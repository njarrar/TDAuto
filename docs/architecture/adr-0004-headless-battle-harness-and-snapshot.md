# ADR-0004: Headless Battle Harness and Snapshot

## Status
Proposed

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
lead-programmer (draft, autonomous run). Pending: technical-director (TD-ADR), godot-specialist, njarrar (project owner, acceptance).

## Summary
Bots, balance gates and every system test need to run a whole battle with no scene, check what each command answered, and compare two battles exactly, but the architecture only says "tests can snapshot a battle, enumerate its systems and inject recording ones" and gives no mechanism. This ADR fixes a scene-free harness (`BattleRig`, a fixture catalogue factory, scripted bots, a command-log replayer, a freed-object check and a wiring check) in `tests/support/`, a per-system `snapshot() -> Dictionary` contract with one plain-data format compared exactly, an injectable tick-slot list for recording systems, and the gdUnit4 run rules (exit codes, orphans, zero-test runs).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (testing) |
| **Layer** | Core |
| **Knowledge Risk** | LOW for the runner (the reference records gdUnit4 6.2.2 running on 4.7.2, with its exit codes). MEDIUM for the suite API and a few engine calls the reference does not cover (H1 to H7) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `current-best-practices.md` ("Command Line", gdUnit4 exit codes 0, 100, 101, 103, 105, `No test cases found`, the first `--import`, `--remote-debug`, `Editor Workflow (4.7)`); `breaking-changes.md` (4.7 typed-return overrides); `deprecated-apis.md`; `.claude/rules/test-standards.md` (naming, `auto_free`) |
| **Post-Cutoff APIs Used** | `@abstract` (4.5) for `BattleBot` and `TickSlot`; 4.7 typed-return rule (each `decide` and `run` override ends in an explicit `return` where it has a return type). gdUnit4 6.2.2 itself is post-cutoff |
| **Verification Required** | Sourced: the run command, the exit codes, "101 also means orphan nodes", "zero tests exits 0". **NOT SOURCEABLE** from `docs/engine-reference/godot/` (all `memory, unverified`): (H1) gdUnit4 ignores non-suite scripts under `res://tests/` (memory: it loads only files that extend `GdUnitTestSuite`); if wrong, move `tests/support/` to `res://tests_support/`. (H2) gdUnit4 suite API names other than `auto_free` (`assert_*`, `await_idle_frame`, scene runner). (H3) `Script.get_script_property_list()` lists a script's member variables by name (section 5 member test); if not, the mutation test alone applies. (H4) `weakref()` of a `RefCounted` reads null at once when the last reference drops, of a `Node` only after the freeing frame; if late, the freed check awaits one frame. (H5) A signal connection holds an object id, not a strong reference, to a `RefCounted` target; if it does hold one, `Battle.dispose()` is required, and the Retry gate already tests that path. (H6) `FileAccess`, `DirAccess` and `Script.resource_path` work under `--headless -s` (token scan, baseline recorder). (H7) The call that names the CPU architecture for the baseline key. Same-machine bit-identical floats across process runs are assumed (the Combat GDD already keeps baselines per architecture) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): `Catalogue.from_data`, `Catalogue.snapshot()`, `CatalogueError`. ADR-0002 (Accepted): the canonical table, `VIEW_SIGNALS`, `HaltLatch`, `Battle.dispose()`, the wiring test of section 3. ADR-0003 (Accepted): `BattleCommand`, `CommandRecord`, `Battle.enqueue`, `apply_queued`, `command_log`, `tick_count`, `DT` |
| **Enables** | Every system story's test evidence; the Pillar 2 bot gates (Hero stories); Tower CI (TR-tower-007); the Retry criterion (Flow); ADR-0005 (its systems implement the snapshot contract here) |
| **Blocks** | The first system story that lists a test (Flow, Enemy and Wave, Combat, Tower, Hero) |
| **Ordering Note** | ADR-0005 is drafted in parallel and defines the per-system state this ADR reads. The contract here is: each battle system implements `snapshot() -> Dictionary` as section 5 states, and ADR-0005 must honour it. ADR-0008 must honour the two builder and wrapper requirements in section 4 and section 10 (a slot list the builder passes to `Battle`, and a scene-free input assembly). Both are listed in the Migration Plan |

## Context

### Problem Statement
Flow Rule 2 and the architecture principles say a battle runs with no scene, so bots and tests measure the game. The GDDs assume tools no document defines. Flow asks "how do tests take a battle snapshot, enumerate its systems and inject recording ones?" (TR-flow-011). Flow criteria 9 and 13 need recording systems A, B, C in tick order. Flow's Retry row needs a snapshot equal to a fresh one and a null `weakref`. Hero criterion 29 compares two runs tick by tick. Hero and Enemy and Wave have a dozen bot gates whose thresholds are "set at the first baseline". Tower criterion 27 runs `peak_alive_ub` in a headless battle. Without one design, each story invents its own helpers.

Three facts shape it. ADR-0003 logs every command as a record with a result code, so a replay can check every answer. The Combat GDD says floats may differ between x86 and ARM, so no result may be compared across architectures. The reference says a gdUnit4 run exits 0 over zero tests and exits 101 on leaked nodes, so an empty run could pass unnoticed.

