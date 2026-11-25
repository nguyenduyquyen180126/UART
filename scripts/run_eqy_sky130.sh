#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EQY_SOURCE=${EQY_SOURCE:?Set EQY_SOURCE to a checkout of YosysHQ/eqy containing examples/spm}
SKY130_LIB=${SKY130_LIB:-/home/vietanh/.local/share/sky130/sky130_fd_sc_hd__tt_025C_1v80.lib}
YOSYS_BIN=${YOSYS_BIN:-yosys}
EQY_PY=${EQY_PY:-$EQY_SOURCE/src/eqy.py}
SBY_BIN=${SBY_BIN:-sby}
OUT_DIR=${OUT_DIR:-$ROOT/build/eqy_sky130}

for tool in "$YOSYS_BIN" python3 "$SBY_BIN"; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Required command not found: $tool" >&2
        exit 2
    }
done
SBY_PATH=$(dirname "$(command -v "$SBY_BIN")")
export PATH="$SBY_PATH:$PATH"
for file in "$EQY_SOURCE/examples/spm/formal_pdk_proc.py" \
            "$EQY_SOURCE/examples/spm/primitives.v" \
            "$EQY_SOURCE/examples/spm/sky130_fd_sc_hd.v" \
            "$SKY130_LIB" "$EQY_PY"; do
    test -f "$file" || { echo "Required file not found: $file" >&2; exit 2; }
done

mkdir -p "$OUT_DIR"
OUT_DIR=$(cd "$OUT_DIR" && pwd)
for path in "$ROOT" "$OUT_DIR" "$SKY130_LIB"; do
    case "$path" in
        *[[:space:]]*) echo "EQY flow paths must not contain whitespace: $path" >&2; exit 2 ;;
    esac
done

NETLIST=$OUT_DIR/apb_uart_sky130.v
CELL_MODELS=$OUT_DIR/sky130_fd_sc_hd_functional.v
MAP_SCRIPT=$OUT_DIR/map.ys
EQY_CONFIG=$OUT_DIR/apb_uart_sky130.eqy

cat > "$MAP_SCRIPT" <<EOF
read_verilog $ROOT/rtl/*.v
synth -top apb_uart -flatten
check -assert
dfflibmap -liberty $SKY130_LIB
abc -liberty $SKY130_LIB -dont_use *lpflow*
hilomap -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO
stat -liberty $SKY130_LIB
write_verilog -noattr $NETLIST
EOF

echo "[1/4] Mapping apb_uart into Sky130 HD cells"
"$YOSYS_BIN" -s "$MAP_SCRIPT" > "$OUT_DIR/map.log" 2>&1

echo "[2/4] Building formal-friendly Sky130 functional models"
python3 "$EQY_SOURCE/examples/spm/formal_pdk_proc.py" \
    "$EQY_SOURCE/examples/spm/primitives.v" \
    "$EQY_SOURCE/examples/spm/sky130_fd_sc_hd.v" \
    -o "$CELL_MODELS"

echo "[3/4] Checking mapped netlist structure with functional cell models"
"$YOSYS_BIN" -p "read_verilog -formal $CELL_MODELS $NETLIST; hierarchy -check -top apb_uart; proc; flatten; opt; check -assert" \
    > "$OUT_DIR/netlist_check.log" 2>&1

sed -e "s|@ROOT@|$ROOT|g" \
    -e "s|@NETLIST@|$NETLIST|g" \
    -e "s|@CELL_MODELS@|$CELL_MODELS|g" \
    "$ROOT/formal/apb_uart_sky130.eqy.in" > "$EQY_CONFIG"

echo "[4/4] Running EQY (SAT, then ABC PDR fallback)"
cd "$OUT_DIR"
python3 "$EQY_PY" -f apb_uart_sky130.eqy 2>&1 | tee eqy.log
