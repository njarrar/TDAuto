# ADR-0004: Fixed-Tick Clock, Tick Order, Frame Order and Determinism

## Status
Accepted

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation.

## Date
2026-11-04

## Last Verified
2026-11-04 (against `docs/engine-reference/godot/` for Godot 4.7.2, `architecture.md` v4, ADR-0001 to ADR-0003 as Accepted, and `docs/registry/architecture.yaml`; revised after godot-specialist and TD-ADR reviews)

## Decision Makers
- Accepted: 2026-11-04 by the user (njarrar); also records the user's sign-off on QQ-08's tick-order part (one tick order, Combat Rule 11), accepting that towers act before the hero
- Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`)
- godot-specialist: CONCERNS; TD-ADR: CONCERNS. Findings resolved under Reviews.
- Acceptance: the user. QQ-08's tick-order part is accepted only with this ADR.

## Summary
Every battle system needs one source of sim time, one fixed order inside a tick and one order inside a frame, so a battle is a function of `(catalogue, stage_id, rng_seed, command script)` and the bonus the HUD shows is the bonus paid. This ADR decides a 60 Hz fixed tick from a pure `TickClock` in `BattleWrapper._process` (not `_physics_process`), capped at 4 ticks per frame, with rendering capped at 60 fps; the six-step order in `Battle.tick`; a `TickGuard` that refuses commands during a tick; `TickMath` in Foundation as the home of the tick constant and `to_ticks`; no sim randomness at MVP with per-consumer seeded streams reserved; and scalar float maths with baselines per OS and CPU.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D) |
| **Domain** | Core (main loop timing and determinism) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH. The pinned reference says nothing about `_process` timing, frame caps, physics stepping, `RandomNumberGenerator` or `Vector2` precision. Load-bearing: `_process(delta)`, `application/run/max_fps`, plain arithmetic, and the two pinned physics settings `physics/common/physics_ticks_per_second` 60 and `physics/common/max_physics_steps_per_frame` 8, since the engine caps `_process` delta at about their ratio (E3, Guideline 11). |
| **References Consulted** | `docs/engine-reference/godot/` (`VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/physics.md`, `modules/input.md`); `architecture.md` v4 (Composition Root, Data Flow 1 to 3, 6, 10, B0, B4 to B9, Required ADRs, QQ-01, 05, 08, 11); `tr-registry.yaml`; ADR-0001 to ADR-0003; the registry; GDDs under Related |
| **Post-Cutoff APIs Used** | None. Used: `_process(delta)`, `RefCounted`, `roundi`, `floori`, `sqrt`, `Vector2` storage, project settings below, `RandomNumberGenerator` (reserved). `breaking-changes.md` lists no change to them in 4.4 to 4.7. Checked in the reference: Jolt became the 4.6 default for 3D only; 2D stays on Godot Physics 2D, and the sim uses no physics at all (Flow Rule 4). |
| **Verification Required** | E1 to E8 are verified 4.7.2 headless (`docs/engine-reference/godot/probe-results.md`); E3 was wrong and is corrected (Amendments, V11 table). S1 (ADR-0003) still runs but no longer gates TR-hud-005 (Decision 4). V13 on a phone. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): `Battle` holds `TickMath` and `HaltGate`; the wrapper holds the clock; `rng_seed`; no `SceneTree.paused`; teardown "stop the Clock"; method Callables only. ADR-0003 (Accepted): input path, `lifecycle_paused` to `Flow.pause`, S1. |
| **Enables** | ADR-0002 floor check (`TickMath.TICK_SECONDS`), ADR-0006, ADR-0007 (lints, V1 to V12), ADR-0008 (`drag_cancelled` emit on cancel), ADR-0009 (per-tick budget), ADR-0010 (`IN_TICK` result, command scripts), ADR-0011 (view refresh, interpolation) |
| **Blocks** | No epic or story exists yet. After `/create-epics`, stories that build `Battle.tick`, `TickClock`, `TickMath`, a sim tick entry, a real-time model or a bot harness wait for acceptance. |
| **Ordering Note** | Before ADR-0006. Decision 7's final `MAX_TICKS_PER_FRAME` waits for the first phone build and changes by amendment. |

## Context

### Problem Statement
Four GDDs restate a tick order and three name a real-time clock; all assume one fixed `dt` and one `to_ticks`, but none says where ticks come from. Architecture v4 leaves the driver (QQ-01), clamp, float policy (QQ-05), the frame order behind TR-hud-005 and the frame budget (QQ-11) here. ADR-0002's floor check needs a tick constant.

### Current State
No game code exists. Prototype numbers came from variable time and 1/30 bots, so they do not transfer (Flow Rule 4).

### Constraints
- **Engine**: one main thread. The sim reads no engine time and no physics (TR-state-003).
- **ADR-0001**: `Battle.tick(dt)` is the only way sim time advances; `halted()` is false while `PAUSED`, so the tick gate stops time in a pause; method Callables only; no sim object holds a `Node`, `Battle` or `AppRoot`.
- **ADR-0002**: the validator (Foundation) reads this ADR's tick constant and calls `TickMath.to_ticks` for mirrored maths.
- **ADR-0003**: input through `_unhandled_input` and `_input`; pause through `lifecycle_paused()`.
- **Tests**: unit fixtures use `dt` 0.25; the real build uses the shipped tick.

### Requirements
TR-state-003 to 007, 012, 014; TR-combat-009, 014; TR-enemy-002, 003, 007; TR-tower-005, 010; TR-hero-003, 006, 011, 013; TR-hud-005, 007; the tick-gate and accumulator part of TR-state-010.

## Decision

### 1. Tick driver (QQ-01)
- Sim time is driven by an accumulator in a pure `TickClock extends RefCounted`, owned by the wrapper and advanced from `BattleWrapper._process(delta)` through `step(delta)`. `_physics_process`, `Engine.physics_ticks_per_second`, `max_physics_steps_per_frame` and `Timer` nodes play no part in stepping. But the engine caps `_process` delta at about `max_physics_steps_per_frame / physics_ticks_per_second` **[E3]**, so the physics settings are load-bearing and Guideline 11 pins them at their defaults (8 and 60, a cap near 0.13 s). The clock's `MAX_TICKS_PER_FRAME = 4` (about 0.067 s) sits below that cap, so the clock works as written.
- Why `_process`: (1) Decision 4 needs real-time models, ticks and view refresh in one callback; (2) the clock must reset on pause and use this project's cap, and for physics steps the engine offers only a global clamp and no reset; (3) no input callback can run between a frame's ticks and its view refresh, which takes S1's second clause off the critical path; (4) tests and bots call `battle.tick` directly.
- **Process order**: AppRoot is the wrapper's parent and both keep `process_priority` 0, so AppRoot's `_process` (ADR-0001 latches) runs before the wrapper's each frame (tree order, parent first **[E7]**). V9 asserts it.

### 2. Tick rate and the tick constant
- `TickMath` lives in `src/foundation/time/tick_math.gd`. `const TICK_RATE: int = 60`, `const TICK_SECONDS: float = 1.0 / TICK_RATE`. **ADR-0002's one-tick floor reads `TickMath.TICK_SECONDS`.** The HUD's `ticks_per_second` is `TickMath.TICK_RATE`.
- An instance holds `dt`. The Builder makes `TickMath.new(TickMath.TICK_SECONDS, dev_error)`; unit tests make their own with `dt` 0.25. `build()` keeps ADR-0001's signature.
- `to_ticks(seconds) -> int` is `roundi(seconds / dt)`, halves away from zero (TR-enemy-002) **[E1]**. Non-finite or negative input: dev error, return 0.
- Every authored duration becomes whole ticks through it; every countdown is an `int` (TR-state-012, TR-tower-005). Hero's `walk_ticks` is movement and keeps its own `ceil` with tolerance.
- Sims that need `dt` itself (Enemy & Wave `d_next`, Flow `seconds_left`) get it as a plain `float` at build.
- **Build order**: the Builder creates `DevErrorSink`, then `TickMath`, then `TickGuard`, then the sims, inside ADR-0001's step (d). The wrapper owns its own `DevErrorSink` for `TickClock` and its views, which also settles how the wrapper reaches a dev-error sink.

### 3. The clock: cap, stall, pause, frame rate
`TickClock.advance(delta, running) -> int`; the accumulator counts ticks:
- `running` false: accumulator 0, return 0.
- First running frame after a closed one: accumulator `0.5 + min(delta / dt, 1.0)`, so the phase sits mid-tick and that frame owes at most one tick, even after a long background stall.
- Otherwise add `delta / dt`; `owed = floori(acc + 1e-6)`, so a frame of exactly two ticks owes two despite float noise.
- **Cap**: only when `owed > max_ticks` does the cap apply: run `max_ticks`, keep only the fraction below one tick, drop the rest. A hitch slows the game rather than jumping it (Flow "long frame"). A frame owing exactly `max_ticks` keeps its remainder. Else subtract `owed`.
- Negative or non-finite `delta` counts as 0, with a dev error. `stop()` zeroes it and every later call returns 0 (ADR-0001 teardown step).
- `MAX_TICKS_PER_FRAME = 4`, provisional (Decision 7). At least 2 holds full speed at 30 fps.
- `running` is `battle.clock_running()`: `flow.phase()` is `WAVE` or `INTERMISSION` and `halted()` is false. The wrapper polls it every frame, so the clock is zero through Build, Paused, Won, Lost and Fatal (TR-state-010) with no `phase_changed` connection. A pause raised by a notification resets on the next frame's poll.
- **Frame rate**: the project sets `application/run/max_fps = 60` in project settings, never in code **[E8]**. A 90, 120 or 144 Hz panel then gets one tick per frame and saves battery. Interpolating views by the clock's fraction is deferred to ADR-0011.

### 4. Frame order (TR-hud-005, TR-state-014)
`BattleWrapper.step(delta)`, called from `_process`; no other battle node reads sim state from its own `_process`:
0. **Input commands** already ran, from adapter callbacks through resolver signals to HeroInput, TowerInput and HudLogic.
1. **Real-time models**: `ms = min(delta * 1000.0, MAX_REAL_MS_PER_FRAME)` (100); `HudLogic.advance(ms)` (arming, Lost 400 ms, Won 1000 ms), `ChipWindow.advance(ms)`, `HeroInput.update()`. Each model owns its Paused freeze rule; the wrapper never branches on a phase.
2. **Ticks**: `n = clock.advance(delta, battle.clock_running())`; up to `n` calls of `battle.tick(battle.tick_seconds())`, stopping once `clock_running()` is false.
3. **Views**: refresh view-models and views from read-only queries, then `queue_redraw()`. `_draw` uses what step 3 gave it.

**Shown equals paid, whatever S1 finds**: the bonus depends on `intermission_left`, which only a tick changes. From step 3 of frame N to step 2 of frame N+1 no tick runs, so a command in that gap reads what the player saw, whether input lands before or after `_process`. Deferred calls and `CONNECT_DEFERRED` handlers also land after `_process`, in the same gap **[E7]**. Only input between two ticks of one frame breaks it, and one `_process` call on one thread rules that out; sim code must not pull input in (Guideline 2). **ADR-0003's S1 queue fallback is not adopted**; S1's result is recorded here.

### 5. Inside a tick: gate and order (TR-state-004, TR-combat-009, QQ-08)
`Battle.tick(dt)`:
1. `dt != _tick_math.dt`: `fatal("tick_dt_mismatch")`, return.
2. Not `clock_running()`: return. The gate is in the sim, so it holds headless (Build no ticks, Intermission ticks).
3. `_tick_guard.enter()`; then, with `if halted(): break` after each: `flow.tick()`; `enemy_wave.advance(...)` (spawn, move, leak: leaks before fire); `combat.tick_status(enemy_wave.roster())`; `tower_sim.tick()` (ascending slot); `hero_sim.tick()` (hero, then burst); `enemy_wave.reap()` (kills by `spawn_id`, then clear checks).
4. `_tick_count += 1`; `_tick_guard.exit()`.

Sims check `halted()` after every read, injected call and emit (ADR-0001 Guideline 9), so an outcome or fatal mid-tick skips the rest (TR-state-007). Flow's commit order: set state (closes the gate), `cancel_input()`, emit `phase_changed`. `Flow.pause()` comes from notifications outside `_process`; if it runs during a tick it reports a dev error and applies, and the tick finishes whole. `advance`'s argument follows B7; ADR-0009 may drop it.

**QQ-08 tick-order part**: TD-ADR judged the order sound. Towers act before the hero, so the hero's damage share runs slightly low on shared kills; bounty is unaffected. Accepted by the user 2026-11-04.

### 6. Commands only between ticks (TR-state-004)
- `TickGuard extends RefCounted` holds one `bool`; `Battle` holds it as `_tick_guard`. The Builder injects `TickGuard.in_tick` into Flow, TowerSim and HeroSim.
- Commands (`start_wave`, `call_early`, `build`, `upgrade`, `pin`, `burst`) are thin public entry points: each checks `in_tick()` first and, if true, changes nothing, emits nothing, reports `ERR_COMMAND_IN_TICK` and returns a refusal (ADR-0010 names it; proposed `IN_TICK`). Internal transitions in a tick (an intermission reaching 0 starts the wave) call private functions, never the public command. *(Amended 2026-11-04 with ADR-0006, confirmed by the user: each command also holds the guard for its body, `if in_tick(): return refusal; enter(); var r := _body(...); exit(); return r`, so a command from any signal handler is refused; see Amendments.)*
- `deliver` gets no guard; V2 and Hero's "burst commanded between ticks" criterion cover Combat Rule 2.
- A command script is a list of `(tick_index, command)` pairs, each applied after `tick_index` ticks and before the next.

### 7. Frame budget (QQ-11, frame part)
- Data Flow 10's split stands at 60 fps: input 0.5, sim 4.0, views 3.0, engine 7.0, headroom 2.1 ms. This ADR owns the sim slice: one tick at most 2.0 ms p95 on an Adreno 5xx-class phone at the worst starter wave.
- At the first phone build, measure `p95_tick_ms` and set `MAX_TICKS_PER_FRAME = clamp(floori(8.0 / p95_tick_ms), 2, 4)`. Above 4.0 ms, 30 fps cannot hold full speed, which reopens ADR-0009's budget. Record by amendment. Views and draw calls are ADR-0011's.

### 8. Randomness (TR-state-005, TR-enemy-007)
- **At MVP no sim system draws a random number** (authored waves, instant hits, ties by `spawn_id` or slot). `Battle` keeps `rng_seed` read-only for logs.
- **When a GDD first adds sim randomness**, the Builder makes one `RandomNumberGenerator` per consumer, held by `Battle`, injected only into that consumer, with `seed = splitmix64(rng_seed * 1_000_003 + SALT)`: a fixed GDScript port with masked shifts, tested against fixed vectors. `SALT` is a constant in the consumer's file; AppRoot keeps `rng_seed` in 0 to 2^31 - 1. Per-consumer streams keep one consumer from shifting another. That amendment also decides whether retry reuses or re-picks the seed, and lists each consumer.
- **Cosmetic randomness** (the `fast` jitter, later VFX) uses a wrapper-owned generator, never seeded from `rng_seed`, never passed to the sim.
- **Banned across all of `src/` except the Builder and the wrapper**: global `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed`, `rand_from_seed`; `Array.shuffle()`, `Array.pick_random()` **[E5]**; `RandomNumberGenerator.new()`. In sim folders `rng.randfn()` is banned too (transcendental).

### 9. Float policy and determinism scope (QQ-05, TR-hero-006, TR-combat-014)
- GDScript `float` is 64-bit; `Vector2` components are 32-bit in a stock build **[E2]**.
- **In `src/foundation`, `src/core` and `src/feature`, sim maths uses `float` and `int` scalars with `+ - * /`, `sqrt`, `min`, `max`, `abs`, `floor`, `ceil`, `round` (and `floori`, `roundi`), `int()`, `clampf`, `clampi`, `is_finite`, `is_nan` and comparisons only.** `Vector2` is storage: construct it, read `.x`, `.y`. Banned there: `Vector2` operators (write x and y apart), `Vector2` and `Rect2` methods, `PackedVector2Array` maths, `Curve2D` / `Path2D` sampling, and transcendentals. Stage path points are read once into float scalars. Reason: basic IEEE-754 ops and `sqrt` round the same on every CPU; engine C++ and libm may not.
- Accumulating state (enemy `distance`, HP, walk ratio) is a scalar; cached `position` is rebuilt each tick, so 32-bit rounding never accumulates.
- **Determinism is promised per OS and CPU only.** Bot baselines live in `tests/baselines/<os>_<arch>/` (`OS.get_name()`, `Engine.get_architecture_name()` **[E4]**). A missing baseline is a report, not a pass. Baselines may need regenerating after an engine upgrade.
- Gameplay never reads `Engine`, `Time`, `OS`, a `Timer` or `await`. Only the wrapper reads `delta`, which `Engine.time_scale` scales **[E3]**; nothing sets it.

### Architecture Diagram

```
One frame:
  input callbacks (ADR-0003) ─► resolver ─► HeroInput / TowerInput / HudLogic ─► commands
  AppRoot._process (parent first) ─► BattleWrapper._process ─► step(delta):
    1 ms = min(delta*1000, 100) ─► HudLogic, ChipWindow, HeroInput.update()
    2 n = TickClock.advance(delta, battle.clock_running()) ─► battle.tick(dt) x n
    3 views refresh ─► queue_redraw()
