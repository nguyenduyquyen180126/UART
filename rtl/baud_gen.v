module baud_gen #(
    parameter CLK_FREQ = 50_000_000
)(
    input             clk,
    input             rst_n,
    input      [1:0]  baud_sel,
    output reg        baud_tick
);  
    localparam CNT_2400  = CLK_FREQ / (2400 * 16);
    localparam CNT_4800  = CLK_FREQ / (4800 * 16);
    localparam CNT_9600  = CLK_FREQ / (9600 * 16);
    localparam CNT_19200 = CLK_FREQ / (19200 * 16);
    
    reg [14:0] max_cnt;
    always @(*) begin
        case (baud_sel)
            2'b00:   max_cnt = CNT_2400;
            2'b01:   max_cnt = CNT_4800;
            2'b10:   max_cnt = CNT_9600;
            2'b11:   max_cnt = CNT_19200;
            default: max_cnt = CNT_9600;
        endcase
    end

    reg [14:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= 15'b0;
            baud_tick <= 1'b0;
        end
        else begin
            if (cnt >= max_cnt - 1) begin
                baud_tick <= 1'b1;
                cnt       <= 15'b0;
            end
            else begin
                baud_tick <= 1'b0;
                cnt       <= cnt + 1'b1;
            end
        end
    end

endmodule
