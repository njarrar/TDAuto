# ADR-0009: Enemy Entity, Roster and Combat API

## Status
Accepted

## Date
2026-11-04

## Last Verified
2026-11-04, against `architecture.md` v6, `tr-registry.yaml` v6 (123 entries), the eight Accepted ADRs with their amendments, and probes B1 to B4 and X1 to X7 run on 4.7.2 by the godot-specialist review.

## Decision Makers
- Accepted: 2026-11-04 by the user (njarrar), with both remaining QQ-08 parts (ProjectileSpawner cut; stage geometry on the Stage record), the plain-value damage_applied payload and the per-tick budget split
Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`). Reviews: godot-specialist and TD-ADR, both CONCERNS, resolved below. Acceptance: the user.

## Summary
Combat (Core) must act on enemies that Enemy & Wave (Feature) owns, with no upward dependency or retry-blocking back-reference, inside ADR-0004's 2.0 ms tick. This ADR fixes a Core base class `Targetable` with plain `float` position, `Health` and `Status` objects that only Combat writes, a roster owned by `EnemyWave` as `Array[Targetable]`, the Combat API with its guards and counters, a plain-value `damage_applied`, and a named per-tick budget split with a targeting bench and a ready-to-build fallback.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Core (GDScript data model, simulation maths) |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM: plain GDScript types stable since 4.0; the open risk is phone cost |
| **References Consulted** | `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `probe-results.md` (V1a to V1f, KEY, E1, E2, E4, E1 to E3 of ADR-0006, H4, R3, R6); no `modules/` file fits |
| **Post-Cutoff APIs Used** | None. 4.7's typed-return override rule applies: `return null` in an `-> int` override fails to parse (H4), so every override returns a real typed value |
| **Verification Required** | B1 to B4 and X1 to X7: verified 4.7.2 headless (desktop debug, 4-core Xeon VM), results below; they join ADR-0007's probe suite. Still open: P2 in a release export, and the device run (ADR-0004 V13) |

| Probe | Result (verified 4.7.2 headless) |
|---|---|
| B1 | `Array[Enemy]` where `Array[Targetable]` is expected fails at parse time when typed; through a `Variant` the callee aborts silently and the caller goes on. `Array[Targetable]` takes an `Enemy`. `as Enemy` on a plain `Targetable` is null |
| B2 | `for t: Targetable in list` works |
| B3 | `Callable.call()` keeps the array type and returns the same instance |
| B4 | `Combat` and `DamageEvent` naming each other parse and load; payload types `int`, `StringName`, `float`, `Vector2`, `bool`, `int` |
| X1 | `+=` on a missing `Dictionary` key errors and aborts |
| X2 | `var t := max(...)` fails to parse (`inference_on_variant` is an error) |
| X3 | `remove_at` on 60 items: about 0.36 µs |
| X4 | GDScript `float` is 64-bit |
| X5 | `Enemy`'s typed `_init` works because `Targetable` has none; a subclass `_init()` without `super()` silently skips a base `_init` |
| X6 | 480 checks a tick: 157 µs p50, 199 µs p95 desktop debug (about 0.33 µs a check); 88 µs p95 with `PackedFloat64Array` data |
| X7 | `DamageEvent.target` is a strong reference; setting it to null frees the enemy |

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

### Constraints and Requirements
Rule 5 (Core cannot name a Feature class; typed arrays are invariant); ADR-0001 (no sim holds `Battle`, `AppRoot` or a `Node`; method Callables; weakref retry proof); ADR-0004 (six-step tick, `halted()` after every read, call and emit, `int` countdowns, scalar maths, 2.0 ms p95); ADR-0005 (one `ReadContext` per `Enemy`, weak); ADR-0006 (commit then emit, VIEW roles, ID types); ADR-0007 (`is_push_error`, invariant `I`). Requirements: the 17 TRs below; retry frees every enemy with no extra unwire; no hot-path allocation but `all_in_radius`.

## Decision

