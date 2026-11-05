# ADR-0005: Stat Accessor and Read-Context Contract

## Status
Accepted

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation.

## Date
2026-11-04

## Last Verified
2026-11-04 (against `docs/engine-reference/godot/` for Godot 4.7.2, `architecture.md` v4, ADR-0001, ADR-0002 and ADR-0004 as Accepted, `tr-registry.yaml` and `docs/registry/architecture.yaml`; revised after godot-specialist and TD-ADR reviews)

## Decision Makers
- Accepted: 2026-11-04 by the user (njarrar), with the dated ADR-0001 amendment (public read-only stat_accessor and halt_gate)
- Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`, 2026-11-04)
- godot-specialist: CONCERNS. TD-ADR: CONCERNS. Findings resolved under Reviews.
- Acceptance: the user.

## Summary
Every number a modifier could change (tower, enemy, hero and burst stats) must reach its caller through one per-battle accessor, read at use time, so the Vertical Slice stat resolver can drop in with no call-site change. This ADR fixes that accessor: two typed reads, `stat_int` and `stat_float`, over a caller-owned and reused `ReadContext`, keys as `StringName` constants in one `StatKeys` file checked against the schema, six named bad-call causes sent to the battle latch's `fatal`, two non-fatal lookups, and reserved modifier grant tags.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core (scripting, data access) |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW. Every API used but `@abstract` dates from 4.0, and `breaking-changes.md` lists no 4.4 to 4.7 change to them. `@abstract` (4.5) is in `current-best-practices.md`. The 4.7 typed-override rule applies to the test spy. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.5 and 4.7 GDScript and Core rows), `deprecated-apis.md` (untyped container row), `current-best-practices.md` (GDScript 4.5, 4.7), `modules/input.md` (StringName in hot paths). No `modules/` file covers scripting. `architecture.md` v4 (Seams, Module Ownership, B0, B1, B1a, B9, B10, Required ADRs); `tr-registry.yaml`; ADR-0001, ADR-0002, ADR-0004 |
| **Post-Cutoff APIs Used** | `@abstract` (4.5) on `StatKeys` only. Also used: `StringName` and `&"..."`, `const` Dictionary literals, `Dictionary.get(key, default)`, `Object.get(StringName)`, `weakref()`, `WeakRef.get_ref()`, `Array.has()`; in tests `Performance.get_monitor()`, `Time.get_ticks_usec()`, `ClassDB.class_exists()`. Typed `Dictionary[K, V]` (4.4) is not used. |
| **Verification Required** | All probes ran on the 4.7.2 binary (`docs/engine-reference/godot/probe-results.md`): E1, E3, E4, E6 and E7 match, E5 does not (Amendments). The rows below still become CI tests (ADR-0007 Decision 7). **E1** `const K := &"x"` and `const` Dictionaries keyed by such constants parse, and `ROWS`, each inner table, `KIND` and `ROLE_TAG` report `is_read_only()`. **E3** `Object.get(&"name")` returns a script `var`'s value and `null` for an unknown name with no error; the same probe records whether a `StringName`-keyed Dictionary hits on a `String` key of the same text (was E2). **E4** `WeakRef.get_ref()` returns `null` once the last strong reference to a `RefCounted` drops. **E5** (corrected) a `String` literal passed to a `StringName` parameter costs the same as a constant: the compiler converts it once (ratio 0.99). A `String` variable costs 1.42x. **E6** a read creates no `Object` and leaves static memory flat after warm-up. **E7** `ClassDB.class_exists()` is false for `StatKeys`, `ReadContext` and `StatAccessor` (no engine class of that name). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted, amended 2026-11-04 with this ADR): one accessor per battle built by the Builder with the battle latch's `fatal`, held by `Battle`; callers check `halted()` after every read. ADR-0002 (Accepted): `RefCounted` records with `StringName` IDs; typed lookups that return null and call no handler; `type_of()`; `schema.gd`; `is_tower` and `level_count` move here. ADR-0004 (Accepted): reads run inside ticks, in commands before any change, or in the view step; `to_ticks` turns read seconds into ticks. |
| **Enables** | ADR-0007 (lints L-STAT-1 to L-STAT-3, the recording spy helper), ADR-0009 (Enemy holds its context; `max_hp` seeds Health), ADR-0010 (`BAD_TOWER`, `MAX_LEVEL`, `HALTED` refusals rest on the lookups and the cost read), the Vertical Slice Stat & Modifier GDD and ADR |
| **Blocks** | The Data & Config accessor story and every Enemy & Wave, Tower, Hero and HUD story that reads a stat. No epic or story exists yet, so none is blocked by path today. |
| **Ordering Note** | Write after ADR-0002 and ADR-0004, before ADR-0009 and ADR-0010. P1 runs on desktop with the first accessor story; its device run waits for the first phone build. |

## Context

### Problem Statement
Four MVP systems read authored stats in the hot path: every enemy reads `move_speed` every tick, every tower reads `range` and then its attack stats, and the hero and burst read theirs. The HUD reads costs and the burst `cooldown`. The Data GDD (Rules 10, 11) asks that all of these go through one accessor taking a read context and a stat key, at use time, so a Vertical Slice modifier changes the value with no change at any call site. architecture.md v4 sketches the accessor (B1) and context (B0) but leaves open the typed split, wrong-type calls, context reuse, the key vocabulary's form and home, how the HUD reaches the accessor, and which modifier tags are reserved.

### Constraints
- **ADR-0001**: one `StatAccessor` per battle, made in Builder step (b) over the shared `Catalogue` with the battle latch's `fatal`. Every injection target is a member of `Battle` or `AppRoot`. No sim object holds `Battle`, `AppRoot` or a `Node`. Guideline 9 (check `halted()` after every read) and Guideline 10 (no `assert` for release checks).
- **ADR-0002**: typed `RefCounted` records; `StringName` IDs made once at load; lookups return null and never call a handler; the Catalogue holds no battle reference; `schema.gd` is the one field table.
- **ADR-0004**: reads run inside a tick, in a command before any change, or in frame step 3 (views). Sim signals fire synchronously inside the tick. Durations go through `to_ticks`.
- **Data GDD**: no fallbacks (Rule 8); never cache, except `max_hp` when seeding Health; Stage, Wave and Input are read directly; a level on a non-tower is a bad call; the value after a bad call is unusable.
- **Performance**: one tick at most 2.0 ms p95 on an Adreno 5xx-class phone (ADR-0004, unmeasured).

### Requirements
TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005, TR-hud-011 (quoted in GDD Requirements Addressed). TR-data-009 is ADR-0001's; this ADR uses it.

## Decision

### 1. Two typed reads; a wrong-type call is a bad call
- `stat_int(ctx, key) -> int` and `stat_float(ctx, key) -> float`; no `Variant` read (TD-ARCHITECTURE A9). Each key has one kind. At MVP the int keys are `cost`, `bounty` and `lives_cost`; all others are float.
- `stat_int` on a float key, or `stat_float` on an int key, is cause `stat_type_mismatch`. It is never coerced: a silent `int()` on `damage` would floor a balance value (Data Rule 8).
- After any bad call the read returns `0` or `0.0`, so the function keeps a typed return. No caller may use it (ADR-0001 Guideline 9); tests never assert it.

### 2. Bad calls: six causes, in a fixed order
A read checks in this order and stops at the first failure:

| # | Cause code | When |
|---|---|---|
| 1 | `stat_null_context` | `ctx` is null |
| 2 | `stat_unresolved_def` | `type_of(ctx.def_id)` has no `ROWS` entry (unknown ID, or a Stage, Wave or Input ID) |
| 3 | `stat_unknown_key` | `KIND.get(key, -1)` is `-1` |
| 4 | `stat_inapplicable_key` | `ROWS[type].get(key, false)` is false; or a `ROLE_TAG` key on a tower whose `tags` lack that tag; or `Object.get(key)` returns `null` (defensive, see Decision 8) |
| 5 | `stat_type_mismatch` | `KIND[key]` differs from the method called |
| 6 | `stat_bad_level` | a tower with `level` outside `1..levels.size()`, or a non-tower with `level != 0` |

- The accessor calls its handler once with `"<code> def=<def_id> key=<key> level=<level>"`; for cause 1, `"stat_null_context def=- key=<key> level=-"`. The string is built only on the failure path. Spy tests compare the first token.
- The handler is the battle latch's `fatal`: it keeps the first cause and emits `latched` once, so Flow enters `FATAL` and `halted()` turns true (ADR-0001 Decision 6). A second bad read changes nothing.
- The checks are plain `if` branches, per ADR-0001 Guideline 10.

### 3. Key vocabulary: `StatKeys`, one file of `StringName` constants
- `src/foundation/data/stat_keys.gd`: `@abstract class_name StatKeys extends RefCounted`, constants only, so it cannot be constructed by name: `StatKeys.new()` is a parse error. Dynamic instancing is not blocked: `load(path).new()` still builds an instance, and `can_instantiate()` is true. Nothing does that at MVP, so no lint is needed. Data & Config owns it (TR-data-010).
- One `const` per key, upper snake case, valued as a `&"..."` literal equal to the schema field name: `COST`, `DAMAGE`, `RANGE`, `ATTACK_INTERVAL`, `SPLASH_RADIUS`, `SLOW_STRENGTH`, `SLOW_DURATION`, `BOUNTY`, `LIVES_COST`, `MAX_HP`, `MOVE_SPEED`, `LEASH_RADIUS`, `WALK_SPEED`, `RADIUS`, `REACH`, `COOLDOWN`, `TELEGRAPH_DURATION` (17). A key is shared across types: `damage` is one key that Tower, Hero and Burst all allow.
- `enum Kind { INT, FLOAT }`. Three tables:
  - `KIND`: every key to its `Kind`, the whole vocabulary.
  - `ROWS`: each record type (`&"tower"`, `&"enemy"`, `&"hero"`, `&"burst"`, as `Catalogue.type_of()` returns them) to its allowed key set (`{key: true}`), copying the Data GDD's stat-key table.
  - `ROLE_TAG`: `SPLASH_RADIUS` to `&"splash"`; `SLOW_STRENGTH`, `SLOW_DURATION` to `&"slow"`.
- **Untyped on purpose.** A `const` Dictionary is read-only (E1); typed Dictionaries do not nest a typed value Dictionary; and typing gives no read-speed gain. This settles `deprecated-apis.md`'s untyped-container row for these tables. Each read site types its local. If E1 finds an inner table writable, the tables become `static var`s with `make_read_only()` on each, and no caller changes.
- Lookups use `Dictionary.get(key, default)`, never `has()` then `[]`.
- **Schema test V4 ties the tables to `schema.gd`.** Every `ROWS` key must name a field on that type's schema table (`tower_level` for towers) of the kind `KIND` gives; every `INT` or `FLOAT` field on `tower_level`, `enemy`, `hero` and `burst` must be in `ROWS`; every `KIND` key must be in some row. An owning GDD that adds a numeric field adds its key in the same change, or CI fails.
- Callers name keys only through these constants (L-STAT-1). The reasons are the vocabulary and typo safety: a literal skips the vocabulary, and a mistyped constant fails the parse. Cost is not a reason: a literal costs the same as a constant (E5).

### 4. `ReadContext`: one per caller, reused, live entity held weakly
- `src/foundation/data/read_context.gd`: `class_name ReadContext extends RefCounted` with `def_id: StringName`, `level: int` and private `_live: WeakRef`. `_init(p_def_id: StringName = &"", p_level: int = 0, p_live: Object = null)` sets `_live = weakref(p_live)` only when `p_live` is not null; otherwise `_live` stays `null`. `live_entity() -> Object` returns `_live.get_ref()`, or null.
- **Why keep `_live` now.** The Data GDD (Rule 10) requires the context to carry the live entity so the first cross-buff needs no call-site change; adding it later would change every owner's constructor call, so it is not an empty field ahead of need.
- **Why weak.** An `Enemy` holds its own context; a strong back-reference would form a `RefCounted` cycle that never frees and fails ADR-0001's retry weakref check (E4).
- The live entity is a sim object, never a `Node`. At MVP the accessor ignores it.
- **Owners.** Each caller makes its contexts once and reuses them; a read never makes one.

| Owner | Contexts | `def_id` | `level` | Live entity |
|---|---|---|---|---|
| `Enemy` (ADR-0009) | one, at spawn | enemy ID | 0 | the `Enemy` |
| `TowerSim` | one per built slot, on `build` | tower ID | 1 on build; raised after an upgrade commits | the slot's tower state |
| `TowerSim` | one scratch, for commands | per command | per command | none |
| `HeroSim` | two, at battle build | Hero ID; `burst_id` | 0 | the hero state, for both |
| `HudLogic` | one preview | before each read | before each read | none |
| `HeroInput` (ADR-0010) | one, at setup | `burst_id` | 0 | none |

- Only the owner writes a context. Sims never change `def_id`; TowerSim changes only `level`. The accessor never stores a context or a value.

### 5. Where reads may happen
- **Inside a tick**, by EnemyWave (`move_speed`, `lives_cost`, `bounty`, and `max_hp` once at spawn), TowerSim (`range`, then `damage`, `attack_interval` and role keys) and HeroSim (Hero and Burst keys). A sim reads every stat an action needs before it changes state (Tower Rule 9 step 3).
- **In a command, before any change.** `build` and `upgrade` call `is_tower` and `level_count` first, then read `cost`, then check `halted()`; a bad cost read returns `HALTED` with nothing changed. `pin` reads `walk_speed`; `burst` reads `reach`, then `telegraph_duration`; each read is followed by `halted()` (ADR-0010 Decision 3).
- **In frame step 3 only, by HudLogic.** Opening the arc and `gold_changed` only mark costs dirty; HudLogic reads `cost` (and `range` for range rings) in the next view step. The wedge reads Burst `cooldown` there each refresh with the injected `burst_id`. `gold_changed` fires in the reap slot, inside the tick, so **HudLogic never reads the accessor from inside a sim signal handler**. For an upgrade chip, HudLogic checks `level < level_count(def_id)`, then sets the preview `level` to `level + 1`. After each read it checks `halted()` and, when true, abandons the update for the Fatal path.
- **In frame step 1, by HeroInput, between ticks, only in the Cancelling and Live aim states** (amended 2026-11-05 with ADR-0010): Burst `reach`, `radius`, `damage`, and Combat `hp_left`, `is_dead` for the kill preview, each followed by `halted()`.
- **Never cached.** A value is used in its action and dropped, except `max_hp` seeding `Health`. A countdown started with `to_ticks` is state, not a cached stat; a new `attack_interval` applies at the next reload (Tower Rule 12).
- The Builder reads no stat; it reads `burst_id` from the Hero record directly.

### 6. Non-fatal lookups
- `is_tower(id) -> bool` is `catalogue.type_of(id) == &"tower"`. `level_count(def_id) -> int` is the tower's `levels.size()`, or 0 for a non-tower.
- Neither calls the handler. Callers use them before a read whenever an ID or level is not yet trusted.

### 7. How callers get the accessor
- `Battle` holds the accessor as the public read-only member `stat_accessor: StatAccessor`, beside `input_resolver` (ADR-0001 amended). There is still one per battle.
- The Builder injects that object, not a method Callable, into EnemyWave, TowerSim and HeroSim: an object keeps typed returns and lets tests pass a spy subclass.
- The wrapper passes `battle.stat_accessor` to HudLogic, and passes `battle.halt_gate.halted` to it as a method Callable; `halt_gate` is a public read-only member of `Battle` (ADR-0001 amended). B9's rule against injecting `Battle.halted()` stands. A HUD never builds its own accessor.
- Combat reads no stat; callers pass values in.

### 8. Read path at MVP and the Vertical Slice seam
- A read runs the Decision 2 checks; one `type_of()` lookup; one typed lookup (`tower()`, `enemy()`, `hero()` or `burst()`); for a tower, `levels[level - 1]`; then `Object.get(key)` on that record or level, typed into the return. A `null` from `Object.get` is cause 4, so a key that V4 missed halts loudly instead of erroring on the typed assign.
- If P1 fails its trigger, the fallback is a hand-written `match` per type with direct field access, behind the same two methods.
- **Seam type.** `StatAccessor` itself is the Vertical Slice seam. The Core resolver extends it and overrides `stat_int` and `stat_float` (base value, then modifiers); the Builder makes the subclass instead. Core depending on Foundation is allowed, so no extra base class is needed and nothing is built now.
- **Reserved grant tags.** A modifier names its granter with `grant_kind: StringName` and `grant_id: StringName`, never `source_*`, so it stays apart from `DamageEvent.source_kind` and `source_id` (Data GDD "Not owned"). `StatKeys` reserves `GRANT_SKILL_TREE := &"skill_tree"`, `GRANT_HERO_WEAPON := &"hero_weapon"`, `GRANT_SYNERGY := &"synergy"`. Nothing reads them at MVP; the Stat GDD may add values but must not reuse these.

### Architecture Diagram

```
Builder (step b) ──► StatAccessor(catalogue, battle_latch.fatal)   = Battle.stat_accessor
                         │ reads                       │ bad call
                         ▼                             ▼
                 Catalogue (shared, read-only)    FatalLatch.fatal(cause) ──► latched ──► Flow FATAL
                 type_of, tower, enemy, hero, burst   (halted() now true)
                 + StatKeys KIND / ROWS / ROLE_TAG

