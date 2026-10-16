# Báo cáo sửa framing error và hướng dẫn chạy testbench

Ngày kiểm chứng: 16/10/2026.

## 1. Kết quả và phạm vi

Đã sửa lỗi RX không đánh dấu stop sai. Hai FAIL cũ là cùng một nguyên nhân:
STT[2] và RX_DATA[8] đều không bật khi stop bằng 0. Không bỏ testcase, không đổi
kỳ vọng lỗi thành PASS và không sửa mô hình tham chiếu để chấp nhận lỗi DUT.

| Bộ kiểm thử | PASS | FAIL | Bằng chứng |
|---|---:|---:|---|
| `tb_apb_uart` | 149 | 0 | 122 khung TX, 153 byte RX, `ref_errors=0` |
| `tb_rx_uart` | 7 | 0 | Tổng kết 7 testcase PASS |
| `tb_full_duplex` | 3 | 0 | Tổng kết 3 testcase PASS |
| `tb_firmware_scenario` | 9 | 0 | Tổng kết 9 testcase PASS |

Cả bốn lệnh mô phỏng thoát mã 0. Kết quả tổng hợp hiện tại:

```text
[UART AO] TX checked=122 RX checked=153 errors=0
TONG SO TEST : 149
SO TEST PASS : 149
SO TEST FAIL : 0
```

**100% là tỷ lệ PASS của các kiểm tra đã chạy**, không đồng nghĩa code coverage,
functional coverage hay tuân thủ APB3 đã được chứng nhận 100%. Testbench firmware
mô phỏng thao tác của CPU, không chạy chương trình C trên Nios V thật.

## 2. Những gì giữ nguyên và thay đổi thời gian

- Giữ module ngoài `apb_uart`, giao diện APB, map thanh ghi và cổng UART.
- Giữ TX FIFO 8×16, RX FIFO 9×16 và cơ chế pop/push hiện có.
- Giữ bốn trạng thái RX: IDLE, CENTER, FRAME, HOLD.
- Giữ nguyên công thức parity trong `error_check.v`.
- Bổ sung nội bộ hai bit nhớ: đã kiểm tra stop đầu và đã thấy framing error.
- Thêm cổng `frame_error` giữa `rx_controller` và `rx_uart`; đây là giao diện
  nội bộ, không đổi giao diện ngoài của UART IP.

Có thay đổi thời điểm hoàn tất RX: RTL cũ chờ 8 tick trong HOLD cho 1 stop hoặc
16 tick cho 2 stop. RTL mới lấy mẫu mỗi stop sau 16 tick, và với 2 stop thì chờ
thêm 16 tick để kiểm tra stop thứ hai. `rx_done` và việc ghi RX FIFO xảy ra tại
mẫu stop cuối. Do FRAME kết thúc một tick sau mẫu data/parity cuối, các mẫu stop
ở gần giữa bit, trễ khoảng một tick oversampling so với tâm lý tưởng.

Đây là chỉnh sửa vi kiến trúc và timing hoàn tất RX, không phải thay đổi kiến
trúc SoC. CPU có thể thấy byte sẵn sàng muộn hơn RTL cũ; các testbench hồi quy đã
kiểm tra luồng nhận, loopback, full-duplex và khóa CFG với timing mới.

## 3. Giải thích từng phần sửa RTL

### `rtl/rx_controller.v`

