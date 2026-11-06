# Đổi cấu hình UART trực tiếp — shell Nios V/m

Đã bổ sung trong `main.c`, `software/uart_config.c` và driver IRQ. Không sửa RTL,
Qsys, bản đồ địa chỉ hoặc chân. Cần nạp **shell.sof mới một lần** để cập nhật
firmware. Từ lần đó, đổi cấu hình bằng lệnh lúc CPU đang chạy, không compile/nạp
lại cho mỗi cấu hình.

Các lệnh này thuộc bản **shell**, không phải `demo.sof` đồng hồ/echo nhị phân.
Demo giữ giao thức echo cũ để không nhầm dữ liệu nhị phân với lệnh điều khiển.

## 1. Cập nhật lần đầu

Đóng terminal kết nối kit, rồi chạy ở thư mục repo:

```bash
# shell.sof mới đã được build; khi cắm kit chỉ cần nạp
./flash_fpga.sh
./run_terminal_jtag.sh
```

Terminal 2:

```bash
./run_terminal_pc.sh /dev/ttyUSB0
```

Khởi động lại CPU/nạp lại image sẽ về mặc định 9600 8N1. Chưa lưu cấu hình runtime
vào flash. Nếu sửa nguồn thêm, chạy `./scripts/build_soc.sh` trước khi nạp.

## 2. Lệnh tại Terminal 1 — JTAG shell

Thoát chế độ `chat` bằng Esc trước khi nhập lệnh:

```text
config
config 19200 8E2
baud 9600
```

- `config` hoặc `baud` không có tham số: đọc cấu hình hiện tại.
- `config <baud> <format>`: đổi đủ baud/data/parity/stop.
- `baud <baud>`: chỉ đổi baud, giữ các trường còn lại.
- Baud: 2400, 4800, 9600, 19200.
- Format: 5–8 data bit, N/E/O parity, 1/2 stop; ví dụ 8N1, 8E2, 7O1.
- Baud được nhập dạng thập phân; `115200` không được RTL hỗ trợ và bị từ chối.

Dừng gửi dữ liệu ở Terminal 2, gửi lệnh, đợi Terminal 1 báo:

```text
APPLIED 19200 8E2; now update PC serial settings.
```

Sau đó đổi cấu hình phần mềm serial của PC cho khớp, rồi mới gửi tiếp.
`peek 08` vẫn đọc được CFG thô; không dùng `poke 08` vì driver quản lý việc đổi.

## 3. Lệnh tại Terminal 2 — UART

Nhập ở cấu hình đang chạy và nhấn Enter:

```text
@config
@config 19200 8E2
@baud 9600
```

Tiền tố `@` chỉ dành cho các lệnh cấu hình, tránh biến tin nhắn thông thường
`config ...` thành thao tác điều khiển. FPGA trả `SWITCH ...` bằng **cấu hình cũ**.
Sau Enter, dừng gửi; đợi `APPLIED` trên Terminal 1, đổi cài đặt serial của PC,
rồi gửi `@config` ở cấu hình mới để kiểm tra.

Terminal 2 dùng lệnh ASCII nên cần 7/8 data bit; yêu cầu đổi sang 5/6 bit qua
Terminal 2 bị từ chối. Dùng JTAG Terminal 1 để thử hoặc phục hồi cấu hình 5/6 bit.

Các dữ liệu thông thường vẫn đi qua ISR và cơ chế gom dòng/echo như trước.
`echo off` không ngăn phản hồi điều khiển `@config`.

## 4. Đổi phía PC ngay trong picocom

Các phím được đối chiếu với man page picocom đang cài. Nhấn **Ctrl+A**, nhả ra,
rồi nhấn tổ hợp thứ hai; mỗi thao tác đều bắt đầu lại bằng Ctrl+A.

| Phím | Tác dụng phía PC |
|---|---|
| Ctrl+A → Ctrl+B | Nhập baud, ví dụ `19200`, Enter |
| Ctrl+A → Ctrl+Y | Chuyển parity: even → odd → none |
| Ctrl+A → Ctrl+I | Chuyển data bit 5/6/7/8 |
| Ctrl+A → Ctrl+J | Chuyển stop bit 1/2 |
| Ctrl+A → Ctrl+V | Xem cấu hình thực tế của serial port |
| Ctrl+A → Ctrl+X | Thoát |

