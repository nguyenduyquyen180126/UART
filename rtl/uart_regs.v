module uart_regs (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        reg_pread,
    input  wire        reg_pwrite,
    input  wire [11:0] reg_paddr,
    input  wire [31:0] reg_pwdata,
    output reg  [31:0] reg_prdata,
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
    localparam [11:0] ADDR_STT  = 12'h00C;
    localparam [11:0] ADDR_IER  = 12'h010; 

    reg [6:0] cfg_reg; // [1:0] data_bits, [2] stop_bit, [3] parity_en, [4] parity_type, [6:5] baud_sel
    reg [2:0] ier_reg; // [0] rx_irq_en, [1] tx_irq_en, [2] overrun_irq_en

    wire addr_tx   = (reg_paddr == ADDR_TX);
    wire addr_rx   = (reg_paddr == ADDR_RX);
    wire addr_cfg  = (reg_paddr == ADDR_CFG);
    wire addr_stt  = (reg_paddr == ADDR_STT);
    wire addr_ier  = (reg_paddr == ADDR_IER);

    // Trang thai ranh cua he thong
    wire tx_ready  = (!tx_busy) && tx_fifo_empty;  // TX hoan toan ranh khi core khong ban va FIFO rong
    wire uart_idle = tx_ready && (!rx_busy);       // Ca 2 kenh TX/RX deu ranh moi cho phep doi CFG

    // Kiem tra dieu kien ghi/doc hop le
    wire write_legal = (addr_tx   && !tx_fifo_full) || // Chi cho phep ghi TX khi FIFO chua day
                       (addr_cfg  && uart_idle)     || // Chi cho phep sua CFG khi UART ranh
                       (addr_ier);                     // Luon cho phep bat/tat ngat

    wire read_legal  = addr_tx || addr_rx || addr_cfg || addr_stt || addr_ier;

    wire valid_write = reg_pwrite && write_legal;
    wire valid_read  = reg_pread  && read_legal;    

    // Bao loi vi pham bao ve bus (pslverr = 1)
    assign reg_ack_err = (reg_pwrite && !write_legal) || 
                         (reg_pread  && !read_legal);

    assign tx_fifo_wr_en   = valid_write && addr_tx;
    assign tx_fifo_wr_data = reg_pwdata[7:0];
    assign rx_fifo_rd_en   = valid_read  && addr_rx && (!rx_fifo_empty);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_reg <= 7'h0;
            ier_reg <= 3'h0;
        end else if (valid_write) begin
            case (reg_paddr)
                ADDR_CFG: cfg_reg <= reg_pwdata[6:0];
                ADDR_IER: ier_reg <= reg_pwdata[2:0];
                default: ;
            endcase
        end
    end

    reg overrun_latch;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            overrun_latch <= 1'b0;
        else if (rx_fifo_rd_en)
            overrun_latch <= 1'b0; // Tu dong xoa khi CPU doc du lieu RX
        else if (rx_overrun_err)
            overrun_latch <= 1'b1; // Chot loi khi co byte den ma RX FIFO da day
    end

    wire rx_ready    = !rx_fifo_empty;                  // Bit 1: RX FIFO co du lieu san sang doc
    wire rx_byte_err = rx_ready && rx_fifo_rd_data[8]; // Bit 2: Byte o dau FIFO bi loi Frame/Parity

    wire [31:0] stt_reg = {
        26'd0,
        rx_fifo_full,     // Bit 5: RX FIFO Day (16 byte)
        tx_fifo_full,     // Bit 4: TX FIFO Day (16 byte)
        overrun_latch,    // Bit 3: Loi tran RX FIFO (Overrun Error)
        rx_byte_err,      // Bit 2: Loi Parity/Frame cua byte hien tai
        rx_ready,         // Bit 1: RX co du lieu san sang
        tx_ready          // Bit 0: Bo phat san sang & TX FIFO da rong hoan toan
    };

    always @(*) begin
        if (valid_read) begin
            case (reg_paddr)
                ADDR_TX:   reg_prdata = 32'h0;
                ADDR_RX:   reg_prdata = rx_fifo_empty ? 32'h0 : {23'd0, rx_fifo_rd_data}; // [7:0] data, [8] error
                ADDR_CFG:  reg_prdata = {25'd0, cfg_reg};
                ADDR_STT:  reg_prdata = stt_reg;
                ADDR_IER:  reg_prdata = {29'd0, ier_reg};
                default:   reg_prdata = 32'h0;
            endcase 
        end else begin
            reg_prdata = 32'h0;
        end
    end

    wire rx_irq = rx_ready     & ier_reg[0]; // Ngat khi RX co du lieu
    wire tx_irq = tx_ready     & ier_reg[1]; // Ngat khi TX phat xong toan bo FIFO
    wire oe_irq = overrun_latch & ier_reg[2]; // Ngat khi xay ra loi tran Overrun

    assign irq = rx_irq | tx_irq | oe_irq;

    assign data_bit_num = cfg_reg[1:0];
    assign stop_bit_num = cfg_reg[2];
    assign parity_en    = cfg_reg[3];
    assign parity_type  = cfg_reg[4];
    assign baud_sel     = cfg_reg[6:5];

endmodule