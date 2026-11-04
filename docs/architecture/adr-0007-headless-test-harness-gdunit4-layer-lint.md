# ADR-0007: Headless Test Harness, gdUnit4 and Layer Lint

## Status
Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. Route: `/architecture-decision accept ADR-0007`.

## Date
2026-11-04

## Last Verified
2026-11-04 (engine reference of 2026-10-17 and gdUnit4 6.2.0 source; nothing run)

## Decision Makers
- Author: `/architecture-decision` in autonomous mode (decisions logged in `production/session-logs/decision-log.md`)
- Reviews still owed: godot-specialist (Step 5.5), technical-director TD-ADR (Step 5.6)
- Acceptance: the user

## Summary
ADR-0001 to ADR-0006 hand this ADR over 60 named tests, five engine probe sets, a recording spy, recording fakes, a listener-count test, ten lint IDs and about 30 more lint rules in prose, and GDScript itself has no module walls to keep layers apart. This ADR fixes one headless harness: gdUnit4 6.2.0 run by one shell script in CI and on desktops, code-built fixtures and hand-written recording fakes under `tests/helpers/`, push_error reporting on, a token lint written in GDScript and run by Godot headless (42 rules, L-LAYER-1 to L-TEST-4), an engine probe suite in `tests/unit/engine/`, and a fixed list of manual evidence for what cannot run headless.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned), gdUnit4 6.2.0 (committed in `addons/gdUnit4/`) |
| **Domain** | Core (scripting, test and CI tooling) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM: the test runner and GDScript rules are post-cutoff (4.5 rest parameters and `@abstract`, 4.7 typed-override return and packed-array setter change); gdUnit4 6.2.x lists Godot 4.5 to 4.7.1, not 4.7.2 |
| **References Consulted** | Engine reference `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (GDScript, Tooling, Command Line); `godot-parse-check.gd`; gdUnit4 6.2.0 source (settings, error monitor, runners, suite scanner, error assert); the tracked class cache; `architecture.md` v4; `tr-registry.yaml`; ADR-0001 to ADR-0006 by section; the registry; coding-standards, test-standards, run-and-observe; `tests/README.md`; `tests.yml`; `project.godot` |
| **Post-Cutoff APIs Used** | gdUnit4 6.2.0 on 4.7.2; gdUnit4's error monitor subclasses `Logger` with `ScriptBacktrace` (4.5); rest parameters `...args` in fakes (4.5); `@abstract` (4.5, ADR-0005 `StatKeys`); typed-override return rule (4.7) |
| **Verification Required** | H1 to H9 (Validation Criteria). H1 (exit codes of 6.2.0 on 4.7.2), H2 (push_error counting) and H7 (Linux download) gate the CI story; the others gate the rule they back |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006 (all Accepted 2026-11-04). Each names tests, probes or lints that this ADR places |
| **Enables** | ADR-0008, ADR-0009, ADR-0010, ADR-0011 (their tests use these helpers and lints); `/create-control-manifest` (the QQ-15 rules); `/test-setup` refresh (QQ-13) |
| **Blocks** | Every story with automated test evidence; the CI and lint stories in Migration Plan. No story file exists yet under `production/epics/` |
| **Ordering Note** | The CI story (Migration 1 to 4) comes before the first Logic story, so the first test runs under the final command. ADR-0003 spike S0a may run before it, since S0a is a prototype outside `src/` |

## Context

### Problem Statement
Six Accepted ADRs say "ADR-0007 places them" for tests (ADR-0001 V1 to V8, ADR-0002 V1 to X2, ADR-0003 A1 to A11, ADR-0004 V1 to V14, ADR-0005 V1 to P1, ADR-0006 V1 to E6), lints, and helpers named by role. None has a home, a runner or a pass rule. GDScript has no module walls and every `class_name` is global (dependency rule 6), so layer rules hold only if a tool checks them. The runner's exit codes, push_error handling and fresh-clone import are known from observation, not docs. The first Logic story waits on all of this.

### Current State
- `addons/gdUnit4/` holds 6.2.0; the plugin is not enabled, and the command-line runner does not need it.
- `.godot/global_script_class_cache.cfg` is tracked in git and lists 202 gdUnit4 classes, among them short global names: `Comparator`, `Fuzzer`, `LocalTime`, `ValueProvider`, `ErrorLogEntry`, `RPC`, `XmlElement`.
- `tests.yml` runs `gdUnit4-action@v1` (`version: installed`) with no lint, no parse check and no rule for exit 101.
- `tests/README.md` still says gdUnit4 is not installed (QQ-13). `tests/unit/` and `tests/integration/` hold only placeholders. `src/` holds no code.
- `project.godot` has no `gdunit4/` settings, so push_error reporting is off (default `false` in `GdUnitSettings.gd`).

### Constraints
- Linux CI and the macOS dev machine run the same command and pass rule.
- Unit tests read no files, load no scene, use no random seed and assert no time (coding-standards, test-standards, TR-data-012, TR-enemy-014).
- No autoloads (ADR-0001), so helpers are plain scripts, never singletons.
- A test may not hold a battle object in a gdUnit assert before its weakref check (ADR-0001 Validation Criteria preamble).
- Nothing in `tests/` or `tools/ci/` ships: export presets exclude both (ADR-0002 Decision 8).
- One part-time developer: one lint tool, one runner script, no new language in the toolchain.

### Requirements
- Host every handed-over test, probe, helper and lint under one naming scheme.
- Fail CI on a test failure, orphan, parse error, lint hit, empty run or crash.
- Count push_error calls exactly (TR-combat-012).
- One named lint per rule, each with a planted-sample test (ADR-0006 V8).
- Answer QQ-13, QQ-15, QQ-16.

## Decision

### 1. Runner and CI job (QQ-13)
- **gdUnit4 6.2.0 stays pinned** as committed. The reference observed 6.2.2 on 4.7.2, so probe H1 proves 6.2.0 before the CI story closes. An upgrade is its own story.
- **`tools/ci/run_tests.sh` is the only test entry**, in CI and on desktops. `GODOT` names the binary (default `godot`; macOS uses `engine.path` from `project.yaml`). Each step stops the run on failure:
  1. **Import**: `"$GODOT" --headless --path . --import`, every run. Exit 139 gets one retry (3 crashes in 17 fresh imports on 4.7.x, per the reference).
  2. **Parse check**: `"$GODOT" --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- <every .gd in src/, tests/, tools/ci/>`. Never `--check-only`.
  3. **Lint**: `"$GODOT" --headless --path . -s res://tools/ci/lint/lint_main.gd`: 0 clean, 1 hits, 2 lint crash.
  4. **Tests**: `"$GODOT" --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c`. `-c` keeps going after a failure; reports land in `res://reports/`.
  5. **Exit map**: 0 passes, unless the output says `No test cases found` while a suite exists. **101 fails**: an orphan is a leak, and ADR-0001's retry proof needs leaks loud. 100, 103, 104, 105, 1 and any other code fail. The two `ERROR:` lines about port `127.0.0.1:0` are expected.
