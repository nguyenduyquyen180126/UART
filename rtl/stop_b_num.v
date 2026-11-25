module stop_b_num(
    input two_stop_bits,
    output wire [1:0] stop_b_num_out
);
    // The APB format bit encodes one stop bit as 0 and two stop bits as 1.
    assign stop_b_num_out[0] = ~two_stop_bits;
    assign stop_b_num_out[1] = two_stop_bits;
endmodule
