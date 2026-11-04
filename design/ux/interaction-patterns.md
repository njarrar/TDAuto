# Interaction Pattern Library

> **Status**: In Design (written in autonomous mode; not yet user-approved or `/ux-review`ed)
> **Author**: njarrar + ux-designer
> **Last Updated**: 2026-11-04
> **Version**: 1.0
> **Engine**: Godot 4.7.2
> **UI Framework**: Godot Control nodes for modal screens and the top band only; every in-battle action is an Input disc drawn by one `_draw` node (Battle HUD Rule 1, Rule 2)
> **Platform Target**: Mobile portrait (iOS, Android), one thumb, touch only. Desktop build uses mouse as touch for development. Gamepad: none. Keyboard: none. (Source: `.claude/docs/technical-preferences.md` § Input & Platform; `project.yaml` has no `platform` block.)
> **Related Documents**:
> - `design/art/art-bible.md`: visual standards (§3 sizes, §4 colour, §7 UI)
> - `design/accessibility-requirements.md`: accessibility commitments per feature
> - `design/gdd/input-gesture-resolver.md`, `battle-hud.md`, `tower-system.md`, `hero-system.md`: the rules these patterns restate
> - `design/ux/[screen].md`: no screen specs exist yet
>
> **Template**: Interaction Pattern Library

> **Why this document exists**: a screen spec should be able to say "uses Armed Button" instead of restating arming, press rules and feedback. This library names the interactions the MVP GDDs already define, in one place. **It adds no mechanic.** Every rule here cites the GDD rule it comes from; where a GDD and this file differ, the GDD wins and this file is the one to fix.
>
> **Status definitions**: **Draft**: specified, not built or validated. **Stable**: built and passed the Pillar 4 phone test. **Deprecated**: being phased out.

---

## Overview

TowerRiot is played with one thumb on a 540 x 960 portrait field. The concept's Pillar 4 (Thumb-First) sets the whole interaction vocabulary: every action is one tap or one drag, no target is under 48 dp, and there is no long press, double tap or two-finger gesture. The game has four verbs: **pin** the hero (drag), **aim the burst** (drag), **build** (tap a slot, then tap a disc) and **upgrade** (tap a tower, then tap again inside a window). Two buttons support them: Start/Call and Retry or Play again.

So this library is small and specific. It is not a menu library. The template's standard control set (Toggle, Slider, Dropdown, Tab Bar, Tooltip, Input Field and the rest) has no use at MVP: there is no settings screen, menu or text entry until Vertical Slice and Alpha (Battle HUD, "Deliberately not built for MVP"). Those patterns are listed under Gaps, not specified.

Three ideas run through every pattern below:

1. **One resolver decides.** The Input & Gesture Resolver turns a press, a movement and a release into exactly one tap, one drag or nothing, sent to exactly one target chosen at press. Owners decide what that gesture means. A pattern never reads raw touch events.
2. **Mistakes that cost gold or a cooldown are made hard; mistakes that cost a moment are allowed.** A wrong re-pin is undone in a second, so the hero wins overlaps. A wave called, a burst spent or a tower bought cannot be undone, so those need a clean tap from an armed target, a guard delay or a second tap (Hero Rule 15).
3. **Answer on the press, stay silent on a miss.** The thing under the thumb answers on the first frame of the press where the GDDs say so. A gesture that reaches nothing makes no sound and, except on open ground, no mark (Input, Game Feel).

### How to Use This Library

**Designing a screen**: reference a pattern by name ("Start/Call uses Armed Button"). If no pattern fits, add one here first, and cite the GDD rule it comes from.

**Implementing**: the Specification lists are the contract. Engine notes say what is sourced from `docs/engine-reference/godot/` and what is NOT SOURCEABLE and waits on an ADR.

**Reviewing**: an interactive element with no pattern name and no full specification fails review. So does a pattern that adds a gesture the resolver does not produce.

**Changing a pattern**: change the owning GDD first, then this file, then every spec that names the pattern.

---

## Pattern Catalog

