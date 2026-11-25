module miter (
  input  [  0:0] \__pi_cts_n ,
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 31:0] \__pi_pwdata ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx ,
`ifdef DIRECT_CROSS_POINTS
`else
`endif
  output [ 15:0] \__mp_u_apb_regs.baud__gold ,
  output [  6:0] \__mp_u_apb_regs.cfg__gold ,
  output [  0:0] \__mp_u_apb_regs.frame_err_flag__gold ,
  output [  2:0] \__mp_u_apb_regs.ier__gold ,
  output [  0:0] \__mp_u_apb_regs.parity_err_flag__gold ,
  output [  7:0] \__mp_u_apb_regs.rx_data_reg__gold ,
  output [  0:0] \__mp_u_apb_regs.rx_done_flag__gold ,
  output [  0:0] \__mp_u_apb_regs.rx_done_prev__gold ,
  output [  0:0] \__mp_u_apb_regs.soft_rst_reg__gold ,
  output [  0:0] \__mp_u_apb_regs.start_reg__gold ,
  output [  7:0] \__mp_u_apb_regs.tx_data_reg__gold ,
  output [  3:0] \__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gold ,
  output [  0:0] \__mp_u_rx_uart.deframe_inst.parity_bit__gold ,
  output [  0:0] \__mp_u_rx_uart.deframe_inst.parity_exp__gold ,
  output [  7:0] \__mp_u_rx_uart.deframe_inst.rx_data__gold ,
  output [  0:0] \__mp_u_rx_uart.frame_err__gold ,
  output [  0:0] \__mp_u_rx_uart.overrun__gold ,
  output [  0:0] \__mp_u_rx_uart.parity_err__gold ,
  output [  0:0] \__mp_u_rx_uart.reset_release_pending__gold ,
  output [  0:0] \__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gold ,
  output [  0:0] \__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gold ,
  output [  7:0] \__mp_u_rx_uart.rx_data__gold ,
  output [  0:0] \__mp_u_rx_uart.rx_done__gold ,
  output [  0:0] \__mp_u_rx_uart.rx_sync1__gold ,
  output [  0:0] \__mp_u_rx_uart.rx_sync2__gold ,
  output [  3:0] \__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gold ,
  output [  3:0] \__mp_u_rx_uart.u_rx_baud_gen.acc__gold ,
  output [ 11:0] \__mp_u_rx_uart.u_rx_baud_gen.cnt__gold ,
  output [  0:0] \__mp_u_tx_uart.cts_n_sync1__gold ,
  output [  0:0] \__mp_u_tx_uart.cts_n_sync2__gold ,
  output [  0:0] \__mp_u_tx_uart.parity_latched__gold ,
  output [  3:0] \__mp_u_tx_uart.tick_cnt_ins.cnt__gold ,
  output [  0:0] \__mp_u_tx_uart.tx_done__gold ,
  output [  3:0] \__mp_u_tx_uart.u_baud_gen.acc__gold ,
  output [ 11:0] \__mp_u_tx_uart.u_baud_gen.cnt__gold ,
  output [  2:0] \__mp_u_tx_uart.u_bit_cnt.cnt__gold ,
  output [  7:0] \__mp_u_tx_uart.u_piso.data__gold ,
  output [  1:0] \__mp_u_tx_uart.u_stop_cnt.cnt__gold ,
  output [ 15:0] \__mp_u_apb_regs.baud__gate ,
  output [  6:0] \__mp_u_apb_regs.cfg__gate ,
  output [  0:0] \__mp_u_apb_regs.frame_err_flag__gate ,
  output [  2:0] \__mp_u_apb_regs.ier__gate ,
  output [  0:0] \__mp_u_apb_regs.parity_err_flag__gate ,
  output [  7:0] \__mp_u_apb_regs.rx_data_reg__gate ,
  output [  0:0] \__mp_u_apb_regs.rx_done_flag__gate ,
  output [  0:0] \__mp_u_apb_regs.rx_done_prev__gate ,
  output [  0:0] \__mp_u_apb_regs.soft_rst_reg__gate ,
  output [  0:0] \__mp_u_apb_regs.start_reg__gate ,
  output [  7:0] \__mp_u_apb_regs.tx_data_reg__gate ,
  output [  3:0] \__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gate ,
  output [  0:0] \__mp_u_rx_uart.deframe_inst.parity_bit__gate ,
  output [  0:0] \__mp_u_rx_uart.deframe_inst.parity_exp__gate ,
  output [  7:0] \__mp_u_rx_uart.deframe_inst.rx_data__gate ,
  output [  0:0] \__mp_u_rx_uart.frame_err__gate ,
  output [  0:0] \__mp_u_rx_uart.overrun__gate ,
  output [  0:0] \__mp_u_rx_uart.parity_err__gate ,
  output [  0:0] \__mp_u_rx_uart.reset_release_pending__gate ,
  output [  0:0] \__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gate ,
  output [  0:0] \__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gate ,
  output [  7:0] \__mp_u_rx_uart.rx_data__gate ,
  output [  0:0] \__mp_u_rx_uart.rx_done__gate ,
  output [  0:0] \__mp_u_rx_uart.rx_sync1__gate ,
  output [  0:0] \__mp_u_rx_uart.rx_sync2__gate ,
  output [  3:0] \__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gate ,
  output [  3:0] \__mp_u_rx_uart.u_rx_baud_gen.acc__gate ,
  output [ 11:0] \__mp_u_rx_uart.u_rx_baud_gen.cnt__gate ,
  output [  0:0] \__mp_u_tx_uart.cts_n_sync1__gate ,
  output [  0:0] \__mp_u_tx_uart.cts_n_sync2__gate ,
  output [  0:0] \__mp_u_tx_uart.parity_latched__gate ,
  output [  3:0] \__mp_u_tx_uart.tick_cnt_ins.cnt__gate ,
  output [  0:0] \__mp_u_tx_uart.tx_done__gate ,
  output [  3:0] \__mp_u_tx_uart.u_baud_gen.acc__gate ,
  output [ 11:0] \__mp_u_tx_uart.u_baud_gen.cnt__gate ,
  output [  2:0] \__mp_u_tx_uart.u_bit_cnt.cnt__gate ,
  output [  7:0] \__mp_u_tx_uart.u_piso.data__gate ,
  output [  1:0] \__mp_u_tx_uart.u_stop_cnt.cnt__gate ,
  output [  0:0] \__po_irq__gold ,
  output [  0:0] \__po_parity_err_status__gold ,
  output [ 31:0] \__po_prdata__gold ,
  output [  0:0] \__po_pready__gold ,
  output [  0:0] \__po_pslverr__gold ,
  output [  0:0] \__po_rts_n__gold ,
  output [  0:0] \__po_rx_done_status__gold ,
  output [  0:0] \__po_tx__gold ,
  output [  0:0] \__po_tx_done_status__gold ,
  output [  0:0] \__po_irq__gate ,
  output [  0:0] \__po_parity_err_status__gate ,
  output [ 31:0] \__po_prdata__gate ,
  output [  0:0] \__po_pready__gate ,
  output [  0:0] \__po_pslverr__gate ,
  output [  0:0] \__po_rts_n__gate ,
  output [  0:0] \__po_rx_done_status__gate ,
  output [  0:0] \__po_tx__gate ,
  output [  0:0] \__po_tx_done_status__gate
);
  \gold.apb_uart gold (
    .\__pi_cts_n (\__pi_cts_n ),
    .\__pi_paddr (\__pi_paddr ),
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_penable (\__pi_penable ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_psel (\__pi_psel ),
    .\__pi_pstrb (\__pi_pstrb ),
    .\__pi_pwdata (\__pi_pwdata ),
    .\__pi_pwrite (\__pi_pwrite ),
    .\__pi_rx (\__pi_rx ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__mp_u_apb_regs.baud (\__mp_u_apb_regs.baud__gold ),
    .\__mp_u_apb_regs.cfg (\__mp_u_apb_regs.cfg__gold ),
    .\__mp_u_apb_regs.frame_err_flag (\__mp_u_apb_regs.frame_err_flag__gold ),
    .\__mp_u_apb_regs.ier (\__mp_u_apb_regs.ier__gold ),
    .\__mp_u_apb_regs.parity_err_flag (\__mp_u_apb_regs.parity_err_flag__gold ),
    .\__mp_u_apb_regs.rx_data_reg (\__mp_u_apb_regs.rx_data_reg__gold ),
    .\__mp_u_apb_regs.rx_done_flag (\__mp_u_apb_regs.rx_done_flag__gold ),
    .\__mp_u_apb_regs.rx_done_prev (\__mp_u_apb_regs.rx_done_prev__gold ),
    .\__mp_u_apb_regs.soft_rst_reg (\__mp_u_apb_regs.soft_rst_reg__gold ),
    .\__mp_u_apb_regs.start_reg (\__mp_u_apb_regs.start_reg__gold ),
    .\__mp_u_apb_regs.tx_data_reg (\__mp_u_apb_regs.tx_data_reg__gold ),
    .\__mp_u_rx_uart.bit_cnt_inst.bit_cnt (\__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gold ),
    .\__mp_u_rx_uart.deframe_inst.parity_bit (\__mp_u_rx_uart.deframe_inst.parity_bit__gold ),
    .\__mp_u_rx_uart.deframe_inst.parity_exp (\__mp_u_rx_uart.deframe_inst.parity_exp__gold ),
    .\__mp_u_rx_uart.deframe_inst.rx_data (\__mp_u_rx_uart.deframe_inst.rx_data__gold ),
    .\__mp_u_rx_uart.frame_err (\__mp_u_rx_uart.frame_err__gold ),
    .\__mp_u_rx_uart.overrun (\__mp_u_rx_uart.overrun__gold ),
    .\__mp_u_rx_uart.parity_err (\__mp_u_rx_uart.parity_err__gold ),
    .\__mp_u_rx_uart.reset_release_pending (\__mp_u_rx_uart.reset_release_pending__gold ),
    .\__mp_u_rx_uart.rx_controller_inst.first_stop_sampled (\__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gold ),
    .\__mp_u_rx_uart.rx_controller_inst.frame_error_latched (\__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gold ),
    .\__mp_u_rx_uart.rx_data (\__mp_u_rx_uart.rx_data__gold ),
    .\__mp_u_rx_uart.rx_done (\__mp_u_rx_uart.rx_done__gold ),
    .\__mp_u_rx_uart.rx_sync1 (\__mp_u_rx_uart.rx_sync1__gold ),
    .\__mp_u_rx_uart.rx_sync2 (\__mp_u_rx_uart.rx_sync2__gold ),
    .\__mp_u_rx_uart.tick_cnt_inst.tick_cnt (\__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gold ),
    .\__mp_u_rx_uart.u_rx_baud_gen.acc (\__mp_u_rx_uart.u_rx_baud_gen.acc__gold ),
    .\__mp_u_rx_uart.u_rx_baud_gen.cnt (\__mp_u_rx_uart.u_rx_baud_gen.cnt__gold ),
    .\__mp_u_tx_uart.cts_n_sync1 (\__mp_u_tx_uart.cts_n_sync1__gold ),
    .\__mp_u_tx_uart.cts_n_sync2 (\__mp_u_tx_uart.cts_n_sync2__gold ),
    .\__mp_u_tx_uart.parity_latched (\__mp_u_tx_uart.parity_latched__gold ),
    .\__mp_u_tx_uart.tick_cnt_ins.cnt (\__mp_u_tx_uart.tick_cnt_ins.cnt__gold ),
    .\__mp_u_tx_uart.tx_done (\__mp_u_tx_uart.tx_done__gold ),
    .\__mp_u_tx_uart.u_baud_gen.acc (\__mp_u_tx_uart.u_baud_gen.acc__gold ),
    .\__mp_u_tx_uart.u_baud_gen.cnt (\__mp_u_tx_uart.u_baud_gen.cnt__gold ),
    .\__mp_u_tx_uart.u_bit_cnt.cnt (\__mp_u_tx_uart.u_bit_cnt.cnt__gold ),
    .\__mp_u_tx_uart.u_piso.data (\__mp_u_tx_uart.u_piso.data__gold ),
    .\__mp_u_tx_uart.u_stop_cnt.cnt (\__mp_u_tx_uart.u_stop_cnt.cnt__gold ),
    .\__po_irq (\__po_irq__gold ),
    .\__po_parity_err_status (\__po_parity_err_status__gold ),
    .\__po_prdata (\__po_prdata__gold ),
    .\__po_pready (\__po_pready__gold ),
    .\__po_pslverr (\__po_pslverr__gold ),
    .\__po_rts_n (\__po_rts_n__gold ),
    .\__po_rx_done_status (\__po_rx_done_status__gold ),
    .\__po_tx (\__po_tx__gold ),
    .\__po_tx_done_status (\__po_tx_done_status__gold )
  );
  \gate.apb_uart gate (
    .\__pi_cts_n (\__pi_cts_n ),
    .\__pi_paddr (\__pi_paddr ),
    .\__pi_pclk (\__pi_pclk ),
    .\__pi_penable (\__pi_penable ),
    .\__pi_presetn (\__pi_presetn ),
    .\__pi_psel (\__pi_psel ),
    .\__pi_pstrb (\__pi_pstrb ),
    .\__pi_pwdata (\__pi_pwdata ),
    .\__pi_pwrite (\__pi_pwrite ),
    .\__pi_rx (\__pi_rx ),
`ifdef DIRECT_CROSS_POINTS
`else
`endif
    .\__mp_u_apb_regs.baud (\__mp_u_apb_regs.baud__gate ),
    .\__mp_u_apb_regs.cfg (\__mp_u_apb_regs.cfg__gate ),
    .\__mp_u_apb_regs.frame_err_flag (\__mp_u_apb_regs.frame_err_flag__gate ),
    .\__mp_u_apb_regs.ier (\__mp_u_apb_regs.ier__gate ),
    .\__mp_u_apb_regs.parity_err_flag (\__mp_u_apb_regs.parity_err_flag__gate ),
    .\__mp_u_apb_regs.rx_data_reg (\__mp_u_apb_regs.rx_data_reg__gate ),
    .\__mp_u_apb_regs.rx_done_flag (\__mp_u_apb_regs.rx_done_flag__gate ),
    .\__mp_u_apb_regs.rx_done_prev (\__mp_u_apb_regs.rx_done_prev__gate ),
    .\__mp_u_apb_regs.soft_rst_reg (\__mp_u_apb_regs.soft_rst_reg__gate ),
    .\__mp_u_apb_regs.start_reg (\__mp_u_apb_regs.start_reg__gate ),
    .\__mp_u_apb_regs.tx_data_reg (\__mp_u_apb_regs.tx_data_reg__gate ),
    .\__mp_u_rx_uart.bit_cnt_inst.bit_cnt (\__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gate ),
    .\__mp_u_rx_uart.deframe_inst.parity_bit (\__mp_u_rx_uart.deframe_inst.parity_bit__gate ),
    .\__mp_u_rx_uart.deframe_inst.parity_exp (\__mp_u_rx_uart.deframe_inst.parity_exp__gate ),
    .\__mp_u_rx_uart.deframe_inst.rx_data (\__mp_u_rx_uart.deframe_inst.rx_data__gate ),
    .\__mp_u_rx_uart.frame_err (\__mp_u_rx_uart.frame_err__gate ),
    .\__mp_u_rx_uart.overrun (\__mp_u_rx_uart.overrun__gate ),
    .\__mp_u_rx_uart.parity_err (\__mp_u_rx_uart.parity_err__gate ),
    .\__mp_u_rx_uart.reset_release_pending (\__mp_u_rx_uart.reset_release_pending__gate ),
    .\__mp_u_rx_uart.rx_controller_inst.first_stop_sampled (\__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gate ),
    .\__mp_u_rx_uart.rx_controller_inst.frame_error_latched (\__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gate ),
    .\__mp_u_rx_uart.rx_data (\__mp_u_rx_uart.rx_data__gate ),
    .\__mp_u_rx_uart.rx_done (\__mp_u_rx_uart.rx_done__gate ),
    .\__mp_u_rx_uart.rx_sync1 (\__mp_u_rx_uart.rx_sync1__gate ),
    .\__mp_u_rx_uart.rx_sync2 (\__mp_u_rx_uart.rx_sync2__gate ),
    .\__mp_u_rx_uart.tick_cnt_inst.tick_cnt (\__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gate ),
    .\__mp_u_rx_uart.u_rx_baud_gen.acc (\__mp_u_rx_uart.u_rx_baud_gen.acc__gate ),
    .\__mp_u_rx_uart.u_rx_baud_gen.cnt (\__mp_u_rx_uart.u_rx_baud_gen.cnt__gate ),
    .\__mp_u_tx_uart.cts_n_sync1 (\__mp_u_tx_uart.cts_n_sync1__gate ),
    .\__mp_u_tx_uart.cts_n_sync2 (\__mp_u_tx_uart.cts_n_sync2__gate ),
    .\__mp_u_tx_uart.parity_latched (\__mp_u_tx_uart.parity_latched__gate ),
    .\__mp_u_tx_uart.tick_cnt_ins.cnt (\__mp_u_tx_uart.tick_cnt_ins.cnt__gate ),
    .\__mp_u_tx_uart.tx_done (\__mp_u_tx_uart.tx_done__gate ),
    .\__mp_u_tx_uart.u_baud_gen.acc (\__mp_u_tx_uart.u_baud_gen.acc__gate ),
    .\__mp_u_tx_uart.u_baud_gen.cnt (\__mp_u_tx_uart.u_baud_gen.cnt__gate ),
    .\__mp_u_tx_uart.u_bit_cnt.cnt (\__mp_u_tx_uart.u_bit_cnt.cnt__gate ),
    .\__mp_u_tx_uart.u_piso.data (\__mp_u_tx_uart.u_piso.data__gate ),
    .\__mp_u_tx_uart.u_stop_cnt.cnt (\__mp_u_tx_uart.u_stop_cnt.cnt__gate ),
    .\__po_irq (\__po_irq__gate ),
    .\__po_parity_err_status (\__po_parity_err_status__gate ),
    .\__po_prdata (\__po_prdata__gate ),
    .\__po_pready (\__po_pready__gate ),
    .\__po_pslverr (\__po_pslverr__gate ),
    .\__po_rts_n (\__po_rts_n__gate ),
    .\__po_rx_done_status (\__po_rx_done_status__gate ),
    .\__po_tx (\__po_tx__gate ),
    .\__po_tx_done_status (\__po_tx_done_status__gate )
  );
