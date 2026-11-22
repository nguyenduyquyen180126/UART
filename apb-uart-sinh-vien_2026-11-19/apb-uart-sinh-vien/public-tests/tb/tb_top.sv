// tb_top — clock 25 MHz (chu kỳ 40 ns), DUT apb_uart nối theo tên đúng 16 cổng spec mục 2
// (quyết định 10, SI-22: cổng ra bổ sung của đội để hở, không nối), hai interface, checker, gọi tests_pkg::run().
`timescale 1ns/1ps
`default_nettype none
module tb_top;

  // Test plan and BAUD table use a 25 MHz APB clock.
  localparam integer TB_CLK_FREQ = 25_000_000;

  logic pclk = 1'b0;
  always #(tb_pkg::T_PCLK_NS / 2.0) pclk = ~pclk;

  apb_if  apb  (.pclk(pclk));
  uart_if uart ();

  apb_uart #(.CLK_FREQ(TB_CLK_FREQ)) dut (
    .pclk    (pclk),
    .presetn (apb.presetn),
    .psel    (apb.psel),
    .penable (apb.penable),
    .pwrite  (apb.pwrite),
    .paddr   (apb.paddr),
    .pstrb   (apb.pstrb),
    .pwdata  (apb.pwdata),
    .pready  (apb.pready),
    .pslverr (apb.pslverr),
    .prdata  (apb.prdata),
    .rx      (uart.rx),
    .cts_n   (uart.cts_n),
    .tx      (uart.tx),
    .rts_n   (uart.rts_n),
    .irq     (uart.irq)
  );

  tb_checker chk (
    .pclk    (pclk),
    .presetn (apb.presetn),
    .psel    (apb.psel),
    .penable (apb.penable),
    .pwrite  (apb.pwrite),
    .paddr   (apb.paddr),
    .pstrb   (apb.pstrb),
    .pwdata  (apb.pwdata),
    .pready  (apb.pready),
    .pslverr (apb.pslverr),
    .prdata  (apb.prdata),
    .tx      (uart.tx),
    .rts_n   (uart.rts_n),
    .irq     (uart.irq)
  );

  initial tests_pkg::run(apb, uart);

endmodule
`default_nettype wire
