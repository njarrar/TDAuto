# ADR-0002: Catalogue Storage Format, Manifest and Validation

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. No other agent, and no skill on its own.

TD-ADR: not run per ADR; batch review after all ADRs are written.
Engine validation (godot-specialist): not run per ADR; batch review after all ADRs are written.

## Date

2026-11-04

## Last Verified

2026-11-04 (against the Godot 4.7.2 class reference at tag `4.7.2-stable`, `docs/engine-reference/godot/`, and `docs/architecture/architecture.md` v3)

## Decision Makers

The user (storage format, binding), written in an autonomous run against `architecture.md` v3. Open for the user and `technical-director` to accept or change.

## Summary

The catalogue of authored gameplay values needs a storage format, a manifest, a validator that reports every error, and read-only typed records. This ADR records JSON files named by a JSON manifest, checked against a schema table in code, and built into read-only typed `RefCounted` records; typed Resources and a JSON-to-`.tres` bake are rejected.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting, file access) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (per `architecture.md` Required ADRs: JSON and file APIs are old and stable, but export behaviour is not verified and the GDScript row is HIGH in `VERSION.md`) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; Godot 4.7.2 class reference: `doc/classes/JSON.xml`, `FileAccess.xml`, `ResourceLoader.xml`, `Resource.xml`, `Dictionary.xml`, `Array.xml`, `@GlobalScope.xml`, `@GDScript.xml` |
| **Post-Cutoff APIs Used** | `Dictionary.duplicate_deep()` (4.5, `Dictionary.xml`) for the snapshot. `FileAccess.store_*` returning `bool` (4.4) is not used (read only). The 4.7 rule that a typed-return override needs an explicit `return` applies to every test double of `TextSource` |
| **Verification Required** | See the NOT SOURCEABLE list below. Each item names the run that settles it |

### NOT SOURCEABLE (blocks Acceptance)

Each item is a fact the pinned reference and the 4.7.2 class reference do not state. None is filled from memory. This ADR cannot move to `Accepted` until each named run is done and its result is recorded here.

