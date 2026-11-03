# ADR-0002: Catalogue Storage Format, Manifest and Validation

## Status
Proposed

## Date
2026-11-03

## Last Verified
2026-11-03 (against `docs/engine-reference/godot/` for Godot 4.7.2, `docs/architecture/architecture.md` v3 and ADR-0001 as Proposed)

## Decision Makers
- Author: `/architecture-decision`, run in autonomous mode (decisions logged in `production/session-logs/decision-log.md`)
- Engine specialist (godot-specialist): NOT ASSESSED in this run. See Validation Criteria, "Reviews still owed".
- Technical director (TD-ADR): NOT ASSESSED in this run. See Validation Criteria, "Reviews still owed".
- Acceptance: the user.

## Summary
The Data & Config catalogue needs a file format that can catch a missing field, a fractional integer and an unknown property, load from an explicit manifest in an Android export, and be proved unchanged after a battle. This ADR picks JSON data files read with `FileAccess` and `JSON`, one schema table per record type that drives parsing, a tiered validator and a deep snapshot, typed `RefCounted` records with read-only lists, and a CI content test that holds every owning GDD's layout, wave and balance rules, each proved on a broken fixture.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core (data loading and file access) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH. architecture.md rates the "Resources and file access" row MEDIUM, and the planned ADR row HIGH because export packing is unverified. The APIs used here all date from 4.0 and show no change in 4.5 to 4.7 in `breaking-changes.md`; the risk is in how an Android export packs and reads `res://`, which the pinned reference does not cover. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 `FileAccess.store_*` returns `bool`; 4.5 `duplicate_deep()`; 4.7 packed-array element writes skip setters), `deprecated-apis.md` (`duplicate()` on nested resources), `current-best-practices.md` (Resources 4.5+, Command Line, Platform 4.5+); no `modules/` file covers file access or data; `docs/architecture/architecture.md` v3 (Engine Knowledge Gap Summary, Module Ownership Foundation, Data Flow 4 and 7, B0, B4, Required ADRs, QQ-03, QQ-19); `docs/architecture/tr-registry.yaml`; ADR-0001 |
| **Post-Cutoff APIs Used** | None. Used: `FileAccess.open()`, `FileAccess.get_open_error()`, `FileAccess.get_as_text()`, `JSON.new()`, `JSON.parse()`, `JSON.get_error_line()`, `JSON.get_error_message()`, `JSON.data`, `Array.make_read_only()`, `Dictionary.make_read_only()`, `StringName`, `RefCounted`, `is_finite()`, `ResourceLoader.exists()`, `PackedScene.instantiate()`. `duplicate_deep()` is deliberately not used (Decision 6). `FileAccess.store_*` is not used, so its 4.4 return-type change does not apply. |
| **Verification Required** | (1) That `assets/data/catalogue/*.json` is packed into an Android export and reads back through `FileAccess` on a device (tests X1, X2). (2) The number type `JSON.parse()` gives for `50` on 4.7.2, `int` or `float` (test E1; the design works either way). (3) What `JSON.parse()` does with a repeated key in one object (test E2). (4) What a write to an Array made read-only with `make_read_only()` does on 4.7.2: error, no-op or both (test E3). (5) That `-s <script>` runs from an exported `.pck` given with `--main-pack` (test X1). None of these is in the pinned reference, and none can be checked offline. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (App Lifecycle, Composition Root and Fatal Path), Proposed. It fixes that AppRoot loads the catalogue once in `_ready()`, that a failed load goes to the app `FatalLatch` and the code-built `FatalScreen`, and that the Builder routes a null resolver to fatal. This ADR must not be implemented before ADR-0001 is Accepted. |
| **Enables** | ADR-0005 (stat accessor; this ADR fixes the record classes and the key-bearing fields it reads), ADR-0007 (harness; this ADR names the content test, the snapshot test and three lint rules it must host), ADR-0009 (enemy entity; this ADR fixes the typed Stage geometry it reads) |
| **Blocks** | The Data & Config epic and every story that reads a record, loads the catalogue or adds a content rule. No epic or story exists yet (`production/epics/` is absent), so no story is blocked by path today. |
| **Ordering Note** | Write after ADR-0001 and before ADR-0005. The Android proof (X2) needs an export preset and a device, so it runs at the Technical Setup gate, not before the first story. |

## Context

### Problem Statement
Every MVP system reads authored values from one catalogue. The Data GDD leaves the format to this ADR with one hard test: the format, or a check on top of it, must catch a missing field, a fractional integer and an unknown property (Rule 8 is meaningless if a typo silently becomes a default). The catalogue must load from an explicit manifest, never a directory scan, and must work in an Android export, where files are renamed and packed. Definitions must stay read-only after load, and a deep-snapshot test must prove it. The rules in four other GDDs (Enemy & Wave layout and waves, Tower, Hero, Battle HUD) are checked by a CI content test that has no design yet.

