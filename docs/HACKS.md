# Hacks, approximations and workarounds in this core

Everything in this core's own RTL, scripts or `.mra` layout that is known not to be what the
hardware does: a stand-in, a shortcut, a value chosen to make something work, a workaround for a
tool. Each entry is added in the commit that introduces the hack and removed in the commit that
removes it.

This is not `MAME_KLUDGES.md`. That file lists MAME's own guesses that the core reproduces on
purpose because MAME is the reference. This file lists what is ours.

Rules:

- An entry cites `file:line` (or a module and signal name if the line moves often), and the
  evidence column says what was measured, or "unverified".
- "What would make it correct" names the work, not "fix later".
- A hack whose entry is missing is a bug. A hack whose entry is stale is worse: update it in the
  same commit as the code.
- Severity is what a player or a verifier would see: **visible** (wrong pixels, wrong sound, wrong
  timing a game can hit), **latent** (wrong only for input no in-scope set produces), **tooling**
  (affects the build or the bench, not the bitstream).

| What | Where | Why it is a hack | What would make it correct | Evidence | Severity |
|---|---|---|---|---|---|
| Watchdog reset of the Z80 held 4 clock enables | `rtl/bios/pc10_bios.sv:128` | MAME's `pulse_input_line(RESET, zero)` has no length; T80 needs to see it | The reset length on the board (LS161A, sheet 1) | Boot trace equal to MAME's across 26 vblanks (`sim/bios_boot_tb`); a watchdog reset is not reached in that window | latent |
| Vblank NMI held 2 clock enables | `rtl/bios/pc10_bios.sv:129` | MAME's NMI pulse has no length; T80 takes NMI on an edge | The board's pulse width | Boot trace equal to MAME's, NMIs taken at the same accesses | latent |
| Single-monitor BIOS: black below the BIOS display's 120 lines | `PlayChoice10.sv` (`bios_cut`) | MAME clips the tilemap to the top half and leaves the rest of the bitmap as the last frame drew it (`screen_update_playch10_single`, 573-591) | What the board's single monitor shows there, from footage or a board | unverified | visible |

| Board A (Gradius, Track & Field) as NES mapper 3 | `scripts/build_mra.py` (BOARDS) | MAME decodes the CHR bank at 0x8000-0x8FFF (`cart_a_map`); CNROM decodes 0x8000-0xFFFF, so a game write to 0x9000-0xFFFF would also bank | A board-A mapper with MAME's decode, if a set writes there | unverified: no set seen writing there | latent |
| Board C (The Goonies) as NES mapper 87 | `scripts/build_mra.py` (BOARDS) | MAME banks CHR on a write to 0x6000 only, bit 1 (`cboard_vrom_switch_w`); mapper 87 takes 0x6000-0x7FFF, bank {D0, D1}, which is bit 1 with 16 KB of CHR | A board-C mapper with MAME's decode | the title screen draws right on the board (`debug/hw/p6/goonies.png`); play not checked | latent |
<!-- Examples of the shape, from sibling cores:
| Sound mailbox is a stub that answers the power-on test | `rtl/gx_snd_stub.sv` | No sound CPU yet; the stub returns the reply the test expects and a heartbeat | Phase 3: the real sound board | The game's RAM check passes with it; nothing else is exercised | visible |
| Sound-command spin of 800 CPU clocks after a latch write | `rtl/cpu/…_bus.sv:NNN` | Copies MAME's 40 us wait; the real board's mechanism is unknown | A measurement of the latch on hardware | Without it the second byte overwrote the first (commit) | latent |
| Sound CPU reset held 1,024 clocks | `rtl/….sv:NNN` | MAME's pulse is zero-length; the T80 needs to see it | The measured reset length | A PCB measurement says about one second | latent |
| Screen timing from one game used for every game | `rtl/video/…crtc.sv` | MAME declares 60 Hz with no comment; the one PCB-verified rate is used for all | Per-game timing from PCB measurement | 0.043% from the verified rate | visible |
-->

## Removed

Entries move here when the hack is gone, with the commit that removed it, so a later reader can
tell "never had it" from "had it and fixed it". Delete a row once nothing else refers to it.

| What | Removed by | Replaced with |
|---|---|---|
