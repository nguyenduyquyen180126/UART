module tx_uart #(
    parameter CLK_FREQ = 50_000_000
)(
    input send,
    input [1:0] baud_rate,  // 00: 2400, 01: 4800, 10: 9600, 11: 19200
    input clk,
    input rst_n,
    input [7:0] data_in,
    input [1:0] parity_type,
    output active,
    output data_tx
);
    wire baud_en;
    wire baud_tick;
    wire parity_bit;
    wire bit_last;
    wire clr;
    wire inc;
    wire load_en;
    wire shift_en;

    tx_baud_gen #(
        .CLK_FREQ(CLK_FREQ)
    ) u_tx_baud_gen (
        .baud_rate(baud_rate),
        .clk(clk),
        .rst_n(rst_n),
        .baud_en(baud_en),
        .baud_tick(baud_tick)
    );

    parity u_parity(
        .data_in(data_in),
        .parity_type(parity_type),
        .parity_bit(parity_bit)
    );

    tx_controller u_tx_controller(
        .send(send),
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .bit_last(bit_last),
        .active(active),
        .clr(clr),
        .inc(inc),
        .load_en(load_en),
        .shift_en(shift_en),
        .baud_en(baud_en)
    );

    bit_counter u_bit_counter(
        .clk(clk),
        .rst_n(rst_n),
        .clr(clr),
        .inc(inc),
        .bit_last(bit_last)
    );

    piso u_piso(
        .clk(clk),
        .rst_n(rst_n),
        .load_en(load_en),
        .shift_en(shift_en),
        .parity_bit(parity_bit),
        .data_in(data_in),
        .data_tx(data_tx)
    );
endmodule