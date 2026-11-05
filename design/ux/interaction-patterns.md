# Interaction Pattern Library

> **Status**: In Design (revised after `/ux-review` NEEDS REVISION, 2026-11-04; re-review owed)
> **Author**: njarrar + ux-designer (authored in session by `/ux-design patterns`, autonomous mode)
> **Last Updated**: 2026-11-05
> **Platform Target**: iOS and Android, portrait, one thumb, touch only; desktop build for testing with mouse as touch
> **Linked Documents**: `design/accessibility-requirements.md`, `design/gdd/input-gesture-resolver.md`, `design/gdd/battle-hud.md`, `design/gdd/tower-system.md`, `design/gdd/hero-system.md`, `design/gdd/game-state-stage-flow.md`, `design/art/art-bible.md`, ADR-0003, ADR-0008
> **Template**: Interaction Pattern Library

---

## Overview

This library names every interaction pattern TowerRiot uses, so specs, stories and reviews cite one ID instead of restating a rule. It adds no mechanic and edits no GDD. Each entry names its source, which wins if the two differ. Where sources disagree, or one misses a floor in `design/accessibility-requirements.md`, the entry follows the floor and logs an `OI-` item.

**Input.** Touch only; on desktop the mouse is one finger (ADR-0003 2.2). No gamepad, keyboard or screen reader path in battle.

**Numbers.** Field units on the 540 x 960 field. At the smallest screen (360 x 640 dp) 1.5 units is 1 dp, so 72 units is 48 dp.

**Rules every pattern obeys.**

| Rule | What it means | Source |
|---|---|---|
| One thumb, one tap or one drag | No hold, no double tap, no long press, no two-finger gesture, no tap time limit | AR-M-01, AR-M-09, Input Rule 3 |
| 48 dp hit floor | Every hit disc has a radius of at least 36 units; the drawn shape may be smaller | AR-M-02, Input `target_ok` |
| Text floor and contrast | Text 14 dp or more on panel, 4.5:1 in every state, dimmed included; a graphic needed to act, 3:1 on field and on path | AR-V-01, AR-V-04 |
| Shape before colour | No state is told by hue alone | AR Colour audit |
| Answer on the next frame | Press feedback and a purchase show on the first frame | Input Game Feel, HUD Game Feel |
| Silence is a valid answer | A miss shows nothing, except a ground tap (IP-14) | Input Game Feel |

### Animation Standards

Art bible §7 and HUD UI Requirements set the timings: ease-out on entry, ease-in on exit, clocks linear. Never animated: the leash, panel opacity, counter digits. AR-V-10 overrides the template's "fades reduced by 50%": fades keep full length; motion is cut or frozen as below.

| Motion | Timing | Used by | Reduce Motion |
|---|---|---|---|
| Press and state change | 120 ms | IP-03, IP-18 | Fade kept; any scale or nudge cut |
| Arc open and collapse | 120 ms | IP-09 | Collapse instant |
| Arming (outline only) | 300 ms, linear | IP-15, IP-21 | Kept; it is a clock |
| Panel slide, 12 units | 200 ms | HUD panels | Cut; the fade stays |
| Lost-life dash | 200 ms fade | IP-20 | Kept |
| Ground ring | 150 ms fade-in | IP-14 | Kept |
| Build and upgrade overlay | Scale 1.15 to 1, 120 ms | IP-09, IP-10 | Fade only |
| Ready pop | Scale 1.15 to 1, 120 ms, once | IP-18 | Cut |
| Refusal nudge | 2 px, 120 ms | IP-24 | Cut; static cue instead |
| Burst wind-up, snap | Shape transforms | IP-13 | Static ring from T+0.1 s; spokes stay |
| Burst field dip | 0.4 s, 3% darker | IP-13 | Skipped |
| Danger pulse | 2 Hz, 25% alpha swing | Lane exit | Frozen at full; chevrons stay |
| Hero breathing | 0.5 Hz, 4% scale | Hero | Off |
| Clocks: chip bar, cooldown wedge | Linear | IP-25 | Kept |
| Enemy jitter, bob, lean | On | Enemies | Kept; they are telegraphs |

### Sound Standards

None at MVP. From Alpha every sound repeats a visual; none carries meaning alone (AR-A-01). Also: three volumes, mono, the silent switch, no cue above 4 kHz alone (AR-A-02 to AR-A-05). A ground tap stays silent.

---

## Pattern Catalog

| ID | Pattern | Status |
|---|---|---|
| IP-01 | Tap | Designed |
| IP-02 | Drag | Designed |
| IP-03 | Press response | Designed |
| IP-04 | Class winners frozen at press | Designed |
| IP-05 | Tap sink | Designed |
| IP-06 | One pointer, palm replacement | Designed |
| IP-07 | Rejected press zones | Designed |
| IP-08 | Host cancel | Designed |
| IP-09 | Build arc | Designed |
| IP-10 | Tap then confirm (upgrade chip) | Designed |
| IP-11 | Inspect tap | Designed |
| IP-12 | Pin drag | Designed |
| IP-13 | Aim drag with offset reticle | Designed |
| IP-14 | Ground rejection ring | Designed |
| IP-15 | Armed button | Designed |
| IP-16 | Hero first in an overlap | Designed |
| IP-17 | Cost and unaffordable state | Designed, one floor fix |
| IP-18 | Stateful burst button | Designed |
| IP-19 | Verb prompt line | Designed |
| IP-20 | Read-only top band | Designed |
| IP-21 | TapScreen modal | Designed |
| IP-22 | Tap to resume | Designed |
| IP-23 | One-tap retry | Designed |
| IP-24 | Refusal cue | Designed |
| IP-25 | Visible clock | Designed |
| IP-26 | Reduce Motion fallback | Designed (flag at MVP) |
| IP-27 | Handedness mirror | Designed (flag at MVP) |
| IP-28 | Two-tap mode | Planned, Alpha |
| IP-29 | Pause control | Planned, Vertical Slice |

