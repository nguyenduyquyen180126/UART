`timescale 1ns/1ps

module sync_fifo #(
    parameter DEPTH  = 16,
    parameter DWIDTH = 8
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              wr_en,
    input  wire              rd_en,
    input  wire [DWIDTH-1:0] din,
    output wire [DWIDTH-1:0] dout,
    output wire              empty,
    output wire              full
);
    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [ADDR_WIDTH:0] wptr;
    reg [ADDR_WIDTH:0] rptr;
    reg [DWIDTH-1:0]   fifo [0:DEPTH-1];

    wire wr_valid = wr_en & ~full;
    wire rd_valid = rd_en & ~empty;

    always @(posedge clk) begin
        if (wr_valid) begin
            fifo[wptr[ADDR_WIDTH-1:0]] <= din;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wptr <= {(ADDR_WIDTH+1){1'b0}};
        end else if (wr_valid) begin
            wptr <= wptr + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rptr <= {(ADDR_WIDTH+1){1'b0}};
        end else if (rd_valid) begin
            rptr <= rptr + 1'b1;
        end
    end

    assign dout  = fifo[rptr[ADDR_WIDTH-1:0]];

    assign full  = (wptr[ADDR_WIDTH] != rptr[ADDR_WIDTH]) && 
                   (wptr[ADDR_WIDTH-1:0] == rptr[ADDR_WIDTH-1:0]);
    assign empty = (wptr == rptr);

endmodule