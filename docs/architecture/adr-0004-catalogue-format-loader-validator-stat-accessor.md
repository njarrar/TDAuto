# ADR-0004: Catalogue Format, Loader, Validator and Stat Accessor

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. No other agent, and no skill on its own.

TD-ADR: not run per ADR; batch review after all ADRs are written.
Engine validation (godot-specialist): not run per ADR; batch review after all ADRs are written.

## Date

2026-11-04

## Last Verified

2026-11-04 (against the Godot 4.7.2 class reference, tag `4.7.2-stable`, and `docs/engine-reference/godot/`)

## Decision Makers

Authored in an autonomous run against `docs/architecture/architecture.md` (version 2). Open for the user and `technical-director` to accept or change.

## Summary

The catalogue of authored gameplay values needs a storage format, a loader, a validator that collects every error, and one typed stat accessor, and the Data & Config GDD left the format open (QQ-05). This ADR chooses JSON text files named by a JSON manifest, validated against a schema table in code, built into read-only typed records, and read through `read_int`, `read_float` and `read_bool` that call an injected failure handler on a bad call.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting, file access) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (GDScript is HIGH in `VERSION.md`; the file and JSON APIs used here are old and stable, but the export behaviour is not verified) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; Godot 4.7.2 class reference: `doc/classes/JSON.xml`, `FileAccess.xml`, `ResourceLoader.xml`, `Resource.xml`, `Dictionary.xml`, `Array.xml`, `@GlobalScope.xml`, and `modules/gdscript/doc_classes/@GDScript.xml` |
| **Post-Cutoff APIs Used** | None. `FileAccess.store_*` returning `bool` (4.4) is not used by the loader (read only). The 4.7 rule that a typed-return override needs an explicit `return` applies to every spy subclass of `Catalogue` |
| **Verification Required** | (1) An Android and an iOS export loads every JSON file. (2) Whether `JSON.parse` yields `int` or `float` for a whole number. (3) How `JSON.parse` treats a duplicate key inside one object. (4) What a write to a read-only `Dictionary` or `Array` does. (5) Whether GDScript accepts a static method named `load` (this ADR avoids the question by renaming). (6) Whether the editor imports `.json` files and how that affects the edit-save-run loop |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary (the `TextSource` seam, typed GDScript conventions, headless load rule) |
| **Enables** | ADR-0005 (failure handler and `halted()` rule), ADR-0007 (Combat reads no data), ADR-0009, ADR-0010, ADR-0011, ADR-0013 (content test and snapshot) |
| **Blocks** | Every story that reads a catalogue value; the Data & Config epic |
| **Ordering Note** | ADR-0002 (App Lifecycle and Composition) owns the fatal handler that this ADR calls. ADR-0003 (Fixed Tick, Time and Determinism) owns `to_ticks`; this ADR validates the one-tick floor as a constant `1.0 / 60.0` taken from `SimTime.DT`. |

## Context

### Problem Statement

All gameplay numbers and stage geometry live in data (Principle 3). The GDD requires a format that detects a missing field, a fractional integer and an unknown property, loads all records or none, reports every error with `{code, source, record_id, field}`, and serves reads through one accessor that a later modifier system can slot behind. The master architecture leaves the file format and manifest form open (QQ-05).

### Current State

Nothing exists. `src/` holds only a standards file. Prototype constants are starter fixtures and are not balance values (Data & Config GDD).

### Constraints

- Godot 4.7.2, GDScript, single thread, Mobile renderer, Android and iOS exports.
- The catalogue is injected, never an autoload (TR-data-006). Tests build catalogues with no file I/O.
- No fallbacks in any build (TR-data-007). `assert` cannot carry the check: `@GDScript.xml` `assert` says the code inside runs only in debug builds or the editor.
- A bad accessor call cannot return a typed "nothing" in GDScript, so it returns a sentinel and the caller checks `halted()` (architecture, Catalogue invariants).

