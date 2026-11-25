module miter (
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx_done_status ,
  input  [ 15:0] \__pi_u_apb_regs.baud ,
  input  [  3:0] \__pi_u_apb_regs.cfg__3_0 ,
  input  [  0:0] \__pi_u_apb_regs.cfg__6 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  3:0] \__pi_u_rx_uart.bit_cnt_inst.bit_cnt ,
  input  [  7:0] \__pi_u_rx_uart.deframe_inst.rx_data ,
  input  [  0:0] \__pi_u_rx_uart.rx_controller_inst.first_stop_sampled ,
  input  [  0:0] \__pi_u_rx_uart.rx_done ,
  input  [  0:0] \__pi_u_rx_uart.rx_sync2 ,
  input  [  3:0] \__pi_u_rx_uart.tick_cnt_inst.tick_cnt ,
  input  [  3:0] \__pi_u_rx_uart.u_rx_baud_gen.acc ,
  input  [ 11:0] \__pi_u_rx_uart.u_rx_baud_gen.cnt ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [  7:0] \__po_u_rx_uart.rx_data__gold ,
  output [  7:0] \__po_u_rx_uart.rx_data__gate
);
  \gold.apb_uart.u_rx_uart.rx_data gold (
    .\__pi_paddr (\__pi_paddr ),
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_penable (\__pi_penable ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_psel (\__pi_psel ),
    .\__pi_pwrite (\__pi_pwrite ),
    .\__pi_rx_done_status (\__pi_rx_done_status ),
    .\__pi_u_apb_regs.baud (\__pi_u_apb_regs.baud ),
    .\__pi_u_apb_regs.cfg__3_0 (\__pi_u_apb_regs.cfg__3_0 ),
    .\__pi_u_apb_regs.cfg__6 (\__pi_u_apb_regs.cfg__6 ),
    .\__pi_u_apb_regs.soft_rst_reg (\__pi_u_apb_regs.soft_rst_reg ),
    .\__pi_u_rx_uart.bit_cnt_inst.bit_cnt (\__pi_u_rx_uart.bit_cnt_inst.bit_cnt ),
    .\__pi_u_rx_uart.deframe_inst.rx_data (\__pi_u_rx_uart.deframe_inst.rx_data ),
    .\__pi_u_rx_uart.rx_controller_inst.first_stop_sampled (\__pi_u_rx_uart.rx_controller_inst.first_stop_sampled ),
    .\__pi_u_rx_uart.rx_done (\__pi_u_rx_uart.rx_done ),
    .\__pi_u_rx_uart.rx_sync2 (\__pi_u_rx_uart.rx_sync2 ),
    .\__pi_u_rx_uart.tick_cnt_inst.tick_cnt (\__pi_u_rx_uart.tick_cnt_inst.tick_cnt ),
    .\__pi_u_rx_uart.u_rx_baud_gen.acc (\__pi_u_rx_uart.u_rx_baud_gen.acc ),
    .\__pi_u_rx_uart.u_rx_baud_gen.cnt (\__pi_u_rx_uart.u_rx_baud_gen.cnt ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_rx_uart.rx_data (\__po_u_rx_uart.rx_data__gold )
  );
  \gate.apb_uart.u_rx_uart.rx_data gate (
    .\__pi_paddr (\__pi_paddr ),
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_penable (\__pi_penable ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_psel (\__pi_psel ),
    .\__pi_pwrite (\__pi_pwrite ),
    .\__pi_rx_done_status (\__pi_rx_done_status ),
    .\__pi_u_apb_regs.baud (\__pi_u_apb_regs.baud ),
    .\__pi_u_apb_regs.cfg__3_0 (\__pi_u_apb_regs.cfg__3_0 ),
    .\__pi_u_apb_regs.cfg__6 (\__pi_u_apb_regs.cfg__6 ),
    .\__pi_u_apb_regs.soft_rst_reg (\__pi_u_apb_regs.soft_rst_reg ),
    .\__pi_u_rx_uart.bit_cnt_inst.bit_cnt (\__pi_u_rx_uart.bit_cnt_inst.bit_cnt ),
    .\__pi_u_rx_uart.deframe_inst.rx_data (\__pi_u_rx_uart.deframe_inst.rx_data ),
    .\__pi_u_rx_uart.rx_controller_inst.first_stop_sampled (\__pi_u_rx_uart.rx_controller_inst.first_stop_sampled ),
    .\__pi_u_rx_uart.rx_done (\__pi_u_rx_uart.rx_done ),
    .\__pi_u_rx_uart.rx_sync2 (\__pi_u_rx_uart.rx_sync2 ),
    .\__pi_u_rx_uart.tick_cnt_inst.tick_cnt (\__pi_u_rx_uart.tick_cnt_inst.tick_cnt ),
    .\__pi_u_rx_uart.u_rx_baud_gen.acc (\__pi_u_rx_uart.u_rx_baud_gen.acc ),
    .\__pi_u_rx_uart.u_rx_baud_gen.cnt (\__pi_u_rx_uart.u_rx_baud_gen.cnt ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_u_rx_uart.rx_data (\__po_u_rx_uart.rx_data__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(12, "assume") \__pi_paddr__assume (\__pi_paddr );
  miter_def_prop #(1, "assume") \__pi_pclk__assume (\__pi_pclk );
  miter_def_prop #(1, "assume") \__pi_penable__assume (\__pi_penable );
  miter_def_prop #(1, "assume") \__pi_presetn__assume (\__pi_presetn );
  miter_def_prop #(1, "assume") \__pi_psel__assume (\__pi_psel );
  miter_def_prop #(1, "assume") \__pi_pwrite__assume (\__pi_pwrite );
  miter_def_prop #(1, "assume") \__pi_rx_done_status__assume (\__pi_rx_done_status );
  miter_def_prop #(16, "assume") \__pi_u_apb_regs.baud__assume (\__pi_u_apb_regs.baud );
  miter_def_prop #(4, "assume") \__pi_u_apb_regs.cfg__3_0__assume (\__pi_u_apb_regs.cfg__3_0 );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.cfg__6__assume (\__pi_u_apb_regs.cfg__6 );
  miter_def_prop #(1, "assume") \__pi_u_apb_regs.soft_rst_reg__assume (\__pi_u_apb_regs.soft_rst_reg );
  miter_def_prop #(4, "assume") \__pi_u_rx_uart.bit_cnt_inst.bit_cnt__assume (\__pi_u_rx_uart.bit_cnt_inst.bit_cnt );
  miter_def_prop #(8, "assume") \__pi_u_rx_uart.deframe_inst.rx_data__assume (\__pi_u_rx_uart.deframe_inst.rx_data );
  miter_def_prop #(1, "assume") \__pi_u_rx_uart.rx_controller_inst.first_stop_sampled__assume (\__pi_u_rx_uart.rx_controller_inst.first_stop_sampled );
  miter_def_prop #(1, "assume") \__pi_u_rx_uart.rx_done__assume (\__pi_u_rx_uart.rx_done );
  miter_def_prop #(1, "assume") \__pi_u_rx_uart.rx_sync2__assume (\__pi_u_rx_uart.rx_sync2 );
  miter_def_prop #(4, "assume") \__pi_u_rx_uart.tick_cnt_inst.tick_cnt__assume (\__pi_u_rx_uart.tick_cnt_inst.tick_cnt );
  miter_def_prop #(4, "assume") \__pi_u_rx_uart.u_rx_baud_gen.acc__assume (\__pi_u_rx_uart.u_rx_baud_gen.acc );
  miter_def_prop #(12, "assume") \__pi_u_rx_uart.u_rx_baud_gen.cnt__assume (\__pi_u_rx_uart.u_rx_baud_gen.cnt );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(8, "assert") \__po_u_rx_uart.rx_data__assert (\__po_u_rx_uart.rx_data__gold , \__po_u_rx_uart.rx_data__gate );
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
  miter_def_prop #(8, "cover") \__po_u_rx_uart.rx_data__gold_cover (\__po_u_rx_uart.rx_data__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(8, "cover") \__po_u_rx_uart.rx_data__gate_cover (\__po_u_rx_uart.rx_data__gate );
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
module \gold.apb_uart.u_rx_uart.rx_data (
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx_done_status ,
  input  [ 15:0] \__pi_u_apb_regs.baud ,
  input  [  3:0] \__pi_u_apb_regs.cfg__3_0 ,
  input  [  0:0] \__pi_u_apb_regs.cfg__6 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  3:0] \__pi_u_rx_uart.bit_cnt_inst.bit_cnt ,
  input  [  7:0] \__pi_u_rx_uart.deframe_inst.rx_data ,
  input  [  0:0] \__pi_u_rx_uart.rx_controller_inst.first_stop_sampled ,
  input  [  0:0] \__pi_u_rx_uart.rx_done ,
  input  [  0:0] \__pi_u_rx_uart.rx_sync2 ,
  input  [  3:0] \__pi_u_rx_uart.tick_cnt_inst.tick_cnt ,
  input  [  3:0] \__pi_u_rx_uart.u_rx_baud_gen.acc ,
  input  [ 11:0] \__pi_u_rx_uart.u_rx_baud_gen.cnt ,
  output [  7:0] \__po_u_rx_uart.rx_data
);
endmodule
module \gate.apb_uart.u_rx_uart.rx_data (
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx_done_status ,
  input  [ 15:0] \__pi_u_apb_regs.baud ,
  input  [  3:0] \__pi_u_apb_regs.cfg__3_0 ,
  input  [  0:0] \__pi_u_apb_regs.cfg__6 ,
  input  [  0:0] \__pi_u_apb_regs.soft_rst_reg ,
  input  [  3:0] \__pi_u_rx_uart.bit_cnt_inst.bit_cnt ,
  input  [  7:0] \__pi_u_rx_uart.deframe_inst.rx_data ,
  input  [  0:0] \__pi_u_rx_uart.rx_controller_inst.first_stop_sampled ,
  input  [  0:0] \__pi_u_rx_uart.rx_done ,
  input  [  0:0] \__pi_u_rx_uart.rx_sync2 ,
  input  [  3:0] \__pi_u_rx_uart.tick_cnt_inst.tick_cnt ,
  input  [  3:0] \__pi_u_rx_uart.u_rx_baud_gen.acc ,
  input  [ 11:0] \__pi_u_rx_uart.u_rx_baud_gen.cnt ,
  output [  7:0] \__po_u_rx_uart.rx_data
);
endmodule
