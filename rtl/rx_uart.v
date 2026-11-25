`timescale 1ns/1ps
module rx_uart #(
    /* verilator lint_off UNUSEDPARAM */
    parameter CLK_FREQ = 50_000_000
    /* verilator lint_on UNUSEDPARAM */
)(
    input clk,
    input rst_n,
    input soft_rst,
    input rx,
    input [1:0] data_b_num,
    input stop_b_num,
    input parity_type,
    input parity_en,
    input rx_dis,
    input [11:0] div_int,
    input [3:0] div_frac,
    input rx_clear,
    output reg [7:0] rx_data,
    output reg rx_done,
    output rx_busy,
    output rts_n,
    output reg parity_err,
    output reg frame_err,
    output reg overrun,
    output wire error
);
    wire       baud_tick;
    wire       clr_baud;
    wire       start_valid;
    wire       sample_data;
    wire       sample_parity;
    wire       tick_clr;
    wire       bit_clr;
    wire       bit_last;
    wire [2:0] bit_cnt;
    wire [3:0] tick_cnt;
    wire       ctrl_frame_err;
    wire       ctrl_rx_done;
    wire       soft_rst_i = (soft_rst === 1'b1);

    // 2-FF synchronizer for external asynchronous RX + mark-rearm guard after reset/disable/break
    reg rx_sync1, rx_sync2;
    reg rx_armed;
    reg reset_release_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
            rx_armed <= 1'b0;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            if (soft_rst_i || rx_dis || (ctrl_rx_done && !rx_sync2)) begin
                rx_armed <= 1'b0;
            end else if (rx_sync2) begin
                rx_armed <= 1'b1;
            end
        end
    end

    wire rx_fsm_in = (rx_dis || !rx_armed) ? 1'b1 : rx_sync2;

    // Keep RTS_N high during reset and through the first sampled clock after reset release.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_release_pending <= 1'b1;
        end else begin
            reset_release_pending <= 1'b0;
        end
    end

    assign rts_n = ~rst_n | soft_rst_i | reset_release_pending | rx_done | rx_dis;

    rx_baud_gen u_rx_baud_gen (
        .div_frac  (div_frac),
        .div_int   (div_int),
        .pclk      (clk),
        .presetn   (rst_n),
        .clr_baud  (clr_baud),
        .baud_tick (baud_tick)
    );

    rx_controller rx_controller_inst(
        .clk           (clk),
        .rst_n         (rst_n),
        .soft_rst      (soft_rst_i),
        .baud_tick     (baud_tick),
        .rx            (rx_fsm_in),
        .bit_last      (bit_last),
        .parity_en     (parity_en),
        .stop_b_num    (stop_b_num),
        .tick_cnt      (tick_cnt),
        .start_valid   (start_valid),
        .sample_data   (sample_data),
        .sample_parity (sample_parity),
        .tick_clr      (tick_clr),
        .bit_clr       (bit_clr),
        .rx_done       (ctrl_rx_done),
        .rx_busy       (rx_busy),
        .clr_baud      (clr_baud),
        .frame_error   (ctrl_frame_err)
    );

    bit_cnt bit_cnt_inst(
        .clk        (clk),
        .rst_n      (rst_n),
        .inc_en     (sample_data),
        .data_b_num (data_b_num),
        .bit_clr    (bit_clr),
        .bit_cnt    (bit_cnt),
        .bit_last   (bit_last)
    );

    tick_cnt tick_cnt_inst(
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .tick_clr  (tick_clr),
        .tick_cnt  (tick_cnt)
    );

    // V2 PPA: Direct bit-indexed capture + 1-bit serial running parity accumulator
    // replaces 9-FF sipo + 354 um^2 deframe + error_check.
    // Bits [4:0] are always written during DATA; only [7:5] need zeroing on start_valid
    // for 5/6/7-bit zero-extension. Both map to Sky130 dfxtp_1 (no async reset).
    reg [7:0] rx_shift;
    reg       rx_par_acc;

    always @(posedge clk) begin
        if (start_valid) begin
            rx_shift[7:5] <= 3'b000;
            rx_par_acc    <= ~parity_type; // 1=Even -> init 0; 0=Odd -> init 1
        end else begin
            if (sample_data) begin
                rx_shift[bit_cnt] <= rx_fsm_in;
            end
            if (sample_data || sample_parity) begin
                rx_par_acc <= rx_par_acc ^ rx_fsm_in;
            end
        end
    end

    wire parity_error = parity_en & rx_par_acc;
    assign error = parity_err | frame_err;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_err  <= 1'b0;
            parity_err <= 1'b0;
            overrun    <= 1'b0;
            rx_done    <= 1'b0;
            rx_data    <= 8'b0;
        end else if (soft_rst_i) begin
            frame_err  <= 1'b0;
            parity_err <= 1'b0;
            overrun    <= 1'b0;
            rx_done    <= 1'b0;
            rx_data    <= 8'b0;
        end else begin
            if (ctrl_rx_done) begin
                if (rx_done && !rx_clear) begin
                    overrun <= 1'b1;
                end else begin
                    rx_done    <= 1'b1;
                    frame_err  <= ctrl_frame_err;
                    parity_err <= parity_error;
                    overrun    <= 1'b0;
                    rx_data    <= rx_shift;
                end
            end else if (rx_clear) begin
                rx_done    <= 1'b0;
                frame_err  <= 1'b0;
                parity_err <= 1'b0;
                overrun    <= 1'b0;
            end
        end
    end

endmodule
