// P5.2 — spec 6.4: rts_n = 0 khi rx_dis = 0 và rx_done = 0; rts_n = 1 ngay khi rx_done = 1; về 0 sau khi đọc RXDATA.
// Nội dung kiểm: sau reset rts_n = 0; nhận một khung 8N1: ở lần đọc STAT đầu tiên thấy rx_done = 1, rts_n = 1; đọc
//   RXDATA: rts_n = 0 sau 2 chu kỳ; assertion ap_rts_eq kiểm ở mọi lần đọc STAT.
// Tiêu chí đạt: 3 giá trị rts_n đúng; khung đúng.
task automatic t_p5_2();
  frame_cfg_t c = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  real fr = real'(frame_bits(c)) * b;
  logic [31:0] s, r;
  set_watchdog(5_000_000.0);
  tb_start();
  @(negedge vapb.pclk);
  check(vuart.rts_n === 1'b0, "rts_n = 0 sau reset (rx_dis = 0, rx_done = 0)");
  uart_setup(c, BAUD_I115200);
  utx.send(8'h4B, c, b);
  wait_rx_done(fr, "P5.2", s);
  #1;
  check(vuart.rts_n === 1'b1, "rts_n = 1 khi rx_done = 1");
  rd(ADDR_RXDATA, r);
  check_eq(r, 32'h4B, "RXDATA");
  repeat (2) @(vapb.cb);
  #1;
  check(vuart.rts_n === 1'b0, "rts_n = 0 sau khi đọc RXDATA");
endtask