Injected object, read in the tick or a command:
  EnemyWave ── Enemy ctx(enemy_id, 0, weak Enemy) ──► MOVE_SPEED, LIVES_COST, BOUNTY, MAX_HP (spawn)
  TowerSim  ── slot ctx, scratch ctx ──► is_tower, level_count, COST, RANGE, DAMAGE, ATTACK_INTERVAL, role keys
  HeroSim   ── hero ctx, burst ctx ──► Hero and Burst keys
Wrapper: battle.stat_accessor + battle.halt_gate.halted ──► HudLogic ── preview ctx, frame step 3 only ──► COST, RANGE, COOLDOWN

Every caller: read ──► if halted(): return
```

### Key Interfaces

```gdscript
@abstract
class_name StatKeys extends RefCounted   # constants only; cannot be constructed by name
enum Kind { INT, FLOAT }
const COST := &"cost"
const DAMAGE := &"damage"
# ... RANGE, ATTACK_INTERVAL, SPLASH_RADIUS, SLOW_STRENGTH, SLOW_DURATION, BOUNTY, LIVES_COST,
#     MAX_HP, MOVE_SPEED, LEASH_RADIUS, WALK_SPEED, RADIUS, REACH, COOLDOWN, TELEGRAPH_DURATION
const KIND := {COST: Kind.INT, BOUNTY: Kind.INT, LIVES_COST: Kind.INT, DAMAGE: Kind.FLOAT,
		RANGE: Kind.FLOAT, ATTACK_INTERVAL: Kind.FLOAT}   # ... every key