---

## Patterns

### Input patterns

#### IP-01 Tap

**Category**: Input · **Used in**: slots, towers, arc discs, chip, Start/Call, sinks
**Description**: A press that lifts before passing its slop, inside the disc that won at press. The way to build, upgrade, inspect, call or dismiss.
**Specification**:
- Slop is `tap_slop` (default 28 units, 18.7 dp) when the press has a real tap winner or no winner at all, else `drag_slop` (default 15). Crossing is inclusive.
- The release must lie inside the winner's disc as frozen at press. A finger that rolls off and lifts emits nothing: slide off to abort, a miss and never a mis-fire.
- No time limit. A press held ten seconds and lifted in place is a tap (AR-M-09).
- A release past slop whose moves were lost is never a tap; it becomes a drag or nothing.
- Feedback comes from the owner: arc (IP-09), chip (IP-10), ring (IP-11), command.
**When to Use**: any discrete choice on a field target or button.
**When NOT to Use**: moving the hero or aiming (IP-02); anything needing a hold or repeat.
**Sources**: Input Rules 3, 5; Formulas `is_drag`; ADR-0008 Decisions 3, 5.
**Accessibility**: AR-M-01, AR-M-09: no time limit; AR-M-02: radius 36 or more. A roll-off is a miss, never a mis-fire.
**Implementation Notes**: The resolver classes it (ADR-0008); owners never hit-test. Slops come from the Input record.

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
**Accessibility**: AR-M-05 steady-hand slop; AR-M-06: every drag has a two-tap path at Alpha (IP-28).
**Implementation Notes**: The owner clamps the raw position. Sticky is set once in the resolver (Input Rule 3).

#### IP-03 Press response

**Category**: Input / Feedback · **Used in**: hero, ready burst button, open arc and chip
**Description**: Some targets answer the press before the gesture is classed, so the first frame says "this is yours".
**Specification**:
- `pressed(best_tap, best_drag, press_pos)` fires on every press, even on nothing.
- Hero as `best_drag`: dashed leash on the first frame (Hero Visual "Press hero"). Hidden on `became_idle()`, which ends every gesture, tap or nothing included.
- Ready burst button: a thin ring at radius 64 (the cancel boundary, visible past the fingertip) plus a dim reticle (IP-13). Cooling: the seconds digit above the thumb, on panel. Locked: a refusal (IP-24).
- An open arc or chip closes on a press that names another tap target or none.
- Owners never command from `became_idle()` or `drag_cancelled()`; both are cleanup edges.
**When to Use**: a target whose gesture will be a drag, so the reply cannot wait for slop.
**When NOT to Use**: plain tap targets; they answer on the classed tap.
**Sources**: Input Rule 2, Game Feel; Hero UI Requirements; ADR-0008 Decision 6.
**Accessibility**: A first-frame reply tells a slow thumb it landed; the ring at 64 shows past the fingertip.
**Implementation Notes**: Views draw from `pressed` and clean up on `became_idle()`; never command from it (ADR-0008 D6).

#### IP-04 Class winners frozen at press

**Category**: Input · **Used in**: every registered target
**Description**: At press the resolver picks the best tap and drag targets under the finger; nothing changes them later. A tap reaches only the tap winner, a drag only the drag winner.
**Specification**:
- Every target is a disc. Ties break by priority, then nearer centre, then earlier id.
- Tap class: burst sink 400, Start/Call 350, arc disc 300, chip 300, arc backdrop 250, tower and slot 200 (same tier, nearest wins). Drag class: hero 200, burst button 100.
- A target registered mid-gesture competes from the next press, so new arc discs cannot catch a double tap.
- A tap over the hero alone reaches no tap target. A drag from a slot or tower alone is not a pin.
**When to Use**: every new target: register a disc with a class and priority.
**When NOT to Use**: Controls on modal screens (IP-21), which take presses before the resolver.
**Sources**: Input Rules 2, 4, suggested registrations; ADR-0008 Decisions 2, 9.
**Accessibility**: AR-M-01: no fall-through, so a slip never fires a second target. AR-M-04 hit scale must keep the winners.
**Implementation Notes**: Register a disc with class and priority; winners live on the press record, never re-queried.

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
**Accessibility**: Absorbs a resting thumb's lift (AR-M-01). A dismissal draws no ring.
**Implementation Notes**: A TAP disc with a no-op owner; it never raises slop or holds the pointer (ADR-0008 D2).

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
**Accessibility**: AR-M-01: a palm or second finger never blocks or cancels the thumb.
**Implementation Notes**: The resolver tracks one pointer id and runs the replacement test on each new press.

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
**Accessibility**: AR-M-10: an OS back swipe cannot fire an action. The margin is unverified on devices.
**Implementation Notes**: The adapter filters before the resolver (ADR-0003 D3); the content test checks target centres.

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
**Accessibility**: A cancel never fires an action the player did not finish (AR-M-01).
**Implementation Notes**: The host calls the resolver's cancel; owners revert on `drag_cancelled` (ADR-0003 2.5).

