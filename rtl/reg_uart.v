module uart_regs (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        reg_pread, 
    input  wire        reg_pwrite,  
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        reg_ack_err,

    output wire [7:0]  tx_data,
    output wire [1:0]  data_bit_num,
    output wire        stop_bit_num,
    output wire        parity_en,
    output wire        parity_type,
    output wire        start_tx,
    output wire [1:0]  baud_sel,

    input  wire        tx_done,
    input  wire        rx_done,
    input  wire        rx_busy,
    input  wire        error,
    input  wire [31:0] rx_data
);

    localparam [11:0] ADDR_TX   = 12'h000;
    localparam [11:0] ADDR_RX   = 12'h004;
    localparam [11:0] ADDR_CFG  = 12'h008;
    localparam [11:0] ADDR_CTRL = 12'h00C;
    localparam [11:0] ADDR_STT  = 12'h010;

    reg [31:0] tx_data_reg;
    reg [31:0] rx_data_reg;
    reg [31:0] cfg_reg;
    reg [31:0] ctrl_reg;
    reg [31:0] stt_reg;

    wire addr_tx   = (paddr == ADDR_TX);
    wire addr_rx   = (paddr == ADDR_RX);
    wire addr_cfg  = (paddr == ADDR_CFG);
    wire addr_ctrl = (paddr == ADDR_CTRL);
    wire addr_stt  = (paddr == ADDR_STT);

    wire tx_ready  = stt_reg[0];
    wire uart_idle = tx_ready && (!rx_busy);

    wire write_legal = (addr_tx   && tx_ready)  ||
                       (addr_cfg  && uart_idle) ||
                       (addr_ctrl);

    wire read_legal  = addr_tx || addr_rx || addr_cfg || addr_ctrl || addr_stt;

    assign reg_ack_err = (reg_pwrite && !write_legal) || 
                         (reg_pread  && !read_legal);

    wire valid_write = reg_pwrite && write_legal;
    wire valid_read  = reg_pread  && read_legal;

    wire rx_read_ack  = valid_read  && addr_rx;
    wire tx_write_ack = valid_write && addr_ctrl && pwdata[0];

    // 1. Quan ly ghi thanh ghi
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data_reg <= 32'h0;
            cfg_reg     <= 32'h0;
            ctrl_reg    <= 32'h0;
        end else begin
            ctrl_reg[0] <= 1'b0; // Tu dong xoa xung start_tx sau 1 chu ky

            if (valid_write) begin
                case (paddr)
                    ADDR_TX:   tx_data_reg <= pwdata;
                    ADDR_CFG:  cfg_reg     <= pwdata;
                    ADDR_CTRL: ctrl_reg    <= pwdata;
                    default: ;
                endcase
            end
        end
    end

    // 2. Quan ly RX Data & Trang thai STT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data_reg <= 32'h0;
            stt_reg     <= 32'h0000_0001; // tx_done ban dau = 1
        end else begin
            rx_data_reg <= rx_data;

            if (tx_write_ack)
                stt_reg[0] <= 1'b0;
            else if (tx_done)
                stt_reg[0] <= 1'b1;

            if (rx_read_ack)
                stt_reg[1] <= 1'b0;
            else if (rx_done)
                stt_reg[1] <= 1'b1;

            if (error)
                stt_reg[2] <= 1'b1;
            else if (rx_read_ack)
                stt_reg[2] <= 1'b0;
        end
    end

    // 3. Doc du lieu ra prdata
    always @(*) begin
        if (valid_read) begin
            case (paddr)
                ADDR_TX:   prdata = tx_data_reg;
                ADDR_RX:   prdata = rx_data_reg;
                ADDR_CFG:  prdata = cfg_reg;
                ADDR_CTRL: prdata = ctrl_reg;
                ADDR_STT:  prdata = stt_reg;
                default:   prdata = 32'h0;
            endcase
        end else begin
            prdata = 32'h0;
        end
    end

    // Hardware mapping
    assign tx_data      = tx_data_reg[7:0];
    assign data_bit_num = cfg_reg[1:0];
    assign stop_bit_num = cfg_reg[2];
    assign parity_en    = cfg_reg[3];
    assign parity_type  = cfg_reg[4];
    assign baud_sel     = cfg_reg[6:5];
    assign start_tx     = ctrl_reg[0];

endmodule