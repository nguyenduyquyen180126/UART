# Testplan APB UART

Nguồn: [tb_apb_uart.v](../tb/tb_apb_uart.v), [RX ảo](../tb/models/uart_rx_virtual.v) và [TX ảo](../tb/models/uart_tx_virtual.v).

Bảng này được lập từ testbench và mở rộng theo APB_UART Specification. **Hiện có 14 nhóm testcase**. Phần 2 giữ bảng 17 kiểm tra của phiên bản ban đầu; phần 8 liệt kê các kiểm tra bổ sung. Nhóm 7 và nhóm 13 cùng phủ đủ 96 tổ hợp baud và định dạng khung, với các bộ so sánh hoạt động xuyên suốt mô phỏng.

## 1. Điều kiện và quy ước

- DUT: `apb_uart`, clock 50 MHz, chu kỳ 20 ns, reset mức thấp.
- TX FIFO sâu 16 byte; RX FIFO sâu 16 phần tử, mỗi phần tử có 8 bit dữ liệu và 1 bit lỗi.
- Các nhóm 1–6 sử dụng 8E1 ở 9600 baud sau khi cấu hình CFG = `0x4B`.
- Địa chỉ trong bảng là offset APB, không bao gồm base address của CPU.
- Các nhóm chạy tuần tự; trạng thái FIFO và cấu hình được kế thừa nếu không được thay đổi.

| Offset | Thanh ghi | Các bit sử dụng trong testplan |
|---|---|---|
| `0x00` | TX_DATA | Byte cần phát ở `[7:0]` |
| `0x04` | RX_DATA | Byte nhận ở `[7:0]`, lỗi parity của byte ở `[8]` |
| `0x08` | CFG | `[1:0]`: 5–8 data bit; `[2]`: 1/2 stop; `[3]`: parity enable; `[4]`: even/odd; `[6:5]`: baud |
| `0x0C` | STT | `[0]`: TX hoàn toàn rảnh; `[1]`: RX có dữ liệu; `[2]`: lỗi byte đầu RX FIFO; `[3]`: overrun; `[4]`: TX full; `[5]`: RX full |
| `0x10` | IER | `[0]`: RX IRQ enable; `[1]`: TX IRQ enable; `[2]`: overrun IRQ enable |

## 2. Bảng testplan theo các kiểm tra hiện có

