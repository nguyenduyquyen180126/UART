module miter (
  input  [  1:0] \__pi_u_apb_regs.cfg__1_0 ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [  2:0] \__po_u_tx_uart.bit_cnt_last__gold ,
  output [  2:0] \__po_u_tx_uart.bit_cnt_last__gate
);
  \gold.apb_uart.u_tx_uart.bit_cnt_last gold (
    .\__pi_u_apb_regs.cfg__1_0 (\__pi_u_apb_regs.cfg__1_0 ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_tx_uart.bit_cnt_last (\__po_u_tx_uart.bit_cnt_last__gold )
  );
  \gate.apb_uart.u_tx_uart.bit_cnt_last gate (
    .\__pi_u_apb_regs.cfg__1_0 (\__pi_u_apb_regs.cfg__1_0 ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_tx_uart.bit_cnt_last (\__po_u_tx_uart.bit_cnt_last__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(2, "assume") \__pi_u_apb_regs.cfg__1_0__assume (\__pi_u_apb_regs.cfg__1_0 );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(3, "assert") \__po_u_tx_uart.bit_cnt_last__assert (\__po_u_tx_uart.bit_cnt_last__gold , \__po_u_tx_uart.bit_cnt_last__gate );
`endif
`ifdef COVER_DEF_CROSS_POINTS
  `ifdef DIRECT_CROSS_POINTS
  `else
  `endif
`endif
`ifdef COVER_DEF_GOLD_MATCH_POINTS
`endif
`ifdef COVER_DEF_GATE_MATCH_POINTS
`endif
`ifdef COVER_DEF_GOLD_OUTPUTS
  miter_def_prop #(3, "cover") \__po_u_tx_uart.bit_cnt_last__gold_cover (\__po_u_tx_uart.bit_cnt_last__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(3, "cover") \__po_u_tx_uart.bit_cnt_last__gate_cover (\__po_u_tx_uart.bit_cnt_last__gate );
`endif
endmodule
module miter_cmp_prop #(parameter WIDTH=1, parameter TYPE="assert") (input [WIDTH-1:0] in_gold, in_gate);
  reg okay;
  integer i;
  always @* begin
    okay = 1;
    for (i = 0; i < WIDTH; i = i+1)
      okay = okay && (in_gold[i] === 1'bx || in_gold[i] === in_gate[i]);
  end
  generate
    if (TYPE == "assert") always @* assert(okay);
    if (TYPE == "assume") always @* assume(okay);
    if (TYPE == "cover")  always @* cover(okay);
  endgenerate
endmodule
module miter_def_prop #(parameter WIDTH=1, parameter TYPE="assert") (input [WIDTH-1:0] in);
  wire okay = ^in !== 1'bx;
  generate
    if (TYPE == "assert") always @* assert(okay);
    if (TYPE == "assume") always @* assume(okay);
    if (TYPE == "cover")  always @* cover(okay);
  endgenerate
endmodule
module \gold.apb_uart.u_tx_uart.bit_cnt_last (
  input  [  1:0] \__pi_u_apb_regs.cfg__1_0 ,
  output [  2:0] \__po_u_tx_uart.bit_cnt_last
);
endmodule
module \gate.apb_uart.u_tx_uart.bit_cnt_last (
  input  [  1:0] \__pi_u_apb_regs.cfg__1_0 ,
  output [  2:0] \__po_u_tx_uart.bit_cnt_last
);
endmodule
