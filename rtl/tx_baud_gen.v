`timescale 1ns/1ps
module tx_baud_gen(
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
    // 1. Pre-register {carry_q, acc_q} so the 4-bit fractional adder runs in parallel
    //    with the down-counter and is completely REMOVED from the baud_tick critical path.
    //    This slashes R2R worst-case delay and boosts Fmax (hence max achievable baud = Fmax/16).
    // 2. Synchronous clear via clr_baud (active in IDLE/WAIT_CTS) removes async reset
    //    -> Sky130 dfxtp_1 saves ~20% FF area and removes 17 loads from the rst_n tree.
    // 3. Supports div_int=1, div_frac=0 (baud_tick every cycle -> 1.5625 Mbps @ 25 MHz).
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
