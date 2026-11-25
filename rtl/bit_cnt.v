module bit_cnt(
    input clk,
    input rst_n,
    input tick_en,
    input [3:0] data_b_num_out,
    input parity_en,
    input bit_clr,
    output reg [3:0] bit_cnt,
    output reg bit_last
);
    wire [3:0] last_bit_idx = data_b_num_out + {3'b0, parity_en};

    always @(*) begin
        bit_last = (bit_cnt == last_bit_idx);
    end

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            bit_cnt <= 4'b0;
        end
        else if(bit_clr) begin
            bit_cnt <= 4'b0;
        end
        else if(tick_en) begin
            if(bit_last) begin
                bit_cnt <= 4'b0;
            end
            else begin
                bit_cnt <= bit_cnt + 1'b1;
            end
        end
    end


endmodule
