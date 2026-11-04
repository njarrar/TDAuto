# ADR-0011: Hero System

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

The hero must be drivable by bots with no resolver and by a thumb with an aim preview. This ADR splits it into `HeroSim` (plain, headless: pin, straight-line walk, auto-attack, burst timers, result codes), `PinGeometry` (a plain class on 64-bit scalars), `AimModel` (a plain class for aim state and hysteresis) and `HeroInput` (a thin shell node), and fixes the signatures that the GDD needs and architecture.md does not yet show.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (sim) with an Input shell adapter |
| **Layer** | Feature |
| **Knowledge Risk** | HIGH for the version (VERSION.md). `HeroSim`, `PinGeometry` and `AimModel` call no engine API except `Vector2` and `Rect2`. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/architecture/architecture.md` (Engine Knowledge Gap Summary, API Boundaries, the `Vector2` precision note). The live 4.7.2 class reference was not fetched for this ADR. |
| **Post-Cutoff APIs Used** | None. The 4.7 override rule for typed returns applies to any base class. |
| **Verification Required** | NOT SOURCEABLE: input path order and the `canceled` flag on touch events, which decide how `drag_cancelled` reaches HeroInput (ADR-0006). A device run is needed for the thumb offset and the aim ring. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary; ADR-0005 Signal and Command Contracts; ADR-0006 Input Adapter and Resolver Integration; ADR-0007 Combat Data Model |
| **Enables** | Hero stories; ADR-0013 Content Test and Bot Harness (hero bots, share gate); ADR-0012 (kill preview drawing) |
| **Blocks** | Hero stories, in particular any HeroInput story |
| **Ordering Note** | Architecture.md assigns the kill preview (TR-hero-005) to ADR-0012. This ADR only provides `AimModel.preview_kills()`. |

## Context

### Problem Statement

`hero-system.md` requires: bots run headless; the resolver is shell-only; HeroInput changes the battle only through `pin` and `burst`; one test proves a resolver-driven script and a direct-command script give identical state. Its "Becomes an ADR" note asks where HeroInput sits in the wrapper and how input orders against the view's per-frame centre update. The GDD also needs method shapes that architecture.md does not show (see Deviations).

### Current State

No code. Fixed by the GDD:

- `pin(position)` returns `HALTED`, `BAD_POSITION` (not finite), `OUT_OF_BOUNDS` (outside `pin_rect`), `BUTTON_ZONE` (inside an active `pin_exclusion` shape), or `OK`, in that order. A refusal changes nothing.
- The hero walks in a straight line at `walk_speed` with `walk_ticks = max(1, ceil(distance / (walk_speed x dt) - 0.0001))`. The position is `from + (pin - from) x (1 - float(walk_left) / float(walk_ticks))`; at `walk_left` 0 it is assigned the pin.
- `burst(aim_point)` returns `HALTED`, `BUILD_PHASE`, `NOT_PINNED`, `NOT_READY`, `BAD_POSITION`, `OFF_FIELD`, `OUT_OF_REACH`, or `OK`, in that order. On `OK` it starts `max(1, to_ticks(telegraph_duration))` ticks of telegraph with the aim fixed.
- Cooldown runs from release, not during the telegraph. It counts on every tick that runs.
- Tick, in the hero slot, `halted()` checked after every read and signal: walk; auto-attack timer and `nearest_in(targets(), position, leash)`; cooldown; telegraph; release (`all_in_radius` of `aim_point`, one `deliver` per victim with source kind BURST).
- `clamp_pin` picks the valid candidate nearest the finger, in 64-bit floats, ties to the smaller y then the smaller x, and returns `hold` if no candidate is valid.
- Aim point is the finger plus (0, -100), clamped to the field, then to `reach - 0.01` from the hero. Cancel hysteresis: the aim stops cancelling above 64 from the button centre and resumes at 48 or less.
- Hit targets: hero DRAG radius 56, priority 200; burst button priority 100.

### Constraints

- Sim classes are `RefCounted`, headless (ADR-0001).
- `Vector2` is 32-bit; the exact compares and `clamp_pin` use scalar `float` and convert once at the end.
- Bots skip the finger offset; they call `burst(aim_point)` directly.
- Callers never retain `targets()` past their slot.

### Requirements

- TR-hero-001: HeroSim headless; HeroInput wrapper only; battle changed only through `pin` and `burst`.
- TR-hero-002: ordered result codes; straight-line walk in whole ticks; `PinGeometry.clamp` as a plain class.
- TR-hero-003: aim with cancel hysteresis (64 and 48), recomputed every frame while the hero walks.
- TR-hero-004: telegraph and cooldown in integer ticks; release in the hero slot; burst counters.

## Decision

### 1. Classes

| Class | Kind | Built by | Holds |
|---|---|---|---|
| `HeroSim` | `RefCounted` | `BattleBuilder` | Pin state, position, walk, attack and burst timers, counters, `pin`, `burst`, `tick` |
| `PinGeometry` | `RefCounted` | `BattleBuilder` | `pin_rect` and the active hand's shapes; `check`, `is_valid`, `clamp` |
| `AimModel` | `RefCounted` | `ShellBuilder` | Aim state, hysteresis, the shared aim-point function, `preview_kills`, `cooldown_digit` |
| `HeroInput` | `Node` (thin adapter) | `ShellBuilder` | Registration of the hero and burst-button targets; forwards resolver gestures to `AimModel`; calls `Battle.pin` and `Battle.burst` |

`PinGeometry` is built by the battle builder because `HeroSim.pin` uses it for `OUT_OF_BOUNDS` and `BUTTON_ZONE`. `HeroInput` and the bots use the same instance through `Battle` (read access), so the ghost and the command agree.

### 2. States

`HeroSim.PinState { UNPINNED, WALKING, PINNED }` and `HeroSim.BurstState { READY, TELEGRAPHING, COOLING }`, returned as `int` by `pin_state()` and `burst_state()` (matches architecture.md). A never-pinned hero fights nothing and the burst is refused with `NOT_PINNED`, so a never-pinned run equals towers-only.

### 3. PinGeometry

```gdscript
class_name PinGeometry extends RefCounted
enum Check { OK, OUT_OF_BOUNDS, BUTTON_ZONE }
func _init(pin_rect: Rect2, shapes: Array[PinShape]) -> void   # active hand and "both" only
func check(x: float, y: float) -> int                          # Check
func is_valid(x: float, y: float) -> bool                      # check(...) == OK
func clamp(x: float, y: float, hold_x: float, hold_y: float) -> Vector2
```

`clamp` follows the GDD rule: candidates from the rect, the shape circles, the parallel lines and their crossings, filtered by `check`, nearest to the finger, ties to the smaller y then x, scalars only, one `Vector2` built at the end. `PinShape` is a small `RefCounted` holding two end points as scalars, a radius and a hand. Whether the Stage record's shapes become `PinShape` objects in the loader or in the builder is ADR-0004's call. The hand comes from the left-hand data flag; the GDD sentence that names the flag's source was cut off in my read, so its location is left to ADR-0004.

### 4. HeroSim commands and tick

- `pin`: checks in the stated order, then sets the destination, `walk_ticks` and `walk_left`, and emits `hero_pinned(position)` after the state is set. No handler may issue a command.
- `burst`: checks in the stated order (state before geometry), reads `telegraph_duration`, holds `aim_point`, sets Telegraphing. There is no cancel after commit.
- `tick`: the seven steps in the GDD, in that order. Reads for an attack are completed before state changes. The release reads `radius`, `damage` and `cooldown`, sets Cooling, calls `report_attack` with source kind BURST and the hero's position as origin, then one `deliver` per victim, then updates counters.
- Counters (`repins`, `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `burst_victims`, and the others the GDD lists) live in `HeroSim` and are read by the human log (ADR-0014). Counter names are those of the GDD; the list there was cut off in my read, so the builder story copies it from the GDD.

