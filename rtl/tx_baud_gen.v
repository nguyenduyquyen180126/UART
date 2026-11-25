module tx_baud_gen(
    input pclk,
    input presetn,
    input [11:0] div_int,
    input [3:0] div_frac,
    input clr_baud,
    output baud_tick
);
    wire carry;
    wire [4:0] sum;
    reg [11:0] cnt;
    reg [3:0] acc;

    assign sum = {1'b0, acc} + {1'b0, div_frac};
    assign carry = sum[4];
    // Down-counter reloads div_int: fires at cnt==1 (carry=0 -> div_int cycles)
    // or cnt==0 (carry=1 -> div_int+1 cycles), eliminating the 12-bit subtractor
    // and variable equality comparator.
    assign baud_tick = (~|cnt[11:1]) & (cnt[0] ^ carry);

    always @(posedge pclk or negedge presetn) begin
        if(~presetn) begin
            cnt <= 12'b0;
            acc <= 4'b0;
        end
        else if(clr_baud || baud_tick) begin
            cnt <= div_int;
            acc <= clr_baud ? 4'b0 : sum[3:0];
        end
        else begin
            cnt <= cnt - 12'd1;
        end
    end
    
endmodule
