# ADR-0007: Headless Test Harness, gdUnit4 and Layer Lint

## Status
Accepted

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. Route: `/architecture-decision accept ADR-0007`.

## Date
2026-11-04

## Last Verified
2026-11-04 (engine reference of 2026-10-17 and gdUnit4 6.2.0 source). Probes H4, H5, H7 (name and hash) and H8 are verified 4.7.2 headless (`docs/engine-reference/godot/probe-results.md`). H1, H2, H3, H6 and H9 still need gdUnit4 and have not run.

## Decision Makers
- Accepted: 2026-11-04 by the user (njarrar), with the gdUnit4 6.2.2 upgrade, the dated ADR-0003 amendment (is_mobile) and exit 101 as a failure
- Author: `/architecture-decision` in autonomous mode (decisions in `production/session-logs/decision-log.md`)
- Reviews: godot-specialist and technical-director TD-ADR, both CONCERNS, all findings applied (Reviews)
- Acceptance: the user

## Summary
ADR-0001 to ADR-0006 hand this ADR over 60 named tests, five engine probe sets, a recording spy, recording fakes, a listener-count test, ten lint IDs and about 20 lint rules stated in prose; GDScript itself has no module walls. This ADR fixes one headless harness: gdUnit4 run by one shell script in CI and on desktops, code-built fixtures and hand-written fakes under `tests/helpers/`, push_error reporting on, a token lint in GDScript run by Godot headless (rules handed over: L-APP, L-DATA, L-INPUT, L-PROJ, L-TIME, L-RNG, L-VEC, L-STAT-1 to 3, L-SIG; derived here: L-LAYER, L-NAME, L-GD, L-STAT-4, L-TEST), an engine probe suite, and a fixed manual-evidence list.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned); gdUnit4 6.2.2 (upgrade from the committed 6.2.0, Migration 0) |
| **Domain** | Core (scripting, test and CI tooling) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM: runner behaviour and GDScript rules are post-cutoff (4.5 rest parameters, `@abstract`; 4.7 typed-override return, packed-array setter); gdUnit4 6.2.x lists Godot up to 4.7.1 |
| **References Consulted** | Engine reference (`VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`); gdUnit4 6.2.0 source; `architecture.md` v4; `tr-registry.yaml`; ADR-0001 to ADR-0006; the registry; project test docs and CI files |
| **Post-Cutoff APIs Used** | gdUnit4 on 4.7.2; its error monitor's `Logger` subclass with `ScriptBacktrace` (4.5); `...args` rest parameters (4.5); `@abstract` (4.5); typed-override return (4.7) |
| **Verification Required** | H1 to H9 (Validation Criteria). H1, H2 and H7 gate the CI story. H4, H5, H7 (name and hash) and H8 are verified 4.7.2 headless (`docs/engine-reference/godot/probe-results.md`); H1, H2, H3, H6 and H9 need gdUnit4 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006 (all Accepted 2026-11-04); amends ADR-0003 (`setup()` gains `is_mobile`, confirmed by the user 2026-11-04 at acceptance) |
| **Enables** | ADR-0008 to ADR-0011 (their tests use these helpers and lints); `/create-control-manifest` (QQ-15 rules); `/test-setup` refresh (QQ-13) |
| **Blocks** | Every story with automated test evidence; the CI and lint stories in Migration. No story file exists yet |
| **Ordering Note** | The CI story (Migration 0 to 5) comes before the first Logic story. ADR-0003 spike S0a may run first (a prototype outside `src/`) |

## Context

### Problem Statement
Six Accepted ADRs say "ADR-0007 places them" for tests (ADR-0001 V1 to V8, ADR-0002 V1 to X2, ADR-0003 A1 to A11, ADR-0004 V1 to V14, ADR-0005 V1 to P1, ADR-0006 V1 to E6), lints and helpers named by role. None has a home, a runner or a pass rule. Every `class_name` is global and GDScript has no module walls (dependency rule 6), so layer rules hold only if a tool checks them. The runner's exit codes, error handling and fresh-clone import are known from observation, not docs. The first Logic story waits on this.

### Current State
- `addons/gdUnit4/` holds 6.2.0; the plugin is off, and the command-line runner does not need it.
- `.godot/global_script_class_cache.cfg` is tracked (a `.gitignore` un-ignore line) and lists 202 gdUnit4 classes, among them `Comparator`, `Fuzzer`, `LocalTime`, `ValueProvider`, `ErrorLogEntry`, `RPC`, `XmlElement`.
- `tests.yml` runs `gdUnit4-action@v1` with no lint, no parse check and no rule for exit 101.
- `tests/README.md` says gdUnit4 is not installed (QQ-13). `tests/` and `src/` hold no code.
- `project.godot` has no `gdunit4/` settings: push_error reporting is off.
- `project.yaml` `commands.test` runs gdUnit4 directly, with no import, lint or parse step.

### Constraints
- Linux CI and the macOS dev machine run the same command and pass rule.
- Unit tests read no files, load no scene, use no random seed and assert no time (coding-standards, test-standards, TR-data-012, TR-enemy-014).
- No autoloads (ADR-0001): helpers are plain scripts.
- A test may not pass a battle object to an assert before its weakref check (ADR-0001 Validation preamble).
- `tests/` and `tools/ci/` never ship (ADR-0002 Decision 8).
- One part-time developer: one lint tool, one runner script, no new language.

### Requirements
- Host every handed-over test, probe, helper and lint under one naming scheme.
- Fail CI on a test failure, orphan, parse error, lint hit, empty run, crash or hang.
- Count errors exactly (TR-combat-012).
- One named lint per rule, each with a planted-sample test (ADR-0006 V8).
- Answer QQ-13, QQ-15, QQ-16.

## Decision

