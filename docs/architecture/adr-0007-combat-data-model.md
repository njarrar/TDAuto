# ADR-0007: Combat Data Model

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. No other agent, and no skill on its own.

TD-ADR: not run per ADR; batch review after all ADRs are written.
Engine validation (godot-specialist): not run per ADR; batch review after all ADRs are written.

## Date

2026-11-04

## Last Verified

2026-11-04 (against the Godot 4.7.2 class reference, tag `4.7.2-stable`, and `docs/engine-reference/godot/`)

## Decision Makers

Authored in an autonomous run against `docs/architecture/architecture.md` (version 2). Open for the user and `technical-director` to accept or change.

## Summary

Combat needs a place for per-enemy Health and Status, an allocation rule for `DamageEvent`, contracts and a cost measure for the targeting helpers, and a record of what it costs to add projectiles later (QQ-06, QQ-07). This ADR puts `Health` and `Status` as fields on `EnemyState`, written only by Combat, allocates one fresh `DamageEvent` per hit, uses scalar float math in every targeting helper, and records the reversal cost of the ProjectileSpawner cut.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting) |
| **Layer** | Core |
| **Knowledge Risk** | HIGH (GDScript is HIGH in `VERSION.md`) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; Godot 4.7.2 class reference: `Vector2.xml`, `RefCounted.xml`, `Dictionary.xml`, `Array.xml`, `@GlobalScope.xml` (`is_finite`, `push_error`, `round`, `roundi`), `@GDScript.xml` (`assert`) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) The 400-check targeting worst case stays near 2 ms on the low-end phone (TR-combat-007, QQ-08). (2) Whether `Vector2.distance_squared_to` computes in 32-bit or 64-bit internally (not needed by this design; scalar math is used instead). (3) Float results across x86 and ARM (QQ-09) |

### NOT SOURCEABLE (blocks Acceptance)

- The internal precision of `Vector2.distance_squared_to`. The decision avoids it by comparing on scalar `float`; a headless desktop test confirms the scalar path gives the expected exact results.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary (plain objects, `HaltState`, shared types); ADR-0005 Signal and Command Contracts (`attack_fired`, `damage_applied`, emit rules, `DamageEvent` fields); ADR-0003 Fixed Tick, Time and Determinism (`SimTime.to_ticks`) |
| **Enables** | ADR-0009 (roster and position cache, which builds on this ADR), ADR-0010 (Tower), ADR-0011 (Hero), ADR-0013 (bots) |
| **Blocks** | Combat, Tower, Hero and Enemy & Wave stories that create or hit enemies |
| **Ordering Note** | ADR-0003 supplies `SimTime.to_ticks`. ADR-0009, which depends on this ADR, fills the per-tick `EnemyState.position` and assigns `spawn_id`; this ADR only reads them. ADR-0004 guarantees Combat needs no catalogue (callers pass values in). |

## Context

### Problem Statement

All damage goes through one path so the hero share is honest. The GDD says how each call behaves but leaves two structure questions to this ADR: how Health and Status attach to an enemy (QQ-06), and whether a future spawner can sit behind `deliver`. The architecture also asks this ADR to fix `DamageEvent` allocation, helper contracts and cost measure, and to record the reversal cost of cutting ProjectileSpawner (QQ-07, accepted for MVP on that condition).

### Current State

Nothing exists. `architecture.md` already shows `health: Health` and `status: Status` fields on `EnemyState` ("attached by Combat at spawn") and fixes the `DamageEvent` fields.

### Constraints

- Combat is Core. It depends only on Foundation: `HaltState`, `SimTime`, shared types. It reads no catalogue.
- `deliver` runs only inside a tick (`in_tick()`), applies at most the remaining HP, and never lets HP go negative.
- Distance compares must be exact and deterministic. `Vector2` holds 32-bit floats by default while a GDScript `float` is 64-bit (`Vector2.xml` description).
- Up to 48 enemies alive, up to about 400 target checks in the worst tick.
- Release builds must keep every guard: `assert` runs only in debug builds and the editor (`@GDScript.xml`), so guards are `if` statements.

