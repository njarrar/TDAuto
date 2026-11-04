# ADR-0004: Fixed-Tick Clock, Tick Order, Frame Order and Determinism

## Status
Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation.

## Date
2026-11-04

## Last Verified
2026-11-04 (against `docs/engine-reference/godot/` for Godot 4.7.2, `docs/architecture/architecture.md` v4, ADR-0001, ADR-0002 and ADR-0003 as Accepted, and `docs/registry/architecture.yaml`)

## Decision Makers
- Author: `/architecture-decision`, run in autonomous mode (decisions logged in `production/session-logs/decision-log.md`)
- Engine specialist (godot-specialist): **not run**. Reviews still owed.
- Technical director (TD-ADR): **not run**. Reviews still owed.
- Acceptance: the user. QQ-08's tick-order part (the one tick order replacing earlier notes) is accepted only with this ADR.

## Summary
Every battle system needs one source of simulation time, one fixed order of work inside a tick, and one order of work inside a frame, so that a battle is a function of `(catalogue, stage_id, rng_seed, command script)` and the bonus the HUD shows is the bonus paid. This ADR decides a 60 Hz fixed tick driven by a pure `TickClock` accumulator in `BattleWrapper._process` (not `_physics_process`), clamped at 4 ticks per frame and zeroed whenever the in-sim gate is closed; the six-step tick order in `Battle.tick`; a `TickGuard` that refuses commands during a tick; `TickMath` in Foundation as the home of the tick constant and `to_ticks`; no simulation randomness at MVP with per-consumer seeded streams reserved; and a float policy of scalar maths with per-architecture baselines.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D) |
| **Domain** | Core (main loop timing and simulation determinism) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (4.5 to 4.7 are post-cutoff; the pinned reference says nothing about `_process` timing, physics stepping, `RandomNumberGenerator` or `Vector2` precision). The decision is built to lean on as little of this as it can: only `_process(delta)` and plain `float` arithmetic are load-bearing. |
| **References Consulted** | `docs/engine-reference/godot/` (`VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/physics.md`, `modules/input.md`); `architecture.md` v4 (Data Flow 1, 2, 3, 6, 10, B0, B4 to B9, Required ADRs, QQ-01, 05, 08, 11); `tr-registry.yaml`; ADR-0001 to ADR-0003 (by section); the registry; GDDs under Related |
| **Post-Cutoff APIs Used** | None. Used: `Node._process(delta)`, `RefCounted`, `float` and `int` arithmetic, `round()`, `sqrt()`, `Vector2` construction and `.x` / `.y`, `RandomNumberGenerator` (reserved, not used at MVP). All exist since 4.0 and `breaking-changes.md` lists no change to them in 4.4 to 4.7. Checked in the pinned reference: Jolt became the default in 4.6 for **3D only**; 2D stays on Godot Physics 2D (`modules/physics.md`), and the simulation uses no physics body or area at all (Flow Rule 4), so neither engine matters here. |
| **Verification Required** | Facts not in the pinned reference, each with the test that settles it (Validation Criteria): E1 `round()` on a `float` rounds halves away from zero (V6). E2 `Vector2` components are 32-bit in the official 4.7.2 build (V11a). E3 `_process(delta)` passes unclamped real seconds scaled by `Engine.time_scale` (V9, and the pure clock makes the answer harmless). E4 `Engine.get_architecture_name()` exists and names the CPU (V11b). E5 `RandomNumberGenerator` with an equal `seed` repeats its sequence, and `Array.shuffle()`, `pick_random()` and the global `randi()` family draw from the global generator (V11c, only before the first sim consumer). E6 `application/run/low_processor_mode` is off by default (V11d). S1 from ADR-0003 still runs; this ADR no longer depends on its result for TR-hud-005 (Decision 4). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): `Battle` holds `TickMath` and `HaltGate`; the wrapper holds the clock; `build(catalogue, stage_id, rng_seed, fatal_handler)`; no `SceneTree.paused`; teardown starts with "stop the Clock"; method Callables only. ADR-0003 (Accepted): input reaches the resolver from engine callbacks; `lifecycle_paused` reaches `Flow.pause`; spike check S1. |
| **Enables** | ADR-0002's interval floor check (reads `TickMath.TICK_SECONDS`, Decision 2), ADR-0006 (signals emitted inside the tick order), ADR-0007 (lint rules G4 to G7 and tests V1 to V11), ADR-0009 (per-tick budget, `deliver` guard), ADR-0010 (command result for a command during a tick; bot command scripts), ADR-0011 (view refresh step of the frame) |
| **Blocks** | No epic or story exists yet (`production/` holds none). After `/create-epics`, every story that builds `Battle.tick`, the `TickClock`, `TickMath`, a sim tick entry, a real-time model or a bot harness waits for this ADR to be Accepted. |
| **Ordering Note** | Write after ADR-0003, before ADR-0006. The device half of Decision 7 (frame budget and the final `MAX_TICKS_PER_FRAME`) waits for the first phone build; the value here is provisional and is changed by amendment, not by code. |

## Context

