# ADR-0005: Stat Accessor and Read-Context Contract

## Status
Accepted (2026-11-05, on the owner's instruction after architecture-review-2026-11-05b and fix round 2; the Verification Required items and device runs stay open and are tracked by their stories)

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer. Reviewed once each on 2026-11-05 by godot-specialist (1 blocking, 8 minor, with desktop probes 5 to 8 on 4.7.2) and technical-director under gate TD-ADR (CONCERNS: 2 blocking, 12 advisory); all findings were applied in this revision. No second review pass has been run.

## Summary
Every modifiable number (damage, range, cost, bounty, leash radius) must be read at use time through one seam that a later Stat & Modifier resolver can replace without touching a call site, and a bad read must reach the fatal path in a release build instead of returning a silent garbage number. This ADR fixes that seam: one `StatAccessor` per battle with two typed reads, `stat_int(ctx, key)` and `stat_float(ctx, key)`, a reusable `ReadContext` (`def_id`, 1-based `level` or 0, a weak live-entity reference), a `StatKeys` vocabulary class that owns the key names and their int/float types and is tied to ADR-0002's schema by a test, two non-fatal lookups (`is_tower`, `level_count`), and a never-cache rule with one exception (`max_hp` at spawn), with `ReadContext` and `StatKeys` under `src/data/` and `StatAccessor` under `src/battle/`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; installed 4.7.2.stable.official) |
| **Domain** | Core (data access) |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW. Plain GDScript: `RefCounted`, `StringName`, `Callable`, `const` dictionaries, `match`, `WeakRef`. None appears in `breaking-changes.md` or `deprecated-apis.md` except the 4.7 typed-return break below. The facts that the local reference does not cover rest on desktop probes run for this ADR (table below), not on the reference. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (line 17, typed-return overrides), `deprecated-apis.md`, `current-best-practices.md` (GDScript 4.5+ and 4.7 sections: lambdas, `@abstract`, typed-return override). The live 4.7 class reference was **not** consulted. |
| **Post-Cutoff APIs Used** | None. The 4.7 rule applies to this ADR's test doubles: a subclass that overrides `stat_int` or `stat_float` (typed return) needs an explicit `return` in every override. No `@abstract` class is used (4.5); `StatAccessor` is a concrete, subclassable class. |
| **Verification Required** | (1) NOT SOURCEABLE until the first phone build: per-read cost on the Adreno 5xx-class device; record the median time of `stat_float(ctx, StatKeys.RANGE)` over 100,000 reads in a loop against the proposed ceiling in Performance Implications (Validation Criterion 11). (2) NOT SOURCEABLE until the first phone build: `weakref()` of a `RefCounted` entity releases it when its last strong reference goes, on an Android **release** export; the entity-context probe runs inside ADR-0001's Android release run (Validation Criterion 14). (3) The parse check passes on the three accessor files, including the `const` dictionary keyed by another class's constant (Validation Criterion 15). |

Probe results on the installed 4.7.2 binary (headless, debug build, 2026-11-05; sources and README in `prototypes/adr-0005-spike/`; probes 5 to 8 were run by the engine reviewer), which this decision relies on:

| Behaviour | Observed |
|---|---|
| `ClassDB.class_exists` for `StatAccessor`, `ReadContext`, `StatKeys`, `SpyStatAccessor`, `SpyFatal` | All false: no collision with a native class (QQ-16). Addon classes are not covered; ADR-0007's collision lint is. |
| A `RefCounted` entity that owns a context which holds only a `WeakRef` to it, both strong references dropped | Entity and context both released (`get_ref() == null` for both). No cycle. |
| Subclass instance held in a base-typed variable, overriding a typed-return method with an explicit `return` | The override runs (`7.0`, not the base's `1.0`). A spy accessor can stand where `StatAccessor` is typed. |
| Subclass with no `_init` of its own, parent `_init(x, cb)` takes arguments | `Sub.new(4, cb)` works; the parent's `_init` receives them. A subclass that defines `_init` and forwards with `super(x, cb)` also works. |
| Method Callable on a plain `RefCounted` recorder, `.call("x")` | The recorder's method ran and recorded the argument. A spy failure handler needs no lambda. |
| `const` dictionary of `StringName` keys to `TYPE_INT` / `TYPE_FLOAT`; lookup by `StringName`; lookup with a plain `String`; `is_read_only()` on it and on the nested per-kind dictionary | Both lookups find the key (agrees with ADR-0002's key probe). Both dictionaries are read-only (probe5), which supports calling the table constant. |
| `match` on a `StringName` against named `const` patterns; the same `match` with `StringName(s)` and with a raw `String` | All three select the same arm. A `String` argument is converted at the call because the parameter is typed `key: StringName` (probe5: `stat_float(ctx, "range")` returned the value), so the accessor's `match` never sees a `String`. |
| `match` against a constant on another class (`StatKeys.COST`) as the pattern | Selects the right arm (probe8). This is the form the accessor uses. |
| `const` dictionary whose key is another class's constant (`CatX.KIND_TOWER`) | Parses and reads. |
| 100,000 `stat_float(ctx, RANGE)` calls implemented as Decision 2 describes (index lookup, level check, `TYPES[kind].has(key)`, role-tag check, type check, `match`, typed field read), desktop debug binary (probe5) | 60.6 ms in total, about 0.6 microsecond per read, against a 2.1 ms loop-and-property baseline. A bare 100,000 `Dictionary` reads loop took about 3 ms (probe.gd), so the cost is the GDScript call and the checks, not the lookup. Not a phone figure. |
| `weakref(null)` | Returns a `WeakRef` whose `get_ref()` is `null` (probe5). |
| Subclass `_init()` that does not call `super()` while the parent `_init` has required arguments | Compiles and runs; the parent body is skipped (probe6). |
| Override of a typed-return method written without a return type and with a path that has no `return` | Parse error "Not all code paths return a value" (probe7): the 4.7 break is caught by the parse check when every override declares its return type. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): `build()` constructs the one accessor and `Battle` holds it; the fatal route and the `halted()` rule. ADR-0002 (Accepted; must be Accepted before this ADR is Accepted): the record classes, `StringName` IDs, the schema as the single source of int/float types, `Catalogue` lookups, `is_tower()` and `level_count()`. |
| **Enables** | ADR-0009 (Enemy & Wave read enemy stats through this contract and hold a `ReadContext` per enemy), ADR-0010 (TowerSim, HeroSim and HudLogic read through it), ADR-0007 (the spy accessor and spy failure handler are test doubles of this contract). |
| **Delegates To** | ADR-0001: where `Battle` holds the accessor and which `fatal` Callable `build()` injects (already decided there; restated). ADR-0002: the record classes, the schema and the field-type lookup the tie test calls. ADR-0006: ratifies in the Flow signal contract that `Flow.phase()` returns `FATAL` whenever the battle's `FatalLatch.is_set` is true (Decision 3), and owns commit-before-emit. ADR-0007: the test harness, where the fixture factory and the spy classes live, and the string-literal-key lint (the accessor under `src/battle/` is already covered by ADR-0001's lint set). ADR-0009: `Targetable` and the `Enemy` type (this ADR types `live_entity` loosely; ADR-0009 may narrow the documentation, not the weakness), when an enemy's context is created and the one `max_hp` seeding call. ADR-0010: the `HALTED` command results, and whether Tower and Hero instances are objects a context can reference. A future Stat GDD and ADR (Vertical Slice): the modifier resolver behind the same two methods. |
| **Blocks** | The stat accessor story (Data & Config) and every consumer story that reads a stat: Tower, Hero, Enemy & Wave, Battle HUD. No stories exist yet. |
| **Ordering Note** | ADR-0002 must be Accepted first because the tie test (Validation Criterion 6) reads `CatalogueSchema.FIELDS` and `CatalogueSchema.ROLE_FIELD_TAG`, whose shape ADR-0002's Key Interfaces now names. ADR-0006 must carry the `Flow.phase()` requirement before this ADR is Accepted. ADR-0007 does not prefix class names (QQ-16): Decision 9 uses a collision lint and a reserved-name list, so the names here stand. |

## Context

### Problem Statement
The Data & Config GDD requires that every modifiable number is read through one accessor, with a read context and a stat key, at use time and never cached, so that the Vertical Slice Stat & Modifier resolver can replace the accessor's internals with no call-site change (Rules 10 and 11, TR-data-008). A bad call must reach an injected failure handler that survives release builds. GDScript has no exceptions and typed GDScript cannot express "a number or nothing", so a bad read finishes on some value and every caller has to know not to use it (ADR-0001 Decision 6 and 8). Five consumer systems (Tower, Hero, Enemy & Wave, Battle HUD, and later the resolver) read hundreds of times per tick, so the contract must also allocate nothing per read. ADR-0001 fixed that `build()` constructs the one accessor; ADR-0002 delegated the caller-facing lookups, the context, the key types and the bad-call handling here.

### Constraints
- GDScript has no exceptions; a failing function returns a garbage value of its declared type, so the accessor can only report through the injected `fatal` Callable and the caller must check `halted()` (ADR-0001 Decision 6).
- `assert()` is banned in `src/` (ADR-0001 Decision 8): it does not survive a release build.
- No lambda, `bind()`, `bindv()` or `static var` in gameplay code, and no `RefCounted` back-reference (ADR-0001 Decision 5, probe table). A strong reference from a per-entity object back to its entity is such a cycle.
- `src/data/` imports none of `src/battle/`, `src/presentation/`, `src/app/`; the other three may import `src/data/` (ADR-0002 Decision 2). `src/battle/` classes extend `RefCounted` and obey ADR-0001's ban set.
- About 400 range checks per tick against a proposed 2 ms (QQ-11): about 5 microseconds per check for everything the check does. `TowerSim` reads `range` once per tower per tick (Decision 7), so accessor reads per tick are about towers plus live enemies, not 400. Unmeasured on a phone.
- The int/float type of a field is declared once, in ADR-0002's schema (ADR-0002 Decision 8); this ADR may not become a second source of truth.
- Every JSON number arrives as float; the builder has already converted integer fields to `int`, so the accessor never converts (ADR-0002 Decision 1).
- Solo developer, workflow `full`: the contract must be checkable by tests and a lint, not by discipline alone.

### Requirements
- TR-data-008: every modifiable value is read through one accessor at use time, never cached, so the resolver can replace its internals with no call-site change.
- TR-data-010: Data owns the stat-key vocabulary and the int/float type per key and exposes non-fatal `level_count(def_id)` and `is_tower(id)`.
- TR-enemy-006: every enemy stat is read through the accessor at use time with a reused per-enemy read context; Wave and Stage records are read directly and never written.
- TR-tower-003: tower IDs and levels are validated with `is_tower` and `level_count` before any accessor read; cost and stats are read at use time.
- TR-hero-005: Hero and Burst stats are read through the accessor at use time; `hero_start`, `pin_rect` and `pin_exclusion` come from the Stage record.
- TR-hud-011: costs are read through the accessor on arc open and `gold_changed`; a read that finds `phase()` Fatal is abandoned for the Fatal screen (`halted()` is not the test, it is also true on Won and Lost).

## Decision

**1. The class, its owner and its directory.** `StatAccessor extends RefCounted` is a concrete class (no `@abstract`), constructed once per battle by `BattleBuilder.build()` as `StatAccessor.new(catalogue, fatal_latch.fatal)` and held by `Battle` in a typed field (ADR-0001 Decision 3). It holds the `Catalogue` and the `fatal` Callable, a method Callable on the per-battle `FatalLatch` (ADR-0001 Decision 5), which is never guarded with `is_valid()`: a missing injection fails in the first test. It holds no `Battle`, no sim and no context. Neither the catalogue nor the latch holds the accessor, so the object graph has no cycle. At MVP `build()` constructs `StatAccessor` unconditionally; how a later resolver class is chosen is the Stat ADR's (Decision 8). At construction the accessor indexes the four stat-bearing kinds into one private `Dictionary` from `StringName` ID to record (`Catalogue.ids(kind)` then `tower(id)`, `enemy(id)`, `burst(id)`, and `hero()` for the one Hero record), so a read resolves its record with one lookup, the Hero needs no special case, and the record class (`is TowerRecord`) gives the kind. This is structure, not a stat value; records are live and read-only after load.

`stat_accessor.gd` lives in **`src/battle/`**; `read_context.gd` and `stat_keys.gd` live in **`src/data/`**. The accessor is a battle-lifetime object by ADR-0001 Decision 10's definition: it holds the battle latch's method Callable and the retry weakref test names it, so ADR-0001's `src/battle/` bans (`func(`, `func (`, `.bind(`, `bindv(`, `static var`, plus `assert(`, `Engine.`, `Time.`, `OS.`, and `Node`) cover it with no lint extension, and so does the Vertical Slice resolver subclass, which also lives in `src/battle/` (it casts `live_entity.get_ref()` to ADR-0009's entity types). `ReadContext` and `StatKeys` hold no Callable and no battle reference (a context holds only a `WeakRef`), so ADR-0002's rules for `src/data/` (`RefCounted`, no `Node`, no `static var`, no `assert()`) are enough, and the tie test sits beside the schema in `tests/unit/data/`. This departs from architecture Module Ownership, which lists StatAccessor under Data & Config beside the Catalogue; the layer map names a layer, not a folder, and a per-battle object that holds the fatal route belongs with `Battle`'s helpers. `HudLogic` is injected with the accessor as a typed `StatAccessor` field; no architecture rule bars presentation from reading sim types (it already reads `Flow.phase()`), and `HudLogic` never constructs one.

