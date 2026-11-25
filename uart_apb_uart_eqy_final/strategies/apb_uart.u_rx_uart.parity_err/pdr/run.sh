STATUS=ERROR
sby -f apb_uart.u_rx_uart.parity_err.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_rx_uart.parity_err/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_rx_uart.parity_err' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.parity_err' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.parity_err' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_rx_uart.parity_err' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_rx_uart.parity_err/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_rx_uart.parity_err' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_final/strategies/apb_uart.u_rx_uart.parity_err/pdr/apb_uart.u_rx_uart.parity_err/logfile.txt'."
        exit 1
    ;;
esac
exit 0

