// uart_ext_tx — class UartExtTx: bên ngoài phát khung lên rx theo thời gian thực (spec 6.1, 6.2), độ dài bit
// 1e9/(baud·(1+δ)) ns do test tính; tiêm sai parity, stop bit 0, xung nhiễu; lái cts_n.
`timescale 1ns/1ps
package uart_ext_tx_pkg;
  import tb_pkg::*;

  class UartExtTx;
    virtual uart_if vif;
    int n_sent = 0;

    function new(virtual uart_if vif);
      this.vif = vif;
    endfunction

    task set_cts_n(bit v);
      vif.cts_n = v;
    endtask

    // Phát một khung: start, data_bits bit LSB trước, parity (nếu có), 1 hoặc 2 stop bit; gap_bits bit nghỉ sau khung
    task send(input logic [7:0] data, input frame_cfg_t cfg, input real bit_time,
              input bit inj_par = 1'b0, input bit inj_s1 = 1'b0, input bit inj_s2 = 1'b0, input real gap_bits = 0.0);
      logic [7:0] dm = data_mask(cfg, data);
      int n = cfg_nbits(cfg);
      vif.rx = 1'b0;
      #(bit_time);
      for (int k = 0; k < n; k++) begin
        vif.rx = dm[k];
        #(bit_time);
      end
      if (cfg.parity_en) begin
        vif.rx = parity_bit(cfg, dm) ^ inj_par;
        #(bit_time);
      end
      vif.rx = ~inj_s1;
      #(bit_time);
      if (cfg.stop_bits) begin
        vif.rx = ~inj_s2;
        #(bit_time);
      end
      vif.rx = 1'b1;
      n_sent++;
      if (gap_bits > 0.0) #(gap_bits * bit_time);
    endtask

    // Xung thấp trên đường nghỉ
    task glitch(input real width_ns);
      vif.rx = 1'b0;
      #(width_ns);
      vif.rx = 1'b1;
    endtask
  endclass

endpackage
