# Input & Gesture Resolver

> **Status**: Revised (pending re-review)
> **Design Review**: NEEDS REVISION 2026-11-01 three times (the third, lean and not independent, found one blocker: Dead sink-only press replaceable, applied) (9, then 8 blocking), revised each time the same day. Second pass: tap_slop whenever a real tap winner exists, palm replacement extended, burst TAP sink, phone test moved to the Pillar 4 milestone gate and counted per gesture (all user decisions); queue, snapshot, validation and adapter fixes.
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-01 — CONCERNS applied (unprompted fires count, visible cancel state, reticle on `drag_started` and press response, verb claim corrected; burst tap later removed by the drag-only decision)
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-04
> **Last Verified**: 2026-11-01
> **Implements Pillar**: Pillar 4 (Thumb-First) directly; enabling system for Pillar 2 (the hero's pin and aimed burst are its two drags)

## Summary

Turns one thumb's press, movement and release into exactly one tap, one drag or nothing, delivered to exactly one registered target. Players never see it, but it is why a re-pin never buys a tower and a stray touch never fires the burst. It knows no features: the hero, towers and HUD register themselves and decide what a tap or drag means. Pillar 4 stays unverified until the phone test passes.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Data & Config Pipeline`

## Overview

The Input & Gesture Resolver is the one place a thumb's press becomes a game action. It owns a registry of hit targets, each registered by its owner (the hero, each tower, each build slot, the burst button) with a shape, a priority and the gestures it accepts, and it owns the rule that turns a press, a movement and a release into exactly one of **tap**, **drag** or **nothing**, delivered to exactly one target. It never names a feature system: it emits "tap on target 7" and "drag from target 3, now at (x, y)", and the owner decides what that means — a pin, an aimed burst, a build arc, an upgrade. Every tower defense on a phone lives or dies on this seam: with one thumb, one lane and four verbs, a drag that fires the wrong thing is worse than a miss, because it spends gold or moves the hero without consent. The concept's Pillar 4 (Thumb-First) makes this measurable: a first-phone-build test of 20 attempts per gesture with a non-developer tester allows at most 5% misses and zero mis-fires, and this system is where that number is won or lost. Without a resolver, each feature would read raw events itself, the priority order would live in four places, and the first overlapping hit area would produce a bug no single system owns. The resolver is small by design, the systems index's TD note fixes its scope to the registry and the priority order, and it is also a test seam: one equivalence test runs a script through it and the same script through Hero's and Tower's commands (Rule 11), while headless bots call those commands directly.

Implementation questions raised while framing this section, all deferred: which Godot input path (`_unhandled_input` on a Node vs Control `_gui_input`) carries touch events into the resolver, how desktop mouse maps onto touch, and whether `Area2D` picking or the resolver's own geometry tests find targets → becomes an ADR. The pinned engine reference does not cover touch events, so that ADR must verify them against live 4.7 docs. ADR-0003 (Accepted) now answers these, pending its S0 spike.

## Detailed Design

### Core Rules

**What the resolver is.** A pure object with no scene-tree dependency: a registry of hit targets, one active pointer, a four-state machine and a handful of signals. A thin adapter node (the only engine-facing code, specified in the ADR) translates Godot touch and mouse events into five calls: `press(pointer, pos)`, `move(pointer, pos)`, `release(pointer, pos)`, `cancel_pointer(pointer)` for an OS cancel of one touch, and `cancel()` for a lifecycle event. Everything below is defined in terms of those calls, so unit tests drive the resolver directly with synthetic positions and never touch an event, a viewport or a device.

**Positions and units.** Every position is in field units on the 540×960 reference field; the adapter converts from the screen. Thresholds are authored in field units too, so the resolver needs no display density. The field scales by the smaller of device width over 540 and device height over 960 (ADR-0003's `keep` stretch), so a threshold's physical size grows on larger screens (see Formulas); the minimum supported screen is 360 dp wide and 640 dp tall, where 72 units is 48 dp. The resolver never reads a camera, the display or the clock.

**Hit targets.** A target is a disc. Every MVP target in the art bible §3 size table is one, so no other shape exists (`shortcut: circles only, add a shape when a rectangular target registers`). An owner registers and later unregisters its own targets; the resolver never knows what a target is.

| Field | Type | Meaning |
|---|---|---|
| `id` | int, assigned at registration from a counter starting at 1 that never reuses a value; `NONE` is −1 | Returned to the owner; carried on every signal. A stale id can never alias a live target; `NONE` marks an absent winner |
| `centre` | Vector2, field units | Owner updates it with `set_centre(id, pos)` when the thing moves (the hero re-pins) |
| `radius` | float | The owner's hit radius from the art bible §3 table: hero's drag 56 units; tower, slot, build-arc disc 36 units; burst button 48 units |
| `accepts` | `TAP` or `DRAG` | Which gesture class this target competes in. A target that answers both gestures registers twice, under two ids |
| `priority` | int | Rank within its class; higher wins |
| `enabled` | bool | `set_enabled(id, false)` removes a target from hit tests without unregistering it (a slot once built) |
| `sink` | bool, TAP only | The target absorbs taps its owner ignores. It wins the tap class like any other, but it does not raise the press's slop and it does not hold the pointer against a replacing press |

**Suggested registrations** (owners decide; listed here so the priority order is visible in one place and matches the concept's Pillar 4 order):

| Owner | Target | Class | Priority |
|---|---|---|---|
| Hero System | burst button sink (a tap here does nothing, and reaches nothing beneath) | TAP, sink | 400 |
| Battle HUD | Start/Call button (Build and Intermission only) | TAP | 350 |
| Battle HUD | build-arc disc (only while an arc is open) | TAP | 300 |
| Tower System | upgrade chip (only while a chip is open) | TAP | 300 |
| Battle HUD | arc backdrop (only while an arc is open; one disc covering the field, so a press outside the arc discs only dismisses) | TAP, sink | 250 |
| Tower System | tower, build slot (same tier; nearest centre wins) | TAP | 200 |
| Hero System | hero | DRAG | 200 |
| Hero System | burst button (drag: aim) | DRAG | 100 |

Towers and slots share a tier so a tower cannot steal a touch aimed at the slot beside it. This refines the concept's earlier tower > slot order. The burst is drag-only: a tap on the button reaches its sink and does nothing, so a resting thumb can never spend the cooldown and a slot beneath can never receive the touch (user decisions, 2026-11-01 reviews; concept Core Mechanic 2).

**Rules.**

1. **One pointer.** The first `press` while Idle names the active pointer. Until that pointer releases or `cancel()` runs, every call with another pointer index is dropped, with nothing emitted. A palm or edge touch never cancels an aim and never counts as a tap. The exception is a press nothing is waiting on: an unmoved press with no real tap winner (none, or only a sink), and a Dead press with no real tap winner. A press on a real tap target never counts, and neither does a drag that has begun. Such a press holds the pointer only until another press arrives, which replaces it as `cancel()` then `press`, so the first emits `idle()` and nothing else, and a resting palm cannot block the thumb, even on the hero or the burst button. A moved drag or a press on a real tap target still holds. A finger already down when the active one lifts never becomes active: it produced no press edge. A second `press` from the *active* pointer without a release (the release was lost) is treated as `cancel()` followed by that press: the old gesture died, and continuing it would carry the hero to wherever the finger landed. An OS cancel of one touch arrives as `cancel_pointer(i)`: for the active pointer it is `cancel()`; for any other pointer it is dropped, so a cancelled palm never ends a live aim. The resolver has no clock, so a press whose release and cancel are both lost strands the gesture until the next press of the same index: the adapter contract (Dependencies) is that this never happens.
2. **Two winners at press, fixed for the gesture.** On `press(p)` the resolver collects every enabled target whose disc contains `p` and keeps the best of each class: `best_tap` and `best_drag`, either of which may be none. Ties within a class break by priority, then by the nearer centre, then by the earlier `id`. Both winners, and each one's centre and radius at that moment, are frozen: nothing the finger or an owner does afterwards re-targets or moves them. The resolver emits `pressed(best_tap, best_drag, p)` so owners can react to the press itself: the hero shows its leash while it is `best_drag` under a finger, and a tower whose cost chip is open closes it when a press names anything else. Every return to Idle emits an argument-free `idle()` after the gesture's own signal, so an owner that reacted to `pressed` always gets a matching "press over" edge: this is how the hero hides a leash it showed for a press that ended as a tap on a tower, or as nothing.
3. **Classification is spatial and sticky.** A press's slop is `tap_slop` when it has a real tap winner or no winner at all, and `drag_slop` otherwise (a drag winner with no tap winner, or only a sink). This stops a thumb roll on a tower moving a hero parked on it, which would be a mis-fire in the normal layout; a re-pin shorter than `tap_slop` is meaningless anyway, while the burst and a clear hero still commit early. The gesture is a **tap** if the pointer releases before ever moving the press's slop from the press point and the release still lies inside `best_tap`'s frozen disc, which gives the standard slide-off-to-abort; a **drag** from the first `move` at or beyond the press's slop when `best_drag` exists; and dead from that move when it does not. The resolver has no tap duration limit and no long press: a press held for ten seconds and released in place is a tap, which is the accessibility floor; an owner may apply its own hold limit to what it does with a tap, the resolver never will. Once a press is a drag it stays one; wobbling back to the origin never turns it into a tap. A release whose position is already at or beyond the press's slop (move events lost or coalesced) is treated as a final move first: with a drag winner it emits `drag_started` then `drag_ended` in one call, otherwise the gesture is dead. It is never a tap, because a flick across a tower whose moves were dropped would otherwise be the second tap of an upgrade.
4. **A gesture reaches only its class winner, or nothing.** A tap goes to `best_tap`; a drag goes to `best_drag`. If the class has no winner the gesture reaches no target, and there is no fall-through to the other class or to a lower-priority target (a press with no winner at all still produces `ground_tap`, Rule 5). A drag from a slot or tower alone is therefore structurally not a pin, while a drag from a hero standing on a slot is, and a tap over the hero alone reaches no tap target. This is the rule that makes the concept's zero-mis-fire target provable rather than hoped for: a gesture can only ever fire the target that was on top, in its own class, at press.
5. **Taps.** On release while still under slop: `tap(best_tap, p)` if `best_tap` exists and `p` is inside its frozen disc; nothing if the finger rolled off it; `ground_tap(p)` if neither winner exists; nothing if only `best_drag` exists (the leash was already shown on press). Ground taps are emitted every time; the HUD decides how often to draw its rejection ring.
6. **Drags.** The first move at or past slop emits `drag_started(best_drag, press_pos, p)`; every subsequent `move` emits `drag_moved(best_drag, press_pos, p)`, one per input call and never per frame, and the owner caches the latest position for drawing; release emits `drag_ended(best_drag, press_pos, release_pos)`. The resolver passes finger positions only. The burst's offset reticle is Hero System's: one function there turns the finger position into the aim point, and both the HUD's reticle and the burst's detonation call it, so the ring drawn and the point hit cannot disagree.
7. **Cancel is host-driven only.** The resolver has no cancel gesture; owners receive gestures, never cancels they could request. Dragging back to the origin already has a meaning, which belongs to the owner: Hero treats a drag released on the burst button as cancelling the aim, and releasing the hero where it stands as re-pinning in place. The resolver just reports the release. `cancel()` has three callers (ADR-0001, ADR-0003): the adapter, on app pause, focus loss, viewport resize and the Android back request; Flow, through its injected `cancel_input()`, on entering Won, Lost, Paused or Fatal; and the app root, at teardown for a retry or a fatal. A cancel by Flow or the app root leaves the adapter's own record of forwarded presses alone, so the stale release reaches the resolver in Idle and is dropped there. An OS touch-cancel arrives as `cancel_pointer(i)` and acts as `cancel()` only for the active pointer (Rule 1). In Dragging, cancel emits `drag_cancelled(best_drag)` and the owner reverts to its pre-drag state (the hero keeps its old pin, the burst does not fire); in Pressed or Dead it emits no gesture signal, only the `idle()` every return to Idle carries. A release is never synthesised from a cancel: a pin completed by an incoming call would be a mis-fire.
8. **The cost-chip window is not the resolver's.** Tower System owns the 1.5 s second-tap window and hears `tap(tower)` twice. Tower must ignore a commit tap for 200 ms (hard) after the chip opens, so a bounce cannot upgrade by accident. The resolver's whole contribution to "zero accidental upgrades" is Rules 1, 3, 4 and 7: a tap is emitted only on release of the active pointer, under slop, never after a drag began, never from a second finger, never on cancel, and never to a target that was not the tap winner at press.
9. **Three data fields.** `drag_slop`, `tap_slop` and `edge_reject_margin` are the fields of one Input record in the Data & Config catalogue, read directly rather than through the stat accessor, since no modifier targets them. The resolver takes the two slops by injection; the adapter applies `edge_reject_margin`. Hit radii are the owners' values from their own records, and priorities are structural constants, not tuned. `validate(drag_slop, tap_slop)` is a static function returning false unless both are finite, `drag_slop` is inside 8–30, `tap_slop` inside 16–34 and `tap_slop` above `drag_slop`. A static factory `create(drag_slop, tap_slop)` returns null when `validate` is false, because a GDScript constructor cannot refuse and an `assert` is stripped from exports and cannot be observed by a test. The cross-field rule has two guards (ADR-0002): the CI content test fails a catalogue whose Input record has `tap_slop` ≤ `drag_slop`, and on a device the Builder sends a null resolver from `create` to the fatal screen. `register` returns `NONE` with `push_error` unless `radius` is finite and above 0 and `centre` is finite: NaN would pass a "radius ≤ 0" check and make a dead disc, and infinity would swallow every press. Every call with a non-finite position is dropped with `push_error`, and `set_centre` with a non-finite position keeps the old centre. A registry call naming an unknown id is a no-op with a debug error.
10. **Idle ignores movement.** Mouse hover and touch moves with no press are dropped in Idle. Non-left mouse buttons never reach the resolver (adapter).
11. **Bots use the commands behind the door.** The resolver is built only by the wrapper, so headless bots call Hero's and Tower's commands directly. One test keeps the original intent: a script through the resolver and the same script through direct commands give identical state (Hero System).
12. **Rejected zones are the adapter's.** A press inside `edge_reject_margin` of a side edge, or inside the platform's safe-area or gesture insets, never reaches the resolver, even if it then drags onto a target. A drag that started elsewhere and moves into these zones stays valid. Insets are zero on desktop, and on a phone they are read once per battle. Gesture insets have no engine source at MVP: the pinned reference has no API for them, so `edge_reject_margin` stands in for them, and the Mobile Platform GDD owns the rest (ADR-0003). Hero must not let a pin land in these zones or under the burst button, or the hero becomes undraggable there: it clamps a person's drag and refuses a bot's; the burst button's centre sits at least `edge_reject_margin` + 48 units from a side edge.
13. **Gesture log.** In development builds a test harness listening to the signals logs each gesture. The harness belongs to the test harness story, not to the resolver, so the resolver still names no feature system. It logs: device and insets, down and up position and time (hold duration), maximum travel, press offset from the prompted target's centre, both winners and the rule that chose them, classification, emitted signal, and the `expected_action` and `expected_target` it prompted. It also listens to Tower's `tower_upgraded` and reads `chip_state()` at each tower prompt, so it logs every upgrade commit and whether a chip was open, and Tower needs no log of its own. The phone test computes misses and mis-fires from this. A miss is an expected action with no signal; a mis-fire is a signal for a different action (exact definitions in the Pillar 4 gate under Acceptance Criteria). The resolver itself stays clock-free.

**Not owned.** What a tap or drag means (pin, burst, aim cancel, build, upgrade, arc), the cost-chip window, the reticle offset, hit radii, the rejection-ring count and timings, the burst button's placement and left-hand mirror (the button registers wherever the HUD puts it; the resolver has no handedness), safe-area insets, and the mapping of engine events to the five calls (ADR).

**Deliberately not built for MVP.** Rectangular targets, long press, a resolver-level cancel gesture, display-density handling, a polled drag position, per-frame drag signals, two-touch gestures, a tap duration limit, a runtime slop setter and a hit-area scale multiplier (both reserved in prose for Settings & Accessibility at Alpha: the first changes a constructor argument into a setter, the second multiplies `radius` in the hit test; neither changes a signal).

→ Becomes an ADR: the adapter node and which Godot path feeds it (presses may take `_unhandled_input`, but moves and releases of the active index must be read where a `mouse_filter = STOP` Control cannot swallow them mid-drag, or the adapter must synthesise the matching `cancel_pointer`); the adapter runs with `PROCESS_MODE_ALWAYS` so a pause menu cannot strand a gesture; the adapter, not Game State stories, owns the lifecycle notifications that call `cancel()` and the `size_changed` hook; a mouse pointer index that cannot collide with touch index 0; `InputEventScreenTouch`/`ScreenDrag` field names and the `canceled` flag; the mouse-from-touch and touch-from-mouse emulation settings (one event family only, or every press arrives twice); whether event positions are already in the stretched 540×960 space (field units are viewport space only with no Camera2D; a `keep` stretch delivers letterbox positions outside the field), which stretch mode applies (the root `project.godot` has none yet) and that `DisplayServer.get_display_safe_area()` returns window pixels; which lifecycle notifications fire on each platform; that Controls with `mouse_filter = STOP` consume events before the adapter sees them. **None of these is in the pinned engine reference (`modules/input.md` does not cover touch), so the ADR verifies each against live 4.7 docs before relying on it.** ADR-0003 (Accepted) answers each point, and its S0 spike checks them on 4.7.2 before the first input story.

### States and Transitions

| State | Meaning |
|---|---|
| Idle | No active pointer |
| Pressed | Active pointer down, under the press's slop; `best_tap`, `best_drag`, `press_pos` held |
| Dragging | Past slop with a drag winner; `best_drag` receiving moves |
| Dead | Past the press's slop with no drag winner; active pointer ignored until it lifts, unless it had no real tap winner (none, or only a sink), in which case another press replaces it |

| From | Call | Guard | To | Emits |
|---|---|---|---|---|
| Idle | `press(i, p)` | — | Pressed | `pressed(best_tap, best_drag, p)` |
| Pressed with no real tap winner; or Dead with no real tap winner | `press(other, p)` | — | as `cancel()` then `press`; `other` becomes active | per those rows; no `ground_tap` |
| Idle | `move` / `release` | — | Idle | — |
| Pressed | `move(i, p)` | distance from `press_pos` < the press's slop | Pressed | — |
| Pressed | `move(i, p)` | ≥ the press's slop and `best_drag` exists | Dragging | `drag_started(best_drag, press_pos, p)` only; the first `drag_moved` is the next move |
| Pressed | `move(i, p)` | ≥ the press's slop and no `best_drag` | Dead | — |
| Pressed | `release(i, p)` | under slop, `best_tap` exists, `p` inside its frozen disc | Idle | `tap(best_tap, p)` |
| Pressed | `release(i, p)` | under slop, `best_tap` exists, `p` outside its disc | Idle | — |
| Pressed | `release(i, p)` | under slop, no winner at all | Idle | `ground_tap(p)` |
| Pressed | `release(i, p)` | under slop, only `best_drag` | Idle | — |
| Pressed | `release(i, p)` | ≥ the press's slop and `best_drag` exists | Idle | `drag_started` then `drag_ended(best_drag, press_pos, p)` |
| Pressed | `release(i, p)` | ≥ the press's slop and no `best_drag` | Idle | — |
| Dragging | `move(i, p)` | — | Dragging | `drag_moved(best_drag, press_pos, p)` |
| Dragging | `release(i, p)` | — | Idle | `drag_ended(best_drag, press_pos, p)` |
| Dead | `move` | — | Dead | — |
| Dead | `release(i, p)` | — | Idle | — |
| Dragging | `cancel()` | — | Idle | `drag_cancelled(best_drag)` |
| Pressed, Dead | `cancel()` | — | Idle | — |
| Idle | `cancel()` | — | Idle | — |
| any | `cancel_pointer(active)` | — | as `cancel()` | per those rows |
| any | `cancel_pointer(other)` | — | unchanged | — |
| Pressed, Dragging, Dead | `press(active, p)` | — | as `cancel()` then `press` | per those rows |
| any other case | call with pointer ≠ active | — | unchanged | — |

Every row that leaves Pressed, Dragging or Dead for Idle also emits `idle()` after the signal shown, cancel included; the Idle→Idle rows emit nothing. **Every row transitions before it emits, and gesture calls are queued.** The state and the frozen winners are committed before any owner hears about them. Each of the five gesture calls produces a batch of signals, including its `idle()`. A gesture call made from inside a handler joins a queue; the outermost call drains that queue synchronously, one call at a time, each only after the whole previous batch has been delivered to every listener. A cancel-then-press row emits its cancel signals with arguments captured before the new press commits. An owner connected later therefore never hears `idle()` before the `pressed` that caused it, and a nested `press` from a `tap` handler starts after that gesture's `idle()`.

Registration calls (`register`, `unregister`, `set_centre`, `set_enabled`) are legal in every state, including inside a handler, and are never deferred: `register` returns its id at once, because the HUD registers arc discs inside `tap(slot)`, and they cannot alter a gesture whose winners and discs are already frozen. A target moved, unregistered or disabled mid-gesture keeps receiving that gesture's remaining signals, and the release tests its frozen disc; an owner that unregisters mid-drag is expected to ignore them.

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Game State & Stage Flow | builds and injects | Constructs the resolver with the Input record, constructs the adapter node, hands the resolver to every owner; the adapter itself owns the lifecycle and OS-cancel wiring (`cancel()`, `cancel_pointer`), and forwards one lifecycle signal so Game State can enter Paused; resolver and adapter are rebuilt per battle | Game State (composition); this system (API and adapter contract) |
| Data & Config Pipeline | reads | One Input record (`drag_slop`, `tap_slop`, `edge_reject_margin`), added under the extension rule with its domain rows and validator | Data & Config (catalogue); this system (field) |
| Hero System | registers, listens | Its wrapper-built HeroInput registers hero (DRAG 200), burst button (DRAG 100) and its sink (TAP 400); updates the hero's centre each frame while walking; listens to `pressed` for the leash and `drag_*` for pin and burst; owns the finger-to-aim-point offset function. Burst meaning: drag-only; a drag released while cancelling cancels (Hero's zone has hysteresis: it stops over 64 from the button and resumes at 48), a drag released otherwise fires there, and a press released in place does nothing. The button and its sink stay enabled while cooling and Hero ignores them, so a touch there fires nothing and, because the sink outranks every tap target, reaches no tap target beneath, while a press also inside the hero's disc drags the hero, which outranks the button (Hero Rule 15, user decision 2026-11-02); Hero samples cooling at `pressed`, so a press stays dead even if cooling ends during it | Hero System |
| Tower System | registers, listens | Its wrapper-built TowerInput registers towers and slots (both TAP 200); disables a slot once built; listens to `tap` for the chip and the second-tap commit, to `pressed` to close an open chip | Tower System |
| Battle HUD & Build UI | registers, listens | Registers build-arc discs (TAP 300) and one arc backdrop (TAP 250 sink, covering the field) while an arc is open, so a press outside the discs only dismisses; listens to `pressed` to close the arc unless `best_tap` is one of its discs, since closing would otherwise unregister the disc before its `tap` builds; ignores `tap(backdrop)`; listens to `ground_tap` for the rejection ring and counts the first few per session itself; its top-band Controls consume their own events before the adapter | Battle HUD |
| Settings & Accessibility (Alpha) | will call | Runtime slop setter and hit-area scale, reserved in prose only | Settings GDD adds them |
| Bot acceptance modes | none | Call Hero's and Tower's commands; one equivalence test passes through the resolver | Hero System stories |

Nothing flows out of this system except its signals, and nothing flows in except the five calls, registrations and the one data record.

## Formulas

These are invariants of the resolver, not balance; the tunable values in them are `drag_slop` and `tap_slop`. Radii are hit radii, half the diameters in `design/art/art-bible.md` §3.

The **inside** formula is defined as:

`inside(c, r, p) = (p.x − c.x)² + (p.y − c.y)² ≤ r²`

and a target is a **candidate** at press when `enabled AND inside(c, r, p)`. A tap's release test is `inside` against the disc frozen at press, with no `enabled` term, so a target moved or disabled during the press still has a defined disc.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `p` | Vector2, field units | inside the field | calculated | Press position |
| `c` | Vector2, field units | inside the field | registered by owner | Target centre |
| `r` | float, field units | 36–48 at MVP | registered by owner | Target hit radius |
| `enabled` | bool | true or false | set by owner | Target participates in hit tests |

**Output Range:** true or false, inclusive of the boundary. With at most about 15 MVP discs the cost is irrelevant, and squared distances keep the boundary exact for the integer positions tests use (adapter-converted positions are fractional and sit on no boundary). Non-finite inputs never reach it (Rule 9).
**Example:** tower at (270, 480), r 36. Press at (300, 500): 900 + 400 = 1300 ≤ 1296 is false, a miss. Press at (299, 500): 841 + 400 = 1241 ≤ 1296, a hit.

The **is_drag** formula is defined as:

`press_slop = tap_slop if best_tap is a real tap winner or the press has no winner, else drag_slop`

`crossed = (p.x − p₀.x)² + (p.y − p₀.y)² ≥ press_slop²`

`is_drag = crossed AND best_drag ≠ NONE`

and **is_dead** as `crossed AND best_drag = NONE`. A tap additionally requires `inside(frozen c, frozen r, p_release)`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `drag_slop` | float, field units | invariant 8–30, balance 12–18, default 15 | data file (Input record) | Slop of a press with a drag winner and no real tap winner: a clear hero, or the burst button. The floor of 8 (5.3 dp at 360 dp) is below Android's own touch slop and is a validation limit, not a value to ship; see Open Questions |
| `tap_slop` | float, field units | invariant 16–34 and above `drag_slop`, balance 24–30, default 28 | data file (Input record) | Slop of a press with a real tap winner or no winner at all; kept below the smallest hit radius of 36 so a centred press cannot leave its target and still tap, and well above `drag_slop` so a thumb roll on a tower is a tap, not a silent miss |
| `p₀` | Vector2, field units | inside the field | calculated | Press position |
| `p` | Vector2, field units | inside the field | calculated | Current position |

**Output Range:** true or false, inclusive, latching for the gesture. Tested on every move, so a frame hitch cannot skip it. Both ends of the balance range are first-build hypotheses: no phone data exists (CD-PLAYTEST).
**Example:** press (100, 100) on a clear hero. Move (114, 100): 196 < 225, still Pressed. Move (115, 100): 225 ≥ 225, Dragging. An 18-unit roll on a tower, with or without a hero parked on it: 324 < 784 (`tap_slop` 28), still a tap if the release is inside the disc. A 28-unit move on that tower with a hero parked on it is a re-pin; with no hero it is dead, a miss and never a mis-fire.

The **field_scale** formula is defined as:

`field_scale = min(width_dp / 540, height_dp / 960)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `width_dp` | float | 360–800 | calculated | Device width in dp |
| `height_dp` | float | at least 640 | calculated | Device height in dp |
| `field_scale` | float | 0.667–1.481 | calculated | dp per field unit |

**Output Range:** 0.667 at the minimum supported screen, 360 dp wide or 640 dp tall. Below 360 dp wide or 640 dp tall is unsupported. The top value of 1.481 holds when the screen is 800 dp wide and at least 1,422 dp tall; a squatter screen is height-limited and scales lower. ADR-0003's `keep` stretch scales the field by the smaller term and letterboxes the rest, so a tall phone gets bars at top and bottom and a squat screen or tablet gets bars at the sides.
**Example:** 360 / 540 = 0.667. A 360 × 800 dp phone: min(0.667, 0.833) = 0.667, width-limited. An 800 × 1,280 dp tablet: min(1.481, 1.333) = 1.333, height-limited.

The **target_ok** formula is defined as:

`target_ok = 2 × r × field_scale ≥ 48`, evaluated without division as `2 × r × width_dp ≥ 25920` (48 × 540) **and** `2 × r × height_dp ≥ 46080` (48 × 960), with `r`, `width_dp` and `height_dp` floored to integers first, so the exact boundaries at 360 dp wide and 640 dp tall do not depend on float rounding

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `r` | float, field units | 36–48 at MVP | registered by owner | Target hit radius |
| `field_scale` | float | 0.667–1.481 | calculated | From field_scale |
| `width_dp`, `height_dp` | int after floor | at least 360 and 640 | calculated | Device size in dp, as in field_scale |

**Output Range:** true at every supported screen for a radius of at least 36.
**Example:** 2 × 36 × 0.667 = 48.0, passes. At 320 dp wide it would be 42.7 and fail, which is why 360 dp is the minimum width. Height: 2 × 36 × 640 = 46,080, passes at the boundary; a 360 × 600 dp screen gives 2 × 36 × 600 = 43,200 and fails, which is why 640 dp is the minimum height.

The table below assumes a width-limited phone (height at least 960/540 of the width); a height-limited screen scales by `height_dp / 960` instead.

| Width (dp) | 72-unit target | 96-unit target | `drag_slop` 15 | `tap_slop` 28 | `edge_reject_margin` 36 |
|---|---|---|---|---|---|
| 360 | 48.0 dp | 64.0 dp | 10.0 dp | 18.7 dp | 24.0 dp |
| 430 | 57.3 dp | 76.4 dp | 11.9 dp | 22.3 dp | 28.7 dp |
| 800 | 106.7 dp | 142.2 dp | 22.2 dp | 41.5 dp | 53.3 dp |

**Tie-break within a class:** higher `priority`, then smaller squared distance to centre, then lower `id`.

**Input record domains.** `drag_slop` default 15, hard domain 8–30. `tap_slop` default 28, hard domain 16–34; the cross-field rule `tap_slop > drag_slop` is the resolver's `validate()`, not the catalogue's per-field validator; the CI content test also checks it, and a null resolver goes to the fatal screen (Rule 9, ADR-0002). `edge_reject_margin` default 36, hard domain 0–48; its value comes from memory of Android's back-swipe zone and must be checked on devices.

## Edge Cases

"Dead" means the gesture emits nothing more than its `idle()` and the active pointer is ignored until it lifts. Cases the rules already settle (slop exactly equal is a drag; a press exactly on a disc edge hits; hero over slot taps the slot and drags the hero; a disabled target is simply absent; a drag from a hero on a slot pins) are not repeated.

**State machine**
- **If `cancel()` is called while Idle**: no-op, empty log. The adapter may call it unconditionally on pause.
- **If `cancel_pointer(i)` names a pointer other than the active one**: dropped; a cancelled palm never ends a live aim. Naming the active pointer is `cancel()`.
- **If a release arrives in Pressed at or beyond slop (moves lost or coalesced)**: `drag_started` then `drag_ended` in one call when a drag winner exists; otherwise nothing. Never a tap (Rule 3).
- **If the active pointer presses again without a release**: `cancel()` then the new press; Dragging emits `drag_cancelled` first (Rule 1).
- **If the finger lifts in place over the hero alone**: nothing but `idle()`; the hero hides its leash on `idle()`, not on a tap it never receives.
- **If an owner registers, unregisters, disables or moves a target inside a handler**: it takes effect at once, and `register` returns its id, but the gesture in flight is unaffected because its winners and discs are frozen.
- **If an owner calls `cancel()` or `press` inside a handler**: the call joins the queue and runs after the current batch reaches every listener, its `idle()` included. A queued `cancel()` from a `pressed` handler means every listener hears `pressed` then `idle`, and the eventual release is dropped in Idle. A `press` from a `tap` handler (a resolver fixture) starts after that gesture's `idle()`.
- **If a target is moved, unregistered or disabled mid-gesture**: it still receives that gesture's remaining signals under its old id, and a release is tested against its frozen disc; the owner ignores what it no longer wants. Ids are never reused, so a stale id cannot alias a new target.
- **If a target is registered mid-gesture under the finger**: it receives nothing from the current gesture, even if it is the only disc under the release point. The arc discs the HUD registers in response to a slot tap compete from the next press.
- **If `cancel()` ran and the OS later delivers the same pointer's move or release**: dropped in Idle; the finger must lift and press again. Focus-return on Android does exactly this.
- **If a second finger is down when the active one lifts and then moves**: dropped; a finger becomes active only by producing a press edge. A two-finger handover cannot continue a drag.
- **If a drag winner is disabled mid-drag**: `drag_moved` and `drag_ended` continue to that id; the owner decides whether to honour the release. `enabled` is tested only at press.
- **If a scripted test issues two gestures without the first's release**: identical to the lost-release case. Only resolver fixtures and the equivalence test drive the resolver; headless bots call the commands and never reach this (Rule 11).
- **If a pause lands in Pressed and the finger then moves past slop and lifts**: nothing fires. A pause during a tap is a miss, never a late action on resume.
- **If the finger rolls off a tap winner's frozen disc while still under the press's slop (a press near a tower's edge)**: release emits nothing, which is the slide-off-to-abort. A miss, never a mis-fire.
- **If a release or cancel for the active pointer never arrives (swallowed by a Control, dropped by the OS)**: the resolver cannot recover it, having no clock; the adapter contract (Dependencies) forbids it, and the next press of the same index recovers (Rule 1).

**Formulas and construction**
- **If `drag_slop` is outside 8–30, `tap_slop` outside 16–34, `tap_slop` ≤ `drag_slop` or either is non-finite**: the Data & Config validator rejects out-of-domain values at load; `validate()` returns false for all of them and `create` returns null, the second line for hand-built fixtures.
- **If a position is NaN or infinite**: the call is dropped with `push_error` and the state is unchanged; NaN would otherwise hold a press under slop forever and emit a `tap` at nowhere.
- **If the width is below 360 dp or the height below 640 dp**: unsupported, because targets would fall under 48 dp. A runtime guard, run once at battle build on mobile, reports it to the dev-error sink and never blocks play (ADR-0003); the store listing's device filter excludes such screens; a Godot export preset cannot filter by size.
- **If `radius` is 0, negative or non-finite, or `centre` is non-finite, at `register`**: returns `NONE` with `push_error` and registers nothing. No MVP radius is below 36, so this guards fixtures only.
- **If `set_centre` gets a non-finite position**: `push_error`, and the old centre stays.
- **If a move arrives at exactly `press_pos`**: distance 0 is below any legal slop; stays Pressed.
- **If a press lands outside the field (mouse off-window, or a disc straddling an edge)**: the adapter drops every press outside the 540 × 960 field before the resolver sees it (ADR-0003), so a disc straddling an edge is hit only from its on-field half. The resolver's hit test itself is unmodified, so a fixture that calls `press` off-field still gets the plain rules: a disc hit, or `ground_tap` with that position.
- **If a drag ends outside the field**: `drag_ended` carries the unclamped position; the owner clamps the pin or aim into the field. Touch hardware usually reports this as an OS cancel instead.
- **If two targets of one class share priority and centre**: the earlier id wins. A double-registered target is an owner bug the resolver does not deduplicate.
- **If a TAP and a DRAG target share a priority number**: no interaction; priorities compare only within a class.
- **If the viewport is resized or re-stretched mid-gesture**: `press_pos` is not rescaled; the adapter calls `cancel()` on resize, with no pause (ADR-0003).

**Overlaps and owner-facing outcomes**
- **If a press hits nothing**: `pressed(none, none, p)` still fires, so open chips and arcs close on the press; release under slop emits `ground_tap(p)`; a move past slop makes it dead.
- **If a press lands on the burst button while cooling**: `pressed(sink, button, p)`; Hero ignores both, so nothing fires and nothing beneath is reached.
- **If cooling ends during that press**: it stays dead until a new press, because Hero samples cooling at `pressed`.
- **If the burst button is pressed while an arc is open**: `pressed(sink, button, p)` closes the arc; a release in place is `tap(sink)`, which Hero ignores; a drag aims the burst.
- **If a second press arrives while an unmoved or Dead press with no real tap winner is down (a palm on the hero, the burst button, the arc backdrop or the ground, then the thumb)**: the second press becomes active, the first emits only `idle()`, and any leash shown for it hides on that `idle()`. A palm on a real tap target still holds until it lifts, and the same rule means a second touch can replace an unmoved hero or burst press; the phone test watches for both (Rule 1, Open Questions).
- **If a press lands inside a rejected zone**: the resolver never hears it, even if it drags onto a target (Rule 12).
- **If the ready burst button is pressed and released in place**: `pressed(sink, button, p)`, `tap(sink)`, `idle()`; nothing fires, because Hero ignores the sink. A resting thumb lifted off the button can never spend the cooldown.
- **If a drag from the ready burst button slips within the button and releases there**: `drag_ended` on the button; Hero cancels. A miss, never a mis-fire.
- **If a tap winner lies inside a drag winner and the finger lifts in place (tower over hero)**: `tap(tower)` then `idle()`; the hero drops its leash on `idle()`. A hero on a slot never blocks building; a tower never blocks a re-pin.
- **If the hero is pressed over a tower and the finger drags**: `drag_started(hero)`; the tower that kept its chip open on `pressed(tower, hero, p)` sees no `tap`, and its 1.5 s window counts taps only, so the drag can never commit an upgrade.
- **If an arc is open and the press lands on a tower or another slot outside the discs**: the backdrop outranks tower and slot, so `pressed(backdrop, …, p)` closes the arc and the release is `tap(backdrop)`, which the HUD ignores: the press only dismisses. Acting on the thing beneath would open a different arc or chip than the one 10 dp away that the thumb meant, which is a mis-fire; zero mis-fires outranks one saved tap.
- **If an arc is open and the press lands on ground**: `pressed(backdrop, NONE, p)` closes the arc; the release is `tap(backdrop)`, never `ground_tap`, so the HUD draws no rejection ring for a dismissal.
- **If an arc disc overlaps the hero and the finger drags from it**: `pressed(arc_disc, hero, p)`; past `tap_slop` the drag goes to the hero and the disc never receives a tap. The HUD closes the arc on `drag_started` since the thumb has left the build decision.
- **If a press lands on a built slot with its tower on top**: the slot is disabled and not a candidate; the tower wins, which is the upgrade-chip path. If a tower is removed, Tower System re-enables the slot in the same change, or the press becomes a ground press.
- **If a pointer id is reused by the OS after a lift**: harmless; equality is tested only while a pointer is active.

## Dependencies

**Upstream (hard):** Data & Config Pipeline, for the Input record. It relies on the engine only through the adapter node, which the ADR specifies.

**Downstream (hard unless noted; none has a GDD yet, so every interface is provisional until that GDD confirms it):**

| System | Interface | Hard / soft |
|---|---|---|
| Game State & Stage Flow | Constructs and injects the resolver and the adapter; the adapter owns lifecycle and OS-cancel wiring; Flow calls `cancel()` through its injected `cancel_input()`, and the app root calls it at teardown (Rule 7) | Hard — nothing receives input without it |
| Hero System | Registers hero, burst button and its sink; listens to `pressed`, `drag_*`; owns the aim-point offset and what a burst drag means; refuses invalid pins. The Hero GDD adopts the DRAG radius of 56 and the cancel hysteresis, and keeps a pin offset of 0 until the phone test | Hard — pin and burst are this system's two drags |
| Tower System | Registers towers and slots as TAP targets; listens to `tap` and `pressed`; owns the cost-chip window and a hard (not proposed) bounce guard of at least 200 ms before a commit tap, or gives the chip its own TAP target. The Rule 13 gesture log (the test harness story's, not the resolver's) also listens to Tower's `tower_upgraded` and reads `chip_state()` | Hard — build and upgrade are its two taps |
| Battle HUD & Build UI | Registers arc discs and the arc backdrop while an arc is open, and closes the arc on `pressed` unless `best_tap` is one of its discs; listens to `pressed` and `ground_tap`, ignores `tap(backdrop)`; its Controls sit above the adapter | Hard for the build arc and rejection ring |
| Settings & Accessibility (Alpha) | Runtime slop setter, hit-area scale | Soft — reserved in prose, nothing built |
| Mobile Platform & Performance (VS) | Safe-area and gesture insets feed the adapter and the HUD's button placement, not the resolver | Soft |

Per the bidirectional rule, each of these GDDs must list this one when authored. The Data & Config GDD and the systems index already list this system.

**Adapter contract (binding on the ADR).** Every `press` the adapter forwards is followed by exactly one `release` of that index, one `cancel_pointer` of that index, or one `cancel()`, whatever Controls lie under the drag and whatever the OS does with the touch. The adapter checks an event's `canceled` flag before treating `pressed = false` as a release, since an Android touch-cancel treated as a release would emit `tap` or `drag_ended`, a mis-fire. The resolver has no clock and cannot recover a stranded gesture; a different finger pressing afterwards is dropped by Rule 1 until the stranded one is closed.

## Visual/Audio Requirements

This system draws nothing and plays nothing. Every visual that answers a gesture is owned elsewhere and triggered by this system's signals, so the mapping is recorded here once:

| Signal | Visual (owner) | Art bible |
|---|---|---|
| `pressed` with the hero as `best_drag` | Leash ring shown (Hero System) | §3 line styles: 2 px dashed, alpha 0.5; §7 two-tone over the path |
| `pressed` naming the ready burst button | Button press response, drawn on the first frame after `pressed` and extending beyond the fingertip (HUD) | §7 Burst button |
| `drag_started` and `drag_moved` from the burst button | Offset reticle about 67 dp above the finger, clamped, with no flip (Hero System computes, HUD draws) | §7 Reticle |
| Finger inside the burst button during an aim | Visible cancel state: reticle dimmed and radius preview hidden, so an aim that will cancel never looks live (Hero System decides from `drag_moved`, HUD draws) | §7 Reticle |
| `drag_moved` from the hero | Leash preview at the finger (Hero System) | §5 Pinned pose |
| `ground_tap` | Tiny unanimated dim ring, 150 ms fade-in, first three taps of a battle only, no sound (Battle HUD) | §7 Ground tap |
| `tap` on a tower | Cost chip for 1.5 s (Tower System / HUD) | §7 Build/upgrade affordance |
| `tap` on a slot | Build arc of three role discs above the slot (Battle HUD) | §7 |
| `drag_cancelled` | Leash preview and reticle removed; nothing fires (owners) | — |

Audio: none at MVP (concept: audio minimal). The ground tap is silent by design. Any later input sound is the owning system's event, not this system's.

## Game Feel

The resolver's feel targets are latency and predictability, both set here because they are architecture, not polish:

- **Press feedback on the press, not the release.** The leash appears on `pressed`, before the player has decided whether this is a tap or a drag, so the first frame of touching the hero already says "this is yours". The ready burst button answers its press too, since the reticle cannot appear until `drag_slop` is crossed, which is later than the mouse prototype. Everything else answers a classified gesture.
- **Classification within one move event.** The slop test runs on every `move`, so a drag is recognised on the first sample past the press's slop with no debounce, no timer and no frame of waiting. A pull that reaches slop in the same input event that leaves the disc still counts: the winners were fixed at press.
- **Few verbs, all taught.** There is no long press and no double tap. The hero has one verb, the pin. The burst button has two behaviours: drag to aim, drag back to cancel; a tap on it does nothing, because a resting thumb must never spend the cooldown. Because a tap does nothing, the Hero and HUD GDDs must give the button an MVP drag affordance and a pressed-but-not-dragged response. Onboarding Prompts (Vertical Slice) teaches them; until then the visible cancel state carries the second.
- **A miss is silent except on the ground.** A drag from a tower, a tap over the hero alone and a second-finger touch produce no feedback at all. Silence reads as "nothing happened", which is correct; a rejection cue on every miss would train the player to look at the field instead of the lane.
- **Sticky drag.** Once a drag, always a drag: a re-pin that wanders back over the hero never collapses into a tap, so a nervous thumb cannot cancel its own pin by hesitating.

The quantitative feel criterion is the concept's phone test (the Pillar 4 gate), not a frame budget: the resolver's per-event work is a handful of squared distances against at most about fifteen discs.

## UI Requirements

None owned. This system has no screen, panel or widget; it supplies gestures to the systems that do. Two constraints on UI that other systems must honour are recorded here because the resolver assumes them:

- The burst button is a registered disc owned by Hero System and placed by the HUD, not a Control, so it competes in this system's priority order rather than the engine's Control ordering; the HUD's top band ignores input, and its result and Paused screens are Controls that consume every event before the adapter sees them. There is no pause button at MVP.
- No build slot may sit so close to the burst button that their hit discs overlap at any supported safe-area inset: the button's priority would make part of that slot untappable. Owner: the Enemy & Wave GDD's layout rule L3, enforced by the content test on the Stage record's `slot_positions`.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Priority order, slop range, 48 dp targets, phone test (0 mis-fires, ≤5% misses) | `design/gdd/game-concept.md` | Pillar 4, Core Mechanic 2, MVP item 6 | Rule dependency |
| Registry-only scope; owners register themselves; Input never names a feature | `design/gdd/systems-index.md` | Foundation Layer TD note (item 2); High-Risk Systems row | Rule dependency |
| Hit radii 36 / 48 units; 1.5 units per dp at 360 dp | `design/art/art-bible.md` | §3 Minimum sizes | Value dependency |
| Reticle offset, ground-tap ring, cost chip, build arc, panel band | `design/art/art-bible.md` | §7 | Ownership handoff |
| Input record, added under the extension rule by this GDD | `design/gdd/data-config-pipeline.md` | Extension rule; Interactions (Input row); Dependencies | Rule dependency |
| Injection by the composition root | `design/gdd/data-config-pipeline.md` | Rule 12 | Pattern reuse |
| Gesture log reads `tower_upgraded` and `chip_state()` (test harness story) | `design/gdd/tower-system.md` | Rule 17 | Rule dependency |
| `cancel()` callers, Builder null-resolver fatal | `docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md` | Decision 5 to 7 | Rule dependency |
| Content test slop rule | `docs/architecture/adr-0002-catalogue-storage-format-manifest-validation.md` | Decision 7 | Rule dependency |
| Adapter, stretch, `field_scale`, rejected zones, lifecycle | `docs/architecture/adr-0003-input-adapter-display-stretch-platform-lifecycle.md` | Decisions 1 to 3 | Rule dependency |
| Press priority as prototyped; mouse-only evidence | `prototypes/hero-pin-concept/main.gd`, `REPORT.md` | `_press`/`_release`; Pillar 4 untested on a phone | Evidence |

## Acceptance Criteria

A recording fake connects to every signal and appends `name(args)` to one Array; each THEN is the entire log in order, and anything unlisted fails. Arguments are compared only where written; `NONE` is −1. Fixtures are factory functions in field units, and a criterion registers only the targets it names: tower `T` centre (270, 480) r 36 TAP 200; slot `S` (270, 600) r 36 TAP 200; hero `H` (100, 100) r 36 DRAG 200 unless placed; burst button `B` (440, 880) r 48 DRAG 100 with sink `Z` (440, 880) r 48 TAP 400 sink; arc disc `A` (270, 540) r 36 TAP 300; arc backdrop `K` (270, 480) r 1200 TAP 250 sink. Presses are at the named target's centre unless stated, empty ground is (500, 100), pointer 0 unless stated, `drag_slop` 15 and `tap_slop` 28 unless stated; "move n" means n units along +x from the press point. No engine input events, no scene, no random seeds, no time assertions. Tests live in `tests/unit/input_gesture_resolver/`, the fake and factories in `tests/unit/input_gesture_resolver/helpers/`; the fake records signals into an Array rather than using gdUnit4 `assert_signal`, which awaits and is timing-dependent.

**CI: Logic**
1. (Rule 1, second pointer) **GIVEN** pointer 0 pressed on `T`, **WHEN** pointer 1 presses on `S` and releases, pointer 0 releases in place, then pointer 1 moves, **THEN** `pressed(T, NONE), tap(T), idle`.
2. (Rule 1, palm replaced while Pressed) **GIVEN** pointer 0 pressed on empty ground, **WHEN** pointer 1 presses on `T` and releases in place, **THEN** `pressed(NONE, NONE), idle, pressed(T, NONE), tap(T), idle`, and a later release of pointer 0 adds nothing.
3. (Rule 1, palm replaced while Dead) **GIVEN** pointer 0 pressed on empty ground and moved 30, **WHEN** pointer 1 presses on `T` and releases in place, **THEN** `pressed(NONE, NONE), idle, pressed(T, NONE), tap(T), idle`.
4. (Rule 1, a live gesture is not replaced) **GIVEN** pointer 0 pressed on `H` and moved 20, **WHEN** pointer 1 presses on `T` and releases, then pointer 0 releases, **THEN** `pressed(NONE, H), drag_started(H), drag_ended(H), idle`.
5. (Rule 1, lost release) **GIVEN** pointer 0 dragging `H`, **WHEN** pointer 0 presses again on `T`, **THEN** `pressed(NONE, H), drag_started(H), drag_cancelled(H), idle, pressed(T, NONE)`.
6. (Rule 2, frozen winners) **GIVEN** `H` centred on `S`, **WHEN** press, `set_centre(H, (0, 0))`, release in place, **THEN** `pressed(S, H), tap(S), idle`.
7. (Rule 3, sticky drag) **GIVEN** `H`, **WHEN** press, move 15, move back to the press point, release, **THEN** `pressed(NONE, H), drag_started(H), drag_moved(H), drag_ended(H), idle`.
8. (Rule 3, lost moves with a drag winner) **GIVEN** `H`, **WHEN** press and release 15 away with no move, **THEN** `pressed(NONE, H), drag_started(H), drag_ended(H), idle`.
9. (Rule 3, lost moves with a tap winner) **GIVEN** `T`, **WHEN** press and release 28 away with no move, **THEN** `pressed(T, NONE), idle`.
10. (Rule 3, tap slop) **GIVEN** `T` pressed at its centre, **WHEN** move 20 and release there, **THEN** `pressed(T, NONE), tap(T), idle`; **WHEN** instead move 28 and release, **THEN** `pressed(T, NONE), idle`.
11. (Rule 3, slop is per press) **GIVEN** `H` pressed at its centre, **WHEN** move 15 and release, **THEN** `pressed(NONE, H), drag_started(H), drag_ended(H), idle`; **GIVEN** `T` pressed at its centre, the same move 15 and release, **THEN** `pressed(T, NONE), tap(T), idle`.
12. (Rule 4, no fall-through) **GIVEN** `S` alone, **WHEN** press, move 28, move 30, release, **THEN** `pressed(S, NONE), idle`.
13. (Rule 5, release off the disc) **GIVEN** `T` pressed at (300, 480), **WHEN** moved to (310, 480) and released there, **THEN** `pressed(T, NONE), idle`.
14. (Rule 5, release in place) **GIVEN** `T`, empty ground and `H` alone in turn, **WHEN** pressed and released in place, **THEN** `pressed(T, NONE), tap(T), idle`; `pressed(NONE, NONE), ground_tap, idle`; `pressed(NONE, H), idle`.
15. (Rule 6) **GIVEN** `H` on `S`, **WHEN** press at p₀, move to p₁ 28 away, p₂, p₃, release at p₄, **THEN** `pressed(S, H, p₀), drag_started(H, p₀, p₁), drag_moved(H, p₀, p₂), drag_moved(H, p₀, p₃), drag_ended(H, p₀, p₄), idle` with the exact positions and no signal naming `S` after `pressed`.
16. (Rule 7, cancel per state) **GIVEN** Dragging `H`, **WHEN** `cancel()` then release, **THEN** `pressed(NONE, H), drag_started(H), drag_cancelled(H), idle`. **GIVEN** Pressed on `T`, **THEN** `pressed(T, NONE), idle`. **GIVEN** Dead (ground, moved 30), **THEN** `pressed(NONE, NONE), idle`. **GIVEN** Idle, **WHEN** `cancel()`, **THEN** an empty log.
17. (Rule 7, per-pointer cancel) **GIVEN** pointer 0 dragging `H`, **WHEN** `cancel_pointer(1)`, move, release, **THEN** `pressed(NONE, H), drag_started(H), drag_moved(H), drag_ended(H), idle`; **WHEN** instead `cancel_pointer(0)` then release, **THEN** `pressed(NONE, H), drag_started(H), drag_cancelled(H), idle`.
18. (Rule 8) **GIVEN** `T`, **WHEN** two press-and-release pairs in place, **THEN** `pressed(T, NONE), tap(T), idle, pressed(T, NONE), tap(T), idle`.
19. (Rule 9, validation) **GIVEN** `validate(8, 28)`, `validate(30, 34)` and `validate(15, 16)`, **THEN** true; **GIVEN** `validate(7, 28)`, `validate(31, 34)`, `validate(15, 15)`, `validate(15, 15.99)`, `validate(15, 35)` and `validate(NAN, 28)`, **THEN** false each time, and `create` returns null for each. **GIVEN** `register` with radius 0, −1, NAN or INF or a non-finite centre, **THEN** it returns `NONE` and a press at that position is `pressed(NONE, NONE)`.
20. (Rule 9, unknown id) **GIVEN** `T` registered, **WHEN** `set_centre`, `set_enabled` and `unregister` are called with an id never issued, then `T` is pressed and released, **THEN** `pressed(T, NONE), tap(T), idle`.
21. (Rule 9, non-finite) **GIVEN** `H`, **WHEN** `press` at (NAN, 100), **THEN** an empty log; **WHEN** `H` is pressed, moved to (INF, 100) and released in place, **THEN** `pressed(NONE, H), idle`; **WHEN** `set_centre(H, (NAN, 0))` then `H` is pressed at (100, 100), **THEN** `pressed(NONE, H)`.
22. (Rule 10) **GIVEN** Idle, **WHEN** move then release, **THEN** an empty log.
23. (Determinism and ids) **GIVEN** a fresh resolver, **WHEN** its first target registers, **THEN** its id is 1. **GIVEN** two fresh resolvers and the call lists of criteria 7 and 15, **WHEN** run, **THEN** identical logs.
24. (Registry, ids) **GIVEN** `T` registered then unregistered, **WHEN** a new target registers, **THEN** its id differs from `T`'s, and a press at `T`'s old centre is `pressed(NONE, NONE)`.
25. (Registry, enabled) **GIVEN** `S` disabled, **WHEN** pressed and released, **THEN** `pressed(NONE, NONE), ground_tap, idle`; re-enabled, `pressed(S, NONE), tap(S), idle`.
26. (Registry, mid-gesture) **GIVEN** `S` pressed, **WHEN** `set_enabled(S, false)` then release in place, **THEN** `pressed(S, NONE), tap(S), idle`. **GIVEN** `S` pressed, **WHEN** `set_centre(S, (0, 0))` then release in place, **THEN** `pressed(S, NONE), tap(S), idle` (frozen disc). **GIVEN** `H` dragging, **WHEN** `unregister(H)` then move and release, **THEN** the log continues `drag_moved(H), drag_ended(H), idle`. **GIVEN** `T` pressed, **WHEN** a new target registers under the finger, then release, **THEN** `pressed(T, NONE), tap(T), idle` and the new id appears nowhere.
27. (Re-entrancy) **GIVEN** two listeners connected in order, the first calling `cancel()` inside its `pressed` handler, **WHEN** `T` is pressed, **THEN** both listeners log `pressed(T, NONE), idle` in that order, and a later release adds nothing. **GIVEN** a listener calling `press` on `S` inside its `tap` handler, **WHEN** `T` is pressed and released, **THEN** `pressed(T, NONE), tap(T), idle, pressed(S, NONE)`. **GIVEN** a listener calling `register` inside its `tap` handler, **WHEN** `T` is tapped, **THEN** the call returns a valid id at once, the log is `pressed(T, NONE), tap(T), idle`, and the next press on that disc names it.
28. (Burst, drag-only and sink) **GIVEN** `B` and `Z` with `S` centred beneath them, **WHEN** pressed and released in place, **THEN** `pressed(Z, B), tap(Z), idle`; **WHEN** pressed, moved 15 and released, **THEN** `pressed(Z, B), drag_started(B), drag_ended(B), idle`; `S` is named nowhere, and the sink did not raise the slop. **GIVEN** `B`, `Z` and `H` at (440, 820), **WHEN** pressed at (440, 840), inside all three, moved 15 and released, **THEN** `pressed(Z, H), drag_started(H), drag_ended(H), idle`: the hero outranks the button.
29. (Arc) **GIVEN** `A`, `K` and `T` registered (arc open) with `H` centred on `T`, **WHEN** pressed on `A` at (270, 560) and released, **THEN** `pressed(A, NONE), tap(A), idle`; **WHEN** pressed on `T` at (270, 470) and released, **THEN** `pressed(K, H), tap(K), idle`; **WHEN** pressed on empty ground and released, **THEN** `pressed(K, NONE), tap(K), idle`; **WHEN** pressed at (270, 505) (inside `A` and `T`) and moved 28, **THEN** `pressed(A, H), drag_started(H)`.
30. (Formula: hit) **GIVEN** `T`, **WHEN** pressed and released in place at (306, 480), (307, 480), (299, 500) and (300, 500) in turn, **THEN** `pressed(T, NONE), tap(T), idle`; `pressed(NONE, NONE), ground_tap, idle`; `pressed(T, NONE), tap(T), idle`; `pressed(NONE, NONE), ground_tap, idle`.
31. (Formula: is_drag) **GIVEN** `H` at (100, 100) pressed at its centre, **WHEN** moved to (109, 111), **THEN** the log is `pressed(NONE, H)`; **WHEN** then moved to (109, 112), **THEN** `drag_started(H)` is appended (distances squared 202 and 225).
32. (Tie-break) **GIVEN** `A` and `T`, **WHEN** pressed at (270, 505) (25 from `T`, 35 from `A`), **THEN** `pressed(A, NONE)` by priority. **GIVEN** `T` and a second tower at (270, 530) registered before it, **WHEN** pressed at (270, 500) (20 from `T`, 30 from the other), **THEN** `pressed(T, NONE)` by distance. **GIVEN** `T` and a second tower at (270, 480) registered after it, **WHEN** pressed at (270, 480), **THEN** `pressed(T, NONE)` by lower id.
33. (Formula: target_ok) **GIVEN** radii 36 and 48 at 360 × 640 dp, **WHEN** `2 × r × 360 ≥ 48 × 540` and `2 × r × 640 ≥ 48 × 960` are evaluated in integers by the production function, **THEN** both pass and radius 35 fails. **GIVEN** radius 36 at 400 × 600 dp, **THEN** it fails on the height term alone.

34. (Rule 3, hero parked on a tower) **GIVEN** `H` centred on `T`, **WHEN** press, move 16, release, **THEN** `pressed(T, H), tap(T), idle`; **WHEN** instead press, move 28, release, **THEN** `pressed(T, H), drag_started(H), drag_ended(H), idle`. **GIVEN** `H` alone, **WHEN** press, move 15, release, **THEN** `pressed(NONE, H), drag_started(H), drag_ended(H), idle`.
35. (Rule 1, replacement) **GIVEN** pointer 0 pressed on `H` alone, unmoved, **WHEN** pointer 1 presses on `T` and releases, **THEN** `pressed(NONE, H), idle, pressed(T, NONE), tap(T), idle`. **GIVEN** pointer 0 pressed on `B` with `Z`, unmoved, the same second press gives `pressed(Z, B), idle, pressed(T, NONE), tap(T), idle`. **GIVEN** pointer 0 pressed on `T`, **WHEN** pointer 1 presses on `S` and releases, **THEN** only `pressed(T, NONE)`.
36. (Rule 1, Dead and active re-press) **GIVEN** `T` pressed and moved 28 (Dead), **WHEN** further moves and pointer 1 presses, **THEN** nothing is appended; **WHEN** pointer 0 presses again, **THEN** `idle, pressed(...)` is appended. **GIVEN** `T` pressed, **WHEN** `cancel_pointer(0)`, **THEN** `pressed(T, NONE), idle`.
37. (Rule 1, Dead sink-only press is replaceable) **GIVEN** `A` and `K` registered (arc open), pointer 0 pressed on empty ground (500, 100) and moved 20, **WHEN** pointer 1 presses on `A` at (270, 560) and releases in place, **THEN** `pressed(K, NONE), idle, pressed(A, NONE), tap(A), idle`.

**Pillar 4 milestone gate (not this system's Done).** The phone test needs Hero, Tower, the HUD and the adapter, so it gates the MVP+ exit, per the concept, rather than this document. Until it passes, Pillar 4 is unverified.

P1. **GIVEN** the Rule 13 gesture log, at least two non-developer testers (one left-handed if available), one phone of 360–400 dp width and one wider, Android gesture navigation on, **WHEN** each tester is prompted in a fixed scripted order for 20 attempts each of slot tap, arc disc tap, tower tap, Start/Call tap, pin drag and burst drag (the burst Ready before every burst prompt, a tower prompt never inside Tower's second-tap window, and the next prompt coming whether or not the attempt succeeded, so each attempt counts once), **THEN** for each gesture separately, pooled over testers and devices, misses are at most 5% and mis-fires are zero. One bad gesture cannot hide in an average.
- *Miss:* a prompted gesture with no signal for the prompted action before the next prompt, including a `ground_tap` on a prompted slot.
- *Mis-fire:* during a prompt, a signal for a different action or a different target than the one prompted, any burst not prompted, or any upgrade commit not prompted.
- *Unprompted segment:* five minutes of play under wave pressure, then the tester flags any action they did not intend. Prompts cannot classify free play, so voluntary bursts do not count; flagged actions are counted as mis-fires against the gate and reviewed against the log.
- *Evidence:* the raw logs and a per-gesture table saved to `production/qa/evidence/input-gesture-resolver/phone-test-[date]/`.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner | Passes when |
|---|---|---|
| Pin, aim and burst meaning, invalid pins, the equivalence test (Rule 11) | Hero stories | A drag released while cancelling cancels, otherwise fires there, a tap or cooling press does nothing; pins in rejected zones and under the button are clamped or refused; headless bots call the commands directly, and the same script through the resolver gives identical state |
| Chip window, hard bounce guard, upgrades | Tower stories | A second tap inside the bounce guard does not commit; one after it, inside the window, commits once |
| Arc close, backdrop, ground ring, press response, visible cancel state | Battle HUD stories | Tapping an arc disc builds; a press outside only dismisses with no ring; the press response appears on the next frame; retained screenshots in `production/qa/evidence/` |
| Injection of resolver and adapter | Game State stories | Every owner receives the one resolver, with no global |
| Adapter contract | Input ADR and first phone build | Every press ends in exactly one release or cancel across Controls; a `canceled` touch never emits `tap` or `drag_ended`; rejected zones drop presses; one physical press gives one gesture on mouse and touch |
| Gesture log contents (Rule 13) | Test harness story | Every Rule 13 field is present for each gesture, and the P1 table computes from it |

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Adapter: which Godot path feeds the five calls, and how moves and releases of the active index survive a `mouse_filter = STOP` Control mid-drag (the adapter contract in Dependencies); touch event field names and `canceled`; emulation settings (one event family only); whether positions arrive in the stretched 540×960 space and which stretch mode; lifecycle notifications for `cancel()`; Control `mouse_filter` ordering. None is in the pinned reference. **Answered by ADR-0003 (Accepted), pending its S0 spike on 4.7.2** | technical-director, `/architecture-decision` | Before the first input story (S0) |
| Do the 15-unit slop and the 36/48-unit radii hold on a phone with a non-developer tester? All evidence is one developer on a mouse (CD-PLAYTEST) | producer + Hero/Tower stories | First phone build (Pillar 4 test) |
| Does a palm resting on a real tap target lock input often enough to matter? It holds by design (Rule 1). The reverse also needs watching: a second touch replaces an unmoved hero or burst press and can then tap a tower | qa-lead | First phone build |
| Hero: pin at the finger position means the thumb covers the pin at release. If the phone test shows pin misses, does Hero route pins through its offset function too? | Hero GDD | First phone build |
| Hero: should re-pinning be instant or a short walk? If "walk", the hero needs path-following and the concept's "no pathfinding" claim is revisited (concept Open Questions). The resolver is unaffected either way | Hero GDD | Hero GDD |
| Settings & Accessibility: runtime slop setter ("steady hand" ×1.5) and hit-area scale; a two-tap alternative to dragging for players who cannot drag. Hooks are reserved in prose only; the owner API (target, press, release) already hides the physical gesture from owners | Settings & Accessibility GDD | Alpha |
| Should the Input record gain `tap_max_ms` or anything else? Current answer: no; the no-timeout rule is the accessibility floor. Revisit only with phone evidence | ux-designer | First phone build |
| Is the `drag_slop` floor of 8 (5.3 dp at 360 dp, below Android's 8 dp touch slop) worth keeping as a validation limit, or should the Data & Config domain floor rise to 12? Decided from measured phone data, not here | Data & Config GDD + first phone build | First phone build |
| Is the 36-unit edge margin right on real Android and iOS devices? From memory, not sourced | gameplay-programmer | First phone build |
| On a tablet `drag_slop` is 22 dp wide at 800 dp: acceptable, or do tablets need a scale cap? **Closed for MVP by ADR-0003:** `keep` scales a height-limited screen by height, so no scale cap at MVP | technical-director | Closed (ADR-0003) |
| Phone-test scope beyond P1 (five or more testers, iOS and Android, more widths) is a concept change; the test as written is the floor | producer | Before the first phone build |
