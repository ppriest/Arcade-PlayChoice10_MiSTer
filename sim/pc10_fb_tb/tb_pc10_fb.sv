// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// pc10_fb in each layout: a 341 x 262 raster with 256 x 224 active (the core's Overscan
// Normal), each pixel's colour encoding which monitor and its x and y. The DDR3 writes
// land in a memory model; every position of the buffer written in the third frame is
// checked against the layout (pc10_fb's header), and every pixel must be written.
//
//   scripts/run_sim.sh pc10_fb_tb
`timescale 1ns/1ps
module tb_pc10_fb;

localparam W = 256, H = 224;

reg clk = 1'b0;
always #23.28 clk = ~clk;

reg  [1:0] div = 2'd0;
wire       ce_pix = div == 2'd3;
reg  [8:0] h = 9'd0, v = 9'd0;
always @(posedge clk) begin
    div <= div + 2'd1;
    if (ce_pix) begin
        h <= h == 9'd340 ? 9'd0 : h + 9'd1;
        if (h == 9'd340) v <= v == 9'd261 ? 9'd0 : v + 9'd1;
    end
end
wire de = h < W && v >= 8 && v < 8 + H;
wire vs = v >= 244 && v < 247;
wire [11:0] px = h, py = v - 9'd8;
// colour: R = monitor (0x11 menu, 0x22 game), G = x, B = y
wire [23:0] menu_rgb = { 8'h11, px[7:0], py[7:0] };
wire [23:0] game_rgb = { 8'h22, px[7:0], py[7:0] };

reg  [2:0] mode = 3'd1;
reg        vbl = 1'b0;
wire       fb_en;
wire [11:0] fbw, fbh;
wire [31:0] fbbase;
wire [13:0] stride;
wire [28:0] daddr;
wire [63:0] ddin;
wire [7:0]  dbe;
wire        dwe;

pc10_fb dut (
    .clk(clk), .ce_pix(ce_pix), .de(de), .vs(vs),
    .menu_rgb(menu_rgb), .game_rgb(game_rgb), .mode_in(mode),
    .FB_EN(fb_en), .FB_FORMAT(), .FB_WIDTH(fbw), .FB_HEIGHT(fbh), .FB_BASE(fbbase),
    .FB_STRIDE(stride), .FB_VBL(vbl),
    .DDRAM_BURSTCNT(), .DDRAM_ADDR(daddr), .DDRAM_DIN(ddin), .DDRAM_BE(dbe), .DDRAM_WE(dwe)
);

// the memory: 32-bit pixels by byte address within an 8 MB buffer, per buffer index
reg [31:0] mem [int];
always @(posedge clk) if (dwe) begin
    int a;
    a = { daddr[21:20], daddr[19:0], 3'b000 } | (dbe == 8'hF0 ? 4 : 0);
    mem[a] = dbe == 8'hF0 ? ddin[63:32] : ddin[31:0];
end

integer errors = 0, checked = 0, frame = 0;
reg [1:0] buf_w;

task check_mode(input [2:0] m, input string name);
    int sx, sy, col, row, a, bad, n;
    reg [31:0] got, want;
    int mw, mh;
    begin
        mode = m;
        mem.delete();
        // let the size and buffers settle, then take the buffer written in one whole frame
        repeat (3) @(posedge vs);
        @(negedge vs);              // past the swap at this vsync
        mem.delete();
        buf_w = dut.i_fb;           // the buffer this frame is written to
        @(posedge vs);
        bad = 0; n = 0;
        mw = W; mh = H;
        for (int mon = 0; mon < 2; mon++)
            for (int y = 0; y < mh; y++)
                for (int x = 0; x < mw; x++) begin
                    // stacked-picture position, then the layout's
                    sx = x; sy = y + (mon ? H : 0);
                    case (m)
                        3'd1: begin col = sx; row = sy; end
                        3'd2: begin col = x + (mon ? W : 0); row = y; end
                        3'd3: begin col = 2 * H - 1 - sy; row = sx; end
                        default: begin col = sy; row = W - 1 - sx; end
                    endcase
                    a = { buf_w, 23'd0 } + row * stride + col * 4;
                    want = { 8'd0, y[7:0], x[7:0], mon ? 8'h22 : 8'h11 };
                    got = mem.exists(a) ? mem[a] : 32'hDEADBEEF;
                    n++;
                    if (got !== want) begin
                        if (bad < 4) $display("  %s: monitor %0d (%0d,%0d) at col %0d row %0d: got %08x want %08x",
                                              name, mon, x, y, col, row, got, want);
                        bad++;
                    end
                end
        $display("%-12s FB %0d x %0d, stride %0d: %0d of %0d pixels right", name, fbw, fbh, stride, n - bad, n);
        errors += bad; checked += n;
    end
endtask

initial begin
    repeat (2) @(posedge vs);
    check_mode(3'd1, "Stacked");
    check_mode(3'd2, "Side");
    check_mode(3'd3, "Rotated CW");
    check_mode(3'd4, "Rotated CCW");
    $display("PC10_FB %s: %0d errors in %0d pixels", errors ? "FAIL" : "PASS", errors, checked);
    $finish;
end

endmodule