- **CI** (`tests.yml`, job name `Run GdUnit4 Tests` kept): checkout; download `Godot_v4.7.2-stable_linux.x86_64.zip` from the godotengine GitHub release and check its SHA512 (names: H7); run the script; upload `reports/` with `if: always()`. The gdUnit4 action goes: its 101 handling and install step cannot be checked offline, and it would make CI differ from desktops.
- **Class cache**: `.godot/` leaves git. Step 1 rebuilds it, and a tracked cache churns on every `class_name` change.
- **Settings**: `project.godot` sets `gdunit4/report/godot/push_error=true`; `script_error` keeps its default `true`. The gdUnit4 editor plugin stays off in `project.godot`: if enabling it adds an autoload, L-APP-1 fails it.

### 2. Test tree and naming
```
tests/helpers/{fixtures,fakes,battle,asserts}/  shared helpers, no class_name
tests/fixtures/catalogue/      ADR-0002 V3 files (integration only)
tests/unit/<system>/           Logic; no file, scene or get_tree()
tests/unit/<system>/helpers/   optional (the Input GDD names one)
tests/unit/content/            ADR-0002 C2 broken-fixture tests
tests/unit/engine/             probes (Decision 7)
tests/unit/lint/               planted samples per lint rule
tests/integration/<system>/    scene tree, real files, multi-system
tests/integration/content/     ADR-0002 C1 and rules/
tests/integration/wiring/      ADR-0006 V1, V2 and battle_signals.gd
tests/integration/lint/        L-INPUT-2
tests/baselines/<os>_<arch>/   ADR-0004 digests (data)
tools/ci/                      run_tests.sh, lint/, export_smoke.gd
tools/ci/selftest/<case>/      planted suites for H1 to H3; skipped by steps 2 to 4
```
- `<system>` is the GDD slug in snake case (`data_config`, `input_gesture_resolver`, `game_state`, `combat`, `enemy_wave`, `tower`, `hero`, `battle_hud`) plus `app` (ADR-0001), `time` (ADR-0004), `input_adapter` (ADR-0003), `signals` (ADR-0006).
- **Files follow test-standards**: `<system>_<feature>_test.gd`, functions `test_<scenario>_<expected>`. Prior test IDs stay as function names. Proposed file names map: `test_content_real_data.gd` to `content_real_data_test.gd` (ADR-0002), `test_signal_probes.gd` to `signal_probe_test.gd` (ADR-0006). `rules/content_rules_*.gd` and `battle_signals.gd` are data and keep their names. gdUnit4 finds suites by base class, so L-TEST-4 enforces the names.
- Every suite `extends GdUnitTestSuite`. Every `Node` a test makes goes through `auto_free()`. A scene test awaits one `process_frame` before a weakref check.

### 3. Fixtures: code-built, no file I/O (TR-data-012, TR-enemy-014)
- `tests/helpers/fixtures/catalogue_fixtures.gd`: `base_documents()` gives the smallest valid `{source, type, records}` set (Tower with two levels, Enemy, Wave, Stage, Hero, Burst, Input); `with_field`, `without_field` and `with_record` return a deep copy with one change; `catalogue(docs)` calls `Catalogue.from_documents` and fails the test on any error; `base_texts()` is the same set as JSON text for `from_texts`. Values live in named `const` tables, multiples of 0.25 below 2^20 where sums are compared (Combat GDD).
- `tests/helpers/fixtures/stage_fixtures.gd`: stage geometry factories in field units (path points, slots, pin rect), as the Enemy & Wave, Tower and Hero GDDs define them.
- `tests/helpers/battle/battle_fixtures.gd`: `build(...)` calls `BattleBuilder.build` with a recording fatal handler and returns `{battle, fatal, sink}`, so the test holds the handler and sink throughout (ADR-0005 V2).
- Only `tests/integration/` reads files: `load_manifest` on the real data root (ADR-0002 C1) and on `res://tests/fixtures/catalogue/` (ADR-0002 V3). Lint L-TEST-2 bans file access in `tests/unit/`.