### Constraints
- A battle is `RefCounted` and needs no scene (architecture principle 1). The harness may not need a `Node` for the simulation.
- No autoloads, no static game state (ADR-0001, ADR-0002). The harness injects everything.
- Gameplay has no `_process`, timers, `await`, wall clock or physics (Flow Rule 4). Test code may `await`; sim code may not.
- Bots use the same command queue as the player (registry `direct_sim_command_from_input`).
- Unit tests do no file I/O and call no external service (`.claude/docs/coding-standards.md`); integration tests may read files.
- Never disable or skip a failing test to pass CI (coding standards).
- gdUnit4 is not installed yet (Open Question A9).

### Requirements
- TR-flow-011: durations become ticks through one `to_ticks`; tests can snapshot a battle, enumerate its systems and inject recording ones.
- TR-tower-007: Tower CI computes `peak_alive_ub` and layout rule L10 and runs in a headless battle.
- TR-hero-005: bots drive `pin` and `burst` through the builder and the queue; one equivalence test passes through the resolver; counters give kills per burst and hero share.
- Carried from ADR-0002 and ADR-0003: the derived wiring test runs here; a Retry test proves the old battle is freed; a replay checks every result code.

## Decision

### 1. Layout and ownership
Harness code is plain GDScript under `res://tests/support/`. It is never imported by code outside `tests/` (forbidden pattern `src_depends_on_tests`). Files are named without a `_test` suffix so the runner does not read them as suites (H1).

```
tests/
  support/        BattleRig, RigOptions, FatalRecorder, FixtureCatalogue, SnapshotTool, TickTrace,
                  Replay, CommandFactory, WiringCheck, FreedCheck, RecordingSlot, SignalTap
  support/bots/   BattleBot (abstract), ScriptedBot, BotProfile
  fixtures/       bot profiles (json), recorded baselines (json), forbidden-token list (json)
  tools/          record_baseline.gd  (a SceneTree script, run with -s)
  unit/<system>/        no file I/O, fixture catalogues built in code
  integration/<system>/ real catalogue files, bots, wrapper tests
```

Test files follow `.claude/rules/test-standards.md`: `[system]_[feature]_test.gd`, `test_[scenario]_[expected]`. The harness owns no game state. Registry: it owns the snapshot format and the replay procedure (section 5 and 6).

### 2. Driving a battle with no scene
`BattleRig` is the one way a test or bot runs a battle. It calls the same entry points as the wrapper: `BattleBuilder.build`, `Battle.enqueue`, `Battle.tick(Battle.DT)`. There is no second path into the simulation.

```gdscript
class_name RigOptions extends RefCounted
var stage_id: StringName
var seed: int                       # injected seed; the only source of randomness
var catalogue: Catalogue            # from FixtureCatalogue or the real loader
var trace_every: int = 0            # 0 = no trace (section 5)

class_name BattleRig extends RefCounted
var battle: Battle
var fatal: FatalRecorder            # the fatal_handler passed to build; keeps every call
static func make(options: RigOptions) -> BattleRig        # build only; emits phase(Build) once (Flow Rule 6)
func send(command: BattleCommand) -> void                 # battle.enqueue(command)
func step() -> void                                       # one tick call: battle.tick(Battle.DT)
func run_ticks(count: int) -> void                        # count tick calls
func run_until(done: Callable, max_steps: int) -> bool    # false at the limit: a TIMEOUT, not a Lost
func drain() -> void                                      # battle.apply_queued(), for Build and Paused
func ticks_for(seconds: float) -> int                     # battle.flow().to_ticks(seconds)
func discard_battle() -> FreedCheck                       # section 9
```

- `step()` and `run_ticks()` call `battle.tick(Battle.DT)` and nothing else (registry `real_delta_tick`).
- Build works without a wrapper. A `tick` call with the clock stopped drains the queue and returns without counting (ADR-0003 section 3), so a bot can send builds and `StartNextWaveCommand` first. Loop limits count calls (`max_steps`), not `tick_count()`, so a bot that never starts the clock ends as a TIMEOUT instead of hanging.
- `ticks_for` is the only way a test turns seconds into ticks (`to_ticks` is the one conversion).
- `run_until` is where timeouts live ("timeouts belong to the harness", Flow). At the limit it returns `false`; the caller fails the test. A TIMEOUT is never read as Lost or Won.
- `FatalRecorder` is a `RefCounted` whose bound method is the `fatal_handler`. It keeps every cause in order, so a Fatal test can assert the first cause is kept (Flow criteria 13, 17, 18) and every other test asserts the list is empty.

### 3. Fixture catalogues
`FixtureCatalogue` builds the plain `Dictionary` that `Catalogue.from_data(data, source_label, on_failure)` takes (ADR-0001), with no file I/O:

