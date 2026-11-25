module sipo(
    input clk,
    input rst_n,
    input shift_en,
    input rx,
    output reg [8:0] data_out
);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            data_out <= 9'b111111111;
        end
        else if(shift_en) begin
            data_out <= {rx, data_out[8:1]};
        end
    end

endmodule
