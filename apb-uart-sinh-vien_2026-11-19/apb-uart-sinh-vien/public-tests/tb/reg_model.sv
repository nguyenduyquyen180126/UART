// reg_model — class RegModel: bản sao TXDATA, CFG, BAUD, IER với mặt nạ rfu (spec 4) và dự đoán pslverr E1–E5 (spec 5.2)
// từ trạng thái tx_done, rx_busy quan sát được ở lần đọc STAT gần nhất.
`timescale 1ns/1ps
package reg_model_pkg;
  import tb_pkg::*;

  class RegModel;
    logic [31:0] txdata, cfg, baud, ier;
    bit tx_done = 1'b1;
    bit rx_busy = 1'b0;

    function new();
      reset();
    endfunction

    function void reset();
      txdata  = 32'h0;
      cfg     = 32'h0;
      baud    = BAUD_RESET;
      ier     = 32'h0;
      tx_done = 1'b1;
      rx_busy = 1'b0;
    endfunction

    function void observe_stat(logic [31:0] s);
      tx_done = s[ST_TX_DONE];
      rx_busy = s[ST_RX_BUSY];
    endfunction

    function bit is_valid_addr(logic [11:0] a);
      foreach (REG_ADDR[i]) if (a == REG_ADDR[i]) return 1'b1;
      return 1'b0;
    endfunction

    function frame_cfg_t cfg_now();
      return frame_cfg_t'(cfg[6:0]);
    endfunction

    // Giá trị đọc kỳ vọng của thanh ghi mô hình được; RXDATA và STAT do test tự quyết
    function logic [31:0] exp_read(logic [11:0] a);
      case (a)
        ADDR_TXDATA: return txdata;
        ADDR_CFG:    return cfg;
        ADDR_CTRL:   return 32'h0;
        ADDR_BAUD:   return baud;
        ADDR_IER:    return ier;
        ADDR_RXDATA: return 32'h0;
        ADDR_STAT:   return {24'h0, 2'b00, cfg[6], cfg[5], 3'b000, tx_done};
        default:     return 32'h0;
      endcase
    endfunction

    function logic [31:0] merged(logic [31:0] old, logic [31:0] wdata, logic [3:0] strb);
      logic [31:0] r = old;
      for (int i = 0; i < 4; i++) if (strb[i]) r[8*i +: 8] = wdata[8*i +: 8];
      return r;
    endfunction

    // Mã lỗi dự đoán (E_NONE khi hợp lệ). Theo SPEC-INTERP: SI-01 soft_rst (pstrb[1] = 1, pwdata[8] = 1) không bao giờ
    // lỗi, kể cả khi cùng lệnh có start_tx = 1 và tx_done = 0; SI-04 E3 cho TXDATA chỉ khi pstrb[0] = 1; SI-20 E1, E2 với
    // mọi pstrb kể cả 0000; SI-02 E4 BAUD chỉ lane 0, 1; SI-03 E5 tính trên div_int sau khi ghép lane.
    function int predict_err(logic [11:0] a, bit write, logic [3:0] strb, logic [31:0] wdata);
      logic [31:0] m;
      if (!is_valid_addr(a)) return E1;
      if (!write) return E_NONE;
      if (a == ADDR_RXDATA || a == ADDR_STAT) return E2;
      if (a == ADDR_CTRL && strb[1] && wdata[8]) return E_NONE;
      if (a == ADDR_TXDATA && strb[0] && !tx_done) return E3;
      if (a == ADDR_CTRL && strb[0] && wdata[0] && !tx_done) return E3;
      if (a == ADDR_CFG && strb[0] && (!tx_done || rx_busy)) return E4;
      if (a == ADDR_BAUD && (strb[0] || strb[1]) && (!tx_done || rx_busy)) return E4;
      if (a == ADDR_BAUD) begin
        m = merged(baud, wdata, strb) & MASK_BAUD;
        if (m[11:0] == 12'h000) return E5;
      end
      return E_NONE;
    endfunction

    // Cập nhật bản sao sau một lệnh ghi hợp lệ
    function void apply_write(logic [11:0] a, logic [3:0] strb, logic [31:0] wdata);
      case (a)
        ADDR_TXDATA: txdata = merged(txdata, wdata, strb) & MASK_TXDATA;
        ADDR_CFG:    cfg    = merged(cfg,    wdata, strb) & MASK_CFG;
        ADDR_BAUD:   baud   = merged(baud,   wdata, strb) & MASK_BAUD;
        ADDR_IER:    ier    = merged(ier,    wdata, strb) & MASK_IER;
        default: ;
      endcase
    endfunction
  endclass

endpackage
