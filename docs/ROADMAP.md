# Nintendo PlayChoice-10 — MiSTer Core Roadmap

**Approved, including keeping NES_MiSTer's 21.477 / 42.95 / 85.9 MHz clock tree. A phase whose scope
changes goes back for approval.**

## Context

Goal: a DE10-nano MiSTer core for the PlayChoice-10, emulated by MAME's
`src/mame/nintendo/playch10.cpp` with the `ppu2c0x`, `rp2a03`/`nes_apu`, `rp5h01` and `z80`
devices — a Quartus 17.0.2 SystemVerilog project producing one `.rbf` and a `.mra` per set.

The game side of the board is an NES, and MiSTer-devel/NES_MiSTer already implements it: the
RP2A03 (T65), the APU, the PPU including the RGB PPUs' differences, and every mapper the
PlayChoice carts use but one. That core is the basis. What is new work:

1. **The BIOS board**: a Z80 (T80) with its ROM, RAM, VRAM, two LS259 latches, NMI and
   watchdog, and the control lines into the NES (reset, halt, PPU reset, control, display and
   sound masks, INT DETECT).
2. **The BIOS display**: a 32 x 32 character map, 3 bpp, colour PROMs. Written from MAME; small.
3. **The RP5H01** security PROM: written from MAME's 192-line model.
4. **Two monitors on one MiSTer**: the KonamiGX Type 3/4 approach — an HDMI framebuffer in DDR3
   showing either monitor, both stacked as in the cabinet, side by side, or the stack turned for
   a panel on its side; the analog output carries one monitor.
5. **Cart configuration from the `.mra`**: each set's board type becomes a synthetic iNES header
   in front of its PRG and CHR, so the NES core's loader and mapper selection run unchanged.
   Board C (The Goonies) has no NES mapper equivalent and gets one.
6. **The RGB palette**: MAME's `rp2c0x.pal` and the RGB PPU's emphasis (a channel forced full,
   not attenuated), in place of the NES core's composite palettes.

Hardware facts with sources are in [`HARDWARE_NOTES.md`](HARDWARE_NOTES.md). Cross-cutting
findings from previous cores are in [`LESSONS_LEARNED.md`](LESSONS_LEARNED.md); working practice
in [`WORKFLOW.md`](WORKFLOW.md).

## Progress

**Phases 0 and 1 are done. Phase 2: pc_smb and pc_smb3 go through the BIOS menu and play on the
board with MAME's colours; sound is not yet judged, and the 60 Hz question is open.**

- Build `c777529` (`PlayChoice10_30000003.rbf`, +2.253 ns, 168 M10K), screenshots in
  `debug/hw/p2c/`, native, compared with MAME (rows offset by the 8 lines Overscan Normal crops):
  - the BIOS menu: 0 pixels differ from MAME's frame 600 in rows 0-207 (`menu.png`; rows
    208-223 are an animated panel);
  - pc_smb's title, through coin and Enter: 24 of 57,344 pixels differ, all in the colour-cycling
    coin icon (`title.png` against MAME's frame 2400): the RP2C03 palette and the picture match;
  - pc_smb3 (MMC3): title rows 0-96 identical to MAME's frames 2400 and 3000, differences only
    where sprites and the menu move (`smb3_b.png`); Start reaches the World 1 map with the
    status-bar split (`smb3_c.png`).
- Earlier on `5257072`: coins register (TIME 900 after three), Enter hands over to the game,
  Start begins pc_smb's World 1-1 with the timer running (`debug/hw/p2/play.png`).
- Decided: the PPU's real 60.0988 Hz, not MAME's 60.000 Hz (user; MAME_KLUDGES).
- Phase 3: `pc10_fb` puts both monitors on HDMI (Stacked, the default; Side by side; Rotated
  CW/CCW), all 114,688 pixels right in each layout in `sim/pc10_fb_tb`; both at 240 lines; the
  CRT keeps one (Auto, Game, Menu). The single-monitor BIOS is an OSD option. The user saw both
  screens on the board. The MiSTer's own screenshot does not capture the framebuffer.
- Phase 5 (ten channels) in: `.mra` indices 15+n / 31+n, a 1 MB SDRAM slot a channel; the
  three-channel cabinet works on the board (user). pc_smb's 4,000,000 boot accesses still equal
  MAME's.
- All 56 sets have an `.mra` (`build_mra.py --all`, all validating, setname `playch10` so the
  core has one CFG); board C (The Goonies) is mapper 87. Build `9256699`+: +1.943 ns, 83% ALMs,
  42% DSP after the composite path and the scaler's adaptive filter went (timing).
- Phase 4, part: build `0715d37` (+2.063 ns, 84% ALMs, 251 M10K) gives the gun sets an NES 2.0
  header with expansion device 0x08, which turns NES_MiSTer's Zapper on for their channel, its
  trigger masked by CNTRLMASK (`pc10_in1_r`); CRT Adjust on the analog path; NES_MiSTer's
  NES-only OSD entries removed. Deployed, not checked on the board.
- `28cd4c0` (+1.912 ns, 83% ALMs, 251 M10K, deployed): `rtl/pc10_gun.sv` aims the gun in place of the Zapper's aim (its light sensing and
  trigger timing kept): the mouse, the left stick and the d-pad together; a crosshair on both
  outputs, only while a gun set runs. On the board (build `28cd4c0`), Duck Hunt starts, the
  crosshair draws and follows the aim, and ducks are hit; the user played it and reports it works well (`debug/hw/gun/s1.png`, `s3.png`:
  score 1,000 then 2,000). `sim/pc10_gun_tb`: 20 checks pass.
