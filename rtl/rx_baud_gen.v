`timescale 1ns/1ps
module rx_baud_gen(
    input pclk,
    /* verilator lint_off UNUSEDSIGNAL */
    input presetn, // Kept for interface compatibility; cleared synchronously by clr_baud in IDLE
    /* verilator lint_on UNUSEDSIGNAL */
    input [11:0] div_int,
    input [3:0] div_frac,
    input clr_baud,
    output baud_tick
);
    // V2 PPA & Fmax breakthrough:
    // Pre-registered {carry_q, acc_q} removes the 4-bit fractional adder from baud_tick,
    // and synchronous clear in IDLE maps all 17 FFs to compact Sky130 dfxtp_1 cells.
    reg [11:0] cnt;
    reg [3:0]  acc_q;
    reg        carry_q;

    assign baud_tick = (~|cnt[11:1]) & (cnt[0] ^ carry_q);

    always @(posedge pclk) begin
        if (clr_baud) begin
            cnt     <= div_int;
            carry_q <= 1'b0;
            acc_q   <= div_frac;
        end else if (baud_tick) begin
            cnt              <= div_int;
            {carry_q, acc_q} <= {1'b0, acc_q} + {1'b0, div_frac};
        end else begin
            cnt <= cnt - 12'd1;
        end
    end

endmodule
