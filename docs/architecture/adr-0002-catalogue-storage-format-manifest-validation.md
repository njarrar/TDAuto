# ADR-0002: Catalogue Storage Format, Manifest and Validation

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.
> Acceptance preconditions: (1) MET: the user confirms the format choice (JSON in
> place of the GDD's recommended typed Resources; it was made in autonomous
> mode). Confirmed by the user, 2026-11-04, as recommended. (2) W1 and W3 have a recorded result in
> `docs/engine-reference/godot/`, each run as a standalone headless script
> under `prototypes/` (not as a story), and W2 from an Android export of a
> throwaway project that reads one JSON file the same way (no game code
> needed); (3) ADR-0001 is Accepted.
> Verification progress, 2026-11-04 (macOS arm64, headless, Godot 4.7.2 editor
> binary; `docs/engine-reference/godot/verification-results.md`): W1 and W3
> are RECORDED. Still open before acceptance: W2 (Android export). Edits from
> the W1 result: the `bom_present` CI check is dropped (Decision 3 code list,
> Decision 8, diagram, Risks, Migration Plan), because `get_file_as_string`
> strips a file's BOM; the `duplicate_key` scan stays, because the parser keeps
> the last value silently; the Decision 5 `make_read_only()` guard is confirmed
> usable.
> After acceptance: W4 (device load time) is measured at the first phone build
> of the real catalogue. Reopen trigger: a median above 1000 ms starts a
> load-time task under this ADR; it does not reject the format.
> On acceptance, update: `architecture.md` B0 and the Foundation Catalogue row
> (names, base class, no `ResourceLoader`, no `duplicate_deep()`), and the Data
> & Config GDD's "Becomes an ADR" note and Open Questions row 1.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only. The live Godot 4.7 documentation was not reachable from the authoring session (`docs.godotengine.org` is outside the session's network policy), so engine behaviour the pinned reference does not cover is marked NEEDS VERIFICATION and listed in W1 to W4.

## Decision Makers

User (njarrar, project owner; format confirmed 2026-11-04, as recommended), technical-director (TD-ADR gate: CONCERNS on the first draft, finding 1 blocking and findings 2 to 11 advisory, all applied in this revision), godot-specialist (engine check: three blocking notes on the first draft, applied). Authored with the `/architecture-decision` flow in autonomous mode; the format choice is logged in `production/session-logs/decision-log.md`.

## Summary

The Data & Config catalogue needs a storage format that catches a missing field, a fractional integer and an unknown property, loads from an explicit manifest on an Android export, and stays read-only after load. This ADR decides plain JSON data files listed in one JSON manifest, read with `FileAccess` and `JSON` by a static `Catalogue.load_manifest()`, checked by a schema-driven GDScript validator that collects every `{code, source, record_id, field}` error, and turned into typed read-only `RefCounted` record classes only when the whole catalogue is valid; code-built fixtures go through the same validator, and a canonical-string snapshot test proves nothing changes the catalogue during a battle.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (post-cutoff version; Android export of the data files is unverified) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`. No `modules/` file covers file access, JSON or export filters. |
| **Post-Cutoff APIs Used** | None. `FileAccess.get_file_as_string`, `FileAccess.get_open_error`, `JSON.parse`, `JSON.data`, `JSON.get_error_line`, `JSON.get_error_message`, `JSON.stringify` all predate 4.3. The 4.4 change to `FileAccess.store_*` returning `bool` does not apply (the catalogue only reads). `duplicate_deep()` (4.5) is not used. The 4.7 typed-return override rule applies only if a record class overrides an engine virtual; none does. |
| **Verification Required** | W1 to W4 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: how 4.7's `JSON` parser types numbers and treats `NaN`/`Infinity` tokens, duplicate keys and a UTF-8 BOM; whether `.json` under `res://` is imported as a `JSON` resource and whether the raw text ships in an export; `JSON.stringify`'s key sorting at every level and its float precision; whether a method named `load` raises a shadowing warning; load time on the target device. The engine check agrees with the expected results from pre-4.4 knowledge only; that is not a source. |

Verification items (wired to acceptance: this ADR stays `Proposed` until each has a recorded result):

- **W1. JSON parsing.** Expected (unsourced): `JSON.parse` returns every number as `float`, including `3`. Check: the type of `3`, `3.0` and `160`; whether `NaN`, `Infinity` and `-Infinity` parse or fail; with a duplicate key in one object, which value survives or whether it fails; whether a leading UTF-8 BOM is a parse error. Method: a headless unit test per case. The validator below works whatever the number answer is; the duplicate-key and BOM answers decide whether the CI scans in Decision 8 stay.
  - Result (2026-11-04, macOS arm64, headless): all numbers parse as `float`; `NaN`, `Infinity` and `-Infinity` are parse errors; a duplicate key keeps the last value silently, so the `duplicate_key` scan stays; a BOM inside a string is a parse error, but `get_file_as_string` strips a file's BOM and the file loads, so the `bom_present` check is dropped; `make_read_only()` turns an in-place write into an error and keeps the value, so the Decision 5 guard is usable; see docs/engine-reference/godot/verification-results.md.
