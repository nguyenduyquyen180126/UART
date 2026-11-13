module apb_regs(
    // SYSTEM SIGNAL
    input pclk,
    input presetn,

    // APB INTERFACES
    input psel,
    input penable,
    input pwrite,
    input [11:0] paddr,
    input [3:0] pstrb,
    input [31:0] pwdata,
    output pready,
    output pslverr,
    output reg [31:0] prdata,

    // TX RX CFG OUTPUT
    output [1:0] data_bits,
    output stop_bits,
    output parity_en,
    output parity_type,
    output tx_dis,
    output rx_dis,
    
    // CONTROL OUTPUT
    output  start_tx,
    output  soft_rst,

    output [7:0] tx_data,

    input [7:0] rx_data,

    // STATUS INPUT
    input tx_done,
    input rx_done,
    input parity_err,
    input rx_busy,
    input frame_err,

    // BAUD OUTPUT
    output [11:0] div_int,
    output [15:12] div_frac,

    output irq
);
    parameter TXDATA    = 12'h000;
    parameter RXDATA    = 12'h004;
    parameter CFG       = 12'h008;
    parameter CTRL      = 12'h00C;
    parameter STAT      = 12'h010;
    parameter BAUD      = 12'h014;
    parameter IER       = 12'h018;

    // REGS
    reg [7:0]   tx_data_reg;
    reg [7:0]   rx_data_reg;
    reg [6:0]   cfg;            // rx_dis, tx_dis, parity_type, parity_en, stop_bits, data_bits[1:0]
    reg         start_reg;
    reg         soft_rst_reg;
    reg [15:0]  baud;           // div_frac[15:12], div_int[11:0]
    reg [2:0]   ier;            // err_ie, rx_done_ie, tx_done_ie

    // INTERNAL STATUS FLAGS
    reg         rx_done_flag;
    reg         parity_err_flag;
    reg         frame_err_flag;
    reg         overrun_flag;

    // STAT WIRE: overrun, frame_err, rx_dis, tx_dis, rx_busy, parity_err, rx_done, tx_done
    wire [7:0]  stat;
    assign stat = {overrun_flag, frame_err_flag, cfg[6], cfg[5], rx_busy, parity_err_flag, rx_done_flag, tx_done};

    // OUTPUT ASSIGNMENTS
    assign data_bits   = cfg[1:0];
    assign stop_bits   = cfg[2];
    assign parity_en   = cfg[3];
    assign parity_type = cfg[4];
    assign tx_dis      = cfg[5];
    assign rx_dis      = cfg[6];

    assign start_tx    = start_reg;
    assign soft_rst    = soft_rst_reg;

    assign tx_data     = tx_data_reg;

    assign div_int     = baud[11:0];
    assign div_frac    = baud[15:12];

    assign pready      = 1'b1;

    assign irq = (ier[0] & tx_done) | (ier[1] & rx_done_flag) | (ier[2] & (parity_err_flag | frame_err_flag | overrun_flag));

    reg read_err;
    reg write_err;

    always @(*) begin
        if(psel & penable & ~pwrite) begin
            case(paddr)
                TXDATA: begin
                    prdata   = {24'h0, tx_data_reg};
                    read_err = 1'b0;
                end
                RXDATA: begin
                    prdata   = {24'h0, rx_data_reg};
                    read_err = 1'b0;
                end
                CFG: begin
                    prdata   = {25'h0, cfg};
                    read_err = 1'b0;
                end
                CTRL: begin
                    prdata   = 32'h0;
                    read_err = 1'b0;
                end
                STAT: begin
                    prdata   = {24'h0, stat};
                    read_err = 1'b0;
                end
                BAUD: begin
                    prdata   = {16'h0, baud};
                    read_err = 1'b0;
                end
                IER: begin
                    prdata   = {29'h0, ier};
                    read_err = 1'b0;
                end
                default: begin
                    prdata   = 32'h0;
                    read_err = 1'b1;
                end
            endcase
        end
        else begin
            prdata   = 32'h0;
            read_err = 1'b0;
        end
    end

    always @(*) begin
        if(psel & penable & pwrite) begin
            case(paddr)
                TXDATA: begin
                    if(!tx_done && (|pstrb)) begin
                        write_err = 1'b1;
                    end
                    else begin
                        write_err = 1'b0;
                    end
                end
                RXDATA: begin
                    write_err = 1'b1;
                end
                CFG: begin
                    if((!tx_done || rx_busy) && pstrb[0]) begin
                        write_err = 1'b1;
                    end
                    else begin
                        write_err = 1'b0;
                    end
                end
                CTRL: begin
                    if(pstrb[1] && pwdata[8]) begin
                        write_err = 1'b0;
                    end
                    else if(!tx_done && (pstrb[0] && pwdata[0])) begin
                        write_err = 1'b1;
                    end
                    else begin
                        write_err = 1'b0;
                    end
                end
                STAT: begin
                    write_err = 1'b1;
                end
                BAUD: begin
                    if((!tx_done || rx_busy) && (pstrb[0] || pstrb[1])) begin
                        write_err = 1'b1;
                    end
                    else if((pstrb[0] || pstrb[1]) && 
                            ({pstrb[1] ? pwdata[11:8] : baud[11:8], pstrb[0] ? pwdata[7:0] : baud[7:0]} == 12'h000)) begin
                        write_err = 1'b1;
                    end
                    else begin
                        write_err = 1'b0;
                    end
                end
                IER: begin
                    write_err = 1'b0;
                end
                default: begin
                    write_err = 1'b1;
                end
            endcase
        end
        else begin
            write_err = 1'b0;
        end
    end

    assign pslverr = (psel & penable) & (pwrite ? write_err : read_err);

    // Doc RXDATA xoa rx_done, parity_err, frame_err, overrun
    wire rxdata_read = psel & penable & ~pwrite & (paddr == RXDATA) & ~read_err;

    always @(posedge pclk or negedge presetn) begin
        if(!presetn) begin
            tx_data_reg     <= 8'h00;
            rx_data_reg     <= 8'h00;
            cfg             <= 7'h00;
            baud            <= 16'h900D;
            ier             <= 3'h0;
            start_reg       <= 1'b0;
            soft_rst_reg    <= 1'b0;
            rx_done_flag    <= 1'b0;
            parity_err_flag <= 1'b0;
            frame_err_flag  <= 1'b0;
            overrun_flag    <= 1'b0;
        end
        else begin
            start_reg    <= 1'b0;
            soft_rst_reg <= 1'b0;

            if(rxdata_read && !rx_done) begin
                rx_done_flag    <= 1'b0;
                parity_err_flag <= 1'b0;
                frame_err_flag  <= 1'b0;
                overrun_flag    <= 1'b0;
            end
            else if(rx_done) begin
                if(rx_done_flag && !rxdata_read) begin
                    overrun_flag <= 1'b1;
                end
                else begin
                    rx_done_flag    <= 1'b1;
                    overrun_flag    <= 1'b0;
                    parity_err_flag <= parity_err;
                    frame_err_flag  <= frame_err;
                    case(cfg[1:0])
                        2'b00: rx_data_reg <= {3'b000, rx_data[4:0]};
                        2'b01: rx_data_reg <= {2'b00, rx_data[5:0]};
                        2'b10: rx_data_reg <= {1'b0, rx_data[6:0]};
                        2'b11: rx_data_reg <= rx_data[7:0];
                    endcase
                end
            end

            if(psel & penable & pwrite & !write_err) begin
                case(paddr)
                    TXDATA: begin
                        if(pstrb[0]) begin
                            tx_data_reg <= pwdata[7:0];
                        end
                    end
                    CFG: begin
                        if(pstrb[0]) begin
                            cfg <= pwdata[6:0];
                        end
                    end
                    CTRL: begin
                        if(pstrb[1] && pwdata[8]) begin
                            soft_rst_reg    <= 1'b1;
                            cfg             <= 7'h00;
                            baud            <= 16'h900D;
                            ier             <= 3'h0;
                            tx_data_reg     <= 8'h00;
                            rx_data_reg     <= 8'h00;
                            rx_done_flag    <= 1'b0;
                            parity_err_flag <= 1'b0;
                            frame_err_flag  <= 1'b0;
                            overrun_flag    <= 1'b0;
                            start_reg       <= 1'b0;
                        end
                        else if(pstrb[0] && pwdata[0]) begin
                            start_reg <= 1'b1;
                        end
                    end
                    BAUD: begin
                        if(pstrb[0]) begin
                            baud[7:0] <= pwdata[7:0];
                        end
                        if(pstrb[1]) begin
                            baud[15:8] <= pwdata[15:8];
                        end
                    end
                    IER: begin
                        if(pstrb[0]) begin
                            ier <= pwdata[2:0];
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule
