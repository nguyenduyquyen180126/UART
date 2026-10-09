`timescale 1ns/1ps

module tb_uart_regs;

    reg         clk;
    reg         rst_n;
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [11:0] paddr;
    reg  [31:0] pwdata;
    wire        pready;
    wire        pslverr;
    wire [31:0] prdata;

    wire        reg_pread;
    wire        reg_pwrite;
    wire        reg_ack_err;
    wire [11:0] reg_paddr;
    wire [31:0] reg_pwdata;
    wire [31:0] reg_prdata;

    wire [7:0]  tx_data;
    wire [1:0]  data_bit_num;
    wire        stop_bit_num;
    wire        parity_en;
    wire        parity_type;
    wire        start_tx;
    wire [1:0]  baud_sel;

    reg         tx_done;
    reg         rx_done;
    reg         rx_busy;
    reg         error;
    reg  [31:0] rx_data;

    // APB Slave
    apb_slave u_apb_slave (
        .pclk        (clk),
        .preset_n    (rst_n),
        .psel        (psel),
        .penable     (penable),
        .pwrite      (pwrite),
        .paddr       (paddr),
        .pwdata      (pwdata),
        .pready      (pready),
        .pslverr     (pslverr),
        .prdata      (prdata),
        .reg_pread   (reg_pread),
        .reg_pwrite  (reg_pwrite),
        .reg_paddr   (reg_paddr),
        .reg_pwdata  (reg_pwdata),
        .reg_prdata  (reg_prdata),
        .reg_ack_err (reg_ack_err)
    );

    // UART Registers
    uart_regs u_uart_regs (
        .clk          (clk),
        .rst_n        (rst_n),
        .reg_pread    (reg_pread),
        .reg_pwrite   (reg_pwrite),
        .paddr        (reg_paddr),
        .pwdata       (reg_pwdata),
        .prdata       (reg_prdata),
        .reg_ack_err  (reg_ack_err),
        .tx_data      (tx_data),
        .data_bit_num (data_bit_num),
        .stop_bit_num (stop_bit_num),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .start_tx     (start_tx),
        .baud_sel     (baud_sel),
        .tx_done      (tx_done),
        .rx_done      (rx_done),
        .rx_busy      (rx_busy),
        .error        (error),
        .rx_data      (rx_data)
    );

    always #10 clk = ~clk;

    task apb_write(input [11:0] addr, input [31:0] data, output err);
        begin
            @(posedge clk);
            paddr   <= addr;
            pwdata  <= data;
            pwrite  <= 1'b1;
            psel    <= 1'b1;
            penable <= 1'b0;

            @(posedge clk);
            penable <= 1'b1;
            #1;
            err = pslverr;

            @(posedge clk);
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
        end
    endtask

    task apb_read(input [11:0] addr, output [31:0] data, output err);
        begin
            @(posedge clk);
            paddr   <= addr;
            pwrite  <= 1'b0;
            psel    <= 1'b1;
            penable <= 1'b0;

            @(posedge clk);
            penable <= 1'b1;
            #1;
            data = prdata;
            err  = pslverr;

            @(posedge clk);
            psel    <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    reg [31:0] rdata;
    reg        err;

    initial begin
        clk     = 0;
        rst_n   = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;
        tx_done = 0; // Output tu tx_uart mac dinh la 0, chi phat xung 1 chu ky khi xong
        rx_done = 0; // Xung Mealy khi nhan xong byte
        rx_busy = 0; // IDLE
        error   = 0;
        rx_data = 0;

        #40;
        rst_n = 1;
        #20;

        $display("=== STARTING UART_REGS PROTECTION TEST ===");

        // 1. Khi ca TX va RX deu IDLE sau reset (tx_done_latch=1, rx_busy=0) -> Ghi CFG thanh cong
        apb_write(12'h008, 32'h0000_003A, err);
        apb_read(12'h008, rdata, err);
        $display("[Test 1: IDLE] Ghi CFG = 0x3A | Doc lai: 0x%02X | Loi: %b", rdata[7:0], err);
        if (rdata[7:0] == 8'h3A && err == 0)
            $display("--> [PASS] Ghi CFG thanh cong khi UART IDLE!");
        else
            $fatal(1, "--> [FAIL] Khong ghi duoc CFG khi IDLE!");

        // 2. CPU ghi start_tx = 1 -> TX bat dau chay (co chot tx_done_latch = 0) -> Co tinh ghi CFG
        apb_write(12'h00C, 32'h0000_0001, err); // start_tx = 1
        $display("[Test 2: TX BUSY] Kich start_tx = 1 de bat dau truyen...");

        apb_write(12'h008, 32'h0000_007F, err);
        $display("[Test 2: TX BUSY] Co tinh ghi CFG = 0x7F | PSLVERR = %b", err);
        if (err == 1)
            $display("--> [PASS] apb_slave da bao PSLVERR = 1 khi TX dang chay!");
        else
            $fatal(1, "--> [FAIL] Khong bao loi khi TX dang chay!");

        // Co tinh ghi tiep ADDR_TX khi TX dang ban -> Mong doi PSLVERR = 1
        apb_write(12'h000, 32'h0000_00BE, err);
        $display("[Test 2: TX BUSY] Co tinh ghi TX_DATA = 0xBE khi dang truyen | PSLVERR = %b", err);
        if (err == 1)
            $display("--> [PASS] apb_slave da bao PSLVERR = 1, chan khong cho ghi TX data khi dang truyen!");
        else
            $fatal(1, "--> [FAIL] Khong bao loi khi ghi TX data luc TX dang chay!");

        // Doc lai de kiem tra gia tri CFG co bi thay doi khong
        apb_read(12'h008, rdata, err);
        $display("          Doc lai CFG: 0x%02X (Mong doi van la 0x3A, khong bi doi thanh 0x7F)", rdata[7:0]);
        if (rdata[7:0] == 8'h3A && err == 0)
            $display("--> [PASS] CFG van duoc bao ve nguyen ven, doc khong bi loi!");
        else
            $fatal(1, "--> [FAIL] CFG da bi ghi de bat hop le!");

        // 3. TX truyen xong: phat xung Mealy tx_done = 1 trong 1 chu ky clock -> co chot len 1
        @(posedge clk);
        tx_done = 1; // Xung Mealy tx_done 1 chu ky
        @(posedge clk);
        tx_done = 0;
        rx_busy = 1; // RX dang ban
        @(posedge clk);

        apb_write(12'h008, 32'h0000_0055, err);
        $display("[Test 3: RX BUSY] Co tinh ghi CFG = 0x55 | PSLVERR = %b", err);
        if (err == 1)
            $display("--> [PASS] apb_slave da bao PSLVERR = 1 khi RX dang chay!");
        else
            $fatal(1, "--> [FAIL] Khong bao loi khi RX dang chay!");

        apb_read(12'h008, rdata, err);
        if (rdata[7:0] == 8'h3A)
            $display("--> [PASS] CFG van giu nguyen 0x3A!");
        else
            $fatal(1, "--> [FAIL] CFG bi thay doi!");

        // 4. Khi ca hai quay ve IDLE
        @(posedge clk);
        rx_busy = 0; // RX quay ve IDLE
        @(posedge clk);
        apb_write(12'h008, 32'h0000_0012, err);
        apb_read(12'h008, rdata, err);
        $display("[Test 4: IDLE lai] Ghi CFG = 0x12 | Doc lai: 0x%02X | Loi: %b", rdata[7:0], err);
        if (rdata[7:0] == 8'h12 && err == 0)
            $display("--> [PASS] Ghi CFG thanh cong khi quay lai IDLE!");
        else
            $fatal(1, "--> [FAIL] Ghi that bai!");

        $display("=== TAT CA CAC TEST PASS HOAN TOAN! ===");
        $finish;
    end

endmodule
