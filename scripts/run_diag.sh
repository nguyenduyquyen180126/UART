#!/usr/bin/env python3
import os
import sys
import time
import termios
import tty
import select
import subprocess
import threading

SERIAL_PORT = "/dev/ttyUSB0" if len(sys.argv) < 2 else sys.argv[1]

print("====================================================================")
print("     TOOL TỰ ĐỘNG CHẨN ĐOÁN GIAO TIẾP 2 CHIỀU (DE2 <-> PC)")
print("====================================================================")

# 1. Cấu hình cổng Serial qua termios
try:
    fd = os.open(SERIAL_PORT, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    tty.setraw(fd)
    attrs[4] = termios.B9600
    attrs[5] = termios.B9600
    attrs[2] &= ~(termios.PARENB | termios.CSTOPB | termios.CSIZE)
    attrs[2] |= (termios.CS8 | termios.CREAD | termios.CLOCAL)
    attrs[0] &= ~(termios.IXON | termios.IXOFF | termios.IXANY)
    if hasattr(termios, 'CRTSCTS'):
        attrs[2] &= ~termios.CRTSCTS
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    print(f"[1/4] Cổng Serial {SERIAL_PORT} đã sẵn sàng @ 9600 baud, 8-N-1.")
except Exception as e:
    print(f"[LỖI]: Không mở được {SERIAL_PORT}: {e}")
    print("-> Hãy kiểm tra mạch USB-to-UART đã cắm vào máy tính chưa.")
    sys.exit(1)

# 2. Khởi chạy juart-terminal
cable = "USB-Blaster [3-11]"
proc = subprocess.Popen(
    ["/home/vietanh/altera_lite/24.1std/quartus/bin/juart-terminal", "-c", cable],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    bufsize=1
)

time.sleep(1.2)
print("[2/4] Đã kết nối kênh JTAG tới CPU Nios V.")

stop_flag = False
def read_jtag():
    while not stop_flag and proc.poll() is None:
        try:
            line = proc.stdout.readline()
            if line and line.strip():
                print(f"  [Nios-V JTAG]: {line.strip()}")
        except Exception:
            break

t = threading.Thread(target=read_jtag, daemon=True)
t.start()

# Kích hoạt Nios V prompt
proc.stdin.write("\r\n")
proc.stdin.flush()
time.sleep(0.5)

# 3. Đọc trạng thái
print("\n[3/4] Kiểm tra thanh ghi phần cứng APB UART...")
proc.stdin.write("status\r\n")
proc.stdin.flush()
time.sleep(1.0)

# 4. Test chiều FPGA -> PC
print("\n[4/4] Kiểm tra truyền 2 chiều đồng thời:")
print("  -> Nios V đang gửi 'HELLO_FROM_FPGA' sang PC qua APB UART...")
proc.stdin.write("send HELLO_FROM_FPGA\r\n")
proc.stdin.flush()

pc_rx_data = b""
t_start = time.time()
while time.time() - t_start < 2.5:
    r, _, _ = select.select([fd], [], [], 0.1)
    if r:
        chunk = os.read(fd, 256)
        if chunk:
            pc_rx_data += chunk
    time.sleep(0.05)

if pc_rx_data:
    print(f"\n  [KẾT QUẢ TX -> RX]: THÀNH CÔNG! PC nhận được: \"{pc_rx_data.decode('ascii', errors='replace').strip()}\"")
else:
    print("\n  [KẾT QUẢ TX -> RX]: THẤT BẠI! PC không nhận được dữ liệu từ FPGA.")

# 5. Test chiều PC -> FPGA
print("\n  -> PC đang gửi 'PING_FROM_PC' xuống FPGA...")
os.write(fd, b"PING_FROM_PC\r\n")
time.sleep(1.5)

stop_flag = True
proc.terminate()
os.close(fd)
print("\n==================== HOÀN TẤT CHẨN ĐOÁN ====================")