### 1. Runner and CI job (QQ-13)
- **gdUnit4 moves to 6.2.2** (Migration 0), the only version the reference saw on 4.7.2. The godot reviewer found no source reason 6.2.0 would differ; H1 and H2 run after the upgrade either way. Confirmed by the user 2026-11-04.
- **`tools/ci/run_tests.sh` is the only test entry.** It `cd`s to the repo root. `GODOT` names the binary (CI: the pinned download; desktops: `engine.path` from `project.yaml`). Each step runs under `timeout` (`gtimeout` on macOS, the tool `.claude/scripts/test-run.sh` also picks) and stops the run on failure:
  1. **Import**: `"$GODOT" --headless --path . --import`, every run. Any non-zero exit gets one retry, with the code logged (the reference saw exit 139 in 3 of 17 fresh imports on 4.7.x). The import is not a parse check: it exits 0 on a parse error.
  2. **Parse check**: `"$GODOT" --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- <every .gd in src/, tests/, tools/ci/ except tools/ci/selftest/>`. Never `--check-only`.
  3. **Lint**: `"$GODOT" --headless --path . -s res://tools/ci/lint/lint_main.gd`: 0 clean, 1 hits, 2 lint crash (a failed `load()` gives 2, never a hang).
  4. **Tests**: the coding-standards CI command plus `--path .` and `-c`, with `-a` narrowed so benches stay out: `"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode -c`. Reports go to `res://reports/`.
  5. **Exit map**: 0 passes only if `results.xml` under `reports/` counts at least one test case once a suite exists (console text is not read). **101 fails**, and the script prints gdUnit4's orphan report. 101 covers orphan `Node`s only; `RefCounted` leaks are the weakref tests' job (ADR-0001 V2). A non-zero gdUnit4 code passes through; the script's own codes are 110 import, 111 parse, 112 lint, 113 empty run, 124 timeout.
- **Flags**: `--harness-selftest` runs `tools/ci/selftest/<case>/` (H1, H2, H3); `--perf` runs `tests/performance/` (ADR-0005 P1 and E5 benches), on demand, never in CI.
- **CI** (`tests.yml`, job `Run GdUnit4 Tests`, `timeout-minutes: 20`, `permissions: contents: read`): checkout; download the Godot 4.7.2 Linux editor from a URL pinned in the file and check it against a SHA512 pinned in the file, both copied from the release page by the CI story (archive name and SHA512 confirmed, H7; the CI story still copies the URL); never trust a sums file fetched at run time; run the script; upload `reports/` with `if: always()`. The gdUnit4 action goes: its 101 handling and install cannot be checked offline, and CI would differ from desktops.
- **Class cache leaves git** (Migration 3). Step 1 rebuilds it each run, so the old fresh-clone warning no longer applies to the script.
- **Settings**: `project.godot` sets `gdunit4/report/godot/push_error=true`, keeps `script_error` at default `true`, and keeps the gdUnit4 editor plugin off (an autoload it adds would fail the settings suite).

### 2. Test tree and naming
```
tests/helpers/{fixtures,fakes,battle,asserts}/  shared helpers, no class_name
tests/fixtures/catalogue/      ADR-0002 V3 files (integration only)
tests/unit/<system>/[helpers/] Logic; no file, scene or get_tree()
tests/unit/{content,engine,lint,app}/  C2 rule tests; probes; lint samples; settings suite
tests/integration/<system>/    scene tree, real files, multi-system
tests/integration/{content,wiring,lint}/  C1 and rules/; ADR-0006 V1, V2, battle_signals.gd; L-INPUT-2
tests/performance/             benches, --perf only
tests/smoke/                   /smoke-check critical paths (Markdown)
tests/baselines/<os>_<arch>/   ADR-0004 digests (data)
tools/ci/                      run_tests.sh, lint/, export_smoke.gd, selftest/<case>/
```
- `<system>` is the GDD slug in snake case (`data_config`, `input_gesture_resolver`, `game_state`, `combat`, `enemy_wave`, `tower`, `hero`, `battle_hud`) plus `app`, `time`, `input_adapter`, `signals`.
- **Files follow test-standards**: `<system>_<feature>_test.gd`, functions `test_<scenario>_<expected>`. Prior test IDs stay as function names. Proposed names map: ADR-0002's `test_content_real_data.gd` to `content_real_data_test.gd`, ADR-0006's `test_signal_probes.gd` to `signal_probe_test.gd`; `rules/content_rules_*.gd` and `battle_signals.gd` are data and keep theirs.
- Every suite `extends GdUnitTestSuite`; every `Node` a test makes goes through `auto_free()`; a scene test awaits one `process_frame` before a weakref check. Every `.gd` under the `-a` folders loads during discovery, so a broken helper there exits 105 (wanted).

### 3. Fixtures: code-built, no file I/O (TR-data-012, TR-enemy-014)
- `tests/helpers/fixtures/catalogue_fixtures.gd`: `base_documents()` gives the smallest valid `{source, type, records}` set (Tower with two levels, Enemy, Wave, Stage, Hero, Burst, Input); `with_field`, `without_field`, `with_record` return a deep copy with one change; `catalogue(docs)` calls `Catalogue.from_documents` and fails the test on any error; `base_texts()` is the same set as JSON text. Values live in named `const` tables, multiples of 0.25 below 2^20 where sums are compared (Combat GDD).
- `fixtures/stage_fixtures.gd`: stage geometry in field units, as the Enemy & Wave, Tower and Hero GDDs define it.
- `battle/battle_fixtures.gd`: `build(...)` calls `BattleBuilder.build` with a recording fatal handler and returns `{battle, fatal, sink}`, so the test holds both throughout (ADR-0005 V2).
- Only `tests/integration/` reads files: `load_manifest` on the real data root (ADR-0002 C1) and on `tests/fixtures/catalogue/` (V3).

### 4. Recording fakes and spies (TR-input-014, TR-tower-014, TR-state-013)
All fakes are hand-written `RefCounted` scripts loaded by `preload`; never gdUnit4 `mock()`, `spy()`, `assert_signal` or `monitor_signals` (those await and depend on timing).

