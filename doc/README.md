# Thư mục Tài liệu Kỹ thuật & Báo cáo (Documentation)

Thư mục `doc/` chứa toàn bộ tài liệu đặc tả, hướng dẫn vận hành, báo cáo đo kiểm và sơ đồ kiến trúc của hệ thống **APB UART Core & SoC Nios-V**.

---

## 📁 Cấu trúc Phân loại Tài liệu

```text
doc/
├── guides/          # Hướng dẫn thực hành, nạp kit, thay đổi runtime config, viết testbench
├── reports/         # Báo cáo kỹ thuật (Fmax, Power, tài nguyên, phân tích & sửa lỗi phần cứng)
├── specs/           # Đặc tả thanh ghi, giao tiếp bus APB, test plan và FSM controller
├── diagrams/        # Sơ đồ khối kiến trúc (.drawio, .svg, .png) & giản đồ WaveDrom (.json)
├── references/      # Tài liệu chuẩn ARM AMBA (APB, AXI), datasheet và spec tham khảo
├── cpu_apb/         # Công cụ probe bus và kịch bản phân tích kết nối Avalon-APB
└── verification/    # Toàn bộ nhật ký và kết quả thực nghiệm đo đạc thực tế trên kit
```

---

## 📖 1. Hướng dẫn Thực hành (`guides/`)

- [`HUONG_DAN_THIET_KE_RTL_UART_RX.md`](guides/HUONG_DAN_THIET_KE_RTL_UART_RX.md): Cẩm nang thiết kế chi tiết khối thu `uart_rx` (FSM, 2-FF Sync, đếm tick, glitch filter, về IDLE sớm, overrun, RTS).
- [`HUONG_DAN_THIET_KE_RTL_UART_TX.md`](guides/HUONG_DAN_THIET_KE_RTL_UART_TX.md): Cẩm nang thiết kế chi tiết khối phát `uart_tx` (FSM 6-State, 2-FF CTS sync, WAIT_CTS, tx_done reset=1, tx_dis, PISO MUX).
- [`HUONG_DAN_NIOSV_IRQ_DEMO.md`](guides/HUONG_DAN_NIOSV_IRQ_DEMO.md): Hướng dẫn nạp kit và chạy demo ngắt (IRQ) Nios-V, hiển thị số byte đếm trên LED 7 đoạn HEX3:HEX2.
- [`HUONG_DAN_DOI_CONFIG_RUNTIME.md`](guides/HUONG_DAN_DOI_CONFIG_RUNTIME.md): Hướng dẫn thay đổi động Baudrate, Data bits, Parity và Stop bits ngay khi hệ thống đang chạy.
- [`HUONG_DAN_OSCILLOSCOPE_TX_DEMO.md`](guides/HUONG_DAN_OSCILLOSCOPE_TX_DEMO.md): Hướng dẫn đo kiểm xung truyền TX trên máy hiện sóng (Oscilloscope) qua chân GPIO kit.
- [`HUONG_DAN_APB_UART_NIOSV.md`](guides/HUONG_DAN_APB_UART_NIOSV.md): Hướng dẫn kết nối và tích hợp ngoại vi APB UART vào hệ thống Nios-V.
- [`HUONG_DAN_CHI_TIET_NANG_CAP_INTERRUPT_UART.md`](guides/HUONG_DAN_CHI_TIET_NANG_CAP_INTERRUPT_UART.md): Hướng dẫn nâng cấp cơ chế ngắt phần cứng, đăng ký ISR trong firmware C.
- [`HUONG_DAN_VIET_TESTBENCH_APB_UART.md`](guides/HUONG_DAN_VIET_TESTBENCH_APB_UART.md): Cẩm nang thiết kế và mở rộng testbench kiểm thử APB UART.
- [`GIAI_THICH_CODE_C_VA_APB_MASTER.md`](guides/GIAI_THICH_CODE_C_VA_APB_MASTER.md): Phân tích chi tiết mã nguồn driver C và cơ chế giao tiếp bus APB.
- [`README_NIOS.md`](guides/README_NIOS.md): Hướng dẫn sử dụng công cụ biên dịch Nios-V và nạp phần mềm.
- [`cheatsheet_commands.txt`](guides/cheatsheet_commands.txt): Các câu lệnh tắt nạp kit và mở terminal serial nhanh.

---

## 📊 2. Báo cáo Kỹ thuật & Đo lường (`reports/`)

