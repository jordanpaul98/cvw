///////////////////////////////////////////
// cacheLFSR=.sv
//
// Original Written (LRU): Rose Thompson ross1728@gmail.com
// Created: 20 July 2021
// Modified: 4 may 2024 - Jordan Paul
// Adopts LRU for LFSR
//
//  ICACHE in ifu.sv
//  DCACHE in lsu.sv
//
// Purpose: Implements Linear Feedback shift Register (LSFR) for victim way
//
// Documentation: RISC-V System on Chip Design Chapter 7 (Figures 7.8 and 7.15 to 7.18)
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module cacheLFSR
  #(parameter NUMWAYS = 4, SETLEN = 9, OFFSETLEN = 5, NUMLINES = 128) (
  input  logic                clk, 
  input  logic                reset,
  input  logic                FlushStage,
  input  logic                CacheEn,         // Enable the cache memory arrays.  Disable hold read data constant
  input  logic [NUMWAYS-1:0]  HitWay,          // Which way is valid and matches PAdr's tag
  input  logic [NUMWAYS-1:0]  ValidWay,        // Which ways for a particular set are valid, ignores tag
  input  logic [SETLEN-1:0]   CacheSetData,    // Cache address, the output of the address select mux, NextAdr, PAdr, or FlushAdr
  input  logic [SETLEN-1:0]   CacheSetTag,     // Cache address, the output of the address select mux, NextAdr, PAdr, or FlushAdr
  input  logic [SETLEN-1:0]   PAdr,            // Physical address 
  input  logic                LRUWriteEn,      // Update the LRU state (LFSR)
  input  logic                SetValid,        // Set the dirty bit in the selected way and set
  input  logic                ClearValid,      // Clear the dirty bit in the selected way and set
  input  logic                InvalidateCache, // Clear all valid bits
  output logic [NUMWAYS-1:0]  VictimWay        // LRU (LFSR) selects a victim to evict
);

  localparam                           LOGNUMWAYS = $clog2(NUMWAYS);
  localparam			       RAND_REGS = LOGNUMWAYS + 2;  // number of bits in random generator + 2 (jordan)

  logic [LOGNUMWAYS-1:0]               HitWayEncoded, Way;
  logic [NUMWAYS-2:0]                  WayExpanded;
  logic                                AllValid;
  
  genvar                               row;

  /* verilator lint_off UNOPTFLAT */
  // Rose: For some reason verilator does not like this.  I checked and it is not a circular path.
  /* verilator lint_on UNOPTFLAT */

  logic [NUMWAYS-1:0] FirstZero;
  logic [LOGNUMWAYS-1:0] FirstZeroWay;
  logic [LOGNUMWAYS-1:0] VictimWayEnc;

  binencoder #(NUMWAYS) hitwayencoder(HitWay, HitWayEncoded);

  assign AllValid = &ValidWay;

  ///// Update replacement bits.
  // coverage off
  // Excluded from coverage b/c it is untestable without varying NUMWAYS.
  function integer log2 (integer value);
    int val;
    val = value;
    for (log2 = 0; val > 0; log2 = log2+1)
      val = val >> 1;
    return log2;
  endfunction // log2
  // coverage on

  // On a miss we need to ignore HitWay and derive the new replacement bits with the VictimWay.
  mux2 #(LOGNUMWAYS) WayMuxEnc(HitWayEncoded, VictimWayEnc, SetValid, Way);

  // bit duplication
  // expand HitWay as HitWay[3], {{2}{HitWay[2]}}, {{4}{HitWay[1]}, {{8{HitWay[0]}}, ...
  for(row = 0; row < LOGNUMWAYS; row++) begin
    localparam integer DuplicationFactor = 2**(LOGNUMWAYS-row-1);
    localparam StartIndex = NUMWAYS-2 - DuplicationFactor + 1;
    localparam EndIndex = NUMWAYS-2 - 2 * DuplicationFactor + 2;
    assign WayExpanded[StartIndex : EndIndex] = {{DuplicationFactor}{Way[row]}};
  end


  // next bit in random sequence, CurrentRandom registers(log(N-WAYS) + 2) - jordan
  logic next;  
  logic [RAND_REGS-1:0] CurrRandom;  // create register
  flopenl #(RAND_REGS) lsrf(.clk(clk), .load(reset), .en(LRUWriteEn), .val({RAND_REGS{1'd1}}), .d({next, CurrRandom[RAND_REGS-1:1]}), .q(CurrRandom));
  assign next = CurrRandom[RAND_REGS-1] ^ CurrRandom[0]; // get next current lower bit by XOR(LSB, MSB) - jordan

  
  priorityonehot #(NUMWAYS) FirstZeroEncoder(~ValidWay, FirstZero);
  binencoder #(NUMWAYS) FirstZeroWayEncoder(FirstZero, FirstZeroWay);
  // splice lower LOGNUMWAYS of CurrRandom into VictimWayEnc -jordan
  mux2 #(LOGNUMWAYS) VictimMux(FirstZeroWay, {CurrRandom[LOGNUMWAYS-1:0]}, AllValid, VictimWayEnc);
  // decode log(N-Ways) to decimal
  decoder #(LOGNUMWAYS) decoder (VictimWayEnc, VictimWay);

  // commented everything out dont think anything needs to happen here - jordan
  // note: Verilator lint doesn't like <= for array initialization (https://verilator.org/warn/BLKLOOPINIT?v=5.021)
  // Move to = to keep Verilator happy and simulator running fast
  //always_ff @(posedge clk) begin
    // if any resets occur. Set 3rd bit of current random to 1 to ensure the random generator continues
    //if (reset | (InvalidateCache & ~FlushStage) | CacheEn) CurrRandom[2] = 1'b1;
    //else if(CacheEn) CurrRandom[2] = 1'b1;
  //end

endmodule


