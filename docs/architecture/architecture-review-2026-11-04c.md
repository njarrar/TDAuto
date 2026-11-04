## Architecture Review Report
Date: 2026-11-04 (third run that day)
Mode: full
Workflow: full
Engine: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D)
GDDs Reviewed: 8 system GDDs (systems index and game concept read for context; the two `gdd-cross-review-*` files are review reports and add no requirements)
ADRs Reviewed: 11 (ADR-0001 to ADR-0011, all Proposed)
Reviewer: technical-director, independent of the ADR authors. Automation: autonomous (no questions asked; decisions logged below).

Reviewed-Content-Hash: docs/architecture/adr-0001-app-lifecycle-composition-root-and-fatal-path.md b3a558c78e3a64a988e6b4728dd18d3da8d0057f
Reviewed-Content-Hash: docs/architecture/adr-0002-catalogue-storage-format-manifest-and-validation.md 3022562a8059df78930552a6b988cb79875c2783
Reviewed-Content-Hash: docs/architecture/adr-0003-input-adapter-display-stretch-and-platform-lifecycle.md 471fc145a787a2b552a6d4e7ec6810836f18701c
Reviewed-Content-Hash: docs/architecture/adr-0004-fixed-tick-clock-tick-order-frame-order-and-determinism.md 226687270f2b89e15d2aecffe81ff4472e436442
Reviewed-Content-Hash: docs/architecture/adr-0005-stat-accessor-and-read-context-contract.md 8615a16b0928c1f13aa0d9be7a8cd98958d9d0c5
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-signal-contracts-and-view-allowlist.md 80cd99321129cdec8b4d7cbd7f0f0f0d57ad95b1
Reviewed-Content-Hash: docs/architecture/adr-0007-headless-test-harness-gdunit4-and-layer-lint.md 65887b453dfabece74509511bf8775e46197f663
Reviewed-Content-Hash: docs/architecture/adr-0008-input-resolver-core-and-signal-contract.md bc0ae0b86e62b339a85736a876223b20d3395a1f
Reviewed-Content-Hash: docs/architecture/adr-0009-enemy-entity-roster-and-combat-api.md 948de35b447da0dfdca9169eb0cce52073197ef7
Reviewed-Content-Hash: docs/architecture/adr-0010-sim-input-split-command-result-codes-and-dev-telemetry.md 3fa85f8dba73047c57ac787a0200c9a0f48c04aa
Reviewed-Content-Hash: docs/architecture/adr-0011-battle-field-rendering-and-draw-call-budget.md 2ab5a5acf6a1680766148fe548ceff920e6954ba
Reviewed-Content-Hash: design/gdd/battle-hud.md 172cff5baf40a0c0edeab9f009d36598cc22cae1
Reviewed-Content-Hash: design/gdd/combat-damage.md bad2d9173d91b32993e7ddc7b48e037cd6da88e7
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md f1a5d2eda70875aa6125487ab162f6f19ab16ebf
Reviewed-Content-Hash: design/gdd/enemy-wave.md 2b6fdb55994220aa0286a7ca4afa29089cb40456
Reviewed-Content-Hash: design/gdd/game-concept.md f6a170aa9c3f4bb23b271cee9616a605f88d4f3f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md a1e5ec8bcca74663693a3abd6cb45c44ca1a60c7
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md 5a40dd61c36f3a56fc886d773347673fe38878c0
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-04.md dc8dc921f08eaa3bf13ec9938c43e751552deaf5
Reviewed-Content-Hash: design/gdd/hero-system.md 5aacd208842b2198c53c791eeeea945a80111d6f
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 06b928eaf7248e4e7196bb310dcd951fa7cf251c
Reviewed-Content-Hash: design/gdd/systems-index.md 07c5cd3263f0885ba45ad318caf1119cac81eaa6
Reviewed-Content-Hash: design/gdd/tower-system.md 8e3925bb61c5c2a291cd4920f8c90fda2685f3e6
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml de1cb6681d7fc1e11de1ddc2e95e04bad6f9f43a
Reviewed-Content-Hash: docs/architecture/architecture.md af13b4091155785a921440c2a393091d4910e17f
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
Reviewed-Content-Hash: project.yaml 0e9e0b4ae6b0f195bb7aa7c062a5d43698a74c8b
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

