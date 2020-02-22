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

module npu (
       clk_in,
       rstb,
       subcore_sel,
       noc_sel,
       mem_sd,
       weight,
       threshold,
       spike_in_buffer,
       spike_in_north,
       spike_in_south,
       spike_in_east,
       spike_in_west,
       add_north_in,  
       add_north_out,  
       add_south_in,
       add_south_out,
       add_east_in,
       add_east_out,
       add_west_in,
       add_west_out,
       spike_out_north,
       spike_out_south,
       spike_out_east,
       spike_out_west,
       start_instr_b,
       read_or_write,
       addr_count,
       instr_in
       
);

// To incorporate control mem and data mem inside this module for consistent layout abuttment
// parameter X_ID = 0;
// parameter Y_ID = 0;

// 4 128*128 sub-cores
// spike_crossbar inc. spike ejection, pool, spiking and routing
// router_add inc. partial sum injection, addition and routing 
parameter PS_WIDTH = 13;
parameter WEIGHT_WIDTH = 5;
parameter THRESHOLD_WIDTH = 16;
parameter ADDER_WIDTH = 16;

input clk_in,rstb;
input [3:0] subcore_sel, mem_sd;
input [THRESHOLD_WIDTH-1:0] threshold;
input [3:0][127:0][WEIGHT_WIDTH-1:0] weight;
input start_instr_b;
input read_or_write;
input [5:0] addr_count;
input [19:0] instr_in;
input [255:0] noc_sel;
wire [19:0] instr_out;

reg start_instr_reg, read_or_write_reg;
reg [255:0] inject_en;
reg [255:0] sum_or_local;
reg [255:0][1:0] spike_in_sel;
reg [255:0][1:0] spike_out_sel;
reg [255:0] spike_bypass_en;
reg [255:0] spike_buffer_en;
input [255:0] spike_in_buffer;                    // buffer input of spike to kick off cnn
input [255:0] spike_in_north;                     // noc input of spike for transmission among npu
input [255:0] spike_in_south;
input [255:0] spike_in_east;
input [255:0] spike_in_west;
reg [255:0] router_bypass_en;
reg [255:0][1:0] add_in_sel;
reg [255:0][2:0] add_out_sel;
input [255:0][ADDER_WIDTH-1:0] add_north_in;
output [255:0][ADDER_WIDTH-1:0] add_north_out;
input [255:0][ADDER_WIDTH-1:0] add_south_in;
output [255:0][ADDER_WIDTH-1:0] add_south_out;
input [255:0][ADDER_WIDTH-1:0] add_east_in;
output [255:0][ADDER_WIDTH-1:0] add_east_out;
input [255:0][ADDER_WIDTH-1:0] add_west_in;
output [255:0][ADDER_WIDTH-1:0] add_west_out;
output [255:0] spike_out_north;
output [255:0] spike_out_south;
output [255:0] spike_out_east;
output [255:0] spike_out_west;

wire [255:0][PS_WIDTH-1:0] local_ps;
wire [255:0][ADDER_WIDTH-1:0] adder_sum;
reg [3:0] start_mac;
reg [3:0] start_weight;
reg [255:0] spike_en;
wire [255:0] axon;
reg [255:0] add_en;
reg [255:0] sum_en;
reg [255:0] ps_en;
reg [255:0] consec_add_en;
//wire [255:0] noc_sel;
reg [7:0] cycle_gap;
reg [5:0] im_addr;
wire [11:0] instr_dec;
wire [7:0] instr_gap;
wire clk,clk_mem;

//assign noc_sel[127:0] = (subcore_sel[0] | subcore_sel[2])? {128{1'b1}} : '0;
//assign noc_sel[255:128] = (subcore_sel[1] | subcore_sel[3])? {128{1'b1}} : '0;

//Note: clk_in is original clk input w/o clk gating

