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

module mac (
  clk_in,
  rstb,
  select,
  mem_sd,
  start_mac,
  start_weight,
  axon_all,
  weight,
  accum_out
);

input clk_in;
input rstb;
input [3:0] start_mac;    // 128-cycle, individually for each core
input [3:0] start_weight; // 128-cycle, individually for each core
input [255:0]  axon_all;  // spikes input for 4 cores at one time slot
input [3:0][127:0][4:0]   weight; // weights input for 4 core, each 128*5 bit
input [3:0] select, mem_sd; // 128-cycle each bit corresponding a core utilization 
output reg [255:0][12:0] accum_out;

wire comb_02_en; // combine core 0,2 to a larger core
wire comb_13_en; // combine core 1,3 to a larger core
wire [127:0] axon_0, axon_1, axon_2, axon_3;
wire [127:0][12:0] accum_out_0;
wire [127:0][12:0] accum_out_1;
wire [127:0][12:0] accum_out_2;
wire [127:0][12:0] accum_out_3;
//reg [127:0][12:0] accum_comb_02;
//reg [127:0][12:0] accum_comb_13;

assign comb_02_en = (select[0] && select[2]) ? 1'b1 : 1'b0;
assign comb_13_en = (select[1] && select[3]) ? 1'b1 : 1'b0;

// For 4 independent tasks, time multiplex input for core 0 & 1, core 2 & 3
// If select[0]=select[1]=1, core 0 & 1 will be combined, so as core 2 & 3
assign axon_0 = select[0] ? axon_all[127:0] : 128'b0;
assign axon_1 = select[1] ? axon_all[127:0] : 128'b0;
assign axon_2 = select[2] ? axon_all[255:128] : 128'b0;
assign axon_3 = select[3] ? axon_all[255:128] : 128'b0;

// For 4 independent tasks, time multiplex output for core 0 & 2, core 1 & 3
// If select[0]=select[2]=1, core 0 & 2 will be combined, so as core 1 & 3
//assign accum_out[127:0] = comb_02_en ? accum_comb_02 : (select[0] ? accum_out_0 : (select[2] ? accum_out_2 : 1664'b0));
//assign accum_out[255:128] = comb_13_en ? accum_comb_13 : (select[1] ? accum_out_1 : (select[3] ? accum_out_3 : 1664'b0)); 

//Note, do not code as accum_out[127:0] <= accum_out_0[127:0] + accum_out_2[127:0] otherwise there are independent 13b adders, no carry bit 
genvar i;
generate

for (i=0;i<128;i++)
begin

always@(posedge clk_in)
  begin
    if (!rstb)
         accum_out[i] <= '0;
    else if (comb_02_en)   
            accum_out[i] <= accum_out_0[i] + accum_out_2[i];
    else if (select[0])
            accum_out[i] <= accum_out_0[i];
    else if (select[2])
            accum_out[i] <= accum_out_2[i]; 
   end


always@(posedge clk_in)
  begin
    if (!rstb)
         accum_out[i+128] <= '0;
    else if (comb_13_en)   
            accum_out[i+128] <= accum_out_1[i] + accum_out_3[i];
    else if (select[1])
            accum_out[i+128] <= accum_out_1[i];
    else if (select[3])
            accum_out[i+128] <= accum_out_3[i]; 
   end

end
endgenerate

mac_unit mac_bank0 (
.clk_in (clk_in),
.rstb (rstb),
.start_mac (start_mac[0]),
.start_weight (start_weight[0]),
.axon_in (axon_0),
.weight (weight[0]),
.sel (select[0]),
.mem_sd (mem_sd[0]),
.accum_out_reg (accum_out_0)
);

mac_unit mac_bank1 (
.clk_in (clk_in),
.rstb (rstb),
.start_mac (start_mac[1]),
.start_weight (start_weight[1]),
.axon_in (axon_1),
.weight (weight[1]),
.sel (select[1]),
.mem_sd (mem_sd[1]),
.accum_out_reg (accum_out_1)
);

mac_unit mac_bank2 (
.clk_in (clk_in),
.rstb (rstb),
.start_mac (start_mac[2]),
.start_weight (start_weight[2]),
.axon_in (axon_2),
.weight (weight[2]),
.sel (select[2]),
.mem_sd (mem_sd[2]),
.accum_out_reg (accum_out_2)
);

mac_unit mac_bank3 (
.clk_in (clk_in),
.rstb (rstb),
.start_mac (start_mac[3]),
.start_weight (start_weight[3]),
.axon_in (axon_3),
.weight (weight[3]),
.sel (select[3]),
.mem_sd (mem_sd[3]),
.accum_out_reg (accum_out_3)
);

/*
genvar i;
generate

for (i=0;i<128;i++)
begin

//eliminate extra registers

assign accum_comb_02[i] = comb_02_en? (accum_out_0[i] + accum_out_2[i]) : 13'b0;
assign accum_comb_13[i] = comb_13_en? (accum_out_1[i] + accum_out_3[i]) : 13'b0;

end

endgenerate
*/

endmodule
