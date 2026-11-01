# Data & Config Pipeline

> **Status**: Designed (pending independent review)
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-01
> **Last Verified**: 2026-11-01
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-01 — CONCERNS applied (`visual_key` on Enemy and Hero, art bible mapping, Open Questions widened)
> **Implements Pillar**: Enabling system for all four pillars (Pillar 1 and 3 most directly: growth and stage variety are data)

## Summary

The read-only catalogue of every authored gameplay value: towers, enemies, waves, stages, the hero and its burst, each with a stable ID. Players never see it, but it is why a tower can be retuned or a stage added without touching code, and why bad data stops the game loudly instead of silently corrupting balance. It loads once, validates everything, and serves all stat reads through one accessor so skill-tree modifiers can slot in later with no call-site changes.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

The Data & Config Pipeline is the read-only catalogue of every authored gameplay value in TowerRiot: what each tower costs and does at each level, how tough and how rewarding each enemy is, what each wave sends, what each stage starts with, and how the hero and its burst behave. Players never interact with it directly. They feel what it enables: because no gameplay number lives in code, a tower can be retuned, a wave reshaped or a new stage added by editing data and running the game, which is what makes 20 distinct stages (Pillar 3) and visible growth (Pillar 1) affordable for one developer. It also gives every other system one honest source of truth, so the hero's damage share (Pillar 2) measures the design and not a stray constant. Without it, tuning means editing code and every balance pass risks a regression.

## Detailed Design

### Core Rules

**Catalogue contents (MVP).** Every record has a stable `id` and a `rationale` (one line saying where the numbers came from, meeting the "balance values link to their source" standard).

| Record | Fields |
|---|---|
| Tower | `tags`; `levels[]`, each with absolute values (never deltas): `cost`, `damage`, `range`, `attack_interval`, `visual_key`, and role fields where relevant (`splash_radius`, `slow_strength`, `slow_duration`) |
| Enemy | `max_hp`, `move_speed`, `bounty`, `lives_cost`, `visual_key`, `tags` |
| Wave | `groups[]`, each with `enemy_id`, `count`, `spawn_interval`, `start_delay` |
| Stage | `scene_ref`, `wave_ids[]`, `starting_gold`, `starting_lives` |
| Hero | `damage`, `attack_interval`, `leash_radius`, `burst_id`, `visual_key` |
| Burst | `damage`, `radius`, `cooldown`, `telegraph_duration` |

There is no separate economy record: gold values sit on the records that spend or earn them. Weapon, tree node and modifier records are reserved for Vertical Slice in prose only, with no empty fields or loaders now. Entity `tags` exist from MVP because modifiers will select their targets by tag ("nearby towers") and a source tag alone cannot express that.

**Rules.**

