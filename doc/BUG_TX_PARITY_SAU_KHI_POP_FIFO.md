# Bug TX UART: parity thay đổi sau khi pop TX FIFO

Ngày ghi nhận: 16/10/2026.

Trạng thái: đã áp dụng sửa trong `rtl/tx_uart.v`: chốt `parity_latched` cùng lúc nạp PISO và dùng giá trị đã chốt ở trạng thái PARITY. Giữ nguyên giao diện, FIFO và FSM. Các đoạn mô tả lỗi bên dưới ghi lại hành vi trước khi sửa.

## Hiện tượng và ảnh hưởng

Bộ thu UART tham chiếu giải mã đúng byte dữ liệu từ TX của DUT nhưng phát hiện bit parity không khớp ở một số khung. Thiết bị nhận có kiểm tra parity có thể báo lỗi hoặc loại bỏ các byte này.

Bug ảnh hưởng cả even và odd parity khi parity được bật. Khi tắt parity, khung không phát bit parity nên không biểu hiện lỗi này. Lỗi có thể xuất hiện ở cả 5, 6, 7 hoặc 8 bit dữ liệu, tùy dữ liệu và trạng thái FIFO.

## Các file liên quan

| File | Vai trò trong lỗi |
|---|---|
| [apb_uart.v](../rtl/apb_uart.v) | Nối đầu TX FIFO vào `tx_uart`; pop FIFO khi `tx_load_reg` bật |
| [sync_fifo.v](../rtl/sync_fifo.v) | Đầu ra tổ hợp trỏ đến phần tử tại con trỏ đọc hiện tại |
| [tx_uart.v](../rtl/tx_uart.v) | Cấp cùng `tx_data_masked` cho PISO và bộ tính parity, nhưng chỉ PISO lưu dữ liệu |
| [tx_piso.v](../rtl/tx_piso.v) | Giữ byte hiện tại khi `load_reg` bật để phát các bit dữ liệu |
| [tx_parity.v](../rtl/tx_parity.v) | Tính parity tổ hợp từ đầu vào, không lưu kết quả theo từng khung |
| [tb_apb_uart.v](../tb/tb_apb_uart.v) | Ghi nhận byte APB đã chấp nhận và so sánh với bộ thu ảo |
| [uart_rx_virtual.v](../tb/models/uart_rx_virtual.v) | Giải mã độc lập chân TX, kiểm tra parity từ chính các bit dữ liệu nhận được |

## Nguyên nhân gốc

Trong `apb_uart.v`:

```verilog
assign tx_fifo_rd_en = tx_load_reg;
```

Đầu ra `tx_fifo_rd_data` được nối vào `tx_data` của `tx_uart`. Trong `sync_fifo.v`:

```verilog
assign dout = fifo[rptr[ADDR_WIDTH-1:0]];
```

Khi bộ phát đang rảnh và FIFO có dữ liệu, `load_reg` bật. Tại cùng một cạnh clock:

1. PISO chốt byte ở đầu FIFO vào thanh ghi riêng.
2. FIFO tăng con trỏ đọc để pop byte đó.
3. Sau khi con trỏ cập nhật, đầu ra FIFO chuyển sang ô tiếp theo.

Trong `tx_uart.v`, parity vẫn được tính trực tiếp từ đầu FIFO:

```verilog
parity u_parity(
    .data_in(tx_data_masked),
    .parity_type(parity_type),
    .parity_bit(parity_bit)
);
```

Khi đến trạng thái PARITY, bộ chọn đầu ra dùng:

```verilog
2'b11: tx = parity_bit;
```

Vì vậy, các bit data được phát từ **byte đã chốt trong PISO**, còn parity có thể được tính từ **ô FIFO tiếp theo**. Nếu FIFO đã rỗng, ô được trỏ đến không phải dữ liệu hợp lệ của khung; bộ tính parity vẫn đang sử dụng nó.

Công thức XOR trong `tx_parity.v` đúng. Bug nằm ở việc tích hợp đường dữ liệu và thời điểm lưu parity trong `tx_uart.v`.

## Ví dụ tái hiện dễ quan sát

Cấu hình UART thành 8E1, ví dụ CFG = `0x4B` tại 9600 baud. Để bảo đảm hai byte minh họa đã nằm trong FIFO khi byte đầu được nạp, có thể:

1. Gửi một byte mở đầu để bộ phát đang bận.
2. Trong thời gian byte mở đầu đang phát, ghi tiếp `0x01` rồi `0x03` vào TX_DATA.
3. Theo dõi khung `0x01` tiếp theo bằng RX ảo hoặc waveform.

Khi bộ phát nạp `0x01`:

```text
Trước cạnh load:
    Đầu TX FIFO = 0x01, phần tử kế tiếp = 0x03

Sau cạnh load:
    PISO        = 0x01
    Đầu TX FIFO = 0x03
```

