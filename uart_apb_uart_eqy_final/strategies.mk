.DEFAULT_GOAL := all

strategies/apb_uart.u_tx_uart.u_stop_cnt.cnt/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.u_stop_cnt.cnt'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.u_stop_cnt.cnt/simple; source run.sh"

strategies/apb_uart.u_tx_uart.u_stop_cnt.cnt/pdr/status: strategies/apb_uart.u_tx_uart.u_stop_cnt.cnt/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.u_stop_cnt.cnt'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.u_stop_cnt.cnt/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.u_piso.data/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.u_piso.data'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.u_piso.data/simple; source run.sh"

strategies/apb_uart.u_tx_uart.u_piso.data/pdr/status: strategies/apb_uart.u_tx_uart.u_piso.data/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.u_piso.data'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.u_piso.data/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.u_bit_cnt.cnt/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.u_bit_cnt.cnt'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.u_bit_cnt.cnt/simple; source run.sh"

strategies/apb_uart.u_tx_uart.u_bit_cnt.cnt/pdr/status: strategies/apb_uart.u_tx_uart.u_bit_cnt.cnt/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.u_bit_cnt.cnt'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.u_bit_cnt.cnt/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.u_baud_gen.cnt/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.u_baud_gen.cnt'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.u_baud_gen.cnt/simple; source run.sh"

strategies/apb_uart.u_tx_uart.u_baud_gen.cnt/pdr/status: strategies/apb_uart.u_tx_uart.u_baud_gen.cnt/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.u_baud_gen.cnt'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.u_baud_gen.cnt/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.u_baud_gen.acc/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.u_baud_gen.acc'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.u_baud_gen.acc/simple; source run.sh"

strategies/apb_uart.u_tx_uart.u_baud_gen.acc/pdr/status: strategies/apb_uart.u_tx_uart.u_baud_gen.acc/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.u_baud_gen.acc'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.u_baud_gen.acc/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.tx_done/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.tx_done'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.tx_done/simple; source run.sh"

strategies/apb_uart.u_tx_uart.tx_done/pdr/status: strategies/apb_uart.u_tx_uart.tx_done/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.tx_done'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.tx_done/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.tick_cnt_ins.cnt/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.tick_cnt_ins.cnt'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.tick_cnt_ins.cnt/simple; source run.sh"

strategies/apb_uart.u_tx_uart.tick_cnt_ins.cnt/pdr/status: strategies/apb_uart.u_tx_uart.tick_cnt_ins.cnt/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.tick_cnt_ins.cnt'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.tick_cnt_ins.cnt/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.parity_latched/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.parity_latched'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.parity_latched/simple; source run.sh"

strategies/apb_uart.u_tx_uart.parity_latched/pdr/status: strategies/apb_uart.u_tx_uart.parity_latched/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.parity_latched'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.parity_latched/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.cts_n_sync2/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.cts_n_sync2'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.cts_n_sync2/simple; source run.sh"

strategies/apb_uart.u_tx_uart.cts_n_sync2/pdr/status: strategies/apb_uart.u_tx_uart.cts_n_sync2/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.cts_n_sync2'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.cts_n_sync2/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_tx_uart.cts_n_sync1/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_tx_uart.cts_n_sync1'.."
	@bash -c "cd strategies/apb_uart.u_tx_uart.cts_n_sync1/simple; source run.sh"

strategies/apb_uart.u_tx_uart.cts_n_sync1/pdr/status: strategies/apb_uart.u_tx_uart.cts_n_sync1/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_tx_uart.cts_n_sync1'.."; \
		bash -c "cd strategies/apb_uart.u_tx_uart.cts_n_sync1/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.u_rx_baud_gen.cnt/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.u_rx_baud_gen.cnt'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.u_rx_baud_gen.cnt/simple; source run.sh"

strategies/apb_uart.u_rx_uart.u_rx_baud_gen.cnt/pdr/status: strategies/apb_uart.u_rx_uart.u_rx_baud_gen.cnt/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.u_rx_baud_gen.cnt'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.u_rx_baud_gen.cnt/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.u_rx_baud_gen.acc/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.u_rx_baud_gen.acc'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.u_rx_baud_gen.acc/simple; source run.sh"

strategies/apb_uart.u_rx_uart.u_rx_baud_gen.acc/pdr/status: strategies/apb_uart.u_rx_uart.u_rx_baud_gen.acc/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.u_rx_baud_gen.acc'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.u_rx_baud_gen.acc/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.tick_cnt_inst.tick_cnt/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.tick_cnt_inst.tick_cnt'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.tick_cnt_inst.tick_cnt/simple; source run.sh"

