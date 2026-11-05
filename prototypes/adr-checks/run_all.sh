#!/usr/bin/env bash
# PROTOTYPE - NOT FOR PRODUCTION. Runs every ADR check script headless.
# Usage: GODOT=/path/to/godot ./run_all.sh   (GODOT defaults to "godot")
# Each script's output goes to results/<script>.log. One script failing to
# parse or crashing does not stop the others.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-godot}"
OUT="$DIR/results"
mkdir -p "$OUT"

# A missing binary is not a parse error: stop before any script runs.
if ! command -v "$GODOT" > /dev/null 2>&1; then
	echo "GODOT not found or not executable: $GODOT" >&2
	echo "Set it to the editor binary, e.g. GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./run_all.sh" >&2
	exit 2
fi

SCRIPTS="check_callables.gd check_signals.gd check_numerics.gd check_json.gd check_types.gd check_files.gd check_harness.gd check_signals_nohold.gd"

# Import first so the class_name stubs are in the class cache. The first
# import of a fresh project has crashed on exit (139) before: retry once.
# Probes in types/probes/ that are meant not to parse print errors here.
"$GODOT" --headless --path "$DIR" --import > "$OUT/import.log" 2>&1
code=$?
if [ "$code" -ne 0 ]; then
	echo "import exit $code, retrying once" | tee -a "$OUT/import.log"
	"$GODOT" --headless --path "$DIR" --import >> "$OUT/import.log" 2>&1
	echo "import retry exit $?" | tee -a "$OUT/import.log"
fi

for s in $SCRIPTS; do
	log="$OUT/$s.log"
	echo "=== $s"
	"$GODOT" --headless --path "$DIR" -s "res://$s" 2>&1 | tee "$log"
	code=${PIPESTATUS[0]}
	echo "EXIT $code" >> "$log"
	if ! grep -q '^RESULT ' "$log"; then
		echo "RESULT $s NOT_RUN no RESULT lines, likely a parse error; see the log (exit $code)" | tee -a "$log"
	elif ! grep -q "^END $s" "$log"; then
		echo "RESULT $s INCOMPLETE stopped before END (exit $code; a crash if 128 or more)" | tee -a "$log"
	fi
done

echo
echo "=== Summary ($("$GODOT" --version 2>/dev/null | head -n 1))"
grep -h '^RESULT ' "$OUT"/*.gd.log > "$OUT/summary.txt"
for st in PASS FAIL RECORD NOT_RUN INCOMPLETE; do
	n=$(grep -c "^RESULT [^ ]* $st " "$OUT/summary.txt")
	echo "$st: $n"
done
echo
grep -E '^RESULT [^ ]* (FAIL|NOT_RUN|INCOMPLETE) ' "$OUT/summary.txt"
echo "All RESULT lines: $OUT/summary.txt"