| Dòng hiện tại | Thay đổi | Ý nghĩa |
|---|---|---|
| 15 | Thêm output `frame_error` | Đưa lỗi framing sang khối RX tổng hợp |
| 32–33 | Ghi chú mốc thời gian | Giải thích quan hệ FRAME và mẫu stop |
| 34 | `first_stop_sampled` | Nhớ đã lấy mẫu stop thứ nhất trong khung 2 stop |
| 35 | `frame_error_latched` | Giữ lỗi nếu một stop trước đó bằng 0 |
| 36 | `stop_sample` | Chỉ lấy mẫu trong HOLD, đúng tick thứ 16 |
| 37 | `final_stop` | 1 stop: hoàn tất ngay; 2 stop: chỉ hoàn tất sau mẫu thứ hai |
| 39–41 | Gộp latch với lỗi ở mẫu hiện tại | FIFO cần thấy lỗi ngay cạnh `rx_done`, không đợi một cạnh clock nữa |
| 43–46 | Reset hai bit nhớ | Không mang trạng thái lỗi từ reset vào khung đầu |
| 47–49 | Xóa tại IDLE | Khung tiếp theo không kế thừa lỗi của khung trước |
| 50–52 | Chốt tại mẫu stop | Đánh dấu stop đầu đã xét, giữ lỗi bằng phép OR |
| 79–80 | Sửa điều kiện thoát HOLD | Không kết thúc trước khi kiểm tra đủ stop |
| 122–126 | Reset tick tại từng mẫu stop; phát done tại mẫu cuối | Dùng lại bộ đếm 4 bit cho cả hai stop, FIFO chỉ nhận một byte mỗi khung |

Bỏ `tick_cnt_max` và khối chọn mốc 7/15 cũ vì chúng chỉ chờ thời gian và chưa
kiểm tra hai stop độc lập. Không thêm trạng thái mới cho FSM.

Tại cạnh stop cuối, `frame_error_latched <= ...` chỉ cập nhật sau cạnh clock
(nonblocking assignment). Nếu chỉ nối latch ra error, FIFO có thể chốt cờ lỗi
cũ. Biểu thức sau đưa cả lỗi của mẫu cuối vào đầu vào FIFO ngay trước cạnh chốt:

```verilog
assign frame_error = frame_error_latched || (stop_sample && !rx);
```

Ở đây `rx` của controller đã được nối từ `rx_sync2`, không dùng chân ngoài chưa
đồng bộ. FIFO chỉ ghi khi `rx_done` nên giá trị error ngoài thời điểm đó không
làm phát sinh phần tử FIFO.

### `rtl/rx_uart.v`

| Dòng hiện tại | Thay đổi | Ý nghĩa |
|---|---|---|
| 31 | Thêm `parity_error` | Tách lỗi parity khỏi lỗi tổng |
| 32 | Thêm `frame_error` | Nhận lỗi stop từ controller |
| 34–35 | `error = parity_error \| frame_error` | Bất kỳ lỗi nào cũng đặt bit lỗi thứ 9 hiện có |
| 73–74 | Nối cổng `.frame_error(frame_error)` | Truyền lỗi từ controller ra khối RX |
| 124 | Đổi `.error(error)` thành `.error(parity_error)` | Tránh nối đồng thời hai nguồn lái lên error tổng |

`apb_uart.v` đã đẩy `{error, rx_uart_data}` vào RX FIFO, và `uart_regs.v` đã đưa
bit thứ 9 ra STT[2]/RX_DATA[8]. Vì vậy không phải sửa hai file này cho framing.

## 4. Bổ sung testbench

Task `check_stop_frame` tạo tín hiệu start/data/parity/stop bằng thời gian mô
phỏng và không đọc nội bộ DUT. Với stop sai, đường RX được giữ thấp qua thời
điểm lấy mẫu rồi nhả lên cao trước khi thành một break kéo dài.

| Cấu hình | Stop lỗi | Điều cần chứng minh |
|---|---|---|
| `0x43` — 8N1 | Stop duy nhất | Phát hiện framing ngay cả khi parity tắt |
| `0x47` — 8N2 | Chỉ stop đầu | Lỗi được giữ qua stop thứ hai đúng |
| `0x47` — 8N2 | Chỉ stop sau | Lỗi mẫu cuối kịp đến FIFO tại cạnh done |
| `0x47` — 8N2 | Cả hai | Lỗi vẫn được gắn vào cùng một byte |
| `0x47` — 8N2 | Không lỗi | Không giữ nhầm lỗi từ khung trước |
| `0x4F` — 8E2 | Stop sau | Parity đúng không che mất framing error |
| `0x5F` — 8O2 | Stop đầu | Phát hiện lỗi khi bật odd parity |
| 8O2, TX ảo gửi `0x3C` | Không lỗi | Phục hồi nhận khung bình thường sau lỗi |