`ifdef ASSUME_DEFINED_INPUTS
  miter_def_prop #(1, "assume") \__pi_cts_n__assume (\__pi_cts_n );
  miter_def_prop #(12, "assume") \__pi_paddr__assume (\__pi_paddr );
  miter_def_prop #(1, "assume") \__pi_pclk__assume (\__pi_pclk );
  miter_def_prop #(1, "assume") \__pi_penable__assume (\__pi_penable );
  miter_def_prop #(1, "assume") \__pi_presetn__assume (\__pi_presetn );
  miter_def_prop #(1, "assume") \__pi_psel__assume (\__pi_psel );
  miter_def_prop #(4, "assume") \__pi_pstrb__assume (\__pi_pstrb );
  miter_def_prop #(32, "assume") \__pi_pwdata__assume (\__pi_pwdata );
  miter_def_prop #(1, "assume") \__pi_pwrite__assume (\__pi_pwrite );
  miter_def_prop #(1, "assume") \__pi_rx__assume (\__pi_rx );
`endif
`ifndef DIRECT_CROSS_POINTS
`endif
`ifdef CHECK_MATCH_POINTS
  miter_cmp_prop #(16, "assert") \__mp_u_apb_regs.baud__assert (\__mp_u_apb_regs.baud__gold , \__mp_u_apb_regs.baud__gate );
  miter_cmp_prop #(7, "assert") \__mp_u_apb_regs.cfg__assert (\__mp_u_apb_regs.cfg__gold , \__mp_u_apb_regs.cfg__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_apb_regs.frame_err_flag__assert (\__mp_u_apb_regs.frame_err_flag__gold , \__mp_u_apb_regs.frame_err_flag__gate );
  miter_cmp_prop #(3, "assert") \__mp_u_apb_regs.ier__assert (\__mp_u_apb_regs.ier__gold , \__mp_u_apb_regs.ier__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_apb_regs.parity_err_flag__assert (\__mp_u_apb_regs.parity_err_flag__gold , \__mp_u_apb_regs.parity_err_flag__gate );
  miter_cmp_prop #(8, "assert") \__mp_u_apb_regs.rx_data_reg__assert (\__mp_u_apb_regs.rx_data_reg__gold , \__mp_u_apb_regs.rx_data_reg__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_apb_regs.rx_done_flag__assert (\__mp_u_apb_regs.rx_done_flag__gold , \__mp_u_apb_regs.rx_done_flag__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_apb_regs.rx_done_prev__assert (\__mp_u_apb_regs.rx_done_prev__gold , \__mp_u_apb_regs.rx_done_prev__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_apb_regs.soft_rst_reg__assert (\__mp_u_apb_regs.soft_rst_reg__gold , \__mp_u_apb_regs.soft_rst_reg__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_apb_regs.start_reg__assert (\__mp_u_apb_regs.start_reg__gold , \__mp_u_apb_regs.start_reg__gate );
  miter_cmp_prop #(8, "assert") \__mp_u_apb_regs.tx_data_reg__assert (\__mp_u_apb_regs.tx_data_reg__gold , \__mp_u_apb_regs.tx_data_reg__gate );
  miter_cmp_prop #(4, "assert") \__mp_u_rx_uart.bit_cnt_inst.bit_cnt__assert (\__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gold , \__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.deframe_inst.parity_bit__assert (\__mp_u_rx_uart.deframe_inst.parity_bit__gold , \__mp_u_rx_uart.deframe_inst.parity_bit__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.deframe_inst.parity_exp__assert (\__mp_u_rx_uart.deframe_inst.parity_exp__gold , \__mp_u_rx_uart.deframe_inst.parity_exp__gate );
  miter_cmp_prop #(8, "assert") \__mp_u_rx_uart.deframe_inst.rx_data__assert (\__mp_u_rx_uart.deframe_inst.rx_data__gold , \__mp_u_rx_uart.deframe_inst.rx_data__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.frame_err__assert (\__mp_u_rx_uart.frame_err__gold , \__mp_u_rx_uart.frame_err__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.overrun__assert (\__mp_u_rx_uart.overrun__gold , \__mp_u_rx_uart.overrun__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.parity_err__assert (\__mp_u_rx_uart.parity_err__gold , \__mp_u_rx_uart.parity_err__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.reset_release_pending__assert (\__mp_u_rx_uart.reset_release_pending__gold , \__mp_u_rx_uart.reset_release_pending__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__assert (\__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gold , \__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.rx_controller_inst.frame_error_latched__assert (\__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gold , \__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gate );
  miter_cmp_prop #(8, "assert") \__mp_u_rx_uart.rx_data__assert (\__mp_u_rx_uart.rx_data__gold , \__mp_u_rx_uart.rx_data__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.rx_done__assert (\__mp_u_rx_uart.rx_done__gold , \__mp_u_rx_uart.rx_done__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.rx_sync1__assert (\__mp_u_rx_uart.rx_sync1__gold , \__mp_u_rx_uart.rx_sync1__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_rx_uart.rx_sync2__assert (\__mp_u_rx_uart.rx_sync2__gold , \__mp_u_rx_uart.rx_sync2__gate );
  miter_cmp_prop #(4, "assert") \__mp_u_rx_uart.tick_cnt_inst.tick_cnt__assert (\__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gold , \__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gate );
  miter_cmp_prop #(4, "assert") \__mp_u_rx_uart.u_rx_baud_gen.acc__assert (\__mp_u_rx_uart.u_rx_baud_gen.acc__gold , \__mp_u_rx_uart.u_rx_baud_gen.acc__gate );
  miter_cmp_prop #(12, "assert") \__mp_u_rx_uart.u_rx_baud_gen.cnt__assert (\__mp_u_rx_uart.u_rx_baud_gen.cnt__gold , \__mp_u_rx_uart.u_rx_baud_gen.cnt__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_tx_uart.cts_n_sync1__assert (\__mp_u_tx_uart.cts_n_sync1__gold , \__mp_u_tx_uart.cts_n_sync1__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_tx_uart.cts_n_sync2__assert (\__mp_u_tx_uart.cts_n_sync2__gold , \__mp_u_tx_uart.cts_n_sync2__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_tx_uart.parity_latched__assert (\__mp_u_tx_uart.parity_latched__gold , \__mp_u_tx_uart.parity_latched__gate );
  miter_cmp_prop #(4, "assert") \__mp_u_tx_uart.tick_cnt_ins.cnt__assert (\__mp_u_tx_uart.tick_cnt_ins.cnt__gold , \__mp_u_tx_uart.tick_cnt_ins.cnt__gate );
  miter_cmp_prop #(1, "assert") \__mp_u_tx_uart.tx_done__assert (\__mp_u_tx_uart.tx_done__gold , \__mp_u_tx_uart.tx_done__gate );
  miter_cmp_prop #(4, "assert") \__mp_u_tx_uart.u_baud_gen.acc__assert (\__mp_u_tx_uart.u_baud_gen.acc__gold , \__mp_u_tx_uart.u_baud_gen.acc__gate );
  miter_cmp_prop #(12, "assert") \__mp_u_tx_uart.u_baud_gen.cnt__assert (\__mp_u_tx_uart.u_baud_gen.cnt__gold , \__mp_u_tx_uart.u_baud_gen.cnt__gate );
  miter_cmp_prop #(3, "assert") \__mp_u_tx_uart.u_bit_cnt.cnt__assert (\__mp_u_tx_uart.u_bit_cnt.cnt__gold , \__mp_u_tx_uart.u_bit_cnt.cnt__gate );
  miter_cmp_prop #(8, "assert") \__mp_u_tx_uart.u_piso.data__assert (\__mp_u_tx_uart.u_piso.data__gold , \__mp_u_tx_uart.u_piso.data__gate );
  miter_cmp_prop #(2, "assert") \__mp_u_tx_uart.u_stop_cnt.cnt__assert (\__mp_u_tx_uart.u_stop_cnt.cnt__gold , \__mp_u_tx_uart.u_stop_cnt.cnt__gate );
`endif
`ifdef CHECK_OUTPUTS
  miter_cmp_prop #(1, "assert") \__po_irq__assert (\__po_irq__gold , \__po_irq__gate );
  miter_cmp_prop #(1, "assert") \__po_parity_err_status__assert (\__po_parity_err_status__gold , \__po_parity_err_status__gate );
  miter_cmp_prop #(32, "assert") \__po_prdata__assert (\__po_prdata__gold , \__po_prdata__gate );
  miter_cmp_prop #(1, "assert") \__po_pready__assert (\__po_pready__gold , \__po_pready__gate );
  miter_cmp_prop #(1, "assert") \__po_pslverr__assert (\__po_pslverr__gold , \__po_pslverr__gate );
  miter_cmp_prop #(1, "assert") \__po_rts_n__assert (\__po_rts_n__gold , \__po_rts_n__gate );
  miter_cmp_prop #(1, "assert") \__po_rx_done_status__assert (\__po_rx_done_status__gold , \__po_rx_done_status__gate );
  miter_cmp_prop #(1, "assert") \__po_tx__assert (\__po_tx__gold , \__po_tx__gate );
  miter_cmp_prop #(1, "assert") \__po_tx_done_status__assert (\__po_tx_done_status__gold , \__po_tx_done_status__gate );
`endif
`ifdef COVER_DEF_CROSS_POINTS
  `ifdef DIRECT_CROSS_POINTS
  `else
  `endif
