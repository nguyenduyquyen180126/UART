# BÁO CÁO KỸ THUẬT: KHẮC PHỤC LỖI & ĐỒNG BỘ TOÀN DIỆN HỆ THỐNG FIFO UART (C FIRMWARE + PLATFORM DESIGNER + QUARTUS DE2-115)

---

## 1. Mục Đích & Bối Cảnh
Tài liệu này ghi lại toàn bộ danh mục các lỗi kỹ thuật, điểm nghẽn hiệu năng và sai lệch cấu hình phần cứng/phần mềm phát hiện được sau khi dự án bổ sung **Hardware FIFO** (nhánh TX và RX) vào module `apb_uart`, cùng quy trình khắc phục và đồng bộ hóa chuẩn xác 100% để đảm bảo hệ thống vận hành ổn định trên kit **Terasic DE2-115**.

---

## 2. Danh Mục Các Lỗi & Vấn Đề Kỹ Thuật Được Phát Hiện

### 2.1. LỖI NGHIÊM TRỌNG (CRITICAL): Ghi vào địa chỉ `UART_CTRL_REG` (0x0C) gây Bus Error / SLVERR
* **Mô tả hiện tượng cũ trong C:**
  Trong hàm `uart_putc()` và `apb_uart_putc()`, mã C cũ thực hiện:
  ```c
  IOWR_32DIRECT(UART_TX_DATA_REG, 0, (uint32_t)c);
  IOWR_32DIRECT(UART_CTRL_REG, 0, 0x01); // <-- KÍCH XUNG start_tx
  ```
* **Bản chất lỗi phần cứng:**
  1. Trong kiến trúc mới có Hardware FIFO ([`rtl/uart_regs.v`](../rtl/uart_regs.v)), thanh ghi `ADDR_CTRL` (0x0C) đã bị **loại bỏ hoàn toàn**.
  2. Logic kiểm tra bus hợp lệ trong `uart_regs.v`:
     ```verilog
     wire write_legal = (addr_tx && !tx_fifo_full) ||
                        (addr_cfg && uart_idle)     ||
                        (addr_ier);
     assign reg_ack_err = (reg_pwrite && !write_legal) || (reg_pread && !read_legal);
     ```
     Địa chỉ `0x0C` không nằm trong danh sách `write_legal` $\rightarrow$ `reg_ack_err = 1`.
  3. Tín hiệu này kéo `pslverr = 1` trên bus APB $\rightarrow$ Cầu Avalon-to-APB trả về phản hồi `avl_response = 2'b10 (SLVERR)`.
  4. Trên bộ xử lý RISC-V (Nios V), phản hồi lỗi bus này kích hoạt ngoại lệ **Store Access Fault Exception**, khiến CPU bị dừng hoặc treo ngay sau khi gửi ký tự đầu tiên!
* **Giải pháp khắc phục:**
  - Xóa bỏ định nghĩa `#define UART_CTRL_REG (APB_UART_0_BASE + 0x0C)`.
  - Xóa bỏ hoàn toàn lệnh `IOWR_32DIRECT(UART_CTRL_REG, ...)`.
  - Khi có Hardware FIFO, phần cứng kết nối trực tiếp `wire start_tx = !tx_fifo_empty;`. Do đó, chỉ cần CPU ghi byte vào `UART_TX_DATA_REG` (0x00), byte sẽ tự động nạp vào FIFO và phần cứng tự động phát ra chân TX mà không cần CPU can thiệp.

---

### 2.2. ĐIỂM NGHẼN HIỆU NĂNG (BOTTLENECK): Chờ `UART_STT_TX_DONE` (Bit 0) thay vì `UART_STT_TX_FULL` (Bit 4)
* **Mô tả hiện tượng cũ trong C:**
  ```c
  while (((IORD_32DIRECT(UART_STT_REG, 0) & UART_STT_TX_DONE) == 0) && --timeout);
  ```
* **Bản chất kỹ thuật:**
  1. Trong `uart_regs.v`:
     - **Bit 0 (`tx_ready`):** Bằng `1` khi **TX FIFO rỗng hoàn toàn VÀ UART Transmitter đã hoàn tất Stop bit**.
     - **Bit 4 (`tx_fifo_full`):** Bằng `1` khi **TX FIFO đã nạp đầy 16 byte**.
  2. Nếu phần mềm chờ Bit 0 lên 1 mới gửi byte kế tiếp, CPU vẫn bị khóa (block) ~1.04 ms cho mỗi ký tự (ở baud 9600). Điều này làm **mất hoàn toàn giá trị của Hardware TX FIFO**!
