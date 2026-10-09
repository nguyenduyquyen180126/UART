# Tài liệu Đặc tả Hoạt động Module `uart_regs` (`rtl/reg_uart.v`)

Tài liệu này mô tả chi tiết các trường hợp hoạt động, điều kiện kích hoạt và hành vi mong đợi của các thanh ghi trong module [`uart_regs`](../rtl/reg_uart.v).

---

## 1. Tổng quan Bản đồ Địa chỉ Thanh ghi (Address Map)

| Thanh ghi | Địa chỉ (`paddr`) | Quyền truy cập | Ý nghĩa |
| :--- | :---: | :---: | :--- |
| **TX Data** (`ADDR_TX`) | `12'h00` | R/W | Chứa dữ liệu cần truyền (`tx_data = tx_data_reg[7:0]`). |
| **RX Data** (`ADDR_RX`) | `12'h04` | R | Chứa dữ liệu nhận được từ khối RX (`rx_data_reg`). |
| **Config** (`ADDR_CFG`) | `12'h08` | R/W | Cấu hình tham số UART (baud, parity, stop/data bits). |
| **Control** (`ADDR_CTRL`) | `12'h0C` | R/W | Kích hoạt truyền dữ liệu (`start_tx = ctrl_reg[0]`). |
| **Status** (`ADDR_STT`) | `12'h10` | R | Trạng thái TX, RX và Error (`stt_reg[2:0]`). |

---

## 2. Chi tiết Hoạt động của từng Thanh ghi

### 2.1. Thanh ghi TX Data (`ADDR_TX = 12'h00`)

| Tình huống | Input | Output |
| :--- | :--- | :--- |
| **Reset hệ thống** | `rst_n == 0` | `tx_data_reg <= 32'h0`, ngõ ra `tx_data <= 8'h0`. |
| **Ghi dữ liệu thành công (TX Idle)** | `reg_en == 1`, `pwrite == 1`, `paddr == 12'h00`, `stt_reg[0] == 1` | `write_en` tích cực (`1`); `tx_data_reg <= pwdata`; ngõ ra `tx_data` nhận giá trị `pwdata[7:0]`. |
| **Ghi dữ liệu bị chặn (TX Busy)** | `reg_en == 1`, `pwrite == 1`, `paddr == 12'h00`, `stt_reg[0] == 0` | `tx_wr_en == 0` dẫn đến `write_en == 0`; `tx_data_reg` giữ nguyên giá trị cũ, thao tác ghi bị bỏ qua. |
| **Đọc thanh ghi TX** | `reg_en == 1`, `pwrite == 0`, `paddr == 12'h00` | `read_en == 1`; bus đọc `prdata` xuất ra giá trị hiện tại của `tx_data_reg`. |

---

### 2.2. Thanh ghi RX Data (`ADDR_RX = 12'h04`)

| Tình huống | Input | Output |
| :--- | :--- | :--- |
| **Reset hệ thống** | `rst_n == 0` | `rx_data_reg <= 32'h0`. |
| **Cập nhật dữ liệu từ RX** | `rst_n == 1` tại cạnh lên `clk` | `rx_data_reg <= rx_data` (luôn capture dữ liệu từ đầu vào `rx_data`). |
| **Đọc dữ liệu RX (Acknowledge)** | `reg_en == 1`, `pwrite == 0`, `paddr == 12'h04` | `read_en == 1`, `rx_read_ack == 1`; `prdata = rx_data_reg`. Đồng thời kích hoạt xóa cờ `stt_reg[1]` (RX ready) và cờ `stt_reg[2]` (Error). |
| **Cố ý ghi vào thanh ghi RX** | `reg_en == 1`, `pwrite == 1`, `paddr == 12'h04` | `write_en == 0`; lệnh ghi không có hiệu lực, không làm thay đổi thanh ghi. |

---

### 2.3. Thanh ghi Cấu hình CFG (`ADDR_CFG = 12'h08`)

