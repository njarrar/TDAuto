# Interaction Pattern Library

> **Status**: In Design (all sections written; review owed)
> **Author**: njarrar + ux-designer (authored in session by `/ux-design patterns`, autonomous mode)
> **Last Updated**: 2026-11-04
> **Platform Target**: iOS and Android, portrait, one thumb, touch only; desktop build for testing with mouse as touch
> **Linked Documents**: `design/accessibility-requirements.md`, `design/gdd/input-gesture-resolver.md`, `design/gdd/battle-hud.md`, `design/gdd/tower-system.md`, `design/gdd/hero-system.md`, `design/gdd/game-state-stage-flow.md`, `design/art/art-bible.md`, ADR-0003, ADR-0008
> **Template**: Interaction Pattern Library

---

## Overview

This library names every interaction pattern TowerRiot already uses, so UX specs, stories and reviews can cite one ID instead of restating the rule. It adds no mechanic. Each entry points at the GDD, ADR or art bible rule that owns it, and that source wins if the two ever differ. Where two sources disagree, or a source misses a floor in `design/accessibility-requirements.md`, the entry follows the accessibility floor and the gap is logged in Open Questions as an `OI-` item. This library edits no GDD.

**Input.** Touch only; on desktop the mouse stands in for one finger (ADR-0003 2.2). No gamepad, keyboard or screen reader path exists in battle.

**How to read the numbers.** Positions and sizes are field units on the 540 x 960 reference field. At the smallest supported screen (360 dp wide or 640 dp tall) 1.5 units is 1 dp, so 72 units is 48 dp. Larger screens only make things bigger (Input `field_scale`).

**Rules every pattern obeys.**

| Rule | What it means | Source |
|---|---|---|
| One thumb, one tap or one drag | No hold, no double tap, no long press, no two-finger gesture, no tap time limit | AR-M-01, AR-M-09, Input Rule 3 |
| 48 dp hit floor | Every hit disc has a radius of at least 36 units; the drawn shape may be smaller | AR-M-02, Input `target_ok` |
| Text floor and contrast | Text 14 dp or more on panel, 4.5:1 in every state, dimmed included; a graphic needed to act, 3:1 on field and on path | AR-V-01, AR-V-04 |
| Shape before colour | No state is told by hue alone; each has a shape, fill, outline, dot or strike backup | AR Colour audit |
| Answer on the press or the next frame | Press feedback shows on the first frame after `pressed`; a purchase lands on the first frame | Input Game Feel, HUD Game Feel |
| Silence is a valid answer | A miss shows nothing, except a ground tap (IP-14) | Input Game Feel |
| No sound carries meaning | Audio is none at MVP; any later sound repeats a visual | AR-A-01 |
| Reduce Motion has a fallback for every motion | See IP-26 | AR-V-10 |

**Timing vocabulary** (art bible §7, HUD UI Requirements): 120 ms for presses, state changes, the arc and arming steps; 200 ms for panel slides and the lost-life dash; 300 ms to arm an irreversible button; ease-out on entry, ease-in on exit; clocks are linear. Never animated: the leash, panel opacity, counter digits.

---

## Pattern Catalog

| ID | Pattern | Category | Used in | Status |
|---|---|---|---|---|
| IP-01 | Tap | Input | Every tap target | Designed |
| IP-02 | Drag | Input | Hero pin, burst aim | Designed |
| IP-03 | Press response | Input / Feedback | Hero, burst button, open arc and chip | Designed |
| IP-04 | Class winners frozen at press | Input | Every target | Designed |
| IP-05 | Tap sink | Input | Burst button, arc backdrop | Designed |
| IP-06 | One pointer, palm replacement | Input | Whole battle | Designed |
| IP-07 | Rejected press zones | Input | Field edges, insets, letterbox | Designed |
| IP-08 | Host cancel | Input | Pause, resize, back, outcomes, retry | Designed |
| IP-09 | Build arc | Field picker | Empty build slot | Designed |
| IP-10 | Tap then confirm (upgrade chip) | Field confirm | Tower below its last level | Designed |
| IP-11 | Inspect tap | Field feedback | Tower at its last level | Designed |
| IP-12 | Pin drag | Field drag | Hero | Designed |
| IP-13 | Aim drag with offset reticle | Field drag | Burst button | Designed |
| IP-14 | Ground rejection ring | Feedback | Empty field | Designed |
| IP-15 | Armed button | HUD control | Start/Call, Retry, Play again | Designed |
| IP-16 | Hero first in an overlap | Input / HUD | Start/Call, burst button | Designed |
| IP-17 | Cost and unaffordable state | Data display | Arc panels, chip | Designed, one floor fix |
| IP-18 | Stateful burst button | HUD control | Burst button | Designed |
| IP-19 | Verb prompt line | Onboarding | Battle, until each verb is done | Designed |
| IP-20 | Read-only top band | Data display | Lives, pips, gold, next-wave line | Designed |
| IP-21 | TapScreen modal | Modal | Paused, Lost, Won | Designed |
| IP-22 | Tap to resume | Modal | Paused | Designed |
| IP-23 | One-tap retry | Modal | Lost, Won | Designed |
| IP-24 | Refusal cue | Feedback | Unaffordable disc and chip, locked burst | Designed in part (static cue open) |
| IP-25 | Visible clock | Data display | Chip bar, cooldown wedge, countdown | Designed |
| IP-26 | Reduce Motion fallback | Cross-cutting | Every animated element | Designed (flag at MVP) |
| IP-27 | Handedness mirror | Cross-cutting | Burst button and digit | Designed (flag at MVP) |
| IP-28 | Two-tap mode | Input (alternative) | Hero pin, burst aim | Planned, Alpha |
| IP-29 | Pause control | HUD control | Every live phase | Planned, Vertical Slice |

