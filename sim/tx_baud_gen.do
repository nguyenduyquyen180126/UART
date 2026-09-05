# ==============================================================================
# ModelSim Wave Window Configuration File
# ==============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

# Testbench top-level signals
add wave -divider "Testbench Signals"
add wave -noupdate -format Logic -radix binary /tb_tx_baud_gen/clk
add wave -noupdate -format Logic -radix binary /tb_tx_baud_gen/rst_n
add wave -noupdate -format Literal -radix binary /tb_tx_baud_gen/baud_rate
add wave -noupdate -format Logic -radix binary /tb_tx_baud_gen/baud_en