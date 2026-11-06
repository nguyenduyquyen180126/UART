package require ::quartus::project
project_open uart_metrics
set scenario [lindex $argv 0]
set temperature [lindex $argv 1]
set_global_assignment -name POWER_USE_INPUT_FILES ON
set_global_assignment -name POWER_DEFAULT_INPUT_IO_TOGGLE_RATE "0 transitions/s"
set_global_assignment -name POWER_DEFAULT_TOGGLE_RATE "0 transitions/s"
# Keep one selected activity file per run.
foreach old {idle.vcd active.vcd idle_gate.vcd active_gate.vcd} {
    remove_all_global_assignments -name POWER_INPUT_FILE_NAME -section_id $old
    remove_all_global_assignments -name POWER_INPUT_FILE_TYPE -section_id $old
}
remove_all_instance_assignments -name POWER_READ_INPUT_FILE
set_global_assignment -name POWER_INPUT_FILE_NAME "$scenario.vcd" -section_id "$scenario.vcd"
set_global_assignment -name POWER_INPUT_FILE_TYPE VCD -section_id "$scenario.vcd"
set_instance_assignment -name POWER_READ_INPUT_FILE "$scenario.vcd" -to apb_uart
set_global_assignment -name POWER_AUTO_COMPUTE_TJ OFF
set_global_assignment -name POWER_TJ_VALUE $temperature
export_assignments
project_close