* **Giải pháp khắc phục:**
  - Cập nhật hàm `uart_putc()` chỉ kiểm tra Bit 4:
    ```c
    while (((IORD_32DIRECT(UART_STT_REG, 0) & UART_STT_TX_FULL) != 0) && --timeout);
    ```
  - Miễn là FIFO chưa đầy (Bit 4 == 0), CPU ghi dữ liệu thẳng vào `UART_TX_DATA_REG` trong 1 chu kỳ APB (~20 ns) rồi thoát ngay.
  - Khi gửi chuỗi (như `uart_puts`), CPU bắn cả burst 16 ký tự vào FIFO chỉ trong ~320 ns, giải phóng 99.9% thời gian CPU cho các tác vụ khác.

---

### 2.3. VẤN ĐỀ XỬ LÝ NGẮT RX: Nguy cơ Interrupt Thrashing do đọc đơn byte
* **Mô tả hiện tượng cũ trong C:**
  Trong hàm ngắt `apb_uart_isr()` cũ:
  ```c
  if (stt & UART_STT_RX_DONE) {
      uint8_t ch = (uint8_t)(IORD_32DIRECT(UART_RX_DATA_REG, 0) & 0xFF);
      ringbuf_put(ch);
  }
  ```
* **Bản chất kỹ thuật:**
  - RX FIFO phần cứng có độ sâu 16 byte. Cờ `UART_STT_RX_DONE` (Bit 1) nối trực tiếp từ `!rx_fifo_empty`.
  - Khi PC gửi tới 1 chuỗi nhanh (burst 5-10 ký tự), dùng `if` chỉ đọc 1 byte rồi thoát ISR. Vì trong FIFO vẫn còn dữ liệu, chân ngắt `irq` vẫn giữ mức cao $\rightarrow$ CPU phải liên tục nhảy vào/ra ISR hàng chục lần, tiêu tốn xung nhịp lưu/phục hồi ngữ cảnh thanh ghi.
* **Giải pháp khắc phục:**
  - Đổi sang vòng lặp `while` để hút cạn toàn bộ dữ liệu đang có trong Hardware RX FIFO nạp vào Ring Buffer RAM trong đúng 1 lần ngắt:
    ```c
    while (IORD_32DIRECT(UART_STT_REG, 0) & UART_STT_RX_DONE) {
        uint8_t ch = (uint8_t)(IORD_32DIRECT(UART_RX_DATA_REG, 0) & 0xFF);
        ringbuf_put(ch);
    }
    ```
  - Áp dụng tương tự cho hàm fallback `uart_has_data()` khi chạy ở chế độ Polling.

---

### 2.4. VẤN ĐỀ QUARTUS / PLATFORM DESIGNER: Thiếu file trong `_hw.tcl` và thư mục IP bị lệch
* **Phát hiện:**
  1. Trong file [`apb_uart_hw.tcl`](../apb_uart_hw.tcl) gốc: danh sách file tổng hợp (`QUARTUS_SYNTH`) **hoàn toàn chưa có `sync_fifo.v`**, thiếu `tx_baud_gen.v` và `rx_baud_gen.v` (thay vào đó là file `baud_gen.v` cũ).
  2. Thư mục IP Component của Platform Designer (`/home/vietanh/altera_lite/24.1std/ip/apb_uart/`) vẫn chứa mã nguồn cũ: chứa file `reg_uart.v`, không có `sync_fifo.v` và `uart_regs.v`.
  3. Nếu biên dịch Quartus mà không cập nhật, Platform Designer sẽ tổng hợp hệ thống không có FIFO hoặc báo lỗi thiếu module `sync_fifo`.
* **Giải pháp khắc phục:**
  - Cập nhật [`apb_uart_hw.tcl`](../apb_uart_hw.tcl) bổ sung đầy đủ `sync_fifo.v`, `tx_baud_gen.v`, `rx_baud_gen.v`.
  - Xóa bỏ `reg_uart.v` cũ và đồng bộ toàn bộ file từ `rtl/` sang `/home/vietanh/altera_lite/24.1std/ip/apb_uart/`.
  - Chạy `qsys-generate` để sinh lại 82 file HDL synthesis trong hệ thống Platform Designer `system.qsys`.

