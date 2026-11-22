// P1.2 — spec mục 4: giá trị reset của mọi thanh ghi.
// Nội dung kiểm: sau reset đọc 7 địa chỉ: TXDATA = 0, RXDATA = 0, CFG = 0, CTRL = 0, STAT = 0x1, BAUD = 0x900D, IER = 0.
// Tiêu chí đạt: 7 giá trị đúng, pslverr = 0 ở mọi lần đọc.
task automatic t_p1_2();
  set_watchdog(100_000.0);
  tb_start();
  rd_chk(ADDR_TXDATA, 32'h0,      "reset TXDATA");
  rd_chk(ADDR_RXDATA, 32'h0,      "reset RXDATA");
  rd_chk(ADDR_CFG,    32'h0,      "reset CFG");
  rd_chk(ADDR_CTRL,   32'h0,      "reset CTRL");
  rd_chk(ADDR_STAT,   STAT_RESET, "reset STAT");
  rd_chk(ADDR_BAUD,   BAUD_RESET, "reset BAUD");
  rd_chk(ADDR_IER,    32'h0,      "reset IER");
endtask