This must be fixed before any code, because every record class, fixture and test depends on it.

### Current State
No code. `src/` holds only a `CLAUDE.md`. No `assets/` folder and no `export_presets.cfg` exist. `addons/gdUnit4/` is present. ADR-0001 is Proposed and names `Catalogue.load(manifest)`, `LoadResult` and `ValidationError` without defining them.

### Constraints
- **Engine**: Godot 4.7.2, GDScript. `assert` is stripped in exports (ADR-0001). GDScript has no `const` instance fields, so read-only is a contract plus a test. In 4.7, writing one element of a packed array does not call the property's setter (`breaking-changes.md`), so setters cannot guard packed data.
- **Architecture**: no autoloads (ADR-0001). The Catalogue is created once, held by AppRoot, and shared by every battle. It must hold no reference to a per-battle latch or handler; the Builder makes a fresh `StatAccessor` per battle over it (ADR-0005), injected with that battle's `FatalLatch`.
- **GDD tiers**: two tiers only, no warnings. Boot-fatal invariants in the validator; everything else in the CI content test (Data Rule 7, 9).
- **Tests**: logic tests build fixture catalogues in code with no file I/O (Data Rule 12). CI tests are deterministic.
- **Team**: solo part-time developer. No converter, no custom editor, no schema versioning (Data GDD, "Deliberately not built").

### Requirements
- Typed read-only records keyed by a stable snake_case ID unique across all types; references by typed ID (TR-data-001).
- Detect a missing field, a fractional integer and an unknown property (TR-data-002).
- Load from an explicit manifest, never a directory scan, and load in an Android export (TR-data-003).
- Collect every error as `{code, source, record_id, field}` before failing, in tiers (TR-data-005).
- Prove the catalogue is unchanged after a battle with a deep snapshot (TR-data-007).
- A CI content test that opens each `scene_ref` and applies layout, wave, rationale and balance rules (TR-data-013), including Hero and HUD rules, each proved on a broken fixture (TR-hero-014, TR-hud-016).
- Stage gameplay geometry on the Stage record, not the scene (TR-enemy-001).
- Load median at most 1000 ms on an Adreno 5xx-class device; edit to in-game at most 10 s (TR-data-015).

## Decision

### 1. Format: JSON files, read as text
- Catalogue data lives in `res://assets/data/catalogue/` as UTF-8 `.json` files. Each file holds one JSON object: `{"type": "<record_type>", "records": [ {...}, ... ]}`. One file holds one record type. Several files may share a type (for example one file per stage later).
- Record types at MVP: `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`.
- Files are read with `FileAccess.open(path, FileAccess.READ)` and `get_as_text()`, then parsed with a `JSON` instance (`JSON.new().parse(text)`), so a parse failure reports its line. Files are never loaded through `load()` or `ResourceLoader`.
- **Why JSON, not typed Resources.** A `.tres` load fills a missing `@export` field with its default, drops a property the script does not declare, and stores a fractional value into an `int` field after converting it. All three facts vanish before any check can see them, and in an export the text is converted to binary, so no check can read the source either. A JSON object keeps every key and every number as written, so all three are visible. JSON also cannot carry a script, and diffs cleanly. The GDD's "typed Resources" recommendation was conditional on passing that test; it does not.
- **Numbers.** The parser treats a JSON number as `int` or `float` (E1 records which; the code accepts both). An `int` field accepts a finite number equal to its floor and stores `int(v)`; any other value is `fractional_int`. So `50` and `50.0` pass and `50.5` fails. All ceilings are at most 1,000,000, far inside exact float range. A `float` field stores the value as GDScript `float` (64-bit).
- **Shapes.** A point is `[x, y]` (two numbers). `pin_rect` is `{"min": [x, y], "max": [x, y]}`. A `pin_exclusion` shape is `{"a": [x, y], "b": [x, y], "radius": r, "hand": "right" | "left" | "both"}`. A Stage `scene_ref` is a `res://` path string ending in `.tscn`; it names a scene, not a record, so Rule 3's "never by file path" does not apply to it.

### 2. The manifest
- `res://assets/data/catalogue/manifest.json` holds `{"files": ["res://assets/data/catalogue/towers.json", ...]}`. Paths are full, case-exact, inside `res://assets/data/catalogue/` and end in `.json`.
- The loader reads only the files the manifest lists, in listed order. No runtime code under `src/` uses `DirAccess` (lint rule L-DATA-1).
- A data file not in the manifest is never read (Data AC 9). The CI content test lists the folder (a directory scan is allowed in CI, never at runtime) and fails on a data file the manifest omits, or on a manifest path whose case differs from the file on disk. Godot packs `res://` case-sensitively, while the dev machine (macOS) is not, so a case slip would pass in the editor and fail on Android.

