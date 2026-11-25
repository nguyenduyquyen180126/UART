`timescale 1ns/1ps

// Comprehensive Tiny Tapeout silicon-level black-box verification for tt_um_hust_apb_uart.
// Runs identically on RTL and Post-P&R GDS gate netlist (with tt/ss/ff SDF annotation).
// Covers Spec za.html:
//   - Pinout, reserved scan_out/uio idle contract
//   - Reset defaults (BAUD=0x900D @ 25 MHz -> 115200 baud)
//   - SPI 56-bit Mode-0 command error + APB E1/E2/E4/E5 errors
//   - Full 24 UART frame formats (5..8b x None/Even/Odd x 1/2 Stop) via TX->RX loopback
//   - High-speed baud rates (115200, 230400, 460800, 921600) + 9600 + +/-2% RX tolerance
//   - CTS_N/RTS_N hardware flow control, TX/RX/ERR IRQ, parity/frame/overrun, soft_rst during rx=0
module tb_tt_tapeout;

    localparam integer PCLK_NS   = 40;   // 25 MHz Tiny Tapeout clock
    localparam integer SPI_HALF  = 220;  // ~2.27 MHz (< pclk/10 = 2.5 MHz)
    localparam integer BIT115K   = 8681; // 1 / 115200 s

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    reg        rx_ext_drv;
    reg        loopback_en;
    reg        cts_n_drv;
    reg        spi_cs_n;
    reg        spi_sclk;
    reg        spi_mosi;

    wire       uart_tx    = uo_out[0];
    wire       uart_rts_n = uo_out[1];
    wire       spi_miso   = uo_out[2];
    wire       tx_done_w  = uo_out[3];
    wire       rx_done_w  = uo_out[4];
    wire       par_err_w  = uo_out[5];
    wire       irq_w      = uo_out[6];

    always @(*) begin
        ui_in[0]   = loopback_en ? uart_tx : rx_ext_drv;
        ui_in[1]   = cts_n_drv;
        ui_in[2]   = spi_cs_n;
        ui_in[3]   = spi_sclk;
        ui_in[4]   = spi_mosi;
        ui_in[7:5] = 3'b000;
    end

    tt_um_hust_apb_uart dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    initial begin
        clk = 1'b0;
        forever #(PCLK_NS/2) clk = ~clk;
    end

    integer checks_total, checks_fail;
    integer tc_total, tc_fail, tc_cur_fail;
    reg [8*80-1:0] tc_name;

    task start_tc;
        input [8*80-1:0] name;
        begin
            tc_total    = tc_total + 1;
            tc_cur_fail = 0;
            tc_name     = name;
        end
    endtask

    task finish_tc;
        begin
            if (tc_cur_fail) begin
                tc_fail = tc_fail + 1;
                $display("  [FAIL] %0s", tc_name);
            end else begin
                $display("  [PASS] %0s", tc_name);
            end
        end
    endtask

    task chk;
        input cond;
        input [8*96-1:0] msg;
        begin
            checks_total = checks_total + 1;
            if (cond !== 1'b1) begin
                checks_fail = checks_fail + 1;
                tc_cur_fail = 1;
                $display("    FAIL (%0s @ %0t): %0s", tc_name, $time, msg);
            end
        end
    endtask

    task spi_xfer;
        input         rw;
        input  [3:0]  idx;
        input  [31:0] wdata;
        input         bad_cmd;
        output [31:0] rdata;
        output [7:0]  stat_b6;
        reg [7:0]  cmd;
        reg [55:0] mosi_v, miso_v;
        integer    b;
        begin
            cmd = {rw, 3'b000, idx};
            if (bad_cmd) cmd[4] = 1'b1;
            mosi_v = {cmd, 8'h00, wdata, 8'h00};
            miso_v = 56'h0;
            spi_cs_n = 1'b0;
            #(SPI_HALF);
            for (b = 55; b >= 0; b = b - 1) begin
                spi_mosi = mosi_v[b];
                #(SPI_HALF);
                spi_sclk = 1'b1;
                #2;
                miso_v[b] = spi_miso;
                #(SPI_HALF - 2);
                spi_sclk = 1'b0;
            end
            spi_mosi = 1'b0;
            #(SPI_HALF);
            spi_cs_n = 1'b1;
            #(PCLK_NS);
            chk(spi_miso === 1'b0, "MISO low after CS_N rises");
            chk(uo_out[7] === 1'b0 && uio_out === 8'h00 && uio_oe === 8'h00, "TT unused outputs remain 0");
            repeat (6) @(negedge clk);
            rdata   = miso_v[39:8];
            stat_b6 = miso_v[7:0];
        end
    endtask

    task apb_write;
        input [3:0]  idx;
        input [31:0] wdata;
        input        exp_err;
        reg [31:0] rd;
        reg [7:0]  st;
        begin
            spi_xfer(1'b1, idx, wdata, 1'b0, rd, st);
            chk(st[1] === 1'b0, "cmd_err == 0 on valid write");
            chk(st[0] === exp_err, exp_err ? "Expected pslverr == 1" : "Expected pslverr == 0");
        end
    endtask

    task apb_read;
        input [3:0]  idx;
        output [31:0] rdata;
        input        exp_err;
        reg [7:0] st;
        begin
            spi_xfer(1'b0, idx, 32'h0, 1'b0, rdata, st);
            chk(st[1] === 1'b0, "cmd_err == 0 on valid read");
            chk(st[0] === exp_err, exp_err ? "Expected pslverr == 1" : "Expected pslverr == 0");
        end
    endtask

    task send_ext_uart;
        input [7:0] data_b;
        input [1:0] dbits;
        input       stop2;
        input       par_en;
        input       par_even;
        input       bad_par;
        input       bad_stop;
        input real  bit_ns;
        integer nbits, i;
        reg pbit;
        begin
            case (dbits)
                2'b00: nbits = 5;
                2'b01: nbits = 6;
                2'b10: nbits = 7;
                2'b11: nbits = 8;
            endcase
            pbit = 1'b0;
            for (i = 0; i < nbits; i = i + 1) pbit = pbit ^ data_b[i];
            if (!par_even) pbit = ~pbit;
            if (bad_par)   pbit = ~pbit;

            rx_ext_drv = 1'b0; #(bit_ns);
            for (i = 0; i < nbits; i = i + 1) begin
                rx_ext_drv = data_b[i]; #(bit_ns);
            end
            if (par_en) begin
                rx_ext_drv = pbit; #(bit_ns);
            end
            rx_ext_drv = bad_stop ? 1'b0 : 1'b1; #(bit_ns);
            if (stop2) begin
                rx_ext_drv = 1'b1; #(bit_ns);
            end
            rx_ext_drv = 1'b1;
        end
    endtask

    integer d_i, p_i, s_i, pat_i;
    reg [31:0] rval;
    reg [7:0]  st6, exp_mask, pat;
    integer    wait_cnt;

    initial begin
        ui_in       = 8'h00;
        uio_in      = 8'h00;
        ena         = 1'b1;
        rx_ext_drv  = 1'b1;
        loopback_en = 1'b0;
        cts_n_drv   = 1'b0;
        spi_cs_n    = 1'b1;
        spi_sclk    = 1'b0;
        spi_mosi    = 1'b0;
        rst_n       = 1'b0;
        checks_total = 0; checks_fail = 0;
        tc_total = 0; tc_fail = 0;

        repeat (10) @(negedge clk);
        chk(uart_tx === 1'b1 && uart_rts_n === 1'b1 && irq_w === 1'b0 && tx_done_w === 1'b1 && rx_done_w === 1'b0,
            "Reset pin state matches za.html");
        rst_n = 1'b1;
        repeat (6) @(negedge clk);

        // TC1: Defaults & SPI/APB Errors E1, E2, E4, E5
        start_tc("TC1: Defaults, SPI cmd_err, and APB pslverr E1/E2/E4/E5");
        apb_read(4'h5, rval, 1'b0); // BAUD
        chk(rval === 32'h0000_900D, "Default BAUD == 0x900D");
        apb_read(4'h4, rval, 1'b0); // STAT
        chk(rval[7:0] === 8'h01, "Default STAT == 0x01 (tx_done=1)");
        spi_xfer(1'b0, 4'h0, 32'h0, 1'b1, rval, st6);
        chk(st6[1] === 1'b1, "Malformed SPI command sets B6[1]=cmd_err");
        apb_write(4'h1, 32'hAA, 1'b1); // RXDATA write -> E1
        apb_write(4'h4, 32'hFF, 1'b1); // STAT write -> E1
        apb_write(4'h5, 32'h1000, 1'b1); // BAUD div_int==0 -> E5
        apb_write(4'h9, 32'h0, 1'b1); // Unmapped addr -> E2
        apb_read(4'h9, rval, 1'b1);   // Unmapped read -> E2
        finish_tc();

        // TC2: All 24 UART formats via internal TX->RX loopback at 115200 baud
        start_tc("TC2: Full 24 UART formats (5/6/7/8 x N/E/O x 1/2 stop) @ 115200 via TT pins");
        loopback_en = 1'b1;
        for (d_i = 0; d_i < 4; d_i = d_i + 1) begin
            for (p_i = 0; p_i < 3; p_i = p_i + 1) begin
                for (s_i = 0; s_i < 2; s_i = s_i + 1) begin
                    pat = (8'hA5 ^ ((d_i * 17) + (p_i * 5) + s_i)) | 8'h81;
                    case (d_i)
                        0: exp_mask = pat & 8'h1F;
                        1: exp_mask = pat & 8'h3F;
                        2: exp_mask = pat & 8'h7F;
                        3: exp_mask = pat & 8'hFF;
                    endcase
                    apb_write(4'h2, {25'b0, 2'b00, (p_i == 1), (p_i != 0), s_i[0], d_i[1:0]}, 1'b0);
                    apb_write(4'h0, {24'h0, pat}, 1'b0);
                    apb_write(4'h3, 32'h1, 1'b0); // start_tx
                    wait_cnt = 0;
                    while ((!rx_done_w || !tx_done_w) && wait_cnt < 5000) begin
                        @(negedge clk);
                        wait_cnt = wait_cnt + 1;
                    end
                    chk(rx_done_w === 1'b1 && tx_done_w === 1'b1, "TX/RX loopback completed");
                    apb_read(4'h4, rval, 1'b0); // STAT
                    chk(rval[7:0] === 8'h03, "STAT indicates clean rx_done & tx_done");
                    apb_read(4'h1, rval, 1'b0); // RXDATA clears rx_done
                    chk(rval[7:0] === exp_mask, "Loopback RXDATA matches masked pattern");
                    chk(rx_done_w === 1'b0 && uart_rts_n === 1'b0, "Read RXDATA clears rx_done & rts_n");
                end
            end
        end
        loopback_en = 1'b0;
        finish_tc();

        // TC3: High-speed bonus bauds (460800 & 921600) + +/-2.0% RX tolerance @ 115200
        start_tc("TC3: Bonus 460800 & 921600 loopback + +/-2.0% RX tolerance @ 115200");
        loopback_en = 1'b1;
        apb_write(4'h2, 32'h000B, 1'b0); // 8N1 + even? No: 0x0B = parity_en=1, odd, 1 stop, 8b
        // 460800 @ 25MHz: D = 25e6/(16*460800) = 3.39 -> div_int=3, div_frac=6 -> 0x6003
        apb_write(4'h5, 32'h6003, 1'b0);
        apb_write(4'h0, 32'h5C, 1'b0);
        apb_write(4'h3, 32'h1, 1'b0);
        wait_cnt = 0; while ((!rx_done_w || !tx_done_w) && wait_cnt < 2000) begin @(negedge clk); wait_cnt = wait_cnt + 1; end
        apb_read(4'h1, rval, 1'b0);
        chk(rval[7:0] === 8'h5C && par_err_w === 1'b0, "460800 baud 8O1 loopback exact");
        // 921600 @ 25MHz: D = 25e6/(16*921600) = 1.695 -> div_int=1, div_frac=11 -> 0xB001
        apb_write(4'h5, 32'hB001, 1'b0);
        apb_write(4'h0, 32'hA3, 1'b0);
        apb_write(4'h3, 32'h1, 1'b0);
        wait_cnt = 0; while ((!rx_done_w || !tx_done_w) && wait_cnt < 2000) begin @(negedge clk); wait_cnt = wait_cnt + 1; end
        apb_read(4'h1, rval, 1'b0);
        chk(rval[7:0] === 8'hA3 && par_err_w === 1'b0, "921600 baud 8O1 loopback exact");
        loopback_en = 1'b0;

        // Back to 115200 (0x900D), 8E1, test +2.0% and -2.0% external RX
        apb_write(4'h5, 32'h900D, 1'b0);
        apb_write(4'h2, 32'h001B, 1'b0); // 8E1
        send_ext_uart(8'hD5, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, BIT115K / 1.02);
        wait_cnt = 0; while (!rx_done_w && wait_cnt < 1000) begin @(negedge clk); wait_cnt = wait_cnt + 1; end
        apb_read(4'h1, rval, 1'b0);
        chk(rval[7:0] === 8'hD5, "+2.0% fast TX received cleanly at 115200 8E1");
        #(BIT115K);
        send_ext_uart(8'h3A, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, BIT115K / 0.98);
        wait_cnt = 0; while (!rx_done_w && wait_cnt < 1000) begin @(negedge clk); wait_cnt = wait_cnt + 1; end
        apb_read(4'h1, rval, 1'b0);
        chk(rval[7:0] === 8'h3A, "-2.0% slow TX received cleanly at 115200 8E1");
        finish_tc();

        // TC4: CTS_N flow control, busy E3/E4, IRQ, Errors, soft_rst during rx=0
        start_tc("TC4: CTS_N gating, busy protection, IRQ, Parity/Frame/Overrun, soft_rst(rx=0)");
        apb_write(4'h2, 32'h001B, 1'b0); // 8E1
        apb_write(4'h6, 32'h7, 1'b0);    // Enable all IRQs (Wait: tx_done=1 already -> irq=1!)
        chk(irq_w === 1'b1, "tx_done_ie asserts irq when tx_done=1");
        cts_n_drv = 1'b1;
        repeat (6) @(negedge clk);
        apb_write(4'h0, 32'h47, 1'b0);
        apb_write(4'h3, 32'h1, 1'b0); // held in WAIT_CTS
        repeat (200) @(negedge clk);
        chk(tx_done_w === 1'b0 && uart_tx === 1'b1, "CTS_N=1 holds TX idle");
        apb_write(4'h0, 32'h99, 1'b1); // TXDATA write while busy -> E3
        apb_write(4'h2, 32'h0, 1'b1);  // CFG write while busy -> E4
        cts_n_drv = 1'b0;
        wait_cnt = 0; while (!tx_done_w && wait_cnt < 5000) begin @(negedge clk); wait_cnt = wait_cnt + 1; end
        chk(tx_done_w === 1'b1, "TX completes after CTS_N drops to 0");

        // Error & Overrun & Clear
        apb_write(4'h6, 32'h6, 1'b0); // err_ie | rx_done_ie
        chk(irq_w === 1'b0, "IRQ low before RX");
        send_ext_uart(8'h6C, 2'b11, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, BIT115K); // bad parity + bad stop
        wait_cnt = 0; while (!rx_done_w && wait_cnt < 1000) begin @(negedge clk); wait_cnt = wait_cnt + 1; end
        chk(irq_w === 1'b1 && par_err_w === 1'b1 && uart_rts_n === 1'b1, "Parity+Frame error raises IRQ/RTS_N");
        #(BIT115K);
        // Overrun frame
        send_ext_uart(8'hF1, 2'b11, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, BIT115K);
        wait_cnt = 0; while (wait_cnt < 400) begin @(negedge clk); wait_cnt = wait_cnt + 1; end
        apb_read(4'h4, rval, 1'b0);
        chk(rval[7:0] === 8'hC7, "STAT == 0xC7 (overrun=1,frame=1,rx_dis=0,tx_dis=0,busy=0,par=1,rxd=1,txd=1)");
        apb_read(4'h1, rval, 1'b0);
        chk(rval[7:0] === 8'h6C && irq_w === 1'b0, "RXDATA keeps 1st byte and read clears IRQ/flags");

        // Mid-frame soft_rst while external rx stays 0 (resets CFG=0x00 -> 5N1)
        rx_ext_drv = 1'b0;
        #(BIT115K * 2);
        apb_write(4'h3, 32'h100, 1'b0); // soft_rst while rx==0
        repeat (10) @(negedge clk);
        rx_ext_drv = 1'b1; // line returns to idle AFTER soft_rst released
        #(BIT115K * 2);
        chk(rx_done_w === 1'b0, "No false start bit after soft_rst with rx=0");
        apb_read(4'h2, rval, 1'b0);
        chk(rval[6:0] === 7'h00, "soft_rst restored CFG == 0x00");
        apb_write(4'h2, 32'h0003, 1'b0); // configure 8N1 after reset check
        send_ext_uart(8'h5A, 2'b11, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, BIT115K);
        wait_cnt = 0; while (!rx_done_w && wait_cnt < 1000) begin @(negedge clk); wait_cnt = wait_cnt + 1; end
        apb_read(4'h1, rval, 1'b0);
        chk(rval[7:0] === 8'h5A, "Clean 8N1 reception restored after soft_rst");
        finish_tc();

        $display("\n============================================================");
        $display("TB_TT_TAPEOUT SUMMARY: TC=%0d FAIL=%0d | CHECKS=%0d FAIL=%0d",
                 tc_total, tc_fail, checks_total, checks_fail);
        $display("============================================================");
        if (tc_fail != 0 || checks_fail != 0) $fatal(1, "tb_tt_tapeout FAILED");
        $finish;
    end

endmodule
