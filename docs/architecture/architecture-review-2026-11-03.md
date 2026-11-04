## Architecture Review Report
Date: 2026-11-03
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
GDDs Reviewed: 8 (systems index and game concept read for context, no requirements drawn from them)
ADRs Reviewed: 0

Reviewed-Content-Hash: design/gdd/battle-hud.md 5ff2bdf88fd457f664e6a0e6602cc491fed05edc
Reviewed-Content-Hash: design/gdd/combat-damage.md 40ae59c616520d9cd4b3a5eea61c1ec824b8c0d8
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 9ab10a8976932d538c3e9eced0c9ccd235555840
Reviewed-Content-Hash: design/gdd/enemy-wave.md fd59ea144735b2cdf0453d2d8d7cce31895dd0cc
Reviewed-Content-Hash: design/gdd/game-concept.md 69276bc59133ed1fc4125a561b829e3bd7eb4156
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md bf732dff9591608ebee0b1d8d7127d51c3c9cd2b
Reviewed-Content-Hash: design/gdd/hero-system.md 6c42e0f35c803d364a8156eb02ebd5a781b47949
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/systems-index.md 267a05ea8643d76efe6e22c5b410bffe9dd68186
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml abda3911f8654bd06edcb263738e97f8fcd21772
Reviewed-Content-Hash: docs/engine-reference/godot/VERSION.md fcf85779788e0facbeca26aeda9fd41955e2633e
Reviewed-Content-Hash: docs/engine-reference/godot/breaking-changes.md 4bc55e16796664ff88c7582c9f08e3530f7c94d4
Reviewed-Content-Hash: docs/engine-reference/godot/current-best-practices.md a45cd2c39a8ec53eaa3e924f39f93594e62085fd
Reviewed-Content-Hash: docs/engine-reference/godot/deprecated-apis.md 6a1353983e1db0d7bc0cc41a568b039495b5413c
Reviewed-Content-Hash: docs/engine-reference/godot/modules/animation.md ee51f50a46f8c63b771f62fe438947d4d84c59e3
Reviewed-Content-Hash: docs/engine-reference/godot/modules/audio.md c72af247505908a04f84a1dd3e765939efe700bd
Reviewed-Content-Hash: docs/engine-reference/godot/modules/input.md 3406b1b813858898696e510ea0accfcc7df98af8
Reviewed-Content-Hash: docs/engine-reference/godot/modules/navigation.md 7ae18ffbd2c3230cb19d610373225bfba187a472
Reviewed-Content-Hash: docs/engine-reference/godot/modules/networking.md 6606880462a2241014f77feb9610c5611e659ec6
Reviewed-Content-Hash: docs/engine-reference/godot/modules/physics.md 3b6ac8947f3f3e8c9ac9e6e0ff6cac06fdb8d805
Reviewed-Content-Hash: docs/engine-reference/godot/modules/rendering.md 2a303185bb57eed31dd1151a036784820747b211
Reviewed-Content-Hash: docs/engine-reference/godot/modules/ui.md 30ad166ab8c4e92c15aa37ed3464483b92b7845b
Reviewed-Content-Hash: project.yaml e704941bbbf4ca25188e8eb8acecac18e6387d0e
Reviewed-Content-Hash: .claude/docs/technical-preferences.md e64f1a53e5b13cb503622f1c3e0691e56789becb
Reviewed-Content-Hash: .claude/skills/architecture-review/SKILL.md 1a9d28aadbcbd26b5fc6b8ed1c64d73ae82b7b73
Reviewed-Content-Hash: .claude/skills/architecture-review/references/1-load.md 9a65759ebdbb2cb1f9744775bfed18cb25e76347
Reviewed-Content-Hash: .claude/skills/architecture-review/references/2-extract-requirements.md d08ea0b0e9ab9760b0d8bfe0cd9115f0bc40f8e2
Reviewed-Content-Hash: .claude/skills/architecture-review/references/3-traceability.md bb7b6b65c5e5e5b8869fa692413aa831615dede7
Reviewed-Content-Hash: .claude/skills/architecture-review/references/4-conflicts.md 0d30f8173b23248a32523a365b606dd1ce9642ab
Reviewed-Content-Hash: .claude/skills/architecture-review/references/5-engine.md 318ecbc1361d430badaf5dd8ce4cfc6ab0dff0ca
Reviewed-Content-Hash: .claude/skills/architecture-review/references/6-document-coverage.md dcce78482ec2ce60048989b6f9d1f797dd0a9a0e
Reviewed-Content-Hash: .claude/skills/architecture-review/references/7-report.md a007fd66bdac87812dc272e4b14cd231174e979d
Reviewed-Content-Hash: .claude/skills/architecture-review/references/8-write.md bf6d8946fc7b9e19eda7f65503a5c8f593a0d2b1
Reviewed-Content-Hash: .claude/skills/architecture-review/references/9-handoff.md fd5f681f4c3517c6a2e388c6d78075d82dded22e

