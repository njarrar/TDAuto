# Gate Check: Technical Setup → Pre-Production

**Date**: 2026-11-05
**Checked by**: gate-check skill (`/gate-check pre-production`)
**Workflow tier**: full (rigor: full). `qa.level`: full. Review mode: full.
**Recorded stage at check time**: Systems Design (`project.yaml`, `production/stage.txt`)

### Required Artifacts: 10/13 present
- [x] Engine chosen: Godot 4.7.2 (CLAUDE.md, `project.yaml`)
- [x] Project config populated: `project.yaml` naming and performance blocks set
- [x] Art bible at `design/art/art-bible.md`, sections 1 to 9
- [x] At least 3 Foundation ADRs: 11 ADRs, all Accepted (`docs/architecture/adr-0001` to `adr-0011`)
- [x] Engine reference docs: `docs/engine-reference/godot/` (plus `probe-results.md`, verified on 4.7.2 headless)
- [x] Test framework folders: `tests/unit/`, `tests/integration/` (placeholders only)
- [x] CI workflow: `.github/workflows/tests.yml`
- [ ] **At least one example test file**: MISSING (both test folders hold only `.gdignore_placeholder`)
- [x] Master architecture: `docs/architecture/architecture.md` (v11)
- [x] Traceability index: `docs/architecture/requirements-traceability.md` (124 rows)
- [x] Architecture review run: `docs/architecture/architecture-review-2026-11-05.md` (Mode: full, CONCERNS)
- [x] `design/accessibility-requirements.md`, tier committed (Standard, touch-adapted, at Alpha)
- [x] `design/ux/interaction-patterns.md`
- [ ] **Control manifest** (`docs/architecture/control-manifest.md`, required for Technical Setup by `.claude/docs/workflow-catalog.yaml`): MISSING

### Quality Checks: 9/10 passing
- [x] Architecture decisions cover rendering, input and state management (ADR-0001, 0003, 0004, 0008, 0011)
- [x] Naming conventions and performance budgets set (`project.yaml`)
- [x] Accessibility tier defined
- [ ] **At least one screen's UX spec started**: MISSING (`design/ux/` holds only the pattern library)
- [x] All ADRs have an Engine Compatibility section stamped 4.7.2
- [x] All ADRs have a GDD Requirements Addressed section
- [x] No ADR uses a deprecated API (review 2026-11-05, engine audit)
- [x] HIGH risk engine domains addressed or flagged as open questions (`architecture.md` engine gap summary)
- [x] Zero Foundation gaps (124 TRs: 119 covered, 5 partial, 0 gaps)
- [x] ADR dependency graph: 11 ADRs, no `CYCLE:` line, no `NO_DEPS_SECTION`, no `UNFILLED_DEPS`
- [x] Engine validation: all ADRs on 4.7.2; post-cutoff APIs flagged; no stale version references

### Director Panel Assessment (4 of 4, `workflow: full`)

Creative Director: NOT READY
  No screen UX spec. The Systems Design gate was skipped and 5 of 8 MVP GDDs are not Approved (Input and Battle HUD carry Pillars 4 and 1). Concerns to plan as prototype questions: design theory pass not re-run (D1 to D13), fragile 25 to 30% hero share band, split commander pacing, bot gates with no thumb limit, thumb reach for top-of-field arcs.

Technical Director: NOT READY
  Architecture ready (11 Accepted ADRs, no cycle, 0 gaps). Blockers: no example test through CI, no control manifest, no UX spec. Concerns: ADR-0003 S0a interactive checks not run, device proofs not run (5 partial TRs), Mobile Platform GDD missing, stage mismatch, gdUnit4 6.2.0 vs 6.2.2 to settle in the CI story.

Producer: CONCERNS
  Stage order broken (no Systems Design → Technical Setup record). No example test, UX spec or control manifest. Schedule drift: about 99 documentation commits since 2026-11-01 and no code in `src/`, against a 6 to 7 day MVP plan. Recommends no new ADRs or review passes unless code or a device result forces one, and a short ordered Pre-Production task list.

Art Director: CONCERNS
  No screen UX spec; nothing rendered yet (make a static mock frame first); art bible header and AD-ART-BIBLE sign-off out of date; defeat's "desaturated 60%" has no drawing method without shaders; path corner rule differs between §6, §8 and ADR-0011; the white hero-hit flash may outshine the hero; rapid-fire tower has no shape (confirm it is out of MVP); device visual checks still due.

### Blockers
1. **Systems Design → Technical Setup gate never passed.** The recorded stage is Systems Design. Run `/design-review` on at least `design/gdd/input-gesture-resolver.md` and `design/gdd/battle-hud.md`, then `/gate-check technical-setup`.
2. **No example test file.** Commit one passing gdUnit4 test under `tests/unit/`, with `[gdunit4] report/godot/push_error=true` in `project.godot`, and get one green CI run.
3. **No control manifest.** Run `/create-control-manifest` from the eleven Accepted ADRs.
4. **No screen UX spec.** Run `/ux-design` for the battle HUD.

### Recommendations
- After the blockers: one desktop and phone device session (ADR-0003 S0a and S0b, ADR-0011 M9a and M9b, ADR-0004 V13, ADR-0009 P2), then a static mock frame for the art direction.
- Settle gdUnit4 6.2.0 or 6.2.2 inside the CI story.
- Write the Mobile Platform GDD before any mobile-lifecycle story (closes TR-input-006).
- Art bible: refresh the header and sign-off; settle defeat desaturation, the path corner rule, the hero-hit flash brightness and the rapid-fire shape.
- Producer's process rule: no new ADRs or review passes unless code or a device result forces one.

### Verdict: FAIL
Three required items are missing (example test, control manifest, screen UX spec) and two directors returned NOT READY. The stage stays at Systems Design.

Chain-of-Verification: 5 questions checked (missing test file, UX spec and control manifest re-checked on disk; blockers separated from recommendations; minimal path to pass named) — verdict unchanged.