### 5. AimModel and HeroInput

`AimModel` is driven by an explicit `update()` each frame (so tests need no frames) and by four gesture methods that `HeroInput` forwards:

```gdscript
class_name AimModel extends RefCounted
func begin(battle: BattleReadModel, finger: Vector2) -> void       # drag_started
func move(battle: BattleReadModel, finger: Vector2) -> void       # drag_moved
func release(battle: BattleReadModel, finger: Vector2) -> bool    # drag_ended: true when a burst should fire
func clear() -> void                                              # drag_cancelled, idle
func update(battle: BattleReadModel, finger: Vector2, finger_down: bool) -> void
func aim_state() -> int
func aim_point() -> Vector2
func aim_ring_radius() -> float      # 64 Cancelling, 48 Live, 0 Idle
func preview_kills() -> Array[EnemyState]
func cooldown_digit() -> int
```

- The aim point is one shared function: finger plus (0, -100), clamped to the field, then to `reach - 0.01` from the hero's current position. `HeroInput` and the preview both call it. The offset is a presentation constant that bots skip.
- `update()` recomputes the aim point every frame, because the hero may be walking. It is called from the shell frame hook after the frame's ticks, so it reads the final state of the frame.
- Hysteresis is measured on `begin`, each `move` and `release`. Every aim starts cancelling. On `release` it returns true unless the model is cancelling.
- `HeroInput` hit-tests the burst button itself (Input Rule 7), arms an aim only when the burst is Ready, the hero has been pinned and the phase is not Build, and treats a result other than `OK` or `HALTED` from a command as a development error.
- `preview_kills()` uses Combat's `hp_left` and a projection of enemy positions to landing (TR-hero-005). The drawing is ADR-0012's.

