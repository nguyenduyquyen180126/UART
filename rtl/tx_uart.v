`timescale 1ns/1ps
module tx_uart #(
    /* verilator lint_off UNUSEDPARAM */
    parameter CLK_FREQ = 50_000_000
    /* verilator lint_on UNUSEDPARAM */
)(
    input clk,
    input rst_n,
    input soft_rst,
    input start_tx,
    input [7:0] tx_data,
    input [1:0] data_bit_num,
    input stop_bit_num,
    input parity_en,
    input parity_type,
    input tx_dis,
    input cts_n,
    input [11:0] div_int,
    input [3:0] div_frac,
    output reg tx,
    output wire load_reg,
    output wire tx_done,
    output wire tx_busy
);
    wire       bit_last;
    wire       baud_tick;
    wire       clr_bit;
    wire       clr_baud;
    wire [2:0] bit_cnt;
    wire [2:0] bit_cnt_last = {1'b1, data_bit_num};
    wire [1:0] tx_sel;
    wire       tick_last;

    reg cts_n_sync1, cts_n_sync2;
    wire soft_rst_i = (soft_rst === 1'b1);

    // 2-FF synchronizer for external asynchronous CTS_N
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cts_n_sync1 <= 1'b1;
            cts_n_sync2 <= 1'b1;
        end else if (soft_rst_i) begin
            cts_n_sync1 <= 1'b1;
            cts_n_sync2 <= 1'b1;
        end else begin
            cts_n_sync1 <= cts_n;
            cts_n_sync2 <= cts_n_sync1;
        end
    end

    tx_controller controller(
        .clk          (clk),
        .rst_n        (rst_n),
        .soft_rst     (soft_rst_i),
        .start_tx     (start_tx),
        .parity_en    (parity_en),
        .stop_bit_num (stop_bit_num),
        .bit_last     (bit_last),
        .cts_n        (cts_n_sync2),
        .tx_dis       (tx_dis),
        .tick_last    (tick_last),
        .tx_sel       (tx_sel),
        .load_reg     (load_reg),
        .clr_bit      (clr_bit),
        .clr_baud     (clr_baud),
        .tx_done      (tx_done),
        .tx_busy      (tx_busy)
    );

    tx_baud_gen u_baud_gen(
        .div_int  (div_int),
        .div_frac (div_frac),
        .pclk     (clk),
        .presetn  (rst_n),
        .clr_baud (clr_baud),
        .baud_tick(baud_tick)
    );

    tx_tick_cnt tick_cnt_ins(
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .clr_tick  (clr_baud),
        .tick_last (tick_last)
    );

    tx_bit_cnt u_bit_cnt(
        .clk       (clk),
        .rst_n     (rst_n),
        .clr_bit   (clr_bit),
        .baud_tick (baud_tick),
        .tick_last (tick_last),
        .cnt       (bit_cnt)
    );

    assign bit_last = (bit_cnt == bit_cnt_last);

    // V2 PPA: TXDATA and CFG are write-protected by E3/E4 while tx_done==0,
    // so direct 8:1 muxing tx_data[bit_cnt] + combinational parity over masked
    // tx_data eliminates the 8-FF PISO shift register and 1-FF parity_latched (-9 FFs).
    wire data_mux_in = tx_data[bit_cnt];
    wire [7:0] tx_masked = {
        tx_data[7] & (&data_bit_num),
        tx_data[6] & data_bit_num[1],
        tx_data[5] & (|data_bit_num),
        tx_data[4:0]
    };
    wire parity_bit = parity_type ? (^tx_masked) : ~(^tx_masked);

    always @(*) begin
        case (tx_sel)
            2'b00:   tx = 1'b0;
            2'b01:   tx = 1'b1;
            2'b10:   tx = data_mux_in;
            2'b11:   tx = parity_bit;
            default: tx = 1'b1;
        endcase
    end
endmodule
