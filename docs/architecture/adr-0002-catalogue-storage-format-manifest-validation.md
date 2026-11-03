# ADR-0002: Catalogue Storage Format, Manifest and Validation

## Status
Proposed

## Date
2026-11-03

## Last Verified
2026-11-03 (against `docs/engine-reference/godot/` for Godot 4.7.2, `docs/architecture/architecture.md` v3 and ADR-0001 as Proposed; revised after TD-ADR and godot-specialist reviews)

## Decision Makers
- Author: `/architecture-decision`, run in autonomous mode (decisions logged in `production/session-logs/decision-log.md`)
- Engine specialist (godot-specialist): CONCERNS, advisory only. See Reviews.
- Technical director (TD-ADR): CONCERNS. See Reviews.
- Acceptance: the user.

## Summary
The Data & Config catalogue needs a file format that can catch a missing field, a fractional integer and an unknown property, load from an explicit manifest in an Android export, and be proved unchanged after a battle. This ADR picks JSON data files read with `FileAccess` and `JSON`, one schema table per record type that drives parsing, a tiered validator and a deep snapshot, typed `RefCounted` records with read-only lists, and a CI content test that holds every owning GDD's layout, wave and balance rules, each proved on a broken fixture.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core (data loading and file access) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH. architecture.md rates "Resources and file access" MEDIUM and the planned ADR HIGH, because export packing is unverified. The APIs used date from 4.0 and show no 4.5 to 4.7 change in `breaking-changes.md`; the risk is how an Android export packs and reads `res://`, which the pinned reference does not cover. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 `FileAccess.store_*` returns `bool`; 4.5 `duplicate_deep()`; 4.7 packed-array element writes skip setters), `deprecated-apis.md`, `current-best-practices.md`; no `modules/` file covers file access; `architecture.md` v3 (Gap Summary, Module Ownership, Data Flow 4 and 7, B0, B1, Required ADRs, QQ-03, QQ-19); `tr-registry.yaml`; ADR-0001 |
| **Post-Cutoff APIs Used** | None. Used: `FileAccess.open()`, `get_open_error()`, `get_as_text()`, `JSON.new()`, `JSON.parse()`, `get_error_line()`, `get_error_message()`, `JSON.data`, `Array.make_read_only()`, `Dictionary.make_read_only()`, `Array.assign()`, `Object.get_property_list()`, `StringName`, `RefCounted`, `is_finite()`, `typeof()`, `ResourceLoader.exists()`, `PackedScene.instantiate()`. `duplicate_deep()` is not used (Decision 6). `FileAccess.store_*` is not used, so its 4.4 change does not apply. |
| **Verification Required** | All from the reviewers' memory, none in the pinned reference, none checkable offline. (1) `.json` files are packed into an Android export and read back through `FileAccess` (X1, X2). (2) `JSON.parse()` likely returns every number as `float` (E1). (3) A repeated key likely keeps the last value, silently (E2). (4) After `make_read_only()`, an index write likely aborts the running function while `append()` logs and goes on (E3). (5) `-s <script>` runs from a `.pck` given with `--main-pack` (X1). (6) `res://` in a `.pck` is case-sensitive, likely true; Linux CI is case-sensitive too, and the check stays for macOS dev runs (C1). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed): AppRoot loads the catalogue once in `_ready()`, keeps a failed `LoadResult` for the code-built `FatalScreen`, and the Builder sends a null resolver to fatal. Not to be built before ADR-0001 is Accepted. |
| **Enables** | ADR-0004 (must expose its tick length as a constant; Decision 3), ADR-0005 (accessor over these records), ADR-0007 (hosts the content test, snapshot test, schema test and two lint rules), ADR-0009 (reads typed Stage geometry) |
| **Blocks** | The Data & Config epic and every story that reads a record, loads the catalogue or adds a content rule. No epic or story exists yet, so none is blocked by path today. |
| **Ordering Note** | Write after ADR-0001, before ADR-0005. The interval floor check waits for ADR-0004's tick constant. X1 first runs at the Technical Setup gate; X2 needs a device. |

## Context

### Problem Statement
Every MVP system reads authored values from one catalogue. The Data GDD leaves the format to this ADR with one hard test: the format, or a check on top of it, must catch a missing field, a fractional integer and an unknown property, or Rule 8 means nothing. The catalogue must load from an explicit manifest, never a directory scan, and work in an Android export, where files are renamed and packed. Definitions must stay read-only after load, proved by a deep snapshot. Four other GDDs (Enemy & Wave, Tower, Hero, Battle HUD) put rules in a CI content test that has no design yet. Every record class, fixture and test depends on this, so it comes before code.

