# HƯỚNG DẪN KIẾN TRÚC DUAL-CPU INTERCONNECT & NIOS-V INTERACTIVE SHELL

Tài liệu này trình bày chi tiết toàn bộ quy trình thiết kế, cơ chế hoạt động, luồng xử lý (flow), và nhật ký kinh nghiệm debug thực tế của hệ thống **Giao Tiếp 2 Chiều Giữa 2 CPU (PC CPU x86_64 và DE2-115 RISC-V SoC)** thông qua **Bus AMBA APB** và **JTAG UART**.

---

## 1. Tầm Nhìn Kiến Trúc: Tại Sao Phải Là Dual-CPU?

Trước đây, việc gạt công tắc `SW[7:0]` rồi nhấn nút `KEY[1]` để truyền 1 byte lên PC là một mô hình đơn giản. Tuy nhiên:
- Một mạch thuần phần cứng (máy trạng thái FSM Verilog) hoàn toàn làm được việc đó mà **không cần tới CPU Nios V**.
- Làm như vậy **chưa phát huy được sức mạnh của vi điều khiển 32-bit RISC-V** và **Bus AMBA APB** trong một hệ thống SoC (System-on-Chip).

### Kiến trúc mới (Phương án 1):
Hệ thống biến kit **DE2-115** thành một vi máy tính SoC độc lập với 2 giao diện truyền thông song song:
1. **Kênh Quản Trị & Điều Khiển (JTAG Console):** Nối qua cáp nạp USB-Blaster, mở màn hình dòng lệnh tương tác trực tiếp với CPU Nios V.
2. **Kênh Dữ Liệu Ngoại Vi (APB UART):** Nối qua header JP5 tới cổng COM của PC (`/dev/ttyUSB0`), cho phép 2 CPU trao đổi dữ liệu 2 chiều.

```mermaid
flowchart LR
    subgraph PC ["MÁY TÍNH (PC - CPU x86_64)"]
        T1["Terminal 1: Nios V Console<br>(juart-terminal)"]
        T2["Terminal 2: PC Serial App<br>(picocom /dev/ttyUSB0)"]
    end

    subgraph FPGA ["KIT TERASIC DE2-115 (CYCLONE IV E)"]
        subgraph SOC ["Hệ Thống Nios V SoC"]
            JUART["jtag_uart_0<br>(0x0001_0010)"]
            CPU["CPU Nios V/c<br>(RISC-V RV32I @ 50MHz)"]
            RAM["On-chip RAM 64KB<br>(0x0000_0000)"]
            BUS["Bus Interconnect<br>(AXI4 & AMBA APB)"]
            APBUART["apb_uart_0<br>(0x0002_0000)"]
            PIO["pio_0 (LED 7 thanh)<br>(0x0001_0000)"]

            CPU <--> BUS
            RAM <--> BUS
            BUS <--> JUART
            BUS <--> APBUART
            BUS --> PIO
        end
        HEX["2 LED 7 Thanh<br>(HEX1 - HEX0)"]
        PIO --> HEX
    end

    T1 <===>|Cáp USB-Blaster (JTAG)| JUART
    T2 <===>|Module USB-to-UART (JP5)| APBUART
```

---

## 2. Cơ Chế Hoạt Động Của Hệ Thống

### 2.1. Phân chia vai trò 2 Terminal trên PC
Khi chạy hệ thống, bạn mở **2 cửa sổ Terminal độc lập**:

| Đặc tính | Terminal 1 (Nios V Shell Console) | Terminal 2 (PC Serial Application) |
| :--- | :--- | :--- |
| **Đại diện cho** | **CPU Nios V (RISC-V trên FPGA)** | **CPU Máy Tính (PC x86_64)** |
| **Giao thức vật lý**| JTAG (Cáp USB-Blaster) | UART TTL (Module cắm header JP5) |
| **Địa chỉ bus SoC** | `0x0001_0010` (`jtag_uart_0`) | `0x0002_0000` (`apb_uart_0`) |
| **Lệnh khởi chạy** | `./run_terminal_jtag.sh` | `./run_terminal_pc.sh` |
| **Chức năng chính**| CLI Shell: Gõ lệnh `send <msg>`, `status`, `peek`, `poke`, `chat` | Nhập văn bản gửi xuống kit / Nhận phản hồi từ kit |

---

### 2.2. Luồng Dữ Liệu 2 Chiều Chi Tiết (Data Flow)

