// apb_if — interface APB4 phía completer (spec mục 2, 5): tín hiệu bus, presetn, clocking block cb ở sườn lên pclk.
`timescale 1ns/1ps
interface apb_if (input logic pclk);

  logic        presetn = 1'b0;   // reset tích cực thấp, do ApbMaster điều khiển (không đồng bộ)
  logic        psel    = 1'b0;
  logic        penable = 1'b0;
  logic        pwrite  = 1'b0;
  logic [11:0] paddr   = '0;
  logic [3:0]  pstrb   = '0;
  logic [31:0] pwdata  = '0;
  logic        pready;
  logic        pslverr;
  logic [31:0] prdata;

  // Thời điểm sườn lên gần nhất, để ApbMaster biết đang đứng ở sườn clock hay giữa chu kỳ
  realtime last_edge = -1.0;
  always @(posedge pclk) last_edge = $realtime;

  function automatic bit at_edge();
    return (last_edge == $realtime);
  endfunction

  clocking cb @(posedge pclk);
    default input #1step output #0;
    output psel, penable, pwrite, paddr, pstrb, pwdata;
    input  pready, pslverr, prdata;
  endclocking

  modport master (clocking cb, output presetn, input pclk);

endinterface
