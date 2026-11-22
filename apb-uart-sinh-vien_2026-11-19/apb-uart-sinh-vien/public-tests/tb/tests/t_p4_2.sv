// P4.2 — spec 6.2: xung thấp 0,30 và 0,39 bit trên đường nghỉ không tạo khung.
// Nội dung kiểm: ở 115 200 baud 8N1, phát xung thấp 0,30 bit rồi 0,39 bit; sau mỗi xung đọc STAT ở 2 bit và 12 bit sau:
//   STAT = 0x1 (không rx_busy, không rx_done, không cờ lỗi). Sau đó một khung 0x5A đúng được nhận.
// Tiêu chí đạt: STAT = 0x1 ở 4 lần đọc; khung 0x5A đúng.
task automatic t_p4_2();
  frame_cfg_t c = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  real widths [2] = '{0.30, 0.39};
  set_watchdog(5_000_000.0);
  tb_start();
  uart_setup(c, BAUD_I115200);
  foreach (widths[i]) begin
    utx.glitch(widths[i] * b);
    #(2.0 * b);
    rd_chk(ADDR_STAT, STAT_RESET, $sformatf("STAT 2 bit sau xung %.2f bit", widths[i]));
    #(10.0 * b);
    rd_chk(ADDR_STAT, STAT_RESET, $sformatf("STAT 12 bit sau xung %.2f bit", widths[i]));
  end
  rx_and_check(8'h5A, c, b, "P4.2 khung sau xung nhiễu");
endtask