| Tình huống | Input | Output |
| :--- | :--- | :--- |
| **Reset hệ thống** | `rst_n == 0` | `cfg_reg <= 32'h0`. Các tín hiệu ngõ ra: `data_bit_num <= 2'b00`, `stop_bit_num <= 0`, `parity_en <= 0`, `parity_type <= 0`, `baud_sel <= 2'b00`. |
| **Ghi cấu hình hợp lệ (UART Idle)** | `reg_en == 1`, `pwrite == 1`, `paddr == 12'h08`, `stt_reg[0] == 1 && rx_done == 1` (`uart_idle == 1`) | `write_en == 1`; `cfg_reg <= pwdata`. Các chân cấu hình phần cứng cập nhật theo `pwdata` (`baud_sel`, `parity`,...). |
| **Ghi cấu hình bị chặn (UART không Idle)** | `reg_en == 1`, `pwrite == 1`, `paddr == 12'h08`, `uart_idle == 0` | `cfg_wr_en == 0` dẫn đến `write_en == 0`; `cfg_reg` giữ nguyên cấu hình cũ, không bị ghi đè khi đang bận. |
| **Đọc thanh ghi CFG** | `reg_en == 1`, `pwrite == 0`, `paddr == 12'h08` | `read_en == 1`; `prdata = cfg_reg`. |

---

### 2.4. Thanh ghi Điều khiển CTRL (`ADDR_CTRL = 12'h0C`)

| Tình huống | Input | Output |
| :--- | :--- | :--- |
| **Reset hệ thống** | `rst_n == 0` | `ctrl_reg <= 32'h0`; `start_tx <= 1'b0`. |
| **Kích hoạt phát TX (Trigger Start)** | `reg_en == 1`, `pwrite == 1`, `paddr == 12'h0C`, `pwdata[0] == 1` | `write_en == 1`; `ctrl_reg <= pwdata`; tín hiệu `start_tx` tích cực lên mức `1` trong 1 chu kỳ clock. Đồng thời kích hoạt `tx_write_ack == 1` để xóa cờ `stt_reg[0] <= 0` (báo hiệu TX đang bận). |
| **Tự động xóa bit `start_tx` (Pulse)** | Chu kỳ clock kế tiếp sau khi kích hoạt | `ctrl_reg[0] <= 1'b0` (tự động xóa bit về 0), ngõ ra `start_tx <= 1'b0` tạo thành 1 xung đơn (single clock pulse). |
| **Ghi giá trị không kích hoạt** | `reg_en == 1`, `pwrite == 1`, `paddr == 12'h0C`, `pwdata[0] == 0` | `write_en == 1`; `ctrl_reg <= pwdata`; `start_tx` giữ ở mức `0`, không xóa `stt_reg[0]`. |
| **Đọc thanh ghi CTRL** | `reg_en == 1`, `pwrite == 0`, `paddr == 12'h0C` | `read_en == 1`; `prdata = ctrl_reg`. |

---

### 2.5. Thanh ghi Trạng thái STT (`ADDR_STT = 12'h10`)

| Tình huống | Input | Output |
| :--- | :--- | :--- |
| **Reset hệ thống** | `rst_n == 0` | `stt_reg <= 32'h0000_0001` (Bit 0 được khởi tạo mức 1 báo TX sẵn sàng). |
| **TX bắt đầu truyền** | `tx_write_ack == 1` (khi ghi `pwdata[0] = 1` vào `ADDR_CTRL`) | `stt_reg[0] <= 1'b0` (báo trạng thái TX đang bận). |
| **TX truyền xong** | `tx_done == 1` (và không có `tx_write_ack`) | `stt_reg[0] <= 1'b1` (báo TX hoàn thành / sẵn sàng truyền tiếp). |
| **RX nhận xong dữ liệu mới** | `rx_done == 1` (và không có `rx_read_ack`) | `stt_reg[1] <= 1'b1` (báo có dữ liệu mới trong RX). |
| **Host đọc dữ liệu RX (Xóa cờ RX)** | `rx_read_ack == 1` (khi đọc `ADDR_RX`) | `stt_reg[1] <= 1'b0` (xóa cờ báo dữ liệu đã được đọc). |
| **Phát hiện lỗi truyền nhận** | `error == 1` | `stt_reg[2] <= 1'b1` (báo lỗi parity/frame). |
| **Xóa cờ lỗi sau khi đọc RX** | `rx_read_ack == 1` (và `error == 0`) | `stt_reg[2] <= 1'b0` (tự động xóa cờ lỗi khi host đọc dữ liệu RX). |
| **Đọc thanh ghi STT** | `reg_en == 1`, `pwrite == 0`, `paddr == 12'h10` | `read_en == 1`; `prdata = stt_reg`. |
| **Ghi vào thanh ghi STT** | `reg_en == 1`, `pwrite == 1`, `paddr == 12'h10` | `write_en == 0`; `stt_reg` là thanh ghi chỉ đọc (Read-Only) từ phía bus, giá trị không thay đổi bởi bus write. |
