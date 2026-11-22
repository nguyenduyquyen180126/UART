// P5.1 — spec 6.2: overrun khi khung thứ hai tới lúc rx_done = 1.
// Nội dung kiểm: hai khung 8N1 liền nhau không đọc: rx_done = 1, overrun = 1, RXDATA giữ khung đầu, parity_err =
//   frame_err = 0; đọc RXDATA xoá cờ; khung thứ ba nhận bình thường.
// Tiêu chí đạt: cờ và dữ liệu đúng ở 3 khung.
task automatic t_p5_1();
  frame_cfg_t c = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  logic [31:0] s, r;
  set_watchdog(5_000_000.0);
  tb_start();
  uart_setup(c, BAUD_I115200);
  utx.send(8'hD1, c, b);
  utx.send(8'hD2, c, b);
  #(b);
  rd_stat(s);
  check(s[ST_RX_DONE] === 1'b1,    "rx_done = 1 sau hai khung");
  check(s[ST_OVERRUN] === 1'b1,    "overrun = 1 sau hai khung");
  check(s[ST_PARITY_ERR] === 1'b0 && s[ST_FRAME_ERR] === 1'b0, "không có parity_err, frame_err");
  rd(ADDR_RXDATA, r);
  check_eq(r, 32'hD1, "RXDATA giữ khung đầu");
  rd_stat(s);
  check(s[ST_RX_DONE] === 1'b0 && s[ST_OVERRUN] === 1'b0, $sformatf("STAT = 0x%02h sau đọc RXDATA", s[7:0]));
  rx_and_check(8'hD3, c, b, "P5.1 khung thứ ba");
endtask
