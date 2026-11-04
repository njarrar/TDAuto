# ADR-0007: Headless Test Harness, gdUnit4 and Layer Lint

## Status

Proposed

> TD-ADR: not run per ADR; batch review after all ADRs are written.
> Engine specialist validation: not run (no agents spawned for this batch).

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

lead-programmer (draft). Acceptance rests with the user or technical-director.

## Summary

The architecture promises that every simulation system runs headless and that layer rules hold, but GDScript has no module boundaries and no shared test kit exists yet. This ADR fixes the test layout, fixture factories, recording fakes, battle snapshot, listener-count test, `push_error` reporting, a CI layer-import lint, the list of what only a device can prove, and the GDScript 4.7 pitfalls that the control manifest must repeat.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (testing and tooling) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM for this ADR. The harness calls no rendering, physics or audio API. The version overall is HIGH (`VERSION.md`), and the typed-return override rule changes how every test fake is written. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/breaking-changes.md` (GDScript typed-return override row); `docs/architecture/architecture.md` (layer map, B4 to B9, "What cannot be tested headless"); `tests/README.md`; `.github/workflows/tests.yml`; the vendored gdUnit4 6.2.0 source in `addons/gdUnit4/src/`; the 4.7.2-stable class reference for `Object`, `Script`, `DirAccess`, `FileAccess`, `RegEx`, `@GlobalScope` and `@GDScript`. |
| **Post-Cutoff APIs Used** | None known. The typed-return override rule is a 4.7 change that affects fakes. |
| **Verification Required** | See the list below. Each item names the run that settles it. |

Sourced facts (class reference at the `4.7.2-stable` tag unless noted):

- `assert(condition, message)` runs only in debug builds or from the editor, and a failed one only generates an error. `push_error(...)` pushes to the debugger and terminal and does not pause the project (doc/classes/@GlobalScope.xml, `push_error`; modules/gdscript/doc_classes/@GDScript.xml, `assert`). So release-relevant checks use `push_error` and an injected handler.
- `Object.has_connections(signal: StringName) -> bool`; `Object.get_signal_list() -> Dictionary[]`; `Object.get_signal_connection_list(signal)` returns dictionaries with `signal`, `callable` and `flags` (doc/classes/Object.xml). `Script.get_script_signal_list()` returns "the list of signals defined in this Script", formatted like `get_signal_list` (doc/classes/Script.xml).
- `DirAccess.get_files_at(path)` and `get_directories_at(path)` are static and return sorted `PackedStringArray`s. On a `res://` path in an exported project only some files are listed (doc/classes/DirAccess.xml). The lint reads the source tree, never an export.
- `FileAccess.get_file_as_string(path)` is static, reads UTF-8, and returns an empty `String` on an open error; `FileAccess.get_open_error()` gives the cause (doc/classes/FileAccess.xml).
- `RegEx.create_from_string(pattern, show_error = true)`, `search_all(subject, offset, end)` and `sub(subject, replacement, all, ...)` (modules/regex/doc_classes/RegEx.xml).
- An override of a typed-return method inherits that return type and needs an explicit `return` (`breaking-changes.md`, GDScript row). Every test fake obeys it.
- gdUnit4 6.2.0 (vendored source): `assert_error(callable).is_push_error(expected)` exists (`GdUnitGodotErrorAssertImpl.gd`). The project setting `gdunit4/report/godot/push_error` ("Report push_error() as failure") defaults to `false` and is only created when absent (`GdUnitSettings.gd`, `create_property_if_need`). `project.godot` holds no `gdunit4` key today.
- CI exit codes (`tests/README.md`): 0 pass, 100 fail, 101 orphan warning, 103 or 104 runner failure, 105 parse failure. "No test cases found" with exit 0 is not a pass.

### NOT SOURCEABLE (blocks Acceptance)

