// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// The BIOS display, the top monitor: 32 x 30 characters of 8 x 8, 3 bpp, from the Z80's
// VRAM (two bytes a character: code low, then code bits 10:8 in 2:0 and colour in 7:3),
// colour through three 4-bit PROMs. playch10.cpp get_bg_tile_info (546-554),
// bios_charlayout (1871-1880), playch10_palette (521-538). Checked against
// scripts/bios_model.py, which is checked against MAME (sim/bios_video_tb).
//
// Driven by the PPU's raster (hcnt 0-340, vcnt 0-261, ce_pix 1 in 4; the counters advance
// on ce_pix). Each character is fetched during the 8 dots before it, the first of a line
// in the last 8 dots of the line before. r, g, b take column h's colour on the ce_pix
// where hcnt is h.
module pc10_bios_video (
    input             clk,
    input             ce_pix,
    input      [ 8:0] hcnt,
    input      [ 8:0] vcnt,
    input             sdcs,        // the Z80 owns VRAM: pen 0 everywhere (MAME's fill)

    output reg [10:0] vram_addr,
    input      [ 7:0] vram_data,   // one clock after vram_addr

    // 0000-5FFF the character planes (8K, 8M, 8P); 6000-62FF the PROMs (6F R, 6E G, 6D B)
    input             ld_we,
    input      [14:0] ld_addr,
    input      [ 7:0] ld_data,

    output reg [ 7:0] r,
    output reg [ 7:0] g,
    output reg [ 7:0] b
);

reg [7:0] gfx  [0:24575];
reg [3:0] prom [0:767];            // stored inverted, as MAME's ROMREGION_INVERT
always @(posedge clk) if (ld_we && ld_addr < 15'h6000) gfx[ld_addr] <= ld_data;
always @(posedge clk) if (ld_we && ld_addr[14:10] == 5'b11000) prom[ld_addr[9:0]] <= ~ld_data[3:0];

// ---------------------------------------------------------------- fetch
// fx: the column being fetched for, 8 ahead of hcnt, wrapping at the 341-dot line;
// fy: its line.
wire       wrap = hcnt >= 9'd333;
wire [8:0] fx   = wrap ? hcnt - 9'd333 : hcnt + 9'd8;
wire [8:0] fy   = !wrap ? vcnt : vcnt == 9'd261 ? 9'd0 : vcnt + 9'd1;
wire [4:0] col  = fx[7:3];
wire [4:0] row  = fy[7:3];
reg  [2:0] fline;

reg  [3:0] st = 4'd0;
reg  [7:0] code_lo, attr;
reg  [7:0] p0, p1, p2;
reg [14:0] gaddr;
reg  [7:0] gq;
always @(posedge clk) gq <= gfx[gaddr];

wire [10:0] chr = { attr[2:0], code_lo };
wire [12:0] gbase = { chr[9:0], fline };   // 1024 characters: bit 10 wraps, as MAME's gfx element

always @(posedge clk) begin
    case (st)
    4'd0: if (ce_pix && fx[2:0] == 3'd0) begin
              vram_addr <= { row, col, 1'b0 };
              fline <= fy[2:0];
              st <= 4'd1;
          end
    4'd1: begin vram_addr[0] <= 1'b1; st <= 4'd2; end
    4'd2: begin code_lo <= vram_data; st <= 4'd3; end
    4'd3: begin attr <= vram_data; st <= 4'd4; end
    4'd4: begin gaddr <= { 2'b00, gbase }; st <= 4'd5; end
    4'd5: begin gaddr <= { 2'b01, gbase }; st <= 4'd6; end
    4'd6: begin gaddr <= { 2'b10, gbase }; p0 <= gq; st <= 4'd7; end
    4'd7: begin p1 <= gq; st <= 4'd8; end
    4'd8: begin p2 <= gq; st <= 4'd0; end
    default: st <= 4'd0;
    endcase
end

// ---------------------------------------------------------------- shift
reg [7:0] s0, s1, s2;
reg [4:0] scol;
always @(posedge clk) if (ce_pix) begin
    if (fx[2:0] == 3'd7) begin
        s0 <= p0; s1 <= p1; s2 <= p2; scol <= attr[7:3];
    end else begin
        s0 <= { s0[6:0], 1'b0 }; s1 <= { s1[6:0], 1'b0 }; s2 <= { s2[6:0], 1'b0 };
    end
end

// ---------------------------------------------------------------- colour
function automatic [7:0] level(input [3:0] n);
    level = (n[0] ? 8'h0E : 8'h00) + (n[1] ? 8'h1F : 8'h00)
          + (n[2] ? 8'h43 : 8'h00) + (n[3] ? 8'h8F : 8'h00);
endfunction

wire [2:0] pen = { s0[7], s1[7], s2[7] };
wire [7:0] pi  = sdcs ? 8'd0 : { scol, pen };
reg  [3:0] pr, pg, pb;
always @(posedge clk) begin
    pr <= prom[{ 2'b00, pi }];
    pg <= prom[{ 2'b01, pi }];
    pb <= prom[{ 2'b10, pi }];
end
always @(posedge clk) if (ce_pix) begin
    r <= level(pr); g <= level(pg); b <= level(pb);
end

endmodule
