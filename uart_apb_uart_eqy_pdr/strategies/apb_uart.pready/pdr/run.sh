STATUS=ERROR
sby -f apb_uart.pready.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.pready/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.pready' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.pready' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.pready' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.pready' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.pready/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.pready' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_pdr/strategies/apb_uart.pready/pdr/apb_uart.pready/logfile.txt'."
        exit 1
    ;;
esac
exit 0

