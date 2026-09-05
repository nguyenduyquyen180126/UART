# ==============================================================================
# Makefile for Verilog & ModelSim Simulation
# ==============================================================================


# Default target
.PHONY: all sim sim_cli clean help

all: 

# Show help menu
help:
	@echo Verilog ModelSim Makefile Template
	@echo ==================================
	@echo make sim      - Run simulation in GUI mode (opens ModelSim)
	@echo make sim_cli  - Run simulation in command-line/batch mode
	@echo make clean    - Remove generated simulation files and folders
	@echo make help     - Show this help message

# Run simulation in GUI mode
tx_baud_gen:
	vsim -do sim/tx_baud_gen.tcl

# Run simulation in CLI/Batch mode (useful for CI/CD or fast tests)
tx_baud_gen_cli:
	vsim -c -do "do sim/tx_baud_gen.tcl; quit -f"

# Clean up compilation database and temporary simulator outputs
clean:
	@echo Cleaning simulation artifacts...
	@if exist transcript del /Q transcript
	@if exist vsim.wlf del /Q vsim.wlf
	@if exist work rmdir /S /Q work
	@if exist wlft* del /Q wlft*
	@rm -rf work transcript vsim.wlf wlft*
