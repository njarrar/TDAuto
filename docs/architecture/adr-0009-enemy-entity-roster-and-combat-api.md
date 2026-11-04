# ADR-0009: Enemy Entity, Roster and Combat API

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. No other agent and no skill may do it alone. Stories that cite this ADR stay blocked while it is `Proposed`.

TD-ADR: batch review 2026-11-04, APPROVE; fixes applied.

Engine validation (godot-specialist): written by the Godot specialist against the 4.7.2 class reference and `docs/engine-reference/godot/`; no separate validation pass.

## Date

2026-11-04

## Last Verified

2026-11-04 (against `docs/engine-reference/godot/` and the Godot class reference at tag `4.7.2-stable`)

## Decision Makers

Godot specialist (author). Pending: technical-director batch review and user acceptance.

## Summary

Combat, Enemy & Wave, Tower and Hero all read and hit the same enemies, and the GDDs leave the enemy's object kind, how Health and Status attach, the roster's lists and the targeting cost to an ADR. This ADR makes `Targetable` (Core, `RefCounted`) the base that Combat's API takes, has `Enemy` (Feature) extend it, attaches `Health` and `Status` through one `Combat.attach` call in Enemy & Wave's add-enemy step, keeps the roster as reused `Array[Targetable]` buffers in `spawn_id` order, looks position up from a cumulative-length table, fixes `deliver`'s guards and the helpers' scalar compare, and sets a counted per-tick targeting budget.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2.stable, installed and pinned) |
| **Domain** | Core (scripting, gameplay data) |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM (architecture.md, Required ADRs). The design uses only `RefCounted`, typed `Array`, typed `Dictionary`, `Vector2`, `float` and `push_error`, none changed in 4.5 to 4.7 per `breaking-changes.md`. The GDScript row in architecture.md is HIGH for its 4.7 pitfalls, which the control manifest turns into rules (QQ-15). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; Godot 4.7.2 class reference: `Vector2.xml` (32-bit components in a stock build, 64-bit GDScript `float`), `RefCounted.xml` (reference cycles are not freed), `Array.xml` (`remove_at` shifts later elements; `clear`; typed arrays), `Dictionary.xml` (typed dictionaries), `@GlobalScope.xml` (`is_finite`, `push_error`, `minf`), `@GDScript.xml` (`assert` runs only in debug builds and the editor) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Per-tick targeting time on the low-end phone at the catch-up clamp; float results on ARM against x86. See NOT SOURCEABLE |

### NOT SOURCEABLE (blocks Acceptance)

- **Per-tick targeting time on the low-end phone** (about 400 range checks, under 2 ms measured on the whole `Battle.tick`, TR-combat-013). No source gives GDScript loop cost on a device. Settled by: the first phone build profile, a bot-driven worst-case tick (48 alive, every slot built, hero attacking, a burst release) run at `MAX_TICKS_PER_FRAME`, timing `Battle.tick` with the check counter on (QQ-11).
- **Allocation cost of one `RefCounted` per hit** (`DamageEvent`, Decision 5). Not in the class reference. Settled by: the same phone profile, comparing the worst tick with and without event creation.
- **Cost of the `as Enemy` cast per enemy per tick** (Decision 3). Not in the class reference. Settled by: the same phone profile.
- **Internal precision of `Vector2.distance_squared_to`.** `Vector2.xml` documents 32-bit components, not how that method accumulates. This design avoids the method and compares on 64-bit scalars. Settled by: the headless boundary tests on desktop (exact `dx*dx + dy*dy == r*r` is a hit) plus the per-architecture bot baselines on an ARM device that ADR-0004 owns (QQ-05).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 App Lifecycle, Composition Root and Fatal Path (no autoloads, `RefCounted` sims, `halted()`, push_error policy, retry by dropping references); ADR-0005 Stat Accessor and Read-Context Contract (`ReadContext` per enemy, `max_hp` read). Text also relies on: ADR-0002 (`StageRecord.path_points`, the validator that rejects repeated points), ADR-0004 (tick order, `to_ticks`, float policy, `MAX_TICKS_PER_FRAME`), ADR-0006 (commit then emit, signal payloads), ADR-0007 (recording fakes, layer lint) |
| **Enables** | ADR-0010 (Tower and Hero call this API); ADR-0011 (views read `roster()`, the path and the Combat view signals) |
| **Blocks** | Every Combat and Enemy & Wave story; Tower and Hero stories that target or hit enemies |
| **Ordering Note** | The Combat GDD names this ADR a prerequisite of its first story. ADR-0004 owns the frame budget split and the clamp; this ADR owns only the targeting share of a tick and how it is counted |

