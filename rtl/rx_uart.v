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
   wire baud_tick;
   wire clr_baud;
   wire parity_bit;
   wire shift_en;
   wire tick_en;
   wire tick_clr;
   wire bit_clr;
   wire bit_last;
   wire [8:0] data_out;
   wire [3:0] num_data_b;
   wire [1:0] num_stop_b;
   /* verilator lint_off UNUSEDSIGNAL */
   wire [3:0] bit_cnt;
   /* verilator lint_on UNUSEDSIGNAL */
   wire [3:0] tick_cnt;
   wire parity_exp;
   wire parity_error;
   wire ctrl_frame_err;
   wire ctrl_rx_done;
   wire [7:0]rx_deframe_data;
   wire soft_rst_i = (soft_rst === 1'b1);
   // Reuse the existing per-byte error bit in the 9-bit RX FIFO.
   assign error = parity_error | frame_err;
   
    // 2-FF Synchronizer cho tin hieu rx (chong Metastability)
    // Giu nguyen qua trinh lay mau rx khi soft_rst_i de tranh tao suon xuong gia
    // neu soft_rst xay ra giua khung thu dang o muc 0.
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
                // After reset, disable, or a framing-error stop bit (=0), require a
                // mark/idle level (rx_sync2==1) before arming the next falling start edge.
                rx_armed <= 1'b0;
            end else if (rx_sync2) begin
                rx_armed <= 1'b1;
            end
        end
    end
    wire rx_fsm_in = (rx_dis || !rx_armed) ? 1'b1 : rx_sync2; 
    // APB-UART spec requires RTS inactive (high) while reset is asserted.
    // Keep RTS inactive through the first sampled clock after reset release.
    // This satisfies the APB-UART reset contract before normal receive-ready
    // flow control (rx_dis | rx_done) takes effect.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            reset_release_pending <= 1'b1;
        else
            reset_release_pending <= 1'b0;
    end

    assign rts_n = ~rst_n | soft_rst_i | reset_release_pending | rx_done | rx_dis;

    rx_baud_gen u_rx_baud_gen (
        .div_frac(div_frac),
        .div_int(div_int),
        .pclk(clk),
        .presetn(rst_n),
        .clr_baud(clr_baud),
        .baud_tick(baud_tick)
    );

    rx_controller rx_controller_inst(
        .clk(clk),
        .rst_n(rst_n),
        .soft_rst(soft_rst_i),
        .baud_tick(baud_tick),
        .rx(rx_fsm_in),
        .bit_last(bit_last),
        .tick_cnt(tick_cnt),
        .shift_en(shift_en),
        .tick_clr(tick_clr),
        .tick_en(tick_en),
        .num_stop_b(num_stop_b),
        .bit_clr(bit_clr),
        .rx_done(ctrl_rx_done),
        .rx_busy(rx_busy),
        .clr_baud(clr_baud),
        .frame_error(ctrl_frame_err)
    );
    data_b_num data_b_num_inst(
        .data_b_num(data_b_num),
        .data_b_num_out(num_data_b)
    );
    stop_b_num stop_b_num_inst(
        .two_stop_bits(stop_b_num),
        .stop_b_num_out(num_stop_b)
    );
    bit_cnt bit_cnt_inst(
        .clk(clk),
        .rst_n(rst_n),
        .tick_en(tick_en),
        .bit_clr(bit_clr),
        .data_b_num_out(num_data_b),
        .bit_last(bit_last),
        .bit_cnt(bit_cnt),
        .parity_en(parity_en)
    );
    tick_cnt tick_cnt_inst(
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .tick_clr(tick_clr),
        .tick_cnt(tick_cnt)
    );
    sipo sipo_inst(
        .clk(clk),
        .rst_n(rst_n),
        .shift_en(shift_en),
        .rx(rx_fsm_in),
        .data_out(data_out)
    );
    deframe deframe_inst(
        .parity_en(parity_en),
        .data_in(data_out),
        .num_data_b(num_data_b),
        .rx_data(rx_deframe_data),
        .parity_bit(parity_bit),
        .parity_exp(parity_exp)
    );
    error_check error_check_inst(
        .parity_en(parity_en),
        .parity_type(parity_type),
        .parity_bit(parity_bit),
        .parity_exp(parity_exp),
        .error(parity_error)
    );
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            frame_err <= 1'b0;
            parity_err <= 1'b0;
            overrun <= 1'b0;
            rx_done <= 1'b0;
            rx_data <= 8'b0;
        end else if (soft_rst_i) begin
            frame_err <= 1'b0;
            parity_err <= 1'b0;
            overrun <= 1'b0;
            rx_done <= 1'b0;
            rx_data <= 8'b0;
        end else begin
            if (ctrl_rx_done) begin
                if(rx_done && !rx_clear) begin
                    overrun <= 1'b1;
                end else begin
                    rx_done <= 1'b1;
                    frame_err <= ctrl_frame_err;
                    parity_err <= parity_error;
                    overrun <= 1'b0;
                    rx_data <= rx_deframe_data;
                end
            end else if(rx_clear) begin
                rx_done <= 1'b0;
                frame_err <= 1'b0;
                parity_err <= 1'b0;
                overrun <= 1'b0;
            end
        end
    end

endmodule

//cd /home/vietanh/Downloads/code/UART/UART
