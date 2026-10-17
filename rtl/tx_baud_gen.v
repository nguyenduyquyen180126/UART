module tx_baud_gen #(
    parameter CLK_FREQ = 50_000_000
)(
    input [1:0] baud_sel,  // 00: 2400, 01: 4800, 10: 9600, 11: 19200
    input clk,
    input rst_n, 
    input clr_baud,           
    output baud_tick    // Xung enable tích cực cao trong 1 chu kỳ clock
);  
    localparam CNT_2400  = CLK_FREQ / (2400);
    localparam CNT_4800  = CLK_FREQ / (4800);
    localparam CNT_9600  = CLK_FREQ / (9600);
    localparam CNT_19200 = CLK_FREQ / (19200);
    
    reg [14:0] max_cnt;
    always @(*) begin
        case(baud_sel)
            2'b00:   max_cnt = CNT_2400;
            2'b01:   max_cnt = CNT_4800;
            2'b10:   max_cnt = CNT_9600;
            2'b11:   max_cnt = CNT_19200;
            default: max_cnt = CNT_9600;
        endcase
    end

    reg [14:0] cnt;

    assign baud_tick = (cnt >= max_cnt - 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cnt <= 15'b0;
        end else if (clr_baud || baud_tick) begin
            cnt <= 15'b0;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
endmodule