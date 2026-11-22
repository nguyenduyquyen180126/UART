// P3.2 — spec 6.3: thời điểm tx_done với 1 và 2 stop bit.
// Nội dung kiểm: sau lệnh start_tx, lệnh đọc STAT liền kề thấy tx_done = 0; đọc STAT liên tục (mỗi 2 chu kỳ) tới khi
//   tx_done = 1; thời điểm sườn kết thúc lần đọc đó nằm trong [t_end − 2T, t_end + 6T] với t_end = sườn xuống start bit
//   + số bit khung × độ dài bit danh định, T = 40 ns (2 chu kỳ trễ của DUT + 2 chu kỳ phân giải của phép đọc).
// Tiêu chí đạt: 2 khung (8N1, 8N2) đúng, tx_done đúng thời điểm.
task automatic t_p3_2();
  frame_cfg_t cfgs [2] = '{mk_cfg(8), mk_cfg(8, 1)};
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  logic [31:0] s;
  rx_frame_t f;
  bit ok;
  real t_obs, fr;
  set_watchdog(5_000_000.0);
  tb_start();
  apb.idle_mode = 0;
  foreach (cfgs[i]) begin
    uart_setup(cfgs[i], BAUD_I115200);
    fr = real'(frame_bits(cfgs[i])) * b;
    tx_char(8'h55);
    rd_stat(s);
    check(s[ST_TX_DONE] === 1'b0, $sformatf("%s: tx_done = 0 ở lệnh đọc liền sau start_tx", cfg_str(cfgs[i])));
    wait_tx_done(3.0 * fr, cfg_str(cfgs[i]));
    t_obs = apb.t_access;
    get_frame(fr, cfg_str(cfgs[i]), ok, f);
    if (ok) begin
      check_frame(f, 8'h55, cfgs[i], b, {"P3.2 ", cfg_str(cfgs[i])});
      check(t_obs >= f.t_end - 2.0 * T_PCLK_NS && t_obs <= f.t_end + 6.0 * T_PCLK_NS,
            $sformatf("%s: tx_done = 1 quan sát tại %.1f ns, cuối stop bit cuối %.1f ns (lệch %.1f ns)",
                      cfg_str(cfgs[i]), t_obs, f.t_end, t_obs - f.t_end));
    end
  end
endtask
