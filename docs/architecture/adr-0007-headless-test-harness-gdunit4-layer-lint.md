# ADR-0007: Headless Test Harness, gdUnit4 and Layer Lint

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Why this is stated here: stories referencing a `Proposed` ADR are set `Blocked`,
> and epics require `Accepted`, so the field needs a named owner.
> `technical-director` is the role `coordination-rules.md` already escalates
> technical conflicts to, and an ADR is that decision made durable.
>
> This does **not** relax the existing rule that `Status: Accepted` is never set
> without explicit user confirmation. It narrows *which agent* may set it once
> that confirmation exists. An agent that believes an ADR is ready says so and
> escalates; it does not edit this field.
>
> **Before acceptance** (none of these needs a story):
> 1. ADR-0001 and ADR-0006 are Accepted.
> 2. V1 to V7 (Engine Compatibility) have recorded results. V1 to V4, V6 and V7 run in one
>    throwaway project, `prototypes/adr-0007-harness-check/` (its own `project.godot`, a copy of
>    `addons/gdUnit4/` 6.2.0, no game code); V5 runs on a scratch GitHub branch the user pushes.
>    Results are copied into `docs/engine-reference/godot/current-best-practices.md`. Where a
>    result takes a branch, this ADR is revised to that branch first.
> 3. The user has confirmed or overturned each item in Decision 13, one by one.
>
> **After acceptance** (stories): the first harness story builds `tools/lint/`, the shared
> helpers in `tests/helpers/`, the `[gdunit4]` project settings and the seeded-file proof
> (Validation 3). Reopen trigger: if the seeded-file proof cannot make the lint fail for a rule,
> or the lint needs more than ten file exceptions by the end of MVP, this ADR is amended before
> the next story closes.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference and against the gdUnit4 6.2.0 source
vendored in `addons/gdUnit4/` (read, not run). The live Godot and gdUnit4 documentation was not
reachable from the authoring session, and no Godot binary exists in it, so every engine or tool
behaviour that neither source covers is marked NEEDS VERIFICATION and listed in V1 to V7.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode.

## Summary