#### Chiều A: PC gửi dữ liệu xuống Kit (PC $\rightarrow$ DE2-115 Nios V)
1. Trên **Terminal 2**, người dùng gõ ký tự (ví dụ: `'H'`).
2. Tín hiệu nối tiếp chạy vào chân `PIN_AB22` (RX của `apb_uart`).
3. Khối `rx_uart.v` lấy mẫu 16x oversampling, gom đủ 8 bit và bật cờ `rx_done = 1`.
4. CPU Nios V đang chạy vòng lặp non-blocking, gọi hàm `apb_uart_has_data()` $\rightarrow$ nhận thấy cờ `rx_done` đang bật.
5. CPU đọc byte qua bus APB: `apb_uart_getc()` $\rightarrow$ phần cứng **tự động xóa cờ `rx_done` về 0**.
6. CPU đồng thời thực hiện 3 hành động:
   - **Hành động 1:** Xuất mã ASCII Hex ra 2 LED 7 đoạn `HEX1-HEX0` (`'H'` = `0x48` $\rightarrow$ HEX hiển thị `48`).
   - **Hành động 2:** Chuyển tiếp ngay lập tức lên **Terminal 1** qua JTAG UART: `[Incoming from PC (APB)]: 'H' (Hex: 0x48)`.
   - **Hành động 3:** Nếu bật cờ `echo_enabled`, CPU dội ngược lại ký tự `'H'` về Terminal 2.

#### Chiều B: Nios V gửi dữ liệu lên PC (DE2-115 Nios V $\rightarrow$ PC)
1. Trên **Terminal 1**, người dùng gõ lệnh:
   ```text
   NIOS-V:/> send Xin chao PC!
   ```
2. Bộ phân tích chuỗi CLI trong firmware Nios V nhận dạng tiền tố `send `.
3. Nios V duyệt qua từng ký tự của chuỗi `"Xin chao PC!\r\n"`:
   - Đọc cờ `tx_done` (bit 0 của `UART_STT_REG` tại `0x00020010`).
   - Ghi ký tự vào `UART_TX_DATA_REG` (`0x00020000`).
   - Kích xung `start_tx = 1` vào `UART_CTRL_REG` (`0x0002000C`).
4. Khối `tx_uart.v` phát từng frame nối tiếp ra chân `PIN_AC15` (TX) với tốc độ 9600 baud.
5. Trên **Terminal 2** của PC, dòng chữ `"Xin chao PC!"` xuất hiện ngay lập tức!

#### Chiều C: Chế độ Direct Chat Mode (`chat`)
- Khi gõ lệnh `chat` trên Terminal 1:
- CPU Nios V chuyển sang chế độ cầu nối trực tiếp: Mọi ký tự bạn gõ trên Terminal 1 sẽ được bắn thẳng qua bus APB sang Terminal 2 theo thời gian thực (nhấn phím `ESC` để thoát).

---

## 3. Kiến Trúc Firmware: Non-Blocking Multi-Channel Polling

Trong các ứng dụng nhúng giao tiếp nhiều cổng I/O, **tuyệt đối không được dùng hàm đọc chặn (Blocking Read)** như `getchar()`. Nếu CPU dừng chờ ở JTAG UART, nó sẽ bỏ lỡ dữ liệu đến từ APB UART và ngược lại.

Firmware sử dụng kiến trúc **Vòng lặp kiểm tra không chặn (Non-blocking Dispatcher Loop)**:

```c
while (1) {
    // 1. Kiểm tra không chặn kênh JTAG UART (Terminal 1)
    int c = jtag_getc_nonblock();
    if (c != -1) {
        // Đã có phím từ người dùng: đưa vào buffer dòng lệnh hoặc chuyển tiếp
        handle_jtag_input((char)c);
    }

    // 2. Kiểm tra không chặn kênh APB UART (Terminal 2)
    if (apb_uart_has_data()) {
        // Đã có byte từ PC: đọc qua APB, in lên Terminal 1 & xuất LED 7 thanh
        handle_apb_input();
    }
}
```

Nhờ thiết kế này, CPU Nios V chạy ở xung nhịp 50 MHz kiểm tra hàng triệu lần mỗi giây, đảm bảo:
- Phản hồi tức thời với độ trễ dưới **1 micro-giây**.
- Không bao giờ bị treo cứng hệ thống.

---

## 4. Danh Sách Lệnh Của Nios V Shell (Terminal 1)

Khi kết nối vào Terminal 1, bạn có một console quản trị SoC với các lệnh sau:

