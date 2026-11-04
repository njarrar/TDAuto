# ADR-0009: Enemy Entity, Roster and Combat API

## Status
Proposed

## Date
2026-11-04

## Last Verified
2026-11-04 (against Godot 4.7.2 probe results of 2026-11-04, `architecture.md` v5, `tr-registry.yaml` v6 and the eight Accepted ADRs with their amendments)

## Decision Makers
Author: `/architecture-decision`, autonomous mode (decisions logged in `production/session-logs/decision-log.md`). Acceptance: the user. Reviews still owed: godot-specialist and TD-ADR (see Reviews).

## Summary
Combat (Core) must act on enemies that Enemy & Wave (Feature) owns, with no upward dependency, no back-reference that would stop a retry from freeing the battle, and a tick that fits ADR-0004's 2.0 ms p95. This ADR fixes a Core base class `Targetable` (plain `float` position), small `Health` and `Status` objects that only `Combat.attach` and `deliver` write, a roster held only by `EnemyWave` as `Array[Targetable]`, the full Combat API with its guards and counters, a plain-value `damage_applied` payload, and a per-tick budget split with a targeting bench.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Core (GDScript data model, simulation maths) |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM. The code is plain GDScript on `RefCounted`, typed `Array`, `Dictionary`, `StringName`, `float` and `Signal`, all stable since 4.0. The risk sits in typed-array behaviour, typed loop variables and cost on a phone core, which training data does not cover for 4.7 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (scan), `probe-results.md` (ADR-0001 V1a to V1f, V6b; ADR-0002 KEY; ADR-0004 E1, E2; ADR-0005 E4, E6; ADR-0006 E1 to E3; ADR-0008 R3, R6). No `modules/` file covers this domain |
| **Post-Cutoff APIs Used** | None. 4.7's typed-return override rule applies to any override here (ADR-0007 R1) |
| **Verification Required** | Probes B1 to B4 (Validation Criteria), headless, before the first Combat story closes: B1 an `Array[Enemy]` passed to an `Array[Targetable]` parameter is refused and an `Enemy` appends to an `Array[Targetable]`; B2 `for t: Targetable in list` parses and runs; B3 an `Array[Targetable]` returned through `Callable.call()` keeps its type (`is_typed()`, `get_typed_script()`); B4 `Combat` and `DamageEvent` naming each other parse under `godot-parse-check.gd`. Bench P2 on desktop with the first Combat story; device run with ADR-0004 V13 |

Verified facts used (`probe-results.md`): Callables and connections are weak, `bind()` and lambdas strong (V1); `Vector2` is 32-bit (E2); `roundi` halves away from zero (E1); `WeakRef` reads null at once (E4); `emit()` checks no types and `String` converts silently to `StringName` (E2a, E3); a bad `int` passes a typed enum parameter (R6).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Battle members, no back-reference, weakref retry proof, method Callables), ADR-0002 (Stage record geometry), ADR-0004 (tick order, `to_ticks`, float policy, sim budget), ADR-0005 (`ReadContext` per enemy, `max_hp` seed exception), ADR-0006 (signal roles, typed payloads, ID types, result snapshot), ADR-0007 (fakes, error claims, lints, `combat_invariant.gd`). All Accepted 2026-11-04 |
| **Enables** | ADR-0010 (TowerSim and HeroSim call this API; its command contract uses `targets()`), ADR-0011 (views draw from `roster()`, `x`, `y`, `attack_fired`, `damage_applied`; decides the hit-flash question, QQ-10) |
| **Blocks** | Every Combat & Damage and Enemy & Wave story (Combat GDD Dependencies: "Prerequisite"), and the Tower and Hero attack stories. No epic or story exists yet, so none is blocked by path today |
| **Ordering Note** | Accept before ADR-0010. On acceptance, ADR-0006 Decision 4's `damage_applied` row and ADR-0007's lint table take the dated amendments listed in Migration Plan items 3 and 4 |

## Context

### Problem Statement
Tower and Hero name a victim and an amount, Enemy & Wave owns and moves the enemies, and Combat owns HP, slows and counters. The Combat GDD makes this ADR the prerequisite for its first story (object kind, attachment, spawn call, ownership, `list` typing, where `SourceKind` and `DamageEvent` live). ADR-0004 left `advance`'s argument here, ADR-0006 the `damage_applied` payload, the 2026-11-04 review the tick share, and QQ-08 two parts: the ProjectileSpawner cut and the stage geometry.

### Constraints
- **Layers** (rule 5): Core cannot name a Feature class; typed arrays are invariant.
- **ADR-0001**: no sim holds `Battle`, `AppRoot` or a `Node`; method Callables only; retry proved by weakrefs.
- **ADR-0004**: six-step tick; `halted()` after every read, injected call and emit; `int` countdowns; scalar maths (L-VEC-1); 2.0 ms p95 per tick.
- **ADR-0005**: one reused `ReadContext` per `Enemy`, weak live entity; `max_hp` seeds Health once.
- **ADR-0006**: sync emit, commit then emit; Combat's signals are VIEW; `StringName` and `int` IDs.
- **ADR-0007**: `push_error` claimed by `is_push_error(MSG)`; invariant `I` reads this ADR's queries.
- **Team**: one part-time developer. Few classes, no framework.