### 3. One schema table per record type
- `src/foundation/data/schema.gd` holds one `const` table per record type and per owned sub-record (`tower_level`, `wave_group`, `pin_shape`). Each entry gives the field name, its kind (`INT`, `FLOAT`, `BOOL`, `STRING`, `ID_REF` with target type, `POINT`, `RECT`, `LIST` of a kind or sub-record, `TAGS`), whether it is required, and its domain bounds from the Data GDD's field-domain table (min, max, and whether each end is inclusive).
- The same table drives three things: the parser that builds records, the validator, and the snapshot (Decision 6). A field added to the table is parsed, checked and snapshotted with no other change. This is the GDD's extension rule made mechanical: an owning GDD adds a field by changing the domain table, the schema entry and the record class in one change.
- Role fields (`splash_radius`, `slow_strength`, `slow_duration`) are optional in the schema; the tag tier decides when each is required or forbidden.
- `rationale` is a required `STRING` on every record. `visual_key` is a required `STRING` on tower levels, Enemy and Hero. Non-empty `rationale` is the content test's check (Data Rule 9), not the validator's.

### 4. Typed records
- Record classes extend `RefCounted`, one per type, in `src/foundation/data/records/`: `TowerRecord` (holds `Array[TowerLevel]`), `EnemyRecord`, `WaveRecord` (holds `Array[WaveGroup]`), `StageRecord`, `HeroRecord`, `BurstRecord`, `InputRecord`, plus `TowerLevel`, `WaveGroup`, `PinShape`. B0 left `Resource` or `RefCounted` open; this ADR picks `RefCounted`.
- Each field is a typed `var` with the schema's name. IDs and ID references are `StringName`. Points are `Vector2`, `pin_rect` is `Rect2`, tags are `Array[StringName]`.
- `StageRecord` holds the gameplay geometry as required fields: `path_points: Array[Vector2]`, `slot_positions: Array[Vector2]`, `path_width: float`, `requires_bend: bool`, `early_call_seconds_per_gold: float`, `hero_start: Vector2`, `pin_rect: Rect2`, `pin_exclusion: Array[PinShape]`, plus `scene_ref: String`, `wave_ids: Array[StringName]`, `starting_gold: int`, `starting_lives: int`. The stage scene holds only the look (TR-enemy-001). Lists use typed `Array`, not packed arrays, so `make_read_only()` applies to them.
- A record holds the IDs it references, never the record object, so records stay plain and the snapshot is a tree.
- After a record passes validation, the builder that makes it calls `make_read_only()` on every `Array` and `Dictionary` it holds, nested ones included. That turns an accidental `levels.append()` or `path_points[0] = ...` into an engine error at the point of the write (E3 records the exact behaviour). Scalar fields have no runtime guard; the contract, lint rule L-DATA-2 and the snapshot test cover them.

### 5. Load and validation
- Two entry points, one path:
  - `Catalogue.load_manifest(manifest_path: String) -> LoadResult` reads the manifest and each listed file into documents `{source: String, type: String, records: Array}`, then calls `from_documents`. This is the only code that touches `FileAccess`.
  - `Catalogue.from_documents(docs: Array[Dictionary]) -> LoadResult` validates and builds. Logic tests call it with documents made by fixture factories, with a label as `source` and no file I/O (Data Rule 12).
