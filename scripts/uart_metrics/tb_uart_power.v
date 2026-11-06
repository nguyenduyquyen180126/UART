`timescale 1ns/1ps
module tb_uart_power;
reg clk=0;
always #10 clk=~clk;
reg rst_n=0, psel=0, penable=0, pwrite=0;
reg [11:0] paddr=0;
reg [31:0] pwdata=0;
wire [31:0] prdata;
wire pready, pslverr, tx, irq;
apb_uart dut(.clk(clk),.rst_n(rst_n),.psel(psel),.penable(penable),
 .pwrite(pwrite),.paddr(paddr),.pwdata(pwdata),.prdata(prdata),
 .pready(pready),.pslverr(pslverr),.tx(tx),.rx(tx),.irq(irq));
task access;
 input wr; input [11:0] addr; input [31:0] data;
 output [31:0] result;
 begin
  @(negedge clk); psel=1; penable=0; pwrite=wr; paddr=addr; pwdata=data;
  @(negedge clk); penable=1; #1;
  if (!pready || pslverr) $fatal(1,"APB error addr=%h",addr);
  result=prdata;
  @(posedge clk);
  @(negedge clk); psel=0; penable=0; pwrite=0; paddr=0; pwdata=0;
 end
endtask
reg [31:0] value, status;
integer sent=0, received=0, polls=0;
initial begin
 repeat(10) @(negedge clk); rst_n=1;
 // 19200,8N1 and RX/overrun interrupts. TX complete enabled as well.
 access(1,12'h008,32'h63,value);
 access(1,12'h010,32'h7,value);
 #1000;
 if ($test$plusargs("IDLE")) begin
  $dumpfile("idle_raw.vcd"); $dumpvars(0,dut);
  #5000000;
  $display("PASS idle: 5 ms, 50 MHz, 19200 8N1, no APB traffic");
 end else begin
  $dumpfile("active_raw.vcd"); $dumpvars(0,dut);
  // Bounded polling workload, back-to-back UART TX/RX through loopback.
  while(received<32 && polls<4000) begin
   access(0,12'h00c,0,status);
   if(status[3]) $fatal(1,"RX overrun");
   if(status[1]) begin
    access(0,12'h004,0,value);
    if(value[8] || value[7:0] !== ((received*73+8'h55)&255))
     $fatal(1,"RX mismatch at %0d: %h",received,value);
    received=received+1;
   end
   if(!status[4] && sent<32) begin
    access(1,12'h000,(sent*73+8'h55)&255,value);
    sent=sent+1;
   end
   polls=polls+1;
   #10000;
  end
  if(received!=32) $fatal(1,"Timeout: received %0d",received);
  $display("PASS active: TX=%0d RX=%0d, polls=%0d, time_ns=%0t",sent,received,polls,$time);
 end
 $dumpoff; $finish;
end
endmodule
