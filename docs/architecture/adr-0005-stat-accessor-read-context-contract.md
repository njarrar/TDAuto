# ADR-0005: Stat Accessor and Read-Context Contract

## Status
Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. Reviews are still owed (see Reviews).

## Date
2026-11-04

## Last Verified
2026-11-04 (against `docs/engine-reference/godot/` for Godot 4.7.2, `architecture.md` v4, ADR-0001, ADR-0002 and ADR-0004 as Accepted, `tr-registry.yaml` and `docs/registry/architecture.yaml`)

## Decision Makers
- Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`, 2026-11-04)
- godot-specialist: not run. TD-ADR: not run. Both are owed before acceptance.
- Acceptance: the user.

## Summary
Every number a modifier could change (tower, enemy, hero and burst stats) must reach its caller through one per-battle accessor, read at use time, so the Vertical Slice stat resolver can drop in with no call-site change. This ADR fixes that accessor: two typed reads, `stat_int` and `stat_float`, over a caller-owned and reused `ReadContext`, keys as `StringName` constants in one `StatKeys` file checked against the schema, six named bad-call causes sent to the battle latch's `fatal`, two non-fatal lookups, and reserved modifier grant tags.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core (scripting, data access) |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW. architecture.md rates this ADR LOW. Every API used dates from 4.0, and `breaking-changes.md` lists no 4.4 to 4.7 change to them. The one 4.7 Core row (`Object.is_class()` takes a `StringName`) does not touch this design. The 4.7 typed-override rule applies to the spy subclass. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.7 Core and GDScript rows), `deprecated-apis.md` (untyped `Array`/`Dictionary` pattern row), `current-best-practices.md` (GDScript 4.5 and 4.7), `modules/input.md` (StringName in hot paths, Common Mistakes). No `modules/` file covers scripting or data. `architecture.md` v4 (Seams, Module Ownership, B0, B1, B1a, B9, B10, Required ADRs); `tr-registry.yaml`; ADR-0001, ADR-0002, ADR-0004 |
| **Post-Cutoff APIs Used** | None. Used: `StringName` and `&"..."` literals, `const` `Dictionary` literals, `Object.get(StringName)`, `weakref()` and `WeakRef.get_ref()`, `RefCounted`, `Array.has()`, `Performance.get_monitor()` (tests only). Typed `Dictionary[K, V]` (added in 4.4) is **not** used. |
| **Verification Required** | None of these is in the pinned reference; all are from memory and none can be checked offline. Each has a named test under Validation Criteria. (E1) `const K := &"x"` and a `const` Dictionary keyed by such constants parse in 4.7.2, and the const Dictionary is read-only at run time. (E2) A Dictionary keyed by `StringName` does or does not hit on a `String` key of the same text; the lint holds either way. (E3) `Object.get()` with a `StringName` returns a script `var`'s value and `null` for an unknown name, with no error. (E4) `WeakRef.get_ref()` returns `null` once the last strong reference to a `RefCounted` drops. (E5) Passing a `String` literal where a `StringName` parameter is expected converts on every call and costs more than a `&"..."` constant. (E6) A read on a `StringName` key creates no `Object` (`Performance.OBJECT_COUNT` is flat). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): one accessor per battle built by the Builder over the shared Catalogue with the battle latch's `fatal`, held privately by `Battle`; callers check `halted()` after every read. ADR-0002 (Accepted): `RefCounted` records with `StringName` IDs; typed lookups that return null and call no handler; `type_of()`; `schema.gd`; `is_tower` and `level_count` move here. ADR-0004 (Accepted): reads happen inside ticks or in a command before any mutation; `TickMath.to_ticks` turns read seconds into ticks. |
| **Enables** | ADR-0007 (hosts lints L-STAT-1 to L-STAT-3 and the spy accessor helper), ADR-0009 (Enemy holds its `ReadContext`; `max_hp` seeds Health), ADR-0010 (`BAD_TOWER`, `MAX_LEVEL` and `HALTED` refusals rest on the non-fatal lookups and the cost read), the Vertical Slice Stat & Modifier GDD and resolver |
| **Blocks** | The Data & Config accessor story and every Enemy & Wave, Tower, Hero and HUD story that reads a stat. No epic or story exists yet, so none is blocked by path today. |
| **Ordering Note** | Write after ADR-0002 and ADR-0004, before ADR-0009 and ADR-0010. The perf check P1 runs on desktop with the first accessor story; its device figure waits for the first phone build. |

## Context

### Problem Statement
Four MVP systems read authored stats in the hot path: every enemy reads `move_speed` every tick, every tower reads `range` and then its attack stats, and the hero and burst read theirs. The HUD reads costs and the burst `cooldown` for its wedge. The Data GDD (Rules 10 and 11) asks that all of these go through one accessor that takes a read context and a stat key, at use time, so that a Vertical Slice modifier ("towers near the hero deal more damage") changes the value with no change at any call site. architecture.md v4 sketches the accessor (B1) and the context (B0) but leaves open: the typed split and what a wrong-type call does, how contexts are reused so a tick allocates nothing, where the key vocabulary lives and in what form, how the HUD reaches the accessor, and which modifier tags are reserved. Every consumer story needs these answers before its first read.

### Current State
No code. `src/` holds only a `CLAUDE.md`. ADR-0001 fixes the accessor's owner and handler; ADR-0002 fixes the records it reads.

### Constraints
- **ADR-0001**: one `StatAccessor` per battle, made by the Builder in step (b) over the shared read-only `Catalogue`, with the battle latch's `fatal` as its handler, held as `Battle._stat_accessor`. Every object behind an injected Callable or reference is a member of `Battle` or `AppRoot`. No sim object holds `Battle`, `AppRoot` or a `Node`. No `assert` for release checks. Callers check `halted()` after every read (Guideline 9).
- **ADR-0002**: records are `RefCounted` with typed fields; IDs are `StringName`, made once at load; lookups return null on an unknown ID and never call a handler. The Catalogue holds no battle reference. `schema.gd` is the one field table.
- **ADR-0004**: stat reads run inside a tick, or in a command before any change, or in a view refresh step that changes nothing. Durations read here are seconds; callers pass them through `to_ticks`. No engine time in sim code.
- **Data GDD**: no fallbacks in any build (Rule 8); never cache, except `max_hp` when seeding Health; Stage and Wave fields are read directly, not through the accessor; a level on a non-tower is a bad call; the value after a bad call is unusable.
- **Performance**: one tick at most 2.0 ms p95 on an Adreno 5xx-class phone (ADR-0004, unmeasured). Reads are the most frequent call in the sim.
- **Team**: solo part-time developer; one small file per concept, no code generation.

### Requirements
TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005 and TR-hud-011, quoted in GDD Requirements Addressed. TR-data-009 (the handler survives release builds) is ADR-0001's; this ADR uses it.

## Decision

### 1. Two typed reads; a wrong-type call is a bad call
- `stat_int(ctx, key) -> int` and `stat_float(ctx, key) -> float`. There is no `Variant` read (TD-ARCHITECTURE A9). Each key has one declared kind (Decision 3). At MVP the int keys are `cost`, `bounty` and `lives_cost`; all others are float.
- Calling `stat_int` on a float key, or `stat_float` on an int key, is a bad call with cause `stat_type_mismatch`. It is never coerced: a silent `int()` on `damage` would floor a balance value, which Data Rule 8 forbids.
- After any bad call the read returns `0` or `0.0`. This is a defined value so the function has a typed return, not a value a caller may use. The caller must check `halted()` and return at once (ADR-0001 Guideline 9). Tests never assert it.

### 2. Bad calls: six causes, checked in a fixed order
A read checks, in this order, and stops at the first failure:

| # | Cause code | When |
|---|---|---|
| 1 | `stat_null_context` | `ctx` is null |
| 2 | `stat_unresolved_def` | `type_of(ctx.def_id)` is not `tower`, `enemy`, `hero` or `burst` (unknown ID, or a Stage, Wave or Input ID, which have no stat row) |
| 3 | `stat_unknown_key` | `key` is not in the vocabulary for any type |
| 4 | `stat_inapplicable_key` | `key` is not in that type's row, or is a role key on a tower without that role's tag (`splash_radius` on a `slow` tower) |
| 5 | `stat_type_mismatch` | the key's kind differs from the method called |
| 6 | `stat_bad_level` | a tower with `level` outside `1..levels.size()`, or a non-tower with `level != 0` |

- The accessor calls its handler once per bad call with the cause string `"<code> def=<def_id> key=<key> level=<level>"`. The string is built only on the failure path. Spy tests compare the first token only.
- The handler is the battle latch's `fatal`. The latch keeps the first cause, forwards once and emits `latched`, so Flow enters `FATAL` at once and `halted()` turns true (ADR-0001 Decision 6). A second bad read in the same tick reaches an already set latch and changes nothing.
- The checks are plain `if` branches. `assert` must not appear in the accessor (ADR-0001 Guideline 10).

### 3. Key vocabulary: `StatKeys`, one file of `StringName` constants
- `src/foundation/data/stat_keys.gd` holds `class_name StatKeys extends RefCounted`, constants only, never instanced. Data & Config owns it (TR-data-010).
- One `const` per key, named in upper snake case, valued as a `&"..."` literal equal to the schema field name: `COST`, `DAMAGE`, `RANGE`, `ATTACK_INTERVAL`, `SPLASH_RADIUS`, `SLOW_STRENGTH`, `SLOW_DURATION`, `BOUNTY`, `LIVES_COST`, `MAX_HP`, `MOVE_SPEED`, `LEASH_RADIUS`, `WALK_SPEED`, `RADIUS`, `REACH`, `COOLDOWN`, `TELEGRAPH_DURATION` (17 keys). A key name is shared across types: `damage` is one key that Tower, Hero and Burst rows each list.
- `enum Kind { INT, FLOAT }`.
- `const ROWS`: record type (`&"tower"`, `&"enemy"`, `&"hero"`, `&"burst"`, the values `Catalogue.type_of()` returns) to a Dictionary of key to `Kind`, copying the Data GDD's MVP stat-key table exactly.
- `const ROLE_TAG`: `SPLASH_RADIUS` to `&"splash"`, `SLOW_STRENGTH` and `SLOW_DURATION` to `&"slow"`. A key in `ROLE_TAG` applies to a tower only when its `tags` hold that tag.
- The tables are untyped `const` Dictionary literals, so they are read-only (E1) and parse on every 4.x. Typed `Dictionary[K, V]` is 4.4+ and not in the pinned reference, so it is not used here; the schema test (V4) checks the contents instead.
- **The schema test ties the two tables.** Every `ROWS` entry must name a field of the same kind (`INT` or `FLOAT`) on that type's schema table (`tower_level` for towers). Every `INT` or `FLOAT` field on `tower_level`, `enemy`, `hero` and `burst` must have a `ROWS` entry. So an owning GDD that adds a numeric field must add its key in the same change, or CI fails. Stage, Wave and Input have no row and are read directly (Data Rule 10).
- Callers name keys only through these constants. A `String` literal or a `&"..."` literal at a call site is forbidden (L-STAT-1): it skips the vocabulary, and a `String` converts to `StringName` on every call (E5).

### 4. `ReadContext`: one per caller, reused, holding the live entity weakly
- `src/foundation/data/read_context.gd`: `class_name ReadContext extends RefCounted` with `def_id: StringName`, `level: int` (0 for non-towers) and a private `_live: WeakRef`. `_init(def_id, level := 0, live_entity: Object = null)` stores `weakref(live_entity)` when one is given. `live_entity() -> Object` returns `_live.get_ref()`, or null.
- **Why weak.** An `Enemy` holds its own context. If the context held the `Enemy` strongly, the two `RefCounted` objects would point at each other and never free, and ADR-0001's retry weakref check would catch a leak on every battle. A weak reference breaks the cycle at the cost of one `WeakRef` per context, made at spawn (E4).
- The live entity must be a sim object (`RefCounted`), never a `Node`, so ADR-0001's no-Node rule holds. At MVP the accessor ignores it; it exists so the first cross-buff can read instance and position with no call-site change (Data Rule 10).
- **Who owns which context.** Each caller makes its contexts once and reuses them for every read; a read never creates one.

| Owner | Contexts | `def_id` | `level` | Live entity |
|---|---|---|---|---|
| `Enemy` (ADR-0009) | one, made at spawn | its enemy ID | 0 | the `Enemy` |
| `TowerSim` | one per built slot, made on `build` | the tower ID | set to 1 on build; the owner raises it on upgrade, after the level commit | the slot's tower state object |
| `TowerSim` | one scratch context for commands | set per command | set per command | none |
| `HeroSim` | two, made at build | Hero record ID; `burst_id` | 0 | the hero state object, for both |
| `HudLogic` | one preview context | set before each read | set before each read | none |

- Only the owner writes its contexts. Sims never change a context's `def_id` after creation; TowerSim changes only `level`. The scratch and preview contexts are the only ones whose `def_id` changes.
- The accessor never stores a context or anything read from one. It holds only the Catalogue and the handler.

### 5. Where reads may happen
- **Inside a tick**, by EnemyWave, TowerSim and HeroSim, in their tick slots (ADR-0004 Decision 5). A sim reads every stat an action needs before it changes any state (Tower Rule 9 step 3), so a bad read halts with nothing half done.
- **In a command, before any change.** `TowerSim.build` and `upgrade` check `is_tower` and `level_count` first (non-fatal), then read `cost`, then check `halted()`; a bad cost read returns `HALTED` with gold and slots unchanged (Tower edge case).
- **In the view step or an input callback, read-only, by HudLogic.** Cost chips read `cost` on arc open and on `gold_changed` while open; the wedge reads Burst `cooldown` each refresh with the injected `burst_id` (HUD Rule 12). These reads change no sim state, so they cannot affect a result. After each, HudLogic checks `halted()` and, when true, abandons the update and lets the Fatal path take over (TR-hud-011).
- **Never cached.** A value read is used in that action and dropped. The one exception is `max_hp`, read once at spawn to seed `Health` (Data Interactions table). A stat duration is converted with `to_ticks` when it starts a countdown (ADR-0004); the int countdown is state, not a cached stat. An upgrade that changes `attack_interval` takes effect at the next reload (Tower Rule 12).
- The Builder reads no stat. It reads `burst_id` from the Hero record directly, as a reference.

### 6. Non-fatal lookups
- `is_tower(id) -> bool` is `catalogue.type_of(id) == &"tower"`.
- `level_count(def_id) -> int` is `catalogue.tower(def_id).levels.size()`, or 0 when `def_id` is not a tower.
- Neither ever calls the handler. Callers use them before a read when an ID or level is not yet trusted: a bot's `build` with an enemy ID, an `upgrade` at the last level, a HUD upgrade chip at `level + 1`.

### 7. How callers get the accessor
- The Builder injects the battle's `StatAccessor` object (not two Callables) into EnemyWave, TowerSim and HeroSim. ADR-0001 already lists "the battle's `StatAccessor`" as an injection target held by `Battle`. An object keeps typed returns and lets tests pass a spy subclass.
- `Battle` gains a read-only getter `stat_accessor() -> StatAccessor` returning `_stat_accessor`. Only the composition root calls it: the wrapper passes the result to HudLogic. The member stays private, the battle still has one accessor, and HudLogic, a Presentation module, gets a Foundation object, so no layer rule breaks. A HUD must not build its own accessor, which would need its own latch.
- Combat reads no stat. Callers pass values in (Data Interactions table).

### 8. Read path at MVP and the Vertical Slice seam
- A read does: the Decision 2 checks; one `type_of()` lookup; one typed lookup (`tower()`, `enemy()`, `hero()` or `burst()`); for a tower, `levels[level - 1]`; then `Object.get(key)` on that record or level (E3), typed into the return. That is two Dictionary lookups, two small `const` table lookups and one property get, with no allocation (E6).
- `Object.get` keeps one table (`StatKeys`) as the only key list; the schema test keeps it in step with `schema.gd`. If perf check P1 fails its budget, the fallback is a hand-written `match` per type with direct field access, behind the same two methods, with no call-site change.
- **Vertical Slice.** The Stat & Modifier resolver (Core) changes the accessor's inside only: base value as above, then modifiers. Foundation cannot depend on Core, so the Stat ADR will add a Foundation base class the resolver extends, injected by the Builder. Nothing for it is built now (Data extension rule: no empty fields ahead of need).
- **Reserved modifier grant tags.** A modifier says who granted it with two fields, `grant_kind: StringName` and `grant_id: StringName`. They are never named `source_*`, so they stay apart from Combat's `DamageEvent.source_kind` and `source_id` ("who dealt this") as the Data GDD asks. `StatKeys` reserves three `grant_kind` values now: `GRANT_SKILL_TREE := &"skill_tree"`, `GRANT_HERO_WEAPON := &"hero_weapon"`, `GRANT_SYNERGY := &"synergy"`. Nothing reads them at MVP. The Stat GDD may add values; it must not reuse a reserved one for another meaning.

### Architecture Diagram

```
Builder (step b) ──► StatAccessor(catalogue, battle_latch.fatal)   held as Battle._stat_accessor
                         │  reads                    │ bad call
                         ▼                           ▼
                 Catalogue (shared, read-only)   FatalLatch.fatal(cause) ──► latched ──► Flow FATAL
                 type_of(), tower(), enemy(),        (halted() now true)
                 hero(), burst()  +  StatKeys tables