## Context

### Problem Statement

Five modules touch enemies in one tick: Enemy & Wave moves and reaps them, Combat changes their HP and slow, Tower and Hero pick victims, and views draw them. Combat is Core and cannot name the Feature-layer enemy class. The Combat GDD leaves to this ADR the enemy's object kind, how Health and Status attach and what call registers them (with its `max_hp` guard), ownership and reference cycles, the typing of the helpers' list, where `SourceKind` and `DamageEvent` live, Combat's object kind and owner, and whether a future spawner sits behind `deliver`. The Enemy & Wave GDD leaves the same attachment question and the path's lookup form.

### Current State

No code exists. architecture.md v3 sketches the types (B0), Combat's API (B6) and Enemy & Wave's API (B7) and marks them ADR-pending.

### Constraints

- Sims extend `RefCounted`, never `Node`. A freed `Node` cannot honour `removed`, and a `Node`'s `position` would collide with the cached one (architecture.md, API Boundaries).
- Combat (Core) must not reference Enemy & Wave (Feature). Typed arrays are invariant, so an `Array[Enemy]` cannot pass where `Array[Targetable]` is expected (architecture.md, Dependency rule 5).
- Combat reads no catalogue. Its one outside need is `to_ticks`, injected (Combat Rule 9).
- Guards must hold in release builds. `assert` runs only in debug builds and the editor (`@GDScript.xml`), so every guard is an `if` with `push_error`.
- `Vector2` stores 32-bit floats in a stock build; a GDScript `float` is 64-bit (`Vector2.xml`). Exact compares use scalars.
- Single thread, one fixed tick order (ADR-0004). At most 48 enemies alive (`peak_alive_ub`).
- A solo part-time developer: the smallest structure that meets the GDDs.

### Requirements

- One damage path, guards in fixed order, real damage only (TR-combat-001, 003, 004).
- Enemy exposes `spawn_id`, cached `distance` and `position`, and `removed`, and stays valid after removal (TR-combat-002, TR-enemy-009).
- Counters, slow, no catalogue, pure helpers (TR-combat-005 to 008).
- One roster owner, typed read-only lists, no back-references (TR-enemy-008).
- Path lookup from a cumulative table; in-field test; one add-enemy step (TR-enemy-010, 011, 013).
- Tower and Hero use only this API (TR-tower-007, TR-hero-007).
- Targeting within budget at the clamp (TR-combat-013).

## Decision

### 1. `Targetable` is the Core base; `Enemy` extends it

```gdscript
## src/core/combat/targetable.gd
## Anything Combat can hit. Combat's API takes and returns this type only.
class_name Targetable extends RefCounted
var spawn_id: int = -1          # battle-wide, ascending, never reused; set by the owner before attach
var position: Vector2           # cached once per tick by the owner's move step
var distance: float = 0.0       # cached once per tick by the owner's move step (64-bit)
var removed: bool = false       # set by the owner when it leaves the roster (leak or reap)
var health: Health              # set once by Combat.attach; written only by Combat
var status: Status              # set once by Combat.attach; written only by Combat

## src/feature/enemy_wave/enemy.gd
class_name Enemy extends Targetable
var def_id: StringName
var ctx: ReadContext            # one per enemy, made once in the add-enemy step (ADR-0005)
var in_field: bool = false      # written by the move step with position (Decision 4)
```

