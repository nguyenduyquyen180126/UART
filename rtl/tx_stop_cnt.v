module tx_stop_cnt(
    input clk, rst_n,
    input clr_stop,
    input stop_cnt_en,
    output reg cnt
);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt <= 1'b0;
        end
        else if(clr_stop) begin
            cnt <= 1'b0;
        end
        else if(stop_cnt_en) begin
            cnt <= 1'b1;
        end
    end
endmodule
