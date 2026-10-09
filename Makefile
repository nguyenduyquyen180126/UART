# ==============================================================================
# Makefile for Verilog & ModelSim / QuestaSim Simulation
# ==============================================================================

VSIM ?= vsim
VLOG ?= vlog
VLIB ?= vlib

.PHONY: all help compile check sim sim_cli clean tx_uart tx_uart_cli tx_baud_gen tx_baud_gen_cli

# Mặc định khi chỉ gõ 'make' sẽ hiển thị menu hướng dẫn
all: help

# ------------------------------------------------------------------------------
# 1. BIÊN DỊCH / KIỂM TRA CÚ PHÁP (COMPILE / CHECK)
# Cách dùng:
#   make check                     -> Biên dịch tất cả file rtl/*.v
#   make check FILE=rx_uart        -> Tự động tìm và biên dịch rtl/rx_uart.v
#   make check FILE=rtl/rx_uart.v  -> Biên dịch chính xác file chỉ định
#   make compile                   -> Tương tự make check
# ------------------------------------------------------------------------------
ifdef FILE
    BASE_NAME  := $(basename $(notdir $(FILE)))
    TARGET_SRC := $(firstword $(wildcard rtl/$(BASE_NAME).v tb/$(BASE_NAME).v $(FILE)))
    ifeq ($(TARGET_SRC),)
        TARGET_SRC := $(FILE)
    endif
