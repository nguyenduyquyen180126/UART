# ==============================================================================
# Makefile for Verilog & ModelSim / QuestaSim / Icarus Verilog Simulation
# ==============================================================================

VSIM     ?= vsim
VLOG     ?= vlog
VLIB     ?= vlib
IVERILOG ?= iverilog
VVP      ?= vvp

.PHONY: all help compile check sim sim_cli clean \
        tx_uart tx_uart_cli tx_baud_gen tx_baud_gen_cli \
        uart_regs uart_regs_cli avalon2apb avalon2apb_cli \
        iv_uart_regs iv_avalon2apb test test_all test_apb test_fw test_fd test_rx \
        rx_uart tb_rx_uart wave_rx_uart \
        apb_uart tb_apb_uart wave_apb_uart apb_uart_vsim apb_uart_vsim_cli \
        firmware firmware_scenario tb_firmware_scenario wave_firmware firmware_vsim firmware_vsim_cli \
        full_duplex tb_full_duplex wave_full_duplex full_duplex_vsim full_duplex_vsim_cli

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

# Tu dong tao thu vien work neu chua co
work:
ifeq ($(OS),Windows_NT)
	@if not exist work $(VLIB) work
else
	@if [ ! -d work ]; then $(VLIB) work; fi
endif

compile check: work
	@echo "==> Đang biên dịch: $(TARGET_SRC)"
	$(VLOG) $(TARGET_SRC)

# ------------------------------------------------------------------------------
# 2. CHẠY MÔ PHỎNG TỔNG QUÁT (SIMULATION CHO BẤT KỲ MODULE NÀO QUA MODELSIM)
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
# 3. CÁC TARGET MÔ PHỎNG MODELSIM CỤ THỂ
# ------------------------------------------------------------------------------
# UART TX Module
tx_uart:
	$(VSIM) -do sim/tx_uart.tcl

tx_uart_cli:
	$(VSIM) -c -do "do sim/tx_uart.tcl; quit -f"

# TX Baud Generator
tx_baud_gen:
	$(VSIM) -do sim/tx_baud_gen.tcl

tx_baud_gen_cli:
	$(VSIM) -c -do "do sim/tx_baud_gen.tcl; quit -f"

# APB Slave & UART Registers (Zero-Wait-State & Protection Check)
uart_regs: work
	$(VLOG) rtl/apb_slave.v rtl/uart_regs.v tb/tb_uart_regs.v
	$(VSIM) -do "vsim -voptargs=+acc work.tb_uart_regs; add wave -r /*; run -all"

uart_regs_cli: work
	$(VLOG) rtl/apb_slave.v rtl/uart_regs.v tb/tb_uart_regs.v
	$(VSIM) -c -do "run -all; quit -f" work.tb_uart_regs

# Avalon-MM to APB Bridge
avalon2apb: work
	$(VLOG) avalon2apb.v rtl/apb_slave.v rtl/uart_regs.v tb/tb_avalon2apb.v
	$(VSIM) -do "vsim -voptargs=+acc work.tb_avalon2apb; add wave -r /*; run -all"

avalon2apb_cli: work
	$(VLOG) avalon2apb.v rtl/apb_slave.v rtl/uart_regs.v tb/tb_avalon2apb.v
	$(VSIM) -c -do "run -all; quit -f" work.tb_avalon2apb

# ------------------------------------------------------------------------------
# 3.1. CHẠY MÔ PHỎNG APB_UART (HỖ TRỢ CẢ IVERILOG & MODELSIM/QUESTASIM)
# ------------------------------------------------------------------------------
APB_UART_SRCS := rtl/apb_uart.v \
                 rtl/apb_slave.v \
                 rtl/uart_regs.v \
                 rtl/rx_baud_gen.v \
                 rtl/tx_uart.v \
                 rtl/tx_controller.v \
                 rtl/tx_baud_gen.v \
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
                 rtl/error_check.v \
                 rtl/sync_fifo.v

# 1) tb_apb_uart: Testbench tong hop tinh nang APB UART
apb_uart tb_apb_uart:
	@echo "==> Đang biên dịch và chạy mô phỏng tb_apb_uart bằng Icarus Verilog..."
	iverilog -g2012 -o sim_apb_uart.vvp $(APB_UART_SRCS) tb/tb_apb_uart.v
	vvp sim_apb_uart.vvp

wave_apb_uart: apb_uart
	gtkwave wave_apb_uart.vcd &

