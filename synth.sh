#!/usr/bin/env bash
set -e

# Tim duong dan thu vien Sky130 PDK (ho tro ca duong dan dai va duong dan tieu chuan trong iic-osic-tools)
if [ -z "$LIB_TT" ]; then
    if [ -f "/foss/pdks/ciel/sky130/versions/1689ac3f2dc763876eaf967227c7dfe831b031ae/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib" ]; then
        LIB_TT="/foss/pdks/ciel/sky130/versions/1689ac3f2dc763876eaf967227c7dfe831b031ae/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
    elif [ -f "/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib" ]; then
        LIB_TT="/foss/pdks/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
    elif [ -n "$PDK_ROOT" ] && [ -f "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib" ]; then
        LIB_TT="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
    fi
fi

TOP_MODULE=${TOP_MODULE:-top_uart}
NETLIST_OUT=${NETLIST_OUT:-netlist_synth.v}

echo "=== TONG HOP YOSYS CHO MODULE: $TOP_MODULE ==="
echo "Thu vien su dung: $LIB_TT"

yosys -p "
  read_verilog rtl/*.v;
  synth -top $TOP_MODULE -flatten;
  dfflibmap -liberty $LIB_TT;
  abc -liberty $LIB_TT -dont_use *lpflow*;
  hilomap -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO;
  insbuf -buf sky130_fd_sc_hd__buf_1 A X;
  stat -liberty $LIB_TT;
  write_verilog -noattr $NETLIST_OUT
" | tee yosys_synth.log

echo "Tong hop thanh cong! Netlist ghi vao: $NETLIST_OUT"
