`timescale 1ns/1ps
// Reproducible evidence for the architecture note. No CPU core is simulated.
module tb_bus_probe;
    parameter MERLIN = 0;
    parameter ADDR_MODE = 0;
    parameter EXPECT_LAST_RX = 0;
    reg clk = 0;
    always #10 clk = ~clk;
    reg reset_n = 0;
    reg rd = 0, wr = 0;
    reg [11:0] addr = 0;
    reg [31:0] wd = 0;
    wire [31:0] data;
    wire [1:0] response;
    wire waitrequest;
    wire [11:0] paddr;
    wire [31:0] pwdata, prdata;
    wire psel, penable, pwrite, pready, pslverr;
    wire tx, irq;
    reg [105:0] cp_data = 0;
    reg cp_valid = 0;
    wire cp_ready, rp_valid;
    wire [105:0] rp_data;
    reg rp_ready = 0;
    integer completions = 0;
    integer expected_completions = 0;
    reg previous_setup = 0;
    reg previous_access = 0;
    reg [44:0] previous_command = 0;

    generate if (!MERLIN) begin : custom_path
        avalon2apb #(.ADDR_MODE(ADDR_MODE)) bridge (
            .clk(clk), .reset_n(reset_n), .avl_chipselect(1'b1),
            .avl_read(rd), .avl_write(wr), .avl_address(addr),
            .avl_writedata(wd), .avl_byteenable(4'hf),
            .avl_readdata(data), .avl_waitrequest(waitrequest),
            .avl_response(response), .pclk(), .preset_n(),
            .paddr(paddr), .pwdata(pwdata), .psel(psel),
            .penable(penable), .pwrite(pwrite),
            .pready(pready), .prdata(prdata), .pslverr(pslverr)
        );
    end else begin : generated_path
        wire [11:0] agent_addr;
        wire [31:0] agent_wdata, agent_rdata;
        wire agent_sel, agent_enable, agent_write, agent_ready, agent_error;
        wire debug_addr;
        // Values read from system_mm_interconnect_0.v in the Quartus project.
        altera_merlin_apb_slave_agent #(
            .ADDR_WIDTH(12), .DATA_WIDTH(32),
            .PKT_DATA_H(31), .PKT_DATA_L(0), .PKT_BEGIN_BURST(85),
            .PKT_SYMBOL_W(8), .PKT_BYTEEN_H(35), .PKT_BYTEEN_L(32),
            .PKT_ADDR_H(67), .PKT_ADDR_L(36),
            .PKT_TRANS_COMPRESSED_READ(68), .PKT_TRANS_POSTED(69),
            .PKT_TRANS_WRITE(70), .PKT_TRANS_READ(71), .PKT_TRANS_LOCK(72),
            .PKT_SRC_ID_H(89), .PKT_SRC_ID_L(87),
            .PKT_DEST_ID_H(92), .PKT_DEST_ID_L(90),
            .PKT_BURSTWRAP_H(77), .PKT_BURSTWRAP_L(77),
            .PKT_BYTE_CNT_H(76), .PKT_BYTE_CNT_L(74),
            .PKT_PROTECTION_H(96), .PKT_PROTECTION_L(94),
            .PKT_RESPONSE_STATUS_H(102), .PKT_RESPONSE_STATUS_L(101),
            .PKT_THREAD_ID_H(93), .PKT_THREAD_ID_L(93),
            .PKT_CACHE_H(100), .PKT_CACHE_L(97),
            .PKT_DATA_SIDEBAND_H(84), .PKT_DATA_SIDEBAND_L(84),
            .PKT_QOS_H(86), .PKT_QOS_L(86),
            .PKT_ADDR_SIDEBAND_H(83), .PKT_ADDR_SIDEBAND_L(83),
            .PKT_BURST_SIZE_H(80), .PKT_BURST_SIZE_L(78),
            .PKT_BURST_TYPE_H(82), .PKT_BURST_TYPE_L(81),
            .PKT_TRANS_EXCLUSIVE(73),
            .PKT_ORI_BURST_SIZE_H(105), .PKT_ORI_BURST_SIZE_L(103),
            .ST_CHANNEL_W(6), .ST_DATA_W(106)
        ) agent (
            .clk(clk), .reset(!reset_n),
            .cp_valid(cp_valid), .cp_ready(cp_ready), .cp_data(cp_data),
            .cp_channel(6'b1), .cp_startofpacket(1'b1), .cp_endofpacket(1'b1),
            .rp_valid(rp_valid), .rp_ready(rp_ready), .rp_data(rp_data),
            .rp_startofpacket(), .rp_endofpacket(),
            .paddr(agent_addr), .pwdata(agent_wdata), .prdata(agent_rdata),
            .psel(agent_sel), .penable(agent_enable), .pwrite(agent_write),
            .pready(agent_ready), .pslverr(agent_error), .paddr31(debug_addr)
        );
        altera_merlin_apb_translator #(
            .ADDR_WIDTH(12), .DATA_WIDTH(32), .USE_S0_PADDR31(1),
            .USE_M0_PADDR31(0), .USE_M0_PSLVERR(1)
        ) translator (
            .clk(clk), .reset(!reset_n),
            .s0_paddr(agent_addr), .s0_pwdata(agent_wdata), .s0_prdata(agent_rdata),
            .s0_psel(agent_sel), .s0_penable(agent_enable), .s0_pwrite(agent_write),
            .s0_pready(agent_ready), .s0_pslverr(agent_error), .s0_paddr31(debug_addr),
            .m0_paddr(paddr), .m0_pwdata(pwdata), .m0_prdata(prdata),
            .m0_psel(psel), .m0_penable(penable), .m0_pwrite(pwrite),
            .m0_pready(pready), .m0_pslverr(pslverr), .m0_paddr31()
        );
        assign data = rp_data[31:0];
        assign response = rp_data[102:101];
    end endgenerate

    apb_uart uart (
        .clk(clk), .rst_n(reset_n), .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .psel(psel), .penable(penable), .pwrite(pwrite),
        .pready(pready), .pslverr(pslverr), .tx(tx), .rx(tx), .irq(irq)
    );

    // Check protocol at the receiving edge, before nonblocking updates.
    always @(posedge clk) if (reset_n) begin
        if (psel && penable && !previous_access && !previous_setup)
            $fatal(1, "ACCESS without SETUP");
        if (psel && penable && previous_setup &&
            {paddr,pwrite,pwdata} !== previous_command)
            $fatal(1, "Address/control/data changed between SETUP and ACCESS");
        if (psel && penable && pready) completions = completions + 1;
        previous_setup <= psel && !penable;
        previous_access <= psel && penable;
        previous_command <= {paddr,pwrite,pwdata};
    end

    task transfer(input bit write_op, input [11:0] offset,
                  input [31:0] value, input [1:0] expected_response,
                  output [31:0] result);
        integer timeout;
        reg [105:0] saved_response;
        begin
            expected_completions = expected_completions + 1;
            @(negedge clk);
            if (!MERLIN) begin
                addr = ADDR_MODE ? (offset >> 2) : offset;
                wd = value; wr = write_op; rd = !write_op;
                timeout = 0;
                @(posedge clk);
                while (waitrequest) begin
                    timeout = timeout + 1;
                    if (timeout > 20) $fatal(1, "Avalon timeout");
                    @(posedge clk);
                end
                result = data;
                if (response !== expected_response)
                    $fatal(1, "Avalon response %b expected %b", response, expected_response);
                @(negedge clk); rd = 0; wr = 0;
            end else begin
                cp_data = 0;
                cp_data[31:0] = value;
                cp_data[35:32] = 4'hf;
                cp_data[67:36] = 32'h20000 + offset;
                cp_data[70] = write_op; cp_data[71] = !write_op;
                cp_data[80:78] = 3'd2;
                cp_data[105:103] = 3'd2;
                cp_valid = 1;
                timeout = 0;
                @(posedge clk);
                while (!cp_ready) begin
                    timeout = timeout + 1;
                    if (timeout > 20) $fatal(1, "Merlin command timeout");
                    @(posedge clk);
                end
                @(negedge clk); cp_valid = 0;
                while (!rp_valid) @(negedge clk);
                saved_response = rp_data;
                result = data;
                if (response !== expected_response)
                    $fatal(1, "Merlin response %b expected %b", response, expected_response);
                // Force response backpressure. An RX read must pop only once.
                repeat (3) begin
                    @(negedge clk);
                    if (!rp_valid || rp_data !== saved_response)
                        $fatal(1, "Response not held during backpressure");
                end
                rp_ready = 1;
                @(posedge clk);
                @(negedge clk); rp_ready = 0;
            end
        end
    endtask

    reg [31:0] value;
    integer polls;
    initial begin
        repeat (4) @(negedge clk);
        reset_n = 1;
        transfer(0,12'h00c,0,0,value);
        if (value !== 1) $fatal(1,"Reset STT %h",value);
        transfer(1,12'h008,32'h43,0,value);
        transfer(0,12'h008,0,0,value);
        if (value !== 'h43) $fatal(1,"CFG readback %h",value);
        transfer(1,12'h00c,1,2'b10,value);
        transfer(0,12'h014,0,2'b10,value);
        transfer(1,12'h010,5,0,value);
        transfer(0,12'h010,0,0,value);
        if (value !== 5) $fatal(1,"IER readback %h",value);
        transfer(1,12'h000,32'h41,0,value);
        transfer(1,12'h008,32'h7f,2'b10,value);
        transfer(0,12'h008,0,0,value);
        if (value !== 'h43) $fatal(1,"Protected CFG corrupted");
        polls = 0; value = 0;
        while (!value[1]) begin
            transfer(0,12'h00c,0,0,value);
            polls = polls + 1;
            if (polls > 22000) $fatal(1,"UART loopback timeout");
        end
        if (!irq) $fatal(1,"Local RX IRQ missing");
        transfer(0,12'h004,0,0,value);
        if (value !== 'h41) $fatal(1,"RX data %h",value);
        transfer(0,12'h00c,0,0,value);
        if (value[1] || irq) $fatal(1,"RX popped more/less than once");
        transfer(0,12'h004,0,0,value);
        if (value !== (EXPECT_LAST_RX ? 32'h41 : 32'h0))
            $fatal(1,"Empty RX behavior %h",value);
        if (MERLIN || !ADDR_MODE) begin
            transfer(0,12'h009,0,MERLIN ? 2'b00 : 2'b10,value);
            if (MERLIN && value !== 'h43) $fatal(1,"Merlin alignment behavior");
        end
        if (completions != expected_completions)
            $fatal(1,"APB side effect count %0d expected %0d",completions,expected_completions);
        $display("PASS MERLIN=%0d ADDR_MODE=%0d LAST_RX=%0d; %0d APB transfers; UART loopback A; errors; response stability",MERLIN,ADDR_MODE,EXPECT_LAST_RX,completions);
        $finish;
    end
    initial begin #5_000_000; $fatal(1,"Global timeout"); end
endmodule
