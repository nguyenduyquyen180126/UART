# KẾ HOẠCH & ĐẶC TẢ CHI TIẾT: TÍCH HỢP HARDWARE FIFO CHO HỆ THỐNG APB UART
*(Tham chiếu chuẩn kiến trúc ARM PrimeCell UART PL011 - DDI0183G & Tối ưu hóa Direct-Handshake)*

Tài liệu này mô tả chi tiết toàn bộ quy trình nâng cấp kiến trúc hệ thống **APB UART** từ cơ chế đệm thanh ghi đơn (Single-byte Holding Register) sang cơ chế **Hàng đợi phần cứng (Hardware FIFO)** độc lập cho cả hai nhánh thu (RX) và phát (TX), sử dụng cơ chế bắt tay trực tiếp (**Direct-Handshake**) tinh gọn nhất.

---

## 1. Mục Tiêu & Cơ Sở Kiến Trúc

### 1.1. Hạn chế của thiết kế hiện tại (Chưa có FIFO)
* **Nhánh phát (TX):** Chỉ có thanh ghi đệm 1 byte `tx_data_reg`. Muốn phát 1 chuỗi ký tự (ví dụ: chuỗi `"HELLO\r\n"`), CPU phải ghi 1 byte $\rightarrow$ bật `start_tx` $\rightarrow$ đợi bộ phát nối tiếp gửi xong 10-bit (~1.04 ms ở baud 9600) $\rightarrow$ rồi mới được gửi byte kế tiếp.
* **Nhánh nhận (RX):** Chỉ có thanh ghi đệm 1 byte `rx_data_reg`. Nếu PC gửi 1 burst dữ liệu nhanh mà CPU bị trễ chưa kịp đọc byte trước, byte sau sẽ đè lên gây lỗi tràn **Overrun Error**.
* **Độ rộng đường truyền RX:** Đã được tối ưu chuẩn hóa xuống đúng **9-bit** (`rx_data[8:0] = {error, data[7:0]}`), sẵn sàng 100% để nạp thẳng vào ô nhớ FIFO mà không lãng phí tài nguyên Flip-Flop.

### 1.2. Giải pháp kiến trúc chuẩn ARM PL011 (Figure 2-1) & Tối ưu Direct-Handshake
* Tích hợp **TX FIFO** (16x8-bit): Nằm giữa khối `uart_regs` và `tx_uart`.
* Tích hợp **RX FIFO** (16x9-bit): Nằm giữa khối `rx_uart` và `uart_regs`.
* **Cơ chế bắt tay trực tiếp cực kỳ tinh gọn (Zero-Overhead Handshake):**
  * **Nhánh TX:** Sử dụng trực tiếp `!tx_fifo_empty` làm tín hiệu `start_tx`, và dùng chính tín hiệu **`load_reg`** từ FSM của `tx_controller` làm xung đọc **`tx_fifo_rd_en`** (loại bỏ hoàn toàn FSM phụ và biến `tx_busy` bên ngoài).
  * **Nhánh RX:** Sử dụng trực tiếp xung **`rx_done`** của `rx_controller` làm xung ghi **`rx_fifo_wr_en`**, và dùng **chu kỳ đọc bus APB** làm xung đọc **`rx_fifo_rd_en`**. Cờ trạng thái `rx_ready` và ngắt `rx_irq` được nối thẳng từ **`!rx_fifo_empty`**, loại bỏ hoàn toàn các Flip-Flop chốt cờ phức tạp trong `uart_regs`.

