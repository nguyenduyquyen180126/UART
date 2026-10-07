module rx_controller(
    input clk,
    input rst_n,
    input baud_tick,
    input rx,
    input bit_last,
    input [1:0] num_stop_b,
    input [3:0] tick_cnt,
    output reg shift_en,
    output reg tick_clr,
    output reg tick_en,
    output reg rx_done,
    output reg bit_clr
);
    reg [1:0] state, next_state;
    localparam IDLE = 2'b00,
               CENTER = 2'b01,
               FRAME = 2'b10,
               HOLD = 2'b11;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end
    reg [3:0] tick_cnt_max;
    always @(*) begin
        case(num_stop_b)
            2'd1: tick_cnt_max = 4'd7;
            2'd2: tick_cnt_max = 4'd15;
            default: tick_cnt_max = 4'd7;
        endcase
    end
    always @(*) begin
        next_state = state;
        if(baud_tick) begin
        case(state)
            IDLE: begin
                if(rx == 1'b0) next_state = CENTER;
                else next_state = IDLE;
            end
            CENTER: begin
                if (tick_cnt == 4'd7 && ~rx)
                    next_state = FRAME;
                else if (tick_cnt == 4'd7 && rx)
                    next_state = IDLE;
                else
                    next_state = CENTER;
            end
            FRAME: begin
                if(bit_last) next_state = HOLD;
                else next_state = FRAME;
            end
            HOLD: begin
                if(tick_cnt == tick_cnt_max) next_state = IDLE;
                else next_state = HOLD;
            end
        endcase
    end
    end
    always @(*) begin
        tick_en = 1'b0;
        shift_en = 1'b0;
        tick_clr = 1'b0;
        rx_done = 1'b0;
        bit_clr = 1'b0;
        if(baud_tick) begin
            case(state)
                IDLE: begin
                    tick_clr = 1'b1;
                    bit_clr  = 1'b1;
                end
                CENTER: begin
                    if (tick_cnt == 4'd7 && ~rx) begin
                        shift_en = 1'b1;
                        tick_en  = 1'b1;
                        tick_clr = 1'b1;
                    end
                    else if (tick_cnt == 4'd7 && rx) begin
                        tick_clr = 1'b1;
                        bit_clr  = 1'b1;
                    end
                end
                FRAME: begin
                    if(bit_last) begin
                        bit_clr  = 1'b1;
                        tick_clr = 1'b1;
                    end
                    else if(tick_cnt == 4'd15) begin
                        tick_en  = 1'b1;
                        shift_en = 1'b1;
                    end
                end
                HOLD: begin
                    bit_clr = 1'b1;
                    if(tick_cnt == tick_cnt_max) begin
                        rx_done  = 1'b1;
                        tick_clr = 1'b1;
                    end
                end
            endcase
        end
    end

endmodule