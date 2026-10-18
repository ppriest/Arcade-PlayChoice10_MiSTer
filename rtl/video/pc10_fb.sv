// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// The PlayChoice-10's two monitors on HDMI, through the scaler's framebuffer in DDR3
// (after Arcade-KonamiGX_MiSTer's gx_t34_fb, itself after Sorgelig's screen_rotate). The
// board draws both monitors on one raster, so each pixel arrives as a pair: the BIOS
// display's (menu, the top monitor) and the game's (the bottom one). Both are written.
//
//   mode 1, Stacked:      menu above game, as the cabinet          (W x 2H)
//   mode 2, Side by side: menu left, game right                     (2W x H)
//   mode 3, Rotated CW:   the stack turned 90 degrees clockwise     (2H x W)
//   mode 4, Rotated CCW:  the stack turned 90 degrees anticlockwise (2H x W)
//   mode 0: off (FB_EN low); the core's own output carries one monitor
//
// W and H are measured from the enables. Three buffers: one written, one shown, and at
// most one finished and waiting; the shown one moves only at the output's vblank.
// Writes are 32 bits, one pixel each, two a pixel clock, and do not wait on DDRAM_BUSY,
// as screen_rotate's do.
module pc10_fb (
    input             clk,
    input             ce_pix,
    input             de,
    input             vs,
    input      [23:0] menu_rgb,     // R, G, B
    input      [23:0] game_rgb,
    input      [ 2:0] mode_in,

    output            FB_EN,
    output     [ 4:0] FB_FORMAT,
    output reg [11:0] FB_WIDTH,
    output reg [11:0] FB_HEIGHT,
    output     [31:0] FB_BASE,
    output     [13:0] FB_STRIDE,
    input             FB_VBL,

    output     [ 7:0] DDRAM_BURSTCNT,
    output     [28:0] DDRAM_ADDR,
    output     [63:0] DDRAM_DIN,
    output     [ 7:0] DDRAM_BE,
    output            DDRAM_WE
);

localparam [6:0] MEM_BASE = 7'b0010010;     // 0x24000000, 3 x 8 MB, as screen_rotate

reg  [2:0] mode = 3'd0;
always @(posedge clk) mode <= mode_in > 3'd4 ? 3'd0 : mode_in;
wire       stack = mode == 3'd1;
wire       side  = mode == 3'd2;
wire       cw    = mode == 3'd3;
wire       ccw   = mode == 3'd4;
wire       rot   = cw | ccw;

