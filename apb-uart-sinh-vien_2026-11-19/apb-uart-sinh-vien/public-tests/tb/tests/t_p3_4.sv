// P3.4 — spec 6.5: soft_rst giữa khung đang phát.
// Nội dung kiểm: phát 0x55 ở 9 600 baud; sau 3,5 bit ghi CTRL.soft_rst: tx = 1 trong 2 chu kỳ sau sườn kết thúc lệnh
//   ghi; từ chu kỳ thứ 3 đọc STAT = 0x1, BAUD = 0x900D, CFG = 0; sau đó phát 0xA5 ở 115 200 baud 8N1 đúng.
// Tiêu chí đạt: tx = 1 đúng hạn, thanh ghi về reset, khung sau reset mềm đúng.
task automatic t_p3_4();
  frame_cfg_t c = mk_cfg(8);
  real b9600 = bit_ns(BAUD_RATE[BAUD_I9600]);
  real b = bit_ns(BAUD_RATE[BAUD_I115200]);
  set_watchdog(20_000_000.0);
  tb_start();
  uart_setup(c, BAUD_I9600);
  fork
    tx_char(8'h55);
    begin
      @(negedge vuart.tx);
      #(3.5 * b9600);
    end
  join
  wr(ADDR_CTRL, CTRL_SOFT_RST);
  repeat (2) @(vapb.cb);
  #1;
  check(vuart.tx === 1'b1, "tx = 1 trong 2 chu kỳ sau soft_rst");
  rm.reset();
  rd_chk(ADDR_STAT, STAT_RESET, "STAT sau soft_rst");
  rd_chk(ADDR_BAUD, BAUD_RESET, "BAUD sau soft_rst");
  rd_chk(ADDR_CFG,  32'h0,      "CFG sau soft_rst");
  #(real'(frame_bits(c)) * b9600);
  urx.flush();
  uart_setup(c, BAUD_I115200);
  tx_and_check(8'hA5, c, b, "P3.4 khung sau soft_rst");
endtask
