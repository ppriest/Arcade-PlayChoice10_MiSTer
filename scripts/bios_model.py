#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The BIOS display (top monitor) as MAME draws it, from a capture's VRAM.

    python scripts/bios_model.py debug/pc_smb-600 [--out model.png] [--check]

playch10.cpp: get_bg_tile_info (546-554), bios_charlayout (1871-1880), playch10_palette
(521-538, PROMs ROMREGION_INVERT, 2052-2075), screen_update_playch10_top (593-605).
--check compares with the top 240 lines of the capture's reference.png (MAME's layout puts
the top monitor first).

Also writes, for sim/bios_video_tb: bios_gfx.hex (gfx1, three 8 KB planes in order),
bios_prom.hex (the three PROMs as dumped, 6F 6E 6D), vram.hex, and bios_pal.hex (the
256-entry palette as RRGGBB).
"""
import argparse, sys, zipfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from coretools import setting   # noqa: E402

GFX = ["9acffb30", "c1232eee", "30c15e23"]       # 8K, 8M, 8P of the dual BIOS
PROMS = ["e5414ca3", "a2625c6e", "1213ebd4"]     # 6F (R), 6E (G), 6D (B)
COEFF = (0x0E, 0x1F, 0x43, 0x8F)


def by_crc(z, crc):
    want = int(crc, 16)
    for i in z.infolist():
        if i.CRC == want:
            return z.read(i)
    sys.exit(f"crc {crc} not in {z.filename}")


def tables():
    z = zipfile.ZipFile(Path(setting("MAME_ROMPATH").split(";")[0]) / "playch10.zip")
    gfx = [by_crc(z, c) for c in GFX]
    raw = [by_crc(z, c) for c in PROMS]
    proms = [bytes(~b & 0xFF for b in r) for r in raw]
    pal = []
    for i in range(256):
        rgb = []
        for p in proms:
            v = sum(COEFF[j] for j in range(4) if (p[i] >> j) & 1)
            rgb.append(v)
        pal.append(tuple(rgb))
    return gfx, pal, raw


def render(vram, gfx, pal, sdcs=False):
    img = [[pal[0]] * 256 for _ in range(240)]
    if sdcs:
        return img
    for ty in range(30):
        for tx in range(32):
            o = (ty * 32 + tx) * 2
            code = (vram[o] | ((vram[o + 1] & 7) << 8)) & 0x3FF
            color = (vram[o + 1] >> 3) & 0x1F
            for y in range(8):
                rows = [g[code * 8 + y] for g in gfx]
                for x in range(8):
                    b = 7 - x
                    pen = (((rows[0] >> b) & 1) << 2) | (((rows[1] >> b) & 1) << 1) | ((rows[2] >> b) & 1)
                    img[ty * 8 + y][tx * 8 + x] = pal[color * 8 + pen]
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("capture")
    ap.add_argument("--out")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--rtl", action="store_true",
                    help="compare <capture>/bios_rtl.hex (sim/bios_video_tb) with the model")
    a = ap.parse_args()
    if a.rtl:
        d = Path(a.capture)
        gfx, pal, _ = tables()
        img = render((d / "videoram.bin").read_bytes(), gfx, pal)
        want = [p for row in img for p in row]
        got = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
               for h in (d / "bios_rtl.hex").read_text().split()]
        bad = [i for i, (p, q) in enumerate(zip(want, got)) if p != q]
        if len(got) != len(want):
            print(f"{d.name}: RTL gave {len(got)} pixels, the model {len(want)}")
            return 1
        print(f"{d.name}: RTL {len(bad)} of {len(want)} pixels differ from the model"
              + (f"; first at x {bad[0] % 256} y {bad[0] // 256}" if bad else ""))
        return 1 if bad else 0
    d = Path(a.capture)
    gfx, pal, raw = tables()
    vram = (d / "videoram.bin").read_bytes()
    img = render(vram, gfx, pal)
    (d / "bios_prom.hex").write_text("\n".join(f"{b:02x}" for r in raw for b in r) + "\n")
    (d / "vram.hex").write_text("\n".join(f"{b:02x}" for b in vram) + "\n")
    (d / "bios_gfx.hex").write_text("\n".join(f"{b:02x}" for g in gfx for b in g) + "\n")
    (d / "bios_pal.hex").write_text("\n".join(f"{r:02x}{g:02x}{b:02x}" for r, g, b in pal) + "\n")
    from PIL import Image
    out = Image.new("RGB", (256, 240))
    out.putdata([p for row in img for p in row])
    out.save(a.out or d / "bios_model.png")
    if a.check:
        ref = Image.open(d / "reference.png").convert("RGB").crop((0, 0, 256, 240))
        bad = sum(1 for p, q in zip(out.get_flattened_data(), ref.get_flattened_data()) if p != q)
        print(f"{d.name}: {bad} of {256 * 240} pixels differ from MAME's top screen")
        return 1 if bad else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
