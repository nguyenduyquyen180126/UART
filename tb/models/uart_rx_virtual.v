`timescale 1ns/1ps

// Simulation-only UART receiver. Samples serial_in at ideal bit centers.
// cfg: [1:0] 5..8 data bits, [2] 1/2 stop, [3] parity enable, [4] odd.
// Configuration is captured at the start edge. No DUT internals are used.
module uart_rx_virtual (
    input wire clk,
    input wire rst_n,
    input wire serial_in,
    input wire [4:0] cfg,
    input wire [31:0] baud_rate,
    output reg [7:0] rx_data,
    output reg rx_done,
    output reg busy,
    output reg start_error,
    output reg parity_error,
    output reg stop_error
);
    integer b, width_bits, stop_bits;
    real bit_period;
    reg [4:0] frame_cfg;
    reg [7:0] sampled_data;
    reg parity_xor;

    initial begin
        rx_data = 0; rx_done = 0; busy = 0;
        start_error = 0; parity_error = 0; stop_error = 0;
        forever begin
            wait (rst_n === 1'b1);
            fork : receiver_or_reset
                begin
                    forever begin
                        @(negedge serial_in);
                        frame_cfg = cfg;
                        if (baud_rate == 0) $fatal(1, "Virtual RX baud must be positive");
                        bit_period = 1.0e9 / baud_rate;
                        width_bits = 5 + frame_cfg[1:0];
                        stop_bits = 1 + frame_cfg[2];
                        busy = 1; sampled_data = 0; parity_xor = 0;
                        start_error = 0; parity_error = 0; stop_error = 0;
                        #(bit_period / 2.0);
                        start_error = (serial_in !== 1'b0);
                        for (b = 0; b < width_bits; b = b + 1) begin
                            #(bit_period);
                            sampled_data[b] = serial_in;
                            parity_xor = parity_xor ^ serial_in;
                        end
                        if (frame_cfg[3]) begin
                            #(bit_period);
                            parity_error = (serial_in !== (parity_xor ^ frame_cfg[4]));
                        end
                        for (b = 0; b < stop_bits; b = b + 1) begin
                            #(bit_period);
                            if (serial_in !== 1'b1) stop_error = 1;
                        end
                        rx_data = sampled_data;
                        rx_done = 1;
                        // Pulse covers one complete clock; serial decoding itself is time-based.
                        @(negedge clk);
                        @(negedge clk);
                        rx_done = 0;
                        busy = 0;
                    end
                end
                begin
                    @(negedge rst_n);
                end
            join_any
            disable receiver_or_reset;
            rx_data = 0; rx_done = 0; busy = 0;
            start_error = 0; parity_error = 0; stop_error = 0;
        end
    end
endmodule
