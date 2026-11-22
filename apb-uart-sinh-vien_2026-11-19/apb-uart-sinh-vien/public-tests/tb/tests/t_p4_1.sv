// P4.1 — spec 6.2: bộ thu ở 115 200 baud, δ = 0, 8 khung với dạng khung chọn ngẫu nhiên trong 24 dạng.
// Nội dung kiểm: mỗi khung: ghi CFG, bên ngoài phát dữ liệu ngẫu nhiên, đọc STAT tới rx_done = 1, kiểm parity_err =
//   frame_err = overrun = 0, RXDATA đúng (bit [7:N] = 0), đọc RXDATA xoá cờ.
// Tiêu chí đạt: 8 khung đúng.
task automatic t_p4_1();
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  frame_cfg_t c;
  logic [7:0] d;
  set_watchdog(5_000_000.0);
  tb_start();
  for (int i = 0; i < 8; i++) begin
    c = cfg_of_index($urandom_range(0, 23));
    d = 8'($urandom);
    uart_setup(c, BAUD_I115200);
    rx_and_check(d, c, b, $sformatf("P4.1 khung %0d %s data 0x%02h", i, cfg_str(c), d));
    cov.sample_frame(c, BAUD_I115200, 0.0);
  end
endtask
