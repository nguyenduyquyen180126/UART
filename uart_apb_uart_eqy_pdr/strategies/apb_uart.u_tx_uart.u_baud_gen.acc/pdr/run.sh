STATUS=ERROR
sby -f apb_uart.u_tx_uart.u_baud_gen.acc.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_tx_uart.u_baud_gen.acc/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_tx_uart.u_baud_gen.acc' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_tx_uart.u_baud_gen.acc' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_tx_uart.u_baud_gen.acc' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_tx_uart.u_baud_gen.acc' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_tx_uart.u_baud_gen.acc/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_tx_uart.u_baud_gen.acc' encountered an error."
        echo "More details can be found in 'uart_apb_uart_eqy_pdr/strategies/apb_uart.u_tx_uart.u_baud_gen.acc/pdr/apb_uart.u_tx_uart.u_baud_gen.acc/logfile.txt'."
        exit 1
    ;;
esac
exit 0

