# Cẩm Nang Thiết Kế & Tối Ưu RTL Khối Thu UART RX (Đặc Tả 1.1)

> **Dành cho kỹ sư RTL:** Tài liệu này được đúc kết từ kinh nghiệm thiết kế phần cứng thực chiến, bám sát **chính xác 100% cấu trúc RTL hiện tại** trong thư mục [`rtl/`](file:///home/vietanh/Downloads/code/UART/UART/rtl) của bạn.
> 
> **Mục tiêu cốt lõi:** Giúp bạn **sửa ít dòng code nhất, tái sử dụng tối đa các module hiện có** (`rx_baud_gen`, `sipo`, `deframe`, `error_check`, `bit_cnt`, `tick_cnt`, `data_b_num`, `stop_b_num`), không bị xáo trộn kiến trúc, nhưng vẫn **đạt 100% các tiêu chí khắt khe của Đặc tả 1.1** ([`za.html`](file:///home/vietanh/Downloads/code/UART/UART/doc/specs/za.html)).

---

## 1. Bản Đồ Kiến Trúc Khối Thu: Giữ Nguyên `rx_baud_gen` Riêng

Hệ thống của bạn sử dụng kiến trúc module hóa rất sạch: **Khối thu `rx_uart` tự chứa bộ sinh baud riêng `rx_baud_gen` bên trong**, kết hợp cơ chế **"Shift-All then Deframe"**:

```text
                                  ┌───────────────────┐
                                  │   rx_baud_gen     │
               clr_baud ─────────►│ (bộ chia baud RX) │
                                  └─────────┬─────────┘
                                            │ baud_tick (16x baud)
                                            ▼
Chân RX ──► [2-FF Synchronizer] ───────► rx_controller ◄──► tick_cnt
                 │                      (FSM 4 state)       (đếm 0..15)
                 │                            │ shift_en
                 ▼                            ▼
             rx_sync2 ────────────────► sipo.v (12-bit)
                                              │ data_out[11:0]
                                              ▼
                                         deframe.v (cắt byte + tính exp)
                                              │
                                              ▼
                                         error_check.v (so sánh parity)
                                              │
                                              ▼
                                        [Buffer 1-byte & Latch Cờ]
                                        (STAT, Overrun, RTS_N)
```

### Bảng Kiểm Kê & Đánh Giá Từng Module Hiện Có:

| Module hiện tại | Vai trò kỹ thuật | Trạng thái đối với Spec 1.1 | Quyết định xử lý |
| :--- | :--- | :--- | :---: |
| [`rx_baud_gen.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_baud_gen.v) | Sinh xung `baud_tick` riêng cho RX, nhận `clr_baud` | Khối baud riêng theo đúng kiến trúc của bạn | **GIỮ NGUYÊN TRONG RX_UART 100%** |
| [`sipo.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/sipo.v) | Thanh ghi dịch 12-bit LSB-first | Hoàn toàn tương thích | **GIỮ NGUYÊN 100%** |
| [`bit_cnt.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/bit_cnt.v) | Đếm tổng số bit (Data + Parity) | Tự động tính đúng số bit theo cấu hình | **GIỮ NGUYÊN 100%** |
| [`tick_cnt.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/tick_cnt.v) | Bộ đếm 16 tick ($0 \dots 15$) | Đếm chuẩn $16 \times \text{baud}$ | **GIỮ NGUYÊN 100%** |
| [`data_b_num.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/data_b_num.v) | Giải mã 5, 6, 7, 8 bit | Đúng chuẩn `CFG.data_bits` | **GIỮ NGUYÊN 100%** |
| [`stop_b_num.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/stop_b_num.v) | Giải mã 1 hoặc 2 stop bit | Đúng chuẩn `CFG.stop_bits` | **GIỮ NGUYÊN 100%** |
| [`deframe.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/deframe.v) | Tách `rx_data`, che bit cao = 0, trích bit parity | Đã tự động che `rx_data[7:N] = 0` | **GIỮ NGUYÊN 100%** |
| [`error_check.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/error_check.v) | So sánh Parity bit | Ngược mapping `parity_type` với Spec | **SỬA ĐÚNG 2 DÒNG CODE** |
| [`rx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_controller.v) | FSM điều khiển 4 trạng thái | Đã có sẵn lọc nhiễu, về IDLE sớm, và `clr_baud`! | **GIỮ NGUYÊN 100% CẢ CODE LẪN PORT** |
| [`rx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_uart.v) | Top ghép nối, Buffer, STAT, RTS | Bỏ FIFO cũ, thêm buffer chốt cờ | **CẬP NHẬT GIAO DIỆN & BUFFER** |

👉 **Ý nghĩa to lớn của việc giữ `rx_baud_gen`:**
1. Cổng `baud_tick` và `clr_baud` của [`rx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_controller.v) được giữ nguyên vẹn, **không cần sửa một dòng code nào trong `rx_controller.v`**!
2. Khi FSM ở `IDLE`, `clr_baud = 1` sẽ reset bộ đếm `cnt` trong `rx_baud_gen`. Ngay khi sườn xuống của Start bit tới và FSM chuyển sang `CENTER`, `clr_baud` hạ về 0, giúp bộ sinh baud đếm tick đồng pha tuyệt đối với Start bit!
3. Phần `rx_baud_gen` do thành viên khác phụ trách (nếu sau này nâng cấp sang bộ chia phân số `BAUD` 16-bit) có thể thay thế độc lập bên trong mà không ảnh hưởng logic lõi của RX.

---

## 2. Giải Mã 2 Thắc Mắc Lớn Của Bạn Về Kiến Trúc

### Câu hỏi 1: "Có nhất thiết phải tách riêng state PARITY trong FSM không?"
**Trả lời: TUYỆT ĐỐI KHÔNG CẦN!**
- Trong kiến trúc của bạn:
  1. [`bit_cnt.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/bit_cnt.v) đã tự động cộng thêm 1 bit vào ngưỡng đếm nếu `parity_en == 1` (`data_b_num_out + 1 + 1`).
  2. FSM ở trạng thái `FRAME` cứ mỗi 16 tick lại kích `shift_en = 1` để đẩy bit vào [`sipo.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/sipo.v). FSM không cần biết bit đó là data hay parity!
  3. Khi nhận đủ toàn bộ data + parity, cờ `bit_last` dựng lên.
  4. Khối [`deframe.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/deframe.v) nhận cờ `bit_last` sẽ lập tức bóc tách bit cuối cùng đưa sang chân `parity_bit`, và tính toán parity kỳ vọng `parity_exp`.
  5. Khối [`error_check.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/error_check.v) so sánh và báo cờ `parity_error`.
- **Nếu bạn cố thêm state PARITY:** Bạn sẽ phá vỡ logic của `bit_cnt.v`, `deframe.v` và `sipo.v`, dẫn đến phải viết lại toàn bộ từ đầu mà không đem lại bất kỳ lợi ích nào!

### Câu hỏi 2: "Trạng thái `HOLD` trong `rx_controller.v` cũ có đúng yêu cầu 'về IDLE sớm' của Spec 1.1 không?"
**Trả lời: CODE CỦA BẠN ĐÃ LÀM ĐÚNG SẴN RỒI!**
Hãy cùng phân tích trục thời gian (timing) thực tế trong RTL của bạn:
1. **Ở trạng thái `CENTER`:**
   - Bộ đếm đếm từ $0 \dots 7$. Tại `tick_cnt == 7` (chính giữa Start bit), FSM kiểm tra nếu `rx == 0` thì xác nhận Start bit hợp lệ, đồng thời phát `tick_clr = 1` để reset `tick_cnt` về 0 ngay tại giữa Start bit!
2. **Ở trạng thái `FRAME`:**
   - Vì `tick_cnt` được reset về 0 tại giữa Start bit, nên 16 tick sau (`tick_cnt == 15`) chính là **tâm của Data bit 0**!
   - Cứ mỗi khi `tick_cnt == 15`, FSM lấy mẫu và dịch 1 bit.
   - Tại Data bit cuối cùng (hoặc Parity bit), khi `tick_cnt == 15`, bit được dịch vào `sipo`.
   - Một tick sau, `bit_last == 1`, FSM chuyển sang `HOLD`, đồng thời reset `tick_cnt` về 0.
3. **Ở trạng thái `HOLD` (Stop bit):**
   - Từ điểm reset khi vào `HOLD` cho đến khi `tick_cnt == 15` là đúng 16 tick tính từ tâm của bit trước đó $\rightarrow$ **`tick_cnt == 15` chính là TÂM CỦA STOP BIT 1!**
   - Hãy nhìn vào code hiện tại của bạn trong [`rx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_controller.v#L80-L127):
     ```verilog
     // Khi stop_sample xuất hiện (tick_cnt == 15):
     if (stop_sample && final_stop) next_state = IDLE;
     if (final_stop) rx_done = 1'b1;
     ```
   - **Thấy gì chưa?** Ngay khi lấy mẫu tại `tick_cnt == 15` (tâm của Stop bit cuối), FSM của bạn **lập tức bật `rx_done = 1` và nhảy thẳng về `IDLE`**! Nó **hoàn toàn không đếm tiếp 8 tick còn lại** của nửa sau stop bit!
   - Điều này khớp 100% với yêu cầu mục 7 của Spec 1.1:
     > *"Phần được rút ngắn chỉ là nửa sau của stop bit cuối cùng: lấy mẫu stop bit cuối xong, bộ thu đặt rx_done và chuyển sang IDLE ngay, không đếm tiếp 8 tick còn lại... về IDLE sớm nửa bit giúp bộ thu không bỏ lỡ sườn xuống của khung kế tiếp khi bên phát chạy nhanh hơn +2.0%."*

👉 **Kết luận:** Thuật toán FSM trong [`rx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_controller.v) của bạn **đã chuẩn xác hoàn hảo**, giữ nguyên 100%!

---

## 3. Chi Tiết Các Bước Cần Sửa (Chỉ Cần Thao Tác Trên 2 File)

Bạn chỉ cần chỉnh sửa đúng 2 file:
1. [`rtl/error_check.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/error_check.v) (Đổi 2 dòng)
2. [`rtl/rx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_uart.v) (Giữ `rx_baud_gen`, bỏ FIFO, thêm buffer chốt cờ)

---

### Bước 1: Sửa Mapping Parity Trong `rtl/error_check.v`

Trong Đặc tả 1.1 (Mục 4 thanh ghi `CFG[4]`):
* `parity_type == 1'b1`: Parity **Chẵn (Even)**.
* `parity_type == 1'b0`: Parity **Lẻ (Odd)**.

Trong code hiện tại của bạn:
```verilog
// CODE HIỆN TẠI (ĐANG BỊ NGƯỢC QUY ƯỚC):
case(parity_type)
    1'b0: error = (parity_bit != parity_exp) ? 1'b1 : 1'b0;  // đang coi 0 là even
    1'b1: error = (parity_bit != ~parity_exp) ? 1'b1 : 1'b0; // đang coi 1 là odd
    default: error = 1'b0;
endcase
```

**Cách sửa (Đảo lại 1'b1 và 1'b0):**
```verilog
// SỬA LẠI THÀNH:
case(parity_type)
    1'b1: error = (parity_bit != parity_exp);   // 1'b1: Even parity
    1'b0: error = (parity_bit != ~parity_exp);  // 1'b0: Odd parity
    default: error = 1'b0;
endcase
```

---

### Bước 2: Hoàn Thiện Top-Level `rtl/rx_uart.v`

Đây là nơi bạn tập hợp các tín hiệu và đáp ứng các yêu cầu hệ thống của Spec 1.1.

#### 1. Khai báo Cổng Giao Tiếp (Interface) Chuẩn:
```verilog
module rx_uart #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire       clk,          // Clock hệ thống (pclk)
    input  wire       rst_n,        // Reset tích cực mức thấp (presetn)
    input  wire       rx,           // Chân nối tiếp vào từ bên ngoài
    input  wire [1:0] baud_sel,     // Chọn baud cho rx_baud_gen nội bộ
    input  wire [1:0] data_b_num,   // CFG.data_bits (00: 5b, 01: 6b, 10: 7b, 11: 8b)
    input  wire       stop_b_num,   // CFG.stop_bits (0: 1 stop, 1: 2 stop)
    input  wire       parity_type,  // CFG.parity_type (1: Chẵn, 0: Lẻ)
    input  wire       parity_en,    // CFG.parity_en (1: Có parity)
    input  wire       rx_dis,       // CFG.rx_dis (1: Cấm thu, rts_n = 1)
    input  wire       rx_clear,     // Xung xóa cờ khi CPU đọc RXDATA
    
    output reg  [7:0] rx_data,      // Byte dữ liệu đã nhận (STAT/RXDATA)
    output reg        rx_done,      // Cờ báo có ký tự chưa đọc (STAT[1])
    output wire       rx_busy,      // Đang bận nhận khung (STAT[3])
    output wire       rts_n,        // Tín hiệu bắt tay phần cứng Request-To-Send
    output reg        parity_err,   // Cờ lỗi Parity (STAT[2])
    output reg        frame_err,    // Cờ lỗi Framing (STAT[6])
    output reg        overrun,      // Cờ lỗi tràn bộ đệm (STAT[7])
    output wire       error         // Báo lỗi tổng hợp (phục vụ tương thích cũ)
);
```

#### 2. Tầng Đồng Bộ 2-FF & Xử Lý Cấm Thu (`rx_dis`):
Giữ nguyên 2 tầng flip-flop cho tín hiệu `rx` để chống metastability. Khi `rx_dis == 1`, cô lập FSM bằng cách giữ mức logic `1` (Idle):

```verilog
reg rx_sync1, rx_sync2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_sync1 <= 1'b1;
        rx_sync2 <= 1'b1;
    end else begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end
end

// Khi rx_dis = 1, cô lập FSM bằng cách giữ mức logic 1 (IDLE)
wire rx_fsm_in = rx_dis ? 1'b1 : rx_sync2;
```

#### 3. Điều Khiển Luồng Phần Cứng (`rts_n`):
Theo đúng mục 2, 7 và 10 của Spec 1.1:
> *"rts_n = 0 khi rx_dis = 0 và rx_done = 0: bên kia được phép gửi. Khi rx_done = 1 hoặc rx_dis = 1 thì rts_n = 1."*

```verilog
assign rts_n = rx_dis | rx_done;
```

#### 4. Ghép Nối Các Khối Con (Giữ `rx_baud_gen`, Nối Dây Chuẩn):
Giữ nguyên `rx_baud_gen` bên trong `rx_uart`. Nối trực tiếp `baud_tick` và `clr_baud`:

```verilog
wire baud_tick;
wire clr_baud;
wire ctrl_rx_done;
wire ctrl_frame_error;
wire parity_error;
wire [7:0] deframe_data;
wire shift_en;
wire tick_clr;
wire tick_en;
wire bit_clr;
wire bit_last;
wire [11:0] data_out;
wire [3:0] num_data_b;
wire [1:0] num_stop_b;
wire [3:0] bit_cnt;
wire [3:0] tick_cnt;
wire parity_bit;
wire parity_exp;

// 1. Khối sinh Baud riêng của RX (GIỮ NGUYÊN)
rx_baud_gen #(
    .CLK_FREQ(CLK_FREQ)
) u_rx_baud_gen (
    .baud_sel  (baud_sel),
    .clk       (clk),
    .rst_n     (rst_n),
    .clr_baud  (clr_baud),
    .baud_tick (baud_tick)
);

// 2. Bộ đếm tick (GIỮ NGUYÊN)
tick_cnt tick_cnt_inst(
    .clk(clk),
    .rst_n(rst_n),
    .baud_tick(baud_tick),
    .tick_clr(tick_clr),
    .tick_cnt(tick_cnt)
);

// 3. FSM Điều khiển (GIỮ NGUYÊN 100%)
rx_controller rx_controller_inst(
    .clk(clk),
    .rst_n(rst_n),
    .baud_tick(baud_tick),
    .rx(rx_fsm_in),
    .bit_last(bit_last),
    .tick_cnt(tick_cnt),
    .shift_en(shift_en),
    .tick_clr(tick_clr),
    .tick_en(tick_en),
    .num_stop_b(num_stop_b),
    .bit_clr(bit_clr),
    .rx_done(ctrl_rx_done),
    .rx_busy(rx_busy),
    .clr_baud(clr_baud),
    .frame_error(ctrl_frame_error)
);

// 4. SIPO 12-bit (GIỮ NGUYÊN)
sipo sipo_inst(
    .clk(clk),
    .rst_n(rst_n),
    .shift_en(shift_en),
    .rx(rx_fsm_in),
    .data_out(data_out)
);

// 5. Deframe: tách byte và tự động che bit cao rx_data[7:N] = 0 (GIỮ NGUYÊN)
deframe deframe_inst(
    .clk(clk),
    .rst_n(rst_n),
    .bit_last(bit_last),
    .parity_en(parity_en),
    .data_in(data_out),
    .num_data_b(num_data_b),
    .rx_data(deframe_data),
    .parity_bit(parity_bit),
    .parity_exp(parity_exp)
);

// 6. Error Check: kiểm tra parity (GIỮ NGUYÊN)
error_check error_check_inst(
    .parity_en(parity_en),
    .parity_type(parity_type),
    .parity_bit(parity_bit),
    .parity_exp(parity_exp),
    .error(parity_error)
);

// 7. Giải mã số bit Data và Stop (GIỮ NGUYÊN)
data_b_num data_b_num_inst(
    .data_b_num(data_b_num),
    .data_b_num_out(num_data_b)
);

stop_b_num stop_b_num_inst(
    .stop_b_num(stop_b_num),
    .stop_b_num_out(num_stop_b)
);

// 8. Đếm số bit khung (GIỮ NGUYÊN)
bit_cnt bit_cnt_inst(
    .clk(clk),
    .rst_n(rst_n),
    .tick_en(tick_en),
    .bit_clr(bit_clr),
    .data_b_num_out(num_data_b),
    .bit_last(bit_last),
    .bit_cnt(bit_cnt),
    .parity_en(parity_en)
);
```

#### 5. Logic Chốt Dữ Liệu, Bảo Vệ Overrun & Xóa Cờ:
Thay thế khối FIFO cũ bằng logic chốt 1-byte có bảo vệ Overrun theo đúng Spec 1.1:

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_data    <= 8'h00;
        rx_done    <= 1'b0;
        parity_err <= 1'b0;
        frame_err  <= 1'b0;
        overrun    <= 1'b0;
    end else begin
        // 1. Ưu tiên xử lý xóa cờ khi CPU đọc RXDATA
        if (rx_clear) begin
            rx_done    <= 1'b0;
            parity_err <= 1'b0;
            frame_err  <= 1'b0;
            overrun    <= 1'b0;
        end
        
        // 2. Khi FSM báo nhận xong 1 khung (xung ctrl_rx_done)
        if (ctrl_rx_done) begin
            if (rx_done && !rx_clear) begin
                // Lỗi Overrun: byte cũ chưa đọc mà byte mới đã tới
                overrun <= 1'b1;
                // GIỮ NGUYÊN rx_data, parity_err, frame_err của byte cũ!
            end else begin
                // Nhận thành công byte mới vào buffer
                rx_data    <= deframe_data;
                parity_err <= parity_error;
                frame_err  <= ctrl_frame_error;
                rx_done    <= 1'b1;
            end
        end
    end
end

assign error = parity_err | frame_err;
```

---

## 4. Bảng Đối Chiếu Đặc Tả 1.1 (Spec Traceability Matrix)

| Yêu cầu trong Spec 1.1 (`za.html`) | Đáp ứng trong kiến trúc hiện tại của bạn | Vị trí mã nguồn |
| :--- | :--- | :--- |
| **Baud Generator độc lập cho RX** | `rx_baud_gen` sinh `baud_tick` nội bộ, đồng pha bằng `clr_baud` | [`rx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_uart.v) |
| **Dung sai tốc độ $\pm 2.0\%$** | Lấy mẫu tại giữa bit (`tick_cnt == 15`); về `IDLE` ngay tại tâm của stop bit cuối | [`rx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_controller.v#L80) |
| **Lọc nhiễu Start bit (Glitch Rejection)** | Kiểm tra lại tại `tick_cnt == 7` ở state `CENTER`, nếu `rx == 1` thì quay về `IDLE` không báo lỗi | [`rx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_controller.v#L67) |
| **24 dạng khung UART** | 5, 6, 7, 8 bit dữ liệu; 1 hoặc 2 stop bit; None, Odd, Even parity | [`data_b_num.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/data_b_num.v), [`stop_b_num.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/stop_b_num.v), [`bit_cnt.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/bit_cnt.v) |
| **Che bit cao `rx_data[7:N] = 0`** | `deframe.v` tự động chèn các bit `0` ở đầu với khung 5, 6, 7 bit | [`deframe.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/deframe.v#L23) |
| **Phát hiện lỗi Stop bit (`frame_err`)** | Lấy mẫu Stop bit 1 và Stop bit 2, nếu có stop bit = 0 thì bật cờ lỗi | [`rx_controller.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_controller.v#L41) |
| **Bảo vệ Overrun** | Không ghi đè `rx_data` cũ khi `rx_done == 1`, bật cờ `overrun = 1` | [`rx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_uart.v) |
| **Điều khiển luồng `rts_n`** | `rts_n = rx_dis \| rx_done` | [`rx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_uart.v) |
| **Đọc RXDATA xóa cờ** | Tín hiệu `rx_clear` xóa cùng lúc 4 cờ: `rx_done, parity_err, frame_err, overrun` | [`rx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_uart.v) |

---

## 5. Quy Trình Bạn Tự Sửa Code & Nghiệm Thu

Bạn chỉ cần thực hiện 3 bước ngắn gọn:

1. **Bước 1 ([`rtl/error_check.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/error_check.v)):**
   - Đổi `1'b0` thành `1'b1` cho Even parity, và `1'b1` thành `1'b0` cho Odd parity (Mục 3, Bước 1).
2. **Bước 2 ([`rtl/rx_uart.v`](file:///home/vietanh/Downloads/code/UART/UART/rtl/rx_uart.v)):**
   - Giữ nguyên instance `rx_baud_gen`.
   - Bỏ instance `sync_fifo`.
   - Cập nhật danh sách cổng vào/ra (thêm `rx_dis`, `rx_clear`, `rts_n`, `parity_err`, `frame_err`, `overrun`).
   - Thêm `rx_fsm_in` cho `rx_dis` và `assign rts_n = rx_dis | rx_done;`.
   - Nối dây `ctrl_rx_done` từ `rx_controller` vào khối `always` chốt `rx_data`, bắt lỗi `overrun` và nhận xung `rx_clear` (Mục 3, Bước 2.5).
3. **Bước 3 (Kiểm tra cú pháp RTL):**
   - Chạy lệnh sau trên terminal:
     ```bash
     make check
     ```
   - Trình biên dịch sẽ quét toàn bộ thư mục `rtl/` để đảm bảo 0 lỗi cú pháp, 0 cảnh báo không nối dây, 0 latch ngoài ý muốn.

---

> [!TIP]
> **Lời khuyên từ giảng viên RTL:**
> Việc giữ `rx_baud_gen` riêng trong `rx_uart` là một quyết định rất thực tế khi làm việc nhóm! Nó giúp module của bạn tự chủ hoàn toàn (self-contained), độc lập kiểm thử (testbench độc lập cấp `baud_sel` là chạy được ngay), và đặc biệt là giữ nguyên vẹn 100% logic của `rx_controller.v` và `tick_cnt.v` mà không phải đổi bất kỳ tên port nào!
