// P2.2 — spec 5.2 E3: ghi TXDATA hoặc CTRL.start_tx khi tx_done = 0.
// Nội dung kiểm: phát một khung 8N1 ở 2 400 baud (khung dài 4,17 ms); trong lúc tx_done = 0: ghi TXDATA → E3 và TXDATA
//   giữ giá trị cũ; ghi CTRL start_tx = 1 → E3; ghi CTRL pwdata[0] = 1 với pstrb[0] = 0 → không lỗi; ghi CTRL = 0 → không
//   lỗi. Sau tx_done = 1: ghi TXDATA bình thường. Chỉ một khung xuất hiện trên tx.
// Tiêu chí đạt: pslverr đúng từng giao dịch; TXDATA không đổi khi lỗi; đúng một khung 0x3C trên tx.
task automatic t_p2_2();
  frame_cfg_t c = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I2400]);
  real fr = real'(frame_bits(c)) * b;
  logic [31:0] s;
  rx_frame_t f;
  bit ok;
  set_watchdog(5.0 * fr);
  tb_start();
  uart_setup(c, BAUD_I2400);
  tx_char(8'h3C);
  rd_stat(s);
  check(s[ST_TX_DONE] === 1'b0, "tx_done = 0 sau start_tx");
  wr(ADDR_TXDATA, 32'h11, 4'hF, 1'b1);
  cov.sample_err(E3);
  rd_chk(ADDR_TXDATA, 32'h3C, "TXDATA giữ nguyên sau lệnh ghi lỗi E3");
  wr(ADDR_CTRL, CTRL_START_TX, 4'hF, 1'b1);
  wr(ADDR_CTRL, CTRL_START_TX, 4'b1110, 1'b0);
  wr(ADDR_CTRL, 32'h0, 4'hF, 1'b0);
  wr(ADDR_CTRL, 32'h2, 4'hF, 1'b0);
  wait_tx_done(2.0 * fr, "P2.2");
  get_frame(fr, "P2.2", ok, f);
  if (ok) check_frame(f, 8'h3C, c, b, "P2.2 khung 1");
  wr(ADDR_TXDATA, 32'h11, 4'hF, 1'b0);
  rd_chk(ADDR_TXDATA, 32'h11, "TXDATA ghi được khi tx_done = 1");
  #(fr);
  check(urx.pending() == 0, $sformatf("chỉ một khung trên tx, thu được thêm %0d", urx.pending()));
endtask
