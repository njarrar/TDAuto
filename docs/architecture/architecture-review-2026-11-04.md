## Architecture Review Report
Date: 2026-11-04
Mode: full
Workflow: standard
Engine: Godot 4.7.2 (GDScript, Mobile renderer, 2D)
GDDs Reviewed: 8 system GDDs (of 11 files in `design/gdd/`; `game-concept.md`, `systems-index.md` and `gdd-cross-review-2026-11-04.md` are not system GDDs)
ADRs Reviewed: 14 (ADR-0001 to ADR-0014, all Proposed)
Reviewer: technical-director, independent of the ADR authors
Automation: autonomous. Each choice below took the recommended option and is noted where made.

Reviewed-Content-Hash: docs/architecture/adr-0001-simulation-and-shell-boundary.md 85c3a75d2fc2ab7e94fa3c51d5f0a644a39a9304
Reviewed-Content-Hash: docs/architecture/adr-0002-app-lifecycle-and-composition.md 39415c1a14c2a6400da428b4b4572e6231f42755
Reviewed-Content-Hash: docs/architecture/adr-0003-fixed-tick-time-and-determinism.md 34a4cfbe62663c76c3a7c2c667f3ebae53f95fc8
Reviewed-Content-Hash: docs/architecture/adr-0004-catalogue-format-loader-validator-stat-accessor.md 44238edf32f84ea8471b182f32975e580ad2a9b1
Reviewed-Content-Hash: docs/architecture/adr-0005-signal-and-command-contracts.md 786b63c2500e640336e58e00cdb7d8af5c2c9d68
Reviewed-Content-Hash: docs/architecture/adr-0006-input-adapter-and-resolver-integration.md f13554ded0752fe9fdc002a7a66c5cfdf9617487
Reviewed-Content-Hash: docs/architecture/adr-0007-combat-data-model.md d44d42f9eb9a4673f8af4ef395d5ec85a2516e7a
Reviewed-Content-Hash: docs/architecture/adr-0008-stretch-mode-safe-area-and-the-field.md aef9c5bf7fca833f711ff5de1f7d55ce7b45f0b7
Reviewed-Content-Hash: docs/architecture/adr-0009-enemy-roster-position-cache-and-view-pooling.md 24b81738257f5a41e46b2ae4d986e2321c82d17d
Reviewed-Content-Hash: docs/architecture/adr-0010-tower-system.md 807afd3d937b0ba1ea0a7a0c285942894c6e3223
Reviewed-Content-Hash: docs/architecture/adr-0011-hero-system.md 9db45c888b7fade377fe2be937ebf4a121d761ff
Reviewed-Content-Hash: docs/architecture/adr-0012-field-and-hud-rendering-and-performance-budget.md 6dc391d74111f4e840801b3692e4d845941b63bf
Reviewed-Content-Hash: docs/architecture/adr-0013-content-test-and-bot-harness.md 1aed899d8486d92d40c1aa31e4ba1dd6f987ce4d
Reviewed-Content-Hash: docs/architecture/adr-0014-debug-logs.md bdc349fa7bd1a8f2031898ab8d971593cc523fa9
Reviewed-Content-Hash: design/gdd/battle-hud.md 1eba9f2a845d6ce42bb86933ea80e2b8df91843d
Reviewed-Content-Hash: design/gdd/combat-damage.md 6910a14a05b3b8a06bc71dda8c1d467de9c1ce0a
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 19f4f8fe91c76e5a7a198d308ce946687ad18755
Reviewed-Content-Hash: design/gdd/enemy-wave.md 5f7eb24177d9f6c177e70792b0632dc5bd66d0c4
Reviewed-Content-Hash: design/gdd/game-concept.md ed25cb702da175ffd4e9fbebb4a42b147cbffa0d
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 047ffe060621aaae4d3c223a6beebfed71a5f4a7
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-04.md 8b51c681dfa837a6bcd6adf98fb8d538d5e2e92e
Reviewed-Content-Hash: design/gdd/hero-system.md 8de82a0b3ec56d02879bbcccbff41e04b7c05336
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md def0dddb6e370a1c954ce16745765bae8e0bf791
Reviewed-Content-Hash: design/gdd/systems-index.md 813faf7bbdcd54277c1075fcbd537fe98abcf4d6
Reviewed-Content-Hash: design/gdd/tower-system.md c4268049729f58cbbbe4e164760f2d46720dc6c6
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 1532696b171cd55474a8834108934a334ea700f9
Reviewed-Content-Hash: docs/architecture/architecture.md 45eea45062f2725f24e3882b5eb39520be455bba
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
Reviewed-Content-Hash: project.yaml 83a28e776a84ffa9bdf08c541ed48abd5b36ad1a
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

