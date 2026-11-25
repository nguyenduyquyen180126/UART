`timescale 1ns/1ps
module rx_controller(
    input clk,
    input rst_n,
    input soft_rst,
    input baud_tick,
    input rx,
    input bit_last,
    input parity_en,
    input stop_b_num,
    input [3:0] tick_cnt,
    output start_valid,
    output sample_data,
    output sample_parity,
    output tick_clr,
    output bit_clr,
    output rx_done,
    output rx_busy,
    output clr_baud,
    output frame_error
);
    // V2 PPA 6-state binary FSM (3 FFs replaces state[1:0] + first_stop_sampled):
    //   - Directly separates DATA, PARITY, STOP1, STOP2 -> eliminates sipo[8], deframe,
    //     error_check, data_b_num, stop_b_num, and bit_cnt[3].
    //   - rx_busy = |state[2:1] (single 2-input OR gate).
    localparam [2:0] IDLE   = 3'b000;
    localparam [2:0] CENTER = 3'b001;
    localparam [2:0] DATA   = 3'b010;
    localparam [2:0] PARITY = 3'b011;
    localparam [2:0] STOP1  = 3'b100;
    localparam [2:0] STOP2  = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;
    reg       frame_error_latched; // dfxtp_1: written at STOP1 before STOP2 ever reads it

    wire tick7  = baud_tick & (tick_cnt == 4'd7);
    wire tick15 = baud_tick & (&tick_cnt);

    assign clr_baud      = (state == IDLE);
    assign rx_busy       = state[2] | state[1]; // DATA, PARITY, STOP1, STOP2
    assign start_valid   = (state == CENTER) & tick7 & (~rx);
    assign sample_data   = (state == DATA)   & tick15;
    assign sample_parity = (state == PARITY) & tick15;

    wire sample_stop1    = (state == STOP1) & tick15;
    wire sample_stop2    = (state == STOP2) & tick15;

    assign tick_clr    = (state == IDLE) | ((state == CENTER) & tick7);
    assign bit_clr     = (state != DATA);
    assign rx_done     = (sample_stop1 & (~stop_b_num)) | sample_stop2;
    assign frame_error = (state == STOP2) ? (frame_error_latched | (~rx)) : (~rx);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else if (soft_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(posedge clk) begin
        if (sample_stop1) begin
            frame_error_latched <= ~rx;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (!rx) begin
                    next_state = CENTER;
                end
            end
            CENTER: begin
                if (tick7) begin
                    next_state = rx ? IDLE : DATA;
                end
            end
            DATA: begin
                if (tick15 && bit_last) begin
                    next_state = parity_en ? PARITY : STOP1;
                end
            end
            PARITY: begin
                if (tick15) begin
                    next_state = STOP1;
                end
            end
            STOP1: begin
                if (tick15) begin
                    next_state = stop_b_num ? STOP2 : IDLE;
                end
            end
            STOP2: begin
                if (tick15) begin
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