// ---------------------------------------------------------------- picture size
reg [11:0] hsz = 12'd256, vsz = 12'd224;
reg [11:0] hcnt = 12'd0, vcnt = 12'd0;
reg  [2:0] fb_en = 3'd0;
reg        old_de = 1'b0, old_vs = 1'b0;
always @(posedge clk) if (ce_pix) begin
    old_de <= de;
    old_vs <= vs;
    hcnt <= hcnt + 12'd1;
    if (~old_de & de) begin hcnt <= 12'd1; vcnt <= vcnt + 12'd1; end
    if (old_de & ~de) hsz <= hcnt;
    if (~old_vs & vs) begin
        vsz   <= vcnt;
        vcnt  <= 12'd0;
        fb_en <= { fb_en[1:0], mode != 3'd0 };
    end
end

wire [11:0] fbw    = side ? { hsz[10:0], 1'b0 } : rot ? { vsz[10:0], 1'b0 } : hsz;
wire [11:0] fbh    = stack ? { vsz[10:0], 1'b0 } : rot ? hsz : vsz;
wire [13:0] stride = { fbw[11:2] + 10'd1, 4'd0 };   // 4 bytes a pixel, 16-byte rows

always @(posedge clk) begin
    FB_WIDTH  <= fbw;
    FB_HEIGHT <= fbh;
end

assign FB_EN     = fb_en[2] && mode != 3'd0;
assign FB_FORMAT = 5'b00110;
assign FB_STRIDE = stride;

// ---------------------------------------------------------------- buffers
reg [1:0] i_fb = 2'd0, o_fb = 2'd1, r_fb = 2'd2;
reg       ready = 1'b0;
assign FB_BASE = { MEM_BASE, o_fb, 23'd0 };

always @(posedge clk) begin
    reg old_vbl, vs_d;
    reg vbl_ev, done;
    old_vbl <= FB_VBL;
    vbl_ev = ~old_vbl & FB_VBL;
    done   = 1'b0;
    if (ce_pix) begin
        vs_d <= vs;
        done = ~vs_d & vs && FB_EN;
    end
    if (done) begin
        if (vbl_ev && ready) begin o_fb <= r_fb; r_fb <= i_fb; i_fb <= o_fb; end
        else begin r_fb <= i_fb; i_fb <= r_fb; end      // a picture still waiting is dropped
        ready <= 1'b1;
    end else if (vbl_ev && ready) begin
        o_fb <= r_fb; r_fb <= o_fb;
        ready <= 1'b0;
    end
end

// ---------------------------------------------------------------- writes
// Addresses step, no multiplies. Per line y, the two pixels' line starts:
//   Stacked:  menu y*stride,               game y*stride + H*stride
//   Side:     menu y*stride,               game y*stride + 4W
//   CW:       menu (2H-1-y)*4,              game (H-1-y)*4         (a pixel steps +stride)
//   CCW:      menu (W-1)*stride + y*4,      game (W-1)*stride + (y+H)*4  (a pixel steps -stride)
// otherwise a pixel steps +4. y*stride is accumulated a line at a time; H*stride is its value
// at the end of the frame before; (W-1)*stride is a shift-add at each vsync.
reg  [22:0] line_acc = 23'd0, h_stride = 23'd0, w_stride = 23'd0;
reg  [11:0] col_m = 12'd0;                         // CW: 2H-1-y
reg  [22:0] m_addr, g_addr;
reg  [23:0] game_q;
reg         wr_game = 1'b0, wr = 1'b0;
reg  [31:0] wdata;
reg  [22:0] waddr;
reg         de_d = 1'b0, vs_d2 = 1'b0;
reg  [11:0] y4;                                    // y, for the CCW line start
// the shift-add for (W-1)*stride
reg  [ 3:0] mul_n = 4'd0;
reg  [11:0] mul_a;
reg  [22:0] mul_b, mul_p;

wire [22:0] step = cw ? { 9'd0, stride } : ccw ? -{ 9'd0, stride } : 23'd4;
wire        line_start = ce_pix && de && !de_d;

always @(posedge clk) begin
    wr <= 1'b0;
    if (mul_n != 4'd0) begin
        if (mul_a[0]) mul_p <= mul_p + mul_b;
        mul_a <= mul_a >> 1;
        mul_b <= mul_b << 1;
        mul_n <= mul_n - 4'd1;
        if (mul_n == 4'd1) w_stride <= mul_a[0] ? mul_p + mul_b : mul_p;
    end
    if (ce_pix) begin
        de_d  <= de;
        vs_d2 <= vs;
        if (~vs_d2 & vs) begin
            h_stride <= line_acc;
            line_acc <= 23'd0;
            col_m    <= { vsz[10:0], 1'b0 } - 12'd1;
            y4       <= 12'd0;
            mul_n    <= 4'd12; mul_a <= hsz - 12'd1; mul_b <= { 9'd0, stride }; mul_p <= 23'd0;
        end else if (de_d & ~de) begin
            line_acc <= line_acc + { 9'd0, stride };
            col_m    <= col_m - 12'd1;
            y4       <= y4 + 12'd1;
        end
    end

    if (ce_pix && de && FB_EN) begin
        // this pixel's addresses: at a line's start from the line terms, else the last plus step
        if (line_start) begin
            m_addr = cw ? { 9'd0, col_m, 2'b00 } : ccw ? w_stride + { 9'd0, y4, 2'b00 } : line_acc;
            g_addr = cw ? { 9'd0, 12'(col_m - vsz), 2'b00 } :
                     ccw ? w_stride + { 9'd0, 12'(y4 + vsz), 2'b00 } :
                     side ? line_acc + { 9'd0, hsz, 2'b00 } : line_acc + h_stride;
        end else begin
            m_addr = m_addr + step;
            g_addr = g_addr + step;
        end
        wr      <= 1'b1;
        wdata   <= { 8'd0, menu_rgb[7:0], menu_rgb[15:8], menu_rgb[23:16] };
        waddr   <= m_addr;
        game_q  <= game_rgb;
        wr_game <= 1'b1;
    end else if (wr_game) begin
        wr      <= 1'b1;
        wdata   <= { 8'd0, game_q[7:0], game_q[15:8], game_q[23:16] };
        waddr   <= g_addr;
        wr_game <= 1'b0;
    end
end

assign DDRAM_BURSTCNT = 8'd1;
assign DDRAM_ADDR     = { MEM_BASE, i_fb, waddr[22:3] };
assign DDRAM_BE       = waddr[2] ? 8'hF0 : 8'h0F;
assign DDRAM_DIN      = { wdata, wdata };
assign DDRAM_WE       = wr;

endmodule
