# ADR-0003: Input Adapter, Display Stretch and Platform Lifecycle

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Why this is stated here: stories referencing a `Proposed` ADR are set `Blocked`,
> and epics require `Accepted`, so the field needs a named owner.
> `technical-director` is the role `coordination-rules.md` already escalates
> technical conflicts to, and an ADR is that decision made durable.
>
> This does **not** relax the existing rule that `Status: Accepted` is never set
> without explicit user confirmation. It narrows *which agent* may set it once
> that confirmation exists. An agent that believes an ADR is ready says so and
> escalates; it does not edit this field.
>
> **This ADR is spike-first.** Do not accept it until spike items SP0 to SP12
> (Engine Compatibility) have recorded results in the results table of
> `prototypes/adr-0003-device-spike/README.md`, on desktop and on at least one
> Android phone, and the observed facts are copied into
> `docs/engine-reference/godot/modules/input.md` and `modules/ui.md` with the
> device, OS version and date. Where a result takes a fallback branch, this ADR
> is revised to that branch before acceptance.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only. The live Godot 4.7 documentation was not reachable from the authoring session, and no device was available, so every engine behaviour below that the pinned reference does not cover is marked NEEDS VERIFICATION and tied to a spike item.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode.

## Summary

The game needs one engine-facing input node that turns Godot touch and mouse events into the resolver's five calls in 540x960 field units, a display setup that keeps field units equal to viewport units on every phone, and one pause path that fires on focus loss and backgrounding on desktop, Android and iOS. This ADR decides an `InputAdapter` node that reads presses in `_unhandled_input` (so HUD Controls win the presses over them) and the moves and releases of its own forwarded presses in `_input` (so no Control can strand a gesture), one event family (touch, with touch emulated from the mouse on desktop), stretch `canvas_items` with aspect `keep` at 540x960 in portrait (taller phones letterbox), safe-area insets converted to field units on Android and iOS only, a 360 dp logging guard, and a pause on any of four lifecycle notifications, all as working defaults that a device spike (SP0 to SP12) must confirm.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Input (also UI and display, and app lifecycle) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (post-cutoff version; `modules/input.md` has no touch coverage; app lifecycle and safe area are unreferenced in the pinned docs) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md`, `modules/ui.md` |
| **Post-Cutoff APIs Used** | `InputEvent.DEVICE_ID_MOUSE` and `InputEvent.DEVICE_ID_KEYBOARD` (4.7, sourced: `breaking-changes.md` 4.6 to 4.7, Input row). The 4.7 change of stretch defaults for new projects (`display/window/stretch/mode` `canvas_items`, `aspect` `expand`; sourced, Project row), which is why this ADR sets both keys explicitly. The 4.6 dual-focus split (sourced, `modules/input.md`), which is why HUD Controls take no focus. Nothing else from 4.5 to 4.7 is used. |
| **Verification Required** | SP0 to SP12 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: the frame point at which input events are delivered; the order of `_input`, Control `_gui_input` and `_unhandled_input` for touch events; whether a `mouse_filter = STOP` Control takes the moves and release of a touch it did not see pressed; the `InputEventScreenTouch` and `InputEventScreenDrag` field names and the `canceled` flag; the emulation settings `input_devices/pointing/emulate_touch_from_mouse` and `emulate_mouse_from_touch` and the device IDs of emulated events; the coordinate space of event positions under `canvas_items`; the aspect value `keep` and its letterbox behaviour (only `expand` and the old default `keep` are named in the reference, not described); `display/window/handheld/orientation`; `application/config/quit_on_go_back`; `DisplayServer.get_display_safe_area()` units and space; `DisplayServer.screen_get_dpi()` and `screen_get_scale()` on phones; every lifecycle notification name, number, platform and delivery depth; `Viewport.size_changed` under `keep`. The godot-specialist check agrees with the expected results from pre-4.4 knowledge only; that is not a source. |

> **Note**: If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated if the
> project upgrades engine versions. Flag it as "Superseded" and write a new ADR.

### Spike items

