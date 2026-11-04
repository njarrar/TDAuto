# ADR-0010 checks (V3 desktop: where user:// lands)

PROTOTYPE - NOT FOR PRODUCTION. A small standalone Godot 4.7 project. Nothing in
`src/` may load or copy from it.

## What it tests

ADR-0010 (`docs/architecture/adr-0010-sim-input-split-command-result-codes-dev-telemetry.md`),
Verification items, V3 (desktop). The headless items of ADR-0010 live in
`prototypes/adr-checks/`.

Hypothesis: a windowed debug run with `application/config/use_custom_user_dir`
at its default writes `user://adr0010_v3.txt` to
`~/Library/Application Support/Godot/app_userdata/adr-0010-checks/`, the same
folder `OS.get_user_data_dir()` prints.

Status: **not yet run.** Written without an editor.

Findings: none yet. They go in the results table at the end.

## How to run it (macOS)

1. `cd prototypes/adr-0010-checks`
2. `/Applications/Godot.app/Contents/MacOS/Godot --path . > results-v3.txt 2>&1`
   A window shows five `RESULT` lines. Close it.
3. In Finder, Go > Go to Folder, paste the `user_data_dir=` value, and check
   that `adr0010_v3.txt` is there and holds the `line=` text.
   Or: `cat "$HOME/Library/Application Support/Godot/app_userdata/adr-0010-checks/adr0010_v3.txt"`.
4. Optional: run it once more from the editor (F5) and check it is the same folder.

## Results

Date: `<date>`  OS and CPU: macOS, arm64  `godot --version`: `<paste>`

| ADR item | What to record | Result | Notes |
|---|---|---|---|
| ADR-0010 V3 (desktop) | `user_data_dir=`; `file=`; `stored=true`; file found there with the line (yes or no); editor run same folder (yes, no, not run) | | |

The Android leg (V3 Android) runs after acceptance on the first phone build.