**2. The two reads.** The whole read contract is two methods:
- `stat_int(ctx: ReadContext, key: StringName) -> int`
- `stat_float(ctx: ReadContext, key: StringName) -> float`

The key's declared type must match the call: `stat_int` on a float key, or the reverse, is a bad call. Every read does the same checks in this order, and the first failure is the one reported (so one fault gives one `fatal` call). A good read does one `has()` on its kind's key table:
1. `ctx.def_id` resolves, through the index, to a tower, enemy, hero or burst record; otherwise `unresolved_def_id`. A `def_id` naming a wave, stage or input record is unresolved here: those have no stat rows.
2. The level matches the record: a tower needs `1 <= ctx.level <= level_count`, otherwise `level_out_of_range`; any other kind needs `ctx.level == 0`, otherwise `level_on_levelless_record`.
3. `StatKeys.TYPES[kind].has(key)`. Only on a miss is the fault decided (slow path, may scan every kind's table): the key belongs to another kind, `inapplicable_key`; it belongs to none, `unknown_key`.
4. A role key (`splash_radius`, `slow_strength`, `slow_duration`, the keys of `StatKeys.ROLE_TAG`) needs the matching role tag (`splash`, `slow`) on the tower, otherwise `role_key_without_tag`. The tag set is read from the `TowerRecord`.
5. The kind's declared type for the key matches the call, otherwise `wrong_type_call`.

Then the value is read by an explicit per-kind `match` on the key that returns a typed record field (`rec.cost`, `rec.levels[ctx.level - 1].range_units`, and so on), one statement per key, no reflection. A new key is one `StatKeys` row, one `match` arm and the schema entry; the per-key read test fails if any is missing. The `match` is split into four per-kind private methods so none exceeds the complexity limit. A read allocates nothing: one index lookup, one `has()`, a tag check for role keys only, one `match` and one typed field read.

**3. The bad-call contract.** A bad call calls `fatal(cause)` exactly once and returns `0` or `0.0`. Those values exist only because the signature is typed; the contract is that the returned value is **unspecified and no caller may use it**, as the GDD says (Rule 10). The architecture's B1 sketch says "returns 0 or 0.0 and the caller checks `halted()`"; this ADR follows the GDD's stronger wording, and B1's Invariants line is updated at `/architecture-review`. The cause is one line in a pinned format: `stat read failed: <call>(def_id '<id>', key '<key>', level <n>): <prose> [<code>]`, for example

`stat read failed: stat_float(def_id 'arrow', key 'splash_radius', level 2): the tower has no splash tag [role_key_without_tag]`

`<call>` is `stat_int` or `stat_float`. `<code>` is one of seven `StringName` constants on `StatAccessor` (`FAULT_UNRESOLVED_DEF_ID`, `FAULT_LEVEL_OUT_OF_RANGE`, `FAULT_LEVEL_ON_LEVELLESS_RECORD`, `FAULT_UNKNOWN_KEY`, `FAULT_INAPPLICABLE_KEY`, `FAULT_ROLE_KEY_WITHOUT_TAG`, `FAULT_WRONG_TYPE_CALL`). Tests assert `cause.ends_with(" [%s]" % code)` and that the cause contains the exact segment `(def_id '%s', key '%s', level %d)`, never the prose and never a loose substring. After `fatal` returns, the accessor does nothing else: it does not touch the catalogue state (criterion 12), does not retain the context and does not latch anything itself. A second bad call after the latch is set calls `fatal` again; the latch is idempotent and keeps the first cause (ADR-0001 Decision 6), and callers have already stopped by checking `halted()`.

The caller's side is ADR-0001's rule: after any accessor read, check `halted()` before using the value; on true, return at once. The one exception is Battle HUD (TR-hud-011), which tests `phase() == FATAL` instead, because `halted()` is also true on Won and Lost, and a result screen must keep reading costs. ADR-0001 says Flow "commits FATAL" after the latch sets but not when, and a bad read on arc open or inside a `gold_changed` handler happens between ticks. This ADR therefore requires of Flow that `phase()` returns `FATAL` whenever the battle's `FatalLatch.is_set` is true, as a derived read, not only after a committed transition at the next tick gate. ADR-0006 ratifies that in the Flow signal contract (Delegates To), and Validation Criterion 12 tests it on the line after the read, with no tick between. The HUD abandons the read and the snapshot for the Fatal screen.

**4. Key vocabulary and types.** `StatKeys extends RefCounted` in `src/data/stat_keys.gd` is the one place key names exist. It holds one `StringName` constant per key (`COST`, `DAMAGE`, `RANGE`, `ATTACK_INTERVAL`, `SPLASH_RADIUS`, `SLOW_STRENGTH`, `SLOW_DURATION`, `MAX_HP`, `MOVE_SPEED`, `BOUNTY`, `LIVES_COST`, `LEASH_RADIUS`, `WALK_SPEED`, `RADIUS`, `REACH`, `COOLDOWN`, `TELEGRAPH_DURATION`), the per-kind table of `key -> TYPE_INT | TYPE_FLOAT` (the GDD's MVP stat-key table, which Data owns by Rule 11) and the role-key table (`SPLASH_RADIUS -> &"splash"`, `SLOW_STRENGTH` and `SLOW_DURATION -> &"slow"`). Callers write `StatKeys.RANGE`, never `&"range"`; ADR-0007's lint greps `src/` outside `src/data/` for a `stat_int(` or `stat_float(` call whose second argument is a string literal. The JSON key and the stat key are both `range`; the record field is `range_units` (ADR-0002 Decision 3), and the accessor's tower arm is the only place that mapping is written.

The MVP table, which is the GDD's, with one row per record kind:

| Kind | Int keys | Float keys |
|---|---|---|
| tower (per level) | `cost` | `damage`, `range`, `attack_interval`, `splash_radius`*, `slow_strength`*, `slow_duration`* |
| enemy | `bounty`, `lives_cost` | `max_hp`, `move_speed` |
| hero | none | `damage`, `attack_interval`, `leash_radius`, `walk_speed` |
| burst | none | `damage`, `radius`, `reach`, `cooldown`, `telegraph_duration` |

\* role key: applicable only to a tower holding that role's tag.

**The tie test (ADR-0002 Validation Criterion 22).** The schema is the single source of truth for int versus float; `StatKeys` mirrors it and a test forces agreement, so the two cannot drift. The unit test in `tests/unit/data/` walks every `(kind, key, type)` row of `StatKeys` and asserts that `CatalogueSchema.FIELDS` declares that field (the schema names fields by JSON key, so the stat key `range` is the schema field `range`; `range_units` is the record field and appears only in the accessor's arm), on that record type (`&"tower_level"` for tower keys), with the same int or float type; it then walks every numeric field of the tower level, enemy, hero and burst entries in `FIELDS` and asserts it appears in `StatKeys`. At MVP every numeric field of those four records is a stat key (`visual_key`, `tags`, `rationale` and the IDs are not numeric), so the second walk is an exact-equality check with no allowlist; the first field that is not a stat key adds a named exclusion to the test and an ADR amendment. The test also asserts that the kind keys of `StatKeys` equal `Catalogue.KIND_TOWER` and its siblings, and that `StatKeys.ROLE_TAG` equals `CatalogueSchema.ROLE_FIELD_TAG`. The type column is therefore a second declaration held in line by the test, which ADR-0002 Decision 8 now says in the same words; a later revision may derive it once at accessor construction (Alternative 6).

**5. ReadContext.** `ReadContext extends RefCounted` in `src/data/read_context.gd`:
- `def_id: StringName`: always set.
- `level: int`: **0 means none**; tower levels are 1-based (the Tower GDD's level 1 and 2; the arc reads level 1 and the chip reads `level + 1` below `level_count`). 0 is the architecture's default (B0), and a negative level is simply out of range, so there is no second "none" value.
- `live_entity: WeakRef`: always set, never null. `_init` does `live_entity = weakref(p_entity)`; `weakref(null)` is a `WeakRef` whose `get_ref()` returns `null` (probe5), so a preview context needs no branch and the resolver's one `get_ref()` null check is the whole contract. It is a `WeakRef` to an `Object`, not a typed `Targetable`, because (a) `Targetable` belongs to ADR-0009 and the context lives in `src/data/`, which must not import `src/battle/`, and (b) a strong reference from the context to its entity is a cycle: `Enemy` owns its context (Enemy & Wave Rule 9) and the context pointing back at the `Enemy` is exactly ADR-0001's forbidden `RefCounted` back-reference. The 4.7.2 probe shows entity and context are both released when only a `WeakRef` points back. The MVP accessor never reads `live_entity`; the Vertical Slice resolver calls `get_ref()` and checks for `null`. The cost is one `WeakRef` allocation per entity at its creation, never per read. ADR-0009 types the entity and may document the cast; it may not make the field strong.
- `_init(p_def_id: StringName, p_level: int = 0, p_entity: Object = null) -> void`.

**Reuse rule: one context per caller, never per read, never shared.** The owner of a thing that is read creates one context when the thing comes to exist and keeps it. What each owner creates, and what it passes as `live_entity` at MVP (so the Vertical Slice "towers near the hero" buff changes no constructor call):
- `EnemyWave`: one per enemy at spawn; the entity is the `Enemy`.
- `TowerSim`: (1) one context per built tower; the entity is the tower's `Tower` object (settled by ADR-0010: Tower and Hero are objects). Its `level` is written only inside the commit of a build or upgrade, after the gold debit and before any emit: debit, write `level`, emit `gold_changed`, emit `tower_upgraded` (commit-before-emit, owned by ADR-0006). (2) One reused **command context** for command-time cost reads: `def_id` is the requested tower, `level` is 1 for `build` and the tower's level + 1 for `upgrade`, written by `TowerSim` only, `live_entity` wraps `null`. A refused command (`NO_GOLD`, `HALTED`) therefore leaves the built tower's context, and so its damage and range reads, unchanged; setting the built tower's own `level` to L+1 to read a cost is forbidden.
- `HeroSim`: two; the hero object for the Hero context, `null` for the Burst context: the Burst has no object at MVP (settled by ADR-0010; a recorded Vertical Slice touch-point).
- `HudLogic`: one preview context for the cost chip, arc and range rings, and one for the Burst `cooldown`; `def_id` and `level` are assigned before each read and `live_entity` wraps `null` (a HUD cost preview has no entity, GDD Rule 10).

Because the accessor never retains a context past the call, mutating one between reads is safe; two callers sharing one context is not allowed. A new context per read is rejected on allocation grounds (Alternative 4). A context holds `def_id` and `level`, never a stat value.

**6. Non-fatal lookups.** The accessor exposes the two lookups B1 lists and no others:
- `is_tower(id: StringName) -> bool`: delegates to `Catalogue.is_tower()`; false for an unknown ID, an ID of any other record type, an empty ID, and when the catalogue is not Ready.
- `level_count(def_id: StringName) -> int`: delegates to `Catalogue.level_count()`; 0 for a non-tower or an unknown ID.

Neither calls `fatal`, neither allocates. They are the guard commands run before trusting an ID or level: `TowerSim.build()` checks `is_tower` and refuses `BAD_TOWER`; `build` and `upgrade` check `level_count` so a last-level upgrade is a `MAX_LEVEL` refusal, not a Fatal (Tower GDD Rule on reading level stats). The HUD checks `level_count` before previewing `level + 1`. A command that skips the check and reaches the accessor with a bad ID or level gets the fatal path, which is correct for a defect.

**Direct `Catalogue` lookups** (`stage`, `wave`, `hero`, `input`, `tower`, `enemy`, `burst`) are for structural data only: Stage fields, Wave records and their groups, the Input record, a tower's tags (HUD role tags, injected by the wrapper). Stat values are never read off a record directly. A null from a direct lookup is a defect (validation guarantees every reference resolves), so the caller, not the catalogue, calls `fatal(cause)` and returns; `build()` does this for the stage and each `wave_ids` entry (ADR-0001 Decision 3). `Catalogue` itself never calls `fatal` (ADR-0002).

**7. Never cache.** A consumer reads a stat at the moment it uses the value and never stores the number for later use: no field, no local across ticks, no value computed once at spawn or build, no value captured when the arc or chip opened. Contexts are stored; values are not. The Enemy & Wave per-tick reads of `move_speed`, `bounty` and `lives_cost` are reads at use time. There is **one exception, `max_hp`**: Enemy & Wave reads `stat_float(ctx, StatKeys.MAX_HP)` once at spawn, seeds `Health` with it, and nothing re-reads it (Combat Rule 9, Enemy & Wave). A resolver modifier to `max_hp` therefore takes effect at the next spawn only, which the Stat GDD must account for. A local inside one tick step is not a cache: `TowerSim` **must** read `range` once per tower per tick into a tick-local and use it for every candidate enemy, so reads per tick are about towers plus live enemies, not tower-enemy pairs. Any further exception needs an amendment to this ADR and to the Data GDD Rule 10. The rule is not mechanically lintable (a stored number is just a field); it is held by the consumer-story test below and by code review, and the exception is pinned by its own test.

**8. The Vertical Slice seam.** The accessor is the seam, and `live_entity` is why the seam is wide enough. The resolver arrives as a subclass of `StatAccessor` in `src/battle/` that overrides `stat_int` and `stat_float`: it calls `super.stat_*()` for the base value, then applies the modifiers selected by the record's tags and, when it needs instance or position, by `ctx.live_entity.get_ref()`. At MVP `build()` constructs `StatAccessor` unconditionally; the Stat ADR decides how the resolver class is chosen (preferably an unconditional swap of the constructed class, which needs no branch). `Battle`'s field stays typed `StatAccessor`, so no call site, context owner or test double changes. The resolver must be a pure function of the catalogue, the context and its modifier state, must not store results across calls (it would break Decision 7), must not call `fatal` again for a base bad call, and must not fault (for example by dividing) on the base's `0`. The Stat GDD and its ADR decide the modifier order and data; this ADR fixes only that the two methods, the context and the vocabulary are the whole interface.

**9. Test contract.** All of these run headless with no file I/O, in `tests/unit/data/` (the harness and the fixture factory's location are ADR-0007's):
- **Spy failure handler:** `class SpyFatal extends RefCounted` with `causes: Array[String]` and `fatal(p_cause: String) -> void` appending. Tests inject `spy.fatal`, a method Callable (lambdas are banned and the probe shows this works), and hold `spy` in a local for the test's lifetime. It is distinct from ADR-0001's `FatalLatch`, which a battle-level test uses.
- **Fixture catalogues:** built in code from the factory through ADR-0002's `load_parsed()`, so the fixtures run through the real validator. Values differ per level and per record (Data criterion 6), so a wrong-level or wrong-record read cannot pass by accident. Expected values come from the raw fixture dictionary, not from the record fields the accessor reads.
- **Spy accessor:** `class SpyStatAccessor extends StatAccessor` overrides both reads, logs `(def_id, key, level)` per call, returns from a settable table, and lets a test change a value between two reads. It is built with the fixture catalogue and a `SpyFatal` method Callable through the inherited constructor (probe; a subclass `_init()` that skips `super()` leaves the base index unbuilt and `is_tower` dereferencing a null catalogue, probe6), or it overrides all four public methods. Every override of `stat_int`, `stat_float`, `is_tower` and `level_count` declares its return type and has an explicit `return` (4.7; without the declared type the parse check fails, probe7). Each consumer story (Tower, Hero, Battle HUD, Enemy & Wave) uses it for the never-cache criterion: read, change the spy value, trigger the second use, assert the second use reflects the change; and Enemy & Wave also asserts `max_hp` is read once and a later change does not move `Health`.
- **Per-key read table (GDD criterion 6):** for every record and, for towers, every level, every applicable key (role keys only with their tag), with a live-entity context and with a preview context, the value equals the fixture's expected value and has the declared type; `level_count` matches each record; the spy handler is never called.
- **Bad-call table (GDD criterion 7):** one row per fault: an unknown key; an enemy key on a tower and a tower key on a hero (inapplicable); `splash_radius` on a `slow` tower and on a `single` tower (role key without tag); level 0, -1 and `level_count + 1` on a tower; a level on an enemy, a hero and a burst; an unknown `def_id`, a wave ID, a stage ID and an empty ID; `stat_int` on a float key and `stat_float` on an int key. Each row builds a fresh accessor and spy and asserts exactly one cause, containing the `def_id`, the key, the level and the row's fault code. The return value is never asserted.
- **Catalogue stays Ready (GDD criterion 12):** after a bad call, `catalogue.state()` is `READY`, `snapshot_diff` against the snapshot taken before is empty, and a following valid read returns the right value.
- **Lookups:** `is_tower` and `level_count` on a tower, an enemy, an unknown and an empty ID, and on a non-Ready catalogue, with the spy never called.
- **Refused upgrade (TR-tower-003):** an `upgrade` refused with `NO_GOLD`, and one refused with `HALTED` from a spy that latches on the cost read, leaves the built tower's context `level` unchanged, and the next `damage` read returns level 1's value.
- **Phase on Fatal (TR-hud-011):** a spy accessor that latches the battle's `FatalLatch` on a HUD cost read, then `phase() == FATAL` on the very next line with no tick between.
- **No retention:** a weakref to a context passed to a read is null once the caller drops it.
- **Side by side (GDD criterion 8):** two accessors over two fixtures with different values return their own values.

### Architecture Diagram

```
AppRoot ── Catalogue (Ready, session) ──────────────┐
BattleBuilder.build()                               │ read-only, live records
   │ StatAccessor.new(catalogue, fatal_latch.fatal) │
   ▼                                                ▼
Battle.accessor ─────────────► StatAccessor ──► Catalogue.tower/enemy/hero/burst
   ▲  (typed field)             │  _records: {id -> record}   (built at construction)
   │                            │  stat_int / stat_float / is_tower / level_count
   │                            └─ bad call ─► fatal(cause) ─► FatalLatch ─► AppRoot.fatal
   │                                                            (callers then return, check halted())
   │ reads at use time, one ReadContext per caller, never cached
   ├── EnemyWave : ctx per enemy   (move_speed, bounty, lives_cost; max_hp once at spawn)
   ├── TowerSim  : ctx per tower + one command ctx (cost at level 1 / L+1); range read once per tower per tick
   ├── HeroSim   : ctx hero + ctx burst
   └── HudLogic  : preview ctx (cost chip/arc, live_entity wraps null) + burst ctx (cooldown)

ReadContext { def_id, level (0 = none, towers 1..N), live_entity: WeakRef (weakref(null) for a preview) }
   src/battle/stat_accessor.gd    src/data/read_context.gd  src/data/stat_keys.gd
Vertical Slice: ResolvingStatAccessor extends StatAccessor in src/battle/ (super + modifiers via ctx.live_entity)
```

### Key Interfaces

```gdscript
class_name StatKeys extends RefCounted
const COST := &"cost"                     # int, tower level
const DAMAGE := &"damage"                 # float, tower level / hero / burst
const RANGE := &"range"                   # float, tower level (record field: range_units)
const ATTACK_INTERVAL := &"attack_interval"   # float, tower level / hero
const SPLASH_RADIUS := &"splash_radius"   # float, tower with the splash tag
const SLOW_STRENGTH := &"slow_strength"   # float, tower with the slow tag
const SLOW_DURATION := &"slow_duration"   # float, tower with the slow tag
const MAX_HP := &"max_hp"                 # float, enemy; read once at spawn
const MOVE_SPEED := &"move_speed"         # float, enemy
const BOUNTY := &"bounty"                 # int, enemy
const LIVES_COST := &"lives_cost"         # int, enemy
const LEASH_RADIUS := &"leash_radius"     # float, hero
const WALK_SPEED := &"walk_speed"         # float, hero
const RADIUS := &"radius"                 # float, burst
const REACH := &"reach"                   # float, burst
const COOLDOWN := &"cooldown"             # float, burst
const TELEGRAPH_DURATION := &"telegraph_duration"   # float, burst
const TYPES := {                          # kind -> key -> TYPE_INT | TYPE_FLOAT; mirrors the schema, tied by a test
	Catalogue.KIND_TOWER: {COST: TYPE_INT, DAMAGE: TYPE_FLOAT, RANGE: TYPE_FLOAT, ATTACK_INTERVAL: TYPE_FLOAT,
		SPLASH_RADIUS: TYPE_FLOAT, SLOW_STRENGTH: TYPE_FLOAT, SLOW_DURATION: TYPE_FLOAT},
	Catalogue.KIND_ENEMY: {MAX_HP: TYPE_FLOAT, MOVE_SPEED: TYPE_FLOAT, BOUNTY: TYPE_INT, LIVES_COST: TYPE_INT},
	Catalogue.KIND_HERO: {DAMAGE: TYPE_FLOAT, ATTACK_INTERVAL: TYPE_FLOAT, LEASH_RADIUS: TYPE_FLOAT, WALK_SPEED: TYPE_FLOAT},
	Catalogue.KIND_BURST: {DAMAGE: TYPE_FLOAT, RADIUS: TYPE_FLOAT, REACH: TYPE_FLOAT, COOLDOWN: TYPE_FLOAT,
		TELEGRAPH_DURATION: TYPE_FLOAT},
}
const ROLE_TAG := {SPLASH_RADIUS: &"splash", SLOW_STRENGTH: &"slow", SLOW_DURATION: &"slow"}   # key -> required tower tag

class_name ReadContext extends RefCounted
var def_id: StringName
var level: int                            ## 0 = none (every non-tower; a tower needs 1..level_count)
var live_entity: WeakRef                  ## Always set; weakref(null) for a preview. Never strong: the owner of the context is the entity.
func _init(p_def_id: StringName, p_level: int = 0, p_entity: Object = null) -> void   ## live_entity = weakref(p_entity).

class_name StatAccessor extends RefCounted
const FAULT_UNRESOLVED_DEF_ID := &"unresolved_def_id"
const FAULT_LEVEL_OUT_OF_RANGE := &"level_out_of_range"
const FAULT_LEVEL_ON_LEVELLESS_RECORD := &"level_on_levelless_record"
const FAULT_UNKNOWN_KEY := &"unknown_key"
const FAULT_INAPPLICABLE_KEY := &"inapplicable_key"
const FAULT_ROLE_KEY_WITHOUT_TAG := &"role_key_without_tag"
const FAULT_WRONG_TYPE_CALL := &"wrong_type_call"   # cause: "stat read failed: <call>(def_id '<id>', key '<key>', level <n>): <prose> [<code>]"
func _init(catalogue: Catalogue, fatal: Callable) -> void       ## fatal is a method Callable on the battle's FatalLatch; never guarded.

## Base value for (ctx, key). Read at use time and never cache the result (one exception: max_hp at spawn).
## A bad call (unknown or inapplicable key, role key without tag, wrong type, level out of range, level on a
## levelless record, unresolved def_id) calls fatal(cause) once. The return after a bad call is UNSPECIFIED:
## the caller returns at once and checks halted() (the HUD checks phase() == FATAL).
func stat_int(ctx: ReadContext, key: StringName) -> int
func stat_float(ctx: ReadContext, key: StringName) -> float

## Non-fatal. Call before trusting an ID or level. Never call fatal.
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int                      ## 0 for a non-tower or unknown ID.

# Test double (tests only). Built with the fixture catalogue, or overrides all four methods; every override declares its return type and has an explicit return (4.7):
#   class_name SpyStatAccessor extends StatAccessor
#   func stat_float(ctx: ReadContext, key: StringName) -> float:
#       reads.append([ctx.def_id, key, ctx.level]); return values.get(key, 0.0)
# Spy handler: class SpyFatal extends RefCounted: var causes: Array[String]; func fatal(p_cause: String) -> void
```

### Implementation Guidelines
- Every stat a modifier could target (the `StatKeys` rows) **must** be read through `stat_int` or `stat_float` at the moment of use; code **must never** read a stat field (`damage`, `range_units`, `cost`, `max_hp` and the rest) off a record directly.
- Code **must never** store a value returned by the accessor in a field, a collection or a local that outlives the tick step that read it. The one exception is `max_hp`, read once at spawn to seed `Health`; any other exception **requires** an amendment to this ADR and Data GDD Rule 10.
- After every accessor read, the caller **must** check `halted()` before using the value and return at once if true; Battle HUD **must** check `phase() == FATAL` instead and abandon the read. No caller **may** use, store or compare the value returned after a bad call.
- Callers **must** check `is_tower(id)` before a command that takes an ID, and `level_count(def_id)` before a command or preview that takes a level, and **must** refuse the command; the accessor **must never** be used to find out whether an ID or level is valid.
- Callers **must** pass keys as `StatKeys` constants and **must never** pass a string literal or a computed key.
- `TowerSim` **must** read `range` once per tower per tick into a tick-local and **must** use a separate reused command context for build and upgrade cost reads; it **must never** set a built tower's context `level` before the commit (after the gold debit, before any emit).
- The accessor **must** call the injected `fatal` exactly once per bad call with a cause naming the call, `def_id`, key, level and a fault code; it **must never** use `assert()`, `push_error` alone, a sentinel the caller is expected to test, or a second route to the fatal screen.
- The accessor **must never** call `Catalogue.load_*`, mutate a record or the catalogue state, retain a `ReadContext`, hold a reference to `Battle` or to any sim, allocate in `stat_int`, `stat_float`, `is_tower` or `level_count`, or use `Object.get()` or other reflection to read a field.
- Every owner of a thing that is read **must** create one `ReadContext` when that thing comes to exist and reuse it; two callers **must never** share a context; a context **must never** hold a stat value.
- `ReadContext.live_entity` **must** always be a `WeakRef` (`weakref(null)` for a preview), never `null`; code **must never** store a strong reference to an entity on a context. Each owner **must** pass its entity as listed in Decision 5.
- `Flow.phase()` **must** return `FATAL` whenever the battle's `FatalLatch.is_set` is true.
- `TowerSim` **must** be the only writer of a tower context's `level`; `HudLogic` **must** be the only writer of its own preview contexts.
- `StatKeys` **must** be the only place a stat-key name or its int/float type is written; a key **must** be added together with its `match` arm, its schema field and its row in the per-key read test, and the tie test **must** pass.
- `stat_accessor.gd` **must** live in `src/battle/` and pass ADR-0001's ban set (`func(`, `func (`, `.bind(`, `bindv(`, `static var`, `assert(`, `Engine.`, `Time.`, `OS.`, `Node`); `read_context.gd` and `stat_keys.gd` **must** live in `src/data/`, extend `RefCounted`, and **must never** declare a `static var`, use `assert()` or hold a Callable.
- `StatAccessor` **must** stay a concrete, subclassable class; every override of `stat_int`, `stat_float`, `is_tower` or `level_count` **must** declare its return type and contain an explicit `return` (4.7).
- Tests **must** use the spy handler's method Callable and fixtures built through `load_parsed()`; they **must never** use a lambda or a file.

## Alternatives Considered

### Alternative 1: One `stat(ctx, key) -> Variant` method
- **Description**: A single read returning a `Variant`, as architecture v1 had.
- **Pros**: One method; no int/float split; a key's type needs no check.
- **Cons**: Callers lose static typing (`var d: float = accessor.stat(...)` is an untyped-to-typed conversion with no check); an int key read as float is silently fine; a bad call can return `null` that a typed local then mishandles.
- **Rejection Reason**: Technical-director review TD-ARCHITECTURE A9 replaced it with two typed methods; the declared type per key is part of the Data GDD's vocabulary (Rule 10).

### Alternative 2: A result object or sentinel for a bad read
- **Description**: Return a `StatResult {ok, value}`, or `NAN` / `-1` as a sentinel, and let the caller test it; fatal only on request.
- **Pros**: The caller sees the failure at the call; no latch needed for non-fatal reads.
- **Cons**: A result object allocates on every read (400 or more per tick); an `int` has no NaN, so a sentinel collides with real values; a caller that forgets the test uses garbage in release, which is the failure the GDD forbids.
- **Rejection Reason**: GDD Rule 10 makes the injected handler "the contract". A forgotten test costs a wrong number, while a forgotten `halted()` check costs at most one more step, because the latch is already set.

### Alternative 3: A strong `live_entity: Object` on the context (or a typed `Targetable`), or no entity field at MVP
- **Description**: Either store the entity strongly, typed `Targetable`, and clear it when the entity dies; or omit the field until Vertical Slice.
- **Pros**: A strong typed reference needs no `get_ref()`; omitting the field adds no `WeakRef`.
- **Cons**: A strong reference is a `RefCounted` cycle (enemy owns context, context holds enemy) that ADR-0001 forbids and the weakref test cannot see; `Targetable` is ADR-0009's and `src/data/` cannot import it. Omitting the field forces a context-constructor change at every owner when the resolver arrives, which is the call-site rewrite the GDD reserves the field to avoid.
- **Rejection Reason**: A `WeakRef` costs one allocation per entity, is cycle-free (4.7.2 probe) and keeps the seam open.

### Alternative 4: A new `ReadContext` per read
- **Description**: Build `ReadContext.new(def_id, level)` at each call site.
- **Pros**: Contexts are immutable in practice; no sharing question; simplest call sites.
- **Cons**: About 400 range reads per tick plus per-enemy `move_speed` reads allocate hundreds of objects per tick on a phone (QQ-11).
- **Rejection Reason**: Architecture B0 and TR-enemy-006 require a reused context per caller. The accessor never retains a context, which is what makes reuse and in-place mutation safe.

### Alternative 5: Put all three files under `src/data/`
- **Description**: `StatAccessor`, `ReadContext` and `StatKeys` beside the records, as architecture Module Ownership lists them under Data & Config.
- **Pros**: One folder; matches the layer map's wording; the tie test and the schema sit together.
- **Cons**: `src/data/` has ADR-0001's `src/battle/` bans relaxed (ADR-0002 Decision 2), yet the accessor holds the battle latch's Callable and is named in the retry weakref test, so a capturing lambda in it could keep an old battle alive; closing that needs a by-name or by-folder lint extension, the weakest option (a split-out helper or the resolver subclass would escape a name list).
- **Rejection Reason**: ADR-0001 Decision 10 defines `src/battle/` as the home of battle-lifetime classes; the accessor goes there and gets the bans for free. `ReadContext` and `StatKeys` hold no Callable and stay in `src/data/`.

### Alternative 6: Derive the key types from the schema at runtime, with no type column in `StatKeys`
- **Description**: `StatKeys` lists only the key names per kind; the accessor asks `CatalogueSchema` for each field's type.
- **Pros**: One declaration of int versus float, as ADR-0002 states ("never declared a second time"); no tie test needed for types.
- **Cons**: The GDD wants the vocabulary and its types readable in one table owned by Data (Rule 11); a schema refactor would silently change what a read means. (Cost is not a reason: the types could be derived once at accessor construction into the same dictionary, with no cost per read.)
- **Rejection Reason**: ADR-0002's Validation Criterion 22 anticipates a declared table tied by a test, and its Decision 8 now says so. This ADR takes that route; deriving the types once at construction stays open as a later revision.

### Alternative 7: Reflection reads (`rec.get(key)`) behind a key-to-field map
- **Description**: One generic read through a `Dictionary` map from key to field name.
- **Pros**: No per-kind `match`; a new key is a table row only.
- **Cons**: Reflective access is slower and untyped on a path that runs 400 or more times per tick; the local engine reference does not cover it; it hides a missing arm until runtime, where the explicit arm is caught by the per-key test; ADR-0002 already chose explicit assignments over reflection.
- **Rejection Reason**: Explicit arms are typed, fast and caught by the first test.

## Consequences

### Positive
- Every stat read has one place to fail loudly, in a release build, with a cause naming the record, key and level.
- The resolver drops in as a subclass behind two methods; no call site, owner or test double changes.
- A read allocates nothing, and contexts cannot form a cycle with their entities.
- The key vocabulary and its types are tested against the schema, so a typo or a retyped field fails a unit test, not a battle.
- Guards (`is_tower`, `level_count`) keep player and bot mistakes as refusals, so the fatal path stays for defects.

### Negative
- Every caller pays a `halted()` check after every read; the lint and the consumer-story tests are what keep it there.
- A new key touches four places (`StatKeys`, a `match` arm, the schema, the read test); the tie test and the read test catch a missing one.
- The type column duplicates the schema, held in line by a two-way test (Alternative 6 records the way out).
- Never-cache is held by tests and review, not by a lint.
- `max_hp` modifiers apply at spawn only.
- `live_entity` is unused at MVP.

## Risks
- **Per-read cost is above the first proposal on desktop and unmeasured on a phone.** A realistic read costs about 0.6 microsecond on a desktop debug build (probe5). Mitigation: `TowerSim` reads `range` once per tower per tick, so reads per tick are towers plus live enemies (Decision 7); the ceiling is re-derived in Performance Implications; Verification item 1 measures a phone. If it still misses, the accessor may memoise reads for one tick, invalidated by a new `accessor.begin_tick()` call from `Battle.tick` (one new call site, no consumer change); that revises Decision 7 here and the Data GDD's rule.
- **A consumer caches a value (a field set from a read).** Mitigation: the spy-accessor criterion in each consumer story, the review checklist, and `max_hp` pinned by its own test.
- **A caller uses the value after a bad call.** Mitigation: the `halted()` rule (ADR-0001 Decision 6), the wiring guideline, and consumer tests with a spy that latches `halted()` after the read.
- **A lambda or `bind()` slips into the accessor.** Mitigation: it lives in `src/battle/`, under ADR-0001's lint set, and the retry weakref test names it.
- **Two callers share a context, or an owner forgets to update `level` on upgrade.** Mitigation: the one-writer guideline, the separate command context, and the Tower story's tests: the success path asserts level 2's value, and the refused-upgrade test asserts level 1's value (Validation Criterion 13).
- **The schema gains a numeric field on one of the four records, or retypes one.** Mitigation: the tie test's two-way walk fails until `StatKeys` and the explicit arm are updated.
- **`WeakRef` or `Callable` lifetimes differ on an export.** Mitigation: Verification item 2 and Validation Criterion 14 (shared with ADR-0001); the design relies on `get_ref()` returning `null` only in the resolver, which is unbuilt.
- **`Flow.phase()` does not read FATAL at once.** Mitigation: Decision 3's requirement, ADR-0006's ratification and Validation Criterion 12.
- **Class-name collision with an addon (QQ-16).** The probe found no engine-class collision; ADR-0007's lint covers addons.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-008: every modifiable value is read through one accessor with a context and key, at use time, never cached; the resolver replaces internals with no call-site change | Decisions 2, 7 and 8: two typed reads, never-cache with the one `max_hp` exception, `StatAccessor` as a subclassable seam, `live_entity` on the context |
| data-config-pipeline.md | TR-data-010: Data owns the key vocabulary and the int/float type per key; non-fatal `level_count` and `is_tower` | Decision 4 (`StatKeys`, the tie test to ADR-0002's schema) and Decision 6 (the two lookups, no `fatal`) |
| data-config-pipeline.md | Rule 10 bad calls reach an injected handler that survives release; return unspecified (criteria 6, 7, 8, 12) | Decisions 2, 3 and 9; no `assert`; `fatal` injected as a method Callable; spy handler tests |
| enemy-wave.md | TR-enemy-006: enemy stats via the accessor at use time with a reused per-enemy context; Wave and Stage read directly | Decision 5 (one context per enemy at spawn), Decision 6 (direct lookups for Wave and Stage), Decision 7 (per-tick `move_speed`, `bounty`, `lives_cost`; `max_hp` once). The enemy type and spawn call are ADR-0009's |
| tower-system.md | TR-tower-003: `is_tower` and `level_count` before any accessor read; cost and stats at use time | Decision 6 (guards and refusals), Decision 5 (one context per built tower plus a command context for cost reads; `level` written only in the commit), Decision 7; Validation Criterion 13 |
| hero-system.md | TR-hero-005: Hero and Burst stats via the accessor at use time; Stage geometry direct | Decision 4 (hero and burst rows), Decision 5 (two contexts in `HeroSim`), Decision 6 (Stage direct) |
| battle-hud.md | TR-hud-011: costs via the accessor on arc open and `gold_changed`; a Fatal `phase()` abandons the read | Decision 5 (preview context, `live_entity` null), Decision 3 (HUD checks `phase() == FATAL`, not `halted()`; Flow must derive `phase()` from the latch; Validation Criterion 12), Decision 6 (`level_count` before `level + 1`) |
| combat-damage.md | Rule 9: Combat reads no data; `max_hp` seeds Health once | Decision 7 (the one exception); Combat takes values from callers and has no accessor dependency |

## Performance Implications
- **CPU**: A read is one index lookup, one `has()` on the kind's key table, a tag check for role keys only, one `match` on a `StringName` and one typed field read, with no allocation and no reflection. Desktop debug measurement (probe5, the read as Decision 2 describes it): about 0.6 microsecond per `stat_float` call; a bare dictionary read is about 30 ns, so the cost is the call and the checks. A phone is typically several times slower on GDScript (not measured here), so a read may cost 2 to 3 microseconds, which is 40 to 60% of QQ-11's 5 microseconds per range check if done once per tower-enemy pair. That is why `TowerSim` reads `range` once per tower per tick (Decision 7): accessor reads per tick are about towers plus live enemies (one `move_speed` each) plus a few `bounty`, `lives_cost`, `cost` and `cooldown` reads, so the proposed ceiling is **2.5 microseconds per read on the phone**, a proposal that leaves the per-tick total far below QQ-11's 2 ms. **Unmeasured on the target device; Verification item 1 measures it.**
- **Memory**: One accessor per battle (a catalogue reference, a Callable and one `Dictionary` of about 8 entries at MVP). One `ReadContext` (a few fields plus an optional `WeakRef`) per enemy, per built tower, two for the Hero and two for the HUD. Nothing per read.
- **Load Time**: The record index is built once in `build()` from four `ids()` passes and one lookup each, about 8 to 20 entries; negligible and unmeasured.
- **Network**: None.

## Migration Plan
Greenfield: `src/` holds no `.gd` file. Create `src/data/stat_keys.gd` and `src/data/read_context.gd`, and `src/battle/stat_accessor.gd`, after ADR-0002's records land. `BattleBuilder.build()` constructs the accessor with `StatAccessor.new(catalogue, fatal_latch.fatal)` before Flow, Combat, EnemyWave, TowerSim and HeroSim, and injects it into the sims, `HudLogic` (through the wrapper) and the content-test helpers. At `/architecture-review`: update `architecture.md` B0's `ReadContext` path (`src/foundation/data/` becomes `src/data/`), `live_entity: Object = null` to an always-set `WeakRef`, and "per tower slot" to "per built tower plus one command context"; B1's Invariants ("returns 0 or 0.0" becomes "unspecified") and its file (`src/battle/stat_accessor.gd`); the Module Ownership row for StatAccessor (path `src/battle/`, vocabulary now owned by `StatKeys`); ADR-0007's Depends On gaining ADR-0005 (the string-literal-key lint and the spy classes); ADR-0006's brief (the `Flow.phase()` requirement); register the stances in the candidates file. No prototype code is migrated.

## Validation Criteria
1. (GDD 6) The per-key read table passes: every applicable key of every record and tower level returns the fixture's expected value of the declared type, with a live-entity context and a preview context; role keys only with their tag; `level_count` matches each record; the spy handler is never called.
2. (GDD 7) The bad-call table passes: for each fault row, the spy fires exactly once with a cause containing the `def_id`, key, level and the row's fault code; the return value is not asserted.
3. (GDD 8) Two code-built fixtures with different values return their own values side by side, with no file I/O.
4. (GDD 12) After a bad call, the catalogue is `READY`, `snapshot_diff` against the earlier snapshot is empty, and a following valid read returns the right value.
5. (Never cache, deferred criterion owned by each consumer story: TR-tower-003, TR-hero-005, TR-hud-011, TR-enemy-006) With `SpyStatAccessor`, a value changed between two uses is reflected by the second use in Tower, Hero, Battle HUD and Enemy & Wave (`move_speed`, `bounty`, `lives_cost`); Enemy & Wave's `max_hp` is read once and a later change does not move `Health`.
6. (ADR-0002 Criterion 22, TR-data-010) The tie test passes both ways against `CatalogueSchema.FIELDS` and `ROLE_FIELD_TAG`: `StatKeys` agrees with the schema on every key's int or float type and on role tags, and every numeric field of the tower level, enemy, hero and burst entries is a stat key.
7. (TR-data-010, TR-tower-003) `is_tower` and `level_count` return the documented values for a tower, an enemy, an unknown ID, an empty ID and a non-Ready catalogue, with no `fatal` call.
8. (ADR-0001 Decision 7) After a retry, a `weakref` to the accessor is null in the same frame, and a weakref to a context that was passed to a read is null once its owner drops it.
9. (ADR-0007 lint) No `func(`, `func (`, `.bind(`, `bindv(`, `static var`, `assert(`, `Engine.`, `Time.` or `OS.` in `stat_accessor.gd`; no `static var`, `assert(` or Callable in `read_context.gd` and `stat_keys.gd`; no string-literal key at a `stat_int(` or `stat_float(` call.
10. (GDD criterion 13, shared with ADR-0001) On the first phone build, a throwaway release build with a deliberate bad accessor call reaches the fatal screen (no stripped assert), screenshot retained in `production/qa/evidence/`.
11. Verification item 1 (NOT SOURCEABLE until the first phone build): the per-read cost of `stat_float(ctx, StatKeys.RANGE)` on the Adreno 5xx-class device is recorded against the 2.5 microsecond proposal.
12. (TR-hud-011, ADR-0006) With a spy accessor that latches the battle `FatalLatch` on a HUD cost read, `Flow.phase() == FATAL` on the very next line, with no tick between.
13. (TR-tower-003) An `upgrade` refused with `NO_GOLD`, and one refused with `HALTED` from a spy that latches on the cost read, leaves the built tower's context `level` unchanged and the next `damage` read returns level 1's value.
14. (Verification item 2) ADR-0001's Android release run includes the entity-context `WeakRef` probe (probe.gd's cycle check) and records the result.
15. (Verification item 3) The parse check passes on `stat_keys.gd`, `read_context.gd` and `stat_accessor.gd`, including a spy subclass with a missing return type failing it (probe7).

## Related
- `docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md`: Decisions 3, 5, 6, 7, 8 (build constructs the accessor, method-Callable injection, the latch, `halted()`, no `assert`).
- `docs/architecture/adr-0002-catalogue-storage-format-manifest-and-validation.md`: Decisions 2, 3, 4, 8 and Validation Criterion 22 (records, IDs, schema, layer rule, tie test).
- `docs/architecture/architecture.md` v4: B0, B1, Module Ownership (StatAccessor), Required ADRs (ADR-0005), QQ-11, QQ-16.
- `design/gdd/data-config-pipeline.md` Rules 10 and 11, MVP stat keys, Acceptance Criteria 6, 7, 8, 12 and the deferred never-cache criterion; `tower-system.md`, `hero-system.md`, `enemy-wave.md`, `battle-hud.md`, `combat-damage.md` (consumer rules).
- Probes: `prototypes/adr-0005-spike/` (`probe.gd` to `probe8.gd`, README).
