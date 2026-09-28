module bit_cnt(
    input clk,
    input rst_n,
    input tick_en,
    input [3:0] data_b_num_out,
    input [1:0] stop_b_num_out,
    input parity_en,
    input bit_clr,
    output reg [3:0] bit_cnt,
    output reg bit_last
);
    always @(*) begin
        if(parity_en) begin
            if(bit_cnt == (data_b_num_out + 1 + 1)) begin
                bit_last = 1'b1;
            end
            else begin
                bit_last = 1'b0;
            end
        end
        else begin
            if(bit_cnt == (data_b_num_out + 1)) begin
                bit_last = 1'b1;
            end
            else begin
                bit_last = 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            bit_cnt <= 4'b0;
        end
        else if(tick_en) begin
            if(parity_en) begin
                if(bit_cnt == (data_b_num_out + 1 + 1)) begin
                    bit_cnt <= 4'b0;
                end
                else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end
            else begin
                if(bit_cnt == (data_b_num_out + 1)) begin
                    bit_cnt <= 4'b0;
                end
                else begin
                    bit_cnt <= bit_cnt + 1'b1;
                end
            end
        end
        else if(bit_clr) begin
            bit_cnt <= 4'b0;
        end
    end


endmodule
