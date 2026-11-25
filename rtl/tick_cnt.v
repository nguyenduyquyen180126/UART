`timescale 1ns/1ps
module tick_cnt(
    input clk,
    /* verilator lint_off UNUSEDSIGNAL */
    input rst_n, // Synchronously cleared via tick_clr in IDLE -> dfxtp_1
    /* verilator lint_on UNUSEDSIGNAL */
    input baud_tick,
    input tick_clr,
    output reg [3:0] tick_cnt
);
    always @(posedge clk) begin
        if (tick_clr) begin
            tick_cnt <= 4'b0;
        end else if (baud_tick) begin
            tick_cnt <= tick_cnt + 4'd1;
        end
    end
endmodule
