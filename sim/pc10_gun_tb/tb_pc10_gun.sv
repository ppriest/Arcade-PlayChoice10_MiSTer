// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// pc10_gun: each aim source, the clamps, the light sensor on a white box (MAME's
// detect_light reads the pixel under GUNX, GUNY), the trigger's timing and the crosshair.
// The raster is the PPU's, 341 x 262, a dot every 4 clocks.
//
//   scripts/run_sim.sh pc10_gun_tb
`timescale 1ns/1ps
module tb_pc10_gun;

reg clk = 1'b0;
always #23.28 clk = ~clk;

reg  [1:0] div = 2'd0;
reg  [8:0] cycle = 9'd0, scanline = 9'd0;
always @(posedge clk) begin
    div <= div + 2'd1;
    if (div == 2'd3) begin
        cycle <= cycle == 9'd340 ? 9'd0 : cycle + 9'd1;
        if (cycle == 9'd340) scanline <= scanline == 9'd261 ? 9'd0 : scanline + 9'd1;
    end
end

// a white box (colour 0x30) at x 100-131, y 80-111 on black (0x0F)
wire       in_box = cycle >= 100 && cycle < 132 && scanline >= 80 && scanline < 112;
wire [5:0] color = in_box ? 6'h30 : 6'h0F;

reg         reset = 1'b1;
reg  [11:0] joy = 12'd0;
reg  [15:0] ana = 16'd0;
reg  [24:0] mouse = 25'd0;
reg   [1:0] mode = 2'd0;
wire        light, trigger;
wire  [1:0] reticle;

pc10_gun dut (
    .clk(clk), .reset(reset), .joy(joy), .ana(ana), .mouse(mouse), .mode(mode),
    .show(1'b1), .cycle(cycle), .scanline(scanline), .color(color),
    .light(light), .trigger(trigger), .reticle(reticle)
);

integer errors = 0;
task check(input string what, input integer got, input integer want);
    if (got !== want) begin
        $display("  FAIL %s: got %0d want %0d", what, got, want);
        errors++;
    end else $display("  ok   %s: %0d", what, got);
endtask

task frames(input integer n);
    repeat (n) @(posedge clk iff (scanline == 9'd241 && cycle == 9'd0 && div == 2'd0));
endtask

task mouse_move(input integer dx, input integer dy, input bit left);
    begin
        @(posedge clk);
        mouse[15:8]  = dx[7:0]; mouse[4] = dx < 0;
        mouse[23:16] = dy[7:0]; mouse[5] = dy < 0;
        mouse[0] = left;
        mouse[24] = ~mouse[24];
        repeat (4) @(posedge clk);
    end
endtask

// light seen at any point in a frame
task automatic light_in_frame(output bit seen);
    seen = 0;
    frames(1);
    repeat (341 * 262 * 4) begin
        @(posedge clk);
        if (!light) seen = 1;
    end
endtask

// the crosshair's dots in one frame: count, and the centre of the horizontal arm's row
task automatic cross_in_frame(output integer n, output integer row);
    n = 0; row = -1;
    frames(1);
    repeat (341 * 262 * 4) begin
        @(posedge clk);
        if (div == 2'd1 && reticle[0]) begin
            n++;
            if (n == 1) row = scanline;
        end
    end
endtask

bit seen;
integer n, row;

initial begin
    repeat (8) @(posedge clk);
    reset = 1'b0;
    repeat (4) @(posedge clk);
    check("reset X", dut.px, 128);
    check("reset Y", dut.py, 120);

    $display("stick, absolute (Aim)");
    mode = 2'd1;
    ana = { 8'sd60, -8'sd28 };              // Y +60, X -28
    repeat (4) @(posedge clk);
    check("stick X", dut.px, 100);          // -28 ^ 0x80
    check("stick Y", dut.py, 188 - (188 >> 4));
    ana = { 8'sd4, 8'sd3 };                 // in the dead zone: held
    repeat (4) @(posedge clk);
    check("dead zone X held", dut.px, 100);

    $display("stick, Auto: full deflection steps 2 a frame");
    mode = 2'd0;
    ana = { 8'sd0, 8'sd120 };
    frames(1); repeat (4) @(posedge clk);
    n = dut.px;
    frames(3); repeat (4) @(posedge clk);
    check("Auto X after 3 frames", dut.px - n, 6);
    ana = 16'd0;

    $display("d-pad: 2 a frame, clamped");
    joy = 12'b0100;                         // down
    frames(80); repeat (4) @(posedge clk);
    check("d-pad Y clamped", dut.py, 239);
    joy = 12'd0;

    $display("mouse: deltas, Y positive up, clamped");
    mouse_move(-100, 0, 0);
    mouse_move(-100, 0, 0);
    check("mouse X clamped", dut.px, 0);
    mouse_move(110, 50, 0);
    check("mouse X", dut.px, 110);
    check("mouse Y", dut.py, 189);

    $display("light: in the box, not outside it");
    mouse_move(0, 189 - 95, 0);             // Y 95, inside the box
    check("aim Y", dut.py, 95);
    light_in_frame(seen);
    check("light on the box", seen, 1);
    mouse_move(80, 0, 0);                   // X 190
    light_in_frame(seen);
    check("no light off the box", seen, 0);

    $display("crosshair: 20 dots, 5 an arm, the arm on the aim's row");
    cross_in_frame(n, row);
    check("crosshair dots", n, 20);
    check("crosshair top", row, 95 - 6);

    $display("no gun set (held in reset): no crosshair");
    reset = 1'b1;
    cross_in_frame(n, row);
    check("crosshair dots in reset", n, 0);
    reset = 1'b0;
    mouse_move(110 - 128, 120 - 95, 0);     // back to X 110, Y 95

    $display("trigger: closes ~39 ms, then ~98 ms locked");
    mouse_move(0, 0, 1);
    check("trigger closed", trigger, 1);
    mouse_move(0, 0, 0);
    repeat (830_000) @(posedge clk);
    check("trigger open after 830,000 clocks", trigger, 0);
    mouse_move(0, 0, 1);
    check("locked out", trigger, 0);
    mouse_move(0, 0, 0);
    repeat (2_100_000) @(posedge clk);
    mouse_move(0, 0, 1);
    check("closes again", trigger, 1);
    joy[4] = 1'b1;                          // A is the joystick's trigger too
    mouse_move(0, 0, 0);

    $display("PC10_GUN %s: %0d errors", errors ? "FAIL" : "PASS", errors);
    $finish;
end

endmodule
