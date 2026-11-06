# Bảng mô tả Interface khối Điều khiển UART RX (rx_controller)

| Signal | Width | I/O | Des |
| :--- | :---: | :---: | :--- |
| clk | 1 | Input | Xung clock hệ thống đồng bộ |
| rst_n | 1 | Input | Tín hiệu reset hệ thống (tích cực mức thấp 0) |
| rx | 1 | Input | Tín hiệu đường truyền RX vào (dùng phát hiện Start bit) |
| bit_last | 1 | Input | Tín hiệu báo đã nhận đủ số bit dữ liệu và Parity |
| tick_cnt | 4 | Input | Giá trị đếm tick 16x (định thời điểm lấy mẫu giữa bit và hết bit) |
| baud_tick | 1 | Input | Xung chia tần Baud rate kích hoạt chuyển trạng thái FSM |
| num_b_stop | 2 | Input | Số lượng bit Stop cấu hình (1 hoặc 2) xác định thời gian giữ HOLD |
| shift_en | 1 | Output | Cho phép khối SIPO dịch lấy mẫu bit dữ liệu vào thanh ghi |
| tick_en | 1 | Output | Cho phép bộ đếm bit (bit_cnt) tăng lên 1 khi xong một bit |
| rx_busy | 1 | Output | Cờ báo FSM đang bận nhận khung (tích cực khi khác IDLE) |
| rx_done | 1 | Output | Xung báo hoàn thành nhận một khung dữ liệu hợp lệ |
| tick_clr | 1 | Output | Tín hiệu xóa bộ đếm mẫu tick_cnt về 0 |
| bit_clr | 1 | Output | Tín hiệu xóa bộ đếm số bit bit_cnt về 0 |
| baud_clr | 1 | Output | Tín hiệu giữ/reset bộ chia tần Baud rate khi ở trạng thái IDLE |
