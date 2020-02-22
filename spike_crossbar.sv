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

module spike_crossbar (
  clk_in,
  rstb,
  spike_sel,
  spike_en,
  local_ps,
  inject_en,
  spike_in_sel,
  spike_out_sel,
  spike_bypass_en,
  spike_buffer_en,
  threshold,
  adder_sum,
  sum_or_local,
  spike_in_north,
  spike_in_south,
  spike_in_east,
  spike_in_west,
  spike_out_north,
  spike_out_south,
  spike_out_east,
  spike_out_west,
  spike_out_core
);

// This module injects a spike produced by spike_gen to crossbar, bypass a spike to distant PE, and register a spike as local axon input
parameter ADDER_WIDTH = 16;
parameter THRESHOLD_WIDTH = 16;
parameter SPIKE_REG_WIDTH = 16;
parameter PS_WIDTH = 13;

input inject_en;                    //note: inject_en is used to inject local spikes to noc, and must be enabled one cycle after enabling spike_en 
input clk_in, rstb, spike_sel;
input spike_en;                     //enable spiking func in this neuron
input spike_bypass_en;
input spike_buffer_en;              //initial spike from input buffer, do not register
//0 for local ps, 1 for added sum
input sum_or_local;
input [1:0] spike_in_sel;
input [1:0] spike_out_sel;
input [THRESHOLD_WIDTH-1:0] threshold; 
input [PS_WIDTH-1:0] local_ps;      //partial sum from local neuron
input [ADDER_WIDTH-1:0] adder_sum;  //spike from router's adder output
input spike_in_north;
input spike_in_south;
input spike_in_east;
input spike_in_west;

reg   spike_in_north_reg;
reg   spike_in_south_reg;
reg   spike_in_west_reg;
reg   spike_in_east_reg;

output reg spike_out_north;
output reg spike_out_south;
output reg spike_out_west;
output reg spike_out_east;
output reg spike_out_core;

reg spike_in;
wire spike_local;
wire [ADDER_WIDTH-1:0] sum;
wire clk;

//clk gating
//CKLNQD24BWP30P140 ICG_spike_crossbar (.TE(1'b0), .E(spike_sel), .CP(clk_in), .Q(clk));
CKLNQD4BWP30P140 ICG_spike_crossbar (.TE(1'b0), .E(spike_sel), .CP(clk_in), .Q(clk));

always@(posedge clk)
  begin
  if (!rstb)
      begin
        spike_in_north_reg <= 1'b0;
        spike_in_south_reg <= 1'b0;
        spike_in_west_reg  <= 1'b0;
        spike_in_east_reg  <= 1'b0;
      end
  else if (!spike_bypass_en && !inject_en && !spike_buffer_en)      //register input spike as axon 
      begin
        spike_in_north_reg <= spike_in_north;
        spike_in_south_reg <= spike_in_south;
        spike_in_west_reg  <= spike_in_west;
        spike_in_east_reg  <= spike_in_east;
      end
  // else is either bypass or generate spike from local ps/adder sum or input from buffer, do not register
  else
       
      begin
      /*
        spike_in_north_reg <= 1'b0;
        spike_in_south_reg <= 1'b0;
        spike_in_west_reg  <= 1'b0;
        spike_in_east_reg  <= 1'b0;
      */
      end
  end

always@*
  begin
    if (spike_bypass_en)
    case (spike_in_sel)
      2'b00: spike_in = spike_in_north;
      2'b01: spike_in = spike_in_south;
      2'b10: spike_in = spike_in_east;
      2'b11: spike_in = spike_in_west;
      default: spike_in = 1'b0;
    endcase
    else if (!inject_en && !spike_buffer_en) // if not bypass, not from local and not from buffer, but register input spike 
    case (spike_in_sel)
      2'b00: spike_in = spike_in_north_reg;
      2'b01: spike_in = spike_in_south_reg;
      2'b10: spike_in = spike_in_east_reg;
      2'b11: spike_in = spike_in_west_reg;
      default: spike_in = 1'b0;
    endcase 
    else if (inject_en)
      spike_in = spike_local;           // spike from local ps or adder sum
    else
      spike_in = 1'b0;
  end

always@(posedge clk)
  begin
    if (!rstb)
       begin
         spike_out_north <= 1'b0;
         spike_out_south <= 1'b0;
         spike_out_east  <= 1'b0;
         spike_out_west  <= 1'b0;
         spike_out_core  <= 1'b0;
       end
    
    else if (spike_bypass_en || inject_en)        // either bypass or inject to destination port 
       case (spike_out_sel)
       2'b00: spike_out_north <= spike_in;
       2'b01: spike_out_south <= spike_in;
       2'b10: spike_out_east  <= spike_in;
       2'b11: spike_out_west  <= spike_in;
       endcase
     else 
         spike_out_core  <= spike_in;            // eject to core as axon
    /*
    else if (!inject_en)  // if not local spike, no matter bypass overlaps or not, spike_out_core needs registered first
         spike_out_core <= spike_in;
    else if (inject_en || spike_bypass_en)
       case (spike_out_sel)
       2'b00: spike_out_north <= spike_in;
       2'b01: spike_out_south <= spike_in;
       2'b10: spike_out_east <=  spike_in;
       2'b11: spike_out_west <=  spike_in; 
       endcase
     */
  end

  spike_gen spike_gen_inst (
  .clk (clk),
  .rstb (rstb),
  .spike_en (spike_en),
  .input_sum (sum),
  .threshold (threshold),
  .spike_out (spike_local)
);

// input sum is either from local partial sum or adder sum, pad to 16b
assign sum = (sum_or_local)? adder_sum : (local_ps[PS_WIDTH-1]==0)? {{{ADDER_WIDTH-PS_WIDTH}{1'b0}},local_ps} : {{{ADDER_WIDTH-PS_WIDTH}{1'b1}},local_ps};

endmodule

