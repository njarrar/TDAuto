# ADR-0005: Simulation State Attachment: Health, Status and Roster

## Status
Proposed

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
njarrar (project owner, approves at Accepted); lead-programmer (draft, autonomous mode). Revised after the technical-director and godot-specialist reviews (see Related).

## Summary
Combat, Enemy & Wave, Tower and Hero share runtime objects whose names, writers and lifetimes the architecture leaves open (`EnemyInstance` is named but not defined). This ADR confirms `EnemyInstance`, attaches Health and Status to it as two components that only Combat writes, makes WaveSim the sole writer of a roster it hands out as copies keyed by a battle-wide `spawn_id`, defines the tower and hero instances and the counter records, and gives every system a `snapshot()` whose format ADR-0004 owns.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (simulation data) |
| **Layer** | Core |
| **Knowledge Risk** | LOW to MEDIUM: plain `RefCounted` objects and typed collections; the one post-cutoff rule that touches the design is the 4.7 packed-array write change |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.7: packed array element writes; typed-return overrides), `deprecated-apis.md` (typed `Array[Type]`), `current-best-practices.md` (`@abstract`, lambda capture) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[K, V]` (4.4; used for `_ctx`, `_got_through`, `_dealt`, `_kind`, as ADR-0002 already does). The 4.7 packed-array rule shapes one choice: no sim class puts a setter on a packed-array property (section 5). The 4.7 typed-return rule applies to any override a story adds (ADR-0003) |
| **Verification Required** | **NOT SOURCEABLE** from `docs/engine-reference/godot/` (no core-class coverage), all `memory, unverified`: (V1) `Array.make_read_only()` exists and a write to a sealed typed array errors; not relied on, only the fallback if copy cost fails; (V2) a `RefCounted` cycle is never freed, and a `weakref` to an object goes null at once when its last reference drops (ADR-0004 H4); the design has no cycle and the Retry test proves it; (V3) `Dictionary` keeps insertion order and `==` ignores order; no result here depends on either; (V4) `Array.duplicate()` of a typed array returns a typed array that a typed parameter accepts, and an untyped `Array` is not accepted; (V5) `floori` and `is_finite`, as ADR-0001 and ADR-0003 use them; (V6) typed `Dictionary[K, V]`: `erase`, `duplicate()` keeps the types, and assignment of an untyped literal is refused or accepted as the story's parse check shows; (V7) `Array.sort_custom` is not stable, and `StringName` ordering may not equal text ordering; so every comparator here is strict and total with a final tie-break, and ids are sorted by `String(id)`. V1 to V7 are checked by the first WaveSim and Combat stories' parse checks and unit tests |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0002, ADR-0003 (all Accepted). ADR-0004 (Proposed): section 10 uses its snapshot format. ADR-0004 and ADR-0005 are accepted together |
| **Enables** | ADR-0006 (views key enemy nodes by `spawn_id`), ADR-0008 (the builder constructs these classes with the inputs listed here) |
| **Blocks** | Epics Combat, Enemy & Wave, Tower, Hero |
| **Ordering Note** | **Requirement on ADR-0008:** the builder creates `TickConverter` first, then Combat, WaveSim, TowerSim, HeroSim, StageFlow (architecture 3.4 with `TickConverter` added), and passes each system the inputs in sections 3 and 5 |

## Context

### Problem Statement
Enemy & Wave Rule 14 says an enemy exposes `spawn_id`, `def_id`, `distance` and `position`, and leaves "how Health and Status attach" to this ADR. Architecture 4.4 and 4.5 use `EnemyInstance`, `SlotState` and `HeroCounters` without fields or writers. Seven questions need an answer before any story starts:

1. Is `EnemyInstance` the right name and shape, and where do HP and slow live?
2. How is "Combat is the only HP writer" kept true with no private members?
3. How does WaveSim hand out the roster so no reader can change it (ADR-0002 left `make_read_only()` versus a copy open)?
4. How do ties break, and what stops a system holding a reaped enemy?
5. What do tower and hero instances hold, so `ReadContext.entity: RefCounted` (ADR-0001) holds any of them?
6. What are the counter records?
7. What does each system put in `snapshot()`?

### Constraints
- One door for damage (`deliver`), time (`tick`) and stats (the accessor). GDScript has no read-only member, so ownership is a rule plus a test, as in ADR-0001.
- Retry rebuilds. A retried battle's snapshot matches a fresh one and the old battle's `weakref` is null, so the object graph has no reference cycle (registry `system_holds_battle`).
- Combat reads no catalogue (Combat Rule 9); `max_hp` is the one value cached at spawn.
- At most 48 enemies alive (TR-enemy-007), 5 slots (Enemy & Wave L-rules), 2 ms per tick proposed (ADR-0003).
- Structural constants (the field rectangle, `Battle.DT`) are injected, not typed into sim code.

### Requirements
TR-combat-001 to 006 and TR-enemy-001 to 006 (one door in a tick; real damage and per-source counters; instant hits; one whole-tick slow slot; pure helpers with `spawn_id` ties; Health and Status attached with no catalogue; geometry on the Stage record; absolute schedule and battle-wide `spawn_id`; speed through the accessor with one cached position; leaks and reaps in `spawn_id` order; read-only roster valid in the reader's slot, targetable only inside the field).

## Decision

### 1. Names and files
`EnemyInstance` is confirmed, so ADR-0002's table does not change. All sim data classes are `RefCounted`, one `class_name` per file, under `res://src/sim/` (`core/`, `combat/`, `wave/`, `tower/`, `hero/`). Tests go in `res://tests/unit/sim/` and `res://tests/integration/sim/`.

