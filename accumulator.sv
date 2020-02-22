//Copyright (c) Dr Bo Wang, National University of Singapore.
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in
//all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//THE SOFTWARE.

module accumulator (
  start,
  en,
  clk,
  rstb,
  A,
  S
);

parameter WEIGHT_WIDTH=5;
parameter DIMENSION = 128;
parameter ADDR_WIDTH = 7;

// implement a 13-bit accummulator with enable, output the sum with a flag of DONE for further adding 
input start;
input en;   // data gating from axon_in
input clk;
input rstb;
input [WEIGHT_WIDTH-1:0] A;
output reg [WEIGHT_WIDTH+ADDR_WIDTH:0] S;

//CKLNQD4BWP30P140 ICG_accum (.TE(1'b0), .E(sel), .CP(clk), .Q(clk_out)); 

`ifndef ACCUM_BB
reg [WEIGHT_WIDTH+ADDR_WIDTH:0] A_pad;

always@*
 begin
  if (A!=0)
     begin
       case (A[WEIGHT_WIDTH-1])
            2'b0: A_pad <= {{{ADDR_WIDTH+1}{1'b0}},A};
            2'b1: A_pad <= {{{ADDR_WIDTH+1}{1'b1}},A};
       endcase
     end
 end

always@(posedge clk)
  begin
    if (!rstb)
      S <= 13'b0;
    else if (start)
      begin
        if (en)
           S <= S + A_pad;
        else 
           S <= S;
      end
    else
      S <= 13'b0;
  end


`endif       
endmodule
