# quartus_sta -t ../scripts/report_irq_path.tcl (run in fpga/ after fitting)
project_open NIOS
create_timing_netlist
read_sdc
update_timing_netlist
set uart_regs [get_registers {*apb_uart_0*}]
set irq_regs [get_registers {*irq_inst*plat_irq*}]
puts "UART_REGISTER_COUNT=[get_collection_size $uart_regs]"
puts "CPU_PLATFORM_IRQ_REGISTER_COUNT=[get_collection_size $irq_regs]"
if {[get_collection_size $uart_regs] == 0 || [get_collection_size $irq_regs] == 0} {
    error "Missing fitted UART or CPU IRQ registers"
}
set paths [get_timing_paths -from $uart_regs -to $irq_regs -npaths 1]
if {[get_collection_size $paths] == 0} { error "No fitted UART-to-CPU IRQ timing path" }
report_timing -from $uart_regs -to $irq_regs -npaths 4 -detail full_path -file ../build/logs/fitted-irq-path.rpt
project_close
