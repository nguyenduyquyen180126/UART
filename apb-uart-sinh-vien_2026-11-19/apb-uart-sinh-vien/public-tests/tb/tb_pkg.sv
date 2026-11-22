// tb_pkg — hằng số, kiểu dữ liệu và tiện ích đếm kiểm tra dùng chung cho testbench apb_uart (spec 1.1 mục 2, 4, 5, 6).
`timescale 1ns/1ps
package tb_pkg;

  // ----- Địa chỉ thanh ghi (spec 4.1) -----
  localparam logic [11:0] ADDR_TXDATA = 12'h000;
  localparam logic [11:0] ADDR_RXDATA = 12'h004;
  localparam logic [11:0] ADDR_CFG    = 12'h008;
  localparam logic [11:0] ADDR_CTRL   = 12'h00C;
  localparam logic [11:0] ADDR_STAT   = 12'h010;
  localparam logic [11:0] ADDR_BAUD   = 12'h014;
  localparam logic [11:0] ADDR_IER    = 12'h018;
  localparam int NREG = 7;
  localparam logic [11:0] REG_ADDR [NREG] = '{ADDR_TXDATA, ADDR_RXDATA, ADDR_CFG, ADDR_CTRL, ADDR_STAT, ADDR_BAUD, ADDR_IER};
  localparam string       REG_NAME [NREG] = '{"TXDATA", "RXDATA", "CFG", "CTRL", "STAT", "BAUD", "IER"};

  // ----- Bit của STAT (spec 4.5), CTRL (4.4), IER (4.6) -----
  localparam int ST_TX_DONE    = 0;
  localparam int ST_RX_DONE    = 1;
  localparam int ST_PARITY_ERR = 2;
  localparam int ST_RX_BUSY    = 3;
  localparam int ST_TX_DIS     = 4;
  localparam int ST_RX_DIS     = 5;
  localparam int ST_FRAME_ERR  = 6;
  localparam int ST_OVERRUN    = 7;
  localparam logic [31:0] CTRL_START_TX = 32'h0000_0001;
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0100;
  localparam logic [31:0] IER_TX_DONE   = 32'h0000_0001;
  localparam logic [31:0] IER_RX_DONE   = 32'h0000_0002;
  localparam logic [31:0] IER_ERR       = 32'h0000_0004;

  // ----- Mặt nạ bit hợp lệ và giá trị reset (spec 4) -----
  localparam logic [31:0] MASK_TXDATA = 32'h0000_00FF;
  localparam logic [31:0] MASK_CFG    = 32'h0000_007F;
  localparam logic [31:0] MASK_BAUD   = 32'h0000_FFFF;
  localparam logic [31:0] MASK_IER    = 32'h0000_0007;
  localparam logic [31:0] BAUD_RESET  = 32'h0000_900D;
  localparam logic [31:0] STAT_RESET  = 32'h0000_0001;

  // ----- Mã lỗi pslverr (spec 5.2) -----
  localparam int E_NONE = 0, E1 = 1, E2 = 2, E3 = 3, E4 = 4, E5 = 5;

  // ----- Clock -----
  localparam real T_PCLK_NS = 40.0;   // 25 MHz

  // ----- Cấu hình khung: thứ tự trường trùng CFG[6:0] (spec 4.2) -----
  typedef struct packed {
    bit       rx_dis;        // CFG[6]
    bit       tx_dis;        // CFG[5]
    bit       parity_type;   // CFG[4]: 1 chẵn, 0 lẻ
    bit       parity_en;     // CFG[3]
    bit       stop_bits;     // CFG[2]: 1 = 2 stop bit
    bit [1:0] data_bits;     // CFG[1:0]: 00 = 5 bit ... 11 = 8 bit
  } frame_cfg_t;

  function automatic frame_cfg_t mk_cfg(int data_bits = 8, bit stop2 = 1'b0, bit par_en = 1'b0,
                                        bit par_even = 1'b0, bit tx_dis = 1'b0, bit rx_dis = 1'b0);
    frame_cfg_t c;
    c.data_bits   = 2'(data_bits - 5);
    c.stop_bits   = stop2;
    c.parity_en   = par_en;
    c.parity_type = par_even;
    c.tx_dis      = tx_dis;
    c.rx_dis      = rx_dis;
    return c;
  endfunction

  // Cấu hình khung thứ i trong 24 dạng (spec 6.1): i = data(4) × parity(3) × stop(2)
  function automatic frame_cfg_t cfg_of_index(int i);
    int d = (i / 6) % 4;
    int p = (i / 2) % 3;
    int s = i % 2;
    return mk_cfg(5 + d, s[0], p != 0, p == 2);
  endfunction

  function automatic logic [31:0] cfg_word(frame_cfg_t c);
    return {25'b0, c};
  endfunction

  function automatic int cfg_nbits(frame_cfg_t c);
    return 5 + int'(c.data_bits);
  endfunction

  // Tổng số bit trên đường truyền: start + dữ liệu + parity + stop
  function automatic int frame_bits(frame_cfg_t c);
    return 1 + cfg_nbits(c) + int'(c.parity_en) + 1 + int'(c.stop_bits);
  endfunction

  function automatic logic [7:0] data_mask(frame_cfg_t c, logic [7:0] d);
    return d & (8'hFF >> (3 - int'(c.data_bits)));
  endfunction

  // Bit parity của dữ liệu đã cắt theo data_bits (spec 6.1)
  function automatic bit parity_bit(frame_cfg_t c, logic [7:0] d);
    logic [7:0] dm = data_mask(c, d);
    return c.parity_type ? (^dm) : ~(^dm);
  endfunction

  function automatic string cfg_str(frame_cfg_t c);
    string p = c.parity_en ? (c.parity_type ? "E" : "O") : "N";
    return $sformatf("%0d%s%0d", cfg_nbits(c), p, 1 + int'(c.stop_bits));
  endfunction

  // ----- Bảng BAUD ở f_pclk = 25 MHz (spec 4.3) -----
  localparam int BAUD_N        = 10;
  localparam int BAUD_MAND     = 7;    // chỉ số 0..6 bắt buộc, 7..9 cộng điểm
  localparam int BAUD_I2400    = 0;
  localparam int BAUD_I9600    = 2;
  localparam int BAUD_I115200  = 6;
  localparam int          BAUD_RATE [BAUD_N] = '{2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600};
  localparam logic [15:0] BAUD_REG  [BAUD_N] = '{16'h128B, 16'h8145, 16'hC0A2, 16'h6051, 16'hB028,
                                                 16'h201B, 16'h900D, 16'hD006, 16'h6003, 16'hB001};

  // Độ dài một bit (ns) của bên ngoài với lệch tốc độ delta (0,02 = +2,0 %)
  function automatic real bit_ns(int baud, real delta = 0.0);
    return 1.0e9 / (real'(baud) * (1.0 + delta));
  endfunction

  // ----- Khung do UartExtRx thu được trên tx -----
  typedef struct {
    logic [7:0] data;
    bit         start_ok;   // start bit vẫn bằng 0 ở giữa bit
    bit         par_ok;     // bit parity đúng theo cfg (1 khi không có parity)
    bit         stop_ok;    // mọi stop bit bằng 1
    real        bit_avg;    // độ rộng bit trung bình đo từ sườn xuống start bit tới sườn cuối (ns)
    int         k_last;     // số bit giữa sườn xuống start bit và sườn cuối
    real        t_start;    // thời điểm sườn xuống start bit (ns)
    real        t_end;      // thời điểm cuối stop bit cuối theo độ dài bit danh định (ns)
    frame_cfg_t cfg;
  } rx_frame_t;

  // ----- Đếm kiểm tra, seed, watchdog -----
  int          n_checks  = 0;
  int          n_errors  = 0;
  string       test_name = "?";
  int unsigned seed      = 1;
  real         deadline_ns = 2.0e6;
  int          sva_cnt [string];
  localparam int SVA_PRINT_MAX = 5;

  function automatic void info(string msg);
    $display("%0t INFO %s", $realtime, msg);
  endfunction

  function automatic void err(string msg);
    n_errors++;
    $display("%0t ERR  %s", $realtime, msg);
  endfunction

  function automatic void check(bit cond, string msg);
    n_checks++;
    if (!cond) err(msg);
  endfunction

  function automatic void check_eq(logic [31:0] got, logic [31:0] exp, string msg);
    n_checks++;
    if (got !== exp) err($sformatf("%s: đọc 0x%08h, kỳ vọng 0x%08h", msg, got, exp));
  endfunction

  // Vi phạm assertion trong checker: đếm mọi lần, in tối đa SVA_PRINT_MAX dòng mỗi tên
  function automatic void sva_fail(string name);
    if (!sva_cnt.exists(name)) sva_cnt[name] = 0;
    sva_cnt[name]++;
    n_errors++;
    if (sva_cnt[name] <= SVA_PRINT_MAX)
      $display("%0t ERR  SVA %s vi phạm (lần %0d)", $realtime, name, sva_cnt[name]);
  endfunction

  function automatic void set_watchdog(real ns);
    deadline_ns = $realtime + ns;
  endfunction

  // In đúng một dòng PASS/FAIL, ghi sim.status (0 đạt, 1 lỗi) rồi kết thúc; FAIL gọi $fatal(1)
  task automatic report();
    int fd;
    foreach (sva_cnt[k])
      $display("%0t INFO SVA %s: %0d vi phạm", $realtime, k, sva_cnt[k]);
    fd = $fopen("sim.status", "w");
    if (fd != 0) begin
      $fdisplay(fd, "%0d", (n_errors != 0) ? 1 : 0);
      $fclose(fd);
    end
    if (n_errors == 0) begin
      $display("PASS %s checks=%0d errors=0", test_name, n_checks);
      $finish;
    end else begin
      $display("FAIL %s checks=%0d errors=%0d", test_name, n_checks, n_errors);
      $fatal(1, "test %s kết thúc với %0d lỗi", test_name, n_errors);
    end
  endtask

endpackage