| Lệnh | Cú pháp ví dụ | Mô tả chức năng |
| :--- | :--- | :--- |
| **`help`** | `help` | Hiển thị menu danh sách hướng dẫn lệnh. |
| **`send`** | `send Hello World!` | Đóng gói chuỗi và gửi qua bus APB sang Terminal 2 của PC. |
| **`chat`** | `chat` | Bật/tắt chế độ gõ trực tiếp (Direct Chat). Gõ phím nào bay phím đó sang PC. Nhấn `ESC` để thoát. |
| **`status`**| `status` | Xem bảng thống kê số byte đã gửi/nhận qua APB & JTAG, trạng thái thanh ghi phần cứng. |
| **`peek`** | `peek 0x10` | Đọc giá trị thanh ghi phần cứng APB UART (Offset `0x10` = Thanh ghi Status). |
| **`poke`** | `poke 0x00 0x41` | Ghi trực tiếp giá trị vào thanh ghi phần cứng APB UART (Offset `0x00` = Ghi byte `'A'`). |
| **`hex`**  | `hex 0x59` | Đặt số hiển thị thủ công lên 2 đèn LED 7 đoạn `HEX1-HEX0`. |
| **`echo`** | `echo on` / `echo off` | Bật hoặc tắt tính năng tự động echo dữ liệu nhận từ PC về lại PC. |
| **`clear`**| `clear` | Xóa sạch màn hình Terminal JTAG. |

---

## 5. Nhật Ký Lỗi & Bài Học Kinh Nghiệm Debug Thực Tế

Phần này ghi lại toàn bộ các sự cố đã gặp phải trong suốt quá trình phát triển dự án và nguyên lý khắc phục để làm tài liệu tham khảo cho các lần debug sau:

### ⚠️ Bài Học 1: Lệch chuẩn thời gian giữa IP APB Slave và Merlin Interconnect
- **Hiện tượng lỗi:** Ban đầu trên kit DE2-115, LED 7 thanh chỉ đứng yên ở số `00`, gõ phím trên PC không có bất kỳ phản hồi nào.
- **Nguyên nhân cốt lõi:**
  - File `apb_slave.v` cũ sử dụng máy trạng thái FSM 2 chu kỳ: bắt buộc chu kỳ SETUP (`psel=1, penable=0`) trước chu kỳ ACCESS (`psel=1, penable=1`).
  - Trong khi đó, bộ chuyển đổi **Merlin APB Translator** được sinh tự động bởi Platform Designer (Qsys) lại kích hoạt `psel` và `penable` đồng thời theo chuẩn **Zero-Wait-State APB**.
  - Kết quả: FSM cũ bị kẹt vĩnh viễn ở trạng thái `IDLE`. Mọi lệnh đọc/ghi của CPU vào UART đều bị bỏ qua (trả về giá trị 0).
- **Cách khắc phục:**
  - Thay thế FSM cũ bằng logic tổ hợp chuẩn Zero-Wait-State:
    ```verilog
    assign pready = psel & penable;
    assign reg_pread  = psel & penable & addr_valid & (~pwrite);
    assign reg_pwrite = psel & penable & addr_valid & pwrite;
    ```
- **Kinh nghiệm:** Khi viết IP APB Slave ghép nối với Qsys/Platform Designer của Altera/Intel, luôn ưu tiên thiết kế Zero-Wait-State với `pready = psel & penable` trừ khi ngoại vi thực sự cần chu kỳ chờ (Wait states).

---

### ⚠️ Bài Học 2: Nguy cơ treo CPU (Hang/Freeze) khi Polling không có Timeout
- **Hiện tượng lỗi:** CPU Nios V dừng hoạt động ngay từ dòng lệnh đầu tiên, không bao giờ chạy đến vòng lặp `while (1)`.
- **Nguyên nhân:**
  - Trong hàm `uart_putc()` viết:
    ```c
    while ((IORD_32DIRECT(UART_STT_REG, 0) & 0x01) == 0); // Vòng lặp chờ vô tận
    ```
  - Khi bus APB gặp sự cố (như Bài học 1) hoặc ngoại vi chưa sẵn sàng, lệnh đọc luôn trả về `0`. Phép so sánh `0 == 0` luôn đúng khiến CPU lặp vô tận tại chỗ.
- **Cách khắc phục:**
  - Bắt buộc thêm biến đếm thời gian chờ (**Software Watchdog Timeout**):
    ```c
    uint32_t timeout = 500000;
    while (((IORD_32DIRECT(UART_STT_REG, 0) & 0x01) == 0) && --timeout);
    if (timeout == 0) return -1; // Thoát an toàn nếu phần cứng không phản hồi
    ```
