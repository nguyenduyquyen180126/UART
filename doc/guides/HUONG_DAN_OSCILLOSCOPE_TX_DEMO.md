# Ba chế độ demo và đo oscilloscope trên TX

## Chọn demo ở Terminal 1

Chạy tại thư mục `/home/vietanh/Downloads/code/UART/UART`. Mỗi lần chọn **một**
script. Đóng JTAG terminal cũ bằng Ctrl+C trước khi chạy script khác.

| Chế độ | Lệnh Terminal 1 | Image |
|---|---|---|
| Truyền bình thường, shell/config | `./run_shell_demo.sh` | `shell.sof` |
| Demo IRQ, đồng hồ tạm dừng/echo | `./run_irq_demo.sh` | `demo.sof` |
| Đo sóng TX, lặp ký tự A | `./run_scope_demo.sh` | `scope.sof` |

Các script nạp SOF qua USB-Blaster rồi mở JTAG terminal. Firmware đã nằm trong
on-chip RAM của từng SOF, không cần nạp ELF riêng. `build_and_run.sh`,
`flash_fpga.sh`, `run_terminal_jtag.sh` và script IRQ cũ vẫn dùng được.
Ba chế độ dùng cùng một phần cứng Nios V/m; mỗi lần nạp chọn một firmware.
Chúng không chạy đồng thời, không ghi cấu hình khởi động vào flash.

Build lại cả ba nếu vừa sửa nguồn:

```bash
./scripts/build_soc.sh
# hoặc build rồi chọn scope ngay:
./run_scope_demo.sh --build
```

Script scope và shell tự build nếu chưa có image. Nếu nguồn thay đổi sau khi
build, cơ chế kiểm tra source manifest của `flash_fpga.sh` sẽ yêu cầu build lại;
không bỏ qua kiểm tra đó. Sau build đầy đủ, chuyển giữa ba demo chỉ cần nạp SOF,
không compile lại mỗi lần.

## Firmware riêng cho oscilloscope

Nguồn: `software/scope_demo.c`. Dùng driver IRQ hiện có; không sửa driver, RTL,
Qsys, địa chỉ, chân, `main.c` hoặc `software/irq_demo.c` để thêm chế độ này.
Cấu hình cố định **9600 baud, 8 data bit, no parity, 1 stop bit**.

Luồng chính đúng yêu cầu có vòng `while`, print một ký tự cố định và delay:

```c
while (1) {
    scope_demo_cycle();
}

/* Nội dung scope_demo_cycle(): */
print_uart("A");
while (uart_irq_tx_busy()) discard_rx();
delay_ms(5);
```

`print_uart("A")` đi qua driver APB UART ra chân TX thật. Không dùng `printf("A")`
vì stdout của BSP hiện tại là JTAG UART, sẽ không tạo sóng trên TX cần đo.
Không thêm `\r`, `\n`, banner hay echo vào đường UART TX; banner chỉ gửi qua JTAG
và không chờ terminal. Dữ liệu RX được bỏ qua, không làm thay đổi mẫu A phát ra.

Delay dùng bộ đếm `mtime` 64 bit của CPU hiện có và bắt đầu **sau khi TX-complete
IRQ báo đã truyền hết stop bit**. Delay ít nhất 5 ms; CPU chủ động chờ trong demo
đơn giản này, không thay timer ISR của demo IRQ. HEX1–HEX0 hiển thị `41`, HEX3–HEX2
hiển thị `00`. Không có lệnh config runtime trong bản scope; cần shell/config
thì chọn lại script shell.

Sóng phát ngay sau khi nạp thành công, kể cả khi không mở JTAG terminal.
**Ctrl+C chỉ đóng JTAG terminal; CPU vẫn phát A.** Chuyển về shell/IRQ bằng script
tương ứng, hoặc tắt nguồn kit để kết thúc chế độ này. KEY[0] reset sẽ khởi động
lại cùng demo và tiếp tục phát.

## Nối oscilloscope

- Đầu probe CH1: **UART_TXD = PIN_AC15 = GPIO[1]** theo `fpga/NIOS.qsf`.
- Kẹp mass probe: GND của DE2-115. Nếu giữ ESP32/USB–UART thì vẫn chung GND.
- Đây là tín hiệu logic khoảng **0–3,3 V**, không phải tín hiệu điện áp RS-232.
- Dùng probe ×10, đặt attenuation ×10 trên oscilloscope, DC coupling, ngõ vào
  **1 MΩ**, không chọn termination 50 Ω trên chân GPIO này.
- Không nối TX của USB–UART vào cùng TX của FPGA. Chân TX FPGA có thể tiếp tục
  nối vào **RX input** của USB–UART và đồng thời được probe đo.
