module stop_b_num(
    input stop_b_num,
    output reg [1:0] stop_b_num_out
);
    always @(stop_b_num) begin
        case (stop_b_num)
            1'b0: stop_b_num_out = 2'd1;
            1'b1: stop_b_num_out = 2'd2;
        endcase
    end
endmodule