There is no player journey map (`design/player-journey.md`) and no UX screen spec yet, so the catalog was built from the four GDDs named in the header, not from specs. Phase 1 of the pattern workflow ("catalog patterns used in existing specs") found nothing to read; this is recorded under Open Questions.

### Pattern Catalog Index

| # | Pattern Name | Category | Description | Used In | Status |
|---|---|---|---|---|---|
| P1 | Gesture Resolution | Input | Press, move, release become one tap, one drag or nothing, sent to one target fixed at press | Every battle interaction | Draft |
| P2 | Hit Disc | Input | Circular touch target with a radius, a class (TAP or DRAG) and a priority; 48 dp floor | Hero, burst button, towers, slots, arc discs, chip, Start/Call | Draft |
| P3 | Tap Sink | Input | A disc that absorbs taps and does nothing, so nothing beneath can receive them | Burst button sink, arc backdrop | Draft |
| P4 | Drag to Place (Hero Pin) | Input / Game-Specific | Drag the hero; a ghost and leash follow; release commits the pin | Battle field | Draft |
| P5 | Offset Aim with Cancel Ring (Burst) | Input / Game-Specific | Drag from the burst button; reticle sits 100 units above the thumb; drag back inside the ring to cancel | Burst button | Draft |
| P6 | Radial Choice Arc (Build) | Input / Overlay | Tap a slot, three role discs open above it, tap one to build | Build slots | Draft |
| P7 | Two-Tap Commit Window (Upgrade Chip) | Input / Overlay | Tap a tower opens a 1.5 s chip; a second tap inside 200 to 1,500 ms upgrades | Towers below last level | Draft |
| P8 | Armed Button | Input | A button that registers on appearing and accepts taps only after 300 ms | Start/Call, Retry, Play again | Draft |
| P9 | Refused Press Nudge | Feedback | A press the owner refuses moves the element ±2 px once for 120 ms | Locked burst button, unaffordable arc disc and chip | Draft |
| P10 | Unaffordable State | Data Display | Dimmed to alpha 0.55 and cost struck through, updated live | Arc discs, chip | Draft |
| P11 | Cooldown Readout | Data Display / Game-Specific | Burst button as full ring, wedge with digit, or dotted outline; Ready ticks around the hero | Burst button, hero, Start/Call glyph | Draft |
| P12 | Ground Tap Ring | Feedback | A dim ring for the first three empty-ground taps per battle, then nothing | Battle field | Draft |
| P13 | Silent Miss | Feedback | A gesture that reaches no target gives no feedback (except P12) | Every disc | Draft |
| P14 | One-Line Prompt | Feedback / Onboarding | One line in the top band teaching a verb; hides on the act, never on a timer | Top band | Draft |
| P15 | Display-Only Top Band | Data Display | Lives dashes, wave pips, gold digits; ignores input | Top band | Draft |
| P16 | Full-Screen Modal Control | Modal | A Control over the whole screen that eats every event; fires only on the release of a press it saw while armed | Result (Lost, Won), Paused | Draft |
| P17 | Lifecycle Cancel | Navigation | App pause, focus loss or resize cancels the live gesture and closes the arc and chip | Every state | Draft |

---

## Patterns

### P1. Gesture Resolution

**Category**: Input
**Used In**: every battle interaction
**Source**: Input & Gesture Resolver, Core Rules 1 to 7, Formulas (`is_drag`)

**Description**: the one rule set that turns a thumb's press into a game action. Every other input pattern in this file sits on top of it. Players never see it; they feel it as "the game did what I meant".

