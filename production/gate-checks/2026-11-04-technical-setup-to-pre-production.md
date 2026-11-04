## Gate Check: Technical Setup → Pre-Production

**Date**: 2026-11-04
**Checked by**: gate-check skill (run by the producer agent, automation: autonomous)
**Config**: workflow `standard` (project.yaml), review_mode `full`, qa.level `full`, team.size `studio`, performance.enforce `warn` (default), testing.strict unset (Logic and Integration default to BLOCKING). project.stage reads `Systems Design`.

### Precondition finding
`project.stage` is `Systems Design`, and `production/stage.txt` agrees. No Systems Design → Technical Setup gate report exists in `production/gate-checks/` (only `2026-11-01-concept-to-systems-design.md`). This gate was run on request, but the project never formally passed the gate before it. Even a PASS here could not be written as a stage change without first running `/gate-check technical-setup`.

### Required Artifacts (at `workflow: standard`): 9/9 present
- [x] Engine chosen: Godot 4.7.2, GDScript (CLAUDE.md, project.yaml)
- [x] Project config populated: engine, naming, performance set in project.yaml (note: `commands.build` is still `[TO BE CONFIGURED]`; no export preset)
- [x] Art bible: required only if visual-asset stories exist; none exist. `design/art/art-bible.md` is present anyway with all 9 sections
- [x] Foundation-layer ADRs: 14 ADRs present, Foundation set ADR-0001, 0002, 0003, 0004, 0005, 0008. **All 14 are Proposed**
- [x] Engine reference docs: `docs/engine-reference/godot/` (VERSION, breaking-changes, deprecated-apis, current-best-practices, modules)
- [x] Test framework initialized: `tests/unit/`, `tests/integration/` (empty), gdUnit4 in `addons/`
- [x] CI workflow: `.github/workflows/tests.yml` (has never run)
- [x] Example test: `tests/unit/framework/framework_sanity_test.gd` (never executed)
- [x] `docs/architecture/architecture.md` (70 KB, real content; partly stale, see below)
- [x] `/architecture-review` run: `architecture-review-2026-11-04.md`, `Mode: full`, verdict CONCERNS

Recommended at `standard` (absent would be CONCERNS):
- [x] `docs/architecture/requirements-traceability.md`: present (74 TRs, 71 covered by Proposed ADRs, 3 Partial, 0 gaps)
- [x] `design/accessibility-requirements.md`: present, tier Standard (phased), status "awaiting user confirmation"
- [x] `design/ux/interaction-patterns.md`: present
- [ ] UX spec started for at least one screen: **none** (`design/ux/` holds only the pattern library)

Outside the gate checklist, from `artifact-check.sh --phase technical-setup`: `control-manifest` ABSENT (catalog step marked required). It cannot be made until ADRs are Accepted.

### Quality Checks
- [x] Architecture covers rendering, input, state (ADR-0012, ADR-0006, ADR-0002)
- [x] Naming conventions and performance budgets set
- [~] Accessibility tier defined (Standard), but marked as awaiting user confirmation
- [ ] UX spec started: none (recommended at standard: CONCERNS)
- [x] Engine Compatibility section: 14/14 ADRs, all name 4.7 or 4.7.2
- [x] GDD Requirements Addressed section: 14/14 ADRs
- [x] No deprecated API use (full-mode review engine audit)
- [x] Knowledge Risk flagged on every ADR (13 HIGH, 1 MEDIUM/HIGH)
- [x] HIGH-risk engine domains addressed in architecture.md Engine Knowledge Gap Summary
- [~] Zero Foundation gaps: 0 gaps, but every covering ADR is Proposed, none Accepted
- [x] ADR circular dependency: `adr-dep-graph.sh` shows 14 ADRs, 48 edges, no CYCLE, no NO_DEPS_SECTION, no UNFILLED_DEPS (the undeclared edges the review flagged for ADR-0006 and ADR-0014 are now declared)
- [?] Tests run: **NOT ASSESSED.** `commands.test` points at `/Applications/Godot.app/...`; no such path or any Godot binary exists here. CI has never run. The example test has never executed, so "framework is functional" is unproven
- [x] Engine specialist consultation: run 2026-11-04 by `godot-specialist` over all 14 ADRs, after the review (API misuse: none found; ADR-0014 sourced from the 4.7.2 class reference; signal name synced). The review's own specialist pass did not run.
- system_overrides: all 8 keys match a GDD stem. `docs/consistency-failures.md` does not exist.

### Director Panel Assessment
Panel at `workflow: standard`: technical-director and producer.