### 6. Position of HeroInput in the frame

Resolver gestures arrive from the input callback and go to `HeroInput`, which may call `Battle.pin` or `Battle.burst` at once (between ticks, per ADR-0005). The per-frame `AimModel.update()` runs after the frame's ticks. So the order in a frame is: input callback (commands), the clock's ticks, then `update()`, then the views. Whether the engine runs the input callback before the frame hook is NOT SOURCEABLE (ADR-0002, ADR-0006 verify it). If the order is reversed on a device, a command lands after the ticks of the same frame, and the effect is a one-frame delay, not a rule break.

### 7. Equivalence test

The same script (pins and bursts at given ticks) through the real `InputResolver` and `HeroInput`, and through direct `Battle.pin` and `Battle.burst`, must give identical snapshots. The script uses finger positions that map to the same aim points that the direct calls pass. The test lives in `tests/integration/hero/`.

### Architecture Diagram

```
 InputResolver (drag_*, tap) -> HeroInput -> AimModel (hysteresis, aim_point, preview)
                                   |  Battle.pin / Battle.burst (between ticks)
                                   v
 Battle -> HeroSim -> PinGeometry (check, clamp)      Bots -> Battle.pin / burst
              |  targets() Callable, Combat.deliver / report_attack
 shell frame hook: ticks, then AimModel.update(), then views
```

### Key Interfaces

`HeroSim` as in architecture.md; `PinGeometry` and `AimModel` as above (with the changes listed under Deviations).

### Implementation Guidelines

- `HeroSim`, `PinGeometry` and `AimModel` must not reference a Node or the resolver.
- `PinGeometry` must compute in scalar `float` and build one `Vector2` at the end.
- A command must check state before geometry, in the GDD order, and a refusal must change nothing and emit nothing.
- `walk_ticks` must use `ceil` with the 0.0001 tolerance, not `to_ticks`, because it is movement and not authored time.
- Authored durations (`telegraph_duration`, `cooldown`, `attack_interval`) must go through `SimTime.to_ticks`.
- Stats must be read at use time through the accessor; none may be cached.
- No handler of `hero_pinned` or `burst_started` may call a command.
- HeroInput must change the battle only through `Battle.pin` and `Battle.burst`.
- The hero's priority (200) and the burst button's (100) must be named constants shared with the Input record, not literals in two places.

## Alternatives Considered

### Alternative 1: Bots call `press`, `move` and `release` on a headless resolver

- **Description**: Build the resolver in the battle so bots drive gestures.
- **Pros**: Tests the input path in every bot run.
- **Cons**: Breaks Input Rule 11 (the resolver is built only by the ShellBuilder) and slows bot runs.
- **Estimated Effort**: Higher.
- **Rejection Reason**: The equivalence test covers the input path once instead.

### Alternative 2: Put the aim state inside `HeroInput`