---

## Patterns

### Input patterns

#### IP-01 Tap

**Category**: Input · **Used in**: slots, towers, arc discs, chip, Start/Call, sinks
**Description**: A press that lifts before it moves past its slop, and lifts inside the disc that won at press. The one way to build, upgrade, inspect, call a wave or dismiss.
**Specification**:
- Slop is `tap_slop` (default 28 units, 18.7 dp) when the press has a real tap winner or no winner at all, else `drag_slop` (default 15). Crossing is inclusive.
- The release must lie inside the winner's disc as frozen at press. A finger that rolls off and lifts emits nothing: slide off to abort, a miss and never a mis-fire.
- No time limit. A press held ten seconds and lifted in place is a tap (AR-M-09).
- A release past slop whose moves were lost is never a tap; it becomes a drag or nothing.
- Feedback comes from the owner: arc (IP-09), chip (IP-10), ring (IP-11), command.
**When to Use**: any discrete choice on a field target or button.
**When NOT to Use**: moving the hero or aiming (IP-02); anything needing a hold or repeat.
**Sources**: Input Rules 3, 5; Formulas `is_drag`; ADR-0008 Decisions 3, 5.

#### IP-02 Drag

**Category**: Input · **Used in**: hero (pin), burst button (aim)
**Description**: A press with a drag winner that moves past its slop.
**Specification**:
- `drag_started` fires on the first move at or past slop, then one `drag_moved` per input call, then `drag_ended` on release with the raw position. The owner clamps.
- Sticky: wobbling back to the origin never turns a drag into a tap.
- A press with a real tap winner needs `tap_slop` before it can drag, so a thumb roll on a tower never moves a hero parked on it.
- A drag that starts in the field stays valid if it moves into a rejected zone (IP-07).
- The resolver has no cancel gesture. Dragging back has a meaning only its owner gives (IP-13).
**When to Use**: the two continuous verbs, pin and aim.
**When NOT to Use**: any new verb. A new drag needs a Per-Feature Matrix row (AR-C-07) and a two-tap path (IP-28).
**Sources**: Input Rules 3, 6, 12; Game Feel "Sticky drag".

#### IP-03 Press response

**Category**: Input / Feedback · **Used in**: hero, ready burst button, open arc and chip
**Description**: Some targets answer the press itself, before the gesture is classed, so the first frame of touch says "this is yours".
**Specification**:
- `pressed(best_tap, best_drag, press_pos)` fires on every press, even on nothing.
- Hero as `best_drag`: dashed leash on the first frame (Hero Visual "Press hero"). Hidden on `became_idle()`, which ends every gesture, tap or nothing included.
- Ready burst button: a thin ring at radius 64 (the cancel boundary, visible past the fingertip) plus a dim reticle (IP-13). Cooling: the seconds digit above the thumb, on panel. Locked: a refusal (IP-24).
- An open arc or chip closes on a press that names another tap target or none.
- Owners never command from `became_idle()` or `drag_cancelled()`; both are cleanup edges.
**When to Use**: a target whose gesture will be a drag, so the reply cannot wait for slop.
**When NOT to Use**: plain tap targets; they answer on the classed tap.
**Sources**: Input Rule 2, Game Feel; Hero UI Requirements; ADR-0008 Decision 6.

#### IP-04 Class winners frozen at press

**Category**: Input · **Used in**: every registered target
**Description**: At press the resolver picks the best tap target and the best drag target under the finger, and nothing changes them for the rest of the gesture. A tap reaches only the tap winner, a drag only the drag winner, with no fall-through.
**Specification**:
- Every target is a disc. Ties break by priority, then nearer centre, then earlier id.
- Tap class: burst sink 400, Start/Call 350, arc disc 300, chip 300, arc backdrop 250, tower and slot 200 (same tier, nearest wins). Drag class: hero 200, burst button 100.
- A target registered mid-gesture competes from the next press, so new arc discs cannot catch a double tap.
- A tap over the hero alone reaches no tap target. A drag from a slot or tower alone is not a pin.
**When to Use**: every new target: register a disc with a class and priority.
**When NOT to Use**: Controls on modal screens (IP-21), which take presses before the resolver.
**Sources**: Input Rules 2, 4, suggested registrations; ADR-0008 Decisions 2, 9.

#### IP-05 Tap sink

**Category**: Input · **Used in**: burst button sink (TAP 400), arc backdrop (TAP 250, covers the field)
**Description**: A tap target that wins the tap and does nothing, so a touch there reaches nothing beneath.
**Specification**:
- A sink does not raise the press's slop and does not hold the pointer against a new press (IP-06).
- Burst sink: a resting thumb lifted off the button can never spend the cooldown or tap a slot beneath.
- Arc backdrop: while an arc is open, any press outside its discs only dismisses, including a press on another slot or a tower. A dismissal draws no ground ring.
**When to Use**: where a stray tap must be absorbed, or where acting on the thing beneath would be a mis-fire.
**When NOT to Use**: as a way to block drags; a sink is TAP only (ADR-0008 Decision 2).
**Sources**: Input Rule 2 table, edge cases; HUD Rules 6, 8, 14.

