## Architecture Review Report
Date: 2026-11-04 (second run that day)
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
GDDs Reviewed: 8 (systems index and game concept read for context; `gdd-cross-review-2026-11-03.md` is a review report, not a GDD, and adds no requirements)
ADRs Reviewed: 0

Reviewed-Content-Hash: design/gdd/battle-hud.md a8f89fe590ea44636a835021accab97e365ff7f3
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 5e5df4a50191c71f81644957fb43ef96b38ab6d5
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 70d0e7681e95807f16f083f1f2ce650c97d328c0
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md 5a40dd61c36f3a56fc886d773347673fe38878c0
Reviewed-Content-Hash: design/gdd/hero-system.md 377e450bbee022ae776076cebdd1ed1c092a02fc
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4c34ae187a1d77212e8c66bd6454c8d7a170ad95
Reviewed-Content-Hash: design/gdd/systems-index.md 46346acf72e112720034dfd4bcd5b35b83b5f552
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 886b7a262a9c948aca953eff4a181be8bcd308f7
Reviewed-Content-Hash: docs/architecture/architecture.md 6296936cf4954972c0152041292c351cdff8b12c
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
Prior report: `architecture-review-2026-11-04.md` (full, workflow full).
`UNRESOLVED: docs/architecture/adr-*.md`: still no ADRs, so the prior report
could not stand in for this run. Changed since it: all 11 files under
`design/gdd/` and `architecture.md` (now v3), mostly from commit 9c81113 (Flow
and Battle HUD revised after their first design reviews) and the Hero Rule 2
amendment. `architecture.md` reaches Phase 6, so this is a full re-run, not a
`single-gdd` scope.

The requirement baseline was rebuilt from the diff of every GDD against the
prior report's commit (84216d5), checked against the 121 registry entries,
rather than by re-reading all 8 GDDs whole.

### Traceability Summary
Total requirements: 125 (55 Foundation, 46 Core, 3 Feature, 21 Presentation)
✅ Covered: 0
🟡 Covered (Proposed): 0
⚠️ Partial: 0
❌ Gaps: 125
Engine risk across requirements: 15 HIGH, 33 MEDIUM, 77 LOW

Registry changes (`tr-registry.yaml` v4):
- **New (4):**
  - TR-state-015 (Foundation, HIGH). The battle strongly holds every helper `build` creates; the builder holds nothing, since a method Callable or signal connection does not keep a `RefCounted` alive and `.call()` on a dead one aborts the caller (Flow Rule 2a). Planned: ADR-0001.
  - TR-state-016 (Foundation, MEDIUM). `cancel_input()` is a guarded public Battle method, set by the wrapper, called by Flow on Won, Lost, Paused and Fatal and by the app root on retry; a second call is harmless (Flow Rule 15, Input Rule 7). Planned: ADR-0001.
  - TR-enemy-017 (Core, LOW). `got_through_by_type()` counts a leak before `enemy_leaked` fires, so the fatal leak is in the result (Enemy Rule 10). Planned: ADR-0009.
  - TR-hud-017 (Presentation, MEDIUM). HudField redraws only on a quantised key change (HUD Rule 1). Planned: ADR-0011.
