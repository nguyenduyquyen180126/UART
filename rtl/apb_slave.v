module apb_slave (
    input  wire        pclk,
    input  wire        preset_n,
    
    // APB Bus Interface
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output wire        pready,
    output wire        pslverr,
    output wire [31:0] prdata,

    // UART Register Interface
    output wire        reg_pread,   // Kich hoat DOC thanh ghi
    output wire        reg_pwrite,  // Kich hoat GHI thanh ghi
    output wire [11:0] reg_paddr,
    output wire [31:0] reg_pwdata,
    input  wire [31:0] reg_prdata,
    input  wire        reg_ack_err  // Bao loi vi pham bao ve tu uart_regs
);
    assign pready = psel & penable;

    wire addr_valid = (paddr <= 12'h010) && (paddr[1:0] == 2'b00);

    assign reg_pread  = psel & penable & addr_valid & (~pwrite);
    assign reg_pwrite = psel & penable & addr_valid & pwrite;
    assign reg_paddr  = paddr;
    assign reg_pwdata = pwdata;

    assign pslverr = psel & penable & ((!addr_valid) | reg_ack_err);

    assign prdata = (reg_pread && !reg_ack_err) ? reg_prdata : 32'h0000_0000;

endmodule