- NOT SOURCEABLE: that a `gdunit4/report/godot/push_error=true` key in `project.godot` is read by the headless CI run. Run: in the harness story, add the key, run a test that calls `push_error` unasserted (must fail) and one that wraps it in `assert_error(...).is_push_error(...)` (must pass), in the CI job on `main`.
- NOT SOURCEABLE: whether `get_script_signal_list()` includes signals declared in a base script or only the script's own. Run: a probe test in the harness story on a two-level fake pair, printed once in CI. The listener-count test is not Accepted until the answer is recorded here.
- NOT SOURCEABLE: that gdUnit4 6.2.0 ignores helper classes under `tests/support/` (no `GdUnitTestSuite` base) and reports no "No test cases found" for them. Run: first CI run after the folder gets a file.
- NOT SOURCEABLE: that `DirAccess.get_files_at("res://src/...")` lists every `.gd` file in the CI checkout. Run: the lint integration test's scanned-file count, printed in the first CI run and compared with `git ls-files src`.
- NOT SOURCEABLE: that a fake subclass of a typed base (a `RefCounted` class with a typed-return method) parses under `godot --headless` on 4.7.2 with an explicit `return` in the override. Run: the first fake, in the CI job (exit 105 means failure).
- NOT SOURCEABLE: whether the headless run has a usable display server for a test that instantiates a scene. Run: one probe test in `tests/integration/framework/` that instantiates a minimal scene, once in CI. Only the manual-evidence list depends on it.
- NOT SOURCEABLE: wall-clock time of the whole suite in CI. No budget is set. Run: the first CI run after the lint and the first Battle fixtures land; record the time here.
- NOT SOURCEABLE: the false-positive rate of the text-based lint on real `src/` code. Run: the lint over the first full Foundation and Core folders; each false positive is fixed in the lint, not allowlisted, unless it is a documented exception.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (builder options for replacement systems, injected callables, `dev_error` sink); ADR-0006 (signal list and view allowlist content) |
| **Enables** | ADR-0010 (equivalence tests use the snapshot and recording fakes); ADR-0009 (Combat tests); every system's first story |
| **Blocks** | The first story of any system (tests are required evidence for Logic stories); the layer-lint story |
| **Ordering Note** | The mechanisms here come first; the allowlist content comes from ADR-0006. ADR-0002 owns the shape of the content tests (real data files); this ADR gives them a home and the rule that unit tests never touch files. |

## Context

### Problem Statement

The architecture rests on four testable claims: the battle is a plain function of its inputs, systems meet only through injected callables and signals, views cannot change a result, and layers depend downward only. Nothing yet runs those checks. GDScript makes every `class_name` global, so a stray reference to a higher layer compiles. Release builds strip `assert`, so checks that matter must use `push_error`, and tests need a sound way to assert on it. Several systems also name this ADR as the owner of their test seams.

### Current State

- gdUnit4 6.2.0 is vendored in `addons/gdUnit4/`.
- `.github/workflows/tests.yml` runs on push and pull request to `main`, with the gdUnit4 action at `version: installed`, over `tests/unit` and `tests/integration`. It is green on `main`.
- `tests/unit/framework/framework_sanity_test.gd` is the only suite. It proves the runner loads and runs.
- `src/` holds no code. The architecture proposes `src/foundation/`, `src/core/`, `src/feature/`, `src/presentation/` and `src/root/`.
- `tools/balance-sim/hero_bots.py` is a throwaway Python sim. It is not a CI gate and this ADR leaves it alone.

### Constraints

- Tests are deterministic: no random seeds, no real clock, no time assertions (coding standards).
- Unit tests do no file I/O and call no external API.
- A check that did not run must say so. Zero inputs must never read as a pass.
- One solo, part-time developer: the kit must be small.
- No autoloads. Fakes arrive by injection, as method Callables on small objects (ADR-0001).

### Requirements

- TR-data-012: logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files.
- TR-input-014: identical call lists give identical signal logs; tests use a recording fake; bots call commands directly plus one resolver equivalence test.
- TR-state-013: tests can enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when a battle signal has no listener.
- TR-combat-012: errors use `push_error`, asserted with `assert_error().is_push_error()`, with the report setting on.
- TR-enemy-014: a headless content test checks layout and wave rules on in-memory records; unit tests use fakes and no scene or files.
- TR-tower-014: logic is unit-testable headless with a spy accessor, a recording fake and a fake `halted()`.

## Decision

### 1. Layout

