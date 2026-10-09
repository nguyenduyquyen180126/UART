module tx_stop_cnt(
    input clk, rst_n,
    input clr_stop,
    input tick_last,
    output reg cnt
);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt <= 1'b0;
        end
        else begin
            if(clr_stop) begin
                cnt <= 1'b0;
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