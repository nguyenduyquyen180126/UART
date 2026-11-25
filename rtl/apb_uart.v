`timescale 1ns/1ps
module apb_uart #(
    /* verilator lint_off UNUSEDPARAM */
    parameter CLK_FREQ = 50_000_000
    /* verilator lint_on UNUSEDPARAM */
)(
    input pclk,
    input presetn,
    input psel,
    input penable,
    input pwrite,
    input [11:0] paddr,
    input [3:0]  pstrb,
    input [31:0] pwdata,
    output pready,
    output pslverr,
    output [31:0] prdata,
    input  cts_n,
    output tx,
    input  rx,
    output rts_n,
    output irq,
    output tx_done_status,
    output rx_done_status,
    output parity_err_status
);

    wire [1:0] data_bits;
    wire       stop_bits;
    wire       parity_en;
    wire       parity_type;
    wire       tx_dis;
    wire       rx_dis;
    wire       start_tx;
    wire       soft_rst;
    wire [7:0] tx_data;
    wire [7:0] rx_data;
    wire       tx_done;
    wire       rx_done;
    wire       rx_busy;
    wire       parity_err;
    wire       frame_err;
    wire       rx_overrun;
    wire [11:0] div_int;
    wire [3:0]  div_frac;
    // These status/data outputs are intentionally not consumed by APB control.
    /* verilator lint_off UNUSEDSIGNAL */
    wire tx_load_reg_unused;
    wire tx_busy_unused;
    wire rx_error_unused;
    /* verilator lint_on UNUSEDSIGNAL */

    // Public status taps for board-level wrappers; avoid hierarchical references.
    assign tx_done_status = tx_done;
    assign rx_done_status = rx_done;
    assign parity_err_status = parity_err;

    apb_regs u_apb_regs (
        .pclk        (pclk),
        .presetn     (presetn),
        .psel        (psel),
        .penable     (penable),
        .pwrite      (pwrite),
        .paddr       (paddr),
        .pstrb       (pstrb),
        .pwdata      (pwdata),
        .pready      (pready),
        .pslverr     (pslverr),
        .prdata      (prdata),
        .data_bits   (data_bits),
        .stop_bits   (stop_bits),
        .parity_en   (parity_en),
        .parity_type (parity_type),
        .tx_dis      (tx_dis),
        .rx_dis      (rx_dis),
        .start_tx    (start_tx),
        .soft_rst    (soft_rst),
        .tx_data     (tx_data),
        .rx_data     (rx_data),
        .tx_done     (tx_done),
        .rx_done     (rx_done),
        .parity_err  (parity_err),
        .rx_busy     (rx_busy),
        .frame_err   (frame_err),
        .rx_overrun  (rx_overrun),
        .div_int     (div_int),
        .div_frac    (div_frac),
        .irq         (irq)
    );

    // Tach bach: presetn la reset cung bat dong bo he thong.
    // soft_rst la reset mem dong bo voi pclk, duoc dua vao cong soft_rst rieng cua engine.
    wire rx_clear = psel & penable & ~pwrite & (paddr == 12'h004);

    tx_uart u_tx_uart (
        .clk          (pclk),
        .rst_n        (presetn),
        .soft_rst     (soft_rst),
        .start_tx     (start_tx),
        .tx_data      (tx_data),
        .data_bit_num (data_bits),
        .stop_bit_num (stop_bits),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .tx_dis       (tx_dis),
        .cts_n        (cts_n),
        .div_int      (div_int),
        .div_frac     (div_frac),
        .tx           (tx),
        .load_reg     (tx_load_reg_unused),
        .tx_done      (tx_done),
        .tx_busy      (tx_busy_unused)
    );

    rx_uart u_rx_uart (
        .clk         (pclk),
        .rst_n       (presetn),
        .soft_rst    (soft_rst),
        .rx          (rx),
        .data_b_num  (data_bits),
        .stop_b_num  (stop_bits),
        .parity_type (parity_type),
        .parity_en   (parity_en),
        .rx_dis      (rx_dis),
        .div_int     (div_int),
        .div_frac    (div_frac),
        .rx_clear    (rx_clear),
        .rx_data     (rx_data),
        .rx_done     (rx_done),
        .rx_busy     (rx_busy),
        .rts_n       (rts_n),
        .parity_err  (parity_err),
        .frame_err   (frame_err),
        .overrun     (rx_overrun),
        .error       (rx_error_unused)
    );

endmodule