```gdscript
class_name FixtureCatalogue extends RefCounted
static func starter_data() -> Dictionary                  # a minimal valid catalogue: one stage, two or more waves, the three tower roles, a hero, a burst, input, options
static func with_value(data: Dictionary, path: Array, value: Variant) -> Dictionary   # a deep copy with one field changed
static func without_field(data: Dictionary, path: Array) -> Dictionary                # a deep copy with one field removed
static func build(data: Dictionary, errors: Array[CatalogueError]) -> Catalogue       # from_data with a collecting on_failure
```

- Fixture values are named constants in `tests/support/`. They are fixtures, not balance (Data GDD: prototype constants are starter fixtures only). A balance test uses the real catalogue, not a fixture.
- The helpers always copy. A test must never change a fixture dictionary in place; `Catalogue.snapshot()` (ADR-0001) proves the catalogue is unchanged after a battle.
- Broken copies come from `with_value` and `without_field`, one per rule row, so "one broken copy per row fails naming it" (Tower criterion 27, Data Rule 7) needs no hand-written data.
- Unit tests use `FixtureCatalogue`. Integration tests may call `CatalogueLoader.load_manifest("res://data/catalogue/manifest.json", ...)` on the real files.

### 4. Enumerating systems and injecting recording ones
`Battle.systems()` returns the systems in tick order (ADR-0002 table). A test can read every system through it and through the typed reads (`flow()`, `tower()` and the rest).

Injecting recording systems needs a seam that does not add a gameplay branch to the builder (Flow Rule 3). Decision: the tick loop of `Battle` runs an ordered list of `TickSlot` objects that the builder passes in; `Battle` itself holds no system-specific tick code.

```gdscript
@abstract
class_name TickSlot extends RefCounted
@abstract func run() -> void              # one slot of architecture 3.1, called once per counted tick

# Battle (constructor shape; the builder is the production caller)
func _init(latch: HaltLatch, slots: Array[TickSlot], systems: Array[RefCounted]) -> void
```

- The builder creates one `TickSlot` per row of architecture 3.1 (StageFlow, WaveSim advance, Status, TowerSim, HeroSim then burst, WaveSim reap) that calls the owning system. The `systems` array is the same objects in tick order, returned by `systems()`.
- `Battle.tick` checks `halted()` before the first slot and between slots (ADR-0003 section 3), then runs `slot.run()`. That check is now testable in isolation: Flow criteria 9 and 13 build a `Battle` directly with `RecordingSlot` objects A, B, C, where B's `on_run` callable latches an outcome or fires the fatal handler, and assert C never runs.
- `RecordingSlot` appends its name to a shared log array and implements `snapshot()` so it can sit in `systems()`. It is a test class and lives in `tests/support/`.
- Tests that need a normal battle use `BattleBuilder.build`. Tests that need recording slots construct `Battle` by hand. Production code never constructs a `Battle` outside the builder.
- `SignalTap` attaches a recording listener to a signal in a system's `VIEW_SIGNALS` only, playing the part of a view (for example `damage_applied`, `attack_fired`, `phase`, `lives_changed`). It never taps a sim-only signal, because ADR-0002 allows at most one sim listener. The wiring check (section 10) always runs on a battle with no taps.

### 5. The snapshot contract and format
**Contract (ADR-0005 must honour it).** Every battle system, and every `TickSlot` owner that sits in `systems()`, implements:

```gdscript
func snapshot() -> Dictionary    # a deep plain-data copy of all state that can change a later tick or a read; tests only
```

Rules for every `snapshot()`:
1. The first key is `"system"`, a `String` naming the class (for example `"WaveSim"`).
2. Values are `bool`, `int`, `float`, `String`, `Vector2`, `Array`, or `Dictionary` with `String` keys. A `StringName` is converted with `String(...)`. No `Object`, `RefCounted`, `Node`, `Callable`, `Signal` or `WeakRef` value, and no instance id.
3. The snapshot is a copy. Changing it never changes the simulation, and taking it changes nothing.
4. Anything that is a set or a map in the system (enemies by `spawn_id`, slots by index) becomes an `Array` in an order the system defines (`spawn_id` ascending, slot index ascending). A `Dictionary` is used only for a record of named fields. Hash iteration order is never relied on.
5. Integers stay `int` and floats stay `float`. `3` and `3.0` are different values.
6. State derived and rebuilt each tick (a per-tick position cache) is left out. Injected references (the catalogue, the accessor, the `HaltLatch`, other systems) are left out. Every other member variable is in the snapshot under its own name, or is named in `const SNAPSHOT_EXEMPT: Array[StringName]` on that system with the reason in a comment. An empty list is written `[]`, as with `VIEW_SIGNALS`.
7. No gameplay code calls `snapshot()` (forbidden pattern `snapshot_in_gameplay`).

**Whole battle.** `SnapshotTool.take(battle: Battle) -> Dictionary` returns:

```
{ "tick_count": int, "halted": bool,
  "systems": [ <system 0 snapshot>, <system 1 snapshot>, ... ] }       # battle.systems(), in tick order
```

`take` fails the test with the path of the first bad value if a system has no `snapshot()` (`has_method`), a value breaks rule 2, or a float is NaN or infinite (NaN never equals itself, so it would hide a difference). It adds no key of its own besides these three, so two snapshots of the same battle are equal.