(`docs/consistency-failures.md` does not exist and is not stamped.)

---

### Load and Freshness

- Freshness check: `RECEIPT: NONE`. No prior `architecture-review-*.md` exists, so this full run carries the first stamps.
- Denominators: 11 files match `design/gdd/*.md`; 8 are MVP system GDDs, all `In Review` in the systems index. 14 ADRs match `docs/architecture/adr-*.md`. Every ADR has `## Status`, `## GDD Requirements Addressed`, `## Engine Compatibility` and `## ADR Dependencies`. No structural gap.
- Systems 9 to 22 in the systems index are Vertical Slice or Alpha and have no GDD yet. They are out of scope for this run.

### Requirements Extraction (Phase 2)

- `tr-registry.yaml` held 0 entries. `architecture.md` held 70 provisional IDs.
- Every provisional row matched its GDD by intent, and no registry entry held its ID, so all 70 keep their numbers and are now permanent. No renames.
- 4 new requirements, each a GDD rule that an ADR already cites but the baseline left out: TR-input-008 (adapter contract), TR-wave-010 (Rule 14, roster and targets), TR-wave-011 (field scale floor of 0.667 dp per unit), TR-hud-014 (Rule 10, frame order).
- Method note: extraction reused the baseline (written from the same GDDs today) and checked it against every GDD's "Becomes an ADR" asks and every GDD rule the ADRs cite. GDD edits after the baseline (commit 8905c49: data, input, HUD) changed wording, not intent.

### Traceability Summary

Total requirements: 74
Covered by an Accepted ADR: 0
Covered by a Proposed ADR: 71
Partial: 3
Gaps: 0

Full matrix: `docs/architecture/requirements-traceability.md`.

Partial rows:
- TR-wave-004 (bad-speed guard): no ADR names it. Fix in ADR-0009 (move step) or as a schema rule in ADR-0004.
- TR-hud-006 (debug run log): ADR-0014 leaves the game build hash and launch ID NOT SOURCEABLE; HUD Rule 19 needs both.
- TR-hud-013 (16.6 ms frame): no ADR sets a per-tick sim CPU budget. See the performance finding below.

### Coverage Gaps (no ADR exists)

None.

### Cross-ADR Conflicts

No blocking conflict. No two ADRs claim the same data, define the same interface two ways, or order initialisation two ways. Shared rows are split cleanly (TR-input-003: ADR-0006 adapter, ADR-0002 pause; TR-wave-008: ADR-0009 pool contents, ADR-0012 drawing).

Concerns (not blocking):

1. **Performance budget, ADR-0003 vs ADR-0007 vs ADR-0012.** ADR-0003 allows `MAX_TICKS_PER_FRAME = 6` and says "the tick budget is set by ADR-0007 and ADR-0012". ADR-0007 owns only targeting (about 2 ms for 400 checks, unverified). ADR-0012 measures the whole frame but sets no sim share. Worst case: 6 x 2 ms = 12 ms of targeting alone in a 16.6 ms frame. Nobody owns the per-tick sim budget. Options: (a) ADR-0012 adds a per-tick sim line (for example 1.5 ms per tick, 9 ms at the clamp) and the phone run measures it; (b) ADR-0003 lowers the clamp. Recommended: (a).
2. **Undeclared dependency edges.** ADR-0006's Ordering Note says it holds only under ADR-0008's stretch rules, but ADR-0006 does not list ADR-0008 in Depends On. ADR-0014 says ADR-0002 and ADR-0006 feed it but lists only ADR-0001. ADR-0013's Ordering Note says ADR-0003, 0004, 0010 and 0011 are "not listed as dependencies", yet its Depends On lists them. The graph has no cycle either way, but the order below is right only if these edges are real.
3. **Verification coupling, ADR-0009 and ADR-0012.** ADR-0012 depends on ADR-0009, while ADR-0009's view-pool half waits on ADR-0012's phone run. Not a cycle, but ADR-0009 cannot be fully accepted from a desktop run alone. `production/qa/engine-verification-plan.md` already splits it (sim half in Run A, pool in Run B).

