module tx_controller(
    input send,
    input clk, rst_n,
    input baud_tick,
    input bit_last,
    output reg active,
    output reg clr,
    output reg inc,
    output reg load_en,
    output reg shift_en,
    output reg baud_en
);
    localparam IDLE = 1'b0;
    localparam ACTIVE = 1'b1;

    reg state;
    reg next_state;

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
                if(send) begin
                    next_state = ACTIVE;
                end
            end
            ACTIVE: begin
                if(baud_tick && bit_last) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        active = 1'b0;
        clr = 1'b0;
        inc = 1'b0;
        load_en = 1'b0;
        shift_en = 1'b0;
        baud_en = 1'b0;
        case(state)
            IDLE: begin
                active = 1'b0;
                if(send) begin
                    load_en = 1'b1;
                    clr = 1'b1;
                    baud_en = 1'b1;
                end
            end
            ACTIVE: begin
                active = 1'b1;
                if(baud_tick && ~bit_last) begin
                    baud_en = 1;
                    shift_en = 1;
                    inc = 1;
                end
                else if(baud_tick && bit_last) begin
                    baud_en = 0;
                end
                else begin
                    baud_en = 1;
                end
            end
            default: ;
        endcase
    end
endmodule
