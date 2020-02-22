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

module mac_unit (
  clk_in,
  rstb,
  start_mac,           //data gating
  start_weight,
  axon_in,
  weight,
  sel,                 //memory sleep, if memory computing is not requred in this subcore at the moment
  mem_sd,              //memory shut down
  accum_out_reg  
);

parameter DIMENSION = 128;
parameter ADDR_WIDTH = 7;
parameter WEIGHT_WIDTH = 5;   // 5-bit weight, first bit as sign

input                                         clk_in, sel, mem_sd;
input                                         rstb;
input                                         start_mac;     // 128-cycle indicating axon_in is ready for mac operation
input                                         start_weight;  // 128-cycle indicating weight updating in SRAM
input  [DIMENSION-1:0]                        axon_in;       // 1-b spike for 128 input neurons
input  [DIMENSION-1:0][WEIGHT_WIDTH-1:0]      weight;        // to update 5-b weight of 128 output neurons at a time, [M-1:0][N-1:0] is M-BY-N packed array, a slice of N-bits can be read out of M index
output reg [DIMENSION-1:0][12:0]              accum_out_reg; // register output of 128 adders

`ifndef MAC_UNIT_BB
logic                      chip_en;
logic                      ceb;
logic                      write_enb;
logic   [WEIGHT_WIDTH-1:0][DIMENSION-1:0]  mem_data_out; // SRAM multiplier output, 5 SRAMs output, each with 128b
logic   [DIMENSION-1:0]    weight_in_0;
logic   [DIMENSION-1:0]    weight_in_1;
logic   [DIMENSION-1:0]    weight_in_2;
logic   [DIMENSION-1:0]    weight_in_3;
logic   [DIMENSION-1:0]    weight_in_4;

reg                       start_mac_reg;
reg                       start_weight_reg;
reg    [ADDR_WIDTH-1:0]   count;
reg    [ADDR_WIDTH-1:0]   acc_count;
reg                       DONE;
logic                      clk_mem00, clk_mem0;
logic                      clk_mem01, clk_mem1;
logic                      clk_mem10, clk_mem2;
logic                      clk_mem11, clk_mem3;
logic                      clk_mem20, clk_mem4;
logic                      clk_mem21, clk_mem5;
logic                      clk_mem30, clk_mem6;
logic                      clk_mem31, clk_mem7;
logic                      clk_mem40, clk_mem8;
logic                      clk_mem41, clk_mem9;
//logic                      mem_sleep;
logic                      clk;

//as memory operation requires satisfaction of setup/hold timing, delay memory clock to establish data setup
//at place & route phase, encounter tool will fix timing so memory delayed clock is not necessary

`ifndef DC_ONLY  //for RTL simulation

assign #1 clk_mem00 = clk_mem0;   
assign #1 clk_mem01 = clk_mem1;
assign #1 clk_mem10 = clk_mem2;
assign #1 clk_mem11 = clk_mem3;
assign #1 clk_mem20 = clk_mem4;
assign #1 clk_mem21 = clk_mem5;
assign #1 clk_mem30 = clk_mem6;
assign #1 clk_mem31 = clk_mem7;
assign #1 clk_mem40 = clk_mem8;
assign #1 clk_mem41 = clk_mem9;

`else

assign clk_mem00 = clk_mem0;      //for dc & PnR
assign clk_mem01 = clk_mem1;      //for dc & PnR
assign clk_mem10 = clk_mem2;      //for dc & PnR
assign clk_mem11 = clk_mem3;      //for dc & PnR
assign clk_mem20 = clk_mem4;      //for dc & PnR
assign clk_mem21 = clk_mem5;      //for dc & PnR
assign clk_mem30 = clk_mem6;      //for dc & PnR
assign clk_mem31 = clk_mem7;      //for dc & PnR
assign clk_mem40 = clk_mem8;      //for dc & PnR
assign clk_mem41 = clk_mem9;      //for dc & PnR

`endif

