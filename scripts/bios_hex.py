#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Write the BIOS board's ROMs for a set as $readmemh files, from MAME's -listxml.

    python scripts/bios_hex.py pc_smb [--bios dual]
    -> debug/<set>-roms/{bios,inst,prom}.hex (not -boot: mame_boot_trace.py recreates that)

bios: the 16 KB Z80 ROM of the chosen BIOS; inst: the set's maincpu region at 0xC000;
prom: the 16-byte rp5h01 region. Files are found by CRC in the set's zip, then playch10.zip.
"""
import argparse, subprocess, sys, zipfile, xml.etree.ElementTree as ET
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from coretools import mame_exe, NO_WINDOW, setting   # noqa: E402

REPO = Path(__file__).resolve().parent.parent
BIOS_INDEX = {"dual": "0", "single": "1", "alt": "2", "singleb": "3", "dualb": "4"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("--bios", default="dual")
    a = ap.parse_args()
    m = ET.fromstring(subprocess.run([str(mame_exe()), "-listxml", a.game], capture_output=True,
                                     text=True, check=True, **NO_WINDOW).stdout).find("machine")
    names = {b.get("name"): i for i, b in enumerate(m.findall("biosset"))}
    want = a.bios
    roms = m.findall("rom")
    rompath = Path(setting("MAME_ROMPATH").split(";")[0])
    zips = [zipfile.ZipFile(rompath / f"{a.game}.zip"), zipfile.ZipFile(rompath / "playch10.zip")]

    def data(r):
        crc = int(r.get("crc"), 16)
        for z in zips:
            for i in z.infolist():
                if i.CRC == crc:
                    return z.read(i)
        sys.exit(f"{r.get('name')} ({r.get('crc')}) not found")

    out = REPO / "debug" / f"{a.game}-roms"
    out.mkdir(parents=True, exist_ok=True)
    pick = {}
    for r in roms:
        reg, off = r.get("region"), int(r.get("offset"), 16)
        if reg == "maincpu" and r.get("bios") == want and off == 0:
            pick["bios"] = data(r)
        elif reg == "maincpu" and not r.get("bios") and off == 0xC000:
            pick["inst"] = data(r)
        elif reg == "rp5h01":
            pick["prom"] = data(r)
    for k in ("bios", "inst", "prom"):
        if k not in pick:
            sys.exit(f"{a.game}: no {k} ROM for bios {want}")
        (out / f"{k}.hex").write_text("\n".join(f"{b:02x}" for b in pick[k]) + "\n")
        print(f"{k}: {len(pick[k])} bytes -> {out / (k + '.hex')}")


if __name__ == "__main__":
    main()
