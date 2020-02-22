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

module spike_gen (
  clk,
  rstb,
  spike_en,
  input_sum,     
  threshold,
  spike_out
);

// This module generates 1-b spike for a single neuron accumulator or sum from the adder in router

parameter ADDER_WIDTH = 16;
parameter SPIKE_REG_WIDTH = 16;
parameter SUM_WIDTH = ADDER_WIDTH;           // can be overwrite by upper-level as 16b sum_reg input

input clk,rstb;
input spike_en;                     // enable spiking func in this neuron
input [SPIKE_REG_WIDTH-1:0] threshold; 
input [SUM_WIDTH-1:0] input_sum;    // partial sum from local neuron or sum_reg from adder in router

output reg spike_out;

wire above_threshold;
reg  [SPIKE_REG_WIDTH-1:0] potential;

//Prior to receiving first input, potential is 0 and not updated with first input, so need to check input_sum directly
assign above_threshold = ((potential + input_sum - threshold) < 16'h8000)? 1'b1 : 1'b0;

always@(posedge clk)
  begin
    if (!rstb)
        spike_out <= 1'b0;
    else if (spike_en && above_threshold)
        spike_out <= 1'b1;
    else if (spike_en && !above_threshold)
        spike_out <=1'b0;
    else
        spike_out <=1'b0;
  end

always@(posedge clk)
  begin
    if (!rstb)
        potential <= 16'b0;
    else if (spike_en && !above_threshold)
        potential <= potential + input_sum;
    else if (spike_en && above_threshold)
        potential <= potential + input_sum - threshold;
  end

endmodule
