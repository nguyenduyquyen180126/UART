// P7.1 — spec 1, 6: song công 100 ký tự mỗi chiều ở 115 200 baud 8N1.
// Nội dung kiểm: hai luồng song song: CPU phát 100 ký tự ngẫu nhiên (UartExtRx kiểm từng khung); bên ngoài phát 100 ký
//   tự ngẫu nhiên vào rx, chỉ phát khi rts_n = 0; CPU đọc STAT, RXDATA cho từng khung; cts_n = 0 suốt test.
// Tiêu chí đạt: 200 khung đúng dữ liệu, không cờ lỗi, không overrun, không khung thừa trên tx.
task automatic t_p7_1();
  frame_cfg_t c = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  localparam int N = 100;
  set_watchdog(60_000_000.0);
  tb_start();
  uart_setup(c, BAUD_I115200);
  utx.set_cts_n(1'b0);
  fork
    begin
      for (int i = 0; i < N; i++) begin
        logic [7:0] d = 8'($urandom);
        tx_and_check(d, c, b, $sformatf("P7.1 TX %0d", i));
      end
    end
    begin
      for (int i = 0; i < N; i++) begin
        logic [7:0] d = 8'($urandom);
        wait (vuart.rts_n === 1'b0);
        rx_and_check(d, c, b, $sformatf("P7.1 RX %0d", i));
      end
    end
  join
  #(12.0 * b);
  check(urx.pending() == 0, $sformatf("không có khung thừa trên tx, thu được thêm %0d", urx.pending()));
  cov.sample_frame(c, BAUD_I115200, 0.0);
endtask