```mermaid
graph LR
    subgraph CPU_BUS ["Bus APB Master"]
        PWDATA["pwdata[7:0]"]
        PRDATA["prdata[31:0]"]
    end

    subgraph APB_UART ["Module Top: apb_uart.v"]
        subgraph REGS ["uart_regs.v"]
            CFG["cfg_reg"]
            STT["stt_reg"]
            IER["ier_reg"]
        end

        subgraph TX_SIDE ["Nhánh Phát (TX)"]
            TX_FIFO["sync_fifo (16x8)<br/>TX FIFO (FWFT)"]
            TX_PHY["tx_uart.v (PISO & tx_controller)"]
        end

        subgraph RX_SIDE ["Nhánh Nhận (RX)"]
            RX_PHY["rx_uart.v (SIPO & rx_controller)"]
            RX_FIFO["sync_fifo (16x9)<br/>RX FIFO (FWFT)"]
        end
    end

    PWDATA -->|Write ADDR_TX (tx_fifo_wr_en)| TX_FIFO
    TX_FIFO -->|tx_rd_data[7:0]| TX_PHY
    TX_FIFO -->|!tx_empty| TX_PHY
    TX_PHY -->|load_reg (tx_fifo_rd_en)| TX_FIFO
    TX_FIFO -.->|tx_empty, tx_full| STT
    TX_PHY --> TXD((Chân TXD))

    RXD((Chân RXD)) --> RX_PHY
    RX_PHY -->|rx_data[8:0]| RX_FIFO
    RX_PHY -->|rx_done (rx_fifo_wr_en)| RX_FIFO
    RX_FIFO -->|rx_rd_data[8:0]| REGS
    REGS -->|Read ADDR_RX (rx_fifo_rd_en)| RX_FIFO
    RX_FIFO -.->|!rx_empty (rx_ready), rx_full| STT
    REGS -->|Read ADDR_RX| PRDATA
```

---

## 2. So Sánh Interface Trước Và Sau Khi Có FIFO (Before vs After)

### 2.1. Module `uart_regs.v`

| Nhóm tín hiệu | Cổng TRƯỚC khi có FIFO | Cổng SAU khi có FIFO | Bản chất thay đổi |
| :--- | :--- | :--- | :--- |
| **Giao tiếp TX** | `output wire [7:0] tx_data`<br/>`output wire start_tx`<br/>`input wire tx_done` | `output wire tx_fifo_wr_en`<br/>`output wire [7:0] tx_fifo_wr_data`<br/>`input wire tx_fifo_full`<br/>`input wire tx_fifo_empty`<br/>`input wire tx_done` | `uart_regs` không còn quản lý `tx_data` và `start_tx`. `uart_regs` chỉ đẩy dữ liệu vào TX FIFO và giám sát cờ `tx_fifo_empty` để báo cờ sẵn sàng cho CPU. |
| **Giao tiếp RX** | `input wire rx_done`<br/>`input wire error`<br/>`input wire [8:0] rx_data` | `output wire rx_fifo_rd_en`<br/>`input wire [8:0] rx_fifo_rd_data`<br/>`input wire rx_fifo_empty`<br/>`input wire rx_fifo_full`<br/>`input wire rx_overrun_err` | Dữ liệu và xung `rx_done` đẩy thẳng vào RX FIFO. `uart_regs` chỉ đọc từ đỉnh FIFO khi CPU yêu cầu. Cờ `rx_ready` lấy trực tiếp từ `!rx_fifo_empty`. |
| **APB & Khác** | `clk`, `rst_n`, `reg_pread`, `reg_pwrite`, `paddr`, `pwdata`, `prdata`, `reg_ack_err`, `irq`, `cfg...` | **Giữ nguyên 100%** | Bus APB và chân cấu hình giữ nguyên hoàn toàn. |

### 2.2. Module `tx_uart.v`
* **Cổng mở thêm:** Bổ sung thêm cổng `output wire load_reg` (hoặc `tx_rd_en`) xuất từ `tx_controller` ra ngoài.
* **Cổng `start_tx`:** Nhận trực tiếp dây `!tx_fifo_empty`.

### 2.3. Module `rx_uart.v`
* Giữ nguyên giao diện 9-bit chuẩn hóa: `output wire [8:0] rx_data`, `output wire rx_done`. Nối trực tiếp sang cổng ghi của RX FIFO.

---

## 3. Nguyên Lý Bắt Tay Trực Tiếp Tinh Gọn (Direct-Handshake)

