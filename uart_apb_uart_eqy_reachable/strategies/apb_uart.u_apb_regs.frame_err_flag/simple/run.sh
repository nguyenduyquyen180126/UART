yosys -ql run.log run.ys
if grep "SAT temporal induction proof finished - model found for base case: FAIL!" run.log > /dev/null ; then
	echo FAIL > status
	echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.frame_err_flag' using strategy 'simple': partitions not equivalent"
elif grep "Reached maximum number of time steps -> proof failed." run.log > /dev/null ; then
	echo UNKNOWN > status
	echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.frame_err_flag' using strategy 'simple': equivalence unknown"
elif grep "Interrupted SAT solver: TIMEOUT!" run.log > /dev/null ; then
	echo UNKNOWN > status
	echo "Could not prove equivalence of partition 'apb_uart.u_apb_regs.frame_err_flag' using strategy 'simple': timeout"
elif grep "Induction step proven: SUCCESS!" run.log > /dev/null ; then
	echo PASS > status
	echo "Proved equivalence of partition 'apb_uart.u_apb_regs.frame_err_flag' using strategy 'simple'"
else
	echo ERROR > status
	echo "Execution of strategy 'simple' on partition 'apb_uart.u_apb_regs.frame_err_flag' encountered an error.
Details can be found in 'uart_apb_uart_eqy_reachable/strategies/apb_uart.u_apb_regs.frame_err_flag/simple/run.log'."
	exit 1
fi
exit 0