### Problem Statement
Four GDDs restate a tick order and three name a real-time clock; all assume one fixed `dt` and one `to_ticks`, but none says where ticks come from. Architecture v4 leaves the driver (QQ-01), the clamp, the float policy (QQ-05), the frame order behind TR-hud-005 and the frame budget (QQ-11) to this ADR. ADR-0002's floor check needs a tick constant. Every sim story rests on these answers.

### Current State
No game code exists (`src/` holds only `CLAUDE.md`). Prototype numbers came from variable time for humans and 1/30 for bots, so they do not transfer (Flow Rule 4).

### Constraints
- **Engine**: one main thread; no data flow may cross a thread (architecture Data Flow). The simulation reads no engine time and no physics (TR-state-003).
- **ADR-0001**: `Battle.tick(dt: float)` is the only way sim time advances; `Battle` holds `_tick_math` and `_halt_gate`; the wrapper holds the clock; `halted()` is false while `PAUSED`, so the tick gate, not `halted()`, stops time in a pause; method Callables only; no sim object holds a `Node`, `Battle` or `AppRoot`.
- **ADR-0002**: the interval floor reads this ADR's tick constant, never a literal; a rule that mirrors runtime maths calls `TickMath.to_ticks`. The validator lives in Foundation (`src/foundation/data/`), so the constant must too.
- **ADR-0003**: presses and endings arrive through `_unhandled_input` and `_input`; pause arrives as `lifecycle_paused()` to `Flow.pause()`; the order on focus loss ends with "the Clock zeroes its accumulator (ADR-0004)".
- **Tests**: GDD fixtures use `dt` 0.25 (binary exact) for unit tests of single systems; the real build uses the shipped tick.
- **Team**: solo part-time developer; desktop first; first phone build later.

### Requirements
TR-state-003, 004, 005, 006, 007, 012, 014; TR-combat-009, 014; TR-enemy-002, 003, 007; TR-tower-005, 010; TR-hero-003, 006, 011, 013; TR-hud-005, 007; and the tick-gate and accumulator part of TR-state-010. Text in `tr-registry.yaml`; mapping under GDD Requirements Addressed.

## Decision

### 1. Tick driver (QQ-01)
- Simulation time is driven by a custom accumulator in **`BattleWrapper._process(delta)`**. `_physics_process`, `Engine.physics_ticks_per_second`, `max_physics_steps_per_frame` and engine `Timer` nodes play no part in simulation time. The physics settings stay at their defaults, since no physics body exists.
- The accumulator lives in a pure `TickClock extends RefCounted` that the wrapper owns, so its maths runs headless with no frames.
- Why `_process`: (1) Decision 4 needs real-time models, ticks and view refresh in one callback, in one order; (2) the accumulator must be zeroed on pause and clamped by this project, and the engine's physics accumulator allows neither; (3) no input callback can run between a frame's ticks and its view refresh, which takes S1's second clause off the critical path; (4) tests and bots call `battle.tick` directly, so the driver stays a thin shell.