- **Description**: Keep hysteresis in the Node.
- **Pros**: Fewer classes.
- **Cons**: Needs a scene to test hysteresis.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Violates ADR-0001. The GDD wants `update()` driven explicitly so tests need no frames.

### Alternative 3: Use `Vector2` math for `clamp_pin`

- **Description**: Use `distance_squared_to` and `Vector2` fields.
- **Pros**: Shorter code.
- **Cons**: 32-bit results; the tie rule (squared distances within 0.000001) and the 0.01 margin need 64-bit scalars.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Architecture.md bans it for exact compares.

### Alternative 4: A free-form pin (no clamp for people)

- **Description**: Refuse bad pins to the player.
- **Pros**: Simpler geometry.
- **Cons**: The GDD wants the ghost to always show where the pin lands and never refuse a person.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Contradicts hero-system.md Rule 14.

## Consequences

### Positive

- Bots, tests and the phone use the same `pin` and `burst`.
- Aim, geometry and timers are tested with no engine.
- The scalar rule gives the same clamp on every device.

### Negative

- Three more plain classes than a single hero node.
- `AimModel` grows four methods that architecture.md does not list.
- `clamp` has a four-argument form.

### Neutral

- A never-pinned run equals a towers-only run by rule.

## Risks

- Candidate generation in `clamp` is the most complex code in the system. Mitigation: port the check in `tools/balance-sim/hero_bots.py` (`check_clamp`, which tests valid samples along every boundary piece for each hand) as a gdUnit4 test (ADR-0013).
- A method over 40 lines or complexity over 10 in `clamp`. Mitigation: split into candidate builders per shape kind.
- The input and frame order differs on a device. Mitigation: described in section 6; the gesture log (ADR-0014) records timing.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| hero-system.md | TR-hero-001: HeroSim headless, HeroInput wrapper only | Section 1 and the guideline on commands |
| hero-system.md | TR-hero-002: ordered results, straight-line walk in ticks, `PinGeometry.clamp` plain | Sections 3 and 4 |
| hero-system.md | TR-hero-003: aim with 64 and 48 hysteresis, recomputed every frame | Section 5 |
| hero-system.md | TR-hero-004: telegraph and cooldown in ticks, release in the hero slot, counters | Section 4 |
| hero-system.md | "Becomes an ADR": where HeroInput sits; input against the per-frame update | Section 6 |
| input-gesture-resolver.md | Rule 11: bots call commands, not the resolver | Alternative 1; the equivalence test |

TR IDs are provisional until `/architecture-review` registers them. TR-hero-005 (preview) is ADR-0012's and TR-hero-006 (bots) is ADR-0013's.

## Performance Implications

- **CPU**: `clamp` runs once per frame while a finger is down: a few dozen candidates. `preview_kills` runs per frame while aiming over at most 48 targets. Not measured on a device.
- **Memory**: A handful of small objects. `preview_kills` returns an array each frame while aiming.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

New code. The Python `clamp_pin` in `hero_bots.py` is the reference for the first port (see ADR-0013).

**Rollback plan**: Move aim state into `HeroInput` if the plain-class split proves awkward, at the cost of headless aim tests.

## Validation Criteria

- The GDD examples for `clamp_pin` (right hand: finger (492, 888) gives (395.99, 888); (480, 850) gives (492, 767.99); left hand: (84, 850) gives (144.01, 850)).
- Table-driven order tests for `pin` and `burst` results.
- A walk of 240 units at 240 per second is 60 ticks; a pin at the hero's own position is Pinned at once.
- Hysteresis: a release at 55 that never passed 64 cancels.
- The equivalence test passes.
- The scripted bots reproduce the table in `hero-system.md` (ADR-0013).

## Related

- ADR-0001, ADR-0005, ADR-0006, ADR-0007 (dependencies); ADR-0003, ADR-0004, ADR-0012, ADR-0013, ADR-0014
- `design/gdd/hero-system.md` (Core Rules 1 to 17, Formulas, Edge Cases)
- Deviations from architecture.md: `PinGeometry.is_valid` stays a bool but a three-valued `check` is added; `clamp` takes `hold`; `AimModel` gains `begin`, `move`, `release` and `clear`.
