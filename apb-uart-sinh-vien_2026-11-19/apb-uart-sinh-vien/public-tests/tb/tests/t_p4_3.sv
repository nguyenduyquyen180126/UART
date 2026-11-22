// P4.3 — spec 6.2: cờ parity_err với parity chẵn và lẻ; dữ liệu vẫn vào RXDATA.
// Nội dung kiểm: 8E1 và 8O1 ở 115 200 baud: khung sai parity → rx_done = 1, parity_err = 1, frame_err = 0, RXDATA đúng;
//   đọc RXDATA xoá cờ; khung đúng tiếp theo → parity_err = 0.
// Tiêu chí đạt: 4 khung đúng cờ và dữ liệu.
task automatic t_p4_3();
  frame_cfg_t cfgs [2] = '{mk_cfg(8, 0, 1, 1), mk_cfg(8, 0, 1, 0)};
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  logic [7:0] d;
  set_watchdog(5_000_000.0);
  tb_start();
  foreach (cfgs[i]) begin
    uart_setup(cfgs[i], BAUD_I115200);
    d = 8'($urandom);
    rx_and_check(d, cfgs[i], b, $sformatf("P4.3 %s sai parity", cfg_str(cfgs[i])), 1'b1);
    d = 8'($urandom);
    rx_and_check(d, cfgs[i], b, $sformatf("P4.3 %s đúng parity", cfg_str(cfgs[i])));
  end
endtask
