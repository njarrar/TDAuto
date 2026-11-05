#!/usr/bin/env bash
# PROTOTYPE - NOT FOR PRODUCTION. ADR-0012 R4: a copy of this prototype changed
# only to renderer/rendering_method="gl_compatibility".
# Usage: ./make_compat_copy.sh   (makes ../adr-0011-render-budget-compat, replacing it)
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="$SRC/../adr-0011-render-budget-compat"
rm -rf "$DST"
mkdir -p "$DST"
# Copy everything except the import cache and any old results.
(cd "$SRC" && tar --exclude='./.godot' -cf - .) | (cd "$DST" && tar -xf -)
P="$DST/project.godot"
sed -i.bak 's|^renderer/rendering_method=.*|renderer/rendering_method="gl_compatibility"|' "$P"
sed -i.bak 's|PackedStringArray("4.7", "Mobile")|PackedStringArray("4.7", "GL Compatibility")|' "$P"
# A separate app name keeps the copy's user:// logs apart from the Mobile run.
sed -i.bak 's|^config/name=.*|config/name="adr-0011-render-budget-compat"|' "$P"
rm -f "$P.bak"
echo "Copy made: $DST"
echo "Changed lines:"
diff "$SRC/project.godot" "$P" || true
