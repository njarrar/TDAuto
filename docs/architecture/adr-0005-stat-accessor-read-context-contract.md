# ADR-0005: Stat Accessor and Read-Context Contract

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.
> Acceptance preconditions: ADR-0001 and ADR-0002 are Accepted.
>
> Phone checks (user instruction, 2026-11-04): phone testing is set aside for
> now, and the future device is an iPhone. The one device item, the per-tick
> read cost (Verification Required 2), is after acceptance, on the iPhone. A
> phone result that contradicts this ADR reopens it before the next story in
> its area closes. This ADR has no open before-acceptance item except ADR-0001
> and ADR-0002 being Accepted.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference. This decision uses no engine API beyond plain GDScript classes, `StringName` and `Dictionary`, so nothing in it needs the live documentation; the one version-specific rule it relies on (4.7 typed-return overrides) is in `breaking-changes.md`.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS on the first draft, findings 1 to 3 blocking and 4 to 12 advisory, all applied here), godot-specialist (engine check: two blocking notes, the context cycle and the spy constructor, applied). Authored with the `/architecture-decision` flow in autonomous mode; choices logged in `production/session-logs/decision-log.md`.

## Summary

Every value a modifier could ever touch must be read through one accessor at use time, so the Vertical Slice stat resolver can replace its internals with no call-site change, and a bad read must reach the battle's fatal path without a session-lived object holding a per-battle callable. This ADR decides a per-battle `StatAccessor` built by the Builder with the session catalogue and the battle's `fatal`, two typed reads `stat_int(ctx, key)` and `stat_float(ctx, key)` over a closed `StatKeys` vocabulary of `StringName` constants, one reused `ReadContext` per caller held by the owning system (never by the entity it names, so no reference cycle forms), the full list of bad calls, and non-fatal `is_tower` and `level_count` lookups to call first.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW (no engine API; plain GDScript objects and dictionaries) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.7 GDScript rows), `current-best-practices.md` (GDScript section) |
| **Post-Cutoff APIs Used** | None. One 4.7 language rule applies: an override of a typed-return method inherits the type and needs an explicit `return` (`breaking-changes.md`, 4.6 to 4.7, GDScript). It affects every test spy that subclasses `StatAccessor`. |
| **Verification Required** | (1) Confirm on the installed 4.7.2 editor that a spy override of `stat_int(...) -> int` with a typed `return` on every path parses, and that omitting a `return` on a path is an error (the 4.7 rule is one line in `breaking-changes.md`; its exact scope is not sourced). Method: the first `SpyStatAccessor` story. (2) Per-tick read cost against the proposed ceiling in Performance, on the first device build (QQ-11); after acceptance, on the iPhone. (3) Inherited: ADR-0001 V1 (a method Callable such as `relay.fatal` holds an object ID, not a strong reference). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Builder, injected `fatal`, `halted()`, session-lifetime rule), ADR-0002 (record classes, `Catalogue` lookups, `StringName` IDs) |
| **Enables** | ADR-0009 (enemy stat reads, per-enemy context), ADR-0010 (Tower and Hero commands read costs and stats), Battle HUD stories (cost previews) |
| **Blocks** | Every story that reads a tower, enemy, hero or burst stat (Enemy & Wave, Tower, Hero, Battle HUD) |
| **Ordering Note** | ADR-0001 left open how the accessor reaches the per-battle `fatal` ("a per-battle read context, or per call"). This ADR picks a third form, a per-battle accessor, and amends ADR-0001, `architecture.md` and the registry in the same change (Migration Plan lists each edit). Validation 6 depends softly on ADR-0007's lint; until that lint exists the rule is checked in code review. Vertical Slice's Stat & Modifier GDD replaces the accessor's internals under this contract; it may add keys and record rows, never change the two read signatures. |

## Context

### Problem Statement