---

### 2.5. VẤN ĐỀ NIOS V BSP: Bảo vệ cờ IRQ khi hệ thống chưa cấu hình bộ điều khiển ngắt
* **Phát hiện:**
  - Trong `software/bsp/system.h`, khi SoC chưa kích hoạt bộ điều khiển ngắt cho Nios V, macro được định nghĩa:
    `#define APB_UART_0_IRQ -1`
  - Nếu dùng `#ifdef APB_UART_0_IRQ`, biểu thức vẫn tính là TRUE, dẫn đến việc CPU gọi `alt_ic_isr_register(-1, -1, ...)` với ID âm không hợp lệ.
* **Giải pháp khắc phục:**
  - Sửa lại điều kiện tiền xử lý:
    ```c
    #if defined(APB_UART_0_IRQ) && (APB_UART_0_IRQ >= 0)
    ```
  - Khi IRQ chưa được kết nối, hệ thống tự động chạy cơ chế Polling Fallback an toàn 100%, không gây crash chương trình.

---

### 2.6. LỖI TREO CỨNG CPU (HANG): `jtag_putc` chờ `WSPACE > 0` vô hạn khi Terminal 1 chưa mở
* **Mô tả hiện tượng cũ trong C:**
  ```c
  void jtag_putc(char c) {
      uint32_t ctrl;
      do {
          ctrl = IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE);
      } while ((ctrl & ALTERA_AVALON_JTAG_UART_CONTROL_WSPACE_MSK) == 0);
      IOWR_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE, (uint32_t)c);
  }
  ```
* **Bản chất kỹ thuật:**
  1. Trong IP JTAG UART của Altera, FIFO phát phần cứng có dung lượng 64 byte. Trường `WSPACE` (bit 31:16) thể hiện số ô còn trống trong FIFO này.
  2. Khi kit DE2-115 vừa khởi động, CPU thực thi `print_banner()` gửi chuỗi chào mừng dài gần 600 byte.
  3. Nếu người dùng **chưa mở cửa sổ Terminal 1 (`./run_terminal_jtag.sh`)** hoặc mở Terminal 2 (PC) trước, host PC sẽ không kéo dữ liệu từ JTAG FIFO.
  4. Sau khi ghi đủ 64 byte đầu tiên, `WSPACE` trở về 0. Vòng lặp `do ... while` của `jtag_putc` sẽ **quay vô tận (Deadlock)**, làm CPU Nios V bị "đóng băng" ngay tại thời điểm boot, không bao giờ chạy đến vòng lặp chính `while (1)`!
* **Giải pháp khắc phục:**
  - Bổ sung bộ đếm thời gian chờ (**Software Timeout**):
    ```c
    void jtag_putc(char c) {
        uint32_t timeout = 50000;
        uint32_t ctrl;
        do {
            ctrl = IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE);
            if ((ctrl & ALTERA_AVALON_JTAG_UART_CONTROL_WSPACE_MSK) != 0) {
                IOWR_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE, (uint32_t)c);
                g_stats.jtag_tx_bytes++;
                return;
            }
        } while (--timeout);
    }
    ```
  - Khi Terminal JTAG đang mở: `WSPACE > 0` thỏa mãn ngay chu kỳ đầu tiên (0 ns trễ).
  - Khi Terminal JTAG chưa mở hoặc bị ngắt: CPU tự động hủy ký tự sau timeout ngắn, tiếp tục vận hành luồng APB UART mượt mà, triệt tiêu 100% nguy cơ treo kit.

---

### 2.7. HIỆN TƯỢNG NHÂN ĐÔI DÒNG MỚI (DOUBLE CRLF) TRÊN TERMINAL PC & PROMPT TRÊN JTAG
* **Bản chất kỹ thuật:**
  - Khi người dùng nhấn phím Enter trên PC (`picocom`), máy tính thường phát liên tiếp 2 ký tự mã ASCII: `\r` (Carriage Return, 0x0D) và `\n` (Line Feed, 0x0A).
  - Khi nhận `\r`, hàm dội lại chuỗi `\r\n` về PC. Ngay 1 mili-giây sau khi `\n` tới, hàm lại dội tiếp `\r\n` lần nữa, làm con trỏ màn hình PC bị nhảy cách 2 dòng trống.
  - Hiện tượng tương tự xảy ra trên JTAG Shell: `\r` kích hoạt thực thi lệnh và in prompt `NIOS-V:/> `, rồi `\n` tới lại được hiểu như một lệnh rỗng khiến hệ thống in thêm một prompt nữa.
