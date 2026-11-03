## Architecture Review Report
Date: 2026-11-03 (second review of the day)
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
GDDs Reviewed: 8 (systems index, game concept and the cross-GDD review read for context, no requirements drawn from them)
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
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 95b5226ab7ee72698a74be79a31c22b789d2f19c
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
Prior report: `architecture-review-2026-11-03.md` (full, workflow full, FAIL).
It covers this run's mode and tier, but the check returned
`UNRESOLVED: docs/architecture/adr-*.md`: the ADR glob still matches nothing,
so no prior result can stand in for this run. Inputs changed since it:

- `CHANGED`: `battle-hud.md`, `enemy-wave.md`, `game-state-stage-flow.md`,
  `input-gesture-resolver.md`, `systems-index.md` (the four cross-GDD blocker fixes).
- `NEW`: `architecture.md` (Phase 6 can now run), `gdd-cross-review-2026-11-03.md`
  (a review record, not a GDD).

### Traceability Summary
Total requirements: 121 (53 Foundation, 45 Core, 3 Feature, 20 Presentation)
✅ Covered: 0
🟡 Covered (Proposed): 0
⚠️ Partial: 0
❌ Gaps: 121

Registry changes (no renumbering, no provisional IDs in `architecture.md`):
- **New** TR-enemy-016: Enemy & Wave exposes view-only `wave_index()` (1-based
  last wave started, 0 before the first start, set when `start_next_wave`
  commits, unchanged by a clear or an outcome) and `got_through_by_type()`; the
  builder injects `wave_index()` into Flow's result. Source: Enemy & Wave
  Rule 14, Flow Rule 15. Proposed ADR-0009. Engine risk LOW.
- **Revised** TR-input-015: the gesture log also records each `tower_upgraded`
  commit and `chip_state()` at each tower prompt (Input Rule 13, cross-GDD B3).
- **Revised** TR-hud-011: the burst wedge reads Burst `cooldown` through the
  accessor at use time with the builder-injected Burst ID (HUD Rule 12, cross-GDD B2).
- **Unchanged** TR-input-014 and TR-hero-012: the B1 fix (bots call commands
  directly) brought Input and Flow in line with what both entries already said.

### Coverage Gaps (no ADR exists)
Every requirement is a gap. `architecture.md` now folds the first review's
P01 to P15 into 11 proposed ADRs; the matrix in
`docs/architecture/requirements-traceability.md` is re-keyed to them.

| Proposed | Title | Layer | TRs | Engine risk |
|---|---|---|---|---|
| ADR-0001 | App Lifecycle, Composition Root and Fatal Path | Foundation | 15 | HIGH |
| ADR-0002 | Catalogue Storage Format, Manifest and Validation | Foundation | 10 | HIGH |
| ADR-0003 | Input Adapter, Display Stretch and Platform Lifecycle | Foundation | 11 | HIGH |
| ADR-0004 | Fixed-Tick Clock, Tick Order, Frame Order and Determinism | Foundation | 20 | HIGH |
| ADR-0005 | Stat Accessor and Read-Context Contract | Foundation | 6 | LOW |
| ADR-0006 | Battle Signal Contracts and View Allowlist | Foundation | 10 | MEDIUM |
| ADR-0007 | Headless Test Harness, gdUnit4 and Layer Lint | Foundation | 6 | MEDIUM |
| ADR-0008 | Input Resolver Core and Signal Contract | Foundation | 11 | MEDIUM |
| ADR-0009 | Enemy Entity, Roster and Combat API | Core | 17 | MEDIUM |
| ADR-0010 | Sim/Input Split, Command Result Codes and Dev Telemetry | Core | 10 | LOW |
| ADR-0011 | Battle Field Rendering and Draw-Call Budget | Presentation | 5 | MEDIUM |

Each TR is assigned to exactly one proposed ADR (121 of 121).

### Cross-ADR Conflicts
NOT ASSESSED: no ADRs exist. `adr-dep-graph.sh` reports `ADRS: 0`.

### Cross-GDD tensions carried for the ADR authors (advisory)
1. **Resolved since the first review:** the four cross-GDD blockers (bot path,
   wedge total, chip log, `wave_index()`) are fixed in the GDD text. Input and
   Enemy & Wave are In Review pending `/review-all-gdds consistency`.
2. **Still open, owned by ADRs:** composition root as a scene-free builder,
   ProjectileSpawner cut, the one tick order, stage geometry on the Stage record
   (QQ-08); hit-flash shader (QQ-10).
3. **Cross-GDD warning C1** (an Input record with `tap_slop > drag_slop` passes
   the catalogue and yields no resolver, with no Fatal route) has no home in
   `architecture.md`. ADR-0002 or ADR-0008 should pick the check.
4. **Cross-GDD warning C2** (who calls `cancel()`) is settled in
   `architecture.md` B9 by injecting `cancel_input()` into Flow; Input Rule 7
   still names only the adapter. ADR-0001 should record it and the GDD follow.

### ADR Dependency Order
No ADRs, so no graph. Authoring order as proposed in `architecture.md`:

