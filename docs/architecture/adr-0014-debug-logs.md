# ADR-0014: Debug Logs

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

Two development-build logs are needed for the first phone tests: the gesture log (Input Rule 13) and the human log (`user://run_log.jsonl`, Battle HUD Rule 19). This ADR writes both through an injected `LineWriter`, on the main thread, one JSON line per event, flushed at event boundaries, with failure that disables the log and never touches the battle. Several engine behaviours it depends on are NOT SOURCEABLE, so it stays Proposed until a phone run.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (file I/O in the shell) |
| **Layer** | Presentation |
| **Knowledge Risk** | MEDIUM for the file API (4.4 changed `store_*` return types, per `breaking-changes.md` as quoted in architecture.md); HIGH for the version overall (VERSION.md). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/architecture/architecture.md` (Module Ownership: HumanLog row; Engine Knowledge Gap Summary). `breaking-changes.md` was not re-read for this ADR, so the 4.4 claim is second-hand through architecture.md. The 4.7.2 class reference XML (`FileAccess`, `OS`, `Time`, `JSON`, `Engine`) at the `4.7.2-stable` tag was read for the sourced list below. |
| **Post-Cutoff APIs Used** | `FileAccess.store_*` returning `bool` (4.4; `store_line` confirmed in doc/classes/FileAccess.xml@4.7.2-stable). |
| **Verification Required** | See the NOT SOURCEABLE list below. Each needs a phone run or a test before Acceptance. |

Sourced from the 4.7.2 class reference:

- Open modes: there is no append flag. `WRITE` truncates an existing file and creates a missing one; `READ_WRITE` does not truncate and puts the cursor at the beginning; `WRITE_READ` truncates (doc/classes/FileAccess.xml@4.7.2-stable, enum `ModeFlags`). `seek_end(position: int = 0)` sets the cursor relative to the end of the file (doc/classes/FileAccess.xml@4.7.2-stable, `seek_end`).
- Failed open: `FileAccess.open(path, flags)` returns `null`; the static `FileAccess.get_open_error()` returns the `Error` of the last `open` in the current thread (doc/classes/FileAccess.xml@4.7.2-stable, `open`, `get_open_error`).
- Write: `store_line(line: String) -> bool` appends `\n`, encodes UTF-8 and returns `true` on success; after an error the cursor position is indeterminate (doc/classes/FileAccess.xml@4.7.2-stable, `store_line`).
- Flush and close: `flush()` writes the buffer to disk and protects data if the project crashes; closing flushes automatically; the docs warn that needless flushing costs performance. A `FileAccess` closes when it is freed (doc/classes/FileAccess.xml@4.7.2-stable, `flush`, `close`).
- `user://` location: on Android and iOS it is "a sandboxed directory in either internal or external storage, depending on the user's configuration" (doc/classes/OS.xml@4.7.2-stable, `get_user_data_dir`).
- Build kind: `OS.is_debug_build()` returns `true` for a debug export template or the editor and `false` for a release export template; `OS.has_feature("template")` tells an export template from the editor; `has_feature` tag names are case-sensitive (doc/classes/OS.xml@4.7.2-stable, `is_debug_build`, `has_feature`).
- JSON: `JSON.stringify(data: Variant, indent: String = "", sort_keys: bool = true, full_precision: bool = false) -> String` is static; it converts every number to `float`, writes `INF` as `1e99999` and `NAN` as `null` (doc/classes/JSON.xml@4.7.2-stable, `stringify`).
- Time: `Time.get_ticks_msec()` and `get_ticks_usec()` return `int` time since engine start, never negative, 64-bit; `Time.get_unix_time_from_system()` returns UTC Unix seconds as `float`; `get_datetime_string_from_system(utc, use_space)` returns ISO 8601 (doc/classes/Time.xml@4.7.2-stable, those members).
- Hash: the only hash in the reference is the engine's Git commit hash, `Engine.get_version_info()["hash"]` (doc/classes/Engine.xml@4.7.2-stable, `get_version_info`); it is not a game build hash.

NOT SOURCEABLE (each stays a gap; none is filled from memory):