Battle.tick(dt): dt check ─► gate ─► TickGuard.enter()
  Flow.tick ─► EnemyWave.advance ─► Combat.tick_status(roster) ─► TowerSim.tick
  ─► HeroSim.tick ─► EnemyWave.reap   [halted(): break]  ─► tick_count += 1; exit()
Foundation TickMath.TICK_SECONDS ◄── ADR-0002 validator
```

### Key Interfaces

```gdscript
class_name TickMath extends RefCounted          # src/foundation/time/tick_math.gd
const TICK_RATE: int = 60
const TICK_SECONDS: float = 1.0 / TICK_RATE
var dt: float                                   # read-only by contract
func _init(tick_dt: float, dev_error: Callable) -> void
func to_ticks(seconds: float) -> int            # roundi(seconds / dt)

class_name TickGuard extends RefCounted          # src/foundation/time/tick_guard.gd
func enter() -> void
func exit() -> void
func in_tick() -> bool

class_name TickClock extends RefCounted          # src/root/tick_clock.gd, wrapper-owned
const MAX_TICKS_PER_FRAME: int = 4              # provisional
func _init(tick_dt: float, dev_error: Callable, max_ticks: int = MAX_TICKS_PER_FRAME) -> void
func advance(delta: float, running: bool) -> int
func stop() -> void

