module tx_bit_cnt(
    input clk, rst_n,
    input baud_tick,
    input clr_bit,
    input tick_last,
    output reg [2:0] cnt
);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt <= 3'b000;
        end
        else begin
            if(clr_bit) begin
                cnt <= 3'b000;
            end
            else begin
                if(baud_tick && tick_last) begin
                    cnt <= cnt + 1'b1;
                end
                else begin
                    cnt <= cnt;
                end
            end
        end
    end
endmodule