- NOT SOURCEABLE: whether `READ_WRITE` creates a missing file (`FileAccess.xml` says so for `WRITE` and `WRITE_READ` only).
- NOT SOURCEABLE: whether a flushed line survives the OS killing the app on Android and iOS; needs a phone run.
- NOT SOURCEABLE: whether `user://` is writable and findable on each target phone, and how a tester finds and sends `user://run_log.jsonl`; needs a phone run.
- NOT SOURCEABLE: the full list of export feature tags (`OS.xml` links to the Feature Tags tutorial, which is not in the class reference).
- NOT SOURCEABLE: that `JSON.stringify` with the default empty `indent` emits one line with no newline (`JSON.xml` does not state it); the `LogFormatter` test pins it.
- Settled by decision (see "Build hash and launch ID"): the source of a game build hash and a launch ID.
- NOT SOURCEABLE: whether a write on the main thread can stall a frame on a low-end phone, and by how much.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary; ADR-0002 App Lifecycle and Composition (debug build flag, launch); ADR-0006 Input Adapter and Resolver Integration (gesture records) |
| **Enables** | The first-playable human tests; the Pillar 4 phone test (gesture misses and mis-fires) |
| **Blocks** | The HUD human-log story and the gesture-log harness story |
| **Ordering Note** | Deferrable. It can be written during implementation (architecture.md, Priority). ADR-0002 (build gating of dev features) and ADR-0006 (event timing) feed it. `LineWriter` is declared in ADR-0001. |

## Context

### Problem Statement

Three GDDs need numbers from real people and none owns writing them down. The Pillar 4 gate computes misses and mis-fires from a gesture log. Flow, Tower and Hero ask whether a human pays a cost for calling early, how long a retry takes, and how bursts land. These logs are not saves and must not affect play.

### Current State

No code. The GDD fields:

- Gesture log (`input-gesture-resolver.md` Rule 13), development builds, from a test harness that listens to the resolver's signals: device and insets; down and up position and time (hold duration); maximum travel; press offset from the prompted target's centre; both winners and the rule that chose them; classification; the emitted signal; and the `expected_action` and `expected_target` it prompted. A miss is an expected action with no signal. A mis-fire is a signal for a different action. The resolver stays clock-free.
- Human log (`battle-hud.md` Rule 19), debug builds, one record per finished attempt and one per call. Each record has a launch ID and the build hash. Attempt: towers built, lives, last wave, damage by source and kind, `repins`, burst counters, `kills_per_burst[]`, `best_victims`, got-through by type, and the real seconds to first pin, first build and first burst, and from the previous attempt's Retry to this attempt's Start. Call, written at the next `wave_cleared` or outcome: `seconds_left`, burst readiness, lives lost in the called wave. File `user://run_log.jsonl`. A quit attempt leaves no record. It reads burst state itself, not through Tower. Release builds do not write it.
- Architecture.md assigns `HumanLog` and `GestureLog` to the Presentation layer, each with an injected `LineWriter` (`write_line(line: String) -> bool`), and says the write runs on the main thread.

### Constraints

- The sim never depends on a log (ADR-0001). Logs are shell classes that read `BattleReadModel` and signals.
- Logging must not change a battle result, and a log failure must not raise Fatal.
- Wall-clock time is allowed in the shell and never in the sim.
- Single thread.

### Requirements

- TR-input-006: a development-build gesture log with the Rule 13 fields.
- TR-hud-006: a debug-only `user://run_log.jsonl` with one record per attempt and per call.

## Decision

### 1. Classes

```gdscript
class_name LineWriter extends RefCounted
## Appends one line. Returns false on failure. The real class wraps FileAccess; tests collect lines.
func write_line(line: String) -> bool

class_name NullLineWriter extends LineWriter     # release builds and after a failure
class_name LogFormatter extends RefCounted       # record Dictionary -> one JSON line
func to_line(record: Dictionary) -> String
class_name HumanLog extends RefCounted           # record_attempt, record_call
class_name GestureLog extends RefCounted         # record(gesture)
```

`HumanLog` and `GestureLog` are plain classes. They take a `LineWriter`, a `LogFormatter` and a clock `Callable` (so tests pass a fixed time). Only the real `LineWriter` touches `FileAccess`. The `LogFormatter` is the single place that depends on the JSON API (`JSON.stringify`, sourced above), so a change of API touches one class.

### 2. Build gating

