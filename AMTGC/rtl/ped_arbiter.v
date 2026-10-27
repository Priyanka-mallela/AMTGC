`timescale 1ns/1ps
// Round-robin pedestrian arbiter. Requests are captured on rising edges and held until served.
module ped_arbiter (
    input wire clk,
    input wire rst_n,
    input wire emergency_active,
    input wire req_a,
    input wire req_b,
    input wire served_a,
    input wire served_b,
    output reg grant_a,
    output reg grant_b,
    output wire busy
);
    reg req_a_d, req_b_d;
    reg pending_a, pending_b;
    reg prefer_b;
    reg [1:0] serving_id;
    assign busy = (serving_id != 2'd0);

    always @(*) begin
        grant_a = (serving_id == 2'd1) && !emergency_active;
        grant_b = (serving_id == 2'd2) && !emergency_active;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            req_a_d <= 1'b0;
            req_b_d <= 1'b0;
            pending_a <= 1'b0;
            pending_b <= 1'b0;
            prefer_b <= 1'b0;
            serving_id <= 2'd0;
        end else begin
            req_a_d <= req_a;
            req_b_d <= req_b;
            if (req_a && !req_a_d) pending_a <= 1'b1;
            if (req_b && !req_b_d) pending_b <= 1'b1;

            if (emergency_active) begin
                // Abort the current grant but retain unserved requests. If a service completed
                // on this same edge, clear that completed request to avoid a duplicate grant.
                serving_id <= 2'd0;
                if (served_a) pending_a <= 1'b0;
                if (served_b) pending_b <= 1'b0;
            end else if (serving_id == 2'd1 && served_a) begin
                pending_a <= 1'b0;
                serving_id <= 2'd0;
                prefer_b <= 1'b1;
            end else if (serving_id == 2'd2 && served_b) begin
                pending_b <= 1'b0;
                serving_id <= 2'd0;
                prefer_b <= 1'b0;
            end else if (serving_id == 2'd0) begin
                if (pending_a && pending_b) begin
                    if (prefer_b) serving_id <= 2'd2;
                    else serving_id <= 2'd1;
                end else if (pending_a) serving_id <= 2'd1;
                else if (pending_b) serving_id <= 2'd2;
            end
        end
    end
endmodule
