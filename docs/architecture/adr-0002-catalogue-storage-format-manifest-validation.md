# ADR-0002: Catalogue Storage Format, Manifest and Validation

## Status
Proposed. Revised the same day after TD-ADR CONCERNS (no blockers) and godot-specialist review (no blockers). Names follow `architecture.md` B0; on acceptance, B0, Data Flow 4 and QQ-03 are amended as Key Interfaces states.

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
njarrar (user), with technical-director and godot-specialist review. Drafted in autonomous mode from the approved Data & Config GDD and `docs/architecture/architecture.md` v4.

## Summary
The catalogue must catch a missing field, a fractional integer and an unknown property at load, load from an explicit manifest on an Android export, and stay read-only after load. This ADR stores records as JSON files under `res://data/`, listed in one manifest, validated as raw Dictionaries by a pure validator that collects every error, and only then turned into typed, read-only GDScript record objects, with Godot Resources kept for scenes and art.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (resources, file access, export) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH: resource and file-access behaviour changed in 4.4 to 4.5 (`FileAccess.store_*` returns `bool`, `duplicate_deep()` added), and export packing of non-resource files is not in the pinned reference |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (rows on `duplicate_deep()` and `FileAccess.store_*`), `deprecated-apis.md` (`duplicate()` for nested resources), `current-best-practices.md` (Resources 4.5+, command line `--import`); `architecture.md` (Engine Knowledge Gap Summary, B0, B1, QQ-03) |
| **Post-Cutoff APIs Used** | None required. `duplicate_deep()` is not needed, since records are not Resources. Reading uses `FileAccess.get_file_as_string()` and `JSON.parse_string()` / `JSON.new().parse()`, both pre-cutoff; their 4.7 behaviour on an Android export is probe Q1 |
| **Verification Required** | Q1 to Q4 in the appendix. Q1 (the manifest and every listed JSON file load from an Android export) gates acceptance for phone builds |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (AppRoot triggers the load in Boot; a failed load takes the fatal path) |
| **Enables** | ADR-0005 (the accessor reads these records), ADR-0007 (fixtures and the content test), ADR-0009 (Enemy and Stage records) |
| **Blocks** | Data & Config epic; every story that reads a catalogue value |
| **Ordering Note** | ADR-0001 must be Accepted before this one is implemented. Probe Q1 shares the first Android export with ADR-0001's P1 and ADR-0003's spike |

## Context

### Problem Statement
Every tunable number in the game lives in the catalogue (Data Rule 1), and Rule 8 forbids silent defaults in any build. The Data GDD leaves the storage format to this ADR with one hard condition: whatever is chosen must detect a missing field, a fractional integer and an unknown property, because typed Godot Resources may silently supply a default for a missing field, which would make "no fallbacks" meaningless. The format also decides how the catalogue survives export packing, how read-only is proved, and how fast the tuning loop is.

### Constraints
- No fallbacks in any build (Data Rule 8); the validator collects all errors, then fails (Rule 7).
- Explicit manifest, never a directory scan (Rule 4): exported builds rename and pack files.
- Load once, all or nothing, from AppRoot (Rule 5, ADR-0001).
- Read-only after load, proved by a test (Rule 6).
- Content ships inside the build: no mods, no downloads, no network at MVP.
- The tuning loop is edit, save, run, under about 10 s, with no code touched (Rule 13).
- A solo developer edits values by hand.

### Requirements
- TR-data-001: typed read-only records keyed by a stable snake_case ID, unique across types; typed ID references.
- TR-data-002: detect a missing field, a fractional integer and an unknown property.
- TR-data-003: explicit manifest; loads on an Android export.
- TR-data-005: collect every error as `{code, source, record_id, field}` in tiers, with the precedence the GDD states, and the `tap_slop > drag_slop` cross-field check.
- TR-data-007: read-only after load, proved by a deep-snapshot test.
- TR-data-013, TR-hero-014, TR-hud-016: a CI content test over the real records and stage scenes, per the Data GDD's content-test register.
- TR-data-015: Loading to Ready at most 1000 ms median on an Adreno 5xx-class device; edit to in-game at most 10 s.
- TR-enemy-001: the Stage record holds gameplay geometry; the scene holds only the look.

## Decision

### 1. Format: JSON files of records
Gameplay records live in JSON under `res://data/`, one file per record type: `towers.json`, `enemies.json`, `waves.json`, `stages.json`, `heroes.json`, `bursts.json`, `input.json`. Each file holds `{"records": [ ... ]}`, and each record is an object with `id`, `rationale` and the fields the Data GDD's record table lists. Stage scenes (the look) stay `.tscn` and are named by the Stage record's `scene_ref`, an asset reference stored as a `uid://` string so a moved scene does not break it.