Mỗi lần `check_stop_frame` kiểm tra ghi cấu hình, cờ STT, dữ liệu cùng bit lỗi
RX_DATA và trạng thái sau khi lấy byte cuối. Bộ scoreboard vẫn đối chiếu thứ tự
và số lượng byte. Bảy khung trong task cùng một khung phục hồi thay thế một khung
stop lỗi trước đó, nên RX đối chiếu tăng từ 146 lên 153 byte. TX vẫn là 122 khung.

## 5. Tổng hợp các thay đổi trước đó trong chuỗi công việc

| File / vùng | Thay đổi đã thực hiện trước lần sửa framing này |
|---|---|
| `rtl/tx_uart.v` | Thêm `parity_latched`, chốt khi `load_reg`, dùng cho nhánh phát parity để không lấy nhầm byte FIFO kế tiếp |
| `rtl/uart_regs.v` | Đồng bộ tên `reg_paddr/reg_pwdata/reg_prdata` giữa khai báo và phần thân |
| `rtl/apb_uart.v` | Đồng bộ tên các cổng kết nối đến `uart_regs` |
| `tb/models/uart_rx_virtual.v` | RX hành vi độc lập, lấy mẫu giữa bit và xuất data/done/cờ lỗi |
| `tb/models/uart_tx_virtual.v` | TX hành vi độc lập, chốt data/config và có bơm lỗi parity |
| `tb/tb_apb_uart.v` | Kết nối hai model, scoreboard TX/RX, kết quả Compare/Monitor, kiểm tra timeout |
| APB BFM trong testbench | Lấy phản hồi trước cạnh thay đổi FIFO và chờ cập nhật NBA/IRQ trước khi trả về |
| TC2 | Ghi đủ 16 byte chờ ngoài byte đã vào PISO để kiểm tra TX full |
| TC8–TC13 | Kiểm tra APB, khóa CFG, IRQ mask, độ sâu FIFO, lỗi theo byte, start giả và đủ 96 tổ hợp định dạng/baud |
| `Makefile` | Thêm nguồn model ảo vào mục tiêu mô phỏng APB UART |

Bảng trên là lịch sử; phần diff bên dưới chỉ ghi chính xác thay đổi trong lượt
sửa framing hiện tại, so với bản sao lưu ngay trước lượt này. Không có Git trong
thư mục làm việc để cung cấp commit diff cho toàn bộ lịch sử.

## 6. Hướng dẫn chạy chuẩn

Cần có `iverilog` và `vvp`; GTKWave chỉ cần nếu muốn xem waveform. Các lệnh sau
bắt đầu từ thư mục gốc project chứa thư mục `UART`.

### Cách 1 — Makefile, không xuất waveform

```bash
cd UART
make apb_uart VVP_ARGS=+NO_VCD
```

Đã bổ sung `VVP_ARGS` trong Makefile để truyền `+NO_VCD`. Lệnh sẽ biên dịch đúng
nguồn DUT, hai model và testbench, rồi chạy mô phỏng. Khi FAIL, mục tiêu make trả
mã lỗi từ vvp. Không cần chạy `make check` trước, vì mục tiêu đó dùng ModelSim.

### Cách 2 — Icarus trực tiếp, đúng top module

```bash
cd UART
iverilog -g2012 -s tb_apb_uart -o /tmp/tb_apb_uart tb/tb_apb_uart.v tb/models/*.v rtl/*.v && vvp /tmp/tb_apb_uart +NO_VCD
```

`-g2012` bật các cú pháp SystemVerilog dùng trong testbench, `-s` chọn top, và
`tb/models/*.v` là hai UART ảo bắt buộc phải biên dịch cùng. Toán tử `&&` ngăn
chạy binary cũ khi biên dịch lỗi. Thời gian chạy tùy máy; khoảng 281 ms trong log
là thời gian mô phỏng, không phải thời gian thực của chương trình.

### Xuất và xem waveform

```bash
cd UART
make apb_uart
gtkwave wave_apb_uart.vcd
```

Waveform của ma trận đầy đủ có thể lớn vì clock 50 MHz và dump cả DUT. Để xem lỗi
stop, tìm nhóm TC14 cuối mô phỏng và thêm các tín hiệu:

