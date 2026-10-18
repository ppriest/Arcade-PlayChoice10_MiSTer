# T80 provenance

**In this repository:** copied from the BallySente core's `rtl/cpu/t80/` (commit `05929f2`
there), unchanged, including its one-line `T80.vhd` fix (below). Here the Z80 is the
PlayChoice-10 BIOS CPU at 4 MHz, driven through `T80se` with a clock enable from `clk`.
The notes below are BallySente's and its predecessors', carried with the files.

**In this repository:** copied from the Fuuki core's `rtl/cpu/t80/`; one line of `T80.vhd` is
since changed here (below, "`T80.vhd` is no longer byte-identical"). Bally/Sente's sound CPU is the Z80 on the 6VB audio board at 4 MHz
(`sente6vb.cpp:107`), driven through `T80se` with a clock enable from `clk_sys`/10.
Fuuki took it from Psikyo unchanged; the notes below are Psikyo's, and the Fuuki status
block at the end is Fuuki's evidence, not this core's.

Vendored from https://github.com/MiSTer-devel/T80, commit `830fd0315f0af5cdbcb0e703f1cea3ce4e91f538`
(2021-03-31), for use as the sound-CPU core (Z80 on SH201B/KA302C; LZ8420M on SH403/SH404 is
expected to be T80-compatible, per docs/ROADMAP.md's component reuse map -- not yet confirmed,
Phase 2 concern).

