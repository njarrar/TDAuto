# ADR-0004: Fixed-Tick Clock, Tick Order, Frame Order and Determinism

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer. Reviewed once each on 2026-11-05 by `godot-specialist` (1 blocking, 10 minor) and `technical-director` under gate TD-ADR (CONCERNS: 3 blocking, 9 concerns, 5 advisory); all findings are applied in this revision. No second review pass was run.

## Summary
The battle must advance only through `Battle.tick(dt)` at a fixed rate, in one order, with commands between ticks and every random draw reproducible from a seed, while the views and HUD run on real time and keep running after the battle clock stops. This ADR fixes a 60 Hz accumulator `Clock` (a `RefCounted` in the presentation root) driven from the wrapper's `_process` with a cap of 3 ticks per frame (floor 2) whose excess time is dropped, the six-slot tick order, commands applied immediately from the input call stack, a single seeded RNG owned by `Battle` that no MVP system reads, a float policy with per-architecture baselines, `to_ticks` as round-half-away-from-zero, and a gated frame delta for every view clock.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; installed 4.7.2.stable.official) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (architecture table). The decision uses only `Node._process`, `RefCounted`, `Callable`, `RandomNumberGenerator`, `roundi`, `Time` and `Engine` property reads, none of which appears in `breaking-changes.md` or `deprecated-apis.md` for 4.4 to 4.7. The semantics of `_process(delta)`, the physics-step settings and cross-platform float behaviour are not in the local reference; each is listed under NOT SOURCEABLE and nothing below rests on it. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/physics.md` (Jolt default in 4.6 is irrelevant: this project uses no physics body, area or query, and no `_physics_process`), `modules/input.md` (section Verified on 4.7.2). The live 4.7 class reference was **not** consulted. |
| **Post-Cutoff APIs Used** | None. Code under this ADR must never override a method with a typed return without an explicit `return` (4.7 break). |
| **Verification Required** | Seven items, each with a pass condition in the Device run block of Validation Criteria. (1) Device run (shared with ADR-0003 D1): input events of a frame arrive before that frame's `_process`, so a command is applied before that frame's ticks. (2) Device run: log `Clock.is_ticking()` whenever a lifecycle notification reaches the adapter; it must always be false (Decision 9). (3) Measure per-tick cost at the worst-case entity count and the frame split of Decision 14 on an Adreno 5xx-class device, in a release export with a timing flag (debug figures alongside), QQ-11; set the cap from it, never below 2. (4) Run `prototypes/adr-0004-probe/probe.gd` on Android, iOS, an x86_64 desktop and the CI runner and compare with the observations below: RNG values, float width, `roundi`, the values of `Engine.get_architecture_name()` and `OS.get_name()`, `Vector2` width, and that `Time.get_unix_time_from_system()` returns a float. (5) Record the first-frame `delta` and the `delta` after a resume from the background on a device. (6) Confirm `Time.get_ticks_usec()` resolution on a device (microsecond observed on desktop). (7) The four physics and time settings (`physics_ticks_per_second`, `max_physics_steps_per_frame`, `physics_jitter_fix`, `time_scale`) are unused by project code: not verified, and the lint keeps them unused. |

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
| `Time` (review probe, windowed: `/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/adr-0004-probe/review`) | `get_unix_time_from_system()` returns a float (`typeof` 3); `int()` of it is `typeof` 2 (1793863941). Five back-to-back `get_ticks_usec()` reads gave 5117250, 5117252, 5117252, 5117252, 5117252: microsecond resolution, and two equal reads mean a sub-microsecond call. Adequate for Decision 14. |
| `Engine.get_architecture_name()` (review probe) | Exists on 4.7.2; returned `arm64` on this host. `x86_64` is expected on Intel desktops and CI (unverified here; Verification item 4). |
| `_process` delta (review probe, same command) | First frame `delta` 0.065880 s and 0.064888 s in two windowed runs. Frame 3: `delta` 9.4 ms against 1.0 ms of wall time; frame 4: 0.04 ms against 0.31 ms; over 300 frames the sum of `delta` matched wall time (0.0536 s against 0.0534 s after frame 1). `physics/common/physics_jitter_fix` read 0.5. The smoothing is engine-source knowledge (the main timer sync smooths the process step against the physics step), not in the local reference. |
| Accumulator models (review probe) | 6000 frames at +-1 % of `DT`: 6000 ticks under both the drop and the keep rule. Ten 100 ms stalls in 600 frames: 650 ticks owed, 610 run under the drop rule, 646 under banking (catches up later). 90 busy-looped frames: 0 re-entrant notifications or inputs (weak evidence; no focus change was induced). |
| JSON versus `var_to_str` (review probe, `res://main2.tscn`) | `JSON.stringify`/`parse_string` turned `rng.state` 2343518260280137770 into the float 2343518260280137728.0 and `0.1 + 0.2` into 0.3; the int-versus-float `==` on the damaged state still reported true. `var_to_str`/`str_to_var` round-tripped exactly and `state` stayed an int. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted: the wrapper that holds the Clock, `Battle`, `build()`, `stop_clock()`, teardown), ADR-0003 (Proposed; **provisional premise**: input is flushed before `_process` on desktop; the device confirmation, D1 and D3, is owed and a failure reopens Decision 3). |
| **Enables** | ADR-0005 (a bad accessor read is a `fatal()`, which the tick slots check), ADR-0006 (signals are emitted synchronously inside the slots of Decision 2), ADR-0007 (the harness drives `tick` and the baselines), ADR-0009 (EnemyWave `advance` and `reap` slots), ADR-0010 (commands run between ticks; RunLog flush is driven by `advance`), ADR-0011 (frame-clock rule for views). |
| **Delegates To** | ADR-0006: signal names and payloads, including the type of `phase_changed`'s value that the wrapper reads to detect Paused, and the once-only `phase_changed(FATAL)` emit and its timing (this ADR fixes only that `Flow.phase()` reads FATAL from the moment the latch is set, Decision 5). ADR-0007: the harness, the baseline test runner, the snapshot-equality runner and the lints named below (no `_physics_process`; no read or set of `Engine.time_scale`, `physics_ticks_per_second`, `max_physics_steps_per_frame` or `physics_jitter_fix`; no `Vector2` method or operator in PinGeometry or the range-check helpers; no `randi`/`randf`/`randomize`/`shuffle` global call under `src/`; no `randfn` or transcendental call (`sin`, `cos`, `atan2`, `pow`, `exp`, `log`) under `src/battle/`), and a runner mode that writes a missing baseline as a CI artifact for review and commit. ADR-0009: the enemy reap internals, the roster ordering `advance` and `reap` use, and the name of the range-check file the float lint covers. ADR-0010: command result codes, the RunLog schema (it records the seed and the attempt index) and RunLog's flush on `advance`. ADR-0011: the hero view's outcome rows on the frame clock (TR-hero-016's last clause), the Combat view's `ClearanceWindow` class design, the redraw key (which must read the Call button's bonus and seconds-left in the view step after the ticks, Decision 7), and whether to interpolate or accept judder between ticks and frames. |
| **Blocks** | Every Game State & Stage Flow story that touches the tick (Clock, Pause, Fatal), the first Enemy & Wave, Tower and Hero stories (they need the tick order), the bot baselines. |
| **Ordering Note** | Edited 2026-11-05 by the ADR-0006 fix round: the `in_tick` command guard (Key Interfaces, the Decision 7 Must rule, the Migration injection) now reads `in_dispatch()`, of which `in_tick()` is a subset. ADR-0002's schema floor `MIN_INTERVAL_SECONDS` is a local copy of `1/60` until its code references `TickRate.DT` (Decision 2); the Hero telegraph row and the wave "strictly increasing spawn ticks" row land with it. ADR-0003 must stay Proposed or become Accepted; this ADR becomes provisional again if D1 or D3 fails. `MAX_TICKS_PER_FRAME` is provisional until Verification item 3. |

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

