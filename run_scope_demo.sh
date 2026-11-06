#!/usr/bin/env bash
# Terminal 1: load dedicated oscilloscope firmware, then open JTAG diagnostics.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
[[ $# -le 1 && ( $# -eq 0 || "$1" == --build ) ]] || { echo "Usage: $0 [--build]" >&2; exit 1; }
if [[ "${1:-}" == --build || ! -f "$ROOT/build/images/scope.sof" ]]; then
    "$ROOT/scripts/build_soc.sh"
fi
"$ROOT/flash_fpga.sh" "$ROOT/build/images/scope.sof"
printf '%s\n' 'Scope demo: TX PIN_AC15 / GPIO[1], GND to board GND.' \
 '9600 8N1, fixed A, 5 ms idle after each frame. Trigger falling edge, about 1.5 V; start at 200 us/div.' \
 'Waveform starts automatically; JTAG terminal is diagnostic only. Ctrl+C closes the terminal, not the transmitter.'
exec "$ROOT/run_terminal_jtag.sh"