```text
tb_apb_uart.rx
tb_apb_uart.uart_inst.u_rx_uart.rx_sync2
tb_apb_uart.uart_inst.u_rx_uart.rx_controller_inst.state
tb_apb_uart.uart_inst.u_rx_uart.rx_controller_inst.stop_sample
tb_apb_uart.uart_inst.u_rx_uart.rx_controller_inst.first_stop_sampled
tb_apb_uart.uart_inst.u_rx_uart.rx_controller_inst.frame_error_latched
tb_apb_uart.uart_inst.u_rx_uart.frame_error
tb_apb_uart.uart_inst.u_rx_uart.parity_error
tb_apb_uart.uart_inst.rx_done
tb_apb_uart.uart_inst.error
```

### Chạy các testbench hồi quy

Từ thư mục `UART`, chạy từng lệnh sau. Các mục tiêu này xuất waveform theo cấu
hình riêng của testbench:

```bash
make rx_uart
make full_duplex
make firmware
```

Ba testbench này đã được kiểm chứng bằng cách biên dịch trực tiếp với top tương
ứng và toàn bộ `rtl/*.v`, chạy trong `/tmp` để giữ sản phẩm mô phỏng ngoài source.
Không chỉ dựa vào mã thoát của testbench cũ: cần đọc tổng kết FAIL bằng 0.

## 7. Diff đầy đủ từng dòng trong lượt sửa này

Dấu `-` là dòng cũ bị bỏ, `+` là dòng mới thêm. Mốc `@@ -a,b +c,d @@` cho biết
vị trí dòng cũ/mới. Các đoạn giữ nguyên được hiển thị làm ngữ cảnh. Đây là bản
đối chiếu đầy đủ, bao gồm khai báo, kết nối, thân logic và các dòng testcase.

### `rtl/rx_controller.v`

```diff
--- before/rtl/rx_controller.v
+++ after/rtl/rx_controller.v
@@ -12,6 +12,7 @@
     output reg rx_done,
     output wire rx_busy,
     output wire clr_baud,
+    output wire frame_error,
     output reg bit_clr
 );
     reg [1:0] state, next_state;
@@ -28,13 +29,28 @@
         else state <= next_state;
     end
 
-    reg [3:0] tick_cnt_max;
-    always @(*) begin
-        case(num_stop_b)
-            2'd1: tick_cnt_max = 4'd7;
-            2'd2: tick_cnt_max = 4'd15;
-            default: tick_cnt_max = 4'd7;
-        endcase
+    // FRAME ends one oversampling tick after the last data/parity sample.
+    // Sample each stop after 16 more ticks, close to its center.
+    reg first_stop_sampled;
+    reg frame_error_latched;
+    wire stop_sample = (state == HOLD) && baud_tick && (tick_cnt == 4'd15);
+    wire final_stop = (num_stop_b != 2'd2) || first_stop_sampled;
+
+    // Include the current sample combinationally: RX FIFO captures error
+    // on the same clock edge as rx_done, before latch NBA updates.
+    assign frame_error = frame_error_latched || (stop_sample && !rx);
+
+    always @(posedge clk or negedge rst_n) begin
+        if (!rst_n) begin
+            first_stop_sampled <= 1'b0;
+            frame_error_latched <= 1'b0;
+        end else if (state == IDLE) begin
+            first_stop_sampled <= 1'b0;
+            frame_error_latched <= 1'b0;
+        end else if (stop_sample) begin
+            first_stop_sampled <= 1'b1;
+            frame_error_latched <= frame_error_latched || !rx;
+        end
     end
 
     always @(*) begin
@@ -61,10 +77,7 @@
                 end
             end
             HOLD: begin
-                if(baud_tick) begin
-                    if(tick_cnt == tick_cnt_max) next_state = IDLE;
-                    else next_state = HOLD;
-                end
+                if (stop_sample && final_stop) next_state = IDLE;
             end
         endcase
     end
@@ -108,11 +121,9 @@
             end
             HOLD: begin
                 bit_clr = 1'b1;
-                if(baud_tick) begin
-                    if(tick_cnt == tick_cnt_max) begin
-                        rx_done  = 1'b1;
-                        tick_clr = 1'b1;
-                    end
+                if (stop_sample) begin
+                    tick_clr = 1'b1;
+                    if (final_stop) rx_done = 1'b1;
                 end
             end
         endcase

```