- **W2. Android export of the data files.** Expected (unsourced): Godot 4 imports `.json` under `res://` as a `JSON` resource, and the export ships the imported form, not the raw text, unless `*.json` is in the non-resource export filter. Check: with the filter, does `FileAccess.get_file_as_string("res://assets/data/<file>.json")` return the text on an Android export? Without it? Record whether the filter is required. Method: the first Android export, with a dev build that logs `catalogue Ready: <records> records from <files> files`, plus a release build with one broken record (GDD Acceptance 13). Owner: Technical Setup. If the raw text cannot be read in either case, use the Risks fallback (non-imported extension).
- **W3. Canonical stringify.** Does `JSON.stringify(data, "", true, true)` sort keys at every nesting level and print floats at full precision in 4.7, so equal snapshots give equal strings and a one-ulp change gives a different one? Method: headless unit test; it is also the snapshot detector's self-test (GDD Acceptance 11). `to_dict()` returns JSON-native types only (Decision 7), so packed-array and `StringName` stringify behaviour does not matter.
  - Result (2026-11-04, macOS arm64, headless): keys sorted at every level; equal snapshots give equal strings; floats round-trip at full precision and a one-ulp change gives a different string. No custom serializer; see docs/engine-reference/godot/verification-results.md.
- **W4. Load time.** Median Loading-to-Ready over 5 cold launches on one named Adreno 5xx-class device, against the proposed 1000 ms (TR-data-015, QQ-11). Advisory: a miss starts a load-time task; it does not reject the format.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (AppRoot starts the load and holds the Ready catalogue; the fatal path; the session-lifetime rule) |
| **Enables** | ADR-0005 (the accessor reads these record classes), ADR-0007 (fixtures built in code through `Catalogue.from_data`), ADR-0009 (Enemy, Wave and Stage records), ADR-0010 (Tower and Hero records) |
| **Blocks** | Data & Config epic; the first story of every system that reads a record (Enemy & Wave, Tower, Hero, Battle HUD, Input) |
| **Ordering Note** | ADR-0001 must be Accepted first. ADR-0005 must not fix the read-context shape before this ADR fixes the record classes. Record IDs are `StringName` here; ADR-0006 decides signal payload ID types (QQ-04) and should match or state why not. This ADR changes ADR-0001's boot step 2 call from `catalogue.load(manifest)` to `Catalogue.load_manifest(path)`; ADR-0001 is amended in the same change. |

## Context

### Problem Statement

Every gameplay number lives in the catalogue, and the Data & Config GDD makes silent bad data the failure to prevent: no fallbacks in any build, every error named by file, record and field. The GDD leaves the storage format to this ADR with one hard condition: the format, or a check on top of it, must detect a missing field, a fractional integer and an unknown property. It also needs an explicit manifest that works from an Android export, a read-only guarantee proven by a test, and fixture catalogues built in code with no file I/O. Nothing that reads a record can be written until the record shape and the load contract exist.

### Current State

No code and no data files exist. The GDD recommends typed Godot Resources, keeps JSON as the fallback "if downloadable content or modding is ever wanted", and warns that typed resources may silently default a missing field, in which case "the ADR must add a check that does". `architecture.md` lists the format as QQ-03, gives working names in B0 (`TowerRecord` and the rest, `LoadResult`, `ValidationError`) and gives the Catalogue the working API `load(manifest) -> LoadResult`, typed lookup by ID, `is_tower(id)` and `level_count(def_id)`.

### Constraints

- GDScript only; no GDExtension, no third-party parsing addon.
- The catalogue emits no signals (TR-data-014) and holds no per-battle callable (ADR-0001 session-lifetime rule).
- No fallbacks and no warning tier: two tiers only, boot-fatal invariants and the CI content test (GDD Rule 7).
- Content ships inside the build; no mods, no network, no hot reload, no schema versioning at MVP.
- Solo developer: the edit-to-in-game loop must stay near 10 s (proposed), with no custom editor tool.
- The engine does not enforce read-only data; it is a rule plus a test (GDD Rule 6).

### Requirements

- Detect missing fields, fractional integers, unknown properties, wrong types, non-finite numbers and out-of-domain values, and collect all of them before failing (TR-data-002, TR-data-005).
- Load only the files an explicit manifest names, and load the same way from an Android export (TR-data-003).
- Typed records keyed by a stable snake_case ID unique across all record types, referencing each other by typed ID (TR-data-001).
- Read-only after load, proven by a deep snapshot test (TR-data-007).
- Stage geometry on the Stage record, not in a scene (TR-enemy-001).
- Content tests in CI for the rules owning GDDs define (TR-data-013, TR-hero-014, TR-hud-016).
- Loading to Ready at most 1000 ms median on an Adreno 5xx-class device (TR-data-015, proposed).

## Decision

### 1. Format: JSON data files and a JSON manifest

All catalogue data lives in UTF-8 JSON files (no BOM) under `res://assets/data/`. One manifest, `res://assets/data/manifest.json`, lists them:

```json
{ "files": ["towers.json", "enemies.json", "waves.json", "stages.json", "hero.json", "input.json"] }
```

Paths in the manifest are relative to the manifest's folder. The loader never lists a directory. A data file is one JSON object whose keys are record-type names and whose values are arrays of records:

