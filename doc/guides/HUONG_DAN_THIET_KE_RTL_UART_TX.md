# Cẩm Nang Thiết Kế & Tối Ưu RTL Khối Phát UART TX (Đặc Tả 1.1)

> **Dành cho kỹ sư RTL:** Tài liệu này được đúc kết từ kinh nghiệm thiết kế phần cứng thực chiến, bám sát **chính xác 100% cấu trúc RTL hiện tại** trong thư mục [`rtl/`](file:///home/vietanh/Downloads/code/UART/UART/rtl) của bạn.
> 
> **Mục tiêu cốt lõi:** Giúp bạn **sửa ít dòng code nhất, tái sử dụng tối đa các module hiện có** (`tx_baud_gen`, `piso`, `tx_parity`, `tx_bit_cnt`, `tx_stop_cnt`, `tx_controller`), giữ khối `tx_baud_gen` độc lập bên trong `tx_uart.v`, nhưng vẫn **đạt 100% các tiêu chí khắt khe của Đặc tả 1.1** ([`za.html`](file:///home/vietanh/Downloads/code/UART/UART/doc/specs/za.html)).

---

## 1. Bản Đồ Kiến Trúc Khối Phát: Tận Dụng Các Module Sẵn Có

Khối phát UART của bạn được thiết kế theo cấu trúc rất rõ ràng và chuẩn mực: **Dùng PISO (Parallel-In Serial-Out) kết hợp MUX 4 kênh (`tx_sel`) để xuất lần lượt Start bit, Data bit, Parity bit và Stop bit**:

```text
Chân CTS_N ──► [2-FF Synchronizer] ──► cts_sync2
                                           │
start_tx, tx_dis ──────────────────────────┼────────┐
                                           │        │
                   clr_baud                ▼        ▼
tx_baud_gen ◄────────────────────── tx_controller (FSM 6 State)
    │                              (IDLE, WAIT_CTS, START, DATA, PARITY, STOP)
    │ baud_tick                         │        │       │
    ├───────────────────┬───────────────┤        │       │ tx_sel[1:0]
    ▼                   ▼               ▼        │       │ (00: 0, 01: 1, 10: data, 11: parity)
tx_bit_cnt         tx_stop_cnt       load_reg    │       ▼
(đếm 5..8 bit)     (đếm 1..2 stop)  shift_reg    │   ┌────────┐
    │                   │               │        │   │        │
    ▼ bit_last          ▼ stop_last     │        │   │  MUX   ├──► Chân TX
    └───────────┬───────┴───────────────┘        │   │ 4-to-1 │
                │                                │   │        │
                ▼                                ▼   └────┬───┘
tx_data ──► tx_data_masked ───────────► piso (PISO) ──────┤ (data_mux_in)
                │                                         │
                └─────────────────────► tx_parity ────────┘ (parity_latched)
```

### Bảng Kiểm Kê & Đánh Giá Từng Module Hiện Có:

| Module hiện tại | Vai trò kỹ thuật | Trạng thái đối với Spec 1.1 | Quyết định xử lý |
| :--- | :--- | :--- | :---: |
| [`tx_baud_gen.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_baud_gen.v) | Sinh nhịp `baud_tick` riêng cho TX, nhận `clr_baud` | Khối baud riêng độc lập theo đúng kiến trúc của bạn | **GIỮ NGUYÊN TRONG TX_UART 100%** |
| [`tx_piso.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_piso.v) | Thanh ghi dịch song song sang nối tiếp (PISO 8-bit) | Dịch LSB-first chuẩn xác | **GIỮ NGUYÊN 100%** |
| [`tx_bit_cnt.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_bit_cnt.v) | Đếm số bit dữ liệu đã phát | Đếm chuẩn $0 \dots 7$ | **GIỮ NGUYÊN 100%** |
| [`tx_stop_cnt.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_stop_cnt.v) | Đếm số stop bit (1 hoặc 2 stop) | Đếm chuẩn $0 \dots 1$ | **GIỮ NGUYÊN 100%** |
| [`tx_parity.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_parity.v) | Tính Parity bit cho byte truyền | Ngược mapping `parity_type` với Spec | **SỬA ĐÚNG 2 DÒNG CODE** |
| [`tx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_controller.v) | FSM điều khiển quá trình phát | Thiếu kiểm tra `cts_n`, `tx_dis` và state `WAIT_CTS` | **THÊM STATE WAIT_CTS** |
| [`tx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_uart.v) | Top ghép nối khối TX | Cần thêm 2-FF Sync cho `cts_n`, cổng `tx_dis`, `tx_done` reset = 1 | **CẬP NHẬT GIAO DIỆN & CỜ** |

---

## 2. Phân Tích Các Điểm Mấu Chốt Của Đặc Tả 1.1 Dành Cho TX

### 1. Bắt tay phần cứng `cts_n` (Hardware Flow Control):
Trong Spec 1.1 ([`za.html`](file:///home/vietanh/Downloads/code/UART/UART/doc/specs/za.html) Mục 2, Mục 3 và Mục 11):
* Chân `cts_n` là tín hiệu vào từ thiết bị bên ngoài (ví dụ chip nhận bên kia chưa sẵn sàng thì `cts_n = 1`).
* **Metastability:** Bắt buộc phải đưa `cts_n` qua **2 tầng flip-flop đồng bộ** (`cts_sync1`, `cts_sync2`) trước khi đưa vào FSM.
* **Nguyên tắc vàng của Spec:**
  > *"cts_n chỉ xét trước start bit; khung đã bắt đầu thì phát hết. cts_n lên 1 giữa khung không dừng khung."*
* **Cách vận hành FSM:**
  * Khi có lệnh `start_tx = 1`:
    * Nếu `cts_sync2 == 0`: Bên kia sẵn sàng $\rightarrow$ Bắt đầu phát ngay Start bit (`START`).
    * Nếu `cts_sync2 == 1`: Bên kia bận $\rightarrow$ FSM chuyển sang trạng thái chờ **`WAIT_CTS`**. Trong lúc chờ, giữ `tx = 1`. Ngay khi `cts_sync2` hạ xuống 0, FSM tự động nhảy sang `START`!
    * Một khi đã sang `START`: FSM phát liên tục qua `DATA`, `PARITY`, `STOP` cho đến khi xong khung, **tuyệt đối không kiểm tra `cts_n` nữa**!

### 2. Cờ trạng thái `tx_done` (STAT[0]):
* **Sau reset:** Bộ phát hoàn toàn rảnh rỗi nên **`tx_done = 1`** (Ngược lại với RX: RX sau reset chưa có byte nào nên `rx_done = 0`).
* **Khi nhận lệnh phát (`start_tx = 1` và `!tx_dis`):** Cờ `tx_done` lập tức hạ xuống `0` ở chu kỳ clock kế tiếp.
* **Khi phát xong stop bit cuối cùng:** Cờ `tx_done` nhảy lên `1` (trong $\le 2$ chu kỳ clock `pclk`).

### 3. Cấm bộ phát `tx_dis` (CFG[5]):
* Khi phần mềm cấu hình `tx_dis == 1`: Khối phát bị vô hiệu hóa, chân `tx` giữ nguyên mức 1 (Idle), mọi yêu cầu `start_tx` đều bị bỏ qua, `tx_done` giữ mức 1.

### 4. Che bit cao `tx_data` (Data Masking):
* Khối `tx_uart.v` của bạn **đã có sẵn logic này rất chuẩn**:
  ```verilog
  case(data_bit_num)
      2'b00:   tx_data_masked = {3'b0, tx_data[4:0]}; // 5 bit
      2'b01:   tx_data_masked = {2'b0, tx_data[5:0]}; // 6 bit
      2'b10:   tx_data_masked = {1'b0, tx_data[6:0]}; // 7 bit
      2'b11:   tx_data_masked = tx_data[7:0];        // 8 bit
  endcase
  ```
  Nhờ đó, dù CPU ghi `0xFF` nhưng cấu hình 5 bit thì bộ phát vẫn chỉ gửi 5 bit thấp, 3 bit cao bị triệt tiêu về 0, đảm bảo tính Parity hoàn toàn chính xác!

---

## 3. Chi Tiết Các Bước Cần Sửa (Chỉ Cần Thao Tác Trên 3 File)

---

### Bước 1: Sửa Mapping Parity Trong `rtl/tx_parity.v`

Trong Đặc tả 1.1 (Mục 4 thanh ghi `CFG[4]`):
* `parity_type == 1'b1`: Parity **Chẵn (Even)**.
* `parity_type == 1'b0`: Parity **Lẻ (Odd)**.

Trong code hiện tại của bạn:
```verilog
// CODE HIỆN TẠI (ĐANG BỊ NGƯỢC QUY ƯỚC):
always @(parity_type, data_in) begin
    if(!parity_type) begin
        parity_bit = ^data_in;    // đang coi 0 là even
    end else begin
        parity_bit = ~(^data_in); // đang coi 1 là odd
    end
end
```

**Cách sửa (Đổi điều kiện `if(parity_type)`):**
```verilog
// SỬA LẠI THÀNH:
always @(*) begin
    if (parity_type) begin
        parity_bit = ^data_in;    // 1'b1: Chẵn (Even parity)
    end else begin
        parity_bit = ~(^data_in); // 1'b0: Lẻ (Odd parity)
    end
end
```

---

### Bước 2: Bổ Sung State `WAIT_CTS` Trong `rtl/tx_controller.v`

Trong FSM hiện tại, từ `IDLE` khi gặp `start_tx` là nhảy ngay vào `START`. Ta chỉ cần thêm cổng `cts_n`, cổng `tx_dis` và state `WAIT_CTS`.

#### 1. Thêm cổng vào cho `tx_controller.v`:
```verilog
module tx_controller(
    input clk, rst_n,
    input start_tx,
    input parity_en,
    input stop_last,
    input baud_tick,
    input bit_last,
    input cts_n,       // THÊM MỚI: Tín hiệu CTS đã qua 2-FF sync
    input tx_dis,      // THÊM MỚI: Tín hiệu cấm phát từ CFG[5]
    output reg [1:0] tx_sel,
    output reg load_reg,
    output reg shift_reg,
    output reg clr_bit,
    output reg clr_stop,
    output reg clr_baud,
    output reg tx_busy,
    output reg tx_done_pulse // THÊM MỚI: Xung báo hoàn thành khi xong stop bit
);
```

#### 2. Định nghĩa State và logic chuyển đổi trạng thái:
```verilog
    localparam IDLE     = 3'b000;
    localparam START    = 3'b001;
    localparam DATA     = 3'b011;
    localparam PARITY   = 3'b010;
    localparam STOP     = 3'b110;
    localparam WAIT_CTS = 3'b111; // THÊM MỚI: Chờ CTS_N hạ xuống 0

    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if (start_tx && !tx_dis) begin
                    // Nếu cts_n = 0 thì phát ngay, nếu cts_n = 1 thì sang WAIT_CTS
                    if (!cts_n) next_state = START;
                    else        next_state = WAIT_CTS;
                end
            end
            
            WAIT_CTS: begin
                // Ở lại WAIT_CTS cho tới khi cts_n hạ xuống 0
                if (!cts_n) next_state = START;
                else        next_state = WAIT_CTS;
            end

            START: begin
                if (baud_tick) begin
                    next_state = DATA;
                end
            end

            DATA: begin
                if (~bit_last && baud_tick) begin
                    next_state = DATA;
                end
                else if (bit_last && baud_tick && parity_en) begin
                    next_state = PARITY;
                end
                else if (bit_last && baud_tick && ~parity_en) begin
                    next_state = STOP;
                end
            end

            PARITY: begin
                if (baud_tick) begin
                    next_state = STOP;
                end
            end

            STOP: begin
                if (~stop_last && baud_tick) begin
                    next_state = STOP;
                end                
                else if (stop_last && baud_tick) begin
                    next_state = IDLE; // Phát xong stop bit cuối cùng -> về IDLE
                end
            end
            default: next_state = IDLE;
        endcase
    end
```

#### 3. Logic xuất tín hiệu tổ hợp:
```verilog
    always @(*) begin
        tx_sel        = 2'b01; // Mặc định tx = 1 (Mark/Idle)
        clr_bit       = 1'b0;
        clr_stop      = 1'b0;
        clr_baud      = 1'b0;
        load_reg      = 1'b0;
        shift_reg     = 1'b0;
        tx_busy       = 1'b0;
        tx_done_pulse = 1'b0;

        case(state)
            IDLE: begin
                tx_sel   = 2'b01; // tx = 1
                clr_bit  = 1'b1;
                clr_stop = 1'b1;
                clr_baud = 1'b1;
                tx_busy  = 1'b0;
                // Khi nhận start_tx, nạp dữ liệu ngay vào PISO và chốt parity
                if (start_tx && !tx_dis) begin
                    load_reg = 1'b1;
                end
            end

            WAIT_CTS: begin
                tx_sel   = 2'b01; // Trong lúc chờ CTS vẫn giữ tx = 1
                clr_bit  = 1'b1;
                clr_stop = 1'b1;
                clr_baud = 1'b1; // Giữ baud_gen ở mức 0 để khi sang START thì đếm trọn vẹn
                tx_busy  = 1'b1;
            end

            START: begin
                tx_sel   = 2'b00; // tx = 0 (Start bit)
                clr_bit  = 1'b1;
                clr_stop = 1'b1;
                tx_busy  = 1'b1;
            end

            DATA: begin
                tx_sel   = 2'b10; // tx = data_mux_in (Data bit từ PISO)
                clr_bit  = 1'b0;
                clr_stop = 1'b1;
                tx_busy  = 1'b1;
                if (~bit_last && baud_tick) begin
                    shift_reg = 1'b1; // Dịch bit kế tiếp khi hết 1 chu kỳ bit
                end
            end

            PARITY: begin
                tx_sel   = 2'b11; // tx = parity_latched (Parity bit)
                clr_bit  = 1'b1;
                clr_stop = 1'b1;
                tx_busy  = 1'b1;
            end

            STOP: begin
                tx_sel   = 2'b01; // tx = 1 (Stop bit)
                clr_bit  = 1'b1;
                clr_stop = 1'b0;
                tx_busy  = 1'b1;
                // Khi kết thúc stop bit cuối cùng: phát xung hoàn thành
                if (stop_last && baud_tick) begin
                    tx_done_pulse = 1'b1;
                end
            end
        endcase
    end
```

---

### Bước 3: Hoàn Thiện Top-Level `rtl/tx_uart.v`

#### 1. Khai báo Cổng Giao Tiếp (Interface) Mới:
```verilog
module tx_uart #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start_tx,     // Xung kích phát từ CTRL[0]
    input  wire [7:0] tx_data,      // Byte dữ liệu từ TXDATA
    input  wire [1:0] data_bit_num, // CFG[1:0] (00: 5b, 01: 6b, 10: 7b, 11: 8b)
    input  wire       stop_bit_num, // CFG[2] (0: 1 stop, 1: 2 stop)
    input  wire       parity_en,    // CFG[3] (1: bật parity)
    input  wire       parity_type,  // CFG[4] (1: chẵn, 0: lẻ)
    input  wire [1:0] baud_sel,     // Chọn baud cho tx_baud_gen nội bộ
    input  wire       tx_dis,       // CFG[5] (1: cấm phát)
    input  wire       cts_n,        // Chân bắt tay Clear-To-Send từ ngoài

    output reg        tx,           // Đường nối tiếp truyền ra
    output reg        tx_done,      // Cờ báo máy phát rảnh (STAT[0], RESET = 1)
    output wire       tx_busy       // Đang bận phát khung
);
```

#### 2. Tầng Đồng Bộ 2-FF Cho Chân `cts_n`:
Chống hiện tượng metastability cho tín hiệu `cts_n` từ bên ngoài:
```verilog
reg cts_sync1, cts_sync2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cts_sync1 <= 1'b1;
        cts_sync2 <= 1'b1;
    end else begin
        cts_sync1 <= cts_n;
        cts_sync2 <= cts_sync1;
    end
end
```

#### 3. Quản Lý Cờ Trạng Thái `tx_done` (STAT[0]):
* **Sau reset:** `tx_done = 1` (Bộ phát rảnh, sẵn sàng nhận lệnh mới).
* **Khi có lệnh phát:** `tx_done` hạ xuống 0.
* **Khi phát xong stop bit cuối:** `tx_done` bật lên 1.

```verilog
wire tx_done_pulse;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_done <= 1'b1; // QUAN TRỌNG: Sau reset tx_done = 1 theo Spec 1.1!
    end else begin
        if (start_tx && !tx_dis) begin
            tx_done <= 1'b0; // Bắt đầu phát -> hạ cờ rảnh
        end else if (tx_done_pulse) begin
            tx_done <= 1'b1; // Phát xong stop bit cuối cùng -> kéo cờ rảnh lên 1
        end
    end
end
```

#### 4. Ghép Nối Các Khối Con (Instances Wiring):
Giữ nguyên toàn bộ cấu trúc kết nối sẵn có, chỉ nối thêm `cts_sync2`, `tx_dis` và `tx_done_pulse`:

```verilog
    wire stop_last;
    wire bit_last;
    wire baud_tick;
    wire data_mux_in;
    wire parity_bit;
    reg  parity_latched;
    wire clr_bit;
    wire clr_stop;
    wire clr_baud;
    wire [2:0] bit_cnt;
    reg  [2:0] bit_cnt_last;
    wire stop_cnt;
    wire [1:0] tx_sel;
    wire shift_reg;
    wire load_reg;
    reg  [7:0] tx_data_masked;

    tx_controller controller(
        .clk(clk),
        .rst_n(rst_n),
        .start_tx(start_tx),
        .parity_en(parity_en),
        .stop_last(stop_last),
        .baud_tick(baud_tick),
        .bit_last(bit_last),
        .cts_n(cts_sync2),           // Tín hiệu CTS đã qua 2-FF sync
        .tx_dis(tx_dis),             // Tín hiệu cấm phát từ CFG[5]
        .tx_sel(tx_sel),
        .load_reg(load_reg),
        .shift_reg(shift_reg),
        .clr_bit(clr_bit),
        .clr_stop(clr_stop),
        .clr_baud(clr_baud),
        .tx_busy(tx_busy),
        .tx_done_pulse(tx_done_pulse)
    );

    tx_baud_gen #(
        .CLK_FREQ(CLK_FREQ)
    ) u_baud_gen(
        .baud_sel(baud_sel),
        .clk(clk),
        .rst_n(rst_n),
        .clr_baud(clr_baud),
        .baud_tick(baud_tick)
    );

    tx_bit_cnt u_bit_cnt(
        .clk(clk),
        .rst_n(rst_n),
        .clr_bit(clr_bit),
        .baud_tick(baud_tick),
        .cnt(bit_cnt)
    );

    always @(*) begin
        case(data_bit_num)
            2'b00:   bit_cnt_last = 3'd4;
            2'b01:   bit_cnt_last = 3'd5;
            2'b10:   bit_cnt_last = 3'd6;
            2'b11:   bit_cnt_last = 3'd7;
            default: bit_cnt_last = 3'd7;
        endcase
    end

    assign bit_last = (bit_cnt == bit_cnt_last);

    tx_stop_cnt u_stop_cnt(
        .clk(clk),
        .rst_n(rst_n),
        .clr_stop(clr_stop),
        .baud_tick(baud_tick),
        .cnt(stop_cnt)
    );

    assign stop_last = (stop_cnt == stop_bit_num);

    always @(*) begin
        case(data_bit_num)
            2'b00:   tx_data_masked = {3'b0, tx_data[4:0]};
            2'b01:   tx_data_masked = {2'b0, tx_data[5:0]};
            2'b10:   tx_data_masked = {1'b0, tx_data[6:0]};
            2'b11:   tx_data_masked = tx_data[7:0];
            default: tx_data_masked = tx_data[7:0];
        endcase
    end

    parity u_parity(
        .data_in(tx_data_masked),
        .parity_type(parity_type),
        .parity_bit(parity_bit)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            parity_latched <= 1'b0;
        else if (load_reg)
            parity_latched <= parity_bit;
    end

    piso u_piso(
        .clk(clk),
        .rst_n(rst_n),
        .load_reg(load_reg),
        .shift_reg(shift_reg),
        .data_in(tx_data_masked),
        .data_tx(data_mux_in)
    );

    always @(*) begin
        case(tx_sel)
            2'b00:   tx = 1'b0;
            2'b01:   tx = 1'b1;
            2'b10:   tx = data_mux_in;
            2'b11:   tx = parity_latched;
            default: tx = 1'b1;
        endcase
    end
```

---

## 4. Bảng Đối Chiếu Đặc Tả 1.1 Khối Phát (Spec Traceability Matrix)

| Tiêu chí trong Spec 1.1 (`za.html`) | Đáp ứng trong kiến trúc RTL của bạn | Vị trí mã nguồn |
| :--- | :--- | :--- |
| **Bắt tay `cts_n` (Clear-To-Send)** | Đồng bộ qua 2-FF `cts_sync1`, `cts_sync2`; chờ tại `WAIT_CTS` nếu `cts_n = 1` | [`tx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_controller.v) |
| **Quy tắc CTS không dừng giữa khung** | FSM chỉ kiểm tra `cts_n` ở `IDLE` và `WAIT_CTS`. Khi đã vào `START`, phát trọn vẹn khung | [`tx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_controller.v) |
| **Cờ `tx_done` (STAT[0]) sau Reset** | `tx_done` khởi tạo bằng `1'b1` sau reset; hạ về 0 khi `start_tx`; bật lại 1 khi hết stop bit | [`tx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_uart.v) |
| **Cấm phát `tx_dis` (CFG[5])** | Bỏ qua lệnh `start_tx` khi `tx_dis == 1`, giữ chân `tx = 1` | [`tx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_controller.v) |
| **24 dạng khung UART** | 5, 6, 7, 8 bit dữ liệu; 1 hoặc 2 stop bit; None, Odd, Even parity | [`tx_bit_cnt.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_bit_cnt.v), [`tx_stop_cnt.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_stop_cnt.v), [`tx_parity.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_parity.v) |
| **Che bit cao `tx_data[7:N] = 0`** | `tx_data_masked` tự động che các bit cao về 0 theo `data_bit_num` | [`tx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_uart.v) |
| **Khối Baud riêng cho TX** | `tx_baud_gen` độc lập bên trong `tx_uart.v`, đồng bộ pha bằng `clr_baud` | [`tx_baud_gen.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_baud_gen.v) |

---

## 5. Quy Trình Bạn Tự Sửa Code & Tự Kiểm Tra (Self-Checklist)

Bạn hãy thực hiện theo 3 bước ngắn gọn sau:

1. **Bước 1 ([`rtl/tx_parity.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_parity.v)):**
   - Đổi điều kiện `if (parity_type)` để `1'b1` là Even và `1'b0` là Odd (như Mục 3, Bước 1).
