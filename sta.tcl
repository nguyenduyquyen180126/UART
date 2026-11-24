read_liberty $::env(LIB_FILE)
read_verilog $::env(NETLIST_FILE)
link_design  $::env(TOP_MODULE)

read_sdc constraints.sdc

check_setup -verbose

puts "=== BAO CAO SETUP (MAX DELAY) ==="
report_checks -path_delay max -group_path_count 5 -endpoint_path_count 1 \
    -format full_clock_expanded -fields {slew cap fanout} -digits 3

puts "=== BAO CAO HOLD (MIN DELAY) ==="
report_checks -path_delay min -group_path_count 5 -endpoint_path_count 1 \
    -format full_clock_expanded -fields {slew cap fanout} -digits 3

puts "=== WORST PATHS THANH GHI -> THANH GHI (SETUP) ==="
report_checks -path_delay max -from [all_registers -clock_pins] \
    -to [all_registers -data_pins] -group_path_count 5 -endpoint_path_count 1 \
    -format full_clock_expanded -fields {slew cap fanout} -digits 3

puts "=== WORST PATHS THANH GHI -> THANH GHI (HOLD) ==="
report_checks -path_delay min -from [all_registers -clock_pins] \
    -to [all_registers -data_pins] -group_path_count 5 -endpoint_path_count 1 \
    -format full_clock_expanded -fields {slew cap fanout} -digits 3

puts "=== TOM TAT CHI SO WNS / TNS / WORST SLACK ==="
report_wns -digits 3
report_tns -digits 3
report_worst_slack -max -digits 3
report_worst_slack -min -digits 3

puts "=== TOP 5 ENDPOINTS SLACK THAP NHAT CHO SETUP ==="
report_checks -path_delay max -group_path_count 5 -endpoint_path_count 1 -format end -digits 3

puts "=== TOP 5 ENDPOINTS SLACK THAP NHAT CHO HOLD ==="
report_checks -path_delay min -group_path_count 5 -endpoint_path_count 1 -format end -digits 3