1. **All authored gameplay values live in the catalogue.** Each owning GDD's tunable values are catalogue fields, and changing a fixture value changes that consumer's behaviour (checked per consumer story). Engine constants and pure presentation timings are not gameplay values.
2. **Identity.** IDs are lowercase snake_case, unique across all record types, and never encode stats or tree position. Display names may change; IDs never change and are never reused.
3. **References are by ID and typed.** A record refers to another record by its ID, never by file path, and the reference must resolve to the expected record type (`burst_id` must name a Burst). Only owned sub-data (a tower's levels, a wave's groups) nests inside a record.
4. **Explicit manifest.** The catalogue loads from an explicit list of data files, never a runtime directory scan (exported builds rename and package files).
5. **Load once, all or nothing.** The whole catalogue loads before the first scene. Either every record is present and valid, or the game does not start. This covers records only; stage scene content is covered by Rule 9.
6. **Read-only after load.** No system writes to a definition. Mutable state (current HP, cooldown, target, current level) lives on the runtime instance, which holds `def_id` and level. The engine does not enforce this, so it is a rule with a test (see Acceptance Criteria).
7. **Validate everything, collect all errors, then fail.** Checks: duplicate IDs, dangling or wrong-type references, missing fields, unknown tags, role fields a tag implies, empty lists, fractional integers, and hard invariants only: every number finite (checked first), intervals and speeds above 0, `max_hp` above 0, costs and `start_delay` at or above 0, `count` and `starting_lives` at least 1, `slow_strength` from 0 to 1. Balance ranges belong to the owning GDDs, not here. From Vertical Slice, modifier stat keys are checked against the vocabulary.
8. **No fallbacks, in any build.** A silently defaulted value corrupts balance and the hero-share metric. A development run names every error by file, record and field. Content ships inside the build, with no mods or network, so the CI content test (Rule 9) and the exported-build check in Acceptance Criteria guard against shipping bad data; if it still happens, the player sees a generic fatal screen that uses no catalogue data, and saves are never opened.
9. **Scene content is checked by the content test, not at boot.** A stage's path and slots live in its scene; checking them at load would mean instancing every stage. The CI content test opens each `scene_ref` and verifies the scene exists and has a path and build slots (slot counts per stage belong to Enemy & Wave). A stage scene that is still broken at runtime gives a fatal screen at stage start, naming the stage in a development run.
10. **One stat accessor.** Any number a modifier could target (damage, range, cost, bounty, leash radius) is read through one accessor taking the **runtime instance context** and a stat key, and returning a number. At MVP it returns the base value for that `def_id` and level. It takes the instance, not just the definition, because the first cross-buff ("towers near the hero") depends on instance and position; a definition-only form would mean rewriting every call site at Vertical Slice. Callers read at use time and never cache at spawn: when a spy accessor changes its value between uses, the consumer's next use reflects it (checked in the Tower, Hero and HUD stories). Structural data (a wave's groups) is read directly. A bad call (unknown key, key inapplicable to that record, out-of-range level, unresolved `def_id`) never returns a number: it logs and goes to the fatal screen, using a check that survives release builds, since engine asserts are stripped there.
11. **Stat-key vocabulary.** This system owns the list of valid stat keys. An unknown key fails at the accessor (Rule 10) and, from Vertical Slice, in modifier validation.
12. **Injection, not a global.** The catalogue is handed to consumers by the battle composition root (Game State & Stage Flow). Tests build small fixture catalogues in code with no file I/O; a separate integration suite validates the real data files.
13. **Tuning loop.** Edit a value, save, run: the new value is in the game within 10 seconds (proposed), with no code touched. Changes apply on the next run; there is no live reload.

**Not owned.** Event contracts (`enemy_killed`, `enemy_leaked`, `waves_complete`), DamageEvent, gold and lives state, modifier resolution, save schemas, and the justification of balance values. This system stores data and has no behaviour to emit signals from. Each emitter declares its own signals and the composition root wires them. Combat's DamageEvent and future modifiers must use two different field names for "who dealt this" and "who granted this" rather than overloading `source`.

**Deliberately not built for MVP.** Spreadsheet or JSON import pipelines, an autoload database, hot reload, schema versioning, inheritance between records, remote config, custom editor tools. Prototype constants are starter fixtures only: they were fitted to a bot and are not balance values (CD-PLAYTEST).

No Formulas section: this system stores values and defines no tunable numeric rule; the validation bounds above are invariants, and owning GDDs define the rules.

→ Becomes an ADR: storage format (recommended: typed Godot Resources, JSON as fallback if downloadable content or modding is ever wanted, since Resources can carry scripts), read-only enforcement, accessor signature and key format, file locations. This GDD assumes only typed records keyed by stable ID behind one read-only lookup. Export behaviour is unverified until a real Android export runs.

### States and Transitions

| State | Meaning | Exits |
|---|---|---|
| Unloaded | Before the first scene | Loading |
| Loading | Reading every manifest file and validating | Ready (no errors) · Failed (any error) |
| Ready | Read-only; serves all lookups for the rest of the session | none |
| Failed | Every error reported; no gameplay scene starts; saves untouched | none (restart after fixing data) |

There is no reload transition: a data change applies on the next run.

### Interactions with Other Systems

