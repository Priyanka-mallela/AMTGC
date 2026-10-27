`timescale 1ns/1ps
// Reusable timer. start should be a one-clock pulse. done is asserted at the target count.
// The start-sampling edge loads count=1 and counts as the first cycle. count_target=0 completes immediately.
module generic_timer #(
    parameter COUNTER_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire cancel,
    input wire [COUNTER_WIDTH-1:0] count_target,
    output wire done
);
    reg [COUNTER_WIDTH-1:0] count;
    reg [COUNTER_WIDTH-1:0] target_latched;
    reg active;

    // Latch the target on start so the consumer may present the next phase's
    // target on the same edge that the current phase completes.
    assign done = (active && (count >= target_latched)) ||
                  (!active && start && (count_target == {COUNTER_WIDTH{1'b0}}));

    always @(posedge clk) begin
        if (!rst_n) begin
            count          <= {COUNTER_WIDTH{1'b0}};
            target_latched <= {COUNTER_WIDTH{1'b0}};
            active         <= 1'b0;
        end else if (cancel) begin
            count          <= {COUNTER_WIDTH{1'b0}};
            target_latched <= {COUNTER_WIDTH{1'b0}};
            active         <= 1'b0;
        end else if (active && (count >= target_latched)) begin
            if (start && (count_target != {COUNTER_WIDTH{1'b0}})) begin
                count          <= {{(COUNTER_WIDTH-1){1'b0}},1'b1};
                target_latched <= count_target;
                active         <= 1'b1;
            end else begin
                count          <= {COUNTER_WIDTH{1'b0}};
                target_latched <= {COUNTER_WIDTH{1'b0}};
                active         <= 1'b0;
            end
        end else if (active) begin
            count <= count + {{(COUNTER_WIDTH-1){1'b0}},1'b1};
        end else if (start && (count_target != {COUNTER_WIDTH{1'b0}})) begin
            count          <= {{(COUNTER_WIDTH-1){1'b0}},1'b1};
            target_latched <= count_target;
            active         <= 1'b1;
        end else begin
            count          <= {COUNTER_WIDTH{1'b0}};
            target_latched <= {COUNTER_WIDTH{1'b0}};
            active         <= 1'b0;
        end
    end
endmodule
