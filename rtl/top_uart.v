`timescale 1ns/1ps
module top_uart #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire pclk,
    input  wire presetn,

    input  wire spi_cs_n,
    input  wire spi_sclk,
    input  wire spi_mosi,
    output wire spi_miso,

    input  wire cts_n,
    input  wire rx,
    output wire tx,
    output wire rts_n,
    output wire irq,
    output wire tx_done_status,
    output wire rx_done_status,
    output wire parity_err_status
);

    wire        psel;
    wire        penable;
    wire        pwrite;
    wire [11:0] paddr;
    wire [3:0]  pstrb;
    wire [31:0] pwdata;
    wire        pready;
    wire        pslverr;
    wire [31:0] prdata;

    spi2apb_apb_master u_spi_apb (
        .pclk      (pclk),
        .presetn   (presetn),
        .spi_cs_n  (spi_cs_n),
        .spi_clk   (spi_sclk),
        .spi_mosi  (spi_mosi),
        .spi_miso  (spi_miso),
        .psel      (psel),
        .penable   (penable),
        .pwrite    (pwrite),
        .paddr     (paddr),
        .pstrb     (pstrb),
        .pwdata    (pwdata),
        .pready    (pready),
        .pslverr   (pslverr),
        .prdata    (prdata)
    );

    apb_uart #(
        .CLK_FREQ (CLK_FREQ)
    ) u_apb_uart (
        .pclk              (pclk),
        .presetn           (presetn),
        .psel              (psel),
        .penable           (penable),
        .pwrite            (pwrite),
        .paddr             (paddr),
        .pstrb             (pstrb),
        .pwdata            (pwdata),
        .pready            (pready),
        .pslverr           (pslverr),
        .prdata            (prdata),
        .cts_n             (cts_n),
        .tx                (tx),
        .rx                (rx),
        .rts_n             (rts_n),
        .irq               (irq),
        .tx_done_status    (tx_done_status),
        .rx_done_status    (rx_done_status),
        .parity_err_status (parity_err_status)
    );

endmodule

// Alias giu tuong thich cho cac testbench va scripts cu
/* verilator lint_off DECLFILENAME */
module spi2apb #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire pclk,
    input  wire presetn,
    input  wire spi_cs_n,
    input  wire spi_sclk,
    input  wire spi_mosi,
    output wire spi_miso,
    input  wire cts_n,
    input  wire rx,
    output wire tx,
    output wire rts_n,
    output wire irq,
    output wire tx_done_status,
    output wire rx_done_status,
    output wire parity_err_status
);
    top_uart #(
        .CLK_FREQ(CLK_FREQ)
    ) u_top (
        .pclk              (pclk),
        .presetn           (presetn),
        .spi_cs_n          (spi_cs_n),
        .spi_sclk          (spi_sclk),
        .spi_mosi          (spi_mosi),
        .spi_miso          (spi_miso),
        .cts_n             (cts_n),
        .rx                (rx),
        .tx                (tx),
        .rts_n             (rts_n),
        .irq               (irq),
        .tx_done_status    (tx_done_status),
        .rx_done_status    (rx_done_status),
        .parity_err_status (parity_err_status)
    );
endmodule
/* verilator lint_on DECLFILENAME */