```
tests/unit/<layer>/<system>/      logic suites, no file I/O, no scene
tests/unit/framework/             the sanity canary and harness self-tests
tests/integration/<system>/       cross-system suites, real data files, the lint scan
tests/support/                    helper classes only (no suite base class)
tests/fixtures/                   data used by tests: allowlists, layer map, expected-output files
production/qa/evidence/           manual evidence (see section 8)
```

Suite and function names follow `.claude/rules/test-standards.md`. Suites extend `GdUnitTestSuite`, create engine objects with `auto_free`, and follow arrange, act, assert. `tests/support/` classes extend `RefCounted` and never `GdUnitTestSuite`. Helpers are factory functions, never shared mutable state. The existing workflow paths (`tests/unit`, `tests/integration`) already cover every suite folder. The CI job must keep failing on "No test cases found"; if the action does not do this, the devops-engineer adds a step (that change is outside this ADR).

### 2. Fixture catalogues (TR-data-012, TR-enemy-014)

`tests/support/fixtures.gd` holds factory functions that build records in code: `tower()`, `enemy()`, `wave()`, `stage()`, `hero()`, `burst()`, `input_record()` and `catalogue(overrides)`. Defaults come from named constants in the file, each with a comment citing the GDD row it mirrors; a test overrides only what it tests. A factory returns a fresh object every call. Logic and rule tests use these and touch no file. The real data files are tested only under `tests/integration/content/`, which opens them through the production loader (ADR-0002). Content rule functions take in-memory records and return rule IDs, so a rule unit test is a pure call on a fixture, and a "broken copy" of a stage is a fixture with one field changed.

### 3. Recording fakes (TR-input-014, TR-tower-014)

- `RecordingListener` (support class). `listen(source: Object, signal_name: StringName)` connects a method Callable; every emit appends `{signal, args}` to `log: Array[Dictionary]` in order. Tests compare the whole log with an expected array, which asserts payloads, types and order in one check. Two runs with the same call list must give equal logs.
- Tests use the recording fake in place of `assert_signal`, as the TR requires.
- `SpyAccessor` extends the production accessor interface, records every `(ctx.def_id, ctx.level, key)` read, and returns values from a dictionary the test supplies. It lets a test prove a value is read at use time and never cached.
- `FakeHalted`, `FakeErrorSink`, `FakeTargets` are tiny classes with one method each, matching the injected callables in B9. `FakeHalted.value` flips mid-test. `FakeErrorSink.messages` collects `dev_error` calls.
- Every fake that overrides a typed-return method ends in an explicit `return`.
- Fakes pass their method Callables to the system under test. They never use lambdas or `bind()` that capture a sim object (ADR-0001).

### 4. Battle probe (TR-state-013)

`tests/support/battle_probe.gd` takes a `Battle` and offers:

- `systems() -> Dictionary`: the six read-only members of `Battle` (`flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`), by name.
- `snapshot() -> Dictionary`: built from public reads only (`Flow.phase()`, `lives()`, `result()`; `TowerSim.gold()`, `slot_state()`, `slows_applied()`; `HeroSim` queries and counters; `EnemyWave.roster()` as `(spawn_id, def_id, distance, hp_left)` rows; `Combat` counters). It copies values, so a later tick cannot change an earlier snapshot. A system adds its reads to the probe in the story that adds the read.
- `same(a, b) -> bool` and a readable diff for the failure message.

Replacement systems enter through the Builder's build options (ADR-0001 fixes the parameter), so a test can build a battle with a recording system in place of a real one. A snapshot that reads a private member is a defect in the probe.

### 5. Listener-count test (TR-state-013)

One integration test builds a headless `Battle`. For each of the six systems it takes `get_script().get_script_signal_list()` and, for each signal name, requires `has_connections(name)`. A signal with no listener passes only if `tests/fixtures/signal_allowlist.json` lists `"System.signal"` with a non-empty `reason`. Headless there are no views, so the allowlist is the set of signals whose only listeners are views; ADR-0006 supplies its content. The test also fails on:

- an allowlist entry that names a signal no system declares (stale);
- an allowlist entry for a signal that does have a listener (the entry is dead);
- zero signals enumerated across all systems (the check did not run).

