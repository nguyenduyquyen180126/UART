package require -exact qsys 24.1
create_system probe_cpu
set_project_property DEVICE_FAMILY "Cyclone IV E"
set_project_property DEVICE EP4CE115F29C7
foreach kind {intel_niosv_c intel_niosv_m intel_niosv_g} {
    add_instance probe $kind
    puts "CPU=$kind INTERFACES=[get_instance_interfaces probe] PARAMETERS=[get_instance_parameters probe]"
    remove_instance probe
}
