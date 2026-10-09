`timescale 1ns/1ps

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
    reg         rx;

    // Biến quản lý testbench & thống kê
    integer     test_id;
    integer     pass_count;
    integer     fail_count;
    integer     timeout;
    integer     bit_time_ns;

    reg  [31:0] read_val;
    reg         err_resp;

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
        .rx      (rx)
    );

    // =========================================================================
    // 3. TẠO CLOCK 50 MHz VÀ DUMP SÓNG VCD
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin
        $dumpfile("wave_apb_uart.vcd");
        $dumpvars(0, tb_apb_uart);
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

            @(posedge clk);
            #1;
            err = pslverr;

            @(posedge clk);
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
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

            @(posedge clk);
            #1;
            data = prdata;
            err  = pslverr;

            @(posedge clk);
            psel    <= 1'b0;
            penable <= 1'b0;
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
        integer i;
        integer total_bits;
        reg parity_bit_calc;
        reg parity_to_send;
        begin
            case (num_data_bits_cfg)
                2'b00:   total_bits = 5; // 5 data bits
                2'b01:   total_bits = 6; // 6 data bits
                2'b10:   total_bits = 7; // 7 data bits
                2'b11:   total_bits = 8; // 8 data bits
                default: total_bits = 8;
            endcase

            // 1. Start bit
            rx = 1'b0;
            #(bit_time_ns);

            // 2. Data bits (LSB first)
            parity_bit_calc = 1'b0;
            for (i = 0; i < total_bits; i = i + 1) begin
                rx = byte_val[i];
                parity_bit_calc = parity_bit_calc ^ byte_val[i];
                #(bit_time_ns);
            end

            // 3. Parity bit
            if (parity_en_cfg) begin
                if (parity_type_cfg)
                    parity_to_send = ~parity_bit_calc; // Odd parity
                else
                    parity_to_send = parity_bit_calc;  // Even parity

                if (inject_error)
                    parity_to_send = ~parity_to_send;  // Đảo bit để tạo lỗi

                rx = parity_to_send;
                #(bit_time_ns);
            end

            // 4. Stop bit
            rx = 1'b1;
            #(bit_time_ns);
        end
    endtask

    // =========================================================================
    // 7. TIẾN TRÌNH KIỂM THỬ CHÍNH (MAIN TEST SEQUENCE)
    // =========================================================================
    initial begin
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
        rx      = 1'b1; // UART idle ở mức cao

        #100;
        rst_n = 1'b1;
        #40;

        // ---------------------------------------------------------------------
        // TESTCASE 1: KHỞI TẠO & CẤU HÌNH THANH GHI CFG
        // ---------------------------------------------------------------------
        print_header("KHOI TAO & CAU HINH THANH GHI CFG");

        // Đọc kiểm tra trạng thái ADDR_STT sau reset (Mong đợi: tx_done=1, rx_done=0, err=0)
        apb_read(12'h010, read_val, err_resp);
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
        // TESTCASE 2: TRUYỀN DỮ LIỆU UART (TX) & KIỂM TRA BẢO VỆ
        // ---------------------------------------------------------------------
        test_id = 2;
        print_header("TRUYEN DU LIEU UART (TX) & KIEM TRA CO STATUS");

        // Ghi dữ liệu 0xA5 vào ADDR_TX và kích start_tx = 1 qua ADDR_CTRL
        apb_write(12'h000, 32'h0000_00A5, err_resp);
        apb_write(12'h00C, 32'h0000_0001, err_resp);

        // Kiểm tra cờ tx_done đã tụt xuống 0 (báo TX bận)
        apb_read(12'h010, read_val, err_resp);
        if ((read_val & 32'h1) == 0) begin
            $display("  --> [PASS] Co tx_done da keo xuong 0 (TX dang ban truyen)!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co tx_done khong chuyen ve 0 sau khi kich start_tx!");
            fail_count = fail_count + 1;
        end

        // Cố tình ghi đè vào ADDR_TX khi TX đang bận -> Mong đợi pslverr = 1
        apb_write(12'h000, 32'h0000_00FF, err_resp);
        if (err_resp == 1'b1) begin
            $display("  --> [PASS] apb_slave da chan va bao pslverr=1 khi ghi de luc TX ban!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Khong bao loi pslverr khi ghi vao TX luc dang ban!");
            fail_count = fail_count + 1;
        end

        // Polling chờ TX phát xong (tx_done quay lại 1)
        timeout = 0;
        while (((read_val & 32'h1) == 0) && (timeout < 50)) begin
            #(bit_time_ns);
            apb_read(12'h010, read_val, err_resp);
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
        apb_read(12'h010, read_val, err_resp);
        while (((read_val & 32'h2) == 0) && (timeout < 50)) begin
            #(bit_time_ns / 2);
            apb_read(12'h010, read_val, err_resp);
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
        apb_read(12'h010, read_val, err_resp);
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
        apb_read(12'h010, read_val, err_resp);
        while (((read_val & 32'h2) == 0) && (timeout < 50)) begin
            #(bit_time_ns / 2);
            apb_read(12'h010, read_val, err_resp);
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
        apb_read(12'h010, read_val, err_resp);
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

        fork
            // Tiến trình 1: Bắt tín hiệu tx đưa sang rx liên tục
            forever @(tx) rx = tx;

            // Tiến trình 2: Điều khiển phát và kiểm tra nhận qua bus APB
            begin
                apb_write(12'h000, 32'h0000_00D2, err_resp);
                apb_write(12'h00C, 32'h0000_0001, err_resp);

                // Chờ nhận xong ở RX
                timeout = 0;
                read_val = 0;
                while (((read_val & 32'h2) == 0) && (timeout < 100)) begin
                    #(bit_time_ns / 2);
                    apb_read(12'h010, read_val, err_resp);
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
        join_any
        disable fork;

        // Kết thúc mô phỏng
        #500;
        print_summary;
        $finish;
    end

endmodule