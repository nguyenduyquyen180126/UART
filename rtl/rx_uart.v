module rx_uart(
    input clk,
    input rst_n,
    input [1:0] baud_rate,
    input data_tx,
    input [1:0] parity_type,
    output [7:0] raw_data,
    output [2:0] error_flag,
    output done_flag
);
    wire active_flag, clear_en, shift_en, received_flag;
    wire [10:0] data_parall;
    wire baud_en;
    wire parity_bit, start_bit, stop_bit;

    rx_baud_gen rx_baud_gen_inst(
        .clk(clk),
        .rst_n(rst_n),
        .baud_rate(baud_rate),
        .baud_en(baud_en)
    );

    rx_controller rx_controller_inst(
        .clk(clk),
        .rst_n(rst_n),
        .baud_en(baud_en),
        .data_tx(data_tx),
        .active_flag(active_flag),
        .clear_en(clear_en),
        .shift_en(shift_en),
        .received_flag(received_flag)
    );
    sipo sipo_inst(
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(shift_en),
        .clear_en(clear_en),
        .data_tx(data_tx),
        .data_out(data_parall)
    );
    deframe deframe_inst(
        .received_flag(received_flag),
        .rst_n(rst_n),
        .data_parall(data_parall),
        .raw_data(raw_data),
        .parity_bit(parity_bit),
        .start_bit(start_bit),
        .stop_bit(stop_bit),
        .done_flag(done_flag)
    );
    error_check error_check_inst(
        .rst_n(rst_n),
        .raw_data(raw_data),
        .parity_bit(parity_bit),
        .start_bit(start_bit),
        .stop_bit(stop_bit),
        .parity_type(parity_type),
        .received_flag(received_flag),
        .error_flag(error_flag)
    );

endmodule