strategies/apb_uart.u_rx_uart.tick_cnt_inst.tick_cnt/pdr/status: strategies/apb_uart.u_rx_uart.tick_cnt_inst.tick_cnt/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.tick_cnt_inst.tick_cnt'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.tick_cnt_inst.tick_cnt/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.sipo_inst.data_out/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.sipo_inst.data_out'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.sipo_inst.data_out/simple; source run.sh"

strategies/apb_uart.u_rx_uart.sipo_inst.data_out/pdr/status: strategies/apb_uart.u_rx_uart.sipo_inst.data_out/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.sipo_inst.data_out'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.sipo_inst.data_out/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.rx_sync2/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.rx_sync2'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.rx_sync2/simple; source run.sh"

strategies/apb_uart.u_rx_uart.rx_sync2/pdr/status: strategies/apb_uart.u_rx_uart.rx_sync2/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.rx_sync2'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.rx_sync2/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.rx_sync1/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.rx_sync1'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.rx_sync1/simple; source run.sh"

strategies/apb_uart.u_rx_uart.rx_sync1/pdr/status: strategies/apb_uart.u_rx_uart.rx_sync1/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.rx_sync1'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.rx_sync1/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.rx_done/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.rx_done'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.rx_done/simple; source run.sh"

strategies/apb_uart.u_rx_uart.rx_done/pdr/status: strategies/apb_uart.u_rx_uart.rx_done/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.rx_done'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.rx_done/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.rx_data/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.rx_data'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.rx_data/simple; source run.sh"

strategies/apb_uart.u_rx_uart.rx_data/pdr/status: strategies/apb_uart.u_rx_uart.rx_data/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.rx_data'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.rx_data/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/simple; source run.sh"

strategies/apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/pdr/status: strategies/apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/simple; source run.sh"

strategies/apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/pdr/status: strategies/apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.reset_release_pending/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.reset_release_pending'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.reset_release_pending/simple; source run.sh"

strategies/apb_uart.u_rx_uart.reset_release_pending/pdr/status: strategies/apb_uart.u_rx_uart.reset_release_pending/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.reset_release_pending'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.reset_release_pending/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.parity_err/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.parity_err'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.parity_err/simple; source run.sh"

strategies/apb_uart.u_rx_uart.parity_err/pdr/status: strategies/apb_uart.u_rx_uart.parity_err/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.parity_err'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.parity_err/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.overrun/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.overrun'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.overrun/simple; source run.sh"

strategies/apb_uart.u_rx_uart.overrun/pdr/status: strategies/apb_uart.u_rx_uart.overrun/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.overrun'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.overrun/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.frame_err/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.frame_err'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.frame_err/simple; source run.sh"

strategies/apb_uart.u_rx_uart.frame_err/pdr/status: strategies/apb_uart.u_rx_uart.frame_err/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.frame_err'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.frame_err/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.deframe_inst.rx_data/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.deframe_inst.rx_data'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.deframe_inst.rx_data/simple; source run.sh"

strategies/apb_uart.u_rx_uart.deframe_inst.rx_data/pdr/status: strategies/apb_uart.u_rx_uart.deframe_inst.rx_data/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.deframe_inst.rx_data'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.deframe_inst.rx_data/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.deframe_inst.parity_exp/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.deframe_inst.parity_exp'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.deframe_inst.parity_exp/simple; source run.sh"

strategies/apb_uart.u_rx_uart.deframe_inst.parity_exp/pdr/status: strategies/apb_uart.u_rx_uart.deframe_inst.parity_exp/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.deframe_inst.parity_exp'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.deframe_inst.parity_exp/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.deframe_inst.parity_bit/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.deframe_inst.parity_bit'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.deframe_inst.parity_bit/simple; source run.sh"

strategies/apb_uart.u_rx_uart.deframe_inst.parity_bit/pdr/status: strategies/apb_uart.u_rx_uart.deframe_inst.parity_bit/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.deframe_inst.parity_bit'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.deframe_inst.parity_bit/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_rx_uart.bit_cnt_inst.bit_cnt/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_rx_uart.bit_cnt_inst.bit_cnt'.."
	@bash -c "cd strategies/apb_uart.u_rx_uart.bit_cnt_inst.bit_cnt/simple; source run.sh"

strategies/apb_uart.u_rx_uart.bit_cnt_inst.bit_cnt/pdr/status: strategies/apb_uart.u_rx_uart.bit_cnt_inst.bit_cnt/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_rx_uart.bit_cnt_inst.bit_cnt'.."; \
		bash -c "cd strategies/apb_uart.u_rx_uart.bit_cnt_inst.bit_cnt/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.tx_data_reg/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.tx_data_reg'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.tx_data_reg/simple; source run.sh"