| ID | Nhóm trong code | Mục tiêu | Điều kiện / dữ liệu đầu vào | Thao tác | Kết quả mong đợi / tiêu chí PASS |
|---|---|---|---|---|---|
| TP-01 | Testcase 1 | Trạng thái sau reset | Reset thấp 100 ns, sau đó nhả reset | Đọc STT | `prdata = 0x01`, `pslverr = 0`: TX rảnh, RX rỗng, không lỗi |
| TP-02 | Testcase 1 | Ghi/đọc cấu hình | UART rảnh | Ghi CFG = `0x4B`, đọc lại | Đọc đúng `0x4B`, phản hồi đọc không lỗi |
| TP-03 | Testcase 2 | Báo TX bận khi có dữ liệu | FIFO ban đầu rỗng | Ghi TX_DATA = `0xA5`, đọc STT | `STT[0] = 0` |
| TP-04 | Testcase 2 | Chặn ghi khi TX FIFO đầy | Byte đầu đã vào PISO; ghi tiếp 16 byte `0x10…0x1F` để đầy FIFO | Thử ghi thêm `0xFF` | `pslverr = 1` ở giao dịch ghi thêm; byte bị từ chối không được xuất hiện trên TX |
| TP-05 | Testcase 2 | TX hoàn tất toàn bộ hàng đợi | TX đang phát các byte đã ghi | Poll STT tối đa 500 lượt, cách nhau khoảng một bit | `STT[0]` trở lại `1` trước timeout |
| TP-06 | Testcase 3 | Báo có dữ liệu RX | TX ảo phát `0x3C`, đúng parity | Poll STT tối đa 50 lượt, cách nhau khoảng nửa bit | `STT[1] = 1` trước timeout |
| TP-07 | Testcase 3 | RX nhận đúng byte | RX FIFO có `0x3C` | Đọc RX_DATA | `[7:0] = 0x3C`; bộ so sánh đồng thời đối chiếu cả `[8:0]` với byte và bit lỗi mong đợi |
| TP-08 | Testcase 3 | RX trở về rỗng sau khi đọc byte cuối | Chỉ có một byte trong RX FIFO | Đọc STT sau khi lấy byte | `STT[1] = 0` |
| TP-09 | Testcase 4 | Phát hiện lỗi parity RX | TX ảo phát `0x7B`, đảo bit parity | Poll đến khi có dữ liệu, kiểm tra STT | `STT[2] = 1`; khi đọc RX_DATA, bộ so sánh mong đợi bit lỗi `[8] = 1` |
| TP-10 | Testcase 4 | Không giữ lỗi sau khi lấy byte lỗi cuối | RX FIFO chứa một byte lỗi | Đọc RX_DATA rồi đọc STT | `STT[2] = 0` vì byte lỗi đã được pop và FIFO rỗng |
| TP-11 | Testcase 5 | Loopback TX → RX | Mux nối chân TX của DUT sang RX của DUT | Ghi `0xD2`, poll RX rồi đọc RX_DATA | Nhận đúng `0xD2` trước timeout; chờ TX hoàn tất trước khi ngắt loopback |
| TP-12 | Testcase 6 | Ghi/đọc cho phép ngắt | Cấu hình UART giữ nguyên | Ghi IER = `0x05`, đọc lại | Đọc đúng `0x05` — cho phép RX và overrun IRQ |
| TP-13 | Testcase 6 | Ngắt khi RX có dữ liệu | IER = `0x05` | TX ảo phát `0xA5`, chờ 100 ns sau task phát | `irq = 1` |
| TP-14 | Testcase 6 | Hạ RX IRQ khi FIFO rỗng | Chỉ có byte `0xA5` trong RX FIFO | Đọc RX_DATA rồi chờ 100 ns | Nhận đúng `0xA5`, `irq = 0` |
| TP-15 | Testcase 6 | Phát hiện RX overrun | Phát `0x30…0x3F` đủ 16 byte mà không đọc | Phát thêm byte thứ 17 là `0xFF`, đọc STT | `STT[3] = 1`, `irq = 1` |
| TP-16 | Testcase 6 | Bảo toàn dữ liệu FIFO và xóa overrun | RX FIFO đầy, overrun đã được chốt | Đọc 16 lần RX_DATA, sau đó đọc STT | Bộ so sánh nhận đúng thứ tự `0x30…0x3F`; byte dư `0xFF` không thay thế dữ liệu; `STT[3] = 0`, `irq = 0` sau khi đọc cạn |
| TP-17 | Testcase 7 + bộ so sánh toàn cục | Đối chiếu UART độc lập, full-duplex và hồi quy lỗi parity TX | Ma trận cấu hình ở phần 3 | Chạy `reference_exchange`; RX ảo giải mã TX của DUT, TX ảo phát vào RX của DUT; kiểm tra hàng đợi cuối mô phỏng | Tất cả byte TX/RX khớp; TX không lỗi start/parity/stop; không timeout; không còn byte mong đợi chưa xử lý; `ref_errors = 0` |

Các bộ so sánh không tạo thêm một dòng PASS cho mỗi byte. Chúng tích lũy lỗi và được tổng hợp cuối mô phỏng. Số kiểm tra PASS khác số khung UART đã truyền; phiên bản mới có thêm các kiểm tra SP ở phần 8.

## 3. Ma trận cấu hình trong TP-17

| Tập kiểm tra | Baud | Data bits | Parity | Stop bits | Byte TX DUT | Byte TX ảo → DUT RX | Số lượt |
|---|---|---|---|---|---|---|---:|
| Mọi tổ hợp định dạng khung | 19200 | 5, 6, 7, 8 | None, Even, Odd | 1, 2 | `0xA5` | `0xDA` | `4 × 3 × 2 = 24` |
| Mọi lựa chọn baud ở 8N1 | 2400, 4800, 9600, 19200 | 8 | None | 1 | `0x55` | `0xAA` | 4 |
| **Tổng** | | | | | | | **28** |

Với khung dưới 8 bit, chỉ các bit thấp tương ứng được so sánh:

| Data bits | DUT TX từ `0xA5` | DUT RX từ `0xDA` |
|---:|---|---|
| 5 | `0x05` | `0x1A` |
| 6 | `0x25` | `0x1A` |
| 7 | `0x25` | `0x5A` |
| 8 | `0xA5` | `0xDA` |

Mỗi lượt chốt cấu hình khi UART rảnh, phát hai chiều đồng thời, chờ TX rảnh và RX có byte, rồi đọc RX_DATA. Không phải tích chéo đầy đủ mọi định dạng với mọi baud: 24 tổ hợp định dạng chỉ chạy ở 19200 baud.

## 4. Cơ chế đối chiếu và điều kiện kết thúc