### Requirements

- Explicit manifest, never a directory scan (GDD Rule 4).
- Validate everything, collect every error, then fail; manifest-tier errors stop record checks (Rule 7).
- Read-only after load, with a snapshot to prove it (Rule 6; GDD Open Question "Snapshot mechanics").
- One accessor taking a read context and a stat key (Rule 10), plus non-fatal `level_count` and `is_tower`.
- Edit a value, save, run: new value in the game within 10 s (proposed), no live reload (Rule 13).

## Decision

### 1. Format and files (answers QQ-05)

Data is JSON text under `res://assets/data/`. A JSON **manifest** lists the data files in order. Each data file holds one record type.

```json
// res://assets/data/manifest.json
{ "files": ["res://assets/data/towers.json", "res://assets/data/enemies.json",
            "res://assets/data/waves.json",  "res://assets/data/stages.json",
            "res://assets/data/hero.json",   "res://assets/data/burst.json",
            "res://assets/data/input.json"] }

// res://assets/data/towers.json
{ "type": "tower",
  "records": [
    { "id": "arrow_tower", "rationale": "...", "tags": ["single_target"],
      "levels": [ { "cost": 40, "damage": 6.0, "range": 120.0,
                    "attack_interval": 0.8, "visual_key": "arrow_1" },
                  { "cost": 60, "damage": 10.0, "range": 130.0,
                    "attack_interval": 0.7, "visual_key": "arrow_2" } ] } ] }
```

Record types are `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`. A type may be split over several files; IDs stay unique across all files and types (GDD Rule 2). Field names follow the GDD tables exactly. Points are two-element arrays `[x, y]`. `pin_rect` is `{"min": [x, y], "max": [x, y]}`. A `pin_exclusion` shape is `{"a": [x, y], "b": [x, y], "radius": r, "hand": "right" | "left" | "both"}`.

**Why JSON and not typed `Resource` files.** The GDD requires a format that can detect a missing field, a fractional integer and an unknown property, or else a check that does. With JSON the validator sees the raw `Dictionary`, so every one of those checks is code we own and test. For `.tres` files the 4.7.2 class reference does not say what happens on load when a property is missing or unknown: NOT SOURCEABLE: `Resource.xml` and `ResourceLoader.xml` do not describe missing or unknown property handling at load. `Resource.xml` does say loaded resources go in a global path cache and are shared, and that `duplicate()` is shallow for nested containers by default, which works against read-only enforcement. `ResourceLoader.xml` (`load`) also says text resources may be converted to binary on export, which a plain-text file avoids. The GDD recommended typed Resources; this ADR departs from that recommendation for the detectability reason and records it here.

### 2. Classes (Foundation, all `RefCounted`, one `class_name` per file)

```
 AppRoot ──► Catalogue.from_manifest(path, TextSource, fail)
                │
                ├─ CatalogueLoader   read manifest, read + parse files        (manifest-tier errors)
                ├─ CatalogueSchema   const tables: record fields, domains, tags, StatKey spec
                ├─ CatalogueValidator validate(documents) -> Array[CatalogueError]   (record-tier)
                └─ build typed records (StageRecord, WaveRecord, ...) + frozen stat data
 consumers ──► read_int / read_float / read_bool(ctx, key), level_count, is_tower, stage, wave ...
```

- `TextSource` (architecture): `read_text(path: String) -> String`. `FileTextSource` wraps `FileAccess.get_file_as_string(path)`, which returns an empty string on an open error (`FileAccess.xml`), and the loader records `FileAccess.get_open_error()` in the error `field` for a development run. An empty string is treated as unreadable or empty: one manifest-tier error. Tests use `StringTextSource`, a dictionary from path to JSON text.
- `CatalogueLoader` parses with a `JSON` instance and `parse(text)`, not `parse_string`, so the error line is available through `get_error_line()` and `get_error_message()` (`JSON.xml`). It stops on manifest-tier errors before any record check (GDD Rule 7).
- `CatalogueValidator` is pure: documents in, errors out.
- `Catalogue` builds records only when the error list is empty.

