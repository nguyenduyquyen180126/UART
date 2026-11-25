`timescale 1ns/1ps
module bit_cnt(
    input clk,
    /* verilator lint_off UNUSEDSIGNAL */
    input rst_n, // Synchronously cleared via bit_clr outside DATA -> dfxtp_1
    /* verilator lint_on UNUSEDSIGNAL */
    input inc_en,
    input [1:0] data_b_num,
    input bit_clr,
    output reg [2:0] bit_cnt,
    output bit_last
);
    // V2 PPA: 3-bit data-only counter (0..4/5/6/7) replaces 4-bit counter + data_b_num LUT + adder.
    assign bit_last = (bit_cnt == {1'b1, data_b_num});

    always @(posedge clk) begin
        if (bit_clr) begin
            bit_cnt <= 3'd0;
        end else if (inc_en) begin
            bit_cnt <= bit_cnt + 3'd1;
        end
    end
endmodule
