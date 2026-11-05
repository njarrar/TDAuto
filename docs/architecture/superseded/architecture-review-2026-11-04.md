## Architecture Review Report
Date: 2026-11-04
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
GDDs Reviewed: 8 (systems index and game concept read for context; `gdd-cross-review-2026-11-03.md` is a review report, not a GDD, and adds no requirements)
ADRs Reviewed: 0

Reviewed-Content-Hash: design/gdd/battle-hud.md 143cd8f5d98210c2de16e0406215914d5a6d22f4
Reviewed-Content-Hash: design/gdd/combat-damage.md 40ae59c616520d9cd4b3a5eea61c1ec824b8c0d8
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 9ab10a8976932d538c3e9eced0c9ccd235555840
Reviewed-Content-Hash: design/gdd/enemy-wave.md e6d3298873a613e5a9c46165819f85fa62767870
Reviewed-Content-Hash: design/gdd/game-concept.md 69276bc59133ed1fc4125a561b829e3bd7eb4156
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md e586644cf97fc7fc1437737f2e44f763da568caf
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md 715aaf91204dc9bd493071f2678a97fd6eb13f41
Reviewed-Content-Hash: design/gdd/hero-system.md 6c42e0f35c803d364a8156eb02ebd5a781b47949
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md bf92775df24697a7fab709ba552e53f2f65da506
Reviewed-Content-Hash: design/gdd/systems-index.md 15635eccb051bd7e3e559ebe9fecf380fc0ee7d8
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml e27b9ad20ee692b9a2b53380fca6310e9b06693d
Reviewed-Content-Hash: docs/architecture/architecture.md b53fa5c07ef94a35c02c2223ec66efe9921d97b1
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
Prior report: `architecture-review-2026-11-03.md` (full, workflow full).
`UNRESOLVED: docs/architecture/adr-*.md`: still no ADRs, so the prior report
could not stand in for this run. Changed since it: `battle-hud.md`,
`enemy-wave.md`, `game-state-stage-flow.md`, `input-gesture-resolver.md`,
`systems-index.md` (all from commit 1687498, the cross-GDD blocker fixes), plus
`architecture.md` (new). A new architecture document reaches Phase 6, so this is
a full re-run, not a `single-gdd` scope.

### Traceability Summary
Total requirements: 121 (53 Foundation, 45 Core, 3 Feature, 20 Presentation)
✅ Covered: 0
🟡 Covered (Proposed): 0
⚠️ Partial: 0
❌ Gaps: 121
Engine risk across requirements: 14 HIGH, 31 MEDIUM, 76 LOW

Registry changes (`tr-registry.yaml` v3):
- **New:** TR-enemy-016. `wave_index()` is the 1-based position of the last wave started, 0 before any start, never reset per wave; Flow reads it for the result and the HUD for pips and result text (Enemy & Wave Rule 14).
- **Revised (same intent, new wording):**
  - TR-hud-010: the HUD no longer asks Hero for a cooldown total; it draws the wedge from `cooldown_left()` and Burst `cooldown` read through the accessor.
  - TR-input-015: the gesture log also listens to `tower_upgraded` and reads `chip_state()`, replacing Tower's own chip log.
  - TR-hero-004: the builder also injects the Burst ID into the HUD.
  - TR-state-006: "last wave started" is now defined as `wave_index()`.
- **Checked, unchanged:** TR-input-014 already said headless bots call commands directly, which is what the fixed Input Rule 11 now says.
- **Deprecated:** none.

### Coverage Gaps (no ADR exists)
All 121 requirements are gaps. Each one is assigned to exactly one ADR that
`architecture.md` v2 proposes (ADR-0001 to ADR-0011). The full matrix is in
`docs/architecture/requirements-traceability.md`.

#### ADR-0001 (proposed). App Lifecycle, Composition Root and Fatal Path (Foundation, engine risk HIGH)

Suggested: `/architecture-decision "App Lifecycle, Composition Root and Fatal Path"`. Decides: no autoloads, AppRoot states (Boot, InStage, Fatal), scene-free builder, injected callables (method Callables only, no capturing lambdas or bind), per-battle FatalLatch, push_error vs assert, dev-error sink, retry by dropping references and the weakref proof, free() vs queue_free() timing, Reduce Motion location.

Requirements (15): TR-data-004, TR-data-006, TR-data-009, TR-data-011, TR-input-012, TR-state-001, TR-state-002, TR-state-009, TR-state-011, TR-enemy-005, TR-enemy-012, TR-tower-006, TR-tower-013, TR-hero-004, TR-hud-006

#### ADR-0002 (proposed). Catalogue Storage Format, Manifest and Validation (Foundation, engine risk HIGH)

Suggested: `/architecture-decision "Catalogue Storage Format, Manifest and Validation"`. Decides: Resource vs JSON, record classes, strict field checks, manifest load proven on an Android export, read-only proof with duplicate_deep, content tests.

