# Data & Config Pipeline

> **Status**: In Review (fifth design review 2026-11-04, full, NEEDS REVISION; its 5 blocking items applied the same day, re-review pending; see the review log)
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-04
> **Last Verified**: 2026-11-01
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-01 — CONCERNS applied (`visual_key` on Enemy and Hero, art bible mapping, Open Questions widened)
> **Implements Pillar**: Enabling system for all four pillars (Pillar 1 and 3 most directly: growth and stage variety are data)

## Summary

The read-only catalogue of every authored gameplay value: towers, enemies, waves, stages, the hero and its burst, each with a stable ID. Players never see it, but it is why a tower can be retuned or a stage added without touching code, and why bad data stops the game loudly instead of silently corrupting balance. It loads once, validates everything, and serves all stat reads through one accessor so skill-tree modifiers can slot in later with no call-site changes.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

The Data & Config Pipeline is the read-only catalogue of every authored gameplay value in TowerRiot: what each tower costs and does at each level, how tough and how rewarding each enemy is, what each wave sends, what each stage starts with, and how the hero and its burst behave. Players never interact with it directly. They feel what it enables: because no gameplay number lives in code, a tower can be retuned, a wave reshaped or a new stage added by editing data and running the game, which is what makes 20 distinct stages (Pillar 3) and visible growth (Pillar 1) affordable for one developer. It also gives every other system one honest source of truth, so the hero's damage share (Pillar 2) is measured against the designed values and not a stray constant. This system guarantees base values only; the share itself is measured from Combat's DamageEvent. Without it, tuning means editing code and every balance pass risks a regression.

## Detailed Design

### Core Rules

**Catalogue contents (MVP minimum).** Every record has a stable `id` and a `rationale` (one line saying where the numbers came from, meeting the "balance values link to their source" standard).

| Record | Fields |
|---|---|
| Tower | `tags`; `levels[]`, each with absolute values (never deltas): `cost`, `damage`, `range`, `attack_interval`, `visual_key`, and role fields where relevant (`splash_radius`, `slow_strength`, `slow_duration`) |
| Enemy | `max_hp`, `move_speed`, `bounty`, `lives_cost`, `visual_key`, `tags` |
| Wave | `groups[]`, each with `enemy_id`, `count`, `spawn_interval`, `start_delay`; `intermission_duration`, the time before the next wave, ignored on the last wave |
| Stage | `scene_ref`, `wave_ids[]`, `starting_gold`, `starting_lives`, `early_call_seconds_per_gold`, `path_points[]`, `slot_positions[]`, `path_width`, `requires_bend` (bool, for layout rule L11), `hero_start`, `pin_rect`, `pin_exclusion` |
| Hero | `damage`, `attack_interval`, `leash_radius`, `walk_speed`, `burst_id`, `visual_key` |
| Burst | `damage`, `radius`, `reach`, `cooldown`, `telegraph_duration` |
| Input (one record, added by the Input GDD; read directly, not through the stat accessor) | `drag_slop`, `tap_slop`, `edge_reject_margin`, `left_handed`, `reduce_motion` (bools, authored explicitly like every field and false at MVP; they are the data flags until Settings exists at Alpha, which then supplies the runtime value through Flow's injection rather than writing the record. Flow's builder injects the hand; views that honour Reduce Motion read its flag) |

**Extension rule.** These tables are the MVP minimum. An owning GDD adds a field by updating the domain table and the validator in the same change; no empty fields are reserved ahead of need. Adding a field must not change the loader or accessor contract. The Enemy & Wave GDD added the Stage geometry fields this way; routes, locomotion and armour or resist wait for Vertical Slice.

**Field domains.** These are invariants against typos and broken simulation, not balance. Balance ranges belong to the owning GDDs. All ceilings and the floor are proposed.

