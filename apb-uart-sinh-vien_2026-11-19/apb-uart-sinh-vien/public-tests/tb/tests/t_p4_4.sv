// P4.4 — spec 6.2: cờ frame_err khi stop bit bằng 0.
// Nội dung kiểm: 8N1 stop bit = 0; 8N2 stop bit thứ hai = 0; 8N2 cả hai stop bit = 0 → frame_err = 1, parity_err = 0,
//   RXDATA đúng; đọc RXDATA xoá cờ; khung đúng tiếp theo → frame_err = 0.
// Tiêu chí đạt: 6 khung đúng cờ và dữ liệu.
task automatic t_p4_4();
  frame_cfg_t c1 = mk_cfg(8);
  frame_cfg_t c2 = mk_cfg(8, 1);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  set_watchdog(5_000_000.0);
  tb_start();
  uart_setup(c1, BAUD_I115200);
  rx_and_check(8'h96, c1, b, "P4.4 8N1 stop = 0", 1'b0, 1'b1, 1'b0);
  rx_and_check(8'h69, c1, b, "P4.4 8N1 khung đúng");
  uart_setup(c2, BAUD_I115200);
  rx_and_check(8'h3C, c2, b, "P4.4 8N2 stop 2 = 0", 1'b0, 1'b0, 1'b1);
  rx_and_check(8'hC3, c2, b, "P4.4 8N2 khung đúng");
  rx_and_check(8'h81, c2, b, "P4.4 8N2 cả hai stop = 0", 1'b0, 1'b1, 1'b1);
  rx_and_check(8'h7E, c2, b, "P4.4 8N2 khung đúng cuối");
endtask
