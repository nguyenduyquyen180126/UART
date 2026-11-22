# Báo cáo sửa RTL APB-UART và đối chiếu public test với `za.html`

Ngày thực hiện: 21/11/2026  
RTL được rà soát: `rtl/`  
Testbench: `apb-uart-sinh-vien_2026-11-19/apb-uart-sinh-vien/public-tests/`  
Đặc tả đối chiếu: `doc/specs/za.html`, phiên bản 1.1

## Kết quả

Đã sửa các lỗi RTL làm public regression fail. Cả 20 test công khai đều PASS với seed 1 và seed 7 (40 lượt chạy, 0 lỗi). Summary:

- Seed 1: `public-tests/run_regress_20261121_100722_public/summary.csv`
- Seed 7: `public-tests/run_regress_20261121_100317_public/summary.csv`

Lệnh tái tạo:

```bash
cd /home/vietanh/Downloads/code/UART/UART/apb-uart-sinh-vien_2026-11-19/apb-uart-sinh-vien/public-tests
make regress SUITE=public FILES_F=files.f SEEDS="1 7"
```

Regres đã chạy bằng Questa 10.7c. Bộ hidden dùng `hidden-enc/tests_pkg.svp` được mã hóa với Questa 2025.1_2, nên chưa được kiểm chứng trong phiên bản Questa này.

## Đối chiếu testbench với `za.html` trước khi sửa RTL

README của testbench nói bộ test viết theo đặc tả 1.2, trong khi file được yêu cầu đối chiếu là `za.html` phiên bản 1.1. Vì khác phiên bản, các điều kiện không được diễn đạt rõ trong 1.1 được đánh dấu riêng bên dưới. Việc đối chiếu cũng xét mô hình hành vi và giản đồ tương tác được nhúng trong HTML, không chỉ phần văn xuôi.

| Test | Nội dung kiểm | Đối chiếu với `za.html` |
|---|---|---|
| P1.1 | Reset outputs, `pready`, `pslverr` | Phù hợp với mục 2. HTML yêu cầu sau reset `tx=1`, `rts_n=1`, `irq=0`, `pslverr=0`, `pready=1`. Kiểm tra `rts_n` trở về trạng thái sẵn sàng được hỗ trợ bởi mô hình RX nhúng trong HTML. |
| P1.2–P1.3 | Giá trị reset, byte lane, RFU | Phù hợp với mục 4 và 8: giá trị reset, bit RFU đọc 0/ghi không tác dụng, APB và `pstrb`. |
| P2.1–P2.3 | Lỗi APB E1, E3, E5 | Phù hợp với bảng E1–E5 ở mục 8. Các trường hợp kiểm không thay đổi thanh ghi sau giao dịch lỗi cũng phù hợp với mô tả giao dịch lỗi không có tác dụng phụ. |
| P3.1–P3.4 | Khung TX, thời điểm `tx_done`, CTS, reset mềm | Phù hợp với mục 5, 6, 12 và giản đồ TX: cấu hình khung/baud, CTS chỉ ngăn khởi phát, khung đã chạy phải hoàn tất, `tx_done` ở cuối stop, reset mềm hủy khung và khôi phục trạng thái. |
| P4.1–P4.5 | Khung RX, glitch, parity, stop, xóa cờ | Phù hợp với mục 6–7 và 12: 24 dạng khung, lấy mẫu/baud, xung ngắn không tạo khung, phát hiện parity/frame error, đọc RXDATA xóa các cờ. |
| P5.1 | Overrun | Phù hợp với mô tả bộ đệm một ký tự và bit STAT: khung mới tới khi `rx_done=1` bị bỏ, giữ RXDATA cũ và báo overrun. |
| P5.2 | Quy tắc `rts_n` khi RX rảnh/đầy | Có trong mô hình RX và giản đồ trao đổi nhúng trong HTML (`rts_n=0` khi sẵn sàng, lên 1 khi RXDATA đầy). Phần văn xuôi chuẩn tắc của mục 2/6.4 chưa nêu rõ biểu thức và độ trễ; nên đưa quy tắc này vào phần yêu cầu chính để tránh tranh luận khi chấm. |
| P6.1 | IRQ theo IER và độ trễ | Phù hợp với mục 12: công thức IRQ và phản ánh thay đổi trong tối đa hai chu kỳ. |
| P6.2 | Reset mềm | Phần reset mềm, khôi phục CFG/BAUD/IER và dừng TX phù hợp mục 12. Test còn yêu cầu TXDATA về 0; mục 12 của `za.html` nêu CFG, BAUD, IER nhưng không nói rõ TXDATA/RXDATA. Đây là điều kiện mạnh hơn câu chữ 1.1. RTL hiện tại vốn xóa TXDATA và test PASS; không có lỗi FAIL nào được sửa bằng cách dựa riêng vào điều kiện chưa được nêu này. Cần ghi rõ trong spec nếu muốn chấm TXDATA sau reset mềm. |
| P7.1 | Song công 100 ký tự mỗi chiều | Là bài stress kiểm tra khả năng TX/RX đồng thời và flow control; phù hợp chức năng UART hai chiều. Con số 100 ký tự là tải kiểm thử, không phải giới hạn định lượng được nêu trong `za.html`. |

