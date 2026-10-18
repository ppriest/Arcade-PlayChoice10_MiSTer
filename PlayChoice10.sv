// SPDX-License-Identifier: GPL-3.0-or-later
//
// PlayChoice-10. Phase 0: NES_MiSTer's NES.sv (rtl/nes/PROVENANCE.md), unchanged apart
// from the core name and the two .mif paths, running one cart with no BIOS board.
//
// Copyright (c) 2012-2013 Ludvig Strigeus
// MiSTer port: Copyright (C) 2017,2018 Sorgelig

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;

assign AUDIO_S   = 0;
assign AUDIO_L   = bios_sound_mute ? 16'd0 : sample[15:0];
assign AUDIO_R   = AUDIO_L;
assign AUDIO_MIX = 0;

assign LED_USER  = downloading | (loader_fail & led_blink) | (bk_state != S_IDLE) | (bk_pending & ~status[50]);
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS [1] = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign VGA_F1 = 0;
//assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [1:0] ar       = status[19:18];
wire       vcrop_en = status[5];
wire [3:0] vcopt    = status[38:35];
reg        en216p;
reg  [4:0] voff;
always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

// Each monitor is 4:3; the HDMI layouts multiply it out: stacked 2:3, side by side 8:3,
// rotated 3:2 (pc10_fb)
// the OSD lists Stacked first, so it is the default (status 0); pc10_fb's mode numbers
// differ: 0 off (As CRT), 1 Stacked
wire [2:0]  hdmi_sel = status[104:102];
wire [2:0]  fb_mode  = hdmi_sel > 3'd4 || bios_single ? 3'd0 :
                       hdmi_sel == 3'd0 ? 3'd1 : hdmi_sel == 3'd1 ? 3'd0 : hdmi_sel;
