# Input & Gesture Resolver

> **Status**: Designed (pending independent review)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-01 — CONCERNS applied (phone test covers burst tap and unprompted fires, visible cancel state, reticle on `drag_started` and press response, verb claim corrected)
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-01
> **Last Verified**: 2026-11-01
> **Implements Pillar**: Pillar 4 (Thumb-First) directly; enabling system for Pillar 2 (the hero's pin and aimed burst are its two drags)

## Summary

Turns one thumb's press, movement and release into exactly one tap, one drag or nothing, delivered to exactly one registered target. Players never see it, but it is why a re-pin never buys a tower and a stray touch never fires the burst. It knows no features: the hero, towers and HUD register themselves and decide what a tap or drag means. Pillar 4 stays unverified until the phone test passes.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Data & Config Pipeline`

## Overview

The Input & Gesture Resolver is the one place a thumb's press becomes a game action. It owns a registry of hit targets, each registered by its owner (the hero, each tower, each build slot, the burst button) with a shape, a priority and the gestures it accepts, and it owns the rule that turns a press, a movement and a release into exactly one of **tap**, **drag** or **nothing**, delivered to exactly one target. It never names a feature system: it emits "tap on target 7" and "drag from target 3, now at (x, y)", and the owner decides what that means — a pin, an aimed burst, a build arc, an upgrade. Every tower defense on a phone lives or dies on this seam: with one thumb, one lane and four verbs, a drag that fires the wrong thing is worse than a miss, because it spends gold or moves the hero without consent. The concept's Pillar 4 (Thumb-First) makes this measurable: a first-phone-build test of 20 attempts per gesture with a non-developer tester allows at most 5% misses and zero mis-fires, and this system is where that number is won or lost. Without a resolver, each feature would read raw events itself, the priority order would live in four places, and the first overlapping hit area would produce a bug no single system owns. The resolver is small by design, the systems index's TD note fixes its scope to the registry and the priority order, and it is the only MVP system that is also a test instrument, since the bot acceptance modes drive the hero through the same tap and drag calls a thumb would.

Implementation questions raised while framing this section, all deferred: which Godot input path (`_unhandled_input` on a Node vs Control `_gui_input`) carries touch events into the resolver, how desktop mouse maps onto touch, and whether `Area2D` picking or the resolver's own geometry tests find targets → becomes an ADR. The pinned engine reference does not cover touch events, so that ADR must verify them against live 4.7 docs.

## Detailed Design

### Core Rules

**What the resolver is.** A pure object with no scene-tree dependency: a registry of hit targets, one active pointer, a four-state machine and a handful of signals. A thin adapter node (the only engine-facing code, specified in the ADR) translates Godot touch and mouse events into four calls: `press(pointer, pos)`, `move(pointer, pos)`, `release(pointer, pos)`, `cancel()`. Everything below is defined in terms of those four calls, so unit tests drive the resolver directly with synthetic positions and never touch an event, a viewport or a device.

**Positions and units.** Every position is in field units on the 540×960 reference field; the adapter converts from the screen. Thresholds are authored in field units too, so the resolver needs no display density. The field scales with device width, so a threshold's physical size grows on wider phones (see Formulas); the minimum supported width is 360 dp, where 72 units is 48 dp. The resolver never reads a camera, the display or the clock.

**Hit targets.** A target is a disc. Every MVP target in the art bible §3 size table is one, so no other shape exists (`shortcut: circles only, add a shape when a rectangular target registers`). An owner registers and later unregisters its own targets; the resolver never knows what a target is.

| Field | Type | Meaning |
|---|---|---|
| `id` | int, assigned at registration from a counter that never reuses a value | Returned to the owner; carried on every signal. A stale id can never alias a live target |
| `centre` | Vector2, field units | Owner updates it with `set_centre(id, pos)` when the thing moves (the hero re-pins) |
| `radius` | float | The owner's hit radius from the art bible §3 table: hero, tower, slot, build-arc disc 36 units; burst button 48 units |
| `accepts` | `TAP` or `DRAG` | Which gesture class this target competes in. A target that answers both gestures registers twice, as the burst button does |
| `priority` | int | Rank within its class; higher wins |
| `enabled` | bool | `set_enabled(id, false)` removes a target from hit tests without unregistering it (a slot once built) |

**Suggested registrations** (owners decide; listed here so the priority order is visible in one place and matches the concept's Pillar 4 order):

| Owner | Target | Class | Priority |
|---|---|---|---|
| Hero System | burst button (tap: burst at the pin) | TAP | 400 |
| Battle HUD | build-arc disc (only while an arc is open) | TAP | 300 |
| Tower System | tower, build slot (same tier; nearest centre wins) | TAP | 200 |
| Hero System | burst button (drag: aim) | DRAG | 200 |
| Hero System | hero | DRAG | 100 |

Towers and slots share a tier so a tower cannot steal a touch aimed at the slot beside it. This refines the concept's earlier tower > slot order.

**Rules.**

1. **One pointer.** The first `press` while Idle names the active pointer. Until that pointer releases or `cancel()` runs, every call with another pointer index is dropped, with nothing emitted. A palm or edge touch never cancels an aim and never counts as a tap. The exception: a press with no winner at all holds the pointer only until another press arrives, which replaces it silently, so a resting palm cannot block the thumb. A finger already down when the active one lifts never becomes active: it produced no press edge. A second `press` from the *active* pointer without a release (the release was lost) is treated as `cancel()` followed by that press: the old gesture died, and continuing it would carry the hero to wherever the finger landed.
2. **Two winners at press, fixed for the gesture.** On `press(p)` the resolver collects every enabled target whose disc contains `p` and keeps the best of each class: `best_tap` and `best_drag`, either of which may be none. Ties within a class break by priority, then by the nearer centre, then by the earlier `id`. Both winners are frozen: nothing the finger does afterwards re-targets. The resolver emits `pressed(best_tap, best_drag, p)` so owners can react to the press itself: the hero shows its leash while it is `best_drag` under a finger, and a tower whose cost chip is open closes it when a press names anything else. Every return to Idle emits an argument-free `idle()` after the gesture's own signal, so an owner that reacted to `pressed` always gets a matching "press over" edge: this is how the hero hides a leash it showed for a press that ended as a tap on a tower, or as nothing.
3. **Classification is spatial and sticky.** The gesture is a **tap** if the pointer releases before ever moving `drag_slop` from the press point (Formulas), and a **drag** from the first `move` at or beyond it. There is no tap duration limit and no long press: a press held for ten seconds and released in place is a tap, which is the accessibility floor and must not be tightened later for feel. Once a press is a drag it stays one; wobbling back to the origin never turns it into a tap. A release whose position is already at or beyond slop (move events lost or coalesced) is treated as a final move first: with a drag winner it emits `drag_started` then `drag_ended` in one call, otherwise the gesture is dead. It is never a tap, because a flick across a tower whose moves were dropped would otherwise be the second tap of an upgrade.
4. **A gesture reaches only its class winner, or nothing.** A tap goes to `best_tap`; a drag goes to `best_drag`. If the class has no winner the gesture reaches no target, and there is no fall-through to the other class or to a lower-priority target (a press with no winner at all still produces `ground_tap`, Rule 5). A drag from a slot or tower alone is therefore structurally not a pin, while a drag from a hero standing on a slot is, and a tap over the hero alone reaches no tap target. This is the rule that makes the concept's zero-mis-fire target provable rather than hoped for: a gesture can only ever fire the target that was on top, in its own class, at press.
5. **Taps.** On release while still under slop: `tap(best_tap, p)` if `best_tap` exists; `ground_tap(p)` if neither winner exists; nothing if only `best_drag` exists (the leash was already shown on press). Ground taps are emitted every time; the HUD decides how often to draw its rejection ring.
6. **Drags.** The first move at or past slop emits `drag_started(best_drag, press_pos, p)`; every subsequent `move` emits `drag_moved(best_drag, press_pos, p)`, one per input call and never per frame, and the owner caches the latest position for drawing; release emits `drag_ended(best_drag, press_pos, release_pos)`. The resolver passes finger positions only. The burst's offset reticle is Hero System's: one function there turns the finger position into the aim point, and both the HUD's reticle and the burst's detonation call it, so the ring drawn and the point hit cannot disagree.
7. **Cancel is host-driven only.** The resolver has no cancel gesture. Dragging back to the origin already has a meaning, which belongs to the owner: Hero treats a drag released on the burst button as cancelling the aim, and releasing the hero where it stands as re-pinning in place. The resolver just reports the release. `cancel()` is called by the composition root on app pause, window focus loss and an OS touch-cancel: in Dragging it emits `drag_cancelled(best_drag)` and the owner reverts to its pre-drag state (the hero keeps its old pin, the burst does not fire); in Pressed or Dead it returns to Idle silently. A release is never synthesised from a cancel: a pin completed by an incoming call would be a mis-fire.
8. **The cost-chip window is not the resolver's.** Tower System owns the 1.5 s second-tap window and hears `tap(tower)` twice. Tower must ignore a commit tap for 200 ms (proposed) after the chip opens, so a bounce cannot upgrade by accident. The resolver's whole contribution to "zero accidental upgrades" is Rules 1, 3, 4 and 7: a tap is emitted only on release of the active pointer, under slop, never after a drag began, never from a second finger, never on cancel, and never to a target that was not the tap winner at press.
9. **Two data fields.** `drag_slop` and `edge_reject_margin` are the fields of one Input record in the Data & Config catalogue, read directly rather than through the stat accessor, since no modifier targets them. The resolver takes `drag_slop` by injection; the adapter applies `edge_reject_margin`. Hit radii are the owners' values from their own records, and priorities are structural constants, not tuned. The constructor asserts `drag_slop` inside its 8–30 invariant (behind the catalogue validator, so a hand-built test fixture cannot bypass it), and `register` asserts `radius` above 0. A registry call naming an unknown id is a no-op with a debug error.
10. **Idle ignores movement.** Mouse hover and touch moves with no press are dropped in Idle. Non-left mouse buttons never reach the resolver (adapter).
11. **Bots use the same door.** The bot acceptance modes (towers-only, hero-only, never-pinned, pinned-once) drive the hero by calling `press`/`move`/`release` with synthetic positions, so the resolver is inside the loop that the acceptance modes measure, and a human and a bot reach the hero through one path.
12. **Rejected zones are the adapter's.** A press inside `edge_reject_margin` of a side edge, or inside the platform's safe-area or gesture insets, never reaches the resolver, even if it then drags onto a target. A drag that started elsewhere and moves into these zones stays valid. Insets are zero on desktop. Hero must refuse pins in these zones and under the burst button, or the hero becomes undraggable there; the burst button's centre sits at least `edge_reject_margin` + 48 units from a side edge.
13. **Gesture log.** In development builds a test harness listening to the signals logs each gesture: device and insets, down and up position and time, maximum travel, both winners and the rule that chose them, classification, emitted signal, and the `expected_action` and `expected_target` it prompted. The phone test computes misses and mis-fires from this. A miss is an expected action with no signal; a mis-fire is a signal for a different action, and a burst that fires with no burst prompt active counts as one. The resolver itself stays clock-free.

**Not owned.** What a tap or drag means (pin, burst, aim cancel, build, upgrade, arc), the cost-chip window, the reticle offset, hit radii, the rejection-ring count and timings, the burst button's placement and left-hand mirror (the button registers wherever the HUD puts it; the resolver has no handedness), safe-area insets, and the mapping of engine events to the four calls (ADR).

**Deliberately not built for MVP.** Rectangular targets, long press, a resolver-level cancel gesture, display-density handling, a polled drag position, per-frame drag signals, two-touch gestures, a tap duration limit, a runtime slop setter and a hit-area scale multiplier (both reserved in prose for Settings & Accessibility at Alpha: the first changes a constructor argument into a setter, the second multiplies `radius` in the hit test; neither changes a signal).

→ Becomes an ADR: the adapter node and which Godot path (`_unhandled_input` vs Control `_gui_input`) feeds it; `InputEventScreenTouch`/`ScreenDrag` field names and the `canceled` flag; the mouse-from-touch and touch-from-mouse emulation settings (one event family only, or every press arrives twice); whether event positions are already in the stretched 540×960 space and which stretch mode applies (the root `project.godot` has none yet); which lifecycle notifications drive `cancel()`; that Controls with `mouse_filter = STOP` consume events before the adapter sees them. **None of these is in the pinned engine reference (`modules/input.md` does not cover touch), so the ADR verifies each against live 4.7 docs before relying on it.**

### States and Transitions

| State | Meaning |
|---|---|
| Idle | No active pointer |
| Pressed | Active pointer down, under slop; `best_tap`, `best_drag`, `press_pos` held |
| Dragging | Past slop with a drag winner; `best_drag` receiving moves |
| Dead | Past slop with no drag winner; active pointer ignored until it lifts |

| From | Call | Guard | To | Emits |
|---|---|---|---|---|
| Idle | `press(i, p)` | — | Pressed | `pressed(best_tap, best_drag, p)` |
| Pressed, no winner at all | `press(other, p)` | — | as `cancel()` then `press`; `other` becomes active | per those rows; no `ground_tap` |
| Idle | `move` / `release` | — | Idle | — |
| Pressed | `move(i, p)` | distance from `press_pos` < slop | Pressed | — |
| Pressed | `move(i, p)` | ≥ slop and `best_drag` exists | Dragging | `drag_started(best_drag, press_pos, p)` |
| Pressed | `move(i, p)` | ≥ slop and no `best_drag` | Dead | — |
| Pressed | `release(i, p)` | under slop, `best_tap` exists | Idle | `tap(best_tap, p)` |
| Pressed | `release(i, p)` | under slop, no winner at all | Idle | `ground_tap(p)` |
| Pressed | `release(i, p)` | under slop, only `best_drag` | Idle | — |
| Pressed | `release(i, p)` | ≥ slop and `best_drag` exists | Idle | `drag_started` then `drag_ended(best_drag, press_pos, p)` |
| Pressed | `release(i, p)` | ≥ slop and no `best_drag` | Idle | — |
| Dragging | `move(i, p)` | — | Dragging | `drag_moved(best_drag, press_pos, p)` |
| Dragging | `release(i, p)` | — | Idle | `drag_ended(best_drag, press_pos, p)` |
| Dead | `move` | — | Dead | — |
| Dead | `release(i, p)` | — | Idle | — |
| Dragging | `cancel()` | — | Idle | `drag_cancelled(best_drag)` |
| Pressed, Dead | `cancel()` | — | Idle | — |
| Idle | `cancel()` | — | Idle | — |
| Pressed, Dragging, Dead | `press(active, p)` | — | as `cancel()` then `press` | per those rows |
| any other case | call with pointer ≠ active | — | unchanged | — |

Every row that reaches Idle also emits `idle()` after the signal shown. **Every row transitions before it emits**: the state and the frozen winners are committed before any owner hears about them, so an owner that registers, unregisters, disables or cancels inside a handler cannot alter the gesture in flight.

Registration calls (`register`, `unregister`, `set_centre`, `set_enabled`) are legal in every state. A target unregistered or disabled mid-gesture keeps receiving that gesture's remaining signals: the winners were fixed at press, and an owner that unregisters mid-drag is expected to ignore them.

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Game State & Stage Flow | builds and injects | Constructs the resolver with the Input record, owns the adapter node, hands the resolver to every owner, calls `cancel()` on pause and focus loss | Game State (composition); this system (API) |
| Data & Config Pipeline | reads | One Input record (`drag_slop`, `edge_reject_margin`), added under the extension rule with its domain rows and validator | Data & Config (catalogue); this system (field) |
| Hero System | registers, listens | Registers hero (DRAG 100) and burst button (TAP 400 and DRAG 200); updates the hero's centre on re-pin; listens to `pressed` for the leash, `tap` and `drag_*` for pin and burst; owns the finger-to-aim-point offset function. Burst meaning: a tap fires at the pin, a drag released on the button cancels (Hero hit-tests `drag_ended` itself), a drag released elsewhere fires there. The button stays enabled while cooling and Hero ignores it, so a touch there fires nothing and reaches nothing beneath; Hero samples cooling at `pressed`, so a press stays dead even if cooling ends during it | Hero System |
| Tower System | registers, listens | Registers towers and slots (both TAP 200); disables a slot once built; listens to `tap` for the chip and the second-tap commit, to `pressed` to close an open chip | Tower System |
| Battle HUD & Build UI | registers, listens | Registers build-arc discs (TAP 300) while an arc is open; listens to `pressed` to close the arc; listens to `ground_tap` for the rejection ring and counts the first few per session itself; its top-band Controls consume their own events before the adapter | Battle HUD |
| Settings & Accessibility (Alpha) | will call | Runtime slop setter and hit-area scale, reserved in prose only | Settings GDD adds them |
| Bot acceptance modes | call | `press`/`move`/`release` with synthetic positions | Hero System stories |

Nothing flows out of this system except its signals, and nothing flows in except the four calls, registrations and the one data field.

## Formulas

These are invariants of the resolver, not balance; the tunable value in them is `drag_slop`. Radii are hit radii, half the diameters in `design/art/art-bible.md` §3.

The **hit** formula is defined as:

`hit = enabled AND (p.x − c.x)² + (p.y − c.y)² ≤ r²`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `p` | Vector2, field units | inside the field | calculated | Press position |
| `c` | Vector2, field units | inside the field | registered by owner | Target centre |
| `r` | float, field units | 36–48 at MVP | registered by owner | Target hit radius |
| `enabled` | bool | true or false | set by owner | Target participates in hit tests |

**Output Range:** true or false, inclusive of the boundary. With at most about 13 MVP discs the cost is irrelevant, and squared distances keep the boundary exact.
**Example:** tower at (270, 480), r 36. Press at (300, 500): 900 + 400 = 1300 ≤ 1296 is false, a miss. Press at (299, 500): 841 + 400 = 1241 ≤ 1296, a hit.

The **is_drag** formula is defined as:

`is_drag = (p.x − p₀.x)² + (p.y − p₀.y)² ≥ drag_slop²`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `drag_slop` | float, field units | invariant 8–30, balance 12–18, default 15 | data file (Input record) | Movement that turns a press into a drag; kept below the smallest hit radius of 36 so a centred press cannot leave its target and still tap |
| `p₀` | Vector2, field units | inside the field | calculated | Press position |
| `p` | Vector2, field units | inside the field | calculated | Current position |

**Output Range:** true or false, inclusive, latching for the gesture. Tested on every move, so a frame hitch cannot skip it. Both ends of the balance range are first-build hypotheses: no phone data exists (CD-PLAYTEST).
**Example:** press (100, 100). Move (114, 100): 196 < 225, still Pressed. Move (115, 100): 225 ≥ 225, Dragging. An 18-unit roll on a tower tap: 324 ≥ 225, so no tap fires, which is a miss and never a mis-fire.

The **field_scale** formula is defined as:

`field_scale = width_dp / 540`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `width_dp` | float | 360–800 | calculated | Device width in dp |
| `field_scale` | float | 0.667–1.481 | calculated | dp per field unit |

**Output Range:** 0.667 at the minimum supported width. Below 360 dp is unsupported. A height-limited tablet may scale by height instead; stretch mode is unverified and belongs to the ADR.
**Example:** 360 / 540 = 0.667.

The **target_ok** formula is defined as:

`target_ok = 2 × r × field_scale ≥ 48`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `r` | float, field units | 36–48 at MVP | registered by owner | Target hit radius |
| `field_scale` | float | 0.667–1.481 | calculated | From field_scale |

**Output Range:** true at every supported width for a radius of at least 36.
**Example:** 2 × 36 × 0.667 = 48.0, passes. At 320 dp it would be 42.7 and fail, which is why 360 dp is the minimum.

| Width (dp) | 72-unit target | 96-unit target | `drag_slop` 15 | `edge_reject_margin` 36 |
|---|---|---|---|---|
| 360 | 48.0 dp | 64.0 dp | 10.0 dp | 24.0 dp |
| 430 | 57.3 dp | 76.4 dp | 11.9 dp | 28.7 dp |
| 800 | 106.7 dp | 142.2 dp | 22.2 dp | 53.3 dp |

**Tie-break within a class:** higher `priority`, then smaller squared distance to centre, then lower `id`.

**Input record domains.** `drag_slop` default 15, hard domain 8–30. `edge_reject_margin` default 36, hard domain 0–48; its value comes from memory of Android's back-swipe zone and must be checked on devices.

## Edge Cases

"Dead" means the gesture emits nothing more and the active pointer is ignored until it lifts. Cases the rules already settle (slop exactly equal is a drag; a press exactly on a disc edge hits; hero over slot taps the slot and drags the hero; a disabled target is simply absent; a drag from a hero on a slot pins) are not repeated.

**State machine**
- **If `cancel()` is called while Idle**: no-op. The host may call it unconditionally on pause.
- **If a release arrives in Pressed at or beyond slop (moves lost or coalesced)**: `drag_started` then `drag_ended` in one call when a drag winner exists; otherwise nothing. Never a tap (Rule 3).
- **If the active pointer presses again without a release**: `cancel()` then the new press; Dragging emits `drag_cancelled` first (Rule 1).
- **If the finger lifts in place over the hero alone**: nothing but `idle()`; the hero hides its leash on `idle()`, not on a tap it never receives.
- **If an owner registers, unregisters, disables, moves a target or calls `cancel()` inside a `pressed` handler**: the gesture is unaffected, because every row transitions and freezes its winners before emitting; a re-entrant `cancel()` returns to Idle and the eventual release is dropped there.
- **If a target is unregistered or disabled mid-gesture**: it still receives that gesture's remaining signals under its old id; the owner ignores them. Ids are never reused, so a stale id cannot alias a new target.
- **If a target is registered mid-gesture under the finger**: it receives nothing from the current gesture, even if it is the only disc under the release point. The arc discs the HUD registers in response to a slot tap compete from the next press.
- **If `cancel()` ran and the OS later delivers the same pointer's move or release**: dropped in Idle; the finger must lift and press again. Focus-return on Android does exactly this.
- **If a second finger is down when the active one lifts and then moves**: dropped; a finger becomes active only by producing a press edge. A two-finger handover cannot continue a drag.
- **If a drag winner is disabled mid-drag**: `drag_moved` and `drag_ended` continue to that id; the owner decides whether to honour the release. `enabled` is tested only at press.
- **If a bot issues two gestures without the first's release**: identical to the lost-release case. The bot and the thumb share one path (Rule 11).
- **If a pause lands in Pressed and the finger then moves past slop and lifts**: nothing fires. A pause during a tap is a miss, never a late action on resume.

**Formulas and construction**
- **If `drag_slop` is outside 8–30**: the Data & Config validator rejects the record at load; the constructor's assert is the second line for hand-built fixtures.
- **If the width is below 360 dp**: unsupported, because targets would fall under 48 dp. The export's minimum device specification must exclude it.
- **If `radius` is 0 or negative at `register`**: debug assert. No MVP radius is below 36, so this guards fixtures only.
- **If a move arrives at exactly `press_pos`**: distance 0 is below any legal slop; stays Pressed.
- **If a press lands outside the field (mouse off-window, or a disc straddling an edge)**: the hit test runs unmodified; a disc is hit from its off-screen half, and a press hitting nothing emits `ground_tap` with an off-screen position the HUD may ignore. Whether off-window mouse presses reach the resolver at all is the adapter's (ADR).
- **If a drag ends outside the field**: `drag_ended` carries the unclamped position; the owner clamps the pin or aim into the field. Touch hardware usually reports this as an OS cancel instead.
- **If two targets of one class share priority and centre**: the earlier id wins. A double-registered target is an owner bug the resolver does not deduplicate.
- **If a TAP and a DRAG target share a priority number**: no interaction; priorities compare only within a class.
- **If the viewport is resized or re-stretched mid-gesture**: `press_pos` is not rescaled; the adapter keeps one coordinate space for the gesture's life or calls `cancel()` on resize (ADR).

**Overlaps and owner-facing outcomes**
- **If a press hits nothing**: `pressed(none, none, p)` still fires, so open chips and arcs close on the press; release under slop emits `ground_tap(p)`; a move past slop makes it dead.
- **If a press lands on the burst button while cooling**: the gesture reaches Hero, which ignores it, so nothing fires and nothing beneath is reached.
- **If cooling ends during that press**: it stays dead until a new press, because Hero samples cooling at `pressed`.
- **If the burst button is tapped while an arc is open**: the burst fires, since TAP 400 outranks the arc, and `pressed` closes the arc.
- **If a second press arrives while a press with no winner is down (a palm, then the thumb)**: the second press becomes active and the first emits nothing further (Rule 1).
- **If a press lands inside a rejected zone**: the resolver never hears it, even if it drags onto a target (Rule 12).
- **If the ready burst button is pressed and released in place**: `tap(button)` then `idle()`; the burst fires at the pin. A stray tap therefore spends the cooldown; see Open Questions.
- **If a drag from the ready burst button slips within the button and releases there**: `drag_ended` on the button; Hero cancels. A miss, never a mis-fire.
- **If a tap winner lies inside a drag winner and the finger lifts in place (tower over hero)**: `tap(tower)` then `idle()`; the hero drops its leash on `idle()`. A hero on a slot never blocks building; a tower never blocks a re-pin.
- **If the hero is pressed over a tower and the finger drags**: `drag_started(hero)`; the tower that kept its chip open on `pressed(tower, hero, p)` sees no `tap`, and its 1.5 s window counts taps only, so the drag can never commit an upgrade.
- **If an arc is open and the press lands on a tower or another slot outside the discs**: `pressed` closes the arc (HUD) and the release still delivers `tap` to the thing under the thumb: dismissing and acting in one press is the one-thumb economy Pillar 4 asks for, and neither outcome spends gold.
- **If an arc is open and the press lands on ground**: `pressed(none, none, p)` closes the arc; the release emits `ground_tap`, which the HUD should not draw a rejection ring for when the tap's job was dismissal (HUD's rule).
- **If an arc disc overlaps the hero and the finger drags from it**: `pressed(arc_disc, hero, p)`; the drag goes to the hero and the disc never receives a tap. The HUD should close the arc on `drag_started` since the thumb has left the build decision.
- **If a press lands on a built slot with its tower on top**: the slot is disabled and not a candidate; the tower wins, which is the upgrade-chip path. If a tower is removed, Tower System re-enables the slot in the same change, or the press becomes a ground press.
- **If a pointer id is reused by the OS after a lift**: harmless; equality is tested only while a pointer is active.

## Dependencies

**Upstream (hard):** Data & Config Pipeline, for the Input record. It relies on the engine only through the adapter node, which the ADR specifies.

**Downstream (hard unless noted; none has a GDD yet, so every interface is provisional until that GDD confirms it):**

| System | Interface | Hard / soft |
|---|---|---|
| Game State & Stage Flow | Constructs and injects the resolver; owns the adapter; calls `cancel()` on pause and focus loss | Hard — nothing receives input without it |
| Hero System | Registers hero and burst button; listens to `pressed`, `tap`, `drag_*`; owns the aim-point offset and what a burst tap or drag means; refuses invalid pins | Hard — pin and burst are this system's two drags |
| Tower System | Registers towers and slots as TAP targets; listens to `tap` and `pressed`; owns the cost-chip window | Hard — build and upgrade are its two taps |
| Battle HUD & Build UI | Registers arc discs while an arc is open; listens to `pressed` and `ground_tap`; its Controls sit above the adapter | Hard for the build arc and rejection ring |
| Settings & Accessibility (Alpha) | Runtime slop setter, hit-area scale | Soft — reserved in prose, nothing built |
| Mobile Platform & Performance (VS) | Safe-area and gesture insets feed the adapter and the HUD's button placement, not the resolver | Soft |

Per the bidirectional rule, each of these GDDs must list this one when authored. The Data & Config GDD and the systems index already list this system.

## Visual/Audio Requirements

This system draws nothing and plays nothing. Every visual that answers a gesture is owned elsewhere and triggered by this system's signals, so the mapping is recorded here once:

| Signal | Visual (owner) | Art bible |
|---|---|---|
| `pressed` with the hero as `best_drag` | Leash ring shown (Hero System) | §3 line styles: 2 px dashed, alpha 0.5; §7 two-tone over the path |
| `pressed` naming the ready burst button | Button press response, visible within 50 ms (proposed) and extending beyond the fingertip (HUD) | §7 Burst button |
| `drag_started` and `drag_moved` from the burst button | Offset reticle 60–80 dp above the finger, flipped near the top (Hero System computes, HUD draws) | §7 Reticle |
| Finger inside the burst button during an aim | Visible cancel state: reticle dimmed and radius preview hidden, so an aim that will cancel never looks live (Hero System decides from `drag_moved`, HUD draws) | §7 Reticle |
| `drag_moved` from the hero | Leash preview at the finger (Hero System) | §5 Pinned pose |
| `ground_tap` | Tiny unanimated dim ring, 150 ms fade-in, first few taps of a session only, no sound (Battle HUD) | §7 Ground tap |
| `tap` on a tower | Cost chip for 1.5 s (Tower System / HUD) | §7 Build/upgrade affordance |
| `tap` on a slot | Build arc of three role discs above the slot (Battle HUD) | §7 |
| `drag_cancelled` | Leash preview and reticle removed; nothing fires (owners) | — |

Audio: none at MVP (concept: audio minimal). The ground tap is silent by design. Any later input sound is the owning system's event, not this system's.

## Game Feel

The resolver's feel targets are latency and predictability, both set here because they are architecture, not polish:

- **Press feedback on the press, not the release.** The leash appears on `pressed`, before the player has decided whether this is a tap or a drag, so the first frame of touching the hero already says "this is yours". The ready burst button answers its press too, since the reticle cannot appear until `drag_slop` is crossed, which is later than the mouse prototype. Everything else answers a classified gesture.
- **Classification within one move event.** The slop test runs on every `move`, so a drag is recognised on the first sample past `drag_slop` with no debounce, no timer and no frame of waiting. A pull that reaches slop in the same input event that leaves the disc still counts: the winners were fixed at press.
- **Few verbs, all taught.** There is no long press and no double tap. The hero has one verb, the pin. The burst button has three behaviours: tap to fire at the pin, drag to aim, drag back to cancel. Onboarding Prompts (Vertical Slice) teaches them; until then the visible cancel state carries the third.
- **A miss is silent except on the ground.** A drag from a tower, a tap over the hero alone and a second-finger touch produce no feedback at all. Silence reads as "nothing happened", which is correct; a rejection cue on every miss would train the player to look at the field instead of the lane.
- **Sticky drag.** Once a drag, always a drag: a re-pin that wanders back over the hero never collapses into a tap, so a nervous thumb cannot cancel its own pin by hesitating.

The quantitative feel criterion is the concept's phone test (Acceptance Criteria), not a frame budget: the resolver's per-event work is a handful of squared distances against at most about thirteen discs.

## UI Requirements

None owned. This system has no screen, panel or widget; it supplies gestures to the systems that do. Two constraints on UI that other systems must honour are recorded here because the resolver assumes them:

- The burst button is a registered disc owned by Hero System and placed by the HUD, not a Control, so it competes in this system's priority order rather than the engine's Control ordering; the HUD's top-band panels and pause button are Controls that consume their own events before the adapter sees them (art bible §7 panel placement: bottom 30% holds only the button and the field).
- No build slot may sit so close to the burst button that their hit discs overlap at any supported safe-area inset: the button's priority would make part of that slot untappable. Owner: whoever authors slot positions per stage (Enemy & Wave / stage scenes). See Open Questions.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Priority order, slop range, 48 dp targets, phone test (0 mis-fires, ≤5% misses) | `design/gdd/game-concept.md` | Pillar 4, Core Mechanic 2, MVP item 6 | Rule dependency |
| Registry-only scope; owners register themselves; Input never names a feature | `design/gdd/systems-index.md` | Foundation Layer TD note (item 2); High-Risk Systems row | Rule dependency |
| Hit radii 36 / 48 units; 1.5 units per dp at 360 dp | `design/art/art-bible.md` | §3 Minimum sizes | Value dependency |
| Reticle offset and flip, ground-tap ring, cost chip, build arc, panel band | `design/art/art-bible.md` | §7 | Ownership handoff |
| Input record, added under the extension rule by this GDD | `design/gdd/data-config-pipeline.md` | Extension rule; Interactions (Input row); Dependencies | Rule dependency |
| Injection by the composition root | `design/gdd/data-config-pipeline.md` | Rule 12 | Pattern reuse |
| Press priority as prototyped; mouse-only evidence | `prototypes/hero-pin-concept/main.gd`, `REPORT.md` | `_press`/`_release`; Pillar 4 untested on a phone | Evidence |

## Acceptance Criteria

A recording fake connects to every signal, and each THEN is the entire log: anything unlisted fails. All Logic criteria use factory fixtures, plain calls with no engine input events and no scene, `drag_slop` 15 unless stated, no random seeds and no time assertions.

**CI: Logic**
1. (Rule 1) **GIVEN** pointer 0 on a tower, **WHEN** pointer 1 presses and releases, 0 releases, then 1 moves, **THEN** `pressed, tap(tower), idle`.
2. (Rule 1) **GIVEN** a press with no winner down, **WHEN** another pointer presses a tower and releases, **THEN** the log has no `ground_tap` and ends `pressed(tower), tap(tower), idle`.
3. (Rule 1) **GIVEN** an active drag, **WHEN** the same pointer presses again, **THEN** `drag_cancelled` and `idle` precede the new `pressed`.
4. (Rule 2) **GIVEN** a hero on a slot, **WHEN** press, move the hero's centre with `set_centre`, release, **THEN** `pressed(slot, hero, p), tap(slot), idle`.
5. (Rule 3) **GIVEN** a hero, **WHEN** move 15, return to the origin, release, **THEN** `pressed, drag_started, drag_moved, drag_ended, idle`, and no `tap`.
6. (Rule 3) **GIVEN** a tower, **WHEN** press and release 15 units away with no move, **THEN** `pressed, idle`, and no `tap`.
7. (Rule 4) **GIVEN** a slot alone, **WHEN** move 15, move, release, **THEN** `pressed, idle`.
8. (Rule 5) **GIVEN** a tower, empty ground and a hero alone in turn, **WHEN** released in place, **THEN** `tap(tower)`, `ground_tap`, and neither, each followed by `idle`.
9. (Rule 6) **GIVEN** a hero on a slot, **WHEN** move 15, two moves, release, **THEN** `pressed, drag_started, drag_moved×2, drag_ended, idle`, with exact positions, and no signal names the slot.
10. (Rule 7) **GIVEN** Dragging, Pressed and Dead in turn, **WHEN** `cancel()` then release, **THEN** only Dragging logs `drag_cancelled`, each logs one `idle`, and no `tap` or `drag_ended` appears.
11. (Rule 8) **GIVEN** a tower, **WHEN** two press-and-release pairs, **THEN** exactly two `tap`, with the second press naming the tower again.
12. (Rule 9) **GIVEN** a hero and an injected `drag_slop` of 8, **WHEN** moved 8, **THEN** `drag_started`. **GIVEN** a fixture value of 7 or 31, **WHEN** constructed, **THEN** the assert fires.
13. (Rule 10) **GIVEN** Idle, **WHEN** move then release, **THEN** an empty log.
14. (Determinism) **GIVEN** two fresh resolvers and the same call list, **WHEN** run, **THEN** identical logs.
15. (Registry) **GIVEN** a disabled target, **WHEN** pressed, **THEN** it is not named; re-enabled, it is. **GIVEN** a slot in Pressed, **WHEN** disabled and released, **THEN** `tap(slot)` still fires.
16. (Burst) **GIVEN** the burst button registered as TAP 400 and DRAG 200 over a slot and a hero, **WHEN** released in place, **THEN** `tap(button), idle` and the slot gets nothing; **WHEN** moved 15 and released, **THEN** drags name the button and the hero gets nothing.
17. (Formula: hit) **GIVEN** a target at (270, 480) r 36, **WHEN** pressed at (306, 480), (307, 480), (299, 500), (300, 500), **THEN** hit, miss, hit, miss.
18. (Formula: is_drag) **GIVEN** a press at (100, 100), **WHEN** moved to (109, 111) then (109, 112), **THEN** Pressed, then Dragging. (Distances squared 202 and 225.)
19. (Tie-break) **GIVEN** overlapping TAP targets, **WHEN** pressed, **THEN** the arc disc beats a nearer tower; between tower and slot at equal priority the nearer wins; at equal distance the lower `id` wins.
20. (Formula: target_ok) **GIVEN** every MVP hit radius (36, 48) at 360 dp, **WHEN** evaluated, **THEN** each passes; 35.9 fails.

**Manual**
21. (Pillar 4, first phone build) **GIVEN** a phone at 360 dp width or more and a non-developer tester, **WHEN** 20 attempts each of slot tap, tower tap, pin drag, burst tap and burst drag are prompted, **THEN** misses are at most 5% per gesture and mis-fires are zero, including accidental upgrades and any burst fired with no burst prompt active, computed from the gesture log. Until this passes, Pillar 4 is unverified.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner |
|---|---|
| Pin, aim, burst meaning (tap fires, return cancels, cooling ignored), refusing invalid pins, bots through `press`/`move`/`release` (Rule 11) | Hero stories |
| Chip window, 200 ms bounce guard, upgrades | Tower stories |
| Arc close, ground ring, press feedback within 50 ms (proposed), visible cancel state | Battle HUD stories |
| `cancel()` wiring on pause and focus loss, injection | Game State stories |
| Adapter: one press gives one gesture, rejected zones, coordinate conversion | Input ADR and first phone build |
| Gesture log contents (Rule 13) | Test harness story |

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Adapter: which Godot path feeds the four calls; touch event field names and `canceled`; emulation settings (one event family only); whether positions arrive in the stretched 540×960 space and which stretch mode; lifecycle notifications for `cancel()`; Control `mouse_filter` ordering. None is in the pinned reference | technical-director, `/architecture-decision` | Before the first input story |
| Do the 15-unit slop and the 36/48-unit radii hold on a phone with a non-developer tester? All evidence is one developer on a mouse (CD-PLAYTEST) | producer + Hero/Tower stories | First phone build (Pillar 4 test) |
| No slot's hit disc may overlap the burst button's at any supported safe-area inset. Who owns slot positions per stage, and where is this constraint written so it exists? | Enemy & Wave GDD (stage scenes) + art bible §6/§7 | Enemy & Wave GDD |
| Hero: pin at the finger position means the thumb covers the pin at release. If the phone test shows pin misses, does Hero route pins through its offset function too? | Hero GDD | First phone build |
| Hero: should re-pinning be instant or a short walk? If "walk", the hero needs path-following and the concept's "no pathfinding" claim is revisited (concept Open Questions). The resolver is unaffected either way | Hero GDD | Hero GDD |
| Battle HUD: how many ground-tap rejection rings per session, and which `ground_tap`s are suppressed (a tap that dismissed an arc) | Battle HUD GDD | Battle HUD GDD |
| Settings & Accessibility: runtime slop setter ("steady hand" ×1.5) and hit-area scale; a two-tap alternative to dragging for players who cannot drag. Hooks are reserved in prose only; the owner API (target, press, release) already hides the physical gesture from owners | Settings & Accessibility GDD | Alpha |
| Should the Input record gain `tap_max_ms` or anything else? Current answer: no; the no-timeout rule is the accessibility floor. Revisit only with phone evidence | ux-designer | First phone build |
| Does a stray tap burning the burst's 8 s cooldown show up in the phone test? If so, a tap does nothing and fire-at-pin needs another gesture | Hero GDD | First phone build |
| Is the 36-unit edge margin right on real Android and iOS devices? From memory, not sourced | gameplay-programmer | First phone build |
| On a tablet `drag_slop` is 22 dp wide at 800 dp: acceptable, or do tablets need a scale cap? | technical-director | Input ADR |
| Is the 5% miss limit per gesture or pooled? This document reads it per gesture | producer | First phone build |
| gdUnit4 behaviour asserting signals on a `RefCounted` with no scene tree is unverified; tests record signals into an array instead | gameplay-programmer | First test story |
