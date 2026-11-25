STATUS=ERROR
sby -f apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_pdr/strategies/apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/pdr/apb_uart.u_rx_uart.rx_controller_inst.frame_error_latched/logfile.txt'."
        exit 1
    ;;
esac
exit 0