| Byte | Nhị phân | Số bit 1 | Even parity |
|---|---|---:|---:|
| `0x01` | `00000001` | 1 | 1 |
| `0x03` | `00000011` | 2 | 0 |

Khung mong đợi của `0x01`:

```text
START | d0 d1 d2 d3 d4 d5 d6 d7 | PARITY | STOP
  0   |  1  0  0  0  0  0  0  0 |   1    |  1
```

Khung lỗi có data của `0x01` nhưng parity bằng `0`, lấy theo `0x03`.

Không phải mọi khung đều sai: nếu byte đang phát và ô FIFO tiếp theo có cùng parity thì bug bị che khuất. Ví dụ `0x01` và `0x02` đều có even parity bằng `1`.

## Cách chạy bộ kiểm thử hiện tại

Từ thư mục `UART`:

```bash
iverilog -g2012 -s tb_apb_uart -o /tmp/tb_apb_uart tb/tb_apb_uart.v tb/models/*.v rtl/*.v
vvp /tmp/tb_apb_uart +NO_VCD
```

Bỏ `+NO_VCD` để xuất `wave_apb_uart.vcd`.

Bộ thu ảo chỉ dùng chân TX và cấu hình khung, không đọc trạng thái nội bộ DUT. Bộ so sánh lấy dữ liệu mong đợi từ các giao dịch ghi TX_DATA được APB chấp nhận. Vì thế, phép kiểm tra có thể phát hiện lỗi mà loopback hoặc chỉ kiểm tra dữ liệu byte chưa chỉ ra được.

Log lỗi có dạng:

```text
[REF FAIL] TX frame data=... start_error=0 parity_error=1 stop_error=0 ...
```

Các tín hiệu nên xem:

- `uart_inst.tx_load_reg`, `uart_inst.tx_fifo_rd_data`.
- `uart_inst.u_tx_uart.tx_data_masked`, `uart_inst.u_tx_uart.parity_bit` và `uart_inst.u_tx_uart.parity_latched`.
- `uart_inst.u_tx_uart.u_piso.data` và chân `tx`.
- `u_virtual_rx.rx_data`, `u_virtual_rx.parity_error`, `u_virtual_rx.rx_done`.
- `tx_compare_expected`, `tx_compare_actual`, `tx_compare_pass`.

## Kết quả đã ghi nhận

Với bộ kiểm thử sau khi tách RX ảo và TX ảo thành hai module:

| Phiên bản chạy | Khung TX đã đối chiếu | Byte RX đã đối chiếu | Lỗi tham chiếu |
|---|---:|---:|---:|
| RTL trước khi sửa | 46 | 48 | 15 lỗi parity TX |
| Bản sao RTL sửa tạm ngoài project | 46 | 48 | 0 |
| RTL trong project sau khi chốt `parity_latched` | 46 | 48 | 0 |

Bản sửa tạm giữ byte dữ liệu theo `load_reg` rồi dùng byte đã giữ để tính parity. Kết quả này xác nhận nguyên nhân. Sau đó bản sửa chốt trực tiếp parity đã được áp dụng vào project và chạy lại toàn bộ `tb_apb_uart`: **17 kiểm tra PASS, 0 FAIL**, đối chiếu 46 khung TX và 48 byte RX, 0 lỗi tham chiếu. Các kết quả chỉ áp dụng cho những trường hợp được bộ kiểm thử bao phủ.

Số lỗi phụ thuộc dữ liệu và trình tự kiểm thử, không phải tỷ lệ lỗi cố định của UART. Trong phiên bản testbench này, có lỗi sẽ kết thúc bằng `$fatal` và mã thoát khác 0.

## Cách sửa đã áp dụng

Bản sửa chốt trực tiếp kết quả parity ngay lúc PISO nạp dữ liệu. Trong `tx_uart.v` đã thêm:

```verilog
reg parity_latched;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        parity_latched <= 1'b0;
    else if (load_reg)
        parity_latched <= parity_bit;
end
```

Đổi nhánh chọn parity thành:

```verilog
2'b11: tx = parity_latched;
```

Tại cạnh `load_reg`, cả PISO và `parity_latched` lấy giá trị của cùng byte trước khi con trỏ FIFO cập nhật. Sau đó FIFO có thể chuyển sang byte kế tiếp mà không ảnh hưởng parity của khung đang phát.

Cách tương đương là chốt `tx_data_masked` thành thanh ghi dữ liệu của khung và tính parity từ thanh ghi đó. Không tính parity từ PISO đang dịch vì nội dung PISO thay đổi trong lúc phát.

Đã chạy lại toàn bộ `tb_apb_uart` sau khi áp dụng sửa thật, bao gồm các trường hợp nhiều byte liên tiếp, FIFO đầy, full-duplex và các cấu hình parity. Dữ liệu và parity phải luôn thuộc cùng byte được chốt tại `load_reg`.