License: 3-clause BSD-style (stated in each file's header, no separate LICENSE file upstream).
Original core copyright (c) 2001-2002 Daniel Wallner <jesus@opencores.org>; maintained since by
MikeJ (fpgaarcade.com) and the MiSTer-devel community (Sorgelig, TobiFlex, Bruno Duarte Gouveia).
Permissive, no copyleft obligation -- redistribution/synthesis permitted with attribution.

`T80se.vhd` is the top-level this project will instantiate: the standard synchronous wrapper
exposing the classic Z80 bus (`M1_n`/`MREQ_n`/`IORQ_n`/`RD_n`/`WR_n`/`RFSH_n`/`HALT_n`, 16-bit
`A`, 8-bit `DI`/`DO`), same interface convention nearly every MiSTer arcade core built around a
Z80 sound CPU uses. `Mode` generic: `0` = Z80 (what this project needs), `1` = Fast Z80, `2` =
8080, `3` = Game Boy.

Files kept as vendored (`T80.qip` lists the full compile set): `GBse.vhd`, `T80.vhd`, `T80a.vhd`,
`T80as.vhd`, `T80pa.vhd`, `T80s.vhd`, `T80se.vhd`, `T80sed.vhd`, `T8080se.vhd`, `T80_ALU.vhd`,
`T80_MCode.vhd`, `T80_Pack.vhd`, `T80_Reg.vhd`. Only `T80se.vhd` (plus its dependencies:
`T80.vhd`, `T80_ALU.vhd`, `T80_MCode.vhd`, `T80_Pack.vhd`, `T80_Reg.vhd`) is actually needed for
this project; the other top-levels (`GBse`, `T8080se`, `T80a`, `T80as`, `T80pa`, `T80s`,
`T80sed`) are kept vendored anyway rather than pruned, matching `T80.qip`'s own file set --
avoids having to re-derive which files are truly load-bearing if a later phase needs a different
top-level variant.

Much lower risk than TG68K.C (`rtl/cpu/tg68k/PROVENANCE.md`): T80 is the de facto standard Z80
core across the MiSTer-devel arcade ecosystem (embedded directly in dozens of cores per
docs/ROADMAP.md's survey), unlike TG68K.C being the *only* viable open 68020 option. Still
worth an independent boot spike before trusting it, same discipline as Phase 0.

## Status

- [x] Source vendored
- [x] Compiles under ModelSim-Altera 10.5b (`sim/t80_spike/`), clean 0 errors (one pre-existing
      upstream width-mismatch warning in `T80.vhd` line 685, an `and` of a 9-bit and a 4-bit
      operand -- not introduced by this project, not investigated further given T80's low prior
      risk, see below)
- [x] Boots and executes a small test program in simulation (`sim/t80_spike/tb_t80_boot.vhd`):
      fetches from address 0 (Z80 has no reset vector, unlike 68k), executes `LD A,0x42`,
      `LD (0x8000),A` (memory write), `OUT (0x00),A` (I/O write), `HALT` -- all four checked
      against expected values, PASS. Exercises opcode fetch, immediate fetch, a memory write
      cycle, and an I/O write cycle -- the classic bus protocol paths this project's actual
      memory-map wiring will depend on.
- [ ] Synthesizes/fits on the real Cyclone V (likely unnecessary as a standalone check given
      how widely this core is already proven on this exact FPGA family across other MiSTer
      cores -- revisit once the full sound subsystem is integrated instead)

**Simulation quirk, not a design issue**: `vsim -c -do "run -all; quit -f"` ran the simulation
to completion and printed PASS at 2040ns, but `quit -f` did not cleanly terminate the VHDL-only
session afterward -- the process sat idle (0% CPU) rather than exiting, needing a manual kill.
Every other testbench in this project (Verilog/SystemVerilog DUTs) has exited cleanly with the
same invocation; this may be specific to a VHDL top-level ending its process with a bare `wait;`.
Not investigated further since the actual simulation result is what matters and was captured
before the hang -- worth remembering if a future VHDL-only testbench run appears to hang: check
whether it already printed PASS/FAIL before assuming something is actually stuck.

## T80 has savestate ports; `T80se` does not forward them

`T80.vhd:124-127`:

    REG    : out std_logic_vector(211 downto 0);  -- IFF2, IFF1, IM, IY, HL', DE', BC',
    DIRSet : in  std_logic := '0';                -- IX, HL, DE, BC, PC, SP, R, I,
    DIR    : in  std_logic_vector(211 downto 0);  -- F', A', F, A

The whole architectural state, out and in. Of the wrappers vendored here only `T80pa` forwards
them; `T80se`, which this core instantiates, does not.

Adding it is a wrapper, not a fork: a thin local top level can instantiate `T80` directly with
the ports exposed and leave every vendored file untouched. Recorded here because it was missed
once already -- `sim/common/state_image.sv` restores the sound CPU with an instruction stub, and
pays for it in a drifting R, an IFF1/IFF2 pair that cannot be set apart, and two clobbered bytes
below SP. See `docs/STATE.md`.

## Local change: an upstream bug in the block I/O flags

**`T80.vhd` is no longer byte-identical to upstream.** One line is changed, marked in place with
the reason, and `T80_upstream_reference.vhd` holds the pristine copy so the diff stays checkable.

`T80.vhd:685` reads, upstream:

    ioq := (ioq and x"7") xor ('0'&BusA);

`ioq` is 9 bits (`std_logic_vector(8 downto 0)`, line 386) and `x"7"` is 4. IEEE
`std_logic_1164`'s `and` requires equal lengths: ModelSim warns at compile time (vcom-1275) and
**aborts at run time** (vsim-3424) the instant the line executes. It executes on `INI`, `IND`,
`OUTI` and `OUTD` — the Z80's block I/O instructions — which the Bally/Sente 6VB sound program
uses, so the boot dies partway through and the machine never reaches its self-calibration.

Changed to `(ioq and "000000111")`: the mask is meant to keep the low three bits, per the Z80's
P/V flag rule for those instructions, so the constant is widened rather than the vector
narrowed.

**Still present upstream** in MiSTer-devel/T80 at `830fd0315f0a` — the same commit vendored here
— so this is not a porting artefact. It is invisible to any core whose Z80 never executes block
I/O, which is why the sibling cores carry the compile warning without ever tripping over it.

The regression that guards the change: `sim/sound_cpu_tb` still matches MAME on all 60,000 bus
accesses after it, and the vcom-1275 warning is gone.

## Status in this core

Nothing below has been run here yet. Fuuki's and Psikyo's evidence above is why this module is
low risk, not proof that this core's integration of it works.

- [x] Source vendored, byte-identical to Fuuki's copy
- [x] Compiles clean under ModelSim in this repository (`sim/vhdl.files`; one
      pre-existing upstream warning, vcom-1275 at `T80.vhd:685`, an overloaded
      `and` with mismatched lengths -- same warning Fuuki records)
- [x] **6VB sound Z80 boots the audio board's own ROM against a MAME bus trace**

Upstream ships no testbench either, so the roadmap's criterion 1 cannot be met literally for this
module any more than for `mc6809i`. The substitute is the same, and it is now **done**:

`sim/sound_cpu_tb` runs T80se against the 6VB's own 8 KB ROM, with the board's memory map and a
replay of any read outside ROM and RAM, and diffs every bus access against MAME's trace of
`:audio6vb:audiocpu` (`scripts/mame_boot_trace.py cshift 60000 --cpu :audio6vb:audiocpu
--addr-hi 0xffff --tag sente6vb`).

> **60,000 bus accesses, 0 differences. Byte-identical to MAME, reads included.**
> All 2,049 writes match in address, data and order.

That is a stronger result than `mc6809i`'s, which differs on 3% of cycles in what a dead cycle
drives. The Z80 has no equivalent: every cycle it runs is a real access.

The boot window needs no replayed reads at all -- the 6VB never touches its ACIA in the first
60,000 accesses -- so the comparison rests entirely on the CPU and the ROM.

Extended since, to the whole boot and into the self-calibration:

> **1,200,000 bus accesses. All 1,112,116 reads identical to MAME. All 84,740 writes identical
> in address and data**, and identical in order except for the two halves of `EX (SP),IX`
> (`DD E3`), where MAME reads both bytes before writing either and T80 interleaves
> read/write/read/write. Same accesses, same data, different order within the one instruction,
> nothing else on the bus during it -- recorded in `docs/MAME_KLUDGES.md` alongside `mc6809i`'s
> dead-cycle divergence rather than "fixed".

`sim/t80_alu_tb` was added while chasing a divergence that turned out not to be T80's: it runs
the `SBC HL,DE` sequence the calibration compares with, prints the result and every flag, and
checks the sign against the result's bit 15. Kept as a regression, and as the shape to copy when
an instruction's flags are next in question -- an isolated bench answered in seconds what a
1.2-million-line trace diff could only point at.

## Under Verilator

The Verilator benches take T80 as GHDL's Verilog conversion (`scripts/verilator_prep.sh`, generics
fixed at Mode 0, T2Write 0, IOWait 1). The conversion is checked the same way as the VHDL:
`scripts/run_verilator.sh sound_cpu_tb` against MAME's boot trace, 60,000 accesses, 0 differences.
