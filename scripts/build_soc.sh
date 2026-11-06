#!/usr/bin/env bash
# Build three bootable images from current RTL, without needing a board.
set -euo pipefail
source "$(dirname "$0")/toolchain_env.sh"
cd "$UART_ROOT"
trap 'echo "Build stopped; inspect $UART_ROOT/build/logs (no programming attempted)." >&2' ERR
mkdir -p build/logs build/images
qsys-generate fpga/system.qsys --synthesis=VERILOG --search-path='../**/*,$' > build/logs/qsys.log 2>&1
niosv-bsp -c --type=hal --sopcinfo=fpga/system.sopcinfo --cpu-instance=intel_niosv_m_0 software/bsp/settings.bsp > build/logs/bsp.log 2>&1
# GCC >=12 requires CSR instructions to be explicitly enabled. This changes
# assembler ISA spelling only; it does not add multiplication/atomic hardware.
python3 - <<'PY'
from pathlib import Path
p=Path('software/bsp/toolchain.cmake')
p.write_text(p.read_text().replace('-march=rv32i ', '-march=rv32i_zicsr '))
PY
for app in shell demo scope; do
    src="$UART_ROOT/software/main.c"
    [[ "$app" == demo ]] && src="$UART_ROOT/software/irq_demo.c"
    [[ "$app" == scope ]] && src="$UART_ROOT/software/scope_demo.c"
    cmake -S software -B "software/build-$app" -DAPP_SOURCE="$src" -DCMAKE_BUILD_TYPE=Release > "build/logs/cmake-$app.log" 2>&1
    cmake --build "software/build-$app" -j4 > "build/logs/firmware-$app.log" 2>&1
    cp "software/build-$app/app.elf" "build/images/$app.elf"
done
cp software/build-shell/onchip_memory2_0.hex fpga/system_onchip_memory2_0.hex
(
    cd fpga
    rm -f output_files/NIOS.sof
    quartus_sh --flow compile NIOS > ../build/logs/quartus.log 2>&1
)
(cd fpga && quartus_sta -t ../scripts/report_irq_path.tcl > ../build/logs/irq-path.log 2>&1)
# Refuse to label a time-limited evaluation image as a normal programming file.
if [[ ! -f fpga/output_files/NIOS.sof ]]; then
    echo 'No normal NIOS.sof produced. Inspect build/logs/quartus.log for IP licensing errors/evaluation restrictions.' >&2
    exit 1
fi
cp fpga/output_files/NIOS.sof build/images/shell.sof
# Only firmware MIF changes between demo modes; the fitted SoC is shared.
for app in demo scope; do
    cp "software/build-$app/onchip_memory2_0.hex" fpga/system_onchip_memory2_0.hex
    (
        cd fpga
        quartus_cdb NIOS --update_mif > "../build/logs/update-$app.log" 2>&1
        quartus_asm NIOS > "../build/logs/asm-$app.log" 2>&1
    )
    cp fpga/output_files/NIOS.sof "build/images/$app.sof"
done
# Leave the Quartus project in shell mode as well.
cp software/build-shell/onchip_memory2_0.hex fpga/system_onchip_memory2_0.hex
(
    cd fpga
    quartus_cdb NIOS --update_mif > ../build/logs/update-shell.log 2>&1
    quartus_asm NIOS > ../build/logs/asm-shell.log 2>&1
)
python3 scripts/check_soc.py
python3 scripts/source_manifest.py > build/images/sources.sha256
printf 'Built: %s/build/images/{shell,demo,scope}.{sof,elf}\n' "$UART_ROOT"