Foundation:
  1. ADR-0001 App Lifecycle, Composition Root and Fatal Path (none)
  2. ADR-0002 Catalogue Storage Format, Manifest and Validation (ADR-0001)
  3. ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle (ADR-0001; starts with a device spike)
  4. ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism (ADR-0001, ADR-0003)
  5. ADR-0005 Stat Accessor and Read-Context Contract (ADR-0001, ADR-0002)
  6. ADR-0006 Battle Signal Contracts and View Allowlist (ADR-0001, ADR-0004)
  7. ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint (ADR-0001, ADR-0006)
  8. ADR-0008 Input Resolver Core and Signal Contract (ADR-0003, ADR-0006)
Core:
  9. ADR-0009 Enemy Entity, Roster and Combat API (ADR-0001, ADR-0005)
  10. ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry (ADR-0004, ADR-0008, ADR-0009)
Presentation:
  11. ADR-0011 Battle Field Rendering and Draw-Call Budget (ADR-0009, ADR-0010)

The proposed edges form no cycle.

### GDD Revision Flags
None. Phase 5b checks GDDs against HIGH RISK engine findings in ADRs, and
there are no ADRs. Systems index left unchanged.

### Engine Compatibility Issues
Engine: Godot 4.7.2
ADRs with Engine Compatibility section: 0 / 0
Deprecated API references: none (no ADRs)
Stale version references: none (no ADRs)
Post-cutoff API conflicts: none (no ADRs)

**Engine validation: NOT ASSESSED** for the ADR class. The godot-specialist
consultation was skipped: it reviews ADR engine claims, and none exist. The
engine reference is unchanged since the first review, so that review's advisory
list (stretch defaults, mouse device ID, dual focus, line feather, FileAccess
return values, unverified event order) still stands, and `architecture.md`
carries each one as QQ-01 to QQ-06, QQ-15 and QQ-17.

### Architecture Document Coverage
`docs/architecture/architecture.md` v2 checked against the 8 GDDs and the
systems index.

**Clean:**
- All 22 systems in the index appear in the layer map. The 14 without a GDD
  are reserved slots with named seams. No orphaned architecture.
- Every one of the 121 requirements maps to one proposed ADR.
- The data flow sections (frame, tick, signal, init, retry, pause, fatal,
  telemetry) cover every cross-system route the GDDs define, and the cross-GDD
  B1 fix matches B4 and the Commands row (bots call commands headless).

**Stale against the revised GDDs (fix before the ADRs cite them):**
1. **B10 says the HUD's reads do not exist yet.** It names a Hero "cooldown
   total" and says `wave_index()`, `got_through_by_type()` and `chip_state()`
   are not in their owners' GDDs. After the blocker fixes there is no cooldown
   total: the HUD reads Burst `cooldown` through the accessor (HUD Rule 12).
   `wave_index()` and `got_through_by_type()` are defined in Enemy & Wave
   Rule 14, and `chip_state()` in Tower Rule 17. The B7 and B8 comments
   ("requested by the HUD") are stale the same way.
2. **B9 is missing two injections.** The builder now passes the Burst's ID to
   HudLogic (Flow Dependencies, HUD Rule 12) and `wave_index()` to Flow for the
   result (Flow Rule 15). Neither row exists. HudLogic also needs the accessor
   listed among its inputs.
3. **Data Flow 9 (telemetry)** says the gesture log listens to resolver signals
   only. Input Rule 13 now also has it listen to `tower_upgraded` and read
   `chip_state()`. That puts a Feature-layer read inside a harness ADR-0008
   owns; ADR-0008 or ADR-0010 must say which.
4. **Counts.** Document Status, the Traceability Coverage Check and Required
   ADRs say 120 requirements; it is 121. ADR-0009 covers 17, not 16.
5. **Review state.** v2 records that neither TD-ARCHITECTURE nor
   LP-FEASIBILITY re-reviewed it after the v1 CONCERNS were applied.

---

### Verdict: FAIL

All 121 requirements are uncovered, including 53 Foundation and 45 Core.
Cross-ADR conflicts and engine validation are **NOT ASSESSED** (no ADRs).
Architecture document coverage ran this time and found the document sound in
shape but stale in five places. FAIL outranks the rest.

This is the expected state before any ADR is written. It blocks
`/gate-check pre-production`.

### Blocking Issues (must resolve before PASS)
1. No ADRs for ADR-0001 to ADR-0008 (53 Foundation requirements).
2. No ADRs for ADR-0009 and ADR-0010 (45 Core requirements); the Combat, Enemy
   & Wave, Hero and Tower GDDs name them as prerequisites for their first story.
3. Every ADR must reach `Accepted`, not `Proposed`, before coverage counts.

### Should fix (not blocking)
4. Update `architecture.md` B7 to B10, Data Flow 9 and its counts to match the
   revised GDDs (Architecture Document Coverage items 1 to 4).
5. Run `/review-all-gdds consistency` to close the re-check the blocker fixes
   left pending.

### Required ADRs
In order: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006,
ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011.