Requirements (10): TR-data-001, TR-data-002, TR-data-003, TR-data-005, TR-data-007, TR-data-013, TR-data-015, TR-enemy-001, TR-hero-014, TR-hud-016

#### ADR-0003 (proposed). Input Adapter, Display Stretch and Platform Lifecycle (Foundation, engine risk HIGH)

Suggested: `/architecture-decision "Input Adapter, Display Stretch and Platform Lifecycle"`. Decides: engine event path and its order against _process and Controls (a spike first), touch and mouse emulation, 4.7 device IDs, safe area, stretch mode and aspect, minimum width, tall-phone behaviour, pause and focus notifications per platform; decided here, inherited later by the Mobile Platform GDD.

Requirements (11): TR-input-002, TR-input-003, TR-input-004, TR-input-005, TR-input-006, TR-input-013, TR-input-016, TR-state-010, TR-hud-002, TR-hud-003, TR-hud-014

#### ADR-0004 (proposed). Fixed-Tick Clock, Tick Order, Frame Order and Determinism (Foundation, engine risk HIGH)

Suggested: `/architecture-decision "Fixed-Tick Clock, Tick Order, Frame Order and Determinism"`. Decides: tick driver and rate, clamp value and max ticks per frame, the one tick order, commands between ticks, the in-sim clock gate, real-time presentation clocks, seeded RNG and cosmetic RNG split, float policy and per-architecture baselines, frame budget split.

Requirements (20): TR-state-003, TR-state-004, TR-state-005, TR-state-006, TR-state-007, TR-state-012, TR-state-014, TR-combat-009, TR-combat-014, TR-enemy-002, TR-enemy-003, TR-enemy-007, TR-tower-005, TR-tower-010, TR-hero-003, TR-hero-006, TR-hero-011, TR-hero-013, TR-hud-005, TR-hud-007

#### ADR-0005 (proposed). Stat Accessor and Read-Context Contract (Foundation, engine risk LOW)

Suggested: `/architecture-decision "Stat Accessor and Read-Context Contract"`. Decides: stat_int and stat_float, ReadContext reuse per caller, key vocabulary and types, non-fatal lookups.

Requirements (6): TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005, TR-hud-011

#### ADR-0006 (proposed). Battle Signal Contracts and View Allowlist (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision "Battle Signal Contracts and View Allowlist"`. Decides: synchronous emit, commit before emit, final signal names (QQ-07) and payloads, ID types, view allowlist.

Requirements (10): TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012

#### ADR-0007 (proposed). Headless Test Harness, gdUnit4 and Layer Lint (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision "Headless Test Harness, gdUnit4 and Layer Lint"`. Decides: fixtures, recording fakes that assert payloads, listener-count test, push_error reporting, layer-import lint, the manual-evidence list for what cannot run headless, GDScript 4.7 pitfalls for the control manifest.

Requirements (6): TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014, TR-tower-014

#### ADR-0008 (proposed). Input Resolver Core and Signal Contract (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision "Input Resolver Core and Signal Contract"`. Decides: pure resolver, hit-target registry, state machine, re-entrancy queue, payloads, gesture log.

Requirements (11): TR-input-001, TR-input-007, TR-input-008, TR-input-009, TR-input-010, TR-input-011, TR-input-015, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009

#### ADR-0009 (proposed). Enemy Entity, Roster and Combat API (Core, engine risk MEDIUM)

Suggested: `/architecture-decision "Enemy Entity, Roster and Combat API"`. Decides: Targetable base class, Health and Status attachment, roster ownership and typed lists, path lookup, deliver guards, targeting helpers, per-tick budget.

Requirements (17): TR-combat-001, TR-combat-002, TR-combat-003, TR-combat-004, TR-combat-005, TR-combat-006, TR-combat-007, TR-combat-008, TR-combat-013, TR-enemy-008, TR-enemy-009, TR-enemy-010, TR-enemy-011, TR-enemy-013, TR-enemy-016, TR-tower-007, TR-hero-007

#### ADR-0010 (proposed). Sim/Input Split, Command Result Codes and Dev Telemetry (Core, engine risk LOW)

Suggested: `/architecture-decision "Sim/Input Split, Command Result Codes and Dev Telemetry"`. Decides: HeroSim/TowerSim vs HeroInput/TowerInput, result enums with OK = 0, gold ownership, bot equivalence, run counters and run log.

Requirements (10): TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009, TR-hero-001, TR-hero-002, TR-hero-009, TR-hero-012, TR-hero-015, TR-hud-013

#### ADR-0011 (proposed). Battle Field Rendering and Draw-Call Budget (Presentation, engine risk MEDIUM)

Suggested: `/architecture-decision "Battle Field Rendering and Draw-Call Budget"`. Decides: single _draw nodes, pools, draw order, path polygon, HUD draw budget, hit-flash shader question.

Requirements (5): TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015


