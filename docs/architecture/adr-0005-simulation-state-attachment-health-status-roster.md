# ADR-0005: Simulation State Attachment: Health, Status and Roster

## Status
Proposed

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
njarrar (project owner, approves at Accepted); lead-programmer (draft, autonomous mode). Technical-director and godot-specialist reviews are recorded under Related once they run.

## Summary
Combat, Enemy & Wave, Tower and Hero share one set of runtime objects, and the architecture leaves their names, writers and lifetimes open (`EnemyInstance` is named but not defined). This ADR confirms `EnemyInstance`, attaches Health and Status to it as two small components that only Combat writes, makes WaveSim the sole writer of a roster of copies keyed by a battle-wide `spawn_id`, defines the tower and hero instances, the counter records, and a `snapshot()` method on every system for the ADR-0004 harness.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (simulation data) |
| **Layer** | Core |
| **Knowledge Risk** | LOW to MEDIUM: plain `RefCounted` objects and typed collections; the only post-cutoff rule that touches the design is the 4.7 packed-array write change |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.7: packed array element writes; typed-return overrides), `deprecated-apis.md` (typed `Array[Type]`), `current-best-practices.md` (`@abstract`, lambda capture) |
| **Post-Cutoff APIs Used** | None new. The 4.7 packed-array rule shapes one design choice (section 5, `PathTrack`): no sim class puts a setter on a packed-array property. The 4.7 typed-return rule applies to any override a story adds (ADR-0003 guideline) |
| **Verification Required** | **NOT SOURCEABLE** from `docs/engine-reference/godot/` (no coverage of core classes): (V1) `Array.make_read_only()` exists and a write to a sealed typed array errors; memory, unverified; this ADR does not rely on it (section 5 returns copies), it is only the escape if copy cost fails the budget; (V2) a `RefCounted` cycle is never freed, and a `weakref` to a battle with no cycle goes null after `dispose()`; memory, unverified; the design has no cycle and the Retry test proves the `weakref`; (V3) `Dictionary` keeps insertion order and `==` ignores order; memory, unverified; no result here depends on either (arrays are sorted, records have fixed keys); (V4) a typed `Array[EnemyInstance]` built by `append` is accepted by a typed parameter and an untyped `Array` is not; `Array.sort_custom` and `Dictionary.erase` behave as in 4.3; memory, unverified; checked by the first WaveSim story's parse check and unit tests; (V5) `floori` and `is_finite` as ADR-0001 and ADR-0003 use them; memory, unverified |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): `StageDef`, `StatAccessor`, `ReadContext`. ADR-0002 (Accepted): the canonical table, `DamageEvent`, `VIEW_SIGNALS`, `HaltLatch`, returned collections. ADR-0003 (Accepted): the tick slot order and `Battle.DT` |
| **Enables** | ADR-0004 (the harness calls `snapshot()` on `Battle.systems()`), ADR-0006 (views key enemy nodes by `spawn_id`), ADR-0008 (the builder constructs these classes with the inputs listed here) |
| **Blocks** | Epics Combat, Enemy & Wave, Tower, Hero |
| **Ordering Note** | ADR-0008 builds `TickConverter` first, then Combat, WaveSim, TowerSim, HeroSim, StageFlow (architecture 3.4 order, with `TickConverter` added). ADR-0004 owns the harness; it must not add keys to a system's snapshot by reflection |

## Context

### Problem Statement
The GDDs agree on behaviour and leave the data open. Combat Rule 9 says Health is seeded once from `max_hp` and Combat reads no catalogue. Enemy & Wave Rule 14 says an enemy exposes `spawn_id`, `def_id`, `distance` and `position`, and that "how Health and Status attach is left to Combat's ADR". Architecture 4.4 uses `EnemyInstance` and 4.5 uses `SlotState`, `HeroCounters`, but nothing defines their fields or says who may write which. Seven questions need an answer before any story starts:

1. Is `EnemyInstance` the right name and shape, and where do HP and slow live?
2. How is "Combat is the only HP writer" kept true in a language with no private or read-only members?
3. How does WaveSim hand out the roster so no reader can change it, given that ADR-0002 left `make_read_only()` versus a copy open?
4. How do ties break, and what stops a system holding a reaped enemy?
5. What do tower and hero instances hold, so `ReadContext.entity: RefCounted` (ADR-0001) can hold any of them?
6. What are the counter records?
7. What does `snapshot()` return, so ADR-0004's harness can compare two battles tick by tick?

### Constraints
- One door for damage (`deliver`), one for time (`tick`), one for stats (the accessor). Architecture principle 2.
- GDScript has no read-only member and no friend access. Ownership is a rule plus a test, as in ADR-0001.
- Retry rebuilds, never resets. A retried battle's snapshot equals a fresh one and the old battle's `weakref` is null (Flow criterion). So the object graph has no reference cycle (registry `system_holds_battle`).
- Combat reads no catalogue (Combat Rule 9). The Data GDD says "never cache at spawn"; `max_hp` is the one allowed exception.
- At most 48 enemies alive (TR-enemy-007), 5 slots (Enemy & Wave L-rules), 2 ms per tick proposed (ADR-0003).
- Gameplay values come from data. Structural constants (the field rectangle, `Battle.DT`) are injected, not typed into sim code.

