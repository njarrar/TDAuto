# ADR-0009: Enemy Entity, Roster and Combat API

## Status
Proposed

## Date
2026-11-04

## Last Verified
2026-11-04, against `architecture.md` v6, `tr-registry.yaml` v6 (123 entries), the eight Accepted ADRs with their amendments, and probes B1 to B4 and X1 to X7 run on 4.7.2 by the godot-specialist review.

## Decision Makers
Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`). Reviews: godot-specialist and TD-ADR, both CONCERNS, resolved below. Acceptance: the user.

## Summary
Combat (Core) acts on enemies that Enemy & Wave (Feature) owns, with no upward dependency, no back-reference that would stop a retry freeing the battle, and a tick inside ADR-0004's 2.0 ms p95. This ADR fixes a Core base class `Targetable` with plain `float` position, `Health` and `Status` objects that only Combat writes, a roster owned by `EnemyWave` as `Array[Targetable]`, the Combat API with its guards and counters, a plain-value `damage_applied`, and a named per-tick budget split with a targeting bench and a ready-to-build fallback.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Core (GDScript data model, simulation maths) |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM. Plain GDScript on `RefCounted`, typed `Array`, `Dictionary`, `PackedFloat64Array`, `StringName`, `Signal`, all stable since 4.0. The open risk is cost on a phone core |
| **References Consulted** | `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `probe-results.md` (ADR-0001 V1a to V1f; ADR-0002 KEY; ADR-0004 E1, E2; ADR-0005 E4; ADR-0006 E1 to E3; ADR-0007 H4; ADR-0008 R3, R6). No `modules/` file covers this domain |
| **Post-Cutoff APIs Used** | None. 4.7's typed-return override rule applies: `return null` in an `-> int` override fails to parse (H4), so every override returns a real typed value |
| **Verification Required** | B1 to B4 and X1 to X7: verified 4.7.2 headless (desktop debug, 4-core Xeon VM), results below; they join ADR-0007's probe suite. Still open: P2 in a release export, and the device run (ADR-0004 V13) |

| Probe | Result (verified 4.7.2 headless) | Used in |
|---|---|---|
| B1 | `Array[Enemy]` where `Array[Targetable]` is expected fails at parse time when typed; through a `Variant` the callee aborts silently and the caller goes on. `Array[Targetable]` takes an `Enemy`. `as Enemy` on a plain `Targetable` is null | Guideline 3 |
| B2 | `for t: Targetable in list` works | Decision 4 |
| B3 | `Callable.call()` keeps the array type and returns the same instance | Decisions 3, 4 |
| B4 | `Combat` and `DamageEvent` naming each other parse and load; payload types `int`, `StringName`, `float`, `Vector2`, `bool`, `int` | Decision 5 |
| X1 | `+=` on a missing `Dictionary` key errors and aborts | Decision 6 |
| X2 | `var t := max(...)` fails to parse (`inference_on_variant` is an error) | Guideline 6 |
| X3 | `remove_at` on 60 items: about 0.36 µs | Decision 3 |
| X4 | GDScript `float` is 64-bit | Decision 2 |
| X5 | `Enemy`'s typed `_init` works because `Targetable` has none; a subclass `_init()` without `super()` silently skips a base `_init` | Decision 2 |
| X6 | 480 checks a tick: 157 µs p50, 199 µs p95 desktop debug (about 0.33 µs a check); 88 µs p95 with `PackedFloat64Array` data | Decision 8 |
| X7 | `DamageEvent.target` is a strong reference; setting it to null frees the enemy | Decision 4 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0002, ADR-0004, ADR-0005, ADR-0006, ADR-0007 (all Accepted 2026-11-04) |
| **Enables** | ADR-0010 (TowerSim and HeroSim call this API), ADR-0011 (views draw from `roster()`, `attack_fired`, `damage_applied`; decides QQ-10) |
| **Blocks** | Every Combat & Damage and Enemy & Wave story, and the Tower and Hero attack stories. No story exists yet |
| **Ordering Note** | Accept before ADR-0010. At acceptance, ADR-0006 and ADR-0007 take the dated amendments in Migration items 3 and 4 |

## Context

### Problem Statement
Tower and Hero name a victim and an amount, Enemy & Wave owns and moves the enemies, and Combat owns HP, slows and counters. The Combat GDD makes this ADR the prerequisite for its first story (object kind, attachment, spawn call, ownership, `list` typing, where `SourceKind` and `DamageEvent` live). ADR-0004 left `advance`'s argument here, ADR-0006 the `damage_applied` payload, the 2026-11-04 review the tick share, and QQ-08 two parts: the ProjectileSpawner cut and the stage geometry.