wire [11:0] base_arx = fb_mode == 3'd1 ? 12'd2 : fb_mode == 3'd2 ? 12'd8 : fb_mode[2] | (fb_mode == 3'd3) ? 12'd3 : 12'd4;
wire [11:0] base_ary = fb_mode == 3'd1 ? 12'd3 : fb_mode == 3'd2 ? 12'd3 : fb_mode[2] | (fb_mode == 3'd3) ? 12'd2 : 12'd3;

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? base_arx : (ar - 1'd1)),
	.ARY((!ar) ? base_ary : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[40:39])
);

// If video mode (NTSC/PAL/Dendy/Vs.) changes, force vmode update
reg [1:0] video_status;
reg new_vmode = 0;
always @(posedge clk) begin
	if (video_status != effective_sys_type) begin
		video_status <= effective_sys_type;
		new_vmode <= ~new_vmode;
    end
end

// Status Bit Map:
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXX XX     XXXXXXXXXXXXX XX XXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
parameter CONF_STR = {
	"PlayChoice10;SS3E000000:200000,UART31250,MIDI;",
	"-;",
	"O[72:70],System Type,Auto,NTSC,PAL,Dendy,Vs.;",
	"-;",
	"C,Cheats;",
	"H2OK,Cheats Enabled,On,Off;",
	"-;",
	"oI,Autosave,On,Off;",
	"H5D0R6,Load Backup RAM;",
	"H5D0R7,Save Backup RAM;",
	"-;",
	"oC,Savestates to SDCard,On,Off;",
	"oDE,Savestate Slot,1,2,3,4;",
	"d7rA,Save state(Alt+F1-F4);",
	"d7rB,Restore state(F1-F4);",
	"-;",
	"P1,Audio & Video;",
	"P1-;",
	"P1-;",
	"P1OIJ,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"HAP1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"P1-;",
	"d6P1O5,Vertical Crop,Disabled,216p(5x);",
	"d6P1o36,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P1o78,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1O[68:67],Overscan,Normal,Vertical Overscan,Borders,Everything;",
	"P1ORS,Mask Edges,Off,Left,Both,Auto;",
	"P1OP,Extra Sprites,Off,On;",
	"P1-;",
	"P1O[101:100],Screen (CRT),Auto,Game,Menu;",
	"HBP1O[104:102],Screen (HDMI),Stacked,As CRT,Side by side,Rotated CW,Rotated CCW;",
	"P1O[105],BIOS (reset),Dual monitor,Single monitor;",
	"P1-;",
	"P1OUV,Audio Enable,Both,Internal,Cart Expansion,None;",
	"P2,Input Options;",
	"P2-;",
	"P2O9,Swap Joysticks,No,Yes;",
	"P2OA,Multitap,Disabled,Enabled;",
	"P2oJK,SNAC,Off,Controllers,Zapper,3D Glasses;",
	"P2o02,Peripheral,None,Zapper(Mouse),Zapper(Joy1),Zapper(Joy2),Vaus,Vaus(A-Trigger),Powerpad,Family Trainer;",
	"P2oL,Famicom Keyboard,No,Yes;",
	"P2-;",
	"P2OL,Zapper Trigger,Mouse,Joystick;",
	"P2OM,Crosshairs,On,Off;",
	"P3,Miscellaneous;",
	"P3-;",
	"P3OG,Disk Swap,Auto,FDS button;",
	"P3O[17],Disk Speed,Fast,Original;",
	"P3o9,Pause when OSD is open,Off,On;",
	"P4,Advanced;",
	"P4-;",
	"P4O[66:65],RAM Clear,No,$00,$FF,Random;",
	"P4O[64],PPU Reset Behavior,Famicom,NES;",
	"HAP4OQ,Video Dijitter,Enabled,Disabled;",
	"P4O[69],Debug Dots,Off,On;",
	"H8P5,Vs. DIPs;",
	"H8P5-;",
	"H8P5O[73],Switch 0,Off,On;",
	"H8P5O[74],Switch 1,Off,On;",
	"H8P5O[75],Switch 2,Off,On;",
	"H8P5O[76],Switch 3,Off,On;",
	"H8P5O[77],Switch 4,Off,On;",
	"H8P5O[78],Switch 5,Off,On;",
	"H8P5O[79],Switch 6,Off,On;",
	"H8P5O[80],Switch 7,Off,On;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,A,B,Select,Start,Coin,Enter,Channel Select,Service,BIOS Reset;",
	"jn,A,B,Select,Start,L,,R|P;",
	"jp,B,Y,Select,Start,L,,R|P;",
	"I,",
	"Disk 1A,",
	"Disk 1B,",
	"Disk 2A,",
	"Disk 2B,",
	"Slot=DPAD|Save/Load=Start+DPAD,",
	"Active Slot 1,",
	"Active Slot 2,",
	"Active Slot 3,",
	"Active Slot 4,",
	"Save to state 1,",
	"Restore state 1,",
	"Save to state 2,",
	"Restore state 2,",
	"Save to state 3,",
	"Restore state 3,",
	"Save to state 4,",
	"Restore state 4,",
	"No NES 2.0 header found\nDefaulting to NTSC;",
	"V,v",`BUILD_DATE
};

wire [23:0] joyA,joyB,joyC,joyD;
wire [23:0] joyB_pad;
wire [23:0] joyA_unmod;
wire [10:0] ps2_key;
wire [1:0] buttons;

wire [127:0] status;

// PlayChoice-10 BIOS board signals used above its instance (below the video section)
localparam [7:0] PC10_IDX_BIOS = 8'd4;     // ioctl index of the BIOS board's ROMs
wire        bios_cntrl_mask, bios_sound_mute, bios_game_reset, bios_game_stop;
wire  [3:0] bios_cart_sel;
wire        ppu_nmi;
wire  [7:0] bios_r, bios_g, bios_b;
// Screen: Auto shows the BIOS display while the BIOS masks the game (DISPMASK). The
// single-monitor BIOS has one screen: the game or the BIOS display, swapped on each rising
// DISPMASK (MAME's screen_update_playch10_single, playch10.cpp 573-591).
wire        bios_disp_mask;
wire        bios_single = status[105];
reg         single_game = 1'b0;
wire        show_menu = bios_single ? !single_game :
                        status[101:100] == 2'd2 || (status[101:100] == 2'd0 && bios_disp_mask);

wire arm_reset = status[0];
wire [1:0] hide_overscan = status[68:67];
wire [3:0] palette2_osd = status[49:47];
wire [6:0] default_expansion = mapper_flags[59:53];
wire vs_player_left = vs_system && (default_expansion == 7'h05);
wire joy_swap = status[9] ^ (raw_serial || piano || vs_player_left); // Controller on port 2 for Miracle Piano/SNAC/Vs.
wire fds_auto_eject = ~status[16];
wire fds_fast = ~status[17];
wire ext_audio = ~status[30];
wire int_audio = ~status[31];

// Auto detects the NES 2.0 console type before its timing-region field. Legacy
// images can select Vs. explicitly from the menu.
wire [2:0] system_type_select = status[72:70];
wire       system_type_auto = (system_type_select == 3'd0) || (system_type_select > 3'd4);
wire [1:0] auto_sys_type = (mapper_flags[44:43] == 2'd1) ? 2'd3 :  // Vs. System
                           (mapper_flags[37:36] == 2'd1) ? 2'd1 :  // PAL
                           (mapper_flags[37:36] == 2'd3) ? 2'd2 :  // Dendy
                           2'd0;                                   // NTSC (0 and multi-region)
wire [1:0] effective_sys_type = system_type_auto ? auto_sys_type
                                                  : (system_type_select[1:0] - 2'd1);
wire pal_video = (effective_sys_type == 2'd1) || (effective_sys_type == 2'd2);
wire vs_system = (effective_sys_type == 2'd3);
wire vs_header_zapper = vs_system && (default_expansion == 7'h07);
wire vs_menu_hidden = ~vs_system;
wire [7:0] vs_dip_switches = vs_menu_hidden ? 8'd0 : status[80:73];

// The PlayChoice-10 drives RGB monitors: NES_MiSTer's composite path is left out (pruned in
// synthesis), which frees the logic and DSP it took.
wire composite_available = 1'b0;
// Budget TV: notch separation and a narrow chroma band. Premium TV: adaptive
// comb and a wider chroma band.
wire [1:0] composite_set = status[82:81];
wire use_composite = (composite_set != 2'd0) && composite_available;
wire composite_premium = (composite_set == 2'd2);

wire [15:0] status_menumask = {4'd0, bios_single, use_composite, ~composite_available, vs_menu_hidden, (rom_loaded && mapper_has_savestate), en216p,
	~status[50], ~raw_serial, (palette2_osd != 3'd5), ~gg_avail, bios_loaded, ~bk_ena};

// Figure out file types
reg type_bios, type_fds, type_gg, type_nsf, type_nes, type_palette, is_bios, downloading;
// the channel a cart download fills: index 16 + channel, or index 1 for channel 0
reg [3:0] load_slot = 4'd0;
reg [24:0] rom_sz;

wire [7:0] random_byte = q[7:0];
wire feedback = q[31]^q[29]^q[28]^ q[27]^ q[23]^q[20]^ q[19]^q[17]^ q[15]^q[14]^q[12]^ q[11]^q[9]^ q[4]^ q[3]^q[2];
reg [31:0] q = 32'haaaaaaaa;

always_ff @(posedge clk) begin
	reg old_downld;
	q <= {q[30:0], feedback} ;

	old_downld <= downloading;
	loader_reset <= !download_reset || (~old_downld && downloading);

	ioctl_download <= ioctl_downloading;
	{type_bios, type_fds, type_gg, type_nsf, type_nes, type_palette, is_bios, downloading} <= 0;
	if (filetype == PC10_IDX_BIOS || filetype == 8'd254 || (filetype >= 8'd32 && filetype < 8'd42))
		;
	else if (filetype >= 8'd16 && filetype < 8'd26) begin
		type_nes <= 1; downloading <= ioctl_downloading;        // channel filetype - 16's cart
	end
	else if (~|filetype[5:0])
		case(filetype[7:6])
			2'b00: begin type_bios <= 1; is_bios <= 1; downloading <= ioctl_downloading; end
			2'b01: begin type_nes <= 1; downloading <= ioctl_downloading; end
			2'b10: begin type_fds <= 1; downloading <= ioctl_downloading; end
			//2'b11: begin type_palette <= 1; end
		endcase
	else if(&filetype)
		type_gg <= 1;
	else if (filetype[1:0] == 2'b01)
		case (filetype[7:6])
			2'b00: begin type_nes <= 1; downloading <= ioctl_downloading; end
			2'b01: begin type_fds <= 1; downloading <= ioctl_downloading; end
			2'b10: begin type_nsf <= 1; downloading <= ioctl_downloading; end
		endcase
	else if (filetype[1:0] == 2'b10) begin
		type_bios <= 1;
		downloading <= ioctl_downloading;
	end else if (filetype[1:0] == 2'b11)
		type_palette <= 1;

	if(old_downld && ~downloading & (type_fds|type_nsf|type_nes)) rom_sz <= ioctl_addr - 1'd1;
	if (ioctl_downloading) load_slot <= (filetype >= 8'd16 && filetype < 8'd26) ? filetype[3:0] : 4'd0;
end

assign BUTTONS[0] = osd_btn;

// Pop OSD menu if no rom has been loaded automatically
wire rom_loaded;

reg osd_btn = 0;
always @(posedge clk) begin : osd_block
	integer timeout = 0;

	if(!RESET) begin
		osd_btn <= 0;
		if(timeout < 61000000) begin
			timeout <= timeout + 1;
			if (timeout > 50000000)
				osd_btn <= ~rom_loaded;
		end
	end
end

wire apu_ce;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire  [7:0] filetype;
wire        ioctl_downloading;
reg         ioctl_download;
wire [24:0] ioctl_addr;
reg         ioctl_wait;

wire [24:0] ps2_mouse;
wire [15:0] joy_analog0, joy_analog1;
wire  [7:0] pdl[4];
wire        forced_scandoubler;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.joystick_0(joyA_unmod),
	.joystick_1(joyB_pad),
	.joystick_2(joyC),
	.joystick_3(joyD),
	.joystick_l_analog_0(joy_analog0),
	.joystick_l_analog_1(joy_analog1),
	.paddle_0(pdl[0]),
	.paddle_1(pdl[1]),
	.paddle_2(pdl[2]),
	.paddle_3(pdl[3]),

	.status(status),
	.status_menumask(status_menumask),
	.status_in({status[127:47],ss_slot,status[44:0]}),
	.status_set(statusUpdate),
	.info_req(info_req),
	.info(info),

	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_downloading),
	.ioctl_addr(ioctl_addr),
	.ioctl_wr(loader_clk),
	.ioctl_dout(file_input),
	.ioctl_wait(ioctl_wait | save_wait),
	.ioctl_index(filetype),

	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.ps2_key(ps2_key),

	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0),

	.ps2_mouse(ps2_mouse)

	//.uart_mode(16'b000_11111_000_11111)
);

// MAME's keys for the PlayChoice-10 (playch10.cpp 1635-1855) in J1's layout: right, left,
// down, up, A (LAlt, BUTTON2), B (LCtrl, BUTTON1), Select (2), Start (1), Coin (5),
// Enter (-), Channel Select (0), Service (9), BIOS Reset (=); player 2's coin is 6.
wire [31:0] mk0, mk1;
wire  [1:0] mk_svc;
mame_keys #(.BUTTONS(2), .START(13), .COIN(14), .PAUSE(15), .SERVICE(16)) u_keys (
	.clk(clk), .ps2_key(ps2_key), .key0(mk0), .key1(mk1), .svc_coin(mk_svc)
);
reg  key_enter = 1'b0, key_reset = 1'b0, key_tog = 1'b0;
always @(posedge clk) begin
	key_tog <= ps2_key[10];
	if (ps2_key[10] != key_tog)
		case (ps2_key[8:0])
			9'h04E: key_enter <= ps2_key[9];    // -
			9'h055: key_reset <= ps2_key[9];    // =
			default: ;
		endcase
end
wire [12:0] kb_a = { key_reset, mk_svc[0], mk_svc[1], key_enter, mk0[14], mk0[13], mk1[13], mk0[4], mk0[5], mk0[3:0] };
wire [12:0] kb_b = { 3'b000, 1'b0, mk1[14], 2'b00, mk1[4], mk1[5], mk1[3:0] };
assign joyA = joyA_unmod | { 11'd0, kb_a };
assign joyB = joyB_pad   | { 11'd0, kb_b };

wire       info_req = diskside_info || ss_info_req || auto_info_req;
wire [7:0] info     = ss_info_req ? ss_info : auto_info_req ? 8'd18 : {1'b0,diskside} + 3'd1;

wire clock_locked;
wire clk85;
wire clk;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk85),
	.outclk_1(CLK_VIDEO),
	.outclk_2(clk),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(clock_locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin : cfg_block
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;

	pald  <= (effective_sys_type == 2'd1);
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 != pald) state <= 1;

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			3: begin
					cfg_address <= 7;
					cfg_data <= pald2 ? 2201376898 : 2537933971;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end


// reset after download
reg [7:0] download_reset_cnt;
wire download_reset = download_reset_cnt != 0;
always @(posedge clk) begin
	if(downloading) download_reset_cnt <= 8'hFF;
	else if(!loader_busy && download_reset_cnt) download_reset_cnt <= download_reset_cnt - 1'd1;
end

// hold machine in reset until first download starts
reg init_reset_n = 0;
always @(posedge clk) if(downloading) init_reset_n <= 1;

wire  [8:0] cycle;
wire  [8:0] scanline;
wire [15:0] sample;
wire  [5:0] color;
wire  [2:0] joypad_out;
wire  [1:0] joypad_clock;
reg  [23:0] joypad_bits, joypad_bits2;
reg   [7:0] joypad_d3, joypad_d4;
reg   [1:0] last_joypad_clock;

// J1 bits 8-12 are the PlayChoice-10's coin and BIOS buttons, not the console's peripherals
wire [11:0] powerpad = 12'd0;

wire [3:0] famtr;
assign famtr[0] = (~joypad_out[2] & powerpad[3]) | (~joypad_out[1] & powerpad[7]) | (~joypad_out[0] & powerpad[11]);
assign famtr[1] = (~joypad_out[2] & powerpad[2]) | (~joypad_out[1] & powerpad[6]) | (~joypad_out[0] & powerpad[10]);
assign famtr[2] = (~joypad_out[2] & powerpad[1]) | (~joypad_out[1] & powerpad[5]) | (~joypad_out[0] & powerpad[9] );
assign famtr[3] = (~joypad_out[2] & powerpad[0]) | (~joypad_out[1] & powerpad[4]) | (~joypad_out[0] & powerpad[8] );

// CNTRLMASK clears player 1's Select and Start; player 2's are wired to player 1's (MAME
// pc10_in0_w and the P2 port, playch10.cpp 820-834, 1843-1844)
wire [7:0] nes_joy_A = { joyA[0], joyA[1], joyA[2], joyA[3], joyA[7] & ~bios_cntrl_mask, joyA[6] & ~bios_cntrl_mask, joyA[5], ~paddle_atr & joyA[4] };
wire [7:0] nes_joy_B = { joyB[0], joyB[1], joyB[2], joyB[3], 1'b0, 1'b0, joyB[5], ~paddle_atr & joyB[4] };
wire [7:0] nes_joy_C = { joyC[0], joyC[1], joyC[2], joyC[3], joyC[7], joyC[6], joyC[5], ~paddle_atr & joyC[4] };
wire [7:0] nes_joy_D = { joyD[0], joyD[1], joyD[2], joyD[3], joyD[7], joyD[6], joyD[5], ~paddle_atr & joyD[4] };

wire mic_button = 1'b0;
wire fds_btn = 1'b0;

reg [1:0] nes_ce;

wire raw_serial = |status[52:51];

// Extend SNAC zapper high signal to be closer to original NES
wire extend_serial_d4 = status[52:51] == 2'b10;
wire snac_3d_glasses = &status[52:51];

wire serial_d4 = extend_serial_d4 ? |serial_d4_sr : ~USER_IN[4];
reg [7:0] serial_d4_sr;
reg snac_p2 = 0;
wire vs_zapper_data;
wire vs_zapper_en;

always @(posedge clk) begin
	reg [17:0] clk_cnt;

	if (raw_serial) begin
		if (~USER_IN[6])
			snac_p2 <= 1;
	end else begin
		snac_p2 <= 0;
	end

	clk_cnt <= clk_cnt + 1'b1;
	serial_d4_sr[0] <= ~USER_IN[4];

	// Shift every 10ms
	if (clk_cnt == 18'd214772) begin
		serial_d4_sr <= serial_d4_sr << 1;
		clk_cnt <= 0;
	end
end

// Indexes:
// IDXDIR   Function    USBPIN
// 0  OUT   Strobe      D+
// 1  OUT   Clk (P2)    D-
// 2  BI    Glasses/D3  TX-
// 3  OUT   CLK (P2)    GND_d
// 4  IN    D4          RX+
// 5  IN    P1D0        RX-
// 6  IN    P2D0        TX+

assign USER_OUT[4] = 1'b1;
assign USER_OUT[5] = 1'b1;
assign USER_OUT[6] = 1'b1;

reg [4:0] joypad1_data, joypad2_data;

wire joy0_d0 = snac_p2 ? ~USER_IN[6] : joypad_bits[0];
wire joy1_d0 = snac_p2 ? ~USER_IN[6] : joypad_bits2[0];

always_comb begin
	if (raw_serial) begin
		USER_OUT[0]  = joypad_out[0];
		USER_OUT[1]  = ~joy_swap ? ~joypad_clock[1] : ~joypad_clock[0];
		USER_OUT[2]  = snac_3d_glasses ? joypad_out[1] : 1'b1;
		USER_OUT[3]  = ~joy_swap ? ~joypad_clock[0] : ~joypad_clock[1];
		joypad1_data = {2'b0, mic, 1'b0, ~joy_swap ? joy0_d0 : ~USER_IN[5]};
		joypad2_data = {serial_d4, snac_3d_glasses ? 1'b1 : ~USER_IN[2], 2'b00, ~joy_swap ? ~USER_IN[5] : joy1_d0};

		// The Vs. gun replaces controller 0's serial report instead of driving
		// the consumer Zapper D3/D4 lines on controller 1.
		if (vs_zapper_en) joypad1_data[0] = vs_zapper_data;
	end else begin
		USER_OUT[0]  = 1'b1;
		USER_OUT[1]  = 1'b1;
		USER_OUT[2]  = 1'b1;
		USER_OUT[3]  = 1'b1;

		joypad1_data = {2'b0, mic, paddle_en & paddle_btn, joypad_bits[0]};
		joypad2_data = joypad_bits2[0];

		// Periphery normally uses port 2. The Vs. gun is an eight-bit serial
		// device on port 1 and is inserted on D0 above the cabinet I/O packer.
		if (vs_zapper_en)       joypad1_data[0] = vs_zapper_data;
		else if (lightgun_en)   joypad2_data[4:3] = {trigger,light};
		if (paddle_en)          joypad2_data[4:1] = {joypad_d4[0], paddle_btn, 1'b0, joypad_d4[0]};
		if (status[34:32] == 6) joypad2_data[4:3] = {joypad_d4[0], joypad_d3[0]};
		if (status[34:32] == 7) joypad2_data[4:1] = ~famtr;
		if (fkeyb)              joypad2_data[4:1] = key_out;
	end
end

wire mic = (mic_cnt < 8'd215) && mic_button;
reg [7:0] mic_cnt;
always @(posedge clk) mic_cnt <= (mic_cnt == 8'd250) ? 8'd0 : mic_cnt + 1'b1;

wire fkeyb = status[53];
wire [3:0] key_out;
keyboard fkey(
	.clk(clk),
	.reset(reset_nes || !fkeyb),
	.posit(1'd1),
	.ps2_key(ps2_key),
	.reg_4016(joypad_out),
	.reg_4017(key_out)
);

assign {UART_RTS, UART_DTR} = 1;
wire [15:0] uart_data;
miraclepiano miracle(
	.clk(clk),
	.reset(reset_nes || !piano),
	.strobe(joypad_out[0]),
	.joypad_o(),
	.joypad_clock(joypad_clock[0]),
	.data_o(uart_data),
	.txd(UART_TXD),
	.rxd(UART_RXD)
);

wire manual_lightgun_en = ~status[34] & |status[33:32];
wire lightgun_en = manual_lightgun_en || vs_header_zapper;
wire zapper_port_b = manual_lightgun_en && status[32];
wire zapper_mode = manual_lightgun_en ? status[33] : 1'b1;
wire zapper_trigger_mode = manual_lightgun_en ? status[21] : 1'b1;
assign vs_zapper_en = vs_system && (extend_serial_d4 || (!raw_serial && lightgun_en));

zapper zap (
	.clk(clk),
	.reset(reset_nes | ~lightgun_en),
	.mode(zapper_mode),
	.trigger_mode(zapper_trigger_mode),
	.ps2_mouse(ps2_mouse),
	.analog(zapper_port_b ? joy_analog1 : joy_analog0),
	.analog_trigger(zapper_port_b ? joyB[10] : joyA[10]),
	.cycle(cycle),
	.scanline(scanline),
	.color(color),
	.reticle(reticle),
	.light(light),
	.trigger(trigger)
);

vs_zapper_serializer vs_zapper (
	.clk(clk),
	.reset(reset_nes),
	.enable(vs_zapper_en),
	.strobe(joypad_out[0]),
	.read_clock(joypad_clock[0]),
	.light(extend_serial_d4 ? ~USER_IN[2] : light),
	.trigger(extend_serial_d4 ? serial_d4 : trigger),
	.serial_data(vs_zapper_data)
);

reg [7:0] paddle = 0;
always @(posedge clk) begin
	reg [7:0] old_pdl[4];
	reg [1:0] num = 0;

	for(reg [2:0] i=0; i<4; i++) begin
		old_pdl[i] <= pdl[i];
		if($signed((pdl[i] - old_pdl[i])) > 4) num <= i[1:0];
	end

	paddle <= pdl[num];
end

localparam [7:0] paddle_off = 32; //middle point for Chase HQ

wire [7:0] paddle_adj = paddle_off + ((paddle < 40) ? 8'd40 : (paddle > 216) ? 8'd216 : paddle);
wire [7:0] paddle_nes = ~{paddle_adj[0],paddle_adj[1],paddle_adj[2],paddle_adj[3],paddle_adj[4],paddle_adj[5],paddle_adj[6],paddle_adj[7]};
wire       paddle_en  = (status[34:33] == 2);
wire       paddle_atr = paddle_en & status[32];
wire       paddle_btn = paddle_atr ? (joyA[4] | joyB[4] | joyC[4] | joyD[4]) : (joyA[10] | joyB[10] | joyC[10] | joyD[10]);

always @(posedge clk) begin
	if (reset_nes) begin
		joypad_bits <= 0;
		joypad_bits2 <= 0;
		joypad_d3 <= 0;
		joypad_d4 <= 0;
		last_joypad_clock <= 0;
	end else begin
		if (joypad_out[0]) begin
			joypad_bits  <= piano ? {15'h0000, uart_data[8:0]}
				: {status[10] ? {8'h08, nes_joy_C} : 16'hFFFF, joy_swap ? nes_joy_B : nes_joy_A};
			joypad_bits2 <= {status[10] ? {8'h04, nes_joy_D} : 16'hFFFF, joy_swap ? nes_joy_A : nes_joy_B};
			joypad_d4 <= paddle_en ? paddle_nes : {4'b1111, powerpad[7], powerpad[11], powerpad[2], powerpad[3]};
			joypad_d3 <= {powerpad[6], powerpad[10], powerpad[9], powerpad[5], powerpad[8], powerpad[4], powerpad[0], powerpad[1]};
		end
		if (!joypad_clock[0] && last_joypad_clock[0]) begin
			joypad_bits <= {1'b0, joypad_bits[23:1]};
		end
		if (!joypad_clock[1] && last_joypad_clock[1]) begin
			joypad_bits2 <= {1'b0, joypad_bits2[23:1]};
			joypad_d4 <= {~paddle_en, joypad_d4[7:1]};
			joypad_d3 <= {1'b1, joypad_d3[7:1]};
		end
		last_joypad_clock <= joypad_clock;
	end
end

// Loader
wire [7:0] file_input;
wire [7:0] loader_input = (loader_busy && !downloading) ? !nsf ? bios_data : nsf_data : file_input;
wire       loader_clk;
wire [24:0] loader_addr;
wire [7:0] loader_write_data;
reg loader_reset;
wire loader_write;
wire [63:0] loader_flags;
reg  [63:0] mapper_flags;
wire fds = (mapper_flags[7:0] == 8'h14);
wire nsf = (loader_flags[7:0] == 8'h1F);
wire piano = (mapper_flags[30]);
wire [3:0] prg_nvram = mapper_flags[34:31];
wire loader_busy, loader_done, loader_fail;
wire [9:0] ld_prg_mask, ld_chr_mask;
reg  [9:0] prg_mask, chr_mask;
wire [1:0] clearval = status[66:65];
wire [7:0] cleardata = (clearval == 3) ? random_byte : (clearval == 2 ? 8'hFF : 8'h00);

GameLoader loader
(
	.clk              ( clk               ),
	.clearval         ( |clearval         ),
	.cleardata        ( cleardata         ),
	.reset            ( loader_reset      ),
	.downloading      ( downloading       ),
	.filetype         ( {4'b0000, type_nsf, type_fds, type_nes, type_bios} ),
	.is_bios          ( is_bios           ), // boot0 bios
	.indata           ( loader_input      ),
	.indata_clk       ( loader_clk        ),
	.mem_addr         ( loader_addr       ),
	.mem_data         ( loader_write_data ),
	.mem_write        ( loader_write      ),
	.mapper_flags     ( loader_flags      ),
	.prg_mask         ( ld_prg_mask       ),
	.chr_mask         ( ld_chr_mask       ),
	.busy             ( loader_busy       ),
	.done             ( loader_done       ),
	.error            ( loader_fail       ),
	.rom_loaded       ( rom_loaded        )
);

reg auto_info_req;

// Ten channels: each cart download keeps its header's flags and masks; the BIOS's cart select
// picks the channel the NES sees (ROADMAP, Phase 5). A channel never loaded has no mapper.
reg [63:0] slot_flags [10];
reg  [9:0] slot_prgm  [10];
reg  [9:0] slot_chrm  [10];
reg  [9:0] slot_ok = 10'd0;
wire [3:0] act_slot = bios_cart_sel < 4'd10 ? bios_cart_sel : 4'd0;
always @(posedge clk) begin
	if (loader_done && !loader_fail && type_nes) begin
		slot_flags[load_slot] <= loader_flags;
		slot_prgm[load_slot]  <= ld_prg_mask;
		slot_chrm[load_slot]  <= ld_chr_mask;
		slot_ok[load_slot]    <= 1'b1;
	end
	mapper_flags <= slot_ok[act_slot] ? slot_flags[act_slot] : 64'd0;
	prg_mask     <= slot_prgm[act_slot];
	chr_mask     <= slot_chrm[act_slot];
end

// the mapper starts afresh in a newly selected channel
reg [3:0] act_slot_d = 4'd0;
reg [7:0] cart_rst_cnt = 8'd0;
always @(posedge clk) begin
	act_slot_d <= act_slot;
	if (act_slot != act_slot_d) cart_rst_cnt <= 8'hFF;
	else if (cart_rst_cnt != 8'd0) cart_rst_cnt <= cart_rst_cnt - 8'd1;
end

// SDRAM: a 1 MB slot a channel. NES_MiSTer's cart view folds into it: PRG (0x000000) at +0,
// CHR (0x200000) at +256 KB, the RAMs (0x300000-0x3FFFFF, 64 KB windows by bits 19:17) at
// +512 KB. PlayChoice-10 carts are at most 256 KB of PRG and 256 KB of CHR.
function automatic [24:0] slot_addr(input [24:0] a, input [3:0] slot);
	slot_addr = a[21:20] == 2'b10 ? { 1'b0, slot, 2'b01, a[17:0] } :
	            a[21:20] == 2'b11 ? { 1'b0, slot, 1'b1, a[19:17], a[15:0] } :
	                                { 1'b0, slot, 2'b00, a[17:0] };
endfunction

always @(posedge clk) begin
	auto_info_req <= 0;              // the NES core's "No NES 2.0 header" notice: never, here
end

reg led_blink;
always @(posedge clk) begin : blink_block
	int cnt = 0;
	cnt <= cnt + 1;
	if(cnt == 10000000) begin
		cnt <= 0;
		led_blink <= ~led_blink;
	end;
end

wire reset_nes =
	~init_reset_n  ||
	buttons[1]     ||
	arm_reset      ||
	download_reset ||
	loader_fail    ||
	bk_loading     ||
	bk_loading_req ||
	hold_reset     ||
	(old_sys_type != effective_sys_type);

reg [1:0] old_sys_type;
always @(posedge clk) old_sys_type <= effective_sys_type;

wire [17:0] bram_addr;
wire [7:0] bram_din;
wire [7:0] bram_dout;
wire bram_write;
wire bram_en;
wire trigger;
wire light;

wire [1:0] diskside;
reg       diskside_info;
always @(posedge clk) begin
	reg [1:0] old_diskside;

	old_diskside <= diskside;
	diskside_info <= (old_diskside != diskside);
end

wire gg_reset = (type_fds | type_gg | type_nes | type_nsf) && ioctl_download;

// pause
reg       pausecore;
reg [1:0] videopause_ce;
wire      corepaused;
wire      refresh;
wire      sleep_savestate;

assign HDMI_FREEZE = corepaused;

always_ff @(posedge clk) begin
	pausecore <= sleep_savestate | (status[41] && OSD_STATUS && !ioctl_download && !reset_nes);

	if (!corepaused) begin
		videopause_ce <= nes_ce + 1'd1;
	end else begin
		videopause_ce <= videopause_ce + 1'd1;
	end
end

wire nes_hblank, nes_hsync, nes_vsync, nes_vblank;
wire signed [23:0] composite_a, composite_b;

NES nes (
	.clk             (clk),
	.reset_nes       (reset_nes),
	.ppu_rst_behavior(status[64]),
	.cold_reset      (downloading & (type_fds | type_nes)),
	.pausecore       (pausecore),
	.corepaused      (corepaused),
	.pc10_cpu_reset  (bios_game_reset),
	.pc10_cpu_halt   (bios_game_stop),
	.pc10_ppu_reset  (1'b0),          // MAME's PPU reset does nothing (MAME_KLUDGES)
	.pc10_cart_reset (cart_rst_cnt != 8'd0),
	.pc10_ppu_nmi    (ppu_nmi),
	.debug_dots	     (status[69]),
	.sys_type        (effective_sys_type),
	.vs_dip_switches (vs_dip_switches),
	.nes_div         (nes_ce),
	.mapper_flags    (downloading ? 64'd0 : mapper_flags),
	.gg              (status[20]),
	.gg_code         (gg_code),
	.gg_reset        (gg_reset && loader_clk && !ioctl_addr),
	.gg_avail        (gg_avail),
	// Audio
	.sample          (sample),
	.audio_channels  (5'b11111),
	.int_audio       (int_audio),
	.ext_audio       (ext_audio),
	.apu_ce          (apu_ce),
	// Video
	.ex_sprites      (status[25]),
	.color           (color),
	.hsync           (nes_hsync),
	.hblank          (nes_hblank),
	.vsync           (nes_vsync),
	.vblank          (nes_vblank),
	.composite_a     (composite_a),
	.composite_b     (composite_b),
	.emphasis        (emphasis),
	.cycle           (cycle),
	.scanline        (scanline),
	.mask            (hide_overscan[1] ? 2'b00 : status[28:27]),
	.dejitter_timing (status[26] | use_composite), // replacement dots would break the carrier
	// User Input
	.joypad_out      (joypad_out),
	.joypad_clock    (joypad_clock),
	.joypad1_data    (joypad1_data),
	.joypad2_data    (joypad2_data),

	.diskside        (diskside),
	.fds_busy        (fds_busy),
	.fds_eject       (fds_btn),
	.fds_auto_eject  (fds_auto_eject),
	.max_diskside    (max_diskside),
	.fds_fast        (fds_fast),

	// Memory transactions
	.cpumem_addr     (cpu_addr ),
	.cpumem_read     (cpu_read ),
	.cpumem_write    (cpu_write),
	.cpumem_dout     (cpu_dout ),
	.cpumem_din      (cpu_din  ),
	.ppumem_addr     (ppu_addr ),
	.ppumem_read     (ppu_read ),
	.ppumem_write    (ppu_write),
	.ppumem_dout     (ppu_dout ),
	.ppumem_din      (ppu_din  ),
	.refresh         (refresh  ),

	.prg_mask        (prg_mask ),
	.chr_mask        (chr_mask ),

	.bram_addr       (bram_addr),
	.bram_din        (bram_din),
	.bram_dout       (bram_dout),
	.bram_write      (bram_write),
	.bram_override   (bram_en),
	.save_written    (save_written),
	.mapper_has_flashsaves (mapper_has_flashsaves),

	// savestates
	.mapper_has_savestate    (mapper_has_savestate),
	.increaseSSHeaderCount   (!status[44]),
	.save_state              (ss_save),
	.load_state              (ss_load),
	.savestate_number        (ss_slot),
	.sleep_savestate         (sleep_savestate),

	.Savestate_SDRAMAddr     (Savestate_SDRAMAddr     ),
	.Savestate_SDRAMRdEn     (Savestate_SDRAMRdEn     ),
	.Savestate_SDRAMWrEn     (Savestate_SDRAMWrEn     ),
	.Savestate_SDRAMWriteData(Savestate_SDRAMWriteData),
	.Savestate_SDRAMReadData (Savestate_SDRAMReadData ),

	.SaveStateExt_Din        (SaveStateBus_Din),
	.SaveStateExt_Adr        (SaveStateBus_Adr),
	.SaveStateExt_wren       (SaveStateBus_wren),
	.SaveStateExt_rst        (SaveStateBus_rst),
	.SaveStateExt_Dout       (SaveStateBus_Dout),
	.SaveStateExt_load       (savestate_load),

	.SAVE_out_Din            (ss_din),           // data read from savestate
	.SAVE_out_Dout           (ss_dout),          // data written to savestate
	.SAVE_out_Adr            (ss_addr),          // all addresses are DWORD addresses!
	.SAVE_out_rnw            (ss_rnw),           // read = 1, write = 0
	.SAVE_out_ena            (ss_req),           // one cycle high for each action
	.SAVE_out_be             (ss_be),
	.SAVE_out_done           (ss_ack)            // should be one cycle high when write is done or read value is valid
);

wire [24:0] cpu_addr;
wire [21:0] ppu_addr;
wire        cpu_read, cpu_write, ppu_read, ppu_write;
wire  [7:0] cpu_dout, cpu_din, ppu_dout, ppu_din;

wire [2:0] emphasis;

wire [7:0] bios_data;
wire bios_download = downloading & type_bios;
wire bios_write = (loader_write && bios_download && ~bios_loaded);

reg bios_loaded = 0; // Only load bios once
reg last_bios_download = 0;

always @(posedge clk) begin
	last_bios_download <= bios_download;
	if(last_bios_download && ~bios_download) begin
		bios_loaded <= 1;
	end
end

spram #(.addr_width(13)) fds_bios
(
	.clock(clk),
	.address(loader_addr[12:0]),
	.wren(bios_write),
	.data(loader_write_data),
	.q(bios_data)
);

wire [7:0] nsf_data;
spram #(12, 8, "rtl/nes/loopy_NSF.mif") nsfplayrom
(
	.clock(clk),
	.address(loader_addr[11:0]),
	.q(nsf_data)
);

// loader_write -> clock when data available
reg loader_write_mem;
reg [7:0] loader_write_data_mem;
reg [24:0] loader_addr_mem;

reg loader_write_triggered;

always @(posedge clk) begin
	if(loader_write) begin
		loader_write_triggered <= 1'b1;
		loader_addr_mem <= loader_addr;
		loader_write_data_mem <= loader_write_data;
		ioctl_wait <= 1;
	end

	if(nes_ce == 3) begin
		loader_write_mem <= loader_write_triggered;
		if(loader_write_triggered) begin
			loader_write_triggered <= 1'b0;
		end else if(ioctl_wait) begin
			ioctl_wait <= 0;
		end
	end
end

wire [24:0] ch2_addr = sleep_savestate ? Savestate_SDRAMAddr :
                       mapper_has_flashsaves ? {6'b000000, save_addr} : // PRG-ROM
                       {7'b0001111, save_addr[17:0]};                   // CARTRAM
wire        ch2_wr   = sleep_savestate ? Savestate_SDRAMWrEn      : save_wr;
wire  [7:0] ch2_din  = sleep_savestate ? Savestate_SDRAMWriteData : sd_buff_dout;
wire        ch2_rd   = sleep_savestate ? Savestate_SDRAMRdEn      : save_rd;

assign Savestate_SDRAMReadData = save_dout;

sdram sdram
(
	.*,

	// system interface
	.clk        ( clk85           ),
	.init       ( !clock_locked   ),

	// cpu/chipset interface
	.ch0_addr   (  (downloading | loader_busy) ? slot_addr(loader_addr_mem, load_slot) : slot_addr({3'b0, ppu_addr}, act_slot) ),
	.ch0_wr     (                                loader_write_mem      | ppu_write ),
	.ch0_din    (  (downloading | loader_busy) ? loader_write_data_mem : ppu_dout  ),
	.ch0_rd     ( ~(downloading | loader_busy)                         & ppu_read  ),
	.ch0_dout   ( ppu_din   ),
	.ch0_busy   ( ),

	.ch1_addr   ( slot_addr(cpu_addr, act_slot) ),
	.ch1_wr     ( cpu_write ),
	.ch1_din    ( cpu_dout  ),
	.ch1_rd     ( cpu_read  ),
	.ch1_dout   ( cpu_din   ),
	.ch1_busy   ( ),

	// reserved for backup ram save/load
	.ch2_addr   ( slot_addr(ch2_addr, act_slot) ),
	.ch2_wr     ( ch2_wr ),
	.ch2_din    ( ch2_din ),
	.ch2_rd     ( ch2_rd ),
	.ch2_dout   ( save_dout ),
	.ch2_busy   ( save_busy ),

	.refresh    (refresh  ),
	.ss_in      (sdram_ss_in),
	.ss_load    (savestate_load),
	.ss_out     (sdram_ss_out)
);

wire [7:0] save_dout;
assign sd_buff_din = bram_en ? eeprom_dout : save_dout;

wire [7:0] eeprom_dout;
dpram #(" ", 11) eeprom
(
	.clock_a(clk85),
	.address_a(bram_addr),
	.data_a(bram_dout),
	.wren_a(bram_write),
	.q_a(bram_din),

	.clock_b(clk),
	.address_b({sd_lba[1:0],sd_buff_addr}),
	.data_b(sd_buff_dout),
	.wren_b(sd_buff_wr & sd_ack),
	.q_b(eeprom_dout)
);

wire save_busy;
reg save_rd, save_wr;
reg save_wait;
reg [18:0] save_addr;

always @(posedge clk) begin

	if(~save_busy & ~save_rd & ~save_wr) save_wait <= 0;

	if(~bk_busy) begin
		save_addr <= '1;
		save_wait <= 0;
	end
	else if(sd_ack & ~save_busy ) begin
		if(~bk_loading && (save_addr != {sd_lba[9:0], sd_buff_addr})) begin
			save_rd <= 1;
			save_addr <= {sd_lba[9:0], sd_buff_addr};
			save_wait <= 1;
		end
		if(bk_loading && sd_buff_wr) begin
			save_wr <= 1;
			save_addr <= {sd_lba[9:0], sd_buff_addr};
			save_wait <= 1;
		end
	end
	if(~bk_busy | save_busy | bram_en) {save_rd, save_wr} <= 0;
end

reg bk_pending;
wire save_written, mapper_has_flashsaves;
always @(posedge clk) begin
	if ((mapper_flags[25] || vs_system || fds || mapper_has_flashsaves) && ~OSD_STATUS && save_written)
		bk_pending <= 1'b1;
	else if (bk_state)
		bk_pending <= 1'b0;
end

///////////////////////////////////////////////////
// palette loader: MAME's rp2c0x.pal, 3 bits a channel, widened as MAME's pal3bit
function automatic [7:0] pal3bit(input [7:0] v);
	pal3bit = { v[2:0], v[2:0], v[2:1] };
endfunction

reg [23:0] pal_color;
reg [5:0] pal_index;
reg [1:0] pal_count;

wire pal_write = ioctl_download && type_palette ? ~|pal_count : 1'b0;

always @(posedge clk) begin
	if (ioctl_download && loader_clk && type_palette && ioctl_addr < 192) begin
		pal_count <= pal_count == 2 ? 2'd0 : pal_count + 2'd1;
		case (pal_count)
			0: begin
				pal_color[23:16] <= pal3bit(file_input);
				//pal_write <= 0;
				pal_index <= ioctl_addr > 0 ? pal_index + 1'd1 : pal_index;
			end

			1: begin
				pal_color[15:8] <= pal3bit(file_input);
			end

			2: begin
				pal_color[7:0] <= pal3bit(file_input);
				//pal_write <= 1;
			end
		endcase
	end

	if (!ioctl_download) begin
		//pal_write <= 0;
		pal_count <= 0;
		pal_index <= 0;
	end
end

///////////////////////////////////////////////////
wire [2:0] scale = status[3:1];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
assign VGA_SL = sl[1:0];

wire [1:0] reticle;
wire hold_reset;
wire ce_pix;
wire HSync,VSync,HBlank,VBlank;
wire [7:0] R,G,B;

wire [1:0] nes_ce_video = corepaused ? videopause_ce : nes_ce;

video video
(
	.*,
	.clk(clk),
	.reset(reset_nes),
	.cnt(nes_ce_video),
	.sys_type(effective_sys_type),
	.vs_ppu_type(mapper_flags[48:45]),
	.nes_hsync(nes_hsync),
	.nes_hblank(nes_hblank),
	.nes_vsync(nes_vsync),
	.nes_vblank(nes_vblank),
	.hold_reset(hold_reset),
	.count_v(scanline),
	.count_h(cycle),
	// the HDMI layouts take both monitors whole: 240 lines, as MAME's screens (the BIOS
	// display's bottom panel is in lines 224-239)
	.hide_overscan(fb_mode != 3'd0 ? 2'b01 : pal_video && ~|hide_overscan ? 2'b01 : hide_overscan),
	.palette(4'd5),                 // the RP2C03's palette, from the .mra (index 3)
	.rgb_ppu(1'b1),
	.load_color(pal_write && ioctl_download),
	.load_color_data(pal_color),
	.load_color_index(pal_index),
	.emphasis(emphasis),
	.reticle(~status[22] ? reticle : 2'b00),
	.pal_video(pal_video)
);

// The console hands over two composite samples per master clock; CLK_VIDEO
// runs at twice that rate and takes them in turn.
reg comp_toggle = 0;
always @(posedge clk) comp_toggle <= ~comp_toggle;

reg comp_toggle_d;
reg signed [23:0] comp_sample;
always @(posedge CLK_VIDEO) begin
	comp_toggle_d <= comp_toggle;
	comp_sample <= (comp_toggle != comp_toggle_d) ? composite_a : composite_b;
end

// Brightness moves the black point relative to blanking, Q2.13 volts. The
// NES has no pedestal, so a set expecting the NTSC-M 7.5 IRE setup crushes
// its blacks; +11 IRE puts $0D, 80 mV under blanking at the jack, at black.
wire [15:0] comp_brightness = status[85:83] == 3'd1 ? 16'hFE49 : status[85:83] == 3'd2 ? 16'd292 :
	status[85:83] == 3'd3 ? 16'd643 : status[85:83] == 3'd4 ? 16'd936 : 16'd0;

// 2728 samples per line: 227 subcarrier cycles and four samples over.
// Composite receiver: sync, blanking and pixels all come from the waveform.
// The decoded stream is 21.5 MHz pixels on CLK_VIDEO, so the scandoubler and
// HQ2x stay off while it is selected.
wire comp_pix, comp_hs, comp_vs, comp_hb, comp_vb;
wire [7:0] comp_r, comp_g, comp_b;

composite_decoder #(.SPC(12), .HCNT_W(12), .LUMA_LP(6), .PIX_DIV(4)) composite_decoder
(
	.clk(CLK_VIDEO),
	.reset(reset_nes),
	.ce(1'b1),
	.comp(comp_sample),
	.sat(8'd128),
	.hue(8'd0),
	.chroma_trail(composite_premium ? 4'd2 : 4'd3),   // 4 or 8 sample time constant
	.sharpness({status[87:86], 2'b00}),
	.black_stretch(2'd0),
	.brightness(comp_brightness),
	.contrast(16'd2857),   // 0.714 V to white
	.comb_mode(composite_premium ? 2'd2 : 2'd0),
	.ce_out(),
	.pix_out(comp_pix),
	.hs_out(comp_hs),
	.vs_out(comp_vs),
	.hb_out(comp_hb),
	.vb_out(comp_vb),
	.r_out(comp_r),
	.g_out(comp_g),
	.b_out(comp_b)
);

wire comp_hb_c, comp_vb_c;
composite_crop composite_crop
(
	.clk(CLK_VIDEO),
	.pix(comp_pix),
	.hb_in(comp_hb),
	.vb_in(comp_vb),
	.mode(hide_overscan),
	.hb_out(comp_hb_c),
	.vb_out(comp_vb_c)
);

// ---------------------------------------------------------------- PlayChoice-10 BIOS board
// ioctl index 4 (scripts/build_mra.py): 0000-3FFF BIOS ROM, 4000-5FFF the cart's INST ROM,
// 6000-600F its RP5H01 PROM; 8000-DFFF the BIOS characters, E000-E2FF the colour PROMs.
wire        bios_ld    = ioctl_downloading && filetype == PC10_IDX_BIOS && loader_clk;
wire        bios_sdcs, bios_ppu_reset;
wire [10:0] bios_vram_addr;
wire  [7:0] bios_vram_data;

// DIPs: ioctl index 254, SW1 then SW2
reg   [7:0] pc10_sw [2];
always @(posedge clk)
	if (ioctl_downloading && filetype == 8'd254 && loader_clk && !ioctl_addr[24:1])
		pc10_sw[ioctl_addr[0]] <= file_input;

// MAME's vblank_irq comes at the end of the frame (MAME_KLUDGES): the PPU entering line 0
wire bios_vblank = scanline == 9'd0;

// MAME's BIOS port: channel select, enter, reset, (INT DETECT), -, coin 2, service, coin 1
wire [7:0] bios_in = { joyA[8], joyA[11], joyB[8], 1'b0, 1'b0, joyA[12], joyA[9], joyA[10] };

pc10_bios u_bios (
	.clk(clk), .reset(reset_nes), .pause(1'b0), .single(bios_single),
	// .mra index 32 + channel: that channel's INST ROM and RP5H01 PROM
	.cart_ld_we(ioctl_downloading && filetype >= 8'd32 && filetype < 8'd42 && loader_clk),
	.cart_ld_slot(filetype[3:0]), .cart_ld_addr(ioctl_addr[13:0]),
	.ld_we(bios_ld && (!ioctl_addr[15] || ioctl_addr[16])), .ld_addr({ ioctl_addr[16], ioctl_addr[14:0] }),
	.ld_data(file_input),
	.vblank(bios_vblank), .int_detect_set(ppu_nmi),
	.bios_in(bios_in), .sw1(pc10_sw[0]), .sw2(pc10_sw[1]),
	.sdcs(bios_sdcs), .cntrl_mask(bios_cntrl_mask), .disp_mask(bios_disp_mask),
	.sound_mute(bios_sound_mute), .game_reset(bios_game_reset), .game_stop(bios_game_stop),
	.ppu_reset(bios_ppu_reset), .cart_sel(bios_cart_sel), .time_digit_we(), .time_data(),
	.vram_raddr(bios_vram_addr), .vram_rdata(bios_vram_data),
	.z80_running()
);

// The top monitor, on the PPU's raster. hcnt = cycle - 3 puts its columns where MAME's are
// relative to the game's: on the board at cycle - 1 the BIOS display was 2 pixels left of
// MAME's while the game's picture matched MAME's (debug/hw/p2, t03.png and start.png).
pc10_bios_video u_bios_video (
	.clk(clk), .ce_pix(ce_pix),
	.hcnt(cycle < 9'd3 ? cycle + 9'd338 : cycle - 9'd3), .vcnt(scanline == 9'd511 ? 9'd261 : scanline),
	.sdcs(bios_sdcs),
	.vram_addr(bios_vram_addr), .vram_data(bios_vram_data),
	.ld_we(bios_ld && ioctl_addr[15] && !ioctl_addr[16]), .ld_addr(ioctl_addr[14:0]), .ld_data(file_input),
	.r(bios_r_full), .g(bios_g_full), .b(bios_b_full)
);

// The single-monitor BIOS draws its display's top 120 lines only (MAME clips the tilemap to
// half the screen); below, MAME leaves the bitmap as it was and this core shows black (HACKS)
wire [7:0] bios_r_full, bios_g_full, bios_b_full;
wire       bios_cut = bios_single && scanline >= 9'd120 && scanline < 9'd511;
assign bios_r = bios_cut ? 8'd0 : bios_r_full;
assign bios_g = bios_cut ? 8'd0 : bios_g_full;
assign bios_b = bios_cut ? 8'd0 : bios_b_full;

reg single_dm_d = 1'b0;
always @(posedge clk) begin
	single_dm_d <= bios_disp_mask;
	if (reset_nes) single_game <= 1'b0;
	else if (bios_disp_mask && !single_dm_d) single_game <= ~single_game;
end

// ---------------------------------------------------------------- both monitors on HDMI
wire  [7:0] fb_DDRAM_BURSTCNT, fb_DDRAM_BE;
wire [28:0] fb_DDRAM_ADDR;
wire [63:0] fb_DDRAM_DIN;
wire        fb_DDRAM_WE;
assign FB_FORCE_BLANK = 1'b0;

pc10_fb u_fb (
	.clk(clk), .ce_pix(ce_pix), .de(~HBlank & ~VBlank), .vs(VSync),
	.menu_rgb({ bios_r, bios_g, bios_b }), .game_rgb({ R, G, B }), .mode_in(fb_mode),
	.FB_EN(FB_EN), .FB_FORMAT(FB_FORMAT), .FB_WIDTH(FB_WIDTH), .FB_HEIGHT(FB_HEIGHT),
	.FB_BASE(FB_BASE), .FB_STRIDE(FB_STRIDE), .FB_VBL(FB_VBL),
	.DDRAM_BURSTCNT(fb_DDRAM_BURSTCNT), .DDRAM_ADDR(fb_DDRAM_ADDR), .DDRAM_DIN(fb_DDRAM_DIN),
	.DDRAM_BE(fb_DDRAM_BE), .DDRAM_WE(fb_DDRAM_WE)
);

video_mixer #(.LINE_LENGTH(260), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.*,
	.ce_pix(use_composite ? comp_pix : ce_pix),
	.R(use_composite ? comp_r : show_menu ? bios_r : R),
	.G(use_composite ? comp_g : show_menu ? bios_g : G),
	.B(use_composite ? comp_b : show_menu ? bios_b : B),
	.HSync(use_composite ? comp_hs : HSync),
	.VSync(use_composite ? comp_vs : VSync),
	.HBlank(use_composite ? comp_hb_c : HBlank),
	.VBlank(use_composite ? comp_vb_c : VBlank),
	.freeze_sync(),
	.VGA_DE(vga_de),
	.hq2x(scale==1 && !use_composite),
	.scandoubler((scale || forced_scandoubler) && !use_composite)
);

////////////////////////////  CODES  ///////////////////////////////////

reg [128:0] gg_code;
wire gg_avail;

// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

always_ff @(posedge clk) begin
	gg_code[128] <= 1'b0;

	if (ioctl_download & type_gg & loader_clk) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= file_input;  // Flags Bottom Word
			1:  gg_code[119:112] <= file_input;  // Flags Bottom Word
			2:  gg_code[127:120] <= file_input;  // Flags Top Word
			3:  gg_code[127:112] <= file_input;  // Flags Top Word
			4:  gg_code[71:64]   <= file_input;  // Address Bottom Word
			5:  gg_code[79:72]   <= file_input;  // Address Bottom Word
			6:  gg_code[87:80]   <= file_input;  // Address Top Word
			7:  gg_code[95:88]   <= file_input;  // Address Top Word
			8:  gg_code[39:32]   <= file_input;  // Compare Bottom Word
			9:  gg_code[47:40]   <= file_input;  // Compare Bottom Word
			10: gg_code[55:48]   <= file_input;  // Compare top Word
			11: gg_code[63:56]   <= file_input;  // Compare top Word
			12: gg_code[7:0]     <= file_input;  // Replace Bottom Word
			13: gg_code[15:8]    <= file_input;  // Replace Bottom Word
			14: gg_code[23:16]   <= file_input;  // Replace Top Word
			15: begin
				gg_code[31:24]   <= file_input;  // Replace Top Word
				gg_code[128]     <=  1'b1;       // Clock it in
			end
		endcase
	end
end

/////////////////////////  STATE SAVE/LOAD  /////////////////////////////

reg bk_ena = 0;
reg old_downloading = 0;
reg [1:0] max_diskside = 2'd3;
always @(posedge clk) begin
	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;
	if(~bk_ena && loader_write_triggered) max_diskside <= loader_addr_mem[17:16];
end

wire bk_load    = status[6];
wire bk_save    = status[7] | (bk_pending & OSD_STATUS && ~status[50]);
reg  bk_loading = 0;
reg  bk_loading_req = 0;
reg  bk_request = 0;
wire bk_busy = (bk_state == S_COPY);
reg  fds_busy;

wire [10:0] save_sz = vs_system ? 11'd3 :
                      fds ? rom_sz[17:9] :
                      bram_en ? 11'd3 :
                      mapper_has_flashsaves ? (11'd32 << mapper_flags[10:8]) : // 512KB max atm
                      (prg_nvram == 4'd7) ? 11'd15 : 11'd63;

typedef enum bit [1:0] { S_IDLE, S_COPY } mystate;
mystate bk_state = S_IDLE;

always @(posedge clk) begin : save_block
	reg old_load = 0, old_save = 0, old_ack;
	reg old_downloading = 0;

	old_downloading <= downloading;

	old_load <= bk_load & bk_ena;
	old_save <= bk_save & bk_ena;
	old_ack  <= sd_ack;
	fds_busy <= (bk_state != S_IDLE) || bk_request;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if (downloading) begin
		bk_state <= S_IDLE;
		bk_request <= 0;
	end else if(bk_state == S_IDLE) begin
		if((~old_load & bk_load) | (~old_save & bk_save)) begin
			bk_loading <= bk_load;
			bk_request <= 1;
		end
		if(old_downloading & ~downloading & |img_size & bk_ena) begin
			bk_loading <= 1;
			bk_request <= 1;
		end
		if (bk_request && !loader_busy) begin
			bk_request <= 0;
			bk_state <= S_COPY;
			sd_lba <= 0;
			sd_rd <=  bk_loading;
			sd_wr <= ~bk_loading;
		end
	end else begin
		if(old_ack & ~sd_ack) begin
			if(sd_lba == save_sz) begin
				bk_loading <= 0;
				bk_state <= S_IDLE;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	end
end

///////////////////////////// savestates /////////////////////////////////

wire [63:0] ss_dout, ss_din;
wire [27:2] ss_addr;
wire  [7:0] ss_be;
wire        ss_rnw, ss_req, ss_ack;

wire [24:0] Savestate_SDRAMAddr;
wire        Savestate_SDRAMRdEn;
wire        Savestate_SDRAMWrEn;
wire [7:0]  Savestate_SDRAMWriteData;
wire [7:0]  Savestate_SDRAMReadData;

wire [63:0] SaveStateBus_Din;
wire [9:0]  SaveStateBus_Adr;
wire        SaveStateBus_wren;
wire        SaveStateBus_rst;
wire [63:0] SaveStateBus_Dout;
wire        savestate_load;

wire [15:0] sdram_ss_in = SS_Ext[15:0];
wire [15:0] sdram_ss_out;

wire [63:0] SS_Ext;
wire [63:0] SS_Ext_BACK;
eReg_SavestateV #(SSREG_INDEX_EXT, SSREG_DEFAULT_EXT) iREG_SAVESTATE_Ext (clk, SaveStateBus_Din, SaveStateBus_Adr, SaveStateBus_wren, SaveStateBus_rst, SaveStateBus_Dout, SS_Ext_BACK, SS_Ext);

assign SS_Ext_BACK[15: 0] = sdram_ss_out;
assign SS_Ext_BACK[63:16] = 48'b0; // free to be used

// DDR3: the savestates' controller while a state is saved or loaded, else pc10_fb
assign DDRAM_CLK = clk;
wire  [7:0] ss_DDRAM_BURSTCNT, ss_DDRAM_BE;
wire [28:0] ss_DDRAM_ADDR;
wire [63:0] ss_DDRAM_DIN;
wire        ss_DDRAM_RD, ss_DDRAM_WE;
wire        ss_own = sleep_savestate;
assign DDRAM_BURSTCNT = ss_own ? ss_DDRAM_BURSTCNT : fb_DDRAM_BURSTCNT;
assign DDRAM_ADDR     = ss_own ? ss_DDRAM_ADDR     : fb_DDRAM_ADDR;
assign DDRAM_DIN      = ss_own ? ss_DDRAM_DIN      : fb_DDRAM_DIN;
assign DDRAM_BE       = ss_own ? ss_DDRAM_BE       : fb_DDRAM_BE;
assign DDRAM_WE       = ss_own ? ss_DDRAM_WE       : fb_DDRAM_WE;
assign DDRAM_RD       = ss_own & ss_DDRAM_RD;

ddram ddram
(
	.DDRAM_CLK(clk), .DDRAM_BUSY(DDRAM_BUSY), .DDRAM_DOUT(DDRAM_DOUT), .DDRAM_DOUT_READY(DDRAM_DOUT_READY),
	.DDRAM_BURSTCNT(ss_DDRAM_BURSTCNT), .DDRAM_ADDR(ss_DDRAM_ADDR), .DDRAM_RD(ss_DDRAM_RD),
	.DDRAM_DIN(ss_DDRAM_DIN), .DDRAM_BE(ss_DDRAM_BE), .DDRAM_WE(ss_DDRAM_WE),

	.ch1_addr({ss_addr, 1'b0}),
	.ch1_din(ss_din),
	.ch1_dout(ss_dout),
	.ch1_req(ss_req),
	.ch1_rnw(ss_rnw),
	.ch1_be(ss_be),
	.ch1_ready(ss_ack)
);

// saving with keyboard/OSD/gamepad
wire [1:0] ss_slot;
wire [7:0] ss_info;
wire ss_save, ss_load, ss_info_req;
wire mapper_has_savestate;
wire statusUpdate;

//Ignore F1-F4 when famicom keyboard is enabled
wire skip_ps2 = (ps2_key[7:0] == 'h04) || (ps2_key[7:0] == 'h05) || (ps2_key[7:0] == 'h06) || (ps2_key[7:0] == 'h0C);
wire [10:0] ps2_key_adjust = skip_ps2 && fkeyb ? 11'h0 : ps2_key[10:0];

savestate_ui savestate_ui
(
	.clk            (clk           ),
	.ps2_key        (ps2_key_adjust),
	.allow_ss       (rom_loaded & mapper_has_savestate),
	.joySS          (1'b0),
	.joyRight       (joyA_unmod[0] ),
	.joyLeft        (joyA_unmod[1] ),
	.joyDown        (joyA_unmod[2] ),
	.joyUp          (joyA_unmod[3] ),
	.joyStart       (joyA_unmod[7] ),
	.status_slot    (status[46:45] ),
	.OSD_saveload   (status[43:42] ),
	.ss_save        (ss_save       ),
	.ss_load        (ss_load       ),
	.ss_info_req    (ss_info_req   ),
	.ss_info        (ss_info       ),
	.statusUpdate   (statusUpdate  ),
	.selected_slot  (ss_slot       )
);
defparam savestate_ui.INFO_TIMEOUT_BITS = 25;

endmodule


/////////////////////////////////////////////////////////////////////////

// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.
module GameLoader
(
	input         clk,
	input         reset,
	input         downloading,
	input   [7:0] filetype,
	input         is_bios,
	input   [7:0] indata,
	input         indata_clk,
	input         clearval,
	input   [7:0] cleardata,
	output reg [24:0] mem_addr,
	output [7:0]  mem_data,
	output        mem_write,
	output [63:0] mapper_flags,
	output reg [9:0]  prg_mask,
	output reg [9:0]  chr_mask,
	output reg    busy,
	output reg    done,
	output reg    error,
	output reg    rom_loaded
);

initial begin
	rom_loaded <= 0;
end

reg [7:0] prgsize;
reg [3:0] ctr;
reg [7:0] ines[0:15]; // 16 bytes of iNES header
reg [24:0] bytes_left;

wire [7:0] prgrom = ines[4];	// Number of 16384 byte program ROM pages
wire [7:0] chrrom = ines[5];	// Number of 8192 byte character ROM pages (0 indicates CHR RAM)
wire [3:0] chrram = ines[11][3:0]; // NES 2.0 CHR-RAM size shift count (64 << count)
wire has_chr_ram = ~is_nes20 ? (chrrom == 0) : |chrram;

assign mem_data = (state == S_CLEARRAM || (~copybios && state == S_COPYBIOS)) ? (clearval && ~(state == S_COPYBIOS) ? (mapper == 8'd232 ? 8'h00 : cleardata) : 8'h00) : indata;
assign mem_write = (((bytes_left != 0) && (state == S_LOADPRG || state == S_LOADCHR || state == S_LOADEXTRA)
	|| (downloading && (state == S_LOADHEADER || state == S_LOADFDS || state == S_LOADNSFH || state == S_LOADNSFD))) && indata_clk)
	|| ((bytes_left != 0) && ((state == S_CLEARRAM) || (state == S_COPYBIOS) || (state == S_COPYPLAY)) && clearclk == 4'h2);

// detect iNES2.0 compliant header
wire is_nes20 = (ines[7][3:2] == 2'b10);
wire is_nes20_prg = (is_nes20 && (ines[9][3:0] == 4'hF));
wire is_nes20_chr = (is_nes20 && (ines[9][7:4] == 4'hF));

// NES 2.0 PRG & CHR sizes
reg [21:0] prg_size2, chr_size2, chr_ram_size;

function [9:0] mask;
	input [10:0] size;
	integer i;
	begin
		for (i=0;i<10;i=i+1) mask[i] = ( size > (11'd1 << i) );
	end
endfunction

always @(posedge clk) begin
	// PRG
	// ines[4][1:0]: Multiplier, actual value is MM*2+1 (1,3,5,7)
	// ines[4][7:2]: Exponent (2^E), 0-63
	prg_size2 <= is_nes20_prg ? ({19'b0, ines[4][1:0], 1'b1} << ines[4][7:2]) : {prgrom, 14'b0};
	prg_mask <= mask(prg_size2[21:11]);

	// CHR
	chr_size2 <= is_nes20_chr ? ({19'b0, ines[5][1:0], 1'b1} << ines[5][7:2]) : {1'b0, chrrom, 13'b0};
	chr_ram_size <= is_nes20 ? (22'd64 << chrram) : 22'h2000;
	chr_mask <= mask(|chr_size2 ? chr_size2[21:11] : chr_ram_size[21:11]);
end

wire [2:0] prg_size = prgrom <= 1  ? 3'd0 :		// 16KB
	prgrom <= 2  ? 3'd1 : 		// 32KB
	prgrom <= 4  ? 3'd2 : 		// 64KB
	prgrom <= 8  ? 3'd3 : 		// 128KB
	prgrom <= 16 ? 3'd4 : 		// 256KB
	prgrom <= 32 ? 3'd5 : 		// 512KB
	prgrom <= 64 ? 3'd6 : 3'd7;// 1MB/2MB

wire [2:0] chr_size = chrrom <= 1  ? 3'd0 : 		// 8KB
	chrrom <= 2  ? 3'd1 : 		// 16KB
	chrrom <= 4  ? 3'd2 : 		// 32KB
	chrrom <= 8  ? 3'd3 : 		// 64KB
	chrrom <= 16 ? 3'd4 : 		// 128KB
	chrrom <= 32 ? 3'd5 : 		// 256KB
	chrrom <= 64 ? 3'd6 : 3'd7;// 512KB/1MB

// differentiate dirty iNES1.0 headers from proper iNES2.0 ones
wire is_dirty = !is_nes20 && ((ines[9][7:1] != 0)
								  || (ines[10] != 0)
								  || (ines[11] != 0)
								  || (ines[12] != 0)
								  || (ines[13] != 0)
								  || (ines[14] != 0)
								  || (ines[15] != 0));

// Read the mapper number
wire [7:0] mapper = {is_dirty ? 4'b0000 : ines[7][7:4], ines[6][7:4]};
wire [7:0] ines2mapper = {is_nes20 ? ines[8] : 8'h00};
wire [3:0] prgram = {is_nes20 ? ines[10][3:0] : 4'h0};
wire [3:0] prg_nvram = (is_nes20 ? ines[10][7:4] : 4'h0);
wire       piano = is_nes20 && (ines[15][5:0] == 6'h19);
wire       mapper99 = ({ines2mapper[1:0], mapper} == 10'd99);
wire [3:0] vs_hardware_type = (is_nes20 && (ines[7][1:0] == 2'd1)) ? ines[13][7:4] : 4'd0;
wire       mapper99_dual = mapper99 && (vs_hardware_type == 4'd5);
wire       mapper99_raid = mapper99 && (vs_hardware_type == 4'd6);
wire has_saves = ines[6][1];

assign mapper_flags[63:60] = 4'd0;
assign mapper_flags[59:53] = is_nes20 ? ines[15][6:0] : 7'd0; // NES 2.0 default expansion device
assign mapper_flags[52:49] = vs_hardware_type; // Vs. hardware/protection type
assign mapper_flags[48:45] = (is_nes20 && (ines[7][1:0] == 2'd1)) ? ines[13][3:0] : 4'd0; // Vs. PPU type
assign mapper_flags[44:43] = is_nes20 ? ines[7][1:0] : 2'd0; // NES 2.0 console type
assign mapper_flags[42:41] = mapper99 ? chr_size2[14:13] : 2'd0; // Exact 8 KiB CHR sockets for mapper 99
// A normal DualSystem image concatenates the main and sub program sets. This
// single-system core runs the main set at the front of the image. Raid stores
// its four game ROMs first and appends one remote-side handshake ROM.
assign mapper_flags[40:38] = mapper99_dual ? prg_size2[16:14] :
	mapper99_raid ? 3'd4 :
	mapper99 ? prg_size2[15:13] : 3'd0;
assign mapper_flags[37:36] = is_nes20 ? ines[12][1:0] : 2'b00;
assign mapper_flags[35]    = is_nes20;
assign mapper_flags[34:31] = prg_nvram; //NES 2.0 Save RAM shift size (64 << size)
assign mapper_flags[30]    = piano;
assign mapper_flags[29:26] = prgram; //NES 2.0 PRG RAM shift size (64 << size)
assign mapper_flags[25]    = has_saves;
assign mapper_flags[24:17] = ines2mapper; //NES 2.0 submapper
assign mapper_flags[16]    = ines[6][3]; // 4 screen mode
assign mapper_flags[15]    = has_chr_ram;
assign mapper_flags[14]    = ines[6][0]; // mirroring
assign mapper_flags[13:11] = chr_size;
assign mapper_flags[10:8]  = prg_size;
assign mapper_flags[7:0]   = mapper;

reg [3:0] clearclk; //Wait for SDRAM
reg copybios;
reg cleardone;

typedef enum bit [3:0] { S_LOADHEADER, S_LOADPRG, S_LOADCHR, S_LOADEXTRA, S_LOADFDS, S_ERROR, S_CLEARRAM, S_COPYBIOS, S_LOADNSFH, S_LOADNSFD, S_COPYPLAY, S_DONE } mystate;
mystate state;

wire type_bios = filetype[0];
wire type_nes = filetype[1];
wire type_fds = filetype[2];
wire type_nsf = filetype[3];

always @(posedge clk) begin
	if (downloading && (type_fds || type_nes || type_nsf))
		rom_loaded <= 1;

	if (reset) begin
		state <= S_LOADHEADER;
		busy <= 0;
		done <= 0;
		ctr <= 0;
		mem_addr <= type_fds ? 25'b0_0011_1100_0000_0000_0001_0000 :
			type_nsf ? 25'b0_0000_0000_0000_0001_0000_0000   // Address for NSF Header (0x80 bytes)
			: 25'b0_0000_0000_0000_0000_0000_0000;           // Address for FDS : BIOS/PRG
		copybios <= 0;
		cleardone <= 0;
	end else begin
		case(state)
		// Read 16 bytes of ines header
		S_LOADHEADER:
			if (indata_clk) begin
				error <= 0;
				ctr <= ctr + 1'd1;
				mem_addr <= mem_addr + 1'd1;
				ines[ctr] <= indata;
				bytes_left <= prg_size2;
				if (ctr == 4'b1111) begin
					// Check the 'NES' header. Also, we don't support trainers.
					busy <= 1;
					if ((ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2]) begin
						mem_addr <= 0;  // Address for PRG
						state <= S_LOADPRG;
					//FDS
					end else if ((ines[0] == 8'h46) && (ines[1] == 8'h44) && (ines[2] == 8'h53) && (ines[3] == 8'h1A)) begin
						mem_addr <= 25'b0_0011_1100_0000_0000_0001_0000;  // Address for FDS skip Header
						state <= S_LOADFDS;
						bytes_left <= 21'b1;
					end else if (type_bios) begin // Bios
						state <= S_LOADFDS;
						mem_addr <= 25'b0_0000_0000_0000_0000_0001_0000;  // Address for BIOS skip Header
						bytes_left <= 21'b1;
					end else if(type_fds) begin // FDS
						state <= S_LOADFDS;
						mem_addr <= 25'b0_0011_1100_0000_0000_0010_0000;  // Address for FDS no Header
						bytes_left <= 21'b1;
					end else if(type_nsf) begin // NFS
						state <= S_LOADNSFH;
						//mem_addr <= 22'b00_0000_0000_0001_0001_0000;  // Just keep copying
						bytes_left <= 21'h70; // Rest of header
					end else begin
						state <= S_ERROR;
					end
				end
			end
		S_LOADPRG, S_LOADCHR: begin // Read the next |bytes_left| bytes into |mem_addr|
			// Abort when downloading stops and there are bytes left (invalid header)
			if (downloading && bytes_left != 0) begin
				if (indata_clk) begin
				  bytes_left <= bytes_left - 1'd1;
				  mem_addr <= mem_addr + 1'd1;
				end
			end else if (state == S_LOADPRG) begin
				state <= S_LOADCHR;
				mem_addr <= 25'b0_0010_0000_0000_0000_0000_0000; // Address for CHR
				bytes_left <= chr_size2;
			end else if (state == S_LOADCHR) begin
				state <= S_LOADEXTRA;
				mem_addr <= 25'b1_0000_0000_0000_0000_0000_0000; // Address for Extra
				//Replace with calculation based on file size requires actual file size?
				bytes_left <= ({ines2mapper[1:0],mapper} == 10'd413) ? 25'b0_1000_0000_0000_0000_0000_0000 : 25'd0;
			end
		end
		S_LOADEXTRA: begin
			if (downloading &&  bytes_left != 0) begin
				if (indata_clk) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			end else if (mapper == 8'd232) begin
				mem_addr <= 25'b0_0011_1000_0000_0111_1111_1110; // Quattro - Clear these two RAM address to restart game menu
				bytes_left <= 21'h2;
				state <= S_CLEARRAM;
				clearclk <= 4'h0;
				cleardone <= 1;
			end else if (clearval) begin
				mem_addr <= 25'b0_0011_0000_0000_0000_0000_0000;
				bytes_left <= 21'hF_FFFF;
				state <= S_CLEARRAM;
				clearclk <= 4'h0;
				cleardone <= 1;
			end else begin
				done <= 1;
				busy <= 0;
			end
		end
		S_ERROR: begin
				done <= 1;
				error <= 1;
				busy <= 0;
		end
		S_LOADFDS: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (downloading) begin
				if (indata_clk) begin
					mem_addr <= mem_addr + 1'd1;
				end
			end else begin
//				mem_addr <= 25'b0_0011_1000_0000_0000_0000_0000;
//				bytes_left <= 21'h800;
				mem_addr <= 25'b0_0011_1000_0000_0001_0000_0010; // FDS - Clear these two RAM addresses to restart BIOS
				bytes_left <= 21'h2;
				ines[4] <= 8'h80;//no masking
				ines[5] <= 8'h00;//0x2000
				ines[6] <= 8'h40;
				ines[7] <= 8'h10;
				ines[8] <= 8'h00;
				ines[9] <= 8'h00;
				ines[10] <= 8'h00;
				ines[11] <= 8'h00;
				ines[12] <= 8'h00;
				ines[13] <= 8'h00;
				ines[14] <= 8'h00;
				ines[15] <= 8'h00;
				state <= S_CLEARRAM;
				clearclk <= 4'h0;
				copybios <= ~is_bios; // Don't copybios for bootrom0
			end
		end
		S_CLEARRAM: begin // Read the next |bytes_left| bytes into |mem_addr|
			clearclk <= clearclk + 4'h1;
			if (bytes_left != 21'h0) begin
				if (clearclk == 4'hF) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			end else if (!cleardone) begin
				mem_addr <= 25'b0_0000_0000_0000_0000_0000_0000;
				bytes_left <= 21'h2000;
				state <= S_COPYBIOS;
				clearclk <= 4'h0;
			end else begin
				state <= S_DONE;
			end
		end
		S_COPYBIOS: begin // Read the next |bytes_left| bytes into |mem_addr|
			clearclk <= clearclk + 4'h1;
			if (bytes_left != 21'h0) begin
				if (clearclk == 4'hF) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			 end else begin
				state <= S_DONE;
			end
		end
		S_LOADNSFH: begin // Read the next |bytes_left| bytes into |mem_addr|
			if (bytes_left != 0) begin
				if (indata_clk) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			end else begin
				state <= S_LOADNSFD;
				//mem_addr <= {25'b0_0001_0000_0000_0000_0000_0000; // Address for NSF Data
				mem_addr <= {13'b0_0001_0000_0000,ines[9][3:0],ines[8]};//_0000_0000_0000; // Address for NSF Data
				bytes_left <= 21'b1;
			end
		end
		S_LOADNSFD: begin // Read the next |bytes_left| bytes into |mem_addr|
			if (downloading) begin
				if (indata_clk) begin
					mem_addr <= mem_addr + 1'd1;
				end
			end else begin
				mem_addr <= 25'b0_0000_0000_0000_0001_1000_0000; // Address for NSF Player (0x180)
				bytes_left <= 21'h0E80;
				ines[4] <= 8'h80;//no masking
				ines[5] <= 8'h00;//no CHR ROM
				ines[6] <= 8'hF0;//Use Mapper 31
				ines[7] <= 8'h18;//Use NES 2.0
				ines[8] <= 8'hF0;//Use Submapper 15
				ines[9] <= 8'h00;
				ines[10] <= 8'h00;
				ines[11] <= 8'h07;//NES 2.0 8KB CHR RAM
				ines[12] <= 8'h00;
				ines[13] <= 8'h00;
				ines[14] <= 8'h00;
				ines[15] <= 8'h19;//miracle piano; controllers swapped
				state <= S_COPYPLAY;
				clearclk <= 4'h0;
			end
		end
		S_COPYPLAY: begin // Read the next |bytes_left| bytes into |mem_addr|
			clearclk <= clearclk + 4'h1;
			if (bytes_left != 21'h0) begin
				if (clearclk == 4'hF) begin
					bytes_left <= bytes_left - 1'd1;
					mem_addr <= mem_addr + 1'd1;
				end
			end else begin
				state <= S_DONE;
			end
		end
		S_DONE: begin // Read the next |bytes_left| bytes into |mem_addr|
			done <= 1;
			busy <= 0;
		end
		endcase
	end
end
endmodule
