# ADR-0001 checks (V2 teardown timing, V3 editor leg)

PROTOTYPE - NOT FOR PRODUCTION. A small standalone Godot 4.7 project. Nothing in
`src/` may load or copy from it.

## What it tests

ADR-0001 (`docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md`),
Engine Compatibility, V2 and the editor half of V3.

Hypothesis: after `wrapper.detach()`, `remove_child(wrapper)` and
`wrapper.queue_free()`, no `_process`, `_input`, `_unhandled_input` or
`_gui_input` of the old wrapper subtree fires again, the old battle, its sims
and its resolver are freed at once, and the wrapper is freed one frame later.
`ResourceLoader.load()` returns null for a missing path and for a broken scene,
and never crashes.

Status: **not yet run.** Written without an editor. If a script shows an error
when you open the project, copy the error into Notes below and tell the session.

Findings: none yet. They go in the results table at the end.

## Files

| File | What it does |
|---|---|
| `v2_main.tscn`, `v2_main.gd` | Main scene. Builds a fake battle (5 sims, a resolver) and a fake wrapper (2 probe nodes, a large Button), tears down as ADR-0001 Decision 7 steps 4 and 5, logs `TEARDOWN`, `AFTER` (callbacks that still fired) and `WEAKREF` (refs still alive) lines |
| `fake_battle.gd`, `fake_wrapper.gd`, `probe_node.gd`, `probe_button.gd`, `counter.gd` | The stand-ins |
| `v3_main.tscn`, `v3_main.gd` | Loads and instantiates each scene in `broken/`, logs result and error count per step |
| `broken/` | `broken_script.tscn` (script does not parse), `missing_ext.tscn` (missing texture file), `missing_sub.tscn` (missing sub-resource), `good.tscn` (control case). The path `does_not_exist.tscn` is missing on purpose |
| `error_counter.gd` | Logger that counts engine errors (4.5+ API, copied from `adr-checks/types/`) |

Do not open the scenes in `broken/` in the editor and never save them: the
editor may offer to fix them.

## How to run it (macOS)

`<godot>` is `/Applications/Godot.app/Contents/MacOS/Godot`.

V2, automatic (also works headless as the two-frame integration leg):

```
cd prototypes/adr-0001-checks
<godot> --headless --path . --import
<godot> --headless --path . > results-v2-headless.txt 2>&1
```

It tears down at frames 60, 180 and 300 and quits at frame 420.

V2, manual with a Control under the pointer (windowed):

1. `<godot> --path . > results-v2-window.txt 2>&1` (or open the project in the
   editor and press F5).
2. Put the pointer on the big button and keep moving it a little until the
   window shows gen 4 (after frame 300).
3. With the pointer still on the button, press R five times, slowly.
4. Click the button five times (the teardown then starts inside the Button's
   own `pressed` signal chain, as Retry will).
5. Close the window. The log is also in
   `~/Library/Application Support/Godot/app_userdata/adr-0001-checks/adr0001_v2_log.txt`.

V3, editor leg:

1. Open the project in the editor (Project Manager, Import). Import errors
   about `broken/` are expected; copy them into Notes.
2. Open `v3_main.tscn` and press F6 (Run Current Scene).
3. Copy the Output panel and the Debugger > Errors tab. The log is also in
   `adr0001_v3_log.txt` in the same user folder.
4. Also run it outside the editor: `<godot> --path . res://v3_main.tscn > results-v3-window.txt 2>&1`.

## Results

Date: `<date>`  OS and CPU: macOS, arm64  `godot --version`: `<paste>`

| ADR item | What to record | Result | Notes |
|---|---|---|---|
| ADR-0001 V2 (headless) | `AFTER ... fired=[]` on frame+1 to +3 for each teardown? `WEAKREF same_frame alive=` (expected only `wrapper`), `frame+1 alive=` (expected empty) | | |
| ADR-0001 V2 (window, auto) | Same, while the pointer moves over the button | | |
| ADR-0001 V2 (window, key R over Control) | Same; any error or crash in Output | | |
| ADR-0001 V2 (window, click) | Same; does the old button get `_gui_input` after teardown? | | |
| ADR-0001 V3 missing path | `LOAD ... result=`, errors, last error text | | |
| ADR-0001 V3 broken script | `LOAD` result; `INSTANTIATE` result and `script=` | | |
| ADR-0001 V3 missing ext resource | `LOAD` and `INSTANTIATE` lines | | |
| ADR-0001 V3 missing sub-resource | `LOAD` and `INSTANTIATE` lines | | |
| ADR-0001 V3 good scene (control) | `LOAD` PackedScene, `INSTANTIATE` Control | | |
| ADR-0001 V3 editor vs plain run | Any difference between F6 in the editor and the terminal run | | |

The Android leg of V3 and V4 are not here (first Android export).
