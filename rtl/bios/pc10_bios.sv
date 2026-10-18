// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Paul Priest
//
// The PlayChoice-10 BIOS board: Z80, its ROM, RAM and VRAM, the two LS259 latches, the
// vblank NMI / watchdog and the slot-0 RP5H01. From MAME playch10.cpp: bios_map and
// bios_io_map (1479-1499), the latch callbacks (729-782, 1907-1920), vblank_irq
// (1886-1896), pc10_prot_r/w (790-812), ram_8w_r/w (637-651).
//
// The Z80 runs at 4 MHz on clk = 21.477272 MHz: 176 enables in 945 clocks, exact.
module pc10_bios (
    input             clk,
    input             reset,         // machine reset (MAME machine_reset)
    input             pause,
    input             single,        // run the single-monitor BIOS (MAME's "single")

    // ROM loading: 0000-3FFF dual-monitor BIOS, 4000-5FFF INST ROM, 6000-600F RP5H01 PROM,
    // 8000-BFFF the single-monitor BIOS
    input             ld_we,
    input      [15:0] ld_addr,
    input      [ 7:0] ld_data,

    // a channel's cart ROMs (PlayChoice10.sv, .mra index 32 + channel): 0000-1FFF its INST
    // ROM, 2000-200F its RP5H01 PROM. The INST ROM and PROM in ld_addr above are channel 0's.
    input             cart_ld_we,
    input      [ 3:0] cart_ld_slot,
    input      [13:0] cart_ld_addr,

    input             vblank,        // rising edge = vblank_irq; MAME's is the frame's end (MAME_KLUDGES)
    input             int_detect_set,// the PPU's NMI output (int_detect_w)

    input      [ 7:0] bios_in,       // BIOS port, bit 3 ignored (INT DETECT is ours)
    input      [ 7:0] sw1,
    input      [ 7:0] sw2,

    // LS259 7D and 7E
    output            sdcs,          // Z80 owns VRAM; BIOS display black
    output            cntrl_mask,
    output            disp_mask,
    output            sound_mute,
    output            game_reset,    // hold the NES in reset
    output            game_stop,     // halt the NES CPU
    output            ppu_reset,
    output     [ 3:0] cart_sel,
    output     [ 3:0] time_digit_we, // single BIOS: 7-segment digits, data on time_data
    output     [ 3:0] time_data,

    // VRAM read port for the display
    input      [10:0] vram_raddr,
    output reg [ 7:0] vram_rdata,

`ifdef SIMULATION
    output            z_cen,
    output     [15:0] z_a,
    output     [ 7:0] z_di,
    output     [ 7:0] z_do,
    output            z_mreq_n, z_iorq_n, z_rd_n, z_wr_n, z_m1_n, z_rfsh_n,
`endif
    output            z80_running
);

