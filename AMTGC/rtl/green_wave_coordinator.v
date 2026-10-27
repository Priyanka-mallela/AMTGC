`timescale 1ns/1ps
// Starts a delay after A's NS green begins. Permission is held until B starts NS green.
module green_wave_coordinator #(
    parameter COUNTER_WIDTH = 16,
    parameter DELAY_CYCLES = 8
)(
    input wire clk,
    input wire rst_n,
    input wire emergency_active,
    input wire a_ns_green_start,
    input wire b_ns_green_start,
    output reg b_ns_green_permit,
    output reg coord_active
);
    reg [COUNTER_WIDTH-1:0] count;
    // Compensate for observing A's registered pulse one edge later and B's
    // registered start one edge after permit. For delays >=3, measured offset
    // between the two start events is DELAY_CYCLES clock periods.
    localparam EFFECTIVE_DELAY = (DELAY_CYCLES > 2) ? (DELAY_CYCLES - 2) : 1;
    always @(posedge clk) begin
        if (!rst_n) begin
            count <= {COUNTER_WIDTH{1'b0}};
            b_ns_green_permit <= 1'b0;
            coord_active <= 1'b0;
        end else if (emergency_active) begin
            count <= {COUNTER_WIDTH{1'b0}};
            b_ns_green_permit <= 1'b0;
            coord_active <= 1'b0;
        end else begin
            if (a_ns_green_start && !coord_active && !b_ns_green_permit) begin
                count <= {{(COUNTER_WIDTH-1){1'b0}},1'b1};
                coord_active <= 1'b1;
            end else if (coord_active) begin
                if (count >= EFFECTIVE_DELAY) begin
                    coord_active <= 1'b0;
                    b_ns_green_permit <= 1'b1;
                end else begin
                    count <= count + {{(COUNTER_WIDTH-1){1'b0}},1'b1};
                end
            end
            if (b_ns_green_start) begin
                b_ns_green_permit <= 1'b0;
                count <= {COUNTER_WIDTH{1'b0}};
                coord_active <= 1'b0;
            end
        end
    end
endmodule
