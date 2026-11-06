create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_clock_uncertainty
# Asynchronous board inputs terminate at their first synchronizer stages.
set_false_path -from [get_ports {KEY[*] SW[*] UART_RXD}]
# Human-visible outputs / asynchronous UART have no external synchronous clock.
set_false_path -to [get_ports {LEDG[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] UART_TXD}]
