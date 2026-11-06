# APB UART Core & Nios-V SoC Project

> **Điểm nổi bật:** Ngoại vi APB UART hoàn chỉnh với đầy đủ tính năng truyền/nhận song công (Full-Duplex), bộ đệm FIFO 16 byte hai chiều, cơ chế phát hiện lỗi Parity/Framing/Overrun, ngắt phần cứng (Hardware IRQ) và tích hợp hệ thống SoC Nios-V (RISC-V) trên FPGA Intel Cyclone IV E (DE2-115).
>
> 📖 Hướng dẫn chạy demo ngắt: [`doc/guides/HUONG_DAN_NIOSV_IRQ_DEMO.md`](doc/guides/HUONG_DAN_NIOSV_IRQ_DEMO.md)  
> 📊 Báo cáo kết quả đo Fmax & Công suất: [`doc/reports/BAO_CAO_TAI_NGUYEN_FMAX_POWER_APB_UART_2026-10-17.md`](doc/reports/BAO_CAO_TAI_NGUYEN_FMAX_POWER_APB_UART_2026-10-17.md)

---

## 📁 Cấu trúc Thư mục Dự án (Project Workspace Structure)

Toàn bộ dự án được phân định thành các vùng làm việc rõ ràng, độc lập và thuận tiện cho việc phát triển:

```text
UART/
├── rtl/                   # Mã nguồn Verilog phần cứng (RTL Core)
│   ├── apb_uart.v         # Top-level IP APB UART
│   ├── apb_slave.v        # Bộ giải mã bus AMBA APB
│   ├── uart_regs.v        # Thanh ghi điều khiển, trạng thái & ngắt
│   ├── sync_fifo.v        # Hàng đợi đồng bộ 16-entry cho TX và RX
│   ├── rx_*.v             # Các khối của bộ thu RX (baud gen, controller, deframe...)
│   ├── tx_*.v             # Các khối của bộ phát TX (baud gen, controller, piso...)
│   └── avalon2apb.v       # Cầu nối độc lập Avalon-MM sang APB
│
├── software/              # Phần mềm Firmware C cho vi xử lý Nios-V (RISC-V)
│   ├── main.c             # Firmware ứng dụng Console Shell tương tác
│   ├── irq_demo.c         # Firmware kiểm chứng cơ chế ngắt và hiển thị LED 7 đoạn
│   ├── scope_demo.c       # Firmware phát xung liên tục phục vụ đo Oscilloscope
│   ├── uart_irq.c / .h    # Driver ngắt UART ISR tối ưu kèm Ring Buffer
│   ├── uart_config.c / .h # Driver phân tích & thay đổi cấu hình runtime linh hoạt
│   └── CMakeLists.txt     # Cấu hình build hệ thống cho Nios-V Toolchain
│
├── fpga/                  # Dự án Quartus Prime cho chip Cyclone IV E (EP4CE115)
│   ├── NIOS.qpf / .qsf    # File cấu hình pin và project Quartus
│   ├── NIOS.sdc           # Ràng buộc thời gian (Timing Constraints 50 MHz)
│   ├── NIOS.v             # Top-level module kết nối FPGA pins
│   └── system.qsys        # Thiết kế hệ thống SoC Platform Designer
│
├── tb/                    # Bộ Testbench mô phỏng & Test driver
│   ├── tb_apb_uart.v      # Testbench toàn diện 149 testcase theo APB Spec
│   ├── tb_full_duplex.v   # Kiểm chứng truyền nhận song công đồng thời 2 dây
│   ├── tb_firmware_scenario.v # Kịch bản mô phỏng Nios-V CPU tương tác APB
│   ├── tb_rx_uart.v       # Unit test bộ thu RX
│   ├── test_*.c           # Test driver C cho ISR driver, parser cấu hình
│   └── models/            # Mô hình UART ảo độc lập (Virtual RX / Virtual TX)
│
├── sim/                   # Kịch bản mô phỏng ModelSim / QuestaSim (.tcl / .do)
│
├── scripts/               # Bộ công cụ tự động hóa, build, nạp và chẩn đoán
│   ├── build_soc.sh       # Tự động sinh Qsys, biên dịch C firmware & Quartus
│   ├── flash_fpga.sh      # Nạp nhanh file .sof xuống kit FPGA qua USB-Blaster
│   ├── run_shell_demo.sh  # Nạp shell.sof và tự động mở JTAG terminal
│   ├── run_irq_demo.sh    # Nạp demo.sof và hướng dẫn mở serial terminal
│   ├── run_scope_demo.sh  # Nạp scope.sof để đo kiểm trên máy hiện sóng
│   ├── run_terminal_jtag.sh # Mở terminal kết nối Nios-V JTAG UART
│   ├── run_terminal_pc.sh # Mở terminal PC giao tiếp UART qua cổng COM/ttyUSB
│   ├── run_diag.sh        # Tool tự động chẩn đoán thông tuyến 2 chiều PC <-> Kit
│   ├── test_full_duplex.py# Script stress-test song công bằng Python
│   └── uart_metrics/      # Bộ script đo Fmax, Power và phân tích tài nguyên
│
├── doc/                   # Toàn bộ tài liệu kỹ thuật (Xem chi tiết tại doc/README.md)
│   ├── guides/            # Các cẩm nang hướng dẫn thực hành & nạp kit
│   ├── reports/           # Báo cáo kỹ thuật Fmax, Power, sửa lỗi và nghiệm thu
│   ├── specs/             # Đặc tả thanh ghi, test plan và kiến trúc bus
│   ├── diagrams/          # Sơ đồ khối kiến trúc (.drawio, .svg) & WaveDrom
│   ├── references/        # Tài liệu chuẩn ARM AMBA, TRM PDF tham khảo
│   ├── cpu_apb/           # Phân tích & probe bus Avalon-APB
│   └── verification/      # Báo cáo và log nghiệm thu thực nghiệm
│
├── legacy/                # Lưu trữ các file thiết kế cũ
├── apb_uart_hw.tcl        # Định nghĩa IP Component cho Platform Designer (Qsys)
├── Makefile               # Điều khiển toàn bộ quy trình biên dịch, test và chạy
└── README.md              # Tài liệu tổng quan (file này)
```

