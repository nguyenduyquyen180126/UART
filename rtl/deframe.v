module deframe(
    input received_flag,
    input rst_n,
    input [10:0] data_parall,
    output reg [7:0] raw_data,
    output reg parity_bit,
    output reg start_bit,
    output reg stop_bit,
    output reg done_flag
);
    always @(*) begin
        if(~rst_n) begin
            raw_data <= 8'd0;
            parity_bit <= 1'b1;
            start_bit <= 1'b1;
            stop_bit <= 1'b0;
            done_flag <= 1'b0;
        end
        else if(received_flag) begin
            raw_data <= data_parall[8:1];
            parity_bit <= data_parall[9];
            start_bit <= data_parall[0];
            stop_bit <= data_parall[10];
            done_flag <= 1'b1;
        end
        else begin
            raw_data <= 8'd0;
            parity_bit <= 1'b1;
            start_bit <= 1'b1;
            stop_bit <= 1'b0;
            done_flag <= 1'b0;
        end
    end
    
endmodule