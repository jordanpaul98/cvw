///////////////////////////////////////////
// simpleram.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified: 
//
// Purpose: On-chip SIMPLERAM, external to core
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// MIT LICENSE
// Permission is hereby granted, free of charge, to any person obtaining a copy of this 
// software and associated documentation files (the "Software"), to deal in the Software 
// without restriction, including without limitation the rights to use, copy, modify, merge, 
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
// to whom the Software is furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all copies or 
//   substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
//   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
//   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
//   OR OTHER DEALINGS IN THE SOFTWARE.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module simpleram #(parameter BASE=0, RANGE = 65535) (
  input  logic             clk, 
  input  logic [31:0]      a,
  input  logic             we,
  input  logic [`XLEN/8-1:0] ByteWe,
  input  logic [`XLEN-1:0] wd,
  output logic [`XLEN-1:0] rd
);

  logic [`XLEN-1:0] RAM[BASE>>(1+`XLEN/32):(RANGE+BASE)>>1+(`XLEN/32)];
  
  // discard bottom 2 or 3 bits of address offset within word or doubleword
  localparam adrlsb = (`XLEN==64) ? 3 : 2;
  logic [31:adrlsb] adrmsbs;
  assign adrmsbs = a[31:adrlsb];

  always_ff @(posedge clk)
    rd <= RAM[adrmsbs];

  genvar            index;
  for(index = 0; index < `XLEN/8; index++) begin
    always_ff @(posedge clk) begin
      if (we & ByteWe[index]) RAM[adrmsbs][8*(index+1)-1:8*index] <= #1 wd[8*(index+1)-1:8*index];
    end
  end
endmodule

