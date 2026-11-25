module miter (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
  input  [  1:0] \__pi_u_apb_regs.cfg__1_0 ,
  input  [  0:0] \__pi_u_apb_regs.cfg__3 ,
  input  [  3:0] \__pi_u_rx_uart.bit_cnt_inst.bit_cnt ,
  input  [  0:0] \__pi_u_rx_uart.sipo_inst.data_out__11 ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [  0:0] \__po_u_rx_uart.deframe_inst.parity_bit__gold ,
  output [  0:0] \__po_u_rx_uart.deframe_inst.parity_bit__gate
);
  \gold.apb_uart.u_rx_uart.deframe_inst.parity_bit gold (
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_u_apb_regs.cfg__1_0 (\__pi_u_apb_regs.cfg__1_0 ),
    .\__pi_u_apb_regs.cfg__3 (\__pi_u_apb_regs.cfg__3 ),
    .\__pi_u_rx_uart.bit_cnt_inst.bit_cnt (\__pi_u_rx_uart.bit_cnt_inst.bit_cnt ),
    .\__pi_u_rx_uart.sipo_inst.data_out__11 (\__pi_u_rx_uart.sipo_inst.data_out__11 ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_rx_uart.deframe_inst.parity_bit (\__po_u_rx_uart.deframe_inst.parity_bit__gold )
  );
  \gate.apb_uart.u_rx_uart.deframe_inst.parity_bit gate (
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_u_apb_regs.cfg__1_0 (\__pi_u_apb_regs.cfg__1_0 ),
    .\__pi_u_apb_regs.cfg__3 (\__pi_u_apb_regs.cfg__3 ),
    .\__pi_u_rx_uart.bit_cnt_inst.bit_cnt (\__pi_u_rx_uart.bit_cnt_inst.bit_cnt ),
    .\__pi_u_rx_uart.sipo_inst.data_out__11 (\__pi_u_rx_uart.sipo_inst.data_out__11 ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_rx_uart.deframe_inst.parity_bit (\__po_u_rx_uart.deframe_inst.parity_bit__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(1, "assume") \__pi_pclk__assume (\__pi_pclk );
  miter_def_prop #(1, "assume") \__pi_presetn__assume (\__pi_presetn );
  miter_def_prop #(2, "assume") \__pi_u_apb_regs.cfg__1_0__assume (\__pi_u_apb_regs.cfg__1_0 );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.cfg__3__assume (\__pi_u_apb_regs.cfg__3 );
  miter_def_prop #(4, "assume") \__pi_u_rx_uart.bit_cnt_inst.bit_cnt__assume (\__pi_u_rx_uart.bit_cnt_inst.bit_cnt );
  miter_def_prop #(1, "assume") \__pi_u_rx_uart.sipo_inst.data_out__11__assume (\__pi_u_rx_uart.sipo_inst.data_out__11 );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(1, "assert") \__po_u_rx_uart.deframe_inst.parity_bit__assert (\__po_u_rx_uart.deframe_inst.parity_bit__gold , \__po_u_rx_uart.deframe_inst.parity_bit__gate );
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
  miter_def_prop #(1, "cover") \__po_u_rx_uart.deframe_inst.parity_bit__gold_cover (\__po_u_rx_uart.deframe_inst.parity_bit__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(1, "cover") \__po_u_rx_uart.deframe_inst.parity_bit__gate_cover (\__po_u_rx_uart.deframe_inst.parity_bit__gate );
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
module \gold.apb_uart.u_rx_uart.deframe_inst.parity_bit (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
  input  [  1:0] \__pi_u_apb_regs.cfg__1_0 ,
  input  [  0:0] \__pi_u_apb_regs.cfg__3 ,
  input  [  3:0] \__pi_u_rx_uart.bit_cnt_inst.bit_cnt ,
  input  [  0:0] \__pi_u_rx_uart.sipo_inst.data_out__11 ,
  output [  0:0] \__po_u_rx_uart.deframe_inst.parity_bit
);
endmodule
module \gate.apb_uart.u_rx_uart.deframe_inst.parity_bit (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
  input  [  1:0] \__pi_u_apb_regs.cfg__1_0 ,
  input  [  0:0] \__pi_u_apb_regs.cfg__3 ,
  input  [  3:0] \__pi_u_rx_uart.bit_cnt_inst.bit_cnt ,
  input  [  0:0] \__pi_u_rx_uart.sipo_inst.data_out__11 ,
  output [  0:0] \__po_u_rx_uart.deframe_inst.parity_bit
);
endmodule