### Requirements

- TR-combat-001 to 005 and 007 (see GDD table below).
- Dead enemies are never targeted or damaged; counters survive until the battle is destroyed.
- A slow is held in whole ticks, one slot, no stacking.

## Decision

### 1. Health and Status are fields on `EnemyState` (resolves QQ-06)

```gdscript
class_name Health extends RefCounted     # Combat writes; everyone else reads through Combat
var hp: float = 0.0
var removed: bool = false                # set by Combat.release; true after a leak or a reap

class_name Status extends RefCounted
var slow_strength: float = 0.0           # fraction of speed removed; 0.0 when the slot is empty
var slow_ticks: int = 0                  # whole ticks left; 0 means empty
```

`EnemyState.health` and `EnemyState.status` are set once, by `Combat.register`, called by EnemyWave in its add-enemy step (the same step the schedule and later splitters use, TR-wave-009):

```gdscript
func register(enemy: EnemyState, max_hp: float) -> void   # creates Health (hp = max_hp) and Status
func release(enemy: EnemyState) -> void                    # marks removed, empties the slot
```

EnemyWave reads `max_hp` through the accessor once and passes it in (the one allowed cache, GDD Rule 9). EnemyWave calls `release` in the leak step and in the reap step, before it drops the enemy. Nothing outside Combat writes `hp`, `slow_strength`, `slow_ticks` or `removed`; a review rule and a grep test enforce it.

`Health` and `Status` hold no reference back to the enemy, so `RefCounted` has no cycle here (`RefCounted.xml`: cycles are not freed).

`register` and `release` are additions to the Combat API in `architecture.md`. The architecture's Combat "Consumes" list names only `HaltState`; Combat also needs `SimTime` (Foundation) to convert slow seconds with `to_ticks`, since the GDD makes Combat do that conversion. Both are consistent with the layer rules.

### 2. `DamageEvent`: one fresh object per hit

Fields are those fixed in `architecture.md` (`target`, `amount`, `source_kind`, `source_id`). Each attacker creates a new `DamageEvent` for each victim and passes it to `deliver`. Combat never mutates it, and `damage_applied` carries the same object. Because it is fresh and unchanged, a listener may keep it. No pooling at MVP. The hits per tick are the slot count plus the hero plus splash victims, a small number; the cost of a `RefCounted` allocation is not sourced, so this is checked in the first phone profile (QQ-08) and pooling is the fallback. Pooling would break "a listener may keep the event", so it would need a superseding decision and a change to the ADR-0005 payload rule.

### 3. `deliver`, `apply_slow`, status

`deliver(event) -> float`, in order:

1. `HaltState.in_tick()` false: development error (`push_error`), return 0.0, change nothing.
2. Target null, or `target.health.removed`: development error, return 0.0.
3. `amount` NaN, infinite or negative (`is_finite`, `@GlobalScope.xml`; checked before `min` so NaN never reaches it): development error, return 0.0.
4. `target.health.hp <= 0.0` (dead, not yet reaped): return 0.0 silently, no signal, no counter.
5. `applied = minf(amount, hp)`; `hp -= applied`; add `applied` to `_dealt_by_id[source_id]` and `_dealt_by_kind[source_kind]`.
6. If `applied > 0.0`, emit `damage_applied(event, applied, target.position)`. `Vector2` is a value type, so the position is a copy.

`apply_slow(enemy, strength, seconds)`: ignored with a development error unless `0 < strength < 1` and finite, and `seconds` finite and above 0; ignored for a dead or removed enemy; `ticks = SimTime.to_ticks(seconds)` and a result of 0 is ignored. Then: no active slot or `strength` greater than current replaces both fields; equal strength keeps `maxi(current ticks, ticks)`; weaker is ignored. `speed_factor(enemy)` is `1.0 - slow_strength`, or `1.0` with an empty slot. `tick_status(roster)` decrements `slow_ticks` for each living enemy with an active slot and clears `slow_strength` at 0. It runs after EnemyWave advance, so a slow applied in tick N first affects the move in tick N+1 and lasts that many moves.