// ---------------------------------------------------------------- clock enable
reg  [9:0] acc = 10'd0;
reg        cen = 1'b0;
always @(posedge clk) begin
    if (acc >= 10'd769) begin acc <= acc - 10'd769; cen <= ~pause; end   // + 176, wrap at 945
    else begin acc <= acc + 10'd176; cen <= 1'b0; end
end

// ---------------------------------------------------------------- Z80
wire [15:0] A;
wire [ 7:0] DO;
reg  [ 7:0] DI;
wire        MREQ_n, IORQ_n, RD_n, WR_n, M1_n, RFSH_n;
reg         nmi_n = 1'b1;
reg  [ 5:0] zres_cnt = 6'd0;          // watchdog reset, held across several enables
wire        z_reset_n = ~reset && zres_cnt == 6'd0;

T80se #(.Mode(0), .T2Write(0), .IOWait(1)) u_z80 (
    .RESET_n(z_reset_n), .CLK_n(clk), .CLKEN(cen),
    .WAIT_n(1'b1), .INT_n(1'b1), .NMI_n(nmi_n), .BUSRQ_n(1'b1),
    .M1_n(M1_n), .MREQ_n(MREQ_n), .IORQ_n(IORQ_n), .RD_n(RD_n), .WR_n(WR_n),
    .RFSH_n(RFSH_n), .HALT_n(), .BUSAK_n(),
    .A(A), .DI(DI), .DO(DO)
);

assign z80_running = z_reset_n;

// ---------------------------------------------------------------- strobes
reg wr_d = 1'b1;
always @(posedge clk) wr_d <= WR_n;
wire wr_edge = wr_d & ~WR_n;
wire mem_wr  = wr_edge & ~MREQ_n;
wire io_wr   = wr_edge & ~IORQ_n;
wire io_rd   = ~IORQ_n & ~RD_n & M1_n;
reg  io_rd_d = 1'b0;
always @(posedge clk) io_rd_d <= io_rd;
wire io_rd_edge = io_rd & ~io_rd_d;

// ---------------------------------------------------------------- latches
reg [7:0] q7d = 8'd0, q7e = 8'd0;     // MAME's LS259s power up cleared
always @(posedge clk) begin
    if (reset) begin
        q7d <= 8'd0; q7e <= 8'd0;
    end else if (io_wr && A[7:4] == 4'h0) begin
        if (!A[3]) q7d[A[2:0]] <= DO[0];
        else       q7e[A[2:0]] <= DO[0];
    end
end

assign sdcs        = ~q7d[0];
assign cntrl_mask  = ~q7d[1];
assign disp_mask   = ~q7d[2];
assign sound_mute  = ~q7d[3];
assign game_reset  = ~q7d[4];
assign game_stop   = ~q7d[5];
wire   nmi_enable  =  q7e[0];
wire   dog_di      =  q7e[1];
assign ppu_reset   =  q7e[2];
assign cart_sel    =  q7e[6:3];
wire   up8w        =  q7e[7];

assign time_digit_we = (io_wr && A[7:2] == 6'b000100) ? (4'b0001 << A[1:0]) : 4'b0000;
assign time_data     = DO[3:0];

// ---------------------------------------------------------------- vblank: NMI or watchdog
reg vbl_d = 1'b0;
reg [3:0] nmi_cnt = 4'd0;
always @(posedge clk) begin
    vbl_d <= vblank;
    if (zres_cnt != 6'd0 && cen) zres_cnt <= zres_cnt - 6'd1;
    if (nmi_cnt != 4'd0 && cen)  nmi_cnt  <= nmi_cnt - 4'd1;
    nmi_n <= nmi_cnt == 4'd0;
    if (reset) begin
        zres_cnt <= 6'd0; nmi_cnt <= 4'd0;
    end else if (vblank && !vbl_d) begin
        if (!dog_di && !nmi_enable) zres_cnt <= 6'd4;
        else if (nmi_enable)        nmi_cnt  <= 4'd2;
    end
end

// ---------------------------------------------------------------- INT DETECT
reg int_detect = 1'b0;
always @(posedge clk) begin
    if (reset) int_detect <= 1'b0;
    else if (int_detect_set) int_detect <= 1'b1;
    else if (io_rd_edge && A[7:0] == 8'h03) int_detect <= 1'b0;
end

// ---------------------------------------------------------------- memories
reg [7:0] rom  [0:32767];
// ten channels' INST ROMs. A channel never loaded reads channel 0's, as MAME maps the set's
// INST ROM whatever the cart select (MAME_KLUDGES); its RP5H01 port reads E7.
reg [7:0] inst [0:81919];
reg [9:0] slot_loaded = 10'd0;
reg [7:0] ram8v[0:2047];
reg [7:0] ram8w[0:2047];
reg [7:0] vram [0:2047];

wire ld_rom  = ld_we && ld_addr[14] == 1'b0;
wire ld_inst = ld_we && ld_addr[15:13] == 3'b010;
wire ld_prom = ld_we && ld_addr[15:4] == 12'h600;
always @(posedge clk) if (ld_rom)  rom[{ ld_addr[15], ld_addr[13:0] }] <= ld_data;
wire        cl_inst = cart_ld_we && cart_ld_slot < 4'd10 && cart_ld_addr[13] == 1'b0;
wire        cl_prom = cart_ld_we && cart_ld_slot < 4'd10 && cart_ld_addr[13:4] == 10'h200;
wire [16:0] inst_wa = cl_inst ? { cart_ld_slot, cart_ld_addr[12:0] } : { 4'd0, ld_addr[12:0] };
always @(posedge clk) begin
    if (ld_inst || cl_inst) inst[inst_wa] <= ld_data;
    if (ld_inst) slot_loaded[0] <= 1'b1;
    if (cl_inst) slot_loaded[cart_ld_slot] <= 1'b1;
end

wire        sel_rom  = A[15:14] == 2'b00;
wire        sel_8v   = A[15:11] == 5'b10000;
wire        sel_8w   = A[15:11] == 5'b10001;
wire        sel_vram = A[15:11] == 5'b10010;
wire        sel_inst = A[15:13] == 3'b110;
wire        sel_prot = A[15:13] == 3'b111;
wire [10:0] a8w      = up8w ? A[10:0] : { 1'b0, A[9:0] };

reg [7:0] rom_q, inst_q, v_q, w_q, vr_q;
always @(posedge clk) begin
    rom_q  <= rom[{ single, A[13:0] }];
    inst_q <= inst[cart_sel < 4'd10 && slot_loaded[cart_sel] ? { cart_sel, A[12:0] } : { 4'd0, A[12:0] }];
    v_q    <= ram8v[A[10:0]];
    w_q    <= ram8w[a8w];
    vr_q   <= vram[A[10:0]];
    if (mem_wr && sel_8v)          ram8v[A[10:0]] <= DO;
    if (mem_wr && sel_8w)          ram8w[a8w]     <= DO;
    if (mem_wr && sel_vram && sdcs) vram[A[10:0]] <= DO;
end
always @(posedge clk) vram_rdata <= vram[vram_raddr];

// ---------------------------------------------------------------- RP5H01, one a channel
wire [9:0] rp_cnt, rp_dat;
genvar gi;
generate for (gi = 0; gi < 10; gi = gi + 1) begin : g_rp
    rp5h01 u_rp (
        .clk(clk), .reset(reset),
        .we(mem_wr && sel_prot && cart_sel == gi),
        .test(DO[4]), .dclk(DO[3]), .rst_pin(~DO[0]),
        .counter_out(rp_cnt[gi]), .data_out(rp_dat[gi]),
        .ld_we(gi == 0 ? ld_prom : cl_prom && cart_ld_slot == gi),
        .ld_addr(gi == 0 && ld_prom ? ld_addr[3:0] : cart_ld_addr[3:0]), .ld_data(ld_data)
    );
end endgenerate
// MAME reads E7 from every slot but 0 (pc10_prot_r); here, from every channel not loaded
wire       rp_here = cart_sel < 4'd10 && slot_loaded[cart_sel];
wire [7:0] prot_q = rp_here ? { 3'b111, ~rp_cnt[cart_sel], rp_dat[cart_sel], 3'b111 } : 8'hE7;

// ---------------------------------------------------------------- read mux
always @* begin
    DI = 8'h00;
    if (!IORQ_n) begin
        case (A[7:0])
            8'h00:   DI = { bios_in[7:4], ~int_detect, bios_in[2:0] };
            8'h01:   DI = sw1;
            8'h02:   DI = sw2;
            default: DI = 8'h00;
        endcase
    end else if (sel_rom)  DI = rom_q;
    else if (sel_8v)       DI = v_q;
    else if (sel_8w)       DI = w_q;
    else if (sel_vram)     DI = vr_q;
    else if (sel_inst)     DI = inst_q;
    else if (sel_prot)     DI = prot_q;
end

`ifdef SIMULATION
assign z_cen = cen; assign z_a = A; assign z_di = DI; assign z_do = DO;
assign z_mreq_n = MREQ_n; assign z_iorq_n = IORQ_n; assign z_rd_n = RD_n;
assign z_wr_n = WR_n; assign z_m1_n = M1_n; assign z_rfsh_n = RFSH_n;
`endif

endmodule