**Specification**:
- **One pointer.** The first press is the active pointer. Other touches are dropped, so a palm cannot cancel an aim or count as a tap. Exception: a press that nothing is waiting on (no real tap winner, unmoved, or dead) is replaced by the next press, so a resting palm cannot block the thumb (Rule 1).
- **Winners fixed at press.** At press the resolver picks the best TAP target and the best DRAG target under the thumb. Ties break by priority, then nearer centre, then earlier id. Nothing that happens later re-targets the gesture (Rule 2).
- **Tap or drag by distance only.** Slop is `tap_slop` (default 28 units, 18.7 dp at 360 dp) when the press has a real tap winner or no winner, and `drag_slop` (default 15 units, 10 dp) otherwise. Moving past slop with a drag winner starts a drag; moving past it with no drag winner makes the press dead. Releasing under slop and inside the tap winner's disc is a tap. Rolling off the disc before release aborts the tap (Rule 3).
- **No time limit.** No long press, no double tap, no tap timeout. A press held ten seconds and released in place is a tap. The Input GDD calls this the accessibility floor (Rule 3).
- **Sticky drag.** Once a drag, always a drag; wandering back never turns it into a tap (Rule 3).
- **No fall-through.** A tap reaches only the tap winner, a drag only the drag winner, or nothing (Rule 4).
- **Cancel is the host's.** Only app lifecycle events and OS touch-cancel cancel a gesture (P17). A cancel never fires a pending action (Rule 7).
- **Feedback**: none from the resolver. Owners answer its signals (`pressed`, `tap`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `ground_tap`, `idle`).
- **Accessibility**: the no-timeout rule and slide-off abort are fixed and must not be removed. A runtime slop setter ("steady hand", x1.5) and a hit-area scale are reserved for Settings & Accessibility at Alpha (Input, Deliberately not built; Open Questions).

**When to Use**: every in-battle touch.
**When NOT to Use**: modal screens (P16), which are Controls and never reach the resolver.

**Engine notes**: which Godot input path feeds the resolver, touch event field names, touch and mouse emulation, and whether positions arrive in 540 x 960 space are NOT SOURCEABLE: `docs/engine-reference/godot/modules/input.md` does not cover touch. They belong to the Input ADR (Input, Open Questions).

---

### P2. Hit Disc

**Category**: Input
**Used In**: hero, burst button, towers, slots, arc discs, chip, Start/Call
**Source**: Input Core Rules (Hit targets table, Suggested registrations); Formulas (`target_ok`); art bible §3

**Description**: every tappable or draggable thing in battle is a circle registered with the resolver. No other shape exists at MVP. The disc is a hit area; what is drawn can be a different shape (the Start/Call rect, the arc polygons).

**Specification**:

| Target | Class | Priority | Radius (units) | Diameter at 360 dp |
|---|---|---|---|---|
| Burst button sink | TAP, sink | 400 | 48 | 64 dp |
| Start/Call | TAP | 350 | 48 | 64 dp |
| Build arc disc | TAP | 300 | 36 | 48 dp |
| Upgrade chip | TAP | 300 | 40 | 53.3 dp |
| Arc backdrop | TAP, sink | 250 | whole field | n/a |
| Tower, build slot (same tier, nearest wins) | TAP | 200 | 36 | 48 dp |
| Hero | DRAG | 200 | 56 | 74.7 dp |
| Burst button (aim) | DRAG | 100 | 48 | 64 dp |

- **Size floor**: `2 x r x field_scale >= 48 dp`. At the 360 dp minimum width a 36-unit radius is exactly 48 dp, with no margin (Battle HUD UI Requirements). Below 360 dp is unsupported.
- **Edges**: a press inside `edge_reject_margin` (36 units) of a side edge, or inside OS safe-area or gesture insets, never reaches the resolver. A drag that started elsewhere may move into them (Input Rule 12).
- **Spacing rules** live in content tests, not here: no slot disc may overlap the burst disc (L3); Start/Call keeps clear of slots, the hero start and both burst discs (`hud_call_*`).
- **Feedback**: the owner's (see each pattern).
- **Accessibility**: discs are not Controls, so they have no focus, no keyboard path and no screen reader node (see `design/accessibility-requirements.md`, Platform API).

**When to Use**: any in-battle target.
**When NOT to Use**: full-screen modals (P16).

---

### P3. Tap Sink

**Category**: Input
**Used In**: burst button sink (TAP 400), arc backdrop (TAP 250)
**Source**: Input Core Rules (`sink` field, registrations); Battle HUD Rules 6 and 8

**Description**: a disc that wins taps and does nothing with them, so a tap there cannot reach anything beneath.

