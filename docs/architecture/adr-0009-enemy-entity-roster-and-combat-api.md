# ADR-0009: Enemy Entity, Roster and Combat API

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer; reviews by godot-specialist and technical-director (TD-ADR) follow.

## Summary
Combat & Damage and Enemy & Wave both leave open what an enemy is, how Health and Status attach to it, who owns the live list, and the exact `deliver` and targeting API. This ADR makes `Targetable` a concrete `RefCounted` base with `Enemy` as its only MVP subclass, attaches `Health` and `Status` as component objects through one `Combat.attach` call at spawn, makes `EnemyWave` the sole owner of the roster (spawn, path lookup, leak, reap, the Waiting/Active/Finished machine), and fixes `Combat.deliver`, `apply_slow`, the three targeting helpers and the damage-by-source counters as the only way HP changes.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (pinned; 4.7.2 installed at pin time) |
| **Domain** | Core |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM (architecture table; no scene, physics or rendering API is used, only GDScript classes, typed arrays and signals) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`; ADR-0001 probe table (method Callables and signal connections do not keep a `RefCounted` alive, back-references leak, `bind()` holds its arguments); ADR-0004 probes (`roundi` halves away from zero, `float` is 64-bit, `Vector2` components are 32-bit); ADR-0005 probe (`weakref(null)` is a `WeakRef` whose `get_ref()` is null; a typed-return override needs an explicit `return`) |
| **Post-Cutoff APIs Used** | None. `@abstract` (4.5) is deliberately not used: `Targetable` is concrete so Combat tests build plain fixtures |
| **Verification Required** | (1) Two scripts that name each other as typed fields (`Combat.SourceKind` used by `DamageEvent`, `DamageEvent` used by `Combat`) parse and run: NOT SOURCEABLE in the reference; the parse check on both files plus the Combat unit test is the proof, with the fallback in Decision 6. (2) `Array[Targetable]` buffers filled with `Enemy` elements pass the typed-array check, and an `Array[Enemy]` is not assignable to a `Array[Targetable]` parameter (architecture.md B7 states the invariance; the reference does not cover it): one unit test. (3) `is_finite()` is available as a GDScript global on 4.7.2 and returns false for NaN and both infinities: NOT SOURCEABLE; Combat criterion 2's NaN, INF and -INF rows are the proof. (4) A direct-connected signal's handlers run before `emit` returns, so a listener sees the roster as committed before the emit (Enemy & Wave criteria 15, 16, 30, 31): NOT SOURCEABLE in the reference; ADR-0006 owns the signal verification and these criteria exercise it. (5) The 400-range-check budget on an Adreno 5xx-class phone (Decision 7), measured with ADR-0004's plan |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted: builder constructs the sims, method-Callable injection, no back-references, `halted()`, `DevErrorSink`); ADR-0002 (Proposed: Enemy, Wave and Stage records, `StringName` IDs, `path_points`); ADR-0004 (Proposed: the six-slot tick order, `to_ticks`, float policy); ADR-0005 (Proposed: `StatAccessor`, `ReadContext`, the `max_hp` exception). The Proposed ones must be Accepted before any story that implements this ADR |
| **Delegates To** | ADR-0006 (signal names and payloads for `enemy_leaked`, `enemy_killed`, `wave_cleared`, `waves_complete`, `attack_fired`, `damage_applied`; commit-before-emit; the QQ-07 rename of `waves_complete`; Flow's copy of the counters into the stage result; `wave_called_early`); ADR-0004 (the tick slots; this ADR fills slots 2, 3 and 6 internally); ADR-0010 (command result codes, gold on kill, RunLog, the Tower and Hero objects passed as `live_entity`, `hero_share` use in telemetry); ADR-0011 (the enemy view and the combat view); ADR-0007 (test harness, fixture factories, lints) |
| **Enables** | ADR-0010 (Tower and Hero call this API), ADR-0011 (views read `roster()` and the Combat signals) |
| **Blocks** | Every Combat & Damage story and every Enemy & Wave story (architecture.md Required ADRs: "ADR-0009 before any Combat or Enemy & Wave story"); the Tower and Hero targeting and damage stories |
| **Ordering Note** | Acceptance also records QQ-08's fourth change (path and slots moved from the stage scene to the Stage record, already ADR-0002 Decision 11), on the owner's confirmation. `architecture.md` B0 needs two edits at `/architecture-review`: `distance` and `def_id` move from `Enemy` to `Targetable`, and the file paths move from `src/core/...` and `src/feature/...` to `src/battle/` (ADR-0001 Decision 10) |

## Context

### Problem Statement
The Combat GDD ends with "Becomes an ADR: how Health and Status attach to an enemy instance, what call registers them at spawn (with its `max_hp` guard), the enemy's object kind, ownership and reference cycles, the typing of the helpers' list, where `SourceKind` and `DamageEvent` are declared, and Combat's object kind and owner." The Enemy & Wave GDD adds the storage form of `path_points`. ADR-0005 delegated `Targetable`, the `Enemy` type, when an enemy's context is created and the `max_hp` seeding call; ADR-0004 delegated the reap internals; ADR-0001 delegated the Waiting/Active/Finished machine and the `start_next_wave()` error route. Tower and Hero stories cannot start until `deliver` and the helpers are fixed.

### Constraints
- The battle is a pure function of (catalogue, stage_id, seed, command script): no engine clock, no node, no wall time (ADR-0001, ADR-0004). Gameplay classes extend `RefCounted` under `src/battle/`; no lambda, `bind()`, `static var` or `assert` there.
- An enemy must stay a valid reference after removal (`removed` true), so it cannot be a node; a node's built-in `position` would also collide with the cached one (TR-combat-002).
- Combat reads no catalogue data; its only outside need is `to_ticks` (TR-combat-007).
- Retry frees the old battle: no enemy may hold a reference back to `Battle` or to anything that holds it (TR-enemy-008, ADR-0001 Decision 5).
- Every stat is read through the accessor at use time, except `max_hp` once at spawn (ADR-0005 Decision 7). Slow is not a stat (Combat Rule 8).
- Tick order is fixed by ADR-0004: Flow, EnemyWave `advance`, Combat `tick_status`, TowerSim, HeroSim, EnemyWave `reap`, with `halted()` checked between slots.
- Peak alive enemies are at most 48 (Enemy & Wave content check `peak_alive_ub`, art bible §8).

### Requirements
- Cover the 18 requirements in the GDD Requirements Addressed table.
- A recording fake, a plain `Targetable` factory and no catalogue must be enough to test Combat (Combat Acceptance Criteria preamble).
- Per-tick targeting at about 400 range checks under 2 ms (TR-combat-013; unmeasured, QQ-11).

## Decision

**1. Types, files and where they live.** All under `src/battle/` (ADR-0001 Decision 10), all `extends RefCounted`, none a node:

| Class | File | Role |
|---|---|---|
| `Targetable` | `targetable.gd` | Base for anything Combat can damage; concrete |
| `Enemy extends Targetable` | `enemy.gd` | The MVP target; adds its `ReadContext` and a path-segment hint |
| `Health` | `health.gd` | Current HP |
| `Status` | `status.gd` | The one slow slot |
| `DamageEvent` | `damage_event.gd` | Value for one hit on one victim |
| `Combat` | `combat.gd` | `deliver`, `apply_slow`, `speed_factor`, `tick_status`, helpers, counters |
| `PathTrack` | `path_track.gd` | Precomputed segment lengths and position-from-distance |
| `EnemyWave` | `enemy_wave.gd` | Roster owner, schedule, wave machine, leak, reap |

`SourceKind` is declared on `Combat` (`Combat.SourceKind { TOWER, HERO, BURST }`), where the GDD, architecture.md B6 and the Combat tests already name it.

**2. `Targetable` is a concrete base with these members.**
- `spawn_id: int`: the stable instance id. Battle-wide, assigned by `EnemyWave` from 1, **never reused within a battle**; a retry builds a new `EnemyWave`, so ids restart identically (Enemy & Wave edge case "if a retry occurs"). It is the tie-break everywhere.
- `def_id: StringName`, `distance: float` (progress along the path, units; 0 for a target with no path), `position: Vector2` (cached once per tick), `removed: bool`, `health: Health`, `status: Status`.
- `is_dead() -> bool`: `health.hp <= 0.0` (stays answerable after the reap; a leaked enemy is removed but not dead, Combat criterion 18). `is_alive() -> bool`: not removed and not dead; this is the test every helper and every targeting caller uses.
- `distance` and `def_id` sit on `Targetable`, not on `Enemy` as architecture.md B0 drew it, because `first_in(list: Array[Targetable], ...)` ranks by `distance` and the helpers must work on the base type.
- **Writers.** `EnemyWave` alone writes `spawn_id`, `def_id`, `distance`, `position`, `removed`. `Combat` alone writes `health` and `status` (through `attach`, `deliver`, `apply_slow`, `tick_status`). GDScript has no friend access, so ADR-0007's lint and review enforce it.
- **Who extends it.** At MVP only `Enemy`. The hero is a damage **source**, not a target: it has no HP (Combat GDD hand-off to Hero, user decision), and the Tower GDD's towers are not attacked. Neither extends `Targetable`. A hero with HP at the Vertical Slice would extend it with no change to Combat.
- **`live_entity` each owner passes to `ReadContext`** (ADR-0005 Decision 5, restated so this ADR is the single place the entity types appear): `EnemyWave` passes the `Enemy`; `TowerSim` passes the tower object if ADR-0010 gives towers one, otherwise null; `HeroSim` passes the hero object for the Hero context and null for the Burst context unless ADR-0010 says otherwise; `HudLogic` passes null. Only `Enemy` is a `Targetable`; the resolver at the Vertical Slice casts `get_ref()` to `Enemy` when it needs position (ADR-0005 Decision 8).

**3. `Health` and `Status` are component objects held by the `Targetable`, created by one Combat call.**
- `Health` has `hp: float`. `Status` has `slow_strength: float` and `slow_ticks: int` (0 means the slot is empty). Both are plain `RefCounted`, they hold nothing that points back, so there is no cycle (TR-enemy-008).
- At spawn `EnemyWave` does, in this order: create the `Enemy`, set `spawn_id`, `def_id`; create its single `ReadContext(def_id, 0, enemy)` and store it in `Enemy.context` (the enemy owns the context, the context holds a `WeakRef` to the enemy: ADR-0005's no-cycle rule); `max_hp = stat.stat_float(context, StatKeys.MAX_HP)`; `if halted(): return`; `combat.attach(enemy, max_hp)`.
- `Combat.attach(target: Targetable, max_hp: float) -> bool` creates `Health(hp = max_hp)` and an empty `Status`, assigns both. It is the **one place `max_hp` is cached**: nothing re-reads it (ADR-0005 Decision 7, `stat_value_caching` exception). Its guard: `max_hp` not finite or not above 0, a null target, or an already-attached target gives `ERR_BAD_MAX_HP` / `ERR_NO_TARGET` through `dev_error`, attaches nothing and returns false. `EnemyWave` treats false as unrecoverable (a catalogue or resolver defect that the validator should have excluded): it calls the injected `fatal(cause)` and returns, so no half-built enemy ever joins the roster.
- The spawn step is the **add-enemy step** (TR-enemy-013): one private method `_add_enemy(def_id, start_distance)` serves the schedule (distance 0) and any future splitter child, and the enemy joins `_live` only after `attach` succeeded.

**4. Slow, the one MVP status.** One slot per enemy, strength is the fraction of speed removed, time is held in whole ticks.
- `apply_slow(enemy, strength, seconds)`: guards in order removed (`ERR_REMOVED`), values (`ERR_BAD_SLOW` when strength is not finite or not strictly between 0 and 1, seconds not finite or not above 0, or `to_ticks(seconds) < 1`), dead (silent no-op). Then ticks `n = to_ticks(seconds)`; empty slot: set; stronger strength: replace both strength and ticks (even with less time); equal strength: keep the larger tick count; weaker: ignore. Strengths are authored values compared exactly, never computed.
- `speed_factor(enemy) = 1.0 - slow_strength` if `slow_ticks > 0`, else `1.0`.
- `tick_status(roster: Array[Targetable])` (slot 3) subtracts 1 from every non-empty slot and clears any slot that reaches 0, including a dead enemy's. It emits nothing and skips nothing; removed enemies are never in the roster.
- Count check: a slow applied in slot 4 of tick t with `n` ticks is read by the move step of ticks t+1 to t+n and cleared in slot 3 of tick t+n, so it affects exactly `n` moves (Combat criteria 7, 9: 30 reads for 0.5 s at 1/60).
- `to_ticks(seconds) < 1` is a decision the GDD does not state (it only guards seconds not above 0); a value below half a tick is reported, never clamped to one tick, in the spirit of ADR-0002's `catalogue_fallback_value`.

**5. `Combat` is a plain `RefCounted` built by `BattleBuilder.build()`, held by `Battle`.** `Combat.new(to_ticks: Callable, dev_error: Callable)`, both method Callables (ADR-0001 Decision 5), neither guarded with `is_valid()`. It holds no `EnemyWave`, no catalogue, no `halted` and no enemy: only counters keyed by source ID. `EnemyWave`, `TowerSim` and `HeroSim` each receive the `Combat` object; `Battle.tick` passes `enemy_wave.roster()` to `combat.tick_status` (slot 3). No sim holds another sim (ADR-0001 Decision 5). `halted()` is **not** injected into Combat (TR-combat-007 keeps its dependencies at `to_ticks`, plus the defect sink): every caller checks `halted()` after each `deliver` (it emits), per ADR-0001.

**6. `DamageEvent` and `deliver`.**
- `DamageEvent extends RefCounted` with `target: Targetable`, `amount: float`, `source_kind: Combat.SourceKind`, `source_id: StringName`. `source_kind` and `source_id` name **who dealt** the damage (the tower, hero or burst definition ID). A future "who granted" (a modifier's grantor, for example the hero buffing a tower) gets its own field, reserved as `granted_by: StringName`, **not added at MVP** (the GDD builds none) and never stored in `source_id`; damage from a buffed tower counts as that tower's (Combat Rule 5).
- No `tick` field: Combat has no clock and the GDD's DamageEvent has none. Telemetry takes the tick from the battle's tick counter when it records an event (ADR-0010). Alternative recorded below.
- One event per victim. Events are allocated per hit and not pooled: at most 17 in a splash (Combat criterion 6) and a few per second per source, far below one per tick. Listeners never keep an event (views use the copied `position` and `spawn_id`, Combat Rule 12).
- `deliver(event) -> float` returns the amount applied (0.0 for anything rejected or ignored), runs only inside a tick (caller discipline, checked by the Order deferred criterion), and runs these guards in this fixed order, only the first failure reporting:

| # | Condition | Reports (via `dev_error`) | Returns | HP, counters, signal |
|---|---|---|---|---|
| 1 | null event, null target or target with no `health` | `ERR_NO_TARGET` (an addition to the GDD, a null-dereference guard) | 0.0 | none |
| 2 | `target.removed` | `ERR_REMOVED` | 0.0 | none |
| 3 | `amount` not finite or below 0 | `ERR_BAD_AMOUNT` | 0.0 | none |
| 4 | target `is_dead()` | silent | 0.0 | none |
| 5 | `amount == 0.0` | silent | 0.0 | none, no `damage_applied` |

  Then `applied = min(amount, hp)` (when `amount >= hp`, `hp` is set to exactly 0.0), the per-source counters add `applied`, and **last** `damage_applied(event, applied, target.position, killed, target.spawn_id)` is emitted with `killed = (hp <= 0.0)`. The signal is on Flow's view allowlist, nothing in gameplay depends on it, and no listener may call `deliver` (ADR-0006). The caller checks `halted()` after `deliver` returns. The three error messages are `const String` on `Combat`, so a test names them.
- **Fallback if the two scripts that name each other fail to parse** (Verification 1): move the enum to `DamageEvent.SourceKind`, keep `Combat.SourceKind` out, and update the three docs that name `Combat.SourceKind`. Not taken now because the GDD, architecture.md and the tests already use `Combat.SourceKind`.

**7. Targeting helpers, and the per-tick budget.** Three pure methods on `Combat`, over a caller-supplied `Array[Targetable]` (typed, built as `Array[Targetable]` from the start because typed arrays are invariant: architecture.md B7), never mutating the list:
- `first_in(list, origin, max_range) -> Targetable`: among those in range and `is_alive()`, the greatest `distance`; ties go to the lowest `spawn_id`; null if none.
- `nearest_in(list, origin, max_range) -> Targetable`: smallest squared distance to `origin`; ties to the lowest `spawn_id`; null if none.
- `all_in_radius(list, impact, radius) -> Array[Targetable]`: everyone in range and alive, in **input order**; callers pass `targets()` (spawn_id order), so events run in ascending `spawn_id`.
- In range is `dx*dx + dy*dy <= max_range*max_range`, inclusive, on the enemy's cached `position` components with scalar `+ - *` only and no `Vector2` method (ADR-0004 Decision 12). Range is applied **before** ranking, so a further-along enemy out of range never wins. The tie-break compares `spawn_id` explicitly, so the result is right in every input order (Combat criterion 10).
- The parameter is `max_range` because `range` is a GDScript global (architecture.md B6). The helpers scan rather than sort (no `sort_custom`, hence no Callable question under ADR-0001's lambda ban).
- Policies are the callers': towers use `first_in`; a slow tower first filters on `speed_factor == 1.0` then falls back to all (Tower Rule 9); the hero uses `nearest_in(targets(), position, leash_radius)` (Hero step 3); the burst and splash use `all_in_radius`. A "densest cluster" helper is **not MVP** (Combat GDD: targeting options are deliberately not built).
- **Budget.** Combat's allocation is about 400 range checks under 2 ms per tick on a low-end phone, **unmeasured** (TR-combat-013, QQ-11). ADR-0004's simulation slice is 4.0 ms per frame at the two-tick cap. Read per tick, two capped ticks at 2 ms each equal the whole 4.0 ms slice with nothing left for `advance`, `tick_status`, `reap` and the accessor reads; read per frame, 400 checks fit in half of it. The two readings differ by a factor of two, and only a device run chooses between them. Combat therefore keeps `range_checks: int`, incremented once per enemy tested in a helper and reset at the start of `tick_status`, readable by dev telemetry (ADR-0010), so the first phone build records checks per tick next to ADR-0004's `Clock.advance` timings. If the p99 per-tick cost is over budget, the candidates are a coarse bucket grid over `targets()`, a per-tower early reject on the tower's range read once per tick (ADR-0005), or a lower `MAX_TICKS_PER_FRAME`; none is chosen until measured.

**8. Splash, burst and damage-by-source.**
- **Order of resolution** for a tower, hero or burst attack: (a) the attacker reads its stats (accessor, never cached) and checks `halted()`; (b) sets its own cooldown; (c) `report_attack(...)` (emits `attack_fired`, nothing else: Tower step 4, Hero step 7); (d) the victim list is computed **once**, by `first_in` / `nearest_in` for the single target or `all_in_radius(targets(), impact, radius)` for splash (a tower's impact is its target's position at fire time; a burst's is its aim point); (e) one `deliver` per victim in ascending `spawn_id`, the primary target included once and given no separate event, `halted()` checked after each; (f) a slow tower then calls `apply_slow` per victim (an attacker delivers first, so a slow never lands on an enemy that hit killed); (g) the attacker's own counters. Because the list is computed before any event, an earlier victim's death does not change who is in it. A burst with no victims emits `attack_fired` only.
- **Splash sources are `targets()` only** (TR-tower-007): an enemy outside the 540x960 field is never a victim.
- **Damage-by-source accounting is owned by `Combat`**: `_dealt_by_id: Dictionary` (`StringName` to `float`) and a three-slot `Array[float]` by `SourceKind`. `deliver` adds `applied`, never `amount`, so overkill cannot inflate hero share. Reads: `dealt_by_id(id)` (0.0 for an unknown ID), `dealt_by_kind(kind)`, `dealt_total()` (the sum of the kind sums) and `hero_share() = (hero + burst) / total` (0.0 when total is 0). Counters survive the reap and the outcome and live until the battle is destroyed; nothing resets them. Flow copies them into the stage result (ADR-0006), the HUD reads them once at the outcome, and bots and RunLog read `hero_share` and `dealt_by_kind(BURST)` (ADR-0010). Nothing else holds a per-source total.

**9. Roster ownership and the typed lists.**
- `EnemyWave` is the **sole owner** of enemies. It holds `_live: Array[Enemy]` in spawn_id order (the owning list, typed so the movement and reap code reach `context` and `segment` without a cast) and two reused buffers `_roster_buf` and `_targets_buf: Array[Targetable]`. `roster()` returns `_roster_buf`: every enemy not yet removed, corpses awaiting the reap included. `targets()` returns `_targets_buf`: the same, limited to those whose centre is inside the field rectangle, edges included (0..540, 0..960; TR-enemy-011), where the field size is a plain value injected at build (the `DisplayContract` field size, ADR-0003; the exact name is confirmed when `build()` is written).
- The buffers are cleared and refilled by one private `_rebuild_views()` (at most 48 appends each) after the move and leak step of slot 2, after each leak removal, after each spawn and after the reap. They are valid **for the slot that read them**: a caller must not keep, mutate or sort them (TR-enemy-008, architecture.md B7). A helper never mutates its list; a snapshot test proves it.
- Two buffers rather than one `Array[Targetable]` owner: the owner stays typed `Array[Enemy]`, at the cost of a second fill and a sync rule (only `_rebuild_views` fills them). The cost is two passes over at most 48 elements per rebuild.
- No back-references: an `Enemy` points to its `Health`, `Status` and `ReadContext` only; the context holds a `WeakRef` back. `Combat` holds no enemy. After a retry `free()` of the wrapper, the old `EnemyWave`, its enemies and their components are released; ADR-0001's weakref test adds a weakref to one `Enemy`.
- `got_through_by_type() -> Dictionary` (`StringName` to `int`) returns `duplicate()` of the internal counts, a view read at the outcome and per frame by the HUD pips; `wave_index() -> int` is the 1-based position in `wave_ids` of the last wave started, 0 before any start, never reset per wave (TR-enemy-016).

**10. Spawn schedule.** `start_next_wave()` (Decision 14) builds the wave's flat schedule once from the `WaveRecord` for the new index: for each group in authored order, for member `i` from 0, `tick = to_ticks(start_delay + i * spawn_interval)`; each entry is **inserted by hand** after the last entry whose tick is not greater, so entries are ordered by (tick, authored order) with no `sort_custom` and no instability question. The schedule is two parallel arrays (`Array[int]` ticks, `Array[StringName]` ids) and a cursor. In slot 2, every entry whose tick equals `wave_tick` spawns through `_add_enemy`, each taking the next `spawn_id` (`_next_spawn_id`, from 1, incremented per spawn, never decremented, never reset by a wave start); `wave_tick` rises at the end of the slot. `spawn_interval` has no effect when `count` is 1. `EnemyWave` draws no randomness and never reads the seed (Rule 6; ADR-0004 Decision 10).

**11. Path lookup and movement.**
- `PathTrack` is built once in `EnemyWave`'s constructor from the Stage record's `path_points: Array[Vector2]`: `lens: Array[float]` (segment lengths, never 0: the validator rejects repeated consecutive points, ADR-0002), `cum: Array[float]` (length before each point), `length: float`. It stores floats, not `Vector2` methods: `segment_for(d, hint) -> int` walks forward from the hint (an enemy never moves backwards: speed times `speed_factor` is above 0 because slow strength is below 1) and `point_at(d, k) -> Vector2` is `P[k] + (d - cum[k]) / lens[k] * (P[k+1] - P[k])` computed per component, clamped to the last point once `d >= length` (Enemy & Wave Formulas; criteria 5, 6).
- Position is **looked up from distance**, not walked, so one step can cross several corners.
- Per tick, per enemy, in slot 2 after spawning: `speed = stat.stat_float(enemy.context, StatKeys.MOVE_SPEED)` (use time, never stored); `if halted(): return`; `enemy.distance = d_next(enemy.distance, speed, combat.speed_factor(enemy))` with `d_next = d + speed * factor * dt` as the Enemy & Wave Formulas define it (the formula is not re-derived here); `enemy.segment`, `enemy.position` updated once. An enemy moves on the tick it spawns.

**12. Leak.** After the move step, in ascending `spawn_id`: an enemy whose `distance >= track.length` leaks. In this order: set `distance = length`; read `lives_cost` through the accessor and `if halted(): return`; set `removed = true`; remove it from `_live`; `_rebuild_views()`; count it in `got_through_by_type`; emit `enemy_leaked(lives_cost)`; `if halted(): return`. So the roster already excludes it inside the handler (Enemy & Wave criterion 15) and a fatal leak stops the loop with the later enemies left in place (criterion 16). A leaked enemy is removed but not dead and is never a target or victim after that; no bounty is paid.

**13. Reap and the clear check (slot 6).** `reap()` returns at once if `halted()`. Otherwise, in ascending `spawn_id`, for each enemy with `is_dead()`: read `bounty` through the accessor, `if halted(): return`; set `removed = true`; remove it from `_live` by index; `_rebuild_views()`; emit `enemy_killed(bounty)`; `if halted(): return`. This commits the removal before the emit (ADR-0006's commit-before-emit); the GDD's Rule 11 lists "fires, and the corpse is removed" in narrative order, and the difference is observable only by a listener that reads `roster()`, which no listener does. The corpse is reaped on the tick it dies and so never moves again. Then the clear check, **every tick, not only after a kill**, and only while `ACTIVE`: if the cursor is past the last schedule entry and `_live` is empty, the wave is clear. State is committed first (Decision 14), then `wave_cleared(intermission_duration)` (the finished wave's record, read directly) or, on the last wave, `waves_complete()`; then `halted()` is checked. A kill listener that calls `_add_enemy` joins before the clear check (Enemy & Wave criterion 28).

**14. The wave machine and the commands that touch it.**
- `enum WaveState { WAITING, ACTIVE, FINISHED }`; reads `wave_state()`, `wave_tick()`, `wave_index()`. Initial state WAITING, index 0.
- `start_next_wave() -> void`, parameterless, called by Flow (never by a view): in WAITING with a next wave it commits at once: index + 1, `wave_tick = 0`, schedule built, state ACTIVE. In ACTIVE, or in FINISHED (past the last wave), it **reports through `dev_error` with `ERR_START_WRONG_STATE` (naming the state and index) and returns with nothing changed**. It never calls `fatal` (TR-enemy-012 first clause, ADR-0001 Decision 8). If `halted()` it returns silently. The first spawn happens in the next slot 2: a countdown-end start commits in Flow's slot 1 so spawns the same tick, an early or Start Wave start commits between ticks so spawns on the next one (Rule 7).
- Transitions: ACTIVE to WAITING on a clear of a non-last wave; ACTIVE to FINISHED on the last wave's clear; FINISHED never leaves. A listener to `wave_cleared` already reads WAITING with the same `wave_index()`; a listener to `waves_complete` reads FINISHED (criteria 30, 31).
- **Signal names.** `waves_complete` is written as the GDD names it. QQ-07 may rename it (for example `waves_completed`); ADR-0006 settles the final name, and the rename is one identifier here and in the GDD.
- **`wave_called_early`** is a **Flow** signal (Module Ownership: Flow emits it, TowerSim consumes it for the gold bonus). `EnemyWave` neither emits nor consumes it: from its side an early call is just a `start_next_wave()` that arrives between ticks, and whether Flow emits before or after calling is ADR-0006's commit-before-emit ordering.

**15. `halted()` discipline in `EnemyWave`.** `halted` is an injected method Callable. It is checked after every accessor read, before the value is used, and after every emit, in `_add_enemy`, the move step, the leak scan and the reap; `advance` and `reap` return at once when it is true on entry. Enemies on the roster at an outcome freeze where they are (Rule 13). Private methods stay under the 40-line and complexity-10 limits: `_spawn_due`, `_move_all`, `_leak_scan`, `_reap_dead`, `_check_clear`, `_rebuild_views`, `_add_enemy`, `_build_schedule`.

**16. Parallel lanes (the fallback, cross-GDD D9): what `path_id` would change.** The one-distance model puts one `PathTrack` and one `distance` on every enemy. Parallel lanes (Enemy & Wave Rule 1: after the Vertical Slice, and the first thing to pull forward if the re-pin question fails) would add `path_id` to `WaveGroup` (ADR-0002 schema field, validator rule that it names a path on the stage, content test), replace the Stage record's single `path_points` with a list of named paths, and give `EnemyWave` one `PathTrack` per path with `Enemy.path_id` set in `_add_enemy`. Movement, the leak test against that lane's `length`, and `got_through_by_type` would index by lane. What stays the same: `Targetable`, `Health`, `Status`, `deliver`, `apply_slow`, the counters, the reap, the clear check and the wave machine. The one real design decision is ranking: `first_in` ranks by raw `distance`, which is not comparable across lanes of different length, so lanes need either a `progress` (distance divided by lane length) on `Targetable` or a per-lane `first_in`; that choice changes tower targeting policy and belongs to the Tower and Enemy & Wave GDDs. Keeping all position reads behind `PathTrack` methods and out of `Combat` is what keeps this a local change. Nothing for lanes is built now.

**17. Delegations.** Signal names and payloads, commit-before-emit and `waves_complete`'s final name: ADR-0006. The tick slots and the clock: ADR-0004 (this ADR defines only what happens inside slots 2, 3 and 6). Command result codes, gold on a kill (`enemy_killed` to TowerSim), RunLog, the Tower and Hero objects: ADR-0010. The enemy view, the combat view and their draw budget: ADR-0011. The test harness, fixture factories (a `Targetable` factory, a recording fake for the four signals, a spy `dev_error`), and the lints: ADR-0007.

### Architecture Diagram

```
 BattleBuilder.build()  ──constructs──►  Combat(to_ticks, dev_error)
                                         EnemyWave(stat, combat, track, waves, field_size, dt,
                                                   halted, dev_error, fatal, to_ticks)
 Battle.tick slots:
   2  EnemyWave.advance(tick): spawn due -> move (accessor MOVE_SPEED x speed_factor) -> leak
   3  Combat.tick_status(enemy_wave.roster())
   4  TowerSim ─ targets() ─► Combat.first_in / all_in_radius ─► report_attack, deliver, apply_slow
   5  HeroSim  ─ targets() ─► Combat.nearest_in / all_in_radius ─► report_attack, deliver
   6  EnemyWave.reap(): dead -> bounty read -> removed -> enemy_killed; then clear check

 EnemyWave ──owns──► _live: Array[Enemy] ──► Enemy ──► Health, Status, ReadContext ─weak─► Enemy
           └─ _roster_buf / _targets_buf: Array[Targetable]  (valid for one slot)
 Combat    ──owns──► counters (id -> float, kind -> float); holds no enemy, no EnemyWave
