# BẢNG KẾ HOẠCH KIỂM THỬ (TEST PLAN) APB UART (BẢN RÚT GỌN)

| Mã Test Case | Mục đích kiểm tra | Input / Điều kiện | Kết quả mong muốn | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| **TC_RST_01** | Kiểm tra `ADDR_STT` sau Reset | `rst_n = 0` $\rightarrow$ `rst_n = 1`, đọc `ADDR_STT` (`0x0C`) | `prdata = 32'h0000_0001` (`tx_ready = 1`), `pslverr = 0` | **PASS** |
| **TC_CFG_01** | Cấu hình và đọc lại `ADDR_CFG` | Ghi `0x4B` (9600-8E1) vào `ADDR_CFG` (`0x08`), đọc lại | `prdata = 32'h0000_004B`, `pslverr = 0` | **PASS** |
| **TC_TX_01** | Kiểm tra cờ bận TX khi bắt đầu phát | Ghi `0xA5` vào `ADDR_TX` (`0x00`), đọc `ADDR_STT` (`0x0C`) | Bit 0 `tx_ready = 0` (TX bận), `pslverr = 0` | **PASS** |
| **TC_TX_02** | Chặn ghi tràn TX FIFO (FIFO Full Protection) | Nạp đầy 16 byte vào `ADDR_TX`, ghi tiếp byte thứ 17 (`0xFF`) | Bị chặn ghi, phản hồi lỗi bus `pslverr = 1` | **PASS** |
| **TC_TX_03** | Cờ hoàn tất truyền khi TX phát hết FIFO | Polling đọc `ADDR_STT` chờ TX phát xong 16 byte | Bit 0 `tx_ready = 1` (TX core rảnh, TX FIFO rỗng) | **PASS** |
| **TC_RX_01** | Cờ báo nhận khi có frame UART hợp lệ | Bắn frame byte `0x3C` (9600-8E1) vào chân `rx` | Bit 1 `rx_ready = 1` (RX FIFO có dữ liệu) | **PASS** |
| **TC_RX_02** | Tính chính xác dữ liệu đọc từ `ADDR_RX` | Đọc `ADDR_RX` (`0x04`) sau khi nhận xong | `prdata[7:0] = 8'h3C`, `pslverr = 0` | **PASS** |
| **TC_RX_03** | Tự động xóa cờ `rx_ready` sau khi đọc RX | Đọc lại `ADDR_STT` (`0x0C`) ngay sau khi đọc `ADDR_RX` | Bit 1 `rx_ready = 0` (tự động xóa cờ) | **PASS** |
| **TC_ERR_01** | Bắt lỗi Parity sai (Error Injection) | Bắn byte `0x7B` vào `rx` với Parity bị đảo bit sai | Bit 2 `rx_byte_err = 1`, Bit 1 `rx_ready = 1` | **PASS** |
| **TC_ERR_02** | Tự động xóa cờ lỗi Parity sau khi đọc RX | Đọc `ADDR_RX` (`0x04`) lấy byte lỗi, đọc lại `ADDR_STT` | Bit 2 `rx_byte_err = 0` (tự động xóa cờ lỗi) | **PASS** |
| **TC_LOOP_01** | Kiểm tra vòng lặp Loopback (TX nối RX) | Nối `rx = tx`, ghi `0xD2` vào `ADDR_TX`, đọc `ADDR_RX` | Nhận đúng `0xD2`, không lỗi Parity, `rx_ready = 1` | **PASS** |
| **TC_INT_01** | Cấu hình và đọc lại thanh ghi ngắt `ADDR_IER` | Ghi `0x05` (bật ngắt RX & Overrun) vào `ADDR_IER` (`0x10`) | `prdata = 32'h0000_0005`, `pslverr = 0` | **PASS** |
| **TC_INT_02** | Kích hoạt chân ngắt `irq` khi nhận byte mới | Cấu hình `ier[0] = 1`, truyền 1 frame byte `0xA5` vào `rx` | Chân ngắt `irq = 1` ngay khi nhận xong Stop bit | **PASS** |
| **TC_INT_03** | Tự động hạ ngắt `irq` khi đọc `ADDR_RX` | Đọc `ADDR_RX` (`0x04`) khi chân ngắt `irq = 1` | Đọc đúng `0xA5`, chân ngắt `irq = 0` ngay lập tức | **PASS** |
| **TC_OVR_01** | Bắt lỗi tràn RX FIFO (Overrun) & kích hoạt ngắt | `ier[2] = 1`, nạp đầy 16 byte vào RX FIFO, bắn tiếp byte 17 | Bit 3 `overrun_latch = 1` và chân ngắt `irq = 1` | **PASS** |
| **TC_OVR_02** | Tự động xóa cờ Overrun & hạ `irq` sau khi đọc | Đọc cạn 16 byte trong RX FIFO, kiểm tra lại `ADDR_STT` | Bit 3 `overrun_latch = 0`, chân ngắt `irq = 0` | **PASS** |