### 4. Recording fakes and spies (TR-input-014, TR-tower-014, TR-state-013)
All fakes are hand-written `RefCounted` scripts loaded by `preload`, never gdUnit4 `mock()` or `spy()`, and never `assert_signal` or `monitor_signals` (TR-input-014: those await and depend on timing; lint L-TEST-1).

| File (`tests/helpers/`) | Role and contract |
|---|---|
| `fakes/event_log.gd` | One ordered log per test: `add(name, args)`, `entries()`, `type_errors()` |
| `fakes/signal_recorder.gd` | `attach(emitter, names, wiring)` connects `_record.bind(name)` through a test-owned `Wiring`; `_record(...args)` checks count, `typeof()` and class per argument against `battle_signals.gd` and logs a mismatch to `type_errors()` rather than failing mid-emit |
| `fakes/spy_stat_accessor.gd` | ADR-0005 spy: `extends StatAccessor`, exact parameter lists, typed returns; logs each read; `set_value(def_id, key, value)`; `fire_fatal_on(n)` calls the held handler on read n and returns the fixture value plus 1000 |
| `fakes/fake_halt_gate.gd` | `halted()`, `set_halted(b)`, `halt_after(calls)` |
| `fakes/recording_fatal.gd` | `fatal(cause)`, `causes()` |
| `fakes/recording_dev_error_sink.gd` | `extends DevErrorSink`; `report(msg)` records and never calls `push_error` |
| `fakes/recording_resolver.gd` | The five resolver calls, logged (ADR-0003) |
| `fakes/command_spy.gd` | Step and command fakes that log and can command from a handler (ADR-0004 V2, V4; ADR-0006 V5) |
| `battle/battle_members.gd` | `emitters(battle)` by `get_property_list()` (ADR-0006 Decision 8 step 1) |
| `battle/battle_state.gd` | `take(battle)`: plain values from every read-only query, resolver registry excluded; `digest(battle)`: `var_to_bytes` of `take()`, exact bits (ADR-0004 V7) |
| `battle/weak_check.gd` | `refs(objects)`, `all_freed(refs)`; the caller drops its locals first |
| `battle/combat_invariant.gd` | Combat GDD invariant `I`: `check(log, combat, enemies) -> String`, empty when sums agree; ADR-0009 fixes the queries it reads |
| `asserts/log_asserts.gd` | `assert_log(test, log, expected)`: the entire log in order, and no `type_errors()` |

- A fake overriding a typed method keeps the exact parameter list and returns a value of that type on every path (4.7; `return 0`, `return 0.0`, never `return null` on a typed int or float).
- A fake records into an `Array` or `Dictionary` member, never by reassigning a captured local in a lambda (QQ-15).
- `typeof()` cannot tell an enum from an `int`; the recorder checks the enum bit against the table's `class_name` instead (ADR-0006 Decision 8 limits stand).

### 5. push_error: reported, counted, asserted (TR-combat-012)
- With `gdunit4/report/godot/push_error=true`, gdUnit4's `Logger` records each `push_error` (`GodotGdErrorMonitor.gd`); off, it records none and `is_push_error()` sees nothing. On, an unclaimed error fails the test. Read from 6.2.0 source, not run: H2 proves it.
- **Claim**: `await assert_error(func(): sut.bad_call()).is_push_error(EXPECTED_MESSAGE)`, awaited (the assert awaits `_execute()`). One claim takes one entry; a second identical error fails (H2 c). Silent cases use `await assert_error(callable).is_success()`.
- **Which**: one error from one call uses the real `DevErrorSink` (or app `FatalLatch`) and `is_push_error`, as TR-combat-012 asks. Order or count across calls injects `recording_dev_error_sink.gd` and asserts its log; no `push_error` fires. Script errors keep failing tests.

### 6. Lints: GDScript, token based, run by Godot headless
- **Tool**: `tools/ci/lint/lint_main.gd` (`extends SceneTree`, like `godot-parse-check.gd`) walks `src/`, `tests/` and `tools/ci/` (L-DATA-1 covers `src/` only) and tokenises each `.gd` with `gd_tokens.gd`. Tokens drop comments, keep each string literal whole and carry line numbers, so a name in a comment is no hit and a literal key (L-STAT-1) still shows.
- **Rules**: one file per family in `tools/ci/lint/rules/` (`layer`, `app`, `data`, `input`, `time`, `stat`, `signal`, `name`, `gd`, `test`). Each rule is a pure static `check(path, tokens, ctx)`, so `tests/unit/lint/<family>_rules_test.gd` tests it on planted text: one sample that hits, one that does not.
- **Scopes** live once in `tools/ci/lint/scopes.gd` (ADR-0004 review B4): `SIM = src/foundation, src/core, src/feature`; `RNG_EXEMPT = src/root/battle_builder.gd, src/root/battle_wrapper.gd`; the adapter, TapScreen, Wiring, wrapper, ResultScreen and RunLog paths; each folder's layer.
- **Reflection** in the same run: `ProjectSettings` (effective values, never file text), `ClassDB.class_exists()`, `ProjectSettings.get_global_class_list()`, and `StatKeys.ROWS` and record classes loaded from `src/`.
- **L-INPUT-2 runs as a test** (`tests/integration/lint/wrapper_mouse_filter_test.gd`): it builds a fixture battle and the wrapper and walks every `Control`.
- **Output**: `LINT <ID> <path>:<line> <message>` per hit, then a count per ID and every suppression in force.
- **Suppression**: `# lint-allow(<ID>): <reason>` on the line or the line above, reason required. L-LAYER-*, L-NAME-*, L-APP-1, L-RNG-1 and L-TEST-* never take one. The first expected one: `OS.has_feature("mobile")` in `input_adapter.gd` (L-TIME-1), which ADR-0003 A7 and fallback F2 need; it reads the platform, not time.
- **Root types other layers name**: `PresentationSettings` (typed by views) has its file in `src/foundation/`, so L-LAYER-2 passes; AppRoot still owns and fills it. Other root types reach layers only as Callables.
- **Known gaps**: the lint matches names, not types. It misses calls through `call()`, a string `Callable` or a renamed local, and `Vector2` operators on values it cannot see are `Vector2`. Review and the runtime tests (replay digest, read-only containers, listener test) back each gap.