Counters: `_dealt_by_id: Dictionary[StringName, float]` and `_dealt_by_kind: Array[float]` sized to the `SourceKind` count. Typed dictionaries exist in 4.7.2 (`Dictionary.xml`, `is_typed`). Counters are read by `dealt_by_id` and `dealt_by_kind` until the battle is destroyed. The tower-versus-hero kill order is fixed by the tick order (ADR-0003), not here.

`removed` is checked before the dead check so a late call on a reaped enemy is an error, while a call on a corpse in the same tick is silent, as the GDD requires.

### 4. Targeting helpers (scalar math in every helper)

```gdscript
func first_in(list: Array[EnemyState], origin: Vector2, range_: float) -> EnemyState
func nearest_in(list: Array[EnemyState], origin: Vector2, range_: float) -> EnemyState
func all_in_radius(list: Array[EnemyState], center: Vector2, radius: float) -> Array[EnemyState]
```

Contract, shared by all three:

- Pure over the list the caller passes; never modify it, never keep a reference past the call.
- Skip dead and removed enemies. Scan once; no sort.
- In-range test: `dx*dx + dy*dy <= r*r`, inclusive, where `dx`, `dy` are `float` scalars taken from `.x` and `.y` of the two vectors. The stored coordinates are already 32-bit; widening them to a 64-bit `float` is exact, so the compare adds no further rounding.
- `first_in` picks the largest `EnemyState.distance` (64-bit `float`); `nearest_in` the smallest squared distance; ties go to the lowest `spawn_id` in both.
- `all_in_radius` returns a new typed array in the list's order. EnemyWave's `targets()` is in `spawn_id` order, so events come in ascending `spawn_id`.

**Answer to the architecture's open point.** The scalar rule applies to every helper, not only the pin clamp. Reason: one pattern with one test is simpler to keep exact, and `Vector2.xml` documents only that components are 32-bit, not how `distance_squared_to` accumulates internally; NOT SOURCEABLE: the internal precision of `Vector2.distance_squared_to`. The docs say that method is faster than `distance_to` and fits comparisons, but speed is not the question here. If the phone profile shows the scalar loop exceeds the 2 ms budget, the fallback is to switch to `distance_squared_to` for the range test only, after a determinism baseline shows no change, not before.

**Cost measure.** Cost is counted in target checks per tick, one check per enemy visited in a helper. A development-build counter on Combat (a `const` bool guard) records checks per tick. Two gates: bots assert the worst tick is at most about 400 checks (about 8 attackers by 48 enemies); the phone build records helper time per tick against the 2 ms proposal (TR-combat-007). The 2 ms figure is a budget from the GDD, unverified until a device run.

### 5. Reversal cost of the ProjectileSpawner cut (QQ-07 condition)

Today every hit is instant: an attacker picks a victim with a helper and calls `deliver` in the same tick. Adding projectiles later reverses that, because an attacker would pick a victim at fire time and the hit would land ticks later. The cost, item by item:

1. **New module and tick slot.** A ProjectileSpawner holds in-flight projectiles and resolves them in a new slot in `Battle.tick()`. That changes the fixed order in ADR-0003 and Combat Rule 11, and the Flow GDD tick list.
2. **Attackers change.** TowerSim and HeroSim stop calling `deliver` at fire time and hand a projectile to the spawner. Both modules, their tests and the TowerInput and HeroInput equivalence tests change.
3. **Stale targets.** A projectile holds an `EnemyState`. It is a `RefCounted`, so the reference cannot dangle, and `Health.removed` already makes `deliver` return 0 with a development error for a reaped target. The guard exists today; the design must turn that error into a normal path (retarget or fizzle).
4. **Splash and impact point.** Rule 6 of the GDD takes the target's position at fire time. With flight time the impact point is chosen at arrival or at fire; that is a new rule for the GDD.
5. **Counters and baselines.** Overkill, kill order and hero share all shift with flight time. Every bot baseline, the `hero_share_band` gate and the per-architecture baselines (ADR-0003) must be re-measured.
6. **Views.** `attack_fired` currently means "fired and hit". It would split into fired and landed, which touches the ADR-0005 table and CombatView.
7. **Scope owner.** The Mobile Platform and Performance system should rescope "heavy projectile load" to tracer and effect pooling, as QQ-07 requires. This ADR does not edit that GDD.

