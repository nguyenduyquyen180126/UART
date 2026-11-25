STATUS=ERROR
sby -f apb_uart.pslverr.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.pslverr/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.pslverr' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.pslverr' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.pslverr' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.pslverr' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.pslverr/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.pslverr' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_pdr/strategies/apb_uart.pslverr/pdr/apb_uart.pslverr/logfile.txt'."
        exit 1
    ;;
esac
exit 0