**Comparing.** `SnapshotTool.diff(a: Dictionary, b: Dictionary) -> Array[String]` returns one line per difference, as `path: a_value != b_value` (for example `systems[2].enemies[5].hp: 12.5 != 12.0`), and an empty array when equal. It walks dictionary keys in sorted order and arrays by index, compares `typeof` first and then values, and compares `Vector2` by component. It does not use `==` on a whole dictionary and does not depend on insertion order (so the result does not rest on how the engine orders or compares dictionaries). Tests assert `diff(...)` is empty, so a failure prints the paths.

**Floats are compared exactly.** The same build, seed and commands on the same machine give the same bits, so any tolerance would hide a real divergence. There is no epsilon in a replay or equivalence test. Stored baselines (section 7) hold only integers and are never compared across architectures.


**Trace.** `TickTrace` (`RigOptions.trace_every`) stores a compact sample (lives, gold, alive count, tower levels, counters) every N ticks. A full snapshot of 48 enemies is about 5 KB (estimate), so a per-tick full trace of a 36 000-tick run would be about 180 MB (estimate); full snapshots are for run ends and short scripts.

**Completeness.** Two tests keep a field from slipping out of a snapshot, derived and not typed by hand:
- *Member test* (H3): for each object in `battle.systems()`, take its script member names; each must be a key in `snapshot()` or be in `SNAPSHOT_EXEMPT`. A new field with neither fails the test with the name.
- *Mutation test*: for each system, drive a command or a tick that changes it, and assert `diff` of before and after is not empty. This holds even if H3 fails.

### 6. Replaying the command log
`Battle.command_log()` returns `CommandRecord` values: `tick`, `kind`, `args`, `result` (ADR-0003). `Replay` rebuilds the commands and checks every answer.

```gdscript
class_name CommandFactory extends RefCounted
static func from_record(record: CommandRecord) -> BattleCommand   # maps kind to class and args to constructor; an unknown kind or wrong args fails the test

class_name Replay extends RefCounted
static func run(log: Array[CommandRecord], options: RigOptions, final_tick: int, max_steps: int) -> ReplayResult
# ReplayResult: battle: Battle, log: Array[CommandRecord], mismatches: Array[String]
```

Procedure:
1. Build a fresh battle with the same stage, seed and catalogue as the original.
2. While `tick_count() < final_tick`: when `tick_count()` reaches a value for the first time, enqueue every record whose `tick` equals it, in log order, using `CommandFactory`. Then `battle.tick(Battle.DT)`.
3. At `final_tick`, enqueue the records with that tick and call `apply_queued()` once.
4. Compare: the replayed log against the original, record by record (`tick`, `kind`, `args`, `result`), so every result code is checked, refused and `HALTED` ones included. Then compare `SnapshotTool.take` of both battles with `diff`.
5. A **stall** is a step that feeds no record and does not advance `tick_count()`, after a step that did the same. It ends the replay with a mismatch (`stalled at tick N`) instead of looping. `max_steps` is a hard second limit.

Why this is faithful: all drains at one `tick_count` value happen with no tick between them, so applying them in one drain in log order is the same. The log holds commands only; `lifecycle_changed` is not logged. A pause changes no state and advances no time (Flow Rule 17, criterion 12), so a replay of a wrapper session gives the same result. The replay never reads the original battle; it reads only the records, which hold no callback (registry `callbacks_in_command_log`).

### 7. Bot scripts
A bot is a decision function that builds commands. It does not run the battle.

```gdscript
@abstract
class_name BattleBot extends RefCounted
@abstract func decide(battle: Battle) -> Array[BattleCommand]   # called once before each tick call; reads only; ends in an explicit return

class_name ScriptedBot extends BattleBot       # driven by a BotProfile
class_name BotProfile extends RefCounted       # typed record read from tests/fixtures/bots/*.json
```

- `BattleRig.play(bot, max_steps) -> BotResult` loops `decide`, `send`, `step` until Won, Lost, Fatal or `max_steps` (TIMEOUT). `BotResult` holds the outcome, lives left, waves cleared, `hero().counters()`, `combat().counters()` and the command log (kills per burst and hero share, TR-hero-005).
- A bot reads only what a view reads (`flow()`, `tower()`, `hero()`, `wave()`, `combat()`) and builds `BuildCommand`, `UpgradeCommand`, `PinCommand`, `BurstCommand` and `StartNextWaveCommand`. It holds no seed and no clock; no choice is random.
- Profiles the GDDs name: mid-skill, pinned once, best single pin, ceiling, towers only, towers only always calling, mid-skill always calling, hero alone slow-only, never pinned (Hero Simulated results and Deferred criteria; Flow Rule 9). `tools/balance-sim/hero_bots.py` is a guide for detail the Hero table leaves out, not a spec. Profile values (re-pin every 3 s, aim error, buy order, call mode) are data in `tests/fixtures/bots/`; seconds become ticks through `ticks_for`. Writing the bots is Hero-story work; bot gates are integration tests (`tests/integration/bots/`).
- **Re-baseline rule (Flow, Deferred "Always-call bot gates"; Enemy and Wave "set at the first baseline").** The python results (for example "Won, 2 lives") do not transfer to the fixed-tick game. Therefore: (a) gates assert the relations the GDDs write (mid-skill at least 4 above towers-only; pinned-once below mid-skill on at least three of four mixed builds; always-call gains at most 2 lives), compared on integers (lives left, waves cleared), never on the python numbers; (b) the first real run writes a baseline, and the thresholds that say "proposed" in the GDDs are then set from it in a GDD edit, not in test code; (c) a stored baseline file is per architecture and holds only integers.
- **Baseline recording.** `tests/tools/record_baseline.gd` (a SceneTree script run with `-s`, as the reference shows for the parse check) runs every profile on every mixed build and writes `tests/fixtures/baselines/<arch>.json` (H6, H7). The regression test `bots_baseline_test.gd` reads the file for the current architecture. **If there is none, the test fails with `NO BASELINE for <arch>: run record_baseline`.** It does not pass, and it does not skip. The relational gates in (a) assert either way, so a new architecture has gates and no stale numbers.