**Cheap seam kept now.** Each attacker (TowerSim, HeroSim, burst release) must resolve one hit in a single private method (`_resolve_hit`) that picks the victim, builds the `DamageEvent`, calls `report_attack` and `deliver`. A later spawner replaces the body of that one method. `deliver` stays the only entry that changes HP, so a spawner sits behind it without any change to Combat or the counters. Estimated reversal effort with the seam: one new module, edits in two Feature modules, the tick order, and a full baseline re-measure. Without the seam, the edits spread through attacker tick code.

### Architecture Diagram

```
 EnemyWave.add_enemy --Combat.register(enemy, max_hp)--> EnemyState.health / .status
 TowerSim / HeroSim: _resolve_hit(): first_in/nearest_in/all_in_radius --> DamageEvent --> Combat.deliver
 Combat.deliver --> Health.hp, counters --> damage_applied(event, applied, position)
 EnemyWave leak/reap --> Combat.release(enemy)
 Battle.tick: ... EnemyWave.advance --> Combat.tick_status(roster) --> TowerSim --> HeroSim --> EnemyWave.reap
```

### Key Interfaces

The Combat signatures in `architecture.md` are unchanged. Additions: `register(enemy: EnemyState, max_hp: float) -> void` and `release(enemy: EnemyState) -> void`. `Health` and `Status` are defined in section 1. Signals follow ADR-0005.

### Implementation Guidelines

- Only Combat may write `Health` and `Status` fields. Review and a grep test enforce it.
- Combat must not reference the catalogue. Callers must pass every value in.
- Combat must never use `assert` for a guard; every guard is an `if`.
- Every helper must compare on scalar `float` components and must never call `Vector2.distance_to`.
- Every attacker must keep its hit resolution in one `_resolve_hit` method.
- A `DamageEvent` must be created fresh for each victim and never mutated after `deliver`.
- EnemyWave must call `Combat.release` before dropping a leaked or reaped enemy.
- Public classes need doc comments (project coding standards).

## Alternatives Considered

### Alternative 1: Combat-side tables keyed by `spawn_id`
- **Description**: Combat holds `Dictionary[int, Health]` and `Dictionary[int, Status]`; `EnemyState` has no combat fields.
- **Pros**: `EnemyState` stays a plain geometry record; removal is deleting a key; "removed" is simply "no entry".
- **Cons**: A hash lookup on every helper visit and every `speed_factor` read (up to the 400-check path); a cleanup duty on every exit path or the tables grow; `EnemyState` readers (views, preview) still need `hp_left` through Combat.
- **Estimated Effort**: Similar.
- **Rejection Reason**: The target-check path is the hot path. A field read is cheaper and needs no cleanup on exit, and the architecture's shared type already carries the fields.

### Alternative 2: Flatten `hp`, `slow_strength` and `slow_ticks` directly onto `EnemyState`
- **Description**: No `Health` or `Status` classes.
- **Pros**: One object per enemy.
- **Cons**: EnemyWave and Combat both own the one class; future statuses grow `EnemyState`; the GDD names Health and Status as pieces.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Weakens the ownership line. The extra two small objects per enemy are bounded by the 48-enemy cap, though the spawn count per wave can be larger over time.

### Alternative 3: Pool and reuse `DamageEvent`
- **Description**: A fixed pool of events refilled per hit.
- **Pros**: No per-hit allocation.
- **Cons**: A listener that keeps an event sees it change; allocation cost is not sourced, so the gain is unproven.
- **Estimated Effort**: Medium.
- **Rejection Reason**: Premature without a profile.

### Alternative 4: Build ProjectileSpawner now behind `deliver`
- **Description**: Keep the fourth piece the systems index asked for.
- **Pros**: No reversal cost later.
- **Cons**: Every hit is instant at MVP; this adds a module, a tick slot and tests for nothing visible. Already cut and accepted (QQ-07).
- **Estimated Effort**: Highest.
- **Rejection Reason**: Cut for MVP; the cost of reversal is recorded in section 5.