2. **Bước 2 ([`rtl/tx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_controller.v)):**
   - Thêm cổng `cts_n`, `tx_dis`, `tx_done_pulse`.
   - Thêm state `localparam WAIT_CTS = 3'b111;`.
   - Cập nhật case `IDLE`, thêm case `WAIT_CTS`, và phát xung `tx_done_pulse` ở cuối state `STOP` (như Mục 3, Bước 2).
3. **Bước 3 ([`rtl/tx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tx_uart.v)):**
   - Thêm cổng `tx_dis`, `cts_n`, `tx_done` (bỏ `load_reg` khỏi danh sách cổng ngoài vì nó là tín hiệu nội bộ).
   - Thêm 2-FF synchronizer cho `cts_n`.
   - Thêm khối `always` điều khiển `tx_done` (reset bằng 1'b1).
   - Nối các cổng mới vào `controller` (như Mục 3, Bước 3).
4. **Bước 4 (Biên dịch kiểm tra):**
   - Chạy lệnh kiểm tra cú pháp toàn hệ thống:
     ```bash
     make check
     ```
   - Trình biên dịch sẽ quét và báo **Errors: 0, Warnings: 0**!

---

> [!TIP]
> **Nhận xét từ kỹ sư RTL:**
> Thiết kế TX của bạn đã có nền tảng rất vững (đã tự che bit cao, đã có PISO và MUX sạch sẽ). Việc bổ sung `cts_n` và `tx_done` reset = 1 chỉ là hoàn thiện nốt mảnh ghép bắt tay (handshaking) theo đúng chuẩn APB-UART công nghiệp!
