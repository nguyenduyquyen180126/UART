STATUS=ERROR
sby -f apb_uart.u_apb_regs.cfg.sby > /dev/null && STATUS=$(awk '{print $1}' apb_uart.u_apb_regs.cfg/status)
echo $STATUS > status
case $STATUS in
    PASS)
        echo "Proved equivalence of partition 'apb_uart.u_apb_regs.cfg' using strategy 'pdr'"
    ;;
    FAIL)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.cfg' using strategy 'pdr': partitions not equivalent"
    ;;
    UNKNOWN)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.cfg' using strategy 'pdr': equivalence unknown"
    ;;
    TIMEOUT)
        echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.cfg' using strategy 'pdr': timeout"
    ;;
    *)
        cat apb_uart.u_apb_regs.cfg/ERROR 2> /dev/null
        echo "Execution of strategy 'pdr' on partition 'apb_uart.u_apb_regs.cfg' encountered an error."
        echo "More details can be found in 'apb_uart_sky130/strategies/apb_uart.u_apb_regs.cfg/pdr/apb_uart.u_apb_regs.cfg/logfile.txt'."
        exit 1
    ;;
esac
exit 0