---

### Freshness Check
`RECEIPT: NONE`: no prior report. `UNRESOLVED: docs/architecture/adr-*.md`: the
ADR glob matched nothing, so the whole ADR class was never examined. This run
carries the first stamps.

### Traceability Summary
Total requirements: 120 (53 Foundation, 44 Core, 3 Feature, 20 Presentation)
✅ Covered: 0
🟡 Covered (Proposed): 0
⚠️ Partial: 0
❌ Gaps: 120
Engine risk across requirements: 14 HIGH, 31 MEDIUM, 75 LOW

All 120 IDs are new and registered in `docs/architecture/tr-registry.yaml`
(the registry was empty). No provisional baseline existed to reconcile.

### Coverage Gaps (no ADR exists)
Every requirement is a gap. Listing 120 separate ADR suggestions would be noise,
so the gaps are grouped into 15 proposed ADRs (P01 to P15; labels only, not ADR
numbers). The full per-requirement matrix is in
`docs/architecture/requirements-traceability.md`.

Workflow note: the 8 MVP GDDs run at `standard`, which asks for one
architecture document and *critical* ADRs only. P01 to P08 (Foundation) are the
critical set; P09 to P13 (Core) are strongly advised because four GDDs defer
decisions to them by name; P14 and P15 may fold into the architecture document.

#### P01. App Lifecycle, Composition Root and Battle Builder (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision App Lifecycle, Composition Root and Battle Builder`. Scope: no autoloads, app root, scene-free builder, injection, retry teardown and weakref proof.

Requirements (11): TR-data-004, TR-data-011, TR-input-012, TR-state-001, TR-state-002, TR-state-009, TR-enemy-005, TR-tower-006, TR-tower-013, TR-hero-004, TR-hud-006

#### P02. Fixed-Tick Simulation Clock, Tick Order and Frame Order (Foundation, engine risk HIGH)

Suggested: `/architecture-decision Fixed-Tick Simulation Clock, Tick Order and Frame Order`. Scope: tick rate and clamp, to_ticks, the one tick order, commands between ticks, pause, real-time presentation clocks.

Requirements (16): TR-state-003, TR-state-004, TR-state-006, TR-state-007, TR-state-012, TR-state-014, TR-combat-009, TR-enemy-002, TR-enemy-003, TR-tower-005, TR-tower-010, TR-hero-003, TR-hero-011, TR-hero-013, TR-hud-005, TR-hud-007

#### P03. Catalogue Storage Format, Manifest and Validation (Foundation, engine risk HIGH)

Suggested: `/architecture-decision Catalogue Storage Format, Manifest and Validation`. Scope: Resource vs JSON, strict field checks, manifest load on Android export, read-only proof, content tests.

Requirements (10): TR-data-001, TR-data-002, TR-data-003, TR-data-005, TR-data-007, TR-data-013, TR-data-015, TR-enemy-001, TR-hero-014, TR-hud-016

#### P04. Stat Accessor and Read-Context Contract (Foundation, engine risk LOW)

Suggested: `/architecture-decision Stat Accessor and Read-Context Contract`. Scope: accessor signature, key vocabulary and types, read at use, non-fatal lookups.

Requirements (6): TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005, TR-hud-011

#### P05. Input Adapter, Display Stretch and Platform Lifecycle (Foundation, engine risk HIGH)

Suggested: `/architecture-decision Input Adapter, Display Stretch and Platform Lifecycle`. Scope: Godot event path, Control vs adapter order, emulation, safe area, stretch mode, pause and focus notifications.

Requirements (11): TR-input-002, TR-input-003, TR-input-004, TR-input-005, TR-input-006, TR-input-013, TR-input-016, TR-state-010, TR-hud-002, TR-hud-003, TR-hud-014

#### P06. Fatal Error Path and Release-Safe Checks (Foundation, engine risk HIGH)

Suggested: `/architecture-decision Fatal Error Path and Release-Safe Checks`. Scope: fatal handler and screen, push_error vs assert, dev-error sink.

Requirements (4): TR-data-006, TR-data-009, TR-state-011, TR-enemy-012

#### P07. Determinism, Seeded RNG and Float Policy (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision Determinism, Seeded RNG and Float Policy`. Scope: seed injection, cosmetic RNG split, per-architecture baselines, scalar float vs Vector2.

Requirements (4): TR-state-005, TR-combat-014, TR-enemy-007, TR-hero-006