1. **Variant type of a parsed whole number.** `JSON.xml` says numbers are parsed with `String.to_float` and does not say whether `5` comes back as `int` or `float`. Settled by: desktop headless (a unit test that parses `5` and `5.0` and records `typeof`). The validator accepts both until then.
2. **Duplicate key inside one JSON object.** `JSON.xml` is silent. Settled by: desktop headless (parse `{"a":1,"a":2}` and record the result). Until then, duplicates are an accepted gap (see Risks).
3. **What a write to a read-only `Dictionary` or `Array` does.** `Dictionary.xml` and `Array.xml` say only that modification is disabled and that nested content is not covered. Settled by: desktop headless (write to a frozen container in a debug run and in a headless run, record error versus silent no-op). The snapshot test, not the freeze, is the guard either way.
4. **Missing and unknown property handling when a `.tres` loads.** `Resource.xml` and `ResourceLoader.xml` do not describe it. It matters only to the rejected alternative, so it does not change the decision. Settled by: desktop headless (informational).
5. **Whether the export preset includes `*.json` and under which setting.** `FileAccess.xml` says a non-resource file needs Keep File import mode or an extension in the non-resource export filter, but the pinned reference does not give the preset key. Settled by: the phone session (an Android export that loads the manifest and every data file). CI may add an export smoke step later; the phone session is the required one.
6. **Whether the editor imports `.json` files, and the effect on the edit-save-run loop.** Settled by: desktop headless (`godot --headless --path . --import`, then inspect for `.import` files and time the loop against the 10 s target).
7. **Whether GDScript accepts a static method named `load`.** `@GDScript.xml` lists `load` as a built-in function. `architecture.md` Data Flow 4 writes `Catalogue.load(manifest)`. This ADR names the factory `from_manifest` to avoid the question. Settled by: desktop headless (informational; only needed if the name is ever changed back).
8. **Catalogue load time.** Median Loading-to-Ready at most 1000 ms on an Adreno 5xx-class device is a proposal. Settled by: the phone session (first phone build).
9. **Scene checks on an export.** The test runner cannot run on an exported build, so scene checks run on the project. Whether a manual export check is enough is the GDD's open question. Settled by: the phone session (open each `scene_ref` stage once on the export).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 App Lifecycle, Composition Root and Fatal Path (AppRoot calls the loader and routes a failed `LoadResult` to the fatal screen; the dev-error sink; no autoloads) |
| **Enables** | ADR-0005 (reads records and the schema's stat table), ADR-0007 (fixture catalogues from documents), ADR-0009, ADR-0010 |
| **Blocks** | Every story that reads a catalogue value; the Data & Config epic |
| **Ordering Note** | The one-tick floor for interval fields is the constant `MIN_INTERVAL_SECONDS = 1.0 / 60.0` taken from the GDD. ADR-0004 decides the tick rate; if it changes the rate, it must change this constant in the same edit. This ADR does not import from ADR-0004. |

## Context

### Problem Statement

All gameplay numbers and stage geometry live in data (Principle 3). The GDD requires a format, or a check on top of it, that detects a missing field, a fractional integer and an unknown property; loads every record or none; reports each error as `{code, source, record_id, field}`; and serves read-only definitions. The GDD recommended typed Resources and left the choice open (QQ-03). The user has since decided.

### Current State

Nothing exists. `src/` holds only a standards file. Prototype constants are starter fixtures, not balance values.

### Constraints

- Godot 4.7.2, GDScript, single thread, Mobile renderer, Android and iOS exports.
- No autoload (TR-data-011, owned by ADR-0001). The catalogue is a value the app root holds and the builder injects.
- No fallbacks in any build. `assert` cannot carry a release check: `@GDScript.xml` says the code inside runs only in debug builds or the editor. Every check in this ADR is an ordinary `if`.
- Simulation and data classes extend `RefCounted`, never `Node` (architecture, API Boundaries).

### Requirements

- Explicit manifest, never a directory scan (TR-data-003).
- Collect every error, then fail; manifest-tier errors stop record checks (TR-data-005).
- Definitions are read-only after load, with a deep-snapshot test (TR-data-007).
- Stage geometry lives on the Stage record, read directly (TR-enemy-001).
- Edit a value, save, run: new value in the game within 10 s, proposed (TR-data-015).

## Decision

**USER DECISION, BINDING.** The storage format is JSON files named by a JSON manifest, validated against a schema table in code, and built into read-only typed records. Typed Resources were rejected because the validator must see raw data to detect a missing field, a fractional integer and an unknown property. The architecture lists "Resource vs JSON" as open (QQ-03); this ADR records JSON as decided.

### 1. Files

Data is JSON text under `res://assets/data/`. A manifest lists the data files in order. Each data file holds one record type.

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
                    "attack_interval": 0.8, "visual_key": "arrow_1" } ] } ] }
```

Record types are `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`. A type may span several files. IDs are unique across all files and types (GDD Rule 2). Field names follow the GDD tables exactly. A point is a two-element array `[x, y]`; `pin_rect` is `{"min": [x, y], "max": [x, y]}`; a `pin_exclusion` shape is `{"a": [x, y], "b": [x, y], "radius": r, "hand": "right" | "left" | "both"}`.

### 2. Classes (Foundation, all `RefCounted`, one `class_name` per file)

```
 AppRoot -> Catalogue.from_manifest(path, TextSource) -> LoadResult
              |- CatalogueLoader     read manifest, read and parse files    (manifest tier)
              |- CatalogueSchema     const tables: fields, types, domains, tags, stat table
              |- CatalogueValidator  validate(documents) -> Array[ValidationError]  (record tier)
              '- record builders     TowerRecord ... InputRecord, frozen stat data