Every item is answered by the kit in `prototypes/adr-0003-device-spike/` (a standalone Godot 4.7 project with this ADR's display and input settings). Method for all: run the kit, perform the actions in its README, read the log. Owner for all: the user runs the kit on the devices; godot-specialist reads the logs and records the results and the branch taken. Each item names the expected result (unsourced) and what this ADR does for each outcome.

- **SP0. Settings take effect.** The start-up report shows `canvas_items`, `keep`, portrait orientation, both emulation flags true and `quit_on_go_back` false as the running values, and the phone does not rotate. *If a key is ignored* (the running value differs from `project.godot`): find the 4.7 key name in the editor's Project Settings (Advanced) and correct Decision 4 before acceptance. Nothing else changes.
- **SP1. Event delivery against the frame.** Expected: on every platform, every input event is delivered after one frame's `_process` and before the next frame's `_physics_process` and `_process` (log tag `after=PROC` on every `IN` line; the status counter "after PHYS" stays 0 with `agile_event_flushing` off). *Branch A (expected)*: the adapter forwards each call at once (Decision 2). *Branch B (any event seen after a PHYS marker, or interleaved with physics steps)*: the adapter queues the five calls and `BattleWrapper._process` calls `adapter.flush()` as frame step 0, before the clock (ADR-0004 adds the step). Lifecycle cancels stay immediate in both branches.
- **SP2. A drag across a STOP Control.** Expected: a touch pressed on the free field and dragged onto the STOP band keeps reaching `_input` with every move and the release, whether or not `_unhandled_input` also sees them. *Branch A (expected)*: Decision 2 as written. *Branch B (`_input` misses the moves or release)*: while the adapter holds any forwarded press, the wrapper sets every non-modal HUD Control to `MOUSE_FILTER_IGNORE`, and restores them when the adapter emits `pointers_released()` (a signal added only in this branch). Modal screens are unaffected, because they mount after a `cancel()`.
- **SP3. A press on a STOP Control.** Expected: a touch pressed on the STOP band reaches the band's `_gui_input` as `InputEventScreenTouch` (and as an emulated mouse button), and no `UNH` line appears for that press. *Branch A (expected)*: HUD Controls read `InputEventScreenTouch` in `_gui_input` (Decision 8). *Branch B (the Control gets only the emulated mouse button, and `_unhandled_input` still does not see the touch)*: HUD Controls read the left `InputEventMouseButton`, and they also clear their press on `display_changed()` and on the adapter's per-pointer cancel (Decision 8 fallback). *Branch C (the touch press also reaches `_unhandled_input`)*: test the kit's Accept toggle; if `accept_event()` in the Control stops it, every HUD Control calls `accept_event()` on touch events; if not, the wrapper registers each HUD Control with `adapter.add_blocker(control)` and the adapter drops a touch press inside a visible blocker's global rect.
- **SP4. Touch fields and OS cancel.** Expected: `InputEventScreenTouch` carries `index`, `position`, `pressed` and `canceled`; `InputEventScreenDrag` carries `index` and `position`; an Android system gesture that takes over a touch (back swipe, notification shade, palm) delivers `pressed = false, canceled = true` for that index. *If `canceled` is absent*: read `InputEvent.is_canceled()` instead (same rule). *If a taken-over touch gets no event at all*: nothing changes in the adapter; the lifecycle cancel and Input Rule 1 (the next press of that index cancels the old gesture) recover it, and the gap is recorded as a known miss source.
- **SP5. Emulation and device IDs.** Expected, desktop: one left click gives exactly one touch press and one release (index 0), right and middle buttons and the wheel give no touch event. Phone: one tap gives one touch press and release and one emulated left mouse button. The log shows each event's `device` beside `DEVICE_ID_MOUSE`, `DEVICE_ID_KEYBOARD` and `DEVICE_ID_EMULATION`. *If touches emulated from the mouse carry a device ID that real touches never carry*: the adapter maps them to pointer `MOUSE_POINTER` (1000), so the mouse never shares index 0 with a real touch (Decision 3). *If not distinguishable*: the adapter keeps index 0 for them and TR-input-005's no-collision clause holds only on machines without a touchscreen; recorded as an accepted deviation (a same-index press is a cancel then a press under Input Rule 1, a miss at worst, never a mis-fire). *If a right or middle click produces a touch event, or a click produces two touch presses*: switch to Alternative 3 (two event families with device filtering) and revise Decision 3.
- **SP6. Positions.** Expected: under `canvas_items` and `keep`, `event.position` in `_input` and `_unhandled_input` is in viewport units, which are field units: a tap on each crosshair reads within 3 units of its label, and a tap in a letterbox bar reads outside 0 to 540 or 0 to 960. *If positions are window pixels*: `_to_field()` applies `get_viewport().get_final_transform().affine_inverse()`; the rest of the ADR is unchanged because `_to_field()` is the one conversion point.
- **SP7. Stretch, aspect and orientation.** Expected: the root viewport's visible rect is 540x960 on every window and phone; a phone taller than 9:16 shows bars above and below the field, a wider window shows bars at the sides; `get_final_transform()` shows one scale and the bar offset. Also record what `keep_width` and `expand` look like on the tall phone (kit's Aspect button) and the bar colour. *If the visible rect is not 540x960 under `keep`*: stop and revise Decision 4; field units would no longer equal viewport units.
- **SP8. Safe area.** Expected: on Android and iOS, `DisplayServer.get_display_safe_area()` is a `Rect2i` in screen pixels, the window covers the screen in the default immersive mode, and the kit's magenta inset overlay (Decision 5 formula) lines up with the cutout and the home indicator. On desktop it returns the usable screen area, not window insets. *If it is in points or dp* (iOS points are likely): multiply by `screen_get_scale()` (or the SP9 density) before the formula. *If the window does not cover the cutout*: the formula already subtracts the window position; record it. *If it reads the whole screen on a notch phone*: insets are 0 there and `edge_reject_margin` is the only side guard; record it for the Mobile Platform GDD.
- **SP9. Density for the 360 dp guard.** Expected: Android `screen_get_dpi()` gives the density so that `px * 160 / dpi` matches the phone's dp width (Developer options, Smallest width) within 5%; iOS `screen_get_scale()` gives pixels per point. *If not*: the guard (Decision 5) logs the pixel width only and the store filter is the only 360 dp enforcement.
- **SP10. Lifecycle notifications.** Expected: Android backgrounding gives `NOTIFICATION_APPLICATION_FOCUS_OUT` then `NOTIFICATION_APPLICATION_PAUSED`; the notification shade gives a focus-out only; desktop unfocus gives `NOTIFICATION_WM_WINDOW_FOCUS_OUT` and `NOTIFICATION_APPLICATION_FOCUS_OUT`; the back gesture gives `NOTIFICATION_WM_GO_BACK_REQUEST` and the app does not quit; each reaches the node two levels below the scene root (`NOTE-DEEP` lines), and the root Window's `focus_exited` signal fires as well. *Branch A (expected: at least one of the four triggers in Decision 6 reaches the deep node before suspension, on each platform)*: Decision 6 as written. *Branch B (they reach the scene root only)*: the adapter also connects the root Window's `focus_exited` and `go_back_requested` signals (method callables). *Branch C (on some platform nothing arrives before suspension, only resume-side notifications)*: on that platform the adapter also treats `NOTIFICATION_APPLICATION_RESUMED` and a focus-in not preceded by a focus-out as a loss, so the game is Paused when the player returns; ADR-0004's catch-up clamp bounds that one frame.
- **SP11. Return from the background.** Expected: on return, the resume and focus-in notifications arrive before the first `_process`, whose `delta` is large; a finger held across the switch either gets a canceled touch or its later moves and release are delivered normally. *Either way* the adapter drops them, because `cancel_all()` cleared its forwarded set (Decision 2); the result is recorded for QQ-06. *If `_process` runs before the notifications in Branch C of SP10*: ADR-0004 must zero the accumulator on the first frame after a resume, not only on `phase_changed(PAUSED)`.
- **SP12. Resize.** Expected: `Viewport.size_changed` on the root viewport fires on a desktop window resize and on entering Android split screen, while the visible rect stays 540x960 under `keep`. *If it does not fire*: the adapter polls `DisplayServer.window_get_size()` once per frame in its `_process` and treats a change as a resize.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed): the BattleWrapper builds the adapter, `detach()` teardown, method-Callable wiring, no autoloads, `Battle.set_input_canceller`. Must be Accepted before this ADR is implemented. |
| **Enables** | ADR-0004 (frame order relies on SP1; the accumulator is zeroed on `phase_changed(PAUSED)`, which this ADR's signal triggers), ADR-0006 (the lifecycle signal and `display_changed` join the wiring list), ADR-0008 (the resolver is driven only by this adapter), the Mobile Platform GDD (Vertical Slice), which inherits the stretch, safe-area and orientation decisions |
| **Blocks** | Input & Gesture epic (adapter stories), Battle HUD epic (every Control and layout story), Game State story for Rule 17 (focus-loss pause), the first phone build |
| **Ordering Note** | Run the spike before ADR-0004 and ADR-0008 are drafted to acceptance; both read SP1 and SP2. Accepting this ADR does not accept ADR-0001; it waits on ADR-0001 as well. |

## Context

### Problem Statement

Eight GDDs assume a fixed 540x960 field and one engine-facing input node, and each defers the engine facts to this ADR: which callback feeds the resolver, how a Control's events are kept away from it, which settings stop a press arriving twice, how positions become field units on a tall phone, where the safe area comes from, and which notifications mean "pause". None is in the pinned reference. A wrong guess here breaks the concept's zero-mis-fire target (Pillar 4) in ways no headless test can show, and ADR-0004 and ADR-0008 build on the answers.

### Current State

No code exists. The root `project.godot` sets the Mobile renderer and nothing else: no viewport size, no stretch mode or aspect, no orientation, no emulation setting. 4.7 changed the stretch defaults written into new projects; what an older project with no keys inherits is not stated in the reference. The two concept prototypes used `_input` with mouse events only, `canvas_items` with no aspect, and never ran on a phone. `architecture.md` gives working defaults in Data Flow 1 and 6 and B3, all marked NEEDS VERIFICATION.

### Constraints

- Godot 4.7.2, GDScript, Mobile renderer, main thread only (TR-state-003).
- No autoloads; method Callables only, no lambdas or `bind()` in `src/` (ADR-0001).
- The resolver is pure: no clock, no scene, no engine events (Input GDD). It cannot recover a stranded gesture, so the adapter must never strand one.
- MVP is played on desktop first; the first phone build follows. The desktop path must exercise the phone code path as far as possible.
- Solo, part-time developer: no extra framework, and fallbacks must be small.
- Engine facts are unsourced; every one is a spike item.

### Requirements

- One thin node is the only engine-facing input code and maps events to `press`, `move`, `release`, `cancel_pointer`, `cancel` in field units (TR-input-002).
- Every forwarded press ends in exactly one release, `cancel_pointer` or `cancel()`, even under a STOP Control, and a `canceled` touch is never a release (TR-input-003).
- `PROCESS_MODE_ALWAYS`; `cancel()` on pause, focus loss and resize; one lifecycle signal for Flow (TR-input-004, TR-state-010).
- One event family; one physical press is one gesture; mouse and touch indices do not collide; non-left buttons dropped (TR-input-005).
- Presses inside `edge_reject_margin` or the safe-area insets are rejected (TR-input-006).
- HUD Controls consume their own events first; game targets are discs (TR-input-013, TR-hud-002, TR-hud-003).
- Field units equal viewport units, no Camera2D, a 360 dp minimum width guard (TR-input-016); HUD layout in field units with insets (TR-hud-014).

## Decision

### 1. One adapter node

`InputAdapter` (`src/foundation/input/input_adapter.gd`, `extends Node`) is the only code in `src/` that overrides `_input` or `_unhandled_input`, reads `InputEvent*` touch or mouse classes outside a Control's `_gui_input`, polls `Input` for pointers, or reads `DisplayServer` display metrics. The BattleWrapper creates it, sets `process_mode = PROCESS_MODE_ALWAYS`, and calls `attach(resolver, edge_reject_margin)` after build. `edge_reject_margin` comes from the same `InputRecord` the wrapper gives HeroInput and the HUD (ADR-0005). The adapter implements `detach()` (ADR-0001 Decision 6): it disconnects, clears its forwarded set and drops the resolver. A new adapter is built with each battle (Game State Rule 16), so a finger held across a retry belongs to no forwarded press.

The game never uses `get_tree().paused`. Pause is Flow's `PAUSED` phase plus the in-sim tick gate (architecture.md Data Flow 6). `PROCESS_MODE_ALWAYS` is kept as a guard in case a later system pauses the tree.

### 2. Event path: presses unhandled, own moves and releases first

- **Presses** are read in `_unhandled_input`. A HUD Control or modal screen under the press consumes it first (SP3), so the adapter never sees presses meant for the HUD (TR-input-013, TR-hud-002).
- **Moves and releases** are read in `_input`, before any Control, but only for indices in the adapter's forwarded set (`_forwarded: Dictionary[int, bool]`). A STOP Control the finger crosses or lifts on cannot take them (SP2). Moves and releases of indices not in the set are ignored in both callbacks.
- On a forwarded press the index joins the set. A release, a canceled touch, `cancel_pointer` and `cancel_all()` remove it. So every forwarded press gets exactly one ending call (TR-input-003).
- A touch event with `canceled == true` (SP4) for a forwarded index becomes `cancel_pointer(i)`, never `release`.
- The adapter never calls `set_input_as_handled()` in `_input`. It calls it in `_unhandled_input` after forwarding a press, as nothing later needs the event.
- **Frame order.** In SP1 Branch A every call is forwarded at once, so commands run from the input call stack before the frame's ticks (TR-hud-005, owned by ADR-0004). In Branch B the adapter queues calls and the wrapper drains them with `adapter.flush()` as frame step 0.
- `Input.use_accumulated_input` stays at its default (true): coalesced drags are fine because the resolver emits one `drag_moved` per call and treats a release past slop with lost moves as a final move (Input Rule 3). `input_devices/buffering/agile_event_flushing` stays off (default), so events are not delivered between physics steps.

### 3. One event family: touch

- `project.godot` sets `input_devices/pointing/emulate_touch_from_mouse=true` and `input_devices/pointing/emulate_mouse_from_touch=true`.
- The adapter reads only `InputEventScreenTouch` and `InputEventScreenDrag`. It ignores every `InputEventMouseButton`, `InputEventMouseMotion` and gesture event. On a phone the emulated mouse events feed engine Controls (Buttons) and nothing else; on desktop the mouse reaches the adapter only as emulated touch. One physical press is therefore one touch press (SP5), and the desktop runs the same adapter code as the phone, `canceled` handling included.
- Non-left mouse buttons produce no touch event (SP5), so they never reach the resolver.
- Pointer index: a real touch keeps its `index`. A touch emulated from the mouse is mapped to `MOUSE_POINTER = 1000` when SP5 shows it can be told apart by `device`; otherwise it keeps index 0 (the SP5 deviation).
- No code compares `event.device == 0` (4.7: mouse and keyboard report `DEVICE_ID_MOUSE` and `DEVICE_ID_KEYBOARD`; `deprecated-apis.md` Patterns). Event type decides family; `device` is compared only to named constants.
- The Android settings `input_devices/pointing/android/enable_long_press_as_right_click` and `enable_pan_and_scale_gestures` stay off (default; unsourced keys, logged by the kit in SP0).

### 4. Display: 540x960, `canvas_items`, `keep`, portrait

`project.godot` sets:

```
[display]
window/size/viewport_width=540
window/size/viewport_height=960
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/handheld/orientation=1        ; portrait (SP0)

[application]
config/quit_on_go_back=false         ; Decision 6 (SP0, SP10)
```

- Field units are viewport units: the root viewport's visible rect is 540x960 on every device (SP7), event positions arrive in it (SP6), and no `Camera2D` and no non-identity canvas transform is used for the battle (TR-input-016). `scale_mode` stays at its default (fractional), so the field fills the limiting dimension.
- **Tall phones letterbox.** A phone taller than 9:16 (a 360x800 dp phone is 9:20) shows bars above and below the field; a wider window or tablet shows bars at the sides. The off-field enemy entry is not revealed at MVP. The kit records how `keep_width` would look (SP7) so the Mobile Platform GDD can choose to reveal it later (see Alternative 5).
- On desktop the window starts at the viewport size and stays resizable; `keep` scales it.
- `_to_field(pos: Vector2) -> Vector2` in the adapter is the one conversion point; it is the identity in SP6 Branch A.

### 5. Safe area, edge rejection and the 360 dp guard

Pure helpers, headless-testable, in `src/foundation/input/field_mapping.gd` (`class_name FieldMapping extends RefCounted`, static functions, no `static var`) and `field_insets.gd` (`class_name FieldInsets extends RefCounted`, four floats).

- **Source.** Only on Android and iOS (`OS.has_feature("mobile")`) does the adapter read `DisplayServer.get_display_safe_area()`, `window_get_size()` and `window_get_position()`. On desktop all insets are 0 (Input Rule 12, HUD Layout), because the desktop safe area is the usable screen, not the window (SP8).
- **Formula.** With window size `W x H` px, `s = min(W / 540, H / 960)` px per field unit, bars `ox = (W - 540 s) / 2`, `oy = (H - 960 s) / 2`, and the safe rect moved into window space (minus the window position):
  - `I_top = max(0, (safe.top - oy) / s)`, `I_bottom = max(0, (oy + 960 s - safe.bottom) / s)`,
  - `I_left = max(0, (safe.left - ox) / s)`, `I_right = max(0, (ox + 540 s - safe.right) / s)`.
  Illustrative (unmeasured) example: a 1080x2400 px phone gives `s = 2`, bars of 240 px, so a 120 px cutout gives `I_top = 0`. On 9:20 phones the bars absorb typical insets; on 9:16-class phones the inset is inside the field.
- **Rejection.** `FieldMapping.press_allowed(pos, insets, edge_reject_margin) -> bool` is false when the press is outside `[0, 540] x [0, 960]` (letterbox bars and off-window), within `edge_reject_margin + I_left` of the left edge or `edge_reject_margin + I_right` of the right edge, above `I_top` or below `960 - I_bottom`. A rejected press is not forwarded, so its later moves and release are ignored. A drag that began inside and moves into a zone stays valid (Input Rule 12).
- **HUD.** The adapter exposes `field_insets() -> FieldInsets` and emits `display_changed()` after a resize or an inset change. The wrapper passes the insets to the HUD at attach and on `display_changed()`; the HUD uses `I_top` and `I_bottom` in its layout (`burst_y = clamp(888 - I_bottom, 816, 888)`, TR-hud-014). The HUD never reads `DisplayServer` itself.
- **360 dp guard.** At attach, on phones, `field_width_dp = 540 s / px_per_dp`, with `px_per_dp = screen_get_dpi() / 160` on Android and `screen_get_scale()` on iOS (SP9). Below 360 the adapter calls `push_error` once with the measured width. It does not stop play; the store listing's device filter is the enforcement (Input GDD Edge Cases). The constant `MIN_FIELD_WIDTH_DP = 360` lives in `FieldMapping` with a comment citing the Input GDD `target_ok` formula; it is a platform floor, not a tuning value.
- **Tablets.** Under `keep` a portrait tablet is height-limited, so its scale is lower than its width alone suggests; no scale cap is added at MVP (answers the Input GDD open question for MVP; tablets are not an MVP target).

### 6. Lifecycle: four triggers, one idempotent path

In `_notification`, the adapter treats each of these as a loss:

| Notification (names NEEDS VERIFICATION, SP10) | Expected source |
|---|---|
| `NOTIFICATION_APPLICATION_FOCUS_OUT` | Android, iOS, desktop: app loses focus |
| `NOTIFICATION_APPLICATION_PAUSED` | Android, iOS: app goes to the background |
| `NOTIFICATION_WM_WINDOW_FOCUS_OUT` | desktop: window loses focus |
| `NOTIFICATION_WM_GO_BACK_REQUEST` | Android back button or back gesture (with `quit_on_go_back = false`) |

On a loss the adapter calls `cancel_all()` (clears the forwarded set, then `resolver.cancel()`), then emits `lifecycle_paused()`. The wrapper connects `lifecycle_paused` to `Flow.pause` and to the HUD's press-clearing method. Several triggers can fire for one event; every step is idempotent: `resolver.cancel()` in Idle does nothing, `Flow.pause()` in PAUSED or a terminal phase does nothing (Flow GDD Rule 17 and Edge Cases), and the HUD clear is a no-op with no press held. Focus-in and resume notifications do nothing: only a tap on the Paused screen resumes (Flow Rule 17). Branches B and C of SP10 add the Window signals or the resume-side triggers.

The back request pauses rather than quits because MVP has no quit button and the back gesture lives at the side edges where play happens; the player leaves with the home gesture.

### 7. Resize

The adapter connects its viewport's `size_changed` (`get_viewport().size_changed.connect(_on_viewport_size_changed)`). On it the adapter calls `cancel_all()` (Input Edge Case: `press_pos` is never rescaled), recomputes the insets and emits `display_changed()`. A resize is not a pause. SP12 Branch B replaces the signal with a per-frame poll.

### 8. HUD Controls and modal screens

- Every HUD Control and modal screen sets `focus_mode = FOCUS_NONE` (the 4.6 dual-focus split plays no part; there is no keyboard path at MVP).
- Modal screens (Result, Paused) are full-rect Controls with `mouse_filter = STOP` that cover the 540x960 viewport. A press in a letterbox bar is outside them and outside the field, so the adapter rejects it; nothing beneath is reached (TR-hud-002, TR-state-010).
- A HUD Control that acts on a tap reads the touch family in `_gui_input` (SP3 Branch A): it records a press it saw while Armed, fires on the matching release, ignores a release with `canceled == true`, and clears its press on the wrapper's call from `lifecycle_paused()` and `display_changed()` (TR-hud-003, Battle HUD Rule 2). HudTopBand and other display-only Controls use `MOUSE_FILTER_IGNORE`.
- SP3 Branches B and C change only how a Control reads or blocks its events, not these rules.

### 9. Flow and the canceller

The wrapper passes `adapter.cancel_all` to `Battle.set_input_canceller` (ADR-0001), so Flow's `cancel_input()` on an outcome, pause or retry also clears the adapter's forwarded set. This refines ADR-0001 Decision 5, which named the resolver's `cancel` directly. Headless, the canceller stays a no-op.

### 10. What stays out

`VirtualJoystick` (4.7) is not used; every game action is a resolver disc. Gamepad, keyboard, gyro and screen-reader paths are out of MVP scope (Battle HUD, Not built).

### Architecture Diagram

```
 OS / DisplayServer
   │ touch (and mouse ─► emulated touch on desktop)      notifications, size_changed, safe area
   ▼                                                              │
 Viewport input:  _input ─────────► GUI (_gui_input) ────► _unhandled_input
                    │ moves/releases of         │ HUD Controls, modal     │ presses not taken
                    │ forwarded indices         │ screens (touch family,  │ by a Control
                    ▼                           │ FOCUS_NONE)             ▼
            ┌──────────────────────── InputAdapter (Node, PROCESS_MODE_ALWAYS) ───────────────┐
            │ _forwarded set · _to_field() · FieldMapping.press_allowed(insets, edge margin)  │
            │ lifecycle: FOCUS_OUT / PAUSED / WM_WINDOW_FOCUS_OUT / GO_BACK ─► cancel_all()  │
            │ size_changed ─► cancel_all(), recompute insets                                  │
            └───┬──────────────────────────────┬────────────────────────┬────────────────────┘
                │ press/move/release/           │ lifecycle_paused()     │ display_changed()
                │ cancel_pointer/cancel         ▼                        ▼
                ▼                        Flow.pause()  HUD.clear     HUD layout (I_top, I_bottom)
           InputResolver ─► signals ─► HeroInput / TowerInput / HudLogic ─► commands (between ticks)
                                                       BattleWrapper._process: [flush() in SP1-B] advance, ticks, views
 Display: 540x960 viewport · canvas_items · keep · portrait · taller phones letterbox · no Camera2D
```

### Key Interfaces

```gdscript
# src/foundation/input/input_adapter.gd
class_name InputAdapter extends Node        # process_mode = PROCESS_MODE_ALWAYS, set by the wrapper
const MOUSE_POINTER := 1000                 # pointer for touches emulated from the mouse (SP5)
signal lifecycle_paused()                   # one per loss trigger; listeners are idempotent
signal display_changed()                    # after a resize or a safe-area change
func attach(resolver: InputResolver, edge_reject_margin: float) -> void
func detach() -> void                       # ADR-0001 teardown: disconnect, clear, drop resolver
func cancel_all() -> void                   # clear forwarded set, then resolver.cancel(); the canceller
func field_insets() -> FieldInsets          # field units; all 0 on desktop
func field_width_dp() -> float              # -1.0 on desktop or when density is unknown
func flush() -> void                        # SP1 Branch B only; a no-op in Branch A

# src/foundation/input/field_insets.gd
class_name FieldInsets extends RefCounted
var top: float
var bottom: float
var left: float
var right: float

# src/foundation/input/field_mapping.gd  (static only, no state)
class_name FieldMapping extends RefCounted
const FIELD_SIZE := Vector2(540.0, 960.0)
const MIN_FIELD_WIDTH_DP := 360.0           # Input GDD target_ok floor (48 dp at radius 36)
static func field_scale(window_px: Vector2) -> float
static func insets_from_safe_area(safe_px: Rect2, window_pos_px: Vector2, window_px: Vector2) -> FieldInsets
static func press_allowed(pos: Vector2, insets: FieldInsets, edge_reject_margin: float) -> bool
static func field_width_dp(window_px: Vector2, px_per_dp: float) -> float
```

The adapter's private handlers (`_input`, `_unhandled_input`, `_notification`, `_on_viewport_size_changed`, `_to_field`) are not interfaces. Names are provisional until ADR-0007 settles the `class_name` collision rule (QQ-16).

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must set the `[display]`, `[application]` and `[input_devices]` keys of Decisions 3 and 4 explicitly in `project.godot`; must never rely on engine or editor defaults for stretch mode, aspect, orientation or emulation.
- Must never override `_input` or `_unhandled_input`, or poll `Input` for pointers, anywhere in `src/` except `InputAdapter`. HUD Controls read their own events in `_gui_input` only.
- Must read presses in `_unhandled_input` and moves and releases of forwarded indices in `_input`; must ignore moves and releases of any index not in the forwarded set.
- Must end every forwarded press with exactly one `release`, `cancel_pointer` or `cancel()`; must turn a touch with `canceled == true` into `cancel_pointer`, never `release`.
- Must never call `set_input_as_handled()` from `_input`.
- Must read only `InputEventScreenTouch` and `InputEventScreenDrag` in the adapter; must never forward an `InputEventMouse*` event.
- Must never compare `event.device` to a literal number; compare event types, or `device` to `InputEvent.DEVICE_ID_*` constants.
- Must never add a `Camera2D` or change the canvas transform of the battle field; field units are viewport units.
- Must convert positions only through `_to_field()`; must compute insets and rejection only through `FieldMapping`.
- Must read `DisplayServer` safe area and density only in `InputAdapter`, and only when `OS.has_feature("mobile")`; desktop insets are 0.
- Must call `cancel_all()` before emitting `lifecycle_paused()`, and on every resize; must treat all four loss notifications the same.
- Must never resume on a focus-in or resume notification; only the Paused screen's tap resumes.
- Must never use `get_tree().paused` for the lifecycle pause.
- `Flow.pause()` must be idempotent and must do nothing in PAUSED, WON, LOST or FATAL.
- Every HUD Control and modal screen must set `focus_mode = FOCUS_NONE`; display-only Controls must use `MOUSE_FILTER_IGNORE`.
- Must connect every signal with `emitter.signal_name.connect(listener.method)`; no lambdas or `bind()` (ADR-0001).
- `InputAdapter.detach()` must disconnect `size_changed`, clear the forwarded set and null the resolver.

## Alternatives Considered

### Alternative 1: `_unhandled_input` for every event
- **Description**: The adapter reads presses, moves and releases in `_unhandled_input` only (the Input GDD's starting assumption).
- **Pros**: Simplest; every Control always wins.
- **Cons**: If a STOP Control takes the moves or release of a touch it did not see pressed (unknown, SP2), the gesture is stranded, which the resolver cannot recover and which breaks the adapter contract.
- **Estimated Effort**: About 10 lines less than the chosen design.
- **Rejection Reason**: Correctness would depend on an unverified engine rule; the hybrid costs little and holds either way.

### Alternative 2: `_input` for everything, with the adapter hit-testing Controls
- **Description**: The adapter sees every event first and drops presses inside registered Control rects.
- **Pros**: Does not depend on GUI routing at all.
- **Cons**: Duplicates the engine's GUI hit test; every HUD Control must be registered and kept in sync; a forgotten one becomes a mis-fire.
- **Estimated Effort**: About 1.5 times the chosen design, plus a registration step in each HUD story.
- **Rejection Reason**: Kept only as SP3 Branch C.

### Alternative 3: Two event families, de-duplicated by device ID
- **Description**: Read real mouse events (device `DEVICE_ID_MOUSE`, pointer 1000) and real touch events; drop emulated events by device; no touch emulation.
- **Pros**: Mouse and touch indices can never collide; uses the sourced 4.7 constant.
- **Cons**: Relies on emulated mouse events carrying a distinct device ID (unsourced); the desktop runs a different path from the phone; mouse events have no `canceled` handling to exercise on desktop.
- **Estimated Effort**: Similar code, but two paths to test.
- **Rejection Reason**: The desktop would not exercise the phone path. It is the fallback if SP5 shows emulation misbehaves.

### Alternative 4: Mouse family only (emulated from touch)
- **Description**: Keep `emulate_mouse_from_touch` and read mouse events only.
- **Pros**: One family that every Control already understands.
- **Cons**: Loses touch indices (a palm becomes the mouse) and the `canceled` flag, so an OS cancel can arrive as a release: the mis-fire TR-input-003 forbids.
- **Estimated Effort**: Less than the chosen design.
- **Rejection Reason**: Fails TR-input-003.

### Alternative 5: `canvas_items` with `keep_width` (or `expand`) and a field offset
- **Description**: The viewport grows on tall phones; the field is drawn with a vertical offset, revealing the off-field entry.
- **Pros**: Uses the whole screen; shows the enemy entry.
- **Cons**: Field units no longer equal viewport units (TR-input-016); every view, Control and the adapter must apply the offset; the HUD layout must handle a variable height; insets fall inside the field on every notch phone.
- **Estimated Effort**: About twice the display work, plus layout checks in every HUD story.
- **Rejection Reason**: Too much for MVP. The Mobile Platform GDD may adopt it later, using the kit's SP7 observations; that would supersede Decision 4.

### Alternative 6: Stretch mode `viewport`
- **Description**: Render at 540x960 and scale the image.
- **Pros**: Exact pixel layout everywhere.
- **Cons**: Text and thin lines blur on 1080 px and wider phones; the 14 dp text floor suffers.
- **Estimated Effort**: Same.
- **Rejection Reason**: Text legibility.

### Alternative 7: Leave the keys unset and take the 4.7 defaults
- **Description**: Rely on whatever the engine applies when `project.godot` has no stretch keys.
- **Pros**: No configuration.
- **Cons**: The reference says new projects get `canvas_items` and `expand`, and says nothing about an older project with no keys; `expand` breaks field units equal to viewport units.
- **Estimated Effort**: None.
- **Rejection Reason**: Unknown and, if `expand`, wrong.

### Alternative 8: `SceneTree.paused` for the lifecycle pause
- **Description**: Pause the tree on focus loss; set process modes per node.
- **Pros**: The engine stops `_process` for paused nodes.
- **Cons**: The sim is plain objects ticked by the wrapper, so the tree pause would freeze views and the HUD but not explain the in-sim gate; it adds a second pause mechanism beside Flow's PAUSED.
- **Estimated Effort**: Similar.
- **Rejection Reason**: architecture.md Data Flow 6 already puts the pause in Flow and the tick gate; one mechanism.

## Consequences

### Positive
- No Control can strand a gesture in the expected case, and the fallback for the other case is small.
- The desktop exercises the phone's input code, including `canceled` handling, so most input stories can be tested on desktop before the first phone build.
- Field units are viewport units everywhere; the resolver, HUD layout and content rules L3 and L5 to L7 hold unchanged.
- On 9:20 phones the letterbox bars absorb typical insets, so the HUD band rarely moves (narrows QQ-12).
- Every engine fact has a named spike item and a stated branch, so the spike result changes a known line rather than the design.

### Negative
- Tall phones show bars above and below the field, about 20% of a 9:20 screen.
- The back gesture never quits; a player leaves only with the home gesture.
- On a desktop with both a touchscreen and a mouse, mouse and touch may share index 0 if SP5 finds them indistinguishable.
- Four triggers can fire for one focus loss, so every listener must stay idempotent.

### Neutral
- The Mobile Platform GDD inherits Decisions 4 to 7 and may revisit Decision 4 (Alternative 5).
- `InputAdapter` gains `display_changed`, `field_insets`, `field_width_dp`, `cancel_all` and `flush` beside the `lifecycle_paused` signal that architecture.md B3 named.

## Risks

- **The spike takes a fallback branch.** Mitigation: each branch is stated above; the ADR is revised before acceptance, and ADR-0004 and ADR-0008 are drafted after the spike.
- **The spike kit itself has a script error** (it was written without an editor to check it). Mitigation: the README says how to report it; the kit uses only engine calls guarded by `ClassDB`, `has_method`, `has_signal` or `get()` where the name is unsourced.
- **A phone model behaves differently from the one tested** (OEM gesture navigation, cutout modes). Mitigation: the Pillar 4 phone test (Input GDD P1) uses two phones of different widths; record each in the kit's table.
- **iOS is not tested before the first phone build.** Mitigation: SP8 and SP10 rows stay open for iOS; the Mobile Platform GDD owns iOS acceptance.
- **The 36-unit edge margin is from memory.** Mitigation: SP4 records where the back gesture starts; the margin is a data field (`edge_reject_margin`, domain 0 to 48).
- **Letterbox bars may be black and look unfinished.** Mitigation: SP7 records the bar colour; art direction decides later.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-002: one thin adapter node is the only engine-facing input code; it maps Godot touch and mouse events to the five calls in 540x960 field units | Decision 1 (only `InputAdapter` reads events), Decisions 2 and 3 (which callback and family), Decision 4 and `_to_field()` (field units) |
| input-gesture-resolver.md | TR-input-003: every forwarded press ends in exactly one release or cancel, even under a STOP Control; `canceled` honoured | Decision 2: forwarded set, moves and releases read in `_input`, `canceled` becomes `cancel_pointer`; SP2 and SP4 branches |
| input-gesture-resolver.md | TR-input-004: `PROCESS_MODE_ALWAYS`; `cancel()` on app pause, focus loss and resize; one lifecycle signal to Game State | Decision 1 (process mode), Decision 6 (four triggers, `cancel_all()`, `lifecycle_paused`), Decision 7 (resize) |
| input-gesture-resolver.md | TR-input-005: one event family; emulation stops duplicate presses; mouse index never collides with touch index 0; non-left buttons dropped | Decision 3: touch only, both emulation flags, `MOUSE_POINTER` mapping per SP5, non-left buttons emit no touch; the SP5 deviation is stated |
| input-gesture-resolver.md | TR-input-006: presses inside `edge_reject_margin` and platform safe-area insets are rejected, via `get_display_safe_area()` converted to field units | Decision 5: formula, `press_allowed`, mobile-only source; SP8 |
| input-gesture-resolver.md | TR-input-013: game targets are resolver discs; HUD Controls consume their events before the adapter | Decision 2 (presses read unhandled), Decision 8; SP3 branches |
| input-gesture-resolver.md | TR-input-016: minimum width 360 dp by runtime guard; stretch keeps field units equal to viewport units; no Camera2D; `cancel()` on resize | Decision 4 (`canvas_items`, `keep`, no Camera2D), Decision 5 (guard), Decision 7 (resize) |
| game-state-stage-flow.md | TR-state-010 (Rule 17): focus loss or backgrounding enters Paused; ticks stop; input cancels; accumulator zeroed; a resume tap reaches nothing beneath | Decision 6 (adapter cancels and signals Flow; desktop and phone alike), Decision 8 (Paused screen consumes the tap; bars rejected). Tick stop and accumulator zeroing stay with Flow and ADR-0004 |
| battle-hud.md | TR-hud-002 (Rule 2): Result and Paused screens are full-screen modal Controls that consume every event before the adapter | Decision 8: full-rect STOP Controls over the 540x960 viewport; letterbox presses rejected by Decision 5 |
| battle-hud.md | TR-hud-003 (Rule 2): a Control fires only on a release whose press it saw while Armed, and clears that press on lifecycle or focus-loss signals | Decision 8: touch family in `_gui_input`, `canceled` ignored, cleared on `lifecycle_paused` and `display_changed`; SP3 branches |
| battle-hud.md | TR-hud-014 (Layout): layout in 540x960 field units with safe-area insets in field units; `burst_y = clamp(888 - I_bottom, 816, 888)` | Decision 5: `field_insets()` gives `I_top` and `I_bottom` in field units to the HUD; 0 on desktop |

Also answered here: QQ-02 (stretch, aspect, 360 dp, letterbox), QQ-06 (through SP1, SP2, SP3, SP10, SP11), the Input GDD open question on tablet scale (Decision 5), and part of QQ-12 (bars absorb insets on 9:20 phones; the Mobile Platform GDD still owns large insets on 9:16-class phones).

## Performance Implications
- **CPU**: One dictionary lookup and a few comparisons per input event; no per-frame work in the expected branches (SP12 Branch B adds one size read per frame).
- **Memory**: A forwarded set of at most a few entries and one `FieldInsets`.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

No code exists. The first Input story applies the `project.godot` keys of Decisions 3 and 4 to the root project, adds `FieldMapping` and `FieldInsets` with headless unit tests (formula, rejection, guard boundary at 360), then the adapter. Before that, the user runs the spike kit and the results are recorded.

**Rollback plan**: Each decision is one file or one block of settings. Changing the event path (Alternatives 1 to 3) changes `input_adapter.gd` only. Changing the aspect (Alternative 5) changes `project.godot`, `FieldMapping` and the HUD layout, and supersedes Decision 4 through a new ADR.

## Validation Criteria

- Spike items SP0 to SP12 recorded for desktop and one Android phone, each with the branch taken.
- Headless unit tests: `FieldMapping.insets_from_safe_area` against hand-computed cases (tall phone, 9:16 phone, landscape window); `press_allowed` at each boundary; `field_width_dp` true at 360 and false at 359.
- Manual evidence in `production/qa/evidence/` (ADR-0007 manual list): a drag from the field across a HUD Control ends in exactly one `drag_ended` or `drag_cancelled`; a tap on a HUD Control never reaches the resolver; focus loss pauses on desktop and phone; a canceled touch never fires a tap; letterbox taps reach nothing.
- The Pillar 4 phone test (Input GDD P1): zero mis-fires on two phones.

## Related

- Depends on ADR-0001 (composition root, wrapper `attach` and `detach`, `set_input_canceller`); refines its Decision 5 canceller.
- ADR-0002 and ADR-0005: `InputRecord` supplies `edge_reject_margin`.
- Enables ADR-0004 (frame order, SP1; accumulator on pause), ADR-0006 (signal list), ADR-0007 (manual-evidence list, lint for `_input` outside the adapter), ADR-0008 (resolver driven by this adapter).
- `docs/architecture/architecture.md`: Engine Knowledge Gap Summary, Module Ownership (InputAdapter), Data Flow 1 and 6, B2, B3, QQ-02, QQ-06, QQ-12.
- `design/gdd/input-gesture-resolver.md` (Rules 7, 9, 10, 12, Dependencies adapter contract), `design/gdd/battle-hud.md` (Rules 2, 17, Layout), `design/gdd/game-state-stage-flow.md` (Rule 17).
- Spike kit: `prototypes/adr-0003-device-spike/` (README holds the results table).