```json
{
  "tower": [
    { "id": "arrow_tower", "rationale": "Prototype starter values; not balance.",
      "tags": ["single_target"],
      "levels": [
        { "cost": 100, "damage": 12.0, "range": 160.0, "attack_interval": 0.8, "visual_key": "tower_arrow_1" },
        { "cost": 80,  "damage": 20.0, "range": 175.0, "attack_interval": 0.7, "visual_key": "tower_arrow_2" }
      ] }
  ]
}
```

Record-type names are `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`. A file may hold several types; a type may be split across files. The fields are exactly the GDD's Core Rules tables, including the Stage geometry fields from the Enemy & Wave GDD. JSON has no comments and no trailing commas; both are parse errors. The `rationale` field carries the "where this number came from" note.

Point and shape encoding: a point is a two-number array `[x, y]`. `path_points` and `slot_positions` are arrays of points. `hero_start` is a point. `pin_rect` is `{"min": [x, y], "max": [x, y]}`. `pin_exclusion` is an array of `{"a": [x, y], "b": [x, y], "radius": r, "hand": "right" | "left" | "both"}`, and a disc has `a` equal to `b`.

Reading: `FileAccess.get_file_as_string(path)`, then `FileAccess.get_open_error()` read at once (it returns an empty string on failure). Parsing: an instance of `JSON`, `var err := json.parse(text)`; the `Error` code decides success, never `json.data == null` (a JSON `null` document is valid); a parse error reports `get_error_line()` and `get_error_message()`. `ResourceLoader` and `load()` are never used for data files. The export preset lists `*.json` in its non-resource filter; W2 records whether that is required, and the `.json.import` sidecar files the editor writes are committed.

**This is the runtime format, read directly.** There is no import or conversion step, so it is not the "Spreadsheet or JSON import pipelines" item the GDD lists as not built for MVP.

### 2. Load contract

`Catalogue` (`src/foundation/data/catalogue.gd`, `extends RefCounted`) declares no signals. Both entry points are static and return a new catalogue inside a `LoadResult`:

```gdscript
## Reads the manifest and every file it lists, validates everything, and builds
## the records only if there is no error. Synchronous. Called once, by AppRoot.
static func load_manifest(manifest_path: String) -> LoadResult
## Same validation and build, from data already in memory. No file I/O.
## For code-built test fixtures; `source_label` stands in for the file name.
static func from_data(source_label: String, data: Dictionary) -> LoadResult
```

The method is not named `load`: an instance or static method of that name would shadow GDScript's global `load()` inside `catalogue.gd` and may raise a shadowing warning, the same reason ADR-0001 renamed `seed`.

`LoadResult` (`src/foundation/data/load_result.gd`, `extends RefCounted`; its own file because each `class_name` needs one) carries `ok: bool`, `errors: Array[ValidationError]`, and `catalogue: Catalogue`, which is `READY` when `ok` and null otherwise. The GDD's four states map to the call: `UNLOADED` before it, `LOADING` during it, then `READY` (a catalogue is returned) or `FAILED` (no catalogue, every error returned). A catalogue therefore exists only in `READY`, there is no second load to guard against, and there is no reload.

AppRoot (ADR-0001 boot step 2) calls `Catalogue.load_manifest(MANIFEST_PATH)`. On `ok == false` it calls its fatal path with a summary cause; in development builds it also calls `push_error` once per error, formatted `<source>: <record_id>.<field>: <code>`, so a run names every error (GDD Rule 8). Release builds show only the generic fatal screen.

### 3. ValidationError

```gdscript
class_name ValidationError extends RefCounted
var code: StringName      # from the code list below
var source: String        # file name relative to the manifest, "manifest", or a fixture label
var record_id: StringName # &"" for manifest and file errors
var field: StringName     # dotted path inside the record, e.g. &"levels[1].damage"; &"" if none
```

Codes (the list is closed; a new check adds its code here and in the validator in the same change):

| Group | Codes |
|---|---|
| Manifest and file (tier 1) | `manifest_missing`, `manifest_parse`, `manifest_shape`, `manifest_empty`, `manifest_repeat_path`, `file_missing`, `file_empty`, `file_parse`, `file_shape`, `unknown_record_type`, `type_has_no_records` |
| Record shape | `id_format`, `id_duplicate`, `missing_field`, `unknown_property`, `wrong_type`, `fractional_int`, `empty_list` |
| Numbers | `non_finite`, `out_of_bounds` |
| Tags | `unknown_tag`, `role_tag_count`, `role_field_missing`, `role_field_without_tag` |
| Geometry | `path_too_short`, `path_repeat_point`, `path_turn_too_sharp`, `path_segment_too_short`, `pin_rect_inverted`, `shape_invalid` |
| References | `dangling_reference`, `wrong_reference_type` |
| CI content tier only | `duplicate_key` (Decision 8; never raised at boot). `bom_present` was dropped 2026-11-04: W1 showed `get_file_as_string` strips a file's BOM, so a BOM file loads correctly |

### 4. Validation: schema-driven, collect everything, then fail

The validator (`src/foundation/data/validator.gd`) works on the parsed dictionaries, never on built records, so it sees exactly what the file said. Its rules come from one schema table (`src/foundation/data/catalogue_schema.gd`): for each record type and sub-record, each field's kind (`int`, `float`, `bool`, `string`, `id`, `id_ref:<type>`, `tags`, `point`, `points`, `rect`, `shapes`, `list:<sub>`), whether it is required, and its domain (min, max, and whether each bound is inclusive). The schema holds the GDD's field-domain table; those bounds are invariants against typos and broken sims, not balance values. Balance ranges stay in the content test.