### `rtl/rx_uart.v`

```diff
--- before/rtl/rx_uart.v
+++ after/rtl/rx_uart.v
@@ -28,6 +28,11 @@
    wire [3:0] bit_cnt;
    wire [3:0] tick_cnt;
    wire parity_exp;
+   wire parity_error;
+   wire frame_error;
+
+   // Reuse the existing per-byte error bit in the 9-bit RX FIFO.
+   assign error = parity_error | frame_error;
    
     // 2-FF Synchronizer cho tin hieu rx (chong Metastability)
     reg rx_sync1, rx_sync2;
@@ -65,7 +70,8 @@
         .bit_clr(bit_clr),
         .rx_done(rx_done),
         .rx_busy(rx_busy),
-        .clr_baud(clr_baud)
+        .clr_baud(clr_baud),
+        .frame_error(frame_error)
     );
     data_b_num data_b_num_inst(
         .data_b_num(data_b_num),
@@ -115,7 +121,7 @@
         .parity_type(parity_type),
         .parity_bit(parity_bit),
         .parity_exp(parity_exp),
-        .error(error)
+        .error(parity_error)
     );
 
 endmodule
```

### `tb/tb_apb_uart.v`

```diff
--- before/tb/tb_apb_uart.v
+++ after/tb/tb_apb_uart.v
@@ -406,6 +406,52 @@
                 spec_check(!error_bus && (irq === (|(active_sources & mask_value[2:0]))),
                            "IRQ mask: only enabled active sources may assert IRQ");
             end
+        end
+    endtask
+
+    // Drive stop faults independently of the DUT; do not suppress scoreboard errors.
+    task check_stop_frame(input [6:0] configuration, input [1:0] bad_stops);
+        integer bit_index, stop_index;
+        reg parity_value, bus_error;
+        reg [31:0] status, value;
+        begin
+            apb_write(8, {25'd0, configuration}, bus_error);
+            spec_check(!bus_error, "Framing test configuration accepted");
+            bit_time_ns = 1_000_000_000 / reference_baud(configuration[6:5]);
+            reference_expect_rx(reference_mask(8'hA5, configuration[1:0]), |bad_stops);
+            raw_rx_enable = 1;
+            raw_rx_level = 0; #(bit_time_ns);
+            parity_value = configuration[4];
+            for (bit_index = 0; bit_index < 5 + configuration[1:0]; bit_index = bit_index + 1) begin
+                raw_rx_level = (8'hA5 >> bit_index) & 1;
+                parity_value = parity_value ^ raw_rx_level;
+                #(bit_time_ns);
+            end
+            if (configuration[3]) begin
+                raw_rx_level = parity_value;
+                #(bit_time_ns);
+            end
+            for (stop_index = 0; stop_index < 1 + configuration[2]; stop_index = stop_index + 1) begin
+                raw_rx_level = !bad_stops[stop_index];
+                // Release after the sample, avoiding an unintended long break.
+                #(3 * bit_time_ns / 4);
+                raw_rx_level = 1;
+                #(bit_time_ns - 3 * bit_time_ns / 4);
+            end
+            #(2 * bit_time_ns);
+            raw_rx_enable = 0;
+            apb_read(12'h00C, status, bus_error);
+            spec_check(!bus_error && status[1] && (status[2] === (|bad_stops)),
+                       "STT reports stop error, including first/second stop independently");
+            if (status[1]) begin
+                apb_read(4, value, bus_error);
+                spec_check(!bus_error && value[8:0] ===
+                           {(|bad_stops), reference_mask(8'hA5, configuration[1:0])},
+                           "RX_DATA preserves data and the framing-error bit");
+            end else $fatal(1, "Framing test: expected frame never arrived");
+            apb_read(12'h00C, status, bus_error);
+            spec_check(!status[1] && !status[2], "Framing error clears after the last queued byte is read");
+            $display("[FRAMING] cfg=%02h bad_stops=%b", configuration, bad_stops);
         end
     endtask
 
@@ -612,25 +658,17 @@
             test_id = 14;
             print_header("SPEC: INVALID RX STOP BIT (FRAMING ERROR)");
             apb_write(12'h010, 0, error_bus);
-            apb_write(8, 32'h43, error_bus); // no parity: isolate framing error
-            bit_time_ns = 1_000_000_000 / 9600;
-            reference_expect_rx(8'hA5, 1'b1);
-            raw_rx_enable = 1;
-            raw_rx_level = 0; #(bit_time_ns);
-            for (n = 0; n < 8; n = n + 1) begin
-                raw_rx_level = (8'hA5 >> n) & 1;
-                #(bit_time_ns);
-            end
-            raw_rx_level = 0; // Invalid stop, sampled before returning idle.
-            #(3 * bit_time_ns / 4);
-            raw_rx_level = 1;
-            #(3 * bit_time_ns);
-            raw_rx_enable = 0;
-            apb_read(12'h00C, status, error_bus);
-            spec_check(status[1] && status[2],
-                       "SPEC GAP: invalid stop must flag received-frame error (parity disabled)");
-            if (status[1]) apb_read(4, value, error_bus);
-            // Keep executing to report every spec mismatch, never hide failure.
+            check_stop_frame(7'h43, 2'b01); // 8N1, bad stop
+            check_stop_frame(7'h47, 2'b01); // 8N2, first stop bad only
+            check_stop_frame(7'h47, 2'b10); // 8N2, second stop bad only
+            check_stop_frame(7'h47, 2'b11); // 8N2, both stops bad
+            check_stop_frame(7'h47, 2'b00); // good frame after errors: no stale latch
+            check_stop_frame(7'h4F, 2'b10); // 8E2: good parity cannot hide bad stop
+            check_stop_frame(7'h5F, 2'b01); // 8O2: check first stop with odd parity
+            send_uart_rx_byte(8'h3C, 3, 1, 1, 0);
+            apb_read(4, value, error_bus);
+            spec_check(!error_bus && value[8:0] === 9'h03C,
+                       "Valid odd-parity frame recovers after framing errors");
         end
     endtask
 

```