**1. Tick driver: a custom accumulator in the wrapper's `_process(delta)`; no `_physics_process` anywhere.** The `Clock` accumulates `delta` and calls `battle.tick(DT)` zero or more times per frame. `_physics_process` is not used by any node in the project. Reasons: the sim must not depend on an engine rate whose behaviour is NOT SOURCEABLE here (`Engine.physics_ticks_per_second`, `Engine.max_physics_steps_per_frame`, `Engine.time_scale`); the project uses no physics (Jolt, the 4.6 default, is irrelevant); input is observed (ADR-0003 spike) to arrive before `_process`, so commands run before that frame's ticks, and the HUD, the Clock and the views then share one callback with one order. `Engine.time_scale`, `physics_ticks_per_second`, `max_physics_steps_per_frame` and `physics_jitter_fix` are never read or set by project code (an unset `time_scale` stays 1.0 as observed; whether `delta` is scaled by it is NOT SOURCEABLE, so nothing sets it). The `_process` delta is not raw wall time: the review probe saw it smoothed by `physics_jitter_fix` (9.4 ms against 1.0 ms of wall time on one frame) while the 300-frame sum matched wall time. The accumulator stays correct because it is fed a sum that is right over the long run and the cap bounds any single frame; Decision 14 therefore measures with `Time.get_ticks_usec()` and never with `delta`.

**2. Rate and constants.** `res://src/data/tick_rate.gd`, `class_name TickRate extends RefCounted`, holds `const HZ := 60`, `const DT := 1.0 / 60.0` and `static func to_ticks(seconds: float, dt: float) -> int`. `MAX_TICKS_PER_FRAME` is a presentation tuning value that only the Clock reads, so it is a const on `Clock`, not here. It lives under `src/data/` because ADR-0002 forbids `src/data/` from importing `src/battle/` and wants the schema floor to reference this constant; both `src/battle/` and `src/data/` may import it. It has no state and no `static var`. `catalogue_schema.gd`'s floor becomes `TickRate.DT`. `build()` sets `Battle.dt = TickRate.DT`; sims and tests that need another `dt` (the Flow GDD's 0.25 fixture) are given it by their own constructor, so no gameplay class reads a global. The cap is `Clock.MAX_TICKS_PER_FRAME := 3`, provisional, and `Clock.setup` raises any smaller value to the floor `MIN_CAP := 2`. The reason is jitter, not the budget: the technical director simulated Decision 3's accumulator over 18,000 frames at 30 fps (a reviewer's scratch script, not in the repo) and a cap of 2 ran 100 % of real time with perfectly even frames, 98.9 % at +-1 ms of jitter and 97.3 % at +-3 ms, because any frame slightly over 2 x `DT` owes 3 ticks and loses one; a cap of 3 ran 100 % in every case, and 60 fps with a cap of 2 also runs 100 %. The 4.0 ms slice is a 60 fps slice, and a frame that owes 3 ticks is by definition a slow frame of about 33 ms, so up to 3 x 2 ms (the unmeasured estimate) there does not break it, and the cap still bounds any spiral. Verification item 3 sets the final value. A measured value below 3 means the tick is too dear and needs a cheaper tick, not a smaller cap, and the constant is never set below 2. Changing the cap changes how many ticks run per frame, never what a tick does, so no baseline moves.

**3. Accumulator, stall and cap.** `Clock.advance(frame_delta)`: if stopped, return 0. `acc += frame_delta`; `owed = floori(acc / DT)`; if `owed > MAX_TICKS_PER_FRAME`, `n = MAX_TICKS_PER_FRAME` and `acc = 0.0` (the owed time beyond the cap and the fractional remainder are **dropped, not banked**, so the game slows during a stall and never fast-forwards after it); otherwise `n = owed` and `acc -= owed * DT`. **`acc` is updated before the loop**, and only then are the `n` ticks run, so a `zero()` called from inside the loop (a pause landing while ticks are still owed, Decision 9) leaves `acc == 0.0` and never a negative debt. After every `advance`, `acc` is in `[0, DT)`, so a long Build phase, in which `Battle.tick` returns at once, cannot bank time. The rule is right as written (godot-specialist, with a model): the drop branch needs `acc >= 4 x DT` (about 67 ms) at cap 3, so at 60 fps with jitter `owed` is 0 or 1 and the remainder is carried (6000 frames at +-1 % ran 6000 ticks), and a slow device loses time in proportion to its deficit, which is the intended "slows, never jumps"; zeroing the fraction costs at most one partial tick per stall event. The first frame of a run was observed with a 65 ms `delta` (windowed, two runs): the cap branch fires and is harmless, since Build runs no ticks and a retry's new wrapper gets a normal frame. A resume frame (Flow Rule 17: on desktop the refocus click may also be the resume tap) can run up to the cap's ticks from that frame's own `delta`; the Clock row's "a resume runs 0 ticks" means 0 ticks from time owed **before** the pause. A negative or non-finite `frame_delta` is treated as 0 and reported through `dev_error`. `acc` is a 64-bit float used only by the presentation layer; it never reaches the sim, which sees only tick counts, so its rounding cannot change a result.

