# ADR-0010: Sim/Input Split, Command Result Codes and Dev Telemetry

## Status

Proposed

> TD-ADR: batch review 2026-11-04, CONCERNS; fixes applied.
> Engine specialist validation: not run (no agents spawned for this batch).

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

lead-programmer (draft). Acceptance rests with the user or technical-director.

## Summary

Tower and Hero each mix state that must run headless with input handling that needs a phone, and both take commands that can fail for several ordered reasons. This ADR splits each into a builder-made `RefCounted` sim (`TowerSim`, `HeroSim`) and a wrapper-made input class (`TowerInput`, `HeroInput`), fixes the result enums with `OK = 0` first, makes `TowerSim` the sole owner of gold, adds read-only run counters, proves resolver and direct-command paths equal, and defines the dev-build run log and gesture log writers.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (game logic and file I/O in development builds) |
| **Layer** | Feature and Presentation (sims in Feature, input objects in Presentation) |
| **Knowledge Risk** | LOW for the split and result codes (plain GDScript). MEDIUM for the log writer: 4.4 changed `FileAccess.store_*` to return `bool`. HIGH for the version overall (`VERSION.md`). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/breaking-changes.md` (typed-return override); `docs/architecture/architecture.md` (B8, B9, B10, Data Flow 9, Module Ownership); the 4.7.2-stable class reference for `FileAccess`, `OS`, `JSON`, `Time`, `Engine`, `@GlobalScope`. The 4.4 `store_*` claim for `store_line` is confirmed in the 4.7.2 `FileAccess.xml`. |
| **Post-Cutoff APIs Used** | `FileAccess.store_line(line) -> bool` (return type changed in 4.4). |
| **Verification Required** | See the lists below. Each names the run that settles it. |

Sourced facts (class reference at the `4.7.2-stable` tag):

- Open modes: no append flag exists. `WRITE` truncates an existing file and creates a missing one. `READ_WRITE` does not truncate and puts the cursor at the beginning. `WRITE_READ` truncates. `seek_end(position: int = 0)` moves the cursor relative to the end (doc/classes/FileAccess.xml, `ModeFlags`, `seek_end`).
- A failed `FileAccess.open(path, flags)` returns `null`; the static `FileAccess.get_open_error()` gives the `Error` of the last `open` in the current thread (doc/classes/FileAccess.xml).
- `store_line(line: String) -> bool` appends `\n`, encodes UTF-8, and returns `true` on success. After an error the cursor position is indeterminate (doc/classes/FileAccess.xml).
- `flush()` writes the buffer to disk and protects data if the project crashes; closing flushes; needless flushing costs performance; a `FileAccess` closes when freed (doc/classes/FileAccess.xml).
- On Android and iOS `user://` is "a sandboxed directory in either internal or external storage, depending on the user's configuration" (doc/classes/OS.xml, `get_user_data_dir`).
- `OS.is_debug_build()` is `true` for a debug export template or the editor, `false` for a release template. `has_feature` tag names are case-sensitive (doc/classes/OS.xml).
- `JSON.stringify(data, indent = "", sort_keys = true, full_precision = false) -> String` is static, converts every number to `float`, writes `INF` as `1e99999` and `NAN` as `null` (doc/classes/JSON.xml).
- `Time.get_ticks_msec()` and `get_ticks_usec()` return `int` time since engine start, never negative, 64-bit. `Time.get_unix_time_from_system()` returns UTC Unix seconds as `float` (doc/classes/Time.xml).
- The only hash in the reference is the engine's Git commit, `Engine.get_version_info()["hash"]`. It is not a game build hash (doc/classes/Engine.xml).
- `push_warning(...)` and `push_error(...)` push to the debugger and terminal and do not pause the project (doc/classes/@GlobalScope.xml).
- An override of a typed-return method inherits that return type and needs an explicit `return` (`breaking-changes.md`).

### NOT SOURCEABLE (blocks Acceptance)

