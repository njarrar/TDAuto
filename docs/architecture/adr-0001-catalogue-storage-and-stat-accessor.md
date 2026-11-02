# ADR-0001: Catalogue Storage Format and Stat Accessor

## Status
Proposed

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
njarrar (project owner), technical-director and lead-programmer (architecture gates, 2026-11-02). Engine specialist and TD-ADR reviews are recorded under Related.

## Summary
The catalogue of authored gameplay values needs a file format that can show a missing field, a fractional integer and an unknown property, and a read-only lookup that every system uses. We store the data as JSON files listed in one manifest, check them against a schema table kept in code, and serve them as typed read-only `RefCounted` records through one `Catalogue` and one `StatAccessor`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (data loading, scripting) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH: Godot 4.7 is past the model's reliable knowledge. This ADR uses only long-stable APIs (`FileAccess`, `JSON`, `RefCounted`, typed GDScript). The risk is in what the pinned reference does not cover, listed in Verification Required |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 to 4.7), `deprecated-apis.md`, `current-best-practices.md`. There is no data or resource module reference |
| **Post-Cutoff APIs Used** | None. 4.7 changes checked and found not to apply: a typed-return override must now `return` explicitly (this ADR has no overrides); writing one element of a packed array no longer calls the property setter (records have no setters) |
| **Verification Required** | V1 to V4 below. **NOT SOURCEABLE** from `docs/engine-reference/godot/` (it has no JSON, file-read, export-filter or `Object.get` coverage): (V1) a JSON file under `res://data/catalogue/` is present in an Android and an iOS export with an explicit include filter, and `FileAccess` reads it; (V2) a parsed JSON number arrives as `float` on 4.7.2, so `3` reads as `3.0`; the integer check accepts an `int` or a finite whole `float` either way; (V3) `FileAccess.get_open_error()` and an instance parser's `JSON.get_error_line()` and `get_error_message()` report what the manifest tier needs; (V4) the per-call cost of `Object.get(StringName)` on the target phone. This ADR uses no `assert` at all, because the pinned reference does not say whether a release export keeps it (Data GDD Rule 10) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (signal and read signatures use the record and key names defined here), ADR-0004 (the harness builds fixture catalogues through `Catalogue.from_data`), ADR-0005 (runtime instances hold `def_id` and read through the accessor), ADR-0008 (the app root holds the `Catalogue`; the battle builder builds the `StatAccessor`) |
| **Blocks** | Epics for Data & Config, Enemy & Wave, Tower, Hero and Battle HUD (every system reads values through this ADR's types) |
| **Ordering Note** | Written first. V1 needs the phone spike (GF5), which now checks JSON export, not Resource export. V1 blocks only the export story (Data criterion 13); the rest of the decision does not wait for it. If V1 fails, the manifest keeps its shape and only the file location and export filter change |

## Context

### Problem Statement
Every gameplay number lives in data, not code (Data GDD Rule 1). Eight systems read it. The Data GDD requires a format that can detect a missing field, a fractional integer and an unknown property, because a silent default would corrupt balance and the hero-share measure (Rule 8). The GDD recommended typed Godot Resources and left the choice to this ADR. The architecture (GF9) decided that records are typed and read-only, not Dictionaries, because a Dictionary can be written (TR-data-005).

### Constraints
- Godot 4.7.2, GDScript, one developer, Android and iOS exports. No autoloads, no event bus (architecture layer rules).
- The simulation is `RefCounted` objects. The catalogue must build with no scene, no engine node and no file I/O in tests (Rule 12).
- `assert` must not carry any check (Rule 10: the check must survive release builds).
- Edit-to-run in about 10 s (proposed, Rule 13). Boot load at most 1000 ms median on an Adreno 5xx-class phone (proposed, criterion 15).
- No retired IDs, no modifiers, no save schema until Vertical Slice.

### Requirements
- TR-data-001 to 008 and TR-enemy-008 (architecture Baseline).
- One failure handler, injected, called with a cause (Rules 8, 10).
- Every error is `{code, source, record_id, field}`; all errors are collected; manifest errors stop record checks (Rule 7).
- The `Stage` record carries `path_points` and `slot_positions` (A3, accepted).
- The accessor takes a read context and a key, and returns the type the key table declares. A modifier can slot in behind it with no call-site change (Rule 10).

## Decision

### 1. Storage: JSON files, one manifest, no directory scan

Data lives under `res://data/catalogue/` as JSON text files.

- `manifest.json`: `{"files": ["towers.json", "enemies.json", "waves.json", "stages.json", "heroes.json", "bursts.json", "input.json", "options.json"]}`. Paths are relative to the manifest. The loader opens only listed files (Rule 4). A repeated path is a manifest error.
- Each data file: `{"kind": "tower", "records": [ {...}, {...} ]}`. `kind` is one of `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`, `options`. `input` and `options` hold exactly one record.
- A record is an object. Numbers are JSON numbers. `path_points`, `slot_positions` and each `pin_rect` and `pin_exclusion` coordinate are arrays of numbers (`[x, y]` pairs). `tags` is an array of strings. References are ID strings.
- The data files are listed in the export filter by an explicit `data/catalogue/*.json` include pattern, set in the export presets (V1).

**Why not typed `Resource` (`.tres`) files.** The Data GDD warned that a typed resource may supply a default for a missing field. How Godot 4.7.2 saves, loads and defaults `@export` properties of a custom `Resource` is **NOT SOURCEABLE** from the pinned reference, and a format whose rule for "absent" is unverified cannot carry TR-data-004. A JSON key is either in the file or not, and we check that ourselves. That is the deciding reason. Two further points come from memory and are unverified: a `.tres` can embed a script while a JSON file cannot (the GDD's reason to prefer JSON if content ever comes from outside the build), and JSON diffs more cleanly in git, which serves the 10 s tuning loop.

**The GDD's "not built: JSON import pipelines".** That line means a pipeline that converts JSON or spreadsheets into another format. This ADR reads JSON directly and converts nothing, so it does not contradict it. The Data GDD wording is clarified in its next edit (Migration Plan).

### 2. Validation: a schema table in code, run on plain data

A `CatalogueSchema` (a `RefCounted` with static data) declares, for each record kind, every field with: a type (`int`, `float`, `bool`, `string`, `string_array`, `point_list`, `ref:<kind>`, `rect`, `shape_list`, or a nested list type), whether it is required, and its domain (min, max, inclusive flags) taken from the Data GDD field-domain table. The tag table and the stat-key table live beside it.

`CatalogueValidator.validate(data: Dictionary, source_label: String) -> Array[CatalogueError]` works on plain `Dictionary` and `Array` values. It does the following, in this order:

1. **Manifest tier** (stops everything after it): empty manifest, repeated path, unreadable or unparseable file, a file with no `kind` or an unknown `kind`, a kind with no records.
2. **Record tier**, collecting every error: ID format (lowercase `snake_case`), duplicate IDs across all kinds, non-empty `rationale`, **missing field** (key absent), **unknown property** (key not in the schema), non-finite number (`is_finite` first, before any other number check), **fractional integer** (an `int` field whose value is not an `int` and not a float with `v == floor(v)`), domain bounds, empty lists, `path_points` length and repeated consecutive points, coordinate range, `pin_rect` order, tag rules (exactly one role tag; role fields present only with their tag and on every level; **an unknown tag gives one error and skips that record's role checks**, Rule 7), reference resolution and reference type.

No default is ever filled in. A value that fails is an error, never a repair (Rule 8).

`CatalogueError` is a small `RefCounted` with `code: StringName`, `source: String`, `record_id: StringName`, `field: StringName`. Codes are constants on the class.

### 3. Typed read-only records

After validation succeeds, a `CatalogueBuilder` turns the plain data into typed records. Each record is a `RefCounted` subclass with typed members set once in `_init` from validated values and **no setters**: `TowerDef`, `TowerLevelDef`, `EnemyDef`, `WaveDef`, `WaveGroupDef`, `StageDef`, `PinShape`, `HeroDef`, `BurstDef`, `InputDef`, `OptionsDef`.

- Members are prefixed with an underscore only where a method must wrap them. Public fields are typed and documented, and a caller must never assign them. GDScript has no read-only member, so enforcement is the rule plus the snapshot test (Data GDD Rule 6, criterion 11), as the GDD states.
- Any member that is a collection is exposed through a method that returns a copy (`StageDef.path_points() -> PackedVector2Array`, `WaveDef.groups() -> Array[WaveGroupDef]`, `TowerDef.level(n: int) -> TowerLevelDef`, `TowerDef.level_count() -> int`). A method returning an `Array` or `Dictionary` must return `.duplicate()` of it: returning the stored `Array` hands out a reference. The copy is shallow, which is fine because its elements are read-only records. Packed arrays are also returned with `.duplicate()`, so the rule does not depend on their copy behaviour (memory says copy-on-write; unverified). Callers cannot reach the stored collection.
- `Catalogue` holds the records by ID in private dictionaries. It has no method that returns the dictionaries.
- Integers are stored as `int` after the whole-number check passes. Floats as `float`.

### 4. Catalogue and the loader

```
res://data/catalogue/*.json --(FileAccess + JSON)--> plain Dictionary
        --> CatalogueValidator --> errors? --> failure handler (boot fatal)
        --> CatalogueBuilder --> Catalogue (Ready, immutable)
```

- `static func CatalogueLoader.load_manifest(manifest_path: String, on_failure: Callable) -> Catalogue` is the only code that opens a file. It parses each file with an instance parser (`JSON.new()` then `parse()`), not `JSON.parse_string`, so a parse error carries its line and message. On any error it calls `on_failure` once with the whole `Array[CatalogueError]` and returns `null`. The app root owns the call (Rule 5, ADR-0008) and treats `null` as the boot Fatal.
- `Catalogue.from_data(data: Dictionary, source_label: String, on_failure: Callable) -> Catalogue` runs the same validator and builder on a Dictionary built in code. Tests and the harness (ADR-0004) use it. No file I/O.
- The app root holds the `Catalogue` across Retry and hands it to the battle builder. The battle builder builds one `StatAccessor` per battle with that battle's fatal handler and hands the `Catalogue` and the accessor to consumers (Rule 12, ADR-0008). **No autoload.**

**Scene checks and export (Open Question A5).** The content test opens every `scene_ref` on the project in CI, because the test runner cannot run on an exported build. That stays the check for scene content. The manual export check (Data criterion 13 and V1) covers what only an export can show: that the manifest and data files are packed and read. A broken scene that slips through still gives the fatal screen at stage start (Rule 9). We judge this enough for MVP: the risk an export adds is packing, and packing is what the manual check tests.

### 5. The stat accessor

```
class_name StatAccessor extends RefCounted

func _init(catalogue: Catalogue, on_failure: Callable) -> void
func get_float(ctx: ReadContext, key: StringName) -> float
func get_int(ctx: ReadContext, key: StringName) -> int

class_name ReadContext extends RefCounted
var def_id: StringName
var level: int = 0                 # 0 means "no level"; towers pass 1..level_count
var entity: RefCounted = null      # live instance (tower, hero or enemy); null for a HUD cost preview
```

`entity` is `RefCounted`, not an enemy type: Rule 10 keeps the slot for "towers near the hero", so it may hold a tower, a hero or an enemy. It is unused at MVP. The Stat and Modifier ADR (Vertical Slice) may narrow it. This keeps Foundation free of any class from ADR-0005.

- A `StatKey` table in `CatalogueSchema` maps each key to: the record kinds it applies to, the member name, and the declared type (`int` or `float`). It matches the Data GDD's MVP stat-key table. Role keys (`splash_radius`, `slow_strength`, `slow_duration`) also require the tower's role tag.
- At MVP the accessor returns the base value from the record. A modifier layer later wraps the same two functions; no call site changes.
- A **bad call** is: unknown key, a key not applicable to the record kind or role, a level out of range or given for a kind with no levels, a missing level for a tower, an unresolved `def_id`, or `get_int` called on a float key (or the reverse). A bad call: (a) calls `on_failure` with a `CatalogueError` naming the cause, **every time**; the accessor cannot see the Fatal latch, and the handler is idempotent (architecture 3.6), so a second bad call adds nothing; (b) returns a typed zero (`0` or `0.0`), so the calling function runs to its end (architecture GF8). The typed zero narrows the GDD's "unspecified" to one fixed value, but **no caller may use it**: Rule 10 still holds, and code must not branch on a zero read. The check is an `if`, never `assert`.
- The `Catalogue` also exposes `is_tower(def_id) -> bool` (never fails), `level_count(def_id) -> int`, and typed lookups `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`, `options`. A lookup of an unknown ID calls the failure handler the same way and returns `null`.
- Callers read at use time and never cache, except `max_hp` once at spawn (Data GDD Rule 10).

### 6. Storage form of stage geometry (A3)

`StageDef` carries `path_points() -> PackedVector2Array`, `slot_positions() -> PackedVector2Array`, `path_width: float`, `hero_start: Vector2`, `pin_rect: Rect2` and `pin_exclusion() -> Array[PinShape]`, in the 540 by 960 field units. They live in `stages.json`, not in the stage scene, because the builder runs with no scene (Data GDD, "Stage visuals are not catalogue values").

### 7. Snapshot for the read-only test

`Catalogue.snapshot() -> Dictionary` returns a deep plain-data copy (ints as `int`, floats as `float`, collections copied, including wave groups). It is for tests only. Criterion 11's detector self-test and the end-to-end battle test compare snapshots (Data GDD Rule 6). A battle harness snapshot (ADR-0004) is separate.

### 8. File and code locations

- Data: `res://data/catalogue/` (manifest plus the eight files).
- Code: `res://src/data/` (`catalogue.gd`, `catalogue_loader.gd`, `catalogue_validator.gd`, `catalogue_builder.gd`, `catalogue_schema.gd`, `catalogue_error.gd`, `stat_accessor.gd`, `read_context.gd`, and one file per record class).
- Tests: `res://tests/unit/data/` (fixtures built in code) and `res://tests/integration/data/` (real files). The content test (TR-enemy-008) lives in `res://tests/integration/content/`.

### Architecture Diagram

```
 app root (ADR-0008)
   |  load(manifest, on_failure)
   v
 CatalogueLoader --FileAccess/JSON--> plain data --> CatalogueValidator --errors--> on_failure
                                                         | ok
                                                         v
                                               CatalogueBuilder --> Catalogue (read-only)
                                                                       |  injected by builder
        tests: Catalogue.from_data(dict) -----------------------------+--> StatAccessor(ctx, key)
                                                                       |--> direct lookups (Stage, Wave, Input, Options)
```

### Key Interfaces

```gdscript
class_name Catalogue extends RefCounted
static func from_data(data: Dictionary, source_label: String, on_failure: Callable) -> Catalogue
func tower(def_id: StringName) -> TowerDef
func enemy(def_id: StringName) -> EnemyDef
func wave(wave_id: StringName) -> WaveDef
func stage(stage_id: StringName) -> StageDef
func hero(def_id: StringName) -> HeroDef
func burst(def_id: StringName) -> BurstDef
func input() -> InputDef
func options() -> OptionsDef
func is_tower(def_id: StringName) -> bool
func level_count(def_id: StringName) -> int
func snapshot() -> Dictionary    # tests only
```

`StatAccessor`, `ReadContext` and `CatalogueError` are as above. The signatures in architecture section 4.1 are updated to match (the `Catalogue` returns are typed, A3 and GF9).

### Implementation Guidelines
- Code must never use `assert` to check catalogue data or an accessor call.
- Code must never assign to a record member or mutate a collection returned by a record method.
- Code must never read a JSON file outside `CatalogueLoader`.
- Code must never scan a directory for data files.
- Code must never fill in a default for a missing or invalid field.
- Code must never reach the catalogue through an autoload or a global; it comes from the builder.
- A new field is added to the schema table and the validator in the same change (Data GDD extension rule); the loader and accessor contract stay as they are.
- Public classes and methods must carry doc comments.
- Every record class and the validator must be unit-testable with `Catalogue.from_data` and no file I/O.
- Use typed arrays (`Array[TowerLevelDef]`) and typed variables throughout.

## Alternatives Considered

### Alternative 1: Typed `Resource` subclasses saved as `.tres`
- **Description**: `TowerDef extends Resource` with `@export` members, edited in the inspector, loaded with `load()`.
- **Pros**: Editor inspector; engine type checks on load; the GDD's first recommendation.
- **Cons**: Behaviour for a missing or unknown property is **NOT SOURCEABLE** from the pinned reference, and the GDD itself flags a silent default. From memory, unverified: a `.tres` can embed a script, and its text format is noisier to diff.
- **Rejection Reason**: It cannot carry TR-data-004 without a second check that re-derives presence from the file text, which is the JSON route with extra steps.

### Alternative 2: JSON read into Dictionaries used directly as records
- **Description**: Parse and validate, then pass the Dictionaries around.
- **Pros**: Least code.
- **Cons**: A Dictionary can be written by any caller, which breaks TR-data-005, and every read is an untyped `Variant` (architecture GF9).
- **Rejection Reason**: Rejected at the architecture gate (GF9).

### Alternative 3: Catalogue as GDScript constants in code
- **Description**: `const TOWERS = {...}` in `.gd` files.
- **Pros**: Parsed at build; no file I/O or export filter concern.
- **Cons**: Violates "no gameplay number in code" (Rule 1); a data edit becomes a code edit and shows up in code review as logic; no clean path to the 10 s tuning loop with a data-only diff.
- **Rejection Reason**: Contradicts the Data GDD's purpose.

## Consequences

### Positive
- Presence, unknown properties and fractional integers are checked by our own code against one schema table, independent of how any engine loader defaults.
- Records are typed, read-only by construction (no setters, copies out) and testable with no file I/O.
- One accessor and one key table; a modifier layer slots in behind it.
- Data diffs are one line per value.

### Negative
- We write and maintain a schema table, a validator and a builder (about 600 lines of GDScript). A Resource design would still need its own presence check (TR-data-004), so the extra cost over it is smaller than that.
- No inspector editing; designers edit JSON by hand (accepted: one developer).
- Read-only is by convention plus a test, not by the language.
- The schema table and the record classes can drift apart; a unit test must assert that every schema field has a matching record member and the reverse.

## Risks
- **V1: JSON is missing from an Android or iOS export.** Mitigation: the explicit include filter; the loader fails loudly with a manifest error and the generic fatal screen; the phone spike (GF5) and Data criterion 13 test it before any content depends on it.
- **V2: number typing.** If the parser does not return whole numbers as `float` on 4.7.2, nothing breaks: the check accepts an `int` or a finite whole `float`. A unit test on the first story pins which one arrives.
- **V4: per-call cost of `Object.get`.** It returns a `Variant` and bypasses static typing, so a wrong member name fails only at runtime (the schema-versus-record test guards that). Mitigation: if profiling on the phone shows a cost, the accessor switches to a `match` on the key that reads each typed member directly. Measured on the first phone build.
- **Checks dropped in release.** Mitigation: no `assert` anywhere in the catalogue code; Data criterion 13 checks a bad accessor call in a release export.
- **Schema drift.** Mitigation: the schema-versus-record unit test above.
- **Fatal reads continue.** The typed zero lets the caller finish after a Fatal. Mitigation: callers check `halted()` at tick-slot edges (ADR-0003, GF8).
- **Stage geometry in JSON is hard to author by eye.** Mitigation: the content test (TR-enemy-008) enforces layout rules; a plotting tool is optional tooling, unscheduled.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | Rule 1, 2, 3: all authored values in the catalogue; stable snake_case IDs; typed references (TR-data-001) | `kind`-tagged JSON records, ID-format and reference-type checks in the validator |
| data-config-pipeline.md | Rule 4, 5: explicit manifest; load once, all or nothing (TR-data-002) | `manifest.json`; `CatalogueLoader.load_manifest` returns a full `Catalogue` or `null` and calls the handler |
| data-config-pipeline.md | Rule 7, 8: collect every error with `{code, source, record_id, field}`; no fallbacks (TR-data-003) | `CatalogueValidator` and `CatalogueError`; no default filling |
| data-config-pipeline.md | ADR must detect a missing field, a fractional integer and an unknown property (TR-data-004) | Key-presence, whole-number and key-set checks against the schema table |
| data-config-pipeline.md | Rule 6: read-only after load (TR-data-005) | Typed records with no setters, copies out, `snapshot()` test |
| data-config-pipeline.md | Rule 10, 11: one accessor `(context, key)` returning the declared type; key vocabulary (TR-data-006) | `StatAccessor`, `ReadContext`, `StatKey` table; typed zero after a bad call |
| data-config-pipeline.md | Rule 12: injection, not a global; fixtures built in code (TR-data-007) | Builder hands the `Catalogue` down; `Catalogue.from_data` with no I/O |
| data-config-pipeline.md | Android and iOS export loads it; 10 s edit-to-run; defined storage form for stage geometry (TR-data-008) | Explicit export include filter (V1); JSON text files; `StageDef` geometry form |
| enemy-wave.md | Content test enforces layout rules on real data, in CI not at boot (TR-enemy-008) | Records and `StageDef` geometry are readable by the content test through `Catalogue`; the scene check stays in the test, not at boot |

## Performance Implications
- **CPU**: One parse and validation pass at boot. At about 20 stages, 6 enemies, a few towers, a few hundred wave groups the file set is far below 1 MB; the 1000 ms device budget is proposed and measured on the first phone build. Accessor reads are a dictionary lookup plus one `Object.get` read through a `Variant`; the cost is unmeasured (V4).
- **Memory**: The records only; the parsed plain data is dropped after the build.
- **Load Time**: Boot only. Never during a battle.
- **Network**: None.

## Migration Plan
No code exists yet. When this ADR is accepted, update these to match it:

- `docs/architecture/architecture.md`:
  - Section 4.1: typed `Catalogue` returns, `ReadContext.entity: RefCounted`, and `Catalogue.from_data`. Drop the "missing-field defaults tested on 4.7.2" note, which this ADR makes moot.
  - Module Ownership: the Validator row becomes `validate(data, source_label) -> Array[CatalogueError]`, and the Catalogue row lists `FileAccess` and `JSON` in place of `ResourceLoader`.
  - Required ADRs: in the ADR-0001 row, drop the same note.
  - GF5 and Open Question A7: the spike checks JSON export, not Resource export.
  - Open Question A5: answered here.
- `design/gdd/data-config-pipeline.md`:
  - The "Becomes an ADR" line: "decided: JSON plus a code schema, see ADR-0001".
  - The storage-format Open Questions row and the snapshot row: answered by ADR-0001.
  - "Deliberately not built: JSON import pipelines" becomes "pipelines that convert JSON or spreadsheets into another format".

## Validation Criteria
- Data GDD criteria 1 to 8, 11, 12 pass in `tests/unit/data/` with fixtures built in code, and criteria 9 and 10 in `tests/integration/data/`.
- A schema-versus-record unit test passes.
- Criterion 13 (release build with one invalid record shows the fatal screen) and criterion 15 (median load time) pass on the first phone build; V1 is confirmed by an Android and an iOS export.
- If V1 fails after the spike, this ADR is revised, not worked around in a caller.

## Related
- Architecture: `docs/architecture/architecture.md` sections 3.4, 3.6, 4.1; Gate Findings GF3, GF8, GF9; Open Questions A3, A5.
- Data GDD: `design/gdd/data-config-pipeline.md` (storage-format row of the Open Questions is answered here).
- Depended on by: ADR-0002, 0004, 0005, 0008.
- Reviews, 2026-11-02: engine specialist (godot-specialist) found two blocking items, the typed `EnemyInstance` entity and the typed-zero wording, both fixed in this draft, plus minor notes folded into Risks and Verification. TD-ADR: CONCERNS, seven items, all revised in this draft. The TD recommends Accept once revised, with V1 tracked against the export story only.