- [`BAO_CAO_TAI_NGUYEN_FMAX_POWER_APB_UART_2026-10-17.md`](reports/BAO_CAO_TAI_NGUYEN_FMAX_POWER_APB_UART_2026-10-17.md): Báo cáo đo tài nguyên logic (LEs/ALMs), tần số cực đại Fmax và công suất tiêu thụ (Dynamic & Static Power).
- [`BAO_CAO_NAP_LICENSE_VA_CHAY_KIT_2026-10-17.md`](reports/BAO_CAO_NAP_LICENSE_VA_CHAY_KIT_2026-10-17.md): Báo cáo cấu hình license Nios-V, tạo file `.sof` vĩnh viễn và nghiệm thu trên kit DE2-115.
- [`BAO_CAO_SUA_LOI_VA_DONG_BO_FIFO_UART.md`](reports/BAO_CAO_SUA_LOI_VA_DONG_BO_FIFO_UART.md): Báo cáo sửa lỗi đồng bộ hàng đợi FIFO (TX/RX FIFO) và logic bảo vệ chống tràn.
- [`BAO_CAO_FIX_FRAMING_VA_CHAY_TESTBENCH.md`](reports/BAO_CAO_FIX_FRAMING_VA_CHAY_TESTBENCH.md): Báo cáo xử lý lỗi Framing Stop bit ở cả 2 chế độ 1 và 2 stop bits.
- [`BUG_TX_PARITY_SAU_KHI_POP_FIFO.md`](reports/BUG_TX_PARITY_SAU_KHI_POP_FIFO.md): Phân tích nguyên nhân và cách khắc phục lỗi chốt parity khi pop dữ liệu khỏi FIFO.
- [`NANG_CAP_HARDWARE_FIFO_UART.md`](reports/NANG_CAP_HARDWARE_FIFO_UART.md): Chi tiết kiến trúc nâng cấp bộ đệm phần cứng 16-entry Sync FIFO.

---

## 📐 3. Đặc tả Kỹ thuật (`specs/`)

- [`TESTPLAN_APB_UART.md`](specs/TESTPLAN_APB_UART.md): Kế hoạch kiểm thử toàn diện với 14 nhóm kiểm tra bao phủ 96 tổ hợp UART và các ca biên (Corner cases).
- [`reg_uart_spec.md`](specs/reg_uart_spec.md): Bảng ánh xạ địa chỉ thanh ghi (Memory Map) của APB UART (`DATA`, `CFG`, `STT`, `IER`).
- [`PHAN_TICH_KET_NOI_CPU_AVALON_APB_UART.md`](specs/PHAN_TICH_KET_NOI_CPU_AVALON_APB_UART.md): Phân tích chi tiết cơ chế chuyển đổi giao thức Avalon-MM sang APB trong Qsys Interconnect.
- [`KIEN_TRUC_DUAL_CPU_SHELL_APB.md`](specs/KIEN_TRUC_DUAL_CPU_SHELL_APB.md): Thiết kế kiến trúc Dual CPU và phân tầng ngoại vi.
- [`rx_controller_interface.md`](specs/rx_controller_interface.md): Đặc tả tín hiệu giao tiếp của bộ điều khiển thu RX.
- [`uart_rx_interface.md`](specs/uart_rx_interface.md): Đặc tả cổng giao tiếp top module RX UART.
- [`fsm_rx_controller.txt`](specs/fsm_rx_controller.txt): Máy trạng thái hữu hạn (FSM) của bộ điều khiển RX.

---

## 🖼️ 4. Sơ đồ Kiến trúc & Giản đồ Thời gian (`diagrams/`)

- `doc/diagrams/`: Chứa file nguồn Draw.io, sơ đồ vector SVG và ảnh PNG chất lượng cao thể hiện cấu trúc SoC, phân luồng IRQ và đường bus.
- `doc/diagrams/wavedrom/`: Các file WaveDrom JSON (`wavedrom_rx.json`, `wavedrom_rx_deframe_error.json`, `wavedrom_rx_zoom.json`) mô tả dạng sóng chuẩn của tín hiệu UART.

---

## 📚 5. Tài liệu Tham khảo (`references/`)

- `IHI0024D_amba_apb_protocol_spec.pdf`: Chuẩn giao tiếp AMBA APB Protocol Specification (v2.0).
- `IHI0022E_amba_axi_and_ace_protocol_spec.pdf`: Chuẩn giao tiếp AMBA AXI Protocol Specification.
- `DDI0183G_uart_pl011_r1p5_trm.pdf`: ARM PrimeCell UART (PL011) Technical Reference Manual.
- `final_project_design_requirements_rev0p0p2.pdf`: Yêu cầu thiết kế đề tài.