`endif
`ifdef COVER_DEF_GOLD_MATCH_POINTS
  miter_def_prop #(16, "cover") \__mp_u_apb_regs.baud__gold_cover (\__mp_u_apb_regs.baud__gold );
  miter_def_prop #(7, "cover") \__mp_u_apb_regs.cfg__gold_cover (\__mp_u_apb_regs.cfg__gold );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.frame_err_flag__gold_cover (\__mp_u_apb_regs.frame_err_flag__gold );
  miter_def_prop #(3, "cover") \__mp_u_apb_regs.ier__gold_cover (\__mp_u_apb_regs.ier__gold );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.parity_err_flag__gold_cover (\__mp_u_apb_regs.parity_err_flag__gold );
  miter_def_prop #(8, "cover") \__mp_u_apb_regs.rx_data_reg__gold_cover (\__mp_u_apb_regs.rx_data_reg__gold );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.rx_done_flag__gold_cover (\__mp_u_apb_regs.rx_done_flag__gold );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.rx_done_prev__gold_cover (\__mp_u_apb_regs.rx_done_prev__gold );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.soft_rst_reg__gold_cover (\__mp_u_apb_regs.soft_rst_reg__gold );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.start_reg__gold_cover (\__mp_u_apb_regs.start_reg__gold );
  miter_def_prop #(8, "cover") \__mp_u_apb_regs.tx_data_reg__gold_cover (\__mp_u_apb_regs.tx_data_reg__gold );
  miter_def_prop #(4, "cover") \__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gold_cover (\__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.deframe_inst.parity_bit__gold_cover (\__mp_u_rx_uart.deframe_inst.parity_bit__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.deframe_inst.parity_exp__gold_cover (\__mp_u_rx_uart.deframe_inst.parity_exp__gold );
  miter_def_prop #(8, "cover") \__mp_u_rx_uart.deframe_inst.rx_data__gold_cover (\__mp_u_rx_uart.deframe_inst.rx_data__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.frame_err__gold_cover (\__mp_u_rx_uart.frame_err__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.overrun__gold_cover (\__mp_u_rx_uart.overrun__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.parity_err__gold_cover (\__mp_u_rx_uart.parity_err__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.reset_release_pending__gold_cover (\__mp_u_rx_uart.reset_release_pending__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gold_cover (\__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gold_cover (\__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gold );
  miter_def_prop #(8, "cover") \__mp_u_rx_uart.rx_data__gold_cover (\__mp_u_rx_uart.rx_data__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_done__gold_cover (\__mp_u_rx_uart.rx_done__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_sync1__gold_cover (\__mp_u_rx_uart.rx_sync1__gold );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_sync2__gold_cover (\__mp_u_rx_uart.rx_sync2__gold );
  miter_def_prop #(4, "cover") \__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gold_cover (\__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gold );
  miter_def_prop #(4, "cover") \__mp_u_rx_uart.u_rx_baud_gen.acc__gold_cover (\__mp_u_rx_uart.u_rx_baud_gen.acc__gold );
  miter_def_prop #(12, "cover") \__mp_u_rx_uart.u_rx_baud_gen.cnt__gold_cover (\__mp_u_rx_uart.u_rx_baud_gen.cnt__gold );
  miter_def_prop #(1, "cover") \__mp_u_tx_uart.cts_n_sync1__gold_cover (\__mp_u_tx_uart.cts_n_sync1__gold );
  miter_def_prop #(1, "cover") \__mp_u_tx_uart.cts_n_sync2__gold_cover (\__mp_u_tx_uart.cts_n_sync2__gold );
  miter_def_prop #(1, "cover") \__mp_u_tx_uart.parity_latched__gold_cover (\__mp_u_tx_uart.parity_latched__gold );
  miter_def_prop #(4, "cover") \__mp_u_tx_uart.tick_cnt_ins.cnt__gold_cover (\__mp_u_tx_uart.tick_cnt_ins.cnt__gold );
  miter_def_prop #(1, "cover") \__mp_u_tx_uart.tx_done__gold_cover (\__mp_u_tx_uart.tx_done__gold );
  miter_def_prop #(4, "cover") \__mp_u_tx_uart.u_baud_gen.acc__gold_cover (\__mp_u_tx_uart.u_baud_gen.acc__gold );
  miter_def_prop #(12, "cover") \__mp_u_tx_uart.u_baud_gen.cnt__gold_cover (\__mp_u_tx_uart.u_baud_gen.cnt__gold );
  miter_def_prop #(3, "cover") \__mp_u_tx_uart.u_bit_cnt.cnt__gold_cover (\__mp_u_tx_uart.u_bit_cnt.cnt__gold );
  miter_def_prop #(8, "cover") \__mp_u_tx_uart.u_piso.data__gold_cover (\__mp_u_tx_uart.u_piso.data__gold );
  miter_def_prop #(2, "cover") \__mp_u_tx_uart.u_stop_cnt.cnt__gold_cover (\__mp_u_tx_uart.u_stop_cnt.cnt__gold );