#### IP-06 One pointer, palm replacement

**Category**: Input · **Used in**: the whole battle
**Description**: The first finger down owns the gesture. Other fingers are ignored, except that a press nobody is waiting on gives way to a new one.
**Specification**:
- A second finger never cancels an aim and never counts as a tap.
- A press with no real tap winner (ground, a sink, the hero or burst button alone), unmoved or dead, is replaced by the next press, so a resting palm cannot block the thumb.
- A press on a real tap target, or a drag that has begun, holds until it lifts.
- A finger already down when the active one lifts never becomes active.
**When to Use**: always; no pattern may need a second finger (AR-M-01).
**When NOT to Use**: n/a.
**Sources**: Input Rule 1; edge cases; Open Questions (palm risk).

#### IP-07 Rejected press zones

**Category**: Input · **Used in**: side edges, safe-area insets, letterbox bars
**Description**: A press in these zones never reaches the game, so an OS back swipe or a notch touch cannot fire an action.
**Specification**:
- Side margin `edge_reject_margin` (default 36 units, 24 dp) or the side inset, whichever is larger; top and bottom insets; anything outside the 540 x 960 field.
- A drag that started inside the field and moves into a zone stays valid.
- The burst button's centre is at least margin + 48 from a side edge; the hero cannot be pinned in a zone.
**When to Use**: placing any target near an edge; check the target's centre clears the zone.
**When NOT to Use**: n/a.
**Sources**: Input Rule 12; ADR-0003 Decision 3; AR-M-10.

#### IP-08 Host cancel

**Category**: Input · **Used in**: focus loss, app pause, Android back, notification shade, resize, Won, Lost, Paused, Fatal, retry teardown
**Description**: Only the host ends a gesture early; the owner reverts and nothing fires.
**Specification**:
- A drag in flight gets `drag_cancelled`: the hero keeps its old pin, the burst does not fire. A press in flight ends with `became_idle()` only.
- A release is never made up from a cancel. A finger held across a cancel stays dead until it lifts.
- Phase changes among Build, Wave and Intermission never cancel (Flow Rule 10). An aim armed in Intermission can release in Wave.
**When to Use**: any event that takes the battle away from the player.
**When NOT to Use**: as a player gesture; there is none.
**Sources**: Input Rule 7; ADR-0003 Decision 2.5; Flow Rules 10, 15, 17.

### Field patterns

#### IP-09 Build arc

**Category**: Field picker · **Used in**: empty build slot
**Description**: Tap a free slot, get three role discs in a fan above it. Tap one to build at once. There is no confirm and no sale, so the guards are in the layout and timing.
**Specification**:
- Fan at radius `R` 76 above the slot, angles -60°, 0°, 60°: triangle (Single), hexagon (Splash), square (Slow), always in that order, both hands. Each disc: hit radius 36, a tower-size polygon with panel fill and a 3 px cyan contour; a 60 x 44 panel above holds the word and the cost.
- Opening registers the backdrop sink (IP-05) and the discs, which compete from the next press. Start/Call is disabled while open.
- A disc press within 200 ms of opening is ignored, so a double tap dismisses.
- Disc tap calls `build`: OK closes at once (120 ms collapse as art only); NO_GOLD stays open with a refusal (IP-24); HALTED closes.
- Closes on a press naming anything but a disc, on `drag_started`, on Paused, an outcome or Fatal. Stays open on roll-off and on a phase change.
- While open: one range ring per distinct level-1 range.
**When to Use**: choosing one of a few options tied to a field position.
**When NOT to Use**: below the slot (the thumb covers it) or as a screen-space menu.
**Sources**: HUD Rules 6 to 8, Formula `arc_disc`; Tower Rule 7; art bible §7; AR-M-11.

#### IP-10 Tap then confirm (upgrade chip)

**Category**: Field confirm · **Used in**: a tower below its last level
**Description**: The first tap shows the price; a second tap inside a short window pays it.
**Specification**:
- Tap opens a 76 x 44 chip at (x, y - 76) of the tower for 1.5 s: cost (16 dp), the level-2 polygon (20 px cyan), and a draining bar (IP-25). Current and next range rings show.
- A tap on the same tower, or on the chip's own disc (TAP 300, radius 40), commits when 200 ms <= elapsed < 1,500 ms at release. Taps under 200 ms are ignored.
- NO_GOLD keeps the chip open and dimmed, the window not restarted (IP-24). Any other result closes it.
- A press on another tap target or none closes it; a press on another tower opens that tower's chip. A drag from the hero over the tower never commits.
- After expiry, a tap opens a fresh chip and never commits. Only one chip at a time. Paused, Won, Lost and Fatal close it.
**When to Use**: an irreversible spend on a field object.
**When NOT to Use**: the build itself (IP-09 is already two taps); anything at its last level (IP-11).
**Sources**: Tower Rule 8 and its event table; HUD Rule 9, Formula `chip_bar`; Input Rule 8; art bible §7; AR-M-07.

#### IP-11 Inspect tap

