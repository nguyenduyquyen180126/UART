#!/usr/bin/env bash
# Terminal 1: normal messaging/configuration shell; existing entry points remain valid.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# -le 1 && ( $# -eq 0 || "$1" == --build ) ]] || { echo "Usage: $0 [--build]" >&2; exit 1; }
if [[ "${1:-}" == --build || ! -f "$ROOT/build/images/shell.sof" ]]; then
    "$ROOT/scripts/build_soc.sh"
fi
"$ROOT/scripts/flash_fpga.sh" "$ROOT/build/images/shell.sof"
exec "$ROOT/scripts/run_terminal_jtag.sh"