#### P08. Headless Test Harness and gdUnit4 Configuration (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision Headless Test Harness and gdUnit4 Configuration`. Scope: fixtures, recording fakes, listener-count test, push_error reporting, bot equivalence.

Requirements (7): TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014, TR-tower-014, TR-hero-012

#### P09. Input Resolver Core and Signal Contract (Core, engine risk MEDIUM)

Suggested: `/architecture-decision Input Resolver Core and Signal Contract`. Scope: pure resolver, hit-target registry, state machine, re-entrancy queue, payloads.

Requirements (10): TR-input-001, TR-input-007, TR-input-008, TR-input-009, TR-input-010, TR-input-011, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009

#### P10. Battle Signal Contracts and View Allowlist (Core, engine risk MEDIUM)

Suggested: `/architecture-decision Battle Signal Contracts and View Allowlist`. Scope: synchronous emit, commit before emit, typed signatures, view-only listeners.

Requirements (10): TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012

#### P11. Enemy Entity Kind, Roster and Combat Attachment (Core, engine risk MEDIUM)

Suggested: `/architecture-decision Enemy Entity Kind, Roster and Combat Attachment`. Scope: enemy object type, Health and Status attachment, roster ownership, path lookup.

Requirements (9): TR-combat-001, TR-combat-002, TR-combat-005, TR-combat-006, TR-enemy-008, TR-enemy-009, TR-enemy-010, TR-enemy-011, TR-enemy-013

#### P12. Combat Delivery and Targeting API (Core, engine risk LOW)

Suggested: `/architecture-decision Combat Delivery and Targeting API`. Scope: deliver guards, targeting helpers, per-tick budget.

Requirements (7): TR-combat-003, TR-combat-004, TR-combat-007, TR-combat-008, TR-combat-013, TR-tower-007, TR-hero-007

#### P13. Sim/Input Split and Command Result Codes (Core, engine risk LOW)

Suggested: `/architecture-decision Sim/Input Split and Command Result Codes`. Scope: HeroSim/TowerSim vs Input pieces, command enums, gold ownership.

Requirements (7): TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009, TR-hero-001, TR-hero-002, TR-hero-015

#### P14. Battle Field Rendering and Draw-Call Budget (Presentation, engine risk MEDIUM)

Suggested: `/architecture-decision Battle Field Rendering and Draw-Call Budget`. Scope: single _draw nodes, pools, draw order, HUD budget.

Requirements (5): TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015

#### P15. Dev Telemetry: Gesture Log and Run Log (Feature, engine risk LOW)

Suggested: `/architecture-decision Dev Telemetry: Gesture Log and Run Log`. Scope: gesture log harness, JSONL run log, per-run counters.

Requirements (3): TR-input-015, TR-hero-009, TR-hud-013


### Cross-ADR Conflicts
NOT ASSESSED: no ADRs exist. `adr-dep-graph.sh` reports `ADRS: 0`.

### Cross-GDD tensions found while extracting (advisory, not ADR conflicts)
These are not cross-ADR conflicts, but each will become one if two ADRs are
written from the GDDs as they stand:

1. **Tick order is stated in four places.** Game State Rule 5, Combat Rule 11,
   Enemy & Wave Rule 12 and Tower Rule 9 each restate it. They agree today. P02
   should own the one copy and the GDDs should cite it.
2. **Composition root moved.** The systems index TD note puts the composition
   root in the battle scene; the Game State GDD moves it to a scene-free
   builder. Both Combat and Game State flag this for technical-director sign-off.
   P01 must settle it.
3. **ProjectileSpawner cut.** The systems index lists it under Combat; the Combat
   GDD cuts it. Awaiting technical-director confirmation (P11/P12).
4. **Hit-flash shader.** Art bible §8 budgets a hit-flash shader; the Combat GDD
   uses no shaders. Owner: technical-artist (P14).
5. **Stage geometry location.** Enemy & Wave moves path and slots from the
   stage scene to the Stage record; Data's CI content test still opens each
   `scene_ref`. Consistent, but P03 must state both.

### ADR Dependency Order
No ADRs, so no graph. Recommended authoring order for the proposed set:

Foundation (no dependencies):
  1. P01 App Lifecycle, Composition Root and Battle Builder
  2. P03 Catalogue Storage Format, Manifest and Validation
  3. P06 Fatal Error Path and Release-Safe Checks (needs P01)
  4. P02 Fixed-Tick Simulation Clock, Tick Order and Frame Order (needs P01)
  5. P04 Stat Accessor and Read-Context Contract (needs P03, P06)
  6. P05 Input Adapter, Display Stretch and Platform Lifecycle (needs P01, P02)
  7. P07 Determinism, Seeded RNG and Float Policy (needs P02)
  8. P08 Headless Test Harness and gdUnit4 Configuration (needs P01, P06)
