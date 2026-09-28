module tick_cnt(
    input clk,
    input rst_n,
    input baud_tick,
    input tick_clr,
    output reg [3:0] tick_cnt
);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            tick_cnt <= 4'b0;
        end
        else if(baud_tick) begin
            if(tick_clr) begin
                tick_cnt <= 4'b0;
            end
            else begin
                tick_cnt <= tick_cnt + 1'b1;
            end
           
        end
    end
endmodule