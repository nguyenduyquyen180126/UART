// P2.1 — spec 5.2 E1: địa chỉ ngoài bảng và địa chỉ không căn 4 byte.
// Nội dung kiểm: đọc và ghi tại 0x1C, 0xFFC, 0x01, 0x06, 0x020, 0x800: pslverr = 1, đọc trả 0; sau đó 7 thanh ghi
//   không đổi so với mô hình.
// Tiêu chí đạt: 12 giao dịch đều có pslverr = 1, prdata = 0; thanh ghi RW giữ giá trị đã ghi trước đó.
task automatic t_p2_1();
  logic [11:0] bad [6] = '{12'h01C, 12'hFFC, 12'h001, 12'h006, 12'h020, 12'h800};
  logic [31:0] d;
  set_watchdog(200_000.0);
  tb_start();
  wr(ADDR_TXDATA, 32'h5A);
  wr(ADDR_CFG,    32'h7F);
  wr(ADDR_BAUD,   32'h8145);
  wr(ADDR_IER,    32'h0);
  foreach (bad[i]) begin
    rd(bad[i], d, 1'b1);
    check_eq(d, 32'h0, $sformatf("đọc địa chỉ sai 0x%03h trả 0", bad[i]));
    cov.sample_err(E1);
    wr(bad[i], 32'hFFFF_FFFF, 4'hF, 1'b1);
  end
  check_model_regs("sau E1");
  rd_chk(ADDR_STAT,   32'h31, "STAT sau E1 (tx_dis, rx_dis, tx_done)");
  rd_chk(ADDR_RXDATA, 32'h0,  "RXDATA sau E1");
endtask