Injected StatAccessor object:
  EnemyWave ── Enemy.ctx(enemy_id, 0, weak Enemy) ──► stat_float(MOVE_SPEED), stat_int(BOUNTY, LIVES_COST)
  TowerSim  ── slot ctx(tower_id, level), scratch ctx ──► is_tower, level_count, stat_int(COST), stat_float(...)
  HeroSim   ── hero ctx(hero_id), burst ctx(burst_id) ──► stat_float(...)
Battle.stat_accessor() ──► BattleWrapper ──► HudLogic ── preview ctx ──► stat_int(COST), stat_float(COOLDOWN)

Every caller: read ──► if halted(): return
```

### Key Interfaces

```gdscript
class_name StatKeys extends RefCounted   # constants only; never instanced
enum Kind { INT, FLOAT }
const COST := &"cost"
const DAMAGE := &"damage"
# ... RANGE, ATTACK_INTERVAL, SPLASH_RADIUS, SLOW_STRENGTH, SLOW_DURATION, BOUNTY,
#     LIVES_COST, MAX_HP, MOVE_SPEED, LEASH_RADIUS, WALK_SPEED, RADIUS, REACH,
#     COOLDOWN, TELEGRAPH_DURATION
const ROWS := {
	&"tower": {COST: Kind.INT, DAMAGE: Kind.FLOAT, RANGE: Kind.FLOAT, ATTACK_INTERVAL: Kind.FLOAT,
			SPLASH_RADIUS: Kind.FLOAT, SLOW_STRENGTH: Kind.FLOAT, SLOW_DURATION: Kind.FLOAT},
	&"enemy": {BOUNTY: Kind.INT, LIVES_COST: Kind.INT, MAX_HP: Kind.FLOAT, MOVE_SPEED: Kind.FLOAT},
	&"hero": {DAMAGE: Kind.FLOAT, ATTACK_INTERVAL: Kind.FLOAT, LEASH_RADIUS: Kind.FLOAT, WALK_SPEED: Kind.FLOAT},
	&"burst": {DAMAGE: Kind.FLOAT, RADIUS: Kind.FLOAT, REACH: Kind.FLOAT, COOLDOWN: Kind.FLOAT,
			TELEGRAPH_DURATION: Kind.FLOAT},
}
const ROLE_TAG := {SPLASH_RADIUS: &"splash", SLOW_STRENGTH: &"slow", SLOW_DURATION: &"slow"}
# Reserved for Vertical Slice modifiers (grant_kind values). Unused at MVP.
const GRANT_SKILL_TREE := &"skill_tree"
const GRANT_HERO_WEAPON := &"hero_weapon"
const GRANT_SYNERGY := &"synergy"

