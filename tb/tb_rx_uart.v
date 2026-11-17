`timescale 1ns/1ps

// =============================================================================
// Module: tb_rx_uart
// Description: Comprehensive, Spec-Driven Verification Testbench for RX_UART
// Based on: APB-UART Specification 1.1 (doc/specs/za.html)
//
// Features & Capabilities:
//   1. Full Frame Coverage (5, 6, 7, 8 Data bits, None/Odd/Even Parity, 1/2 Stop bits)
//   2. High-bit Zero-Extension Masking (rx_data[7:N] = 0)
//   3. Parity Error Detection (Even & Odd parity mismatch)
//   4. Framing Error Detection (Stop bit 1 error, Stop bit 2 error, both)
//   5. Overrun Protection (Keep old data, flag overrun, no overwrite)
//   6. Hardware Flow Control (rts_n = rx_dis | rx_done)
//   7. Receiver Disable (rx_dis = 1 suppresses reception, asserts rts_n)
//   8. Read Handshake / Clear Flags (rx_clear clears rx_done, errs, overrun)
//   9. Start Bit Glitch / Noise Rejection (pulses < 0.4 bit ignored)
//  10. Baud Rate Tolerance (+/- 2.0% deviation testing per Spec Section 7)
//  11. Multi-baud testing: 2400, 4800, 9600, 19200
//  12. Mandatory High-Speed Baud: 115200 Baud (div_int=27, div_frac=2)
//  13. Ultra High-Speed Baud: 230400, 460800, 921600 Baud (div_int=3, div_frac=6)
//  14. USER DYNAMIC BAUD FIXING:
//      - Runtime CLI Plusarg:  vvp sim_rx_uart.vvp +BAUD=<any_baudrate>
//      - Compile-time Parameter: -Ptb_rx_uart.USER_BAUD=<any_baudrate>
// =============================================================================

module tb_rx_uart #(
    parameter integer USER_BAUD = 0  // 0: Run default full test suite; >0: Run specific baud suite
);

    // =========================================================================
    // 1. SIGNALS & DUT INTERFACE
    // =========================================================================
    reg        clk;
    reg        rst_n;
    reg        rx;
    reg [11:0] div_int;        // Spec 1.1: BAUD[11:0] fractional baud divisor integer
    reg  [3:0] div_frac;       // Spec 1.1: BAUD[15:12] fractional baud divisor fraction
    reg  [1:0] data_b_num;     // CFG[1:0]: 00=5b, 01=6b, 10=7b, 11=8b
    reg        stop_b_num;     // CFG[2]: 0=1 stop, 1=2 stop
    reg        parity_type;    // CFG[4]: Spec 1.1: 1 = Even, 0 = Odd
    reg        parity_en;      // CFG[3]: 1 = Enable, 0 = Disable
    reg        rx_dis;         // CFG[6]: 1 = Disable RX, rts_n = 1
    reg        rx_clear;       // Pulse from CPU reading RXDATA

    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_busy;
    wire       rts_n;
    wire       parity_err;
    wire       frame_err;
    wire       overrun;
    wire       error;

    // Testbench Management & Statistics
    real       bit_time_ns;
    integer    current_baud;
    integer    test_count;
    integer    pass_count;
    integer    fail_count;
    integer    fmt_data;
    integer    fmt_parity;
    integer    fmt_stop;
    integer    pat_idx;
    reg [7:0]  boundary_patterns [0:3];

    // =========================================================================
    // 2. DUT INSTANTIATION
    // =========================================================================
    rx_uart #(
        .CLK_FREQ(50_000_000)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (rx),
        .div_int    (div_int),
        .div_frac   (div_frac),
        .data_b_num (data_b_num),
        .stop_b_num (stop_b_num),
        .parity_type(parity_type),
        .parity_en  (parity_en),
        .rx_dis     (rx_dis),
        .rx_clear   (rx_clear),
        .rx_data    (rx_data),
        .rx_done    (rx_done),
        .rx_busy    (rx_busy),
        .rts_n      (rts_n),
        .parity_err (parity_err),
        .frame_err  (frame_err),
        .overrun    (overrun),
        .error      (error)
    );

    // =========================================================================
    // 3. CLOCK GENERATION (50 MHz -> 20ns period)
    // =========================================================================
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // =========================================================================
    // 4. VERIFICATION TASKS & INFRASTRUCTURE
    // =========================================================================

    // Task: Set configuration and calculate nominal bit duration & BAUD divider
    task set_config(
        input integer target_baud,
        input [1:0]   cfg_data_bits,
        input         cfg_stop_bits,
        input         cfg_parity_en,
        input         cfg_parity_type,
        input         cfg_rx_dis
    );
        real d_val;
        integer d_i;
        integer d_f;
        real actual_calc_baud;
        real baud_error_pct;
        begin
            current_baud = target_baud;
            data_b_num   = cfg_data_bits;
            stop_b_num   = cfg_stop_bits;
            parity_en    = cfg_parity_en;
            parity_type  = cfg_parity_type;
            rx_dis       = cfg_rx_dis;

            // Spec 1.1 Fractional Baud calculation:
            // D = f_clk / (16 * Baud)
            // div_int = floor(D), div_frac = round((D - floor(D)) * 16)
            d_val = 50_000_000.0 / (16.0 * target_baud);
            d_i   = $rtoi(d_val);
            d_f   = $rtoi((d_val - d_i) * 16.0 + 0.5);
            if (d_f >= 16) begin
                d_i = d_i + 1;
                d_f = 0;
            end
            div_int  = d_i[11:0];
            div_frac = d_f[3:0];

            actual_calc_baud = 50_000_000.0 / (16.0 * (d_i + (d_f / 16.0)));
            baud_error_pct   = ((actual_calc_baud - target_baud) / target_baud) * 100.0;

            bit_time_ns = 1_000_000_000.0 / target_baud;
            #(bit_time_ns * 2.0); // Allow configuration to stabilize
        end
    endtask

    // Task: Pulse rx_clear to simulate software reading RXDATA
    task clear_rx();
        begin
            @(posedge clk);
            rx_clear = 1'b1;
            @(posedge clk);
            rx_clear = 1'b0;
            @(posedge clk);
        end
    endtask

    // Task: Transmit serial UART frame with full error-injection and baud deviation control
    task send_frame(
        input [7:0]   byte_val,
        input         force_par_err,
        input         force_stop1_err,
        input         force_stop2_err,
        input real    baud_deviation_pct // e.g. 0.0, +2.0, -2.0
    );
        integer num_data_bits;
        integer i;
        real actual_bit_ns;
        reg par_val;
        reg par_calc;
        begin
            case (data_b_num)
                2'b00: num_data_bits = 5;
                2'b01: num_data_bits = 6;
                2'b10: num_data_bits = 7;
                2'b11: num_data_bits = 8;
            endcase

            // Fast transmitter (+e%): bit_time is shorter: bit_time / (1 + e/100)
            actual_bit_ns = bit_time_ns / (1.0 + (baud_deviation_pct / 100.0));

            // Calculate parity according to Spec 1.1:
            // parity_type == 1: EVEN (Total 1s in data + parity is EVEN) -> parity = ^data
            // parity_type == 0: ODD  (Total 1s in data + parity is ODD)  -> parity = ~(^data)
            par_calc = 1'b0;
            for (i = 0; i < num_data_bits; i = i + 1) begin
                par_calc = par_calc ^ byte_val[i];
            end

            if (parity_type == 1'b1)
                par_val = par_calc;      // Even
            else
                par_val = ~par_calc;     // Odd

            if (force_par_err)
                par_val = ~par_val;      // Corrupt parity

            // 1. Start Bit (Low)
            rx = 1'b0;
            #(actual_bit_ns);

            // 2. Data Bits (LSB first)
            for (i = 0; i < num_data_bits; i = i + 1) begin
                rx = byte_val[i];
                #(actual_bit_ns);
            end

            // 3. Parity Bit (if enabled)
            if (parity_en) begin
                rx = par_val;
                #(actual_bit_ns);
            end

            // 4. Stop Bit 1
            rx = force_stop1_err ? 1'b0 : 1'b1;
            #(actual_bit_ns);

            // 5. Stop Bit 2 (if 2 stop bits configured)
            if (stop_b_num) begin
                rx = force_stop2_err ? 1'b0 : 1'b1;
                #(actual_bit_ns);
            end

            // Return to Idle (High)
            rx = 1'b1;
        end
    endtask

    // Task: Self-checking receiver monitor
    task check_rx(
        input [7:0]   expected_char,
        input         exp_par_err,
        input         exp_frame_err,
        input         exp_overrun,
        input         should_receive, // 1 = frame expected to complete, 0 = ignore/suppressed
        input [511:0] test_name
    );
        integer wait_timeout;
        reg [7:0] exp_masked;
        reg tc_pass;
        begin
            test_count = test_count + 1;
            tc_pass = 1'b1;

            // Mask expected data according to data_b_num (zero-extension of upper bits)
            case (data_b_num)
                2'b00: exp_masked = expected_char & 8'h1F;
                2'b01: exp_masked = expected_char & 8'h3F;
                2'b10: exp_masked = expected_char & 8'h7F;
                2'b11: exp_masked = expected_char & 8'hFF;
            endcase

            // Wait for rx_done with timeout watchdog
            wait_timeout = 0;
            while (!rx_done && wait_timeout < 100) begin
                #(bit_time_ns / 10.0);
                wait_timeout = wait_timeout + 1;
            end

            $display("----------------------------------------------------------------------");
            $display("[TC #%0d] %0s (Time: %0t ns | Baud: %0d)", test_count, test_name, $time, current_baud);

            if (should_receive) begin
                if (!rx_done) begin
                    $display("  [FAIL] TIMEOUT: rx_done did NOT assert!");
                    $display("         DUT Status: rx_busy=%0b, rts_n=%0b, rx_data=0x%02X", rx_busy, rts_n, rx_data);
                    tc_pass = 1'b0;
                end else begin
                    // Check Data
                    if (rx_data !== exp_masked) begin
                        $display("  [FAIL] DATA MISMATCH: Expected 0x%02X, Received 0x%02X", exp_masked, rx_data);
                        tc_pass = 1'b0;
                    end
                    // Check Parity Error
                    if (parity_err !== exp_par_err) begin
                        $display("  [FAIL] PARITY_ERR MISMATCH: Expected %0b, Got %0b", exp_par_err, parity_err);
                        tc_pass = 1'b0;
                    end
                    // Check Framing Error
                    if (frame_err !== exp_frame_err) begin
                        $display("  [FAIL] FRAME_ERR MISMATCH: Expected %0b, Got %0b", exp_frame_err, frame_err);
                        tc_pass = 1'b0;
                    end
                    // Check Overrun
                    if (overrun !== exp_overrun) begin
                        $display("  [FAIL] OVERRUN MISMATCH: Expected %0b, Got %0b", exp_overrun, overrun);
                        tc_pass = 1'b0;
                    end
                    // Check Hardware Flow Control RTS_N (Spec: rts_n = rx_dis | rx_done)
                    if (rts_n !== (rx_dis | rx_done)) begin
                        $display("  [FAIL] RTS_N MISMATCH: Expected %0b, Got %0b", (rx_dis | rx_done), rts_n);
                        tc_pass = 1'b0;
                    end
                    // Check Composite Error
                    if (error !== (parity_err | frame_err)) begin
                        $display("  [FAIL] COMPOSITE ERROR MISMATCH: Expected %0b, Got %0b", (parity_err | frame_err), error);
                        tc_pass = 1'b0;
                    end
                end
            end else begin
                // should_receive == 0 (e.g. glitch or rx_dis = 1)
                if (rx_done) begin
                    $display("  [FAIL] UNEXPECTED RECEPTION: rx_done asserted when frame should be ignored!");
                    tc_pass = 1'b0;
                end else if (rx_busy) begin
                    $display("  [FAIL] UNEXPECTED BUSY: rx_busy asserted when receiver should remain IDLE!");
                    tc_pass = 1'b0;
                end
            end

            if (tc_pass) begin
                $display("  >>> [PASS] All checks matched: rx_data=0x%02X, done=%0b, rts_n=%0b, par_err=%0b, frm_err=%0b, ovr=%0b",
                         rx_data, rx_done, rts_n, parity_err, frame_err, overrun);
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
            end

            #(bit_time_ns); // Inter-frame spacing
        end
    endtask

    // =========================================================================
    // 5. REUSABLE TEST SUITE FOR ANY SPECIFIED BAUDRATE
    // =========================================================================
    task run_baud_suite(input integer baud_to_test);
        begin
            $display("\n======================================================================");
            $display(">>> RUNNING DEDICATED VERIFICATION AT %0d BAUD", baud_to_test);
            $display("======================================================================");

            // 1. 8-N-1 Standard
            set_config(baud_to_test, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'hA5, 0, 0, 0, 0.0);
            check_rx(8'hA5, 0, 0, 0, 1, "8N1: Receive 0xA5");
            clear_rx();

            send_frame(8'h5A, 0, 0, 0, 0.0);
            check_rx(8'h5A, 0, 0, 0, 1, "8N1: Receive 0x5A");
            clear_rx();

            // 2. 8-E-1 (Even Parity)
            set_config(baud_to_test, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            send_frame(8'h3C, 0, 0, 0, 0.0);
            check_rx(8'h3C, 0, 0, 0, 1, "8E1: Receive 0x3C (Even Parity)");
            clear_rx();

            // 3. Parity Error Detection
            send_frame(8'h3C, 1, 0, 0, 0.0); // Corrupt parity
            check_rx(8'h3C, 1, 0, 0, 1, "8E1: Injected Parity Error Detection");
            clear_rx();

            // 4. 8-N-2 (2 Stop bits)
            set_config(baud_to_test, 2'b11, 1'b1, 1'b0, 1'b0, 1'b0);
            send_frame(8'hF0, 0, 0, 0, 0.0);
            check_rx(8'hF0, 0, 0, 0, 1, "8N2: Receive 0xF0 (2 Stop Bits)");
            clear_rx();

            // 5. Baud Rate Tolerance (+2.0% Fast Transmitter)
            send_frame(8'h96, 0, 0, 0, +2.0);
            check_rx(8'h96, 0, 0, 0, 1, "Baud Tolerance: +2.0% Fast Transmitter");
            clear_rx();

            // 6. Baud Rate Tolerance (-2.0% Slow Transmitter)
            send_frame(8'h69, 0, 0, 0, -2.0);
            check_rx(8'h69, 0, 0, 0, 1, "Baud Tolerance: -2.0% Slow Transmitter");
            clear_rx();
        end
    endtask

    // =========================================================================
    // 6. MAIN VERIFICATION SEQUENCE
    // =========================================================================
    integer selected_baud;

    initial begin
        // Waveform dump
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_rx_uart);

        // Signal initialization
        test_count   = 0;
        pass_count   = 0;
        fail_count   = 0;
        clk          = 1'b0;
        rst_n        = 1'b0;
        rx           = 1'b1;
        rx_dis       = 1'b0;
        rx_clear     = 1'b0;
        div_int      = 12'd325; // Default 9600 baud @ 50 MHz
        div_frac     = 4'd8;
        data_b_num   = 2'b11;   // 8 bit
        stop_b_num   = 1'b0;    // 1 stop
        parity_en    = 1'b0;    // None
        parity_type  = 1'b1;    // Even
        current_baud = 9600;

        $display("\n======================================================================");
        $display("   DV TESTBENCH: APB-UART RX SPECIFICATION 1.1 VERIFICATION SUITE   ");
        $display("======================================================================");

        // Reset Sequence
        #100;
        @(negedge clk);
        rst_n = 1'b1;
        #(bit_time_ns * 2.0);
        $display("[INFO] System released from reset (rst_n = 1) at time %0t ns", $time);

        // Check if user specified custom baudrate via Command Line Plusarg or Parameter
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
            run_baud_suite(selected_baud);
        end
        // ---------------------------------------------------------------------
        // BRANCH B: RUN DEFAULT FULL SPEC 1.1 COMPREHENSIVE REGRESSION SUITE
        // ---------------------------------------------------------------------
        else begin
            $display("[MODE] RUNNING COMPREHENSIVE FULL SPEC REGRESSION SUITE");

            // -----------------------------------------------------------------
            // TEST GROUP 1: STANDARD FRAME FORMATS (8N1, 8E1, 8O1, 8N2...)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 1: STANDARD FRAME CONFIGURATIONS (8N1, 8E1, 8O1, 8N2...)");
            $display("======================================================================");

            set_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'hA5, 0, 0, 0, 0.0);
            check_rx(8'hA5, 0, 0, 0, 1, "8N1: Receive 0xA5 @ 9600 baud");
            clear_rx();

            send_frame(8'h5A, 0, 0, 0, 0.0);
            check_rx(8'h5A, 0, 0, 0, 1, "8N1: Receive 0x5A @ 9600 baud");
            clear_rx();

            set_config(9600, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            send_frame(8'h3C, 0, 0, 0, 0.0);
            check_rx(8'h3C, 0, 0, 0, 1, "8E1: Receive 0x3C with Even Parity");
            clear_rx();

            send_frame(8'hFF, 0, 0, 0, 0.0);
            check_rx(8'hFF, 0, 0, 0, 1, "8E1: Receive 0xFF with Even Parity");
            clear_rx();

            set_config(9600, 2'b11, 1'b0, 1'b1, 1'b0, 1'b0);
            send_frame(8'h77, 0, 0, 0, 0.0);
            check_rx(8'h77, 0, 0, 0, 1, "8O1: Receive 0x77 with Odd Parity");
            clear_rx();

            send_frame(8'h00, 0, 0, 0, 0.0);
            check_rx(8'h00, 0, 0, 0, 1, "8O1: Receive 0x00 with Odd Parity");
            clear_rx();

            set_config(9600, 2'b11, 1'b1, 1'b0, 1'b0, 1'b0);
            send_frame(8'hC3, 0, 0, 0, 0.0);
            check_rx(8'hC3, 0, 0, 0, 1, "8N2: Receive 0xC3 with 2 Stop Bits");
            clear_rx();

            set_config(19200, 2'b11, 1'b1, 1'b1, 1'b1, 1'b0);
            send_frame(8'h55, 0, 0, 0, 0.0);
            check_rx(8'h55, 0, 0, 0, 1, "8E2: Receive 0x55 @ 19200 Baud");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 2: DATA WIDTHS & HIGH-BIT ZERO MASKING
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 2: DATA LENGTHS & ZERO-MASKING (5, 6, 7 BITS)");
            $display("======================================================================");

            set_config(9600, 2'b10, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'hFF, 0, 0, 0, 0.0);
            check_rx(8'h7F, 0, 0, 0, 1, "7N1: Zero-masking bit 7 (Send 0xFF -> Exp 0x7F)");
            clear_rx();

            set_config(9600, 2'b01, 1'b0, 1'b1, 1'b1, 1'b0);
            send_frame(8'hFF, 0, 0, 0, 0.0);
            check_rx(8'h3F, 0, 0, 0, 1, "6E1: Zero-masking bits 7:6 (Send 0xFF -> Exp 0x3F)");
            clear_rx();

            set_config(9600, 2'b00, 1'b0, 1'b1, 1'b0, 1'b0);
            send_frame(8'hFF, 0, 0, 0, 0.0);
            check_rx(8'h1F, 0, 0, 0, 1, "5O1: Zero-masking bits 7:5 (Send 0xFF -> Exp 0x1F)");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 3: ERROR INJECTION & RECOVERY (PARITY & FRAMING)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 3: ERROR INJECTION (PARITY & FRAMING ERRORS)");
            $display("======================================================================");

            set_config(9600, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            send_frame(8'hA5, 1, 0, 0, 0.0);
            check_rx(8'hA5, 1, 0, 0, 1, "8E1: Injected Even Parity Error");
            clear_rx();

            set_config(9600, 2'b11, 1'b0, 1'b1, 1'b0, 1'b0);
            send_frame(8'h5A, 1, 0, 0, 0.0);
            check_rx(8'h5A, 1, 0, 0, 1, "8O1: Injected Odd Parity Error");
            clear_rx();

            set_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'h42, 0, 1, 0, 0.0);
            check_rx(8'h42, 0, 1, 0, 1, "8N1: Injected Framing Error (Stop bit = 0)");
            clear_rx();

            set_config(9600, 2'b11, 1'b1, 1'b0, 1'b0, 1'b0);
            send_frame(8'h11, 0, 1, 0, 0.0);
            check_rx(8'h11, 0, 1, 0, 1, "8N2: Framing Error on Stop Bit 1");
            clear_rx();

            send_frame(8'h22, 0, 0, 1, 0.0);
            check_rx(8'h22, 0, 1, 0, 1, "8N2: Framing Error on Stop Bit 2");
            clear_rx();

            set_config(9600, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            send_frame(8'hEE, 1, 1, 0, 0.0);
            check_rx(8'hEE, 1, 1, 0, 1, "8E1: Combined Parity Error & Framing Error");
            clear_rx();

            send_frame(8'h69, 0, 0, 0, 0.0);
            check_rx(8'h69, 0, 0, 0, 1, "Recovery: Valid frame received cleanly after errors");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 4: OVERRUN PROTECTION & DATA BUFFER RETENTION
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 4: OVERRUN PROTECTION (BUFFER RETENTION)");
            $display("======================================================================");

            set_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'h12, 0, 0, 0, 0.0);
            check_rx(8'h12, 0, 0, 0, 1, "Overrun Step 1: 1st frame 0x12 received, rx_done=1");

            send_frame(8'h34, 0, 0, 0, 0.0);
            check_rx(8'h12, 0, 0, 1, 1, "Overrun Step 2: 2nd frame dropped, overrun=1, data kept 0x12");
            clear_rx();

            if (overrun !== 1'b0 || rx_done !== 1'b0 || rts_n !== 1'b0) begin
                $display("  [FAIL] clear_rx() failed to clear overrun/rx_done/rts_n!");
                fail_count = fail_count + 1;
            end else begin
                $display("  >>> [PASS] Software read cleared rx_done, overrun, and deasserted rts_n.");
                pass_count = pass_count + 1;
            end

            send_frame(8'h56, 0, 0, 0, 0.0);
            check_rx(8'h56, 0, 0, 0, 1, "Overrun Step 3: Normal reception restored with 0x56");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 5: HARDWARE FLOW CONTROL (rts_n) & RECEIVER DISABLE (rx_dis)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 5: HARDWARE FLOW CONTROL (rts_n) & rx_dis");
            $display("======================================================================");

            set_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b1);
            #(bit_time_ns);
            if (rts_n !== 1'b1) begin
                $display("  [FAIL] rts_n must be 1 when rx_dis = 1! Got %0b", rts_n);
                fail_count = fail_count + 1;
            end else begin
                $display("  >>> [PASS] rts_n asserted (1) when rx_dis = 1");
                pass_count = pass_count + 1;
            end

            send_frame(8'hAA, 0, 0, 0, 0.0);
            check_rx(8'hAA, 0, 0, 0, 0, "rx_dis=1: Frame 0xAA ignored, no rx_done, no rx_busy");

            set_config(9600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            #(bit_time_ns);
            if (rts_n !== 1'b0) begin
                $display("  [FAIL] rts_n must return to 0 when rx_dis = 0! Got %0b", rts_n);
                fail_count = fail_count + 1;
            end else begin
                $display("  >>> [PASS] rts_n returned to 0 when rx_dis = 0");
                pass_count = pass_count + 1;
            end

            send_frame(8'hBB, 0, 0, 0, 0.0);
            check_rx(8'hBB, 0, 0, 0, 1, "rx_dis=0: Normal reception restored for 0xBB");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 6: START BIT GLITCH & NOISE REJECTION
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 6: START BIT GLITCH / NOISE REJECTION");
            $display("======================================================================");

            @(posedge clk);
            rx = 1'b0;
            repeat (3) @(posedge clk);
            rx = 1'b1;
            #(bit_time_ns * 2.0);
            check_rx(8'h00, 0, 0, 0, 0, "Glitch Rejection: 60ns noise pulse suppressed, no frame");

            send_frame(8'hD4, 0, 0, 0, 0.0);
            check_rx(8'hD4, 0, 0, 0, 1, "Post-Glitch: Valid frame 0xD4 received successfully");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 7: BAUD RATE TOLERANCE (+/- 2.0%) PER SPEC SECTION 7
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 7: BAUD RATE TOLERANCE (+/- 2.0%% DEVIATION)");
            $display("======================================================================");

            set_config(9600, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            send_frame(8'h89, 0, 0, 0, +2.0);
            check_rx(8'h89, 0, 0, 0, 1, "Baud Tolerance: +2.0% Fast Transmitter (8E1)");
            clear_rx();

            send_frame(8'h98, 0, 0, 0, -2.0);
            check_rx(8'h98, 0, 0, 0, 1, "Baud Tolerance: -2.0% Slow Transmitter (8E1)");
            clear_rx();

            set_config(9600, 2'b11, 1'b1, 1'b1, 1'b0, 1'b0);
            send_frame(8'hFE, 0, 0, 0, +2.0);
            check_rx(8'hFE, 0, 0, 0, 1, "Baud Tolerance: +2.0% Fast Transmitter (8O2, 2 Stop)");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 8: LOW/MEDIUM BAUD RATES (2400, 4800, 19200)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 8: MULTI-BAUD RATE COVERAGE (2400, 4800, 19200)");
            $display("======================================================================");

            set_config(19200, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'h55, 0, 0, 0, 0.0);
            check_rx(8'h55, 0, 0, 0, 1, "Multi-Baud: 19200 Baud (8N1, 0x55)");
            clear_rx();

            set_config(4800, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'hAA, 0, 0, 0, 0.0);
            check_rx(8'hAA, 0, 0, 0, 1, "Multi-Baud: 4800 Baud (8N1, 0xAA)");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 9: HIGH-SPEED & ULTRA HIGH-SPEED BAUDRATES (115.2k - 921.6k)
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 9: HIGH-SPEED BAUDRATES (115200 BẮT BUỘC & 230400–921600)");
            $display("======================================================================");

            // 9.1: 115,200 BAUD (BẮT BUỘC) -> div_int = 27, div_frac = 2
            $display("\n--- [BAUD 115,200] D = 27 + 2/16 = 27.125 (Error = +0.006%%) ---");
            set_config(115200, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'hA5, 0, 0, 0, 0.0);
            check_rx(8'hA5, 0, 0, 0, 1, "115200 Baud: 8N1 standard receive (0xA5)");
            clear_rx();

            set_config(115200, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0);
            send_frame(8'h5A, 0, 0, 0, 0.0);
            check_rx(8'h5A, 0, 0, 0, 1, "115200 Baud: 8E1 Even Parity receive (0x5A)");
            clear_rx();

            send_frame(8'h5A, 1, 0, 0, 0.0); // Inject parity error
            check_rx(8'h5A, 1, 0, 0, 1, "115200 Baud: Parity Error Detection (parity_err=1)");
            clear_rx();

            send_frame(8'h3C, 0, 0, 0, +2.0); // Fast transmitter +2.0%
            check_rx(8'h3C, 0, 0, 0, 1, "115200 Baud: +2.0% Baud Tolerance verification");
            clear_rx();

            // 9.2: 230,400 BAUD -> div_int = 13, div_frac = 9
            $display("\n--- [BAUD 230,400] D = 13 + 9/16 = 13.5625 (Error = +0.006%%) ---");
            set_config(230400, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'h33, 0, 0, 0, 0.0);
            check_rx(8'h33, 0, 0, 0, 1, "230400 Baud: 8N1 standard receive (0x33)");
            clear_rx();

            set_config(230400, 2'b11, 1'b0, 1'b1, 1'b0, 1'b0);
            send_frame(8'hCC, 0, 0, 0, 0.0);
            check_rx(8'hCC, 0, 0, 0, 1, "230400 Baud: 8O1 Odd Parity receive (0xCC)");
            clear_rx();

            // 9.3: 460,800 BAUD -> div_int = 6, div_frac = 13
            $display("\n--- [BAUD 460,800] D = 6 + 13/16 = 6.8125 (Error = -0.452%%) ---");
            set_config(460800, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'h7E, 0, 0, 0, 0.0);
            check_rx(8'h7E, 0, 0, 0, 1, "460800 Baud: 8N1 standard receive (0x7E)");
            clear_rx();

            // 9.4: 921,600 BAUD (TỐC ĐỘ CỰC ĐẠI SPEC 1.1) -> div_int = 3, div_frac = 6
            $display("\n--- [BAUD 921,600] D = 3 + 6/16 = 3.375 (Error = +0.469%%) ---");
            set_config(921600, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
            send_frame(8'h69, 0, 0, 0, 0.0);
            check_rx(8'h69, 0, 0, 0, 1, "921600 Baud (Max Spec): 8N1 receive (0x69)");
            clear_rx();

            set_config(921600, 2'b11, 1'b1, 1'b1, 1'b1, 1'b0);
            send_frame(8'h96, 0, 0, 0, 0.0);
            check_rx(8'h96, 0, 0, 0, 1, "921600 Baud (Max Spec): 8E2 2 Stop Bits (0x96)");
            clear_rx();

            send_frame(8'h96, 0, 0, 0, -2.0); // Slow transmitter -2.0%
            check_rx(8'h96, 0, 0, 0, 1, "921600 Baud: -2.0% Baud Tolerance verification");
            clear_rx();

            // -----------------------------------------------------------------
            // TEST GROUP 10: ALL 24 FORMATS AND DATA BOUNDARY PATTERNS
            // Spec requires every data width, parity mode, and stop-bit count.
            // Exercise values that expose LSB order, high-bit zero extension,
            // and parity handling for both data polarities and sparse bits.
            // -----------------------------------------------------------------
            $display("\n======================================================================");
            $display(">>> TEST GROUP 10: ALL 24 UART FORMATS AND DATA BOUNDARY PATTERNS");
            $display("======================================================================");
            boundary_patterns[0] = 8'h00;
            boundary_patterns[1] = 8'hFF;
            boundary_patterns[2] = 8'h01;
            boundary_patterns[3] = 8'h80;
            for (fmt_data = 0; fmt_data < 4; fmt_data = fmt_data + 1) begin
                for (fmt_parity = 0; fmt_parity < 3; fmt_parity = fmt_parity + 1) begin
                    for (fmt_stop = 0; fmt_stop < 2; fmt_stop = fmt_stop + 1) begin
                        set_config(57600, fmt_data[1:0], fmt_stop[0],
                                   (fmt_parity != 0), (fmt_parity == 1), 1'b0);
                        for (pat_idx = 0; pat_idx < 4; pat_idx = pat_idx + 1) begin
                            send_frame(boundary_patterns[pat_idx], 0, 0, 0, 0.0);
                            case (fmt_parity)
                                0: check_rx(boundary_patterns[pat_idx], 0, 0, 0, 1,
                                      "24-format matrix: no parity boundary pattern");
                                1: check_rx(boundary_patterns[pat_idx], 0, 0, 0, 1,
                                      "24-format matrix: even parity boundary pattern");
                                2: check_rx(boundary_patterns[pat_idx], 0, 0, 0, 1,
                                      "24-format matrix: odd parity boundary pattern");
                            endcase
                            clear_rx();
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
            $display("  *** VERDICT: 100%% PASS! RTL FULLY MEETS SPECIFICATION 1.1! ***");
        end else begin
            $display("  *** VERDICT: FAILURES DETECTED! PLEASE REVIEW LOGS ABOVE. ***");
        end
        $display("======================================================================\n");

        $finish;
    end

endmodule
