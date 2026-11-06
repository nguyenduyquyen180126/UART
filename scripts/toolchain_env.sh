#!/usr/bin/env bash
# Source this file; override ALTERA_DIR / RISCV_BIN for another installation.
UART_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ALTERA_DIR="${ALTERA_DIR:-/home/vietanh/altera_lite/24.1std}"
export RISCV_BIN="${RISCV_BIN:-/home/vietanh/opt/xpack-riscv-none-elf-gcc-15.2.0-1/bin}"
export QUARTUS_ROOTDIR="$ALTERA_DIR/quartus"
export SOPC_KIT_NIOS2="$ALTERA_DIR/nios2eds"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.awt.headless=true"
export PATH="$RISCV_BIN:$ALTERA_DIR/niosv/bin:$QUARTUS_ROOTDIR/bin:$QUARTUS_ROOTDIR/sopc_builder/bin:$PATH"

# Login/noninteractive shells may not source ~/.bashrc. Prefer the installed
# Nios V IP license once, while retaining other simulator/server licenses.
if [[ -r "$HOME/.altera/license.dat" ]]; then
    case ":${LM_LICENSE_FILE:-}:" in
        *":$HOME/.altera/license.dat:"*) ;;
        *) export LM_LICENSE_FILE="$HOME/.altera/license.dat${LM_LICENSE_FILE:+:$LM_LICENSE_FILE}" ;;
    esac
fi
