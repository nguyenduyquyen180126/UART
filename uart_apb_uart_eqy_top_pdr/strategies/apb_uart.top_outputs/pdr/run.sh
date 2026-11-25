STATUS=ERROR
sby -f apb_uart.top_outputs.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.top_outputs/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.top_outputs' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.top_outputs' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.top_outputs' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.top_outputs' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.top_outputs/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.top_outputs' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_top_pdr/strategies/apb_uart.top_outputs/pdr/apb_uart.top_outputs/logfile.txt'."
        exit 1
    ;;
esac
exit 0