* **Giải pháp khắc phục:**
  - Bổ sung biến theo dõi ký tự trước đó: `s_prev_pc_char` trên kênh PC và `prev_jtag_ch` trên kênh JTAG.
  - Nếu ký tự hiện tại là `\n` và ký tự ngay trước đó là `\r`, phần mềm lập tức bỏ qua, đảm bảo hiển thị đúng 1 dòng mới chuẩn xác.

---

### 2.8. LỖI MẤT KÝ TỰ ĐANG GÕ TRÊN JTAG CLI KHI CÓ TIN NHẮN ĐẾN TỪ PC
* **Bản chất kỹ thuật:**
  - Trong kiến trúc 2 chiều, người dùng trên Terminal 1 có thể đang gõ dở một câu lệnh (ví dụ `stat` trong lệnh `status`).
  - Đúng lúc đó, PC trên Terminal 2 gửi một chuỗi văn bản xuống. Hàm `handle_pc_rx_char` sẽ in dòng `[Incoming from PC (APB)]: ...` kèm prompt `NIOS-V:/> `.
  - Người dùng nhìn vào màn hình thấy mất trắng các ký tự `stat` mình vừa gõ, gây hoang mang trong quá trình demo.
* **Giải pháp khắc phục:**
  - Khi in thông điệp từ PC, firmware kiểm tra `if (cmd_idx > 0)`.
  - Nếu người dùng đang gõ dở lệnh, firmware lập tức in lại prompt `NIOS-V:/> ` và in lại toàn bộ chuỗi ký tự dở dang `cmd_buf[0..cmd_idx-1]`, giúp người dùng tiếp tục gõ lệnh bình thường.

---

### 2.9. NGUY CƠ CRASH CPU KHI LỆNH CLI `poke` GHI VÀO OFFSET KHÔNG HỢP LỆ (0x0C)
* **Bản chất kỹ thuật:**
  - Lệnh `poke <offset> <val>` cho phép can thiệp thanh ghi APB trực tiếp từ Terminal 1.
  - Vì phần cứng RTL [`rtl/uart_regs.v`](../rtl/uart_regs.v) đã gỡ bỏ offset `0x0C` (`UART_CTRL_REG`), nếu người dùng thử nghiệm gõ `poke 0x0C 1`, tín hiệu `reg_ack_err = 1` sẽ kích hoạt `pslverr = 1` $\rightarrow$ Nios V gặp Bus Exception và sập hệ thống.
* **Giải pháp khắc phục:**
  - Bổ sung chốt bảo vệ kiểm tra `reg_off`: Chặn mọi thao tác ghi vào `0x0C` hoặc các offset vượt quá không gian ngoại vi `0x14`, in thông báo cảnh báo thay vì để CPU bị lỗi bus.

---

### 2.10. LỖI LỆCH FILE HEX ON-CHIP RAM TRONG QUY TRÌNH NẠP BITSTREAM SOF
* **Bản chất kỹ thuật:**
  - Khi biên dịch C bằng CMake trong `software/`, file hex sinh ra là `software/build/onchip_memory2_0.hex`.
  - Tuy nhiên, lệnh `quartus_cdb --update_mif NIOS` lại đọc file `system_onchip_memory2_0.hex` tại thư mục gốc của Quartus.
  - Nếu quên sao chép file hex mới nhất sang thư mục gốc, lệnh cập nhật bitstream sẽ tiếp tục nhúng file hex cũ vào FPGA, khiến phần mềm chạy trên kit không khớp với mã nguồn C vừa sửa.
* **Giải pháp khắc phục:**
  - Tự động hóa lệnh copy `cp software/build/onchip_memory2_0.hex system_onchip_memory2_0.hex` và `onchip_memory2_0.hex` trước khi chạy `quartus_cdb --update_mif NIOS` và `quartus_asm`.

---

## 3. Bảng Đối Chiếu Bản Đồ Thanh Ghi APB UART (Sau Khi Có FIFO)

