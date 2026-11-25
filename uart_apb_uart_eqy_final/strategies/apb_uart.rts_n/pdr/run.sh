STATUS=ERROR
sby -f apb_uart.rts_n.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.rts_n/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.rts_n' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.rts_n' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.rts_n' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.rts_n' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.rts_n/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.rts_n' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_final/strategies/apb_uart.rts_n/pdr/apb_uart.rts_n/logfile.txt'."
        exit 1
    ;;
esac
exit 0