| Thành phần | Dữ liệu mong đợi | Dữ liệu thực tế / điều kiện kiểm tra |
|---|---|---|
| TX scoreboard | Byte của giao dịch ghi TX_DATA được APB chấp nhận | Byte giải mã bởi `u_virtual_rx`, đúng thứ tự |
| Bộ kiểm tra khung TX | Start = 0, parity tính từ data nhận được, stop = 1 | Các mẫu giữa bit của RX ảo |
| RX scoreboard | Byte TX ảo được yêu cầu phát, kèm bit lỗi parity chủ động bơm | RX_DATA `[8:0]` tại cạnh hoàn tất giao dịch đọc APB |
| RX FIFO tham chiếu | Chỉ giữ tối đa 16 byte; byte dư bị bỏ | Thứ tự dữ liệu khi đọc cạn FIFO trong phép thử overrun |
| Kiểm tra cuối | Tất cả byte mong đợi đã được xử lý | `ref_tx_wr == ref_tx_rd`, `ref_rx_wr == ref_rx_rd` |
| Watchdog | Mô phỏng kết thúc hữu hạn | `$fatal` nếu vượt 1 giây thời gian mô phỏng |

`virtual_rx_done` báo kết quả từng khung cho Compare. `STT[0]` của DUT báo toàn bộ TX FIFO và bộ phát rảnh; hai tín hiệu có ý nghĩa khác nhau.

Đạt khi không có lỗi tham chiếu, tất cả kiểm tra PASS và mô phỏng thoát bình thường. Khi thất bại, testbench kết thúc bằng `$fatal` với mã thoát khác 0.

## 5. Kết quả phiên bản ban đầu đã ghi nhận

Lần chạy sau khi sửa chốt `parity_latched` trong TX:

| Chỉ số | Kết quả |
|---|---:|
| Kiểm tra PASS | 17 |
| Kiểm tra FAIL | 0 |
| Khung TX đã đối chiếu | 46 |
| Byte RX đã đối chiếu | 48 |
| Lỗi tham chiếu | 0 |

Đây là kết quả lần chạy đã ghi nhận, không phải báo cáo coverage chức năng/code coverage. Xem [báo cáo lỗi parity TX](BUG_TX_PARITY_SAU_KHI_POP_FIFO.md) để biết hành vi trước và sau sửa.

## 6. Phạm vi và giới hạn

Các khoảng trống của phiên bản ban đầu đã được bổ sung theo bảng SP ở phần 8,
bao gồm truy cập APB sai, khóa CFG, cô lập/mask IRQ, start giả và tích chéo baud
với định dạng. Phép thử framing error được thêm để làm rõ yêu cầu phát hiện lỗi
gói nhận; xem diễn giải SP-20 bên dưới.

Chưa có testcase riêng cho reset giữa khung, nhiễu/break, sai lệch baud, dữ liệu
ngẫu nhiên hoặc tất cả trường hợp đọc/ghi FIFO đồng thời ở biên đầy/rỗng.
Chưa đo code coverage hay functional coverage bằng công cụ.

## 7. Lệnh chạy

Từ thư mục `UART`:

```bash
iverilog -g2012 -s tb_apb_uart -o /tmp/tb_apb_uart tb/tb_apb_uart.v tb/models/*.v rtl/*.v
vvp /tmp/tb_apb_uart +NO_VCD
```

Bỏ `+NO_VCD` để tạo `wave_apb_uart.vcd`, hoặc dùng `make apb_uart` với Makefile hiện tại.

## 8. Testcase bổ sung theo APB_UART Specification

Các nhóm dưới đây được bổ sung từ spec sau khi lập bảng TP-01…TP-17. Kết quả
17 PASS ở phần 5 thuộc bộ kiểm thử cũ, trước khi bổ sung các nhóm này. Số kiểm tra
PASS hiện tăng theo các vòng lặp; không còn cố định bằng 17.

