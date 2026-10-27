`timescale 1ns/1ps
module tb_amtgc_top;
    reg clk=0, rst_n=0, emergency_in=0, ped_req_a=0, ped_req_b=0;
    reg [2:0] traffic_density_a=0, traffic_density_b=0;
    wire [2:0] a_ns_light,a_ew_light,b_ns_light,b_ew_light;
    wire ped_walk_a,ped_walk_b,ped_grant_a,ped_grant_b,emergency_active,green_wave_active,green_wave_permit_b;
    integer a_ns_cycle=-1, b_ns_cycle=-1, cycle=0, grant_a_count=0, grant_b_count=0;
    localparam [2:0] RED=3'b100, GREEN=3'b001;
    amtgc_top #(
        .COUNTER_WIDTH(8), .A_GREEN_TIME(10), .B_GREEN_TIME(10), .YELLOW_TIME(2),
        .RED_TIME(1), .PED_TIME(2), .MIN_GREEN_TIME(3), .MAX_GREEN_TIME(17),
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
            if (a_ns_light==GREEN && a_ns_cycle<0) a_ns_cycle=cycle;
            if (b_ns_light==GREEN && b_ns_cycle<0) b_ns_cycle=cycle;
            if (ped_grant_a) grant_a_count=grant_a_count+1;
            if (ped_grant_b) grant_b_count=grant_b_count+1;
            if ((a_ns_light==GREEN && a_ew_light!=RED) || (a_ew_light==GREEN && a_ns_light!=RED)) begin $display("FAIL A conflicting greens"); $fatal; end
            if ((b_ns_light==GREEN && b_ew_light!=RED) || (b_ew_light==GREEN && b_ns_light!=RED)) begin $display("FAIL B conflicting greens"); $fatal; end
            if (emergency_active && (a_ns_light!=RED || a_ew_light!=RED || b_ns_light!=RED || b_ew_light!=RED || ped_walk_a || ped_walk_b)) begin $display("FAIL emergency not all-red"); $fatal; end
        end
    end
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        traffic_density_a=3; traffic_density_b=5;
        repeat(4) @(negedge clk); ped_req_a=1; ped_req_b=1;
        @(negedge clk); ped_req_a=0; ped_req_b=0;
        repeat(80) @(negedge clk);
        if (a_ns_cycle<0 || b_ns_cycle<0) begin $display("FAIL NS phase missing"); $fatal; end
        if (b_ns_cycle-a_ns_cycle != 8) begin
            $display("FAIL measured initial green-wave offset=%0d cycles", b_ns_cycle-a_ns_cycle); $fatal;
        end else $display("PASS initial green-wave offset=%0d cycles", b_ns_cycle-a_ns_cycle);
        // Emergency must force both junctions to all red and suppress walk indications.
        emergency_in=1;
        repeat(5) @(negedge clk);
        if (!emergency_active || a_ns_light!=RED || a_ew_light!=RED || b_ns_light!=RED || b_ew_light!=RED) begin $display("FAIL emergency all-red"); $fatal; end
        emergency_in=0;
        repeat(5) @(negedge clk);
        $display("TB_AMTGC_TOP_PASS (inspect full waveforms and rerun all directed cases before claiming complete coverage)");
        $finish;
    end
endmodule