### 3. Errors

```gdscript
class_name CatalogueError extends RefCounted   # fields as architecture.md
var code: StringName       # &"field_missing", &"int_fractional", ...
var source: String         # file path, or a label for code-built fixtures
var record_id: StringName  # &"" for a file-level error
var field: StringName      # &"levels[1].cost"; the property name for an unknown property
```

Codes, grouped by tier. Manifest tier: `manifest_unreadable`, `manifest_parse`, `manifest_shape`, `manifest_empty`, `manifest_duplicate_path`, `file_unreadable_or_empty`, `file_parse`, `file_shape`, `file_unknown_type`, `type_no_records`. Record tier: `id_format`, `id_duplicate`, `ref_dangling`, `ref_wrong_type`, `field_missing`, `field_unknown`, `field_type`, `number_non_finite`, `number_out_of_range`, `int_fractional`, `tag_unknown`, `tag_role_count`, `role_field_missing`, `role_field_without_tag`, `list_empty`, `path_degenerate`, `pin_rect_inverted`, `input_record_count`. Accessor time: `stat_unknown_key`, `stat_inapplicable_key`, `stat_wrong_type`, `stat_bad_level`, `stat_unresolved_def`.

Rules for the record tier, in this order per field: finite check first (`is_finite`, `@GlobalScope.xml`; infinity would pass "above 0"), then type, then integer check, then domain. An unknown tag produces one error and skips that record's role checks. A fractional integer is `value != floor(value)`; the validator accepts both `TYPE_INT` and `TYPE_FLOAT` for a number because `JSON.xml` says numbers are parsed with `String.to_float` and does not say whether a whole number comes back as `int`; NOT SOURCEABLE: the Variant type of a parsed whole number. A unit test pins what 4.7.2 actually returns.

Duplicate-key detection inside one JSON object is not possible after parse: NOT SOURCEABLE: how `JSON.parse` treats a duplicate key (`JSON.xml` is silent). The risk is recorded below.

### 4. Stat accessor

```gdscript
class_name ReadContext extends RefCounted     # architecture.md fields, plus one
var def_id: StringName
var level: int = 0               # towers only; 0 for every other record
var entity: RefCounted = null    # live entity when one exists; ignored at MVP (GDD Rule 10)

class_name Catalogue extends RefCounted
enum StatKey { COST, DAMAGE, RANGE, ATTACK_INTERVAL, SPLASH_RADIUS, SLOW_STRENGTH, SLOW_DURATION,
               BOUNTY, LIVES_COST, MAX_HP, MOVE_SPEED, LEASH_RADIUS, WALK_SPEED, RADIUS, REACH,
               COOLDOWN, TELEGRAPH_DURATION }

## Builds a catalogue or returns null. `fail` is called as fail.call(cause: StringName, errors: Array[CatalogueError]).
static func from_manifest(manifest_path: String, source: TextSource, fail: Callable) -> Catalogue
## Same pipeline from already-parsed documents, for fixtures built in code. No file I/O.
static func from_documents(documents: Array[Dictionary], fail: Callable) -> Catalogue

func read_int(ctx: ReadContext, key: StatKey) -> int         # 0 after a failure
func read_float(ctx: ReadContext, key: StatKey) -> float     # 0.0 after a failure
func read_bool(ctx: ReadContext, key: StatKey) -> bool       # false after a failure
func level_count(def_id: StringName) -> int                  # non-fatal; 0 for an unknown or level-less id
func is_tower(id: StringName) -> bool                        # non-fatal
func stage(id: StringName) -> StageRecord                    # structural, read directly
```