# BattleWrapper: const MAX_REAL_MS_PER_FRAME := 100.0; func step(delta: float) -> void
# Battle additions (B4): var rng_seed: int; var _tick_guard: TickGuard
#   func clock_running() -> bool; func tick_seconds() -> float; func tick_count() -> int
# Injected (B9 additions): dt: float -> Flow, EnemyWave, HeroSim
#   in_tick() -> bool (TickGuard.in_tick) -> Flow, TowerSim, HeroSim
```

Names are proposed; QQ-16 may add a prefix (ADR-0007).

### Implementation Guidelines
1. Sim time advances only through `Battle.tick(dt)`. The wrapper, tests and bots pass `battle.tick_seconds()`, never a literal.
2. Only `BattleWrapper.step` calls `battle.tick`, apart from tests and bots. Code in sim folders never implements `_process` or `_physics_process`, creates a `Timer`, uses `await`, reads `Engine`, `Time` or `OS`, or calls `Input.flush_buffered_events`, `Input.parse_input_event` or `Viewport.push_input`.
3. The wrapper runs Decision 4's order. No other battle node reads sim state from `_process`.
4. `TickClock` follows Decision 3: zero while closed, 0.5 on reopening, cap only when owed exceeds the cap.
5. `Battle.tick` runs Decision 5's six steps and breaks when `halted()` turns true.
6. Every countdown is an `int` of ticks; every authored duration goes through `to_ticks`.
7. Commands are thin public entry points that check `in_tick()` first, then hold the guard with `enter()` and `exit()` around a private body on one return path (amended 2026-11-04 with ADR-0006); internal transitions call private functions.
8. Real-time models take time only from the wrapper's `advance(ms)` or `update()`.
9. Randomness follows Decision 8's ban and scope.
10. Sim maths follows Decision 9's allowed list and bans.
11. `project.godot` pins, checked through `ProjectSettings` (V11e): `physics/common/physics_ticks_per_second` 60 and `physics/common/max_physics_steps_per_frame` 8 (they set the engine's `_process` delta cap, Decision 1; a lower value would starve the clock's cap of 4), `application/run/max_fps` 60, `application/run/low_processor_mode` off, `display/window/vsync/vsync_mode` enabled, `application/run/delta_smoothing` on. Nothing sets `Engine.time_scale`, `Engine.physics_ticks_per_second` or `SceneTree.paused`.
12. Baselines are read and written under `tests/baselines/<os>_<arch>/`.
13. ADR-0002's validator reads `TickMath.TICK_SECONDS` for every one-tick floor.
14. An override of a typed method returns a value on every path (4.7).

## Alternatives Considered

### Alternative 1: Tick in `_physics_process`
- **Description**: physics stepping calls `battle.tick`; `max_physics_steps_per_frame` clamps.
- **Pros**: no accumulator code; engine catch-up.
- **Cons**: no reset on pause; global clamp only; the frame order spans two callbacks and rests on S1's second clause.
- **Rejection Reason**: gives up the pause reset and cap this ADR must own.

### Alternative 2: Variable `dt`
- **Description**: `battle.tick(delta)` once per frame.
- **Pros**: simplest; smooth.
- **Cons**: breaks determinism and every whole-tick formula (5.0 s took 301 ticks).
- **Rejection Reason**: contradicts TR-state-003, 012, TR-enemy-002.

### Alternative 3: 30 Hz tick
- **Description**: `TICK_RATE = 30`.
- **Pros**: half the sim cost.
- **Cons**: Data floor and GDD values assume 1/60; coarser timing; needs interpolation.
- **Rejection Reason**: re-tunes every value for an unmeasured saving.

### Alternative 4: S1 command queue
- **Description**: input owners queue commands; the wrapper drains them before step 1.
- **Pros**: independent of input timing.
- **Cons**: loses synchronous results the chip, arc and HeroInput need.
- **Rejection Reason**: Decision 4 already holds under either order. Fallback only if S1 shows input inside the wrapper's `_process`.

### Alternative 5: One shared sim RNG now
- **Description**: one seeded generator on `Battle`.
- **Pros**: one object.
- **Cons**: unused at MVP; one stream lets a new consumer shift all others.
- **Rejection Reason**: per-consumer streams keep baselines stable.

### Alternative 6: Uncapped frame rate on high refresh panels
- **Description**: render at 90 to 144 Hz; some frames owe 0 ticks.
- **Pros**: smoother input feel.
- **Cons**: views repeat frames without interpolation; more battery.
- **Rejection Reason**: `max_fps` 60 is simpler; ADR-0011 may add interpolation later.

## Consequences

### Positive
- The frame order sits in one function and one test; the clock runs headless.
- TR-hud-005 no longer depends on S1.
- Commands during a tick fail loudly.
- ADR-0002's floor check can be written now; added randomness cannot shift baselines.

### Negative
- A hand-written accumulator instead of an engine feature.
- Scalar-only sim maths makes Combat helpers, PinGeometry and path code longer.
- A stall drops time (the GDD's choice); baselines per OS and CPU; a 60 fps cap gives up 120 Hz smoothness.

### Neutral
- Physics settings stay at defaults, pinned (Guideline 11). `rng_seed` is read by nothing at MVP.

## Risks
- **E1 fails** (`roundi` rounds halves to even): use `floori(x + 0.5)` for the non-negative inputs it accepts; re-run ADR-0002's floor test.
- **E2 fails** (`Vector2` 64-bit): nothing breaks; record it.
- **Tick above 2 ms on the phone**: Decision 7's rule; ADR-0009 owns per-tick work.
- **`max_fps` 60 on a 90 Hz panel paces unevenly** (frames alternate one and two vsyncs) or the cap is ignored: V13 on a 90 or 120 Hz phone; if it judders, ADR-0011 takes interpolation.
- **A pause during a tick**: dev error; the tick still finishes whole.
- **Lint gaps**: ADR-0007 lints by call name over the scopes in Decisions 8 and 9.
- **A listener issues a command**: the refusal names it; ADR-0006's rule is the main guard.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-003: time only through `tick`; wrapper clamps | Decisions 1 to 3 |
| game-state-stage-flow.md | TR-state-004: one order; commands between ticks | Decisions 5, 6 |
| game-state-stage-flow.md | TR-state-005: randomness from the seed | Decision 8 |
| game-state-stage-flow.md | TR-state-006: pure Flow machine, readable result | Decision 5 (only `Battle.tick` ticks Flow; the gate reads its phase). **Partial, shared with ADR-0006** (result contents, phase signals) |
| game-state-stage-flow.md | TR-state-007: commit, stop, cancel, emit; rest skipped | Decision 5 |
| game-state-stage-flow.md | TR-state-010 (shared): ticks stop, accumulator zero on Paused | Decision 3; ADR-0003 covers the rest |
| game-state-stage-flow.md | TR-state-012: one `to_ticks`; int countdowns | Decision 2 |
| game-state-stage-flow.md | TR-state-014: presentation timers on the frame clock | Decision 4 step 1 |
| combat-damage.md | TR-combat-009: tick order; leaks before fire | Decision 5 |
| combat-damage.md | TR-combat-014: per-architecture baselines | Decision 9 |
| enemy-wave.md | TR-enemy-002: fixed `dt`, `to_ticks` half away, absolute schedule | Decision 2 |
| enemy-wave.md | TR-enemy-003: advance and reap; roster to `tick_status` | Decision 5 |
| enemy-wave.md | TR-enemy-007: no seed read; cosmetic RNG apart; retry identical | Decision 8; retry rebuild by ADR-0001 section 5. **Full** |
| tower-system.md | TR-tower-005: slot order; int cooldown, Intermission too | Decisions 2, 5 |
| tower-system.md | TR-tower-010: chip on real time from the wrapper | Decision 4 step 1 |
| hero-system.md | TR-hero-003: Hero slot; `to_ticks`; `halted()` | Decisions 2, 5 |
| hero-system.md | TR-hero-006: scalar PinGeometry | Decision 9 (whole sim) |
| hero-system.md | TR-hero-011: explicit `update()` | Decision 4 step 1 |
| hero-system.md | TR-hero-013: pause resumes exactly; aims get `drag_cancelled`; Build no ticks | Decisions 3, 5; cancel by ADR-0003 2.5; the emit by ADR-0008. **Full** |
| battle-hud.md | TR-hud-005: frame order; shown equals paid | Decision 4 |
| battle-hud.md | TR-hud-007: arming `advance(ms)`, 100 ms clamp, frozen while Paused | Decision 4 step 1 |
| data-config-pipeline.md | One-tick floor from a constant | Decision 2 |

## Performance Implications
- **CPU**: a few float ops per frame; sim slice 4.0 ms, 2.0 ms p95 per tick (Decision 7). The 60 fps cap lowers CPU and GPU load on fast panels.
- **Memory**: three small `RefCounted` objects per battle; no per-tick allocation.
- **Load Time / Network**: none.

## Migration Plan
No code exists. Sync items, not edited here:
1. `architecture.md`: Composition Root BattleWrapper row (the clock polls `clock_running()`, not `phase_changed(PAUSED)`; the wrapper owns a `DevErrorSink`); Data Flow 1 (driver, `step`, S1 off the critical path); Data Flow 3 row for `phase_changed` (drop the wrapper); Data Flow 6 step 4 (ADR-0003 2.5's zeroing now happens on the next frame's poll); Data Flow 10 (Decision 7); B0 (`TickMath`, `TickGuard`, `TickClock`); B4 and B9 additions; Required ADRs (ADR-0004 written; TR-state-006 joins ADR-0006's Covers as shared, for result contents and phase signals); QQ-01 resolved; QQ-05 resolved pending V11a; QQ-08 tick-order part accepted by the user 2026-11-04; QQ-11 frame part.
2. GDDs: Game State's ADR line after Rule 18 and "long frame" edge case; Combat and Enemy & Wave tick-order open questions; HUD `ticks_per_second` and Rules 10, 18; Tower's `ChipWindow` feed note (the wrapper); Data & Config floor text; Hero's walk position formula `from + (pin - from) * ratio` written per component (Decision 9).
3. ADR-0002 (next revision): `to_ticks` uses `roundi`; optionally its validator warns when `seconds / dt` lies within 1e-9 of `k + 0.5`.
4. ADR-0003 (next revision): Risks "S1 fails" notes the queue is not adopted.
5. `requirements-traceability.md`, `tr-registry.yaml`: by `/architecture-review`.

## Validation Criteria
Headless unless marked; ADR-0007 hosts them. Recording fakes log into an `Array` or `Dictionary`; a fake overriding a typed method returns a value on every path (4.7).
- **V1 `test_tick_clock`** (`dt` 1/60): 1/60, 1/30, 0.5 s, 10 s owe 1, 2, 4, 4 in steady state; MAX 2 at 30 fps with a small surplus keeps the remainder; at MAX 4, 1/15 s plus a remainder keeps it; above the cap only the fraction survives; the first running frame starts at 0.5 and owes at most 1 even after a 10 s delta; `running` false zeroes; negative or NaN delta owes 0 with one dev error; after `stop()` always 0.
- **V2 `test_tick_order`**: fakes log exactly Flow, advance, tick_status (with the roster), TowerSim, HeroSim, reap; a leak that latches `halted()` in step 2 stops the log there; `tick_count()` rises by one.
- **V3 `test_tick_gate`**: Build, Paused, Won, Lost, Fatal run no step; Wave and Intermission run six; a wrong `dt` calls `fatal("tick_dt_mismatch")`; an intermission reaching 0 inside a tick starts the wave with no refusal.
- **V4 `test_command_in_tick_refused`**: each command called from a fake step is refused with no change, no emit and one `ERR_COMMAND_IN_TICK`.
- **V6 `test_to_ticks`**: Enemy & Wave criteria 37 to 39; negative and NaN give 0 with a dev error. Settles E1.
- **V7 `test_determinism_replay`**: two builds with the same inputs over 3,000 ticks give the same per-tick digest, hashed from exact bits (`var_to_bytes` or `PackedFloat64Array.to_byte_array()`), never `str(float)`; two seeds give the same digest at MVP.
- **V8 `test_pause_resume_exact`**: pause mid-walk and mid-telegraph, 100 gated ticks, resume; the digest matches an unpaused run.
- **V9 `test_frame_order`** (scene tree): calls `wrapper.step(delta)` with listed deltas; spies check step order and AppRoot before wrapper; one shown-equals-paid check on Call; a 10 s delta runs at most the cap. gdUnit4's `set_time_factor` is banned here. A 200-delta list is optional.
- **V10 `test_real_time_models`**: `advance` gets at most 100 ms; Paused holds arming and the Won beat; no model reads engine time.
- **V11 engine probes**: results with date and version go into `docs/engine-reference/godot/`. See table.
- **V12 lint** (ADR-0007): Guideline 2 and Decision 9 bans over `src/foundation`, `src/core`, `src/feature`; Decision 8 bans over all of `src/` except the Builder and the wrapper.
- **V13 device** (manual, `production/qa/evidence/`): p95 tick cost and frame time at 60 and 30 fps; pacing on a 90 or 120 Hz phone under `max_fps` 60; sets `MAX_TICKS_PER_FRAME`.
- **V14**: S1's result is recorded here; input inside the wrapper's `_process` reopens Decision 4.

| Fact | Answer (memory, then probed) | Probe |
|---|---|---|
| E1 `roundi` / `round` halves | Away from zero | V6; verified 4.7.2 headless, see probe-results.md |
| E2 `Vector2` precision | 32-bit | V11a: `Vector2(0.1, 0).x == 0.1` is false; verified 4.7.2 headless, see probe-results.md |
| E3 `_process` delta | Corrected: real seconds times `Engine.time_scale`, capped by the engine at about `max_physics_steps_per_frame / physics_ticks_per_second` (0.13 to 0.15 s at 8 and 60). First frame is a nominal 1/60 or 0.0083, bounded by the first-running-frame rule. Smoothing on paced frames is not judged headless | V9, V11e; verified 4.7.2 headless, see probe-results.md |
| E4 architecture name | `Engine.get_architecture_name()` exists | V11b; else `OS.has_feature("arm64")`; verified 4.7.2 headless, see probe-results.md (arm64 value needs a phone) |
| E5 RNG | Equal `seed` repeats; `shuffle`, `pick_random`, global `randi` use the global generator | V11c, before the first sim consumer; verified 4.7.2 headless, see probe-results.md |
| E6 low processor mode | Off by default | V11d: project setting false and `OS.low_processor_usage_mode` false; verified 4.7.2 headless, see probe-results.md |
| E7 order | Parent `_process` before child at equal priority; deferred calls flush after `_process` | V9; verified 4.7.2 headless, see probe-results.md |
| E8 `max_fps` | `application/run/max_fps`, default 0 (no cap) | V11e settings dump; V13; verified 4.7.2 headless, see probe-results.md |

## Reviews
**godot-specialist: CONCERNS. TD-ADR: CONCERNS.** All relayed findings applied. The relayed list named no G1, G2, G5, TD7 or TD8; if those were separate findings, they are not covered here.

| # | Finding | Resolution |
|---|---|---|
| B1 | Cap rule (both) | Decision 3: cap only when owed exceeds it; V1 cases |
| B2 | High refresh panels (both) | Decision 3 `max_fps` 60 in settings; Alt 6; risk; V13; E8 |
| B3 / TD1 | TR split | TR-enemy-007, TR-hero-013 full; TR-state-006 shared with ADR-0006 (Migration 1) |
| B4 / TD2 | Lint scope | Decisions 8, 9; V12 |
| G3 | Reopen at 0.5 tick | Decision 3; V1 |
| G4 | Reason (2) wording | Decision 1 |
| G6 | Input pull-in, deferred calls | Guideline 2; Decision 4 |
| G7 | AppRoot and wrapper order | Decision 1; V9 |
| G8 | `time_scale`, settings | Decision 9; Guideline 11; V9 |
| G9 / TD12 | V9 shape | V9 via `step(delta)` |
| G10 | V11d | Both checks |
| G11 | `roundi`, `floori`; half-tick warning | Decisions 2, 3; Migration 3 |
| G12 | splitmix64; `randfn`; upgrades | Decisions 8, 9 |
| G13 | `<os>_<arch>`; exact-bit digest | Decision 9; V7 |
| G14 | Curve2D, packed maths | Decision 9 |
| G15 | Typed overrides; fake logs | Guideline 14; Validation preamble |
| G16 | E1 to E6 memory-only | Engine Compatibility; table |
| TD3 | Ops list; no `Vector2` operators; Hero formula | Decision 9; Migration 2 |
| TD4 | Drop `deliver` guard | Decision 6; V5 removed |
| TD5 | Thin commands; intermission case | Decision 6; Guideline 7; V3 |
| TD6 | `tick_seconds()` everywhere | Guideline 1 |
| TD9 | Build order; wrapper sink | Decision 2 |
| TD10 | BattleWrapper row; 2.5 timing | Decision 3; Migration 1 |
| TD11 | Retry seed decision | Decision 8 |
| QQ-08 | TD view | Decision 5, accepted by the user 2026-11-04 |

## Related
- ADR-0001 (depends on), ADR-0002 (enabled), ADR-0003 (depends on); enables ADR-0006 to ADR-0011
- `architecture.md` v4: Composition Root, Data Flow 1, 2, 3, 6, 10; B0, B4, B5, B9; QQ-01, 05, 08, 11
- GDDs: `game-state-stage-flow.md` (Rules 4, 5, 8, 10, 15, 17), `combat-damage.md` (Rules 2, 7, 9, 11), `enemy-wave.md` (Rules 6 to 12, `to_ticks`, criteria 37 to 42), `tower-system.md` (Rules 8 to 10, 15), `hero-system.md` (Rules 6, 9, 16, Tick, PinGeometry), `battle-hud.md` (Rules 10, 11, 18), `data-config-pipeline.md` (field domains)

## Amendments
- **2026-11-04, with ADR-0006 (confirmed by the user 2026-11-04 at ADR-0006 acceptance).** Status stays Accepted. Decision 6 and Guideline 7 change: every public command holds the `TickGuard` for its body, shaped `if in_tick(): return refusal; enter(); var r := _body(...); exit(); return r`, with one return path, so a command called from any signal handler, inside a tick or inside another command, is refused and changes nothing. `ERR_COMMAND_IN_TICK` now means "inside a tick or another command" (ADR-0010 may rename it `BUSY`). The Builder injects `TickGuard.enter` and `TickGuard.exit` as method Callables into Flow, TowerSim and HeroSim beside `in_tick`. `enter()` reports a dev error if the guard is already entered. `Battle.tick` reports a dev error and resets the guard if it finds it already set. `Flow.pause()` and `Flow.resume()` call `enter()` and `exit()` only when `in_tick()` is false; a pause during a tick keeps Decision 5's behaviour. Nothing else in this ADR changes.
- **2026-11-04, from verified engine probes** (docs/engine-reference/godot/probe-results.md; Status stays Accepted). E3 is corrected: the engine caps `_process` delta at about `max_physics_steps_per_frame / physics_ticks_per_second`. Decision 1 now says the physics settings are load-bearing, and Guideline 11 pins `physics/common/physics_ticks_per_second` 60 and `physics/common/max_physics_steps_per_frame` 8. `MAX_TICKS_PER_FRAME = 4` sits below the cap, so the clock and V1 stand. First-frame delta (1/60 or 0.0083) needs no change. Engine Compatibility and the V11 table now mark E1 to E8 verified.
- **2026-11-04, from the third architecture review; Status stays Accepted** (`architecture-review-2026-11-04.md`, Should fix 5). Decision 5 and the QQ-08 review row now say the tick-order part was accepted by the user 2026-11-04, as Decision Makers records. Knowledge Risk now names the two pinned physics settings (`physics/common/physics_ticks_per_second` 60, `physics/common/max_physics_steps_per_frame` 8) as load-bearing, as the E3 amendment made them. This ADR also supersedes ADR-0003's old S1 fail branch (a command queue); ADR-0003 is amended to match. Nothing else in this ADR changes.