### Current State
No code. `src/` holds only a `CLAUDE.md`. No `assets/` folder and no `export_presets.cfg`. `addons/gdUnit4/` is present. architecture.md names `Catalogue.load(manifest)`, `LoadResult` and `ValidationError` without defining them.

### Constraints
- **Engine**: `assert` is stripped in exports (ADR-0001). GDScript has no `const` instance fields, so read-only is a contract plus a test. In 4.7 a packed-array element write skips the property setter, so setters cannot guard lists. `set()` on an undeclared name does nothing and reports nothing.
- **Architecture**: no autoloads. AppRoot holds one Catalogue shared by every battle; it holds no per-battle latch or handler. The Builder makes a fresh `StatAccessor` per battle over it (ADR-0001, ADR-0005).
- **GDD tiers**: boot-fatal invariants in the validator, everything else in the CI content test; no warnings (Data Rules 7, 9).
- **Tests**: logic tests build catalogues in code with no file I/O (Data Rule 12); CI tests are deterministic.
- **Team**: solo part-time developer. No converter, no custom editor, no schema versioning.

### Requirements
TR-data-001, 002, 003, 005, 007, 013, 015, TR-enemy-001, TR-hero-014 and TR-hud-016, as quoted in GDD Requirements Addressed.

## Decision

### 1. Format: JSON files, read as text
- Data lives in `res://assets/data/catalogue/` as UTF-8 `.json` files. Each file is one object with exactly two keys, `{"type": "<record_type>", "records": [ ... ]}`. One file holds one type; several files may share a type.
- Record types at MVP: `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`.
- Files are read with `FileAccess` and parsed with a `JSON` instance, so a parse failure reports its line. A leading UTF-8 byte-order mark is stripped before parsing, so an editor that adds one does not break boot. Data files are never loaded through `load()` or `ResourceLoader`.
- **Why JSON, not typed Resources.** A `.tres` load fills a missing `@export` field with its default, drops a property the script does not declare, and converts a fractional value stored into an `int` field. All three vanish before any check runs, and an export converts the text to binary, so no check can read the source. A parsed JSON object keeps every key, and a fractional number stays visible as a non-integral value, so all three cases can be caught. JSON carries no script and diffs cleanly. The GDD recommended Resources only if they passed that test; they do not.
- **Numbers.** `JSON.parse()` likely returns every number as `float` (E1); the code accepts `int` or `float`. An `int` field takes a finite number equal to its floor and stores `int(v)`; any other number is `fractional_int`. So `50` and `50.0` pass and `50.5` fails. Every ceiling is at most 1,000,000, exact in a 64-bit float. A `float` field stores a 64-bit `float`.
- **Shapes.** A point is `[x, y]`. `pin_rect` is `{"min": [x, y], "max": [x, y]}`. A `pin_exclusion` shape is `{"a": [x, y], "b": [x, y], "radius": r, "hand": "right" | "left" | "both"}`. `scene_ref` is a `res://` path ending in `.tscn`; it names a scene, not a record, so Rule 3's "never by file path" does not apply.
- **Keys and IDs.** JSON keys are compared as `String` against schema names. Each ID string becomes a `StringName` once, at build. Every lookup by ID uses `StringName` only.

### 2. The manifest
- `manifest.json` in the data root holds `{"files": ["res://assets/data/catalogue/towers.json", ...]}`: full, case-exact paths inside the data root, ending in `.json`.
- The loader reads only the listed files, in order. No runtime code under `src/` uses `DirAccess` (lint L-DATA-1).
- The data root is an argument, defaulting to `res://assets/data/catalogue/`, so V3 can point a manifest at `res://tests/fixtures/catalogue/`.
- The content test lists the real data root only, with no recursion (a scan is allowed in CI, never at runtime). It fails on a data file the manifest omits and on a manifest path whose case differs from the file on disk.

### 3. One schema table per record type
- `src/foundation/data/schema.gd` holds one `const` table per record type and owned sub-record (`tower_level`, `wave_group`, `pin_shape`). Each entry gives the field name, kind (`INT`, `FLOAT`, `BOOL`, `STRING`, `ID_REF` with target type, `POINT`, `RECT`, `LIST` of a kind or sub-record, `TAGS`), whether it is required, the domain bounds from the Data GDD table (min, max, each end inclusive or not), and for `LIST` and `TAGS` a `min_count`.
- `min_count`: `path_points` 2; `slot_positions`, `wave_ids`, `levels` and `groups` 1; enemy `tags` 0. `pin_exclusion` is 0 for now; whether a stage needs at least one shape is an open question for the Hero or Enemy & Wave owner.
- The floor "one tick" on interval fields reads ADR-0004's tick constant, not a literal 1/60, because the tick rate is still ADR-0004's choice (QQ-01) and a literal would drift from it.
- The same table drives the parser, the validator and the snapshot (Decision 6). An owning GDD adds a field by changing its domain table, the schema entry and the record class in one change.
- Role fields (`splash_radius`, `slow_strength`, `slow_duration`) are optional in the schema; the tag tier decides when each is required or forbidden.
- `rationale` is a required `STRING` on every record; `visual_key` on tower levels, Enemy and Hero. Non-empty `rationale` is a content rule (Data Rule 9).