The Data & Config GDD (Rule 10) makes one accessor the only path for any number a modifier could target, read at use time and never cached, so that skill-tree and synergy modifiers at Vertical Slice drop in with no call-site change. Four GDDs read through it (Enemy & Wave, Tower, Hero, Battle HUD), each with a reused read context, a spy accessor in its tests and a `halted()` check after every read. The signature, the key format, the context shape, what counts as a bad call, what a bad call returns, and how the accessor reaches the battle's fatal handler all have to be fixed before any of those systems' first story. ADR-0001 also handed this ADR one open point: the catalogue is session-lived, the fatal handler is per battle, and nothing session-lived may hold a per-battle callable.

### Current State

No code exists. `architecture.md` B1 proposes `stat_int(ctx, key) -> int` and `stat_float(ctx, key) -> float` plus `is_tower` and `level_count` (two typed methods replaced version 1's `Variant` return, TD-ARCHITECTURE A9), and B0 proposes `ReadContext {def_id, level = 0, live_entity = null}`, one reused per caller. ADR-0002 fixed the record classes (`TowerRecord` with `Array[TowerLevel]`, `EnemyRecord`, `HeroRecord`, `BurstRecord`) and `StringName` IDs.

### Constraints

- GDScript cannot return "a number or nothing" from a typed method; the value after a bad call is unspecified and no caller may use it (GDD Rule 10).
- No exceptions: after a bad call, the caller checks `halted()` and returns (ADR-0001).
- The check must survive release builds: no `assert` (ADR-0001 Decision 4).
- No session-lived object holds a per-battle callable (ADR-0001 session-lifetime rule).
- A tick must allocate nothing per read (B0: contexts are reused).
- Stage, Wave groups and the Input record are read directly, not through the accessor (GDD Rule 10).

### Requirements

- One accessor, `(read_context, stat_key)`, read at use time, never cached (TR-data-008); the one exception is `max_hp` seeding Health once at spawn.
- Data owns the key vocabulary and each key's int or float type, and exposes non-fatal `level_count(def_id)` and `is_tower(id)` (TR-data-010).
- Each enemy reads through a reused per-enemy context; Wave and Stage records are read directly and never written (TR-enemy-006).
- Tower IDs and levels are checked with `is_tower` and `level_count` before any read; cost and stats are read at use time (TR-tower-003).
- Hero and Burst stats through the accessor; `hero_start`, `pin_rect`, `pin_exclusion` straight from the Stage record (TR-hero-005).
- HUD costs read on arc open and on `gold_changed`; a read that finds `halted()` is abandoned for the Fatal screen (TR-hud-011).

## Decision

### 1. One accessor per battle

`StatAccessor` (`src/foundation/data/stat_accessor.gd`, `extends RefCounted`) is created by `BattleBuilder.build` in ADR-0001's step 1, right after the `FatalLatch` and `FatalRelay` and before any sim, with two constructor arguments: the session `Catalogue` and the battle's `fatal` (the `FatalRelay.fatal` method Callable). The Battle owns it and exposes it as the read-only member `stat_accessor` (added to `architecture.md` B0's `Battle` row); every system that reads stats receives the same instance as a constructor argument. `_init` checks `fatal.is_valid()` and calls `push_error` if it is not, since then a bad call would have nowhere to go.

This answers ADR-0001's open point. The accessor is per battle, so it may hold the per-battle `fatal`; it holds the session catalogue, which is allowed (per-battle objects may reference session objects, never the reverse). The catalogue stays free of callables. When the battle is dropped on retry, the accessor goes with it; the new battle gets a new accessor over the same catalogue.

The HUD's cost previews use the battle's accessor too: the wrapper reads `battle.stat_accessor` in `attach()` and passes it to the HUD. The HUD's accessor reference and its preview contexts are among the references `detach()` must clear (ADR-0001 Decision 6). Nothing reads stats outside a battle at MVP (Boot reads only the catalogue's stage list, ADR-0002).

### 2. Two typed reads

```gdscript
## Returns the value of an int key for this context. A bad call (see Decision 5)
## calls the injected fatal once, names the cause, and returns 0. The caller must
## check halted() before using the result.
func stat_int(ctx: ReadContext, key: StringName) -> int

## Same, for a float key. Returns 0.0 after a bad call.
func stat_float(ctx: ReadContext, key: StringName) -> float
```

A key's declared type must match the method: `stat_int` on a float key, or `stat_float` on an int key, is a bad call. Two methods keep static typing at every call site, so `var cost: int = accessor.stat_int(ctx, StatKeys.COST)` needs no cast and the parser checks it. At MVP each read returns the base value from the catalogue for that context. At Vertical Slice, Stat & Modifier Resolution changes only what happens inside these two methods.

### 3. Key vocabulary: StatKeys

`StatKeys` (`src/foundation/data/stat_keys.gd`) is owned by Data & Config (TR-data-010). It declares one `StringName` constant per key and one table giving, for each key, its type and the record types it applies to, plus the role tag it needs on towers:

| Key | Type | Applies to | Role tag needed |
|---|---|---|---|
| `COST` | int | tower | none |
| `DAMAGE` | float | tower, hero, burst | none |
| `RANGE` | float | tower | none |
| `ATTACK_INTERVAL` | float | tower, hero | none |
| `SPLASH_RADIUS` | float | tower | `splash` |
| `SLOW_STRENGTH` | float | tower | `slow` |
| `SLOW_DURATION` | float | tower | `slow` |
| `BOUNTY` | int | enemy | none |
| `LIVES_COST` | int | enemy | none |
| `MAX_HP` | float | enemy | none |
| `MOVE_SPEED` | float | enemy | none |
| `LEASH_RADIUS` | float | hero | none |
| `WALK_SPEED` | float | hero | none |
| `RADIUS` | float | burst | none |
| `REACH` | float | burst | none |
| `COOLDOWN` | float | burst | none |
| `TELEGRAPH_DURATION` | float | burst | none |

The table is the GDD's MVP stat-key table restated as code; adding a key is a GDD change first. Constant values equal the record field names (`const DAMAGE := &"damage"`), so the base read is a field lookup by the same name.

Callers must pass a `StatKeys` constant, never a string literal. `StatKeys.DAMAGE`, referenced through the `class_name`, is resolved at parse time, so a misspelt constant is a parse error; a misspelt literal would be a run-time bad call. The parse-time check does not hold through an untyped variable or a script loaded with `load()`, which is one more reason the key is always written as `StatKeys.X`.

The table is a `const` Dictionary in `stat_keys.gd`, never a `static var` (ADR-0001 bans mutable static state). From Vertical Slice, modifier stat keys are validated against this same table (GDD Rule 11).

Stage has no row: its fields are structural and read directly. Wave groups and the Input record are also read directly.

### 4. ReadContext

```gdscript
class_name ReadContext extends RefCounted
var def_id: StringName           # the record's ID
var level: int = 0               # towers: 1 to level_count(def_id); every other record: 0
var live_entity: Object = null   # the live enemy, tower or hero when one exists; null for a preview
```

- One context per caller, made once and reused for every read. **A context is created only when its owner comes into being, never per read:** one per enemy (created when the enemy spawns, which happens inside a tick), one per tower slot (created when the tower is built, its `level` updated on upgrade), one for the hero and one for the burst (created at battle build), and one per HUD preview (created when the HUD is attached). A read never allocates a context.
- **The owning system holds the contexts, not the entity they name.** EnemyWave keeps each enemy's context keyed by `spawn_id` and drops it when the enemy leaves the roster; TowerSim keeps one per slot; HeroSim keeps the hero's and the burst's. An entity (`Enemy`, a tower, the hero) never stores its own `ReadContext`. The context's `live_entity` points at the entity, so if the entity also held the context, the two `RefCounted` objects would form a cycle that GDScript never frees (ADR-0001 forbids cycles; the registry's `sim_back_reference_to_battle` covers it). This changes `architecture.md` B0's `Enemy` row, which listed "its `ReadContext`"; ADR-0009 inherits the change.
- The caller owns its context and may change `level` (upgrade) or `def_id` (a HUD preview switching towers). The accessor never writes to a context and never stores one.
- `live_entity` is unused at MVP; it exists so the first instance-dependent modifier ("towers near the hero") needs no call-site change (GDD Rule 10). It is typed `Object` so Data does not depend on Core or Feature classes. It is a strong reference, so it must only ever be held by a context that the entity's owner holds (above). A context must not be stored by any session-lived object, since `live_entity` points into the battle.
- Constructor helper: `ReadContext.make(def_id: StringName, level: int = 0, live_entity: Object = null) -> ReadContext`.

### 5. Bad calls

Each of these calls `fatal(cause)` once, with a cause naming the method, the key, `def_id` and level, then returns `0` or `0.0`:

1. `key` is not in `StatKeys`.
2. `key`'s type does not match the method (`stat_int` on a float key, or the reverse).
3. `ctx` is null, or `ctx.def_id` does not resolve to a record.
4. The record's type is not one the key applies to (`BOUNTY` on a tower).
5. A role key on a tower without that role's tag (`SPLASH_RADIUS` on a `slow` tower).
6. A tower context with `level` outside 1 to `level_count(def_id)` (including 0).
7. A non-tower context with `level` other than 0.

The order above is the check order, so one bad call reports its first cause only. The cause string is built only on this path, so a good read allocates nothing.

A bad call always calls `fatal`, whatever the battle's phase. If the battle is already FATAL, `fatal` is idempotent and keeps the first cause (ADR-0001). If it is WON or LOST (for example a HUD read on the result screen), the bad call still latches FATAL and the fatal screen replaces the result: this is intended, since a bad read is a data or code defect that must not pass silently.

The value returned after a bad call is not part of the contract. Tests never assert it (GDD Acceptance 7). Callers never use it: every read is followed by a `halted()` check before the value is used (TR-enemy-005, TR-tower-006).

### 6. Non-fatal lookups, called first

```gdscript
func is_tower(id: StringName) -> bool        # true if id names a TowerRecord
func level_count(def_id: StringName) -> int  # number of levels; 0 if def_id is not a tower
```

These never call `fatal`. A command or a bot that holds an untrusted ID or level calls them first and returns a refusal (for example `BAD_TOWER`, `MAX_LEVEL`; ADR-0010 owns the codes) rather than reaching the handler (TR-tower-003). They delegate to the catalogue (ADR-0002 Decision 6).

### 7. Read at use time; read before mutate

- **Never cache.** A system reads a stat at the moment it uses it, every time (TR-data-008). A tower reads `ATTACK_INTERVAL` when it resets its cooldown, `RANGE` when it targets, `DAMAGE` when it fires; an enemy reads `MOVE_SPEED` each tick it moves; Tower reads `COST` inside `build` and `upgrade`; the HUD reads costs on arc open and on each `gold_changed` while open (TR-hud-011), range rings (`RANGE` by `def_id` and level) when it shows them, and the Burst's `COOLDOWN` every frame for the cooldown wedge, through its burst context made from the Burst ID the Builder injects (Battle HUD Rule 12 and read table). The HUD's reads run from the frame, not the tick; they follow the same rules.
- **One exception.** `MAX_HP` is read once at spawn to seed Health (Data & Config Interactions; Combat). No other stat is stored.
- **Read before mutate.** A command or step that needs several stats reads all of them, and checks `halted()`, before it changes any state, so a bad read halts with nothing half done (TR-tower-006, Tower Rule 5).
- **Check after every read.** `halted()` is checked after every read and before the value is used. A HUD read that finds `halted()` true abandons the refresh; the Fatal screen follows (TR-hud-011).
- **Proof.** Each consumer story has the GDD's spy test: a spy accessor changes its value between two uses, and the second use reflects it (Data & Config deferred criteria).

### 8. Direct reads are given, not looked up

Structural data is not read through the accessor (GDD Rule 10). The Builder looks up the records a system reads directly and passes them in at construction: the `StageRecord` to Flow, EnemyWave, TowerSim and HeroSim; the stage's `WaveRecord`s to EnemyWave; the `InputRecord` to the resolver and HeroSim, and it sets the read-only `Battle.input_record`, `Battle.stage_record` and `Battle.visual_keys` (ADR-0011), from which the BattleWrapper gives it to the wrapper-built HeroInput, HUD and InputAdapter (ADR-0003 Decision 1; ADR-0001 B9 `left_handed`). Sims never hold the `Catalogue`; they hold the accessor and the specific records they were given. Records are read-only (ADR-0002); no system writes to them (TR-enemy-006).

### 9. Test spies

Tests replace the accessor with a subclass, `SpyStatAccessor extends StatAccessor` in `tests/helpers/`, which logs each read, can return a scripted value per `(def_id, level, key)`, and can call `fatal` on a chosen read. Its `_init(catalogue: Catalogue, fatal: Callable)` forwards both arguments with `super(catalogue, fatal)`; the base `_init` has no defaults, so a spy that omits the call fails. Overrides keep the full signatures (`-> int`, `-> float`) and return a value of that type on every path; `return null` is not valid for `-> int` (4.7 typed-return rule). The spy is passed to the system under test exactly as the real accessor is, through its constructor.

### Architecture Diagram

```
 AppRoot (session) ── Catalogue (READY; no callables)
                           │
                BattleBuilder.build(catalogue, stage_id, rng_seed, on_fatal)
                           │  creates first: FatalLatch, FatalRelay, StatAccessor(catalogue, relay.fatal)
                           ▼
   Battle ── owns StatAccessor (member stat_accessor) ┬──────────────┬─────────────┬──────────────┐
                                            ▼              ▼             ▼              ▼
                                      EnemyWave       TowerSim       HeroSim     wrapper: HUD
                                      ctxs by spawn_id ctx per slot  hero + burst  ctx per preview
                                      (enemy never holds its ctx; ctx.live_entity ─► enemy, one way)
                                            │              │             │              │
              stat_int / stat_float(ctx, StatKeys.X) ──► base value (MVP) or resolved value (VS)
                                            │
                   bad call ─► relay.fatal(cause) ─► latches; caller checks halted() and returns

   Direct reads (no accessor): Builder passes StageRecord, WaveRecord[], InputRecord at construction
   Pre-checks (non-fatal): is_tower(id), level_count(def_id)
```

### Key Interfaces

```gdscript
# src/foundation/data/stat_accessor.gd
class_name StatAccessor extends RefCounted
func _init(catalogue: Catalogue, fatal: Callable) -> void
func stat_int(ctx: ReadContext, key: StringName) -> int
func stat_float(ctx: ReadContext, key: StringName) -> float
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int

# src/foundation/data/read_context.gd
class_name ReadContext extends RefCounted
var def_id: StringName
var level: int = 0
var live_entity: Object = null
static func make(def_id: StringName, level: int = 0, live_entity: Object = null) -> ReadContext

# src/foundation/data/stat_keys.gd
class_name StatKeys extends RefCounted     # constants and a const Dictionary table only; never instantiated
const COST := &"cost"
const DAMAGE := &"damage"
# ... one constant per row of the Decision 3 table
static func is_key(key: StringName) -> bool
static func is_int(key: StringName) -> bool
static func applies_to(key: StringName, record_type: StringName) -> bool
static func role_tag(key: StringName) -> StringName   # &"" if none
```

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must read every value in the Decision 3 table through `stat_int` or `stat_float`, at the moment of use.
- Must never store a value read from the accessor, except `MAX_HP` when seeding Health at spawn.
- Must pass `StatKeys` constants; must never pass a string or `StringName` literal as a key.
- Must check `halted()` after every read and before using the value; must never use the value returned by a bad call.
- Must read every stat a command or step needs before changing any state.
- Must call `is_tower` and `level_count` before reading with an ID or level that is not already trusted.
- Must create one `ReadContext` per caller, only when its owner is created, and reuse it; must never create a context per read.
- The owning system must hold the contexts; an entity must never store its own `ReadContext`.
- Must drop an entity's context when the entity leaves its owner (reap, leak, retry).
- Must never store a `ReadContext` in a session-lived object.
- Must never read Stage, Wave groups or the Input record through the accessor; must never hold the `Catalogue` in a sim (use the records the Builder passes in).
- Must never write to a record.
- Must take the accessor as a constructor argument; must never build a second accessor inside a battle.
- Test spies must subclass `StatAccessor`, forward `_init(catalogue, fatal)` with `super(...)`, keep the typed signatures and return a typed value on every path.
- Must declare the `StatKeys` table as `const`, never `static var`.
- Slow, and any other per-instance countdown state, must never go through the accessor (Combat Rule 8).

## Alternatives Considered

### Alternative 1: One `stat(ctx, key) -> Variant` method

- **Description**: A single read returning `Variant`, as in architecture version 1.
- **Pros**: One method; no type mismatch case.
- **Cons**: Every call site needs a cast, and a wrong cast is a silent conversion or a run-time error; static typing is lost on every stat in the game.
- **Estimated Effort**: About 1x.
- **Rejection Reason**: TD-ARCHITECTURE A9; two typed methods keep the parser on our side.

### Alternative 2: Per-stat getters (`tower_damage(id, level)`, `enemy_speed(id)`)

- **Description**: One method per key.
- **Pros**: Fully typed; no key argument to misspell.
- **Cons**: Seventeen methods now, more at Vertical Slice; a modifier layer must wrap every one; no single place to add a key; no context to carry the live entity.
- **Estimated Effort**: About 1.3x now, growing.
- **Rejection Reason**: Breaks the "one accessor, no call-site change" goal (TR-data-008).

### Alternative 3: Callers read record fields directly; add the accessor at Vertical Slice

- **Description**: MVP reads `tower.levels[n].damage`; the accessor arrives with modifiers.
- **Pros**: Least code now.
- **Cons**: Every call site changes at Vertical Slice, which is exactly what the GDD forbids; caching habits form in the meantime.
- **Estimated Effort**: About 0.5x now, 2x later.
- **Rejection Reason**: GDD Rule 10 and TR-data-008.

### Alternative 4: Session-lived accessor with `fatal` per call or in each context

- **Description**: One accessor for the session; each read passes the handler, or each `ReadContext` carries it.
- **Pros**: The accessor never needs rebuilding.
- **Cons**: Per call: every read site passes an extra argument for the rare failure case. In the context: a callable stored in many objects, one of which could outlive its battle.
- **Estimated Effort**: About 1x.
- **Rejection Reason**: A per-battle accessor is simpler, and costs nothing because it holds no state of its own.

### Alternative 5: Cache stats at spawn or build, refresh on change

- **Description**: Read once, store on the entity, refresh when a modifier changes.
- **Pros**: Fewer reads per tick.
- **Cons**: Needs change notification from every future modifier source; a missed refresh is a silent balance bug; the spy test would fail by design.
- **Estimated Effort**: About 1.5x at Vertical Slice.
- **Rejection Reason**: GDD Rule 10 forbids it; read cost is small (see Performance).

## Consequences

### Positive

- One seam for all modifiable values; Vertical Slice changes the accessor's internals only.
- Typed reads and constant keys: most mistakes are parse errors, and the rest are named bad calls.
- The fatal route obeys ADR-0001 with no callable on any session object.
- Spies make "read at use time" a tested property per consumer.
- Sims depend on the accessor and on the records they need, not on the whole catalogue.

### Negative

- Every stat use is a call with a context and a key, and a `halted()` check after it: more lines than a field read.
- `StatKeys` restates the GDD's stat-key table, a third copy beside the schema (ADR-0002) and the GDD. A test checks that every `StatKeys` key exists as a field on each record type it applies to, and that its type matches the schema.
- Reads per tick are more than a cache would need; acceptable at MVP size, measured on device.

### Neutral

- The accessor is rebuilt with each battle; it holds no state, so this costs one small object.
- `live_entity` is carried and ignored at MVP.

## Risks

- **Per-tick read cost exceeds the budget.** Mitigation: internals may be optimised freely; internals may precompute a flat table per `(def_id, level)` at construction with no contract change. Measured with ADR-0004's frame budget on the first device build.
- **A caller caches anyway.** Mitigation: each consumer's spy test (GDD deferred criteria) and code review; the control manifest lists it as Forbidden.
- **A context cycle slips in** (an entity given its own context). Mitigation: the ownership rule, and Validation 7 (weakrefs to reaped enemies and to the old battle read null).
- **Inherited from ADR-0001 V1.** The accessor holds `relay.fatal` as a method Callable; if V1 shows method Callables hold a strong reference, the accessor and relay join the Builder's wiring in ADR-0001's rollback (`Battle.dispose()` clears held Callables).
- **A caller uses a value after a bad call.** Mitigation: the `halted()` rule, and Tower and Hero acceptance tests with a spy that calls `fatal` mid-command (Tower Edge Cases, Hero Edge Cases).
- **`StatKeys` drifts from the schema.** Mitigation: the consistency test in Consequences.
- **Vertical Slice needs a key per stage value ("+50 starting gold").** Mitigation: the Stat GDD adds a Stage row then; the contract allows new rows.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-008: every modifiable value read through one accessor `(read_context, stat_key)` at use time, never cached, replaceable internals | Decision 1, 2, 7 |
| data-config-pipeline.md | TR-data-010: Data owns the key vocabulary and int or float type per key; non-fatal `level_count` and `is_tower` | Decision 3, 6 |
| enemy-wave.md | TR-enemy-006: enemy stats through the accessor at use time with a reused per-enemy context; Wave and Stage read directly, never written | Decision 4, 7, 8 |
| tower-system.md | TR-tower-003: IDs and levels checked with `is_tower` and `level_count` before any read; cost and stats read at use time | Decision 5 (bad calls 4 to 6), 6, 7 |
| hero-system.md | TR-hero-005: Hero and Burst stats through the accessor; `hero_start`, `pin_rect`, `pin_exclusion` from the Stage record | Decision 3 (hero, burst rows), 8 |
| battle-hud.md | TR-hud-011: costs read on arc open and `gold_changed`; a read that finds `halted()` is abandoned | Decision 1 (HUD uses the battle's accessor), 4 (preview context), 7 |

## Performance Implications

- **CPU**: The MVP read path is a method call, then about four `StatKeys` table lookups (exists, type, applies-to, role tag), a record lookup by `def_id`, a record-type check, a search of the tower's tags for a role key, a level-range check, and a field read by `StringName`. All are hash lookups or short scans; a good read allocates nothing. A wave of about 40 enemies and 10 towers does on the order of 100 reads per tick, plus a few HUD reads per frame. **Proposed ceiling: all stat reads in one tick take at most 0.5 ms on the Adreno 5xx-class device** (Android-only: deferred until an Android device is available; iPhone run covers the iOS equivalent where one exists: the same measure on the iPhone), measured with ADR-0004's budget split on the first device build (QQ-11). If it is missed, the accessor precomputes a flat table per `(def_id, level)` at construction.
- **Memory**: One accessor per battle and one small context per enemy, tower slot, hero, burst and HUD preview.
- **Load Time**: None; the accessor is built in `build`.
- **Network**: None.

## Migration Plan

No code exists. First stories, in order: `StatKeys` with the consistency test against the ADR-0002 schema; `ReadContext`; `StatAccessor` with the GDD's Acceptance 6 and 7 on code-built fixtures; `SpyStatAccessor` in `tests/helpers/`. The Builder creates the accessor in its step 2 (ADR-0001). Consumer stories adopt it as they are written.

Same change as this ADR:

- ADR-0001 Decision 5, session-lifetime bullet, and its Implementation Guidelines: remove "the stat accessor" from the session-lived lists, and name the per-battle accessor as the chosen route.
- ADR-0001 Decision 5, step 1: also create `StatAccessor(catalogue, relay.fatal)`. ADR-0001 Ordering Note: the open point is closed by ADR-0005.
- `architecture.md` Data Flow 4, step 5a: the same addition. B0: add `stat_accessor: StatAccessor` to `Battle`'s members; remove "its `ReadContext`" from `Enemy`.
- Registry: `session_object_holds_battle_callable` is superseded by a reworded entry without the accessor.

**Rollback plan**: If per-tick cost is too high, precompute per-`(def_id, level)` tables inside the accessor; the contract does not change. If a session-lived reader ever needs stats (a stage-select preview at Vertical Slice), give it its own accessor with a handler that reports to AppRoot; the contract does not change.

## Validation Criteria

Automated, headless (gdUnit4 under `tests/unit/data/`):

1. GDD Acceptance 6: every applicable key on each record (towers per level, role keys only with the tag) returns the base value of the declared type, with a live entity and with a preview context; `level_count` matches each tower's record.
2. GDD Acceptance 7: a spy `fatal` fires once, naming the cause, for each of bad calls 1 to 7; the return value is not asserted.
3. `is_tower` and `level_count` never call `fatal`, for any input including unknown IDs and non-tower IDs.
4. Consistency: every `StatKeys` key is a field on each record type it applies to, with the matching type in the ADR-0002 schema; every GDD stat-key row has a constant.
5. No allocation per read: N reads on existing contexts leave `Performance.get_monitor(Performance.OBJECT_COUNT)` unchanged (no mutable static counter, which is banned).
6. Lint (ADR-0007 STAT-1; code review until it exists): no string or `StringName` literal passed as the key argument of `stat_int` or `stat_float` under `src/`.
7. No cycle: in a fixture battle, weakrefs to an enemy and to its context read null once the enemy is reaped and the owner has dropped the context; the ADR-0001 retry weakref test passes with contexts in use.
8. GDD Acceptance 8: two code-built fixtures with different values, each behind its own accessor, return their own values side by side with no file I/O.
9. GDD Acceptance 12: a bad call invokes the injected handler and the catalogue stays `READY` (its snapshot is unchanged).
10. A bad call after WON latches FATAL (spy `fatal` fires).

Per consumer story (Enemy & Wave, Tower, Hero, Battle HUD): the spy never-cache test, and a mid-command `fatal` test showing nothing half done.

The decision is wrong if: a Vertical Slice modifier needs a call-site change, or a consumer cannot meet its tick budget without caching.

## Related

- Depends on ADR-0001 (Builder, `fatal`, `halted()`, session-lifetime rule, amended here) and ADR-0002 (records, catalogue lookups).
- Enables ADR-0009, ADR-0010; Battle HUD stories.
- `docs/architecture/architecture.md`: B0 (`ReadContext`), B1 (accessor; adopted as proposed), B9, Data Flow 4, QQ-11.
- `design/gdd/data-config-pipeline.md` Rules 10 to 12, Acceptance 6 to 8, deferred criteria; `enemy-wave.md` Rules 9 to 13; `tower-system.md` Rules 5, 9; `hero-system.md` Interactions; `battle-hud.md` Rule 7 and the read table; `combat-damage.md` Rules 8, 9.
- `docs/architecture/tr-registry.yaml` (the 6 TR IDs above).