`ShellBuilder` decides. In a release build it passes `NullLineWriter` (or no log object) and no log is created. The engine query that separates the build kinds is `OS.is_debug_build()` (sourced above); the ShellBuilder takes a `dev_logging: bool` input, set by `AppRoot` (ADR-0002), so tests set it directly. A release build must never create `user://run_log.jsonl`; a test with `dev_logging` false asserts that the fake writer received nothing.

### 3. What writes when

- Gesture log: one line per gesture, written when the gesture ends (the `tap`, `ground_tap`, `drag_ended`, `drag_cancelled` or an `idle` after a cancelled press), so all fields are known. A press that never resolves (a pointer cancelled by `cancel()`) writes a line with classification `cancelled`. `expected_action` and `expected_target` come from the test harness that prompts the tester; outside a prompted run they are null.
- Human log, attempt: one line when the attempt finishes (Won, Lost) or on Retry. A quit leaves no line. The fields are read from a `HudLogic` snapshot taken on the frame after the outcome, as the HUD already does for results.
- Human log, call: the call is remembered at `call_early`, and the line is written at the next `wave_cleared` or outcome, with `lives lost in the called wave`.
- Burst readiness comes from `BattleReadModel` (burst state), never through `TowerSim`.
- Timestamps are real seconds in the shell. They use the injected clock `Callable`. The `Time` candidates are sourced above; which one backs it is left to the story.

### 4. File handling