```

### Key Interfaces

```gdscript
# src/battle/targetable.gd
class_name Targetable extends RefCounted
## Anything Combat can damage. Concrete, so Combat tests use plain factories.
var spawn_id: int = 0            ## battle-wide, from 1, never reused; the tie-break
var def_id: StringName = &""
var distance: float = 0.0        ## progress along the path; EnemyWave writes it
var position: Vector2 = Vector2.ZERO  ## cached once per tick; EnemyWave writes it
var removed: bool = false        ## EnemyWave sets it on leak or reap
var health: Health = null        ## Combat.attach writes it
var status: Status = null        ## Combat writes it
func is_dead() -> bool: return health != null and health.hp <= 0.0
func is_alive() -> bool: return not removed and health != null and health.hp > 0.0

# src/battle/enemy.gd
class_name Enemy extends Targetable
var context: ReadContext = null  ## one per enemy; live_entity is a WeakRef to this
var segment: int = 0             ## PathTrack hint; EnemyWave only

# src/battle/health.gd / status.gd
class_name Health extends RefCounted
var hp: float = 0.0
class_name Status extends RefCounted
var slow_strength: float = 0.0
var slow_ticks: int = 0          ## 0 = empty slot

# src/battle/damage_event.gd
class_name DamageEvent extends RefCounted
var target: Targetable
var amount: float
var source_kind: Combat.SourceKind
var source_id: StringName        ## who DEALT it. A future grantor gets its own field (granted_by).
func _init(p_target: Targetable, p_amount: float, p_kind: Combat.SourceKind, p_source_id: StringName) -> void

