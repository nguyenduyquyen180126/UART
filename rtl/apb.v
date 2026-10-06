module apb_slave (
    input  wire        pclk,
    input  wire        preset_n,
    
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output wire        pready,
    output wire        pslverr,
    output wire [31:0] prdata,

    output reg  [11:0] reg_paddr,
    output reg  [31:0] reg_pwdata,
    output reg         reg_pwrite,
    output wire        write_en,
    output wire        read_en,
    input  wire [31:0] reg_prdata
);

    localparam IDLE   = 2'b00;
    localparam SETUP  = 2'b01;
    localparam ACCESS = 2'b10;

    reg [1:0] state, next_state;
    always @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (psel && !penable) 
                    next_state = SETUP;
            end
            
            SETUP: begin
                if (psel && penable) 
                    next_state = ACCESS;
                else if (!psel) 
                    next_state = IDLE;
            end
            
            ACCESS: begin
                if (pready) begin
                    if (!psel)
                        next_state = IDLE;
                    else if (psel && !penable)
                        next_state = SETUP;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    always @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            reg_paddr  <= 12'h000;
            reg_pwdata <= 32'h00000000;
            reg_pwrite <= 1'b0;
        end 
        else if (state == IDLE && psel && !penable) begin
            reg_paddr  <= paddr;
            reg_pwdata <= pwdata;
            reg_pwrite <= pwrite;
        end
    end

    assign pready  = 1'b1; 
    assign pslverr = 1'b0; 

    assign write_en = (state == ACCESS) &&  reg_pwrite && pready;
    assign read_en  = (state == ACCESS) && !reg_pwrite && pready;

    assign prdata = (read_en) ? reg_prdata : 32'h00000000;

endmodule
