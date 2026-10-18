// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// The BIOS board's Z80 from reset, logged access by access in the boot-trace format
// (scripts/compare_boot_trace.py). ROMs from scripts/bios_hex.py, loaded through the
// board's load port. vblank follows MAME's screen: an edge at the end of every 60.000 Hz
// frame (below). A second log, <set>_m1.trace, holds each opcode fetch with its T-state,
// for scripts/compare_cycles.py.
//
//   scripts/run_sim.sh bios_boot_tb +SET=pc_smb +N=400000
//
// Inputs are MAME's defaults: BIOS port 0, SW1 0x40, SW2 0x3F. There is no NES: INT
// DETECT (the PPU's NMI) is set before each port-0 read at which MAME read it set, from
// debug/<set>-roms/intdet.txt (scripts/intdet_replay.py).
`timescale 1ns/1ps
module tb_bios_boot;

localparam real CLK_HZ  = 21477272.727;

reg clk = 1'b0;
always #(1.0e9 / CLK_HZ / 2.0) clk = ~clk;

reg         reset = 1'b1;
reg         ld_we = 1'b0;
reg  [15:0] ld_addr = 16'd0;
reg  [ 7:0] ld_data = 8'd0;
reg         vblank = 1'b0;
reg         intdet_set = 1'b0;
reg         intdet [0:1048575];
integer     intdet_i = 0;

wire        cen, mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n;
wire [15:0] a;
wire [ 7:0] di, dout;

pc10_bios dut (
    .clk(clk), .reset(reset), .pause(1'b0), .single(1'b0),
    .cart_ld_we(1'b0), .cart_ld_slot(4'd0), .cart_ld_addr(14'd0),
    .ld_we(ld_we), .ld_addr(ld_addr), .ld_data(ld_data),
    .vblank(vblank), .int_detect_set(intdet_set),
    .bios_in(8'h00), .sw1(8'h40), .sw2(8'h3F),
    .sdcs(), .cntrl_mask(), .disp_mask(), .sound_mute(), .game_reset(), .game_stop(),
    .ppu_reset(), .cart_sel(), .time_digit_we(), .time_data(),
    .vram_raddr(11'd0), .vram_rdata(),
    .z_cen(cen), .z_a(a), .z_di(di), .z_do(dout),
    .z_mreq_n(mreq_n), .z_iorq_n(iorq_n), .z_rd_n(rd_n), .z_wr_n(wr_n),
    .z_m1_n(m1_n), .z_rfsh_n(rfsh_n),
    .z80_running()
);

longint tstate = 0;

// ---------------------------------------------------------------- vblank from T-states
// MAME's screens have no vblank time, so vblank_irq fires at each frame's end
// (MAME_KLUDGES), every 200,000 / 3 Z80 T-states, and MAME's Z80 takes the NMI at the
// first instruction boundary at or after one cycle before the frame's end. Measured from
// MAME's debugger trace (totalcycles) on pc_smb: frames 160, 162, 170 and 174 end at
// .67, .00, .33 and .00; their NMIs are taken +7.3, 0, -0.3 and -1 cycles from the end.
// Counted in the Z80's own T-states (tstate; T80's first M1 is tstate 1 where MAME's
// first instruction is cycle 0) and raised on the clock after 3 tstate + 3 >= 200,000 k,
// the edge reaches T80 three clocks later, before the next clock enable. Held one line.
real t0;
longint phase;
always @(posedge clk) begin
    phase = (3 * tstate + 3) % 200000;
    vblank <= !reset && tstate >= 66667 && phase < 763;
end

// ---------------------------------------------------------------- trace
// <set>_m1.trace: each opcode fetch as "T-state address opcode", T-states counted from
// reset, for scripts/compare_cycles.py against MAME's debugger trace with totalcycles.
integer f, fm1, n = 0, nmax, frames = 0;
longint m1_t;
reg     m1_d = 1'b1;
// T80's NMI acknowledge M1 reads the opcode at PC and discards it; MAME's Z80 makes no
// such access, so it is left out of both logs.
reg     nmicyc = 1'b0;
initial $init_signal_spy("/tb_bios_boot/dut/u_z80/u0/NMICycle", "/tb_bios_boot/nmicyc");
reg     rd_d = 1'b1, wr_d = 1'b1, vb_d = 1'b0;
reg [15:0] a_d;
reg [ 7:0] di_d;
reg        io_d, intack_d;

always @(posedge clk) if (!reset) begin
    // the first clock of an IN from port 0
    intdet_set <= 1'b0;
    if (!iorq_n && !rd_n && m1_n && a[7:0] == 8'h00 && !(io_d && !rd_d)) begin
        intdet_set <= intdet[intdet_i] === 1'b1;
        intdet_i = intdet_i + 1;
    end
    if (cen) tstate <= tstate + 1;
    m1_d <= m1_n;
    if (m1_d && !m1_n && iorq_n) m1_t = tstate;
    if (!rd_d && rd_n && !m1_d && !io_d && !nmicyc) $fdisplay(fm1, "%0d %04X %02X", m1_t, a_d, di_d);
    rd_d <= rd_n; wr_d <= wr_n; a_d <= a; di_d <= di;
    io_d <= !iorq_n; intack_d <= !iorq_n && !m1_n;
    vb_d <= vblank;
    if (vblank && !vb_d) frames = frames + 1;
    // a read is logged as it ends, with the data the CPU took
    if (!rd_d && rd_n && !intack_d && !(nmicyc && !m1_d)) begin
        n = n + 1;
        if (io_d) $fdisplay(f, "%0d\tir\t%04X\tFF\t%02X", n, a_d[7:0], di_d);
        else      $fdisplay(f, "%0d\tr\t%04X\tFF\t%02X", n, a_d, di_d);
    end
    if (wr_d && !wr_n) begin
        n = n + 1;
        if (!iorq_n) $fdisplay(f, "%0d\tiw\t%04X\tFF\t%02X", n, a[7:0], dout);
        else         $fdisplay(f, "%0d\tw\t%04X\tFF\t%02X", n, a, dout);
    end
    if (n >= nmax) begin
        $fdisplay(f, "# %0d accesses logged, %0d vblanks", n, frames);
        $fclose(f); $fclose(fm1);
        $display("TRACE %0d accesses, %0d vblanks, t = %0.3f ms", n, frames, ($realtime - t0) * 1.0e-6);
        $finish;
    end
end

// ---------------------------------------------------------------- load and run
reg [7:0] img_bios [0:16383];
reg [7:0] img_inst [0:8191];
reg [7:0] img_prom [0:15];
string set;
integer i;
initial begin
    if (!$value$plusargs("SET=%s", set)) set = "pc_smb";
    if (!$value$plusargs("N=%d", nmax)) nmax = 20000;
    $readmemh({"debug/", set, "-roms/bios.hex"}, img_bios);
    $readmemh({"debug/", set, "-roms/inst.hex"}, img_inst);
    $readmemh({"debug/", set, "-roms/prom.hex"}, img_prom);
    $readmemb({"debug/", set, "-roms/intdet.txt"}, intdet);
    f = $fopen({"debug/", set, "-boot/", set, "_rtl.trace"}, "w");
    fm1 = $fopen({"debug/", set, "-boot/", set, "_m1.trace"}, "w");
    $fdisplay(f, "# RTL Z80 bus accesses from reset (sim/bios_boot_tb)");
    repeat (4) @(posedge clk);
    for (i = 0; i < 16384; i = i + 1) begin
        @(posedge clk); ld_we <= 1'b1; ld_addr <= i[15:0]; ld_data <= img_bios[i];
    end
    for (i = 0; i < 8192; i = i + 1) begin
        @(posedge clk); ld_we <= 1'b1; ld_addr <= 16'h4000 + i[15:0]; ld_data <= img_inst[i];
    end
    for (i = 0; i < 16; i = i + 1) begin
        @(posedge clk); ld_we <= 1'b1; ld_addr <= 16'h6000 + i[15:0]; ld_data <= img_prom[i];
    end
    @(posedge clk); ld_we <= 1'b0;
    repeat (8) @(posedge clk);
    t0 = $realtime;
    reset <= 1'b0;
end

endmodule