### Field patterns

#### IP-09 Build arc

**Category**: Field picker · **Used in**: empty build slot
**Description**: Tap a free slot, get three role discs in a fan above it. Tap one to build at once. There is no confirm and no sale, so the guards are in the layout and timing.
**Specification**:
- Fan at radius `R` 76 above the slot, angles -60°, 0°, 60°: triangle (Single), hexagon (Splash), square (Slow), always in that order, both hands. Each disc: hit radius 36, a tower-size polygon with panel fill and a 3 px cyan contour; a 60 x 44 panel above holds the word and the cost.
- Opening registers the backdrop sink (IP-05) and the discs, which compete from the next press. Start/Call is disabled while open.
- While open: one range ring per distinct level-1 range. Stays open on roll-off and on a phase change.

| State | Entered by | A disc tap | Shows |
|---|---|---|---|
| Guard | Slot tap; lasts 200 ms from opening | Ignored, so a double tap dismisses | Discs, panels, rings |
| Open | Guard ends | Calls `build` | Same |
| Refused | `build` returns NO_GOLD | Stays open; any disc still calls `build` | Refusal (IP-24) |
| Closed | OK, HALTED, a press naming anything but a disc, `drag_started`, Paused, an outcome, Fatal | None; the next slot tap opens a new arc | 120 ms collapse, art only |

**When to Use**: choosing one of a few options tied to a field position.
**When NOT to Use**: below the slot (the thumb covers it) or as a screen-space menu.
**Sources**: HUD Rules 6 to 8, Formula `arc_disc`; Tower Rule 7; art bible §7; AR-M-11.
**Accessibility**: AR-M-02 discs, 4 units apart (AR-M-11); shape and word, not hue; costs per IP-17.
**Implementation Notes**: The HUD owns the arc and places discs by `arc_disc`; `build` is the Tower call.

#### IP-10 Tap then confirm (upgrade chip)

**Category**: Field confirm · **Used in**: a tower below its last level
**Description**: The first tap shows the price; a second tap inside a short window pays it.
**Specification**:
- Tap opens a 76 x 44 chip at (x, y - 76) of the tower for 1.5 s: cost (16 dp), the level-2 polygon (20 px cyan), and a draining bar (IP-25). Current and next range rings show.
- Commit taps: the same tower, or the chip's own disc (TAP 300, radius 40). The 200 ms guard counts from the press, as the arc's does (IP-09); the window end counts at release. One chip at a time. A drag from the hero over the tower never commits.

| State | When | What a commit tap does |
|---|---|---|
| Guard | Press begins under 200 ms | Ignored, even if released later |
| Open | Press begins at 200 ms or later; released under 1,500 ms | Upgrades; any result but NO_GOLD closes the chip |
| Refused | After NO_GOLD | Stays open and dimmed, window not restarted (IP-24); a later tap may commit |
| Expired | 1,500 ms | Chip closes; the next tap on the tower opens a fresh chip and never commits |
| Closed | A press on another tap target or none; Paused, Won, Lost, Fatal. Another tower opens its own chip | Nothing |

**When to Use**: an irreversible spend on a field object.
**When NOT to Use**: the build itself (IP-09 is already two taps); anything at its last level (IP-11).
**Sources**: Tower Rule 8 and its event table; HUD Rule 9, Formula `chip_bar`; Input Rule 8; art bible §7; AR-M-07.
**Accessibility**: AR-M-07: the window is a timed input, x1 to x3 at Alpha, with the bar draining (IP-25).
**Implementation Notes**: `ChipWindow.advance(ms)` on real time from the wrapper (ADR-0004 step 1; TR-tower-010).

#### IP-11 Inspect tap

**Category**: Field feedback · **Used in**: a tower at its last level (level 2 at MVP)
**Description**: A tap on a tower that cannot upgrade shows its range ring for 1.5 s, so the tap is not silent. No chip opens.
**Specification**: `tower_inspected(slot_index)` draws the current ring, solid 2 px cyan, alpha 0.5. A maximum-level cue beside the ring is still to be specified (Tower UX flag).
**When to Use**: a tap on a field object with no action left.
**When NOT to Use**: as a stat panel; tower stats are not shown (HUD Rule 4).
**Sources**: Tower Rule 8, UI Requirements; HUD Rule 9.
**Accessibility**: A tap is never silent. The ring is 3.05:1 on the path, with no margin.
**Implementation Notes**: Tower emits `tower_inspected`; the view draws the ring for 1.5 s.

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
**Accessibility**: 75 dp grab disc; the ghost clamps, never refuses; leash 3.8:1; two-tap pin at Alpha (AR-M-06).
**Implementation Notes**: Hero owns the clamp and pin (Hero Rules 1 to 4). The leash never animates.

