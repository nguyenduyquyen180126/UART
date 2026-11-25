STATUS=ERROR
sby -f apb_uart.u_rx_uart.rx_done.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_rx_uart.rx_done/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_rx_uart.rx_done' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_done' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_done' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_done' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_rx_uart.rx_done/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_rx_uart.rx_done' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_pdr/strategies/apb_uart.u_rx_uart.rx_done/pdr/apb_uart.u_rx_uart.rx_done/logfile.txt'."
        exit 1
    ;;
esac
exit 0