### Constraints
- **Layers** (rule 5): Core cannot name a Feature class; typed arrays are invariant (B1).
- **ADR-0001**: no sim holds `Battle`, `AppRoot` or a `Node`; method Callables only; retry proved by weakrefs.
- **ADR-0004**: six-step tick; `halted()` after every read, injected call and emit; `int` countdowns; scalar maths (L-VEC-1); 2.0 ms p95 per tick.
- **ADR-0005**: one reused `ReadContext` per `Enemy`, weak live entity; `max_hp` seeds Health once.
- **ADR-0006**: sync emit, commit then emit; Combat's signals are VIEW; `StringName` and `int` IDs.
- **ADR-0007**: `push_error` claimed by `is_push_error(MSG)`; invariant `I` reads this ADR's queries.

### Requirements
The 17 TRs below; retry frees every enemy with no extra unwire; no hot-path allocation but `all_in_radius`; targeting fits a named share of the 2.0 ms tick.

## Decision

### 1. Object kinds and ownership
Classes and fields are in Key Interfaces. Owners:
- **`Targetable`** (`src/core/combat/`): EnemyWave alone writes `spawn_id`, `distance`, `x`, `y`, `removed`; `Combat.attach` alone sets `health` and `status`.
- **`Health`, `Status`**: Combat alone writes them. Outside `src/core/combat/`, `src/` reads them only through `hp_left`, `is_dead`, `speed_factor`.
- **`DamageEvent`**: its caller. **`Combat`**: `Battle.combat`. **`Enemy`, `PathTable`, `EnemyWave`** (`src/feature/enemy_wave/`): EnemyWave.
- **`RefCounted`, not `Node`**: a freed `Node` cannot honour `removed`, and `Node2D.position` collides (TR-combat-002).
- **`x` and `y` as `float`**: `float` is 64-bit (X4) and `Vector2` 32-bit (E2), so the cached position needs no conversion per read and edge tests stay exact. Signals build `Vector2(t.x, t.y)`, which is storage.
- **`distance` on `Targetable`**: `first_in` ranks by it (moved from B0's `Enemy` row).

### 2. Attachment and construction
- `Combat.attach(target, max_hp) -> bool` makes one `Health` (`hp = max_hp`, `max_hp = max_hp`) and one empty `Status`. Guards, in order, each one `push_error` with `false` and nothing changed: null target (`ERR_NO_TARGET`), already attached (`ERR_ATTACHED_TWICE`), `max_hp` not finite or not above 0 (`ERR_BAD_MAX_HP`).
- EnemyWave's add-enemy step reads `max_hp`, checks `halted()`, calls `attach`, and on `false` calls `fatal("enemy_attach_failed")` and returns. The Data validator already bounds `max_hp` above 0.
- **`Targetable` has no `_init`, and must never gain one.** X5 shows a subclass `_init()` without `super()` skips a base `_init` with no error, so a base constructor could silently not run. `Enemy._init(p_spawn_id, p_def_id)` sets both and makes `ctx = ReadContext.new(p_def_id, 0, self)` (ADR-0005 V6(b)).

### 3. Roster and lists (TR-enemy-008, 011, 013, 016)
- EnemyWave owns `_roster` and `_targets`, both `Array[Targetable]`, made once and reused. `roster()` is every enemy not yet removed, corpses included, in ascending `spawn_id`; `targets()` the in-field subset, `0.0 <= x <= FIELD_MAX_X` (540.0) and `0.0 <= y <= FIELD_MAX_Y` (960.0), edges in. A test checks the constants against ADR-0003's viewport.
- Both return the internal array, and callers get the same instance (B3). They are read-only by contract; `make_read_only()` cannot be used, since EnemyWave writes them. Lint L-COMBAT-4 backs the contract. Never kept past the reader's slot.
- `_targets` is rebuilt at the end of the advance slot, after the leaks. The reap removes each corpse from both lists, so between ticks neither holds a removed enemy.
- Removal is `remove_at` on one enemy (about 0.36 µs at 60 items, X3), then the emit, so every emit sees whole lists.
- One add-enemy step, `_add_enemy(def_id, start_distance) -> Enemy`, serves the schedule (advance slot) and future splitter children (reap slot, before the clear check). `spawn_id` only rises, so appending keeps order.
- `wave_index()` (1-based, 0 before the first start, set when `start_next_wave` commits, unchanged by a clear or outcome) and `got_through_by_type()` (internal untyped `Dictionary`, enemy `def_id` to `int`, keys added on first leak, never reset) are view-only. The snapshot deep-copies the latter.

### 4. Path, stage geometry and EnemyWave entries (TR-enemy-010; QQ-08)
- `path_points`, `slot_positions`, `path_width` stay on the Stage record as ADR-0002 stores them; the scene keeps only the look. **This settles QQ-08's stage-geometry part, pending the user's acceptance.**
- EnemyWave builds one `PathTable` at build: `px`, `py`, `cum` as `PackedFloat64Array`, and `length`. Position is looked up from `distance` and the enemy's `seg` hint, so one step can cross several segments, and clamps to the last point at `length`. Each component is computed apart (L-VEC-1); `x`, `y` are rebuilt each tick, so no rounding builds up.
- The source points are `Vector2` (32-bit). A sync item asks the CI content test to fail a path point that float32 cannot hold exactly; the starter points are integers.
- **`advance() -> void` takes no argument.** EnemyWave owns `wave_tick` (Enemy & Wave Rule 7); `Battle.tick_count()` runs through Intermission, so it is not wave time, and a second counter could disagree. ADR-0004 Decision 5 allowed this. `advance()` spawns, moves (`move_speed` read each tick, times `speed_factor`, times the injected `dt`), runs the leak loop by `spawn_id`, then rebuilds `_targets`. `reap()` handles corpses by `spawn_id`, then the clear check. `start_next_wave()` takes no argument.

### 5. Combat API (TR-combat-001 to 008)
- **Object**: `Combat.new(to_ticks, dev_error)` in ADR-0001 step (d), with method Callables `TickMath.to_ticks` and `DevErrorSink.report`. **No `dt`**: slow time is `maxi(1, to_ticks(seconds))`. ADR-0004's `dt` list stands. **No `halted()`**: this rests on `_init` taking only those two Callables (test V9). Combat reads no stat and calls no fatal, and its listeners are VIEW-only, so no Combat call can latch. Callers check `halted()` after each Combat call that emits, per victim in splash and burst loops; Decision 8 charges those calls to the "other" share.
- **Injection**: the Builder passes `battle.combat` as an object into EnemyWave, TowerSim and HeroSim. Combat holds nothing that points at a sim.
- **`deliver(event) -> float`**, inside a tick only (Combat Rule 2). Guards in fixed order; only the first failure reports, and each returns 0.0 with nothing changed or emitted:
  1. `event`, `event.target` or `target.health` null: `ERR_NO_TARGET`.
  2. `target.removed`: `ERR_REMOVED`.
  3. `amount` not finite or below 0: `ERR_BAD_AMOUNT`.
  4. `source_kind` outside `SourceKind` (any `int` passes a typed enum parameter, R6): `ERR_BAD_KIND`. This runs before the dead check, so a bad kind on a dead enemy reports.
  5. `hp <= 0.0` (dead): silent.
  6. `applied = minf(amount, hp)`; 0.0 returns with no emit.
  7. Commit: `hp -= applied`; `_dealt_by_id[id] = _dealt_by_id.get(id, 0.0) + applied` (a bare `+=` on a missing key aborts, X1); `_dealt_by_kind[kind] += applied`. Emit `damage_applied`; return `applied`.
- **`apply_slow(enemy, strength, seconds)`**: null or unattached (`ERR_NO_TARGET`), removed (`ERR_REMOVED`), `strength` outside the open interval (0, 1) or `seconds` not finite or not above 0 (`ERR_BAD_SLOW`), dead (silent). Then stronger or empty replaces; equal sets `slow_ticks = maxi(slow_ticks, ticks)`; weaker is ignored. Exact compares.
- **`speed_factor`**: `1.0 - slow_strength` while `slow_ticks > 0`, else 1.0. **`tick_status(roster)`**: subtract 1 from each active slot; at or below 0, empty it. Emits nothing. **`is_dead`**: `hp <= 0.0`, true after the reap; a leaked enemy is not dead. **`hp_left`**: `hp`.
- **Helpers** (`first_in`: greatest `distance`; `nearest_in`: smallest squared distance; `all_in_radius`: all in range, in input order). Each checks `max_range` or `radius` first (not finite or below 0: `ERR_BAD_RANGE`), reads `origin.x`, `origin.y` once, and tests `dx * dx + dy * dy <= r * r` on `x`, `y`. They skip the dead, scan without sorting, never mutate, and break ties by lowest `spawn_id`. An empty list gives null or an empty array, silently; V1 records what a null list does on the typed parameter and requires no state change. The slow tower's "unslowed first" filters into a scratch list TowerSim owns.
- **`report_attack`**: checks the kind (`ERR_BAD_KIND`, no emit), then emits `attack_fired`. Callers call it before their `deliver` calls.
- **`DamageEvent` reuse**: TowerSim and HeroSim each own one. The reference is strong (X7), so the caller sets `target = null` at the start of each attack and on every exit, the early `halted()` return included. V1 checks it is null after a halted attack.
- **Counters** (TR-combat-005): `_dealt_by_id` is an untyped `Dictionary` (`StringName` to `float`), as ADR-0006 keeps `got_through` untyped; `String` and `StringName` keys cross on lookup (ADR-0002 KEY) and typed-Dictionary key conversion is unprobed. `_dealt_by_kind` is a `PackedFloat64Array` of size 3. `dealt_by_id` (0.0 for unknown), `dealt_by_kind` (`ERR_BAD_KIND` and 0.0 out of range), `dealt_total` (tower + hero + burst, in that order), `hero_share` (`(hero + burst) / total`, 0.0 when the total is 0.0). Readable until the battle drops. `take_result_snapshot()` fills `damage_towers`, `damage_hero`, `damage_burst`, `hero_share` from them.

### 6. Signals (payload decided here)
```gdscript
signal attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(source_kind: Combat.SourceKind, source_id: StringName, applied: float, hit_position: Vector2, killed: bool, spawn_id: int)
```
- `damage_applied` carries plain values only. No view can reach an enemy through it, a reused `DamageEvent` cannot change under a listener, and a `typeof()` fake checks every argument. `killed` reads committed state; `hit_position` is copied before the reap. Both signals stay VIEW with no sim listener. This replaces ADR-0006 Decision 4's row, which ADR-0006 left to this ADR. TR-combat-010 is shared: this ADR decides the payload half; ADR-0006 owns the rest.
- **QQ-10** (hit-flash shader) is left to ADR-0011. The payload carries what any flash needs, so ADR-0011 can choose with no Combat change.

### 7. Projectiles (QQ-08 ProjectileSpawner part)
No ProjectileSpawner at MVP; every hit is instant. A future spawner is a caller in front of `deliver` that owns flight; `deliver` stays the one HP path, and its removed and dead guards cover a target that left mid-flight. **This settles QQ-08's spawner part, pending the user's acceptance.**

### 8. Per-tick budget (TR-combat-013)
**Catch-up arithmetic, in ADR-0004's terms.** A normal frame owes one tick: 2.0 ms p95 inside the 4.0 ms sim slice. At the first phone build `MAX_TICKS_PER_FRAME = clamp(floori(8.0 / p95_tick_ms), 2, 4)`: at 2.0 ms that gives 4 ticks, 8.0 ms in a catch-up frame. Above 4.0 ms per tick the clamp sits at 2, 30 fps cannot hold full speed, and this budget reopens. TR-combat-013's "at the catch-up clamp" therefore means per tick: a catch-up frame spends the targeting share once per owed tick.

**Ready towers per tick** (Tower GDD starter values). A tower scans only when its cooldown is 0. Single and slow fire every 36 ticks (0.6 s), splash every 60 (1.0 s), the hero every 60 (1.0 s). Under constant fire the 610-gold mix (3 single, 1 splash, 1 slow) has 3/36 + 1/36 + 1/60, about 0.13 towers ready a tick, plus 0.017 for the hero: about 7 checks a tick at 48 targets. But a ready tower with nothing in range holds at 0 and scans every tick (Tower Rules 9, 10), and so does a pinned hero with nothing in the leash. **Design point**: all 5 towers and the hero holding (6 x 48 = 288), plus one firing tower's extras, the slow tower's second pass and a splash's victims (2 x 48): **384, about 400 checks**, the GDD's figure. A tick where all 5 fire at once recurs at most 1 in 36, and the burst release at most once in 10 s, so both fall outside p95.

**Cost from X6.** 0.33 µs a check in desktop debug gives 127 µs for 384 checks, or 0.63 to 1.9 ms at a 5 to 15 times phone slowdown. With `PackedFloat64Array` data (0.18 µs a check) it is 70 µs, or 0.35 to 1.05 ms. The old 0.5 ms share does not hold, so targeting widens to 0.8 ms and two other shares shrink:

| Share | Budget (p95, phone) | Work at the design point | Checked by |
|---|---|---|---|
| Stat reads, all callers | 0.7 ms | About 90 reads | ADR-0005 P1 |
| Combat targeting | 0.8 ms (was 0.5) | 384 checks | P2 (trigger 0.053 ms) |
| Combat `deliver`, `tick_status`, emits | 0.1 ms (was 0.2) | About 15 delivers, 48 status steps | P2 (trigger 0.007 ms) |
| EnemyWave move, path, leak, reap | 0.2 ms (was 0.3) | 48 moves, list rebuild | P2 (trigger 0.013 ms) |
| Flow, Tower, Hero bookkeeping, every `halted()` call | 0.2 ms (was 0.3) | | none |
| **Total** | **2.0 ms** | 48 is the `peak_alive_ub` cap | |

- **The split is an allocation**, checked by desktop benches P1 and P2 against `share / 15` (the top of the slowdown range). ADR-0004 V13 measures the whole tick on the phone; it does not time the shares.
- **P2 `bench_targeting`**: the design-point fixture (48 attached in-field targets, 6 scanners, the two extras), plus 15 delivers, one `tick_status` and 48 moves; warm-up, 600 ticks, `Time.get_ticks_usec()` in the bench only. It reports p95 per line, in a debug run and a release export. **Trigger: targeting above 0.053 ms p95 desktop (0.8 / 15).** X6 already puts debug at about 0.13 ms, so the trigger is likely to fire; the release run decides.
- **Named fallback, ready to build** (in the first Tower story if the release run fires): **one shared pass per tick.** EnemyWave fills `PackedFloat64Array` `tx`, `ty`, `td` beside `_targets` when it rebuilds it. TowerSim collects each ready slot's origin and `range`, then calls one new helper, `Combat.first_in_each(list, tx, ty, td, ox, oy, ranges, picks)`, which reads each target once and tests it against every ready tower (two picks for a slow tower: unslowed and any). TowerSim then fires by ascending slot; a pick that died, or a slow tower's pick slowed, earlier this tick is re-picked with `first_in`, so results match the per-tower path. Cost: the Tower GDD's per-tower read order (read `range`, pick, read the rest) becomes "all ranges, then per tower", a Tower GDD sync at that time. Test V10 checks both paths give the same per-tick digest over a bot script.
- **ADR-0005 P1** keeps its trigger and `match` fallback; at about 90 reads, 0.7 ms allows 7.8 µs a read on the phone, above P1's 0.5 µs desktop trigger times 15. A read overrun is not taken from targeting; it reopens the split under ADR-0004 Decision 7.

### Architecture Diagram
```
Battle holds: flow, combat, enemy_wave, tower_sim, hero_sim, ...
  enemy_wave, tower_sim, hero_sim ──► combat (object) ──► TickMath.to_ticks, DevErrorSink.report
  enemy_wave owns _roster, _targets: Array[Targetable] ──► Enemy (extends Targetable)
       Enemy ──► Health, Status (Combat.attach), ReadContext ─ weak ─► Enemy
Tick: Flow.tick ─► EnemyWave.advance() ─► Combat.tick_status(roster)
   ─► TowerSim.tick [first_in, report_attack, deliver, apply_slow]
   ─► HeroSim.tick [nearest_in or all_in_radius, report_attack, deliver] ─► EnemyWave.reap()
deliver ─► commit hp and counters ─► damage_applied(plain values) ─► views only
```
Nothing points from an enemy, `Health` or `Status` to a sim, and no view payload holds an object, so dropping `Battle` frees the graph (ADR-0001 V2).

### Key Interfaces
```gdscript
class_name Targetable extends RefCounted     # src/core/combat/targetable.gd; no _init, ever
var spawn_id: int      # battle-wide, never reused        (EnemyWave writes)
var distance: float    # along the path                   (EnemyWave writes)
var x: float           # cached centre, rebuilt each tick (EnemyWave writes)
var y: float
var removed: bool      # left the roster by leak or reap  (EnemyWave writes)
var health: Health     # Combat.attach only
var status: Status

class_name Health extends RefCounted         # src/core/combat/health.gd: hp: float, max_hp: float
class_name Status extends RefCounted         # src/core/combat/status.gd: slow_strength: float, slow_ticks: int

class_name DamageEvent extends RefCounted    # src/core/combat/damage_event.gd; one per caller, reused
var target: Targetable                       # strong (X7); caller nulls it
var amount: float
var source_kind: Combat.SourceKind
var source_id: StringName

class_name Combat extends RefCounted         # src/core/combat/combat.gd
enum SourceKind { TOWER, HERO, BURST }
# const String messages: ERR_NO_TARGET, ERR_ATTACHED_TWICE, ERR_BAD_MAX_HP, ERR_REMOVED,
#   ERR_BAD_AMOUNT, ERR_BAD_KIND, ERR_BAD_SLOW, ERR_BAD_RANGE (text is the story's)
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

class_name Enemy extends Targetable          # src/feature/enemy_wave/enemy.gd
var def_id: StringName
var ctx: ReadContext   # ReadContext.new(def_id, 0, self), once in _init
var seg: int           # path segment hint
func _init(p_spawn_id: int, p_def_id: StringName) -> void

class_name PathTable extends RefCounted      # src/feature/enemy_wave/path_table.gd: px, py, cum, length

class_name EnemyWave extends RefCounted      # src/feature/enemy_wave/enemy_wave.gd
const FIELD_MAX_X: float = 540.0
const FIELD_MAX_Y: float = 960.0
func advance() -> void
func reap() -> void
func start_next_wave() -> void
func roster() -> Array[Targetable]           # same instance each call; never mutate or keep
func targets() -> Array[Targetable]
func wave_index() -> int
func got_through_by_type() -> Dictionary     # StringName -> int, view-only
# signals enemy_leaked, enemy_killed, wave_cleared, waves_completed: unchanged (ADR-0006)
```

### Implementation Guidelines
1. Every HP change must go through `deliver`; only Combat may create or write `Health` and `Status`.
2. Only EnemyWave may write `spawn_id`, `distance`, `x`, `y`, `removed`, or mutate a `roster()` or `targets()` result.
3. Enemy lists must be `Array[Targetable]` from construction. B1 is why: a wrong-typed array reaching Combat through a `Variant` aborts the callee silently. If a conversion is ever needed, use `Array(src, TYPE_OBJECT, &"RefCounted", Targetable)`.
4. A caller must reuse one `DamageEvent` and null its `target` at the start of each attack and on every exit.
5. `Targetable` must have no `_init`.
6. Typed results use `maxi`, `minf`, `maxf`, never `max` or `min` (X2).
7. Every guard reports one `push_error` through `dev_error` with its named constant; never `assert`.

## Alternatives Considered

### Alternative 1: Flat HP and slow fields on `Targetable`
- **Description / Pros**: `hp`, `slow_strength` and the rest on the base; fewer objects and one fewer lookup a check.
- **Cons / Rejection Reason**: Combat state sits in a base EnemyWave also writes, so ownership rests on review alone. The saving is one read a check, which the shared pass claims anyway.

### Alternative 2: Combat holds state in a `Dictionary` by `spawn_id`
- **Cons / Rejection Reason**: a hash per check (384 a tick), entries to clean up, and a removed enemy's HP must stay answerable.

### Alternative 3: Enemies as `Node2D`
- **Rejection Reason**: a freed node cannot honour `removed`, `position` collides, ADR-0001 bans `Node` in sims, and tests need a tree.

### Alternative 4: No base class, Combat typed on `Object`
- **Rejection Reason**: no parse-time checks and slower dynamic reads; rule 5 chose the base class for this.

### Alternative 5: Keep `DamageEvent` in the `damage_applied` payload
- **Rejection Reason**: a view gets a live enemy and a reused event changes under it; plain values close a retry leak path.

### Alternative 6: Keep `position: Vector2` on `Targetable`
- **Description / Pros**: B0's proposal; matches the GDD wording and view code.
- **Cons / Rejection Reason**: ADR-0004 L-VEC-1 keeps sim maths in scalars, so every read would unpack `.x` and `.y` from a 32-bit copy. 64-bit `x`, `y` feed the path maths with no conversion per read.

## Consequences

### Positive
- One guarded HP path keeps hero share honest and invariant `I` true by construction.
- Retry needs no extra teardown: the graph points one way and views get no objects.
- Combat tests need no scene, catalogue or EnemyWave.
- The tick budget has named shares, each with a desktop trigger.

### Negative
- Four objects per spawn, about 100 a stage.
- Field ownership rests on lints and review; GDScript has no access control.
- The new payload differs from Combat Rule 12 and ADR-0006's row until synced.
- `all_in_radius` allocates one `Array` per splash or burst.
- If the shared pass is built, Tower's per-tower read order changes.

### Neutral
- `origin` and `impact` stay `Vector2` as the GDD names them; a non-integer caller position rounds to 32-bit, deterministic per CPU.

## Risks
- **R1 Targeting on a phone.** Up to 1.9 ms at the design point on the naive path. Mitigation: P2 release run; the shared pass; V13.
- **R2 A view keeps a list or an enemy.** It delays frees but forms no cycle (V1). Mitigation: ADR-0006 VIEW rules; L-COMBAT-4; V3.
- **R3 Field writes outside the owner.** Mitigation: L-COMBAT-1, L-COMBAT-2.
- **R4 Bad `source_kind`** (R6). Mitigation: step 4 guard before indexing.
- Closed: typed arrays through `Callable.call()` (B3 keeps the type).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-001: DamageEvent, one Health and one Status per enemy; no ProjectileSpawner | Decisions 1, 2, 7 |
| combat-damage.md | TR-combat-002: `spawn_id`, cached distance and position, `removed`; not a freed Node | Decision 1 |
| combat-damage.md | TR-combat-003: every HP change through `deliver` in a tick, `min(amount, hp)`, fixed guards with named codes | Decision 5; Guidelines 1, 7 |
| combat-damage.md | TR-combat-004: death at 0; dead not targetable; reap emits `enemy_killed` once | Decisions 4, 5 |
| combat-damage.md | TR-combat-005: per-source counters readable until destroyed | Decision 5 (Counters) |
| combat-damage.md | TR-combat-006: whole-tick slow with replace, equal, ignore; `speed_factor` | Decision 5 |
| combat-damage.md | TR-combat-007: no catalogue; only `to_ticks` | Decision 5 (plus the dev-error sink; no `dt`) |
| combat-damage.md | TR-combat-008: inclusive squared test, lowest `spawn_id` ties, no mutation | Decision 5 |
| combat-damage.md | TR-combat-013: targeting within budget at the catch-up clamp | Decision 8. **Partial**: device proof owed |
| enemy-wave.md | TR-enemy-008: sole roster owner, read-only lists by `spawn_id`, no back-references | Decision 3 |
| enemy-wave.md | TR-enemy-009: how Health and Status attach | Decision 2 |
| enemy-wave.md | TR-enemy-010: position from distance, cached lengths, multi-segment, clamped | Decision 4 |
| enemy-wave.md | TR-enemy-011: targetable only inside 540x960, a defined constant | Decision 3 |
| enemy-wave.md | TR-enemy-013: one add-enemy step, before the clear check | Decision 3 |
| enemy-wave.md | TR-enemy-016: `wave_index()`, `got_through_by_type()` view-only | Decision 3 |
| tower-system.md | TR-tower-007: targeting and damage only through Combat; splash from `targets()` | Decision 5 |
| hero-system.md | TR-hero-007: HERO and BURST kinds, `report_attack` first, helpers over `targets()` | Decision 5 |

Shared, not counted: TR-combat-010 (payload half; ADR-0006 owns the rest). Also settled: QQ-08's two remaining parts, pending acceptance. QQ-10 goes to ADR-0011.

## Performance Implications
- **CPU**: 1.1 ms of the 2.0 ms tick is this ADR's code (targeting 0.8, Combat writes 0.1, EnemyWave 0.2); reads keep 0.7 (Decision 8). Allocations, checked by P2.
- **Memory**: four small objects per spawned enemy, at most 48 alive; two reused lists; one counter `Dictionary`.
- **Load Time**: one `PathTable` per battle. **Network**: none.

## Migration Plan
No code exists. Sync items, not edited here:
1. **`architecture.md`**: rule 5 fields; B0 rows (`Targetable`, `Enemy`, `DamageEvent`; add `Health`, `Status`, `PathTable`); B6 (`attach`, guards, payload); B7 (`advance()`, constants); B9 (`combat` object into the three sims); Module Ownership Combat row (drop `dt`, add `attach`) and EnemyWave row; Data Flow 10 (Decision 8 split); Required ADRs; QQ-08, QQ-10, QQ-11.
2. **GDDs** (game-designer, user sign-off): combat-damage.md Rule 3 gains `ERR_NO_TARGET` (step 1) and `ERR_BAD_KIND` (step 4, before dead); Rule 10 gains `ERR_BAD_RANGE` and the empty-list result; a new acceptance criterion covers `attach` with `ERR_ATTACHED_TWICE` and `ERR_BAD_MAX_HP`; Rule 11 types `Array[Targetable]`; Core Rules and enemy-wave.md Rule 14 read `x`, `y` for `position`. **Data**: the CI content test fails a path point float32 cannot hold exactly.
3. **At acceptance, together**: ADR-0006's Decision 4 `damage_applied` row amendment, the registry `battle_signal_catalogue` entry, and the combat-damage.md Rule 12 edit, all to Decision 6's signature.
4. **ADR-0007 amendment** at acceptance: L-COMBAT-1 (T3, `src/` but `core/combat/`: `.health`, `.status`, `Health.new(`, `Status.new(`); L-COMBAT-2 (C3, `src/` but `feature/enemy_wave/`: on a receiver typed `Targetable` or `Enemy`, assigning `spawn_id`, `distance`, `x`, `y` or `removed`); L-COMBAT-3 (T3, `DamageEvent.new(` outside `tower_sim.gd`, `hero_sim.gd`); L-COMBAT-4 (C3, `src/` but `enemy_wave.gd`: `append`, `remove_at`, `clear`, `sort`, `erase` or assignment on a `roster()` or `targets()` result); `combat_invariant.gd` reads `applied` (argument 3); B1 to B4 and X1 to X7 join the probe suite.
5. `requirements-traceability.md`, `tr-registry.yaml`: by `/architecture-review`.

## Validation Criteria
Headless gdUnit4; code-built fixtures; no scene or catalogue for Combat.
- **V1 `test_combat_*`**: Combat GDD criteria 1 to 18 with `I` after each; first hit by a new source id; amount and kind both bad reports `ERR_BAD_AMOUNT` alone; bad kind on a dead enemy reports `ERR_BAD_KIND`; `attach` twice reports `ERR_ATTACHED_TWICE`; bad `max_hp`; `ERR_BAD_RANGE`; empty and null lists; `event.target` null after a halted attack.
- **V2 `test_damage_applied_payload`**: `typeof()` per argument; no `Object`.
- **V3 `test_enemy_frees_on_retry`**: ADR-0001 V2 plus leaks, reaps, a frozen outcome and a view; every enemy, `Health`, `Status` and context weakref reads null.
- **V4 `test_path_table`**: the GDD example and multi-segment steps.
- **V5 `test_targets_field_rect`**: edges in, just outside out.
- **V6 `test_roster_order_and_removal`**: order and whole lists at each emit.
- **V7 `test_advance_no_argument`**: `wave_tick` across an Intermission.
- **V8 `test_wave_reads`**: `wave_index`, got-through.
- **V9 `test_combat_init_signature`**: `_init` takes exactly `to_ticks` and `dev_error`.
- **V10 `test_shared_pass_matches`** (with the fallback): same per-tick digest as the per-tower path.
- **P2 `bench_targeting`**: Decision 8, debug and release export. **ADR-0004 V13** on device.

## Reviews
**godot-specialist: CONCERNS** (ran probes on 4.7.2). **TD-ADR: CONCERNS.** All findings applied.

| # | Finding | Resolution |
|---|---|---|
| B-1 (both) | Catch-up arithmetic wrong; 5 x 48 overcounts; device gap | Decision 8: ADR-0004 terms; ready-tower count; share 0.8 from X6; shared pass named; trigger share / 15; release run; split is an allocation |
| B-2 (X1) | `+=` on a missing key aborts | Decision 5 step 7 `.get(id, 0.0)`; V1 case |
| B-3 (TD 2) | Amount and kind in one step | Steps 3 and 4; V1 cases |
| G3 | `max` and `min` infer `Variant` | `maxi`, `minf`; Guideline 6 |
| G4 | Typed-array conversion | Guideline 3 |
| G5 | R2 closed by B3 | Risks |
| G6 | Same list instance | L-COMBAT-4; Decision 3 |
| G7 | Strong `target` | Decision 5; Guideline 4; V1 |
| G11 | Base `_init` skipped | No `_init` on `Targetable`; Guideline 5 |
| G13 | `return null` overrides | Engine Compatibility |
| G14 | Typed Dictionary | Kept untyped, reason in Decision 5 |
| G16, TD 6 | TR-combat-003 citation | Guidelines 1, 7 |
| TD 4 | Share timing on device | Allocation, desktop benches |
| TD 5 | Verify against v6 | Last Verified; Related |
| TD 7 | Five new constants need GDD homes | Migration item 2; V1 |
| TD 8 | Null list | Silent; V1 |
| TD 9 | No `halted()` basis | Decision 5; V9; "other" share |
| TD 10 | float32 path points | Migration item 2 |
| TD 11 | L-COMBAT-2 class | C3, receiver-typed, scoped |
| TD 12 | TR-combat-010 | Shared note |
| TD Alt | `Vector2` position | Alternative 6 |
| TD 13 | Length | Trimmed |

GDD sync (4 GDDs checked): combat-damage.md (Rules 3, 10, 11, 12, Core Rules), enemy-wave.md (Rule 14) use names this ADR changes; Migration items 2 and 3. Tower and Hero call names are unchanged.

## Related
- Depends on ADR-0001, 0002, 0004, 0005, 0006, 0007; amends ADR-0006 and ADR-0007 at acceptance; enables ADR-0010, ADR-0011.
- `architecture.md` v6 (rule 5, B0, B6, B7, B9, Data Flow 10, QQ-08, QQ-10, QQ-11); `architecture-review-2026-11-04.md` (Blocking 1, Conflict 2, Should-fix 6).
- GDDs: `combat-damage.md`, `enemy-wave.md`, `tower-system.md` (Rules 9, 10, 13, starter values), `hero-system.md` (Rules 4, 8, Tick).
