#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build_soc.sh"
"$ROOT/scripts/flash_fpga.sh"
exec "$ROOT/scripts/run_terminal_jtag.sh"