**Category**: Field feedback · **Used in**: a tower at its last level (level 2 at MVP)
**Description**: A tap on a tower that cannot upgrade shows its range ring for 1.5 s, so the tap is not silent. No chip opens.
**Specification**: `tower_inspected(slot_index)` draws the current ring, solid 2 px cyan, alpha 0.5. A maximum-level cue beside the ring is still to be specified (Tower UX flag).
**When to Use**: a tap on a field object with no action left.
**When NOT to Use**: as a stat panel; tower stats are not shown (HUD Rule 4).
**Sources**: Tower Rule 8, UI Requirements; HUD Rule 9.

#### IP-12 Pin drag

**Category**: Field drag · **Used in**: hero
**Description**: Press the hero, drag to a spot, lift. The hero walks there in a straight line and fights inside its leash. The only hero verb.
**Specification**:
- Hit disc radius 56 (75 dp), DRAG priority 200. Unpinned, the hero shows a dashed ring at 56 (not the leash) and the prompt "Drag the hero".
- Press: dashed leash at the hero (IP-03). Drag: the leash and a 2 px unfilled kite ghost at the clamped pin point; the leash carries it, since the thumb hides the ghost.
- The ghost never refuses a person: off-field, out of `pin_rect` or inside a button exclusion (radius 60 around each burst line and Start/Call), the point clamps to the nearest valid spot, and the ghost shows where it will land.
- Release commits: a 2 px ground ring (radius 30) and the leash snap to the pin, then the hero walks (240 units/s). No re-pin cooldown. Pin offset is 0 at MVP.
- A pin may land on a slot or tower; it never blocks building.
**When to Use**: placing the hero.
**When NOT to Use**: a tap on the hero (does nothing but show the leash, IP-28 aside).
**Sources**: Hero Rules 1 to 4, 14, 15, Visual table; Input Rule 4; art bible §3.

#### IP-13 Aim drag with offset reticle

**Category**: Field drag · **Used in**: burst button
**Description**: Drag from the big button to aim the burst at a point 100 units above the finger; lift to fire. Drag back onto the button to cancel.
**Specification**:
- Arms only if the burst is Ready, the hero is pinned and the phase is not Build. Otherwise the whole press is dead (IP-24 for Locked; digit for Cooling). Sampled at `pressed`.
- Aim point: finger plus (0, -100), clamped to the field, then to `reach` (160) from the hero. No flip. Re-clamped each frame while the hero walks.
- Live aim: 3 px reticle with four ticks, solid radius preview (70), dotted reach ring, and a kill mark on each enemy the burst would kill. At the reach clamp ±20° of the reach arc turns solid.
- Cancel hysteresis: every aim starts cancelling; it goes live once the finger is over 64 from the button centre, and returns to cancelling at 48 or less. Cancelling: reticle alpha 0.3, preview and kill marks hidden. Release while cancelling does nothing.
- Release while live fires; no cancel after release. A drag cancel (IP-08) fires nothing.
**When to Use**: a targeted ability with a cooldown.
**When NOT to Use**: a tap on the button; it reaches the sink and does nothing (IP-05).
**Sources**: Hero Rules 11 to 13, Visual table, UI Requirements; Input Visual table; art bible §3, §7.

#### IP-14 Ground rejection ring

**Category**: Feedback · **Used in**: a tap on empty field
**Description**: A tap that hits nothing shows a tiny dim ring, for the first three in a battle only, so a new player learns the touch was seen and does nothing.
**Specification**: 2 px neutral ring, radius 16, alpha 0.35, 150 ms fade-in, unanimated, no sound. Resets on retry. Not drawn for an arc dismissal. Its 2.5:1 contrast is an accepted exception (AR Known Intentional Limitations).
**When to Use**: only for `ground_tapped`.
**When NOT to Use**: other misses (roll-off, second finger, drag from a tower); those stay silent.
**Sources**: Input Rule 5, Game Feel; HUD Rule 14; art bible §7.

### HUD patterns

#### IP-15 Armed button

**Category**: HUD control · **Used in**: Start/Call; Retry and Play again use the same model
**Description**: An irreversible button that may appear under a thumb waits 300 ms before a press counts.
**Specification**:
- States: Hidden (not registered), Arming (registered, alpha 0.5 rising to full over 300 ms, a tap from a press made now is dead even if released once Armed), Armed (a new press counts).
- Registers on appearing, not on arming, so an early press cannot land on what lies beneath.
- Clock from frame time, clamped to 100 ms per frame, frozen while Paused; a return from Paused is not a new appearance.
- Once armed: no pulse, no warning, no advice.
- Start/Call: (186, 800), 88 x 72 rect, hit radius 48. "Start" in Build; "Call +N" in Intermission ("Call" at bonus 0) with seconds left and a burst glyph beneath. Hidden in Wave.
**When to Use**: any button whose action cannot be undone and that appears without the player asking.
**When NOT to Use**: Paused (no timer; IP-22).
**Sources**: HUD Rules 10, 11, States table; Flow Game Feel. See OI-05, OI-10.

#### IP-16 Hero first in an overlap

