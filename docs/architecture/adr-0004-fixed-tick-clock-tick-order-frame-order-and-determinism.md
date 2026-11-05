# ADR-0004: Fixed-Tick Clock, Tick Order, Frame Order and Determinism

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer; reviews by godot-specialist and technical-director (TD-ADR) follow.

## Summary
The battle must advance only through `Battle.tick(dt)` at a fixed rate, in one order, with commands between ticks and every random draw reproducible from a seed, while the views and HUD run on real time and keep running after the battle clock stops. This ADR fixes a 60 Hz accumulator `Clock` (a `RefCounted` in the presentation root) driven from the wrapper's `_process` with a cap of 2 ticks per frame whose excess time is dropped, the six-slot tick order, commands applied immediately from the input call stack, a single seeded RNG owned by `Battle` that no MVP system reads, a float policy with per-architecture baselines, `to_ticks` as round-half-away-from-zero, and a gated frame delta for every view clock.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; installed 4.7.2.stable.official) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (architecture table). The decision uses only `Node._process`, `RefCounted`, `Callable`, `RandomNumberGenerator`, `roundi`, `Time` and `Engine` property reads, none of which appears in `breaking-changes.md` or `deprecated-apis.md` for 4.4 to 4.7. The semantics of `_process(delta)`, the physics-step settings and cross-platform float behaviour are not in the local reference; each is listed under NOT SOURCEABLE and nothing below rests on it. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/physics.md` (Jolt default in 4.6 is irrelevant: this project uses no physics body, area or query, and no `_physics_process`), `modules/input.md` (section Verified on 4.7.2). The live 4.7 class reference was **not** consulted. |
| **Post-Cutoff APIs Used** | None. Code under this ADR must never override a method with a typed return without an explicit `return` (4.7 break). |
| **Verification Required** | (1) Device run (shared with ADR-0003 D1): input events of a frame arrive before that frame's `_process`, so a command is applied before that frame's ticks. (2) Device run: log `Clock.is_ticking()` whenever a lifecycle notification reaches the adapter; it must always be false (Decision 9). (3) Measure per-tick cost at the worst-case entity count and the whole frame split of Decision 12 on an Adreno 5xx-class device (QQ-11); set `MAX_TICKS_PER_FRAME` from it. (4) Run `prototypes/adr-0004-probe/probe.gd` on an Android and an iOS build and on an x86 desktop; compare against the ARM column of the observations below. (5) Record the first-frame `delta` and the `delta` after a resume from the background on a device (NOT SOURCEABLE below). (6) `Time.get_unix_time_from_system()` returns a float on a device. |

Probe results on the installed 4.7.2 binary (debug build, macOS arm64 host; `prototypes/adr-0004-probe/probe.gd`, run 2026-11-05 with `/Applications/Godot.app/Contents/MacOS/Godot --headless --path <folder> -s res://probe.gd`, twice, the two outputs identical apart from the time line):

| Behaviour | Observed |
|---|---|
| `RandomNumberGenerator`, `seed = 12345`, first ten `randi()` | `1321476956, 17539747, 3348728241, 2863338820, 85463406, 1024873269, 4179236141, 1040420088, 2363282938, 1603148953`. A second instance with the same seed gave the same ten, and a second process run gave the same ten. This shows repeatability on this one binary and host only. |
| `seed = 0`, first `randf()`, then `randi()` | `0.20227184891700745`, then `692503688`. Seed 0 is a usable seed; it did not degenerate. |
| GDScript `float` | 64-bit: `1.0 / 3.0` printed `0.33333333333333331` (17 digits). |
| `Vector2` component | 32-bit: `Vector2(1.0 / 3.0, 0.0).x` printed `0.33333334326744080`. Matches the ADR-0002 probe (single precision, 2026-11-05). |
| `roundi` | `roundi(0.5)` 1, `roundi(-0.5)` -1, `roundi(2.5)` 3, `roundi(-2.5)` -3: halves go away from zero. |
| `to_ticks` at `dt = 1.0 / 60.0` | 0.9 s gives 54, 5.0 s gives 300, `dt` gives 1, 0 gives 0. `3 * 0.1 / dt` is `18.00000000000000355`: round gives 18, floor 18, **ceil 19**. This reproduces the Enemy & Wave GDD's reason to reject `ceil`. |
| `Engine` defaults | `physics_ticks_per_second` 60, `max_physics_steps_per_frame` 8, `time_scale` 1.0. Values only; no semantics are claimed and none is used. |
| `Time.get_unix_time_from_system()` | Returned a float (`typeof` 3), 1793863608.934 at the run. `get_ticks_usec()` read twice back to back gave the same value, so it is not a per-call clock to rely on at that scale. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted: the wrapper that holds the Clock, `Battle`, `build()`, `stop_clock()`, teardown), ADR-0003 (Proposed; **provisional premise**: input is flushed before `_process` on desktop; the device confirmation, D1 and D3, is owed and a failure reopens Decision 3). |
| **Enables** | ADR-0005 (a bad accessor read is a `fatal()`, which the tick slots check), ADR-0006 (signals are emitted synchronously inside the slots of Decision 2), ADR-0007 (the harness drives `tick` and the baselines), ADR-0009 (EnemyWave `advance` and `reap` slots), ADR-0010 (commands run between ticks; RunLog flush is driven by `advance`), ADR-0011 (frame-clock rule for views). |
| **Delegates To** | ADR-0006: signal names and payloads, including the type of `phase_changed`'s value that the wrapper reads to detect Paused. ADR-0007: the harness, the baseline test runner, the snapshot-equality runner and the lints named below (no `_physics_process`, no `Vector2` method in PinGeometry, no `randi`/`randf`/`randomize` global call under `src/`). ADR-0009: the enemy reap internals and the roster ordering `advance` and `reap` use. ADR-0010: command result codes, the RunLog schema (it records the seed and the attempt index) and RunLog's flush on `advance`. ADR-0011: the hero view's outcome rows on the frame clock (TR-hero-016's last clause), the Combat view's `ClearanceWindow` class design, the redraw key. |
| **Blocks** | Every Game State & Stage Flow story that touches the tick (Clock, Pause, Fatal), the first Enemy & Wave, Tower and Hero stories (they need the tick order), the bot baselines. |
| **Ordering Note** | ADR-0002's schema floor `MIN_INTERVAL_SECONDS` is a local copy of `1/60` until its code references `TickRate.DT` (Decision 2); the Hero telegraph row and the wave "strictly increasing spawn ticks" row land with it. ADR-0003 must stay Proposed or become Accepted; this ADR becomes provisional again if D1 or D3 fails. `MAX_TICKS_PER_FRAME` is provisional until Verification item 3. |

