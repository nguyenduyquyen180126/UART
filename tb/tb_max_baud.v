`timescale 1ns/1ps

// =============================================================================
// Module: tb_max_baud
// Description: Black-box Max Baud Rate Verification Testbench (V2 PPA Signoff)
//   Proves the theoretical spec ceiling under doc/specs/za.html:
//     * BAUD = 16'h0001 (div_int = 1, div_frac = 0) -> 16 pclk cycles per bit
//       At 25 MHz TT clock (40 ns period): T_bit = 640 ns -> 1,562,500 bps!
//     * BAUD = 16'h0000 (div_int = 0) -> rejected with E5 (pslverr = 1).
//   Tests BOTH:
//     1) Chip-level tt_um_hust_apb_uart (SPI -> APB -> UART TX -> RX loopback)
//        - Legal ceiling BAUD = 16'h0001 (1.5625 Mbps @ 25 MHz) across formats
//          (8N1, 8E1, 8O2, 5N1, 7E1), back-to-back streaming, and E5 rejection.
//     2) External golden UART peer driving RX at 1.5625 Mbps with +/-2.0%
//        clock deviation (1,531,250 bps and 1,593,750 bps) to verify spec
//        Section 7 tolerance holds even at div_int = 1!
//   Zero internal DUT hierarchical references -> directly reusable for Post-P&R
//   SDF Gate-Level Simulation (G8).
// =============================================================================
module tb_max_baud;

    localparam integer PCLK_PERIOD_NS = 40;   // 25 MHz Tiny Tapeout clock
    localparam integer SPI_HALF_NS    = 200;  // 2.5 MHz SPI SCLK (pclk/10)
    localparam integer MAX_BIT_NS     = 640;  // 16 * 1 * 40 ns = 640 ns -> 1,562,500 bps

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    reg        loopback_en;
    reg        ext_rx;

    wire uart_tx       = uo_out[0];
    wire uart_rts_n    = uo_out[1];
    wire spi_miso      = uo_out[2];
    wire tx_done_pin   = uo_out[3];
    wire rx_done_pin   = uo_out[4];
    wire parity_err_p  = uo_out[5];
    wire uart_irq      = uo_out[6];

    reg  spi_cs_n;
    reg  spi_sclk;
    reg  spi_mosi;
    reg  cts_n;

    always @(*) begin
        ui_in = {3'b000, spi_mosi, spi_sclk, spi_cs_n, cts_n, (loopback_en ? uart_tx : ext_rx)};
    end

    tt_um_hust_apb_uart dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    always #(PCLK_PERIOD_NS/2) clk = ~clk;

    integer checks;
    integer fails;

    task check_cond;
        input cond;
        input [8*88-1:0] msg;
        begin
            checks = checks + 1;
            if (cond !== 1'b1) begin
                fails = fails + 1;
                $display("  [FAIL] %0s (t=%0t)", msg, $time);
            end
        end
    endtask

    task spi_xfer;
        input         rw;
        input  [3:0]  reg_idx;
        input  [31:0] wdata;
        output [31:0] rdata;
        output [7:0]  status;
        reg [55:0] mosi_f;
        reg [55:0] miso_f;
        integer i;
        begin
            mosi_f = {{rw, 3'b000, reg_idx}, 8'h00, wdata, 8'h00};
            miso_f = 56'h0;
            spi_cs_n = 1'b0;
            #(SPI_HALF_NS);
            for (i = 55; i >= 0; i = i - 1) begin
                spi_mosi = mosi_f[i];
                #(SPI_HALF_NS);
                spi_sclk = 1'b1;
                #2;
                miso_f[i] = spi_miso;
                #(SPI_HALF_NS - 2);
                spi_sclk = 1'b0;
            end
            spi_mosi = 1'b0;
            #(SPI_HALF_NS);
            spi_cs_n = 1'b1;
            repeat (5) @(negedge clk);
            rdata  = miso_f[39:8];
            status = miso_f[7:0];
        end
    endtask

    task wr_reg;
        input  [3:0]  idx;
        input  [31:0] val;
        output [7:0]  st;
        reg    [31:0] dummy;
        begin
            spi_xfer(1'b1, idx, val, dummy, st);
        end
    endtask

    task rd_reg;
        input  [3:0]  idx;
        output [31:0] val;
        output [7:0]  st;
        begin
            spi_xfer(1'b0, idx, 32'h0, val, st);
        end
    endtask

    // Loopback one byte at 1.5625 Mbps and verify TX bit timing + RX data/status
    task test_loopback_byte;
        input [7:0] tx_byte;
        input [7:0] exp_byte;
        input [8*64-1:0] label;
        reg [31:0] rdata;
        reg [7:0]  st;
        integer    wait_cyc;
        begin
            wr_reg(4'h0, {24'h0, tx_byte}, st);
            check_cond(st === 8'h00, "TXDATA write OK");
            wr_reg(4'h3, 32'h0000_0001, st);
            check_cond(st === 8'h00, "CTRL.start_tx OK");

            wait_cyc = 0;
            while ((rx_done_pin !== 1'b1 || tx_done_pin !== 1'b1) && wait_cyc < 500) begin
                @(posedge clk);
                wait_cyc = wait_cyc + 1;
            end
            check_cond(wait_cyc < 500, "1.5625 Mbps loopback completed within 500 pclk");
            check_cond(tx_done_pin === 1'b1, "tx_done=1 after max-baud frame");
            check_cond(rx_done_pin === 1'b1, "rx_done=1 after max-baud frame");
            check_cond(parity_err_p === 1'b0, "no parity error on loopback");

            rd_reg(4'h4, rdata, st);
            check_cond((rdata[7:0] & 8'hC7) === 8'h03, "STAT clean (tx_done=1, rx_done=1, no errs)");

            rd_reg(4'h1, rdata, st);
            check_cond(rdata === {24'h0, exp_byte}, label);
            if (rdata !== {24'h0, exp_byte})
                $display("    got 0x%08x, expected 0x%02x (%0s)", rdata, exp_byte, label);
        end
    endtask

    // Drive an external 8N1 frame at arbitrary bit period (for +/-2% tolerance at 1.5625 Mbps)
    task send_ext_rx_8n1;
        input [7:0] val;
        input real  bit_ns;
        integer b;
        begin
            ext_rx = 1'b0;
            #(bit_ns);
            for (b = 0; b < 8; b = b + 1) begin
                ext_rx = val[b];
                #(bit_ns);
            end
            ext_rx = 1'b1;
            #(bit_ns * 1.5);
        end
    endtask

    // Measure actual TX bit duration from falling start edge to rising edge of 0x55 (alternating 10101010)
    task measure_tx_baud_8n1;
        time t_start, t_stop;
        integer elapsed_ns;
        reg [7:0] st;
        begin
            // 0xAA = 8'b1010_1010 (LSB first: 0,1,0,1,0,1,0,1)
            // Start=0, D0=0, D1=1 -> rising edge at exactly 2 * T_bit = 1280 ns after start falling edge
            wr_reg(4'h0, 32'h0000_00AA, st);
            fork
                begin
                    @(negedge uart_tx);
                    t_start = $time;
                    @(posedge uart_tx);
                    t_stop = $time;
                end
                begin
                    wr_reg(4'h3, 32'h0000_0001, st);
                end
            join
            elapsed_ns = t_stop - t_start;
            $display("  [MEAS] 2-bit duration at BAUD=0x0001 (25 MHz): %0d ns (ideal = %0d ns -> %0.3f Mbps)",
                     elapsed_ns, 2 * MAX_BIT_NS, 2000.0 / elapsed_ns);
            // Allow +/-10 ns for post-P&R SDF propagation skew
            check_cond(elapsed_ns >= (2*MAX_BIT_NS - 10) && elapsed_ns <= (2*MAX_BIT_NS + 10),
                       "Measured TX bit period matches exact 1.5625 Mbps (640 ns/bit)");
            // Wait for frame to complete and drain RX
            repeat (300) @(posedge clk);
        end
    endtask

    reg [31:0] rdata;
    reg [7:0]  st;
    integer    k;
    reg [7:0]  stream_bytes [0:7];

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        ena         = 1'b1;
        uio_in      = 8'h00;
        spi_cs_n    = 1'b1;
        spi_sclk    = 1'b0;
        spi_mosi    = 1'b0;
        cts_n       = 1'b0;
        loopback_en = 1'b1;
        ext_rx      = 1'b1;
        checks      = 0;
        fails       = 0;

        stream_bytes[0] = 8'h00;
        stream_bytes[1] = 8'hFF;
        stream_bytes[2] = 8'h55;
        stream_bytes[3] = 8'hAA;
        stream_bytes[4] = 8'hA5;
        stream_bytes[5] = 8'h5A;
        stream_bytes[6] = 8'h3C;
        stream_bytes[7] = 8'hC3;

        repeat (6) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        $display("\n=== [1] Spec Ceiling E5 Guard: BAUD=0x0000 rejected, BAUD=0x0001 accepted ===");
        wr_reg(4'h5, 32'h0000_0000, st); // div_int=0 -> E5 error!
        check_cond(st === 8'h01, "BAUD=0x0000 rejected with E5 (pslverr=1)");
        wr_reg(4'h5, 32'h0000_F000, st); // div_int=0, div_frac=15 -> STILL E5!
        check_cond(st === 8'h01, "BAUD=0xF000 rejected with E5 (pslverr=1)");

        wr_reg(4'h5, 32'h0000_0001, st); // div_int=1, div_frac=0 -> 1,562,500 bps @ 25 MHz!
        check_cond(st === 8'h00, "BAUD=0x0001 accepted (1.5625 Mbps @ 25 MHz)");
        rd_reg(4'h5, rdata, st);
        check_cond(rdata === 32'h0000_0001, "BAUD=0x0001 readback verified");

        $display("\n=== [2] Direct TX Bit-Period Measurement at 1,562,500 bps ===");
        wr_reg(4'h2, 32'h0000_0003, st); // 8N1
        measure_tx_baud_8n1();
        rd_reg(4'h1, rdata, st); // Drain RXDATA from measurement frame
        check_cond(rdata === 32'h0000_00AA, "Measurement frame 0xAA received cleanly at 1.5625 Mbps");

        $display("\n=== [3] Back-to-Back 8-Byte Streaming Loopback at 1.5625 Mbps (8N1) ===");
        for (k = 0; k < 8; k = k + 1) begin
            test_loopback_byte(stream_bytes[k], stream_bytes[k], "8N1 1.5625 Mbps loopback match");
        end

        $display("\n=== [4] Multi-Format Matrix at 1.5625 Mbps (8E1, 8O2, 7E1, 5N1) ===");
        // 8E1: data=11, stop=0, par_en=1, par_type=1 -> 0x1B
        wr_reg(4'h2, 32'h0000_001B, st);
        test_loopback_byte(8'hA5, 8'hA5, "8E1 1.5625 Mbps loopback 0xA5");
        test_loopback_byte(8'h01, 8'h01, "8E1 1.5625 Mbps loopback 0x01");

        // 8O2: data=11, stop=1, par_en=1, par_type=0 -> 0x0F
        wr_reg(4'h2, 32'h0000_000F, st);
        test_loopback_byte(8'h5A, 8'h5A, "8O2 1.5625 Mbps loopback 0x5A");
        test_loopback_byte(8'hFF, 8'hFF, "8O2 1.5625 Mbps loopback 0xFF");

        // 7E1: data=10, stop=0, par_en=1, par_type=1 -> 0x1A (high bit zero-masked!)
        wr_reg(4'h2, 32'h0000_001A, st);
        test_loopback_byte(8'hFF, 8'h7F, "7E1 1.5625 Mbps zero-mask 0xFF->0x7F");

        // 5N1: data=00, stop=0, par_en=0 -> 0x00 (bits 7:5 zero-masked!)
        wr_reg(4'h2, 32'h0000_0000, st);
        test_loopback_byte(8'hFF, 8'h1F, "5N1 1.5625 Mbps zero-mask 0xFF->0x1F");

        $display("\n=== [5] Fractional High-Speed Baud BAUD=0x8001 (div=1.5 -> 1,041,667 bps) ===");
        wr_reg(4'h5, 32'h0000_8001, st); // D = 1 + 8/16 = 1.5 -> 1,041,667 bps
        check_cond(st === 8'h00, "BAUD=0x8001 accepted (1.0417 Mbps fractional)");
        wr_reg(4'h2, 32'h0000_001B, st); // 8E1
        test_loopback_byte(8'h69, 8'h69, "8E1 1.0417 Mbps fractional loopback 0x69");
        test_loopback_byte(8'h96, 8'h96, "8E1 1.0417 Mbps fractional loopback 0x96");

        $display("\n=== [6] External RX Tolerance (+/-2.0%%) at 1.5625 Mbps (BAUD=0x0001) ===");
        loopback_en = 1'b0;
        ext_rx      = 1'b1;
        wr_reg(4'h5, 32'h0000_0001, st);
        wr_reg(4'h2, 32'h0000_0003, st); // 8N1
        repeat (20) @(posedge clk);

        // -2.0% slower baud (+2.04% longer bit period = 653.06 ns)
        send_ext_rx_8n1(8'hD5, 653.06);
        rd_reg(4'h1, rdata, st);
        check_cond(rdata === 32'h0000_00D5, "1.5625 Mbps RX -2.0% baud tolerance (0xD5)");

        // +2.0% faster baud (-1.96% shorter bit period = 627.45 ns)
        send_ext_rx_8n1(8'h2B, 627.45);
        rd_reg(4'h1, rdata, st);
        check_cond(rdata === 32'h0000_002B, "1.5625 Mbps RX +2.0% baud tolerance (0x2B)");

        $display("\n======================================================================");
        $display("MAX BAUD VERIFICATION SUMMARY: CHECKS=%0d FAIL=%0d (Peak = 1,562,500 bps @ 25 MHz)", checks, fails);
        $display("======================================================================");
        if (fails != 0)
            $fatal(1, "tb_max_baud FAILED with %0d error(s)", fails);
        $display("PASS: tb_max_baud all checks passed!");
        $finish;
    end

    initial begin
        #5_000_000;
        $fatal(1, "tb_max_baud watchdog timeout");
    end

endmodule