#### IP-13 Aim drag with offset reticle

**Category**: Field drag · **Used in**: burst button
**Description**: Drag from the big button to aim the burst at a point 100 units above the finger; lift to fire. Drag back onto the button to cancel.
**Specification**:
- Aim point: finger plus (0, -100), clamped to the field, then to `reach` (160) from the hero. No flip. Re-clamped each frame while the hero walks.

| State | Entered by | Shows | On release |
|---|---|---|---|
| Dead | At `pressed`: not Ready, hero unpinned, or Build. The whole press is dead | Digit (Cooling) or refusal (Locked, IP-24) | Nothing |
| Cancelling | Every aim starts here; returns when the finger is 48 or less from the button centre | Reticle alpha 0.3, no ticks; preview and kill marks hidden | Nothing |
| Live | Finger over 64 from the button centre | 3 px reticle, four ticks; solid preview (radius 70); dotted reach ring; a kill mark on each enemy it would kill | Fires; no cancel after release |
| Clamped | Live, aim point at `reach` | ±20° of the reach arc solid, alpha 0.7 | Fires |
| Cancelled | Host cancel (IP-08) | Aim cleared | Nothing fires |

**When to Use**: a targeted ability with a cooldown.
**When NOT to Use**: a tap on the button; it reaches the sink and does nothing (IP-05).
**Sources**: Hero Rules 11 to 13, Visual table, UI Requirements; Input Visual table; art bible §3, §7.
**Accessibility**: Two-tap aim at Alpha (AR-M-06). The offset keeps the mark clear of the thumb. The Cancelling reticle, about 2.4:1, is an accepted exception (OI-17).
**Implementation Notes**: `HeroInput.update()` re-clamps each frame. The 64/48 hysteresis lives in the owner, not the resolver.

#### IP-14 Ground rejection ring

**Category**: Feedback · **Used in**: a tap on empty field
**Description**: A tap that hits nothing shows a tiny dim ring, for the first three in a battle only, so a new player learns the touch was seen and does nothing.
**Specification**: 2 px neutral ring, radius 16, alpha 0.35, 150 ms fade-in, unanimated, no sound. Resets on retry. Not drawn for an arc dismissal. Its 2.5:1 contrast is an accepted exception (AR Known Intentional Limitations).
**When to Use**: only for `ground_tapped`.
**When NOT to Use**: other misses (roll-off, second finger, drag from a tower); those stay silent.
**Sources**: Input Rule 5, Game Feel; HUD Rule 14; art bible §7.
**Accessibility**: 2.5:1, an accepted exception; silent; three per battle at most.
**Implementation Notes**: The view listens to `ground_tapped`; the count resets on retry.

### HUD patterns

#### IP-15 Armed button

**Category**: HUD control · **Used in**: Start/Call; Retry and Play again get the same 300 ms through TapScreen `arm_ms` (IP-21)
**Description**: An irreversible button that may appear under a thumb waits 300 ms before a press counts.
**Specification**:
- States: Hidden (not registered), Arming (registered; only the 2 px outline dims, alpha 0.5 rising to full over 300 ms; a press made now is dead even if released once Armed), Armed (a new press counts).
- The labels stay at 4.5:1 or above while Arming, and the panel stays at 85%, since panel opacity never animates (AR-V-04, art bible §7). The HUD Visual table says the same (OI-05, resolved).
- Registers on appearing, not on arming, so an early press cannot land on what lies beneath.
- Clock from frame time, clamped to 100 ms per frame, frozen while Paused; a return from Paused is not a new appearance.
- Once armed: no pulse, no warning, no advice.
- Start/Call: (186, 800), 88 x 72 rect, hit radius 48. "Start" in Build; "Call +N" in Intermission ("Call" at bonus 0) with seconds left and a burst glyph beneath. Hidden in Wave.
**When to Use**: any button whose action cannot be undone and that appears without the player asking.
**When NOT to Use**: Paused (no timer; IP-22).
**Sources**: HUD Rules 10, 11, States table; Flow Game Feel. See OI-05, OI-10.
**Accessibility**: AR-V-04: labels at 4.5:1 or above in every state; only the outline dims (OI-05, AR change 15).
**Implementation Notes**: `HudLogic.advance(ms)` from the wrapper (ADR-0004).

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
**Accessibility**: A wrong grab is cheap; a wrong call or burst is not (AR-M-01).
**Implementation Notes**: The HUD checks the `pressed` winners; Stage `pin_exclusion` keeps 60 around each centre.

#### IP-17 Cost and unaffordable state

