module error_check(
    input rst_n,
    input [7:0] raw_data,
    input parity_bit,
    input start_bit,
    input stop_bit,
    input [1:0] parity_type,
    input received_flag,
    output [2:0] error_flag
);
    reg expected_parity;
    reg start_flag;
    reg stop_flag;
    reg parity_flag;
    localparam NOPARITY00 = 2'b00,
               ODD = 2'b01,
               EVEN = 2'b10,
               NOPARITY11 = 2'b11;
    always @(*) begin
        case(parity_type)
                NOPARITY00, NOPARITY11: begin
                    expected_parity <= 1'b1;
                end
                ODD: begin
                    expected_parity <= ~(^raw_data);
                end
                EVEN: begin
                    expected_parity <= ^raw_data;
                end
            endcase
    end

    always @(*) begin
        if(~rst_n) begin
            start_flag <= 1'b0;
            stop_flag <= 1'b0;
            parity_flag <= 1'b0;
        end
        else begin
            if(received_flag) begin
                if(parity_type == 2'b00 || parity_type == 2'b11) begin
                    parity_flag <= 1'b0;
                end
                else if(parity_bit != expected_parity) begin
                    parity_flag <= 1'b1;
                end
                start_flag <= start_bit;
                stop_flag <= ~stop_bit;
            end
            else begin
                start_flag <= 1'b0;
                stop_flag <= 1'b0;
                parity_flag <= 1'b0;
            end
        end
    end
    assign error_flag = {start_flag, stop_flag, parity_flag};
endmodule