`timescale 1ns/1ps
// Integration regression: directed emergency checks, adaptive density sweep, and >100 paired requests.
module tb_full_verification;
    reg clk=0, rst_n=0, emergency_in=0, ped_req_a=0, ped_req_b=0;
    reg [2:0] traffic_density_a=0, traffic_density_b=0;
    wire [2:0] a_ns_light,a_ew_light,b_ns_light,b_ew_light;
    wire ped_walk_a,ped_walk_b,ped_grant_a,ped_grant_b,emergency_active,green_wave_active,green_wave_permit_b;
    integer cycle=0, i, expected_a, expected_b, base_idx, offset_cycles, a_count=0, b_count=0, served_a_count=0, served_b_count=0, first_a=-1, first_b=-1;
    integer a_event_cycle[0:1023];
    integer b_event_cycle[0:1023];
    reg [31:0] lfsr=32'h1ACEB00C;
    localparam [2:0] RED=3'b100, GREEN=3'b001;

    amtgc_top #(
        .COUNTER_WIDTH(8), .A_GREEN_TIME(10), .B_GREEN_TIME(10), .YELLOW_TIME(2),
        .RED_TIME(4), .PED_TIME(2), .MIN_GREEN_TIME(5), .MAX_GREEN_TIME(17),
        .DENSITY_STEP(1), .GREEN_WAVE_DELAY(8)
    ) dut(
        .clk(clk), .rst_n(rst_n), .emergency_in(emergency_in), .ped_req_a(ped_req_a), .ped_req_b(ped_req_b),
        .traffic_density_a(traffic_density_a), .traffic_density_b(traffic_density_b),
        .a_ns_light(a_ns_light), .a_ew_light(a_ew_light), .b_ns_light(b_ns_light), .b_ew_light(b_ew_light),
        .ped_walk_a(ped_walk_a), .ped_walk_b(ped_walk_b), .ped_grant_a(ped_grant_a), .ped_grant_b(ped_grant_b),
        .emergency_active(emergency_active), .green_wave_active(green_wave_active), .green_wave_permit_b(green_wave_permit_b)
    );
    always #5 clk=~clk;
    always @(posedge clk) begin
        cycle <= cycle+1;
        if (rst_n) begin
            if (dut.served_a) served_a_count <= served_a_count+1;
            if (dut.served_b) served_b_count <= served_b_count+1;
            if (dut.u_junction_a.ns_green_start) begin
                a_event_cycle[a_count]=cycle;
                if (first_a<0) first_a=cycle;
                a_count=a_count+1;
            end
            if (dut.u_junction_b.ns_green_start) begin
                b_event_cycle[b_count]=cycle;
                if (first_b<0) first_b=cycle;
                b_count=b_count+1;
            end
            if ((a_ns_light==GREEN && a_ew_light!=RED) || (a_ew_light==GREEN && a_ns_light!=RED)) begin
                $display("FAIL: Junction A conflicting vehicle indications at cycle %0d",cycle); $fatal;
            end
            if ((b_ns_light==GREEN && b_ew_light!=RED) || (b_ew_light==GREEN && b_ns_light!=RED)) begin
                $display("FAIL: Junction B conflicting vehicle indications at cycle %0d",cycle); $fatal;
            end
            if (emergency_active && (a_ns_light!=RED || a_ew_light!=RED || b_ns_light!=RED || b_ew_light!=RED || ped_walk_a || ped_walk_b)) begin
                $display("FAIL: emergency state is not all-red at cycle %0d",cycle); $fatal;
            end
        end
    end

    task pulse_both_requests;
        begin
            @(negedge clk); ped_req_a=1; ped_req_b=1;
            @(negedge clk); ped_req_a=0; ped_req_b=0;
        end
    endtask

    task check_emergency;
        begin
            @(negedge clk); emergency_in=1;
            // The external input is synchronized; once the synchronized status asserts,
            // the output override must already show all-red.
            wait(emergency_active === 1'b1);
            #1;
            if (a_ns_light!=RED || a_ew_light!=RED || b_ns_light!=RED || b_ew_light!=RED || ped_walk_a || ped_walk_b) begin
                $display("FAIL: emergency did not force all-red at recognition"); $fatal;
            end
            repeat(2) @(negedge clk);
            emergency_in=0;
            repeat(4) @(negedge clk);
        end
    endtask

    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        // Adaptive density sweep: each density is held for a complete set of phases.
        for (i=0; i<8; i=i+1) begin
            traffic_density_a=i[2:0];
            traffic_density_b=(7-i);
            // Wait until the current A green has ended, then measure the next A/B start pair.
            wait(dut.u_junction_a.state != 4'd1);
            base_idx=a_count;
            wait(a_count > base_idx);
            wait(b_count > base_idx);
            offset_cycles=b_event_cycle[base_idx]-a_event_cycle[base_idx];
            if (offset_cycles != 8) begin
                $display("FAIL: density combo A=%0d B=%0d green-wave offset=%0d cycles",i,7-i,offset_cycles); $fatal;
            end
            expected_a=10+i; if (expected_a>17) expected_a=17;
            expected_b=10+(7-i); if (expected_b>17) expected_b=17;
            if (dut.u_junction_a.green_target_latched != expected_a) begin
                $display("FAIL: A adaptive target density=%0d expected=%0d got=%0d",i,expected_a,dut.u_junction_a.green_target_latched); $fatal;
            end
            if (dut.u_junction_b.green_target_latched != expected_b) begin
                $display("FAIL: B adaptive target density=%0d expected=%0d got=%0d",7-i,expected_b,dut.u_junction_b.green_target_latched); $fatal;
            end
            $display("PASS: density combo A=%0d B=%0d, measured green-wave offset=%0d cycles",i,7-i,offset_cycles);
        end
        if (first_a<0 || first_b<0) begin
            $display("FAIL: initial NS green event missing"); $fatal;
        end

        // Assert emergency while Junction A is in each ordinary vehicle phase/state.
        // State IDs are the localparam encodings documented in junction_controller.v.
        wait(dut.u_junction_a.state == 4'd1); check_emergency(); // NS green
        wait(dut.u_junction_a.state == 4'd2); check_emergency(); // NS yellow
        wait(dut.u_junction_a.state == 4'd3); check_emergency(); // all-red to EW
        wait(dut.u_junction_a.state == 4'd4); check_emergency(); // EW green
        wait(dut.u_junction_a.state == 4'd5); check_emergency(); // EW yellow
        wait(dut.u_junction_a.state == 4'd6); check_emergency(); // all-red to NS
        $display("PASS: emergency exercised during each ordinary traffic phase/state");

        // 120 simultaneous paired request events. A request is pulsed once per service interval.
        for (i=0; i<120; i=i+1) begin
            pulse_both_requests();
            repeat(58) @(negedge clk);
        end
        repeat(80) @(negedge clk);
        if (served_a_count < 100 || served_b_count < 100) begin
            $display("FAIL: expected >100 services per junction, got A=%0d B=%0d",served_a_count,served_b_count); $fatal;
        end
        if ((served_a_count-served_b_count > 3) || (served_b_count-served_a_count > 3)) begin
            $display("FAIL: service imbalance too large A=%0d B=%0d",served_a_count,served_b_count); $fatal;
        end
        $display("PASS: pedestrian service counts A=%0d B=%0d",served_a_count,served_b_count);

        // Exercise emergency while traffic is running, and then again after a pedestrian phase begins.
        check_emergency();
        pulse_both_requests();
        i=0;
        while (!(ped_walk_a || ped_walk_b) && i<250) begin
            @(negedge clk); i=i+1;
        end
        if (ped_walk_a || ped_walk_b) check_emergency();
        else begin
            $display("FAIL: pedestrian phase not observed in bounded wait"); $fatal;
        end

        // Rapid emergency pulses with no idle gap between deassertion and the next assertion.
        for (i=0; i<5; i=i+1) begin
            @(negedge clk); emergency_in=1;
            @(negedge clk); emergency_in=0;
        end
        repeat(5) @(negedge clk);

        // Exercise reset while the complete system is already running.
        @(negedge clk); rst_n=0; emergency_in=0; ped_req_a=0; ped_req_b=0;
        repeat(2) @(negedge clk);
        if (a_ns_light!=RED || a_ew_light!=RED || b_ns_light!=RED || b_ew_light!=RED) begin
            $display("FAIL: active reset did not initialize all-red outputs"); $fatal;
        end
        @(negedge clk); rst_n=1;
        repeat(5) @(negedge clk);
        $display("PASS: rapid emergency toggles and active reset exercised");

        // Deterministic pseudo-random stimulus for 1000 clocks.
        for (i=0; i<1000; i=i+1) begin
            @(negedge clk);
            lfsr = {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
            traffic_density_a = lfsr[2:0];
            traffic_density_b = lfsr[5:3];
            if (lfsr[8]) ped_req_a=1; else ped_req_a=0;
            if (lfsr[11]) ped_req_b=1; else ped_req_b=0;
        end
        ped_req_a=0; ped_req_b=0;
        $display("PASS: 1000-cycle deterministic pseudo-random stimulus completed");
        $display("FULL_REGRESSION_PASS (run in ModelSim and archive its actual transcript/waveform before submission)");
        $finish;
    end

    initial begin
        #2000000;
        $display("FAIL: regression timeout"); $fatal;
    end
endmodule