Not stamped: `docs/consistency-failures.md` (no such file).

---

### Freshness Check

Prior report: `architecture-review-2026-11-04b.md` (Mode full, Workflow full, 0 ADRs). It does not cover this run: all 11 ADRs are NEW since it, and the TR registry, `architecture.md`, `project.yaml`, the systems index and 9 GDDs CHANGED. No UNRESOLVED pattern. Full re-run done as asked. Engine reference and this skill's files are UNCHANGED.

### Load Summary

- GDDs: 12 files in `design/gdd/`; 8 are system GDDs with requirements. GDD edits since the prior report are visual detail only (battle-hud.md and tower-system.md chip, ring, refusal cue and Reduce Motion rows); they add no technical requirement.
- ADRs: 11 of 11 carry Status, Summary, Engine Compatibility, ADR Dependencies, Decision, GDD Requirements Addressed and Performance Implications. No structural section gap.
- Requirement source: `tr-registry.yaml` v4, 126 entries, all `active`. `registry.sh validate`: 0 duplicate, 0 unknown, 0 status, 0 layout rows.
- Engine reference: VERSION.md, breaking-changes.md, deprecated-apis.md, current-best-practices.md, modules/input.md, ui.md, rendering.md (the modules the ADRs name).

---

### Traceability Summary
Total requirements: 126
Covered by an Accepted ADR: 0
Covered (Proposed): 124 (120 listed in an ADR's GDD Requirements Addressed table; 4 decided in Decision text only)
Partial: 2
Gaps: 0

| GDD | TRs | Covered (Proposed) | Partial |
|-----|-----|--------------------|---------|
| data-config-pipeline.md | 15 | 15 | 0 |
| input-gesture-resolver.md | 16 | 16 | 0 |
| game-state-stage-flow.md | 16 | 16 | 0 |
| combat-damage.md | 14 | 14 | 0 |
| enemy-wave.md | 17 | 15 | 2 |
| tower-system.md | 15 | 15 | 0 |
| hero-system.md | 15 | 15 | 0 |
| battle-hud.md | 18 | 18 | 0 |

By layer: Foundation 47, Core 31, Feature 30, Presentation 18. The full matrix is in `docs/architecture/requirements-traceability.md`.

### Coverage Gaps (no ADR exists)

None. Two partial rows:

- ⚠️ TR-enemy-016: enemy-wave.md, Enemy & Wave (Core). `wave_index()` is 1-based, 0 before any start, never reset. ADR-0001 Decision 5 only lists it as an injected callable. `architecture.md` v4 says ADR-0009 covers it; ADR-0009 never names it. Domain: Core scripting. Engine risk: LOW. Fix: one Decision line and a table row in ADR-0009 (or ADR-0006).
- ⚠️ TR-enemy-017: enemy-wave.md, Enemy & Wave (Core). `got_through_by_type()` counts a leak before `enemy_leaked` fires. ADR-0010 only lists it as a run-log field. `architecture.md` v4 says ADR-0009 covers it; ADR-0009 never names it. Domain: Core scripting. Engine risk: LOW. Fix: add the count-before-emit rule to ADR-0009 Decision 7 or ADR-0006 emit rules.

Structural note (not a gap): four TRs are decided in Decision text but missing from the covering ADR's GDD Requirements Addressed table, although `architecture.md` v4 assigns them there: TR-state-015 (ADR-0001 Decision 4, Battle holds everything strongly), TR-state-016 (ADR-0001 Decision 10, `cancel_input()`), TR-hud-017 (ADR-0011 redraw trigger table, quantised key), TR-hud-018 (ADR-0010 "Build hash and launch ID"). A story-to-ADR lookup by table will miss them. Add the rows on the next ADR revision.

### Cross-ADR Conflicts

No blocking conflict found.

- Data ownership: gold (TowerSim, ADR-0010), Combat counters (ADR-0009), run log and launch ID (ADR-0010), gesture record and TR-input-015 (ADR-0008) each have one owner. ADR-0001's TR-hud-006 row says the launch ID moved out, which matches ADR-0010.
- Integration: signal renames are consistent across ADR-0006 (`waves_completed`) and ADR-0008 (`tapped`, `ground_tapped`, `became_idle`) and `architecture.md` v4.
- Performance: ADR-0004 frame split (input 0.5 ms, ticks 4.0 ms) plus ADR-0011 views and HUD 3.0 ms is 7.5 ms of 16.6 ms. ADR-0009's 2 ms targeting sits inside the tick slice. ADR-0011 HUD 8 to 12 draw calls sit inside the 60-call limit. All numbers are unmeasured.
- Advisory: `architecture.md` v4's Required ADRs "Depends on" column is narrower than the ADRs' own sections for ADR-0009 (ADR adds 0002, 0004, 0006, 0007), ADR-0010 (adds 0001, 0005, 0006, 0007) and ADR-0011 (adds 0001, 0003, 0004, 0006, 0008). The ADR sections are the source; the table is stale.

### ADR Dependency Order

From `adr-dep-graph.sh`: 11 ADRs, 35 edges, no CYCLE, no NO_DEPS_SECTION, no UNFILLED_DEPS.

Foundation (no dependencies):
1. ADR-0001 App Lifecycle, Composition Root and Fatal Path
Depends on Foundation:
2. ADR-0002 Catalogue Storage Format, Manifest and Validation (0001)
3. ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle (0001)
4. ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism (0001, 0003)
5. ADR-0005 Stat Accessor and Read-Context Contract (0001, 0002)
6. ADR-0006 Battle Signal Contracts and View Allowlist (0001, 0004)
7. ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint (0001, 0006)
8. ADR-0008 Input Resolver Core and Signal Contract (0001, 0003, 0004, 0006, 0007)
Core and above:
9. ADR-0009 Enemy Entity, Roster and Combat API (0001, 0002, 0004, 0005, 0006, 0007)
10. ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry (0001, 0004 to 0009)
11. ADR-0011 Battle Field Rendering and Draw-Call Budget (0001, 0003, 0004, 0006, 0008, 0009, 0010)

⚠️ Every dependency is on a Proposed ADR. ADR-0001 gates all ten others; it should be the first to clear its engine runs and be accepted.

### GDD Revision Flags

Engine-derived (Phase 5b):

| GDD | Assumption | Reality (ADR or engine reference) | Action |
|-----|-----------|-----------------------------------|--------|
| input-gesture-resolver.md | `get_display_safe_area()` returns window pixels | Not stated in the pinned reference; ADR-0003 spike S-7 settles it | Revise GDD after S-7 |

GDD sync pending from ADR renames (not engine-derived): `waves_complete` is still used in enemy-wave.md, game-state-stage-flow.md, data-config-pipeline.md, tower-system.md and systems-index.md (ADR-0006). `tap`, `ground_tap` and `idle()` are still used in input-gesture-resolver.md and battle-hud.md, and none of the GDDs uses the new names yet (ADR-0008). Registry texts TR-input-009, TR-enemy-004 and TR-tower-012 carry the same old wording; they follow their GDD and should be revised when the GDD sync lands.

Systems index not changed: this run was told not to edit GDDs, and `systems-index.md` sits with them. Logged decision: report the flag only.

### Engine Compatibility Issues

Engine: Godot 4.7.2. ADRs with an Engine Compatibility section: 11 / 11.

- Version consistency: all 11 name 4.7 or 4.7.2. No stale version.
- Deprecated API references: none used. ADR-0003 names `event.device` only to forbid comparing it to 0, as `deprecated-apis.md` asks. ADR-0002 uses `duplicate_deep()`, the 4.5 replacement.
- Post-cutoff APIs: `Dictionary.duplicate_deep()` (ADR-0002), `InputEvent.DEVICE_ID_MOUSE` and `DEVICE_ID_EMULATION` and `Control.get_mouse_filter_with_override()` (ADR-0003), `FileAccess.store_line() -> bool` (ADR-0010), 4.7 unfeathered `CanvasItem` lines (ADR-0011), the 4.7 typed-return override rule (ADR-0001, 0002, 0005 to 0008). No two ADRs assume different things about the same API.
- Stale reference: ADR-0001 and ADR-0004 cite `architecture.md` v3 in References Consulted; v4 is current. LOW.
- Knowledge risk HIGH: ADR-0001, 0002, 0003, 0004. Their NOT SOURCEABLE items (Callable and weakref lifetime, Android export manifest load, touch event order, lifecycle notifications, safe area, input-before-`_process` order, ARM float results) are all open.
- No Godot binary exists in this environment, so no engine run was possible in this review. CI is green on main, but CI runs the headless suite, not the device and export runs these ADRs list as blocking.

### Engine Specialist Findings

NOT ASSESSED: the godot-specialist consultation was not run, because this run was told not to spawn agents. The audit above stands alone. Run it before acceptance of the HIGH-risk ADRs.

### Architecture Document Coverage

- All 8 MVP systems in `systems-index.md` appear in `architecture.md` v4 layers; the 14 Vertical Slice and Alpha systems sit as reserved slots. No orphaned architecture.
- Data flow and API boundaries match the ADR signal names (B2, Data Flow 3, `waves_completed`).
- Stale claims in `architecture.md` v4: it says 126 of 126 covered, 0 partial (this review finds 2 partial); its Traceability section says the matrix was built by the 2026-11-03 review; its layer and risk counts cover only the first 120 TRs; its "Depends on" column is narrower than the ADRs (see Conflicts). Report only; not edited.

---

### Verdict: CONCERNS

No gap and no blocking conflict. Not PASS because: 0 of 126 requirements rest on an Accepted ADR (all 11 are Proposed, each blocked by engine runs that cannot happen without a Godot binary and a device), 2 Core requirements are partial, and the engine-specialist check was not run.

### Blocking Issues (must resolve before PASS)

None at FAIL level. To reach PASS:
1. Run each ADR's blocking engine runs, then accept through `/architecture-decision accept ADR-NNNN`, ADR-0001 first.
2. Close TR-enemy-016 and TR-enemy-017 in ADR-0009 (or ADR-0006) and add table rows for TR-state-015, TR-state-016, TR-hud-017 and TR-hud-018.
3. Run the godot-specialist consultation.

### Required ADRs

No new ADR is needed. Revisions only: ADR-0009 (two partial TRs), ADR-0001, ADR-0010, ADR-0011 (missing table rows).

### Files Written

- `docs/architecture/architecture-review-2026-11-04c.md` (this report)
- `docs/architecture/requirements-traceability.md` (refreshed: 126 rows, replaces the 125-row index)
- `docs/architecture/tr-registry.yaml`: no change. No new requirement was found, and no text was revised (append-only run).

### Logged Decisions (autonomous)

- Freshness: prior report does not cover this run; full re-run.
- Implicit coverage graded Covered (Proposed), not Partial, where the ADR Decision text decides the requirement.
- Registry wording drift reported, not edited, since the GDDs still carry the old names and this run is append-only.
- Systems index not edited (GDD folder out of bounds for this run).

---

### Note (2026-11-04, after this review)

- An engine-specialist check of all 11 ADRs did run on 2026-11-04, before this review: it found no removed or deprecated API, and its fixes were applied. The "Engine Specialist Findings" section above did not know of it.
- Then fixed: the missing GDD Requirements Addressed rows (TR-state-015 and TR-state-016 in ADR-0001, TR-hud-017 in ADR-0011, TR-hud-018 in ADR-0010); TR-enemy-016 and TR-enemy-017, now decided in ADR-0009 Decision 7 with table rows; and the stale `architecture.md` v4 claims (coverage line, matrix review, layer counts, "Depends on" column). ADR-0001 and ADR-0004 now cite `architecture.md` v4.
- The verdict above is unchanged.
