// uart_if — tín hiệu nối tiếp và điều khiển luồng của apb_uart (spec mục 2); không clocking vì rx, cts_n không đồng bộ với pclk.
`timescale 1ns/1ps
interface uart_if;
  logic rx    = 1'b1;   // mức nghỉ 1, do UartExtTx lái
  logic cts_n = 1'b0;   // mặc định cho phép phát
  logic tx;
  logic rts_n;
  logic irq;
endinterface