**Specification**:
- The burst sink makes a tap on the burst button do nothing, so a resting thumb never spends the cooldown and a slot beneath never gets the touch.
- The arc backdrop covers the field while an arc is open, so a press outside the three discs only closes the arc. The HUD closes the arc on `pressed` and ignores the later `tap(backdrop)`.
- A sink does not raise the press's slop and does not hold the pointer against a replacing press (Input Rule 1).
- **Feedback**: none from the sink itself. A dismissal draws no ground ring (Battle HUD Rule 14).

**When to Use**: a surface that must swallow taps to protect what is under it.
**When NOT to Use**: as a way to block drags; sinks are TAP only.

---

### P4. Drag to Place (Hero Pin)

**Category**: Input / Game-Specific
**Used In**: battle field
**Source**: Hero Rules 1 to 3, 14, 15; Hero Visual/Audio; Input Visual/Audio and Game Feel

**Description**: the hero's one verb. Drag the hero to where it should stand; release to commit. The hero then walks there in a straight line at 240 units per second.

**Specification**:

| Moment | What the player sees | Source |
|---|---|---|
| Unpinned (battle start) | Dashed ring at the hero's grab radius 56, plus prompt "Drag the hero" (P14) | Hero V/A "Unpinned" |
| Press on the hero | Dashed leash ring on the first frame of the press, before tap or drag is known | Hero V/A "Press hero"; Input Game Feel |
| Drag | Leash plus a 2 px unfilled kite ghost at the clamped pin point; the leash carries it because the thumb hides the ghost | Hero V/A "Drag" |
| Release | Ground ring (2 px solid, radius 30) and leash snap to the pin; hero walks | Hero V/A "Release" |
| Arrival | Hero 6% smaller for 0.1 s | Hero V/A |
| Tap on the hero (no drag) | Leash shown, nothing else | Concept Pillar 4 |
| Lifecycle cancel mid-drag | Ghost and leash preview removed; old pin kept | Input Rule 7 |

- **Clamp, never refuse.** The ghost is clamped into `pin_rect` and out of the button exclusion zones, so the drawn ring is always where the pin lands. Only bots see refusals (Hero Rule 14).
- **Hero wins overlaps.** A press inside the hero's 56-unit disc drags the hero even over the burst button or Start/Call; the HUD ignores a Start/Call tap from the same press (Hero Rule 15; Battle HUD Rule 10).
- **Finger offset**: 0 at MVP. A 100-unit offset is an open phone-test question (Hero Open Questions).
- **Accessibility**: drag is the only way to pin. A two-tap alternative is reserved for Alpha (Input Open Questions). Re-grabbing a hero pinned near the top with one thumb is untested.

**When to Use**: placing the hero.
**When NOT to Use**: any action that spends a resource.

---

### P5. Offset Aim with Cancel Ring (Burst)

**Category**: Input / Game-Specific
**Used In**: burst button (bottom corner, dominant-hand side, mirrored for left hand)
**Source**: Hero Rules 11 to 13, Hero UI Requirements and Visual/Audio; Input Rule 6 and Visual/Audio; Battle HUD Rule 12

**Description**: drag from the burst button to aim the hero's burst. The reticle sits 100 units above the thumb so the thumb never hides it. Release fires. Dragging back to the button cancels.

**Specification**:

| Button state | Press response | Source |
|---|---|---|
| Locked (Build, or hero never pinned): dotted neutral outline, no fill or digit | Whole press dead; P9 nudge; repeats prompt 1 if it still shows | Hero Rule 11, UI Req |
| Cooling: wedge and digit | Whole press dead; seconds digit shown above the thumb, on panel | Hero Rule 11, UI Req |
| Telegraphing: empty wedge | Dead | Battle HUD Rule 12 |
| Ready | Aim arms; thin ring at `aim_ring_radius()` drawn beyond the fingertip on the first frame | Hero UI Req; Input V/A |

| Aim state | Rule | What the player sees |
|---|---|---|
| Cancelling (every aim starts here) | Finger within 64 of the button centre, or has not yet passed 64 | Ring at 64 (the line to cross), reticle alpha 0.3, no radius preview, no kill marks |
| Live | Finger has passed 64; returns to Cancelling at 48 or less | Ring redrawn at 48 (the line to cross back), reticle, 2 px radius preview, kill-preview marks |
| Clamped at reach (160 from the hero) | Aim point stops | Reticle stops; ±20° of the reach arc turns solid |

