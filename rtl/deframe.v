module deframe(
        input               parity_en,
        input [8:0]         data_in,
        input [3:0]         num_data_b,
        output reg [7:0]    rx_data,
        output wire         parity_exp,
        output wire         parity_bit
    );

    // Share the 2:1 parity-window shift before the width mask and reuse one
    // parity XOR tree across all 5..8-bit formats (Tuan 13A resource sharing).
    wire [7:0] aligned = parity_en ? data_in[7:0] : data_in[8:1];

    always @(*) begin
        case(num_data_b)
            4'd5:    rx_data = {3'b0, aligned[7:3]};
            4'd6:    rx_data = {2'b0, aligned[7:2]};
            4'd7:    rx_data = {1'b0, aligned[7:1]};
            4'd8:    rx_data = aligned[7:0];
            default: rx_data = 8'd0;
        endcase
    end

    assign parity_exp = ^rx_data;
    assign parity_bit = parity_en & data_in[8];

endmodule