### Requirements
- TR-combat-001: all damage through `deliver(event)`, one event per victim, only in a tick.
- TR-combat-002: only HP removed counts; per-source counters readable after the outcome.
- TR-combat-003: all hits are instant; victims computed at release.
- TR-combat-004: one slow slot per enemy, whole ticks, stronger replaces, equal keeps longer, weaker ignored.
- TR-combat-005: pure targeting helpers; ties by lowest `spawn_id`; skip the dead.
- TR-combat-006: Health and Status attach to the enemy instance; Combat reads no catalogue.
- TR-enemy-001: one path per stage; geometry is data on the Stage record.
- TR-enemy-002: no randomness; absolute spawn schedule; battle-wide `spawn_id`.
- TR-enemy-003: speed read through the accessor each use, times `speed_factor`; one cached position per enemy per tick.
- TR-enemy-004: leaks fire in `spawn_id` order, before `waves_complete`; a fatal leak stops the loop.
- TR-enemy-005: reap in `spawn_id` order; the clear check runs every tick while a wave is active.
- TR-enemy-006: `roster()` and `targets()` read-only, valid in the reader's slot; targetable only inside the field.

## Decision

### 1. Names and files
`EnemyInstance` is confirmed. It is the typed enemy runtime object that architecture 4.4 and ADR-0002 already name, so no table changes. All sim data classes below are `RefCounted`, one `class_name` per file, under `res://src/sim/` (`core/`, `combat/`, `wave/`, `tower/`, `hero/`). Tests go in `res://tests/unit/sim/` and `res://tests/integration/sim/`.

```gdscript
class_name SimEntity extends RefCounted            # base of every runtime instance
var def_id: StringName                             # set once in _init, never assigned again
var level: int = 0                                 # 0 means "no level" (ADR-0001); towers 1..level_count

class_name EnemyInstance extends SimEntity
var spawn_id: int                                  # set once; battle-wide; never reused
var distance: float                                # WaveSim writes, in move
var position: Vector2                              # WaveSim writes; cached once per tick in move
var in_play: bool = true                           # WaveSim writes; false after a leak or a reap
var health: EnemyHealth                            # Combat creates (attach) and writes
var status: EnemyStatus                            # Combat creates (attach) and writes

class_name EnemyHealth extends RefCounted
func hp() -> float
func max_hp() -> float
func is_dead() -> bool                             # hp <= 0.0
# Combat-only mutators: seed(max_hp: float), remove(applied: float)

class_name EnemyStatus extends RefCounted
func slow_strength() -> float                      # 0.0 when the slot is empty
func slow_ticks_left() -> int
# Combat-only mutators: set_slow(strength: float, ticks: int), count_down()

class_name TowerInstance extends SimEntity         # slot_index: int, cooldown_left: int (ticks); TowerSim writes
class_name HeroInstance extends SimEntity          # position: Vector2; level stays 0 (HeroDef has no levels); HeroSim writes
```

`SimEntity` is a plain `RefCounted`, so `ReadContext.entity: RefCounted` (ADR-0001) holds any of the three without a change to ADR-0001. A later Stat and Modifier ADR may narrow `entity` to `SimEntity`, which then lets it read `def_id` and `level` with no type test. No code reads `entity` at MVP.

### 2. Where HP and slow live, and who writes them
Health and Status are two components held by the enemy instance (`enemy.health`, `enemy.status`). This is TR-combat-006 as written ("attach to an enemy instance"). WaveSim calls `combat.attach(enemy, max_hp)` once, in the add-enemy step. `attach` creates both components, seeds Health from `max_hp`, and is the only place `health` and `status` are assigned. The components have no cycle to the enemy: the enemy holds them, they hold numbers.

Write rules (ownership rules 1 and 2 of the architecture):

| Field | Sole writer | Everyone else |
|-------|-------------|---------------|
| `health`, `status` and every field inside them | Combat | reads through `hp_left`, `is_dead`, `speed_factor`, or the component's read methods |
| `spawn_id`, `def_id`, `distance`, `position`, `in_play`, roster membership | WaveSim | reads |
| `TowerInstance` fields, gold, slot table | TowerSim | reads |
| `HeroInstance` fields | HeroSim | reads |

The mutators on the components are public methods because GDScript has no friend access. They are documented "Combat only" and a test enforces it (section 11). Writing HP is therefore a call to `EnemyHealth.remove`, which only `Combat.deliver` makes. Any other call site fails the ownership scan.

### 3. Combat
Combat is built with `Combat.new(latch: HaltLatch, ticks: TickConverter, dev_error: Callable)`. It holds no catalogue, no accessor, no enemy list and no reference to any other system.

```gdscript
enum SourceKind { TOWER, HERO, BURST }             # passed as int, ADR-0002

class_name DamageEvent extends RefCounted          # fields set in _init, never written after
var target: EnemyInstance
var amount: float
var source_kind: int
var source_id: StringName                          # the dealer's def_id; the grantor, if ever, gets its own field

class_name Combat extends RefCounted
const VIEW_SIGNALS: Array[StringName] = [&"attack_fired", &"damage_applied"]
func attach(enemy: EnemyInstance, max_hp: float) -> void
func deliver(event: DamageEvent) -> float
func apply_slow(enemy: EnemyInstance, strength: float, seconds: float) -> void
func report_attack(source_kind: int, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func tick_status(roster: Array[EnemyInstance]) -> void            # the Status slot
func speed_factor(enemy: EnemyInstance) -> float
func hp_left(enemy: EnemyInstance) -> float
func is_dead(enemy: EnemyInstance) -> bool
func first_in(list: Array[EnemyInstance], from: Vector2, range: float) -> EnemyInstance
func nearest_in(list: Array[EnemyInstance], from: Vector2, range: float) -> EnemyInstance
func all_in_radius(list: Array[EnemyInstance], center: Vector2, radius: float) -> Array[EnemyInstance]
func counters() -> CombatCounters
func enemy_snapshot(enemy: EnemyInstance) -> Dictionary          # used by WaveSim.snapshot()
func snapshot() -> Dictionary
```

The `...` in architecture 4.4's `first_in` is `from: Vector2, range: float`: the range filter lives in the helper, as Combat Rule 10 says "ranges passed in".

