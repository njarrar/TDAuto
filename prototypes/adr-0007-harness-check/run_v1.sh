#!/usr/bin/env bash
# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V1 exit ladder (gdUnit4 6.2.0).
# Usage: GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./run_v1.sh [label]
# With no label it runs every case in order, one run each. Output per run:
# results/v1-<label>.txt (with IMPORT_EXIT and EXIT lines); summary in
# results/v1-summary.txt.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-godot}"
OUT="$DIR/results"
ONLY="${1:-}"
mkdir -p "$OUT"
if ! command -v "$GODOT" > /dev/null 2>&1; then
	echo "GODOT not found: $GODOT" >&2
	exit 2
fi
if [ ! -f "$DIR/addons/gdUnit4/plugin.cfg" ]; then
	mkdir -p "$DIR/addons"
	cp -R "$DIR/../../addons/gdUnit4" "$DIR/addons/"
fi
echo "gdUnit4 $(grep '^version=' "$DIR/addons/gdUnit4/plugin.cfg"); $("$GODOT" --version | head -n 1)" | tee "$OUT/v1-summary.txt"

run_case() {
	label="$1"
	src="$2"
	shift 2
	if [ -n "$ONLY" ] && [ "$ONLY" != "$label" ]; then
		return
	fi
	rm -rf "$DIR/tests" "$DIR/reports"
	mkdir -p "$DIR/tests"
	if [ -n "$src" ]; then
		cp -R "$DIR/cases/$src/." "$DIR/tests/"
	fi
	log="$OUT/v1-$label.txt"
	echo "=== $label: case=${src:-none} flags=$*" > "$log"
	(cd "$DIR" && "$GODOT" --headless --path . --import) >> "$log" 2>&1
	echo "IMPORT_EXIT $?" >> "$log"
	(cd "$DIR" && "$GODOT" --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests "$@") >> "$log" 2>&1
	code=$?
	echo "EXIT $code" >> "$log"
	none="no"
	if grep -q "No test cases found" "$log"; then
		none="yes"
	fi
	echo "$label exit=$code no_test_cases_found=$none" | tee -a "$OUT/v1-summary.txt"
}

run_case run1 run1 --ignoreHeadlessMode
run_case run2 run2 --ignoreHeadlessMode
run_case run3 run3 --ignoreHeadlessMode
run_case run3b run3b --ignoreHeadlessMode
run_case run4 run4 --ignoreHeadlessMode
run_case run5 "" --ignoreHeadlessMode
run_case run6 run1
run_case run7a run7 --ignoreHeadlessMode
run_case run7b run7 --ignoreHeadlessMode -c
run_case run8 run8 --ignoreHeadlessMode
run_case run9 run9 --ignoreHeadlessMode
rm -rf "$DIR/tests"
echo "Logs: $OUT/v1-*.txt"
