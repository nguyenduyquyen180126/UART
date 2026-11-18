set clk_period 40.0
create_clock -name pclk -period $clk_period [get_ports pclk]

set_clock_uncertainty -setup 0.50 [all_clocks]
set_clock_uncertainty -hold  0.10 [all_clocks]

set t_ext [expr {0.2 * $clk_period}]
set in_ports  [get_ports {spi_cs_n spi_sclk spi_mosi cts_n rx}]
set out_ports [get_ports {spi_miso tx rts_n irq}]

set_input_delay  -max $t_ext -clock pclk $in_ports
set_input_delay  -min 0.0    -clock pclk $in_ports

set_output_delay -max $t_ext -clock pclk $out_ports
set_output_delay -min 0.0    -clock pclk $out_ports

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 -pin X $in_ports
set_load 0.01 [all_outputs]

# 1. Reset he thong bat dong bo
set_input_delay 0.0 -clock pclk [get_ports presetn]
set_false_path -from [get_ports presetn]

# 2. Cac tin hieu bat dong bo tu ben ngoai dua vao bo dong bo hoa (2-FF Synchronizer):
# spi_sclk, spi_mosi, rx, cts_n chi di vao tang 1 cua cac bo dong bo hoa
set_false_path -hold -from [get_ports {spi_sclk spi_mosi rx cts_n}]

# spi_cs_n vua di vao FF cs_n_pipe[0], vua co duong to hop ra spi_miso:
# Chi loai bo kiem tra timing toi cac thanh ghi noi bo (DFF), van giu kiem tra duong to hop ra spi_miso
set_false_path -hold -from [get_ports spi_cs_n] -to [all_registers]