**Category**: Input / HUD · **Used in**: Start/Call, burst button
**Description**: Where the hero's grab disc overlaps a button, the press belongs to the hero. A wrong grab costs a moment; a wrong call or burst cannot be undone.
**Specification**:
- Start/Call: when `pressed` names Start/Call as tap winner and the hero as drag winner, the HUD ignores that tap. A drag re-pins. Only the overlap is dead; the rest of the button works.
- Burst button: hero DRAG 200 beats button DRAG 100; a tap there still reaches the sink.
- A pinned hero stays 60 from each button centre, so every centre stays pressable.
**When to Use**: any irreversible tap target the hero can walk across.
**When NOT to Use**: towers and slots; a tap there still builds or upgrades with the hero beneath.
**Sources**: HUD Rule 10; Hero Rules 2, 15, edge cases.

#### IP-17 Cost and unaffordable state

**Category**: Data display · **Used in**: arc disc panels, chip
**Description**: Every spend shows its price on a panel beside the thing it buys, and the price updates live as gold changes.
**Specification**:
- Cost in 16 dp tabular digits on panel. Read at draw time, never cached from when the arc or chip opened.
- Unaffordable: dimmed and struck through, no magenta. **Text alpha at least 0.6** (4.83:1, AR-V-05); the arc polygon may stay at 0.55. See OI-01.
- A disc or chip that becomes affordable while open works at once.
- A refused tap gets a refusal (IP-24).
**When to Use**: any gold spend.
**When NOT to Use**: as a stat readout; no tower stats are shown.
**Sources**: HUD Rules 7, 9, Visual table; Tower UI Requirements; AR-V-04, AR-V-05.

#### IP-18 Stateful burst button

**Category**: HUD control · **Used in**: burst button
**Description**: One disc in the bottom corner on the dominant-hand side shows whether the burst can be aimed, with shape, fill and a digit.
**Specification**:
- 84 px visible, hit radius 48 (64 dp), centre x 456 (84 left-handed), `y = clamp(888 - I_bottom, 816, 888)`.
- Ready: gold fill, complete ring; four static ticks around the hero repeat it on the field. Cooling: neutral outline, gold returning as a clockwise wedge, digit (24 dp, floor 18). Telegraphing: empty wedge. Locked (Build or before a first pin): dotted outline, no fill or digit.
- Ready first frame: button scale 1.15 to 1 in 120 ms, once (IP-26).
- Press responses per IP-03; drag per IP-13; tap per IP-05.
**When to Use**: the one hero ability at MVP.
**When NOT to Use**: as a pattern for tap buttons; disc buttons are reserved for hero actions (art bible §3).
**Sources**: HUD Rule 12, Layout, Formula `burst_y`; Hero UI Requirements, Visual table; art bible §7.

#### IP-19 Verb prompt line

**Category**: Onboarding · **Used in**: Build, Wave, Intermission
**Description**: One short line names the next verb to try, and hides when the player does it. Never on a timer.
**Specification**:
- First match, this battle only: "Drag the hero" (unpinned); "Tap a slot to build" (no tower, Build or Intermission); "Drag from the big button" (Wave, burst Ready, none started; latched until `burst_started`).
- 300 x 34 panel, 14 dp, one line, centre (270, `I_top + 89`). No arrows, no pause, no captured input.
- The same three verbs return as the first next-try lines on the result (IP-23).
**When to Use**: teaching a verb, never where or when.
**When NOT to Use**: advice, warnings or strategy.
**Sources**: HUD Rules 13, 16; Hero UI Requirements; AR-C-03.

#### IP-20 Read-only top band

**Category**: Data display · **Used in**: lives, wave pips, gold, next-wave line
**Description**: Bookkeeping sits in a top band that ignores input.
**Specification**:
- Band y 0 to `I_top + 72`. Lives: ten dashes; a lost one fades to alpha 0.2 and stays countable. Pips: filled done, outlined current, dotted upcoming. Gold digits swap, never bounce. Next-wave line: glyph and count per enemy type.
- Every Control here has `mouse_filter = IGNORE`.
**When to Use**: values the player glances at but never acts on.
**When NOT to Use**: anything tappable (see OI-06 for the pause control).
**Sources**: HUD Rules 1, 4, 5, Layout, Visual table; ADR-0003 Decision 4; art bible §7.

### Modal patterns

#### IP-21 TapScreen modal

**Category**: Modal · **Used in**: Paused, Lost, Won
**Description**: A full-screen Control that takes every press, so a tap on it can never reach a tower or the hero.
**Specification**:
- `TapScreen`: full rect, takes every pointer event, no focus. Fires `tapped` only on the release of a press it saw; a cancelled release does not fire. Clears held presses after firing, on show and on the lifecycle signal.
- While it shows, the adapter's press gate is closed. A drag begun before it showed still ends once.
- A finger down when it appears, or across a focus loss, cannot fire it.
**When to Use**: any screen that stops play.
**When NOT to Use**: in-battle choices (arc, chip); they are field discs.
**Sources**: HUD Rule 2; ADR-0003 Decisions 2.4, 4.

#### IP-22 Tap to resume