- Scope demo không cần Terminal 2, không cần gửi dữ liệu từ PC. Có thể tháo
  USB–UART và chỉ dùng USB-Blaster cùng oscilloscope.

Nếu muốn Terminal 2 nhận các chữ `AAAA...` để đối chiếu, mở đúng cấu hình:

```bash
./run_terminal_pc.sh /dev/ttyUSB0 9600 8N1
```

Không dùng cấu hình 19200 8E2 của lần demo shell trước cho bản scope này.

## Thiết lập để thấy một khung đẹp, ổn định

| Thiết lập | Giá trị gợi ý |
|---|---|
| Vertical | 1 V/div, DC, probe ×10 |
| Timebase | **200 µs/div** để thấy trọn khung ~1,042 ms |
| Trigger | Edge, falling, source CH1 |
| Trigger level | Khoảng **1,5 V** |
| Trigger mode | Normal hoặc Single |
| Trigger position | Khoảng 10–20% bên trái màn hình |
| Trigger holdoff, nếu có | Khoảng **2 ms**, để bỏ các cạnh xuống bên trong khung |
| Sample rate | ≥10 MSa/s nếu máy hỗ trợ |
| UART decode, nếu có | 9600 / 8N1 / LSB first / non-inverted |

Có thể chỉnh 1 ms/div để thấy cả khung lẫn khoảng nghỉ. 100 µs/div phù hợp zoom
chi tiết bit nhưng trên màn hình 10 division sẽ không chứa trọn cả khung 10 bit.
Ký tự A có nhiều cạnh xuống: nếu không holdoff hoặc serial trigger, oscilloscope
có thể trigger vào data bit thay vì start bit. Kiểm tra đúng vị trí start trước
khi đánh giá khung. Nếu máy hỗ trợ UART trigger, chọn data `0x41`.

## Sóng dự kiến

`A = 0x41`, truyền LSB trước:

| Phần | Idle | Start | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | Stop | Nghỉ |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Mức logic | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 1 |

Tại clock 50 MHz, RTL dùng `floor(50_000_000/9600) = 5208` clock/bit:

- Một bit: **104,160 µs**; baud tính từ bộ chia khoảng **9600,61 baud**.
- Một khung 10 bit: **1,041600 ms**.
- Khoảng nghỉ thêm sau khung: **ít nhất 5 ms**.
- Chu kỳ start-to-start: khoảng **6,042 ms** cộng độ trễ xử lý CPU/IRQ nhỏ;
  tốc độ lặp khoảng **165,5 khung/s**.

Không dùng khoảng cách giữa hai cạnh bất kỳ làm bit time: các data bit 0 liên
tiếp tạo một đoạn low dài 5 bit. Muốn đo một bit, dùng đoạn high D0 hoặc D6.
Sai số clock thực của kit và thời gian xử lý khiến số đo không trùng tuyệt đối
với thời gian lý tưởng trong mô phỏng.

## Kiểm chứng

```bash
make test_scope_demo
make test_runtime_config test_uart_config test_irq_driver test_demo_clock
```

- Host test chạy hàm chu kỳ **thật của firmware scope**: chỉ nhận byte A,
  xử lý queue retry, bỏ RX và chờ ≥5 ms sau TX complete trong bốn lần lặp.
- RTL test kích APB vào `apb_uart` thật: bốn khung A 9600 8N1, đúng bit và stop,
  khoảng nghỉ ≥5 ms. Đây không phải mô phỏng Nios chạy ELF.
- Waveform RTL: `build/scope_demo_tx.vcd`; log: `build/logs/scope-tests.log`.
- Build ba ELF/HEX/SOF và kiểm tra lại đường IRQ, địa chỉ, chân bằng script SoC.
- Chưa đo bằng oscilloscope vật lý trong lần bổ sung này; số timing trên là
  kết quả kiểm chứng mô phỏng và bộ chia RTL, không gắn nhãn là số đo trên kit.

Kết quả build lần bổ sung 17/10/2026: đã tạo đủ `shell.sof`, `demo.sof`,
`scope.sof`, ba ELF/HEX; Assembler có license hoàn tất 0 errors/0 warnings.
Kiểm tra SoC, các kiểm thử trên và kiểm tra launcher riêng shell/scope đều PASS.
Hash xác nhận nguồn shell, demo IRQ, driver UART, top/QSF/Qsys không thay đổi
so với trước lần bổ sung. Bản ghi: [SCOPE_DEMO_2026-10-17.txt](verification/SCOPE_DEMO_2026-10-17.txt).
