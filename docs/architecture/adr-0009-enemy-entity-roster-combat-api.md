# ADR-0009: Enemy Entity, Roster and Combat API

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Why this is stated here: stories referencing a `Proposed` ADR are set `Blocked`,
> and epics require `Accepted`, so the field needs a named owner.
> `technical-director` is the role `coordination-rules.md` already escalates
> technical conflicts to, and an ADR is that decision made durable.
>
> This does **not** relax the existing rule that `Status: Accepted` is never set
> without explicit user confirmation. It narrows *which agent* may set it once
> that confirmation exists. An agent that believes an ADR is ready says so and
> escalates; it does not edit this field.
>
> Acceptance preconditions: ADR-0001 and ADR-0005 are Accepted; the user has
> confirmed or overturned each item in "Choices pending user confirmation"
> (end of Decision); and the verification items (Engine Compatibility) are
> split into two groups.
>
> Before acceptance: V1, V2, V3, V5, V6 and V7. Each runs as a standalone
> headless script or a throwaway project under `prototypes/`, not as a story,
> and its result is recorded in `docs/engine-reference/godot/`. Until all six
> have a recorded result this ADR stays `Proposed`, because the engine
> behaviours they cover are not sourced there.
>
> After acceptance: V4 (whole-tick cost on the device). It needs a full sim on
> the device, so it runs at the first phone build, as ADR-0004 V6. Until then
> ADR-0004's `MAX_TICKS_PER_FRAME = 3` is provisional. Reopen trigger: a p99
> tick above 1.33 ms changes that constant in place (2 to 4); above 2.0 ms it
> is escalated to `technical-director` with Decision 9's levers.
>
> Accepting it also records the
> technical director's acceptance of two QQ-08 items: the ProjectileSpawner cut
> and the move of path and slots from the stage scene to the Stage record.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference (Godot 4.7.2). The decision uses plain GDScript classes, typed arrays, `Dictionary`, `PackedFloat64Array`, `Callable`, `Signal` and `push_error`. The pinned reference does not cover typed-array variance, `Vector2` component precision, NaN handling or `is_finite`, so those are verification items, not facts.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS on the first draft, T1 blocking and T2 to T12 advisory, all applied here), godot-specialist (engine check: four blocking notes E1 to E4 and eleven minor notes, all applied). Authored with the /architecture-decision flow in autonomous mode; the parent session chose "Revise flagged items" for every finding.

## Summary

Combat (Core) must target, damage and slow enemies that Enemy & Wave (Feature) owns, without naming the Feature class, without reference cycles that would leak a battle on retry, and with deterministic results the bots can compare. This ADR decides a Core base class `Targetable extends RefCounted` that Enemy & Wave's `Enemy` extends, with sim positions stored as 64-bit `float` scalars (`pos_x`, `pos_y`) rather than `Vector2`; Health and Status as plain `RefCounted` objects held one way by the Targetable and created by `Combat.attach`; EnemyWave as sole owner of the roster in typed `Array[Targetable]` buffers with contexts keyed by `spawn_id`; a cached cumulative-length path lookup; `deliver` and `apply_slow` guards in a fixed order with named codes, reported by `push_error` under a scoped exception to ADR-0001 Decision 4; and pure scan-based targeting helpers whose cost is measured as part of the whole tick before ADR-0004 sets the catch-up clamp.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM (post-cutoff version; the decision uses no post-cutoff API, but several plain-GDScript behaviours it relies on are not in the pinned reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.6 to 4.7 GDScript rows), `deprecated-apis.md` (untyped `Array` and `Dictionary` row), `current-best-practices.md` (GDScript 4.5 and 4.7 sections). `modules/physics.md` and `modules/navigation.md` were checked and are not used: targeting is plain arithmetic, and the path is a polyline lookup, not navigation. No `modules/` file covers scripting or containers. |
| **Post-Cutoff APIs Used** | None. Two 4.7 language rules apply: an override of a typed-return method inherits the type and needs an explicit `return` (affects every test fake that subclasses `Combat` or `EnemyWave`); writing one element of a packed array no longer calls the property's setter (affects `PathTrack`, which therefore declares no setter on its packed arrays). Both from `breaking-changes.md`, 4.6 to 4.7. |
| **Verification Required** | V1 to V7 below. V1, V2, V3, V5, V6 and V7 run as standalone scripts before acceptance; V4 runs after acceptance (see Status). |

> **Note**: If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated if the
> project upgrades engine versions. Flag it as "Superseded" and write a new ADR.

Verification items. NOT SOURCEABLE: each behaviour below is not covered by `docs/engine-reference/godot/**`. This ADR stays `Proposed` until each has a recorded result.

- **V1. `Vector2` component precision (QQ-05).** Is a `Vector2` component stored as a 32-bit float in the stock 4.7.2 build? Test: `Vector2(0.1, 0.0).x == 0.1` reads false, and `Vector2(16777217.0, 0.0).x == 16777217.0` reads false, if components are 32-bit. Expected (unsourced): 32-bit. This ADR's scalar rule (Decision 2) holds either way. If V1 shows 64-bit components, a later ADR may allow `Vector2` in the sim, and ADR-0004's float policy decides. Method: a standalone headless script (`godot --headless -s`) outside `src/`, run before acceptance. Owner: gameplay-programmer, result recorded in `docs/engine-reference/godot/current-best-practices.md` and in ADR-0004.
- **V2. Typed-array variance and Callable returns.** (a) Passing an `Array[Enemy]` where `Array[Targetable]` is declared is an error (the engine check expects so but could not confirm it); (b) appending an `Enemy` to an `Array[Targetable]` succeeds; (c) `t as Enemy` on an element returns the instance; (d) `var list: Array[Targetable] = targets.call()`, where `targets` is the method Callable `enemy_wave.targets`, assigns without error and keeps the element type; (e) `Array.remove_at(i)` and `Array.erase(value)` keep order of the remaining elements; (f) `Array.clear()` followed by `append` reuses capacity or reallocates (recorded, not required; feeds V4). Optional: (g) typed `Dictionary[int, ReadContext]` (4.4+) parses and rejects a wrong value type; until (g) passes, `_contexts` stays an untyped `Dictionary`. Expected (unsourced): (a) to (e) as stated. `architecture.md` dependency rule 5 states (a) without a source. Method: a standalone headless script outside `src/`, or a throwaway project under `prototypes/` with stub `Targetable` and `Enemy` classes. Run before acceptance; result recorded in `docs/engine-reference/godot/`. Owner: gameplay-programmer.
- **V3. Non-finite floats.** `is_finite(NAN)`, `is_finite(INF)` and `is_finite(-INF)` are false; `NAN > 0.0`, `NAN < 1.0` and `NAN >= 0.0` are false. Every guard calls `is_finite` first, so the comparisons are only a second line. Expected (unsourced): IEEE semantics. Method: a standalone headless script outside `src/`. Run before acceptance; result recorded in `docs/engine-reference/godot/`. Combat Acceptance 2 and 7 and the `attach` cases repeat the checks as unit tests later. Owner: gameplay-programmer.
- **V4. Whole-tick cost (QQ-11, TR-combat-013).** Measure one whole `battle.tick` at the worst case (48 alive enemies, five towers, the hero and a burst release), not only the helpers: the cost is expected to be dominated by property lookups, `is_dead` calls, accessor reads and the per-hit allocations (`DamageEvent.make`, one `all_in_radius` result per splash or burst). Record the helpers' share (about 340 range checks) separately against the GDD's 2.0 ms ceiling. Method: headless micro-benchmark on desktop first (a baseline only, not a pass), then the device run on a low-end Android device (Adreno 5xx class) at the first phone build. Owner: performance-analyst with ADR-0004, which sets `MAX_TICKS_PER_FRAME` from the measured whole-tick cost (Decision 9).
- **V5. One-way ownership frees.** Dropping the last strong reference to an `Enemy` frees it, its `Health`, its `Status` and its `ReadContext` (weakrefs all null), both on reap inside a running battle (after the test drops its own references) and on retry. Depends on ADR-0001 V1 (method Callables and signal connections do not hold their target strongly). Method: a throwaway project under `prototypes/` with stub `Enemy`, `Health`, `Status` and `ReadContext` classes, run headless, extending ADR-0001's weakref proof. Run before acceptance; result recorded in `docs/engine-reference/godot/`. Owner: gameplay-programmer; the ADR-0007 test harness later keeps it as a regression test.
- **V6. Cyclic script references between `class_name` scripts.** `DamageEvent` types a field `Combat.SourceKind` while `Combat` takes a `DamageEvent` parameter; `Targetable` types fields `Health` and `Status`; `Enemy` extends `Targetable`. Do these parse and run on 4.7.2 with no cyclic-reference error? Expected (unsourced): yes; the engine check could not confirm it. Fallback if not: move `SourceKind` into its own constants script (`class_name CombatTypes extends RefCounted` holding only `enum SourceKind`), referenced by both. Also record whether assigning a bare `int` to a `Combat.SourceKind`-typed variable warns, so callers always pass the enum member. Method: a throwaway project under `prototypes/` with stub versions of the five scripts, parsed and run headless. Run before acceptance; result recorded in `docs/engine-reference/godot/`. Owner: gameplay-programmer.
- **V7. Subclass constructor chaining.** `Targetable._init(p_spawn_id: int)` has a required argument, so `Enemy._init(p_spawn_id, p_def_id)` must call `super(p_spawn_id)`. Confirm on 4.7.2 that omitting the `super` call is a parse or run-time error (not a silent default), and that a test fake subclassing `Combat` or `EnemyWave` must likewise forward its constructor arguments. Expected (unsourced): an error. Method: a throwaway project under `prototypes/` with stub `Targetable` and `Enemy` scripts, run headless. Run before acceptance; result recorded in `docs/engine-reference/godot/`. Owner: gameplay-programmer.

