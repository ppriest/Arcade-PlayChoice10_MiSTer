#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Write tools/cabinet_builder.html: a page, run from disk with no network, that builds a
PlayChoice-10 cabinet .mra from up to ten games in any order.

    python scripts/build_cabinet_page.py

Every game's .mra pieces come from scripts/build_mra.py (header, channel1, channel, footer)
with placeholders the page's script fills, so a cabinet made on the page is line for line the
one `build_mra.py --cabinet` writes. Rerun after any change to build_mra.py or a new MAME.
"""
import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_mra as bm   # noqa: E402
from coretools import core_root, mame_version   # noqa: E402

TEMPLATE = Path(__file__).resolve().parent / "cabinet_page.template.html"
EXAMPLE = ["pc_smb", "pc_smb3", "pc_mtoid"]     # shown on first open


def main():
    games = bm.driver_games()
    mv = bm.mame_version() if hasattr(bm, "mame_version") else mame_version()
    if not mv:
        raise SystemExit("MAME does not answer -version")
    sets = sorted(n for n in games if n != "playch10")
    xml = bm.listxml(sets)
    out = []
    for s in sets:
        g, m = games[s], xml[s]
        if bm.cart_image(s, g, m) is None:
            print(f"skip  {s}: board {g['config']} has no mapper yet")
            continue
        out.append({
            "set": s,
            "name": g["desc"].replace(" (PlayChoice-10)", "").replace(", PlayChoice-10)", ")"),
            "desc": g["desc"],
            "year": g["year"],
            "maker": bm.escape(g["maker"]),
            "makerText": g["maker"],
            "zips": bm.zips_of(s, g),
            "ch1": "\n".join(bm.channel1(s, g, m)),
            "chn": "\n".join(bm.channel(s, g, m, "@N@", "@CART@", "@INST@")),
        })
    out.sort(key=lambda d: d["name"].lower())
    header = bm.header("@TITLE@", {"year": "@YEAR@", "maker": "@MAKER@"}, mv)
    data = {
        "header": "\n".join(header),
        "footer": "\n".join(bm.footer()),
        "games": out,
        "example": EXAMPLE,
    }
    # inside <script type="application/json">: only "</" could end the element early
    blob = json.dumps(data, separators=(",", ":")).replace("</", "<\\/")
    page = TEMPLATE.read_text(encoding="utf-8")
    page = page.replace("/*DATA*/", blob).replace("@MAMEVER@", html.escape(mv))
    dest = core_root() / "tools" / "cabinet_builder.html"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(page, encoding="utf-8", newline="\n")
    print(f"wrote {dest} ({len(out)} games, {len(page) // 1024} KB)")


if __name__ == "__main__":
    main()
