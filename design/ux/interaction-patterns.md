# Interaction Pattern Library

> Authoring guidance: .claude/docs/templates/guidance/interaction-pattern-library-guide.md (load per-section as you author, do not read entirely).

> **Status**: In Design (draft, autonomous mode)
> **Author**: user + ux-designer
> **Last Updated**: 2026-11-05
> **Version**: 0.1
> **Engine**: Godot 4.7
> **UI Framework**: Custom `_draw()` hit discs on the Input & Gesture Resolver for every battle action; Godot Control nodes for the two modal screens only
> **Related Documents**:
> - `design/art/art-bible.md`: visual standards (colours, type, iconography)
> - `design/accessibility-requirements.md`: accessibility commitments per feature (tier: Basic plus elevated items)
> - `design/ux/[screen].md`: none written yet
>
> **Template**: Interaction Pattern Library

> **Why this document exists**: Every screen spec should be able to say "uses
> Armed Button" rather than restate press, arming, refusal and Reduce Motion
> rules. This library is the single source for reusable interaction behaviour.
> When the behaviour changes, it changes here first.
>
> **Status definitions**:
> - **Draft**: specified, not yet built or tested
> - **Stable**: built, tested and validated in at least one shipped screen
> - **Deprecated**: being phased out

**Source key.** "Concept" is `design/gdd/game-concept.md`. "HUD", "Input",
"Hero", "Tower" and "Flow" are `battle-hud.md`, `input-gesture-resolver.md`,
`hero-system.md`, `tower-system.md` and `game-state-stage-flow.md` in
`design/gdd/`. "AB" is `design/art/art-bible.md`. ADR-0003, 0008, 0010 and
0011 in `docs/architecture/` are all **Proposed**. **Proposed** in this document
means no source sets the value and this draft suggests one. Units are field
units on the 540 x 960 reference; 1.5 units = 1 dp at 360 dp.

---

## Overview

TowerRiot has two verbs, tap and drag, done with one thumb on a portrait phone
(Concept Pillar 4). Nearly every interactive thing is a disc registered on the
Input & Gesture Resolver, not a Godot Control (Input Hit targets; HUD Rule 2).
The only Controls are the full-screen result and Paused screens, which take
every event before the resolver sees it (HUD Rule 2; ADR-0003 Decision 2).
So the patterns here are mostly gesture patterns, not standard widgets.

**Where the list came from.** No UX specs exist yet in `design/ux/`, so
Phase 1 of the skill (catalog patterns from existing specs) found nothing.
Every pattern below is taken from the GDDs and ADRs named in the source key.

### Rules every pattern follows

These come from the resolver and apply to all patterns, so they are not
repeated in each entry.

1. **One pointer.** The first press owns the gesture. Other fingers are dropped. A resting palm on nothing real is replaced by the next press (Input Rule 1).
2. **Winners fixed at press.** The best tap target and best drag target are chosen at press and never change for that gesture (Input Rule 2). A gesture reaches only its own class winner, or nothing (Input Rule 4).
3. **Tap vs drag is distance only.** No duration limit, no long press, no double tap. `tap_slop` 28 units when a real tap target is under the press, `drag_slop` 15 otherwise (Input Rule 3, Tuning Knobs).
4. **Slide off to abort.** A tap released outside its frozen disc does nothing (Input Rule 5).
5. **A miss is silent, except on the ground.** Wrong-class presses produce no feedback (Input Game Feel). Only Ground Tap Rejection draws a cue.
6. **Press feedback on the press** for the hero and the ready burst button; everything else answers the classified gesture (Input Game Feel).
7. **Host cancel only.** App pause, focus loss, Android back and resize cancel the gesture; nothing ever fires from a cancel (Input Rule 7; ADR-0003 Decision 6).
8. **Touch target floor 48 dp (72 units)**, checked by `target_ok` (Concept Pillar 4; Input Formulas).
9. **Reduce Motion** removes slides, nudges, snaps and pulses; fades and clock bars stay (HUD UI Requirements; ADR-0011 Decision 8).
10. **Left-handed** mirrors only the burst button and its digit (HUD Edge Cases; Hero UI Requirements).
11. **Edge and safe-area presses** never reach the resolver (Input Rule 12; ADR-0003 Decision 5).

