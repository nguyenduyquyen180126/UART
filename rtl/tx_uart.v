module tx_uart #(
    parameter CLK_FREQ = 50_000_000
)(
    input clk, rst_n,
    input start_tx,
    input [7:0] tx_data,
    input [1:0] data_bit_num,
    input stop_bit_num,
    input parity_en,
    input parity_type,
    input [1:0] baud_sel,
    output reg tx,
    output load_reg,
    output tx_busy
);
    wire stop_last;
    wire bit_last;
    wire baud_tick;
    wire data_mux_in;
    wire parity_bit;
    reg parity_latched;
    wire clr_bit;
    wire clr_stop;
    wire clr_baud;
    wire [2:0] bit_cnt;
    reg [2:0] bit_cnt_last;
    wire stop_cnt;
    wire [1:0] tx_sel;
    wire shift_reg;
    reg [7:0] tx_data_masked;


    tx_controller controller(
        .clk(clk),
        .rst_n(rst_n),
        .start_tx(start_tx),
        .parity_en(parity_en),
        .stop_last(stop_last),
        .baud_tick(baud_tick),
        .bit_last(bit_last),
        .tx_sel(tx_sel),
        .load_reg(load_reg),
        .shift_reg(shift_reg),
        .clr_bit(clr_bit),
        .clr_stop(clr_stop),
        .clr_baud(clr_baud),
        .tx_busy(tx_busy)
    );

    tx_baud_gen #(
        .CLK_FREQ(CLK_FREQ)
    ) u_baud_gen(
        .baud_sel(baud_sel),
        .clk(clk),
        .rst_n(rst_n),
        .clr_baud(clr_baud),
        .baud_tick(baud_tick)
    );

    tx_bit_cnt u_bit_cnt(
        .clk(clk),
        .rst_n(rst_n),
        .clr_bit(clr_bit),
        .baud_tick(baud_tick),
        .cnt(bit_cnt)
    );

    always @(*) begin
        case(data_bit_num)
            2'b00: bit_cnt_last = 3'd4;
            2'b01: bit_cnt_last = 3'd5;
            2'b10: bit_cnt_last = 3'd6;
            2'b11: bit_cnt_last = 3'd7;
            default: bit_cnt_last = 3'd7;
        endcase
    end

    assign bit_last = (bit_cnt == bit_cnt_last);


    tx_stop_cnt u_stop_cnt(
        .clk(clk),
        .rst_n(rst_n),
        .clr_stop(clr_stop),
        .baud_tick(baud_tick),
        .cnt(stop_cnt)
    );

    assign stop_last = (stop_cnt == stop_bit_num);


    always @(*) begin
        case(data_bit_num)
            2'b00:   tx_data_masked = {3'b0, tx_data[4:0]};
            2'b01:   tx_data_masked = {2'b0, tx_data[5:0]};
            2'b10:   tx_data_masked = {1'b0, tx_data[6:0]};
            2'b11:   tx_data_masked = tx_data[7:0];
            default: tx_data_masked = tx_data[7:0];
        endcase
    end


    parity u_parity(
        .data_in(tx_data_masked),
        .parity_type(parity_type),
        .parity_bit(parity_bit)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            parity_latched <= 1'b0;
        else if (load_reg)
            parity_latched <= parity_bit;
    end

    piso u_piso(
        .clk(clk),
        .rst_n(rst_n),
        .load_reg(load_reg),
        .shift_reg(shift_reg),
        .data_in(tx_data_masked),
        .data_tx(data_mux_in)
    );

    always @(*) begin
        case(tx_sel)
            2'b00:   tx = 1'b0;
            2'b01:   tx = 1'b1;
            2'b10:   tx = data_mux_in;
            2'b11:   tx = parity_latched;
            default: tx = 1'b1;
        endcase
    end
endmodule
