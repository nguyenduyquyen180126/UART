STATUS=ERROR
sby -f apb_uart.u_rx_uart.rx_sync2.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_rx_uart.rx_sync2/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_rx_uart.rx_sync2' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_sync2' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_sync2' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.rx_sync2' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_rx_uart.rx_sync2/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_rx_uart.rx_sync2' encountered an error."
        echo "More details can be found in 'apb_uart_sky130/strategies/apb_uart.u_rx_uart.rx_sync2/pdr/apb_uart.u_rx_uart.rx_sync2/logfile.txt'."
        exit 1
    ;;
esac
exit 0

