#!/usr/bin/env bash
set -e

export TOP_MODULE=${TOP_MODULE:-top_uart}
export NETLIST_FILE=${NETLIST_FILE:-netlist_synth.v}

# Tu dong tim thu vien PDK neu chua dat bien LIB_DIR
if [ -z "$LIB_DIR" ]; then
    if [ -d "/foss/pdks/ciel/sky130/versions/1689ac3f2dc763876eaf967227c7dfe831b031ae/sky130A/libs.ref/sky130_fd_sc_hd/lib" ]; then
        LIB_DIR="/foss/pdks/ciel/sky130/versions/1689ac3f2dc763876eaf967227c7dfe831b031ae/sky130A/libs.ref/sky130_fd_sc_hd/lib"
    elif [ -d "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib" ]; then
        LIB_DIR="/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib"
    elif [ -n "$PDK_ROOT" ] && [ -d "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib" ]; then
        LIB_DIR="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib"
    fi
fi

echo "=== PHAN TICH STA CHO MODULE: $TOP_MODULE ==="
echo "Netlist: $NETLIST_FILE"
echo "LIB_DIR: $LIB_DIR"

# 1. Chay goc cham (ss) de kiem tra Setup o 40 ns (25 MHz)
echo "--> 1. Chay goc cham (Slow-Slow, 100C, 1.60V)"
export LIB_FILE="$LIB_DIR/sky130_fd_sc_hd__ss_100C_1v60.lib"
sta -no_init -no_splash -exit sta.tcl | tee sta_ss.log


# 2. Góc điển hình (Typical)
echo "--> 1. Chay goc dien hinh (Typical-Typical, 25C, 1.80V)"
export LIB_FILE="$LIB_DIR/sky130_fd_sc_hd__tt_025C_1v80.lib"
sta -no_init -no_splash -exit sta.tcl | tee sta_tt.log


# 2. Chay goc nhanh (ff) de kiem tra Hold (-40C, 1.95V)
echo "--> 2. Chay goc nhanh (Fast-Fast, -40C, 1.95V)"
export LIB_FILE="$LIB_DIR/sky130_fd_sc_hd__ff_n40C_1v95.lib"
sta -no_init -no_splash -exit sta.tcl | tee sta_ff.log

echo "=== HOAN TAT STA! Kiem tra ket qua tai sta_ss.log, sta_tt.log va sta_ff.log ==="
