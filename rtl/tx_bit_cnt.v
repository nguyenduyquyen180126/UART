module tx_bit_cnt(
    input clk, rst_n,
    input tick_last,
    input clr_bit,
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
                if(tick_last) begin
                    cnt <= cnt + 1'b1;
                end
                else begin
                    cnt <= cnt;
                end
            end
        end
    end
endmodule