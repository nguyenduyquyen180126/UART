module miter (
  input  [  0:0] \__pi_u_apb_regs.frame_err_flag ,
  input  [  2:0] \__pi_u_apb_regs.ier ,
  input  [  0:0] \__pi_u_apb_regs.parity_err_flag ,
  input  [  0:0] \__pi_u_apb_regs.rx_done_flag ,
  input  [  0:0] \__pi_u_rx_uart.overrun ,
  input  [  0:0] \__pi_u_tx_uart.tx_done ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [  0:0] \__po_irq__gold ,
  output [  0:0] \__po_irq__gate
);
  \gold.apb_uart.irq gold (
    .\__pi_u_apb_regs.frame_err_flag (\__pi_u_apb_regs.frame_err_flag ),
    .\__pi_u_apb_regs.ier (\__pi_u_apb_regs.ier ),
    .\__pi_u_apb_regs.parity_err_flag (\__pi_u_apb_regs.parity_err_flag ),
    .\__pi_u_apb_regs.rx_done_flag (\__pi_u_apb_regs.rx_done_flag ),
    .\__pi_u_rx_uart.overrun (\__pi_u_rx_uart.overrun ),
    .\__pi_u_tx_uart.tx_done (\__pi_u_tx_uart.tx_done ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_irq (\__po_irq__gold )
  );
  \gate.apb_uart.irq gate (
    .\__pi_u_apb_regs.frame_err_flag (\__pi_u_apb_regs.frame_err_flag ),
    .\__pi_u_apb_regs.ier (\__pi_u_apb_regs.ier ),
    .\__pi_u_apb_regs.parity_err_flag (\__pi_u_apb_regs.parity_err_flag ),
    .\__pi_u_apb_regs.rx_done_flag (\__pi_u_apb_regs.rx_done_flag ),
    .\__pi_u_rx_uart.overrun (\__pi_u_rx_uart.overrun ),
    .\__pi_u_tx_uart.tx_done (\__pi_u_tx_uart.tx_done ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_irq (\__po_irq__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.frame_err_flag__assume (\__pi_u_apb_regs.frame_err_flag );
  miter_def_prop #(3, "assume") \__pi_u_apb_regs.ier__assume (\__pi_u_apb_regs.ier );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.parity_err_flag__assume (\__pi_u_apb_regs.parity_err_flag );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.rx_done_flag__assume (\__pi_u_apb_regs.rx_done_flag );
  miter_def_prop #(1, "assume") \__pi_u_rx_uart.overrun__assume (\__pi_u_rx_uart.overrun );
  miter_def_prop #(1, "assume") \__pi_u_tx_uart.tx_done__assume (\__pi_u_tx_uart.tx_done );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(1, "assert") \__po_irq__assert (\__po_irq__gold , \__po_irq__gate );
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
  miter_def_prop #(1, "cover") \__po_irq__gold_cover (\__po_irq__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(1, "cover") \__po_irq__gate_cover (\__po_irq__gate );
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
module \gold.apb_uart.irq (
  input  [  0:0] \__pi_u_apb_regs.frame_err_flag ,
  input  [  2:0] \__pi_u_apb_regs.ier ,
  input  [  0:0] \__pi_u_apb_regs.parity_err_flag ,
  input  [  0:0] \__pi_u_apb_regs.rx_done_flag ,
  input  [  0:0] \__pi_u_rx_uart.overrun ,
  input  [  0:0] \__pi_u_tx_uart.tx_done ,
  output [  0:0] \__po_irq
);
endmodule
module \gate.apb_uart.irq (
  input  [  0:0] \__pi_u_apb_regs.frame_err_flag ,
  input  [  2:0] \__pi_u_apb_regs.ier ,
  input  [  0:0] \__pi_u_apb_regs.parity_err_flag ,
  input  [  0:0] \__pi_u_apb_regs.rx_done_flag ,
  input  [  0:0] \__pi_u_rx_uart.overrun ,
  input  [  0:0] \__pi_u_tx_uart.tx_done ,
  output [  0:0] \__po_irq
);
endmodule
