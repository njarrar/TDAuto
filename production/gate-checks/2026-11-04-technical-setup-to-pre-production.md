# Gate Check: Technical Setup → Pre-Production

**Date**: 2026-11-04
**Checked by**: gate-check skill, at `main` bc90be5
**Config**: `modes.rigor: full` → `workflow: full`, `review_mode: full`, `qa.level: full`, `team.size: studio`; `testing.strict` unset (Logic and Integration BLOCKING by default); `performance.enforce: warn`
**Automation**: autonomous. No questions asked. No agents could be spawned in this run.

### Required Artifacts: 13/13 present
- [x] Engine chosen: Godot 4.7.2, GDScript (CLAUDE.md and `project.yaml`)
- [x] `project.yaml` has engine, naming and performance set
- [x] `design/art/art-bible.md`, Sections 1 to 9 present (1 to 4 required)
- [x] 11 ADRs (`adr-0001` to `adr-0011`), Foundation ADRs for scene and app lifecycle (ADR-0001), events (ADR-0006), tick order (ADR-0004), data (ADR-0002). No save/load ADR (see Concern 3)
- [x] `docs/engine-reference/godot/` (VERSION.md, breaking-changes, deprecated-apis, best practices, modules)
- [x] Test roots `tests/unit/` and `tests/integration/` exist; gdUnit4 6.2.0 vendored in `addons/gdUnit4/`
- [x] `.github/workflows/tests.yml` (gdUnit4 action, Godot 4.7.2, `version: installed`)
- [x] Example test: `tests/unit/framework/framework_sanity_test.gd` (2 tests)
- [x] `docs/architecture/architecture.md` (v4)
- [x] `docs/architecture/requirements-traceability.md` (126 rows)
- [x] `/architecture-review` run: `architecture-review-2026-11-04c.md`, `Mode: full`, verdict CONCERNS
- [x] `design/accessibility-requirements.md`, tier Standard (phased), committed; AQ-01 closed by the user 2026-11-04
- [x] `design/ux/interaction-patterns.md` (real content, no placeholders)

`artifact-check.sh --phase technical-setup`: 6 PRESENT, 1 ABSENT (`control-manifest`), 0 NO_CHECK. The control manifest is not on this gate's checklist; the Pre-Production → Production gate first requires it, and it needs Accepted ADRs. Not a finding here.

### Quality Checks
- [x] ADRs cover rendering (ADR-0011), input (ADR-0003, ADR-0008), state and lifecycle (ADR-0001, ADR-0004)
- [x] Naming conventions and performance budgets set (60 fps, 16.6 ms, 60 draw calls, 256 MB)
- [x] Accessibility tier defined and documented
- [x] UX specs started: `hud.md`, `arc-and-chip.md`, `pin-and-aim.md` (HUD status "In Design", user review pending)
- [x] All 11 ADRs have Engine Compatibility with the engine version stamped
- [x] All 11 ADRs have GDD Requirements Addressed
- [x] No deprecated API use (04c engine audit, plus the 2026-11-04 engine-specialist check noted in that report)
- [x] HIGH-risk domains (input, UI and display, GDScript, app lifecycle) addressed in `architecture.md` as NEEDS VERIFICATION, owners named
- [x] Zero Foundation gaps (04c, `Mode: full`: 126 TRs, 0 gaps; Foundation 47)
- [x] ADR dependency graph: 35 edges, no `CYCLE:`, no `NO_DEPS_SECTION`, no `UNFILLED_DEPS`
- [x] Post-cutoff ADRs carry Knowledge Risk HIGH or MEDIUM; ADR-0005 and ADR-0010 LOW with reasons
- [x] All ADRs cite Godot 4.7 or 4.7.2; no stale version
- [x] Tests: CI green on `main` (latest push run: success, 44 s); 2 passed, 0 failed in `framework_sanity_test` per the PR #19 run. Not run locally: `engine.path` is a macOS path and this host has no Godot binary
- [~] See Concerns

### Director Panel Assessment
Panel required: 4 of 4 (`workflow: full`, `review_mode: full`). None could be spawned in this run.

- Creative Director (CD-PHASE-GATE): NOT ASSESSED. Not spawned.
- Technical Director (TD-PHASE-GATE): NOT ASSESSED. Not spawned.
- Producer (PR-PHASE-GATE): NOT ASSESSED. Not spawned.
- Art Director (AD-PHASE-GATE): NOT ASSESSED. Not spawned.

### Blockers
No hard blocker found in artifacts or checks. These NOT ASSESSED items hold the stage; the CONCERNS override is not offered while they stand:
1. **CD-PHASE-GATE not run.** Re-run `/gate-check pre-production` in a session that can spawn `creative-director`.
2. **TD-PHASE-GATE not run.** Same, `technical-director`.
3. **PR-PHASE-GATE not run.** Same, `producer`.
4. **AD-PHASE-GATE not run.** Same, `art-director`.

### Concerns
1. **No ADR is Accepted.** 0 of 126 TRs rest on an Accepted ADR, and every HIGH-risk engine row is still NEEDS VERIFICATION. Kept Proposed by user choice. Clear: run the engine runs in `production/qa/engine-verification-plan.md`, then `/architecture-decision accept ADR-NNNN`, ADR-0001 first.
2. **Architecture review is CONCERNS and partly stale.** Fixes landed after 04c, but no review re-ran, and `requirements-traceability.md` still lists TR-enemy-016 and TR-enemy-017 as Partial. Clear: `/architecture-review full` (or `rtm`).
3. **No save/load ADR.** The checklist names save/load as a Foundation ADR. `architecture.md` defers Save/Load to Vertical Slice with a no-globals rule. Clear: write the ADR before any VS save work, or accept the deferral.
4. **Thin test proof.** Only the 2-test canary; `tests/integration/` holds no test. The gate relied on CI, not a local run. Clear: first real Logic tests in Pre-Production; set `engine.path` for this host if local runs are wanted.
5. **UX specs await user review** (`hud.md` is an autonomous draft). Clear: user review or `/ux-review`.

### Verdict: CONCERNS
Precedence: no FAIL; Concerns 1 to 5 set CONCERNS, which outranks the NOT ASSESSED panel. Stage stays Technical Setup. No stage write was offered or made.

Chain-of-Verification: 5 questions checked (control manifest scope re-read in `gate-production.md`; traceability Partial rows re-grepped; ADR sections re-counted; CI re-queried; save/load re-grepped). Verdict unchanged.