**Category**: Modal · **Used in**: Paused
**Description**: Leaving the app freezes the battle; one tap brings it back.
**Specification**:
- Entered by focus loss, app pause, window focus loss, Android back (every time, never quits) or a notification-shade pull.
- Static 40% scrim and a 300 x 64 panel: "Paused. Tap to resume". Instant, no timer, no motion (AR-C-02).
- Resumes on the release of a press the screen saw. The tap reaches nothing beneath. On desktop the click that refocuses the window is that tap (ADR-0003 Decision 5.3).
- Arc and chip close; an aim in flight cancels (IP-08).
**When to Use**: the only pause at MVP.
**When NOT to Use**: as a menu; there is no quit or settings at MVP.
**Sources**: HUD Rule 17; Flow Rule 17; ADR-0003 Decisions 2.5, 5. See OI-06 for the manual pause.

#### IP-23 One-tap retry

**Category**: Modal · **Used in**: Lost, Won
**Description**: A plain result and one filled button to go again.
**Specification**:
- The modal mounts at the outcome, so input is dead at once. Text shows after 400 ms (Lost) or 1,000 ms (Won).
- Fixed order, 16 dp, same weight: headline, next-try line or lives, "Got through", damage by Towers, Hero, Burst.
- Retry (Lost) or Play again (Won), 128 x 72, is the only filled shape. It arms as IP-15 from when its text shows. No confirm.
- Lost panel x 48 to 492, y 200 to 752. Won panel is compact (y 752 to 944) so the finished board stays in view.
- Retry sets an idempotent latch; a second tap does nothing.
**When to Use**: every stage end at MVP.
**When NOT to Use**: Vertical Slice replaces it with Stage Progression's report.
**Sources**: HUD Rules 15, 16, 18, Layout; Flow Rule 16, Game Feel; AR-C-06.

### Feedback and cross-cutting patterns

#### IP-24 Refusal cue

**Category**: Feedback · **Used in**: unaffordable arc disc, unaffordable chip, locked burst button press
**Description**: A refused tap must look refused, not missed.
**Specification**:
- Normal: a 2 px nudge once for 120 ms, no magenta. Before the first pin, a locked press also repeats the prompt.
- Under Reduce Motion the nudge is skipped and **a static cue must replace it** (AR-V-11). The cue is not yet chosen; the arc-and-chip UX spec picks it. AR-V-11's examples: the strike thickens for 300 ms, or the dotted outline turns solid for 300 ms. See OI-04.
- A cooling burst press is not a refusal: it shows the digit (IP-03).
**When to Use**: any tap that reaches its owner and is turned down.
**When NOT to Use**: misses that reach no owner; those stay silent (IP-14 aside).
**Sources**: Tower UI Requirements; Hero UI Requirements; HUD Rule 7; AR-V-11.

#### IP-25 Visible clock

**Category**: Data display · **Used in**: chip bar, burst cooldown wedge and digit, intermission seconds
**Description**: Every timed thing shows its time.
**Specification**:
- Chip: a 3-unit bar draining linearly over 1.5 s (`chip_bar`). Burst: a clockwise wedge plus a digit. Intermission: seconds under Call.
- Digits use `display_seconds`, which shows 0 only at 0. Clocks are linear and stay under Reduce Motion.
**When to Use**: any window or cooldown.
**When NOT to Use**: protective delays (200 ms guards, 300 ms arming); they are not windows (AR Motor table).
**Sources**: HUD Rules 9, 10, 12, Formulas; art bible §7; AR-M-07, AR-M-08.

#### IP-26 Reduce Motion fallback

**Category**: Cross-cutting · **Used in**: every animated element
**Description**: The `reduce_motion` flag swaps each motion for a still form that keeps the same fact. AR-V-10 is the one list.
**Specification**:
- Cut: panel slides, burst field dip, wind-up, snap and Ready pop (a static ring from T+0.1 s, 4 px at release; spokes stay), the refusal nudge (IP-24 static cue instead), build overlay scale (fade only), arc collapse (instant), hero idle breathing.
- Frozen: the danger pulse at full; the chevron shape stays.
- Kept: fades, the chip bar, the cooldown sweep and enemy motion traits, since they carry information.
**When to Use**: every new animation needs a row here and in AR-V-10.
**When NOT to Use**: n/a.
**Sources**: AR-V-10; HUD UI Requirements; Hero Visual table; art bible §7. See OI-04, OI-08.

#### IP-27 Handedness mirror

**Category**: Cross-cutting · **Used in**: burst button and its digit
**Description**: `left_handed` mirrors the burst button and its digit to the bottom-left. Nothing else moves.
**Specification**: x 84 instead of 456; the left burst line and Start/Call then refuse pins, and the bottom-right is free. Start/Call, the arc order, the kite and the aim offset never mirror. Fixed for a battle.
**When to Use**: only the dominant-hand control.
**When NOT to Use**: general HUD layout; full repositioning is out of scope.
**Sources**: HUD Edge Cases, Layout; Hero Rule 2, UI Requirements; AR-M-03.

### Planned patterns (committed, not built)

#### IP-28 Two-tap mode

**Category**: Input (alternative) · **Used in**: hero pin, burst aim · **Tier**: Alpha
**Description**: A setting that turns both drags into two taps, so no action needs a drag (AR-M-06).
**Specification (as committed in AR-M-06, nothing added)**: tap the hero, then tap the field, to pin there. Tap the Ready burst button, then tap the field, to aim and fire there, with a visible armed state; tap the button again to cancel. Needs its own Pillar 4 phone test with the zero mis-fire bar.
**When to Use**: only as the opt-in setting.
**When NOT to Use**: the default mode, where a tap on the hero or burst button does nothing.
**Sources**: AR-M-06; Input Open Questions. See OI-07, OI-12.

