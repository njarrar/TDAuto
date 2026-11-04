# ADR-0003: Fixed Tick, Time and Determinism

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

Godot specialist (author, autonomous run). TD-ADR: not run per ADR; batch review after all ADRs are written. Engine specialist gate: not run per ADR; same batch review.

## Summary

TowerRiot must give the same result for the same stage, seed and command script on a phone, in tests and in bots, so simulation time cannot come from the engine's frame or physics loop. Time enters the sim only through `Battle.tick()`, one fixed 1/60 s step per call; a shell `BattleWrapper` in `_process` asks a plain `FixedStepClock` how many ticks are owed (at most 6 per frame), authored seconds become ticks through one `SimTime.to_ticks`, and the tick order is fixed in `Battle.tick()`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2 installed, matches the pin) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` (`OS.get_ticks_msec` replaced by `Time`), `current-best-practices.md`; official class reference at tag 4.7.2-stable: `doc/classes/Node.xml`, `doc/classes/MainLoop.xml`, `doc/classes/Engine.xml`, `doc/classes/ProjectSettings.xml`, `doc/classes/SceneTree.xml`, `doc/classes/@GlobalScope.xml`, `doc/classes/float.xml`, `doc/classes/Vector2.xml`, `doc/classes/RandomNumberGenerator.xml`, `doc/classes/Time.xml` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Device run of the frame hook (NOT SOURCEABLE list); per-architecture bot baselines |

### Sourced engine facts

| Claim | Source |
|---|---|
| `_process` is called each idle frame, before rendering and after physics ticks; `delta` is time between frames | doc/classes/Node.xml@4.7.2-stable, `_process`; doc/classes/MainLoop.xml@4.7.2-stable, `_process` |
| `_process` `delta` is capped at `Engine.time_scale * Engine.max_physics_steps_per_frame / Engine.physics_ticks_per_second` when the frame rate drops | doc/classes/Node.xml@4.7.2-stable, `_process` (Note) |
| `delta` is constant per frame under `--fixed-fps` or Movie Maker, and may be filtered by delta smoothing | doc/classes/Node.xml@4.7.2-stable, `_process` (Notes) |
| `application/run/delta_smoothing` defaults to `true` and only acts with V-Sync enabled | doc/classes/ProjectSettings.xml@4.7.2-stable, `application/run/delta_smoothing` |
| `_physics_process` `delta` equals `Engine.time_scale / Engine.physics_ticks_per_second`; accumulated delta may diverge from real seconds | doc/classes/Node.xml@4.7.2-stable, `_physics_process` |
| `Engine.physics_ticks_per_second` defaults to 60; `Engine.max_physics_steps_per_frame` defaults to 8; above that limit the project appears to slow down | doc/classes/Engine.xml@4.7.2-stable, `physics_ticks_per_second`, `max_physics_steps_per_frame`; doc/classes/ProjectSettings.xml@4.7.2-stable, `physics/common/physics_ticks_per_second`, `physics/common/max_physics_steps_per_frame` |
| `Engine.physics_jitter_fix` defaults to 0.5 and lets the in-game clock deviate from real time | doc/classes/Engine.xml@4.7.2-stable, `physics_jitter_fix` |
| `Engine.time_scale` defaults to 1.0 and scales `delta` for `_process`, `_physics_process`, `Timer` and `SceneTreeTimer` | doc/classes/Engine.xml@4.7.2-stable, `time_scale` |
| Process order follows `process_priority`, lower first, then tree order | doc/classes/Node.xml@4.7.2-stable, `_process`, `process_priority` |
| `roundi(x)` rounds halfway cases away from 0 and returns `int` | doc/classes/@GlobalScope.xml@4.7.2-stable, `roundi` |
| GDScript `float` is 64-bit; `Vector2` is 32-bit unless built with `precision=double`; float math is not exact | doc/classes/float.xml@4.7.2-stable; doc/classes/Vector2.xml@4.7.2-stable |
| `RandomNumberGenerator` gives a reproducible sequence for a given seed, but its algorithm "should not be depended upon" | doc/classes/RandomNumberGenerator.xml@4.7.2-stable, class description and `seed` |
| `Time.get_ticks_usec()` returns microseconds since engine start; Node.xml advises it for real-world time instead of `delta` | doc/classes/Time.xml@4.7.2-stable, `get_ticks_usec`; doc/classes/Node.xml@4.7.2-stable, `get_process_delta_time` (Note) |

