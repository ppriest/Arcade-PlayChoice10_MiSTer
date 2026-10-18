#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate the PlayChoice-10 .mra files from MAME's -listxml and playch10.cpp.

    python scripts/build_mra.py [sets ...] [--out DIR]

Index 4, the BIOS board (PlayChoice10.sv, PC10_IDX_BIOS): 0000 the dual-monitor BIOS ROM,
4000 the set's INST ROM (maincpu at 0xC000), 6000 its RP5H01 PROM, 8000 the BIOS characters
(gfx1), E000 the colour PROMs 6F, 6E, 6D, 10000 the single-monitor BIOS ROM.

Index 3, the RP2C03's palette (ppu:palette, rp2c0x.pal): NES_MiSTer's custom palette download.

Index 1, the cart: NES_MiSTer's .nes download, a synthetic 16-byte iNES header, then the
set's `prg` region, then `gfx2`. The header carries what MAME's machine config and init
function say about the board (BOARDS below), so the NES core's loader and mapper selection
run unchanged.

DIPs: playch10.cpp's SW1 and SW2 (1747-1824). Main_MiSTer takes a bit range and at most 32
settings a switch, so the two 6-bit fields are split where their meaning splits.

ROM layout per set comes from -listxml of the installed MAME, never typed; the board
from the GAME() line's machine config and init function in MAME_SRC.
"""
import argparse, re, subprocess, sys, xml.etree.ElementTree as ET
from xml.sax.saxutils import escape
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from coretools import core_root, mame_exe, mame_src, mame_version, NO_WINDOW   # noqa: E402

# machine config -> (iNES mapper, CHR is RAM, PRG RAM/NVRAM at 0x6000, battery)
# playch10.cpp cart_*_map (1511-1631) and init_pc*board (1132-1474).
BOARDS = {
    "playch10":    (0,   False, False, False),   # standard
    "playch10_a":  (3,   False, False, False),   # CHR bank at 0x8000-0x8FFF; CNROM decodes 0x8000-0xFFFF
    "playch10_b":  (2,   True,  False, False),   # UNROM
    "playch10_c":  (87,  False, False, False),   # CHR bank = bit 1 of a 0x6000 write; mapper 87 decodes 0x6000-0x7FFF
    "playch10_d":  (1,   True,  False, False),   # MMC1, CHR RAM
    "playch10_d2": (1,   True,  True,  False),
    "playch10_e":  (9,   False, True,  True),    # MMC2, NVRAM
    "playch10_f":  (1,   False, False, False),   # MMC1, CHR ROM
    "playch10_f2": (1,   False, True,  False),
    "playch10_g":  (4,   False, True,  False),   # MMC3
    "playch10_h":  (119, False, False, False),   # MMC3 with CHR ROM and RAM (TQROM)
    "playch10_i":  (7,   True,  False, False),   # AxROM
    "playch10_k":  (1,   True,  True,  False),
}

GAME_RE = re.compile(r'^GAME\(\s*(\d+),\s*(\w+),\s*(\w+),\s*(\w+)\s*,\s*(\w+),\s*\w+,\s*(\w+),\s*(ROT\d+),\s*'
                     r'"([^"]*)",\s*"([^"]*)"', re.M)


def driver_games():
    src = Path(mame_src()).read_text(encoding="utf-8", errors="replace")
    out = {}
    for m in GAME_RE.finditer(src):
        year, name, parent, config, inputs, init, rot, maker, desc = m.groups()
        out[name] = dict(year=year, parent=parent, config=config, inputs=inputs, init=init,
                         rot=rot, maker=maker, desc=desc)
    return out


def listxml(sets):
    r = subprocess.run([str(mame_exe()), "-listxml", *sets], capture_output=True, text=True,
                       check=True, **NO_WINDOW)
    return {m.get("name"): m for m in ET.fromstring(r.stdout).findall("machine")}


def region(machine, name):
    roms = [r for r in machine.findall("rom") if r.get("region") == name and not r.get("bios")]
    roms.sort(key=lambda r: int(r.get("offset"), 16))
    # -listxml leaves out ROM_RELOAD: a hole the size of the ROM before it is that ROM again
    # (pc_pwrst's pw-u1 at 0x8000)
    out, end = [], 0
    for r in roms:
        off = int(r.get("offset"), 16)
        if off != end and out and off - end == int(out[-1].get("size")):
            out.append(out[-1])
            end = off
        if off != end:
            raise SystemExit(f"{machine.get('name')}: {name} has a hole at {end:#x}")
        out.append(r)
        end += int(r.get("size"))
    return out, end


def ines_header(mapper, prg_len, chr_len, vertical, four_screen, battery):
    f6 = ((mapper & 0x0F) << 4) | (8 if four_screen else 0) | (2 if battery else 0) | (1 if vertical else 0)
    f7 = mapper & 0xF0
    return bytes([0x4E, 0x45, 0x53, 0x1A, prg_len // 0x4000, chr_len // 0x2000, f6, f7] + [0] * 8)


def hexbytes(b):
    return " ".join(f"{x:02X}" for x in b)


BIOS = "dual"


def bios_part(roms, region, bios=None):
    rs = [r for r in roms if r.get("region") == region and r.get("bios") == bios]
    rs.sort(key=lambda r: int(r.get("offset"), 16))
    return rs


def part(r, comment=""):
    c = f"  <!-- {comment} -->" if comment else ""
    return f'\t\t<part crc="{r.get("crc")}" name="{r.get("name")}"/>{c}'


def pad(n):
    return f'\t\t<part repeat="0x{n:X}">FF</part>'


def bios_rom(m):
    roms = m.findall("rom")
    z80 = [r for r in bios_part(roms, "maincpu", BIOS) if int(r.get("offset"), 16) == 0]
    inst = [r for r in bios_part(roms, "maincpu") if int(r.get("offset"), 16) == 0xC000]
    prom = bios_part(roms, "rp5h01")
    gfx = bios_part(roms, "gfx1", BIOS)
    pal = bios_part(roms, "proms")
    for rs, n in ((z80, 0x4000), (inst, 0x2000), (prom, 0x10), (gfx, 0x6000), (pal, 0x300)):
        if sum(int(r.get("size")) for r in rs) != n:
            raise SystemExit(f"{m.get('name')}: a BIOS-board region of {n:#x} bytes is missing")
    out = [part(z80[0], f"0000 Z80 BIOS ({BIOS})"), part(inst[0], "4000 INST ROM"),
           part(prom[0], "6000 RP5H01"), pad(0x8000 - 0x6010)]
    out += [part(r, "8000 characters" if i == 0 else "") for i, r in enumerate(gfx)]
    out += [part(r, "E000 colour PROMs 6F 6E 6D" if i == 0 else "") for i, r in enumerate(pal)]
    single = [r for r in bios_part(roms, "maincpu", "single") if int(r.get("offset"), 16) == 0]
    if len(single) != 1:
        raise SystemExit(f"{m.get('name')}: no single-monitor BIOS")
    out += [pad(0x10000 - 0xE300), part(single[0], "10000 Z80 BIOS (single), OSD BIOS option")]
    return out


def switches():
    # SW1 bits 0-5, units of time for coin A / coin B: bits 0-3 pick the pair, bits 4-5 add
    # thousands to coin B (the driver's table, 1747-1810)
    pair = ["300/+0", "300/+100", "300/+200", "300/+300", "300/+400", "300/+500", "300/+600",
            "300/+700", "300/+800", "300/+900", "150/+0", "150/+200", "150/+400", "150/+600",
            "150/+800", "150/+500"]
    # SW2 bits 0-5, timer speed: a unit of time lasts ((v | 0xC0) + 0x3C) & 0xFF frames (the
    # driver's note, 79-80); bits 0-4 here, bit 5 adds 32
    frames = [str(((v | 0xC0) + 0x3C) & 0xFF) for v in range(32)]
    return [
        '\t<switches default="40,3F">',
        f'\t\t<dip name="Time/coin A/B" bits="0,3" ids="{",".join(pair)}"/>',
        '\t\t<dip name="Coin B time" bits="4,5" ids="+0,+1000,+2000,+3000"/>',
        '\t\t<dip name="Demo Sounds" bits="6" ids="Off,On"/>',
        '\t\t<dip name="Service Mode" bits="7" ids="Off,On"/>',
        f'\t\t<dip name="Frames/unit" bits="8,12" ids="{",".join(frames)}"/>',
        '\t\t<dip name="Frames/unit +32" bits="13" ids="Off,On"/>',
        '\t\t<dip name="Coin Mode" bits="14" ids="Mode 1,Mode 2"/>',
        '\t\t<dip name="Free Play" bits="15" ids="Off,On"/>',
        '\t</switches>',
    ]


def zips_of(name, g):
    return [f"{name}.zip"] + ([f"{g['parent']}.zip"] if g["parent"] != "playch10" else []) + ["playch10.zip"]


def cart_image(name, g, m):
    """The cart's NES image: iNES header, PRG, CHR. None for a board with no mapper yet."""
    mapper, chr_ram, _prg_ram, battery = BOARDS[g["config"]]
    if mapper is None:
        return None
    prg, prg_len = region(m, "prg")
    chrr, chr_len = region(m, "gfx2")
    if chr_ram != (chr_len == 0):
        raise SystemExit(f"{name}: board {g['config']} says CHR RAM={chr_ram}, gfx2 is {chr_len} bytes")
    vertical = g["init"] != "init_pc_hrz"
    four = g["init"] == "init_pcgboard_type2"
    hdr = ines_header(mapper, prg_len, chr_len, vertical, four, battery)
    return ([f"\t\t<!-- {name}: iNES header, mapper {mapper}, PRG {prg_len // 1024} KB, CHR "
             f"{'RAM' if chr_ram else str(chr_len // 1024) + ' KB'}, "
             f"{'four-screen' if four else 'vertical' if vertical else 'horizontal'} -->",
             f"\t\t<part>{hexbytes(hdr)}</part>"] + [part(r) for r in prg + chrr])


