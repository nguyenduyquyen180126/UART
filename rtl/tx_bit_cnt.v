`timescale 1ns/1ps
module tx_bit_cnt(
    input clk,
    /* verilator lint_off UNUSEDSIGNAL */
    input rst_n,     // Synchronously cleared via clr_bit outside DATA -> dfxtp_1
    input baud_tick, // Kept for interface compatibility; tick_last already gates baud_tick
    /* verilator lint_on UNUSEDSIGNAL */
    input clr_bit,
    input tick_last,
    output reg [2:0] cnt
);
    always @(posedge clk) begin
        if (clr_bit) begin
            cnt <= 3'b000;
        end else if (tick_last) begin
            cnt <= cnt + 3'd1;
        end
    end
endmodule