### NOT SOURCEABLE (blocks Acceptance)

- NOT SOURCEABLE: the real spread of `_process` `delta` on the low-end target phone with V-Sync and delta smoothing on, and so how often the 6-tick clamp engages in normal play; needs a device run.
- NOT SOURCEABLE: whether float results of the same tick script match between x86 desktop and ARM phones (the reference says float math is inexact, not whether it differs by CPU); needs bot runs on both.
- NOT SOURCEABLE: whether `--fixed-fps` with `--headless` is needed for the bot runner at all, given bots call `tick()` directly; needs the ADR-0013 harness run.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (sim is `RefCounted`, no engine clock) |
| **Enables** | ADR-0005 (commands between ticks), ADR-0007, ADR-0009, ADR-0010, ADR-0011 (tick-based timers), ADR-0013 (bots on the fixed tick) |
| **Blocks** | Game State & Stage Flow, Enemy & Wave, Tower and Hero epics; any story with a timer |
| **Ordering Note** | Accept together with ADR-0002, which resets the clock on pause and Retry |

## Context

### Problem Statement

The game needs reproducible battles (TR-flow-011) and bots that run faster than real time, while the phone renders at an uneven frame rate. The open questions are where the frame hook lives, the clamp value (QQ-02), how authored seconds become ticks, and how float results are kept comparable (QQ-09).

### Current State

No code exists. `project.godot` sets no physics or timing keys, so engine defaults apply.

### Constraints

- No `_process`, engine timer, `await`, wall clock or physics area in gameplay (TR-flow-003).
- Commands apply only between ticks (TR-flow-004).
- HUD real-time models use `advance(ms)` clamped to 100 ms and ignored while Paused (TR-hud-004).
- Single thread.

### Requirements

- One fixed step of 1/60 s per `Battle.tick()` call.
- A fixed system order per tick.
- `to_ticks(seconds) = round(seconds / dt)`, halves away from zero.
- Same stage, seed and command script give the same result.

## Decision

