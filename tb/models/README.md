# UART ảo: RX và TX độc lập

Hai module mô hình hành vi, chỉ dùng trong mô phỏng; không dùng RTL nội bộ DUT.

```text
APB write TX_DATA ──> DUT TX ──serial──> u_virtual_rx ──rx_data/rx_done──> Compare
       └──────────────── expected byte ────────────────────────────────> Compare
                                                                         │
                                                                         v
                                                               Monitor: log / VCD

u_virtual_tx ──serial──> DUT RX ──APB read RX_DATA──> Compare
       └──────────────── expected byte ────────────> Compare
```

## RX ảo: `uart_rx_virtual.v`

- `serial_in`: nối chân `tx` của DUT.
- `cfg[1:0]`: `00/01/10/11` tương ứng 5/6/7/8 bit dữ liệu.
- `cfg[2]`: `0/1` tương ứng 1/2 stop bit.
- `cfg[3]`: cho phép parity; `cfg[4]`: `0` even, `1` odd.
- `baud_rate`: số baud trực tiếp, ví dụ `9600`.
- `rx_data`, `rx_done`: byte đã giải mã và tín hiệu báo kết quả.
- `start_error`, `parity_error`, `stop_error`: lỗi khung vừa nhận.
- `busy`: đang xử lý một khung.

RX chốt cấu hình lúc gặp cạnh xuống start, lấy mẫu ở giữa mỗi bit bằng delay
`1e9 / baud_rate` nanosecond. Dữ liệu và các cờ lỗi ổn định khi `rx_done` lên 1.
Các tín hiệu `busy`/`rx_done` có thể quan sát trong waveform dưới `u_virtual_rx`.

## TX ảo: `uart_tx_virtual.v`

- `serial_out`: nối chân `rx` của DUT (qua mux để giữ phép thử loopback).
- `tx_data`, `cfg`, `baud_rate`: byte và cấu hình khung; cách mã hóa như RX ảo.
- `start`: giữ 1 qua một cạnh lên `clk` khi module rảnh.
- `inject_parity_error`: đảo bit parity để kiểm tra khả năng phát hiện lỗi của DUT.
- `busy`: đang phát; `tx_done`: đã phát đủ cả stop bit.

TX chốt dữ liệu/cấu hình lúc nhận `start`. Chỉ gửi yêu cầu kế tiếp sau khi
`tx_done` đã về 0. Reset mức thấp hủy khung đang xử lý và đưa TX về idle = 1.
Task `send_uart_rx_byte` trong testbench điều khiển giao diện này.

## Compare và Monitor

Hai phần này nằm trong `tb_apb_uart.v`:

- Bus monitor ghi nhận byte TX khi APB thực sự chấp nhận giao dịch.
- `compare_tx_and_monitor` so sánh byte RX ảo nhận với hàng đợi mong đợi,
  đồng thời kiểm tra start/parity/stop và giữ kết quả để xem waveform.
- Monitor APB so sánh byte DUT nhận với dữ liệu đã yêu cầu TX ảo phát.
- Testcase 7 chạy full-duplex với 24 cấu hình khung ở 19200 baud,
  rồi thử 8N1 ở cả 2400, 4800, 9600, 19200 baud.
- Nhóm 8–14 bổ sung APB, khóa CFG, mask IRQ, FIFO, start giả và framing error;
  nhóm 13 hoàn tất ma trận 96 tổ hợp baud × data × parity × stop.
  Xem [testplan theo spec](../../doc/TESTPLAN_APB_UART.md) và kết quả chạy chi tiết.

DUT `STT[0]` chỉ báo TX hoàn toàn rảnh, không phải xung kết thúc từng byte.
Vì vậy so sánh từng byte được kích bằng `u_virtual_rx.rx_done`; trạng thái DUT
được kiểm tra riêng khi chờ hoàn tất. Kết quả cuối có kiểm tra byte còn thiếu.
Mô hình chưa phải bộ kiểm chứng đầy đủ dung sai baud, nhiễu hay mọi điều kiện lỗi.

Từ thư mục `UART`:

```bash
iverilog -g2012 -s tb_apb_uart -o /tmp/tb_apb_uart tb/tb_apb_uart.v tb/models/*.v rtl/*.v
vvp /tmp/tb_apb_uart +NO_VCD
```

Bỏ `+NO_VCD` để xuất `wave_apb_uart.vcd`. Các lệnh `make apb_uart`,
`make apb_uart_vsim`, `make apb_uart_vsim_cli` đã bao gồm hai file mô hình.

`[REF FAIL]` hoặc `$fatal` nghĩa là DUT khác mô hình. Bộ so sánh từng phát hiện
lỗi parity TX do tính từ đầu FIFO sau khi pop. RTL hiện đã chốt `parity_latched`
cùng lúc nạp PISO để giữ parity theo đúng byte đang phát. Xem
[báo cáo bug](../../doc/BUG_TX_PARITY_SAU_KHI_POP_FIFO.md) để biết nguyên nhân và cách sửa.

RTL RX đã được sửa để phát hiện stop sai ở cả cấu hình 1 và 2 stop bit.
Kết quả hiện tại: **149 PASS, 0 FAIL**, đối chiếu 122 khung TX và 153 byte RX,
không lỗi tham chiếu. Chi tiết từng dòng sửa và lệnh chạy nằm trong
[báo cáo sửa framing error](../../doc/BAO_CAO_FIX_FRAMING_VA_CHAY_TESTBENCH.md).

Chạy nhanh từ thư mục `UART`: `make apb_uart VVP_ARGS=+NO_VCD`.