else
    TARGET_SRC := rtl/*.v
endif

# Tự động tạo thư viện work nếu chưa có
work:
	@if [ ! -d work ]; then $(VLIB) work; fi

compile check: work
	@echo "==> Đang biên dịch: $(TARGET_SRC)"
	$(VLOG) $(TARGET_SRC)

# ------------------------------------------------------------------------------
# 2. CHẠY MÔ PHỎNG TỔNG QUÁT (SIMULATION CHO BẤT KỲ MODULE NÀO)
# Cách dùng:
#   make sim TOP=rx_uart           -> Mở GUI ModelSim, add wave và run -all
#   make sim_cli TOP=rx_uart       -> Chạy dòng lệnh (CLI/Batch), in kết quả ra terminal
# ------------------------------------------------------------------------------
sim: work
ifndef TOP
	@echo "Lỗi: Vui lòng chỉ định TOP=<tên_module>. Ví dụ: make sim TOP=rx_uart"
else
	@if [ -f "sim/$(TOP).tcl" ]; then \
		$(VSIM) -do "sim/$(TOP).tcl"; \
	elif [ -f "tb/tb_$(TOP).v" ]; then \
		$(VLOG) rtl/*.v tb/tb_$(TOP).v && $(VSIM) -do "vsim -voptargs=+acc work.tb_$(TOP); add wave -r /*; run -all"; \
	else \
		echo "Không tìm thấy testbench: tb/tb_$(TOP).v hoặc kịch bản: sim/$(TOP).tcl"; \
	fi
endif

sim_cli: work
ifndef TOP
	@echo "Lỗi: Vui lòng chỉ định TOP=<tên_module>. Ví dụ: make sim_cli TOP=rx_uart"
else
	@if [ -f "sim/$(TOP).tcl" ]; then \
		$(VSIM) -c -do "do sim/$(TOP).tcl; quit -f"; \
	elif [ -f "tb/tb_$(TOP).v" ]; then \
		$(VLOG) rtl/*.v tb/tb_$(TOP).v && $(VSIM) -c -do "run -all; quit -f" work.tb_$(TOP); \
	else \
		echo "Không tìm thấy testbench: tb/tb_$(TOP).v hoặc kịch bản: sim/$(TOP).tcl"; \
	fi
endif

# ------------------------------------------------------------------------------
# 3. CÁC TARGET CÓ SẴN (BACKWARD COMPATIBILITY)
# ------------------------------------------------------------------------------
tx_uart:
	$(VSIM) -do sim/tx_uart.tcl

tx_uart_cli:
	$(VSIM) -c -do "do sim/tx_uart.tcl; quit -f"

tx_baud_gen:
	$(VSIM) -do sim/tx_baud_gen.tcl

tx_baud_gen_cli:
	$(VSIM) -c -do "do sim/tx_baud_gen.tcl; quit -f"

# ------------------------------------------------------------------------------
# 3.1. CHẠY MÔ PHỎNG APB_UART (HỖ TRỢ CẢ IVERILOG & MODELSIM/QUESTASIM)
# ------------------------------------------------------------------------------
APB_UART_SRCS := rtl/apb_uart.v \
                 rtl/apb_slave.v \
                 rtl/reg_uart.v \
                 rtl/baud_gen.v \
                 rtl/tx_uart.v \
                 rtl/tx_controller.v \
                 rtl/tx_tick_cnt.v \
                 rtl/tx_bit_cnt.v \
                 rtl/tx_stop_cnt.v \
                 rtl/tx_parity.v \
                 rtl/tx_piso.v \
                 rtl/rx_uart.v \
                 rtl/rx_controller.v \
                 rtl/data_b_num.v \
                 rtl/stop_b_num.v \
                 rtl/bit_cnt.v \
                 rtl/tick_cnt.v \
                 rtl/sipo.v \
                 rtl/deframe.v \
                 rtl/error_check.v

# Chạy mô phỏng apb_uart bằng iverilog (mặc định nhanh, không cần license)
apb_uart:
	@echo "==> Đang biên dịch và chạy mô phỏng tb_apb_uart bằng Icarus Verilog..."
	iverilog -g2012 -o sim_apb_uart.vvp $(APB_UART_SRCS) tb/tb_apb_uart.v
	vvp sim_apb_uart.vvp

# Mở dạng sóng GTKWave cho apb_uart
wave_apb_uart: apb_uart
	gtkwave wave_apb_uart.vcd &

# Chạy bằng QuestaSim/ModelSim (khi có license)
apb_uart_vsim: work
	$(VLOG) -sv $(APB_UART_SRCS) tb/tb_apb_uart.v
	$(VSIM) -do "vsim -voptargs=+acc work.tb_apb_uart; add wave -r /*; run -all"

apb_uart_vsim_cli: work
	$(VLOG) -sv $(APB_UART_SRCS) tb/tb_apb_uart.v
	$(VSIM) -c -do "run -all; quit -f" work.tb_apb_uart

# ------------------------------------------------------------------------------
# 4. GÕ TẮT THEO TÊN MODULE (VÍ DỤ: make rx_uart)
# ------------------------------------------------------------------------------
%:
	@if [ "$@" != "clean" ] && [ "$@" != "help" ] && [ "$@" != "work" ]; then \
		if [ -f "tb/tb_$@.v" ] || [ -f "sim/$@.tcl" ]; then \
			$(MAKE) sim TOP=$@; \
		elif [ -f "rtl/$@.v" ]; then \
			$(MAKE) compile FILE=$@; \
		elif [ -f "tb/$@.v" ]; then \
			$(MAKE) compile FILE=$@; \
		else \
			echo "Target '$@' không hợp lệ. Gõ 'make help' hoặc 'make' để xem menu."; \
		fi \
	fi

# ------------------------------------------------------------------------------
# 5. DỌN DẸP DỮ LIỆU TẠM
# ------------------------------------------------------------------------------
clean:
	@echo "Đang dọn dẹp các file rác mô phỏng..."
	@rm -rf work transcript vsim.wlf wlft*

# ------------------------------------------------------------------------------
# 6. MENU HƯỚNG DẪN (CHEAT SHEET)
# ------------------------------------------------------------------------------
help:
	@echo "=========================================================================="
	@echo "                       HƯỚNG DẪN BIÊN DỊCH & MÔ PHỎNG                    "
	@echo "=========================================================================="
	@echo "1. BIÊN DỊCH / KIỂM TRA LỖI CÚ PHÁP (COMPILE / SYNTAX CHECK):"
	@echo "   make check                 : Biên dịch tất cả file trong thư mục rtl/"
	@echo "   make check FILE=rx_uart    : Biên dịch kiểm tra file rtl/rx_uart.v"
	@echo "   make check FILE=tb_rx_uart : Biên dịch kiểm tra testbench tb/tb_rx_uart.v"
	@echo "   make tb_rx_uart            : Gõ tắt để compile nhanh file testbench!"
	@echo ""
	@echo "2. CHẠY MÔ PHỎNG TỔNG QUÁT (TỰ ĐỘNG CHO MỌI MODULE NẾU CÓ TB):"
	@echo "   make sim TOP=rx_uart       : Mở GUI ModelSim, tự load sóng Waveform"
	@echo "   make sim_cli TOP=rx_uart   : Chạy mô phỏng dòng lệnh CLI (không mở GUI)"
	@echo ""
	@echo "3. CÁC MODULE ĐÃ CÓ SẴN KỊCH BẢN SIMULATION:"
	@echo "   make tx_uart               : Chạy GUI mô phỏng TX UART"
	@echo "   make tx_uart_cli           : Chạy CLI mô phỏng TX UART"
	@echo "   make tx_baud_gen           : Chạy GUI mô phỏng TX Baud Generator"
	@echo "   make tx_baud_gen_cli       : Chạy CLI mô phỏng TX Baud Generator"
	@echo ""
	@echo "4. DỌN DẸP:"
	@echo "   make clean                 : Xóa thư viện work/ và file tạm transcript"
	@echo "=========================================================================="
