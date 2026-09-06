module rx_controller(
    input clk,
    input rst_n,
    input baud_en,
    input data_tx,
    output reg active_flag,
    output reg clear_en,
    output reg shift_en,
    output reg received_flag
);
    reg [1:0] state, next_state;
    reg [3:0] stop_cnt;
    reg [3:0] frame_cnt;
    localparam IDLE = 2'b00,
               CENTER = 2'b01,
               FRAME = 2'b10,
               HOLD = 2'b11;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end
    always @(*) begin
        next_state = state;
        if(baud_en) begin
        case(state)
            IDLE: begin
                if(data_tx == 1'b0) next_state = CENTER;
                else next_state = IDLE;
            end
            CENTER: begin
                if(stop_cnt == 4'd7) begin
                    if(~data_tx) next_state = FRAME;
                    else next_state = IDLE;
                end
                else next_state = CENTER;
            end
            FRAME: begin
                if(frame_cnt == 4'd10) next_state = HOLD;
                else next_state = FRAME;
            end
            HOLD: begin
                if(stop_cnt >= 4'd7) next_state = IDLE;
                else next_state = HOLD;
            end
        endcase
    end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            frame_cnt <= 4'b0;
            stop_cnt <= 4'b0;
        end
        else if(baud_en) begin
            case(state)
                IDLE: begin
                    frame_cnt <= 4'b0;
                    stop_cnt <= 4'b0;
                end
                CENTER: begin
                    frame_cnt <= 4'b0;
                    if(stop_cnt == 4'd7) begin
                        stop_cnt <= 4'b0;
                    end
                    else stop_cnt <= stop_cnt + 1'b1;
                end
                FRAME: begin
                    if(frame_cnt == 4'd10) begin
                        frame_cnt <= 4'd0;
                        stop_cnt <= 4'd0;
                    end
                    else begin
                        if(stop_cnt == 4'd15) begin
                            stop_cnt <= 4'd0;
                            frame_cnt <= frame_cnt + 1'b1;
                        end
                        else stop_cnt <= stop_cnt + 1'b1;
                    end
                end
                HOLD: begin
                    frame_cnt <= 4'b0;
                    if(stop_cnt >= 4'd7) begin
                        stop_cnt <= 4'd0;
                    end
                    else stop_cnt <= stop_cnt + 1'b1;
                end
            endcase
        end
    end
    always @(*) begin
        active_flag = 1'b0;
        clear_en = 1'b0;
        shift_en = 1'b0;
        received_flag = 1'b0;
        if(baud_en) begin
        case(state)
            IDLE: begin
                active_flag = 1'b0;
                clear_en = 1'b1;
                shift_en = 1'b0;
                received_flag = 1'b0;
            end
            CENTER: begin
                active_flag = 1'b1;
                clear_en = 1'b0;
                shift_en = 1'b0;
                received_flag = 1'b0;
                if(stop_cnt == 4'd7) begin
                    if(~data_tx) begin
                        active_flag = 1'b1;
                        clear_en = 1'b0;
                        shift_en = 1'b1;
                        received_flag = 1'b0;
                    end
                    else begin
                        active_flag = 1'b0;
                        clear_en = 1'b1;
                        shift_en = 1'b0;
                        received_flag = 1'b0;
                    end
                end
            end
            FRAME: begin
                active_flag = 1'b1;
                clear_en = 1'b0;
                shift_en = 1'b0;
                received_flag = 1'b0;
                if(frame_cnt == 4'd10) begin
                    active_flag = 1'b0;
                    clear_en = 1'b0;
                    shift_en = 1'b0;
                    received_flag = 1'b1;
                end
                else begin
                    if(stop_cnt == 4'd15) begin
                        active_flag = 1'b1;
                        clear_en = 1'b0;
                        shift_en = 1'b1;
                        received_flag = 1'b0;
                    end
                    else begin
                        active_flag = 1'b1;
                        clear_en = 1'b0;
                        shift_en = 1'b0;
                        received_flag = 1'b0;
                    end
                end
            end
            HOLD: begin
                if(stop_cnt >= 4'd7) begin
                    active_flag = 1'b0;
                    clear_en = 1'b1;
                    shift_en = 1'b0;
                    received_flag = 1'b0;
                end
                else begin
                    active_flag = 1'b0;
                    clear_en = 1'b0;
                    shift_en = 1'b0;
                    received_flag = 1'b0;
                end
            end
        endcase
        end
    end

endmodule