### 6. Error reporting (TR-combat-012)

- Checks that matter in release use `push_error` and the injected handler, never `assert` (principle 5, sourced above).
- `project.godot` gets `gdunit4/report/godot/push_error = true`, so a test that triggers an unasserted `push_error` fails.
- A test that expects an error wraps the call: `assert_error(callable).is_push_error("message")`. Every refusal path that logs has such a test.
- Combat invariant I (damage sums) has a test that corrupts a counter through a fake and expects the `push_error`, plus a clean run that expects none.
- `FakeErrorSink` is used for `dev_error`. Tests never read the console.

### 7. Layer-import lint

The lint has three parts so that its logic is unit-testable without files.

- `tests/fixtures/layer_lint/layer_map.json` maps each `src/` folder to a layer and lists exceptions, each with a reason:

```json
{
  "folders": {
    "src/foundation": "foundation", "src/core": "core", "src/feature": "feature",
    "src/presentation": "presentation", "src/root": "root"
  },
  "feature_modules": ["src/feature/enemy_wave", "src/feature/tower", "src/feature/hero"],
  "engine_node_allowed": [{"path": "src/foundation/input/input_adapter.gd", "reason": "the one engine-facing input node"}]
}
```

- `tests/support/layer_lint.gd` (`LayerLint`) is a pure class. `scan(files: Dictionary) -> Array[LintError]` takes `{path: source_text}`, with `LintError` holding `rule`, `path`, `line`, `token`. It strips string literals and comments, collects each file's `class_name`, then checks every identifier in each file against the class table and every `load` or `preload` call:
  1. `up`: a file in layer L references a class declared in a layer above L. Layer order is foundation, core, feature, presentation. Root is above all.
  2. `root`: any file outside `src/root/` references a class declared in `src/root/`.
  3. `sibling`: a file in one `feature_modules` folder references a class declared in another.
  4. `core_names_feature`: covered by `up` (Combat naming `Enemy`); a separate test names it because architecture rule 5 depends on it.
  5. `node_in_sim`: a file under foundation, core or feature declares `extends` of a `Node` type or calls `get_tree` or `Engine.` unless listed in `engine_node_allowed`. Simulation classes extend `RefCounted`.
  6. `dynamic_load`: a `load(` or `preload(` whose argument is not a string literal, outside `src/root/`.
  7. `unmapped`: a `.gd` file under `src/` whose folder is not in the map.
- `tests/unit/framework/layer_lint_test.gd` runs `LayerLint` on in-memory sources: a clean set, and one broken copy per rule, each of which must report exactly its rule and no other. A copy that reports nothing, or a second rule, fails.
- `tests/integration/framework/layer_lint_scan_test.gd` walks `src/` with `DirAccess.get_directories_at` and `get_files_at`, reads each file with `FileAccess.get_file_as_string`, and feeds `LayerLint`. It fails if the scanned file count is zero, if any file reads back empty, or if any `LintError` is returned. It prints the scanned count.

The lint has no false-negative guarantee. A reference through a string-built name or a dynamic `get()` is invisible to it; rule 6 limits the common route. The doc comments mention classes too, so comment stripping is required and tested.

Because the scan fails on zero files, the lint story merges together with, or after, the first Foundation script. Until then the lint suite is not in `main`.

### 8. What cannot be tested headless

These become manual-evidence stories. Each has a file in `production/qa/evidence/` named `<story-id>-<slug>.md` that records the build, the device, the date, the steps and a retained screenshot or log excerpt, and that is closed only with lead sign-off:

1. InputAdapter and Control event order (ADR-0003 spike and result).
2. Lifecycle notifications per platform.
3. `free()` versus `queue_free()` timing on retry (the weakref test itself runs headless, if the test holds no reference to the old battle).
4. Safe-area values on target phones.
5. The catalogue load from an Android export (ADR-0002).
6. Draw-call and frame-time budgets on a phone (ADR-0004, ADR-0011).

Everything in B0 to B2 and B4 to B9 runs headless.

### 9. GDScript 4.7 pitfalls for the control manifest

The manifest must repeat these as Required or Forbidden rules:

