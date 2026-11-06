#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ "${1:-}" == --build || ! -f "$ROOT/build/images/demo.sof" ]]; then
    "$ROOT/scripts/build_soc.sh"
fi
"$ROOT/flash_fpga.sh" "$ROOT/build/images/demo.sof"
printf 'Demo loaded: watch HEX3:HEX2. Open Terminal 2: ./run_terminal_pc.sh /dev/ttyUSB0\n'
exec "$ROOT/run_terminal_jtag.sh"
