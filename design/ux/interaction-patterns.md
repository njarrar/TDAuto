# Interaction Pattern Library

> **Status**: In Design
> **Author**: ux-designer (autonomous mode; user to review)
> **Last Updated**: 2026-11-04
> **Version**: 0.1
> **Engine**: Godot 4.7.2
> **UI Framework**: Two surfaces. Everything that can be tapped or dragged in the field is a registered disc in the Input & Gesture Resolver, drawn by `CanvasItem._draw`. Only the modal screens (Result, Paused, Fatal) and the top information band are Godot `Control` nodes.
> **Related Documents**:
> - `design/art/art-bible.md` sections 3, 4, 7 (shapes, colour, UI direction)
> - `design/accessibility-requirements.md` (tier and per-feature commitments)
> - `design/gdd/battle-hud.md`, `input-gesture-resolver.md`, `tower-system.md`, `hero-system.md`, `game-state-stage-flow.md`
> - `design/ux/[screen].md` (none yet; the Battle HUD, arc and chip, and pin and aim specs are still to be written)
> **Template**: Interaction Pattern Library

> **Source of this draft.** No UX spec exists yet, so every pattern below is
> extracted from the approved or in-review GDDs and the art bible, not from a
> screen spec. Numbers are copied from those documents; where a document leaves
> a value open it is listed in Open Questions rather than invented here. All
> patterns are **Draft** (specified, not implemented or validated on a device).

---

## Overview

TowerRiot is portrait, one thumb, touch first (a mouse stands in for touch on the
desktop development build). Pillar 4 ("Thumb-First") sets the rule every pattern
obeys: every action is one tap or one drag, and no target is smaller than
44 pt (iOS) or 48 dp (Android). The art bible converts that to field units:
540 units is about 360 dp, so 48 dp is 72 units.

The library has four parts:

1. **Input patterns** (P-01 to P-05): how a touch becomes a tap, a drag or nothing, and which target wins.
2. **Control patterns** (P-06 to P-11): the build arc, the upgrade chip, the Start/Call button, pin, aim, and the modal screens.
3. **Feedback patterns** (P-12 to P-17): refusal, unaffordable, locked, cooldown, ground tap, prompt.
4. **Display patterns** (P-18 to P-20): counters, lives, wave pips.

### How to Use This Library

**Designing a screen:** browse the catalogue, reference a pattern by its ID
(for example "uses P-04 Armed Button"), and do not restate its behaviour. If no
pattern fits, add one here or flag it in Gaps before writing the spec.

**Implementing:** the pattern's Specification is the contract. The GDD named in
"Source" is the authority if the two ever differ; fix this document.

**Reviewing:** `/ux-review` checks that a spec uses these names and that its
accessibility notes match each pattern's accessibility line.

### Global rules

| Rule | Value | Source |
|---|---|---|
| Minimum hit target | 48 dp (72 units at 360 dp). Every MVP target meets it with no margin at the narrowest width | Art bible 3; Battle HUD UI Requirements |
| Minimum text | 14 dp (21 units) body; 16 dp gold, lives, labels, costs; 24 dp burst digit (floor 18 dp) | Art bible 7 |
| Text surface | Neutral `#C8D0E0` on panel `#141B30` (85% opacity) only; never on the raw field at small sizes | Art bible 7 |
| Press and state-change animation | 120 ms | Art bible 7 |
| Panel slide | 200 ms, opacity fixed | Art bible 7 |
| Never animated | Leash (dash density switches), panel opacity, counter values (digits swap, never bounce). Nothing in screen space loops or glows | Art bible 7 |
| Reduce Motion | Cuts slides and nudges; fades and clock bars stay; the 2 Hz danger pulse freezes and the 0.4 s burst dip is skipped. Data flag `reduce_motion` on the Input record until Settings exists | Battle HUD; art bible 7 |
| Handedness | `left_handed` mirrors the burst button and its digit only; never the leash kite or the aim offset | Hero UI Requirements |
| Hover | None. No hover-only interaction anywhere | Technical preferences |
| Destructive actions | None exist (no selling, no respec in battle), so no confirmation dialogs. The mis-spend guards are P-06 and P-07 | Tower, Battle HUD |

---

## Pattern Catalog

