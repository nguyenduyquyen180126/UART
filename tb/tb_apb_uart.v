`timescale 1ns/1ps

// UART tham chieu hanh vi (simulation-only), tach module trong tb/models/.
// Chay tu thu muc UART:
//   iverilog -g2012 -s tb_apb_uart -o /tmp/tb_apb_uart tb/tb_apb_uart.v tb/models/*.v rtl/*.v
//   vvp /tmp/tb_apb_uart +NO_VCD
// Bo +NO_VCD de tao wave_apb_uart.vcd. [REF FAIL] bao sai khac voi model.
// Model chi dung bus APB va chan TX/RX, khong phu thuoc vi kien truc DUT.
module tb_apb_uart;

    // =========================================================================
    // 1. KHAI BÁO THAM SỐ VÀ TÍN HIỆU
    // =========================================================================
    parameter CLK_PERIOD = 20;         // 50 MHz clock -> chu kỳ 20ns
    parameter CLK_FREQ   = 50_000_000; // Tần số clock 50 MHz

    reg         clk;
    reg         rst_n;

    // Tín hiệu giao tiếp bus APB
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [11:0] paddr;
    reg  [31:0] pwdata;
    wire        pready;
    wire        pslverr;
    wire [31:0] prdata;

    // Tín hiệu UART nối tiếp
    wire        tx;
    wire        rx;
    reg         loopback_enable;
    reg         raw_rx_enable, raw_rx_level;
    reg         virtual_tx_start;
    reg [7:0]   virtual_tx_data;
    reg [4:0]   virtual_tx_cfg;
    reg         virtual_tx_inject;
    wire        virtual_tx_serial, virtual_tx_busy, virtual_tx_done;
    wire [7:0]  virtual_rx_data;
    wire        virtual_rx_done, virtual_rx_busy;
    wire        virtual_rx_start_error, virtual_rx_parity_error, virtual_rx_stop_error;
    // Biến quản lý testbench & thống kê
    integer     test_id;
    integer     pass_count;
    integer     fail_count;
    integer     timeout;
    integer     bit_time_ns;
    integer     i;

    reg  [31:0] read_val;
    reg         err_resp;

    // UART ao chi dung trong mo phong: khong instantiate lai RTL cua DUT.
    // Queue TX ghi nhan cac lenh APB duoc chap nhan; RX ghi nhan stimulus.
    reg [6:0] ref_cfg;
    reg [7:0] ref_tx_queue [0:4095];
    reg [8:0] ref_rx_queue [0:4095];
    integer ref_tx_wr, ref_tx_rd, ref_rx_wr, ref_rx_rd;
    integer ref_tx_checked, ref_rx_checked, ref_errors;
    integer cfg_bits, cfg_parity, cfg_stop, cfg_baud;
    reg [31:0] cfg_value;
    // Ket qua Compare giu lai cho Monitor/waveform, valid = virtual_rx_done.
    reg [7:0] tx_compare_expected, tx_compare_actual;
    reg tx_compare_pass;

    function integer reference_baud(input [1:0] selection);
        begin
            case (selection)
                0: reference_baud = 2400;
                1: reference_baud = 4800;
                2: reference_baud = 9600;
                3: reference_baud = 19200;
            endcase
        end
    endfunction

    function [7:0] reference_mask(input [7:0] value, input [1:0] width_cfg);
        begin
            reference_mask = value & (8'hFF >> (3 - width_cfg));
        end
    endfunction

    wire [31:0] virtual_baud = reference_baud(ref_cfg[6:5]);

    // Hai nhanh doc lap, dung so do stimulus -> DUT -> compare -> monitor.
    // DUT TX -> RX ao -> compare voi pwdata da duoc APB chap nhan.
    // TX ao -> DUT RX -> compare prdata voi byte stimulus.
    assign rx = raw_rx_enable ? raw_rx_level : (loopback_enable ? tx : virtual_tx_serial);
    uart_rx_virtual u_virtual_rx (
        .clk(clk), .rst_n(rst_n), .serial_in(tx),
        .cfg(ref_cfg[4:0]), .baud_rate(virtual_baud),
        .rx_data(virtual_rx_data), .rx_done(virtual_rx_done), .busy(virtual_rx_busy),
        .start_error(virtual_rx_start_error),
        .parity_error(virtual_rx_parity_error), .stop_error(virtual_rx_stop_error)
    );
    uart_tx_virtual u_virtual_tx (
        .clk(clk), .rst_n(rst_n), .start(virtual_tx_start),
        .tx_data(virtual_tx_data), .cfg(virtual_tx_cfg), .baud_rate(virtual_baud),
        .inject_parity_error(virtual_tx_inject), .serial_out(virtual_tx_serial),
        .busy(virtual_tx_busy), .tx_done(virtual_tx_done)
    );
    wire        irq;

    // FIFO RX mo hinh: byte den khi day bi bo, dung dung luong 16 byte.
    task reference_expect_rx(input [7:0] value, input error_bit);
        begin
            if (ref_rx_wr - ref_rx_rd < 16) begin
                if (ref_rx_wr >= 4096) $fatal(1, "Reference RX queue overflow");
                ref_rx_queue[ref_rx_wr] = {error_bit, value};
                ref_rx_wr = ref_rx_wr + 1;
            end
        end
    endtask

    // Quan sat bus tai canh chap nhan, truoc khi RX FIFO pop/NBA cap nhat.
    always @(posedge clk) begin
        if (rst_n && psel && penable && pready && !pslverr) begin
            if (pwrite && paddr == 12'h008)
                ref_cfg = pwdata[6:0];
            if (pwrite && paddr == 12'h000) begin
                if (ref_tx_wr >= 4096) $fatal(1, "Reference TX queue overflow");
                ref_tx_queue[ref_tx_wr] = reference_mask(pwdata[7:0], ref_cfg[1:0]);
                ref_tx_wr = ref_tx_wr + 1;
            end
            if (!pwrite && paddr == 12'h004) begin
                if (ref_rx_rd == ref_rx_wr) begin
                    $display("[REF FAIL] RX read without expected byte at %0t", $time);
                    ref_errors = ref_errors + 1;
                end else begin
                    if (prdata[8:0] !== ref_rx_queue[ref_rx_rd]) begin
                        $display("[REF FAIL] RX #%0d expected=%03h actual=%03h at %0t",
                                 ref_rx_rd, ref_rx_queue[ref_rx_rd], prdata[8:0], $time);
                        ref_errors = ref_errors + 1;
                    end
                    ref_rx_rd = ref_rx_rd + 1;
                    ref_rx_checked = ref_rx_checked + 1;
                end
            end
        end
    end

    // COMPARE + MONITOR: RX ao tra byte khi da lay mau stop cuoi.
    // Dung rx_done cua RX ao cho tung frame: STT.tx_done cua DUT chi bao
    // toan bo FIFO va bo phat da rong, khong phai xung hoan tat tung byte.
    always @(posedge virtual_rx_done) begin : compare_tx_and_monitor
        if (rst_n) begin
            tx_compare_actual = virtual_rx_data;
            tx_compare_expected = (ref_tx_rd < ref_tx_wr) ? ref_tx_queue[ref_tx_rd] : 8'hxx;
            tx_compare_pass = (ref_tx_rd < ref_tx_wr) &&
                              (virtual_rx_data === tx_compare_expected) &&
                              !virtual_rx_start_error && !virtual_rx_parity_error && !virtual_rx_stop_error;
            $display("[MONITOR TX] expected=%02h actual=%02h pass=%b at %0t",
                     tx_compare_expected, tx_compare_actual, tx_compare_pass, $time);
            if (virtual_rx_start_error || virtual_rx_parity_error || virtual_rx_stop_error) begin
                $display("[REF FAIL] TX frame data=%02h start_error=%b parity_error=%b stop_error=%b at %0t",
                         virtual_rx_data, virtual_rx_start_error,
                         virtual_rx_parity_error, virtual_rx_stop_error, $time);
                ref_errors = ref_errors + 1;
            end
            if (ref_tx_rd == ref_tx_wr) begin
                $display("[REF FAIL] Unexpected TX frame %02h", virtual_rx_data);
                ref_errors = ref_errors + 1;
            end else begin
                if (virtual_rx_data !== ref_tx_queue[ref_tx_rd]) begin
                    $display("[REF FAIL] TX #%0d expected=%02h actual=%02h",
                             ref_tx_rd, ref_tx_queue[ref_tx_rd], virtual_rx_data);
                    ref_errors = ref_errors + 1;
                end
                ref_tx_rd = ref_tx_rd + 1;
                ref_tx_checked = ref_tx_checked + 1;
            end
        end
    end

    // Watchdog doc lap: loi DUT khong duoc lam mo phong treo vo han.
    initial begin
        #1_000_000_000;
        $fatal(1, "Global UART testbench timeout");
    end

    // =========================================================================
    // 2. KHỞI TẠO DUT (apb_uart)
    // =========================================================================
    apb_uart #(
        .CLK_FREQ(CLK_FREQ)
    ) uart_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .pready  (pready),
        .pslverr (pslverr),
        .prdata  (prdata),
        .tx      (tx),
        .rx      (rx),
        .irq     (irq)
    );

    // =========================================================================
    // 3. TẠO CLOCK 50 MHz VÀ DUMP SÓNG VCD
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin
        // vvp ... +NO_VCD de chay nhanh khi chi can bao cao so sanh.
        if (!$test$plusargs("NO_VCD")) begin
            $dumpfile("wave_apb_uart.vcd");
            $dumpvars(0, tb_apb_uart);
        end
    end

    // =========================================================================
    // 4. CÁC TASK IN ẤN VÀ BÁO CÁO KẾT QUẢ
    // =========================================================================
    task print_header(input [511:0] test_name);
        begin
            $display("\n============================================================");
            $display(">>> TESTCASE %0d: %0s", test_id, test_name);
            $display("============================================================");
        end
    endtask

    task print_summary;
        begin
            $display("\n============================================================");
            $display("                TONG KET KET QUA MO PHONG                   ");
            $display("============================================================");
            $display("  TONG SO TEST : %0d", pass_count + fail_count);
            $display("  SO TEST PASS : %0d", pass_count);
            $display("  SO TEST FAIL : %0d", fail_count);
            $display("============================================================");
            if (fail_count == 0)
                $display("  >>> KET LUAN: TAT CA CAC TESTCASE DEU PASS! XUAT SAC! <<<");
            else
                $display("  >>> KET LUAN: CO %0d TESTCASE BI THAT BAI! CAN KIEM TRA LAI! <<<", fail_count);
            $display("============================================================\n");
        end
    endtask

    // =========================================================================
    // 5. CÁC TASK GIAO TIẾP APB MASTER
    // =========================================================================
    task apb_write(
        input  [11:0] addr,
        input  [31:0] data,
        output        err
    );
        begin
            @(posedge clk);
            paddr   <= addr;
            pwdata  <= data;
            pwrite  <= 1'b1;
            psel    <= 1'b1;
            penable <= 1'b0;

            @(posedge clk);
            penable <= 1'b1;

            // Lay response truoc canh ghi: sau canh nay FIFO co the vua day.
            #1;
            if (pready !== 1'b1) $fatal(1, "APB ACCESS did not complete");
            err = pslverr;
            @(posedge clk);
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            #1; // Let register/FIFO NBA updates and IRQ combinational logic settle.
        end
    endtask

    task apb_read(
        input  [11:0] addr,
        output [31:0] data,
        output        err
    );
        begin
            @(posedge clk);
            paddr   <= addr;
            pwrite  <= 1'b0;
            psel    <= 1'b1;
            penable <= 1'b0;

            @(posedge clk);
            penable <= 1'b1;

            #1;
            if (pready !== 1'b1) $fatal(1, "APB read ACCESS did not complete");
            data = prdata;
            err  = pslverr;

            @(posedge clk);
            psel    <= 1'b0;
            penable <= 1'b0;
            #1; // Read-side FIFO pop and IRQ updates must settle before returning.
        end
    endtask

    // =========================================================================
    // 6. TASK TRUYỀN FRAME UART RX TỪ NGOẠI VI VÀO DUT
    // =========================================================================
    task send_uart_rx_byte(
        input [7:0] byte_val,
        input [1:0] num_data_bits_cfg, // 00: 5b, 01: 6b, 10: 7b, 11: 8b
        input       parity_en_cfg,
        input       parity_type_cfg,   // 0: Even, 1: Odd
        input       inject_error       // 1: Bơm lỗi Parity
    );
        begin
            reference_expect_rx(reference_mask(byte_val, num_data_bits_cfg),
                                parity_en_cfg && inject_error);
            // Drive control on negedge so TX ao samples stable inputs on posedge.
            @(negedge clk);
            virtual_tx_data = byte_val;
            virtual_tx_cfg = {parity_type_cfg, parity_en_cfg,
                              ref_cfg[2], num_data_bits_cfg};
            virtual_tx_inject = inject_error;
            virtual_tx_start = 1;
            @(negedge clk);
            virtual_tx_start = 0;
            wait (virtual_tx_done === 1'b1);
            // Let the module finish its done pulse before another request.
            wait (virtual_tx_done === 1'b0);
        end
    endtask

    // Mot phep trao doi full-duplex; UART ao nhan TX chay song song o tren.
    task reference_exchange(input [31:0] configuration,
                            input [7:0] tx_byte, input [7:0] rx_byte);
        integer polls, tx_before;
        reg [31:0] status, received;
        reg bus_error;
        begin
            apb_write(12'h008, configuration, bus_error);
            if (bus_error) $fatal(1, "Cannot configure reference exchange");
            bit_time_ns = 1_000_000_000 / reference_baud(configuration[6:5]);
            tx_before = ref_tx_checked;
            fork
                send_uart_rx_byte(rx_byte, configuration[1:0],
                                  configuration[3], configuration[4], 1'b0);
                apb_write(12'h000, {24'd0, tx_byte}, bus_error);
            join
            polls = 0;
            status = 0;
            while ((!status[0] || !status[1]) && polls < 40) begin
                apb_read(12'h00C, status, bus_error);
                #(CLK_PERIOD);
                polls = polls + 1;
            end
            if (!status[0] || !status[1] || ref_tx_checked != tx_before + 1) begin
                $display("[REF FAIL] Exchange timeout cfg=%02h STT=%08h", configuration, status);
                ref_errors = ref_errors + 1;
            end
            if (status[1]) apb_read(12'h004, received, bus_error);
            $display("[UART AO] cfg=%02h baud=%0d TX=%02h RX=%02h",
                     configuration, reference_baud(configuration[6:5]),
                     reference_mask(tx_byte, configuration[1:0]),
                     reference_mask(rx_byte, configuration[1:0]));
        end
    endtask

    // =====================================================================
    // SPEC CHECKS: chi dung APB va UART pins, khong truy cap noi bo DUT.
    // =====================================================================
    task spec_check(input condition, input [767:0] description);
        begin
            if (condition === 1'b1) begin
                $display("[SPEC PASS] %0s", description);
                pass_count = pass_count + 1;
            end else begin
                $display("[SPEC FAIL] %0s at %0t", description, $time);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task wait_tx_idle;
        integer n;
        reg [31:0] status;
        reg error_bus;
        begin
            n = 0; status = 0;
            while (!status[0] && n < 500) begin
                apb_read(12'h00C, status, error_bus);
                #(bit_time_ns);
                n = n + 1;
            end
            if (!status[0]) $fatal(1, "SPEC: TX idle timeout");
        end
    endtask

    // Check IRQ = OR(enabled sources), with each source state built externally.
    task check_irq_masks(input [2:0] active_sources);
        integer mask_value;
        reg error_bus;
        begin
            for (mask_value = 0; mask_value < 8; mask_value = mask_value + 1) begin
                apb_write(12'h010, mask_value, error_bus);
                #2;
                spec_check(!error_bus && (irq === (|(active_sources & mask_value[2:0]))),
                           "IRQ mask: only enabled active sources may assert IRQ");
            end
        end
    endtask

    // Drive stop faults independently of the DUT; do not suppress scoreboard errors.
    task check_stop_frame(input [6:0] configuration, input [1:0] bad_stops);
        integer bit_index, stop_index;
        reg parity_value, bus_error;
        reg [31:0] status, value;
        begin
            apb_write(8, {25'd0, configuration}, bus_error);
            spec_check(!bus_error, "Framing test configuration accepted");
            bit_time_ns = 1_000_000_000 / reference_baud(configuration[6:5]);
            reference_expect_rx(reference_mask(8'hA5, configuration[1:0]), |bad_stops);
            raw_rx_enable = 1;
            raw_rx_level = 0; #(bit_time_ns);
            parity_value = configuration[4];
            for (bit_index = 0; bit_index < 5 + configuration[1:0]; bit_index = bit_index + 1) begin
                raw_rx_level = (8'hA5 >> bit_index) & 1;
                parity_value = parity_value ^ raw_rx_level;
                #(bit_time_ns);
            end
            if (configuration[3]) begin
                raw_rx_level = parity_value;
                #(bit_time_ns);
            end
            for (stop_index = 0; stop_index < 1 + configuration[2]; stop_index = stop_index + 1) begin
                raw_rx_level = !bad_stops[stop_index];
                // Release after the sample, avoiding an unintended long break.
                #(3 * bit_time_ns / 4);
                raw_rx_level = 1;
                #(bit_time_ns - 3 * bit_time_ns / 4);
            end
            #(2 * bit_time_ns);
            raw_rx_enable = 0;
            apb_read(12'h00C, status, bus_error);
            spec_check(!bus_error && status[1] && (status[2] === (|bad_stops)),
                       "STT reports stop error, including first/second stop independently");
            if (status[1]) begin
                apb_read(4, value, bus_error);
                spec_check(!bus_error && value[8:0] ===
                           {(|bad_stops), reference_mask(8'hA5, configuration[1:0])},
                           "RX_DATA preserves data and the framing-error bit");
            end else $fatal(1, "Framing test: expected frame never arrived");
            apb_read(12'h00C, status, bus_error);
            spec_check(!status[1] && !status[2], "Framing error clears after the last queued byte is read");
            $display("[FRAMING] cfg=%02h bad_stops=%b", configuration, bad_stops);
        end
    endtask

    task run_spec_tests;
        integer n, baud_sel_test, data_sel_test, parity_test, stop_test;
        integer before_tx, before_rx;
        reg [11:0] bad_address;
        reg [31:0] value, status, configuration;
        reg error_bus, rejected;
        begin
            test_id = 8;
            print_header("SPEC: APB3 ILLEGAL ACCESS, SETUP, BACK-TO-BACK");
            wait_tx_idle();
            apb_write(12'h008, 32'h43, error_bus); // 9600 8N1
            bit_time_ns = 1_000_000_000 / 9600;
            apb_write(12'h010, 0, error_bus);
            for (n = 0; n < 6; n = n + 1) begin
                case (n)
                    0: bad_address = 12'h014;
                    1: bad_address = 12'hFFC;
                    2: bad_address = 12'h001;
                    3: bad_address = 12'h002;
                    4: bad_address = 12'h003;
                    5: bad_address = 12'h006;
                endcase
                apb_write(bad_address, 32'hFFFFFFFF, error_bus);
                spec_check(error_bus, "Illegal/misaligned APB write returns PSLVERR");
                apb_read(bad_address, value, error_bus);
                spec_check(error_bus && value === 32'b0,
                           "Illegal/misaligned APB read returns PSLVERR and zero data");
            end
            apb_write(12'h004, 32'hFF, error_bus);
            spec_check(error_bus, "Write RX_DATA is rejected");
            apb_write(12'h00C, 32'hFF, error_bus);
            spec_check(error_bus, "Write read-only STT is rejected");
            apb_read(12'h008, value, error_bus);
            spec_check(!error_bus && value === 32'h43, "Illegal accesses do not corrupt CFG");

            // Hold SETUP for several clocks: must not push TX FIFO.
            before_tx = ref_tx_checked;
            @(negedge clk);
            psel = 1; penable = 0; pwrite = 1; paddr = 0; pwdata = 8'h96;
            repeat (3) begin
                @(negedge clk);
                spec_check(tx === 1'b1 && !pslverr,
                           "APB extended SETUP write has no TX side effect or error");
            end
            penable = 1;
            #1;
            spec_check(pready && !pslverr, "APB ACCESS completes extended SETUP");
            @(negedge clk);
            psel = 0; penable = 0; pwrite = 0;
            wait_tx_idle();
            spec_check(ref_tx_checked == before_tx + 1, "Extended SETUP produces exactly one TX frame");

            send_uart_rx_byte(8'h69, 3, 0, 0, 0);
            before_rx = ref_rx_checked;
            @(negedge clk);
            psel = 1; penable = 0; pwrite = 0; paddr = 4;
            repeat (3) @(negedge clk);
            // Abort SETUP; subsequent normal read must still return the byte.
            psel = 0;
            apb_read(12'h004, value, error_bus);
            spec_check(!error_bus && value[8:0] === 9'h069 && ref_rx_checked == before_rx + 1,
                       "Aborted/extended read SETUP does not pop RX FIFO");

            // Consecutive transfers retain PSEL; PENABLE returns low for SETUP.
            @(negedge clk);
            psel = 1; penable = 0; pwrite = 1; paddr = 12'h010; pwdata = 2;
            @(negedge clk); penable = 1;
            #1; spec_check(pready && !pslverr, "Back-to-back APB write response");
            @(negedge clk); penable = 0; pwrite = 0;
            @(negedge clk); penable = 1;
            #1; spec_check(pready && !pslverr && prdata === 32'h2,
                           "Back-to-back APB read with PSEL held high");
            @(negedge clk); psel = 0; penable = 0;
            apb_write(12'h010, 0, error_bus);

            test_id = 9;
            print_header("SPEC: CFG LOCK WHILE TX OR RX BUSY");
            apb_write(0, 8'h5A, error_bus);
            #(bit_time_ns);
            apb_write(8, 32'h7F, rejected);
            apb_read(8, value, error_bus);
            spec_check(rejected && !error_bus && value === 32'h43,
                       "CFG write while TX busy: PSLVERR, old config retained");
            wait_tx_idle();
            fork
                send_uart_rx_byte(8'hC3, 3, 0, 0, 0);
                begin
                    #(2 * bit_time_ns);
                    apb_write(8, 32'h7F, rejected);
                    apb_read(8, value, error_bus);
                    spec_check(rejected && !error_bus && value === 32'h43,
                               "CFG write while RX busy: PSLVERR, old config retained");
                end
            join
            apb_read(4, value, error_bus);
            spec_check(value[8:0] === 9'h0C3, "RX data survives rejected CFG change");
            apb_write(8, 32'h4B, error_bus);
            apb_read(8, value, rejected);
            spec_check(!error_bus && !rejected && value === 32'h4B,
                       "CFG becomes writable again when TX and RX idle");

            test_id = 10;
            print_header("SPEC: INDEPENDENT IRQ MASKS AND FIFO DEPTH");
            check_irq_masks(3'b010); // Only TX ready.
            apb_write(12'h010, 2, error_bus);
            spec_check(irq === 1'b1, "TX-ready IRQ asserts when enabled and idle");
            apb_write(0, 8'h01, error_bus);
            apb_write(0, 8'h03, error_bus);
            apb_read(12'h00C, status, error_bus);
            spec_check(!status[0] && irq === 1'b0, "TX-ready IRQ clears with queued frames");
            // First frame is complete, second still active: readiness must stay low.
            #(12 * bit_time_ns);
            apb_read(12'h00C, status, error_bus);
            spec_check(!status[0] && irq === 1'b0, "TX-ready stays low until entire queue completes");
            wait_tx_idle();
            spec_check(irq === 1'b1, "TX-ready IRQ returns after final stop bit");
            send_uart_rx_byte(8'h12, 3, 1, 0, 0);
            check_irq_masks(3'b011); // TX idle and RX nonempty.
            apb_write(12'h010, 1, error_bus);
            send_uart_rx_byte(8'h34, 3, 1, 0, 0);
            apb_read(4, value, error_bus);
            spec_check(value[7:0] === 8'h12 && irq === 1'b1,
                       "RX-ready IRQ remains high while another byte is queued");
            apb_read(4, value, error_bus);
            spec_check(value[7:0] === 8'h34 && irq === 1'b0,
                       "RX-ready IRQ clears after final byte");
            apb_write(12'h010, 4, error_bus); // Isolate overrun IRQ, mask RX/TX.
            for (n = 0; n < 16; n = n + 1) begin
                send_uart_rx_byte(8'h80 + n, 3, 1, 0, 0);
                apb_read(12'h00C, status, error_bus);
                spec_check(status[5] === (n == 15) && !status[3] && irq === 1'b0,
                           "RX FIFO full only at entry 16; overrun IRQ stays low");
            end
            send_uart_rx_byte(8'hFF, 3, 1, 0, 0);
            apb_read(12'h00C, status, error_bus);
            spec_check(status[5] && status[3] && irq === 1'b1,
                       "Entry 17 raises isolated overrun IRQ and preserves full FIFO");
            check_irq_masks(3'b111);
            apb_write(12'h010, 4, error_bus);
            apb_read(4, value, error_bus);
            apb_read(12'h00C, status, error_bus);
            spec_check(!status[3] && status[1] && !status[5] && irq === 1'b0,
                       "First RX read clears overrun IRQ independently of RX-ready");
            for (n = 1; n < 16; n = n + 1) apb_read(4, value, error_bus);
            apb_write(12'h010, 0, error_bus);

            test_id = 11;
            print_header("SPEC: RX ERROR BIT FOLLOWS EACH FIFO ENTRY");
            // Bad, good, bad: error flag must follow the head, not last received byte.
            send_uart_rx_byte(8'h55, 3, 1, 0, 1);
            send_uart_rx_byte(8'hAA, 3, 1, 0, 0);
            send_uart_rx_byte(8'h33, 3, 1, 0, 1);
            for (n = 0; n < 3; n = n + 1) begin
                apb_read(12'h00C, status, error_bus);
                spec_check(status[2] === (n != 1), "STT error reflects current RX FIFO head");
                apb_read(4, value, error_bus);
                spec_check(value[8] === (n != 1), "RX FIFO ninth bit preserves per-byte parity error");
            end
            // Also inject wrong odd parity, independently from existing even test.
            apb_write(8, 32'h5B, error_bus);
            send_uart_rx_byte(8'hA6, 3, 1, 1, 1);
            apb_read(4, value, error_bus);
            spec_check(value[8:0] === 9'h1A6, "Wrong odd parity is detected");

            test_id = 12;
            print_header("SPEC: FALSE START REJECTION AND RECOVERY");
            apb_write(8, 32'h43, error_bus);
            apb_write(12'h010, 1, error_bus); // Enable RX IRQ so the pulse test is meaningful.
            raw_rx_enable = 1; raw_rx_level = 1;
            #(bit_time_ns);
            for (n = 0; n < 2; n = n + 1) begin
                raw_rx_level = 0;
                if (n == 0) #(bit_time_ns / 4);
                else #(3 * bit_time_ns / 8);
                raw_rx_level = 1;
                #(12 * bit_time_ns);
                apb_read(12'h00C, status, error_bus);
                spec_check(!status[1] && !status[2] && !status[3] && irq === 1'b0,
                           "Pulse shorter than half start bit produces no RX data/error/IRQ");
                apb_write(8, 32'h43, error_bus);
                spec_check(!error_bus, "Receiver returns idle after rejecting false start");
            end
            raw_rx_enable = 0;
            send_uart_rx_byte(8'hA5, 3, 0, 0, 0);
            apb_read(4, value, error_bus);
            spec_check(value[8:0] === 9'h0A5, "Valid frame is received after false starts");

            test_id = 13;
            print_header("SPEC: ALL BAUD X DATA X PARITY X STOP COMBINATIONS");
            // Existing TC7 covers all formats at 19200; fill the other 3 baud rates.
            for (baud_sel_test = 0; baud_sel_test < 3; baud_sel_test = baud_sel_test + 1)
                for (data_sel_test = 0; data_sel_test < 4; data_sel_test = data_sel_test + 1)
                    for (parity_test = 0; parity_test < 3; parity_test = parity_test + 1)
                        for (stop_test = 0; stop_test < 2; stop_test = stop_test + 1) begin
                            configuration = (baud_sel_test << 5) | (stop_test << 2) | data_sel_test;
                            if (parity_test != 0) configuration = configuration | 8;
                            if (parity_test == 2) configuration = configuration | 16;
                            reference_exchange(configuration, 8'h96, 8'h69);
                        end

            test_id = 14;
            print_header("SPEC: INVALID RX STOP BIT (FRAMING ERROR)");
            apb_write(12'h010, 0, error_bus);
            check_stop_frame(7'h43, 2'b01); // 8N1, bad stop
            check_stop_frame(7'h47, 2'b01); // 8N2, first stop bad only
            check_stop_frame(7'h47, 2'b10); // 8N2, second stop bad only
            check_stop_frame(7'h47, 2'b11); // 8N2, both stops bad
            check_stop_frame(7'h47, 2'b00); // good frame after errors: no stale latch
            check_stop_frame(7'h4F, 2'b10); // 8E2: good parity cannot hide bad stop
            check_stop_frame(7'h5F, 2'b01); // 8O2: check first stop with odd parity
            send_uart_rx_byte(8'h3C, 3, 1, 1, 0);
            apb_read(4, value, error_bus);
            spec_check(!error_bus && value[8:0] === 9'h03C,
                       "Valid odd-parity frame recovers after framing errors");
        end
    endtask

    // =========================================================================
    // 7. TIẾN TRÌNH KIỂM THỬ CHÍNH (MAIN TEST SEQUENCE)
    // =========================================================================
    initial begin
        ref_cfg = 0;
        tx_compare_expected = 0; tx_compare_actual = 0; tx_compare_pass = 0;
        ref_tx_wr = 0; ref_tx_rd = 0;
        ref_rx_wr = 0; ref_rx_rd = 0;
        ref_tx_checked = 0; ref_rx_checked = 0; ref_errors = 0;
        test_id    = 1;
        pass_count = 0;
        fail_count = 0;
        timeout    = 0;

        rst_n   = 1'b0;
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = 12'b0;
        pwdata  = 32'b0;
        loopback_enable = 0;
        raw_rx_enable = 0; raw_rx_level = 1;
        virtual_tx_start = 0; virtual_tx_data = 0;
        virtual_tx_cfg = 0; virtual_tx_inject = 0;

        #100;
        rst_n = 1'b1;
        #40;

        // ---------------------------------------------------------------------
        // TESTCASE 1: KHỞI TẠO & CẤU HÌNH THANH GHI CFG
        // ---------------------------------------------------------------------
        print_header("KHOI TAO & CAU HINH THANH GHI CFG");

        // Đọc kiểm tra trạng thái ADDR_STT sau reset (Mong đợi: tx_done=1, rx_done=0, err=0)
        apb_read(12'h00C, read_val, err_resp);
        if (read_val == 32'h0000_0001 && err_resp == 1'b0) begin
            $display("  --> [PASS] Trang thai reset ADDR_STT = 0x%08X, ERR = %b", read_val, err_resp);
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Trang thai reset ADDR_STT sai! Nhan: 0x%08X, ERR = %b", read_val, err_resp);
            fail_count = fail_count + 1;
        end

        // Thời gian 1 bit UART ở 9600 Baud: 1s / 9600 ~ 104,167 ns
        bit_time_ns = 1_000_000_000 / 9600;

        // Cấu hình 8-E-1 @ 9600 Baud (CFG = 0x0000_004B)
        apb_write(12'h008, 32'h0000_004B, err_resp);
        apb_read(12'h008, read_val, err_resp);
        if (read_val == 32'h0000_004B && err_resp == 1'b0) begin
            $display("  --> [PASS] Ghi va doc lai ADDR_CFG = 0x%08X thanh cong!", read_val);
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] ADDR_CFG khong dung! Mong doi: 0x4B, Nhan: 0x%08X", read_val);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TESTCASE 2: TRUYỀN DỮ LIỆU UART (TX) & KIỂM TRA BẢO VỆ FIFO FULL
        // ---------------------------------------------------------------------
        test_id = 2;
        print_header("TRUYEN DU LIEU UART (TX) & KIEM TRA CO STATUS");

        // Ghi dữ liệu 0xA5 vào ADDR_TX (TX tu dong kich hoat qua !tx_fifo_empty)
        apb_write(12'h000, 32'h0000_00A5, err_resp);

        // Kiểm tra cờ tx_done đã tụt xuống 0 (báo TX bận)
        apb_read(12'h00C, read_val, err_resp);
        if ((read_val & 32'h1) == 0) begin
            $display("  --> [PASS] Co tx_done da keo xuong 0 (TX dang ban truyen)!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co tx_done khong chuyen ve 0 sau khi kich start_tx!");
            fail_count = fail_count + 1;
        end

        // Byte dau da vao PISO; can them 16 byte de lap day TX FIFO.
        for (i = 0; i < 16; i = i + 1) begin
            apb_write(12'h000, 32'h0000_0010 + i, err_resp);
            apb_read(12'h00C, read_val, err_resp);
            spec_check(!err_resp && (read_val[4] === (i == 15)),
                       "TX FIFO full only after 16 queued bytes, excluding active PISO");
        end

        // Cố tình ghi thêm byte thứ 17 vào ADDR_TX khi TX FIFO đã FULL -> Mong đợi pslverr = 1
        apb_write(12'h000, 32'h0000_00FF, err_resp);
        if (err_resp == 1'b1) begin
            $display("  --> [PASS] apb_slave da chan va bao pslverr=1 khi ghi vao TX FIFO bi FULL!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Khong bao loi pslverr khi ghi vao TX FIFO bi FULL!");
            fail_count = fail_count + 1;
        end

        // Polling chờ TX phát xong toàn bộ FIFO (tx_done quay lại 1)
        timeout = 0;
        while (((read_val & 32'h1) == 0) && (timeout < 500)) begin
            #(bit_time_ns);
            apb_read(12'h00C, read_val, err_resp);
            timeout = timeout + 1;
        end

        if ((read_val & 32'h1) == 32'h1) begin
            $display("  --> [PASS] TX da phat xong hoan toan, tx_done da quay ve 1!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Timeout! TX khong the ket thuc qua trinh phat!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TESTCASE 3: NHẬN DỮ LIỆU UART (RX) & AUTO-CLEAR FLAG
        // ---------------------------------------------------------------------
        test_id = 3;
        print_header("NHAN DU LIEU UART (RX) & AUTO-CLEAR FLAG");

        $display("  [INFO] Bat dau gui byte 0x3C vao chan rx...");
        send_uart_rx_byte(8'h3C, 2'b11, 1'b1, 1'b0, 1'b0); // 8-bit data, Even parity

        // Polling chờ rx_done = 1
        timeout = 0;
        apb_read(12'h00C, read_val, err_resp);
        while (((read_val & 32'h2) == 0) && (timeout < 50)) begin
            #(bit_time_ns / 2);
            apb_read(12'h00C, read_val, err_resp);
            timeout = timeout + 1;
        end

        if ((read_val & 32'h2) != 0) begin
            $display("  --> [PASS] Phat hien co rx_done=1 (Da nhan duoc byte moi)!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Timeout cho co rx_done!");
            fail_count = fail_count + 1;
        end

        // Đọc ADDR_RX lấy dữ liệu nhận
        apb_read(12'h004, read_val, err_resp);
        if (read_val[7:0] == 8'h3C) begin
            $display("  --> [PASS] Du lieu nhan tu ADDR_RX chinh xac: 0x%02X!", read_val[7:0]);
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Du lieu nhan sai! Mong doi 0x3C, Nhan: 0x%02X", read_val[7:0]);
            fail_count = fail_count + 1;
        end

        // Kiểm tra Auto-Clear: Đọc lại ADDR_STT xem rx_done đã bị xóa về 0 chưa
        apb_read(12'h00C, read_val, err_resp);
        if ((read_val & 32'h2) == 0) begin
            $display("  --> [PASS] Co rx_done da duoc tu dong xoa ve 0 sau khi doc ADDR_RX!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co rx_done van con giu nguyen 1, tinh nang auto-clear bi loi!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TESTCASE 4: BƠM LỖI PARITY (PARITY ERROR INJECTION)
        // ---------------------------------------------------------------------
        test_id = 4;
        print_header("BOM LOI BIT PARITY (ERROR INJECTION TEST)");

        $display("  [INFO] Gui byte 0x7B kem bit Parity CO TINH BI SAI...");
        send_uart_rx_byte(8'h7B, 2'b11, 1'b1, 1'b0, 1'b1); // inject_error = 1

        // Polling chờ nhận xong
        timeout = 0;
        apb_read(12'h00C, read_val, err_resp);
        while (((read_val & 32'h2) == 0) && (timeout < 50)) begin
            #(bit_time_ns / 2);
            apb_read(12'h00C, read_val, err_resp);
            timeout = timeout + 1;
        end

        // Kiểm tra cờ error = 1 (bit 2 của ADDR_STT)
        if ((read_val & 32'h4) != 0) begin
            $display("  --> [PASS] Phan cung da bat co ERROR=1 dung khi phat hien Parity sai!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Phan cung khong phat hien ra loi Parity! ADDR_STT = 0x%08X", read_val);
            fail_count = fail_count + 1;
        end

        // Đọc ADDR_RX để kích hoạt cơ chế tự xóa lỗi
        apb_read(12'h004, read_val, err_resp);
        apb_read(12'h00C, read_val, err_resp);
        if ((read_val & 32'h4) == 0) begin
            $display("  --> [PASS] Co ERROR da duoc tu dong xoa ve 0 sau khi doc ADDR_RX!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co ERROR van chua duoc xoa sau khi doc ADDR_RX!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TESTCASE 5: LOOPBACK TOÀN DIỆN (TX NỐI TRỰC TIẾP RX)
        // ---------------------------------------------------------------------
        test_id = 5;
        print_header("LOOPBACK TOAN DIEN (TX NOI TRUC TIEP RX)");

        loopback_enable = 1;
        begin
                reference_expect_rx(8'hD2, 1'b0);
                apb_write(12'h000, 32'h0000_00D2, err_resp);

                // Chờ nhận xong ở RX
                timeout = 0;
                read_val = 0;
                while (((read_val & 32'h2) == 0) && (timeout < 100)) begin
                    #(bit_time_ns / 2);
                    apb_read(12'h00C, read_val, err_resp);
                    timeout = timeout + 1;
                end

                if ((read_val & 32'h2) != 0) begin
                    apb_read(12'h004, read_val, err_resp);
                    if (read_val[7:0] == 8'hD2) begin
                        $display("  --> [PASS] Loopback thanh cong hoan hao! Byte thu duoc: 0x%02X", read_val[7:0]);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("  --> [FAIL] Loopback sai du lieu! Gui 0xD2, Nhan 0x%02X", read_val[7:0]);
                        fail_count = fail_count + 1;
                    end
                end else begin
                    $display("  --> [FAIL] Loopback bi timeout, khong thay RX hoan thanh!");
                    fail_count = fail_count + 1;
                end
            end
        // TX can finish after RX has sampled the frame; keep loopback connected.
        read_val = 0;
        timeout = 0;
        while (!read_val[0] && timeout < 100) begin
            #(bit_time_ns);
            apb_read(12'h00C, read_val, err_resp);
            timeout = timeout + 1;
        end
        if (!read_val[0]) $fatal(1, "Loopback TX timeout");
        loopback_enable = 0;

        // ---------------------------------------------------------------------
        // TESTCASE 6: KIỂM CHỨNG CƠ CHẾ NGẮT (INTERRUPT) & LỖI TRÀN OVERRUN
        // ---------------------------------------------------------------------
        test_id = 6;
        print_header("CO CHE NGAT (INTERRUPT) & PHAT HIEN TRAN DU LIEU OVERRUN");

        // 1. Ghi IER = 0x05 (Bật RX Interrupt & Overrun Interrupt)
        apb_write(12'h010, 32'h0000_0005, err_resp);
        apb_read(12'h010, read_val, err_resp);
        if (read_val == 32'h0000_0005) begin
            $display("  --> [PASS] Ghi va doc lai ADDR_IER = 0x05 thanh cong!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Ghi/doc ADDR_IER that bai: 0x%08X", read_val);
            fail_count = fail_count + 1;
        end

        // 2. Gửi byte 0xA5 vào RX, kiểm tra ngắt IRQ nhảy lên 1
        $display("  [INFO] Gui byte 0xA5 vao RX va theo doi chan IRQ...");
        send_uart_rx_byte(8'hA5, 2'b11, 1'b1, 1'b0, 1'b0);
        #100;
        if (irq == 1) begin
            $display("  --> [PASS] Nhan xong byte 0xA5, chan IRQ da lap tuc nhay len muc 1!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] IRQ khong nhay len muc 1 sau khi nhan xong byte!");
            fail_count = fail_count + 1;
        end

        // 3. Đọc dữ liệu RX -> Kiểm tra IRQ tự động hạ về 0
        apb_read(12'h004, read_val, err_resp);
        #100;
        if ((read_val[7:0] == 8'hA5) && (irq == 0)) begin
            $display("  --> [PASS] Doc dung byte 0xA5 va chan IRQ da tu dong ha ve 0!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Doc sai byte hoac IRQ chua ha ve 0: Val=0x%02X, IRQ=%b", read_val[7:0], irq);
            fail_count = fail_count + 1;
        end

        // 4. Kịch bản Overrun: Gửi 16 byte vào RX mà CPU không đọc để làm đầy FIFO
        $display("  [INFO] Bat dau kich ban Overrun: Bom 16 byte vao RX FIFO...");
        for (i = 0; i < 16; i = i + 1) begin
            send_uart_rx_byte(8'h30 + i, 2'b11, 1'b1, 1'b0, 1'b0);
        end
        #100;

        // CPU bận không đọc, PC bắn tiếp byte thứ 17 (0xFF) -> Gây Overrun
        $display("  [INFO] RX FIFO da day (16 byte), PC tiep tuc ban byte thu 17...");
        send_uart_rx_byte(8'hFF, 2'b11, 1'b1, 1'b0, 1'b0);
        #100;

        // Kiểm tra bit 3 (overrun_error) trong ADDR_STT và IRQ = 1
        apb_read(12'h00C, read_val, err_resp);
        if (((read_val & 32'h08) != 0) && (irq == 1)) begin
            $display("  --> [PASS] Phat hien Overrun: Bit 3 cua ADDR_STT = 1 va IRQ = 1!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Khong phat hien Overrun khi byte bi ghi de: STT=0x%02X, IRQ=%b", read_val[7:0], irq);
            fail_count = fail_count + 1;
        end

        // 5. Đọc cạn RX FIFO để thu thập dữ liệu và tự động xóa cờ Overrun
        for (i = 0; i < 16; i = i + 1) begin
            apb_read(12'h004, read_val, err_resp);
        end
        apb_read(12'h00C, read_val, err_resp);
        #100;
        if (((read_val & 32'h08) == 0) && (irq == 0)) begin
            $display("  --> [PASS] Co Overrun da duoc xoa ve 0 va IRQ ha ve 0 sau khi doc RX!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co Overrun hoac IRQ chua duoc xoa sau khi doc RX: STT=0x%02X, IRQ=%b", read_val[7:0], irq);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TESTCASE 7: UART AO DOI CHIEU TX/RX, CAC DO RONG/PARITY/STOP/BAUD
        // ---------------------------------------------------------------------
        loopback_enable = 0;
        // Loopback RX hoan tat som hon TX; cho TX idle truoc khi doi CFG.
        read_val = 0;
        timeout = 0;
        while (!read_val[0] && timeout < 100) begin
            #(bit_time_ns);
            apb_read(12'h00C, read_val, err_resp);
            timeout = timeout + 1;
        end
        if (!read_val[0]) $fatal(1, "TX did not become idle before reference tests");
        test_id = 7;
        print_header("UART AO: DOI CHIEU DOC LAP TX/RX VA FULL DUPLEX");
        // 24 to hop: 5..8 data bits, none/even/odd parity, 1..2 stop.
        for (cfg_bits = 0; cfg_bits < 4; cfg_bits = cfg_bits + 1)
            for (cfg_parity = 0; cfg_parity < 3; cfg_parity = cfg_parity + 1)
                for (cfg_stop = 0; cfg_stop < 2; cfg_stop = cfg_stop + 1) begin
                    cfg_value = (3 << 5) | (cfg_stop << 2) | cfg_bits;
                    if (cfg_parity != 0) cfg_value = cfg_value | 8;
                    if (cfg_parity == 2) cfg_value = cfg_value | 16;
                    reference_exchange(cfg_value, 8'hA5, 8'hDA);
                end
        // Kiem tra ca 4 baud bang du lieu nhieu canh chuyen muc.
        for (cfg_baud = 0; cfg_baud < 4; cfg_baud = cfg_baud + 1)
            reference_exchange((cfg_baud << 5) | 3, 8'h55, 8'hAA);

        run_spec_tests();

        #500;
        if (ref_tx_wr != ref_tx_rd || ref_rx_wr != ref_rx_rd) begin
            $display("[REF FAIL] Pending bytes: TX=%0d RX=%0d",
                     ref_tx_wr-ref_tx_rd, ref_rx_wr-ref_rx_rd);
            ref_errors = ref_errors + 1;
        end
        $display("[UART AO] TX checked=%0d RX checked=%0d errors=%0d",
                 ref_tx_checked, ref_rx_checked, ref_errors);
        if (ref_errors == 0) pass_count = pass_count + 1;
        else fail_count = fail_count + ref_errors;
        print_summary;
        if (fail_count != 0) $fatal(1, "UART verification failed");
        $finish;
    end

endmodule