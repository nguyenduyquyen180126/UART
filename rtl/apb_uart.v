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
    input  wire        rx,
    output wire        irq
);

    wire        reg_pread, reg_pwrite, reg_ack_err;
    wire [11:0] reg_paddr;
    wire [31:0] reg_pwdata, reg_prdata;

    wire [1:0]  data_bit_num, baud_sel;
    wire        stop_bit_num, parity_en, parity_type;
    wire        tx_busy, rx_done, rx_busy, error;

    apb_slave u_apb_slave (
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

    wire [7:0]  tx_fifo_wr_data;
    wire        tx_fifo_wr_en;
    wire [7:0]  tx_fifo_rd_data;
    wire        tx_fifo_rd_en;
    wire        tx_fifo_full;
    wire        tx_fifo_empty;
    wire        tx_load_reg;

    wire [7:0]  rx_uart_data;
    wire [8:0]  rx_fifo_rd_data;
    wire        rx_fifo_rd_en;
    wire        rx_fifo_full;
    wire        rx_fifo_empty;
    wire        rx_overrun_err;

    uart_regs u_uart_regs (
        .clk             (clk),
        .rst_n           (rst_n),
        .reg_pread       (reg_pread),
        .reg_pwrite      (reg_pwrite),
        .paddr           (reg_paddr),
        .pwdata          (reg_pwdata),
        .prdata          (reg_prdata),
        .reg_ack_err     (reg_ack_err),
        .irq             (irq),

        .data_bit_num    (data_bit_num),
        .stop_bit_num    (stop_bit_num),
        .parity_en       (parity_en),
        .parity_type     (parity_type),
        .baud_sel        (baud_sel),
        .rx_busy         (rx_busy),

        .tx_fifo_wr_en   (tx_fifo_wr_en),
        .tx_fifo_wr_data (tx_fifo_wr_data),
        .tx_fifo_full    (tx_fifo_full),
        .tx_fifo_empty   (tx_fifo_empty),
        .tx_busy         (tx_busy),

        .rx_fifo_rd_en   (rx_fifo_rd_en),
        .rx_fifo_rd_data (rx_fifo_rd_data),
        .rx_fifo_empty   (rx_fifo_empty),
        .rx_fifo_full    (rx_fifo_full),
        .rx_overrun_err  (rx_overrun_err)
    );

    sync_fifo #(
        .DEPTH (16),
        .DWIDTH(8)
    ) u_tx_fifo (
        .clk   (clk),
        .rst_n (rst_n),
        .wr_en (tx_fifo_wr_en),
        .rd_en (tx_fifo_rd_en),
        .din   (tx_fifo_wr_data),
        .dout  (tx_fifo_rd_data),
        .empty (tx_fifo_empty),
        .full  (tx_fifo_full)
    );

    wire start_tx        = !tx_fifo_empty;
    assign tx_fifo_rd_en = tx_load_reg;

    wire rx_fifo_wr_en  = rx_done && !rx_fifo_full;
    assign rx_overrun_err = rx_done && rx_fifo_full;

    sync_fifo #(
        .DEPTH (16),
        .DWIDTH(9)
    ) u_rx_fifo (
        .clk   (clk),
        .rst_n (rst_n),
        .wr_en (rx_fifo_wr_en),
        .rd_en (rx_fifo_rd_en),
        .din   ({error, rx_uart_data}),
        .dout  (rx_fifo_rd_data),
        .empty (rx_fifo_empty),
        .full  (rx_fifo_full)
    );


    tx_uart #(.CLK_FREQ(CLK_FREQ)) u_tx_uart (
        .clk          (clk),
        .rst_n        (rst_n),
        .start_tx     (start_tx),
        .tx_data      (tx_fifo_rd_data),
        .data_bit_num (data_bit_num),
        .stop_bit_num (stop_bit_num),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .baud_sel     (baud_sel),
        .tx           (tx),
        .load_reg     (tx_load_reg),
        .tx_busy      (tx_busy)
    );

    rx_uart #(.CLK_FREQ(CLK_FREQ)) u_rx_uart (
        .clk         (clk),
        .rst_n       (rst_n),
        .rx          (rx),
        .baud_sel    (baud_sel),
        .data_b_num  (data_bit_num),
        .stop_b_num  (stop_bit_num),
        .parity_type (parity_type),
        .parity_en   (parity_en),
        .rx_data     (rx_uart_data),
        .rx_done     (rx_done),
        .rx_busy     (rx_busy),
        .error       (error)
    );

endmodule