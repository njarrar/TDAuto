# Gate Check: Systems Design → Technical Setup

**Date**: 2026-11-05
**Checked by**: gate-check skill (`/gate-check technical-setup`)
**Workflow tier**: full. Review mode: full.
**Recorded stage at check time**: Systems Design

> **Passed after the fact.** Technical Setup work (11 Accepted ADRs,
> `architecture.md`, the control manifest, the example test) went ahead before
> this gate ran. Passing it now fixes the stage order. It does not re-check that
> work and reopens no ADR.

### Required Artifacts: all present
- [x] Systems index: `design/gdd/systems-index.md`
- [x] All 8 MVP GDDs Approved, with review logs in `design/gdd/reviews/`
- [x] Cross-GDD review: `design/gdd/gdd-cross-review-2026-11-05.md` (both passes CONCERNS, 0 blockers)
- [x] GDD structure check: every GDD meets its tier (Player Fantasy absent at `standard`, advisory)

### Director Panel Assessment (4 of 4)

Creative Director: CONCERNS
  Settle calm vs busy feel (D13/D14). Pillar 2 hero share unproven (bot 39% vs a 25 to 30% target). HUD text-size trade-offs and pause owner open. No ADR should settle D6 or D9.

Technical Director: CONCERNS
  Wording fixes: C1 (Flow Rule 18 fatal cause), C6 (hit-radius owner), C17 (to_ticks and dependency tables), C14/C15 criterion owners, stale systems index. Decide UX items before HUD stories.

Art Director: CONCERNS
  HUD text size (N7): art bible and accessibility say 16 dp, HUD GDD says 14 dp, and 16 dp breaks the build arc and Won panels. Decide before HUD layout constants. "Lives" listed as text but drawn as dashes. Device checks pending; H-07 and H-10 unset.

Producer: CONCERNS
  Gate passed after the work it should have opened. Schedule drift: 111 commits since 2026-11-01, about 106 docs, no `.gd` in `src/`, against a 6 to 7 day MVP. Scope unchanged at 8 systems. Next phase must be code first.

### Accepted Risks (user accepted 2026-11-05)
1. Gate order: passed after the fact, as noted above.
2. Schedule drift. Rule: no new ADRs or review passes unless code or a device result forces one.
3. Decide N7 (HUD text size) and N9 (pause control build and owner) before the first HUD story.
4. D1 to D13 become prototype or playtest questions. The first build logs human hero share from day one; the 25 to 30% band is a hypothesis.
5. Open cross-review warnings (C-series, N5 to N11) are fixed when the story that touches that GDD starts.
6. Systems index header and tracker refreshed with this gate.

### Verdict: CONCERNS (risks accepted, stage advanced to Technical Setup)