| ID | Nhóm code | Yêu cầu spec | Stimulus / thao tác | Tiêu chí kiểm tra |
|---|---|---|---|---|
| SP-01 | TC8 | APB3: truy cập bất hợp lệ | Đọc/ghi `0x014`, `0xFFC`, `0x001`, `0x002`, `0x003`, `0x006` | `PSLVERR=1`; đọc trả 0; CFG không bị đổi |
| SP-02 | TC8 | Bảo vệ thanh ghi | Ghi RX_DATA và STT | `PSLVERR=1` |
| SP-03 | TC8 | APB SETUP không thực hiện giao dịch | Giữ SETUP ghi TX 3 chu kỳ, sau đó ACCESS | Không phát trong SETUP; đúng một khung sau ACCESS |
| SP-04 | TC8 | SETUP đọc không pop FIFO | Giữ SETUP đọc RX rồi hủy trước ACCESS | Lần đọc hợp lệ tiếp theo vẫn lấy đúng byte |
| SP-05 | TC8 | APB back-to-back | Ghi rồi đọc IER, giữ PSEL cao và hạ PENABLE ở SETUP kế tiếp | Hai giao dịch hoàn tất, đọc đúng dữ liệu |
| SP-06 | TC9 | Khóa CFG khi TX hoạt động | Đổi CFG trong lúc TX phát | `PSLVERR=1`, CFG cũ được giữ |
| SP-07 | TC9 | Khóa CFG khi RX hoạt động | TX ảo đang gửi; đồng thời đổi CFG qua APB | `PSLVERR=1`, CFG và dữ liệu RX được giữ đúng |
| SP-08 | TC9 | Cho lập trình lại khi rảnh | Đổi CFG sau khi TX/RX rảnh | Ghi/đọc lại thành công |
| SP-09 | TC10 | Mask độc lập từng IRQ | Thử cả 8 mask khi chỉ TX ready, TX+RX ready và cả ba nguồn active | `irq = OR(active_sources & IER)` |
| SP-10 | TC10 | TX ready chỉ khi phát hết FIFO | Bật riêng TX IRQ, gửi liên tiếp `0x01`, `0x03` | IRQ hạ khi bận, vẫn thấp khi byte thứ hai đang phát, lên lại khi toàn bộ TX rảnh |
| SP-11 | TC10 | RX ready khi FIFO còn dữ liệu | Gửi 2 byte; đọc lần lượt | IRQ giữ cao sau byte đầu, hạ sau byte cuối |
| SP-12 | TC2 bổ sung | TX FIFO 8×16 | Byte đầu vào PISO, ghi thêm 16 byte; đọc cờ full sau từng lần ghi | TX full chỉ lên tại byte thứ 16 đang chờ; byte dư bị từ chối |
| SP-13 | TC10 | RX FIFO 9×16 và overrun | Đọc full/overrun sau từng byte thứ 1…16; gửi thêm byte 17 | Full chỉ lên tại byte 16, overrun chỉ xuất hiện sau byte dư |
| SP-14 | TC10 | Cô lập overrun IRQ | Chỉ bật IER[2], che RX/TX; tạo overrun rồi đọc 1 byte | IRQ do overrun lên; sau đọc hạ dù RX FIFO vẫn còn dữ liệu |
| SP-15 | TC11 | Bit lỗi đi cùng từng phần tử RX | Gửi lần lượt byte sai/đúng/sai parity rồi đọc FIFO | STT[2] và RX_DATA[8] đi theo byte đầu: 1/0/1 |
| SP-16 | TC11 | Phát hiện sai odd parity | Gửi `0xA6` ở 8O1 với parity đảo | RX_DATA = `0x1A6` |
| SP-17 | TC12 | Start giả | Bật RX IRQ; phát xung thấp dài 1/4 và 3/8 bit, trở lại idle | Không byte, không lỗi, không IRQ; UART trở lại rảnh |
| SP-18 | TC12 | Phục hồi sau start giả | Sau xung giả gửi khung `0xA5` hợp lệ | Nhận đúng byte, không lỗi |
| SP-19 | TC13 + TC7 | Mọi lựa chọn baud và định dạng | Bổ sung 72 tổ hợp ở 2400/4800/9600; TC7 đã có 24 tổ hợp ở 19200 | Đủ 96 tổ hợp baud × data bits × parity × stop bits, đều truyền nhận full-duplex đúng |
| SP-20 | TC14 | Lỗi gói nhận: kiểm tra stop sai | 8N1, data `0xA5`, stop bị giữ thấp qua điểm lấy mẫu | Mong đợi STT[2]=1 và RX_DATA[8]=1; kiểm tra này xác định khả năng phát hiện framing error |

**Diễn giải SP-20:** spec ghi “phát hiện có lỗi ở gói tin được nhận” nhưng chưa liệt
kê loại lỗi. Testcase dùng yêu cầu phát hiện stop sai như một phép kiểm tra framing
error và được chạy mặc định. Nếu yêu cầu chỉ giới hạn ở parity, cần xác nhận lại
phạm vi đặc tả; không dùng kết quả parity PASS để khẳng định có phát hiện framing error.

