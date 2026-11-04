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
> **Acceptance preconditions (all three):**
> 1. Spike items SP0 to SP13 (Engine Compatibility) have recorded results in the
>    results table of `prototypes/adr-0003-device-spike/README.md`, on desktop
>    and on at least one Android phone; the observed facts are copied into
>    `docs/engine-reference/godot/modules/input.md` and `modules/ui.md` with
>    device, OS version and date; and this ADR is revised to every fallback
>    branch the results chose.
> 2. The user has confirmed, one by one, each item under **Choices pending user
>    confirmation** below. Approving this ADR as a whole does not confirm them.
> 3. ADR-0001 is Accepted.

### Choices pending user confirmation

Design choices made in autonomous mode; each changes what the player sees or
does, so each needs its own yes or no.

| # | Choice | What it changes | If the user says no |
|---|---|---|---|
| C1 | The Android back button or gesture pauses the game and never quits it (`quit_on_go_back = false`) | Input GDD Rule 7 gains the back request as a pause trigger; the player leaves with the home gesture | Keep the engine default (back quits); drop the fourth trigger in Decision 6 |
| C2 | A press outside the 540x960 field, letterbox bars included, is rejected | An Input GDD Edge Case changes: a disc straddling an edge is hit only from its on-field part (no MVP disc straddles one) | Forward off-field presses unmodified; the HUD ignores the off-screen `ground_tapped` |
| C3 | Taller phones letterbox (bars above and below); the off-field enemy entry is not revealed | About 20% of a 9:20 screen is bars | Alternative 5 (`keep_width` with a field offset), which reopens TR-input-016 and the HUD layout |
| C4 | The game is locked to portrait | Rotating the phone does nothing | Supersede Decision 4; landscape needs a new layout |

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only. The live Godot 4.7 documentation was not reachable from the authoring session, and no device was available, so every engine behaviour below that the pinned reference does not cover is marked NEEDS VERIFICATION and tied to a spike item.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS, findings T1 to T9 applied in this revision, T1 and T2 were blocking), godot-specialist (engine check: no blocking issue for the ADR; K1 and the minor notes applied). Authored with the /architecture-decision flow in autonomous mode.

## Summary

The game needs one engine-facing input node that turns Godot touch events into the resolver's five calls in 540x960 field units, a display setup that keeps field units equal to viewport units on every phone, and one pause path for focus loss and backgrounding on desktop, Android and iOS. This ADR decides an `InputAdapter` that takes presses in `_unhandled_input` and its own presses' moves and releases in `_input`, queues every call and hands them to the resolver at frame step 0 (`flush()`), so a loss notification in the same batch drops a stray release; touch as the only event family; stretch `canvas_items`, aspect `keep`, 540x960, portrait (taller phones letterbox); safe-area insets in field units on phones only; a 360 dp logging guard; and a pause on any of four lifecycle notifications, all as working defaults that a device spike (SP0 to SP13) must confirm.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Input (also UI and display, and app lifecycle) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (post-cutoff version; `modules/input.md` has no touch coverage; lifecycle and safe area are unreferenced in the pinned docs) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md`, `modules/ui.md` |
| **Post-Cutoff APIs Used** | Sourced: `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (4.7, `breaking-changes.md` Input row); 4.7 new-project stretch defaults (Project row), hence explicit keys; 4.6 dual focus (`modules/input.md`), hence `FOCUS_NONE`; 4.5 recursive Control disable (UI row; property name NOT SOURCEABLE), SP2 fallback only. |
| **Verification Required** | SP0 to SP13 below. Each names one behaviour that is NOT SOURCEABLE in `docs/engine-reference/godot/**` (event timing and routing, touch fields, emulation, positions, stretch and window mode, safe area, density, lifecycle notifications, resize, focus), plus: Godot has no Android system-gesture exclusion API. The engine check agrees with the expected results from pre-4.4 knowledge only; that is not a source. |

> **Note**: If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated if the
> project upgrades engine versions. Flag it as "Superseded" and write a new ADR.

### Spike items