### 4. Typed records
- Record classes extend `RefCounted`, in `src/foundation/data/records/`: `TowerRecord` (holds `Array[TowerLevel]`), `EnemyRecord`, `WaveRecord` (holds `Array[WaveGroup]`), `StageRecord`, `HeroRecord`, `BurstRecord`, `InputRecord`, plus `TowerLevel`, `WaveGroup`, `PinShape`. This settles B0's open choice.
- Each field is a typed `var` named as in the schema. IDs and references are `StringName`; points `Vector2`; `pin_rect` `Rect2`; tags `Array[StringName]`. `InputRecord` holds `drag_slop`, `tap_slop`, `edge_reject_margin`, `left_handed` and `reduce_motion`.
- `StageRecord` holds the gameplay geometry as required fields (`path_points: Array[Vector2]`, `slot_positions: Array[Vector2]`, `path_width`, `requires_bend`, `early_call_seconds_per_gold`, `hero_start`, `pin_rect`, `pin_exclusion: Array[PinShape]`) plus `scene_ref`, `wave_ids`, `starting_gold`, `starting_lives`. The scene holds only the look (TR-enemy-001). Lists are typed `Array`, not packed arrays, so `make_read_only()` applies.
- A record holds the IDs it references, never the record object, so the snapshot is a tree.
- The parser fills the property's own typed array with `append()` or `assign()`, never assigns an untyped array, and never fills a temporary that it then copies.
- After a record passes validation, the parser calls `make_read_only()` on each stored `Array` and `Dictionary`. The call is not recursive: each nested container gets its own call, and it does not freeze the `TowerLevel` or `WaveGroup` objects inside a list. Scalar fields have no runtime guard; the contract, lint L-DATA-2 and the snapshot cover them.

### 5. Load and validation
- Three entry points, one path:
  - `load_manifest(manifest_path, data_root)` reads bytes only: the manifest text and each listed file's text. It reports `manifest_unreadable` itself, then calls `from_texts`. It is the only code that touches `FileAccess`.
  - `from_texts(manifest_text, file_texts, data_root)` runs the file tier (Tier 0a) with no I/O. `file_texts` maps each path to its text; a listed path with no entry is `file_unreadable`. It then calls `from_documents`. Data AC 5 tests run against it.
  - `from_documents(docs)` runs the type tier (Tier 0b) and Tiers 1 to 4. Each document is `{source, type, records}`. Fixture factories return a real `Array[Dictionary]` with a label as `source`.
