// P2.3 — spec 5.2 E5: ghi BAUD mà giá trị sau khi ghi có div_int = 0.
// Nội dung kiểm: ghi 0x0000, 0x1000, 0xF000, 0xFFFF_0000 với pstrb = 1111 → E5, BAUD giữ 0x900D; ghi lane 0 bằng 0x00 khi
//   BAUD = 0x900D (div_int = 0x00D, div_frac = 9) → E5 vì div_int sau khi ghép lane = 0; BAUD = 0x0100 rồi lane 0 = 0x00 →
//   không lỗi (div_int = 0x100); ghi 0x0001 → không lỗi; lane 0 = 0x00 khi BAUD = 0x0001 → E5.
// Diễn giải: SI-03 (ISSUE-003).
// Tiêu chí đạt: pslverr đúng từng giao dịch; BAUD đọc lại khớp mô hình.
task automatic t_p2_3();
  logic [31:0] bad [4] = '{32'h0000_0000, 32'h0000_1000, 32'h0000_F000, 32'hFFFF_0000};
  set_watchdog(200_000.0);
  tb_start();
  foreach (bad[i]) begin
    wr(ADDR_BAUD, bad[i], 4'hF, 1'b1);
    cov.sample_err(E5);
    rd_chk(ADDR_BAUD, BAUD_RESET, $sformatf("BAUD giữ nguyên sau ghi 0x%08h (E5)", bad[i]));
  end
  wr(ADDR_BAUD, 32'h0000_0000, 4'b0001, 1'b1);
  rd_chk(ADDR_BAUD, BAUD_RESET, "BAUD lane 0 = 0x00 khi div_int = 0x00D → E5 (div_int = 0), giữ 0x900D");
  wr(ADDR_BAUD, 32'h0000_0100, 4'hF, 1'b0);
  wr(ADDR_BAUD, 32'h0000_0000, 4'b0001, 1'b0);
  rd_chk(ADDR_BAUD, 32'h0100, "BAUD lane 0 = 0x00 khi div_int[11:8] = 1 không lỗi");
  wr(ADDR_BAUD, 32'h0000_0001, 4'hF, 1'b0);
  rd_chk(ADDR_BAUD, 32'h1, "BAUD = 0x0001 hợp lệ");
  wr(ADDR_BAUD, 32'h0000_0000, 4'b0001, 1'b1);
  rd_chk(ADDR_BAUD, 32'h1, "BAUD lane 0 làm div_int = 0 → E5, giữ 0x0001");
  wr(ADDR_BAUD, BAUD_RESET, 4'hF, 1'b0);
  rd_chk(ADDR_BAUD, BAUD_RESET, "BAUD về 0x900D");
endtask