**Category**: Data display · **Used in**: arc disc panels, chip
**Description**: Every spend shows its price on a panel beside the thing it buys, and the price updates live as gold changes.
**Specification**:
- Cost in 16 dp tabular digits on panel. Read at draw time, never cached from when the arc or chip opened.
- Unaffordable: dimmed and struck through, no magenta. **Text alpha at least 0.6** (4.83:1, AR-V-05); the arc polygon may stay at 0.55. The HUD Visual table says the same (OI-01, resolved).
- A disc or chip that becomes affordable while open works at once.
- A refused tap gets a refusal (IP-24).
**When to Use**: any gold spend.
**When NOT to Use**: as a stat readout; no tower stats are shown.
**Sources**: HUD Rules 7, 9, Visual table; Tower UI Requirements; AR-V-04, AR-V-05.
**Accessibility**: AR-V-05: text alpha 0.6 or above (4.83:1); the strike, not hue, says unaffordable.
**Implementation Notes**: Read cost and gold at draw time; never cache them at open.

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
**Accessibility**: Fill, wedge, digit and dotted line tell the states, not hue; 64 dp; mirrors (IP-27).
**Implementation Notes**: `burst_y` places it; state comes from Hero signals; the Ready pop is cut under Reduce Motion.

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
**Accessibility**: AR-C-03: hides on the act, never on a timer; 14 dp at 11.2:1; must fit at 125% (AR-V-03).
**Implementation Notes**: The HUD picks the first match each frame; the burst line latches until `burst_started`.

#### IP-20 Read-only top band

**Category**: Data display · **Used in**: lives, wave pips, gold, next-wave line
**Description**: Bookkeeping sits in a top band that ignores input.
**Specification**:
- Band y 0 to `I_top + 72`. Lives: ten dashes; a lost one fades to alpha 0.2 and stays countable. Pips: filled done, outlined current, dotted upcoming. Gold digits swap, never bounce. Next-wave line: glyph and count per enemy type.
- Every Control here has `mouse_filter = IGNORE`.
**When to Use**: values the player glances at but never acts on.
**When NOT to Use**: anything tappable (see OI-06 for the pause control).
**Sources**: HUD Rules 1, 4, 5, Layout, Visual table; ADR-0003 Decision 4; art bible §7.
**Accessibility**: Read-only, so no stray tap lands; lost dashes stay countable.
**Implementation Notes**: `mouse_filter = IGNORE` on every Control (ADR-0003 D4).

### Modal patterns

#### IP-21 TapScreen modal

**Category**: Modal · **Used in**: Paused, Lost, Won
**Description**: A full-screen Control that takes every press, so a tap on it can never reach a tower or the hero.
**Specification**:
- `TapScreen`: full rect, takes every pointer event, no focus. Fires `tapped` only on the release of a press it saw; a cancelled release does not fire. Clears held presses after firing, on show and on the lifecycle signal.
- While it shows, the adapter's press gate is closed. A drag begun before it showed still ends once.
- A finger down when it appears, or across a focus loss, cannot fire it.
- Optional arming delay `arm_ms` (default 0), counted from when the owning screen starts it. A press counts only if it began after arming; one begun earlier is ignored even if released after. The screen that builds the TapScreen owns the value: the wrapper's result screen sets 300 for Retry and Play again; Paused keeps 0. Decided by the ADR-0003 amendment of 2026-11-04, confirmed by the user 2026-11-04 (OI-10).
**When to Use**: any screen that stops play.
**When NOT to Use**: in-battle choices (arc, chip); they are field discs.
**Sources**: HUD Rule 2; ADR-0003 Decisions 2.4, 4.
**Accessibility**: AR-P-02: an accessible name if a plain Control can carry one; no keyboard path.
**Implementation Notes**: `TapScreen` per ADR-0003 D4, with `arm_ms` and `start_arming(now_ms)` from its 2026-11-04 amendment (OI-10).

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
**Accessibility**: AR-C-02: static, no timer, no motion; one tap anywhere resumes.
**Implementation Notes**: A TapScreen with `arm_ms` 0, entered by Flow Rule 17.

#### IP-23 One-tap retry

**Category**: Modal · **Used in**: Lost, Won
**Description**: A plain result and one filled button to go again.
**Specification**:
- The modal mounts at the outcome, so input is dead at once. Text shows after 400 ms (Lost) or 1,000 ms (Won).
- Fixed order, 16 dp, same weight: headline, next-try line or lives, "Got through", damage by Towers, Hero, Burst.
- Retry (Lost) or Play again (Won), 128 x 72, is the only filled shape. No confirm. The result screen builds its TapScreen with `arm_ms` 300 and starts it when the text shows, so Retry arms 700 ms (Lost) or 1,300 ms (Won) after the outcome (IP-21, OI-10).
- Lost panel x 48 to 492, y 200 to 752. Won panel is compact (y 752 to 944) so the finished board stays in view.
- Retry sets an idempotent latch; a second tap does nothing.
**When to Use**: every stage end at MVP.
**When NOT to Use**: Vertical Slice replaces it with Stage Progression's report.
**Sources**: HUD Rules 15, 16, 18, Layout; Flow Rule 16, Game Feel; AR-C-06.
**Accessibility**: AR-C-06: plain, blame-free text; the button is 85 x 48 dp; armed, not confirmed.
**Implementation Notes**: The result screen sets `arm_ms` 300 from text show (OI-10). The retry latch sits on the app root, not in Flow: Retry calls `AppRoot.request_retry()` (ADR-0001 Decision 5).

### Feedback and cross-cutting patterns

#### IP-24 Refusal cue

