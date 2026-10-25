#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# PlayChoice-10: copy one set's OSD settings to every other PlayChoice-10 set.
#
# Each .mra has its game's MAME setname (pc_smb, pc_miket, ...), and Main_MiSTer keeps the OSD
# settings (config/<setname>.CFG) and the joystick maps (config/inputs/<setname>_input_*.map)
# per setname. Set the core up once in one game, run this from the Scripts menu, and every
# setname used by a PlayChoice-10 .mra on the SD card (cabinets' playch10 included) gets the
# same settings. DIP switches are kept per .mra and are not touched.
#
# Copy to /media/fat/Scripts on the SD card.

CFG="${PC10_CONFIG:-/media/fat/config}"
ARCADE="${PC10_ARCADE:-/media/fat/_Arcade}"

# every setname in a PlayChoice-10 .mra
targets=$(find "$ARCADE" -name '*.mra' -print0 2>/dev/null \
	| xargs -0 grep -l '<rbf>PlayChoice10</rbf>' 2>/dev/null \
	| while IFS= read -r f; do sed -n 's:.*<setname>\([A-Za-z0-9_]*\)</setname>.*:\1:p' "$f"; done \
	| sort -u)
if [ -z "$targets" ]; then
	echo "No PlayChoice-10 .mra files under $ARCADE."
	exit 1
fi

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
