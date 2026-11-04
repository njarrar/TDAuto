# ADR-0004: Fixed-Tick Clock, Tick Order, Frame Order and Determinism

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

godot-specialist (draft). Acceptance: the user, or technical-director on the user's confirmation.

TD-ADR: not run per ADR; batch review after all ADRs are written.

## Summary

A battle must give the same result for the same stage, seed and command script on a phone, in tests and in bots, so simulation time cannot come from the engine's frame or physics loop. Time enters the sim only through `Battle.tick(dt)` at a fixed 1/60 s step, driven by the BattleWrapper's Clock in `_process` with a catch-up clamp; the tick order, the frame order, the in-sim gate, integer tick timers, one `to_ticks`, the seeded and cosmetic RNG split and per-architecture baselines are fixed here.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2 installed, matches the pin) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (input-before-`_process` order on 4.7 is unreferenced; float behaviour across CPUs is unreferenced) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/architecture/architecture.md` v3 (Data Flow 1, 2, 6 and 10; API Boundaries B4, B5 and B9; QQ-01, QQ-05, QQ-11); official class reference at tag 4.7.2-stable: `doc/classes/Node.xml`, `doc/classes/MainLoop.xml`, `doc/classes/Engine.xml`, `doc/classes/ProjectSettings.xml`, `doc/classes/Input.xml`, `doc/classes/@GlobalScope.xml`, `doc/classes/float.xml`, `doc/classes/Vector2.xml`, `doc/classes/RandomNumberGenerator.xml`, `doc/classes/Time.xml` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | The runs in NOT SOURCEABLE below; bot baselines per CPU architecture |

### Sourced engine facts

| Claim | Source |
|---|---|
| `_process` is called each idle frame, after the frame's physics ticks and before rendering; `delta` is the time between frames | doc/classes/Node.xml@4.7.2-stable, `_process`; doc/classes/MainLoop.xml@4.7.2-stable, `_process` |
| `_process` `delta` is capped at `Engine.time_scale * Engine.max_physics_steps_per_frame / Engine.physics_ticks_per_second` when the frame rate drops | doc/classes/Node.xml@4.7.2-stable, `_process` (Note) |
| `delta` is constant per frame under `--fixed-fps` or Movie Maker, and may be filtered by delta smoothing | doc/classes/Node.xml@4.7.2-stable, `_process` (Notes) |
| `application/run/delta_smoothing` defaults to `true` and acts only with V-Sync on | doc/classes/ProjectSettings.xml@4.7.2-stable, `application/run/delta_smoothing` |
| `_physics_process` `delta` equals `Engine.time_scale / Engine.physics_ticks_per_second`; accumulated delta may diverge from real seconds | doc/classes/Node.xml@4.7.2-stable, `_physics_process` |
| `Engine.physics_ticks_per_second` defaults to 60; `Engine.max_physics_steps_per_frame` defaults to 8; above it the project appears to slow down | doc/classes/Engine.xml@4.7.2-stable, `physics_ticks_per_second`, `max_physics_steps_per_frame`; doc/classes/ProjectSettings.xml@4.7.2-stable, `physics/common/physics_ticks_per_second`, `physics/common/max_physics_steps_per_frame` |
| `Engine.physics_jitter_fix` defaults to 0.5 and lets the in-game clock deviate from real time | doc/classes/Engine.xml@4.7.2-stable, `physics_jitter_fix` |
| `Engine.time_scale` defaults to 1.0 and scales `delta` for `_process`, `_physics_process`, `Timer` and `SceneTreeTimer` | doc/classes/Engine.xml@4.7.2-stable, `time_scale` |
| Process callbacks run in `process_priority` order, lower first, regardless of tree order | doc/classes/Node.xml@4.7.2-stable, `process_priority` |
| With `input_devices/buffering/agile_event_flushing` false (default), input events are flushed once per process frame, between engine iterations; when true (Android only) before every idle and physics frame | doc/classes/ProjectSettings.xml@4.7.2-stable, `input_devices/buffering/agile_event_flushing` |
| Input accumulation is on by default and merges similar events per frame | doc/classes/Input.xml@4.7.2-stable, `use_accumulated_input` |
| `roundi(x)` rounds halfway cases away from 0 and returns `int` | doc/classes/@GlobalScope.xml@4.7.2-stable, `roundi` |
| GDScript `float` is 64-bit; `Vector2` is 32-bit unless the engine is built with `precision=double`; float math is not exact | doc/classes/float.xml@4.7.2-stable; doc/classes/Vector2.xml@4.7.2-stable |
| `RandomNumberGenerator` gives a reproducible sequence for a given seed, but its algorithm "should not be depended upon" | doc/classes/RandomNumberGenerator.xml@4.7.2-stable, class description and `seed` |
| `Time.get_ticks_usec()` returns microseconds since engine start; Node.xml advises it for real-world time instead of `delta` | doc/classes/Time.xml@4.7.2-stable, `get_ticks_usec`; doc/classes/Node.xml@4.7.2-stable, `get_process_delta_time` (Note) |

### NOT SOURCEABLE (blocks Acceptance)

- NOT SOURCEABLE: whether input events flushed in a frame are always dispatched before that frame's `_process` on Android, iOS and desktop. The reference states the flush point, not the dispatch order against `_process`. ADR-0003's spike owns the test; settled by the phone session, with a desktop headless run for desktop.
- NOT SOURCEABLE: the real spread of `_process` `delta` on the low-end target phone with V-Sync and delta smoothing on, and so how often the clamp engages in normal play. Settled by the phone session.
- NOT SOURCEABLE: the worst-case cost of one tick on the target phone, which sets `MAX_TICKS_PER_FRAME` (Decision 5). Settled by the phone session.
- NOT SOURCEABLE: whether the same tick script gives bit-identical float results on x86_64 desktop and arm64 phones. The reference says float math is inexact, not whether it differs by CPU. Settled by CI (x86_64 baseline) plus the phone session (arm64 baseline).
- NOT SOURCEABLE: whether `seconds / DT` gives an exact `x.5` for the authored halfway cases, so that `roundi` decides the direction. Settled by a desktop headless run of the `to_ticks` test, then CI.
- NOT SOURCEABLE: whether `Vector2` is 32-bit in the stock 4.7.2 export templates used for the phone build (QQ-05). Settled by the phone session; until then PinGeometry uses float scalars.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Battle is a `RefCounted` built headless; Battle holds every sim; `halted()` and the fatal path), ADR-0003 (engine event order against `_process`; the adapter's lifecycle signal that drives Flow's PAUSED) |
| **Enables** | ADR-0006 (signals emitted inside the tick), ADR-0010 (commands between ticks; HeroInput `update()`; bot equivalence on the fixed tick); every tick-based timer in ADR-0009 stories |
| **Blocks** | Game State & Stage Flow, Enemy & Wave, Tower, Hero and Battle HUD epics; any story with a timer or a cooldown |
| **Ordering Note** | ADR-0003's spike must report the event order before this ADR is Accepted. Accept with ADR-0001, which stops the Clock on Retry. |

## Context

### Problem Statement

Battles must be reproducible (TR-state-005) and bots must run faster than real time, while the phone renders at an uneven frame rate. The open questions are where the frame hook lives, the tick rate, the clamp, how authored seconds become ticks, how real-time HUD clocks stay out of the sim, and how float results are compared (QQ-01, QQ-05, QQ-11).

### Current State

No code exists. `project.godot` sets no physics or timing keys, so engine defaults apply.

### Constraints

- No `_process`, Timer, `await`, wall clock or physics area in gameplay (TR-state-003).
- Commands apply only between ticks (TR-state-004).
- Single thread (architecture.md Data Flow).
- Frame budget proposal: 4.0 ms for all of a frame's ticks at 60 fps (Data Flow 10); 30 fps floor on low-end Android.

### Requirements

- One fixed step per `Battle.tick(dt)` call, in one fixed order.
- Integer tick countdowns; one `to_ticks` that rounds half away from zero (TR-state-012, TR-enemy-002).
- Real-time presentation clocks outside the sim, frozen while Paused (TR-state-014, TR-hud-007, TR-tower-010).
- The frame order makes the displayed bonus equal the paid bonus (TR-hud-005).

## Decision

1. **Tick rate.** `dt = 1.0 / 60.0`, fixed at build and held by a `TickTime` object (`RefCounted`) that `Battle` keeps as a typed field. Every gameplay timer, cooldown, telegraph, spawn time and `intermission_left` is an `int` tick count.
2. **One entry for time.** Only `Battle.tick(dt)` advances the sim, one step per call. `dt` must equal the battle's build-time `dt`; any other value is a bad call routed to `fatal`. `tick` returns at once unless `flow.phase()` is `WAVE` or `INTERMISSION` and `halted()` is false. The gate lives in the sim, so it holds headless. Build runs no ticks; Intermission ticks; Paused runs none, so walk and telegraph resume exactly (TR-hero-013).
3. **Tick order**, written once in `Battle.tick` and never reordered:
   1. `flow.tick()` (intermission countdown, wave start and clear checks)
   2. `enemy_wave.advance(tick)` (spawn from the absolute schedule, move, leak); leaks resolve before any fire
   3. `combat.tick_status(enemy_wave.roster())` (slow countdown)
   4. `tower_sim.tick()` (ascending slot index: cooldown, target, `report_attack`, `deliver`)
   5. `hero_sim.tick()` (walk, attack, cooldown, telegraph, release; burst after the hero)
   6. `enemy_wave.reap()` (remove corpses, emit `enemy_killed(bounty)` once each)

   After each step `Battle.tick` checks `halted()` and returns if it is set; each system also checks `halted()` after any read or signal that can commit an outcome (TR-state-007). A tick counter on `Battle` gives the `tick` argument and keys command scripts.
4. **Frame hook in `_process`, not `_physics_process`.** The BattleWrapper's `_process(delta)` drives the frame. `_physics_process` delta is `time_scale / physics_ticks_per_second` and drifts from real time by design, its rate is a physics setting, and it runs before `_process` in the same frame (Node.xml), which would put ticks before the real-time models.
5. **Clock and clamp.** The Clock (`RefCounted`, owned by the wrapper, tested headless) keeps a `float` accumulator in seconds. `advance(real_seconds) -> int`: ignore a value that is negative or not finite; add it; owed = `floori(acc / dt)`; clamp owed to `MAX_TICKS_PER_FRAME`; when clamped, drop the excess time (the game slows, it does not spiral); subtract owed times `dt`. `reset()` zeroes it. The wrapper calls `reset()` on `phase_changed(PAUSED)` and AppRoot's Retry stops the wrapper (ADR-0001). `MAX_TICKS_PER_FRAME` is the largest N where N times the measured worst-case tick cost fits the 4.0 ms tick slice, and never below 2, so the 30 fps floor keeps real time. Working value: **2** (Combat's unmeasured estimate is under 2 ms per tick). The phone session sets the final value. The engine's own `delta` cap (8/60 s at defaults) sits above this clamp, so ours acts first.
6. **Frame order** (Data Flow 1, TR-hud-005). Within one frame:
   1. Input events reach the adapter, the resolver and the input objects, whose commands (pin, burst, build, upgrade, `start_wave`, `call_early`) run at once, between ticks.
   2. `BattleWrapper._process(delta)`, unless Flow is PAUSED: `ms = mini(roundi(delta * 1000.0), 100)`; `hud_logic.advance(ms)`, `chip_window.advance(ms)`, `hero_input.update()`.
   3. `n = clock.advance(delta)`; call `battle.tick(dt)` n times.
   4. Refresh views from read-only queries and `queue_redraw` where a key changed.

   Steps 2 to 4 are explicit calls inside the one wrapper `_process`, not separate nodes, so `process_priority` is needed only to run AppRoot before the wrapper (ADR-0001).
7. **Real-time clocks.** HudLogic (button arming, Lost delay, Won beat), ChipWindow and HeroInput are presentation models with an explicit `advance(ms)` or `update()`. They are frozen while Paused, never read `delta`, `Time` or `Engine` themselves, and never feed the sim except by issuing a command.
8. **Authored time.** `TickTime.to_ticks(seconds: float) -> int` returns `roundi(seconds / dt)`. It is the only time conversion, injected into Combat, EnemyWave, TowerSim, HeroSim, Flow and HudLogic as a method Callable. The catalogue stores seconds; systems convert at use. Spawn ticks come from an absolute schedule, never a float countdown.
9. **Engine settings.** The game must never write `Engine.time_scale`, `Engine.physics_ticks_per_second` or `Engine.max_physics_steps_per_frame`. Physics settings stay at defaults and are unused. Delta smoothing stays at its default; it shapes only the real-time feel.
10. **Randomness.** The `seed` given to `BattleBuilder.build` is held by `TickTime`. Any sim randomness uses one `RandomNumberGenerator` the Builder creates with that seed and injects; global `randi`, `randf` and `randomize` are banned in the sim. No MVP system draws from it, and waves never read it (TR-enemy-007). Cosmetic jitter uses a separate generator owned by the views, never seeded from the sim seed and never read by the sim. Because the reference does not promise the algorithm across versions, baselines are also keyed by engine version.
11. **Float policy.** Sim maths that needs exact compares uses scalar `float` (64-bit); PinGeometry uses float scalars only (TR-hero-006). `Vector2` carries positions across boundaries. Bot baselines are recorded per CPU architecture (x86_64, arm64) and per engine version; determinism is promised within one architecture only (TR-combat-014).
12. **Determinism scope.** `(catalogue, stage_id, seed, command script)` determines the result, where a script is keyed by tick index. Bots and tests call commands and `tick(dt)` directly and never use the Clock. A human run is not reproducible from frame timing and need not be.
13. **Frame budget** (Data Flow 10, proposal). Input and commands 0.5 ms; ticks 4.0 ms total; views and HUD 3.0 ms; engine and OS 7.0 ms; headroom 2.1 ms. The phone session confirms or revises it with ADR-0011.

### Architecture Diagram

```
 one frame
   input flush ─▶ InputAdapter ─▶ InputResolver ─▶ HeroInput / TowerInput / HudLogic
                                                   └─ commands on sims (between ticks)
   AppRoot._process            (latches; lower process_priority; ADR-0001)
   BattleWrapper._process(delta):
     unless PAUSED: ms = min(round(delta*1000), 100)
                    hud_logic.advance(ms) ; chip_window.advance(ms) ; hero_input.update()
     n = clock.advance(delta)                       # 0..MAX_TICKS_PER_FRAME
     repeat n: battle.tick(dt)
        gate: WAVE or INTERMISSION, and not halted()
        flow ▶ enemy_wave.advance ▶ combat.tick_status ▶ tower_sim ▶ hero_sim ▶ enemy_wave.reap
     views: read queries, queue_redraw on change

 bots and tests: command ; battle.tick(dt) ; ...      (no Clock, no engine)
