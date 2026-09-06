`timescale 1ns/1ps
module tb_tx_uart();

    reg send;
    reg [1:0] baud_rate;
    reg clk, rst_n;
    reg [7:0] data_in;
    reg [1:0] parity_type;
    wire active;
    wire data_tx;
    tx_uart  dut(
        .send(send),
        .baud_rate(baud_rate),
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .parity_type(parity_type),
        .active(active),
        .data_tx(data_tx)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        $monitor("Time %0t: data_tx = %b, active = %b", $time, data_tx, active);
        send = 0;
        baud_rate = 2'b00;
        rst_n = 0;
        data_in = 8'b10101010;
        parity_type = 2'b00;
        @(negedge clk);
        rst_n = 1;
        send = 1;
        #5000000;
        $finish;
    end
endmodule