- **Kinh nghiệm:** Trong lập trình nhúng / vi điều khiển, **không bao giờ được phép `while` vô điều kiện trên thanh ghi trạng thái phần cứng**. Luôn phải có timeout để hệ thống tự phục hồi hoặc báo lỗi.

---

### ⚠️ Bài Học 3: Bẫy "Giá trị Reset mặc định" của cổng PIO
- **Hiện tượng gây nhầm lẫn:** Khi nạp code, LED 7 đoạn hiện `00`. Người lập trình dễ ngộ nhận rằng CPU đã chạy thành công tới lệnh `IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, 0x00)`.
- **Bản chất thực sự:**
  - Trong cấu hình Qsys, giá trị reset phần cứng của khối `pio_0` đã được đặt mặc định là `0` (`PIO_0_RESET_VALUE 0`).
  - Vì vậy, ngay cả khi CPU bị đứt clock hoặc bị treo từ lúc reset, LED 7 đoạn vẫn sáng `00`!
- **Cách khắc phục:**
  - Trong quá trình debug, luôn dùng một giá trị khởi động đặc trưng khác 0 (ví dụ `0x88`, `0x11`) hoặc tạo hiệu ứng nhấp nháy (Heartbeat LED) để khẳng định CPU thực sự sống và đang thực thi code.

---

### ⚠️ Bài Học 4: Lỗi `Programming hardware cable not detected` (Error 213013) & Xử Lý jtagd Socket
- **Hiện tượng:** Cáp USB-Blaster và nguồn kit DE2-115 đã cắm đầy đủ, nhưng khi chạy nạp thì Quartus Programmer báo:
  `Error (213013): Programming hardware cable not detected`.
- **Bản chất nguyên nhân gốc rễ (Root Cause):**
  1. **Lỗi truyền chuỗi tên cáp (Cable Name String Parsing):**
     - Đầu ra của `jtagconfig` hoặc `quartus_pgm -l` có định dạng: `1) USB-Blaster [3-11]`.
     - Nếu script dùng `awk '{print $2}'`, nó chỉ bóc được chữ `USB-Blaster`. Khi script gọi lệnh:
       `quartus_pgm -m jtag -c "USB-Blaster $CABLE"`
       thì tham số bị biến thành: `-c "USB-Blaster USB-Blaster"` (bị lặp 2 lần). Quartus tìm kiếm phần cứng tên `USB-Blaster USB-Blaster` nên không thể nhận diện.
     - Tham số chính xác phải là: `-c "USB-Blaster [3-11]"`.
  2. **Tiến trình ngầm `jtagd` bị treo socket (Stale Daemon Socket):**
     - Khi rút cắm cáp USB hoặc sau khi máy tính Sleep/Wake, tiến trình nền `jtagd` (Altera JTAG Server Daemon) có thể giữ socket cũ và không quét lại danh sách thiết bị trên bus USB.
- **Cách khắc phục triệt để:**
  - Sửa lệnh tách chuỗi tên cáp trong script bằng `sed 's/^[0-9]*)[[:space:]]*//'` để giữ nguyên cả định danh port `[3-11]`.
  - Tích hợp cơ chế tự phục hồi: nếu chưa thấy cáp, script sẽ tự động gọi `killall -9 jtagd` để ép daemon khởi động lại sạch sẽ và quét lại bus USB.

---

## 6. Hướng Dẫn Sử Dụng Chi Tiết Từng Bước (Step-by-Step Run)

### Bước 1: Nạp Bitstream vào Kit DE2-115
1. Cắm cáp nguồn 12V và cáp nạp USB-Blaster vào kit DE2-115. Bật công tắc nguồn (Nút đỏ **POWER**).
2. Cắm module USB-to-UART vào máy tính và nối 3 dây vào header JP5:
   - Dây **TX** (module) $\rightarrow$ Cắm Chân 1 JP5 (`PIN_AB22`)
   - Dây **RX** (module) $\rightarrow$ Cắm Chân 2 JP5 (`PIN_AC15`)
   - Dây **GND** (module) $\rightarrow$ Cắm Chân 12 JP5 (Ground)
3. Mở terminal, chạy lệnh nạp nhanh:
   ```bash
   cd ~/altera_lite/24.1std
   ./flash_fpga.sh
   ```
   *Khi thấy thông báo `[THÀNH CÔNG] Đã nạp SoC Nios-V & APB UART vào kit DE2-115!`, kit đã sẵn sàng!*

---

