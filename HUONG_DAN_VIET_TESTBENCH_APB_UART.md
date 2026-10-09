# GIÁO TRÌNH HƯỚNG DẪN VIẾT TESTBENCH CHO MODULE `apb_uart.v`
> **Dành cho người mới bắt đầu (Beginner to Intermediate)**  
> **Mục tiêu**: Xây dựng tư duy kiểm thử chuẩn công nghiệp (Verification Mindset), nắm vững giao thức APB & UART, tự tay viết Testbench tự kiểm tra (Self-checking Testbench) với 5 Testcase toàn diện.

---

## 1. Bản Đồ Kiến Trúc & Tư Duy Kiểm Thử (Verification Mindset)

### 1.1. Sơ Đồ Khối & Hai Luồng Tín Hiệu Của `apb_uart`
Hệ thống `apb_uart` đóng vai trò là một thiết bị ngoại vi SoC (Peripheral) giao tiếp 2 chiều:
1. **Control Plane (Bus APB)**: Phía CPU (Master) điều khiển, cấu hình và đọc/ghi dữ liệu qua giao thức AMBA APB.
2. **Data Plane (Serial UART)**: Phía ngoại vi bên ngoài (PC / Cảm biến / Module khác) truyền nhận dữ liệu nối tiếp qua 2 dây `rx` và `tx`.

```
               +-------------------------------------------------------------+
               |                       MODULE apb_uart                       |
               |                                                             |
   [APB BUS]   |   +-------------+      +-------------+      +-----------+   |
   pclk ------->-->|             |      |             |----->|  tx_uart  |---> tx (Serial Out)
   preset_n --->-->|  apb_slave  |<---->|  uart_regs  |      +-----------+   |
   psel ------->-->| (APB FSM)   |      | (Reg Map)   |            ^         |
   penable ---->-->|             |      |             |            |         |
   pwrite ----->-->+-------------+      +-------------+      +-----------+   |
   paddr ----->-->         |                   ^             | baud_gen  |   |
   pwdata ----->->         v                   |             +-----------+   |
   prdata <-----<-         |                   v                   |         |
   pready <-----<-         |            +-------------+            v         |
   pslverr <----<-         +----------->|   rx_uart   |<-----------+         |
               |                        +-------------+                      |
               |                               ^                             |
   rx (Serial In) -----------------------------+                             |
               +-------------------------------------------------------------+
```

---

