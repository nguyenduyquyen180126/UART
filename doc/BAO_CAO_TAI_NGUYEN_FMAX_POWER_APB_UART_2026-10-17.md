# Tài nguyên, timing và công suất riêng APB UART — 17/10/2026

## Phạm vi và điều kiện

Đã chạy Quartus Prime Lite **24.1std.0 Build 1077**, Analysis & Synthesis,
Fitter, TimeQuest và Power Analyzer bằng công cụ dòng lệnh của Quartus.
Đích là **Cyclone IV E EP4CE115F29C7**, cùng FPGA trên DE2-115.
`apb_uart`, `CLK_FREQ=50_000_000`, clock 50 MHz / 20 ns; giữ cả hai FIFO sâu 16,
đủ APB, TX, RX, cấu hình và IRQ. Không sửa RTL, Qsys, CPU, chân hoặc nạp lại kit.

Có hai phạm vi độc lập:

1. **Trong SoC hiện có:** đọc Fitter theo đúng hierarchy
   `NIOS|system:u0|apb_uart:apb_uart_0`; chạy lại TimeQuest chỉ lấy register thuộc
   `*|apb_uart:apb_uart_0|*`. Không lấy CPU, RAM hệ thống, JTAG, PIO hay APB adapter.
2. **Project độc lập:** top-level `apb_uart`, build mới trong `build/uart_metrics`,
   seed 1. APB và các cổng dữ liệu dùng virtual pin, chỉ clock ở Y2;
   không biến bus APB nội bộ thành hàng chục pad vật lý của FPGA.

Nguồn SoC generated và nguồn RTL hiện tại giống nhau về token Verilog.
`rtl/rx_uart.v` khác bản generated ở newline/comment cuối file; kiểm tra byte-for-byte
`check_soc.py` sẽ báo khác vì comment đó, nhưng không có khác biệt logic UART.
Không xóa comment người dùng để làm phép kiểm tra byte-for-byte thành PASS.

## Tài nguyên sau Fitter

| Chỉ số | Riêng UART trong SoC | UART build độc lập |
|---|---:|---:|
| Logic Cells / LEs theo Fitter | **340** | **349** |
| LC sử dụng LUT | **318** | **334** |
| Dedicated logic registers | **176** | **168** |
| LUT-only LCs | 151 | 181 |
| Register-only LCs | 22 | 15 |
| LUT/Register LCs | 167 | 153 |
| Memory bits dữ liệu | **272** | **272** |
| M9K | **2** | **2** |
| DSP | **0** | **0** |

Nguồn: bảng **Fitter Resource Utilization by Entity**; lấy số ngoài ngoặc,
bao gồm các module con. LC dùng LUT = LUT-only + LUT/Register. Không cộng LUT,
register và LE với nhau thành “tổng tài nguyên”; LUT và FF có thể chia sẻ LC.
Các trường thống kê được giữ theo định nghĩa của Quartus.

- 340 LEs tương đương khoảng **0,297%** trong 114.480 LEs của chip.
- TX FIFO: 16 × 8 = 128 bit, một M9K; RX FIFO: 16 × 9 = 144 bit, một M9K.
- 272 bit là dung lượng dữ liệu logic. Hai M9K chiếm **18.432 bit dung lượng
  block RAM vật lý**; không ghi nhầm UART chỉ chiếm 272 bit RAM vật lý.
- Chênh lệch hai project do tối ưu, packing và placement trong ngữ cảnh khác nhau.
  Khi báo tài nguyên của SoC hiện tại, dùng cột **340 / 318 / 176 / 2 M9K**.

## Timing và Fmax

### Đường nội bộ UART trong SoC

Chỉ xét đường **register → register nằm hoàn toàn trong instance UART**, không
lấy đường UART → CPU hoặc adapter → UART làm Fmax riêng của IP.

| Corner | Setup slack tại 50 MHz | Fmax tương đương từ setup |
|---|---:|---:|
| Slow, 1,2 V, 85°C | **+10,514 ns** | **105,42 MHz** |
| Slow, 1,2 V, 0°C | +11,424 ns | 116,60 MHz |
| Fast, 1,2 V, 0°C | +15,375 ns | 216,22 MHz |

