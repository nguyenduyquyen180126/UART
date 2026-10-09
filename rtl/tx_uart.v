module tx_uart(
    input clk, rst_n,
    input start_tx,
    input [7:0] tx_data,
    input [1:0] data_bit_num,
    input stop_bit_num,
    input parity_en,
    input parity_type,
    input baud_tick,
    output reg tx,
    output tx_done
);
    wire stop_last;
    wire bit_last;
    wire tick_last;
    wire data_mux_in;
    wire parity_bit;
    wire clr_bit;
    wire clr_stop;
    wire [2:0] bit_cnt;
    reg [2:0] bit_cnt_last;
    wire stop_cnt;
    wire [1:0] tx_sel;
    wire load_reg;
    wire shift_reg;
    reg [7:0] tx_data_masked;

    reg start_tx_d;
    reg start_tx_edge;

    // Detect rising edge of start_tx and hold until transmission starts
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_tx_d    <= 1'b0;
            start_tx_edge <= 1'b0;
        end else begin
            start_tx_d <= start_tx;
            if (start_tx && !start_tx_d) begin
                start_tx_edge <= 1'b1;
            end else if (load_reg) begin
                start_tx_edge <= 1'b0;
            end
        end
    end

    tx_controller controller(
        .clk(clk) ,
        .rst_n(rst_n),
        .start_tx(start_tx_edge),
        .parity_en(parity_en),
        .stop_last(stop_last),
        .tick_last(tick_last),
        .bit_last(bit_last),
        .tx_done(tx_done),
        .tx_sel(tx_sel),
        .load_reg(load_reg),
        .shift_reg(shift_reg),
        .clr_bit(clr_bit),
        .clr_stop(clr_stop)
    );

    tx_tick_cnt #(.OS(16)) tick_cnt(
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .tick_last(tick_last)
    );

    tx_bit_cnt u_bit_cnt(
        .clk(clk),
        .rst_n(rst_n),
        .clr_bit(clr_bit),
        .tick_last(tick_last),
        .cnt(bit_cnt)
    );

    always @(*) begin
        case(data_bit_num)
            2'b00: bit_cnt_last = 3'd4;
            2'b01: bit_cnt_last = 3'd5;
            2'b10: bit_cnt_last = 3'd6;
            2'b11: bit_cnt_last = 3'd7;
            default: ;
        endcase
    end

    assign bit_last = (bit_cnt == bit_cnt_last);


    tx_stop_cnt u_stop_cnt(
        .clk(clk),
        .rst_n(rst_n),
        .tick_last(tick_last),
        .clr_stop(clr_stop),
        .cnt(stop_cnt)
    );

    assign stop_last = (stop_cnt == stop_bit_num);


    always @(*) begin
        case(data_bit_num)
            2'b00: tx_data_masked = {3'b0, tx_data[4:0]};
            2'b01: tx_data_masked = {2'b0, tx_data[5:0]};
            2'b10: tx_data_masked = {1'b0, tx_data[6:0]};
            2'b11: tx_data_masked = tx_data[7:0];
            default: ;
        endcase
    end


    parity u_parity(
        .data_in(tx_data_masked),
        .parity_type(parity_type),
        .parity_bit(parity_bit)
    );

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
            2'b00: tx = 1'b0;
            2'b01: tx = 1'b1;
            2'b10: tx = data_mux_in;
            2'b11: tx = parity_bit;
            default: ;
        endcase
    end
endmodule