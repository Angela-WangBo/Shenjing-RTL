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

module router_add (
  clk_in,
  rstb,
  add_sel,
  add_en,
  input_sel,
  output_sel,
  sum_en,
  ps_en,
  bypass_en,
  consec_add_en,
  local_ps,
  north_in,
  south_in,
  east_in,
  west_in,
  north_out,
  south_out,
  east_out,
  west_out,
  sum_reg
);

// This module route partial sum either from local or from input ports
// Partial sum from input ports either bypass this core to other distant PE, or registered as an operand for addition in router

parameter WEIGHT_WIDTH=5;                  //2's complementory to represent signed weight value
parameter ADDER_WIDTH=16;                  //adder in router width
parameter PS_WIDTH=13;                     //local partial sum width
parameter INPUT_WIDTH=16;                  //width of partial sum from remote cores

input      clk_in, rstb, add_sel;
input      add_en, bypass_en, ps_en, sum_en;              //provided by control mem, eject partial sum by ps_en, eject sum_reg by sum_en
input      consec_add_en;                  //enable consecutive adding, from control mem
input      [1:0]  input_sel;               //select remote input port
input      [2:0]  output_sel;              //select output port, further spiking is from sum_reg directly thus no selection code 
input      [PS_WIDTH-1:0] local_ps;        //partial_sum from local mac
input      [ADDER_WIDTH-1:0] north_in;     //partial_sum from remote neuron
output reg [ADDER_WIDTH-1:0] north_out;    //partial_sum from remote neuron
input      [ADDER_WIDTH-1:0] south_in;     //partial_sum from remote neuron
output reg [ADDER_WIDTH-1:0] south_out;    //partial_sum from remote neuron
input      [ADDER_WIDTH-1:0] east_in;      //partial_sum from remote neuron
output reg [ADDER_WIDTH-1:0] east_out;     //partial_sum from remote neuron
input      [ADDER_WIDTH-1:0] west_in;      //partial_sum from remote neuron
output reg [ADDER_WIDTH-1:0] west_out;     //partial_sum from remote neuron
output reg [ADDER_WIDTH-1:0] sum_reg;
reg        [ADDER_WIDTH-1:0] local_out;

reg [ADDER_WIDTH-1:0] op2;            // reg declaration doesn't necessarily map to a register/flip flop, in this case, op is a mux
wire [ADDER_WIDTH-1:0] op1;
reg [ADDER_WIDTH-1:0] op1_reg;
      
reg [ADDER_WIDTH-1:0] north_in_reg;
reg [ADDER_WIDTH-1:0] south_in_reg;
reg [ADDER_WIDTH-1:0] east_in_reg;
reg [ADDER_WIDTH-1:0] west_in_reg;
reg [INPUT_WIDTH-1:0] bypass_out;
wire clk;

CKLNQD4BWP30P140 ICG_router_add (.TE(1'b0), .E(add_sel), .CP(clk_in), .Q(clk));

// for consective additions if needed, sum_reg is fed into input for further additions
 assign op1 = consec_add_en ? sum_reg : local_ps[PS_WIDTH-1] ? {{{ADDER_WIDTH-PS_WIDTH}{1'b1}},local_ps} : {{{ADDER_WIDTH-PS_WIDTH}{1'b0}},local_ps};


always@ (posedge clk)
  if (!rstb)
    op1_reg <= {ADDER_WIDTH{1'b0}};
  //else if (consec_add_en | add_en)
  //  op1_reg <= op1;
  else
    op1_reg <= op1;


// register input to crossbar
always@ *
  begin
  op2 = {ADDER_WIDTH{1'b0}};
  if (!bypass_en)
    case (input_sel)
      2'b00: op2 = north_in_reg;
      2'b01: op2 = south_in_reg;
      2'b10: op2 = east_in_reg;
      2'b11: op2 = west_in_reg;
      //default: op2 = {ADDER_WIDTH{1'b0}};        //make op2 = 0, inject local partial sum to NoC only
    endcase
  end

always@(posedge clk)
  begin
    if (!rstb)
        begin
          north_in_reg <= {INPUT_WIDTH{1'b0}};
          south_in_reg <= {INPUT_WIDTH{1'b0}};
          east_in_reg  <=  {INPUT_WIDTH{1'b0}};
          west_in_reg  <=  {INPUT_WIDTH{1'b0}};
        end
    else if (!bypass_en)      //register input
        begin
          case (input_sel)
            2'b00: north_in_reg <= north_in;
            2'b01: south_in_reg <= south_in;
            2'b10: east_in_reg  <= east_in;
            2'b11: west_in_reg  <= west_in;
          endcase
        end
  end

always@ *
  begin
  if (bypass_en)
      case (input_sel)
        2'b00: bypass_out = north_in;
        2'b01: bypass_out = south_in;
        2'b10: bypass_out = east_in;
        2'b11: bypass_out = west_in;
      endcase
  else 
               bypass_out = {INPUT_WIDTH{1'b0}};
  end

// bypass output
always@(posedge clk)
  if (!rstb)
    begin
      north_out <= {ADDER_WIDTH{1'b0}};
      south_out <= {ADDER_WIDTH{1'b0}};
      east_out  <= {ADDER_WIDTH{1'b0}};
      west_out  <= {ADDER_WIDTH{1'b0}};
      local_out <= {ADDER_WIDTH{1'b0}};
    end
  else if (bypass_en)
      case (output_sel)  // bypass this core to distant PE
         3'b000: north_out <= bypass_out;
         3'b001: south_out <= bypass_out;
         3'b010: east_out  <= bypass_out;
         3'b011: west_out  <= bypass_out;
         3'b100: local_out <= {ADDER_WIDTH{1'b0}};
      endcase
   else if (sum_en)      // route sum value after addition
       case (output_sel)
         3'b000: north_out <= sum_reg;
         3'b001: south_out <= sum_reg;
         3'b010: east_out  <= sum_reg;
         3'b011: west_out  <= sum_reg;
         3'b100: local_out <= sum_reg;        //send sum result to local for spiking, but use sum_reg instead for timing
       endcase
    else if (ps_en)      // route local partial sum only
        case (output_sel)
         3'b000: north_out <= op1;
         3'b001: south_out <= op1;
         3'b010: east_out  <= op1;
         3'b011: west_out  <= op1;
         3'b100: local_out <= {ADDER_WIDTH{1'b0}};
        endcase

always@(posedge clk)
  begin
    if (!rstb)
        sum_reg <= {ADDER_WIDTH{1'b0}};
    else if (add_en & !consec_add_en)
        sum_reg <= op1_reg + op2;
        //sum_reg <= op1 + op2;
    else if (consec_add_en)
        sum_reg <= sum_reg;
    else
        sum_reg <= {ADDER_WIDTH{1'b0}};   //output sum_reg in case further spiking
  end

endmodule
