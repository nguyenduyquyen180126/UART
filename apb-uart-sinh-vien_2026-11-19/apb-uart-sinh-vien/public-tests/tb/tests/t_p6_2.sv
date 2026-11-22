// P6.2 — spec 6.5: soft_rst đưa CFG, BAUD, IER, TXDATA về reset, tx = 1, rts_n = 1 trong lúc reset; lệnh APB bình thường từ
//   chu kỳ thứ 3.
// Nội dung kiểm: ghi CFG = 0x1A, BAUD = 0x8145, IER = 0x7, TXDATA = 0xA5 (irq = 1 do tx_done); ghi soft_rst; lấy mẫu rts_n
//   ở 2 chu kỳ reset (ít nhất một mẫu = 1); từ chu kỳ thứ 3 đọc TXDATA = 0, CFG = 0, CTRL = 0, BAUD = 0x900D, IER = 0,
//   STAT = 0x1; irq = 0, tx = 1, rts_n = 0; phát một khung 8N1 ở 115 200 baud đúng.
// Tiêu chí đạt: mọi giá trị đúng.
// Diễn giải: "mọi thanh ghi" ở spec 6.5 gồm TXDATA; rts_n = 1 chỉ trong 2 chu kỳ reset mềm, sau đó theo spec 6.4.
task automatic t_p6_2();
  frame_cfg_t c = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  logic r1, r2;
  set_watchdog(5_000_000.0);
  tb_start();
  wr(ADDR_CFG,    32'h1A);
  wr(ADDR_BAUD,   32'h8145);
  wr(ADDR_IER,    32'h7);
  wr(ADDR_TXDATA, 32'hA5);
  repeat (2) @(vapb.cb);
  #1;
  check(vuart.irq === 1'b1, "irq = 1 trước soft_rst (tx_done_ie)");
  check(vuart.rts_n === 1'b0, "rts_n = 0 trước soft_rst");
  wr(ADDR_CTRL, CTRL_SOFT_RST);
  #1;
  r1 = vuart.rts_n;
  @(vapb.cb);
  #1;
  r2 = vuart.rts_n;
  check(r1 === 1'b1 || r2 === 1'b1, $sformatf("rts_n = 1 trong 2 chu kỳ reset mềm (mẫu %b, %b)", r1, r2));
  @(vapb.cb);
  rm.reset();
  check_model_regs("sau soft_rst");
  rd_chk(ADDR_STAT, STAT_RESET, "STAT sau soft_rst");
  #1;
  check(vuart.irq === 1'b0,   "irq = 0 sau soft_rst (IER = 0)");
  check(vuart.tx === 1'b1,    "tx = 1 sau soft_rst");
  check(vuart.rts_n === 1'b0, "rts_n = 0 sau khi reset mềm hoàn tất");
  uart_setup(c, BAUD_I115200);
  tx_and_check(8'h5C, c, b, "P6.2 khung sau soft_rst");
endtask