Công thức với quan hệ clock đơn chu kỳ 20 ns:
`Fmax tương đương = 1000 / (20 − setup_slack_ns)` MHz.
Đây là suy ra từ đường setup đã fit ở clock 50 MHz, **không phải một lượt re-fit
và kiểm chứng vận hành UART ở 105,42 MHz**. PLL/board clock vẫn là 50 MHz.

Đường chậm nhất ở corner Slow 85°C:
`u_uart_regs|cfg_reg[5] → u_tx_uart|u_baud_gen|cnt[...]`.
Hold slack nội bộ nhỏ nhất trong ba corner: **+0,148 ns**.
Các đường setup/hold nội bộ được báo cáo không vi phạm.
Reset và RX bất đồng bộ được false-path theo SDC gốc; đây không phải chứng nhận
CDC/metastability hoặc recovery/removal của tín hiệu reset bất đồng bộ.

### Project UART độc lập

- **Fmax Summary của Quartus: 77,54 MHz**, corner Slow 1,2 V 85°C.
- Đường register → register riêng: setup slack **+8,929 ns**, tương đương
  **90,33 MHz** ở cùng corner.
- Toàn bộ đường được ràng buộc trong project: setup nhỏ nhất **+7,104 ns**;
  hold nhỏ nhất qua các corner **+0,139 ns**; unconstrained setup/hold ports = 0.

77,54 MHz có xét các đường interface trong project và ngân sách input/output
2 ns được khai báo cho phép đo; nó khác Fmax chỉ lấy đường register → register.
Ngân sách 2 ns là điều kiện benchmark, không phải thông số timing của kit.
Clock reset/RX và TX bất đồng bộ có false-path được khai báo rõ trong SDC.
Không gộp số 77,54 MHz với tài nguyên của project SoC như thể cùng một lần fit.

Fmax `CLOCK_50 = 68,54 MHz` trong report SoC là **toàn SoC**, không dùng làm
Fmax riêng UART. Không đổi clock phần cứng theo các con số Fmax này:
baud generator vẫn được cấu hình cho đầu vào 50 MHz.

## Công suất: kết quả ước tính, không phải đo điện trên kit

Chạy Power Analyzer trên netlist **UART độc lập sau Fitter**. Điều kiện:
1,2 V core, đặc tính silicon Typical, junction **25°C cố định**, clock **50 MHz**,
UART **19200 8N1**, IER RX/TX/overrun bật. Không giả định nhiệt độ thực của kit.

- Idle: 5 ms, không truy cập APB, không TX/RX; clock vẫn chạy.
- Active: 32 byte TX và 32 byte RX qua loopback, dữ liệu biến đổi
  `(index × 73 + 0x55) & 0xff`; APB đọc trạng thái mỗi khoảng 10 µs, chèn ghi TX
  và đọc RX khi cần. Test kiểm tra đúng từng byte và không overrun/error.
- Thực hiện cả mô phỏng RTL và mô phỏng functional của netlist sau Fitter.
  VCD netlist không back-annotate SDF; không khẳng định đã mô phỏng đầy đủ glitch
  có trễ đường dây. Power Analyzer vẫn dùng dữ liệu placement/routing đã fit.

| Kết quả Power Analyzer | Idle | TX/RX active |
|---|---:|---:|
| **Core Dynamic — dùng làm ước tính động của project UART độc lập** | **3,61 mW** | **3,68 mW** |
| Core Static — của toàn FPGA, không riêng UART | 98,10 mW | 98,10 mW |
| I/O — summary toàn thiết bị trong project benchmark | 40,71 mW | 40,71 mW |
| Total Thermal — toàn thiết bị trong project benchmark | 142,42 mW | 142,49 mW |
| Confidence do Quartus đánh giá | **Medium** | **Medium** |

Trong cả hai workload gate-level, **583/625 tín hiệu (93,3%)** nhận toggle rate
trực tiếp từ mô phỏng; registered nodes **133/168 (79,2%)**, combinational nodes
**449/451 (99,6%)**. Quartus báo unknown time **0,0%**; phần còn lại dùng
vectorless/default. Vì vậy không gọi kết quả là High confidence hoặc đo chính
xác tuyệt đối. Dữ liệu chưa bao phủ mọi cấu hình UART và mọi workload APB.