Core:
  9. P10 Battle Signal Contracts and View Allowlist (needs P01, P02)
  10. P09 Input Resolver Core and Signal Contract (needs P05, P10)
  11. P11 Enemy Entity Kind, Roster and Combat Attachment (needs P01, P04)
  12. P12 Combat Delivery and Targeting API (needs P11)
  13. P13 Sim/Input Split and Command Result Codes (needs P02, P09, P12)
Presentation and Feature:
  14. P14 Battle Field Rendering and Draw-Call Budget (needs P11, P13)
  15. P15 Dev Telemetry: Gesture Log and Run Log (needs P09, P13)

### GDD Revision Flags
None from this run. Phase 5b checks GDDs against HIGH RISK engine findings in
ADRs, and there are no ADRs. Systems index left unchanged.

### Engine Compatibility Issues
Engine: Godot 4.7.2
ADRs with Engine Compatibility section: 0 / 0
Deprecated API references: none (no ADRs)
Stale version references: none (no ADRs)
Post-cutoff API conflicts: none (no ADRs)

**Engine validation: NOT ASSESSED** for the ADR class, and the godot-specialist
consultation was skipped: it reviews ADR engine claims, and none exist.

Advisory, from the GDDs' own engine assumptions checked against
`breaking-changes.md` and `deprecated-apis.md` (for the ADR authors, not
verdict items):

- **P05, stretch mode.** `project.godot` sets no `display/window/stretch/*` key.
  4.7 changed the stretch defaults for new projects (`canvas_items` / `expand`).
  Input TR-input-016 and HUD TR-hud-014 assume a fixed 540x960 field space, and
  Enemy & Wave layout rules L3, L5 to L7 depend on it. Set mode and aspect
  explicitly in P05 rather than relying on a default.
- **P05, mouse device ID.** 4.7 stopped mouse and keyboard reporting device `0`
  (`InputEvent.DEVICE_ID_MOUSE`). TR-input-005 keeps mouse and touch index 0
  apart; the adapter must test event type, not `device == 0`.
- **P05, dual focus.** Since 4.6 touch focus is separate from keyboard focus.
  This bears on TR-hud-002 and TR-hud-003 (modal Controls consuming events).
- **P14, line drawing.** 4.7 no longer adds an antialias feather to CanvasItem
  lines. Enemy & Wave already doubts `draw_polyline` corners at width 72 and
  proposes a baked polygon; this change adds weight to that choice.
- **P15, FileAccess.** Since 4.4 `store_*` returns `bool`. TR-hud-013 says a
  run-log write failure is non-fatal; check the return value.
- **Unverified by the GDDs themselves:** Control event order against
  `_unhandled_input`, input-before-ticks within a frame, `free()` timing inside
  input callbacks, mobile lifecycle notifications, `get_display_safe_area()`
  units, `Vector2` precision. None is in the pinned reference (`modules/input.md`
  has no touch coverage). Each P05/P02/P01 author should verify against live 4.7
  docs.

### Architecture Document Coverage
**Architecture document coverage: NOT ASSESSED**: no
`docs/architecture/architecture.md`. Run `/create-architecture` to produce it;
at `standard` it is the one required architecture document.

### Structural notes
- `enemy-wave.md`, `tower-system.md`, `hero-system.md`, `battle-hud.md`,
  `data-config-pipeline.md`, `input-gesture-resolver.md` and
  `game-state-stage-flow.md` have no `## Tuning Knobs` heading; values sit in
  Starter-values tables. Fine at `standard` (Tuning Knobs is not among its
  required sections), but needed if these systems move to `full`.

---

### Verdict: FAIL

All 120 requirements are uncovered, including 53 Foundation and 44 Core.
Three parts of the full-mode scope are also **NOT ASSESSED**: cross-ADR
conflicts (no ADRs), engine validation (no ADRs), and architecture document
coverage (no `architecture.md`). FAIL outranks NOT ASSESSED, so it is the
verdict.

This is the expected state for a project at Systems Design that has not yet
started Technical Setup; it is not a design fault. It does block
`/gate-check pre-production`.

### Blocking Issues (must resolve before PASS)
1. No `docs/architecture/architecture.md`. Run `/create-architecture`.
2. No ADRs for the eight Foundation groups P01 to P08 (53 requirements).
3. Core groups P09 to P13 (44 requirements) uncovered; four GDDs name these
   decisions as prerequisites for their first story.
4. Every ADR must reach `Accepted`, not `Proposed`, before coverage counts.

### Required ADRs
In order: P01, P03, P06, P02, P04, P05, P07, P08, P10, P09, P11, P12, P13,
P14, P15 (see ADR Dependency Order above for titles and reasons).
