# Khung testbench SystemVerilog cho `apb_uart` — bộ công khai (ET4030, đồ án APB-UART)

Khung testbench kiểm chứng khối `apb_uart` theo đặc tả `02-SPEC-APB-UART-DDAS.md` bản 1.2 qua cổng của khối (SystemVerilog IEEE 1800-2017, không UVM). Gói gồm khung (12 tệp), 20 test P dạng mã nguồn, 108 test H của bộ chấm phần A dạng mã hoá (`hidden-enc/`), module `apb_uart` rỗng để tự kiểm khung, và `Makefile`. Khi chấm, ban tổ chức chạy cùng bộ test H với seed riêng.

## Mục lục
1. Cấu trúc tệp
2. Chạy bằng Questa
2a. Bộ 108 test H mã hoá, độ phủ
3. Định dạng kết quả và mã thoát
4. Assertion trong `tb_checker`
5. Viết thêm test
6. Quy ước

## 1. Cấu trúc tệp

```text
public-tests/
  Makefile                 sim TEST=<mã> [SEED=n] [RTL="..."] [COV=1] [FILES_F=...]; regress SUITE=public|hidden|all [SEEDS="1 7 2026"]; cov
  files.f                  danh sách tệp SV theo thứ tự biên dịch (không chứa RTL), dùng tb/tests_pkg.sv (20 test P)
  files_hidden.f           như files.f nhưng dùng hidden-enc/tests_pkg.svp (20 test P và 108 test H)
  hidden-enc/tests_pkg.svp gói tests_pkg mã hoá IEEE 1735 (khoá Siemens), Questa giải mã khi biên dịch
  suites/public.txt        20 mã test P
  suites/hidden.txt        108 mã test H
  suites/all.txt           128 mã P và H
  tb/
    tb_pkg.sv              hằng địa chỉ thanh ghi, bit STAT, mặt nạ rfu, kiểu frame_cfg_t (trùng CFG[6:0]), bảng BAUD 10 tốc độ,
                           check()/check_eq()/report(), watchdog
    apb_if.sv              interface APB4 với clocking block cb (sườn lên pclk) và presetn
    uart_if.sv             interface rx, cts_n, tx, rts_n, irq (không clocking vì không đồng bộ với pclk)
    apb_master.sv          class ApbMaster: write/read/idle; tuỳ chọn idle_mode, setup_cycles, penable_extra; kiểm pready, pslverr
    reg_model.sv           class RegModel: bản sao TXDATA, CFG, BAUD, IER; dự đoán pslverr E1–E5 từ STAT quan sát được
    uart_ext_tx.sv         class UartExtTx: bên ngoài phát khung vào rx theo thời gian thực, lệch tốc độ δ, tiêm lỗi parity/stop
    uart_ext_rx.sv         class UartExtRx: theo dõi tx liên tục, giải mã khung, đo độ rộng bit trung bình
    scoreboard.sv          class Scoreboard: hàng đợi khung kỳ vọng phía RX, đối chiếu RXDATA và STAT
    coverage.sv            class Coverage: covergroup dạng khung × tốc độ, mã lỗi, nguồn irq, cấu hình × δ
    checker.sv             module tb_checker: 9 assertion cấp cổng (mục 4)
    tests_pkg.sv           tiện ích dùng chung cho test, `include các thân test, bảng mã → task, run()
    tb_top.sv              clock 25 MHz (chu kỳ 40 ns), DUT apb_uart nối theo tên cổng, hai interface, tb_checker
    tests/h_lib.sv         tiện ích cho họ test theo tốc độ, chùm khung, đo thời điểm tx_done/rx_done, song công
    tests/t_p1_1.sv …      20 thân test P (một task mỗi tệp; đầu tệp ghi mục spec, nội dung kiểm, tiêu chí đạt)
    stub/apb_uart.v        module apb_uart rỗng (mọi đầu ra 0) để tự kiểm khung: mọi test P phải FAIL trên stub