#### IP-29 Pause control

**Category**: HUD control · **Used in**: every live phase · **Tier**: Vertical Slice (first phone build)
**Description**: A visible pause target, since iOS has no back button (AR-C-01).
**Specification (as committed)**: 48 dp target, outside the bottom 30%, must not take a press meant for the field; opens IP-22. Placement is open.
**When to Use**: from the first phone build.
**When NOT to Use**: MVP on desktop, where focus loss pauses.
**Sources**: AR-C-01. See OI-06.

---

## Gaps & Patterns Needed

**No UX specs exist yet.** Phase 1 of this skill reads the Component Inventory and Interaction Map of each spec in `design/ux/`; there were none, so every pattern above comes from the GDDs, ADR-0003, ADR-0008, the art bible and the AR document. When the HUD spec (`design/ux/hud.md`), the arc-and-chip spec and the pin-and-aim spec are written, each should cite these IDs, and any pattern they add comes back here.

| Gap | Needed by | Owner | Notes |
|---|---|---|---|
| Static refusal cue (completes IP-24) | MVP | Arc-and-chip UX spec | AR-V-11; Tower UX flag |
| Chip details: armed look after the 200 ms guard, expired or closed chip, a chip that would leave the field, maximum-level cue (IP-11) | MVP | Arc-and-chip UX spec | Tower UX flag |
| Aim details: reticle far from the thumb when clamped, preview overhanging the reach ring, ring clipping at 540 wide, re-grabbing a hero pinned high | MVP | Pin-and-aim UX spec | Hero UX flag |
| Pause control placement (IP-29) | Vertical Slice | HUD spec with Menu & Screen Flow | AR-C-01; OI-06 |
| Menu controls: primary and secondary button, toggle, slider, list, focus order with accessible names | Vertical Slice | Menu & Screen Flow | AR-P-01, AR-M-02 |
| First-launch screens: hand choice, photosensitivity notice | Vertical Slice | Menu & Screen Flow | AR-M-03, AR-V-09 |
| "How to play" help, reached from Pause | Vertical Slice | Onboarding Prompts | AR-C-04 |
| Skill tree node (owned filled, available outlined, locked dotted) | Vertical Slice | Skill Tree System | Art bible §3; AR matrix row 11 |
| Settings rows: Larger text, hit scale, steady hand, two-tap, timing multipliers, game speed, volumes, with "applies next battle" | Alpha | Settings & Accessibility | AR-V-03, AR-M-04 to AR-M-08, AR-C-08, AR-C-10 |
| Two-tap mode details (IP-28) | Alpha | Hero, Input, Settings | OI-12 |

**Consolidation candidate.** IP-15 and IP-21 both stop an early press from firing. Once OI-10 is settled, one rule ("a press counts only if it began while the target was armed and seen") could cover both.

**Not a pattern.** The Fatal screen takes no input at MVP (Flow Rule 18).

**Cross-reference check (Phase 5, 2026-11-04).**
- GDD UI requirements: Input, HUD, Tower, Hero and Flow are each covered. Combat, Enemy & Wave and Data own no interaction.
- New patterns to add: none beyond this file.
- Navigation mismatches: none; no screen specs exist to compare.
- Accessibility: every entry cites its AR floor; four floors are not met by the sources today (OI-01 to OI-05).
- Empty states: prompt (None after the first burst), damage rows (read 0), gold (shows 0). Later screens need their own.

---

## Open Questions

### Conflicts and open items

Each item names the sources that disagree. This library follows the accessibility floor or the newer, more specific rule, as stated, and edits no source.