apb_uart_vsim: work
	$(VLOG) -sv $(APB_UART_SRCS) tb/tb_apb_uart.v
	$(VSIM) -do "vsim -voptargs=+acc work.tb_apb_uart; add wave -r /*; run -all"

apb_uart_vsim_cli: work
	$(VLOG) -sv $(APB_UART_SRCS) tb/tb_apb_uart.v
	$(VSIM) -c -do "run -all; quit -f" work.tb_apb_uart

# 2) tb_firmware_scenario: Kịch bản mô phỏng tương thích Firmware C & CPU Nios V
firmware firmware_scenario tb_firmware_scenario:
	@echo "==> Đang biên dịch và chạy mô phỏng tb_firmware_scenario bằng Icarus Verilog..."
	iverilog -g2012 -o sim_firmware.vvp $(APB_UART_SRCS) tb/tb_firmware_scenario.v
	vvp sim_firmware.vvp

wave_firmware: firmware_scenario
	gtkwave wave_firmware_scenario.vcd &

firmware_vsim: work
	$(VLOG) -sv $(APB_UART_SRCS) tb/tb_firmware_scenario.v
	$(VSIM) -do "vsim -voptargs=+acc work.tb_firmware_scenario; add wave -r /*; run -all"

firmware_vsim_cli: work
	$(VLOG) -sv $(APB_UART_SRCS) tb/tb_firmware_scenario.v
	$(VSIM) -c -do "run -all; quit -f" work.tb_firmware_scenario

# 3) tb_full_duplex: Kịch bản kiểm chứng truyền và nhận đồng thời Full-Duplex (2 dây)
full_duplex tb_full_duplex:
	@echo "==> Đang biên dịch và chạy mô phỏng tb_full_duplex bằng Icarus Verilog..."
	iverilog -g2012 -o sim_full_duplex.vvp $(APB_UART_SRCS) tb/tb_full_duplex.v
	vvp sim_full_duplex.vvp

wave_full_duplex: full_duplex
	gtkwave wave_full_duplex.vcd &

full_duplex_vsim: work
	$(VLOG) -sv $(APB_UART_SRCS) tb/tb_full_duplex.v
	$(VSIM) -do "vsim -voptargs=+acc work.tb_full_duplex; add wave -r /*; run -all"

full_duplex_vsim_cli: work
	$(VLOG) -sv $(APB_UART_SRCS) tb/tb_full_duplex.v
	$(VSIM) -c -do "run -all; quit -f" work.tb_full_duplex

# 4) tb_rx_uart: Kịch bản kiểm thử chi tiết bộ thu RX UART
RX_UART_SRCS  := rtl/rx_uart.v \
                 rtl/rx_controller.v \
                 rtl/rx_baud_gen.v \
                 rtl/data_b_num.v \
                 rtl/stop_b_num.v \
                 rtl/bit_cnt.v \
                 rtl/tick_cnt.v \
                 rtl/sipo.v \
                 rtl/deframe.v \
                 rtl/error_check.v

rx_uart tb_rx_uart test_rx:
	@echo "==> Đang biên dịch và chạy mô phỏng tb_rx_uart bằng Icarus Verilog..."
	iverilog -g2012 -o sim_rx_uart.vvp $(RX_UART_SRCS) tb/tb_rx_uart.v
	vvp sim_rx_uart.vvp

wave_rx_uart: rx_uart
	gtkwave wave.vcd &

# ------------------------------------------------------------------------------
# 4. CÁC LỆNH GÕ TẮT TIỆN LỢI (CONVENIENT ALIASES)
# ------------------------------------------------------------------------------
test_apb: apb_uart
test_fw:  firmware
test_fd:  full_duplex

# Chạy toàn bộ test suite hoàn chỉnh của IP Core APB UART
test test_all:
	@echo "=========================================================================="
	@echo ">>> 1/4: Chay kiem chung Song Cong (Full-Duplex):"
	@echo "=========================================================================="
	$(MAKE) test_fd
	@echo "\n=========================================================================="
	@echo ">>> 2/4: Chay kiem chung Firmware Scenario C (Nios V CPU):"
	@echo "=========================================================================="
	$(MAKE) test_fw
	@echo "\n=========================================================================="
	@echo ">>> 3/4: Chay kiem chung Unit Test Bo Thu RX UART:"
	@echo "=========================================================================="
	$(MAKE) test_rx
	@echo "\n=========================================================================="
	@echo ">>> 4/4: Chay kiem chung Toan Dien APB UART (FIFO, IRQ, Overrun):"
	@echo "=========================================================================="
	$(MAKE) test_apb
	@echo "\n>>> HOAN TAT TAT CA CAC TEST SUITE TREN MAKEFILE! <<<"