const ROWS := {
	&"tower": {COST: true, DAMAGE: true, RANGE: true, ATTACK_INTERVAL: true,
			SPLASH_RADIUS: true, SLOW_STRENGTH: true, SLOW_DURATION: true},
	&"enemy": {BOUNTY: true, LIVES_COST: true, MAX_HP: true, MOVE_SPEED: true},
	&"hero": {DAMAGE: true, ATTACK_INTERVAL: true, LEASH_RADIUS: true, WALK_SPEED: true},
	&"burst": {DAMAGE: true, RADIUS: true, REACH: true, COOLDOWN: true, TELEGRAPH_DURATION: true},
}
const ROLE_TAG := {SPLASH_RADIUS: &"splash", SLOW_STRENGTH: &"slow", SLOW_DURATION: &"slow"}
const GRANT_SKILL_TREE := &"skill_tree"     # reserved grant_kind values; unused at MVP
const GRANT_HERO_WEAPON := &"hero_weapon"
const GRANT_SYNERGY := &"synergy"

class_name ReadContext extends RefCounted
var def_id: StringName
var level: int                           # 0 for non-towers; 1..n for towers
var _live: WeakRef = null                # null when no live entity
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
## Base value of key for ctx, of the key's kind. A bad call sends one cause to
## fatal_handler and returns 0 / 0.0. Read at use time; never cache, except max_hp.
func stat_int(ctx: ReadContext, key: StringName) -> int
func stat_float(ctx: ReadContext, key: StringName) -> float
## Non-fatal. Never call the handler.
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int     # 0 when def_id is not a tower

