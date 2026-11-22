// P6.1 — spec 7: ngắt tx_done_ie.
// Nội dung kiểm: IER = 0x1 khi bộ phát rảnh: irq = 1 sau ≤ 2 chu kỳ; start_tx (9 600 baud): irq = 0 sau ≤ 2 chu kỳ kể từ
//   tx_done = 0; sau khung: irq = 1 trong ≤ 2 chu kỳ kể từ lần đọc thấy tx_done = 1; IER = 0: irq = 0.
// Tiêu chí đạt: 4 giá trị irq đúng; khung đúng.
task automatic t_p6_1();
  frame_cfg_t c = mk_cfg(8);
  real b = bit_ns(BAUD_RATE[BAUD_I9600]);
  real fr = real'(frame_bits(c)) * b;
  rx_frame_t f;
  bit ok;
  set_watchdog(20_000_000.0);
  tb_start();
  uart_setup(c, BAUD_I9600);
  wr(ADDR_IER, IER_TX_DONE);
  repeat (2) @(vapb.cb);
  #1;
  check(vuart.irq === 1'b1, "irq = 1 khi tx_done = 1 và tx_done_ie = 1");
  cov.sample_irq(1);
  tx_char(8'h33);
  repeat (2) @(vapb.cb);
  #1;
  check(vuart.irq === 1'b0, "irq = 0 sau start_tx");
  wait_tx_done(3.0 * fr, "P6.1");
  repeat (2) @(vapb.cb);
  #1;
  check(vuart.irq === 1'b1, "irq = 1 sau khi phát xong");
  get_frame(fr, "P6.1", ok, f);
  if (ok) check_frame(f, 8'h33, c, b, "P6.1 khung");
  wr(ADDR_IER, 32'h0);
  repeat (2) @(vapb.cb);
  #1;
  check(vuart.irq === 1'b0, "irq = 0 khi IER = 0");
endtask
