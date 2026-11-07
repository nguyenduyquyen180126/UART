module tx_controller(
    input clk, rst_n,
    input start_tx,
    input parity_en,
    input stop_last,
    input baud_tick,
    input bit_last,
    input cts_n,
    input tx_dis,
    output reg [1:0]tx_sel,
    output reg load_reg,
    output reg shift_reg,
    output reg clr_bit,
    output reg clr_stop,
    output reg clr_baud,
    output reg tx_done_pulse,
    output reg tx_busy
);
    localparam IDLE     = 3'b000;
    localparam START    = 3'b001;
    localparam DATA     = 3'b011;
    localparam PARITY   = 3'b010;
    localparam STOP     = 3'b110;
    localparam WAIT_CTS  = 3'b111;


    reg [2:0] state;
    reg [2:0] next_state;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if(start_tx && !tx_dis) begin
                    if(!cts_n) begin
                        next_state = START;
                    end
                    else begin
                        next_state = WAIT_CTS;
                    end
                end
            end
            WAIT_CTS: begin
                if(!cts_n) begin
                    next_state = START;
                end
                else begin
                    next_state = WAIT_CTS;
                end
            end
            START: begin
                if(baud_tick) begin
                    next_state = DATA;
                end
            end
            DATA: begin
                if(~bit_last && baud_tick) begin
                    next_state = DATA;
                end
                else if(bit_last && baud_tick && parity_en) begin
                    next_state = PARITY;
                end
                else if(bit_last && baud_tick && ~parity_en) begin
                    next_state = STOP;
                end
            end
            PARITY: begin
                if(baud_tick) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                if(~stop_last && baud_tick) begin
                    next_state = STOP;
                end
                else if(stop_last && baud_tick) begin
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(*) begin
        tx_sel      = 2'b01;
        clr_bit     = 1'b0;
        clr_stop    = 1'b0;
        clr_baud    = 1'b0;
        load_reg    = 1'b0;
        shift_reg   = 1'b0;
        tx_busy     = 1'b0;
        tx_done_pulse = 1'b0;

        case(state)
            IDLE: begin
                tx_sel = 2'b01;
                clr_bit = 1'b1;
                clr_stop = 1'b1;
                clr_baud = 1'b1;
                tx_busy = 1'b0;
                if(start_tx && !tx_dis) begin
                    load_reg = 1'b1;
                end
            end
            WAIT_CTS: begin
                tx_sel = 2'b01;
                clr_bit = 1'b1;
                clr_stop = 1'b1;
                clr_baud = 1'b1;
                tx_busy = 1'b1;
            end
            START: begin
                tx_sel = 2'b00;
                clr_bit = 1'b1;
                clr_stop = 1'b1;
                tx_busy = 1'b1;
            end
            DATA: begin
                tx_sel = 2'b10;
                clr_bit = 1'b0;
                clr_stop = 1'b1;
                tx_busy = 1'b1;
                if(~bit_last && baud_tick) begin
                    shift_reg = 1'b1;
                end
            end
            PARITY: begin
                tx_sel = 2'b11;
                clr_bit = 1'b1;
                clr_stop = 1'b1;
                tx_busy = 1'b1;
            end
            STOP: begin
                tx_sel = 2'b01;
                clr_bit = 1'b1;
                clr_stop = 1'b0;
                tx_busy = 1'b1;
                if(stop_last && baud_tick) begin
                    tx_done_pulse = 1'b1;
                end
            end
        endcase
    end
endmodule