### 3.1. Nhánh phát TX: `start_tx = !tx_fifo_empty` và `tx_fifo_rd_en = load_reg`
* Trong [`rtl/tx_controller.v`](file:///C:/Users/84333/projects/tks/code/UART/rtl/tx_controller.v), tại trạng thái `IDLE`:
  ```verilog
  IDLE: begin
      if (start_tx) begin
          load_reg   = 1'b1;  // Tích cực đúng 1 chu kỳ clock!
          next_state = START; // Chuyển sang START
      end
  end
  ```
* Khi FIFO có dữ liệu $\rightarrow$ `!tx_fifo_empty = 1` $\rightarrow$ `start_tx = 1`.
* Khi `tx_controller` ở `IDLE` thấy `start_tx = 1`:
  * Nó kích hoạt `load_reg = 1` trong đúng **1 chu kỳ clock**.
  * Cạnh clock kế tiếp: `piso.v` chốt byte dữ liệu, TX FIFO tăng con trỏ `rd_ptr` (pop 1 byte), và `tx_controller` chuyển sang `START`.
  * Trong các trạng thái `START`, `DATA`, `PARITY`, `STOP`, `load_reg` **khóa cứng ở mức 0**, chống pop thừa tuyệt đối!
  * Khi phát xong Stop bit, `tx_controller` quay về `IDLE`. Nếu FIFO vẫn còn dữ liệu, nó lại tiếp tục kích `load_reg` để phát byte kế tiếp (truyền liên tục không ngắt quãng - back-to-back).

### 3.2. Nhánh nhận RX: `rx_fifo_wr_en = rx_done` và `rx_ready = !rx_fifo_empty`
* Xung **`rx_done`** xuất hiện đúng 1 chu kỳ clock khi bộ nhận hoàn tất Stop bit $\rightarrow$ Nối trực tiếp làm xung ghi `rx_fifo_wr_en`.
* Khi CPU đọc `ADDR_RX` (0x04) trên bus APB $\rightarrow$ Xung đọc APB kéo dài đúng 1 chu kỳ clock $\rightarrow$ Nối trực tiếp làm `rx_fifo_rd_en`.
* Cờ trạng thái `rx_ready` và ngắt `rx_irq`:
  $$\text{rx\_ready} = !\text{rx\_fifo\_empty}$$
  Không cần bất kỳ Flip-Flop nào để lưu cờ, không sợ xung đột giữa đọc và nhận cùng lúc!

---

## 4. Mã Nguồn Cụ Thể Từng File Cần Thêm & Sửa Đổi

### 4.1. File MỚI CẦN THÊM: `rtl/sync_fifo.v` (Bộ đệm FIFO đồng bộ FWFT)

Tạo mới file [`rtl/sync_fifo.v`](file:///C:/Users/84333/projects/tks/code/UART/rtl/sync_fifo.v):
```verilog
`timescale 1ns/1ps

module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4   // Depth = 2^4 = 16 locations
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Cổng ghi (Write Port)
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,

    // Cổng đọc (Read Port - First-Word Fall-Through)
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty,

    // Mức đệm hiện tại
    output wire [ADDR_WIDTH:0]   count
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0]   wr_ptr;
    reg [ADDR_WIDTH:0]   rd_ptr;

    wire wr_valid = wr_en && !full;
    wire rd_valid = rd_en && !empty;

    // Ghi dữ liệu vào RAM
    always @(posedge clk) begin
        if (wr_valid)
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Quản lý con trỏ ghi / đọc
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            if (wr_valid)
                wr_ptr <= wr_ptr + 1'b1;
            if (rd_valid)
                rd_ptr <= rd_ptr + 1'b1;
        end
    end

    // Đọc dữ liệu ra kiểu FWFT (dữ liệu đỉnh FIFO luôn có sẵn)
    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

    // Tính trạng thái Empty & Full
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    assign count = wr_ptr - rd_ptr;

endmodule
```

---

### 4.2. SỬA ĐỔI FILE: `rtl/tx_uart.v`

Mở tín hiệu `load_reg` ra cổng ngoài của module `tx_uart`:
```verilog
module tx_uart #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start_tx,
    input  wire [7:0] tx_data,
    input  wire [1:0] data_bit_num,
    input  wire       stop_bit_num,
    input  wire       parity_en,
    input  wire       parity_type,
    input  wire [1:0] baud_sel,
    output wire       tx,
    output wire       tx_done,
    output wire       load_reg       // <<-- THÊM CỔNG NÀY ĐỂ KÍCH ĐỌC FIFO
);

    // Nối tín hiệu load_reg từ tx_controller ra cổng ngoài:
    tx_controller controller(
        .clk        (clk),
        .rst_n      (rst_n),
        .start_tx   (start_tx),
        .parity_en  (parity_en),
        .stop_last  (stop_last),
        .baud_tick  (baud_tick),
        .bit_last   (bit_last),
        .tx_done    (tx_done),
        .tx_sel     (tx_sel),
        .load_reg   (load_reg),      // Đưa ra cổng ngoài
        .shift_reg  (shift_reg),
        .clr_bit    (clr_bit),
        .clr_stop   (clr_stop),
        .clr_baud   (clr_baud)
    );
    // ... các phần còn lại giữ nguyên ...