| ID | Sources that disagree | Gap | Library follows | Owner |
|---|---|---|---|---|
| OI-01 | HUD Visual table "Unaffordable" (alpha 0.55) vs AR-V-05 | Cost text at 0.55 is 4.26:1, under 4.5:1 | Text at 0.6 or above (IP-17) | Battle HUD GDD (AR change 1) |
| OI-02 | Tower Visual table "Range ring" (next level at alpha 0.25) vs AR-V-06 | 1.65:1 on the path, under 3:1; told apart by alpha only | Nothing new; IP-10 cites the ring without a value | Tower GDD (AR change 2) |
| OI-03 | Art bible §6 slot marks vs AR-V-07 | 1 px outline at 0.3 is 2.1:1; corner mark has no alpha | Nothing new | art-director (AR change 3) |
| OI-04 | Tower UI Requirements, Hero UI Requirements and HUD (nudge skipped under Reduce Motion, nothing in its place) vs AR-V-11 | A refused tap reads as a missed tap | IP-24 requires a static cue, not yet picked | Arc-and-chip UX spec; Tower, Hero, HUD GDDs (AR change 4) |
| OI-05 | HUD Visual table "Start/Call" (Arming at alpha 0.5, rising to full over 300 ms) vs AR-V-04 and art bible §7 | Labels at 0.5 fall below 4.5:1 (0.55 is already 4.26:1), and AR-V-04 says dimmed states count. Art bible §7 also says panel opacity never animates, and the Start/Call panel fades in | Nothing new; IP-15 records the HUD value and this item | Battle HUD GDD, art-director |
| OI-06 | HUD Rule 4, Flow Rule 17 and Input UI Requirements ("no pause button") vs AR-C-01 | iOS has no back button; a phone build needs a pause control. The top band ignores input (IP-20) and the bottom 30% is reserved, so no place is free | IP-22 at MVP; IP-29 planned | HUD spec, Flow GDD (AR change 6) |
| OI-07 | Input burst sink, concept Pillar 4 and Hero Rule 11 ("a tap on the burst button does nothing") vs AR-M-06 | True only in the default mode once two-tap mode exists | IP-05 for default; IP-28 as the named exception | Input, Hero GDDs, concept (AR change 9) |
| OI-08 | HUD UI Requirements Reduce Motion line (slides only) vs AR-V-10 | The HUD line omits arc collapse, build overlay scale, refusal and hero breathing | AR-V-10 (IP-26) | Battle HUD GDD (AR change 5) |
| OI-09 | Tower Rule 7 ("one the player cannot afford is dimmed and does nothing") vs HUD Rule 7 (the disc always calls `build`; NO_GOLD stays open with a nudge) and Tower UI Requirements (a refused tap nudges) | Whether a refused disc tap shows a refusal | HUD Rule 7: the disc calls `build` and shows IP-24 | Tower GDD |
| OI-10 | HUD Rules 2 and 11 and Flow Game Feel (Retry arms after 300 ms and ignores presses begun earlier) vs ADR-0003 Decision 4 (`TapScreen` fires on the release of any press it saw; no arming state) | The ADR's interface has no arming gate, and no document names who holds it for a `TapScreen` region | IP-15 and IP-23 as the HUD states; gate owner open | technical-director, Battle HUD stories |
| OI-11 | HUD Rule 6 and AC 4 (arc guard on press time: a disc press within 200 ms is ignored) vs Tower Rule 8 (chip guard on release time: commits when 200 <= elapsed < 1,500 ms at release) | Two 200 ms guards on different clocks. A press at 150 ms released at 250 ms upgrades on a chip and is ignored on an arc | Each as written (IP-09, IP-10) | Battle HUD and Tower GDDs |
| OI-12 | AR-M-06 (owners change, resolver signals do not) vs Input Rules 4 and 5 | The hero has no TAP disc today, so a tap on it emits nothing. A second tap "on the field" reaches a tower, slot or arc disc if one is beneath, or `ground_tapped` if none; no signal means "tap at any point" | IP-28 restates AR-M-06 only | Input, Hero GDDs; Settings & Accessibility (Alpha) |
| OI-13 | `.claude/docs/technical-preferences.md` Platform Notes ("skill button > tower > build slot > walkable ground") vs Input priority table | Legacy note puts tower above slot, omits Start/Call, arc and sink | Input priority (IP-04) | Project config owner (`/setup-engine`) |
| OI-14 | HUD panel sizes (arc 60 x 44, Start/Call 88 x 72, chip 76 x 44, prompt 300 x 34) vs AR-V-03 | Sized for 100% text only | Nothing new | Battle HUD GDD (AR change 7, Alpha) |
| OI-15 | HUD content rules and Enemy & Wave L3 (checked at hit scale x1) vs AR-M-04 | Start/Call is 7.2 from the left burst disc and 17.3 from a slot; x1.25 breaks both | Nothing new | Battle HUD, Enemy & Wave GDDs (AR change 8, Alpha) |
| OI-16 | Hero UI Requirements ("before a first pin, the nudge also repeats the prompt") vs HUD Rule 13 and AR-V-10 | The prompt line already shows then; what "repeat" looks like, and whether it survives Reduce Motion, is unstated | Nothing new | Hero GDD, pin-and-aim UX spec |
| OI-17 | Hero Visual "Cancelling" (reticle alpha 0.3) vs AR-V-04 | The AR contrast table has no ratio for it, though it tells the player a release will cancel | Nothing new | ux-designer, test plan |
| OI-18 | AR document header and Open Questions ("`design/ux/interaction-patterns.md` does not exist yet") | Now stale | n/a | AR document's next revision |

### Other open questions

| Question | Owner | Resolve by |
|---|---|---|
| No player journey map exists (`design/player-journey.md`). Author it from `.claude/docs/templates/player-journey.md` so onboarding and help patterns (IP-19, AR-C-04) rest on known player context | ux-designer | Before Vertical Slice UX specs |
| Do IP-01 to IP-13 hold on a phone? All evidence is one developer on a mouse; the Pillar 4 test is the gate | producer | First phone build |
| Adjacent arc discs are 4 units apart, and a wrong disc cannot be undone. First fallback: a larger `R` (AR-M-11) | Pillar 4 phone test | First phone build |
| Should only the chip's own disc commit, which would remove the same-tower commit and the 200 ms guard? | Pillar 4 phone test | First phone build |
| Is the prompt at the top seen while the eyes are on the lane? | First-run test | First playable |
| Pin offset 0 or 100 (IP-12), and the exclusion radius of 60 (IP-16) | Pillar 4 phone test | First phone build |

### Reviews

| Review | Status |
|---|---|
| ux-designer (this skill's primary agent) | **Review owed.** This session could not start agents; the library was drafted in session in autonomous mode |
| ui-programmer (feasibility of the component rules) | **Review owed** for the same reason |
| `/ux-review design/ux/interaction-patterns.md` | Not run. Required before `/team-ui` |
