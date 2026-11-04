# Gate Check: Systems Design → Technical Setup

**Date**: 2026-11-04
**Checked by**: gate-check skill, at `main` 221524d
**Workflow**: project `full`; all 8 MVP GDDs pinned to `standard`

### Required Artifacts: 3/3 present
- [x] `design/gdd/systems-index.md`, 8 MVP systems, all marked Approved
- [x] 8 MVP GDDs in `design/gdd/`, latest review verdict APPROVED on each
- [x] `design/gdd/gdd-cross-review-2026-11-04.md`, Focus full, verdict CONCERNS

### Quality Checks
- [x] Required sections present at each GDD's effective tier (`gdd-structure-check.sh`). Player Fantasy and Tuning Knobs are advisory at `standard`; Data has no Formulas, and its log records why
- [x] `/review-all-gdds` verdict is not FAIL or NOT ASSESSED, and both passes ran
- [x] MVP priority tier defined
- [~] Every GDD changed after its last review, so review hashes are stale
- [~] C1 to C11 edited, 5 spot-checked by search, comparison not re-run
- [~] Hero's index row omits Battle HUD, which Hero lists as hard for HeroInput
- [~] Stale references remain (concern 4)

### Director Panel
- Creative Director: CONCERNS. Enter; D1 is the biggest open risk; the lanes trigger may fire on noise
- Technical Director: CONCERNS. Enter; the requirement baseline has drifted; run the ADR-0003 spike early
- Producer: CONCERNS. Enter; schedule is stale; cap review loops
- Art Director: READY, with advisory items

### Blockers
None.

### Concerns
1. Today's rules are unreviewed: outcome during a telegraph, "Burst decides", proposed numbers.
2. Bots have no thumb cost (D1), and no GDD row requires fixing it.
3. The lanes trigger may fire falsely: players re-pin more when a run goes badly, samples are small, and lives move in steps of 3.
4. Drift: `tr-registry.yaml` lacks today's rules; `architecture.md` says 120 requirements against 125; index header says Draft; Combat and Enemy & Wave dates; Battle HUD alpha 0.55 against 0.6; concept's wave 4 and about 3 lives.
5. Scenarios 1, 3 and 5 rest on unverified ADR-0003 and ADR-0004 premises.
6. D1 to D10, I1, I2, I4 to I7 have no owners; the entity registry is empty.
7. "MVP 6 to 7 days" predates this phase. Producer's low-confidence estimate: Technical Setup 3, 5 or 9 working days; MVP build 12 to 21 days.
8. Review loops are the top rework risk: 40 design reviews in 4 days.

Open question from the art director: are Defeat's and Victory's field shifts in MVP?

### Verdict: CONCERNS
Chain-of-Verification: 5 questions checked — verdict unchanged. Stage stays at Systems Design. The user chose to fix the small items and re-run; the re-run is recorded below when done.

## Re-run — 2026-11-04, on the uncommitted working tree after the fixes

The directors re-judged the changed text in their first-run sessions, and did not read everything afresh.

- Creative Director: CONCERNS. Enter
- Technical Director: CONCERNS. Enter
- Producer: CONCERNS. Enter
- Art Director: READY

**Closed:** D1 has a Hero row; open D and I items have owners; the lanes trigger flags the user; index header and Hero row; Combat and Enemy & Wave dates; unaffordable alpha 0.6 (HQ-01); concept's wave 3 and about 2 lives; clearance on Pause.

**Open:**
1. The newest independent read of today's rules returned NEEDS REVISION (18 findings, 5 blocking). All 5 were fixed in one pass that nobody re-read. "Approved" in the GDD headers and "latest review verdict APPROVED" above predate this text. Applying a one-review, one-fix cap to GDD rules was the skill runner's choice, not yet a user decision.
2. `architecture.md` and `tr-registry.yaml` have drifted, and must be re-synced before ADRs. TR-hud-017 has two wordings until then.
3. The engine premises behind scenarios 1, 3 and 5 are unverified. The technical director recommends the ADR-0003 spike before any ADR.
4. The entity registry is empty.
5. "MVP 6 to 7 days" is stale; the MVP build now also holds bot work.
6. Review loops stay the top rework risk.
7. First-playable human logs are mouse-only, so lanes, mono-role and always-call results are provisional until the phone test.
8. Small: the redraw key's HudField merge has manual cover only; `arc-and-chip.md:163-164` can be read as dimming the whole disc; the save/load ADR question; `team.size` studio against a solo developer.
9. Decisions due: ADR review depth; Defeat and Victory field shifts.

### Verdict: CONCERNS
Chain-of-Verification: 5 questions checked — verdict unchanged. No check was NOT ASSESSED. Stage stays at Systems Design unless the user accepts these risks.

### Accepted Risks
Each of the eight open items above, 1 to 8, accepted by the user, 2026-11-04, and item 9's decisions deferred until they come up. The 5 blocking fixes in item 1 get checked during the architecture re-sync, with no new review round (user decision, 2026-11-04). The user advanced the stage to Technical Setup.
