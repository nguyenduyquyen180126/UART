// tests_pkg — tiện ích dùng chung cho các test, thân test (tests/t_p*.sv), bảng mã test → task,
// run(): đọc +TEST, +SEED, tạo tác nhân, chạy test dưới watchdog rồi gọi tb_pkg::report().
`timescale 1ns/1ps
package tests_pkg;
  import tb_pkg::*;
  import apb_master_pkg::*;
  import reg_model_pkg::*;
  import uart_ext_tx_pkg::*;
  import uart_ext_rx_pkg::*;
  import scoreboard_pkg::*;
  import coverage_pkg::*;

  ApbMaster  apb;
  RegModel   rm;
  UartExtTx  utx;
  UartExtRx  urx;
  Scoreboard sb;
  Coverage   cov;
  virtual apb_if  vapb;
  virtual uart_if vuart;

  localparam real POLL_NS = 200.0;   // bước chờ khi đợi khung của UartExtRx
  real poll_gap_ns = 0.0;            // nghỉ giữa hai lần đọc STAT trong wait_stat (0 = đọc liên tục)

  // ----- Reset và truy cập thanh ghi qua mô hình -----
  task automatic tb_start(int reset_cycles = 3);
    apb.reset(reset_cycles);
    rm.reset();
    urx.flush();
  endtask

  task automatic wr(input logic [11:0] addr, input logic [31:0] data, input logic [3:0] strb = 4'hF, input bit exp_err = 1'b0);
    apb.write(addr, data, strb, exp_err);
    if (!exp_err) rm.apply_write(addr, strb, data);
  endtask

  task automatic rd(input logic [11:0] addr, output logic [31:0] data, input bit exp_err = 1'b0);
    apb.read(addr, data, exp_err);
    if (addr == ADDR_STAT && !exp_err) rm.observe_stat(data);
  endtask

  task automatic rd_chk(input logic [11:0] addr, input logic [31:0] exp, input string tag);
    logic [31:0] d;
    rd(addr, d);
    check_eq(d, exp, tag);
  endtask

  task automatic rd_stat(output logic [31:0] s);
    rd(ADDR_STAT, s);
  endtask

  // Đọc lại 5 thanh ghi RW/CTRL và so với mô hình
  task automatic check_model_regs(string tag);
    rd_chk(ADDR_TXDATA, rm.exp_read(ADDR_TXDATA), {tag, ": TXDATA"});
    rd_chk(ADDR_CFG,    rm.exp_read(ADDR_CFG),    {tag, ": CFG"});
    rd_chk(ADDR_CTRL,   32'h0,                    {tag, ": CTRL"});
    rd_chk(ADDR_BAUD,   rm.exp_read(ADDR_BAUD),   {tag, ": BAUD"});
    rd_chk(ADDR_IER,    rm.exp_read(ADDR_IER),    {tag, ": IER"});
  endtask

  // Chọn tốc độ và dạng khung cho DUT và cho UartExtRx (độ dài bit danh định)
  task automatic uart_setup(frame_cfg_t c, int baud_idx);
    wr(ADDR_BAUD, {16'h0, BAUD_REG[baud_idx]});
    wr(ADDR_CFG, cfg_word(c));
    urx.configure(c, bit_ns(BAUD_RATE[baud_idx]));
  endtask

  task automatic tx_char(logic [7:0] d);
    wr(ADDR_TXDATA, {24'h0, d});
    wr(ADDR_CTRL, CTRL_START_TX);
  endtask

  // Reset mềm: ghi CTRL.soft_rst rồi để trống 2 chu kỳ (spec 6.5: lệnh APB bình thường từ chu kỳ thứ 3)
  task automatic soft_reset();
    wr(ADDR_CTRL, CTRL_SOFT_RST);
    apb.idle(2);
    rm.reset();
  endtask

  // Chờ một bit của STAT bằng val, đọc STAT liên tục (back-to-back); ok = 0 khi quá timeout
  task automatic wait_stat(input int bitpos, input bit val, input real timeout_ns, output bit ok, output logic [31:0] s);
    real t_lim = $realtime + timeout_ns;
    ok = 1'b0;
    forever begin
      rd_stat(s);
      if (s[bitpos] === val) begin
        ok = 1'b1;
        return;
      end
      if ($realtime > t_lim) return;
      if (poll_gap_ns > 0.0) #(poll_gap_ns);
    end
  endtask

  task automatic wait_tx_done(input real timeout_ns, input string tag);
    bit ok;
    logic [31:0] s;
    wait_stat(ST_TX_DONE, 1'b1, timeout_ns, ok, s);
    check(ok, {tag, ": tx_done không lên 1 trong thời hạn"});
  endtask

  task automatic wait_rx_done(input real timeout_ns, input string tag, output logic [31:0] s);
    bit ok;
    wait_stat(ST_RX_DONE, 1'b1, timeout_ns, ok, s);
    check(ok, {tag, ": rx_done không lên 1 trong thời hạn"});
  endtask

  // Lấy khung kế tiếp mà UartExtRx đã thu
  task automatic get_frame(input real timeout_ns, input string tag, output bit ok, output rx_frame_t f);
    real t_lim = $realtime + timeout_ns;
    while (urx.pending() == 0 && $realtime < t_lim) #(POLL_NS);
    if (urx.pending() > 0) begin
      f  = urx.frames.pop_front();
      ok = 1'b1;
    end else begin
      ok = 1'b0;
      err({tag, ": không thu được khung trên tx trong thời hạn"});
    end
  endtask

  // Khung thu được đúng dữ liệu, parity, stop bit; độ rộng bit trung bình lệch ≤ ±1,0 % (spec 4.3). Mỗi sườn trên tx
  // bị lượng tử hoá theo pclk nên phép đo qua k_last bit có sai số tới T_PCLK/(k_last·b); dung sai cộng thêm phần này.
  function automatic void check_frame(rx_frame_t f, logic [7:0] exp, frame_cfg_t c, real b, string tag);
    real dev = (f.bit_avg - b) / b;
    real tol = 0.01 + ((f.k_last > 0) ? T_PCLK_NS / (real'(f.k_last) * b) : 0.0);
    check(f.start_ok, {tag, ": start bit không giữ 0 ở giữa bit"});
    check_eq({24'h0, f.data}, {24'h0, data_mask(c, exp)}, {tag, ": dữ liệu trên tx"});
    check(f.par_ok,  {tag, ": bit parity sai"});
    check(f.stop_ok, {tag, ": stop bit bằng 0"});
    check(f.k_last > 0 && dev >= -tol && dev <= tol,
          $sformatf("%s: độ rộng bit trung bình %.1f ns, danh định %.1f ns, lệch %.2f %% (k=%0d, dung sai %.2f %%)",
                    tag, f.bit_avg, b, 100.0 * dev, f.k_last, 100.0 * tol));
  endfunction

  // Phát một ký tự và kiểm trên tx; chờ tx_done
  task automatic tx_and_check(logic [7:0] d, frame_cfg_t c, real b, string tag);
    rx_frame_t f;
    bit ok;
    real fr = real'(frame_bits(c)) * b;
    tx_char(d);
    wait_tx_done(3.0 * fr + 10_000.0, tag);
    get_frame(2.0 * fr, tag, ok, f);
    if (ok) check_frame(f, d, c, b, tag);
  endtask

  // Nhận một ký tự từ bên ngoài, đối chiếu STAT và RXDATA, rồi kiểm cờ đã xoá
  task automatic rx_and_check(logic [7:0] d, frame_cfg_t c, real b, string tag,
                              bit inj_par = 1'b0, bit inj_s1 = 1'b0, bit inj_s2 = 1'b0);
    logic [31:0] s, r;
    real fr = real'(frame_bits(c)) * b;
    sb.expect_frame(data_mask(c, d), c.parity_en & inj_par, inj_s1 | (c.stop_bits & inj_s2), 1'b0, tag);
    utx.send(d, c, b, inj_par, inj_s1, inj_s2, 1.0);
    wait_rx_done(fr + 10_000.0, tag, s);
    rd(ADDR_RXDATA, r);
    sb.check_rx(r, s);
    rd_stat(s);
    check(s[ST_RX_DONE] === 1'b0 && s[ST_PARITY_ERR] === 1'b0 && s[ST_FRAME_ERR] === 1'b0 && s[ST_OVERRUN] === 1'b0,
          $sformatf("%s: STAT=0x%02h còn cờ sau khi đọc RXDATA", tag, s[7:0]));
  endtask

  // Chuỗi giao dịch ngẫu nhiên tới thanh ghi hợp lệ và địa chỉ sai, dự đoán pslverr và prdata bằng mô hình;
  // không ghi start_tx, soft_rst để tx_done = 1 và rx_busy = 0 trong suốt chuỗi
  task automatic random_xfers(int n, string tag);
    logic [11:0] a;
    logic [31:0] wdata, d, exp;
    logic [3:0]  strb;
    bit write, exp_err;
    int e;
    for (int i = 0; i < n; i++) begin
      if ($urandom_range(0, 9) < 7) a = REG_ADDR[$urandom_range(0, NREG - 1)];
      else a = 12'($urandom);
      write = $urandom_range(0, 1);
      wdata = $urandom;
      strb  = 4'($urandom);
      if (a == ADDR_CTRL) begin
        wdata[0] = 1'b0;
        wdata[8] = 1'b0;
      end
      e = rm.predict_err(a, write, strb, wdata);
      exp_err = (e != E_NONE);
      cov.sample_err(e);
      if (write) begin
        apb.write(a, wdata, strb, exp_err);
        if (!exp_err) rm.apply_write(a, strb, wdata);
      end else begin
        apb.read(a, d, exp_err);
        exp = rm.is_valid_addr(a) ? rm.exp_read(a) : 32'h0;
        check_eq(d, exp, $sformatf("%s: giao dịch %0d đọc 0x%03h", tag, i, a));
      end
    end
  endtask

  // ----- Thân test -----
  `include "tests/h_lib.sv"
  `include "tests/t_p1_1.sv"
  `include "tests/t_p1_2.sv"
  `include "tests/t_p1_3.sv"
  `include "tests/t_p2_1.sv"
  `include "tests/t_p2_2.sv"
  `include "tests/t_p2_3.sv"
  `include "tests/t_p3_1.sv"
  `include "tests/t_p3_2.sv"
  `include "tests/t_p3_3.sv"
  `include "tests/t_p3_4.sv"
  `include "tests/t_p4_1.sv"
  `include "tests/t_p4_2.sv"
  `include "tests/t_p4_3.sv"
  `include "tests/t_p4_4.sv"
  `include "tests/t_p4_5.sv"
  `include "tests/t_p5_1.sv"
  `include "tests/t_p5_2.sv"
  `include "tests/t_p6_1.sv"
  `include "tests/t_p6_2.sv"
  `include "tests/t_p7_1.sv"

  task automatic run_test(input string name, output bit found);
    found = 1'b1;
    case (name)
      "P1.1": t_p1_1();
      "P1.2": t_p1_2();
      "P1.3": t_p1_3();
      "P2.1": t_p2_1();
      "P2.2": t_p2_2();
      "P2.3": t_p2_3();
      "P3.1": t_p3_1();
      "P3.2": t_p3_2();
      "P3.3": t_p3_3();
      "P3.4": t_p3_4();
      "P4.1": t_p4_1();
      "P4.2": t_p4_2();
      "P4.3": t_p4_3();
      "P4.4": t_p4_4();
      "P4.5": t_p4_5();
      "P5.1": t_p5_1();
      "P5.2": t_p5_2();
      "P6.1": t_p6_1();
      "P6.2": t_p6_2();
      "P7.1": t_p7_1();
      default: found = 1'b0;
    endcase
  endtask

  task automatic watchdog();
    real dt;
    forever begin
      dt = deadline_ns - $realtime;
      if (dt < 1.0) break;   // dưới 1 ns coi như tới hạn, tránh vòng #0 vô hạn khi sai số làm tròn (H5.07 trên stub)
      #(dt);
    end
    err($sformatf("watchdog: test không kết thúc sau %.0f ns", deadline_ns));
  endtask

  task automatic run(virtual apb_if va, virtual uart_if vu);
    string name;
    int s;
    int fd;
    bit found;
    if (!$value$plusargs("TEST=%s", name)) name = "P1.1";
    if (!$value$plusargs("SEED=%d", s)) s = 1;
    seed      = s;
    test_name = name;
    $timeformat(-9, 1, " ns", 12);
    $display("SEED %0d TEST %s", seed, name);
    fd = $fopen("sim.status", "w");
    if (fd != 0) begin
      $fdisplay(fd, "2");
      $fclose(fd);
    end
    process::self().srandom(seed);
    vapb  = va;
    vuart = vu;
    apb   = new(va);
    rm    = new();
    utx   = new(vu);
    urx   = new(vu);
    sb    = new();
    cov   = new();
    fork
      urx.run();
    join_none
    fork
      begin
        run_test(name, found);
        if (!found) err($sformatf("mã test không tồn tại: %s", name));
      end
      watchdog();
    join_any
    disable fork;
    report();
  endtask

endpackage
