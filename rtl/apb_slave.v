module apb_slave (
    input  wire        pclk,
    input  wire        preset_n,
    
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output reg         pready,
    output reg         pslverr,
    output reg  [31:0] prdata,

    output reg         reg_en,
    output wire [11:0] reg_paddr,
    output wire [31:0] reg_pwdata,
    output wire        reg_pwrite,
    input  wire [31:0] reg_prdata,
    input  wire        write_en,
    input  wire        read_en
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

    assign reg_paddr  = paddr;
    assign reg_pwdata = pwdata;
    assign reg_pwrite = pwrite;

    always @(*) begin
        reg_en  = 1'b0;
        pready  = 1'b1;
        pslverr = 1'b0;
        prdata  = 32'h00000000;

        case (state)
            ACCESS: begin
                reg_en  = 1'b1;
                pslverr = reg_pwrite ? !write_en : !read_en;
                prdata  = (read_en) ? reg_prdata : 32'h00000000;
            end

            default: ;
        endcase
    end

endmodule
