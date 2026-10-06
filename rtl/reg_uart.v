module uart_regs (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    input  wire        pwrite,
    input  wire        write_en,
    input  wire        read_en,
    output reg  [31:0] prdata,

    output wire [31:0] tx_data,
    output wire [1:0]  data_bit_num,
    output wire        stop_bit_num,
    output wire        parity_en,
    output wire        parity_type,
    output wire        start_tx,
    output wire [1:0]  baud_sel,
    
    input  wire        tx_done,
    input  wire        rx_done,
    input  wire        error,
    input  wire [31:0] rx_data
);

    reg  [31:0] tx_data_reg; // 0x0
    reg  [31:0] cfg_reg;     // 0x8
    reg  [31:0] ctrl_reg;    // 0xC

    wire [31:0] rx_data_reg; // 0x4
    wire [31:0] stt_reg;     // 0x10

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data_reg <= 32'h0000_0000; 
            cfg_reg     <= 32'h0000_0000; 
            ctrl_reg    <= 32'h0000_0000; 
        end
        else if (write_en) begin
            case (paddr[7:0])
                8'h00: tx_data_reg <= pwdata;
                8'h08: cfg_reg     <= pwdata;
                8'h0C: ctrl_reg    <= pwdata;
                default: ; 
            endcase
        end
    end

    assign rx_data_reg = {24'h000000, rx_data[7:0]};
    assign stt_reg = {29'h00000000, error, rx_done, tx_done};

    always @(*) begin
        prdata = 32'h0000_0000; 
        if (read_en) begin
            case (paddr[7:0])
                8'h00: prdata = tx_data_reg;
                8'h04: prdata = rx_data_reg;
                8'h08: prdata = cfg_reg;    
                8'h0C: prdata = ctrl_reg;   
                8'h10: prdata = stt_reg;    
                default: prdata = 32'h0000_0000;
            endcase
        end
    end

    assign tx_data      = tx_data_reg;               
    assign data_bit_num = cfg_reg[1:0];              
    assign stop_bit_num = cfg_reg[2];                
    assign parity_en    = cfg_reg[3];               
    assign parity_type  = cfg_reg[4];               
    assign baud_sel     = cfg_reg[6:5];             
    assign start_tx     = ctrl_reg[0];         

endmodule