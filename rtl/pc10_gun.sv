// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// The PlayChoice-10 gun (MAME init_pc_gun): GUNX 0-255 and GUNY 0-239 in the PPU's pixels,
// read through port 2 as bit 3 (no light) and bit 4 (trigger) (pc10_in1_r, 856-876).
//
// The aim is a held position, moved as Arcade-KonamiGX_MiSTer's gx_guns moves le2's:
//   the mouse        relatively; its left button is the trigger
//   the left stick   absolutely, past a dead zone of 8 (Sinden and GUN4IR guns present it)
//   the d-pad        two pixels a frame while held
// Stick mode: Auto (pushed to 96 or more an axis moves as the d-pad, for arcade sticks on
// gamepad encoders; below that, absolute), Aim (always absolute) or D-pad (any deflection
// steps). The joystick's trigger is A.
//
// The light sensor and the trigger's timing are NES_MiSTer's zapper.sv (Kitrinx): light when
// the 9 x 9 pixels round the aim show a bright colour, held for some lines; the trigger's
// switch closes for ~39 ms, then ~98 ms before it can close again.
//
// The crosshair marks the aim on the game picture (video.sv's reticle input), so it reaches
// both outputs; it is drawn from the PPU's colour index, never seen by the sensor. Held in
// reset (no gun set in the running channel) there is none.
module pc10_gun (
    input             clk,
    input             reset,       // the aim to the centre
    input      [11:0] joy,         // joystick_0: right, left, down, up, A from bit 0
    input      [15:0] ana,         // joystick_l_analog_0: { Y, X }, signed
    input      [24:0] mouse,       // hps_io's ps2_mouse: bit 24 toggles a packet, Y positive up
    input       [1:0] mode,        // the stick: 0 Auto, 1 Aim, 2 D-pad
    input             show,        // the crosshair
    input       [8:0] cycle,       // the PPU's dot and line
    input       [8:0] scanline,
    input       [5:0] color,       // the PPU's colour index at that dot
    output            light,       // port 2 bit 3: 1 = no light
    output            trigger,     // port 2 bit 4
    output reg  [1:0] reticle      // video.sv: [0] draw the crosshair, [1] its second colour
);

reg [11:0] j;
reg [15:0] a;
reg [24:0] ms;
reg        ms_t = 1'b0;
reg  [8:0] line_d = 9'd0;
always @(posedge clk) begin
    j <= joy; a <= ana; ms <= mouse; ms_t <= ms[24]; line_d <= scanline;
end
wire ms_ev = ms[24] ^ ms_t;
wire frame = scanline == 9'd240 && line_d != 9'd240;
wire new_line = scanline != line_d;

localparam [7:0] DEAD = 8'd8;
localparam [7:0] FULL = 8'd96;

function [7:0] mag(input [7:0] v);                   // of a signed byte
    mag = v[7] ? 8'd0 - v : v;
endfunction
// v + d, held to 0..max
function [7:0] step(input [7:0] v, input signed [9:0] d, input [7:0] max);
    reg signed [10:0] t;
    begin
        t = $signed({ 3'b000, v }) + { d[9], d };
        step = t < 11'sd0 ? 8'd0 : t > $signed({ 3'b000, max }) ? max : t[7:0];
    end
endfunction

wire [7:0] ax = a[7:0], ay = a[15:8];
wire       lx = mag(ax) >= DEAD, ly = mag(ay) >= DEAD;
wire       sx = mode == 2'd2 ? lx : mode == 2'd1 ? 1'b0 : mag(ax) >= FULL;
wire       sy = mode == 2'd2 ? ly : mode == 2'd1 ? 1'b0 : mag(ay) >= FULL;
wire [3:0] dir = { j[3] | (ay[7] & sy), j[2] | (!ay[7] & sy),
                   j[1] | (ax[7] & sx), j[0] | (!ax[7] & sx) };      // up, down, left, right
wire [7:0] ay_u = ay ^ 8'h80;
wire [7:0] ay_l = ay_u - { 4'd0, ay_u[7:4] };                         // 0-255 to 0-239

reg [7:0] px = 8'd128, py = 8'd120;
always @(posedge clk) begin
    if (reset) begin
        px <= 8'd128; py <= 8'd120;
    end else if (ms_ev) begin
        px <= step(px, $signed({ {2{ms[4]}}, ms[15:8] }), 8'd255);
        py <= step(py, -$signed({ {2{ms[5]}}, ms[23:16] }), 8'd239);
    end else begin
        if (dir[1:0] != 2'b00) begin
            if (frame) px <= step(px, dir[0] ? 10'sd2 : -10'sd2, 8'd255);
        end else if (lx) px <= ax ^ 8'h80;
        if (dir[3:2] != 2'b00) begin
            if (frame) py <= step(py, dir[2] ? 10'sd2 : -10'sd2, 8'd239);
        end else if (ly) py <= ay_l;
    end
end

// ---------------------------------------------------------- trigger (zapper.sv)
reg [21:0] trig_cnt = 22'd0;
reg        pressed = 1'b0;
wire       trig_btn = j[4] | ms[0];
assign trigger = trig_cnt > 22'd2_100_000;
always @(posedge clk) begin
    if (reset) begin
        trig_cnt <= 22'd0; pressed <= 1'b0;
    end else begin
        if (trig_cnt != 22'd0) trig_cnt <= trig_cnt - 22'd1;
        if (trig_cnt == 22'd0 && trig_btn && !pressed) begin
            trig_cnt <= 22'd2_930_000;
            pressed  <= 1'b1;
        end
        if (!trig_btn) pressed <= 1'b0;
    end
end

// ---------------------------------------------------------- light (zapper.sv)
wire [9:0] x = { 2'b00, px }, y = { 2'b00, py };
wire [9:0] c = { 1'b0, cycle }, l = { 1'b0, scanline };
wire offscreen = px >= 8'd254 || px <= 8'd1 || py >= 8'd224 || py <= 8'd8;
wire near = x + 10'd4 >= c && x <= c + 10'd4 && y + 10'd4 >= l && y <= l + 10'd4;
reg [4:0] light_cnt = 5'd0;
assign light = light_cnt == 5'd0;
always @(posedge clk) begin
    if (reset) light_cnt <= 5'd0;
    else begin
        if (new_line && light_cnt != 5'd0) light_cnt <= light_cnt - 5'd1;
        if (near && !offscreen) begin
            if (color == 6'h20 || color == 6'h30)
                light_cnt <= 5'd26;
            else if ((color[5:4] == 2'd3 && color < 6'h3E) || color == 6'h10) begin
                if (light_cnt < 5'd20) light_cnt <= 5'd20;
            end else if ((color[5:4] == 2'd2 && color < 6'h2E) || color == 6'h00) begin
                if (light_cnt < 5'd17) light_cnt <= 5'd17;
            end
        end
    end
end

// ---------------------------------------------------------- crosshair
// arms 2 to 6 pixels from the aim, as gx_guns
wire [9:0] dx = c >= x ? c - x : x - c;
wire [9:0] dy = l >= y ? l - y : y - l;
wire       arm = (dx == 10'd0 && dy >= 10'd2 && dy <= 10'd6) || (dy == 10'd0 && dx >= 10'd2 && dx <= 10'd6);
always @(posedge clk) reticle <= { offscreen, show && arm && !reset };

endmodule