| File (`tests/helpers/`) | Role and contract |
|---|---|
| `fakes/event_log.gd` | One ordered log per test: `add(name, args)`, `entries()`, `type_errors()` |
| `fakes/signal_recorder.gd` | `attach(emitter, names, wiring)` connects `_record.bind(name)` through a test-owned `Wiring`; `_record(...args)` checks count, `typeof()` and class per argument against `battle_signals.gd` and logs a mismatch to `type_errors()` |
| `fakes/spy_stat_accessor.gd` | ADR-0005 spy: `extends StatAccessor`, exact parameter lists, typed returns; logs reads; `set_value(def_id, key, value)`; `fire_fatal_on(n)` calls the handler on read n and returns the fixture value plus 1000 |
| `fakes/fake_halt_gate.gd` | `halted()`, `set_halted(b)`, `halt_after(calls)` |
| `fakes/recording_fatal.gd` | `fatal(cause)`, `causes()` |
| `fakes/recording_dev_error_sink.gd` | `extends DevErrorSink`; `report(msg)` records, never calls `push_error` |
| `fakes/recording_resolver.gd` | The five resolver calls, logged (ADR-0003), and the four registry calls (ADR-0008 amendment) |
| `fakes/command_spy.gd` | Step and command fakes that log and can command from a handler (ADR-0004 V2, V4; ADR-0006 V5) |
| `battle/battle_members.gd` | `emitters(battle)` by `get_property_list()` (ADR-0006 Decision 8 step 1) |
| `battle/battle_state.gd` | `take(battle)`: plain values from every read-only query, resolver registry excluded; `digest(battle)`: `var_to_bytes` of `take()` (ADR-0004 V7) |
| `battle/weak_check.gd` | `refs(objects)`, `all_freed(refs)`; the caller drops its locals first |
| `battle/combat_invariant.gd` | Combat invariant `I`: `check(log, combat, enemies) -> String`, empty when sums agree; reads ADR-0009's queries and `applied` (`damage_applied` argument 3, amendment) |
| `asserts/log_asserts.gd` | `assert_log(test, log, expected)`: the entire log in order, no `type_errors()` |

