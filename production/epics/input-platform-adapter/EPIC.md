# Epic: Input Platform Adapter

> **Layer**: Foundation
> **GDD**: design/gdd/input-gesture-resolver.md (adapter, coordinates, lifecycle)
> **Architecture Module**: InputAdapter, PointerGate, FieldSpace, FieldInsets, SafeAreaSource
> **Status**: Ready
> **Stories**: Not yet created. Run `/create-stories input-platform-adapter`

## Overview

This epic builds the engine-facing side of input: the one node that turns touch and mouse events into the resolver's five calls, and the coordinate space every screen position passes through. All of this epic's HIGH engine risk sits here, and so do the best-guess device assumptions behind ADR-0006 to 0008 (`docs/architecture/device-assumptions.md`).

ADR-0007 decides the path. The `InputAdapter` reads events in `_input` and passes them through one decode function into a pure `PointerGate` that holds every rule. Every forwarded press ends in exactly one release, `cancel_pointer` or `cancel()`. Mouse events are told apart by class, never `device == 0`; both emulation keys are false; a family lock drops the other event family while a press is open. The gate's press block stops forwarding while a modal is up and never cancels; step 1g's `cancel()` then `forget_open_presses()` closes the open press (ADR-0003, ADR-0007). The adapter emits no signals and owns no lifecycle (ADR-0002, ADR-0008: the BattleWrapper owns `lifecycle_changed`).

ADR-0006 decides the space: `canvas_items` with `expand` at 540 by 960, a bottom-anchored field, opaque curtains over the margins, and one pure `FieldSpace` that alone converts event positions and safe-area insets. A resize cancels the gesture and the new `FieldSpace` is swapped in only at step 1g (TR-input-006). `BattleWrapper.attach()` builds the pieces in order: `InputAssembly.build` (resolver, HeroInput, TowerInput), `PointerGate.create`, then `InputAdapter` (ADR-0008).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0007: Input Adapter and Gesture Path | `_input` into a pure `PointerGate`; one closer per press; emulation off; family lock | HIGH (best-guess assumptions I1 to I11) |
| ADR-0006: Stretch Mode, Coordinate Space, Safe Area and HUD Layering | `canvas_items`/`expand`, bottom-anchored field, `FieldSpace`, insets, press block | HIGH (best-guess assumptions D1 to D12) |
| ADR-0008: App Lifecycle and Battle Composition | Wrapper owns lifecycle; attach order; step 1g order | HIGH (best-guess assumptions L1 to L10) |
| ADR-0003: Frame Order | Handlers only enqueue; `cancel()` and the space swap only at step 1g | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-input-003 | Adapter guarantees every forwarded press ends in exactly one release, `cancel_pointer` or `cancel()` across Controls and OS touch-cancel | ADR-0007 ✅ |
| TR-input-004 | Desktop mouse maps to one touch pointer; one physical press gives one gesture; events identified by class, not device 0 | ADR-0007 ✅ |
| TR-input-006 | Gesture coordinate space stays fixed for a gesture's life; resize or restretch cancels it; reference field 540 by 960; below 360 dp unsupported | ADR-0006 ✅ |
| TR-input-007 | `lifecycle_changed(state)` covers focus lost, focus gained, quit requested, resized and Android back; its one owner is the BattleWrapper, not the adapter | ADR-0008 ✅ |

Coverage: 4 of 4 by an Accepted ADR, per the architecture Baseline. Untraced in the TR registry: all 4 (see Known Gaps). ADR-0006 to 0008 were accepted on best guesses, not device tests.

## Known Gaps (recorded 2026-11-03, user decision)

- **TR registry empty.** `docs/architecture/tr-registry.yaml` has no entries yet. The TR-IDs below come from the architecture's Technical Requirements Baseline (provisional). Run `/architecture-review` in a fresh session before `/create-stories`, so stories can embed registered TR-IDs.
- **GDD not Approved.** The GDD is In Review. Do not write stories against sections still being revised.
- **One developer.** `team.size` resolves to studio, but the team is one person: size stories for one developer.
- **No milestones** are recorded, so this epic is not checked against a deadline.
- **No test device.** No phone is available. Log this as a project risk with an owner and a date to get an iPhone 16 or later before the first sprint.

## Deferred to the Milestone Gate (not epic-close criteria)

- Every device check in `docs/architecture/device-assumptions.md` (its First device build checklist): the D, I and L items that need a phone.
- In scope now, on desktop: D1 and D8 (the display keys), I7 and I8 (off-window mouse release, process mode).

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/input-gesture-resolver.md (adapter rules) verified, except criteria deferred to the milestone gate below
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