### `Makefile`

```diff
--- before/Makefile
+++ after/Makefile
@@ -7,6 +7,7 @@
 VLIB     ?= vlib
 IVERILOG ?= iverilog
 VVP      ?= vvp
+VVP_ARGS ?=
 
 .PHONY: all help compile check sim sim_cli clean \
         tx_uart tx_uart_cli tx_baud_gen tx_baud_gen_cli \
@@ -148,7 +149,7 @@
 apb_uart tb_apb_uart:
 	@echo "==> Đang biên dịch và chạy mô phỏng tb_apb_uart bằng Icarus Verilog..."
 	iverilog -g2012 -o sim_apb_uart.vvp $(APB_UART_SRCS) $(UART_VIRTUAL_SRCS) tb/tb_apb_uart.v
-	vvp sim_apb_uart.vvp
+	$(VVP) sim_apb_uart.vvp $(VVP_ARGS)
 
 wave_apb_uart: apb_uart
 	gtkwave wave_apb_uart.vcd &

```

## 8. Tài liệu được cập nhật

- `TESTPLAN_APB_UART.md`: giữ kết quả FAIL cũ ở mục lịch sử, thêm kết quả mới và các trường hợp stop bổ sung.
- `tb/models/README.md`: thay thông báo thiếu framing error bằng kết quả sau sửa và liên kết báo cáo này.
- Báo cáo này: nguyên nhân, giải thích theo dòng RTL, diff đầy đủ, kết quả và hướng dẫn chạy.

Phạm vi chưa được kiểm chứng vẫn gồm nhiễu/break, dung sai baud, mọi tổ hợp reset
giữa khung và mọi biên FIFO đọc/ghi đồng thời. Chưa chạy tổng hợp FPGA, kiểm tra
timing trên thiết bị hay đo coverage bằng công cụ trong lượt này.