**Only tier 1 stops anything.** Any manifest or file error stops all record checks, since records from a broken manifest only produce noise (GDD Rule 7). Otherwise every check below runs over every record, and the validator returns the full set. A check is skipped only where an earlier failure on the same field or record makes it meaningless:

- no bounds check on a field that failed `wrong_type`, `fractional_int` or `non_finite`;
- no reference check on a field that failed `wrong_type`;
- no geometry check on a malformed point or shape;
- no role checks on a record after `unknown_tag` (one typo gives one error).

Checks, grouped (grouping is for reading, not for stopping):

1. **Manifest and file (tier 1).** Manifest missing, unparsable, not `{"files": [strings]}`, empty, or with a repeated path; a listed file missing, empty, unparsable, not an object of arrays, or naming an unknown record type; after every file is parsed, any record type with no records.
2. **Shape.** ID present, a string, lowercase snake_case (`^[a-z][a-z0-9_]*$`); unique across all types (reported once per record holding the duplicate). For every field the record type's schema declares: `missing_field` if required and absent; `wrong_type` if the JSON kind is wrong. For every key the record type's schema does not declare: `unknown_property`, naming the key as `field`. Lists that must be non-empty: `empty_list`.
3. **Numbers.** Every number is checked for finiteness before its bounds. `int` fields: a number whose value is not whole is `fractional_int`. Then the domain bounds.
4. **Tags and roles.** Unknown tag; a tower with other than exactly one role tag; a role field missing on any level for its tag, or present without its tag.
5. **Geometry.** `path_points` has at least 2 points and no repeated consecutive point; `slot_positions` at least 1; every coordinate finite and within -2,000 to 2,000; `pin_rect` min below max on both axes; each `pin_exclusion` shape has `radius > 0` and a valid `hand`. Path drawability (ADR-0011 Decision 5), skipped if `path_width` failed a number check: with deflection `d_k` at each interior point (the angle between incoming and outgoing directions; 0 straight on, 90 degrees a square turn; `d = 0` at the two end points) and `w = path_width`, every `d_k` is at most 90 degrees (`path_turn_too_sharp`, naming the point index), and every segment from point `a` to point `b` has length at least `(w / 2) * (tan(d_a / 2) + tan(d_b / 2))` (`path_segment_too_short`, naming the segment index). Two square turns need `w`; a finely sampled curve needs little.
6. **References.** Every `id_ref` resolves, and to the declared type (`burst_id` names a `burst`; a wave group's `enemy_id` an `enemy`; a stage's `wave_ids` each a `wave`).

Number kinds. `wrong_type` means the wrong JSON kind (number, string, bool, array, object, null), never int against float:

- A `float` field accepts any finite JSON number, written `160` or `160.0`.
- An `int` field accepts a number whose value is whole and inside the domain; `1.0` is accepted as `1`, `1.5` is `fractional_int`. The record stores `int(v)` explicitly. All integer domains are far below 2^53, so a whole `float` from the parser is exact.

This works whether 4.7's parser returns whole numbers as `int` or `float` (W1; expected `float`).

**"Unknown property" is checked per record type,** which is stricter than GDD Rule 7's wording ("a field no record type declares"): `bounty` on a tower is `unknown_property` even though enemies declare it. The stricter reading catches a field put on the wrong record; the GDD's Rule 7 wording is updated to match in the same change as this ADR.

Cross-field rules that belong to another system stay there: `tap_slop > drag_slop` is the resolver's `validate()` (Input GDD). Layout, wave and balance rules are the content test's (Decision 8).

### 5. Records: typed, read-only RefCounted classes, built after validation

Only when every check passes does the catalogue build records. Names follow `architecture.md` B0. Each record type is a class under `src/foundation/data/records/`, `extends RefCounted`: `TowerRecord` (with `Array[TowerLevel]`), `EnemyRecord`, `WaveRecord` (with `Array[WaveGroup]`), `StageRecord`, `HeroRecord`, `BurstRecord`, `InputRecord`, and the sub-records `TowerLevel`, `WaveGroup`, `PinShape`. Fields are typed members with the GDD's names. Every record has `id: StringName` and `rationale: String`. `InputRecord` includes `reduce_motion` (ADR-0001 Decision 8).

- IDs are `StringName`, converted once at build (parsed JSON keys and values are `String`). References are stored as `StringName` IDs, never as object references or paths. Only owned sub-data (tower levels, wave groups, pin shapes) nests as objects.
- Typed arrays are filled with `append` or `assign`, never by returning an untyped literal.
- Geometry is stored as `PackedFloat64Array`, x and y interleaved (`path_points`, `slot_positions`, `hero_start`, `pin_rect` as `[min_x, min_y, max_x, max_y]`), so no 32-bit `Vector2` rounding enters the data (QQ-05). ADR-0004 owns the float policy and may change how consumers convert it.
- `scene_ref` is a `String` path to the stage's look-only scene. It is the one path in the catalogue; it names a scene, not a record.
- A record never holds a reference to the `Catalogue`, to another record object outside its owned sub-data, or to any battle object.
- Records and sub-records reference each other only through `class_name`, never `preload`, to avoid script load cycles.

