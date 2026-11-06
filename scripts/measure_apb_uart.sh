#!/usr/bin/env bash
# Standalone UART characterization; never programs the kit or modifies SoC RTL.
set -euo pipefail
source "$(dirname "$0")/toolchain_env.sh"
METRICS_DIR="$UART_ROOT/build/uart_metrics"
mkdir -p "$METRICS_DIR"
cd "$METRICS_DIR"
sha256sum "$UART_ROOT"/rtl/*.v > rtl-before.sha256
quartus_sh -t "$UART_ROOT/scripts/uart_metrics/create_project.tcl" "$UART_ROOT" > create.log 2>&1
quartus_sh --flow compile uart_metrics > compile.log 2>&1
quartus_sta -t "$UART_ROOT/scripts/uart_metrics/report_timing.tcl" uart_metrics > core_timing.log 2>&1
iverilog -g2012 -s tb_uart_power -o power_tb "$UART_ROOT/scripts/uart_metrics/tb_uart_power.v" "$UART_ROOT"/rtl/*.v
vvp power_tb +IDLE > idle_sim.log
vvp power_tb > active_sim.log
for scenario in idle active; do
 python3 "$UART_ROOT/scripts/uart_metrics/prepare_vcd.py" "${scenario}_raw.vcd" "$scenario.vcd"
 quartus_sh -t "$UART_ROOT/scripts/uart_metrics/set_power.tcl" "$scenario" 25 > "power-settings-$scenario.log" 2>&1
 quartus_pow uart_metrics > "power-$scenario.log" 2>&1
 cp output_files/uart_metrics.pow.rpt "power-$scenario-25c.rpt"
 cp output_files/uart_metrics.pow.summary "power-$scenario-25c.summary"
done
# Post-fit functional simulation gives the analyzer the fitted register names.
# No SDF annotation: this estimate does not claim timing-glitch accuracy.
quartus_eda uart_metrics --simulation --tool=modelsim --format=verilog --output_directory=gate_sim > eda.log 2>&1
iverilog -g2012 -s tb_uart_power -o gate_tb "$UART_ROOT/scripts/uart_metrics/tb_uart_power.v" gate_sim/uart_metrics.vo \
 "$QUARTUS_ROOTDIR/eda/sim_lib/cycloneive_atoms.v" "$QUARTUS_ROOTDIR/eda/sim_lib/altera_primitives.v" > gate_compile.log 2>&1
mkdir -p gate_vcd
(cd gate_vcd; vvp ../gate_tb +IDLE > ../gate_idle_sim.log; vvp ../gate_tb > ../gate_active_sim.log)
for scenario in idle active; do
 python3 "$UART_ROOT/scripts/uart_metrics/prepare_vcd.py" "gate_vcd/${scenario}_raw.vcd" "${scenario}_gate.vcd"
 quartus_sh -t "$UART_ROOT/scripts/uart_metrics/set_power.tcl" "${scenario}_gate" 25 > "power-settings-${scenario}_gate.log" 2>&1
 quartus_pow uart_metrics > "power-${scenario}_gate.log" 2>&1
 cp output_files/uart_metrics.pow.rpt "power-${scenario}_gate-25c.rpt"
 cp output_files/uart_metrics.pow.summary "power-${scenario}_gate-25c.summary"
done
if [[ -f "$UART_ROOT/fpga/db/NIOS.fit.qdb" || -f "$UART_ROOT/fpga/output_files/NIOS.fit.rpt" ]]; then
 (cd "$UART_ROOT/fpga"; quartus_sta -t "$UART_ROOT/scripts/uart_metrics/report_timing.tcl" NIOS '*|apb_uart:apb_uart_0|*' > "$METRICS_DIR/soc_core_timing.log" 2>&1)
fi
sha256sum -c rtl-before.sha256 > rtl-integrity.log
python3 "$UART_ROOT/scripts/uart_metrics/summarize.py"
echo "Results: $METRICS_DIR/results.json"