| ID | Pattern | Category | Used in | Status |
|---|---|---|---|---|
| P-01 | Disc Hit Target | Input | Every tappable or draggable thing in the field | Draft |
| P-02 | Tap vs Drag Classification | Input | All gestures | Draft |
| P-03 | Tap Priority Order | Input | All overlapping targets | Draft |
| P-04 | Sink Target | Input | Burst button, arc backdrop | Draft |
| P-05 | Edge and Safe-Area Rejection | Input | All presses | Draft |
| P-06 | Build Arc | Control | Battle HUD (slot tap) | Draft |
| P-07 | Upgrade Chip | Control | Battle HUD (tower tap) | Draft |
| P-08 | Armed Button | Control | Start/Call, Retry, Play again | Draft |
| P-09 | Pin Drag | Control | Hero | Draft |
| P-10 | Aimed Burst Drag | Control | Hero burst | Draft |
| P-11 | Modal Screen | Control | Result, Paused, Fatal | Draft |
| P-12 | Refused Action | Feedback | Arc disc, chip, burst button | Draft |
| P-13 | Unaffordable | Feedback | Arc disc, chip | Draft |
| P-14 | Locked Outline | Feedback | Burst button | Draft |
| P-15 | Cooldown Display | Feedback | Burst button, towers | Draft |
| P-16 | Ground Tap Rejection | Feedback | Empty field | Draft |
| P-17 | First-Time Prompt | Feedback | Hero pin, build | Draft |
| P-18 | Swap Counter | Display | Gold | Draft |
| P-19 | Lives Dashes | Display | Lives | Draft |
| P-20 | Wave Pips | Display | Wave progress | Draft |

---

## Patterns

### P-01 Disc Hit Target

**Category**: Input
**Used In**: every field target (hero, burst button, slots, towers, arc discs, chip, Start/Call, backdrop)
**Source**: Input & Gesture Resolver, Hit targets
**Status**: Draft

**Description**: A target is a disc: a centre, a radius, a gesture class (TAP or DRAG), a priority and an enabled flag. The owner registers and unregisters its own targets and moves the centre when the thing moves. The resolver never knows what a target is.

**Specification**:
- Radius from the art bible table: hero drag 56 units; tower, slot and arc disc 36 units; burst button 48 units; chip 40 units.
- A thing that answers both a tap and a drag registers twice, under two ids.
- `set_enabled(false)` removes a target from hit tests without unregistering it (a built slot).
- Ids start at 1 and are never reused; `NONE` is -1, so a stale id can never alias a live target.
- The visible shape is larger than or equal to the disc's inner area and never smaller than the minimum text and target rules above.
- Accessibility: the disc, not the drawing, is the hit area. A drawn element smaller than 48 dp must still have a 48 dp disc.

**When to Use**: any tappable or draggable thing in the field, including things drawn by `_draw`.
**When NOT to Use**: modal screens and the top band; those are Controls (P-11).

### P-02 Tap vs Drag Classification

**Category**: Input
**Used In**: all gestures
**Source**: Input & Gesture Resolver, Rules 1 to 6
**Status**: Draft

**Description**: A press is a tap or a drag, decided by distance moved from the press point. The two kinds never fall through to each other.

**Specification**:
- Slops come from the Data `Input` record (`drag_slop` 8 to 30 units, `tap_slop` 16 to 34 units, with `tap_slop > drag_slop`). Pillar 4 aims for a drag slop of about 10 to 12 dp on phones; the shipped values come from the phone test.
- At press the resolver freezes the best TAP winner and the best DRAG winner. A press with a tap target uses the larger tap slop before it can become a drag.
- A drag latches once started and never turns back into a tap.
- One pointer at a time. A second finger is ignored.
- Every exit ends with `idle`.
- Accessibility: a tap never requires holding. A drag never requires a precise end point except the burst aim (P-10), whose cancel zone is generous (64 units).

**When to Use**: automatic; all input goes through it.
**When NOT to Use**: never bypass it. Headless bots call the commands directly instead (Input Rule 11).

### P-03 Tap Priority Order

**Category**: Input
**Used In**: any place where discs overlap
**Source**: Input & Gesture Resolver, Suggested registrations; concept Pillar 4
**Status**: Draft

**Specification** (higher wins within a class; ties go to priority, then nearest centre, then id):