Method for all: run the kit in `prototypes/adr-0003-device-spike/` (standalone, with this ADR's settings), perform the README's actions, read the log. Owner: the user runs it; godot-specialist records results and branches. Expected results are unsourced.

- **SP0. Settings take effect.** Expected: the start-up report shows `canvas_items`, `keep`, portrait, both emulation flags true, `quit_on_go_back` false and (phone) fullscreen as running values; the phone does not rotate. *If a key is ignored*: find the 4.7 key in the editor's Project Settings (Advanced) and correct Decision 4. Nothing else changes.
- **SP1. Delivery against the frame.** Expected: events arrive between frames (`after=PROC` on every `IN` line; "after PHYS" stays 0 with `agile_event_flushing` off). With queue and flush (Decision 2) this decides latency only, not order. *If events arrive after the wrapper's `_process`*: they wait for the next `flush()`, one frame later, in order; accepted. ADR-0004 ticks in `_process` (Decision 1), so `flush()` stays frame step 0.
- **SP2. A drag across a STOP Control.** Expected: a touch pressed on the field and dragged onto or released over a STOP Control reaches `_input` with every move and the release. `_input` runs before the GUI, so only another node's `_input` could take it first; the spike confirms no engine step does. *If it fails*: remove that node's handling; if the engine itself does it, the wrapper disables input on the HUD subtree while the adapter holds a forwarded press, using the 4.5 recursive Control disable (property name NOT SOURCEABLE; look it up in the editor).
- **SP3. A press on a Control, and a second finger.** Expected: a touch press on a STOP or PASS Control is marked handled (no `UNH` line); `_gui_input` gets `InputEventScreenTouch` for any index plus an emulated mouse button for index 0 only. With a drag held, a second-finger tap gets the touch and no mouse event, which is why battle code never reads `InputEventMouseButton` or `Button.pressed`. *Branch A (expected)*: modal screens read `InputEventScreenTouch` (Decision 8). *Branch B (Controls get only mouse events)*: modal screens read the left `InputEventMouseButton`; the adapter forwards no press while a modal screen is shown (`set_presses_blocked(true)`); accepted miss: a modal tap made while another finger is down is lost. *Branch C (the press also reaches `_unhandled_input`)*: the wrapper calls `set_presses_blocked(true)` while a modal is shown; only modals are tappable Controls (Decision 8), so this covers every case.
- **SP4. Touch fields and OS cancel.** Expected: `InputEventScreenTouch` has `index`, `position`, `pressed`, `canceled`; `InputEventScreenDrag` has `index`, `position`; a system gesture that takes over a touch (back swipe, notification shade, palm) gives `pressed = false, canceled = true`. Also record Android 13+ predictive back. *If `canceled` is absent*: read `InputEvent.is_canceled()`. *If a taken-over touch gets no event*: the lifecycle cancel and Input Rule 1 recover it; recorded as a miss source.
- **SP5. Emulation and device IDs.** Expected, desktop: one left click gives one touch press and one release (index 0); right, middle and wheel give none. Phone: one tap gives one touch press and release and one emulated mouse button. The log shows `device` against `DEVICE_ID_MOUSE`, `DEVICE_ID_KEYBOARD`, `DEVICE_ID_EMULATION`. Telling emulated from real touches needs a touchscreen laptop (or both a mouse and a touchscreen on one machine); without one, record "not tested". *If emulated touches carry a device ID real touches never carry*: map them to `MOUSE_POINTER` (1000). *If not, or not tested*: keep index 0; TR-input-005's no-collision clause then holds only without a touchscreen, an accepted deviation (a same-index press is cancel then press, a miss at worst). *If a right or middle click makes a touch event, or a click makes two touch presses*: switch to Alternative 3 and revise Decision 3.
- **SP6. Positions.** Expected: `event.position` in `_input` and `_unhandled_input` is in field units: each crosshair reads within 3 units of its label; a letterbox tap reads outside the field. *If window pixels*: `_to_field()` applies `get_viewport().get_final_transform().affine_inverse()`; nothing else changes.
- **SP7. Stretch, aspect, orientation.** Expected: the root viewport's visible rect is 540x960 everywhere; a taller phone shows bars above and below, a wider window at the sides. Record `keep_width` and `expand` on the tall phone and the bar colour. *If the visible rect is not 540x960 under `keep`*: stop and revise Decision 4.
- **SP8. Safe area and window mode.** Record the 4.7 Android export dialog's real screen options and the start window mode; take readings in fullscreen and windowed mode (kit's Mode button). Expected: in fullscreen, `get_display_safe_area()` is a `Rect2i` in screen pixels, the window covers the screen and `window_get_position()` is (0,0), and the kit's magenta overlay lines up with the cutout and home indicator; windowed, the safe area may include system bars and the window may start below the status bar. On desktop it is the usable screen. *If in points or dp* (iOS points likely): multiply by `screen_get_scale()` first. *If fullscreen is not the immersive edge-to-edge case*: set the mode and export option the readings show to be immersive, and record both cases for the Mobile Platform GDD. *If it reads the whole screen on a notch phone*: insets are 0 there and `edge_reject_margin` is the only side guard.
- **SP9. Density.** Expected: Android `px * 160 / screen_get_dpi()` matches the phone's Smallest width within 5%; iOS `screen_get_scale()` is pixels per point. `screen_get_dpi()` may return a density bucket rather than the exact value; record which. *If off by more than 5%*: the guard logs the pixel width only and the store filter is the only 360 dp enforcement.
- **SP10. Lifecycle notifications.** Expected: Android backgrounding gives `NOTIFICATION_APPLICATION_FOCUS_OUT` then `NOTIFICATION_APPLICATION_PAUSED`; the shade gives a focus-out only; desktop unfocus gives `NOTIFICATION_WM_WINDOW_FOCUS_OUT` and `NOTIFICATION_APPLICATION_FOCUS_OUT`; the back gesture (Android 13+ predictive back included) gives `NOTIFICATION_WM_GO_BACK_REQUEST` and the app does not quit; each reaches the node two levels below the scene root (`NOTE-DEEP`), and the root Window's `focus_exited` fires. Each log line carries `Time.get_unix_time_from_system()`, so suspend and resume order is certain across a suspension. *Branch A (expected)*: Decision 6. *Branch B (they reach the scene root only)*: the adapter also connects the root Window's `focus_exited` and `go_back_requested` (method callables). *Branch C (nothing arrives before suspension on some platform)*: on that platform the adapter also treats `NOTIFICATION_APPLICATION_RESUMED`, and a focus-in with no focus-out before it, as a loss; ADR-0004's stall rule (over 0.5 s, no ticks) or, below it, its clamp (at most 3 ticks) bounds that one frame.
- **SP11. Release before loss, and return.** Desktop (and maybe a phone gesture) may synthesise a non-canceled release for a held touch on focus loss; forwarded, it completes a tap or pin, a mis-fire. The kit logs, at each loss, the last release (sequence, frame, same frame or not) and `Window.has_focus()` on every event. Expected: such a release arrives in the same delivery batch as the loss notification, before the same frame's `_process`. *Branch A (same batch)*: Decision 2 covers it; `cancel_all()` drops the queued release before `flush()`. *Branch B (a later batch, but `has_focus()` reads false on the release)*: `flush()` turns a queued release read while unfocused into `cancel_pointer`. *Branch C (neither)*: `flush()` holds each release for one extra frame and drops it if a loss arrives meanwhile (one frame of release latency). Also record on return: resume notifications against the first `_process` and its `delta`; what a held finger delivers (dropped either way). *If `_process` runs first in SP10 Branch C*: ADR-0004 covers it without a branch: a frame over 0.5 s runs no ticks and zeroes the accumulator, and the accumulator is zeroed again when Flow leaves PAUSED (ADR-0004 Decisions 2 and 3).
- **SP12. Resize.** Expected: `Viewport.size_changed` fires on a desktop resize and on Android split screen (which may letterbox a portrait-locked app instead of resizing it; record the Android version), and the visible rect stays 540x960. Also record whether it fires with no user resize (phone actions with bars, shade, cutout, keyboard). *If it fires with the window size unchanged*: the adapter ignores it for cancelling and only recomputes insets (Decision 7). *If it does not fire on a real resize*: the adapter polls `DisplayServer.window_get_size()` once per frame.
- **SP13. Focus.** Expected: with `focus_mode = FOCUS_NONE` on every Control, `get_viewport().gui_get_focus_owner()` stays null through taps, drags and lifecycle events under the 4.6 dual-focus split. *If a Control takes focus*: the wrapper calls `release_focus()` on it in its `focus_entered`, and the result is recorded for the control manifest.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed): the wrapper builds the adapter, `detach()` teardown, method-Callable wiring, no autoloads, `Battle.set_input_canceller`. ADR-0005 (Proposed): the `InputRecord` path, amended here (Decision 1). Both must be Accepted before implementation. |
| **Enables** | ADR-0004 (frame step 0 is `adapter.flush()`; the accumulator is zeroed on `phase_changed(PAUSED)`, which this ADR's signal triggers), ADR-0006 (`lifecycle_paused` and `display_changed` join the wiring list), ADR-0007 (manual-evidence list; lint for `_input` outside the adapter and for non-modal Controls not set to IGNORE), ADR-0008 (the resolver is driven only by this adapter), the Mobile Platform GDD (inherits Decisions 4 to 7) |
| **Blocks** | Input & Gesture epic (adapter stories), Battle HUD epic (every Control and layout story), the Game State story for Rule 17, the first phone build |
| **Ordering Note** | Run the spike before ADR-0004 and ADR-0008 are accepted; both read SP1, SP2 and SP11. ADR-0007's Control lint is a soft dependency: until it exists, code review checks Decision 8. |

## Context

### Problem Statement

The GDDs assume a 540x960 field and one engine-facing input node, and defer the engine facts here: which callback feeds the resolver, how Controls keep their events, which settings stop double presses, how positions become field units on a tall phone, where the safe area comes from, and which notifications mean pause. None is in the pinned reference. A wrong guess breaks the zero-mis-fire target (Pillar 4) where no headless test can see it, and ADR-0004 and ADR-0008 build on the answers.

### Current State

No code exists. The root `project.godot` sets only the Mobile renderer. 4.7 changed the stretch defaults written into new projects; what an older project with no keys inherits is unstated. Both concept prototypes read mouse events in `_input` and never ran on a phone. `architecture.md` Data Flow 1 and 6 and B3 hold working defaults marked NEEDS VERIFICATION.

### Constraints

- Godot 4.7.2, GDScript, Mobile renderer, main thread only (TR-state-003).
- No autoloads; method Callables only, no lambdas or `bind()` in `src/` (ADR-0001).
- The resolver is pure (no clock, scene or engine events) and cannot recover a stranded gesture, so the adapter must never strand one.
- MVP is played on desktop first; the first phone build follows.
- Solo, part-time developer: no extra framework; fallbacks must be small.
- Every engine fact is unsourced and is a spike item.

### Requirements

The eleven TRs in GDD Requirements Addressed: one engine-facing node in field units; exactly one ending per forwarded press, `canceled` honoured; `PROCESS_MODE_ALWAYS` and `cancel()` on pause, focus loss and resize; one event family with no index collision; edge and safe-area rejection; Controls before discs; field units equal viewport units with a 360 dp guard; HUD layout with insets in field units.

## Decision

### 1. One adapter node, and where its data comes from

`InputAdapter` (`src/foundation/input/input_adapter.gd`, `extends Node`) is the only code in `src/` that overrides `_input` or `_unhandled_input`, reads touch or mouse events outside a Control's `_gui_input`, polls `Input` for pointers, or reads `DisplayServer` display metrics.

The BattleWrapper creates it, sets `process_mode = PROCESS_MODE_ALWAYS`, and in its own `attach(battle, reduce_motion)` (ADR-0001 Decision 6) calls `adapter.attach(battle.resolver, battle.input_record.edge_reject_margin)`. **`Battle` gains a read-only member `input_record: InputRecord`**, set by the Builder from the record it already looks up (ADR-0005 Decision 8). It is the one path by which wrapper-built nodes (adapter, HeroInput, HUD) get the record; ADR-0005 Decision 8 is amended to match. `Battle.resolver` is the read-only member ADR-0008 Decision 2 names.

`detach()` (ADR-0001 Decision 6) disconnects, clears the queue and the forwarded set, and drops the resolver. A new adapter is built with each battle (Game State Rule 16), so a finger held across a retry belongs to no forwarded press.

The game never uses `get_tree().paused`: pause is Flow's `PAUSED` phase plus the in-sim tick gate (Data Flow 6). `PROCESS_MODE_ALWAYS` guards against a later tree pause.

### 2. Event path: read, queue, flush at frame step 0

- **Presses** are read in `_unhandled_input`, so a Control under the press takes it first (SP3). A press that passes rejection (Decision 5) is queued, its index joins the forwarded set (`_forwarded: Dictionary[int, bool]`), and the event is marked handled.
- **Moves and releases** of forwarded indices are read in `_input`, before any Control, so no Control can take them (SP2). They are queued and marked handled with `set_input_as_handled()`. Reason: a forwarded gesture belongs to the resolver alone; consuming it stops a Control and `_unhandled_input` from also acting on it. Presses are never consumed in `_input`, so Controls still get theirs. Moves and releases of other indices are ignored.
- A touch with `canceled == true` (SP4) for a forwarded index is queued as `cancel_pointer(i)`, never `release`.
- **`flush()`** first calls `resolver.recover_if_stuck()` (ADR-0008 Decision 7: frame step 0 is the one point known not to be inside a resolver drain), then hands the queued calls to the resolver in arrival order and empties the queue. The BattleWrapper calls it as frame step 0, before the clock (ADR-0004 owns the frame order). Commands therefore run from the resolver's signals before the frame's ticks, against the state the player last saw (TR-hud-005).
- **A loss or resize** calls `cancel_all()` at once: it empties the queue, clears the forwarded set and calls `resolver.cancel()`. A release that arrived in the same batch as a focus-loss notification is dropped before it reaches the resolver (SP11 Branch A; B and C add the focus check or a one-frame hold).
- The ending rule holds: every forwarded index leaves the set exactly once, through a flushed release, a flushed `cancel_pointer`, or `cancel_all()` (TR-input-003).
- `Input.use_accumulated_input` stays true (default): coalesced drags are fine, since the resolver emits one `drag_moved` per call and treats a release past slop with lost moves as a final move (Input Rule 3). `agile_event_flushing` stays off (default).

### 3. One event family: touch

- `project.godot` sets `input_devices/pointing/emulate_touch_from_mouse=true` and `emulate_mouse_from_touch=true`.
- The adapter reads only `InputEventScreenTouch` and `InputEventScreenDrag`, and ignores every `InputEventMouse*` and gesture event. On desktop the mouse reaches it only as emulated touch, so one physical press is one touch press (SP5), and desktop and phone run one adapter code path. The `canceled` branch is not exercised on desktop (emulated touches are never canceled); it is first exercised on a phone (SP4) and in unit tests that feed the adapter synthetic events.
- Non-left mouse buttons make no touch event (SP5) and never reach the resolver.
- A real touch keeps its `index`. A touch emulated from the mouse maps to `MOUSE_POINTER = 1000` when SP5 can tell it apart by `device`; otherwise it keeps index 0 (the SP5 deviation).
- Mouse emulation follows touch index 0 only (SP3), so no battle code may read `InputEventMouseButton` or `Button.pressed`: a second finger would be lost.
- No code compares `event.device` to a literal (4.7 moved mouse and keyboard to `DEVICE_ID_MOUSE` and `DEVICE_ID_KEYBOARD`; `deprecated-apis.md` Patterns).
- The Android settings `input_devices/pointing/android/enable_long_press_as_right_click` and `enable_pan_and_scale_gestures` stay off (defaults; unsourced keys, logged in SP0).

### 4. Display: 540x960, `canvas_items`, `keep`, portrait

`project.godot` sets these keys (names and values NEEDS VERIFICATION, SP0; the window mode override and its value also SP8):

```
[application]
config/quit_on_go_back=false

[display]
window/size/viewport_width=540
window/size/viewport_height=960
window/size/mode.mobile=3
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/handheld/orientation=1
```

`orientation=1` is portrait (C4). `mode.mobile=3` is fullscreen on phones only; desktop stays windowed. `quit_on_go_back=false` is C1.

- Field units are viewport units: the visible rect is 540x960 everywhere (SP7), positions arrive in it (SP6), and the battle has no `Camera2D` or canvas transform (TR-input-016). `scale_mode` stays fractional.
- The field size comes from `FieldBounds.WIDTH` and `FieldBounds.HEIGHT` (ADR-0009, `src/foundation/field_bounds.gd`); this ADR uses those constants and does not take ownership of them.
- **Taller phones letterbox** (C3): a phone taller than 9:16 shows bars above and below; a wider window or tablet shows bars at the sides. The kit records how `keep_width` would look (SP7).
- On desktop the window starts at the viewport size and stays resizable; `keep` scales it.
- `_to_field(pos: Vector2) -> Vector2` is the one conversion point; the identity if SP6 holds.

### 5. Safe area, edge rejection and the 360 dp guard

Pure helpers, headless-testable: `src/foundation/input/field_mapping.gd` (`class_name FieldMapping extends RefCounted`, static functions only, no `static var`) and `field_insets.gd` (`class_name FieldInsets extends RefCounted`, four floats).

- **Source.** Only when `OS.has_feature("mobile")` does the adapter read `DisplayServer.get_display_safe_area()` (`Rect2i`), `window_get_size()` and `window_get_position()` (`Vector2i`). It converts them to `Rect2`, `Vector2` and `Vector2` before calling `FieldMapping`, so `FieldMapping` takes only float types. On desktop all insets are 0 (Input Rule 12, HUD Layout), because the desktop safe area is the usable screen (SP8).
- **Formula** (`FieldMapping.insets_from_safe_area(safe: Rect2, window_pos: Vector2, window_size: Vector2) -> FieldInsets`), with `F = Vector2(FieldBounds.WIDTH, FieldBounds.HEIGHT)`:
  ```
  s   = min(window_size.x / F.x, window_size.y / F.y)        # px per field unit
  ox  = (window_size.x - F.x * s) / 2                         # side bar, px
  oy  = (window_size.y - F.y * s) / 2                         # top bar, px
  sx0 = safe.position.x - window_pos.x                        # safe rect in window px
  sy0 = safe.position.y - window_pos.y
  sx1 = safe.end.x - window_pos.x
  sy1 = safe.end.y - window_pos.y
  top    = max(0, (sy0 - oy) / s)
  bottom = max(0, (oy + F.y * s - sy1) / s)
  left   = max(0, (sx0 - ox) / s)
  right  = max(0, (ox + F.x * s - sx1) / s)
  ```
  Unit tests check exactly these expressions. Illustrative, unmeasured: a 1080x2400 px window gives `s = 2` and 240 px bars, so a 120 px cutout gives `top = 0`. The bars absorb typical insets on 9:20 phones; on 9:16-class phones the inset lies inside the field. `s <= 0` returns all zeros.
- **Rejection.** `FieldMapping.press_allowed(pos, insets, edge_reject_margin) -> bool` is false when the press is outside `[0, F.x] x [0, F.y]` (letterbox bars and off-window, C2), within `edge_reject_margin + insets.left` of the left edge or `edge_reject_margin + insets.right` of the right edge, above `insets.top` or below `F.y - insets.bottom`. A rejected press is not forwarded, so its moves and release are ignored. A drag that began inside and moves into a zone stays valid (Input Rule 12). Android's back gesture starts in the side strips this already rejects; Godot has no system-gesture exclusion API (unsourced; the margin is the only guard).
- **HUD.** The adapter exposes `field_insets() -> FieldInsets` and emits `display_changed()` when the insets or window size change. The wrapper passes the insets to the HUD at attach and on `display_changed()`; the HUD uses `insets.top` and `insets.bottom` as `I_top` and `I_bottom` (`burst_y = clamp(888 - I_bottom, 816, 888)`, TR-hud-014). The HUD never reads `DisplayServer`.
- **360 dp guard.** At attach, on phones: `field_width_dp(window_size, px_per_dp) -> float` returns `F.x * s / px_per_dp`, with `px_per_dp = screen_get_dpi() / 160.0` on Android and `screen_get_scale()` on iOS (SP9). The check is `FieldMapping.width_supported(width_dp: int) -> bool`, true when `width_dp >= MIN_FIELD_WIDTH_DP` (360), called with `floori(field_width_dp(...))`. This follows the Input GDD Formulas rule (integers, floored first), so the boundary does not depend on float rounding; tests check true at 360 and false at 359. If false, the adapter calls `push_error` once with the width. It does not stop play: the store filter enforces the floor (Input GDD Edge Cases). `MIN_FIELD_WIDTH_DP` cites the Input GDD `target_ok` formula; it is a platform floor, not a tuning value.
- **Tablets.** A portrait tablet under `keep` is height-limited, so its scale is lower than its width suggests; no scale cap at MVP (answers the Input GDD open question for MVP).

### 6. Lifecycle: four triggers, one idempotent path

In `_notification`, the adapter treats each of these as a loss (names NEEDS VERIFICATION, SP10):

| Notification | Expected source |
|---|---|
| `NOTIFICATION_APPLICATION_FOCUS_OUT` | Android, iOS, desktop: the app loses focus |
| `NOTIFICATION_APPLICATION_PAUSED` | Android, iOS: the app goes to the background |
| `NOTIFICATION_WM_WINDOW_FOCUS_OUT` | Desktop: the window loses focus |
| `NOTIFICATION_WM_GO_BACK_REQUEST` | Android back button or gesture, with `quit_on_go_back = false` (C1) |

On a loss the adapter calls `cancel_all()`, then emits `lifecycle_paused()`. The wrapper connects `lifecycle_paused` to `Flow.pause` and to the HUD's press-clearing method. Several triggers can fire for one event, so every step is idempotent: `resolver.cancel()` in Idle, `Flow.pause()` in PAUSED or a terminal phase (Flow Rule 17, Edge Cases) and the HUD clear with no press held all do nothing. Focus-in and resume do nothing: only the Paused screen's tap resumes. SP10 Branches B and C add the Window signals or the resume-side triggers.

### 7. Resize

The adapter connects `get_viewport().size_changed` to `_on_viewport_size_changed`. It compares `DisplayServer.window_get_size()` with the last size it saw. If the size changed, it calls `cancel_all()` (Input Edge Case: `press_pos` is never rescaled). Either way it recomputes the insets, and emits `display_changed()` if the size or the insets changed. A resize is not a pause. SP12 decides whether polling replaces the signal.

### 8. Battle Controls: only modal screens are tappable

Battle HUD Rule 2: the Result and Paused screens are the only Controls a player taps; everything else tappable is a resolver disc (Start/Call, burst, arc, chip, slots, towers, hero).

- **Every non-modal Control in the battle** (HudTopBand, labels, panels, decorations) must set `mouse_filter = MOUSE_FILTER_IGNORE`. `Control`, `Panel` and `ColorRect` default to STOP, and SP3 expects PASS also to mark a touch handled, so anything else would swallow presses meant for discs. ADR-0007 checks it with the scene test SCENE-1 (first wrapper story); until then code review checks it.
- **Modal screens** are full-rect Controls with `mouse_filter = STOP` over the 540x960 viewport. A press in a letterbox bar is outside them and outside the field, so the adapter rejects it; nothing beneath is reached (TR-hud-002, TR-state-010).
- A modal screen reads `InputEventScreenTouch` in `_gui_input` (SP3 Branch A): it records a press it saw while Armed, fires on that index's release, ignores a release with `canceled == true`, and clears its press when the wrapper relays `lifecycle_paused()` or `display_changed()` (TR-hud-003, Battle HUD Rule 2). It never reads `InputEventMouseButton` or uses `Button.pressed` (Decision 3).
- Every battle Control sets `focus_mode = FOCUS_NONE` (no keyboard path at MVP; SP13).
- SP3 Branches B and C change how a modal reads or blocks events (`set_presses_blocked`), not these rules.

### 9. Flow and the canceller

The wrapper passes `adapter.cancel_all` to `Battle.set_input_canceller` (ADR-0001), so Flow's `cancel_input()` on an outcome, pause or retry also empties the queue and the forwarded set. This refines ADR-0001 Decision 5, which named the resolver's `cancel` directly. Headless, the canceller stays a no-op.

### 10. What stays out

`VirtualJoystick` (4.7) is not used. Gamepad, keyboard, gyro and screen-reader paths are out of MVP scope (Battle HUD, Not built).

### Architecture Diagram

```
 OS / DisplayServer
   │ touch (mouse ─► emulated touch on desktop)        notifications · size_changed · safe area
   ▼                                                                │
 _input ───────────────► GUI (_gui_input) ───────────► _unhandled_input
   │ moves/releases of      │ modal screens only        │ presses no Control took
   │ forwarded indices      │ (others IGNORE)           │
   │ (consumed)             │                           │ (rejection, then consumed)
   ▼                                                    ▼
 ┌──────────────────── InputAdapter (Node, PROCESS_MODE_ALWAYS) ─────────────────────┐
 │ queue · _forwarded · _to_field() · FieldMapping.press_allowed(insets, margin)     │
 │ loss (4 notifications) or size change ─► cancel_all(): empty queue, clear set,    │
 │                                          resolver.cancel()                        │
 └──┬──────────────────────────────┬────────────────────────┬────────────────────────┘
    │ flush() at frame step 0       │ lifecycle_paused()     │ display_changed()
    ▼                               ▼                        ▼
 InputResolver ─► signals ─► HeroInput / TowerInput / HudLogic ─► commands, then ticks
                            Flow.pause() · HUD press clear     HUD layout (I_top, I_bottom)
 Display: 540x960 · canvas_items · keep · portrait · fullscreen on phones · no Camera2D
```

### Key Interfaces

```gdscript
# src/foundation/input/input_adapter.gd
class_name InputAdapter extends Node        # process_mode = PROCESS_MODE_ALWAYS, set by the wrapper
const MOUSE_POINTER := 1000                 # pointer for touches emulated from the mouse (SP5)
signal lifecycle_paused()                   # one per loss trigger; listeners are idempotent
signal display_changed()                    # after a window-size or inset change
func attach(resolver: InputResolver, edge_reject_margin: float) -> void
func detach() -> void                       # ADR-0001 teardown: disconnect, clear, drop resolver
func flush() -> void                        # frame step 0: queued calls to the resolver, in order
func cancel_all() -> void                   # empty queue, clear forwarded set, resolver.cancel()
func set_presses_blocked(blocked: bool) -> void   # SP3 Branches B and C only
func field_insets() -> FieldInsets          # field units; all 0 on desktop
func field_width_dp() -> float              # -1.0 on desktop or when density is unknown

# src/root/battle.gd (addition to ADR-0001's Battle)
var input_record: InputRecord               # read-only by contract; set by BattleBuilder

# src/foundation/input/field_insets.gd
class_name FieldInsets extends RefCounted
var top: float
var bottom: float
var left: float
var right: float

# src/foundation/input/field_mapping.gd  (static only, no state)
class_name FieldMapping extends RefCounted
const MIN_FIELD_WIDTH_DP := 360             # Input GDD target_ok floor (48 dp at radius 36)
static func field_scale(window_size: Vector2) -> float
static func insets_from_safe_area(safe: Rect2, window_pos: Vector2, window_size: Vector2) -> FieldInsets
static func press_allowed(pos: Vector2, insets: FieldInsets, edge_reject_margin: float) -> bool
static func field_width_dp(window_size: Vector2, px_per_dp: float) -> float
static func width_supported(width_dp: int) -> bool   # call with floori(field_width_dp(...))
```

Private handlers are not interfaces. `class_name` collisions (QQ-16) are checked by ADR-0007 NAME-1 to NAME-4; names stand unless ADR-0007 V6 reports one.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must set the keys of Decisions 3 and 4 explicitly in `project.godot`; must never rely on defaults for stretch, aspect, orientation, window mode or emulation.
- Must never override `_input` or `_unhandled_input`, or poll `Input` for pointers, in `src/` outside `InputAdapter`. Modal screens read their own events in `_gui_input` only.
- Must read presses in `_unhandled_input` and moves and releases of forwarded indices in `_input`; must ignore other indices' moves and releases.
- Must mark forwarded moves and releases handled in `_input`; must never mark a press handled in `_input`.
- Must queue the five calls and deliver them only in `flush()`, which the wrapper calls as frame step 0; `flush()` must call `resolver.recover_if_stuck()` first.
- `flush()` must tolerate `cancel_all()` running during it (a gesture listener's command can reach `cancel_input()` through a fatal): it stops when `cancel_all()` has emptied the queue and never delivers a call queued before that `cancel_all()` (ADR-0008 Risks).
- Must end every forwarded press exactly once (flushed release, flushed `cancel_pointer`, or `cancel_all()`); a touch with `canceled == true` is `cancel_pointer`, never `release`.
- Must read only `InputEventScreenTouch` and `InputEventScreenDrag` in the adapter. Must never read `InputEventMouseButton` or use `Button.pressed` anywhere in battle code.
- Must never compare `event.device` to a literal number.
- Must never add a `Camera2D` or change the battle's canvas transform.
- Must convert positions only through `_to_field()`; must compute insets, rejection and the width check only through `FieldMapping`, with `FieldBounds` sizes.
- Must read `DisplayServer` safe area and density only in `InputAdapter`, and only when `OS.has_feature("mobile")`.
- Must call `cancel_all()` before emitting `lifecycle_paused()`, and on every window-size change; must treat the four loss notifications the same.
- Must never resume on a focus-in or resume notification.
- Must never use `get_tree().paused` for the lifecycle pause.
- `Flow.pause()` must be idempotent and do nothing in PAUSED, WON, LOST or FATAL.
- Every non-modal battle Control must use `MOUSE_FILTER_IGNORE`; every battle Control must set `focus_mode = FOCUS_NONE`.
- Must connect every signal as `emitter.signal_name.connect(listener.method)`; no lambdas or `bind()` (ADR-0001).
- `InputAdapter.detach()` must disconnect `size_changed`, empty the queue, clear the forwarded set and null the resolver.

## Alternatives Considered

### Alternative 1: `_unhandled_input` for every event, forwarded at once
- **Description**: Presses, moves and releases all read in `_unhandled_input` and passed straight to the resolver (the Input GDD's starting assumption).
- **Pros**: Simplest.
- **Cons**: A Control can strand a gesture; a release synthesised before a focus loss becomes a real release (SP11).
- **Estimated Effort**: About 20 lines less.
- **Rejection Reason**: Correctness would rest on two unverified engine rules.

### Alternative 2: `_input` for everything, with the adapter hit-testing Controls
- **Description**: The adapter drops presses inside registered Control rects.
- **Pros**: Independent of GUI routing.
- **Cons**: Duplicates the GUI hit test; a forgotten registration is a mis-fire.
- **Estimated Effort**: About 1.5 times the chosen design.
- **Rejection Reason**: Only modals are tappable, so the simpler `set_presses_blocked` covers the SP3 fallbacks.

### Alternative 3: Two event families, de-duplicated by device ID
- **Description**: Real mouse events (`DEVICE_ID_MOUSE`, pointer 1000) plus real touch events; emulated events dropped by device; no touch emulation.
- **Pros**: Indices never collide; uses the sourced 4.7 constant.
- **Cons**: Needs a distinct device ID on emulated mouse events (unsourced); two adapter paths, so desktop testing covers one.
- **Estimated Effort**: Similar code, two paths to test.
- **Rejection Reason**: Two code paths for one solo tester. Fallback if SP5 shows emulation misbehaves.

### Alternative 4: Mouse family only (emulated from touch)
- **Description**: Read mouse events only, with `emulate_mouse_from_touch`.
- **Pros**: One family every Control understands.
- **Cons**: Loses touch indices (a palm becomes the mouse; emulation follows index 0 only) and the `canceled` flag, so an OS cancel can arrive as a release.
- **Estimated Effort**: Less.
- **Rejection Reason**: Fails TR-input-003.

### Alternative 5: `canvas_items` with `keep_width` (or `expand`) and a field offset
- **Description**: The viewport grows on tall phones; the field is offset vertically, revealing the off-field entry.
- **Pros**: Whole screen used; enemy entry shown.
- **Cons**: Field units no longer equal viewport units (TR-input-016); every view, Control and the adapter apply the offset; variable HUD height; insets inside the field on every notch phone.
- **Estimated Effort**: About twice the display work, plus layout checks in every HUD story.
- **Rejection Reason**: Too much for MVP (C3). The Mobile Platform GDD may adopt it later from the SP7 observations, superseding Decision 4.

### Alternative 6: Stretch mode `viewport`
- **Description**: Render at 540x960 and scale the image.
- **Pros**: Exact pixel layout.
- **Cons**: Text and thin lines blur on 1080 px and wider phones.
- **Estimated Effort**: Same.
- **Rejection Reason**: Text legibility (14 dp floor).

### Alternative 7: Leave the keys unset
- **Description**: Take whatever the engine applies with no stretch keys.
- **Pros**: No configuration.
- **Cons**: The reference gives `canvas_items` and `expand` for new projects and says nothing about an older project with no keys; `expand` breaks field units.
- **Estimated Effort**: None.
- **Rejection Reason**: Unknown and, if `expand`, wrong.

### Alternative 8: `SceneTree.paused` for the lifecycle pause
- **Description**: Pause the tree on focus loss.
- **Pros**: The engine stops `_process` for paused nodes.
- **Cons**: A second pause mechanism beside Flow's PAUSED and the in-sim gate.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Data Flow 6 already puts the pause in Flow; one mechanism.

## Consequences

### Positive
- No Control can strand a gesture, and a release in the same batch as a focus loss never reaches the resolver.
- Desktop and phone run one adapter code path, so most input stories are testable on desktop (`canceled` excepted: phone or unit test).
- Field units are viewport units; the resolver, HUD layout and content rules L3, L5 to L7 hold unchanged.
- On 9:20 phones the bars absorb typical insets, so the HUD band rarely moves (narrows QQ-12).
- Every engine fact has a spike item and a stated branch.

### Negative
- Tall phones show bars (C3); back never quits (C1).
- Every input call is delivered at frame step 0, not inside the engine callback; tests of the adapter must call `flush()`.
- On a desktop with a touchscreen and a mouse, the two may share index 0 (SP5).
- Several triggers can fire for one loss; every listener must stay idempotent.
- Every non-modal battle Control must be set to IGNORE by hand until ADR-0007's lint exists.

### Neutral
- The Mobile Platform GDD inherits Decisions 4 to 7 and may revisit Decision 4.
- `InputAdapter` gains `flush`, `cancel_all`, `display_changed`, `field_insets`, `field_width_dp` and `set_presses_blocked` beside the `lifecycle_paused` that B3 named; `Battle` gains `input_record`.

## Risks

- **A fallback branch is taken.** Each is stated; the ADR is revised before acceptance; ADR-0004 and ADR-0008 are accepted after the spike.
- **The kit has a script error** (no editor check). The README says how to report it; unsourced names go through `ClassDB`, `has_method`, `has_signal` or `get()`.
- **Phone models differ** (gesture navigation, cutouts, density buckets). The Pillar 4 test uses two phones; record each.
- **iOS is not tested before the first phone build.** SP8 and SP10 stay open for iOS; the Mobile Platform GDD owns iOS acceptance.
- **The 36-unit edge margin is from memory**, and it is the only back-gesture guard. SP4 records where the back gesture starts; the margin is a data field (domain 0 to 48).
- **Letterbox bars may look unfinished.** SP7 records the colour; art direction decides.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-002: one thin adapter node is the only engine-facing input code; it maps Godot touch and mouse events to the five calls in 540x960 field units | Decision 1 (only `InputAdapter`), Decisions 2 and 3 (callbacks, queue, family), Decision 4 and `_to_field()` (field units) |
| input-gesture-resolver.md | TR-input-003: every forwarded press ends in exactly one release or cancel, even under a STOP Control; `canceled` honoured | Decision 2: forwarded set, moves and releases read and consumed in `_input`, `canceled` becomes `cancel_pointer`, queue emptied on loss; SP2, SP4, SP11 |
| input-gesture-resolver.md | TR-input-004: `PROCESS_MODE_ALWAYS`; `cancel()` on app pause, focus loss and resize; one lifecycle signal | Decision 1, Decision 6 (four triggers, `cancel_all()`, `lifecycle_paused`), Decision 7 |
| input-gesture-resolver.md | TR-input-005: one event family; emulation stops duplicate presses; mouse index never collides with touch 0; non-left buttons dropped | Decision 3: touch only, both emulation flags, `MOUSE_POINTER` per SP5 (deviation stated), non-left buttons make no touch |
| input-gesture-resolver.md | TR-input-006: presses inside `edge_reject_margin` and safe-area insets rejected, via `get_display_safe_area()` in field units | Decision 5: formula, `press_allowed`, mobile-only source; Decision 1 gives the margin's path; SP8 |
| input-gesture-resolver.md | TR-input-013: game targets are discs; HUD Controls consume their events before the adapter | Decision 2 (presses unhandled), Decision 8 (only modals tappable, others IGNORE); SP3 |
| input-gesture-resolver.md | TR-input-016: 360 dp runtime guard; field units equal viewport units; no Camera2D; `cancel()` on resize | Decision 4, Decision 5 (`width_supported`, floored), Decision 7 |
| game-state-stage-flow.md | TR-state-010 (Rule 17): focus loss or backgrounding enters Paused; ticks stop; input cancels; accumulator zeroed; resume tap reaches nothing beneath | Decision 6 (adapter cancels and signals Flow, desktop and phone), Decision 8 (Paused screen takes the tap; bars rejected). Tick stop and accumulator stay with Flow and ADR-0004 |
| battle-hud.md | TR-hud-002 (Rule 2): Result and Paused screens are full-screen modal Controls that consume every event before the adapter | Decision 8: full-rect STOP modals; letterbox presses rejected (Decision 5) |
| battle-hud.md | TR-hud-003 (Rule 2): a Control fires only on a release whose press it saw while Armed, and clears it on lifecycle or focus-loss signals | Decision 8: touch family in `_gui_input`, `canceled` ignored, cleared on `lifecycle_paused` and `display_changed`; SP3 |
| battle-hud.md | TR-hud-014 (Layout): layout in 540x960 field units with insets in field units; `burst_y = clamp(888 - I_bottom, 816, 888)` | Decision 5: `field_insets()` gives `I_top` and `I_bottom`; 0 on desktop |

Also answered: QQ-02 (stretch, aspect, 360 dp, letterbox), QQ-06 (SP1, SP2, SP3, SP10, SP11), the Input GDD open question on tablet scale, and part of QQ-12 (bars absorb insets on 9:20 phones; the Mobile Platform GDD owns large insets on 9:16-class phones).

## Performance Implications
- **CPU**: One dictionary lookup, a few comparisons and one queue append per input event; one `flush()` per frame. SP12's poll branch adds one size read per frame.
- **Memory**: A queue and a forwarded set of a few entries each, one `FieldInsets`. The queue is reused, not reallocated per frame.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

No code exists. The first Input story applies the `project.godot` keys of Decisions 3 and 4, adds `FieldMapping` and `FieldInsets` with headless tests, adds `Battle.input_record` (with the ADR-0005 amendment), then the adapter. Before that, the user runs the spike kit and the results are recorded.

**Rollback plan**: Each decision is one file or one block of settings. An event-path change (Alternatives 1 to 3) touches `input_adapter.gd` only. An aspect change (Alternative 5) touches `project.godot`, `FieldMapping` and the HUD layout, through a new ADR that supersedes Decision 4.

## Validation Criteria

- SP0 to SP13 recorded for desktop and one Android phone, each with its branch.
- Headless unit tests: `insets_from_safe_area` against hand-computed cases (tall phone, 9:16 phone, landscape window, a window offset from the screen origin); `press_allowed` at each boundary; `width_supported` true at 360, false at 359; the adapter fed synthetic events: a release queued then `cancel_all()` reaches the resolver as nothing; a canceled touch becomes `cancel_pointer`; `flush()` keeps arrival order.
- Manual evidence in `production/qa/evidence/` (ADR-0007 list): a drag across a modal-free HUD ends in one `drag_ended` or `drag_cancelled`; a modal tap never reaches the resolver; focus loss pauses on desktop and phone, with a held button or finger never completing a gesture; a canceled touch never fires a tap; letterbox taps reach nothing.
- The Pillar 4 phone test (Input GDD P1): zero mis-fires on two phones.

## Related

- Depends on ADR-0001 (wrapper `attach` and `detach`, `set_input_canceller`; refines its Decision 5 canceller and adds `Battle.input_record`) and ADR-0005 (amends Decision 8's `InputRecord` recipients).
- Uses ADR-0009's `FieldBounds` constants.
- Enables ADR-0004 (frame step 0 `flush()`, SP1, SP11), ADR-0006 (signal list), ADR-0007 (manual list; lints for `_input` outside the adapter and for non-modal Controls), ADR-0008 (resolver driven by this adapter).
- `docs/architecture/architecture.md`: Engine Knowledge Gap Summary, Module Ownership (InputAdapter), Data Flow 1 and 6, B2, B3, B4, QQ-02, QQ-06, QQ-12.
- `design/gdd/input-gesture-resolver.md` (Rules 7, 9, 10, 12, Formulas, Edge Cases, Dependencies adapter contract), `design/gdd/battle-hud.md` (Rules 2, 17, Layout), `design/gdd/game-state-stage-flow.md` (Rule 17).
- Spike kit: `prototypes/adr-0003-device-spike/` (README holds the results table).
