#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LIBRELANE_PYTHON=${LIBRELANE_PYTHON:-$(command -v python3 || command -v python)}
TT_TOOL_PYTHON=${TT_TOOL_PYTHON:-$LIBRELANE_PYTHON}
if [[ -n "${TT_TOOLS_BIN_DIR:-}" ]]; then
    # Append the TT support-tools venv after Nix so `python -m librelane`
    # resolves to the LibreLane environment, while yowasp-yosys is still found.
    export PATH="$PATH:$TT_TOOLS_BIN_DIR"
fi
if [[ -z "$LIBRELANE_PYTHON" ]] || ! "$LIBRELANE_PYTHON" -c 'import librelane' >/dev/null 2>&1; then
    echo "LibreLane Python module is not available in this shell." >&2
    echo "Enter the supported LibreLane Nix shell (or Docker environment) first." >&2
    exit 2
fi
if [[ ! -n "${PDK_ROOT:-}" ]]; then
    echo "PDK_ROOT is unset. Set it to the full Sky130A physical PDK root." >&2
    exit 2
fi
if [[ ! -f "$PDK_ROOT/sky130A/SOURCES" && ! -d "$PDK_ROOT/ciel/sky130/versions" ]]; then
    echo "PDK_ROOT does not look like an Open PDK root or Ciel cache root: $PDK_ROOT" >&2
    echo "For Ciel, use its root directory (normally ~/.ciel), not a version directory." >&2
    exit 2
fi
cd "$ROOT"
if [[ -d "$ROOT/runs" ]] && find "$ROOT/runs" -mindepth 1 -print -quit | grep -q .; then
    echo "Refusing to harden: $ROOT/runs is non-empty." >&2
    echo "Archive or rename the existing run first; Tiny Tapeout hardening may replace runs/wokwi." >&2
    exit 2
fi
"$TT_TOOL_PYTHON" ./tt/tt_tool.py --project-dir "$ROOT" --pdk sky130A --create-user-config
"$TT_TOOL_PYTHON" ./tt/tt_tool.py --project-dir "$ROOT" --pdk sky130A --harden --no-docker