**Category**: Feedback · **Used in**: unaffordable arc disc, unaffordable chip, locked burst button press
**Description**: A refused tap must look refused, not missed.
**Specification**:
- Normal: a 2 px nudge once for 120 ms, no magenta. Before the first pin, a locked press also repeats the prompt: the prompt line shows its text again for 1 s.
- Under Reduce Motion the nudge and the prompt repeat are skipped and **a static cue replaces them** (AR-V-11): the refused item shows a dotted outline and one short line of text naming the reason, "Need N gold" or "Locked", 14 dp on panel, for 1 s, with no motion. N is the cost minus gold at the refusal. The arc-and-chip and pin-and-aim specs place the line. User decision 2026-11-04 (OI-04, resolved).
- A cooling burst press is not a refusal: it shows the digit (IP-03).
**When to Use**: any tap that reaches its owner and is turned down.
**When NOT to Use**: misses that reach no owner; those stay silent (IP-14 aside).
**Sources**: Tower UI Requirements; Hero UI Requirements; HUD Rule 7; AR-V-11.
**Accessibility**: AR-V-11: under Reduce Motion, a dotted outline and a reason line for 1 s, with no motion.
**Implementation Notes**: Owners report NO_GOLD or Locked; the HUD draws nudge or cue from `PresentationSettings`.

#### IP-25 Visible clock

**Category**: Data display · **Used in**: chip bar, burst cooldown wedge and digit, intermission seconds
**Description**: Every timed thing shows its time.
**Specification**:
- Chip: a 3-unit bar draining linearly over 1.5 s (`chip_bar`). Burst: a clockwise wedge plus a digit. Intermission: seconds under Call.
- Digits use `display_seconds`, which shows 0 only at 0. Clocks are linear and stay under Reduce Motion.
**When to Use**: any window or cooldown.
**When NOT to Use**: protective delays (200 ms guards, 300 ms arming); they are not windows (AR Motor table).
**Sources**: HUD Rules 9, 10, 12, Formulas; art bible §7; AR-M-07, AR-M-08.
**Accessibility**: Multipliers stretch the clocks (AR-M-07, AR-M-08); clocks stay under Reduce Motion.
**Implementation Notes**: `display_seconds` and `chip_bar`; real-time clocks freeze while Paused.

#### IP-26 Reduce Motion fallback

**Category**: Cross-cutting · **Used in**: every animated element
**Description**: The `reduce_motion` flag swaps each motion for a still form that keeps the same fact. AR-V-10 is the one list.
**Specification**:
- The Reduce Motion column of Animation Standards is the rule: cut, frozen or kept, row by row.
**When to Use**: every new animation needs a row in Animation Standards and in AR-V-10.
**When NOT to Use**: n/a.
**Sources**: AR-V-10; HUD UI Requirements; Hero Visual table; art bible §7. See OI-04, OI-08.
**Accessibility**: AR-V-10 is the one list; the AR-V-08 flash limits still apply.
**Implementation Notes**: Read `reduce_motion` once from `PresentationSettings` (ADR-0001), never from the Input record.

#### IP-27 Handedness mirror

**Category**: Cross-cutting · **Used in**: burst button and its digit
**Description**: `left_handed` mirrors the burst button and its digit to the bottom-left. Nothing else moves.
**Specification**: x 84 instead of 456; the left burst line and Start/Call then refuse pins, and the bottom-right is free. Start/Call, the arc order, the kite and the aim offset never mirror. Fixed for a battle.
**When to Use**: only the dominant-hand control.
**When NOT to Use**: general HUD layout; full repositioning is out of scope.
**Sources**: HUD Edge Cases, Layout; Hero Rule 2, UI Requirements; AR-M-03.
**Accessibility**: AR-M-03: first-launch choice at Vertical Slice, a setting at Alpha.
**Implementation Notes**: `left_handed` is read once into `PresentationSettings`; the layout swaps x only.

### Planned patterns (committed, not built)

#### IP-28 Two-tap mode

**Category**: Input (alternative) · **Used in**: hero pin, burst aim · **Tier**: Alpha
**Description**: A setting that turns both drags into two taps, so no action needs a drag (AR-M-06).
**Specification (AR-M-06, nothing added)**: tap the hero, then the field, to pin. Tap the Ready burst button (visible armed state), then the field, to aim and fire; tap the button again to cancel.
**When to Use**: only as the opt-in setting.
**When NOT to Use**: the default mode, where a tap on the hero or burst button does nothing.
**Sources**: AR-M-06; Input Open Questions. See OI-07, OI-12.
**Accessibility**: AR-M-06, with the zero mis-fire bar; the Input GDD's P1 is the test gate.
**Implementation Notes**: Owners change; resolver signals do not. Blocked on OI-12.

#### IP-29 Pause control

**Category**: HUD control · **Used in**: every live phase · **Tier**: Vertical Slice (first phone build)
**Description**: A visible pause target, since iOS has no back button (AR-C-01).
**Specification (as committed)**: 48 dp target, outside the bottom 30%, must not take a press meant for the field; opens IP-22. Placement is open.
**When to Use**: from the first phone build.
**When NOT to Use**: MVP on desktop, where focus loss pauses.
**Sources**: AR-C-01. See OI-06.
**Accessibility**: AR-C-01; AR-M-02 48 dp; outside the bottom 30%.
**Implementation Notes**: Placement open (OI-06); opens IP-22.

---

## Gaps & Patterns Needed

