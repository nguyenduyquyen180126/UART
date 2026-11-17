module tx_stop_cnt(
    input clk, rst_n,
    input clr_stop,
    input baud_tick,
    input tick_last,
    input stop_cnt_en,
    output reg [1:0] cnt
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
                if(stop_cnt_en) begin
                    cnt <= cnt + 1'b1;
                end
                else begin
                    cnt <= cnt;
                end
            end
        end
    end
endmodule