### Cross-ADR Conflicts
NOT ASSESSED: no ADRs exist. `adr-dep-graph.sh` reports `ADRS: 0`.

### ADR Dependency Order
No ADRs, so no graph. `architecture.md` v2 gives the planned order, Foundation
first: ADR-0001, then 0002 and 0003, then 0004, 0005, 0006, 0007, 0008, then
Core 0009 and 0010, then Presentation 0011. It has no cycles; the two gate
reviews checked it.

### GDD Revision Flags
None from engine findings: Phase 5b checks GDDs against HIGH RISK engine
findings in ADRs, and there are no ADRs. Systems index left unchanged.

One GDD follow-up comes from the architecture rather than the engine (see
Phase 6, item 1): `architecture.md` renames Flow's `phase` signal to
`phase_changed`, and the Game State GDD still says `phase`.

### Engine Compatibility Issues
Engine: Godot 4.7.2
ADRs with Engine Compatibility section: 0 / 0
Deprecated API references: none (no ADRs)
Stale version references: none (no ADRs)
Post-cutoff API conflicts: none (no ADRs)

**Engine validation: NOT ASSESSED** for the ADR class, and the godot-specialist
consultation was skipped: it reviews ADR engine claims, and none exist. The
advisory engine notes of the 2026-11-03 report (stretch defaults, 4.7 mouse
device ID, 4.6 dual focus, 4.7 line feather, `FileAccess` return values) are
now carried in `architecture.md` and its open questions; the GDD changes add no
new engine assumption.

### Architecture Document Coverage
`docs/architecture/architecture.md` v2 (2026-11-03) now exists, so Phase 6 ran.

**Every system appears in the layers:** yes. All 22 systems from
`systems-index.md` have a layer row; the 14 later-tier systems are reserved slots
with named seams. Enemy & Wave's status in the index changed to In Review; that
does not affect the architecture.

**Orphaned architecture:** none. Composition Root modules (AppRoot, Builder,
BattleWrapper, Fatal screen) all derive from the Game State GDD.

**Stale against the changed GDDs (the document predates commit 1687498):**
1. **`phase` vs `phase_changed`.** The architecture renames the signal; Game
   State Rule 15, Tower's chip and the HUD tables still say `phase`. Either edit
   the GDDs or record the rename in ADR-0006. Until one happens, two sources
   disagree on a wiring name.
2. **B10 HUD read surface** says Hero must add a "cooldown total". The HUD GDD
   dropped that request: it reads Burst `cooldown` through the accessor instead.
   Remove it from B10 and from the ADR-0010 scope note.
3. **B9 injected values** list `left_handed` for the HUD but not the Burst ID,
   which the builder now passes to the HUD (TR-hero-004 revised).
4. **B7 and B0 `StageResult`.** `wave_index()` is labelled "view-only read
   requested by the HUD", but Flow also reads it to fill the result's
   `last_wave_started`. It is a sim-to-sim read, so it is not view-only.
5. **Data Flow 3** lists signal listeners. The gesture log now listens to
   `tower_upgraded` and reads `chip_state()`. That is a dev-only listener, but
   the listener-count test's allowlist (ADR-0006) needs it.

**Data flow and API boundaries otherwise cover** the GDDs' cross-system
communication: every signal and command named in the 8 GDDs appears in the
signal table or in B1 to B10.

**Architecture document coverage: CONCERNS.** The five items above are document
edits, run with `/create-architecture` in update mode (sections Data Flow and
API Boundaries).

---

### Verdict: FAIL

All 121 requirements are uncovered, including 53 Foundation and 45 Core, because
no ADR exists yet. Cross-ADR conflicts and engine validation are **NOT
ASSESSED** (no ADRs). Architecture document coverage, NOT ASSESSED last time,
now runs and gives CONCERNS. FAIL outranks both, so it is the verdict.

This is still the expected state before ADRs are written, not a design fault. It
blocks `/gate-check pre-production`.

### Blocking Issues (must resolve before PASS)
1. No ADRs. Write ADR-0001 to ADR-0008 (Foundation) first, then ADR-0009 and
   ADR-0010 before the Combat, Enemy, Hero and Tower stories.
2. Every ADR must reach `Accepted`, not `Proposed`, before coverage counts.
3. Update `architecture.md` for the five stale items above before ADR-0006
   (signals) and ADR-0010 (commands) are written, since both would inherit them.

### Required ADRs
As planned in `architecture.md` v2: ADR-0001 App Lifecycle, Composition Root and
Fatal Path; ADR-0002 Catalogue; ADR-0003 Input Adapter and Display; ADR-0004
Tick, Frame Order and Determinism; ADR-0005 Stat Accessor; ADR-0006 Signal
Contracts; ADR-0007 Test Harness; ADR-0008 Input Resolver; ADR-0009 Enemy Entity
and Combat API; ADR-0010 Sim/Input Split and Commands; ADR-0011 Rendering
(deferrable).