### 1.2. Bản Đồ Bộ Nhớ (Register Memory Map)
Theo đúng code nguồn trong [`rtl/reg_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/reg_uart.v), CPU giao tiếp với UART qua 5 thanh ghi 32-bit (chỉ dùng các byte/bit thấp):

| Tên Thanh Ghi | Địa Chỉ (Offset) | Quyền Truy Cập | Chức Năng Chi Tiết |
| :--- | :---: | :---: | :--- |
| **`ADDR_TX`** | `12'h00` | Read / Write | **Ghi dữ liệu cần phát** `pwdata[7:0]`.<br/>*Bảo vệ*: Chỉ cho phép ghi khi `stt_reg[0] == 1` (TX rảnh). Nếu ghi khi TX đang bận $\rightarrow$ `pslverr = 1`. |
| **`ADDR_RX`** | `12'h04` | Read Only | **Đọc dữ liệu nhận được** `prdata[7:0]`.<br/>*Cơ chế tự xóa*: Khi CPU đọc thanh ghi này (`rx_read_ack`), phần cứng **tự động xóa cờ `rx_done` và cờ `error` về 0**! |
| **`ADDR_CFG`** | `12'h08` | Read / Write | **Cấu hình khung truyền và Baudrate**:<br/>• Bit `[1:0]`: Số data bits (`00`: 5b, `01`: 6b, `10`: 7b, `11`: 8b)<br/>• Bit `[2]`: Số stop bits (`0`: 1 stop bit, `1`: 2 stop bits)<br/>• Bit `[3]`: Bật Parity (`1`: Bật, `0`: Tắt)<br/>• Bit `[4]`: Loại Parity (`0`: Chẵn/Even, `1`: Lẻ/Odd)<br/>• Bit `[6:5]`: Baudrate (`00`: 2400, `01`: 4800, `10`: 9600, `11`: 19200)<br/>*Bảo vệ*: Chỉ được ghi khi UART hoàn toàn rảnh (`uart_idle`). |
| **`ADDR_CTRL`**| `12'h0C` | Read / Write | **Điều khiển hoạt động**:<br/>• Bit `[0]`: `start_tx` (Ghi `1` để phát byte trong `ADDR_TX`). Tự động xóa về `0` ở chu kỳ clock kế tiếp. |
| **`ADDR_STT`** | `12'h10` | Read Only | **Trạng thái hệ thống**:<br/>• Bit `[0]`: `tx_done` (`1` = TX rảnh/xong, `0` = TX đang bận). Reset = `1`.<br/>• Bit `[1]`: `rx_done` (`1` = Có byte mới nhận, `0` = Không có). Reset = `0`.<br/>• Bit `[2]`: `error` (`1` = Lỗi Parity phát hiện ở RX). Reset = `0`. |

---

### 1.3. Nhật Ký Lỗi RTL & Bẫy Kỹ Thuật Đã Phát Hiện Qua Testbench (RTL Bug Log)
Trong quá trình phát triển SoC và viết Testbench, việc phát hiện lỗi trong mã nguồn RTL là mục tiêu quan trọng nhất của một kỹ sư kiểm thử. Dưới đây là 3 lỗi phần cứng thực tế cực kỳ hiểm hóc đã được phát hiện và sửa chữa:

#### 🔴 LỖI 1: Lệch số bit và Đảo ngược logic Parity Type (Port Width Mismatch & Inverted Logic)
* **Vị trí**: [`rtl/apb_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/apb_uart.v#L29), [`rtl/rx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_uart.v#L8) và [`rtl/error_check.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/error_check.v#L2).
* **Hiện tượng**: Khi cấu hình Parity Chẵn (`parity_type = 0`), phần cứng lại kiểm tra Parity Lẻ (Odd); khi cấu hình Parity Lẻ (`parity_type = 1`), phần cứng lại kiểm tra Parity Chẵn (Even).
* **Nguyên nhân gốc rễ**:
  1. Ban đầu trong code cũ, Parity dùng mã 2-bit (`2'b10` = Even, `2'b01` = Odd). `apb_uart.v` chuyển đổi: `rx_parity_type = {parity_type, ~parity_type}`.
  2. Về sau, đồng đội sửa `error_check.v` thành 1-bit (`1'b0` = Even, `1'b1` = Odd), nhưng quên sửa `rx_uart.v` (vẫn khai báo 2-bit `input [1:0] parity_type`).
  3. Verilog tự động cắt bỏ bit cao khi nối bus 2-bit vào cổng 1-bit, chỉ lấy bit LSB `parity_type[0]`, tức là `~parity_type` (bit bị đảo!).
* **Cách khắc phục chuẩn**:
  - Trong `rx_uart.v`: Đổi cổng thành 1-bit: `input parity_type,`.
  - Trong `apb_uart.v`: Nối thẳng `.parity_type(parity_type)`, bỏ dòng ghép bit `{parity_type, ~parity_type}`.

---

#### 🔴 LỖI 2: Điều kiện `uart_idle` chặn ghi thanh ghi cấu hình `ADDR_CFG`
* **Vị trí**: [`rtl/reg_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/reg_uart.v#L46).
* **Đoạn code bị lỗi**:
  ```verilog
  wire tx_wr_en    = addr_tx && stt_reg[0];
  wire uart_idle   = stt_reg[0] && rx_done; // <-- LỖI TẠI ĐÂY!
  wire cfg_wr_en   = addr_cfg && uart_idle;
  ```
* **Hiện tượng**: CPU ghi vào `ADDR_CFG` (0x08) luôn bị báo lỗi `pslverr = 1`, thanh ghi giữ nguyên giá trị `0x0000_0000` (5 data bits, 2400 baud, không parity).
* **Nguyên nhân gốc rễ**:
  - `rx_done` từ `rx_uart` là một xung tích cực mức cao chỉ kéo dài 1 chu kỳ khi nhận xong byte. Ở trạng thái rảnh (IDLE), `rx_done = 0`!
  - Tác giả `reg_uart.v` giả định nhầm trong testbench con (`tb_uart_regs.v`) rằng `rx_done = 1` là rảnh. Khi tích hợp vào hệ thống thực tế, `uart_idle = stt_reg[0] && rx_done` = `1 && 0 = 0` $\rightarrow$ `cfg_wr_en = 0` vĩnh viễn!
* **Cách khắc phục**:
  Sửa điều kiện rảnh thành TX không bận và RX không có dữ liệu chưa đọc:
  ```verilog
  wire uart_idle = stt_reg[0] && !stt_reg[1];
  ```

---

#### 🔴 LỖI 3: Cờ `ERROR` không tự xóa sau khi đọc `ADDR_RX` (Latch Priority Bug)
* **Vị trí**: [`rtl/reg_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/reg_uart.v#L92).
* **Đoạn code bị lỗi**:
  ```verilog
  if (error)
      stt_reg[2] <= 1'b1;
  else if (rx_read_ack)
      stt_reg[2] <= 1'b0;
  ```
* **Hiện tượng**: Khi phát hiện lỗi Parity, cờ `error` (bit 2 của `ADDR_STT`) bật lên 1. Nhưng sau khi CPU đọc `ADDR_RX`, cờ `error` vẫn kẹt ở mức 1, không bao giờ xóa được!
* **Nguyên nhân gốc rễ**:
  - Tín hiệu `error` từ `error_check.v` là tín hiệu tổ hợp mức cao (level), giữ nguyên giá trị `1` cho đến khi có frame mới.
  - Vì `if (error)` nằm ở đầu, nó luôn đúng ở mọi chu kỳ clock, nhánh `else if (rx_read_ack)` không bao giờ có hiệu lực!
* **Cách khắc phục**:
  Chỉ chốt lỗi khi có xung báo nhận xong `rx_done`, và ưu tiên xóa lỗi khi CPU đọc `ADDR_RX`:
  ```verilog
  if (rx_read_ack)
      stt_reg[2] <= 1'b0;
  else if (rx_done && error)
      stt_reg[2] <= 1'b1;
  ```

---

### 1.4. Các Lỗi Cú Pháp & Logic Thường Gặp Khi Mới Bắt Đầu Viết Testbench
Là một người mới bắt đầu (Beginner), bạn rất dễ gặp các lỗi sau khi tự code:

1. **Nhầm lẫn giữa `wire` và `reg`**:
   - Khi truyền biến vào cổng `output` của một `task` (ví dụ: `apb_read(..., read_val, err_resp)`), biến nhận bắt buộc phải khai báo là `reg`, không được dùng `wire`.
   - Chân `rx` bị gán thủ công (`rx = 1'b0;`) trong initial block cũng bắt buộc phải là `reg rx;`.
2. **Sai lệch tên biến**:
   - Khai báo `integer time_out;` (có dấu gạch dưới) nhưng bên dưới lại dùng `timeout` $\rightarrow$ Trình biên dịch báo lỗi biến chưa khai báo.
3. **Ánh xạ số bit dữ liệu bị đảo ngược**:
   - Trong `send_uart_rx_byte`: `2'b00` là **5 data bits**, còn `2'b11` là **8 data bits** (xem [`rtl/data_b_num.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/data_b_num.v)). Nếu viết ngược, TB sẽ gửi thiếu bit.
4. **Độ rộng tham số in chuỗi quá hẹp**:
   - Khai báo `task print_header(input [255:0] test_name);` chỉ chứa được tối đa 32 ký tự, các tên testcase dài sẽ bị cắt cụt chữ đầu. Hãy dùng `input [511:0] test_name;` (64 ký tự).

---

### 1.4. Tư Duy Người Viết Testbench: Self-Checking Testbench
Người mới bắt đầu thường chỉ chạy mô phỏng rồi mở dạng sóng (Waveform) để "nhìn bằng mắt". Cách làm này chậm, dễ bỏ sót lỗi và không thể tự động hóa trong các dự án lớn.
* **Nguyên tắc Self-checking**: Mọi hành động gửi/nhận đều phải được Testbench tự động tính toán giá trị kỳ vọng (Golden Expected Value) và dùng câu lệnh `if...else` so sánh.
* Nếu đúng $\rightarrow$ Tăng biến `pass_count` và in `[PASS]`.
* Nếu sai $\rightarrow$ Tăng biến `fail_count`, in cảnh báo chi tiết `[FAIL]` kèm giá trị thực tế vs giá trị mong đợi.

---

## 2. Bộ Khung Testbench Hoàn Chỉnh (Boilerplate Code)

Dưới đây là phần khung chuẩn bạn có thể copy vào file [`tb/tb_apb_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/tb/tb_apb_uart.v). Phần này gồm các tín hiệu, kết nối DUT, tạo clock, reset, và cơ chế in thống kê.

```verilog
`timescale 1ns/1ps

module tb_apb_uart;

    // =========================================================================
    // 1. KHAI BÁO THAM SỐ VÀ TÍN HIỆU (PARAMETERS & SIGNALS)
    // =========================================================================
    // Đặt tần số 50MHz (hoặc 1_000_000 để tăng tốc độ mô phỏng)
    parameter CLK_FREQ = 50_000_000;
    parameter CLK_PERIOD = 20; // 50 MHz -> Chu kỳ 20ns (10ns HIGH, 10ns LOW)

    // Tín hiệu Clock và Reset
    reg         clk;
    reg         rst_n;

    // Tín hiệu giao tiếp Bus APB (Testbench đóng vai Master)
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [11:0] paddr;
    reg  [31:0] pwdata;
    wire        pready;
    wire        pslverr;
    wire [31:0] prdata;

    // Tín hiệu giao tiếp UART vật lý nối ra ngoài
    wire        tx; // DUT phát ra -> TB giám sát
    reg         rx; // TB phát vào -> DUT nhận

    // Các biến quản lý testbench & thống kê Pass/Fail
    integer test_id;
    integer pass_count;
    integer fail_count;
    integer bit_time_ns; // Thời gian 1 bit UART tính bằng ns

    // =========================================================================
    // 2. KẾT NỐI VỚI THIẾT BỊ CẦN KIỂM THỬ (DUT INSTANTIATION)
    // =========================================================================
    apb_uart #(
        .CLK_FREQ(CLK_FREQ)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .pready  (pready),
        .pslverr (pslverr),
        .prdata  (prdata),
        .tx      (tx),
        .rx      (rx)
    );

    // =========================================================================
    // 3. TẠO XUNG CLOCK VÀ DUMP DẠNG SÓNG
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin
        $dumpfile("wave_apb_uart.vcd");
        $dumpvars(0, tb_apb_uart);
    end

    // =========================================================================
    // 4. CÁC HÀM TIỆN ÍCH HIỂN THỊ KẾT QUẢ
    // =========================================================================
    task print_header(input [255:0] test_name);
        begin
            $display("\n============================================================");
            $display(">>> TESTCASE %0d: %0s", test_id, test_name);
            $display("============================================================");
        end
    endtask

    task print_summary;
        begin
            $display("\n============================================================");
            $display("                TONG KET KET QUA MO PHONG                   ");
            $display("============================================================");
            $display("  TONG SO TEST : %0d", pass_count + fail_count);
            $display("  SO TEST PASS : %0d", pass_count);
            $display("  SO TEST FAIL : %0d", fail_count);
            $display("============================================================");
            if (fail_count == 0)
                $display("  >>> KET LUAN: TAT CA CAC TESTCASE DEU PASS! XUAT SAC! <<<");
            else
                $display("  >>> KET LUAN: CO %0d TESTCASE BI THAT BAI! CAN KIEM TRA LAI! <<<", fail_count);
            $display("============================================================\n");
        end
    endtask

```

---

## 3. Xây Dựng Các "Vũ Khí Cơ Bản" (Verification Tasks)

Trước khi viết từng testcase, ta cần trang bị các `task` tái sử dụng. Đây là cách các kỹ sư chuyên nghiệp trừu tượng hóa các thao tác bus phức tạp.

### 3.1. Task Giao Tiếp APB: `apb_write` & `apb_read` *(Code sẵn - Copy trực tiếp)*
Giao thức APB tuân thủ nghiêm ngặt 2 pha:
* **Chu kỳ 1 (SETUP Phase)**: Kéo `psel = 1`, `penable = 0`, đặt địa chỉ `paddr` và dữ liệu `pwdata`.
* **Chu kỳ 2 (ACCESS Phase)**: Kéo `penable = 1`. Lấy mẫu tín hiệu `pready`, `pslverr` và dữ liệu `prdata`.
* **Chu kỳ 3**: Thu hồi `psel = 0`, `penable = 0`.

```verilog
    // Task ghi dữ liệu vào thanh ghi APB
    task apb_write(
        input [11:0] addr, 
        input [31:0] data, 
        output err
    );
        begin
            @(posedge clk);
            paddr   <= addr;
            pwdata  <= data;
            pwrite  <= 1'b1;
            psel    <= 1'b1;
            penable <= 1'b0;

            @(posedge clk);
            penable <= 1'b1;

            @(posedge clk); // Trạng thái chuyển sang ACCESS trong apb_slave
            #1;             // Chờ 1ns để tín hiệu tổ hợp ổn định
            err = pslverr;

            @(posedge clk); // Dữ liệu được ghi vào thanh ghi ở cạnh này
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
        end
    endtask

    // Task đọc dữ liệu từ thanh ghi APB
    task apb_read(
        input  [11:0] addr, 
        output [31:0] data, 
        output err
    );
        begin
            @(posedge clk);
            paddr   <= addr;
            pwrite  <= 1'b0;
            psel    <= 1'b1;
            penable <= 1'b0;

            @(posedge clk);
            penable <= 1'b1;

            @(posedge clk); // Trạng thái chuyển sang ACCESS
            #1;
            data = prdata;
            err  = pslverr;

            @(posedge clk);
            psel    <= 1'b0;
            penable <= 1'b0;
        end
    endtask
```

---

### 3.2. Task Bơm Frame UART Nối Tiếp Vào Chân `rx`: `send_uart_rx_byte`
Khi muốn test khả năng nhận (RX) của chip, Testbench phải đóng vai một thiết bị UART truyền nối tiếp vào chân `rx`.
* Trạng thái rảnh (Idle): `rx = 1`.
* **Start bit**: Kéo xuống `0` trong đúng 1 `bit_time`.
* **Data bits**: Gửi lần lượt từ bit thấp nhất (LSB - bit 0) đến bit cao nhất (MSB), mỗi bit giữ đúng 1 `bit_time`.
* **Parity bit** (nếu có): Giá trị chẵn/lẻ tùy cấu hình.
* **Stop bit**: Kéo lên `1` trong 1 hoặc 2 `bit_time`.

#### 🧠 Thử Thách Tư Duy #1: Hoàn Thiện Task `send_uart_rx_byte`
Dưới đây là khung sườn task. Chỗ có ghi `/* TODO 1: ... */` là nơi bạn cần suy nghĩ và tự viết:

```verilog
    task send_uart_rx_byte(
        input [7:0] byte_val,
        input [1:0] num_data_bits_cfg, // 00: 5b, 01: 6b, 10: 7b, 11: 8b
        input       parity_en_cfg,
        input       parity_type_cfg,   // 0: Even (Chẵn), 1: Odd (Lẻ)
        input       inject_error       // 1: Cố tình đảo bit Parity để test lỗi
    );
        integer i;
        integer total_bits;
        reg parity_bit_calc;
        reg parity_to_send;
        begin
            // Xác định số bit data thực tế cần gửi
            case (num_data_bits_cfg)
                2'b00: total_bits = 5;
                2'b01: total_bits = 6;
                2'b10: total_bits = 7;
                2'b11: total_bits = 8;
            endcase

            // 1. GỬI START BIT
            rx = 1'b0;
            #(bit_time_ns);

            // 2. GỬI DATA BITS (LSB first) VÀ TÍNH TOÁN PARITY
            parity_bit_calc = 1'b0;
            for (i = 0; i < total_bits; i = i + 1) begin
                rx = byte_val[i];
                // ==============================================================
                // TODO 1.1: Tính toán bit Parity tích lũy sau mỗi bit dữ liệu.
                // Gợi ý: Dùng toán tử XOR (^) giữa parity_bit_calc và byte_val[i]
                // ==============================================================
                /* [BẠN TỰ VIẾT DÒNG NÀY VÀO ĐÂY] */

                #(bit_time_ns);
            end

            // 3. GỬI PARITY BIT (NẾU ĐƯỢC BẬT)
            if (parity_en_cfg) begin
                // ==============================================================
                // TODO 1.2: Xác định giá trị parity_to_send:
                // - Nếu parity_type_cfg == 0 (Even parity): 
                //   Tổng số bit 1 là chẵn -> parity_to_send = parity_bit_calc.
                // - Nếu parity_type_cfg == 1 (Odd parity): 
                //   Tổng số bit 1 là lẻ -> parity_to_send = ~parity_bit_calc.
                // - Nếu inject_error == 1: Đảo ngược bit để cố tình gây lỗi!
                // ==============================================================
                /* [BẠN TỰ VIẾT KHỐI LOGIC PARITY VÀO ĐÂY] */

                rx = parity_to_send;
                #(bit_time_ns);
            end

            // 4. GỬI STOP BIT
            rx = 1'b1;
            #(bit_time_ns); // 1 Stop bit
        end
    endtask
```

> [!TIP]
> **Gợi ý nhanh cho TODO 1.1 & 1.2**:
> - XOR bit tích lũy: `parity_bit_calc = parity_bit_calc ^ byte_val[i];`
> - Even parity: `parity_to_send = (parity_type_cfg == 1'b0) ? parity_bit_calc : ~parity_bit_calc;`
> - Error injection: `if (inject_error) parity_to_send = ~parity_to_send;`

---

## 4. Hướng Dẫn Chi Tiết 5 Testcase Chuẩn Chỉ

Bây giờ chúng ta sẽ vào khối chương trình chính `initial begin ... end`. Mỗi testcase sẽ kiểm tra một tính năng cốt lõi của `apb_uart`.

---

### Testcase 1: Khởi Tạo, Cấu Hình Thanh Ghi & Kiểm Tra Mặc Định
* **Mục tiêu**:
  1. Kiểm tra trạng thái mặc định của thanh ghi `ADDR_STT` sau khi nhả reset: `tx_done = 1` (bit 0), `rx_done = 0` (bit 1), `error = 0` (bit 2).
  2. Ghi cấu hình chuẩn vào `ADDR_CFG` (0x08): 8 data bits (`11`), 1 stop bit (`0`), có Parity (`1`), Parity chẵn (`0`), tốc độ 9600 Baud (`10`).
  3. Đọc lại `ADDR_CFG` qua APB, kiểm tra `prdata` có khớp chính xác không và `pslverr` phải bằng `0`.

#### 🧠 Thử Thách Tư Duy #2: Tính Giá Trị `ADDR_CFG` & Viết Câu Lệnh Kiểm Tra

Cấu trúc 32-bit của `ADDR_CFG`:
```
Bit:       [31:7]       [6:5]         [4]          [3]         [2]        [1:0]
Ý nghĩa:   Reserved   baud_sel   parity_type   parity_en   stop_bit   data_bits
Giá trị:      0          10           0            1           0          11
```
Ghép các bit lại: `(2'b10 << 5) | (1'b0 << 4) | (1'b1 << 3) | (1'b0 << 2) | (2'b11)` = `7'b1001011` = `0x4B`.

Dưới đây là đoạn code chừa chỗ cho bạn tự viết:

```verilog
        // Khởi tạo ban đầu
        test_id    = 1;
        pass_count = 0;
        fail_count = 0;
        rst_n      = 0;
        psel       = 0;
        penable    = 0;
        pwrite     = 0;
        paddr      = 0;
        pwdata     = 0;
        rx         = 1; // UART idle ở mức cao

        #100;
        rst_n = 1;      // Nhả reset
        #40;

        print_header("KHOI TAO & CAU HINH THANH GHI CFG");

        // BƯỚC 1: Đọc kiểm tra ADDR_STT sau reset (Mong đợi: 32'h0000_0001)
        apb_read(12'h010, read_val, err_resp);
        
        // ==============================================================
        // TODO 2.1: Viết câu lệnh if...else kiểm tra read_val == 32'h1 và err_resp == 0
        // Nếu ĐÚNG: Tăng pass_count, in [PASS].
        // Nếu SAI:  Tăng fail_count, in [FAIL] và giá trị nhận được.
        // ==============================================================
        /* [BẠN TỰ VIẾT CÂU LỆNH IF...ELSE VÀO ĐÂY] */

        // BƯỚC 2: Ghi cấu hình 8-E-1 @ 9600 Baud vào ADDR_CFG
        // Tính thời gian 1 bit cho 9600 Baud: 1s / 9600 = ~104167 ns
        bit_time_ns = 1_000_000_000 / 9600;
        
        apb_write(12'h008, 32'h0000_004B, err_resp);
        apb_read(12'h008, read_val, err_resp);

        // ==============================================================
        // TODO 2.2: Viết câu lệnh if...else kiểm tra read_val == 32'h4B và err_resp == 0
        // ==============================================================
        /* [BẠN TỰ VIẾT CÂU LỆNH IF...ELSE VÀO ĐÂY] */
```

---

### Testcase 2: Truyền Dữ Liệu UART (TX) Qua APB & Bắt Bit Nối Tiếp
* **Mục tiêu**:
  1. Ghi byte `0xA5` (`8'b1010_0101`) vào `ADDR_TX` (0x00).
  2. Kích hoạt phát bằng cách ghi `0x01` vào `ADDR_CTRL` (0x0C).
  3. Xác nhận cờ `tx_done` trong `ADDR_STT` lập tức tụt xuống `0` (báo bận).
  4. **Kiểm tra tính năng bảo vệ (Protection)**: Thử cố tình ghi vào `ADDR_TX` hoặc `ADDR_CFG` trong lúc TX đang bận $\rightarrow$ mong đợi `pslverr == 1`.
  5. Polling đọc `ADDR_STT` chờ đến khi `tx_done` trở lại mức `1` (kết thúc truyền).

#### 🧠 Thử Thách Tư Duy #3: Viết Vòng Lặp Polling `tx_done` Có Timeout
Trong lập trình nhúng và kiểm thử, không bao giờ dùng vòng lặp vô hạn `while(tx_busy)` vì nếu phần cứng lỗi, mô phỏng sẽ bị **treo vĩnh viễn**!
Ta phải dùng biến đếm timeout (ví dụ đếm tối đa 100 lần, mỗi lần chờ 1 khoảng thời gian).

```verilog
        test_id = 2;
        print_header("TRUYEN DU LIEU UART (TX) & KIEM TRA CO STATUS");

        // 1. Ghi dữ liệu 0xA5 vào thanh ghi TX
        apb_write(12'h000, 32'h0000_00A5, err_resp);

        // 2. Kích xung start_tx = 1 qua ADDR_CTRL
        apb_write(12'h00C, 32'h0000_0001, err_resp);

        // 3. Đọc ngay ADDR_STT xem tx_done đã về 0 chưa
        apb_read(12'h010, read_val, err_resp);
        if ((read_val & 32'h1) == 0) begin
            $display("  --> [PASS] Co tx_done da keo xuong 0 (TX dang ban truyen)!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co tx_done khong chuyen ve 0 sau khi kich start_tx!");
            fail_count = fail_count + 1;
        end

        // 4. Test tính năng bảo vệ: Cố tình ghi vào ADDR_TX khi đang bận
        apb_write(12'h000, 32'h0000_00FF, err_resp);
        if (err_resp == 1'b1) begin
            $display("  --> [PASS] apb_slave da chan va bao pslverr=1 khi ghi de luc TX ban!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Khong bao loi pslverr khi ghi vao TX luc dang ban!");
            fail_count = fail_count + 1;
        end

        // ==============================================================
        // TODO 3: Viết vòng lặp Polling đọc ADDR_STT chờ tx_done quay lại 1
        // Gợi ý thuật toán:
        //   timeout = 0;
        //   while ((read_val & 1 == 0) && (timeout < 50)) begin
        //       #(bit_time_ns); // Chờ 1 bit_time
        //       apb_read(12'h010, read_val, err_resp);
        //       timeout = timeout + 1;
        //   end
        // Sau đó kiểm tra nếu (read_val & 1 == 1) -> PASS, ngược lại -> FAIL.
        // ==============================================================
        /* [BẠN TỰ VIẾT VÒNG LẶP POLLING VÀO ĐÂY] */
```

---

### Testcase 3: Nhận Dữ Liệu UART (RX) & Xác Minh Cơ Chế Tự Xóa Cờ (Auto-Clear)
* **Mục tiêu**:
  1. Testbench gọi task `send_uart_rx_byte` để bơm byte `0x3C` (`8'b0011_1100`) vào chân `rx`.
  2. Polling `ADDR_STT` chờ bit 1 (`rx_done`) lên `1`.
  3. Đọc dữ liệu từ `ADDR_RX` (0x04) và so sánh xem có đúng là `0x3C` không.
  4. **Cơ chế phần cứng cốt lõi**: Đọc lại `ADDR_STT`, xác nhận cờ `rx_done` **đã tự động tụt về `0`** nhờ lệnh đọc `ADDR_RX` vừa rồi!

#### 🧠 Thử Thách Tư Duy #4: Tự Viết Kịch Bản Nhận & Auto-Clear Flag
Hãy vận dụng tư duy vừa học ở Testcase 2 để tự hoàn thiện Testcase 3:

```verilog
        test_id = 3;
        print_header("NHAN DU LIEU UART (RX) & AUTO-CLEAR FLAG");

        // 1. Gửi byte 0x3C (Parity chẵn: 0x3C có bốn bit 1 -> bit Parity = 0)
        $display("  [INFO] Bat dau gui byte 0x3C vao chan rx...");
        send_uart_rx_byte(8'h3C, 2'b11, 1'b1, 1'b0, 1'b0);

        // ==============================================================
        // TODO 4.1: Polling đọc ADDR_STT chờ cờ rx_done (bit 1) lên 1.
        // Gợi ý: Kiểm tra điều kiện (read_val & 32'h2) != 0.
        // ==============================================================
        /* [BẠN TỰ VIẾT POLLING CHỜ RX_DONE VÀO ĐÂY] */

        // ==============================================================
        // TODO 4.2: Đọc ADDR_RX (0x04) qua apb_read.
        // Kiểm tra xem read_val[7:0] có bằng 8'h3C không.
        // ==============================================================
        /* [BẠN TỰ VIẾT LỆNH ĐỌC VÀ ASSERT KẾT QUẢ VÀO ĐÂY] */

        // ==============================================================
        // TODO 4.3: Đọc lại ADDR_STT (0x10) để kiểm tra tính năng Auto-Clear.
        // Mong đợi: bit 1 (rx_done) phải bằng 0 sau khi đọc ADDR_RX!
        // ==============================================================
        /* [BẠN TỰ VIẾT LỆNH ĐỌC ADDR_STT VÀ ASSERT AUTO-CLEAR VÀO ĐÂY] */
```

---

### Testcase 4: Bơm Lỗi Parity (Parity Error Injection & Error Checking)
* **Mục tiêu**:
  1. Kiểm thử góc khuất (Negative Testing): Không có hệ thống nào hoàn hảo, ta phải kiểm tra xem khi đường truyền bị nhiễu làm sai bit Parity, hệ thống có phát hiện ra không?
  2. Gọi `send_uart_rx_byte` gửi byte `0x7B` nhưng đặt `inject_error = 1` (đảo ngược bit Parity).
  3. Polling chờ `rx_done == 1`.
  4. Đọc `ADDR_STT` và kiểm tra bit 2 (`error`) **phải bằng `1`**!
  5. Đọc `ADDR_RX`, sau đó đọc lại `ADDR_STT` để xác nhận cả cờ `error` và `rx_done` đều được xóa về `0`.

#### 🧠 Thử Thách Tư Duy #5: Tự Viết Kịch Bản Bơm Lỗi
Đây là kịch bản rèn luyện khả năng tư duy kiểm thử biên của bạn:

```verilog
        test_id = 4;
        print_header("BOM LOI BIT PARITY (ERROR INJECTION TEST)");

        $display("  [INFO] Gui byte 0x7B kem bit Parity CO TINH BI SAI...");
        send_uart_rx_byte(8'h7B, 2'b11, 1'b1, 1'b0, 1'b1); // inject_error = 1

        // Chờ nhận xong
        #100;
        apb_read(12'h010, read_val, err_resp);

        // ==============================================================
        // TODO 5: Kiểm tra cờ error (bit 2) trong ADDR_STT:
        // - Mong đợi: (read_val & 32'h4) != 0 (Cờ error = 1)
        // - Sau đó gọi apb_read(12'h004, read_val, err_resp) để xóa lỗi
        // - Đọc lại ADDR_STT kiểm tra cờ error đã về 0 chưa!
        // ==============================================================
        /* [BẠN TỰ VIẾT TOÀN BỘ LOGIC KIỂM TRA LỖI VÀ AUTO-CLEAR VÀO ĐÂY] */
```

---

### Testcase 5: Loopback Toàn Diện (End-to-End TX $\rightarrow$ RX Loopback Test)
* **Mục tiêu**:
  1. Đây là bài test kinh điển trong ngành chip viễn thông: **Tự phát và tự thu**.
  2. Nối dây: Trong testbench, ta gán tín hiệu `rx = tx` (hoặc tạo task chuyển tiếp).
  3. APB ghi byte `0xD2` vào `ADDR_TX`, kích phát bằng `ADDR_CTRL`.
  4. Chờ toàn bộ chu trình: APB $\rightarrow$ `uart_regs` $\rightarrow$ `tx_uart` phát ra chân `tx` $\rightarrow$ đi vào chân `rx` $\rightarrow$ `rx_uart` giải mã $\rightarrow$ cập nhật `ADDR_RX` và bật `rx_done`.
  5. Đọc `ADDR_RX` và xác nhận dữ liệu nhận được chính xác là `0xD2`, không có lỗi Parity!

#### 🧠 Thử Thách Tư Duy #6: Tự Viết Testcase Loopback Hoàn Chỉnh
Gợi ý:
1. Đặt `rx = tx;` liên tục trong quá trình chạy (hoặc dùng `always @(*) rx = tx;` hoặc `assign`).
2. Ghi `0xD2` vào `12'h000`.
3. Ghi `0x01` vào `12'h00C`.
4. Polling chờ `rx_done == 1` ở `12'h010`.
5. Đọc `12'h004` và so sánh với `8'hD2`.

```verilog
        test_id = 5;
        print_header("LOOPBACK TOAN DIEN (TX NOI TRUC TIEP RX)");

        // ==============================================================
        // TODO 6: Tự ráp nối kịch bản Loopback từ các bước đã học ở trên!
        // ==============================================================
        /* [BẠN TỰ VIẾT TOÀN BỘ KỊCH BẢN LOOPBACK VÀO ĐÂY] */

        // KẾT THÚC TOÀN BỘ MÔ PHỎNG
        #500;
        print_summary;
        $finish;
    end
```

---

## 5. Lời Giải Mẫu Đối Chiếu (Solution & Answer Key)

> [!CAUTION]
> **Hãy tự suy nghĩ và tự code các phần `TODO` ở trên trước khi mở phần này!**  
> Việc tự vấp ngã và tự gõ từng dòng lệnh là cách duy nhất giúp bạn trở thành kỹ sư giỏi trong thời gian ngắn nhất.

<details>
<summary>👉 <b>Nhấn vào đây để xem đáp án hoàn chỉnh của các TODO</b></summary>

### Đáp án TODO 1 (Hoàn thiện `send_uart_rx_byte`):
```verilog
    // TODO 1.1: Tính parity tích lũy
    parity_bit_calc = parity_bit_calc ^ byte_val[i];

    // TODO 1.2: Xác định bit parity gửi đi
    parity_to_send = (parity_type_cfg == 1'b0) ? parity_bit_calc : ~parity_bit_calc;
    if (inject_error)
        parity_to_send = ~parity_to_send;
```

### Đáp án TODO 2 (Testcase 1: Khởi tạo & Cấu hình):
```verilog
    // TODO 2.1: Kiểm tra ADDR_STT sau reset
    if ((read_val == 32'h0000_0001) && (err_resp == 1'b0)) begin
        $display("  --> [PASS] Trang thai reset chuan xac (tx_done=1, rx_done=0, error=0)!");
        pass_count = pass_count + 1;
    end else begin
        $display("  --> [FAIL] ADDR_STT sau reset khong dung! Nhan: 0x%08X", read_val);
        fail_count = fail_count + 1;
    end

    // TODO 2.2: Kiểm tra đọc lại ADDR_CFG
    if ((read_val[6:0] == 7'h4B) && (err_resp == 1'b0)) begin
        $display("  --> [PASS] Ghi va doc lai thanh ghi CFG thanh cong (0x4B)!");
        pass_count = pass_count + 1;
    end else begin
        $display("  --> [FAIL] CFG khong khop! Mong doi: 0x4B, Nhan: 0x%02X", read_val[6:0]);
        fail_count = fail_count + 1;
    end
```

### Đáp án TODO 3 (Testcase 2: Polling `tx_done`):
```verilog
    timeout = 0;
    while (((read_val & 32'h1) == 0) && (timeout < 50)) begin
        #(bit_time_ns);
        apb_read(12'h010, read_val, err_resp);
        timeout = timeout + 1;
    end

    if ((read_val & 32'h1) == 32'h1) begin
        $display("  --> [PASS] TX da phat xong hoan toan, tx_done da quay ve 1!");
        pass_count = pass_count + 1;
    end else begin
        $display("  --> [FAIL] Timeout! TX khong the ket thuc qua trinh phat!");
        fail_count = fail_count + 1;
    end
```

### Đáp án TODO 4 (Testcase 3: Nhận & Auto-Clear Flag):
```verilog
    // 4.1: Polling rx_done
    timeout = 0;
    apb_read(12'h010, read_val, err_resp);
    while (((read_val & 32'h2) == 0) && (timeout < 50)) begin
        #(bit_time_ns / 2);
        apb_read(12'h010, read_val, err_resp);
        timeout = timeout + 1;
    end

    if ((read_val & 32'h2) != 0) begin
        $display("  --> [PASS] Phat hien co rx_done=1 (Da nhan duoc byte moi)!");
        pass_count = pass_count + 1;
    end else begin
        $display("  --> [FAIL] Timeout cho co rx_done!");
        fail_count = fail_count + 1;
    end

    // 4.2: Đọc ADDR_RX
    apb_read(12'h004, read_val, err_resp);
    if (read_val[7:0] == 8'h3C) begin
        $display("  --> [PASS] Du lieu nhan tu ADDR_RX chinh xac: 0x%02X!", read_val[7:0]);
        pass_count = pass_count + 1;
    end else begin
        $display("  --> [FAIL] Du lieu nhan sai! Mong doi 0x3C, Nhan: 0x%02X", read_val[7:0]);
        fail_count = fail_count + 1;
    end

    // 4.3: Kiểm tra Auto-Clear
    apb_read(12'h010, read_val, err_resp);
    if ((read_val & 32'h2) == 0) begin
        $display("  --> [PASS] Co rx_done da duoc tu dong xoa ve 0 sau khi doc ADDR_RX!");
        pass_count = pass_count + 1;
    end else begin
        $display("  --> [FAIL] Co rx_done van con giu nguyen 1, tinh nang auto-clear bi loi!");
        fail_count = fail_count + 1;
    end
```

### Đáp án TODO 5 (Testcase 4: Bơm lỗi Parity):
```verilog
    // Polling chờ nhận xong
    timeout = 0;
    apb_read(12'h010, read_val, err_resp);
    while (((read_val & 32'h2) == 0) && (timeout < 50)) begin
        #(bit_time_ns / 2);
        apb_read(12'h010, read_val, err_resp);
        timeout = timeout + 1;
    end

    // Kiểm tra cờ error = 1
    if ((read_val & 32'h4) != 0) begin
        $display("  --> [PASS] Phan cung da bat co ERROR=1 dung khi phat hien Parity sai!");
        pass_count = pass_count + 1;
    end else begin
        $display("  --> [FAIL] Phan cung khong phat hien ra loi Parity! ADDR_STT = 0x%08X", read_val);
        fail_count = fail_count + 1;
    end

    // Đọc ADDR_RX để kích hoạt cơ chế xóa lỗi
    apb_read(12'h004, read_val, err_resp);
    apb_read(12'h010, read_val, err_resp);
    if ((read_val & 32'h4) == 0) begin
        $display("  --> [PASS] Co ERROR da duoc tu dong xoa ve 0 sau khi doc ADDR_RX!");
        pass_count = pass_count + 1;
    end else begin
        $display("  --> [FAIL] Co ERROR van chua duoc xoa sau khi doc ADDR_RX!");
        fail_count = fail_count + 1;
    end
```

### Đáp án TODO 6 (Testcase 5: Loopback):
```verilog
    // Kết nối loopback mềm
    fork
        // Tiến trình 1: Bắt tín hiệu tx đưa sang rx
        forever @(tx) rx = tx;
        
        // Tiến trình 2: Kích truyền từ APB
        begin
            apb_write(12'h000, 32'h0000_00D2, err_resp);
            apb_write(12'h00C, 32'h0000_0001, err_resp);
            
            // Chờ nhận xong ở RX
            timeout = 0;
            read_val = 0;
            while (((read_val & 32'h2) == 0) && (timeout < 100)) begin
                #(bit_time_ns / 2);
                apb_read(12'h010, read_val, err_resp);
                timeout = timeout + 1;
            end
            
            if ((read_val & 32'h2) != 0) begin
                apb_read(12'h004, read_val, err_resp);
                if (read_val[7:0] == 8'hD2) begin
                    $display("  --> [PASS] Loopback thanh cong hoan hao! Byte thu duoc: 0x%02X", read_val[7:0]);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  --> [FAIL] Loopback sai du lieu! Gui 0xD2, Nhan 0x%02X", read_val[7:0]);
                    fail_count = fail_count + 1;
                end
            end else begin
                $display("  --> [FAIL] Loopback bi timeout, khong thay RX hoan thanh!");
                fail_count = fail_count + 1;
            end
        end
    join_any
    disable fork;
```
</details>

---

## 6. Hướng Dẫn Biên Dịch Và Chạy Mô Phỏng

### 6.1. Chạy Nhanh Bằng Makefile (Khuyên Dùng)
File `Makefile` của dự án đã được tích hợp sẵn các lệnh chạy tự động:

```bash
# 1. Biên dịch và chạy toàn bộ 5 Testcase bằng Icarus Verilog (Nhanh, không cần license)
make apb_uart

# 2. Chạy mô phỏng xong tự động mở GTKWave xem dạng sóng
make wave_apb_uart

# 3. Chạy bằng QuestaSim / ModelSim (khi có license)
make apb_uart_vsim       # Mở giao diện GUI Waveform ModelSim
make apb_uart_vsim_cli   # Chạy dòng lệnh CLI
```

### 6.2. Chạy Thủ Công Bằng Lệnh Dòng Lệnh Icarus Verilog (`iverilog` & `vvp`)
Nếu muốn gõ lệnh tay trực tiếp:

```bash
# 1. Biên dịch toàn bộ các file RTL cần thiết và Testbench
iverilog -g2012 -o sim_apb_uart.vvp \
    rtl/apb_uart.v \
    rtl/apb_slave.v \
    rtl/reg_uart.v \
    rtl/baud_gen.v \
    rtl/tx_uart.v \
    rtl/tx_controller.v \
    rtl/tx_tick_cnt.v \
    rtl/tx_bit_cnt.v \
    rtl/tx_stop_cnt.v \
    rtl/tx_parity.v \
    rtl/tx_piso.v \
    rtl/rx_uart.v \
    rtl/rx_controller.v \
    rtl/data_b_num.v \
    rtl/stop_b_num.v \
    rtl/bit_cnt.v \
    rtl/tick_cnt.v \
    rtl/sipo.v \
    rtl/deframe.v \
    rtl/error_check.v \
    tb/tb_apb_uart.v

# 2. Chạy mô phỏng
vvp sim_apb_uart.vvp

# 3. Mở xem dạng sóng trên GTKWave
gtkwave wave_apb_uart.vcd
```

### 6.3. Các Tín Hiệu Quan Trọng Cần Kéo Vào Xem Trên GTKWave:
1. **Bus APB**: `clk`, `rst_n`, `psel`, `penable`, `pwrite`, `paddr`, `pwdata`, `prdata`, `pready`, `pslverr`.
2. **UART Nối Tiếp**: `tx` (quan sát từng bit phát ra), `rx` (quan sát từng bit đưa vào).
3. **Thanh ghi nội bộ**: `dut.u_uart_regs.stt_reg` (quan sát các cờ 0, 1, 2 chuyển trạng thái), `dut.baud_tick`.

---

## 7. Phụ Lục: Module `tx_uart.v` Chuẩn Đồng Bộ Với `apb_uart.v`

Nếu file `rtl/tx_uart.v` hiện tại của nhóm bạn bị lỗi cổng cũ hoặc thiếu `bit_counter`, bạn có thể dùng mã nguồn chuẩn hóa dưới đây để đồng bộ 100% với `apb_uart.v`:

```verilog
module tx_uart (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start_tx,
    input  wire [7:0] tx_data,
    input  wire [1:0] data_bit_num,
    input  wire       stop_bit_num,
    input  wire       parity_en,
    input  wire       parity_type, // 0: Even, 1: Odd
    input  wire       baud_tick,
    output reg        tx,
    output reg        tx_done
);

    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam PAR   = 3'b011;
    localparam STOP  = 3'b100;

    reg [2:0] state;
    reg [3:0] tick_cnt;
    reg [2:0] bit_idx;
    reg [7:0] data_reg;
    reg [2:0] max_bits;

    // Tính toán số bit data thực tế
    always @(*) begin
        case (data_bit_num)
            2'b00: max_bits = 3'd5;
            2'b01: max_bits = 3'd6;
            2'b10: max_bits = 3'd7;
            2'b11: max_bits = 3'd8;
        endcase
    end

    wire parity_bit = (parity_type == 1'b0) ? (^data_reg) : ~(^data_reg);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            tx       <= 1'b1;
            tx_done  <= 1'b1;
            tick_cnt <= 4'd0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    tx_done <= 1'b1;
                    if (start_tx) begin
                        data_reg <= tx_data;
                        state    <= START;
                        tx       <= 1'b0; // Start bit
                        tx_done  <= 1'b0;
                        tick_cnt <= 4'd0;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            state    <= DATA;
                            bit_idx  <= 3'd0;
                            tx       <= data_reg[0];
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            if (bit_idx == max_bits - 1) begin
                                if (parity_en) begin
                                    state <= PAR;
                                    tx    <= parity_bit;
                                end else begin
                                    state <= STOP;
                                    tx    <= 1'b1;
                                end
                            end else begin
                                bit_idx <= bit_idx + 1'b1;
                                tx      <= data_reg[bit_idx + 1];
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                PAR: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= 4'd0;
                            state    <= STOP;
                            tx       <= 1'b1; // Stop bit
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        if (tick_cnt == 4'd15) begin
                            state   <= IDLE;
                            tx_done <= 1'b1;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
```

---

## 8. Lời Khuyên Của Kỹ Sư Verification Để Tiến Bộ Vượt Bậc

1. **Hiểu rõ DUT trước khi viết test**: Đừng bao giờ viết testbench khi chưa hiểu rõ bản đồ thanh ghi (Register Map) và các cờ trạng thái.
2. **Kỹ thuật chia nhỏ module (Task Modularization)**: Mỗi thao tác lặp lại trên bus hoặc trên chân ngoại vi hãy đóng gói thành 1 `task`. File testbench chính sẽ cực kỳ ngắn gọn và giống như một kịch bản kiểm thử bằng ngôn ngữ tự nhiên.
3. **Luôn có cơ chế Timeout**: Mọi vòng lặp `while` chờ cờ phần cứng bắt buộc phải có biến đếm timeout để bảo vệ mô phỏng không bị treo.
4. **Kiểm tra cả trường hợp đúng lẫn trường hợp sai**: Một kỹ sư kiểm thử giỏi được đánh giá qua khả năng phát hiện lỗi biên (Corner Cases) và bơm lỗi (Error Injection), chứ không chỉ chạy mỗi kịch bản bình thường!
