# ==============================================================================
# ModelSim TCL Script for Running Simulation
# ==============================================================================

# 1. Create work library if it doesn't exist
if {![file exists work]} {
    vlib work
}

# 2. Compile RTL and Testbench source files
# Note: Add/remove source files here as your project grows.
vlog rtl/*.v
vlog tb/tb_tx_uart.v

# 3. Start the simulation
vsim work.tb_tx_uart

# 4. Open waveform window and load signals if in GUI mode
view wave
do sim/tx_uart.do

# 5. Run simulation
# Simulation will run until $stop is encountered in testbench or user stops it
run -all

# 6. Zoom full in wave window (GUI mode only)
wave zoom full
