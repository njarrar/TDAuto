# ADR-0007 harness check: desktop runs (V1, V4, V7)

PROTOTYPE - NOT FOR PRODUCTION. Run steps for the procedures in `README.md` in
this folder. Nothing here is game code.

## What it tests

ADR-0007 (`docs/architecture/adr-0007-headless-test-harness-gdunit4-layer-lint.md`),
Verification items V1, V4 and V7, on the user's Mac. V2, V5 and the editor parts
of V6 are not here.

Hypothesis: gdUnit4 6.2.0 on Godot 4.7.2 gives the exit codes in `README.md` V1,
a fresh clone runs its suites only after `--import`, and Godot keeps keystore
passwords out of `export_presets.cfg`.

Status: **not yet run.** Scripts written without a Godot binary.

Findings: none yet. They go in the results table at the end.

## Files

| File | What it does |
|---|---|
| `project.godot` | The throwaway project (`[gdunit4] report/verbose_orphans=true`) |
| `cases/run*/` | One `tests/` folder per V1 run |
| `run_v1.sh` | Copies `addons/gdUnit4` from the repo root once, then per run: empties `tests/`, copies one case, imports, runs the test command, logs the exit |
| `v4_fresh_clone.sh` | V4 steps 1 to 6 in a clone at `~/towerriot-v4-clone`, deleted at the end |
| `v7_read.sh` | Reads the two preset files and prints keys only, never values |

## How to run it (macOS)

`export GODOT=/Applications/Godot.app/Contents/MacOS/Godot` first.

V1 (about 11 runs, one mutation each):

```
cd prototypes/adr-0007-harness-check
./run_v1.sh            # or ./run_v1.sh run4 for one run
```

Paste `results/v1-summary.txt`. For run7a and run7b also count how many tests
ran in `results/v1-run7a.txt` and `v1-run7b.txt`. For run8, check the helper is
not listed as a suite.

V4:

```
./v4_fresh_clone.sh
```

Paste `results/v4.txt`. The repo already has suites in `tests/unit/`, so expect
more than one test; the check is that the V4 suite appears and the exit is 0.

V7 (editor, about 10 minutes):

1. `git clone /path/to/TDAuto ~/towerriot-v7-clone` (a copy of the main project).
2. Open `~/towerriot-v7-clone/project.godot` in the editor.
3. Project > Export > Add... > Android. In Resources, set "Filters to export
   non-resource files" to `*.txt` and "Filters to exclude files" to `tests/*`.
   In Keystore, set Debug User `v7user` and Debug Password `v7-dummy-pass`
   (a dummy, never a real one). Close the dialog.
4. Export once: Export PCK/ZIP... to `~/v7.zip` (it needs the Android export
   templates; if the editor refuses, write that in Notes and skip to step 5).
5. `./v7_read.sh ~/towerriot-v7-clone ~/v7.zip` and paste the output.
6. Delete `~/towerriot-v7-clone` and `~/v7.zip`.

## Results

Date: `<date>`  OS and CPU: macOS, arm64  `godot --version`: `<paste>`  gdUnit4: 6.2.0

| ADR item | Run | Expect | Exit and output | Notes |
|---|---|---|---|---|
| ADR-0007 V1 | run1 pass | 0 | | |
| ADR-0007 V1 | run2 fail | 100 | | |
| ADR-0007 V1 | run3 orphan | 101 | | |
| ADR-0007 V1 | run3b fail and orphan | 100 | | |
| ADR-0007 V1 | run4 syntax error | 105 | | |
| ADR-0007 V1 | run5 no suites | 0 and `No test cases found` | | |
| ADR-0007 V1 | run6 no `--ignoreHeadlessMode` | 103 | | |
| ADR-0007 V1 | run7a / run7b two fails, without and with `-c` | tests run: 1 / 2 | | |
| ADR-0007 V1 | run8 helper in `tests/helpers/` | 0, helper not a suite | | |
| ADR-0007 V1 | run9 broken preloaded helper | 105 | | |
| ADR-0007 V4 | no import / import / ten imports / class cache | see README V4 | | |
| ADR-0007 V7 | `include_filter` and `exclude_filter` keys; `tests/` in package; password file | `include_filter`, `exclude_filter`, none, `.godot/export_credentials.cfg` | | |
