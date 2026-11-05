# ADR-0007: Headless Test Harness, gdUnit4 and Layer Lint

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer in an autonomous run. Reviewed 2026-11-05 by technical-director (TD-ADR: CONCERNS, 4 blockers, 5 concerns, 3 advisories) and godot-specialist (APPROVE WITH FIXES, 3 blockers, 9 minors, plus a review probe, `prototypes/adr-0007-probe/output-review.txt`). All findings were applied in the same-day fix round; the fix round added rule L30 and left L01-L29 numbered as before. A re-review of the revised text follows. Fix round 2026-11-05 after architecture-review-2026-11-05 (items applied: dropped delegations 0003, 0010, 0006, 0002, 0004 -> 0007 (pointer fixtures, L32 to L36), L16 files, bot ids, evidence naming, field-view lint, Decision 5 listener sentence, rule count 36, Depends On). Fix round 2 2026-11-05 after architecture-review-2026-11-05b (items applied: K1 ordering note and Enables row, K2 L34 scope and portable patterns, E2 L16 owed wording, L36 adds `draw_polyline` and is named a guard, new L37 field-view rule, wiring test builds from a fresh `Battle` and frees the first wrapper; 37 rules).

## Summary
Nine earlier ADRs delegate tests, lints and CI checks to this one, and no harness, runner or lint exists yet. This ADR decides: gdUnit4 6.2.0 as installed, run headless after an explicit `--import`; one test layout with fixtures and recording fakes kept out of `src/`; a parse check that detects failure through `GDScript.can_instantiate()` (because `load()` of a broken script does not return null); one bash layer-lint runner with a 37-rule catalogue, an allowlist whose stale entries fail, and a self-test that proves each rule fires; a listener-count wiring test, a per-host baseline runner with a candidate-artifact mode, a repeated-JSON-key check, a fixed CI order in which everything blocks, and a manual-evidence list for what headless cannot show.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Core (tooling) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH for tooling: the CLI flags, gdUnit4 6.2.0 and the 4.7 typed-return rule post-date the training data. Most claims below are taken from the engine reference or observed. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `current-best-practices.md` section "Command Line - Tests and Parse Check" (gdUnit4 command, exit codes 0/100/101/103/104/105, `No test cases found` exits 0, `--import` first on a fresh clone); `breaking-changes.md` (4.7: an override of a method with a typed return inherits that type and needs an explicit `return`); `.gitignore` lines 55-70 (class cache un-ignored); `tests/README.md`; ADR-0001 probe table (`--check-only -s` exits 0 on a parse error); ADR-0002 probe (repeated JSON key keeps the last value); ADR-0004 probe (`var_to_str` round-trips an int `rng.state`; JSON does not); ADR-0006 probe rows 4, 6, 7, 8 |
| **Post-Cutoff APIs Used** | `GDScript.can_instantiate()` and `reload()` (older than 4.5, observed below). Typed-return override rule (4.7) is caught, not used. |
| **Verification Required** | See the Verification table in Validation Criteria: 12 rows; V2, V3, V7 and V9 are closed as observed by the review probe, the rest stay `NOT SOURCEABLE`. Observed here: 4.7.2 probe, 2026-11-05, prototypes/adr-0007-probe/ (`output.txt`): (1) `load("res://bad.gd")` of a script with a syntax error prints `SCRIPT ERROR: Parse Error` and `Failed to load script ... Parse error`, and **returns a non-null GDScript** (exit code 0); (2) on that script `can_instantiate()` is `false` and `reload()` returns `43`; on a good script `can_instantiate()` is `true`; (3) `GdUnitCmdTool.gd` run in a project with no class cache (no prior `--import`) prints `Parse Error: Could not find type "GdUnitTestCIRunner"`, fails to load, and the pipe's last stage exit was **0**; so the tool's exit code alone is not a gate. **Caveat: desktop debug editor only. Repeat on a CI Linux runner before Accepted.** Review probe (4.7.2 probe, 2026-11-05, prototypes/adr-0007-probe/output-review.txt, same caveat, no `--import`): `load()` of a `.tscn` with a missing `ext_resource` prints three `ERROR:` lines and returns a non-null `PackedScene` with `can_instantiate()` true; `ProjectSettings.get_global_class_list()` returns `[]` without an import; `get_script().get_global_name()` returns the class name; `can_instantiate()` is false and `reload()` is 43 for a syntax error, an unknown type and the 4.7 typed-return override without `return`; host strings are `macos`, `arm64`, `4.7.2` once lower-cased. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted: composition root, roots, `build()` callable from tests); ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0008, ADR-0009, ADR-0010, ADR-0011 (Proposed: each delegates checks collected in Decision 7; ADR-0003 and ADR-0008 also supply lints and fixtures, ADR-0010 and ADR-0011 supply rules L16, L32 to L34, L36 and L37). Ordering: this ADR depends on every other ADR and is accepted last; ADR-0010 and ADR-0011 delegate to it without depending on it, which keeps the graph acyclic |
| **Enables** | Every Logic and Integration story (a place to put tests), `/test-setup`, `/create-control-manifest` |
| **Blocks** | First story that writes a test; first `.gd` under `src/` (the lint and parse check must exist before it, per ADR-0001's Ordering Note) |
| **Delegates To** | `/test-setup`: scaffolding the directories, `tests.yml`, the stub scripts of Decision 12. ADR-0010 (taken up): the RunLog fake sink class (`FakeRunLogSink`, `tests/support/`), the command-script format, the bot roster (five ids, Decision 6) and the pin-geometry files of L16 (no `owed:` entry). ADR-0011 owns evidence file naming and screenshot capture. ADR-0011: the screenshot capture method and file naming under `production/qa/evidence/`. |
| **Ordering Note** | Accept with ADR-0006 (Decision 10 there is run by Decision 5 here). If Decision 9 (no prefix) is overturned, the class names in ADR-0001 to ADR-0009 are renamed without reopening them. |

## Context

### Problem Statement
Every earlier ADR ends in "ADR-0007's lint" or "ADR-0007's runner". Without one owner, each check is a promise with no mechanism: the repo has `addons/gdUnit4`, empty `tests/unit` and `tests/integration`, a stale `tests/README.md` (QQ-13) and no `tools/ci`. Three engine facts make the mechanism non-obvious: `--check-only -s` is not a parse check (ADR-0001 probe), `load()` of a broken script returns a live object (probe, observed here), and the gdUnit4 runner can exit 0 having run nothing. A check that cannot report that it did not run is not a check; every runner below must say "ran N" or fail.

### Constraints
- Godot 4.7.2, GDScript, gdUnit4 6.2.0; solo developer, workflow `full`; no autoload, `src/battle/` is `RefCounted` only.
- Headless and file-I/O-free for logic tests (TR-data-012); real data files only in `tests/integration/data/` (ADR-0002 Decision 12).
- Determinism is per host (ADR-0004 Decision 12): baselines multiply by OS, architecture and engine version.
- CI must not need a display or a device.

### Requirements
- TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014, TR-tower-014 (table near the end).
- Collect every delegated lint and check into one catalogue; resolve QQ-13, QQ-15 and QQ-16.

## Decision

**1. Framework.** gdUnit4 6.2.0 (`addons/gdUnit4/plugin.cfg`), as installed and committed. The CI command is CLAUDE.md's with `--path .` and a mandatory preceding import: `godot --headless --path . --import`, then `godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/<dir> --ignoreHeadlessMode`. The two `ERROR:` lines about port `127.0.0.1:0` are expected. CLAUDE.md and `coding-standards.md` carry the command without the import; the edit is in the gdd-sync file. **QQ-13 resolved:** `.godot/global_script_class_cache.cfg` stays tracked (the `.gitignore` un-ignore stays), and CI runs `--import` anyway, because a stale tracked cache is the failure mode, so lint L26 checks the cache against the `class_name` declarations. NOT SOURCEABLE: whether a fresh clone also needs `.godot/uid_cache.bin` (untracked) for `uid://` scene references to resolve; `--import` in CI makes it moot there, and V8 covers the clone case. `tests/README.md` is rewritten at acceptance (gdd-sync file). Every gdUnit4 invocation goes through `tools/ci/run-tests.sh <dir>` (Decision 3).

**2. Layout and naming.**
- `tests/unit/<system>/`: Logic stories, no file I/O, no scene. `tests/integration/<system>/`: multi-system and real-data content tests; the TR-input-014 resolver equivalence test is `tests/integration/input/resolver_bot_equivalence_test.gd`. `tests/smoke/`: `critical-paths.md` plus `smoke_boot_test.gd` (builds one battle and ticks 60 times). `tests/baselines/`: Decision 6.
- `tests/fixtures/`: `catalogue/` (raw documents for ADR-0002 Decision 13), `json/` (data files for the key check), `commands/` (command scripts, ADR-0004). **`tests/lint_fixtures/`**: deliberately broken scripts, scenes and data, one folder per rule (`Lnn/`). It is excluded from the parse check and, by an implicit exclude in the rules-file format, from every L-rule; only the lint self-test scans it.
- `tests/support/`: `spy_stat_accessor.gd`, `spy_fatal.gd`, `dev_error_spy.gd` (a spy `dev_error` sink recording code and cause), `targetable_factory.gd`, `signal_recorder.gd` (`SignalRecorder`, the untyped recording fake of ADR-0006 Decision 14), `snapshot_diff.gd`, `baseline_runner.gd`, `wiring_probe.gd`. Factory functions, minimal signatures: `make_catalogue(overrides: Dictionary) -> Catalogue` (raw documents run through the real validator via `load_parsed()`), `make_command_script(steps: Array) -> Array`, `make_targetable(distance: float, max_hp: int) -> Targetable`. Support classes with a `class_name` are prefixed `Spy`, `Fake`, `Recording` or end in `Probe`, `Runner`, `Recorder`, `Factory`.
- **Pointer-path tests (ADR-0003 delegation):** `tests/unit/input/` holds `pointer_gate_test.gd`, `display_contract_accepts_test.gd` and `input_adapter_read_pointer_test.gd`, covering `PointerGate`, `DisplayContract.accepts` and `InputAdapter.read_pointer`; `tests/support/pointer_event_factory.gd` (`PointerEventFactory`) builds their touch, drag and mouse event fixtures. Only these tests and the adapter name `InputEvent` types (L31 covers the resolver).
- Naming per `.claude/rules/test-standards.md`: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`, `extends GdUnitTestSuite`. Each test builds and frees its own state; a leaked node is exit 101 and fails CI (Decision 3).
- Nothing under `tests/` or `addons/gdUnit4/` is ever loaded by `src/` (L24). The export filter excludes `tests/`, `addons/gdUnit4/`, `tools/`, `prototypes/` (V10; `export_presets.cfg` is untracked).

**3. The test runner script.** `tools/ci/run-tests.sh <dir>` runs one gdUnit4 invocation and fails when the exit code is not 0 (so 100, 101 orphan leak, 103, 104 and 105 all fail; codes sourced at `GdUnitTestSessionRunner.gd:19-24`) or the output contains `No test cases found` (the runner prints it and calls `quit(0)`, `GdUnitTestCIRunner.gd:393-395`). `-a` is registered at `GdUnitTestCIRunner.gd:335` and `--ignoreHeadlessMode` at :345. It prints `ran <N> test cases in <dir>` from the report; an unparseable count exits 2 `NOT ASSESSED`, never 0. A canary suite `tests/unit/harness/harness_canary_test.gd` keeps the unit step non-empty. **The `SCRIPT ERROR` gate applies to the output of the import step and the parse-check step only, not to test runs, and there is no `--strict-errors` mode.** Trade-off: a suite that uses `assert_error().is_push_error()` prints `ERROR:` lines by design, so an output scan would false-fail it; the cost is that a duplicate `connect` (an `ERROR:` line with an unchanged count) is not gated in any test run (Risks). Orphan leaks block because ADR-0001's retry proof depends on nothing being kept alive.

**4. The parse check.** `tools/ci/godot-parse-check.sh` runs `godot --headless --path . -s res://tools/ci/godot-parse-check.gd` and fails when the exit code is not 0 or its output holds any `ERROR:` or `SCRIPT ERROR` line (a GDScript cannot read its own output, hence the wrapper). The script (`extends SceneTree`) walks `res://src/`, `res://tests/` and `res://tools/`, **skipping `res://tests/lint_fixtures/`**, `load()`s each `.gd` and fails when the result is null **or** `can_instantiate()` is false (observed: `load()` is non-null on a parse error). For each `.tscn` under `src/` it reads the `ext_resource path="..."` lines and fails on any path for which `ResourceLoader.exists()` is false (observed: `load()` of a scene with a missing `ext_resource` is non-null and instantiable, so loading the scene is not the check). It prints `parsed <N> scripts` and fails if N is 0 once any `.gd` exists under `src/`. It collects every failure before `quit(1)`. Caught by construction (all three observed in the review probe): a syntax error, an unknown type or class_name missing from the cache, and the **4.7 typed-return override without `return`**; plus a missing `preload` path. The collision check (Decision 9) is in the same script.

**5. The listener-count wiring test (ADR-0006 Decision 10).** `tests/integration/battle/battle_wiring_test.gd`, run in its own CI step (ADR-0006 10(e) has no console-error net here, see Decision 3: a duplicate `connect` leaves an `ERROR:` line and an unchanged count that no step gates; a rejected typed handler cannot occur because the fakes are untyped). It calls `BattleBuilder.build()` with fake callables (ADR-0001 Decision 9), holds every fake and observer in a field for the whole run, and uses `tests/support/wiring_probe.gd` (`class_name WiringProbe`, the only code besides this test allowed to call `get_connections()`; L07). For each signal in `BattleSignals` it asserts: (a) headless connection count equals the `REACTED` count (implied 1) or 0 for `OBSERVED_ONLY`, and each target's class and method match the table; (b) with RunLog and GestureLog attached, each log has at least one connection per signal it consumes; (c) where a scene can be built, each allowlisted view or HUD class has its connections and no battle-signal connection targets a class outside the table; (d) `d["flags"] == 0` on every connection; (e) the declared signals of each emitter, from `get_script().get_script_signal_list()`, equal the `BattleSignals` entries for that emitter. The target class is read with `get_object().get_script().get_global_name()` (observed in the review probe, which closes V7 and ADR-0006's unverified line). Part (c) needs a built wrapper and runs under the gdUnit4 scene runner or the editor-driven suite (V4). **Per-build-configuration wiring:** the wrapper takes its dev flags (RunLog, GestureLog on or off) as a `setup()` argument, not from a feature tag, so the same test builds the dev and the release-shaped wrapper in one process. For resolver signals that carry an id, there is exactly one listener per owner class (ADR-0008 Decision 11); the test builds the wrapper twice in one process, with `dev_telemetry` true and false (ADR-0001 `setup(battle, dev_telemetry)`), each from a fresh `Battle`, and calls `free()` on the first wrapper before building the second (`queue_free()` keeps its connections until the frame ends and doubles the counts). A repeat of the test inside a release export is owed evidence (Decision 11), not a CI step.

