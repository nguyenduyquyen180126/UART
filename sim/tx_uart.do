# ==============================================================================
# ModelSim Wave Window Configuration File
# ==============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

# Testbench top-level signals
add wave -divider "TB Top-Level Signals"
add wave -noupdate -format Logic -radix binary /tb_tx_uart/clk
add wave -noupdate -format Logic -radix binary /tb_tx_uart/rst_n
add wave -noupdate -format Logic -radix binary /tb_tx_uart/send
add wave -noupdate -format Logic -radix binary /tb_tx_uart/active
add wave -noupdate -format Literal -radix binary /tb_tx_uart/baud_rate
add wave -noupdate -format Literal -radix hexadecimal /tb_tx_uart/data_in
add wave -noupdate -format Literal -radix binary /tb_tx_uart/parity_type
add wave -noupdate -format Logic -radix binary /tb_tx_uart/data_tx
add wave -divider "Baud counter"
add wave -noupdate -format Logic -radix binary /tb_tx_uart/dut/baud_tick