## Context

### Problem Statement
The GDDs require a battle that is a pure function of `(catalogue, stage_id, seed, command script)` (Flow Rules 4 and 5), so simulation time, order, command timing and randomness must be fixed in one place before any system is built. The same ADR must keep the real-time layer (HUD, view effects, the 0.15 s clearance tail, Won's 0.4 s beat) running after the battle clock stops, and settle the handful of engine-facing choices the earlier ADRs delegated: the tick driver, the cap, the pause behaviour of the clock, when a lifecycle notification can land, where the seed comes from, and `to_ticks`.

### Constraints
- Gameplay classes are `RefCounted`, never read `Engine`, `Time`, `OS`, a `Timer` or `await`, and have no `static var` (ADR-0001). Time therefore enters only as an argument to `tick(dt)`.
- GDScript has no exceptions and a failing function finishes on a garbage value; the tick must check `halted()` between slots (ADR-0001 Decision 6).
- The pinned engine reference does not document `_process`/`_physics_process` delta semantics or the physics-step settings (NOT SOURCEABLE).
- Frame budget 16.6 ms at 60 fps with a 30 fps floor on low-end Android; the ticks' slice is 4.0 ms, unmeasured (QQ-11). Combat's worst case is estimated under 2 ms per tick, unmeasured.
- Solo developer, workflow `full`: every rule here must be checkable by a test or a lint.
- Input is flushed at frame start before `_process` on desktop (ADR-0003 spike), unconfirmed on a device.

### Requirements
- One way in for sim time, a fixed tick, a documented single order, commands only between ticks (TR-state-003, TR-state-004, TR-combat-009).
- All randomness from an injected seed; same stage, seed and script give an identical result (TR-state-005, TR-enemy-007).
- Authored durations become whole ticks through one conversion; countdowns are integer tick counters (TR-state-012, TR-enemy-002, TR-tower-005).
- Pause stops the clock with no time jump on resume; walk and telegraph resume exactly (TR-state-007, TR-hero-013).
- Wrapper-side timers, button arming, the chip window and view clocks run on the frame clock outside the sim (TR-state-014, TR-hud-007, TR-tower-010, TR-hero-011).
- Each frame runs commands, then real-time models, then ticks, then views (TR-hud-005).
- Float results are per-architecture; PinGeometry uses scalar floats only (TR-combat-014, TR-hero-006).

## Decision

**1. Tick driver: a custom accumulator in the wrapper's `_process(delta)`; no `_physics_process` anywhere.** The `Clock` accumulates `delta` and calls `battle.tick(DT)` zero or more times per frame. `_physics_process` is not used by any node in the project. Reasons: the sim must not depend on an engine rate whose behaviour is NOT SOURCEABLE here (`Engine.physics_ticks_per_second`, `Engine.max_physics_steps_per_frame`, `Engine.time_scale`); the project uses no physics (Jolt, the 4.6 default, is irrelevant); input is documented to arrive before `_process`, so commands run before that frame's ticks, and the HUD, the Clock and the views then share one callback with one order. `Engine.time_scale`, `physics_ticks_per_second` and `max_physics_steps_per_frame` are never read or set by project code (an unset `time_scale` stays 1.0 as observed; whether `delta` is scaled by it is NOT SOURCEABLE, so nothing sets it).

**2. Rate and constants.** `res://src/data/tick_rate.gd`, `class_name TickRate extends RefCounted`, holds `const HZ := 60`, `const DT := 1.0 / 60.0`, `const MAX_TICKS_PER_FRAME := 2` and `static func to_ticks(seconds: float, dt: float) -> int`. It lives under `src/data/` because ADR-0002 forbids `src/data/` from importing `src/battle/` and wants the schema floor to reference this constant; both `src/battle/` and `src/data/` may import it. It has no state and no `static var`. `catalogue_schema.gd`'s floor becomes `TickRate.DT`. `build()` sets `Battle.dt = TickRate.DT`; sims and tests that need another `dt` (the Flow GDD's 0.25 fixture) are given it by their own constructor, so no gameplay class reads a global. The cap is 2 because the ticks' slice is 4.0 ms and Combat's worst-case estimate is under 2 ms per tick (2 x 2 = 4.0 ms, both unmeasured), and because two ticks per frame equal real time at the 30 fps floor (2 x 1/60 = 1/30 s), so a floor-rate device runs at full speed and anything slower slows down. The value is provisional until Verification item 3; changing it is a one-line edit and a new baseline is not needed, since it changes how many ticks run per frame, never what a tick does.

**3. Accumulator, stall and cap.** `Clock.advance(frame_delta)`: if stopped, return 0. `acc += frame_delta`; `owed = floori(acc / DT)`; if `owed > MAX_TICKS_PER_FRAME`, run exactly `MAX_TICKS_PER_FRAME` ticks and set `acc = 0.0` (the owed time beyond the cap and the fractional remainder are **dropped, not banked**, so the game slows during a stall and never fast-forwards after it); otherwise run `owed` ticks and `acc -= owed * DT`. After every `advance`, `acc` is below `DT`, so a long Build phase, in which `Battle.tick` returns at once, cannot bank time. A negative or non-finite `frame_delta` is treated as 0 and reported through `dev_error`. `acc` is a 64-bit float used only by the presentation layer; it never reaches the sim, which sees only tick counts, so its rounding cannot change a result.