**4. The Clock and `stop_clock()`.** `Clock extends RefCounted` in `src/presentation/clock.gd`; the wrapper builds it in `setup()` (ADR-0001 Decision 10), holds it in a typed field, and drives it. It never lives in `src/battle/` and `Battle` never holds it. It receives `battle.tick` as a method Callable (target held by the wrapper's `Battle` field, ADR-0001 Decision 5), `dt`, the cap (`Clock.MAX_TICKS_PER_FRAME`, floored at `MIN_CAP`) and `dev_error`. `BattleWrapper.stop_clock()` calls `Clock.stop()`: sets `running = false`, `acc = 0.0`; idempotent; a stopped Clock returns 0 from `advance` and cannot be restarted (a retry builds a new wrapper and a new Clock). `AppRoot` calls it before `cancel_input()` and teardown on retry and on Fatal (ADR-0001 Decisions 6 and 7). Won and Lost do not stop the Clock: the in-sim gate (Decision 5) makes the remaining ticks no-ops, and the wrapper's frame work (HUD, views) must keep running to show the result.

**5. The in-sim clock gate.** `Battle.tick(dt)` returns at once unless `halted()` is false **and** Flow's phase is WAVE or INTERMISSION. Build runs no ticks (Flow Rule 6 and 10: a stopped clock; a pin in Build places the hero at once through `in_build()`); Paused, Won, Lost and Fatal run none. The gate lives in the sim, so it holds headless. A `dt` argument other than `Battle.dt` is a defect reported through `dev_error` and the tick returns; the argument exists for the harness and signature stability (ADR-0001 Key Interfaces), not for variable time. The comparison is a bit-exact compare of the same constant and is meant as written (it draws the float-equality lint; the lint gets a named exception for this line). `Battle.tick` sets a private in-tick flag for its duration and `Battle.in_tick()` reads it (Decision 7). **`Flow.phase()` returns `FATAL` whenever the battle `FatalLatch` is set.** Flow reads the latch through an injected method Callable, `Battle.is_fatal()` (the same pattern as `battle.halted`; `Battle` holds the latch and Flow holds no reference back), so `phase()` reads FATAL from the moment the latch sets, before `phase_changed(FATAL)` is emitted. ADR-0006 owns the once-only emit and its timing; ADR-0005's, the HUD's (`phase() == FATAL`) and the wrapper's `_paused` reset (Decision 8) rely on this read.

**6. The one tick order.** Inside `Battle.tick`, after the gate, in this order, every tick (Intermission included):

| Slot | System | Work |
|---|---|---|
| 1 | Flow `tick` | intermission countdown (integer ticks), wave start and clear checks |
| 2 | EnemyWave `advance(tick)` | spawn from the absolute schedule, move, leak (leaks resolve before fire) |
| 3 | Combat `tick_status(roster)` | slow countdown over the roster |
| 4 | TowerSim `tick` | by ascending slot index: cooldown, target, `report_attack`, deliver |
| 5 | HeroSim `tick` | walk, attack, cooldown, telegraph, release; burst after hero |
| 6 | EnemyWave `reap` | remove corpses, emit `enemy_killed(bounty)` once each |

`halted()` is checked before slot 1 and after every slot, and each sim checks it after every accessor read and emit (TR-state-007, TR-enemy-005, TR-tower-006); once true the tick returns and later slots do not run. There is no seventh slot: an outcome commits inside the slot that causes it (a leak in slot 2, the last kill's `waves_completed` in slot 6) and Flow's transition rules (commit, act, emit, check the latch) run from there. Because the Hero slot (5) precedes the reap (6), a burst that kills the last enemy releases on the tick the stage is won, and its BURST `attack_fired` precedes `phase_changed(Won)`; a latched outcome (a fatal leak in slot 2, or Fatal) stops later releases because slot 5 sees `halted()` (TR-hero-016; its last clause is ADR-0011's). Waves use no randomness, so no slot draws from the RNG at MVP (Decision 10). This is the order Flow Rule 5, Combat Rule 11, Enemy & Wave Rule 12 and Tower Rule 9 cite; they restate it and do not define it.

**7. Frame order and commands between ticks.** Per frame:

1. Engine, before any `_process`: buffered input is flushed (verified on desktop, ADR-0003; provisional on D1). `InputAdapter` callbacks run, the resolver emits, and `HeroInput`, `TowerInput` and `HudLogic` **issue commands synchronously from that call stack**: a command is applied the instant its gesture resolves, not queued. This is "between ticks" because ticks run only inside `Clock.advance`, which is called only from the wrapper's `_process`, and engine callbacks run one after another on the main thread (the premise of Verification item 2). A command therefore never runs inside a tick. The **command guard** is in the sim: `Battle.tick` sets a private in-tick flag and exposes `in_tick()`; Flow, TowerSim and HeroSim receive `battle.in_tick` as a method Callable and their command methods, when it is true, report through `dev_error` and refuse (the result code is ADR-0010's). This catches the realistic breach, a listener of a signal emitted inside a tick that issues a command, in every headless test (commands never pass through the wrapper, and bots run with no Clock). `Clock.is_ticking()` stays, for Verification item 2's lifecycle log only.
2. `BattleWrapper._process(delta)`, in this order and nothing else:
   a. compute `view_dt` (Decision 8: 0 while Paused, else the delta clamped to 0.1 s);
   b. real-time models: `HudLogic.advance(view_dt * 1000.0)` (it clamps to 100 ms itself), `ChipWindow.advance(view_dt * 1000.0)`, `HeroInput.update()`, then the view clocks (`ClearanceWindow.advance(view_dt)`, flash timers, the hero view);
   c. `Clock.advance(delta)`: zero up to `MAX_TICKS_PER_FRAME` calls to `battle.tick(DT)`;
   d. views read the committed state (rosters, slot state, hero queries, HUD view-models), and mark themselves for redraw. **The Call button's bonus and seconds-left are read here, after the ticks, from the same `intermission_left` the command will read, and are never cached in `HudLogic.advance`** (ADR-0011's redraw key must honour this).

   This puts the real-time models **before** the ticks, as TR-hud-005 and `architecture.md` Data Flow 1 state ("input commands, then real-time models, then ticks, then views"). It differs from the order in this ADR's brief (ticks, views, then HUD `advance`). The cost of the TR-hud-005 order is that an outcome latched during this frame's ticks is first seen by `HudLogic.advance` one frame later (one frame: about 17 ms at 60 fps and 33 ms at the floor, or the length of a stall, before its 400 ms text timer starts), so for that one frame the field shows the outcome and the HUD text does not, which is accepted; the gain is that the snapshot is built in `advance`, never inside a tick's signal stack (HUD Rule 15), and that the displayed bonus equals the paid bonus (TR-hud-005) **provided** step 2d reads it after the ticks as stated there: a tap in the next frame's input is applied before that frame's ticks, on the state step 2d displayed. (`HudLogic.advance` in step b and the views in step d read sim state one tick apart inside the same frame; the HUD GDD accepts that. `queue_redraw()` from step d draws in the same frame.) RunLog's flush rides `advance` (ADR-0010).
3. Everything is in `_process`. No `_physics_process` exists, and no node other than the wrapper drives the Clock.

**8. View clocks and Pause.** The wrapper tracks `_paused`, set when `phase_changed` announces PAUSED and cleared by any other `phase_changed` (the Flow stage machine leaves Paused only for the phase it left or for Fatal). Each frame, `view_dt = 0.0 if _paused else minf(delta, VIEW_DT_MAX)`, with `VIEW_DT_MAX = 0.1` a const on the wrapper, so a first frame (65 ms observed) or a resume from the background cannot hand a jump to any view clock; the Clock keeps the raw `delta` because its cap bounds it, and `HudLogic` keeps its own 100 ms clamp as a second guard. **Every frame-clock consumer receives `view_dt`**: HUD advance, `ChipWindow`, `ClearanceWindow`, flash markers, the hero view. So they freeze under Pause with one rule at one site, and views need no pause flag of their own (the alternative). The `HudLogic` rule "ignores `advance` while Paused" (HUD Rule 11) stays as a second guard; with `view_dt = 0` it is not exercised. The clearance window is a pure `RefCounted` whose only input is `advance(frame_dt)`; it is never driven by a sim tick and never by `Clock`, so its 0.15 s tail runs after the battle clock stops at Won, Lost or Fatal (those phases do not gate `view_dt`), and a `phase_changed` to Paused leaves the window as it is and frozen (Combat GDD; TR-combat-015). Won's and Lost's 0.4 s text beat is the HUD's 400 ms timer on the same `view_dt` (HUD Rule 15, TR-state-014). Reduce Motion's effect on frame-clock timers is the HUD GDD's (cut slides, fades and clock bars stay); it is cited here and not decided. The cosmetic RNG (Decision 10) is drawn only from this layer.

**9. Lifecycle notifications relative to the tick.** The adapter handles notifications in its own `_notification` (ADR-0003 Decision 8) and emits `lifecycle_paused`, which the wrapper has connected to `Flow.pause`. The engine runs callbacks on the main thread one after another, so the expectation is that a notification is delivered between callbacks, never inside the synchronous `Clock.advance` loop; this is NOT SOURCEABLE and is Verification item 2. What is sourced: input is flushed at frame start and an event queued during `_process` arrives next frame (`modules/input.md`, Verified on 4.7.2). Engine structure, from engine-source knowledge and not the local reference: desktop OS events are pumped between main-loop iterations, Android posts lifecycle and input callbacks to the render thread's queue, run between frames, and iOS callbacks share one run loop, so engine-driven re-entrancy into `_process` is not expected on any target; the review probe's 90 busy-looped frames saw none, but induced no focus change, so item 2 stays. The one path this ADR does not close by itself is **project-driven** synchronous dispatch: `Viewport.size_changed` was observed firing from the caller's stack of `window_set_size` (ADR-0003 spike), and `OS.alert`, `DisplayServer.dialog_show` or an `await` would pump events from inside the loop; the guideline below forbids them. The design does not need it to be true for safety against a **between-ticks** landing: if Flow pauses while the loop still owes ticks, `Battle.tick` returns at once for the rest (the gate) and the wrapper's phase handler zeroes the accumulator, so a resume runs 0 ticks. A landing **inside** a tick is the one case not covered: Flow would commit PAUSED while later slots still see `halted()` false. A debug-build listener on `lifecycle_paused` logs it through `dev_error` if `Clock.is_ticking()` is true, and a device run must show it never happens before this ADR is Accepted for phone builds. Pause, as Flow Rule 17 says, zeroes `acc`, stops ticks through the gate, cancels input, and `SceneTree.paused` is never set (registry: `scene_tree_paused_for_flow_pause`).

**10. Determinism and the RNG.** There is one gameplay RNG: `Battle` creates `RandomNumberGenerator.new()` in `build()`, assigns `seed = rng_seed` (an explicit seed; `randomize()` is never called) and holds it in a typed field. At MVP **no system receives it**: Enemy & Wave is authored with no randomness and never reads the seed (Rule 6, GDD case 42: "a spy shows the seed never read"), and no other MVP system draws. A system that later needs randomness receives a method Callable on `Battle` (never the generator itself, never a lambda), and every draw happens inside a fixed tick slot, so the consumption order is the tick order and one stream stays reproducible. Adding the first consumer requires revising this ADR and the registry. The **cosmetic RNG** is a separate `RandomNumberGenerator` held by the wrapper, seeded at setup with `rng_seed ^ COSMETIC_SALT` (so a retained screenshot is reproducible), used only by views for jitter; the sim never sees it and nothing it produces feeds back. A global `randi()`, `randf()`, `randomize()` or `shuffle()` call under `src/` is forbidden (ADR-0007 lint). `RandomNumberGenerator` repeated the same ten values for the same seed across instances and runs on the probed binary (table above); stability across platforms and engine versions is NOT SOURCEABLE from the local reference. From engine-source knowledge (unverified here): the generator is PCG32 and integer-only, so `randi`, `randi_range`, `randf` and `randf_range` give the same sequence on every architecture, while `randfn` goes through libm (`log`, `cos`) and is the one platform-sensitive draw; the ADR-0007 lint therefore bans `randfn` and the transcendental functions under `src/battle/`. The baselines stay per host and per engine version as the backstop (Decision 12).

**11. Seed source and the retry seed.** `AppRoot` chooses the seed, through a small `SeedSource extends RefCounted` in `src/app/` (testable with a fixed base). MVP rule: `base = int(Time.get_unix_time_from_system())` read once in `_ready()`; the first battle uses `base`; each retry `n` (1, 2, ...) uses `base + n`, a **fresh seed per retry**. `AppRoot` owns the attempt counter `n`, which restarts at 0 at every launch; the retry comparison battle uses `base + n`, and `snapshot()` includes `rng.state`, so the equality covers the seed. `AppRoot` records the seed and attempt index through the wrapper-built RunLog (ADR-0010 owns the schema). The retry snapshot test builds its comparison battle with the **retry's** seed (ADR-0001 Decision 7). Bots and tests pass explicit seeds to `build()` and never touch `SeedSource`. `AppRoot` is not under `src/battle/`, so reading `Time` there does not break ADR-0001's ban. Because MVP waves read no randomness, a retry reproduces the same spawn schedule and `spawn_id`s regardless of seed (TR-enemy-007), and the fresh seed costs nothing now and keeps the seam honest later. No dev override flag is added at MVP; a command-line override would need `OS.get_cmdline_user_args()`, which the reference does not cover.

**12. Float policy, baselines and the determinism test.** Gameplay arithmetic uses GDScript `float` (64-bit, observed). `Vector2` components are 32-bit (observed, ADR-0002 probe and this one). Decision (QQ-05): **PinGeometry and every range check use float scalars with +, -, x, / and square root, with no `Vector2` method and no `Vector2` operator** (`a - b` and `v * s` also compute in 32 bits); `.x` and `.y` are read into `float` locals at the boundary (TR-hero-006, the Hero GDD's choice); positions cross the boundary as `Vector2` at the edges (enemy `position` is cached once per tick, Combat GDD), and the sub-0.0001 error of the 32-bit round trip is inside the Hero GDD's 0.01 margins. Determinism is therefore guaranteed on one OS, one CPU architecture and one engine build, not across them (TR-combat-014). From engine-source knowledge (unverified here): 64-bit `+ - * / sqrt` are IEEE correctly rounded on x86_64 and arm64, so divergence would come from transcendental functions and compiler float contraction inside engine C++; a macOS arm64 editor and an Android or iOS arm64 export are different builds. Cross-architecture float equality is NOT SOURCEABLE. Bot baselines are kept per host, one file each, named `tests/baselines/<stage_id>_<bot_id>_<os>_<arch>_<major.minor.patch>.txt`, with `<os>` from `OS.get_name()` and `<arch>` from `Engine.get_architecture_name()` (`arm64` observed on the dev host; `x86_64` expected on CI, Verification item 4), both lower-cased and repeated in the file header. The extension is not `.json` on purpose (below). Baselines exist **only for hosts that run the suite**: CI (`ubuntu-latest`, x86_64) and the developer's macOS arm64 machine, so each stage-and-bot pair has two files and the x86_64 one can only be produced on CI. Device determinism is Verification item 4's job, not the baseline test's. arm32 (`armeabi-v7a`) exports are **unsupported at MVP**: the Android export preset ships arm64 only, so no arm32 baseline is needed; enabling it later requires a baseline for it first. A baseline missing for the running host is a test **failure** with the message "no baseline for <os>_<arch>", not a skip, and the regeneration path is ADR-0007's runner mode that writes the missing candidate file as a CI artifact for review and commit; `NOT ASSESSED` reporting belongs to ADR-0007's runner. The "same stage, seed and script give an identical result" test (Flow GDD Full determinism row) builds two battles with the same `(catalogue, stage_id, seed)`, feeds both the same command script on the same tick numbers, and requires equal `Battle.snapshot()` after N ticks and at the outcome. The snapshot is a plain nested `Dictionary` built from each sim's own `to_dict()` (the ADR-0002 record-snapshot approach; not `duplicate_deep()`): tick count, Flow phase, lives, intermission ticks, gold, each tower's level and `cooldown_left`, the hero's position, state and `cooldown_left`, the roster in `spawn_id` order (id, distance, hp, slow ticks), Combat's counters, and the RNG state (`rng.state`). Floats compare bit-exact on the same host; a cross-host run compares nothing. Snapshots and baselines are written and read with `var_to_str`/`str_to_var`, **never JSON**: the review probe showed JSON turning `rng.state` 2343518260280137770 into the float 2343518260280137728.0 (and the int-versus-float `==` then reports true, so a JSON check of the state would be vacuous) and `0.1 + 0.2` into 0.3, while `var_to_str` round-tripped exactly with `state` still an int.

**13. `to_ticks` and `Battle.dt`.** `to_ticks(seconds) = roundi(seconds / dt)`, halves away from zero (probe: `roundi(0.5)` is 1, `roundi(-0.5)` is -1), exposed as `TickRate.to_ticks(seconds, dt)` and as `Battle.to_ticks(seconds)` (the Callable ADR-0001 injects). `ceil` is rejected on the GDD's evidence and reproduced by the probe (`3 * 0.1 / dt` is `18.00000000000000355`, ceil gives 19); `floor` makes an exactly-`dt` interval depend on float noise. The validator's one-tick floor (`MIN_INTERVAL_SECONDS = TickRate.DT`) means every interval is at least one tick (`dt / dt` gives 1). A value below one tick can still round to 0 only if it is below half a tick, which the floor forbids for the intervals that need it; fields that may legitimately be 0 (a `telegraph_duration` of 0) are floored by their owners, as Hero does with `max(1, to_ticks(...))`. Countdowns are integer tick counters (TR-state-012, TR-tower-005). The two content rows ADR-0002 delegated, with the starter values and `dt = 1/60`: (a) the **wave spawn rule**: `spawn_tick(i) = to_ticks(start_delay + i x spawn_interval)` must be strictly increasing within a group (wave 2's `0.6` s interval gives 36 ticks apart, wave 5's `0.4` s gives 24, and the exact-`dt` half-tick-offset case is the one the row guards); (b) the **Hero telegraph travel row**: `fastest move_speed x max(1, to_ticks(telegraph_duration)) x dt <= radius / 2`, with the starter `telegraph_duration` 0.25 s giving 15 ticks, the GDD's `27.5 <= 35`. Both read `TickRate.to_ticks`, never a local copy. `TickRate.to_ticks` has the precondition `dt > 0.0` (always `TickRate.DT` or a test fixture's positive value; `seconds / 0.0` is `inf` and `roundi(inf)` is a garbage int); `Battle.to_ticks`, which the sims call, guards it: `dt <= 0.0` reports through `dev_error` and returns 0.

**14. Frame budget split (Data Flow 10), all unmeasured (QQ-11).**

| Slice | Budget at 60 fps | Status |
|---|---|---|
| Input, resolver, commands | 0.5 ms | unmeasured |
| Simulation ticks | 4.0 ms total; normal frame one tick; at the cap three, so the test is `MAX_TICKS_PER_FRAME` x p99 tick cost at most 4.0 ms | unmeasured; Combat worst case about 400 range checks per tick estimated under 2 ms |
| Views and HUD | 3.0 ms | unmeasured |
| Engine, rendering submit, OS | 7.0 ms | unmeasured |
| Headroom | 2.1 ms | unmeasured |

Measurement plan: on one Adreno 5xx-class phone at the first phone build, with the starter stage's worst wave on screen (wave 6), record 600 frames of `Time.get_ticks_usec()` differences (microsecond resolution observed; never the `_process` `delta`, which is smoothed against the physics step) around `Clock.advance`, around the views and HUD refresh, and for the whole `_process`, in a **release export** with a timing flag (a debug build runs debug GDScript and overstates per-tick cost; record debug figures alongside), and the mean and 99th percentile of the per-tick cost. If time batches of 60 ticks are needed for resolution, report the per-tick mean only. The cap stays at 3 unless the p99 shows a tick dearer than the budget allows; a measured N below 3 is a defect that calls for a cheaper tick, not a smaller cap, and the constant never goes below 2. Revise this table with the figures. Until then every number is an estimate.

**15. Delegations.** Signal names and payloads: ADR-0006. The harness, the baseline test runner and the lints: ADR-0007. Command result codes and the RunLog schema: ADR-0010. The hero view's outcome rows on the frame clock: ADR-0011. The enemy reap internals: ADR-0009.

### Architecture Diagram

```
Engine frame start: input flushed ──► InputAdapter ► resolver ► HeroInput/TowerInput/HudLogic
                                                       └─ commands applied NOW (between ticks)
BattleWrapper._process(delta)                          (no _physics_process anywhere)
 a view_dt = 0 if _paused else min(delta, 0.1)
 b HudLogic.advance(ms) · ChipWindow.advance(ms) · HeroInput.update() · ClearanceWindow.advance(s) · view timers
 c Clock.advance(delta): acc += delta; owed = floor(acc/DT); owed > CAP ? (n = CAP, acc = 0) : (n = owed, acc -= n*DT)   [acc settled BEFORE the loop]
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
static func to_ticks(seconds: float, dt: float) -> int:
	return roundi(seconds / dt)                   # halves away from zero. Precondition: dt > 0.0

class_name Clock extends RefCounted               # res://src/presentation/clock.gd
const MAX_TICKS_PER_FRAME := 3                    # provisional, Verification item 3
const MIN_CAP := 2                                # setup() raises any smaller max_ticks to this
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
func in_tick() -> bool                            # true only while tick() runs; a subset of Battle.in_dispatch() (ADR-0006), which command methods check: they refuse and dev_error when it is true
func is_fatal() -> bool                           # fatal_latch.is_set; injected into Flow so Flow.phase() reads FATAL at once

class_name SeedSource extends RefCounted          # res://src/app/seed_source.gd
func _init(base: int) -> void
func first() -> int                               # base
func retry(attempt: int) -> int                   # base + attempt, attempt >= 1
```

### Implementation Guidelines
- Sim time **must** enter only through `Battle.tick(dt)`; `_process`, `_physics_process`, a `Timer`, `await` or the wall clock **must never** appear in `src/battle/`, and `src/data/` **must never** read a clock (`TickRate` holds constants and one pure function).
- No node in the project **may ever** define `_physics_process`, and project code **must never** read or set `Engine.time_scale`, `Engine.physics_ticks_per_second`, `Engine.max_physics_steps_per_frame` or `Engine.physics_jitter_fix` (ADR-0007 lint).
- The Clock **must** be a `RefCounted` under `src/presentation/`, driven only by `BattleWrapper._process`, **must** cap at `Clock.MAX_TICKS_PER_FRAME` (never below `MIN_CAP` 2), **must** drop (not bank) owed time beyond the cap, **must** settle `acc` before running the ticks, and **must** be zeroed on the transition into Paused.
- `Battle.tick` **must** return at once unless `halted()` is false and the phase is WAVE or INTERMISSION; it **must** run slots 1 to 6 in the order of Decision 6 and **must** check `halted()` after every slot. A new tick participant **must** be inserted into that table by a revision of this ADR, never appended ad hoc.
- A command **must** be applied from the input call stack between ticks and **must never** be queued into, or called from, a tick; sims **must never** call a command method of another sim; command methods **must** refuse and report through `dev_error` when `Battle.in_dispatch()` is true (ADR-0006: `in_tick()` or any sim's `in_command()`).
- Authored durations **must** become ticks through `TickRate.to_ticks` only; countdowns **must** be integer tick counters; no gameplay code **may** subtract `dt` repeatedly from a float.
- The wrapper **must** pass `view_dt` (0 while Paused, else the delta clamped once to 0.1 s) to every frame-clock consumer; a view or HUD object **must never** read the engine's delta itself, and **must never** be driven by a sim tick or a sim signal for its duration.
- The clearance window and every other frame-clock timer **must** be a `RefCounted` advanced by `advance(frame_dt)`.
- `Battle` **must** own the only gameplay `RandomNumberGenerator`, seeded from the injected seed; gameplay code **must never** call global `randi`, `randf`, `randomize` or `shuffle`, nor `randfn` or a transcendental function under `src/battle/`, and **must never** hold the generator itself; the cosmetic RNG **must** be wrapper-held and never reach the sim.
- PinGeometry and the range-check helpers **must** use float scalars read from `.x` and `.y` at the boundary and **must never** call a `Vector2` method (`length`, `distance_to`, `normalized`, `dot`, `lerp`) or use a `Vector2` operator.
- Bot baselines **must** be per host (OS, architecture, engine version), named as in Decision 12, stored with `var_to_str` and **never** as JSON; a missing baseline **must** fail the test.
- `AppRoot` **must** call `stop_clock()` before `cancel_input()` and teardown; the retry seed **must** differ from the first (`base + n`) and be recorded through RunLog.
- `Flow.phase()` **must** return `FATAL` whenever the battle latch is set, through the injected `battle.is_fatal` Callable.
- The Call button's bonus and seconds-left **must** be read in the view step after the ticks and **must never** be cached by `HudLogic.advance`.
- Nothing reached from `Clock.advance` (the wrapper's step c, every sim, every synchronous handler of a sim signal) **must ever** call a `DisplayServer`, `Window` or `OS` method or `await`; `src/battle/` has this through ADR-0001, wrapper-side handlers must follow it.

## Alternatives Considered

### Alternative 1: Drive the tick from `_physics_process`
- **Description**: Set the project's physics rate to 60 and call `battle.tick(1.0 / 60.0)` once per physics step.
- **Pros**: The engine owns the accumulator and the catch-up; less custom code.
- **Cons**: Depends on `Engine.physics_ticks_per_second`, `max_physics_steps_per_frame` (default 8, observed) and their catch-up behaviour, none of which the reference documents; a second callback order to reason about against input and `_process`; `max_physics_steps_per_frame` is settable, so the cap is not the reason against it; there is no physics in the project, so the loop would exist only for the tick.
- **Rejection Reason**: Unsourced catch-up semantics on the one thing that must be exact, and `_process` gives one callback order with input and the HUD; the custom accumulator is about 20 lines, headless-testable with a fake Callable, and keeps the cap ours.

### Alternative 2: Variable `dt` per frame
- **Description**: Pass the frame delta to `tick`.
- **Pros**: No accumulator.
- **Cons**: Results depend on frame time; bots and humans diverge (the prototypes' numbers did not transfer); no determinism.
- **Rejection Reason**: Contradicts Flow Rule 4 and TR-state-003.

### Alternative 3: Cap of 2 or 4 ticks per frame, or bank the owed time
- **Description**: A cap of 2 (equal to real time at an even 30 fps), a cap of 4 (covers down to 15 fps), or carrying the remainder so the game catches up after a stall.
- **Pros**: Cap 2 fits the 4.0 ms slice at the 2 ms estimate; cap 4 and banking give full speed on slower devices.
- **Cons**: Cap 2 ran 98.9 % of real time at +-1 ms jitter and 97.3 % at +-3 ms at 30 fps (TD simulation); cap 4 feeds a spiral (slow frame, more owed ticks, slower frame) and costs 8 ms at the estimate; banking makes a hitch fast-forward, and a backgrounded app would return with a time jump (probe model: 646 ticks against 610 after ten 100 ms stalls, the extra arriving as a catch-up).
- **Rejection Reason**: Cap 3 gives 100 % in the jitter cases and still bounds a spiral; Flow's edge case says the game slows rather than jumping. Revisit with Verification item 3.

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
- A device slower than about 30 fps runs the game in slow motion rather than catching up, in proportion to its deficit.
- The cap of 3 is an estimate; if the measured tick is dearer than the budget allows, the 30 fps floor needs a cheaper tick, not a smaller cap.
- Baselines multiply by architecture and engine version, and a new platform means a new baseline.
- The HUD sees an outcome one frame later than the tick that made it (Decision 7); for that frame the field and the HUD text differ.
- There is no render interpolation: a 60 Hz tick on a 90 or 120 Hz display, or with jitter at 60, gives frames with 0 or 2 ticks, which shows as judder. ADR-0011 decides whether to interpolate or accept it.
- A notification landing inside a tick is unprotected until a device run shows it cannot happen.

## Risks
- **`_process` delta is not what the reference implies (first frame, resume from background, `time_scale`, `physics_jitter_fix` smoothing).** Observed: a 65 ms first-frame delta (two windowed runs) and per-frame deltas smoothed against the physics step with a matching long-run sum. Mitigation: the cap and `acc = 0` bound any single frame to 3 ticks, the first frame is harmless because Build runs no ticks, `view_dt` is clamped to 0.1 s, the project sets none of the four settings, and Verification item 5 records device values.
- **Input is not flushed before `_process` on a device (ADR-0003 D1).** Mitigation: this ADR's premise is marked provisional; a failure reopens Decision 7 and the Approved HUD and Input rules (QQ-22).
- **A lifecycle notification lands inside `Battle.tick`.** Mitigation: `Clock.is_ticking()` debug check; Verification item 2; if observed, Flow's `pause()` is deferred to the next frame start by a latch in the wrapper (a revision of this ADR).
- **Someone adds a random draw, a `Vector2` method or a float countdown to a sim.** Mitigation: the ADR-0007 lints and the determinism and baseline tests.
- **ARM and x86 baselines drift or the engine version changes the RNG sequence.** Mitigation: baselines are named by architecture and engine version; a missing one fails; an engine upgrade regenerates them under review.
- **The cap is wrong for the phone.** Mitigation: the measurement plan (release export); the constant is one line and never goes below 2.
- **A signal listener issues a command inside a tick.** Mitigation: the in-tick guard in the command methods (Decision 7) and its validation row.
- **Stale GDD rows.** The Flow GDD's Clock deferred row and its question on the clamp value, and the Enemy & Wave "strictly increasing ticks" row, change when this ADR is Accepted.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-003: sim time only through `battle.tick(dt)` at a fixed rate; wrapper clamps owed ticks | Decisions 1 to 5 |
| game-state-stage-flow.md | TR-state-004: one fixed order; commands only between ticks | Decisions 6 and 7 |
| game-state-stage-flow.md | TR-state-005: all randomness from an injected seed; same stage, seed and script give an identical result | Decisions 10 to 12 |
| game-state-stage-flow.md | TR-state-006: pure stage machine, Fatal absorbing, `in_build()` | Decision 5 (gate by phase; `Flow.phase()` reads FATAL whenever the latch is set); machine itself is Flow's |
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
| hero-system.md | TR-hero-016 (registered 2026-11-05): the Hero slot precedes the reap, so a last-enemy burst releases on the Won tick and a latched outcome stops later releases; the hero view's outcome rows run on the frame clock | Decision 6 covers the slot order and the halt; the frame-clock clause is delegated to ADR-0011, with Decision 8's rule |
| battle-hud.md | TR-hud-005: each frame runs commands, then real-time models, then ticks, then views | Decision 7, with the condition that the Call bonus and seconds-left are read after the ticks, never cached in `advance` |
| battle-hud.md | TR-hud-007: armed buttons on a real-time `advance(ms)` clock, clamped to 100 ms, frozen while Paused | Decisions 7 and 8 (`view_dt` is 0 under Pause; the clamp is HudLogic's) |

## Performance Implications
- **CPU**: One tick per frame in the normal case, at most two; the tick slice is 4.0 ms (unmeasured). The Clock adds a division and a loop per frame. The snapshot and baselines run only in tests.
- **Memory**: One `RandomNumberGenerator` per battle, one cosmetic generator, one Clock; no per-frame allocation in the Clock.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
Greenfield: `src/` holds no `.gd` file. Create `src/data/tick_rate.gd`, `src/presentation/clock.gd`, `src/app/seed_source.gd`; add `rng`, `tick`, `to_ticks`, `snapshot`, `in_tick`, `is_fatal` to `Battle` and inject `is_fatal` into Flow and `in_dispatch` (ADR-0006, which includes `in_tick`) into Flow, TowerSim and HeroSim; point `catalogue_schema.gd`'s floor at `TickRate.DT` (ADR-0002) and add its two `to_ticks` rows. Copy the probe to `prototypes/adr-0004-probe/` (done with this ADR). The Flow, Combat, Enemy & Wave, Tower and Hero GDD tick-order restatements already cite the order and need no edit except the rows listed under Risks.

## Validation Criteria
- Clock row (Flow GDD): a frame owing more than the cap runs exactly `MAX_TICKS_PER_FRAME` ticks and the accumulator is 0 afterwards (cap test, fake Callable); a frame owing less leaves `acc` in `[0, DT)`. Branch pins against a "helpful" rewrite: a frame sequence alternating `0.99 x DT` and `1.01 x DT` over N frames (N even) runs N ticks (within the one tick end-of-run float rounding can move) and leaves `acc < DT`; a single 70 ms frame at cap 3 runs 3 ticks and leaves `acc == 0.0`; a fixed jittered 30 fps sequence (33.3 ms +-3 ms, 18,000 frames) runs at least 99.9 % of real time at cap 3; `setup` with `max_ticks` 1 behaves as 2.
- Mid-loop zero: a fake tick Callable that calls `clock.zero()` on its first call leaves `acc == 0.0` after `advance`; the first frame with a 65 ms delta runs at most 3 ticks and leaves `acc == 0.0`.
- Command guard: a slot listener that calls `start_wave` mid-tick records one `dev_error` and changes nothing.
- Fatal read: a spy in slot 3 fires the latch; `phase()` reads FATAL at once with no `phase_changed` seen yet, slots 4 to 6 do not run, and one `phase_changed(FATAL)` follows (ADR-0006 owns the emit).
- Displayed equals paid: on a wrapper-level fixture, after frame N the Call button's displayed bonus equals what `call_early` pays when issued from frame N+1's input before that frame's ticks, at Intermission tick counts on either side of a bonus step.
- View clock gate: `view_dt` is 0 under Paused and at most 0.1 s otherwise; a 65 ms and a 2 s delta give 0.065 and 0.1.
- `to_ticks`: `Battle.to_ticks` with `dt <= 0` reports one `dev_error` and returns 0.
- Pause-zeroing test: `phase_changed(PAUSED)` zeroes `acc`, so a resume runs 0 ticks from time owed before the pause; the Flow GDD's criterion 12 holds (A, B and C do not tick during the 100; one tick adds 1 after a resume to Wave or Intermission, none to Build).
- Order test: recording systems in slots 1 to 6 log the listed order; `halted()` latched after slot N skips slots N+1 to 6; a burst that kills the last enemy releases before `phase_changed(Won)` (TR-hero-016).
- Full determinism row: two battles with the same seed and script give equal `snapshot()` at every checked tick and at the outcome; two seeds give equal logs and a spy shows the seed never read (Enemy & Wave case 42).
- Retry: the comparison battle uses the retry's seed; `SeedSource.retry(n)` differs from `first()`.
- `to_ticks` rows: 0.9 s is 54, 5.0 s is 300, 1/60 s is 1, 0 is 0, 0.125 s at `dt` 0.25 is 1 (Enemy & Wave cases 37 to 39).
- Per-architecture baseline test: the bot baseline for the running architecture and engine version exists and matches; a missing one fails.
- Lints (ADR-0007): no `_physics_process`, no `Engine.time_scale` and its siblings, no global random call under `src/`, no `Vector2` method in PinGeometry, no `Time`/`Engine` read under `src/battle/`.
- View clock tests: `ClearanceWindow.advance` with `view_dt` 0 holds its value; it keeps counting at Won, Lost and Fatal; a retry clears it.
- Baseline storage: a snapshot with `rng.state` 2343518260280137770 and a float `0.1 + 0.2` written with `var_to_str` and read back with `str_to_var` compares equal, with `state` still an int; no baseline file has a `.json` extension.
- Device run (before the first phone build, with ADR-0003 D1 to D4), one pass condition per Verification item: V1 input log lines precede the frame's first `_process` mark; V2 `Clock.is_ticking()` is false at every lifecycle notification over at least 20 background cycles; V3 the Decision 14 table is measured in a release export and the cap is set (not below 2); V4 the probe on Android, iOS, x86_64 desktop and the CI runner gives the same RNG values and `roundi` results, `Vector2` 32-bit, `Time.get_unix_time_from_system()` a float, and records the `OS.get_name()` and `Engine.get_architecture_name()` values (a difference is recorded, not hidden); V5 first-frame and resume deltas are recorded and no view clock jumps more than 0.1 s; V6 `Time.get_ticks_usec()` resolution is recorded (if coarse, ticks are timed in batches of 60); V7 the four settings are unused: the lint passes, nothing else is verified.

## NOT SOURCEABLE
Not covered by `docs/engine-reference/godot/`; seven items, each mapped to a Verification item and a Device run row. Nothing above depends on any of them being true.
- NOT SOURCEABLE: `_process(delta)` versus `_physics_process(delta)` semantics, including the first-frame delta (65 ms observed windowed), the delta after a resume from the background, whether `Engine.time_scale` scales `delta`, and the smoothing by `physics_jitter_fix` (observed: 9.4 ms delta against 1.0 ms wall on one frame, long-run sum matching; the mechanism is engine-source knowledge). Verification items 5 and 7.
- NOT SOURCEABLE: what `Engine.physics_ticks_per_second` and `Engine.max_physics_steps_per_frame` do (only default values 60 and 8 were read; the project does not use them). Unused; not verified (item 7).
- NOT SOURCEABLE: float determinism across ARM and x86 and across engine versions, and `RandomNumberGenerator` stability across platforms and versions (repeatability was observed on one binary and host only; PCG32 being integer-only and `randfn` and transcendental calls being the sensitive ones is engine-source knowledge, unverified here). Item 4.
- NOT SOURCEABLE: that a lifecycle notification or an input callback is never dispatched inside the synchronous `Clock.advance` loop (ADR-0003 lists the same item); project-driven dispatch is closed by a guideline, engine-driven dispatch is not verified. Items 1 and 2.
- NOT SOURCEABLE: `Time.get_ticks_usec()` resolution on a device and `Time.get_unix_time_from_system()`'s return type on a device (microsecond resolution and a float were observed on desktop). Item 6 and item 4.
- NOT SOURCEABLE: the values of `Engine.get_architecture_name()` other than `arm64` (observed on the dev host), and of `OS.get_name()`, on CI and on devices. Item 4.
- NOT SOURCEABLE: `Vector2` precision on a device (single precision observed on desktop in the ADR-0002 probe and in this one). Item 4.

## GDD and Registry Sync at Acceptance
- Flow GDD: the Clock deferred row gets the cap (3, provisional, floor 2); the open clamp question closes; the Full determinism row cites Decision 12.
- `tr-registry.yaml`: TR-hero-016 was registered by `/architecture-review` on 2026-11-05 (done).
- `architecture.md`: Data Flow 1 order (real-time models before ticks) is confirmed; QQ-01 and QQ-05 close; QQ-11 stays open; QQ-22 stays open until the device run.
- Registry stances appended to `docs/registry/architecture.yaml` when this ADR is Accepted:
  - Interface contracts: `tick_entry` (Clock.advance drives `Battle.tick(DT)` from the wrapper's `_process` only; the gate; the six-slot order with `halted()` between slots); `commands_between_ticks` (applied synchronously from the input call stack, never queued; the `Battle.in_tick()` guard); `view_clock` (`view_dt` = 0 under Pause else the delta clamped to 0.1 s, to every frame-clock consumer, never a sim tick; the Call bonus read after the ticks); `flow_phase_fatal` (`Flow.phase()` reads FATAL whenever the latch is set, via `Battle.is_fatal`).
  - Performance budgets: 60 fps / 16.6 ms on mobile, with per-system slices input and commands 0.5 ms, simulation ticks 4.0 ms (the tick slice, unmeasured), views and HUD 3.0 ms.
  - API decisions: `tick_driver` (accumulator Clock in `_process`, 60 Hz, cap 3 floor 2, owed time dropped); `authored_time_to_ticks` (`roundi`, halves away from zero, integer countdowns); `gameplay_rng` (one `Battle`-owned generator, no MVP reader, wrapper-held cosmetic RNG); `float_policy` (scalar floats, no `Vector2` method or operator, per-host baselines); `baseline_storage` (`var_to_str`, never JSON); `retry_seed` (`base + n`, recorded).
  - Forbidden patterns: `physics_process_anywhere` (including the four settings), `sim_time_outside_tick`, `command_inside_tick`, `view_clock_on_sim_tick`.

## Related
- `docs/architecture/architecture.md`: Required ADRs (ADR-0004), Data Flow 1, 2, 6 and 10, B4, B5, QQ-01, QQ-05, QQ-08, QQ-11, QQ-22.
- `design/gdd/game-state-stage-flow.md` Rules 4, 5, 6, 10, 17, Edge Cases (long frame), Clock and Full determinism rows; `combat-damage.md` Rule 11, Burst clearance, View clocks; `enemy-wave.md` Rule 6, Formulas (`to_ticks`); `tower-system.md` Rule 9; `hero-system.md` Rules 8, 9, telegraph; `battle-hud.md` Rules 11 and 15.
- ADR-0001 Decisions 2(d), 6, 7 and 10; ADR-0002 Ordering Note; ADR-0003 Decision 8 and the NOT SOURCEABLE section.
- Probes: `prototypes/adr-0004-probe/probe.gd` (drafter) and `prototypes/adr-0004-probe/review/` (godot-specialist: `main.gd`, `main2.gd` and their scenes).
