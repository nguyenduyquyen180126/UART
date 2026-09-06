module bit_counter(
    input clk, rst_n,
    input clr, inc,
    output bit_last
);
    reg[3:0] bit_cnt;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            bit_cnt <= 4'b0;
        end
        else begin
            if(clr) begin
                bit_cnt <= 4'b0;
            end
            else if(inc) begin
                bit_cnt <= bit_cnt + 1'b1;
            end
            else begin
                bit_cnt <= bit_cnt;
            end
        end
    end

    assign bit_last = (bit_cnt == 4'd10);
endmodule