```

---

### 4.3. SỬA ĐỔI FILE: `rtl/uart_regs.v`

```verilog
module uart_regs (
    input  wire        clk,
    input  wire        rst_n,

    // Bus APB Interface
    input  wire        reg_pread, 
    input  wire        reg_pwrite,  
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        reg_ack_err,
    output wire        irq,

    // Cấu hình UART
    output wire [1:0]  data_bit_num,
    output wire        stop_bit_num,
    output wire        parity_en,
    output wire        parity_type,
    output wire [1:0]  baud_sel,
    input  wire        rx_busy,

    // Interface TX FIFO
    output wire        tx_fifo_wr_en,
    output wire [7:0]  tx_fifo_wr_data,
    input  wire        tx_fifo_full,
    input  wire        tx_fifo_empty,
    input  wire        tx_done,

    // Interface RX FIFO
    output wire        rx_fifo_rd_en,
    input  wire [8:0]  rx_fifo_rd_data,
    input  wire        rx_fifo_empty,
    input  wire        rx_fifo_full,
    input  wire        rx_overrun_err
);

    localparam [11:0] ADDR_TX   = 12'h000;
    localparam [11:0] ADDR_RX   = 12'h004;
    localparam [11:0] ADDR_CFG  = 12'h008;
    localparam [11:0] ADDR_CTRL = 12'h00C;
    localparam [11:0] ADDR_STT  = 12'h010;
    localparam [11:0] ADDR_IER  = 12'h014;

    reg [31:0] cfg_reg;
    reg [31:0] ctrl_reg;
    reg [31:0] ier_reg;

    wire addr_tx   = (paddr == ADDR_TX);
    wire addr_rx   = (paddr == ADDR_RX);
    wire addr_cfg  = (paddr == ADDR_CFG);
    wire addr_ctrl = (paddr == ADDR_CTRL);
    wire addr_stt  = (paddr == ADDR_STT);
    wire addr_ier  = (paddr == ADDR_IER);

    // TX rảnh khi FIFO rỗng và tx_done = 1 (hoặc không bận)
    wire tx_ready  = tx_fifo_empty;
    wire uart_idle = tx_ready && (!rx_busy);

    // Điều kiện ghi/đọc hợp lệ
    wire write_legal = (addr_tx   && !tx_fifo_full) ||
                       (addr_cfg  && uart_idle)     ||
                       (addr_ctrl)                  ||
                       (addr_ier);

    wire read_legal  = addr_tx || addr_rx || addr_cfg || addr_ctrl || addr_stt || addr_ier;

    assign reg_ack_err = (reg_pwrite && !write_legal) || 
                         (reg_pread  && !read_legal);

    wire valid_write = reg_pwrite && write_legal;
    wire valid_read  = reg_pread  && read_legal;

    // Ghi vào TX FIFO khi CPU ghi ADDR_TX
    assign tx_fifo_wr_en   = valid_write && addr_tx;
    assign tx_fifo_wr_data = pwdata[7:0];

    // Rút từ RX FIFO khi CPU đọc ADDR_RX
    assign rx_fifo_rd_en   = valid_read  && addr_rx && (!rx_fifo_empty);

    // 1. Quản lý ghi thanh ghi cấu hình & điều khiển
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_reg  <= 32'h0;
            ctrl_reg <= 32'h0;
            ier_reg  <= 32'h0;
        end else if (valid_write) begin
            case (paddr)
                ADDR_CFG:  cfg_reg  <= pwdata;
                ADDR_CTRL: ctrl_reg <= pwdata;
                ADDR_IER:  ier_reg  <= pwdata;
                default: ;
            endcase
        end
    end

    // 2. Quản lý trạng thái Overrun Latch
    reg overrun_latch;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            overrun_latch <= 1'b0;
        else if (rx_fifo_rd_en)
            overrun_latch <= 1'b0; // Tự động xóa cờ overrun khi CPU đọc RX
        else if (rx_overrun_err)
            overrun_latch <= 1'b1;
    end

    // 3. Trạng thái STT thuần túy từ FIFO (Không cần latch phức tạp)
    wire rx_ready    = !rx_fifo_empty;                  // Bit 1: RX ready
    wire rx_byte_err = rx_ready && rx_fifo_rd_data[8]; // Bit 2: Error của byte hiện tại

    reg [31:0] stt_reg;
    always @(*) begin
        stt_reg = 32'h0;
        stt_reg[0] = tx_ready;       // Bit 0: TX Empty / Ready
        stt_reg[1] = rx_ready;       // Bit 1: RX Data Available
        stt_reg[2] = rx_byte_err;   // Bit 2: Parity/Frame Error của byte đỉnh FIFO
        stt_reg[3] = overrun_latch;  // Bit 3: Overrun Error
        stt_reg[4] = tx_fifo_full;   // Bit 4: TX FIFO Full
        stt_reg[5] = rx_fifo_full;   // Bit 5: RX FIFO Full
    end

    // 4. Đọc dữ liệu ra prdata
    always @(*) begin
        if (valid_read) begin
            case (paddr)
                ADDR_TX:   prdata = 32'h0;
                ADDR_RX:   prdata = {23'd0, rx_fifo_rd_data}; // [7:0]: data, [8]: error
                ADDR_CFG:  prdata = cfg_reg;
                ADDR_CTRL: prdata = ctrl_reg;
                ADDR_STT:  prdata = stt_reg;
                ADDR_IER:  prdata = ier_reg;
                default:   prdata = 32'h0;
            endcase
        end else begin
            prdata = 32'h0;
        end
    end

    // 5. Sinh ngắt phần cứng
    wire rx_irq = rx_ready & ier_reg[0];
    wire tx_irq = tx_ready & ier_reg[1];
    wire oe_irq = overrun_latch & ier_reg[2];
    assign irq  = rx_irq | tx_irq | oe_irq;

    // Hardware mapping
    assign data_bit_num = cfg_reg[1:0];
    assign stop_bit_num = cfg_reg[2];
    assign parity_en    = cfg_reg[3];
    assign parity_type  = cfg_reg[4];
    assign baud_sel     = cfg_reg[6:5];

endmodule
```

---

### 4.4. SỬA ĐỔI FILE TOP-LEVEL: `rtl/apb_uart.v`

Ghép nối trực tiếp cực kỳ ngắn gọn và sạch sẽ:

```verilog
    // =========================================================================
    // 1. TX FIFO & DIRECT-HANDSHAKE VỚI TX_UART
    // =========================================================================
    wire [7:0]  tx_fifo_wr_data;
    wire        tx_fifo_wr_en;
    wire [7:0]  tx_fifo_rd_data;
    wire        tx_fifo_rd_en;
    wire        tx_fifo_full;
    wire        tx_fifo_empty;
    wire        tx_load_reg;

    sync_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) u_tx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (tx_fifo_wr_en),
        .wr_data (tx_fifo_wr_data),
        .rd_en   (tx_fifo_rd_en),
        .rd_data (tx_fifo_rd_data),
        .full    (tx_fifo_full),
        .empty   (tx_fifo_empty),
        .count   ()
    );

    // KẾT NỐI TRỰC TIẾP:
    // start_tx lấy từ !empty, và rd_en lấy từ load_reg của tx_uart
    wire start_tx        = !tx_fifo_empty;
    assign tx_fifo_rd_en = tx_load_reg;

    // =========================================================================
    // 2. RX FIFO & DIRECT-HANDSHAKE VỚI RX_UART
    // =========================================================================
    wire [8:0]  rx_uart_data;
    wire        rx_done;
    wire [8:0]  rx_fifo_rd_data;
    wire        rx_fifo_rd_en;
    wire        rx_fifo_full;
    wire        rx_fifo_empty;

    wire rx_fifo_wr_en  = rx_done && (!rx_fifo_full);
    wire rx_overrun_err = rx_done && rx_fifo_full;

    sync_fifo #(.DATA_WIDTH(9), .ADDR_WIDTH(4)) u_rx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (rx_fifo_wr_en),
        .wr_data (rx_uart_data),
        .rd_en   (rx_fifo_rd_en),
        .rd_data (rx_fifo_rd_data),
        .full    (rx_fifo_full),
        .empty   (rx_fifo_empty),
        .count   ()
    );

    // =========================================================================
    // 3. INSTANTIATE CÁC MODULE CON
    // =========================================================================
    uart_regs u_uart_regs (
        .clk             (clk),
        .rst_n           (rst_n),
        .reg_pread       (reg_pread),
        .reg_pwrite      (reg_pwrite),
        .paddr           (reg_paddr),
        .pwdata          (reg_pwdata),
        .prdata          (reg_prdata),
        .reg_ack_err     (reg_ack_err),
        .irq             (irq),

        .data_bit_num    (data_bit_num),
        .stop_bit_num    (stop_bit_num),
        .parity_en       (parity_en),
        .parity_type     (parity_type),
        .baud_sel        (baud_sel),
        .rx_busy         (rx_busy),

        // Cổng kết nối TX FIFO
        .tx_fifo_wr_en   (tx_fifo_wr_en),
        .tx_fifo_wr_data (tx_fifo_wr_data),
        .tx_fifo_full    (tx_fifo_full),
        .tx_fifo_empty   (tx_fifo_empty),
        .tx_done         (tx_done),

        // Cổng kết nối RX FIFO
        .rx_fifo_rd_en   (rx_fifo_rd_en),
        .rx_fifo_rd_data (rx_fifo_rd_data),
        .rx_fifo_empty   (rx_fifo_empty),
        .rx_fifo_full    (rx_fifo_full),
        .rx_overrun_err  (rx_overrun_err)
    );

    tx_uart #(.CLK_FREQ(CLK_FREQ)) u_tx_uart (
        .clk          (clk),
        .rst_n        (rst_n),
        .start_tx     (start_tx),
        .tx_data      (tx_fifo_rd_data),
        .data_bit_num (data_bit_num),
        .stop_bit_num (stop_bit_num),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .baud_sel     (baud_sel),
        .tx           (tx),
        .tx_done      (tx_done),
        .load_reg     (tx_load_reg)     // <<-- Đưa xung load_reg ra điều khiển rd_en
    );

    rx_uart #(.CLK_FREQ(CLK_FREQ)) u_rx_uart (
        .clk         (clk),
        .rst_n       (rst_n),
        .rx          (rx),
        .baud_sel    (baud_sel),
        .data_b_num  (data_bit_num),
        .stop_b_num  (stop_bit_num),
        .parity_type (parity_type),
        .parity_en   (parity_en),
        .rx_data     (rx_uart_data),
        .rx_done     (rx_done),
        .rx_busy     (rx_busy),
        .error       (error)
    );