# src/battle/combat.gd
class_name Combat extends RefCounted
enum SourceKind { TOWER, HERO, BURST }
const ERR_REMOVED: String = "..."; const ERR_BAD_AMOUNT: String = "..."; const ERR_BAD_SLOW: String = "..."
const ERR_NO_TARGET: String = "..."; const ERR_BAD_MAX_HP: String = "..."
signal attack_fired(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(event: DamageEvent, applied: float, position: Vector2, killed: bool, spawn_id: int)
var range_checks: int = 0        ## per-tick counter for the budget; reset in tick_status
func _init(p_to_ticks: Callable, p_dev_error: Callable) -> void
func attach(target: Targetable, max_hp: float) -> bool            ## the one max_hp cache
func deliver(event: DamageEvent) -> float                         ## applied amount; inside a tick only
func apply_slow(enemy: Targetable, strength: float, seconds: float) -> void
func speed_factor(enemy: Targetable) -> float
func tick_status(roster: Array[Targetable]) -> void
func first_in(list: Array[Targetable], origin: Vector2, max_range: float) -> Targetable
func nearest_in(list: Array[Targetable], origin: Vector2, max_range: float) -> Targetable
func all_in_radius(list: Array[Targetable], impact: Vector2, radius: float) -> Array[Targetable]
func is_dead(enemy: Targetable) -> bool
func hp_left(enemy: Targetable) -> float
func report_attack(kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func dealt_by_id(id: StringName) -> float
func dealt_by_kind(kind: SourceKind) -> float
func dealt_total() -> float
func hero_share() -> float

# src/battle/path_track.gd
class_name PathTrack extends RefCounted
var length: float
func _init(points: Array[Vector2]) -> void
func segment_for(d: float, hint: int) -> int
func point_at(d: float, segment: int) -> Vector2                  ## clamped to the last point

# src/battle/enemy_wave.gd
class_name EnemyWave extends RefCounted
enum WaveState { WAITING, ACTIVE, FINISHED }
const ERR_START_WRONG_STATE: String = "..."
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_complete()                                          ## final name: ADR-0006 (QQ-07)
func _init(p_stat: StatAccessor, p_combat: Combat, p_track: PathTrack, p_waves: Array[WaveRecord],
		p_field_size: Vector2, p_dt: float, p_halted: Callable, p_dev_error: Callable,
		p_fatal: Callable, p_to_ticks: Callable) -> void
func start_next_wave() -> void                                    ## wrong state: dev_error, never fatal
func advance(tick: int) -> void                                   ## slot 2
func reap() -> void                                               ## slot 6
func roster() -> Array[Targetable]                                ## spawn_id order; valid for the slot
func targets() -> Array[Targetable]                               ## inside the field; valid for the slot
func wave_index() -> int
func wave_state() -> WaveState
func wave_tick() -> int
func got_through_by_type() -> Dictionary                          ## copy
```

### Implementation Guidelines
- Every HP change **must** go through `Combat.deliver` (and the one seed in `Combat.attach`); code **must never** write `health.hp` anywhere else, and **must never** write `status` fields outside `Combat`.
- `deliver` **must** run only inside a tick, from a sim's slot; it **must never** be called from a signal handler of `damage_applied`, from a command, or from a view.
- Callers **must** check `halted()` after every `deliver`, `apply_slow` that follows a `deliver`, and accessor read, and return at once if true.
- `Targetable`, `Enemy`, `Health`, `Status`, `DamageEvent`, `Combat`, `PathTrack` and `EnemyWave` **must** extend `RefCounted`, **must never** extend `Node` or `Resource`, and **must never** store a reference to `Battle`, to another sim, or to the `EnemyWave` from an enemy.
- Only `EnemyWave` **may** set `removed`, `distance`, `position`, `spawn_id`, `segment` and **may** add to or remove from `_live`; an enemy **must** leave the roster only by the leak step or the reap step; `spawn_id` **must never** be reused or reset within a battle.
- `roster()` and `targets()` **must** return the reused typed buffers; callers **must never** keep them past their slot, mutate them or sort them; `Combat` helpers **must never** mutate the list passed in.
- Lists passed to Combat **must** be `Array[Targetable]`; code **must never** pass an `Array[Enemy]`.
- `max_hp` **must** be read once, through the accessor, in the spawn step and passed to `Combat.attach`; every other enemy stat (`move_speed`, `bounty`, `lives_cost`) **must** be read at the moment of use through the enemy's one `ReadContext`.
- An enemy's `ReadContext` **must** be created in `_add_enemy` before the `max_hp` read, stored on the `Enemy`, and its `live_entity` **must** be a `WeakRef` to the enemy; it **must never** be shared.
- Range checks **must** use the inclusive squared-distance test on scalar components and **must never** call a `Vector2` method; helpers **must** break ties by explicit `spawn_id`, not by iteration order.
- `start_next_wave()` in the wrong state **must** call the injected `dev_error` with `ERR_START_WRONG_STATE` and return without changing state; it **must never** call `fatal`.
- The wave schedule **must** be built with the manual insertion of Decision 10; `sort_custom` **must never** be used for it, and no lambda **may** appear under `src/battle/`.
- A wave clear **must** be checked every tick while `ACTIVE`, with state committed before `wave_cleared` / `waves_complete` is emitted.
- Counters **must** add `applied`, never `amount`, and **must never** be reset, copied-then-cleared or written outside `deliver`.
- `Combat` **must never** read the catalogue or the accessor, and slow **must never** go through the stat accessor.
- `EnemyWave` **must never** read the seed or any RNG.

## Alternatives Considered

### Alternative 1: `Health` and `Status` as plain fields on `Targetable`
- **Description**: `hp`, `slow_strength`, `slow_ticks` directly on the target; no component objects.
- **Pros**: Two fewer objects per enemy (about 96 fewer at peak); no attach step.
- **Cons**: Combat's state lives in a class `EnemyWave` writes; a hero with HP at the Vertical Slice needs the fields copied; the GDD and architecture.md B0 both say "one Health and one Status per target".
- **Rejection Reason**: The allocation saving is at spawn only. The GDD's piece list and B0 recommend components; the `attach` call is also the one place the `max_hp` guard sits.

### Alternative 2: Enemy as a `Node` or `Resource`
- **Description**: A scene node per enemy, owned by the tree, or a `Resource` instance.
- **Pros**: The view could bind directly.
- **Cons**: A freed node cannot honour `removed`; a node's `position` collides with the cached one (TR-combat-002); the battle must tick with no scene (ADR-0001).
- **Rejection Reason**: Violates `node_in_gameplay_class` and TR-combat-002.

### Alternative 3: A strong `Array[Targetable]` as the only owning list
- **Description**: One owner list of base-typed elements, casting to `Enemy` where needed.
- **Pros**: One list, no buffers, no sync rule.
- **Cons**: A cast at every movement and reap access; `roster()` would hand out the owner list itself, which any caller could mutate.
- **Rejection Reason**: The two reused buffers cost at most 96 appends per rebuild and keep the owner private; chosen on the owner's `Array[Enemy]` instruction.

### Alternative 4: `tick` on `DamageEvent`, and `halted` injected into Combat
- **Description**: Combat given the battle tick and `halted()`; every event stamped with its tick; `deliver` refusing when halted.
- **Pros**: Self-describing events for telemetry; one more guard.
- **Cons**: Combat gains two dependencies beyond `to_ticks` (TR-combat-007); the GDD's DamageEvent has no tick; callers must check `halted()` after the emit anyway.
- **Rejection Reason**: The GDD recommends the smaller value type; telemetry can stamp the tick itself.

### Alternative 5: `SourceKind` on `DamageEvent`
- **Description**: Declare the enum on the leaf value class to avoid two scripts naming each other.
- **Pros**: No script cycle.
- **Cons**: Three documents and the tests name `Combat.SourceKind`.
- **Rejection Reason**: Kept as the recorded fallback (Decision 6), taken only if Verification 1 fails.

### Alternative 6: A single mixed list sorted by `spawn_id` and a spatial grid now
- **Description**: A bucket grid over enemies for range queries from day one.
- **Pros**: Fewer range checks per query.
- **Cons**: A structure to keep in sync with movement, built for a budget nobody has measured (QQ-11); at 48 enemies a scan is 48 checks.
- **Rejection Reason**: Measure first; the grid is named as the first fallback in Decision 7.

## Consequences

### Positive
- One path for HP (`deliver`) makes the counters, the hero-share metric and the result screen exact; overkill cannot inflate hero share.
- A concrete `Targetable` lets Combat be tested with no catalogue and no scene.
- Roster ownership in one class plus the reap/leak rule makes "an enemy leaves the roster only by leak or reap" lintable.
- `start_next_wave()` errors never end a battle; accessor and attach defects do.
- The lanes fallback is a local change, described in Decision 16.

### Negative
- Two reused buffers must be kept in sync with `_live`; a caller that keeps one past its slot sees it change.
- `Combat.SourceKind` and `DamageEvent` name each other; if that does not parse, the enum moves and three docs change.
- No `tick` on `DamageEvent`; telemetry stamps it.
- The reap commits removal before the emit, a reading of Rule 11 the owner should confirm.
- The 400-check budget may leave zero slack against ADR-0004's 4.0 ms slice if it is per tick.

## Risks
- **Per-tick budget misses on the phone** (unmeasured). Mitigation: `range_checks` counter in the first phone build; fallbacks named in Decision 7.
- **A caller holds `roster()` past its slot.** Mitigation: ADR-0007 lint on stored results, a snapshot test, review.
- **A typed-array or cyclic-script rule behaves differently on 4.7.2.** Mitigation: Verification 1 and 2 and their fallbacks.
- **A tick-boundary mismatch changes slow duration by one move.** Mitigation: Combat criteria 7, 9 (30 reads at 1/60).
- **`to_ticks(seconds) < 1` for a valid slow duration.** Mitigation: reported, not clamped; ADR-0002's validator floor (`MIN_INTERVAL_SECONDS`) should cover tower slow durations; confirm in the Tower story.
- **An enemy `spawn_id` leaks into replay or save data expecting reuse.** Mitigation: ids are battle-local and never persisted (no save at MVP).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-001: three pieces, DamageEvent, one Health and one Status per enemy, no ProjectileSpawner | Decisions 1, 3, 6 |
| combat-damage.md | TR-combat-002: enemy exposes spawn_id, cached distance and position, removed; valid after removal | Decision 2 (`Targetable`, `RefCounted`) |
| combat-damage.md | TR-combat-003: every HP change through `deliver` inside a tick; min(amount, hp); guards in order with named codes | Decision 6 (guard table) |
| combat-damage.md | TR-combat-004: death at 0; dead cannot be targeted; reap removes corpse, emits `enemy_killed(bounty)` once | Decisions 2, 7, 13 |
| combat-damage.md | TR-combat-005: per-source counters, readable until the battle is destroyed | Decision 8 |
| combat-damage.md | TR-combat-006: slow whole-tick countdown, replace/equal/ignore, `speed_factor` | Decision 4 |
| combat-damage.md | TR-combat-007: Combat reads no catalogue; only `to_ticks` with dt injected | Decision 5 |
| combat-damage.md | TR-combat-008: pure helpers, inclusive squared distance, lowest `spawn_id` tie, no mutation | Decision 7 |
| combat-damage.md | TR-combat-013: about 400 range checks under 2 ms, unmeasured | Decision 7 (budget, counter, fallbacks) |
| enemy-wave.md | TR-enemy-008: roster sole owner, read-only `roster()` and `targets()`, no back-references | Decision 9 |
| enemy-wave.md | TR-enemy-009: how Health and Status attach to an enemy | Decision 3 |
| enemy-wave.md | TR-enemy-010: position from distance via cached cumulative lengths, multi-segment, clamped | Decision 11 |
| enemy-wave.md | TR-enemy-011: targetable only inside the 540x960 field | Decision 9 (`targets()`) |
| enemy-wave.md | TR-enemy-013: one add-enemy step | Decisions 3, 10 |
| enemy-wave.md | TR-enemy-016: `wave_index()` 1-based, 0 before any start, never reset | Decisions 9, 14 |
| enemy-wave.md | TR-enemy-017: `got_through_by_type()` counts a leak before `enemy_leaked` | Decision 12 |
| tower-system.md | TR-tower-007: targeting and damage only through Combat's API; splash victims only from `targets()` | Decisions 7, 8 |
| hero-system.md | TR-hero-007: `deliver` with HERO/BURST, `report_attack` before `deliver`, `nearest_in`, `all_in_radius`, `is_dead`, `hp_left` over `targets()` | Decisions 6, 7, 8 |

## Performance Implications
- **CPU**: One accessor read of `move_speed` per enemy per tick (at most 48), one position lookup per enemy per tick from a cached segment hint, two buffer rebuilds of at most 48 appends per slot that changes the roster, and the helpers' range checks, about 400 per tick estimated under 2 ms (unmeasured, QQ-11; Decision 7).
- **Memory**: At most 48 enemies of five small objects each (`Enemy`, `Health`, `Status`, `ReadContext`, `WeakRef`), two 48-element buffers, one `DamageEvent` per victim hit, released on use. No per-tick allocation except events.
- **Load Time**: `PathTrack` built once per battle from at most a few dozen points.
- **Network**: None.

## Migration Plan
No code exists yet. `architecture.md` B0 (`distance` and `def_id` move to `Targetable`; paths `src/battle/`), B6 and B7 are updated at `/architecture-review`. If Verification 1 fails, the `SourceKind` fallback of Decision 6 applies and the Combat, Tower and Hero GDD references change in one commit.

## Validation Criteria
- Combat GDD criteria 1 to 18 pass as unit tests in `tests/unit/combat/` (HP 12 and `deliver` 30 gives applied 12; NaN, INF, -INF and -5 give `ERR_BAD_AMOUNT` and an empty log; a removed enemy gives `ERR_REMOVED` alone; helper tie-breaks in every input order; slow reads: 30 at 1/60 for 0.5 s; counters and `hero_share` 0.30; `is_dead` false for a leaked enemy). TR-combat-001 to 008.
- Enemy & Wave GDD criteria pass in `tests/unit/enemy_wave/`: roster holds a corpse until the reap (54); `targets()` edge inclusion (4); position across two corners (5, 6); leak emits with the roster already excluding it (15, 16); a halt on the first leak keeps the second enemy (16); no emission after Finished (26); clear after leak and after kill (23, 27, 29); a listener sees WAITING or FINISHED (30, 31); `start_next_wave()` in ACTIVE or FINISHED gives one `ERR_START_WRONG_STATE` and no state change (36); spawn order across groups and `spawn_id` continuing across waves (40, 41). TR-enemy-008 to 017.
- New: the retry test adds a weakref to an `Enemy` and to its `ReadContext` that both read null after teardown (TR-enemy-008); a test shows `max_hp` is read exactly once per spawn through a spy accessor and no other stat is cached (ADR-0005's spy); `attach` with 0, NaN, INF and an already-attached target returns false and the wave calls `fatal`; a snapshot test shows no helper mutates its list; the `src/battle/` lint finds no lambda, `bind`, `static var`, `assert`, `sort_custom` on the schedule, and no write to `removed`, `spawn_id`, `distance`, `position`, `health` or `status` outside their owners.
- TR-tower-007 and TR-hero-007: the Tower and Hero stories include an integration test where a splash never hits an enemy outside the field and every attack reports before it delivers.
- The first phone build records `range_checks` per tick and the p99 per-tick cost of targeting with ADR-0004's plan; the budget (2 ms per tick, 400 checks) passes or Decision 7's fallback is chosen.
- Not covered here and verified elsewhere: signal payload types and names (ADR-0006), gold on kill (ADR-0010), the enemy view (ADR-0011).

## NOT SOURCEABLE
- NOT SOURCEABLE: two GDScript files each naming the other as a typed member (`Combat.SourceKind` and `DamageEvent`) parse and run on 4.7.2 (not covered by `docs/engine-reference/godot/`). Verification 1; fallback in Decision 6.
- NOT SOURCEABLE: typed-array invariance (`Array[Enemy]` not assignable to `Array[Targetable]`) is taken from architecture.md B7, not from the engine reference. Verification 2.
- NOT SOURCEABLE: `is_finite()` on 4.7.2 returns false for NaN and both infinities (not covered by the reference). Verification 3.
- NOT SOURCEABLE: a direct-connected signal's handlers run before `emit` returns (not covered by the reference; ADR-0006 verifies). Verification 4.
- NOT SOURCEABLE: the cost of about 400 range checks per tick on an Adreno 5xx-class phone. Verification 5.

## Related
- `design/gdd/combat-damage.md`, `design/gdd/enemy-wave.md`, `design/gdd/tower-system.md`, `design/gdd/hero-system.md`
- ADR-0001, ADR-0002, ADR-0004, ADR-0005; `docs/architecture/architecture.md` B0, B6, B7, B9, QQ-07, QQ-08, QQ-11
