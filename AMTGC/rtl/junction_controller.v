`timescale 1ns/1ps
// Parameterized Moore FSM for one junction. Light encoding: RED=100, YELLOW=010, GREEN=001.
module junction_controller #(
    parameter COUNTER_WIDTH = 16,
    parameter GREEN_TIME = 20,
    parameter YELLOW_TIME = 4,
    parameter RED_TIME = 2,
    parameter PED_TIME = 6,
    parameter MIN_GREEN_TIME = 10,
    parameter MAX_GREEN_TIME = 40,
    parameter DENSITY_STEP = 4,
    parameter USE_GREEN_WAVE = 0,
    parameter WAIT_FOR_B_READY = 0
)(
    input wire clk,
    input wire rst_n,
    input wire emergency_active,
    input wire [2:0] traffic_density,
    input wire ped_req,
    input wire ped_grant,
    input wire ns_green_permit,
    input wire peer_ready_for_ns,
    output reg [2:0] ns_light,
    output reg [2:0] ew_light,
    output reg ped_walk,
    output reg ns_green_start,
    output reg served_pulse,
    output wire all_red,
    output wire ready_for_ns
);
    localparam [2:0] LIGHT_RED = 3'b100;
    localparam [2:0] LIGHT_YELLOW = 3'b010;
    localparam [2:0] LIGHT_GREEN = 3'b001;

    localparam [3:0] ST_WAIT_NS       = 4'd0;
    localparam [3:0] ST_NS_GREEN      = 4'd1;
    localparam [3:0] ST_NS_YELLOW     = 4'd2;
    localparam [3:0] ST_RED_TO_EW     = 4'd3;
    localparam [3:0] ST_EW_GREEN      = 4'd4;
    localparam [3:0] ST_EW_YELLOW     = 4'd5;
    localparam [3:0] ST_RED_TO_NS     = 4'd6;
    localparam [3:0] ST_PED           = 4'd7;
    localparam [3:0] ST_EMERGENCY_RED = 4'd8;

    reg [3:0] state, next_state;
    reg [3:0] state_before_ped;
    reg [COUNTER_WIDTH-1:0] green_target_latched;
    reg [COUNTER_WIDTH-1:0] count_target;
    wire timer_start;
    wire [3:0] timer_phase_state;
    wire timer_done;
    reg ped_req_d;
    reg ped_pending;
    wire ped_req_rise;

    assign ped_req_rise = ped_req & ~ped_req_d;
    assign all_red = (ns_light == LIGHT_RED) && (ew_light == LIGHT_RED);
    assign ready_for_ns = (state == ST_WAIT_NS) && !emergency_active;
    assign timer_phase_state = (next_state != state) ? next_state : state;
    assign timer_start = (next_state != state) && !emergency_active;

    function [COUNTER_WIDTH-1:0] adaptive_green_target;
        input [2:0] density;
        integer calculated;
        begin
            calculated = GREEN_TIME + (density * DENSITY_STEP);
            if (calculated < MIN_GREEN_TIME) calculated = MIN_GREEN_TIME;
            if (calculated > MAX_GREEN_TIME) calculated = MAX_GREEN_TIME;
            adaptive_green_target = calculated;
        end
    endfunction

    generic_timer #(.COUNTER_WIDTH(COUNTER_WIDTH)) phase_timer (
        .clk(clk), .rst_n(rst_n), .start(timer_start),
        .cancel(emergency_active), .count_target(count_target), .done(timer_done)
    );

    // The density value is sampled only when a green phase begins; it cannot
    // change the duration halfway through an active green phase.
    always @(*) begin
        count_target = {COUNTER_WIDTH{1'b0}};
        case (timer_phase_state)
            ST_NS_GREEN, ST_EW_GREEN: begin
                if (next_state != state) count_target = adaptive_green_target(traffic_density);
                else count_target = green_target_latched;
            end
            ST_NS_YELLOW, ST_EW_YELLOW: count_target = YELLOW_TIME;
            ST_RED_TO_EW, ST_RED_TO_NS: count_target = RED_TIME;
            ST_PED: count_target = PED_TIME;
            default: count_target = {COUNTER_WIDTH{1'b0}};
        endcase
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_WAIT_NS: begin
                if (USE_GREEN_WAVE) begin
                    if (ns_green_permit) next_state = ST_NS_GREEN;
                end else if (WAIT_FOR_B_READY) begin
                    if (peer_ready_for_ns) next_state = ST_NS_GREEN;
                end else begin
                    next_state = ST_NS_GREEN;
                end
            end
            ST_NS_GREEN: if (timer_done) next_state = ST_NS_YELLOW;
            ST_NS_YELLOW: if (timer_done) next_state = ST_RED_TO_EW;
            ST_RED_TO_EW: begin
                if (timer_done) begin
                    if (ped_pending && ped_grant) next_state = ST_PED;
                    else next_state = ST_EW_GREEN;
                end
            end
            ST_EW_GREEN: if (timer_done) next_state = ST_EW_YELLOW;
            ST_EW_YELLOW: if (timer_done) next_state = ST_RED_TO_NS;
            ST_RED_TO_NS: begin
                if (timer_done) begin
                    if (ped_pending && ped_grant) next_state = ST_PED;
                    else next_state = ST_WAIT_NS;
                end
            end
            ST_PED: begin
                if (timer_done) begin
                    if (state_before_ped == ST_RED_TO_EW) next_state = ST_EW_GREEN;
                    else next_state = ST_WAIT_NS;
                end
            end
            ST_EMERGENCY_RED: next_state = ST_EMERGENCY_RED;
            default: next_state = ST_EMERGENCY_RED;
        endcase
        if (emergency_active) next_state = ST_EMERGENCY_RED;
        else if (state == ST_EMERGENCY_RED) next_state = ST_RED_TO_NS;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_WAIT_NS;
            state_before_ped <= ST_RED_TO_NS;
            green_target_latched <= GREEN_TIME;
            ped_req_d <= 1'b0;
            ped_pending <= 1'b0;
            ns_green_start <= 1'b0;
            served_pulse <= 1'b0;
        end else begin
            ped_req_d <= ped_req;
            ns_green_start <= 1'b0;
            served_pulse <= 1'b0;

            if (emergency_active) begin
                state <= ST_EMERGENCY_RED;
                ped_pending <= ped_pending | ped_req_rise | (state == ST_PED);
            end else begin
                if (ped_req_rise) ped_pending <= 1'b1;
                if ((state == ST_RED_TO_EW || state == ST_RED_TO_NS) && timer_done && ped_pending && ped_grant) begin
                    state_before_ped <= state;
                    ped_pending <= 1'b0;
                end
                if (state == ST_PED && timer_done) served_pulse <= 1'b1;

                if (next_state != state) begin
                    state <= next_state;
                    if (next_state == ST_NS_GREEN) begin
                        green_target_latched <= adaptive_green_target(traffic_density);
                        ns_green_start <= 1'b1;
                    end else if (next_state == ST_EW_GREEN) begin
                        green_target_latched <= adaptive_green_target(traffic_density);
                    end
                end
            end
        end
    end

    // Moore outputs: determined only by the registered state.
    always @(*) begin
        ns_light = LIGHT_RED;
        ew_light = LIGHT_RED;
        ped_walk = 1'b0;
        case (state)
            ST_NS_GREEN: ns_light = LIGHT_GREEN;
            ST_NS_YELLOW: ns_light = LIGHT_YELLOW;
            ST_EW_GREEN: ew_light = LIGHT_GREEN;
            ST_EW_YELLOW: ew_light = LIGHT_YELLOW;
            ST_PED: ped_walk = 1'b1;
            default: begin ns_light = LIGHT_RED; ew_light = LIGHT_RED; ped_walk = 1'b0; end
        endcase
        if (emergency_active || state == ST_EMERGENCY_RED) begin
            ns_light = LIGHT_RED;
            ew_light = LIGHT_RED;
            ped_walk = 1'b0;
        end
    end
endmodule