`endif
`ifdef COVER_DEF_GATE_MATCH_POINTS
  miter_def_prop #(16, "cover") \__mp_u_apb_regs.baud__gate_cover (\__mp_u_apb_regs.baud__gate );
  miter_def_prop #(7, "cover") \__mp_u_apb_regs.cfg__gate_cover (\__mp_u_apb_regs.cfg__gate );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.frame_err_flag__gate_cover (\__mp_u_apb_regs.frame_err_flag__gate );
  miter_def_prop #(3, "cover") \__mp_u_apb_regs.ier__gate_cover (\__mp_u_apb_regs.ier__gate );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.parity_err_flag__gate_cover (\__mp_u_apb_regs.parity_err_flag__gate );
  miter_def_prop #(8, "cover") \__mp_u_apb_regs.rx_data_reg__gate_cover (\__mp_u_apb_regs.rx_data_reg__gate );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.rx_done_flag__gate_cover (\__mp_u_apb_regs.rx_done_flag__gate );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.rx_done_prev__gate_cover (\__mp_u_apb_regs.rx_done_prev__gate );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.soft_rst_reg__gate_cover (\__mp_u_apb_regs.soft_rst_reg__gate );
  miter_def_prop #(1, "cover") \__mp_u_apb_regs.start_reg__gate_cover (\__mp_u_apb_regs.start_reg__gate );
  miter_def_prop #(8, "cover") \__mp_u_apb_regs.tx_data_reg__gate_cover (\__mp_u_apb_regs.tx_data_reg__gate );
  miter_def_prop #(4, "cover") \__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gate_cover (\__mp_u_rx_uart.bit_cnt_inst.bit_cnt__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.deframe_inst.parity_bit__gate_cover (\__mp_u_rx_uart.deframe_inst.parity_bit__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.deframe_inst.parity_exp__gate_cover (\__mp_u_rx_uart.deframe_inst.parity_exp__gate );
  miter_def_prop #(8, "cover") \__mp_u_rx_uart.deframe_inst.rx_data__gate_cover (\__mp_u_rx_uart.deframe_inst.rx_data__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.frame_err__gate_cover (\__mp_u_rx_uart.frame_err__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.overrun__gate_cover (\__mp_u_rx_uart.overrun__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.parity_err__gate_cover (\__mp_u_rx_uart.parity_err__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.reset_release_pending__gate_cover (\__mp_u_rx_uart.reset_release_pending__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gate_cover (\__mp_u_rx_uart.rx_controller_inst.first_stop_sampled__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gate_cover (\__mp_u_rx_uart.rx_controller_inst.frame_error_latched__gate );
  miter_def_prop #(8, "cover") \__mp_u_rx_uart.rx_data__gate_cover (\__mp_u_rx_uart.rx_data__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_done__gate_cover (\__mp_u_rx_uart.rx_done__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_sync1__gate_cover (\__mp_u_rx_uart.rx_sync1__gate );
  miter_def_prop #(1, "cover") \__mp_u_rx_uart.rx_sync2__gate_cover (\__mp_u_rx_uart.rx_sync2__gate );
  miter_def_prop #(4, "cover") \__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gate_cover (\__mp_u_rx_uart.tick_cnt_inst.tick_cnt__gate );
  miter_def_prop #(4, "cover") \__mp_u_rx_uart.u_rx_baud_gen.acc__gate_cover (\__mp_u_rx_uart.u_rx_baud_gen.acc__gate );
  miter_def_prop #(12, "cover") \__mp_u_rx_uart.u_rx_baud_gen.cnt__gate_cover (\__mp_u_rx_uart.u_rx_baud_gen.cnt__gate );
  miter_def_prop #(1, "cover") \__mp_u_tx_uart.cts_n_sync1__gate_cover (\__mp_u_tx_uart.cts_n_sync1__gate );
  miter_def_prop #(1, "cover") \__mp_u_tx_uart.cts_n_sync2__gate_cover (\__mp_u_tx_uart.cts_n_sync2__gate );
  miter_def_prop #(1, "cover") \__mp_u_tx_uart.parity_latched__gate_cover (\__mp_u_tx_uart.parity_latched__gate );
  miter_def_prop #(4, "cover") \__mp_u_tx_uart.tick_cnt_ins.cnt__gate_cover (\__mp_u_tx_uart.tick_cnt_ins.cnt__gate );
  miter_def_prop #(1, "cover") \__mp_u_tx_uart.tx_done__gate_cover (\__mp_u_tx_uart.tx_done__gate );
  miter_def_prop #(4, "cover") \__mp_u_tx_uart.u_baud_gen.acc__gate_cover (\__mp_u_tx_uart.u_baud_gen.acc__gate );
  miter_def_prop #(12, "cover") \__mp_u_tx_uart.u_baud_gen.cnt__gate_cover (\__mp_u_tx_uart.u_baud_gen.cnt__gate );
  miter_def_prop #(3, "cover") \__mp_u_tx_uart.u_bit_cnt.cnt__gate_cover (\__mp_u_tx_uart.u_bit_cnt.cnt__gate );
  miter_def_prop #(8, "cover") \__mp_u_tx_uart.u_piso.data__gate_cover (\__mp_u_tx_uart.u_piso.data__gate );
  miter_def_prop #(2, "cover") \__mp_u_tx_uart.u_stop_cnt.cnt__gate_cover (\__mp_u_tx_uart.u_stop_cnt.cnt__gate );