```

### Key Interfaces

```gdscript
class_name TickTime extends RefCounted
const TICK_RATE: int = 60
var dt: float                                   # 1.0 / TICK_RATE, set in _init
var seed: int
func to_ticks(seconds: float) -> int            # roundi(seconds / dt)

class_name Clock extends RefCounted             # name may take a prefix (QQ-16)
var max_ticks_per_frame: int = 2                # working value; phone session sets it
func advance(real_seconds: float) -> int        # ticks owed, 0..max_ticks_per_frame
func reset() -> void

# on Battle (ADR-0001)
func tick(dt: float) -> void
func tick_index() -> int
```

### Implementation Guidelines

- Gameplay code must never use `_process`, `_physics_process`, `Timer`, `SceneTreeTimer`, `await`, `Time`, `OS` time calls, `Engine` or frame `delta`.
- Only the BattleWrapper may call `battle.tick(dt)` in a running game; bots and tests call it directly.
- The tick order must live only in `Battle.tick`; no system calls another system's tick entry.
- Commands must never be issued from inside a tick or from a signal handler running inside a tick.
- Every authored duration must go through the injected `to_ticks`; no other rounding of time is allowed.
- Gameplay timers must be `int` ticks; float subtraction for countdowns is forbidden.
- The game must never write `Engine.time_scale`, `Engine.physics_ticks_per_second` or `Engine.max_physics_steps_per_frame`.
- The wrapper must call `clock.reset()` on `phase_changed(PAUSED)`.
- Real-time models must take `advance(ms)` clamped to 100 and must not advance while Paused.
- Sim randomness must use the injected seeded generator; global random functions are forbidden in the sim; cosmetic RNG must never be seeded from the sim seed.
- Exact geometric compares must use scalar `float`, never `Vector2` components after arithmetic.

## Alternatives Considered

### Alternative 1: Tick in `_physics_process`
- **Description**: Set `physics_ticks_per_second` to 60 and tick once per physics step.
- **Pros**: The engine accumulates.
- **Cons**: Step count shaped by `physics_jitter_fix` and `max_physics_steps_per_frame`; the rate lives in a physics setting; runs before `_process`.
- **Estimated Effort**: Slightly lower.
- **Rejection Reason**: Puts sim time under engine settings the sim cannot see, and breaks the frame order.

### Alternative 2: Variable step (pass `delta` into systems)
- **Description**: Each system scales by frame delta.
- **Pros**: Smooth at any frame rate.
- **Cons**: Results depend on frame timing.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Breaks TR-state-005.

### Alternative 3: Engine timers and `await` for gameplay waits
- **Description**: Timer nodes and coroutines for cooldowns and spawns.
- **Pros**: Familiar.
- **Cons**: Nodes are absent headless; scaled by `time_scale`.
- **Estimated Effort**: Lower at first.
- **Rejection Reason**: Banned by TR-state-003.

### Alternative 4: No clamp, or the engine's 8-step cap only
- **Description**: Owe every tick of real time.
- **Pros**: The game never slows.
- **Cons**: A long frame runs up to 8 ticks, past the 4.0 ms tick slice, and can spiral on a slow phone.
- **Estimated Effort**: Lower.
- **Rejection Reason**: The clamp bounds the tick cost per frame.

## Consequences

### Positive
- Bots and tests run the same tick as the phone, as fast as the CPU allows.
- One rounding rule for all authored time.
- Frame drops below the floor slow the game evenly instead of skipping logic.

### Negative
- Below 30 fps the game runs slower than real time.
- No interpolation: enemies move in 1/60 s steps, which may look uneven at 90 or 120 Hz.
- Baselines must be kept per CPU architecture and engine version.

### Neutral
- Physics settings stay at defaults and are unused.

## Risks

- **The clamp of 2 drops time at the 30 fps floor when a frame runs a little long.** Mitigation: the phone session measures clamp engagement; raise N if the tick cost allows.
- **Input arrives after `_process` on some platform.** Then commands land after the frame's ticks and the shown bonus can differ from the paid one. Mitigation: ADR-0003's spike; if it fails, revise this ADR before code.
- **Float drift between CPUs.** Mitigation: per-architecture baselines; scalar 64-bit compares.
- **Accumulator error over a long session.** The accumulator holds under one step after each frame, so error does not grow. Unit test with many small deltas.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-003: time only through `battle.tick(dt)` at a fixed rate; no `_process`, Timers, `await`, wall clock or physics areas; wrapper clamps owed ticks | Decisions 1, 2, 4 and 5 |
| game-state-stage-flow.md | TR-state-004: one fixed tick order; commands only between ticks | Decisions 3 and 6 |
| game-state-stage-flow.md | TR-state-005: all randomness from an injected seed | Decisions 10 and 12 |
| game-state-stage-flow.md | TR-state-006: pure Flow machine; `in_build()` true in Build and Paused from Build | Decision 2 (the gate reads `phase()`; Build and Paused run no ticks) |
| game-state-stage-flow.md | TR-state-007: commit, act, emit; outcomes stop the clock and cancel input; remaining systems skip the rest of the tick | Decisions 2, 3 and 5 |
| game-state-stage-flow.md | TR-state-012: one `to_ticks`; integer countdowns | Decisions 1 and 8 |
| game-state-stage-flow.md | TR-state-014: wrapper-side presentation timers on the frame clock | Decisions 6 and 7 |
| combat-damage.md | TR-combat-009: tick order Flow, advance, `tick_status`, towers by slot, hero then burst, reap | Decision 3 |
| combat-damage.md | TR-combat-014: determinism per CPU architecture; baselines per architecture | Decision 11 |
| enemy-wave.md | TR-enemy-002: fixed `dt`, one `to_ticks` rounding half away from zero; absolute spawn schedule | Decisions 1 and 8 |
| enemy-wave.md | TR-enemy-003: two tick entries, advance and reap; battle passes the roster to `tick_status` | Decision 3 |
| enemy-wave.md | TR-enemy-007: no randomness in waves; separate cosmetic RNG; retry rebuilds the same schedule | Decisions 10 and 12 |
| tower-system.md | TR-tower-005: towers by ascending slot; `cooldown_left` an int that runs every tick, Intermission included | Decisions 2 and 3 |
| tower-system.md | TR-tower-010: chip window on real time while the sim clock is stopped, via `ChipWindow.advance(ms)` | Decisions 6 and 7 |
| hero-system.md | TR-hero-003: HeroSim ticks in the hero-and-burst slot, uses `to_ticks`, returns when `halted()` | Decisions 3 and 8 |
| hero-system.md | TR-hero-006: PinGeometry in float scalars, no `Vector2` methods | Decision 11 |
| hero-system.md | TR-hero-011: HeroInput advances through explicit `update()` | Decisions 6 and 7 |
| hero-system.md | TR-hero-013: Pause stops the clock so walk and telegraph resume exactly; Build runs no ticks; Intermission ticks | Decision 2 |
| battle-hud.md | TR-hud-005: input commands, then real-time models, then ticks, then views | Decision 6 |
| battle-hud.md | TR-hud-007: arming on `advance(ms)` clamped to 100 ms, frozen while Paused | Decisions 6 and 7 |

## Performance Implications
- **CPU**: One tick per frame at 60 fps; at most `MAX_TICKS_PER_FRAME` in a slow frame, inside the 4.0 ms slice.
- **Memory**: Negligible; the Clock and `TickTime` are a few fields.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

No code exists. New code follows this ADR from the first story.

**Rollback plan**: If input proves to arrive after `_process`, supersede this ADR with a frame order that queues commands to the start of the next frame; the sim's tick order and gate do not change.

## Validation Criteria

- Unit: `to_ticks(0.5)` is 30 and `to_ticks(15.0)` is 900. For halfway cases the test first asserts the quotient is exactly x.5 on 4.7.2, then asserts the direction (2 and -2 for 1.5 and -1.5).
- Unit: the Clock owes 1 tick per 1/60 s, at most `max_ticks_per_frame` per call, 0 after `reset()`, and ignores negative or non-finite input; many small deltas leave the accumulator under one step.
- Unit: a recording fake per system shows the six steps in order each tick, and none after a `halted()` step.
- Unit: `tick(dt)` does nothing in BUILD and PAUSED, and runs in WAVE and INTERMISSION.
- Unit: a `tick` with a different `dt` calls `fatal`.
- Bot: the same script and seed give identical snapshots on two runs on one machine; baselines kept per architecture and engine version.
- Phone session: a frame log shows input commands before the frame's ticks, the clamp engagement rate, the per-tick cost, and no tick after `pause()`.

## Related

- ADR-0001 (depends on: Battle, Builder, fatal path, Retry), ADR-0003 (depends on: event order spike, lifecycle signal), ADR-0006 (signals inside the tick), ADR-0009 (Combat and roster APIs called in the tick), ADR-0010 (commands, HeroInput, bot equivalence), ADR-0011 (frame budget)
- `docs/architecture/architecture.md` v3: Data Flow 1, 2, 6 and 10; API Boundaries B4, B5 and B9; QQ-01, QQ-05, QQ-11
- `design/gdd/game-state-stage-flow.md`, `design/gdd/combat-damage.md`, `design/gdd/enemy-wave.md`, `design/gdd/tower-system.md`, `design/gdd/hero-system.md`, `design/gdd/battle-hud.md`
