module miter (
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 11:0] \__pi_pwdata__11_0 ,
  input  [  0:0] \__pi_pwrite ,
  input  [ 11:0] \__pi_u_apb_regs.baud__11_0 ,
  input  [  0:0] \__pi_u_apb_regs.rx_done_prev ,
  input  [  1:0] \__pi_u_rx_uart.rx_controller_inst.state ,
  input  [  0:0] \__pi_u_rx_uart.rx_done ,
  input  [  0:0] \__pi_u_tx_uart.tx_done ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [  0:0] \__po_u_apb_regs.rx_done_flag__gold ,
  output [  0:0] \__po_u_apb_regs.rx_done_flag__gate
);
  \gold.apb_uart.u_apb_regs.rx_done_flag gold (
    .\__pi_paddr (\__pi_paddr ),
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_penable (\__pi_penable ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_psel (\__pi_psel ),
    .\__pi_pstrb (\__pi_pstrb ),
    .\__pi_pwdata__11_0 (\__pi_pwdata__11_0 ),
    .\__pi_pwrite (\__pi_pwrite ),
    .\__pi_u_apb_regs.baud__11_0 (\__pi_u_apb_regs.baud__11_0 ),
    .\__pi_u_apb_regs.rx_done_prev (\__pi_u_apb_regs.rx_done_prev ),
    .\__pi_u_rx_uart.rx_controller_inst.state (\__pi_u_rx_uart.rx_controller_inst.state ),
    .\__pi_u_rx_uart.rx_done (\__pi_u_rx_uart.rx_done ),
    .\__pi_u_tx_uart.tx_done (\__pi_u_tx_uart.tx_done ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_apb_regs.rx_done_flag (\__po_u_apb_regs.rx_done_flag__gold )
  );
  \gate.apb_uart.u_apb_regs.rx_done_flag gate (
    .\__pi_paddr (\__pi_paddr ),
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_penable (\__pi_penable ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_psel (\__pi_psel ),
    .\__pi_pstrb (\__pi_pstrb ),
    .\__pi_pwdata__11_0 (\__pi_pwdata__11_0 ),
    .\__pi_pwrite (\__pi_pwrite ),
    .\__pi_u_apb_regs.baud__11_0 (\__pi_u_apb_regs.baud__11_0 ),
    .\__pi_u_apb_regs.rx_done_prev (\__pi_u_apb_regs.rx_done_prev ),
    .\__pi_u_rx_uart.rx_controller_inst.state (\__pi_u_rx_uart.rx_controller_inst.state ),
    .\__pi_u_rx_uart.rx_done (\__pi_u_rx_uart.rx_done ),
    .\__pi_u_tx_uart.tx_done (\__pi_u_tx_uart.tx_done ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_apb_regs.rx_done_flag (\__po_u_apb_regs.rx_done_flag__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(12, "assume") \__pi_paddr__assume (\__pi_paddr );
  miter_def_prop #(1, "assume") \__pi_pclk__assume (\__pi_pclk );
  miter_def_prop #(1, "assume") \__pi_penable__assume (\__pi_penable );
  miter_def_prop #(1, "assume") \__pi_presetn__assume (\__pi_presetn );
  miter_def_prop #(1, "assume") \__pi_psel__assume (\__pi_psel );
  miter_def_prop #(4, "assume") \__pi_pstrb__assume (\__pi_pstrb );
  miter_def_prop #(12, "assume") \__pi_pwdata__11_0__assume (\__pi_pwdata__11_0 );
  miter_def_prop #(1, "assume") \__pi_pwrite__assume (\__pi_pwrite );
  miter_def_prop #(12, "assume") \__pi_u_apb_regs.baud__11_0__assume (\__pi_u_apb_regs.baud__11_0 );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.rx_done_prev__assume (\__pi_u_apb_regs.rx_done_prev );
  miter_def_prop #(2, "assume") \__pi_u_rx_uart.rx_controller_inst.state__assume (\__pi_u_rx_uart.rx_controller_inst.state );
  miter_def_prop #(1, "assume") \__pi_u_rx_uart.rx_done__assume (\__pi_u_rx_uart.rx_done );
  miter_def_prop #(1, "assume") \__pi_u_tx_uart.tx_done__assume (\__pi_u_tx_uart.tx_done );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(1, "assert") \__po_u_apb_regs.rx_done_flag__assert (\__po_u_apb_regs.rx_done_flag__gold , \__po_u_apb_regs.rx_done_flag__gate );
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
  miter_def_prop #(1, "cover") \__po_u_apb_regs.rx_done_flag__gold_cover (\__po_u_apb_regs.rx_done_flag__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(1, "cover") \__po_u_apb_regs.rx_done_flag__gate_cover (\__po_u_apb_regs.rx_done_flag__gate );
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
module \gold.apb_uart.u_apb_regs.rx_done_flag (
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 11:0] \__pi_pwdata__11_0 ,
  input  [  0:0] \__pi_pwrite ,
  input  [ 11:0] \__pi_u_apb_regs.baud__11_0 ,
  input  [  0:0] \__pi_u_apb_regs.rx_done_prev ,
  input  [  1:0] \__pi_u_rx_uart.rx_controller_inst.state ,
  input  [  0:0] \__pi_u_rx_uart.rx_done ,
  input  [  0:0] \__pi_u_tx_uart.tx_done ,
  output [  0:0] \__po_u_apb_regs.rx_done_flag
);
endmodule
module \gate.apb_uart.u_apb_regs.rx_done_flag (
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 11:0] \__pi_pwdata__11_0 ,
  input  [  0:0] \__pi_pwrite ,
  input  [ 11:0] \__pi_u_apb_regs.baud__11_0 ,
  input  [  0:0] \__pi_u_apb_regs.rx_done_prev ,
  input  [  1:0] \__pi_u_rx_uart.rx_controller_inst.state ,
  input  [  0:0] \__pi_u_rx_uart.rx_done ,
  input  [  0:0] \__pi_u_tx_uart.tx_done ,
  output [  0:0] \__po_u_apb_regs.rx_done_flag
);
endmodule
