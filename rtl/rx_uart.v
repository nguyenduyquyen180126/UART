module rx_uart #(
    parameter CLK_FREQ = 50_000_000
)(
    input clk,
    input rst_n,
    input rx,
    input [1:0]baud_sel,
    input [1:0] data_b_num,
    input stop_b_num,
    input parity_type,
    input parity_en,
    input rx_dis,
    input div_int,
    input div_frac,
    input rx_clear,
    output reg [7:0] rx_data,
    output reg rx_done,
    output rx_busy,
    output error,
    output rts_n,
    output reg parity_err,
    output reg frame_err,
    output reg overrun
);
   wire baud_tick;
   wire clr_baud;
   wire parity_bit;
   wire shift_en;
   wire tick_en;
   wire tick_clr;
   wire bit_clr;
   wire bit_last;
   wire [11:0] data_out;
   wire [3:0] num_data_b;
   wire [1:0] num_stop_b;
   wire [3:0] bit_cnt;
   wire [3:0] tick_cnt;
   wire parity_exp;
   wire parity_error;
   wire ctrl_frame_err;
   wire ctrl_rx_done;
   wire [7:0]rx_deframe_data;
   // Reuse the existing per-byte error bit in the 9-bit RX FIFO.
   assign error = parity_error | frame_err;
   
    // 2-FF Synchronizer cho tin hieu rx (chong Metastability)
    reg rx_sync1, rx_sync2;
    reg rx_falling, rx_sync_prv;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            rx_sync_prv <= rx_sync2;
            rx_falling <= (rx_sync_prv == 1'b1) & (rx_sync2 == 1'b0);
        end
    end
    wire rx_fsm_in = (rx_dis) ? 1'b1 : rx_sync2; 
    assign rts_n = rx_done | rx_dis; 

    rx_baud_gen #(
        .CLK_FREQ(CLK_FREQ)
    ) u_rx_baud_gen (
        .div_frac(div_frac),
        .div_int(div_int),
        .clk(clk),
        .rst_n(rst_n),
        .clr_baud(clr_baud),
        .baud_tick(baud_tick)
    );

    rx_controller rx_controller_inst(
        .clk(clk),
        .rst_n(rst_n),
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
        .stop_b_num(stop_b_num),
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
        .clk(clk),
        .rst_n(rst_n),
        .bit_last(bit_last),
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
        end else begin
            if(rx_clear) begin
                rx_done <= 1'b0;
                frame_err <= 1'b0;
                parity_err <= 1'b0;
                overrun <= 1'b0;
            end
            if (ctrl_rx_done) begin
                if(rx_done && !rx_clear) begin
                    overrun <= 1'b1;
                end else begin
                    rx_done <= 1'b1;
                    frame_err <= ctrl_frame_err;
                    parity_err <= parity_error;
                    rx_data <= rx_deframe_data;
                end

        end
        end
    end

endmodule

//cd /home/vietanh/Downloads/code/UART/UART
