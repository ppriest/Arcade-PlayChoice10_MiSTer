#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""MAME's INT DETECT at each BIOS port-0 read, for sim/bios_boot_tb's NES stub.

    python scripts/intdet_replay.py pc_smb
    -> debug/<set>-roms/intdet.txt, one bit per IN from port 0: 1 when MAME read INT DETECT
       set (bit 3 low), 0 otherwise.

INT DETECT is set by the PPU's NMI (playch10.cpp int_detect_w) and cleared by IN 3; with no
NES in the bench, the bench sets it before each port-0 read MAME saw it set.
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
game = sys.argv[1]
src = REPO / "debug" / f"{game}-boot" / f"{game}_boot.trace"
out = REPO / "debug" / f"{game}-roms" / "intdet.txt"
bits = []
for ln in open(src):
    if ln.startswith("#"):
        continue
    f = ln.split("\t")
    if len(f) > 4 and f[1] == "ir" and int(f[2], 16) & 0xFF == 0:
        bits.append("0" if int(f[4], 16) & 8 else "1")
out.write_text("\n".join(bits) + "\n")
print(f"{len(bits)} port-0 reads, {bits.count('1')} with INT DETECT set -> {out}")