Ví dụ từ 9600 8N1 sang 19200 8E2:

1. Gõ `config 19200 8E2` ở Terminal 1 hoặc `@config 19200 8E2` ở Terminal 2.
2. Đợi `APPLIED` tại Terminal 1.
3. Tại picocom: Ctrl+A → Ctrl+B, nhập `19200`, Enter.
4. Ctrl+A → Ctrl+Y đến khi parity=even; Ctrl+A → Ctrl+J đến stopbits=2.
5. Ctrl+A → Ctrl+V kiểm tra 19200 / 8 / even / 2 / flow none.
6. Gửi `@config` hoặc văn bản kiểm tra.

Cũng có thể thoát picocom rồi mở lại đúng tham số:

```bash
./run_terminal_pc.sh /dev/ttyUSB0 19200 8E2
```

**Phím picocom chỉ đổi PC; lệnh config chỉ đổi FPGA.** Hai phía phải khớp.
Nếu mất liên lạc UART, Terminal 1 vẫn độc lập: dùng `config` để đọc hoặc
`config 9600 8N1` để phục hồi, rồi chỉnh PC về 9600 8N1.

## 5. Đồng bộ chuyển cấu hình và giới hạn phần cứng

Lệnh không ghi CFG ngay khi đang phát/nhận:

- Xếp phản hồi vào TX queue cũ nếu lệnh đến từ Terminal 2.
- Main tiếp tục phục vụ RX queue; ISR RX/TX vẫn hoạt động.
- Chờ TX-complete IRQ, ít nhất 200 ms từ yêu cầu và RX không có byte mới trong
  50 ms. 50 ms dài hơn một khung ở mọi cấu hình baud/data/parity/stop được hỗ trợ.
- Trong critical section, kiểm tra queue RX/TX và STT, ghi CFG, đọc lại CFG.
- Sau khi đổi, thông báo APPLIED chỉ gửi qua JTAG để PC không đọc nhầm ở baud cũ.
- Nếu không đạt điều kiện trong 2 giây: TIMEOUT, giữ cấu hình cũ. Yêu cầu mới khi
  đang pending bị từ chối BUSY. Lệnh sai không làm thay đổi cấu hình.

**Phải dừng truyền từ PC trong quá trình chuyển.** RTL hiện không đưa `rx_busy`
ra STT và trả PSLVERR nếu ghi CFG đúng lúc đang thu một khung. Khoảng yên lặng
là quy ước phối hợp hai đầu, không phải khóa vật lý ngăn PC phát khung mới.
Không hỗ trợ đổi cấu hình an toàn giữa luồng RX liên tục hoặc cố ý phát đúng
thời điểm ghi CFG. Muốn bảo đảm cả trường hợp đó cần mở rộng handshake RTL;
chưa sửa hành vi RTL trong thay đổi firmware này.

## 6. Kiểm chứng trong lần thay đổi này

```bash
make test_uart_config test_runtime_config test_irq_driver test_demo_clock
```

- Parser/encoder: kiểm tra đủ 96 tổ hợp hợp lệ, query, giữ frame khi đổi baud,
  từ chối baud/format sai, dư tham số, giữ nguyên tin nhắn không phải lệnh.
- Driver thực: đổi khi idle, từ chối khi TX/RX queue bận, giữ IER/IRQ.
- Shell thực với mô hình host: lệnh T1, parser dòng T2, CRLF, phản hồi cũ,
  chờ TX, RX quiet, APPLIED, timeout, từ chối 5/6 bit ở T2.
- Kiểm tra script Terminal 2 truyền đúng long options tới picocom. Đã sửa lỗi
  short option cũ: bản picocom đang cài dùng `-y` cho parity, `-p` cho stopbits;
  script mới dùng `--parity`/`--stopbits` để tránh nhầm.
- Build lại ELF/HEX và bitstream. Các cảnh báo header HAL vendor được giữ nguyên.

Công cụ hiện báo **No JTAG hardware available**. Vì vậy chưa nạp và chưa kiểm tra
runtime-config mới trên kit; không dùng kết quả echo của firmware cũ để kết luận
chức năng mới đã PASS phần cứng. Các host test không chạy ELF trên CPU Nios V.
