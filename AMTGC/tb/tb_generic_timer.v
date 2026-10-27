`timescale 1ns/1ps
module tb_generic_timer #(parameter COUNTER_WIDTH=8);
    reg clk=0, rst_n=0, start=0, cancel=0;
    reg [COUNTER_WIDTH-1:0] count_target=0;
    wire done;
    integer cycles;
    generic_timer #(.COUNTER_WIDTH(COUNTER_WIDTH)) dut(
        .clk(clk), .rst_n(rst_n), .start(start), .cancel(cancel),
        .count_target(count_target), .done(done)
    );
    always #5 clk=~clk;

    task run_target;
        input [COUNTER_WIDTH-1:0] target;
        input integer expected_cycles;
        integer seen;
        begin
            @(negedge clk); count_target=target; start=1;
            if (target == 0) begin
                #1;
                if (!done) begin $display("FAIL zero target was not immediate"); $fatal; end
                @(negedge clk); start=0; #1;
                if (done) begin $display("FAIL zero-target done did not clear"); $fatal; end
                $display("PASS timer target=0 immediate completion");
            end else begin
                @(negedge clk); start=0; seen=1; // start-sampling edge counts as cycle one
                while (!done && seen < expected_cycles+2) begin
                    @(negedge clk); seen=seen+1;
                end
                if (!done) begin $display("FAIL timer target=%0d timeout",target); $fatal; end
                if (seen != expected_cycles) begin
                    $display("FAIL timer target=%0d expected=%0d observed=%0d",target,expected_cycles,seen); $fatal;
                end
                @(negedge clk);
                if (done) begin $display("FAIL done did not clear"); $fatal; end
                $display("PASS timer target=%0d exact completion",target);
            end
        end
    endtask

    initial begin
        repeat(2) @(negedge clk); rst_n=1;
        run_target(3,3);
        run_target(5,5);
        run_target(0,0);
        // Reset while the timer is active must clear count and done.
        @(negedge clk); count_target=20; start=1;
        @(negedge clk); start=0;
        repeat(2) @(negedge clk);
        rst_n=0; @(negedge clk); rst_n=1;
        repeat(2) @(negedge clk);
        if (done || dut.count != 0) begin $display("FAIL timer did not reset cleanly"); $fatal; end
        $display("PASS timer reset while counting");
        $display("TB_GENERIC_TIMER_PASS"); $finish;
    end
endmodule