1. **Tick length.** `SimTime.DT = 1.0 / 60.0`. Gameplay timers, cooldowns, telegraphs and spawn times are whole `int` ticks.
2. **One entry for time.** Only `Battle.tick()` advances the sim, one step per call. `Battle.tick()` returns at once when Paused or halted. It sets `HaltState.in_tick()` true for its duration.
3. **Tick order**, owned by `Battle.tick()` and never reordered: FlowSim.tick, EnemyWave.advance (spawn, move, leak), Combat.tick_status, TowerSim.tick by slot index, HeroSim.tick (hero attack, then burst), EnemyWave.reap (kills, then the clear check).
4. **Frame hook in `_process`, not `_physics_process`.** The BattleWrapper (shell `Node`) overrides `_process(delta)`, calls `n = clock.advance(delta)` and then `battle.tick()` n times. Reasons: `_physics_process` delta is `time_scale / physics_ticks_per_second` and drifts from real time by design (Node.xml), its rate is a project setting shared with the physics engine, and it runs before `_process` in the same frame (Node.xml, `_process`), which would put ticks before the HUD's same-frame bookkeeping. `_process` keeps the sim's rate in the sim (`SimTime.DT`), independent of physics settings.
5. **`FixedStepClock`** (plain `RefCounted`, headless-tested) keeps a `float` accumulator in seconds. `advance(real_seconds)`: ignore values that are not finite or are negative; add; owe `floor(acc / DT)` ticks; clamp owed ticks to `MAX_TICKS_PER_FRAME = 6` (100 ms of sim, matching the HUD's 100 ms clamp); when clamped, drop the excess time (the game slows, it does not spiral); subtract owed ticks times `DT`. `reset()` zeroes the accumulator; called on pause, resume and Retry. The engine's own cap on `delta` (8/60 s at defaults, Node.xml) sits above this clamp, so ours is the one that acts.
6. **Engine settings.** The game must never set `Engine.time_scale`; it stays 1.0. The BattleWrapper asserts `Engine.time_scale == 1.0` in debug builds at start. Physics settings are left at defaults and are not used for gameplay. Delta smoothing stays at its default; it only shapes real-time feel, not the sim's step.
7. **Process order.** AppRoot's `process_priority` is lower than the BattleWrapper's (latches first, ADR-0002); the HUD and views run after the wrapper (higher `process_priority`), so they draw the state after the frame's ticks.
8. **Authored time.** `SimTime.to_ticks(seconds: float) -> int` returns `roundi(seconds / DT)`, which rounds halves away from zero (@GlobalScope.xml, `roundi`). It is the only conversion. The catalogue stores seconds; systems convert at the moment of use.
9. **HUD clock.** HudLogic, ChipWindow and other real-time presentation models run on `advance(ms: int)`. The BattleWrapper (or the HUD node) passes `mini(roundi(delta * 1000.0), 100)`, and passes nothing while Paused. These clocks never feed the sim; ChipWindow's result reaches the sim only as an `upgrade` command.
10. **Seed.** `SimTime` holds the seed given to `BattleBuilder.build`. No MVP system reads it. A later system that needs randomness must use its own generator seeded from it, not the global random functions, and must not rely on the generator's algorithm across engine versions (RandomNumberGenerator.xml). Cosmetic jitter never uses it.
11. **Float policy.** Sim math uses scalar `float` (64-bit) where exact compares matter (ADR-0001). Bot baselines are recorded per CPU architecture (x86_64 and arm64) until a device run shows they match.
12. **Determinism scope.** A command script is keyed by tick index. Bots and tests call commands and `tick()` directly and never use the clock. A human run is not reproducible from frame timing, and need not be.

### Architecture Diagram

```
 frame (process order by process_priority)
   input callback ─▶ commands on Battle (between ticks)
   AppRoot._process      (latches; ADR-0002)
   BattleWrapper._process(delta):
       n = FixedStepClock.advance(delta)        # 0..6
       repeat n: Battle.tick()
           in_tick = true
           FlowSim ▶ EnemyWave.advance ▶ Combat.tick_status ▶ TowerSim ▶ HeroSim ▶ EnemyWave.reap
           in_tick = false
       hud.advance(min(ms, 100))  unless Paused
   HUD and views: read BattleReadModel, queue_redraw on change

 bots and tests: Battle.command(...) ; Battle.tick() ; ...   (no clock, no engine)
```

### Key Interfaces

```gdscript
class_name SimTime extends RefCounted
const DT: float = 1.0 / 60.0
static func to_ticks(seconds: float) -> int    # roundi(seconds / DT)
func seed() -> int

class_name FixedStepClock extends RefCounted
const MAX_TICKS_PER_FRAME: int = 6
func advance(real_seconds: float) -> int       # ticks owed this frame, 0..MAX_TICKS_PER_FRAME
func reset() -> void

# on Battle (ADR-0001, architecture.md API Boundaries)
func tick() -> void
```

### Implementation Guidelines

- Gameplay code must never use `_process`, `_physics_process`, `Timer`, `SceneTreeTimer`, `await`, `Time`, `OS` time calls or `delta`.
- Only the BattleWrapper may call `battle.tick()` in a running game.
- Every authored duration must be converted with `SimTime.to_ticks`; no other rounding of time is allowed.
- Gameplay timers must be `int` ticks.
- The tick order must live only in `Battle.tick()`.
- The game must never write `Engine.time_scale`, `Engine.physics_ticks_per_second` or `Engine.max_physics_steps_per_frame`.
- `FixedStepClock.reset()` must be called on pause, resume and Retry.
- Real-time HUD models must take `advance(ms)` clamped to 100 and must not advance while Paused.
- Systems needing randomness must use an injected generator seeded from `SimTime.seed()`.

## Alternatives Considered

### Alternative 1: Tick in `_physics_process`
- **Description**: Set `physics_ticks_per_second` to 60 and call `battle.tick()` once per physics step.
- **Pros**: The engine does the accumulation.
- **Cons**: Delta and step count are shaped by `physics_jitter_fix` and `max_physics_steps_per_frame` (Engine.xml); the rate lives in a physics setting; runs before `_process` in the frame.
- **Estimated Effort**: Slightly lower.
- **Rejection Reason**: Puts sim time under engine settings the sim cannot see; harder to test headless.

### Alternative 2: Variable step (pass `delta` into systems)
- **Description**: Each system scales by frame delta.
- **Pros**: Smooth at any frame rate.
- **Cons**: Results depend on frame timing; not reproducible.
- **Rejection Reason**: Breaks TR-flow-011.

### Alternative 3: Engine timers and `await` for gameplay waits
- **Description**: Use `Timer` nodes and coroutines for cooldowns and spawns.
- **Rejection Reason**: Nodes are absent headless; scaled by `time_scale` (Engine.xml); banned by TR-flow-003.

### Alternative 4: No clamp, or the engine's 8-step cap only
- **Description**: Owe every tick of real time.
- **Cons**: A long frame on a slow phone runs up to 8 ticks, longer than the HUD's 100 ms clamp, so HUD and sim drift apart.
- **Rejection Reason**: The 6-tick clamp keeps both clocks bounded the same way.

## Consequences

### Positive
- Bots and tests run the exact same tick as the phone, as fast as the CPU allows.
- One rounding rule for all authored time.
- Frame drops slow the game evenly instead of skipping logic.

### Negative
- On a phone under 10 FPS the game runs slower than real time.
- No interpolation: enemies move in 1/60 s steps, which may show uneven motion on displays not at 60 Hz.

### Neutral
- Physics settings stay at defaults and are unused.

## Risks

- **Uneven motion at 90 or 120 Hz.** Mitigation: device check; view-side interpolation can be added later without touching the sim.
- **Float drift between CPUs.** Mitigation: per-architecture baselines; scalar 64-bit compares.
- **Accumulator float error over long sessions.** The accumulator holds under one step after each frame, so error does not grow. Unit test with many small deltas.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-flow-003: time enters only through `Battle.tick()`, fixed 1/60 s; no `_process`, timer, `await`, wall clock, physics area in gameplay | Decisions 1, 2, 4; guidelines |
| game-state-stage-flow.md | TR-flow-004: fixed system tick order; commands only between ticks | Decision 3; `in_tick()` refusal (ADR-0005) |
| game-state-stage-flow.md | TR-flow-011: same stage, seed and script give the same result | Decisions 10 to 12 |
| game-state-stage-flow.md | TR-flow-012: `to_ticks(seconds) = round(seconds / dt)`, halves away from zero | Decision 8, `roundi` |
| enemy-wave.md | TR-wave-002: absolute spawn schedule in whole ticks, no randomness | Decisions 1 and 8 |
| enemy-wave.md | TR-wave-004: movement `d_next = d + speed x factor x dt` | `SimTime.DT` is the `dt` |
| battle-hud.md | TR-hud-004: real-time models on `advance(ms)` clamped to 100 ms, ignored while Paused | Decision 9 |
| battle-hud.md | TR-hud-012: every HUD timer on one `advance` clock; chip bar shows Tower's window | Decision 9 |

## Performance Implications
- **CPU**: Up to 6 ticks per frame in the worst case; the tick budget is set by ADR-0007 and ADR-0012.
- **Memory**: None.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

No code exists.

**Rollback plan**: Moving the hook to `_physics_process` changes only the BattleWrapper; supersede this ADR.

## Validation Criteria

- Unit: `to_ticks(0.5)` is 30 and `to_ticks(15.0)` is 900. Halfway cases: `seconds / DT` near x.5 may not be exact in binary floats, so the test must first assert the quotient is exactly x.5 on 4.7.2 before asserting the rounding direction (for example, 2 and -2 for a quotient of 1.5 and -1.5).
- Unit: `FixedStepClock` owes 1 tick per 1/60 s, at most 6 per call, 0 after `reset()`, and ignores negative or non-finite input.
- Unit: the tick order test with recording systems (ADR-0001 seam).
- Bot: the same script and seed give identical snapshots on two runs on one machine; baselines kept per architecture.
- Device: frame log on the target phone shows clamp engagement rate and no tick after `pause()`.

## Related

- ADR-0001 (depends on), ADR-0002 (clock reset, process priority), ADR-0005, ADR-0013
- `docs/architecture/architecture.md` (Data Flow 2 and 6; Module Ownership: FixedStepClock, BattleWrapper, SimTime; QQ-02, QQ-09)
- `design/gdd/game-state-stage-flow.md`, `design/gdd/enemy-wave.md`, `design/gdd/battle-hud.md`
