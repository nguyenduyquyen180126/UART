`timescale 1ns/1ps
module tb_tx_baud_gen();
    reg clk, rst_n;
    reg [1:0] baud_rate;
    wire baud_en;

    tx_baud_gen dut(
        .clk(clk),
        .rst_n(rst_n),
        .baud_rate(baud_rate),
        .baud_en(baud_en)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        $monitor("Time %0t: (baud_rate %b, rst_n = %b) baud_en %0b", $time, baud_rate, rst_n, baud_en);
        rst_n = 0;
        baud_rate = 2'b00;
        @(posedge clk);
        rst_n = 1;
        #2000000;
        baud_rate = 2'b01;
        #210000;
        baud_rate = 2'b10;
        #210000;
        baud_rate = 2'b11;
        #210000;

        $finish;
    end
endmodule