**No UX specs exist yet**, so every pattern comes from the GDDs, ADRs, art bible and AR document. The HUD, arc-and-chip and pin-and-aim specs cite these IDs, and any pattern they add comes back here.

| Gap | Needed by | Owner | Notes |
|---|---|---|---|
| Placement of the static refusal cue's text line (IP-24; the cue was decided 2026-11-04) | MVP | Arc-and-chip and pin-and-aim UX specs | AR-V-11; Tower UX flag |
| Chip details: armed look after the guard, a chip that would leave the field, maximum-level cue (IP-11) | MVP | Arc-and-chip UX spec | Tower UX flag |
| Aim details: clamped reticle far from the thumb, preview past the reach ring, ring clipping, re-grabbing a hero pinned high | MVP | Pin-and-aim UX spec | Hero UX flag |
| Pause control placement (IP-29) | Vertical Slice | HUD spec with Menu & Screen Flow | AR-C-01; OI-06 |
| Menu controls and focus order with accessible names (see Standard controls) | Vertical Slice | Menu & Screen Flow | AR-P-01, AR-M-02 |
| First-launch screens: hand choice, photosensitivity notice | Vertical Slice | Menu & Screen Flow | AR-M-03, AR-V-09 |
| "How to play" help, reached from Pause | Vertical Slice | Onboarding Prompts | AR-C-04 |
| Skill tree node (owned filled, available outlined, locked dotted) | Vertical Slice | Skill Tree System | Art bible §3; AR matrix row 11 |
| Settings rows, each with "applies next battle"; game speed only if technical-director clears AR-C-08 | Alpha | Settings & Accessibility | AR-V-03, AR-M-04 to AR-M-08, AR-C-08, AR-C-10 |
| Two-tap mode details (IP-28) | Alpha | Hero, Input, Settings | OI-12 |

### Standard controls

| Control | Status |
|---|---|
| Button, modal | Used: IP-15, IP-18, IP-21 to IP-23 |
| Toggle, slider, list, grid, scroll, tab bar | Not used at MVP; deferred to the Vertical Slice menus (AR-P-01, AR-M-02) |
| Dropdown, toast, input field | Out of scope: no text entry, and nothing auto-dismisses (AR-C-03) |
| Tooltip, any hover state | Forbidden: touch has no hover. Help is IP-19 and "How to play" (AR-C-04) |

**Consolidation candidate.** IP-15 and IP-21 `arm_ms` share one rule: a press counts only if it began after the target armed.

**Not a pattern.** The Fatal screen takes no input at MVP (Flow Rule 18).

**Cross-reference check (2026-11-04).** Input, HUD, Tower, Hero and Flow UI requirements are covered; Combat, Enemy & Wave and Data own no interaction. Five floors were not met by the sources (OI-01 to OI-05); the GDDs and art bible met them on 2026-11-04. OI-17 is an accepted exception. Empty states: prompt (none after the first burst), damage rows and gold read 0.

---

## Open Questions

### Conflicts and open items

Each item names the sources that disagree and what this library follows. It edits no source.