- Release while Live fires (no cancel after lift). Release while Cancelling does nothing. Lifecycle cancel does nothing (P17).
- Aim point = finger + (0, −100), clamped to the field, then to reach. No flip.
- Left hand mirrors the button and digit only, not the aim offset (Hero UI Req).
- **Accessibility**: drag-only by design: a tap on the button does nothing (P3). The cancel state is shown by ring position, reticle alpha and hidden preview, not by colour. No two-tap or switch alternative exists until Alpha.

**When to Use**: aiming the burst.
**When NOT to Use**: any other action; this is the game's one aimed drag.

---

### P6. Radial Choice Arc (Build)

**Category**: Input / Overlay
**Used In**: empty build slots
**Source**: Battle HUD Rules 6 to 8, Visual/Audio; Tower Rule 7

**Description**: tap an empty slot and three role discs open above it. Tap one to build that tower at once. There is no confirm step and no selling, so the guards matter.

**Specification**:
- **Open**: tap a slot. Three discs (TAP 300) and one field-wide backdrop (P3) register; they compete from the next press. Order is always triangle, hexagon, square, left to right, on every slot and both hands.
- **Labels**: a 60 x 30 panel above each disc shows its cost. The role words "Single, Splash, Slow" show in the prompt row while an arc is open, until the first Won this session.
- **Guard**: a disc press within 200 ms of opening is ignored, so a double tap on a slot dismisses instead of buying.
- **Build**: tap a disc. `OK` closes the arc (120 ms collapse, art only). `NO_GOLD` leaves it open with a P9 nudge. `HALTED` closes it.
- **Close**: a press on anything other than a disc; a drag start; Paused, an outcome or Fatal. Rolling off a disc leaves it open. A phase change leaves it open.
- **While open**: Start/Call is registered but disabled.
- **Unaffordable discs**: P10, updated live as gold changes.
- **Range preview**: one range ring per distinct level-1 range while open (Tower V/A).
- **Accessibility**: adjacent discs are 4 units apart; a wrong disc is a permanent mis-fire (Battle HUD Open Questions). Role is shown by shape and cost text, not colour.

**When to Use**: choosing among a small fixed set at a field location.
**When NOT to Use**: irreversible choices with more than three options, or anything that should need a confirm step.

---

### P7. Two-Tap Commit Window (Upgrade Chip)

**Category**: Input / Overlay
**Used In**: towers below their last level
**Source**: Tower Rule 8 and table; Battle HUD Rule 9; Input Rule 8

**Description**: the upgrade safeguard. A tap on a tower opens a chip; a second tap on the tower or the chip, inside a window, upgrades it.

**Specification**:
- **Open**: tap a tower below its last level. A 76 x 44 chip appears at (tower x, y − 76) with the cost, the level-2 glyph and a 3-unit bar draining over 1.5 s. The chip registers its own disc (TAP 300, radius 40).
- **Commit**: a tap on the same tower or the chip with `200 <= elapsed < 1500` ms at release calls `upgrade`.
- **Guard**: taps under 200 ms are ignored; the window keeps running.
- **Expire**: at 1,500 ms the chip closes and its disc unregisters. A tap after that opens a new chip and never commits.
- **NO_GOLD**: stays open and dimmed (P10, P9 nudge); the window does not restart.
- **Close**: a press naming another target or none; Paused, Won, Lost, Fatal. A press on another tower opens that tower's chip.
- **Last level**: a tap opens no chip; the tower's range ring shows for 1.5 s, so the tap is not silent.
- **Range preview**: current ring, plus next level's at alpha 0.25.
- **Accessibility**: the 1.5 s window is a timed input with no extension at MVP. The draining bar gives it a visible clock. See accessibility open items.

**When to Use**: an irreversible spend on an existing object.
**When NOT to Use**: first purchases (P6 builds at once).

---

### P8. Armed Button

**Category**: Input
**Used In**: Start/Call (Build and Intermission), Retry, Play again
**Source**: Battle HUD Rules 10, 11, States and Transitions, Visual/Audio