CKLNQD24BWP30P140 ICG_npu (.TE(1'b0), .E(|subcore_sel), .CP(clk_in), .Q(clk)); 
`ifndef DC_ONLY  //for RTL simulation
assign #1 clk_mem = clk;
`else
assign clk_mem = clk;
`endif

TS1N28LPB64X20M4SSOR instruction_mem (
.CLK (clk_mem),
.SLP (1'b0),
.SD (~(|subcore_sel)),  //bitwise OR all bits in subcore_sel
.CEB (start_instr_b),
.WEB (read_or_write),
.RSTB (rstb),
.SCLK (1'b0),
.SDIN (1'b0),
.SDOUT (),
.A (im_addr | addr_count),   //addr_count is address during load of instr to mem
.D (instr_in),
.Q (instr_out)
);

always @(posedge clk)
  begin
    if (!rstb)
       begin
         start_instr_reg <=0;
         read_or_write_reg <=0;
       end
    else
      begin
        start_instr_reg <= start_instr_b;
        read_or_write_reg <= read_or_write;
      end
   end

always @(posedge clk) 
  begin 
    if (!rstb) 
       begin
         cycle_gap <= '0;
         im_addr <= '0;
       end
    else if (start_instr_reg ==0 && read_or_write_reg == 1'b1)   //read instr memory
    //else
      begin
        if (instr_gap == 8'b11111111)  //gap = -1, indicating end of instruction read
          begin
            cycle_gap <= '0;
            im_addr <= '0;
          end
        else if (cycle_gap == instr_gap)    //wait for cycles = cycle_gap then read
          begin   
            cycle_gap <= '0;
            im_addr <= im_addr + 1'b1;
          end
        else 
          cycle_gap <= cycle_gap + 1'b1;
      end
    else 
      begin
        cycle_gap <= '0;
        im_addr <= '0;
      end
  end

assign instr_dec = instr_out[19:8];
assign instr_gap = instr_out[7:0];

//assign sum_instr = ((instr_dec != 12'hfff) && instr_dec[11])? 1'b1 : 1'b0;



genvar j;
generate

for (j=0;j<256;j++)
begin

always @(posedge clk)
  begin 
    if (!rstb)
      begin
        ps_en[j] <= 0;
        sum_en[j] <= 0;
        add_in_sel[j] <= 0;
        add_out_sel[j] <= 0;
        add_en[j] <= 0;
        consec_add_en[j] <= 0;
        router_bypass_en[j] <= 0;
        spike_buffer_en[j] <= 0;
        spike_en[j] <= 0;
        sum_or_local[j] <= 0;
        inject_en[j] <= 0;
        spike_in_sel[j] <= 0;
        spike_out_sel[j] <= 0;
        spike_bypass_en[j] <= 0;
        //start_weight <= 0;
        //start_mac <= 0;
      end 
    else if (instr_dec == 12'hfff)
      begin
       //load_image
      end
    else if (instr_dec[11:10] == 2'b00)   //partial sum instruction
      begin
        ps_en[j]            <= instr_dec[9];  //instr_dec[10];
        sum_en[j]           <= instr_dec[8];  //instr_dec[9];
        add_in_sel[j]       <= instr_dec[7:6];
        add_out_sel[j]      <= instr_dec[5:3];
        add_en[j]           <= instr_dec[2];
        consec_add_en[j]    <= instr_dec[1];
        router_bypass_en[j] <= instr_dec[0]; 
      end
    else if (instr_dec[11:10] == 2'b01)   //spike instruction 
      begin
        spike_buffer_en[j]  <= instr_dec[9];
        spike_en[j]         <= instr_dec[8];
        sum_or_local[j]     <= instr_dec[7];
        inject_en[j]        <= instr_dec[6];
        spike_in_sel[j]     <= instr_dec[5:4];
        spike_out_sel[j]    <= instr_dec[3:2];
        spike_bypass_en[j]  <= instr_dec[1]; 
      end
    //else if (instr_dec[11:10] == 2'b10)
    //  begin
    //    start_weight        <= instr_dec[7:4];
    //    start_mac           <= instr_dec[3:0];
    //  end
  end

end

endgenerate

always@(posedge clk)
  if (!rstb)
    begin
      start_mac <= 4'b0;
      start_weight <= 4'b0;
    end
  else if (instr_dec[11:10] == 2'b10)
    begin
      start_weight        <= instr_dec[7:4];
      start_mac           <= instr_dec[3:0];
    end


mac mac_inst ( 
.clk_in (clk_in),
.rstb (rstb),
.select (subcore_sel),
.mem_sd (mem_sd),
.start_mac (start_mac),               //internal timing signal
.start_weight (start_weight),         //internal timing signal
.axon_all (axon | spike_in_buffer),   //decode from spike_gen module (or input buffer?)
.weight (weight),   
.accum_out (local_ps)                 //generate local partial sum
);

//Note: genvar needs defined before generate
genvar i;
generate

for (i=0;i<256;i++)
begin

spike_crossbar spike_crossbar_inst (
.clk_in (clk_in),
.rstb (rstb),
.spike_sel (noc_sel[i]),
.spike_en (spike_en[i]),                  //internal timing signal
.local_ps (local_ps[i]),
.inject_en (inject_en[i]),
.spike_in_sel (spike_in_sel[i]),
.spike_out_sel (spike_out_sel[i]),
.spike_bypass_en (spike_bypass_en[i]),
.spike_buffer_en (spike_buffer_en[i]),
.threshold (threshold),
.adder_sum (adder_sum[i]),
.sum_or_local (sum_or_local[i]),
.spike_in_north (spike_in_north[i]),
.spike_in_south (spike_in_south[i]),
.spike_in_east (spike_in_east[i]),
.spike_in_west (spike_in_west[i]),
.spike_out_north (spike_out_north[i]),
.spike_out_south (spike_out_south[i]),
.spike_out_east (spike_out_east[i]),
.spike_out_west (spike_out_west[i]),
.spike_out_core (axon[i])
);

router_add router_add_inst (
.clk_in (clk_in),
.rstb (rstb),
.add_sel (noc_sel[i]),
.add_en (add_en[i]),                  //internal timing
.input_sel (add_in_sel[i]),
.output_sel (add_out_sel[i]),
.sum_en (sum_en[i]),
.ps_en (ps_en[i]),
.bypass_en (router_bypass_en[i]),
.consec_add_en (consec_add_en[i]),
.local_ps (local_ps[i]),
.north_in (add_north_in[i]),
.south_in (add_south_in[i]),
.east_in (add_east_in[i]),
.west_in (add_west_in[i]),
.north_out (add_north_out[i]),
.south_out (add_south_out[i]),
.east_out (add_east_out[i]),
.west_out (add_west_out[i]),
.sum_reg (adder_sum[i])
);

end
endgenerate


endmodule
