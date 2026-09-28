`timescale 1ns/1ps

module tb_rx_uart();

    // =========================================================================
    // 1. KHAI BÁO CÁC TÍN HIỆU (SIGNALS & INTERFACES)
    // =========================================================================
    reg clk;
    reg rst_n;

    // Các tín hiệu giao tiếp với rx_uart (DUT)
    wire        baud_tick;
    reg  [1:0]  baud_rate;     // 00: 2400, 01: 4800, 10: 9600, 11: 19200
    reg  [1:0]  data_b_num;    // 00: 5 bits, 01: 6 bits, 10: 7 bits, 11: 8 bits
    reg         stop_b_num;    // 0: 1 stop bit, 1: 2 stop bits
    reg  [1:0]  parity_type;   // 00: None, 01: Odd parity, 10: Even parity
    reg         parity_en;     // 0: Không dùng parity, 1: Có parity
    reg         rx;            // Đường truyền nối tiếp UART RX

    wire [31:0] rx_data;       // Dữ liệu nhận được từ DUT
    wire        rx_done;       // Xung báo đã nhận xong 1 frame
    wire        error;         // Cờ báo lỗi Parity từ DUT

    // Biến quản lý testbench & thống kê kết quả
    integer bit_time;          // Thời gian 1 bit (ns)
    integer test_count;        // Tổng số test case đã chạy
    integer pass_count;        // Số test case PASS
    integer fail_count;        // Số test case FAIL

    // Bộ chốt (Latch) để bắt xung rx_done và lưu kết quả nhận được
    // Giúp TB không bao giờ bị trượt xung rx_done dù xung chỉ tồn tại 1 chu kỳ clock!
    reg        clear_done;
    reg        rx_done_latched;
    reg [31:0] captured_rx_data;
    reg        captured_error;

    // =========================================================================
    // 2. KHỞI TẠO MODULE (DUT & BAUD GEN INSTANTIATION)
    // =========================================================================
    rx_baud_gen #(
        .CLK_FREQ(50_000_000)
    ) rx_baud_gen_inst (
        .clk(clk),
        .rst_n(rst_n),
        .baud_rate(baud_rate),
        .baud_en(baud_tick)
    );

    rx_uart rx_uart_dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .baud_tick(baud_tick),
        .data_b_num(data_b_num),
        .stop_b_num(stop_b_num),
        .parity_type(parity_type),
        .parity_en(parity_en),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .error(error)
    );

    // =========================================================================
    // 3. TẠO CLOCK 50 MHz (Chu kỳ 20ns: 10ns HIGH / 10ns LOW)
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // =========================================================================
    // 4. MẠCH CHỐT XUNG RX_DONE (CHỐNG BỎ SÓT XUNG TRONG SIMULATION)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_done_latched  <= 1'b0;
            captured_rx_data <= 32'd0;
            captured_error   <= 1'b0;
        end else if (clear_done) begin
            rx_done_latched  <= 1'b0;
        end else if (rx_done) begin
            rx_done_latched  <= 1'b1;
            captured_rx_data <= rx_data;
            captured_error   <= error;
        end
    end

    // =========================================================================
    // 5. TASK CẤU HÌNH UART & TÍNH TOÁN BIT_TIME TỰ ĐỘNG
    // =========================================================================
    task set_uart_config(
        input [1:0] cfg_baud_rate,
        input [1:0] cfg_data_b_num,
        input       cfg_stop_b_num,
        input       cfg_parity_en,
        input [1:0] cfg_parity_type
    );
        begin
            baud_rate   = cfg_baud_rate;
            data_b_num  = cfg_data_b_num;
            stop_b_num  = cfg_stop_b_num;
            parity_en   = cfg_parity_en;
            parity_type = cfg_parity_type;

            case (cfg_baud_rate)
                2'b00: bit_time = 1_000_000_000 / 2400;   // 2400 baud (~416,667 ns)
                2'b01: bit_time = 1_000_000_000 / 4800;   // 4800 baud (~208,333 ns)
                2'b10: bit_time = 1_000_000_000 / 9600;   // 9600 baud (~104,167 ns)
                2'b11: bit_time = 1_000_000_000 / 19200;  // 19200 baud (~52,083 ns)
                default: bit_time = 1_000_000_000 / 9600;
            endcase
            #(bit_time); // Đợi ổn định cấu hình
        end
    endtask

    // =========================================================================
    // 6. TASK TRUYỀN BYTE & TỰ ĐỘNG KIỂM TRA (SELF-CHECKING & TIMEOUT MONITOR)
    // =========================================================================
    task send_and_check(
        input [7:0] byte_data,
        input       inject_parity_error // 1: Cố tình đảo bit parity để test cờ error
    );
        integer i;
        integer num_data_bits;
        integer num_stop_bits;
        reg parity_calc;
        reg parity_val;
        reg [31:0] expected_data;
        reg [31:0] data_mask;
        integer timeout_wait;
        begin
            test_count = test_count + 1;

            // Xác định số bit data và mặt nạ dữ liệu tương ứng
            case (data_b_num)
                2'b00: begin num_data_bits = 5; data_mask = 32'h0000001F; end
                2'b01: begin num_data_bits = 6; data_mask = 32'h0000003F; end
                2'b10: begin num_data_bits = 7; data_mask = 32'h0000007F; end
                2'b11: begin num_data_bits = 8; data_mask = 32'h000000FF; end
            endcase
            num_stop_bits = stop_b_num ? 2 : 1;
            expected_data = byte_data & data_mask;

            // Xóa cờ chốt trước khi phát frame mới
            clear_done = 1'b1;
            @(posedge clk);
            clear_done = 1'b0;

            $display("\n------------------------------------------------------------");
            $display("[TEST #%0d] Thoi gian: %0t ns", test_count, $time);
            $display("  Dang gui byte: 0x%02X | Mong doi nhan: 0x%02X", byte_data, expected_data[7:0]);
            $display("  Cau hinh: %0d Data bits | %0d Stop bit(s) | Parity: %s (%s)",
                     num_data_bits, num_stop_bits,
                     parity_en ? "BAT (ENABLED)" : "TAT (DISABLED)",
                     (parity_type == 2'b01) ? "Odd (Le)" : (parity_type == 2'b10) ? "Even (Chan)" : "None");
            if (inject_parity_error && parity_en)
                $display("  [Luu y] Dang CO TINH bom loi bit Parity de kiem tra co ERROR!");

            // --- BƯỚC 1: START BIT (Kéo xuống mức 0 trong 1 bit_time) ---
            rx = 1'b0;
            #(bit_time);

            // --- BƯỚC 2: DATA BITS (Truyền từ LSB đến MSB) ---
            parity_calc = 1'b0;
            for (i = 0; i < num_data_bits; i = i + 1) begin
                rx = byte_data[i];
                parity_calc = parity_calc ^ byte_data[i];
                #(bit_time);
            end

            // --- BƯỚC 3: PARITY BIT (Nếu parity_en = 1) ---
            if (parity_en) begin
                if (parity_type == 2'b01) begin
                    // Parity Lẻ (Odd): Tổng số bit 1 của (data + parity) là số LẺ
                    parity_val = ~parity_calc;
                end else if (parity_type == 2'b10) begin
                    // Parity Chẵn (Even): Tổng số bit 1 của (data + parity) là số CHẴN
                    parity_val = parity_calc;
                end else begin
                    parity_val = 1'b0;
                end

                // Nếu có yêu cầu inject error, đảo ngược bit parity
                if (inject_parity_error)
                    rx = ~parity_val;
                else
                    rx = parity_val;

                #(bit_time);
            end

            // --- BƯỚC 4: STOP BIT (Kéo lên mức 1 trong 1 hoặc 2 bit_time) ---
            rx = 1'b1;
            #(bit_time * num_stop_bits);

            // --- BƯỚC 5: CHỜ RX_DONE VỚI TIMEOUT (Tránh treo mô phỏng) ---
            timeout_wait = 0;
            while (!rx_done_latched && timeout_wait < 50) begin
                #(bit_time / 10);
                timeout_wait = timeout_wait + 1;
            end

            // --- BƯỚC 6: TỰ ĐỘNG ĐỐI SOÁT KẾT QUẢ ---
            if (!rx_done_latched) begin
                $display("  --> [FAIL] TIMEOUT! Tin hieu rx_done KHONG duoc bat sau khi truyen frame.");
                $display("             Gia tri DUT hien tai: rx_data = 0x%08X, rx_done = %0b, error = %0b",
                         rx_data, rx_done, error);
                $display("             (Goi y: Kiem tra rx_controller FSM hoac tick_cnt/bit_cnt trong RTL)");
                fail_count = fail_count + 1;
            end else begin
                if (captured_rx_data !== expected_data) begin
                    $display("  --> [FAIL] DỮ LIỆU SAI (DATA MISMATCH)!");
                    $display("             Ky vong (Expected): 0x%02X", expected_data[7:0]);
                    $display("             Nhan duoc (Got)   : 0x%02X (rx_data 32-bit: 0x%08X)",
                             captured_rx_data[7:0], captured_rx_data);
                    fail_count = fail_count + 1;
                end else if (captured_error !== inject_parity_error) begin
                    $display("  --> [FAIL] CO BAO LOI PARITY SAI (ERROR MISMATCH)!");
                    $display("             Ky vong error = %0b, Nhan duoc error = %0b",
                             inject_parity_error, captured_error);
                    fail_count = fail_count + 1;
                end else begin
                    $display("  --> [PASS] Nhan byte thanh cong va chinh xac!");
                    $display("             rx_data = 0x%02X, error = %0b, rx_done da kich hoat.",
                             captured_rx_data[7:0], captured_error);
                    pass_count = pass_count + 1;
                end
            end

            // Khoảng nghỉ giữa các frame (Idle time: 2 bit_time)
            rx = 1'b1;
            #(bit_time * 2);
        end
    endtask

    // =========================================================================
    // 7. KỊCH BẢN KIỂM THỬ (TEST SCENARIOS)
    // =========================================================================
    initial begin
        // Ghi lại dạng sóng để debug bằng GTKWave
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_rx_uart);

        // Khởi tạo các tín hiệu
        clear_done = 1'b0;
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        rx = 1'b1;
        rst_n = 1'b0;

        $display("\n************************************************************");
        $display("          BAT DAU MO PHONG TESTBENCH RX UART               ");
        $display("************************************************************");

        // Nhả Reset sau 100ns đồng bộ với sườn âm của clock
        #100;
        @(negedge clk);
        rst_n = 1'b1;
        $display("[INFO] Thoi gian %0t ns: He thong da nha Reset (rst_n = 1).", $time);

        // ---------------------------------------------------------------------
        // KỊCH BẢN 1: Baud 9600, 8 Data bits, 1 Stop bit, ODD Parity (8-O-1)
        // ---------------------------------------------------------------------
        $display("\n>>> KICH BAN 1: 8-O-1 (8 Data bits, Parity Le, 1 Stop bit) @ 9600 Baud");
        set_uart_config(2'b10, 2'b11, 1'b0, 1'b1, 2'b01);
        send_and_check(8'hA5, 1'b0); // Truyền chuẩn 0xA5
        send_and_check(8'h5A, 1'b0); // Truyền chuẩn 0x5A
        send_and_check(8'h3C, 1'b1); // Bơm lỗi Parity (Kỳ vọng error = 1)

        // ---------------------------------------------------------------------
        // KỊCH BẢN 2: Baud 9600, 8 Data bits, 1 Stop bit, EVEN Parity (8-E-1)
        // ---------------------------------------------------------------------
        $display("\n>>> KICH BAN 2: 8-E-1 (8 Data bits, Parity Chan, 1 Stop bit) @ 9600 Baud");
        set_uart_config(2'b10, 2'b11, 1'b0, 1'b1, 2'b10);
        send_and_check(8'hFF, 1'b0); // Truyền 0xFF
        send_and_check(8'h00, 1'b0); // Truyền 0x00

        // ---------------------------------------------------------------------
        // KỊCH BẢN 3: Baud 9600, 8 Data bits, 1 Stop bit, NO Parity (8-N-1)
        // ---------------------------------------------------------------------
        $display("\n>>> KICH BAN 3: 8-N-1 (8 Data bits, Khong Parity, 1 Stop bit) @ 9600 Baud");
        set_uart_config(2'b10, 2'b11, 1'b0, 1'b0, 2'b00);
        send_and_check(8'h7E, 1'b0);

        // ---------------------------------------------------------------------
        // KỊCH BẢN 4: Baud 9600, 7 Data bits, 2 Stop bits, ODD Parity (7-O-2)
        // ---------------------------------------------------------------------
        $display("\n>>> KICH BAN 4: 7-O-2 (7 Data bits, Parity Le, 2 Stop bits) @ 9600 Baud");
        set_uart_config(2'b10, 2'b10, 1'b1, 1'b1, 2'b01);
        send_and_check(8'h55, 1'b0);

        // ---------------------------------------------------------------------
        // TỔNG KẾT KẾT QUẢ KIỂM THỬ (SUMMARY REPORT)
        // ---------------------------------------------------------------------
        #(bit_time * 5);
        $display("\n============================================================");
        $display("                 TONG KET KET QUA MO PHONG                  ");
        $display("============================================================");
        $display("  TONG SO TEST CASE : %0d", test_count);
        $display("  SO TEST CASE PASS : %0d", pass_count);
        $display("  SO TEST CASE FAIL : %0d", fail_count);
        $display("============================================================");
        if (fail_count == 0 && test_count > 0)
            $display("  >>> KET LUAN: TAT CA CAC TEST CASE DEU PASS! <<<");
        else
            $display("  >>> KET LUAN: PHAT HIEN CO TEST CASE THAT BAI (FAIL)! <<<");
        $display("============================================================\n");

        $finish;
    end

endmodule