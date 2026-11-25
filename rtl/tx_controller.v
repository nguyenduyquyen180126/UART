`timescale 1ns/1ps
module tx_controller(
    input clk,
    input rst_n,
    input soft_rst,
    input start_tx,
    input parity_en,
    input stop_bit_num,
    input bit_last,
    input cts_n,
    input tx_dis,
    input tick_last,
    output [1:0] tx_sel,
    output load_reg,
    output clr_bit,
    output clr_baud,
    output tx_done,
    output tx_busy
);
    // V2 PPA smart binary state encoding (7 states in 3 FFs):
    //   - Absorbs tx_stop_cnt (-1 FF) via STOP1/STOP2
    //   - Eliminates redundant tx_done FF (-1 FF) via state == IDLE
    //   - state[2] == 0 => tx always mark (1); state[2:1] == 00 => clr_baud == 1
    localparam [2:0] IDLE     = 3'b000;
    localparam [2:0] WAIT_CTS = 3'b001;
    localparam [2:0] STOP1    = 3'b010;
    localparam [2:0] STOP2    = 3'b011;
    localparam [2:0] START    = 3'b100;
    localparam [2:0] DATA     = 3'b101;
    localparam [2:0] PARITY   = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else if (soft_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_tx && !tx_dis) begin
                    next_state = cts_n ? WAIT_CTS : START;
                end
            end
            WAIT_CTS: begin
                if (!cts_n) begin
                    next_state = START;
                end
            end
            START: begin
                if (tick_last) begin
                    next_state = DATA;
                end
            end
            DATA: begin
                if (bit_last && tick_last) begin
                    next_state = parity_en ? PARITY : STOP1;
                end
            end
            PARITY: begin
                if (tick_last) begin
                    next_state = STOP1;
                end
            end
            STOP1: begin
                if (tick_last) begin
                    next_state = stop_bit_num ? STOP2 : IDLE;
                end
            end
            STOP2: begin
                if (tick_last) begin
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    wire is_idle       = (state == IDLE);
    wire tx_done_pulse = tick_last & ((state == STOP2) | ((state == STOP1) & ~stop_bit_num));

    assign tx_done  = is_idle;
    assign tx_busy  = (~is_idle) & (~tx_done_pulse);
    assign load_reg = is_idle & start_tx & (~tx_dis);
    assign clr_baud = ~state[2] & ~state[1]; // IDLE (000) and WAIT_CTS (001)
    assign clr_bit  = (state != DATA);

    // tx_sel: 2'b00 = START (0), 2'b01 = MARK/STOP (1), 2'b10 = DATA, 2'b11 = PARITY
    assign tx_sel = (!state[2]) ? 2'b01 :
                    (state[1:0] == 2'b00) ? 2'b00 :
                    (state[1:0] == 2'b01) ? 2'b10 :
                    (state[1:0] == 2'b10) ? 2'b11 : 2'b01;
endmodule
