module miter (
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_rx_done_status ,
  input  [  0:0] \__pi_u_apb_regs.cfg__6 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  0:0] \__pi_u_rx_uart.reset_release_pending ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [  0:0] \__po_rts_n__gold ,
  output [  0:0] \__po_rts_n__gate
);
  \gold.apb_uart.rts_n gold (
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_rx_done_status (\__pi_rx_done_status ),
    .\__pi_u_apb_regs.cfg__6 (\__pi_u_apb_regs.cfg__6 ),
    .\__pi_u_apb_regs.soft_rst_reg (\__pi_u_apb_regs.soft_rst_reg ),
    .\__pi_u_rx_uart.reset_release_pending (\__pi_u_rx_uart.reset_release_pending ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_rts_n (\__po_rts_n__gold )
  );
  \gate.apb_uart.rts_n gate (
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_rx_done_status (\__pi_rx_done_status ),
    .\__pi_u_apb_regs.cfg__6 (\__pi_u_apb_regs.cfg__6 ),
    .\__pi_u_apb_regs.soft_rst_reg (\__pi_u_apb_regs.soft_rst_reg ),
    .\__pi_u_rx_uart.reset_release_pending (\__pi_u_rx_uart.reset_release_pending ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_rts_n (\__po_rts_n__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(1, "assume") \__pi_presetn__assume (\__pi_presetn );
  miter_def_prop #(1, "assume") \__pi_rx_done_status__assume (\__pi_rx_done_status );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.cfg__6__assume (\__pi_u_apb_regs.cfg__6 );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.soft_rst_reg__assume (\__pi_u_apb_regs.soft_rst_reg );
  miter_def_prop #(1, "assume") \__pi_u_rx_uart.reset_release_pending__assume (\__pi_u_rx_uart.reset_release_pending );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(1, "assert") \__po_rts_n__assert (\__po_rts_n__gold , \__po_rts_n__gate );
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
  miter_def_prop #(1, "cover") \__po_rts_n__gold_cover (\__po_rts_n__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(1, "cover") \__po_rts_n__gate_cover (\__po_rts_n__gate );
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
module \gold.apb_uart.rts_n (
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_rx_done_status ,
  input  [  0:0] \__pi_u_apb_regs.cfg__6 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  0:0] \__pi_u_rx_uart.reset_release_pending ,
  output [  0:0] \__po_rts_n
);
endmodule
module \gate.apb_uart.rts_n (
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_rx_done_status ,
  input  [  0:0] \__pi_u_apb_regs.cfg__6 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  0:0] \__pi_u_rx_uart.reset_release_pending ,
  output [  0:0] \__po_rts_n
);
endmodule
