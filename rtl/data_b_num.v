module data_b_num(
    input [1:0]data_b_num,
    output reg [3:0] data_b_num_out
);
    always @(data_b_num) begin
        case (data_b_num)
            2'b00: data_b_num_out = 4'd5;
            2'b01: data_b_num_out = 4'd6;
            2'b10: data_b_num_out = 4'd7;
            2'b11: data_b_num_out = 4'd8;
        endcase
    end
endmodule