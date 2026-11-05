# Desktop run: every ADR desktop check in one sitting

PROTOTYPE - NOT FOR PRODUCTION. One ordered checklist for macOS arm64 with
Godot 4.7.2. About 90 minutes. Each folder's README has the details and the
results table.

Before you start:

```
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /path/to/TDAuto/prototypes
$GODOT --version
```

If any project shows a script error when it opens or runs, copy the error
text and go on with the next step. Do not fix it.

## Checklist

0. **The game's own tests, lint and a first launch** (from the repo root, not
   `prototypes/`). Run these first: the code has never been parsed, so parse
   errors show up here.
   - Import once: `cd /path/to/TDAuto && $GODOT --headless --path . --import > import.log 2>&1`
   - Lint: `$GODOT --headless --path . -s res://tools/lint/run_lint.gd > lint.log 2>&1`
   - Tests: `$GODOT --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode > tests.log 2>&1`
   - Launch: `$GODOT --path .` and play the starter stage for a minute, then close it.
   Paste: the end of `tests.log` (the summary and every failure), every
   `ERROR` or `SCRIPT ERROR` line from `import.log`, `lint.log` and the launch,
   and one line on what the launch showed. Then `cd prototypes` for step 1.

1. **Headless checks again** (after the session's fixes):
   `cd adr-checks && GODOT=$GODOT ./run_all.sh; cd ..`
   Paste: the Summary block and every FAIL, NOT_RUN or INCOMPLETE line.
2. **ADR-0001 V2 headless**: `cd adr-0001-checks && $GODOT --headless --path . --import > /dev/null 2>&1; $GODOT --headless --path . > results-v2-headless.txt 2>&1; cd ..`
   Paste: `results-v2-headless.txt`.
3. **ADR-0001 V2 windowed** (pointer on the button): README "V2, manual".
   Paste: `results-v2-window.txt`.
4. **ADR-0001 V3 editor leg**: README "V3, editor leg", F6 on `v3_main.tscn`, then the terminal run.
   Paste: the Output panel text, the Errors tab, and `results-v3-window.txt`.
5. **ADR-0010 V3**: `cd adr-0010-checks && $GODOT --path . > results-v3.txt 2>&1; cd ..`, then find the file.
   Paste: `results-v3.txt` and "file found: yes or no".
6. **ADR-0004 SP14** (spike): open `adr-0003-device-spike` in the editor, open
   `sp14_stall.tscn`, F6. Press Stall 300 ms, Stall 1000 ms, then Cadence 10 s
   and do not touch anything for 10 s. Close. Then Project Settings >
   Application > Run > Delta Smoothing off (Advanced Settings on), F6 again,
   same three presses, close, and set Delta Smoothing back on (do not keep
   the change). Paste: both `sp14_log.txt` runs (Copy log button, or the file
   in `~/Library/Application Support/Godot/app_userdata/ADR-0003 device spike/`).
7. **ADR-0011 V1 to V5**: README "How to run it" in `adr-0011-render-budget`.
   Paste: `results-desktop.txt` (or `adr0011_log.txt`) and attach the
   screenshots from `~/Library/Application Support/Godot/app_userdata/adr-0011-render-budget/`.
8. **ADR-0007 V1**: `cd adr-0007-harness-check && ./run_v1.sh`.
   Paste: `results/v1-summary.txt` and the test counts for run7a and run7b.
9. **ADR-0007 V4**: `./v4_fresh_clone.sh`. Paste: `results/v4.txt`.
10. **ADR-0007 V7**: `DESKTOP.md` V7 steps 1 to 6 in the editor.
    Paste: the `v7_read.sh` output (it never prints values).
11. Fill in `Date`, `godot --version` and each results table, or paste the
    files and let the session fill them.

12. **ADR-0012 R1 to R5** (Mac, windowed unless noted). `$GODOT` as above.
    Start every evidence file with the `RUNINFO` line the probe prints.
    - **R1, ADR-0011 kit**: `cd adr-0011-render-budget && $GODOT --path . res://r1_run.tscn`.
      Wait 70 s, then close. Compare the `RUNINFO` line with the engine's Output
      banner (renderer, driver, GPU). Paste `user://run_probe_log.txt`
      (`~/Library/Application Support/Godot/app_userdata/adr-0011-render-budget/`):
      the `RUNINFO` line and the `R1 frame=` and `R1 nonzero` lines. Any field
      that reads `unknown` that the banner shows: copy the banner value.
    - **R1, ADR-0003 kit**: `cd ../adr-0003-device-spike && $GODOT --path . res://r1_spike.tscn`.
      Wait 10 s, close. Paste its `run_probe_log.txt` the same way
      (`.../app_userdata/ADR-0003 device spike/`).
    - **R2 (headless)**: `cd ../adr-checks && $GODOT --headless --path . --import > /dev/null 2>&1; $GODOT --headless --path . -s res://check_project_keys.gd`.
      Paste every `RESULT R2-` line, then name the Branch (A, B or C) or "none".
    - **R3 (cap on the desktop)**: in `adr-0003-device-spike`, run
      `$GODOT --path . --max-fps 60 res://r3_sp14.tscn`. Press Cadence 10 s, touch
      nothing for 10 s, close. Paste both logs: `sp14_log.txt` (the `DISPLAY` and
      `CADENCE` lines) and the `RUNINFO` line (`max_fps=60` must show). Repeat on
      any display above 60 Hz you can drive (move the window to it, or use the
      120 Hz ProMotion panel); write "none available" if there is none.
    - **R4 (renderer baseline)**: in `adr-0011-render-budget`:
      1. `$GODOT --path . res://r1_run.tscn`. Within the first 5 s do nothing
         (the cold-start line prints at 5 s). Press 6, press R, wait for two
         `R4 window` lines, press 7, press R, wait for two more. Press P once
         for the draw calls line of the main log. Close.
         Paste `run_probe_log.txt` and `adr0011_log.txt`.
      2. `./make_compat_copy.sh`, then `cd ../adr-0011-render-budget-compat`
         and repeat step 1 there (same keys). Paste both logs again, labelled
         Compatibility. Check `method=gl_compatibility` in its `RUNINFO` line.
      If Mobile fails to start or draws wrongly, stop and say so (escalation).
    - **R5 (Shader Baker, needs the 4.7.2 iOS export templates)**:
      `cd ../adr-checks && GODOT=$GODOT ./r5_ios_baker.sh prepare`. Open
      `~/r5-ios-project/project.godot` in the editor, Project > Export > Add... >
      iOS; set a dummy Bundle Identifier (`com.example.r5`) and a dummy App Store
      Team ID, look in the options for a Shader Baker entry (note its exact label,
      whether it is shown, and its default), save and close.
      `GODOT=$GODOT ./r5_ios_baker.sh read` and paste the output.
      If it lists a baker key whose name is not `shader_baker/enabled`, rerun the next
      step with `BAKER_KEY=<that key>`. Then `GODOT=$GODOT ./r5_ios_baker.sh export`
      and paste the output (exit codes and `size_kb` lines; if Xcode export
      fails, paste the log tail and say so). Finish with `./r5_ios_baker.sh clean`.

## What to paste back

One message per step, in order, starting with the step number. Logs as text,
not screenshots, except ADR-0011 V3 and V4, where the screenshots are the result.
Keep copies of all logs and screenshots; the session moves them to
`production/qa/evidence/`.
