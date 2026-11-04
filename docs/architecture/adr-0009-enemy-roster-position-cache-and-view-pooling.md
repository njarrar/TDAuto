# ADR-0009: Enemy Roster, Position Cache and View Pooling

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

Enemy & Wave must keep one roster, compute each enemy's position once per tick, and feed a view that never holds more than 48 enemies. This ADR stores the roster as an ordered typed array of `EnemyState`, derives position from distance with a precomputed path table, caches the targetable list once per tick, gives the view a fixed pool of 48 slot records, and defines one add-enemy step for the schedule and for later splitters.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (gameplay data, with a Presentation pool) |
| **Layer** | Feature |
| **Knowledge Risk** | HIGH for the engine version (VERSION.md). The sim half of this ADR calls no engine API beyond `RefCounted`, typed `Array` and `Vector2`. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/architecture/architecture.md` (Engine Knowledge Gap Summary and the Engine awareness checks, which cite the pinned reference). The live 4.7.2 class reference was not fetched for this ADR. |
| **Post-Cutoff APIs Used** | None. Typed arrays and typed `Dictionary` are used as listed in `deprecated-apis.md` (as quoted in architecture.md). |
| **Verification Required** | NOT SOURCEABLE: draw-call cost of 48 enemies in one `_draw` against the budget of 8 expected and 12 at most (decided in ADR-0012). NOT SOURCEABLE: `queue_free` against `free` timing, which matters only if ADR-0012 gives each enemy a Node. A device run is needed for both. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary |
| **Enables** | ADR-0012 Field and HUD Rendering and Performance Budget (uses the pool); the Vertical Slice splitter work |
| **Blocks** | Enemy & Wave stories |
| **Ordering Note** | QQ-06 (how `Health` and `Status` attach to `EnemyState`) is open between this ADR and ADR-0007 Combat Data Model. This ADR only requires that the attach call happens inside the add-enemy step. It does not decide the form. The `EnemyState` fields in architecture.md are the contract; ADR-0007 may change allocation, not these fields. |

## Context

### Problem Statement

Five modules read the enemy list in one tick: EnemyWave, Combat helpers, TowerSim, HeroSim and the views. Version 2 of the master architecture names the data (`EnemyState`, `roster()`, `targets()`) but not how they are stored, when position is computed, who owns the view pool, or how a second source of enemies (splitters) joins. Without a rule, each module will copy the list or recompute position, and the 48-enemy view pool will have no owner.

### Current State

No code exists. The GDD (`enemy-wave.md`, Rules 8, 9, 14, 15 and the edge case on the view pool) fixes behaviour:

- One path per stage. Position is looked up from one distance `d`, not walked. `position = P[k] + (d - cum[k]) / len[k] x (P[k+1] - P[k])`, clamped to the last point once `d >= path_length`. `path_length` is `cum[last]`.
- `spawn_id` is battle-wide and ascending. Reap, leak and tie-breaks go by `spawn_id`.
- `roster()` holds every enemy not yet removed, corpses included. `targets()` is that list limited to enemies whose centre is inside the field, edges included (0 to 540, 0 to 960).
- Both lists are read-only and never kept past the reader's slot.
- At most 48 enemies are alive (`peak_alive_ub`); the starter stage peaks at 34.
- If more than the pool holds are alive, the view creates one more and logs a development error. The sim has no cap.
- One add-enemy step serves the schedule and later splitter children. A member joins the roster, and its `spawn_id` is spent, only after its `max_hp` read passes the halt check.

### Constraints

- Sim classes are plain `RefCounted` and load with no scene tree (ADR-0001).
- `Vector2` holds 32-bit floats; scalar `float` is 64-bit (architecture.md, Stated, not a gap). An exact compare (the in-field edge test) must use scalars.
- Single thread. Tick order is fixed: advance, status, towers, hero, reap.
- Gameplay numbers (path points, speeds) come from the catalogue at the time of use. The path table is derived from the Stage record at battle build and is not a gameplay value cache; the Stage record is read-only after load.

### Requirements

- TR-wave-001: one path; position from one distance; a view draws from the same points.
- TR-wave-008: at most 48 alive; the view pool matches.
- TR-wave-009: one add-enemy step for the schedule and splitters.

## Decision

### 1. Roster storage

`EnemyWave` holds `_roster: Array[EnemyState]`, ordered by `spawn_id`. Because `spawn_id` rises with each add, an append keeps the order, and no sort is ever run. Removal (leak or reap) uses `remove_at(index)`, which keeps order. With 48 entries at most, the cost is bounded by 48 element moves per removal. `roster()` returns `_roster` itself. The read-only rule is a review rule and a test (the snapshot before and after a reader must match), not a defensive copy, because a copy per call would allocate on the hot path.

### 2. Position cache

`EnemyState.distance` is written only by the move step. In the same step, the move step also writes `EnemyState.position` and `EnemyState.in_field`, so all three describe the same tick. Nothing else writes them.

A `PathTable` plain class is built once in the `EnemyWave` constructor from `StageRecord.path_points`:

```gdscript
class_name PathTable extends RefCounted
## Cumulative lengths of one stage path. Built once; read-only after.
func _init(points: PackedVector2Array) -> void
func length() -> float                         # cum[last], also used by the leak test
func lookup(d: float) -> Vector2               # position at distance d, clamped to the ends
func inside_field(d: float) -> bool            # 64-bit scalar test, edges inclusive
```

`cum` is an `Array[float]` built from the point components as scalars. `lookup` finds the segment by binary search over `cum` and then interpolates in 64-bit scalars, narrowing to `Vector2` once at the end. The starter path has 7 points (6 segments), so a lookup is about 3 compares; 48 enemies is about 150 compares a tick. The binary search crosses several segments in one step safely (the GDD edge case at `move_speed` 2,000).

`in_field` is computed from the same scalars before narrowing, so an enemy exactly on an edge is targetable (GDD edge case) and the answer does not depend on 32-bit rounding.

`EnemyState` gains one field over architecture.md: `var in_field: bool`. This is additive. See Deviations below.

### 3. The targets list

`targets()` returns a cached `Array[EnemyState]` holding the roster entries with `in_field` true, in `spawn_id` order. `EnemyWave` marks the cache dirty on any add, removal or move step, and rebuilds it on the next `targets()` call. A rebuild is one pass over at most 48 entries. Callers must not keep the array past their slot, because the next rebuild reuses it (the array is cleared and refilled, not reallocated).

### 4. The add-enemy step

```gdscript
## Adds one enemy. Returns null (and spends no spawn_id) when the battle is halted
## or the max_hp read fails. Used by the schedule now and by splitters later.
func _add_enemy(def_id: StringName, start_distance: float) -> EnemyState
```

Order inside the step: make the `ReadContext` once; read `max_hp` through the accessor; check `halted()`; only then take the next `spawn_id`, build the `EnemyState`, set position from `start_distance`, attach `Health` and `Status` through Combat (form decided in ADR-0007), and append. The schedule calls it from the advance slot. A splitter, when it exists, calls it from the reap slot before the clear check, so children join atomically. The clear test looks only at the schedule and the roster, so it needs no change.

### 5. The view pool

`FieldView` owns a fixed pool of 48 `EnemyViewSlot` records, created when the view is built:

```gdscript
class_name EnemyViewSlot extends RefCounted
var spawn_id: int          # -1 when free
var def_id: StringName
var flash_left: float      # cosmetic timers live here, never in the sim
```

Each frame `FieldView` reads `BattleReadModel.roster()` and binds slots by `spawn_id`: a `Dictionary[int, int]` maps `spawn_id` to a slot index, and a free-index `Array[int]` holds unused slots. An enemy in the roster with no slot takes one from the free list. A slot whose `spawn_id` is no longer in the roster goes back. If the free list is empty, the view adds a 49th slot and logs one development error (GDD edge case). The view never draws from `distance`; it draws at `EnemyState.position`, so the sim and the view cannot disagree.

Whether the slot holds a `Node` or only draw data is decided in ADR-0012. This ADR requires only the binding and the 48 count. If ADR-0012 chooses one node per enemy, the nodes are created at view build and hidden when free, and are never freed during a battle.

### Architecture Diagram

```
 StageRecord.path_points --(build once)--> PathTable (cum[], length())
                                              |
 EnemyWave._add_enemy --> _roster: Array[EnemyState] (spawn_id order)
   advance(): d += step; position = PathTable.lookup(d); in_field = ...
   targets(): cached filter of _roster (dirty flag)
   reap():    remove_at(i) in spawn_id order, emit enemy_killed
                    |  read-only via BattleReadModel.roster()
                    v
 FieldView: 48 EnemyViewSlot, spawn_id -> slot index, free list