- A typed-return override needs an explicit `return` (all fakes).
- `Array[Targetable]` and `Array[Enemy]` are not interchangeable; build lists as `Array[Targetable]` from the start (architecture rule 5).
- Injected callables are method Callables only; no lambda or `bind()` that captures a sim object.
- No `CONNECT_DEFERRED` on gameplay signals.
- `assert` never guards release-relevant behaviour.
- Float width and `Vector2` precision rules are ADR-0004's (float policy) and QQ-05's; this ADR sources neither, and the manifest copies them from ADR-0004.
- Retire a battle by dropping references, as ADR-0001 decides; tests never call `free()` on a sim object.
- Tests never rely on test execution order.

### Architecture Diagram

```
 tests/unit (no files)                    tests/integration (real files, scan)
   Fixtures --> system under test           real data files --> production loader --> rules
   RecordingListener / Spy / Fakes          src/**/*.gd --> LayerLint --> LintError[]
   BattleProbe.snapshot()                   Battle --> listener-count test <-- signal_allowlist.json
        |                                          |
        +---------- gdUnit4 6.2.0 (godot --headless) ----------+
                              |
                    CI: tests.yml (exit 0 / 100 / 101 / 103-105)
 Manual evidence (device only) --> production/qa/evidence/
```

### Key Interfaces

```gdscript
class_name LayerLint extends RefCounted
## Pure. Takes {path: source_text}; returns the layer errors. No file or engine access.
func scan(files: Dictionary) -> Array[LintError]

class_name RecordingListener extends RefCounted
## Records every emit as {signal, args}, in order.
func listen(source: Object, signal_name: StringName) -> void
var log: Array[Dictionary]

class_name BattleProbe extends RefCounted
func systems() -> Dictionary
func snapshot() -> Dictionary
```

All public methods carry doc comments.

### Implementation Guidelines

- Unit tests must not read or write files, load a scene, or use a real clock or random seed.
- Test data must come from `Fixtures` factories or `tests/fixtures/`, never shared mutable state.
- A test that checks a collection must first assert it is not empty, or name the missing input in the failure.
- Tests must compare whole recording logs, not single fields, when order or payload matters.
- A refusal path must be tested for "no mutation and no emit" using a snapshot before and after.
- Fakes must end every typed-return override in an explicit `return`.
- A new engine-facing class must be listed in `engine_node_allowed` with a reason, in the same change.
- Lint exceptions must carry a reason. A silent allowlist entry is a defect.
- A bug fix must have a regression test that was seen failing against the unfixed code.
- Device budgets must never appear as CI assertions.

## Alternatives Considered

### Alternative 1: Rely on code review for layer rules

- **Description**: No lint; reviewers check imports.
- **Pros**: No tool to build.
- **Cons**: Every `class_name` is global, so a wrong reference compiles and runs. A solo developer is the only reviewer.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: The architecture's rule 6 says the lint, not the language, enforces the layers.

### Alternative 2: A Python lint script run in CI

- **Description**: Scan `src/` from `tools/`.
- **Pros**: Easy text handling.
- **Cons**: Needs a Python install on the runner (not sourced for this CI job), a second language, and cannot be unit tested through the same runner.
- **Estimated Effort**: Similar.
- **Rejection Reason**: A gdUnit4 suite runs in the existing job with no new dependency.

### Alternative 3: Use gdUnit4 mocks and `assert_signal` for everything

- **Description**: Mock systems and assert on signals directly.
- **Pros**: Less support code.
- **Cons**: TR-input-014 requires recording fakes that assert whole logs. Spying a class does not give an ordered payload log.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Does not meet the TR.

### Alternative 4: Parse GDScript properly for the lint

- **Description**: Use a real parser.
- **Pros**: No text false positives.
- **Cons**: No parser is sourced for this engine in the reference; building one is out of scope.
- **Estimated Effort**: Much higher.
- **Rejection Reason**: Text matching with comment and string stripping is enough for the rules above, and its blind spot is stated.

## Consequences

### Positive

- Every Logic story has a ready kit: fixtures, fakes, probe.
- A wrong-way reference fails CI with the rule name and line.
- A dead or stale signal fails a test, so views cannot silently lose a listener.
- A check that scans nothing fails.

