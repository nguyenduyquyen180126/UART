`timescale 1ns/1ps
// Tiny Tapeout 1x1 wrapper for the SPI-to-APB UART design.
`default_nettype none

module tt_um_hust_apb_uart (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire spi_miso;
    wire tx;
    wire rts_n;
    wire irq;
    wire tx_done_status;
    wire rx_done_status;
    wire parity_err_status;

    top_uart #(
        .CLK_FREQ(25_000_000)
    ) uart_top (
        .pclk             (clk),
        .presetn          (rst_n),
        .spi_cs_n         (ui_in[2]),
        .spi_sclk         (ui_in[3]),
        .spi_mosi         (ui_in[4]),
        .spi_miso         (spi_miso),
        .cts_n            (ui_in[1]),
        .rx               (ui_in[0]),
        .tx               (tx),
        .rts_n            (rts_n),
        .irq              (irq),
        .tx_done_status   (tx_done_status),
        .rx_done_status   (rx_done_status),
        .parity_err_status(parity_err_status)
    );

    assign uo_out = {
        1'b0,               // [7] reserved for scan_out; DFT is not implemented
        irq,                // [6]
        parity_err_status,  // [5]
        rx_done_status,     // [4]
        tx_done_status,     // [3]
        spi_miso,           // [2]
        rts_n,              // [1]
        tx                  // [0]
    };
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // ui_in[7:5], uio_in, and ena are intentionally unused in this design.
    wire _unused = &{ena, uio_in, ui_in[7:5], 1'b0};
endmodule

`default_nettype wire