### Requirements
- The 17 TRs below; retry frees every enemy with no extra unwire; no hot-path allocation but `all_in_radius`; targeting (about 480 checks) fits a named share of the 2.0 ms tick.

## Decision

### 1. Object kinds and files
| Class | Base | File | Holds | Written by |
|---|---|---|---|---|
| `Targetable` | `RefCounted` | `src/core/combat/targetable.gd` | `spawn_id: int`, `distance: float`, `x: float`, `y: float`, `removed: bool`, `health: Health`, `status: Status` | `spawn_id`, `distance`, `x`, `y`, `removed`: EnemyWave only. `health`, `status`: `Combat.attach` only |
| `Health` | `RefCounted` | `src/core/combat/health.gd` | `hp: float`, `max_hp: float` (seed, kept for invariant `I`) | Combat only |
| `Status` | `RefCounted` | `src/core/combat/status.gd` | `slow_strength: float` (0.0 when empty), `slow_ticks: int` | Combat only |
| `DamageEvent` | `RefCounted` | `src/core/combat/damage_event.gd` | `target: Targetable`, `amount: float`, `source_kind: Combat.SourceKind`, `source_id: StringName` | Its caller |
| `Combat` | `RefCounted` | `src/core/combat/combat.gd` | `enum SourceKind { TOWER, HERO, BURST }`, the counters, two injected Callables | Itself |
| `Enemy` | `Targetable` | `src/feature/enemy_wave/enemy.gd` | Adds `def_id: StringName`, `ctx: ReadContext`, `seg: int` (path segment hint) | EnemyWave only |
| `PathTable` | `RefCounted` | `src/feature/enemy_wave/path_table.gd` | `px`, `py`, `cum`: `PackedFloat64Array`; `length: float` | Built once by EnemyWave |
| `EnemyWave` | `RefCounted` | `src/feature/enemy_wave/enemy_wave.gd` | Roster, targets buffer, wave state, `spawn_id` counter, `wave_index`, got-through counts | Itself |