Read-only is a rule with a test, not an engine guarantee (GDD Rule 6): no code outside `src/foundation/data/` writes a record field, and runtime state lives on runtime instances holding `def_id` (and level for towers). As an optional extra guard, the builder may call `make_read_only()` on each nested `Array` it creates, since W1's test run (2026-11-04) confirmed the method exists in 4.7, turns an in-place write into an error and keeps the value. The snapshot test stays the proof.

### 6. Catalogue lookups

```gdscript
func tower(id: StringName) -> TowerRecord             # and enemy, wave, stage, hero, burst
func input() -> InputRecord                           # the one Input record
func stage_ids() -> Array[StringName]                 # manifest file order, then order in file
func has_record(id: StringName) -> bool               # non-fatal
func record_type(id: StringName) -> StringName        # non-fatal; &"" if unknown
func is_tower(id: StringName) -> bool                 # non-fatal (GDD Rule 10)
func level_count(def_id: StringName) -> int           # non-fatal; 0 if not a tower
func snapshot() -> String                             # canonical string of the whole catalogue
```

A typed lookup with an unknown ID, or the wrong type's ID, is a bad call: it returns null, and the caller reports it through its injected `fatal` (ADR-0001). The catalogue holds no failure handler, because it lives for the session and the handler is per battle (ADR-0001 session-lifetime rule). The stat accessor (ADR-0005) wraps these lookups and owns bad-call reporting for stat reads. `stage_ids()` is built from the file arrays, so its order is stable; it gives AppRoot its first stage (ADR-0001 boot step 4).

### 7. Read-only proof: canonical snapshot

Every record and sub-record class has `to_dict() -> Dictionary`, returning a fresh copy of all its fields in JSON-native types only: `String` (never `StringName`), `int`, `float`, `bool`, `Array`, `Dictionary`. `PackedFloat64Array` becomes a plain `Array`. `snapshot()` builds a `Dictionary` of every record's `to_dict()`, keyed by type then ID, and returns `JSON.stringify(data, "", true, true)` (sorted keys, full float precision; W3).

Tests:

