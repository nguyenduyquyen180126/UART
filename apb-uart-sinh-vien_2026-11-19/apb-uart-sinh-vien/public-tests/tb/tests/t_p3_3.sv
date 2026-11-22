// P3.3 — spec 6.3: cts_n lên 1 giữa khung thì khung vẫn phát hết; cts_n = 1 trước khi phát thì bộ phát chờ.
// Nội dung kiểm: (1) phát 0xC3 ở 115 200 baud 8N1, sau 3,5 bit kể từ start bit đặt cts_n = 1: khung đủ 10 bit, đúng dữ
//   liệu, tx_done = 1. (2) cts_n = 1 rồi mới start_tx: sau 2 độ dài khung tx vẫn 1, không có khung, tx_done = 0;
//   đặt cts_n = 0: khung phát, đúng dữ liệu.
// Tiêu chí đạt: 2 khung đúng; không có khung trong lúc cts_n = 1 ở phần (2).
task automatic t_p3_3();
  frame_cfg_t c = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  real fr = real'(frame_bits(c)) * b;
  logic [31:0] s;
  rx_frame_t f;
  bit ok;
  set_watchdog(5_000_000.0);
  tb_start();
  uart_setup(c, BAUD_I115200);
  utx.set_cts_n(1'b0);
  fork
    tx_char(8'hC3);
    begin
      @(negedge vuart.tx);
      #(3.5 * b);
      utx.set_cts_n(1'b1);
    end
  join
  wait_tx_done(3.0 * fr, "P3.3 (1)");
  get_frame(fr, "P3.3 (1)", ok, f);
  if (ok) check_frame(f, 8'hC3, c, b, "P3.3 (1) cts_n lên 1 giữa khung");
  check(vuart.tx === 1'b1, "tx = 1 sau khung");
  tx_char(8'h3C);
  #(2.0 * fr);
  check(vuart.tx === 1'b1, "tx = 1 khi chờ cts_n");
  check(urx.pending() == 0, "không có khung khi cts_n = 1");
  rd_stat(s);
  check(s[ST_TX_DONE] === 1'b0, "tx_done = 0 khi chờ cts_n");
  utx.set_cts_n(1'b0);
  wait_tx_done(3.0 * fr, "P3.3 (2)");
  get_frame(fr, "P3.3 (2)", ok, f);
  if (ok) check_frame(f, 8'h3C, c, b, "P3.3 (2) phát sau khi cts_n = 0");
endtask