```gdscript
class_name SimEntity extends RefCounted            # base of every runtime instance
var def_id: StringName                             # set once in _init
var level: int = 0                                 # 0 means "no level" (ADR-0001)

class_name EnemyInstance extends SimEntity
var spawn_id: int                                  # set once; battle-wide; never reused
var distance: float                                # WaveSim writes
var position: Vector2                              # WaveSim writes; cached once per tick
var in_play: bool = true                           # WaveSim writes; false after a leak or reap
var health: EnemyHealth                            # Combat creates (attach) and writes
var status: EnemyStatus                            # Combat creates (attach) and writes

class_name EnemyHealth extends RefCounted          # hp(), max_hp(), is_dead(); Combat-only: seed(), remove()
class_name EnemyStatus extends RefCounted          # slow_strength(), slow_ticks_left(); Combat-only: set_slow(), count_down()
class_name TowerInstance extends SimEntity         # slot_index: int, cooldown_left: int ticks; TowerSim writes
class_name HeroInstance extends SimEntity          # position: Vector2; level stays 0; HeroSim writes
```

`ReadContext.entity: RefCounted` (ADR-0001) holds any of the three. ADR-0001 stays unchanged; a later Stat and Modifier ADR may narrow `entity` to `SimEntity`. No code reads `entity` at MVP.

### 2. Where HP and slow live, and who writes them
Health and Status are components of the enemy instance (TR-combat-006). WaveSim calls `combat.attach(enemy, max_hp)` once in its add step; `attach` creates both and seeds Health. The components hold numbers and no back reference, so there is no cycle.

| Field | Sole writer |
|-------|-------------|
| `health`, `status` and every field inside them | Combat |
| `spawn_id`, `def_id`, `distance`, `position`, `in_play`, roster membership | WaveSim |
| `TowerInstance` fields, gold, slot table | TowerSim |
| `HeroInstance` fields | HeroSim |

The component mutators are public methods (no friend access). They are documented "Combat only" and the ownership scan of section 11 enforces it.

### 3. Combat
Built with `Combat.new(latch: HaltLatch, ticks: TickConverter, dev_error: Callable)`. It holds no catalogue, accessor, enemy list or other system.

```gdscript
enum SourceKind { TOWER, HERO, BURST }             # passed as int (ADR-0002)
class_name DamageEvent extends RefCounted          # target, amount, source_kind, source_id; set in _init only

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
func enemy_snapshot(enemy: EnemyInstance) -> Dictionary          # the formatter WaveSim embeds (section 10)
func snapshot() -> Dictionary
```

The `...` in architecture 4.4's `first_in` is `from: Vector2, range: float`. The rules for `deliver`, damage, death and the helpers are Combat Rules 2 to 5 and 10; this ADR adds only these decisions:
- **`deliver` checks in this order, with `if`, never `assert`:** latch halted (return `0.0`, change and emit nothing: Flow Rule 15 and ADR-0002 rule 4, a refinement of the Combat edge case that Combat needs no `halted()` of its own); null event or target, or target not `in_play` (call `dev_error`, return `0.0`); target dead (return `0.0`, silent); amount negative or not finite (`dev_error`, `0.0`); then apply `min(amount, hp)`, count it under `source_id` with its kind, and emit `damage_applied` with a copied `Vector2` position. `hp` becomes exactly `0.0` when everything is applied.
- **Only `TowerSim` and `HeroSim` call `deliver`,** each inside its tick slot, so "only in a tick" follows from slot order. A command never calls it; a burst command sets state and releases in the hero slot (Combat Rule 2).
- **Helpers** scan without sorting and skip enemies that are dead or not `in_play`. Ties go to the lower `spawn_id`, compared explicitly, never by list position. `in_radius` is inclusive (Combat formula). A slow tower builds its own "unslowed" sublist from `all_in_radius` and falls back to the full list (Combat Rule 10); there is no extra helper.
- **`report_attack`** emits `attack_fired` after the same halted check. Tower and Hero call it before their `deliver` calls.
- **Slow** (Combat Rules 7 and 8): the slot is `slow_strength` and `slow_ticks_left` on `EnemyStatus`. `apply_slow` converts seconds with `TickConverter` (floored at one tick), then sets, replaces, keeps the longer or ignores as Rule 7 says; a dead target does nothing. `tick_status(wave.roster())` runs in the Status slot and counts each living enemy's slow down by one. `speed_factor` is `1.0 - strength` while ticks remain, else `1.0`.

