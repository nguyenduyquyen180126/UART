`timescale 1ns/1ps

// Black-box APB-UART verification derived from doc/specs/za.html.
// The DUT is observed only through its APB and UART ports.
module tb_apb_uart;
    localparam integer CLK_PERIOD = 40;
    localparam integer CLK_FREQ = 25_000_000;
    localparam [11:0] A_TXDATA = 12'h000;
    localparam [11:0] A_RXDATA = 12'h004;
    localparam [11:0] A_CFG    = 12'h008;
    localparam [11:0] A_CTRL   = 12'h00c;
    localparam [11:0] A_STAT   = 12'h010;
    localparam [11:0] A_BAUD   = 12'h014;
    localparam [11:0] A_IER    = 12'h018;

    reg pclk, presetn, psel, penable, pwrite;
    reg [11:0] paddr;
    reg [3:0] pstrb;
    reg [31:0] pwdata;
    wire pready, pslverr;
    wire [31:0] prdata;
    reg rx, cts_n;
    wire tx, rts_n, irq;

    integer checks, failures, testcase;
    reg [255:0] testcase_name;
    integer baud_rate, bit_ns;
    reg [31:0] rdata;
    reg err;

    apb_uart #(.CLK_FREQ(CLK_FREQ)) dut (
        .pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
        .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
        .pready(pready), .pslverr(pslverr), .prdata(prdata),
        .cts_n(cts_n), .tx(tx), .rx(rx), .rts_n(rts_n), .irq(irq)
    );

    always #(CLK_PERIOD / 2) pclk = ~pclk;

    initial begin
        if (!$test$plusargs("NO_VCD")) begin
            $dumpfile("wave_apb_uart.vcd");
            $dumpvars(0, tb_apb_uart);
        end
    end

    task begin_testcase;
        input integer number;
        input [255:0] name;
        begin
            testcase = number;
            testcase_name = name;
            $display("\n[TESTCASE %0d] %0s", testcase, testcase_name);
        end
    endtask

    task check;
        input condition;
        input [255:0] message;
        begin
            checks = checks + 1;
            if (!condition) begin
                failures = failures + 1;
                $display("[FAIL][TC%0d %0s] %0s at %0t", testcase, testcase_name, message, $time);
            end else begin
                $display("[PASS][TC%0d %0s] %0s", testcase, testcase_name, message);
            end
        end
    endtask

    task apb_transfer;
        input write;
        input [11:0] address;
        input [31:0] write_data;
        input [3:0] strobe;
        output [31:0] read_data;
        output bus_error;
        begin
            @(negedge pclk);
            psel = 1'b1; penable = 1'b0; pwrite = write;
            paddr = address; pwdata = write_data; pstrb = strobe;
            @(negedge pclk);
            penable = 1'b1;
            @(posedge pclk);
            #1;
            read_data = prdata;
            bus_error = pslverr;
            check(pready === 1'b1, "APB access completes with pready = 1");
            @(negedge pclk);
            psel = 1'b0; penable = 1'b0; pwrite = 1'b0;
            paddr = 12'b0; pwdata = 32'b0; pstrb = 4'b0;
        end
    endtask

    task apb_write;
        input [11:0] address;
        input [31:0] write_data;
        input [3:0] strobe;
        output bus_error;
        reg [31:0] unused;
        begin
            apb_transfer(1'b1, address, write_data, strobe, unused, bus_error);
        end
    endtask

    task apb_read;
        input [11:0] address;
        output [31:0] read_data;
        output bus_error;
        begin
            apb_transfer(1'b0, address, 32'b0, 4'b0, read_data, bus_error);
        end
    endtask

    function [7:0] mask_data;
        input [7:0] value;
        input [1:0] width;
        begin
            mask_data = value & (8'hff >> (3 - width));
        end
    endfunction

    function parity_value;
        input [7:0] value;
        input [1:0] width;
        input parity_type;
        integer k, ones;
        begin
            ones = 0;
            for (k = 0; k < 5 + width; k = k + 1)
                ones = ones + ((value >> k) & 1);
            // CFG.parity_type: 1 = even, 0 = odd.  The parity bit makes
            // data + parity have the selected overall parity.
            parity_value = parity_type ? (ones % 2) : !(ones % 2);
        end
    endfunction

    // cfg: [1:0] data width (5..8), [2] two stops, [3] parity enable,
    // [4] even parity. This is the encoding defined by za.html.
    task send_frame;
        input [7:0] value;
        input [6:0] cfg;
        input parity_bad;
        input stop1_bad;
        input stop2_bad;
        integer k, stops, width;
        reg parity;
        begin
            width = 5 + cfg[1:0];
            stops = 1 + cfg[2];
            parity = parity_value(value, cfg[1:0], cfg[4]);
            rx = 1'b1;
            #(bit_ns);
            rx = 1'b0;
            #(bit_ns);
            for (k = 0; k < width; k = k + 1) begin
                rx = value[k];
                #(bit_ns);
            end
            if (cfg[3]) begin
                rx = parity ^ parity_bad;
                #(bit_ns);
            end
            rx = stop1_bad ? 1'b0 : 1'b1;
            #(bit_ns);
            if (stops == 2) begin
                rx = stop2_bad ? 1'b0 : 1'b1;
                #(bit_ns);
            end
            rx = 1'b1;
            #(bit_ns);
        end
    endtask

    task check_rx_frame;
        input [7:0] value;
        input [6:0] cfg;
        input parity_bad;
        input stop1_bad;
        input stop2_bad;
        reg [31:0] status, received;
        begin
            send_frame(value, cfg, parity_bad, stop1_bad, stop2_bad);
            repeat (3) @(posedge pclk);
            apb_read(A_STAT, status, err);
            check(!err && status[1], "RX sets rx_done after a complete frame");
            check(status[2] === ((cfg[3] && parity_bad) ? 1'b1 : 1'b0),
                  "RX parity_err matches the received parity");
            check(status[6] === ((stop1_bad || (cfg[2] && stop2_bad)) ? 1'b1 : 1'b0),
                  "RX frame_err checks every stop bit");
            apb_read(A_RXDATA, received, err);
            check(!err && received[7:0] === mask_data(value, cfg[1:0]),
                  "RXDATA contains the masked received character");
            repeat (3) @(posedge pclk);
            apb_read(A_STAT, status, err);
            check(!err && !status[1] && !status[2] && !status[6] && !status[7],
                  "Reading RXDATA clears RX status flags");
        end
    endtask

    task check_tx_frame;
        input [7:0] value;
        input [6:0] cfg;
        integer k, width, stops;
        reg expected, sampled;
        reg [31:0] status;
        begin
            cts_n = 1'b0;
            apb_write(A_TXDATA, value, 4'b0001, err);
            check(!err, "TXDATA accepts one character");
            apb_write(A_CTRL, 32'h0000_0001, 4'b0001, err);
            check(!err, "CTRL.start_tx accepts a transmit request");
            width = 5 + cfg[1:0];
            stops = 1 + cfg[2];
            @(negedge tx);
            #(bit_ns / 2);
            check(tx === 1'b0, "TX start bit is low");
            #(bit_ns);
            for (k = 0; k < width; k = k + 1) begin
                sampled = tx;
                expected = value[k];
                check(sampled === expected, "TX data bit is LSB first");
                #(bit_ns);
            end
            if (cfg[3]) begin
                sampled = tx;
                expected = parity_value(value, cfg[1:0], cfg[4]);
                check(sampled === expected, "TX parity bit follows CFG");
                #(bit_ns);
            end
            repeat (stops) begin
                check(tx === 1'b1, "TX stop bit is high");
                apb_read(A_STAT, status, err);
                check(!err && status[0] === 1'b0,
                      "tx_done remains low while a stop bit is in progress");
                #(bit_ns);
            end
            apb_read(A_STAT, status, err);
            check(!err && status[0] && tx === 1'b1, "TX returns idle with tx_done set");
        end
    endtask

    task check_error_matrix;
        reg [31:0] before_value, after_value;
        begin
            apb_write(12'h001, 32'hdead_beef, 4'b1111, err);
            check(err, "E1 rejects an unaligned address");
            apb_read(12'h002, rdata, err);
            check(err && rdata === 32'b0, "E1 rejects an invalid read and returns zero");
            apb_write(A_RXDATA, 32'h1, 4'b1111, err);
            check(err, "E2 rejects RXDATA writes");
            apb_write(A_STAT, 32'h1, 4'b1111, err);
            check(err, "E2 rejects STAT writes");
            apb_write(A_BAUD, 32'h0000_0000, 4'b1111, err);
            check(err, "E5 rejects BAUD with div_int equal to zero");
            apb_read(A_BAUD, before_value, err);
            apb_write(A_BAUD, 32'h0000_900d, 4'b1111, err);
            check(!err, "BAUD accepts a valid full-word write");
            apb_write(A_TXDATA, 32'h55, 4'b0000, err);
            check(!err, "A zero pstrb write has no error");
            apb_read(A_TXDATA, after_value, err);
            check(!err && after_value === 0, "A zero pstrb write has no side effect");
        end
    endtask

    task check_busy_write_errors;
        reg [31:0] status;
        begin
            apb_write(A_CFG, 32'h0000_0003, 4'b0001, err);
            check(!err, "CFG selects an enabled 8N1 frame before busy-write checks");
            cts_n = 1'b1;
            repeat (4) @(posedge pclk);
            apb_write(A_TXDATA, 32'h0000_005a, 4'b0001, err);
            apb_write(A_CTRL, 32'h0000_0001, 4'b0001, err);
            repeat (4) @(posedge pclk);
            #1;
            apb_write(A_TXDATA, 32'h0000_00a5, 4'b0001, err);
            check(err, "E3 rejects TXDATA writes while TX is pending");
            apb_write(A_CTRL, 32'h0000_0001, 4'b0001, err);
            check(err, "E3 rejects a second start_tx request while TX is pending");
            apb_write(A_CFG, 32'h0000_0007, 4'b0001, err);
            check(err, "E4 rejects CFG writes while TX is pending");
            apb_write(A_BAUD, 32'h0000_900d, 4'b1111, err);
            check(err, "E4 rejects BAUD writes while TX is pending");
            cts_n = 1'b0;
            #(12 * bit_ns);
            apb_read(A_STAT, status, err);
            check(!err && status[0] && tx === 1'b1,
                  "TX completes after CTS permits the pending frame");
            #bit_ns;
        end
    endtask

    task check_partial_writes;
        reg [31:0] value;
        begin
            apb_write(A_BAUD, 32'h0000_000d, 4'b1111, err);
            apb_write(A_BAUD, 32'h0000_0000, 4'b0010, err);
            apb_read(A_BAUD, value, err);
            check(!err && value[15:8] === 8'h00 && value[7:0] === 8'h0d,
                  "BAUD byte lanes follow pstrb");
            apb_write(A_CFG, 32'h0000_0043, 4'b1111, err);
            apb_write(A_CFG, 32'h0000_0000, 4'b0010, err);
            apb_read(A_CFG, value, err);
            check(!err && value[7:0] === 8'h43, "CFG ignores unselected byte lanes");
        end
    endtask

    task check_cts_and_rts;
        reg [31:0] status;
        begin
            // Keep the TX format from TC3 (8-bit odd parity), but enable RX
            // so the RTS checks exercise the documented ready/full behavior.
            apb_write(A_CFG, 32'h0000_000b, 4'b0001, err);
            check(!err, "CFG enables RX for RTS flow-control checks");
            cts_n = 1'b1;
            // Let the asynchronous CTS level reach the required two-flop
            // synchronizer before issuing the transmit request.
            repeat (4) @(posedge pclk);
            #1;
            apb_write(A_TXDATA, 8'h96, 4'b0001, err);
            apb_write(A_CTRL, 32'h0000_0001, 4'b0001, err);
            repeat (4) @(posedge pclk);
            #1;
            apb_read(A_STAT, status, err);
            check(!err && tx === 1'b1 && status[0] === 1'b0,
                  "TX remains pending while synchronized cts_n is high");
            cts_n = 1'b0;
            // CTS is asynchronous and the spec requires a two-flop
            // synchronizer; allow it and the TX state machine to respond.
            repeat (8) @(posedge pclk);
            #1;
            check(tx === 1'b0, "TX starts after cts_n is asserted");
            #(12 * bit_ns);
            apb_read(A_STAT, status, err);
            check(!err && status[0], "TX completes after CTS release");
            repeat (3) @(posedge pclk);
            check(rts_n === 1'b0, "RTS is asserted while RXDATA is empty");
            send_frame(8'h5a, 7'h43, 1'b0, 1'b0, 1'b0);
            repeat (3) @(posedge pclk);
            #(bit_ns / 2);
            check(rts_n === 1'b1, "RTS deasserts when RXDATA is occupied");
            apb_read(A_RXDATA, rdata, err);
            repeat (3) @(posedge pclk);
            check(rts_n === 1'b0, "RTS reasserts after RXDATA is read");
        end
    endtask

    task check_irq;
        reg [31:0] status;
        begin
            apb_write(A_CFG, 32'h0000_000b, 4'b0001, err);
            check(!err, "CFG enables RX for interrupt checks");
            apb_write(A_IER, 32'h7, 4'b0001, err);
            check(!err, "IER enables all interrupt sources");
            apb_read(A_STAT, status, err);
            check(irq === 1'b1, "tx_done interrupt is level high when enabled");
            apb_write(A_IER, 32'h0, 4'b0001, err);
            check(irq === 1'b0, "IRQ clears when all sources are masked");
            apb_write(A_IER, 32'h2, 4'b0001, err);
            send_frame(8'h33, 7'h0b, 1'b0, 1'b0, 1'b0);
            #(bit_ns / 2);
            check(irq === 1'b1, "rx_done_ie asserts IRQ when RXDATA becomes full");
            apb_read(A_RXDATA, rdata, err);
            #(CLK_PERIOD);
            check(irq === 1'b0, "Reading RXDATA clears the rx_done interrupt source");
            apb_write(A_IER, 32'h4, 4'b0001, err);
            send_frame(8'h33, 7'h0b, 1'b1, 1'b0, 1'b0);
            #(bit_ns / 2);
            check(irq === 1'b1, "err_ie asserts IRQ for a parity error");
            apb_read(A_RXDATA, rdata, err);
            #(CLK_PERIOD);
            check(irq === 1'b0, "Reading RXDATA clears the parity-error interrupt source");
        end
    endtask

    task check_overrun;
        reg [31:0] status, first_value, second_value;
        begin
            apb_write(A_IER, 32'h0, 4'b0001, err);
            apb_write(A_CFG, 32'h0000_0003, 4'b0001, err);
            check(!err, "CFG enables RX for overrun checks");
            send_frame(8'h11, 7'h43, 1'b0, 1'b0, 1'b0);
            repeat (3) @(posedge pclk);
            send_frame(8'hee, 7'h43, 1'b0, 1'b0, 1'b0);
            repeat (3) @(posedge pclk);
            apb_read(A_STAT, status, err);
            check(status[1] && status[7], "A second unread RX character sets overrun");
            apb_read(A_RXDATA, first_value, err);
            repeat (3) @(posedge pclk);
            check(first_value[7:0] === 8'h11, "Overrun preserves the first RX character");
            apb_read(A_STAT, status, err);
            check(!status[7] && status[1] === 1'b0, "Reading RXDATA clears overrun and rx_done");
            apb_read(A_RXDATA, second_value, err);
            check(second_value[7:0] === 8'h11, "No hidden FIFO entry exists after overrun");
        end
    endtask

    task check_soft_reset;
        reg [31:0] value;
        begin
            apb_write(A_CFG, 32'h7f, 4'b0001, err);
            apb_write(A_IER, 32'h7, 4'b0001, err);
            apb_write(A_CTRL, 32'h100, 4'b0011, err);
            // soft_rst is a one-cycle pulse. Check the pins while that reset
            // pulse is still active, as specified; once released, CFG=0 means
            // RX is enabled and the empty receiver may assert RTS.
            check(tx === 1'b1 && rts_n === 1'b1,
                  "Soft reset drives UART pins idle during reset pulse");
            #(2 * CLK_PERIOD);
            apb_read(A_CFG, value, err);
            check(!err && value === 0, "Soft reset restores CFG");
            apb_read(A_BAUD, value, err);
            check(!err && value === 32'h0000_900d, "Soft reset restores BAUD");
            apb_read(A_IER, value, err);
            check(!err && value === 0, "Soft reset restores IER");
            check(tx === 1'b1 && rts_n === 1'b0,
                  "After reset release, empty enabled RX asserts RTS");
        end
    endtask

    integer width_i, parity_i, stop_i;
    reg [6:0] cfg_i;
    initial begin
        pclk = 1'b0; presetn = 1'b0; psel = 1'b0; penable = 1'b0;
        pwrite = 1'b0; paddr = 0; pstrb = 0; pwdata = 0;
        rx = 1'b1; cts_n = 1'b0; checks = 0; failures = 0;
        testcase = 0; testcase_name = "initialization";
        baud_rate = 115200;
        bit_ns = 1_000_000_000 / baud_rate;
        #200; presetn = 1'b1; #(2 * CLK_PERIOD);

        apb_read(A_STAT, rdata, err);
        check(!err && rdata === 32'h1, "Reset STAT has tx_done set only");
        apb_read(A_BAUD, rdata, err);
        check(!err && rdata === 32'h0000_900d, "Reset BAUD is 0x900D");
        apb_read(A_CFG, rdata, err);
        check(!err && rdata === 0, "Reset CFG is zero");

        begin_testcase(1, "reset and register defaults");
        check_error_matrix();
        check_busy_write_errors();
        begin_testcase(2, "partial writes and pstrb");
        check_partial_writes();
        apb_write(A_BAUD, 32'h0000_900d, 4'b1111, err);
        apb_write(A_CFG, 32'h0000_004b, 4'b1111, err);
        begin_testcase(3, "TX frame format");
        check_tx_frame(8'ha5, 7'h4b);
        // Leave the transmitter idle for a complete bit after the observed
        // stop interval before starting the independent CTS test.
        #(bit_ns);
        begin_testcase(4, "CTS and RTS flow control");
        check_cts_and_rts();

        // All 24 mandatory UART formats: 5..8 data, no/even/odd parity, 1/2 stop.
        for (width_i = 0; width_i < 4; width_i = width_i + 1)
            for (parity_i = 0; parity_i < 3; parity_i = parity_i + 1)
                for (stop_i = 0; stop_i < 2; stop_i = stop_i + 1) begin
                    testcase = 100 + (width_i * 24) + (parity_i * 2) + stop_i;
                    testcase_name = "UART format matrix";
                    cfg_i = width_i | (stop_i << 2);
                    if (parity_i != 0) cfg_i = cfg_i | 7'h08;
                    if (parity_i == 1) cfg_i = cfg_i | 7'h10;
                    apb_write(A_CFG, {25'b0, cfg_i}, 4'b0001, err);
                    check(!err, "CFG accepts each mandatory UART format");
                    check_rx_frame(8'ha5, cfg_i, 1'b0, 1'b0, 1'b0);
                    check_tx_frame(8'ha5, cfg_i);
                    // Allow the final stop interval to finish before CFG is
                    // changed for the next format.
                    #(bit_ns);
                end

        begin_testcase(5, "parity and framing errors");
        apb_write(A_CFG, 32'h0000_000b, 4'b0001, err);
        check(!err, "CFG enables RX for parity and framing error checks");
        check_rx_frame(8'h7b, 7'h0b, 1'b1, 1'b0, 1'b0);
        apb_write(A_CFG, 32'h0000_0007, 4'b0001, err);
        check(!err, "CFG selects 8-bit two-stop format for stop error checks");
        check_rx_frame(8'h55, 7'h07, 1'b0, 1'b1, 1'b0);
        check_rx_frame(8'haa, 7'h07, 1'b0, 1'b0, 1'b1);
        begin_testcase(6, "level IRQ behavior");
        check_irq();
        begin_testcase(7, "single-entry RX overrun");
        check_overrun();
        begin_testcase(8, "software reset");
        check_soft_reset();

        $display("\nAPB-UART DV: %0d checks, %0d failures", checks, failures);
        if (failures != 0) $fatal(1, "APB-UART verification failed");
        $finish;
    end
endmodule
