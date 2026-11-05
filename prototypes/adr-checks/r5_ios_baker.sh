#!/usr/bin/env bash
# PROTOTYPE - NOT FOR PRODUCTION. ADR-0012 R5: Shader Baker in a throwaway iOS preset.
# Needs the 4.7.2 iOS export templates and, for the export step, a Mac with Xcode.
# The preset lives only in the throwaway copy, never in the main project.
#
#   GODOT=... ./r5_ios_baker.sh prepare   copy the render-budget prototype to ~/r5-ios-project
#   (by hand: add the iOS preset in the editor, see DESKTOP-RUN.md)
#   GODOT=... ./r5_ios_baker.sh read      print the preset's baker keys (names only matter)
#   GODOT=... ./r5_ios_baker.sh export    export with the baker off, then on, and print sizes
#   ./r5_ios_baker.sh clean               delete the copy
#
# BAKER_KEY is the key to flip. Default is the 4.5 name, UNVERIFIED for 4.7.2:
# step "read" prints every key that mentions baker or shader so the real name is seen.
set -u
MODE="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../adr-0011-render-budget"
PROJ="$HOME/r5-ios-project"
GODOT="${GODOT:-godot}"
BAKER_KEY="${BAKER_KEY:-shader_baker/enabled}"
PRESET="iOS"
CFG="$PROJ/export_presets.cfg"

case "$MODE" in
prepare)
	rm -rf "$PROJ"
	mkdir -p "$PROJ"
	(cd "$SRC" && tar --exclude='./.godot' -cf - .) | (cd "$PROJ" && tar -xf -)
	echo "Copy made: $PROJ"
	echo "Next: open it in the editor and add the iOS preset (see DESKTOP-RUN.md step R5)."
	;;
read)
	if [ ! -f "$CFG" ]; then
		echo "no $CFG: add the iOS preset in the editor first"
		exit 2
	fi
	echo "== preset names and platforms"
	grep -nE '^(name|platform)=' "$CFG"
	echo "== keys that mention baker or shader (with values; none of these is a secret)"
	grep -niE 'baker|shader' "$CFG" || echo "NONE: the preset has no baker or shader key (Decision 6: no baker step)"
	echo "== renderer of the project"
	grep -n 'rendering_method' "$PROJ/project.godot"
	;;
export)
	if [ ! -f "$CFG" ]; then
		echo "no $CFG: add the iOS preset in the editor first"
		exit 2
	fi
	if ! grep -q "^$BAKER_KEY=" "$CFG"; then
		echo "key $BAKER_KEY not in the preset. Run 'read', then rerun with BAKER_KEY=<the key it printed>."
		exit 3
	fi
	"$GODOT" --headless --path "$PROJ" --import > "$PROJ/r5-import.log" 2>&1
	for state in false true; do
		sed -i.bak "s|^$BAKER_KEY=.*|$BAKER_KEY=$state|" "$CFG"
		rm -f "$CFG.bak"
		OUT="$PROJ/out-baker-$state"
		rm -rf "$OUT"
		mkdir -p "$OUT"
		echo "== export with $BAKER_KEY=$state"
		"$GODOT" --headless --path "$PROJ" --export-debug "$PRESET" "$OUT/r5.ipa" > "$PROJ/r5-export-$state.log" 2>&1
		echo "exit $?"
		tail -n 8 "$PROJ/r5-export-$state.log"
		echo "size_kb $state: $(du -sk "$OUT" | cut -f1)"
	done
	;;
clean)
	rm -rf "$PROJ"
	echo "removed $PROJ"
	;;
*)
	echo "usage: GODOT=... $0 prepare|read|export|clean" >&2
	exit 64
	;;
esac