Seven ADRs push their checks here ("ADR-0007's lint", "the ADR-0007 harness"), and TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014 and TR-tower-014 need one way to build fixtures, record signals with their payloads, catch `push_error` and prove wiring, all headless. This ADR decides gdUnit4 6.2.0 (vendored, pinned) run headless after a `--import`, shared test helpers in `tests/helpers/` with no `class_name`, a recording fake that checks every payload against the declared signal types, `gdunit4/report/godot/push_error` on so any unasserted error fails a test, and one GDScript lint in `tools/lint/` (run as a gdUnit4 integration test) that enforces the layer rule, the `class_name` policy and every mechanical rule earlier ADRs deferred, each rule proven on a seeded bad file.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) with gdUnit4 6.2.0 (`addons/gdUnit4/plugin.cfg`) |
| **Domain** | Core (scripting, test and CI tooling) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM (post-cutoff engine; the test runner's command line and exit codes are in the pinned reference, error capture and the CI action are not) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 to 4.7 GDScript rows, `RegEx` `show_error`), `deprecated-apis.md` (string `connect()`), `current-best-practices.md` (GDScript 4.5 and 4.7, Command Line: Tests and Parse Check). No `modules/` file covers scripting or testing. Also read as a source of tool behaviour: `addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd`, `GdUnitTestSessionRunner.gd`, `src/core/GdUnitSettings.gd`, `src/monitor/GodotGdErrorMonitor.gd`, `src/asserts/GdUnitGodotErrorAssertImpl.gd`, `src/GdUnitTestSuite.gd`, `.godot/global_script_class_cache.cfg`, `.github/workflows/tests.yml`, `.gitignore`, `.claude/scripts/godot-parse-check.gd`. |
| **Post-Cutoff APIs Used** | Variadic parameters `...args: Array` (4.5, sourced) in the recording fake's lambda. Typed-return overrides need an explicit `return` (4.7, sourced). Packed-array element writes skip the setter (4.7, sourced). Indirectly: gdUnit4 6.2.0 captures errors through `Logger`, `OS.add_logger` and `ScriptBacktrace` (4.5 engine API, read in the addon source; NOT SOURCEABLE in `docs/engine-reference/godot/**`). |
| **Verification Required** | V1 to V7 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: gdUnit4 6.2.0 (not 6.2.2) on 4.7.2; how the `Logger` callback reports `push_error` and engine errors, and whether `assert_error(...).is_push_error()` consumes them; whether the gdUnit4 GitHub action imports first and which exit codes fail its job; `.tscn` and `export_presets.cfg` key names; whether nested `prototypes/*/project.godot` folders are imported into the main project; `ClassDB.class_exists` results for this project's class names. |

> **Note**: Knowledge Risk is MEDIUM, so this ADR must be re-validated if the project upgrades
> the engine or gdUnit4. Flag it as "Superseded" and write a new ADR.

### Verification items

Expected results are unsourced unless marked. All run before acceptance, outside `src/`, as the Status note says. Owner of every item: the user runs it; godot-specialist records the result in `current-best-practices.md` (Command Line section) and revises this ADR where a branch applies.

- **V1. gdUnit4 6.2.0 on Godot 4.7.2: the exit ladder.** The pinned reference observed gdUnit4 **6.2.2** on 4.7.2 (Windows); the vendored copy is **6.2.0**, and gdUnit4's README listed 6.2.x for 4.5 to 4.7.1 only. Run the CI command (Decision 2) on Linux x86-64 and on the user's Mac over five seeded suites, one per run: all passing (expect 0), one failing (100), one leaked `Node` (101), one test script that does not parse (105), no suites (0 with `No test cases found`); and once without `--ignoreHeadlessMode` (103). The vendored source agrees with these codes (`GdUnitTestSessionRunner.gd` lines 19 to 24; `report_exit_code()`), which makes this a check of the build, not of the reading. Also record: whether a failure stops the whole run without `-c` (the CI runner calls `fail_fast(true)`), and whether a non-suite script under `tests/helpers/` is skipped by discovery. *If 6.2.0 misbehaves*: upgrade to the newest 6.2.x through one reviewed change and rerun V1.
- **V2. Error capture headless.** In one suite, with `gdunit4/report/godot/push_error=true` in the throwaway `project.godot`: (a) a test that calls `push_error("x")` and asserts nothing fails; (b) `await assert_error(f).is_push_error("x")` around a callable that pushes `"x"` once passes; (c) the same assertion around two identical `"x"` pushes fails (one left over); (d) with the setting off, (a) passes; (e) an engine error (a second `connect` of the same method Callable; `get_node` on a missing path) fails a test, and the message text gdUnit4 records is copied down; (f) `push_warning("w")` with the setting on fails a test (the source appends warnings when the push setting is on); (g) a `push_error` from a method reached through a method Callable inside the asserted lambda is caught. Expected: all as stated, read from `GodotGdErrorMonitor.gd` and `GdUnitGodotErrorAssertImpl.gd`. *If (a) passes with the setting on*: the error-capture half of Decision 7 is void; the Rollback plan applies.
- **V3. The recording fake's listener.** On 4.7.2, `sig.connect(func(...args): ...)` receives zero, one and six arguments; `typeof()` of an argument emitted as `&"a"` is `TYPE_STRING_NAME`, and an argument emitted as `"a"` into a parameter declared `StringName` arrives as `TYPE_STRING` (no conversion into an untyped variadic lambda). `get_script_signal_list()` gives each argument's declared `type`. Expected (from the reference's 4.6.1 observation and pre-cutoff knowledge): yes to all. Run beside ADR-0006 V1 and V2 in the same script. *If the variadic lambda fails*: the fake uses one method per arity (`on_0` to `on_6`) with `bind(signal_name)`, which tests may use.
- **V4. Import on a fresh clone.** Clone the repo (tracked `.godot/global_script_class_cache.cfg`, nothing else under `.godot/`): run the test command with no import (record the exit and output), then `godot --headless --path . --import` and the test command (expect 0). Repeat the import ten times on Linux and record any exit 139 (the reference saw 3 crashes in 17 runs on Windows). Then add a script with a new `class_name`, run the import, and confirm the cache file gains it. *If the run without import works*: the import stays anyway (Decision 2), as cheap insurance for stale caches.
- **V5. The CI action.** On a scratch branch, four pushes, one mutation each: a failing test, a leaked node, a parse error, and an empty `tests/unit` plus `tests/integration`. Record per push: whether `godot-gdunit-labs/gdUnit4-action@v1` ran an import step, the runner's exit code in the log, and whether the job went red. Also record the JUnit XML path and its `tests=` attribute. *If the action imports and fails on 100, 101 and 105*: keep it, plus the zero-test step (Decision 2). *If not*: replace it with explicit steps (download 4.7.2, import, run the command, read the exit code with the Decision 2 ladder).
- **V6. Lint engine facts.** In a headless script: `RegEx.create_from_string("(?<![\\w.])floor\\s*\\(")` compiles and matches `floor(x)` but not `.floor(` or `floorf(` (PCRE2 lookbehind); `DirAccess` lists `res://src` recursively headless; `ClassDB.class_exists(n)` is false for every class name fixed by ADR-0001 to ADR-0009 (list in Decision 10) and true for `Node`, `Input` and `Engine`; a scene saved in the editor with one signal connected holds a line starting `[connection signal=`; whether the main project's import lists any file under `prototypes/*/` (folders with their own `project.godot`) in `.godot/`. *If `ClassDB` reports a collision*: that one class is renamed (Decision 10) and the owning ADR amended before acceptance.
- **V7. Export preset file.** Create one Android preset in the editor and read `export_presets.cfg`: the key that holds the non-resource include filter (expected `include_filter`), the exclude key (expected `exclude_filter`), and whether keystore passwords are written to it or to `.godot/export_credentials.cfg` (expected the latter). *If secrets are written to `export_presets.cfg`*: it stays gitignored, PROJ-6 and PROJ-7 run only on a developer machine, and ADR-0002 Validation 10 is amended to say so.

Not relied on: gdUnit4's scene runner input simulation (gdUnit4 warns that input events are not transported headless; Decision 3 bans it), `assert_signal` and `monitor_signals` (Decision 4 bans them), any GDScript warning-as-error project setting.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed: `BattleBuilder.build`, `FatalRelay` and its `push_error`, `dev_error` sink, the weakref proof, the no-autoload and `obj.method` rules this lint enforces), ADR-0006 (Proposed: the signal table, `Battle.emitters()`, `battle_signal_contract.gd`, the listener-count tests whose harness this is, the rule that wiring rules bind `src/` and tests may connect, disconnect and call test seams). Both must be Accepted before this can be implemented. |
| **Enables** | ADR-0008 (resolver tests use the recording fake; its rules join the lint table), ADR-0010 (bot scripts run through the battle runner; its result enums and command names feed WIRE-9), ADR-0011 (view-pool and Control rules join the lint and scene test); and every Logic and Integration story's test evidence. |
| **Blocks** | The first harness story (lint, helpers, project settings); every story whose acceptance needs a recording fake, a fixture catalogue, the error-capture setting or the lint, which is every Logic and Integration story of the MVP epics. |
| **Ordering Note** | The lint enforces registered stances of ADR-0002, ADR-0003, ADR-0004, ADR-0005 and ADR-0009 (all Proposed). It does not depend on them being Accepted, but when one of them changes a rule, its lint row changes in the same change. The harness story runs right after ADR-0001's `FatalLatch` story, so every later story lands under the lint. ADR-0001 V1 (Callable reference semantics) is run before acceptance by ADR-0001 itself; its kept test (ADR-0001 Validation 3b) uses this harness's weakref helper. |

## Context

### Problem Statement

GDScript has no module boundaries, no access control and one global `class_name` namespace (`architecture.md` layer rule 6), so the layer map, the wiring rules and the ownership tables of ADR-0001 to ADR-0009 hold only if something checks them. Those ADRs say "ADR-0007's lint" or "the ADR-0007 harness" more than forty times. Six requirements also fix how tests must work: code-built fixtures with no file I/O (TR-data-012), a recording fake instead of `assert_signal` (TR-input-014), enumerable battles with a listener-count test (TR-state-013), `push_error` asserted through gdUnit4 with the report setting on (TR-combat-012), content tests on in-memory records and no scenes in unit tests (TR-enemy-014), spy accessor and fake `halted()` (TR-tower-014). This must be decided before the first story, because every story's tests use it.

### Current State

- `addons/gdUnit4/` holds gdUnit4 **6.2.0** (MIT). It declares 202 global classes in the tracked class cache (`GdUnit*`, `Gd*`, plus `Comparator`, `Fuzzer`, `ValueProvider`, `LocalTime`, `RPC`, `ErrorLogEntry`, `XmlElement`, `CmdOption` and others). None equals a name fixed by ADR-0001 to ADR-0009 (checked against the cache file).
- `tests/` has `unit/`, `integration/` (each with a `.gdignore_placeholder` file only), `smoke/critical-paths.md` and a `README.md` that is stale: it says gdUnit4 is not installed (QQ-13).
- `.github/workflows/tests.yml` runs `godot-gdunit-labs/gdUnit4-action@v1` with `godot-version: '4.7.2'`, `version: 'installed'`, over `tests/unit` and `tests/integration`.
- `project.godot` has no `[gdunit4]` section, so `report/godot/push_error` is at its default, off (`GdUnitSettings.gd` line 135).
- `.gitignore` ignores `export_presets.cfg`, which ADR-0002 Validation 10 wants CI to read.
- `src/` holds only `CLAUDE.md`; no game code exists. No lint exists.

### Constraints

- Solo, part-time developer: one command runs everything, and a failing gate names the file, line and rule.
- No autoloads (ADR-0001): no harness singleton, and the lint itself checks `project.godot`.
- Unit tests do no file I/O, use no scene and are deterministic (coding standards, TR-data-012, TR-enemy-014).
- Skill-authoring rules: a gate must be watched failing; an absent input is never a pass; covered sets are derived where the category is crisp, and a kept list says why.
- The pinned reference does not cover the error-capture path or the CI action, so the decisions that rest on them carry a fallback.

### Requirements

- Must build fixture catalogues in code through `Catalogue.from_data` (ADR-0002 Decision 9).
- Must record signals into one ordered log and compare whole logs, arguments and their types (TR-input-014, ADR-0006 Implementation Guidelines).
- Must let tests enumerate a battle's systems, snapshot it and run the listener-count test (TR-state-013, ADR-0006 Decision 8).
- Must fail a test on any unasserted `push_error` or engine error, and assert expected ones by message (TR-combat-012).
- Must enforce, mechanically where possible, the layer rule and every rule earlier ADRs deferred, and say which are left to code review.
- Must list what cannot run headless and where its evidence goes.

## Decision

### 1. Framework, folders and names

1. **gdUnit4 6.2.0, vendored and pinned.** It stays in `addons/gdUnit4/`; CI uses it through `version: 'installed'`. An upgrade is its own reviewed change that reruns V1 and V2. No second test framework.
2. **Folders.** `tests/unit/<system>/` (Logic), `tests/integration/<system>/` (multi-system, real data, the lint), `tests/helpers/` (shared helpers, Decisions 3 to 7), `tests/baselines/<arch>/` (ADR-0004), `tests/integration/battle_wiring/` (ADR-0006), `tests/integration/content/` (ADR-0002), `tests/integration/lint/` and `tests/unit/lint/` (Decision 8). A helper used by one system only may live in `tests/unit/<system>/helpers/` (the Input GDD's choice). `<system>` is the module folder name under `src/` (`combat`, `enemy_wave`, `input_gesture_resolver` as the Input GDD names it).
3. **Names** follow `.claude/rules/test-standards.md`: `<system>_<feature>_test.gd`, `test_<scenario>_<expected>()`, arrange/act/assert, suites `extends GdUnitTestSuite`.
4. **No `class_name` outside `src/`.** Helpers, fakes, lint scripts and test suites declare none. Tests reach a helper by path: `const Fakes := preload("res://tests/helpers/fakes.gd")`. This keeps test names out of the global namespace and out of the export (NAME-3). A helper that extends a game class does so by name (`extends StatAccessor`).

### 2. Running the tests, locally and in CI (QQ-13)

The command is the one in `coding-standards.md` and `project.yaml` `commands.test`, always preceded by an import:

```bash
godot --headless --path . --import          # every run; retry once if it exits 139 (reference: crash on exit)
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

- **Import every time.** The class cache is tracked, but it goes stale whenever a story adds or renames a `class_name`, and the other `.godot/` files are not tracked. The import costs seconds. `.claude/scripts/test-run.sh` already does it. A story that adds or renames a `class_name` also commits the regenerated `.godot/global_script_class_cache.cfg`.
- **Exit ladder** (pinned reference, agrees with the vendored source): 0 pass; 100 a test failed; **101 fails the gate** (every test passed but a node leaked; an orphan is a missed `queue_free` or `detach`, ADR-0001); 103 headless refused; 104 engine too old; 105 a test script does not parse; 1 before the first import; any other code is NOT ASSESSED. **0 with `No test cases found` is not a pass.**
- **CI** keeps the gdUnit4 action for now (V5 decides). One step after it fails the job when no JUnit report exists or its total `tests` is 0, so an empty run cannot read as green. Branch on V5 as stated there.
- `-c` (run on after a failure) is a local convenience only; CI keeps fail-fast.

### 3. Fixtures and fakes (TR-data-012, TR-tower-014, TR-enemy-014)

- **Catalogue fixtures.** `tests/helpers/catalogue_factory.gd` returns dictionaries in exactly the file shape (ADR-0002 Decision 9). `minimal()` is the smallest valid catalogue (one stage, wave, enemy, tower, hero, burst, input record); tests copy and edit it, then call `catalogue(data, label)`, which returns `Catalogue.from_data("fixture:" + label, data)`'s `LoadResult` unchanged, so a test asserts `ok` itself and the validator runs exactly as in production. Fixture values are named constants in the factory, binary-exact (multiples of 1/4, sums below 2^20) as the Combat and Enemy & Wave GDDs require, never inline literals except at a tested boundary.
- **Real data** is read only by integration suites: `tests/integration/content/` (ADR-0002 Decision 8; content rules run as `check_<rule>(catalogue)` on the in-memory records of the loaded catalogue, each with a broken fixture from the factory) and `tests/integration/data/` (`load_manifest`).
- **Fakes for injected values** (`architecture.md` B9) are inner classes of `tests/helpers/fakes.gd`, each one object with method Callables, so a test passes `fake.method` exactly as the Builder would: `Halted` (`var value := false`, `halted() -> bool`), `InBuild`, `Fatal` (records every cause in order; optionally sets a `Halted`), `DevErrors` (`report(msg)` records), `Targets` (`targets() -> Array[Targetable]` over a list the test fills), `Canceller` (counts `cancel()`), `ToTicks` (wraps a real `SimTime`, so conversion is never faked). Unit tests inject these; only Builder-level tests use the real relay (Decision 7).
- **Spy accessor.** `tests/helpers/spy_stat_accessor.gd`, as ADR-0005 Decision 9 states (`extends StatAccessor`, `super(catalogue, fatal)`, typed returns on every path).
- **System factories** (Combat's `enemy()`, Tower's `sim()`, Flow's `stage()`, the resolver's targets) live with their system's tests and use the values their GDD's Acceptance Criteria preamble fixes.
- **No scene, no files, no engine input in unit tests.** Unit suites never load or instantiate a `.tscn`, never use gdUnit4's `scene_runner` or `simulate_*` input calls, and never touch `FileAccess`, `DirAccess`, `ConfigFile` or `ResourceLoader` (TEST-2, TEST-3, TEST-5). Adapter tests call the adapter's handlers directly with constructed `InputEventScreenTouch` objects (ADR-0003 Validation).

### 4. The recording fake (TR-input-014, ADR-0006 payload rule)

`tests/helpers/recording_fake.gd` (no `class_name`):

- `watch(sig: Signal)` connects one variadic lambda (`func(...args)`, V3) that appends `{signal, args}` to **one** ordered log shared by every watched signal; `watch_all(emitter)` watches every signal from `get_script().get_script_signal_list()`.
- **At record time it checks each payload against the declaration**: the argument count equals the declared count, and each `typeof(arg)` equals the declared type (`TYPE_STRING_NAME` for IDs, `TYPE_INT` for enums, `slot_index`, `spawn_id`, resolver ids and `level`). A declared `TYPE_NIL` (untyped) or `TYPE_OBJECT` parameter is itself recorded as an error, because ADR-0006 requires typed, object-free payloads. Errors collect in `type_errors()`; `expect(expected)` fails on any of them. This turns "signal parameter types are not checked at `emit()`" (QQ-15) into a test failure.
- `expect(expected: Array) -> PackedStringArray` compares the **whole** log in order with `[name, [args...]]` entries; `ANY` (a unique sentinel object in the fake) matches any value of the right type; anything unlisted, missing or out of order is a line in the result. An empty result is a pass. Floats compare exactly (the sim is deterministic and fixtures are binary-exact).
- It holds payload values only, never the emitter, so it cannot keep a battle alive in a weakref test.
- `assert_signal` and `monitor_signals` are not used (TEST-1): they count and await, and the GDDs require whole, ordered, typed logs.

### 5. Battle probes: enumerate, snapshot, run (TR-state-013, ADR-0004 Validation 6)

- **Enumerate.** Tests reach a battle's systems through `Battle.emitters()` and `Battle.EMITTER_KEYS` (ADR-0006). `tests/helpers/battle_probe.gd` has `system(battle, key) -> Object`. No new `Battle` API.
- **Snapshot.** `battle_probe.gd` `digest(battle) -> String`: `JSON.stringify` with sorted keys and full precision (the form `Catalogue.snapshot()` uses, ADR-0002) of read-only queries only: phase, lives, gold, `ticks_run()`, then each system's queries as their ADRs add them (roster `spawn_id`, `pos_x`, `pos_y`, `distance`, HP; slots; hero position). A digest never reads a private field, so it cannot steer.
- **Run.** `battle_runner.gd` `run(battle, ticks, between: Callable) -> PackedStringArray` calls `between(i)` (the command script; ADR-0010 fixes its format) then `battle.tick(battle.sim_time.dt)` and records `digest` after each tick. Two runs of one `(fixture, stage, rng_seed, script)` compare tick by tick.
- **Baselines.** `baselines.gd` names `res://tests/baselines/<arch>/<name>.json` from ADR-0004 V4's architecture call. A comparing test with no baseline for its architecture **fails** with `NOT ASSESSED: no baseline for <arch>`; gdUnit4 has no third state, and a skip reads as green. Baselines are written only by `tools/baseline/record_baselines.gd` (a `SceneTree` script run by hand and reviewed), never by a test (TEST-4).
- **Weakrefs.** `battle_probe.gd` `alive(refs: Array[WeakRef]) -> PackedStringArray` names each ref that still resolves; ADR-0001 Validation 3 asserts it empty in the same frame as the drop.

### 6. The listener-count harness (TR-state-013; contract owned by ADR-0006)

ADR-0006 Decision 8 owns what is checked. This ADR owns how: `tests/helpers/wiring_check.gd` `check(battle, contract: GDScript) -> PackedStringArray` runs ADR-0006's five checks and returns one line per failure, naming emitter, signal and listener. `tests/integration/battle_wiring/battle_wiring_test.gd` builds a battle on `CatalogueFactory.minimal()` with `Fakes.Fatal` as `fatal_handler`, asserts `check` is empty and the emitter count is non-zero, then disconnects W2 (tests may, per ADR-0006 Decision 2) and asserts `check` returns exactly the one line `enemy_wave.enemy_killed: missing tower_sim.on_enemy_killed`. The self-proof therefore runs on every CI run; its first output is also kept in `production/qa/evidence/adr-0006-listener-self-proof/`.

### 7. Errors: `push_error`, engine errors and `dev_error` (TR-combat-012)

1. `project.godot` sets, in a `[gdunit4]` section, `report/godot/push_error=true` and `report/godot/script_error=true` (PROJ-5). With them, gdUnit4's error monitor reports every `push_error`, `push_warning`, engine error and script error logged during a test as a failure (`GodotGdErrorMonitor.gd`; V2).
2. An **expected** error is asserted, one per assertion, with `await assert_error(callable).is_push_error(MESSAGE)` against the emitting code's constant (Combat's `ERR_*`, the relay's cause). Each assertion consumes one matching entry; a leftover fails the test, so "exactly one" holds (Combat GDD). A silent case uses `is_success()`.
3. **Unit tests inject fakes** for `fatal` and `dev_error` (Decision 3), so no `push_error` happens and the fake's record is asserted instead. **Builder-level tests** use the real `FatalRelay`, which calls `push_error(cause)` (ADR-0001 Decision 3); they wrap the triggering call in `assert_error(...).is_push_error(cause)`.
4. `src/` never calls `push_warning` (ERR-3): with the setting on it fails tests, and ADR-0001 has no warning tier (`dev_error` is the non-fatal sink).
5. **Combat's invariant I** is `tests/helpers/combat_invariant.gd` `check(recorder, combat, created: Array[Targetable]) -> String` (empty when the sums agree, exactly, in creation order). Combat suites call it in `after_test()`. Its kept negative tests tamper with HP, a counter and the log one at a time, call it directly and assert a non-empty result (Combat GDD).
6. The proof that an **unasserted** `push_error` fails a test cannot stay in CI as a test that must fail. It is V2 (a) and (d) before acceptance, and the seeded run of Validation 4 after, kept as evidence; PROJ-5 keeps the setting on.

### 8. The lint: one GDScript tool, run as a test

- **Files.** `tools/lint/lint_rules.gd` (the rule table, scopes, exception table and allowlists, all `const`), `tools/lint/lint_engine.gd` (pure: `build_index`, `check_source` and `check_project`, Key Interfaces; no file access), `tools/lint/run_lint.gd` (`extends SceneTree`; walks the repo, reads files, prints findings, `quit(1)` on any, `quit(0)` otherwise, the pattern of `godot-parse-check.gd`). None declares `class_name`.
- **CI path.** `tests/integration/lint/repo_lint_test.gd` reads every `.gd` and `.tscn` under `res://src/`, `res://tests/` (TEST and NAME rules only) and `res://tools/` (NAME rules only), plus `project.godot` and `export_presets.cfg`, passes them to the engine and fails listing every finding as `<res path>:<line>: <RULE> <message>`. It also prints files scanned, rules run and findings per rule, and **fails when it scanned no `.gd` under `src/`** (an empty scan is NOT ASSESSED, not a pass). So the lint runs inside the existing CI command and test paths, with no new workflow step. `run_lint.gd` gives the same output locally: `godot --headless --path . -s res://tools/lint/run_lint.gd`.
- **Self-tests.** `tests/unit/lint/lint_rules_test.gd` feeds in-memory sources (no file I/O) to `check_source` with fake paths such as `res://src/core/x.gd`. For **every** rule ID in `lint_rules.gd` it needs one bad sample that yields exactly that finding on the expected line, and at least one near miss (the token in a comment, in a string, in an allowed file or out of scope) that yields none. The test iterates the rule table, so a rule with no bad sample fails the suite: coverage is derived from the table, not listed.
- **Lexer.** Before matching, the engine masks comments (`#`, `##`) and string contents (`"`, `'`, triple-quoted, `&"..."`, `^"..."`, raw `r"..."`), keeping line numbers, and joins a statement continued inside open brackets or after `\`. Path rules read the unmasked string of `preload`, `load` and `.tscn` `ext_resource path=`. Function bodies are found by indentation.
- **No inline suppressions.** An exception is a row in `lint_rules.gd`'s `FILE_EXCEPTIONS` naming the rule, the file and the ADR decision that allows it. Exceptions are reviewed like code. The Status note's reopen trigger caps them.
- **Derived sets** (skill-authoring obligation 5): the class-to-layer map and every `class_name` come from scanning the repo; engine class names come from `ClassDB.class_exists`; the battle signal set comes from the keys of `tests/integration/battle_wiring/battle_signal_contract.gd` (ADR-0006), whose completeness its own test proves; enum names come from `enum` declarations in `src/`. **Kept lists, and why**: the sim scope (no mechanical test tells a sim class from a view), the command names (ADR-0004's registry list; ADR-0010 extends it), the gesture signals allowed to issue commands (ADR-0006 Decision 7 rule 3), the project keys (copied from ADR-0001, ADR-0003, ADR-0004). Whoever changes one of those ADRs changes the row in the same change.
- **Sim scope** (ADR-0004 Decision 9): `src/core/**`, `src/feature/**`, `src/foundation/data/**`, `src/foundation/sim_time.gd`, `src/foundation/sim_rng.gd`, `src/foundation/fatal_latch.gd`, `src/root/battle.gd`, `src/root/fatal_relay.gd`, `src/root/battle_builder.gd`.

**Rule table.** Scope is `src/` unless stated. A pattern is matched on masked code.

| ID | Rule (fails when) | Source |
|---|---|---|
| **LAYER-1** | A file references a `class_name` or a `res://src/<layer>/` path of a higher layer. Ranks: `foundation` 0, `core` 1, `feature` 2, `presentation` 3, `root` 4. `root` may reference all; nothing below may reference `root`. `extends`, type hints, `Class.CONST`, `Class.Enum` and `.tscn` script paths all count | `architecture.md` rules 1, 2, 3, 5 |
| LAYER-2 | A file in `src/feature/<m>/` references a class or path in `src/feature/<n>/`, m not n | rule 4 |
| LAYER-3 | A `.gd` or `.tscn` under `src/` is not inside one of the five layer folders | rule 6 |
| LAYER-4 | `src/` references a class declared under `addons/`, `tests/`, `tools/` or `prototypes/`, or a path there | rule 2, Decision 1 |
| NAME-1 | Two scripts anywhere under `src/`, `tests/`, `tools/`, `addons/` declare the same `class_name` | QQ-16 |
| NAME-2 | A `src/` `class_name` is an engine class (`ClassDB.class_exists`) | QQ-16 |
| NAME-3 | A script under `tests/` or `tools/` declares `class_name` | Decision 1 |
| NAME-4 | A `src/` `class_name` is not the PascalCase of its file name (`battle_clock.gd` is `BattleClock`) | `project.yaml` naming |
| NAME-5 | A function, parameter or variable in `src/` is named `load` or `seed` | ADR-0001, ADR-0002 |
| WIRE-1 | `Callable(` appears | ADR-0001 Decision 5 |
| WIRE-2 | `connect(`, `disconnect(`, `is_connected(` or `emit_signal(` takes a string or StringName literal first | ADR-0001, ADR-0006 Decision 1 |
| WIRE-3 | A lambda (`func` followed by `(` with no name) appears | ADR-0001 (tightened, Decision 13 C2) |
| WIRE-4 | `.bind(` or `.unbind(` appears | ADR-0001 |
| WIRE-5 | A `CONNECT_` constant appears | ADR-0006 Decision 2 |
| WIRE-6 | `.<s>.connect(` or `.<s>.disconnect(` for a battle signal `s` appears outside `src/root/battle_builder.gd` and `src/root/battle_wrapper.gd` | ADR-0006 Decision 2 |
| WIRE-7 | A `.tscn` under `src/` has a `[connection` line | ADR-0006 Decision 2 (V6) |
| WIRE-8 | A battle-signal connection `x.s.connect(y.m)` has `m` other than `on_s` or `_on_s` | Decision 13 C3 (makes WIRE-9 possible) |
| WIRE-9 | The body of a function named `on_s` or `_on_s`, for a battle signal `s`, calls `.tick(`, `.deliver(`, `.apply_slow(` or a command (`pin`, `burst`, `build`, `upgrade`, `start_wave`, `call_early`, `pause`, `resume`), unless `s` is a gesture signal G1 to G6 (`pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended`). In `src/presentation/` and `battle_wrapper.gd` such a body also may not call `.emit(`, `.connect(`, `.disconnect(` or `request_retry(`. For `attack_fired` and `damage_applied` it may not call `stat_int(` or `stat_float(` | ADR-0004 `command_inside_tick`, ADR-0006 Decision 7 rules 1 to 4 |
| WIRE-10 | A `signal` parameter is untyped, or typed other than `int`, `float`, `bool`, `StringName`, `Vector2` or an enum declared in `src/` | ADR-0006 Decision 4 |
| WIRE-11 | `signal` is declared under `src/foundation/data/` | ADR-0002, ADR-0006 |
| WIRE-12 | A parameter or variable named `id` or `*_id` is typed `String` | ADR-0006 Decision 4 |
| STATE-1 | `static var` appears | ADR-0001 Decision 5 |
| STATE-2 | A member variable is typed `Battle` outside `src/root/app_root.gd` and `src/root/battle_wrapper.gd` | ADR-0001 `sim_back_reference_to_battle` |
| STATE-3 | `func reset(` in sim scope | ADR-0001 `in_place_reset` (`drop_backlog` is not matched) |
| STATE-4 | `.hp`, `.max_hp`, `.strength` or `.ticks_left` is assigned (`=`, `+=`, `-=`, `*=`, `/=`) outside `src/core/combat/` | ADR-0009 `hp_change_outside_deliver` |
| STATE-5 | `.add_enemy(` outside `src/feature/enemy_wave/` | ADR-0009 Decision 7 |
| STATE-6 | `roster()`, `targets()` or `targets.call()` is followed directly by `.append(`, `.erase(`, `.sort`, `.clear(`, `.remove_at(`, `.insert(`, `.push_*`, `.pop_*`, `.resize(`, `.fill(`, `.reverse(`, `.shuffle(` or `.assign(` | ADR-0009 `mutate_roster_view` (partial, see blind spots) |
| STATE-7 | In `targetable.gd`, `enemy.gd`, `health.gd`, `status.gd` or `path_track.gd`, a member is typed `ReadContext`, `EnemyWave`, `Combat`, `Battle`, `Callable`, `Targetable`, `Enemy`, `Object`, `Node` or `RefCounted`, or is untyped | ADR-0009 `combat_piece_back_reference`, ADR-0005 |
| STATE-8 | Inside `for x in a:`, the body calls `a.erase(`, `a.remove_at(`, `a.pop_*(` or `a.clear(` | ADR-0009 `remove_during_foreach` |
| STATE-9 | In one file, a member with a setter typed `Packed*Array` has an element written (`name[i] =`) | QQ-15, `breaking-changes.md` 4.7 |
| STATE-10 | `catalogue.gd` or a file under `src/foundation/data/records/` declares a `Callable` member | ADR-0002 Implementation Guidelines |
| STAT-1 | The second argument of `stat_int(` or `stat_float(` does not start with `StatKeys.` | ADR-0005 `stat_key_literal` |
| TIME-1 | `_physics_process` is declared | ADR-0004 |
| TIME-2 | `_process` is declared outside `battle_wrapper.gd`, `app_root.gd`, `input_adapter.gd` | ADR-0004 |
| TIME-3 | `Timer`, `create_timer(`, `await`, `Engine.time_scale`, `Engine.get_frames_drawn`, `Engine.get_process_frames`, `Engine.get_physics_frames`, `Time.` or `OS.get_ticks_` appears. Exceptions: `Time.get_unix_time_from_system` and `Time.get_ticks_msec` in `app_root.gd` (seed, ADR-0004 V8), `Time.get_ticks_usec` in `battle_wrapper.gd` (dev timers) | ADR-0004 `engine_time_in_sim` (widened to all `src/`, Decision 13 C4) |
| TIME-4 | `get_tree().paused` or `low_processor_mode` appears | ADR-0003, ADR-0004 |
| TIME-5 | `-= dt`, `-= delta`, `-= _dt` (or `= x - dt` on the same name) in sim scope | ADR-0004 `float_duration_countdown` |
| MATH-1 | A global `floor`, `ceil`, `abs`, `sign`, `round`, `sin`, `cos`, `tan`, `atan2`, `pow`, `exp`, `log`, `fmod`, `fposmod`, `lerp`, `move_toward` or `snapped` call (not preceded by `.` or a word character) in sim scope | ADR-0004 `sim_nondeterministic_math` |
| MATH-2 | `.distance_to(`, `.distance_squared_to(`, `.normalized(`, `.direction_to(`, `.angle_to(`, `.rotated(`, `.limit_length(`, `.dot(`, `.cross(` in sim scope | ADR-0004, ADR-0009 |
| MATH-3 | `RandomNumberGenerator`, or a global `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed` call, in sim scope | ADR-0004 `engine_rng_in_sim` |
| MATH-4 | `rng_seed` or `sim_rng` appears under `src/presentation/` | ADR-0004 |
| MATH-5 | `get_instance_id(` or a global `hash(` in sim scope | ADR-0004 `unordered_iteration_in_sim` (partial) |
| MATH-6 | A member typed `Vector2` (or initialised `:= Vector2(`) in sim scope | ADR-0009 `sim_position_representation` |
| INPUT-1 | `_input` or `_unhandled_input` is declared outside `src/foundation/input/input_adapter.gd` | ADR-0003 |
| INPUT-2 | `_gui_input` is declared outside the files in `MODAL_SCREENS` (empty until the first modal story adds its file) | ADR-0003 Decision 8 |
| INPUT-3 | `Input.` (the singleton) or `DisplayServer.` appears outside `input_adapter.gd` | ADR-0003 |
| INPUT-4 | `InputEventMouse` appears | ADR-0003 `mouse_event_in_battle_code` |
| INPUT-5 | `extends` a `BaseButton` type, `<Button type>.new(`, or a `.tscn` node `type="Button"` (and `CheckBox`, `CheckButton`, `LinkButton`, `MenuButton`, `OptionButton`, `TextureButton`, `ColorPickerButton`) | ADR-0003 (`Button.pressed` ban; Menu at VS revisits) |
| INPUT-6 | `.device` is compared with `==` or `!=` to a number literal | ADR-0003 `device_id_literal` |
| INPUT-7 | `Camera2D` (in `.gd` or as a `.tscn` node type), `canvas_transform =` or `set_canvas_transform(` | ADR-0003 |
| ERR-1 | `assert(` appears | ADR-0001 Decision 4 (tightened, Decision 13 C5) |
| ERR-2 | `print_debug(` appears | ADR-0001 |
| ERR-3 | `push_warning(` appears | Decision 7 |
| ERR-4 | `.free()` or a bare `free()` appears (`queue_free()` is not matched) | ADR-0001 `retry_node_teardown` (tightened, C5) |
| ERR-5 | `preload(` in `src/root/app_root.gd` | ADR-0001 `app_root_scene_loading` |
| TEST-1 | `assert_signal(` or `monitor_signals(` under `tests/` | TR-input-014 |
| TEST-2 | Under `tests/unit/`: `FileAccess`, `DirAccess`, `ConfigFile`, `ResourceLoader`, or `load(`/`preload(` of a path not ending `.gd` | TR-data-012 |
| TEST-3 | Under `tests/unit/`: `.tscn`, `instantiate(` or `scene_runner(` | TR-enemy-014 |
| TEST-4 | Under `tests/`: `FileAccess.WRITE` or `FileAccess.READ_WRITE` together with `baselines` in one file | ADR-0004 Decision 9 |
| TEST-5 | Under `tests/`: a gdUnit4 `simulate_` call | Decision 3 |
| PROJ-1 | `project.godot` has an `[autoload]` section | ADR-0001 V5 |
| PROJ-2 | `src/root/app_root.tscn` exists and `project.godot` lacks `run/main_scene="res://src/root/app_root.tscn"` under `[application]` | ADR-0001 Decision 1 |
| PROJ-3 | A key of ADR-0003 Decisions 3 and 4 is missing or differs (`config/quit_on_go_back=false`, viewport 540 and 960, `mode.mobile=3`, `stretch/mode="canvas_items"`, `stretch/aspect="keep"`, `handheld/orientation=1`, both pointing emulation flags `true`) | ADR-0003 (keys NEEDS VERIFICATION there, SP0) |
| PROJ-4 | `run/delta_smoothing=false` is missing under `[application]`, or `run/low_processor_mode=true` is present | ADR-0004 (key NEEDS VERIFICATION there, V9) |
| PROJ-5 | `[gdunit4]` lacks `report/godot/push_error=true`, or sets `report/godot/script_error=false` | Decision 7 |
| PROJ-6 | `export_presets.cfg` exists and a `[preset.N]` section's `include_filter` lacks `*.json` | ADR-0002 Validation 10 (key name V7) |
| PROJ-7 | `export_presets.cfg` exists and a preset's `exclude_filter` lacks `tests/*`, `tools/*`, `addons/gdUnit4/*` or `prototypes/*` | Decision 1 (key name V7) |

When `export_presets.cfg` is absent, PROJ-6 and PROJ-7 print `not assessed: no export_presets.cfg` on every run; they are not silent. ADR-0002 Validation 10 applies "once it exists", and the first phone-build story creates it.

**Known blind spots** (the lint sees names in text, not types): access through untyped variables, `get_node`, `Object.call` or `get`/`set`; a roster array stored in a variable and then mutated; `Dictionary` iteration order; field writes through a differently named receiver; a lambda built by `Callable` is impossible here only because WIRE-1 bans the constructor. These are covered by the tests and code-review rows in Decision 9.

### 9. Every deferred rule and its mechanism

| Deferred by | Rule | Mechanism |
|---|---|---|
| ADR-0001 | No string Callables, string `connect`, lambdas, `bind()` | Lint WIRE-1 to WIRE-4 |
| ADR-0001 | No mutable `static var` | Lint STATE-1 |
| ADR-0001 | No `[autoload]`; `main_scene` set | Lint PROJ-1, PROJ-2 |
| ADR-0001 | No `Battle` field in a sim; no `RefCounted` cycle | Lint STATE-2, STATE-7; weakref tests (ADR-0001 Validation 3) |
| ADR-0001 | No `assert`, no `print_debug` for release checks | Lint ERR-1, ERR-2 |
| ADR-0001 | No `free()` on a node in the current call; `queue_free()` after `detach()` | Lint ERR-4; retry weakref test |
| ADR-0001 | No `preload` in `app_root.gd` | Lint ERR-5 |
| ADR-0001 | Builder and wrapper are wiring only (no gameplay `if`) | **Code review only**: "a gameplay field" is not crisp in text |
| ADR-0001 | Session-lived objects hold no per-battle callable | **Code review** plus the retry weakref test after a bad accessor call |
| ADR-0001 | `is_valid()` before a held Callable on the fatal path | **Code review** plus the fatal-path tests (ADR-0001 Validation 4 to 6, 11) |
| ADR-0001 | Every wrapper node holding a sim implements `detach()` | Wrapper test (ADR-0006 Decision 8) plus the 3a weakref test |
| ADR-0001 | Typed-return override needs `return` (4.7) | The parser: a test script that fails to parse exits 105 |
| ADR-0002 | No method named `load` | Lint NAME-5 |
| ADR-0002 | `*.json` in every preset's non-resource filter | Lint PROJ-6 (needs `export_presets.cfg` tracked; Decision 13 C6) |
| ADR-0002 | Catalogue and records declare no signal, hold no Callable | Lint WIRE-11, STATE-10 |
| ADR-0002 | No record field written outside `src/foundation/data/`; IDs, not object references | **Code review** plus the read-only snapshot test (ADR-0002) |
| ADR-0002 | Data read with `FileAccess`/`JSON`, never `ResourceLoader` | **Code review** plus the Android export check (W2) |
| ADR-0003 | No `_input`/`_unhandled_input` or `Input` polling outside the adapter | Lint INPUT-1, INPUT-3 |
| ADR-0003 | `_gui_input` only in modal screens | Lint INPUT-2 |
| ADR-0003 | Non-modal battle Controls `MOUSE_FILTER_IGNORE`, all `FOCUS_NONE` | **gdUnit4 scene test** SCENE-1 (below); not a lint, because Controls built in code and inherited defaults are invisible in `.tscn` text |
| ADR-0003 | No mouse events, no `Button.pressed` | Lint INPUT-4, INPUT-5 |
| ADR-0003 | No `device` compared to a literal | Lint INPUT-6 |
| ADR-0003 | No `Camera2D` or canvas transform | Lint INPUT-7 |
| ADR-0003 | No `get_tree().paused` | Lint TIME-4 |
| ADR-0003 | Safe area and `DisplayServer` only in the adapter | Lint INPUT-3 |
| ADR-0003 | Canceled touch is `cancel_pointer`, never `release` | Adapter unit tests (ADR-0003 Validation) |
| ADR-0003 | Explicit display and emulation keys | Lint PROJ-3 |
| ADR-0004 | `_process` only in three files; no `_physics_process` | Lint TIME-1, TIME-2 |
| ADR-0004 | No engine time, timers, `await` or frame counters | Lint TIME-3 |
| ADR-0004 | No `low_processor_mode`; `delta_smoothing` off | Lint TIME-4, PROJ-4 |
| ADR-0004 | No `dt` subtraction from a duration | Lint TIME-5; the 301-tick regression test |
| ADR-0004 | Banned maths and `Vector2` methods on sim values | Lint MATH-1, MATH-2, MATH-6 |
| ADR-0004 | No engine RNG in sim; Presentation never reads `rng_seed`/`sim_rng` | Lint MATH-3, MATH-4 |
| ADR-0004 | No order from instance IDs, hashes or `Dictionary` order | Lint MATH-5 (IDs, hashes); **determinism test** for `Dictionary` order |
| ADR-0004 | No `reset()` on battle systems | Lint STATE-3 |
| ADR-0004 | No command inside a tick or from a listener | Lint WIRE-9; ADR-0004's `between_ticks()` development check |
| ADR-0004 | Determinism against `tests/baselines/<arch>/` | Battle runner and baselines (Decision 5) |
| ADR-0004 | No test writes its own baseline | Lint TEST-4 |
| ADR-0005 | Stat keys are `StatKeys` constants | Lint STAT-1 |
| ADR-0005 | No cached stat value | **Spy tests** per consumer (ADR-0005) plus code review |
| ADR-0005 | Entities never hold their own `ReadContext` | Lint STATE-7 (named entity files); weakref test (ADR-0005 Validation 7) |
| ADR-0006 | No `emit_signal`, no `CONNECT_` flag | Lint WIRE-2, WIRE-5 |
| ADR-0006 | Battle-signal connections only in builder and wrapper | Lint WIRE-6, WIRE-7; listener-count and wrapper tests |
| ADR-0006 | Typed, object-free payloads; `StringName` IDs | Lint WIRE-10, WIRE-12; the recording fake's type check |
| ADR-0006 | Listener rules (no commands in G7, G8 or view listeners; no accessor in P8, P9 listeners; no emit or connect in view listeners) | Lint WIRE-8, WIRE-9 |
| ADR-0006 | No sim listens to a view signal; non-emitters declare no signal | Listener-count test steps 4, 5 |
| ADR-0006 | No outcome depends on listener order; no re-emit inside own listener | **Code review** plus the with-and-without-listeners run (ADR-0006 Validation 4) |
| ADR-0009 | Combat-owned fields written only in `src/core/combat/` | Lint STATE-4 |
| ADR-0009 | `add_enemy` called only by EnemyWave and tests | Lint STATE-5 |
| ADR-0009 | `roster()`/`targets()` not mutated | Lint STATE-6 (direct calls); roster snapshot test (ADR-0009) for the rest |
| ADR-0009 | No removal inside a for-in loop | Lint STATE-8 |
| ADR-0009 | No `Vector2` field on `Targetable`, `Enemy`, `PathTrack`; no `Enemy` under `src/core/` | Lint MATH-6, LAYER-1 |
| ADR-0009 | Health and Status hold no reference; Enemy holds no context, system or Callable | Lint STATE-7 |
| QQ-16 | `class_name` collisions | Lint NAME-1 to NAME-4 |

**SCENE-1** (`tests/integration/hud/battle_controls_test.gd`, written by the first `BattleWrapper` story with ADR-0006's wrapper test): after `attach` on a fixture battle, walk every `Control` in the wrapper subtree; each must have `mouse_filter == Control.MOUSE_FILTER_IGNORE` and `focus_mode == Control.FOCUS_NONE`, except each modal screen's root (`MOUSE_FILTER_STOP`), named in the test's `MODAL_ROOTS` list. It instantiates a scene, so it is an integration test (headless instantiation of Control scenes is expected to work; the first run records it).

### 10. `class_name` policy (QQ-16)

No prefix. The names ADR-0001 to ADR-0009 fix stand, provided V6 finds no engine class among them: `AppRoot`, `Battle`, `BattleBuilder`, `BattleWrapper`, `BattleClock`, `FatalLatch`, `FatalRelay`, `DevErrorSink`, `SimTime`, `SimRng`, `Catalogue`, `CatalogueSchema`, `Validator`, `LoadResult`, `ValidationError`, `TowerRecord`, `TowerLevel`, `EnemyRecord`, `WaveRecord`, `WaveGroup`, `StageRecord`, `PinShape`, `HeroRecord`, `BurstRecord`, `InputRecord`, `StatKeys`, `StatAccessor`, `ReadContext`, `Targetable`, `Health`, `Status`, `Combat`, `DamageEvent`, `Flow`, `StageResult`, `Enemy`, `EnemyWave`, `PathTrack`, `TowerSim`, `HeroSim`, `InputResolver`, `InputAdapter`, `FieldMapping`, `FieldInsets`, `FieldBounds`, `HudLogic`, `HudTopBand`, `HudField`, `TowerInput`, `HeroInput`, `ChipWindow`, `PinGeometry`. NAME-1 and NAME-2 run on every CI run, so an engine upgrade or a new addon that adds a clashing class fails the build at once, naming both sides; the fix is then a rename of our class in one change. One `class_name` per file, matching the file name (NAME-4).

### 11. GDScript 4.7 pitfalls for the control manifest (QQ-15)

| Pitfall | Source | Rule | Enforced by |
|---|---|---|---|
| An override of a typed method inherits its return type and needs an explicit `return` on every path | `breaking-changes.md` 4.7 (sourced) | Required: every override of a typed method, including test spies, returns a value of that type on every path; never `return null` from `-> int` | Parser (exit 105 in tests; parse check) |
| Writing one element of a packed array does not call the property's setter | `breaking-changes.md` 4.7 (sourced) | Forbidden: relying on a setter for `arr[i] = v`; assign the whole array where the setter must run | Lint STATE-9 (same file); code review across files |
| Lambdas capture locals by value | `current-best-practices.md` (sourced) | `src/`: no lambdas (WIRE-3). `tests/`: a lambda that must change test state mutates a Dictionary, Array or object (the recording fake, `var box := {}`), never reassigns a local | Lint WIRE-3; code review in tests |
| A one-argument lambda on a zero-argument signal errors | `current-best-practices.md`, 4.6.1 (sourced observation) | Tests connect generic listeners as `func(...args)` | The recording fake (V3) |
| Signal parameter types are not checked at `emit()` | Expected, unsourced (ADR-0006 V1) | Required: every payload is checked by the recording fake against the declaration | Decision 4 |
| A method named like a global function shadows it (`load`, `seed`; a helper method `log` would shadow `log()`) | ADR-0001, ADR-0002 (precaution) | Forbidden: functions, parameters or variables named `load` or `seed` in `src/`; helpers use `entries()`, not `log()` | Lint NAME-5 |
| Typed arrays are invariant | `architecture.md` rule 5 | Required: lists that Combat takes are `Array[Targetable]` from creation | Parser; code review |
| A subclass `_init` must call `super(...)` when the base `_init` has required arguments | ADR-0005, ADR-0009 V7 | Required: `super(args)` first | Tests (the object fails to build) |
| Every `class_name` is global | `architecture.md` rule 6 | Decision 10 | Lint NAME-1 to NAME-4 |

### 12. What cannot run headless: the manual-evidence list

Each item is recorded by the story or verification run named, in `production/qa/evidence/<story-slug>/` (or `adr-NNNN-<item>/` for a pre-acceptance run), as a Markdown note (build, device, OS, engine version, steps, expected, observed, result) with its screenshots or logs beside it, following `.claude/docs/run-and-observe.md`. Captures use `--write-movie` or a capture node inside the evidence scene, never an autoload (PROJ-1).

| ID | Item | Source | Recorded by |
|---|---|---|---|
| M1 | InputAdapter and Control event order: a drag across a modal-free HUD ends in one `drag_ended` or `drag_cancelled`; a modal tap never reaches the resolver; letterbox taps reach nothing; a canceled touch never fires a tap | ADR-0003 SP items, Validation | ADR-0003 spike; first adapter and HUD stories |
| M2 | Lifecycle notifications: focus loss pauses on desktop and phone; a held finger or button never completes a gesture; after focus loss mid-walk and mid-telegraph the hero continues from the same point | ADR-0003, ADR-0004 Validation 8 | First pause story |
| M3 | `free()` against `queue_free()` timing on retry with a Control under the pointer | ADR-0001 V2 | First retry story |
| M4 | Safe-area values on a phone | ADR-0003 SP items | ADR-0003 spike; first phone build |
| M5 | Catalogue load from an Android export (W2); release build with one invalid record shows the generic fatal screen; load-time log; tuning loop | ADR-0002 W2, W4; Data & Config Acceptance 13 to 15 | First phone build |
| M6 | Fatal screen, development and release builds; load and instantiate failures (V3); `push_error` in a release export (V4) | ADR-0001 | Fatal-screen story; first Android export |
| M7 | Draw-call and frame-time budgets; whole-tick cost | ADR-0004 V6, ADR-0011, QQ-11 | First phone build (performance-analyst) |
| M8 | Displayed equals paid: tap Call as the digit changes, 20 times | ADR-0004 Validation 9 | First Call-early story |
| M9 | Cross-architecture digest (informational) | ADR-0004 V5 | First phone build |
| M10 | Pillar 4 phone test: zero mis-fires on two phones | ADR-0003, Input GDD | Input epic close |
| M11 | Lint seeded-file proof and the unasserted-`push_error` proof | Validation 3, 4 | Harness story |

Everything in `architecture.md` B0 to B2 and B4 to B9 runs headless, including the weakref test, as that section says.

### 13. Choices pending user confirmation

- **C1.** Orphan exit 101 fails the gate (a leaked node is a teardown defect). Alternative: treat 101 as a warning.
- **C2.** No lambda anywhere in `src/` (WIRE-3), not only for injected or connected callables, so `sort_custom` takes `obj.method` too. Alternative: allow lambdas that are neither stored nor connected, and lose the lint (that use is not crisp in text).
- **C3.** Every listener of a battle signal is named `on_<signal>` (Builder, ADR-0006) or `_on_<signal>` (wrapper subtree), WIRE-8. It is what lets WIRE-9 find listener bodies. Alternative: no naming rule, and WIRE-9 becomes code review.
- **C4.** TIME-3 applies to all of `src/` (views too), with three named exceptions, not only to sim code and real-time models. Views animate from the wrapper's frame clock (ADR-0004 Decision 8).
- **C5.** No `assert(` and no node `free()` anywhere in `src/` (ERR-1, ERR-4), one flat rule instead of "release-relevant" and "in the current call".
- **C6.** Track `export_presets.cfg` in git (remove it from `.gitignore`) once V7 shows it holds no secrets, so PROJ-6 and PROJ-7 run in CI.
- **C7.** A comparing test with no baseline for its architecture fails (`NOT ASSESSED`), on the developer's machine too, until a reviewed recording exists.

### Architecture Diagram

```
 developer or CI
   godot --headless --path . --import
   godot --headless -s ... GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
        │  exit 0 pass · 100 fail · 101 orphan (fails) · 105 parse · other NOT ASSESSED
        ▼
 tests/unit/<system>/       ── Logic: fakes, factories, recording fake, spy accessor; no file, scene or input
 tests/unit/lint/           ── lint self-tests: every rule, a seeded bad sample and a near miss (in memory)
 tests/integration/
   battle_wiring/           ── wiring_check(battle, contract) + W2 self-proof          (ADR-0006 contract)
   content/, data/          ── real catalogue, check_<rule>(catalogue) + broken fixtures (ADR-0002)
   lint/repo_lint_test.gd   ── reads src/, tests/, tools/, project.godot, export_presets.cfg
   hud/                     ── SCENE-1 Control filter test (first wrapper story)
        │ uses
        ▼
 tests/helpers/  (no class_name; preload by path)
   catalogue_factory · fakes · recording_fake · spy_stat_accessor · battle_probe
   battle_runner · baselines · wiring_check · combat_invariant
 tools/lint/     (no class_name)
   lint_rules (const tables) ─► lint_engine (pure check_source / check_project) ◄─ run_lint (SceneTree, local)
 project.godot [gdunit4] report/godot/push_error=true ─► any unasserted error fails the test
```

### Key Interfaces

```gdscript
# tests/helpers/catalogue_factory.gd   (extends RefCounted; no class_name)
static func minimal() -> Dictionary                              # smallest valid catalogue, file shape
static func catalogue(data: Dictionary, label: String) -> LoadResult   # Catalogue.from_data("fixture:" + label, data)

# tests/helpers/fakes.gd   (inner classes, each extends RefCounted)
class Halted:   var value := false;  func halted() -> bool
class InBuild:  var value := true;   func in_build() -> bool
class Fatal:    func fatal(cause: String) -> void;  func causes() -> PackedStringArray
class DevErrors: func report(msg: String) -> void;  func messages() -> PackedStringArray
class Targets:  var list: Array[Targetable] = [];   func targets() -> Array[Targetable]
class Canceller: func cancel() -> void;  func count() -> int

# tests/helpers/recording_fake.gd   (extends RefCounted)
var ANY: Object                                   # sentinel; matches any value of the declared type
func watch(sig: Signal) -> void
func watch_all(emitter: Object) -> void
func entries() -> Array[Dictionary]               # {signal: StringName, args: Array}, emit order
func type_errors() -> PackedStringArray
func expect(expected: Array) -> PackedStringArray  # [[name, [args]], ...]; empty = whole log matches

# tests/helpers/battle_probe.gd   (static only)
static func system(battle: Battle, key: StringName) -> Object
static func digest(battle: Battle) -> String
static func alive(refs: Array[WeakRef]) -> PackedStringArray

# tests/helpers/battle_runner.gd
static func run(battle: Battle, ticks: int, between: Callable) -> PackedStringArray   # one digest per tick

# tests/helpers/wiring_check.gd
static func check(battle: Battle, contract: GDScript) -> PackedStringArray

# tests/helpers/combat_invariant.gd
static func check(recorder: RefCounted, combat: Combat, created: Array[Targetable]) -> String

# tests/helpers/baselines.gd
static func arch() -> String                     # x86_64 | arm64 (ADR-0004 V4 names the call)
static func path(name: String) -> String         # res://tests/baselines/<arch>/<name>.json

# tools/lint/lint_engine.gd   (extends RefCounted; pure)
# Finding: {rule: StringName, path: String, line: int, message: String}
static func check_source(res_path: String, text: String, index: Dictionary) -> Array[Dictionary]
static func check_project(files: Dictionary) -> Array[Dictionary]   # {"project.godot": text, "export_presets.cfg": text or absent}
static func build_index(sources: Dictionary) -> Dictionary          # class_name -> path and layer, enums, battle signals
```

`index` carries the derived sets (Decision 8), built once per run from every scanned file, so `check_source` stays pure and the self-tests can pass a small hand-made index.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must run `godot --headless --path . --import` before the test command, every time; must retry the import once on exit 139.
- Must treat exit 101 as a failure, any unlisted exit as NOT ASSESSED, and `No test cases found` as not a pass.
- Must commit the regenerated `.godot/global_script_class_cache.cfg` with any change that adds or renames a `class_name`.
- Must never declare `class_name` in `tests/` or `tools/`; must preload helpers by path.
- Must build fixture catalogues with `CatalogueFactory` and `Catalogue.from_data`; unit tests must never use files, scenes, `scene_runner` or `simulate_*` input.
- Must use named, binary-exact fixture constants; never inline magic numbers outside boundary tests.
- Must record signals with the recording fake and compare whole, ordered logs with argument types; must never use `assert_signal` or `monitor_signals`.
- Must inject `Fakes` method Callables for `halted`, `in_build`, `fatal`, `dev_error`, `targets` and `cancel_input` in unit tests; must assert the fake's record, not a `push_error`.
- Must assert every expected `push_error` with `await assert_error(callable).is_push_error(CONSTANT)`, one per occurrence; must never leave one unasserted.
- Must never call `push_warning` in `src/`.
- Must keep `report/godot/push_error=true` and `report/godot/script_error=true` in `project.godot`.
- Must reach battle systems in tests through `Battle.emitters()`; must snapshot through read-only queries only.
- Must never write a baseline from a test; must record baselines with `tools/baseline/record_baselines.gd` in a reviewed change.
- Lambdas in tests that must change test state must mutate a Dictionary, Array or object, never reassign a captured local.
- Must name every listener of a battle signal `on_<signal>` (Builder) or `_on_<signal>` (wrapper subtree).
- Must add a lint rule's bad sample and near miss to `tests/unit/lint/` in the same change as the rule; must add an exception only as a `FILE_EXCEPTIONS` row citing its ADR; must never add an inline suppression.
- When an ADR adds or changes a lintable rule, must change `tools/lint/lint_rules.gd` in the same change.
- Must keep each new `src/` file inside one of the five layer folders, one `class_name` per file, named after the file.
- Manual evidence for M1 to M11 must land in `production/qa/evidence/` as Decision 12 states, never in `tests/`.

## Alternatives Considered

### Alternative 1: gdtoolkit (`gdlint`) for the lint
- **Description**: The Python `gdtoolkit` linter in a CI step, with custom checks written as plugins.
- **Pros**: A real GDScript parser; style rules for free.
- **Cons**: Its support for 4.5 to 4.7 syntax (variadic parameters, `@abstract`) is unsourced; it knows nothing of layers, engine class names or the signal contract; adds a Python toolchain to CI and to the developer's Mac; custom rules are a second codebase in a second language.
- **Estimated Effort**: Similar for the rules, more for the toolchain.
- **Rejection Reason**: The lint needs facts only the engine has (`ClassDB`, the contract script), and one toolchain is simpler for a solo developer.

### Alternative 2: `grep` rules in a shell CI step
- **Description**: One `grep -E` per rule over `src/`.
- **Pros**: Minutes to write.
- **Cons**: Cannot mask comments and strings, so doc comments trip it; cannot follow function bodies, layers or derived sets; differs between GNU and BSD grep; a muted noisy gate is worse than none.
- **Estimated Effort**: Lower at first, higher in false positives.
- **Rejection Reason**: Not crisp enough for most rules (skill-authoring obligation 5).

### Alternative 3: Rules as gdUnit4 tests only, with no `tools/` script
- **Description**: Put the matching code inside test suites.
- **Pros**: One fewer folder.
- **Cons**: No way to run the lint alone before a commit; the rule code is harder to self-test as a pure function; test suites would carry `class_name`-free shared code anyway.
- **Estimated Effort**: Similar.
- **Rejection Reason**: The chosen design keeps a pure engine with two thin callers, which gives both paths for little extra.

### Alternative 4: gdUnit4 `assert_signal` and `monitor_signals`
- **Description**: The framework's own signal assertions.
- **Pros**: No helper to write.
- **Cons**: Counts and awaits; no whole ordered log across emitters; no type check of payloads; TR-input-014 and the Input GDD reject it.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Cannot meet TR-input-014 or ADR-0006's payload rule.

### Alternative 5: Prefix every `class_name` (`TrBattle`, `TrFlow`)
- **Description**: A project prefix makes collisions impossible by convention.
- **Pros**: No collision lint needed for engine classes.
- **Cons**: Renames across nine ADRs, seven GDDs and the registry; longer names everywhere; still needs a duplicate check inside the project.
- **Estimated Effort**: Higher now, for a risk the lint catches at once.
- **Rejection Reason**: NAME-1 and NAME-2 detect the real collisions on every run, including after an engine upgrade.

### Alternative 6: File-based fixtures (`tests/fixtures/*.json`)
- **Description**: Small JSON files loaded by tests.
- **Pros**: Fixtures look like real data.
- **Cons**: File I/O in unit tests (TR-data-012 forbids it); fixtures drift apart from the factory edits each test needs.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Breaks TR-data-012; `Catalogue.from_data` already runs the same validator.

### Alternative 7: Leave `push_error` reporting off and count errors through `DevErrorSink` only
- **Description**: Every error goes through an injected sink that tests read; gdUnit4's setting stays at its default.
- **Pros**: No dependency on gdUnit4's `Logger` capture (V2).
- **Cons**: Engine errors (a double connect, a missing node) and Combat's direct `push_error` guards (ADR-0009 Decision 4) would pass unseen; contradicts TR-combat-012, which names the setting.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Kept only as the Rollback plan if V2 fails.

### Alternative 8: GUT instead of gdUnit4
- **Description**: Switch to the other common Godot test framework.
- **Pros**: Widely used.
- **Cons**: gdUnit4 is already vendored and wired into CI; the Combat GDD's criteria name gdUnit4's `assert_error`; GUT's 4.7 support is unsourced.
- **Estimated Effort**: Higher.
- **Rejection Reason**: No gain for the cost.

## Consequences

### Positive
- One command proves logic, wiring, error behaviour and architecture rules; a failure names file, line and rule.
- The layer map, the wiring rules and the ownership tables of seven ADRs become build failures, not review notes.
- Payload types are checked even though the engine does not check them at `emit()`.
- Engine errors and stray `push_error` calls fail tests instead of scrolling past.
- `class_name` collisions surface on the run that introduces them, including after an engine or addon upgrade.

### Negative
- A hand-written lexer in GDScript is code to maintain; its self-tests are the guard.
- The lint sees text, not types; the blind spots in Decision 8 stay on code review and tests.
- WIRE-8's naming rule and C2 to C5's flat bans are stricter than the ADRs that deferred them.
- Every test that fires the real relay must wrap the call in `assert_error`.
- Local runs on a new architecture fail until a baseline is recorded (C7).

### Neutral
- Test helpers have no global names; tests preload them by path.
- `tools/lint/` ships nothing: PROJ-7 keeps `tools/`, `tests/` and the addon out of exports.

## Risks

- **gdUnit4 6.2.0 misbehaves on 4.7.2 (V1).** Mitigation: upgrade to the newest 6.2.x in one change and rerun V1 and V2 before any story.
- **`push_error` capture does not work headless (V2).** Mitigation: Rollback plan (sink-only counting); ADR-0009's direct `push_error` exception is then reopened.
- **The CI action skips the import or reads exit codes differently (V5).** Mitigation: the zero-test step; replace the action with explicit steps.
- **The lint is noisy and gets muted.** Mitigation: masked comments and strings, near-miss self-tests, no inline suppressions, the ten-exception reopen trigger.
- **A rule silently stops matching** (a regex typo after a refactor). Mitigation: every rule's bad sample runs on every CI run; the end-to-end seeded proof (Validation 3) is rerun whenever `lint_engine.gd` changes.
- **The import crashes on exit (139).** Mitigation: one retry; the reference shows the files are written before the crash.
- **`export_presets.cfg` holds secrets (V7).** Mitigation: it stays ignored and PROJ-6, PROJ-7 run locally only, with ADR-0002 amended.
- **Nested prototype projects are imported into the main project (V6).** Mitigation: NAME-1 then scans `prototypes/` too, and PROJ-7 keeps them out of exports.
- **gdUnit4 refuses to load if the `inferred_declaration` warning is ever turned on** (`GdUnitSettings.validate_is_inferred_declaration_enabled`). Mitigation: exclude `res://addons/gdUnit4` in `debug/gdscript/warnings/directory_rules` in the same change.
- **`run-and-observe.md` suggests an autoload for capture-on-trigger.** Mitigation: Decision 12 forbids it here; PROJ-1 fails it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-012: logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files | Decision 3 (`CatalogueFactory`, `Catalogue.from_data`, `tests/integration/data/` and `content/`); lint TEST-2 |
| input-gesture-resolver.md | TR-input-014: identical call lists give identical signal logs; a recording fake, not `assert_signal`; bots call commands plus one resolver equivalence test | Decision 4 (one ordered, typed log; whole-log `expect`), lint TEST-1; Decision 5 (battle runner for bots; the equivalence test's script format is ADR-0010's) |
| game-state-stage-flow.md | TR-state-013: tests enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when any battle signal has no listener (views on an allowlist) | Decision 5 (`Battle.emitters()`, `digest`), Decision 4, Decision 6 (listener-count harness and W2 self-proof; contract in ADR-0006) |
| combat-damage.md | TR-combat-012: errors use `push_error`, asserted with `assert_error().is_push_error()` with the report setting on; invariant I checks damage sums | Decision 7 (PROJ-5 setting, one assertion per error, `combat_invariant.gd` with tamper tests), V2 |
| enemy-wave.md | TR-enemy-014: a headless content test checks layout rules L1 to L14 and wave rules on in-memory records; unit tests use fakes and no scene or files | Decision 3 (content suites on the loaded catalogue's records, broken fixtures; `Fakes`), lints TEST-2, TEST-3 |
| tower-system.md | TR-tower-014: all logic unit-testable headless with spy accessor, recording fake and fake `halted()`; the content test enforces tower and gold rows | Decision 3 (`SpyStatAccessor`, `Fakes.Halted`, content suites), Decision 4 |

Foundational as well: the lint (Decision 8 and 9) enforces `architecture.md` layer rules 1 to 6 and the rules ADR-0001 to ADR-0006 and ADR-0009 deferred, which constrains every GDD system's implementation.

## Performance Implications
- **CPU**: None at run time: `tests/`, `tools/` and the addon are excluded from exports (PROJ-7). In CI, the import plus the lint over an MVP-sized `src/` (expected under 200 files, about 60 rules) is expected to take seconds; unmeasured, the first CI run records it.
- **Memory**: None at run time.
- **Load Time**: None at run time.
- **Network**: None.

## Migration Plan

No game code exists. In order:

1. Before acceptance: V1 to V4, V6 and V7 in `prototypes/adr-0007-harness-check/`; V5 on a scratch branch; results into `current-best-practices.md`; cascade edits (tests README, `.gitignore` per C6 and V7, `architecture.md` QQ rows, the "provisional names" lines in ADR-0001 to ADR-0006 and ADR-0009).
2. First harness story (after ADR-0001's `FatalLatch` story): `[gdunit4]` settings in `project.godot`; `tools/lint/` with the rules whose targets can exist yet (LAYER, NAME, WIRE-1 to WIRE-5, WIRE-12, STATE-1, TIME, MATH, INPUT, ERR, TEST, PROJ) and their self-tests; `repo_lint_test.gd`; `catalogue_factory.gd` (once ADR-0002's `from_data` exists), `fakes.gd`, `recording_fake.gd`; the zero-test CI step; Validations 3 and 4.
3. Rules that need later code join with that code's story: WIRE-6 to WIRE-11 with ADR-0006's contract file; STATE-4 to STATE-8 with ADR-0009's first stories; STAT-1 with the accessor; SCENE-1 with the first wrapper story; `battle_probe`, `battle_runner`, `baselines` with the first two sims; `combat_invariant` with Combat.
4. Remove `tests/unit/.gdignore_placeholder` and `tests/integration/.gdignore_placeholder` when the first real file lands in each folder.

**Rollback plan**: If V2 shows gdUnit4 cannot capture `push_error` headless, turn the setting off, route every `src/` error report through `DevErrorSink` (tests read its record), and reopen ADR-0009 Decision 4's direct `push_error` exception; Decision 7 is amended. If the GDScript lexer proves too fragile, keep the rule table and self-tests and move only `lint_engine.gd` to another language, run as a CI step. If the action fails V5, replace it with explicit steps; nothing else changes.

## Validation Criteria

1. V1 to V7 recorded in `current-best-practices.md` before acceptance.
2. **Every lint rule watched failing.** `tests/unit/lint/lint_rules_test.gd` iterates the rule table: each rule's seeded bad sample yields exactly its finding on the expected line, and each near miss yields none. Each rule's test is written and run red before the rule is implemented.
3. **Seeded bad files, end to end.** With the lint green on the real repo, the harness story adds one seeded bad file at a time, runs the CI command, and confirms exit 100 with the finding named, then removes it and confirms exit 0. One mutation per run: (a) `src/core/_lint_probe.gd` referencing a `src/feature/` class (LAYER-1); (b) the same file holding a lambda passed to `connect` (WIRE-3); (c) an `[autoload]` section added to `project.godot` (PROJ-1); (d) a `class_name` added to a script in `tests/helpers/` (NAME-3). The four outputs are kept in `production/qa/evidence/adr-0007-lint-seeded/`. Repeated once on CI through one pull request that must go red. Rerun whenever `lint_engine.gd` changes.
4. **Unasserted `push_error` fails.** One seeded run of a test that calls `push_error` without asserting it exits 100; one with two identical pushes and one assertion exits 100; output kept beside Validation 3's. The positive case (one push, one assertion, exit 0) stays in CI.
5. The listener-count test passes on a fixture battle, and its W2 self-proof returns exactly the expected line on every run (ADR-0006 Validation 2).
6. The recording fake's own tests: a `String` emitted into a `StringName` parameter, a missing argument, an extra entry, a wrong order and an `ANY` match each give the expected result.
7. A fresh clone, import, then the CI command exits 0 on Linux CI and on the user's Mac; a run that finds no tests fails the CI job (the zero-test step).
8. NAME-1 to NAME-4 report no finding over the classes of Decision 10 once they exist (V6 checks them earlier as a list).
9. SCENE-1 passes after `attach`, and fails when one HUD label is set to `MOUSE_FILTER_STOP` (watched once, kept).

The decision is wrong if: the lint cannot be made quiet on correct code without more than ten exceptions; a defect class it targets ships past it; or gdUnit4 cannot report `push_error` headless on 4.7.2 even after an upgrade.

## Related

- Depends on ADR-0001 (fatal path, wiring mechanism, weakref proof) and ADR-0006 (signal contract, `emitters()`, listener-count tests; wiring rules bind `src/`, tests may connect, disconnect and call test seams).
- Enforces rules deferred by ADR-0002, ADR-0003, ADR-0004, ADR-0005 and ADR-0009 (Decision 9 lists each).
- Enables ADR-0008, ADR-0010, ADR-0011.
- `docs/architecture/architecture.md`: Dependency rules 1 to 6, "What cannot be tested headless", QQ-13, QQ-15, QQ-16 (resolved here when Accepted).
- `design/gdd/data-config-pipeline.md` (Rule 12, Acceptance Criteria preamble), `input-gesture-resolver.md` (Acceptance Criteria preamble), `game-state-stage-flow.md` (wiring test, deferred criteria), `combat-damage.md` (Acceptance Criteria preamble), `enemy-wave.md` (content test, Acceptance 58), `tower-system.md` (Acceptance Criteria preamble, 59).
- `.claude/docs/coding-standards.md` (CI command, test rules), `.claude/rules/test-standards.md`, `.claude/rules/skill-authoring.md` (obligations 1, 4, 5; a gate you have not watched fail).
- `addons/gdUnit4/` 6.2.0, `.github/workflows/tests.yml`, `tests/README.md` (rewritten per the cascade notes).
