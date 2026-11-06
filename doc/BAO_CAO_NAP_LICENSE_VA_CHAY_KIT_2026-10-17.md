# Cài license và chạy SoC IRQ trên DE2-115 — 17/10/2026

Đã build hai bitstream `build/images/shell.sof`, `demo.sof`, nạp thành công vào
FPGA và kiểm tra UART/IRQ thực tế. Đây là kết quả trên kit, bổ sung cho lần
kiểm chứng offline trong `HUONG_DAN_NIOSV_IRQ_DEMO.md`.

## License và môi trường

- File đã có sẵn: `~/.altera/license.dat`, 1.727 byte; không đưa file vào repo.
- Có feature `6AF7_D036` và `6AF8_D036`, vendor `alterad`, hết hạn 16/10/2027.
- `.bashrc` đã có khai báo license; không thêm dòng trùng.
- Phiên công cụ ban đầu chỉ kế thừa license Questa. Đã sửa
  `scripts/toolchain_env.sh` để tự thêm license Nios V ở đầu `LM_LICENSE_FILE`
  nếu file tồn tại, tránh thêm trùng và giữ đường dẫn license khác.
- Full build đã thực sự checkout được license: không còn warnings 24850,
  115003/115005; Assembler sinh `.sof`, 0 errors/0 warnings.

Không thay đổi RTL, CPU, map địa chỉ hay gán chân trong lần chạy này. Các thay
đổi mới là nhận license trong script và thêm script kiểm tra trên phần cứng.

## Thiết bị thực tế

- USB-Blaster `[3-11]`, JTAG ID `0x020F70DD`.
- Programmer dùng đúng device `EP4CE115F29`, configuration succeeded.
- Silicon Labs CP2102: `/dev/ttyUSB0`, alias bền vững:
  `/dev/serial/by-id/usb-Silicon_Labs_CP2102_USB_to_UART_Bridge_Controller_0001-if00-port0`.
- Người dùng dùng USB–UART trên board ESP32, đã xác nhận chung GND và EN nối GND.
- Chiều tín hiệu FPGA vẫn giữ: RXD=AB22/GPIO[0], TXD=AC15/GPIO[1].
  Nhãn RX/TX trên sơ đồ ngoài cần đọc theo phía thiết bị; không đổi chân trong QSF.

Khi dùng chân có nhãn RX0/TX0 trên board ESP32, cần phân biệt chúng với TX/RX
của chip CP2102. Kiểm tra echo thực tế dưới đây xác nhận đường nối hiện tại hoạt
động; không yêu cầu đảo dây sau khi đã PASS. EN nối GND giúp chip ESP32 không
chạy và phát lên UART chung. Không nạp/chỉnh firmware ESP32.

## Build và timing

Chạy lại `./scripts/build_soc.sh` từ RTL hiện tại; exit 0.

- Generate Qsys, BSP mới, hai ELF/HEX: PASS.
- Quartus full compile: 0 errors, 28 warnings; không có lỗi license.
- Assembler cho shell/demo: 0 errors, 0 warnings.
- Kiểm tra generated RTL/chân/map: PASS.
- Đường IRQ sau fitting tới `A0_plat_irq_vec[0]`: PASS, slack +15,528 ns.
- CLOCK_50: worst setup +5,410 ns, worst hold qua corner +0,148 ns.
- 4.139 LE, 2.258 registers, 527.632 memory bits, 49 chân.
- Vẫn có các cảnh báo vendor, truncation chia baud với giá trị hợp lệ tại 50 MHz,
  drive strength/slew mặc định và ngoại lệ JTAG đã giải thích ở hướng dẫn trước.
  Không gọi đây là thiết kế không có cảnh báo.

Hai image có RAM khởi động khác nhau, SHA-256:

```text
demo.sof  1dc279f7e549de29b80c7fdbb0cc73ae201a8b731e7acc4f15c6b007f53d6a47
shell.sof 38bcc4d4179897fbe54a25dc401353a7a7f3fd6f98eb4a64407444966d7d3880
```

## Kiểm tra demo trên kit

Đã nạp bằng Quartus Programmer, báo configuration succeeded, 0 errors/0 warnings.
Người dùng xác nhận trực tiếp HEX3–HEX2 đang đếm.

Script `scripts/check_irq_hardware.py` mở cổng serial 9600 8N1 và JTAG console,
gửi byte kiểm tra, so byte echo chính xác, đối chiếu record RX với ISR/timer.
Không dùng riêng việc echo để kết luận IRQ chạy.

Các lượt đã PASS:

- Mẫu đơn `00`, `55`, `AA`, `41`, `FF`, `31`: echo đúng từng byte.
- Pause/resume qua JTAG: giữ 49 rồi tiếp tục 51; sau một lần nạp mới giữ 04 rồi
  tiếp tục 05. Thời gian chờ mỗi lần kiểm tra khoảng 2,2 giây, trong đó có khoảng
  1 giây giữ sau byte cuối; số giây tăng 1 hoặc 2 tùy phần giây được giữ lại.