| ID | Sources that disagree | Gap | Library follows | Owner |
|---|---|---|---|---|
| OI-01 | HUD Visual table "Unaffordable" (alpha 0.55) vs AR-V-05 | Cost text at 0.55 is 4.26:1, under 4.5:1 | Text at 0.6 or above (IP-17) | Resolved 2026-11-04: HUD Visual table sets text at 0.6 |
| OI-02 | Tower Visual table "Range ring" (next level at alpha 0.25) vs AR-V-06 | 1.65:1 on the path, under 3:1; told apart by alpha only | Nothing new; IP-10 cites the ring without a value | Resolved 2026-11-04: Tower Visual table draws the next ring dashed at 0.5 or above |
| OI-03 | Art bible §6 slot marks vs AR-V-07 | 1 px outline at 0.3 is 2.1:1; corner mark has no alpha | Nothing new | Resolved 2026-11-04: art bible §6 sets the corner mark at 0.45 or above |
| OI-04 | Tower, Hero and HUD UI Requirements (nudge skipped under Reduce Motion, no stand-in) vs AR-V-11 | A refused tap reads as a missed tap | IP-24: a dotted outline and a reason line ("Need N gold", "Locked") for 1 s, no motion | Resolved 2026-11-04 (user decision): Tower, Hero, HUD UI Requirements; the UX specs place the line |
| OI-05 | HUD Visual table "Start/Call" (Arming at alpha 0.5, rising to full over 300 ms) vs AR-V-04 and art bible §7 | Labels at 0.5 are 3.75:1, under 4.5:1; art bible §7 says panel opacity never animates | The floor: labels stay at 4.5:1 or above while Arming and only the outline dims (IP-15) | Resolved 2026-11-04: HUD Visual table; art bible §7 kept |
| OI-06 | HUD Rule 4, Flow Rule 17 and Input UI Requirements ("no pause button") vs AR-C-01 | iOS has no back button. The top band ignores input (IP-20) and the bottom 30% is reserved, so no place is free | IP-22 at MVP; IP-29 planned | HUD spec, Flow GDD (AR change 6) |
| OI-07 | Input burst sink, concept Pillar 4, Hero Rules 11 and 15 vs AR-M-06 | "A tap on the burst button does nothing" holds only in the default mode | IP-05 for default; IP-28 as the named exception | Input, Hero GDDs, concept (AR change 9) |
| OI-08 | HUD UI Requirements Reduce Motion line (slides only) vs AR-V-10 | The HUD line omits four rows | AR-V-10 (IP-26) | Resolved 2026-11-04: HUD UI Requirements point to AR-V-10 |
| OI-09 | Tower Rule 7 ("dimmed and does nothing") vs HUD Rule 7 (the disc calls `build`; NO_GOLD nudges) and Tower UI Requirements | Whether a refused disc tap shows a refusal | HUD Rule 7: the disc calls `build` and shows IP-24 | Resolved 2026-11-04: Tower Rule 7 matches HUD Rule 7 |
| OI-10 | HUD Rules 2 and 11, Flow Game Feel (Retry arms after 300 ms) vs ADR-0003 Decision 4 (`TapScreen` has no arming state) | No arming gate, and no owner for it | IP-21: TapScreen takes optional `arm_ms` (default 0) and ignores presses begun before arming; the result screen sets 300 (IP-23). **Decided by the ADR-0003 amendment of 2026-11-04** | Resolved. GDD side 2026-11-04 (HUD Rules 2 and 11, Flow Game Feel); ADR-0003 amendment done, confirmed by the user 2026-11-04 |
| OI-11 | HUD Rule 6 and AC 4 (arc guard on press time) vs Tower Rule 8 (chip guard on release time) | Two 200 ms guards on different clocks. A press at 150 ms released at 250 ms upgrades on a chip and is ignored on an arc | Both count from the press (IP-09, IP-10) | Resolved 2026-11-04 (user decision): Tower Rule 8 and its criteria now count from the press |
| OI-12 | AR-M-06 (owners change, resolver signals do not) vs Input Rules 4 and 5 | The hero has no TAP disc, so a tap on it emits nothing; a second tap reaches whatever lies beneath. No signal means "tap at any point" | IP-28 restates AR-M-06 only | Input, Hero GDDs; Settings & Accessibility (Alpha) |
| OI-13 | `.claude/docs/technical-preferences.md` Platform Notes ("skill button > tower > build slot > walkable ground") vs Input priority table | Legacy order is wrong and incomplete | Input priority (IP-04) | Project config owner (`/setup-engine`) |
| OI-14 | HUD panel sizes vs AR-V-03 | Sized for 100% text only | Nothing new | Battle HUD GDD (AR change 7, Alpha) |
| OI-15 | HUD content rules and Enemy & Wave L3 (checked at hit scale x1) vs AR-M-04 | Start/Call is 7.2 from the left burst disc and 17.3 from a slot; x1.25 breaks both | Nothing new | Battle HUD, Enemy & Wave GDDs (AR change 8, Alpha) |
| OI-16 | Hero UI Requirements ("before a first pin, the nudge also repeats the prompt") vs HUD Rule 13 and AR-V-10 | The prompt already shows; "repeat" is unstated, under Reduce Motion too | IP-24: the prompt line shows its text again for 1 s; under Reduce Motion, the static cue | Resolved 2026-11-04: Hero UI Requirements |
| OI-17 | Hero Visual "Cancelling" (reticle alpha 0.3) vs AR-V-04 | Now computed at about 2.4:1, under 3:1 | Accepted exception, as in the AR doc: the hidden preview and kill marks are the non-alpha backup | Resolved 2026-11-04 |
| OI-18 | AR header said this library did not exist | Was stale | n/a | Resolved 2026-11-04 |
| OI-19 | Concept Pillar 4 ("Drag priority: burst > hero") vs IP-04, IP-16, the Input table and Hero Rule 15 (hero 200 over burst 100) | The concept line is reversed | The GDDs are right (IP-04, IP-16) | Resolved 2026-11-04: Pillar 4 now reads hero over burst |

### Other open questions

| Question | Owner | Resolve by |
|---|---|---|
| No player journey map exists (`design/player-journey.md`); IP-19 and AR-C-04 need it | ux-designer | Before Vertical Slice UX specs |
| Do IP-01 to IP-13 hold on a phone? All evidence is one developer on a mouse. The gate is the Input GDD's P1 (two or more non-developer testers) | producer | First phone build |
| Adjacent arc discs are 4 units apart, and a wrong disc cannot be undone. First fallback: a larger `R` (AR-M-11) | Pillar 4 phone test | First phone build |
| Should only the chip's own disc commit, which would remove the same-tower commit and the 200 ms guard? | Pillar 4 phone test | First phone build |
| Is the prompt at the top seen while the eyes are on the lane? | First-run test | First playable |
| Pin offset 0 or 100 (IP-12), and the exclusion radius of 60 (IP-16) | Pillar 4 phone test | First phone build |

### Reviews

| Review | Status |
|---|---|
| ux-designer (this skill's primary agent) | **Review owed.** This session could not start agents; the library was drafted in session in autonomous mode |
| ui-programmer (feasibility of the component rules) | **Review owed** for the same reason |
| `/ux-review design/ux/interaction-patterns.md` | NEEDS REVISION 2026-11-04; fixed in this revision. Re-run before `/team-ui` |
