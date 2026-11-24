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

# 2. CDC inputs: waive setup/hold only to the first synchronizer stage.
# Resolve each stage's D pin from its named Q net so the constraints do not
# depend on Yosys-generated cell names such as _3854_.
proc sync_stage_d_pin {q_net_pattern q_net_regexp} {
    set q_nets [get_nets -hierarchical $q_net_pattern]
    set d_pins {}
    foreach q_net $q_nets {
        if {![regexp -- $q_net_regexp [get_property $q_net full_name]]} {
            continue
        }
        foreach q_pin [get_pins -of_objects $q_net] {
            if {[get_property $q_pin name] eq "Q" &&
                [get_property $q_pin direction] eq "output"} {
                set ff [get_cells -of_objects $q_pin]
                foreach ff_pin [get_pins -of_objects $ff] {
                    if {[get_property $ff_pin name] eq "D"} {
                        lappend d_pins $ff_pin
                    }
                }
            }
        }
    }
    if {[llength $d_pins] == 0} {
        error "No synchronizer D pin found for net pattern $q_net_pattern"
    }
    return $d_pins
}

# External SPI/UART signals have no fixed phase relationship to pclk. Keep
# input delay/driver models above for the timed spi_cs_n -> spi_miso output
# path, while cutting only the input-to-first-stage synchronizer paths.
set spi_sclk_stage1_d [sync_stage_d_pin {*clk_pipe*} {clk_pipe\[0\]$}]
set spi_mosi_stage1_d [sync_stage_d_pin {*mosi_pipe*} {mosi_pipe\[0\]$}]
set spi_cs_n_stage1_d [sync_stage_d_pin {*cs_n_pipe*} {cs_n_pipe\[0\]$}]
set rx_stage1_d [sync_stage_d_pin {*rx_sync1*} {rx_sync1$}]
set cts_n_stage1_d [sync_stage_d_pin {*cts_n_sync1*} {cts_n_sync1$}]
puts "CDC first-stage D pins:"
report_object_full_names [concat $spi_sclk_stage1_d $spi_mosi_stage1_d \
    $spi_cs_n_stage1_d $rx_stage1_d $cts_n_stage1_d]

set_false_path -from [get_ports spi_sclk] -to $spi_sclk_stage1_d
set_false_path -from [get_ports spi_mosi] -to $spi_mosi_stage1_d
set_false_path -from [get_ports spi_cs_n] -to $spi_cs_n_stage1_d
set_false_path -from [get_ports rx] -to $rx_stage1_d
set_false_path -from [get_ports cts_n] -to $cts_n_stage1_d
