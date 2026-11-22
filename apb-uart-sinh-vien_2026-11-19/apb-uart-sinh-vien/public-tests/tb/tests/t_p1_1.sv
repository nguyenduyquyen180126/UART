// P1.1 — spec mục 2: giá trị đầu ra trong và ngay sau reset.
// Nội dung kiểm: trong 5 chu kỳ giữ presetn = 0 và 5 chu kỳ sau khi thả, lấy mẫu ở sườn xuống pclk:
//   tx = 1, rts_n = 1, irq = 0, pslverr = 0, pready = 1.
// Tiêu chí đạt: 50 mẫu đúng; assertion ap_reset_outputs, ap_pready_const không vi phạm.
// Diễn giải (SI-09): rts_n là flip-flop reset 1, bằng 1 trong reset và tới sườn lên đầu tiên sau khi presetn lên 1,
//   rồi về 0 vì rx_dis = 0, rx_done = 0; sau reset kiểm rts_n = 0 từ chu kỳ thứ hai trở đi.
task automatic t_p1_1();
  set_watchdog(100_000.0);
  apb.assert_reset();
  #1;   // bỏ sườn X→0 của pclk tại 0 ns: reset không đồng bộ chưa chắc đã lan tới flip-flop trong cùng bước thời gian (ISSUE-001)
  for (int i = 0; i < 5; i++) begin
    @(negedge vapb.pclk);
    check(vuart.tx    === 1'b1, $sformatf("trong reset chu kỳ %0d: tx = %b",    i, vuart.tx));
    check(vuart.rts_n === 1'b1, $sformatf("trong reset chu kỳ %0d: rts_n = %b", i, vuart.rts_n));
    check(vuart.irq   === 1'b0, $sformatf("trong reset chu kỳ %0d: irq = %b",   i, vuart.irq));
    check(vapb.pslverr === 1'b0, $sformatf("trong reset chu kỳ %0d: pslverr = %b", i, vapb.pslverr));
    check(vapb.pready  === 1'b1, $sformatf("trong reset chu kỳ %0d: pready = %b",  i, vapb.pready));
  end
  apb.release_reset();
  for (int i = 0; i < 5; i++) begin
    @(negedge vapb.pclk);
    check(vuart.tx    === 1'b1, $sformatf("sau reset chu kỳ %0d: tx = %b",    i, vuart.tx));
    check(vuart.irq   === 1'b0, $sformatf("sau reset chu kỳ %0d: irq = %b",   i, vuart.irq));
    check(vapb.pslverr === 1'b0, $sformatf("sau reset chu kỳ %0d: pslverr = %b", i, vapb.pslverr));
    check(vapb.pready  === 1'b1, $sformatf("sau reset chu kỳ %0d: pready = %b",  i, vapb.pready));
    if (i >= 1)
      check(vuart.rts_n === 1'b0, $sformatf("sau reset chu kỳ %0d: rts_n = %b (rx_dis = 0, rx_done = 0)", i, vuart.rts_n));
  end
endtask
