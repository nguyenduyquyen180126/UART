// checker — module tb_checker nối với cổng của apb_uart trong tb_top: 9 assertion cấp cổng theo testplan mục 3.8
// (APB4 phía completer và phía master). Vi phạm được đếm vào tb_pkg::n_errors qua sva_fail().
// ap_pready_const và ap_pslverr_zero_in_reset không dùng disable iff vì cần kiểm cả trong reset (spec mục 2).
`timescale 1ns/1ps
`default_nettype none
module tb_checker (
  input wire logic        pclk,
  input wire logic        presetn,
  input wire logic        psel,
  input wire logic        penable,
  input wire logic        pwrite,
  input wire logic [11:0] paddr,
  input wire logic [3:0]  pstrb,
  input wire logic [31:0] pwdata,
  input wire logic        pready,
  input wire logic        pslverr,
  input wire logic [31:0] prdata,
  input wire logic        tx,
  input wire logic        rts_n,
  input wire logic        irq
);
  import tb_pkg::*;

  // ----- Phía completer -----
  ap_pready_const: assert property (@(posedge pclk) pready === 1'b1)
    else sva_fail("ap_pready_const");

  ap_pslverr_only_access: assert property (@(posedge pclk) disable iff (!presetn) pslverr |-> (psel && penable))
    else sva_fail("ap_pslverr_only_access");

  ap_pslverr_zero_in_reset: assert property (@(posedge pclk) !presetn |-> !pslverr)
    else sva_fail("ap_pslverr_zero_in_reset");

  ap_prdata_known: assert property (@(posedge pclk) disable iff (!presetn) (psel && penable) |-> !$isunknown(prdata))
    else sva_fail("ap_prdata_known");

  ap_reset_outputs: assert property (@(posedge pclk) $rose(presetn) |-> (tx && rts_n && !irq))
    else sva_fail("ap_reset_outputs");

  // rts_n = rx_dis | rx_done, kiểm ở chu kỳ truy cập đọc STAT (prdata là STAT). Hai chu kỳ sau lệnh ghi soft_rst được loại
  // vì spec 6.5 cho rts_n = 1 trong lúc reset mềm trong khi STAT đã về 0 (ARCH mục 5: chu kỳ 2).
  logic [1:0] srst_sh;
  wire wr_soft = psel && penable && pwrite && (paddr == ADDR_CTRL) && pstrb[1] && pwdata[8];
  always @(posedge pclk or negedge presetn)
    if (!presetn) srst_sh <= 2'b00;
    else          srst_sh <= {srst_sh[0], wr_soft};

  ap_rts_eq: assert property (@(posedge pclk) disable iff (!presetn)
      (psel && penable && !pwrite && paddr == ADDR_STAT && srst_sh == 2'b00) |-> (rts_n == (prdata[ST_RX_DIS] || prdata[ST_RX_DONE])))
    else sva_fail("ap_rts_eq");

  // ----- Phía master (tự kiểm testbench) -----
  ap_penable_after_psel: assert property (@(posedge pclk) disable iff (!presetn) penable |-> (psel && $past(psel)))
    else sva_fail("ap_penable_after_psel");

  ap_stable_in_access: assert property (@(posedge pclk) disable iff (!presetn)
      (psel && !penable) |=> $stable({paddr, pwrite, pwdata, pstrb}))
    else sva_fail("ap_stable_in_access");

  ap_psel_hold: assert property (@(posedge pclk) disable iff (!presetn) (psel && !penable) |=> psel)
    else sva_fail("ap_psel_hold");

endmodule
`default_nettype wire