## Consequences

### Positive
- Hot-path reads are field reads.
- One damage path and one set of counters keep hero share honest.
- Reversal cost is written down, and the `_resolve_hit` seam keeps it small.

### Negative
- `EnemyState` and Combat are coupled by two fields; moving to Alternative 1 later touches `EnemyState`, Combat and the EnemyWave spawn site.
- EnemyWave must remember to call `release` on every exit path.
- A `DamageEvent` allocation per hit.

### Neutral
- `architecture.md` needs these edits in its next revision (not made here): Combat gains `register` and `release`, and Combat "Consumes" gains `SimTime`.

## Risks

- **Missed `release` leaves a corpse targetable.** Mitigation: helpers skip `hp <= 0` as well as `removed`; a test removes enemies by each path and checks `is_dead` is true afterward.
- **Scalar loop slower than budget.** Mitigation: profile on the phone; documented fallback in section 4.
- **Float results differ between x86 and ARM.** Mitigation: per-architecture baselines (ADR-0003, QQ-09).
- **Fractional damage leaves a float remainder above 0.** Behaviour is defined by the GDD: the enemy stays alive until the next hit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-001: one damage path, `deliver(event)`, only in a tick, returns applied | Section 3 order of checks |
| combat-damage.md | TR-combat-002: Health seeded once from `max_hp`; death immediate; counters by id and kind | `register`, `Health`, counters |
| combat-damage.md | TR-combat-003: one slow slot in whole ticks, no stacking | `Status`, `apply_slow`, `tick_status` |
| combat-damage.md | TR-combat-004: pure helpers, exact compares, ties to lowest `spawn_id`, skip the dead | Section 4 |
| combat-damage.md | TR-combat-005: Combat reads no data | Constraints; `register` takes `max_hp` as a value |
| combat-damage.md | TR-combat-007: about 400 checks within about 2 ms | Cost measure and two gates |
| combat-damage.md | "Becomes an ADR": how Health and Status attach; whether a spawner sits behind `deliver` | Sections 1 and 5 |

## Performance Implications
- **CPU**: About 400 target checks in the worst tick; scalar GDScript math. No time is claimed; the 2 ms budget is the GDD's and is unverified.
- **Memory**: Per enemy one `Health` and one `Status`; at most 48 alive. One `DamageEvent` per hit, freed by reference counting.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
Nothing exists to migrate. Order: shared types (`Health`, `Status`), Combat with fixtures and no scene, then helpers, then attackers.

**Rollback plan**: To move to Alternative 1, make `Health` and `Status` private to Combat and key them by `spawn_id`. Only Combat, `EnemyState` and the EnemyWave spawn site change, because nobody else touches the fields.

## Validation Criteria
- GDD acceptance criteria for Combat pass: overkill applies at most the HP left; a dead enemy takes no hit and emits nothing; slow replace, equal and weaker cases; ties go to the lowest `spawn_id`; boundary `dx*dx + dy*dy == r*r` is a hit.
- A bot run reports at most about 400 checks in the worst tick.
- The first phone profile keeps helper time within the 2 ms proposal, or this ADR is revised.
- A grep test finds no write to a `Health` or `Status` field outside Combat.

## Related
- `docs/architecture/architecture.md` (Shared types, Combat, QQ-06, QQ-07, QQ-08, QQ-09)
- `design/gdd/combat-damage.md`
- ADR-0001 Simulation and Shell Boundary; ADR-0003 Fixed Tick, Time and Determinism; ADR-0004 Catalogue Format, Loader, Validator and Stat Accessor; ADR-0005 Signal and Command Contracts; ADR-0009 Enemy Roster, Position Cache and View Pooling; ADR-0010 Tower System; ADR-0011 Hero System
- GDD sync: checked 1 referenced GDD(s), no naming inconsistencies. The GDD says Enemy & Wave "creates Health and Status at spawn"; this ADR has EnemyWave call `Combat.register`, which creates them, matching the architecture's "attached by Combat at spawn".