- `72d1dff` (+1.903 ns): NES_MiSTer's MMC2 had no RAM at 0x6000, where PlayChoice-10
  Punch-Out!! keeps its leaderboard (NES_MiSTer issue 390); it now maps 8 KB there when the
  header has a battery. On the board the game gets past the leaderboard after Glass Joe (user).
- Open in Phase 2: sound, by ear (the APU is NES_MiSTer's; SOUNDMASK mutes it).
- Phase 1, `rtl/bios/`: the Z80 (T80 from BallySente), map, LS259 latches, NMI and watchdog,
  INT DETECT, RP5H01, and the BIOS display. `sim/bios_boot_tb` from reset on pc_smb: 8,393,343 Z80
  accesses identical to MAME's (`scripts/mame_boot_trace.py`, 600 frames, through the channel
  menu; 294,692 of them RP5H01 accesses in the first 4M), and all 2,085,200 instructions of MAME's
  debugger trace over the first 4 s start on the same cycle (`scripts/compare_cycles.py`). The
  bench reproduces MAME's NMI rule (end of frame, `MAME_KLUDGES.md`; taken one cycle early, as
  MAME's scheduler does) and replays MAME's INT DETECT in place of the NES.
- BIOS display: `scripts/bios_model.py` is pixel-identical to MAME's top screen on pc_smb frames
  120, 300, 600, 1200, 1800, 2400 and 3600 (four distinct screens); `pc10_bios_video.sv` is
  pixel-identical to the model on the same seven in `sim/bios_video_tb` (ModelSim, not Verilator).
- Not in Phase 1: the BIOS board is not yet in `PlayChoice10.sv`, and nothing of it has been on
  the board.

- `c8f6c9b` imports NES_MiSTer `49a0a66` (`rtl/nes/PROVENANCE.md`). `build_mra.py` writes the
  pc_smb `.mra` (synthetic iNES header, then `prg` and `gfx2`); `mra.py` builds its image, equal
  to the zip's `u1sm` and `u2sm` after the header.
- Staged build of `328cfbf`, release revision, seed 1: 32,001 / 41,910 ALMs (76%), 112 / 553
  M10K (20%), 94 / 112 DSP (84%), worst `clk_sys` setup +1.950 ns, no negative slack
  (`debug/debug_build_p0.log`). Deployed as `PlayChoice10_30000001.rbf` with the pc_smb `.mra` in
  `_PlayChoice10/_dev`. On the board, pc_smb runs its title and its attract demo, which loops
  back to the title (`debug/hw/p0/smb_title.png`, `debug/hw/p0/burst_sheet.png`, ten native
  shots). MAME, through the BIOS, shows the title then the demo about 10 s later. The board
  needed `pc_smb.zip` and `playch10.zip` in `/media/fat/games/mame`; without them the `.mra`
  loads nothing and the screen is NES colour $00 (`debug/hw/p0/smb_t20.png`).

