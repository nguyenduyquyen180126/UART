create_clock -name clk -period 20.000 [get_ports clk]
derive_clock_uncertainty
# Reproducible interface budget, not a board-level APB specification.
set_input_delay -clock clk -max 2.0 [get_ports {psel penable pwrite paddr[*] pwdata[*]}]
set_input_delay -clock clk -min 0.0 [get_ports {psel penable pwrite paddr[*] pwdata[*]}]
set_output_delay -clock clk -max 2.0 [get_ports {pready pslverr prdata[*] irq}]
set_output_delay -clock clk -min 0.0 [get_ports {pready pslverr prdata[*] irq}]
set_false_path -from [get_ports {rst_n rx}]
set_false_path -to [get_ports tx]
