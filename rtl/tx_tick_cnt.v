`timescale 1ns/1ps
module tx_tick_cnt #(
    parameter OS = 16,
    parameter WIDTH = $clog2(OS)
)(
    input clk,
    /* verilator lint_off UNUSEDSIGNAL */
    input rst_n, // Synchronously cleared via clr_tick in IDLE/WAIT_CTS -> dfxtp_1
    /* verilator lint_on UNUSEDSIGNAL */
    input baud_tick,
    input clr_tick,
    output tick_last
);
    reg [WIDTH-1:0] cnt;

    // 4-bit counter (OS=16) wraps naturally from 4'hF to 4'h0 without an extra clear mux.
    always @(posedge clk) begin
        if (clr_tick) begin
            cnt <= {WIDTH{1'b0}};
        end else if (baud_tick) begin
            cnt <= cnt + {{(WIDTH-1){1'b0}}, 1'b1};
        end
    end

    assign tick_last = (&cnt) & baud_tick;
endmodule
