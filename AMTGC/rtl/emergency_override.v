`timescale 1ns/1ps
// Two-flop synchronizer for an external emergency input. Output is the recognized system-clock signal.
module emergency_override (
    input wire clk,
    input wire rst_n,
    input wire emergency_in,
    output wire emergency_active
);
    reg emergency_meta, emergency_sync;
    always @(posedge clk) begin
        if (!rst_n) begin
            emergency_meta <= 1'b0;
            emergency_sync <= 1'b0;
        end else begin
            emergency_meta <= emergency_in;
            emergency_sync <= emergency_meta;
        end
    end
    assign emergency_active = emergency_sync;
endmodule
