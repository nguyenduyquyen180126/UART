`timescale 1ns/1ps

module tb_firmware_scenario;

    // =========================================================================
    // 1. CÁC TÍN HIỆU VÀ THAM SỐ
    // =========================================================================
    parameter CLK_PERIOD = 20; // 50 MHz clock -> Chu kỳ 20ns
    parameter BIT_TIME_9600 = 104167; // Chu kỳ 1 bit ở 9600 baud (~104.167 us)

    reg        clk;
    reg        rst_n;

    // Tín hiệu Bus APB (Giả lập Nios V CPU Master)
    reg        psel;
    reg        penable;
    reg        pwrite;
    reg [11:0] paddr;
    reg [31:0] pwdata;
    wire       pready;
    wire       pslverr;
    wire [31:0] prdata;

    // Đường dây nối tiếp UART
    wire       tx; // DE2 phát sang PC
    reg        rx; // PC phát sang DE2

    // Biến phụ trợ kiểm tra
    reg [31:0] read_val;
    reg [7:0]  sim_pc_buf [0:127];
    integer    sim_pc_idx = 0;
    integer    pass_count = 0;
    integer    fail_count = 0;

    // =========================================================================
    // 2. KHỞI TẠO DUT (apb_uart)
    // =========================================================================
    apb_uart #(
        .CLK_FREQ(50_000_000)
    ) dut (
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

    // Tạo clock 50 MHz
    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // 3. CÁC TASK MÔ PHỎNG CPU NIOS V TRUY CẬP BUS APB (MMIO DRIVER)
    // =========================================================================
    // Mô phỏng hàm C: IOWR_32DIRECT(addr, 0, data)
    task cpu_apb_write(input [11:0] addr, input [31:0] data);
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
        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;
    end
    endtask

    // Mô phỏng hàm C: IORD_32DIRECT(addr, 0)
    task cpu_apb_read(input [11:0] addr, output [31:0] data);
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

        psel    <= 1'b0;
        penable <= 1'b0;
    end
    endtask

    // Mô phỏng phía PC gửi 1 byte nối tiếp vào chân rx của kit
    task pc_send_byte(input [7:0] byte_val);
        integer i;
    begin
        $display("[PC Simulator] Gui byte 0x%02X ('%c') vao chan RX cua kit...", byte_val, byte_val);
        // Start bit = 0
        rx = 1'b0;
        #BIT_TIME_9600;

        // 8 Data bits (LSB first)
        for (i = 0; i < 8; i = i + 1) begin
            rx = byte_val[i];
            #BIT_TIME_9600;
        end

        // Stop bit = 1
        rx = 1'b1;
        #BIT_TIME_9600;
    end
    endtask

    // =========================================================================
    // 4. KỊCH BẢN KIỂM CHỨNG TOÀN DIỆN FIRMWARE MAIN.C
    // =========================================================================
    initial begin
        $dumpfile("wave_firmware_scenario.vcd");
        $dumpvars(0, tb_firmware_scenario);

        clk   = 1'b0;
        rst_n = 1'b0;
        psel  = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = 12'h0;
        pwdata  = 32'h0;
        rx    = 1'b1; // UART idle mức cao

        $display("\n====================================================================");
        $display("   MO PHONG KIEM CHUNG KICH BAN FIRMWARE C TREN BUS AMBA APB        ");
        $display("====================================================================");

        // Reset hệ thống trong 100ns
        #100;
        rst_n = 1'b1;
        #100;

        // ---------------------------------------------------------------------
        // TEST 1: Kiểm tra trạng thái Reset của APB UART
        // ---------------------------------------------------------------------
        $display("\n>>> [BƯỚC 1]: Kiem tra trang thai ban dau cua thanh ghi STT (0x10)");
        cpu_apb_read(12'h010, read_val);
        if ((read_val & 32'h1) == 1'b1) begin
            $display("  --> [PASS] Co tx_done = 1 (Bo phat dang ranh, san sang)");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co tx_done != 1 (Gia tri doc duoc: 0x%08X)", read_val);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TEST 2: CPU chạy hàm uart_init(): ghi cấu hình 9600-8N1 vào UART_CFG_REG
        // Code C: IOWR_32DIRECT(UART_CFG_REG, 0, (0x2 << 5) | 0x3) -> 0x43
        // ---------------------------------------------------------------------
        $display("\n>>> [BƯỚC 2]: CPU chay ham uart_init() -> Ghi 0x43 vao UART_CFG_REG (0x08)");
        cpu_apb_write(12'h008, 32'h0000_0043);

        // Đọc lại kiểm chứng
        cpu_apb_read(12'h008, read_val);
        if (read_val == 32'h0000_0043) begin
            $display("  --> [PASS] UART_CFG_REG doc lai dung 0x43 (Baud 9600, 8-N-1)");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] UART_CFG_REG doc sai: 0x%08X", read_val);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TEST 3: CPU chạy lệnh "send" -> Gửi ký tự 'K' (0x4B) qua UART TX
        // Code C: Ghi 'K' vào 0x00, ghi 0x01 vào 0x0C (start_tx)
        // ---------------------------------------------------------------------
        $display("\n>>> [BƯỚC 3]: CPU gui ky tu 'K' (0x4B) qua bus APB");
        cpu_apb_write(12'h000, 32'h0000_004B); // Ghi ký tự vào TX buffer
        cpu_apb_write(12'h00C, 32'h0000_0001); // start_tx = 1

        // Kiểm tra cờ tx_done bị kéo xuống 0 (đang bận truyền)
        cpu_apb_read(12'h010, read_val);
        if ((read_val & 32'h1) == 1'b0) begin
            $display("  --> [PASS] Co tx_done da keo ve 0 (UART dang ban phat frame 10-bit)");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co tx_done chua keo ve 0!");
            fail_count = fail_count + 1;
        end

        // Chờ UART phát xong (10 bit x 104us ~ 1.04ms)
        #(BIT_TIME_9600 * 11);
        cpu_apb_read(12'h010, read_val);
        if ((read_val & 32'h1) == 1'b1) begin
            $display("  --> [PASS] Phat xong frame! Co tx_done da tu dong quay ve 1");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Het thoi gian ma tx_done van bang 0!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TEST 4: PC gửi ký tự 'A' (0x41) xuống kit -> CPU nhận qua APB & Loopback
        // ---------------------------------------------------------------------
        // ---------------------------------------------------------------------
        // TEST 4: MÔ PHỎNG CÁCH B - PC GỬI NGUYÊN CHUỖI "OK\r" VÀ CPU GOM DÒNG
        // ---------------------------------------------------------------------
        $display("\n>>> [BƯỚC 4]: PC truyen chuoi \"OK\\r\" (0x4F, 0x4B, 0x0D) vao chan RX cua kit...");

        // Ký tự 1: 'O' (0x4F)
        pc_send_byte(8'h4F);
        cpu_apb_read(12'h010, read_val);
        if ((read_val & 32'h2) != 1'b0) begin
            $display("  --> [PASS] Nhan byte 1 ('O'): Co rx_done = 1");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Khong nhan duoc byte 1!");
            fail_count = fail_count + 1;
        end
        cpu_apb_read(12'h004, read_val);
        sim_pc_buf[sim_pc_idx] = read_val[7:0];
        sim_pc_idx = sim_pc_idx + 1;

        // Ký tự 2: 'K' (0x4B)
        pc_send_byte(8'h4B);
        cpu_apb_read(12'h010, read_val);
        if ((read_val & 32'h2) != 1'b0) begin
            $display("  --> [PASS] Nhan byte 2 ('K'): Co rx_done = 1");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Khong nhan duoc byte 2!");
            fail_count = fail_count + 1;
        end
        cpu_apb_read(12'h004, read_val);
        sim_pc_buf[sim_pc_idx] = read_val[7:0];
        sim_pc_idx = sim_pc_idx + 1;

        // Ký tự 3: '\r' (0x0D - Phím Enter từ PC)
        pc_send_byte(8'h0D);
        cpu_apb_read(12'h010, read_val);
        if ((read_val & 32'h2) != 1'b0) begin
            $display("  --> [PASS] Nhan byte 3 (Enter '\\r'): Co rx_done = 1");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Khong nhan duoc byte Enter!");
            fail_count = fail_count + 1;
        end
        cpu_apb_read(12'h004, read_val);

        // CPU phát hiện Enter: Commit chuỗi và kiểm tra nội dung bộ đệm
        if (read_val[7:0] == 8'h0D && sim_pc_idx == 2 && sim_pc_buf[0] == 8'h4F && sim_pc_buf[1] == 8'h4B) begin
            $display("  --> [PASS] CPU phat hien Enter va gom duoc chuoi hoan chinh: \"%c%c\" (Cach B thanh cong!)", sim_pc_buf[0], sim_pc_buf[1]);
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Gom chuoi bi sai!");
            fail_count = fail_count + 1;
        end

        // Kiểm tra cơ chế tự động xóa cờ (Auto-clear rx_done)
        cpu_apb_read(12'h010, read_val);
        if ((read_val & 32'h2) == 1'b0) begin
            $display("  --> [PASS] Phan cung tu dong xoa co rx_done ve 0 sau khi CPU doc!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] Co rx_done chua duoc xoa!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TỔNG KẾT
        // ---------------------------------------------------------------------
        $display("\n====================================================================");
        $display("                   KET QUA KIEM CHUNG KICH BAN                      ");
        $display("====================================================================");
        $display("  SO TESTCASE PASS : %0d / 9", pass_count);
        $display("  SO TESTCASE FAIL : %0d / 9", fail_count);
        if (fail_count == 0) begin
            $display("  >>> KET LUAN: TOAN BO KICH BAN FIRMWARE C VA BUS APB HOAT DONG 100%% CHUAN XAC! <<<");
        end else begin
            $display("  >>> KET LUAN: PHAT HIEN CO LOI CAN KIEM TRA LAI! <<<");
        end
        $display("====================================================================\n");

        $finish;
    end

endmodule
