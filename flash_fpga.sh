#!/bin/bash
# Script nạp nhanh file bitstream NIOS.sof vào kit DE2-115

SOF_FILE="/home/vietanh/altera_lite/24.1std/output_files/NIOS.sof"

if [ ! -f "$SOF_FILE" ]; then
    echo "[LỖI]: Không tìm thấy file $SOF_FILE!"
    exit 1
fi

# Tự động lấy chính xác chuỗi tên cáp từ jtagconfig (ví dụ: "USB-Blaster [3-11]")
CABLE=$(/home/vietanh/altera_lite/24.1std/quartus/bin/jtagconfig 2>/dev/null | grep -i "USB-Blaster" | head -n 1 | sed 's/^[0-9]*)[[:space:]]*//')

if [ -z "$CABLE" ]; then
    echo "[CẢNH BÁO]: jtagconfig chưa thấy cáp, đang khởi động lại jtagd..."
    killall -9 jtagd 2>/dev/null
    sleep 1
    CABLE=$(/home/vietanh/altera_lite/24.1std/quartus/bin/jtagconfig 2>/dev/null | grep -i "USB-Blaster" | head -n 1 | sed 's/^[0-9]*)[[:space:]]*//')
fi

if [ -z "$CABLE" ]; then
    echo "[LỖI]: Không tìm thấy cáp nạp USB-Blaster!"
    echo "Vui lòng cắm cáp USB-Blaster và bật nguồn kit DE2-115 trước khi nạp."
    exit 1
fi

echo "-> Đang nạp bitstream vào kit DE2-115 qua cáp: $CABLE..."
/home/vietanh/altera_lite/24.1std/quartus/bin/quartus_pgm -m jtag -c "$CABLE" -o "p;$SOF_FILE"

if [ $? -eq 0 ]; then
    echo "=========================================================="
    echo " [THÀNH CÔNG] Đã nạp SoC Nios-V & APB UART vào kit DE2-115!"
    echo "=========================================================="
else
    echo "[LỖI]: Quá trình nạp thất bại. Vui lòng kiểm tra lại cáp và nguồn."
fi
