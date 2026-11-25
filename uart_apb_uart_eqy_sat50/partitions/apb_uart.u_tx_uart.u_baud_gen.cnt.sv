module miter (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
  input  [ 15:0] \__pi_u_apb_regs.baud ,
  input  [  0:0] \__pi_u_apb_regs.cfg__5 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  0:0] \__pi_u_apb_regs.start_reg ,
  input  [  2:0] \__pi_u_tx_uart.controller.state ,
  input  [  0:0] \__pi_u_tx_uart.cts_n_sync2 ,
  input  [  3:0] \__pi_u_tx_uart.u_baud_gen.acc ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [ 11:0] \__po_u_tx_uart.u_baud_gen.cnt__gold ,
  output [ 11:0] \__po_u_tx_uart.u_baud_gen.cnt__gate
);
  \gold.apb_uart.u_tx_uart.u_baud_gen.cnt gold (
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_u_apb_regs.baud (\__pi_u_apb_regs.baud ),
    .\__pi_u_apb_regs.cfg__5 (\__pi_u_apb_regs.cfg__5 ),
    .\__pi_u_apb_regs.soft_rst_reg (\__pi_u_apb_regs.soft_rst_reg ),
    .\__pi_u_apb_regs.start_reg (\__pi_u_apb_regs.start_reg ),
    .\__pi_u_tx_uart.controller.state (\__pi_u_tx_uart.controller.state ),
    .\__pi_u_tx_uart.cts_n_sync2 (\__pi_u_tx_uart.cts_n_sync2 ),
    .\__pi_u_tx_uart.u_baud_gen.acc (\__pi_u_tx_uart.u_baud_gen.acc ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_tx_uart.u_baud_gen.cnt (\__po_u_tx_uart.u_baud_gen.cnt__gold )
  );
  \gate.apb_uart.u_tx_uart.u_baud_gen.cnt gate (
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_u_apb_regs.baud (\__pi_u_apb_regs.baud ),
    .\__pi_u_apb_regs.cfg__5 (\__pi_u_apb_regs.cfg__5 ),
    .\__pi_u_apb_regs.soft_rst_reg (\__pi_u_apb_regs.soft_rst_reg ),
    .\__pi_u_apb_regs.start_reg (\__pi_u_apb_regs.start_reg ),
    .\__pi_u_tx_uart.controller.state (\__pi_u_tx_uart.controller.state ),
    .\__pi_u_tx_uart.cts_n_sync2 (\__pi_u_tx_uart.cts_n_sync2 ),
    .\__pi_u_tx_uart.u_baud_gen.acc (\__pi_u_tx_uart.u_baud_gen.acc ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_tx_uart.u_baud_gen.cnt (\__po_u_tx_uart.u_baud_gen.cnt__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(1, "assume") \__pi_pclk__assume (\__pi_pclk );
  miter_def_prop #(1, "assume") \__pi_presetn__assume (\__pi_presetn );
  miter_def_prop #(16, "assume") \__pi_u_apb_regs.baud__assume (\__pi_u_apb_regs.baud );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.cfg__5__assume (\__pi_u_apb_regs.cfg__5 );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.soft_rst_reg__assume (\__pi_u_apb_regs.soft_rst_reg );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.start_reg__assume (\__pi_u_apb_regs.start_reg );
  miter_def_prop #(3, "assume") \__pi_u_tx_uart.controller.state__assume (\__pi_u_tx_uart.controller.state );
  miter_def_prop #(1, "assume") \__pi_u_tx_uart.cts_n_sync2__assume (\__pi_u_tx_uart.cts_n_sync2 );
  miter_def_prop #(4, "assume") \__pi_u_tx_uart.u_baud_gen.acc__assume (\__pi_u_tx_uart.u_baud_gen.acc );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(12, "assert") \__po_u_tx_uart.u_baud_gen.cnt__assert (\__po_u_tx_uart.u_baud_gen.cnt__gold , \__po_u_tx_uart.u_baud_gen.cnt__gate );
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
  miter_def_prop #(12, "cover") \__po_u_tx_uart.u_baud_gen.cnt__gold_cover (\__po_u_tx_uart.u_baud_gen.cnt__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(12, "cover") \__po_u_tx_uart.u_baud_gen.cnt__gate_cover (\__po_u_tx_uart.u_baud_gen.cnt__gate );
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
module \gold.apb_uart.u_tx_uart.u_baud_gen.cnt (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
  input  [ 15:0] \__pi_u_apb_regs.baud ,
  input  [  0:0] \__pi_u_apb_regs.cfg__5 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  0:0] \__pi_u_apb_regs.start_reg ,
  input  [  2:0] \__pi_u_tx_uart.controller.state ,
  input  [  0:0] \__pi_u_tx_uart.cts_n_sync2 ,
  input  [  3:0] \__pi_u_tx_uart.u_baud_gen.acc ,
  output [ 11:0] \__po_u_tx_uart.u_baud_gen.cnt
);
endmodule
module \gate.apb_uart.u_tx_uart.u_baud_gen.cnt (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
  input  [ 15:0] \__pi_u_apb_regs.baud ,
  input  [  0:0] \__pi_u_apb_regs.cfg__5 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  0:0] \__pi_u_apb_regs.start_reg ,
  input  [  2:0] \__pi_u_tx_uart.controller.state ,
  input  [  0:0] \__pi_u_tx_uart.cts_n_sync2 ,
  input  [  3:0] \__pi_u_tx_uart.u_baud_gen.acc ,
  output [ 11:0] \__po_u_tx_uart.u_baud_gen.cnt
);
endmodule
