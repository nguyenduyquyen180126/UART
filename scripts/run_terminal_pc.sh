#!/usr/bin/env bash
# Terminal 2: ./run_terminal_pc.sh [port] [baud] [format, e.g. 8E2]
set -euo pipefail
PORT="${1:-}"
UART_BAUD="${2:-9600}"
UART_FORMAT="${3:-8N1}"
UART_FORMAT="${UART_FORMAT^^}"
case "$UART_BAUD" in 2400|4800|9600|19200) ;; *) echo 'Baud: 2400, 4800, 9600 or 19200' >&2; exit 1;; esac
[[ "$UART_FORMAT" =~ ^[5-8][NEO][12]$ ]] || { echo 'Format: 5..8 data bits, N/E/O parity, 1/2 stop bits (e.g. 8E2)' >&2; exit 1; }
if [[ -z "$PORT" ]]; then
    for dev in /dev/ttyUSB* /dev/ttyACM*; do
        if [[ -e "$dev" ]]; then PORT="$dev"; break; fi
    done
fi
[[ -n "$PORT" && -e "$PORT" ]] || { echo 'Serial port not found. Connect USB-UART; specify /dev/serial/by-id/... if needed.' >&2; exit 1; }
UART_PARITY="${UART_FORMAT:1:1}"
printf 'Terminal 2: %s, %s %s (must match FPGA)\n' "$PORT" "$UART_BAUD" "$UART_FORMAT"
echo 'Runtime FPGA command: @config 19200 8E2 or @baud 9600, then Enter.'
echo 'Wait APPLIED on Terminal 1. Change PC: Ctrl+A then Ctrl+B (baud), Ctrl+Y (parity), Ctrl+I (data), Ctrl+J (stop).'
echo 'Each shortcut starts with Ctrl+A. Inspect PC settings: Ctrl+A then Ctrl+V. Exit: Ctrl+A then Ctrl+X.'
exec picocom --baud "$UART_BAUD" --databits "${UART_FORMAT:0:1}" --parity "${UART_PARITY,,}" --stopbits "${UART_FORMAT:2:1}" --flow n --imap lfcrlf "$PORT"
