# Bảng mô tả Interface khối UART RX (uart_rx)

| Signal | Width | I/O | Des |
| :--- | :---: | :---: | :--- |
| clk | 1 | Input | Xung clock hệ thống đồng bộ |
| rst_n | 1 | Input | Tín hiệu reset hệ thống (tích cực mức thấp 0) |
| rx | 1 | Input | Đường truyền nối tiếp dữ liệu nhận vào (UART RX line) |
| baud_sel | 2 | Input | Chọn tốc độ Baud (00: 2400, 01: 4800, 10: 9600, 11: 19200 bps) |
| data_b_num | 2 | Input | Cấu hình số bit dữ liệu trong khung (00: 5, 01: 6, 10: 7, 11: 8 bit) |
| stop_b_num | 1 | Input | Cấu hình số bit Stop (0: 1 stop bit, 1: 2 stop bit) |
| parity_en | 1 | Input | Cho phép kiểm tra bit Parity (1: bật, 0: tắt) |
| parity_type | 1 | Input | Lựa chọn kiểu Parity (0: Even / chẵn, 1: Odd / lẻ) |
| rx_data | 32 | Output | Dữ liệu nhận được sau giải mã khung (Zero-extended lên 32-bit) |
| rx_busy | 1 | Output | Cờ báo bộ thu RX đang bận trong quá trình nhận khung dữ liệu |
| rx_done | 1 | Output | Xung báo hoàn thành nhận một khung dữ liệu hợp lệ |
| error | 1 | Output | Cờ báo lỗi Parity khi dữ liệu nhận không khớp kiểm tra |
