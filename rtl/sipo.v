module sipo(
    input clk,
    input rst_n,
    input shift_en,
    input data_tx,
    input clear_en,
    output reg [10:0] data_out
);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            data_out <= 11'b11111111111;
        end
        else begin
            if(shift_en) begin
                data_out <= {data_tx, data_out[10:1]};
            end
            else if(clear_en) begin
                data_out <= 11'b11111111111;
            end
        end
    end

endmodule