---

## 🚀 Hướng Dẫn Sử Dụng Nhanh (Cheat Sheet)

### 1. Kiểm thử Mô phỏng (Simulation Testbench)
Chạy toàn bộ 149 testcase kiểm chứng chuẩn đặc tả bằng Icarus Verilog:
```bash
make test          # Chạy toàn bộ test suites (Full-Duplex, Firmware, RX, APB UART)
make test_apb      # Chạy testbench chính tb_apb_uart (14 nhóm testcase theo spec)
make test_fd       # Chạy kiểm thử truyền nhận song công đồng thời (Full-Duplex)
make test_fw       # Chạy kịch bản CPU tương tác thanh ghi APB UART
```

Xem dạng sóng mô phỏng bằng GTKWave:
```bash
make wave_apb_uart
make wave_full_duplex
```

Mô phỏng qua ModelSim / QuestaSim (GUI hoặc dòng lệnh):
```bash
make apb_uart_vsim      # Mở GUI ModelSim
make apb_uart_vsim_cli  # Chạy CLI không mở GUI
```

Kiểm tra cú pháp Verilog:
```bash
make check              # Kiểm tra toàn bộ file trong rtl/
make check FILE=rx_uart # Kiểm tra riêng module rx_uart.v
```

Kiểm thử driver phần mềm C:
```bash
make test_irq_driver    # Kiểm thử driver ISR ngắt UART
make test_uart_config   # Kiểm thử parser cấu hình UART (96 định dạng)
make test_runtime_config# Kiểm thử đổi cấu hình động runtime
make test_scope_demo    # Kiểm thử firmware phát xung oscilloscope
```

---

### 2. Vận hành Trên Kit FPGA (Hardware & Demo Runners)

Tất cả các tác vụ chạy kit đã được tích hợp vào `Makefile` và `scripts/`:

```bash
# Nạp nhanh và chạy ứng dụng Console Shell (mặc định)
make run_shell

# Nạp và chạy Demo Ngắt (đếm byte nhận trên LED 7 đoạn HEX3:HEX2)
make run_demo

# Nạp ứng dụng phát xung liên tục phục vụ đo Oscilloscope
make run_scope

# Mở JTAG terminal đọc thông điệp từ Nios-V:
make terminal_jtag

# Mở Serial terminal giao tiếp từ PC qua cổng USB-to-UART:
make terminal_pc PORT=/dev/ttyUSB0 BAUD=9600 FORMAT=8N1

# Chẩn đoán kết nối 2 chiều PC <-> Kit:
make diag PORT=/dev/ttyUSB0

# Chạy stress test song công 2 chiều bằng Python:
make full_duplex_stress PORT=/dev/ttyUSB0
```

---

### 3. Build Lại Toàn Bộ Hệ Thống SoC từ Đầu
Khi có thay đổi về RTL hoặc firmware C, chạy script tự động:
```bash
make soc_build    # Tự động chạy Platform Designer, Nios-V CMake và Quartus Prime
make soc_check    # Kiểm tra tính toàn vẹn của kết nối bus, địa chỉ và chân pin
```

Dọn dẹp các file rác mô phỏng:
```bash
make clean
```
