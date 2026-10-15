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

    // 1. Nhan dien chu ky ACCESS hop le (Zero-Wait-State, khong dung FSM)
    wire apb_access = psel & penable;

    // 2. Zero-wait-state PREADY
    assign pready = apb_access;

    // 3. Kiem tra dia chi hop le (vung dia chi 0x000 den 0x010, can le 4-byte)
    wire addr_valid = (paddr <= 12'h010) && (paddr[1:0] == 2'b00);

    // 4. Tach bach tin hieu dieu khien Read / Write
    assign reg_pread  = apb_access & addr_valid & (~pwrite);
    assign reg_pwrite = apb_access & addr_valid & pwrite;
    assign reg_paddr  = paddr;
    assign reg_pwdata = pwdata;

    // 5. PSLVERR: Bao loi khi dia chi khong hop le HOAC vi pham dieu kien bao ve
    assign pslverr = apb_access & ((!addr_valid) | reg_ack_err);

    // 6. PRDATA: Lai du lieu khi doc hop le va khong loi; con lai tra ve 0
    assign prdata = (reg_pread && !reg_ack_err) ? reg_prdata : 32'h0000_0000;

endmodule