JSON is chosen because all three conditions are visible in the parsed data itself: a missing field is an absent key, an unknown property is an extra key, and a fractional integer is a number whose value is not whole. One thing is not: a key repeated inside one object, which a parser keeps only once. So the loader also scans each file's raw text for a repeated key within one object before parsing, and reports it as an error (Rule 8 allows no silent override). A small scanner over the raw text does this; it does not parse values.

**Encodings.** A coordinate is a two-number array `[x, y]`; `pin_rect` is `{"min": [x, y], "max": [x, y]}`; a `pin_exclusion` shape is `{"a": [x, y], "b": [x, y], "radius": r, "hand": "right" | "left" | "both"}`; IDs and tags are strings; bools are JSON `true` or `false`; `scene_ref` is a string starting `uid://`. Any other shape is a wrong-type error.

### 2. Manifest
`res://data/manifest.json` lists the data files by path: `{"files": ["res://data/towers.json", ...]}`. The loader reads exactly these and nothing else; it never lists a directory. Every path must be unique and non-empty. The export preset's filter for files with no import step lists `data/*.json` (a path relative to the project), because a plain export packs only resources and would leave the JSON behind. Stage scenes are reached only through `scene_ref` strings, so no resource depends on them; the preset must export all resources, or list the stage scenes. Probe Q1 confirms both on Android, and that `res://data/` paths are not rewritten in the pack.

### 3. Load and validate in tiers
`Catalogue` is a `RefCounted` with the states Unloaded, Loading, Ready and Failed. `Catalogue.load_manifest(path) -> bool` runs synchronously in AppRoot's Boot:

1. **Manifest and file tier.** Read the manifest and each listed file with `FileAccess.get_file_as_string()`, which returns an empty string on failure; `FileAccess.get_open_error()` tells a missing file from an empty one. Scan for repeated keys, then parse with a `JSON` instance so the error line is known. A missing, unreadable, empty or unparseable file, a repeated key, an empty or repeated path, or a record type with no records is one manifest-tier error, and record checks do not run (Rule 7).
2. **Record tier, on raw Dictionaries.** A pure `CatalogueValidator.validate(raw) -> Array[ValidationError]` applies Rule 7's checks with this precedence, extending the GDD's: a missing field gets no other check; a value of the wrong JSON type (a string where a number belongs, a number where a bool belongs, a non-array where a list belongs, a malformed coordinate) gets no other check on that field; a non-finite number gets no bounds check; an unknown tag suppresses that record's role checks. Number fields must have `typeof(x) == TYPE_FLOAT`, since JSON numbers arrive as `float`. Integer fields must also be finite, within `±2^31`, and satisfy `x == floor(x)`, and are then converted with `int(x)`; a whole value such as `10.0` passes as `10`, by intent. Then IDs, duplicates across types, typed references, unknown properties (a key the record's own type does not declare), tags per type, role fields, non-empty lists, field domains (with `MIN_INTERVAL - 1e-6`), Stage geometry, and the Input cross-field check.
3. **Build tier.** Only if the error list is empty: construct one typed record object per entry and index them by ID. Typed arrays are built typed from the start (`var errors: Array[ValidationError] = []`), since an untyped array returned where a typed one is declared fails at runtime. On any error, the state is Failed, every error is reported (by file, record and field in development builds), and AppRoot takes the fatal path (ADR-0001).

`ValidationError` (B0) is `{code: StringName, source: String, record_id: StringName, field: StringName}`; the codes are one list of `StringName` constants owned by the validator, among them `&"missing_field"`, `&"wrong_type"`, `&"non_finite"`, `&"fractional_int"`, `&"out_of_bounds"`, `&"unknown_property"`, `&"unknown_tag"`, `&"duplicate_id"`, `&"duplicate_key"`, `&"bad_reference"`.