class_name ReadContext extends RefCounted
var def_id: StringName
var level: int                           # 0 for non-towers; 1..n for towers
var _live: WeakRef                       # null when no live entity
func _init(p_def_id: StringName = &"", p_level: int = 0, p_live: Object = null) -> void
func live_entity() -> Object             # null when none or freed

class_name StatAccessor extends RefCounted
const CAUSE_NULL_CONTEXT := "stat_null_context"
const CAUSE_UNRESOLVED_DEF := "stat_unresolved_def"
const CAUSE_UNKNOWN_KEY := "stat_unknown_key"
const CAUSE_INAPPLICABLE_KEY := "stat_inapplicable_key"
const CAUSE_TYPE_MISMATCH := "stat_type_mismatch"
const CAUSE_BAD_LEVEL := "stat_bad_level"
func _init(catalogue: Catalogue, fatal_handler: Callable) -> void
## Base value of key for ctx, of the key's declared kind. A bad call sends one cause
## to fatal_handler and returns 0 / 0.0; the caller checks halted() before any use.
## Read at use time; never cache, except max_hp when seeding Health.
func stat_int(ctx: ReadContext, key: StringName) -> int
func stat_float(ctx: ReadContext, key: StringName) -> float
## Non-fatal. Never call the handler.
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int     # 0 when def_id is not a tower

