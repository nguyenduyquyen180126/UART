// apb_uart (stub) — module rỗng đúng 16 cổng spec mục 2 (quyết định 10, SI-22), mọi đầu ra bằng 0, dùng để tự kiểm khung testbench (tiêu chí V5):
// mọi test P chạy trên stub này phải in FAIL và thoát khác 0.
`timescale 1ns/1ps
`default_nettype none
module apb_uart (
  input  wire        pclk,
  input  wire        presetn,
  input  wire        psel,
  input  wire        penable,
  input  wire        pwrite,
  input  wire [11:0] paddr,
  input  wire [3:0]  pstrb,
  input  wire [31:0] pwdata,
  output wire        pready,
  output wire        pslverr,
  output wire [31:0] prdata,
  input  wire        rx,
  input  wire        cts_n,
  output wire        tx,
  output wire        rts_n,
  output wire        irq
);
  assign pready  = 1'b0;
  assign pslverr = 1'b0;
  assign prdata  = 32'h0;
  assign tx      = 1'b0;
  assign rts_n   = 1'b0;
  assign irq     = 1'b0;
endmodule
`default_nettype wire
