#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/toolchain_env.sh"
CABLE="${CABLE:-$(jtagconfig 2>/dev/null | sed -n 's/^[0-9][0-9]*)[[:space:]]*\(.*USB-Blaster.*\)$/\1/p' | head -n1 || true)}"
[[ -n "$CABLE" ]] || { echo 'USB-Blaster not detected. Connect and power the DE2-115.' >&2; exit 1; }
exec juart-terminal -c "$CABLE"
