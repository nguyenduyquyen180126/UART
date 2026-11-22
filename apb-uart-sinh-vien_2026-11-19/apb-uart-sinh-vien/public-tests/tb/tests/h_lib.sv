// h_lib — tiện ích dùng chung cho các test H: họ test theo tốc độ (TX, RX), chùm khung liền nhau, đo thời điểm
// tx_done và rx_done, bộ đếm mẫu tín hiệu theo chu kỳ.

  function automatic real frame_ns(frame_cfg_t c, real b);
    return real'(frame_bits(c)) * b;
  endfunction

  function automatic frame_cfg_t random_cfg();
    return cfg_of_index($urandom_range(0, 23));
  endfunction

  // Phát 24 dạng khung × n_pat mẫu ở tốc độ bi; mẫu đầu 0x55, các mẫu sau ngẫu nhiên
  task automatic tx_sweep(int bi, int n_pat, string tag);
    real b = bit_ns(BAUD_RATE[bi]);
    frame_cfg_t c;
    logic [7:0] d;
    poll_gap_ns = b / 8.0;
    for (int i = 0; i < 24; i++) begin
      c = cfg_of_index(i);
      uart_setup(c, bi);
      for (int p = 0; p < n_pat; p++) begin
        d = (p == 0) ? 8'h55 : 8'($urandom);
        tx_and_check(d, c, b, $sformatf("%s %s #%0d 0x%02h", tag, cfg_str(c), p, d));
      end
      cov.sample_frame(c, bi);
    end
    poll_gap_ns = 0.0;
  endtask

  // Bên ngoài phát n khung liền nhau (không nghỉ) với độ dài bit b; CPU đọc từng khung trước khi khung sau kết thúc
  task automatic rx_burst(frame_cfg_t c, real b, int n, string tag);
    logic [7:0] ds [$];
    real fr = frame_ns(c, b);
    for (int i = 0; i < n; i++) begin
      logic [7:0] d = 8'($urandom);
      ds.push_back(d);
      sb.expect_frame(data_mask(c, d), 1'b0, 1'b0, 1'b0, $sformatf("%s khung %0d", tag, i));
    end
    fork
      foreach (ds[i]) utx.send(ds[i], c, b);
      begin
        logic [31:0] s, r;
        for (int i = 0; i < n; i++) begin
          wait_rx_done(2.0 * fr + 10_000.0, $sformatf("%s khung %0d", tag, i), s);
          rd(ADDR_RXDATA, r);
          sb.check_rx(r, s);
        end
      end
    join
    #(2.0 * b);
  endtask

  // 24 dạng khung ở tốc độ bi, bên phát lệch delta, per_cfg khung liền nhau mỗi dạng
  task automatic rx_sweep(int bi, real delta, int per_cfg, string tag);
    real b = bit_ns(BAUD_RATE[bi], delta);
    frame_cfg_t c;
    poll_gap_ns = b / 16.0;
    for (int i = 0; i < 24; i++) begin
      c = cfg_of_index(i);
      uart_setup(c, bi);
      rx_burst(c, b, per_cfg, $sformatf("%s %s", tag, cfg_str(c)));
      cov.sample_frame(c, bi, delta);
    end
    poll_gap_ns = 0.0;
  endtask

  // Thời điểm tx_done: 0 ở lệnh đọc liền sau start_tx; 1 trong [t_end − 2T, t_end + 6T] (poll STAT mỗi 2 chu kỳ, SI-06)
  task automatic tx_done_timing(frame_cfg_t c, int bi, logic [7:0] d, string tag);
    real b = bit_ns(BAUD_RATE[bi]);
    real fr = frame_ns(c, b);
    logic [31:0] s;
    rx_frame_t f;
    bit ok;
    real t_obs;
    apb.idle_mode = 0;
    poll_gap_ns = 0.0;
    uart_setup(c, bi);
    tx_char(d);
    rd_stat(s);
    check(s[ST_TX_DONE] === 1'b0, {tag, ": tx_done = 0 ở lệnh đọc liền sau start_tx"});
    wait_tx_done(3.0 * fr, tag);
    t_obs = apb.t_access;
    get_frame(fr, tag, ok, f);
    if (ok) begin
      check_frame(f, d, c, b, tag);
      check(t_obs >= f.t_end - 2.0 * T_PCLK_NS && t_obs <= f.t_end + 6.0 * T_PCLK_NS,
            $sformatf("%s: tx_done = 1 quan sát tại %.1f ns, cuối stop bit cuối %.1f ns (lệch %.1f ns)", tag, t_obs, f.t_end, t_obs - f.t_end));
    end
  endtask

  // Thời điểm rx_done (SI-08): lần đọc STAT đầu tiên thấy rx_done = 1 nằm trong
  // [t_fall + (N − 9/16)·b + T, t_fall + (N − 1/2)·b + 8T]; rx_busy = 0 cùng lần đọc đó và = 1 ở lần đọc trước
  task automatic rx_done_timing(frame_cfg_t c, int bi, logic [7:0] d, string tag);
    real b = bit_ns(BAUD_RATE[bi]);
    int n = frame_bits(c);
    real t_fall, t_obs, lo, hi;
    logic [31:0] s, r;
    bit seen = 1'b0;
    logic busy_prev = 1'b0;
    apb.idle_mode = 0;
    poll_gap_ns = 0.0;
    uart_setup(c, bi);
    t_fall = $realtime;
    fork
      utx.send(d, c, b, 1'b0, 1'b0, 1'b0, 2.0);
      begin
        while (!seen && $realtime < t_fall + real'(n + 2) * b) begin
          rd_stat(s);
          if (s[ST_RX_DONE] === 1'b1) begin
            seen  = 1'b1;
            t_obs = apb.t_access;
            check(s[ST_RX_BUSY] === 1'b0, {tag, ": rx_busy = 0 ở lần đọc thấy rx_done = 1"});
            check(busy_prev === 1'b1, {tag, ": rx_busy = 1 ở lần đọc ngay trước"});
          end else busy_prev = s[ST_RX_BUSY];
        end
      end
    join
    check(seen, {tag, ": rx_done không lên 1"});
    lo = t_fall + (real'(n) - 0.5625) * b + T_PCLK_NS;
    hi = t_fall + (real'(n) - 0.5) * b + 8.0 * T_PCLK_NS;
    if (seen)
      check(t_obs >= lo && t_obs <= hi,
            $sformatf("%s: rx_done quan sát tại %.1f ns, cửa sổ [%.1f, %.1f] ns", tag, t_obs, lo, hi));
    rd(ADDR_RXDATA, r);
    check_eq(r, {24'h0, data_mask(c, d)}, {tag, ": RXDATA"});
  endtask

  // Reset mềm giữa chừng rồi chờ hết thời gian khung dở trên tx để UartExtRx không giữ khung rác
  task automatic soft_reset_settle(real settle_ns);
    soft_reset();
    #(settle_ns);
    urx.flush();
    sb.q.delete();
  endtask

  // Đọc STAT tại thời điểm gọi, trả về bit chọn
  task automatic stat_bit(int bitpos, output logic v);
    logic [31:0] s;
    rd_stat(s);
    v = s[bitpos];
  endtask

  // ----- Song công (G7): một đợt n ký tự mỗi chiều với cấu hình c ở tốc độ bi; bên ngoài tuân rts_n, CPU tuân cts_n
  // (luồng cts ngẫu nhiên kéo cts_n = 1 trong 0,2–1,5 khung giữa các khung); err_pct: tỉ lệ % khung RX bị tiêm lỗi
  task automatic duplex_batch(frame_cfg_t c, int bi, int n, int err_pct, string tag);
    real b = bit_ns(BAUD_RATE[bi]);
    real fr = frame_ns(c, b);
    bit done = 1'b0;
    uart_setup(c, bi);
    poll_gap_ns = b / 4.0;
    fork
      begin : cts_thread
        while (!done) begin
          #($urandom_range(0, int'(3.0 * fr)));
          if (!done) begin
            utx.set_cts_n(1'b1);
            #($urandom_range(int'(0.2 * fr), int'(1.5 * fr)));
            utx.set_cts_n(1'b0);
          end
        end
      end
    join_none
    fork
      begin : tx_thread
        rx_frame_t f;
        bit ok;
        for (int i = 0; i < n; i++) begin
          logic [7:0] d = 8'($urandom);
          tx_char(d);
          wait_tx_done(6.0 * fr + 10_000.0, $sformatf("%s TX %0d", tag, i));
          get_frame(2.0 * fr, $sformatf("%s TX %0d", tag, i), ok, f);
          if (ok) check_frame(f, d, c, b, $sformatf("%s TX %0d", tag, i));
        end
      end
      begin : rx_thread
        logic [31:0] s, r;
        for (int i = 0; i < n; i++) begin
          logic [7:0] d = 8'($urandom);
          bit ip = 1'b0, is1 = 1'b0, is2 = 1'b0;
          if (err_pct > 0 && $urandom_range(0, 99) < err_pct) begin
            case ($urandom_range(0, 2))
              0: ip  = 1'b1;
              1: is1 = 1'b1;
              default: is2 = 1'b1;
            endcase
          end
          sb.expect_frame(data_mask(c, d), c.parity_en & ip, is1 | (c.stop_bits & is2), 1'b0, $sformatf("%s RX %0d", tag, i));
          wait (vuart.rts_n === 1'b0);
          utx.send(d, c, b, ip, is1, is2, 1.0);
          wait_rx_done(fr + 10_000.0, $sformatf("%s RX %0d", tag, i), s);
          rd(ADDR_RXDATA, r);
          sb.check_rx(r, s);
        end
      end
    join
    done = 1'b1;
    utx.set_cts_n(1'b0);
    poll_gap_ns = 0.0;
  endtask