def inst_prom(m):
    roms = m.findall("rom")
    inst = [r for r in bios_part(roms, "maincpu") if int(r.get("offset"), 16) == 0xC000]
    return [part(inst[0], "0000 INST ROM"), part(bios_part(roms, "rp5h01")[0], "2000 RP5H01")]


def build(sets, games, xml, mv, title=None):
    """Channel 1 is sets[0] (index 4 with the BIOS board, index 1 its cart); channel n of 2-10
    is sets[n-1]: index 15 + n its cart, index 31 + n its INST ROM and RP5H01 (PlayChoice10.sv).
    To make a cabinet by hand, copy a channel's two blocks and change the zip and parts."""
    first = sets[0]
    g, m = games[first], xml[first]
    if cart_image(first, g, m) is None:
        return None
    out = header(escape(title or g["desc"]), g, mv) + channel1(first, g, m)
    for n, s in enumerate(sets[1:], 2):
        gs, ms = games[s], xml[s]
        if cart_image(s, gs, ms) is None:
            raise SystemExit(f"{s}: board {gs['config']} has no mapper yet")
        out += channel(s, gs, ms, str(n), str(15 + n), str(31 + n))
    return "\n".join(out + footer())


# The pieces of a .mra, shared with scripts/build_cabinet_page.py, whose page assembles the
# same lines in the browser.

