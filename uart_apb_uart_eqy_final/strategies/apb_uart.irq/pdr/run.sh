STATUS=ERROR
sby -f apb_uart.irq.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.irq/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.irq' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.irq' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.irq' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.irq' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.irq/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.irq' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_final/strategies/apb_uart.irq/pdr/apb_uart.irq/logfile.txt'."
        exit 1
    ;;
esac
exit 0

