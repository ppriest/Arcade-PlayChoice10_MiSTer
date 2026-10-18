# PlayChoice10: hardware notes

Nintendo PlayChoice-10 (1986), as MAME models it. Each fact cites its source.

Source: MAME `src/mame/nintendo/playch10.cpp` (line numbers below) at `dedb5227403`
(`mame0289-1527`); the only change to the driver since the `mame0289` tag is the `SCREEN()`
constructor (API only), so MAME 0.289 (`mame.exe -version`) is the matching binary. Devices:
`src/devices/video/ppu2c0x.cpp`, `src/devices/machine/rp5h01.cpp`, the RP2A03 in
`src/devices/cpu/m6502/rp2a03.cpp` and `src/devices/sound/nes_apu.cpp`, the Z80. `-listxml`
from that binary. Everything here is MAME's model unless marked otherwise.

## The board in one paragraph

Two computers on one board. A Z80 runs the BIOS: coins, time credit, the game menu, and a
character display on the top monitor. A complete NES (RP2A03 CPU and APU, an RGB PPU, 2 KB
work RAM, 2 KB nametable RAM) runs the cartridge and drives the bottom monitor. The Z80 holds
the NES in reset or halt, masks its controls, display and sound, and reads the cart's RP5H01
security PROM (driver header, lines 21-58; machine config, lines 1898-1954).

## Sets

55 games plus one clone, all `playch10` children. Sizes in KB are loaded bytes from `-listxml`.
"INST" is the per-cart 8 KB Z80 instruction ROM loaded at Z80 0xC000 (every set). MAME flags
from the `GAME` lines 2989-3068.

| Board | Mapper (NES equivalent) | Sets | PRG KB | CHR KB | Notes |
|---|---|---|---|---|---|
| Standard | NROM (0) | pc_tenis pc_mario pc_bball pc_bfght pc_golf pc_1942 (horizontal mirroring); pc_ebike pc_kngfu pc_smb pc_vball; pc_duckh pc_hgaly pc_wgnmn (Zapper) | 16-32 | 8 | pc_ebike `IMPERFECT_GRAPHICS` |
| A | CHR bank at 0x8000-0x8FFF (CNROM-like, 3) | pc_grdus, pc_grdue (clone), pc_tkfld | 32 | 32 | |
| B | UNROM (2), 8 KB CHR RAM | pc_pwrst pc_trjan pc_cvnia pc_dbldr pc_rnatk pc_rygar pc_cntra | 128 | RAM | |
| C | CHR bank bit 1 at 0x6000 | pc_goons | 32 | 16 | no NES mapper writes there |
| D | MMC1 (1), CHR RAM | pc_radrc; pc_mtoid (D2: +8 KB RAM at 0x6000) | 128 | RAM | pc_radrc `IMPERFECT_GRAPHICS` |
| E | MMC2 (9), 8 KB NVRAM | pc_miket | 128 | 128 | `IMPERFECT_GRAPHICS` |
| F | MMC1 (1), CHR ROM | pc_rcpam pc_ddrgn pc_ngaid pc_tmnt pc_ftqst pc_tbowl pc_virus pc_rrngr pc_drmro pc_bload pc_ynoid; pc_bstar (F2: +RAM) | 32-256 | 32-128 | pc_bstar `IMPERFECT_GRAPHICS` |
| G | MMC3 (4), 8 KB RAM | pc_smb2 pc_smb3 pc_mman3 pc_suprc pc_tmnt2 pc_wcup pc_ngai2 pc_ngai3 pc_pwbld pc_rkats pc_ttoon; pc_radr2 pc_gntlt (four-screen, +2 KB cart nametable) | 64-256 | 64-256 | pc_ngai2, pc_radr2 `IMPERFECT_GRAPHICS` |
| H | MMC3 with CHR ROM and 8 KB CHR RAM mixed (TQROM, 119) | pc_pinbt | 128 | 64 + RAM | `IMPERFECT_GRAPHICS` |
| I | AxROM (7), one-screen mirroring | pc_cshwk pc_sjetm | 128-256 | RAM | both `IMPERFECT_GRAPHICS` |
| K | MMC1 (1), CHR RAM, +8 KB RAM | pc_moglf | 256 | RAM | |

