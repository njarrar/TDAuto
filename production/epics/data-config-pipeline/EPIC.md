# Epic: Data & Config Pipeline

> **Layer**: Foundation
> **GDD**: design/gdd/data-config-pipeline.md
> **Architecture Module**: Catalogue, Validator, StatAccessor
> **Status**: Ready
> **Stories**: Not yet created. Run `/create-stories data-config-pipeline`

## Overview

This epic builds the read-only catalogue of every authored gameplay value: towers, enemies, waves, stages, the hero and its burst, and the Input and Options records. No gameplay number lives in code, so a tower can be retuned or a stage added by editing data and running the game (GDD Overview, Pillars 1 and 3).

ADR-0001 fixes the shape. The data lives in JSON files listed in one `manifest.json` under `res://data/catalogue/`. A schema table in code checks every file and collects every error as `{code, source, record_id, field}` before the game refuses to start. The check catches a missing field, a fractional integer and an unknown property, which the GDD requires and which engine Resource defaults could not be trusted to show. Valid data becomes typed read-only `RefCounted` records (`TowerDef`, `StageDef` and the rest) with no setters, served through one `Catalogue` and one `StatAccessor`. A bad read calls an injected failure handler and returns a typed zero no caller may use. Tests build catalogues in code through `Catalogue.from_data`, with no file I/O. There is no autoload: the app root holds the catalogue and the battle builder injects it (ADR-0002, ADR-0008).

**First story: a desktop export spike.** Build an export and read the manifest's JSON from the PCK. This retires the main engine risk (ADR-0001 V1, JSON packing) early. iOS and Android packing stay a device check at the milestone gate.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: Catalogue Storage Format and Stat Accessor | JSON from one manifest, code schema, typed read-only records, one injected stat accessor | HIGH |
| ADR-0002: Signal Contracts and Wiring Conventions | Data emits no signals; record and read names in the canonical table | MEDIUM |
| ADR-0004: Headless Battle Harness and Snapshot | Fixture catalogues through `Catalogue.from_data`; `Catalogue.snapshot()` for the read-only test | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-data-001 | Catalogue of typed records (Tower, Enemy, Wave, Stage, Hero, Burst, Input, Options), each with a stable lowercase snake_case ID and a non-empty rationale | ADR-0001 ✅ |
| TR-data-002 | Load once from an explicit file manifest (no directory scan); either every record is valid or the game does not start | ADR-0001 ✅ |
| TR-data-003 | Validate all fields against domain tables and collect every error as `{code, source, record_id, field}`; no fallbacks in any build | ADR-0001 ✅ |
| TR-data-004 | The format must detect a missing field, a fractional integer and an unknown property, or an added check must | ADR-0001 ✅ |
| TR-data-005 | Definitions are read-only after load; mutable state lives on runtime instances holding `def_id` (and level for towers) | ADR-0001 ✅ |
| TR-data-006 | One stat accessor `(read context, key)` returning the declared type; the base value at MVP, with modifiers slotting in later at no call-site change | ADR-0001 ✅ |
| TR-data-007 | Catalogue is injected by the app root and builder; no autoload; tests build fixture catalogues in code | ADR-0001 ✅ |
| TR-data-008 | Catalogue loads from an Android and iOS export with no path or packing assumption; edit-to-run in about 10 s on desktop; stage geometry has a defined storage form | ADR-0001 ✅ (device packing deferred to the milestone gate) |

Coverage: 8 of 8 by an Accepted ADR, per the architecture Baseline. Untraced in the TR registry: all 8, because the registry is empty (see Known Gaps).

## Known Gaps (recorded 2026-11-03, user decision)

- **TR registry empty.** `docs/architecture/tr-registry.yaml` has no entries yet. The TR-IDs below come from the architecture's Technical Requirements Baseline (provisional). Run `/architecture-review` in a fresh session before `/create-stories`, so stories can embed registered TR-IDs.
- **GDD not Approved.** The GDD is In Review. Do not write stories against sections still being revised.
- **One developer.** `team.size` resolves to studio, but the team is one person: size stories for one developer.
- **No milestones** are recorded, so this epic is not checked against a deadline.

## Deferred to the Milestone Gate (not epic-close criteria)

- Data GDD criterion 13 (release build on a phone with one invalid record shows the fatal screen) and criterion 15 (median device load time): need a phone.
- ADR-0001 V1 on iOS and Android: JSON packed and read in a device export.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/data-config-pipeline.md verified, except criteria deferred to the milestone gate below
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