`distance` sits on `Targetable`, not on `Enemy`. Combat Rule 10 makes `first_in` rank by `distance`, and Combat can only read fields of `Targetable` with parse-time checks. B0 in architecture.md lists `distance` on `Enemy`; this ADR moves it up one class (see Deviations).

`Health` and `Status` are plain `RefCounted` holders in `src/core/combat/`:

```gdscript
class_name Health extends RefCounted
var hp: float = 0.0

class_name Status extends RefCounted
var slow_strength: float = 0.0   # fraction removed; 0.0 when the slot is empty
var slow_ticks: int = 0          # whole ticks left; 0 means empty
```

Neither holds a reference back to its target, and `Enemy` holds none to `EnemyWave`, `Combat` or `Battle`. `RefCounted.xml` says cycles are not freed, so with no back-references, dropping the `Battle` frees every enemy on retry (TR-enemy-008, ADR-0001's weakref proof).

### 2. Attachment: one `Combat.attach` call in the add-enemy step

```gdscript
const ERR_BAD_HP := "Combat.attach: max_hp not finite or not above 0"
## Creates Health (hp = max_hp) and Status (empty) on target. Returns false, with
## ERR_BAD_HP, and attaches nothing when max_hp is not finite or not above 0.
func attach(target: Targetable, max_hp: float) -> bool
```

`attach` is an addition to B6. It is the "call that registers them at spawn, with its `max_hp` guard" the Combat GDD asks for. No `release` call exists: `removed` lives on `Targetable` and the roster owner sets it, as Enemy & Wave Rule 14 says. Only Combat writes `health` and `status` and their fields; a grep test in ADR-0007's lint enforces it.

### 3. Roster ownership and typed lists

`EnemyWave` alone creates, holds and drops enemies. It keeps three reused buffers, all built typed from the start:

```gdscript
var _roster: Array[Targetable] = []    # spawn_id order, corpses included until the reap
var _targets: Array[Targetable] = []   # roster entries with in_field true, spawn_id order
var _reap: Array[Targetable] = []      # scratch, reap slot only
```

- `roster()` and `targets()` return the buffers themselves. Both are read-only by rule and valid only for the caller's slot (B7). A copy per call would allocate on the hot path.
- Appends keep `spawn_id` order, since ids rise. Removal uses `remove_at(index)`, which keeps order; `Array.xml` notes it shifts later elements, a bounded cost at 48 entries.
- `_targets` is cleared and refilled (`clear()` then appends) at the end of the advance slot and after each reap removal. One pass over at most 48 entries.
- Inside `EnemyWave`, Feature fields are read through `var e := _roster[i] as Enemy`. Combat never casts.

### 4. Path lookup and the field test

A `PathTable` (`src/feature/enemy_wave/path_table.gd`, `RefCounted`) is built once in the `EnemyWave` constructor from `StageRecord.path_points`:

```gdscript
class_name PathTable extends RefCounted
func _init(points: PackedVector2Array) -> void
func length() -> float                    # cum[last]; the leak test uses it
func lookup_x(d: float) -> float          # 64-bit scalar result
func lookup_y(d: float) -> float
func segment_at(d: float) -> int          # binary search over cum
```

- `cum`, `px` and `py` are `Array[float]`, built from point components widened to 64-bit. `lookup` finds `k` with `cum[k] <= d < cum[k+1]` by binary search and applies the GDD formula; `d >= length()` returns the last point. A step that crosses several segments lands on the path by construction (Enemy & Wave edge case at speed 2,000). The validator (ADR-0002) rejects repeated points, so `len[k]` is never 0.
- The move step is the only writer of `distance`, `position` and `in_field`, all for the same tick. It computes `x` and `y` as 64-bit scalars, sets `in_field = x >= 0.0 and x <= FIELD_W and y >= 0.0 and y <= FIELD_H` (edges included, Rule 4), and only then narrows to `position = Vector2(x, y)`.
- `FIELD_W = 540.0` and `FIELD_H = 960.0` are injected at build from the one field-size constant ADR-0003 owns (TR-enemy-011), not literals in Enemy & Wave.
- Views draw from the same `path_points` (ADR-0011). Nothing recomputes position from `distance`.

### 5. Combat: object kind, guards, counters, slow

`Combat extends RefCounted`, built by the Builder, held by `Battle.combat` (B0), with `to_ticks` injected as a method Callable (ADR-0001). `SourceKind` is declared on `Combat`. `DamageEvent` lives in `src/core/combat/damage_event.gd` with B0's four fields.

**`DamageEvent` allocation.** Each attacker creates one fresh event per victim. Combat never mutates it, and `damage_applied` carries the same object. No pooling at MVP; the cost is NOT SOURCEABLE and the phone profile decides. Pooling would break "a listener may keep the event" and needs a superseding ADR.

**`deliver(event) -> float`**, in this order. Only the first failure reports.

"Only inside a tick" is held by structure, not by a guard. TR-combat-007 allows Combat one outside need, `to_ticks`, so it gets no tick flag. Every `deliver` caller is a `_resolve_hit` reached only from a `tick` method (Decision 9), and a recording-fake test (ADR-0007) fails if `deliver` is called while no tick is running.

1. `event.target == null` or `event.target.removed`: `push_error(ERR_REMOVED)`, return 0.0.
2. `not is_finite(event.amount) or event.amount < 0.0`: `push_error(ERR_BAD_AMOUNT)`, return 0.0. Checked before `minf`, so NaN never reaches it.
3. `health.hp <= 0.0` (dead, not reaped): return 0.0 silently.
4. `applied = minf(event.amount, health.hp)`; `health.hp -= applied`; add `applied` to the counters.
5. If `applied > 0.0`, emit `damage_applied(event, applied, target.position, health.hp <= 0.0, target.spawn_id)` after all state is committed (ADR-0006). `Vector2` is a value type, so `position` is a copy.

**Counters.** `_dealt_by_id: Dictionary[StringName, float]` and `_dealt_by_kind: Array[float]` sized to `SourceKind`. Read by `dealt_by_id` (0.0 for an unknown id), `dealt_by_kind`, `dealt_total` and `hero_share` until the battle is destroyed.

**Slow.** `apply_slow(target, strength, seconds)` checks, in Rule 3's order: removed (`ERR_REMOVED`); `strength` strictly between 0 and 1 and `seconds` finite and above 0 (`ERR_BAD_SLOW`); dead (silent). Then `ticks = to_ticks(seconds)`; a result of 0 changes nothing. Stronger replaces both fields, equal keeps `maxi(current, ticks)`, weaker is ignored. `speed_factor(target)` is `1.0 - slow_strength`, or `1.0` when empty. `tick_status(roster)` takes 1 from every active slot and empties any at 0 or below, and emits nothing.

### 6. Targeting helpers

Signatures are B6's, with `list: Array[Targetable]`:

- Pure. Never modify `list`; never keep it past the call.
- Skip `is_dead(t)` (`health.hp <= 0.0`). Scan once; no sort.
- In range: `dx * dx + dy * dy <= r * r`, inclusive, where `dx`, `dy` are `float` scalars from `.x` and `.y`. Widening a 32-bit component to a 64-bit `float` is exact, so the compare adds no rounding. Never call `Vector2.distance_to` or `distance_squared_to` in a helper.
- Range is applied before ranking. `first_in` takes the greatest `distance`; `nearest_in` the smallest squared distance; ties go to the lowest `spawn_id`.
- `all_in_radius` returns a new `Array[Targetable]` in input order. Callers pass `targets()`, so events run in ascending `spawn_id`.

### 7. The add-enemy step

```gdscript
## The one way an enemy joins. Used by the schedule now and by splitters later.
## Returns null and spends no spawn_id when halted or when attach fails.
func _add_enemy(def_id: StringName, start_distance: float) -> Enemy
```

Order: make the `ReadContext`; read `max_hp` through the accessor; check `halted()`; build the `Enemy` with `spawn_id = _next_id`; call `combat.attach(enemy, max_hp)`, and on `false` drop the object and return null; only then increment `_next_id`, set `distance`, `position` and `in_field` from `start_distance`, and append to `_roster`. The schedule calls it in the advance slot. A splitter child (Vertical Slice) calls it in the reap slot from a kill listener, before the clear check, so it joins atomically (Rule 15, acceptance 28).

**Reap.** Collect dead roster entries into `_reap` in roster order. For each: read `bounty`, set `removed = true`, `remove_at` its index, emit `enemy_killed(bounty)`, check `halted()`. Then rebuild `_targets` and run the clear check.

### 8. Per-tick targeting budget (TR-combat-013)

Cost is counted in **range checks**: one per entry visited by a helper. A development-build counter on Combat, behind a `const` flag, records checks per tick.

- **Gate 1, headless (bots):** the worst tick of every content stage is at most 400 checks. Over 400 is a content or design flag, not a code failure.
- **Gate 2, device:** whole `Battle.tick` time under 2 ms per tick on the low-end phone at `MAX_TICKS_PER_FRAME` (NOT SOURCEABLE above). The sim slice in Data Flow 10 is 4.0 ms per frame; ADR-0004 sets the clamp from this measured cost.
- **Fallback if Gate 2 fails:** first, have each attacker reject out-of-range enemies with one `abs(dx) > r` test before the multiply; second, switch the range test to `distance_squared_to` only after a determinism baseline shows identical results.

### 9. ProjectileSpawner: cut, with a seam (QQ-08)

Every hit is instant at MVP. Adding projectiles later costs:

1. A new module and a new slot in `Battle.tick`, changing ADR-0004's order, Combat Rule 11 and the Flow tick list.
2. Tower and Hero stop calling `deliver` at fire time and hand off a projectile; their tests and the input equivalence tests change.
3. Stale targets. A projectile would hold a `Targetable`. It cannot dangle (it is `RefCounted`), and `removed` already makes `deliver` return 0 with `ERR_REMOVED`. That error must become a normal path (retarget or fizzle).
4. Splash impact point moves from fire time to arrival or stays at fire time: a new GDD rule.
5. Overkill, kill order and hero share shift with flight time. Every bot baseline, the hero-share gate and the per-architecture baselines are re-measured.
6. `attack_fired` splits into fired and landed, changing ADR-0006's table and the Combat view.

**Seam kept now.** Each attacker (TowerSim, HeroSim, burst release) resolves one hit in one private method, `_resolve_hit`, that picks the victim, calls `report_attack`, builds the `DamageEvent` and calls `deliver`. A spawner later replaces that body only. `deliver` stays the one HP entry, so a spawner sits behind it with no change to Combat or the counters.

### Architecture Diagram

```
 Builder ── to_ticks, in_tick ──► Combat (RefCounted, held by Battle)
                                     ▲ attach / deliver / apply_slow / helpers
 StageRecord.path_points ─► PathTable (cum[], once)
                                     │
 EnemyWave._add_enemy ─► Enemy (extends Targetable) ─► _roster: Array[Targetable]
   advance: d, x, y (64-bit) → in_field → position (Vector2) → _targets rebuilt
   reap:    _reap scratch → removed = true → remove_at → enemy_killed → _targets rebuilt
                                     │ roster(), targets() (read-only, slot-scoped)
 TowerSim / HeroSim._resolve_hit: first_in / nearest_in / all_in_radius(targets())
                                  → report_attack → DamageEvent → Combat.deliver
 Battle.tick: Flow → EnemyWave.advance → Combat.tick_status(roster) → TowerSim → HeroSim → EnemyWave.reap
```

### Key Interfaces

B6 and B7 of architecture.md stand, with these changes:

- `Combat.attach(target: Targetable, max_hp: float) -> bool` (new).
- Error constants on Combat: `ERR_REMOVED`, `ERR_BAD_AMOUNT`, `ERR_BAD_SLOW`, `ERR_BAD_HP`.
- `Targetable.distance` (moved up from `Enemy`); `Enemy.in_field` (new); `Health`, `Status`, `PathTable` as above.
- `tick_status(roster: Array[Targetable])` and the three helpers take `Array[Targetable]`, as B6 proposed.

### Implementation Guidelines

- Every sim class here must extend `RefCounted`; none may extend `Node`.
- Combat must never reference `Enemy`, `EnemyWave` or the catalogue; callers pass every value in.
- Only Combat may write `health`, `status`, `hp`, `slow_strength` or `slow_ticks`.
- Only EnemyWave's move step may write `distance`, `position` and `in_field`; only EnemyWave may write `removed` and `spawn_id`.
- Enemy lists must be declared `Array[Targetable]` from creation; never build an `Array[Enemy]` to pass to Combat.
- `roster()` and `targets()` results must never be stored past the caller's slot or modified.
- Every guard must be an `if` with `push_error` of a named constant; never `assert`.
- Helpers must compare on 64-bit scalars and must never call `Vector2.distance_to` or `distance_squared_to`.
- `_add_enemy` must read `max_hp`, check `halted()` and pass `attach` before it spends a `spawn_id`.
- A `DamageEvent` must be created fresh per victim and never mutated after `deliver`.
- Each attacker must keep hit resolution in one `_resolve_hit` method.
- No enemy, `Health` or `Status` may hold a reference to a module or to the battle.
- Public classes and methods need doc comments.

## Alternatives Considered

### Alternative 1: A plain record with no base class (Combat takes `Object` or `Variant`)

- **Description**: Enemy & Wave owns a plain `EnemyState`; Combat reads its fields by name.
- **Pros**: No Core class; Enemy & Wave owns one type.
- **Cons**: Combat would read fields on `Object` by dynamic lookup, with no parse-time check, or name a Feature class, an upward dependency.
- **Rejection Reason**: architecture.md Dependency rule 5 and its "Decisions that need no separate ADR" list make `Targetable` a Core base class. This ADR ratifies that.

### Alternative 2: Combat-side tables keyed by `spawn_id`

- **Description**: Combat holds `Dictionary[int, Health]` and `Dictionary[int, Status]`; the enemy has no combat fields.
- **Pros**: The enemy stays pure geometry.
- **Cons**: A hash lookup on every helper visit and every `speed_factor` read on the 400-check path; a cleanup duty on every exit path.
- **Rejection Reason**: The check path is the hot path. A field read is cheaper and needs no cleanup.

### Alternative 3: Flatten `hp` and slow fields onto `Targetable`

- **Description**: No `Health` or `Status` classes.
- **Pros**: One object per enemy.
- **Cons**: Blurs who writes what; the GDD names Health and Status as pieces; future statuses grow the base.
- **Rejection Reason**: Weakens the one-writer rule for two small objects per enemy, bounded by 48 alive.

### Alternative 4: Walk position forward, or compute it in each reader

- **Description**: Keep a current segment and step, or store only `distance` and let readers look it up.
- **Pros**: No search, or fewer fields.
- **Cons**: Walking drifts from `cum` and needs a loop for multi-segment steps; lazy lookup repeats work and lets a later slot see a different position.
- **Rejection Reason**: Rule 9 computes position once in the move step; a lookup from `d` is safe by construction.

### Alternative 5: Build ProjectileSpawner now

- **Description**: Keep the fourth piece behind `deliver`.
- **Pros**: No reversal later.
- **Cons**: A module, a tick slot and tests for nothing visible, since every MVP hit is instant.
- **Rejection Reason**: Cut for MVP; the cost is recorded in Decision 9 and the seam keeps it small.

## Consequences

### Positive

- Combat's API is type-checked at parse time with no upward dependency.
- One writer per field; every reader in a tick sees the same position.
- Hot-path reads are field reads; the roster stays sorted with no sort.
- Retry frees everything by dropping the `Battle`.
- A future spawner or splitter needs no change to Combat or the clear check.

### Negative

- `Enemy` reads in `EnemyWave` go through an `as Enemy` cast.
- `targets()` returns a reused buffer; a caller that keeps it sees it change.
- One `DamageEvent` allocation per hit.
- architecture.md B0, B6 and B7 need edits in their next revision (not made here).

### Neutral

- The 400-check gate is a content signal, not a CI failure.

## Risks

- **A reader keeps `targets()` past its slot.** Mitigation: snapshot test before and after each reader (ADR-0007), and review.
- **A write to `health` or `status` outside Combat.** Mitigation: grep test in the layer lint.
- **Targeting over 2 ms on the phone.** Mitigation: Decision 8 fallbacks; ADR-0004 lowers the clamp.
- **Floats differ on ARM.** Mitigation: per-architecture baselines (ADR-0004).
- **Signal parameter types are not checked at `emit()`** (architecture.md, Data Flow 3). Mitigation: recording fakes assert `damage_applied` payloads (ADR-0007).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-001: DamageEvent, one Health and one Status per enemy; no ProjectileSpawner | Decisions 1, 2, 5; cut and seam in Decision 9 |
| combat-damage.md | TR-combat-002: enemy exposes `spawn_id`, cached `distance` and `position`, `removed`; valid after removal; not a freed Node | `Targetable extends RefCounted` with those fields (Decision 1) |
| combat-damage.md | TR-combat-003: every HP change through `deliver` in a tick; `min(amount, hp)`; guards in fixed order with named codes | Decision 5 guard order and constants |
| combat-damage.md | TR-combat-004: death at HP 0; dead not targetable; reap removes and emits `enemy_killed` once | `is_dead`, helpers skip the dead; reap in Decision 7 |
| combat-damage.md | TR-combat-005: `dealt_by_id`, `dealt_by_kind`, `dealt_total`, `hero_share` until destroyed | Counters in Decision 5 |
| combat-damage.md | TR-combat-006: whole-tick slow, replace/equal/ignore; `move_speed` times `speed_factor` | `Status`, `apply_slow`, `tick_status` (Decision 5) |
| combat-damage.md | TR-combat-007: no catalogue; only `to_ticks` injected | Combat takes values and `max_hp` in; `to_ticks` injected (Decisions 2, 5) |
| combat-damage.md | TR-combat-008: pure helpers, inclusive squared distance, lowest `spawn_id` ties, no mutation | Decision 6 |
| combat-damage.md | TR-combat-013: about 400 checks under 2 ms at the clamp | Check counter, two gates, fallbacks (Decision 8) |
| enemy-wave.md | TR-enemy-008: roster sole owner; read-only `roster()` and `targets()` in `spawn_id` order; no back-references | Decision 3; no back-references (Decision 1) |
| enemy-wave.md | TR-enemy-009: how Health and Status attach | `Combat.attach` in the add-enemy step (Decisions 2, 7) |
| enemy-wave.md | TR-enemy-010: position from distance via cached cumulative lengths, multi-segment, clamped | `PathTable` (Decision 4) |
| enemy-wave.md | TR-enemy-011: targetable only with centre inside 540x960, a defined or injected value | `in_field` from 64-bit scalars against injected `FIELD_W`, `FIELD_H` (Decision 4) |
| enemy-wave.md | TR-enemy-013: one add-enemy step for schedule and splitters, atomic before the clear check | `_add_enemy` (Decision 7) |
| tower-system.md | TR-tower-007: targeting and damage only through Combat; splash victims only from `targets()` | Implementation Guidelines; `_resolve_hit` over `targets()` |
| hero-system.md | TR-hero-007: `deliver` with HERO and BURST, `report_attack` first, `nearest_in`, `all_in_radius`, `is_dead`, `hp_left` over `targets()` | Same API; `_resolve_hit` order (Decision 9) |

GDD sync: checked 4 referenced GDDs. No renames. Additions the GDDs do not name yet: `Combat.attach`, `ERR_BAD_HP`, `Enemy.in_field`. `enemy-wave.md` Rule 8 says the enemy "gets its Health and Status"; this ADR has the add-enemy step call `Combat.attach` to do it.

## Performance Implications

- **CPU**: About 150 compares a tick for 48 path lookups (binary search on the starter path's 7 points); 48 entries per `_targets` rebuild; about 400 range checks in the worst tick. No time is claimed; the device run sets it.
- **Memory**: Per live enemy one `Enemy`, one `Health`, one `Status`, one `ReadContext`; at most 48 alive. One `DamageEvent` per hit, freed by reference counting (`doc/classes/RefCounted.xml@4.7.2-stable`, description: "RefCounteds keep an internal reference counter so that they are automatically released when no longer in use").
- **Load Time**: One `PathTable` build per battle.
- **Network**: None.

## Migration Plan

No code exists. Order: `Targetable`, `Health`, `Status`, `DamageEvent`; Combat with plain fixtures; `PathTable`; EnemyWave; then attackers through `_resolve_hit`.

**Rollback plan**: To move to Alternative 2, make `Health` and `Status` private to Combat keyed by `spawn_id`. Only Combat, `Targetable` and the add-enemy step change, since nobody else touches the fields.

## Validation Criteria

- Combat GDD criteria pass headless: overkill applies only the HP left; a dead target takes no hit and emits nothing; guard order (−5 on a removed target reports `ERR_REMOVED` alone); slow replace, equal and weaker; ties to the lowest `spawn_id`; `dx*dx + dy*dy == r*r` is a hit.
- Enemy & Wave criteria pass: path (0,0), (5,0), (5,5), (25,5) at `d` 10, 20, 30 gives (5,5), (15,5), (25,5); (540, 950) is in `targets()` and (550, 950) is not; a three-segment step lands on the path; no `spawn_id` is spent when `max_hp` halts or `attach` fails; acceptance 28 (kill listener adds an enemy before the clear).
- A weakref test shows every enemy freed after the `Battle` is dropped.
- Roster and targets snapshots match before and after each reader.
- A grep test finds no write to Combat-owned fields outside Combat.
- Bots: worst tick at most 400 checks. Device: helper time under 2 ms at the clamp (blocks Acceptance).

## Related

- `docs/architecture/architecture.md` v3: Dependency rule 5, B0, B6, B7, Data Flow 2 and 10, QQ-05, QQ-08, QQ-11
- `design/gdd/combat-damage.md` (Core Rules, Edge Cases, Dependencies); `design/gdd/enemy-wave.md` (Rules 4, 8 to 15; Formulas: `d_next`, position); `design/gdd/tower-system.md`; `design/gdd/hero-system.md`
- ADR-0001, ADR-0002, ADR-0004, ADR-0005, ADR-0006, ADR-0007 (depends on); ADR-0010, ADR-0011 (enabled)

### Deviations from architecture.md v3

- `distance` moves from `Enemy` to `Targetable`, because Combat's `first_in` must read it with a parse-time check.
- `Combat.attach` and the error constants are added to B6.
- `Enemy.in_field` is added to B0.
