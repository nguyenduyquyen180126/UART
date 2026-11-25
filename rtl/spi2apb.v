`timescale 1ns/1ps
/* verilator lint_off DECLFILENAME */
module spi2apb_apb_master #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
)(
    input  wire                  pclk,
    input  wire                  presetn,

    input  wire                  spi_cs_n,
    input  wire                  spi_clk,
    input  wire                  spi_mosi,
    output wire                  spi_miso,

    output wire                  psel,
    output wire                  penable,
    output wire                  pwrite,
    output wire [ADDR_WIDTH-1:0] paddr,
    output wire [3:0]            pstrb,
    output wire [DATA_WIDTH-1:0] pwdata,
    input  wire                  pready,
    input  wire                  pslverr,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [DATA_WIDTH-1:0] prdata // APB-UART registers are <=16b; prdata[31:16]==0
    /* verilator lint_on UNUSEDSIGNAL */
);

    // 1. INPUT SYNCHRONIZATION AND EDGE DETECTION (2-FF sync into pclk domain)
    reg [2:0] clk_pipe;
    reg [2:0] cs_n_pipe;
    reg [1:0] mosi_pipe;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            clk_pipe  <= 3'b000;
            cs_n_pipe <= 3'b111;
            mosi_pipe <= 2'b00;
        end else begin
            clk_pipe  <= {clk_pipe[1:0], spi_clk};
            cs_n_pipe <= {cs_n_pipe[1:0], spi_cs_n};
            mosi_pipe <= {mosi_pipe[0], spi_mosi};
        end
    end

    wire cs_active   = ~cs_n_pipe[1];
    wire cs_falling  = cs_n_pipe[2] & ~cs_n_pipe[1];
    wire clk_rising  = ~clk_pipe[2] & clk_pipe[1];
    wire clk_falling = clk_pipe[2] & ~clk_pipe[1];
    wire mosi_sync   = mosi_pipe[1];

    // 2. V2 PPA-OPTIMIZED SHARED 16-BIT DATA SHIFT REGISTER (dfxtp_1, no async reset)
    // Spec (za.html Sec. 4): All APB-UART registers reside in bits [15:0] (BAUD is 16b,
    // CTRL uses bits 8 & 0, all other regs <= 8b; prdata[31:16] == 16'h0, pwdata[31:16] ignored).
    // Shrinking data_sr from 32b to 16b saves 16 FFs (~550 um^2 + dynamic power):
    //   - B0 (bits  0.. 7, bit_cnt[5:3]==3'b000): shift MOSI command byte into data_sr[7:0]
    //   - B2-B3 (bits 16..31, bit_cnt[5:4]==2'b01): READ outputs 0 on MISO; WRITE ignores MOSI
    //   - B4-B5 (bits 32..47, bit_cnt[5:4]==2'b10): READ shifts data_sr[15:0]; WRITE shifts MOSI
    reg [5:0]  bit_cnt;
    reg [15:0] data_sr;
    reg        miso_out;

    reg        rw_reg;
    reg [3:0]  addr_reg;
    reg        cmd_err_reg;
    reg        pslverr_reg;

    // Gate directly with external chip select so MISO returns to 0 as soon as CS rises.
    assign spi_miso = (!spi_cs_n && cs_active) ? miso_out : 1'b0;
    assign pwrite   = rw_reg;
    assign pstrb    = rw_reg ? 4'b1111 : 4'b0000;
    assign paddr    = { {(ADDR_WIDTH-6){1'b0}}, addr_reg, 2'b00 };
    assign pwdata   = { {(DATA_WIDTH-16){1'b0}}, data_sr };

    // 3. APB MASTER STATE MACHINE (direct transition on bit 7 / bit 47 eliminates apb_start FF)
    localparam [1:0] APB_IDLE   = 2'b00;
    localparam [1:0] APB_SETUP  = 2'b01;
    localparam [1:0] APB_ACCESS = 2'b10;

    reg [1:0] apb_state;
    assign psel    = (apb_state != APB_IDLE);
    assign penable = (apb_state == APB_ACCESS);

    wire in_b0      = (bit_cnt[5:3] == 3'b000);
    wire in_b4_b5   = (bit_cnt[5:4] == 2'b10);
    wire active_sck = cs_active & ~cs_falling;

    wire start_apb_read  = active_sck & clk_rising & (bit_cnt == 6'd7) &
                           (data_sr[5:3] == 3'b000) & (~data_sr[6]);
    wire start_apb_write = active_sck & clk_rising & (bit_cnt == 6'd47) &
                           rw_reg & (~cmd_err_reg);
    wire start_apb       = start_apb_read | start_apb_write;

    // Datapath registers without async reset (-> Sky130 dfxtp_1, -20% FF area, lighter rst_n tree).
    // All are deterministically initialized on cs_falling or bit_cnt==7 before ever being consumed.
    always @(posedge pclk) begin
        if (apb_state == APB_ACCESS && pready && !pwrite) begin
            data_sr <= prdata[15:0];
        end else if (active_sck) begin
            if (clk_rising && (in_b0 || (rw_reg && in_b4_b5))) begin
                data_sr <= {data_sr[14:0], mosi_sync};
            end else if (clk_falling && !rw_reg && !cmd_err_reg && in_b4_b5) begin
                data_sr <= {data_sr[14:0], 1'b0};
            end
        end

        if (cs_falling) begin
            bit_cnt     <= 6'd0;
            cmd_err_reg <= 1'b0;
            pslverr_reg <= 1'b0;
        end else begin
            if (cs_active && clk_rising) begin
                bit_cnt <= bit_cnt + 6'd1;
                if (bit_cnt == 6'd7) begin
                    rw_reg   <= data_sr[6];
                    addr_reg <= {data_sr[2:0], mosi_sync};
                    if (data_sr[5:3] != 3'b000) begin
                        cmd_err_reg <= 1'b1;
                    end
                end
            end
            if (apb_state == APB_ACCESS && pready) begin
                pslverr_reg <= pslverr;
            end
        end
    end

    // Async-reset control/output registers (guaranteed deterministic immediately on reset).
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            miso_out  <= 1'b0;
            apb_state <= APB_IDLE;
        end else begin
            if (cs_falling) begin
                miso_out <= 1'b0;
            end else if (cs_active && clk_falling) begin
                if (!rw_reg && !cmd_err_reg && in_b4_b5) begin
                    miso_out <= data_sr[15];
                end else if (bit_cnt == 6'd54) begin
                    miso_out <= cmd_err_reg;
                end else if (bit_cnt == 6'd55) begin
                    miso_out <= pslverr_reg;
                end else begin
                    miso_out <= 1'b0;
                end
            end

            case (apb_state)
                APB_IDLE: begin
                    if (start_apb) begin
                        apb_state <= APB_SETUP;
                    end
                end
                APB_SETUP: begin
                    apb_state <= APB_ACCESS;
                end
                APB_ACCESS: begin
                    if (pready) begin
                        apb_state <= APB_IDLE;
                    end
                end
                default: apb_state <= APB_IDLE;
            endcase
        end
    end

endmodule
/* verilator lint_on DECLFILENAME */
