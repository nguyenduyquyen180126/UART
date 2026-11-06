package require ::quartus::project
set root [file normalize [lindex $argv 0]]
project_new uart_metrics -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE115F29C7
set_global_assignment -name TOP_LEVEL_ENTITY apb_uart
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name SEED 1
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name NOMINAL_CORE_SUPPLY_VOLTAGE 1.2V
foreach f [lsort [glob "$root/rtl/*.v"]] {
    set_global_assignment -name VERILOG_FILE $f
}
set_global_assignment -name SDC_FILE "$root/scripts/uart_metrics/uart_metrics.sdc"
# APB is an internal SoC bus: do not allocate fictitious package pins/pad loads.
foreach port {rst_n psel penable pwrite paddr[*] pwdata[*] pready pslverr prdata[*] tx rx irq} {
    set_instance_assignment -name VIRTUAL_PIN ON -to $port
}
set_location_assignment PIN_Y2 -to clk
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
# Fixed junction temperature, no inference about the physical board/heatsink.
set_global_assignment -name POWER_USE_DEVICE_CHARACTERISTICS TYPICAL
set_global_assignment -name POWER_AUTO_COMPUTE_TJ OFF
set_global_assignment -name POWER_TJ_VALUE 25
set_global_assignment -name POWER_VCD_FILTER_GLITCHES ON
set_global_assignment -name POWER_DEFAULT_INPUT_IO_TOGGLE_RATE "0 transitions/s"
set_global_assignment -name POWER_DEFAULT_TOGGLE_RATE "0 transitions/s"
export_assignments
project_close