| Offset | Tên Thanh Ghi | Quyền | Mô Tả Chức Năng Sau Khi Nâng Cấp |
| :---: | :--- | :---: | :--- |
| `0x00` | **`UART_TX_DATA_REG`** | WO | Ghi 8-bit dữ liệu vào **TX FIFO (16x8)**. Tự động kích phát nối tiếp. |
| `0x04` | **`UART_RX_DATA_REG`** | RO | Đọc dữ liệu từ đỉnh **RX FIFO (16x9)**. Bit `[7:0]`: data, Bit `[8]`: error byte. Tự động pop 1 byte và hạ cờ/ngắt khi FIFO rỗng. |
| `0x08` | **`UART_CFG_REG`** | RW | Cấu hình baudrate (`[6:5]`), parity (`[4:3]`), stop bit (`[2]`), data bits (`[1:0]`). Chỉ ghi khi UART Idle. |
| ~~`0x0C`~~ | ~~`UART_CTRL_REG`~~ | - | **ĐÃ BỎ (KHÔNG ĐƯỢC TRUY CẬP)**. |
| `0x10` | **`UART_STT_REG`** | RO | Thanh ghi trạng thái 6-bit:<br/>• **Bit 0 (`TX_DONE`):** 1 = TX rảnh & TX FIFO rỗng.<br/>• **Bit 1 (`RX_READY`):** 1 = Có ít nhất 1 byte trong RX FIFO (`!rx_fifo_empty`).<br/>• **Bit 2 (`BYTE_ERR`):** 1 = Lỗi Parity/Frame của byte tại đỉnh RX FIFO.<br/>• **Bit 3 (`OVERRUN`):** 1 = Lỗi tràn (PC gửi khi RX FIFO đã đầy 16 byte).<br/>• **Bit 4 (`TX_FULL`):** 1 = TX FIFO đầy 16 byte.<br/>• **Bit 5 (`RX_FULL`):** 1 = RX FIFO đầy 16 byte. |
| `0x14` | **`UART_IER_REG`** | RW | Thanh ghi cho phép ngắt:<br/>• Bit 0: Cho phép ngắt nhận RX (`!rx_fifo_empty`).<br/>• Bit 1: Cho phép ngắt phát TX (`tx_ready`).<br/>• Bit 2: Cho phép ngắt tràn Overrun. |

---

## 4. Tóm Tắt Các Bước Đã Thực Hiện

1. **Cập nhật mã nguồn C:**
   - [`main.c`](../main.c): Loại bỏ `UART_CTRL_REG`, cập nhật kiểm tra `UART_STT_TX_FULL`, nâng cấp ISR ngắt và fallback hút cạn RX FIFO.
   - [`software/main.c`](/home/vietanh/altera_lite/24.1std/software/main.c): Cập nhật tương ứng cho ứng dụng Full-Duplex Console Nios V.
2. **Biên dịch mã nhị phân Firmware Nios V:**
   - Biên dịch thành công `app.elf` và sinh lại `onchip_memory2_0.hex` (kích thước 20.18 KB, trống 43.22 KB RAM).
3. **Cập nhật định nghĩa Platform Designer:**
   - Sửa [`apb_uart_hw.tcl`](../apb_uart_hw.tcl) bổ sung `sync_fifo.v`, `tx_baud_gen.v`, `rx_baud_gen.v`.
   - Đồng bộ toàn bộ RTL sang `/home/vietanh/altera_lite/24.1std/ip/apb_uart/`.
4. **Tái tạo thiết kế phần cứng SoC (Platform Designer):**
   - Chạy `qsys-generate --synthesis=VERILOG` cập nhật toàn bộ 82 file tổng hợp phần cứng.
5. **Tổng hợp Bitstream Quartus:**
   - Chạy luồng biên dịch đầy đủ để sinh file `output_files/NIOS.sof` mới nhất chứa phần cứng FIFO.

---

## 5. Hướng Dẫn Thực Nghiệm Trên Kit DE2-115 (Khi Cắm Kit)

Khi bạn sẵn sàng cắm kit DE2-115 vào máy tính, thực hiện theo đúng các bước sau:

```bash
# Bước 1: Nạp file bitstream phần cứng vào FPGA (chỉ cần chạy script đã chuẩn bị sẵn)
./flash_fpga.sh

# Bước 2: Mở Terminal 2 (Giao tiếp APB UART với PC qua mạch USB2UART ngoài, baud 9600)
./run_terminal_pc.sh

# Bước 3 (Nếu dùng Dual Console): Mở Terminal 1 (Nios V Shell qua cáp nạp USB-Blaster)
./run_terminal_jtag.sh
```