### 8. Determinism rules
1. The only randomness is the injected `seed` in `RigOptions`, passed to `BattleBuilder.build`. MVP waves use none (Enemy and Wave Rule on authored waves). Test code uses no `randi`, `randf`, `randomize` or `shuffle`; a test that needs variety loops over a fixed list of seeds written in the test.
2. Tests read no wall clock, no `Time`, no `OS` tick counters. A test that exercises the chip passes a fake `RealClock` (ADR-0003).
3. Tests call `tick` only with `Battle.DT` (registry `real_delta_tick`).
4. Tests do not depend on each other's order or leave state behind; every test builds its own rig.
5. **Token scan** (`determinism_scan_test.gd`, integration, H6). It reads the source text of the scripts of `Battle`, `BattleBuilder` and every object in `battle.systems()`, and of every `.gd` file in those scripts' directories, recursively, and fails on a token from `tests/fixtures/determinism/forbidden_tokens.json`: `_process`, `_physics_process`, `Time.`, `OS.get_ticks`, `create_timer`, `Timer`, `await`, `randi(`, `randf(`, `randomize(`, `shuffle(`, `pick_random(`. The covered set is derived from the live scripts, so a new system folder is covered at once. A new sim folder that is not under one of those directories is not covered; ADR-0008 names the sim directories, and the story that adds one adds it to the scan. This turns Flow's "checked by code review" lines for Rules 3 and 4 into a test. A seeded `RandomNumberGenerator` instance whose seed comes from the builder is allowed by review only.
6. Replay equality (section 6) and the fresh-versus-retried comparison are the end-to-end determinism checks (Flow Rule 5, Combat "Full determinism").

### 9. Retry, freed objects and orphans
**Retry test (ADR-0002 rule 7, Flow Retry criterion).** `BattleRig.discard_battle() -> FreedCheck` takes a `weakref` of the battle and of each object in `battle.systems()` (with class names), calls `battle.dispose()` as the wrapper does, and clears the rig's reference. `FreedCheck.leaks() -> Array[String]` names every object whose `get_ref()` is not null (H4); the test asserts the list is empty. A local variable in the test that kept the battle would fail it, which is correct. The test then builds a second battle from the same catalogue and seed and asserts an empty `diff` against a never-used fresh battle, an unchanged `Catalogue.snapshot()`, and that the catalogue is the only shared object (Flow, "only the catalogue is shared"). A meta test holds a reference on purpose and asserts the check names it. For the wrapper, `integration/` repeats the check over its `Node` objects; `free()` timing is ADR-0008's.

**Orphans (exit 101).** A rig battle is `RefCounted`, so it makes no orphan. Any test that creates a `Node` must wrap it in `auto_free(...)` (`.claude/rules/test-standards.md`) or give it to the scene runner. gdUnit4 exits 101 when all tests passed and a node leaked (reference). **CI treats 101 as a failure.** A `RefCounted` cycle leaks without any orphan report, which is why the weakref check exists.

### 10. The ADR-0002 wiring tests run here
`WiringCheck` holds the checks as functions that return findings, so a test asserts the list is empty and a meta test breaks a connection and asserts a finding:

```gdscript
class_name WiringCheck extends RefCounted
static func headless(battle: Battle) -> Array[String]            # ADR-0002 section 3: every script signal has a listener unless in VIEW_SIGNALS, at most one; VIEW_SIGNALS names are real; the system count is not zero
static func wrapper(objects: Array[RefCounted]) -> Array[String]   # no allowlist for the resolver, TowerInput, HeroInput, the wrapper
```

- The headless test is `tests/unit/wiring/battle_wiring_test.gd` on `BattleBuilder.build` with a fixture catalogue, with no `SignalTap` attached. The wrapper test is in `tests/integration/wiring/`.
- **Requirement on ADR-0008:** the wrapper builds its input pieces through one function that loads no stage scene and creates no `InputAdapter` or views, for example `InputAssembly.build(battle, catalogue, clock)`, returning the resolver, `HeroInput` and `TowerInput` with their connections. The wrapper calls the same function, so the wrapper test and the hero equivalence test (section 11) test the real wiring.
- **Meta test (Flow Deferred "Listener test"):** a test-only helper removes one connection and the test asserts `headless` names that system and signal; the output is kept (watched failing once). Per-signal argument-type tests (ADR-0002 S3) use `SignalTap` on view signals.

