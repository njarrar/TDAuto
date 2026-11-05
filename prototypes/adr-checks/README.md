PROTOTYPE - NOT FOR PRODUCTION

# ADR checks (headless verification scripts, Part 2 group A)

- **Hypothesis**: Godot 4.7.2 behaves as the "expected" text of each verification
  item below says. Any other result takes the branch that item's ADR names.
- **How to run**: see "How to run" below. One command runs every script.
- **Status**: run once on macOS arm64, 2026-11-04 (Mac16,10, Godot 4.7.2 editor binary,
  headless). 186 RESULT lines, 2 FAIL, 0 NOT_RUN. Evidence:
  `production/qa/evidence/adr-checks-mac-2026-11-04.txt`.
- **Findings**: see "Findings" below. Every result is recorded in
  `docs/engine-reference/godot/verification-results.md`, and each ADR item has a
  Result line that points there.

A small standalone Godot 4.7 project (`project.godot`, `config_version=5`, no
autoloads, no main scene). Nothing in `src/` or `tests/` may load or copy from it.
The main project ignores it through `prototypes/.gdignore`; this project opens on
its own with `--path`.

This one folder replaces `prototypes/adr-0006-signal-check/` and
`prototypes/adr-0010-checks/` (headless items only), as named in the ADR text.
ADR-0010 V3 (where `user://` lands) is a windowed desktop run and is not here;
`check_files.gd` only prints `OS.get_user_data_dir()` as a hint.

## What each script covers

| Script | ADR items |
|---|---|
| `check_callables.gd` | ADR-0001 V1 (method Callable, signal connection, lambda capture, `bind()`, lambda binding `self`, Builder-style cycles); ADR-0009 V5 (reaped enemy with Health, Status, ReadContext freed; all freed on retry) |
| `check_signals.gd` | ADR-0006 V1 to V5; ADR-0008 V1 (a), (b), (c), (d) with the self-hold, (e); ADR-0007 V3 |
| `check_signals_nohold.gd` | ADR-0008 V1 (d) without the self-hold. May crash: runs alone and last |
| `check_numerics.gd` | ADR-0004 V4 desktop leg (binary64, 64-bit int, typed math, `to_ticks` Validation 3 values, `SimRng` golden values, `BattleClock` Validation 1 and jitter, `round()` and CPU architecture records, debug unwinding); ADR-0004 V9 (key read only); ADR-0009 V1, V3; ADR-0008 V2, V3 |
| `check_json.gd` | ADR-0002 W1 (number types, `NaN`/`Infinity` tokens, duplicate key, BOM in a string and in a file, JSON `null`, `make_read_only`); W3 (sort at every level, equal snapshots, full precision and one-ulp change) |
| `check_types.gd` | ADR-0009 V2, V6, V7; ADR-0006 V6; ADR-0008 V4, V5, V6; ADR-0010 V4; ADR-0011 V6 |
| `check_files.gd` | ADR-0008 V7, V8; ADR-0010 V1, V2 (one run closes both) |
| `check_harness.gd` | ADR-0007 V6 headless parts (regex lookbehind, DirAccess, `ClassDB.class_exists` over every `class_name` in `docs/architecture/adr-*.md`, `[connection signal=` token through `ResourceSaver`) |

Not covered here:
- ADR-0007 V2 (needs gdUnit4: see `prototypes/adr-0007-harness-check/README.md`).
- From ADR-0007 V6: the editor save of a scene and the main-project `.godot/` scan.
  `check_harness.gd` saves the scene with `ResourceSaver`, not the editor.
- ADR-0009 V2 (f): array capacity cannot be read from GDScript, so it is recorded
  as not observable.

## How the scripts work

- Each script `extends SceneTree`, runs in `_initialize()` and prints one line per item:
  `RESULT <ADR>-<item> <PASS|FAIL|RECORD> <observed> | expected: <expected>`.
  RECORD lines only record a value. A script exits 0 if it has no FAIL, else 1,
  and prints `END <script>` last.
- No assertions. One failure never hides the rest.
- `types/report.gd` prints the lines. `types/error_counter.gd` is a `Logger`
  (4.5+ API, signature not in the pinned reference) that counts engine and script
  errors. If it does not load, error counts print `n/a` and the checks still run.
- `check_types.gd` names no stub class itself. The stubs in `types/` and the
  probes in `types/probes/` are loaded with `load()`, so a script that does not
  parse becomes a RESULT line, not a stopped run.
- Warnings: `project.godot` raises `int_as_enum_without_cast` and
  `int_as_enum_without_match` to errors. Each warning probe has a twin with
  `@warning_ignore`. If the plain probe fails to load and its twin loads, the
  observed value is "warning". If both fail, it is "hard error".
- Some probes are meant not to parse (`enum_override_no_return.gd`,
  `enum_override_null.gd`, `fake_resolver_no_return.gd`, maybe
  `variance_static.gd`, `enemy_no_super.gd` and some warning probes). Their errors
  in `results/import.log` and in the logs are expected.
- `check_harness.gd` reads the ADRs at `../../docs/architecture/` from this
  folder, so keep the folder at `prototypes/adr-checks/`.
- Files are written only under `user://adr_checks/` and removed at the end.

## How to run

Mac:

```
cd prototypes/adr-checks
GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./run_all.sh
```

Linux (the editor binary by its path, or `godot` on `PATH`):

```
cd prototypes/adr-checks
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 ./run_all.sh
```