# Battle (ADR-0001 amended): var stat_accessor: StatAccessor   # read-only by contract
```

Names are proposed. QQ-16 may add a prefix (ADR-0007); E7 checks for engine-class clashes. `StatAccessor` is not abstract: the game uses it as is.

### Implementation Guidelines
1. Every tower, enemy, hero and burst stat in `StatKeys.ROWS` must be read through `stat_int` or `stat_float`. A direct read of such a field outside `src/foundation/data/` is forbidden (L-STAT-2). Stage, Wave and Input fields and references such as `burst_id` must be read directly.
2. A read result must never be stored past the action that read it, except `max_hp` seeding `Health`.
3. Callers follow ADR-0001 Guideline 9 after every read. Tests prove it with the recording spy: on the read where it fires `fatal`, it returns a poison value (fixture value plus 1000), so a missed check shows as a state change or an emit. Production returns `0` / `0.0`.
4. A sim must read every stat an action needs before it changes state; a command must read before its first change.
5. Keys must come only from `StatKeys` constants; a `String` or `&"..."` literal key argument is forbidden (L-STAT-1).
6. Each caller must make its contexts once and reuse them. A read path must never call `ReadContext.new()`.
7. A context must hold its live entity only through `WeakRef`, `null` when there is none, and never a `Node`.
8. Only a context's owner may write it. Sims must not change `def_id`; TowerSim sets `level` only after an upgrade commits.
9. `StatAccessor` must hold only the Catalogue and the handler: no context, value or cache.
10. A bad call must call the handler exactly once with a Decision 2 cause, in Decision 2's order, and return `0` / `0.0`. ADR-0001 Guideline 10 applies; L-STAT-3 lints `stat_accessor.gd` and `read_context.gd` for `assert`.
11. `is_tower` and `level_count` must never call the handler. Commands must call them before a read when the ID or level comes from an argument.
12. A wrong-kind call must never be coerced.
13. A numeric field added to `tower_level`, `enemy`, `hero` or `burst` must get its `StatKeys` constant, `KIND` and `ROWS` entries in the same change (V4).
14. **HudLogic never reads the accessor from inside a sim signal handler.** It marks data dirty there and reads in frame step 3.
15. The Builder must inject the battle's one `stat_accessor` object. Nothing may make a second accessor for a battle.
16. A future modifier must name its granter `grant_kind` and `grant_id`, never `source_*`, and must not reuse a reserved `GRANT_*` value.
17. A spy override must keep the exact parameter list and end every path with a typed return (`return 0`, `return 0.0`), never `return null` (4.7 rule).

## Alternatives Considered

### Alternative 1: One `stat(ctx, key) -> Variant` read
- **Pros**: one method. **Cons**: every call site casts; a wrong cast fails far from the call.
- **Rejection Reason**: TD-ARCHITECTURE A9 asked for typed reads.

### Alternative 2: Coerce a wrong-type call
- **Pros**: no halt on a harmless `stat_float(COST)`. **Cons**: `stat_int(DAMAGE)` floors a balance value silently.
- **Rejection Reason**: Data Rule 8 bans fallbacks; a loud halt finds the bug in its first test.

### Alternative 3: Read once at spawn, keep the value
- **Pros**: no hot-path reads. **Cons**: a mid-battle modifier never reaches a live entity; every call site changes at Vertical Slice.
- **Rejection Reason**: breaks TR-data-008.

### Alternative 4: Inject two method Callables
- **Pros**: same pattern as `halted()`. **Cons**: `Callable.call()` returns `Variant`; a dynamic call per read; a spy needs a stand-in object.
- **Rejection Reason**: the object is a `Battle` member, so ADR-0001's rules hold, and types survive.

### Alternative 5: Keys as an `int` enum
- **Pros**: fastest compare. **Cons**: Vertical Slice modifier JSON names stats as text, needing a second map that can drift; causes show numbers.
- **Rejection Reason**: `StringName` constants are parse-checked through `StatKeys.X`, compare by pointer and match schema names with no map.

### Alternative 6: Strong `live_entity`
- **Pros**: no `WeakRef`. **Cons**: an `Enemy` and its context form a cycle that never frees.
- **Rejection Reason**: leaks every enemy and fails ADR-0001's retry proof.

### Alternative 7: Hand-written `match` per key
- **Pros**: no dynamic property get; likely faster. **Cons**: a second key list to keep in step.
- **Rejection Reason**: not chosen before measuring. P1 benches it in the same run and its trigger decides.

### Alternative 8: Public getter `Battle.stat_accessor()`
- **Pros**: keeps the member private. **Cons**: a second pattern beside ADR-0001's public read-only members.
- **Rejection Reason**: TD-ADR T2; a public member matches `input_resolver`.

## Consequences

### Positive
- One read path, so the Vertical Slice resolver subclasses one class and touches no call site.
- Typed returns everywhere; a wrong-kind call halts in its first test.
- Six named causes let a spy pin the exact fault; the debug Fatal screen shows it.
- Contexts are made once per owner; reads allocate nothing; the weak live entity keeps retry leak-free.
- V4 makes it impossible to add a numeric stat field without its key.
- The HUD reads through the same accessor, so a shown cost equals the paid cost.

### Negative
- Each read pays two Dictionary lookups, table lookups and a dynamic property get; R1 may force the `match` fallback.
- Callers must remember `halted()` after every read; the poison spy catches a miss only where a test exercises that read.
- ADR-0001 gains two public members, `stat_accessor` and `halt_gate` (amended in this change).
- The `0` / `0.0` return is a real number a careless caller could use.
- The scratch and preview contexts carry no slot and no live entity, so a Vertical Slice cost modifier that depends on position would have to change those two owners.

### Neutral
- `_live` is unused at MVP and costs one `WeakRef` per context with an entity.
- The grant tags are three constants with no reader until Vertical Slice.

## Risks
- **R1 Read cost.** Estimated 1 to 3 µs per read on desktop and 5 to 15 µs on an A53/A73-class phone core. About 150 reads a tick (100 enemies, 10 towers, hero, burst) could take 0.75 to 2.25 ms against ADR-0004's 2.0 ms p95 per tick: the top of the range breaks the budget alone. Mitigation: P1 with a desktop trigger (above 0.5 µs per read, build the `match` fallback now); R1's range suggests the trigger will fire, so Alternative 7 is benched in the same run.
- **R2 String keys.** A `String` key hits a `StringName`-keyed Dictionary (E3), and a literal costs the same as a constant (E5), so the risk is a key outside the vocabulary, not speed. L-STAT-1 bans literals for vocabulary and typo safety.
- **R3 Const tables (E1).** If an inner table is writable, switch to `static var` plus `make_read_only()` on each table; no caller changes.
- **R4 A missed `halted()` check** lets a value reach state. Mitigation: ADR-0001 V5; every consumer story uses the recording spy, which fires `fatal` on a chosen read and returns the poison value, then asserts no state change and no emit. The spy helper is ADR-0007's.
- **R5 Weak entity freed early.** `live_entity()` returns null. Nothing reads it at MVP; the Stat ADR treats null as "no instance".

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-008: every modifiable value is read through one stat accessor (read_context, stat_key) at use time, never cached, so Stat & Modifier Resolution can replace its internals with no call-site change | Decisions 1, 5, 8: typed reads over a `ReadContext`; never-cache with the `max_hp` exception; the resolver subclasses `StatAccessor`. The Vertical Slice proof waits for the Stat GDD |
| data-config-pipeline.md | TR-data-010: Data owns the stat-key vocabulary and int/float type per key, and exposes non-fatal `level_count(def_id)` and `is_tower(id)` | Decisions 3, 6: `StatKeys` (`KIND`, `ROWS`, `ROLE_TAG`) in `src/foundation/data/`, V4; lookups never call the handler |
| enemy-wave.md | TR-enemy-006: every enemy stat is read through the accessor at use time with a reused per-enemy read context; Wave and Stage records are read directly and never written | Decision 4: one context per `Enemy`, made at spawn; Guideline 1: Wave and Stage read directly; ADR-0002's snapshot proves no write |
| tower-system.md | TR-tower-003: tower IDs and levels are validated with `is_tower` and `level_count` before any accessor read; cost and stats are read at use time | Decisions 5, 6; Guideline 11: lookups first, then the cost read, then `halted()`; slot `level` follows the commit |
| hero-system.md | TR-hero-005: Hero and Burst stats are read through the accessor at use time; `hero_start`, `pin_rect` and `pin_exclusion` come straight from the Stage record | Decision 4: HeroSim's two contexts; Guideline 1: Stage fields read directly |
| battle-hud.md | TR-hud-011: costs are read through the accessor on arc open and `gold_changed`, and the burst wedge reads Burst cooldown through the accessor at use time with the builder-injected Burst ID; a read that finds `halted()` is abandoned for the Fatal screen | Decisions 5, 7; Guideline 14: arc open and `gold_changed` mark costs dirty and HudLogic reads in frame step 3, never inside a sim signal handler; HudLogic gets `battle.stat_accessor` and `battle.halt_gate.halted` from the wrapper, checks `halted()` and abandons |
| data-config-pipeline.md | Rule 10 bad-call list and the release-build handler (TR-data-009, ADR-0001) | Decision 2: six causes, fixed order, plain branches; handler is the battle latch's `fatal` |

## Performance Implications
- **CPU**: per read, two Dictionary lookups, up to three table lookups, one `Object.get`, an `Array.has` for role keys. 0.75 to 2.25 ms a tick estimated (R1), against 2.0 ms p95 per tick; P1 decides.
- **Memory**: one `ReadContext` per enemy, tower slot, hero, burst, scratch and preview; one `WeakRef` each where an entity is given. No per-read allocation (V7).
- **Load Time**: none.
- **Network**: not applicable.

## Migration Plan
No code exists. Documents to change (not changed here unless stated):
1. `architecture.md`: B0 `ReadContext` row (weak private `_live`, `live_entity()`, `_init` signature, owner table; it now shows a strong public `live_entity`); B1 (`StatKeys` tables, cause codes, constructor); B4 (`stat_accessor` public member); B9 (`stat_accessor` object row: EnemyWave, TowerSim, HeroSim; HudLogic via the wrapper); Module Ownership StatAccessor row; Seams row ("Modifier source tags" becomes grant tags, `grant_kind` and `grant_id`); Required ADRs (shows ADR-0004 Proposed; ADR-0005 now written, Proposed); Document Status.
2. **Due with acceptance:** `design/gdd/data-config-pipeline.md` Rule 10, Edge Cases and AC 7 add the wrong-kind call and the null context as bad calls, and note the return is `0` / `0.0` and still unusable. `design/gdd/battle-hud.md` Rule 7: costs refresh in the view step after arc open or `gold_changed`.
3. ADR-0001: amended in this change (its Amendments section): `stat_accessor` and `halt_gate` are public read-only members; the accessor is injected as an object. architecture.md B4 and B9 follow.

## Validation Criteria
Fixtures are code-built through `Catalogue.from_documents` (ADR-0002); no file I/O. V1's fixture is shared by V7 and P1.
- **V1 `test_reads_return_base_values`** (Data AC 6): every key in each row, every tower level and role, with a live entity and a preview context, returns the fixture value of its kind; `level_count` matches.
- **V2 `test_bad_calls_name_one_cause`** (Data AC 7): one case per Decision 2 row, the null-context string, and a two-fault case that reports the earlier cause. The spy, held in a test variable for the whole test, fires once.
- **V3 `test_lookups_never_fatal`**: `is_tower` on enemy, wave and unknown IDs is false; `level_count` is 0; the spy never fires.
- **V4 `test_stat_keys_match_schema`**: `ROWS` against `schema.gd` both ways; `KIND` covers every `ROWS` key and no key outside them.
- **V5 `test_bad_read_keeps_catalogue_ready`** (Data AC 12): spy held for the whole test; after a bad call a fresh accessor reads the same catalogue.
- **V6 `test_read_context_holds_entity_weakly`** (E4, verified 4.7.2 headless, see probe-results.md): (a) a context made by the test over a `RefCounted` owner; (b) a context made inside the owner's own `_init`, as `Enemy` does. In each, set the test's local to null (never pass the owner to a gdUnit assert first, per ADR-0001's weakref rule); the owner's weakref is dead and `live_entity()` is null. (c) no entity: `_live` is null.
- **V7 `test_reads_allocate_nothing`** (E6, verified 4.7.2 headless, see probe-results.md): after a warm-up pass, 10,000 mixed reads leave `Performance.OBJECT_COUNT` equal and `Performance.MEMORY_STATIC` flat (debug build). It claims only "creates no Object" and flat static memory.
- **E1 `test_const_stringname_tables`**: `is_read_only()` on `ROWS`, each inner table, `KIND` and `ROLE_TAG`. verified 4.7.2 headless, see probe-results.md.
- **E3 `test_object_get_and_string_keys`**: `Object.get(&"damage")` returns the field, an unknown name returns null with no error; records whether `ROWS[&"tower"].get("cost", false)` hits (it does). verified 4.7.2 headless, see probe-results.md.
- **E5 `bench_string_vs_stringname_key`** (optional): cost of a `String` literal key against a constant. Ratio 0.99 for a literal, 1.42 for a `String` variable; verified 4.7.2 headless, see probe-results.md.
- **E7 `test_class_names_free`**: `ClassDB.class_exists()` is false for the three names. verified 4.7.2 headless, see probe-results.md.
- **P1 `bench_stat_reads`** (logged): V1's fixture; warm-up first; 150 reads per simulated tick, each a read plus a `halted()` call, for 600 ticks, timed with `Time.get_ticks_usec()`; reports p95 per tick and µs per read, and records debug or release build. Benches Alternative 7 in the same run. Desktop trigger: above 0.5 µs per read, build the `match` fallback now. Device run at the first phone build against 2.0 ms p95 per tick.
- **Lints (ADR-0007)**: L-STAT-1 no literal key argument; L-STAT-2 no direct read of a `ROWS` field outside `src/foundation/data/`; L-STAT-3 no `assert` in the two files.
- **Consumer stories** (Tower, Hero, HUD, Enemy & Wave): Data's deferred never-cache criterion (a spy changes a value between two uses, the second use shows it), and the poison spy (R4). HUD stories also check that no read runs inside a sim signal handler.

## Reviews
**godot-specialist: CONCERNS. TD-ADR: CONCERNS.** All relayed findings applied except where noted.

| # | Finding | Resolution |
|---|---|---|
| T1 | `gold_changed` fires in the tick | Decision 5, Guideline 14, TR-hud-011 row: mark dirty, read in frame step 3 |
| T2 | Getter vs member | Decision 7: public read-only `stat_accessor`; object, not Callable; HudLogic gets `battle.halt_gate.halted` from the wrapper (`halt_gate` made public); ADR-0001 amended; Alternative 8 |
| T3 | Missed `halted()` invisible | Guideline 3, R4: poison spy (fixture plus 1000); helper to ADR-0007 |
| G1 | V7 overclaims | V7 and E6: no Object created, flat `MEMORY_STATIC` after warm-up |
| G2, T8 | R1 too low | R1 range; P1 spec and desktop trigger; Alternative 7 benched |
| G4 | Wrong budget | 2.0 ms p95 per tick throughout |
| G5, T9 | `_live` | Kept, justified in Decision 4; null when no entity; V6 cases (b), (c) and ADR-0001's weakref rule |
| G6, T5 | One vocabulary table | `KIND` added; `ROWS` holds key sets; causes 3 and 5 use `KIND`; V4 checks both; `get(key, default)` |
| G7 | Typed tables? | Untyped, reasons in Decision 3; typed locals |
| G1-E1 | E1 scope | E1 checks all four tables and each inner one; R3 fallback |
| G-E3 | Null from `Object.get` | Defensive branch, cause 4 |
| G-E5, T10 | L-STAT-1 reason | Vocabulary first; E2 folded into E3; E5 optional |
| G8 | Class names | E7; `StatKeys` is `@abstract`, `StatAccessor` is not |
| G10 | Spy overrides | Guideline 17 |
| G12 | Spy lifetime | V2, V5 |
| T4 | Seam type | Decision 8: `StatAccessor` subclass; Consequences note on scratch and preview contexts |
| T6 | Sync, cause string, signature | Migration 2 due with acceptance; Decision 2 null string; Decision 4 matches Key Interfaces |
| T7 | `RANGE`, upgrade chip | Decision 5 and diagram |
| T10 | Restated guidelines | Guidelines 3 and 10 cite ADR-0001 Guidelines 9 and 10 |
| T11 | Stale architecture.md | Migration 1 |

## Related
- Depends on ADR-0001 (amended 2026-11-04 with this ADR), ADR-0002, ADR-0004
- Enables ADR-0007, ADR-0009, ADR-0010
- `architecture.md` v4: Seams, Module Ownership (StatAccessor), B0, B1, B1a, B4, B9, B10
- GDDs: `data-config-pipeline.md` (stat-key table, Rules 10, 11, Edge Cases, AC 6, 7, 12), `enemy-wave.md` (Rules 9 to 11, 13), `tower-system.md` (Rules 5, 9, 12), `hero-system.md` (Rule 8), `battle-hud.md` (Rules 7, 12)

## Amendments
- **2026-11-04, from verified engine probes** (docs/engine-reference/godot/probe-results.md; Status stays Accepted). E5 is corrected: a `String` literal key costs the same as a `StringName` constant (ratio 0.99); a `String` variable costs 1.42x. Decision 3 and R2 drop the cost reason, so L-STAT-1 rests on the vocabulary and typo safety only. Decision 3 and Key Interfaces now say `@abstract` makes `StatKeys` impossible to construct by name; `load(path).new()` still builds one, which needs no lint at MVP. Engine Compatibility and the E rows, V6 and V7 are marked verified.
- **2026-11-05, with ADR-0010 (confirmed by the user at ADR-0010 acceptance); Status stays Accepted.** Decision 5 gains a read site: in frame step 1, by HeroInput, between ticks, only in the Cancelling and Live aim states, Burst `reach`, `radius`, `damage`, and Combat `hp_left`, `is_dead`, each followed by `halted()`. HeroInput owns one context (Decision 4 table), and `hero_input.gd` joins L-STAT-4's owner list (ADR-0007). The command bullet now names the `pin` and `burst` reads. Nothing else in this ADR changes.
