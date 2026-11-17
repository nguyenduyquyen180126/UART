`timescale 1ns/1ps

// Black-box system test for the SPI-to-APB UART wrapper.
// Stimulus and expected behavior are taken from doc/specs/za.html:
//   * SPI mode 0, MSB first, fixed 56-bit frames
//   * register map and status/error behavior
//   * 8N1 TX/RX at the reset BAUD value (25 MHz pclk, 115200 baud)
// No internal DUT signals are referenced.
module tb_spi2apb;

    localparam integer PCLK_PERIOD_NS = 40;
    localparam integer SPI_HALF_NS    = 200;  // SCLK = pclk/10
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

            if (spi_miso !== 1'b0)
                $fatal(1, "SPI MISO must be 0 while spi_cs_n is high");
            rx_payload = miso_frame[39:8];
            rx_status  = miso_frame[7:0];
            checks = checks + 1;
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
            if (actual !== expected)
                $fatal(1, "%0s: expected 0x%08x, got 0x%08x", label_text, expected, actual);
            checks = checks + 1;
        end
    endtask

    task expect_eq8;
        input [7:0] actual;
        input [7:0] expected;
        input [8*80-1:0] label_text;
        begin
            if (actual !== expected)
                $fatal(1, "%0s: expected 0x%02x, got 0x%02x", label_text, expected, actual);
            checks = checks + 1;
        end
    endtask

    task expect_high;
        input signal_value;
        input [8*80-1:0] label_text;
        begin
            if (signal_value !== 1'b1)
                $fatal(1, "%0s: expected logic 1, got %b", label_text, signal_value);
            checks = checks + 1;
        end
    endtask

    task expect_low;
        input signal_value;
        input [8*80-1:0] label_text;
        begin
            if (signal_value !== 1'b0)
                $fatal(1, "%0s: expected logic 0, got %b", label_text, signal_value);
            checks = checks + 1;
        end
    endtask

    // Receive and check the externally visible 8N1 serial frame.
    task check_uart_tx_8n1;
        input [7:0] expected_byte;
        integer bit_number;
        begin
            @(negedge tx);
            #(UART_BIT_NS/2);
            if (tx !== 1'b0)
                $fatal(1, "TX start bit was not low at its midpoint");
            checks = checks + 1;

            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                #(UART_BIT_NS);
                if (tx !== expected_byte[bit_number])
                    $fatal(1, "TX data bit %0d: expected %b, got %b",
                           bit_number, expected_byte[bit_number], tx);
                checks = checks + 1;
            end

            #(UART_BIT_NS);
            if (tx !== 1'b1)
                $fatal(1, "TX stop bit was not high at its midpoint");
            checks = checks + 1;
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

        repeat (5) @(posedge pclk);
        // During active-low reset, the external serial outputs are idle and
        // RTS_N is inactive. Once reset is released, the empty enabled RX
        // receiver advertises readiness with RTS_N low (spec sections 2/6.4).
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

        // A reserved command bit is a bridge-level command error and must not
        // issue an APB access. Confirm the addressed register stays unchanged.
        spi_frame(1'b1, 4'h2, 32'h0000_0000, 1'b1, ignored_value, status);
        expect_eq8(status, 8'h02, "malformed command status");
        read_reg(4'h2, read_value, status); // CFG
        expect_eq32(read_value, 32'h0, "malformed command did not write CFG");

        // Configure 8N1 and verify ordinary register write/read operation.
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

        // Enable TX-done interrupt, queue a byte, and prove CTS gates the
        // transfer. Then check the serial waveform while an E4 BAUD write is
        // attempted during the active transmit frame.
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

        expect_high(tx, "TX returns to idle after frame");
        expect_high(irq, "TX-done interrupt asserted");
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value & 32'h1, 32'h1, "STAT.tx_done after TX");
        read_reg(4'h5, read_value, status);
        expect_eq32(read_value, 32'h0000_900D, "busy BAUD write has no effect");

        // RX-done interrupt, received data, RTS flow control, and read-clear.
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

        // Error interrupt and read-clear behavior for a bad stop bit.
        write_reg(4'h6, 32'h0000_0004, status); // IER.err_ie
        send_uart_rx_8n1(8'hC3, 1'b0);
        expect_high(irq, "framing error interrupt asserted");
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value & 32'h0000_0044, 32'h0000_0044,
                    "STAT reports rx_done and frame_err");
        read_reg(4'h1, read_value, status);
        expect_eq32(read_value, 32'h0000_00C3, "RXDATA with framing error");
        expect_low(irq, "RXDATA read clears framing error IRQ");

        // A second unread character is dropped and sets overrun; old RXDATA
        // remains intact until software reads it.
        send_uart_rx_8n1(8'h96, 1'b1);
        send_uart_rx_8n1(8'h69, 1'b1);
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value & 32'h0000_0082, 32'h0000_0082,
                    "STAT reports rx_done and overrun");
        expect_high(irq, "overrun error interrupt asserted");
        read_reg(4'h1, read_value, status);
        expect_eq32(read_value, 32'h0000_0096, "overrun preserves unread RXDATA");
        expect_low(irq, "RXDATA read clears overrun IRQ");

        // Soft reset restores register/engine state and output idle levels.
        write_reg(4'h3, 32'h0000_0100, status); // CTRL.soft_rst
        repeat (4) @(posedge pclk);
        read_reg(4'h2, read_value, status);
        expect_eq32(read_value, 32'h0, "CFG after soft reset");
        read_reg(4'h6, read_value, status);
        expect_eq32(read_value, 32'h0, "IER after soft reset");
        read_reg(4'h4, read_value, status);
        expect_eq32(read_value, 32'h1, "STAT after soft reset");
        expect_high(tx, "TX idle after soft reset");
        expect_high(rts_n, "RTS_N after soft reset");
        expect_low(irq, "IRQ after soft reset");

        $display("PASS: tb_spi2apb completed %0d black-box checks", checks);
        $finish;
    end

    initial begin
        #20_000_000;
        $fatal(1, "tb_spi2apb watchdog timeout");
    end

endmodule
