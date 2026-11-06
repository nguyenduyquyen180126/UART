#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/scripts/toolchain_env.sh"
SOF_FILE="${1:-$UART_ROOT/build/images/shell.sof}"
[[ -f "$SOF_FILE" ]] || { echo "Missing $SOF_FILE; run ./scripts/build_soc.sh" >&2; exit 1; }
if [[ "$SOF_FILE" == "$UART_ROOT/build/images/"* ]]; then
    python3 "$UART_ROOT/scripts/source_manifest.py" > "$UART_ROOT/build/current.sha256"
    cmp -s "$UART_ROOT/build/current.sha256" "$UART_ROOT/build/images/sources.sha256" || {
        echo 'Sources changed since build. Run ./scripts/build_soc.sh before programming.' >&2; exit 1;
    }
fi
CABLE="${CABLE:-$(jtagconfig 2>/dev/null | sed -n 's/^[0-9][0-9]*)[[:space:]]*\(.*USB-Blaster.*\)$/\1/p' | head -n1 || true)}"
[[ -n "$CABLE" ]] || { echo 'USB-Blaster not detected. Connect and power the DE2-115.' >&2; exit 1; }
quartus_pgm -m jtag -c "$CABLE" -o "p;$SOF_FILE"
