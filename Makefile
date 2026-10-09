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
        iv_uart_regs iv_avalon2apb test

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
	$(VLOG) rtl/apb_slave.v rtl/reg_uart.v tb/tb_uart_regs.v
	$(VSIM) -do "vsim -voptargs=+acc work.tb_uart_regs; add wave -r /*; run -all"

uart_regs_cli: work
	$(VLOG) rtl/apb_slave.v rtl/reg_uart.v tb/tb_uart_regs.v
	$(VSIM) -c -do "run -all; quit -f" work.tb_uart_regs

# Avalon-MM to APB Bridge
avalon2apb: work
	$(VLOG) avalon2apb.v rtl/apb_slave.v rtl/reg_uart.v tb/tb_avalon2apb.v
	$(VSIM) -do "vsim -voptargs=+acc work.tb_avalon2apb; add wave -r /*; run -all"

avalon2apb_cli: work
	$(VLOG) avalon2apb.v rtl/apb_slave.v rtl/reg_uart.v tb/tb_avalon2apb.v
	$(VSIM) -c -do "run -all; quit -f" work.tb_avalon2apb

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
# 4. MÔ PHỎNG NHANH BẰNG ICARUS VERILOG (IVERILOG / VVP)
# ------------------------------------------------------------------------------
test_regs.vvp: rtl/apb_slave.v rtl/reg_uart.v tb/tb_uart_regs.v
	$(IVERILOG) -o $@ $^

iv_uart_regs: test_regs.vvp
	@echo "==> Mo phong tb_uart_regs bang Icarus Verilog..."
	$(VVP) $<

sim_avl.vvp: avalon2apb.v rtl/apb_slave.v rtl/reg_uart.v tb/tb_avalon2apb.v
	$(IVERILOG) -o $@ $^

iv_avalon2apb: sim_avl.vvp
	@echo "==> Mo phong tb_avalon2apb bang Icarus Verilog..."
	$(VVP) $<

# Chạy toàn bộ test suite bằng iverilog
test: iv_uart_regs iv_avalon2apb

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
	@echo "1. BIEN DICH / KIEM TRA LOI CU PHAP (MODELSIM):"
	@echo "   make check                 : Bien dich tat ca file trong thu muc rtl/"
	@echo "   make check FILE=rx_uart    : Bien dich kiem tra file rtl/rx_uart.v"
	@echo "   make check FILE=tb_rx_uart : Bien dich kiem tra testbench tb/tb_rx_uart.v"
	@echo ""
	@echo "2. CHAY MO PHONG MODELSIM (GUI SONG / DONG LENH CLI):"
	@echo "   make uart_regs             : Mo GUI ModelSim mo phong APB Slave & UART Regs"
	@echo "   make uart_regs_cli         : Chay CLI terminal mo phong APB Slave & UART Regs"
	@echo "   make avalon2apb            : Mo GUI ModelSim mo phong Bridge Avalon to APB"
	@echo "   make avalon2apb_cli        : Chay CLI terminal mo phong Bridge Avalon to APB"
	@echo "   make tx_uart               : Chay GUI mo phong TX UART"
	@echo "   make tx_uart_cli           : Chay CLI mo phong TX UART"
	@echo "   make tx_baud_gen           : Chay GUI mo phong TX Baud Generator"
	@echo "   make tx_baud_gen_cli       : Chay CLI mo phong TX Baud Generator"
	@echo ""
	@echo "3. CHAY MO PHONG NHANH BANG ICARUS VERILOG (IVERILOG):"
	@echo "   make test                  : Chay toan bo test suites (uart_regs + avalon2apb)"
	@echo "   make iv_uart_regs          : Chay rieng testbench tb_uart_regs bang iverilog"
	@echo "   make iv_avalon2apb         : Chay rieng testbench tb_avalon2apb bang iverilog"
	@echo ""
	@echo "4. DON DEP:"
	@echo "   make clean                 : Xoa thu vien work/, *.vvp, transcript, vsim.wlf"
	@echo "=========================================================================="