- The method is `load_manifest`, not architecture.md's `load`, because `load` is a GDScript global function and a method of that name shadows it.
- Load is synchronous, runs once from AppRoot `_ready()`, and never reloads. Unloaded is before the call; Loading during it; Ready when `ok`; Failed when not. A failed result carries no catalogue, so it serves no lookup.
- **Tier 0a, manifest and files** (stop on any error): `manifest_unreadable`, `manifest_invalid` (not JSON, not an object, no `files` list, a non-string entry), `manifest_empty`, `manifest_path_repeated`, `manifest_path_outside` (outside `data_root` or not `.json`), `file_unreadable`, `file_empty`, `file_invalid_json` (line in `detail`), `file_bad_shape` (`typeof(json.data)` is not `TYPE_DICTIONARY`, which catches `null` and `[]`; no `type` or `records`; `records` not a list; or any other key), `unknown_record_type`.
- **Tier 0b, types** (stop on any error): `record_type_empty` (a type with no records), `record_count` (not exactly one Input record, or not exactly one Hero record). The Builder reads one of each with no selector, so a second record would be silently ignored, which is a fallback.
- **Tiers 1 to 4, records.** All run and all errors are collected. Per field, the first failing check wins, so one typo gives one error.
  1. **Structure**: `id_missing`, `id_format` (not lowercase snake_case), `id_duplicate` (one error per record sharing the ID, across all types), `unknown_property` (a key the record's own type does not declare; `field` holds that key), `field_missing`, `null_value` (JSON `null`), `wrong_kind` (checked by `typeof()`: a `bool`, string or list where a number belongs, and so on), `list_too_short` (below `min_count`).
  2. **Numbers and geometry**: on numbers that passed the kind check, `non_finite`, then `fractional_int`, then `out_of_bounds`. Then `path_repeated_point`, `coord_out_of_range` (outside -2,000 to 2,000), `rect_inverted` (`pin_rect` min not below max), `shape_invalid` (radius not above 0, or an unknown hand).
  3. **Tags**: `tag_unknown` (that record's role checks are skipped), `role_tag_count`, `role_field_missing` (on any level), `role_field_without_tag`.
  4. **References**: `ref_dangling`, `ref_wrong_type`.
- `ValidationError` (`RefCounted`): `code: StringName`, `source: String`, `record_id: StringName` (empty for file errors), `field: StringName` (a path such as `levels[1].splash_radius`), `detail: String` (display only). Tests compare the first four, never `detail`.
- `LoadResult` (`RefCounted`): `ok`, `errors: Array[ValidationError]` (read-only), `catalogue` (null unless `ok`). On a failed load AppRoot keeps it and passes its errors to `FatalScreen.show_cause()` (ADR-0001).

### 6. Read-only proof: a schema-walk snapshot
- `CatalogueSnapshot.take(catalogue)` walks every record through the schema tables and builds a fresh tree of plain values and new containers. It holds no reference into the catalogue.
- `CatalogueSnapshot.diff(before, after)` returns the path of each differing value, such as `wave:wave_03.groups[1].count`. Empty means unchanged.
- No `duplicate()` or `duplicate_deep()` call copies the fields of a `RefCounted` object, so neither can snapshot these records, even if 4.5 also added deep copies to `Array` and `Dictionary`. The walk follows the schema, so a new field is in the snapshot with no test change.

### 7. The CI content test
- `tests/integration/content/test_content_real_data.gd` loads the real manifest, runs every content rule over the Ready catalogue, collects every `ValidationError`, and fails if any exist. No warning tier.
- **Rule sets, one per owning GDD**, in `tests/integration/content/rules/`. Each rule is a function `(catalogue, errors)` that appends errors coded `content_<rule>`.
  - `content_rules_data.gd`: non-empty `rationale`; each `scene_ref` checked with `ResourceLoader.exists()` and `load()`, instanced, then freed; the manifest case and unlisted-file checks; a raw-text scan that fails on a key repeated in one JSON object, since the parser likely keeps the last value silently (E2).
  - `content_rules_input.gd`: `tap_slop > drag_slop` (QQ-19).
  - `content_rules_enemy_wave.gd` (L1 to L14, wave rules), `content_rules_tower.gd`, `content_rules_hero.gd`, `content_rules_hud.gd` (layout, at most 3 next-wave types, 6 waves, 10 lives).
- **Every rule is proved on a broken fixture**: a unit test in `tests/unit/content/` breaks only that rule through `from_documents` and sees exactly its one error; the valid base fixture sees none.
- A rule that mirrors runtime maths calls the runtime function (such as `TickMath.to_ticks`, ADR-0004). Geometry rules compare the stored `Vector2` values, which are 32-bit, with each other, never with raw JSON numbers.
- Rules needing later data (L10, L11, L14, intermission, `peak_alive_ub`, `burst_spike`) join in the Tower and Hero stories. The owning GDDs keep the bounds.
- **QQ-19, catalogue half.** The Data GDD says `tap_slop > drag_slop` is not the boot validator's rule; this ADR keeps that. The content test fails it in CI; on a device, ADR-0001's null-resolver check sends it to the fatal screen.
- gdUnit4 cannot run in an export, so the content test runs on the project; X1 covers packing.

### 8. Export
- Every player-facing preset exports all resources, includes `res://assets/data/catalogue/*.json`, and excludes `res://tests/*`, `res://addons/gdUnit4/*` and `res://tools/ci/*`. The include is harmless if `.json` already exports.
- A desktop preset, `ci_export_smoke`, includes `res://tools/ci/export_smoke.gd` and has no `tools/ci` exclude, since an exclude beats an include. It is exported with `--export-pack` and run headless with `--main-pack <file>.pck -s res://tools/ci/export_smoke.gd`. The script loads the catalogue, instances every `scene_ref`, prints record counts and exits 0 on Ready, 1 otherwise (X1).
- X1 runs at the Technical Setup gate, then on release tags or nightly, until a CI job with export templates exists. X2, on a device, stays manual.

### Architecture Diagram

```
 res://assets/data/catalogue/ (data_root)
   manifest.json ──► files[] (explicit, case-exact)
        │  load_manifest: FileAccess reads bytes only
        ▼
 from_texts(manifest_text, file_texts, data_root)   Tier 0a files ──error──► stop
        ▼                                            ◄── fixture texts (no I/O)
 from_documents([{source, type, records}])          Tier 0b types ──error──► stop
        │                                            ◄── fixture factories (no I/O)
        ▼  schema.gd drives every tier
 Tier 1 structure · 2 numbers+geometry · 3 tags · 4 references ── collect all
        │ any error ──► LoadResult{ok=false, errors} ──► AppRoot keeps it ──► FatalScreen
        ▼ none
 typed RefCounted records, containers make_read_only() ──► LoadResult{ok=true, catalogue}
        ▼
 AppRoot holds it ──► BattleBuilder.build(catalogue, stage_id, rng_seed, ...)
                        └─► fresh StatAccessor(catalogue, battle latch)  (ADR-0005)

 CI: test_content_real_data ── rule set per GDD ── broken-fixture test per rule
     ci_export_smoke .pck ── load + instance scene_refs (X1)
```

### Key Interfaces

```gdscript
class_name Catalogue extends RefCounted
const DATA_ROOT := "res://assets/data/catalogue/"
## Reads bytes, then calls from_texts. The only FileAccess user.
static func load_manifest(manifest_path: String, data_root: String = DATA_ROOT) -> LoadResult
## Tier 0a with no I/O. file_texts maps path -> text.
static func from_texts(manifest_text: String, file_texts: Dictionary, data_root: String = DATA_ROOT) -> LoadResult
## Tier 0b and Tiers 1 to 4. docs are {source, type, records}.
static func from_documents(docs: Array[Dictionary]) -> LoadResult

## Typed lookups. Null for an ID not of that type; never call a handler.
func tower(id: StringName) -> TowerRecord
func enemy(id: StringName) -> EnemyRecord
func wave(id: StringName) -> WaveRecord
func stage(id: StringName) -> StageRecord
func hero(id: StringName) -> HeroRecord
func burst(id: StringName) -> BurstRecord
## All records of a type, in manifest order. Read-only.
func towers() -> Array[TowerRecord]
func enemies() -> Array[EnemyRecord]
func waves() -> Array[WaveRecord]
func stages() -> Array[StageRecord]
func heroes() -> Array[HeroRecord]      # exactly one (Tier 0b)
func bursts() -> Array[BurstRecord]
func inputs() -> Array[InputRecord]     # exactly one (Tier 0b)
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

`is_tower(id)` and `level_count(def_id)` belong to the accessor (B1, ADR-0005), built on `type_of()` and `tower(id).levels.size()`. Names are proposed; QQ-16 may add a prefix (ADR-0007).

### Implementation Guidelines
1. Catalogue data must be JSON under the data root, read with `FileAccess` and parsed with a `JSON` instance. Records must never be `.tres` or `.res`, and data files must never go through `load()` or `ResourceLoader`.
2. Only `load_manifest()` may touch `FileAccess`, and it must read only listed files. No runtime code under `src/` may use `DirAccess` (L-DATA-1).
3. Every record field must be in `schema.gd`; the parser, validator and snapshot must all read that table and nothing else.
4. Every schema entry must match a declared property of its record class by name and type, in both directions (`test_schema_matches_record_classes`), because `set()` on a wrong name fails silently and leaves a default.
5. A missing key must give `field_missing`, never a default. An undeclared key must give `unknown_property`. A non-integral number in an `int` field must give `fractional_int`.
6. The validator must check kind with `typeof()` before `is_finite()`, and `is_finite()` before bounds. It must collect every record-tier error, and stop after Tier 0a or 0b on any error there.
7. JSON keys must be compared as `String`; each ID must become a `StringName` once; lookups by ID must use `StringName` only.
8. The parser must fill each property's own typed array with `append()` or `assign()`, then call `make_read_only()` on the stored container and on every nested one.
9. No code outside `src/foundation/data/` may assign a record field or mutate a record's list (L-DATA-2, ADR-0007).
10. The `Catalogue` must hold no `FatalLatch`, handler, battle or node, and lookups must return null on an unknown ID.
11. The snapshot must be built by `CatalogueSnapshot.take()`, never by `duplicate()` or `duplicate_deep()`.
12. Every content rule must have a unit test that breaks only that rule and sees exactly its one error. A rule mirroring runtime maths must call the runtime function.
13. `scene_ref` must be checked with `ResourceLoader.exists()` and `load()`, never `FileAccess.file_exists()`, because exports remap `.tscn`.
14. Logic tests must build catalogues through `from_texts` or `from_documents`. Only the integration and content suites may read files.
15. Export filters must use the `res://` prefix as in Decision 8.
16. A typed override must end with an explicit `return` (4.7 rule).

## Alternatives Considered

### Alternative 1: Typed Resources (`.tres`) with `@export` fields
- **Description**: A `Resource` script per type, edited in the inspector, listed by the manifest, loaded by `ResourceLoader`.
- **Pros**: Inspector editing; the GDD's first suggestion; well-trodden export.
- **Cons**: Missing field, unknown property and fractional int are all lost during load; exports turn the text binary; Resources can carry scripts.
- **Rejection Reason**: Fails TR-data-002, the GDD's one mandatory test.

### Alternative 2: Resources with sentinel defaults
- **Description**: Keep `.tres`, give every field a sentinel (NaN, -1), check for sentinels after load.
- **Pros**: Keeps the inspector; catches most missing fields.
- **Cons**: Blind to unknown properties and fractional ints; sentinels can clash with legal values; one hand-picked sentinel per field.
- **Rejection Reason**: Catches one of the three required cases.

### Alternative 3: `ConfigFile` (`.cfg`)
- **Description**: Godot's INI-like format with Variant values; keeps `int` and `float` apart.
- **Pros**: Tells `50` from `50.0`; missing and unknown keys are visible.
- **Cons**: Variant text can build objects and resources; nested sub-records are awkward by hand.
- **Rejection Reason**: JSON passes the same test with a simpler, safer value model.

### Alternative 4: A GDScript constant manifest
- **Description**: The file list is a `const` array in code.
- **Pros**: Cannot go missing in an export.
- **Cons**: Adding a stage changes code, so Data AC 14 fails.
- **Rejection Reason**: Breaks the tuning-loop rule.

### Alternative 5: Setters with a sealed flag
- **Description**: Each field's setter reports an error once the record is sealed.
- **Pros**: Catches scalar writes at runtime.
- **Cons**: About 60 setters. Packed-array element writes skip setters (4.7), and `append()` or an index write on a typed `Array` never assigns the property.
- **Rejection Reason**: High cost, partial cover; read-only containers, lint and snapshot do the job.

## Consequences

### Positive
- All three silent-default cases fail at boot with one error each, naming file, record and field.
- One schema table keeps parser, validator and snapshot in step.
- Tests build catalogues with no file I/O, through the same validator the game uses, Tier 0 included.
- Every owning GDD has one place for its content rules, each proved to fire.
- JSON diffs cleanly and needs no import step, which helps the 10 s tuning loop.
- No post-cutoff API is used.

### Negative
- No inspector editing until a tool exists (QQ-14).
- The schema repeats the GDD's field-domain table in code; a field change touches the GDD, the schema and the record class.
- The schema and record classes can drift by name or type, and `set()` would hide it; `test_schema_matches_record_classes` must stay green.
- The parser must build typed arrays with care (Guideline 8); an untyped assign fails at runtime.
- A repeated JSON key is likely merged silently at parse; only the CI raw-text scan catches it.
- JSON has no comments; `rationale` carries the "why".

### Neutral
- Records are `RefCounted`, not `Resource`.
- `load_manifest` replaces architecture.md's `load`.

## Risks
- **JSON is not packed, or packed under another path, in an Android export.** Mitigation: explicit include filter, X1 at the gate and then on release tags or nightly, X2 on the first device. A failure shows the fatal screen, which is the right failure.
- **Manifest case differs from the file.** Mitigation: C1 compares names case-exactly; X1 reads a `.pck`.
- **Number type differs from E1's answer.** The int check accepts both.
- **A write after `make_read_only()` aborts the function, or logs and goes on.** Either blocks the write; the snapshot is the proof. E3 probes both forms.
- **Load over 1000 ms on a low-end device.** Unlikely at MVP size (seven types, about 40 records, tens of KB). Measure at P1; profile the validator before changing format.
- **A content rule drifts from runtime maths.** Mitigation: Guideline 12.
- **`-s` with `--main-pack` fails on 4.7.2.** Then X1 uses an exported debug binary with a CI-only `--catalogue-smoke` user argument.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-001: typed read-only records keyed by a stable snake_case ID unique across all types; references by typed ID, never by file path | Decision 4 and 5: typed records with `StringName` IDs; `id_format`, cross-type `id_duplicate`, `ref_dangling`, `ref_wrong_type`; records hold IDs only |
| data-config-pipeline.md | TR-data-002: detect a missing field, a fractional integer and an unknown property | Decision 1, 3 and 5: JSON keeps all three visible; `field_missing`, `fractional_int`, `unknown_property`; the schema test stops `set()` hiding a name slip |
| data-config-pipeline.md | TR-data-003: explicit manifest, never a directory scan, loads in an Android export | **Partial.** Decision 2 and 8: manifest, no `DirAccess`, include filter, X1. The Android proof (X2) is owed at Technical Setup |
| data-config-pipeline.md | TR-data-005: collect every error as `{code, source, record_id, field}` before failing, in tiers | Decision 5: Tiers 0a and 0b stop; Tiers 1 to 4 collect all; one error per field |
| data-config-pipeline.md | TR-data-007: read-only after load; deep snapshot proves the catalogue unchanged after a battle | Decision 4 and 6: read-only containers, L-DATA-2, schema-walk snapshot; R1 here, the battle run in Tower and Enemy & Wave stories |
| data-config-pipeline.md | TR-data-013: CI content test opens each `scene_ref`, applies layout and wave rules, checks rationale and balance ranges | Decision 7 |
| data-config-pipeline.md | TR-data-015: load median at most 1000 ms on Adreno 5xx; edit to in-game at most 10 s | **Partial.** Small synchronous load, no import step, no scene at boot. Measured only at P1 and P2 |
| enemy-wave.md | TR-enemy-001: the Stage record holds the gameplay geometry; the scene holds only the look | Decision 4: required typed fields on `StageRecord` |
| hero-system.md | TR-hero-014: content tests enforce hero and burst rules, each proven on a broken fixture | Decision 7: `content_rules_hero.gd` with a broken-fixture test per rule; exactly one Hero moves to Tier 0b. Rule bodies land in Hero stories |
| battle-hud.md | TR-hud-016: content tests enforce HUD layout rules | Decision 7: `content_rules_hud.gd`, broken-fixture test per rule. Rule bodies land in the HUD story |

QQ-03 is resolved except the Android proof, owed at Technical Setup (X2). QQ-19's catalogue half is closed by the content test. Data GDD open questions answered: snapshot mechanics and integer representation (Decisions 1, 6); scene checks on the project, not the export (Decisions 7, 8).

## Performance Implications
- **CPU**: none per tick; a lookup is one `Dictionary` read.
- **Memory**: about 40 small records at MVP, under 1 MB; parsed JSON is freed after build.
- **Load Time**: one synchronous load at boot, no scene instanced; estimated well under 1000 ms, unmeasured (P1).
- **Network**: none.

## Migration Plan
No code exists. When this ADR is Accepted, these edits are owed; this ADR does not make them:
1. `architecture.md`: B0 sets records to `RefCounted`, adds `catalogue` to `LoadResult`, `detail` to `ValidationError`, `reduce_motion` to `InputRecord`, and adds `CatalogueSnapshot`. The Catalogue row uses `load_manifest`, JSON plus `FileAccess`, drops `duplicate_deep()`, and moves `is_tower` and `level_count` to the accessor (B1). Data Flow 4 step 2 uses `load_manifest`. QQ-19 is marked resolved; QQ-03 stays open on the Android proof (X2) only.
2. `design/gdd/data-config-pipeline.md`: the "Becomes an ADR" note and the Open Questions rows on format, snapshot and scene checks point here and read JSON; Rule 7's "a field no record type declares" becomes "a field the record's type does not declare"; Rule 7 gains `record_count` (exactly one Input and one Hero) and the `min_count` values; the content test gains the case, unlisted-file and repeated-key rules.
3. `design/gdd/hero-system.md`: the "Hero records, exactly one" content row moves to boot (Tier 0b).
4. `design/gdd/input-gesture-resolver.md`: the slop rule notes the content test and the Builder's null-resolver fatal.
5. `docs/engine-reference/godot/current-best-practices.md`: probe results go under a new "Data and Containers (4.7)" heading, with the date and `4.7.2.stable`.

## Validation Criteria
Headless gdUnit4 tests (ADR-0007 places them; names proposed):
- **V1 `test_validator_errors_table`** (Data AC 1 to 4): table-driven fixtures each give exactly their one `{code, source, record_id, field}`; five seeded errors give those five.
- **V2 `test_validator_file_tier_stops`** (Data AC 5): through `from_texts`, with no I/O: empty manifest, repeated path, empty file, a bad envelope, and (through `from_documents`) an empty type and a second Input record, each beside a broken record, give one Tier 0 error, no record error and a null `catalogue`.
- **V3 `test_manifest_ignores_unlisted_file`** (Data AC 9, integration): `load_manifest` with `data_root` `res://tests/fixtures/catalogue/`, whose folder holds a valid unlisted file.
- **V4 `test_schema_matches_record_classes`**: every schema entry matches a `get_property_list()` entry by name and type, both ways.
- **V5 `test_id_keys_are_stringname`**: lookups with `StringName` IDs hit; the index holds no `String` keys.
- **R1 `test_snapshot_detects_nested_change`** (Data AC 11): a change to `waves[0].groups[1].count` is reported by path; no change reports none.
- **R2 `test_record_containers_read_only`**: every stored container, nested ones too, reports `is_read_only()`.
- **C1 `test_content_real_data`** (integration): the real catalogue passes every rule.
- **C2 `test_content_rules_*`**: one broken fixture per rule, exactly its one error.
- **E1 `test_json_number_type_probe`**, **E2 `test_json_duplicate_key_probe`**, **E3 `test_read_only_write_probe`** (index write and `append()` on `Array`, key write on `Dictionary`, and whether the next line runs): each prints its result to the CI log and asserts no answer. Results go to `current-best-practices.md` (Migration 5).
- **X1 `ci_export_smoke`** (desktop `.pck`, cadence in Decision 8): exit 0 with expected counts; every `scene_ref` instances.
Manual evidence (`production/qa/evidence/`, first phone build):
- **X2**: a debug Android build reaches Ready and shows record counts (screenshot); a release build with one invalid record shows the fatal screen (with ADR-0001 V8).
- **P1**: five cold launches on one named Adreno 5xx-class device; median Loading to Ready against 1000 ms (Data AC 15).
- **P2**: edit one value, run, time against 10 s (Data AC 14).

## Reviews
**TD-ADR: CONCERNS** (2026-11-03). Blocking items fixed; advisory items applied.
- T1 (blocking): `data_root` argument; V3 uses `res://tests/fixtures/catalogue/`; unlisted scan reads the real root only, no recursion. Fixed.
- T2 (blocking): `from_texts` seam runs Tier 0a with no I/O; V2 rewritten. Fixed.
- T3 (blocking): Guideline 4, V4, typed-array rule (Guideline 8); both in Negative. Fixed.
- T4: TR-data-003 Partial; QQ-03 kept open on X2. Applied.
- T5: `min_count` added; `pin_exclusion` minimum left open for its owner. Applied.
- T6: `hero(id)` added. Applied.
- T7: Migration Plan item 1. Applied.
- T8: floor reads ADR-0004's tick constant. Applied.
- T9: exactly one Input and one Hero made boot-fatal (`record_count`), since the Builder would ignore a second. Applied; Hero GDD sync item 3.
- T10: X1 cadence set. Applied.
- T11: case-sensitivity added to Verification Required. Applied.
- T12: extra envelope key is `file_bad_shape`; `unknown_property` names the key. Applied.

**godot-specialist: CONCERNS, advisory only** (2026-11-03). From memory, unverified by the pinned reference; probes kept.
- G-E1: "every number as written" claim removed; numbers likely float. Applied.
- G-E2: plan for last-wins; CI raw-text scan added. Applied.
- G-E3: E3 probes both write forms and whether code goes on. Applied.
- G1: `duplicate_deep()` reason restated. Applied.
- G2: a BOM is stripped before parsing. Applied.
- G3: `typeof(json.data)` checked first. Applied.
- G4: `typeof()` before `is_finite()`; `null_value` code. Applied.
- G5: one key rule (Guideline 7) and V5. Applied.
- G6: fill the stored typed array; factories return real `Array[Dictionary]`. Applied.
- G7: `make_read_only()` is not recursive and freezes no objects. Applied.
- G9: geometry rules compare stored `Vector2` values. Applied.
- G12: Guideline 13. Applied.
- G13: `res://` filter prefix; no `tools/ci` exclude on the smoke preset. Applied.
- G15: probe output to CI logs and to `current-best-practices.md`, not edited now. Applied.

## Related
- ADR-0001 (depends on); ADR-0004, ADR-0005, ADR-0007, ADR-0009 (enabled)
- `architecture.md` v3: Module Ownership, Data Flow 4 and 7, B0, B1, QQ-01, QQ-03, QQ-14, QQ-16, QQ-19
- GDDs: `data-config-pipeline.md` (Rules 1 to 13, Edge Cases, AC 1 to 15), `enemy-wave.md` (Rules 2, 3; layout and wave rules), `tower-system.md`, `hero-system.md`, `battle-hud.md` (content rules), `input-gesture-resolver.md` (slop rule)