- A fake overriding a typed method keeps the parameter list and returns that type on every path (4.7; `return 0`, `return 0.0`; the guide's `return null` fits only `Object` or `Variant` returns).
- A fake records into an `Array` or `Dictionary` member, never by reassigning a captured local.
- `typeof()` cannot tell an enum from an `int`; the recorder checks the enum bit against the table.

### 5. Errors: recorded, counted, claimed (TR-combat-012)
- Every `assert_error(callable)` records the errors its callable raises in its own logger, whatever the setting (`GdUnitGodotErrorAssertImpl.gd:6`). The setting `gdunit4/report/godot/push_error` decides only whether an error no assertion claims fails the test (`GodotGdErrorMonitor.gd:74`, `GdUnitExecutionContext.gd:149-153`).
- With it on, the test monitor records `push_error`, `push_warning` and engine errors and warnings, and `script_error` (default on) adds runtime script errors; each entry is an abort report counted as an error. **Any unclaimed `push_warning`, engine `ERR_*` or warning, or runtime script error during a test fails it.**
- **Claim** errors with `await assert_error(func(): sut.bad_call()).is_push_error(MSG)` and warnings with `await assert_error(...).is_push_warning(MSG)`; always `await` (L-TEST-5). Silent cases use `await assert_error(callable).is_success()`.
- **Which**: one error from one call uses the real `DevErrorSink` (or app `FatalLatch`) and `is_push_error`, as TR-combat-012 asks. Order or count across calls injects `recording_dev_error_sink.gd` and asserts its log.
- Probes that provoke engine or script errors (ADR-0002 E3, ADR-0006 E2) wrap the call in `assert_error` and print what it caught.

### 6. Lints: GDScript, token based, run by Godot headless
- **Tool**: `tools/ci/lint/lint_main.gd` (`extends SceneTree`) walks `src/`, `tests/`, `tools/ci/` and `.tscn` files. `gd_tokens.gd` is a hand-written scanner (`GDScriptTokenizer` is not exposed). It must handle triple-quoted, raw `r"..."`, `&"..."` and `^"..."` literals, `#` inside strings, `##` doc comments, `\` line continuation, line counts across multi-line strings, and `$` and `%` node paths. Comments drop; each string stays one token.
- **Rule shape**: one table-driven rule, `token_rules.gd`, holds every "banned token in scope" row (Kind T below) as data, each row with a hit and a clean sample in `tests/unit/lint/token_rules_test.gd`. Only Kind C rules get their own code in `tools/ci/lint/rules/`, each a pure `check(path, tokens, ctx)` with its own samples.
- **Scopes** live once in `tools/ci/lint/scopes.gd` (ADR-0004 review B4): `SIM = src/foundation, src/core, src/feature`; `RNG_EXEMPT = src/root/battle_builder.gd, src/root/battle_wrapper.gd`; the adapter, TapScreen, Wiring, wrapper, ResultScreen, RunLog and ReadContext owner paths; each folder's layer. `tests/unit/lint/` is exempt from string-literal rules, since its samples are strings.
- **Settings suite** (Kind S): `tests/unit/app/app_settings_test.gd` reads `ProjectSettings`, the base key and every `.<feature>` override key, never file text.
- **Output**: `LINT <ID> <path>:<line> <message>`, then a count per ID. No suppression marker exists.
- **Known gaps**: the lint matches names, not types. It misses calls through `call()`, a string `Callable` or a renamed local, and `Vector2` operators on values it cannot see are `Vector2`. Review and the runtime tests (replay digest, read-only containers, listener test) back each gap.
- **PresentationSettings**' file goes to `src/presentation/`, so views name it inside their layer; AppRoot still owns and fills it. Other root types reach layers as Callables.

**Lint list.** Kind: T token table, C own code, S settings suite, X scene test, A alias, R review, D deferred. When: 1 before the first Logic story, 2 before the first sim story, 3 with the story that adds the file.

| ID | Source | Kind/When | Scope | Fails on |
|---|---|---|---|---|
| L-LAYER-1 | rules 1, 6 | C1 | `src/` | A class name or `res://src/` path of a higher layer (Foundation < Core < Feature < Presentation < root) |
| L-LAYER-2 | rule 2; 0001 G2 | C1 | `src/` but root | Any `src/root/` class |
| L-LAYER-3 | rule 4 | C3 | `src/feature/` | `enemy_wave/`, `tower/`, `hero/` naming each other |
| L-LAYER-4 | 0002 D8 | T1 | `src/` | `res://tests/`, `res://addons/`, `res://tools/`, a `GdUnit` name |
| L-APP-1 | 0001 G1, V7 | S1 | settings | Any `autoload/` key; `run/main_scene` not `app_root.tscn` |
| L-APP-2 | 0001 G3; 0006 D1 | T3 | `src/` | `.connect(` outside `wiring.gd` and the engine-node files `scopes.gd` names, each with its reason |
| L-APP-3 | 0001 G4 | T3 | Builder, wrapper | A lambda or `.bind(` |
| L-APP-4 | 0001 G12 | T3 | `src/root/` | `.free()` |
| L-APP-5 | 0001 G10 | T3 | `src/` | `assert(` |
| L-APP-6 | 0001 G16; 0003 G14; 0004 G11 | T3 | `src/` | Assigning `paused` on the tree |
| L-APP-7 | 0001 G17 | T3 | `src/` | `get_tree().create_tween(`, `create_timer(` |
| L-APP-8 | 0001 G14 | S1 | settings | `gui/theme/custom` or `custom_font` set |
| L-DATA-1 | 0002 G2 | T3 | `src/` | `DirAccess` |
| L-DATA-2 | 0002 G9 | C3 | `src/` but `foundation/data/` | On a receiver typed as a record class: a schema field assigned, or `append`, `push_back`, `erase`, `clear`, `insert`, `remove_at`, `sort`, `assign` on one |
| L-INPUT-1 | 0003 G2 | T3 | `src/` | `_input`, `_unhandled_input` outside the adapter; `_gui_input` outside `tap_screen.gd` |
| L-INPUT-2 | 0003 G9, G10 | X3 | wrapper scene | A Control not IGNORE (TapScreen: not STOP); `focus_mode` not NONE; a full-rect wrapper root |
| L-INPUT-3 | 0003 G4 | T3 | `src/` | `device == 0`, `device != 0` |
| L-INPUT-4 | 0003 G8 | T3 | `src/`, `.tscn` as text | `Camera2D`; `type="Camera2D"` |
| L-INPUT-5 | 0003 G12 | T3 | `src/` | `get_display_safe_area(` outside the wrapper |
| L-INPUT-6 | 0008 G3, G12 (amendment) | C3 | `src/` | On a resolver receiver, `press(`, `move(`, `release(`, `cancel_pointer(` outside the adapter; `cancel(` outside the adapter, Flow's `cancel_input` target and AppRoot teardown; `InputResolver.new(` outside the resolver file |
| L-INPUT-7 | 0008 G13 (amendment) | T3 | `src/` but `foundation/input/`, `presentation/dev/` | `last_trace(`, `GestureTrace`, resolver `state(` |
| L-PROJ-1 | 0003 A11; 0004 G11, V11e | S1 | settings | A key of ADR-0003 Decision 1 or ADR-0004 Guideline 11 off its value |
| L-TIME-1 | 0004 G2 | T2 | `SIM` | `_process`, `_physics_process`, `Timer`, `await`, `Engine.`, `Time.`, `OS.`, `Input.flush_buffered_events`, `Input.parse_input_event`, `push_input(` |
| L-TIME-2 | 0004 G1, G2 | T2 | `src/` | `battle.tick(` outside the wrapper; `.tick(` with a number literal |
| L-TIME-3 | 0004 G6 | C2 | `src/` | `-=` then `dt`, `delta`, `TICK_SECONDS`, `tick_seconds()` |
| L-RNG-1 | 0004 D8 | T2 | `src/` but `RNG_EXEMPT`; `SIM` | Global `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed`, `rand_from_seed`; `.shuffle(`, `.pick_random(`, `RandomNumberGenerator.new(`; in `SIM` also `.randfn(` |
| L-VEC-1 | 0004 D9 | C2 | `SIM` | A `Vector2`, `Vector2i` or `Rect2` method by name (`length`, `distance_to`, `normalized`, `dot`, `lerp`, `has_point` and the rule's list); an operator on a local typed `Vector2`; `Curve2D`, `Path2D`, `PackedVector2Array` maths; transcendentals |
| L-STAT-1 | 0005 G5 | T3 | `src/` | A string or `&"..."` key in `stat_int(` or `stat_float(` |
| L-STAT-2 | 0005 G1 | C3 | `src/` but `foundation/data/` | On a receiver typed as a tower level, enemy, hero or burst record: a field `StatKeys.ROWS` lists |
| L-STAT-3 | 0005 G10 | A | | Alias of L-APP-5 for `stat_accessor.gd`, `read_context.gd` |
| L-STAT-4 | registry `read_context_per_read` (0005 G6) | T3 | `src/` | `ReadContext.new(` outside the owner files in `scopes.gd` (enemy, tower_sim, hero_sim, hud_logic) |
| L-SIG-1 | 0006 G1 | T3 | `src/` | `emit_signal(`, `connect("`, `add_user_signal(` |
| L-SIG-2 | 0006 G2 | T3 | `src/` | `CONNECT_` flags; `call_deferred` on an emit; `await` on a battle signal; `tween_await(` |
| L-SIG-3 | 0006 G4 | C3 | presentation, wrapper | Assigning a field of `flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`, `stat_accessor`, `halt_gate` |
| L-SIG-4 | 0006 G6 | C3 | `src/` | A `*_id` parameter or variable typed `String` |
| L-SIG-5 | 0006 G8 | T3 | ResultScreen, RunLog | Any sim member or sim class name |
| L-COMBAT-1 | 0009 G1 (amendment) | T3 | `src/` but `core/combat/` | `.health`, `.status`, `Health.new(`, `Status.new(` |
| L-COMBAT-2 | 0009 G2 (amendment) | C3 | `src/` but `feature/enemy_wave/` | On a receiver typed `Targetable` or `Enemy`, assigning `spawn_id`, `distance`, `x`, `y`, `removed` |
| L-COMBAT-3 | 0009 G4 (amendment) | T3 | `src/` | `DamageEvent.new(` outside `tower_sim.gd`, `hero_sim.gd` |
| L-COMBAT-4 | 0009 G2 (amendment) | C3 | `src/` but `enemy_wave.gd` | `append`, `remove_at`, `clear`, `sort`, `erase` or assignment on a `roster()` or `targets()` result |
| L-NAME-1 | QQ-16; 0005 E7 | C1 | `src/` | A `class_name` that `ClassDB.class_exists()` knows, or whose `get_global_class_list()` entry names another path (the list holds one entry per name) |
| L-NAME-2 | QQ-16 | T1 | `tests/`, `tools/` | Any `class_name` |
| L-GD-1 | QQ-15 | D | `src/`, `tests/` | `arr[i] = v` on a property with a `set(`; lands with the first such property |
| L-TEST-1 | TR-input-014; 0004 V9 | T1 | `tests/` | `assert_signal(`, `monitor_signals(`, `set_time_factor(`, `create_timer(`, global RNG |
| L-TEST-2 | TR-data-012, TR-enemy-014 | T1 | `tests/unit/` | `FileAccess`, `DirAccess`, `load_manifest(`, a `.tscn` or `.scn` path, `get_tree()` |
| L-TEST-3 | 0001 Validation preamble | R | `tests/` | A weakref target passed to an assert first (code review) |
| L-TEST-4 | test-standards | C1 | `tests/unit/`, `tests/integration/` | A suite not named `*_test.gd`; a public `func` other than `before`, `after`, `before_test`, `after_test` not starting `test_` (gdUnit4 runs only `test_*`, `GdUnitTestDiscoverer.gd:128`); helpers start with `_` |
| L-TEST-5 | Decision 5 | T1 | `tests/` | `assert_error(` with no `await` before it |

### 7. Engine probe suite
- `tests/unit/engine/`, one file per handing ADR: `callable_ref_probe_test.gd` (ADR-0001 V1), `json_probe_test.gd` (ADR-0002 E1 to E3), `tick_probe_test.gd` (ADR-0004 V11a to e), `stat_probe_test.gd` (ADR-0005 E1, E3, E7), `signal_probe_test.gd` (ADR-0006 E1 to E6), `combat_probe_test.gd` (ADR-0009 B1 to B4, X1 to X7; amendment), `harness_probe_test.gd` (H2a, H2b, H5, H8, H9).
- A probe prints `PROBE <id> <answer>` and asserts nothing about which answer is right; must-pass parts (ADR-0001 V1 case f) assert.
- After a run on a new engine or gdUnit4 version, the story adds a row per probe to `docs/engine-reference/godot/probe-results.md` (ID, date, Godot and gdUnit4 versions, OS and architecture, answer, test file), plus a line in the doc each handing ADR names where guidance changes. An answer that differs from the row on file is a review item.

### 8. Manual evidence: what cannot run headless
Each item is a story (Visual/Feel, UI, or Integration with a documented playtest) with screenshots or photos, the raw log and `stamp.txt` in `production/qa/evidence/<story-slug>/` (`run-and-observe.md`). Capture with `--write-movie`; never `--headless`.

| ID | What | From | When |
|---|---|---|---|
| M1 | Spike S0a on desktop | ADR-0003 | Before ADR-0004 and ADR-0008 stories rest on it |
| M2 | Spike S0b on an Android phone | ADR-0003 | First phone build |
| M3 | UI evidence: 540x960 and resized, Paused on alt-tab, Lost and Won block the field; phone letterbox, insets, back swipe, 50 taps give 50 `tapped` | ADR-0003 | Each UI story |
| M4 | V8: release export fatal screen, device-log `push_error` line, stderr and file-logging values | ADR-0001 | First phone build |
| M5 | X2: Android debug build reaches Ready; release build fatal screen | ADR-0002 | Technical Setup gate |
| M6 | P1 load timing, P2 edit-to-run time | ADR-0002 | First phone build |
| M7 | V13: p95 tick cost, frame time, high-refresh pacing | ADR-0004 | First phone build |
| M8 | P1 device run of `bench_stat_reads` | ADR-0005 | First phone build |
| M9 | Draw calls and frame time against budget | ADR-0011 | First phone build |

- **Headless outside step 4**: ADR-0002 X1 (needs export templates; Technical Setup gate, then release tags) and the `--perf` benches.
- Everything else runs in step 4, including ADR-0001 V6 and ADR-0006 V2 as scene tests. If V2 cannot build the wrapper headless, the wrapper takes the value by injection; V2 does not move to manual.

### 9. GDScript 4.7 rules for the control manifest (QQ-15)
**Required**: R1 an override of a typed method returns that type on every path (4.7; a missing `return` is a parse error per `breaking-changes.md`, so step 2 catches it). R2 to change one element of a packed-array property whose setter must run, assign the whole array. R3 state a lambda changes lives in an `Array`, `Dictionary` or object member. R4 every battle signal has a `battle_signals.gd` row and fakes check each argument, since `emit()` checks no types. R5 a rest parameter is `...name: Array` or untyped, last. R6 helpers load by `const X := preload(...)`.

**Forbidden**: F1 relying on a setter for `arr[i] = v` on a packed array. F2 assigning a captured outer local in a lambda (H5 found `debug/gdscript/warnings/confusable_capture_reassignment`: set it to error, 2. 4.7.2 has no `exclude_addons`; keep `debug/gdscript/warnings/directory_rules` at its default `{"res://addons": 0}`, which already skips addon warnings). F3 trusting declared signal types at runtime. F4 `return null` in an override typed `int`, `float` or `bool`; `--check-only` as a parse check. F5 `class_name` in `tests/` or `tools/`.

**Notes** (verified 4.7.2 headless, see probe-results.md): N1 `debug/gdscript/warnings/inference_on_variant` defaults to error, so write `var w: WeakRef = weakref(x)`, never `var w := weakref(x)`. N2 never name a variable `log`: it shadows the global `log()` and breaks the parse.

### 10. Class names (QQ-16)
No prefix; the short names in ADR-0001 to ADR-0006 stay. L-NAME-1 fails a clash by name on every run, so an engine or addon upgrade that adds a class shows at once; it extends ADR-0005 E7 to script classes. Taken today: every gdUnit4 global (`Comparator`, `Fuzzer`, `LocalTime`, `ValueProvider`, `ErrorLogEntry`, `RPC`, `XmlElement`, the `Gd` and `GdUnit` names). A class a future clash forces to rename takes a `Tr` prefix alone.

### Architecture Diagram
```
run_tests.sh: import -> parse check -> lint (tokens + rules + reflection) -> gdUnit4 unit+integration -> exit map
tests/helpers (fixtures, fakes) feed tests/unit and tests/integration; probes -> probe-results.md
manual M1 to M9 -> production/qa/evidence/<story-slug>/
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
# tests/helpers/battle/battle_fixtures.gd
static func build(docs: Array[Dictionary] = [], stage_id: StringName = &"fixture_stage", rng_seed: int = 1) -> Dictionary
```
Names are proposed. The spy copies ADR-0005's `stat_int` and `stat_float` signatures; the other contracts are the Decision 4 table.

### Implementation Guidelines
1. Tests must run only through `tools/ci/run_tests.sh`. A run must fail on any non-zero step, on 101, and on an empty `results.xml` once suites exist; `--import` must run first every time, with one retry.
2. Unit tests must never read a file, load a scene, call `get_tree()`, draw a random number or assert a time; they must build catalogues only through `catalogue_fixtures.gd`.
3. Tests must record signals only into an `EventLog` through the Decision 4 fakes, never `assert_signal`, `monitor_signals`, `mock()` or `spy()`; a THEN must compare the entire log in order with no `type_errors()`.
4. Every expected error or warning must be claimed with an awaited `assert_error(...).is_push_error(msg)` or `is_push_warning(msg)`; `gdunit4/report/godot/push_error` must stay `true`.
5. A test must hold its spy, handler and sink for its whole run, must not pass a battle or sim object to an assert before its weakref check, and must free every `Node` it makes.
6. Fakes overriding typed methods must keep the parameter list and return a typed value on every path; `tests/` and `tools/` must hold no `class_name`, and helpers must load by `preload`.
7. Every lint row must have a hitting and a clean planted sample; scopes and exempt files must live only in `scopes.gd`.
8. Probes must print `PROBE <id> <answer>`, assert only must-pass cases, and be recorded in `probe-results.md`.
9. Manual evidence must sit in `production/qa/evidence/<story-slug>/` with `stamp.txt`.

## Alternatives Considered

### Alternative 1: Keep the gdUnit4 GitHub Action
- **Description**: Keep `gdUnit4-action@v1`; add lint and parse steps.
- **Pros**: No install step; a check run.
- **Cons**: Its 101 and empty-run handling cannot be checked offline; its own Godot install; desktops differ.
- **Rejection Reason**: The pass rule must live in code the project owns.

### Alternative 2: Shell or Python regex lint
- **Description**: `grep` or Python over `src/`.
- **Pros**: Fast; no engine boot.
- **Cons**: No effective settings, `ClassDB`, global classes, `StatKeys.ROWS` or built scene; a second language; hits in comments and strings.
- **Rejection Reason**: Many rules need the engine's view.

### Alternative 3: gdtoolkit parse-based lint
- **Description**: A syntax tree from the gdtoolkit Python parser.
- **Pros**: Exact syntax.
- **Cons**: Its 4.5+ grammar is unverified offline; a lagging parser blocks CI on valid code; still no types.
- **Rejection Reason**: CI risk with no gain on type gaps.

### Alternative 4: gdUnit4 mocks, spies and `assert_signal`
- **Description**: Generated doubles and signal asserts.
- **Pros**: Less code.
- **Cons**: `assert_signal` awaits (TR-input-014 bans it); doubles override typed methods (a 4.7 risk); no `typeof()` per argument.
- **Rejection Reason**: The GDDs require whole-log, typed, synchronous logs.

### Alternative 5: Prefix every `class_name`
- **Description**: `TrFlow`, `TrBattle` and so on.
- **Pros**: No clash risk.
- **Cons**: Renames across six Accepted ADRs, eight GDDs and the registry; L-NAME-1 catches a clash anyway.
- **Rejection Reason**: Cost now for a risk a lint finds.

### Alternative 6: Exit 101 as a pass, or lint suppressions
- **Description**: Treat orphans as warnings; allow `# lint-allow` markers.
- **Pros**: Fewer red builds.
- **Cons**: A leaked node is what ADR-0001's retry design guards against; markers turn rules into opinions.
- **Rejection Reason**: Leaks and rule breaks must be loud; a real exception changes the ADR or `scopes.gd`.

## Consequences

### Positive
- Every test, probe, helper and lint the six ADRs named has one home and one ID.
- CI and desktops run the same steps with the same pass rule, under timeouts.
- Error counts are exact; a stray warning or engine error fails the test that caused it.
- Layer rules become named CI failures.

### Negative
- About 40 lint IDs to build; the When column orders them, and most are rows in one table.
- A token lint misses calls by string name or alias; review stays the backstop.
- Each run boots Godot four times; expect tens of seconds more.
- Hand-written fakes cost more code than generated doubles.
- Strict error reporting fails tests on engine warnings a looser setting would let pass; each must be claimed or fixed.

## Risks
- **6.2.2 exits or error handling differ from the reference** (H1, H2). Mitigation: both run after the upgrade, before the CI story closes.
- **Import fails twice**. Mitigation: exit 110 names it; rerun the job.
- **Lint false hits**. Mitigation: typed-receiver matching for L-DATA-2 and L-STAT-2; a real exception moves into `scopes.gd` by an ADR change.
- **`DisplayServer` in wrapper build blocks ADR-0006 V2 headless**. Mitigation: inject the value.
- **Hidden folder** (H8): if `res://.claude/` scripts do not load on Linux, copy the parse check to `tools/ci/`. H8 passed, so no copy is needed.
- **Other tools call Godot directly** (`.claude/scripts/test-run.sh`, `/smoke-check`, `/dev-story`, `/test-setup`) and skip import and lint. Mitigation: `commands.test` points at the script (Migration 4).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-012: code-built fixture catalogues, no file I/O; an integration suite checks the real files | Decision 3; L-TEST-2; real-data suite only in `tests/integration/content/`. Full |
| input-gesture-resolver.md | TR-input-014: same calls, same logs; recording fake, not `assert_signal`; bots call commands plus one equivalence test | Decision 4, L-TEST-1, `battle_state.digest`. **Partial**: the bot path and equivalence test are ADR-0010's (TR-hero-012) |
| game-state-stage-flow.md | TR-state-013: enumerate systems, inject fakes, snapshot a battle, fail on an unheard signal (views allowlisted) | `battle_members.gd`, `signal_recorder.gd`, `battle_state.gd`; listener test per ADR-0006 Decision 8. Full |
| combat-damage.md | TR-combat-012: errors use push_error, asserted with `is_push_error()` and the report setting on; invariant I checks damage sums | Decision 5; H2; `combat_invariant.gd` (ADR-0009's query names are a dependency, not a split). Full |
| enemy-wave.md | TR-enemy-014: headless content test of L1 to L14 and wave rules on in-memory records; unit tests use fakes, no scene or files | ADR-0002 C1, C2 placed; Decisions 3, 4; L-TEST-2. Full |
| tower-system.md | TR-tower-014: spy accessor, recording fake, fake `halted()`; content test of tower and gold rows | Decision 4 spy, recorder, halt gate; `content_rules_tower.gd`. Full |

## Performance Implications
- **CPU**: None at runtime; nothing here ships. CI time rises by three extra Godot boots.
- **Memory**: None at runtime.
- **Load Time**: None; `tests/`, `tools/ci/`, `addons/gdUnit4/` stay out of exports.
- **Network**: One pinned editor download per CI run (cacheable).

## Migration Plan
0. Upgrade `addons/gdUnit4/` to 6.2.2 (confirmed by the user 2026-11-04).
1. Write `tools/ci/run_tests.sh` and `tools/ci/selftest/`; run H1, H2, H3, H7, H8.
2. Set `gdunit4/report/godot/push_error=true`; write `harness_probe_test.gd`; watch H2 (c) fail.
3. Remove the `!**/.godot/global_script_class_cache.cfg` line and its comment from `.gitignore`, then `git rm --cached .godot/global_script_class_cache.cfg`. Rewrite `tests/README.md`; close QQ-13.
4. Set `project.yaml` `commands.test` to `bash tools/ci/run_tests.sh` with `GODOT` from `engine.path`, so `/smoke-check`, `/story-done` and `/dev-story` use it. `coding-standards.md` stays as is.
5. Replace the action in `tests.yml` with the pinned download, checksum, script and upload.
6. Write `gd_tokens.gd`, `lint_main.gd`, `scopes.gd`, `token_rules.gd` and the settings suite, then rules by the When column.
7. Write the helpers with the first story that needs each; create `probe-results.md` with the first probe run.
8. Run `/create-control-manifest` for Decision 9.

## Validation Criteria
Harness probes and self-tests; results to `probe-results.md`:
- **H1** (`--harness-selftest`): a run with no class cache exits 1; a run with no test cases exits 0 and the script maps it to 113 from `results.xml`. Record whether 101 ever means anything but orphans.
- **H2** setting on unless noted: (a) one claimed `push_error` passes; (b) one claimed `push_error` passes with the setting off; (c) one unclaimed fails; (d) an unclaimed `push_warning` fails, and an engine `ERR_*` and a runtime script error are each counted; (e) two identical, one claimed, fails. (a), (b) in `harness_probe_test.gd`; (c) to (e) in `tools/ci/selftest/`, which must exit 100.
- **H3** (`--harness-selftest`): a leaked `Node` makes the script fail on 101 and print the orphan report.
- **H4** (once): confirm that a typed override with no `return` fails the parse check; the reference says it is an error. It fails; verified 4.7.2 headless, see probe-results.md.
- **H5**: whether `debug/gdscript/warnings/confusable_capture_reassignment` exists on 4.7.2 (`ProjectSettings.has_setting()`). It exists, default 1 (warn); verified 4.7.2 headless, see probe-results.md.
- **H6** (once): record a fresh-clone run's exit without step 1.
- **H7**: archive `Godot_v4.7.2-stable_linux.x86_64.zip`, SHA512 `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65`, confirmed (verified 4.7.2 headless, see probe-results.md). The CI story still copies the URL from the release page.
- **H8**: `load("res://.claude/scripts/godot-parse-check.gd")` is not null headless on Linux. It loads; verified 4.7.2 headless, see probe-results.md.
- **H9** (print only): what an un-awaited `is_push_error` reports; tests always `await` either way.

Harness tests:
- **T1** `tests/unit/lint/`: every T row and C rule has a hitting and a clean sample (ADR-0006 V8).
- **T2** `lint_main` over the empty `src/` exits 0; a broken `load()` exits 2.
- **T3** `signal_recorder_test.gd`: a `String` where the table says `StringName` lands in `type_errors()` (ADR-0006 V6).
- **T4** `spy_stat_accessor_test.gd`: `fire_fatal_on(2)` calls the handler once on read 2 and returns fixture plus 1000.
- **T5** `battle_state_test.gd`: equal fixtures give equal digests; one changed value does not.

## Reviews
**godot-specialist: CONCERNS. TD-ADR: CONCERNS.** All findings applied.

| # | Finding | Resolution |
|---|---|---|
| G1 | Error assert always records; setting rules unclaimed errors only | Decision 5; H2 (b) |
| G2 / T7 | Setting also records warnings, engine and script errors | Decision 5; `is_push_warning`; H2 (d); probes wrap in `assert_error` |
| G4 | H9 should not gate | H9 print only; L-TEST-5 |
| G5 | H1 too broad; empty run by console text | H1 two cases; `results.xml` count |
| G6 | `--selftest` clashes with gdUnit4's flag | `--harness-selftest` |
| G7 | Overlap with `test-run.sh`; no timeouts | Same timeout tool; every step timed; `timeout-minutes` |
| G8 | Retry only on 139 | Retry once on any non-zero; import is no parse check |
| G9 / T8 | `.gitignore` un-ignore line; other tools call Godot | Migration 3, 4; Risks |
| G10 | Workflow permissions | `contents: read` |
| G11 | Download names unverified; fetched sums | URL and SHA512 pinned in the file; H7 open |
| G13 | H4 settled by reference | One-time confirmation; risk row dropped; `return null` note |
| G14 | Capture warning setting | F2; `exclude_addons` kept |
| G15 | L-NAME-1 method | Path compare against the global class list |
| G16 | Tokenizer not exposed | Hand scanner; case list; exit 2 on failed load |
| G17 | Samples hit string rules | `tests/unit/lint/` exempt in `scopes.gd` |
| G18 | Tree and discovery | `tests/smoke/`; broken helper gives 105 |
| T1 | `commands.test` bypasses the script | Migration 4; step 4 command |
| T2 | L-TIME-1 suppression | Dropped; ADR-0003 amendment adds `is_mobile` |
| T3 | L-STAT-4 scope | Owner files in `scopes.gd`; When 3 |
| T4 | L-TEST-4 definition; benches | Hook names; `tests/performance/`, `--perf` |
| T5 | Lint shape | Handed over vs derived; Kind and When columns; one token table; aliases, review, deferred rows |
| T6 | Camera2D in scenes | `.tscn` text scan |
| T9 | Sync items | Related |
| TD | gdUnit4 version; exit 101; PresentationSettings; TR-combat-012; trims | 6.2.2 Migration 0; 101 fails with report; `src/presentation/`; Full; trims made |

## Amendments
- **2026-11-04, with ADR-0008** (confirmed by the user 2026-11-04 at ADR-0008 acceptance; Status stays Accepted). Lint rows L-INPUT-6 and L-INPUT-7; `recording_resolver.gd` also logs `register`, `unregister`, `set_centre`, `set_enabled`.
- **2026-11-04, from verified engine probes** (docs/engine-reference/godot/probe-results.md; Status stays Accepted). F2: `debug/gdscript/warnings/exclude_addons` does not exist in 4.7.2; F2 now keeps `debug/gdscript/warnings/directory_rules` at its default `{"res://addons": 0}`, which already skips addon warnings. Decision 9 gains notes N1 (`inference_on_variant` is an error by default: type a `weakref()` local as `WeakRef`, not `:=`) and N2 (a variable named `log` breaks the parse). H7: archive name and SHA512 confirmed; the CI story still copies the URL. H4, H5, H7 and H8 are marked verified.
- **2026-11-04, from the third architecture review; Status stays Accepted** (`architecture-review-2026-11-04.md`, Should fix 5 and 9). Last Verified now names the probes verified 4.7.2 headless (H4, H5, H7, H8) and those that still need gdUnit4 (H1, H2, H3, H6, H9). Depends On lists ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006 by number, so `adr-dep-graph.sh` sees all six edges. Nothing else in this ADR changes.
- **2026-11-04, with ADR-0009** (confirmed by the user at ADR-0009 acceptance); Status stays Accepted. Lint rows L-COMBAT-1 to L-COMBAT-4 (ADR-0009 Migration 4). `combat_invariant.gd` reads `applied` from the plain-value `damage_applied` (argument 3). `combat_probe_test.gd` runs ADR-0009 B1 to B4 and X1 to X7 in the probe suite.

## Related
- Depends on ADR-0001 to ADR-0006 (Accepted). Amends ADR-0003 (`setup(..., is_mobile: bool)`, Amendments, confirmed 2026-11-04). Adds L-STAT-4 for the registry's `read_context_per_read`.
- Sync items, not made here: ADR-0002 and ADR-0006 rename `test_content_real_data.gd` and `test_signal_probes.gd` at their next revision; `architecture.md` moves `PresentationSettings`' file to `src/presentation/` (Composition Root row), adds "Shared, not counted: TR-input-014 bot part" to ADR-0010's entry, and closes QQ-13, QQ-15, QQ-16; `.claude/scripts/test-run.sh` learns codes 110 to 113 and 101 as a failure.
- GDDs: `design/gdd/data-config-pipeline.md`, `input-gesture-resolver.md`, `game-state-stage-flow.md`, `combat-damage.md`, `enemy-wave.md`, `tower-system.md`.
- `.claude/docs/coding-standards.md`, `.claude/rules/test-standards.md`, `.claude/docs/run-and-observe.md`.
