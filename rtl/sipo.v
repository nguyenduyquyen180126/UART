module sipo(
    input clk,
    input rst_n,
    input shift_en,
    input rx,
    output reg [11:0] data_out
);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            data_out <= 12'b111111111111;
        end
        else if(shift_en) begin
            data_out <= {rx, data_out[11:1]};
        end
        else begin
            data_out <= data_out;
        end
    end

endmodule