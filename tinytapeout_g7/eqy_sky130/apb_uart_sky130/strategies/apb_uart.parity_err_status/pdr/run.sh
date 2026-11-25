STATUS=ERROR
sby -f apb_uart.parity_err_status.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.parity_err_status/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.parity_err_status' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.parity_err_status' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.parity_err_status' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.parity_err_status' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.parity_err_status/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.parity_err_status' encountered an error."
        echo "More details can be found in 'apb_uart_sky130/strategies/apb_uart.parity_err_status/pdr/apb_uart.parity_err_status/logfile.txt'."
        exit 1
    ;;
esac
exit 0

