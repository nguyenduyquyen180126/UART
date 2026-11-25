// coverage — class Coverage: độ phủ chức năng theo testplan mục 2: dạng khung × tốc độ, mã lỗi E1–E5, nguồn irq,
// cấu hình × lệch tốc độ δ (bước 0,25 %).
// Lưu ý: Các khối covergroup được lược bỏ để chạy tương thích trên Questa Starter FPGA Edition (Free License).
// Bản gốc có covergroup được lưu tại tb/coverage.sv.orig
`timescale 1ns/1ps
package coverage_pkg;
  import tb_pkg::*;

  class Coverage;
    frame_cfg_t cfg;
    int baud_idx = 0;
    int err_code = 0;
    int irq_src  = 0;
    int delta_q  = 0;   // δ chia cho 0,25 %: −8 ... +8

    function new();
      cfg = mk_cfg(8);
    endfunction

    function void sample_frame(frame_cfg_t c, int bi, real delta = 0.0);
      cfg      = c;
      baud_idx = bi;
      delta_q  = int'(delta / 0.0025);
    endfunction

    function void sample_err(int e);
      err_code = e;
    endfunction

    function void sample_irq(int s);
      irq_src = s;
    endfunction
  endclass

endpackage
