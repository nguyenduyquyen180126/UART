// P4.5 — spec 4.5, 6.2: đọc RXDATA xoá rx_done, parity_err, frame_err, overrun từ chu kỳ sau.
// Nội dung kiểm: (1) 8E1 sai parity: STAT có rx_done, parity_err; đọc RXDATA; đọc STAT liền kề: hai cờ = 0.
//   (2) 8N1 stop = 0: frame_err; đọc RXDATA; STAT liền kề: frame_err = 0. (3) hai khung liền nhau không đọc: overrun = 1;
//   đọc RXDATA (khung đầu); STAT liền kề: rx_done = overrun = 0.
// Tiêu chí đạt: cờ đúng trước khi đọc, bằng 0 ở lệnh đọc STAT liền sau lệnh đọc RXDATA.
task automatic t_p4_5();
  frame_cfg_t ce = mk_cfg(8, 0, 1, 1);
  frame_cfg_t cn = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  real fr = real'(frame_bits(cn)) * b;
  logic [31:0] s, r;
  set_watchdog(5_000_000.0);
  tb_start();
  apb.idle_mode = 0;
  uart_setup(ce, BAUD_I115200);
  utx.send(8'h5A, ce, b, 1'b1);
  wait_rx_done(fr, "P4.5 (1)", s);
  check(s[ST_PARITY_ERR] === 1'b1, "(1) parity_err = 1 trước khi đọc RXDATA");
  rd(ADDR_RXDATA, r);
  check_eq(r, 32'h5A, "(1) RXDATA");
  rd_stat(s);
  check(s[ST_RX_DONE] === 1'b0 && s[ST_PARITY_ERR] === 1'b0, $sformatf("(1) STAT = 0x%02h sau đọc RXDATA", s[7:0]));
  uart_setup(cn, BAUD_I115200);
  utx.send(8'hA5, cn, b, 1'b0, 1'b1);
  #(b);
  wait_rx_done(fr, "P4.5 (2)", s);
  check(s[ST_FRAME_ERR] === 1'b1, "(2) frame_err = 1 trước khi đọc RXDATA");
  rd(ADDR_RXDATA, r);
  check_eq(r, 32'hA5, "(2) RXDATA");
  rd_stat(s);
  check(s[ST_RX_DONE] === 1'b0 && s[ST_FRAME_ERR] === 1'b0, $sformatf("(2) STAT = 0x%02h sau đọc RXDATA", s[7:0]));
  utx.send(8'h11, cn, b);
  utx.send(8'h22, cn, b);
  #(b);
  rd_stat(s);
  check(s[ST_RX_DONE] === 1'b1 && s[ST_OVERRUN] === 1'b1, $sformatf("(3) STAT = 0x%02h có rx_done, overrun", s[7:0]));
  rd(ADDR_RXDATA, r);
  check_eq(r, 32'h11, "(3) RXDATA giữ khung đầu");
  rd_stat(s);
  check(s[ST_RX_DONE] === 1'b0 && s[ST_OVERRUN] === 1'b0, $sformatf("(3) STAT = 0x%02h sau đọc RXDATA", s[7:0]));
endtask
