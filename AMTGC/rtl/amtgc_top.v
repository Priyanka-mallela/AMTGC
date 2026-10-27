`timescale 1ns/1ps
module amtgc_top #(
    parameter COUNTER_WIDTH = 16,
    parameter A_GREEN_TIME = 20,
    parameter B_GREEN_TIME = 18,
    parameter YELLOW_TIME = 4,
    parameter RED_TIME = 2,
    parameter PED_TIME = 6,
    parameter MIN_GREEN_TIME = 10,
    parameter MAX_GREEN_TIME = 40,
    parameter DENSITY_STEP = 4,
    parameter GREEN_WAVE_DELAY = 8
)(
    input wire clk,
    input wire rst_n,
    input wire emergency_in,
    input wire ped_req_a,
    input wire ped_req_b,
    input wire [2:0] traffic_density_a,
    input wire [2:0] traffic_density_b,
    output wire [2:0] a_ns_light,
    output wire [2:0] a_ew_light,
    output wire [2:0] b_ns_light,
    output wire [2:0] b_ew_light,
    output wire ped_walk_a,
    output wire ped_walk_b,
    output wire ped_grant_a,
    output wire ped_grant_b,
    output wire emergency_active,
    output wire green_wave_active,
    output wire green_wave_permit_b
);
    wire a_ns_green_start, b_ns_green_start;
    wire ready_a_for_ns, ready_b_for_ns;
    wire served_a, served_b;
    wire all_red_a, all_red_b;
    wire arbiter_busy;

    emergency_override u_emergency (
        .clk(clk), .rst_n(rst_n), .emergency_in(emergency_in),
        .emergency_active(emergency_active)
    );

    ped_arbiter u_ped_arbiter (
        .clk(clk), .rst_n(rst_n), .emergency_active(emergency_active),
        .req_a(ped_req_a), .req_b(ped_req_b),
        .served_a(served_a), .served_b(served_b),
        .grant_a(ped_grant_a), .grant_b(ped_grant_b), .busy(arbiter_busy)
    );

    green_wave_coordinator #(
        .COUNTER_WIDTH(COUNTER_WIDTH), .DELAY_CYCLES(GREEN_WAVE_DELAY)
    ) u_green_wave (
        .clk(clk), .rst_n(rst_n), .emergency_active(emergency_active),
        .a_ns_green_start(a_ns_green_start), .b_ns_green_start(b_ns_green_start),
        .b_ns_green_permit(green_wave_permit_b), .coord_active(green_wave_active)
    );

    junction_controller #(
        .COUNTER_WIDTH(COUNTER_WIDTH), .GREEN_TIME(A_GREEN_TIME),
        .YELLOW_TIME(YELLOW_TIME), .RED_TIME(RED_TIME), .PED_TIME(PED_TIME),
        .MIN_GREEN_TIME(MIN_GREEN_TIME), .MAX_GREEN_TIME(MAX_GREEN_TIME),
        .DENSITY_STEP(DENSITY_STEP), .USE_GREEN_WAVE(0), .WAIT_FOR_B_READY(1)
    ) u_junction_a (
        .clk(clk), .rst_n(rst_n), .emergency_active(emergency_active),
        .traffic_density(traffic_density_a), .ped_req(ped_req_a), .ped_grant(ped_grant_a),
        .ns_green_permit(1'b1), .peer_ready_for_ns(ready_b_for_ns), .ns_light(a_ns_light), .ew_light(a_ew_light),
        .ped_walk(ped_walk_a), .ns_green_start(a_ns_green_start),
        .served_pulse(served_a), .all_red(all_red_a), .ready_for_ns(ready_a_for_ns)
    );

    junction_controller #(
        .COUNTER_WIDTH(COUNTER_WIDTH), .GREEN_TIME(B_GREEN_TIME),
        .YELLOW_TIME(YELLOW_TIME), .RED_TIME(RED_TIME), .PED_TIME(PED_TIME),
        .MIN_GREEN_TIME(MIN_GREEN_TIME), .MAX_GREEN_TIME(MAX_GREEN_TIME),
        .DENSITY_STEP(DENSITY_STEP), .USE_GREEN_WAVE(1), .WAIT_FOR_B_READY(0)
    ) u_junction_b (
        .clk(clk), .rst_n(rst_n), .emergency_active(emergency_active),
        .traffic_density(traffic_density_b), .ped_req(ped_req_b), .ped_grant(ped_grant_b),
        .ns_green_permit(green_wave_permit_b), .peer_ready_for_ns(1'b0), .ns_light(b_ns_light), .ew_light(b_ew_light),
        .ped_walk(ped_walk_b), .ns_green_start(b_ns_green_start),
        .served_pulse(served_b), .all_red(all_red_b), .ready_for_ns(ready_b_for_ns)
    );
endmodule
