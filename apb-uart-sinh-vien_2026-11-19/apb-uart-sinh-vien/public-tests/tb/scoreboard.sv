// scoreboard — class Scoreboard: hàng đợi khung kỳ vọng phía RX (data, parity_err, frame_err, overrun) và đối chiếu
// với RXDATA, STAT khi CPU đọc (spec 4.5, 6.2).
`timescale 1ns/1ps
package scoreboard_pkg;
  import tb_pkg::*;

  class Scoreboard;
    typedef struct {
      logic [7:0] data;
      bit         par_err;
      bit         frm_err;
      bit         overrun;
      string      tag;
    } exp_t;
    exp_t q [$];
    int n_match = 0;

    function void expect_frame(logic [7:0] data, bit par_err = 1'b0, bit frm_err = 1'b0, bit overrun = 1'b0, string tag = "");
      exp_t e;
      e.data    = data;
      e.par_err = par_err;
      e.frm_err = frm_err;
      e.overrun = overrun;
      e.tag     = tag;
      q.push_back(e);
    endfunction

    function int pending();
      return q.size();
    endfunction

    // Đối chiếu RXDATA và STAT đọc được với khung kỳ vọng đầu hàng đợi
    function void check_rx(logic [31:0] rxdata, logic [31:0] stat);
      exp_t e;
      if (q.size() == 0) begin
        err($sformatf("scoreboard: đọc RXDATA=0x%02h khi không có khung kỳ vọng", rxdata[7:0]));
        return;
      end
      e = q.pop_front();
      check(stat[ST_RX_DONE] === 1'b1,          $sformatf("%s: rx_done = 0 khi đọc khung", e.tag));
      check_eq({24'h0, rxdata[7:0]}, {24'h0, e.data}, $sformatf("%s: RXDATA", e.tag));
      check(stat[ST_PARITY_ERR] === e.par_err,  $sformatf("%s: parity_err = %b, kỳ vọng %b", e.tag, stat[ST_PARITY_ERR], e.par_err));
      check(stat[ST_FRAME_ERR]  === e.frm_err,  $sformatf("%s: frame_err = %b, kỳ vọng %b",  e.tag, stat[ST_FRAME_ERR],  e.frm_err));
      check(stat[ST_OVERRUN]    === e.overrun,  $sformatf("%s: overrun = %b, kỳ vọng %b",    e.tag, stat[ST_OVERRUN],    e.overrun));
      n_match++;
    endfunction
  endclass

endpackage
