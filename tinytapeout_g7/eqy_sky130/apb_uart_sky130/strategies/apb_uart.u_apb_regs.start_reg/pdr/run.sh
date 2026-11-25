STATUS=ERROR
sby -f apb_uart.u_apb_regs.start_reg.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_apb_regs.start_reg/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_apb_regs.start_reg' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.start_reg' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.start_reg' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.start_reg' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_apb_regs.start_reg/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_apb_regs.start_reg' encountered an error."
        echo "More details can be found in 'apb_uart_sky130/strategies/apb_uart.u_apb_regs.start_reg/pdr/apb_uart.u_apb_regs.start_reg/logfile.txt'."
        exit 1
    ;;
esac
exit 0