**6. Baseline runner and candidate mode.** `tests/support/baseline_runner.gd` (`class_name BaselineRunner`) and `tests/integration/battle/baseline_test.gd`, their own CI step. **Content:** a baseline is the `var_to_str` of an `Array` of `Battle.snapshot()` dictionaries (ADR-0004 Key Interfaces; it includes `rng.state`) taken at each checked tick and at the outcome, with a header line holding os, arch and version; never JSON. ADR-0004 states no further content; anything a bot adds (for example a result record) is ADR-0010's to define. **`bot_id` comes from ADR-0010's bot roster**: `towers-only`, `pinned-once`, `mid-skill`, `ceiling`, `mid-skill-calling`; this ADR fixes the name shape. File: `tests/baselines/<stage_id>_<bot_id>_<os>_<arch>_<major.minor.patch>.txt` with `os` from `OS.get_name()` and `arch` from `Engine.get_architecture_name()`, **both lower-cased as ADR-0004 Decision 12 requires**, and the version from `Engine.get_version_info()`; observed on the dev host: `macos`, `arm64`, `4.7.2` (V2, V3 closed; the CI strings stay to be recorded at first CI run). Rules: (a) a missing baseline **fails** and names the file wanted; (b) a mismatch fails and prints the first differing tick and field path through `snapshot_diff`; (c) **candidate-artifact mode:** when the environment variable `BASELINE_CANDIDATE_DIR` is set, a missing file or a mismatch also writes the snapshot to `$BASELINE_CANDIDATE_DIR/<same file name>` and still fails; CI sets it and uploads the directory as an artifact; **no code path overwrites a committed baseline**, a human copies the candidate in under review; (d) comparison checks `typeof` so an int `rng.state` that came back a float fails. CI hosts: `ubuntu-latest` (linux, x86_64) is the gate; macOS arm64 is the owner's local host; each needs its committed baseline before it may run this step. **arm32 is unsupported:** no baseline exists, the step fails there by rule (a), and the Android export is arm64 only. An Android arm64 device run compares against a candidate file and is owed evidence.