### 11. Content, peak and equivalence tests
- **Tower CI (TR-tower-007).** `peak_alive_ub` and layout rule L10 are computed from the catalogue records by the content test (`tests/integration/content/`, ADR-0001). A second test runs the real starter stage in a headless battle with the mid-skill bot, samples `wave().roster().size()` every tick with `TickTrace`, and asserts the largest value is at most the computed `peak_alive_ub` and at most 48. The computed value is an upper bound, so a larger observed value means the formula or the sim is wrong.
- **Hero equivalence (TR-hero-005, Hero criterion 28, Input Rule 11).** Battle A takes a script as direct commands through `Battle.enqueue`. Battle B takes the same script as `press`, `move` and `release` calls on the `InputAssembly` of section 10. Both then run the same ticks. The test asserts `diff` of the end snapshots is empty and the two command logs agree on `kind`, `args` and `result`. The script is chosen so both paths agree (no clamped pin); the Hero story writes it.

### 12. The runner, CI and the harness's own tests
- gdUnit4 6.2.2 is pinned and committed under `addons/gdUnit4/` so CI does not depend on the Asset Store (4.7 renamed the workspace; the reference says addons install from the Asset Store). `tests/README.md` records the pinned version. This closes Open Question A9 once `/test-setup` has installed it.
- CI order, as the reference gives: `godot --headless --path . --import` first (a fresh clone has no `.godot/` and a run without it exits 1 having run nothing; the first import crashed on exit in 3 of 17 runs on 4.7.x, so CI retries the import once); then the parse check on `tests/support/`; then
  `godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode`.
- **Exit codes.** Only 0 passes. 100 is a failure. 101 (orphan nodes or warnings) is a failure. 105 (a script does not parse) and 103 (`--ignoreHeadlessMode` missing) are failures. 1 is a failure.
- **Zero tests is not a pass.** The runner exits 0 with `No test cases found`. CI fails the step when that text appears, and `tests/unit/harness/canary_test.gd` (one trivial passing test) must always exist so the count is never zero. The two expected `ERROR:` lines about the remote port are filtered by exact text, not by pattern.
- **Meta tests (`tests/unit/harness/`)** keep each check known to fail, because a gate not watched failing is not a gate (`.claude/rules/skill-authoring.md`): `diff` reports a doctored field and an int-versus-float change; `take` rejects an `Object` value and a NaN; `Replay` reports a doctored result code, an unknown kind and a stall; `FreedCheck` names a deliberately held reference; `WiringCheck` names a removed connection; the token scan flags a planted token in a fixture script; the member test flags a field left out of a snapshot.

### Architecture Diagram

```
tests/unit, tests/integration  (gdUnit4 suites)
        |
   BattleRig --------------------------------------------------------------+
     | make()          | send()/play(bot)         | step()                    | discard_battle()
     v                 v                          v                           v
 BattleBuilder.build   Battle.enqueue(BattleCommand)   Battle.tick(DT)     FreedCheck (weakrefs)
  (catalogue from       |                              |  slots: TickSlot[]
   FixtureCatalogue)    +--> command_log()-> Replay    +--> systems() in tick order
                              (CommandFactory,                 |
                               every result code)              +--> each system.snapshot()
                                                                      |
                                              SnapshotTool.take / diff   WiringCheck
```

### Key Interfaces
Test side: `BattleRig`, `RigOptions`, `FatalRecorder`, `FixtureCatalogue`, `SnapshotTool`, `Replay`, `CommandFactory`, `WiringCheck`, `FreedCheck`, `RecordingSlot`, `SignalTap`, `TickTrace`, `BattleBot`, `ScriptedBot`, `BotProfile`. Production side: `snapshot() -> Dictionary` and `SNAPSHOT_EXEMPT` on each battle system, `TickSlot`, `Battle._init(latch, slots, systems)`.

### Implementation Guidelines
- Tests must drive a battle only through `BattleRig` or its three entry points: `BattleBuilder.build`, `Battle.enqueue`, `Battle.tick(Battle.DT)`.
- Tests and bots must never call `build`, `upgrade`, `pin` or `burst` on a system; they must enqueue a `BattleCommand`.
- Tests must never pass a frame delta to `tick`, read engine time or use a random function; the seed comes from `RigOptions`; seconds become ticks only through `ticks_for`.
- Every battle system must implement `snapshot()` under section 5 and declare `SNAPSHOT_EXEMPT`, even when empty. A snapshot must never hold an `Object`, a `Callable`, an instance id or a NaN.
- Snapshots must be compared with `SnapshotTool.diff`, never with `==` on a whole dictionary, and never with a float tolerance in a replay or equivalence test.
- A run loop must have a `max_steps` limit, and a TIMEOUT must fail the test; it is never read as Lost.
- A test that creates a `Node` must wrap it in `auto_free` or the scene runner; CI must treat exit 101 as failure.
- A baseline must hold only integers, be stored per architecture and fail when missing.
- Production code must never import from `tests/`, and gameplay code must never call `snapshot()`.
- Every harness check must have a meta test that shows it failing.