| Priority | Target | Class |
|---|---|---|
| 400 | Burst button sink | TAP, sink |
| 350 | Start/Call (Build and Intermission only) | TAP |
| 300 | Build-arc disc; upgrade chip | TAP |
| 250 | Arc backdrop | TAP, sink |
| 200 | Tower; build slot (nearest centre wins) | TAP |
| 200 | Hero | DRAG |
| 100 | Burst button | DRAG |

- Drag order: the hero's grab disc (56 units) beats the burst button, so a press inside both is the hero's. When `pressed` names Start/Call as `best_tap` and the hero as `best_drag`, the HUD ignores that gesture's tap.
- Towers and slots share a tier so a tower cannot steal a touch aimed at the slot beside it.
- No slot may sit close enough to the burst button for their discs to overlap at any supported inset (Enemy & Wave rule L3, enforced by a content test).
- Walkable ground: a tap on nothing does nothing (P-16).

### P-04 Sink Target

**Category**: Input
**Used In**: burst button (tap), arc backdrop
**Source**: Input & Gesture Resolver, `sink` field
**Status**: Draft

**Description**: A TAP-only target that absorbs taps its owner ignores. It wins the tap class like any other target but does not raise the press's slop and does not hold the pointer against a replacing press.

**Specification**:
- Burst button: a tap does nothing and reaches nothing beneath, so a resting thumb cannot spend the cooldown and a slot below cannot receive the touch.
- Arc backdrop: one disc covering the field while an arc is open, so a press outside the discs only dismisses the arc.
- Accessibility: a tap that does nothing must not feel broken; for the burst button the cooldown display (P-15) is the explanation.

### P-05 Edge and Safe-Area Rejection

**Category**: Input
**Used In**: every press
**Source**: Input & Gesture Resolver, Rule 12
**Status**: Draft

**Specification**:
- The adapter rejects a press inside `edge_reject_margin` (0 to 36 units) and inside the platform safe-area or gesture insets.
- Burst button: hit box ends at least 24 dp from the side edge (Android back-swipe zone, unverified) and 16 dp above the OS gesture inset.
- Start/Call may sit in the bottom band only in Build and Intermission, clear of the burst button and build slots.
- The bottom 30% of the screen holds only the burst button and the field, so the pinned thumb never hides the lower lane.
- Open: real inset values on Android and iOS (see Open Questions).

### P-06 Build Arc

**Category**: Control
**Used In**: Battle HUD
**Source**: Battle HUD Rules 6 to 8; Tower Rule 8; art bible 7
**Status**: Draft

**Description**: Tapping a free slot opens three tower discs in an arc above the slot. Tapping a disc builds that tower.

**Specification**:
- Order is always triangle (Single), hexagon (Splash), square (Slow), left to right, on every slot and for both hands, for motor memory.
- Arc sits above the slot, never below, where the thumb is. Each disc is a 56 px role polygon with a 72 px hit disc; a panel above holds the word and the cost on two lines.
- A disc press within 200 ms of opening is ignored, because a slot's disc and the hexagon's are only 4 units apart, and a double tap must dismiss rather than buy.
- The disc always calls `build`; the result decides: `OK` closes the arc at once (120 ms collapse is art only), `NO_GOLD` leaves it open with a refusal (P-12), `HALTED` closes it.
- Closing: a press outside the discs closes it (backdrop sink); `drag_started` closes it; Paused, an outcome and Fatal close it. A phase change among Build, Wave and Intermission leaves it open. A finger rolling off a disc under slop still taps it (Input Rule 3); a press dragged past slop with no drag winner is dead and leaves it open.
- Start/Call is disabled while an arc is open.
- Unaffordable discs use P-13.
- Reduce Motion: the 120 ms collapse becomes a cut. Static fallback for the open and close is still to be specified (Open Questions).
- Accessibility: choice is by shape and word, never colour alone (all three discs are cyan). No timer; the arc stays open until dismissed.

**When to Use**: building on a free slot.
**When NOT to Use**: upgrading (use P-07).

### P-07 Upgrade Chip

**Category**: Control
**Used In**: Battle HUD
**Source**: Battle HUD Rule 9; Tower Rule 8
**Status**: Draft

**Description**: Tapping a level-1 tower shows a cost chip for 1.5 s. A tap on the chip, or a second tap on the tower, commits the upgrade.

