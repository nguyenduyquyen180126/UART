module piso(
    input clk, rst_n,
    input load_reg,
    input shift_reg,
    input [7:0] data_in,
    output data_tx
);
    reg [7:0] data;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            data <= 7'b0;
        end
        else begin
            if(load_reg) begin
                data <= data_in;
            end
            else if(shift_reg) begin
                data <= {1'b0, data[7:1]};
            end
            else begin
                data <= data;
            end
        end
    end

    assign data_tx = data[0];
endmodule