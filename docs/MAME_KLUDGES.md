# MAME kludges this core reproduces

This project follows MAME, including where MAME is wrong (ROADMAP, "Design decisions"), so the
software model and the RTL reproduce MAME's guesses on purpose. This file lists each one that
touches an in-scope set: where it is in MAME, what the core does, and what would settle the real
behaviour.

It also records where a vendored, silicon-derived module disagrees with MAME and the module was
kept (ROADMAP, "Where a vendored module and MAME disagree").

This core's own approximations are not here; they are in `HACKS.md`.

Source references are to `src/mame/nintendo/playch10.cpp` unless named. MAME commit:
`dedb5227403` (`mame0289-1527`).

9 of the 56 sets are `MACHINE_IMPERFECT_GRAPHICS`; the rest have no flags.

**Core column:** *copies* MAME; *differs* (and why); *n/a* (not in the core's scope);
*not checked*.

## Video

| Kludge | MAME | Core | Would settle it |
|---|---|---|---|
| BIOS display while SDCS: pen 0 | `593-605`, `sdcs_w` 729-738: the top screen is filled with pen 0 while the Z80 owns VRAM; MAME's own comment says SDCS "drives character and color code to 0", which would show character 0 in colour 0. Character 0 is not blank (8P plane `00 fc fc c4 c4 c4 c4 fc`). | copies, `rtl/bios/pc10_bios_video.sv` (`pi` forced to 0) | The board's top monitor while the BIOS rewrites VRAM, or the LS194 schematic sheet |
| Z80 NMI / watchdog at the end of the frame, not at vblank | `1928-1938`: both screens use `set_refresh_hz(60)` with no `set_vblank_time`, so MAME's vblank is zero-length at the end of each 262-line frame, and `vblank_irq` (1886-1896) fires there. Measured: in MAME's debugger trace (totalcycles) all 81 NMIs in the first 4 s of pc_smb are taken 5,608-5,621 Z80 cycles after line 240, i.e. at line 262. The board's top monitor presumably blanks from line 240. | copies: `pc10_bios`'s `vblank` input takes the frame-boundary edge (`sim/bios_boot_tb`) | The top monitor's vblank-to-NMI timing on a board, or the schematic's sheet 1 |
| BIOS PPU reset does nothing | `ppu_reset_w` (765-769) calls `m_ppu->reset()`, but `ppu2c0x_device` (`src/devices/video/ppu2c0x.cpp`) has no `device_reset`, so the PPU's registers, counters and raster are untouched | copies: `nes.v`'s `pc10_ppu_reset` is tied low in `PlayChoice10.sv` | The board's PPU behaviour while 7E Q2 is set, or the 2C03's /RST effect |
| Two screens at 60.000 Hz | `1928-1938`: `set_refresh_hz(60)`; the PPU follows the screen, so the cart CPU gets 29,829.5 cycles a frame against the PPU's 29,780.67 (ROADMAP, Phase 0 item 5) | differs, by decision: the core keeps NES_MiSTer's PPU timing, 341 x 262 dots at 5.369318 MHz, 60.0988 Hz; MAME's frame is 0.164% longer. The BIOS's NMI follows the PPU's frame | — (the PPU's timing is known; MAME's 60 Hz is a screen declaration, not a measurement) |

## Carts

| Kludge | MAME | Core | Would settle it |
|---|---|---|---|
| One cart; its INST ROM in every slot | `bios_map` (1479-1487) maps the set's INST ROM at C000-DFFF whatever CSEL says; `pc10_prot_r/w` (790-812) answer only for slot 0 (E7 elsewhere) | copies for every channel not loaded: its INST ROM reads channel 1's, its RP5H01 port E7 (`pc10_bios.sv`); a loaded channel has its own (Phase 5, beyond MAME) | A board with carts in several slots, read from the Z80 |

## Vendored modules that disagree with MAME

| Module | MAME says | The module does | Kept because | Would settle it |
|---|---|---|---|---|
| `{{module}}` | {{MAME behaviour, file:line}} | {{module behaviour, file:line}} | {{silicon-derived / upstream bench / measured}} | {{what would show which describes the chip}} |