- The method is named `load_manifest`, not `load` as in architecture.md, because `load` is a GDScript global function and a method of that name shadows it. ADR-0001 now says only "load the catalogue", so it needs no change.
- Load is synchronous, runs once from AppRoot `_ready()` (ADR-0001), and has no reload. The GDD states map to the result: Unloaded before the call, Loading during it, Ready when `ok` is true and `catalogue` is set, Failed when `ok` is false. A failed result carries no catalogue, so no lookup can be served (Data AC 5).
- **Tier 0, manifest and files.** Any error here stops the load before any record check. Codes: `manifest_unreadable`, `manifest_invalid` (not JSON, no `files` list, a non-string entry), `manifest_empty`, `manifest_path_repeated`, `manifest_path_outside` (outside the data folder or not `.json`), `file_unreadable`, `file_empty`, `file_invalid_json` (line in `detail`), `file_bad_shape` (no `type` or `records`, or `records` not a list), `unknown_record_type`, and `record_type_empty` (a known type with no records once every file is parsed).
- **Tiers 1 to 4, records.** All run, and all errors are collected. Within one field, the first failing check wins and later checks on that field are skipped, so one typo gives one error.
  1. **Structure**: `id_missing`, `id_format` (not lowercase snake_case), `id_duplicate` (one error per record sharing the ID, across all types), `unknown_property` (a key the record's own type does not declare), `field_missing`, `wrong_kind` (a string where a number belongs), `list_empty`.
  2. **Numbers and geometry**: `non_finite` first, then `fractional_int`, then `out_of_bounds` against the domain table. Then the boot-fatal geometry rules: `path_too_short` (fewer than 2 points), `path_repeated_point` (two equal consecutive points), `coord_out_of_range` (outside -2,000 to 2,000), `rect_inverted` (`pin_rect` min not below max), `shape_invalid` (radius not above 0, or an unknown hand).
  3. **Tags**: `tag_unknown` (and that record's role checks are skipped), `role_tag_count` (a tower without exactly one role tag), `role_field_missing` (on any level), `role_field_without_tag`.
  4. **References**: `ref_dangling`, `ref_wrong_type` (`burst_id` naming an enemy).
- `ValidationError` is a `RefCounted` value: `code: StringName`, `source: String` (file path or fixture label), `record_id: StringName` (empty for file errors), `field: StringName` (a path such as `levels[1].splash_radius`), and `detail: String`, a free-text note for the debug fatal screen only. Tests compare the first four fields; `detail` is never asserted.
- `LoadResult` is a `RefCounted` value: `ok: bool`, `errors: Array[ValidationError]` (made read-only before return), `catalogue: Catalogue` (null unless `ok`). On a failed load, AppRoot keeps the `LoadResult` and passes its errors to `FatalScreen.show_cause()`, which lists them in a debug build (ADR-0001 Decisions 1 and 6). Nothing else holds it.

### 6. Read-only proof: a schema-walk snapshot
- `CatalogueSnapshot.take(catalogue) -> Dictionary` walks every record in manifest order through the schema tables and builds a fresh tree of plain values (`int`, `float`, `bool`, `String`, `StringName`, `Vector2`, `Rect2`, and new `Array` and `Dictionary` containers). It holds no reference into the catalogue, so a later write to a record cannot change the snapshot.
- `CatalogueSnapshot.diff(before, after) -> Array[String]` returns the path of every value that differs, for example `wave:wave_03.groups[1].count`. Empty means unchanged.
- `duplicate_deep()` is not used. It is a `Resource` method (4.5), and records are `RefCounted`. Plain `duplicate()` on a nested `Array` is shallow and must never be used to take a snapshot. Because the walk is driven by the schema, a field added to the schema is in the snapshot with no change to the test.
- Tests: R1 (the detector self-test, Data AC 11) and the end-to-end battle check that Tower and Enemy & Wave stories own (Data deferred criteria).

### 7. The CI content test
- One integration suite, `tests/integration/content/test_content_real_data.gd`, loads the real manifest through `load_manifest`, then runs every content rule over the Ready catalogue and collects every `ValidationError` (same shape, same "collect all, then fail" rule). It fails if the list is not empty. There is no warning tier.
- **Rule sets, one per owning GDD**, in `tests/integration/content/rules/`: `content_rules_data.gd` (non-empty `rationale`; each `scene_ref` exists with `ResourceLoader.exists()`, loads as a `PackedScene` and instantiates, then is freed; manifest case and unlisted-file checks from Decision 2), `content_rules_input.gd` (exactly one Input record; `tap_slop > drag_slop`, see QQ-19 below), `content_rules_enemy_wave.gd` (L1 to L14 and the wave rules), `content_rules_tower.gd`, `content_rules_hero.gd` (exactly one Hero record and the hero and burst rules), `content_rules_hud.gd` (the HUD layout rules, at most 3 next-wave types, 6 waves, 10 lives). Each rule is a function `(catalogue, errors)` that appends `ValidationError` values with code `content_<rule>`, the stage or record ID, and the field.
- **Every rule is proved on a broken fixture.** For each rule, a unit test in `tests/unit/content/` builds a fixture catalogue through `from_documents` that breaks only that rule, and checks that the rule reports exactly that one error, and that the valid base fixture reports none (TR-hero-014; applied to every rule set).
- Rules that mirror runtime maths must call the runtime code (for example `TickMath.to_ticks` for spawn ticks, ADR-0004), never a copy of it, so the test and the game cannot disagree.
- Rules that need data from a later story (L10, L11, L14, intermission, `peak_alive_ub`, `burst_spike`) join the suite in the Tower and Hero stories, as the GDDs say. This ADR fixes where they go and how they are proved, not their bounds; the owning GDDs keep the bounds.
- **QQ-19, catalogue half.** The Data GDD's field table says `tap_slop > drag_slop` is not the boot validator's rule, and this ADR keeps that. The content test checks it, so real data with the slops swapped fails CI. If it still reaches a device, the Builder's null-resolver check sends it to the fatal screen (ADR-0001 Decision 2). Both halves are now closed.
- **Scene checks on the export.** The content test runs on the project, because gdUnit4 cannot run inside an exported build. Test X1 closes the gap for packing: it loads the catalogue and instances every `scene_ref` from an exported `.pck`.

### 8. Export
- The Android preset, and every later preset, exports all resources, adds the include filter `assets/data/catalogue/*.json`, and adds the exclude filter `tests/*, addons/gdUnit4/*, tools/ci/*`. The include filter is harmless if Godot already treats `.json` as a resource; it removes the question.
- A separate desktop preset, `ci_export_smoke`, includes `tools/ci/export_smoke.gd`. CI exports it with `--export-pack` and runs it headless with `--main-pack <file>.pck -s res://tools/ci/export_smoke.gd`. The script calls `Catalogue.load_manifest()`, instances every `scene_ref`, prints record counts and exits 0 on Ready, 1 otherwise (test X1).
- The first Android build repeats the check on a device (test X2), with a retained screenshot of a debug build showing the record counts.

### Architecture Diagram

```
 res://assets/data/catalogue/
   manifest.json ──► files[] (explicit, case-exact)
   towers.json  enemies.json  waves.json  stages.json  hero.json  input.json ...
        │  FileAccess.open + get_as_text          (load_manifest only)
        ▼
 documents [{source, type, records}] ◄──── fixture factories (tests, no file I/O)
        │
        ▼  Catalogue.from_documents
 ┌──────────────────────────── Validator (schema.gd drives every tier) ───────────┐
 │ Tier 0 manifest/files ──any error──► LoadResult{ok=false, errors}  (stop)      │
 │ Tier 1 structure · Tier 2 numbers+geometry · Tier 3 tags · Tier 4 references   │
 │        collect all ──any error──► LoadResult{ok=false, errors}                 │
 └────────────────────────────────────────────────┬───────────────────────────────┘
                                                  │ no errors
                                                  ▼
             typed RefCounted records, lists make_read_only()
                                                  │
                                                  ▼
                         LoadResult{ok=true, catalogue}
                                                  │
     AppRoot (ADR-0001) holds it ──► BattleBuilder.build(catalogue, stage_id, rng_seed, ...)
                                       └─► fresh StatAccessor(catalogue, battle latch) (ADR-0005)
     failed: AppRoot keeps LoadResult, app FatalLatch latched ──► FatalScreen lists errors (debug)

 CI only: test_content_real_data ── rule sets per GDD ── each rule has a broken-fixture test
          ci_export_smoke .pck ── load_manifest + instance scene_refs (X1)
```

### Key Interfaces

```gdscript
class_name Catalogue extends RefCounted
## Reads the manifest and every listed file, then validates. The only FileAccess user.
static func load_manifest(manifest_path: String) -> LoadResult
## Validates in-memory documents {source, type, records}. No file I/O.
static func from_documents(docs: Array[Dictionary]) -> LoadResult

## Typed lookups. Return null for an ID that is not of that type; never call a handler.
func tower(id: StringName) -> TowerRecord
func enemy(id: StringName) -> EnemyRecord
func wave(id: StringName) -> WaveRecord
func stage(id: StringName) -> StageRecord
func burst(id: StringName) -> BurstRecord
## All records of a type, in manifest order. Arrays are read-only.
func towers() -> Array[TowerRecord]
func enemies() -> Array[EnemyRecord]
func waves() -> Array[WaveRecord]
func stages() -> Array[StageRecord]
func heroes() -> Array[HeroRecord]      # the content test enforces exactly one
func bursts() -> Array[BurstRecord]
func inputs() -> Array[InputRecord]     # the content test enforces exactly one
## Non-fatal type check, for untrusted IDs.
func type_of(id: StringName) -> StringName   # &"" when unknown

class_name LoadResult extends RefCounted
var ok: bool
var errors: Array[ValidationError]      # read-only
var catalogue: Catalogue                # null unless ok

class_name ValidationError extends RefCounted
var code: StringName
var source: String
var record_id: StringName
var field: StringName
var detail: String                      # display only; never asserted

class_name CatalogueSnapshot extends RefCounted
static func take(catalogue: Catalogue) -> Dictionary
static func diff(before: Dictionary, after: Dictionary) -> Array[String]
```

The Builder takes `heroes()[0]` and `inputs()[0]`; the content test guarantees there is exactly one of each in real data. `is_tower(id)` and `level_count(def_id)` stay on the accessor (ADR-0005), which can build them on `type_of()` and `tower(id).levels.size()`. Names are proposed; QQ-16 may add a prefix (ADR-0007).

### Implementation Guidelines
1. Catalogue data must be JSON files under `res://assets/data/catalogue/`, read with `FileAccess` and parsed with a `JSON` instance. Catalogue records must never be `.tres` or `.res` files, and data files must never be loaded with `load()` or `ResourceLoader`.
2. `Catalogue.load_manifest()` must read only the files the manifest lists. No runtime code under `src/` may use `DirAccess` (lint L-DATA-1).
3. Every record field must be declared in `schema.gd`, and the parser, validator and snapshot must all read that table. A field must never be parsed, checked or snapshotted by hand-written code that bypasses it.
4. An `int` field must reject a non-integral number with `fractional_int`. A missing key must give `field_missing` and must never fall back to a default. A key the record's type does not declare must give `unknown_property`.
5. The validator must check `is_finite()` before bounds, must collect every record-tier error before failing, and must stop after Tier 0 if Tier 0 found any error.
6. Every `ValidationError` must carry `code`, `source`, `record_id` and `field`. Tests must compare those four and must never assert `detail`.
7. Records must extend `RefCounted`, must hold referenced records by `StringName` ID, and must have every `Array` and `Dictionary` made read-only before the catalogue is returned.
8. No code outside `src/foundation/data/` may assign to a record field or call a mutating method on a record's list (lint L-DATA-2, ADR-0007).
9. The `Catalogue` must hold no reference to a `FatalLatch`, a handler, a battle or a node. Lookups must return null on an unknown ID and never call a handler.
10. The snapshot must be built fresh by `CatalogueSnapshot.take()`. `duplicate()` must never be used for it.
11. Every content rule must have a unit test that breaks only that rule on a fixture and sees exactly its one error. A content rule that mirrors runtime maths must call the runtime function.
12. Logic tests must build catalogues with `from_documents` and fixture factory functions. Only the integration and content suites may read files.
13. Every export preset must include `assets/data/catalogue/*.json` and exclude `tests/*`, `addons/gdUnit4/*` and `tools/ci/*`, except `ci_export_smoke`, which includes `tools/ci/export_smoke.gd`.
14. A typed override in any of these classes must end with an explicit `return` (4.7 rule).

## Alternatives Considered

### Alternative 1: Typed Resources (`.tres`) with `@export` fields
- **Description**: One `Resource` script per record type; designers edit records in the inspector; the manifest lists `.tres` paths; `ResourceLoader.load()` builds them.
- **Pros**: Editor inspector editing, typed fields, and the GDD's first recommendation. Export packing of `.tres` is well trodden.
- **Cons**: A missing field takes its default, an unknown property is dropped, and a fractional number in an `int` field is converted, all during load and before any check. Exports convert text resources to binary, so no check can read the source. Resources can carry scripts. The read-only proof would need `duplicate_deep()` (4.5, post-cutoff) and its sub-resource rules.
- **Rejection Reason**: Fails TR-data-002, the one test the GDD makes mandatory.

### Alternative 2: Resources plus a schema check with sentinel defaults
- **Description**: Keep `.tres`, but give every field a sentinel default (NaN, -1) and check for sentinels after load.
- **Pros**: Keeps inspector editing. Catches most missing fields.
- **Cons**: Still blind to unknown properties and fractional integers. A sentinel can collide with a legal value (cost 0 and -1 are both bounds cases). Every field needs a hand-picked sentinel.
- **Rejection Reason**: Catches only one of the three required cases, and adds a rule per field.

### Alternative 3: `ConfigFile` (`.cfg`) data
- **Description**: Godot's INI-like format with Variant values; it keeps `int` and `float` apart as written.
- **Pros**: Distinguishes `50` from `50.0` natively. Missing and unknown keys are visible.
- **Cons**: Its values are parsed as Variant text, which can construct objects and resources. Nested lists of sub-records (levels, groups, shapes) are awkward to write by hand. Less familiar to outside tools.
- **Rejection Reason**: JSON passes the same test with a simpler, safer value model; the int check is one line.

### Alternative 4: A GDScript constant manifest instead of `manifest.json`
- **Description**: The file list is a `const` array in a script, so it cannot go missing in an export.
- **Pros**: One fewer file to read.
- **Cons**: Adding a stage would change code, so Data AC 14 ("`git diff` shows only a data file") fails.
- **Rejection Reason**: Breaks the tuning-loop rule.

### Alternative 5: Read-only by setters with a sealed flag
- **Description**: Every record field has a setter that reports an error once the record is sealed.
- **Pros**: Catches scalar writes at runtime.
- **Cons**: One setter per field (about 60). In 4.7, packed-array element writes skip setters, and an element write or `append()` on a typed `Array` changes the list in place without assigning the property, so lists still need another guard.
- **Rejection Reason**: High cost for partial cover. `make_read_only()` on lists, the lint and the snapshot test cover the same ground.

## Consequences

### Positive
- All three silent-default cases are caught at boot, with one error each, naming file, record and field.
- One schema table per type keeps the parser, validator and snapshot in step; adding a field is one change.
- Tests build catalogues with no file I/O, through the same validator the game uses.
- The content test gives every owning GDD one place to put its rules, and each rule is proved to fire.
- JSON data diffs cleanly and needs no import step, which helps the 10 s tuning loop.
- No post-cutoff API is used.

### Negative
- No inspector editing. Data is edited as text until a tool exists (QQ-14).
- The schema table duplicates the GDD's field-domain table in code. Each field change touches the GDD table, the schema and the record class.
- Hand-written JSON has no comments; `rationale` carries the "why" instead.
- A repeated key in one JSON object may be silently merged by the parser (E2). If E2 shows that, the content test adds a raw-text duplicate-key check.

### Neutral
- Records are `RefCounted`, not `Resource`, which settles B0's open choice.
- The method is `load_manifest`, not `load`, against architecture.md text.

## Risks
- **JSON files are not packed, or are packed under another path, in an Android export.** Mitigation: the explicit include filter, X1 in CI on every push, X2 on the first device build. If X2 fails, the fatal screen shows (no fallback), which is the correct failure.
- **Case mismatch between the manifest and the file on disk.** Mitigation: the content test compares names case-exactly; X1 runs against the case-sensitive `.pck`.
- **`JSON.parse()` number type changes between builds.** Mitigation: the int check accepts both `int` and `float` input. E1 records which one 4.7.2 gives.
- **`make_read_only()` write behaviour is softer than expected (a logged error, then the write is ignored).** That still blocks the write; the snapshot test is the proof either way. E3 records it.
- **Load time on a low-end device exceeds 1000 ms.** Unlikely at MVP size (seven types, about 40 records, a few tens of KB). Mitigation: measure at the first phone build (P1); if over, profile the validator before changing the format.
- **A content rule drifts from the runtime maths.** Mitigation: Guideline 11, rules call runtime functions.
- **`-s` with `--main-pack` is not supported on 4.7.2.** Then X1 uses an exported debug binary with a `--catalogue-smoke` user argument read by a small CI-only scene instead. X1 records which form works.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-001: typed read-only records keyed by a stable snake_case ID unique across all types; references by typed ID, never by file path | Decision 4: typed `RefCounted` records with `StringName` IDs; Tier 1 `id_format` and cross-type `id_duplicate`; Tier 4 `ref_dangling` and `ref_wrong_type`; records hold IDs, not paths or objects |
| data-config-pipeline.md | TR-data-002: detect a missing field, a fractional integer and an unknown property | Decision 1 and 5: JSON keeps all three visible; `field_missing`, `fractional_int` and `unknown_property` checks driven by the schema |
| data-config-pipeline.md | TR-data-003: explicit manifest, never a directory scan, loads in an Android export | Decision 2 and 8: `manifest.json`, no `DirAccess` (L-DATA-1), include filter, X1 in CI. **Android proof owed**: X2 at the first device build |
| data-config-pipeline.md | TR-data-005: collect every error as `{code, source, record_id, field}` before failing, in tiers | Decision 5: Tier 0 stops; Tiers 1 to 4 collect all; one error per field |
| data-config-pipeline.md | TR-data-007: read-only after load; deep-snapshot test proves the catalogue unchanged after a battle | Decision 4 and 6: read-only lists, lint L-DATA-2, schema-walk snapshot and `diff`; R1 self-test here, the battle run in the Tower and Enemy & Wave stories |
| data-config-pipeline.md | TR-data-013: CI content test opens each `scene_ref`, applies layout and wave rules, checks rationale and balance ranges | Decision 7: one suite, rule sets per GDD, scene instancing, rationale rule |
| data-config-pipeline.md | TR-data-015: load median at most 1000 ms on Adreno 5xx; edit to in-game at most 10 s | **Partial.** The design keeps load small and synchronous, with no import step and no scene loads at boot. Neither target can be measured until a device build exists (P1, P2) |
| enemy-wave.md | TR-enemy-001: the Stage record holds `path_points`, `slot_positions`, `path_width`, `requires_bend`, `early_call_seconds_per_gold`; the scene holds only the look | Decision 4: all are required typed fields on `StageRecord`; the scene is opened only for its look by the wrapper and by the content test |
| hero-system.md | TR-hero-014: content tests enforce hero and burst rules, each proven on a broken fixture | Decision 7: `content_rules_hero.gd`, exactly one Hero record, a broken-fixture unit test per rule. Rule bodies land in the Hero stories |
| battle-hud.md | TR-hud-016: content tests enforce HUD layout rules (slot bounds, clearances, at most 3 next-wave types, 6 waves, 10 lives) | Decision 7: `content_rules_hud.gd` with a broken-fixture test per rule. Rule bodies land in the HUD story |

Open questions closed: QQ-03 (format, missing and fractional detection, read-only proof, Android proof plan); QQ-19 catalogue half (content test). Data GDD open questions answered: "Snapshot mechanics, integer representation" (Decision 1 and 6) and "Scene checks run on the project, not the export" (Decision 7 and 8, X1).

## Performance Implications
- **CPU**: none per tick. Lookups are one `Dictionary` read.
- **Memory**: about 40 small records at MVP, well under 1 MB with the parsed JSON freed after build.
- **Load Time**: one synchronous load at boot. Estimated well under the 1000 ms target at MVP size; unmeasured (P1). No scene is instanced at boot.
- **Network**: none.

## Migration Plan
No code exists, so nothing migrates. When this ADR is Accepted, these documents need edits to match. This ADR does not make them:
1. `docs/architecture/architecture.md`: B0 sets record classes to `RefCounted`, adds `catalogue` and `detail` to `LoadResult` and `ValidationError`, and adds `CatalogueSnapshot`; Module Ownership (Catalogue row) changes `load(manifest)` to `load_manifest(path)` and the engine API cell to JSON plus `FileAccess`, dropping `duplicate_deep()`; Data Flow 4 step 2 uses `load_manifest`; QQ-03 and QQ-19 marked resolved by ADR-0001 and ADR-0002.
2. `design/gdd/data-config-pipeline.md`: the "Becomes an ADR" note and the Open Questions rows for storage format, snapshot mechanics and scene checks point to ADR-0002, and the recommendation reads JSON; Rule 7's "unknown properties (a field no record type declares)" becomes "a field the record's type does not declare"; the content test gains the exactly-one Input record, case-exact manifest and unlisted-file rules.
3. `design/gdd/input-gesture-resolver.md`: where it names `tap_slop > drag_slop`, add that the CI content test checks it and the Builder sends a null resolver to fatal.

## Validation Criteria
Headless gdUnit4 tests (ADR-0007 places them; names proposed):
- **V1 `test_validator_errors_table`** (Data AC 1 to 4): table-driven fixtures each give exactly their one `{code, source, record_id, field}`; five seeded errors give exactly those five.
- **V2 `test_validator_manifest_tier_stops`** (Data AC 5): empty manifest, empty type, repeated path, empty file, each beside a broken record, give one Tier 0 error and no record error; `catalogue` is null.
- **V3 `test_manifest_ignores_unlisted_file`** (Data AC 9, integration).
- **R1 `test_snapshot_detects_nested_change`** (Data AC 11): a change to `waves[0].groups[1].count` is reported by path; no change reports none.
- **R2 `test_record_lists_read_only`**: every record list reports `is_read_only()`.
- **C1 `test_content_real_data`** (integration): the real catalogue passes every rule.
- **C2 `test_content_rules_*`**: one broken fixture per rule, each giving exactly its one error.
- **E1 `test_json_number_type_probe`**, **E2 `test_json_duplicate_key_probe`**, **E3 `test_read_only_array_write_probe`**: each records the 4.7.2 behaviour, asserts nothing about which answer is right, and the result goes into `docs/engine-reference/godot/` with the date and version.
- **X1 `ci_export_smoke`** (CI, desktop `.pck`): exit 0 with the expected record counts; every `scene_ref` instances.
Manual evidence (`production/qa/evidence/`, first phone build):
- **X2**: a debug Android build reaches Ready and shows record counts (screenshot); a release build with one invalid record shows the fatal screen (shared with ADR-0001 V8).
- **P1**: five cold launches on one named Adreno 5xx-class device; median Loading to Ready logged against 1000 ms (Data AC 15).
- **P2**: edit one value, run, time noted against 10 s (Data AC 14).

**Reviews still owed.** This run had no way to spawn review agents, so the godot-specialist check (Step 5.5) and the technical-director TD-ADR gate (Step 5.6) did not run. Both must run before acceptance. `review_mode` is `full`, so TD-ADR is required. Questions for the godot-specialist: E1, E2, E3, the `.json` export packing default, and the `-s` with `--main-pack` form in X1.

## Related
- ADR-0001 (depends on): AppRoot load and kept `LoadResult`, app `FatalLatch`, `FatalScreen.show_cause()`, per-battle `StatAccessor`, Builder null-resolver fatal
- ADR-0005 (enabled): stat accessor built per battle over this catalogue
- ADR-0007 (enabled): hosts C1, C2, the snapshot test and lint rules L-DATA-1 and L-DATA-2
- ADR-0009 (enabled): reads `StageRecord` geometry
- `docs/architecture/architecture.md` v3: Module Ownership (Foundation), Data Flow 4 and 7, B0, QQ-03, QQ-14, QQ-16, QQ-19
- GDDs: `design/gdd/data-config-pipeline.md` (Rules 1 to 9, 12, 13; Edge Cases; AC 1 to 5, 9 to 11, 13 to 15), `design/gdd/enemy-wave.md` (Rules 2, 3; layout and wave rules), `design/gdd/tower-system.md`, `design/gdd/hero-system.md`, `design/gdd/battle-hud.md` (content rules), `design/gdd/input-gesture-resolver.md` (slop rule)
