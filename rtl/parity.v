module parity (
    input [7:0] data_in,
    input [1:0] parity_type,    // 00: No parity - 01: Odd parity - 10: Even parity
    output reg parity_bit
);
    localparam no_parity = 2'b00;
    localparam odd_parity = 2'b01;
    localparam even_parity = 2'b10;

    always @(data_in, parity_type) begin
        case (parity_type)
            no_parity: parity_bit = 1;
            odd_parity: parity_bit = (^data_in);
            even_parity: parity_bit = ~(^data_in);
            default: parity_bit = 1;
        endcase
    end
endmodule