| System | Reads | Interface owner |
|---|---|---|
| Game State & Stage Flow | Stage records; triggers load before the first scene; injects the catalogue | This system (load, lookup); Game State (injection) |
| Combat & Damage | Slow and splash values come via the tower record; damage arrives on DamageEvent, so its direct reads are narrow | This system |
| Enemy & Wave | Enemy, Wave, Stage | This system |
| Tower System | Tower levels through the accessor | This system |
| Hero System | Hero and Burst through the accessor | This system |
| Input & Gesture Resolver | Input thresholds (drag slop) as data | This system; provisional, Input GDD confirms |
| Battle HUD | Costs for the cost chip through the accessor | This system |
| Stat & Modifier Resolution (VS) | Drops in behind the accessor with no call-site changes | Stat GDD owns the resolver; this system owns the key vocabulary |
| Save/Load (VS) | Stable IDs; retired-ID list from Vertical Slice | Save/Load owns migration |

## Edge Cases

"Fail" means a collected validation error naming file, record and field, then the Failed state.

**MVP**
- **If the manifest is empty or a record type has no records**: Fail.
- **If a manifest path repeats or a file is empty**: Fail with one manifest error, not one per duplicated record.
- **If an ID appears in two record types**: Fail, naming both records.
- **If a reference resolves to the wrong type (`burst_id` names an enemy)**: Fail.
- **If a wave references an enemy that no longer exists**: Fail as dangling. MVP has no retired state.
- **If a group's `count` is below 1**: Fail. It is never skipped.
- **If `start_delay` is negative**: Fail. Unordered or overlapping groups are legal; delays count from wave start.
- **If `wave_ids` is empty**: Fail. Repeated wave IDs are legal.
- **If a tower has zero levels**: Fail. Any count above zero passes here; the Tower GDD's content test enforces how many levels a tower must have.
- **If a tag is unknown, or a role field its tag implies is missing on any level**: Fail. A mistyped tag would otherwise skip the role check.
- **If an integer field is fractional**: Fail.
- **If a number is NaN or infinite**: Fail, checked before bounds, since infinity passes "above 0".
- **If `starting_lives` is below 1**: Fail.
- **If the accessor gets an unknown key, a key inapplicable to that record, an out-of-range level or an unresolved `def_id`**: log, then fatal screen. No number is returned.
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

**Downstream (hard unless noted; none has a GDD yet, so every interface is provisional until that GDD confirms it):**

| System | Data interface |
|---|---|
| Game State & Stage Flow | Triggers load; reads Stage; injects the catalogue |
| Combat & Damage | Narrow: role values via tower records |
| Enemy & Wave | Enemy, Wave, Stage records |
| Tower System | Tower levels via the accessor |
| Hero System | Hero and Burst via the accessor |
| Input & Gesture Resolver | Input thresholds (soft: defaults cannot exist, so the record is required once Input confirms it) |
| Battle HUD & Build UI | Costs via the accessor |
| Stat & Modifier Resolution (VS) | Key vocabulary; replaces the accessor's internals |
| Skill Tree, Hero Weapons, Synergies (VS) | New record types reserved in Core Rules |
| Save/Load (VS) | Stable IDs and retired-ID list |

Per the bidirectional rule, each of these GDDs must list this one when authored.

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

## Acceptance Criteria

Logic criteria use code-built fixtures with no file I/O. All CI criteria use fixed fixtures, no random seeds, explicit ticks and no time assertions; timed criteria are manual only. There is no Formulas section, so criteria come from Core Rules and Edge Cases.

