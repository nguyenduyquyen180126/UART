STATUS=ERROR
sby -f apb_uart.u_apb_regs.baud.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_apb_regs.baud/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_apb_regs.baud' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.baud' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.baud' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.baud' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_apb_regs.baud/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_apb_regs.baud' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_pdr/strategies/apb_uart.u_apb_regs.baud/pdr/apb_uart.u_apb_regs.baud/logfile.txt'."
        exit 1
    ;;
esac
exit 0

