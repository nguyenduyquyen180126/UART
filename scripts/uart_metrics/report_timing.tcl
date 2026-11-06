# usage: quartus_sta -t report_timing.tcl project [hierarchy pattern]
set proj [lindex $argv 0]
set pattern [lindex $argv 1]
project_open $proj
create_timing_netlist -model slow
read_sdc
update_timing_netlist
if {$pattern eq ""} {set pattern *}
set regs [get_registers $pattern]
puts "CORE_REGISTER_COLLECTION=[get_collection_size $regs]"
if {[get_collection_size $regs] == 0} {error "No core registers"}
foreach corner [get_available_operating_conditions] {
    set_operating_conditions $corner
    update_timing_netlist
    set safe [string map {" " _} $corner]
    report_timing -from $regs -to $regs -setup -npaths 10 -detail full_path -file "core_setup_${safe}.rpt"
    report_timing -from $regs -to $regs -hold -npaths 10 -detail full_path -file "core_hold_${safe}.rpt"
    report_timing -from $regs -to $regs -recovery -npaths 10 -file "core_recovery_${safe}.rpt"
    report_timing -from $regs -to $regs -removal -npaths 10 -file "core_removal_${safe}.rpt"
    set paths [get_timing_paths -from $regs -to $regs -setup -npaths 1]
    foreach_in_collection path $paths {
        set slack [get_path_info -slack $path]
        puts "CORE_SETUP_CORNER=$corner SLACK_NS=$slack PERIOD_NS=20.000 IMPLIED_REG_REG_FMAX_MHZ=[expr {1000.0/(20.0-$slack)}]"
    }
}
report_ucp -file core_unconstrained.rpt
project_close