| Field | Type | Min | Max | Balance owner |
|---|---|---|---|---|
| `attack_interval`, `spawn_interval`, `cooldown`, `slow_duration`, `early_call_seconds_per_gold` | float, seconds | 1/30, one tick at the slowest rate Flow's Tuning Knobs allow (30 to 60 per second), so every interval is at least one tick whatever ADR-0004 picks; compared as a float, `x >= 1/30` | 600 | Tower, Enemy & Wave, Hero |
| `telegraph_duration`, `start_delay` | float, seconds | 0 | 600 | Hero, Enemy & Wave |
| `damage` | float | 0 | 1,000,000 | Tower, Hero |
| `range`, `leash_radius`, `radius`, `reach`, `splash_radius` | float, field units | above 0 | 2,000 | Tower, Hero |
| `move_speed` (as authored; slowed speed is Combat's), `walk_speed` | float, field units/s | above 0 | 2,000 | Enemy & Wave, Hero |
| `max_hp` | float | above 0 | 1,000,000 | Enemy & Wave |
| `slow_strength` | float | above 0 | below 1 | Tower; meaning owned by Combat. 0 is dead data and 1 would freeze enemies |
| `cost`, `bounty`, `starting_gold` | int | 0 | 100,000 | Tower, Enemy & Wave |
| `lives_cost` | int | 0 | 1,000 | Enemy & Wave |
| `intermission_duration` | float, seconds | 0 | 600 | Enemy & Wave |
| `drag_slop` | float, field units | 8 | 30 | Input |
| `tap_slop` | float, field units | 16 | 34 | Input; must also exceed `drag_slop` (Rule 7's cross-field check) |
| `edge_reject_margin` | float, field units | 0 | 36 | Input; the Battle HUD burst rule requires m ≤ 36 (Input Formulas, Input record domains) |
| `count` | int | 1 | 500 | Enemy & Wave |
| `starting_lives` | int | 1 | 1,000 | Enemy & Wave |
| `path_width` | float, field units | above 0 | 2,000 | Enemy & Wave |

Simultaneous spawns are expressed by overlapping groups, not an interval of 0.

`path_points` holds at least 2 points with no repeated consecutive point, and `slot_positions` at least 1. Every coordinate, including `hero_start`, `pin_rect` and `pin_exclusion`, is finite and within −2,000 to 2,000, and `pin_rect`'s minimum is below its maximum. `pin_exclusion` is a list of shapes, each of two points, a radius above 0 and a hand (right, left or both), checked per shape, and a disc has both points equal. These are boot-fatal, since a zero-length segment would divide by 0; layout rules are the content test's (Enemy & Wave GDD).

**Tower levels and cost.** Levels are numbered from 1. `cost` at level N is the price of reaching N from N-1, so level 1's `cost` is the build price. The Tower GDD confirms this, with two levels and no selling at MVP.

**MVP tags.** A tower has exactly one role tag; enemy tags may be empty at MVP.

| Tag | Applies to | Requires on every level |
|---|---|---|
| `single_target` | Tower | none |
| `splash` | Tower | `splash_radius` |
| `slow` | Tower | `slow_strength`, `slow_duration` |

A role field without its tag is rejected, because dead data could still be targeted by a modifier.

**MVP stat keys.**

| Record | Int keys | Float keys |
|---|---|---|
| Tower | `cost` | `damage`, `range`, `attack_interval`, `splash_radius`, `slow_strength`, `slow_duration` |
| Enemy | `bounty`, `lives_cost` | `max_hp`, `move_speed` |
| Hero | none | `damage`, `attack_interval`, `leash_radius`, `walk_speed` |
| Burst | none | `damage`, `radius`, `reach`, `cooldown`, `telegraph_duration` |

Stage has no row: its fields are structural and read directly (Rule 10). Role keys apply only to a tower holding that role's tag: reading `splash_radius` on a `slow` tower is an inapplicable key.

**Stage visuals are not catalogue values.** Field hue, base value and grid tilt (`design/art/art-bible.md` §6) are presentation and live in the stage scene. Path points, slot positions and path width are on the Stage record, because they set time to leak and tower coverage (Rule 1), and the builder runs with no scene. MVP has one path per stage.

There is no separate economy record: gold values sit on the records that spend or earn them. Weapon, tree node and modifier records are reserved for Vertical Slice in prose only, with no empty fields or loaders now. Entity `tags` exist from MVP because modifiers will select their targets by tag ("nearby towers") and a source tag alone cannot express that.

**Rules.**

1. **All authored gameplay values live in the catalogue.** Each owning GDD's tunable values are catalogue fields, and changing a fixture value changes that consumer's behaviour (checked per consumer story). Engine constants and pure presentation timings are not gameplay values. Exempt, and owned where named: the tick `dt` (ADR-0004), hit radii and priorities (Input Rule 9), the hero's pin and aim offsets (Hero System), and presentation timings.
2. **Identity.** IDs are lowercase snake_case (validated), unique across all record types, and never encode stats or tree position. Display names may change; IDs never change and are never reused.
3. **References are by ID and typed.** A record refers to another record by its ID, never by file path (this covers record-to-record references; `scene_ref` is an asset reference, and the ADR may make it a `uid://`), and the reference must resolve to the expected record type (`burst_id` must name a Burst). Only owned sub-data (a tower's levels, a wave's groups) nests inside a record.
4. **Explicit manifest.** The catalogue loads from an explicit list of data files, never a runtime directory scan (exported builds rename and package files).
5. **Load once, all or nothing.** The whole catalogue loads before the first gameplay scene, triggered by the app root. Either every record is present and valid, or the game does not start. This covers records only; stage scene content is covered by Rule 9.
6. **Read-only after load.** No system writes to a definition. Mutable state (current HP, cooldown, target, current level) lives on the runtime instance, which holds `def_id`, and level for Towers. The engine does not enforce this, so it is a rule with a test (see Acceptance Criteria).
7. **Validate everything, collect all errors, then fail.** Every error has the structure `{code, source, record_id, field}`, where `source` is the file, or a label for code-built fixtures. Manifest and file errors stop before any record checks, since records from a broken manifest would only produce noise. A record type with no records is detected once every file is parsed and before any record is validated; it counts as a manifest-tier error and stops record checks the same way. **Precedence, so one fault gives one error:** a missing field gets no other check; a non-finite number gets no bounds check; an unknown tag suppresses that record's role checks and its role-tag count. Checks: ID format, duplicate IDs, dangling or wrong-type references, missing fields, unknown properties (a field no record type declares), unknown tags, a tower without exactly one role tag, role fields missing for or present without their tag, an empty `wave_ids`, `levels`, wave `groups`, `path_points` or `slot_positions` (`tags` may be empty), fractional integers, and every number finite (checked first) and inside the field-domain table. From Vertical Slice, modifier stat keys are checked against the vocabulary. There are two tiers and no warning tier, since a solo developer learns to ignore warnings: these boot-fatal invariants, and the CI content test for everything else (Rule 9). One cross-field check: the Input record's `tap_slop` must exceed `drag_slop`, reported on `tap_slop`. The resolver's `validate()` repeats it as a second line for hand-built fixtures.
8. **No fallbacks, in any build.** A silently defaulted value corrupts balance and the hero-share metric. A development run names every error by file, record and field. Content ships inside the build, with no mods or network, so the CI content test (Rule 9) and the exported-build check in Acceptance Criteria guard against shipping bad data; if it still happens, the player sees a generic fatal screen that uses no catalogue data, and saves are never opened.
9. **Scene content is checked by the content test, not at boot.** Checking scenes at load would mean instancing every stage. The CI content test opens each `scene_ref` and verifies the scene exists, and applies the Enemy & Wave GDD's layout and wave rules to the records. The same test enforces a non-empty `rationale` on every record and any balance range an owning GDD declares, such as Battle HUD's one-digit early-call bonus, which the `early_call_seconds_per_gold` floor alone does not bound. It runs locally by one command as well as in CI (named by ADR-0007), so a tuning edit can be checked before a push; the boot bounds catch broken simulation, and typos of a plausible size are the content test's to catch. Art-bible range and consecutive-stage checks join it at Vertical Slice. A stage scene that is still broken at runtime gives a fatal screen at stage start, naming the stage in a development run.
10. **One stat accessor.** Any number a modifier could target (damage, range, cost, bounty, leash radius) is read through one accessor taking a **read context** and a stat key, and returning the type the stat-key table declares for that key. The context always holds `def_id`; for a Tower it also holds the level, since Towers are the only MVP record with levels. A level passed for an Enemy, Hero or Burst is a bad call. The context holds the live entity when one exists; a HUD cost preview has none and passes `def_id` and level alone. At MVP the accessor returns the base value for that context. The system also exposes each tower's level count as a non-fatal `level_count(def_id)`, so callers never ask past the maximum, and a non-fatal `is_tower(id)`, so a command can refuse a bad ID rather than reach the handler. The context allows a live entity, not just a definition, because the first cross-buff ("towers near the hero") depends on instance and position; a definition-only form would mean rewriting every call site at Vertical Slice. Callers read at use time and never cache at spawn: when a spy accessor changes its value between uses, the consumer's next use reflects it (checked in the Tower, Hero and HUD stories). Structural data (a wave's groups) and every Stage field (`scene_ref`, `wave_ids`, `starting_gold`, `starting_lives`, `early_call_seconds_per_gold`, `path_points`, `slot_positions`, `path_width`, `requires_bend`, `hero_start`, `pin_rect`, `pin_exclusion`) are read directly, not through the accessor: Stage has no stat-key row. A modifier that targets a stage start value ("+50 starting gold") is a Stat GDD question and would add a Stage row then. A bad call (unknown key, key inapplicable to that record, out-of-range or unexpected level, unresolved `def_id`) calls an injected failure handler, naming the cause. **The handler is the contract:** in the game it reaches the fatal screen, and tests replace it. The value returned after a bad call is unspecified and no caller may use it, since typed GDScript cannot express "this returns a number or nothing". The check must survive release builds (mechanism in the ADR; the pinned engine reference does not cover assert behaviour).
11. **Stat-key vocabulary.** This system owns the list of valid stat keys (the table above). An unknown key fails at the accessor (Rule 10) and, from Vertical Slice, in modifier validation.
12. **Injection, not a global.** The app root (Game State & Stage Flow) holds the Ready catalogue across retries, and the battle builder hands it to consumers. Tests build small fixture catalogues in code with no file I/O; a separate integration suite validates the real data files.
13. **Tuning loop.** Edit a value, save, run: the new value is in the game within 10 seconds (proposed), with no code touched. Changes apply on the next run; there is no live reload.

**Not owned.** Event contracts (`enemy_killed`, `enemy_leaked`, `waves_complete`), DamageEvent, gold and lives state, modifier resolution, save schemas, and the justification of balance values. This system stores data and has no behaviour to emit signals from. Each emitter declares its own signals and the composition root wires them. Combat's DamageEvent and future modifiers must use two different field names for "who dealt this" and "who granted this" rather than overloading `source`.

**Deliberately not built for MVP.** Spreadsheet or JSON import pipelines, an autoload database, hot reload, schema versioning, inheritance between records, remote config, custom editor tools. Prototype constants are starter fixtures only: they were fitted to a bot and are not balance values (CD-PLAYTEST).

No Formulas section: this system stores values and defines no tunable numeric rule; the validation bounds above are invariants, and owning GDDs define the rules.

→ Becomes an ADR: storage format (recommended: typed Godot Resources, JSON as fallback if downloadable content or modding is ever wanted, since Resources can carry scripts), read-only enforcement, accessor signature and key format, file locations. **The ADR must choose a format that can detect a missing field, a fractional integer and an unknown property.** Typed resources may silently supply a default for a missing field, which would make Rule 8 meaningless, so if the format cannot detect these itself, the ADR must add a check that does. This GDD assumes only typed records keyed by stable ID behind one read-only lookup. Export behaviour is unverified until a real Android export runs.

### States and Transitions

| State | Meaning | Exits |
|---|---|---|
| Unloaded | Before the first gameplay scene | Loading |
| Loading | Reading every manifest file and validating | Ready (no errors) · Failed (any error) |
| Ready | Read-only; serves all lookups for the rest of the session | none |
| Failed | Every error reported; no gameplay scene starts; saves untouched | none (restart after fixing data) |

There is no reload transition: a data change applies on the next run.

### Interactions with Other Systems

| System | Reads | Interface owner |
|---|---|---|
| Game State & Stage Flow | Stage records; app root triggers load and holds the catalogue; builder injects it | This system (load, lookup); Game State (injection) |
| Combat & Damage | Nothing: callers read values and pass them in, and `max_hp` seeds Health once at spawn, the one exception to Rule 10's "never cache" | Combat GDD |
| Enemy & Wave | Enemy, Wave, Stage | This system |
| Tower System | Tower levels through the accessor | This system |
| Hero System | Hero and Burst through the accessor | This system |
| Input & Gesture Resolver | The Input record, read directly | This system; Input GDD owns its meaning |
| Battle HUD | Costs for the cost chip, and Burst `cooldown` for the wedge, through the accessor | This system |
| Stat & Modifier Resolution (VS) | Drops in behind the accessor with no call-site changes | Stat GDD owns the resolver; this system owns the key vocabulary |
| Save/Load (VS) | Stable IDs; retired-ID list from Vertical Slice | Save/Load owns migration |

## Edge Cases

"Fail" means a collected validation error naming file, record and field, then the Failed state.

**MVP**
- **If the manifest is empty or a record type has no records**: Fail. Serves no lookup.
- **If a manifest path repeats or a file is empty**: Fail with one manifest error, and no record checks run.
- **If an ID appears in two record types**: Fail, naming both records.
- **If a reference resolves to the wrong type (`burst_id` names an enemy)**: Fail.
- **If a wave references an enemy that no longer exists**: Fail as dangling. MVP has no retired state.
- **If a group's `count` is below 1**: Fail. It is never skipped.
- **If `start_delay` is negative**: Fail. Unordered or overlapping groups are legal; delays count from wave start.
- **If `wave_ids` is empty**: Fail. Repeated wave IDs are legal.
- **If `path_points` has fewer than 2 points or repeats a consecutive point, or `slot_positions` is empty**: Fail.
- **If a tower has zero levels**: Fail. Any count above zero passes here; the Tower GDD's content test enforces how many levels a tower must have.
- **If a tag is unknown**: Fail with one error for that tag, and skip that record's role checks.
- **If a role field its known tag implies is missing on any level**: Fail.
- **If an integer field is fractional**: Fail.
- **If a record carries a property no record type declares**: Fail, naming the property as `field`. A typo in a field name is otherwise a silently missing field.
- **If a number is NaN or infinite**: Fail, checked before bounds, since infinity passes "above 0".
- **If `starting_lives` is below 1**: Fail.
- **If the accessor gets an unknown key, a key inapplicable to that record, an out-of-range or unexpected level or an unresolved `def_id`**: the failure handler is called with the cause and, in the game, reaches the fatal screen. The return value is unspecified and unused.
- **If a caller mutates a definition**: nothing blocks it at runtime; the read-only test fails by comparing a catalogue snapshot after a battle, including directly read wave groups.
- **If device load fails after a green CI run**: generic fatal screen using no catalogue data; saves stay unopened.
- **If a stage scene is broken at runtime despite the content test**: fatal screen at stage start; the catalogue stays Ready.

**Vertical Slice**
- **If a reference targets a retired ID, or a retired ID is live in the data**: Fail.
- **If spawn references form a cycle, including an enemy spawning itself**: Fail, printing the cycle.
- **If data changed while a save exists**: new values apply, because saves hold only IDs and levels. Retired IDs and levels above the new maximum go to Save/Load migration.
- **If a modifier uses a key outside the vocabulary**: Fail.

## Dependencies

**Upstream:** none. This is a Foundation system. It relies only on the engine's file access.

**Downstream (hard unless noted; the MVP systems have GDDs, and the Vertical Slice ones stay provisional until written):**

| System | Data interface |
|---|---|
| Game State & Stage Flow | Triggers load; reads Stage; injects the catalogue |
| Combat & Damage | None directly; callers pass values in |
| Enemy & Wave | Enemy, Wave, Stage records |
| Tower System | Tower levels via the accessor |
| Hero System | Hero and Burst via the accessor |
| Input & Gesture Resolver | The Input record |
| Battle HUD & Build UI | Costs and Burst `cooldown` via the accessor |
| Stat & Modifier Resolution (VS) | Key vocabulary; replaces the accessor's internals |
| Skill Tree, Hero Weapons, Synergies (VS) | New record types reserved in Core Rules |
| Save/Load (VS) | Stable IDs and retired-ID list |

Per the bidirectional rule, each of these must list this one. The MVP GDDs that read data do, and the Vertical Slice ones must when authored.

## Visual/Audio Requirements

Not applicable: this system has no visual or audio output. The fatal screen's appearance belongs to Game State & Stage Flow. Records carry `visual_key` only as an identifier; `design/art/art-bible.md` owns what it means.

## Game Feel

Not applicable: players never operate this system.

## UI Requirements

None beyond the generic fatal screen, owned by Game State & Stage Flow. This system supplies values to the HUD and owns no screen.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Accessor takes instance context | `design/gdd/game-concept.md` | Core Mechanic 4, first cross-buff at Vertical Slice | Rule dependency |
| Stable IDs | `design/gdd/game-concept.md` | Save versioning, Technical Considerations | Rule dependency |
| Prototype values are not balance | `prototypes/hero-pin-concept/REPORT.md` | CD-PLAYTEST carry-forward 5 | Ownership handoff |
| Composition root, injection | `design/gdd/systems-index.md` | TD notes, Dependency Map | Rule dependency |
| `visual_key` meaning | `design/art/art-bible.md` | §3, §8 | Ownership handoff |
| Load, injection, fatal screen | `design/gdd/game-state-stage-flow.md` | Rules 1, 2, 18 | Rule dependency |
| Input record's meaning and `validate()` | `design/gdd/input-gesture-resolver.md` | Rule 9; Formulas | Ownership handoff |
| Stage geometry, wave fields, layout and wave rules | `design/gdd/enemy-wave.md` | Rules 2, 3; Layout and wave rules | Amended there |
| Tower levels, `early_call_seconds_per_gold` | `design/gdd/tower-system.md` | Rules 2, 16 | Amended there |
| Hero and Burst fields, `pin_exclusion`, hand | `design/gdd/hero-system.md` | Rule 2; Starter values | Amended there |
| Accessor reads for costs and `cooldown` | `design/gdd/battle-hud.md` | Rules 7, 12 | Rule dependency |

## Acceptance Criteria

Logic criteria use code-built fixtures with no file I/O. All CI criteria use fixed fixtures, no random seeds, explicit ticks and no time assertions; timed criteria are manual only. There is no Formulas section, so criteria come from Core Rules and Edge Cases.

**CI: Logic**
1. (Rules 2, 3) **GIVEN** fixtures with a cross-type duplicate ID, a dangling reference and a `burst_id` naming an enemy, **WHEN** validated, **THEN** the state is Failed and each error is a `{code, source, record_id, field}` value: a duplicate ID gives one error per colliding record, so a two-way collision gives two, and the dangling and wrong-type references give one each. Fixtures supply a label as `source`.
2. (Rule 7) **GIVEN** table-driven fixtures (missing field, unknown property, unknown tag, role field missing on one level, role field without its tag, tower with no role tag, ID not in snake_case, empty `wave_ids` or `levels`, a path of one point or with a repeated consecutive point, fractional integer), **WHEN** validated, **THEN** each yields exactly its one expected `{code, record_id, field}`, including a single error for an unknown tag on a tower with no other tag, and for an unknown tag on a tower carrying `splash_radius`. Each fixture breaks one thing only: the missing field is numeric and gives no domain error, the fractional integer is `cost` 10.5, and the badly formed ID is unique. An enemy with empty `tags` passes.
3. (Rule 7) **GIVEN** boundary values, **WHEN** validated, **THEN** an interval below 1/30 s, `max_hp` 0, cost -1, `start_delay` -1, `count` 0, `starting_lives` 0, `slow_strength` 0, 1 and 1.01 and any value above its ceiling fail; NaN and infinity each report exactly one error, non-finite, and no bounds error; cost 0, `lives_cost` 0, delay 0, `slow_strength` 0.5, values exactly at an inclusive floor or ceiling, repeated wave IDs and overlapping groups pass. **GIVEN** an Input record with `drag_slop` 20 and `tap_slop` 20, **THEN** exactly one error, the cross-field one on `tap_slop`, since both values are inside their domains; `tap_slop` 21 passes.
4. (Rule 7) **GIVEN** a fixture seeded with 5 unrelated errors, **WHEN** validated once, **THEN** the reported set equals those 5 `{code, source, record_id, field}` values, in any order.
5. (Rule 5) **GIVEN** an empty manifest, a type with no records, a repeated path or an empty file, each alongside an otherwise invalid record, **WHEN** loaded, **THEN** there is one manifest or file error, no record error is reported, the state is Failed and no lookup is served. **GIVEN** a valid fixture, **THEN** the state is Ready.
6. (Rule 10) **GIVEN** a valid fixture whose values differ per level and per record, **WHEN** every key applicable to each record is read (towers: for each level, role keys only with that role's tag), with a live entity and with a preview context, **THEN** the base value of the declared type is returned, and each tower's exposed level count matches its record. `level_count` and `is_tower` on an unknown ID return 0 and false without calling the failure handler.
7. (Rules 10, 11) **GIVEN** a spy failure handler injected into the accessor, **WHEN** called with an unknown key, an inapplicable key (including a role key on a tower without that role), an out-of-range level, a level on a record without levels or an unresolved `def_id`, **THEN** the spy fires once naming that cause. The return value is not asserted.
8. (Rule 12) **GIVEN** two code-built fixtures with different values, **WHEN** read side by side, **THEN** each returns its own values with no file I/O.

**CI: Integration**
9. (Rules 4, 7) **GIVEN** the real manifest plus a valid data file not listed in it, **WHEN** loaded, **THEN** there are zero errors, every listed record is present, and the unlisted record is absent. This proves manifest logic only, not export behaviour.
10. (Rule 9) **GIVEN** every Stage record, **WHEN** the content test opens each `scene_ref`, **THEN** each exists; a broken fixture scene fails, naming its stage.
11. (Rule 6, detector self-test) **GIVEN** a deep catalogue snapshot including wave groups, **WHEN** a test deliberately changes a nested fixture value, **THEN** the comparison reports that field; with no change it reports none.
12. (Rules 8, 10) **GIVEN** an injected handler, **WHEN** a bad accessor call occurs, **THEN** the handler is invoked and the catalogue stays Ready. The fatal screen itself is owned by Game State (see deferred criteria).

**Manual**
13. (Rule 8, first phone build) **GIVEN** an exported release build with one invalid record, **WHEN** launched, **THEN** the generic fatal screen shows and the save file is unchanged; a bad accessor call also reaches it (no stripped assert). Retained screenshot in `production/qa/evidence/`.
14. (Rule 13, advisory) **GIVEN** the editor, **WHEN** one value is edited and the game run, **THEN** `git diff` shows only a data file changed and the new value is logged on the next run's first frame; time noted against the proposed 10 s.
15. (First phone build, advisory) **GIVEN** one named Adreno 5xx-class device, **WHEN** launched cold 5 times, **THEN** the median from Loading to Ready is at most 1000 ms (proposed), logged. Not measurable until a device build exists.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner |
|---|---|
| Rule 6 end to end: catalogue unchanged after a scripted fixed-tick battle in which at least one enemy spawned and died | Tower and Enemy & Wave stories |
| Rule 10 never-cache: a spy accessor changes its value between two uses and the second use reflects it | Each consumer story (Tower, Hero, HUD) |
| Rule 1: changing a fixture value changes the consumer's behaviour | Each consumer story |
| Fatal screen shows on a broken stage scene or bad accessor call | Game State & Stage Flow |
| Android export loads the catalogue (no path or packing assumption) | Storage-format ADR, Technical Setup |

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Storage format and read-only enforcement (recommended: typed Resources), confirmed by a real Android export | technical-director, `/architecture-decision` | Technical Setup gate |
| Locomotion, armour and resist, splitter spawn reference, `introduces`. Answered for MVP by the Enemy & Wave GDD: none are needed yet | Vertical Slice GDDs | Vertical Slice |
| Preview data: `attack_type`, `display_name`, stage order | Stage Progression GDD | Vertical Slice |
| Snapshot mechanics, integer representation | technical-director | Storage-format ADR |
| Optional tooling, unscheduled: headless validate-only command (reuse the content test first), alternate manifest, DPS dump | producer | When tuning hurts |
| The accessor returns numbers only: how does a tree node that visibly changes something (Pillar 1's "shots chain") reach the game? | Stat GDD | Stat GDD |
| Both thresholds (10 s tuning loop, 1 s device load) are proposals; `project.yaml` has no load budget | producer + performance-analyst | First phone build |
| Scene checks run on the project, not the export, because the test runner cannot run on an exported build: is the manual check enough? | technical-director | Storage-format ADR |
| `tests/README.md` is stale: it says clones lack the class cache (now tracked) and that gdUnit4 is uninstalled (now in `addons/`) | gameplay-programmer | First test story |