def header(title_xml, g, mv):
    """The opening lines. title_xml is already XML-escaped; year and manufacturer are channel
    1's."""
    return [
        "<misterromdescription>",
        f"\t<name>{title_xml}</name>",
        # MAME's BIOS set for every .mra: Main_MiSTer names the OSD's CFG (and the DIP file)
        # after it, so the core's settings are one file, whichever game or cabinet runs
        "\t<setname>playch10</setname>",
        f"\t<mameversion>{mv}</mameversion>",
        f"\t<year>{g['year']}</year>",
        f"\t<manufacturer>{escape(g['maker'])}</manufacturer>",
        "\t<rbf>PlayChoice10</rbf>",
        "\t<rotation>horizontal</rotation>",
        "\t<players>2</players>",
        "\t<joystick>8-way</joystick>",
        '\t<buttons names="A,B,Game Select,Start,Coin,Enter,Channel Select,Service Coin,Reset" '
        'default="A,B,Back,Start,R,L,Y,X"/>',
    ]


def channel1(first, g, m):
    """Channel 1: the BIOS board (index 4, with this cart's INST ROM and RP5H01), the palette
    (index 3) and the cart (index 1)."""
    z = "|".join(zips_of(first, g))
    return [
        f'\t<rom index="4" zip="{z}" md5="None">',
        f"\t\t<!-- the BIOS board (PlayChoice10.sv, PC10_IDX_BIOS); channel 1 is {first} -->",
        *bios_rom(m),
        "\t</rom>",
        f'\t<rom index="3" zip="{z}" md5="None">',
        "\t\t<!-- the RP2C03's palette: NES_MiSTer's custom palette, widened in PlayChoice10.sv -->",
        *[part(r) for r in bios_part(m.findall("rom"), "ppu:palette")],
        "\t</rom>",
        f'\t<rom index="1" zip="{z}" md5="None">',
        "\t\t<!-- channel 1's cart -->",
        *cart_image(first, g, m),
        "\t</rom>",
    ]


