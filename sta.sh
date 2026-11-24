#!/usr/bin/env bash
set -euo pipefail

export TOP_MODULE=${TOP_MODULE:-top_uart}
export NETLIST_FILE=${NETLIST_FILE:-netlist_synth.v}

# Tu dong tim thu vien PDK neu chua dat bien LIB_DIR
if [ -z "${LIB_DIR:-}" ]; then
    if [ -d "/foss/pdks/ciel/sky130/versions/1689ac3f2dc763876eaf967227c7dfe831b031ae/sky130A/libs.ref/sky130_fd_sc_hd/lib" ]; then
        LIB_DIR="/foss/pdks/ciel/sky130/versions/1689ac3f2dc763876eaf967227c7dfe831b031ae/sky130A/libs.ref/sky130_fd_sc_hd/lib"
    elif [ -d "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib" ]; then
        LIB_DIR="/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib"
    elif [ -n "${PDK_ROOT:-}" ] && [ -d "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib" ]; then
        LIB_DIR="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib"
    elif [ -d "$HOME/.local/share/sky130" ]; then
        LIB_DIR="$HOME/.local/share/sky130"
    fi
fi

if ! command -v sta >/dev/null 2>&1; then
    echo "Loi: khong tim thay OpenSTA (sta) trong PATH. Hay activate env uart-sta hoac them thu muc chua sta vao PATH." >&2
    exit 127
fi
# The standalone Linux package ships its own Tcl library. Point Tcl at the
# matching init files so an active conda environment cannot supply another
# Tcl patch level.
sta_real_path="$(readlink -f "$(command -v sta)")"
bundled_tcl_dir="$(dirname "$sta_real_path")/../lib/tcl8.6"
if [ -f "$bundled_tcl_dir/init.tcl" ]; then
    export TCL_LIBRARY="$bundled_tcl_dir"
fi
if [ -z "${LIB_DIR:-}" ] || [ ! -d "$LIB_DIR" ]; then
    echo "Loi: khong tim thay thu vien Sky130. Dat LIB_DIR=/duong/dan/sky130_fd_sc_hd/lib." >&2
    exit 2
fi

echo "=== PHAN TICH STA CHO MODULE: $TOP_MODULE ==="
echo "Netlist: $NETLIST_FILE"
echo "LIB_DIR: $LIB_DIR"

# Run every available process corner. A typical-only Liberty is useful for
# learning and relative timing, but it is not a setup/hold signoff corner set.
ran=0
for corner in ss tt ff; do
    case "$corner" in
        ss) lib_name="sky130_fd_sc_hd__ss_100C_1v60.lib"; corner_desc="Slow-Slow, 100C, 1.60V" ;;
        tt) lib_name="sky130_fd_sc_hd__tt_025C_1v80.lib"; corner_desc="Typical-Typical, 25C, 1.80V" ;;
        ff) lib_name="sky130_fd_sc_hd__ff_n40C_1v95.lib"; corner_desc="Fast-Fast, -40C, 1.95V" ;;
    esac
    lib_path="$LIB_DIR/$lib_name"
    if [ ! -f "$lib_path" ]; then
        echo "WARNING: Bo qua corner $corner_desc; khong tim thay $lib_path"
        continue
    fi
    echo "--> Chay corner $corner_desc"
    export LIB_FILE="$lib_path"
    log_file="sta_${corner}.log"
    sta -no_init -no_splash -exit sta.tcl | tee "$log_file"
    if ! grep -q 'Startpoint:' "$log_file"; then
        echo "Loi: OpenSTA khong tao timing path report trong $log_file." >&2
        exit 1
    fi
    ran=$((ran + 1))
done

if [ "$ran" -eq 0 ]; then
    echo "Loi: khong co Liberty corner nao de chay." >&2
    exit 2
fi
echo "=== HOAN TAT STA. Kiem tra cac file sta_{ss,tt,ff}.log da duoc tao. ==="