- Trong lúc đồng hồ giữ giá trị, `ticks` và số lần ISR tiếp tục tăng.
- Chuỗi `xyz`, burst 95 ký tự ASCII, burst 1.024 byte nhị phân gồm đủ 00–FF
  lặp bốn lần: so khớp toàn bộ, không chỉ kiểm tra một phần đầu.
- Ba lượt kiểm tra đầy đủ đều PASS, trong đó có hai lượt sau khi nạp mới.
- Lượt cuối có kiểm tra quay vòng: record trước `seconds=0000003B` (59),
  `ticks=00001919` (6.425); sau đó `seconds=00000001` (01),
  `ticks=00001A74` (6.772). Bộ đếm đi qua 60/00, timer không reset.
- Kết thúc để FPGA chạy **demo.sof**, không phải shell. Đã đóng cổng serial và
  JTAG của các script kiểm thử; người dùng có thể mở terminal.

**Ghi nhận lỗi đầu tiên:** lần thử ngay sau nạp đầu gửi `A` nhưng đọc được `FF`;
ISR cũng ghi nhận `FF`. Không sửa RTL để che lỗi này. Sau đó sáu mẫu chẩn đoán,
kiểm tra đầy đủ và lần nạp lại đều PASS. Chưa xác định được nguyên nhân byte sai
đầu tiên, nên không khẳng định đã sửa triệt để một lỗi startup. Script hiện ghi
lại dữ liệu đến trước payload kiểm thử, rồi đối chiếu riêng payload đã biết;
không tự retry để biến một payload sai thành PASS.

Người dùng xác nhận EN nối GND, do đó không kết luận ESP32 đang chạy là nguyên
nhân. Thao tác mở cổng có thể tác động DTR/RTS trên board USB–UART, theo
[tài liệu Espressif](https://docs.espressif.com/projects/esptool/en/latest/esp32/advanced-topics/boot-mode-selection.html),
nhưng chưa có phép đo chứng minh liên hệ với byte FF đã thấy.

JTAG log demo là best-effort: khi FIFO JTAG đầy, một phần dòng có thể bị cắt để
không chặn UART/đồng hồ. Điều này có xuất hiện trong log burst; không coi dòng
log thiếu là mất dữ liệu UART. Burst UART được so sánh đầy đủ qua cổng serial.

## Kiểm tra shell trên kit

Đã nạp `shell.sof` và kiểm tra cả hai chiều:

```text
PASS PC -> shell echo: b'IRQ-shell-test\r\n'
PASS shell IRQ/RX/dropped/errors/overruns: (46, 15, 0, 0, 0)
PASS JTAG shell -> PC: b'NIOS-to-PC\r\n'
```

Log CLI:

```text
UART ISR calls: 46 RX: 15 dropped: 0 errors: 0 overruns: 0
```

ISR count có cả các lần phục vụ TX nên không cần bằng số byte RX.
Shell JTAG vẫn dùng console polling riêng; RX/TX APB UART dùng driver IRQ.

## Cách chạy lại

```bash
# Build hoàn toàn, không cần source ~/.bashrc thủ công
./scripts/build_soc.sh

# Nạp demo và mở JTAG console
./run_irq_demo.sh

# Terminal thứ hai: UART trên board ESP32
./run_terminal_pc.sh /dev/ttyUSB0
```

Hoặc đóng cả hai terminal rồi kiểm tra tự động:

```bash
python3 scripts/check_irq_hardware.py /dev/ttyUSB0 --wrap-check
```

Script tự đóng kết nối khi kết thúc; chương trình trên FPGA vẫn chạy. Khi mở
Terminal 2, tắt local echo để ký tự hiện ra là echo từ FPGA. Không cho hai app
cùng chiếm một cổng serial/JTAG.

Các `.sof` được nạp vào SRAM FPGA; khi tắt nguồn cần nạp lại. Chưa thực hiện
nạp cấu hình vào flash EPCS để tự boot sau mất nguồn.

## Bằng chứng và giới hạn

Log trong `build/logs/`: `quartus.log`, `asm-demo.log`, `asm-shell.log`,
`program-demo*.log`, `program-shell.log`, `hardware-demo-round1.log`,
`hardware-demo-round2.log`, `hardware-demo-final.log`, `hardware-demo-*-jtag.log`,
`hardware-shell-check.log`, `hardware-shell-jtag.log`, `fitted-irq-path.rpt`.

Chưa đo điện áp/baud bằng oscilloscope, chưa kiểm chứng mọi tình huống reset
giữa khung, tháo/cắm nóng và stress dài giờ. Có một byte sai ban đầu chưa tái lập.
Các kết luận PASS áp dụng cho đúng các lượt đo và kịch bản ghi trong báo cáo.
