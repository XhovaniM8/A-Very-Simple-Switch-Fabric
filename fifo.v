`timescale 1ns/100ps

module fifo #(
    parameter DWIDTH     = 64,
    parameter LOG2_DEPTH = 4
) (
    input [DWIDTH-1:0]  din,
    input               push,
    output              full,

    output [DWIDTH-1:0] dout,
    input               pop,
    output              empty,
        
    input               clk,
    input               reset
);

reg [DWIDTH-1:0]        ram [(1 << LOG2_DEPTH)-1:0];
reg [LOG2_DEPTH-1:0]    wptr;
wire [LOG2_DEPTH-1:0]   wptr_next;
reg [LOG2_DEPTH-1:0]    rptr;
wire [LOG2_DEPTH-1:0]   rptr_next;
reg                     empty_r;
reg                     full_r;
reg [DWIDTH-1:0]        dout_r;

always @(posedge clk)
    if (reset) begin
        wptr    <= {LOG2_DEPTH{1'b0}};
        rptr    <= {LOG2_DEPTH{1'b0}};
        empty_r <= 1'b1;
        full_r  <= 1'b0;
    end else begin
        if (push && (!full || pop)) begin
            wptr      <= wptr_next;
            ram[wptr] <= din;
            empty_r   <= 1'b0;
            full_r    <= (wptr_next == rptr) && !pop;
        end

        if (pop && !empty) begin
            rptr   <= rptr_next;
            full_r <= full_r && push;
            empty_r <= (rptr_next == wptr) && !push;
        end
    end

assign rptr_next = rptr + 1;
assign wptr_next = wptr + 1;
assign dout  = ram[rptr];
assign empty = empty_r;
assign full  = full_r;

endmodule
