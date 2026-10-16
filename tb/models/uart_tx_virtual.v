`timescale 1ns/1ps

// Simulation-only UART transmitter. Pulse start for one clock while !busy.
// Data/configuration are latched on acceptance; tx_done marks the end of stop bits.
module uart_tx_virtual (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tx_data,
    input wire [4:0] cfg,
    input wire [31:0] baud_rate,
    input wire inject_parity_error,
    output reg serial_out,
    output reg busy,
    output reg tx_done
);
    integer b, width_bits, stop_bits;
    real bit_period;
    reg [7:0] frame_data;
    reg [4:0] frame_cfg;
    reg parity_bit, frame_inject;

    initial begin
        serial_out = 1; busy = 0; tx_done = 0;
        forever begin
            wait (rst_n === 1'b1);
            fork : transmitter_or_reset
                begin
                    forever begin
                        @(posedge clk);
                        if (start === 1'b1) begin
                            if (baud_rate == 0) $fatal(1, "Virtual TX baud must be positive");
                            frame_data = tx_data;
                            frame_cfg = cfg;
                            frame_inject = inject_parity_error;
                            bit_period = 1.0e9 / baud_rate;
                            width_bits = 5 + frame_cfg[1:0];
                            stop_bits = 1 + frame_cfg[2];
                            busy = 1; tx_done = 0;
                            serial_out = 0;
                            #(bit_period);
                            parity_bit = frame_cfg[4];
                            for (b = 0; b < width_bits; b = b + 1) begin
                                serial_out = frame_data[b];
                                parity_bit = parity_bit ^ frame_data[b];
                                #(bit_period);
                            end
                            if (frame_cfg[3]) begin
                                serial_out = parity_bit ^ frame_inject;
                                #(bit_period);
                            end
                            serial_out = 1;
                            repeat (stop_bits) #(bit_period);
                            busy = 0; tx_done = 1;
                            @(negedge clk);
                            @(negedge clk);
                            tx_done = 0;
                        end
                    end
                end
                begin
                    @(negedge rst_n);
                end
            join_any
            disable transmitter_or_reset;
            serial_out = 1; busy = 0; tx_done = 0;
        end
    end
endmodule
