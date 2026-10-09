module parity (
    input  [7:0] data_in,
    input        parity_type, // 0: ODD, 1: EVEN
    output reg   parity_bit
);
    always @(parity_type, data_in) begin
        if(parity_type) begin
            parity_bit = ^data_in;
        end   
        else begin
            parity_bit = ~(^data_in);
        end
    end
endmodule