Largest cart: pc_tmnt2, 256 KB PRG + 256 KB CHR. The BIOS adds 16 KB Z80 program, 24 KB
character ROM, three 256-byte colour PROMs and the PPU's 192-byte palette ROM.

**BIOS versions** (`BIOS_CPU`, lines 2038-2050): `dual` (default), `single`, `alt` ("doesn't
work properly"), `singleb`, `dualb` ("doesn't work properly"). The dual-monitor BIOS has
`0x2a` at byte 3 (`video_start`, line 559); MAME switches its whole video model on that byte.

## CPUs and chips

| Tag | Part | Clock | Role | Existing RTL |
|---|---|---|---|---|
| maincpu | Z80 | 8 MHz / 2 = 4 MHz (1901) | BIOS | T80 (MiSTer-devel, many cores) |
| cart | RP2A03 ("really RP2A03E", MAME uses G) | NTSC_APU_CLOCK = 21.477272 MHz / 12 (1905) | game CPU and APU | NES_MiSTer `rtl/t65`, `rtl/apu.sv` |
| ppu | RP2C03B (RGB PPU) | master / 4 dot clock | game video | NES_MiSTer `rtl/ppu.sv`, which already models the RGB PPUs (no odd-frame dot skip) |
| rp5h01 | Ricoh RP5H01 security PROM, 64 bits + counter | clocked by Z80 writes | per-cart key | none; 192 lines in MAME |
| outlatch1, outlatch2 | 74LS259 x2 | - | BIOS control lines | trivial |
| BIOS video | LS194 shifters, 3 colour PROMs | - | top monitor | none; MAME's `bg_tilemap` |

## Clocks

| Clock | Source |
|---|---|
| 21.477272 MHz master (NTSC_APU_CLOCK x 12) | `RP2A03G(config, m_cartcpu, NTSC_APU_CLOCK)` (1905) |
| PPU dot 5.369318 MHz (master / 4) | not stated in the driver; the RP2C03 is clocked like the 2C02 (NES core) |
| Z80 4 MHz from 8 MHz | `Z80(config, m_maincpu, 8000000/2)` (1901) |
| Screens 60 Hz, 256 x 262, 256 x 240 visible | `set_refresh_hz(60)`, `set_size(32*8, 262)` (1928-1938) |

MAME declares 60 Hz rather than the PPU's own rate: 341 dots x 262 lines at 5.369318 MHz is
60.0988 Hz. The PPU timing in MAME follows the screen, so MAME's CPU-to-PPU ratio is not exactly
3:1. See the roadmap's open items.

## Video

### Bottom monitor: the PPU

256 x 240 from the RP2C03B: the NES PPU with an RGB DAC. Colour is the 6-bit NES index through
`rp2c0x.pal` (192 bytes, 3 bits per channel, `pal3bit`); emphasis bit n forces channel n to 7
rather than attenuating (`ppu2c0x_rgb_device::init_palette_tables`, ppu2c0x.cpp 458-476). CHR
and nametables are on the PPU bus (`ppu_map`, 1501-1509): CHR through the cart's banking, 2 KB
nametable RAM on the main board, 2 KB more on four-screen carts (1384-1393).

### Top monitor: the BIOS display

32 x 32 tiles of 8 x 8 (256 x 240 shown), from Z80 VRAM at 0x9000 (2 KB, two bytes a tile):
code = byte0 + (byte1 & 7) << 8, colour = byte1 >> 3 (`get_bg_tile_info`, 546-554). Tiles are 3
bpp from three 8 KB planes of `gfx1` (`bios_charlayout`, 1871-1880). Colour is `color*8 + pen`
through three 4-bit PROMs, weighted 0x0e/0x1f/0x43/0x8f (`playch10_palette`, 521-538; the PROM
region is `ROMREGION_INVERT`). While SDCS is set the Z80 owns VRAM and the display is black
(`sdcs_w`, 729-738; `screen_update_playch10_top`, 593-605).

### How the two are combined

- **Dual BIOS**: two screens with the same timing in MAME, top = BIOS, bottom = PPU blanked
  while DISPMASK (`screen_update_playch10_bottom`, 607-620). Both are live in every frame;
  nothing alternates.
- **Single BIOS**: one screen. A rising DISPMASK toggles between the BIOS display and the PPU
  (`screen_update_playch10_single`, 573-591).
- The Z80's NMI and watchdog come from the top screen's vblank (`vblank_irq`, 1886-1896).

Not in MAME: whether the BIOS video counters are slaved to the PPU's raster or free-running.
The core will drive both from one raster, which MAME's two identical screens permit.

Aspect: 4:3 per monitor (two standard monitors in the cabinet; no `set_physical_aspect`).

## Memory map

### Z80 (`bios_map`, 1479-1487; `bios_io_map`, 1489-1499)

| Range | What |
|---|---|
| 0000-3FFF | BIOS ROM (8T) |
| 8000-87FF | RAM 8V |
| 8800-8FFF | RAM 8W; only 1 KB visible unless UP8W (`ram_8w_r/w`, 637-651) |
| 9000-97FF | VRAM; writes ignored unless SDCS (512-519) |
| C000-DFFF | cart INST ROM |
| E000-FFFF | RP5H01 of slot 0: read D4 counter, D3 data; write D4 test, D3 clock, D0 reset (`pc10_prot_r/w`, 790-812) |
| I/O 00 r | coin 1, service, coin 2, INT DETECT, reset, enter, channel select |
| I/O 01, 02 r | DIP SW1, SW2 |
| I/O 03 r | clear INT DETECT |
| I/O 00-07 w | LS259 7D bit 0: SDCS, CNTRLMASK, DISPMASK, SOUNDMASK, GAMERES, GAMESTOP |
| I/O 08-0F w | LS259 7E bit 0: NMI enable, DOG DI, PPU reset, CSEL0-3 (cart select), UP8W |
| I/O 10-13 w | time digits, single BIOS only |

INT DETECT is set by the PPU's NMI output (`int_detect_w`, 540-544) and is how the BIOS sees
that the game is running.

### RP2A03 (`cart_map`, 1511-1526, and the per-board maps that follow)

The NES map: 2 KB RAM mirrored to 1FFF, PPU 2000-3FFF, OAM DMA 4014, controllers 4016/4017,
PRG at 8000-FFFF, board RAM or NVRAM at 6000-7FFF where the board has it. Controller reads
return bit 6 set (open bus, 836-868); CNTRLMASK clears Select and Start from player 1's latch
(820-834). The Zapper sets port 2 bit 3 (light not seen) and bit 4 (trigger, unless CNTRLMASK).

## Inputs and DIPs (`INPUT_PORTS_START( playch10 )`, 1635-1855)

- BIOS port: Channel Select, Enter, Reset (service-type buttons), Coin 1, Coin 2, Service.
- P1: A, B, Game Select, Start, joystick. P2: A, B, joystick (its Select/Start are wired to P1's).
- Gun sets: trigger, X 0-255, Y 0-239.
- SW1: units of time per coin A/B (6 bits), Demo Sounds, Service Mode. SW2: Coin Mode, Timer
  speed / Free Play (7 bits). The manual's conditional DIP table is commented out in the driver
  (1650-1755) because MAME cannot express it; `extract_dips.py` reads the commented block and
  fails on its condition, so the generator needs to skip comments.

## Sound

The RP2A03's APU only, mono; SOUNDMASK mutes it (`sound_mask_w`, 750-753). Already in the NES
core.

## Protection

The RP5H01 per cart: 16 bytes in each set's `rp5h01` region. The BIOS refuses a cart whose key
does not match. MAME supports only slot 0 (`pc10_prot_r`, 790-801).

## Feasibility

Not a large board. Every chip but the RP5H01 and the BIOS display exists as tested RTL, the
largest set is 0.5 MB, and the NES core already fits the DE10-nano with room
(its per-build figures are to be measured in Phase 0, not assumed).