### ADR Dependency Order

From `.claude/scripts/adr-dep-graph.sh`: 14 ADRs, 45 edges, no `CYCLE`, no `NO_DEPS_SECTION`, no `UNFILLED_DEPS`.

Foundation (no dependencies):
1. ADR-0001 Simulation and Shell Boundary

Depends on Foundation:
2. ADR-0002 App Lifecycle and Composition (0001)
3. ADR-0003 Fixed Tick, Time and Determinism (0001)
4. ADR-0014 Debug Logs (0001; see concern 2)
5. ADR-0004 Catalogue Format, Loader, Validator and Stat Accessor (0001, 0002, 0003)
6. ADR-0005 Signal and Command Contracts (0001, 0002, 0003)
7. ADR-0006 Input Adapter and Resolver Integration (0001, 0002; see concern 2)
8. ADR-0008 Stretch Mode, Safe Area and the Field (0001, 0002)

Core and Feature:
9. ADR-0007 Combat Data Model (0001, 0003, 0005)
10. ADR-0009 Enemy Roster, Position Cache and View Pooling (0001, 0003, 0004, 0005, 0007)
11. ADR-0010 Tower System (0001, 0003, 0004, 0005, 0006, 0007)
12. ADR-0011 Hero System (0001, 0003, 0004, 0005, 0006, 0007)

Presentation and tooling:
13. ADR-0012 Field and HUD Rendering and Performance Budget (0001, 0002, 0003, 0008, 0009, 0011)
14. ADR-0013 Content Test and Bot Harness (0001, 0003, 0004, 0005, 0010, 0011)

Unresolved dependencies: every edge points at a Proposed ADR, so no ADR can be safely implemented until the ones below it are Accepted. This is the known state.

### Acceptance Status (reported, not changed)

- All 14 ADRs are Proposed by the user's choice on 2026-11-04. This review accepts none.
- Each ADR lists engine checks that block acceptance. Five need a desktop Godot or CI run: ADR-0001, 0005, 0007, 0009, 0013. Nine need a phone run: ADR-0002, 0003, 0004, 0006, 0008, 0010, 0011, 0012, 0014.
- Two of the five also carry a phone item: ADR-0007 (the 400-check targeting time) and ADR-0009 (the view-pool draw cost). Their desktop checks are enough only for the sim half.
- No Godot binary exists in this environment (`project.yaml` points at a macOS path), so none of the checks could run here.

### GDD Revision Flags

These GDD statements conflict with ADR-0006 (HIGH knowledge risk; its `_input` order is sourced from `Viewport.push_input`) or ADR-0002. Revise before Input stories start.

| GDD | Assumption | Reality (ADR) | Action |
|-----|-----------|---------------|--------|
| input-gesture-resolver.md, Interactions, Battle HUD row | "its result and Paused screens are Controls that consume their own events before the adapter" | ADR-0006: the adapter reads `_input`, which runs before Controls; modal taps are blocked by `set_modal()`. `battle-hud.md` Rule 2 already says this | Revise GDD |
| input-gesture-resolver.md, "Becomes an ADR" paragraph | "the adapter, not Game State stories, owns the lifecycle notifications" | ADR-0002 and ADR-0006: AppRoot owns them and calls `adapter.cancel()`. The same GDD's Interactions row already says so, so the GDD contradicts itself | Revise GDD |
| input-gesture-resolver.md, same paragraph | "the adapter runs with `PROCESS_MODE_ALWAYS`" and "a mouse pointer index that cannot collide with touch index 0" | ADR-0002: the tree is never paused. ADR-0006: touch only; mouse is emulated as touch | Revise GDD (these were open questions; mark them answered) |
| data-config-pipeline.md, "Deliberately not built for MVP" | "Spreadsheet or JSON import pipelines" | ADR-0004 makes JSON the storage format (no import step). Not a true conflict, but it reads as one | Reword |

