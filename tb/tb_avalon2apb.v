`timescale 1ns/1ps

module tb_avalon2apb;

    reg         clk;
    reg         rst_n;

    // Avalon Master side signals (emulating Nios V)
    reg         avl_chipselect;
    reg         avl_read;
    reg         avl_write;
    reg  [11:0] avl_address;
    reg  [31:0] avl_writedata;
    reg  [3:0]  avl_byteenable;
    wire [31:0] avl_readdata;
    wire        avl_waitrequest;
    wire [1:0]  avl_response;

    // APB interconnect wires (avalon2apb <-> apb_slave)
    wire        pclk;
    wire        preset_n;
    wire        psel;
    wire        penable;
    wire        pwrite;
    wire [11:0] paddr;
    wire [31:0] pwdata;
    wire        pready;
    wire        pslverr;
    wire [31:0] prdata;

    // apb_slave <-> uart_regs wires
    wire        reg_en;
    wire [11:0] reg_paddr;
    wire [31:0] reg_pwdata;
    wire        reg_pwrite;
    wire        write_en;
    wire        read_en;
    wire [31:0] reg_prdata;

    // UART peripheral side
    wire [7:0]  tx_data;
    wire [1:0]  data_bit_num;
    wire        stop_bit_num;
    wire        parity_en;
    wire        parity_type;
    wire        start_tx;
    wire [1:0]  baud_sel;

    reg         tx_done;
    reg         rx_done;
    reg         error;
    reg  [31:0] rx_data;

    // -------------------------------------------------------------------------
    // 1. Instantiate avalon2apb Bridge
    // -------------------------------------------------------------------------
    avalon2apb #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32),
        .USE_CHIPSELECT(0),
        .ADDR_MODE(0)
    ) u_avalon2apb (
        .clk             (clk),
        .reset_n         (rst_n),
        .avl_chipselect  (avl_chipselect),
        .avl_read        (avl_read),
        .avl_write       (avl_write),
        .avl_address     (avl_address),
        .avl_writedata   (avl_writedata),
        .avl_byteenable  (avl_byteenable),
        .avl_readdata    (avl_readdata),
        .avl_waitrequest (avl_waitrequest),
        .avl_response    (avl_response),
        .pclk            (pclk),
        .preset_n        (preset_n),
        .psel            (psel),
        .penable         (penable),
        .pwrite          (pwrite),
        .paddr           (paddr),
        .pwdata          (pwdata),
        .pready          (pready),
        .pslverr         (pslverr),
        .prdata          (prdata)
    );

    // -------------------------------------------------------------------------
    // 2. Instantiate apb_slave
    // -------------------------------------------------------------------------
    apb_slave u_apb_slave (
        .pclk       (pclk),
        .preset_n   (preset_n),
        .psel       (psel),
        .penable    (penable),
        .pwrite     (pwrite),
        .paddr      (paddr),
        .pwdata     (pwdata),
        .pready     (pready),
        .pslverr    (pslverr),
        .prdata     (prdata),
        .reg_en     (reg_en),
        .reg_paddr  (reg_paddr),
        .reg_pwdata (reg_pwdata),
        .reg_pwrite (reg_pwrite),
        .write_en   (write_en),
        .read_en    (read_en),
        .reg_prdata (reg_prdata)
    );

    // -------------------------------------------------------------------------
    // 3. Instantiate uart_regs
    // -------------------------------------------------------------------------
    uart_regs u_uart_regs (
        .clk          (clk),
        .rst_n        (rst_n),
        .reg_en       (reg_en),
        .paddr        (reg_paddr),
        .pwdata       (reg_pwdata),
        .pwrite       (reg_pwrite),
        .write_en     (write_en),
        .read_en      (read_en),
        .prdata       (reg_prdata),
        .tx_data      (tx_data),
        .data_bit_num (data_bit_num),
        .stop_bit_num (stop_bit_num),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .start_tx     (start_tx),
        .baud_sel     (baud_sel),
        .tx_done      (tx_done),
        .rx_done      (rx_done),
        .error        (error),
        .rx_data      (rx_data)
    );

    // Clock generator (50MHz -> 20ns period)
    always #10 clk = ~clk;

    // -------------------------------------------------------------------------
    // Nios V Emulation Tasks (Avalon-MM Master Read / Write)
    // -------------------------------------------------------------------------
    task nios_write(input [11:0] addr, input [31:0] data, output [1:0] resp);
        begin
            @(posedge clk);
            avl_address    <= addr;
            avl_writedata  <= data;
            avl_write      <= 1'b1;
            avl_read       <= 1'b0;
            avl_chipselect <= 1'b1;

            @(posedge clk);
            while (avl_waitrequest) begin
                @(posedge clk);
            end

            // In ST_ACCESS cycle when waitrequest == 0
            #1;
            resp = avl_response;
            avl_write      <= 1'b0;
            avl_chipselect <= 1'b0;
            @(posedge clk);
        end
    endtask

    task nios_read(input [11:0] addr, output [31:0] data, output [1:0] resp);
        begin
            @(posedge clk);
            avl_address    <= addr;
            avl_read       <= 1'b1;
            avl_write      <= 1'b0;
            avl_chipselect <= 1'b1;

            @(posedge clk);
            while (avl_waitrequest) begin
                @(posedge clk);
            end

            // In ST_ACCESS cycle when waitrequest == 0: data is stable
            #1;
            data = avl_readdata;
            resp = avl_response;
            avl_read       <= 1'b0;
            avl_chipselect <= 1'b0;
            @(posedge clk);
        end
    endtask

    reg [31:0] rd_data;
    reg [1:0]  resp;

    initial begin
        clk            = 0;
        rst_n          = 0;
        avl_chipselect = 0;
        avl_read       = 0;
        avl_write      = 0;
        avl_address    = 0;
        avl_writedata  = 0;
        avl_byteenable = 4'b1111;
        tx_done        = 0; // Output tu tx_uart mac dinh la 0, chi phat xung 1 chu ky khi xong
        rx_done        = 1; // IDLE
        error          = 0;
        rx_data        = 32'h0;

        // Reset system
        #40;
        rst_n = 1;
        #20;

        $display("=========================================================");
        $display("   TESTBENCH: AVALON2APB BRIDGE INTERFACING WITH NIOS V  ");
        $display("=========================================================");

        // Test 1: Write to CFG register when UART is IDLE
        $display("\n[TEST 1] Nios V writes to CFG (0x08) with data 0x3A");
        nios_write(12'h08, 32'h3A, resp);
        if (resp == 2'b00) begin
            $display("--> [PASS] Write CFG succeeded with response OKAY (0b00)");
        end else begin
            $fatal(1, "--> [FAIL] Expected OKAY, got resp = %b", resp);
        end

        // Test 2: Read back from CFG register
        $display("\n[TEST 2] Nios V reads from CFG (0x08)");
        nios_read(12'h08, rd_data, resp);
        if (rd_data == 32'h3A && resp == 2'b00) begin
            $display("--> [PASS] Read back CFG correctly: 0x%08X (Expected: 0x0000003A)", rd_data);
        end else begin
            $fatal(1, "--> [FAIL] Read CFG failed: data=0x%08X, resp=%b", rd_data, resp);
        end

        // Test 3: Write to TX register (0x00) with data 0x55
        $display("\n[TEST 3] Nios V writes to TX Data Reg (0x00) with 0x55");
        nios_write(12'h00, 32'h55, resp);
        if (tx_data == 8'h55 && resp == 2'b00) begin
            $display("--> [PASS] TX data register received byte: 0x%02X", tx_data);
        end else begin
            $fatal(1, "--> [FAIL] TX data mismatch: tx_data=0x%02X, resp=%b", tx_data, resp);
        end

        // Test 4: Write to CFG register when TX is BUSY -> Expect SLVERR
        $display("\n[TEST 4] UART TX busy (start_tx=1, tx_done_latch=0). Nios V attempts write CFG = 0x7F");
        nios_write(12'h0C, 32'h01, resp); // Start TX -> TX busy

        nios_write(12'h08, 32'h7F, resp);
        if (resp == 2'b10) begin
            $display("--> [PASS] avl_response correctly returned SLVERR (0b10) on illegal write!");
        end else begin
            $fatal(1, "--> [FAIL] Expected SLVERR (0b10), got %b", resp);
        end

        // Verify CFG was not corrupted
        nios_read(12'h08, rd_data, resp);
        if (rd_data == 32'h3A && resp == 2'b00) begin
            $display("--> [PASS] CFG register kept previous value 0x3A, write protected!");
        end else begin
            $fatal(1, "--> [FAIL] CFG register corrupted: 0x%08X", rd_data);
        end

        @(posedge clk);
        tx_done = 1; // 1-cycle Mealy pulse on tx_done
        @(posedge clk);
        tx_done = 0;
        @(posedge clk);

        // Test 5: Back-to-back operations on TX Data Register (0x00)
        $display("\n[TEST 5] Back-to-back writes and reads to TX register (0x00)");
        nios_write(12'h00, 32'h000000A5, resp);
        nios_read(12'h00, rd_data, resp);
        if (rd_data == 32'hA5 && resp == 2'b00) begin
            $display("--> [PASS] Back-to-back write/read succeeded: 0x%08X", rd_data);
        end else begin
            $fatal(1, "--> [FAIL] Back-to-back failed: rd_data=0x%08X, resp=%b", rd_data, resp);
        end

        $display("\n=========================================================");
        $display("   ALL AVALON2APB BRIDGE TESTS PASSED SUCCESSFULLY!     ");
        $display("=========================================================\n");

        #100;
        $finish;
    end

endmodule