Not verified and not relied on: signal parameter types are metadata only, and `emit()` does not check them (`architecture.md` Data Flow 3 rule 5); recording fakes assert payloads instead (ADR-0007). Cross-device float results (for example fused multiply-add on ARM) matter only for bit-exact comparison across devices; bot baselines are kept per architecture (QQ-05), so no decision here depends on them.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Builder, injected `halted`, `fatal`, `dev_error`, `to_ticks`, `targets`; no RefCounted cycles; commit then emit; method Callables only), ADR-0005 (`StatAccessor`, `ReadContext`, `StatKeys`; contexts held by the owner keyed by `spawn_id`; `MAX_HP` read once to seed Health). Both Proposed. ADR-0002 is used through ADR-0005 (record classes, `PackedFloat64Array` geometry, `StringName` IDs) and is not a separate gate. |
| **Enables** | ADR-0010 (Tower and Hero commands call Combat's API and read `targets()`). ADR-0010 inherits one constraint: HeroSim and TowerSim store and compare every sim position (hero position, pin target, aim point, slot origins) as `float` scalars, because Combat's helpers take scalars (Decision 2). `architecture.md` B8's `pin(pos: Vector2)` and `burst(pos: Vector2)` stay legal as boundary inputs from HeroInput, converted to scalars on entry; `hero_pinned` and `burst_started` stay `Vector2` as view signals; B8's `position()` query may return `Vector2` for views only. ADR-0011 (views read `roster()`, `view_position()` and Combat's view signals). |
| **Blocks** | Every Combat & Damage and Enemy & Wave story (the Combat GDD names this decision as a prerequisite). Tower and Hero targeting stories also need it, through ADR-0010. |
| **Ordering Note** | Tick order is owned by ADR-0004 Decision 4 (Proposed), which ratifies `architecture.md` Data Flow 2 unchanged. Signal payload ID types are ADR-0006's (QQ-04); `StringName` is the working default here. `class_name` collision handling (`Health`, `Status`, `Combat` are short global names, QQ-16) is ADR-0007's; the names here are provisional until then. V1, V2, V6 and V7 must run before the first EnemyWave story. Decision 4 declares a scoped exception to ADR-0001 Decision 4 (Combat's guard codes use `push_error` directly); ADR-0001's guideline and the registry's `release_relevant_checks` are amended in the same change (cascade notes). |

## Context

### Problem Statement

The Combat GDD splits combat into three pieces (DamageEvent, Health, Status) and hands this ADR every structural question it could not answer in design: the enemy's object kind, how Health and Status attach and which call registers them at spawn, who owns what and how cycles are avoided, how the helpers' list is typed, where `SourceKind` and `DamageEvent` live, and what Combat itself is. The Enemy & Wave GDD hands over the attachment and the storage form of path geometry. Combat sits in Core and the enemy in Feature, so Combat cannot name `Enemy` without an upward dependency. No Combat, Enemy & Wave, Tower or Hero targeting code can be written until these are fixed.

### Current State

No code exists. `architecture.md` proposes: `Targetable extends RefCounted` with `spawn_id`, `position: Vector2`, `removed`, `health`, `status` (B0, dependency rule 5); `Enemy extends Targetable` adding `def_id` and `distance`; the Combat API copied from the GDD with `Vector2` origins (B6); EnemyWave's API (B7). ADR-0002 stores geometry as `PackedFloat64Array` so no 32-bit rounding enters the data; PinGeometry computes in `float` scalars. ADR-0005 moved the enemy's `ReadContext` out of the enemy and into EnemyWave. The prototype skipped the hero's leash check and credited negative damage; both are what the guards below prevent.

### Constraints

- Downward dependencies only: Core never names a Feature class (dependency rule 1, rule 5).
- All sim classes extend `RefCounted`, never `Node` (B0 preamble, TR-combat-002).
- No RefCounted cycles, no field holding `Battle`, method Callables only, no lambdas or `bind()` (ADR-0001).
- No autoloads, no mutable `static var` (ADR-0001).
- An entity never holds its own `ReadContext`; stats are read at use time, except `MAX_HP` seeding Health (ADR-0005).
- Combat reads no catalogue data; its only injected dependency is `to_ticks` (TR-combat-007).
- No `assert` for release-relevant checks (ADR-0001 Decision 4).
- Deterministic and single-threaded (Data Flow preamble).
- Solo part-time developer: the smallest structure that meets the GDDs.

### Requirements

- The 16 TRs in GDD Requirements Addressed, below.
- About 400 range checks per tick within 2 ms on a low-end phone at the catch-up clamp (TR-combat-013, unmeasured).
- Every Combat acceptance criterion runs headless with factory fixtures, no scene and no catalogue.
- Every Enemy & Wave acceptance criterion runs with a fake Combat.

## Decision

### 1. Targetable: the Core base class

`Targetable` (`src/core/combat/targetable.gd`, `extends RefCounted`) is the one type Combat sees. It carries what the Combat GDD says Combat sees of an enemy, plus the two Combat pieces:

| Field | Type | Written by | Meaning |
|---|---|---|---|
| `spawn_id` | `int` | EnemyWave, once, at construction | Battle-wide, never reused; every tie-break |
| `distance` | `float` | EnemyWave, in the move step | Distance along the path, cached once per tick |
| `pos_x`, `pos_y` | `float` | EnemyWave, in the move step | Centre in field units (y down), cached once per tick |
| `removed` | `bool` | EnemyWave, on leak or reap | True once the enemy has left the roster |
| `health` | `Health` | Combat (`attach`) | Set once at spawn; never null on the roster |
| `status` | `Status` | Combat (`attach`) | Set once at spawn; never null on the roster |

`distance` moves from `Enemy` to `Targetable`, because `first_in` ranks by it and Combat may not name `Enemy`. `Targetable` also has `view_position() -> Vector2`, which returns `Vector2(pos_x, pos_y)`. Views call it to draw. Sim code may call it only to build a view-signal payload (Combat does, for `damage_applied`); sim code must never use its result for a decision, a comparison or stored state.

`Enemy` (`src/feature/enemy_wave/enemy.gd`, `extends Targetable`) adds `def_id: StringName` and `segment: int` (the path segment hint, Decision 7). Its `_init(p_spawn_id, p_def_id)` must call `super(p_spawn_id)` first, because `Targetable._init(p_spawn_id: int)` has a required argument (V7). It holds no `ReadContext`, no reference to EnemyWave, Combat or Battle, and no Callable.

GDScript has no access control. The write column is enforced by code review now and by an ADR-0007 lint rule later (cascade notes).

A removed enemy is never freed by the sim. It stays a valid object while anything holds it, so `deliver`'s `removed` guard can read it (TR-combat-002). A `Node` was rejected for this reason and because its built-in `position` would collide.

### 2. Sim positions are float scalars, not Vector2

Every position the sim computes and compares is a pair of GDScript `float` values (64-bit in GDScript): `Targetable.pos_x`/`pos_y`, the helpers' `origin` and `impact`, and the path lookup. `Vector2` appears only at boundaries where precision cannot change a result: input arriving from the adapter, the `report_attack` and view-signal payloads, and `view_position()`.

This matches the existing choices. ADR-0002 stores geometry as `PackedFloat64Array` so no 32-bit rounding enters the data; PinGeometry computes in `float` scalars and takes `Vector2` only at its boundary (Hero Formulas). If enemy positions were `Vector2`, each tick would round a 64-bit interpolation to 32 bits and then compare it against a 64-bit range squared, so an inclusive edge test such as the leash at exactly 90 could flip against a reference computed in 64 bits. Storing scalars removes that question rather than testing around it. V1 records whether `Vector2` is really 32-bit on 4.7.2; the scalar rule does not depend on the answer, and only a later ADR (with ADR-0004's float policy) may relax it.

### 3. Health and Status: one-way attachment, no back-references

`Health` (`src/core/combat/health.gd`) and `Status` (`src/core/combat/status.gd`) extend `RefCounted` and hold no reference to their `Targetable`, to Combat or to anything else:

```gdscript
class_name Health extends RefCounted
var hp: float        # current HP, never below 0
var max_hp: float    # the spawn seed, kept for the invariant check and the damaged-core view; never re-read

class_name Status extends RefCounted
var strength: float = 0.0   # slow strength in the one slot; 0.0 when empty
var ticks_left: int = 0     # whole ticks left; the slot is empty at or below 0
```

The Targetable holds them strongly; they hold nothing. That is the only direction, so no cycle can form (ADR-0001). Storing `max_hp` in Health is the seed itself, which ADR-0005 allows; it is never read back as a stat and never refreshed.

Combat creates them in one registration call:

```gdscript
## Creates Health (seeded from max_hp) and Status on t. Checks, in order:
## t already has Health or Status: push_error(ERR_ALREADY_ATTACHED), return false.
## not is_finite(max_hp) or max_hp <= 0.0: push_error(ERR_BAD_MAX_HP), return false.
## Writes nothing on failure.
func attach(t: Targetable, max_hp: float) -> bool
```

The two codes are separate because they mean different defects: `ERR_ALREADY_ATTACHED` is a code bug (a second registration), `ERR_BAD_MAX_HP` is bad data or a spy value. `is_finite` runs before the comparison, so NaN never reaches `<=` (V3).

Only Combat writes `hp`, `max_hp`, `strength` and `ticks_left`. A Targetable is never added to the roster before `attach` returns true.

### 4. Combat: object kind, owner and declarations

`Combat` (`src/core/combat/combat.gd`, `extends RefCounted`) is one per battle. `BattleBuilder.build` creates it with `Combat.new(to_ticks)` (the method Callable from B9; `_init` checks `is_valid()` and calls `push_error` if not), and `Battle` owns it as the read-only member `combat`. Combat holds its counters and the `to_ticks` Callable, and nothing else: no Targetable, no list, no event. `SourceKind` is declared on Combat (`enum SourceKind { TOWER, HERO, BURST }`). `DamageEvent` has its own file:

```gdscript
# src/core/combat/damage_event.gd
class_name DamageEvent extends RefCounted
var target: Targetable
var amount: float
var source_kind: Combat.SourceKind
var source_id: StringName           # dealer's definition ID; StringName per ADR-0006 (QQ-04)
static func make(target: Targetable, amount: float, source_kind: Combat.SourceKind, source_id: StringName) -> DamageEvent
```

Callers make one event per victim. Combat never stores an event. `damage_applied` does not carry the event: ADR-0006 Decision 4 replaced the GDD's `event` parameter with `source_kind` and `source_id`, so no listener can reach `event.target` (Combat Rule 12), by construction.

**Scoped exception to ADR-0001 Decision 4.** Combat calls `push_error` directly for its guard codes, with the fixed message constants `ERR_REMOVED`, `ERR_BAD_AMOUNT`, `ERR_BAD_SLOW`, `ERR_BAD_MAX_HP` and `ERR_ALREADY_ATTACHED`, instead of the injected `dev_error` sink. ADR-0001 Decision 4 and the registry's `release_relevant_checks` say a release-relevant failure goes through `fatal` or `dev_error`; this exception covers only these five codes in `src/core/combat/`. Reasons: the guards catch caller bugs that are unreachable at MVP (attackers hold no target across ticks, and callers pass catalogue-validated values); each guarded call changes nothing, so state stays correct whether or not the message is seen; it keeps `to_ticks` Combat's only dependency (TR-combat-007); and it matches the GDD's test method (`assert_error(...).is_push_error(constant)`). Accepted costs: these messages are not recorded in `DevErrorSink`'s in-memory list, and they may be silent in a release export if ADR-0001 V4 shows `push_error` does not log there. The one guard whose failure must not pass silently, a bad `max_hp`, is escalated by EnemyWave to `fatal` (Decision 7), so it does not rely on `push_error`. Combat injects no `halted()` and no `fatal`: it never reads a stat, and its two signals are view-only and cannot end a battle, so ADR-0001's "check after every signal that can end the battle" does not apply to them. Its callers check `halted()` after their own reads.

### 5. Guards in fixed order

`deliver(event) -> float`:

1. `event.target.removed`: `push_error(ERR_REMOVED)`, return 0.0.
2. `amount` not finite, or below 0: `push_error(ERR_BAD_AMOUNT)`, return 0.0. Tested with `is_finite` (V3) before any arithmetic.
3. Dead (`health.hp <= 0.0`): return 0.0, silent.
4. `applied = minf(amount, hp)` (typed; `min()` returns `Variant`). If `applied` is 0.0, return 0.0 with no counter change and no signal.
5. Commit: `hp -= applied`; `dealt[source_id] = dealt.get(source_id, 0.0) + applied` (a `+=` on a missing key is a run-time error); the kind sum for `source_kind` `+= applied` (a `PackedFloat64Array` of three, indexed by the enum).
6. Emit `damage_applied(event.source_kind, event.source_id, applied, target.view_position(), hp <= 0.0, target.spawn_id)`.
7. Return `applied`.

Only the first failing guard reports. `deliver` runs only inside a tick; that is caller discipline (Combat Rule 2), checked by the Enemy & Wave and Hero deferred criteria, not by a flag in Combat.

`apply_slow(t, strength, seconds) -> void` runs the same order: removed (`ERR_REMOVED`), then values, then dead (silent). The value test is written so NaN fails it: `not is_finite(strength) or not (strength > 0.0 and strength < 1.0) or not is_finite(seconds) or not (seconds > 0.0)` reports `ERR_BAD_SLOW`. Then `ticks = maxi(1, int(_to_ticks.call(seconds)))`, using the typed `maxi` because `max()` and `Callable.call()` return `Variant`. An empty slot or a stronger slow replaces both fields; an equal strength keeps `max(ticks_left, ticks)`; a weaker one changes nothing. Strengths compare exactly.

`speed_factor(t) -> float` is `1.0 - strength` while `ticks_left > 0`, else `1.0`. `tick_status(roster: Array[Targetable])` subtracts 1 from every non-empty slot and empties any at or below 0 (`strength = 0.0`, `ticks_left = 0`); it emits nothing. `is_dead(t)` is `health.hp <= 0.0` and stays answerable after removal; `hp_left(t)` is `health.hp`.

### 6. Targeting helpers

All three are pure scans over the caller's list. They never mutate it, never sort, never allocate (except `all_in_radius`'s result), skip any element that `is_dead` or has `removed` set, and use the inclusive test `dx * dx + dy * dy <= r * r` on `pos_x`/`pos_y`, applied before any ranking. Ties go to the lowest `spawn_id`, compared explicitly, so input order never decides.

- `first_in(list, origin_x, origin_y, max_range) -> Targetable`: greatest `distance` in range; null if none.
- `nearest_in(list, origin_x, origin_y, max_range) -> Targetable`: smallest squared distance to the origin in range; null if none.
- `all_in_radius(list, impact_x, impact_y, radius) -> Array[Targetable]`: every element in range, in input order; a new empty typed array if none.

Skipping `removed` adds nothing at MVP (`targets()` never holds a removed enemy) and keeps a leaked enemy from ever being a target if a caller passes another list. Filtering is the caller's job: a slow tower builds its "unslowed first" list (`speed_factor` exactly 1) into its own reused `Array[Targetable]` buffer, cleared and refilled per attack, then falls back to `targets()` (Tower Rule 9; ADR-0010).

### 7. EnemyWave: roster ownership, path lookup, add-enemy step

EnemyWave (`src/feature/enemy_wave/enemy_wave.gd`, `extends RefCounted`) is the sole owner of every enemy (TR-enemy-008). It holds:

- `_roster: Array[Targetable]`, every enemy not yet removed, in `spawn_id` order (append order; removal keeps order).
- `_targets: Array[Targetable]`, the roster entries whose centre is inside the field, edges included.
- `_contexts: Dictionary`, `spawn_id` (int) to that enemy's `ReadContext` (ADR-0005). A typed `Dictionary[int, ReadContext]` (4.4+) is not in the pinned reference; it replaces the untyped form only after V2 (g) passes.
- `_roster_count: int` and `_targets_count: int`, which EnemyWave updates on each of its own writes (the ownership check below).
- `_path: PathTrack`, `_next_spawn_id: int`, `_wave_state: WaveState` (`enum WaveState { WAITING, ACTIVE, FINISHED }`, declared on EnemyWave), the wave schedule (Enemy & Wave GDD), and the per-type leak counts.

Its constructor receives, from the Builder: the `StageRecord`, the stage's `Array[WaveRecord]`, the `StatAccessor`, `Combat`, `dt: float`, the field size (`field_w`, `field_h`, from the constants `FieldBounds.WIDTH` 540.0 and `FieldBounds.HEIGHT` 960.0 in `src/foundation/field_bounds.gd`, so tests may pass their own), and the Callables `halted`, `fatal`, `dev_error`, `to_ticks`. Holding `Combat` is a downward reference to an object that holds nothing back, so it forms no cycle.

**Path lookup (TR-enemy-010).** `PathTrack` (`src/feature/enemy_wave/path_track.gd`, `extends RefCounted`) is built once from `StageRecord.path_points` (`PackedFloat64Array`, x and y interleaved, ADR-0002) by a static factory, because `_init` cannot report failure:

```gdscript
## Returns null if the points are unusable: an odd float count, fewer than two
## points, any non-finite coordinate, or any segment whose length is not above 0.
static func make(path_points: PackedFloat64Array) -> PathTrack
```

The catalogue validator already rejects these for real stages (ADR-0002 geometry rule); the factory covers code-built fixtures and any path that bypasses the validator. EnemyWave's constructor calls `PathTrack.make`, and on null calls `fatal("enemy_wave: bad path_points for <stage id>")` and stops constructing; the Builder sees the latch and returns null (ADR-0001 Decision 5).

It keeps the points `P` (`n` points), the segment lengths `seg_len` and the cumulative lengths `cum` (both `PackedFloat64Array`; no variable is named `len`, which would shadow `len()`), with `path_length = cum[n - 1]`. It declares no setter on any packed array (4.7 rule). `place(e: Enemy) -> void` sets `e.pos_x`/`e.pos_y` from `e.distance = d`: if `d >= path_length`, the last point. Otherwise, starting from `k = e.segment`, it advances `k` while `k + 2 < n and cum[k + 1] <= d`, so one step may cross several segments and `k` never passes the last segment; it stores `k` in `e.segment`, then applies the GDD formula exactly, `P[k] + (d - cum[k]) / seg_len[k] * (P[k+1] - P[k])`, per axis. Distance only grows, so the walk from the hint is short.

**Add-enemy step (TR-enemy-013).** One step serves the schedule now and splitter children later (the schedule passes `start_distance` 0.0). It is public, so tests can reach it (Enemy & Wave Acceptance 28 calls it from a kill listener, and the GDD's seam list names it), but its only sim caller is EnemyWave itself: no other `src/` class may call it (code review, and an ADR-0007 lint candidate):

```gdscript
## The one way an enemy joins the roster. Callers: EnemyWave's spawn step, and
## tests. Returns false if a read halted or attach failed; nothing persists then.
func add_enemy(def_id: StringName, start_distance: float) -> bool
```

1. Take `id = _next_spawn_id` and increment it.
2. `e = Enemy.new(id, def_id)`; `ctx = ReadContext.make(def_id, 0, e)`.
3. `max_hp = accessor.stat_float(ctx, StatKeys.MAX_HP)`. If `halted()`, return false; `e` and `ctx` are dropped, nothing persists.
4. If `combat.attach(e, max_hp)` is false: `fatal("enemy_wave.add_enemy: attach failed for <def_id>")`, return false.
5. Set `e.distance = start_distance`, `_path.place(e)`.
6. Commit: `_roster.append(e)`, `_contexts[id] = ctx`; if the centre is inside the field, also `_targets.append(e)` (appending keeps `spawn_id` order); update the counts. Return true. No signal (the GDD has no spawn signal).

Children appended this way join the roster before the reap's clear check, so the clear test (schedule exhausted and roster empty) can never see a wave as clear while a child exists.

**Advance and reap.** The order of the tick's steps is ADR-0004's; inside its own two entries EnemyWave does:

- `advance() -> void`: ownership check (below); spawn (schedule members due at `wave_tick`, groups in authored order, members ascending, each through `add_enemy`; **if `add_enemy` returns false, `advance` returns at once**, so no later member spawns and nothing moves, Rule 13 and Acceptance 19); move (for each enemy in `spawn_id` order not dead: read `MOVE_SPEED` through its context, check `halted()`, `distance = minf(distance + speed * combat.speed_factor(e) * dt, path_length)`, `_path.place(e)`); rebuild `_targets`; leak loop; then `wave_tick` rises.
- `reap() -> void`: ownership check; reap loop; then the clear check every tick while the wave is Active (Enemy & Wave Rule 11), state committed before `wave_cleared` or `waves_completed`, then `halted()`.

**Loop rules (leak and reap).** Both loops must be written as `var i := 0` / `while i < _roster.size():`, reading the size on every pass; must never use `for e in _roster` while removing. For a match (leak: `distance >= path_length`; reap: `combat.is_dead(e)`): read the stat (`LIVES_COST` or `BOUNTY`) through the context, check `halted()`, then commit `removed = true`, `_roster.remove_at(i)`, `_targets.erase(e)`, `_contexts.erase(e.spawn_id)`, the counts and (leak only) the per-type leak count; then emit (`enemy_leaked(lives_cost)` or `enemy_killed(bounty)`) and check `halted()`. After a removal, `i` is not advanced, since the next enemy now sits at `i`; otherwise `i += 1`. A listener may append to the roster during the emit (a kill listener calling `add_enemy`, Acceptance 28): the child lands at the end, so the size read on the next pass picks it up, and an alive child is skipped by the reap and keeps the wave from clearing.

Removal happens at once, in place, before the signal, so a listener reading `roster()` or `targets()` inside the handler never sees a removed enemy, and a halt mid-loop leaves both buffers compact with nothing to fix. A corpse stays in both lists until the reap; the helpers skip it.

**Reads and the ownership check.** `roster()` and `targets()` return the internal buffers themselves, with no copy and no allocation. They are read-only by contract: no caller may append, erase, sort, clear or keep them past its tick slot (or its frame, for views). Copies were rejected (Alternative 6). `make_read_only()` was rejected too, because it would lock EnemyWave's own writes to the same buffers. Instead, at the start of `advance()` and `reap()`, EnemyWave compares `_roster.size()` with `_roster_count` and `_targets.size()` with `_targets_count`; a mismatch means a caller mutated a buffer, and EnemyWave calls `dev_error` with the counts. This catches appends and removals, not reorders; reorders are left to the review rule and the Validation 5 snapshot test.

`_targets` is rebuilt with `clear()` then `append`. Whether `clear()` keeps capacity is not in the pinned reference (V2 (f)); if V4 shows the rebuild allocating, it changes to resize-and-overwrite with no interface change. `wave_index()`, `got_through_by_type()`, `wave_state()` and `wave_tick()` are as in the GDD and B7.

### 8. The two QQ-08 items this ADR closes

- **ProjectileSpawner cut.** Every hit is instant and goes through `deliver` inside a tick. If projectiles are ever added, the spawner is a caller in front of `deliver`: it holds its own flights and calls `deliver` at impact in its own tick slot. `deliver`'s contract and the counters do not change. Attackers that enumerate victims at fire time would change, as the Combat GDD accepts.
- **Path and slots on the Stage record.** `path_points`, `slot_positions` and `path_width` are Stage record fields (ADR-0002 stores them). EnemyWave and TowerSim read them from the `StageRecord` the Builder passes in; `scene_ref` holds the look only. Views draw the path from the same points.

### 9. Per-tick budget

The helpers scan linearly with no spatial structure. At the GDD's worst case (48 alive, five towers, hero and burst) one tick does about 340 range checks, each a few multiplies and one compare, plus one `_targets` rebuild over at most 48 entries, plus the per-hit allocations (one `DamageEvent` per victim, one `all_in_radius` result per splash or burst).

The GDD's figure, under 2 ms per tick for targeting, is a ceiling, not a target, and it does not fit the frame budget at its full value. Data Flow 10 gives the whole simulation 4.0 ms per frame, so at `MAX_TICKS_PER_FRAME = N` one whole tick (Flow, movement, accessor reads, status, towers, hero, reap and targeting) must fit `4.0 / N` ms. If targeting alone took 2.0 ms, N could be at most 2, and at N = 2 nothing would be left for the rest of the tick. So this ADR registers no targeting slice of its own. V4 measures the whole tick at the worst case, with the helpers' share recorded beside it, and ADR-0004 sets N from the whole-tick figure. Levers if the measurement is too high: first ADR-0004's N (3 by default, never below 2, ADR-0004 Decision 2); second a bucketing scheme inside the helpers that keeps their signatures and their results, proven against the scan; third reusing the per-hit allocations.

### Choices pending user confirmation

This ADR was drafted in autonomous mode. These choices are the recommended option but change a GDD, an earlier ADR or a GDD-stated behaviour, so the user confirms or overturns each before acceptance (Status note):

1. **Float scalar sim positions instead of `Vector2`** (Decision 2). Renames the Combat GDD's `position`, `origin` and `impact`, and binds ADR-0010. The alternative is `Vector2` with 32-bit rounding inside range tests (Alternative 5).
2. **Combat's guard codes use `push_error` directly**, a scoped exception to ADR-0001 Decision 4 (Decision 4). The alternative is injecting `dev_error` into Combat, which adds a second dependency against TR-combat-007 and changes the GDD's test method.
3. **A bad `max_hp` at spawn is fatal** (Decision 7, step 4). The alternative is a development error that skips the spawn, which would let a wave run short silently.
4. **`roster()` and `targets()` return internal buffers**, guarded by the count check, not copies (Decision 7, Alternative 6).
5. **`add_enemy` is public for tests** with a rule that no other `src/` class calls it (Decision 7).
6. **Helpers also skip `removed` targets** (Decision 6), a small addition to Combat Rule 10.
7. **`advance()` takes no argument** (Key Interfaces), against B7's `advance(tick: int)`.

### Architecture Diagram

```
 Battle (owns all; nothing below holds Battle)
  ├─ Combat (Core) ── holds: counters, to_ticks Callable. Holds no Targetable.
  │     attach / deliver / apply_slow / speed_factor / tick_status / helpers
  │     signals: attack_fired, damage_applied (view-only, Vector2 copies)
  │
  └─ EnemyWave (Feature) ── holds Combat (down), StatAccessor, StageRecord, WaveRecords
        ├─ _roster:   Array[Targetable] ─────► Enemy (extends Targetable)
        ├─ _targets:  Array[Targetable] ─────►   ├─ health ──► Health  (holds nothing)
        ├─ _contexts: spawn_id ─► ReadContext    └─ status ──► Status  (holds nothing)
        │                   └─ live_entity ──► Enemy   (one way; Enemy holds no ctx)
        └─ _path: PathTrack (points, cum: PackedFloat64Array)

 TowerSim / HeroSim ── targets() (injected method Callable) ─► Array[Targetable]
        └─► Combat.first_in / nearest_in / all_in_radius (pos_x, pos_y scalars)
        └─► report_attack (Vector2 for the view) then deliver(DamageEvent) per victim

 Every arrow points away from the enemy. No arrow points back at Targetable, EnemyWave or Battle.
```

### Key Interfaces

```gdscript
# src/core/combat/targetable.gd
class_name Targetable extends RefCounted
var spawn_id: int
var distance: float = 0.0
var pos_x: float = 0.0
var pos_y: float = 0.0
var removed: bool = false
var health: Health = null
var status: Status = null
func _init(p_spawn_id: int) -> void
func view_position() -> Vector2          # views, and building view-signal payloads; never a sim decision

# src/core/combat/health.gd, status.gd: as in Decision 3
# src/core/combat/damage_event.gd: as in Decision 4

# src/core/combat/combat.gd
class_name Combat extends RefCounted
enum SourceKind { TOWER, HERO, BURST }
const ERR_REMOVED := "combat: target removed"
const ERR_BAD_AMOUNT := "combat: amount negative or not finite"
const ERR_BAD_SLOW := "combat: slow strength or seconds out of range"
const ERR_BAD_MAX_HP := "combat: max_hp not finite or not above 0"
const ERR_ALREADY_ATTACHED := "combat: target already has Health or Status"
func _init(to_ticks: Callable) -> void
func attach(t: Targetable, max_hp: float) -> bool
func deliver(event: DamageEvent) -> float
func apply_slow(t: Targetable, strength: float, seconds: float) -> void
func speed_factor(t: Targetable) -> float
func tick_status(roster: Array[Targetable]) -> void
func first_in(list: Array[Targetable], origin_x: float, origin_y: float, max_range: float) -> Targetable
func nearest_in(list: Array[Targetable], origin_x: float, origin_y: float, max_range: float) -> Targetable
func all_in_radius(list: Array[Targetable], impact_x: float, impact_y: float, radius: float) -> Array[Targetable]
func is_dead(t: Targetable) -> bool
func hp_left(t: Targetable) -> float
func report_attack(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func dealt_by_id(id: StringName) -> float          # 0.0 for an unknown ID
func dealt_by_kind(kind: SourceKind) -> float
func dealt_total() -> float                        # sum of the three kind sums
func hero_share() -> float                         # (HERO + BURST) / total; 0.0 when total is 0
signal attack_fired(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(source_kind: SourceKind, source_id: StringName, applied: float, position: Vector2, killed: bool, spawn_id: int)   # ADR-0006

# src/feature/enemy_wave/enemy.gd
class_name Enemy extends Targetable
var def_id: StringName
var segment: int = 0
func _init(p_spawn_id: int, p_def_id: StringName) -> void   # first line: super(p_spawn_id)

# src/feature/enemy_wave/path_track.gd
class_name PathTrack extends RefCounted
static func make(path_points: PackedFloat64Array) -> PathTrack   # null on unusable points
func path_length() -> float
func place(e: Enemy) -> void

# src/foundation/field_bounds.gd
class_name FieldBounds extends RefCounted     # constants only; never instantiated
const WIDTH := 540.0
const HEIGHT := 960.0

# src/feature/enemy_wave/enemy_wave.gd
class_name EnemyWave extends RefCounted
enum WaveState { WAITING, ACTIVE, FINISHED }
func _init(stage: StageRecord, waves: Array[WaveRecord], accessor: StatAccessor, combat: Combat,
		dt: float, field_w: float, field_h: float,
		halted: Callable, fatal: Callable, dev_error: Callable, to_ticks: Callable) -> void
func advance() -> void
func reap() -> void
func start_next_wave() -> void
func add_enemy(def_id: StringName, start_distance: float) -> bool   # EnemyWave and tests only
func roster() -> Array[Targetable]     # internal buffer; read-only; spawn_id order
func targets() -> Array[Targetable]    # internal buffer; read-only; centre inside the field
func wave_index() -> int
func got_through_by_type() -> Dictionary
func wave_state() -> WaveState
func wave_tick() -> int
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_completed()               # renamed from waves_complete (ADR-0006)
```

Names and signatures are the contract; private fields may change. `advance()` takes no argument: EnemyWave owns `wave_tick`, and a passed battle tick would be a second clock that could disagree.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Combat and its helpers must take and return `Targetable`; Core code must never name `Enemy` or any Feature class.
- Every list of enemies must be declared `Array[Targetable]` from creation; must never build an `Array[Enemy]` for Combat.
- Sim positions must be `float` scalars (`pos_x`, `pos_y`, `origin_x`, `origin_y`, `impact_x`, `impact_y`); must never store or compare a sim position as `Vector2`. `Vector2` is allowed only for input arriving from the adapter, `report_attack`, Combat's view signals and `view_position()`.
- Sim code must never use `view_position()` for a decision, a comparison or stored state; it may call it only to build a view-signal payload.
- HeroSim and TowerSim (ADR-0010) must store hero position, pin target, aim point and attack origins as `float` scalars, converting any `Vector2` command argument on entry.
- `Enemy._init` must call `super(p_spawn_id)` first; every test fake that subclasses a class whose `_init` takes arguments must forward them with `super(...)`.
- Combat must report its guard failures with `push_error` and its `ERR_*` constants only (the scoped exception to ADR-0001 Decision 4); no other class may cite this exception.
- Every float guard must call `is_finite` before any comparison, and must write range tests so NaN fails them (`not (x > 0.0 and x < 1.0)`).
- Must update `dealt` with `dealt.get(id, 0.0) + applied`; must never `+=` a possibly missing Dictionary key.
- Must use the typed `minf`, `maxf`, `mini`, `maxi` in sim code, and cast `Callable.call()` results (`int(...)`, `float(...)`) before use.
- Must never name a variable `len`, `range` or `seed` (they shadow GDScript globals).
- Leak and reap loops must be `while i < _roster.size()` index loops that do not advance `i` after `remove_at(i)`; must never remove inside `for ... in`.
- `advance()` must return at once when `add_enemy` returns false.
- Must build `PathTrack` only through `PathTrack.make`, and must call `fatal` when it returns null.
- Only EnemyWave and tests may call `add_enemy`.
- `Health` and `Status` must never hold a reference to their `Targetable` or to any other object.
- `Enemy` must never hold its `ReadContext`, EnemyWave, Combat, Battle or any Callable.
- Only Combat may write `health`, `status`, `hp`, `max_hp`, `strength` or `ticks_left`. Only EnemyWave may write `distance`, `pos_x`, `pos_y` or `removed`.
- Must call `combat.attach` and get true before adding an enemy to the roster; must route every spawn, now and for splitters later, through `add_enemy`.
- Every HP change must go through `deliver`; `deliver` must run only inside a tick.
- Must create one `DamageEvent` per victim; Combat must never store an event; `damage_applied` carries `source_kind` and `source_id`, never the event (ADR-0006); listeners must never call `deliver` or the `StatAccessor`.
- Callers must call `report_attack` before the attack's `deliver` calls, and deliver before `apply_slow`.
- Combat must never read the catalogue or the stat accessor and must never hold a Targetable or a list.
- Helpers must never mutate, sort or keep their input list; tie-breaks must compare `spawn_id` explicitly.
- Must never mutate or keep the arrays returned by `roster()` or `targets()`; a caller that needs a filtered list must fill its own reused buffer.
- EnemyWave must remove a leaked or reaped enemy from `_roster`, `_targets` and `_contexts` before emitting its signal, and must check `halted()` after every accessor read and every signal it emits.
- EnemyWave must read `MOVE_SPEED`, `LIVES_COST` and `BOUNTY` at use time through the enemy's context; `MAX_HP` is read once in the add-enemy step.
- `PathTrack` must compute position by the GDD formula from `cum`; must never walk the path by repeated float subtraction; must bound the segment walk with `k + 2 < n`; must declare no setter on a packed-array property.
- Must never connect Combat's or EnemyWave's gameplay signals deferred (ADR-0006).
- Test fakes that subclass `Combat` or `EnemyWave` must keep the typed signatures and return a typed value on every path (4.7 rule).

## Alternatives Considered

### Alternative 1: Enemy as a Node2D

- **Description**: Each enemy is a scene node; Combat targets nodes; views are the nodes.
- **Pros**: Familiar Godot pattern; drawing comes free.
- **Cons**: A freed node cannot honour `removed`; the built-in `position` collides with the cached sim position; the sim would need a scene tree, breaking headless runs and the scene-free Builder (ADR-0001).
- **Estimated Effort**: Similar at first, more later (headless harness workarounds).
- **Rejection Reason**: Violates TR-combat-002 and the B0 rule that sim classes extend `RefCounted`.

### Alternative 2: Combat keeps Health and Status in its own dictionaries keyed by spawn_id

- **Description**: Targetable has no `health` or `status`; Combat maps `spawn_id` to each.
- **Pros**: Targetable is lighter; Combat's state is private by construction.
- **Cons**: A hash lookup on every `is_dead` and range check (about 340 per tick); Combat would need a removal call or it would keep every dead enemy's state for the battle; two owners of one enemy's lifetime.
- **Estimated Effort**: Slightly more (removal path, extra tests).
- **Rejection Reason**: Slower on the hot path and splits lifetime ownership. One-way fields on the Targetable give the same isolation with no lookup.

### Alternative 3: Health and Status point back at their Targetable

- **Description**: Each piece holds its owner (strongly, or through `weakref()`).
- **Pros**: A Status could name its enemy in a log.
- **Cons**: A strong back-reference is a RefCounted cycle that never frees (ADR-0001). A `weakref()` costs a `get_ref()` per use and nothing needs the back link.
- **Estimated Effort**: Same.
- **Rejection Reason**: No use for it, and the strong form is forbidden.

### Alternative 4: HP and slow as plain fields on Targetable

- **Description**: `hp`, `max_hp`, `slow_strength`, `slow_ticks` live on Targetable; no Health or Status objects.
- **Pros**: Two fewer allocations per spawn; one fewer indirection.
- **Cons**: Departs from the GDD's three pieces (TR-combat-001) and blurs which fields are Combat's.
- **Estimated Effort**: Slightly less.
- **Rejection Reason**: At most 48 alive and about 34 spawns per wave, the allocation saving is negligible; the GDD's shape and the clear ownership win. A later ADR may fold them if V4 shows a need.

### Alternative 5: Vector2 sim positions (the GDD's and B6's signatures)

- **Description**: `Targetable.position: Vector2`; helpers take `origin: Vector2`.
- **Pros**: Matches the GDD text; shorter signatures; `Vector2` methods available.
- **Cons**: If components are 32-bit (V1, expected), every cached position is rounded while path data, distance and range are 64-bit, so inclusive edge tests can differ from a 64-bit reference; inconsistent with ADR-0002 and PinGeometry.
- **Estimated Effort**: Slightly less code.
- **Rejection Reason**: Keeps an unverified precision question inside every range test. Scalars cost a few extra parameters.

### Alternative 6: roster() and targets() return copies

- **Description**: Each call returns `duplicate()` of the buffer, so callers cannot corrupt it.
- **Pros**: Read-only enforced by construction.
- **Cons**: An allocation per call (about seven per tick, one per view per frame); whether `duplicate()` keeps the array's element type is not in the pinned reference.
- **Estimated Effort**: Same.
- **Rejection Reason**: Allocation on the hot path plus an unsourced typing behaviour, against a rule that code review and the helpers' no-mutation tests already cover.

### Alternative 7: Untyped or duck-typed lists (`Array`, `Object`)

- **Description**: Helpers take `Array` and read fields by dynamic lookup.
- **Pros**: No variance concerns.
- **Cons**: Field access is unchecked at parse time; a misspelt field is a runtime error.
- **Estimated Effort**: Same.
- **Rejection Reason**: `architecture.md` rule 5 and `deprecated-apis.md` (typed arrays preferred).

## Consequences

### Positive

- Combat is testable alone with factory Targetables, no scene and no catalogue.
- No reference cycle exists in the enemy graph, so a reaped enemy and a retried battle free (V5).
- Range tests are exact on 64-bit values, with no dependency on `Vector2`'s precision.
- Every list is parse-checked; every write has one named owner.
- One add-enemy step leaves room for splitters with no new fields.

### Negative

- Helper signatures differ from the Combat GDD (`origin_x`, `origin_y` instead of `origin`); the GDD needs a sync edit.
- Read-only lists are a rule, not a guarantee; a careless caller can corrupt the roster until the lint exists.
- Field write ownership is enforced by review and a future lint, not by the language.
- Combat's guard messages are not recorded in `DevErrorSink` and may be silent in a release export (ADR-0001 V4). Accepted because each guarded call changes nothing and the one release-relevant case (bad `max_hp`) is escalated to `fatal`.
- The whole tick, not targeting alone, must fit `4.0 / MAX_TICKS_PER_FRAME` ms, so the GDD's 2 ms targeting ceiling cannot be spent in full (Decision 9).
- One allocation per hit (`DamageEvent`) and per splash or burst (`all_in_radius`).

### Neutral

- `distance` moves from `Enemy` to `Targetable`; `architecture.md` B0 changes.
- Combat uses `push_error` directly rather than the `dev_error` sink, under a scoped exception to ADR-0001 Decision 4; EnemyWave uses the sink.
- A new `FieldBounds` constant class appears in Foundation.

## Risks

- **Typed-array variance or Callable return typing behaves differently on 4.7.2 (V2).** Mitigation: V2 runs before the first EnemyWave story; if (d) fails, callers assign `targets.call()` to an untyped `Array` and cast elements, which keeps behaviour and costs parse checks.
- **A caller mutates `targets()` and corrupts the roster.** Mitigation: the size check at the start of `advance()` and `reap()` (Decision 7), helper no-mutation tests (Combat Acceptance 10), an EnemyWave test that compares `roster()` against a snapshot after a full tick with real callers, and an ADR-0007 lint candidate for mutating calls on these returns.
- **Budget exceeded on a low-end phone (V4).** Mitigation: ADR-0004 lowers the clamp first; bucketing inside the helpers second, with identical results proven against the scan; reusing per-hit allocations third.
- **Combat's guard messages are silent in release (ADR-0001 V4).** Mitigation: each guarded call changes nothing; the guards catch caller bugs that CI tests exercise in debug runs; bad `max_hp` goes to `fatal`.
- **Cyclic `class_name` references fail to parse (V6).** Mitigation: `SourceKind` moves to a `CombatTypes` constants script, with no other change.
- **A test fake forgets `super(...)` (V7).** Mitigation: the guideline, plus the first fake's story proves the error appears.
- **A listener stores a `DamageEvent` and keeps a removed enemy alive.** Not a cycle, so it frees with the battle, but it breaks the reap weakref check. Mitigation: the V5 test runs with the real Combat view attached once views exist.
- **Short global class names collide (`Health`, `Status`, QQ-16).** Mitigation: ADR-0007's collision lint or prefix; names here are provisional.
- **NaN slips past the amount guard (V3).** Mitigation: Acceptance 2 and 7 test NaN, INF and -INF directly.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-001: three pieces (DamageEvent, one Health and one Status per enemy); no ProjectileSpawner | Decisions 3 and 4 define the three classes; Decision 8 ratifies the cut and places any future spawner in front of `deliver` |
| combat-damage.md | TR-combat-002: enemy exposes `spawn_id`, cached `distance` and position, `removed`; stays valid after removal; not a freed Node | Decision 1 (`Targetable` fields, `RefCounted`, never freed by the sim); Decision 2 (position as `pos_x`, `pos_y`) |
| combat-damage.md | TR-combat-003: every HP change through `deliver` inside a tick, `min(amount, hp)` after guards in fixed order with named `push_error` codes | Decision 5 (order removed, amount, dead; `ERR_*` constants; commit then emit) |
| combat-damage.md | TR-combat-004: death immediate at HP 0; dead not targetable; reap removes the corpse and emits `enemy_killed(bounty)` once | Decision 5 (`is_dead` at `hp <= 0`; dead silent); Decision 6 (helpers skip the dead); Decision 7 (reap removes before emit, once per enemy) |
| combat-damage.md | TR-combat-005: `dealt_by_id`, `dealt_by_kind`, `dealt_total`, `hero_share`, readable until the battle is destroyed | Decision 4 (counters on Combat, owned by Battle); Key Interfaces (total as the sum of kind sums) |
| combat-damage.md | TR-combat-006: slow is per-instance whole-tick countdown with replace, equal and ignore rules; movement multiplies `move_speed` by `speed_factor` | Decision 3 (`Status`); Decision 5 (`apply_slow`, `tick_status`, `speed_factor`); Decision 7 (move step) |
| combat-damage.md | TR-combat-007: Combat reads no catalogue; only dependency is `to_ticks` | Decision 4 (`Combat.new(to_ticks)`; no accessor, no `halted`, `push_error` direct) |
| combat-damage.md | TR-combat-008: pure helpers with inclusive squared-distance test, lowest `spawn_id` tie-break, never mutate input | Decision 6 |
| combat-damage.md | TR-combat-013: about 400 range checks per tick under 2 ms at the clamp on a low-end phone (unmeasured) | Decision 9 (linear scan; the 2 ms is a ceiling inside the whole-tick budget `4.0 / MAX_TICKS_PER_FRAME`; fallback levers); V4 measures the whole tick |
| enemy-wave.md | TR-enemy-008: roster solely owns enemies; read-only `roster()` and `targets()` in `spawn_id` order; no back-references, so retry frees | Decision 7 (buffers, contexts, removal); Decisions 1 and 3 (no back-references); V5 |
| enemy-wave.md | TR-enemy-009: how Health and Status attach to an enemy | Decision 3 (`Combat.attach`, one-way fields); Decision 7 step 4 |
| enemy-wave.md | TR-enemy-010: position from distance via a cached cumulative-length array, crossing several segments per step, clamped to the end | Decision 7 (`PathTrack.place`, `cum`, segment hint, clamp) |
| enemy-wave.md | TR-enemy-011: targetable only while the centre is inside the 540x960 field, a defined constant or injected value | Decision 7 (`FieldBounds` constants injected as `field_w`, `field_h`; inclusive edges; `_targets` rebuilt after the move) |
| enemy-wave.md | TR-enemy-013: one add-enemy step for schedule spawns and future splitter children, joining before the clear check | Decision 7 (`add_enemy(def_id, start_distance)`, public for tests, sim caller EnemyWave only; append before the reap's clear check) |
| tower-system.md | TR-tower-007: targeting and damage only through Combat's API; splash victims only from `targets()` | Decision 6 (`first_in`, `all_in_radius` over `targets()`; caller-built unslowed buffer); Implementation Guidelines |
| hero-system.md | TR-hero-007: `deliver` with HERO and BURST kinds, `report_attack` before `deliver`, `nearest_in`, `all_in_radius`, `is_dead`, `hp_left` over `targets()` | Decision 4 (`SourceKind`); Decisions 5 and 6; Implementation Guidelines (report before deliver) |

## Performance Implications

- **CPU**: Per tick, about 340 range checks at the worst case (each two subtracts, two multiplies, an add and a compare on `float`), one `_targets` rebuild (at most 48 appends after a `clear()`), one `MOVE_SPEED` read and one `PathTrack.place` per enemy. Plus one `DamageEvent` per victim and one result array per splash or burst. The whole tick must fit `4.0 / MAX_TICKS_PER_FRAME` ms (Data Flow 10); targeting's share is recorded against the GDD's 2 ms ceiling. All unmeasured (V4).
- **Memory**: Per alive enemy, four `RefCounted` objects (Enemy, Health, Status, ReadContext) plus one `Dictionary` entry. At most 48 alive (`peak_alive_ub`). Per hit, one short-lived `DamageEvent`; per splash or burst, one result array.
- **Load Time**: `PathTrack` computes `cum` once per battle build, over a handful of points. Negligible.
- **Network**: None.

## Migration Plan

No code exists, so nothing migrates. The documentation edits are listed in the cascade notes for the parent session: `architecture.md` B0 (`Targetable` fields, `Enemy` row, new `Health`, `Status`, `PathTrack`, `FieldBounds` rows), B6 (scalar helper signatures, `attach`, `ERR_BAD_MAX_HP`, `ERR_ALREADY_ATTACHED`), B7 (`advance()` without argument, `add_enemy`, `WaveState`, `wave_tick`, constructor), Module Ownership (Combat and EnemyWave rows, Combat's Consumes cell), dependency rule 5, QQ-05 and QQ-08; sync edits to `combat-damage.md` (Rules 3, 10, 11, the in_radius variables, the Cross-References row, the ADR hand-off), `enemy-wave.md` (Rule 14, the stories note, the ADR hand-off, the seam list) and `hero-system.md` (tick steps 3 and 7); a one-line note on ADR-0001's release-check guideline; and the registry supersede of `release_relevant_checks`.

**Rollback plan**: If V2 fails, assign Callable returns to untyped `Array` at call sites and cast elements; the helpers keep their typed parameters. If V6 shows a cyclic-reference error, move `SourceKind` into `CombatTypes`. If V5 shows a leak, find the holder with weakref probes before any further EnemyWave story; the one-way design itself has no cycle to remove. If a later ADR allows `Vector2` sim positions after V1, replace the scalar pairs field by field; no other decision here depends on the scalar form.

## Validation Criteria

1. Every Combat acceptance criterion (1 to 18) passes headless with factory Targetables, with the invariant `I` checked after each test.
2. Every Enemy & Wave acceptance criterion that names roster, `targets()`, positions, leaks, reaps or the add-enemy step passes with a fake Combat.
3. V1, V2, V3, V5, V6 and V7 each have a recorded result in this ADR and in the engine reference before acceptance, V4 after it (Status), and the user has answered every item in "Choices pending user confirmation".
4. A weakref test: after a reap and the test dropping its own references, the reaped Enemy, its Health, Status and ReadContext read null; after retry, every enemy of the old battle reads null.
5. A test that runs a full tick with real TowerSim and HeroSim callers and compares `roster()` and `targets()` against a snapshot of size and `spawn_id` order taken before the attack steps.
6. A test that `deliver` on a removed, dead or bad-amount target leaves counters, HP and the signal log unchanged, that `attach` with 0, -1, NaN or INF returns false with `ERR_BAD_MAX_HP` and a second `attach` returns false with `ERR_ALREADY_ATTACHED`, that `apply_slow` with NaN strength or NaN seconds reports `ERR_BAD_SLOW`, and that `PathTrack.make` returns null for an odd count, one point, a repeated point and a non-finite coordinate.
7. A path test: a step that crosses two segments lands on the GDD formula's point; `d >= path_length` lands on the last point; the starter stage at `d` 720 gives (370, 400).
8. A grep (later the ADR-0007 lint) finds no `Vector2` field on `Targetable`, `Enemy` or `PathTrack`, no `Enemy` name under `src/core/`, and no assignment to Combat-owned fields outside `src/core/combat/`.
9. V4's device run records the whole-tick cost at the worst case, and the helpers' share against the GDD's 2 ms ceiling; ADR-0004 records the `MAX_TICKS_PER_FRAME` it sets from it.
10. Loop tests: a kill listener calling `add_enemy` during the reap (Acceptance 28), two adjacent leakers on one tick, and a spy latching on the second member's `max_hp` read (Acceptance 19: nothing later spawns or moves).
11. An ownership-check test: a caller that appends to `targets()` causes `dev_error` at the next `advance()`.

## Related

- Depends on: ADR-0001 (App Lifecycle, Composition Root and Fatal Path), ADR-0005 (Stat Accessor and Read-Context Contract). Uses ADR-0002's record classes and geometry encoding.
- Defers to: ADR-0004 (tick order, float policy, `MAX_TICKS_PER_FRAME`), ADR-0006 (signal payload ID types, QQ-04; signal names, QQ-07), ADR-0007 (lint rules, class-name collisions).
- Amended by: ADR-0006 Decision 4 (`damage_applied` carries `source_kind` and `source_id` instead of the `DamageEvent`; registry `listener_stores_damage_event` superseded by `sim_object_in_signal_payload`) and Decision 3 (`waves_complete` renamed `waves_completed`).
- Enables: ADR-0010, ADR-0011.
- Amends: `architecture.md` B0, B6, B7, Module Ownership; ADR-0001 Decision 4 (scoped exception for Combat's guard codes) and the registry's `release_relevant_checks`; closes QQ-08's ProjectileSpawner and stage-record items on acceptance; answers QQ-05 for sim positions.
- Design: `design/gdd/combat-damage.md` (Core Rules, Formulas, Acceptance Criteria), `design/gdd/enemy-wave.md` (Rules 2, 4, 8 to 15, Formulas), `design/gdd/tower-system.md` (Rules 9, 13), `design/gdd/hero-system.md` (Rule 8, attack steps).
- Code (once implemented): `src/core/combat/`, `src/feature/enemy_wave/`, `src/foundation/field_bounds.gd`.