```

---

## 5. Tác Động Tích Cực Lên Mã Nguồn Firmware C (`main.c`)

Sau khi nâng cấp Hardware FIFO, mã C đạt được sự tối ưu vượt bậc:

### Trước khi có FIFO:
```c
// CPU phải đợi từng byte một:
void uart_putc(char c) {
    while (!(IORD_32DIRECT(UART_STT_REG, 0) & 0x01)); // Chờ TX rảnh (~1.04 ms!)
    IOWR_32DIRECT(UART_TX_DATA_REG, 0, c);
    IOWR_32DIRECT(UART_CTRL_REG, 0, 1); // Bấm start_tx
}
```

### Sau khi có FIFO:
```c
// CPU bắn cả chuỗi cực nhanh trong vài nano-giây (Burst Transfer):
void uart_write_string(const char *str) {
    while (*str) {
        // Chỉ cần kiểm tra nếu FIFO chưa đầy thì đẩy thẳng vào:
        while (IORD_32DIRECT(UART_STT_REG, 0) & (1 << 4)); // Chờ nếu TX_FULL (bit 4)
        IOWR_32DIRECT(UART_TX_DATA_REG, 0, *str++);
        // KHÔNG CẦN ghi ADDR_CTRL nữa! Phần cứng tự động rút phát liên tục!
    }
}
```
*(Chuỗi 16 ký tự được CPU nạp xong chỉ trong 16 chu kỳ bus APB ~320 ns, sau đó CPU được giải phóng hoàn toàn để thực thi tác vụ khác!)*