strategies/apb_uart.u_apb_regs.tx_data_reg/pdr/status: strategies/apb_uart.u_apb_regs.tx_data_reg/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.tx_data_reg'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.tx_data_reg/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.start_reg/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.start_reg'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.start_reg/simple; source run.sh"

strategies/apb_uart.u_apb_regs.start_reg/pdr/status: strategies/apb_uart.u_apb_regs.start_reg/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.start_reg'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.start_reg/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.soft_rst_reg/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.soft_rst_reg'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.soft_rst_reg/simple; source run.sh"

strategies/apb_uart.u_apb_regs.soft_rst_reg/pdr/status: strategies/apb_uart.u_apb_regs.soft_rst_reg/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.soft_rst_reg'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.soft_rst_reg/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.rx_done_prev/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.rx_done_prev'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.rx_done_prev/simple; source run.sh"

strategies/apb_uart.u_apb_regs.rx_done_prev/pdr/status: strategies/apb_uart.u_apb_regs.rx_done_prev/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.rx_done_prev'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.rx_done_prev/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.rx_done_flag/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.rx_done_flag'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.rx_done_flag/simple; source run.sh"

strategies/apb_uart.u_apb_regs.rx_done_flag/pdr/status: strategies/apb_uart.u_apb_regs.rx_done_flag/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.rx_done_flag'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.rx_done_flag/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.rx_data_reg/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.rx_data_reg'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.rx_data_reg/simple; source run.sh"

strategies/apb_uart.u_apb_regs.rx_data_reg/pdr/status: strategies/apb_uart.u_apb_regs.rx_data_reg/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.rx_data_reg'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.rx_data_reg/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.parity_err_flag/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.parity_err_flag'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.parity_err_flag/simple; source run.sh"

strategies/apb_uart.u_apb_regs.parity_err_flag/pdr/status: strategies/apb_uart.u_apb_regs.parity_err_flag/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.parity_err_flag'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.parity_err_flag/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.ier/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.ier'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.ier/simple; source run.sh"

strategies/apb_uart.u_apb_regs.ier/pdr/status: strategies/apb_uart.u_apb_regs.ier/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.ier'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.ier/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.frame_err_flag/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.frame_err_flag'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.frame_err_flag/simple; source run.sh"

strategies/apb_uart.u_apb_regs.frame_err_flag/pdr/status: strategies/apb_uart.u_apb_regs.frame_err_flag/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.frame_err_flag'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.frame_err_flag/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.cfg/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.cfg'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.cfg/simple; source run.sh"

strategies/apb_uart.u_apb_regs.cfg/pdr/status: strategies/apb_uart.u_apb_regs.cfg/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.cfg'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.cfg/pdr; source run.sh"; \
	fi

strategies/apb_uart.u_apb_regs.baud/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.u_apb_regs.baud'.."
	@bash -c "cd strategies/apb_uart.u_apb_regs.baud/simple; source run.sh"

strategies/apb_uart.u_apb_regs.baud/pdr/status: strategies/apb_uart.u_apb_regs.baud/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.u_apb_regs.baud'.."; \
		bash -c "cd strategies/apb_uart.u_apb_regs.baud/pdr; source run.sh"; \
	fi

strategies/apb_uart.irq/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.irq'.."
	@bash -c "cd strategies/apb_uart.irq/simple; source run.sh"

strategies/apb_uart.irq/pdr/status: strategies/apb_uart.irq/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.irq'.."; \
		bash -c "cd strategies/apb_uart.irq/pdr; source run.sh"; \
	fi

strategies/apb_uart.rts_n/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.rts_n'.."
	@bash -c "cd strategies/apb_uart.rts_n/simple; source run.sh"

strategies/apb_uart.rts_n/pdr/status: strategies/apb_uart.rts_n/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.rts_n'.."; \
		bash -c "cd strategies/apb_uart.rts_n/pdr; source run.sh"; \
	fi

strategies/apb_uart.tx/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.tx'.."
	@bash -c "cd strategies/apb_uart.tx/simple; source run.sh"

strategies/apb_uart.tx/pdr/status: strategies/apb_uart.tx/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.tx'.."; \
		bash -c "cd strategies/apb_uart.tx/pdr; source run.sh"; \
	fi

strategies/apb_uart.prdata/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.prdata'.."
	@bash -c "cd strategies/apb_uart.prdata/simple; source run.sh"

strategies/apb_uart.prdata/pdr/status: strategies/apb_uart.prdata/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.prdata'.."; \
		bash -c "cd strategies/apb_uart.prdata/pdr; source run.sh"; \
	fi

strategies/apb_uart.pslverr/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.pslverr'.."
	@bash -c "cd strategies/apb_uart.pslverr/simple; source run.sh"