Systems index: the recommended step is to set `input-gesture-resolver.md` to `Needs Revision`. Not applied: this run's brief limits writes to the three output files and forbids GDD edits. The user should apply it or ask for it.

ADR-0006's own "GDD sync required" note is partly stale: `architecture.md` now uses `centre`, `sink`, `set_centre` and `set_enabled`. One shape difference remains: the GDD has `set_centre(id, pos)` on the resolver, the architecture has `HitTarget.set_centre(p)`.

### Engine Compatibility Issues

Engine: Godot 4.7.2. ADRs with an Engine Compatibility section: 14 / 14.

- Version consistency: all 14 name 4.7 or 4.7.2. None is stale.
- Deprecated API references: none used. ADR-0003 names `OS.get_ticks_msec` only as the replaced API and uses `Time`. ADR-0006 forbids `event.device == 0`, as `deprecated-apis.md` advises.
- Post-cutoff APIs: `@abstract` and the 4.7 typed-return override rule (ADR-0001, applied in 0004, 0005, 0010, 0011); `DEVICE_ID_MOUSE` and `mouse_behavior_recursive` (ADR-0006); 4.7 line drawing without a feather (ADR-0012); `FileAccess.store_*` returning `bool` (ADR-0014). No two ADRs assume different things about the same API.
- Sourcing depth: ADR-0009, 0010, 0011 and 0013 did not fetch the live 4.7.2 class reference; they lean on `architecture.md`. ADR-0014 cites `breaking-changes.md` second-hand. All four use little engine API, so the risk is low, but the engine pass should confirm them.
- Engine specialist consultation: **NOT RUN.** This reviewer had no tool to spawn `godot-specialist`. Several ADRs also record that no separate specialist pass was run. Run it before acceptance.

### Architecture Document Coverage

- All 8 MVP systems appear in the layer map. No orphaned architecture: every module maps to a GDD.
- `architecture.md` is stale in four places. Document Status says "ADRs Referenced: none exist yet" and that numbers are placeholders. ADR Audit says "Existing ADRs: none". The Traceability Coverage Check says 0 covered, 70 gaps. The baseline still marks every ID provisional. All four should be refreshed (not done here, per the brief).
- Data flow and API boundaries support every cross-system link in the GDDs, apart from the `set_centre` shape noted above.

---

### Verdict: CONCERNS

Reasons:
1. All coverage rests on Proposed ADRs. This caps the verdict at CONCERNS by rule. The user chose this state on purpose.
2. Three partial requirements (TR-wave-004, TR-hud-006, TR-hud-013).
3. No owner for the per-tick sim CPU budget under the 6-tick clamp.
4. Three undeclared or contradictory dependency notes (ADR-0006, 0013, 0014).
5. Four GDD revision flags, three in `input-gesture-resolver.md`.
6. Engine specialist consultation not run.

Not FAIL: no Foundation or Core requirement is uncovered and no cross-ADR conflict blocks.

### Blocking Issues

None at FAIL level. To reach PASS: run the engine checks (`production/qa/engine-verification-plan.md`, Run A then Run B), accept the ADRs in the order above, and close the concerns listed.

### Required ADRs

No new ADR is required. Amend instead:
1. ADR-0012 (or ADR-0003): per-tick sim CPU budget.
2. ADR-0009 or ADR-0004: bad-speed guard.
3. ADR-0014: source of the game build hash and launch ID.
4. ADR-0006, 0013, 0014: fix the Depends On rows.

### Handoff

Pre-gate checklist: `tests/unit/` and `tests/integration/` present; `.github/workflows/tests.yml` present; `design/accessibility-requirements.md` present; `design/ux/interaction-patterns.md` present.

Next: get a Godot 4.7.2 desktop or CI run (Run A), then the phone session (Run B). Re-run `/architecture-review` after the ADRs are accepted.
