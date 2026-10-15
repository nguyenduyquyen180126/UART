module piso(
    input clk, rst_n,
    input load_en,
    input shift_en,
    input parity_bit,
    input [7:0] data_in,
    output data_tx
);
    localparam no_parity = 2'b00;
    localparam odd_parity = 2'b01;
    localparam even_parity = 2'b10;

    reg[10:0] data_frame; // [stop_bit, data, parity, start_bit];
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            data_frame <= {11{1'b1}};
        end
        else begin
            if(load_en) begin
                data_frame <= {1'b1, parity_bit, data_in, 1'b0};
            end
            else if(shift_en) begin
                data_frame <= {1'b1, data_frame[10:1]};
            end
            else begin
                data_frame <= data_frame;
            end
        end
    end

    assign data_tx = data_frame[0];
endmodule