- The real `LineWriter` opens the file once per launch, writes each line followed by a newline, and flushes after each line. Writing at event boundaries means a flush every few seconds at most, not every frame. That rate is an estimate from the event list above, not a measurement.
- Open for append without truncating is required (a tester may run several attempts per launch, and the file survives across launches until sent). No mode appends: `READ_WRITE` does not truncate and starts at the beginning, and `seek_end()` moves to the end (sourced above). Whether `READ_WRITE` creates a missing file is NOT SOURCEABLE.
- A failed open or a `false` from `write_line` switches the log to `NullLineWriter`, records one development warning, and the battle goes on. The log never calls the fatal handler. A failed open returns `null`, with the cause from `FileAccess.get_open_error()`, and `store_line` returns `bool` (sourced above); that is what makes the failure visible.
- Each record includes a launch ID and a build hash (the sources are NOT SOURCEABLE; `Engine.get_version_info()["hash"]` is the engine's commit, not a game build hash; the launch ID needs no sim randomness and must not touch the sim seed).

### 5. Thread

Main thread only. A background writer thread is rejected for MVP (see Alternatives). The risk that a write stalls a frame is unmeasured. The phone test records the longest frame around a write; if a write is a visible fraction of the 16.6 ms frame budget (ADR-0012), lines are queued in memory and written when the phase is not Wave (Build, Intermission, Paused, outcome).

### Architecture Diagram

```
 InputResolver signals --> GestureLog --+
                                        +--> LogFormatter --> LineWriter (real | null | fake)
 HudLogic snapshot, BattleReadModel --> HumanLog --+                 |
                                                                     v
                                                          user://run_log.jsonl (debug builds)
 ShellBuilder(dev_logging) decides real or null writer
```

### Key Interfaces

`LineWriter`, `LogFormatter`, `HumanLog.record_attempt(snapshot)`, `HumanLog.record_call(call)`, `GestureLog.record(gesture)`. Record schemas are the field lists above; the first story fixes key names and a `schema_version` key in every line.

### Implementation Guidelines

- A log class must never be referenced by sim code and must never call a command or a sim method that writes state.
- A log failure must degrade to `NullLineWriter` and must never raise Fatal.
- `FileAccess` must appear only in the real `LineWriter`.
- A release build must not create or open a log file.
- Every line must carry `schema_version`, the launch ID and the build hash.
- Log code must not read the sim seed or use sim randomness.
- Tests must use a collecting `LineWriter` and a fixed clock `Callable`.

### Build hash and launch ID (TR-hud-006)

- **Build hash**: an export step in `tools/build/` writes the game's Git commit to `res://build_info.json` (`{"build": "<short hash>"}`). A run from the editor, where that file is absent, writes `"dev"`. The engine's own hash (`Engine.get_version_info()["hash"]`) is logged beside it as `engine`, so the two never get confused.
- **Launch ID**: made once at boot by AppRoot from `Time.get_unix_time_from_system()` and `Time.get_ticks_usec()` (both cited above), as `"<unix seconds>-<usec>"`. It needs no randomness, so the battle seed stays untouched.
- This settles TR-hud-006. The previous NOT SOURCEABLE line about the source is withdrawn: both sources are project decisions, not engine behaviour.

## Alternatives Considered

### Alternative 1: Engine print or the editor's output only

- **Description**: Print lines and copy them from a console.
- **Pros**: No file code.
- **Cons**: A tester on a phone has no console. The GDDs require a file a tester can send.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Does not meet TR-hud-006.

### Alternative 2: A background writer thread

- **Description**: Queue lines and write on another thread.
- **Pros**: No frame stall.
- **Cons**: Breaks the single-thread rule; needs thread APIs that are NOT SOURCEABLE here; adds shutdown and loss-on-kill cases.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Unmeasured need. Revisit only if the phone run shows a stall.

### Alternative 3: One combined log

- **Description**: One file for gestures and human records.
- **Pros**: One handle.
- **Cons**: The gesture log is high rate and test-harness driven; the human log is per attempt and sent by hand. Different owners and different lifetimes.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Keep them separable. The gesture log's file name is left to its harness story.

### Alternative 4: Log from inside the sim

- **Description**: Systems write their own records.
- **Pros**: Access to private state.
- **Cons**: Breaks ADR-0001; the sim would need a writer.
- **Estimated Effort**: Lower.
- **Rejection Reason**: The read model and counters already expose what the records need.

## Consequences

### Positive

- The same code runs on a phone and in tests with a fake writer.
- A log failure cannot lose a battle.
- Release builds write nothing.

### Negative

- Several engine facts must be verified before Acceptance.
- A quit attempt leaves no record (accepted by the GDD).
- Flushing at event boundaries may lose the last line if the OS kills the app first.

### Neutral

- The gesture log's file name and the harness that prompts testers are left to its story.

## Risks

- Append mode, flush or path behaviour differs on a platform. Mitigation: the phone run is an Acceptance condition; the `LineWriter` seam keeps the fix in one class.
- A write stalls a frame. Mitigation: section 5 fallback.
- A tester cannot retrieve the file. Mitigation: NOT SOURCEABLE; the first phone build documents the retrieval route in `production/qa/`.
- Log data identifies a device. Mitigation: no personal data fields are defined; the device field is the model and insets only (to be confirmed in the story).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-006, Rule 13: gesture log with the listed fields; the resolver stays clock-free | `GestureLog` listens to resolver signals; the clock lives in the log |
| battle-hud.md | TR-hud-006, Rule 19: debug-only `user://run_log.jsonl`, one record per attempt and per call | `HumanLog`, build gating, write-at-boundary rules |
| battle-hud.md | Rule 19: reads burst state itself, not through Tower | Section 3 |

TR IDs are provisional until `/architecture-review` registers them.

## Performance Implications

- **CPU**: One string build and one write per event. Frequency is an estimate of a few per second at most for gestures, and a few per minute for human records. Not measured.
- **Memory**: One line at a time, plus the queue if the section 5 fallback is used.
- **Load Time**: One file open at launch in debug builds.
- **Network**: None.

## Migration Plan

New code. No migration.

**Rollback plan**: Switch `dev_logging` off. Nothing else depends on the logs.

## Validation Criteria

- With a fake writer, a scripted attempt yields the exact set of lines and fields in the GDD.
- With `dev_logging` false, the writer receives nothing.
- A writer that returns `false` switches to null, logs one warning, and the battle's final snapshot equals the run with no log.
- Phone run: lines appear in the file after several attempts, across a relaunch (append), and the file can be retrieved.
- Phone run: the longest frame around a write stays inside the 16.6 ms budget.

## Related

- ADR-0001 Simulation and Shell Boundary (depends on; declares `LineWriter`)
- ADR-0002 App Lifecycle and Composition (`dev_logging`); ADR-0006 Input Adapter and Resolver Integration (event timing); ADR-0010 Tower System (chip commits logged); ADR-0012 Field and HUD Rendering and Performance Budget (frame budget)
- `design/gdd/input-gesture-resolver.md` (Rule 13, Pillar 4 gate P1), `design/gdd/battle-hud.md` (Rule 19)
