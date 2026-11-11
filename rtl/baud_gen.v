module baud_gen(
    input pclk,
    input presetn,
    input [11:0] div_int,
    input [3:0] div_frac,
    output tick
);
    wire carry;
    wire [4:0] sum;
    wire [11:0] max_cnt;
    reg [11:0] cnt;
    reg [3:0] acc;

    assign sum = {1'b0, acc} + {1'b0, div_frac};
    assign carry = sum[4];
    assign max_cnt = (carry) ? div_int : (div_int - 1'b1);

    assign tick = (cnt == max_cnt);

    always @(posedge pclk or negedge presetn) begin
        if(~presetn) begin
            cnt <= 12'b0;
            acc <= 4'b0;
        end
        else begin
            if(tick) begin
                cnt <= 12'b0;
                acc <= sum[3:0];
            end
            else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
    
endmodule