- **`RefCounted`, not `Node`**: a freed `Node` cannot honour `removed`, and `Node2D.position` collides (TR-combat-002).
- **`x` and `y`, not `position: Vector2`**: `Vector2` is 32-bit (E2). `float` fields stay 64-bit, keep edge tests exact and avoid a copy per read. Signals build `Vector2(t.x, t.y)`, which is storage.
- **`distance` on `Targetable`**: `first_in` ranks by it, and Core cannot read a Feature field (moved from B0's `Enemy` row).
- `Enemy._init(p_spawn_id: int, p_def_id: StringName)` sets both and makes `ctx = ReadContext.new(p_def_id, 0, self)`, the case ADR-0005 V6(b) covers.

### 2. Attachment: `Combat.attach`
- `attach(target: Targetable, max_hp: float) -> bool` makes one `Health` (`hp = max_hp`, `max_hp = max_hp`) and one `Status` (empty) and sets `target.health` and `target.status`. It is the one spawn registration call.
- Guards, in order, each a `push_error` with a named constant and `false` returned, nothing changed: null target (`ERR_NO_TARGET`); already attached (`ERR_ATTACHED_TWICE`); `max_hp` not finite or not above 0 (`ERR_BAD_MAX_HP`).
- EnemyWave's add-enemy step reads `max_hp` through the accessor with the enemy's context, checks `halted()`, calls `attach`, and on `false` calls `fatal("enemy_attach_failed")` and returns. The Data validator already bounds `max_hp` above 0, so this branch guards a caller bug.
- Nothing outside `src/core/combat/` reads `.health` or `.status` in `src/`. Callers use `hp_left`, `is_dead` and `speed_factor`. Tests may read `health.max_hp` for invariant `I`.

### 3. Roster and lists (TR-enemy-008, TR-enemy-011, TR-enemy-013)
- EnemyWave is the sole owner. It holds `_roster: Array[Targetable]` and `_targets: Array[Targetable]`, both made once at build and reused.
- `roster()` returns `_roster`: every enemy not yet removed, corpses awaiting the reap included, in ascending `spawn_id`. `targets()` returns `_targets`: the roster members whose centre lies in the field, `0.0 <= x <= FIELD_MAX_X` and `0.0 <= y <= FIELD_MAX_Y`, edges included. `FIELD_MAX_X: float = 540.0` and `FIELD_MAX_Y: float = 960.0` are constants on `EnemyWave`; a test checks them against ADR-0003's viewport size.
- Both return the internal array, never a copy. They are read-only by contract and never kept past the reader's slot (ADR-0006 Decision 3). This keeps the hot path free of allocation.
- `_targets` is rebuilt once per tick at the end of the advance slot, after the leak loop. The reap removes each corpse from both arrays, so between ticks neither holds a removed enemy.
- **Removal is `remove_at`, one enemy at a time, then the emit.** The lists are whole at every emit, so a listener that reads `roster()` sees committed state. At 48 enemies the O(n) shift is cheap.
- EnemyWave casts with `var e := t as Enemy` where it needs `def_id`, `ctx` or `seg`. Combat never casts.
- **One add-enemy step**, `_add_enemy(def_id: StringName, start_distance: float) -> Enemy`: next `spawn_id`, `Enemy.new`, `max_hp` read, `halted()` check, `attach`, append to `_roster`. The schedule calls it in the advance slot. Splitter children at Vertical Slice call it from the reap slot before the clear check, so they join atomically with new `spawn_id`s and no new fields. Since `spawn_id` only rises, appending keeps the roster in order.

### 4. Path lookup (TR-enemy-010) and stage geometry (QQ-08)
- `path_points`, `slot_positions` and `path_width` stay on the Stage record as ADR-0002 stores them (`Array[Vector2]`, read-only). The stage scene keeps only the look. This settles QQ-08's stage-geometry part, pending the user's acceptance.
- EnemyWave builds one `PathTable` at build from `path_points`: `px[k]`, `py[k]`, `cum[k]` (length before point `k`) as 64-bit scalars, and `length`. Segment lengths use `sqrt(dx * dx + dy * dy)` on scalars. Points are integers in the starter data, so the 32-bit source loses nothing (E2; exact below 2^24, R3b).
- Position: from the enemy's `seg` hint, step `seg` forward while `seg + 1 < last` and `distance >= cum[seg + 1]`, so one move can cross several segments; then `x = px[seg] + (distance - cum[seg]) / (cum[seg + 1] - cum[seg]) * (px[seg + 1] - px[seg])`, and the same for `y`. Once `distance >= length`, the enemy sits at the last point. Each component is written apart (L-VEC-1). `distance` accumulates as a scalar; `x` and `y` are rebuilt each tick, so no rounding builds up.
- `d_next = distance + move_speed * speed_factor * dt`, with `move_speed` read through the accessor each tick and `dt` the injected plain `float` (ADR-0004 Decision 2).

### 5. Combat API (TR-combat-001 to 008)
- **Object and owner**: `Battle.combat`, built in ADR-0001 step (d) as `Combat.new(to_ticks, dev_error)`, with method Callables `TickMath.to_ticks` and `DevErrorSink.report`. **Combat gets no `dt`**: it stores slow time as `max(1, to_ticks(seconds))` and needs nothing else. ADR-0004's `dt` list (Flow, EnemyWave, HeroSim) stands; the Module Ownership row that adds `dt` to Combat is wrong (sync item).
- **Injection**: the Builder passes `battle.combat` as an object into EnemyWave, TowerSim and HeroSim, as ADR-0005 does for the accessor. Combat holds nothing that points at a sim, so the graph stays acyclic.
- **`deliver(event: DamageEvent) -> float`**, inside a tick only (caller discipline, ADR-0004 Decision 6). Guards in this fixed order; only the first failure reports, and each returns 0.0 with nothing changed and nothing emitted:
  1. `event` null, `event.target` null, or `target.health` null: `ERR_NO_TARGET`.
  2. `target.removed`: `ERR_REMOVED`.
  3. `amount` not finite or below 0: `ERR_BAD_AMOUNT`. `source_kind` outside `SourceKind` (a typed enum parameter takes any `int`, R6): `ERR_BAD_KIND`.
  4. `hp <= 0.0` (dead): silent.
  5. `applied = min(amount, hp)`. If `applied` is 0.0, return 0.0 with no emit.
  6. Commit: `hp -= applied`; `_dealt_by_id[source_id] += applied`; `_dealt_by_kind[source_kind] += applied`. Then emit `damage_applied`, then return `applied`.
- **`apply_slow(enemy: Targetable, strength: float, seconds: float) -> void`**. Guards: null or unattached (`ERR_NO_TARGET`); removed (`ERR_REMOVED`); `strength` not in the open interval (0, 1), or `seconds` not finite or not above 0 (`ERR_BAD_SLOW`); dead (silent). Then `ticks = max(1, to_ticks(seconds))`. Empty slot or stronger: replace both. Equal: `slow_ticks = max(slow_ticks, ticks)`. Weaker: ignore. Strengths compare exactly.
- **`speed_factor(enemy) -> float`**: `1.0 - slow_strength` when `slow_ticks > 0`, else `1.0`.
- **`tick_status(roster: Array[Targetable]) -> void`**: for each enemy with `slow_ticks > 0`, subtract 1; at or below 0, empty the slot (`slow_strength = 0.0`, `slow_ticks = 0`). Emits nothing. Removed enemies never reach it.
- **`is_dead(enemy) -> bool`**: `hp <= 0.0`, still true after the reap; a leaked enemy is removed but not dead. **`hp_left(enemy) -> float`**: `hp`, read-only.
- **Helpers** over a caller's list. Each checks `max_range` or `radius` first (not finite or below 0: `ERR_BAD_RANGE`, then null or empty), reads `origin.x`, `origin.y` once, and compares `dx * dx + dy * dy <= r * r` against the cached `x`, `y` (inclusive). They skip the dead, scan without sorting, never mutate the list, and break ties by lowest `spawn_id`:
  - `first_in(list, origin, max_range) -> Targetable`: greatest `distance` in range, else null.
  - `nearest_in(list, origin, max_range) -> Targetable`: smallest squared distance in range, else null.
  - `all_in_radius(list, impact, radius) -> Array[Targetable]`: every one in range, in input order (so ascending `spawn_id` from `targets()`). The only allocation on the attack path.
  - The slow tower's "first unslowed, then all" (Tower Rule 9) filters into a scratch `Array[Targetable]` that TowerSim owns and clears, then calls `first_in` twice at most.
- **`report_attack(source_kind, source_id, origin: Vector2, impact: Vector2, radius: float) -> void`**: checks the kind (`ERR_BAD_KIND`, no emit), then emits `attack_fired` with the same five arguments. Callers call it before their `deliver` calls.
- **`DamageEvent` reuse**: TowerSim and HeroSim each own one `DamageEvent`, set its fields per victim and call `deliver`. Combat never keeps it. After an attack's last `deliver`, the caller sets `event.target = null`, so no attacker holds an enemy across ticks (Combat Rule 10).
- **Halting**: Combat holds no `halted()`. It reads no stat and calls no fatal, and its listeners are VIEW-only, so nothing in a Combat call can latch. TowerSim and HeroSim still check `halted()` after each Combat call that emits, as ADR-0001 Guideline 9 asks of every emit inside a tick.

### 6. Signals (ADR-0006 roles; payload settled here)
```gdscript
signal attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(source_kind: Combat.SourceKind, source_id: StringName, applied: float, hit_position: Vector2, killed: bool, spawn_id: int)
```
- `damage_applied` carries **plain values only**: the `DamageEvent` object and its `Targetable` leave the payload. No view can reach an enemy through it, a reused `DamageEvent` cannot change under a listener, and a `typeof()` fake checks every argument (ADR-0006 Decision 8). `amount` is dropped: views draw what was applied. `killed` reads committed state; `hit_position` is `Vector2(target.x, target.y)` copied before the reap.
- Both stay VIEW, with no sim listener. This replaces ADR-0006 Decision 4's `damage_applied` row, which ADR-0006 left to this ADR ("may replace it with plain values by amending this row"); the amendment is owed on acceptance (Migration item 3).
- The hit-flash shader (QQ-10) is not decided here. The payload already carries what any flash needs (`spawn_id`, `hit_position`, `source_kind`, `killed`), so ADR-0011 can choose primitives or a shader with no Combat change.

### 7. Counters and the result (TR-combat-005, ADR-0006 Decision 9)
- `_dealt_by_id: Dictionary` (`StringName` to `float`) and `_dealt_by_kind: PackedFloat64Array` of size 3, indexed by `SourceKind`. Both change only in step 6 of `deliver`.
- `dealt_by_id(id: StringName) -> float` (0.0 for an unknown ID); `dealt_by_kind(kind: SourceKind) -> float` (0.0 and `ERR_BAD_KIND` out of range); `dealt_total() -> float` is `tower + hero + burst`, summed in that order; `hero_share() -> float` is `(hero + burst) / dealt_total()`, or 0.0 when the total is 0.0.
- Counters stay readable after the outcome until the battle is dropped: `halted()` stops every caller, so nothing changes them.
- `Battle.take_result_snapshot()` fills `damage_towers`, `damage_hero`, `damage_burst` from `dealt_by_kind` and `hero_share` from `hero_share()`, and `got_through` from a deep copy of `enemy_wave.got_through_by_type()`. `slows_applied` stays TowerSim's (Tower Rule 17).

### 8. EnemyWave tick entries and reads (TR-enemy-016)
- **`advance() -> void` takes no argument.** EnemyWave owns `wave_tick` (Enemy & Wave Rule 7); `Battle.tick_count()` counts every gated tick, Intermission included, so it is not wave time. ADR-0004 Decision 5 allowed this ("ADR-0009 may drop it"); the `battle_tick` registry entry already reads `EnemyWave.advance` with no argument.
- `advance()`: spawn members due at `wave_tick`; move every roster enemy (spawned ones too), rebuilding `x`, `y`; leak loop in ascending `spawn_id` (read `lives_cost`, `halted()`, set `removed`, `remove_at`, record got-through by `def_id`, emit `enemy_leaked`, `halted()`); rebuild `_targets`; `wave_tick += 1` while Active.
- `reap() -> void`: for each dead roster enemy in ascending `spawn_id`, read `bounty`, `halted()`, set `removed`, `remove_at` from both lists, emit `enemy_killed`, `halted()`; then the clear check while Active.
- `start_next_wave() -> void`: no argument; commits at `wave_tick` 0 and sets `wave_index` (1-based, 0 before the first start, unchanged by a clear or an outcome).
- `wave_index() -> int` and `got_through_by_type() -> Dictionary` are view-only reads. `got_through_by_type()` returns the internal untyped `Dictionary` (`StringName` to `int`), keyed by enemy `def_id` on first leak, never reset per wave; absent means 0. Readers never write or keep it; the snapshot deep-copies it (ADR-0006 Decision 9). The Builder injects `wave_index` into Flow (B9, unchanged).

### 9. Per-tick budget (TR-combat-013; Conflict 2 of the 2026-11-04 review)
ADR-0004 Decision 7 gives one tick at most 2.0 ms p95 on an Adreno 5xx-class phone at the worst starter wave. This ADR splits that one number, so ADR-0005's reads and Combat's targeting add up inside it:

| Share | Budget (p95, phone) | Worst-case work | Owner of the check |
|---|---|---|---|
| Stat reads, all callers | 0.7 ms | About 90 reads (48 `move_speed`, leak and reap reads, tower and hero attack reads) | ADR-0005 P1 |
| Combat targeting helpers | 0.5 ms | About 480 range checks: 5 towers x 48, one slow tower's second pass 48, two splash results 96, hero 48, burst 48 | This ADR, P2 |
| Combat `deliver`, `tick_status`, `report_attack`, emits with no listener | 0.2 ms | About 60 delivers, 48 status steps | This ADR, P2 |
| EnemyWave move, path lookup, leak and reap (reads excluded) | 0.3 ms | 48 moves, list rebuild | ADR-0004 V13 |
| Flow, Tower and Hero bookkeeping, `halted()` calls | 0.3 ms | | ADR-0004 V13 |
| **Total** | **2.0 ms** | 48 is the `peak_alive_ub` cap and view pool (Enemy & Wave content test) | |

- **Targeting estimate**: a check is about six typed property reads and five float ops. At an assumed 0.3 to 1.0 µs per check on an A53-class core, 480 checks take 0.14 to 0.48 ms. Unmeasured.
- **P2 `bench_targeting`** (desktop, with the first Combat story; logged, not a pass or fail test): 48 attached targets in field, the 480-check mix above plus 60 `deliver` calls and one `tick_status`, warm-up, then 600 ticks timed with `Time.get_ticks_usec()` in the bench only. Reports p95 per tick and ns per check, and records debug or release. **Desktop trigger: above 0.05 ms p95 per tick for the helpers.** On a trigger, apply in order: hoist `origin.x`, `origin.y`, `r * r` and the list size into locals; skip the dead by one `hp` read; then one shared pass per tick that tests each target once against every ready tower's range. If a trigger still fires, this ADR is amended before the first Tower story.
- **ADR-0005 P1 and its `match` fallback fit inside the 0.7 ms share.** At about 90 reads, 0.7 ms allows about 7.8 µs per read on the phone. P1's desktop trigger (0.5 µs per read) sits well under that at ADR-0005 R1's 5 to 15 times phone slowdown, so P1 firing still means "build the `match` fallback now", as ADR-0005 says. If the device run of P1 after the fallback still exceeds 0.7 ms, the excess is not taken from Combat's share: it reopens the split under ADR-0004 Decision 7, which lowers `MAX_TICKS_PER_FRAME` toward 2 by amendment.
- **Catch-up**: at `MAX_TICKS_PER_FRAME = 4` a frame owes at most four ticks, so the 4.0 ms sim slice holds while each tick stays at 2.0 ms. The device run (ADR-0004 V13) measures the whole tick and the shares; the split above is provisional until then.

### 10. Projectiles (QQ-08 ProjectileSpawner part)
- There is no ProjectileSpawner at MVP. Every hit is instant, and attackers pick victims at fire time.
- If projectiles ever come, a spawner is a caller in front of `deliver`, in Core or Feature, that owns flight and calls `deliver` on arrival. `deliver` stays the one HP path and its guards (`removed`, dead) already cover a target that left during flight. Attackers would then hand a pending hit instead of a victim: the Combat GDD accepts that cost. This settles QQ-08's spawner part, pending the user's acceptance.

### Architecture Diagram
```
Battle (RefCounted) holds: flow, combat, enemy_wave, tower_sim, hero_sim, ...
  enemy_wave ──► combat (object)        tower_sim ──► combat     hero_sim ──► combat
  enemy_wave ──► stat_accessor          combat ──► TickMath.to_ticks, DevErrorSink.report
  enemy_wave owns _roster, _targets: Array[Targetable] ──► Enemy (extends Targetable)
       Enemy ──► Health, Status (made by Combat.attach), ReadContext ─ weak ─► Enemy
  tower_sim, hero_sim get targets() as EnemyWave.targets (method Callable)

Tick: Flow.tick ─► EnemyWave.advance() [spawn: attach; move: x, y; leak; _targets]
   ─► Combat.tick_status(roster) ─► TowerSim.tick [first_in, report_attack, deliver, apply_slow]
   ─► HeroSim.tick [nearest_in / all_in_radius, report_attack, deliver]
   ─► EnemyWave.reap() [enemy_killed, clear check]
deliver ─► commit hp and counters ─► damage_applied(plain values) ─► views only
```
Nothing points from an enemy, Health or Status to any sim, and no view payload holds an object, so dropping `Battle` frees the whole graph (ADR-0001 V2).

### Key Interfaces
```gdscript
class_name Targetable extends RefCounted     # src/core/combat/targetable.gd
var spawn_id: int          # battle-wide, never reused; EnemyWave writes
var distance: float        # along the path; EnemyWave writes
var x: float               # cached centre, rebuilt each tick; EnemyWave writes
var y: float
var removed: bool          # true once it left the roster (leak or reap); EnemyWave writes
var health: Health         # Combat.attach only
var status: Status         # Combat.attach only

class_name Health extends RefCounted         # hp: float, max_hp: float; Combat writes
class_name Status extends RefCounted         # slow_strength: float, slow_ticks: int; Combat writes

class_name DamageEvent extends RefCounted    # one reused instance per caller
var target: Targetable
var amount: float
var source_kind: Combat.SourceKind
var source_id: StringName

class_name Combat extends RefCounted         # src/core/combat/combat.gd
enum SourceKind { TOWER, HERO, BURST }
# const String messages: ERR_NO_TARGET, ERR_ATTACHED_TWICE, ERR_BAD_MAX_HP, ERR_REMOVED,
#   ERR_BAD_AMOUNT, ERR_BAD_KIND, ERR_BAD_SLOW, ERR_BAD_RANGE (text is the story's; tests name the constant)
func _init(to_ticks: Callable, dev_error: Callable) -> void
func attach(target: Targetable, max_hp: float) -> bool
func deliver(event: DamageEvent) -> float
func apply_slow(enemy: Targetable, strength: float, seconds: float) -> void
func speed_factor(enemy: Targetable) -> float
func tick_status(roster: Array[Targetable]) -> void
func is_dead(enemy: Targetable) -> bool
func hp_left(enemy: Targetable) -> float
func first_in(list: Array[Targetable], origin: Vector2, max_range: float) -> Targetable
func nearest_in(list: Array[Targetable], origin: Vector2, max_range: float) -> Targetable
func all_in_radius(list: Array[Targetable], impact: Vector2, radius: float) -> Array[Targetable]
func report_attack(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func dealt_by_id(id: StringName) -> float
func dealt_by_kind(kind: SourceKind) -> float
func dealt_total() -> float
func hero_share() -> float
# signals: Decision 6

class_name Enemy extends Targetable          # src/feature/enemy_wave/enemy.gd
var def_id: StringName
var ctx: ReadContext       # made once in _init: ReadContext.new(def_id, 0, self)
var seg: int               # path segment hint
func _init(p_spawn_id: int, p_def_id: StringName) -> void

class_name EnemyWave extends RefCounted      # src/feature/enemy_wave/enemy_wave.gd
const FIELD_MAX_X: float = 540.0
const FIELD_MAX_Y: float = 960.0
func advance() -> void                       # no argument
func reap() -> void
func start_next_wave() -> void
func roster() -> Array[Targetable]           # internal, spawn_id order; do not keep or mutate
func targets() -> Array[Targetable]          # in-field subset, same rules
func wave_index() -> int
func got_through_by_type() -> Dictionary     # StringName -> int; view-only
signal enemy_leaked(lives_cost: int)         # unchanged (ADR-0006)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_completed()
```

### Implementation Guidelines
1. Every HP change must go through `deliver`; only `attach` may create `Health` and `Status`, and only Combat may write them.
2. Code in `src/` outside `src/core/combat/` must never touch `.health` or `.status`; it uses `hp_left`, `is_dead`, `speed_factor`.
3. Only EnemyWave may write `spawn_id`, `distance`, `x`, `y`, `removed`, or hold enemies past a tick slot.
4. Enemy lists must be `Array[Targetable]` from construction; never build an `Array[Enemy]` for Combat.
5. `roster()` and `targets()` results must never be mutated or kept past the reader's slot.
6. A caller must reuse one `DamageEvent`, never one per hit, and null its `target` after the attack's last `deliver`.
7. Callers must call `report_attack` before `deliver`, and check `halted()` after each Combat call that emits.
8. `deliver` must run only inside a tick (Combat Rule 2).
9. Combat must read no catalogue data and hold no sim, `Battle` or `Node`; it gets only `to_ticks` and `dev_error`.
10. Position maths must use `x`, `y` and `PathTable` scalars (L-VEC-1).
11. Removal must be `remove_at` for one enemy, then the emit.
12. Every guard reports one `push_error` through `dev_error` with its named constant; never `assert`.

## Alternatives Considered

### Alternative 1: Flat HP and slow fields on `Targetable`
- **Description / Pros**: `hp`, `max_hp`, `slow_strength`, `slow_ticks` on the base; two fewer objects per spawn, one fewer lookup per check.
- **Cons**: Combat's state sits in a base EnemyWave also writes, so "only Combat writes HP" rests on review alone; drops the GDD's three pieces.
- **Rejection Reason**: the saving is one property read per check, which P2 can still claim by amendment. Clear ownership is worth more now.

### Alternative 2: Combat holds state in a `Dictionary` keyed by `spawn_id`
- **Description / Pros**: Combat looks up HP and slow by ID; enemies carry nothing of Combat's.
- **Cons**: a hash per range check (about 480 a tick), entries to clean up, and a removed enemy's HP must stay answerable for `is_dead`.
- **Rejection Reason**: slower on the hot path, and adds a lifetime to manage.

### Alternative 3: Enemies as `Node2D`
- **Description / Pros**: one node per enemy; views could draw from it.
- **Cons**: a freed node cannot honour `removed`; `position` collides; ADR-0001 bans `Node` in sims; tests need a tree.
- **Rejection Reason**: breaks TR-combat-002 and ADR-0001.

### Alternative 4: No base class, Combat typed on `Object`
- **Description / Pros**: dynamic field lookup; one class fewer.
- **Cons**: no parse-time checks, slower reads, typos fail at run time.
- **Rejection Reason**: architecture rule 5 chose the base class for exactly this.

### Alternative 5: Keep `DamageEvent` in the `damage_applied` payload
- **Description / Pros**: ADR-0006's interim row; one argument, no amendment.
- **Cons**: a view gets a live `Targetable`, a reused event changes under it, a typed fake checks only the class.
- **Rejection Reason**: plain values close a retry leak path and allow event reuse.

### Alternative 6: `advance(tick: int)`
- **Description / Pros**: `Battle.tick` passes `tick_count()`; one clock for logs.
- **Cons**: `tick_count` runs through Intermission, so EnemyWave still keeps `wave_tick`; two counters can disagree.
- **Rejection Reason**: Rule 7 already gives EnemyWave its own wave time.

## Consequences

### Positive
- One guarded HP path keeps hero share honest and invariant `I` true by construction.
- Retry needs no extra teardown: the graph points one way and views get no objects.
- Combat tests need no scene, catalogue or EnemyWave.
- The tick budget has named shares, so each overrun shows on its own line.

### Negative
- Four objects per spawn, about 100 a stage.
- Field ownership rests on lints and review; GDScript has no access control.
- The new payload differs from Combat Rule 12 and ADR-0006's row until synced.
- `all_in_radius` allocates one `Array` per splash or burst.

### Neutral
- `origin` and `impact` stay `Vector2` as the GDD names them; a non-integer caller position rounds to 32-bit, deterministic per CPU (ADR-0004 Decision 9).

## Risks
- **R1 Targeting cost on a phone** (0.14 to 0.48 ms estimated, 0.5 ms share). Mitigation: P2 and its ordered fixes; V13.
- **R2 Typed arrays behave otherwise.** If B3 shows `Callable.call()` drops the type, the Combat call fails. Mitigation: B1 to B3 before the first Combat story; fallback, by amendment, a small Core reader object in place of the Callable.
- **R3 A view keeps a list or an enemy.** It delays frees but forms no cycle (V1). Mitigation: ADR-0006 VIEW rules; V3.
- **R4 Field writes outside the owner.** Mitigation: L-COMBAT-1, L-COMBAT-2.
- **R5 Bad `source_kind`** (any `int` passes, R6). Mitigation: `ERR_BAD_KIND` before indexing.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-001: three pieces (DamageEvent, one Health and one Status per enemy); no ProjectileSpawner | Decisions 1, 2, 10 |
| combat-damage.md | TR-combat-002: enemy exposes `spawn_id`, cached distance and position, `removed`; valid after removal, so not a freed Node | Decision 1 (`RefCounted`, `x`, `y`, `distance` on `Targetable`) |
| combat-damage.md | TR-combat-003: every HP change through `deliver` in a tick, `min(amount, hp)`, guards in fixed order with named codes | Decision 5; Guidelines 1, 8, 13 |
| combat-damage.md | TR-combat-004: death at HP 0; dead not targetable; reap removes and emits `enemy_killed` once | Decisions 5 (helpers skip dead), 8 (`reap`) |
| combat-damage.md | TR-combat-005: `dealt_by_id`, `dealt_by_kind`, `dealt_total`, `hero_share`, readable until destroyed | Decision 7 |
| combat-damage.md | TR-combat-006: slow as whole-tick countdown with replace, equal, ignore; `speed_factor` | Decision 5 |
| combat-damage.md | TR-combat-007: no catalogue; only `to_ticks` with `dt` fixed at build | Decision 5 (injected `to_ticks` and the dev-error sink; no `dt`) |
| combat-damage.md | TR-combat-008: helpers inclusive squared test, lowest `spawn_id` tie, never mutate | Decision 5 |
| combat-damage.md | TR-combat-013: targeting within budget at the catch-up clamp (about 400 checks, under 2 ms) | Decision 9: 0.5 ms share, P2, V13. **Partial**: device proof owed |
| enemy-wave.md | TR-enemy-008: sole roster owner, read-only `roster()` and `targets()` in `spawn_id` order, no back-references | Decisions 3, Architecture Diagram |
| enemy-wave.md | TR-enemy-009: how Health and Status attach | Decision 2 |
| enemy-wave.md | TR-enemy-010: position from distance via cached cumulative lengths, multi-segment, clamped | Decision 4 |
| enemy-wave.md | TR-enemy-011: targetable only inside the 540x960 rectangle, a defined constant | Decision 3 (`FIELD_MAX_X`, `FIELD_MAX_Y`) |
| enemy-wave.md | TR-enemy-013: one add-enemy step for spawns and future splitters, before the clear check | Decision 3 |
| enemy-wave.md | TR-enemy-016: `wave_index()` and `got_through_by_type()` view-only; `wave_index` into Flow | Decision 8 |
| tower-system.md | TR-tower-007: targeting and damage only through Combat; splash victims only from `targets()` | Decision 5; Guideline 1 |
| hero-system.md | TR-hero-007: `deliver` with HERO and BURST, `report_attack` first, `nearest_in`, `all_in_radius`, `is_dead`, `hp_left` over `targets()` | Decision 5; Guideline 7 |

Also settled: QQ-08's ProjectileSpawner and stage-geometry parts (Decisions 4, 10), pending the user's acceptance. QQ-10 is left to ADR-0011 (Decision 6).

## Performance Implications
- **CPU**: 1.0 ms of the 2.0 ms p95 tick is named for this ADR's code (targeting 0.5, Combat writes 0.2, EnemyWave 0.3); stat reads keep 0.7 under ADR-0005 (Decision 9). Unmeasured.
- **Memory**: four small `RefCounted` objects per spawned enemy, freed on reap or leak once no list holds them; at most 48 alive. Two reused lists per battle; one `Dictionary` of counters.
- **Load Time**: one `PathTable` per battle, built from at most a few dozen points.
- **Network**: none.

## Migration Plan
No code exists. Sync items, not edited here:
1. **`architecture.md`**: rule 5 fields (`distance`, `x`, `y`); B0 rows (`Targetable`, `Enemy`, `DamageEvent`; add `Health`, `Status`, `PathTable`); B6 (`attach`, guards, new `damage_applied`); B7 (`advance()`, constants); B9 (`combat` object into the three sims); Module Ownership Combat row (drop `dt`, add `attach`) and EnemyWave row; Data Flow 10 (Decision 9 split); Required ADRs; QQ-08 (both parts settled, pending acceptance); QQ-10 (ADR-0011 only); QQ-11.
2. **GDDs** (game-designer edits, user sign-off): combat-damage.md Rule 12 and Interactions (`damage_applied` payload; views read no `event`), Rule 3 (`ERR_NO_TARGET`, `ERR_BAD_KIND` in the guard order), Rule 11 (`tick_status(roster: Array[Targetable])`), Core Rules "What Combat sees" (`x`, `y` in place of `position`), the `attach` call and `ERR_BAD_RANGE`, the ProjectileSpawner open question; enemy-wave.md Rule 14 (`x`, `y`), Rule 9 position wording, the ADR line after Handed to owning GDDs.
3. **ADR-0006 amendment** (on acceptance): Decision 4's `damage_applied` row becomes Decision 6's plain-value signature; the registry `battle_signal_catalogue` entry follows.
4. **ADR-0007 amendment** (on acceptance): lints L-COMBAT-1 (in `src/` but `core/combat/`: `.health`, `.status`, `Health.new(`, `Status.new(`), L-COMBAT-2 (in `src/` but `feature/enemy_wave/`: assigning `spawn_id`, `distance`, `x`, `y` or `removed` on a `Targetable` or `Enemy` receiver), L-COMBAT-3 (`DamageEvent.new(` outside `tower_sim.gd`, `hero_sim.gd`); `combat_invariant.gd` reads `applied` from the new payload, `dealt_total`, `dealt_by_kind`, `hp_left` and `health.max_hp`; probes B1 to B4 join the probe suite.
5. `requirements-traceability.md`, `tr-registry.yaml`: by `/architecture-review`.

## Validation Criteria
Headless gdUnit4 unless marked; ADR-0007 places them. Fixtures are code-built; no scene, no catalogue for Combat.
- **B1 `probe_typed_array_invariance`**: `Array[Enemy]` into an `Array[Targetable]` parameter is refused; an `Enemy` appends to `Array[Targetable]`; `as Enemy` on a plain `Targetable` is null.
- **B2 `probe_typed_for_variable`**: `for t: Targetable in list` parses and runs.
- **B3 `probe_callable_typed_array_return`**: `targets()` through `Callable.call()` assigns to `Array[Targetable]`; `is_typed()` true.
- **B4 `probe_cyclic_class_refs`**: `Combat` and `DamageEvent` naming each other pass the parse check.
- **V1 `test_combat_*`**: Combat GDD criteria 1 to 18 with `I` after each, plus `attach` guards, `ERR_NO_TARGET`, `ERR_BAD_KIND` (an `int` cast), `ERR_BAD_RANGE` (negative, NaN).
- **V2 `test_damage_applied_payload`**: a `typeof()` fake sees `int`, `StringName`, `float`, `Vector2`, `bool`, `int`; no `Object`.
- **V3 `test_enemy_frees_on_retry`**: extends ADR-0001 V2 with leaks, reaps, enemies frozen at an outcome and a view on `damage_applied`; every enemy, `Health`, `Status` and context weakref reads null.
- **V4 `test_path_table`**: `d` 720 gives (370, 400); a two-segment step lands right; past the end gives the last point.
- **V5 `test_targets_field_rect`**: x 0 and 540, y 0 and 960 are in; 540.5 and -0.5 out; no removed enemy between ticks.
- **V6 `test_roster_order_and_removal`**: ascending `spawn_id`; a listener on `enemy_leaked` or `enemy_killed` sees a whole roster without the removed one.
- **V7 `test_advance_has_no_argument`** and **V8 `test_wave_reads`**: `wave_tick` across an Intermission; `wave_index` 0, then N through wave N; got-through by `def_id`, never reset.
- **P2 `bench_targeting`** (Decision 9) and **ADR-0004 V13** on device.

## Reviews
**Reviews still owed**: godot-specialist (step 5.5) and TD-ADR (step 5.6, `review_mode: full`); this run could not start subagents. For the specialist: B1 to B4, property read cost on `RefCounted` subclasses, `remove_at` at 48 items, `PackedFloat64Array` against `Array[float]`. For TD-ADR: the budget split and P2 trigger, the plain-value payload against ADR-0006, Combat with no `halted()`, `x`, `y` against B0's `Vector2`, the two QQ-08 parts.

**GDD sync** (4 GDDs checked): `damage_applied(event, ...)` becomes plain values (combat-damage Rule 12); enemy `position` becomes `x`, `y` (combat-damage Core Rules, enemy-wave Rule 14); `tick_status(roster: Array)` becomes `Array[Targetable]`; new `attach` and three error constants. Tower and Hero call names are unchanged. Migration item 2; GDDs not edited.

## Related
- Depends on ADR-0001, 0002, 0004, 0005, 0006, 0007; amends ADR-0006 and ADR-0007 on acceptance; enables ADR-0010, ADR-0011.
- `architecture.md` v5 (rule 5, B0, B6, B7, B9, Data Flow 10, QQ-08, QQ-10, QQ-11); `architecture-review-2026-11-04.md` (Blocking 1, Conflict 2, Should-fix 6).
- GDDs: `combat-damage.md`, `enemy-wave.md`, `tower-system.md` (Rules 9, 13), `hero-system.md` (Rules 4, 8, Tick).