**Specification**:
- The chip is its own tap target (priority 300, radius 40, at the tower's x and y minus 76 units) so a tap on what the player sees works. `tap(chip)` is treated as a second `tap(tower)`.
- It shows the cost, the level-2 glyph and a 3-unit bar draining over the 1.5 s window, so the window has a visible clock.
- A tap on a level-2 tower shows its range ring for 1.5 s and opens no chip, so the tap is not silent.
- The chip closes on Paused, Won, Lost and Fatal, and is ignored while halted.
- Below the affordable cost it uses P-13.
- The chip-then-tap step is the mis-spend safeguard: there is no selling.
- Window length runs on real time (the sim clock is stopped in Build). It must be adjustable (see accessibility requirements, input timing).
- Open: whether the draining bar reads under a thumb; an expired or closed chip look; an armed look after the 200 ms guard; a chip that would leave the field; a maximum-level cue beside the range ring.
- Accessibility: the 1.5 s window is a timed input. See Accessibility Requirements, Motor, "Input timing adjustments".

### P-08 Armed Button

**Category**: Control
**Used In**: Start/Call, Retry, Play again (the Paused screen does not arm, P-11)
**Source**: Battle HUD Rules 10 and 11; Game State Game Feel
**Status**: Draft

**Description**: A button for an irreversible or screen-changing action does not fire for 300 ms after it appears, so a thumb already on that spot cannot trigger it.

**Specification**:
- States: Hidden, Arming (300 ms of real time), Armed.
- It registers with the resolver on appearing, not on arming, or an early press would land on what lies beneath.
- A tap whose press began during Arming is dead, even if released once Armed. A press begun before the button appeared cannot win.
- A Control fires only on a release whose press it saw while Armed, and clears that press on the lifecycle signal (focus loss), so a thumb held across a screen change cannot fire it.
- The clock is `advance(ms)` from the frame time, clamped to 100 ms per frame, frozen while Paused. Returning from Paused is not a new appearance.
- Start: "Start" in Build. Call: "Call +7" in Intermission (bare "Call" when the bonus is 0), with the seconds left and a small burst glyph under it. No pulse, warning or advice once armed.
- Accessibility: Arming is a deliberate delay of 300 ms, not a demand. The look of the Arming state must differ from Armed by more than colour (outline vs filled; to be set in the screen spec).

### P-09 Pin Drag

**Category**: Control
**Used In**: Hero
**Source**: Hero System; art bible 3 and 7; concept Pillar 2
**Status**: Draft

**Description**: Dragging the hero pins it to a spot. It fights only inside a leash around the pin.

**Specification**:
- Grab disc is 56 units (drag priority 200). The hero is at least 44 px visible.
- The leash is a 2 px dashed circle (10 on, 8 off) at 90 px radius, alpha 0.5, never filled. Where it crosses the lifted path it is drawn in two tones or raised to alpha 0.7 so it clears 3:1.
- Invalid pins are clamped or refused (rejected zones, under the burst button). Refusal uses P-12.
- Before a first pin, a one-line prompt "Drag the hero" (P-17).
- The pin ghost is a 2 px unfilled kite. The ground ring is 2 px solid at radius 30.
- Open: re-grabbing a hero pinned high on the screen with one thumb.
- Accessibility: one finger, one drag, no hold. The leash's in-zone and out-of-zone states differ by dash density, not tint.

### P-10 Aimed Burst Drag

**Category**: Control
**Used In**: Hero burst
**Source**: Hero System; art bible 7; Input Rule 4
**Status**: Draft

**Description**: Dragging from the burst button aims the hero's burst; releasing fires it there, unless the release is in the cancel zone.

**Specification**:
- Burst button: 84 px visible, 96 px hit, bottom corner on the dominant-hand side. A tap does nothing (P-04). Locked in Build or before a first pin (P-14).
- Ready press: a thin ring at radius 64 shows beyond the fingertip; this is the cancel boundary. Cancelling starts when the finger ends over 64 from the button's centre and resumes at 48.
- Reticle: a 3 px solid ring with four ticks, alpha 0.7, drawn offset 100 units above the finger so the thumb never hides it, clamped to the viewport and the burst's reach, with no flip.
- While cancelling, the reticle dims and the radius preview hides, because releasing then cancels.
- A radius preview is a solid unfilled outline. The reach ring is neutral, dotted (3 on, 13 off), 2 px, alpha 0.6.
- Releasing in the cancel zone cancels. Pause cancels an aim in progress.
- Cooling press: the digit shows above the thumb on a panel, and the press does nothing (P-15).
- Accessibility: aim is a held drag (no timing). Cancel is by direction (release near the button) and needs no precision. A drag-free alternative is not in scope at MVP (Known Intentional Limitations).

### P-11 Modal Screen

**Category**: Control
**Used In**: Result (Won, Lost), Paused, Fatal
**Source**: Battle HUD Rules 2 and 15; Game State Rules 15 to 18
**Status**: Draft

**Specification**:
- A full-screen `Control` that consumes every input event before the Input adapter sees it, so a tap cannot reach a tower or the hero.
- Result: a transparent modal mounts at the outcome, so input is dead at once. Text appears 400 ms after a Lost or a Won (Battle HUD Rule 15; Flow, Game Feel). Plain text in fixed order, same weight for Won and Lost. A lost stage reads "Broke on wave N of 6". Both show damage by source (Towers, Hero, Burst) as plain numbers with no percentage. Retry uses P-08.
- Paused: instant. There is no pause button at MVP; Paused comes from focus loss or backgrounding. The resume tap does not arm: it counts only a press begun after the screen showed, and reaches nothing beneath (Battle HUD Rules 2 and 17).
- Fatal: a generic, catalogue-free screen that is guaranteed to load.
- Modals add about 4 draw calls.
- Accessibility: these are real `Control` nodes, so they are the screens that can carry accessibility labels for TalkBack and VoiceOver (see Accessibility Requirements, Platform API). Nothing auto-dismisses.

### P-12 Refused Action

**Category**: Feedback
**Used In**: arc disc (NO_GOLD), chip, burst button
**Source**: Tower UI Requirements; Hero UI Requirements
**Status**: Draft

**Specification**:
- A refused tap nudges the element 2 px once for 120 ms. No magenta (magenta is danger only).
- Skipped under Reduce Motion, which leaves a refused tap with only the standing dim (P-13).
- **Closed**: the refusal cue that does not rely on motion is Battle HUD Rule 7's cost flash, the struck-through cost at full alpha for 120 ms, which Reduce Motion keeps.
- Accessibility: a cue must exist that is not motion alone.

### P-13 Unaffordable

**Category**: Feedback
**Used In**: arc disc cost, chip cost
**Source**: Tower UI Requirements; Battle HUD Rules 7 and 9
**Status**: Draft

**Specification**:
- Dimmed plus struck through, updated live as gold changes.
- A dimmed cost must stay legible. Measured on panel `#141B30`: neutral text at alpha 0.6 gives 4.8:1 (passes 4.5:1); alpha 0.5 gives 3.8:1 and alpha 0.4 gives 2.8:1 (both fail). **The dimmed alpha floor is 0.6.**
- The strike-through carries the meaning; the dim is secondary, so the state is not colour or brightness alone.

### P-14 Locked Outline

**Category**: Feedback
**Used In**: burst button (Build, or before a first pin)
**Source**: Hero UI Requirements; art bible 7
**Status**: Draft

**Specification**:
- Dotted neutral outline, no fill, no digit. A press nudges the button 2 px once for 120 ms (skipped under Reduce Motion) and, before a first pin, repeats the prompt (P-17).
- Shares the "owned filled, available outlined, locked dotted" grammar with tree nodes and wave pips.

### P-15 Cooldown Display

**Category**: Feedback
**Used In**: burst button; towers
**Source**: Battle HUD Rule 12; Tower Visual; art bible 4
**Status**: Draft

**Specification**:
- Burst button: Ready is a gold fill with a complete outer ring. Cooling is a neutral outline with the gold fill returning behind it as a clockwise wedge, and a seconds digit in neutral. Telegraphing draws an empty wedge. The wedge is `cooldown_left() / to_ticks(cooldown)`, clamped to 1.
- Towers: Ready is a complete ring; Cooling is a regrowing ring.
- The sweep is linear (it is a clock). The digit swaps and never bounces.
- Colour-blind safe: ready and cooling differ by shape (outline vs filled plus wedge; complete vs regrowing ring), never fill level alone.
- The digit is hidden while the thumb is on the button (device test needed).

### P-16 Ground Tap Rejection

**Category**: Feedback
**Used In**: empty field
**Source**: art bible 7; Input `ground_tap`
**Status**: Draft

**Specification**:
- A tap on nothing does nothing. For the first three taps of a battle, a tiny unanimated dim ring fades in over 150 ms as a rejection cue, so new players do not assume the touch was missed. It never reads as a button.

### P-17 First-Time Prompt

**Category**: Feedback
**Used In**: hero pin, others (three prompts in total, owned by the Battle HUD)
**Source**: Hero UI Requirements; Battle HUD Rule 13
**Status**: Draft

**Specification**:
- One line on panel below the top band, for example "Drag the hero". Stays until the action is done; no auto-dismiss.
- No onboarding system is needed at MVP.
- Open: where a dismissed prompt can be read again (see Accessibility Requirements, Cognitive, "Tutorial persistence").

### P-18 Swap Counter

**Category**: Display
**Used In**: gold (top right)
**Source**: art bible 7
**Status**: Draft

**Specification**: tabular lining numerals so the width never shifts; digits swap, never bounce or count up. 16 dp.

### P-19 Lives Dashes

**Category**: Display
**Used In**: lives (top left)
**Source**: art bible 7
**Status**: Draft

**Specification**: two rows of five dashes, 16x3 dp each. A lost dash fades to alpha 0.2 in 200 ms and stays countable. Urgency is carried by in-field chevrons, not by the dashes.

### P-20 Wave Pips

**Category**: Display
**Used In**: wave progress (top centre)
**Source**: art bible 7; Battle HUD pips row
**Status**: Draft

**Specification**: 20 by 10 pills, not discs, so they never match enemy glyphs. Filled is done, outlined is current, dotted is upcoming. With `wave_index()` W: Build has pip 1 current; Wave and Lost have W - 1 done and W current; Intermission has W done and W + 1 current; Won has all done; Paused shows the phase it left.

---

## Gaps & Patterns Needed

| Gap | Needed by | Note |
|---|---|---|
| Refusal cue that survives Reduce Motion | P-12, arc and chip spec | Tower UX flag |
| Static fallbacks for the build overlay and arc collapse under Reduce Motion | P-06 | Tower UX flag |
| Expired or closed chip, armed look after the 200 ms guard, maximum-level cue, chip leaving the field | P-07 | Tower UX flag |
| Unit-to-dp scale behind the 44 pt / 48 dp targets | P-01 | Tower UX flag; needs the Mobile Platform GDD |
| Menu and list navigation, toggle, slider, tab | Menu & Screen Flow (Vertical Slice), Settings (Alpha) | Standard controls: not needed at MVP. Define with the first menu spec. Keyboard and gamepad focus is out of scope (touch only; technical preferences) |
| Tree node (owned filled, available outlined, locked dotted) | Skill Tree (Vertical Slice) | Grammar exists in the art bible; pattern to be written with the Skill Tree spec |
| Stage preview | Stage Progression (Vertical Slice) | Pillar 3 |
| Tooltip or long-press help | none planned | Touch-first; no hover. Do not add without a decision |
| Confirmation dialog | none planned | No destructive action exists. Skill respec is free and unlimited (concept) |
| Drag-free alternative to pin and aim | accessibility | See Accessibility Requirements, Known Intentional Limitations |

**Possible inconsistencies to resolve:** P-12 (nudge) and P-14 (nudge) share a motion cue that Reduce Motion removes; both need the same non-motion fallback. P-13 (strike plus dim) and P-14 (dotted outline) are two different "unavailable" looks; they differ on purpose (unaffordable now vs locked by phase) but the screen spec should say so.

---

## Open Questions

| ID | Question | Owner |
|---|---|---|
| PQ-01 | Drag slop and tap slop shipped values (Pillar 4 aims at about 10 to 12 dp). Needs a phone test with at least two non-developer testers | game-designer, Pillar 4 phone test |
| PQ-02 | Real safe-area and gesture-inset values on Android and iOS; whether the 24 dp side margin for the burst button is enough | technical-director, ADR-0003 |
| PQ-03 | Whether the chip's draining bar reads under a thumb, and its look when expired | ux-designer, arc and chip spec |
| PQ-04 | Re-grabbing a hero pinned high on the screen with one thumb | ux-designer, pin and aim spec |
| PQ-05 | Reticle far from the thumb when clamped; preview overhanging the reach ring; ring clipping at 540 wide; reach-dot contrast | ux-designer, pin and aim spec |
| PQ-06 | Where a dismissed first-time prompt can be read again | ux-designer |
| PQ-07 | Font choice (tabular numerals, licence). Affects the text draw-call budget | art-director |