def channel(s, g, m, n, idx_cart, idx_inst):
    """Channel n of 2-10: its cart (index 15 + n) and its INST ROM and RP5H01 (31 + n). n and
    the indices are strings, so the cabinet page can pass placeholders."""
    zs = "|".join(zips_of(s, g))
    return [f"\t<!-- channel {n}: {escape(g['desc']).replace('--', '-')} -->",
            f'\t<rom index="{idx_cart}" zip="{zs}" md5="None">', *cart_image(s, g, m), "\t</rom>",
            f'\t<rom index="{idx_inst}" zip="{zs}" md5="None">', *inst_prom(m), "\t</rom>"]


def footer():
    return [*switches(), "</misterromdescription>", ""]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sets", nargs="*", default=["pc_smb"])
    ap.add_argument("--all", action="store_true", help="every set in the driver")
    ap.add_argument("--out", default=str(core_root() / "releases"))
    ap.add_argument("--cabinet", metavar="TITLE",
                    help="one .mra holding every set given, channel 1 first (at most 10)")
    a = ap.parse_args()
    games = driver_games()
    mv = mame_version()
    if not mv:
        raise SystemExit("MAME does not answer -version")
    if a.all:
        a.sets = sorted(n for n in games if n != "playch10")
    xml = listxml(a.sets)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    jobs = [(a.sets, a.cabinet)] if a.cabinet else [([s], None) for s in a.sets]
    if a.cabinet and len(a.sets) > 10:
        raise SystemExit("ten channels at most")
    for sets, title in jobs:
        text = build(sets, games, xml, mv, title)
        if text is None:
            print(f"skip  {sets[0]}: board {games[sets[0]]['config']} has no mapper yet")
            continue
        g0 = games[sets[0]]
        safe = lambda t: re.sub(r'[\\/:*?"<>|]', "-", t)  # noqa: E731
        d = out
        if not title and g0["parent"] != "playch10":
            # a clone: under _alternatives/_<its parent's game>, as the contribution rules ask
            d = out / "_alternatives" / ("_" + safe(games[g0["parent"]]["desc"].replace(" (PlayChoice-10)", "")))
            d.mkdir(parents=True, exist_ok=True)
        p = d / (safe(title or g0["desc"]) + ".mra")
        p.write_text(text, encoding="utf-8")
        print(f"wrote {p}")


if __name__ == "__main__":
    main()
