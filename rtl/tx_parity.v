module parity (
    input  [7:0] data_in,
    input        parity_type, // 0: EVEN, 1: ODD
    output reg   parity_bit
);
    always @(parity_type, data_in) begin
        if(!parity_type) begin
            parity_bit = ^data_in; // 0: EVEN
        end   
        else begin
            parity_bit = ~(^data_in); // 1: ODD
        end
    end
endmodule