**`TickConverter`.** Combat needs `to_ticks`, StageFlow owns the public `to_ticks`, and StageFlow reads Combat's counters. A Combat holding StageFlow would form a cycle. So `to_ticks` is implemented once in a pure `TickConverter(dt: float)` (`dt`, `to_ticks(seconds) -> int`), shared by Combat, WaveSim and StageFlow; `StageFlow.to_ticks` forwards to it. ADR-0002's table is unchanged. It computes the Enemy & Wave formula, `round(seconds / dt)` with halves away from zero, as `floori(seconds / dt + 0.5)` for the non-negative inputs it receives (V5).

### 4. Records
Read-only `RefCounted` records, built fresh on each read, fields set in `_init`, no setters (the ADR-0001 pattern). ADR-0002 owns the table; these are the field lists it asked each story to define.

| Record | Fields (GDD source) |
|--------|---------------------|
| `SlotState` | `tower_id: StringName` (`&""` unbuilt), `level: int` (`0` unbuilt), `cooldown_left: int` ticks |
| `HeroCounters` (Hero Rule 16) | ints: `repins`, `bursts_started`, `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `bursts_emptied_by_kill`, `bursts_walked_out`, `burst_victims`, `burst_kills`; `kills_per_burst() -> Array[int]`, `kills_on_hit_3() -> Array[int]` (copies) |
| `CombatCounters` (Combat Rules 3, 5) | `source_ids() -> Array[StringName]`, `amount(source_id) -> float`, `kind(source_id) -> int`, `kind_total(kind) -> float`, `total() -> float`, `hero_share() -> float` |
| `BattleResult` (Flow Rule 15) | `outcome: StringName` (`&"none"`, `&"won"`, `&"lost"`, `&"fatal"`), `last_wave_started: int`, `lives_left: int`, `damage: CombatCounters` |

`CombatCounters` sums in order of `String(source_id)` so float totals repeat on every run (V7). `hero_share()` is `(kind_total(HERO) + kind_total(BURST)) / total()`, `0.0` when the total is `0.0`. Counters stay readable after the outcome until the battle is freed. Each read allocates one small object, which is acceptable for a per-frame HUD read. Flow's story and ADR-0008 may add `BattleResult` fields by updating ADR-0002's table.

### 5. The roster: WaveSim is the only writer
Built with `WaveSim.new(stage: StageDef, catalogue: Catalogue, stats: StatAccessor, combat: Combat, ticks: TickConverter, latch: HaltLatch, field: Rect2, dev_error: Callable)`. This answers the seams Enemy & Wave's open question lists (constructor inputs, two tick entries, add-enemy, development-error sink, field rectangle, snapshot).

**State.** `_roster` and `_targets` (`Array[EnemyInstance]`, ascending `spawn_id`), `_next_spawn_id: int` (from `0`, +1 per enemy, never reused), `_ctx: Dictionary[int, ReadContext]` (one context per enemy, made at add and erased at leak or reap: Enemy & Wave Rule 9), `_got_through: Dictionary[StringName, int]`, the wave index, `wave_tick`, the spawn cursor, and a `PathTrack`.

**Geometry (A3, confirmed).** WaveSim reads `stage.path_points()` once into `PathTrack` (points plus a cumulative-length `PackedFloat64Array`, `length`, `position_at(distance)`). TowerSim reads `slot_positions()`; HeroSim reads `hero_start`, `pin_rect`, `pin_exclusion()`. All come from the `StageDef` the builder passes (ADR-0001 section 6), never a scene. `PathTrack` fills its arrays in locals and assigns each once, and no sim class declares a setter on a packed-array property, so the 4.7 packed-write change cannot matter.

**Two tick entries** (ADR-0003 slot order unchanged). The algorithms are Enemy & Wave Rules 7 to 13; the decisions this ADR adds:
- `advance()` (slot 2) spawns due members through `add_enemy`, moves all enemies (clamped to the path end, position cached), runs the leak step, then rebuilds `_targets` from the roster (centre inside `field`, edges inclusive, compared with explicit `>=` and `<=` because `Rect2.has_point` edge behaviour is not in the reference).
- `reap()` (slot 6) handles dead enemies in ascending `spawn_id`, rebuilds `_targets`, then runs the clear check every tick while a wave is active.
- **Leak and reap never remove from `_roster` while iterating it.** They first collect the affected enemies into a local array, process them in order (accessor read, latch check, `in_play = false`, erase the context, emit), then rebuild `_roster` from the survivors. A latch that turns halted stops the processing loop; enemies not yet processed stay in the roster and freeze (Enemy & Wave Rule 13).
- The latch is checked right after every accessor read and every emit.

**`add_enemy(def_id) -> EnemyInstance`** is the one add step (Rule 15). The schedule, a later splitter or a test uses it; no `BattleCommand` can reach it. It makes the instance with the next id (not yet consumed), reads `max_hp`, and returns `null` without consuming the id if the latch turned halted. Otherwise it consumes the id, calls `combat.attach`, appends, stores the context and puts the enemy at the path start.

**`spawn_id` and the tie-break.** An `int` assigned in schedule order and never reused, so a total order over a battle. Leaks and reaps run in ascending order and every helper breaks ties on the lower id (TR-enemy-002, 004, 005; TR-combat-005).

**`roster()` and `targets()`: a copy, chosen now.** ADR-0002 left this to the first WaveSim story. Each call returns `_roster.duplicate()` or `_targets.duplicate()`, a new typed array (V4). A caller may write to it without touching the simulation or another reader. `make_read_only()` is not used (V1). `roster()` includes corpses awaiting the reap (Rule 14). A returned array is a snapshot at the call, valid for the reader's slot only, because its enemies may die later (ADR-0002 guideline). The elements are shared objects; section 2's rule and test protect their fields, not the copy. `got_through_by_type()` returns a copy of `_got_through`.

**Cost.** E = 48, S = 5. TowerSim may hold one `targets()` copy in a local for its whole slot, so one tick makes about 2 `targets()` copies (TowerSim, HeroSim) and 1 `roster()` copy (Status slot), each at most 48 elements. That is an estimate, unmeasured, beside the Combat GDD's own unmeasured "400-check" estimate of under 2 ms. The first WaveSim story measures it; above 10% of the 2 ms tick, the fallback is a sealed shared array (V1).

### 6. Reaping, and why no system holds a target
A reaped or leaked enemy has `in_play = false` and leaves `_roster`. It stays a live object while anything references it (`RefCounted`), so a held reference cannot crash. The risk is a stale answer, such as a tower aiming at a corpse. Three rules close it:
1. **Re-pick every attack** from a `targets()` copy; keep no enemy past the slot (Combat Rule 10).
2. **No member holds an enemy.** No class outside WaveSim and Combat declares a class-level variable of type `EnemyInstance` or `Array[EnemyInstance]`. `DamageEvent.target` is the one exception, and a listener must not keep an event (ADR-0002). A view that must remember an enemy keeps its `spawn_id` (an `int`) and looks it up in `roster()` each frame.
3. **`deliver` guards the rest** (section 3).

### 7. Tower and hero instances
`TowerSim.build` creates a `TowerInstance` (`level = 1`, `cooldown_left = 0`: a new tower starts ready, Tower Rule 11); `upgrade` raises `level` and leaves the timer (Rule 12). TowerSim holds `Array[TowerInstance]` of fixed length S, `null` for an empty slot, looped by ascending index (Rule 9). `slot_state(i)` returns a fresh `SlotState`. HeroSim creates a `HeroInstance` (`level = 0`, `position = hero_start`) and keeps the pin, leash, burst and telegraph state private. Only `def_id`, `level` and `position` sit on the instance because a future "towers near the hero" stat reads them through `ReadContext.entity` (Data GDD Rule 10). The hero has no HP at MVP.

### 8. A1 confirmed
`ProjectileSpawner` is cut and the tick order stays: StageFlow, WaveSim `advance`, Status (`combat.tick_status`), TowerSim by slot index, HeroSim then burst, WaveSim `reap`. `deliver` stays the only door. If projectiles return, they arrive as a new system in its own slot that holds in-flight events and calls `deliver` on impact; that needs its own ADR and no `deliver` change.

### 9. Ownership and removal in one table

| Event | Who | Effect |
|-------|-----|--------|
| spawn | WaveSim `add_enemy` | id consumed, `attach`, roster append |
| damage | Tower, Hero via `Combat.deliver` | HP falls, counters rise, `damage_applied` |
| leak | WaveSim `advance` | `in_play = false`, out of roster, `enemy_leaked` |
| kill | WaveSim `reap` | `in_play = false`, out of roster, `enemy_killed` |

### 10. `snapshot() -> Dictionary` on every system
Every system in `Battle.systems()` (StageFlow, WaveSim, Combat, TowerSim, HeroSim) has `func snapshot() -> Dictionary`. **ADR-0004 owns the format** and this ADR does not restate it. Under ADR-0004: the first key is `"system"`; every other key is a member name with its leading `_` stripped; a system declares `const SNAPSHOT_EXEMPT` (even `[]`) naming the members it leaves out, and `const SNAPSHOT_KEYS: Dictionary[StringName, StringName]` for any renamed key; a holder embeds another owner's state only through that owner's formatter; two snapshots are compared with `SnapshotTool.diff`, never `==`.

What each system puts in, and what it exempts:

| System | Keys (member names; renames in `SNAPSHOT_KEYS`) | `SNAPSHOT_EXEMPT` |
|--------|--------------------------------------------------|-------------------|
| StageFlow | `state`, `lives`, `intermission_left`, `last_wave_started`, `outcome`, `clock_running`. `halted` is not included: the latch is held once by the harness top level | `stage`, `ticks`, `combat`, `latch`, `dev_error` |
| WaveSim | `wave_index`, `wave_active`, `wave_tick`, `spawn_cursor`, `next_spawn_id`, `got_through` (array of `{def_id, count}` sorted by `String(def_id)`), `enemies` (from `_roster`: array in `spawn_id` order of `{spawn_id, def_id, distance, position, in_play, health}` where `health` is `combat.enemy_snapshot(enemy)`), `target_ids` (from `_targets`: array of `spawn_id`), `context_count` (from `_ctx`: its size) | `track` (the PathTrack, fixed by the stage), `stage`, `catalogue`, `stats`, `combat`, `ticks`, `latch`, `field`, `dev_error` |
| Combat | `dealt` (array of `{source_id, amount}`), `kind` (array of `{source_id, kind}`), both sorted by `String(source_id)`. `enemy_snapshot(enemy)` returns `{hp, max_hp, slow_strength, slow_ticks_left}`: Combat formats the state it owns and WaveSim, which holds the roster, embeds it | `latch`, `ticks`, `dev_error` |
| TowerSim | `gold`, `slots` (S records `{slot_index, tower_id, level, cooldown_left}` in index order; empty slot has `tower_id = ""`) | `stage`, `catalogue`, `stats`, `combat`, `wave`, `ticks`, `latch`, `dev_error`, `slot_positions` |
| HeroSim | `instance` fields (`def_id`, `level`, `position`), `pin_state`, `pin_target`, `burst_state`, `cooldown_left`, `telegraph_left`, `aim_point`, every `HeroCounters` field, and any other field that changes a later tick (the story lists it here as it adds it) | `stage`, `catalogue`, `stats`, `combat`, `wave`, `options`, `ticks`, `latch`, `dev_error` |

Renames: WaveSim declares `_roster` to `enemies`, `_targets` to `target_ids`, `_ctx` to `context_count`. `_next_spawn_id` needs none (the stripped name is the key). `context_count` equals the roster size after every tick, so a leaked context shows as a diff. A snapshot never calls the `StatAccessor` (a bad read would call the failure handler), emits nothing, and works while halted. Battle's `tick_count` and the command log belong to ADR-0003 and ADR-0004.

### 11. Enforcing ownership (tests)
1. **Ownership scan** (`tests/integration/sim/ownership_scan_test.gd`; it reads source files). Under `res://src/` it fails if: (a) `EnemyHealth.remove`, `seed`, `EnemyStatus.set_slow` or `count_down` is called outside `src/sim/combat/`; (b) `deliver(` is called outside `tower_sim.gd` and `hero_sim.gd`; (c) `spawn_id`, `distance`, `in_play` or a roster array is written outside `src/sim/wave/` (an `_init` set is the only write to `spawn_id` and `def_id`); (d) an unindented `var` of type `EnemyInstance` or `Array[EnemyInstance]` appears outside `src/sim/wave/` and `src/sim/combat/`. The set of files comes from the file tree. It is a line scan and a call built from a string would fool it; review still catches that.
2. **HP conservation test.** Over a scripted battle, the sum of `applied` from every `deliver` equals the HP removed from every enemy and equals `CombatCounters.total()`.
3. **No bypass test.** A fixture enemy is hit by every tower role and a burst; `hp_left` falls only by applied amounts.

