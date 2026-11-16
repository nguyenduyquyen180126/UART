module spi2apb #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
)(
    input  wire                  pclk,
    input  wire                  presetn,

    input  wire                  spi_cs_n,
    input  wire                  spi_clk,  
    input  wire                  spi_mosi,
    output wire                  spi_miso,

    output reg                   psel,
    output reg                   penable,
    output reg                   pwrite,
    output reg  [ADDR_WIDTH-1:0] paddr,
    output wire [3:0]            pstrb,
    output reg  [DATA_WIDTH-1:0] pwdata,
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

    // 2. COUNTER AND SHIFT REGISTERS
    reg [5:0]  bit_cnt;
    reg [7:0]  rx_byte;
    reg [7:0]  tx_byte;

    reg        rw_reg;
    reg [3:0]  addr_reg;
    reg [31:0] wdata_reg;
    reg [31:0] rdata_reg;
    reg        cmd_err_reg;
    reg        pslverr_reg;
    reg        apb_start;

    assign spi_miso = cs_active ? tx_byte[7] : 1'b0;
    assign pstrb    = (pwrite) ? 4'b1111 : 4'b0000;

    wire [7:0] rx_byte_next = {rx_byte[6:0], mosi_sync};

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            bit_cnt     <= 6'b0;
            rx_byte     <= 8'b0;
            tx_byte     <= 8'b0;
            rw_reg      <= 1'b0;
            addr_reg    <= 4'd0;
            wdata_reg   <= 32'd0;
            cmd_err_reg <= 1'b0;
            apb_start   <= 1'b0;
        end else begin
            apb_start <= 1'b0;

            if (cs_falling) begin
                bit_cnt     <= 6'b0;
                rx_byte     <= 8'b0;
                tx_byte     <= 8'b0;
                cmd_err_reg <= 1'b0;
            end else if (cs_active) begin
                // Sample MOSI on rising edge of SCLK
                if (clk_rising) begin
                    bit_cnt <= bit_cnt + 1'b1;
                    rx_byte <= rx_byte_next;

                    case (bit_cnt)
                        6'd7: begin
                            rw_reg   <= rx_byte_next[7];
                            addr_reg <= rx_byte_next[3:0];
                            if (rx_byte_next[6:4] != 3'b000) begin
                                cmd_err_reg <= 1'b1;
                            end else if (rx_byte_next[7] == 1'b0) begin
                                apb_start <= 1'b1;
                            end
                        end
                        6'd23: wdata_reg[31:24] <= rx_byte_next;
                        6'd31: wdata_reg[23:16] <= rx_byte_next;
                        6'd39: wdata_reg[15:8]  <= rx_byte_next;
                        6'd47: begin
                            wdata_reg[7:0] <= rx_byte_next;
                            if (rw_reg && !cmd_err_reg) begin
                                apb_start <= 1'b1;
                            end
                        end
                        default: ;
                    endcase
                end

                // Shift MISO on falling edge of SCLK
                if (clk_falling) begin
                    case (bit_cnt)
                        6'd8:  tx_byte <= 8'h00;
                        6'd16: tx_byte <= (!rw_reg && !cmd_err_reg) ? rdata_reg[31:24] : 8'h00;
                        6'd24: tx_byte <= (!rw_reg && !cmd_err_reg) ? rdata_reg[23:16] : 8'h00;
                        6'd32: tx_byte <= (!rw_reg && !cmd_err_reg) ? rdata_reg[15:8]  : 8'h00;
                        6'd40: tx_byte <= (!rw_reg && !cmd_err_reg) ? rdata_reg[7:0]   : 8'h00;
                        6'd48: tx_byte <= 8'h00;
                        6'd54: tx_byte <= {cmd_err_reg, 7'b0};
                        6'd55: tx_byte <= {pslverr_reg, 7'b0};
                        default: tx_byte <= {tx_byte[6:0], 1'b0};
                    endcase
                end
            end
        end
    end

    // 3. APB MASTER STATE MACHINE
    localparam [1:0] APB_IDLE   = 2'b00;
    localparam [1:0] APB_SETUP  = 2'b01;
    localparam [1:0] APB_ACCESS = 2'b10;

    reg [1:0] apb_state;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            apb_state   <= APB_IDLE;
            psel        <= 1'b0;
            penable     <= 1'b0;
            pwrite      <= 1'b0;
            paddr       <= {12{1'b0}};
            pwdata      <= {32{1'b0}};
            rdata_reg   <= 32'd0;
            pslverr_reg <= 1'b0;
        end else begin
            if (cs_falling) begin
                pslverr_reg <= 1'b0;
                rdata_reg   <= 32'd0;
            end

            case (apb_state)
                APB_IDLE: begin
                    psel    <= 1'b0;
                    penable <= 1'b0;
                    if (apb_start) begin
                        psel      <= 1'b1;
                        pwrite    <= rw_reg;
                        paddr     <= { {(12-6){1'b0}}, addr_reg, 2'b00 };
                        pwdata    <= wdata_reg;
                        apb_state <= APB_SETUP;
                    end
                end
                APB_SETUP: begin
                    penable   <= 1'b1;
                    apb_state <= APB_ACCESS;
                end
                APB_ACCESS: begin
                    if (pready) begin
                        psel        <= 1'b0;
                        penable     <= 1'b0;
                        pslverr_reg <= pslverr;
                        if (!pwrite) begin
                            rdata_reg <= prdata;
                        end
                        apb_state <= APB_IDLE;
                    end
                end
                default: apb_state <= APB_IDLE;
            endcase
        end
    end

endmodule
