module tx_controller(
    input send,
    input clk, rst_n,
    input baud_en,
    output reg done,
    output reg load_en,
    output reg shift_en
);
    localparam IDLE = 1'b0;
    localparam ACTIVE = 1'b1;
    reg state;
    reg next_state;
    reg [3:0] bit_cnt;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= IDLE;
            bit_cnt <= 4'b0;
        end
        else begin
            state <= next_state;
            bit_cnt <= bit_cnt;
        end
    end

    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if()
                cnt <= cnt;
            end
            ACTIVE: begin
                
            end
        endcase
    end

    always @(*) begin
        
    end
endmodule