### Architecture Diagram

```
Catalogue --StageDef--> WaveSim                      builder order (requirement on ADR-0008):
                         |  advance(): spawn, move, leak     TickConverter, Combat, WaveSim,
 TickConverter ----+     |  reap():    kills, clear          TowerSim, HeroSim, StageFlow
                   |     v
                   |   _roster / _targets (private; copies out)
                   |     |  EnemyInstance { spawn_id, def_id, distance, position, in_play,
                   v     |                  health: EnemyHealth, status: EnemyStatus }
                Combat <-+- attach, deliver, apply_slow, tick_status(roster)
                   ^   \
   TowerSim, HeroSim    `--damage_applied, attack_fired--> views (copied positions)
 Writers: HP and slow = Combat | roster, position = WaveSim | gold, slots = TowerSim | hero = HeroSim
```

### Key Interfaces
`SimEntity`, `EnemyInstance`, `EnemyHealth`, `EnemyStatus`, `TowerInstance`, `HeroInstance`, `DamageEvent`, `TickConverter`, `SlotState`, `HeroCounters`, `CombatCounters`, `BattleResult`; `Combat` as in section 3; `WaveSim.advance()`, `reap()`, `add_enemy(def_id)`, `roster()`, `targets()`, `wave_index()`, `got_through_by_type()`; `snapshot()` on StageFlow, WaveSim, Combat, TowerSim, HeroSim.

### Implementation Guidelines
- Only Combat may call the Health and Status mutators. Only WaveSim may write `spawn_id`, `distance`, `position`, `in_play` or the roster.
- Every damage point must go through `Combat.deliver`, one event per victim, called only from `TowerSim` or `HeroSim` inside their slot. A command must never call it.
- `deliver` must return `0.0` and emit nothing once `halted()` is true.
- Code must not hold an `EnemyInstance` or `Array[EnemyInstance]` in a member outside WaveSim and Combat. A view must key by `spawn_id`.
- Code must re-pick the target on every attack. A listener must not keep a `DamageEvent`.
- Ties must break on the lower `spawn_id`, compared explicitly. Every sort comparator must be strict and total, and ids must sort by `String(id)`.
- `roster()` and `targets()` must return a new typed copy on every call. Code must not rely on `make_read_only()`.
- Leak and reap must collect first and rebuild the roster after; they must never remove while iterating it.
- WaveSim must assign `spawn_id` only in `add_enemy`, after the `max_hp` read passed the latch check.
- All seconds-to-ticks conversion must use `TickConverter`.
- No sim class may declare a setter on a packed-array property.
- `snapshot()` must follow ADR-0004, must not call the `StatAccessor` and must not mutate.
- Every override must end in an explicit `return` (4.7, ADR-0003). Checks must use `if` and `dev_error`, never `assert`.

## Alternatives Considered

### Alternative 1: Combat keeps HP and slow in tables keyed by `spawn_id`
- **Description**: `EnemyInstance` has no health fields; Combat holds dictionaries.
- **Pros**: Combat's state cannot be reached from an enemy reference.
- **Cons**: Needs a release at every leak and reap or the tables grow; every read is a lookup; TR-combat-006 says "attach to an enemy instance".
- **Rejection Reason**: Components give the same single-writer rule at class level, free with the enemy, and match the requirement text.

### Alternative 2: Flat fields on `EnemyInstance`
- **Description**: `hp`, `slow_strength`, `slow_ticks` on one object.
- **Pros**: Fewest objects.
- **Cons**: Every field is writable by everyone; the scan must know which fields belong to whom.
- **Rejection Reason**: Two components make the boundary a type. The cost is 96 small objects at the cap.

### Alternative 3: Dictionaries, or parallel packed arrays
- **Description**: A Dictionary per enemy, or packed columns indexed by slot.
- **Pros**: Fewer allocations.
- **Cons**: A Dictionary loses typing and the read-only rule (ADR-0001's reason). Columns need slot reuse, which breaks stable identity, and put the 4.7 packed-write change in the hot path.
- **Rejection Reason**: 48 enemies do not need it.

### Alternative 4: `make_read_only()` on shared roster arrays
- **Description**: WaveSim publishes one sealed array per change.
- **Pros**: No copying.
- **Cons**: Behaviour on 4.7.2 is NOT SOURCEABLE (V1); WaveSim would rebuild and reseal on each change.
- **Rejection Reason**: Copies need no unsourced API. Kept as the profiled fallback.

### Alternative 5: A spawner behind `deliver` now
- **Description**: `deliver` hands events to a spawner that applies them later.
- **Pros**: Projectiles need no later change.
- **Cons**: All hits are instant (Combat Rule 1); it adds a queue, a slot and delayed death for no use.
- **Rejection Reason**: A1 is decided. A projectile system later is a new slot that calls the same `deliver`.

### Alternative 6: Attackers keep a target between attacks
- **Description**: A tower holds its target until it dies or leaves range.
- **Pros**: Fewer scans.
- **Cons**: Stale references after a reap; behaviour depends on who reaped first.
- **Rejection Reason**: Combat Rule 10 re-picks every attack; the scan enforces it.

## Consequences

### Positive
- One definition of an enemy, one writer per field, and a test that checks it.
- No change to ADR-0001 or to ADR-0002's table; no reference cycle, so Retry leaves nothing behind.
- Reaping cannot leave a live reference that matters.
- The harness gets a snapshot with no reflection, and context leaks show as a diff.

### Negative
- Component mutators are public by language limit; safety is a scan.
- Copies on every `roster()`, `targets()` and record read. Small, unmeasured.
- One more injected object (`TickConverter`) and one more constructor argument per system.
- Five snapshot methods to keep in step with their systems (ADR-0004's exemption list catches a missed member).

## Risks
- **The scan misses an indirect write.** Mitigation: the conservation and no-bypass tests catch the effect.
- **Copy cost exceeds budget on the phone.** Mitigation: measure in the first WaveSim story; fallback in section 5.
- **`TickConverter` rounding differs from the GDD at a half value.** Mitigation: a unit test pins half cases against the Enemy & Wave examples (0.125 s gives 0, 8, 15, 23).
- **GDD wording on `halted()` in Combat.** Mitigation: the Migration Plan edits that line.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | Rules 2, 3 (TR-combat-001): one door, in the tick, real damage | Section 3 `deliver`; section 11 scan |
| combat-damage.md | Rules 4, 5 (TR-combat-002): death at once; counters by source and kind | Section 3; `CombatCounters` (section 4) |
| combat-damage.md | Rules 1, 6 (TR-combat-003): instant hits, victims at release | Sections 3, 8 |
| combat-damage.md | Rules 7, 8 (TR-combat-004): one slow slot, whole ticks | Section 3 slow, `TickConverter` |
| combat-damage.md | Rule 10 (TR-combat-005): helpers, `spawn_id` ties, skip the dead | Sections 3, 5 |
| combat-damage.md | Rule 9 (TR-combat-006): attach; no catalogue; `max_hp` seeds once | Sections 2, 3, 5 |
| combat-damage.md | Open question: spawner behind `deliver`; how Health and Status attach | Sections 8, 2 |
| enemy-wave.md | Rules 1, 2 (TR-enemy-001): one path; geometry on the Stage record | Section 5 geometry |
| enemy-wave.md | Rules 7, 8 (TR-enemy-002): absolute schedule, `spawn_id` | Section 5 |
| enemy-wave.md | Rule 9 (TR-enemy-003): accessor speed times `speed_factor`; cached position | Section 5 `advance`, `_ctx` |
| enemy-wave.md | Rules 10, 11 (TR-enemy-004, 005): leak and reap order, clear check | Section 5 |
| enemy-wave.md | Rule 14 (TR-enemy-006): read-only roster in the reader's slot; edge inclusive | Section 5 copies |
| enemy-wave.md | Rule 15; Open Question on seams | One add step; constructor inputs; `dev_error`; field; snapshot |
| game-state-stage-flow.md | Retry criterion: matching snapshot, `weakref` null | Section 10, no cycle (V2) |
| tower-system.md | Rules 9, 11, 12 | Section 7 |
| hero-system.md | Rule 16: counters | `HeroCounters` (section 4) |

## Performance Implications
- **CPU**: About 2 `targets()` copies and 1 `roster()` copy per tick, at most 48 elements each, estimated and unmeasured, against a proposed 2 ms tick. `deliver` is a few comparisons. Snapshots run only in tests.
- **Memory**: 48 enemies × 3 objects plus 5 tower and 1 hero instance. Negligible.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
No code exists yet. **These edits land in the same change that marks this ADR Accepted** (together with ADR-0004). None is made by this draft.

- `docs/architecture/architecture.md`:
  - 4.4: replace the `EnemyInstance` comment with the class block of section 1; add `attach`, `report_attack`, `tick_status`, `counters`, `snapshot`; fill `first_in(list, from, range)`; add the `deliver` halted note.
  - 4.5: WaveSim gets `advance()`, `reap()`, `add_enemy(def_id)`; the records get section 4's field lists; the invariant "no system holds a target between attacks" cites section 6; every system gets `snapshot()`.
  - 4.3: `systems()` comment cites section 10 and ADR-0004.
  - 3.4: `TickConverter` is built first (a requirement ADR-0008 confirms); 3.1 slot 3 reads `combat.tick_status(wave.roster())`.
  - Module Ownership: Combat and WaveSim rows name the components and copies; ownership rule 2 adds "readers get copies".
  - Open Questions A1 and A3 notes cite this ADR.
- `docs/architecture/adr-0002-signal-contracts-and-wiring-conventions.md` (Accepted): in "Returned collections" record that WaveSim returns a new typed copy per call (this ADR); add `snapshot()` to the reads and cross-reference the record field lists; note `attach` and `report_attack` are direct calls. A cross-reference, not a change of decision.
- `docs/architecture/adr-0003-frame-order-command-queue-ticks-and-view-update.md` (Accepted): a cross-reference note that its slot names are `StageFlow`, `WaveSim.advance`, `Combat.tick_status`, `TowerSim`, `HeroSim`, `WaveSim.reap`.
- ADR-0001 is unchanged.
- `design/gdd/combat-damage.md`: the edge case "Combat needs no `halted()` of its own" gains "`deliver` returns 0 once halted (ADR-0002 rule 4)"; Rule 10 `first_in(list, from, range)`; the spawner and attachment Open Questions closed by this ADR.
- `design/gdd/enemy-wave.md`: the Open Question rows on seams and on path and slots closed by this ADR and ADR-0001; Rule 14 adds "copies".
- `design/gdd/game-state-stage-flow.md`: the snapshot Open Question points to ADR-0004 and this ADR.
- `docs/registry/architecture.yaml`: registered with this ADR's write, as Proposed stances.

## Validation Criteria
- Unit: 30 damage on 12 HP applies 12, leaves `hp` at exactly `0.0`, counts 12; a second hit the same tick returns `0.0`, emits and counts nothing.
- Unit: a negative, NaN or infinite amount returns `0.0` and calls `dev_error`; with the latch halted `deliver` returns `0.0`, emits nothing and leaves counters unchanged.
- Unit: slow rules (empty, stronger replaces with less time, equal keeps longer, weaker ignored, dead ignored); a 0.5 s slow gives exactly `to_ticks(0.5)` slowed moves.
- Unit: helpers break ties on the lower `spawn_id` with the list reversed; `all_in_radius` includes the edge; all skip the dead and not-`in_play`.
- Unit: `roster()` and `targets()` return distinct typed arrays per call; writing to one changes nothing; an enemy on the field edge is in `targets()`, one just outside is not.
- Unit: `add_enemy` with a failing `max_hp` read returns `null` and consumes no id; ids rise by one and are never reused.
- Integration: leaks fire in `spawn_id` order before `waves_complete`; a fatal leak stops the loop and pays no bounty; kills reap in `spawn_id` order; leak and reap leave the roster intact when the latch halts mid-loop.
- Integration: the conservation and no-bypass tests; the ownership scan fails on a planted `EnemyHealth.remove` outside Combat (watched failing once, then restored).
- Harness (ADR-0004): two battles with the same seed and command script show no `SnapshotTool.diff` entry after every tick; a fresh battle and a retried one show none; `context_count` equals the roster size every tick; every system declares `SNAPSHOT_EXEMPT`.
- Retry: a `weakref` to the old battle is null as soon as the last reference drops (V2, ADR-0004 H4).
- First WaveSim story: record the copy cost per tick against the 10% line of section 5.

## Related
- Architecture: `docs/architecture/architecture.md` Module Ownership rules 1 and 2, 3.1, 3.4, 4.4, 4.5; Open Questions A1, A3.
- ADR-0001, ADR-0002, ADR-0003 (Accepted); ADR-0004 (Proposed, owns the snapshot format); ADR-0006 keys enemy views by `spawn_id`; ADR-0008 builds the classes.
- GDDs: `design/gdd/combat-damage.md`, `enemy-wave.md`, `tower-system.md`, `hero-system.md`, `game-state-stage-flow.md`, `data-config-pipeline.md`.
- Reviews: technical-director CONCERNS and godot-specialist (two blockers) folded in on 2026-11-02: `SnapshotTool.diff`, `"system"` key and exemption lists, copy by `duplicate()`, collect-then-rebuild for leak and reap, strict sort comparators, typed dictionaries listed as post-cutoff, ADR-0004 dependency, and a shorter section 3 to 5.