**Description**: a button that appears without warning under a thumb that may already be down, so it refuses taps for its first 300 ms.

**Specification**:

| State | Visual | Input |
|---|---|---|
| Hidden | Not drawn, not registered | n/a |
| Arming (300 ms of clamped frame time) | Alpha 0.5 rising to full | Registered; a tap from a press made now is dead, even if released once Armed |
| Armed | Full alpha, 2 px neutral outline | A new press counts |

- Registers on appearing, not on arming, so an early press cannot land on what lies beneath.
- Clock clamps 100 ms per frame and stops while Paused; a return from Paused is not a new appearance.
- **Start/Call labels**: "Start" in Build; "Call +N" in Intermission ("Call" at bonus 0), with seconds left and a burst glyph (P11) on a second line. No pulse, warning or advice.
- **Hero overlap**: a press that also names the hero as drag winner never taps Start/Call.
- **Retry / Play again**: the only filled shape on the result panel. Re-arms when the app regains focus in Won or Lost.
- **Accessibility**: label text plus fill carry the state; arming alpha is a supplement.

**When to Use**: any button that appears during play or at a phase change.
**When NOT to Use**: buttons the player opened themselves in the same gesture.

---

### P9. Refused Press Nudge

**Category**: Feedback
**Used In**: locked burst button, `NO_GOLD` arc disc, `NO_GOLD` chip
**Source**: Tower UI Requirements; Hero UI Requirements; Battle HUD Rule 7

**Specification**: the element moves ±2 px once over 120 ms. No colour change, no magenta, no sound. Skipped under Reduce Motion, where the dimmed or dotted state alone carries the meaning.

**When to Use**: a press that reached its owner but was refused.
**When NOT to Use**: a gesture that reached no target (P13).

---

### P10. Unaffordable State

**Category**: Data Display
**Used In**: arc discs, chip
**Source**: Battle HUD Rule 7, Visual/Audio; Tower UI Requirements

**Specification**: alpha 0.55 and the cost struck through, updated live on `gold_changed`. Two non-colour signals (strike and alpha). A dimmed cost must stay legible (Tower UX flag).

---

### P11. Cooldown Readout

**Category**: Data Display / Game-Specific
**Used In**: burst button, hero, Start/Call glyph
**Source**: Battle HUD Rules 10, 12; Hero Visual/Audio and UI Requirements

**Specification**:

| State | Button | Elsewhere |
|---|---|---|
| Locked | Dotted outline, no fill or digit | Start/Call glyph dotted |
| Cooling | Wedge plus seconds digit | Glyph wedge |
| Telegraphing | Empty wedge | |
| Ready | Full ring | Four static 3 px ticks around the hero (Wave and Intermission, once pinned); first frame: ticks close in, button scale 1.15 to 1 over 120 ms, once |

- Every state differs by shape (dots, wedge, ring) and the cooling state carries a number.
- Reduce Motion drops the Ready pop.

---

### P12. Ground Tap Ring

**Category**: Feedback
**Source**: Input Rule 5 and Visual/Audio; Battle HUD Rule 14

**Specification**: a tap with no winner draws a 2 px neutral ring, radius 16, alpha 0.35, 150 ms fade-in, unanimated, no sound. Only the first three per battle; none after. Reset on retry. A backdrop dismissal is not a ground tap.

---

### P13. Silent Miss

**Category**: Feedback
**Source**: Input Game Feel

**Specification**: a drag from a tower, a tap over the hero alone, a second-finger touch and a dead press produce no feedback. Silence reads as "nothing happened", which is true. Exception: P12 on open ground. This is a deliberate rule, recorded here so no screen adds rejection cues.

---

### P14. One-Line Prompt

**Category**: Feedback / Onboarding
**Used In**: top band, next-wave row
**Source**: Battle HUD Rule 13, Visual/Audio; Hero UI Requirements

**Specification**:
- One line, 14 dp, on panel, 300 x 30 at (270, `I_top + 55`). First match wins:
  1. Hero unpinned: "Drag the hero"
  2. No tower built, in Build or Intermission: "Tap a slot to build"
  3. In Wave, burst Ready and none started: "Drag from the big button"
