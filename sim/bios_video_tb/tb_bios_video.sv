// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// pc10_bios_video against scripts/bios_model.py: one capture's VRAM, the BIOS
// characters and PROMs (written by the model into the capture directory), a 341 x 262
// raster with ce_pix 1 in 4 as the PPU's. The second frame's 256 x 240 pixels go to
// <capture>/bios_rtl.hex as RRGGBB, compared by scripts/bios_model.py --rtl.
//
//   scripts/run_sim.sh bios_video_tb +CAP=debug/pc_smb-600
`timescale 1ns/1ps
module tb_bios_video;

reg clk = 1'b0;
always #23.28 clk = ~clk;

reg  [1:0] div = 2'd0;
wire       ce_pix = div == 2'd3;
reg  [8:0] hcnt = 9'd0, vcnt = 9'd0;
always @(posedge clk) begin
    div <= div + 2'd1;
    if (ce_pix) begin
        hcnt <= hcnt == 9'd340 ? 9'd0 : hcnt + 9'd1;
        if (hcnt == 9'd340) vcnt <= vcnt == 9'd261 ? 9'd0 : vcnt + 9'd1;
    end
end

reg         ld_we = 1'b0;
reg  [14:0] ld_addr;
reg  [ 7:0] ld_data;
wire [10:0] vram_addr;
reg  [ 7:0] vram_q;
reg  [ 7:0] vram [0:2047];
always @(posedge clk) vram_q <= vram[vram_addr];
wire [7:0] r, g, b;

pc10_bios_video dut (
    .clk(clk), .ce_pix(ce_pix), .hcnt(hcnt), .vcnt(vcnt), .sdcs(1'b0),
    .vram_addr(vram_addr), .vram_data(vram_q),
    .ld_we(ld_we), .ld_addr(ld_addr), .ld_data(ld_data),
    .r(r), .g(g), .b(b)
);

reg [7:0] img_gfx  [0:24575];
reg [7:0] img_prom [0:767];
string cap;
integer i, f, frame = 0, n = 0;

// r, g, b take column h's colour on the ce_pix where hcnt is h: sample one clock later
reg       ce_d = 1'b0;
reg [8:0] h_d, v_d;
always @(posedge clk) begin
    ce_d <= ce_pix; h_d <= hcnt; v_d <= vcnt;
    if (ce_pix && hcnt == 9'd340 && vcnt == 9'd261) frame = frame + 1;
    if (ce_d && frame == 2 && h_d < 9'd256 && v_d < 9'd240) begin
        $fdisplay(f, "%02x%02x%02x", r, g, b);
        n = n + 1;
    end
    if (frame == 3) begin
        $fclose(f);
        $display("BIOS VIDEO %0d pixels -> %s/bios_rtl.hex", n, cap);
        $finish;
    end
end

initial begin
    if (!$value$plusargs("CAP=%s", cap)) cap = "debug/pc_smb-600";
    $readmemh({cap, "/bios_gfx.hex"}, img_gfx);
    $readmemh({cap, "/bios_prom.hex"}, img_prom);
    $readmemh({cap, "/vram.hex"}, vram);
    f = $fopen({cap, "/bios_rtl.hex"}, "w");
    for (i = 0; i < 24576; i = i + 1) begin
        @(posedge clk); ld_we <= 1'b1; ld_addr <= i[14:0]; ld_data <= img_gfx[i];
    end
    for (i = 0; i < 768; i = i + 1) begin
        @(posedge clk); ld_we <= 1'b1; ld_addr <= 15'h6000 + i[14:0]; ld_data <= img_prom[i];
    end
    @(posedge clk); ld_we <= 1'b0;
end

endmodule
