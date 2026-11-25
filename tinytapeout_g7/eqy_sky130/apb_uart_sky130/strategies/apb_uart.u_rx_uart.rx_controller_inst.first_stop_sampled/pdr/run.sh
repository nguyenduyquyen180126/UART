STATUS=ERROR
sby -f apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled' encountered an error."
        echo "More details can be found in 'apb_uart_sky130/strategies/apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/pdr/apb_uart.u_rx_uart.rx_controller_inst.first_stop_sampled/logfile.txt'."
        exit 1
    ;;
esac
exit 0

