STATUS=ERROR
sby -f apb_uart.u_rx_uart.rx_controller_inst.state.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_rx_uart.rx_controller_inst.state/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.state' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.state' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.state' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.state' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_rx_uart.rx_controller_inst.state/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_rx_uart.rx_controller_inst.state' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_pdr/strategies/apb_uart.u_rx_uart.rx_controller_inst.state/pdr/apb_uart.u_rx_uart.rx_controller_inst.state/logfile.txt'."
        exit 1
    ;;
esac
exit 0

