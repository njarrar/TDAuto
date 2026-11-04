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
> **Before acceptance** (the one list; none of these needs a story):
> 1. ADR-0001 is Accepted.
> 2. V1 to V7 (Engine Compatibility) have recorded results, run as
>    `prototypes/adr-0007-harness-check/README.md` describes (a throwaway project, a throwaway
>    clone, and a scratch GitHub branch the user pushes), copied into
>    `docs/engine-reference/godot/current-best-practices.md`. Where a result takes a branch, this
>    ADR is revised to that branch first.
> 3. The user has confirmed or overturned each item in Decision 13, one by one, and **each
>    confirmed item is reflected in its owning ADR** by the conditional edit in the cascade notes.
>    MET for the user part: C1 to C7 and D1 to D3 confirmed by the user, 2026-11-04, as
>    recommended. Owner edits applied 2026-11-04: C2 (ADR-0001, ADR-0003, ADR-0009), C3
>    (ADR-0006), C4 (ADR-0004), C5 (ADR-0001). Still open: the C6 `.gitignore` edit, which
>    also waits for V7 to show no secrets (item 2).
> 4. The cascade edits that need no confirmation are applied: `tests/README.md`, `prototypes/.gdignore`,
>    the `architecture.md` QQ-13, QQ-15, QQ-16 rows, the "provisional names" lines in ADR-0001 to
>    ADR-0006, ADR-0008 and ADR-0009, and the ADR-0001 V1 and Risks fixes.
>
> Verification progress, 2026-11-04 (macOS arm64, headless, Godot 4.7.2 editor binary;
> `prototypes/adr-checks/`; `docs/engine-reference/godot/verification-results.md`): V3 and the
> headless parts of V6 are RECORDED and take no branch. Still open before acceptance: V1, V2,
> V4, V5, V7, and the V6 editor save and `.godot/` scan. Edits from this run: Decision 4 now
> says tests drop recording lambdas before weakref asserts (ADR-0001 V1 lambda-release), and
> `adr-0007-lint-rules.md` gains INIT-1 (ADR-0009 V7: the engine does not enforce `super(...)`).
>
> **Two-part activation.** Acceptance switches on everything except the ADR-0006-dependent parts.
> Decision 6 (listener-count harness) and the lint rules marked *pending ADR-0006* in
> `adr-0007-lint-rules.md` (WIRE-5 to WIRE-12) switch on when ADR-0006 is Accepted; rules marked
> *pending ADR-0008* switch on when ADR-0008 is. A pending rule prints `pending: <RULE> (<ADR>)` on
> every run, so it is never silent.
>
> **After acceptance** (stories): the first harness story builds `tools/lint/`, the shared helpers,
> the `[gdunit4]` project settings and the seeded-file proofs (Validation 3, 4). Reopen trigger: if
> a seeded file cannot make a rule fail, or the lint needs more than ten file exceptions by the end
> of MVP, this ADR is amended before the next story closes.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference and against the gdUnit4 6.2.0 source vendored in `addons/gdUnit4/` (read, not run; the engine check confirmed the cited lines). The live Godot and gdUnit4 documentation was not reachable from the authoring session, and no Godot binary exists in it, so every behaviour neither source covers is marked NEEDS VERIFICATION and listed in V1 to V7.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS on the first draft, T1 to T3 blocking and T4 to T9 advisory, all applied in this revision), godot-specialist (engine check: E1 and E2 blocking, minor notes, all applied). Authored with the /architecture-decision flow in autonomous mode; the parent session's choices D1 to D3 on the TD's questions are logged in Decision 13.

## Summary