`endif
`ifdef COVER_DEF_GOLD_OUTPUTS
  miter_def_prop #(1, "cover") \__po_irq__gold_cover (\__po_irq__gold );
  miter_def_prop #(1, "cover") \__po_parity_err_status__gold_cover (\__po_parity_err_status__gold );
  miter_def_prop #(32, "cover") \__po_prdata__gold_cover (\__po_prdata__gold );
  miter_def_prop #(1, "cover") \__po_pready__gold_cover (\__po_pready__gold );
  miter_def_prop #(1, "cover") \__po_pslverr__gold_cover (\__po_pslverr__gold );
  miter_def_prop #(1, "cover") \__po_rts_n__gold_cover (\__po_rts_n__gold );
  miter_def_prop #(1, "cover") \__po_rx_done_status__gold_cover (\__po_rx_done_status__gold );
  miter_def_prop #(1, "cover") \__po_tx__gold_cover (\__po_tx__gold );
  miter_def_prop #(1, "cover") \__po_tx_done_status__gold_cover (\__po_tx_done_status__gold );
`endif
`ifdef COVER_DEF_GATE_OUTPUTS
  miter_def_prop #(1, "cover") \__po_irq__gate_cover (\__po_irq__gate );
  miter_def_prop #(1, "cover") \__po_parity_err_status__gate_cover (\__po_parity_err_status__gate );
  miter_def_prop #(32, "cover") \__po_prdata__gate_cover (\__po_prdata__gate );
  miter_def_prop #(1, "cover") \__po_pready__gate_cover (\__po_pready__gate );
  miter_def_prop #(1, "cover") \__po_pslverr__gate_cover (\__po_pslverr__gate );
  miter_def_prop #(1, "cover") \__po_rts_n__gate_cover (\__po_rts_n__gate );
  miter_def_prop #(1, "cover") \__po_rx_done_status__gate_cover (\__po_rx_done_status__gate );
  miter_def_prop #(1, "cover") \__po_tx__gate_cover (\__po_tx__gate );
  miter_def_prop #(1, "cover") \__po_tx_done_status__gate_cover (\__po_tx_done_status__gate );
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
module \gold.apb_uart (
  input  [  0:0] \__pi_cts_n ,
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 31:0] \__pi_pwdata ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx ,
  output [ 15:0] \__mp_u_apb_regs.baud ,
  output [  6:0] \__mp_u_apb_regs.cfg ,
  output [  0:0] \__mp_u_apb_regs.frame_err_flag ,
  output [  2:0] \__mp_u_apb_regs.ier ,
  output [  0:0] \__mp_u_apb_regs.parity_err_flag ,
  output [  7:0] \__mp_u_apb_regs.rx_data_reg ,
  output [  0:0] \__mp_u_apb_regs.rx_done_flag ,
  output [  0:0] \__mp_u_apb_regs.rx_done_prev ,
  output [  0:0] \__mp_u_apb_regs.soft_rst_reg ,
  output [  0:0] \__mp_u_apb_regs.start_reg ,
  output [  7:0] \__mp_u_apb_regs.tx_data_reg ,
  output [  3:0] \__mp_u_rx_uart.bit_cnt_inst.bit_cnt ,
  output [  0:0] \__mp_u_rx_uart.deframe_inst.parity_bit ,
  output [  0:0] \__mp_u_rx_uart.deframe_inst.parity_exp ,
  output [  7:0] \__mp_u_rx_uart.deframe_inst.rx_data ,
  output [  0:0] \__mp_u_rx_uart.frame_err ,
  output [  0:0] \__mp_u_rx_uart.overrun ,
  output [  0:0] \__mp_u_rx_uart.parity_err ,
  output [  0:0] \__mp_u_rx_uart.reset_release_pending ,
  output [  0:0] \__mp_u_rx_uart.rx_controller_inst.first_stop_sampled ,
  output [  0:0] \__mp_u_rx_uart.rx_controller_inst.frame_error_latched ,
  output [  7:0] \__mp_u_rx_uart.rx_data ,
  output [  0:0] \__mp_u_rx_uart.rx_done ,
  output [  0:0] \__mp_u_rx_uart.rx_sync1 ,
  output [  0:0] \__mp_u_rx_uart.rx_sync2 ,
  output [  3:0] \__mp_u_rx_uart.tick_cnt_inst.tick_cnt ,
  output [  3:0] \__mp_u_rx_uart.u_rx_baud_gen.acc ,
  output [ 11:0] \__mp_u_rx_uart.u_rx_baud_gen.cnt ,
  output [  0:0] \__mp_u_tx_uart.cts_n_sync1 ,
  output [  0:0] \__mp_u_tx_uart.cts_n_sync2 ,
  output [  0:0] \__mp_u_tx_uart.parity_latched ,
  output [  3:0] \__mp_u_tx_uart.tick_cnt_ins.cnt ,
  output [  0:0] \__mp_u_tx_uart.tx_done ,
  output [  3:0] \__mp_u_tx_uart.u_baud_gen.acc ,
  output [ 11:0] \__mp_u_tx_uart.u_baud_gen.cnt ,
  output [  2:0] \__mp_u_tx_uart.u_bit_cnt.cnt ,
  output [  7:0] \__mp_u_tx_uart.u_piso.data ,
  output [  1:0] \__mp_u_tx_uart.u_stop_cnt.cnt ,
  output [  0:0] \__po_irq ,
  output [  0:0] \__po_parity_err_status ,
  output [ 31:0] \__po_prdata ,
  output [  0:0] \__po_pready ,
  output [  0:0] \__po_pslverr ,
  output [  0:0] \__po_rts_n ,
  output [  0:0] \__po_rx_done_status ,
  output [  0:0] \__po_tx ,
  output [  0:0] \__po_tx_done_status
);
endmodule
module \gate.apb_uart (
  input  [  0:0] \__pi_cts_n ,
  input  [ 11:0] \__pi_paddr ,
  input  [  0:0] \__pi_pclk ,
  input  [  0:0] \__pi_penable ,
  input  [  0:0] \__pi_presetn ,
  input  [  0:0] \__pi_psel ,
  input  [  3:0] \__pi_pstrb ,
  input  [ 31:0] \__pi_pwdata ,
  input  [  0:0] \__pi_pwrite ,
  input  [  0:0] \__pi_rx ,
  output [ 15:0] \__mp_u_apb_regs.baud ,
  output [  6:0] \__mp_u_apb_regs.cfg ,
  output [  0:0] \__mp_u_apb_regs.frame_err_flag ,
  output [  2:0] \__mp_u_apb_regs.ier ,
  output [  0:0] \__mp_u_apb_regs.parity_err_flag ,
  output [  7:0] \__mp_u_apb_regs.rx_data_reg ,
  output [  0:0] \__mp_u_apb_regs.rx_done_flag ,
  output [  0:0] \__mp_u_apb_regs.rx_done_prev ,
  output [  0:0] \__mp_u_apb_regs.soft_rst_reg ,
  output [  0:0] \__mp_u_apb_regs.start_reg ,
  output [  7:0] \__mp_u_apb_regs.tx_data_reg ,
  output [  3:0] \__mp_u_rx_uart.bit_cnt_inst.bit_cnt ,
  output [  0:0] \__mp_u_rx_uart.deframe_inst.parity_bit ,
  output [  0:0] \__mp_u_rx_uart.deframe_inst.parity_exp ,
  output [  7:0] \__mp_u_rx_uart.deframe_inst.rx_data ,
  output [  0:0] \__mp_u_rx_uart.frame_err ,
  output [  0:0] \__mp_u_rx_uart.overrun ,
  output [  0:0] \__mp_u_rx_uart.parity_err ,
  output [  0:0] \__mp_u_rx_uart.reset_release_pending ,
  output [  0:0] \__mp_u_rx_uart.rx_controller_inst.first_stop_sampled ,
  output [  0:0] \__mp_u_rx_uart.rx_controller_inst.frame_error_latched ,
  output [  7:0] \__mp_u_rx_uart.rx_data ,
  output [  0:0] \__mp_u_rx_uart.rx_done ,
  output [  0:0] \__mp_u_rx_uart.rx_sync1 ,
  output [  0:0] \__mp_u_rx_uart.rx_sync2 ,
  output [  3:0] \__mp_u_rx_uart.tick_cnt_inst.tick_cnt ,
  output [  3:0] \__mp_u_rx_uart.u_rx_baud_gen.acc ,
  output [ 11:0] \__mp_u_rx_uart.u_rx_baud_gen.cnt ,
  output [  0:0] \__mp_u_tx_uart.cts_n_sync1 ,
  output [  0:0] \__mp_u_tx_uart.cts_n_sync2 ,
  output [  0:0] \__mp_u_tx_uart.parity_latched ,
  output [  3:0] \__mp_u_tx_uart.tick_cnt_ins.cnt ,
  output [  0:0] \__mp_u_tx_uart.tx_done ,
  output [  3:0] \__mp_u_tx_uart.u_baud_gen.acc ,
  output [ 11:0] \__mp_u_tx_uart.u_baud_gen.cnt ,
  output [  2:0] \__mp_u_tx_uart.u_bit_cnt.cnt ,
  output [  7:0] \__mp_u_tx_uart.u_piso.data ,
  output [  1:0] \__mp_u_tx_uart.u_stop_cnt.cnt ,
  output [  0:0] \__po_irq ,
  output [  0:0] \__po_parity_err_status ,
  output [ 31:0] \__po_prdata ,
  output [  0:0] \__po_pready ,
  output [  0:0] \__po_pslverr ,
  output [  0:0] \__po_rts_n ,
  output [  0:0] \__po_rx_done_status ,
  output [  0:0] \__po_tx ,
  output [  0:0] \__po_tx_done_status
);
endmodule
