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

- Creative Director (CD-PHASE-GATE): CONCERNS. The core fantasy holds in the 8 MVP GDDs. Each system maps to a pillar, no anti-pillar is broken, and hero alone loses on wave 3. Pre-Production can start. Risks it must carry: (1) Pillar 4 has only mouse evidence, so the phone test stays the MVP+ exit. (2) Pillar 2 rests on bots with no thumb cost (D1), so the hero share is unproven until human logs exist. (3) Re-pinning, the decision the fantasy names, buys under 2 lives (D4). The lanes trigger now flags this to the user. (4) "Tactical calm" against "a burst every 10 s keeps the thumb busy" (D10) is mine to set, after D1 and D3 and before feel work. (5) Stage length runs over the 5 to 8 min target (D8). (6) The pillar decisions were applied to the GDDs with no re-review. Pillar 1's trees and the cross-buff hook wait for Vertical Slice, as planned, so that is not a finding.
- Technical Director (TD-PHASE-GATE): CONCERNS. The architecture is sound for entering Pre-Production: 11 ADRs, a clean dependency graph, 126 of 126 TRs covered after the 04c fixes (TR-enemy-016 and 017 now in ADR-0009), and a written frame budget (7.5 of 16.6 ms planned, 2.1 ms headroom). Concerns: (1) all 11 ADRs are Proposed, with 72 open engine items; ADR-0001, 0003 and 0004 gate the rest and need the Run B phone session, which this host cannot run (no Godot binary). (2) The frame and draw-call budgets are unmeasured. (3) CI proves the pipeline only (2 canary tests); it covers Run A, not device behaviour. (4) Deferring save/load is fine, given the `architecture.md` Data Flow 8 contract, but its ADR must land before any Vertical Slice save work. Do Run A, then the ADR-0003 spike, in the first Pre-Production sprint, and build no input or lifecycle code past a prototype until ADR-0001, 0003 and 0004 are Accepted.
- Producer (PR-PHASE-GATE): CONCERNS. Nothing this gate requires is missing, and Run A (desktop and CI) can start now. Risks for a solo part-time developer:
  1. **Run B has no device, owner or date.** It settles 8 of 11 ADRs. The Production gate needs the control manifest, the manifest needs Accepted ADRs, and those wait on Run B, so Run B is on the critical path. Yet the concept puts the first phone build at MVP+, after the desktop MVP. Clear: name the phone(s), the owner (the user) and a target week, and decide whether Run B comes before MVP or is merged into MVP+.
  2. **Run B is too big for one session.** It asks for a low-end Android phone, an iPhone and a 4:3 screen in one sitting, plus 11-step spike S-1 to S-11 first. No `export_presets.cfg` exists and `commands.build` is unset; iOS also needs Xcode and an Apple developer account, none confirmed. Clear: split it. B1 = Android debug export (ADR-0003 spike, then 0001, 0002, 0004, 0010, 0011). B2 = iOS and 4:3 later, before Vertical Slice.
  3. **Overhead vs. team.** `rigor: full` expands to `team.size: studio` and a 4-seat panel for a one-person team. The MVP is 6 to 7 days, and PR-SCOPE already rated it OPTIMISTIC. Clear: confirm or lower the rigor before Pre-Production planning starts.
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
