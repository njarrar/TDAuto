# ADR-0005: Stat Accessor and Read-Context Contract

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. No other agent, and no skill on its own.

TD-ADR: batch review 2026-11-04, CONCERNS; fixes applied.

2026-11-04: TD-ADR batch review and engine check fixes applied.
Engine validation (godot-specialist): not run per ADR; batch review after all ADRs are written.

## Date

2026-11-04

## Last Verified

2026-11-04 (against the Godot 4.7.2 class reference at tag `4.7.2-stable`, `docs/engine-reference/godot/`, and `docs/architecture/architecture.md` v3)

## Decision Makers

Written in an autonomous run against `architecture.md` v3 and the Data & Config GDD. Open for the user and `technical-director` to accept or change.

## Summary

Every modifiable gameplay number must be read at use time through one accessor, so the Vertical Slice stat resolver can replace its internals with no call-site change. This ADR fixes `StatAccessor` with `stat_int` and `stat_float`, a `StringName` key vocabulary with one declared type per key, one reused `ReadContext` per caller, non-fatal `is_tower` and `level_count`, and a bad-call path that calls an injected failure handler.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting) |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW (per `architecture.md` Required ADRs: plain typed GDScript, `Dictionary` lookups and `Callable`; the 4.7 typed-return override rule is the one language trap) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; Godot 4.7.2 class reference: `doc/classes/Callable.xml`, `Dictionary.xml`, `@GDScript.xml` |
| **Post-Cutoff APIs Used** | None. The 4.7 rule that an override of a typed method inherits its return type and needs an explicit `return` (`breaking-changes.md`) applies to every spy subclass of `StatAccessor` |
| **Verification Required** | See the NOT SOURCEABLE list below |

### NOT SOURCEABLE (blocks Acceptance)

Each item is a fact the pinned reference and the 4.7.2 class reference do not state or only partly state. None is filled from memory. This ADR cannot move to `Accepted` until each named run is done and its result is recorded here.

