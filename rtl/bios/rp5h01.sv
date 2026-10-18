// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// Ricoh RP5H01: 64-bit PROM read through a 6/7-bit counter. Transcribed from MAME
// src/devices/machine/rp5h01.cpp; MAME's machine_reset leaves it enabled with the
// counter at 0 and old_reset high (playch10.cpp 683-686), which is the reset state here.
// The pins are levels; each write from the Z80 is one update of all three.
module rp5h01 (
    input            clk,
    input            reset,
    input            we,          // pins below are new this clock
    input            test,        // 1: 7-bit counter mode
    input            dclk,        // DATA CLOCK: counts on 1 -> 0
    input            rst_pin,     // RESET: clears the counter on 0 -> 1
    output           counter_out, // A5
    output           data_out,
    // the 16-byte PROM, loaded with the cart
    input            ld_we,
    input      [3:0] ld_addr,
    input      [7:0] ld_data
);

reg [7:0] prom [0:15];
always @(posedge clk) if (ld_we) prom[ld_addr] <= ld_data;

reg [6:0] counter;
reg       mode7, old_reset, old_clock;

always @(posedge clk) begin
    if (reset) begin
        counter   <= 7'd0;
        mode7     <= 1'b0;
        old_reset <= 1'b1;
        old_clock <= 1'b0;
    end else if (we) begin
        // MAME's order: test, clock, reset (pc10_prot_w)
        mode7 <= test;
        if (!old_reset && rst_pin)      counter <= 7'd0;
        else if (old_clock && !dclk)    counter <= counter + 7'd1;
        old_clock <= dclk;
        old_reset <= rst_pin;
    end
end

wire [6:0] a = mode7 ? counter : { 1'b0, counter[5:0] };
wire [7:0] byte_q = prom[a[6:3]];
assign counter_out = counter[5];
assign data_out    = byte_q[~a[2:0]];

endmodule