- Key format is the `StatKey` enum, not a string. A misspelt member fails at parse time (architecture.md, Catalogue invariants). A const table in `CatalogueSchema` maps each key to its JSON field name, its declared type (int or float), the record kinds it applies to, and the role tag it needs (`SPLASH_RADIUS` needs `splash`, `SLOW_STRENGTH` and `SLOW_DURATION` need `slow`).
- Integer keys: `COST`, `BOUNTY`, `LIVES_COST`. Every other key is float. `read_bool` has no MVP key; any call is a `stat_wrong_type` failure until a bool key is added together with its domain row.
- A bad call is: unknown key, key not applicable to that record kind or role tag, key read with the wrong typed accessor, a level outside `1..level_count` for a tower, a nonzero level for any other record, an unresolved `def_id`. Each calls `fail.call(cause, [error])` with `source = "accessor"` and returns the sentinel. The check is an ordinary `if`, never `assert`.
- The handler is the contract. The game wires it to ADR-0002's idempotent fatal handler. Tests wire a spy. The sentinel is never to be used by a caller; callers check `halted()` after every read (TR-wave-005, ADR-0005).
- Callers read at use time and never cache a value. The one exception is `max_hp` seeding Health once (ADR-0007). A caller may hold one `ReadContext` per entity and reuse it; it must not hold the value.
- Spy accessors are subclasses of `Catalogue` that override the read methods. Each override needs an explicit typed `return` (4.7 rule, `breaking-changes.md`).

### 5. Records the architecture's API list does not name

The GDDs read these directly or need them for views. They are additions to `architecture.md` API Boundaries (see Consequences).

```gdscript
func wave(id: StringName) -> WaveRecord        # groups: Array[WaveGroup]; intermission_duration: float
func hero(id: StringName) -> HeroRecord        # id, burst_id: StringName
func input_record() -> InputRecord             # drag_slop, tap_slop, edge_reject_margin
func visual_key(ctx: ReadContext) -> StringName  # same failure rules as the stat reads
func tower_ids() -> Array[StringName]          # manifest order, for the build arc
func snapshot() -> Dictionary                  # deep copy of all data, see section 6
```

`StageRecord` carries every Stage field the GDD lists, not only geometry: `scene_ref`, `wave_ids`, `starting_gold`, `starting_lives`, `early_call_seconds_per_gold`, `path_points`, `path_width`, `slot_positions`, `hero_start`, `pin_rect`, `pin_exclusion: Array[PinExclusionShape]`. `PinExclusionShape` holds `a: Vector2`, `b: Vector2`, `radius: float`, `hand: int` (enum `PinHand { RIGHT, LEFT, BOTH }`), and scalar `float` copies of the four coordinates, because `Vector2` is 32-bit and a GDScript `float` is 64-bit (`Vector2.xml` description) and `PinGeometry` computes on 64-bit scalars (architecture, Engine Knowledge Gap Summary). `StageRecord` likewise exposes `pin_min_x`, `pin_min_y`, `pin_max_x`, `pin_max_y` as scalars beside `pin_rect`.

### 6. Read-only and snapshot (GDD Open Question "Snapshot mechanics")

After validation the loader freezes the stat data: every nested `Dictionary` and `Array` gets `make_read_only()`, applied recursively because the class reference says it "does not apply to nested content" (`Dictionary.xml`, `Array.xml`). What a write to a frozen container does is NOT SOURCEABLE: `Dictionary.xml` and `Array.xml` say only that modification is disabled. Packed arrays on `StageRecord` have no such flag. So the real guard is the snapshot test, not the freeze.

`snapshot()` returns `Dictionary.duplicate(true)` of the stat data plus a plain-value dump of every typed record (each record class has `to_dict()`). `Dictionary.duplicate` with `deep = true` copies nested arrays and dictionaries (`Dictionary.xml`). The test compares `JSON.stringify(JSON.from_native(snapshot()), "", true, true)` before and after a scripted battle; `sort_keys` and `full_precision` are documented parameters of `JSON.stringify`, and `JSON.from_native` is documented in `JSON.xml`. Integers are held as GDScript `int` in the typed records and the stat data; the JSON text dump writes them as floats (`JSON.xml`, stringify note), which is harmless for equality.