**`deliver`**, in order, with an `if` for every check (registry `assert_for_runtime_checks`):
1. If the latch is halted, return `0.0` and change nothing. The result must not change after an outcome (Flow Rule 15), and ADR-0002 declaration rule 4 forbids emitting then. Combat GDD edge case "needs no `halted()` of its own" stays true for slot skipping; this check is the emitter rule.
2. If the event or its target is null, or the target is not `in_play`, call `dev_error` and return `0.0`. This is the "removed enemy" guard of the Combat edge cases.
3. If the target is dead, return `0.0`: nothing is applied, emitted or counted (Rule 4).
4. If `amount` is not finite or is negative, call `dev_error` and return `0.0` (Rule 3). If it is `0.0`, return `0.0` with no signal.
5. `applied = minf(amount, hp)`; `health.remove(applied)`, which sets `hp` to exactly `0.0` when `applied == hp`. Add `applied` to the counter for `source_id` (kind kept beside it), then emit `damage_applied(event, applied, position_copy)` where the position is `target.position`, a `Vector2` value. Return `applied`.

**One door, checked by a scan.** Only `TowerSim` and `HeroSim` call `deliver` in game code (WaveSim's tests may call it for test kills, per the Combat GDD). Both call it inside their tick slot, so "only in a tick" (TR-combat-001) follows from the slot order. Commands never call `deliver`: a burst command sets state and the release happens in the hero slot (Combat Rule 2). Section 11 scans for any other caller.

**Targeting helpers** read `enemy.position` and `enemy.distance`, scan without sorting, and skip any enemy that is dead or not `in_play`.
- `first_in`: the in-range enemy with the greatest `distance`. Exact float compare. A tie goes to the lower `spawn_id`, compared explicitly, never by list position, so a caller who reorders a list gets the same answer.
- `nearest_in`: smallest squared distance to `from`, within `range`, ties by lower `spawn_id`.
- `all_in_radius`: `dx*dx + dy*dy <= radius*radius`, inclusive (Combat formula `in_radius`). Returns a new typed array in input order.
- A slow tower's "first unslowed" rule stays in the caller (Combat Rule 10): it builds a list of in-range enemies whose `speed_factor` is `1.0` and falls back to the full in-range list. There is no extra helper.

**`report_attack`** emits `attack_fired` after the same halted check. Tower and Hero call it before their `deliver` calls (Tower Rule 9 step 4; Hero Rule 8). This names the call the GDDs describe as "report the attack".

### 4. Slow
Slow is one slot per enemy, held in `EnemyStatus` as `slow_strength` and `slow_ticks_left`, both written only by Combat (TR-combat-004).

- `apply_slow(enemy, strength, seconds)`: do nothing if halted or the enemy is dead (Rule 7). Call `dev_error` and do nothing if the enemy is not `in_play` or `strength` is outside `0 < strength < 1`. `ticks = max(1, ticks.to_ticks(seconds))` (the Data GDD floors `slow_duration` at one tick). If the slot is empty, set it. Else if `strength` is greater, replace both fields. Else if equal, keep the larger `slow_ticks_left`. Else ignore. A stronger slow with less time replaces entirely.
- `speed_factor(enemy)` is `1.0 - slow_strength` while `slow_ticks_left > 0`, else `1.0`. It is a pure read, valid at any time.
- `tick_status(roster)` runs in the Status slot, after WaveSim's advance and before the towers. For each living enemy in roster order with `slow_ticks_left > 0`, it subtracts one; at `0` it clears the strength to `0.0`. A slow applied by a tower in tick T first affects the move of tick T+1 and counts down after it, so it affects exactly `ticks` moves (Combat formula note). Battle's Status slot calls `combat.tick_status(wave.roster())`.
- Slow is not a stat and never goes through the accessor (Rule 8).

`TickConverter` is the one change to the builder's wiring. Combat needs `to_ticks`, StageFlow owns the public `to_ticks`, and StageFlow reads Combat's counters for the result. A Combat that held StageFlow (or a Callable bound to it) would form a cycle. So `to_ticks` is implemented once in a small pure `TickConverter(dt: float)` with `to_ticks(seconds) -> int` and a `dt` field. The builder creates it first with `Battle.DT` and hands it to Combat, WaveSim and StageFlow. `StageFlow.to_ticks` forwards to it, so ADR-0002's table is unchanged and there is still one conversion. The formula is the Enemy & Wave one, `round(seconds / dt)` with halves away from zero; for the non-negative values it receives, it is written `floori(seconds / dt + 0.5)` so it does not depend on the engine's rounding function (V5).

### 5. The roster: WaveSim is the only writer
WaveSim is built with `WaveSim.new(stage: StageDef, catalogue: Catalogue, stats: StatAccessor, combat: Combat, ticks: TickConverter, latch: HaltLatch, field: Rect2, dev_error: Callable)`. This answers the seams Enemy & Wave's open question lists (constructor inputs, the two tick entries, add-enemy, the development-error sink, the field rectangle, the snapshot).

**State.** `_roster: Array[EnemyInstance]` in ascending `spawn_id` order (appends only grow it, removals keep the order), `_targets: Array[EnemyInstance]` in the same order, `_next_spawn_id: int` (starts at `0`, plus one per enemy, never reused; an `int` is 64-bit so it cannot wrap), `_ctx: Dictionary[int, ReadContext]` (one context per enemy, made at add, erased at leak or reap, so Enemy & Wave Rule 9's "made once per enemy" holds), the wave index, `wave_tick`, the spawn cursor, `_got_through: Dictionary[StringName, int]`, and a `PathTrack`.

**Stage geometry (A3, confirmed).** WaveSim reads `stage.path_points()` once at construction into `PathTrack`, a private pure object holding the points and a cumulative-length `PackedFloat64Array`, with `length` and `position_at(distance: float) -> Vector2` (the Enemy & Wave position formula; the last point once `distance >= length`). TowerSim reads `stage.slot_positions()`; HeroSim reads `hero_start`, `pin_rect` and `pin_exclusion()`. All come from the `StageDef` the builder passes in (ADR-0001 section 6), never from a scene. The stage scene draws the path from the same points, read from the catalogue. 4.7 changed packed array element writes so they no longer call the property's setter. `PathTrack` builds its arrays in locals and assigns each once, and no sim class declares a setter on a packed-array property, so the change cannot matter here.

**Two tick entries** (ADR-0003 slot order, unchanged):
- `advance()` (slot 2): (a) spawn every member due at `wave_tick`, groups in authored order, members ascending, each through `add_enemy`; (b) move every enemy in roster order: `speed = stats.get_float(ctx, &"move_speed") * combat.speed_factor(e)`, `distance = minf(distance + speed * ticks.dt, length)`, `position = track.position_at(distance)`, checking the latch after each read; (c) leak: for each enemy at `distance >= length`, in ascending `spawn_id`, read `lives_cost`, set `in_play = false`, remove it from the roster, erase its context, add one to `_got_through[def_id]`, emit `enemy_leaked(lives_cost)`, and stop the loop if the latch turned halted; (d) rebuild `_targets` from the roster, keeping enemies whose centre is inside `field` (edges inclusive, as the Enemy & Wave edge case says; compared with explicit `>=` and `<=`, not `Rect2.has_point`, whose edge rule is not in the reference); (e) `wave_tick += 1`.
- `reap()` (slot 6): for each dead enemy in ascending `spawn_id`, read `bounty`, set `in_play = false`, remove it, erase its context, emit `enemy_killed(bounty)`, checking the latch after each read and emit. Then rebuild `_targets` from the survivors. Then, every tick while a wave is active, run the clear check: schedule exhausted and roster empty emits `waves_complete()` for the last wave index and `wave_cleared(intermission_duration)` otherwise, after committing state (Enemy & Wave Rule 11).

**`add_enemy(def_id: StringName) -> EnemyInstance`** is the one add step. The schedule uses it, and so can a splitter later (Rule 15) or a test. No `BattleCommand` can reach it. It creates the instance with the next id (not yet consumed), reads `max_hp` through a context, and returns `null` without consuming the id if the latch turned halted, so a bad read persists nothing. Otherwise it consumes the id, calls `combat.attach`, appends to the roster, stores the context, and sets `position` to the path start.

**`spawn_id` and the tie-break.** The id is an `int` assigned in schedule order and never reused, so it is a total order over a battle. Every place that needs an order or a tie uses it: leaks and reaps in ascending order, and the three helpers pick the lower id on a tie (TR-enemy-002, TR-enemy-004, TR-combat-005). An enemy exposes its `spawn_id`, `def_id`, `distance` and `position` as Enemy & Wave Rule 14 requires.

**`roster()` and `targets()`: a copy, chosen now.** ADR-0002 left the choice to "the first WaveSim story". This ADR chooses: each call returns a **new typed array** filled by `append` from the private one. A caller can then write to it without touching the simulation or another reader. `make_read_only()` is not used, because its presence on 4.7.2 is NOT SOURCEABLE (V1) and a sealed shared array would also fail to be rebuilt in place. `roster()` returns every enemy not yet removed, corpses awaiting the reap included (Rule 14). `targets()` returns the inside-the-field subset built in `advance`, minus anything reaped. A returned array is a snapshot at the call: it is valid for the reader's own tick slot, and a reader must not keep it past the slot because the enemies in it may die or be reaped later (ADR-0002 guideline). The elements are shared objects, so their fields are protected by section 2's rule and test, not by the copy.

**Cost of the copy.** E = 48 enemies, S = 5 towers. In one tick `targets()` is called at most S + 1 times (each tower that is ready, plus the hero) and `roster()` once by the Status slot, so about 7 copies of at most 48 appends, about 340 appends per tick and 1,700 in a frame that runs the 5-tick cap. That is an estimate, unmeasured. It sits beside the Combat GDD's own unmeasured "400-check targeting" estimate of under 2 ms. The first WaveSim story measures it. If the copies cost more than 10% of the 2 ms tick budget, the fallback is one shared sealed array per slot (V1), decided then.

`got_through_by_type()` returns a copy of `_got_through`, as ADR-0002 says. It is a count kept only for the result.

### 6. Reaping, and why no system holds a target
A reaped or leaked enemy has `in_play = false` and leaves `_roster`. It is still a live object while anything references it, because `RefCounted` frees it only at the last release. So a held reference cannot crash. The risk is a stale answer: a tower aiming at a corpse. Three rules close it:
1. **Re-pick every attack.** Tower and Hero call `targets()` and a Combat helper each time they attack and keep nothing (Combat Rule 10).
2. **No member holds an enemy.** No class outside WaveSim and Combat declares a class-level variable of type `EnemyInstance` or `Array[EnemyInstance]`. `DamageEvent.target` is the one exception, and a listener must not keep an event (ADR-0002). A view that needs to remember an enemy keeps its `spawn_id` (an `int`) and looks it up in `roster()` each frame.
3. **`deliver` guards the rest.** A stale target gets a development error and `0.0` (section 3, step 2).

Section 11 enforces rule 2 with a scan.

### 7. Tower and hero instances
`TowerInstance` is created by `TowerSim.build` (def_id, `level = 1`, `slot_index`, `cooldown_left = 0`: a new tower starts ready, Tower Rule 11). `upgrade` raises `level` and leaves `cooldown_left` alone (Rule 12). TowerSim holds `Array[TowerInstance]` of fixed length S with `null` for an empty slot, so slot index is identity and the loop is by ascending index (Tower Rule 9). `slot_state(i)` returns a fresh `SlotState` copy.

`HeroInstance` is created at build with the hero's `def_id`, `level = 0`, and `position = hero_start`. The pin, leash, burst and telegraph state stay private to HeroSim: only `def_id`, `level` and `position` are on the instance because those are what a future "towers near the hero" stat needs through `ReadContext.entity` (Data GDD Rule 10). HeroSim has no HP at MVP (Hero GDD).

### 8. A1 confirmed
`ProjectileSpawner` is cut and the tick order stays: StageFlow, WaveSim `advance`, Status (`combat.tick_status`), TowerSim by slot index, HeroSim then burst, WaveSim `reap`. `deliver` stays the only door for damage. If projectiles ever return, they arrive as a new system in its own tick slot that holds in-flight events and calls `deliver` on impact. That needs its own ADR and a new slot, and no `deliver` signature changes. No placeholder is built now.

### 9. Records
All are read-only `RefCounted` records, built fresh on each read, with fields set in `_init` and no setters (the ADR-0001 pattern). ADR-0002 owns the table; these are the field lists it asked each story to define.

| Record | Fields (GDD source) |
|--------|---------------------|
| `SlotState` | `tower_id: StringName` (`&""` unbuilt), `level: int` (`0` unbuilt), `cooldown_left: int` ticks |
| `HeroCounters` (Hero Rule 16) | ints: `repins`, `bursts_started`, `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `bursts_emptied_by_kill`, `bursts_walked_out`, `burst_victims`, `burst_kills`; `kills_per_burst() -> Array[int]` and `kills_on_hit_3() -> Array[int]` (copies) |
| `CombatCounters` (Combat Rules 3, 5) | `source_ids() -> Array[StringName]` (sorted by text), `amount(source_id) -> float`, `kind(source_id) -> int`, `kind_total(kind: int) -> float`, `total() -> float`, `hero_share() -> float` |
| `BattleResult` (Flow Rule 15) | `outcome: StringName` (`&"none"`, `&"won"`, `&"lost"`, `&"fatal"`), `last_wave_started: int`, `lives_left: int`, `damage: CombatCounters` |

`CombatCounters` sums in sorted source order so the float totals are the same on every run. `hero_share()` is `(kind_total(HERO) + kind_total(BURST)) / total()`, `0.0` when the total is `0.0` (Combat formula `hero_share`). Live counts sit in the owner's private fields. Counters stay readable after the outcome until the battle is freed. A per-call copy allocates one small object, about 12 ints for `HeroCounters` and one entry per source for `CombatCounters`, so a HUD read per frame is acceptable. Flow's story and ADR-0008 may add fields to `BattleResult` by updating ADR-0002's table.

### 10. `snapshot() -> Dictionary` on every system
Every system in `Battle.systems()` (StageFlow, WaveSim, Combat, TowerSim, HeroSim) has `func snapshot() -> Dictionary`. ADR-0004's harness calls it on each, in `systems()` order, and compares two runs with `==`. Rules:

- **Plain data only.** Values are `bool`, `int`, `float`, `String` (a `StringName` is stored as a `String`), `Vector2`, `Array` and `Dictionary`. No object, no `Callable`, no `RefCounted`.
- **Deterministic order.** A sequence is an `Array` in the order given below. A `Dictionary` is used only as a record with a fixed key set. Anything keyed by id becomes an array of records sorted by id, so no result depends on dictionary order (V3).
- **Everything that can change a later tick or the result, and nothing else.** No derived caches, no engine value, no signal connection. Each fact appears in exactly one system's snapshot.
- **Read only.** A snapshot emits nothing, advances nothing, never calls the `StatAccessor` (a bad read would call the failure handler) and works while halted.
- **Stable keys.** Removing, renaming or reordering a key needs a note in this ADR's table and a refresh of ADR-0004's golden files. A story may add a key at the end.

| System | Snapshot content |
|--------|------------------|
| StageFlow | `state`, `lives`, `intermission_left`, `halted`, `clock_running`, `last_wave_started`, `outcome` |
| WaveSim | `wave_index`, `wave_active`, `wave_tick`, `spawn_cursor`, `next_spawn_id`, `got_through` (array of `[def_id, count]`, sorted by `def_id`), `enemies` (array in `spawn_id` order of `{spawn_id, def_id, distance, position, in_play, health}`, where `health` is `combat.enemy_snapshot(enemy)`), `target_ids` (array of `spawn_id`), `context_count` |
| Combat | `dealt` (array of `{source_id, kind, amount}` sorted by `source_id`). `enemy_snapshot(enemy)` returns `{hp, max_hp, slow_strength, slow_ticks_left}`, so Combat defines the format of the state it owns while WaveSim, which holds the roster, lists it |
| TowerSim | `gold`, `slots` (array of S records `{slot_index, tower_id, level, cooldown_left}` in index order, empty slots with `tower_id = ""`) |
| HeroSim | `def_id`, `level`, `position`, `pin_state`, `pin_target`, `burst_state`, `cooldown_left`, `telegraph_left`, `aim_point`, every `HeroCounters` field, and any other field HeroSim holds that changes a later tick (the story lists them here as it adds them) |

`context_count` equals the roster size after every tick. The harness asserts it, which catches a leaked context. Battle's own `tick_count` and the command log belong to ADR-0003 and ADR-0004. The harness may add them under its own keys.

### 11. Enforcing ownership (the tests)
Enforcement is the rule plus tests, as ADR-0001 does for records.
1. **Ownership scan** (`tests/integration/sim/ownership_scan_test.gd`; it reads source files, so it is an integration test). It fails if, under `res://src/`: (a) `EnemyHealth.remove`, `EnemyHealth.seed`, `EnemyStatus.set_slow` or `count_down` is called outside `src/sim/combat/`; (b) `deliver(` is called outside `tower_sim.gd` and `hero_sim.gd`; (c) a write to `spawn_id`, `distance`, `in_play`, or the roster arrays appears outside `src/sim/wave/` (an `_init` set is the only write to `spawn_id` and `def_id`); (d) an unindented `var` of type `EnemyInstance` or `Array[EnemyInstance]` appears outside `src/sim/wave/` and `src/sim/combat/`. The scan is derived from the file tree, not from a list of files. It is a line scan and is fooled by a call built from a string, which a reviewer still catches.
2. **HP conservation test.** Over a scripted battle, the sum of `applied` returned by every `deliver` equals the sum of HP removed from every enemy and equals `CombatCounters.total()`. Overkill adds nothing.
3. **No bypass test.** A fixture enemy is hit by every tower role and a burst; `hp_left` falls only by the applied amounts.

### Architecture Diagram

```
Catalogue --StageDef--> WaveSim                              builder order (ADR-0008):
                         |  advance(): spawn, move, leak       TickConverter, Combat, WaveSim,
 TickConverter ----+     |  reap():    kills, clear check      TowerSim, HeroSim, StageFlow
   (dt, to_ticks)  |     v
                   |   _roster / _targets  (WaveSim private, copies out)
                   |     |  EnemyInstance { spawn_id, def_id, distance, position, in_play,
                   v     |                  health: EnemyHealth, status: EnemyStatus }
                Combat <-+- attach(enemy, max_hp), deliver(event), apply_slow, tick_status(roster)
                   ^   \
   TowerSim, HeroSim    `--damage_applied, attack_fired--> views (copied positions)
   (targets() copy -> first_in / nearest_in / all_in_radius -> deliver)

 Writers:  HP and slow = Combat   roster and position = WaveSim   gold, slots = TowerSim   hero = HeroSim
 Every system: snapshot() -> plain Dictionary  --> ADR-0004 harness
```

### Key Interfaces
`SimEntity`, `EnemyInstance`, `EnemyHealth`, `EnemyStatus`, `TowerInstance`, `HeroInstance`, `DamageEvent`, `TickConverter`, `SlotState`, `HeroCounters`, `CombatCounters`, `BattleResult`; `Combat` as in section 3; `WaveSim.advance()`, `reap()`, `add_enemy(def_id)`, `roster()`, `targets()`, `wave_index()`, `got_through_by_type()`; `snapshot() -> Dictionary` on StageFlow, WaveSim, Combat, TowerSim, HeroSim.

### Implementation Guidelines
- Only Combat may call `EnemyHealth.remove` or `seed` and `EnemyStatus.set_slow` or `count_down`. Only WaveSim may write `spawn_id`, `distance`, `position`, `in_play` or the roster. Nothing else may write HP, status or the roster.
- Every damage point must go through `Combat.deliver`, one event per victim, called only from `TowerSim` or `HeroSim` inside their tick slot. A command must never call it.
- `deliver` must return `0.0` and change nothing once `halted()` is true, and must never emit then.
- Code must not hold an `EnemyInstance` or `Array[EnemyInstance]` in a member variable outside WaveSim and Combat. A view must key by `spawn_id` and re-read.
- Code must re-pick the target on every attack. A listener must not keep a `DamageEvent`.
- Ties must break by lower `spawn_id`, compared explicitly, never by list position.
- `roster()` and `targets()` must return a new typed array on every call. Code must not rely on `make_read_only()`.
- WaveSim must assign `spawn_id` only in `add_enemy`, only after the `max_hp` read passed the halted check, and must never reuse an id.
- Every count of time must use `TickConverter`. No sim class may convert seconds to ticks itself.
- No sim class may declare a setter on a packed-array property.
- `snapshot()` must return plain data in the stated order, must not call the `StatAccessor`, and must not mutate.
- Every override a story adds must end in an explicit `return` (4.7 typed-return rule, ADR-0003).
- Checks must use `if` and `dev_error`, never `assert` (registry `assert_for_runtime_checks`).

## Alternatives Considered

### Alternative 1: Combat keeps HP and slow in side tables keyed by `spawn_id`
- **Description**: `EnemyInstance` has no health fields; Combat holds `Dictionary[int, float]` for HP and another for slow.
- **Pros**: Combat's state cannot be reached from an enemy reference at all, so "only writer" is structural.
- **Cons**: Needs a release call at every leak and reap or the tables grow; a forgotten release is a leak the snapshot must hunt; every read is a dictionary lookup; TR-combat-006 says "attach to an enemy instance".
- **Rejection Reason**: The components give the same single-writer rule at the class level, are freed with the enemy, and match the requirement text.

### Alternative 2: Flat fields on `EnemyInstance` (`hp`, `slow_strength`, `slow_ticks`)
- **Description**: One object, no components.
- **Pros**: Fewest objects, simplest reads.
- **Cons**: Every field is writable by everyone, and the ownership scan would have to know which fields on one class belong to whom.
- **Rejection Reason**: Two components make the ownership boundary a type, so the scan is a simple call-site check. The cost is 96 extra tiny objects at the 48-enemy cap.

### Alternative 3: Enemies as Dictionaries, or parallel packed arrays (data-oriented)
- **Description**: A Dictionary per enemy, or `PackedFloat32Array` columns for HP, position and slow indexed by slot.
- **Pros**: Fewer allocations; cache friendly.
- **Cons**: A Dictionary breaks typing and the read-only rule (the reason ADR-0001 refuses Dictionary records). Parallel columns need slot reuse or compaction, which breaks stable identity, and they put the 4.7 packed-array write change directly in the hot path.
- **Rejection Reason**: 48 enemies do not need it, and the cost in safety is real.

### Alternative 4: `make_read_only()` on shared roster arrays
- **Description**: WaveSim publishes one sealed array per change and returns it.
- **Pros**: No copying.
- **Cons**: Presence and behaviour on 4.7.2 are NOT SOURCEABLE (V1); a sealed array cannot be updated in place, so WaveSim would rebuild and reseal on every change anyway.
- **Rejection Reason**: Copies need no unsourced API. Kept as the profiled fallback.

### Alternative 5: Keep a spawner behind `deliver` now (the original ProjectileSpawner)
- **Description**: `deliver` hands events to a spawner that applies them later.
- **Pros**: Projectiles would need no later change.
- **Cons**: All hits are instant at MVP (Combat Rule 1), so it adds a queue, a tick slot and delayed death for no use. It also makes a burst's victims differ from the tick that released it.
- **Rejection Reason**: A1 is decided. A projectile system later is a new slot that calls the same `deliver`.

### Alternative 6: Attackers keep their target between attacks
- **Description**: A tower holds its current target until it dies or leaves range.
- **Pros**: Fewer scans.
- **Cons**: Stale references after a reap; behaviour then depends on who reaped first; the 400-check worst case is small anyway.
- **Rejection Reason**: Combat Rule 10 re-picks every attack. The ownership scan enforces it.

### Alternative 7: Harness snapshot by reflection (`get_property_list`)
- **Description**: ADR-0004 walks each system's properties.
- **Pros**: No per-system method.
- **Cons**: Picks up private caches and objects, so equality breaks or hides state; order is the engine's.
- **Rejection Reason**: Each system lists what it owns, in a stated order.

## Consequences

### Positive
- One definition of an enemy, one writer per field, and a test that checks it.
- `EnemyInstance`, `SlotState` and the counters need no change to ADR-0002.
- No reference cycle: `Battle` to systems to instances to components. A retried battle leaves nothing behind.
- Reaping cannot leave a live reference that matters, because nothing holds an enemy between attacks.
- The harness gets a snapshot with no reflection, and context leaks show up as a count mismatch.
- `ReadContext.entity` can carry a tower, hero or enemy with no ADR-0001 edit.

### Negative
- Component mutators are public by language limit; safety is a scan, not the compiler.
- Copies on every `roster()` and `targets()` call, and on every record read. Small, unmeasured.
- One more injected object (`TickConverter`) and one more constructor argument per system.
- Five snapshot methods to keep in step with their systems.

## Risks
- **The ownership scan misses an indirect write.** Mitigation: the HP conservation and no-bypass tests catch the effect, and review checks new call sites of the guarded methods.
- **Copy cost exceeds budget on the phone.** Mitigation: the first WaveSim story measures; the fallback is sealed shared arrays (V1) or a per-slot cache.
- **A snapshot omits a field and hides a divergence.** Mitigation: the snapshot rule is "everything that can change a later tick"; the harness's replay test (ADR-0004) fails when two runs differ in a later tick, and the story adds the missing key.
- **`TickConverter` rounding differs from the GDD at a half value.** Mitigation: a unit test pins the half cases (0.5 tick, 1.5 ticks) against the Enemy & Wave examples, such as 0.125 s giving 0, 8, 15, 23.
- **An old `CombatCounters` is read after the battle is freed.** Mitigation: it is a copy, so the Retry rebuild frees nothing it needs.
- **GDD `deliver` edge case wording.** The Combat GDD says Combat needs no `halted()` of its own. Mitigation: the Migration Plan edits that line to match section 3 step 1.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | Rule 2, Rule 3 (TR-combat-001): one door, inside the tick, real damage only | Section 3 `deliver`; section 11 scan; callers are the tower and hero slots |
| combat-damage.md | Rules 4, 5 (TR-combat-002): death at once, counters by source and kind, readable after the outcome | Section 3 steps 3 to 5; `CombatCounters` (section 9) |
| combat-damage.md | Rule 1, Rule 6 (TR-combat-003): instant hits, victims at release | Section 3 helpers; section 8 (no spawner); victims come from `targets()` at the release slot |
| combat-damage.md | Rule 7, Rule 8 (TR-combat-004): one slow slot, whole ticks | Section 4 |
| combat-damage.md | Rule 10 (TR-combat-005): helpers over a caller list, ties by `spawn_id`, skip the dead | Section 3 helpers and section 5 |
| combat-damage.md | Rule 9 (TR-combat-006): Health and Status attach; no catalogue; `max_hp` seeds once | Sections 2, 3 (`attach`), 5 (`add_enemy`) |
| combat-damage.md | Open question: a future spawner behind `deliver`; how Health and Status attach | Sections 8 and 2 |
| enemy-wave.md | Rules 1, 2 (TR-enemy-001): one path; geometry on the Stage record (A3) | Section 5 `PathTrack` and `StageDef` reads |
| enemy-wave.md | Rules 7, 8 (TR-enemy-002): absolute schedule, battle-wide `spawn_id` | Section 5 `advance`, `add_enemy`, `spawn_id` |
| enemy-wave.md | Rule 9 (TR-enemy-003): speed through the accessor times `speed_factor`; position cached | Section 5 move step, `_ctx` per enemy |
| enemy-wave.md | Rule 10 (TR-enemy-004): leaks in `spawn_id` order, fatal leak stops the loop | Section 5 leak step |
| enemy-wave.md | Rule 11 (TR-enemy-005): reap order, clear check every tick | Section 5 `reap` |
| enemy-wave.md | Rule 14 (TR-enemy-006): `roster()` and `targets()` read-only and slot-scoped; edge inclusive | Section 5 copies and the `targets` rule |
| enemy-wave.md | Rule 15, Open Question on seams | One add step; constructor inputs; two entries; `dev_error`; field rectangle; snapshot |
| game-state-stage-flow.md | Retry criterion: a retried battle's snapshot equals a fresh one; `weakref` null | Section 10; no cycle (V2) |
| tower-system.md | Rules 9, 11, 12: slot-index order, new tower starts ready, upgrade keeps the timer | Section 7 |
| hero-system.md | Rule 16: counters | `HeroCounters` (section 9) |

## Performance Implications
- **CPU**: Roster and target copies about 340 appends per tick at the E = 48, S = 5 worst case, estimated and unmeasured, against a proposed 2 ms tick. `deliver` is a handful of comparisons. Snapshots run only in tests.
- **Memory**: 48 enemies × 3 objects, plus up to 5 tower and 1 hero instance, plus small per-read records. Negligible.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
No code exists yet. **These edits land in the same change that marks this ADR Accepted.** None is made by this draft.

- `docs/architecture/architecture.md`:
  - 4.4: replace the `EnemyInstance` comment with the class block of section 1; add `attach`, `report_attack`, `tick_status`, `counters`, `snapshot`; fill `first_in(list, from, range)`; add the `deliver` halted note. Add `EnemyHealth`, `EnemyStatus` to Combat's "Owns".
  - 4.5: WaveSim gets `advance()`, `reap()`, `add_enemy(def_id)`; the records get the field lists of section 9; the invariant line "no system holds a target between attacks" cites section 6; add `snapshot()` to every system.
  - 4.3: `systems()` comment cites the snapshot rules of section 10.
  - 3.4: add `TickConverter` as the first object built; 3.1 slot 3 reads `combat.tick_status(wave.roster())`.
  - Module Ownership: Combat and WaveSim rows name the components and the roster rule; Ownership rule 2 adds "readers get copies".
  - Required ADRs: ADR-0005 row marked done once Accepted. Open Questions A1 and A3 notes cite this ADR.
- `docs/architecture/adr-0002-signal-contracts-and-wiring-conventions.md` (Accepted): in "Returned collections", record that WaveSim returns a new typed copy per call (this ADR); in "Reads" add `snapshot()` and cross-reference the record field lists; note that `Combat.report_attack` and `attach` are direct calls, not signals. A cross-reference, not a change of decision.
- `docs/architecture/adr-0003-frame-order-command-queue-ticks-and-view-update.md` (Accepted): add a cross-reference note that its slot names are `StageFlow`, `WaveSim.advance`, `Combat.tick_status`, `TowerSim`, `HeroSim`, `WaveSim.reap`. No change of decision.
- `docs/architecture/adr-0001-catalogue-storage-and-stat-accessor.md` (Accepted): one line under `ReadContext` that `SimEntity` (ADR-0005) is the common subclass held in `entity`. No change of decision.
- `design/gdd/combat-damage.md`: Edge Cases "Combat needs no `halted()` of its own" gains "`deliver` returns 0 once halted (ADR-0002 rule 4)"; Rule 10 `first_in(list, from, range)`; the Open Question rows on the spawner and the ADR are closed by ADR-0005.
- `design/gdd/enemy-wave.md`: Open Questions rows "Seams the criteria assume" and "Does the technical director accept moving path and slots" closed by ADR-0005 and ADR-0001; Rule 14 adds "copies".
- `design/gdd/game-state-stage-flow.md`: the Open Question on snapshots points to ADR-0004 and ADR-0005.
- `docs/registry/architecture.yaml`: registered with this ADR's write, as Proposed stances.

## Validation Criteria
- Unit: a 30 HP hit on 12 HP applies 12, leaves `hp` at exactly `0.0`, and counts 12; a second hit in the same tick returns `0.0`, emits nothing and counts nothing.
- Unit: `deliver` with a negative, NaN or infinite amount returns `0.0` and calls `dev_error`; with the latch halted it returns `0.0`, emits nothing and leaves counters unchanged.
- Unit: slow rules: empty set; stronger replaces with less time; equal keeps the longer; weaker ignored; a dead target ignored. A 0.5 s slow gives exactly `to_ticks(0.5)` slowed moves.
- Unit: `first_in`, `nearest_in` and `all_in_radius` break ties by lower `spawn_id` even when the list is reversed; `all_in_radius` includes the edge; all skip the dead and not-`in_play`.
- Unit: `roster()` and `targets()` return distinct typed arrays per call; writing to one changes nothing in WaveSim or another reader; an enemy on the field edge is in `targets()` and one just outside is not.
- Unit: `add_enemy` with a failing `max_hp` read returns `null` and does not consume an id; ids rise by one and are never reused.
- Integration: leaks fire in `spawn_id` order before `waves_complete`; a fatal leak stops the loop and pays no bounty; kills reap in `spawn_id` order.
- Integration: HP conservation and no-bypass tests (section 11).
- Integration: the ownership scan fails on a planted call to `EnemyHealth.remove` outside Combat (watched failing once, then restored).
- Harness (with ADR-0004): two battles with the same seed and command script give equal snapshots after every tick; a fresh battle equals a retried one; `context_count` equals the roster size every tick; every snapshot value passes the plain-data type check.
- Retry: a `weakref` to the old battle is null after `dispose()` and a frame (V2).
- Phone/first WaveSim story: record the copy cost per tick against the 10% line of section 5.

## Related
- Architecture: `docs/architecture/architecture.md` Module Ownership rules 1 and 2, 3.1, 3.4, 4.4, 4.5; Gate Findings TD recommendations (A1, A3); Open Questions A1, A3.
- ADR-0001, ADR-0002, ADR-0003 (all Accepted). ADR-0004 (drafted in parallel) uses section 10. ADR-0006 keys enemy views by `spawn_id`. ADR-0008 builds the classes with the inputs above.
- GDDs: `design/gdd/combat-damage.md`, `enemy-wave.md`, `tower-system.md`, `hero-system.md`, `game-state-stage-flow.md`, `data-config-pipeline.md`.
- Reviews: pending (godot-specialist and technical-director).