**Lint list.** `src/` means all of it; `SIM` as above; "settings" means a `ProjectSettings` check.

| ID | Source | Scope | Fails on |
|---|---|---|---|
| L-LAYER-1 | arch rules 1, 6 | `src/` | A class name or `res://src/` path of a higher layer (Foundation < Core < Feature < Presentation < root) |
| L-LAYER-2 | arch rule 2; 0001 G2 | `src/` but `src/root/` | Any `src/root/` class, `AppRoot`, `BattleBuilder`, `Battle`, `BattleWrapper` included |
| L-LAYER-3 | arch rule 4 | `src/feature/` | `enemy_wave/`, `tower/`, `hero/` naming each other |
| L-LAYER-4 | 0002 D8 | `src/` | `res://tests/`, `res://addons/`, `res://tools/`, a `GdUnit` name |
| L-APP-1 | 0001 G1, V7 | settings | Any autoload; `run/main_scene` not resolving to `app_root.tscn` |
| L-APP-2 | 0001 G3; 0006 D1 | `src/` | `.connect(` outside `wiring.gd` (engine-node signals: suppress with reason) |
| L-APP-3 | 0001 G4 | Builder, wrapper | A lambda or `.bind(` |
| L-APP-4 | 0001 G12 | `src/root/` | `.free()` |
| L-APP-5 | 0001 G10 | `src/` | `assert(` |
| L-APP-6 | 0001 G16; 0003 G14; 0004 G11 | `src/` | Assigning `paused` on the tree |
| L-APP-7 | 0001 G17 | `src/` | `get_tree().create_tween(`, `create_timer(` |
| L-APP-8 | 0001 G14 | settings | `gui/theme/custom` or `custom_font` set |
| L-DATA-1 | 0002 G2 | `src/` | `DirAccess` |
| L-DATA-2 | 0002 G9 | `src/` but `src/foundation/data/` | On a receiver typed as a record class: a schema field assigned, or `append`, `push_back`, `erase`, `clear`, `insert`, `remove_at`, `sort`, `assign` on one |
| L-INPUT-1 | 0003 G2 | `src/` | `_input` or `_unhandled_input` outside `input_adapter.gd`; `_gui_input` outside `tap_screen.gd` |
| L-INPUT-2 | 0003 G9, G10 | wrapper scene (test) | A Control not IGNORE (TapScreen: not STOP); `focus_mode` not NONE; a full-rect wrapper root |
| L-INPUT-3 | 0003 G4 | `src/` | `device == 0`, `device != 0` |
| L-INPUT-4 | 0003 G8 | `src/`, `.tscn` | `Camera2D` |
| L-INPUT-5 | 0003 G12 | `src/` | `get_display_safe_area(` outside the wrapper |
| L-PROJ-1 | 0003 A11; 0004 G11, V11e | settings | A key of ADR-0003 Decision 1 or ADR-0004 Guideline 11 off its value |
| L-TIME-1 | 0004 G2 | `SIM` | `_process`, `_physics_process`, `Timer`, `await`, `Engine.`, `Time.`, `OS.`, `Input.flush_buffered_events`, `Input.parse_input_event`, `push_input(` |
| L-TIME-2 | 0004 G1, G2 | `src/` | `battle.tick(` outside the wrapper; `.tick(` with a number literal |
| L-TIME-3 | 0004 G6 | `src/` | `-=` then `dt`, `delta`, `TICK_SECONDS`, `tick_seconds()` |
| L-RNG-1 | 0004 D8 | `src/` but `RNG_EXEMPT` | Global `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed`, `rand_from_seed`; `.shuffle(`, `.pick_random(`; `RandomNumberGenerator.new(` |
| L-RNG-2 | 0004 D8 | `SIM` | `.randfn(` |
| L-VEC-1 | 0004 D9 | `SIM` | A `Vector2`, `Vector2i` or `Rect2` method by name (`length`, `distance_to`, `normalized`, `dot`, `lerp`, `has_point` and the list in the rule file); an operator on a local typed `Vector2`; `Curve2D`, `Path2D`, `PackedVector2Array` maths; transcendentals (`sin`, `cos`, `atan2`, `exp`, `log`, `pow` and the rest) |
| L-STAT-1 | 0005 G5 | `src/` | A string or `&"..."` literal key in `stat_int(` or `stat_float(` |
| L-STAT-2 | 0005 G1 | `src/` but `src/foundation/data/` | On a receiver typed as a tower level, enemy, hero or burst record: a read of a field `StatKeys.ROWS` lists |
| L-STAT-3 | 0005 G10 | `stat_accessor.gd`, `read_context.gd` | `assert(` (own ID; L-APP-5 also covers it) |
| L-STAT-4 | registry `read_context_per_read` (new ID) | `src/` | `ReadContext.new(` outside `_init` or a member initialiser |
| L-SIG-1 | 0006 G1 | `src/` | `emit_signal(`, `connect("`, `add_user_signal(` |
| L-SIG-2 | 0006 G2 | `src/` | `CONNECT_` flags; `call_deferred` on an emit; `await` on a battle signal; `tween_await(` |
| L-SIG-3 | 0006 G4 | `src/presentation/`, wrapper | Assigning a field of `flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`, `stat_accessor`, `halt_gate` |
| L-SIG-4 | 0006 G6 | `src/` | A `*_id` parameter or variable typed `String` |
| L-SIG-5 | 0006 G8 | ResultScreen, RunLog | Any sim member or sim class name |
| L-NAME-1 | QQ-16; 0005 E7 | `class_name` in `src/` | A name `ClassDB.class_exists()` knows or another script in `get_global_class_list()` declares |
| L-NAME-2 | QQ-16 | `tests/`, `tools/` | Any `class_name` |
| L-GD-1 | QQ-15 | `src/`, `tests/` | `arr[i] = v` on a property with a `set(` accessor in that file |
| L-TEST-1 | TR-input-014; 0004 V9 | `tests/` | `assert_signal(`, `monitor_signals(`, `set_time_factor(`, `create_timer(`, global RNG |
| L-TEST-2 | TR-data-012, TR-enemy-014 | `tests/unit/` | `FileAccess`, `DirAccess`, `load_manifest(`, a `.tscn` or `.scn` path, `get_tree()` |
| L-TEST-3 | 0001 Validation preamble | `tests/` | A `weakref(` target passed to an `assert_` call earlier in that function |
| L-TEST-4 | test-standards | `tests/unit/`, `tests/integration/` | A suite file not `*_test.gd`; a test function not `test_*` |