strategies/apb_uart.pslverr/pdr/status: strategies/apb_uart.pslverr/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.pslverr'.."; \
		bash -c "cd strategies/apb_uart.pslverr/pdr; source run.sh"; \
	fi

strategies/apb_uart.pready/simple/status:
	@echo "Running strategy 'simple' on 'apb_uart.pready'.."
	@bash -c "cd strategies/apb_uart.pready/simple; source run.sh"

strategies/apb_uart.pready/pdr/status: strategies/apb_uart.pready/simple/status
	@if grep PASS $^ >/dev/null ; then \
		echo "PASS (cached)" > $@; \
	elif grep FAIL $^ >/dev/null ; then \
		echo "FAIL (cached)" > $@; \
	else \
		echo "Running strategy 'pdr' on 'apb_uart.pready'.."; \
		bash -c "cd strategies/apb_uart.pready/pdr; source run.sh"; \
	fi

.PHONY: all summary
all: strategies/apb_uart.irq/pdr/status strategies/apb_uart.prdata/pdr/status strategies/apb_uart.pready/pdr/status strategies/apb_uart.pslverr/pdr/status strategies/apb_uart.rts_n/pdr/status strategies/apb_uart.tx/pdr/status strategies/apb_uart.u_apb_regs.baud/pdr/status strategies/apb_uart.u_apb_regs.cfg/pdr/status strategies/apb_uart.u_apb_regs.frame_err_flag/pdr/status strategies/apb_uart.u_apb_regs.ier/pdr/status strategies/apb_uart.u_apb_regs.parity_err_flag/pdr/status strategies/apb_uart.u_apb_regs.rx_data_reg/pdr/status strategies/apb_uart.u_apb_regs.rx_done_flag/pdr/status strategies/apb_uart.u_apb_regs.rx_done_prev/pdr/status strategies/apb_uart.u_apb_regs.soft_rst_reg/pdr/status strategies/apb_uart.u_apb_regs.start_reg/pdr/status strategies/apb_uart.u_apb_regs.tx_data_reg/pdr/status strategies/apb_uart.u_rx_uart.bit_cnt_inst.bit_cnt/pdr/status strategies/apb_uart.u_rx_uart.deframe_inst.parity_bit/pdr/status strategies/apb_uart.u_rx_uart.deframe_inst.parity_exp/pdr/status strategies/apb_uart.u_rx_uart.deframe_inst.rx_data/pdr/status strategies/apb_uart.u_rx_uart.frame_err/pdr/status strategies/apb_uart.u_rx_uart.overrun/pdr/status strategies/apb_uart.u_rx_uart.parity_err/pdr/status strategies/apb_uart.u_rx_uart.reset_release_pending/pdr/status strategies/apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/pdr/status strategies/apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/pdr/status strategies/apb_uart.u_rx_uart.rx_data/pdr/status strategies/apb_uart.u_rx_uart.rx_done/pdr/status strategies/apb_uart.u_rx_uart.rx_sync1/pdr/status strategies/apb_uart.u_rx_uart.rx_sync2/pdr/status strategies/apb_uart.u_rx_uart.sipo_inst.data_out/pdr/status strategies/apb_uart.u_rx_uart.tick_cnt_inst.tick_cnt/pdr/status strategies/apb_uart.u_rx_uart.u_rx_baud_gen.acc/pdr/status strategies/apb_uart.u_rx_uart.u_rx_baud_gen.cnt/pdr/status strategies/apb_uart.u_tx_uart.cts_n_sync1/pdr/status strategies/apb_uart.u_tx_uart.cts_n_sync2/pdr/status strategies/apb_uart.u_tx_uart.parity_latched/pdr/status strategies/apb_uart.u_tx_uart.tick_cnt_ins.cnt/pdr/status strategies/apb_uart.u_tx_uart.tx_done/pdr/status strategies/apb_uart.u_tx_uart.u_baud_gen.acc/pdr/status strategies/apb_uart.u_tx_uart.u_baud_gen.cnt/pdr/status strategies/apb_uart.u_tx_uart.u_bit_cnt.cnt/pdr/status strategies/apb_uart.u_tx_uart.u_piso.data/pdr/status strategies/apb_uart.u_tx_uart.u_stop_cnt.cnt/pdr/status
	$(MAKE) -f strategies.mk summary
summary:
	@rc=0 ; \
	while read f; do \
		p=$${f#strategies/} ; p=$${p%/*/status} ; \
		if grep -q "PASS" $$f ; then \
			echo "* Successfully proved equivalence of partition $$p" ; \
		else \
			echo "* Failed to prove equivalence of partition $$p" ; rc=1 ; \
		fi ; \
	done < summary_targets.list ; \
	if [ "$$rc" -eq 0 ] ; then \
		echo "* Successfully proved designs equivalent" ; \
	fi
