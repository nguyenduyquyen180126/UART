# public-tests/Makefile — chạy khung testbench công khai của đồ án APB-UART bằng Questa (rút gọn từ ref/dv/Makefile của lời giải tham chiếu).
#   make sim TEST=P1.1 [SEED=1] [RTL="..."] [COV=1]       một test, cwd = thư mục này; log ở run_<TEST>_<SEED>/{vlog.log,sim.log,sim.status}
#   make regress [SUITE=public] [SEED=1 | SEEDS="1 7 2026"] [RTL="..."] [STOP_ON_FAIL=1]
#                                                          chạy tuần tự suites/$(SUITE).txt → run_regress_<YYYYMMDD_HHMMSS>_<SUITE>/summary.csv
#   make regress RTL=tb/stub/apb_uart.v                    tự kiểm khung: mọi test P phải FAIL trên module rỗng
#   make clean
# RTL: mặc định mọi tệp ../../../rtl/*.v trong workspace hiện tại (hoặc truyền RTL="đường/dẫn/*.v").
# files.f liệt kê tệp SV của khung (đường dẫn tương đối so với thư mục này), không chứa RTL.
# Mã thoát: sim trả khác 0 khi vlog có ** Warning/** Error, vsim trả khác 0 (sim.status do tb_pkg::report ghi: 0 PASS, 1 FAIL, 2 chưa kết thúc),
#   sim.log thiếu dòng "PASS <TEST>", hoặc có ** Error/** Fatal/FAIL. Dòng kết quả: "PASS <mã> checks=<n> errors=0" hoặc "FAIL <mã> checks=<n> errors=<m>".
SHELL    := /bin/bash
RTL      ?= $(wildcard ../../../rtl/*.v)
TEST     ?= P1.1
SEED     ?= 1
COV      ?=
STOP_ON_FAIL ?=
SUITE    ?= public
FILES_F  ?= $(if $(filter hidden all,$(SUITE)),files_hidden.f,files.f)
TOP      ?= tb_top
RUNTAG   ?=
RUN       = run_$(TEST)_$(SEED)$(RUNTAG)
VLOG_COV  = $(if $(COV),+cover=sbfec)
VSIM_COV  = $(if $(COV),-coverage)
# vopt-2685, vopt-2718 (TFMPC): apb_uart được phép có cổng ra ngoài 16 cổng của bảng (đặc tả 1.2 mục 2),
# tb_top chỉ nối 16 cổng; hai cảnh báo này không phải lỗi của RTL nên bị tắt.
VSIM_SUPP = -suppress 2685,2718
DO_COV    = $(if $(COV),coverage save cov.ucdb;)

.PHONY: sim regress cov clean

sim:
	@command -v vsim >/dev/null || { echo "thiếu Questa (vsim) trong PATH"; exit 2; }
	@test -n "$(RTL)" || { echo "thiếu RTL: đặt ../../../rtl/*.v hoặc truyền RTL=\"...\""; exit 2; }
	@for f in $(RTL); do test -f $$f || { echo "thiếu tệp RTL $$f"; exit 2; }; done
	rm -rf $(RUN) && mkdir -p $(RUN) && vlib $(RUN)/work > /dev/null && echo 2 > $(RUN)/sim.status
	LC_ALL=C vlog -sv -mfcu -lint -quiet -work $(RUN)/work $(VLOG_COV) -f $(FILES_F) $(RTL) > $(RUN)/vlog.log 2>&1; rc=$$?; \
	  if [ $$rc -ne 0 ] || grep -qE "^\*\* (Warning|Error)" $(RUN)/vlog.log; then \
	    grep -E "^\*\* (Warning|Error)" $(RUN)/vlog.log | head -20; echo "FAIL $(TEST) seed=$(SEED) run=$(RUN) (vlog rc=$$rc, xem $(RUN)/vlog.log)"; exit 1; fi
	cd $(RUN) && LC_ALL=C vsim -c -quiet $(VSIM_SUPP) -lib work $(TOP) +TEST=$(TEST) +SEED=$(SEED) $(VSIM_COV) -l transcript -wlf vsim.wlf \
	  -do "onfinish stop; run -all; $(DO_COV) quit -code [exec cat sim.status]" > sim.log 2>&1; echo $$? > vsim.rc
	@grep -E "^# (PASS|FAIL) |^# \*\* (Error|Fatal)" $(RUN)/sim.log | head -20 | sed 's/^# //'
	@[ "$$(cat $(RUN)/vsim.rc)" = 0 ] && grep -qE "^# PASS $(TEST)( |$$)" $(RUN)/sim.log && ! grep -qE "^# (\*\* (Error|Fatal)|FAIL)" $(RUN)/sim.log \
	  && echo "PASS $(TEST) seed=$(SEED) run=$(RUN)" \
	  || { echo "FAIL $(TEST) seed=$(SEED) run=$(RUN) (vsim rc=$$(cat $(RUN)/vsim.rc), sim.status=$$(cat $(RUN)/sim.status), xem $(RUN)/sim.log)"; exit 1; }

ifndef REGRESS_DIR
REGRESS_DIR := run_regress_$(shell date +%Y%m%d_%H%M%S)_$(SUITE)
endif
SEEDS ?= $(SEED)
SUITE_FILE ?= suites/$(SUITE).txt

regress:
	@test -f $(SUITE_FILE) || { echo "thiếu $(SUITE_FILE)"; exit 2; }
	@mkdir -p $(REGRESS_DIR)
	@echo "test,seed,checks,errors,result,seconds" > $(REGRESS_DIR)/summary.csv
	@npass=0; nfail=0; t0=$$(date +%s); \
	for s in $(SEEDS); do \
	  for t in $$(grep -vE '^\s*(#|$$)' $(SUITE_FILE) | awk '{print $$1}'); do \
	    run=run_$${t}_$${s}$(RUNTAG); ts=$$(date +%s); \
	    $(MAKE) --no-print-directory sim TEST=$$t SEED=$$s RTL="$(RTL)" RUNTAG=$(RUNTAG) FILES_F="$(FILES_F)" $(if $(COV),COV=1) > $(REGRESS_DIR)/$$t.$$s.out 2>&1; rc=$$?; \
	    sec=$$(( $$(date +%s) - ts )); \
	    ce=$$(sed -nE 's/^# (PASS|FAIL) [^ ]+ checks=([0-9]+) errors=([0-9]+).*/\2,\3/p' $$run/sim.log 2>/dev/null | tail -1); \
	    [ -n "$$ce" ] || ce=","; \
	    if [ $$rc -eq 0 ]; then res=PASS; npass=$$((npass+1)); else res=FAIL; nfail=$$((nfail+1)); fi; \
	    echo "$$t,$$s,$$ce,$$res,$$sec" >> $(REGRESS_DIR)/summary.csv; \
	    printf "%-8s seed=%-5s %-4s %4ss  %s\n" $$t $$s $$res $$sec $$run/sim.log; \
	    if [ $$res = FAIL ] && [ -n "$(STOP_ON_FAIL)" ]; then break 2; fi; \
	  done; \
	done; \
	echo "regress SUITE=$(SUITE) SEEDS=\"$(SEEDS)\": PASS=$$npass FAIL=$$nfail tổng $$(( $$(date +%s) - t0 ))s → $(REGRESS_DIR)/summary.csv"; \
	[ $$nfail -eq 0 ]

# Độ phủ mã của RTL (phần D1): chạy sim/regress với COV=1 trước, rồi make cov.
#   Gộp mọi run_*/cov.ucdb → merged.ucdb; in statement, branch, FSM state theo từng module RTL (bỏ module, package, interface của khung tb).
#   Chi tiết từng dòng chưa phủ: cov.txt.
TB_DUS = tb_top tb_checker apb_if uart_if tb_pkg apb_master_pkg reg_model_pkg uart_ext_tx_pkg uart_ext_rx_pkg scoreboard_pkg coverage_pkg tests_pkg
cov:
	@ls run_*/cov.ucdb >/dev/null 2>&1 || { echo "chưa có run_*/cov.ucdb: chạy make sim hoặc make regress với COV=1"; exit 2; }
	vcover merge merged.ucdb run_*/cov.ucdb > /dev/null
	vcover report -details -codeAll merged.ucdb > cov.txt
	vcover report -summary -code bfs -du='*' merged.ucdb > cov_summary.txt
	@printf "%-24s %10s %10s %10s\n" module statement branch fsm_state
	@awk -v skip="$(TB_DUS)" 'BEGIN{n=split(skip,a," "); for(i=1;i<=n;i++) no[a[i]]=1} \
	     /^=== Design Unit: /{m=$$NF; sub(/^[^.]*\./,"",m); p=!(m in no)} \
	     p && /^ *Statements /{st[m]=$$NF} p && /^ *Branches /{br[m]=$$NF} p && /^ *FSM States /{fs[m]=$$NF} \
	     END{for (k in st) printf "%-24s %10s %10s %10s\n", k, st[k], br[k], (k in fs)?fs[k]:"-"}' cov_summary.txt | sort

clean:
	rm -rf run_* transcript vsim.wlf work merged.ucdb cov.txt cov_summary.txt
