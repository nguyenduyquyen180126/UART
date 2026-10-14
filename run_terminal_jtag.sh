#!/bin/bash
# Script mở Terminal 1: JTAG Console của CPU Nios V trên kit DE2-115

echo "=========================================================="
echo "   TERMINAL 1: NIOS-V SoC INTERACTIVE JTAG CONSOLE        "
echo "=========================================================="

CABLE=$(/home/vietanh/altera_lite/24.1std/quartus/bin/jtagconfig 2>/dev/null | grep -i "USB-Blaster" | head -n 1 | sed 's/^[0-9]*)[[:space:]]*//')

if [ -z "$CABLE" ]; then
    echo "[CẢNH BÁO]: jtagconfig chưa thấy cáp, đang khởi động lại jtagd..."
    killall -9 jtagd 2>/dev/null
    sleep 1
    CABLE=$(/home/vietanh/altera_lite/24.1std/quartus/bin/jtagconfig 2>/dev/null | grep -i "USB-Blaster" | head -n 1 | sed 's/^[0-9]*)[[:space:]]*//')
fi

if [ -z "$CABLE" ]; then
    echo "[LỖI]: Không tìm thấy cáp nạp USB-Blaster!"
    echo "Vui lòng kiểm tra:"
    echo "  1. Đã cắm cáp USB-Blaster vào máy tính chưa?"
    echo "  2. Đã bật công tắc nguồn (Power ON) trên kit DE2-115 chưa?"
    echo ""
    echo "Thử chạy lại sau khi cắm/bật nguồn kit."
    exit 1
fi

echo "-> Đang kết nối tới CPU Nios V qua cáp: $CABLE..."
echo "-> Mẹo: Gõ 'help' để xem danh sách lệnh, gõ 'send <msg>' để gửi dữ liệu sang PC."
echo "----------------------------------------------------------"
echo ""

exec /home/vietanh/altera_lite/24.1std/quartus/bin/juart-terminal -c "$CABLE"
