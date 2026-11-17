module apb_uart #(
    parameter CLK_FREQ = 50_000_000
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
    output irq
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
    wire [11:0] div_int;
    wire [3:0]  div_frac;

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
        .div_int     (div_int),
        .div_frac    (div_frac),
        .irq         (irq)
    );

    // The register block's soft reset resets the UART engines while leaving
    // the APB interface available to reconfigure them.
    wire uart_rst_n = presetn & ~soft_rst;
    wire rx_clear = psel & penable & ~pwrite & (paddr == 12'h004);

    tx_uart #(
        .CLK_FREQ (CLK_FREQ)
    ) u_tx_uart (
        .clk          (pclk),
        .rst_n        (uart_rst_n),
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
        .tx_done      (tx_done),
        .tx_busy      ()
    );

    rx_uart #(
        .CLK_FREQ (CLK_FREQ)
    ) u_rx_uart (
        .clk         (pclk),
        .rst_n       (uart_rst_n),
        .rx          (rx),
        .data_b_num  (data_bits),
        .stop_b_num  (stop_bits),
        .parity_type (parity_type),
        .parity_en   (parity_en),
        .rx_dis      (rx_dis),
        .div_int     (div_int),
        .div_frac    (div_frac),
        .rx_clear    (rx_clear | soft_rst),
        .rx_data     (rx_data),
        .rx_done     (rx_done),
        .rx_busy     (rx_busy),
        .rts_n       (rts_n),
        .parity_err  (parity_err),
        .frame_err   (frame_err),
        .overrun     ()
    );

endmodule
