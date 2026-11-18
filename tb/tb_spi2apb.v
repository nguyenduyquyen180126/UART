`timescale 1ns/1ps

// Black-box system test for the SPI-to-APB UART wrapper.
// Stimulus and expected behavior are taken from doc/specs/za.html:
//   * SPI mode 0, MSB first, fixed 56-bit frames
//   * register map and status/error behavior
//   * 8N1 TX/RX at the reset BAUD value (25 MHz pclk, 115200 baud)
// No internal DUT signals are referenced.
module tb_spi2apb;

    localparam integer PCLK_PERIOD_NS = 40;
    localparam integer SPI_HALF_NS    = 207;  // 2.42 MHz, safely below pclk/10
    localparam integer UART_BIT_NS    = 8680; // 217 pclk cycles at BAUD=0x900D

    reg  pclk;
    reg  presetn;
    reg  spi_cs_n;
    reg  spi_sclk;
    reg  spi_mosi;
    wire spi_miso;
    reg  cts_n;
    reg  rx;
    wire tx;
    wire rts_n;
    wire irq;

    integer checks;
    integer check_pass_count, check_fail_count;
    integer test_count, pass_count, fail_count;
    integer case_failed;
    reg [8*96-1:0] current_case;

    spi2apb #(
        .CLK_FREQ (25_000_000)
    ) dut (
        .pclk     (pclk),
        .presetn  (presetn),
        .spi_cs_n (spi_cs_n),
        .spi_sclk (spi_sclk),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .cts_n    (cts_n),
        .rx       (rx),
        .tx       (tx),
        .rts_n    (rts_n),
        .irq      (irq)
    );

    always #(PCLK_PERIOD_NS/2) pclk = ~pclk;

    task begin_case;
        input [8*96-1:0] case_name;
        begin
            test_count = test_count + 1;
            current_case = case_name;
            case_failed = 0;
            $display("\n[TC #%02d] %0s", test_count, current_case);
        end
    endtask

    task end_case;
        begin
            if (case_failed) begin
                fail_count = fail_count + 1;
                $display("  >>> [FAIL] %0s", current_case);
            end else begin
                pass_count = pass_count + 1;
                $display("  >>> [PASS] %0s", current_case);
            end
        end
    endtask

    task record_check;
        input condition;
        input [8*100-1:0] message;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                check_fail_count = check_fail_count + 1;
                case_failed = 1;
                $display("  [FAIL] %0s: %0s", current_case, message);
            end else begin
                check_pass_count = check_pass_count + 1;
            end
        end
    endtask

    // Send one complete SPI frame. cmd_bad sets a reserved command bit;
    // tx_payload is transmitted MSB first in bytes B2 through B5.
    task spi_frame;
        input         rw;
        input  [3:0]  reg_index;
        input  [31:0] tx_payload;
        input         cmd_bad;
        output [31:0] rx_payload;
        output [7:0]  rx_status;
        reg [7:0] command;
        reg [55:0] mosi_frame;
        reg [55:0] miso_frame;
        integer bit_index;
        begin
            command = {rw, 3'b000, reg_index};
            if (cmd_bad)
                command[6] = 1'b1;
            mosi_frame = {command, 8'h00, tx_payload, 8'h00};
            miso_frame = 56'h0;

            spi_cs_n = 1'b0;
            #(SPI_HALF_NS);
            for (bit_index = 55; bit_index >= 0; bit_index = bit_index - 1) begin
                spi_mosi = mosi_frame[bit_index];
                #(SPI_HALF_NS);
                spi_sclk = 1'b1;
                #1;
                miso_frame[bit_index] = spi_miso;
                #(SPI_HALF_NS-1);
                spi_sclk = 1'b0;
            end
            spi_mosi = 1'b0;
            #(SPI_HALF_NS);
            spi_cs_n = 1'b1;
            #1;

            record_check(spi_miso === 1'b0, "MISO is low while CS is high");
            record_check(miso_frame[55:40] === 16'h0000, "MISO B0/B1 are zero");
            if (rw)
                record_check(miso_frame[39:8] === 32'h0000_0000,
                             "MISO write-data bytes B2-B5 are zero");
            // The SPI pins are synchronized into pclk. Leave CS high long
            // enough for the complete next-frame boundary to cross that sync.
            repeat (5) @(negedge pclk);
            rx_payload = miso_frame[39:8];
            rx_status  = miso_frame[7:0];
        end
    endtask

    // Start a write frame, but deassert CS before bit 48. Per the spec, the
    // APB write is not issued until all four data bytes have arrived.
    task abort_write_before_bit48;
        input [3:0]  reg_index;
        input [31:0] value;
        reg [7:0] command;
        reg [55:0] mosi_frame;
        integer bit_index;
        begin
            command = {1'b1, 3'b000, reg_index};
            mosi_frame = {command, 8'h00, value, 8'h00};
            spi_cs_n = 1'b0;
            #(SPI_HALF_NS);
            for (bit_index = 55; bit_index > 55-40; bit_index = bit_index - 1) begin
                spi_mosi = mosi_frame[bit_index];
                #(SPI_HALF_NS);
                spi_sclk = 1'b1;
                #(SPI_HALF_NS);
                spi_sclk = 1'b0;
            end
            spi_mosi = 1'b0;
            #(SPI_HALF_NS);
            spi_cs_n = 1'b1;
            #1;
            record_check(spi_miso === 1'b0, "MISO is low after aborted frame");
            repeat (5) @(negedge pclk);
        end
    endtask

    task write_reg;
        input [3:0]  reg_index;
        input [31:0] value;
        output [7:0] status;
        reg [31:0] ignored_data;
        begin
            spi_frame(1'b1, reg_index, value, 1'b0, ignored_data, status);
        end
    endtask

    task read_reg;
        input  [3:0]  reg_index;
        output [31:0] value;
        output [7:0]  status;
        begin
            spi_frame(1'b0, reg_index, 32'h0, 1'b0, value, status);
        end
    endtask

    task expect_eq32;
        input [31:0] actual;
        input [31:0] expected;
        input [8*80-1:0] label_text;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                check_fail_count = check_fail_count + 1;
                case_failed = 1;
                $display("  [FAIL] %0s: %0s expected 0x%08x, got 0x%08x", current_case, label_text, expected, actual);
            end else check_pass_count = check_pass_count + 1;
        end
    endtask

    task expect_eq8;
        input [7:0] actual;
        input [7:0] expected;
        input [8*80-1:0] label_text;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                check_fail_count = check_fail_count + 1;
                case_failed = 1;
                $display("  [FAIL] %0s: %0s expected 0x%02x, got 0x%02x", current_case, label_text, expected, actual);
            end else check_pass_count = check_pass_count + 1;
        end
    endtask

    task expect_high;
        input signal_value;
        input [8*80-1:0] label_text;
        begin
            checks = checks + 1;
            if (signal_value !== 1'b1) begin
                check_fail_count = check_fail_count + 1;
                case_failed = 1;
                $display("  [FAIL] %0s: %0s expected logic 1, got %b", current_case, label_text, signal_value);
            end else check_pass_count = check_pass_count + 1;
        end
    endtask

    task expect_low;
        input signal_value;
        input [8*80-1:0] label_text;
        begin
            checks = checks + 1;
            if (signal_value !== 1'b0) begin
                check_fail_count = check_fail_count + 1;
                case_failed = 1;
                $display("  [FAIL] %0s: %0s expected logic 0, got %b", current_case, label_text, signal_value);
            end else check_pass_count = check_pass_count + 1;
        end
    endtask

    // Receive and check the externally visible 8N1 serial frame.
    task check_uart_tx_8n1;
        input [7:0] expected_byte;
        integer bit_number;
        begin
            @(negedge tx);
            #(UART_BIT_NS/2);
            record_check(tx === 1'b0, "TX start bit is low at midpoint");

            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                #(UART_BIT_NS);
                checks = checks + 1;
                if (tx !== expected_byte[bit_number]) begin
                    check_fail_count = check_fail_count + 1;
                    case_failed = 1;
                    $display("  [FAIL] %0s: TX data bit %0d expected %b, got %b", current_case, bit_number, expected_byte[bit_number], tx);
                end else check_pass_count = check_pass_count + 1;
            end

            #(UART_BIT_NS);
            record_check(tx === 1'b1, "TX stop bit is high at midpoint");
        end
    endtask

    // Drive an 8N1 UART frame into the asynchronous rx pin, LSB first.
    task send_uart_rx_8n1;
        input [7:0] value;
        input       good_stop;
        integer bit_number;
        begin
            rx = 1'b0;
            #(UART_BIT_NS);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                rx = value[bit_number];
                #(UART_BIT_NS);
            end
            rx = good_stop;
            #(UART_BIT_NS);
            rx = 1'b1;
            // Allow the specified stop-bit midpoint check and status update.
            #(UART_BIT_NS);
        end
    endtask

    reg [31:0] read_value;
    reg [31:0] ignored_value;
    reg [7:0]  status;
    reg [7:0]  ignored_status;

    initial begin
        pclk       = 1'b0;
        presetn    = 1'b0;
        spi_cs_n   = 1'b1;
        spi_sclk   = 1'b0;
        spi_mosi   = 1'b0;
        cts_n      = 1'b1; // not clear to send
        rx         = 1'b1; // UART idle
        checks     = 0;
        check_pass_count = 0;
        check_fail_count = 0;
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        case_failed = 0;
        current_case = "initialization";

        repeat (5) @(posedge pclk);
        // During active-low reset, the external serial outputs are idle and
        // RTS_N is inactive. Once reset is released, the empty enabled RX
        // receiver advertises readiness with RTS_N low (spec sections 2/6.4).
        begin_case("Reset outputs and SPI register defaults");
        expect_high(tx,     "TX idle while reset is asserted");
        expect_high(rts_n,  "RTS_N inactive while reset is asserted");
        expect_low (irq,    "IRQ while reset is asserted");
        @(negedge pclk);
        presetn = 1'b1;
        repeat (4) @(posedge pclk);

        expect_high(tx,     "TX idle after reset release");
        expect_low (rts_n,  "empty enabled RX is ready after reset release");
        expect_low (irq,    "IRQ after reset release");

        // Reset values and the 56-bit SPI command/data/status format.
        read_reg(4'h4, read_value, status); // STAT
        expect_eq32(read_value, 32'h0000_0001, "reset STAT");
        expect_eq8(status, 8'h00, "STAT read status byte");

        read_reg(4'h5, read_value, status); // BAUD
        expect_eq32(read_value, 32'h0000_900D, "reset BAUD");
        expect_eq8(status, 8'h00, "BAUD read status byte");
        end_case;

        // A reserved command bit is a bridge-level command error and must not
        // issue an APB access. Confirm the addressed register stays unchanged.
        begin_case("Malformed SPI command and aborted write");
        spi_frame(1'b1, 4'h2, 32'h0000_0000, 1'b1, ignored_value, status);
        expect_eq8(status, 8'h02, "malformed command status");
        read_reg(4'h2, read_value, status); // CFG
        expect_eq32(read_value, 32'h0, "malformed command did not write CFG");

        // A write frame cut short of its 48th SCLK edge must have no effect.
        abort_write_before_bit48(4'h0, 32'h0000_0077); // TXDATA
        read_reg(4'h0, read_value, status);
        expect_eq32(read_value, 32'h0, "aborted SPI write did not change TXDATA");
        end_case;

        // Configure 8N1 and verify ordinary register write/read operation.
        begin_case("Register access and APB slave errors");
        write_reg(4'h2, 32'h0000_0003, status); // CFG: 8 data, no parity, 1 stop
        expect_eq8(status, 8'h00, "CFG write status");
        read_reg(4'h2, read_value, status);
        expect_eq32(read_value, 32'h0000_0003, "CFG readback");

        // Invalid APB address and representative slave errors E2 and E5.
        spi_frame(1'b0, 4'h7, 32'h0, 1'b0, read_value, status);
        expect_eq32(read_value, 32'h0, "invalid address read data");
        expect_eq8(status, 8'h01, "invalid address reports pslverr");

        write_reg(4'h1, 32'h0000_005A, status); // RXDATA is read-only (E2)
        expect_eq8(status, 8'h01, "write RXDATA reports E2");

        write_reg(4'h5, 32'h0000_9000, status); // div_int=0 (E5)
        expect_eq8(status, 8'h01, "zero div_int reports E5");
        read_reg(4'h5, read_value, status);
        expect_eq32(read_value, 32'h0000_900D, "failed BAUD write has no effect");
        end_case;

        // Enable TX-done interrupt, queue a byte, and prove CTS gates the
        // transfer. Then check the serial waveform while an E4 BAUD write is
        // attempted during the active transmit frame.
        begin_case("UART TX, CTS gating, busy protection, and TX IRQ");
        write_reg(4'h6, 32'h0000_0001, status); // IER.tx_done_ie
        write_reg(4'h0, 32'h0000_00A6, status); // TXDATA
        write_reg(4'h3, 32'h0000_0001, status); // CTRL.start_tx
        expect_eq8(status, 8'h00, "start TX status");
        expect_low(irq, "IRQ while TX is busy");
        repeat (10) @(posedge pclk);
        expect_high(tx, "CTS_N high holds TX idle");

        fork
            check_uart_tx_8n1(8'hA6);
            begin
                #1000;
                cts_n = 1'b0;
                // Transaction occurs while the 8N1 frame is still active.
                write_reg(4'h5, 32'h0000_900D, status);
                expect_eq8(status, 8'h01, "BAUD write while TX busy reports E4");
                cts_n = 1'b1; // CTS changes mid-frame; current frame must finish.
            end
        join

        // The UART checker samples the stop bit at its midpoint; tx_done is
        // specified at the end of that stop bit (within two pclk cycles).
        #(UART_BIT_NS/2 + 2*PCLK_PERIOD_NS);
        expect_high(tx, "TX returns to idle after frame");
        expect_high(irq, "TX-done interrupt asserted");
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value & 32'h1, 32'h1, "STAT.tx_done after TX");
        read_reg(4'h5, read_value, status);
        expect_eq32(read_value, 32'h0000_900D, "busy BAUD write has no effect");
        end_case;

        // RX-done interrupt, received data, RTS flow control, and read-clear.
        begin_case("UART RX data, RTS flow control, and RX-done IRQ");
        write_reg(4'h6, 32'h0000_0002, status); // IER.rx_done_ie
        send_uart_rx_8n1(8'h5A, 1'b1);
        expect_high(rts_n, "RTS_N asserts when RX data is pending");
        expect_high(irq, "RX-done interrupt asserted");
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value & 32'h0000_0003, 32'h0000_0003,
                    "STAT shows tx_done and rx_done");
        read_reg(4'h1, read_value, status); // RXDATA read clears receive flags
        expect_eq32(read_value, 32'h0000_005A, "received RXDATA");
        expect_low(irq, "RXDATA read clears RX-done IRQ");
        expect_low(rts_n, "RTS_N deasserts after RXDATA is read");
        end_case;

        // Error interrupt and read-clear behavior for a bad stop bit.
        begin_case("UART RX framing error and error IRQ");
        write_reg(4'h6, 32'h0000_0004, status); // IER.err_ie
        send_uart_rx_8n1(8'hC3, 1'b0);
        expect_high(irq, "framing error interrupt asserted");
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value & 32'h0000_0042, 32'h0000_0042,
                    "STAT reports rx_done and frame_err");
        read_reg(4'h1, read_value, status);
        expect_eq32(read_value, 32'h0000_00C3, "RXDATA with framing error");
        expect_low(irq, "RXDATA read clears framing error IRQ");
        end_case;

        // A second unread character is dropped and sets overrun; old RXDATA
        // remains intact until software reads it.
        begin_case("UART RX overrun and unread data preservation");
        send_uart_rx_8n1(8'h96, 1'b1);
        send_uart_rx_8n1(8'h69, 1'b1);
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value & 32'h0000_0082, 32'h0000_0082,
                    "STAT reports rx_done and overrun");
        expect_high(irq, "overrun error interrupt asserted");
        read_reg(4'h1, read_value, status);
        expect_eq32(read_value, 32'h0000_0096, "overrun preserves unread RXDATA");
        expect_low(irq, "RXDATA read clears overrun IRQ");
        end_case;

        // Soft reset restores register/engine state and output idle levels.
        begin_case("Soft reset and restored defaults");
        write_reg(4'h3, 32'h0000_0100, status); // CTRL.soft_rst
        expect_eq8(status, 8'h00, "soft reset write status");
        repeat (4) @(posedge pclk);
        read_reg(4'h2, read_value, status);
        expect_eq32(read_value, 32'h0, "CFG after soft reset");
        read_reg(4'h6, read_value, status);
        expect_eq32(read_value, 32'h0, "IER after soft reset");
        read_reg(4'h5, read_value, status);
        expect_eq32(read_value, 32'h0000_900D, "BAUD after soft reset");
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value, 32'h1, "STAT after soft reset");
        expect_high(tx, "TX idle after soft reset");
        expect_low(rts_n, "empty enabled RX is ready after soft reset");
        expect_low(irq, "IRQ after soft reset");

        end_case;

        $display("\n======================================================================");
        $display("TESTCASE SUMMARY: TOTAL=%0d PASS=%0d FAIL=%0d", test_count, pass_count, fail_count);
        $display("CHECK SUMMARY:    TOTAL=%0d PASS=%0d FAIL=%0d", checks, check_pass_count, check_fail_count);
        $display("======================================================================");
        if (fail_count != 0 || check_fail_count != 0)
            $fatal(1, "tb_spi2apb failed: %0d testcase(s), %0d check(s)", fail_count, check_fail_count);
        $display("PASS: tb_spi2apb all black-box testcases passed");
        $finish;
    end

    initial begin
        #20_000_000;
        $fatal(1, "tb_spi2apb watchdog timeout");
    end

endmodule