### 7. Export and tuning loop

`FileAccess.xml` says exported games may lack original source files, and that a non-resource file must be included by changing the import mode to Keep File or by adding its extension to the non-resource export filter. The export preset must include `*.json`. NOT SOURCEABLE: the preset key name for that filter and whether the editor imports `.json` files; both are verified by the Android export run (Verification Required 1 and 6). The loader never uses `ResourceLoader`, because `ResourceLoader.xml` says non-resource files cannot be read that way.

### Implementation Guidelines

- The loader and validator must never reference a scene node, autoload or `Engine` singleton. They load headless (ADR-0001).
- Callers must never write to a record or a frozen container. A code review rule and the snapshot test enforce it.
- The validator must report every error in one pass, except that manifest-tier errors stop record checks.
- Accessor checks must be `if` statements that call `fail`. They must never be `assert`.
- Adding a field means editing `CatalogueSchema` and the validator in the same change. Adding a key means adding a `StatKey` member and its spec row. Neither changes the loader or accessor signatures.
- Callers must call `is_tower` and `level_count` before an accessor read whose id or level comes from a command or a preview.
- Public classes need doc comments (project coding standards).

## Alternatives Considered

### Alternative 1: Typed `Resource` files (`.tres`), one per record or per type
- **Description**: `class_name TowerData extends Resource` with `@export` fields; load with `load()`.
- **Pros**: Editor inspector; type checking at edit time; GDD's stated preference.
- **Cons**: Missing and unknown property handling on load is not documented in the reference (NOT SOURCEABLE), so Rule 8 would need a second parallel check anyway. Loaded resources are cached and shared and mutable. Text resources may be converted to binary on export. Merge diffs of `.tres` are noisier than JSON.
- **Estimated Effort**: Similar loader cost; larger validator cost to recover raw-file facts.
- **Rejection Reason**: Cannot be shown to meet the "detect missing field, unknown property" requirement without extra machinery that JSON gets for free.

### Alternative 2: GDScript `const` dictionaries in `.gd` files
- **Description**: Data lives in preloaded scripts as constants.
- **Pros**: Always exported; no file I/O; constants are read-only by language rule (`Dictionary.xml`: const dictionaries are read-only).
- **Cons**: Data edits are code edits; parse errors surface as script errors, not collected catalogue errors; blurs the "no gameplay value in code" line.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Breaks Principle 3 in spirit and cannot collect all errors.

### Alternative 3: JSON authored, compiled to `.tres` at build
- **Description**: JSON as source; a tool bakes typed Resources.
- **Pros**: Both worlds.
- **Cons**: A build tool the solo developer must maintain; the edit-save-run loop gains a step (GDD "Deliberately not built": import pipelines, custom tools).
- **Estimated Effort**: Highest.
- **Rejection Reason**: Over-built for MVP. Can be added later behind the same `Catalogue` API.

## Consequences

### Positive
- Every GDD validation rule is plain code, table-testable with `from_documents` and no file I/O.
- Errors name file, record and field, and the format has no hidden defaults.
- The accessor signature is stable for the Vertical Slice modifier resolver (it replaces internals only).

### Negative
- No editor inspector for data; designers edit text. JSON parse leniencies apply (trailing commas ignored, lax numbers, `JSON.xml`).
- Duplicate keys in one object are not detected (see Risks).
- Records are built by hand from dictionaries; each new field costs a schema row and a record-class change.