`run_all.sh` first runs `--import` (it retries once if the import exits non-zero,
for example the known 139 crash on exit). Then it runs each script with
`"$GODOT" --headless --path <this folder> -s res://<script>`. Output goes to
`results/<script>.log`, with an `EXIT <code>` line. If a script prints no RESULT
line, the runner adds `RESULT <script> NOT_RUN parse error`. If it stops before
`END`, the runner adds `RESULT <script> INCOMPLETE` (a crash if the exit is 128 or more).
The summary counts the lines and lists every FAIL, NOT_RUN and INCOMPLETE line.
All RESULT lines are also in `results/summary.txt`.

One script by hand: `"$GODOT" --headless --path . -s res://check_numerics.gd`.

## Findings (2026-11-04, macOS arm64)

- ADR-0001 V1: method Callables and connections hold an ID only; lambdas and
  `bind()` hold strongly; a lambda that never uses `self` does not keep it alive; a
  lambda cycle leaks. The design holds. `lambda-release` (captured object still alive
  after the lambda is dropped) needs a second look: the check may still hold a
  reference. Tests only; lambdas are banned in `src/`.
- ADR-0002 W1: numbers are `float`; `NaN` and `Infinity` are parse errors; a duplicate
  key keeps the last value silently (CI scan stays); `get_file_as_string` strips a
  file's BOM, so the `bom_present` check is dropped; `make_read_only()` works. W3 passes.
- ADR-0004 V4 desktop leg and V9 pass; `round()` is half away from zero; arm64. After a
  runtime error in debug the callee stops and the caller continues.
- ADR-0006 V1 to V6 pass or record with no branch: no type check at emit, silent
  conversion into typed params, depth-first nested emits, snapshot during emit.
- ADR-0007 V3 and V6 (headless parts) pass. ADR-0008 V1 to V8 desktop pass; V1 (e)
  showed only the callee stops, so `recover_if_stuck` is kept for release.
- ADR-0009 V1, V2 (f not observable), V3, V5, V6 pass. ADR-0010 V1, V2 (debug), V4
  pass; V3 desktop path recorded. ADR-0011 V6 passes.

The two FAILs are engine facts, not script bugs. `ADR-0009-V7-no-super` and
`ADR-0009-V7-combat-no-forward` expected an error when a subclass `_init` skips
`super(...)`. Godot 4.7.2 gives none: the object builds and the parent's fields
keep their defaults. The scripts measured that correctly. The forwarding rule now
rests on lint INIT-1 (`docs/architecture/adr-0007-lint-rules.md`).

## Results

Date: 2026-11-04  OS and CPU: macOS, arm64 (Mac16,10)  `godot --version`: 4.7.2 editor binary (as pinned)

| ADR item | Script | Result (PASS / FAIL / RECORD value) | Branch taken or note |
|---|---|---|---|
| ADR-0001 V1 | check_callables | PASS (6), RECORD (6) | Design holds; lambda-release needs a second look |
| ADR-0009 V5 | check_callables | PASS | All freed on reap and retry |
| ADR-0006 V1 | check_signals | PASS; parse-time RECORD | No emit type check; analyzer does not check arity |
| ADR-0006 V2 | check_signals | PASS | Main form used |
| ADR-0006 V3 | check_signals | PASS | As expected |
| ADR-0006 V4 | check_signals | PASS; RECORD snapshot | Snapshot during emit |
| ADR-0006 V5 | check_signals | PASS; re-emit RECORD | Depth-first, no outbox |
| ADR-0006 V6 | check_types | PASS | No branch |
| ADR-0007 V3 | check_signals | PASS | Variadic fake works |
| ADR-0007 V6 (headless parts) | check_harness | PASS | No class_name collision |
| ADR-0008 V1 (a) to (e) | check_signals, check_signals_nohold | PASS (a to d); RECORD (d nohold, e) | (e): only the callee stopped |
| ADR-0008 V2 | check_numerics | PASS | |
| ADR-0008 V3 | check_numerics | PASS | |
| ADR-0008 V4 | check_types | PASS; RECORD warnings | Other enum is a hard error |
| ADR-0008 V5 | check_types | PASS | |
| ADR-0008 V6 | check_types | PASS | |
| ADR-0008 V7 | check_files | PASS | Model Mac16,10 |
| ADR-0008 V8 | check_files | PASS | |
| ADR-0002 W1 | check_json | PASS; RECORD tokens, dup key, BOM, read-only | BOM check dropped; dup-key scan stays |
| ADR-0002 W3 | check_json | PASS | |
| ADR-0004 V4 (desktop) | check_numerics | PASS; RECORD round, arch, unwind | Half away from zero; arm64 |
| ADR-0004 V9 (key read) | check_numerics | PASS | Key exists, default true |
| ADR-0009 V1 | check_numerics | PASS | 32-bit |
| ADR-0009 V2 | check_types | PASS; (f) RECORD | (g) passes |
| ADR-0009 V3 | check_numerics | PASS | |
| ADR-0009 V6 | check_types | PASS | No CombatTypes fallback |
| ADR-0009 V7 | check_types | FAIL (2) | Engine fact: no error without super(); lint INIT-1 |
| ADR-0010 V1 | check_files | PASS | get_open_error 7 |
| ADR-0010 V2 (editor half) | check_files | PASS | |
| ADR-0010 V4 | check_types | PASS; keys RECORD | Use find_key, not keys()[v] |
| ADR-0011 V6 | check_types | PASS | |
