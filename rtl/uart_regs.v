module uart_regs (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        reg_pread, 
    input  wire        reg_pwrite,  
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        reg_ack_err,
    output wire        irq,

    output wire [1:0]  data_bit_num,
    output wire        stop_bit_num,
    output wire        parity_en,
    output wire        parity_type,
    output wire [1:0]  baud_sel,
    input  wire        rx_busy,

    output wire        tx_fifo_wr_en,
    output wire [7:0]  tx_fifo_wr_data,
    input  wire        tx_fifo_full,
    input  wire        tx_fifo_empty,
    input  wire        tx_busy,

    output wire        rx_fifo_rd_en,
    input  wire [8:0]  rx_fifo_rd_data,
    input  wire        rx_fifo_empty,
    input  wire        rx_fifo_full,
    input  wire        rx_overrun_err
);

    localparam [11:0] ADDR_TX   = 12'h000;
    localparam [11:0] ADDR_RX   = 12'h004;
    localparam [11:0] ADDR_CFG  = 12'h008;
    localparam [11:0] ADDR_STT  = 12'h010;
    localparam [11:0] ADDR_IER  = 12'h014;

    reg [6:0] cfg_reg;
    reg [2:0] ier_reg;

    wire addr_tx   = (paddr == ADDR_TX);
    wire addr_rx   = (paddr == ADDR_RX);
    wire addr_cfg  = (paddr == ADDR_CFG);
    wire addr_stt  = (paddr == ADDR_STT);
    wire addr_ier  = (paddr == ADDR_IER);

    wire tx_ready  = (!tx_busy) && tx_fifo_empty;
    wire uart_idle = tx_ready && (!rx_busy);

    // Ghi TX hop le khi TX FIFO chua day
    wire write_legal = (addr_tx   && !tx_fifo_full) ||
                       (addr_cfg  && uart_idle)     ||
                       (addr_ier);

    wire read_legal  = addr_tx || addr_rx || addr_cfg || addr_stt || addr_ier;

    wire valid_write = reg_pwrite && write_legal;
    wire valid_read  = reg_pread  && read_legal;

    assign reg_ack_err = (reg_pwrite && !write_legal) || 
                         (reg_pread  && !read_legal);

    // Tin hieu dieu khien FIFO truc tiep theo chu ky bus APB hop le
    assign tx_fifo_wr_en   = valid_write && addr_tx;
    assign tx_fifo_wr_data = pwdata[7:0];
    assign rx_fifo_rd_en   = valid_read  && addr_rx && (!rx_fifo_empty);

    reg [8:0] last_rx_data;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            last_rx_data <= 9'd0;
        else if (rx_fifo_rd_en)
            last_rx_data <= rx_fifo_rd_data;
    end

    // 1. Quan ly ghi thanh ghi
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_reg <= 7'h0;
            ier_reg <= 3'h0;
        end else if (valid_write) begin
            case (paddr)
                ADDR_CFG: cfg_reg <= pwdata[6:0];
                ADDR_IER: ier_reg <= pwdata[2:0];
                default: ;
            endcase
        end
    end

    // 2. Quan ly co Overrun Error Latch
    reg overrun_latch;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            overrun_latch <= 1'b0;
        else if (rx_fifo_rd_en)
            overrun_latch <= 1'b0; // Tu dong ha khi CPU doc du lieu RX
        else if (rx_overrun_err)
            overrun_latch <= 1'b1;
    end

    // 3. Trang thai STT tuong thich cao
    wire rx_ready    = !rx_fifo_empty;
    wire rx_byte_err = rx_ready && rx_fifo_rd_data[8];

    reg [31:0] stt_reg;
    always @(*) begin
        stt_reg = 32'h0;
        stt_reg[0] = tx_ready;       // Bit 0: TX Ready / Empty
        stt_reg[1] = rx_ready;       // Bit 1: RX Data Available
        stt_reg[2] = rx_byte_err;   // Bit 2: Parity/Frame error cua byte hien tai
        stt_reg[3] = overrun_latch;  // Bit 3: Overrun error
        stt_reg[4] = tx_fifo_full;   // Bit 4: TX FIFO Full
        stt_reg[5] = rx_fifo_full;   // Bit 5: RX FIFO Full
    end

    // 4. Doc du lieu ra prdata
    always @(*) begin
        if (valid_read) begin
            case (paddr)
                ADDR_TX:   prdata = 32'h0;
                ADDR_RX:   prdata = {23'd0, (rx_fifo_rd_en ? rx_fifo_rd_data : last_rx_data)}; // [7:0] data, [8] error
                ADDR_CFG:  prdata = {25'd0, cfg_reg};
                ADDR_STT:  prdata = stt_reg;
                ADDR_IER:  prdata = {29'd0, ier_reg};
                default:   prdata = 32'h0;
            endcase
        end else begin
            prdata = 32'h0;
        end
    end

    // 5. Sinh tin hieu ngat (Interrupt Generation)
    wire rx_irq = rx_ready & ier_reg[0];
    wire tx_irq = tx_ready & ier_reg[1];
    wire oe_irq = overrun_latch & ier_reg[2];

    assign irq = rx_irq | tx_irq | oe_irq;

    // Hardware mapping
    assign data_bit_num = cfg_reg[1:0];
    assign stop_bit_num = cfg_reg[2];
    assign parity_en    = cfg_reg[3];
    assign parity_type  = cfg_reg[4];
    assign baud_sel     = cfg_reg[6:5];

endmodule