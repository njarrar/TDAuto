# Gate Check: Technical Setup → Pre-Production (re-run)

**Date**: 2026-11-05
**Checked by**: gate-check skill (`/gate-check pre-production`)
**Workflow tier**: full. `qa.level`: full. Review mode: full.
**Recorded stage at check time**: Technical Setup
**Earlier run**: `2026-11-05-technical-setup-to-pre-production.md` (FAIL). All four of its blockers are closed.

### Required Artifacts: 13/13 present
- [x] Engine chosen: Godot 4.7.2
- [x] Project config populated (`project.yaml`)
- [x] Art bible `design/art/art-bible.md`, sections 1 to 9
- [x] 11 Accepted ADRs covering Foundation systems
- [x] Engine reference `docs/engine-reference/godot/`
- [x] Test folders `tests/unit/`, `tests/integration/`
- [x] CI workflow `.github/workflows/tests.yml`
- [x] Example test `tests/unit/harness/harness_smoke_test.gd` (3 tests; evidence `production/qa/evidence/harness-smoke-2026-11-05.txt`: exit 0, negative controls exit 100)
- [x] `docs/architecture/architecture.md` (v11)
- [x] `docs/architecture/requirements-traceability.md`
- [x] `docs/architecture/architecture-review-2026-11-05.md` (Mode: full, CONCERNS)
- [x] `design/accessibility-requirements.md`, tier committed
- [x] `design/ux/interaction-patterns.md`
- [x] Control manifest `docs/architecture/control-manifest.md` (catalog step)

### Quality Checks: 10/10 passing
- [x] Core systems covered (rendering, input, state)
- [x] Naming conventions and performance budgets set
- [x] Accessibility tier defined
- [x] Screen UX spec started: `design/ux/hud.md`
- [x] All ADRs stamp 4.7.2 Engine Compatibility
- [x] All ADRs have GDD Requirements Addressed
- [x] No deprecated APIs
- [x] HIGH risk engine domains addressed or flagged
- [x] Zero Foundation gaps (119 covered, 5 partial, 0 gaps)
- [x] ADR graph: no CYCLE, NO_DEPS_SECTION or UNFILLED_DEPS
- Test re-run inside this gate was denied by the sandbox; the gate relies on the evidence file from the same commit as the tests.

### Director Panel Assessment (4 of 4)
Creative Director: CONCERNS. Earlier NOT READY reasons closed. HUD 16 dp breaks (H-01 to H-04) need a user call before first render; accessibility review of hud.md owed; Pillar 4 thumb test and Pillar 2 hero share unproven.
Technical Director: CONCERNS. No blockers. No CI run has executed a test yet; gdUnit4 6.2.0 vs 6.2.2; `tools/ci/run_tests.sh` not written; device checks open; Mobile Platform GDD missing.
Producer: CONCERNS. Earlier blockers closed. Schedule drift worse (112 commits, no `.gd` in `src/`); `team.size: studio` vs one part-time developer.
Art Director: CONCERNS. No blockers. Nothing rendered, no font (H-11); art bible header and sign-off stale; defeat desaturation, path corners, hero-hit flash, rapid-fire shape; device visual checks.

### Accepted Risks (user accepted 2026-11-05)
1. Schedule drift: code first; no new ADRs or review passes unless code or a device result forces one; plan for one part-time developer.
2. No CI test run yet: the first PR to main must show 3 tests, before any Logic story closes.
3. gdUnit4 6.2.2 upgrade, `run_tests.sh`, Linux test command.
4. HUD text sizes (N7, H-01 to H-03, H-11 font) via a static mock frame before the first HUD story; pause owner (N9).
5. Pillar 4 thumb test early; hero share logged from the first build; D1 to D13 as playtest questions.
6. Device checks S0a/S0b, M9a/M9b, V13, P1/P2, M3.
7. Mobile Platform GDD before the vertical slice.
8. Art bible fixes listed above.
9. hud.md reviews and `/ux-review` before `/team-ui`.

### First Pre-Production tasks (producer)
1. One green CI run with tests; settle gdUnit4 version.
2. Foundation epics and stories (lifecycle and composition root, catalogue, tick clock).
3. Build them in `src/`, test first.
4. Core stories: input resolver, one wave on a path, one tower, combat damage.
5. One desktop and phone device session.
6. Decide N7 and N9, then a minimal HUD.
7. Playable slice loop that logs hero share; first sprint plan from real story paths.

### Verdict: CONCERNS (risks accepted, stage advanced to Pre-Production)
