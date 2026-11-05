#!/usr/bin/env bash
# PROTOTYPE - NOT FOR PRODUCTION. ADR-0007 V4: import on a fresh clone.
# Usage: GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./v4_fresh_clone.sh
# Clones the repo (committed state only) to $DEST, adds one passing suite and
# one class_name script there (never committed), and logs each step to
# results/v4.txt. Deletes the clone at the end unless KEEP=1.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-godot}"
DEST="${DEST:-$HOME/towerriot-v4-clone}"
LOG="$HERE/results/v4.txt"
mkdir -p "$HERE/results"
if ! command -v "$GODOT" > /dev/null 2>&1; then
	echo "GODOT not found: $GODOT" >&2
	exit 2
fi
if [ -e "$DEST" ]; then
	echo "$DEST exists; delete it or set DEST" >&2
	exit 2
fi
git clone --quiet "$REPO" "$DEST" || exit 2
cd "$DEST" || exit 2
echo "=== V4 $(date) clone=$DEST commit=$(git rev-parse --short HEAD) $("$GODOT" --version | head -n 1)" | tee "$LOG"
mkdir -p tests/unit/v4
printf 'extends GdUnitTestSuite\n\n\nfunc test_clone_suite_runs() -> void:\n\tassert_int(2 + 2).is_equal(4)\n' > tests/unit/v4/v4_clone_test.gd

run_tests() {
	"$GODOT" --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode > "$HERE/results/v4-$1.txt" 2>&1
	code=$?
	seen="no"
	if grep -q "v4_clone_test" "$HERE/results/v4-$1.txt"; then
		seen="yes"
	fi
	none="no"
	if grep -q "No test cases found" "$HERE/results/v4-$1.txt"; then
		none="yes"
	fi
	echo "STEP $1 exit=$code v4_suite_in_output=$seen no_test_cases_found=$none" | tee -a "$LOG"
}

echo "STEP 3 run with no import" | tee -a "$LOG"
run_tests noimport
echo "STEP 4 import, then run" | tee -a "$LOG"
"$GODOT" --headless --path . --import > "$HERE/results/v4-import1.txt" 2>&1
echo "STEP 4 import exit=$?" | tee -a "$LOG"
run_tests withimport
echo "STEP 5 ten imports" | tee -a "$LOG"
for i in 1 2 3 4 5 6 7 8 9 10; do
	"$GODOT" --headless --path . --import > /dev/null 2>&1
	echo "STEP 5 import $i exit=$?" | tee -a "$LOG"
done
echo "STEP 6 new class_name reaches the cache" | tee -a "$LOG"
mkdir -p src/v4_probe
printf 'class_name V4ProbeClass\nextends RefCounted\n' > src/v4_probe/v4_probe.gd
"$GODOT" --headless --path . --import > "$HERE/results/v4-import-class.txt" 2>&1
echo "STEP 6 import exit=$?" | tee -a "$LOG"
if grep -q "V4ProbeClass" .godot/global_script_class_cache.cfg 2> /dev/null; then
	echo "STEP 6 V4ProbeClass in cache: yes" | tee -a "$LOG"
else
	echo "STEP 6 V4ProbeClass in cache: no" | tee -a "$LOG"
fi
cd "$HERE" || exit 2
if [ "${KEEP:-0}" != "1" ]; then
	case "$DEST" in
		*towerriot-v4*) rm -rf "$DEST" && echo "clone deleted" | tee -a "$LOG" ;;
		*) echo "clone kept (DEST name has no towerriot-v4): delete $DEST by hand" | tee -a "$LOG" ;;
	esac
fi
