#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compare the Z80's instruction timing in the boot bench with MAME's.

    python scripts/compare_cycles.py <mame.tr> <set>_m1.trace

mame.tr: MAME's debugger trace with the total cycle count first on each line, made by
    trace <file>,maincpu,noloop,{tracelog "%d ",totalcycles}
(a Lua autoboot script can issue it through manager.machine.debugger under
-debug -debugger none). <set>_m1.trace: sim/bios_boot_tb's opcode fetches,
"T-state address opcode".

The bench logs every M1 fetch, so a prefixed opcode (CB, DD, ED, FD) shows twice; those
are folded into one instruction. The two are walked by PC; the first instruction whose
start, relative to the first, differs is printed with its neighbours.
"""
import sys

PREFIX = {0xCB, 0xDD, 0xED, 0xFD}


def mame(path):
    for ln in open(path, encoding="utf-8", errors="replace"):
        f = ln.split()
        if len(f) < 2 or not f[0].isdigit() or not f[1].endswith(":"):
            continue
        yield int(f[0]), int(f[1][:-1], 16), ln.rstrip()


def rtl(path):
    prev = None
    for ln in open(path):
        t, a, d = ln.split()
        t, a, d = int(t), int(a, 16), int(d, 16)
        if prev and prev[2] in PREFIX and a == (prev[1] + 1) & 0xFFFF:
            prev = (prev[0], prev[1], -1)   # second byte of a prefixed opcode
            continue
        prev = (t, a, d)
        yield t, a


def main():
    m, r = mame(sys.argv[1]), rtl(sys.argv[2])
    hist = []
    t0m = t0r = None
    n = 0
    for (tm, am, text), (tr, ar) in zip(m, r):
        if t0m is None:
            t0m, t0r = tm, tr
        n += 1
        dm, dr = tm - t0m, tr - t0r
        hist.append((dm, dr, am, ar, text))
        hist = hist[-12:]
        if am != ar or dm != dr:
            for h in hist:
                flag = "" if (h[0] == h[1] and h[2] == h[3]) else "  <--"
                print(f"MAME {h[0]:>9} {h[2]:04X}   RTL {h[1]:>9} {h[3]:04X}   {h[4].split(':',1)[1].strip()}{flag}")
            print(f"first difference at instruction {n}")
            return 1
    print(f"{n} instructions: same addresses, same start cycles")
    return 0


if __name__ == "__main__":
    sys.exit(main())
