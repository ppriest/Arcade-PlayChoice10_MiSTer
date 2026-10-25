#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# PlayChoice-10: copy one set's OSD settings to every other PlayChoice-10 set.
#
# Each .mra has its game's MAME setname (pc_smb, pc_miket, ...), and Main_MiSTer keeps the OSD
# settings (config/<setname>.CFG) and the joystick maps (config/inputs/<setname>_input_*.map)
# per setname. Set the core up once in one game, run this from the Scripts menu, and every
# PlayChoice-10 setname (cabinets' playch10 included) gets the same settings. DIP switches are
# kept per .mra and are not touched.
#
# Copy to /media/fat/Scripts on the SD card.

CFG="${PC10_CONFIG:-/media/fat/config}"

# The setnames releases/*.mra use (build_mra.py), plus any other pc_* CFG already saved, such as
# a cabinet given its own setname. Scanning _Arcade instead takes minutes on a full card.
SETS="playch10 pc_1942 pc_bball pc_bfght pc_bload pc_bstar pc_cntra pc_cshwk pc_cvnia pc_dbldr
pc_ddrgn pc_drmro pc_duckh pc_ebike pc_ftqst pc_gntlt pc_golf pc_goons pc_grdue pc_grdus pc_hgaly
pc_kngfu pc_mario pc_miket pc_mman3 pc_moglf pc_mtoid pc_ngai2 pc_ngai3 pc_ngaid pc_pinbt pc_pwbld
pc_pwrst pc_radr2 pc_radrc pc_rcpam pc_rkats pc_rnatk pc_rrngr pc_rygar pc_sjetm pc_smb pc_smb2
pc_smb3 pc_suprc pc_tbowl pc_tenis pc_tkfld pc_tmnt pc_tmnt2 pc_trjan pc_ttoon pc_vball pc_virus
pc_wcup pc_wgnmn pc_ynoid"
targets=$( { for t in $SETS; do echo "$t"; done
	for f in "$CFG"/pc_*.CFG; do [ -f "$f" ] && basename "$f" .CFG; done; } | sort -u)

# the suggestion: the most recently changed PlayChoice-10 CFG
suggest=""
for f in $(ls -t "$CFG"/*.CFG 2>/dev/null); do
	n=$(basename "$f" .CFG)
	if echo "$targets" | grep -qx "$n"; then suggest="$n"; break; fi
done

echo "PlayChoice-10: copy one set's settings to all $(echo "$targets" | wc -l) PlayChoice-10 sets."
echo
read -r -p "Copy from setname [${suggest:-none}]: " src
src="${src:-$suggest}"
if [ -z "$src" ] || [ ! -f "$CFG/$src.CFG" ]; then
	echo "No settings file $CFG/$src.CFG: run that game and change a setting first."
	exit 1
fi

maps=$(ls "$CFG/inputs/${src}_input_"* "$CFG/inputs/${src}_advanced_input_"* 2>/dev/null)
echo
echo "From $src: $src.CFG and $(echo -n "$maps" | grep -c .) joystick map(s)."
read -r -p "Overwrite the other sets' settings? [y/N] " ok
case "$ok" in y|Y) ;; *) echo "Nothing changed."; exit 0 ;; esac

n=0
for t in $targets; do
	[ "$t" = "$src" ] && continue
	cp "$CFG/$src.CFG" "$CFG/$t.CFG" || continue
	for m in $maps; do
		cp "$m" "$CFG/inputs/$t${m#"$CFG/inputs/$src"}"
	done
	n=$((n + 1))
done
sync
echo "Copied to $n sets."