- **Read-only end to end.** Snapshot before and after a scripted fixed-tick battle in which at least one enemy spawned and died; the strings must be equal, and a mismatch reports the first differing path. (Owner: the Tower and Enemy & Wave stories, as the GDD defers it.)
- **Detector self-test.** Change one nested fixture value (a wave group's `count`) and assert the comparison names it (GDD Acceptance 11).
- **Coverage self-test.** For each record and sub-record class, the keys of `to_dict()` equal the script's own property names (`get_script().get_script_property_list()`), so a field added later cannot escape the snapshot.

Comparing strings avoids relying on deep `==` on nested containers, and `duplicate_deep()` is not needed because `to_dict()` already returns fresh data.

### 8. Content tests

The CI content tests live in `tests/integration/content/`. Each owning GDD's content rules (Enemy & Wave layout and wave rules, Hero and Burst rules, Battle HUD layout rules, non-empty `rationale`, declared balance ranges) are one function each, `check_<rule>(catalogue: Catalogue) -> Array[ValidationError]`, run against the real catalogue and, for each rule, against a broken fixture that must fail it (TR-hero-014, TR-hud-016). The suite also:

- opens every Stage `scene_ref` with `ResourceLoader.exists()` and `load()`, failing with the stage named (GDD Rule 9), and checks that its root is a `StageLook` whose hue, base value and grid tilt are inside art bible §6's ranges, and that every record's `visual_key` has a `ViewStyles` entry (ADR-0011);
- re-reads each real data file as text and scans it for a duplicate key inside one object (`duplicate_key`). W1 (2026-11-04) showed the parser keeps the last value silently, so this scan stays. There is no BOM scan: W1 showed `get_file_as_string` strips a leading BOM, so a BOM file loads correctly.

These run only in CI, never at boot, and never as warnings. The rules are defined by the owning GDDs; this ADR fixes only where they live and their shape.

**Scene checks on the project, not the export (GDD Open Question).** Enough for MVP: the content test proves every `scene_ref` opens in the project; GDD Acceptance 13 runs a release export; and a `scene_ref` broken only in the export still reaches the fatal screen at stage start (ADR-0001), naming the stage in a development build. Nothing fails silently.

### 9. Fixtures

Logic tests build fixtures in code as dictionaries in exactly the file shape and load them with `Catalogue.from_data("fixture:<name>", data)`, so fixtures pass the same validator and builder with no file I/O (TR-data-012). A small factory in `tests/helpers/` returns a minimal valid catalogue dictionary that a test then edits. A separate integration suite loads the real manifest.

Path drawability fixtures (ADR-0011 Decision 5): one stage with a 120 degree deflection and one with a 100-unit segment between two square turns at `path_width` 120, each producing exactly its one code; and the starter stage plus a 16-point radius-200 quarter circle at width 96 producing none.

### Architecture Diagram

```
 res://assets/data/manifest.json ──► {"files": [...]}
             │ (explicit list; no directory scan)
             ▼
  FileAccess.get_file_as_string ──► JSON.parse ──► Dictionaries
             │                                         │
             └── tier 1 error (manifest, file) ──────► stop: LoadResult{ok=false, errors}
                                                       │ else
                              Validator (schema table): every record check, collect all
                                                       │
                              errors? ── yes ──► LoadResult{ok=false, errors} ──► AppRoot fatal path
                                                       │ no
                                                       ▼
                  build typed records (TowerRecord, EnemyRecord, ... InputRecord)
                                                       │
                       LoadResult{ok=true, catalogue: READY; no signals, no callables}
                                                       │ held by AppRoot for the session
                    ┌──────────────────────────────────┼──────────────────────┐
                    ▼                                  ▼                      ▼
     BattleBuilder (ADR-0001)          StatAccessor (ADR-0005)      direct reads: Stage, Wave
     injects it per battle             reads stat fields            groups, Input record

 Tests: Catalogue.from_data(label, dict) ──► same validator and builder, no file I/O
 CI:    tests/integration/content/ ──► check_<rule>(catalogue), scene_ref opens,
        duplicate-key scan, snapshot tests
```

### Key Interfaces

```gdscript
# src/foundation/data/catalogue.gd
class_name Catalogue extends RefCounted
static func load_manifest(manifest_path: String) -> LoadResult
static func from_data(source_label: String, data: Dictionary) -> LoadResult
func tower(id: StringName) -> TowerRecord
func enemy(id: StringName) -> EnemyRecord
func wave(id: StringName) -> WaveRecord
func stage(id: StringName) -> StageRecord
func hero(id: StringName) -> HeroRecord
func burst(id: StringName) -> BurstRecord
func input() -> InputRecord
func stage_ids() -> Array[StringName]
func has_record(id: StringName) -> bool
func record_type(id: StringName) -> StringName
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int
func snapshot() -> String

# src/foundation/data/load_result.gd
class_name LoadResult extends RefCounted
var ok: bool
var errors: Array[ValidationError]
var catalogue: Catalogue            # READY when ok; null otherwise

# src/foundation/data/validation_error.gd
class_name ValidationError extends RefCounted
var code: StringName
var source: String
var record_id: StringName
var field: StringName

# src/foundation/data/records/*.gd  (each: extends RefCounted, typed fields per the GDD,
#                                    id: StringName, rationale: String, to_dict() -> Dictionary)
TowerRecord, TowerLevel, EnemyRecord, WaveRecord, WaveGroup, StageRecord, PinShape,
HeroRecord, BurstRecord, InputRecord
```

These names are the ones ADR-0005, ADR-0009 and ADR-0010 inherit. `class_name` collisions (QQ-16) are ADR-0007's lint (NAME-1 to NAME-4); ADR-0007 Decision 10 keeps `Catalogue` unprefixed unless V6 reports a collision.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must store every authored gameplay value in a JSON file under `res://assets/data/` listed in `manifest.json`.
- Must never scan a directory to find data files.
- Must read data files with `FileAccess` and `JSON.parse` on a `JSON` instance, checking the returned `Error`; must never load them with `ResourceLoader` or `load()`.
- Must keep `*.json` in the export preset's non-resource filter until W2 shows it is not needed, and must commit the `.json.import` sidecars.
- Must validate parsed dictionaries before building any record; must never build a record from data that failed validation.
- Must collect every error before failing; only a manifest or file error may stop the record checks.
- Must never supply a default for a missing field, in any build.
- Must treat `wrong_type` as a JSON-kind mismatch only; a whole number is valid for a `float` field.
- Must add a new field to the GDD table, the schema table and the record class (including `to_dict()`) in the same change, with its validator test.
- Must reference other records by `StringName` ID only; must never store an object reference to another record, the catalogue or any battle object in a record.
- Must never write a record field outside `src/foundation/data/`.
- `to_dict()` must return JSON-native types only.
- Must never declare a signal on `Catalogue` or any record class.
- Must never give the catalogue a failure handler or any per-battle callable (ADR-0001).
- Must never name a method `load` in `src/`.
- Must build test fixtures with `Catalogue.from_data`; logic tests must do no file I/O.
- Content rules must live in `tests/integration/content/` and must each have a broken-fixture test.

## Alternatives Considered

### Alternative 1: Typed custom Resources (`.tres`), the GDD's recommendation

- **Description**: One `Resource` subclass per record type with `@export` typed fields, authored in the inspector, saved as `.tres`, loaded with `ResourceLoader`.
- **Pros**: Inspector editing, which mostly prevents typo'd field names in the first place; typed fields; native to Godot; packed into exports with no filter.
- **Cons**: Godot omits a property equal to its default when it saves a resource, so a field missing from the file cannot be told from one set to its default. Sentinel defaults (NaN, minimum int) could fix that for numbers, but not for lists (enemy `tags` may legitimately be empty). From pre-4.4 knowledge, not the pinned reference: an unknown property in a `.tres` is dropped at load with at most a warning, and how a float written for an `int` property loads is uncertain. Meeting the GDD's condition this way needs a scanner for the `.tres` text format on top of the resources. Resources can also carry scripts.
- **Estimated Effort**: About 1.5x (records plus a `.tres` text scanner plus sentinel rules).
- **Rejection Reason**: The GDD's own route for Resources, "add a check that does", costs more than a JSON validator over dictionaries. Note the GDD's JSON fallback was conditioned on modding or downloadable content, not on detection; the reason here is cost, not that condition. An honest counterpoint: the unknown-property risk is largely one JSON creates by being hand-typed, and the validator is what pays for it.

### Alternative 2: `ConfigFile` (`.cfg`)

- **Description**: One section per record (`[tower.arrow_tower]`), Variant-typed values, read with `ConfigFile.load`.
- **Pros**: Native; keeps `1` and `1.0` as different types; missing and unknown keys are easy to list.
- **Cons**: Nested data (tower levels, wave groups, pin shapes) becomes inline Variant arrays and dictionaries in a Godot-only syntax that is harder to read and diff; the same export question as JSON; fewer outside tools.
- **Estimated Effort**: About 1x.
- **Rejection Reason**: Close second, and the rollback. JSON reads better for nested records, and the integer check costs one line either way.

### Alternative 3: GDScript constant dictionaries (data as code)

- **Description**: Records as `const` dictionaries in `.gd` files.
- **Pros**: The parser checks syntax; no file I/O; packs by default.
- **Cons**: Gameplay numbers would live in code, which the coding standard forbids; `git diff` no longer shows "only a data file changed" (GDD Acceptance 14); the validator is still needed.
- **Estimated Effort**: About 0.8x.
- **Rejection Reason**: Breaks the data-driven standard and GDD Rule 1.

### Alternative 4: Spreadsheet or CSV with an import step

- **Description**: Author in a spreadsheet, export CSV, import to records.
- **Pros**: Easy bulk tuning across many rows.
- **Cons**: Nested data fits poorly; adds an import pipeline the GDD lists as not built for MVP.
- **Estimated Effort**: About 2x.
- **Rejection Reason**: Out of MVP scope by the GDD's own list.

## Consequences

### Positive

- All three required detections (missing field, fractional integer, unknown property) are direct dictionary checks, with no parser of our own.
- One validator path for real files and code-built fixtures, so tests prove the production checks.
- Data files are plain text: readable diffs, any editor, and the tuning loop is edit, save, run.
- Records are typed after load, so consumers get typed fields and the parser checks member names.
- The catalogue stays a pure `RefCounted` with no engine coupling beyond two file reads, so it runs headless.
- A static loader means a catalogue object exists only in `READY`; there is no half-loaded or reloaded state to guard.

### Negative

- No inspector editing; values are edited as JSON text, so typo'd field names are possible and are caught only by the validator. Accepted for a solo developer at MVP; tooling waits for QQ-14.
- A new field touches four places (GDD table, schema, record class, `to_dict()`). The validator test and the snapshot coverage self-test catch a missed one.
- JSON has no comments; `rationale` carries the note instead.
- The export filter is a setting that is easy to lose; W2 and a CI check on `export_presets.cfg` guard it.
- Names and contracts here differ from `architecture.md` v2 in four places (Decision 2 loader, `LoadResult` file, record base class, snapshot method); they must be cascaded on acceptance.

### Neutral

- The GDD's recommended format (Resources) is replaced by JSON, for cost. The GDD's Open Question on format closes on acceptance.
- Geometry is stored as float64 pairs rather than `Vector2`; consumers convert at use.

## Risks

- **`.json` is imported and its raw text does not ship (W2).** Mitigation: the non-resource filter. If W2 shows the raw text is still unreadable, rename the data files to a non-imported extension (for example `.data`), keep the filter for that extension, and change only the paths in the manifest and the loader.
- **Duplicate keys pass the parser silently (W1, confirmed 2026-11-04: the last value wins).** Mitigation: the CI text scan in Decision 8. A BOM is not a risk: `get_file_as_string` strips it (W1), so the BOM scan was dropped.
- **JSON number handling differs from the plan (W1).** Mitigation: the integer check tests the value, not the parsed type, and `float` fields accept whole numbers, so either answer works. `NaN` or `Infinity` tokens, if accepted, are caught by the finiteness check.
- **Canonical stringify is not canonical (W3).** Mitigation: replace `JSON.stringify` with a small recursive serializer that sorts keys and formats floats with `var_to_str`.
- **Load is slow on the device (W4).** Mitigation: the data is small (tens of records); profile parse against validate, and consider one combined file. The format does not change.
- **The schema drifts from the GDD.** Mitigation: the table-driven validator tests follow the GDD's Acceptance Criteria 1 to 5; a new field without a test fails review.
- **The user rejects the format at acceptance.** Mitigation: Alternative 2 or Alternative 1 plus a scanner; the validator, error codes and record classes carry over because they work on dictionaries and typed records, not on JSON.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-001: typed read-only records keyed by stable snake_case ID unique across types; references by typed ID, never by path | Decision 4 (ID format, uniqueness, reference checks), 5 (typed classes, `StringName` IDs) |
| data-config-pipeline.md | TR-data-002: the format or a check on it detects a missing field, a fractional integer and an unknown property | Decision 1 (JSON), 4 (schema-driven checks, per-type unknown property) |
| data-config-pipeline.md | TR-data-003: loads from an explicit manifest, never a directory scan, and loads on an Android export | Decision 1 (manifest, `FileAccess`, export filter), 2, W2 |
| data-config-pipeline.md | TR-data-005: collect every error as `{code, source, record_id, field}` before failing, in tiers | Decision 3, 4 (only tier 1 stops; all else collected) |
| data-config-pipeline.md | TR-data-007: read-only after load; deep snapshot test proves the catalogue unchanged after a battle | Decision 5 (rule), 7 (snapshot, detector and coverage self-tests), W3 |
| data-config-pipeline.md | TR-data-013: CI content test opens each Stage `scene_ref`, applies layout and wave rules, checks rationale and balance ranges | Decision 8 |
| data-config-pipeline.md | TR-data-015: Loading to Ready median at most 1000 ms on an Adreno 5xx-class device; edit-to-in-game at most 10 s | Decision 1, 2 (small synchronous JSON load, no import step); W4 measures it |
| enemy-wave.md | TR-enemy-001: the Stage record holds gameplay geometry; the scene holds only the look | Decision 1 (Stage fields and encoding), 5 (`StageRecord` geometry) |
| hero-system.md | TR-hero-014: content tests enforce hero and burst rules, each proven on a broken fixture | Decision 8 (rule functions plus broken fixtures), 9 |
| battle-hud.md | TR-hud-016: content tests enforce HUD layout rules | Decision 8 |

## Performance Implications

- **CPU**: One synchronous parse and validation at boot over tens of records: expected a few milliseconds on desktop. Not measured; W4 measures the device. No per-frame cost; lookups are dictionary reads by `StringName`.
- **Memory**: Parsed dictionaries are dropped after the records are built; the catalogue holds only the records, well under 1 MB.
- **Load Time**: Inside the proposed 1000 ms budget by a wide margin on paper; W4 confirms.
- **Network**: None.

## Migration Plan

No code or data exists. First stories, in order: `ValidationError`, `LoadResult` and the schema table; the validator with the GDD's table-driven tests (Acceptance 1 to 5, 8); record classes, `to_dict()` and `from_data`; `load_manifest` with the manifest and file tier (Acceptance 9); `snapshot()` with its detector and coverage self-tests (Acceptance 11, W1, W3); starter data files from the prototype constants (marked as fixtures, not balance); the content-test shell with the scene and duplicate-key checks; the Android export check (W2, Acceptance 13, 15).

Same change as this ADR: ADR-0001 boot step 2 and `architecture.md` Data Flow 4 change `catalogue.load(manifest)` to `Catalogue.load_manifest(path)`; GDD Rule 7's "unknown property" wording becomes per record type.

**Rollback plan**: If W2 shows JSON cannot be read from an Android export in any form, move to `ConfigFile` (Alternative 2): the validator works on dictionaries, so only the file reader and the integer check change. If inspector editing is wanted later, add an editor tool that writes the same JSON; the runtime does not change.

## Validation Criteria

Automated, headless (gdUnit4 under `tests/unit/data/`, `tests/integration/data/`, `tests/integration/content/`):

1. The GDD's Acceptance Criteria 1 to 8 pass on code-built fixtures through `Catalogue.from_data`, with no file I/O.
2. Missing field, unknown property (including a field valid on another record type) and fractional integer each yield exactly one error with the right `code`, `record_id` and `field`.
3. Number kinds: `cost` accepts `1`, `1.0` and `100000`; `1.5` gives `fractional_int`; `100001` gives `out_of_bounds`; `"range": 160` and `"range": 160.0` both pass; `"range": "160"` gives `wrong_type`.
4. Collect-all: one fixture holding one error from each of shape, numbers, tags, geometry and references reports all five (GDD Acceptance 4).
5. A manifest or file error alongside an invalid record reports only the manifest or file error (GDD Acceptance 5).
6. GDD Acceptance 9 and 10 pass on the real manifest.
7. Snapshot detector and coverage self-tests pass (GDD Acceptance 11).
8. Read-only end to end: snapshot equal before and after a scripted fixed-tick battle (deferred to the Tower and Enemy & Wave stories, as the GDD lists).
9. `Catalogue` and record scripts declare no signals and hold no `Callable` member; no method named `load` under `src/` (lint, ADR-0007).
10. CI check: `export_presets.cfg` (once it exists) includes `*.json` in every preset's non-resource filter, until W2 shows it is not needed.

Manual evidence in `production/qa/evidence/`: W2 and GDD Acceptance 13 (release build with one invalid record shows the generic fatal screen; screenshot), W4 and GDD Acceptance 15 (load-time log), GDD Acceptance 14 (tuning loop).

The decision is wrong if: an Android export cannot read the data files in any form (W2 with both mitigations failing), or a required detection cannot be made from the parsed dictionaries.

## Related

- Depends on ADR-0001 (AppRoot, fatal path, session-lifetime rule; boot step 2 amended here). Enables ADR-0005, ADR-0007, ADR-0009, ADR-0010.
- `docs/architecture/architecture.md`: B0 (names adopted; base class decided), Module Ownership (Catalogue, Validator), Data Flow 4 and 7, QQ-03 (answered here), QQ-04 (record IDs are `StringName`; signal IDs are ADR-0006's), QQ-05 (geometry stored as float64), QQ-11, QQ-14.
- `design/gdd/data-config-pipeline.md` Core Rules 1 to 13, Edge Cases, Acceptance Criteria, Open Questions (format; snapshot mechanics and integer representation; scene checks on the project, not the export: all answered here).
- `design/gdd/enemy-wave.md` (Stage geometry), `hero-system.md`, `battle-hud.md` (content rules).
- `docs/architecture/tr-registry.yaml` (the 10 TR IDs above).