```

RTL của đội không nằm trong `files.f`; biến `RTL` của `Makefile` mặc định trỏ tới `../../../rtl/*.v` trong workspace hiện tại và có thể ghi đè bằng `RTL=".../*.v"`. `tb_top` nối DUT theo tên đúng 16 cổng của spec mục 2 và đặt `CLK_FREQ=25_000_000`, khớp clock 25 MHz cùng bảng BAUD của bộ test. `apb_uart` của đội được phép có thêm cổng ra (spec 1.2 mục 2); các cổng đó để hở và Questa không báo cảnh báo vì `Makefile` tắt vopt-2685, vopt-2718.

## 2. Chạy bằng Questa

```bash
source ~/tools/env.sh                                   # Questa Sim-64 2025.1_2 trong PATH (đường dẫn theo máy)
cd public-tests
make sim TEST=P1.1                                      # RTL mặc định: ../../../rtl/*.v; kết quả ở run_P1.1_1/sim.log
make sim TEST=P3.1 SEED=7 RTL="$(ls ../my_rtl/*.v)"     # RTL ở thư mục khác, seed 7
make regress SUITE=public SEEDS="1 7 2026"              # 20 test × 3 seed → run_regress_<thời gian>_public/summary.csv
make sim TEST=P1.1 RTL=tb/stub/apb_uart.v               # tự kiểm khung: phải FAIL
```

Lệnh Questa tương đương, chạy từ `public-tests/`:

```bash
vlog -sv -mfcu -lint -quiet -work run/work -f files.f <rtl>.v
cd run && LC_ALL=C vsim -c -quiet -lib work tb_top +TEST=P1.1 +SEED=1 \
  -do "onfinish stop; run -all; quit -code [exec cat sim.status]"
```

`+TEST=<mã>` chọn test; `+SEED=<n>` đặt seed cho `$urandom` và `randomize()` (mặc định 1); dòng đầu của log in `SEED <n> TEST <mã>`. `LC_ALL=C` giữ chữ có dấu trong transcript.

## 2a. Bộ 108 test H mã hoá, độ phủ

```bash
make regress SUITE=hidden FILES_F=files_hidden.f              # 108 test H, seed 1
make regress SUITE=all    FILES_F=files_hidden.f SEEDS="1 7"   # 128 test × 2 seed
make sim TEST=H3.07 FILES_F=files_hidden.f                     # một test
make regress SUITE=hidden FILES_F=files_hidden.f RTL=tb/stub/apb_uart.v   # tự kiểm gói: mọi test FAIL
make regress SUITE=public COV=1                                # ghi cov.ucdb cho từng test
make cov                                                       # statement, branch, FSM state theo module RTL; chi tiết ở cov.txt
```

Gói mã hoá đã chạy thử ngày 19/11/2026 trên Questa Sim-64 2025.1_2, seed 1: RTL tham chiếu đạt 128/128 (281 s), module rỗng đạt 0/108, một bản RTL cài lỗi đảo parity chẵn và lẻ đạt 50/108. Phiên bản Questa khác chưa kiểm. Dòng `ERR` của test H in mục đặc tả và nội dung kiểm; mã nguồn test không đọc được.

## 3. Định dạng kết quả và mã thoát

Mỗi lần chạy in đúng một dòng kết thúc:

```text
PASS P1.1 checks=49 errors=0
FAIL P1.1 checks=49 errors=36
```

`checks` là số phép kiểm đã thực hiện, `errors` là số phép kiểm sai cộng số lần assertion vi phạm. Khi FAIL, `report()` gọi `$fatal(1)`; vì `vsim -c` trả mã 0 sau `$fatal`, `report()` ghi thêm tệp `sim.status` (0 PASS, 1 FAIL, 2 chưa kết thúc) và do-script kết thúc bằng `quit -code [exec cat sim.status]`, nên `vsim` và `make sim` trả khác 0 khi FAIL. Mã test không tồn tại cho `FAIL <mã> checks=0 errors=1`. Mỗi test có watchdog theo tốc độ baud; test quá hạn in `ERR watchdog` và FAIL.

Dòng `<thời gian> ERR <nội dung>` ghi từng phép kiểm sai kèm giá trị đọc và kỳ vọng; dòng `INFO` ghi số đo chỉ để tham khảo. Assertion vi phạm in tối đa 5 dòng mỗi tên và tổng số ở cuối (`INFO SVA <tên>: <n> vi phạm`).

## 4. Assertion trong `tb_checker`

`tb_checker` nối với cổng của DUT trong `tb_top`, đánh giá ở sườn lên `pclk`, `disable iff (!presetn)` trừ hai assertion cần kiểm cả trong reset. Vi phạm được cộng vào `errors`.

| Tên | Thuộc tính | Phía | Ý nghĩa |
|---|---|---|---|
| `ap_pready_const` | `pready == 1` mọi chu kỳ, kể cả trong reset | completer (DUT) | spec 2, 5.1 |
| `ap_pslverr_only_access` | `pslverr → psel && penable` | completer | spec 5.2 |
| `ap_pslverr_zero_in_reset` | `!presetn → !pslverr` | completer | spec 2 |
| `ap_prdata_known` | `psel && penable → prdata` không có X | completer | spec 5.1 |
| `ap_reset_outputs` | sườn lên `presetn` → `tx = 1`, `rts_n = 1`, `irq = 0` | completer | spec 2 |
| `ap_rts_eq` | ở chu kỳ truy cập đọc STAT: `rts_n == STAT.rx_dis \|\| STAT.rx_done`; bỏ 2 chu kỳ sau lệnh ghi soft_rst | completer | spec 6.4, 6.5 |
| `ap_penable_after_psel` | `penable → psel && $past(psel)` | master (testbench) | pha truy cập luôn đứng sau pha setup |
| `ap_stable_in_access` | `psel && !penable ⇒ paddr, pwrite, pwdata, pstrb` giữ nguyên ở chu kỳ sau | master | tín hiệu ổn định suốt giao dịch |
| `ap_psel_hold` | `psel && !penable ⇒ psel` | master | psel không rơi giữa giao dịch |

Ba assertion phía master kiểm chính testbench: khi đội sửa `ApbMaster` hoặc viết tác nhân khác, vi phạm ở đây là lỗi của testbench, không phải của RTL.

## 5. Viết thêm test

1. Tạo `tb/tests/t_<mã>.sv` chứa một `task automatic t_<mã>();` với đầu tệp ghi mục spec, nội dung kiểm, tiêu chí đạt. Thân test dùng các tiện ích của `tests_pkg`: `tb_start()`, `wr()`, `rd()`, `rd_chk()`, `rd_stat()`, `uart_setup()`, `tx_char()`, `tx_and_check()`, `rx_and_check()`, `wait_stat()`, `wait_tx_done()`, `wait_rx_done()`, `get_frame()`, `check_frame()`, `soft_reset()`; các handle `apb`, `rm`, `utx`, `urx`, `sb`, `cov`, `vapb`, `vuart`.
2. Thêm `` `include "tests/t_<mã>.sv" `` vào `tests_pkg.sv` (trước `run_test`) và một dòng `"<mã>": t_<mã>();` vào `case` trong `run_test`.
3. Gọi `set_watchdog(<ns>)` ở đầu test theo tốc độ baud và số khung.
4. Mọi phép kiểm dùng `check(cond, msg)` hoặc `check_eq(got, exp, msg)` để được đếm vào `checks`/`errors`; thông tin tham khảo dùng `info(msg)`.
5. Thêm mã test vào `suites/<tên>.txt` để `make regress SUITE=<tên>` chạy.

Ví dụ đọc thanh ghi và kiểm:

```systemverilog
task automatic t_x1();
  logic [31:0] s;
  set_watchdog(1_000_000.0);
  tb_start();
  uart_setup(mk_cfg(8), BAUD_I115200);
  tx_and_check(8'h5A, mk_cfg(8), bit_ns(115200), "X1 khung 0x5A");
  rd_stat(s);
  check(s[ST_TX_DONE] === 1'b1, "tx_done = 1 sau khung");
endtask
```

## 6. Quy ước

- Testbench chỉ truy cập DUT qua cổng: không dùng tên phân cấp vào DUT (`dut.`, `tb_top.dut.`), không `bind` vào trong DUT; `grep -E "dut\.|tb_top\.dut" tb/` phải rỗng.
- `timescale 1ns/1ps`; `default_nettype none` trong module; mô hình UART bên ngoài dùng thời gian thực ns, không đồng bộ với `pclk`.
- Giao dịch APB: `ApbMaster` lái pha setup ở sườn lên `pclk`, pha truy cập ở sườn kế tiếp; `pslverr`, `pready`, `prdata` lấy mẫu ở sườn kết thúc pha truy cập; `idle_mode` 0/1/2 chọn số chu kỳ idle giữa hai giao dịch (0, 1, ngẫu nhiên 0–5).
- Bộ tham số kỹ thuật dùng trong test: `BAUD_REG[]` theo bảng spec 4.3; dung sai độ rộng bit ±1,0 % cộng sai số lượng tử hoá `T_pclk/(k·bit)`; `tx_done`, `rx_done` đo qua đọc STAT liên tục (phân giải 2 chu kỳ).
