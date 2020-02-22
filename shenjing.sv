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

module shenjing (
       clk_in,
       rstb,
       subcore_sel,
       mem_sd,
       noc_sel,
       weight,
       threshold,
       spike_in_buffer,
       start_instr_b,
       read_or_write,
       addr_count,
       instr_in
);

//Tiles are organized as X rows/num_tiles_in_y_dir, Y columns/num_tiles_in_x_dir
parameter X = 4, Y = 3;

input clk_in, rstb;
input [X-1:0][Y-1:0][3:0] subcore_sel;
input [X-1:0][Y-1:0][3:0] mem_sd;
input [X-1:0][Y-1:0][255:0] noc_sel;
input [X-1:0][Y-1:0][3:0][127:0][4:0] weight;
input [X-1:0][Y-1:0][15:0] threshold;
input [X-1:0][Y-1:0][255:0] spike_in_buffer;
input [X-1:0][Y-1:0] start_instr_b;
input [X-1:0][Y-1:0] read_or_write;
input [X-1:0][Y-1:0][5:0] addr_count;
input [X-1:0][Y-1:0][19:0] instr_in;

wire  [X-1:0][Y-1:0][255:0] spike_in_north;
wire  [X-1:0][Y-1:0][255:0] spike_in_south;
wire  [X-1:0][Y-1:0][255:0] spike_in_east;
wire  [X-1:0][Y-1:0][255:0] spike_in_west;
wire  [X-1:0][Y-1:0][255:0] spike_out_north;
wire  [X-1:0][Y-1:0][255:0] spike_out_south;
wire  [X-1:0][Y-1:0][255:0] spike_out_east;
wire  [X-1:0][Y-1:0][255:0] spike_out_west;

wire [X-1:0][Y-1:0][255:0][15:0] add_in_north;
wire [X-1:0][Y-1:0][255:0][15:0] add_in_south;
wire [X-1:0][Y-1:0][255:0][15:0] add_in_west;
wire [X-1:0][Y-1:0][255:0][15:0] add_in_east;
wire [X-1:0][Y-1:0][255:0][15:0] add_out_north;
wire [X-1:0][Y-1:0][255:0][15:0] add_out_south; 
wire [X-1:0][Y-1:0][255:0][15:0] add_out_west; 
wire [X-1:0][Y-1:0][255:0][15:0] add_out_east; 

wire  [X-1:0][Y-1:0][255:0] w_spike_in_west;
wire  [X-1:0][Y-1:0][255:0] w_spike_in_east;
wire  [X-1:0][Y-1:0][255:0] w_spike_in_north;
wire  [X-1:0][Y-1:0][255:0] w_spike_in_south;
wire  [X-1:0][Y-1:0][255:0] w_spike_out_west;
wire  [X-1:0][Y-1:0][255:0] w_spike_out_east;
wire  [X-1:0][Y-1:0][255:0] w_spike_out_north;
wire  [X-1:0][Y-1:0][255:0] w_spike_out_south;

wire  [X-1:0][Y-1:0][255:0][15:0] w_add_in_west;
wire  [X-1:0][Y-1:0][255:0][15:0] w_add_in_east;
wire  [X-1:0][Y-1:0][255:0][15:0] w_add_in_north;
wire  [X-1:0][Y-1:0][255:0][15:0] w_add_in_south;
wire  [X-1:0][Y-1:0][255:0][15:0] w_add_out_west;
wire  [X-1:0][Y-1:0][255:0][15:0] w_add_out_east;
wire  [X-1:0][Y-1:0][255:0][15:0] w_add_out_north;
wire  [X-1:0][Y-1:0][255:0][15:0] w_add_out_south;

assign spike_in_west     = w_spike_in_west;
assign spike_in_east     = w_spike_in_east;
assign spike_in_north    = w_spike_in_north;
assign spike_in_south    = w_spike_in_south;
assign w_spike_out_west  = spike_out_west;
assign w_spike_out_east  = spike_out_east;
assign w_spike_out_north = spike_out_north;
assign w_spike_out_south = spike_out_south;

//Note: right hand side of assign must be a known signal
assign add_in_west     =   w_add_in_west;
assign add_in_east     =   w_add_in_east;
assign add_in_north    =   w_add_in_north;
assign add_in_south    =   w_add_in_south;
assign w_add_out_west  =   add_out_west;
assign w_add_out_east  =   add_out_east;
assign w_add_out_north =   add_out_north;
assign w_add_out_south =   add_out_south;

generate
genvar i,j;

for(i = 0; i < X; i++)
begin: y_connection
    for(j = 0; j < Y; j++)
    begin: x_connection
 
 // East
        if(j < (Y-1))
        begin 
               assign w_spike_in_east[i][j]   = w_spike_out_west[i][j+1];
               assign w_add_in_east[i][j] = w_add_out_west[i][j+1];
        end
        else
        begin
               assign w_spike_in_east[i][j]   = '0;
               assign w_add_in_east[i][j]   = '0;
        end
 // North
        if(i < (X-1))
        begin
               assign w_spike_in_south[i][j]   = w_spike_out_north[i+1][j];
               assign w_add_in_south[i][j]   = w_add_out_north[i+1][j];
        end
        else
        begin
               assign w_spike_in_south[i][j]   = '0;
               assign w_add_in_south[i][j]   = '0;
        end

 // West
       if(j >= 1)
       begin
              assign w_spike_in_west[i][j] = w_spike_out_east[i][j-1];
              assign w_add_in_west[i][j] = w_add_out_east[i][j-1];
       end
       else
       begin
              assign w_spike_in_west[i][j] = '0;
              assign w_add_in_west[i][j] = '0;
       end
 // South
       if(i >= 1)
       begin
              assign w_spike_in_north[i][j] = w_spike_out_south[i-1][j];
              assign w_add_in_north[i][j] = w_add_out_south[i-1][j];
       end
       else
       begin
              assign w_spike_in_north[i][j] = '0;
              assign w_add_in_north[i][j] = '0;
       end


//Note: can't code as npu_inst[i][j], otherwise error of 'downto' or 'to' appears

    npu                 npu_inst 
    (
    .clk_in             (clk_in),
    .rstb               (rstb),
    .subcore_sel        (subcore_sel[i][j]),
    .mem_sd             (mem_sd[i][j]),
    .noc_sel            (noc_sel[i][j]),
    .weight             (weight[i][j]),
    .threshold          (threshold[i][j]),
    .spike_in_buffer    (spike_in_buffer[i][j]),
    .spike_in_north     (spike_in_north[i][j]),
    .spike_in_south     (spike_in_south[i][j]),
    .spike_in_east      (spike_in_east[i][j]),
    .spike_in_west      (spike_in_west[i][j]),
    .spike_out_north    (spike_out_north[i][j]),
    .spike_out_south    (spike_out_south[i][j]),
    .spike_out_east     (spike_out_east[i][j]),
    .spike_out_west     (spike_out_west[i][j]),
    .add_north_in       (add_in_north[i][j]),
    .add_south_in       (add_in_south[i][j]),
    .add_east_in        (add_in_east[i][j]),
    .add_west_in        (add_in_west[i][j]),
    .add_north_out      (add_out_north[i][j]),
    .add_south_out      (add_out_south[i][j]),
    .add_east_out       (add_out_east[i][j]),
    .add_west_out       (add_out_west[i][j]),
    .start_instr_b      (start_instr_b[i][j]), // port of npu w/ memory
    .read_or_write      (read_or_write[i][j]),
    .addr_count         (addr_count[i][j]),
    .instr_in           (instr_in[i][j])
);
   end
end

endgenerate

endmodule