Earlier ADRs defer more than forty checks to "ADR-0007's lint" or "the ADR-0007 harness", and TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014 and TR-tower-014 need one way to build fixtures, record signals with their payloads, catch `push_error` and prove wiring, all headless. This ADR decides gdUnit4 6.2.0 (vendored, pinned) run headless after a `--import`, shared helpers in `tests/helpers/` with no `class_name`, a recording fake that checks every payload against the declared signal types, gdUnit4's error and orphan reporting on so any unasserted error or leaked node fails, and one GDScript lint in `tools/lint/` (run as a gdUnit4 integration test, rules in the companion `adr-0007-lint-rules.md`, each scoped to its owning ADR and proven on a seeded bad file).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) with gdUnit4 6.2.0 (`addons/gdUnit4/plugin.cfg` line 6) |
| **Domain** | Core (scripting, test and CI tooling) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM (post-cutoff engine; the runner's command line and exit codes are in the pinned reference, error capture and the CI action are not) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 to 4.7 GDScript rows; `RegEx` `show_error`, 4.4), `deprecated-apis.md`, `current-best-practices.md` (GDScript 4.5, 4.7; Command Line: Tests and Parse Check). No `modules/` file covers scripting or testing. Read as a source of tool behaviour, line numbers confirmed by the engine check: gdUnit4 6.2.0 `GdUnitTestSessionRunner.gd` 19 to 24 (exit codes), `GdUnitTestCIRunner.gd` 107, 342, 380 to 395, 467 to 475 (fail-fast, `-c`, discovery, exit choice), `GdUnitSettings.gd` 28 to 31, 135 to 137, 291 (keys, defaults), `GodotGdErrorMonitor.gd` 47 to 49, `GdUnitGodotErrorAssertImpl.gd` 36 to 41, `GdUnitTestSuiteScanner.gd` 20, 21, 207 to 211 (skips); the class cache, `tests.yml`, `.gitignore`, `godot-parse-check.gd`. |
| **Post-Cutoff APIs Used** | Variadic parameters `...args: Array` (4.5, sourced) in the recording fake's lambda. Typed-return overrides need an explicit `return` (4.7, sourced). Packed-array element writes skip the setter (4.7, sourced). `uid://` paths in `preload` (4.4; LAYER-5 bans them in `src/`). Indirectly: gdUnit4 captures errors through `Logger`, `OS.add_logger` and `ScriptBacktrace` (4.5 engine API, read in the addon source; NOT SOURCEABLE in `docs/engine-reference/godot/**`). |
| **Verification Required** | V1 to V7 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: gdUnit4 6.2.0 (not 6.2.2) on 4.7.2; how the `Logger` callback reports `push_error`, warnings and engine errors headless; whether the gdUnit4 GitHub action imports first and which exit codes fail its job; `.tscn` and `export_presets.cfg` keys; whether nested `prototypes/*/project.godot` folders are imported; `ClassDB.class_exists` for this project's class names. |

> **Note**: Knowledge Risk is MEDIUM, so this ADR must be re-validated if the project upgrades
> the engine or gdUnit4. Flag it as "Superseded" and write a new ADR.

### Verification items

Owner of every item: godot-specialist writes the script or steps, the user runs them, godot-specialist records the result in `current-best-practices.md` and revises this ADR where a branch applies. Procedures and expected values: `prototypes/adr-0007-harness-check/README.md`. Expected results are unsourced unless marked.

- **V1. Exit ladder of gdUnit4 6.2.0 on 4.7.2** (the reference saw 6.2.2): 0, 100 (wins over 101), 101, 105, 0 with `No test cases found`, 103; fail-fast without `-c`; helpers not run as suites; a parse error in a preloaded helper. Mac on the throwaway project; the Linux leg on V5's scratch branch. *Branch*: upgrade to the newest 6.2.x and rerun V1, V2.
- **V2. Error capture headless**, setting on: unasserted `push_error` fails; one push, one assertion passes; two pushes, one assertion fails; setting off passes; engine errors and `push_warning` fail; a push through a method Callable is caught; (h) warnings raised by headless default-`Control` instantiation are recorded (they would fail SCENE-1). *Branch*: if an unasserted push passes, the Rollback plan.
- **V3. Recording-fake listener**: `func(...args)` on 0, 1 and 6 arguments; `&"a"` reads `TYPE_STRING_NAME`, `"a"` into a `StringName` parameter reads `TYPE_STRING`; declared types from `get_script_signal_list()`. Beside ADR-0006 V1, V2. *Branch*: one method per arity with `bind(name)` (legal in tests).
  - Result (2026-11-04, macOS arm64, headless): the variadic lambda sees 0, 1, 6 and 6 arguments and the raw emitted types (`&"a"` is StringName, `"a"` stays String); declared types read from the signal list. No branch; see docs/engine-reference/godot/verification-results.md.
- **V4. Import on a fresh clone**: a throwaway clone with one uncommitted passing suite, run without and then with import (exit 0 with one test run; `No test cases found` fails the check); ten imports, any exit above 128 recorded; a new `class_name` reaches the cache.
- **V5. CI action**: four scratch-branch pushes, one mutation each (fail, orphan, parse error, no suites): import step, logged exit, job colour, JUnit path and `tests=`. *Branch*: if it does not import or does not fail on 100, 101, 105, replace it with explicit steps; the zero-test step stays either way.
- **V6. Lint engine facts**: PCRE2 lookbehind with `show_error`; `DirAccess` headless; `ClassDB.class_exists` false for every name found by **scanning `class_name <Name>` in `docs/architecture/adr-*.md`** at run time (so ADR-0008's `GestureRecord`, `GestureLog` and ADR-0009's rollback `CombatTypes` are included) and true for `Node`, `Input`, `Engine`; the `[connection signal=` token; no `prototypes/` path under `.godot/` once `prototypes/.gdignore` exists. *Branch*: a colliding class is renamed and its ADR amended before acceptance.
  - Result (2026-11-04, macOS arm64, headless): headless parts pass: regex lookbehind, `DirAccess` headless, `ClassDB.class_exists` false for all 36 class names in the ADRs and true for Node, Input, Engine, and the `[connection signal=` token in a scene saved by `ResourceSaver`. No collision. The editor save and the `.godot/` scan are still open; see docs/engine-reference/godot/verification-results.md.
- **V7. Export preset file**: include and exclude filter keys; whether `tests/*` excludes `res://tests/`; whether keystore passwords land in `export_presets.cfg` (expected: in `.godot/export_credentials.cfg`). *Branch*: if they do, the file stays ignored, PROJ-6 and PROJ-7 run locally only, and ADR-0002 Validation 10 is amended.

Not relied on: gdUnit4's scene-runner input simulation (gdUnit4 warns input events are not transported headless), `assert_signal`, `monitor_signals`, any warning-as-error project setting, the text of engine errors.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed; must be Accepted: `BattleBuilder.build`, `FatalRelay` and its `push_error`, the `dev_error` sink, the weakref proof, the no-autoload and `obj.method` rules). ADR-0006 (Proposed; needed only for the second activation step: the signal table, `Battle.emitters()`, `battle_signal_contract.gd`, the listener-count tests, and its rule that wiring rules bind `src/` while tests may connect, disconnect and call test seams). |
| **Enables** | ADR-0008 (resolver tests use the recording fake and fakes by path; INPUT-9, INPUT-10), ADR-0010 (bot scripts through the battle runner; its commands extend WIRE-9), ADR-0011 (view and Control rules join the catalogue); every Logic and Integration story's test evidence. |
| **Blocks** | The first harness story; every story whose acceptance needs a recording fake, a fixture catalogue, the error setting or the lint, which is every Logic and Integration story of the MVP epics. |
| **Ordering Note** | The lint enforces registered stances of ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0008 and ADR-0009. A rule whose owning ADR is not Accepted is *pending* (off, printed). When an owning ADR changes a rule, its catalogue row changes in the same change. The harness story runs right after ADR-0001's `FatalLatch` story. ADR-0001 V1 runs before ADR-0001's acceptance as a standalone script; its kept test (ADR-0001 Validation 3b) uses this harness's `alive()` helper, which the first harness story builds. |

## Context

### Problem Statement

GDScript has no module boundaries, no access control and one global `class_name` namespace (`architecture.md` layer rule 6), so the layer map, the wiring rules and the ownership tables of ADR-0001 to ADR-0009 hold only if something checks them. Six requirements also fix how tests must work: code-built fixtures with no file I/O (TR-data-012), a recording fake instead of `assert_signal` (TR-input-014), enumerable battles with a listener-count test (TR-state-013), `push_error` asserted with the report setting on (TR-combat-012), content tests on in-memory records and no scenes in unit tests (TR-enemy-014), spy accessor and fake `halted()` (TR-tower-014). Every story's tests use this, so it is decided before the first story.

### Current State

- `addons/gdUnit4/` holds gdUnit4 **6.2.0**; its 202 global classes in the tracked cache match no `class_name` in the ADRs.
- `tests/` holds empty `unit/` and `integration/`, `smoke/` and a stale `README.md` (says gdUnit4 is missing; QQ-13).
- `tests.yml` runs `gdUnit4-action@v1`, `godot-version: '4.7.2'`, `version: 'installed'`, over `tests/unit` and `tests/integration`.
- `project.godot` has no `[gdunit4]` section: `push_error` reporting is off by default; `verbose_orphans` defaults on, and exit 101 depends on it (E1).
- `.gitignore` ignores `export_presets.cfg`, which ADR-0002 Validation 10 wants CI to read. `prototypes/` holds three nested projects and no `.gdignore`. `src/` has no code.

### Constraints

- Solo, part-time developer: one command runs everything, and a failing gate names the file, line and rule.
- No autoloads (ADR-0001): no harness singleton, and the lint checks `project.godot`.
- Unit tests do no file I/O, use no scene and are deterministic (coding standards, TR-data-012, TR-enemy-014).
- Skill-authoring rules: a gate must be watched failing; an absent input is never a pass; covered sets are derived where the category is crisp, and a kept list says why.
- A lint rule may not be stricter than the ADR that owns the rule unless the user confirms the tightening (Decision 13) and the owner is amended.

### Requirements

- Must build fixture catalogues in code through `Catalogue.from_data` (ADR-0002 Decision 9).
- Must record signals into one ordered log and compare whole logs, arguments and their types (TR-input-014, ADR-0006).
- Must let tests enumerate a battle's systems, snapshot it and run the listener-count test (TR-state-013).
- Must fail a test on any unasserted `push_error`, warning, engine error or leaked node, and assert expected errors by message (TR-combat-012).
- Must enforce mechanically where possible the layer rule and the rules earlier ADRs deferred, and name what stays on code review.
- Must list what cannot run headless and where its evidence goes.

## Decision

### 1. Framework, folders and names

1. **gdUnit4 6.2.0, vendored and pinned** in `addons/gdUnit4/`; CI uses it through `version: 'installed'`. An upgrade is its own reviewed change that reruns V1 and V2. No second framework.
2. **Folders.** `tests/unit/<system>/` (Logic), `tests/integration/<system>/` (multi-system, real data, the lint), `tests/helpers/` (shared helpers), `tests/baselines/<arch>/` (ADR-0004), `tests/integration/battle_wiring/` (ADR-0006), `tests/integration/content/` (ADR-0002), `tests/integration/lint/` and `tests/unit/lint/`. A helper used by one system may live in `tests/unit/<system>/helpers/` (the Input GDD's choice). `<system>` is the module folder under `src/`, or the GDD's name where it fixes one (`input_gesture_resolver`).
3. **Names** follow `.claude/rules/test-standards.md`: `<system>_<feature>_test.gd`, `test_<scenario>_<expected>()`, arrange/act/assert, suites `extends GdUnitTestSuite`.
4. **No `class_name` outside `src/`.** Helpers, fakes, lint scripts and suites declare none; tests preload by path (`const Fakes := preload("res://tests/helpers/fakes.gd")`). A test subclass of a game class extends it by name and is reached through its preload constant: `const FakeResolver := preload("res://tests/unit/input_gesture_resolver/helpers/fake_resolver.gd")`, then `FakeResolver.new(15.0, 28.0)`, exactly as ADR-0008 writes it. This keeps test names out of the global namespace and the export (NAME-3; gdUnit4's "create test" template adds a `class_name`, which NAME-3 catches).

### 2. Running the tests, locally and in CI (QQ-13)

```bash
godot --headless --path . --import          # every run; retry once on any exit above 128
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

- **Import every time.** The class cache is tracked but goes stale whenever a `class_name` is added or renamed, and nothing else under `.godot/` is tracked. The import is not a gate: it exits 0 on a parse error (pinned reference); the test run's 105 and the parse check are the gates. A change that adds or renames a `class_name` commits the regenerated `.godot/global_script_class_cache.cfg`.
- **Exit ladder** (pinned reference; agrees with the vendored source): 0 pass; 100 a test failed; **101 fails the gate** (every test passed but a node leaked, C1; needs `report/verbose_orphans=true`, PROJ-5); 103 headless refused; 104 engine too old; 105 a script does not parse during discovery; 1 before the first import; any other code is NOT ASSESSED. **0 with `No test cases found` is not a pass.**
- **CI** keeps the gdUnit4 action until V5 decides. A step after it fails the job when no JUnit report exists or its total `tests` is 0.
- `-c` (run on after a failure) is a local convenience only; CI keeps fail-fast.

### 3. Fixtures and fakes (TR-data-012, TR-tower-014, TR-enemy-014)

- **Catalogue fixtures.** `tests/helpers/catalogue_factory.gd`: `minimal()` returns the smallest valid catalogue dictionary in file shape (ADR-0002 Decision 9); tests copy and edit it and call `catalogue(data, label)`, which returns `Catalogue.from_data("fixture:" + label, data)`'s `LoadResult` unchanged, so the test asserts `ok` and the production validator runs. Fixture values are named constants, binary-exact (multiples of 1/4, sums below 2^20) as the Combat and Enemy & Wave GDDs require.
- **Real data** is read only by integration suites: `tests/integration/content/` (ADR-0002 Decision 8: `check_<rule>(catalogue)` on the loaded catalogue's in-memory records, each with a broken fixture) and `tests/integration/data/`.
- **Fakes for injected values** (`architecture.md` B9) are inner classes of `tests/helpers/fakes.gd`, used as `fake.method` exactly as the Builder injects: `Halted`, `InBuild`, `Fatal` (records causes; can set a `Halted`), `DevErrors`, `Targets`, `Canceller`. `to_ticks` is never faked: tests use a real `SimTime`.
- **Spy accessor**: `tests/helpers/spy_stat_accessor.gd`, as ADR-0005 Decision 9 states, reached as `const SpyStatAccessor := preload(...)`.
- **System factories** live with their system's tests and use the values their GDD's Acceptance Criteria preamble fixes.
- **No scene, no files, no engine input, no skips in unit tests** (TEST-2, TEST-3, TEST-5, TEST-6). Adapter tests call the adapter's handlers with constructed `InputEventScreenTouch` objects. gdUnit4 6.2.0 silently skips a test that declares an unknown parameter (`GdUnitTestSuiteScanner.gd` lines 207 to 211), so TEST-6 bans skip parameters and unknown test parameters.

### 4. The recording fake (TR-input-014, ADR-0006 payload rule)

`tests/helpers/recording_fake.gd`:

- `watch(sig: Signal)` connects one variadic lambda (`func(...args)`, V3) that appends `{signal, args}` to **one** ordered log shared by every watched signal; `watch_all(emitter)` watches every script signal of an emitter.
- **At record time it checks each payload against the declaration** from `get_script_signal_list()`: argument count, and `typeof(arg)` equal to the declared type (`TYPE_STRING_NAME` for IDs, `TYPE_INT` for enums and integer IDs). A declared `TYPE_NIL` or `TYPE_OBJECT` parameter is itself an error (ADR-0006: typed, object-free payloads). This turns "signal parameter types are not checked at `emit()`" (QQ-15) into a test failure.
- `expect(expected)` compares the **whole** log in order (`[[name, [args]], ...]`); `ANY` matches any value of the declared type; any type error, unlisted, missing or misordered entry is one line of the result; empty means pass. Floats compare exactly (deterministic sim, binary-exact fixtures).
- Method names avoid global functions: `entries()`, never `log()`.
- The lambda captures the fake, so the emitter keeps the fake alive while connected. The fake holds payload values only, never an emitter, so it never keeps a battle alive in a weakref test.
- A test drops its recording lambdas (disconnects them and clears every variable that holds one) before any weakref assert. ADR-0001 V1 (2026-11-04) saw a captured object stay alive after its lambda was dropped (lambda-release, still under a second look), so a weakref test must not rely on a lambda's release.
- `assert_signal` and `monitor_signals` are not used (TEST-1).

### 5. Battle probes: enumerate, snapshot, run (TR-state-013, ADR-0004 Validation 6)

- **Enumerate** through `Battle.emitters()` and `EMITTER_KEYS` (ADR-0006): `battle_probe.gd` `system(battle, key)`. No new `Battle` API.
- **Snapshot**: `battle_probe.gd` `digest(battle) -> String`, `JSON.stringify` with sorted keys and full precision (ADR-0002's `snapshot()` form) of read-only queries only (phase, lives, gold, `ticks_run()`, then each system's queries as its ADR adds them). A digest never reads a private field.
- **Run**: `battle_runner.gd` `run(battle, ticks, between: Callable)` calls `between(i)` (the command script; ADR-0010 fixes the format), then `battle.tick(battle.sim_time.dt)`, and records `digest` per tick.
- **Baselines**: `baselines.gd` names `res://tests/baselines/<arch>/<name>.json` (ADR-0004 V4 names the architecture call). A comparing test with no baseline for its architecture **fails** with `NOT ASSESSED: no baseline for <arch>` (C7). Baselines are written only by `tools/baseline/record_baselines.gd` in a reviewed change (TEST-4).
- **Weakrefs**: `battle_probe.gd` `alive(refs: Array[WeakRef]) -> PackedStringArray` names each ref that still resolves. It is built in the first harness story, because ADR-0001 Validation 3 and 3b need it before any sim exists.

### 6. The listener-count harness (TR-state-013; contract owned by ADR-0006; active once ADR-0006 is Accepted)

`tests/helpers/wiring_check.gd` `check(battle, contract: GDScript) -> PackedStringArray` runs ADR-0006 Decision 8's five checks and returns one line per failure, naming emitter, signal and listener. `tests/integration/battle_wiring/battle_wiring_test.gd` builds a battle on `CatalogueFactory.minimal()` with `Fakes.Fatal` as `fatal_handler`, asserts `check` is empty and the emitter count is non-zero, then disconnects W2 (tests may, ADR-0006 Decision 2) and asserts `check` returns exactly `enemy_wave.enemy_killed: missing tower_sim.on_enemy_killed`. The self-proof runs on every CI run; its first output is kept in `production/qa/evidence/adr-0006-listener-self-proof/`.

### 7. Errors: `push_error`, warnings, engine errors, `dev_error` (TR-combat-012)

1. `project.godot` sets, under `[gdunit4]`, `report/godot/push_error=true`, `report/godot/script_error=true` and `report/verbose_orphans=true` (PROJ-5). Then gdUnit4 reports every `push_error`, `push_warning`, engine error and script error logged during a test as a failure (`GodotGdErrorMonitor.gd`, V2), and leaked nodes give exit 101.
2. An **expected** error is asserted with `await assert_error(callable).is_push_error(MESSAGE)` against the emitting code's constant (Combat's `ERR_*`, the relay's cause). Each assertion consumes the first matching entry (`GdUnitGodotErrorAssertImpl.gd` lines 36 to 41), and a leftover fails the test. Each asserted callable must push its error **once**: a callable that pushes the same message twice cannot be asserted twice without running it again.
3. **Engine errors are never asserted by text**: they arrive as generic error entries; a test that expects one is redesigned to avoid it.
4. **Unit tests inject fakes** for `fatal` and `dev_error` and assert the fake's record. **Builder-level tests** use the real `FatalRelay`, which calls `push_error(cause)` (ADR-0001 Decision 3), and wrap the triggering call in `assert_error(...).is_push_error(cause)`.
5. `src/` never calls `push_warning` (ERR-3): with the setting on, it fails tests, and ADR-0001 has no warning tier.
6. **Combat's invariant I**: `tests/helpers/combat_invariant.gd` `check(recorder, combat, created) -> String` (empty when the three sums agree exactly, in creation order), called in Combat suites' `after_test()`, with kept negative tests that tamper with HP, a counter and the log one at a time (Combat GDD).
7. The proof that an **unasserted** error fails cannot stay in CI as a test that must fail: it is V2 (a), (d) before acceptance and Validation 4 after, kept as evidence; PROJ-5 keeps the setting on.

### 8. The lint: one GDScript tool, run as a test

- **Files.** `tools/lint/lint_rules.gd` (rule table, scopes, kept sets, `FILE_EXCEPTIONS`, all `const`, mirroring `adr-0007-lint-rules.md`), `tools/lint/lint_engine.gd` (pure: `build_index`, `check_source`, `check_project`; no file access), `tools/lint/run_lint.gd` (`extends SceneTree`; walks the repo, prints findings, `quit(1)` on any, `quit(0)` otherwise, the pattern of `godot-parse-check.gd`). None declares `class_name`.
- **CI path.** `tests/integration/lint/repo_lint_test.gd` reads every `.gd` and `.tscn` under `res://src/`, `res://tests/` (TEST and NAME rules) and `res://tools/` (NAME rules), plus `project.godot` and `export_presets.cfg`; fails listing each finding as `<res path>:<line>: <RULE> <message>`; prints files scanned and in-scope file counts per rule, `not assessed` for named-file rules whose file is absent, and `pending` rules; **fails when it scanned no `.gd` under `src/`**; and fails when the rule IDs in `lint_rules.gd` differ from those in `adr-0007-lint-rules.md`. The lint therefore runs inside the existing CI command. Locally: `godot --headless --path . -s res://tools/lint/run_lint.gd`.
- **Self-tests.** `tests/unit/lint/lint_rules_test.gd` iterates the rule table and feeds in-memory sources with fake paths to `check_source`: each active rule needs a seeded bad sample yielding exactly its finding, and a near miss yielding none, plus the lexer cases the catalogue lists. A rule with no bad sample fails the suite.
- **Scope rule.** Each lint rule takes its owning ADR's scope (Decision 13 D1). A rule stricter than its owner exists only as a confirmed Decision 13 item whose owner ADR is amended; otherwise the catalogue's bracketed owner scope applies. This also protects the ten-exception budget.
- **No inline suppressions.** Exceptions are `FILE_EXCEPTIONS` rows naming the rule, the file and the ADR decision allowing it.
- **Derived and kept sets**, the lexer, every rule with its source, and the known blind spots are in **`docs/architecture/adr-0007-lint-rules.md`**, which changes only through this ADR's review. Categories: LAYER (5 rules, including LAYER-5 `uid://` ban, engine check E2), NAME (5), WIRE (12, of which 8 pending ADR-0006), STATE and STAT (11), TIME and MATH (10), INPUT (9, of which 2 pending ADR-0008), ERR (4), TEST (6), PROJ (7).

### 9. Rules checked by tests or code review, not the lint

The lint rows are in the companion catalogue. These deferred rules are left to other mechanisms, with the reason.

| Deferred by | Rule | Mechanism |
|---|---|---|
| ADR-0001 | Builder and wrapper are wiring only (no gameplay `if`) | **Code review**: "a gameplay field" is not crisp in text (replaces ADR-0001 Risks' lint wording; cascade) |
| ADR-0001 | Session-lived objects hold no per-battle callable | **Code review** plus the retry weakref test after a bad accessor call |
| ADR-0001 | `is_valid()` before a held Callable on the fatal path | **Code review** plus ADR-0001 Validation 4 to 6, 11 |
| ADR-0001 | No `RefCounted` cycle | Weakref tests (ADR-0001 Validation 3, 3a) with `alive()` |
| ADR-0001 | Every wrapper node holding a sim implements `detach()` | Wrapper test (ADR-0006 Decision 8) plus the 3a weakref test |
| ADR-0001 | `print_debug` carries no error report; `assert` only for non-release checks (unless C5) | **Code review** |
| ADR-0001, ADR-0005 | Typed-return override needs `return` (4.7) | The parser: exit 105, parse check |
| ADR-0002 | No record field written outside `src/foundation/data/`; IDs, not object references | **Code review** plus the read-only snapshot test |
| ADR-0002 | Data read with `FileAccess`/`JSON`, never `ResourceLoader` | **Code review** plus the Android export check (W2) |
| ADR-0003 | Non-modal battle Controls `MOUSE_FILTER_IGNORE`, all `FOCUS_NONE` | **SCENE-1** below; not a lint, because Controls built in code and inherited defaults are invisible in `.tscn` text |
| ADR-0003 | Modal screens read events in `_gui_input` | **Code review**; SCENE-1 proves other Controls ignore input |
| ADR-0003 | Canceled touch is `cancel_pointer`, never `release` | Adapter unit tests (ADR-0003 Validation) |
| ADR-0004 | No order from `Dictionary` iteration, instance IDs or hashes | **Determinism test** (Decision 5); MATH-5 withdrawn as not crisp |
| ADR-0004 | No command inside a tick at run time | ADR-0004's `between_ticks()` development check (lint WIRE-9 covers listeners) |
| ADR-0004 | Determinism against `tests/baselines/<arch>/` | Battle runner and baselines (Decision 5) |
| ADR-0005 | No cached stat value | **Spy tests** per consumer plus code review |
| ADR-0006 | No sim listens to a view signal; non-emitters declare no signal | Listener-count test steps 4, 5 |
| ADR-0006 | No outcome depends on listener order; no re-emit inside own listener | **Code review** plus ADR-0006 Validation 4 |
| ADR-0008 | No `Vector2` operator in `input_resolver.gd` | **Code review** (methods are INPUT-10) |
| ADR-0009 | `roster()`/`targets()` kept in a variable and mutated | ADR-0009's roster snapshot test |

**SCENE-1** (`tests/integration/hud/battle_controls_test.gd`, written by the first `BattleWrapper` story with ADR-0006's wrapper test): after `attach` on a fixture battle, every `Control` in the wrapper subtree has `mouse_filter == Control.MOUSE_FILTER_IGNORE` and `focus_mode == Control.FOCUS_NONE`, except each modal screen root (`MOUSE_FILTER_STOP`) named in the test's `MODAL_ROOTS`. Engine warnings raised by headless Control instantiation would fail it (V2 h records them).

### 10. `class_name` policy (QQ-16)

No prefix. The names the ADRs fix stand unless a check finds a collision. The check is derived, not listed: before acceptance, V6 scans `class_name <Name>` in `docs/architecture/adr-*.md` and asks `ClassDB.class_exists` for each; after acceptance, NAME-1 to NAME-4 scan the real scripts on every run (duplicates across `src/`, `tests/`, `tools/`, `addons/`; engine classes plus the catalogue's static Variant-type list, since `ClassDB` does not report Variant types; none outside `src/`; name equals the PascalCase of the file). An engine upgrade or new addon that adds a clashing class fails the build at once, naming both sides, and the fix is one rename.

### 11. GDScript 4.7 pitfalls for the control manifest (QQ-15)

| Pitfall | Source | Rule | Enforced by |
|---|---|---|---|
| An override of a typed method inherits its return type and needs an explicit `return` on every path | `breaking-changes.md` 4.7 (sourced) | Required: every override of a typed method, test spies included, returns a value of that type on every path; never `return null` from `-> int` | Parser (exit 105; parse check) |
| Writing one element of a packed array does not call the property's setter | `breaking-changes.md` 4.7 (sourced) | Forbidden: relying on a setter for `arr[i] = v`; assign the whole array where the setter must run | Lint STATE-9 (same file); code review |
| Lambdas capture locals by value | `current-best-practices.md` (sourced) | `tests/`: a lambda that changes test state mutates a Dictionary, Array or object, never reassigns a captured local | Code review; `src/` per C2 or ADR-0001 |
| A one-argument lambda on a zero-argument signal errors | `current-best-practices.md`, 4.6.1 (sourced observation) | Tests connect generic listeners as `func(...args)` | The recording fake (V3) |
| Signal parameter types are not checked at `emit()` | Expected, unsourced (ADR-0006 V1) | Required: every payload is checked by the recording fake against the declaration | Decision 4 |
| A name like a global function shadows it (`load`, `seed`; a helper `log` would shadow `log()`) | ADR-0001, ADR-0002 (precaution) | Forbidden: `load` or `seed` as a function, parameter or variable name in `src/`; helpers use `entries()` | Lint NAME-5 |
| `uid://` paths hide what a script depends on | Engine check E2 (4.4 feature) | Forbidden: `uid://` in `src/*.gd`; use `res://` paths | Lint LAYER-5 |
| Typed arrays are invariant | `architecture.md` rule 5 | Required: lists Combat takes are `Array[Targetable]` from creation | Parser; code review |
| A subclass `_init` must call `super(...)` when the base `_init` has required arguments | ADR-0005, ADR-0009 V7 | Required: `super(args)` first | Tests (the object fails to build) |
| gdUnit4 skips a test with an unknown parameter, silently | `GdUnitTestSuiteScanner.gd` (read) | Forbidden: skip parameters and unknown test parameters | Lint TEST-6 |
| Every `class_name` is global | `architecture.md` rule 6 | Decision 10 | Lint NAME-1 to NAME-4 |

### 12. What cannot run headless: the manual-evidence list

Each item is recorded by the story or run named, in `production/qa/evidence/<story-slug>/` (or `adr-NNNN-<item>/` for a pre-acceptance run), as a Markdown note (build, device, OS, engine version, steps, expected, observed, result) with screenshots or logs beside it, per `.claude/docs/run-and-observe.md`. Captures use `--write-movie` or a capture node inside the evidence scene, never an autoload (PROJ-1).

| ID | Item | Source | Recorded by |
|---|---|---|---|
| M1 | InputAdapter and Control event order: a drag across a modal-free HUD ends in one `drag_ended` or `drag_cancelled`; a modal tap never reaches the resolver; letterbox taps reach nothing; a canceled touch never fires a tap | ADR-0003 | ADR-0003 spike; first adapter and HUD stories |
| M2 | Lifecycle: focus loss pauses on desktop and phone; a held finger never completes a gesture; after focus loss mid-walk or mid-telegraph the hero continues from the same point | ADR-0003, ADR-0004 Validation 8 | First pause story |
| M3 | `free()` against `queue_free()` timing on retry with a Control under the pointer | ADR-0001 V2 | First retry story |
| M4 | Safe-area values on a phone | ADR-0003 | ADR-0003 spike; first phone build |
| M5 | Catalogue load from an Android export (W2); release build with one invalid record shows the generic fatal screen; load-time log; tuning loop | ADR-0002; Data & Config Acceptance 13 to 15 | First phone build |
| M6 | Fatal screen in development and release builds; load and instantiate failures (V3); `push_error` in a release export (V4) | ADR-0001 | Fatal-screen story; first Android export |
| M7 | Draw-call and frame-time budgets; whole-tick cost | ADR-0004 V6, ADR-0011, QQ-11 | First phone build |
| M8 | Displayed equals paid: tap Call as the digit changes, 20 times | ADR-0004 Validation 9 | First Call-early story |
| M9 | Cross-architecture digest (informational) | ADR-0004 V5 | First phone build |
| M10 | Pillar 4 phone test: zero mis-fires on two phones | ADR-0003, Input GDD | Input epic close |
| M11 | Lint seeded-file proof and the unasserted-error proof | Validation 3, 4 | Harness story |

Everything in `architecture.md` B0 to B2 and B4 to B9 runs headless, including the weakref test, as that section says.

### 13. Choices pending user confirmation, and autonomous choices logged

Pending (if confirmed, the owning ADR is amended by the conditional cascade edit; if overturned, the lint takes the owner's bracketed scope in the catalogue):

| Item | Choice | Owner and its scope |
|---|---|---|
| C1 | Exit 101 (orphan nodes) fails the gate | This ADR; alternative: a warning |
| C2 | No lambda anywhere in `src/` (WIRE-3) | ADR-0001: injected or connected callables (ADR-0003 and ADR-0009 already paraphrase it as flat) |
| C3 | Battle-signal listeners named `on_<signal>` (Builder) or `_on_<signal>` (wrapper subtree), WIRE-8, so WIRE-9 can find bodies | ADR-0006 names Builder listeners only; alternative: WIRE-9 becomes code review |
| C4 | TIME-3 over all `src/`, with file exceptions (ADR-0008's `GestureLog` under `src/presentation/dev/` among them) | ADR-0004: sim code and real-time models |
| C5 | No `assert(` and no `free()` on any object in `src/` (ERR-1, ERR-4) | ADR-0001: release-relevant checks; nodes in the current call |
| C6 | Track `export_presets.cfg` once V7 shows no secrets | ADR-0002 Validation 10 assumed CI can read it |
| C7 | A comparing test with no baseline for its architecture fails, locally too | ADR-0004 Decision 9 ("NOT ASSESSED, never a pass") |

Autonomous choices by the parent session (logged; the user may overturn them):

- **D1.** Rules stricter than their owners without a C-item are narrowed to the owner's scope: WIRE-1 bans only `Callable(` with arguments (ADR-0008's `chip_open: Callable = Callable()` passes); WIRE-4 only where callables are connected or injected; WIRE-5, WIRE-7, WIRE-10, WIRE-12 battle signals and emitters only; INPUT-4, INPUT-5, INPUT-7 battle code only; STATE-2 the sim scope; INPUT-3, INPUT-8 pointer polling and safe-area reads only. INPUT-2, ERR-2 and MATH-5 withdrawn to review or tests. C2, C4, C5 stay, each with an owner edit.
- **D2.** Acceptance needs only ADR-0001 Accepted (plus V items and C-items); the ADR-0006-dependent parts activate with ADR-0006.
- **D3.** Size: rule catalogue to `adr-0007-lint-rules.md`, V procedures to the prototype README, Decision 9 cut to non-lint rows, Decision 10's name list replaced by a derived scan.

C1 to C7 and D1 to D3: each confirmed by the user, 2026-11-04, as recommended (the choice as written above). The owner amendments for C2 to C5 are applied; C1 and C7 need no edit elsewhere; C6's `.gitignore` edit waits for V7.

### Architecture Diagram

```
 developer or CI
   godot --headless --path . --import            (retry once on exit > 128; not a gate)
   godot --headless -s ... GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
        │  0 pass · 100 fail · 101 orphan (fails) · 105 parse · other NOT ASSESSED · 0 tests fails
        ▼
 tests/unit/<system>/       Logic: fakes, factories, recording fake, spy accessor; no file, scene, input or skip
 tests/unit/lint/           lint self-tests: every active rule, seeded bad sample and near miss (in memory)
 tests/integration/
   battle_wiring/           wiring_check + W2 self-proof            (active with ADR-0006)
   content/, data/          real catalogue; check_<rule>(catalogue) + broken fixtures (ADR-0002)
   lint/repo_lint_test.gd   src/, tests/, tools/, project.godot, export_presets.cfg; rule IDs = catalogue
   hud/                     SCENE-1 Control filter test (first wrapper story)
        │ uses
        ▼
 tests/helpers/ (no class_name; preload by path)
   catalogue_factory · fakes · recording_fake · spy_stat_accessor · battle_probe (alive first)
   battle_runner · baselines · wiring_check · combat_invariant
 tools/lint/ (no class_name)
   lint_rules (const; mirrors adr-0007-lint-rules.md) ─► lint_engine (pure) ◄─ run_lint (SceneTree, local)
 project.godot [gdunit4] push_error, script_error, verbose_orphans = true
```

### Key Interfaces

```gdscript
# tests/helpers/catalogue_factory.gd   (extends RefCounted; no class_name)
static func minimal() -> Dictionary
static func catalogue(data: Dictionary, label: String) -> LoadResult    # Catalogue.from_data("fixture:" + label, data)

# tests/helpers/fakes.gd   (inner classes, each extends RefCounted)
class Halted:    var value := false;  func halted() -> bool
class InBuild:   var value := true;   func in_build() -> bool
class Fatal:     func fatal(cause: String) -> void;  func causes() -> PackedStringArray
class DevErrors: func report(msg: String) -> void;   func messages() -> PackedStringArray
class Targets:   var list: Array[Targetable] = [];   func targets() -> Array[Targetable]
class Canceller: func cancel() -> void;  func count() -> int

# tests/helpers/recording_fake.gd   (extends RefCounted)
var ANY: Object                                    # sentinel: any value of the declared type
func watch(sig: Signal) -> void
func watch_all(emitter: Object) -> void
func entries() -> Array[Dictionary]                # {signal: StringName, args: Array}, emit order
func type_errors() -> PackedStringArray
func expect(expected: Array) -> PackedStringArray  # empty = the whole log matches

# tests/helpers/battle_probe.gd   (static only)
static func alive(refs: Array[WeakRef]) -> PackedStringArray     # first harness story
static func system(battle: Battle, key: StringName) -> Object
static func digest(battle: Battle) -> String

# tests/helpers/battle_runner.gd
static func run(battle: Battle, ticks: int, between: Callable) -> PackedStringArray

# tests/helpers/wiring_check.gd   (active with ADR-0006)
static func check(battle: Battle, contract: GDScript) -> PackedStringArray

# tests/helpers/combat_invariant.gd
static func check(recorder: RefCounted, combat: Combat, created: Array[Targetable]) -> String

# tests/helpers/baselines.gd
static func arch() -> String
static func path(name: String) -> String           # res://tests/baselines/<arch>/<name>.json

# tools/lint/lint_engine.gd   (extends RefCounted; pure)
# Finding: {rule: StringName, path: String, line: int, message: String}
static func build_index(sources: Dictionary) -> Dictionary   # class map, layers, enums, battle signals
static func check_source(res_path: String, text: String, index: Dictionary) -> Array[Dictionary]
static func check_project(files: Dictionary) -> Array[Dictionary]   # project.godot, export_presets.cfg if present
```

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must run `godot --headless --path . --import` before the test command, every time; must retry the import once on any exit above 128; must never treat the import as a parse gate.
- Must treat exit 101 as a failure (C1), any unlisted exit as NOT ASSESSED, and `No test cases found` as not a pass.
- Must keep `report/godot/push_error=true`, `report/godot/script_error=true` and `report/verbose_orphans=true` under `[gdunit4]` in `project.godot`.
- Must commit the regenerated `.godot/global_script_class_cache.cfg` with any change that adds or renames a `class_name`.
- Must never declare `class_name` in `tests/` or `tools/`; must preload helpers and test subclasses by path.
- Must build fixture catalogues with `CatalogueFactory` and `Catalogue.from_data`; unit tests must never use files, scenes, `scene_runner` or `simulate_*` input.
- Must use named, binary-exact fixture constants; never inline magic numbers outside boundary tests.
- Must never skip a test: no `do_skip` or `skip_reason`, and no test parameter gdUnit4 does not know.
- Must record signals with the recording fake and compare whole, ordered logs with argument types; must never use `assert_signal` or `monitor_signals`.
- Must inject `Fakes` method Callables for injected values in unit tests and assert the fake's record.
- Must assert each expected `push_error` with `await assert_error(callable).is_push_error(CONSTANT)`, with a callable that pushes it once; must never leave one unasserted; must never assert engine-error text.
- Must never call `push_warning` in `src/`.
- Must reach battle systems in tests through `Battle.emitters()`; must snapshot through read-only queries only.
- Must never write a baseline from a test.
- Lambdas in tests that change test state must mutate a Dictionary, Array or object.
- Must never use a `uid://` path in `src/*.gd`.
- Must add each lint rule to `adr-0007-lint-rules.md` (through this ADR's review), `lint_rules.gd` and a bad sample plus near miss in `tests/unit/lint/` in one change; must give a rule its owning ADR's scope unless a confirmed Decision 13 item widens it; must add an exception only as a `FILE_EXCEPTIONS` row citing its ADR; must never add an inline suppression.
- When an ADR adds or changes a lintable rule, must change its catalogue row and `lint_rules.gd` in the same change.
- Must keep each `src/` file inside one of the five layer folders, one `class_name` per file, named after the file.
- Manual evidence for M1 to M11 must land in `production/qa/evidence/`, never in `tests/`.

## Alternatives Considered

Each alternative below was weighed against the chosen design; effort is relative to it.

### Alternative 1: gdtoolkit (`gdlint`) for the lint
- **Description**: The Python linter in a CI step, custom checks as plugins.
- **Pros**: A real GDScript parser.
- **Cons**: 4.5 to 4.7 syntax support unsourced; no access to `ClassDB` or the signal contract; a second toolchain on CI and the Mac.
- **Estimated Effort**: Similar, plus the toolchain.
- **Rejection Reason**: The lint needs facts only the engine has.

### Alternative 2: `grep` rules in a shell CI step
- **Description**: One `grep -E` per rule.
- **Pros**: Minutes to write.
- **Cons**: Cannot mask comments and strings, follow bodies or derive sets; noisy gates get muted.
- **Estimated Effort**: Lower at first, higher in false positives.
- **Rejection Reason**: Not crisp enough (skill-authoring obligation 5).

### Alternative 3: Rules as gdUnit4 tests only, no `tools/` script
- **Description**: Matching code inside suites.
- **Pros**: One fewer folder.
- **Cons**: No standalone run before a commit; rule code harder to test as a pure function.
- **Estimated Effort**: Similar.
- **Rejection Reason**: A pure engine with two thin callers gives both.

### Alternative 4: gdUnit4 `assert_signal` and `monitor_signals`
- **Description**: The framework's signal assertions.
- **Pros**: Nothing to write.
- **Cons**: Counts and awaits; no ordered log across emitters; no type check.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Fails TR-input-014 and ADR-0006's payload rule.

### Alternative 5: Prefix every `class_name`
- **Description**: `TrBattle`, `TrFlow` and so on.
- **Pros**: No engine-collision check.
- **Cons**: Renames across nine ADRs, seven GDDs and the registry; still needs a duplicate check.
- **Estimated Effort**: Higher.
- **Rejection Reason**: The derived check finds real collisions on every run.

### Alternative 6: File-based fixtures
- **Description**: JSON files under `tests/fixtures/`.
- **Pros**: Look like real data.
- **Cons**: File I/O in unit tests (TR-data-012); drift from per-test edits.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Breaks TR-data-012.

### Alternative 7: Reporting off; count errors through `DevErrorSink` only
- **Description**: Tests read an injected sink.
- **Pros**: No dependency on gdUnit4's `Logger` capture.
- **Cons**: Engine errors and Combat's direct `push_error` pass unseen; contradicts TR-combat-012.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Kept as the Rollback plan only.

### Alternative 8: GUT instead of gdUnit4
- **Description**: The other common framework.
- **Pros**: Widely used.
- **Cons**: gdUnit4 is vendored and in CI; the Combat GDD names `assert_error`; GUT on 4.7 unsourced.
- **Estimated Effort**: Higher.
- **Rejection Reason**: No gain.

## Consequences

### Positive
- One command proves logic, wiring, error behaviour, teardown and architecture rules; a failure names file, line and rule.
- The layer map, the wiring rules and the ownership tables become build failures, not review notes, each within its owner's scope.
- Payload types are checked even though `emit()` does not check them.
- Stray errors, warnings, engine errors, leaked nodes and silently skipped tests fail.
- `class_name` collisions surface on the run that introduces them.

### Negative
- A hand-written lexer in GDScript is code to maintain; its self-tests are the guard.
- The lint sees text, not types; the blind spots stay on tests and code review.
- Every test that fires the real relay wraps the call in `assert_error`.
- Local runs on a new architecture fail until a baseline is recorded (C7).
- The rule catalogue is a second document that must stay in step with `lint_rules.gd` (the ID check enforces it).

### Neutral
- Test helpers have no global names; tests preload them by path.
- `tools/`, `tests/` and the addon ship nothing (PROJ-7).
- **For the producer:** acceptance needs only ADR-0001 (D2), so the harness story does not wait on the ADR-0003 phone spike that ADR-0004 and ADR-0006 depend on; the listener-count harness and the WIRE rules switch on later, when ADR-0006 is Accepted.

## Risks

- **gdUnit4 6.2.0 misbehaves on 4.7.2 (V1)**: upgrade to the newest 6.2.x, rerun V1 and V2. **Capture fails headless (V2)**: Rollback plan; ADR-0009's direct `push_error` exception reopens. **The action misreads exits (V5)**: zero-test step; explicit steps.
- **The lint is noisy and gets muted**: owner scopes (D1), masking, near-miss tests, no inline suppressions, the ten-exception trigger. **A rule silently stops matching**: bad samples run on every CI run; Validation 3 reruns when `lint_engine.gd` changes.
- **The import crashes on exit**: one retry on any exit above 128; the files are written before the crash (reference).
- **`assert_error` adds an OS logger per call and never removes it; its entry list is not thread-safe** (engine check): tests stay single-threaded; if suites slow, record it and upgrade gdUnit4.
- **A signal fires after its recording fake is freed**: the late emit errors and fails the test, which is the wanted signal.
- **`export_presets.cfg` holds secrets (V7)** or **nested prototypes are imported (V6)**: the V7 branch; `prototypes/.gdignore` and PROJ-7.
- **The `inferred_declaration` warning, if ever turned on, stops gdUnit4 loading**: exclude `res://addons/gdUnit4` in `debug/gdscript/warnings/directory_rules` in that change.
- **`run-and-observe.md` suggests an autoload for capture-on-trigger**: Decision 12 forbids it; PROJ-1 fails it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-012: logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files | Decision 3 (`CatalogueFactory`, `Catalogue.from_data`, `tests/integration/data/` and `content/`); TEST-2 |
| input-gesture-resolver.md | TR-input-014: identical call lists give identical signal logs; a recording fake, not `assert_signal`; bots call commands plus one resolver equivalence test | Decision 4 (one ordered, typed log; whole-log `expect`); TEST-1; Decision 5 (battle runner; the equivalence test's script format is ADR-0010's) |
| game-state-stage-flow.md | TR-state-013: tests enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when any battle signal has no listener (views on an allowlist) | Decision 5 (`Battle.emitters()`, `digest`), Decision 4, Decision 6 (harness and W2 self-proof; contract ADR-0006) |
| combat-damage.md | TR-combat-012: errors use `push_error`, asserted with `assert_error().is_push_error()` with the report setting on; invariant I checks damage sums | Decision 7 (PROJ-5, one assertion per single push, `combat_invariant.gd` with tamper tests); V2 |
| enemy-wave.md | TR-enemy-014: a headless content test checks layout rules L1 to L14 and wave rules on in-memory records; unit tests use fakes and no scene or files | Decision 3 (content suites on the loaded catalogue's records, broken fixtures; `Fakes`); TEST-2, TEST-3 |
| tower-system.md | TR-tower-014: all logic unit-testable headless with spy accessor, recording fake and fake `halted()`; the content test enforces tower and gold rows | Decision 3 (`SpyStatAccessor`, `Fakes.Halted`, content suites), Decision 4 |

Foundational as well: the lint enforces `architecture.md` layer rules 1 to 6 and the rules ADR-0001 to ADR-0006, ADR-0008 and ADR-0009 deferred, which constrains every GDD system's implementation.

## Performance Implications
- **CPU**: None at run time (PROJ-7 keeps tests, tools and the addon out of exports). In CI, the import plus the lint over an MVP-sized `src/` (under 200 files, about 70 rules) is expected to take seconds; unmeasured, the first CI run records it.
- **Memory**: None at run time.
- **Load Time**: None at run time.
- **Network**: None.

## Migration Plan

No game code exists. In order:

1. Before acceptance: the Status note's list (the one list).
2. First harness story (after ADR-0001's `FatalLatch` story): the `[gdunit4]` settings; `tools/lint/` with every rule whose owner is Accepted, the rest pending; the self-tests; `repo_lint_test.gd`; `fakes.gd`, `recording_fake.gd`, `battle_probe.gd` `alive()`; `catalogue_factory.gd` once ADR-0002's `from_data` exists; the zero-test CI step; Validations 3 and 4.
3. When ADR-0006 is Accepted (second activation): `wiring_check.gd` and `battle_wiring_test.gd` with the first two sims; WIRE-5 to WIRE-12 switched on with ADR-0006's contract file. When ADR-0008 is Accepted: INPUT-9, INPUT-10.
4. With later code: STATE-4 to STATE-8 with ADR-0009's first stories; STAT-1 with the accessor; SCENE-1 with the first wrapper story; `digest`, `battle_runner`, `baselines` with the first two sims; `combat_invariant` with Combat.
5. Remove `tests/unit/.gdignore_placeholder` and `tests/integration/.gdignore_placeholder` when the first real file lands in each.

**Rollback plan**: If V2 shows gdUnit4 cannot capture `push_error` headless, turn the setting off, route every `src/` error report through `DevErrorSink` (tests read its record), and reopen ADR-0009 Decision 4's direct `push_error` exception. If the GDScript lexer proves too fragile, keep the catalogue and self-tests and move only `lint_engine.gd` to another language as a CI step. If the action fails V5, replace it with explicit steps.

## Validation Criteria

1. V1 to V7 recorded in `current-best-practices.md` before acceptance.
2. **Every lint rule watched failing.** The self-test iterates the rule table: each active rule's seeded bad sample yields exactly its finding on the expected line, each near miss yields none; each rule's test is run red before the rule is implemented.
3. **Seeded bad files, end to end.** With the lint green on the real repo, the harness story adds one seeded file at a time, runs the CI command, confirms exit 100 with the finding named, removes it, confirms exit 0: (a) `src/core/_lint_probe.gd` referencing a `src/feature/` class (LAYER-1); (b) the same file preloading a `uid://` path (LAYER-5); (c) an `[autoload]` section in `project.godot` (PROJ-1); (d) a `class_name` in a `tests/helpers/` script (NAME-3); (e) a test with a `do_skip` parameter (TEST-6). Outputs kept in `production/qa/evidence/adr-0007-lint-seeded/`; once on CI through a pull request that must go red; rerun whenever `lint_engine.gd` changes.
4. **Unasserted error and orphan fail.** Seeded runs, one each: an unasserted `push_error` exits 100; two identical pushes with one assertion exit 100; a leaked node exits 101 with PROJ-5's settings; outputs kept beside Validation 3's. The positive case stays in CI.
5. The listener-count test passes on a fixture battle and its W2 self-proof returns exactly the expected line on every run (once ADR-0006 is Accepted).
6. The recording fake's own tests: a `String` into a `StringName` parameter, a missing argument, an extra entry, a wrong order and an `ANY` match give the expected results.
7. A fresh clone, import and the CI command exit 0 on Linux CI and the user's Mac; a run with no tests fails the CI job.
8. NAME-1 to NAME-4 report nothing once the classes exist (V6 checked the ADR names earlier by scan).
9. SCENE-1 passes after `attach`, and fails when one HUD label is set to `MOUSE_FILTER_STOP` (watched once, kept).
10. `repo_lint_test.gd` fails when a rule ID is added to `lint_rules.gd` without a catalogue row (watched once).

The decision is wrong if: the lint cannot be quiet on correct code without more than ten exceptions; a defect class it targets ships past it; or gdUnit4 cannot report `push_error` headless on 4.7.2 even after an upgrade.

## Related

- Depends on ADR-0001; second activation on ADR-0006 (contract, `emitters()`, listener-count tests; wiring rules bind `src/`, tests may connect, disconnect and call test seams).
- Enforces rules deferred by ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0008 and ADR-0009: `docs/architecture/adr-0007-lint-rules.md` (companion catalogue, part of this ADR).
- Verification procedures: `prototypes/adr-0007-harness-check/README.md`.
- Enables ADR-0008, ADR-0010, ADR-0011.
- `docs/architecture/architecture.md`: Dependency rules 1 to 6, "What cannot be tested headless", QQ-13, QQ-15, QQ-16 (resolved here when Accepted).
- GDDs: `data-config-pipeline.md` (Rule 12, Acceptance preamble), `input-gesture-resolver.md` (Acceptance preamble), `game-state-stage-flow.md` (wiring test, deferred criteria), `combat-damage.md` (Acceptance preamble), `enemy-wave.md` (content test, Acceptance 58), `tower-system.md` (Acceptance preamble, 59).
- `.claude/docs/coding-standards.md`, `.claude/rules/test-standards.md`, `.claude/rules/skill-authoring.md`.
- `addons/gdUnit4/` 6.2.0, `.github/workflows/tests.yml`, `tests/README.md` (rewritten per the cascade notes).
