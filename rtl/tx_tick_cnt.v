module tx_tick_cnt #(
    parameter OS = 16,
    parameter WIDTH = $clog2(OS)
)(
    input clk, rst_n,
    input baud_tick,
    input clr_tick,
    output tick_last
);
    // WIDTH is $clog2(OS); OS-1 therefore fits the counter. The explicit
    // narrowing below records the intended counter-width comparison.
    /* verilator lint_off WIDTHTRUNC */
    localparam [WIDTH-1:0] LAST_COUNT = OS - 1;
    /* verilator lint_on WIDTHTRUNC */
    reg [WIDTH - 1 : 0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt <= {WIDTH{1'b0}};
        end
        else begin
            if(clr_tick) begin
                cnt <= {WIDTH{1'b0}};
            end
            else if(baud_tick) begin
                if(cnt == LAST_COUNT) begin
                    cnt <= {WIDTH{1'b0}};
                end
                else cnt <= cnt + 1'b1;
            end
            else begin
                cnt <= cnt;
            end
        end
    end

    assign tick_last = (cnt == LAST_COUNT) && baud_tick;
endmodule