- NOT SOURCEABLE: whether `READ_WRITE` creates a missing file (`FileAccess.xml` says so only for `WRITE` and `WRITE_READ`). Run: a device test in the log story that opens a path that does not exist with `READ_WRITE` on each target phone and on the CI runner. The writer's fallback to `WRITE` on a `null` open makes the log correct either way; the run records which branch fires.
- NOT SOURCEABLE: whether a flushed line survives the OS killing the app on Android and iOS. Run: the phone run in Validation Criteria (kill the app after a flush, read the file).
- NOT SOURCEABLE: whether `user://` is writable and findable on each target phone, and how a tester finds and sends `user://run_log.jsonl`. Run: the first phone build; the retrieval route goes in `production/qa/`.
- NOT SOURCEABLE: that `JSON.stringify` with the default empty `indent` emits one line with no newline (`JSON.xml` does not state it), and how an integer such as `3` prints once converted to `float`. Run: the `LogFormatter` unit test pins the text for every record schema (it fails on any `\n`).
- NOT SOURCEABLE: that `res://build_info.json` is packed into an export (`ResourceLoader.xml@4.7.2-stable`: "non-resource files are not exported by default"; `FileAccess.xml` names a `*.json` non-resource filter or Keep File; add `*.json` to the export filter, subject to the JSON-as-Resource question in ADR-0002). Run: the Android export check in the build-hash story; the file is read in an exported build and the build hash shown in a log line. Until it passes the log writes `"dev"` and says so.
- NOT SOURCEABLE: whether a main-thread write stalls a frame on a low-end phone, and by how much. Run: the phone run records the longest frame around a write.
- NOT SOURCEABLE: that a headless `HeroSim`-absent battle (test builder option) ticks without error. Run: the first equivalence story, headless on 4.7.2 in CI.
- NOT SOURCEABLE: the full list of export feature tags (`OS.xml` links to a tutorial outside the class reference). The design uses only `OS.is_debug_build()`, so this does not block, but no other tag may be used until it is sourced.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (tick order, commands between ticks, `to_ticks`); ADR-0008 (resolver signals and the registry); ADR-0009 (`Targetable`, `Combat`, targeting helpers); plus ADR-0001 (injected callables, fatal, `dev_error`, builder options); ADR-0005 (stat accessor); ADR-0006 (signal names and payloads); ADR-0007 (probe, fakes, equivalence harness) |
| **Enables** | ADR-0011 (field views read `slot_state()`, `HeroInput` and `HeroSim`); the Tower, Hero, HUD and first-playable stories |
| **Blocks** | Any Hero or Tower story; the run-log and gesture-log stories |
| **Ordering Note** | Needed before the first Hero or Tower story, because that is where `HeroInput` and `TowerInput` are placed. The launch ID and build hash values are injected by ADR-0001 (TR-hud-006 is ADR-0001's); this ADR fixes where they come from and how the log uses them. The gesture record fields belong to ADR-0008 (TR-input-015); this ADR gives the gesture log its sink and format. The Layer is Core as the architecture table lists it, but the decision also governs Feature classes (`TowerSim`, `HeroSim`) and Presentation classes (the inputs, the logs). |

## Context

### Problem Statement

A battle must run with no scene, no clock and no engine event (principle 1), yet a tower upgrade chip needs real time, a hero aim needs a finger, and the HUD needs to know why a command was refused. If input handling lives inside the sim, bots and tests need a phone. If commands return a bare bool, the HUD cannot say why, and a refusal can leave half a change behind. Gold touches kills, early calls, builds and the HUD; with no single owner it drifts. The first phone tests also need numbers from real people, and no GDD owns writing them down.

### Constraints

- Simulation classes extend `RefCounted`, are made by the Builder, and never reference Presentation (architecture, "Decisions made in this document").
- Commands run only between ticks (ADR-0004). A refusal mutates and emits nothing (B8).
- Tower, Hero and EnemyWave do not reference each other (dependency rule 4). They meet in the Builder through signals and injected callables (B9).
- Wall-clock time is allowed in the shell and never in the sim. Logs cannot change a result and a log failure never raises Fatal.
- Release builds never write a log file.
- No gameplay value in code; costs, rates and cooldowns come from the catalogue through the accessor.

### Requirements

- TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009; TR-hero-001, TR-hero-002, TR-hero-009, TR-hero-012, TR-hero-015; TR-hud-013 (see the table below).

## Decision

### 1. The split

| Class | Kind | Made by | Layer | Headless |
|---|---|---|---|---|
| `TowerSim` | `RefCounted` | Builder | Feature | yes |
| `HeroSim` | `RefCounted` | Builder | Feature | yes |
| `TowerInput` | `RefCounted` | Wrapper | Presentation | built in tests; the wrapper skips it headless |
| `HeroInput` | `RefCounted` | Wrapper | Presentation | built in tests; the wrapper skips it headless |

- The sims hold all battle state: gold, slots, towers, cooldowns for Tower; position, pin, burst state, cooldown, telegraph and counters for Hero. A sim never references an input class, a view or the resolver.
- The input classes change battle state only by calling sim commands. `TowerInput` calls `upgrade`. The HUD logic calls `build` (the arc). `HeroInput` calls `pin` and `burst`. Nothing else mutates a sim.
- `TowerInput` and `HeroInput` extend `RefCounted`, not `Node`, and take time as an argument (`ChipWindow.advance(ms)`, `HeroInput.update()`), so the equivalence tests in section 5 build and drive them headless. This is a decision of this ADR and extends the architecture's wording ("absent headless" means the wrapper does not create them in a headless battle).
- `slot_tapped` and `tower_inspected` are signals on `TowerInput`, not reads on `TowerSim` (B8). They are the only way the HUD learns of a tap.
- `TowerSim` and `HeroSim` reach enemies only through the injected `targets()` callable (B9). They read `halted()`, `in_build()`, `left_handed` and the Hero record ID as injected values.

### 2. Result codes

Result enums are exactly those in B8. Each lists `OK` first and the source assigns it explicitly, so the success value is 0 and does not rely on declaration order:

```gdscript
class_name TowerSim extends RefCounted
enum BuildResult { OK = 0, HALTED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_GOLD }
enum UpgradeResult { OK = 0, HALTED, BAD_SLOT, NO_TOWER, MAX_LEVEL, NO_GOLD }
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult

class_name HeroSim extends RefCounted
enum PinResult { OK = 0, HALTED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE }
enum BurstResult { OK = 0, HALTED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH }
func pin(pos: Vector2) -> PinResult
func burst(pos: Vector2) -> BurstResult
```

Rules every command follows:

1. Check `halted()` first. A halted battle returns `HALTED` and does nothing. Then check state, then geometry, in the order the enum lists after `HALTED`, which is the GDD's order. The first failing check returns its code.
2. Read every stat the command needs (through the accessor, never cached) before the first mutation. If a read fails, the accessor calls the injected `fatal`, the command returns `HALTED`, and nothing is half done.
3. A refusal mutates nothing and emits nothing. A test takes a snapshot before and after.
4. After `OK`, commit state, then emit (principle 4): `gold_changed(current)` then `tower_built(slot_index, tower_id)` or `tower_upgraded(slot_index, level)`; `hero_pinned(position)` or `burst_started(aim_point, telegraph_ticks)`. Payload types are ADR-0006's.
5. Callers compare with `== X.OK`, never by truthiness. Always write the qualified name (`BuildResult.OK`): a bare `OK` inside a named enum is not class scope and resolves to `@GlobalScope` `Error.OK`. Because `OK` is 0, `if result:` is true for every failure.
6. A new failure reason is added at its place in the check order, and no existing member changes meaning. A test per member proves each code is reachable.
7. Callers map each code to feedback; the sim does not carry message text.

### 3. Gold ownership

- `TowerSim` is the only holder of gold. It is one non-negative `int`. No other class stores, caches or recomputes it. The HUD reads `gold()` and listens to `gold_changed`.
- Sources: `starting_gold` (read through the accessor when the battle is built), `enemy_killed(bounty)` from EnemyWave, and the early-call bonus on `wave_called_early(seconds_left)` from Flow. The Builder connects both signals to `TowerSim` (B9; neither source references `TowerSim`). Sinks: `build` and `upgrade` costs.
- A spend that would go below zero returns `NO_GOLD` and changes nothing. The check happens before any mutation.
- Once `halted()` is true, gold freezes: kill and bonus credits are ignored and no `gold_changed` is emitted.
- `gold_changed` is emitted after the value is final, once per change, never on a refusal.
- `early_call_bonus(seconds_left: float) -> int` is pure and stateless. It returns `to_ticks(seconds_left) div to_ticks(rate)`, where `rate` is the Stage record's `early_call_seconds_per_gold`, with integer division. The payout and the HUD's "Call +N" call the same function. `seconds_left` includes the tick on which the next wave starts; the HUD passes `intermission_left * dt` (B9). If `to_ticks(rate)` is below 1 the function reports through `fatal` and returns 0, because dividing by it is a bad read. ADR-0002's validator must also reject such a rate at load, so this branch is a backstop.
- Values (`starting_gold`, costs, `rate`) are data. No gold number lives in code.

### 4. Run counters

- `HeroSim` keeps integer counters for the run: `repins`, `bursts`, `victims`, `kills`, plus `best_victims` and `kills_per_burst: Array[int]`. Each counter's meaning is as the Hero GDD defines it. This ADR fixes only the owner, the type and the access rule. `TowerSim.slows_applied()` is the Tower counter. Combat's counters (`dealt_by_id`, `dealt_by_kind`, `hero_share`) stay in Combat (ADR-0009). `EnemyWave.got_through_by_type()` stays in EnemyWave.
- Counters are read-only to everyone else, update after the state they count is committed, and start at zero in a new battle. A battle is rebuilt for each attempt, so no reset call exists.
- Nothing in the sim reads a counter to decide a result. Bots, the HUD, the run log and Stage Progression read them.

### 5. Equivalence tests

Using ADR-0007's `BattleProbe` and fixtures:

- **Tower and Hero path test.** A fixed script of presses, moves and releases is fed to the real `InputResolver` with `TowerInput`, `HeroInput` and `HudLogic` registered. The matching command list (`build`, `upgrade`, `pin`, `burst` at the same ticks) is run directly on a second battle with the same `(catalogue, stage_id, seed)`. The two snapshots must be equal after every tick, not only at the end. This is the "one resolver equivalence test" of TR-input-014.
- **Never pinned equals Hero absent.** A run in which `pin` is never called is compared with a run built with `HeroSim` absent (a test-only Builder option fixed by ADR-0001). Snapshots must match tick for tick. A bot that never calls `pin` must also leave every Hero counter at zero.
- Bots use only `Battle` commands and never the resolver.
- The tests live in `tests/integration/tower/` and `tests/integration/hero/`.

### 6. Burst button centre

`HudLogic` owns `burst_button_centre() -> Vector2`. `HeroInput` receives it as a method Callable at construction and calls it once, when it registers its disc with the resolver. It never re-reads it. After a resize, `HudLogic` moves the disc through the resolver's `set_centre`. Tests pass a fake Callable that returns a fixed point.

### 7. Dev telemetry

```gdscript
class_name LineWriter extends RefCounted
## Appends one line. Returns false on failure. The real class wraps FileAccess; tests collect lines.
func write_line(line: String) -> bool

class_name NullLineWriter extends LineWriter     # release builds and after a failure
class_name LogFormatter extends RefCounted       # record Dictionary -> one JSON line
func to_line(record: Dictionary) -> String
class_name RunLog extends RefCounted             # record_attempt(snapshot), record_call(call)
class_name GestureLog extends RefCounted         # record(gesture)
```

**Placement.** `RunLog` and `GestureLog` are Presentation classes in a dev-only folder. They take a `LineWriter`, a `LogFormatter` and a clock `Callable`, and they only listen. Only the real `LineWriter` calls `FileAccess`. `LogFormatter` is the only class that calls `JSON.stringify`, so an API change touches one class. No sim class references a log.

**Build gating.** The wrapper receives `dev_logging: bool`, set by AppRoot from `OS.is_debug_build()`. When false it creates no log object and passes `NullLineWriter`. A test with `dev_logging` false asserts the fake writer received nothing.

**What writes when.**

- Attempt record (`RunLog`): one line when an attempt finishes (Won or Lost) or on Retry. A quit attempt leaves no line. Fields are read from the `HudLogic` snapshot taken on the frame after the outcome: towers built, lives, last wave, damage by source and kind, the Hero counters of section 4, `kills_per_burst`, `best_victims`, `got_through_by_type`, and the real seconds to first pin, first build and first burst and from the previous attempt's Retry to this attempt's Start.
- Call record: remembered at `call_early`, written at the next `wave_cleared` or outcome, with `seconds_left`, burst readiness and lives lost in the called wave. Burst state comes from `HeroSim` queries, never through `TowerSim`.
- Gesture record (`GestureLog`): one line when a gesture ends (`tapped`, `ground_tapped`, `drag_ended`, `drag_cancelled`, or `became_idle` after a cancelled press). A press ended by `cancel()` writes classification `cancelled`. The fields (device, insets, timing, travel, winners, classification, `expected_action`, `expected_target`) are ADR-0008's. The log also listens to `tower_upgraded`, `burst_started` (only it counts as a burst) and reads `chip_state()` at tower prompts. The resolver stays clock-free; the clock lives in the log.
- Every line carries `schema_version`, `launch_id` and `build`. The first story fixes key names.
- Time fields use the injected clock Callable. Which `Time` function backs it is left to the story; tests pass a fixed value.

**File handling.**

- The real `LineWriter` opens `user://run_log.jsonl` once per launch with `READ_WRITE` and calls `seek_end()`. If `open` returns `null`, it opens with `WRITE`, which creates the file and is sourced. Either branch then writes lines. It flushes after each line. Lines are written at event boundaries (a few per attempt), so flushing is rare. That rate is an estimate from the event list, not a measurement.
- A `null` open or a `false` from `store_line` switches the log to `NullLineWriter` and raises one `push_warning`. The log never calls `fatal`, and the battle result is unchanged.
- Main thread only. A background writer is rejected for MVP. If the phone run shows a write is a visible fraction of the 16.6 ms frame, lines queue in memory and are written when the phase is not Wave.

**Build hash and launch ID.**

- Build hash: an export step in `tools/build/` writes the game's short Git hash to `res://build_info.json` as `{"build": "<hash>"}`. A run from the editor, with no file, uses `"dev"`. The engine's own hash is logged beside it as `engine`, so the two are never confused.
- Launch ID: made once at boot by AppRoot as `"<unix seconds>-<usec>"` from `Time.get_unix_time_from_system()` and `Time.get_ticks_usec()`. It uses no randomness, so the battle seed is untouched.
- Both are injected into `HudLogic` and the logs by the wrapper (B9). Both are project decisions, not engine behaviour, except the file-in-export question above.

### Architecture Diagram

```
 phone / editor only                          headless-capable
 +-------------------------------+            +------------------------------+
 | InputAdapter -> InputResolver |  signals   | TowerInput    HeroInput      |
 +-------------------------------+ ---------> | (RefCounted, wrapper-made)   |
                                              +-------------+----------------+
                      HudLogic.build ---------+             | upgrade / pin / burst
                                                            v
                                         +----------------------------------+
   EnemyWave.enemy_killed(bounty) -----> | TowerSim (gold, slots)           |
   Flow.wave_called_early(sec) --------> | HeroSim  (pin, burst, counters)  |
                                         +----------------+-----------------+
                                          Result enums (OK = 0 first)
                                          signals after commit
   HudLogic snapshot, signals ---> RunLog --+
   resolver signals --------------> GestureLog --+--> LogFormatter --> LineWriter --> user://run_log.jsonl
                                    (debug builds only; Null writer in release)
```

### Key Interfaces

`TowerSim`, `HeroSim` and their enums as in section 2 and B8. `TowerInput`: signals `slot_tapped`, `tower_inspected`; `chip_state()`. `HeroInput`: `update()`, `aim_state()`, `aim_point()`, `button_press()`, `cooldown_digit()` (B10). `LineWriter`, `LogFormatter`, `RunLog`, `GestureLog` as in section 7. All public methods carry doc comments.

### Implementation Guidelines

- A sim class must extend `RefCounted` and must never reference an input class, a view, the resolver or a log.
- An input class must change battle state only by calling a sim command.
- A command must check `halted()` first, read all stats before mutating, refuse without mutating or emitting, and emit only after commit.
- Callers must compare results with `== X.OK` and must never use a result as a bool.
- Gold must be stored only in `TowerSim`, as a non-negative `int`, and must freeze once halted.
- `early_call_bonus` must stay pure and be the only place the bonus is computed.
- Counters must be written only by their owner and never read to decide a result.
- `FileAccess` must appear only in the real `LineWriter`; `JSON.stringify` only in `LogFormatter`.
- A log must never call a sim command, never raise Fatal, and in a release build must never create or open a file.
- Every log line must carry `schema_version`, `launch_id` and `build`.
- Log code must not read the sim seed or use sim randomness.
- Tests must use a collecting `LineWriter` and a fixed clock Callable.

## Alternatives Considered

### Alternative 1: One Tower class and one Hero class with input inside

- **Description**: Each system is a single scene or node that handles touch and holds state.
- **Pros**: Fewer classes.
- **Cons**: Bots and tests need a scene and a device. The sim result could depend on input timing.
- **Estimated Effort**: Lower at first, higher in tests.
- **Rejection Reason**: Breaks principle 1 (the battle is a plain function of its inputs).

### Alternative 2: Return `bool` or Godot `Error` from commands

- **Description**: Commands report success or a generic code.
- **Pros**: Simple.
- **Cons**: The HUD cannot tell no gold from a bad slot. `Error` codes do not match the GDD's ordered refusals.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: TR-tower-002 and TR-hero-002 require ordered result enums.

### Alternative 3: Bots drive the resolver with simulated touches

- **Description**: Every bot sends `press`, `move`, `release`.
- **Pros**: Exercises the input path every run.
- **Cons**: Slower; needs the input classes in every bot run.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Bots call commands directly (TR-input-014); one equivalence test covers the path.

### Alternative 4: Gold in Flow or a separate Economy class

- **Description**: A shared holder for gold.
- **Pros**: One place for all currencies.
- **Cons**: Adds a module and a reference between Tower and the holder; Flow would need Tower's costs.
- **Estimated Effort**: Higher.
- **Rejection Reason**: TR-tower-008 puts gold in `TowerSim`; the VS currencies own their own state.

### Alternative 5: A background writer thread, or print-only logging

- **Description**: Queue lines and write on a thread, or print to the console.
- **Pros**: No frame stall (thread); no file code (print).
- **Cons**: A thread breaks the single-thread rule and adds shutdown and loss cases. A tester on a phone has no console.
- **Estimated Effort**: Higher (thread), lowest (print).
- **Rejection Reason**: The stall is unmeasured, and print does not meet TR-hud-013. Revisit the thread only if the phone run shows a stall.

## Consequences

### Positive

- The whole sim, both bots and the equivalence tests run headless.
- A refusal can be proven harmless by a snapshot diff.
- The HUD and the early-call payout cannot disagree on the bonus.
- A log failure cannot lose a battle, and release builds write nothing.

### Negative

- Two callers reach `TowerSim` (HUD for `build`, `TowerInput` for `upgrade`) and must be kept in step by the equivalence test.
- `OK = 0` makes a truthiness check wrong in the dangerous direction; it relies on review and a lint-like test.
- Several engine facts must be verified before Acceptance.
- A quit attempt leaves no record, and a flushed last line may be lost if the OS kills the app.

### Neutral

- The gesture log's file name and the harness that prompts testers are left to its story.
- Counter meanings stay in the Hero GDD.

## Risks

- `TowerInput` and `HeroInput` as `RefCounted` may conflict with a view that needs `Node` features. Mitigation: views own the nodes and draw from the input class's reads (`chip_state()`, `aim_state()`); the input classes hold no node.
- A test-only "HeroSim absent" Builder option adds a null branch in `Battle`. Mitigation: ADR-0001 fixes the option; the null branch is exercised only in tests and the equivalence test covers it.
- Append mode, flush or path behaviour differs by platform. Mitigation: the `LineWriter` seam keeps any fix in one class; the phone run is an Acceptance condition.
- A write stalls a frame. Mitigation: the queueing fallback in section 7.
- Log data identifies a device. Mitigation: no personal fields; the device field is model and insets only (confirm in the story).
- A bad `early_call_seconds_per_gold` divides by zero. Mitigation: validator at load plus the backstop in section 3.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| tower-system.md | TR-tower-001: `TowerSim` (builder-made, headless) holds gold, slots, towers and the tick; `TowerInput` (wrapper-made) changes state only through `upgrade` | Section 1 split and the "only through commands" rule |
| tower-system.md | TR-tower-002: `build` and `upgrade` are the only mutation API, run between ticks, return a typed result enum in fixed check order | Section 2 enums and rules 1 to 4 |
| tower-system.md | TR-tower-008: gold is one non-negative integer owned by `TowerSim`, fed by `starting_gold`, `enemy_killed(bounty)` and `wave_called_early`; freezes once halted | Section 3 |
| tower-system.md | TR-tower-009: the early-call bonus is one pure integer function shared by the payout and the HUD | Section 3, `early_call_bonus` |
| hero-system.md | TR-hero-001: `HeroSim` (builder-made, headless) and `HeroInput` (wrapper-only), which changes state only through `pin()` and `burst()` | Section 1 |
| hero-system.md | TR-hero-002: `pin()` and `burst()` run between ticks and return ordered enum codes, state before geometry; a refusal mutates nothing | Section 2 |
| hero-system.md | TR-hero-009: read-only queries and per-run counters (repins, bursts, victims, kills) for HUD, bots, logs, Stage Progression | Section 4 |
| hero-system.md | TR-hero-012: a resolver-driven script and a direct-command script give tick-identical `HeroSim` state; a never-pinned run equals a `HeroSim`-absent run | Section 5 |
| hero-system.md | TR-hero-015: `burst_button_centre()` is owned by the HUD, read once by `HeroInput` at registration, injectable by tests | Section 6 |
| battle-hud.md | TR-hud-013: debug builds append JSON lines to `user://run_log.jsonl` through an injectable sink; a write failure is non-fatal; release builds never write | Section 7 |

## Performance Implications

- **CPU**: Commands run a few times per second at most and do a handful of accessor reads each. A result enum costs nothing. A log write is one string build and one write per event: a few per attempt for `RunLog`, a few per second at most for `GestureLog`. Estimates from the event lists; not measured. The input slice budget is 0.5 ms per frame (architecture, Data Flow 10).
- **Memory**: A handful of integers per sim; one log line at a time, plus the queue if the fallback is used.
- **Load Time**: One file open at launch in debug builds.
- **Network**: None.

## Migration Plan

New code. No migration.

1. Add the enums and command signatures with the first Tower story and Hero story, with the refusal tests.
2. Add `TowerInput` and `HeroInput` after the resolver and the Hud logic exist; add the equivalence tests as each lands.
3. Add the log classes, the fake-writer tests and the build-hash export step in the telemetry story, before the first phone test.

**Rollback plan**: Set `dev_logging` to false; nothing depends on the logs. The split itself has no rollback short of a new ADR, because every Tower and Hero story builds on it.

## Validation Criteria

- Every result code of every enum is reached by a test, and a refusal leaves the snapshot unchanged and emits nothing.
- The resolver-driven and direct-command scripts give equal snapshots on every tick; the never-pinned run equals the Hero-absent run.
- Gold never goes negative, does not change after `halted()`, and the HUD's "Call +N" equals the payout in a test.
- With a fake writer, a scripted attempt yields exactly the lines and fields in the GDD. With `dev_logging` false the writer receives nothing. A writer that returns `false` switches to null with one warning, and the final snapshot equals a run with no log.
- Phone run: lines appear after several attempts, across a relaunch (append), the file can be retrieved, and the longest frame around a write stays inside 16.6 ms.
- Every NOT SOURCEABLE item above has its run recorded in this ADR.

## Related

- ADR-0001 App Lifecycle, Composition Root and Fatal Path (depends on; injects `halted()`, `fatal`, `dev_error`, launch ID, build hash)
- ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism (depends on)
- ADR-0005 Stat Accessor and Read-Context Contract; ADR-0006 Battle Signal Contracts and View Allowlist
- ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint (the probe, fakes and lint used here)
- ADR-0008 Input Resolver Core and Signal Contract (depends on; owns the gesture record fields)
- ADR-0009 Enemy Entity, Roster and Combat API (depends on)
- ADR-0011 Battle Field Rendering and Draw-Call Budget (enabled by this ADR)
- `design/gdd/tower-system.md`, `hero-system.md`, `battle-hud.md`, `input-gesture-resolver.md`
- `docs/architecture/architecture.md` (B8, B9, B10, Data Flow 9)