- Hides on the act, never on a timer. No arrows, no pause, no captured input.
- Retires for the session: prompt 1 once the hero was pinned in an earlier battle, prompt 2 once a tower was built in one, both after the first Won. Flags reset on app restart.
- The row shows the arc's role words while an arc is open (P6).
- **Accessibility**: prompts teach verbs only. They cannot be recalled once retired (see accessibility open items). Placement at the top, away from the lane, is untested for whether players see it.

---

### P15. Display-Only Top Band

**Category**: Data Display
**Source**: Battle HUD Rules 1, 4, Layout, Visual/Audio

**Specification**: lives as two rows of five neutral dashes (a lost dash fades to alpha 0.2 in 200 ms, still countable); wave pips as 20 x 10 pills (filled done, outlined current, dotted upcoming); gold as 16 dp tabular digits at top right. Controls with input ignored, so a touch here reaches nothing (the band sits in the resolver's dead area). State differs by fill, outline and dots, never hue alone.

---

### P16. Full-Screen Modal Control

**Category**: Modal
**Used In**: Result (Lost, Won), Paused
**Source**: Battle HUD Rules 2, 15 to 17, Layout, Visual/Audio

**Specification**:
- A full-screen Control that consumes every event, so nothing reaches the resolver while it shows.
- Fires only on the release of a press it saw while Armed (P8). It clears that press on the lifecycle signal, so a thumb held across a screen change cannot fire it.
- **Result**: transparent modal at the outcome (input dead at once); text 400 ms after Lost, 1,000 ms after Won; all text 16 dp, left-aligned, fixed order (Battle HUD Rule 15 table); Retry or Play again is the only filled shape, 128 x 72. Lost panel y 200 to 752; Won panel compact, y 752 to 944, so the build stays visible.
- **Paused**: static 40% scrim, 300 x 64 panel, "Paused. Tap to resume". The whole screen is the target. Resumes on release, no countdown. Paused shows instantly (no motion).
- **No pause button exists at MVP**: Paused is entered only by app focus loss (Battle HUD Rule 4; Flow Rule 17).
- **Accessibility**: these are the only Controls with actions, so they are the only candidates for screen reader exposure (see accessibility doc).

**Engine notes**: Godot 4.5 added AccessKit screen reader support for Control nodes, and 4.6 split touch focus from keyboard focus (`docs/engine-reference/godot/modules/ui.md`). The architecture sets `focus_mode` NONE on these modals (`docs/architecture/architecture.md`, Engine Knowledge Gap Summary). Whether a Control with `mouse_filter` STOP hides events from the adapter is NOT SOURCEABLE (same section); the Battle HUD rule holds either way.

---

### P17. Lifecycle Cancel

**Category**: Navigation
**Source**: Input Rule 7; Battle HUD Rule 8, Edge Cases; Tower Rule 8 table

**Specification**: on app pause, focus loss or viewport resize, the adapter cancels the live gesture: a drag emits `drag_cancelled` (hero keeps its old pin, the burst does not fire), and no release is ever made up. Paused then closes any open arc and chip, so the tap that resumes reaches nothing beneath. Modal Controls clear any press they saw.

**Engine notes**: which platform notifications fire, and which enter Paused, is NOT SOURCEABLE (architecture, Engine Knowledge Gap Summary).

---

## Animation Standards

All motions are from the GDDs. Every value waits on the first phone test.

| Motion | Duration | Notes | Source |
|---|---|---|---|
| Arc open and collapse, button presses, arming | 120 ms (arming 300 ms) | Collapse is art only; targets unregister at once | Battle HUD UI Req, Rule 11 |
| Lost dash, panel slides | 200 ms | 12-unit slides; opacity fixed | Battle HUD UI Req |
| Paused | Instant | | Battle HUD UI Req |
| Build / upgrade flash | 120 ms, scale 1.15 to 1, white overlay 0.6 | One flash, not repeated | Tower V/A |
| Refused nudge | 120 ms, ±2 px once | Skipped under Reduce Motion | Tower, Hero UI Req |
| Ground ring | 150 ms fade-in | | Battle HUD V/A |
| Chip window bar | 1,500 ms linear drain | A clock, kept under Reduce Motion | Tower Rule 8 |

**Reduce Motion** (data flag until Settings at Alpha): cuts slides, nudges, the Ready pop and the burst dip, wind-up and snap; fades and clock bars stay; the burst shows a static ring from T+0.1 and 4 px at release; spokes stay (Battle HUD UI Req; Hero V/A).

---

## Sound Standards

No audio at MVP (Input, Battle HUD, Tower and Hero Visual/Audio). Every pattern above is complete with sound off, which also matches the target player, who often plays with sound off (concept, Target Player Profile). When audio arrives (Small Ship), any new sound must be a supplement: a sound that carries information needs a visual already listed here.

---

## Gaps & Patterns Needed

| Gap | Why it is needed | Owner / when |
|---|---|---|
| Alternative to drag for pin and aim (two-tap) | Drag-only verbs are a motor barrier | Settings & Accessibility GDD, Alpha (reserved in Input) |
| Settings controls (Toggle, Slider) | Left hand, Reduce Motion, steady hand, hit-area scale have no UI | Settings & Accessibility GDD, Alpha |
| Pause button and in-play pause | No way to pause except leaving the app | Flow / Menu & Screen Flow; not in any GDD yet |
| Menu navigation (Screen Push / Pop / Replace, Back) | Stage select and menus | Menu & Screen Flow, Vertical Slice |
| Fatal screen | Battle HUD names a Fatal screen that replaces the HUD but no GDD read here specs its interaction | Flow GDD / HUD spec |
| Onboarding beyond three lines; prompt recall | Prompts cannot be seen again once retired | Onboarding Prompts, Vertical Slice |
| Stage report | Replaces the result screen | Stage Progression, Vertical Slice |
| Screen reader and focus model for modals | Discs cannot be exposed; modals use `focus_mode` NONE | Accessibility open items |
| Error and Empty states | None at MVP (no lists, no saves, no network) | Revisit with menus |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| No UX screen specs and no player journey map exist, so this library was built from GDDs only. Author `design/player-journey.md` from `.claude/docs/templates/player-journey.md`, then re-check the "Used In" columns against the specs | ux-designer | Before `/ux-design hud` | Unresolved |
| Do the 15 and 28 unit slops and the 36 to 56 unit radii hold on a phone with a non-developer tester? | producer, qa-lead | First phone build (Pillar 4 test) | Unresolved |
| Arc discs 4 units apart: is a wrong-disc mis-fire seen? First fallback is a larger arc radius | Pillar 4 phone test | First phone build | Unresolved |
| Does the chip's draining bar read under a thumb, and does a dimmed cost stay legible? | art-director, phone test | First phone build | Unresolved |
| Pin finger offset 0 or 100; can a thumb re-grab a hero pinned near the top? | Hero GDD, phone test | First phone build | Unresolved |
| Is the top-band prompt seen while the eyes are on the lane? | First-run test | First playable | Unresolved |
| Is 7.2 units enough between Start/Call and the left-hand burst disc? | Pillar 4 phone test | First phone build | Unresolved |
| Input path, touch fields, emulation, stretch space and lifecycle notifications: NOT SOURCEABLE in `docs/engine-reference/godot/` | technical-director (Input ADR) | Before the first input story | Unresolved |

### Decisions taken in autonomous mode

`modes.automation` is `autonomous`, so no questions were asked. Each choice below took the recommended option. They could not be written to `production/session-logs/decision-log.md` in this run (no shell access for `log_decision`), so they are recorded here.

| Decision point | Chosen | Reason |
|---|---|---|
| Input methods (no `platform` block in `project.yaml`) | Touch only, mouse as touch on desktop; from `technical-preferences.md` | Skill fallback rule |
| How to work through patterns | Draft the full batch from the GDDs | No specs exist; all rules are already decided in GDDs |
| Template standard controls (Button variants, Toggle, Slider and so on) | Not specified; listed as gaps | No MVP screen uses them; specifying them would invent UI |
| Depth | `docs.density` thorough (from `rigor: full`) | Config resolution |