## Game scope

All 56 sets (55 games and pc_grdue), by board, are in HARDWARE_NOTES "Sets". MAME marks 9
`MACHINE_IMPERFECT_GRAPHICS`, the rest working.

### Scope decision

- **In scope:** every set. One BIOS, one NES, one RP5H01 slot; the largest cart is 512 KB.
- **BIOS:** `dual` (MAME's default) primary; `single` as an OSD choice, both ROMs loaded by every
  `.mra` (16 KB each). `alt` and `dualb` are marked bad in MAME and left out; `singleb` with
  `single` if it costs nothing.
- **First target:** pc_smb — NROM, the smallest board, the most-documented game.
- **Second target:** pc_smb3 — MMC3 with its scanline IRQ, the largest common board.
- **Then one per board:** pc_grdus (A), pc_cntra (B), pc_goons (C), pc_mtoid (D2), pc_miket (E),
  pc_ngaid (F), pc_gntlt (G four-screen), pc_pinbt (H), pc_sjetm (I), pc_moglf (K), pc_duckh (gun).

## Hardware reality (from the driver, not assumption)

Details and line numbers: [`HARDWARE_NOTES.md`](HARDWARE_NOTES.md).

### Chips

Z80 4 MHz; RP2A03 at 21.477272 MHz / 12; RP2C03B PPU; RP5H01; two 74LS259; BIOS character
display with three 82S129 colour PROMs.

### Clocks

Board: 21.477272 MHz NES master (CPU /12, PPU /4), 8 MHz for the Z80 (/2). Pixel clock
5.369318 MHz on both monitors.

**Proposed: keep NES_MiSTer's clock tree, which departs from the ~48 MHz default.**

| Clock | Value | Relation |
|---|---|---|
| `clk` (NES core system clock) | 21.477272 MHz | master; pixel = 1 in 4 (`nes_ce`) |
| `CLK_VIDEO` | 42.954544 MHz | 2 x master, 8 x pixel |
| SDRAM | 85.909088 MHz | 4 x master |
| Z80 4 MHz | from `clk`, Bresenham 88/945 x 2 = 176/945 | exact (21.477272 MHz = 6 x 315/88 MHz) |

The default would be `clk_sys` 42.954544 MHz (8 x pixel) with the SDRAM on it. That means
adding a clock enable through all of NES_MiSTer and reworking its SDRAM timing, which assumes
four SDRAM clocks per master clock and two accesses per CPU cycle. The NES core is shipped and
in wide use at 21.477/85.9 MHz; changing its clocking for this core's sake rewrites the part
that works. This is the decision the user is asked to make (see Open items).

### Interrupts

Z80: NMI at the top monitor's vblank when NMI enable is set; with NMI enable and DOG DI both
clear, the same edge resets the Z80 (watchdog) (`vblank_irq`, 1886-1896). RP2A03: NMI from the
PPU, IRQ from the APU and from MMC3 (G, H boards).

### Memory map

As HARDWARE_NOTES. The NES side is NES_MiSTer's; the Z80 side is new.

### Video

Two 256 x 240 monitors at the same timing, both live every frame (dual BIOS). Bottom: the PPU.
Top: the BIOS character map. Single BIOS: one monitor, switched by DISPMASK.

### Sound

The APU, mono, muted by SOUNDMASK. In NES_MiSTer.

### Protection

RP5H01 per cart, slot 0 only, as MAME.

### Per-game configuration

The `.mra` mod byte: board type, mirroring, gun, four-screen; the synthetic iNES header carries
the mapper, PRG/CHR sizes, CHR RAM and PRG RAM/NVRAM. MAME's per-board differences from the
NES mappers (A writes only 0x8000-0x8FFF; C at 0x6000; MMC3 IRQ per `gboard_scanline_cb`) are
checked per board against the NES core's mapper and logged where they differ.

## Component reuse map

| block | plan | source |
|---|---|---|
| RP2A03 CPU, DMA, APU, PPU, mappers, SDRAM controller, game loader, savestates | Port NES_MiSTer, cart and video paths adapted | github.com/MiSTer-devel/NES_MiSTer `49a0a66`, GPL-3.0 (`COPYING`); cloned at `E:/refs/NES_MiSTer` |
| Zapper (mouse/stick to light gun, reticle) | NES_MiSTer `rtl/zapper.sv` | as above |
| Z80 | T80, from a sibling core's proven copy (Psikyo, Fuuki or MS32) | BSD-style |
| RP5H01 | Written from MAME's model (`rp5h01.cpp`, 192 lines) | MAME, BSD-3-Clause, as reference |
| BIOS character display and PROM palette | Written from `playch10.cpp` 521-620 | MAME, as reference |
| HDMI dual-monitor framebuffer | Adapted from KonamiGX `rtl/video/gx_t34_fb.sv` (itself after Sorgelig's `screen_rotate_two`): two simultaneous streams in place of alternate frames | Arcade-KonamiGX_MiSTer, GPL-3.0-or-later |
| HDMI rotation and flip, single monitor | `screen_rotate_two.sv` | KonamiGX copy, GPL-2.0 |
| CRT Adjust | rmonic79 `crt_adjust.sv` via a sibling core | GPL-3.0-or-later |
| Hiscore | JimmyStones `hiscore.v` | GPL-3.0; whether hiscore.dat covers `pc_*` is to be checked |
| Pause | Fuuki `pause_control.sv`, plus NES_MiSTer's own `pausecore` | project's |
| Fast DDR3 ROM loading | Not planned: 0.5 MB loads in well under a second over ioctl | - |

## On-chip RAM budget

The import uses 112 of 553 M10K (Phase 0 build). To add: Z80 ROM 2 x 16 KB + INST 8 KB, BIOS
characters 24 KB, PROMs, Z80 RAM 4 KB and VRAM 2 KB — about 80 KB, roughly 70 M10K blocks. The
HDMI framebuffer is in DDR3. One to watch: NES_MiSTer's palette and composite blocks, which this
core can drop.

## Memory plan

- **SDRAM** (32 MB module; any module): NES_MiSTer's layout — PRG, CHR, CHR RAM, work RAM, cart
  RAM and NVRAM, three channels (PPU, CPU, saves). The cart image is under 0.6 MB.
- **BRAM**: everything on the BIOS board.
- **DDR3 during play**: the HDMI framebuffer only, at 0x24000000 as the rotator. That is the
  standard rotator traffic, plus one frame of the second monitor; no ROM or game data.

## Design decisions

**Follow MAME, including where MAME is wrong, and write down every place that is.** Each goes in
`docs/MAME_KLUDGES.md` when it is implemented.

**Where NES_MiSTer and MAME disagree on the NES side, record it and keep NES_MiSTer.** It is
verified against hardware test ROMs; MAME's PPU follows its screen's timing. Disagreements go in
`docs/MAME_KLUDGES.md` with the evidence.

**Every approximation of this core's own goes in `docs/HACKS.md`** in the commit it lands.

**One `.rbf` for all games.** Per-set differences are the `.mra` mod byte and the synthetic iNES
header.

**Two Quartus revisions, `PlayChoice10_stp` and `PlayChoice10`,** differing only by `DEBUG_ISSP`.

**Licence: GPL-3.0-or-later**, which NES_MiSTer's GPL-3.0 requires. `sys/` is never edited.

**Per-scanline rendering, no frame buffer in the game path.** The PPU renders as the chip did.
The BIOS display reads VRAM live, as MAME does (no snapshot); the video-write sweep of Z80 VRAM
confirms or refutes that before the display is written.

**No multiplies or divides** in the new video or glue (WORKFLOW §14).

**Both monitors come from one raster.** MAME's two screens have identical timing; the BIOS
display is generated from the PPU's counters, so the two pictures arrive pixel for pixel together.

**The dual-monitor output follows KonamiGX Type 3/4.** HDMI: *Screen (HDMI)* — Game, Menu,
Stacked (menu above game, as the cabinet: 2:3), Side by side (8:3, for 16:9 panels), Stacked
CW and Stacked CCW (the stack turned 90 degrees for a panel on its side: 3:2). Analog: *Screen
(CRT)* — Game or Menu, a plain select because both pictures are live every frame (no frame hold,
unlike GX). Under the single BIOS both options are hidden: there is one picture.

**Aspect is 4:3 per monitor**, multiplied out for the combined layouts as above.

**Flip screen.** The board has none. A fake DIP and the OSD drive one flip: on HDMI the
framebuffer writes the picture turned 180 degrees; on analog the picture is read back turned from
the stored frame, one frame late. Verified against the unflipped frame rotated 180 degrees. If
the analog path costs too much, analog stays unflipped, in `docs/HACKS.md` and the README.

## Pitfalls that already bind decisions here

| Entry | What it binds here |
|---|---|
| "Suspect your own integration before any vendored module" | NES_MiSTer is the vendored module: faults are assumed to be in the BIOS board and glue first |
| "Copy from the sibling core that last proved the module" | T80 and the framebuffer modules come from siblings, not upstream |
| ROM loading: `.mra`, byte order | the synthetic iNES header and the mod byte are generated and validated, never hand-written |
| "Read the framework's source instead of inferring its behaviour" | DIPs arrive as ioctl index 254; NES_MiSTer reads file types by index, which the `.mra` must match |

## Phased roadmap

**Phase 0 — Import and the measurements. The gate.**

NES_MiSTer imported under `rtl/nes/` with `PROVENANCE.md`, its top-level logic folded into
`PlayChoice10.sv`, running a cart with no BIOS: the `.mra` loads pc_smb's PRG and CHR behind a
synthetic header. Exit criteria:

1. **The imported core builds unchanged** and pc_smb runs to its title and attract on the board
   with the NES held out of the BIOS's control. — Met: see Progress.
2. **Fit and timing of the import**: ALMs, M10K, slack per clock, from `build_staged.py`. — Met:
   see Progress. DSP is the resource to watch (84%).
3. **The clock decision taken** (Open items). — Met: NES_MiSTer's clock tree kept (approval).
4. **The video-write sweep of Z80 VRAM**, attract and in play (`--coin`), every BIOS, recorded in
   `docs/write_timing_mame.txt`. — Met for the dual and single BIOS on pc_smb: 0.0-4.9 writes a
   frame, and MAME accepts them only while SDCS blanks the display, so the display reads VRAM
   live with no snapshot.
5. **MAME's CPU-to-PPU timing measured** (cart CPU cycles per frame in MAME against 29780.67) to
   size the 60 Hz question. — Met: MAME runs pc_smb at 60.000000 Hz (600 frames in 10.000000 s of
   emulated time, Lua on `:bottom`). With the cart CPU at 21.477272 MHz / 12 that is 29,829.5 CPU
   cycles a frame against the PPU's 29,780.67: MAME's frame is 0.164% long.

**Phase 1 — The BIOS board, in simulation.**

T80, the Z80 map and latches, RP5H01, NMI and watchdog, the BIOS display and PROM palette.
Exit: the Z80's bus trace equals MAME's from reset through the menu (`scripts/mame_boot_trace.py`),
the RP5H01 key read matches, and the top monitor's frame equals MAME's for captured scenes in
Verilator, with the NES stubbed to MAME's INT DETECT behaviour. — Met (Progress); the display
bench runs in ModelSim.

**Phase 2 — The board together, and the first games.**

The Z80 controls the NES (GAMERES, GAMESTOP, PPU reset, masks, INT DETECT, cart select), inputs
through CNTRLMASK, the RGB palette and emphasis, the `.mra` generator with headers, mod byte,
DIPs (comments skipped) and `<mameversion>`. Exit: pc_smb and pc_smb3 take a coin, start from
the menu and play on a DE10-nano with sound, judged by ear, the game on HDMI.

**Phase 3 — Two monitors.**

The dual-stream framebuffer, *Screen (HDMI)* and *Screen (CRT)*, aspect per layout, the single
BIOS, flip. Exit: every layout on HDMI and both analog selections on the board, screenshots
against MAME's two screens.

**Phase 4 — Every board, and the standard features.**

The remaining boards, board C's mapper, four-screen, TQROM, the Zapper with mouse and synthetic
crosshair (OSD shown for gun sets only), Pause suspending both CPUs, CRT Adjust, hiscore if
covered, audio, HDMI rotation for single-monitor layouts, real button names, one `.mra` per game
with clones under `_alternatives`. Exit: every set boots, takes a coin and plays on the board.

**Phase 5 — Ten channels: any carts in any channel, from the `.mra`. Requested by the user;
beyond MAME, which supports slot 0 only.**

The board holds up to ten carts behind the BIOS's cart select (CSEL0-3, `pc10_bios.cart_sel`);
each cart carries its own PRG and CHR, its board type, its INST ROM (the Z80's C000-DFFF) and
its RP5H01. Design:

- **`.mra`:** a `<rom>` block per channel, ioctl index 16 + channel (16-25), each with its own
  `zip`: a 16-byte iNES header (the board type, as now), the INST ROM, the RP5H01 PROM, PRG,
  CHR. A custom cabinet is a list of channel blocks, written by hand or by
  `scripts/build_mra.py --cabinet "<name>" <set> ...`; a single-game `.mra` is channel 1 alone.
  The BIOS-board block (index 4) and the palette (index 3) are shared.
- **SDRAM:** a 1 MB slot a channel. NES_MiSTer's 4 MB cart view (PRG from 0x000000, CHR from
  0x200000, RAMs from 0x300000) is folded into it: PlayChoice-10 carts are at most 256 KB of PRG
  and 256 KB of CHR. Ten slots in the 32 MB module.
- **Switching:** per channel, the loader's header becomes that slot's mapper flags and masks;
  CSEL picks the slot for the NES side (SDRAM base, flags, masks) and for the Z80 side (INST ROM
  and RP5H01, in block RAM: about 70 M10K for ten). The BIOS holds the NES in reset across a
  change; the mapper state is reset with it.
- **Verification:** no MAME reference exists for more than one cart. The BIOS's own menu (it
  reads each cart's INST ROM for the titles) and each game starting from its channel are the
  check, on the board.

Exit: a three-channel `.mra` (pc_smb, pc_smb3, pc_mtoid) lists all three in the menu, and each
starts and plays from its channel on the board.

**Phase 6 — Savestates, state dumps and cheats.** NES_MiSTer has savestates; extending them to
the BIOS board (Z80 state through T80's register port, BRAMs, latches, RP5H01 counter) is the
work. `docs/STATE.md` is kept from Phase 1.

## Verification strategy

- MAME drives the references: Z80 boot traces, VRAM and register dumps at known frames, both
  screens' snapshots.
- The NES side's regression is NES_MiSTer's own behaviour on the same carts before and after
  the import.
- The BIOS display is checked against a model of `playch10.cpp`'s tilemap before RTL.
- `.mra` files are generated and re-read against `ROM_START`; `validate_mra.py` gates them.

## Repository setup

Seeded from MiSTer-devel/Template_MiSTer, `Template.*` renamed to `PlayChoice10.*`, the
`PlayChoice10_stp` revision added, the Quartus 13 project dropped (`bef264c`). Quartus 17.0.2.

## Open items

**The clock plan.** Keep NES_MiSTer's 21.477 / 42.95 / 85.9 MHz (proposed), or move to
`clk_sys` 42.95 MHz with the SDRAM on it as the standing rule asks. Needs the user's decision
before Phase 0 ends.

**MAME's 60 Hz against the PPU's 60.0988 Hz.** MAME's screens are declared at 60 Hz and its PPU
timing follows them. The proposal is the PPU's real timing, NES_MiSTer's, logged in
`MAME_KLUDGES.md` as a place the core does not follow MAME. Measured: MAME gives 29,829.5 cart CPU
cycles a frame, 49 more than the PPU's 29,780.67 (0.164%). A decision for Phase 2, when the BIOS
and the NES first run together.

**Whether the BIOS display is slaved to the PPU raster.** Assumed (above); a schematic or PCB
measurement would close it.

**The RP2A03E against MAME's RP2A03G.** MAME notes the board has the E; NES_MiSTer models a later
revision. Differences are in the APU and are checked by ear.

**MAME files.** The research used `playch10.cpp`, `ppu2c0x.cpp/.h`, `rp5h01.cpp/.h`, `rp2a03`
and `nes_apu`. Confirm nothing else is in scope.

## Next steps

1. Phase 2: the BIOS board in `PlayChoice10.sv` driving the NES (GAMERES, GAMESTOP, PPU reset,
   masks, INT DETECT from the PPU's NMI), its vblank edge at the PPU's frame end, the BIOS ROMs
   and the security PROM in the `.mra`, the top monitor on the video output for a first look.
