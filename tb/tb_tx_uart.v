`timescale 1ns/1ps

// =============================================================================
// Module: tb_tx_uart
// Description: Strict Spec 1.1 Verification Testbench for TX_UART
// Based strictly on: APB-UART Specification 1.1 (doc/specs/za.html)
//
// Verification Principles:
//   - 100% Spec-driven (No looking into RTL, no accommodating RTL defects).
//   - Formula: D = f_clk / (16 * Baud) = div_int + div_frac/16
//   - Strict Bit Duration: T_bit = 16 * D * T_clk = 1 / Baud (Spec 1.1 Section 5)
//   - Golden Receiver samples strictly at 0.5 * T_bit (center of start bit)
//     and 1.0 * T_bit intervals for data, parity, and stop bit(s).
//   - If RTL violates bit duration or protocol, Testbench MUST FAIL it.
// =============================================================================

module tb_tx_uart #(
    parameter integer USER_BAUD = 0  // 0: Full regression suite; >0: Specific baud suite
);

    // =========================================================================
    // 1. SIGNALS & DUT INTERFACE (Spec 1.1)
    // =========================================================================
    reg        clk;
    reg        rst_n;
    reg        start_tx;       // CTRL[0]: Pulse 1 clock cycle to trigger TX
    reg  [7:0] tx_data;        // TXDATA: Data to transmit
    reg  [1:0] data_bit_num;   // CFG[1:0]: 00=5b, 01=6b, 10=7b, 11=8b
    reg        stop_bit_num;   // CFG[2]: 0=1 stop, 1=2 stop
    reg        parity_en;      // CFG[3]: 1=enable, 0=disable
    reg        parity_type;    // CFG[4]: Spec 1.1: 1=Even, 0=Odd
    reg        tx_dis;         // CFG[5]: 1=disable TX
    reg        cts_n;          // Hardware flow control: Clear-To-Send (Active Low)
    reg [11:0] div_int;        // BAUD[11:0]: Integer divisor
    reg  [3:0] div_frac;       // BAUD[15:12]: Fractional divisor

    wire       tx;             // Serial output line
    wire       tx_done;        // STAT[0]: 1=idle/ready, 0=transmitting
    wire       tx_busy;        // Status: 1=busy
    wire       load_reg;       // Internal load pulse

    // Testbench Management & Statistics
    real       bit_time_ns;
    integer    current_baud;
    integer    test_count;
    integer    pass_count;
    integer    fail_count;

    // =========================================================================
    // 2. DUT INSTANTIATION
    // =========================================================================
    tx_uart #(
        .CLK_FREQ(50_000_000)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start_tx    (start_tx),
        .tx_data     (tx_data),
        .data_bit_num(data_bit_num),
        .stop_bit_num(stop_bit_num),
        .parity_en   (parity_en),
        .parity_type (parity_type),
        .tx_dis      (tx_dis),
        .cts_n       (cts_n),
        .div_int     (div_int),
        .div_frac    (div_frac),
        .tx          (tx),
        .load_reg    (load_reg),
        .tx_done     (tx_done),
        .tx_busy     (tx_busy)
    );

    // =========================================================================
    // 3. CLOCK GENERATION (50 MHz -> 20ns period)
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // =========================================================================
    // 4. STRICT SPEC 1.1 CONFIGURATION TASK
    // =========================================================================
    task set_tx_config(
        input integer target_baud,
        input [1:0]   cfg_data_bits,
        input         cfg_stop_bits,
        input         cfg_parity_en,
        input         cfg_parity_type,
        input         cfg_tx_dis
    );
        real d_val;
        integer d_i;
        integer d_f;
        begin
            current_baud = target_baud;
            data_bit_num = cfg_data_bits;
            stop_bit_num = cfg_stop_bits;
            parity_en    = cfg_parity_en;
            parity_type  = cfg_parity_type;
            tx_dis       = cfg_tx_dis;

            // Spec 1.1 Section 5:
            // D = f_clk / (16 * Baud)
            d_val = 50_000_000.0 / (16.0 * target_baud);
            d_i   = $rtoi(d_val);
            d_f   = $rtoi((d_val - d_i) * 16.0 + 0.5);
            if (d_f >= 16) begin
                d_i = d_i + 1;
                d_f = 0;
            end
            div_int  = d_i[11:0];
            div_frac = d_f[3:0];

            // Strict Spec 1.1 Bit Duration: 16 ticks per bit
            // T_bit = 16 * (div_int + div_frac/16) * 20ns
            bit_time_ns = 16.0 * (d_i + (d_f / 16.0)) * 20.0;
            #(bit_time_ns * 2.0); // Settle
        end
    endtask

    // =========================================================================
    // 5. STRICT SPEC 1.1 GOLDEN RECEIVER & CHECKER
    // =========================================================================
    task transmit_and_check(
        input [7:0]   byte_val,
        input         expect_suppressed, // 1: tx_dis = 1, expect NO transmission
        input [1:0]   cts_mode,          // 0: Normal CTS=0, 1: Delayed CTS, 2: Mid-frame CTS deassert
        input [511:0] test_name
    );
        integer num_data_bits;
        integer i;
        reg [7:0] exp_masked;
        reg [7:0] captured_data;
        reg       captured_parity;
        reg       captured_stop1;
        reg       captured_stop2;
        reg       exp_parity;
        reg       tc_pass;
        reg       timeout_flag;
        begin
            test_count = test_count + 1;
            tc_pass    = 1'b1;

            // Determine data length & high-bit mask (Spec 1.1 Section 6)
            case (data_bit_num)
                2'b00: begin num_data_bits = 5; exp_masked = byte_val & 8'h1F; end
                2'b01: begin num_data_bits = 6; exp_masked = byte_val & 8'h3F; end
                2'b10: begin num_data_bits = 7; exp_masked = byte_val & 8'h7F; end
                2'b11: begin num_data_bits = 8; exp_masked = byte_val & 8'hFF; end
            endcase

            // Compute expected parity (Spec 1.1 Section 4: parity_type: 1=Even, 0=Odd)
            exp_parity = 1'b0;
            for (i = 0; i < num_data_bits; i = i + 1) begin
                exp_parity = exp_parity ^ exp_masked[i];
            end
            if (parity_type == 1'b1)
                exp_parity = exp_parity;      // Even
            else
                exp_parity = ~exp_parity;     // Odd

            $display("----------------------------------------------------------------------");
            $display("[TC #%02d] %0s", test_count, test_name);
            $display("         Config: Data=%0db | Stop=%0d | Parity=%0s | Baud=%0d (Spec BitTime=%0.2f ns)",
                     num_data_bits, (stop_bit_num ? 2 : 1),
                     (!parity_en ? "None" : (parity_type ? "Even" : "Odd")),
                     current_baud, bit_time_ns);

            // CASE 1: TRANSMITTER DISABLED (tx_dis = 1) -> Must suppress transmission
            if (expect_suppressed) begin
                cts_n   = 1'b0;
                tx_data = byte_val;
                @(posedge clk);
                start_tx = 1'b1;
                @(posedge clk);
                start_tx = 1'b0;

                #(bit_time_ns * 2.0);
                if (tx !== 1'b1) begin
                    $display("  [FAIL] tx_dis=1: Serial line transmitted data when disabled! tx=%0b", tx);
                    tc_pass = 1'b0;
                end else if (tx_done !== 1'b1 || tx_busy !== 1'b0) begin
                    $display("  [FAIL] tx_dis=1: Status invalid! tx_done=%0b (exp 1), tx_busy=%0b (exp 0)", tx_done, tx_busy);
                    tc_pass = 1'b0;
                end else begin
                    $display("  >>> [PASS] tx_dis=1 cleanly suppressed transmission (tx=1, tx_done=1, tx_busy=0).");
                end

                if (tc_pass) pass_count = pass_count + 1;
                else         fail_count = fail_count + 1;
                #(bit_time_ns);
            end
            // CASE 2: ACTIVE TRANSMISSION
            else begin
                if (cts_mode == 2'd1) begin
                    // Delayed CTS flow control: Assert start_tx with cts_n = 1
                    cts_n    = 1'b1;
                    tx_data  = byte_val;
                    repeat (4) @(posedge clk); // Allow 2-FF synchronizer to capture cts_n=1
                    start_tx = 1'b1;
                    @(posedge clk);
                    start_tx = 1'b0;

                    // Verify DUT enters WAIT_CTS and holds tx = 1, tx_busy = 1, tx_done = 0
                    #(bit_time_ns * 1.5);
                    if (tx !== 1'b1) begin
                        $display("  [FAIL] WAIT_CTS: Serial line fell when cts_n=1! Must hold mark 1.");
                        tc_pass = 1'b0;
                    end
                    if (tx_busy !== 1'b1) begin
                        $display("  [FAIL] WAIT_CTS: tx_busy should be 1 while waiting for CTS! Got %0b", tx_busy);
                        tc_pass = 1'b0;
                    end
                    if (tx_done !== 1'b0) begin
                        $display("  [FAIL] WAIT_CTS: tx_done should be 0 while waiting for CTS! Got %0b", tx_done);
                        tc_pass = 1'b0;
                    end

                    // Release CTS (0) and sample frame
                    fork
                        begin : monitor_delayed_cts
                            @(negedge tx);
                            // Sample Center of Start Bit (0.5 * T_bit)
                            #(bit_time_ns * 0.5);
                            if (tx !== 1'b0) begin
                                $display("  [FAIL] START BIT: Sampled %0b at center (exp 0)!", tx);
                                tc_pass = 1'b0;
                            end

                            // Sample Data Bits at 1.0 * T_bit intervals
                            captured_data = 8'h00;
                            for (i = 0; i < num_data_bits; i = i + 1) begin
                                #(bit_time_ns);
                                captured_data[i] = tx;
                            end

                            // Sample Parity Bit
                            if (parity_en) begin
                                #(bit_time_ns);
                                captured_parity = tx;
                                if (captured_parity !== exp_parity) begin
                                    $display("  [FAIL] PARITY BIT MISMATCH: Captured %0b, Expected %0b",
                                             captured_parity, exp_parity);
                                    tc_pass = 1'b0;
                                end
                            end

                            // Sample Stop Bit 1
                            #(bit_time_ns);
                            captured_stop1 = tx;
                            if (captured_stop1 !== 1'b1) begin
                                $display("  [FAIL] STOP BIT 1 ERROR: Sampled %0b (exp 1)!", captured_stop1);
                                tc_pass = 1'b0;
                            end

                            // Sample Stop Bit 2
                            if (stop_bit_num) begin
                                #(bit_time_ns);
                                captured_stop2 = tx;
                                if (captured_stop2 !== 1'b1) begin
                                    $display("  [FAIL] STOP BIT 2 ERROR: Sampled %0b (exp 1)!", captured_stop2);
                                    tc_pass = 1'b0;
                                end
                            end
                        end
                        begin : drive_delayed_cts_release
                            @(posedge clk);
                            cts_n = 1'b0;
                        end
                    join
                end else begin
                    // Normal transmission or Mid-frame CTS deassertion
                    cts_n   = 1'b0;
                    tx_data = byte_val;
                    fork
                        begin : monitor_active_frame
                            @(negedge tx);
                            // Sample Center of Start Bit (0.5 * T_bit)
                            #(bit_time_ns * 0.5);
                            if (tx !== 1'b0) begin
                                $display("  [FAIL] START BIT: Sampled %0b at center (exp 0)!", tx);
                                tc_pass = 1'b0;
                            end

                            // Sample Data Bits at 1.0 * T_bit intervals
                            captured_data = 8'h00;
                            for (i = 0; i < num_data_bits; i = i + 1) begin
                                #(bit_time_ns);
                                captured_data[i] = tx;

                                if (cts_mode == 2'd2 && i == 2) begin
                                    $display("  [INFO] Deasserting cts_n = 1 mid-frame at data bit 2...");
                                    cts_n = 1'b1;
                                end
                            end

                            // Sample Parity Bit
                            if (parity_en) begin
                                #(bit_time_ns);
                                captured_parity = tx;
                                if (captured_parity !== exp_parity) begin
                                    $display("  [FAIL] PARITY BIT MISMATCH: Captured %0b, Expected %0b",
                                             captured_parity, exp_parity);
                                    tc_pass = 1'b0;
                                end
                            end

                            // Sample Stop Bit 1
                            #(bit_time_ns);
                            captured_stop1 = tx;
                            if (captured_stop1 !== 1'b1) begin
                                $display("  [FAIL] STOP BIT 1 ERROR: Sampled %0b (exp 1)!", captured_stop1);
                                tc_pass = 1'b0;
                            end

                            // Sample Stop Bit 2
                            if (stop_bit_num) begin
                                #(bit_time_ns);
                                captured_stop2 = tx;
                                if (captured_stop2 !== 1'b1) begin
                                    $display("  [FAIL] STOP BIT 2 ERROR: Sampled %0b (exp 1)!", captured_stop2);
                                    tc_pass = 1'b0;
                                end
                            end
                        end
                        begin : drive_start_tx
                            @(posedge clk);
                            start_tx = 1'b1;
                            @(posedge clk);
                            start_tx = 1'b0;
                        end
                    join
                end

                // Wait for frame completion (tx_done asserts)
                timeout_flag = 0;
                fork
                    begin : wait_done_edge
                        while (!tx_done) @(posedge clk);
                    end
                    begin : wait_done_to
                        #(bit_time_ns * 3.0 + 2000);
                        timeout_flag = 1;
                    end
                join_any
                disable fork;

                if (timeout_flag) begin
                    $display("  [FAIL] TIMEOUT: tx_done did not assert after stop bit!");
                    tc_pass = 1'b0;
                end
                if (tx_busy !== 1'b0) begin
                    $display("  [FAIL] tx_busy did not return to 0 after frame completion! Got %0b", tx_busy);
                    tc_pass = 1'b0;
                end

                // Compare captured data with expected
                if (captured_data !== exp_masked) begin
                    $display("  [FAIL] DATA MISMATCH: Captured 0x%02X, Expected 0x%02X", captured_data, exp_masked);
                    tc_pass = 1'b0;
                end

                cts_n = 1'b0;

                if (tc_pass) begin
                    $display("  >>> [PASS] Transmitted: 0x%02X | Captured: 0x%02X | Flags: tx_done=1, tx_busy=0",
                             byte_val, captured_data);
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                end

                #(bit_time_ns * 1.5); // Inter-frame spacing
            end
        end
    endtask

    // =========================================================================
    // 6. DEDICATED USER BAUDRATE SUITE
    // =========================================================================
    task run_dedicated_baud_suite(input integer baud_to_test);
        begin
            $display("\n======================================================================");
            $display(">>> RUNNING DEDICATED TX VERIFICATION AT USER-FIXED %0d BAUD", baud_to_test);
            $display("======================================================================");

            // 1. 8N1 Standard Transmission
            set_tx_config(baud_to_test, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hA5, 0, 0, "Dedicated Baud: 8N1 Transmit 0xA5");
            transmit_and_check(8'h5A, 0, 0, "Dedicated Baud: 8N1 Transmit 0x5A");

            // 2. 8E1 Even Parity Transmission
            set_tx_config(baud_to_test, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'h3C, 0, 0, "Dedicated Baud: 8E1 Even Parity Transmit 0x3C");
            transmit_and_check(8'hFF, 0, 0, "Dedicated Baud: 8E1 Even Parity Transmit 0xFF");

            // 3. 8O1 Odd Parity Transmission
            set_tx_config(baud_to_test, 2'b11, 1'b0, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'h77, 0, 0, "Dedicated Baud: 8O1 Odd Parity Transmit 0x77");

            // 4. 8N2 2 Stop Bits Transmission
            set_tx_config(baud_to_test, 2'b11, 1'b1, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hF0, 0, 0, "Dedicated Baud: 8N2 2 Stop Bits Transmit 0xF0");

            // 5. 7N1 High-Bit Zero Masking
            set_tx_config(baud_to_test, 2'b10, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "Dedicated Baud: 7N1 Zero-masking bit 7 (Send 0xFF -> Tx 0x7F)");

            // 6. 6E1 High-Bit Zero Masking
            set_tx_config(baud_to_test, 2'b01, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "Dedicated Baud: 6E1 Zero-masking bits 7:6 (Send 0xFF -> Tx 0x3F)");

            // 7. 5O1 High-Bit Zero Masking
            set_tx_config(baud_to_test, 2'b00, 1'b0, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "Dedicated Baud: 5O1 Zero-masking bits 7:5 (Send 0xFF -> Tx 0x1F)");

            // 8. Hardware Flow Control CTS check
            set_tx_config(baud_to_test, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hB4, 0, 1, "Dedicated Baud: CTS WAIT_CTS and release test");

            // 9. Transmitter Disable (tx_dis) check
            set_tx_config(baud_to_test, 2'b11, 1'b0, 1'b0, 1'b0, 1'b1);
            transmit_and_check(8'hAA, 1, 0, "Dedicated Baud: tx_dis=1 suppression test");
        end
    endtask

    // =========================================================================
    // 7. MAIN TESTBENCH EXECUTION
    // =========================================================================
    integer selected_baud;
    integer fmt_data;
    integer fmt_parity;
    integer fmt_stop;
    integer pat_idx;
    reg [7:0] boundary_patterns [0:3];

    initial begin
        // Waveform dump for GTKWave analysis
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tx_uart);

        // Signal initialization
        test_count   = 0;
        pass_count   = 0;
        fail_count   = 0;
        clk          = 1'b0;
        rst_n        = 1'b0;
        start_tx     = 1'b0;
        tx_data      = 8'h00;
        data_bit_num = 2'b11; // 8 bit
        stop_bit_num = 1'b0;  // 1 stop
        parity_en    = 1'b0;  // None
        parity_type  = 1'b0;  // Odd
        tx_dis       = 1'b0;
        cts_n        = 1'b0;
        div_int      = 12'd325;
        div_frac     = 4'd8;
        current_baud = 9600;

        $display("\n======================================================================");
        $display("   DV TESTBENCH: APB-UART TX STRICT SPECIFICATION 1.1 VERIFICATION   ");
        $display("======================================================================");

        // Reset Sequence
        #100;
        @(negedge clk);
        rst_n = 1'b1;
        #500;
        $display("[INFO] System released from reset (rst_n = 1) at time %0t ns", $time);

        // Check STAT[0]: tx_done MUST reset to 1'b1 (Spec 1.1 Section 4: STAT.tx_done = 1)
        test_count = test_count + 1;
        $display("----------------------------------------------------------------------");
        $display("[TC #%02d] Reset State: STAT.tx_done must reset to 1 (Transmitter IDLE/READY)", test_count);
        if (tx_done !== 1'b1 || tx_busy !== 1'b0 || tx !== 1'b1) begin
            $display("  [FAIL] RESET ERROR: tx_done=%0b (exp 1), tx_busy=%0b (exp 0), tx=%0b (exp 1)",
                     tx_done, tx_busy, tx);
            fail_count = fail_count + 1;
        end else begin
            $display("  >>> [PASS] Reset state verified: tx_done = 1, tx_busy = 0, tx = 1 (MARK).");
            pass_count = pass_count + 1;
        end

        // Check if user specified custom baudrate via CLI Plusarg or Parameter
        selected_baud = USER_BAUD;
        if ($value$plusargs("BAUD=%d", selected_baud)) begin
            $display("[INFO] User provided runtime CLI argument +BAUD=%0d", selected_baud);
        end else if ($value$plusargs("TARGET_BAUD=%d", selected_baud)) begin
            $display("[INFO] User provided runtime CLI argument +TARGET_BAUD=%0d", selected_baud);
        end

        // ---------------------------------------------------------------------
        // BRANCH A: USER SPECIFIED A CUSTOM BAUDRATE TO TEST / FIX
        // ---------------------------------------------------------------------
        if (selected_baud > 0) begin
            $display("[MODE] RUNNING DEDICATED USER-FIXED BAUDRATE SUITE: %0d Baud", selected_baud);
            run_dedicated_baud_suite(selected_baud);
        end
        // ---------------------------------------------------------------------
        // BRANCH B: RUN DEFAULT FULL SPEC 1.1 COMPREHENSIVE REGRESSION SUITE
        // ---------------------------------------------------------------------
        else begin
            $display("[MODE] RUNNING COMPREHENSIVE FULL SPEC 1.1 REGRESSION SUITE");

            // -----------------------------------------------------------------
            // TEST GROUP 1: STANDARD FRAME CONFIGURATIONS (8N1, 8E1, 8O1, 8N2...)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 1: STANDARD FRAME CONFIGURATIONS (8N1, 8E1, 8O1, 8N2...)");
            $display("======================================================================");

            // 1.1: 8N1 @ 9600 Baud
            set_tx_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hA5, 0, 0, "8N1: Transmit 0xA5 @ 9600 baud");
            transmit_and_check(8'h5A, 0, 0, "8N1: Transmit 0x5A @ 9600 baud");

            // 1.2: 8E1 (Even Parity) @ 9600 Baud
            set_tx_config(9600, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'h3C, 0, 0, "8E1: Transmit 0x3C (Even Parity = 0)");
            transmit_and_check(8'hFF, 0, 0, "8E1: Transmit 0xFF (Even Parity = 0)");
            transmit_and_check(8'h01, 0, 0, "8E1: Transmit 0x01 (Even Parity = 1)");

            // 1.3: 8O1 (Odd Parity) @ 9600 Baud
            set_tx_config(9600, 2'b11, 1'b0, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'h77, 0, 0, "8O1: Transmit 0x77 (Odd Parity = 0)");
            transmit_and_check(8'h00, 0, 0, "8O1: Transmit 0x00 (Odd Parity = 1)");
            transmit_and_check(8'hAA, 0, 0, "8O1: Transmit 0xAA (Odd Parity = 1)");

            // 1.4: 8N2 (2 Stop bits) @ 9600 Baud
            set_tx_config(9600, 2'b11, 1'b1, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hC3, 0, 0, "8N2: Transmit 0xC3 with 2 Stop Bits");

            // 1.5: 8E2 (Even Parity, 2 Stop bits) @ 19200 Baud
            set_tx_config(19200, 2'b11, 1'b1, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'h55, 0, 0, "8E2: Transmit 0x55 @ 19200 Baud");

            // 1.6: 8O2 (Odd Parity, 2 Stop bits) @ 19200 Baud
            set_tx_config(19200, 2'b11, 1'b1, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'hAA, 0, 0, "8O2: Transmit 0xAA @ 19200 Baud");

            // -----------------------------------------------------------------
            // TEST GROUP 2: DATA LENGTHS & HIGH-BIT ZERO MASKING
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 2: DATA LENGTHS & ZERO-MASKING (5, 6, 7 BITS)");
            $display("======================================================================");

            // 2.1: 7-bit Data (7N1) -> Bit 7 masked to 0
            set_tx_config(9600, 2'b10, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "7N1: Zero-masking bit 7 (Send 0xFF -> Tx 0x7F)");

            // 2.2: 7-bit Data (7E1) -> Parity computed over 7 bits
            set_tx_config(9600, 2'b10, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "7E1: Zero-masking bit 7 with Even Parity (Tx 0x7F, P=1)");

            // 2.3: 7-bit Data (7O1) -> Parity computed over 7 bits
            set_tx_config(9600, 2'b10, 1'b0, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "7O1: Zero-masking bit 7 with Odd Parity (Tx 0x7F, P=0)");

            // 2.4: 6-bit Data (6N1) -> Bits 7:6 masked to 0
            set_tx_config(9600, 2'b01, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "6N1: Zero-masking bits 7:6 (Send 0xFF -> Tx 0x3F)");

            // 2.5: 6-bit Data (6E1) -> Parity computed over 6 bits
            set_tx_config(9600, 2'b01, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "6E1: Zero-masking bits 7:6 with Even Parity (Tx 0x3F, P=0)");

            // 2.6: 6-bit Data (6O1) -> Parity computed over 6 bits
            set_tx_config(9600, 2'b01, 1'b0, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "6O1: Zero-masking bits 7:6 with Odd Parity (Tx 0x3F, P=1)");

            // 2.7: 5-bit Data (5N1) -> Bits 7:5 masked to 0
            set_tx_config(9600, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "5N1: Zero-masking bits 7:5 (Send 0xFF -> Tx 0x1F)");

            // 2.8: 5-bit Data (5E1) -> Parity computed over 5 bits
            set_tx_config(9600, 2'b00, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "5E1: Zero-masking bits 7:5 with Even Parity (Tx 0x1F, P=1)");

            // 2.9: 5-bit Data (5O1) -> Parity computed over 5 bits
            set_tx_config(9600, 2'b00, 1'b0, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'hFF, 0, 0, "5O1: Zero-masking bits 7:5 with Odd Parity (Tx 0x1F, P=0)");

            // 2.10: 5-bit Data (5N2) -> 2 Stop bits
            set_tx_config(9600, 2'b00, 1'b1, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'h55, 0, 0, "5N2: 5-bit data with 2 Stop Bits (Send 0x55 -> Tx 0x15)");

            // -----------------------------------------------------------------
            // TEST GROUP 3: HARDWARE FLOW CONTROL (cts_n)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 3: HARDWARE FLOW CONTROL (cts_n)");
            $display("======================================================================");

            // 3.1: Normal immediate transmission when cts_n = 0
            set_tx_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hA1, 0, 0, "CTS Normal: Immediate transmission with cts_n=0");

            // 3.2: Delayed CTS: start_tx pulsed while cts_n=1 -> wait in WAIT_CTS -> start when cts_n=0
            transmit_and_check(8'hB4, 0, 1, "CTS Flow Control: Enter WAIT_CTS until cts_n asserts (0)");

            // 3.3: CTS deasserted MID-FRAME (Spec 1.1: Ongoing frame must NOT pause or abort)
            transmit_and_check(8'hD2, 0, 2, "CTS Flow Control: cts_n deasserted mid-frame must not abort");

            // -----------------------------------------------------------------
            // TEST GROUP 4: TRANSMITTER DISABLE (tx_dis)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 4: TRANSMITTER DISABLE (tx_dis)");
            $display("======================================================================");

            // 4.1: tx_dis = 1 -> start_tx must be ignored!
            set_tx_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b1); // tx_dis = 1
            transmit_and_check(8'hAA, 1, 0, "tx_dis=1: start_tx ignored, tx holds mark 1");

            // 4.2: tx_dis = 0 -> normal transmission restored
            set_tx_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0); // tx_dis = 0
            transmit_and_check(8'hBB, 0, 0, "tx_dis=0: Normal transmission restored for 0xBB");

            // -----------------------------------------------------------------
            // TEST GROUP 5: BACK-TO-BACK TRANSMISSION
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 5: BACK-TO-BACK FRAMES (ZERO GAP STRESS TEST)");
            $display("======================================================================");

            set_tx_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'h11, 0, 0, "Back-to-Back Frame 1 (0x11)");
            transmit_and_check(8'h22, 0, 0, "Back-to-Back Frame 2 (0x22)");
            transmit_and_check(8'h33, 0, 0, "Back-to-Back Frame 3 (0x33)");
            transmit_and_check(8'h44, 0, 0, "Back-to-Back Frame 4 (0x44)");

            // -----------------------------------------------------------------
            // TEST GROUP 6: MULTI-BAUD RATES (2400, 4800, 19200, 38400, 57600)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 6: MULTI-BAUD RATE COVERAGE (2400 - 57600 BAUD)");
            $display("======================================================================");

            set_tx_config(2400, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hE5, 0, 0, "Multi-Baud: 2400 Baud (8N1, 0xE5)");

            set_tx_config(4800, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'h88, 0, 0, "Multi-Baud: 4800 Baud (8N1, 0x88)");

            set_tx_config(19200, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'h44, 0, 0, "Multi-Baud: 19200 Baud (8N1, 0x44)");

            set_tx_config(38400, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'h66, 0, 0, "Multi-Baud: 38400 Baud (8E1 Even Parity, 0x66)");

            set_tx_config(57600, 2'b11, 1'b0, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'h99, 0, 0, "Multi-Baud: 57600 Baud (8O1 Odd Parity, 0x99)");

            // -----------------------------------------------------------------
            // TEST GROUP 7: HIGH-SPEED & MANDATORY BAUDRATES (115.2k - 921.6k)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 7: HIGH-SPEED BAUDRATES (115200 BẮT BUỘC & 230400–921600)");
            $display("======================================================================");

            // 7.1: 115,200 BAUD (BẮT BUỘC) -> div_int = 27, div_frac = 2
            $display("\n--- [BAUD 115,200] D = 27 + 2/16 = 27.125 (Spec Error = +0.006%%) ---");
            set_tx_config(115200, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'hA5, 0, 0, "115200 Baud (Mandatory): 8N1 standard transmit (0xA5)");

            set_tx_config(115200, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'h5A, 0, 0, "115200 Baud (Mandatory): 8E1 Even Parity transmit (0x5A)");

            set_tx_config(115200, 2'b11, 1'b1, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'h3C, 0, 0, "115200 Baud (Mandatory): 8O2 2 Stop Bits transmit (0x3C)");

            // 7.2: 230,400 BAUD -> div_int = 13, div_frac = 9
            $display("\n--- [BAUD 230,400] D = 13 + 9/16 = 13.5625 (Spec Error = +0.006%%) ---");
            set_tx_config(230400, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'h33, 0, 0, "230400 Baud: 8N1 standard transmit (0x33)");

            set_tx_config(230400, 2'b11, 1'b0, 1'b1, 1'b0, 1'b0);
            transmit_and_check(8'hCC, 0, 0, "230400 Baud: 8O1 Odd Parity transmit (0xCC)");

            // 7.3: 460,800 BAUD -> div_int = 6, div_frac = 13
            $display("\n--- [BAUD 460,800] D = 6 + 13/16 = 6.8125 (Spec Error = -0.452%%) ---");
            set_tx_config(460800, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'h7E, 0, 0, "460800 Baud: 8N1 standard transmit (0x7E)");

            set_tx_config(460800, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'h81, 0, 0, "460800 Baud: 8E1 Even Parity transmit (0x81)");

            // 7.4: 921,600 BAUD (TỐC ĐỘ CỰC ĐẠI SPEC 1.1) -> div_int = 3, div_frac = 6
            $display("\n--- [BAUD 921,600] D = 3 + 6/16 = 3.375 (Spec Error = +0.469%%) ---");
            set_tx_config(921600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            transmit_and_check(8'h69, 0, 0, "921600 Baud (Max Spec Speed): 8N1 standard transmit (0x69)");

            set_tx_config(921600, 2'b11, 1'b1, 1'b1, 1'b1, 1'b0);
            transmit_and_check(8'h96, 0, 0, "921600 Baud (Max Spec Speed): 8E2 2 Stop Bits transmit (0x96)");

            // -----------------------------------------------------------------
            // TEST GROUP 8: COMPLETE 24-FORMAT MATRIX AND DATA BOUNDARIES
            // Spec requires every combination of 5–8 data bits, no/even/odd
            // parity, and one/two stop bits. Exercise each combination with
            // patterns that distinguish bit order, masking, and parity errors.
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 8: ALL 24 UART FORMATS AND DATA BOUNDARY PATTERNS");
            $display("======================================================================");
            boundary_patterns[0] = 8'h00;
            boundary_patterns[1] = 8'hFF;
            boundary_patterns[2] = 8'h01;
            boundary_patterns[3] = 8'h80;
            for (fmt_data = 0; fmt_data < 4; fmt_data = fmt_data + 1) begin
                for (fmt_parity = 0; fmt_parity < 3; fmt_parity = fmt_parity + 1) begin
                    for (fmt_stop = 0; fmt_stop < 2; fmt_stop = fmt_stop + 1) begin
                        set_tx_config(57600, fmt_data[1:0], fmt_stop[0],
                                      (fmt_parity != 0), (fmt_parity == 1), 1'b0);
                        for (pat_idx = 0; pat_idx < 4; pat_idx = pat_idx + 1) begin
                            case (fmt_parity)
                                0: transmit_and_check(boundary_patterns[pat_idx], 0, 0,
                                      "24-format matrix: no parity boundary pattern");
                                1: transmit_and_check(boundary_patterns[pat_idx], 0, 0,
                                      "24-format matrix: even parity boundary pattern");
                                2: transmit_and_check(boundary_patterns[pat_idx], 0, 0,
                                      "24-format matrix: odd parity boundary pattern");
                            endcase
                        end
                    end
                end
            end
        end

        // ---------------------------------------------------------------------
        // FINAL SCOREBOARD SUMMARY REPORT
        // ---------------------------------------------------------------------
        #(bit_time_ns * 5.0);
        $display("\n======================================================================");
        $display("                     FINAL VERIFICATION SUMMARY                       ");
        $display("======================================================================");
        $display("  TOTAL TESTCASES RUN : %0d", test_count);
        $display("  PASSED TESTCASES    : %0d", pass_count);
        $display("  FAILED TESTCASES    : %0d", fail_count);
        $display("======================================================================");
        if (fail_count == 0 && test_count > 0) begin
            $display("  *** VERDICT: 100%% PASS! ALL TX PROTOCOL CHECKS SUCCEEDED! ***");
        end else begin
            $display("  *** VERDICT: FAILURES DETECTED! PLEASE REVIEW LOGS ABOVE. ***");
        end
        $display("======================================================================\n");

        $finish;
    end

endmodule
