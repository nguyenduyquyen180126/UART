module tx_baud_gen #(
    parameter CLK_FREQ = 50_000_000

)(
    input [1:0] baud_rate,  // 00: 2400, 01: 4800, 10: 9600, 11: 19200
    input clk,
    input baud_en,
    input rst_n,            
    output reg baud_tick    // Xung enable tích cực cao trong 1 chu kỳ clock
);  
    localparam CNT_2400 = CLK_FREQ / (2400 * 16);
    localparam CNT_4800 = CLK_FREQ / (4800 * 16);
    localparam CNT_9600 = CLK_FREQ / (9600 * 16);
    localparam CNT_19200 = CLK_FREQ / (19200 * 16);
    
    reg [14:0] max_cnt;
    always @(baud_rate) begin
        case(baud_rate)
            2'b00: max_cnt = CNT_2400;
            2'b01: max_cnt = CNT_4800;
            2'b10: max_cnt = CNT_9600;
            2'b11: max_cnt = CNT_19200;
            default: max_cnt = CNT_9600;
        endcase
    end

    reg [14:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt <= 15'b0;
            baud_tick <= 1'b0;
        end
        else begin
            if(baud_en) begin
                if (cnt >= max_cnt - 1) begin
                    baud_tick <= 1'b1;
                    cnt <= 15'b0;
                end
                else begin
                    baud_tick <= 1'b0;
                    cnt <= cnt + 1'b1;
                end
            end
            else begin
                cnt <= 15'b0;
                baud_tick <= 1'b0;
            end
        end
    end
endmodule