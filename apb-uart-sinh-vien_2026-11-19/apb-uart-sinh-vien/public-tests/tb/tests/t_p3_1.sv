// P3.1 — spec 6.1, 4.3: bộ phát ở 115 200 baud với khung 8N1 và 8E1, 3 mẫu dữ liệu mỗi khung.
// Nội dung kiểm: UartExtRx giải mã từng khung trên tx: start bit, dữ liệu LSB trước, parity chẵn, stop bit; độ rộng bit
//   trung bình (sườn xuống start bit tới sườn cuối trong khung) lệch ≤ ±1,0 % so với 1/115 200 s.
// Tiêu chí đạt: 6 khung đúng dữ liệu, parity, stop bit, độ rộng bit; không có khung thừa trên tx.
task automatic t_p3_1();
  frame_cfg_t cfgs [2] = '{mk_cfg(8), mk_cfg(8, 0, 1, 1)};
  logic [7:0] pats [3] = '{8'h55, 8'hA3, 8'h00};
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  set_watchdog(5_000_000.0);
  tb_start();
  foreach (cfgs[i]) begin
    uart_setup(cfgs[i], BAUD_I115200);
    foreach (pats[j]) begin
      tx_and_check(pats[j], cfgs[i], b, $sformatf("P3.1 %s data 0x%02h", cfg_str(cfgs[i]), pats[j]));
      cov.sample_frame(cfgs[i], BAUD_I115200);
    end
  end
  #(12.0 * b);
  check(urx.pending() == 0, $sformatf("không có khung thừa trên tx, thu được thêm %0d", urx.pending()));
endtask
