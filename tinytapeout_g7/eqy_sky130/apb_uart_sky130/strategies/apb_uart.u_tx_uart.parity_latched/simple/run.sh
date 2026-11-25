yosys -ql run.log run.ys
if grep "SAT temporal induction proof finished - model found for base case: FAIL!" run.log > /dev/null ; then
	echo FAIL > status
	echo "Could not prove equivalence of partition 'apb_uart.u_tx_uart.parity_latched' using strategy 'simple': partitions not equivalent"
elif grep "Reached maximum number of time steps -> proof failed." run.log > /dev/null ; then
	echo UNKNOWN > status
	echo "Could not prove equivalence of partition 'apb_uart.u_tx_uart.parity_latched' using strategy 'simple': equivalence unknown"
elif grep "Interrupted SAT solver: TIMEOUT!" run.log > /dev/null ; then
	echo UNKNOWN > status
	echo "Could not prove equivalence of partition 'apb_uart.u_tx_uart.parity_latched' using strategy 'simple': timeout"
elif grep "Induction step proven: SUCCESS!" run.log > /dev/null ; then
	echo PASS > status
	echo "Proved equivalence of partition 'apb_uart.u_tx_uart.parity_latched' using strategy 'simple'"
else
	echo ERROR > status
	echo "Execution of strategy 'simple' on partition 'apb_uart.u_tx_uart.parity_latched' encountered an error.
Details can be found in 'apb_uart_sky130/strategies/apb_uart.u_tx_uart.parity_latched/simple/run.log'."
	exit 1
fi
exit 0

