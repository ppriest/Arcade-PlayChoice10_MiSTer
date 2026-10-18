# PlayChoice10 state inventory

What a savestate or a state dump has to carry, kept current as RTL lands (the skill's
`savestates.md`). "Skip" needs a reason: a ROM table from the `.mra`, or something re-derived
every frame.

## RAMs

| Region | RTL | Width x depth | Bytes | Save? |
|---|---|---|---|---|
| Z80 RAM 8V | `pc10_bios.ram8v` | 8 x 2048 | 2048 | yes |
| Z80 RAM 8W | `pc10_bios.ram8w` | 8 x 2048 | 2048 | yes |
| BIOS VRAM | `pc10_bios.vram` | 8 x 2048 | 2048 | yes |
| NES side | NES_MiSTer's own savestate bus (`rtl/nes`) | | | yes, through its existing path |

## Registers and FSMs

| What | RTL | Bits | Save? | MAME `save_item` equivalent |
|---|---|---|---|---|
| LS259 7D, 7E | `pc10_bios.q7d`, `q7e` | 16 | yes | the latches' own state, and `m_pc10_*` derived from them |
| INT DETECT | `pc10_bios.int_detect` | 1 | yes | `m_pc10_int_detect` |
| NMI / watchdog pulse counters | `pc10_bios.nmi_cnt`, `zres_cnt` | 10 | yes (zero at a frame boundary) | none (MAME's pulses are instantaneous) |
| Z80 clock-enable phase | `pc10_bios.acc` | 10 | yes | none |
| RP5H01 | `rp5h01.counter`, `mode7`, `old_reset`, `old_clock` | 10 | yes | rp5h01's `m_counter`, `m_counter_mode`, `m_old_reset`, `m_old_clock` |

## Chip state

| Chip | Module | Addressable? | Tier | Note |
|---|---|---|---|---|
| Z80 | T80se (`rtl/cpu/t80`) | registers through T80's `REG`/`DIR` ports, not yet brought out | CPU | |

## Deliberately skipped

| What | Why it need not be saved |
|---|---|
| BIOS ROM, INST ROM, RP5H01 PROM | loaded from the `.mra` |

## Frame alignment

Restore point (normally `frame_start`), and anything whose phase must be saved with it: sprite or
tile double-buffer selection, snapshot ownership bits.
