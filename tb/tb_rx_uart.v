`timescale 1ns/1ps
module tb_rx_uart();
    reg clk, rst_n, baud_en, data_tx;
    reg [1:0] parity_type;
    reg [1:0] baud_rate;
    wire [7:0] raw_data;
    wire [2:0] error_flag;
    wire done_flag;

    rx_uart rx_uart_dut(
        .clk(clk),
        .rst_n(rst_n),
        .baud_rate(baud_rate),
        .data_tx(data_tx),
        .parity_type(parity_type),
        .raw_data(raw_data),
        .error_flag(error_flag),
        .done_flag(done_flag)
    );
    integer bit_time;
    task set_baud_rate(input [1:0] rate);
        begin
            baud_rate = rate;
            case(rate)
                2'b00: bit_time = 416667; // 2400 baud
                2'b01: bit_time = 208333; // 4800 baud
                2'b10: bit_time = 104000; // 9600 baud
                2'b11: bit_time = 52083;  // 19200 baud
            endcase
        end
    endtask
    task send_byte(input [7:0] byte_data);
        integer i;
        begin
            data_tx = 1'b0;
            #(bit_time);
            for(i = 0; i < 8; i = i + 1) begin
                data_tx = byte_data[i];
                #(bit_time);
            end
            data_tx = ~(^byte_data);
            #(bit_time);
            data_tx = 1'b1;
            #(bit_time);
        end
    endtask
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_rx_uart);
        $monitor("Time %0t: raw_data = %h, error_flag = %b, done_flag = %b",
  $time, raw_data, error_flag, done_flag);
        rst_n = 1'b0;
        baud_rate = 2'b00;
        data_tx = 1'b1;
        parity_type = 2'b00;
        set_baud_rate(2'b10);
        #20 rst_n = 1'b1;
        set_baud_rate(2'b10);
        #10 parity_type = 2'b01;
        send_byte(8'hA5);
        #(bit_time * 2);
        
        send_byte(8'h5A);
        #(bit_time * 2);
        send_byte(8'hFF);
        #(bit_time * 2);
        #2000 $finish;

    end
endmodule