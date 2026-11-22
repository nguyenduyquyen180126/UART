// P1.3 — spec 5.1: ghi theo byte lane pstrb cho TXDATA, CFG, BAUD, IER; pstrb = 0000 không đổi thanh ghi và không lỗi.
// Nội dung kiểm: với mỗi thanh ghi, ghi từng lane 0..3 bằng dữ liệu ngẫu nhiên rồi đọc lại; so với mô hình có mặt nạ
//   rfu (bit rfu đọc 0). Sau đó ghi 0xFFFF_FFFF với pstrb = 0000: giá trị giữ nguyên, pslverr = 0.
// Tiêu chí đạt: mọi lần đọc lại khớp mô hình; không có pslverr ngoài dự đoán.
// Diễn giải: dữ liệu ghi BAUD giữ div_int[11:8] ≠ 0 để không chạm E5 (E5 có test riêng P2.3).
task automatic t_p1_3();
  logic [11:0] regs [4] = '{ADDR_TXDATA, ADDR_CFG, ADDR_BAUD, ADDR_IER};
  logic [31:0] w;
  set_watchdog(200_000.0);
  tb_start();
  foreach (regs[r]) begin
    for (int lane = 0; lane < 4; lane++) begin
      w = $urandom;
      if (regs[r] == ADDR_BAUD) w[11:8] = 4'h9;
      wr(regs[r], w, 4'(1 << lane));
      rd_chk(regs[r], rm.exp_read(regs[r]), $sformatf("ghi 0x%03h lane %0d", regs[r], lane));
    end
    wr(regs[r], 32'hFFFF_FFFF, 4'hF);
    rd_chk(regs[r], rm.exp_read(regs[r]), $sformatf("ghi 0x%03h đủ 4 lane toàn 1 (bit rfu đọc 0)", regs[r]));
  end
  foreach (regs[r]) begin
    wr(regs[r], 32'hFFFF_FFFF, 4'h0);
    rd_chk(regs[r], rm.exp_read(regs[r]), $sformatf("ghi 0x%03h pstrb = 0000 không đổi", regs[r]));
  end
  check_model_regs("cuối P1.3");
endtask
