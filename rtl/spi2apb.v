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
    input  wire [DATA_WIDTH-1:0] prdata
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

    // 2. COUNTER, SHARED 32-BIT DATA SHIFT REGISTER, AND MISO OUTPUT
    // TDA Tuần 13A resource sharing: B0 command shift (bits 0..7), APB read capture
    // (during B1 turnaround), and B2..B5 write/read shifting are time-multiplexed,
    // so one 32-bit shift register (without async reset -> dfxtp_1) replaces
    // separate rx_byte, tx_byte, wdata_reg, rdata_reg, and pwdata holding FFs.
    reg [5:0]  bit_cnt;
    reg [31:0] data_sr;
    reg        miso_out;

    reg        rw_reg;
    reg [3:0]  addr_reg;
    reg        cmd_err_reg;
    reg        pslverr_reg;
    reg        apb_start;

    // Gate directly with external chip select so MISO returns to 0 as soon as CS rises.
    assign spi_miso = (!spi_cs_n && cs_active) ? miso_out : 1'b0;
    assign pwrite   = rw_reg;
    assign pstrb    = rw_reg ? 4'b1111 : 4'b0000;
    assign paddr    = { {(ADDR_WIDTH-6){1'b0}}, addr_reg, 2'b00 };
    assign pwdata   = data_sr;

    // 3. APB MASTER STATE MACHINE
    localparam [1:0] APB_IDLE   = 2'b00;
    localparam [1:0] APB_SETUP  = 2'b01;
    localparam [1:0] APB_ACCESS = 2'b10;

    reg [1:0] apb_state;
    assign psel    = (apb_state != APB_IDLE);
    assign penable = (apb_state == APB_ACCESS);

    wire in_b0       = (bit_cnt[5:3] == 3'b000);
    wire in_b2_to_b5 = bit_cnt[5] ^ bit_cnt[4];

    always @(posedge pclk) begin
        if (apb_state == APB_ACCESS && pready && !pwrite) begin
            data_sr <= prdata;
        end else if (cs_active && !cs_falling) begin
            if (clk_rising && (in_b0 || (rw_reg && in_b2_to_b5))) begin
                data_sr <= {data_sr[30:0], mosi_sync};
            end else if (clk_falling && !rw_reg && !cmd_err_reg && in_b2_to_b5) begin
                data_sr <= {data_sr[30:0], 1'b0};
            end
        end
    end

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            bit_cnt     <= 6'b0;
            miso_out    <= 1'b0;
            rw_reg      <= 1'b0;
            addr_reg    <= 4'd0;
            cmd_err_reg <= 1'b0;
            apb_start   <= 1'b0;
        end else begin
            apb_start <= 1'b0;

            if (cs_falling) begin
                bit_cnt     <= 6'b0;
                miso_out    <= 1'b0;
                cmd_err_reg <= 1'b0;
            end else if (cs_active) begin
                // Sample MOSI command/trigger points on rising edge of SCLK.
                if (clk_rising) begin
                    bit_cnt <= bit_cnt + 1'b1;

                    if (bit_cnt == 6'd7) begin
                        rw_reg   <= data_sr[6];
                        addr_reg <= {data_sr[2:0], mosi_sync};
                        if (data_sr[5:3] != 3'b000) begin
                            cmd_err_reg <= 1'b1;
                        end else if (data_sr[6] == 1'b0) begin
                            apb_start <= 1'b1;
                        end
                    end else if (bit_cnt == 6'd47) begin
                        if (rw_reg && !cmd_err_reg) begin
                            apb_start <= 1'b1;
                        end
                    end
                end

                // Shift MISO on falling edge of SCLK.
                if (clk_falling) begin
                    if (!rw_reg && !cmd_err_reg && in_b2_to_b5) begin
                        miso_out <= data_sr[31];
                    end else if (bit_cnt == 6'd54) begin
                        miso_out <= cmd_err_reg;
                    end else if (bit_cnt == 6'd55) begin
                        miso_out <= pslverr_reg;
                    end else begin
                        miso_out <= 1'b0;
                    end
                end
            end
        end
    end

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            apb_state   <= APB_IDLE;
            pslverr_reg <= 1'b0;
        end else begin
            if (cs_falling) begin
                pslverr_reg <= 1'b0;
            end

            case (apb_state)
                APB_IDLE: begin
                    if (apb_start) begin
                        apb_state <= APB_SETUP;
                    end
                end
                APB_SETUP: begin
                    apb_state <= APB_ACCESS;
                end
                APB_ACCESS: begin
                    if (pready) begin
                        pslverr_reg <= pslverr;
                        apb_state   <= APB_IDLE;
                    end
                end
                default: apb_state <= APB_IDLE;
            endcase
        end
    end

endmodule
/* verilator lint_on DECLFILENAME */
