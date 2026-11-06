`timescale 1ns/1ps
// Hardware half of scope demo validation: 9600 8N1 A frames with >=5ms gap.
// This is APB stimulus, not a simulation of the Nios CPU/ELF.
module tb_scope_demo;
reg clk=0; always #10 clk=~clk;
reg rst_n=0,psel=0,penable=0,pwrite=0;
reg [11:0] paddr=0;
reg [31:0] pwdata=0;
wire [31:0] prdata;
wire pready,pslverr,tx,irq;
apb_uart dut(.clk(clk),.rst_n(rst_n),.psel(psel),.penable(penable),
 .pwrite(pwrite),.paddr(paddr),.pwdata(pwdata),.prdata(prdata),
 .pready(pready),.pslverr(pslverr),.tx(tx),.rx(1'b1),.irq(irq));
localparam integer BIT_NS=5208*20; // RTL: floor(50MHz/9600) clock cycles/bit.
task access;
 input wr; input [11:0] addr; input [31:0] data;
 output [31:0] result;
 begin
  @(negedge clk); psel=1;penable=0;pwrite=wr;paddr=addr;pwdata=data;
  @(negedge clk); penable=1; #1;
  if(!pready || pslverr)$fatal(1,"APB error");
  result=prdata;
  @(posedge clk); @(negedge clk); psel=0;penable=0;pwrite=0;paddr=0;pwdata=0;
 end
endtask
integer frames=0, i, bit_index;
reg [7:0] data;
reg [31:0] status;
time last_start=0, current_start;
initial begin
 forever begin
  @(negedge tx);
  current_start=$time;
  if(frames>0 && current_start-last_start<10*BIT_NS+5000000)
   $fatal(1,"Idle gap shorter than 5ms");
  last_start=current_start;
  #(BIT_NS/2); if(tx!==0)$fatal(1,"Bad start bit");
  for(bit_index=0;bit_index<8;bit_index=bit_index+1)begin
   #BIT_NS; data[bit_index]=tx;
  end
  #BIT_NS;
  if(tx!==1 || data!==8'h41)$fatal(1,"Not an 8N1 A frame: %h",data);
  frames=frames+1;
 end
end
initial begin
 $dumpfile("build/scope_demo_tx.vcd"); $dumpvars(0,tx);
 repeat(10)@(negedge clk);rst_n=1;
 access(1,12'h008,32'h43,status);
 for(i=0;i<4;i=i+1)begin
  access(1,12'h000,32'h41,status);
  // Wait for the full frame, then observe TX-idle exactly as the driver does.
  wait(frames==i+1);
  access(0,12'h00c,0,status);
  while(!status[0])begin #100;access(0,12'h00c,0,status);end
  #5000000;
 end
 if(frames!=4)$fatal(1,"Unexpected frame count");
 $display("PASS scope RTL: 4 x 0x41, 9600 8N1, bit=%0d ns, frame=%0d ns, idle>=5ms",BIT_NS,10*BIT_NS);
 $finish;
end
initial begin #30000000;$fatal(1,"Scope waveform timeout");end
endmodule