### 2. Tick rate and the tick constant
- `TickMath` lives in **`src/foundation/time/tick_math.gd`** (Foundation, so ADR-0002's validator may read it without an upward dependency).
- `const TICK_RATE: int = 60` and `const TICK_SECONDS: float = 1.0 / TICK_RATE`. **`TickMath.TICK_SECONDS` is the constant ADR-0002's one-tick floor reads.** The Battle HUD's `ticks_per_second` is `TickMath.TICK_RATE`.
- A `TickMath` instance holds `dt`. The Builder makes it with `TickMath.new(TickMath.TICK_SECONDS, dev_error)`. Unit tests of a single system make their own with `dt` 0.25. `build()` keeps ADR-0001's signature and always uses the shipped tick.
- `to_ticks(seconds: float) -> int` returns `int(round(seconds / dt))`, rounding halves away from zero (Enemy & Wave Formulas, TR-enemy-002) **[E1]**. A non-finite or negative input reports to the dev-error sink and returns 0; the catalogue validator already rejects such data, so this guards caller bugs.
- Every authored duration becomes whole ticks through this one function. Every countdown is an `int` that a tick decrements (TR-state-012, TR-tower-005). Movement is not an authored time: Hero's `walk_ticks` keeps its own `ceil` with tolerance, as the Hero GDD states.
- Sims that need `dt` itself (Enemy & Wave's `d_next`, Flow's `seconds_left = intermission_left × dt`) receive it as a plain `float` value at build, read from `TickMath.dt`.

### 3. The clock: clamp, stall and pause
- `TickClock.advance(delta: float, running: bool) -> int` returns the ticks owed this frame:
  - If `running` is false: set the accumulator to 0 and return 0.
  - Else add `delta / dt` to the accumulator, which counts ticks, take `owed = floor(acc + 1e-6)` (so a frame of exactly two ticks owes two despite float noise), and cap it at `MAX_TICKS_PER_FRAME`.
  - If the cap applied, set the accumulator to 0: the time past the cap is dropped, so a hitch slows the game rather than jumping it (Flow edge case "long frame"). Else subtract `owed`.
  - A negative or non-finite `delta` counts as 0, with a dev error.
- `const MAX_TICKS_PER_FRAME: int = 4`, provisional. At least 2 keeps full speed at the 30 fps floor; 4 keeps it down to 15 fps. Decision 7 sets the final value from a measured per-tick cost.
- `running` is `battle.clock_running()`: true only when `flow.phase()` is `WAVE` or `INTERMISSION` and `halted()` is false. The wrapper reads it every frame. So the accumulator is zero through Build, Paused, Won, Lost and Fatal, and the first frame after a resume or a Start Wave owes at most one frame of time (TR-state-010, accumulator part). No `phase_changed` connection is needed for this.
- `TickClock.stop()` zeroes the accumulator and makes every later `advance` return 0. ADR-0001's teardown step "stop the Clock" calls it. A rebuilt battle gets a new wrapper and a new clock.

### 4. Frame order (TR-hud-005, TR-state-014)
`BattleWrapper._process(delta)` runs, in this order, and nothing else in the battle reads sim state from its own `_process`:

0. **Input commands** have already run, from the adapter's callbacks through the resolver's signals to HeroInput, TowerInput and HudLogic, which call sim commands at once.
1. **Real-time models**: `ms = min(delta × 1000.0, MAX_REAL_MS_PER_FRAME)` with `MAX_REAL_MS_PER_FRAME = 100`. Then `HudLogic.advance(ms)` (arming, Lost delay 400 ms, Won beat 1000 ms), `TowerInput`'s `ChipWindow.advance(ms)`, `HeroInput.update()`. Each model owns its own freeze rule while Paused (HUD Rule 11, Tower Rule 8); the wrapper feeds real time and never branches on a phase.
2. **Ticks**: `n = clock.advance(delta, battle.clock_running())`; then up to `n` calls of `battle.tick(battle.tick_seconds())`, breaking out as soon as `battle.clock_running()` turns false, so a mid-frame outcome drops the rest.
3. **Views**: refresh HUD view-models and field views from read-only queries, then `queue_redraw()`. Views draw from what step 3 gave them, never from a live read in `_draw`.

Why the shown bonus equals the paid bonus whatever S1 finds: the bonus depends on `intermission_left`, which only a tick changes. From the step 3 refresh of frame N to step 2 of frame N+1 no tick runs, so a command in that gap reads the `intermission_left` the player saw. If S1 shows input arriving before `_process` (the expected case), the order is exactly TR-hud-005's. If it shows input arriving after `_process` in the same frame, the command still lands in that gap. The only order that breaks it is input running between two ticks of one frame, which a single `_process` call on one thread rules out. **ADR-0003's S1 fallback (a command queue drained at the start of the tick driver) is therefore not adopted**; S1 still runs and its result is recorded here.

### 5. Inside a tick: gate and order (TR-state-004, TR-combat-009, QQ-08 tick-order part)
`Battle.tick(dt)`:
1. If `dt != _tick_math.dt`: `fatal("tick_dt_mismatch")` and return. One fixed tick has no other legal value.
2. If not `clock_running()`: return. The gate lives in the sim, so it holds headless (Build runs no ticks; Intermission does; TR-hero-013).
3. `_tick_guard.enter()`, then the six steps, with `if halted(): break` after each:
   1. `flow.tick()` (intermission countdown; the tick that enters Intermission does not decrement)
   2. `enemy_wave.advance(...)` (spawn from the absolute schedule, move, leak; leaks resolve before fire)
   3. `combat.tick_status(enemy_wave.roster())` (the battle passes the roster; TR-enemy-003)
   4. `tower_sim.tick()` (ascending slot index)
   5. `hero_sim.tick()` (walk, attack, cooldown, telegraph, release; the burst after the hero)
   6. `enemy_wave.reap()` (kills in `spawn_id` order, then clear checks)
4. `_tick_count += 1` (only for a tick that passed the gate, including one that broke early), then `_tick_guard.exit()`.

Each sim also checks `halted()` after every read, injected call and emit (ADR-0001 Guideline 9), so an outcome or fatal mid-tick skips the rest of that tick (TR-state-007). Outcome commit order stays Flow's: set state, which closes the gate ("stops the clock"), then `cancel_input()`, then emit `phase_changed` (Flow Rule 15); the wrapper's clock then zeroes. `Flow.pause()` comes from the adapter's notification path, outside `_process`. If it ever runs while `in_tick()` is true it reports a dev error and still applies; the tick finishes whole, since `halted()` is false while Paused, and the next tick finds the gate closed.

The `enemy_wave.advance` argument follows B7 (`advance(tick: int)`, given `_tick_count`); ADR-0009 may drop it, since Enemy & Wave keeps its own `wave_tick`.

### 6. Commands only between ticks (TR-state-004)
- `TickGuard extends RefCounted` holds one `bool`. `Battle` holds it as a private member, `_tick_guard`, so its Callable stays valid (ADR-0001 Guideline 5).
- The Builder injects `TickGuard.in_tick` as a method Callable into Flow, TowerSim, HeroSim and Combat.
- Every command (`start_wave`, `call_early`, `build`, `upgrade`, `pin`, `burst`) checks `in_tick()` first. If true it changes nothing, emits nothing, reports `ERR_COMMAND_IN_TICK` to the dev-error sink and returns a refusal. The result value is ADR-0010's to name (proposed `IN_TICK`, placed before `HALTED`).
- `Combat.deliver()` checks `in_tick()` too; outside a tick it applies 0 and reports a dev error (Combat Rule 2: `deliver` never runs outside a tick).
- Bots and tests issue commands the same way: a command script is a list of `(tick_index, command)` pairs, each applied after `tick_index` ticks have run and before the next. The harness owns timeouts; ADR-0010 owns the command enums.

### 7. Frame budget (QQ-11, frame part)
- Architecture Data Flow 10's split stands as the working budget: input 0.5 ms, simulation 4.0 ms per frame, views and HUD 3.0 ms, engine 7.0 ms, headroom 2.1 ms, at 60 fps (16.6 ms).
- This ADR owns the simulation slice. Targets: one tick at p95 at most **2.0 ms** on an Adreno 5xx-class phone at the starter stage's worst wave; a normal 60 fps frame runs one tick.
- At the first phone build, measure the p95 cost of one tick (`p95_tick_ms`), then set `MAX_TICKS_PER_FRAME = clamp(floor(8.0 / p95_tick_ms), 2, 4)`: a stall frame may spend at most 8 ms on catch-up, and at least 2 ticks are owed per frame at 30 fps. If `p95_tick_ms` is above 4.0 ms, 30 fps cannot hold full speed: that reopens ADR-0009's per-tick budget, not this clamp. Record the numbers in this ADR by amendment.
- The views slice and draw calls are ADR-0011's.

### 8. Randomness (TR-state-005, TR-enemy-007)
- **At MVP, no simulation system draws a random number.** Waves are authored (Enemy & Wave Rule 6), all hits are instant and every tie breaks by `spawn_id` or slot index. The seed still enters through `build(..., rng_seed, ...)` and `Battle` keeps it as a read-only `rng_seed` for logs and replays of a result.
- **When a GDD first adds sim randomness**, the Builder creates one `RandomNumberGenerator` per consuming system, seeded with `rng_seed * 1_000_003 + SALT` in `int` arithmetic (AppRoot keeps `rng_seed` in 0 to 2^31 - 1, so it never overflows), where `SALT` is a fixed constant per consumer named in that system's file. Per-consumer streams mean adding a consumer, or one consumer drawing more, never shifts another's numbers. The generator is a member of `Battle` and is injected as an object only into its one consumer. This ADR is amended to list each consumer.
- **Cosmetic randomness** (the `fast` enemy's ±1.5 px jitter, any later VFX) uses a `RandomNumberGenerator` owned by the wrapper, never passed to the sim, never seeded from `rng_seed`. Its draw count may vary freely with frame rate and Reduce Motion.
- **Banned in `src/foundation`, `src/core` and `src/feature`**: the global `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed`, `rand_from_seed`, and `Array.shuffle()` / `Array.pick_random()` **[E5]**. `RandomNumberGenerator.new()` is allowed only in the Builder and the wrapper.

### 9. Float policy and determinism scope (QQ-05, TR-hero-006, TR-combat-014)
- GDScript `float` is 64-bit. `Vector2` components are 32-bit in a stock build **[E2]**.
- **Simulation maths uses `float` scalars and only `+`, `-`, `*`, `/`, `sqrt()`, `min`, `max`, `abs`, `floor`, `round` and comparisons.** `Vector2` is storage only: construct it, read `.x` and `.y`. No `Vector2` or `Rect2` method (`distance_to`, `distance_squared_to`, `length`, `normalized`, `lerp`, `has_point`, `angle`) and no transcendental (`sin`, `cos`, `atan2`, `pow`, `exp`, `log`) runs in `src/foundation`, `src/core` or `src/feature` sim code. This extends TR-hero-006's PinGeometry rule to the whole sim. Reason: IEEE-754 basic operations and `sqrt` are correctly rounded on every CPU, while engine C++ methods and the platform maths library may differ by compiler or CPU.
- State that accumulates (enemy `distance`, HP, hero walk ratio) is a `float` scalar. Cached `position: Vector2` values are recomputed each tick from those scalars, so 32-bit rounding never accumulates across ticks.
- Equality on floats is exact where the GDDs say so (slow strengths, distance ties); tolerances are the ones the GDDs state (Hero `walk_ticks`, PinGeometry margins).
- **Determinism is promised per CPU architecture only.** Bot baselines are stored per architecture at `tests/baselines/<arch>/`, where `<arch>` is `Engine.get_architecture_name()` **[E4]**. A baseline from one architecture never fails a run on another; a missing baseline for the running architecture is a report, not a pass.
- Gameplay code never reads `Engine`, `Time`, `OS`, a `Timer`, a SceneTree timer or `await` (B4, ADR-0001). Only the wrapper reads `delta`.

### Architecture Diagram

```
Godot main loop, one frame
  input callbacks (ADR-0003) ─► resolver signals ─► HeroInput / TowerInput / HudLogic
                                   │ commands: TickGuard.in_tick() is false here ─► sims
  ... AppRoot._process (ADR-0001 latches) ...
  BattleWrapper._process(delta)
    1  ms = min(delta*1000, 100) ─► HudLogic.advance(ms), ChipWindow.advance(ms), HeroInput.update()
    2  n = TickClock.advance(delta, battle.clock_running())      [0 and acc=0 when gate closed]
       repeat n: battle.tick(dt); stop early when clock_running() is false
    3  views refresh from read-only queries ─► queue_redraw()

Battle.tick(dt)                                  [headless: tests and bots call this directly]
  dt == TickMath.dt ? ─ no ─► fatal("tick_dt_mismatch")
  phase WAVE|INTERMISSION and not halted() ? ─ no ─► return
  TickGuard.enter()
    Flow.tick ─► EnemyWave.advance ─► Combat.tick_status(roster) ─► TowerSim.tick
       ─► HeroSim.tick ─► EnemyWave.reap          [halted() after each: break]
  tick_count += 1; TickGuard.exit()

Foundation: TickMath (TICK_RATE, TICK_SECONDS, dt, to_ticks) ◄── ADR-0002 validator floor
Composition: Battle holds _tick_math, _tick_guard, _halt_gate; Wrapper holds TickClock
```

### Key Interfaces

```gdscript
class_name TickMath extends RefCounted          # src/foundation/time/tick_math.gd
const TICK_RATE: int = 60
const TICK_SECONDS: float = 1.0 / TICK_RATE     # ADR-0002's one-tick floor reads this
var dt: float                                   # read-only by contract
func _init(tick_dt: float, dev_error: Callable) -> void
## round(seconds / dt), halves away from zero. Non-finite or negative: dev error, 0.
func to_ticks(seconds: float) -> int

class_name TickGuard extends RefCounted          # src/foundation/time/tick_guard.gd
func enter() -> void
func exit() -> void
func in_tick() -> bool

class_name TickClock extends RefCounted          # src/root/tick_clock.gd (wrapper-owned)
const MAX_TICKS_PER_FRAME: int = 4              # provisional; Decision 7 sets it
func _init(tick_dt: float, dev_error: Callable) -> void
## Ticks owed this frame. running false: zero the accumulator, return 0.
func advance(delta: float, running: bool) -> int
## Zero and stay at 0 for good. Teardown step 1 (ADR-0001).
func stop() -> void

# Additions to Battle (ADR-0001 B4):
var rng_seed: int                               # read-only; logs only at MVP
var _tick_guard: TickGuard                      # private, holds the in_tick Callable target
func tick(dt: float) -> void                    # Decision 5
func clock_running() -> bool                    # WAVE or INTERMISSION, and not halted()
func tick_seconds() -> float                    # _tick_math.dt, for the wrapper
func tick_count() -> int                        # ticks that passed the gate

# Injected (additions to B9):
#   dt: float (plain value)        -> Flow, EnemyWave, HeroSim (and any sim that needs dt)
#   in_tick() -> bool              -> Flow, TowerSim, HeroSim, Combat (TickGuard.in_tick)
const MAX_REAL_MS_PER_FRAME: float = 100.0      # on BattleWrapper
```

Names are proposed here. `TickMath` matches ADR-0001; `TickGuard`, `TickClock` (architecture.md's "Clock"), `clock_running()`, `tick_seconds()`, `tick_count()`, `rng_seed` on `Battle` and the two B9 rows are new. QQ-16 may add a prefix (ADR-0007).

### Implementation Guidelines
1. Simulation time must advance only through `Battle.tick(dt)`, with `dt` equal to the build's `TickMath.dt`.
2. Only `BattleWrapper._process` may call `battle.tick`, apart from tests and bots. Gameplay code must never implement `_process` or `_physics_process`, create a `Timer`, use `await`, or read `Engine`, `Time` or `OS`.
3. The wrapper must run the frame in Decision 4's order: real-time models, then ticks, then view refresh. No other battle node may read sim state from its own `_process`.
4. `TickClock` must zero its accumulator whenever `battle.clock_running()` is false, cap owed ticks at `MAX_TICKS_PER_FRAME`, and drop the excess when the cap applies.
5. `Battle.tick` must run the six steps in Decision 5's order and break when `halted()` turns true after any step.
6. Every countdown must be an `int` of ticks; every authored duration must pass through `TickMath.to_ticks`. No code may subtract `dt` from a float countdown.
7. Every sim command must check the injected `in_tick()` first and refuse with no change and no emit when it is true. `Combat.deliver` must apply 0 outside a tick.
8. Real-time models (HudLogic, ChipWindow, HeroInput) must take time only from the wrapper's `advance(ms)` or `update()` calls, clamped to `MAX_REAL_MS_PER_FRAME`, and must never read engine time.
9. Code under `src/foundation`, `src/core` and `src/feature` must never call the global random functions, `Array.shuffle()` or `Array.pick_random()`. `RandomNumberGenerator.new()` may appear only in the Builder and the wrapper. The cosmetic generator must never reach a sim object.
10. Sim maths must use `float` scalars with the operations in Decision 9 only. No `Vector2` or `Rect2` method and no transcendental function in sim code.
11. Nothing may set `Engine.time_scale`, `Engine.physics_ticks_per_second` or `SceneTree.paused`, and `application/run/low_processor_mode` must stay off.
12. Bot baselines must be read and written per architecture under `tests/baselines/<arch>/`.
13. ADR-0002's validator must read `TickMath.TICK_SECONDS` for every one-tick floor, never a literal.

## Alternatives Considered

### Alternative 1: Tick in `_physics_process` with `physics_ticks_per_second = 60`
- **Description**: let the engine's physics stepping call `battle.tick` once per physics step; `max_physics_steps_per_frame` acts as the clamp.
- **Pros**: no accumulator code; the engine already handles catch-up; familiar pattern.
- **Cons**: the engine's accumulator cannot be zeroed on pause, so a resume could owe a burst of steps; clamp and stall policy are global engine settings; the frame order spans two callbacks and depends on S1's second clause (no input between physics steps).
- **Rejection Reason**: it gives up control of the two things this ADR must decide (pause zeroing, clamp) and makes TR-hud-005 rest on an unverified engine order.

### Alternative 2: Variable `dt` (one tick per frame with the real delta)
- **Description**: `battle.tick(delta)` once per frame.
- **Pros**: simplest driver; smooth at any frame rate.
- **Cons**: breaks determinism and every whole-tick formula; the prototype's float countdowns drifted (5.0 s took 301 ticks).
- **Rejection Reason**: contradicts TR-state-003, TR-state-012 and TR-enemy-002.

### Alternative 3: 30 Hz tick
- **Description**: `TICK_RATE = 30`.
- **Pros**: half the sim cost; easier on low-end phones.
- **Cons**: the Data floor, starter values and GDD examples assume 1/60; coarser leak and burst timing; motion would need view interpolation.
- **Rejection Reason**: every authored value would need re-tuning, and the cost saving is unmeasured. Revisit only if Decision 7's measurement shows 60 Hz cannot fit.

### Alternative 4: Command queue drained at the start of the tick driver (ADR-0003's S1 fallback)
- **Description**: input owners push command records; the wrapper drains them before step 1.
- **Pros**: order independent of when the engine delivers input.
- **Cons**: commands lose the synchronous result the chip, arc and HeroInput use at once; more to tear down.
- **Rejection Reason**: with ticks in `_process`, shown equals paid under either input order (Decision 4). Kept as the fallback only if S1 shows input inside the wrapper's `_process`.

### Alternative 5: One shared sim RNG on `Battle` from the first build
- **Description**: `Battle` creates one `RandomNumberGenerator` seeded with `rng_seed` and injects it wherever randomness is wanted.
- **Pros**: one object; matches TR-state-005's wording directly.
- **Cons**: unused at MVP; with one stream, a new consumer or a changed draw count shifts every other system's numbers and every baseline.
- **Rejection Reason**: per-consumer streams made on first need keep baselines stable.

## Consequences

### Positive
- The whole frame order sits in one function and one integration test.
- The clock is pure maths and runs headless; pause, stall and teardown behaviour need no frames to test.
- TR-hud-005 no longer depends on spike check S1's outcome.
- Commands during a tick fail loudly instead of corrupting a tick.
- ADR-0002's floor check can be written now.
- Adding randomness later cannot shift existing baselines.

### Negative
- The wrapper's `_process` carries a hand-written accumulator (about 20 lines) instead of an engine feature.
- The float policy bans convenient `Vector2` methods in sim code, so distance and geometry helpers are written out in scalars; Combat's helpers and PinGeometry carry that cost.
- A stall drops time, so under a long hitch the battle runs slower than wall time (the GDD's choice).
- Baselines must be kept for each architecture that runs CI or bots.

### Neutral
- Physics settings stay at defaults. `rng_seed` is read by nothing at MVP (Enemy & Wave criterion 42).

## Risks
- **E1 fails (`round()` rounds halves to even)**: `to_ticks(0.125)` at `dt` 0.25 gives 0, and spawn ticks shift. Mitigation: V6 runs first; on failure `to_ticks` uses `floor(x + 0.5)` for the non-negative inputs it accepts, and ADR-0002's floor test re-runs.
- **E2 fails (`Vector2` is 64-bit)**: nothing breaks; record it.
- **Per-tick cost above 2 ms on the phone**: a 30 fps phone owes 2 ticks a frame and could slip under its frame budget. Mitigation: Decision 7's rule; ADR-0009 owns the per-tick work.
- **A notification runs `Flow.pause()` during a tick**: the dev error shows it; the tick still finishes whole.
- **A view reads live sim state in `_draw`**: Guideline 3 and a lint on `_process` in view scripts; ADR-0011 restates it.
- **Lint gaps** (a banned call through a helper outside the linted folders): ADR-0007 lints by call name across all of `src/`, except the two allowed files.
- **A listener issues a command**: the refusal's dev error names it; ADR-0006's rule that listeners never command is the main guard.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-003: time only through `battle.tick(dt)`; no engine time in gameplay; wrapper clamps | Decisions 1 to 3; Guidelines 1, 2, 4, 11 |
| game-state-stage-flow.md | TR-state-004: one fixed order; commands only between ticks | Decisions 5 and 6 (`TickGuard`), Guidelines 5, 7 |
| game-state-stage-flow.md | TR-state-005: all randomness from an injected seed | Decision 8: none at MVP; per-consumer seeded streams; globals banned |
| game-state-stage-flow.md | TR-state-006: Flow is a pure stage machine with a result readable after the outcome | Decision 5: only `Battle.tick` ticks Flow; the gate reads its phase. **Partial**: result contents and phase signals are ADR-0006's |
| game-state-stage-flow.md | TR-state-007: outcome sets state, stops the clock, cancels input, then emits; rest of tick skipped | Decision 5: state closes the gate; `halted()` break after each step; clock zeroes |
| game-state-stage-flow.md | TR-state-010 (shared): ticks stop and the accumulator is zeroed on Paused | Decision 3: `clock_running()` false in Paused; `TickClock` zeroes. ADR-0003 covers the rest |
| game-state-stage-flow.md | TR-state-012: one `to_ticks`; integer countdowns | Decision 2, Guideline 6 |
| game-state-stage-flow.md | TR-state-014: Lost delay, Won beat, arming on the frame clock outside the sim | Decision 4 step 1 |
| combat-damage.md | TR-combat-009: tick order; leaks before fire | Decision 5 |
| combat-damage.md | TR-combat-014: determinism per architecture; per-architecture baselines | Decision 9 |
| enemy-wave.md | TR-enemy-002: fixed `dt`, one `to_ticks` rounding half away from zero, absolute schedule | Decision 2 (E1 tested by V6) |
| enemy-wave.md | TR-enemy-003: advance and reap entries; battle passes the roster to `tick_status` | Decision 5 steps 2, 3, 6 |
| enemy-wave.md | TR-enemy-007: waves never read the seed; cosmetic RNG separate | Decision 8; retry rebuild is ADR-0001's |
| tower-system.md | TR-tower-005: ascending slot order; integer cooldown on every tick, Intermission included | Decision 5 step 4; Decision 2; gate runs in Intermission |
| tower-system.md | TR-tower-010: chip window on real time via `ChipWindow.advance(ms)` from the wrapper | Decision 4 step 1 |
| hero-system.md | TR-hero-003: Hero-and-burst slot; `to_ticks`; returns on `halted()` | Decision 5 step 5; Decision 2 |
| hero-system.md | TR-hero-006: PinGeometry in float scalars, no `Vector2` methods | Decision 9 (extended to all sim maths) |
| hero-system.md | TR-hero-011: HeroInput advances through explicit `update()` | Decision 4 step 1 |
| hero-system.md | TR-hero-013: pause stops the clock so walk and telegraph resume exactly; Build no ticks, Intermission ticks | Decisions 3 and 5 (gate); `drag_cancelled` on pause is ADR-0003's |
| battle-hud.md | TR-hud-005: input commands, real-time models, ticks, views; shown bonus equals paid | Decision 4, with the argument that it holds under either S1 result |
| battle-hud.md | TR-hud-007: arming on `advance(ms)` clamped to 100 ms, frozen while Paused | Decision 4 step 1 (`MAX_REAL_MS_PER_FRAME`); freeze rule stays in HudLogic |
| data-config-pipeline.md | ADR-0002 floor: one tick read from a constant | Decision 2: `TickMath.TICK_SECONDS` |

## Performance Implications
- **CPU**: the driver costs a few float operations per frame. The simulation slice is 4.0 ms per frame with a 2.0 ms p95 per-tick target (Decision 7). `TickGuard` and `clock_running()` are a few field reads per tick.
- **Memory**: three small `RefCounted` objects per battle (`TickMath`, `TickGuard`, `TickClock`). No per-tick allocation is added.
- **Load Time**: none.
- **Network**: none.

## Migration Plan
No code exists. Documents to sync, which this ADR does not edit:
1. `architecture.md`: Data Flow 1 (driver decided; S1 no longer critical; cite Decision 4), Data Flow 3 (the wrapper polls `clock_running()` instead of listening to `phase_changed(PAUSED)`), Data Flow 6 step 4, Data Flow 10 (Decision 7 rule), B0 (add `TickMath`, `TickGuard`, `TickClock`), B4 (`clock_running`, `tick_seconds`, `tick_count`, `rng_seed`, `_tick_guard`), B9 (add `dt` and `in_tick()` rows), Required ADRs (ADR-0004 written, Proposed), QQ-01 (resolved), QQ-05 (resolved pending V11a), QQ-08 (tick-order part waits for this ADR's acceptance), QQ-11 (frame part owned here).
2. GDDs: Game State's "Becomes an ADR (App Lifecycle & Composition)" line (after Rule 18) points at ADR-0004 for tick rate, order and clamp, and its "long frame" edge case names `MAX_TICKS_PER_FRAME`; Combat and Enemy & Wave Open Questions on the tick order point here; Battle HUD `ticks_per_second` is `TickMath.TICK_RATE`, and Rules 10, 18 and the "displayed bonus" edge case cite Decision 4; Tower's note on who feeds `ChipWindow` is answered (the wrapper); Data & Config's floor reads "one tick (`TickMath.TICK_SECONDS`)".
3. ADR-0003 Risks "S1 fails" and its Enables row: on its next revision, note that ADR-0004 does not adopt the queue (Decision 4). ADR-0003 is Accepted and is not edited here.
4. `requirements-traceability.md` and `tr-registry.yaml`: updated by `/architecture-review`, not here.

## Validation Criteria
Headless unless marked. ADR-0007 hosts them.
- **V1 `test_tick_clock`** (pure, `dt` 1/60): deltas of 1/60, 1/30, 0.5 s and 10 s owe 1, 2, 4 and 4; the cap zeroes the accumulator; `running` false returns 0 and zeroes; a negative or NaN delta returns 0 with one dev error; after `stop()` every call returns 0.
- **V2 `test_tick_order`**: recording fakes for the six steps log exactly Flow, advance, tick_status (receiving the roster), TowerSim, HeroSim, reap; a fake leak that latches `halted()` in step 2 logs nothing after it; `tick_count()` rises by one.
- **V3 `test_tick_gate`**: Build, Paused, Won, Lost and Fatal run no step and leave `tick_count()` unchanged; Wave and Intermission run all six; a `dt` other than the build's calls `fatal("tick_dt_mismatch")`.
- **V4 `test_command_in_tick_refused`**: a fake step that calls each command during a tick gets a refusal, no state change, no emit and one `ERR_COMMAND_IN_TICK`.
- **V5 `test_deliver_outside_tick`**: `deliver` between ticks applies 0 with one dev error.
- **V6 `test_to_ticks`**: Enemy & Wave criteria 37 to 39 (0.9 s is 54, 5.0 s is 300, 1/60 s is 1, 0.125 s at `dt` 0.25 is 1); a negative and a NaN input each give 0 with a dev error. Settles E1.
- **V7 `test_determinism_replay`**: two builds from the same catalogue, stage, seed and command script, run 3,000 ticks, give an identical per-tick digest of public reads (floats compared exactly); two different seeds give the same digest at MVP (Enemy & Wave criterion 42).
- **V8 `test_pause_resume_exact`**: pause mid-walk and mid-telegraph, call `tick` 100 times (gate closed), resume; the digest matches an unpaused run tick for tick.
- **V9 `test_frame_order`** (scene tree, headless, fake adapter input): during Intermission, read the displayed Call bonus after a wrapper `_process`, issue `call_early` before the next `_process`, and check paid gold equals the displayed bonus, across 200 frame deltas from a fixed list; also checks step order with spies and that `_process` with a 10 s delta runs at most `MAX_TICKS_PER_FRAME` ticks.
- **V10 `test_real_time_models`**: `advance` receives at most 100 ms per frame; Paused holds arming and the Won beat; ChipWindow and HeroInput read no engine time (spy).
- **V11 engine probes** (headless, results written with date and version into `docs/engine-reference/godot/` by the story that runs them): (a) `Vector2(0.1, 0.0).x == 0.1` is false under 32-bit components; (b) `Engine.get_architecture_name()` returns a non-empty name, else use `OS.has_feature("arm64")` / `"x86_64"`; (c) two `RandomNumberGenerator`s with equal `seed` give equal `randi()` sequences (runs before the first sim consumer); (d) `ProjectSettings` effective value of `application/run/low_processor_mode` is false.
- **V12 lint** (ADR-0007): Guidelines 2, 9 and 10 by call name over `src/`, with the two allowed files for `RandomNumberGenerator.new()`.
- **V13 device** (manual evidence in `production/qa/evidence/`, first phone build): p95 tick cost at the worst starter wave, frame time at 60 and 30 fps; sets `MAX_TICKS_PER_FRAME` by Decision 7.
- **V14**: ADR-0003's S1 result is recorded in this ADR. A result showing an input callback inside the wrapper's `_process` reopens Decision 4.

## Reviews
**Reviews still owed.** The godot-specialist engine check (skill step 5.5) and the TD-ADR strategic review (step 5.6) were not run in this session; the user will run both. Findings will be listed here with their resolutions before acceptance.

## Related
- ADR-0001 (depends on): `Battle`, `TickMath`, `HaltGate`, wrapper, teardown, B4, B9
- ADR-0002 (enabled): one-tick floor reads `TickMath.TICK_SECONDS`
- ADR-0003 (depends on): input path, `lifecycle_paused`, S1, S5
- Enables ADR-0006, ADR-0007, ADR-0009, ADR-0010, ADR-0011 (not written)
- `docs/architecture/architecture.md` v4: Data Flow 1, 2, 3, 6, 10; B0, B4, B5, B9; QQ-01, QQ-05, QQ-08, QQ-11
- GDDs: `design/gdd/game-state-stage-flow.md` (Rules 4, 5, 8, 10, 15, 17; Formulas; Edge Cases), `design/gdd/combat-damage.md` (Rules 2, 7, 9, 11), `design/gdd/enemy-wave.md` (Rules 6 to 12; `to_ticks`, `spawn_tick`; criteria 37 to 42), `design/gdd/tower-system.md` (Rules 8 to 10, 15), `design/gdd/hero-system.md` (Rules 6, 9, 16, Tick; `walk_ticks`; PinGeometry), `design/gdd/battle-hud.md` (Rules 10, 11, 18; `display_seconds`), `design/gdd/data-config-pipeline.md` (field domains)