- **Revised, same intent (17):** TR-data-005 (cross-field slop check at load), TR-input-011 (null `create` reaches Fatal), TR-input-012 (the wrapper builds the resolver; hit radii are owner constants), TR-input-015 (gesture log also hears `burst_started`), TR-state-002 (`build` returns null on an unbuildable stage), TR-state-006 (Fatal absorbing; `in_build()` true in Paused from Build), TR-state-007 (one commit, act, emit order for every transition), TR-state-011 (Fatal overrides Won, Lost and Paused; wrapper checks the latch per step), TR-tower-009 (one shared `early_call_bonus`), TR-hero-013 (a pin in Build places the hero at once), TR-hud-001 (fourth piece HudModals), TR-hud-002 (modals hidden, never freed in their handler), TR-hud-003 (modal press model repeats the adapter's rules), TR-hud-010 (float `burst_wedge`, new reads), TR-hud-011 (`phase() == FATAL`, not `halted()`), TR-hud-012 (snapshot on the first `advance` after the outcome), TR-hud-016 (new content rows).
- **Checked, unchanged:** Combat, Data and Tower edits outside those rows were wording or cross-references. Enemy's `requires_bend` row was already in TR-enemy-001.
- **Deprecated:** none.

### Coverage Gaps (no ADR exists)
All 125 requirements are gaps. Each one is assigned to exactly one ADR that
`architecture.md` proposes (ADR-0001 to ADR-0011). The full matrix and the
per-ADR lists are in `docs/architecture/requirements-traceability.md`.

| Proposed ADR | Layer | Engine risk | TRs | Change this run |
|---|---|---|---|---|
| ADR-0001 App Lifecycle, Composition Root and Fatal Path | Foundation | HIGH | 17 | +TR-state-015, TR-state-016 |
| ADR-0002 Catalogue Storage Format, Manifest and Validation | Foundation | HIGH | 10 | none |
| ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle | Foundation | HIGH | 11 | none |
| ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism | Foundation | HIGH | 20 | none |
| ADR-0005 Stat Accessor and Read-Context Contract | Foundation | LOW | 6 | none |
| ADR-0006 Battle Signal Contracts and View Allowlist | Foundation | MEDIUM | 10 | none |
| ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint | Foundation | MEDIUM | 6 | none |
| ADR-0008 Input Resolver Core and Signal Contract | Foundation | MEDIUM | 11 | none |
| ADR-0009 Enemy Entity, Roster and Combat API | Core | MEDIUM | 18 | +TR-enemy-017 |
| ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry | Core | LOW | 10 | none |
| ADR-0011 Battle Field Rendering and Draw-Call Budget | Presentation | MEDIUM | 6 | +TR-hud-017 |

Suggested commands: `/architecture-decision "<title>"` with each title above.

### Cross-ADR Conflicts
NOT ASSESSED: no ADRs exist. `adr-dep-graph.sh` reports `ADRS: 0`.

### ADR Dependency Order
No ADRs, so no graph. `architecture.md` v3 gives the planned order, Foundation
first: ADR-0001, then 0002 and 0003, then 0004, 0005, 0006, 0007, 0008, then
Core 0009 and 0010, then Presentation 0011. It has no cycles.

### GDD Revision Flags
None from engine findings: Phase 5b checks GDDs against HIGH RISK engine
findings in ADRs, and there are no ADRs. Systems index left unchanged.

### Engine Compatibility Issues
Engine: Godot 4.7.2
ADRs with Engine Compatibility section: 0 / 0
Deprecated API references: none (no ADRs)
Stale version references: none (no ADRs)
Post-cutoff API conflicts: none (no ADRs)

**Engine validation: NOT ASSESSED** for the ADR class, and the godot-specialist
consultation was skipped: it reviews ADR engine claims, and none exist.

Advisory, from the GDDs: Flow Rule 2a now rests on an engine behaviour that the
pinned reference does not cover. A method `Callable` or signal connection does
not keep a `RefCounted` target alive, and `.call()` on a dead one raises a
script error that aborts the caller. It was seen on the 4.7.2 desktop editor
only. TR-state-015 carries it at HIGH risk; ADR-0001 must repeat the probe on an
export template and a phone, and the result belongs in
`docs/engine-reference/godot/` once confirmed.

### Architecture Document Coverage
`docs/architecture/architecture.md` v3 (2026-11-04) exists, so Phase 6 ran.

**Every system appears in the layers:** yes, all 22 systems from
`systems-index.md`, with HudModals added to the HUD and the hero view to the
field views. **Orphaned architecture:** none.

**Fixed since the prior report:** B10 no longer asks Hero for a cooldown total;
B9 now injects the Burst ID and `wave_index()`; the `phase` to `phase_changed`
rename is stated where the signal is declared and deferred to ADR-0006 and
QQ-07; QQ-09, QQ-17 (lifetime half), QQ-19 and QQ-20 are closed in line with the
GDDs.

**Still stale:**
1. **Baseline count and ADR-0009 list.** "Traceability Coverage Check" and
   "Required ADRs" still say 120 requirements, and ADR-0009's Covers list
   (16) omits TR-enemy-016, which the prior review registered. With this run
   the count is 125: add TR-enemy-016 and TR-enemy-017 to ADR-0009,
   TR-state-015 and TR-state-016 to ADR-0001, TR-hud-017 to ADR-0011, and
   update the layer and risk tallies.
2. **B7 labels.** `wave_index()` is still marked "view-only read", but Flow
   reads it for the result (B9 already says so). It is a sim-to-sim read.
3. **Data Flow 3.** The signal table still names no dev-only listener. The
   gesture log listens to `tower_upgraded` and now also `burst_started` (Input
   Rule 13), and the listener-count test's allowlist (ADR-0006) needs both.
4. **Header.** v3 says "No gate has re-reviewed v2 or v3". Two GDDs it reflects,
   Flow and Battle HUD, are In Review with re-reviews pending, so v3 may move
   again.

**Data flow and API boundaries otherwise cover** the GDDs' cross-system
communication: every signal, command and injected value named in the 8 GDDs
appears in the signal table or in B0 to B10, including `set_input_cancel`,
`cancel_input()`, `early_call_bonus()`, `slows_applied()` and the modal press
calls.

**Architecture document coverage: CONCERNS.** The four items are document
edits for `/create-architecture` in update mode (Data Flow, API Boundaries,
Required ADRs).

---

### Verdict: FAIL

All 125 requirements are uncovered, including 55 Foundation and 46 Core, because
no ADR exists yet. Cross-ADR conflicts and engine validation are **NOT
ASSESSED** (no ADRs). Architecture document coverage gives CONCERNS. FAIL
outranks both, so it is the verdict.

This is still the expected state before ADRs are written, not a design fault. It
blocks `/gate-check pre-production`.

### Blocking Issues (must resolve before PASS)
1. No ADRs. Write ADR-0001 to ADR-0008 (Foundation) first, then ADR-0009 and
   ADR-0010 before the Combat, Enemy, Hero and Tower stories.
2. Every ADR must reach `Accepted`, not `Proposed`, before coverage counts.
3. Update `architecture.md` for the four stale items above before ADR-0001 and
   ADR-0009 are written, since their Covers lists are now short.

Advisory, not blocking this review: Flow, Battle HUD, Hero and Input are In
Review. A re-review that changes a rule can add or reword requirements again,
so write ADR-0001, ADR-0004 and ADR-0006 after the Flow and HUD re-reviews.

### Required ADRs
As planned in `architecture.md` v3: ADR-0001 App Lifecycle, Composition Root and
Fatal Path; ADR-0002 Catalogue; ADR-0003 Input Adapter and Display; ADR-0004
Tick, Frame Order and Determinism; ADR-0005 Stat Accessor; ADR-0006 Signal
Contracts; ADR-0007 Test Harness; ADR-0008 Input Resolver; ADR-0009 Enemy Entity
and Combat API; ADR-0010 Sim/Input Split and Commands; ADR-0011 Rendering
(deferrable).