1. **Whether a `Dictionary` treats a `String` key and a `StringName` key as the same key.** `Dictionary.xml` does not say. The rule below avoids the question by building every stats dictionary with `StringName` keys and calling with `StringName` constants. Settled by: desktop headless (a unit test that stores under `&"cost"` and looks up under `"cost"` and the reverse, and records the result).
2. **Whether a spy subclass overriding `stat_int` and `stat_float` with an explicit `return` compiles and dispatches under 4.7.2.** `breaking-changes.md` states the rule but gives no example for this shape. Settled by: desktop headless (the spy test in ADR-0007's harness).
3. **What `fail.call()` does when the handler's target is freed, in an exported build.** `Callable.xml` says `is_valid()` is true when the callable's object exists and has a valid method. `architecture.md` QQ-17 records that in a 4.7.2 editor probe `.call()` on a dead callable raised a script error and aborted the calling function. The export result is unverified. Settled by: the phone session (ADR-0001 owns the probe; this ADR needs its result). The accessor checks `is_valid()` first regardless.
4. **Cost of one read on a low-end phone.** No target is claimed. Settled by: the phone session (first phone build, measured with the Data Flow 10 frame budget).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 Catalogue Storage Format, Manifest and Validation (records, frozen `stats`, typed lookups); ADR-0001 App Lifecycle, Composition Root and Fatal Path (the fatal handler that the failure callable reaches; no autoloads; method Callables only) |
| **Enables** | ADR-0007 (spy accessors in the harness), ADR-0009 (Enemy holds a `ReadContext`), ADR-0010 (Tower and Hero command paths use `is_tower` and `level_count`) |
| **Blocks** | Every story that reads a stat: Enemy & Wave, Tower, Hero and Burst, Battle HUD costs and cooldown wedge |
| **Ordering Note** | `architecture.md` assigns TR-data-009 (a bad call reaches an injected handler that survives release) to ADR-0001. This ADR defines how the accessor calls that handler and the causes it names, and does not claim the TR. |

## Context

### Problem Statement

The first cross-buff ("towers near the hero") depends on instance and position, so a read API that takes only a definition would force a rewrite of every call site at Vertical Slice. The accessor shape must be right now. A bad call also cannot return a typed "nothing" in GDScript, so the failure contract must be explicit.

### Current State

Nothing exists. `architecture.md` B1 sketches the signatures; ADR-0002 defines the records the accessor reads.

### Constraints

- GDScript is statically typed in this project; version 1's `Variant` return was dropped for two typed methods (TD-ARCHITECTURE A9).
- No fallbacks in any build, and `assert` cannot carry the check: `@GDScript.xml` says the code inside `assert` runs only in debug builds or the editor.
- No autoload. One `StatAccessor` exists per battle, built by `BattleBuilder` (B4, Flow Rule 2a).
- A tick must allocate nothing on the hot read path (B0: one reused `ReadContext` per caller).
- Injected callables are method Callables only: no capturing lambda, no `bind()` (ADR-0001).

### Requirements

- One accessor taking a read context and a stat key, returning the type the key declares (TR-data-008).
- Data owns the key vocabulary and the int or float type per key, plus non-fatal `level_count` and `is_tower` (TR-data-010).
- Callers read at use time and never cache (TR-enemy-006, TR-hero-005, TR-hud-011).
- Callers validate IDs and levels with `is_tower` and `level_count` before a read (TR-tower-003).

## Decision

### 1. The accessor

```gdscript
class_name StatAccessor extends RefCounted     # src/foundation/data/stat_accessor.gd

## fail is a method Callable: fail.call(cause: StringName, error: ValidationError) -> void.
func _init(catalogue: Catalogue, fail: Callable) -> void

## Typed read. The key's declared type must match the call. Never cache the result,
## except max_hp when it seeds Health once.
func stat_int(ctx: ReadContext, key: StringName) -> int       # 0 after a bad call
func stat_float(ctx: ReadContext, key: StringName) -> float   # 0.0 after a bad call

## Non-fatal. Call these first when an ID or level is not already trusted.
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int    # 0 for an unknown ID or a record with no levels
```

The signatures are exactly those in `architecture.md` B1. `BattleBuilder.build` creates the one per-battle instance and passes a failure callable that reaches the per-battle FatalLatch (ADR-0001). Tests pass a recording method on a strongly held object.

### 2. Read context

```gdscript
class_name ReadContext extends RefCounted      # src/foundation/data/read_context.gd
var def_id: StringName = &""
var level: int = 0               # towers only; 0 for every other record
var live_entity: Object = null   # the live entity when one exists; ignored at MVP
```

Field names follow B0 (`live_entity`, not `entity`). Rules:

- Each caller owns one `ReadContext` for its life: one per enemy, one per tower slot, one for the hero, one per HUD preview. The caller sets `def_id` and `level` once, or before a read when previewing a level, and never creates a context per read.
- A caller must not share a context with another caller and must not store the context inside the accessor. The accessor reads a context and keeps nothing.
- A HUD cost preview has no live entity and passes `def_id` and `level` alone.
- At MVP the accessor ignores `live_entity` and returns the base value. The Vertical Slice resolver reads it; no call site changes.

### 3. Key vocabulary and types

Keys are `StringName` constants in `StatKeys` (`src/foundation/data/stat_keys.gd`), for example `const DAMAGE: StringName = &"damage"`. Call sites write `StatKeys.DAMAGE`, so a misspelt member fails at parse time, which a bare `&"dmg"` would not. The key type is `StringName` because B1 fixes it.

`StatKeys` also holds the spec table, a `const` Dictionary from key to `{type, kinds, role_tag}`. The GDD key table is the source:

| Kind | Int keys | Float keys |
|---|---|---|
| tower | `cost` | `damage`, `range`, `attack_interval`, `splash_radius` (needs tag `splash`), `slow_strength`, `slow_duration` (both need tag `slow`) |
| enemy | `bounty`, `lives_cost` | `max_hp`, `move_speed` |
| hero | none | `damage`, `attack_interval`, `leash_radius`, `walk_speed` |
| burst | none | `damage`, `radius`, `reach`, `cooldown`, `telegraph_duration` |

A key has one declared type everywhere it appears. `damage` and `attack_interval` are float for every kind that has them. A test fails if the table gives one key two types. Stage has no row: Stage fields, wave groups, the Input record, `scene_ref` and each level's `visual_key` are structural and read directly from the records (Rule 10). No `stat_bool` exists at MVP; a bool key arrives with its own method and spec row.

ADR-0002's validator and builder use the same table to place each value in a record's `stats` dictionary with `StringName` keys and the declared type (NOT SOURCEABLE item 1 explains why every key is a `StringName`). Adding a key means adding a constant and a spec row. It changes no signature.

### 4. Bad calls

A bad call is checked in this fixed order. The first failure wins, so a test can pin one cause per input.

1. `stat_null_context`: `ctx` is null.
2. `stat_unresolved_def`: `ctx.def_id` names no tower, enemy, hero or burst. IDs are unique across record types (ADR-0002), so lookup order does not matter.
3. `stat_unknown_key`: `key` is not in the spec table.
4. `stat_inapplicable_key`: the key does not apply to the record's kind, or needs a role tag the record lacks (for example `splash_radius` on a `slow` tower).
5. `stat_wrong_type`: `stat_int` on a float key, or `stat_float` on an int key.
6. `stat_bad_level`: a tower with a level outside `1..level_count`, or any other kind with a nonzero level.

On a bad call the accessor builds one `ValidationError` with `code` set to the cause, `source` set to `"accessor"`, `record_id` set to `ctx.def_id` (or empty), and `field` set to the key. It then calls the handler and returns `0` or `0.0`. If `fail.is_valid()` is false it calls `push_error` with the cause and still returns the sentinel, because `.call()` on a dead callable aborts the caller (NOT SOURCEABLE item 3). The checks are ordinary `if` statements and never `assert`.

**The handler is the contract.** In the game it reaches the fatal screen; tests replace it. The sentinel is never a usable value. After every read whose result matters, the caller checks the injected `halted()` before using the number (B1 invariants).

Caller rules from the GDDs:

- A read or snapshot that finds `phase()` Fatal is abandoned for the Fatal screen. The HUD tests `phase()`, not `halted()`, because `halted()` is also true on Won and Lost (TR-hud-011).
- Callers read at use time and never cache. The one exception is `max_hp` seeding Health once at spawn.
- A caller whose ID or level comes from a command or a preview calls `is_tower` and `level_count` first and refuses the command, rather than reach the handler (TR-tower-003).
- Wave and Stage records are read directly and never written (TR-enemy-006). Hero and Burst stats use the accessor, while `hero_start`, `pin_rect` and `pin_exclusion` come from the Stage record (TR-hero-005).

### 5. Read path

For a non-tower record the value is `record.stats[key]`. For a tower it is `tower.levels[ctx.level - 1].stats[key]`. The validator has already proved the value exists, is finite, is in domain, and has the declared type, so the read path does no further checks beyond the six above.

### 6. Test doubles

A spy accessor extends `StatAccessor` and overrides `stat_int` and `stat_float`. Each override needs an explicit typed `return` (4.7 rule, `breaking-changes.md`; NOT SOURCEABLE item 2). A spy proves use-time reads: change the value between two uses and the consumer's next use reflects it. The recording failure handler is a method on a strongly held `RefCounted` or `Node` helper, not a lambda.

### Key Interfaces

See sections 1 and 2. The only public surface is `StatAccessor`, `ReadContext` and `StatKeys`. Consumers never read a record's `stats` dictionary.

### Implementation Guidelines

- Consumers must read every modifiable value through `stat_int` or `stat_float` at the moment of use. They must never cache the result, except `max_hp` seeding Health.
- Consumers must pass a `StatKeys` constant, never a string literal.
- Consumers must create one `ReadContext` per entity or slot and reuse it. They must never create one per read.
- Consumers must check `halted()` (or `phase()` for the HUD) before using a read after a possible bad call.
- Consumers must call `is_tower` and `level_count` before reading when the ID or level is not already trusted.
- The accessor must use `if` checks and call the injected handler. It must never use `assert`.
- The accessor must never allocate on a successful read.
- The accessor must never hold a `ReadContext`, an entity or a record reference between calls.
- `StatKeys` must declare one type per key. Adding a key must not change `stat_int`, `stat_float`, `is_tower`, `level_count` or `ReadContext`.
- The Vertical Slice resolver must replace the accessor's internals only. It must not add a parameter to `stat_int` or `stat_float`.
- Public classes need doc comments (project coding standards).

### Architecture Diagram

```
 BattleBuilder --creates--> StatAccessor(catalogue, fail) --held by--> Battle
                                   ^
 Enemy / TowerSim / HeroSim / HudLogic --stat_int/stat_float(own ReadContext, StatKeys.X)
                                   |
                       Catalogue records (frozen stats, ADR-0002)
 bad call --> fail.call(cause, ValidationError) --> FatalLatch (ADR-0001)
```

## Alternatives Considered

### Alternative 1: One `read(ctx, key) -> Variant`
- **Description**: A single method returning `Variant`, as in version 1 of the architecture.
- **Pros**: Fewer methods; no wrong-type call is possible.
- **Cons**: Callers lose static typing and need a cast at every site. Version 1 was replaced for this reason.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Violates the static-typing rule and TD-ARCHITECTURE A9.

### Alternative 2: Key enum instead of `StringName`
- **Description**: A `Catalogue.StatKey` enum, so a misspelt member fails at parse time without constants.
- **Pros**: Cheap integer compare; parse-time check.
- **Cons**: B1 fixes `key: StringName`. An enum also hides the JSON field name in a second table.
- **Estimated Effort**: Similar.
- **Rejection Reason**: `StatKeys` constants give the same parse-time check and keep the `StringName` signature.

### Alternative 3: Read the record's typed fields directly
- **Description**: Consumers read `tower.levels[n].damage` and skip the accessor.
- **Pros**: Simplest; no table.
- **Cons**: Every call site changes when the resolver arrives; no single place for the bad-call contract.
- **Estimated Effort**: Lowest now, highest later.
- **Rejection Reason**: Breaks Principle 3 and TR-data-008.

### Alternative 4: A new `ReadContext` per read
- **Description**: Build a context at each call.
- **Pros**: No stale fields.
- **Cons**: Allocates on every read; a tick would allocate.
- **Estimated Effort**: Similar.
- **Rejection Reason**: B0 requires reuse per caller.

## Consequences

### Positive
- One place holds the vocabulary, the types and the bad-call contract.
- The resolver drops in behind an unchanged signature.
- Typed returns keep callers statically typed.

### Negative
- A wrong accessor choice (int versus float) is a runtime failure, not a parse error.
- A caller that forgets to check `halted()` after a bad call uses a sentinel zero. A review rule and the spy tests are the guard.
- A reused context can carry a stale `level`. The caller sets it before each preview read.

### Neutral
- `bool` stats have no accessor until one is needed.
- Visual keys are structural data and bypass the accessor.

## Risks

- **String and StringName key mismatch.** Mitigation: every stats key is a `StringName` built by the builder, and a unit test pins the engine behaviour (item 1).
- **Dead failure handler.** Mitigation: `is_valid()` guard plus `push_error`; the export probe (item 3).
- **A caller caches a stat.** Mitigation: the spy use-time test in each consumer story.
- **Spec table drifts from the GDD.** Mitigation: a test compares the table to the validator's per-kind field lists, and the content test covers the rest.
- **Hot-path cost on a phone is unmeasured** (item 4). Mitigation: measure in the first phone build.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-008: every modifiable value is read through one stat accessor `(read_context, stat_key)` at use time, never cached, so the resolver can replace its internals | `StatAccessor`, `ReadContext`, `live_entity` reserved, no-cache rule |
| data-config-pipeline.md | TR-data-010: Data owns the stat-key vocabulary and the int or float type per key, and exposes non-fatal `level_count` and `is_tower` | `StatKeys` spec table; `is_tower`, `level_count` |
| enemy-wave.md | TR-enemy-006: every enemy stat is read through the accessor at use time with a reused per-enemy context; Wave and Stage records are read directly | Section 2 reuse rule; section 3 structural data note |
| tower-system.md | TR-tower-003: tower IDs and levels are validated with `is_tower` and `level_count` before any accessor read | Section 4 caller rules; non-fatal lookups |
| hero-system.md | TR-hero-005: Hero and Burst stats go through the accessor; `hero_start`, `pin_rect` and `pin_exclusion` come from the Stage record | Section 3 table rows for hero and burst; Stage read directly |
| battle-hud.md | TR-hud-011: costs read through the accessor on arc open and `gold_changed`; a Fatal `phase()` abandons the read | Section 4 caller rule on `phase()`; preview context |

## Performance Implications
- **CPU**: A read is a few checks and two dictionary lookups (three for a tower level). Reads per tick are a few dozen. No target is claimed; unverified until a phone build.
- **Memory**: One accessor per battle; one context per entity or slot.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
Nothing exists to migrate. Order: `StatKeys` and the spec table, `ReadContext`, `StatAccessor` with a recording handler and table tests for the six causes, then consumers.

**Rollback plan**: The signatures match `architecture.md` B1. If `StringName` keys prove unsafe (item 1), switch the key to an enum inside `StatKeys` and change B1 and this ADR together.

## Validation Criteria
- A table test covers each of the six bad-call causes and shows the order of checks.
- A spy accessor test shows a changed value reaches the next use in the Enemy, Tower, Hero and HUD stories.
- Static typing holds: no `Variant` return and no untyped parameter in the accessor.
- A test shows no allocation on a successful read.
- Every NOT SOURCEABLE item above has a recorded result.

## Related
- `docs/architecture/architecture.md` (B0 Shared types, B1 Stat accessor, B4 Battle and Builder, Required ADRs)
- `design/gdd/data-config-pipeline.md` (Rules 10 and 11, stat keys)
- ADR-0001 (depends on); ADR-0002 (depends on); ADR-0007, ADR-0009, ADR-0010 (enabled)
- GDD sync: checked data-config-pipeline.md; the GDD names `read_context` and `stat_key`, and this ADR uses `ReadContext` and `StatKeys` constants. No behaviour differs.
