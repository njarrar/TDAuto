PROTOTYPE - NOT FOR PRODUCTION

# ADR-0007 harness check (verification procedures V1 to V7)

- **Hypothesis**: gdUnit4 6.2.0 on Godot 4.7.2 gives the exit codes, error capture and
  import behaviour ADR-0007 assumes, and the lint's engine-side facts hold.
- **How to run**: the Set-up below, then each item V1 to V7 in order.
- **Status**: in-progress (no run yet).
- **Findings**: none yet; record each item's result below it and in `current-best-practices.md`.

Throwaway material for `docs/architecture/adr-0007-headless-test-harness-gdunit4-layer-lint.md`.
Nothing here is game code and nothing here is committed to `src/` or `tests/`. Each item is run
by the user; godot-specialist writes the scripts and records each result, with the date, OS,
engine build (`godot --version`) and gdUnit4 version, in
`docs/engine-reference/godot/current-best-practices.md` (Command Line section). Where a result
takes a branch, ADR-0007 is revised first. One mutation per run: never batch two seeded faults.

`<godot>` is the editor binary (`project.yaml` `engine.path`). `<cmd>` is the test command:

```
<godot> --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

## Set-up

1. Make this folder a Godot project: `project.godot` (`config_version=5`, the name
   `adr-0007-harness-check`), and copy `addons/gdUnit4/` (6.2.0) from the repo root.
2. Add `tests/` with the suites each item names. Run `<godot> --headless --path . --import` first.
3. Keep every run's console output in `results/<item>-<n>.txt` here.

The main project ignores this folder once `prototypes/.gdignore` exists (ADR-0007 cascade).

## V1. Exit ladder (gdUnit4 6.2.0 on 4.7.2)

On the user's Mac, one run per row, with `tests/` holding only the named suite:

| Run | Suite | Expect |
|---|---|---|
| 1 | one passing test | 0 |
| 2 | one failing assertion | 100 |
| 3 | a test that adds a `Node` and never frees it (`[gdunit4] report/verbose_orphans=true`) | 101 |
| 4 | a suite with a syntax error | 105 |
| 5 | no suites | 0 and `No test cases found` (not a pass) |
| 6 | run 1 without `--ignoreHeadlessMode` | 103 |
| 7 | two failing tests, without `-c`, then with `-c` | record how many ran each time |
| 8 | run 1 plus a non-suite script in `tests/helpers/` | 0; the helper is not run as a suite |
| 9 | run 1 plus a helper with a parse error preloaded by the suite | record the exit (expected 105) |

The Linux x86-64 leg runs on CI through V5's scratch branch (runs 1 to 5 there).

## V2. Error capture headless

Project setting `[gdunit4] report/godot/push_error=true` except in (d). One suite per case:

- (a) `push_error("x")`, no assertion: the test fails.
- (b) `await assert_error(func(): push_error("x")).is_push_error("x")`: passes.
- (c) a callable that pushes `"x"` twice, one assertion: fails (one left over).
- (d) setting off, case (a): passes.
- (e) a second `connect` of the same method Callable; `get_node("missing")`: each fails a test.
  Copy down the recorded text; tests never assert engine-error text.
- (f) `push_warning("w")`: fails the test.
- (g) `push_error` inside a method reached through a method Callable called in the asserted lambda: caught.
- (h) an integration test that instantiates a scene of default `Control`, `Label` and `Panel`
  nodes headless: record every engine warning or error raised (these would fail SCENE-1).

## V3. The recording fake's listener

A script with signals of zero, one and six typed parameters (one declared `StringName`):
connect `func(...args)` to each and emit. Record: argument counts received; `typeof` of an
argument emitted as `&"a"` (expected `TYPE_STRING_NAME`) and as `"a"` into the `StringName`
parameter (expected `TYPE_STRING`); the `args[i].type` values from `get_script_signal_list()`.
Run it beside ADR-0006 V1 and V2.

## V4. Import on a fresh clone

1. `git clone` the repo into a scratch directory outside the repo.
2. In the clone only, add one passing suite under `tests/unit/` (never committed).
3. Run `<cmd>` with no import: record exit and output.
4. Run `<godot> --headless --path . --import`, then `<cmd>`: expect 0 with one test run.
   Exit 0 with `No test cases found` is a failed check, not a pass.
5. Repeat the import ten times; record any exit above 128.
6. Add a script with a new `class_name`, import, and confirm the class appears in
   `.godot/global_script_class_cache.cfg`. Delete the clone afterwards.

## V5. The CI action

The user pushes a scratch branch (not `main`) four times, one change each: a failing test; a
leaked node; a parse error; `tests/unit` and `tests/integration` with no suites. Per push record:
whether `godot-gdunit-labs/gdUnit4-action@v1` ran an import step, the runner's exit code in the
log, whether the job went red, and the JUnit XML path and its `tests=` value. Also V1 runs 1 to 5.
Delete the branch afterwards.

## V6. Lint engine facts

One `extends SceneTree` script, run with `<godot> --headless --path . -s res://v6.gd`:

- `RegEx.create_from_string("(?<![\\w.])floor\\s*\\(", true)` matches `floor(x)` and not
  `.floor(` or `floorf(`.
- `DirAccess` lists a nested `res://` tree headless.
- `ClassDB.class_exists(n)` for every `n` found by scanning `class_name <Name>` in
  `docs/architecture/adr-*.md` of the main repo (copy the list in at run time; never hand-type
  it), and for `Node`, `Input`, `Engine` as controls (expected true).
- Save, in the editor, a scene with one signal connected: confirm a line starting
  `[connection signal=`.
- In the main project after `prototypes/.gdignore` is added and an import: no `prototypes/` path
  in `.godot/` files. Before it: record whether any appears.

## V7. Export preset file

In a copy of the main project, create one Android preset in the editor with a debug keystore
password. Read `export_presets.cfg`: the key of the non-resource include filter (expected
`include_filter`), the exclude key (expected `exclude_filter`), whether `tests/*` written there
excludes `res://tests/` (export once and list the package), and whether the keystore password
is in `export_presets.cfg` or in `.godot/export_credentials.cfg` (expected the latter).
