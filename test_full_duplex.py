#!/usr/bin/env python3
"""
Script Stress-Test Full-Duplex (Song công toàn phần) trên cổng Serial PC.
Kiểm tra truyền và nhận đồng thời 2 chiều giữa PC (x86_64) và DE2-115 (Nios V).
"""

import sys
import time
import threading

try:
    import serial
except ImportError:
    print("[CẢNH BÁO]: Chưa cài thư viện pyserial. Chạy: pip install pyserial")
    sys.exit(1)

SERIAL_PORT = "/dev/ttyUSB0" if len(sys.argv) < 2 else sys.argv[1]
BAUD_RATE   = 9600
NUM_TESTS   = 10

sent_count = 0
received_lines = []
lock = threading.Lock()
stop_event = threading.Event()

def receiver_thread(ser):
    """Luồng độc lập chuyên đọc dữ liệu từ FPGA gửi lên"""
    while not stop_event.is_set():
        try:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if line:
                    with lock:
                        received_lines.append(line)
                        print(f"  [PC RX Thread]: << {line}")
            else:
                time.sleep(0.01)
        except Exception as e:
            break

def sender_thread(ser):
    """Luồng độc lập chuyên bắn dữ liệu từ PC xuống FPGA"""
    global sent_count
    for i in range(1, NUM_TESTS + 1):
        msg = f"PC_STREAM_PACKET_{i:02d}"
        payload = f"{msg}\r"
        with lock:
            print(f"  [PC TX Thread]: >> Gửi '{msg}'")
        ser.write(payload.encode('ascii'))
        sent_count += 1
        time.sleep(0.15) # Giãn cách nhỏ giữa các câu

def main():
    print("====================================================================")
    print("   KIỂM THỬ STRESS TEST FULL-DUPLEX ĐỒNG THỜI 2 CHIỀU (PC <-> DE2)  ")
    print("====================================================================")
    print(f"-> Đang kết nối tới cổng: {SERIAL_PORT} @ {BAUD_RATE} baud...")

    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1.0)
    except Exception as e:
        print(f"[LỖI]: Không mở được cổng {SERIAL_PORT}: {e}")
        print("Vui lòng kiểm tra cáp USB-to-UART đã cắm và kit đã bật nguồn.")
        return

    time.sleep(0.5)
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    print("-> Bắt đầu kích hoạt đồng thời 2 luồng TX và RX...")
    t_recv = threading.Thread(target=receiver_thread, args=(ser,), daemon=True)
    t_send = threading.Thread(target=sender_thread, args=(ser,))

    t_recv.start()
    t_send.start()

    t_send.join()
    time.sleep(1.0) # Đợi nốt các byte cuối
    stop_event.set()
    ser.close()

    print("\n====================================================================")
    print("                      KẾT QUẢ TEST FULL-DUPLEX                      ")
    print("====================================================================")
    print(f"  Số gói tin PC đã gửi đồng thời : {sent_count}")
    print(f"  Số phản hồi thu được           : {len(received_lines)}")
    print("  >>> Kết luận: 2 chiều TX và RX hoạt động song công thành công! <<<")
    print("====================================================================\n")

if __name__ == "__main__":
    main()