# Battle addition (B4): func stat_accessor() -> StatAccessor   # composition root only
```

Names are proposed by this ADR. QQ-16 (global `class_name` collisions) may add a prefix; ADR-0007 decides. A spy for tests extends `StatAccessor` and overrides the two reads; under the 4.7 rule each override returns a value on every path.

### Implementation Guidelines
1. Every tower, enemy, hero and burst stat in the Data GDD's stat-key table must be read through `StatAccessor.stat_int` or `stat_float`. A direct read of one of those fields on a record or `TowerLevel` outside `src/foundation/data/` is forbidden (L-STAT-2). Stage, Wave and Input fields, and reference fields such as `burst_id`, must be read directly.
2. A read result must never be stored past the action that read it. The one exception is `max_hp`, read once at spawn to seed `Health`.
3. Every caller must check `halted()` after every read and return at once when true, before using the value (ADR-0001 Guideline 9). HudLogic abandons the update.
4. A sim must read every stat an action needs before it changes any state. A command must read before its first change.
5. Keys must be named only through `StatKeys` constants. A `String` or `&"..."` literal as a key argument is forbidden (L-STAT-1).
6. Each caller must make its `ReadContext` objects once (spawn, build, battle build, HudLogic setup) and reuse them. A read path must never call `ReadContext.new()`.
7. A `ReadContext` must hold its live entity only through `WeakRef`, and the live entity must never be a `Node`.
8. Only a context's owner may write it. Sims must not change `def_id` after creation; TowerSim must set `level` only after an upgrade commits.
9. `StatAccessor` must hold only the Catalogue and the handler. It must never store a context, a value or a per-battle cache, and the Catalogue must never hold the accessor (ADR-0002 Guideline 10).
10. A bad call must call the handler exactly once with a cause from Decision 2, in Decision 2's order, and return `0` or `0.0`. `assert` must not appear in `stat_accessor.gd` or `read_context.gd` (L-STAT-3).
11. `is_tower` and `level_count` must never call the handler. Commands must call them before a read whenever the ID or level comes from a command argument.
12. A wrong-kind call must never be coerced. `stat_int` on a float key is `stat_type_mismatch`.
13. Every numeric field added to `tower_level`, `enemy`, `hero` or `burst` in `schema.gd` must get a `StatKeys` constant and `ROWS` entry in the same change (V4).
14. The Builder must inject the battle's one `StatAccessor`. Only the composition root may call `Battle.stat_accessor()`. Nothing may make a second accessor for a battle.
15. A future modifier must name its granter `grant_kind` and `grant_id`, never `source_*`, and must not reuse a reserved `GRANT_*` value for another meaning.
16. A typed override (the test spy) must end with an explicit `return` (4.7 rule).

## Alternatives Considered

### Alternative 1: One `stat(ctx, key) -> Variant` read (architecture.md v1)
- **Description**: one method returns the value as a `Variant`; callers cast.
- **Pros**: one method; the key decides the type.
- **Cons**: every call site loses static typing and needs a cast; a wrong cast fails far from the call; the "number or nothing" problem the Data GDD names stays.
- **Rejection Reason**: TD-ARCHITECTURE A9 asked for typed reads. Two methods cost one more name and keep the parser's type checks at each call site.

### Alternative 2: Coerce a wrong-type call
- **Description**: `stat_int` on a float key returns `int(value)`; `stat_float` on an int key returns `float(value)`.
- **Pros**: no fatal for a harmless `stat_float(COST)`.
- **Cons**: `stat_int(DAMAGE)` would floor a balance value with no error. It is a silent fallback.
- **Rejection Reason**: Data Rule 8 bans fallbacks in every build. A wrong-kind call is a code bug, and a loud halt in a test finds it at once.

### Alternative 3: Read once at spawn or build, keep the value
- **Description**: each entity copies its stats when created.
- **Pros**: no reads in the hot path; simplest call sites.
- **Cons**: a Vertical Slice modifier that turns on mid-battle (a cross-buff when the hero walks near) would never reach a live entity; every call site changes at Vertical Slice.
- **Rejection Reason**: it breaks TR-data-008, the reason the accessor exists.

### Alternative 4: Inject two method Callables instead of the object
- **Description**: the Builder injects `StatAccessor.stat_int` and `stat_float` as Callables, as it does for `halted()`.
- **Pros**: same pattern as the other injected functions.
- **Cons**: `Callable.call()` returns `Variant`, so typed returns are lost again; each read pays a dynamic call; a spy needs two objects or a wrapper; `is_tower` and `level_count` add two more Callables.
- **Rejection Reason**: ADR-0001 already lists the accessor object as an injection target. The object is a `Battle` member, so the injection rules hold.

### Alternative 5: Keys as an `int` enum
- **Description**: `enum Stat { COST, DAMAGE, ... }`, with tables indexed by int.
- **Pros**: fastest compare; a typo is a parse error.
- **Cons**: Vertical Slice modifier records in JSON name the stat they change as text, so a second map from text to enum would be needed and could drift; error causes and logs would show numbers.
- **Rejection Reason**: `StringName` constants are also checked at parse time when callers use `StatKeys.X`, compare by pointer, and match the schema field names and future modifier data with no map.

### Alternative 6: Strong `live_entity` in the context
- **Description**: `var live_entity: Object` as architecture.md B0 sketches.
- **Pros**: no `WeakRef`; direct field access.
- **Cons**: an `Enemy` holds its context and the context holds the `Enemy`: a `RefCounted` cycle that never frees.
- **Rejection Reason**: it leaks every enemy and fails ADR-0001's retry weakref proof.

### Alternative 7: Hand-written `match` per key with direct field access
- **Description**: `match key: StatKeys.DAMAGE: return rec.damage ...` per type.
- **Pros**: no dynamic property get; likely faster.
- **Cons**: a second key list in code that must stay in step with `StatKeys` and `schema.gd`; more code to read.
- **Rejection Reason**: not needed until measured. It stays the fallback if P1 fails, behind the same interface.

## Consequences

### Positive
- One read path for every stat, so the Vertical Slice resolver changes one class and no call site.
- Typed returns at every call site; a wrong-kind call halts in the first test that runs it.
- Bad calls name one of six causes, so a spy test pins the exact fault and a debug Fatal screen shows it.
- Contexts are made once per owner, so a tick's reads allocate nothing, and the weak live entity keeps retry leak-free.
- The schema test makes it impossible to add a numeric stat field without its key.
- The HUD reads through the same accessor as the sim, so a preview cost always equals the paid cost.

### Negative
- Each read pays a `type_of()` lookup, a typed lookup and a dynamic property get. P1 measures it; the `match` fallback costs code.
- Callers must remember the `halted()` check after every read. Only review and tests (V5 in ADR-0001) catch a missing one.
- `Battle` gains one getter, which architecture.md B4 and ADR-0001's interface sketch do not yet list.
- The `0` / `0.0` return after a bad call is a real number a careless caller could use. Guideline 3 and the halt tests guard it.

### Neutral
- The live entity is unused at MVP. It costs one `WeakRef` per context.
- The reserved grant tags are three constants with no reader until Vertical Slice.

## Risks
- **R1 Read cost on device.** 100 enemies plus 10 towers give about 150 reads a tick. If each costs about 1 µs on an Adreno 5xx-class phone, reads take 0.15 ms of the 2.0 ms tick. Unmeasured. Mitigation: P1 on desktop now, on device at the first phone build; the `match` fallback (Alternative 7) needs no call-site change.
- **R2 `String` and `StringName` keys mix (E2).** If a `String` key misses in a `StringName`-keyed Dictionary, a literal call would report `stat_unknown_key`; if it hits, it is silently slow. Mitigation: L-STAT-1 bans literals at call sites; V1 calls through constants only.
- **R3 Const Dictionary behaviour (E1).** If a `const` Dictionary keyed by other constants does not parse or is writable at run time in 4.7.2, the tables move to a `static var` filled once and made read-only with `make_read_only()`. No caller changes.
- **R4 A missed `halted()` check** lets a `0` reach state, such as an enemy that does not move for one tick. Mitigation: ADR-0001 V5 halts mid-tick; each consumer story adds a spy that fires `fatal` on its read and asserts no state change and no emit.
- **R5 Weak live entity freed early.** If the only strong reference to a live entity drops while its context is still used, `live_entity()` returns null. At MVP nothing reads it. The Stat ADR must treat null as "no instance".

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-008: every modifiable value is read through one stat accessor (read_context, stat_key) at use time, never cached, so Stat & Modifier Resolution can replace its internals with no call-site change | Decisions 1, 5 and 8: two typed reads over a `ReadContext`; never-cache rule with the `max_hp` exception; the resolver changes only the accessor's inside. The Vertical Slice proof waits for the Stat GDD |
| data-config-pipeline.md | TR-data-010: Data owns the stat-key vocabulary and int/float type per key, and exposes non-fatal `level_count(def_id)` and `is_tower(id)` | Decisions 3 and 6: `StatKeys` in `src/foundation/data/`, kinds per key, schema test V4; `is_tower` and `level_count` never call the handler |
| enemy-wave.md | TR-enemy-006: every enemy stat is read through the accessor at use time with a reused per-enemy read context; Wave and Stage records are read directly and never written | Decision 4: one context per `Enemy`, made at spawn; Decision 5 and Guideline 1: Wave and Stage read directly. ADR-0002's snapshot proves no write |
| tower-system.md | TR-tower-003: tower IDs and levels are validated with `is_tower` and `level_count` before any accessor read; cost and stats are read at use time | Decisions 5 and 6, Guideline 11: lookups first in `build` and `upgrade`, then the cost read, then `halted()`; slot context `level` follows the commit |
| hero-system.md | TR-hero-005: Hero and Burst stats are read through the accessor at use time; `hero_start`, `pin_rect` and `pin_exclusion` come straight from the Stage record | Decision 4: HeroSim's two contexts (Hero ID, `burst_id`); Guideline 1: Stage fields read directly |
| battle-hud.md | TR-hud-011: costs are read through the accessor on arc open and `gold_changed`, and the burst wedge reads Burst cooldown through the accessor at use time with the builder-injected Burst ID; a read that finds `halted()` is abandoned for the Fatal screen | Decisions 5 and 7: HudLogic gets the battle's accessor through `Battle.stat_accessor()`, reads with a preview context in the view step, checks `halted()` and abandons |
| data-config-pipeline.md | Rule 10 bad-call list (unknown or inapplicable key, bad level, unresolved `def_id`) and the release-build handler (TR-data-009, ADR-0001) | Decision 2: six causes in a fixed order, plain branches, no `assert`; handler is the battle latch's `fatal` |

## Performance Implications
- **CPU**: per read, two Dictionary lookups, two `const` table lookups, one `Object.get`, and an `Array.has` for role keys. Estimated 0.15 ms a tick on the target phone (R1), inside ADR-0004's 4.0 ms simulation budget. Provisional; P1 measures it.
- **Memory**: one `ReadContext` and one `WeakRef` per enemy, tower slot and the hero and burst, plus one scratch and one preview. A few hundred bytes each. No per-read allocation.
- **Load Time**: none. The tables are constants; the accessor is made once per battle.
- **Network**: not applicable.

## Migration Plan
No code exists, so nothing moves. Documents to change when this ADR is accepted (not changed by this ADR):
1. `architecture.md`: B0 `ReadContext` row (weak live entity, `_init` signature, owner table); B1 (StatKeys, cause codes, constructor); B4 (`Battle.stat_accessor()`); B9 (a `StatAccessor` row: injected into EnemyWave, TowerSim, HeroSim; HudLogic via the wrapper); Module Ownership StatAccessor row (`StatKeys` file); Seams row (grant tags named); Required ADRs and Document Status (ADR-0005 written, Proposed).
2. `design/gdd/data-config-pipeline.md`: Rule 10, Edge Cases and AC 7 add the wrong-kind call and the null context as bad calls; Rule 10's "value is unspecified" may note it is `0` or `0.0` and still unusable.
3. ADR-0001 (next revision): the `Battle` sketch adds `stat_accessor()`.

## Validation Criteria
Fixtures are code-built through `Catalogue.from_documents` (ADR-0002); the handler is a recording spy; no file I/O.
- **V1 `test_reads_return_base_values`** (Data AC 6): every key in each type's row, for every tower level and role, with a live entity and with a preview context, returns the fixture value of the declared kind; `level_count` matches each tower.
- **V2 `test_bad_calls_name_one_cause`** (Data AC 7): table-driven, one case per Decision 2 row, plus a case with two faults that reports only the earlier cause. The spy fires once; the first token equals the cause. The return value is not asserted.
- **V3 `test_lookups_never_fatal`**: `is_tower` on an enemy, wave and unknown ID is false; `level_count` on them is 0; the spy never fires.
- **V4 `test_stat_keys_match_schema`**: both directions of Decision 3's schema rule, against `schema.gd`.
- **V5 `test_bad_read_keeps_catalogue_ready`** (Data AC 12): after a bad call the catalogue is still usable and a fresh accessor reads it.
- **V6 `test_read_context_holds_entity_weakly`** (E4): a context with a live `RefCounted` owner held only by the test; drop the owner; `live_entity()` is null and the owner's weakref is dead.
- **V7 `test_reads_allocate_no_objects`** (E6): 10,000 mixed reads; `Performance.get_monitor(Performance.OBJECT_COUNT)` is equal before and after.
- **E1 `test_const_stringname_tables`**: `StatKeys.ROWS` parses, holds `StringName` keys, and `is_read_only()` is true.
- **E2 `test_string_key_lookup`**: records whether `ROWS[&"tower"]` hits for `"cost"` as `String`; the result goes in the engine reference. No production code depends on it.
- **E3 `test_object_get_stringname`**: `Object.get(&"damage")` on a record returns the field; an unknown name returns null with no error.
- **E5 `bench_string_vs_stringname_key`**: advisory; records the cost of a `String` literal key against a constant.
- **P1 `bench_stat_reads`** (advisory, logged): 150 reads per simulated tick for 600 ticks on desktop; record µs per read. Device run at the first phone build against R1's 0.15 ms a tick.
- **Lints (ADR-0007)**: L-STAT-1 no literal key argument to `stat_int` or `stat_float`; L-STAT-2 no direct read of a stat-table field on a record or `TowerLevel` outside `src/foundation/data/`; L-STAT-3 no `assert` in `stat_accessor.gd` or `read_context.gd`.
- **Consumer stories**: Data's deferred never-cache criterion: a spy changes a value between two uses and the second use shows it (Tower, Hero, HUD, Enemy & Wave). Each also fires `fatal` from its spy on a read and asserts no state change and no emit.

## Reviews
**Reviews still owed.** godot-specialist (engine validation, Step 5.5) and technical-director (TD-ADR, Step 5.6) were not run in this pass; the caller will run both. Points to put to them: E1 to E6; the weak live entity; `Object.get` against `match`; the `Battle.stat_accessor()` getter against ADR-0001's private member; injecting the object rather than Callables.

## Related
- Depends on ADR-0001 (accessor owner, handler, `halted()` rule), ADR-0002 (records, lookups, `schema.gd`), ADR-0004 (where reads run, `to_ticks`)
- Enables ADR-0007 (lints, spy helper), ADR-0009 (Enemy context, `max_hp` seed), ADR-0010 (refusals on lookups and cost reads)
- `architecture.md` v4: Seams (Stat & Modifier, Skill Tree), Module Ownership (StatAccessor), B0, B1, B1a, B4, B9, B10
- GDDs: `data-config-pipeline.md` (stat-key table, Rules 10 and 11, Edge Cases, AC 6, 7, 12), `enemy-wave.md` (Rules 9 to 11, 13), `tower-system.md` (Rules 5, 9, 12; edge cases on cost read and preview past the last level), `hero-system.md` (Rule 8; Interactions), `battle-hud.md` (Rules 7, 12)
