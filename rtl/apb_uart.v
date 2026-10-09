module apb_uart #(
    parameter CLK_FREQ = 50_000_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [11:0] paddr,
    input  wire [31:0] pwdata,
    output wire        pready,
    output wire        pslverr,
    output wire [31:0] prdata,

    output wire        tx,
    input  wire        rx
);

    wire        reg_pread, reg_pwrite, reg_ack_err;
    wire [11:0] reg_paddr;
    wire [31:0] reg_pwdata, reg_prdata;

    wire [7:0]  tx_data;
    wire [1:0]  data_bit_num, baud_sel;
    wire        stop_bit_num, parity_en, parity_type, start_tx;

    wire        tx_done, rx_done, rx_busy, error, baud_tick;
    wire [31:0] rx_data;

    apb_slave u_apb_slave (
        .pclk        (clk),
        .preset_n    (rst_n),
        .psel        (psel),
        .penable     (penable),
        .pwrite      (pwrite),
        .paddr       (paddr),
        .pwdata      (pwdata),
        .pready      (pready),
        .pslverr     (pslverr),
        .prdata      (prdata),
        .reg_pread   (reg_pread),
        .reg_pwrite  (reg_pwrite),
        .reg_paddr   (reg_paddr),
        .reg_pwdata  (reg_pwdata),
        .reg_prdata  (reg_prdata),
        .reg_ack_err (reg_ack_err)
    );

    uart_regs u_uart_regs (
        .clk          (clk),
        .rst_n        (rst_n),
        .reg_pread    (reg_pread),
        .reg_pwrite   (reg_pwrite),
        .paddr        (reg_paddr),
        .pwdata       (reg_pwdata),
        .prdata       (reg_prdata),
        .reg_ack_err  (reg_ack_err),
        .tx_data      (tx_data),
        .data_bit_num (data_bit_num),
        .stop_bit_num (stop_bit_num),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .start_tx     (start_tx),
        .baud_sel     (baud_sel),
        .tx_done      (tx_done),
        .rx_done      (rx_done),
        .rx_busy      (rx_busy),
        .error        (error),
        .rx_data      (rx_data)
    );

    baud_gen #(.CLK_FREQ(CLK_FREQ)) u_baud_gen (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_sel  (baud_sel),
        .baud_tick (baud_tick)
    );

    tx_uart u_tx_uart (
        .clk          (clk),
        .rst_n        (rst_n),
        .start_tx     (start_tx),
        .tx_data      (tx_data),
        .data_bit_num (data_bit_num),
        .stop_bit_num (stop_bit_num),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .baud_tick    (baud_tick),
        .tx           (tx),
        .tx_done      (tx_done)
    );

    rx_uart u_rx_uart (
        .clk         (clk),
        .rst_n       (rst_n),
        .rx          (rx),
        .baud_tick   (baud_tick),
        .data_b_num  (data_bit_num),
        .stop_b_num  (stop_bit_num),
        .parity_type (parity_type),
        .parity_en   (parity_en),
        .rx_data     (rx_data),
        .rx_done     (rx_done),
        .rx_busy     (rx_busy),
        .error       (error)
    );

endmodule