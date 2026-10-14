#!/bin/bash
# Script mở Terminal 2: PC Serial Console (Giao tiếp với APB UART)

echo "=========================================================="
echo "   TERMINAL 2: PC SERIAL APPLICATION (APB UART 9600)      "
echo "=========================================================="

PORT="$1"
if [ -z "$PORT" ]; then
    for dev in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$dev" ]; then
            PORT="$dev"
            break
        fi
    done
fi

if [ -z "$PORT" ] || [ ! -e "$PORT" ]; then
    echo "[LỖI]: Không tìm thấy cổng Serial USB nào (/dev/ttyUSB*)!"
    echo "Vui lòng kiểm tra:"
    echo "  1. Đã cắm mạch USB-to-UART ngoài vào cổng USB máy tính chưa?"
    echo "  2. Đã cắm 2 dây TX/RX và dây GND vào header JP5 của kit DE2-115 chưa?"
    echo ""
    echo "Sau khi cắm, hãy chạy lại: ./run_terminal_pc.sh"
    exit 1
fi

echo "-> Đang kết nối tới cổng: $PORT (Baud 9600, 8-N-1)..."
echo "-> Mẹo (Cách B): Gõ tin nhắn văn bản và nhấn [ENTER] để gửi nguyên chuỗi sang CPU Nios V (Terminal 1)."
echo "-> Hỗ trợ: Phím Backspace để xóa ký tự, LED 7-đoạn hiển thị mã ASCII trực tiếp."
echo "-> Thoát: Nhấn Ctrl + A rồi nhấn Ctrl + X."
echo "----------------------------------------------------------"
echo ""

exec picocom -b 9600 -d 8 -p n -s 1 --imap lfcrlf "$PORT"