## Alternatives Considered

### Alternative 1: One `Battle.snapshot()` compared with `==`
- **Pros**: Least code.
- **Cons**: `Battle` must know every system's fields; dictionary equality and order rest on engine behaviour the reference does not cover; a failure says only "not equal".
- **Rejection Reason**: Per-system snapshots keep state next to its owner (ADR-0005), and `diff` prints a path.

### Alternative 2: Reflection snapshot (copy every property)
- **Pros**: Cannot forget a field.
- **Cons**: Needs reflection the reference does not cover (H3); copies injected objects and caches; the snapshot content is then nobody's decision.
- **Rejection Reason**: Reflection is used only to check completeness, with a mutation test as fallback.

### Alternative 3: A test flag in the builder, or test subclasses of `Battle`
- **Pros**: No new seam.
- **Cons**: A gameplay branch in the builder, which Flow Rule 3 bans; a flag production could set by mistake.
- **Rejection Reason**: A `TickSlot` list passed to the constructor adds no branch.

### Alternative 4: Replay compared by final state with a float tolerance
- **Pros**: Tolerates drift.
- **Cons**: Hides a mid-battle divergence that later cancels out; a tolerance can hide a real defect.
- **Rejection Reason**: Exact comparison on one machine, with per-record result codes, finds the first divergence.

### Alternative 5: A scene-based harness
- **Description**: Tests drive the wrapper with the scene runner and real frames.
- **Pros**: Tests the wrapper path as shipped.
- **Cons**: Slow, frame-timed, and bots would run in real time.
- **Rejection Reason**: Kept only for the wrapper and Retry integration tests. Bots and system tests use the scene-free rig.

## Consequences

### Positive
- One way to run a battle for humans, bots and tests; the same three entry points as the wrapper.
- A replay checks every result code, so a divergence shows at the first wrong command.
- Snapshot failures print a path, and completeness is checked by test, not by memory.
- Recording systems can be injected with no gameplay branch in the builder.
- A leaked battle is named; an empty gdUnit4 run and exit 101 cannot pass.
- Every check has a meta test that shows it failing.

### Negative
- Each battle system carries a `snapshot()` and a `SNAPSHOT_EXEMPT` list, and a duty at every new field.
- `Battle` gains a `TickSlot` list, a small change to its architecture shape.
- About a dozen small support classes to keep; baselines must be recorded once per architecture.
- The token scan does not cover a sim folder outside the derived directories.

## Risks
- **ADR-0005 does not honour the snapshot contract.** Mitigation: the contract is stated here and in the Ordering Note; the member and mutation tests fail the first story that skips it.
- **ADR-0008 does not give the `InputAssembly` seam or builds `Battle` differently.** Mitigation: both are listed as requirements; if refused, the wrapper test and the hero equivalence test run against the wrapper with a scene runner, slower but valid.
- **Accessor read log and "HeroSim absent" (Hero criterion 29).** The criterion compares an accessor read log and a battle built without HeroSim. ADR-0001 defines no read-log hook on `StatAccessor`, and the builder has no way to omit HeroSim without a gameplay branch. This ADR does not decide either. Both go to the Hero story and to ADR-0001 and ADR-0008 follow-ups; until then criterion 29 is only partly testable (per-tick lives, gold, enemies, towers and the `deliver` and `attack_fired` logs through `SignalTap`).
- **gdUnit4 skips or rejects the support files (H1).** Mitigation: move them to `res://tests_support/`; no other change.
- **Float drift across process runs on one machine (assumed none).** Mitigation: the first CI run executes the replay test twice in two processes; a difference reopens section 5 (a tolerance is then a decision for a new ADR, not a quiet edit).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-flow-011 and Open Question "snapshot, enumerate systems, inject recording ones" | `snapshot()` contract and `SnapshotTool` (section 5), `systems()` in tick order, `TickSlot` and `RecordingSlot` (section 4); `ticks_for` uses `to_ticks` |
| game-state-stage-flow.md | Rule 2: a battle runs with no scene; Rule 5: same stage, seed and script give an identical result | `BattleRig` (section 2), `Replay` (section 6), determinism rules (section 8) |
| game-state-stage-flow.md | Deferred: Retry (snapshot equal to fresh, `weakref` null, only the catalogue shared); Listener test (watched failing); Always-call bot gates re-baselined on the fixed tick | Section 9; section 10 meta test; section 7 re-baseline rule |
| game-state-stage-flow.md | Dependencies: "timeouts belong to the harness" | `run_until` and `max_steps` (section 2) |
| tower-system.md | TR-tower-007 and criterion 27: Tower CI computes `peak_alive_ub` and L10 in a headless battle; one broken copy per row | Section 11; `FixtureCatalogue.with_value` and `without_field` |
| hero-system.md | TR-hero-005: bots through the builder and queue; one equivalence test; counters give kills per burst and share | Sections 7 and 11 |
| hero-system.md | Simulated results table and Deferred bot rows; criterion 29 (never pinned) | Bot profiles as data; relational gates; criterion 29 partly covered, gaps named under Risks |
| enemy-wave.md | Deferred criteria: thresholds set at the first baseline; Retry; Listener test; "seams the criteria assume ... the snapshot" | Section 7 baseline rule; sections 9 and 10; sections 4 and 5 |

