// coverage — class Coverage: độ phủ chức năng theo testplan mục 2: dạng khung × tốc độ, mã lỗi E1–E5, nguồn irq,
// cấu hình × lệch tốc độ δ (bước 0,25 %).
`timescale 1ns/1ps
package coverage_pkg;
  import tb_pkg::*;

  class Coverage;
    frame_cfg_t cfg;
    int baud_idx = 0;
    int err_code = 0;
    int irq_src  = 0;
    int delta_q  = 0;   // δ chia cho 0,25 %: −8 ... +8

    covergroup cg_frame;
      cp_db:   coverpoint cfg.data_bits;
      cp_sb:   coverpoint cfg.stop_bits;
      cp_par:  coverpoint {cfg.parity_en, cfg.parity_type} {
        bins none = {2'b00, 2'b01};
        bins odd  = {2'b10};
        bins even = {2'b11};
      }
      cp_baud: coverpoint baud_idx {
        bins mand[]  = {[0:6]};
        bins bonus[] = {[7:9]};
      }
      cp_delta: coverpoint delta_q {
        bins neg2  = {-8};
        bins zero  = {0};
        bins pos2  = {8};
        bins other = default;
      }
      cx_frame:       cross cp_db, cp_sb, cp_par;
      cx_frame_baud:  cross cp_db, cp_sb, cp_par, cp_baud;
      cx_frame_delta: cross cp_db, cp_sb, cp_par, cp_delta;
    endgroup

    covergroup cg_err;
      cp_err: coverpoint err_code {
        bins none = {0};
        bins e[]  = {[1:5]};
      }
    endgroup

    covergroup cg_irq;
      cp_irq: coverpoint irq_src {
        bins tx_done = {1};
        bins rx_done = {2};
        bins error   = {3};
      }
    endgroup

    function new();
      cg_frame = new;
      cg_err   = new;
      cg_irq   = new;
      cfg      = mk_cfg(8);
    endfunction

    function void sample_frame(frame_cfg_t c, int bi, real delta = 0.0);
      cfg      = c;
      baud_idx = bi;
      delta_q  = int'(delta / 0.0025);
      cg_frame.sample();
    endfunction

    function void sample_err(int e);
      err_code = e;
      cg_err.sample();
    endfunction

    function void sample_irq(int s);
      irq_src = s;
      cg_irq.sample();
    endfunction
  endclass

endpackage