### 7. Engine probe suite
- **Location**: `tests/unit/engine/`, one file per handing ADR: `callable_ref_probe_test.gd` (ADR-0001 V1), `json_probe_test.gd` (ADR-0002 E1 to E3), `tick_probe_test.gd` (ADR-0004 V11a to V11e), `stat_probe_test.gd` (ADR-0005 E1, E3, E5, E7), `signal_probe_test.gd` (ADR-0006 E1 to E6), `harness_probe_test.gd` (this ADR's H2a, H5, H8, H9; H1 to H3 failure cases live in `tools/ci/selftest/`).
- **Shape**: a probe prints `PROBE <id> <answer>` and asserts nothing about which answer is right, as the handing ADRs say. The parts they mark must-pass (ADR-0001 V1 case f) assert.
- **Recording**: after a run on a new engine or gdUnit4 version, the story that ran it adds a row per probe to `docs/engine-reference/godot/probe-results.md` (probe ID, date, Godot version, gdUnit4 version, `OS.get_name()` and architecture, answer, test file), and adds a line to the doc each handing ADR names (`current-best-practices.md`, `modules/input.md`) where the answer changes guidance. A probe whose answer differs from the row on file is a review item, not a silent change.

### 8. Manual evidence: what cannot run headless
Each item is a story (Visual/Feel, UI, or Integration with a documented playtest) with screenshots or photos, the raw log and `stamp.txt` in `production/qa/evidence/<story-slug>/` (`run-and-observe.md`). Capture with `--write-movie` where a scene launch reaches the state; never `--headless`.

| ID | What | From | When |
|---|---|---|---|
| M1 | Spike S0a: parse probe, settings dump, S1, S2, S3, S5, S6, S9 on desktop | ADR-0003 | Before ADR-0004 and ADR-0008 stories rest on them |
| M2 | Spike S0b: S1, S2, S4, S5, S7, S8, TapScreen on an Android phone | ADR-0003 | First phone build |
| M3 | UI evidence: 540x960 and resized, Paused on alt-tab, Lost and Won block the field; phone letterbox, insets, back swipe, 50 taps give 50 `tapped` | ADR-0003 | Each UI story |
| M4 | V8: release export with one bad record shows the fatal screen; `push_error` line in the device log; `disable_stderr` and file-logging values | ADR-0001 | First phone build |
| M5 | X2: Android debug build reaches Ready with counts; release build fatal screen | ADR-0002 | Technical Setup gate |
| M6 | P1 load timing (five cold launches) and P2 edit-to-run time | ADR-0002 | First phone build |
| M7 | V13: p95 tick cost, frame time at 60 and 30 fps, 90 or 120 Hz pacing | ADR-0004 | First phone build |
| M8 | P1 device run of `bench_stat_reads` against 2.0 ms p95 per tick | ADR-0005 | First phone build |
| M9 | Draw calls and frame time against the 60-call budget | ADR-0011 | First phone build |

- **Headless but outside the test job**: ADR-0002 X1 `ci_export_smoke` needs export templates, so it runs from `tools/ci/` at the Technical Setup gate and then on release tags, as ADR-0002 Decision 8 says.
- Everything else the six ADRs name runs headless in `run_tests.sh`, including ADR-0001 V6 and ADR-0006 V2 as scene-tree integration tests. If V2 cannot build the wrapper headless (a `DisplayServer` call at build), the wrapper must take that value by injection; V2 does not move to manual.

### 9. GDScript 4.7 rules for the control manifest (QQ-15)
**Required**
- R1 An override of a method with a typed return returns a value of that type on every path (4.7). The parse check (step 2) catches a missing `return` if H4 confirms it is a parse error.
- R2 To change one element of a packed-array property whose setter must run, build the new array and assign the whole property (4.7).
- R3 State a lambda must change lives in an `Array`, `Dictionary` or object member; lambdas capture locals by value.
- R4 Every battle signal has a row in `battle_signals.gd`; recording fakes check count, `typeof()` and class per argument, because `emit()` does not check types.
- R5 A rest parameter is written `...name: Array` (or untyped), last in the list.
- R6 Test helpers load by `const X := preload("res://tests/helpers/...")`.

**Forbidden**
- F1 Relying on a setter to run for `arr[i] = v` on a packed array (L-GD-1).
- F2 Assigning to a captured outer local inside a lambda (review; H5 decides whether a warning can be raised to an error).
- F3 Trusting a signal's declared parameter types as a runtime check.
- F4 `return null` in an override typed `int`, `float` or `bool`; `--check-only` as a parse check.
- F5 `class_name` in `tests/` or `tools/` (L-NAME-2).

### 10. Class names (QQ-16)
No prefix; the short names in ADR-0001 to ADR-0006 stay. L-NAME-1 fails a clash by name on every run, so an engine or addon upgrade that adds a class shows at once, and it extends ADR-0005 E7 (engine classes) to script classes. Whether the 4.7.2 parser also rejects a clash is unverified offline (memory says it does); L-NAME-1 holds either way. Taken today: every gdUnit4 global (`Comparator`, `Fuzzer`, `LocalTime`, `ValueProvider`, `ErrorLogEntry`, `RPC`, `XmlElement`, the `Gd` and `GdUnit` names). A class a future clash forces to rename takes a `Tr` prefix; no other class changes.

### Architecture Diagram
```
 tools/ci/run_tests.sh  (CI job "Run GdUnit4 Tests" and desktops: same script)
   1 --import (retry once on 139) -> .godot/ class cache (untracked)
   2 godot-parse-check.gd ---------> every .gd in src/ tests/ tools/ci/
   3 lint_main.gd -+- gd_tokens -> rules/*.gd (pure) -> LINT <ID> path:line
                   +- ProjectSettings | ClassDB | global classes | StatKeys
   4 GdUnitCmdTool.gd -a res://tests -c --> reports/ (JUnit XML)
        tests/unit/<system>   fixtures + fakes from tests/helpers (preload)
        tests/unit/engine     probes -> PROBE lines -> probe-results.md (by story)
        tests/unit/lint       planted samples -> rules/*.gd
        tests/integration/*   real data, scene tree, wiring, L-INPUT-2
   5 exit map: 0 pass (non-empty run) | 100 101 103 104 105 1 other: fail
 manual: M1 to M9 -> production/qa/evidence/<story-slug>/ (+ stamp.txt)
```

### Key Interfaces
```gdscript
# tools/ci/lint/rules/<family>_rules.gd (no class_name; preload)
static func check(path: String, tokens: Array, ctx: Dictionary) -> Array[Dictionary]  # {id, path, line, message}
# tools/ci/lint/gd_tokens.gd
static func tokenize(text: String) -> Array  # [{kind, text, line}], comments dropped
# tests/helpers/fixtures/catalogue_fixtures.gd
static func base_documents() -> Array[Dictionary]
static func catalogue(docs: Array[Dictionary]) -> Catalogue
# tests/helpers/battle/battle_fixtures.gd ([] means base_documents())
static func build(docs: Array[Dictionary] = [], stage_id: StringName = &"fixture_stage", rng_seed: int = 1) -> Dictionary  # {battle, fatal, sink}
```
Names are proposed. The spy copies ADR-0005's `stat_int` and `stat_float` signatures exactly; the rest of each helper's contract is the Decision 4 table.

### Implementation Guidelines
1. Tests must run only through `tools/ci/run_tests.sh`, in CI and on desktops.
2. A run must fail on any exit but 0, on 101, and on `No test cases found` once suites exist; `--import` must run first every time, with one retry on 139.
3. Unit tests must never read a file, load a scene, call `get_tree()`, draw a random number or assert a time.
4. Logic tests must build catalogues only through `catalogue_fixtures.gd`.
5. Tests must record signals only into an `EventLog` through the Decision 4 fakes, and must never use `assert_signal`, `monitor_signals`, `mock()` or `spy()`.
6. A THEN must compare the entire log in order (`assert_log`) with no `type_errors()`.
7. An expected `push_error` must be claimed with `await assert_error(...).is_push_error(msg)`; `gdunit4/report/godot/push_error` must stay `true`.
8. A test must hold its spy, fatal handler and sink for its whole run, must never pass a battle or sim object to an assert before its weakref check, and must free every `Node` it makes.
9. A fake overriding a typed method must keep the parameter list and return a typed value on every path.
10. Every lint rule must be a pure function with a hitting and a clean planted sample; scopes and exempt files must live only in `scopes.gd`.
11. A suppression must name its ID and a reason; layer, name, autoload, RNG and test rules must never be suppressed.
12. Probes must print `PROBE <id> <answer>`, assert only must-pass cases, and have results recorded in `probe-results.md`.
13. Manual evidence must sit in `production/qa/evidence/<story-slug>/` with `stamp.txt`.
14. `tests/` and `tools/` must hold no `class_name`; helpers load by `preload`.

## Alternatives Considered

### Alternative 1: Keep the gdUnit4 GitHub Action
- **Description**: Leave `gdUnit4-action@v1` and add lint and parse steps beside it.
- **Pros**: No install step to write; it publishes a check run.
- **Cons**: Its handling of 101 and of an empty run cannot be checked offline; it installs its own Godot; desktops would run a different command.
- **Rejection Reason**: The pass rule must live in code the project owns and runs the same way everywhere.

### Alternative 2: Shell or Python regex lint
- **Description**: `grep` or Python over `src/`.
- **Pros**: Fast; no engine boot.
- **Cons**: Cannot see effective settings, `ClassDB`, global classes, `StatKeys.ROWS` or a built scene; a second language; hits names in comments and strings.
- **Rejection Reason**: A third of the rules need the engine's view.

### Alternative 3: gdtoolkit parse-based lint
- **Description**: A real syntax tree from the gdtoolkit Python parser.
- **Pros**: Exact syntax, fewer false hits.
- **Cons**: Its grammar for 4.5+ syntax is unverified offline; a lagging parser blocks CI on valid code; still no types.
- **Rejection Reason**: CI risk with no gain on the type gaps.

### Alternative 4: gdUnit4 mocks, spies and `assert_signal`
- **Description**: Generated doubles and signal asserts.
- **Pros**: Less code.
- **Cons**: `assert_signal` awaits (TR-input-014 bans it); doubles override typed methods, a new 4.7 risk; no `typeof()` per argument.
- **Rejection Reason**: The GDDs require whole-log, typed, synchronous logs.

### Alternative 5: Prefix every `class_name`
- **Description**: `TrFlow`, `TrBattle` and so on.
- **Pros**: No clash risk.
- **Cons**: Renames across six Accepted ADRs, eight GDDs and the registry; L-NAME-1 catches a clash anyway.
- **Rejection Reason**: Cost now for a risk a lint finds.

### Alternative 6: Exit 101 as a pass
- **Description**: Orphans as a warning, as gdUnit4 labels them.
- **Pros**: Fewer red builds.
- **Cons**: A leaked node is what ADR-0001's retry design guards against.
- **Rejection Reason**: Leaks must be loud.

## Consequences

### Positive
- Every test, probe, helper and lint the six ADRs named has one home and one ID.
- CI and desktops run the same five steps with the same pass rule.
- push_error counts are exact, so "exactly one dev error" is testable.
- Layer rules become CI failures with names, not review comments.
- The lint can grow one pure rule at a time, each with its own planted test.

### Negative
- 42 rules to write and test before the full lint gives value; Migration orders them.
- A token lint misses calls made by string name or through an alias; code review stays the backstop.
- Each run boots Godot four times (import, parse, lint, tests); expect tens of seconds more per run.
- Hand-written fakes cost more code than generated doubles.

### Neutral
- `.godot/` leaves git, so a fresh clone needs step 1, which the script always runs.
- gdUnit4 stays at 6.2.0 until a story moves it.

## Risks
- **6.2.0 exits differ on 4.7.2** (H1). Mitigation: H1 before the CI story closes; if it fails, upgrade to 6.2.2, the version the reference observed.
- **push_error claims do not clear entries as read** (H2). Mitigation: H2 negative test; if claims do not clear, tests use the recording sink for counts and keep `is_push_error` for the message.
- **Import crashes (139) twice in a row**. Mitigation: the script names it a crash; rerun the job.
- **Lint false hits**. Mitigation: typed-receiver matching for L-DATA-2 and L-STAT-2; suppression with reason elsewhere.
- **`DisplayServer` in wrapper build blocks ADR-0006 V2 headless**. Mitigation: inject the value (Decision 8).
- **Hidden folder** (H8): if `res://.claude/` scripts do not load on Linux, copy the parse check to `tools/ci/`.
- **Typed-override missing return is a warning, not an error, on 4.7.2** (H4). Mitigation: set that warning to error in `project.godot`, or add a lint.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-012: code-built fixture catalogues, no file I/O; an integration suite checks the real files | Decision 3 fixtures through `from_documents`/`from_texts`; L-TEST-2; real-data suite only in `tests/integration/content/` (ADR-0002 C1). Full |
| input-gesture-resolver.md | TR-input-014: same calls, same logs; recording fake, not `assert_signal`; bots call commands plus one equivalence test | Decision 4 recorder and `EventLog`, L-TEST-1, `battle_state.digest`. **Partial**: the bot path and the equivalence test itself belong to ADR-0010 (TR-hero-012) and the Hero stories |
| game-state-stage-flow.md | TR-state-013: enumerate systems, inject fakes, snapshot a battle, fail on an unheard signal (views allowlisted) | `battle_members.gd`, `signal_recorder.gd`, `battle_state.gd`; listener test at `tests/integration/wiring/` per ADR-0006 Decision 8. Full |
| combat-damage.md | TR-combat-012: errors use push_error, asserted with `assert_error().is_push_error()` and the push_error report setting on; invariant I checks damage sums | Decision 5; H2. **Partial**: `combat_invariant.gd` hosts `I`, but the Combat counter and HP query names it reads come from ADR-0009 |
| enemy-wave.md | TR-enemy-014: headless content test of L1 to L14 and wave rules on in-memory records; unit tests use fakes, no scene or files | ADR-0002 C1/C2 placed in `tests/integration/content/` and `tests/unit/content/`; Decision 3 and 4 fakes; L-TEST-2. Full (rules L10, L11, L14 join with Tower and Hero stories, per ADR-0002) |
| tower-system.md | TR-tower-014: logic testable headless with spy accessor, recording fake, fake `halted()`; content test of tower and gold rows | `spy_stat_accessor.gd`, `signal_recorder.gd`, `fake_halt_gate.gd`; `content_rules_tower.gd` in the content suite. Full |

## Performance Implications
- **CPU**: None at runtime; nothing here ships. CI time rises by the import, parse and lint boots.
- **Memory**: None at runtime.
- **Load Time**: None. `tests/`, `tools/ci/` and `addons/gdUnit4/` stay out of exports.
- **Network**: CI downloads one pinned editor archive per run (cacheable).

## Migration Plan
1. Write `tools/ci/run_tests.sh` with steps 1, 2, 4 and 5; run H1, H3, H7 and H8 on it.
2. Set `gdunit4/report/godot/push_error=true` in `project.godot`; write `harness_probe_test.gd` with H2 and H9; watch H2's negative case fail with the setting off.
3. Untrack `.godot/`, add it to `.gitignore`; rewrite `tests/README.md` (gdUnit4 6.2.0 installed, the script, the exit map, the helper tree); close QQ-13.
4. Replace the action in `.github/workflows/tests.yml` with the install, checksum, script and upload steps.
5. Write `gd_tokens.gd`, `lint_main.gd`, `scopes.gd` and the first rules in the order code needs them: L-LAYER-*, L-APP-1, L-NAME-*, L-TEST-*, then L-TIME-*, L-RNG-*, L-VEC-1 (before the first sim story), then L-DATA-*, L-STAT-*, L-SIG-* and L-INPUT-* with the stories that add those files. Each lands with its planted tests.
6. Write the helpers in `tests/helpers/` with the first story that needs each.
7. Create `docs/engine-reference/godot/probe-results.md` with the first probe run.
8. Run `/create-control-manifest` to carry Decision 9's rules.

## Validation Criteria
Harness probes (`tests/unit/engine/harness_probe_test.gd` unless marked), results to `probe-results.md`:
- **H1** (`run_tests.sh --selftest`, CI story): on 4.7.2 with gdUnit4 6.2.0, the `tools/ci/selftest/` cases give 0 pass, 100 fail, 101 orphan, 105 parse error, 0 with `No test cases found`, 1 with no class cache. The reference recorded these for 6.2.2, not 6.2.0.
- **H2** `test_push_error_claims_are_exact`: setting on: (a) one `push_error` claimed passes; (b) one unclaimed fails; (c) two identical, one claimed, fails. (b) and (c) are `tools/ci/selftest/` cases that must exit 100. With the setting off, (a) fails, watched once (Migration 2).
- **H3** (`--selftest`): a leaked `Node` case makes the script fail on 101.
- **H4** (manual, once): a scratch override of a typed method with no `return` fails `godot-parse-check.gd`; record parse error or warning.
- **H5** `test_capture_reassign_warning`: whether 4.7.2 has a GDScript warning for reassigning a captured local, by `ProjectSettings.has_setting()` on the warning key; if it exists, set it to error.
- **H6** (manual, once): record the exit of a fresh clone run without step 1 (decides nothing).
- **H7** (CI story): the 4.7.2 Linux editor archive and SHA512 list names on the godotengine GitHub release.
- **H8** `test_hidden_folder_script_loads`: `load("res://.claude/scripts/godot-parse-check.gd")` is not null headless on Linux.
- **H9** `test_error_assert_awaits`: `is_push_error` without `await` does not report; with it, it does.

Harness tests:
- **T1** `tests/unit/lint/*_rules_test.gd`: every rule ID in Decision 6 has a hitting and a clean sample (ADR-0006 V8 included).
- **T2** `lint_main` over the empty `src/` exits 0; over a planted tree in a test string set it reports each ID once.
- **T3** `signal_recorder_test.gd`: a `String` sent where the table says `StringName` lands in `type_errors()` (ADR-0006 V6).
- **T4** `spy_stat_accessor_test.gd`: `fire_fatal_on(2)` calls the handler once on read 2 and returns fixture plus 1000.
- **T5** `battle_state_test.gd`: two fixture battles give equal digests; one changed fixture value gives a different one.

## Reviews
**Reviews still owed.** The godot-specialist check (Step 5.5) and the technical-director TD-ADR review (Step 5.6) were not run in this session; the user runs them. Until then this ADR stays Proposed and no finding is applied.

## Related
- Depends on ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006 (Accepted). Hosts their tests and lints; changes none of their decisions. Adds L-STAT-4 for the registry's `read_context_per_read` pattern.
- Enables ADR-0008 to ADR-0011 and the control manifest.
- `architecture.md` v4: dependency rules 1 to 6, What cannot be tested headless, QQ-13, QQ-15, QQ-16.
- GDDs: `design/gdd/data-config-pipeline.md`, `input-gesture-resolver.md`, `game-state-stage-flow.md`, `combat-damage.md`, `enemy-wave.md`, `tower-system.md` (each Acceptance Criteria preamble).
- `.claude/docs/coding-standards.md` (CI command), `.claude/rules/test-standards.md` (naming), `.claude/docs/run-and-observe.md` (evidence).