Đối chứng bằng VCD RTL cho kết quả core dynamic idle **3,74 mW**, active
**3,97 mW**, confidence **Low**. Kết quả được ưu tiên là VCD netlist sau Fitter
với coverage cao hơn và confidence Medium; không lấy riêng một con số thuận lợi
rồi bỏ thông tin confidence.

Chênh active/idle chỉ khoảng **0,07 mW** trong workload này. Clock và RAM vẫn
được cấp clock khi idle, nên không được suy rằng UART idle tiêu thụ 0 mW.
Không dùng chênh lệch đã làm tròn này để suy ra năng lượng chính xác mỗi byte.

Không gọi `Total Thermal Power Dissipation` của project độc lập là “công suất
riêng UART”: giá trị này còn chứa static của **cả chip FPGA**, I/O và tài nguyên
hạ tầng. Virtual pin giúp tránh tạo pad giả cho APB, nhưng summary vẫn có phần
I/O/unused device contribution. Kết quả core dynamic cũng thuộc cách bố trí và
phân phối clock trong project độc lập; không khẳng định bằng chính xác phần
công suất tăng thêm khi gắn UART vào SoC đã có clock chung.

Đơn vị mW là **công suất**. Năng lượng cho một khoảng chạy cụ thể cần tính
`E = P × thời gian`, kèm workload tương ứng; không có một số “năng lượng UART”
cố định cho mọi cấu hình, dữ liệu và thời gian hoạt động.

Theo [hướng dẫn Power Analysis của Intel/Altera](https://www.intel.com/programmable/technical-pdfs/683506.pdf),
node matching và độ phủ hoạt động ảnh hưởng đến độ tin cậy của power estimate.
Các số dưới đây được giữ nguyên mức confidence Quartus báo; không đổi thành
kết quả đo vật lý hoặc bảo đảm sai số phần trăm chưa được kiểm chứng.

## Tái lập và bằng chứng

```bash
cd /home/vietanh/Downloads/code/UART/UART
./scripts/measure_apb_uart.sh
```

Script chỉ tạo project đo và chạy công cụ; không program kit. Mô phỏng netlist
có VCD lớn, nên cần dung lượng đĩa và mất lâu hơn compile UART.
Project có thể mở trong GUI Quartus tại `build/uart_metrics/uart_metrics.qpf`.
Đây là project benchmark với virtual pins, **không dùng SOF của nó để nạp kit**.

- Project/simulation/Tcl: `scripts/uart_metrics/`.
- JSON số liệu và hash từng file RTL: `build/uart_metrics/results.json`.
- Báo cáo gốc: `build/uart_metrics/output_files/`, `power-*-25c.rpt`,
  `core_setup_*.rpt`, `core_hold_*.rpt`.
- Bản lưu kết quả: [doc/verification/apb_uart_metrics_2026-10-17](verification/apb_uart_metrics_2026-10-17/).

Compile độc lập thành công, **0 errors, 42 warnings**. Đã đọc các nhóm cảnh báo:
thu hẹp hằng số baud từ 32 xuống 15 bit, inferred RAM/pass-through, bit đọc thanh
ghi cố định 0, thiết lập số CPU, LogicLock không có subscription và yêu cầu I/O
clock 3,3 V. Với `CLK_FREQ=50 MHz`, giá trị baud lớn nhất 20.833 vừa trong 15 bit.
Không sửa RTL để làm đẹp số tài nguyên hoặc xóa cảnh báo trong lần đo này.

Đối chiếu trong GUI Quartus:

1. Mở `fpga/NIOS.qpf` → Compilation Report → Fitter → Resource Section →
   Resource Utilization by Entity; chọn đúng `apb_uart:apb_uart_0`.
2. Mở project benchmark → Compilation Report → TimeQuest Timing Analyzer →
   Slow 1200mV 85C Model → Fmax Summary để xem 77,54 MHz. Các báo cáo lọc
   đường nội bộ UART nằm riêng trong `core_setup_*.rpt`, không phải Fmax Summary
   của toàn SoC.
3. Trong project benchmark, Power Analyzer → Summary và Confidence Metric
   Details; đọc `Core Dynamic` cùng mức confidence, sau đó xem Simulation Files
   Read để xác nhận đã dùng VCD gate-level đúng workload.