## Performance Implications
- **CPU**: Tests only. A full snapshot of 48 enemies is estimated at about 5 KB (estimate, proposed). A 36 000-tick bot run is 36 000 `tick` calls plus bot reads; the sim target is 2 ms per tick (ADR-0003). The CI time budget for the bot suite is set at the first baseline.
- **Memory**: Compact trace samples; a full per-tick trace of a 10-minute run is about 180 MB (estimate) and is not allowed. No harness object exists in release.
- **Load Time**: A few small classes (`snapshot()`, `TickSlot`); none runs at load.
- **Network**: None.

## Migration Plan
No code exists yet. **These edits land in the same change that marks this ADR Accepted:**

- `docs/architecture/architecture.md`: Required ADRs, ADR-0004 row: Layer `Foundation` becomes `Core`, and the Decision cell adds the `snapshot()` contract, `TickSlot`, the replay and the exit-code rules. 3.1: the six tick rows are `TickSlot` objects built by the builder. 4.3: `Battle._init(latch, slots, systems)` and the `TickSlot` class. 4.3 to 4.5: `snapshot()` and `SNAPSHOT_EXEMPT` on StageFlow, Combat, WaveSim, TowerSim and HeroSim. Open Questions A9 (closed once `/test-setup` installs gdUnit4 6.2.2) and M7's snapshot question (closed).
- `design/gdd/game-state-stage-flow.md`: the Open Questions row on snapshot, enumeration and recording systems marked answered by ADR-0004.
- `design/gdd/enemy-wave.md`: the Deferred row "Seams the criteria assume ... and the snapshot" marked answered for the snapshot (other seams stay with ADR-0008).
- `design/gdd/hero-system.md` criterion 29: a note that the accessor read log and the HeroSim-absent build need hooks not yet decided (see Risks).
- ADR-0003 (Accepted): a cross-reference note, not a change of decision, that the slot loop runs `TickSlot` objects (section 4). ADR-0002 (Accepted): a note that `WiringCheck` implements its section 3 tests.
- `tests/README.md`: the layout (`tests/support/`, `fixtures/`, `tools/`), the pinned gdUnit4 version and the exit-code rules.
- `docs/registry/architecture.yaml`: registered with this ADR's write, as Proposed stances.

## Validation Criteria
- A smoke test builds a battle from `FixtureCatalogue.starter_data()`, runs 100 steps with no scene, and sees `phase(Build)` once and no Fatal.
- A Build-phase test sends a `BuildCommand` and calls `step()` with the clock stopped: the tower is built and `tick_count()` is 0.
- A replay of a scripted battle gives no mismatch and an empty snapshot `diff`; a doctored result code is reported by record.
- `diff` treats `3` and `3.0` as different; `take` rejects an `Object` value and a NaN.
- Every system passes the member and mutation tests; a field deleted from one `snapshot()` fails the member test by name.
- Flow criteria 9 and 13 pass with `RecordingSlot` A, B, C.
- The wiring check is empty on a normal battle and names the system and signal after `without_connection`.
- The Retry test finds no leak after `dispose()`; a deliberately held reference is named.
- A planted forbidden token fails the token scan; the real sim directories pass.
- The full gdUnit4 run exits 0; a planted leaked `Node` exits 101 and CI fails; an empty run is failed by the `No test cases found` rule.
- The mid-skill peak sample is at most `peak_alive_ub` and 48 on the starter stage.
- The first bot baseline is recorded per architecture, and the "proposed" thresholds in the Hero and Enemy and Wave GDDs are set from it.

## Related
- Architecture: `docs/architecture/architecture.md` 3.1, 4.3 to 4.5, Required ADRs (ADR-0004 row), Technical Requirements Baseline (TR-flow-011, TR-tower-007, TR-hero-005), Open Questions A9 and M7, Gate Findings GF2.
- ADR-0001, ADR-0002, ADR-0003 (all Accepted). ADR-0005 (parallel; must honour section 5). ADR-0008 (the `InputAssembly` seam and the builder passing `TickSlot` objects).
- GDDs: `game-state-stage-flow.md` (Rules 2, 4, 5, 6, 9, 17; CI criteria; Deferred criteria; Open Questions), `hero-system.md` (Simulated results; Deferred criteria; criteria 28, 29), `tower-system.md` (criteria 27, 28), `enemy-wave.md` (Deferred criteria), `combat-damage.md` (determinism; x86 and ARM), `input-gesture-resolver.md` (Rule 11).
- Engine: `docs/engine-reference/godot/current-best-practices.md` ("Command Line, Tests and Parse Check"); `.claude/rules/test-standards.md`; `.claude/rules/skill-authoring.md` (obligations 1, 4, 5 and the watched-failing rule).