**CI: Logic**
1. (Rules 2, 3) **GIVEN** fixtures with a cross-type duplicate ID, a dangling reference and a `burst_id` naming an enemy, **WHEN** validated, **THEN** the state is Failed and each error names file, record and field (both records for duplicates).
2. (Rule 7) **GIVEN** table-driven fixtures (missing field, unknown tag, role field missing on one level, empty `wave_ids` or `levels`, fractional integer), **WHEN** validated, **THEN** each yields exactly its one expected error.
3. (Rule 7) **GIVEN** boundary values, **WHEN** validated, **THEN** interval 0, `max_hp` 0, cost -1, `start_delay` -1, `count` 0, lives 0 and slow 1.01 fail; NaN and infinity report non-finite, not bounds; cost 0, delay 0, slow 0 and 1, repeated wave IDs and overlapping groups pass.
4. (Rule 7) **GIVEN** a fixture seeded with 5 unrelated errors, **WHEN** validated once, **THEN** exactly those 5 are reported.
5. (Rule 5) **GIVEN** an empty manifest, a type with no records, or a repeated path, **WHEN** loaded, **THEN** there is one manifest error, the state is Failed and no lookup is served. **GIVEN** a valid fixture, **THEN** the state is Ready.
6. (Rule 10) **GIVEN** a valid fixture, **WHEN** each key is read per instance and level, **THEN** the base value is returned.
7. (Rules 10, 11) **GIVEN** a spy failure handler injected into the accessor, **WHEN** called with an unknown key, an inapplicable key, an out-of-range level or an unresolved `def_id`, **THEN** the spy fires once naming the cause and the return is not a number.
8. (Rule 12) **GIVEN** two code-built fixtures with different values, **WHEN** read side by side, **THEN** each returns its own values with no file I/O.

**CI: Integration**
9. (Rules 4, 7) **GIVEN** the real manifest plus a valid data file not listed in it, **WHEN** loaded, **THEN** there are zero errors and the unlisted record is absent.
10. (Rule 9) **GIVEN** every Stage record, **WHEN** the content test opens each `scene_ref`, **THEN** each exists with a path and at least one slot; a broken fixture scene fails, naming its stage.
11. (Rule 6) **GIVEN** a deep catalogue snapshot including wave groups, **WHEN** a scripted fixed-tick battle ends, **THEN** the catalogue equals the snapshot. *Cannot pass until Tower and Enemy exist.*
12. (Rules 8, 9) **GIVEN** the real failure handler, **WHEN** a stage scene fails at start or a bad accessor call occurs, **THEN** the fatal screen shows and the catalogue stays Ready.

**Manual**
13. (Rule 8, first phone build) **GIVEN** an exported release build with one invalid record, **WHEN** launched, **THEN** the generic fatal screen shows and the save file is unchanged; a bad accessor call also reaches it (no stripped assert). Retained screenshot in `production/qa/evidence/`.
14. (Rule 13, desktop) **GIVEN** a running editor, **WHEN** one value is edited, saved and run, **THEN** it appears in game within 10 s with no code touched; stopwatch time logged.
15. (First phone build) **GIVEN** an Adreno 5xx-class device, **WHEN** launched cold, **THEN** Loading to Ready takes at most 1 s (proposed). **Not measurable until a device build exists.**

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Storage format and read-only enforcement (recommended: typed Resources), confirmed by a real Android export | technical-director, `/architecture-decision` | Technical Setup gate |
| Does slow go through the accessor, or is it a second modifier path? | Combat GDD + Stat GDD | Combat GDD |
| Can the hero die? No hero HP field exists until this is decided | Hero GDD | Hero GDD |
| Which enemy types are in MVP, and what fields do the others need? Armoured, flying, lane-switching and tower-resistant enemies have no field yet beyond `tags`, and Pillar 2's Vertical Slice wave rule needs tower resistance. Splitters would need a spawn reference and cycle check | Enemy & Wave GDD | Enemy & Wave GDD |
| The accessor returns numbers only: how does a tree node that visibly changes something (Pillar 1's "shots chain") reach the game? | Stat GDD | Stat GDD |
| Which input thresholds are data? | Input GDD | Input GDD |
| How many levels must a tower have? (Concept MVP: 2. Art bible: 3) | Tower GDD | Tower GDD |
| Both thresholds (10 s tuning loop, 1 s device load) are proposals; `project.yaml` has no load budget | producer + performance-analyst | First phone build |
| Scene checks run on the project, not the export, because the test runner cannot run on an exported build: is the manual check enough? | technical-director | Storage-format ADR |
| `tests/README.md` is stale: it says clones lack the class cache (now tracked) and that gdUnit4 is uninstalled (now in `addons/`) | gameplay-programmer | First test story |
