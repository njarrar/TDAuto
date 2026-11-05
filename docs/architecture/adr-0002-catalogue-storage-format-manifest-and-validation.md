# ADR-0002: Catalogue Storage Format, Manifest and Validation

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer. Reviewed once each on 2026-11-05 by godot-specialist (2 blocking, 12 minor, with desktop probes on 4.7.2) and technical-director under gate TD-ADR (CONCERNS: 4 blocking, 9 advisory); all findings were applied in this revision. No second review pass has been run.

## Summary
The game needs one read-only catalogue of every authored gameplay value that fails loudly on a missing field, a fractional integer or a misspelt property, and that provably loads from an Android export. This ADR stores the data as JSON files listed in an explicit manifest, parses them through a hand-written two-tier validator that collects every `{code, source, record_id, field}` error, builds typed `RefCounted` records only from clean data, loads synchronously on the main thread from `AppRoot._ready()`, proves read-only with a hand-rolled deep snapshot, and records save/load as deferred with its seams.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; installed 4.7.2.stable.official) |
| **Domain** | Core (file access and data loading) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (QQ-03) until an Android export proves the load. The local reference says almost nothing about the APIs this decision rests on, so the rating comes from the gap, not from a known break; the desktop probe below narrows it but does not close it. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 `FileAccess.store_*`, 4.5 `duplicate_deep()`, 4.7 typed-return override), `deprecated-apis.md` (`duplicate()` row, `Time.get_ticks_msec()` row), `current-best-practices.md` (GDScript 4.5+, 4.7, Resources 4.5+, Command Line and parse check), `.claude/scripts/godot-parse-check.gd` (header). The live class reference was not consulted. |
| **Post-Cutoff APIs Used** | None. `duplicate_deep()` (4.5) was considered for the snapshot and rejected (Decision 10). Code under this ADR never overrides a typed-return method without an explicit `return` (4.7 break) and uses no `@abstract` class. |
| **Observed on desktop** | Probed on the installed 4.7.2 (debug build, macOS) by godot-specialist: 4.7.2 probe, 2026-11-05, `prototypes/adr-0002-spike/`. Every JSON number is a `float`; `NaN` and `Infinity` tokens are parse errors; `1e400` parses to `inf`; a repeated key in one object keeps the last value silently; `JSON.new().parse(text)` returns an `Error` with `get_error_line()` (1-based), `get_error_message()` and `get_data()` and prints nothing, while `JSON.parse_string` returns `null` for a failure, an empty text and a literal `null` alike and prints an `ERROR:` with a backtrace; `JSON` is a `Resource` and `.json` a registered resource extension (`load("res://x.json")` returns one); `FileAccess.open` on a missing path returns `null` with `get_open_error()` equal to `ERR_FILE_NOT_FOUND`; `Dictionary ==` compares contents but is type-strict (`1` vs `1.0`, `"x"` vs `&"x"` are unequal); `String` and `StringName` interoperate as dictionary keys; `Array.make_read_only()` exists and works; `Vector2` is single precision (`0.1` is stored as `0.10000000149011612`); `is_finite`, `floor`, `typeof` and `int()` behave as Decision 1 uses them; a `.tres` with `1.5` in an int export loads as `1`, a `String` in a float export as `0.0`, a missing field takes its default and an unknown property is dropped, with no error printed. Desktop only: none of this stands in for the Android export. |
| | NOT SOURCEABLE — `FileAccess`, `JSON` and `ResourceLoader` behaviour on an Android export or a packed `.pck` (default packing of the data files, read speed) is not covered by docs/engine-reference/godot/ |
| | NOT SOURCEABLE — `load()` on a missing or broken scene (return value and engine error print) and gdUnit4's reaction to an engine `ERROR:` line are not covered by docs/engine-reference/godot/ |
| | NOT SOURCEABLE — `Thread` is not covered by docs/engine-reference/godot/; it is not used until verified (Decision 7) |
| | NOT SOURCEABLE — the whole class pages for `FileAccess`, `JSON`, `Dictionary`, `Array` and `Vector2` are not covered by docs/engine-reference/godot/; every behaviour above rests on the probe, not on the reference |
| **Verification Required** | (1) Android release export: `Catalogue.load_from()` reaches Ready with the real manifest and every file the manifest lists is readable from the export. `.json` is a registered resource extension on 4.7.2, so the default export is expected to pack the data files; a filter is added only if a file is missing there. (2) On the same export, one deliberately invalid record gives the fatal screen and creates no file under `user://` (GDD criterion 13; no save exists at MVP). (3) Repeat the JSON probe rows on the export: every number a `float`, `1e400` to `inf`, a parse error's line and message, `FileAccess.open` on a missing path returning `null`. (4) Median Loading to Ready at most 1000 ms over 5 cold launches on one named Adreno 5xx-class device, from the build named in Decision 7, measured with `Time.get_ticks_msec()` (sourced: `deprecated-apis.md`). (5) The Stage `scene_ref` of the starter stage loads on the export through ADR-0001's runtime `load()` with null check. (6) `godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- <files>` passes on every file under `src/data/`; `--check-only` is not a parse check on this install (`current-best-practices.md`, ADR-0001 probe table). (7) Before the content-test story closes, record what `load()` does on a missing and on a broken `scene_ref` in the editor suite and whether gdUnit4 counts the engine `ERROR:` line as a failure; if it does, the broken-fixture case checks existence with `ResourceLoader.exists()` (probe: true for a present file; record the missing-path result) and the `load()` check is the first phone run's. (8) `Array.make_read_only()` on a typed array (`Array[TowerLevel]`) works and a read of it still works (Validation Criterion 19). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): the composition root that calls the load once, holds the Ready catalogue, routes `Failed` to `fatal(cause)` and bans `Node`, `static var` and lambdas in gameplay code. |
| **Enables** | ADR-0005 (the accessor reads these records and their field types), ADR-0006 (inherits `StringName` for record IDs in signal payloads), ADR-0007 (fixtures, content-test runner, lint), ADR-0009 and ADR-0010 (read Enemy, Wave, Hero, Burst and Tower records), ADR-0011 (reads the Stage record's geometry). |
| **Delegates To** | ADR-0004: the tick rate behind the one-tick floor, and `to_ticks` used by two content rows. ADR-0005: the stat accessor, `ReadContext`, key vocabulary types, the bad-call handler (criteria 6, 7, 12), the caller-facing lookup surface and what a null or bad lookup does in battle; ADR-0005 may place `StatAccessor` and `ReadContext` under `src/data/` under this ADR's rules and one-way imports, or elsewhere (its choice). ADR-0006: signal payload ID types (inherit `StringName`). ADR-0007: the test runner and harness, where the fixture factory lives, the layer lint for `src/data/` and a CI text check for a repeated key inside one JSON object in `assets/data/` (firm: the probe shows the parser keeps the last value silently). ADR-0008: the resolver's own `validate()` second line for `tap_slop > drag_slop`. ADR-0010: the hit-radius and burst-line constants the Hero and HUD content rows read. ADR-0011: the Stage scene's look. |
| **Blocks** | The Boot story (it calls `Catalogue.load_from()`), every consumer story that reads a record, the first phone build's data checks. |
| **Ordering Note** | ADR-0001's Ordering Note requires this ADR Proposed before the Boot story. The schema's one-tick floor (`1/60` s) is provisional: it is a local copy until ADR-0004 fixes the tick rate, after which `catalogue_schema.gd` references ADR-0004's constant (importable from `src/data/` if ADR-0004 places it outside `src/battle/`). The Hero telegraph row and the wave "strictly increasing spawn ticks" row need ADR-0004's `to_ticks`; those two rows land when ADR-0004 does. Rows that need Tower or Hero data (L10, L11, L14, intermission, `peak_alive_ub`, `burst_spike`) land with the Tower and Hero stories, as the Enemy & Wave GDD says. |

## Context

### Problem Statement
Every gameplay number lives in data (Data Rule 1), so a typo in a data file can corrupt balance silently: a missing field read as 0, a `count` of 1.5 truncated to 1, a field named `atack_interval` never read. The GDD requires that none of these ships: the catalogue loads all or nothing, collects every error with file, record and field, and has no fallback in any build. It also requires that the load is proven on an Android export, where files are packed and renamed, and that the result is read-only for the rest of the session. ADR-0001 already fixed who calls the load and how a failure reaches the fatal screen; it left the storage format, the load API, whether the load is threaded, and the error text to this ADR.

### Constraints
- Godot 4.7.2, GDScript, no exceptions (ADR-0001): a failing function returns a value, so load returns a result the caller must check.
- `src/battle/` is `RefCounted` only, with no `static var`, lambda, `bind()` or `assert()` (ADR-0001). Records are read by battle code, so they are `RefCounted` too.
- No autoload and no global: `AppRoot` holds the catalogue and the builder injects it (TR-data-011).
- Android kills an app that blocks its main thread for about 5 s; the GDD's load budget is 1000 ms median on an Adreno 5xx-class device (TR-data-015).
- The test runner cannot run on an exported build, so everything an export could break is checked by a manual run, not CI.
- Solo developer, workflow `full`. Hand-editing data is the main authoring path; `git diff` must show a one-line change for a one-value edit (GDD criterion 14).
- The engine reference is silent on the file, JSON, resource-loading and export APIs; desktop behaviour is taken from the 4.7.2 probe, and anything on the Android export is a Verification item, never assumed.

### Requirements
- Typed read-only records keyed by a snake_case ID unique across all record types; references by typed ID only (TR-data-001).
- The format, or a check on top of it, detects a missing field, a fractional integer and an unknown property (TR-data-002).
- An explicit manifest, never a directory scan, loading correctly from an Android export (TR-data-003).
- A validator collecting `{code, source, record_id, field}` in tiers, including `tap_slop > drag_slop` at load (TR-data-005).
- A deep-snapshot test proving the catalogue is unchanged after a battle (TR-data-007).
- A CI content test that opens each `scene_ref`, applies layout and wave rules and checks `rationale` and balance ranges (TR-data-013), plus the Hero (TR-hero-014) and HUD (TR-hud-016) rule sets.
- Median load at most 1000 ms; edit to in-game at most 10 s (TR-data-015).
- Geometry on the Stage record, the scene holds the look (TR-enemy-001).

## Decision

**1. Storage format: JSON files, parsed and validated by our own code, then built into typed records.** The source of truth is JSON text under `assets/data/`. Typed `Resource` records (`.tres`) are rejected as the source. The reason is detection, which TR-data-002 makes the deciding requirement: the GDD's premise is that a typed Resource defaults a missing field silently, converts `1.5` into an integer field without complaint and never reports a property that no field declares. The 4.7.2 probe, 2026-11-05, `prototypes/adr-0002-spike/` confirms all three on 4.7.2: a `.tres` with `1.5` in an int export loads as `1`, a string in a float export as `0.0`, a missing field takes its default and an unknown property is dropped, with no error printed. So with JSON, our validator sees the raw keys and raw numbers before any coercion, so all three faults are detected by code we wrote and can unit-test, on every engine version. Detection works like this:
- **Missing field:** for each record the validator walks the schema's required key list for that record type (and for each nested level, group, point and shape) and reports `missing_field` for every key absent from the raw `Dictionary`. There are no optional keys at MVP; a role field is "required when the tag is present" and "forbidden when it is not" (Decision 8, pass 3).
- **Fractional integer:** an integer field must hold a JSON number whose `typeof` is int or float, whose float value passes `is_finite()` and whose `floor(x) == x`. Otherwise `fractional_integer` (or `non_finite`, which is checked first). The probe shows every JSON number parses as `float`, so the int branch is dead on this build; the check still accepts both, harmlessly, and the builder converts with `int()` only after validation. From a file, `NaN` and `Infinity` tokens are parse errors (`file_parse`) and never reach this check; the only file route to `non_finite` is overflow (`1e400` parses to `inf`), and the NaN rows of the tests are code-built fixtures through `load_parsed()`. A `bool` or `String` in a number field is `wrong_type`.
- **Unknown property:** the validator compares each raw key against the schema's declared key set and reports `unknown_property` with the key as `field`. A misspelt optional is therefore never silently "missing"; it is reported twice at most (`unknown_property` for the typo, `missing_field` for the real name), which points at the cause.

Typed records are built (Decision 3) only from data that produced zero record-tier errors, so no typed field ever holds a defaulted or truncated value. JSON as the source is not the "import pipeline" the GDD lists under Deliberately not built: there is no conversion step, the loader reads the files themselves. A hybrid (JSON authoring converted to `.tres` at build time) is rejected: it adds a build step and a second artefact for no gain at 20 records.

**2. Where things live.**
- Data: `assets/data/`. The manifest is `assets/data/manifest.json`. Data files are named by content (`towers.json`, `enemies.json`, `waves.json`, `hero.json`, `input.json`, one `stage_NN.json` per stage); the manifest, not the file name, decides what loads. A file may hold records of several types.
- Code: a new root `src/data/` (all `RefCounted`, no `Node`, no `static var`, no `assert()`, no autoload; lambdas and `bind()` are not banned here, because ADR-0001's reason for banning them, a capture keeping the old battle alive across a retry, does not apply to session-lifetime catalogue code): `catalogue.gd`, `catalogue_load_result.gd`, `catalogue_error.gd`, `catalogue_schema.gd`, `catalogue_validator.gd`, `catalogue_builder.gd` and `records/` (one file per record class, snake_case file names). This adds a fourth root to ADR-0001 Decision 10's three; it does not contradict it: that decision names the roots under which ADR-0010 and ADR-0011 place their classes, and says nothing about data. It is not `src/battle/` because the loader does file I/O and is not gameplay, and ADR-0001 says `src/battle/` holds only gameplay classes. `architecture.md` line 361 gives `src/foundation/data/catalogue.gd`; ADR-0001's layout supersedes it, and the table row is updated at `/architecture-review`. Where `StatAccessor` and `ReadContext` live is ADR-0005's choice (`src/data/` is allowed under the same rules). Dependency direction (for ADR-0007's layer lint): `src/battle/`, `src/presentation/` and `src/app/` may import `src/data/`; `src/data/` imports none of them.
- Tests: `tests/unit/data/` for validator and fixture tests, `tests/integration/data/` for the content test and the real-manifest test (Decision 12).

**3. Record classes.** One `RefCounted` class per record type, typed fields, assigned only by `CatalogueBuilder` and never again:
- `TowerRecord` (`def_id`, `rationale`, `tags: Array[StringName]`, `levels: Array[TowerLevel]`), `TowerLevel` (`cost: int`, `damage`, `range_units`, `attack_interval`, `visual_key`, `splash_radius`, `slow_strength`, `slow_duration`).
- `EnemyRecord`, `WaveRecord` with `groups: Array[WaveGroup]` (`enemy_id`, `count: int`, `spawn_interval`, `start_delay`) and `intermission_duration`, `HeroRecord`, `BurstRecord`, `InputRecord`.
- `StageRecord` (Decision 11) with `PinExclusion` (`a`, `b`, `radius`, `hand`).
Field names equal the GDD's JSON keys except two: JSON `id` is `def_id` in the class, and `range` is `range_units` in the class to avoid a shadowing warning for a GDScript built-in (the probe shows `var range` loads and runs without error; warnings are not printed headless). The JSON key and the stat key stay `range`, and `to_dict()` writes `range`. The probe also checked the 14 class names of this ADR against `ClassDB.class_exists`: none collides with a native class, while `Input` does (`class_name Input` fails to load: it hides a native class), which is why the record is `InputRecord`. Builder assignments are explicit statements, one per field, so there is no reflection. A tower level's role fields (`splash_radius`, `slow_strength`, `slow_duration`) hold `0.0` when the tower lacks that role; the validator guarantees the raw data had none, and the stat accessor (ADR-0005) refuses a role key on a tower without the tag, so the zero is unreachable through the accessor. Direct reads of a role field on a record are a defect. Each record class has `to_dict() -> Dictionary` for the snapshot (Decision 10) and no `from_dict()`.

**4. IDs.** `def_id` and every reference field are `StringName`. JSON carries strings; the builder converts once. Lookups take `StringName`, so dictionary keys are always `StringName`. The probe shows `String` and `StringName` interoperate as dictionary keys in both directions and `"a" == &"a"`, so the one-type rule is for consistency, not to avoid a missed lookup. This ADR uses `StringName` for record IDs and **ADR-0006 inherits it** for signal payloads. ID format, proposed and tighter than nothing the GDD specifies: lowercase `a-z`, `0-9` and single underscores, starting with a letter, not ending with an underscore, checked by a character scan (smaller than a `RegEx`). IDs are unique across all record types.

**5. Manifest.** `assets/data/manifest.json` is `{"files": ["res://assets/data/towers.json", ...]}`: one key, an array of `res://` paths, in load order. Load order is "manifest order" wherever the GDD uses it (the second Input record, `hero()`, `ids()`). The loader never lists a directory; a valid data file that the manifest omits is simply not loaded (GDD criterion 9). Manifest-phase errors (Decision 8) stop the load before any record check: an unreadable or unparsable manifest (parsed with the API in Decision 13), a manifest that is not exactly that shape, an empty `files` list, a repeated path (one error per repeated path), a listed file that cannot be opened, is not valid JSON, is not `{"records": [...]}`, or holds zero records, and a record type with no records in any listed file (detected after every file is parsed). The manifest path is the constant `Catalogue.MANIFEST_PATH`; it is a location, not a gameplay value.

**6. Load API and states.** `Catalogue` is a `RefCounted` instance created by `AppRoot`. Its state is `UNLOADED`, `LOADING`, `READY` or `FAILED` (read with `state()`), and the only transitions are `UNLOADED → LOADING → READY | FAILED`. `LOADING` is unobservable while the load is synchronous; it is kept as the seam for Decision 7's fallback. There is no reload: a second call to either load function returns a result holding one `already_loaded` error and changes nothing. `is_tower()` and `level_count()` are data-level building blocks; the lookup surface consumers call, and what a null or bad lookup does in battle, are ADR-0005's (architecture.md B1). The load API has three layers, and only the shell touches the disk:
- `load_from(manifest_path: String = MANIFEST_PATH) -> CatalogueLoadResult`: the I/O shell. Reads the manifest and each file, parses, then calls the pure core. This is the one call `AppRoot` makes (ADR-0001 Boot step c).
- `load_parsed(manifest_files: Array[String], docs: Dictionary) -> CatalogueLoadResult`: the pure core, no file I/O. `docs` maps path to the parsed top-level value; a listed path with no entry is `file_unreadable`. Tests build fixtures with this (Decision 13).
- `CatalogueLoadResult` has `ok: bool`, `errors: Array[CatalogueError]` and `cause() -> String` (the joined error lines, newline separated, headed by `catalogue load failed: N error(s)`). On `ok == false` the catalogue serves no lookup. `AppRoot` calls `fatal(result.cause())` and returns (ADR-0001 Decision 6); the dev build prints every line, and the fatal screen shows `cause` only when `OS.is_debug_build()` (ADR-0001). The release screen uses no catalogue data.

**7. Synchronous on the main thread, in `AppRoot._ready()`; a thread only if the phone build misses the budget.** The MVP catalogue is about 20 records (3 towers of 2 levels, 3 enemies, up to 6 waves, 1 stage, 1 hero, 1 burst, 1 input), which as JSON text is a few KB to a few tens of KB. The budget is 1000 ms median, the Android ANR limit is about 5 s, so the budget leaves a factor of five below the limit and the work is a handful of small file reads, one parse each and one linear validation pass. No measurement exists yet (the figures above are sizes, not timings), so the decision rests on the size of the work, not on a benchmark, and the first phone build measures it (Verification 4). A threaded load adds a second execution context, a hand-off to `AppRoot` and a Loading wait state, all to defend a budget that the data size makes unlikely to be missed. **Fallback trigger:** if the median over 5 cold launches exceeds 1000 ms, or any single launch exceeds 2500 ms (half the ANR limit), the load moves to a worker. That is a revision of this ADR's Decision 7 with no change to ADR-0001, which already delegates the choice here (its Decision 2(c)). Its shape is fixed now: `AppRoot` stays in `BOOT`; `load_from()` runs the shell and the pure core on a worker; `AppRoot._process` polls `catalogue.state()` each frame, where `READY` continues to ADR-0001 Boot step (d) and `FAILED` calls `fatal(result.cause())`; the fatal and retry checks in `_process` are unchanged. `load_parsed` and the validator are unchanged because the core is pure. `Thread` is not covered by the reference and is not used until verified. `AppRoot` measures the call with `Time.get_ticks_msec()` before and after and prints one timing line; `Time` is allowed there, since the ban covers `src/battle/` only. The device median (Verification 4, GDD criterion 15) comes from a release export that prints that line; whether `print` reaches the device log on a release export is checked with ADR-0001's Verification 1 (`push_error` still prints), and if neither does, the number comes from a debug export and is recorded as such.

**8. Validator: two tiers, five passes, collect everything.** Tier 1 is boot-fatal and lives in `CatalogueValidator`; it has two phases, the manifest phase and the record phase, and "tier" always means the GDD's two tiers (`validate(docs: Dictionary, files: Array[String]) -> Array[CatalogueError]`). Tier 2 is the CI content test (Decision 12). There is no warning tier (GDD Rule 7).
- **Manifest phase, manifest and files** (Decision 5). All files are parsed and all manifest-phase errors collected, then if any exist the load stops and no record pass runs.
- **Record phase,** five passes over all records in manifest order, each pass skipping any `(record_id, field)` that an earlier pass already reported, so one fault gives one error:
  1. *Shape:* `type` known, ID format, duplicate IDs (one error per record that shares an ID, message naming the other), required keys present, no unknown keys, JSON type of every value.
  2. *Numbers:* every number finite first (`non_finite`), then every integer field whole (`fractional_integer`), then every domain bound from the GDD's field-domain table (`out_of_range`), list lengths (`empty_list`, `list_too_short`), consecutive repeated points, coordinate bounds, and `pin_rect` min below max, run only on finite values.
  3. *Tags and role fields:* tags known (an unknown tag skips that record's role checks), exactly one role tag on a tower, role fields present on every level iff the tag is present, hand values valid.
  4. *References:* every reference resolves (`dangling_reference`) to the expected type (`wrong_type_reference`), using an ID table built in pass 1 from the raw data so a record that failed shape still counts as existing.
  5. *Set and cross-field:* each Input record beyond the first gets `input_record_count`; `tap_slop > drag_slop` is checked only when both fields are present, finite and in domain, and reports `tap_not_above_drag` on `tap_slop`. The resolver repeats it in `validate()` (ADR-0008).
- The schema (field names, types, min, max, which key sets) is data-shaped constants in `catalogue_schema.gd`, so one table drives the validator and the criterion-3 test rows (one row per domain row). The schema is the single source of truth for int versus float per field; ADR-0005's `StatKeys` declares each stat key's type once more, for the GDD's readable vocabulary, and a test ties it to the schema both ways (Criterion 22), so the two cannot drift. TR-data-005's listed tiers map onto the phases explicitly: manifest = the manifest phase; finiteness and bounds = pass 2; tags = pass 3; references = pass 4. Domain bounds are invariants against typos, not balance (GDD); the one-tick floor is `1/60` s, provisional until ADR-0004 fixes the rate (Ordering Note), and the schema constant is the only place it appears. The zero-Input and the zero-of-any-type cases are `record_type_empty` (manifest phase, one error); `input_record_count` covers only the extras. This reconciles the GDD's two sentences, and both yield exactly one error.
- Typed records are built by `CatalogueBuilder` only when the record phase reported nothing, so the builder can trust every type and never checks.

**9. Error structure, codes and text.** `CatalogueError` holds `code: StringName`, `source: String` (the file path, or a label such as `fixture:dup_ids` for code-built fixtures), `record_id: StringName` (empty for manifest and file errors), `field: String` (a path with 0-based indices, for example `levels[1].range`, `groups[0].count`, `pin_exclusion[0].radius`; for a manifest-phase error, the offending key or empty) and `message: String`. The four-tuple is the identity tests compare through `key()`; `message` is the human text and is never asserted by the validator tests except in the text test below. Codes, as `StringName` constants on `CatalogueError`:
- Manifest phase: `manifest_unreadable`, `manifest_parse`, `manifest_shape`, `manifest_empty`, `manifest_duplicate_path`, `file_unreadable`, `file_parse`, `file_shape`, `file_empty`, `record_type_empty`, `already_loaded`.
- Record phase: `unknown_record_type`, `bad_id_format`, `duplicate_id`, `missing_field`, `unknown_property`, `wrong_type`, `non_finite`, `fractional_integer`, `out_of_range`, `empty_list`, `list_too_short`, `repeated_point`, `bad_rect`, `bad_enum`, `unknown_tag`, `role_tag_count`, `role_field_missing`, `role_field_without_tag`, `dangling_reference`, `wrong_type_reference`, `input_record_count`, `tap_not_above_drag`.
- Tier 2 (content test only): `content_rule`, with `field` holding the rule label (`L6`, `W3`) and `message` the numbers.
`CatalogueError.text()` returns one line, `{source}: {kind} '{record_id}', field '{field}': {message} [{code}]`, so a development run prints, for example:
- `res://assets/data/towers.json: tower 'arrow', field 'levels[1].range': 0 is not above 0 and at most 2000 [out_of_range]`
- `res://assets/data/waves.json: wave 'wave_3', field 'groups[0].count': 1.5 is not a whole number [fractional_integer]`
- `res://assets/data/enemies.json: enemy 'fast', field 'move_spead': not a field of an enemy record [unknown_property]`
- `res://assets/data/enemies.json: enemy 'fast', field 'move_speed': required field is missing [missing_field]`
- `res://assets/data/input.json: input 'input', field 'tap_slop': 20 must be above drag_slop 20 [tap_not_above_drag]`
- `res://assets/data/waves.json: file, field '': line 3: Expected value, got '}' [file_parse]`
- `res://assets/data/manifest.json: manifest lists no data files [manifest_empty]`
- `res://assets/data/manifest.json: no 'burst' record in any listed file [record_type_empty]`
A record with no usable ID reports the position instead: `record 3 of file`.

**10. Read-only and the snapshot.** GDScript cannot make an object's fields constant, so read-only is a rule with a test, as the GDD says. Lookups return the live record, never a copy (a copy per accessor read would allocate in the tick). Records have no setters and nothing outside `CatalogueBuilder` assigns a field; a `grep` lint for assignments to record fields outside `src/data/` is ADR-0007's. The proof is `Catalogue.snapshot() -> Dictionary`, a plain nested `Dictionary` built fresh from every record's `to_dict()` (levels, groups, points, pin shapes included), and a test-side `snapshot_diff(a, b) -> Array[String]` returning the field paths that differ. **Hand-rolled `to_dict()`, not `duplicate_deep()`.** The reference documents `duplicate_deep()` only for nested `Resource` trees (4.5), and these records are `RefCounted`, not `Resource`; whether it copies them is not in the reference. A hand-rolled snapshot is also what GDD criterion 11 needs: the comparison must report the changed field by name, and a hand-written diff does so without depending on `Dictionary ==`, which the probe shows is content-based and nested but type-strict (`1` and `1.0`, `"x"` and `&"x"` compare unequal). The cost is that `to_dict()` can forget a field, which would blind the detector to it; the self-test (Validation Criteria 10) closes that by changing every schema field in turn and asserting the diff names it, and a count check ties the test's row list to the schema, so a new field without a test row fails. `CatalogueBuilder` also calls `Array.make_read_only()` on every array it stores in a record (the probe shows it exists and works; Validation Criterion 19 confirms it on a typed array). It hardens the arrays only, not the records' scalar fields, so the snapshot test stays the proof. `snapshot()` is dev and test use only; it is not a save schema and has no `from_dict()`.

**11. Stage record (TR-enemy-001).** The Stage record holds all gameplay geometry and start values: `scene_ref: String`, `wave_ids: Array[StringName]`, `starting_gold: int`, `starting_lives: int`, `early_call_seconds_per_gold: float`, `path_points: Array[Vector2]`, `slot_positions: Array[Vector2]`, `path_width: float`, `requires_bend: bool`, `hero_start: Vector2`, `pin_rect_min: Vector2`, `pin_rect_max: Vector2` (JSON key `pin_rect` is `{"min": [x, y], "max": [x, y]}`) and `pin_exclusion: Array[PinExclusion]`. The stage scene holds only the look (hue, base value, grid tilt; ADR-0011). `scene_ref` is a `String` path, not a loaded resource: the GDD's Rule 9 bans opening scenes at boot, and ADR-0001 loads the scene at stage start with `load()` and a null check into `fatal()`. Boot validates that `scene_ref` is a non-empty string beginning `res://`; whether the scene exists is the content test's (project) and the first phone run's (export). A repeated wave ID in `wave_ids` is legal. Vector2 components are float; the validator checks the raw doubles, and `Vector2` is single precision (probe: `173.99` is stored as `173.9900054932`), so stored values differ slightly from the authored doubles; the snapshot compares stored values and content-test boundaries (L6 at 174 against 173.99) still separate on float32 (Validation Criterion 20).

**12. Content tests (TR-data-013, TR-hero-014, TR-hud-016).** They live in `tests/integration/data/` and run on the project, not the export, against the real manifest loaded through `load_from()` (so they also prove the manifest). The runner and harness are ADR-0007's; the rules are here. One function per rule row, each with a pass on the starter data and a fail on a broken fixture (the factory builds fresh raw dictionaries per call, so a test breaks one field of a fresh copy and nothing is shared), with boundary pairs where a bound is exact (L6 at 174 passes and 173.99 fails; `lives_cost` 4 passes and 5 fails). Failures are `CatalogueError` values with code `content_rule`. The rule set is the tables of:
- *Data & Config Rule 9:* every `scene_ref` opens (a broken fixture scene fails naming its stage); every record's `rationale` is non-empty.
- *Enemy & Wave:* layout rules L1 to L9, L12, L13 now and L10, L11, L14 with the Tower and Hero stories; the wave rules table (first spawn, largest gap, `time_to_exit`, `lives_at_risk` rows, `lives_cost` cap, `peak_alive_ub`, strictly increasing spawn ticks, at least 2 waves and `starting_lives` at least 2 on real stages).
- *Hero:* `leash_radius`, telegraph travel, intermission, `burst_spike`, L11, L14, `reach`, `hero_start`, `pin_exclusion` coverage, Burst `damage`, `pin_rect` margins, exactly one Hero record.
- *Battle HUD:* the content-rules table (slot bounds, arc and Start/Call clearances, at most 3 next-wave types, at most 6 waves and 10 lives, the burst line at least `edge_reject_margin` + 48 from a side edge, early-call bonus at most 2 digits, a next-try line per enemy type, chip clearances, tower body against the Won panel).
Rows that need hit radii or button geometry read the constants ADR-0010 puts on the input objects; rows that need `to_ticks` read ADR-0004's. The broken-fixture scene case follows Verification 7 (existence check if gdUnit4 counts the engine `ERROR:` from `load()`). The scene-check question is answered **yes, the project check plus the manual export check is enough for MVP**: the starter stage's `scene_ref` is exercised on the export by the first phone run (Verification 5), and ADR-0001's runtime `load()` null check reaches the fatal screen if it fails there.

**13. Fixtures.** Logic tests build catalogues in code with no file I/O: a factory (location ADR-0007's; the need is named here) returns a valid raw document set and a `Catalogue` built from it through `load_parsed()`, so fixtures run through the real validator. Two fixtures with different values read side by side (criterion 8). A fixture `source` is a label such as `fixture:valid_starter`. The factory builds fresh dictionaries per call and has no shared state. Parsing uses `var j := JSON.new(); var err := j.parse(text)`: on `err != OK` the result is `file_parse` (or `manifest_parse`) with message `"line %d: %s" % [j.get_error_line(), j.get_error_message()]`, otherwise the value is `j.get_data()`. `JSON.parse_string` is not used: it returns `null` for a failure, an empty text and a literal `null` alike, reports no line or message, and prints an `ERROR:` with a backtrace on every failure (probe), which every broken-fixture test would hit. `JSON.new().parse` prints nothing and returns `OK` with `get_data() == null` for the text `null`, which then falls to `file_shape`. An empty text is `file_empty`. `CatalogueParser.parse(source, text)` wraps this as a pure function from text to a value or a `CatalogueError`, so parse-level cases run with no file.

**14. Android export proof (TR-data-003, TR-data-015, criteria 13 and 15).** The test runner cannot run on an export, so the proof is manual, retained in `production/qa/evidence/`, and has a built-in boot check: every manifest file the loader cannot open is a `file_unreadable` error, so a data file missing from the `.pck` fails the load before any gameplay. The first phone build must show: (a) Ready with the real manifest and all records present; (b) the data files are in the export: `.json` is a registered resource extension on 4.7.2 (probe), so the default export is expected to pack them; confirm on the Android export and add an include filter only if a file is missing, recording which; (c) a throwaway release build with one invalid record (a fractional `count`; `NaN` cannot be written in JSON, it is a parse error) shows the generic fatal screen and creates no file under `user://` (no save exists at MVP), with the screenshot; a bad accessor call reaching the fatal screen on the export is owned by ADR-0005 and ADR-0001; (d) the cold-launch median; (e) the stage scene loads. This shares ADR-0001 Verification item 2. Boot needs no `FileAccess.file_exists()` call: `FileAccess.open` returning `null` is the presence check (probe on desktop: `ERR_FILE_NOT_FOUND`; export in Verification 3). The content test may use `ResourceLoader.exists()` (Decision 12).

**15. Save/Load (QQ-21): deferred, seams recorded here, no separate ADR.** Save/Load is a Vertical Slice system and has no GDD. The seams already exist and are recorded as constraints: progression systems own their save schema and give it `to_dict()` and `from_dict()` with a version field; progression systems never call Save directly; saves hold only stable IDs and levels (so a data retune never invalidates a save); and a retired-ID list arrives at Vertical Slice, when the validator gains `retired_id_live` and `retired_id_referenced` codes (GDD Vertical Slice edge cases). The catalogue never opens a save, and a failed load never touches one (GDD Rule 8). **What the Pre-Production gate should read:** "Save/Load: deferred to Vertical Slice by ADR-0002 Decision 15; seams recorded (`to_dict()`/`from_dict()` with version, no direct Save calls from progression systems, stable IDs, retired-ID list at Vertical Slice); no ADR required until the Save/Load GDD exists." A thin ADR now would decide the file format and migration before a single progression record exists to save.

### Architecture Diagram

```
assets/data/manifest.json ──► {"files": [towers.json, enemies.json, waves.json, hero.json, input.json, stage_01.json]}
assets/data/*.json   ──► {"records": [ {"type": "tower", "id": "...", "rationale": "...", ...}, ... ]}

AppRoot._ready ──► Catalogue.load_from(MANIFEST_PATH)            (only call that touches disk)
                      │ read manifest, read + parse each file     manifest phase: manifest/file errors ─┐
                      ▼                                                                         │ any? stop
                  Catalogue.load_parsed(files, docs)  (pure; fixtures call this directly)       │
                      │ record_type_empty check ────────────────────────────────────────────────┤
                      │ CatalogueValidator: pass 1 shape · 2 numbers · 3 tags · 4 refs · 5 set  │
                      │                      record phase: collect every CatalogueError ──────────────┤
                      ▼                                                                         ▼
              errors == [] ? CatalogueBuilder ─► typed RefCounted records   CatalogueLoadResult(ok=false, errors)
                      │  state READY                                         state FAILED ─► AppRoot.fatal(result.cause())
                      ▼
   lookups: stage(id) tower(id) enemy(id) wave(id) hero() burst(id) input() ids(kind) is_tower(id) level_count(id)
   snapshot() ─► Dictionary (tests)          CI content test (tests/integration/data/): scene_ref + layout + wave + Hero + HUD rules
```

### Key Interfaces

```gdscript
class_name Catalogue extends RefCounted
enum State { UNLOADED, LOADING, READY, FAILED }
const MANIFEST_PATH := "res://assets/data/manifest.json"
const KIND_TOWER := &"tower"        # also KIND_ENEMY, KIND_WAVE, KIND_STAGE, KIND_HERO, KIND_BURST, KIND_INPUT
func state() -> State
func load_from(manifest_path: String = MANIFEST_PATH) -> CatalogueLoadResult   ## I/O shell. Under src/ only AppRoot._ready() calls it; integration tests may, on a fresh Catalogue.
func load_parsed(manifest_files: Array[String], docs: Dictionary) -> CatalogueLoadResult   ## Pure core; no file I/O. Fixtures and tests call this.
# Lookups: non-fatal, return null for an unknown ID or when not READY. Callers null-check; the builder routes null to fatal(); how the accessor handles a null record, and the lookup surface consumers call, are ADR-0005's.
func stage(id: StringName) -> StageRecord
func tower(id: StringName) -> TowerRecord
func enemy(id: StringName) -> EnemyRecord
func wave(id: StringName) -> WaveRecord
func burst(id: StringName) -> BurstRecord
func hero() -> HeroRecord                       ## The one Hero record (first in manifest order).
func input() -> InputRecord                     ## The one Input record; read directly, not through the accessor.
func ids(kind: StringName) -> Array[StringName] ## Manifest order. Unknown kind: empty array.
func is_tower(id: StringName) -> bool           ## Data-level primitive; non-fatal.
func level_count(def_id: StringName) -> int     ## Data-level primitive; 0 for a non-tower. Non-fatal.
func snapshot() -> Dictionary                   ## Deep plain-data copy of every record, for the read-only test. Not a save schema.

class_name CatalogueLoadResult extends RefCounted
var ok: bool
var errors: Array[CatalogueError]
func cause() -> String                          ## "catalogue load failed: N error(s)" then one text() line each. Passed to fatal().

class_name CatalogueError extends RefCounted
var code: StringName          # a constant on this class, see Decision 9
var source: String            # file path, or a label for code-built fixtures
var record_id: StringName     # empty for manifest and file errors
var field: String             # "levels[1].range", "groups[0].count"; 0-based indices
var message: String
func key() -> String          ## "code|source|record_id|field": the identity tests compare.
func text() -> String         ## One line for the development run.

class_name CatalogueSchema extends RefCounted
## Data-shaped constant the validator, the criterion-3 rows and ADR-0005's tie test all read. Fields are named by JSON key (so `range`, not `range_units`; the record-field mapping is the builder's and the accessor's).
const FIELDS: Dictionary = {}   # kind -> field -> {type: TYPE_INT | TYPE_FLOAT | TYPE_STRING | ..., min, max}; kinds: Catalogue.KIND_ENEMY, KIND_HERO, KIND_BURST, and &"tower_level" for a tower's per-level fields. Shape is fixed here; contents are the GDD domain table.
const ROLE_FIELD_TAG: Dictionary = {}   # role field (splash_radius, slow_strength, slow_duration) -> the tower tag that requires it

class_name CatalogueParser extends RefCounted
static func parse(source: String, text: String) -> Variant   ## Parsed value, or a CatalogueError (file_parse, file_empty). Uses JSON.new().parse(); never JSON.parse_string. Pure; no file.

class_name TowerRecord extends RefCounted
var def_id: StringName
var rationale: String
var tags: Array[StringName]
var levels: Array[TowerLevel]
func to_dict() -> Dictionary
class_name TowerLevel extends RefCounted
var cost: int
var damage: float
var range_units: float                  # JSON and stat key: "range"
var attack_interval: float
var visual_key: StringName
var splash_radius: float                # 0.0 unless the tower has the splash tag
var slow_strength: float                # 0.0 unless slow
var slow_duration: float                # 0.0 unless slow
class_name EnemyRecord extends RefCounted   # def_id, rationale, max_hp, move_speed, bounty: int, lives_cost: int, visual_key, tags
class_name WaveRecord extends RefCounted    # def_id, rationale, groups: Array[WaveGroup], intermission_duration
class_name WaveGroup extends RefCounted     # enemy_id: StringName, count: int, spawn_interval, start_delay
class_name HeroRecord extends RefCounted    # def_id, rationale, damage, attack_interval, leash_radius, walk_speed, burst_id: StringName, visual_key
class_name BurstRecord extends RefCounted   # def_id, rationale, damage, radius, reach, cooldown, telegraph_duration
class_name InputRecord extends RefCounted   # def_id, rationale, drag_slop, tap_slop, edge_reject_margin, left_handed: bool, reduce_motion: bool
class_name StageRecord extends RefCounted
var def_id: StringName
var rationale: String
var scene_ref: String                   # path, never loaded at boot
var wave_ids: Array[StringName]
var starting_gold: int
var starting_lives: int
var early_call_seconds_per_gold: float
var path_points: Array[Vector2]
var slot_positions: Array[Vector2]
var path_width: float
var requires_bend: bool
var hero_start: Vector2
var pin_rect_min: Vector2
var pin_rect_max: Vector2
var pin_exclusion: Array[PinExclusion]
class_name PinExclusion extends RefCounted  # a: Vector2, b: Vector2, radius: float, hand: StringName (&"right", &"left", &"both")

# AppRoot (ADR-0001 Boot step c):
#   var catalogue := Catalogue.new()
#   var result := catalogue.load_from()
#   if not result.ok:
#       fatal(result.cause())
#       return
```

### Implementation Guidelines
- Gameplay data **must** live in `assets/data/` JSON files listed in `assets/data/manifest.json`; the loader **must never** list a directory or load a file the manifest does not name.
- Every file under `src/data/` **must** extend `RefCounted`, **must never** extend `Node`, declare a `static var`, or use `assert()`; `src/data/` **must never** import `src/battle/`, `src/presentation/` or `src/app/`.
- `load_from()` **must** be the only function that reads a file; the validator, parser, builder and `load_parsed()` **must never** touch the disk.
- Under `src/`, `load_from()` **must** be called once, by `AppRoot` in `_ready()`, on the main thread; no other code under `src/` **must ever** call it, and a reload path **must never** exist. Integration tests under `tests/integration/data/` may call it on a fresh `Catalogue`; unit tests use `load_parsed()` only. ADR-0007's lint greps `src/` and leaves `tests/` alone.
- The validator **must** run every record-phase pass over every record and return all errors; it **must never** stop at the first, and **must never** run a record pass after a manifest-phase error.
- Every integer field **must** be checked with finiteness first, then wholeness, then bounds; a JSON `bool` **must never** pass as a number.
- `CatalogueBuilder` **must** run only when the record phase reported zero errors and **must never** default, clamp, round or truncate a value. A new field **must** be added to the schema, the validator, the builder, `to_dict()`, the snapshot self-test row and the GDD domain table in one change.
- Record fields **must** be assigned only inside `CatalogueBuilder`; code outside `src/data/` **must never** assign a record field or mutate a record's arrays.
- Lookups **must** return the live record and **must** be non-fatal; callers **must** null-check, and `Catalogue` **must never** call `fatal()` itself.
- Code reading a tower level **must** read role fields only through the stat accessor (ADR-0005), **never** directly.
- Text **must** be parsed with `JSON.new().parse()`; code **must never** use `JSON.parse_string`. `CatalogueBuilder` **must** call `make_read_only()` on every array it stores in a record.
- Record IDs **must** be `StringName` everywhere in code; raw strings **must** be converted once, in the builder.
- `scene_ref` **must** be a `String` and **must never** be loaded at boot.
- A `fatal()` route for load failure **must** be `fatal(result.cause())`; a development run **must** print every `CatalogueError.text()` line, and the release fatal screen **must** use no catalogue data.
- Balance values **must never** be hardcoded in code; the schema's domain bounds are invariants against typos only.
- Content-rule failures **must** be `CatalogueError` values with code `content_rule` and **must never** run at boot.
- Fixtures **must** be built in code through `load_parsed()` with no file I/O, and **must never** share mutable dictionaries between tests.
- The Hero and wave rows that need `to_ticks` **must** use ADR-0004's conversion, never a local copy.

## Alternatives Considered

### Alternative 1: Typed `Resource` records (`.tres`) as the source of truth
- **Description**: One `Resource` subclass per record type with `@export` fields, authored in the inspector and loaded with `ResourceLoader`. The GDD's stated recommendation.
- **Pros**: Editor inspector and autocomplete; `duplicate_deep()` (4.5, in the reference) applies directly to a snapshot.
- **Cons**: Detection is the problem. Observed on 4.7.2 (probe): a missing field takes its default, `1.5` in an int export loads as `1`, a string in a float export as `0.0`, and an unknown property is dropped, all with no error, so TR-data-002 needs a second parser of the `.tres` text or a parallel schema, which is the validator below with extra steps. `.tres` diffs for a one-value edit carry resource headers and are harder to review than a JSON line. Resources can carry scripts, which a content-only catalogue does not want.
- **Rejection Reason**: The GDD makes detection a requirement either format could meet, by adding "a check on top of it". The deciding factor is that the check is smaller on raw JSON: with Resources the check would have to read the file text anyway. Chosen against the GDD's recommendation for that reason, with the recommendation's own condition (the format must detect the three faults, or a check must be added) as the justification.

### Alternative 2: Resources plus a schema check
- **Description**: `.tres` records plus a validator that reads each `.tres` as text, or a reflection pass over loaded properties.
- **Pros**: Keeps the inspector.
- **Cons**: Two sources of truth (the class and the schema) that can drift; text-level parsing of `.tres` is more code than JSON parsing; reflection cannot see a field the loader dropped (unverified).
- **Rejection Reason**: More code than the chosen option for the same guarantee.

### Alternative 3: GDScript constant dictionaries
- **Description**: Data as `const` dictionaries in `.gd` files.
- **Pros**: No parser, no export-filter question (scripts are packed).
- **Cons**: A data edit is a code change; a typo is a parse error or silent; the file cannot be validated as data before it runs; tools and bots cannot read it without running code.
- **Rejection Reason**: Contradicts Data Rule 1's intent (data, not code) and the tuning loop (criterion 14).

### Alternative 4: Directory scan instead of a manifest
- **Description**: Load every `.json` under `assets/data/`.
- **Pros**: A new file needs no manifest edit.
- **Cons**: Exported builds rename and package files, and listing a packed directory is not in the reference; an unlisted stray file silently joins the catalogue.
- **Rejection Reason**: Data Rule 4 and TR-data-003 forbid it.

### Alternative 5: Threaded load from the start
- **Description**: A worker thread reads and validates; `AppRoot` waits in `BOOT`.
- **Pros**: Immune to a slow device by construction.
- **Cons**: A second execution context, a hand-off and a wait state for about 20 records; the `Thread` API is not in the reference; the failure modes (a result read before ready) are new defects.
- **Rejection Reason**: The data size makes the budget unlikely to be missed (Decision 7). Kept as the measured fallback, a revision of this ADR's Decision 7 that the pure core makes cheap.

### Alternative 6: `duplicate_deep()` for the snapshot
- **Description**: Make records `Resource` and snapshot with `duplicate_deep()` (4.5).
- **Pros**: One call; in the reference.
- **Cons**: Needs `Resource` records, which Decision 3 avoids (gameplay classes are `RefCounted`, ADR-0001); the diff still has to be hand-written to name the changed field.
- **Rejection Reason**: A hand-rolled `to_dict()` is needed for the diff anyway and works on `RefCounted` records.

### Alternative 7: A thin save/load ADR now (QQ-21)
- **Description**: Decide the save file format and migration scheme in a separate ADR.
- **Pros**: The Pre-Production gate's Foundation examples are fully covered.
- **Cons**: There is no Save/Load GDD and no progression record to save; the decision would be made blind and revised at Vertical Slice.
- **Rejection Reason**: The seams are already in the layer map; Decision 15 records them and the exact gate wording.

## Consequences

### Positive
- All three TR-data-002 faults are detected by code we own and unit-test on every engine version, independent of how `Resource` or `JSON` behave.
- Typed records are built only from clean data, so a field read can never return a silent default or a truncated value.
- One fault gives one error with file, record and field; a whole bad data pass is fixed in one run (criteria 2 and 4).
- The pure core means every validator, fixture and error-code test runs with no file I/O, and a threaded load later changes only the shell.
- A data edit is a one-line JSON diff (criterion 14).

### Negative
- No inspector or autocomplete for data; authors edit JSON by hand and rely on the validator.
- We maintain a schema and a validator instead of using the engine's resource system; a new field touches schema, validator, builder, `to_dict()` and a test row (one checklist, listed in the guidelines).
- Read-only is a rule with a test, not engine-enforced; a stray write is caught only by the snapshot test or review.
- The export is expected to pack the JSON files by default (`.json` is a registered resource extension on 4.7.2, probe), unconfirmed until the Android export; a filter is added only if a file is missing.
- `to_dict()` can drift from the record; the self-test and its row-count tie are the guard.
- A fourth source root `src/data/` extends ADR-0001's three.

## Risks
- **The export drops the JSON files or the parser behaves differently on Android.** Mitigation: a missing file is a boot `file_unreadable` error; Verification 1 and 2 before the Boot story closes; the pure core is unaffected.
- **A repeated key in one JSON object passes the validator.** Observed (probe): the parser keeps the last value silently, and the validator sees only a `Dictionary`. Mitigation: ADR-0007 owns a CI text check for repeated keys in `assets/data/` (firm delegation, Dependencies table).
- **Every JSON number parses as `float`.** Observed (probe). Mitigation: the integer check accepts both types; the builder converts with `int()` after validation; unit tests pin the 100,000 ceiling and `1e400` giving `non_finite`.
- **Vector2 stores less precision than the authored doubles.** Observed: single precision. Mitigation: the snapshot compares stored values, so it is unaffected; the validator checks the raw doubles; content-test boundaries still separate on float32 (Validation Criterion 20); a coordinate needing more precision is a content change.
- **`to_dict()` forgets a field and the snapshot test goes blind to it.** Mitigation: the per-field self-test and the schema row-count tie.
- **The load misses 1000 ms on the phone.** Mitigation: Decision 7's fallback trigger and the thread route; the data stays pure.
- **Someone mutates a record through a returned array.** Mitigation: the snapshot test in the Tower and Enemy & Wave stories (GDD deferred criterion), the grep lint, review. `make_read_only()` on the arrays narrows it (Decision 10).
- **Rule thresholds in the content test drift from the GDDs.** Mitigation: one function per GDD row, named after the row label, and the GDD domain table updated in the same change as the schema.
- **An ID format stricter than the author expects.** Mitigation: the `bad_id_format` message states the rule; the format is proposed and revisited at the first review.
- **The schema's one-tick floor drifts if ADR-0004 changes the rate.** Mitigation: the constant is the only occurrence, referenced by ADR-0004.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-001: typed read-only records keyed by a unique snake_case ID; typed ID references, never file paths | Decision 3 (typed `RefCounted` records), Decision 4 (`StringName` IDs, format, cross-type uniqueness), Decision 8 pass 1 and 4 (duplicate and reference checks) |
| data-config-pipeline.md | TR-data-002: the format, or a check on top, detects a missing field, a fractional integer and an unknown property | Decision 1: JSON source; schema key walk for `missing_field` and `unknown_property`; `typeof`, `is_finite`, `floor(x) == x` for `fractional_integer`; typed records built only from clean data |
| data-config-pipeline.md | TR-data-003: explicit manifest, never a directory scan, loads from an Android export | Decision 5 (manifest rule and manifest-phase errors), Decision 14 (export proof, boot-time `file_unreadable`); the export result is a Verification item, not yet proven |
| data-config-pipeline.md | TR-data-005: validator collects `{code, source, record_id, field}` in tiers; `tap_slop > drag_slop` at load | Decision 8 (tiers, five passes, collect all), Decision 9 (structure, codes, text), pass 5 (cross-field) |
| data-config-pipeline.md | TR-data-007: definitions read-only after load; deep-snapshot test | Decision 10 (live records, no setters, `snapshot()` and diff, self-test); Validation Criteria 10. The second clause (mutable state on runtime instances holding `def_id`) is owned by ADR-0009 (Enemy instances) and ADR-0010 (Tower and Hero instances); this ADR supplies only the `def_id` they hold |
| data-config-pipeline.md | TR-data-013: CI content test opens each `scene_ref`, applies layout and wave rules, checks `rationale` and balance ranges | Decision 12 (`tests/integration/data/`, one function per rule row, broken fixtures); runner is ADR-0007's |
| data-config-pipeline.md | TR-data-015: median load at most 1000 ms on an Adreno 5xx-class device; edit to in-game at most 10 s | Decision 7 (synchronous, sizes against 1000 ms and the 5 s ANR limit, fallback trigger); Verification 4; JSON one-line diff for the 10 s loop (criterion 14); unmeasured until a phone build |
| enemy-wave.md | TR-enemy-001: Stage record holds geometry; the scene holds only the look | Decision 11 (all geometry fields on `StageRecord`, `scene_ref` as a `String`), Decision 3 |
| hero-system.md | TR-hero-014: content tests enforce hero and burst rules, each proven on a broken fixture | Decision 12 (Hero rule rows, exactly one Hero record, `hero()` lookup); telegraph row waits for ADR-0004's `to_ticks` |
| battle-hud.md | TR-hud-016: content tests enforce HUD layout rules | Decision 12 (HUD content-rules table, geometry constants from ADR-0010); `ids()`, `level_count()` and tower tags for the HUD checks |

## Performance Implications
- **CPU**: One synchronous load at boot: a few small file reads, one parse each and a linear validation over about 20 records. Unmeasured; the figure to beat is the 1000 ms median (Verification 4). Nothing runs after Ready except lookups, which are dictionary reads. `snapshot()` is test use only.
- **Memory**: A few KB of records for the session; the JSON text and raw dictionaries are locals freed after the load. The validator's ID table and poisoned-field set die with the call.
- **Load Time**: At most 1000 ms median on the named device, well under the 5 s ANR limit; fallback to a worker if missed (Decision 7).
- **Network**: None.

## Migration Plan
Greenfield: `src/` holds no `.gd` file and `assets/` does not exist. Create `assets/data/manifest.json` and the data files from the starter values in the Enemy & Wave, Tower, Hero and Input GDDs (prototype constants are fixtures, not balance); `src/data/` as in Decision 2; `tests/unit/data/` and `tests/integration/data/`. No export filter is added up front; add one on the first Android export only if a data file is missing there (Decision 14). Copy the probe folder to `prototypes/adr-0002-spike/` when this ADR is Accepted.

At acceptance (`/architecture-review`, through the producer for GDD files):
- `architecture.md`: B0 renames `LoadResult` to `CatalogueLoadResult` and `ValidationError` to `CatalogueError`, `field: StringName` to `String`, record `id` to `def_id`, and its `src/foundation/data/` paths (records and `read_context.gd`) to the `src/data/` decision; the Catalogue row (`load_from`, line 121) and Validator row (`validate(docs, files)`, line 122); line 361 and line 271; the ADR-0002 paragraph ("read-only proof with duplicate_deep" becomes the hand-rolled snapshot) and the QQ-03 and QQ-21 text; the ADR-0007 paragraph gains the `src/data/` lint and the firm repeated-key check.
- `design/gdd/data-config-pipeline.md`: the Open Questions rows answered here (storage format and read-only enforcement; snapshot mechanics and integer representation; scene checks on the project) and the "Becomes an ADR" note, which recommends typed Resources.
- ADR-0001 Related line on QQ-21.

## Validation Criteria
Mapped to the GDD's 15 acceptance criteria:
1. (GDD 1) Fixtures with a cross-type duplicate ID, a dangling reference and a `burst_id` naming an enemy fail with the expected four-tuples, one per record for duplicates.
2. (GDD 2) A table-driven set of fixtures yields exactly one expected `{code, record_id, field}` each, including the single `unknown_tag` on a tower with no other tag and the role-tag-only error for empty `tags`.
3. (GDD 3) Boundary tests: one row per domain row (the NaN and infinity rows are code-built fixtures through `load_parsed()`; the file-level `non_finite` fixture is `1e400`), NaN and infinity give `non_finite` not `out_of_range`, `tap_slop` 20 against `drag_slop` 20 gives one error on `tap_slop`, a NaN `pin_rect` coordinate gives only the non-finite error, and the whole-number check accepts a whole float and an int up to 100,000.
4. (GDD 4) A fixture seeded with 5 unrelated errors reports exactly those 5 four-tuples, in any order.
5. (GDD 5) An empty manifest, a type with no records, a repeated path and an empty file, each beside an otherwise invalid record, give one manifest-phase error, no record error, state FAILED and no lookup served; a valid fixture is READY. `file_unreadable` is tested as unit through `load_parsed()` with a listed path missing from `docs`; `manifest_unreadable` is reached only through `load_from()` and is an integration test, so the no-I/O rule for unit tests holds.
6. (GDD 6, 7, 12) Owned by ADR-0005 and ADR-0001 (accessor reads, spy handler, fatal route); this ADR supplies the records, `level_count()`, `is_tower()` and fixtures they use.
7. (GDD 8) Two code-built fixtures with different values read side by side with no file I/O.
8. (GDD 9) The real manifest plus a valid unlisted data file gives zero errors, every listed record present and the unlisted record absent.
9. (GDD 10) Every Stage `scene_ref` opens in the content test; a broken fixture scene fails naming its stage.
10. (GDD 11) Detector self-test: a snapshot after a deliberate change to each schema field in turn reports that field's path; an unchanged catalogue reports none; the test's row count equals the schema field count.
11. (Read-only end to end) Deferred to the Tower and Enemy & Wave stories: the snapshot is equal after a scripted fixed-tick battle in which an enemy spawned and died.
12. (GDD 13) Manual, first phone build: the release export with one invalid record shows the generic fatal screen and creates no file under `user://` (no save exists at MVP, so "save unchanged" is vacuous until Save/Load); screenshot retained in `production/qa/evidence/`. The clause "a bad accessor call also reaches it" is owned by ADR-0005 and ADR-0001.
13. (GDD 14) Manual: one value edited, `git diff` shows only a data file, the new value is logged on the next run's first frame, time noted against 10 s.
14. (GDD 15) Manual: median Loading to Ready at most 1000 ms over 5 cold launches on one named Adreno 5xx-class device; over budget triggers Decision 7's fallback.
15. Export proof (deferred criterion "Android export loads the catalogue"): Verification items 1, 2, 3, 5 recorded on the first phone build.
16. Error text: every code in Decision 9 has one test asserting `text()` for a fixture of that code, so the development run's per-field text is checked, not only the four-tuple.
17. Content tests: each rule row in Decision 12 passes on the starter data and fails on its broken fixture.
18. Engine primitives: one unit test pins `typeof` for int, float, bool and String, `is_finite` on NaN and infinity, and `floor(x) == x` on 1.5 and 100000.0.
19. `Array.make_read_only()` on an `Array[TowerLevel]` succeeds and the array still reads (Verification 8); if it fails, Decision 10's call is dropped and the snapshot test alone is the proof.
20. Float32: a `Vector2` boundary pair (L6 at 174 and 173.99) still separates after storage.
21. Parse API: broken text gives `file_parse` with a line and message and prints no engine `ERROR:`; the text `null` gives `file_shape`; empty text gives `file_empty`.
22. Tie test: the stat-key types ADR-0005 declares equal the schema's int and float types.

## Related
- `docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md`: Decisions 2, 6, 10; delegations to this ADR (load API, sync or threaded, per-field text).
- `docs/architecture/architecture.md` v4: Module Ownership (Catalogue, Validator), Data Flow 4, Required ADRs (ADR-0002), QQ-03, QQ-11, QQ-21.
- `design/gdd/data-config-pipeline.md` Core Rules, Rules 1 to 13, Edge Cases, Acceptance Criteria 1 to 15, Open Questions (storage format, snapshot mechanics and integer representation, scene checks on the project) answered here; `design/gdd/enemy-wave.md` Rules 2, 3 and Layout and wave rules; `design/gdd/hero-system.md` content rules; `design/gdd/battle-hud.md` content rules.
- `docs/registry/architecture.yaml`: the stances this ADR sets (record ID type, load API, storage format, no fallback, read-only, manifest) are appended when it is Accepted.