### 1. Object kinds and ownership
Classes, files, fields and writers are in Key Interfaces. Outside `src/core/combat/`, `src/` reads `Health` and `Status` only through `hp_left`, `is_dead`, `speed_factor`.
- **`RefCounted`, not `Node`**: a freed `Node` cannot honour `removed`, and `Node2D.position` collides (TR-combat-002).
- **`x`, `y` as `float`**: 64-bit (X4) where `Vector2` is 32-bit (E2); no conversion per read; exact edge tests. Signals build `Vector2(t.x, t.y)`.
- **`distance` on `Targetable`**: `first_in` ranks by it (moved from B0's `Enemy` row).

### 2. Attachment and construction
- `Combat.attach(target, max_hp) -> bool` makes one `Health` (`hp = max_hp`, `max_hp = max_hp`) and one empty `Status`. Guards, in order, each one `push_error` with `false` and nothing changed: null target (`ERR_NO_TARGET`), already attached (`ERR_ATTACHED_TWICE`), `max_hp` not finite or not above 0 (`ERR_BAD_MAX_HP`).
- EnemyWave's add-enemy step reads `max_hp`, checks `halted()`, calls `attach`, and on `false` calls `fatal("enemy_attach_failed")` and returns. The Data validator already bounds `max_hp` above 0.
- **`Targetable` has no `_init`, ever**: a subclass `_init()` without `super()` skips it silently (X5). `Enemy._init` sets `spawn_id`, `def_id` and `ctx = ReadContext.new(def_id, 0, self)` (ADR-0005 V6(b)).

### 3. Roster and lists (TR-enemy-008, 011, 013, 016)
- EnemyWave owns `_roster` and `_targets`, both `Array[Targetable]`, made once and reused. `roster()`: every enemy not yet removed, corpses included, by ascending `spawn_id`. `targets()`: the subset with `0.0 <= x <= FIELD_MAX_X` (540.0) and `0.0 <= y <= FIELD_MAX_Y` (960.0); a test checks the constants against ADR-0003's viewport.
- Both return the internal array; callers get the same instance (B3). Read-only by contract, since `make_read_only()` would stop EnemyWave's own writes; L-COMBAT-4 backs it. Never kept past the reader's slot.
- `_targets` is rebuilt after the leak loop; the reap removes corpses from both lists. Removal is `remove_at` on one enemy (0.36 µs at 60, X3), then the emit, so every emit sees whole lists.
- One add-enemy step, `_add_enemy(def_id, start_distance) -> Enemy`, serves the schedule (advance slot) and future splitter children (reap slot, before the clear check). `spawn_id` only rises, so appending keeps order.
- `wave_index()` (1-based, 0 before the first start, set when `start_next_wave` commits, unchanged by a clear or outcome) and `got_through_by_type()` (internal untyped `Dictionary`, enemy `def_id` to `int`, keys added on first leak, never reset) are view-only. The snapshot deep-copies the latter.

### 4. Path, stage geometry and EnemyWave entries (TR-enemy-010; QQ-08)
- `path_points`, `slot_positions`, `path_width` stay on the Stage record as ADR-0002 stores them; the scene keeps only the look. **This settles QQ-08's stage-geometry part, accepted by the user 2026-11-04.**
- EnemyWave builds one `PathTable` at build: `px`, `py`, `cum` as `PackedFloat64Array`, and `length`. Position is looked up from `distance` and the enemy's `seg` hint, so one step can cross several segments, and clamps to the last point at `length`. Each component is computed apart (L-VEC-1); `x`, `y` are rebuilt each tick, so no rounding builds up.
- The source points are `Vector2` (32-bit). A sync item asks the CI content test to fail a path point that float32 cannot hold exactly; the starter points are integers.
- **`advance() -> void` takes no argument** (ADR-0004 Decision 5 allowed it). EnemyWave owns `wave_tick` (Rule 7); `tick_count()` runs through Intermission, and a second counter could disagree. `advance()` spawns, moves (`move_speed x speed_factor x dt`), leaks by `spawn_id`, rebuilds `_targets`; `reap()` handles corpses by `spawn_id`, then the clear check.

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
- **Helpers** (`first_in`: greatest `distance`; `nearest_in`: smallest squared distance; `all_in_radius`: all, in input order) check the radius first (not finite or below 0: `ERR_BAD_RANGE`), then test `dx * dx + dy * dy <= r * r` on `x`, `y`; skip the dead, never sort or mutate, tie to lowest `spawn_id`. An empty or null list gives null or empty, silently (V1 records the null case). Tower's "unslowed first" filters into a scratch list it owns.
- **`report_attack`**: checks the kind (`ERR_BAD_KIND`, no emit), then emits `attack_fired`. Callers call it before their `deliver` calls.
- **`DamageEvent` reuse**: TowerSim and HeroSim each own one. The reference is strong (X7), so the caller sets `target = null` at the start of each attack and on every exit, the early `halted()` return included. V1 checks it is null after a halted attack.
- **Counters** (TR-combat-005): `_dealt_by_id` stays an untyped `Dictionary` (`StringName` to `float`), like ADR-0006's `got_through`: keys cross on lookup (ADR-0002 KEY) and typed-Dictionary key conversion is unprobed. `_dealt_by_kind` is a `PackedFloat64Array` of 3. `dealt_by_id` (0.0 unknown), `dealt_by_kind` (`ERR_BAD_KIND`, 0.0 out of range), `dealt_total` (tower + hero + burst, in order), `hero_share` (`(hero + burst) / total`, 0.0 at total 0.0). Readable until the battle drops; `take_result_snapshot()` copies them.

### 6. Signals (payload decided here)
```gdscript
signal attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(source_kind: Combat.SourceKind, source_id: StringName, applied: float, hit_position: Vector2, killed: bool, spawn_id: int)
```
- Plain values only: no view reaches an enemy, a reused `DamageEvent` cannot change under a listener, and a `typeof()` fake checks every argument. `killed` reads committed state. Both stay VIEW, no sim listener. This replaces ADR-0006 Decision 4's row, as ADR-0006 allowed; TR-combat-010 is shared (payload half here).
- **QQ-10** (hit-flash shader) goes to ADR-0011; the payload already carries what a flash needs.

### 7. Projectiles (QQ-08 ProjectileSpawner part)
No ProjectileSpawner at MVP; every hit is instant. A future spawner is a caller in front of `deliver` that owns flight; `deliver` stays the one HP path, and its removed and dead guards cover a target that left mid-flight. **This settles QQ-08's spawner part, accepted by the user 2026-11-04.**

### 8. Per-tick budget (TR-combat-013)
**Catch-up, in ADR-0004's terms.** A normal frame owes one tick: 2.0 ms p95 inside the 4.0 ms sim slice. At the first phone build `MAX_TICKS_PER_FRAME = clamp(floori(8.0 / p95_tick_ms), 2, 4)`: at 2.0 ms that is 4 ticks, 8.0 ms in a catch-up frame. Above 4.0 ms per tick the clamp sits at 2, 30 fps cannot hold full speed, and this budget reopens. So TR-combat-013's "at the catch-up clamp" is a per-tick limit, spent once per owed tick.

**Ready towers per tick** (Tower GDD starter values). A tower scans only at cooldown 0: single and slow every 36 ticks, splash and hero every 60. Under fire the 610-gold mix (3 single, 1 splash, 1 slow) has 3/36 + 1/36 + 1/60, about 0.13 ready a tick, plus 0.017 for the hero: about 7 checks. But a ready tower or pinned hero with nothing in range holds and scans every tick (Tower Rules 9, 10). **Design point**: all 5 towers and the hero holding (6 x 48 = 288), plus the extras of towers firing that tick, a slow tower's second pass and a splash's victims (2 x 48): **384 checks**, the GDD's "about 400". A tick where all 5 fire recurs at most 1 in 36, and a burst release once in 10 s or more, so both fall outside p95.

**Cost from X6.** At 0.33 µs a check (desktop debug), 384 checks take 127 µs, or 0.63 to 1.9 ms at a 5 to 15 times phone slowdown; with packed data (0.18 µs), 70 µs, or 0.35 to 1.05 ms. The old 0.5 ms share does not hold, so targeting widens to 0.8 ms and three shares shrink:

| Share | Budget (p95, phone) | Design-point work | Desktop trigger (share / 15) |
|---|---|---|---|
| Stat reads, all callers | 0.7 ms | About 90 reads | ADR-0005 P1 |
| Combat targeting | 0.8 ms (was 0.5) | 384 checks | P2: 0.053 ms |
| Combat `deliver`, `tick_status`, emits | 0.1 ms (was 0.2) | About 15 delivers, 48 steps | P2: 0.007 ms |
| EnemyWave move, path, leak, reap | 0.2 ms (was 0.3) | 48 moves | P2: 0.013 ms |
| Flow, Tower, Hero bookkeeping, all `halted()` calls | 0.2 ms (was 0.3) | | none |
| **Total** | **2.0 ms** | 48 is the `peak_alive_ub` cap | |

- **The split is an allocation**, checked by desktop benches against `share / 15`. ADR-0004 V13 times only the whole tick on the phone.
- **P2 `bench_targeting`**: the design-point fixture plus 15 delivers, one `tick_status` and 48 moves; warm-up, 600 ticks, `Time.get_ticks_usec()` in the bench only; p95 per line, in debug and in a release export. X6 puts debug targeting near 0.13 ms, so the trigger will likely fire; the release run decides.
- **Named fallback, ready to build** in the first Tower story if the release run fires: **one shared pass per tick.** EnemyWave fills `PackedFloat64Array` `tx`, `ty`, `td` beside `_targets`. TowerSim collects each ready slot's origin and `range`, then calls `Combat.first_in_each(list, tx, ty, td, ox, oy, ranges, picks)`, which reads each target (and its `hp`) once and tests it against every ready tower, with two picks for a slow tower (unslowed, any). TowerSim fires by ascending slot and re-picks with `first_in` any pick that died, or a slow pick that got slowed, earlier this tick, so results match the per-tower path (V10). Cost: Tower's read order becomes "all ranges, then per tower", a Tower GDD sync then. If the shared pass misses 0.053 ms, this ADR is amended before the Tower story closes.
- **ADR-0005 P1** keeps its trigger and `match` fallback: 0.7 ms over 90 reads allows 7.8 µs a read, above 0.5 µs times 15. A read overrun reopens the split under ADR-0004 Decision 7; it never takes Combat's share.

### Architecture Diagram
```
enemy_wave, tower_sim, hero_sim ──► combat (object) ──► TickMath.to_ticks, DevErrorSink.report
enemy_wave ──► _roster, _targets ──► Enemy ──► Health, Status, ReadContext ─ weak ─► Enemy
Tick: Flow ─► advance() ─► tick_status(roster) ─► TowerSim ─► HeroSim ─► reap()
deliver ─► commit ─► damage_applied(plain values) ─► views only
```
Nothing points from an enemy to a sim, and no view payload holds an object, so dropping `Battle` frees the graph (ADR-0001 V2).

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

1. **Flat HP and slow fields on `Targetable`**: fewer objects, but Combat state would sit in a base EnemyWave also writes. The one read a check it saves, the shared pass claims anyway.
2. **Combat state in a `Dictionary` by `spawn_id`**: a hash per check, entries to clean up, and a removed enemy's HP must stay answerable.
3. **Enemies as `Node2D`**: a freed node cannot honour `removed`, `position` collides, ADR-0001 bans `Node` in sims.
4. **No base class, Combat typed on `Object`**: no parse-time checks, slower dynamic reads; rule 5 chose the base class for this.
5. **`DamageEvent` in the `damage_applied` payload**: a view gets a live enemy and a reused event changes under it.
6. **Keep `position: Vector2`** (B0's proposal, the GDD wording): ADR-0004 L-VEC-1 keeps sim maths in scalars, so each read would unpack a 32-bit copy; 64-bit `x`, `y` feed the path maths with no conversion per read.

## Consequences

- **Positive**: one guarded HP path keeps hero share honest and `I` true; retry needs no extra teardown; Combat tests need no scene, catalogue or EnemyWave; each budget share has a desktop trigger.
- **Negative**: four objects per spawn; field ownership rests on lints and review; the payload differs from Combat Rule 12 and ADR-0006 until synced; `all_in_radius` allocates per splash or burst; the shared pass, if built, changes Tower's read order.
- **Neutral**: `origin` and `impact` stay `Vector2`; a non-integer caller position rounds to 32-bit, deterministic per CPU.

## Risks
- **R1 Targeting on a phone**: up to 1.9 ms naive. Mitigation: P2 release run, shared pass, V13.
- **R2 A view keeps a list or enemy**: delays frees, no cycle (V1). Mitigation: VIEW rules, L-COMBAT-4, V3.
- **R3 Writes outside the owner**: L-COMBAT-1, L-COMBAT-2. **R4 Bad `source_kind`** (R6): step 4.
- Closed: typed arrays through `Callable.call()` (B3).

## GDD Requirements Addressed

| GDD System | Requirement | Decision |
|------------|-------------|----------|
| combat-damage.md | TR-combat-001: DamageEvent, Health, Status; no ProjectileSpawner | 1, 2, 7 |
| combat-damage.md | TR-combat-002: enemy fields; valid after removal, not a Node | 1 |
| combat-damage.md | TR-combat-003: all HP through `deliver` in a tick, fixed guards, named codes | 5; Guidelines 1, 7 |
| combat-damage.md | TR-combat-004: death at 0, not targetable, `enemy_killed` once | 4, 5 |
| combat-damage.md | TR-combat-005: per-source counters | 5 |
| combat-damage.md | TR-combat-006: whole-tick slow rules, `speed_factor` | 5 |
| combat-damage.md | TR-combat-007: no catalogue, only `to_ticks` | 5 (plus the dev-error sink; no `dt`) |
| combat-damage.md | TR-combat-008: inclusive test, `spawn_id` ties, no mutation | 5 |
| combat-damage.md | TR-combat-013: targeting in budget at the catch-up clamp | 8. **Partial**: device proof owed |
| enemy-wave.md | TR-enemy-008: sole owner, read-only ordered lists, no back-references | 3 |
| enemy-wave.md | TR-enemy-009: Health and Status attachment | 2 |
| enemy-wave.md | TR-enemy-010: position from distance via cached lengths | 4 |
| enemy-wave.md | TR-enemy-011: field rectangle as a constant | 3 |
| enemy-wave.md | TR-enemy-013: one add-enemy step | 3 |
| enemy-wave.md | TR-enemy-016: `wave_index()`, `got_through_by_type()` | 3 |
| tower-system.md | TR-tower-007: only through Combat; splash from `targets()` | 5 |
| hero-system.md | TR-hero-007: HERO and BURST, `report_attack` first, helpers | 5 |

Shared, not counted: TR-combat-010 (payload half; ADR-0006 owns the rest). Also settled and accepted by the user 2026-11-04: QQ-08's two parts. QQ-10 goes to ADR-0011.

## Performance Implications
- **CPU**: 1.1 of the 2.0 ms tick is this ADR's code; reads keep 0.7 (Decision 8). **Memory**: four small objects per enemy, at most 48 alive. **Load Time**: one `PathTable`. **Network**: none.

## Migration Plan
No code exists. Sync items, not edited here:
1. **`architecture.md`**: rule 5 fields; B0 (`Targetable`, `Enemy`, `DamageEvent`; add `Health`, `Status`, `PathTable`); B6; B7 (`advance()`); B9 (`combat` object); Module Ownership Combat (drop `dt`, add `attach`) and EnemyWave rows; Data Flow 10; Required ADRs; QQ-08, QQ-10, QQ-11.
2. **GDDs** (user sign-off): combat-damage.md Rule 3 gains `ERR_NO_TARGET` (step 1) and `ERR_BAD_KIND` (step 4); Rule 10 gains `ERR_BAD_RANGE` and the empty-list result; a new criterion covers `attach` with `ERR_ATTACHED_TWICE` and `ERR_BAD_MAX_HP`; Rule 11 types `Array[Targetable]`; Core Rules and enemy-wave.md Rule 14 read `x`, `y`. Data: the CI content test fails a path point float32 cannot hold exactly.
3. **At acceptance, together**: the ADR-0006 Decision 4 `damage_applied` row amendment, the registry `battle_signal_catalogue` entry, and combat-damage.md Rule 12, all to Decision 6's signature.
4. **ADR-0007 amendment** at acceptance: L-COMBAT-1 (T3, `src/` but `core/combat/`: `.health`, `.status`, `Health.new(`, `Status.new(`); L-COMBAT-2 (C3, `src/` but `feature/enemy_wave/`: on a receiver typed `Targetable` or `Enemy`, assigning `spawn_id`, `distance`, `x`, `y`, `removed`); L-COMBAT-3 (T3, `DamageEvent.new(` outside `tower_sim.gd`, `hero_sim.gd`); L-COMBAT-4 (C3, `src/` but `enemy_wave.gd`: `append`, `remove_at`, `clear`, `sort`, `erase` or assignment on a `roster()` or `targets()` result); `combat_invariant.gd` reads `applied` (argument 3); B1 to B4, X1 to X7 join the probe suite.
5. `requirements-traceability.md`, `tr-registry.yaml`: by `/architecture-review`.

## Validation Criteria
Headless gdUnit4; code-built fixtures.
- **V1 `test_combat_*`**: Combat GDD criteria 1 to 18 with `I` after each; first hit by a new source id; amount and kind both bad reports `ERR_BAD_AMOUNT` alone; bad kind on a dead enemy reports; `attach` twice; bad `max_hp`; `ERR_BAD_RANGE`; empty and null lists; `event.target` null after a halted attack.
- **V2 `test_damage_applied_payload`**: `typeof()` per argument, no `Object`. **V3 `test_enemy_frees_on_retry`**: every enemy, `Health`, `Status`, context weakref null. **V4 `test_path_table`**: GDD example, multi-segment. **V5 `test_targets_field_rect`**: edges. **V6 `test_roster_order_and_removal`**: whole lists at each emit. **V7 `test_advance_no_argument`**. **V8 `test_wave_reads`**. **V9 `test_combat_init_signature`**: exactly `to_ticks`, `dev_error`. **V10 `test_shared_pass_matches`**: same digest as per-tower (with the fallback).
- **P2 `bench_targeting`** (Decision 8), debug and release export; **ADR-0004 V13** on device.

## Reviews
**godot-specialist: CONCERNS** (ran probes on 4.7.2). **TD-ADR: CONCERNS.** All findings applied.

| # | Finding | Resolution |
|---|---|---|
| B-1 (both) | Catch-up maths; 5 x 48 overcounts; device gap | Decision 8 |
| B-2 (X1) | `+=` on a missing key aborts | Step 7 `.get()`; V1 |
| B-3 (TD 2) | Amount and kind in one step | Steps 3, 4; V1 |
| G3 | `max`, `min` infer `Variant` | Guideline 6 |
| G4, G5 | Typed-array conversion; R2 | Guideline 3; R2 closed |
| G6 | Same list instance | L-COMBAT-4 |
| G7 | Strong `target` | Decision 5; V1 |
| G11 | Base `_init` skipped | Decision 2 |
| G13 | `return null` overrides | Engine Compatibility |
| G14 | Typed Dictionary | Kept untyped (Decision 5) |
| G16, TD 6 | TR-combat-003 citation | Fixed |
| TD 4 | Share timing on device | Allocation, desktop benches |
| TD 5 | v6 | Last Verified, Related |
| TD 7 | New constants need homes | Migration 2; V1 |
| TD 8 | Null list | Silent; V1 |
| TD 9 | No `halted()` basis | Decision 5; V9 |
| TD 10 | float32 path points | Migration 2 |
| TD 11 | L-COMBAT-2 class | C3, scoped |
| TD 12 | TR-combat-010 | Shared |
| TD Alt | `Vector2` position | Alternative 6 |
| TD 13 | Length | Trimmed |

GDD sync (4 GDDs checked): combat-damage.md (Rules 3, 10, 11, 12, Core Rules), enemy-wave.md (Rule 14) use names this ADR changes; Migration items 2 and 3. Tower and Hero call names are unchanged.

## Related
- Depends on ADR-0001, 0002, 0004, 0005, 0006, 0007; amends ADR-0006 and ADR-0007 at acceptance; enables ADR-0010, ADR-0011.
- `architecture.md` v6 (rule 5, B0, B6, B7, B9, Data Flow 10, QQ-08, QQ-10, QQ-11); `architecture-review-2026-11-04.md` (Blocking 1, Conflict 2, Should-fix 6).
- GDDs: `combat-damage.md`, `enemy-wave.md`, `tower-system.md` (Rules 9, 10, 13, starter values), `hero-system.md` (Rules 4, 8, Tick).

## Amendments
- **2026-11-05, with ADR-0011 (confirmed by the user 2026-11-05 at ADR-0011 acceptance); Status stays Accepted.** Combat gains `func hp_ratio(enemy: Targetable) -> float`, a view-only read: `hp / max_hp` from the enemy's `Health`, which already holds `max_hp`, and 1.0 for an unattached enemy. Decision 1's list of `Health` reads outside `src/core/combat/` becomes `hp_left`, `is_dead`, `speed_factor`, `hp_ratio`. It changes no state, reports nothing and is not called by the sim. Nothing else in this ADR changes.
- **2026-11-05, from the fourth architecture review; Status stays Accepted** (`architecture-review-2026-11-05.md`, Should fix 5). Decisions 4 and 7 now say each QQ-08 part was accepted by the user 2026-11-04, as Decision Makers records, in place of "pending the user's acceptance". Nothing else in this ADR changes.
