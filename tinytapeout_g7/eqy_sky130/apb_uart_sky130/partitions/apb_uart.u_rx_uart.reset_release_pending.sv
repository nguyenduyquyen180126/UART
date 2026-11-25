module miter (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [  0:0] \__po_u_rx_uart.reset_release_pending__gold ,
  output [  0:0] \__po_u_rx_uart.reset_release_pending__gate
);
  \gold.apb_uart.u_rx_uart.reset_release_pending gold (
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_presetn (\__pi_presetn ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_rx_uart.reset_release_pending (\__po_u_rx_uart.reset_release_pending__gold )
  );
  \gate.apb_uart.u_rx_uart.reset_release_pending gate (
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_presetn (\__pi_presetn ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_rx_uart.reset_release_pending (\__po_u_rx_uart.reset_release_pending__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(1, "assume") \__pi_pclk__assume (\__pi_pclk );
  miter_def_prop #(1, "assume") \__pi_presetn__assume (\__pi_presetn );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(1, "assert") \__po_u_rx_uart.reset_release_pending__assert (\__po_u_rx_uart.reset_release_pending__gold , \__po_u_rx_uart.reset_release_pending__gate );
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
  miter_def_prop #(1, "cover") \__po_u_rx_uart.reset_release_pending__gold_cover (\__po_u_rx_uart.reset_release_pending__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(1, "cover") \__po_u_rx_uart.reset_release_pending__gate_cover (\__po_u_rx_uart.reset_release_pending__gate );
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
module \gold.apb_uart.u_rx_uart.reset_release_pending (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
  output [  0:0] \__po_u_rx_uart.reset_release_pending
);
endmodule
module \gate.apb_uart.u_rx_uart.reset_release_pending (
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_presetn ,
  output [  0:0] \__po_u_rx_uart.reset_release_pending
);
endmodule
