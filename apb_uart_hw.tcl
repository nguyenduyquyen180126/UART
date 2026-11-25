# TCL File for apb_uart IP Component in Platform Designer
package require -exact qsys 14.0

# 
# module apb_uart
# 
set_module_property DESCRIPTION "APB UART Peripheral Controller"
set_module_property NAME apb_uart
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property DISPLAY_NAME "apb_uart"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false
set_module_property REPORT_HIERARCHY false

# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL apb_uart
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file apb_uart.v VERILOG PATH rtl/apb_uart.v TOP_LEVEL_FILE
add_fileset_file apb_regs.v VERILOG PATH rtl/apb_regs.v
add_fileset_file tx_uart.v VERILOG PATH rtl/tx_uart.v
add_fileset_file tx_controller.v VERILOG PATH rtl/tx_controller.v
add_fileset_file tx_baud_gen.v VERILOG PATH rtl/tx_baud_gen.v
add_fileset_file tx_tick_cnt.v VERILOG PATH rtl/tx_tick_cnt.v
add_fileset_file tx_bit_cnt.v VERILOG PATH rtl/tx_bit_cnt.v
add_fileset_file rx_uart.v VERILOG PATH rtl/rx_uart.v
add_fileset_file rx_controller.v VERILOG PATH rtl/rx_controller.v
add_fileset_file rx_baud_gen.v VERILOG PATH rtl/rx_baud_gen.v
add_fileset_file bit_cnt.v VERILOG PATH rtl/bit_cnt.v
add_fileset_file tick_cnt.v VERILOG PATH rtl/tick_cnt.v

# 
# parameters
# 
add_parameter CLK_FREQ INTEGER 50000000
set_parameter_property CLK_FREQ DEFAULT_VALUE 50000000
set_parameter_property CLK_FREQ DISPLAY_NAME "Clock Frequency"
set_parameter_property CLK_FREQ TYPE INTEGER
set_parameter_property CLK_FREQ UNITS Hertz
set_parameter_property CLK_FREQ HDL_PARAMETER true

# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock ENABLED true
add_interface_port clock clk clk Input 1

# 
# connection point reset
# 
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
add_interface_port reset rst_n reset_n Input 1

# 
# connection point apb_slave
# 
add_interface apb_slave apb end
set_interface_property apb_slave associatedClock clock
set_interface_property apb_slave associatedReset reset
set_interface_property apb_slave ENABLED true

add_interface_port apb_slave paddr paddr Input 12
add_interface_port apb_slave psel psel Input 1
add_interface_port apb_slave penable penable Input 1
add_interface_port apb_slave pwrite pwrite Input 1
add_interface_port apb_slave pwdata pwdata Input 32
add_interface_port apb_slave prdata prdata Output 32
add_interface_port apb_slave pready pready Output 1
add_interface_port apb_slave pslverr pslverr Output 1

# 
# connection point conduit_uart
# 
add_interface conduit_uart conduit end
set_interface_property conduit_uart associatedClock clock
set_interface_property conduit_uart associatedReset ""
set_interface_property conduit_uart ENABLED true

add_interface_port conduit_uart tx uart_tx Output 1
add_interface_port conduit_uart rx uart_rx Input 1

# 
# connection point interrupt_sender
# 
add_interface interrupt_sender interrupt end
set_interface_property interrupt_sender associatedClock clock
set_interface_property interrupt_sender associatedReset reset
set_interface_property interrupt_sender ENABLED true
set_interface_property interrupt_sender associatedAddressablePoint apb_slave

add_interface_port interrupt_sender irq irq Output 1
