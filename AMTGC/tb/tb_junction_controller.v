`timescale 1ns/1ps
module tb_junction_controller;
    reg clk=0, rst_n=0, emergency_active=0;
    reg [2:0] traffic_density=0;
    reg ped_req=0, ped_grant=0, ns_green_permit=1;
    wire [2:0] ns_light, ew_light;
    wire ped_walk, ns_green_start, served_pulse, all_red;
    integer cycles=0, ped_seen=0, ns_seen=0, ew_seen=0, ped_entries=0;
    reg ped_walk_d=0;
    localparam [2:0] RED=3'b100, YELLOW=3'b010, GREEN=3'b001;
    junction_controller #(
        .COUNTER_WIDTH(8), .GREEN_TIME(4), .YELLOW_TIME(2), .RED_TIME(1), .PED_TIME(2),
        .MIN_GREEN_TIME(2), .MAX_GREEN_TIME(8), .DENSITY_STEP(1), .USE_GREEN_WAVE(0)
    ) dut(
        .clk(clk), .rst_n(rst_n), .emergency_active(emergency_active),
        .traffic_density(traffic_density), .ped_req(ped_req), .ped_grant(ped_grant),
        .ns_green_permit(ns_green_permit), .peer_ready_for_ns(1'b1), .ns_light(ns_light), .ew_light(ew_light),
        .ped_walk(ped_walk), .ns_green_start(ns_green_start), .served_pulse(served_pulse), .all_red(all_red), .ready_for_ns()
    );
    always #5 clk=~clk;
    always @(posedge clk) if (rst_n) begin
        cycles <= cycles+1;
        if (ns_light==GREEN) ns_seen<=1;
        if (ew_light==GREEN) ew_seen<=1;
        if (ped_walk) ped_seen<=1;
        if (ped_walk && !ped_walk_d) ped_entries<=ped_entries+1;
        ped_walk_d <= ped_walk;
        if ((ns_light==GREEN && ew_light!=RED) || (ew_light==GREEN && ns_light!=RED)) begin
            $display("FAIL conflicting signal state"); $fatal;
        end
    end
    initial begin
        repeat(2) @(negedge clk); rst_n=1;
        // Deliberately raise a request during the NS-yellow phase.
        wait(dut.state == 4'd2);
        @(negedge clk); ped_req=1; ped_grant=1;
        @(negedge clk); ped_req=0;
        repeat(80) @(negedge clk);
        if (!ns_seen || !ew_seen) begin $display("FAIL missing traffic phase"); $fatal; end
        if (!ped_seen || ped_entries != 1) begin $display("FAIL pedestrian request lost or serviced more than once; entries=%0d",ped_entries); $fatal; end
        $display("TB_JUNCTION_CONTROLLER_PASS"); $finish;
    end
endmodule
