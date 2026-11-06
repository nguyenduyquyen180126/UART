#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/scripts/build_soc.sh"
"$ROOT/flash_fpga.sh"
exec "$ROOT/run_terminal_jtag.sh"