### How to Use This Library

**Designing a screen**: check the catalog before inventing an interaction. Reference patterns by name. If none fits, add one here first.

**Implementing a screen**: look up the named pattern here. Accessibility notes are not optional.

**Reviewing a spec**: every interactive element must name a pattern from this library or carry its own full spec.

**Changing a pattern**: search all specs for its name, check the impact, get ux-designer approval, and update this file first.

---

## Pattern Catalog

### Pattern Catalog Index

| Pattern Name | Category | Description | Used In (Screens) | Status |
|-------------|----------|-------------|------------------|--------|
| Slot Tap | Input | Tap an empty slot to open the build arc | Battle | Draft |
| Build Arc | Input / Overlay | Three role discs above a slot; tap one to build | Battle | Draft |
| Arc Dismiss | Input | Any press outside the discs closes the arc and does nothing else | Battle | Draft |
| Tower Tap and Cost Chip | Input / Feedback | Tap a tower to show its upgrade cost and a 1.5 s window | Battle | Draft |
| Chip Commit | Input | Second tap on the tower or chip inside the window upgrades | Battle | Draft |
| Max-Level Inspect | Feedback | Tap a level-2 tower to show its range ring | Battle | Draft |
| Refused Purchase | Feedback | What a tap on something you cannot afford does | Battle | Draft |
| Hero Press (Leash Show) | Feedback | Touching the hero shows its leash at once | Battle | Draft |
| Hero Pin Drag | Input | Drag the hero and release to pin it | Battle | Draft |
| Burst Aim Drag | Input | Drag from the burst button to aim, release to fire | Battle | Draft |
| Burst Cancel | Input | Drag back onto the button and release to cancel | Battle | Draft |
| Burst Dead Press | Feedback | Tap, cooling press or locked press on the burst button | Battle | Draft |
| Armed Button | Input | A button that ignores presses for 300 ms after appearing | Start/Call, Retry, Play again | Draft |
| Start / Call | Input | One button: start wave 1, or call the next wave early | Battle | Draft |
| Ground Tap Rejection | Feedback | Dim ring for the first three empty taps of a battle | Battle | Draft |
| Prompt Line | Feedback | One line naming the next verb, hidden on the act | Battle | Draft |
| Modal Screen | Modal | Full-screen Control that takes every event | Result, Paused | Draft |
| Result and Retry | Modal | Plain result text with one filled button | Result (Lost, Won) | Draft |
| Resume Tap | Modal | Tap anywhere to leave Paused | Paused | Draft |
| Lifecycle Cancel | Navigation | Focus loss or back cancels any gesture and pauses | All | Draft |

