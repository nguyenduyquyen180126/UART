// uart_ext_rx — class UartExtRx: theo dõi tx liên tục; mỗi sườn xuống start bit mở một khung, lấy mẫu giữa bit theo độ
// dài bit danh định của cfg hiện hành, giải mã dữ liệu, parity, stop bit; đo độ rộng bit trung bình bằng sườn cuối
// cùng trong khung chia cho số bit danh định tới sườn đó (spec 4.3, 6.1, 6.3). Khung thu được xếp vào hàng đợi frames.
`timescale 1ns/1ps
package uart_ext_rx_pkg;
  import tb_pkg::*;

  class UartExtRx;
    virtual uart_if vif;
    frame_cfg_t cfg;
    real        bit_time = 0.0;
    rx_frame_t  frames [$];
    int         n_frames = 0;

    function new(virtual uart_if vif);
      this.vif = vif;
      cfg      = mk_cfg(8);
      bit_time = bit_ns(115200);
    endfunction

    function void configure(frame_cfg_t c, real b);
      cfg      = c;
      bit_time = b;
    endfunction

    function void flush();
      frames.delete();
    endfunction

    function int pending();
      return frames.size();
    endfunction

    // Thu một khung từ sườn xuống của tx
    // Cấu hình và độ dài bit được chụp tại sườn xuống start bit, để configure() gọi giữa hai khung có hiệu lực (ISSUE-002)
    task capture_one(output rx_frame_t f);
      frame_cfg_t c;
      real        b;
      int         n;
      logic [7:0] bits = 8'h0;
      logic       p = 1'b1, s1 = 1'b1, s2 = 1'b1, st = 1'b0;
      real        t0, t_last;
      int         k_last = 0;
      wait (vif.tx === 1'b1);
      @(negedge vif.tx);
      c      = cfg;
      b      = bit_time;
      n      = cfg_nbits(c);
      t0     = $realtime;
      t_last = t0;
      fork
        begin : edges
          forever begin
            @(vif.tx);
            t_last = $realtime;
            k_last = int'($floor((t_last - t0) / b + 0.5));   // làm tròn về số nguyên gần nhất (int' tự làm tròn, không cộng 0,5 hai lần)
          end
        end
        begin : sample
          #(0.5 * b);
          st = vif.tx;
          for (int k = 0; k < n; k++) begin
            #(b);
            bits[k] = vif.tx;
          end
          if (c.parity_en) begin
            #(b);
            p = vif.tx;
          end
          #(b);
          s1 = vif.tx;
          if (c.stop_bits) begin
            #(b);
            s2 = vif.tx;
          end
        end
      join_any
      disable fork;
      f.cfg      = c;
      f.data     = bits;
      f.start_ok = (st === 1'b0);
      f.par_ok   = c.parity_en ? (p === parity_bit(c, bits)) : 1'b1;
      f.stop_ok  = (s1 === 1'b1) && (!c.stop_bits || (s2 === 1'b1));
      f.k_last   = k_last;
      f.bit_avg  = (k_last > 0) ? (t_last - t0) / real'(k_last) : 0.0;
      f.t_start  = t0;
      f.t_end    = t0 + real'(frame_bits(c)) * b;
    endtask

    task run();
      rx_frame_t f;
      forever begin
        capture_one(f);
        frames.push_back(f);
        n_frames++;
      end
    endtask
  endclass

endpackage