Technical Director: **CONCERNS** (TD-PHASE-GATE, run 2026-11-04 after the first pass). The architecture is sound for this gate: 8 of 8 MVP systems mapped, 74 TRs with 0 gaps, an acyclic ADR graph, a clean sim and shell split that lets most checks run headless, and a per-tick sim budget now owned by ADR-0012 (sim at most 3 ms per 1-tick frame). The Foundation decisions (ADR-0001, 0002, 0003, 0004, 0005, 0008) are complete in content, and the Proposed state is the user's choice with a clear exit in `production/qa/engine-verification-plan.md`. Not NOT READY, because the first Pre-Production work is the verification itself. Not READY, because: (1) no Foundation ADR is Accepted, so no story may build on them until Run A passes; (2) the toolchain is unproven: no Godot binary, CI never ran, `engine.path` is a macOS path, so Run A cannot start here; (3) the riskiest calls (lifecycle notices, input order, safe area, draw calls) rest on a phone run with no device or date named; (4) `architecture.md` contradicts itself: its ADR Audit says every ADR passed an engine-specialist check, while the review and the ADRs' own Decision Makers say none was run. This seat cannot clear the test-run item.

Producer: **CONCERNS.** Scope for Pre-Production is ordered (engine verification Run A then Run B, accept ADRs in graph order, then prototype). Risks: no runnable engine in this environment, so every ADR acceptance is blocked on a machine with Godot 4.7.2 and a phone; no milestone or sprint plan yet (not expected before Production); the formal stage is two steps behind this gate.

Panel: 2 of 4 (`modes.workflow: standard`, set on its own). Creative and Art perspectives not consulted. Set `modes.workflow: full` for the full panel.

### Blockers (keep the stage from advancing)
1. **NOT ASSESSED: test suite never ran.** Install Godot 4.7.2, fix `engine.path`/`commands.test`, run the suite locally or push to trigger CI, and confirm the sanity test passes.
2. ~~NOT ASSESSED: TD-PHASE-GATE did not run.~~ Cleared 2026-11-04: TD-PHASE-GATE returned CONCERNS (see Director Panel).
3. **Prior gate never passed.** Run `/gate-check technical-setup` first; the stage is `Systems Design`.

### Concerns
1. All 14 ADRs Proposed; Foundation coverage rests on unaccepted ADRs. Clear: run `production/qa/engine-verification-plan.md` Run A and Run B, then `/architecture-decision accept` in graph order.
2. No UX screen spec. Clear: `/ux-design` for the Battle HUD.
3. Accessibility tier not confirmed by the user. Clear: user confirms the tier in `design/accessibility-requirements.md`.
4. Traceability matrix still lists 3 Partial rows (TR-wave-004, TR-hud-006, TR-hud-013) though ADR-0009, 0012, 0014 were amended after the review. The fixes were not re-reviewed. Clear: `/architecture-review coverage`.
5. `architecture.md` stale: ADR Audit says "Existing ADRs: none" and the coverage check says 70 provisional (lines ~601-610). Clear: refresh those sections.
6. ~~Engine specialist pass not run.~~ Cleared: `godot-specialist` checked all 14 ADRs on 2026-11-04 (see the checklist line above).
7. Control manifest absent (blocked on Accepted ADRs). Clear: `/create-control-manifest` after acceptance.
8. `commands.build` unset, no export preset.
9. (TD) ~~`architecture.md` ADR Audit claims an engine-specialist check that the review says was never run.~~ Cleared: the check ran after the review; the audit line now names who ran it and what it covered.
10. (TD) Run B has no named device, owner or date, and nine ADRs wait on it, the Foundation ADR-0002, 0003, 0004 and 0008 among them. Clear: name the low-end Android model and book the session before any Input or HUD story.
11. (TD) ~~`project.yaml` `draw_call_limit: 60` differs from ADR-0012's limit of 12.~~ Not a conflict: 60 is the whole-frame budget and 12 (16 with a modal) is the field and HUD share of it, as Battle HUD states ("at most 12 of 60") and ADR-0012 line 56 quotes.

### Verdict: CONCERNS
Precedence: no FAIL condition; CONCERNS outranks NOT ASSESSED. One required check (tests run) is still NOT ASSESSED after TD-PHASE-GATE returned CONCERNS, so the stage override is **not offered** (Section 6). Stage not changed.

Chain-of-Verification: 5 questions checked (2 by tool: re-read architecture.md lines 601-610 and the traceability Partial rows; re-checked for a Godot binary) — verdict unchanged.
