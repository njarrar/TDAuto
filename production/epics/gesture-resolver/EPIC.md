# Epic: Gesture Resolver

> **Layer**: Foundation
> **GDD**: design/gdd/input-gesture-resolver.md (resolver rules, gesture log)
> **Architecture Module**: GestureResolver
> **Status**: Ready
> **Stories**: Not yet created. Run `/create-stories gesture-resolver`

## Overview

This epic builds the pure resolver: the one place a thumb's press becomes exactly one tap, one drag or nothing, delivered to exactly one target (GDD Overview, Pillar 4). It owns the target registry (each owner registers its own shape, priority and gestures), one active pointer, the four-state machine and the gesture log. It never names a feature system.

The resolver is a `RefCounted` object with no scene-tree dependency (TR-input-001), so every rule is tested headless with gdUnit4. Its signals and calls follow the canonical table (ADR-0002): `pressed(best_tap, best_drag, pos)`, `tap`, `ground_tap`, `drag_started`, `drag_moved`, `drag_ended` with `press_pos`, `drag_cancelled`, `idle`, and `register`, `unregister`, `set_centre`, `set_enabled`, `press`, `move`, `release`, `cancel_pointer`, `cancel`. Discs freeze at press, so a target that moves mid-gesture keeps its gesture. Its handlers' owners only queue commands (ADR-0003). Hit radii and slop are the GDD's values; `drag_slop`, `tap_slop` and `edge_reject_margin` come from the Input record (Data epic).

This epic can start against fixture catalogues before the Data epic closes. The platform adapter that feeds it is the Input Platform Adapter epic.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0007: Input Adapter and Gesture Path | The resolver's contract, the one-closer rule, gesture log feeding | HIGH |
| ADR-0002: Signal Contracts and Wiring Conventions | Canonical resolver signal and call signatures; wrapper wiring test | MEDIUM |
| ADR-0003: Frame Order | Handlers only enqueue commands; `cancel()` only at step 1g | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-input-001 | Resolver is a pure object with no scene-tree dependency: registry, one active pointer, four-state machine, five input calls | ADR-0007 ✅ |
| TR-input-002 | Each press yields exactly one tap, one drag or nothing, delivered to exactly one target by priority; owners register themselves | ADR-0007 ✅ |
| TR-input-005 | Hit radii and tap/drag slop meet the 44 pt / 48 dp minimum; at most 5% misses and zero mis-fires over 20 attempts on a phone | ADR-0007 ✅ (radii and slop as config in scope; the 20-attempt phone test is deferred to the Pillar 4 milestone gate) |
| TR-input-008 | Gesture log records each gesture, including the landed pin position for a hero drag | ADR-0007 ✅ |

Coverage: 4 of 4 by an Accepted ADR, per the architecture Baseline. Untraced in the TR registry: all 4 (see Known Gaps).

## Known Gaps (recorded 2026-11-03, user decision)

- **TR registry empty.** `docs/architecture/tr-registry.yaml` has no entries yet. The TR-IDs below come from the architecture's Technical Requirements Baseline (provisional). Run `/architecture-review` in a fresh session before `/create-stories`, so stories can embed registered TR-IDs.
- **GDD not Approved.** The GDD is In Review. Do not write stories against sections still being revised.
- **One developer.** `team.size` resolves to studio, but the team is one person: size stories for one developer.
- **No milestones** are recorded, so this epic is not checked against a deadline.

## Deferred to the Milestone Gate (not epic-close criteria)

- The 20-attempt phone test with a non-developer tester (TR-input-005; the Input GDD already places it at the Pillar 4 gate).

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/input-gesture-resolver.md (resolver rules) verified, except criteria deferred to the milestone gate below
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
