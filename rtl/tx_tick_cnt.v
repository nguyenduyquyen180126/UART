module tx_tick_cnt #(
    parameter OS = 16,
    parameter WIDTH = $clog2(OS)
)(
    input clk, rst_n,
    input baud_tick,
    output tick_last
);
    reg [WIDTH - 1 : 0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            cnt <= {WIDTH{1'b0}};
        end
        else begin
            if(baud_tick) begin
                if(cnt == OS - 1) begin
                    cnt <= {WIDTH{1'b0}};
                end
                else cnt <= cnt + 1'b1;
            end
            else begin
                cnt <= cnt;
            end
        end
    end

    assign tick_last = (cnt == OS - 1) && baud_tick;
endmodule