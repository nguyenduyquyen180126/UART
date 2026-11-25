STATUS=ERROR
sby -f apb_uart.u_rx_uart.deframe_inst.rx_data.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_rx_uart.deframe_inst.rx_data/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_rx_uart.deframe_inst.rx_data' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.deframe_inst.rx_data' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.deframe_inst.rx_data' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.deframe_inst.rx_data' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_rx_uart.deframe_inst.rx_data/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_rx_uart.deframe_inst.rx_data' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_pdr/strategies/apb_uart.u_rx_uart.deframe_inst.rx_data/pdr/apb_uart.u_rx_uart.deframe_inst.rx_data/logfile.txt'."
        exit 1
    ;;
esac
exit 0