### 4. Typed, read-only records
Each record type is a `class_name` extending `RefCounted` (B0's `TowerRecord`, `EnemyRecord`, `WaveRecord`, `StageRecord`, `HeroRecord`, `BurstRecord`, `InputRecord`, plus `TowerLevelRecord` and `WaveGroupRecord` for owned sub-data, under `src/foundation/data/records/`) with typed fields set once by its constructor from validated data. Arrays and Dictionaries inside a record are made read-only with `make_read_only()` after construction. There are no setters. `make_read_only()` is shallow and a blocked write prints an engine error rather than stopping the caller, so the snapshot test, not the engine, is the proof. Systems read stats through the accessor (ADR-0005) and structure and Stage fields directly (Data Rule 10).

### 5. Read-only proof
A test-only `Catalogue.snapshot() -> String` serialises every record to canonical JSON (keys sorted); no `duplicate_deep()` is involved, since records are not Resources. The deep-snapshot test takes it before and after a scripted battle and compares; a detector self-test changes one nested value and must see the comparison fail. Mutation of a typed field would also be caught here, since `make_read_only()` covers only arrays and dictionaries.

### 6. Content test
A gdUnit4 suite under `tests/integration/content/` loads the real manifest and runs every row of the Data GDD's content-test register: its own rows (non-empty `rationale`, each `scene_ref` loads, at least one Stage) and each owning GDD's content table (Enemy & Wave, Tower, Hero, Battle HUD), table-driven with a pass and a fail fixture per row and a row count. It runs in CI and by one local command (ADR-0007 names it), at both 30 and 60 ticks per second where a rule reads `to_ticks`. The `scene_ref` row also runs once against an exported build, since an editor load proves nothing about the pack.

### Architecture Diagram
```
AppRoot (Boot)
  └─ Catalogue.load_manifest("res://data/manifest.json")
        1 manifest tier ── read files (FileAccess) ── parse (JSON) ──► raw Dictionaries
        2 CatalogueValidator.validate(raw) ──► Array[ValidationError]   (pure, unit-testable)
        3 build typed records (RefCounted, read-only arrays) ──► Ready
           any error ─► Failed ─► fatal path (ADR-0001)
Battle ◄─ StatAccessor (ADR-0005) ◄─ Catalogue (Ready, held by AppRoot)
```

### Key Interfaces
```gdscript
class_name Catalogue extends RefCounted
enum State { UNLOADED, LOADING, READY, FAILED }
func load_manifest(path: String) -> LoadResult  # synchronous; B0's LoadResult {ok, errors}
func state() -> State
func tower(id: StringName) -> TowerRecord       # null for an unknown ID; is_tower() first
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int     # 0 for an unknown ID
# enemy(), wave(), stage(), hero(), burst(), input_record() likewise
static func from_raw(raw: Dictionary) -> Catalogue   # tests: build from in-code fixtures, no file I/O

class_name CatalogueValidator extends RefCounted
static func validate(raw: Dictionary) -> Array[ValidationError]
```
The method is `load_manifest`, not `load`, which would shadow the global `load()` (ADR-0001 uses this name). On acceptance, `architecture.md` Data Flow 4 changes `Catalogue.load(manifest)` to `load_manifest`, B0's record row records `RefCounted`, and QQ-03 closes. The stat accessor's signature (`stat_int`, `stat_float`) and how its bad-call check survives release builds are ADR-0005's, as B1 states; this ADR only supplies the records it reads.

### Implementation Guidelines
- Must store gameplay records only in JSON files listed in `res://data/manifest.json`; must never scan a directory.
- Must validate raw Dictionaries before building any typed record, and must collect every error before failing.
- Must check each value's JSON type before any other check on it, and must treat every JSON number as `float`, checking integer fields with `x == floor(x)` and a ±2^31 bound before converting.
- Must scan raw text for a repeated key within one object and reject it.
- Must build typed arrays typed from the start.
- Must reject a key the record's own type does not declare.
- Must never supply a default for a missing field, in any build.
- Must make arrays and dictionaries in records read-only after construction, and give record classes no setters.
- Tests must build catalogues in code with `Catalogue.from_raw`, with no file I/O (Data Rule 12).
- The export preset must include `data/*.json` in its non-resource filter.

## Alternatives Considered

### Alternative 1: Typed Godot Resources (`.tres`)
- **Description**: One `Resource` script per record type with `@export` fields; records as `.tres` files edited in the Inspector; the manifest as an array of resource paths.
- **Pros**: Inspector editing; resources are packed by export without a filter; typed fields at load; the Data GDD's first recommendation.
- **Cons**: A missing field silently takes the script's default; a property the script does not declare is dropped without error; whether a fractional value in an integer export is caught is unverified. Meeting the hard condition needs a second reader over the raw `.tres` text, which means two parsers to keep in step. Resources can also carry scripts.
- **Rejection Reason**: Fails the Data GDD's hard condition without an extra text parser. JSON meets it with none.

### Alternative 2: Resources with sentinel defaults
- **Description**: Every exported field defaults to an impossible value (`NAN`, a sentinel int), so a missing field shows up.
- **Pros**: Keeps Inspector editing.
- **Cons**: Detects only the missing field; unknown properties and fractional integers still pass. Sentinels leak into code that forgets to check them.
- **Rejection Reason**: Meets one of three conditions.

### Alternative 3: One large JSON file
- **Description**: The whole catalogue in one file.
- **Pros**: One read; no manifest.
- **Cons**: Large diffs and merge conflicts; errors are harder to locate by file; Rule 4's manifest becomes trivial rather than useful.
- **Rejection Reason**: Per-type files keep edits small and errors named by file, at no real load cost.

## Consequences

### Positive
- All three hard conditions are met by the data itself, in one pure, unit-testable validator.
- Errors name the file, record and field, which the tuning loop needs.
- Records are plain text: small diffs, easy review, and simple tools later (QQ-14).
- The JSON format is also the path to downloadable content or modding, if ever wanted.

### Negative
- No Inspector editing of values; edits are by text editor. A tool may be wanted before about 20 stages (QQ-14).
- One extra export setting (the include filter), easy to forget; probe Q1 and the export checklist catch it.
- Typed record classes repeat the field list the validator also holds; a test checks they agree.

## Risks
- **JSON files missing from an Android export.** Mitigation: the include filter, probe Q1, and the fatal path naming the missing file.
- **`JSON` parses a value Godot-specifically** (for example accepting a non-standard token). Mitigation: probe Q2; the validator rejects any non-finite number regardless.
- **Validator and record classes drift.** Mitigation: a test that every declared field in each record class appears in the validator's schema, and the reverse.
- **Load time on a slow phone.** Mitigation: a few kilobytes of JSON; probe Q3 measures against the 1000 ms target.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-001: typed read-only records by stable ID; typed references | Typed `RefCounted` record classes indexed by ID; references validated by type (Decision 3, 4) |
| data-config-pipeline.md | TR-data-002: detect missing field, fractional integer, unknown property | JSON raw-Dictionary validation (Decision 1, 3) |
| data-config-pipeline.md | TR-data-003: explicit manifest; Android export | `manifest.json`, include filter, probe Q1 (Decision 2) |
| data-config-pipeline.md | TR-data-005: collect every error in tiers, with precedence and the cross-field check | Three tiers, `ValidationError`, Rule 7 precedence (Decision 3) |
| data-config-pipeline.md | TR-data-007: read-only; deep-snapshot test | Read-only arrays, no setters, canonical snapshot test (Decision 4, 5) |
| data-config-pipeline.md | TR-data-013: CI content test | `tests/integration/content/`, register-driven (Decision 6) |
| data-config-pipeline.md | TR-data-015: load and tuning-loop targets | Synchronous load of small JSON; probe Q3; edit-save-run loop |
| enemy-wave.md | TR-enemy-001: Stage record holds geometry; scene holds the look | `stages.json` geometry fields; `scene_ref` as `uid://` (Decision 1) |
| hero-system.md | TR-hero-014: hero and burst content rules on broken fixtures | Content test runs Hero's table with pass and fail fixtures (Decision 6) |
| battle-hud.md | TR-hud-016: HUD layout content rules | Content test runs the HUD's table (Decision 6) |

## Performance Implications
- **CPU**: Parsing and validating a few kilobytes once per session; expected well under 100 ms on desktop.
- **Memory**: A few hundred small objects; negligible against 256 MB.
- **Load Time**: Target at most 1000 ms median, Loading to Ready, on an Adreno 5xx-class device (probe Q3).
- **Network**: None.

## Migration Plan
No catalogue exists yet. The prototypes' constants become starter fixtures by hand when the Data stories run; they are not balance values (Data GDD).

## Validation Criteria
- The Data GDD's criteria 1 to 5 and 8 to 11 pass against `CatalogueValidator` and `Catalogue.from_raw`; criteria 6, 7 and 12 test the accessor and belong to ADR-0005.
- `test_record_schema_agreement`: each record class's fields equal the validator's field list for that type, both ways.
- Fixtures for each wrong-type case, a malformed coordinate and a repeated key each give exactly one error.
- The content test passes on the real data, and each row fails on its broken fixture.
- Probes Q1 to Q4 pass.

## Related
- ADR-0001 (AppRoot, fatal path). ADR-0005 (accessor). ADR-0007 (test harness, content-test command).
- `design/gdd/data-config-pipeline.md` (Rules 1 to 13, content-test register, Acceptance Criteria).
- `docs/architecture/architecture.md` QQ-03 (closed by this ADR on acceptance).

## Appendix: Probes

| ID | Probe | Pass condition | Result |
|---|---|---|---|
| Q1 | Android export with `data/*.json` in the include filter; load the manifest, every file and every `scene_ref` | All load; `res://data/` paths are unchanged in the pack; stage scenes are present; without the filter, the loader reports the missing file and takes the fatal path | Pending |
| Q2 | `JSON.parse` on `NaN`, `Infinity`, `1e999`, a trailing comma and a duplicate key | Recorded: which parse and what they yield; the validator rejects any non-finite number, and the raw-text scan rejects the duplicate key whatever the parser does | Pending |
| Q3 | Cold launch, Loading to Ready, five runs on an Adreno 5xx-class device | Median at most 1000 ms | Pending |
| Q4 | `make_read_only()` on an Array and a Dictionary inside a record; then a write | Recorded: the write is refused with an engine error and the caller continues; nested elements stay writable (shallow), which the snapshot test covers | Pending |
