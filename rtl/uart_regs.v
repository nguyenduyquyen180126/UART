module uart_regs (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        reg_pread,
    input  wire        reg_pwrite,
    input  wire [11:0] reg_paddr,
    input  wire [31:0] reg_pwdata,
    output reg  [31:0] reg_prdata,
    output reg         reg_ack_err,
    output wire        irq,

    output wire [1:0]  data_bit_num,
    output wire        stop_bit_num,
    output wire        parity_en,
    output wire        parity_type,
    output wire [1:0]  baud_sel,
    input  wire        rx_busy,
    input  wire        tx_busy,

    output reg         tx_fifo_wr_en,
    output wire [7:0]  tx_fifo_wr_data,
    input  wire        tx_fifo_full,
    input  wire        tx_fifo_empty,

    output reg         rx_fifo_rd_en,
    input  wire [8:0]  rx_fifo_rd_data,
    input  wire        rx_fifo_empty,
    input  wire        rx_fifo_full,
    input  wire        rx_overrun_err
);

    localparam [11:0] ADDR_TX   = 12'h000; 
    localparam [11:0] ADDR_RX   = 12'h004; 
    localparam [11:0] ADDR_CFG  = 12'h008; 
    localparam [11:0] ADDR_STT  = 12'h00C;
    localparam [11:0] ADDR_IER  = 12'h010; 

    reg [6:0] cfg_reg; // [1:0] data_bits, [2] stop_bit, [3] parity_en, [4] parity_type, [6:5] baud_sel
    reg [2:0] ier_reg; // [0] rx_irq_en, [1] tx_irq_en, [2] overrun_irq_en
    reg       overrun_latch;

    wire tx_ready  = (!tx_busy) && tx_fifo_empty;
    wire rx_ready  = !rx_fifo_empty;
    wire uart_idle = tx_ready && (!rx_busy);

    assign tx_fifo_wr_data = reg_pwdata[7:0];

    always @(*) begin
        reg_prdata    = 32'h0;
        tx_fifo_wr_en = 1'b0;
        rx_fifo_rd_en = 1'b0;
        reg_ack_err   = 1'b0;

        if (reg_pwrite) begin
            case (reg_paddr)
                ADDR_TX: begin
                    if (!tx_fifo_full) tx_fifo_wr_en = 1'b1;
                    else               reg_ack_err   = 1'b1;
                end
                ADDR_CFG: begin
                    if (uart_idle)     ;
                    else               reg_ack_err   = 1'b1;
                end
                ADDR_IER: begin
                    // Luôn cho phép ghi IER
                end
                default:  reg_ack_err = 1'b1;
            endcase
        end else if (reg_pread) begin
            case (reg_paddr)
                ADDR_RX: begin
                    reg_prdata    = rx_ready ? {23'd0, rx_fifo_rd_data} : 32'h0;
                    rx_fifo_rd_en = rx_ready;
                end
                ADDR_CFG: reg_prdata = {25'd0, cfg_reg};
                ADDR_STT: reg_prdata = {26'd0, rx_fifo_full, tx_fifo_full, overrun_latch, (rx_ready && rx_fifo_rd_data[8]), rx_ready, tx_ready};
                ADDR_IER: reg_prdata = {29'd0, ier_reg};
                default:  reg_ack_err = 1'b1;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_reg <= 7'h0;
            ier_reg <= 3'h0;
        end else if (reg_pwrite && !reg_ack_err) begin
            case (reg_paddr)
                ADDR_CFG: cfg_reg <= reg_pwdata[6:0];
                ADDR_IER: ier_reg <= reg_pwdata[2:0];
                default:  ;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            overrun_latch <= 1'b0;
        else if (rx_fifo_rd_en)
            overrun_latch <= 1'b0;
        else if (rx_overrun_err)
            overrun_latch <= 1'b1;
    end

    assign irq = (rx_ready      & ier_reg[0]) |
                 (tx_ready      & ier_reg[1]) |
                 (overrun_latch & ier_reg[2]);

    assign data_bit_num = cfg_reg[1:0];
    assign stop_bit_num = cfg_reg[2];
    assign parity_en    = cfg_reg[3];
    assign parity_type  = cfg_reg[4];
    assign baud_sel     = cfg_reg[6:5];

endmodule