### Bước 2: Mở Terminal 1 (Nios V Shell Console)
Mở một cửa sổ Terminal mới (đặt ở nửa bên trái màn hình) và chạy:
```bash
cd ~/altera_lite/24.1std
./run_terminal_jtag.sh
```
Màn hình banner Nios V xuất hiện:
```text
====================================================================
     TERASIC DE2-115 NIOS-V SoC DUAL-CPU INTERCONNECT BRIDGE        
       Architecture: RISC-V RV32I @ 50MHz  |  Bus: AMBA APB         
====================================================================
 [Core]  Nios V CPU online. Running on-chip RAM 64KB.
 [APB]   UART IP Peripheral initialized at base: 0x00020000.
 [JTAG]  Interactive Debug Shell active.
--------------------------------------------------------------------
 Type 'help' to see available commands, or 'send <msg>' to talk to PC.
====================================================================
NIOS-V:/> 
```

---

### Bước 3: Mở Terminal 2 (PC Serial Application)
Mở một cửa sổ Terminal thứ hai (đặt ở nửa bên phải màn hình) và chạy:
```bash
cd ~/altera_lite/24.1std
./run_terminal_pc.sh
```
Terminal này kết nối tới `/dev/ttyUSB0` với tốc độ 9600 baud. Bạn sẽ thấy dòng thông báo chào mừng từ kit:
```text
[DE2-115 SoC Online] Core: Nios V RISC-V | APB UART 9600-8N1
```

---

### Bước 4: Thử Nghiệm Giao Tiếp 2 Chiều Giữa 2 CPU!

#### Kịch bản 1: Nios V gửi tin nhắn sang PC
- Trên **Terminal 1**, gõ:
  ```text
  NIOS-V:/> send Chao ban, toi la CPU Nios V tren DE2-115!
  ```
- Quan sát **Terminal 2**: Tin nhắn xuất hiện ngay lập tức trên màn hình PC!

#### Kịch bản 2: PC gửi tin nhắn chuỗi sang Nios V (Cách B: Đồng nhất Chuỗi sang Chuỗi)
- Trên **Terminal 2**, gõ một câu văn bản hoàn chỉnh rồi nhấn phím **[ENTER]**:
  ```text
  Chao Nios V, toi la PC x86_64!
  ```
- **Trong quá trình gõ:**
  - Từng ký tự được tự động echo lên Terminal 2 để bạn quan sát rõ những gì đang gõ.
  - Hỗ trợ phím **Backspace** để sửa lỗi nếu gõ sai chính tả.
  - Đèn LED 7 đoạn `HEX1-HEX0` trên kit DE2-115 liên tục nhảy số hiển thị mã ASCII Hex của phím bạn vừa bấm.
- **Khi nhấn phím [ENTER]:**
  - Quan sát **Terminal 1**: Nios V gom trọn vẹn cả chuỗi và in ra một lần duy nhất:
    ```text
    [Incoming from PC (APB)]: "Chao Nios V, toi la PC x86_64!"
    NIOS-V:/> 
    ```
  - Hai chiều giao tiếp giữa 2 CPU giờ đây **hoàn toàn đồng nhất theo định dạng chuỗi (String-to-String Message)**!

#### Kịch bản 3: Chế độ Direct Chat (Trò chuyện trực tiếp)
- Trên **Terminal 1**, gõ lệnh `chat`.
- Bây giờ bạn có thể gõ bất kỳ văn bản nào, từng ký tự sẽ được bắn trực tiếp sang Terminal 2.
- Nhấn phím `ESC` để quay lại chế độ CLI Shell.

#### Kịch bản 4: Xem thống kê Bus APB
- Trên **Terminal 1**, gõ lệnh `status`. Nios V sẽ in báo cáo toàn diện số lượng byte đã truyền/nhận qua từng bus.

---

## 7. Tổng Kết

Hệ thống đã đạt được các tiêu chuẩn kỹ thuật cao nhất của một thiết kế SoC:
1. **Chuẩn hóa phần cứng:** IP APB UART tuân thủ chuẩn AMBA APB Zero-Wait-State, tích hợp mượt mà vào Platform Designer.
2. **Khai thác toàn diện CPU:** Nios V không chỉ làm nhiệm vụ thụ động mà trở thành bộ não điều phối 2 bus song song (JTAG & APB), chạy Shell parser tương tác với người dùng.
3. **Mô hình Dual-CPU hoàn chỉnh:** Tách biệt rõ ràng giữa Console quản trị của kit và Kênh ứng dụng của PC, tạo nền tảng vững chắc cho mọi đề tài nghiên cứu SoC nâng cao.