```

`ValidationError`, `LoadResult` and `Catalogue` keep the fields in `architecture.md` B0. One addition: `LoadResult` also holds `catalogue: Catalogue`, which is null unless `ok` is true. B0 lists no field that carries the catalogue out.

- `TextSource` has `read_text(path: String) -> String`. `FileTextSource` wraps `FileAccess.get_file_as_string`, which returns an empty string on an open error (`FileAccess.xml`); the loader records `FileAccess.get_open_error()` in `field` for a development run. An empty string is one manifest-tier error. Tests use `StringTextSource`, a dictionary from path to text.
- `CatalogueLoader` parses with a `JSON` instance and `parse(text)`, not `parse_string`, so `get_error_line()` and `get_error_message()` are available (`JSON.xml`).
- `CatalogueValidator` is pure: documents in, errors out. It never touches a node, an autoload or `Engine`.
- `Catalogue.from_documents(documents: Array[Dictionary]) -> LoadResult` runs the same pipeline from parsed documents, so fixtures are built in code with no file I/O (TR-data-012, ADR-0007).
- The loader does not call the fatal handler. AppRoot (ADR-0001) reads `LoadResult.ok` and routes a failure to the fatal screen. A development run prints each error through the dev-error sink.
- States Unloaded, Loading, Ready, Failed belong to AppRoot. A `Catalogue` object exists only when the load was Ready. There is no reload.

### 3. Records (replaces "Resource or RefCounted" in B0)

Record classes are `RefCounted`: `TowerRecord`, `EnemyRecord`, `WaveRecord`, `StageRecord`, `HeroRecord`, `BurstRecord`, `InputRecord`, plus owned sub-records `TowerLevel`, `WaveGroup`, `PinExclusionShape`. Each holds `id: StringName` and `rationale: String`. Structural fields (wave groups, every Stage field, the Input record) are typed members read directly. Stat-key values are held in a frozen `stats: Dictionary` on the record (or on each `TowerLevel`), keyed by `StringName`, with `int` or `float` values; ADR-0005 owns the vocabulary and the reader. References between records are `StringName` IDs resolved by the validator, never file paths (TR-data-001).

`StageRecord` holds `scene_ref`, `wave_ids`, `starting_gold`, `starting_lives`, `early_call_seconds_per_gold`, `path_points`, `slot_positions`, `path_width`, `requires_bend`, `hero_start`, `pin_rect`, `pin_exclusion: Array[PinExclusionShape]`. The scene holds only the look (TR-enemy-001). `B0` types `pin_exclusion` loosely; the GDD defines each shape as two points, a radius and a hand, so a shape class is needed. `PinExclusionShape` and `StageRecord` also keep scalar `float` copies of every coordinate, because `Vector2` is 32-bit in a stock build and `PinGeometry` computes on 64-bit scalars (architecture, QQ-05).

`Catalogue` lookups: `tower(id)`, `enemy(id)`, `wave(id)`, `stage(id)`, `hero(id)`, `burst(id)`, `input_record()`, each returning the typed record or null, and `tower_ids() -> Array[StringName]` in manifest order. The non-fatal `is_tower` and `level_count` live on `StatAccessor` (ADR-0005) and read these lookups.

### 4. Validation

Two tiers and no warnings (GDD Rule 7). The CI content test (section 6) covers everything else.

- **Manifest tier**, stops before any record check: `manifest_unreadable`, `manifest_parse`, `manifest_shape`, `manifest_empty`, `manifest_duplicate_path`, `file_unreadable_or_empty`, `file_parse`, `file_shape`, `file_unknown_type`, `type_no_records`.
- **Record tier**, all collected in one pass: `id_format`, `id_duplicate`, `ref_dangling`, `ref_wrong_type`, `field_missing`, `field_unknown`, `field_type`, `number_non_finite`, `number_out_of_range`, `int_fractional`, `tag_unknown`, `tag_role_count`, `role_field_missing`, `role_field_without_tag`, `list_empty`, `path_degenerate`, `pin_rect_inverted`, `input_record_count`, `slop_order`.

Per field the order is: finite check first (`is_finite`, `@GlobalScope.xml`; infinity would pass "above 0"), then type, then integer check, then domain. A fractional integer is `value != floor(value)`; the validator accepts both `TYPE_INT` and `TYPE_FLOAT` for a number (NOT SOURCEABLE item 1). An unknown tag gives one error and skips that record's role checks. The cross-field check `tap_slop` greater than `drag_slop` runs only when both are present, finite and in domain, and reports on `tap_slop` (TR-data-005). Domains come from the GDD field-domain table and sit in `CatalogueSchema` as constants; the interval floor is `MIN_INTERVAL_SECONDS`.

`CatalogueSchema` is the single table of record fields, so "unknown property" means "a field the schema does not list for this record type". Adding a field edits the schema and the validator in the same change.

### 5. Read-only and the snapshot

After validation the builder calls `make_read_only()` on every `stats` dictionary and every list inside a record, recursively, because `Dictionary.xml` says it "does not apply to nested content". What a write to a frozen container does is NOT SOURCEABLE (item 3), and packed arrays have no such flag, so the real proof is the snapshot test:

- `Catalogue.snapshot() -> Dictionary` returns a fresh plain-value dump of every record, including wave groups and Stage fields, through `to_dict()` on each record class. It returns `duplicate_deep()` of internal data, never a reference to it (`Dictionary.xml`).
- The test takes `JSON.stringify(snapshot(), "", true, true)` before and after a scripted battle that includes a death, and compares the two strings. `sort_keys` and `full_precision` are documented `JSON.stringify` parameters. Integers print as floats (`JSON.xml`), which is harmless for equality.

### 6. Content tests

The integration suite `tests/integration/data/` validates the real data files (TR-data-012) and holds the CI content test:

- It opens each Stage `scene_ref` on the project and applies the Enemy & Wave layout and wave rules (TR-data-013).
- It requires a non-empty `rationale` on every record and enforces each owning GDD's balance range.
- It enforces the Hero and Burst rules (leash, telegraph, intermission, reach, `hero_start`, `pin_exclusion`, exactly one Hero record), each proven on a broken fixture (TR-hero-014).
- It enforces the HUD layout rules (slot bounds, clearances, at most 3 next-wave types, a next-try line per enemy type, early-call bonus of at most 2 digits, 6 waves, 10 lives), each proven on a broken fixture (TR-hud-016).
- It adds a raw-text scan for a repeated key inside one JSON object, until NOT SOURCEABLE item 2 is settled.

Each rule above must be shown to fail on a deliberately broken fixture; a rule never seen to fail does not count.

### 7. Export and the tuning loop

The export preset must include `*.json` (NOT SOURCEABLE item 5). The loader reads through `FileAccess`, never `ResourceLoader`, because `ResourceLoader.xml` says non-resource files cannot be read that way. There is no import step and no bake, so the edit-save-run loop is a save and a run (TR-data-015; items 6 and 8).

### Implementation Guidelines

- The loader and validator must never reference a scene node, an autoload, or an `Engine` singleton. They load headless.
- Checks must be `if` statements that add a `ValidationError`. They must never be `assert`.
- The validator must report every error in one pass, except that manifest-tier errors stop record checks.
- Callers must never write to a record or a frozen container. Code review and the snapshot test enforce this.
- Callers must not hold a reference to a record's `stats`; they read through `StatAccessor` (ADR-0005).
- A record class must hold `def_id` consumers by `StringName` only; mutable state lives on runtime instances (TR-data-007).
- Adding a field must change `CatalogueSchema` and the validator together and must not change the loader signature.
- Public classes need doc comments (project coding standards).

## Alternatives Considered

### Alternative 1: Typed `Resource` files (`.tres`)
- **Description**: `class_name TowerData extends Resource` with `@export` fields, loaded with `load()`.
- **Pros**: Editor inspector; edit-time type checks; the GDD's stated preference.
- **Cons**: The validator would not see raw data, so a missing field, a fractional integer and an unknown property could be silently defaulted or dropped. Missing and unknown property handling is not documented (item 4). `Resource.xml` says loaded resources sit in a shared path cache and `duplicate()` is shallow for nested containers, which works against read-only. `ResourceLoader.xml` says text resources may convert to binary on export.
- **Estimated Effort**: Similar loader cost; a second parallel raw-file check would still be needed.
- **Rejection Reason**: User decision. The validator must see raw data.

### Alternative 2: JSON authored, baked to `.tres` at build
- **Description**: JSON is the source; a tool bakes typed Resources.
- **Pros**: Raw validation plus an inspector.
- **Cons**: A build tool a solo developer must maintain; an extra step in the edit-save-run loop; the GDD lists import pipelines and custom tools under "Deliberately not built".
- **Estimated Effort**: Highest.
- **Rejection Reason**: User decision, and over-built for MVP. It can be added later behind the same `Catalogue` API.

### Alternative 3: GDScript `const` dictionaries
- **Description**: Data lives in preloaded `.gd` scripts.
- **Pros**: Always exported; no file I/O; no parse step.
- **Cons**: Data edits become code edits; parse faults surface as script errors, not collected catalogue errors; it blurs the "no gameplay value in code" line.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Breaks Principle 3 in spirit and cannot collect all errors.

## Consequences

### Positive
- Every validation rule is plain code, table-testable through `from_documents` with no file I/O.
- Errors name file, record and field. The format has no hidden defaults.
- The format sits behind `Catalogue`, so a later swap does not touch consumers.

### Negative
- No editor inspector for data; designers edit text. JSON parse leniencies apply (`JSON.xml`: lax numbers).
- Duplicate keys in one object are not detected after parse (Risks).
- Records are built by hand from dictionaries; each new field costs a schema row and a record change.

### Neutral
- `architecture.md` Data Flow 4 writes `Catalogue.load(manifest)`; this ADR uses `Catalogue.from_manifest` (NOT SOURCEABLE item 7). The next revision of `architecture.md` should follow, and should add `LoadResult.catalogue` and the `PinExclusionShape` type. This ADR does not edit it.

## Risks

- **Duplicate JSON keys may overwrite silently.** Mitigation: the raw-text scan in the content test.
- **Export drops the data files.** Mitigation: the Android export check before Acceptance (item 5); the catalogue-free fatal screen shows if a file is missing.
- **Whole-number type surprise.** Mitigation: the validator accepts both types; a unit test pins the result (item 1).
- **A frozen container hides a write, or crashes.** Mitigation: the snapshot test is the guard (item 3).
- **Load time on a low-end phone is unmeasured.** Mitigation: measure in the first phone build (item 8).
- **Tick-rate drift.** `MIN_INTERVAL_SECONDS` could fall out of step with ADR-0004. Mitigation: the Ordering Note; a test asserts the constant equals one tick.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-001: typed read-only records keyed by a stable snake_case ID, unique across all record types; references by typed ID, never by file path | Typed `RefCounted` records; `id_format`, `id_duplicate`, `ref_dangling` and `ref_wrong_type` checks |
| data-config-pipeline.md | TR-data-002: the format, or a check on top, detects a missing field, a fractional integer and an unknown property | JSON read raw; the schema table drives `field_missing`, `int_fractional` and `field_unknown` |
| data-config-pipeline.md | TR-data-003: explicit manifest, never a directory scan, loads from an Android export | JSON manifest, `FileAccess` reads, export check as a NOT SOURCEABLE item |
| data-config-pipeline.md | TR-data-005: collect every error as `{code, source, record_id, field}` in tiers; check `tap_slop > drag_slop` | `ValidationError`, two tiers, `slop_order` check |
| data-config-pipeline.md | TR-data-007: read-only definitions, mutable state on instances with `def_id`, deep-snapshot test | Frozen `stats`, `snapshot()` compared before and after a battle |
| data-config-pipeline.md | TR-data-013: CI content test opens each `scene_ref`, applies layout and wave rules, checks rationale and balance ranges | Section 6 |
| data-config-pipeline.md | TR-data-015: load at most 1000 ms median on an Adreno 5xx-class device; edit-to-in-game at most 10 s | No import or bake step; both targets are phone-session items |
| enemy-wave.md | TR-enemy-001: the Stage record holds gameplay geometry; the scene holds only the look | `StageRecord` fields and scalar copies |
| hero-system.md | TR-hero-014: content tests enforce hero and burst rules, each proven on a broken fixture | Section 6 |
| battle-hud.md | TR-hud-016: content tests enforce HUD layout rules | Section 6 |

## Performance Implications
- **CPU**: Parse and validate once at boot. Reads after load are dictionary lookups and member reads (ADR-0005). No target is claimed.
- **Memory**: Small; tens of records.
- **Load Time**: Budget 1000 ms median to Ready on the named device is the GDD's proposal and is unmeasured.
- **Network**: None.

## Migration Plan
Nothing exists to migrate. Order: `ValidationError`, `LoadResult`, `TextSource`, `CatalogueSchema`, validator with table tests, loader, record builders, `Catalogue`, snapshot test, content tests.

**Rollback plan**: `Catalogue` hides the format. If JSON fails the Android export check, replace the loader and keep the validator on the same dictionaries. The user's decision would need to be reopened first.

## Validation Criteria
- The GDD's logic and integration acceptance criteria for load, validation and read-only pass.
- An Android export loads the manifest and shows the fatal screen for one invalid record.
- The snapshot text is identical after a scripted battle with a death.
- Every content rule fails on its broken fixture.
- Every NOT SOURCEABLE item above has a recorded result.

## Related
- `docs/architecture/architecture.md` (B0 Shared types, Required ADRs, QQ-03)
- `design/gdd/data-config-pipeline.md`
- ADR-0001 (depends on); ADR-0004 (tick rate constant); ADR-0005 (reads these records); ADR-0007 (fixtures and harness); ADR-0009, ADR-0010
- GDD sync: checked data-config-pipeline.md; the GDD recommends typed Resources, and this ADR departs from that on the user's decision. The GDD's Open Question on storage format should be marked closed when this ADR is Accepted.
