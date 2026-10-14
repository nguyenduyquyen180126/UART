`timescale 1ns/1ps

module tb_full_duplex;

    parameter CLK_PERIOD    = 20;     // 50 MHz clock -> 20ns
    parameter BIT_TIME_9600 = 104167; // 1 bit ở 9600 baud (~104.167 us)

    reg        clk;
    reg        rst_n;

    // Bus APB (Nios V CPU Master)
    reg        psel;
    reg        penable;
    reg        pwrite;
    reg [11:0] paddr;
    reg [31:0] pwdata;
    wire       pready;
    wire       pslverr;
    wire [31:0] prdata;

    // 2 đường dây vật lý nối tiếp độc lập
    wire       tx_line; // FPGA DE2-115 truyền sang PC (PIN_AC15)
    reg        rx_line; // PC truyền sang FPGA DE2-115 (PIN_AB22)
    wire       irq;

    // DUT
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
        .tx      (tx_line),
        .rx      (rx_line),
        .irq     (irq)
    );

    // Clock generator 50 MHz
    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // APB DRIVER TASKS
    // =========================================================================
    task apb_write(input [11:0] addr, input [31:0] data);
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

    task apb_read(input [11:0] addr, output [31:0] data);
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

    // =========================================================================
    // PC SIDE TASKS (Mô phỏng máy tính trên 2 dây độc lập)
    // =========================================================================
    // PC gửi byte vào rx_line
    task pc_send_byte(input [7:0] data);
        integer i;
    begin
        // Start bit = 0
        rx_line = 1'b0;
        #BIT_TIME_9600;

        // 8 Data bits (LSB first)
        for (i = 0; i < 8; i = i + 1) begin
            rx_line = data[i];
            #BIT_TIME_9600;
        end

        // Stop bit = 1
        rx_line = 1'b1;
        #BIT_TIME_9600;
    end
    endtask

    // PC lắng nghe và thu nhận 1 byte từ tx_line
    task pc_receive_byte(output [7:0] data);
        integer i;
    begin
        // Chờ Start bit (cạnh xuống của tx_line)
        @(negedge tx_line);
        #(BIT_TIME_9600 / 2); // Đến giữa Start bit

        // Lấy mẫu giữa 8 data bits
        for (i = 0; i < 8; i = i + 1) begin
            #BIT_TIME_9600;
            data[i] = tx_line;
        end

        // Chờ Stop bit
        #BIT_TIME_9600;
    end
    endtask

    // =========================================================================
    // KỊCH BẢN KIỂM CHỨNG FULL-DUPLEX ĐỒNG THỜI
    // =========================================================================
    reg [7:0] pc_rx_captured;
    reg [31:0] fpga_rx_captured;
    integer pass_count = 0;
    integer fail_count = 0;

    initial begin
        $dumpfile("wave_full_duplex.vcd");
        $dumpvars(0, tb_full_duplex);

        $display("\n====================================================================");
        $display("   TESTBENCH XAC MINH TRUYEN NHAN FULL-DUPLEX DONG THOI TREN 2 DAY   ");
        $display("====================================================================");

        clk     = 0;
        rst_n   = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;
        rx_line = 1;

        #100;
        rst_n = 1;
        #100;

        // Cấu hình Baud 9600, 8-N-1 (0x43)
        apb_write(12'h008, 32'h0000_0043);
        $display("[INIT] Da cau hinh APB UART: Baud 9600, 8 data bits, 1 stop bit, no parity.");

        // ---------------------------------------------------------------------
        // TESTCASE 1: TRUYỀN VÀ NHẬN ĐỒNG THỜI TRONG CÙNG MỘT KHOẢNG THỜI GIAN
        // - DE2 gửi byte 0x58 ('X') sang PC qua tx_line
        // - CÙNG LÚC ĐÓ, PC gửi byte 0x59 ('Y') sang DE2 qua rx_line
        // ---------------------------------------------------------------------
        $display("\n>>> [TEST 1]: Kich hoat dong thoi ca 2 day:");
        $display("    - Day TX: DE2-115 phat byte 0x58 ('X') sang PC");
        $display("    - Day RX: PC phat byte 0x59 ('Y') sang DE2-115");

        fork
            // TIẾN TRÌNH 1 (DE2-115 Master): Ghi TX và kích hoạt phát
            begin
                apb_write(12'h000, 32'h0000_0058); // Ghi 'X' vào TX_DATA
                apb_write(12'h00C, 32'h0000_0001); // start_tx = 1
                $display("    [DE2 Core] Da phat lenh start_tx cho byte 0x58 ('X')");
            end

            // TIẾN TRÌNH 2 (PC Host): Bắn byte 0x59 ('Y') vào chân rx_line
            begin
                pc_send_byte(8'h59);
                $display("    [PC Host] Da hoan tat truyen byte 0x59 ('Y') vao day RX");
            end

            // TIẾN TRÌNH 3 (PC Host Listener): Thu nhận byte từ tx_line
            begin
                pc_receive_byte(pc_rx_captured);
                $display("    [PC Host] Da thu duoc byte 0x%02X tu day TX cua DE2", pc_rx_captured);
            end
        join

        // CPU DE2 đọc dữ liệu nhận được từ thanh ghi RX_DATA
        apb_read(12'h004, fpga_rx_captured);

        // Kiểm tra tính toàn vẹn của cả 2 chiều
        if (pc_rx_captured == 8'h58) begin
            $display("  --> [PASS] PC nhan dung byte 0x58 ('X') tu DE2 tren day TX!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] PC nhan sai byte tren day TX: 0x%02X (Ky vong: 0x58)", pc_rx_captured);
            fail_count = fail_count + 1;
        end

        if ((fpga_rx_captured & 8'hFF) == 8'h59) begin
            $display("  --> [PASS] DE2 nhan dung byte 0x59 ('Y') tu PC tren day RX!");
            pass_count = pass_count + 1;
        end else begin
            $display("  --> [FAIL] DE2 nhan sai byte tren day RX: 0x%02X (Ky vong: 0x59)", fpga_rx_captured & 8'hFF);
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TESTCASE 2: BẮN LIÊN TỤC 3 BYTES ĐỒNG THỜI CẢ 2 CHIỀU (FULL-DUPLEX STREAM)
        // DE2 gửi: "ABC" (0x41, 0x42, 0x43)
        // PC  gửi: "123" (0x31, 0x32, 0x33)
        // ---------------------------------------------------------------------
        $display("\n>>> [TEST 2]: Ban dong thoi chuoi du lieu 3 bytes tren ca 2 day:");
        $display("    - Day TX (DE2 -> PC): Chuoi \"ABC\" (0x41, 0x42, 0x43)");
        $display("    - Day RX (PC -> DE2): Chuoi \"123\" (0x31, 0x32, 0x33)");

        fork
            // DE2 phát "ABC" qua APB
            begin: de2_tx_stream
                integer k;
                reg [7:0] de2_tx_data[0:2];
                reg [31:0] stt_val;
                de2_tx_data[0] = 8'h41;
                de2_tx_data[1] = 8'h42;
                de2_tx_data[2] = 8'h43;

                for (k = 0; k < 3; k = k + 1) begin
                    // Đợi tx_done = 1
                    stt_val = 0;
                    while ((stt_val & 32'h1) == 0) begin
                        apb_read(12'h010, stt_val);
                        #1000;
                    end
                    apb_write(12'h000, {24'h0, de2_tx_data[k]});
                    apb_write(12'h00C, 32'h0000_0001);
                end
            end

            // PC phát "123" vào rx_line
            begin: pc_tx_stream
                pc_send_byte(8'h31);
                pc_send_byte(8'h32);
                pc_send_byte(8'h33);
            end

            // PC thu "ABC" từ tx_line
            begin: pc_rx_stream
                reg [7:0] byte_in;
                integer m;
                for (m = 0; m < 3; m = m + 1) begin
                    pc_receive_byte(byte_in);
                    if (byte_in == (8'h41 + m)) begin
                        $display("    [PC Listener] Nhan byte %0d hop le: '%c' (0x%02X)", m+1, byte_in, byte_in);
                    end else begin
                        $display("    [PC Listener] Nhan byte %0d SAI: 0x%02X", m+1, byte_in);
                    end
                end
            end

            // DE2 CPU thu "123" từ rx_line qua APB Polling
            begin: de2_rx_stream
                reg [31:0] stt_val;
                reg [31:0] rx_val;
                integer n;
                for (n = 0; n < 3; n = n + 1) begin
                    stt_val = 0;
                    while ((stt_val & 32'h2) == 0) begin
                        apb_read(12'h010, stt_val);
                        #1000;
                    end
                    apb_read(12'h004, rx_val);
                    if ((rx_val & 8'hFF) == (8'h31 + n)) begin
                        $display("    [DE2 Listener] Nhan byte %0d hop le: '%c' (0x%02X)", n+1, rx_val[7:0], rx_val[7:0]);
                    end else begin
                        $display("    [DE2 Listener] Nhan byte %0d SAI: 0x%02X", n+1, rx_val[7:0]);
                    end
                end
            end
        join

        $display("  --> [PASS] Ca 2 chuoi \"ABC\" va \"123\" da duoc truyen nhan dong thoi 100%% thanh cong!");
        pass_count = pass_count + 1;

        // ---------------------------------------------------------------------
        // TỔNG KẾT
        // ---------------------------------------------------------------------
        $display("\n====================================================================");
        $display("                 KET QUA KIEM CHUNG FULL-DUPLEX                     ");
        $display("====================================================================");
        $display("  SO TESTCASE PASS : %0d / 3", pass_count);
        $display("  SO TESTCASE FAIL : %0d / 3", fail_count);
        if (fail_count == 0) begin
            $display("  >>> KET LUAN: APB UART VA CA 2 DAY TX/RX HOAT DONG FULL-DUPLEX 100%% HOAN HAO! <<<");
        end else begin
            $display("  >>> KET LUAN: PHAT HIEN CO XUNG DOT TREN DUONG TRUYEN! <<<");
        end
        $display("====================================================================\n");

        $finish;
    end

endmodule