//insert clock gating latch to reduce power
CKLNQD24BWP30P140 ICG_mac_unit00 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem0));
CKLNQD24BWP30P140 ICG_mac_unit01 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem1));
CKLNQD24BWP30P140 ICG_mac_unit10 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem2));
CKLNQD24BWP30P140 ICG_mac_unit11 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem3));
CKLNQD24BWP30P140 ICG_mac_unit20 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem4));
CKLNQD24BWP30P140 ICG_mac_unit21 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem5));
CKLNQD24BWP30P140 ICG_mac_unit30 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem6));
CKLNQD24BWP30P140 ICG_mac_unit31 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem7));
CKLNQD24BWP30P140 ICG_mac_unit40 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem8));
CKLNQD24BWP30P140 ICG_mac_unit41 (.TE(1'b0), .E(sel), .CP(clk_in), .Q(clk_mem9));
assign clk = clk_in;

//single port SRAM banks of 128x(64x2)x5
//compute with 5 banks for 5-bit weight 


//func: split 5-b weight to 5 SRAMs
//Note: assign rhs should be known value
genvar i;
for (i=0;i<DIMENSION;i++) 
  begin 
    assign {weight_in_4[i],weight_in_3[i],weight_in_2[i],weight_in_1[i],weight_in_0[i]} = {weight[i][4],weight[i][3],weight[i][2],weight[i][1],weight[i][0]};
  end

//func: update weight to 128-entry SRAMs with 128 cycles; input axon to 128-entry SRAMs with 128 cycles
       
always@(posedge clk)
  if(!rstb)
    count <= 7'b0;
  else if (start_mac_reg | start_weight_reg)
    begin 
      if (count != 127)
          count <= count + 1;
      else
          count <= 7'b0;
    end
  else
    count <= 7'b0;


//generate mem control signals
assign write_enb = (start_mac == 1'b1) ? 1'b1 : (start_weight == 1'b1) ? 1'b0 : 1'b1;  // read when start_mac, wirte when start_weight
assign chip_en = (start_mac == 1'b1 && axon_in[count] == 1'b1) ? 1'b1 : (start_weight == 1'b1) ? 1'b1 : 1'b0;
assign ceb  = (sel == 1'b1 && chip_en == 1'b1)? 1'b0 : 1'b1;   //memory enabled only when the subcore is selected and chip_en is enabled

//Note: for simulation simplicity, make SLP = ~sel; should assign mem_sleep to SLP at PnR
TS1N28LPB128X64M4SSOR mem_bank40 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_4[63:0]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem40),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[4][63:0])
);

TS1N28LPB128X64M4SSOR mem_bank41 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_4[127:64]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem41),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[4][127:64])
);

TS1N28LPB128X64M4SSOR mem_bank30 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_3[63:0]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem30),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[3][63:0])
);

TS1N28LPB128X64M4SSOR mem_bank31 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_3[127:64]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem31),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[3][127:64])
);

TS1N28LPB128X64M4SSOR mem_bank20 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_2[63:0]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem20),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[2][63:0])
);

TS1N28LPB128X64M4SSOR mem_bank21 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_2[127:64]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem21),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[2][127:64])
);

TS1N28LPB128X64M4SSOR mem_bank10 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_1[63:0]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem10),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[1][63:0])
);

TS1N28LPB128X64M4SSOR mem_bank11 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_1[127:64]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem11),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[1][127:64])
);

TS1N28LPB128X64M4SSOR mem_bank00 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_0[63:0]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem00),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[0][63:0])
);

TS1N28LPB128X64M4SSOR mem_bank01 (
  .SLP (~sel),
  .A (count),
  .D (weight_in_0[127:64]),
  .WEB (write_enb),
  .CEB (ceb),
  .CLK (clk_mem01),
  .RSTB (rstb),
  .SCLK (1'b0),
  .SDIN (1'b0),
  .SDOUT (),
  .SD (mem_sd),
  .Q (mem_data_out[0][127:64])
);


logic [DIMENSION-1:0][WEIGHT_WIDTH-1:0] product_in;
logic [DIMENSION-1:0][WEIGHT_WIDTH+ADDR_WIDTH:0] accum_out;

// delay start_mac to make sure input ready to accumulator
always@(posedge clk)
begin
 if (!rstb)
    start_mac_reg <= 1'b0;
 else 
    start_mac_reg <= start_mac;
end

always@(posedge clk)
begin
  if (!rstb)
     start_weight_reg <= 1'b0;
  else
     start_weight_reg <= start_weight;
end


genvar k;
generate

for (k=0;k<DIMENSION;k++)
begin
assign product_in[k] = {mem_data_out[4][k],mem_data_out[3][k],mem_data_out[2][k],mem_data_out[1][k],mem_data_out[0][k]};

// to compare power of accumu in this version with new version w/o en and accum_out_reg
accumulator accum_inst (
.start  (start_mac_reg),
.en   (axon_in[count] && product_in[k]),
.clk  (clk),
.rstb (rstb),
.A    (product_in[k]),
.S    (accum_out[k])
);

always@(posedge clk) 
begin
  if(rstb==0)
    accum_out_reg[k] <= 13'b0;
  else if (DONE) 
    accum_out_reg[k] <= accum_out[k];
  else 
    accum_out_reg[k] <= accum_out_reg[k];
end

end

endgenerate

always@(posedge clk)
begin
  if (rstb==0 | start_mac_reg==0)
    begin
      DONE <= 1'b0;
      acc_count <= 7'b0;
    end
  else
  begin
  if (acc_count != (DIMENSION-1))
    begin
      acc_count <= acc_count + 1;
      DONE  <= 1'b0;
    end
  else
    begin
      acc_count <= 7'b0;
      DONE  <= 1'b1;
    end
  end
end


`endif

endmodule