# ------------------------------------------------------------------------------
# 5. GÕ TẮT THEO TÊN MODULE (VÍ DỤ: make rx_uart)
# ------------------------------------------------------------------------------
%:
	@if [ "$@" != "clean" ] && [ "$@" != "help" ] && [ "$@" != "work" ] && [ "$@" != "test" ]; then \
		if [ -f "tb/tb_$@.v" ] || [ -f "sim/$@.tcl" ]; then \
			$(MAKE) sim TOP=$@; \
		elif [ -f "rtl/$@.v" ]; then \
			$(MAKE) compile FILE=$@; \
		elif [ -f "tb/$@.v" ]; then \
			$(MAKE) compile FILE=$@; \
		else \
			echo "Target '$@' khong hop le. Go 'make help' hoac 'make' de xem menu."; \
		fi \
	fi

# ------------------------------------------------------------------------------
# 6. DỌN DẸP DỮ LIỆU TẠM
# ------------------------------------------------------------------------------
clean:
	@echo "Dang don dep cac file rac mo phong..."
ifeq ($(OS),Windows_NT)
	-@cmd /c "del /f /q transcript vsim.wlf wlft* *.vvp *.vcd 2>nul & (if exist work rmdir /s /q work) & exit 0"
else
	@rm -rf work transcript vsim.wlf wlft* *.vvp *.vcd
endif

# ------------------------------------------------------------------------------
# 7. MENU HƯỚNG DẪN (CHEAT SHEET)
# ------------------------------------------------------------------------------
help:
	@echo "=========================================================================="
	@echo "                       HUONG DAN BIEN DICH & MO PHONG                    "
	@echo "=========================================================================="
	@echo "1. CHAY TESTBENCH TONG THE BANG ICARUS VERILOG (IVERILOG - KHUYEN DUNG):"
	@echo "   make test (hoac make test_all) : Chay TOAN BO test suite (4 kich ban)"
	@echo "   make full_duplex (make test_fd): Chay tb_full_duplex (truyen/nhan 2 day)"
	@echo "   make firmware    (make test_fw): Chay tb_firmware_scenario (Nios V CPU)"
	@echo "   make rx_uart     (make test_rx): Chay tb_rx_uart (unit test bo thu RX)"
	@echo "   make apb_uart    (make test_apb): Chay tb_apb_uart (tong hop FIFO & IRQ)"
	@echo ""
	@echo "   make wave_apb_uart             : Mo GTKWave xem dang song tb_apb_uart"
	@echo "   make wave_firmware             : Mo GTKWave xem dang song firmware"
	@echo "   make wave_full_duplex          : Mo GTKWave xem dang song full_duplex"
	@echo "   make wave_rx_uart              : Mo GTKWave xem dang song tb_rx_uart"
	@echo ""
	@echo "2. BIEN DICH / KIEM TRA LOI CU PHAP (MODELSIM):"
	@echo "   make check                 : Bien dich tat ca file trong thu muc rtl/"
	@echo "   make check FILE=rx_uart    : Bien dich kiem tra file rtl/rx_uart.v"
	@echo "   make check FILE=tb_rx_uart : Bien dich kiem tra testbench tb/tb_rx_uart.v"
	@echo ""
	@echo "3. CHAY MO PHONG MODELSIM (GUI SONG / DONG LENH CLI):"
	@echo "   make apb_uart_vsim         : Mo GUI ModelSim mo phong tb_apb_uart"
	@echo "   make firmware_vsim         : Mo GUI ModelSim mo phong tb_firmware_scenario"
	@echo "   make full_duplex_vsim      : Mo GUI ModelSim mo phong tb_full_duplex"
	@echo "   make uart_regs             : Mo GUI ModelSim mo phong APB Slave & UART Regs"
	@echo "   make avalon2apb            : Mo GUI ModelSim mo phong Bridge Avalon to APB"
	@echo ""
	@echo "4. DON DEP:"
	@echo "   make clean                 : Xoa thu vien work/, *.vvp, *.vcd, transcript"
	@echo "=========================================================================="
