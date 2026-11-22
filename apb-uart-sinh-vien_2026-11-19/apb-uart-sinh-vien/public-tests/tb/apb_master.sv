// apb_master — class ApbMaster: tạo giao dịch APB4 qua clocking block của apb_if (spec 5.1, 5.2; testplan 3.8).
// Mỗi giao dịch gồm pha setup (psel = 1, penable = 0) dài setup_cycles chu kỳ và một pha truy cập (penable = 1);
// pslverr, pready, prdata được lấy mẫu ở sườn kết thúc pha truy cập. Mọi task dùng chung một semaphore để nhiều
// luồng của test (song công) không tranh bus.
`timescale 1ns/1ps
package apb_master_pkg;
  import tb_pkg::*;

  class ApbMaster;
    virtual apb_if vif;
    int idle_mode     = 0;   // 0: không idle giữa hai giao dịch; 1: một chu kỳ; 2: ngẫu nhiên 0–5 chu kỳ
    int setup_cycles  = 1;   // số chu kỳ psel = 1, penable = 0 trước pha truy cập (≥ 1)
    int penable_extra = 0;   // số chu kỳ giữ psel = penable = 1 sau pha truy cập (vi phạm của master, test A.05)
    int n_extra_err   = 0;   // số chu kỳ thừa có pslverr = 1 (ghi nhận)
    int n_xfer        = 0;
    bit check_en      = 1'b1; // 0: không đếm kiểm tra pready, pslverr, prdata (giao dịch chỉ ghi nhận)
    realtime t_setup  = 0.0; // sườn bắt đầu pha setup của giao dịch gần nhất
    realtime t_access = 0.0; // sườn kết thúc pha truy cập của giao dịch gần nhất
    semaphore lock;

    function new(virtual apb_if vif);
      this.vif = vif;
      lock = new(1);
    endfunction

    // Đứng đúng ở sườn lên pclk trước khi lái pha setup
    task sync();
      if (!vif.at_edge()) @(vif.cb);
    endtask

    task idle(int n);
      lock.get();
      repeat (n) @(vif.cb);
      lock.put();
    endtask

    local task do_idle();
      case (idle_mode)
        1: repeat (1) @(vif.cb);
        2: repeat ($urandom_range(0, 5)) @(vif.cb);
        default: ;
      endcase
    endtask

    task xfer(input bit write, input logic [11:0] addr, input logic [31:0] wdata, input logic [3:0] strb,
              input bit exp_err, output logic [31:0] rdata, output bit err);
      string dir = write ? "ghi" : "đọc";
      lock.get();
      do_idle();
      sync();
      t_setup = $realtime;
      vif.cb.psel    <= 1'b1;
      vif.cb.penable <= 1'b0;
      vif.cb.pwrite  <= write;
      vif.cb.paddr   <= addr;
      vif.cb.pwdata  <= wdata;
      vif.cb.pstrb   <= strb;
      repeat (setup_cycles) @(vif.cb);
      vif.cb.penable <= 1'b1;
      @(vif.cb);
      t_access = $realtime;
      rdata = vif.cb.prdata;
      err   = vif.cb.pslverr;
      n_xfer++;
      if (check_en) begin
        check(vif.cb.pready === 1'b1, $sformatf("pready = %b ở chu kỳ truy cập (%s 0x%03h)", vif.cb.pready, dir, addr));
        check(err === exp_err, $sformatf("pslverr = %b, kỳ vọng %b (%s 0x%03h strb=%b data=0x%08h)",
                                         err, exp_err, dir, addr, strb, wdata));
        if (!write && !exp_err) check(!$isunknown(rdata), $sformatf("prdata có X khi đọc 0x%03h", addr));
      end
      repeat (penable_extra) begin
        @(vif.cb);
        if (vif.cb.pslverr === 1'b1) n_extra_err++;
      end
      vif.cb.psel    <= 1'b0;
      vif.cb.penable <= 1'b0;
      lock.put();
    endtask

    task write(input logic [11:0] addr, input logic [31:0] data, input logic [3:0] strb = 4'hF, input bit exp_err = 1'b0);
      logic [31:0] d;
      bit e;
      xfer(1'b1, addr, data, strb, exp_err, d, e);
    endtask

    task read(input logic [11:0] addr, output logic [31:0] data, input bit exp_err = 1'b0, input logic [3:0] strb = 4'h0);
      bit e;
      xfer(1'b0, addr, 32'h0, strb, exp_err, data, e);
    endtask

    // Reset không đồng bộ: giữ presetn = 0 trong cycles chu kỳ, thả ở sườn xuống pclk
    task reset(int cycles = 3);
      lock.get();
      vif.presetn    = 1'b0;
      vif.cb.psel    <= 1'b0;
      vif.cb.penable <= 1'b0;
      repeat (cycles) @(vif.cb);
      @(negedge vif.pclk);
      vif.presetn = 1'b1;
      lock.put();
    endtask

    task assert_reset();
      vif.presetn = 1'b0;
    endtask

    task release_reset();
      @(negedge vif.pclk);
      vif.presetn = 1'b1;
    endtask
  endclass

endpackage
