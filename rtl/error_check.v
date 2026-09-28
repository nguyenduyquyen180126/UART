module error_check(
    input [1:0]parity_type,// 1'b0: even parity, 1'b1: odd parity
    input parity_bit,
    input parity_exp,
    input parity_en,
    output reg error
);
    always @(*) begin
        if(parity_en) begin
            case(parity_type)
                2'b10: error = (parity_bit != parity_exp) ? 1'b1 : 1'b0; // even parity
                2'b01: error = (parity_bit != ~parity_exp) ? 1'b1 : 1'b0; // odd parity
                default: error = 1'b0;
            endcase
        end else begin
            error = 1'b0;
        end
    end
endmodule