**4. The Clock and `stop_clock()`.** `Clock extends RefCounted` in `src/presentation/clock.gd`; the wrapper builds it in `setup()` (ADR-0001 Decision 10), holds it in a typed field, and drives it. It never lives in `src/battle/` and `Battle` never holds it. It receives `battle.tick` as a method Callable (target held by the wrapper's `Battle` field, ADR-0001 Decision 5), `dt` and the cap. `BattleWrapper.stop_clock()` calls `Clock.stop()`: sets `running = false`, `acc = 0.0`; idempotent; a stopped Clock returns 0 from `advance` and cannot be restarted (a retry builds a new wrapper and a new Clock). `AppRoot` calls it before `cancel_input()` and teardown on retry and on Fatal (ADR-0001 Decisions 6 and 7). Won and Lost do not stop the Clock: the in-sim gate (Decision 5) makes the remaining ticks no-ops, and the wrapper's frame work (HUD, views) must keep running to show the result.

**5. The in-sim clock gate.** `Battle.tick(dt)` returns at once unless `halted()` is false **and** Flow's phase is WAVE or INTERMISSION. Build runs no ticks (Flow Rule 6 and 10: a stopped clock; a pin in Build places the hero at once through `in_build()`); Paused, Won, Lost and Fatal run none. The gate lives in the sim, so it holds headless. A `dt` argument other than `Battle.dt` is a defect reported through `dev_error` and the tick returns; the argument exists for the harness and signature stability (ADR-0001 Key Interfaces), not for variable time.

**6. The one tick order.** Inside `Battle.tick`, after the gate, in this order, every tick (Intermission included):

| Slot | System | Work |
|---|---|---|
| 1 | Flow `tick` | intermission countdown (integer ticks), wave start and clear checks |
| 2 | EnemyWave `advance(tick)` | spawn from the absolute schedule, move, leak (leaks resolve before fire) |
| 3 | Combat `tick_status(roster)` | slow countdown over the roster |
| 4 | TowerSim `tick` | by ascending slot index: cooldown, target, `report_attack`, deliver |
| 5 | HeroSim `tick` | walk, attack, cooldown, telegraph, release; burst after hero |
| 6 | EnemyWave `reap` | remove corpses, emit `enemy_killed(bounty)` once each |

`halted()` is checked before slot 1 and after every slot, and each sim checks it after every accessor read and emit (TR-state-007, TR-enemy-005, TR-tower-006); once true the tick returns and later slots do not run. There is no seventh slot: an outcome commits inside the slot that causes it (a leak in slot 2, the last kill's `waves_complete` in slot 6) and Flow's transition rules (commit, act, emit, check the latch) run from there. Because the Hero slot (5) precedes the reap (6), a burst that kills the last enemy releases on the tick the stage is won, and its BURST `attack_fired` precedes `phase_changed(Won)`; a latched outcome (a fatal leak in slot 2, or Fatal) stops later releases because slot 5 sees `halted()` (TR-hero-016, provisional; its last clause is ADR-0011's). Waves use no randomness, so no slot draws from the RNG at MVP (Decision 10). This is the order Flow Rule 5, Combat Rule 11, Enemy & Wave Rule 12 and Tower Rule 9 cite; they restate it and do not define it.

**7. Frame order and commands between ticks.** Per frame:

1. Engine, before any `_process`: buffered input is flushed (verified on desktop, ADR-0003; provisional on D1). `InputAdapter` callbacks run, the resolver emits, and `HeroInput`, `TowerInput` and `HudLogic` **issue commands synchronously from that call stack**: a command is applied the instant its gesture resolves, not queued. This is "between ticks" because ticks run only inside `Clock.advance`, which is called only from the wrapper's `_process`, and engine callbacks run one after another on the main thread (the premise of Verification item 2). A command therefore never runs inside a tick. The `Clock` exposes `is_ticking() -> bool`, true only inside its loop, and the wrapper's debug wiring reports a command or lifecycle signal that arrives while it is true.
2. `BattleWrapper._process(delta)`, in this order and nothing else:
   a. compute `view_dt` (Decision 8);
   b. real-time models: `HudLogic.advance(view_dt * 1000.0)` (it clamps to 100 ms itself), `ChipWindow.advance(view_dt * 1000.0)`, `HeroInput.update()`, then the view clocks (`ClearanceWindow.advance(view_dt)`, flash timers, the hero view);
   c. `Clock.advance(delta)`: zero up to `MAX_TICKS_PER_FRAME` calls to `battle.tick(DT)`;
   d. views read the committed state (rosters, slot state, hero queries, HUD view-models), and mark themselves for redraw.

   This puts the real-time models **before** the ticks, as TR-hud-005 and `architecture.md` Data Flow 1 state ("input commands, then real-time models, then ticks, then views"). It differs from the order in this ADR's brief (ticks, views, then HUD `advance`). The cost of the TR-hud-005 order is that an outcome latched during this frame's ticks is first seen by `HudLogic.advance` one frame later (at most 1/60 s before its 400 ms text timer starts); the gain is that the displayed bonus equals the paid bonus (TR-hud-005) and that the snapshot is built in `advance`, never inside a tick's signal stack (HUD Rule 15). RunLog's flush rides `advance` (ADR-0010).
3. Everything is in `_process`. No `_physics_process` exists, and no node other than the wrapper drives the Clock.

**8. View clocks and Pause.** The wrapper tracks `_paused`, set when `phase_changed` announces PAUSED and cleared by any other `phase_changed` (the Flow stage machine leaves Paused only for the phase it left or for Fatal). Each frame, `view_dt = 0.0 if _paused else delta`. **Every frame-clock consumer receives `view_dt`**: HUD advance, `ChipWindow`, `ClearanceWindow`, flash markers, the hero view. So they freeze under Pause with one rule at one site, and views need no pause flag of their own (the alternative). The `HudLogic` rule "ignores `advance` while Paused" (HUD Rule 11) stays as a second guard; with `view_dt = 0` it is not exercised. The clearance window is a pure `RefCounted` whose only input is `advance(frame_dt)`; it is never driven by a sim tick and never by `Clock`, so its 0.15 s tail runs after the battle clock stops at Won, Lost or Fatal (those phases do not gate `view_dt`), and a `phase_changed` to Paused leaves the window as it is and frozen (Combat GDD; TR-combat-015). Won's and Lost's 0.4 s text beat is the HUD's 400 ms timer on the same `view_dt` (HUD Rule 15, TR-state-014). Reduce Motion's effect on frame-clock timers is the HUD GDD's (cut slides, fades and clock bars stay); it is cited here and not decided. The cosmetic RNG (Decision 10) is drawn only from this layer.

**9. Lifecycle notifications relative to the tick.** The adapter handles notifications in its own `_notification` (ADR-0003 Decision 8) and emits `lifecycle_paused`, which the wrapper has connected to `Flow.pause`. The engine runs callbacks on the main thread one after another, so the expectation is that a notification is delivered between callbacks, never inside the synchronous `Clock.advance` loop; this is NOT SOURCEABLE and is Verification item 2. The design does not need it to be true for safety against a **between-ticks** landing: if Flow pauses while the loop still owes ticks, `Battle.tick` returns at once for the rest (the gate) and the wrapper's phase handler zeroes the accumulator, so a resume runs 0 ticks. A landing **inside** a tick is the one case not covered: Flow would commit PAUSED while later slots still see `halted()` false. The debug wiring of Decision 7 reports it, and a device run must show it never happens before this ADR is Accepted for phone builds. Pause, as Flow Rule 17 says, zeroes `acc`, stops ticks through the gate, cancels input, and `SceneTree.paused` is never set (registry: `scene_tree_paused_for_flow_pause`).

**10. Determinism and the RNG.** There is one gameplay RNG: `Battle` creates `RandomNumberGenerator.new()` in `build()`, assigns `seed = rng_seed` (an explicit seed; `randomize()` is never called) and holds it in a typed field. At MVP **no system receives it**: Enemy & Wave is authored with no randomness and never reads the seed (Rule 6, GDD case 42: "a spy shows the seed never read"), and no other MVP system draws. A system that later needs randomness receives a method Callable on `Battle` (never the generator itself, never a lambda), and every draw happens inside a fixed tick slot, so the consumption order is the tick order and one stream stays reproducible. Adding the first consumer requires revising this ADR and the registry. The **cosmetic RNG** is a separate `RandomNumberGenerator` held by the wrapper, seeded at setup with `rng_seed ^ COSMETIC_SALT` (so a retained screenshot is reproducible), used only by views for jitter; the sim never sees it and nothing it produces feeds back. A global `randi()`, `randf()`, `randomize()` or `shuffle()` call under `src/` is forbidden (ADR-0007 lint). `RandomNumberGenerator` repeated the same ten values for the same seed across instances and runs on the probed binary (table above); stability across platforms and engine versions is NOT SOURCEABLE, which is why the baselines are per architecture and the baseline test pins the engine version (Decision 12).

**11. Seed source and the retry seed.** `AppRoot` chooses the seed, through a small `SeedSource extends RefCounted` in `src/app/` (testable with a fixed base). MVP rule: `base = int(Time.get_unix_time_from_system())` read once in `_ready()`; the first battle uses `base`; each retry `n` (1, 2, ...) uses `base + n`, a **fresh seed per retry**. `AppRoot` records the seed and attempt index through the wrapper-built RunLog (ADR-0010 owns the schema). The retry snapshot test builds its comparison battle with the **retry's** seed (ADR-0001 Decision 7). Bots and tests pass explicit seeds to `build()` and never touch `SeedSource`. `AppRoot` is not under `src/battle/`, so reading `Time` there does not break ADR-0001's ban. Because MVP waves read no randomness, a retry reproduces the same spawn schedule and `spawn_id`s regardless of seed (TR-enemy-007), and the fresh seed costs nothing now and keeps the seam honest later. No dev override flag is added at MVP; a command-line override would need `OS.get_cmdline_user_args()`, which the reference does not cover.

**12. Float policy, baselines and the determinism test.** Gameplay arithmetic uses GDScript `float` (64-bit, observed). `Vector2` components are 32-bit (observed, ADR-0002 probe and this one). Decision (QQ-05): **PinGeometry and every range check use float scalars with +, -, x, / and square root and no `Vector2` method** (TR-hero-006, the Hero GDD's choice); positions cross the boundary as `Vector2` at the edges (enemy `position` is cached once per tick, Combat GDD), and the sub-0.0001 error of the 32-bit round trip is inside the Hero GDD's 0.01 margins. Determinism is therefore guaranteed on one CPU architecture and one engine version, not across them (TR-combat-014; float results on x86 and ARM may differ, NOT SOURCEABLE). Bot baselines are kept per architecture, one file each, named `tests/baselines/<stage_id>_<bot_id>_<arch>_<engine_version>.json` with `<arch>` from `Engine.get_architecture_name()`'s value lower-cased (recorded in the file header; that method is not in the local reference, so the first harness story confirms the name, Verification item 4). A baseline missing for the running architecture is a test **failure** with the message "no baseline for <arch>", not a skip; `NOT ASSESSED` reporting belongs to ADR-0007's runner. The "same stage, seed and script give an identical result" test (Flow GDD Full determinism row) builds two battles with the same `(catalogue, stage_id, seed)`, feeds both the same command script on the same tick numbers, and requires equal `Battle.snapshot()` after N ticks and at the outcome. The snapshot is a plain nested `Dictionary` built from each sim's own `to_dict()` (the ADR-0002 record-snapshot approach; not `duplicate_deep()`): tick count, Flow phase, lives, intermission ticks, gold, each tower's level and `cooldown_left`, the hero's position, state and `cooldown_left`, the roster in `spawn_id` order (id, distance, hp, slow ticks), Combat's counters, and the RNG state (`rng.state`). Floats compare bit-exact on the same architecture; a cross-architecture run compares nothing.

**13. `to_ticks` and `Battle.dt`.** `to_ticks(seconds) = roundi(seconds / dt)`, halves away from zero (probe: `roundi(0.5)` is 1, `roundi(-0.5)` is -1), exposed as `TickRate.to_ticks(seconds, dt)` and as `Battle.to_ticks(seconds)` (the Callable ADR-0001 injects). `ceil` is rejected on the GDD's evidence and reproduced by the probe (`3 * 0.1 / dt` is `18.00000000000000355`, ceil gives 19); `floor` makes an exactly-`dt` interval depend on float noise. The validator's one-tick floor (`MIN_INTERVAL_SECONDS = TickRate.DT`) means every interval is at least one tick (`dt / dt` gives 1). A value below one tick can still round to 0 only if it is below half a tick, which the floor forbids for the intervals that need it; fields that may legitimately be 0 (a `telegraph_duration` of 0) are floored by their owners, as Hero does with `max(1, to_ticks(...))`. Countdowns are integer tick counters (TR-state-012, TR-tower-005). The two content rows ADR-0002 delegated, with the starter values and `dt = 1/60`: (a) the **wave spawn rule**: `spawn_tick(i) = to_ticks(start_delay + i x spawn_interval)` must be strictly increasing within a group (wave 2's `0.6` s interval gives 36 ticks apart, wave 5's `0.4` s gives 24, and the exact-`dt` half-tick-offset case is the one the row guards); (b) the **Hero telegraph travel row**: `fastest move_speed x max(1, to_ticks(telegraph_duration)) x dt <= radius / 2`, with the starter `telegraph_duration` 0.25 s giving 15 ticks, the GDD's `27.5 <= 35`. Both read `TickRate.to_ticks`, never a local copy.

**14. Frame budget split (Data Flow 10), all unmeasured (QQ-11).**

| Slice | Budget at 60 fps | Status |
|---|---|---|
| Input, resolver, commands | 0.5 ms | unmeasured |
| Simulation ticks | 4.0 ms total; normal frame one tick; at the cap two | unmeasured; Combat worst case about 400 range checks per tick estimated under 2 ms |
| Views and HUD | 3.0 ms | unmeasured |
| Engine, rendering submit, OS | 7.0 ms | unmeasured |
| Headroom | 2.1 ms | unmeasured |

Measurement plan: on one Adreno 5xx-class phone at the first phone build, with the starter stage's worst wave on screen (wave 6), record 600 frames of `Time.get_ticks_usec()` deltas around `Clock.advance`, around the views and HUD refresh, and for the whole `_process`, in a development build, and the mean and 99th percentile of the per-tick cost; set `MAX_TICKS_PER_FRAME` to the largest N whose p99 cost times N fits 4.0 ms, and revise this table. Until then every number is an estimate.

**15. Delegations.** Signal names and payloads: ADR-0006. The harness, the baseline test runner and the lints: ADR-0007. Command result codes and the RunLog schema: ADR-0010. The hero view's outcome rows on the frame clock: ADR-0011. The enemy reap internals: ADR-0009.

### Architecture Diagram

```
Engine frame start: input flushed ──► InputAdapter ► resolver ► HeroInput/TowerInput/HudLogic
                                                       └─ commands applied NOW (between ticks)
BattleWrapper._process(delta)                          (no _physics_process anywhere)
 a view_dt = 0 if _paused else delta
 b HudLogic.advance(ms) · ChipWindow.advance(ms) · HeroInput.update() · ClearanceWindow.advance(s) · view timers
 c Clock.advance(delta): acc += delta; n = floor(acc/DT); n > CAP ? run CAP, acc = 0 : run n, acc -= n*DT
      └─ n x battle.tick(DT)
           gate: halted() or phase not WAVE/INTERMISSION ─► return
           1 Flow.tick  2 EnemyWave.advance  3 Combat.tick_status  4 TowerSim.tick
           5 HeroSim.tick (hero, burst)  6 EnemyWave.reap      (halted() checked between slots)
 d views read state, queue redraw

phase_changed(PAUSED) ─► wrapper: Clock.zero(), _paused = true
AppRoot: stop_clock() before cancel_input() and free() on retry and Fatal
Battle: rng (seeded, no MVP reader)   Wrapper: cosmetic rng (sim never sees)
```

### Key Interfaces

```gdscript
class_name TickRate extends RefCounted            # res://src/data/tick_rate.gd
const HZ := 60
const DT := 1.0 / 60.0
const MAX_TICKS_PER_FRAME := 2                    # provisional, Verification item 3
static func to_ticks(seconds: float, dt: float) -> int:
	return roundi(seconds / dt)                   # halves away from zero

class_name Clock extends RefCounted               # res://src/presentation/clock.gd
func setup(tick: Callable, dt: float, max_ticks: int, dev_error: Callable) -> void
func advance(frame_delta: float) -> int           ## Ticks run this call, 0 .. max_ticks. Excess owed time is dropped.
func zero() -> void                               ## acc = 0. Wrapper calls it on phase_changed(PAUSED).
func stop() -> void                               ## Idempotent. running = false, acc = 0. Called by BattleWrapper.stop_clock().
func is_ticking() -> bool                         ## True only inside advance's loop.

class_name Battle extends RefCounted              # additions to ADR-0001's interface
var rng: RandomNumberGenerator                    # seeded in build(); no MVP system holds it
func tick(dt: float) -> void                      # gate, then slots 1..6 of Decision 6
func to_ticks(seconds: float) -> int              # TickRate.to_ticks(seconds, dt)
func snapshot() -> Dictionary                     # plain nested Dictionary for the determinism test; includes rng.state

class_name SeedSource extends RefCounted          # res://src/app/seed_source.gd
func _init(base: int) -> void
func first() -> int                               # base
func retry(attempt: int) -> int                   # base + attempt, attempt >= 1
```

### Implementation Guidelines
- Sim time **must** enter only through `Battle.tick(dt)`; `_process`, `_physics_process`, a `Timer`, `await` or the wall clock **must never** appear in `src/battle/` or `src/data/` (the latter except `TickRate`'s constants).
- No node in the project **may ever** define `_physics_process`, and project code **must never** read or set `Engine.time_scale`, `Engine.physics_ticks_per_second` or `Engine.max_physics_steps_per_frame` (ADR-0007 lint).
- The Clock **must** be a `RefCounted` under `src/presentation/`, driven only by `BattleWrapper._process`, **must** cap at `MAX_TICKS_PER_FRAME`, **must** drop (not bank) owed time beyond the cap, and **must** be zeroed on the transition into Paused.
- `Battle.tick` **must** return at once unless `halted()` is false and the phase is WAVE or INTERMISSION; it **must** run slots 1 to 6 in the order of Decision 6 and **must** check `halted()` after every slot. A new tick participant **must** be inserted into that table by a revision of this ADR, never appended ad hoc.
- A command **must** be applied from the input call stack between ticks and **must never** be queued into, or called from, a tick; sims **must never** call a command method of another sim.
- Authored durations **must** become ticks through `TickRate.to_ticks` only; countdowns **must** be integer tick counters; no gameplay code **may** subtract `dt` repeatedly from a float.
- The wrapper **must** pass `view_dt` (0 while Paused) to every frame-clock consumer; a view or HUD object **must never** read the engine's delta itself, and **must never** be driven by a sim tick or a sim signal for its duration.
- The clearance window and every other frame-clock timer **must** be a `RefCounted` advanced by `advance(frame_dt)`.
- `Battle` **must** own the only gameplay `RandomNumberGenerator`, seeded from the injected seed; gameplay code **must never** call global `randi`, `randf`, `randomize` or `shuffle`, and **must never** hold the generator itself; the cosmetic RNG **must** be wrapper-held and never reach the sim.
- PinGeometry and range checks **must** use float scalars and **must never** call a `Vector2` method (`length`, `distance_to`, `normalized`, `dot`, `lerp`).
- Bot baselines **must** be per architecture and per engine version, named as in Decision 12; a missing baseline **must** fail the test.
- `AppRoot` **must** call `stop_clock()` before `cancel_input()` and teardown; the retry seed **must** differ from the first (`base + n`) and be recorded through RunLog.

## Alternatives Considered

### Alternative 1: Drive the tick from `_physics_process`
- **Description**: Set the project's physics rate to 60 and call `battle.tick(1.0 / 60.0)` once per physics step.
- **Pros**: The engine owns the accumulator and the catch-up; less custom code.
- **Cons**: Depends on `Engine.physics_ticks_per_second`, `max_physics_steps_per_frame` (default 8, observed) and their catch-up behaviour, none of which the reference documents; a second callback order to reason about against input and `_process`; the cap would be the engine's 8, above the 4.0 ms slice; there is no physics in the project, so the loop would exist only for the tick.
- **Rejection Reason**: Unsourced behaviour on the one thing that must be exact; the custom accumulator is about 20 lines, headless-testable with a fake Callable, and keeps the cap ours.

### Alternative 2: Variable `dt` per frame
- **Description**: Pass the frame delta to `tick`.
- **Pros**: No accumulator.
- **Cons**: Results depend on frame time; bots and humans diverge (the prototypes' numbers did not transfer); no determinism.
- **Rejection Reason**: Contradicts Flow Rule 4 and TR-state-003.

### Alternative 3: Cap of 4 ticks per frame, or bank the owed time
- **Description**: Allow up to 4 ticks per frame (covers down to 15 fps at full speed), or carry the remainder so the game catches up after a stall.
- **Pros**: Full speed on a slower device; no slowdown after a hitch.
- **Cons**: 4 ticks at the 2 ms estimate is 8 ms against a 4.0 ms slice and feeds a spiral (slow frame, more owed ticks, slower frame); banking makes a hitch fast-forward, and a backgrounded app would return with a time jump.
- **Rejection Reason**: Flow's edge case says the game slows rather than jumping; 2 matches the 30 fps floor and the budget. Revisit with Verification item 3.

### Alternative 4: Float seconds countdowns and `ceil`
- **Description**: Keep per-system float timers; convert with `ceil`.
- **Pros**: Reads naturally.
- **Cons**: 5.0 s took 301 ticks by repeated subtraction; `ceil` put 409 of 6,240 spawn times a tick late, and the probe reproduces it (`3 * 0.1 / dt` ceils to 19).
- **Rejection Reason**: Enemy & Wave Formulas; TR-state-012.

### Alternative 5: Views keep their own delta plus a pause flag
- **Description**: Each view and the HUD receive the raw delta and a `paused` flag and freeze themselves.
- **Pros**: A view can choose to keep animating under Pause.
- **Cons**: Every view re-implements the freeze; the clearance window, flash markers and the hero view can disagree; the HUD GDD already freezes `HudLogic` itself, so two mechanisms coexist.
- **Rejection Reason**: One gate at one site is testable once. No GDD row needs a view that runs under Pause.

### Alternative 6: Queue commands and apply them before each tick
- **Description**: Input handlers enqueue commands; the wrapper drains the queue before every tick.
- **Pros**: Guarantees a command lands on a tick boundary even if a notification or callback arrived mid-loop; a clean replay log.
- **Cons**: A command's result (the result enum, the HUD's displayed bonus) is no longer available in the input call stack, so a tap would show stale state for a frame, and TR-hud-005 ("displayed bonus equals paid bonus") needs the result at once.
- **Rejection Reason**: Immediate application between ticks is what the HUD and Hero GDDs assume; the `is_ticking()` check catches the one case a queue would fix.

### Alternative 7: A shared RNG injected into every sim
- **Description**: Inject the `RandomNumberGenerator` into Combat, EnemyWave and others now.
- **Pros**: Ready for a later random mechanic.
- **Cons**: A holder with no reader is a hidden dependency and breaks the GDD's "seed never read" test; fixed consumption order is unprovable without a consumer.
- **Rejection Reason**: Unneeded at MVP; a method Callable per consumer is added with the first consumer.

## Consequences

### Positive
- Sim time, order, command timing and randomness each have exactly one place, checkable by tests and lints.
- The sim runs identically headless and on a phone, because it sees only tick counts.
- A stall slows the game instead of jumping it, and a resume from Pause can never fast-forward.
- Views, HUD and the clearance tail keep running after the battle clock stops, and freeze under Pause by one rule.
- Retry gets a fresh recorded seed with no cost at MVP.

### Negative
- A device slower than 30 fps runs the game in slow motion rather than catching up.
- The cap of 2 is an estimate; if the measured tick is dearer, the 30 fps floor needs a cheaper tick, not a bigger cap.
- Baselines multiply by architecture and engine version, and a new platform means a new baseline.
- The HUD sees an outcome one frame later than the tick that made it (Decision 7).
- A notification landing inside a tick is unprotected until a device run shows it cannot happen.

## Risks
- **`_process` delta is not what the reference implies (first frame, resume from background, `time_scale`).** Mitigation: the cap and `acc = 0` bound any single frame to 2 ticks; Verification item 5 records the real values; `time_scale` is never set.
- **Input is not flushed before `_process` on a device (ADR-0003 D1).** Mitigation: this ADR's premise is marked provisional; a failure reopens Decision 7 and the Approved HUD and Input rules (QQ-22).
- **A lifecycle notification lands inside `Battle.tick`.** Mitigation: `Clock.is_ticking()` debug check; Verification item 2; if observed, Flow's `pause()` is deferred to the next frame start by a latch in the wrapper (a revision of this ADR).
- **Someone adds a random draw, a `Vector2` method or a float countdown to a sim.** Mitigation: the ADR-0007 lints and the determinism and baseline tests.
- **ARM and x86 baselines drift or the engine version changes the RNG sequence.** Mitigation: baselines are named by architecture and engine version; a missing one fails; an engine upgrade regenerates them under review.
- **The cap is wrong for the phone.** Mitigation: the measurement plan; the constant is one line.
- **Stale GDD rows.** The Flow GDD's Clock deferred row and its question on the clamp value, and the Enemy & Wave "strictly increasing ticks" row, change when this ADR is Accepted.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-003: sim time only through `battle.tick(dt)` at a fixed rate; wrapper clamps owed ticks | Decisions 1 to 5 |
| game-state-stage-flow.md | TR-state-004: one fixed order; commands only between ticks | Decisions 6 and 7 |
| game-state-stage-flow.md | TR-state-005: all randomness from an injected seed; same stage, seed and script give an identical result | Decisions 10 to 12 |
| game-state-stage-flow.md | TR-state-006: pure stage machine, Fatal absorbing, `in_build()` | Decision 5 (gate by phase); machine itself is Flow's |
| game-state-stage-flow.md | TR-state-007: Won, Lost, Paused and Fatal stop the clock; remaining systems skip the tick | Decisions 5, 6 and 9 (`halted()` between slots) |
| game-state-stage-flow.md | TR-state-012: authored durations through one `to_ticks`; integer counters | Decision 13 |
| game-state-stage-flow.md | TR-state-014: presentation timers on the frame clock outside the sim | Decision 8 |
| combat-damage.md | TR-combat-009: tick order Flow, advance, `tick_status`, towers by slot, hero then burst, reap | Decision 6 |
| combat-damage.md | TR-combat-014: determinism per architecture; baselines per architecture | Decision 12 |
| enemy-wave.md | TR-enemy-002: fixed `dt`, one `to_ticks` (half away from zero), absolute spawn schedule | Decisions 2 and 13 (probe) |
| enemy-wave.md | TR-enemy-003: two tick entries, `advance` and `reap`, in Combat's order | Decision 6 (slots 2 and 6); internals ADR-0009 |
| enemy-wave.md | TR-enemy-007: no randomness, never reads the sim seed; cosmetic jitter uses a separate RNG; retry rebuilds identical schedule | Decisions 10 and 11 |
| tower-system.md | TR-tower-005: ascending slot index; integer `cooldown_left` running on every tick, Intermission included | Decision 6 (slot 4) and 5 (Intermission ticks) |
| tower-system.md | TR-tower-010: chip window on real time while the sim clock is stopped | Decisions 7 and 8 (`ChipWindow.advance`) |
| hero-system.md | TR-hero-003: HeroSim in the Hero-and-burst slot, uses `to_ticks`, returns when `halted()` | Decision 6 (slot 5) and 13 |
| hero-system.md | TR-hero-006: PinGeometry in float scalars, no `Vector2` methods | Decision 12 (QQ-05 decided) |
| hero-system.md | TR-hero-011: HeroInput advances through an explicit `update()` | Decision 7 (step 2b) |
| hero-system.md | TR-hero-013: Pause stops the clock so walk and telegraph resume exactly; Build runs no ticks; Intermission ticks | Decisions 3, 5 and 9 |
| hero-system.md | TR-hero-016 (provisional, not yet in `tr-registry.yaml`): the Hero slot precedes the reap, so a last-enemy burst releases on the Won tick and a latched outcome stops later releases; the hero view's outcome rows run on the frame clock | Decision 6 covers the slot order and the halt; the frame-clock clause is delegated to ADR-0011, with Decision 8's rule |
| battle-hud.md | TR-hud-005: each frame runs commands, then real-time models, then ticks, then views | Decision 7 |
| battle-hud.md | TR-hud-007: armed buttons on a real-time `advance(ms)` clock, clamped to 100 ms, frozen while Paused | Decisions 7 and 8 (`view_dt` is 0 under Pause; the clamp is HudLogic's) |

## Performance Implications
- **CPU**: One tick per frame in the normal case, at most two; the tick slice is 4.0 ms (unmeasured). The Clock adds a division and a loop per frame. The snapshot and baselines run only in tests.
- **Memory**: One `RandomNumberGenerator` per battle, one cosmetic generator, one Clock; no per-frame allocation in the Clock.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
Greenfield: `src/` holds no `.gd` file. Create `src/data/tick_rate.gd`, `src/presentation/clock.gd`, `src/app/seed_source.gd`; add `rng`, `tick`, `to_ticks`, `snapshot` to `Battle`; point `catalogue_schema.gd`'s floor at `TickRate.DT` (ADR-0002) and add its two `to_ticks` rows. Copy the probe to `prototypes/adr-0004-probe/` (done with this ADR). The Flow, Combat, Enemy & Wave, Tower and Hero GDD tick-order restatements already cite the order and need no edit except the rows listed under Risks.

## Validation Criteria
- Clock row (Flow GDD): a frame owing more than the cap runs exactly `MAX_TICKS_PER_FRAME` ticks and the accumulator is 0 afterwards (cap test, fake Callable); a frame owing less leaves `acc < DT`.
- Pause-zeroing test: `phase_changed(PAUSED)` zeroes `acc`, so a resume runs 0 ticks from time owed before the pause; the Flow GDD's criterion 12 holds (A, B and C do not tick during the 100; one tick adds 1 after a resume to Wave or Intermission, none to Build).
- Order test: recording systems in slots 1 to 6 log the listed order; `halted()` latched after slot N skips slots N+1 to 6; a burst that kills the last enemy releases before `phase_changed(Won)` (TR-hero-016).
- Full determinism row: two battles with the same seed and script give equal `snapshot()` at every checked tick and at the outcome; two seeds give equal logs and a spy shows the seed never read (Enemy & Wave case 42).
- Retry: the comparison battle uses the retry's seed; `SeedSource.retry(n)` differs from `first()`.
- `to_ticks` rows: 0.9 s is 54, 5.0 s is 300, 1/60 s is 1, 0 is 0, 0.125 s at `dt` 0.25 is 1 (Enemy & Wave cases 37 to 39).
- Per-architecture baseline test: the bot baseline for the running architecture and engine version exists and matches; a missing one fails.
- Lints (ADR-0007): no `_physics_process`, no `Engine.time_scale` and its siblings, no global random call under `src/`, no `Vector2` method in PinGeometry, no `Time`/`Engine` read under `src/battle/`.
- View clock tests: `ClearanceWindow.advance` with `view_dt` 0 holds its value; it keeps counting at Won, Lost and Fatal; a retry clears it.
- Probe repeat on Android, iOS and x86 desktop (Verification item 4) shows the same RNG values or records the difference.

## NOT SOURCEABLE
Not covered by `docs/engine-reference/godot/`; each is listed under Verification Required and nothing above depends on it being true.
- NOT SOURCEABLE: `_process(delta)` versus `_physics_process(delta)` semantics, including the first-frame delta, the delta after a resume from the background, and whether `Engine.time_scale` scales `delta`.
- NOT SOURCEABLE: what `Engine.physics_ticks_per_second` and `Engine.max_physics_steps_per_frame` do (only their default values, 60 and 8, were read; the project does not use them).
- NOT SOURCEABLE: float determinism across ARM and x86 and across engine versions, and `RandomNumberGenerator` sequence stability across platforms and versions (repeatability was observed on one binary on one host only).
- NOT SOURCEABLE: that a lifecycle notification or an input callback is never dispatched inside the synchronous `Clock.advance` loop; ADR-0003 lists the same item.
- NOT SOURCEABLE: `Time.get_unix_time_from_system()` and `Time.get_ticks_usec()` resolution and monotonicity on a device (a float was observed on desktop; two back-to-back `get_ticks_usec()` reads were equal).
- NOT SOURCEABLE: the `Engine.get_architecture_name()` values used for the baseline file names.
- NOT SOURCEABLE: `Vector2` precision on a device (single precision observed on desktop in the ADR-0002 probe and in this one).

## GDD and Registry Sync at Acceptance
- Flow GDD: the Clock deferred row gets the cap (2, provisional); the open clamp question closes; the Full determinism row cites Decision 12.
- `tr-registry.yaml`: add TR-hero-016 (provisional) at `/architecture-review`.
- Registry: the stances proposed in `adr-0004-registry-candidates.yaml` are appended to `docs/registry/architecture.yaml` when this ADR is Accepted.
- `architecture.md`: Data Flow 1 order (real-time models before ticks) is confirmed; QQ-01 and QQ-05 close; QQ-11 stays open; QQ-22 stays open until the device run.

## Related
- `docs/architecture/architecture.md`: Required ADRs (ADR-0004), Data Flow 1, 2, 6 and 10, B4, B5, QQ-01, QQ-05, QQ-08, QQ-11, QQ-22.
- `design/gdd/game-state-stage-flow.md` Rules 4, 5, 6, 10, 17, Edge Cases (long frame), Clock and Full determinism rows; `combat-damage.md` Rule 11, Burst clearance, View clocks; `enemy-wave.md` Rule 6, Formulas (`to_ticks`); `tower-system.md` Rule 9; `hero-system.md` Rules 8, 9, telegraph; `battle-hud.md` Rules 11 and 15.
- ADR-0001 Decisions 2(d), 6, 7 and 10; ADR-0002 Ordering Note; ADR-0003 Decision 8 and the NOT SOURCEABLE section.
- Probe: `prototypes/adr-0004-probe/probe.gd`.