**7. The lint and check catalogue, and its runner.** One runner, `tools/ci/layer-lint.sh` (bash, `grep -E`/`sed`), reads `tools/ci/layer-lint-rules.tsv`, tab-separated, one row per rule: `id`, `kind`, `scope` (comma-separated globs), `exclude` (globs; `tests/lint_fixtures/**` is always excluded), `pattern-or-script`, `source`. `kind` is `grep` (fail on a match of the `grep -E` pattern), `grep-not` (fail when the pattern is absent from a scoped file; used for required `project.godot` keys) or `script` (an executable under `tools/ci/lint/` that prints `path:line: text` per hit and exits non-zero on any). Multi-condition rules are scripts: L02 `extends_ok.sh`, L21 `stored_roster.sh`, L22 `single_writer.sh`, L26 `class_cache.sh`, L32 `sim_writers.sh`, L35 `import_direction.sh`, L36 `field_draw_loops.sh`, L27 `scene_rules.sh`, L28 `json_dup_keys.py`, L29 the parse check. Before matching it strips `#` tails (shortcut: a `#` inside a string literal hides the rest of that line; upgrade to a GDScript tokenizer if it ever causes a miss). Output per rule: `Lnn PASS|FAIL <files scanned> <hits>`; a rule whose scope holds 0 files prints `Lnn SKIPPED 0 files` (never PASS) ; **a SKIPPED rule fails the run unless the allowlist carries an `owed:` entry for it**. `/test-setup` writes `owed: greenfield` entries for rules whose scope is empty, and a stale `owed:` entry (scope now non-empty) fails, so the first story that creates a file in scope removes it. L16 lists its four files; it carries `owed: greenfield` like any rule while its scope is empty, and never an `owed: ADR-0010` entry. Exit 1 on any hit, exit 2 if the rules file cannot be read. **Allowlist:** `tools/ci/layer-lint-allowlist.txt`, one line `Lnn|path|fixed string|ADR-or-story-id|one-line reason`. A new line lands in its own commit, cites the ADR or story, and is reviewed at code review; an entry that matches no hit **fails the run as stale**, so exceptions cannot rot. **Self-test:** `tools/ci/layer-lint-selftest.sh` runs the lint over `tests/lint_fixtures/<Lnn>/` (one violating file per rule) and fails unless every rule fires; it is CI step 2b. These lints are a CI gate, a verdict, not an observation helper. The catalogue (every item an earlier ADR delegated):