Các mục chưa kiểm tra riêng sau bổ sung: reset giữa khung, nhiễu/break, sai lệch
baud, stimulus ngẫu nhiên, tất cả điểm biên đọc/ghi FIFO đồng thời và coverage bằng
công cụ. Các testcase APB trên kiểm tra các hành vi liệt kê, không phải chứng nhận
đầy đủ tuân thủ APB3 AMBA.

## 9. Kết quả trước khi sửa framing error (lịch sử)

Đã biên dịch và chạy `tb_apb_uart` với Icarus Verilog, không sửa RTL trong lần bổ sung này:

| Chỉ số | Kết quả |
|---|---:|
| Nhóm testcase | 14 |
| Kiểm tra PASS theo bộ đếm testbench | 119 |
| Kiểm tra FAIL theo bộ đếm testbench | 2 |
| Khung TX đối chiếu | 122 |
| Byte RX đối chiếu | 146 |
| Lỗi scoreboard | 1 (được tính trong 2 FAIL ở trên) |
| Thời gian mô phỏng | Khoảng 271 ms |

Hai FAIL cùng xuất phát từ **SP-20 / TC14**, không phải hai nguyên nhân riêng:

1. Stop bit bị kéo thấp nhưng `STT[2]` không bật.
2. RX_DATA trả `0x0A5` thay vì `0x1A5`: data đúng, bit lỗi `[8]` không bật.

```text
[SPEC FAIL] SPEC GAP: invalid stop must flag received-frame error (parity disabled)
[REF FAIL] RX #145 expected=1a5 actual=0a5
[UART AO] TX checked=122 RX checked=146 errors=1
```

Cơ sở từ RTL: `rx_controller.v` chờ đủ thời gian stop trong HOLD nhưng không kiểm
tra mức RX tại stop; `error_check.v` chỉ kiểm tra parity và trả error=0 khi parity
tắt. Vì vậy phép thử 8N1 với stop sai không tạo cờ lỗi. Các nhóm APB, khóa CFG,
IRQ mask, FIFO, parity, start giả và ma trận 96 tổ hợp không ghi nhận lỗi trong
lần chạy này. Testbench thoát mã khác 0 để giữ nguyên bằng chứng sai khác với
kỳ vọng framing error; không tự đánh dấu PASS hay bỏ qua testcase này.

Lệnh tái hiện từ thư mục `UART`:

```bash
iverilog -g2012 -s tb_apb_uart -o /tmp/tb_apb_uart tb/tb_apb_uart.v tb/models/*.v rtl/*.v
vvp /tmp/tb_apb_uart +NO_VCD
```

## 10. Kết quả sau khi sửa framing error — hiện tại

Đã sửa `rx_controller.v` và `rx_uart.v`, giữ nguyên APB, map thanh ghi, kích thước
FIFO và bốn trạng thái FSM. RX lấy mẫu từng stop bit và gộp lỗi framing với parity
vào bit lỗi thứ 9 hiện có. `rx_done` nay phát khi lấy mẫu stop cuối, vì vậy thời
điểm hoàn tất RX thay đổi so với RTL cũ để kiểm tra đủ stop.

TC14 được mở rộng bằng task `check_stop_frame`: 8N1 stop sai; 8N2 sai stop đầu,
sai stop sau, sai cả hai, cả hai đúng; 8E2 sai stop sau; 8O2 sai stop đầu; sau đó
nhận khung odd parity hợp lệ để kiểm tra phục hồi. Mỗi khung kiểm tra cấu hình,
STT, dữ liệu cùng bit lỗi RX_DATA và trạng thái sau khi đọc byte cuối.

| Testbench | PASS | FAIL | Kết quả |
|---|---:|---:|---|
| `tb_apb_uart` | 149 | 0 | 122 khung TX, 153 byte RX, 0 lỗi tham chiếu |
| `tb_rx_uart` | 7 | 0 | Hồi quy bộ nhận |
| `tb_full_duplex` | 3 | 0 | Hồi quy truyền nhận đồng thời |
| `tb_firmware_scenario` | 9 | 0 | Hồi quy luồng firmware mô phỏng |

Toàn bộ kiểm tra trong bốn lượt chạy trên đều PASS. Đây là **100% testcase đã
chạy**, không phải 100% code coverage hay mọi tình huống UART. Các giới hạn về
nhiễu, break, dung sai baud, reset giữa khung và các biên FIFO ngẫu nhiên vẫn còn.

Xem [báo cáo thay đổi từng dòng và hướng dẫn chạy](BAO_CAO_FIX_FRAMING_VA_CHAY_TESTBENCH.md).