Không có test nào trong số các test FAIL ban đầu bị loại bỏ hoặc sửa kỳ vọng để làm regression xanh. Các lỗi reset, TX, RX và overrun ban đầu đều tương ứng hành vi được yêu cầu trong `za.html`. Hai điểm cần chủ spec làm rõ là quan hệ/thời điểm `rts_n` trong phần văn xuôi và phạm vi thanh ghi được reset mềm; chúng không gây FAIL trong regression đã sửa.

## Lỗi RTL tìm được và cách sửa

### 1. `rts_n` xuống thấp ngay khi nhả reset

**Triệu chứng:** Cả 20 test ban đầu báo assertion `ap_reset_outputs`. Assertion này kiểm tra `tx=1`, `rts_n=1`, `irq=0` tại cạnh đầu tiên sau reset.

**Nguyên nhân:** `rx_uart` tạo `rts_n` tổ hợp từ `~rst_n | soft_rst | rx_done | rx_dis`. Ngay khi `presetn` được nhả và RX đang rảnh, `rts_n` xuống 0, sớm hơn thời điểm reset contract yêu cầu đầu ra ở trạng thái reset.

**Sửa:** Thêm `reset_release_pending` để giữ `rts_n` cao qua cạnh clock đầu tiên sau khi nhả reset. Sau cạnh đó, `rts_n` tiếp tục theo trạng thái `rx_done`/`rx_dis` như flow control bình thường. Thay đổi ở `rtl/rx_uart.v`.

### 2. `tx_done` báo trước khi TX FSM kết thúc stop bit

**Triệu chứng:** P3.1/P3.2/P3.3 có khung TX bị bỏ hoặc không thấy trên chân `tx`; các test khác phụ thuộc việc có thể nạp ký tự tiếp theo sau `tx_done`.

**Nguyên nhân:** Stop counter đếm các ranh giới stop bit đã hoàn thành, nhưng `stop_last` cũ so sánh với 1/2. Do vậy `tx_done` lên trước khi FSM rời trạng thái STOP; một lệnh start mới có thể tới trong lúc FSM vẫn bận và bị mất.

**Sửa:** Định nghĩa lại `stop_last` là khoảng stop cuối đang chạy (count 0 cho một stop, count 1 cho hai stop), rồi chỉ phát `tx_done_pulse` và chuyển về IDLE tại ranh giới baud cuối của khoảng đó. Thay đổi ở `rtl/tx_uart.v` và `rtl/tx_controller.v`.

### 3. Pha tick TX không được làm sạch sau reset mềm giữa khung

**Triệu chứng:** P3.4 sau `soft_rst` bắt được start/data sai và độ rộng bit lệch 7,10% dù thanh ghi BAUD đã trở về giá trị reset.

**Nguyên nhân:** Bộ đếm 16× của TX chỉ quay vòng tự nhiên theo baud tick. Reset mềm giữa khung đưa FSM về IDLE nhưng không xóa pha của bộ đếm này; khung mới bắt đầu ở một vị trí tick cũ.

**Sửa:** Thêm `clr_tick` cho `tx_tick_cnt`, nối với `clr_baud` đang bật ở IDLE/WAIT_CTS. Pha được xóa khi TX rảnh/chờ CTS và trước khi start mới. Thay đổi ở `rtl/tx_tick_cnt.v` và `rtl/tx_uart.v`.

### 4. RX overrun bị đặt sau mọi khung đơn

**Triệu chứng:** P4/P5/P7 báo `overrun=1` kể cả khi chỉ nhận một khung rồi đọc RXDATA.

**Nguyên nhân:** `rx_done` từ `rx_uart` là cờ giữ mức 1 cho đến khi đọc RXDATA. `apb_regs` xử lý mọi chu kỳ `rx_done=1` như một khung mới; chu kỳ kế tiếp sau khi đặt `rx_done_flag`, logic hiểu nhầm cùng một cờ mức là khung thứ hai. Trong khi đó `rx_uart` đã có cờ overrun thật nhưng đầu ra này trước đó bị bỏ trống khi nối vào top.

**Sửa:** Nối `rx_overrun` thật từ `rx_uart` sang `apb_regs` và dùng nó cho STAT/IRQ. Thêm `rx_done_prev` để chỉ chốt RXDATA/parity/frame đúng một lần ở cạnh lên của `rx_done`, không diễn giải các chu kỳ giữ cờ thành khung mới. Thay đổi ở `rtl/apb_uart.v` và `rtl/apb_regs.v`.

## Tệp RTL đã sửa

- `rtl/rx_uart.v` — giữ RTS inactive qua cạnh clock đầu sau reset.
- `rtl/tx_controller.v` — hoàn tất TX ở ranh giới cuối stop bit.
- `rtl/tx_uart.v` — stop counter và làm sạch pha tick khi rảnh/chờ CTS.
- `rtl/tx_tick_cnt.v` — hỗ trợ xóa pha đồng bộ.
- `rtl/apb_uart.v` — nối cờ overrun RX thực vào thanh ghi/IRQ.
- `rtl/apb_regs.v` — bắt cạnh RX-done và phản ánh overrun thật trong STAT/IRQ.

Testbench, đặc tả và Makefile không bị sửa trong lượt sửa RTL này.