### Neutral
- `architecture.md` needs these edits in its next revision (not made here): the `Catalogue.load` name becomes `from_manifest`; the API list gains the section 5 methods; `ReadContext` gains `entity`; `StageRecord` gains the missing Stage fields; `pin_exclusion` is `Array[PinExclusionShape]`, not `Array[Rect2]`, because the GDD defines each shape as two points, a radius and a hand.
- The rename from `load` avoids an unanswered question: NOT SOURCEABLE: whether GDScript allows a static method named like the built-in `load` (`@GDScript.xml` documents `load` as a keyword-like built-in function).

## Risks

- **Duplicate JSON keys silently overwrite.** Mitigation: ADR-0013's content test adds a raw-text scan for repeated keys in one object; until then it is an accepted gap.
- **Export drops the files.** Mitigation: the Android and iOS export check (GDD criterion 13) runs before Acceptance; the generic fatal screen shows if a file is missing.
- **Whole-number type surprise** (`int` or `float`). Mitigation: validator accepts both; pinned by a unit test.
- **Frozen containers hide a write silently or crash.** Mitigation: the snapshot test, not the freeze, is the guard.
- **Load time on a low-end phone** is unmeasured (GDD criterion 15, at most 1000 ms, proposed). Mitigation: measure in the first phone build.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-001: load once from an explicit manifest, all or nothing | JSON manifest, `from_manifest` returns null on any error |
| data-config-pipeline.md | TR-data-002: validate everything, collect `{code, source, record_id, field}` | `CatalogueValidator`, `CatalogueError`, two tiers |
| data-config-pipeline.md | TR-data-003: read-only after load, instances hold `def_id` | Frozen data, `snapshot()` test, `ReadContext` |
| data-config-pipeline.md | TR-data-004: one accessor with read context and key, plus `level_count`, `is_tower` | `read_int`, `read_float`, `read_bool`, `StatKey`, schema spec table |
| data-config-pipeline.md | TR-data-005: Stage geometry on the Stage record, read directly | `StageRecord` with all Stage fields and scalar copies |
| data-config-pipeline.md | TR-data-006: injected, fixtures in code, no file I/O | `from_documents`, `TextSource`, spy subclasses |
| data-config-pipeline.md | TR-data-009: edit, save, run within 10 s | No import step or bake; verification listed |
| combat-damage.md | Combat reads no data | No `Catalogue` reference in Combat (ADR-0007) |

## Performance Implications
- **CPU**: A read is two dictionary lookups plus the checks. Reads per tick are a few dozen (tower slots, up to 48 enemies reading `move_speed`). No target is claimed; unverified until a phone build.
- **Memory**: Small; tens of records.
- **Load Time**: Parse and validate once. Budget 1000 ms to Ready on the named device is the GDD's proposal and is unmeasured.
- **Network**: None.

## Migration Plan
Nothing exists to migrate. Implementation order: `CatalogueError`, `TextSource`, `CatalogueSchema`, validator with table tests, loader, `Catalogue`, then consumers.

**Rollback plan**: The `Catalogue` API hides the format. If JSON fails the Android export check, swap the loader for another source (Alternative 1 or 3) and keep the validator on the same dictionaries.

## Validation Criteria
- The GDD's CI logic criteria 1 to 8 and integration criteria 9 to 12 pass.
- The exported Android build loads the catalogue and shows the fatal screen for one invalid record (GDD criterion 13).
- A spy accessor test shows a changed value reaches the next use.
- The snapshot is identical after a scripted battle with a death.

## Related
- `docs/architecture/architecture.md` (Catalogue, Shared types, TR-data-001 to 009, QQ-05)
- `design/gdd/data-config-pipeline.md`
- ADR-0001 Simulation and Shell Boundary; ADR-0002 App Lifecycle and Composition; ADR-0003 Fixed Tick, Time and Determinism; ADR-0005 Signal and Command Contracts; ADR-0007 Combat Data Model; ADR-0013 Content Test and Bot Harness
- GDD sync: checked data-config-pipeline.md, combat-damage.md; no GDD name is changed by this ADR. Differences from architecture.md are listed under Neutral.