```

### Key Interfaces

As in architecture.md API Boundaries (`EnemyWave`, `EnemyState`), plus `PathTable`, `EnemyState.in_field` and `EnemyViewSlot` above.

### Implementation Guidelines

- `EnemyWave` must be the only writer of `distance`, `position` and `in_field`.
- Position must be computed once per enemy per tick, in the move step, and must never be recomputed by a reader.
- No module may call `Vector2.distance_to` where an exact compare decides the result; use scalar components (ADR-0007 decides the helper scope).
- `roster()` and `targets()` results must never be stored beyond the caller's slot, and must never be modified.
- `_add_enemy` must read `max_hp` and check `halted()` before it takes a `spawn_id`.
- `FieldView` must not allocate during a frame in the steady state; the pool, the dictionary and the free list are built at view build.
- A removal must use `remove_at`, not `erase` on a value search, and must not break `spawn_id` order.

## Alternatives Considered

### Alternative 1: Sim object pool for `EnemyState`

- **Description**: Preallocate 48 `EnemyState` objects and reuse them.
- **Pros**: No allocation in the sim after build.
- **Cons**: A reused object can leak old state (a stale `status`, a stale `spawn_id`). A reader that kept a reference past its slot would see another enemy.
- **Estimated Effort**: Higher, plus a reset routine to test.
- **Rejection Reason**: A starter stage creates 112 `EnemyState` objects in total (8, 12, 20, 10, 28 and 34 per wave). That is under 2 a second over the 5.0 to 5.3 minute stage length in `enemy-wave.md`. The saving does not repay the stale-state risk.

### Alternative 2: Walk position forward each tick instead of a lookup

- **Description**: Keep the current segment and step along it.
- **Pros**: No search.
- **Cons**: A step that crosses several segments needs a loop, and rounding drifts from `cum`. The GDD defines `path_length` as `cum[last]` so the two cannot differ.
- **Estimated Effort**: Similar.
- **Rejection Reason**: The GDD edge case at speed 2,000 requires safe multi-segment steps. A lookup from `d` gives that by construction.

### Alternative 3: Compute position lazily in the reader

- **Description**: Store only `distance`; each reader calls `PathTable.lookup`.
- **Pros**: Fewer fields.
- **Cons**: Up to five readers repeat the lookup each tick, and a reader in a later slot could see a position that differs from the one targeting used.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Enemy & Wave Rule 9 says position is computed once in the move step and kept for that tick.

### Alternative 4: Create and free a view Node per enemy

- **Description**: Instantiate on spawn, free on removal.
- **Pros**: Simplest code.
- **Cons**: Allocation and free timing mid-battle. Free timing is NOT SOURCEABLE.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: The pool avoids the unsourced behaviour and matches the art bible's enemy pool (cited by `enemy-wave.md`, `peak_alive_ub` row).

## Consequences

### Positive

- One writer for position and one cache per tick. Readers agree by construction.
- The roster stays sorted without a sort.
- The splitter case needs no change to the clear check.
- The view allocates nothing in the steady state.

### Negative

- `EnemyState` grows by one field, `in_field`, over the contract in architecture.md.
- `targets()` returns a reused array; a caller that keeps it will see it change. Review and a snapshot test guard this.
- `remove_at` is O(n) on 48 entries. Accepted at this size.

### Neutral

- The 49th-slot fallback exists but is unreachable while the content test's `peak_alive_ub` rule passes (ADR-0013).

## Risks

- A reader keeps `targets()` past its slot. Mitigation: the snapshot test in ADR-0013's harness compares the roster before and after each reader, and review checks it.
- The 48 pool count drifts from the content rule. Mitigation: one named constant, referenced by the content test and by `FieldView`.
- ADR-0012 may choose a node-per-enemy design with a cost that the pool does not remove. Mitigation: the binding rule here is independent of the draw choice.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| enemy-wave.md | TR-wave-001: one path, position from one distance, view draws from the same points | `PathTable.lookup(d)` is the only position source; the view draws at `EnemyState.position` |
| enemy-wave.md | TR-wave-008: at most 48 alive; pool matches | A fixed pool of 48 `EnemyViewSlot` records bound by `spawn_id`; overflow adds one and logs |
| enemy-wave.md | TR-wave-009: one add-enemy step for schedule and splitters | `_add_enemy` with the halt check before `spawn_id` is spent |
| enemy-wave.md | Rule 9: position computed once in the move step | The move step writes `distance`, `position` and `in_field` together |
| enemy-wave.md | Rule 14: `roster()` and `targets()`; read-only; not kept | Ordered array, cached filtered list, rules in Implementation Guidelines |

TR IDs are provisional until `/architecture-review` registers them.

## Performance Implications

- **CPU**: About 150 compares for lookups and 48 for the targets rebuild per tick at the 48 maximum. Targeting cost is ADR-0007's (worst case about 400 checks, within about 2 ms on a low-end phone, unverified).
- **Memory**: 48 live `EnemyState` plus their Health and Status, and 48 `EnemyViewSlot` records. Total objects created per starter stage: 112 `EnemyState`. Not measured on a device.
- **Load Time**: One `PathTable` build per battle, a few dozen operations.
- **Network**: None.

## Migration Plan

New code, no migration. If ADR-0007 chooses Combat-side tables keyed by `spawn_id`, `_add_enemy` registers there instead of attaching fields; the rest is unchanged.

**Rollback plan**: Drop the `targets()` cache and the `in_field` field and compute the filter per call. Nothing else depends on the cache.

## Validation Criteria

- Position test from `enemy-wave.md` criterion 2: path (0,0), (5,0), (5,5), (25,5); `d` 10, 20, 30 give (5,5), (15,5), (25,5).
- An enemy centred exactly on a field edge is in `targets()`.
- A step that crosses three segments lands on the path.
- `spawn_id` is not spent when the `max_hp` read halts the battle.
- Roster and targets snapshots are identical before and after each reader.
- A scripted stage with 49 alive creates one extra slot and logs one development error.
- Device: the frame budget with 34 and with 48 enemies (ADR-0012 owns the budget).

## Related

- ADR-0001 Simulation and Shell Boundary (depends on)
- ADR-0007 Combat Data Model (QQ-06, attach form)
- ADR-0012 Field and HUD Rendering and Performance Budget (node or draw data per slot)
- ADR-0013 Content Test and Bot Harness (`peak_alive_ub`, snapshot test)
- `design/gdd/enemy-wave.md` (Rules 1, 2, 8, 9, 14, 15; Formulas: position, d_next)
- Deviation from architecture.md: `EnemyState.in_field` is new; `targets()` becomes a cached, reused array.
