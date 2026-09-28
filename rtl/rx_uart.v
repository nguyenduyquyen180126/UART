module rx_uart(
    input clk,
    input rst_n,
    input rx,
    input baud_tick,
    input [1:0] data_b_num,
    input stop_b_num,
    input [1:0] parity_type,
    input parity_en,
    output [31:0] rx_data,
    output rx_done,
    output error
);
   wire parity_bit;
   wire shift_en;
   wire tick_en;
   wire tick_clr;
   wire bit_clr;
   wire bit_last;
   wire [11:0] data_out;
   wire [3:0] num_data_b;
   wire [1:0] num_stop_b;
   wire [3:0] bit_cnt;
   wire [3:0] tick_cnt;
   wire parity_exp;
    rx_controller rx_controller_inst(
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .rx(rx),
        .bit_last(bit_last),
        .tick_cnt(tick_cnt),
        .shift_en(shift_en),
        .tick_clr(tick_clr),
        .tick_en(tick_en),
        .num_stop_b(num_stop_b),
        .bit_clr(bit_clr),
        .rx_done(rx_done)
    );
    data_b_num data_b_num_inst(
        .data_b_num(data_b_num),
        .data_b_num_out(num_data_b)
    );
    stop_b_num stop_b_num_inst(
        .stop_b_num(stop_b_num),
        .stop_b_num_out(num_stop_b)
    );
    bit_cnt bit_cnt_inst(
        .clk(clk),
        .rst_n(rst_n),
        .tick_en(tick_en),
        .bit_clr(bit_clr),
        .data_b_num_out(num_data_b),
        .stop_b_num_out(num_stop_b),
        .bit_last(bit_last),
        .bit_cnt(bit_cnt),
        .parity_en(parity_en)
    );
    tick_cnt tick_cnt_inst(
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .tick_clr(tick_clr),
        .tick_cnt(tick_cnt)
    );
    sipo sipo_inst(
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(shift_en),
        .rx(rx),
        .data_out(data_out)
    );
    deframe deframe_inst(
        .clk(clk),
        .rst_n(rst_n),
        .bit_last(bit_last),
        .parity_en(parity_en),
        .data_in(data_out),
        .num_data_b(num_data_b),
        .num_stop_b(num_stop_b),
        .rx_data(rx_data),
        .parity_bit(parity_bit),
        .parity_exp(parity_exp)
    );
    error_check error_check_inst(
        .parity_en(parity_en),
        .parity_type(parity_type),
        .parity_bit(parity_bit),
        .parity_exp(parity_exp),
        .error(error)
    );

endmodule