| ID | Scope | Rule (fail when found) | Source |
|----|-------|------------------------|--------|
| L01 | `project.godot` | a line `[autoload]` | ADR-0001 D1 |
| L02 | `src/battle/` | [script] `extends` of anything but `RefCounted` or a `class_name` declared in `src/battle/` or `src/data/` (so no Node, Control, Resource, Object) | ADR-0001 D10 |
| L03 | `src/battle/` | `func(`, `func (`, `.bind(`, `bindv(`, `static var` (`static func` stays legal) | ADR-0001 D5, ADR-0005 |
| L04 | `src/` | `assert(` | ADR-0001 D8, ADR-0002 D2 |
| L05 | `src/presentation/`, `src/app/` | `connect(func`, `.bind(`, `bindv(`. Catches single-line `connect(func` only; a multi-line `connect(` with a lambda and a lambda stored in a variable are owed to a `script`-kind rule, and L25 already bans `func(` in `src/presentation/input/` | ADR-0006 D1 |
| L06 | `src/` except `src/battle/` | `.deliver(` | ADR-0006 D4 |
| L07 | `src/` | `get_connections(`, `get_signal_connection_list(`, `get_script_signal_list(`, `get_incoming_connections(` (tests and `tools/` may) | ADR-0006 D10 |
| L08 | `src/` | `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT`, `CONNECT_REFERENCE_COUNTED`, `CONNECT_PERSIST`; and `await` on a battle signal anywhere in `src/` (pattern: `await` followed by a name in `BattleSignals`) | ADR-0006 D1/Verification 14, ADR-0009 |
| L09 | `src/` | a `signal X` and a `func X(` with the same name in one file (inherited clashes: the parse check) | ADR-0006 D1 |
| L10 | `combat.gd`, `targetable.gd`, `health.gd`, `status.gd`, `damage_event.gd` | the words `Enemy`, `EnemyWave`, `TowerSim`, `HeroSim` | ADR-0009 Layer boundary |
| L11 | `src/`, `tools/` | `_physics_process`, `Engine.time_scale`, `physics_ticks_per_second`, `max_physics_steps_per_frame`, `physics_jitter_fix` | ADR-0004 |
| L12 | `project.godot` | any `physics/common/` key | ADR-0004 |
| L13 | `src/` | a global random call, pattern `(^\|[^.[:alnum:]_])(randi\|randf\|randomize\|shuffle\|pick_random\|randi_range\|randf_range)\(`; the dot exclusion means a held `RandomNumberGenerator` call (`rng.randi_range(`) needs no allowlist line | ADR-0004 D10 |
| L14 | `src/battle/` | `randfn(`, `sin(`, `cos(`, `tan(`, `atan2(`, `pow(`, `exp(`, `log(` | ADR-0004 D12 |
| L15 | `src/battle/` | `\bTime\.`, `\bEngine\.`, `\bOS\.` (word boundaries, so `TOWER_POS.x` and `AttackEngine.` do not hit) | ADR-0004, ADR-0005 lint 9 |
| L16 | `src/battle/hero/pin_geometry.gd`, `src/battle/hero_sim.gd` (ADR-0010 Decision 12a), `src/battle/combat.gd`, `src/battle/path_track.gd` (ADR-0009) | Vector2 methods `.length(`, `.distance_to(`, `.normalized(`, `.dot(`, `.length_squared(`, `.distance_squared_to(`, `.direction_to(`, `.lerp(`, `.move_toward(`; a Vector2 operator cannot be grepped and stays a review item. | ADR-0004 D12 |
| L17 | `src/`, `tests/`, `tools/`, `*.json` | an absolute path: `/private/`, `/Users/`, `/tmp/`, `C:\` | invariant (no absolute paths) |
| L18 | `read_context.gd`, `stat_keys.gd` | `static var`, `Callable` | ADR-0005 lint 9 |
| L19 | `src/` | `stat_int("`, `stat_float("`, `stat_int(&"`, `stat_float(&"` (a literal key) | ADR-0005 lint 9 |
| L20 | `src/` except `app_root.gd` | [script] `load_from(` called outside `AppRoot`; no `reload` method name | ADR-0002 D12/Key rules |
| L21 | `src/` | [script `stored_roster.sh`] a `roster()` or `targets()` result assigned to a field: lines starting `var ` at class scope or `self.`. The hole is `_field = x.roster()` inside a method (a field and a local look alike to grep); that case is review and the Guidelines name it | ADR-0009 Risks |
| L22 | `src/` except the owners | [script `single_writer.sh`] a write by anyone but the owner: `\.spawn_id\s*=[^=]` and the same shape for `def_id`, `distance`, `position`, `segment`, `removed` outside `enemy_wave.gd` (ADR-0009:52); `\.health\s*=[^=]` and the same for `status` outside `combat.gd` (the `[^=]` stops `==` from matching); any record field assigned outside `catalogue_builder.gd` | ADR-0009 D1, ADR-0002 D10 |
| L23 | `project.godot` | the six ADR-0003 keys exactly: viewport 540x960, `stretch/mode="canvas_items"`, `stretch/aspect="keep"`, `emulate_touch_from_mouse=true`, `emulate_mouse_from_touch=false` | ADR-0003 D9 |
| L24 | `src/` | `res://tests`, `res://addons/gdUnit4`, `tests/` | this ADR D2 |
| L25 | `src/presentation/input/` | `func(`, `func (` | ADR-0003 D8 |
| L26 | `project.godot` and `.godot/global_script_class_cache.cfg` | [script `class_cache.sh`] every `class_name X` under `src/`, `tests/support/`, `tools/` appears in the cache and the reverse (entries are `"class": &"Name"`) | QQ-13 |
| L27 | `*.tscn` under `src/presentation/` | [script `scene_rules.sh`] no `Camera2D` in the wrapper scene; every `Control` under the HUD `CanvasLayer` has `mouse_filter = 2` except `HudModals`; no HUD `Control` with a `Node2D` ancestor (read from the text format, node `parent=` paths) | ADR-0003 D10 |
| L28 | `assets/data/` | [script `json_dup_keys.py`] repeated JSON key, see below | ADR-0002 Risks |
| L29 | `src/`, `tests/` | [script] a `class_name` that collides with a native class or another project or addon class, in the parse-check script (Decision 9) | ADR-0005 Risks, QQ-16 |
| L30 | `src/data/` | `^extends` of Node, Node2D, Control, CanvasItem, Resource or Object; `static var` (`static func` stays legal) | ADR-0002 D2 (delegated layer lint for `src/data/`) |
| L31 | `src/presentation/input/input_resolver.gd` | [grep] `\bInputEvent\w*` and `\bTime\.` (the resolver names no input-event type and calls no `Time` function) | ADR-0008 Validation 5 (delegating ADR) |
| L32 | `src/battle/` | [script `sim_writers.sh`] single writer: `Tower` fields assigned only in `tower_sim.gd`, `Hero` fields only in `hero_sim.gd`, `_in_command` only in its own sim (same shape as L22) | ADR-0010 D12(b) |
| L33 | `src/battle/` | [grep] the whole words `TowerInput`, `HeroInput`, `RunLog`, `GestureLog` (the battle layer never names the input objects or the logs) | ADR-0010 D12(c) |
| L34 | `src/presentation/telemetry/run_log.gd`, `src/presentation/telemetry/gesture_log.gd` (ADR-0010 Decision 1) | [grep] `(^|[^[:alnum:]_])(OS|Time)\.`, `(^|[^[:alnum:]_])(FileAccess|DirAccess)`, and the whole-word command methods `(^|[^[:alnum:]_])(build|upgrade|pin|burst|start_wave|call_early|start_next_wave)\(` (the leading class is portable to BSD grep, unlike `\b`) | ADR-0010 D12(d) |
| L35 | `src/battle/`, `src/data/` | [script `import_direction.sh`] files under `src/battle/` name no class or path under `src/presentation/` or `src/app/`; files under `src/data/` name nothing under `src/battle/`, `src/presentation/` or `src/app/`; fixture in `tests/lint_fixtures/L35/` | ADR-0006 and ADR-0002 (layer lint) |
| L36 | `src/presentation/field/` | [script `field_draw_loops.sh`] no `draw_colored_polygon`, `draw_arc`, `draw_circle` or `draw_polyline` inside a `for`/`while` body (per-entity loop). A guard, not the gate: it misses a draw inside a helper called from a loop or inside a lambda; ADR-0011 V1's `TOTAL_DRAW_CALLS_IN_FRAME` count is the gate | ADR-0011 Decisions 11 and 13 |
| L37 | `src/presentation/field/` | [grep] `(^|[^[:alnum:]_])(material|z_index|add_child|draw_string)[^[:alnum:]_]`, and `enemy_killed` (a field view sets no material, shader or `z_index`, creates no child per entity, draws no text, and never connects `enemy_killed`). Per-entity `modulate` is not greppable apart from the allowed uniform `modulate`; code review checks it | ADR-0011 Decisions 1, 2, 12 and Must rules |

L28 is `tools/ci/json_dup_keys.py` (`python3 -I`): it loads every `assets/data/*.json` with `object_pairs_hook` and fails on any object that repeats a key, naming file and key; it prints `checked <N> files` and exits 2 if python3 is missing (V11). Fixture `tests/fixtures/json/dup_key.json` must fail it (self-test).

**8. CI order and what blocks.** `.github/workflows/tests.yml` (rewritten by `/test-setup`) runs these steps in order; any failure stops the job and blocks merge. 0 `--import` (output scanned for `SCRIPT ERROR`). 1 parse check (`godot-parse-check.sh`) and collision check. 2 `layer-lint.sh`; 2b `layer-lint-selftest.sh`. 3 `json_dup_keys.py`. 4 unit (`run-tests.sh tests/unit`). 5 integration (`tests/integration`, excluding `battle/battle_wiring_test.gd` and `battle/baseline_test.gd`), then the wiring test. 6 baselines, with `BASELINE_CANDIDATE_DIR` set and the directory uploaded on failure (`if: failure()`). 7 smoke (`tests/smoke`). Cheap static checks come first so a lint failure does not cost a test run. Smoke is blocking: a solo project has no advisory queue that gets read. Manual evidence (Decision 11) does not run in CI; it blocks `/story-done`.

**9. QQ-16: class-name collisions, no prefix.** Decision: **no prefix**. Renaming about 40 classes across nine ADRs to avoid a collision no probe has found costs more than a check (ADR-0005's probe: `ClassDB.class_exists` false for its five names). The parse-check script fails when `ClassDB.class_exists(name)` is true for any project `class_name`, or when `ProjectSettings.get_global_class_list()` names one twice (Godot may already refuse a duplicate at import, so that branch may never fire). **It also fails when the list is empty while any `class_name` file exists under `src/` or `tests/`**: the list is `[]` without an import (observed), so an empty list would otherwise pass over nothing; this makes step 0 (`--import`) a hard dependency. The reserved list is `tools/ci/reserved-names.txt`, seeded with `Clock`, `Flow`, `Combat`, `Battle`, `Catalogue`, `Health`, `Status`, `Targetable`, owned by lead-programmer and changed only with an ADR or a control-manifest edit; a hit means a rename through the ADR that owns the class. Support classes follow Decision 2's prefixes.

**10. QQ-15: GDScript 4.7 pitfalls rules** (carried to `/create-control-manifest`). Required: every override of a typed-return method has an explicit `return` (parse check); every handler is `func on_<signal>(...) -> void`; payload tests use untyped recording fakes that assert `typeof` and enum range (observed: a typed handler rejects a bad argument with a console error and is skipped; `float` into `int` truncates; an out-of-range enum passes); every signal is emitted at least once in a test (a parameter-count mismatch connects with `OK` and fails at the first emit); JSON numbers are `float` (ADR-0002 probe), so integer fields are validated whole before use. Forbidden: lambdas and `bind` in `src/battle/` (L03); relying on a setter firing for a packed-array element write and relying on lambda capture of a mutable local (both from QQ-15's text, not re-probed here, V6; the ban on lambdas in `src/battle/` makes the second moot there). Lint-enforced: only the L03/L05 items; the rest are parse check, tests and review.

**11. Manual-evidence list.** Never CI; each is a file retained in `production/qa/evidence/` (CLAUDE.md: retained, not discarded); files are named `<story-id>_<screen>_<yyyy-mm-dd>[_<device>].png` per ADR-0011 Decision 15, which also owns screenshot capture. Items: the InputAdapter and Control event order; lifecycle notifications; `free()` versus `queue_free()` timing on retry; safe-area values; the catalogue load from an Android export; draw-call and frame-time budgets (architecture.md "What cannot be tested headless"); ADR-0003 device run D1 to D10; ADR-0004 device run V1 to V7; ADR-0001 export probes 1 and 2; the repeat of ADR-0006 probe rows 1 to 8 and of this ADR's probe on a release export; the wiring test inside a release export; every Visual and UI story's screenshot. These are listed as owed in each ADR's Validation and tracked by `/gate-check`; none becomes a test.

**12. Scaffolding scope.** This ADR decides content; `/test-setup` creates the files: the directories, `run-tests.sh`, `godot-parse-check.gd`, `layer-lint.sh` with the rules file, `json_dup_keys.py`, `tests.yml`, the canary suite and the lint fixtures. ADR-0010 supplies the RunLog fake sink (`tests/support/`), ADR-0011 the screenshot capture.

### Architecture Diagram
```
 CI job (ubuntu-latest)              local (macOS arm64)
 0 --import
 1 godot-parse-check.gd  (parse + class collisions)
 2 layer-lint.sh  <- layer-lint-rules.tsv, allowlist     2b layer-lint-selftest.sh <- tests/lint_fixtures/
 3 json_dup_keys.py <- assets/data/*.json
 4 run-tests.sh tests/unit          (gdUnit4, fakes from tests/support)
 5 run-tests.sh tests/integration ; wiring test
 6 baseline_test  <- tests/baselines/<stage>_<bot>_<os>_<arch>_<ver>.txt ; candidates -> artifact
 7 run-tests.sh tests/smoke
 manual: production/qa/evidence/  (device runs, screenshots, release-export repeats)
```

### Key Interfaces
- `tools/ci/run-tests.sh <dir>` exit 0 only if ran N > 0 and clean. `layer-lint.sh [--root <dir>]` exit 0/1/2. `godot-parse-check.gd` exit 0/1.
- `BaselineRunner.compare(stage_id, bot_id, snapshot) -> Array[String]` (empty = match); `WiringProbe.connections(sig: Signal) -> Array[Dictionary]` with keys `target_class`, `method`, `flags`.
- `SignalRecorder`: untyped handlers, `calls: Array[Array]`, asserts argument count, `typeof`, enum range.

### Implementation Guidelines
- Tests must never read the wall clock, a global RNG or a file outside `tests/fixtures`; logic tests call `load_parsed()`, never `load_from()` (L20).
- A new lint rule ships with its fixture in `tests/lint_fixtures/` in the same commit.
- Allowlist entries cite an ADR or story id and a one-line reason, land in their own commit, are reviewed at code review and must never cover a whole directory.
- A committed baseline is never edited by code; a changed baseline lands in its own commit citing the cause.
- Error-path tests inject the recording `DevErrorSink` (ADR-0001 D8); `assert_error().is_push_error()` is used only for the default sink's own test (TR-combat-012).

## Alternatives Considered

### Alternative 1: GDScript-only lint
- **Description**: the layer lint as an `extends SceneTree` script reusing the engine's file API.
- **Pros**: one language; could read the class cache natively.
- **Cons**: slower to write, no ready regex tooling, a parse error in the lint hides the lint.
- **Rejection Reason**: grep-level rules need `grep`; the parse check already covers the GDScript-native checks.

### Alternative 2: Prefix every class name (QQ-16)
- **Description**: `TrFlow`, `TrCombat`, and so on.
- **Pros**: collisions impossible by construction.
- **Cons**: renames nine accepted or proposed ADRs and every GDD reference; uglier call sites.
- **Rejection Reason**: a collision is detectable in the parse check; prevention cost exceeds detection cost.

### Alternative 3: Let CI overwrite a failing baseline
- **Description**: regenerate and commit on mismatch.
- **Pros**: no manual copy.
- **Cons**: the gate can never fail; defeats determinism checking.
- **Rejection Reason**: candidate-artifact mode keeps a human in the loop.

## Consequences

### Positive
- Every delegated check has an owner, an ID and a fixture that proves it fires.
- No runner can report success over zero files or zero tests.
- A fresh clone and CI use the same documented command.

### Negative
- Thirty-one rules in grep need maintenance; comment stripping can miss a hidden pattern.
- Baselines multiply by host; a Godot patch update regenerates all of them.
- The wiring test needs a scene for part (c), which may only run in the editor.

## Risks
- **gdUnit4 passes over nothing.** Mitigation: `run-tests.sh` count, canary suite, `No test cases found` fails.
- **Lint rules go stale or noisy and get muted.** Mitigation: SKIPPED is never PASS, stale allowlist entries fail, the self-test fires every rule.
- **Release export differs from the desktop probe.** Mitigation: owed repeat, Decision 11.
- **A tracked class cache goes stale.** Mitigation: CI `--import`, L26.
- **A duplicate `connect` prints an `ERROR:` line and no step gates it (no strict-errors mode).** Mitigation: the wiring suite has no push_error test, so its step log is clean and a reviewer reads it; the count assertion catches the wiring errors that change a count.
- **`tests.yml` and `CLAUDE.md` drift from this ADR.** Mitigation: gdd-sync edits at acceptance; `tests.yml` is replaced per Migration Plan.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-012: "Logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files" | Decision 2 layout: `tests/fixtures/catalogue/` factories via `load_parsed()`, real files only in `tests/integration/data/`; L20 |
| input-gesture-resolver.md | TR-input-014: "Identical call lists give identical signal logs; tests use a recording fake, not assert_signal; bots call commands directly plus one resolver equivalence test" | `SignalRecorder` in `tests/support/`, Decision 5 and 10; command scripts in `tests/fixtures/commands/` |
| game-state-stage-flow.md | TR-state-013: "Tests can enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when any battle signal has no listener (views on an allowlist)" | Decision 5 wiring test over `BattleSignals`, `WiringProbe`, `snapshot_diff` |
| combat-damage.md | TR-combat-012: "Errors use push_error, asserted with gdUnit4 assert_error().is_push_error() and the push_error report setting on; invariant I checks damage sums" | Guidelines: `assert_error` only for the default sink; setting name is V5; invariant I belongs to Combat stories |
| enemy-wave.md | TR-enemy-014: "A headless content test checks layout rules L1-L14 and wave rules on in-memory records; unit tests use fakes and no scene or files" | Decision 2 layout; content tests in `tests/integration/data/` (ADR-0002 D12); L02, L10 keep units headless |
| tower-system.md | TR-tower-014: "All logic is unit-testable headless with spy accessor, recording fake and fake halted(); the content test enforces tower and gold rows" | `SpyStatAccessor`, `SpyFatal`, recording fake in `tests/support/`; Decision 1 and 3 |

## Performance Implications
- **CPU**: none at runtime; nothing here ships. CI cost: parse check and lint each seconds-scale (unmeasured); baselines run the full bot per host (unmeasured).
- **Memory**: none in the game. **Load Time**: none. **Network**: none.

## Migration Plan
Greenfield, except `.github/workflows/tests.yml`: it exists and uses `godot-gdunit-labs/gdUnit4-action@v1` (Godot 4.7.2, `version: installed`, paths `tests/unit` and `tests/integration`, uploads `reports/`), with no import, lint, parse, JSON-key, wiring, baseline or smoke step. `/test-setup` replaces it with the Decision 8 order, which calls the CLI directly through `run-tests.sh`; keeping the action for the unit and integration steps is possible but it hides the exit code and output that `run-tests.sh` gates on, so it is not used. CLAUDE.md's command differs from `run-tests.sh` by `--path .` and the preceding `--import` step. The entry point and flags are sourced: `-a` at `addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd:335`, `--ignoreHeadlessMode` at :345, the `No test cases found` abort then `quit(0)` at :393-395, and exit codes 0/100/101/103/104/105 at `GdUnitTestSessionRunner.gd:19-24` (godot-specialist review, 2026-11-05). Order: `/test-setup` scaffolds Decision 12; write `layer-lint.sh` and fixtures before the first `.gd` under `src/`; rewrite `tests/README.md` and edit CLAUDE.md per the gdd-sync file; add baselines per host with the first bot story.

## Validation Criteria
1. Self-test: all 37 rules fire on their fixtures; deleting a fixture fails the self-test.
2. Parse check fails on `tests/lint_fixtures/parse_error.gd` kept outside the scanned set via a flag, and on a typed-return override without `return`.
3. `run-tests.sh` exits non-zero on an empty directory.
4. Baseline: a missing file fails and writes a candidate; a committed file is never modified.
5. `json_dup_keys.py` fails `tests/fixtures/json/dup_key.json`.
6. Wiring test fails when `enemy_killed` is wired to Flow instead of TowerSim.
7. The `tests/unit/input/` pointer tests (PointerGate, DisplayContract.accepts, InputAdapter.read_pointer) pass using `PointerEventFactory`; L32 to L37 each fire on their `tests/lint_fixtures/` file.

**Verification table** (all `NOT SOURCEABLE`; none is claimed above except where noted in text):

| # | Claim | Run | Expected |
|---|-------|-----|----------|
| V1 | after `--import`, `get_global_class_list()` lists addon and project classes (empty without import: observed) | print it in the probe after an import | gdUnit4 and `src/` classes both present |
| V2 | closed (observed, `output-review.txt`): `OS.get_name()` and `Engine.get_architecture_name()` lower-cased give `macos`, `arm64`; `OS.get_environment` works headless | repeat on the CI runner at first baseline run | record the Linux strings (expected `linux`, `x86_64`) |
| V3 | closed (observed): `Engine.get_version_info()` has `major`, `minor`, `patch` | none | 4, 7, 2 |
| V4 | gdUnit4 scene runner builds a scene headless | one test | passes under `run-tests.sh` |
| V5 | `assert_error` catches `push_error`; name of the report setting | one test | green; setting recorded |
| V6 | packed-array element write skips setters; lambda local capture | two lines | matches QQ-15 text |
| V7 | closed (observed): `get_object().get_script().get_global_name()` returns the class name | none | class name string |
| V8 | fresh clone, tracked cache, no `--import`: does the parse check pass; does a `uid://` scene reference need the untracked `.godot/uid_cache.bin` | clone to a temp dir, run the parse check and a scene load | decide whether `--import` stays (it stays in CI regardless) |
| V9 | closed (observed): `load()` of a `.tscn` with a missing `ext_resource` returns a non-null instantiable `PackedScene` and prints `ERROR:` lines | none; the parse check reads `ext_resource` paths instead | `ResourceLoader.exists()` false on the missing path |
| V10 | export filter excludes tests, addons, tools | inspect an export | absent |
| V11 | python3 present on the runner | `python3 -I --version` | any 3.x |
| V12 | clean-run `ERROR:` count of `run-tests.sh tests/unit` on a clean checkout | run it and count `ERROR:` lines | exit 0 and only the two `127.0.0.1:0` port lines |

## GDD and Registry Sync at Acceptance

Applied 2026-11-05 at acceptance; items not applied are listed below.

- Not applied: `tests/README.md` and `.github/workflows/tests.yml`: held for `/test-setup`.
- Not applied: CLAUDE.md and `.claude/docs/coding-standards.md` CI command: held; needs the owner's explicit approval.
- Not applied: adr-0004:53 applied in its settled form (L16 names ADR-0009's and ADR-0010's files), not as "needs the file name from ADR-0010".


Edits owed when this ADR moves to Accepted (recorded 2026-11-05 from the drafting sync list; line numbers are as of that date). The CLAUDE.md CI-command edit needs the owner's explicit approval; acceptance does not cover it.


- tests/README.md:1-70: stale text -> rewrite: layout incl. fixtures/, support/, baselines/; command with --path . and the --import step; exit codes 0/100/101/103/104/105 (101 fails CI); run via tools/ci/run-tests.sh; class cache stays tracked
- CLAUDE.md (Testing Standards CI/CD, Godot line): godot --headless -s -d --remote-debug ... -a res://tests --ignoreHeadlessMode -> prepend "godot --headless --path . --import" and add --path . to the run command; cite tools/ci/run-tests.sh
- .claude/docs/coding-standards.md (Engine-specific CI commands, Godot): same edit as CLAUDE.md
- docs/architecture/architecture.md:699 (QQ-13): open -> resolved by ADR-0007 D1: class cache stays tracked, CI runs --import, README rewritten
- docs/architecture/architecture.md:701 (QQ-15): open -> resolved by ADR-0007 D10 (Required/Forbidden list for /create-control-manifest)
- docs/architecture/architecture.md:702 (QQ-16): open -> resolved by ADR-0007 D9: no prefix, collision lint plus reserved-name list
- docs/architecture/architecture.md:575-578: "ADR-0007 lists them as manual-evidence stories" -> "ADR-0007 Decision 11 lists them"
- docs/architecture/adr-0001-*.md:56 Ordering Note: "If ADR-0007 prefixes class names (QQ-16)" -> "ADR-0007 does not prefix class names (QQ-16)"
- docs/architecture/adr-0005-*.md:56: same wording change as ADR-0001:56
- docs/architecture/adr-0006-*.md:293 (Risks, class-name read): add "carried as ADR-0007 V7"
- docs/architecture/adr-0004-*.md:53: "the name of the range-check file" -> L16 needs the pin-geometry file name from ADR-0010
- docs/architecture/tr-registry.yaml: no TR wording change; TR-combat-012 push_error report setting name is open (ADR-0007 V5)
- .github/workflows/tests.yml: exists (gdUnit4-action, tests/unit and tests/integration only); replace with the Decision 8 order via /test-setup
- docs/architecture/adr-0010-*.md (when written): must name the pin-geometry file(s) for lint L16, the bot roster that supplies bot_id for baseline file names, and the RunLog fake sink; applied in the 2026-11-05 fix round (no `owed: ADR-0010` entry)
- docs/architecture/adr-0011-*.md (when written): owns evidence file naming under production/qa/evidence/ and screenshot capture (ADR-0007 D11 no longer names files)
- docs/architecture/adr-0009-*.md:52 (writer-ownership lint): "position, segment" -> covered by ADR-0007 L22; L16 also lists ADR-0009's `combat.gd` and `path_track.gd`
- docs/architecture/adr-0006-*.md:28 and 293: get_script().get_global_name() "unverified" -> observed (prototypes/adr-0007-probe/output-review.txt)
- docs/architecture/adr-0004-*.md:205 area: baselines are lower-cased per D12; no edit, ADR-0007 D6 conforms
- CLAUDE.md edit needs the user's explicit approval; acceptance of ADR-0007 alone does not cover it