**Template patterns not used at MVP.** Button (Primary, Secondary,
Destructive), Toggle, Slider, Dropdown, List Item, Grid Item, Confirmation
Dialog, Toast, Tooltip, Progress Bar, Input Field, Tab Bar, Scroll Container,
Inventory Slot, Health Bar, Minimap, Quest Tracker, Dialogue Box, Context Action
Prompt, Damage Number, Status Effect Icon, Notification Banner, Screen
Push/Pop/Replace, Tab Switch, Focus Management, Escape/Cancel (keyboard form),
Loading State, Empty State, Error State, Optimistic UI. MVP has no menus,
settings or text entry (HUD Deliberately not built; Flow Deliberately not
built). Tooltip in particular is ruled out on touch (template: "touch-only
platforms without hover"). Damage Number is ruled out by HUD Rule 4. They
return with Menu & Screen Flow and Settings (Gaps section).

---

## Patterns

Each entry gives **Trigger**, **Feedback**, **Failure** (what happens when the
gesture is wrong, late or refused) and **Accessibility**.

### Slot Tap

**Category**: Input
**Status**: Draft
**Used In**: Battle
**Source**: Tower Rule 7, Rule 17 (`slot_tapped`); HUD Rule 6; Input priority table (slot TAP 200)

- **Trigger**: tap on an empty build slot (disc radius 36, TAP 200). Towers and slots share a tier; nearest centre wins.
- **Feedback**: the Build Arc opens above the slot on the next frame (HUD Game Feel). Slot shows its selected outline at alpha 0.6 (AB §8 checklist).
- **Failure**: release outside the disc does nothing (slide-off). A built slot is disabled and its tower takes the press (Input Edge Cases). A drag from a slot is never a pin unless the hero is under it (Input Rule 4).
- **Accessibility**: 48 dp target. Free vs blocked slot is told by corner dots vs a diagonal hairline, not colour (AB §6).
- **When to use**: the only way to start a build.
- **When NOT to use**: never chain a build from a slot tap alone; a disc tap is always the second step.

### Build Arc

**Category**: Input / Overlay
**Status**: Draft
**Used In**: Battle
**Source**: HUD Rules 6 to 8, Formulas `arc_disc`; Tower Rule 7; AB §7 Build/upgrade affordance

- **Trigger**: opened by Slot Tap. Three discs (TAP 300, radius 36) at radius `R` 76 above the slot, always triangle, hexagon, square, left to right, both hands. Tap a disc to call `build`.
- **Feedback**: each disc shows a tower-size polygon with a cyan contour and a 60 x 44 panel with its word and cost (Single, Splash, Slow). On `OK` the arc collapses in 120 ms (art only; it unregisters at once) and the tower appears with a white overlay, scale 1.15 to 1 in 120 ms (Tower Visual/Audio). One range ring per distinct level-1 range shows while open (Tower Visual/Audio).
- **Failure**: a disc press within 200 ms of opening is ignored, so a double tap on the slot dismisses instead of buying (HUD Rule 6). Unaffordable discs are dimmed and struck through, and a tap on one follows Refused Purchase. `HALTED` closes the arc. Start/Call is disabled while the arc is open (HUD Rule 6).
- **Accessibility**: fixed disc order builds motor memory. Role is shape plus word, never colour alone. Adjacent discs are only 4 units apart, under the proposed 8 dp gap (accessibility doc, Target spacing); first fallback is a larger `R` (HUD Open Questions). Under Reduce Motion the collapse and build scale are replaced by a cut, keeping the white overlay as a 120 ms fade (proposed static fallback; Tower UX flag asks for one).
- **When to use**: choosing a tower for one slot.
- **When NOT to use**: never place the arc below the slot (thumb side) (AB §7).

### Arc Dismiss

**Category**: Input
**Status**: Draft
**Used In**: Battle
**Source**: HUD Rule 8; Input priority table (backdrop TAP 250 sink); Input Edge Cases (arc open)

- **Trigger**: any press while the arc is open whose best tap is not one of its discs: ground, another slot, a tower. Also `drag_started` (for example a drag to the hero), Paused, an outcome or Fatal.
- **Feedback**: the arc closes on the press. Nothing else happens: a tap on another slot does not open its arc, so the thumb never acts on a target 10 dp from the one it meant.
- **Failure**: none to the player; the next tap opens the new arc. A finger rolling off a disc leaves the arc open. A phase change among Build, Wave and Intermission leaves it open.
- **Accessibility**: no rejection ring for a dismissal (HUD Rule 14), so the ring stays a cue only for empty taps. Zero mis-fires outranks one saved tap (Input Edge Cases).

### Tower Tap and Cost Chip

**Category**: Input / Feedback
**Status**: Draft
**Used In**: Battle
**Source**: Tower Rule 8; HUD Rule 9, Formulas `chip_bar`; AB §7

- **Trigger**: tap on a tower below its last level (TAP 200).
- **Feedback**: a 76 x 44 chip panel above the tower at (x, y − 76) with the cost (16 dp), a 20 px cyan level-2 polygon and a neutral bar draining over 1.5 s. Current range ring plus next range at alpha 0.25 (Tower Visual/Audio). The chip is its own disc (TAP 300, radius 40).
- **Failure**: the window expires at 1.5 s and the chip closes; a later tap opens a new chip and never commits. A press on anything else closes it; a press on another tower opens that tower's chip. Paused, Won, Lost and Fatal close it (Tower Rule 8 table).
- **Accessibility**: the bar gives the window a visible clock (HUD Rule 9). The chip sits above the thumb so it can be seen. Open points from the Tower UX flag: does the bar read under a thumb, and what does a chip that would leave the field do. The 1.5 s window is the only timed input; a timing multiplier is proposed for Alpha (accessibility doc).

### Chip Commit

**Category**: Input
**Status**: Draft
**Used In**: Battle
**Source**: Tower Rule 8; Input Rule 8; Concept MVP item 6

- **Trigger**: a second tap on the same tower, or on its chip, released with `200 ≤ elapsed < 1500` ms.
- **Feedback**: upgrade on the next frame. The tower gains its inset outline at 60% scale with the white overlay (Tower Visual/Audio). Range ring shows 400 ms then fades over 200 ms.
- **Failure**: taps under 200 ms are ignored, a hard bounce guard. `NO_GOLD` keeps the chip open and dimmed; the window does not restart (Refused Purchase). A drag that starts on the tower (hero beneath) never commits, since the window counts taps only (Input Edge Cases).
- **Accessibility**: the chip is the mis-spend safeguard instead of a modal (AB §7). Open: an armed look after the 200 ms guard (Tower UX flag). **Proposed:** the chip outline goes from 1 px to 2 px at 200 ms, a weight change with no motion, so it also works under Reduce Motion.

### Max-Level Inspect

**Category**: Feedback
**Status**: Draft
**Used In**: Battle
**Source**: Tower Rule 8 (`tower_inspected`); HUD Rule 9; Tower UI Requirements

- **Trigger**: tap on a level-2 tower.
- **Feedback**: its range ring for 1.5 s. No chip opens.
- **Failure**: none.
- **Accessibility**: makes the tap not silent. Open: a maximum-level cue beside the ring (Tower UX flag). Level is already shown by shape (inset outline), not colour (AB §3 Accretion).

### Refused Purchase

**Category**: Feedback
**Status**: Draft
**Used In**: Build Arc, Chip Commit
**Source**: Tower UI Requirements; HUD Rule 7 (`NO_GOLD` nudge); AB §7 ("no magenta")

- **Trigger**: tap on an unaffordable disc, or a chip commit that returns `NO_GOLD`.
- **Feedback**: the item stays dimmed and struck through, updated live as gold changes. A ±2 px nudge once for 120 ms. No magenta (danger only).
- **Failure**: nothing is bought; the arc or chip stays open. A disc that becomes affordable works at once (HUD Edge Cases).
- **Accessibility**: under Reduce Motion the nudge is skipped (Tower UI Requirements), which would leave no cue. **Proposed static cue:** the struck cost and its line show at full alpha for 300 ms, then return to dim. One step up and one down, no movement, no repeat, so it is not a flash. Dimmed alpha proposed at 0.6 for 4.5:1 contrast (accessibility doc).

### Hero Press (Leash Show)

**Category**: Feedback
**Status**: Draft
**Used In**: Battle
**Source**: Input Rule 2 (`pressed`, `became_idle`), Visual/Audio table; Hero Visual/Audio; AB §3 Line styles

- **Trigger**: any press whose best drag is the hero (DRAG 200, radius 56), including a tap on the hero alone.
- **Feedback**: dashed leash ring (2 px, 10 on 8 off, radius 90, alpha 0.5) on the first frame of the press. Hidden on `became_idle`.
- **Failure**: a tap on the hero alone does nothing but show the leash (Concept Pillar 4). A tower or slot under the hero still wins the tap (Input Edge Cases).
- **Accessibility**: answering on press tells the player "this is yours" before tap vs drag is known. Over the path the leash is two-tone or alpha 0.7 to clear 3:1 (AB §7). Unpinned hero shows a dashed ring at its grab radius instead, plus the "Drag the hero" prompt (Hero Visual/Audio).

### Hero Pin Drag

**Category**: Input
**Status**: Draft
**Used In**: Battle
**Source**: Hero Rules 1 to 3, 14, 15; Input Rules 3, 6; AB §5 Pose language

- **Trigger**: press inside the hero's 56-unit grab disc and move past slop (15 units on a clear hero; 28 if a tap target is also under the press). Release sets the pin.
- **Feedback**: during the drag, leash plus a 2 px unfilled kite ghost at the clamped pin point; the leash carries it since the thumb hides the ghost. On release a 2 px ground ring (radius 30) lands at once and the leash snaps to the pin; the hero walks there at 240 units per second, tip locked on the pin. On arrival the hero shrinks 6% for 0.1 s (Hero Visual/Audio).
- **Failure**: a pin off the field, in a button's exclusion zone or outside `pin_rect` is clamped, never refused, so the ghost always shows where it lands (Hero Rule 14). A cancel mid-drag keeps the old pin (Input Rule 7). Once a drag, always a drag; wobbling back does not make it a tap (Input Game Feel).
- **Accessibility**: no re-pin cooldown (Hero Rule 3). The hero outranks both buttons inside its grab disc, because a wrong re-pin is cheap and a wasted burst or call is not (Hero Rule 15). `pin_offset` is 0 at MVP; a 105-unit offset waits for the phone test. Open: re-grabbing a hero pinned high on the screen with one thumb (Hero UX flag). Under Reduce Motion the arrival shrink is a cosmetic transform that should be skipped (proposed; Hero's Reduce Motion row does not list it).

### Burst Aim Drag

**Category**: Input
**Status**: Draft
**Used In**: Battle
**Source**: Hero Rules 6, 7, 11 to 13; Input Visual/Audio table; AB §7 Burst button, Reticle

- **Trigger**: press on the burst button (DRAG 100, radius 48) while Ready, pinned and not in Build, then drag past 64 units from the button's centre. Release fires at the aim point.
- **Feedback**: on press, a thin ring at radius 64 (the cancel boundary) plus a cancelling reticle, as the drag affordance (Hero UI Requirements). While aiming: reticle (3 px ring, four ticks) 100 units above the finger, solid radius preview, neutral dotted reach ring around the hero, and kill preview on enemies that would die. At the reach limit the reticle stops and ±20° of the reach arc turns solid. On release: wind-up, the gold ring grows to meet the preview, spokes to each kill (Hero Visual/Audio).
- **Failure**: a release under 64 units that never passed 64 cancels (Burst Cancel). The aim is clamped to reach, so a person never gets `OUT_OF_REACH` (Hero Edge Cases). Paused during an aim cancels it; nothing fires (Hero Edge Cases). A burst on nobody still spends the cooldown; the preview showed no victims first.
- **Accessibility**: drag-only, so a resting thumb never spends the cooldown (Concept Core Mechanic 2). Reticle offset keeps the aim out from under the thumb. Kill preview uses a knocked-out body plus white contour, not colour. Under Reduce Motion: no field dip, wind-up, snap or Ready pop; a static ring from T+0.1 and 4 px at release; spokes stay (Hero Visual/Audio). The 0.4 s field dip never re-dips within 1 s (AB §7). Open: reticle far from the thumb when clamped, preview overhanging the reach ring, ring clipping at 540 wide, reach-dot contrast (Hero UX flag).

### Burst Cancel

**Category**: Input
**Status**: Draft
**Used In**: Battle
**Source**: Hero Rule 13; Input Rule 7; AB §7 Reticle

- **Trigger**: during an aim, bring the finger back to 48 units or less from the button's centre and release there. Every aim starts in the cancelling state until it passes 64.
- **Feedback**: while cancelling the reticle drops to alpha 0.3 with no ticks, and the preview and kill marks hide, so an aim that will cancel never looks live. On release everything clears; nothing fires.
- **Failure**: none. A cancel is free; there is no cancel after release (Hero Rule 6).
- **Accessibility**: hysteresis (stop at 64, resume at 48) stops a shaky thumb from flickering between states. The cancel state is shown by alpha plus missing ticks plus a hidden preview, not by colour.

### Burst Dead Press

**Category**: Feedback
**Status**: Draft
**Used In**: Battle
**Source**: Hero Rule 11, UI Requirements; Input priority table (sink TAP 400); Input Edge Cases

- **Trigger**: (a) a tap on the button, (b) a press while Cooling, (c) a press while Locked (Build, or before a first pin).
- **Feedback**: (a) nothing; the sink takes the tap so nothing beneath is reached. (b) the seconds digit on a panel above the thumb. (c) the dotted outline nudges ±2 px once for 120 ms; before a first pin it also repeats the "Drag the hero" prompt.
- **Failure**: the press stays dead even if cooling ends during it; press again (Input Edge Cases). There is no queue.
- **Accessibility**: Ready, Cooling and Locked differ by fill, wedge, digit and dotted outline (AB §7). Under Reduce Motion the Locked nudge is skipped (Hero UI Requirements); the repeated prompt still tells the player why. **Proposed:** under Reduce Motion the Locked press shows the dotted outline at full alpha for 300 ms, the same static cue as Refused Purchase. The cooling digit is hidden under the thumb while pressed; accepted by AB §7 but to be device-tested.

### Armed Button

**Category**: Input
**Status**: Draft
**Used In**: Start / Call, Retry, Play again
**Source**: HUD Rule 11, States and Transitions; Flow Game Feel

- **Trigger**: a button goes Hidden, then Arming for 300 ms of real time, then Armed. It registers when it appears, not when it arms.
- **Feedback**: alpha 0.5 while Arming, reaching full at 300 ms (HUD Visual/Audio).
- **Failure**: a press that starts during Arming is dead, even if released once Armed. A press begun before the button appeared cannot win (Input Rule 2). The clock is clamped to 100 ms per frame, so a hitch cannot arm an unseen button. Paused freezes the clock; a return from Paused is not a new appearance.
- **Accessibility**: stops a resting thumb from firing a button that appeared under it. Arming text at alpha 0.5 is a 300 ms transient and is exempt from the contrast target (proposed). Under Reduce Motion the fade stays, since fades are kept (HUD UI Requirements).

### Start / Call

**Category**: Input
**Status**: Draft
**Used In**: Battle (Build and Intermission)
**Source**: HUD Rule 10, Layout; Tower Rule 16; Flow Rule 9

- **Trigger**: tap the button at (186, 800), rect 88 x 72, hit radius 48, same place for both hands. Build: "Start". Intermission: "Call +N" (bare "Call" at bonus 0). Hidden in Wave. Follows Armed Button.
- **Feedback**: the wave starts and the button hides. In Intermission the button shows the seconds left and a small burst glyph matching the burst state.
- **Failure**: disabled while an arc is open (HUD Rule 6). A press inside the hero's grab disc belongs to the hero: its tap is ignored and its drag re-pins (HUD Rule 10). A late tap after the countdown ends is ignored (HUD Edge Cases).
- **Accessibility**: once armed it has no pulse, warning or advice; it shows numbers only, so it never hurries the player (HUD Rule 10). Build has no timer at all, so the player can read the board as long as needed (Concept Mechanic 3). Two 14 dp lines in 88 units need a render test (HUD Manual).

### Ground Tap Rejection

**Category**: Feedback
**Status**: Draft
**Used In**: Battle
**Source**: HUD Rule 14; Input Rule 5; AB §7 Ground tap

- **Trigger**: a tap with no tap or drag winner (`ground_tapped`).
- **Feedback**: for the first three in a battle only, a 2 px neutral ring, radius 16, alpha 0.35, fading in over 150 ms, unanimated otherwise. No sound. Resets on retry.
- **Failure**: none; it is the failure cue.
- **Accessibility**: tells new players the touch was seen but does nothing, without looking like a button. A fade, so it stays under Reduce Motion.

### Prompt Line

**Category**: Feedback
**Status**: Draft
**Used In**: Battle (Build, Wave, Intermission)
**Source**: HUD Rule 13, Layout; Hero UI Requirements

- **Trigger**: first match of: hero unpinned, "Drag the hero"; no tower in Build or Intermission, "Tap a slot to build"; in Wave with burst Ready and none fired, "Drag from the big button".
- **Feedback**: one 14 dp line on a 300 x 34 panel below the top band.
- **Failure**: hides on the act, never on a timer. No arrows, pauses or captured input. Not shown on an outcome.
- **Accessibility**: no reading-time pressure. Teaches verbs only. Above `I_top` 68 units the panel may overlap the lane; Mobile Platform owns that (HUD Layout).

### Modal Screen

**Category**: Modal
**Status**: Draft
**Used In**: Result, Paused
**Source**: HUD Rule 2; Input UI Requirements; ADR-0003 Decision 2

- **Trigger**: mounted at an outcome or on Paused.
- **Feedback**: a full-screen Control that consumes every event before the resolver, so a tap on it can never reach a tower or the hero.
- **Failure**: a Control fires only on a release whose press it saw while Armed, and clears that press on a lifecycle signal, so a thumb held across a screen change cannot fire it. Whether the engine helps here is unverified in 4.7; the rule holds either way (HUD Rule 2).
- **Accessibility**: these are the only Controls, so they are the only candidates for AccessKit names (accessibility doc, Platform table, NOT SOURCEABLE on mobile).

### Result and Retry

**Category**: Modal
**Status**: Draft
**Used In**: Result (Lost, Won)
**Source**: HUD Rules 15, 16, 18, Layout; Flow Rule 16; AB §2 Defeat

- **Trigger**: an outcome. Text shows 400 ms after Lost, 1000 ms after Won. Retry (Lost) or Play again (Won), 128 x 72, follow Armed Button.
- **Feedback**: plain 16 dp text, left-aligned, fixed order, same weight: what happened, a next-try line if any, what got through, damage by source as whole numbers. On Lost, Retry is the only filled shape. On Won, a compact panel at the bottom so the finished build stays visible.
- **Failure**: Retry sets a latch; a second tap does nothing (HUD Rule 18). Retry rebuilds the battle in Build.
- **Accessibility**: no auto-dismiss. No percentages, bars or ranking. Next-try lines avoid "you" and past tense (HUD Game Feel). Retry is one tap.

### Resume Tap

**Category**: Modal
**Status**: Draft
**Used In**: Paused
**Source**: HUD Rule 17; Flow Rule 17

- **Trigger**: release of a press the Paused screen saw, anywhere on screen.
- **Feedback**: a static 40% scrim and "Paused. Tap to resume" on a 300 x 64 panel. Instant, no countdown.
- **Failure**: the resume tap reaches nothing beneath. A finger held across the pause stays dead until lifted.
- **Accessibility**: the whole screen is the target, so there is no precision needed. Static, so nothing changes under Reduce Motion. There is no manual way to enter Paused at MVP (accessibility doc, Known Intentional Limitations).

### Lifecycle Cancel

**Category**: Navigation
**Status**: Draft
**Used In**: All
**Source**: Input Rule 7; ADR-0003 Decisions 2 and 6; Flow Rule 17

- **Trigger**: app pause, focus loss, Android back, a viewport resize, or an OS touch-cancel of the active finger.
- **Feedback**: the gesture ends with no action. Focus loss enters Paused (Resume Tap). An aim or drag in progress is dropped; the hero keeps its old pin, the burst does not fire.
- **Failure**: none to the player by design: a release is never made up from a cancel.
- **Accessibility**: Android back does not quit (`quit_on_go_back=false`, ADR-0003 Decision 4). There is no back or escape navigation at MVP because there are no menus.

---

## Animation Standards

Values from AB §7 and the GDDs. They replace the template's generic table.

| Animation Type | Duration (ms) | Easing Function | Notes |
|---------------|--------------|----------------|-------|
| Press response, state change | 120 | ease-out in, ease-in out | AB §7 |
| Arc collapse, build and upgrade overlay | 120 | ease-out | HUD Rule 7; Tower Visual/Audio |
| Button arming fade | 300 | linear | HUD Rule 11 |
| Panel in or out, 12-unit slide | 200 | ease-out in, ease-in out | AB §7; HUD UI Requirements |
| Lost dash fade | 200 | linear | AB §7 |
| Ground ring fade-in | 150 | ease-out | HUD Visual/Audio |
| Refusal nudge ±2 px | 120 | once | Tower UI Requirements |
| Chip bar drain, cooldown wedge, tower ring regrow | real time | linear (clock) | AB §7 |
| Range ring after build | 400 hold, 200 fade | linear | Tower Visual/Audio |
| Burst field dip | about 400 | n/a | Never re-dips within 1 s (AB §7) |
| Danger pulse | 2 Hz | n/a | Alpha swing at most 25% (AB §7) |

Never animated: leash, panel opacity, counter values (digits swap) (AB §7).
Nothing in screen space loops or glows.

**Motion reduction overrides**: with `reduce_motion` on, slides, nudges, the
burst dip, wind-up, snap and Ready pop are removed and the danger pulse
freezes; fades and clock bars stay (HUD UI Requirements; Hero Visual/Audio;
AB §7). Where a removed motion was the only cue, the pattern names a static
replacement (Refused Purchase, Burst Dead Press).

---

## Sound Standards

No audio at MVP (HUD, Hero, Tower, Input Visual/Audio). The ground tap is
silent by design (Input Visual/Audio). When the Audio system arrives (Alpha),
every sound must have a visual that already carries the same fact
(accessibility doc, SFX audit). Sound categories are set by the Audio GDD, not
here.

---

## Gaps & Patterns Needed

| Gap | Needed By | Notes |
|-----|-----------|-------|
| Menu buttons, focus order, back navigation | Menu & Screen Flow (Vertical Slice) | Template Button, Screen Push/Pop and Escape patterns return here. |
| Settings controls (toggle, slider) for Reduce Motion, left hand, slop, hit scale, chip multiplier, volume | Settings & Accessibility (Alpha) | The two flags exist as data only (HUD UI Requirements). |
| Skill tree node tap and respec | Skill Tree (Vertical Slice) | Node grammar exists in AB §3; available-node pulse must honour Reduce Motion. |
| Stage preview and stage select | Stage Progression (Vertical Slice) | |
| Pause button | Proposed for Vertical Slice | Accessibility doc, Known Intentional Limitations. |
| Tap alternative to drag for burst and pin | Settings (Alpha) | HUD Dependencies: "an alternative path to discs". |
| Static fallbacks for build overlay and arc collapse | Battle HUD stories | Tower UX flag. Proposed in Build Arc above. |
| Chip leaving the field; armed chip look | Battle HUD UX spec | Tower UX flag. Armed look proposed in Chip Commit above. |
| UX specs for arc, chip, Start/Call, result, pin and aim | Before epics | HUD and Hero UX flags. Each should reference patterns here by name. |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Do adjacent arc discs 4 units apart cause wrong-disc mis-fires? Fallback: larger `R`. | ux-designer, Pillar 4 phone test | First phone build | Unresolved |
| Accept the proposed static cues (300 ms full alpha) for Refused Purchase and Locked press under Reduce Motion? | art-director, ux-designer | Before HUD stories | Unresolved |
| Accept the proposed armed chip look (outline 1 px to 2 px at 200 ms)? | art-director | Before Tower stories | Unresolved |
| Should the hero's arrival shrink be skipped under Reduce Motion? Hero's row does not list it. | game-designer, ux-designer | Before Hero stories | Unresolved |
| Does `pin_offset` 0 work on a phone, or is 105 needed? | Pillar 4 phone test | First phone build | Unresolved |
| Does the cooling digit hidden under the thumb confuse players? | Pillar 4 phone test | First phone build | Unresolved |
| Does a held press on a Control survive a screen change in Godot 4.7? NOT SOURCEABLE in `docs/engine-reference/godot/`; HUD ADR must check. | technical-director | Before HUD stories | Unresolved |
