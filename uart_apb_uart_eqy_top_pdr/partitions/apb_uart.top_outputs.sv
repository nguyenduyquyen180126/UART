module miter (
  input  [  0:0] \__pi_cts_n ,
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 15:0] \__pi_pwdata__15_0 ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [  0:0] \__po_irq__gold ,
  output [ 31:0] \__po_prdata__gold ,
  output [  0:0] \__po_pready__gold ,
  output [  0:0] \__po_pslverr__gold ,
  output [  0:0] \__po_rts_n__gold ,
  output [  0:0] \__po_tx__gold ,
  output [  0:0] \__po_irq__gate ,
  output [ 31:0] \__po_prdata__gate ,
  output [  0:0] \__po_pready__gate ,
  output [  0:0] \__po_pslverr__gate ,
  output [  0:0] \__po_rts_n__gate ,
  output [  0:0] \__po_tx__gate
);
  \gold.apb_uart.top_outputs gold (
    .\__pi_cts_n (\__pi_cts_n ),
    .\__pi_paddr (\__pi_paddr ),
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_penable (\__pi_penable ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_psel (\__pi_psel ),
    .\__pi_pstrb (\__pi_pstrb ),
    .\__pi_pwdata__15_0 (\__pi_pwdata__15_0 ),
    .\__pi_pwrite (\__pi_pwrite ),
    .\__pi_rx (\__pi_rx ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_irq (\__po_irq__gold ),
    .\__po_prdata (\__po_prdata__gold ),
    .\__po_pready (\__po_pready__gold ),
    .\__po_pslverr (\__po_pslverr__gold ),
    .\__po_rts_n (\__po_rts_n__gold ),
    .\__po_tx (\__po_tx__gold )
  );
  \gate.apb_uart.top_outputs gate (
    .\__pi_cts_n (\__pi_cts_n ),
    .\__pi_paddr (\__pi_paddr ),
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_penable (\__pi_penable ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_psel (\__pi_psel ),
    .\__pi_pstrb (\__pi_pstrb ),
    .\__pi_pwdata__15_0 (\__pi_pwdata__15_0 ),
    .\__pi_pwrite (\__pi_pwrite ),
    .\__pi_rx (\__pi_rx ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__po_irq (\__po_irq__gate ),
    .\__po_prdata (\__po_prdata__gate ),
    .\__po_pready (\__po_pready__gate ),
    .\__po_pslverr (\__po_pslverr__gate ),
    .\__po_rts_n (\__po_rts_n__gate ),
    .\__po_tx (\__po_tx__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(1, "assume") \__pi_cts_n__assume (\__pi_cts_n );
  miter_def_prop #(12, "assume") \__pi_paddr__assume (\__pi_paddr );
  miter_def_prop #(1, "assume") \__pi_pclk__assume (\__pi_pclk );
  miter_def_prop #(1, "assume") \__pi_penable__assume (\__pi_penable );
  miter_def_prop #(1, "assume") \__pi_presetn__assume (\__pi_presetn );
  miter_def_prop #(1, "assume") \__pi_psel__assume (\__pi_psel );
  miter_def_prop #(4, "assume") \__pi_pstrb__assume (\__pi_pstrb );
  miter_def_prop #(16, "assume") \__pi_pwdata__15_0__assume (\__pi_pwdata__15_0 );
  miter_def_prop #(1, "assume") \__pi_pwrite__assume (\__pi_pwrite );
  miter_def_prop #(1, "assume") \__pi_rx__assume (\__pi_rx );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(1, "assert") \__po_irq__assert (\__po_irq__gold , \__po_irq__gate );
  miter_cmp_prop #(32, "assert") \__po_prdata__assert (\__po_prdata__gold , \__po_prdata__gate );
  miter_cmp_prop #(1, "assert") \__po_pready__assert (\__po_pready__gold , \__po_pready__gate );
  miter_cmp_prop #(1, "assert") \__po_pslverr__assert (\__po_pslverr__gold , \__po_pslverr__gate );
  miter_cmp_prop #(1, "assert") \__po_rts_n__assert (\__po_rts_n__gold , \__po_rts_n__gate );
  miter_cmp_prop #(1, "assert") \__po_tx__assert (\__po_tx__gold , \__po_tx__gate );
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
  miter_def_prop #(32, "cover") \__po_prdata__gold_cover (\__po_prdata__gold );
  miter_def_prop #(1, "cover") \__po_pready__gold_cover (\__po_pready__gold );
  miter_def_prop #(1, "cover") \__po_pslverr__gold_cover (\__po_pslverr__gold );
  miter_def_prop #(1, "cover") \__po_rts_n__gold_cover (\__po_rts_n__gold );
  miter_def_prop #(1, "cover") \__po_tx__gold_cover (\__po_tx__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(1, "cover") \__po_irq__gate_cover (\__po_irq__gate );
  miter_def_prop #(32, "cover") \__po_prdata__gate_cover (\__po_prdata__gate );
  miter_def_prop #(1, "cover") \__po_pready__gate_cover (\__po_pready__gate );
  miter_def_prop #(1, "cover") \__po_pslverr__gate_cover (\__po_pslverr__gate );
  miter_def_prop #(1, "cover") \__po_rts_n__gate_cover (\__po_rts_n__gate );
  miter_def_prop #(1, "cover") \__po_tx__gate_cover (\__po_tx__gate );
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
module \gold.apb_uart.top_outputs (
  input  [  0:0] \__pi_cts_n ,
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 15:0] \__pi_pwdata__15_0 ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx ,
  output [  0:0] \__po_irq ,
  output [ 31:0] \__po_prdata ,
  output [  0:0] \__po_pready ,
  output [  0:0] \__po_pslverr ,
  output [  0:0] \__po_rts_n ,
  output [  0:0] \__po_tx
);
endmodule
module \gate.apb_uart.top_outputs (
  input  [  0:0] \__pi_cts_n ,
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 15:0] \__pi_pwdata__15_0 ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx ,
  output [  0:0] \__po_irq ,
  output [ 31:0] \__po_prdata ,
  output [  0:0] \__po_pready ,
  output [  0:0] \__po_pslverr ,
  output [  0:0] \__po_rts_n ,
  output [  0:0] \__po_tx
);
endmodule