### Negative

- Support code (fixtures, probe, lint) must be written and kept in step with the systems.
- The lint is text-based and can miss indirect references.
- The `push_error` setting makes any stray `push_error` in a test an error.

### Neutral

- Bot policies and gate suites are not decided here. They use the same kit and call `Battle` commands only.
- ADR-0002 still owns the real-data content tests.

## Risks

- The `project.godot` setting is not read in headless CI. Mitigation: the first verification item above; until it passes the ADR stays Proposed.
- The lint produces false positives on real code and gets muted. Mitigation: fix the lint, not the code, for each false positive; exceptions need reasons; the broken-copy table pins every rule.
- The signal enumeration misses base-script signals. Mitigation: the probe test above.
- Suite run time grows. Mitigation: unit suites do no I/O; measure at the first CI run and split a slow suite into its own folder.
- A helper class under `tests/support/` is mistaken for a suite. Mitigation: no `GdUnitTestSuite` base; first CI run checks it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-012: logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files | Section 1 layout; section 2 `Fixtures` factories; real files only under `tests/integration/content/` |
| input-gesture-resolver.md | TR-input-014: identical call lists give identical signal logs; recording fake, not `assert_signal`; bots call commands directly plus one resolver equivalence test | Section 3 `RecordingListener` with whole-log comparison; the equivalence test itself is in ADR-0010 |
| game-state-stage-flow.md | TR-state-013: enumerate systems, inject recording fakes, snapshot a battle, fail on a signal with no listener | Sections 4 and 5: `BattleProbe`, builder options, listener-count test with allowlist |
| combat-damage.md | TR-combat-012: `push_error` asserted with `assert_error().is_push_error()`, report setting on; invariant I checks damage sums | Section 6 |
| enemy-wave.md | TR-enemy-014: headless content test on in-memory records; unit tests use fakes and no scene or files | Section 2: rule functions on fixtures, broken copies as fixtures; section 3 fakes |
| tower-system.md | TR-tower-014: unit-testable headless with a spy accessor, a recording fake and a fake `halted()` | Section 3: `SpyAccessor`, `RecordingListener`, `FakeHalted` |

## Performance Implications

- **CPU**: CI time only. The lint scans every `src/` file once with regex passes; the cost is unknown until the first run (see NOT SOURCEABLE). No game cost.
- **Memory**: Test process only.
- **Load Time**: None in the game. Test code is not exported.
- **Network**: None.

## Migration Plan

1. Add `tests/support/fixtures.gd`, `recording_listener.gd`, and the fakes with the first system story.
2. Add `gdunit4/report/godot/push_error` to `project.godot` and prove it in CI (verification item 1).
3. Add `BattleProbe` with the Builder story; add the listener-count test when the Battle first builds.
4. Add `LayerLint`, its broken-copy table and the scan test together with the first Foundation script.
5. Open the six manual-evidence stories before the first phone build.

The sanity canary stays.

**Rollback plan**: Mark the lint scan test advisory by moving it out of `tests/integration/` if it blocks work on false positives; keep the unit table. Restore the gate once the lint is fixed.

## Validation Criteria

- Each broken-copy lint fixture reports exactly its rule; the clean set reports none.
- The scan test fails on an empty `src/` and passes on a clean tree, with the scanned count printed.
- An unasserted `push_error` fails a test; an asserted one passes.
- The listener-count test fails when a listener is removed, and when an allowlist entry goes stale.
- A fake subclass parses on 4.7.2 headless.
- Every NOT SOURCEABLE item above has its run recorded in this ADR.

## Related

- ADR-0001 App Lifecycle, Composition Root and Fatal Path (depends on)
- ADR-0006 Battle Signal Contracts and View Allowlist (depends on)
- ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry (uses the probe and fakes)
- ADR-0002, ADR-0003, ADR-0004, ADR-0009, ADR-0011 (cited for content tests, spike, budgets)
- `docs/architecture/architecture.md` (layer rules, B4 to B9, "What cannot be tested headless")
- `tests/README.md`, `.claude/rules/test-standards.md`, `.github/workflows/tests.yml`
- `tests/unit/framework/framework_sanity_test.gd`
