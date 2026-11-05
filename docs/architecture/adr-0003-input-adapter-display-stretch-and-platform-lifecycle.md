# ADR-0003: Input Adapter, Display Stretch and Platform Lifecycle

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer from the 2026-11-04 desktop spike; reviews by godot-specialist and technical-director (TD-ADR) follow.

## Summary
Touch, display scaling and app focus are the three places the engine reaches the game, and the GDDs rest on unverified premises about all three (QQ-02, QQ-06, QQ-22). This ADR fixes one wrapper-built `InputAdapter` node that reads presses in `_unhandled_input` and the moves and releases of pointers it forwarded in `_input`, takes only `ScreenTouch`/`ScreenDrag` events with mouse-to-touch emulation on and touch-to-mouse off, rejects edge and inset presses, maps focus loss to `cancel()` plus one `lifecycle_paused` signal and a resize to `cancel()` plus `viewport_resized`, and sets the project to `canvas_items` stretch with `keep` aspect on a 540x960 base so field units equal canvas units; everything about phones stays in a device-run plan until Android and iOS confirm it.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; installed 4.7.2.stable.official) |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (QQ-02, QQ-06). The pinned reference has no touch, safe-area or lifecycle coverage beyond the section "Verified on 4.7.2" in `modules/input.md`, which is a desktop run. Every phone statement below is a decision taken on desktop evidence and is listed under Verification Required. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (lines 24, 39), `deprecated-apis.md` (line 53), `current-best-practices.md` (4.7, Platform), `modules/input.md` (section Verified on 4.7.2), `modules/ui.md`, and the spike itself: `prototypes/adr-0003-spike/README.md`, `main.gd`, `field.gd`, `main.tscn`, `project.godot` |
| **Post-Cutoff APIs Used** | `InputEvent.DEVICE_ID_MOUSE` (4.7, value 32 in the spike), used only by the dev-only duplicate counter. Stretch keys and `ProjectSettings` names are those the spike's own `project.godot` and `main.gd` used and ran on 4.7.2. |
| **Verification Required** | The owed Android and iOS device run, D1 to D10 in the table under Decision 10: event order, STOP-Control behaviour with a real finger, `canceled` and `index` on real touches, the two emulation settings, lifecycle notifications per OS, `size_changed`, safe-area rectangle space and units, letterbox presses, `free()` with a finger down (ADR-0001 item 3), dp readout. Plus the NOT SOURCEABLE items listed after the Decision. |

### What the 2026-11-04 desktop spike verified (4.7.2, macOS, `canvas_items`/`keep`, both emulations on, events injected with `Input.parse_input_event`)
This ADR relies on these rows and nothing else about the engine. Source: `modules/input.md`, section Verified on 4.7.2.

| Behaviour | Observed |
|---|---|
| Frame order | Buffered input is flushed at frame start, before `_physics_process` and `_process`; an event queued in `_process` of frame N arrives at N+1. |
| Callback order | `_input` on every node, then GUI (`gui_input`), then `_unhandled_input`. |
| STOP Control appears over a live gesture | Its moves go to `gui_input` and never reach `_unhandled_input`; its release is not taken and reaches `_unhandled_input`. |
| New press under a visible STOP Control | Press, moves, release all go to the Control; nothing reaches `_unhandled_input`. |
| Control hides while holding a press | Touch focus stays on the hidden Control; mouse focus is dropped, so mouse motion and release reach `_unhandled_input`. |
| `emulate_touch_from_mouse` | Each mouse event yields a `ScreenTouch`/`ScreenDrag` with device -1 delivered before the mouse event, which keeps device 32 (`DEVICE_ID_MOUSE`). |
| `emulate_mouse_from_touch` (default on) | Touch index 0 yields a mouse event (device -1) before the touch; index 1 yields none. |
| Positions under stretch | Already in canvas units. 600x1048 window: scale 1.0907, offset (6, 0). 500x1000: scale 0.9259, offset (0, 56). |
| Resize | `Viewport.size_changed` fired the same frame as `window_set_size`; `NOTIFICATION_WM_SIZE_CHANGED` did not reach a child in 4 frames. |
| Focus notifications | `NOTIFICATION_APPLICATION_FOCUS_IN` 2016, `_OUT` 2017, `NOTIFICATION_WM_WINDOW_FOCUS_IN` 1004, `_OUT` 1005 reach child nodes. Startup sequence 2016, 1005, 2017, then 1004, 2016. `NOTIFICATION_APPLICATION_PAUSED` 2015 and `_RESUMED` 2014 were not testable. |
| Safe area | `DisplayServer.get_display_safe_area()` returned the screen minus the menu bar on macOS. Meaningless off-device. |
| Control under a Node2D | Zero-size rect, never receives GUI input; a `CanvasLayer` parent works (the spike's `HUD` layer). |
| `input/buffering/agile_event_flushing` | Read as null. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): the wrapper builds the adapter per battle in `setup()` (Decision 4), it lives under `src/presentation/`, and `Battle.set_input_cancel` receives `resolver.cancel`. |
| **Enables** | ADR-0004 (the frame order its commands wait for rests on Decision 2), ADR-0008 (the five resolver calls and positions in field units are this ADR's output contract), ADR-0010 (HeroInput and TowerInput receive positions only through the resolver), ADR-0011 (HUD Controls sit under a `CanvasLayer`; field and band coordinates are field units). |
| **Delegates To** | ADR-0004: the Clock and wrapper `_process` ordering, the frame a lifecycle notification is handled in relative to `Battle.tick`, the accumulator zeroing on `phase_changed(PAUSED)`, how view clocks freeze. ADR-0007: the `project.godot` key lint, the Control `mouse_filter` scene lint, the `PointerGate` and `SafeAreaMapper` fixtures and the manual-evidence list for D1 to D10. ADR-0008: resolver internals (`press`, `move`, `release`, `cancel_pointer`, `cancel`, `create`, `validate`, re-entrancy, signal names, QQ-07). ADR-0010: what a pin or tap means, hit radii as constants, `HudLogic`'s modal press model. ADR-0011: HUD and field drawing, redraw keys. The Mobile Platform & Performance GDD (Vertical Slice): per-platform numbers (orientation lock, edge-to-edge, gesture insets, the layout response beyond the inset numbers in Decision 7, the dp readout, phone detection, bar colour). |
| **Blocks** | Every Input adapter story, the HudModals story (it shares the translator), the first story that sets `project.godot` display keys, and the Flow story for Rule 17 (Paused). |
| **Ordering Note** | Stays Proposed until godot-specialist and TD-ADR review. Acceptance does not require the device run; stories whose acceptance depends on a phone premise carry the D-numbers below as their evidence. QQ-22 stays open until D1 to D4 pass on Android and iOS. |

## Context

### Problem Statement
The Input and Battle HUD GDDs are Approved with bindings that cannot be met until the engine path is chosen: "the adapter is the only engine-facing input code" (TR-input-002), "every press ends in a release or cancel under a STOP Control" (TR-input-003), lifecycle `cancel()` (TR-input-004), one event family (TR-input-005), edge and safe-area rejection (TR-input-006), modals that stop presses but not moves (TR-hud-002, TR-input-013), min width and stretch (TR-input-016, TR-hud-014), and focus loss freezing the game (TR-state-010). `project.godot` sets no display or input keys, and 4.7 changed the defaults a new project would get, so today the field scale is whatever the editor wrote. The desktop spike answered the event-order questions; the phone questions remain.

### Constraints
- Godot 4.7.2, GDScript. Positions the GDDs use are field units on a 540x960 reference with no Camera2D (TR-input-016).
- ADR-0001: the adapter is built by the wrapper per battle, absent headless, never references `AppRoot`, and the injected `cancel_input` is `resolver.cancel`. Gameplay classes never touch a node.
- The resolver is pure and engine-free (ADR-0008); everything engine-facing is the adapter's.
- No device was available for the spike. Phone behaviour cannot be asserted from this reference.
- Solo developer: the decision must be enforceable by a lint, a unit test or a short manual run.

### Requirements
- TR-input-002, 003, 004, 005, 006, 013, 016; TR-state-010; TR-hud-002, 003, 014 (traced in the table below).
- One active pointer; extra touches must not cancel an aim and must not count as a tap (Input Rule 1).
- A release for an index never pressed is dropped (spike: Control hiding mid-gesture).
- A resize cancels input but never pauses (Input Rule 7).
- Focus loss and backgrounding each reach `pause()` exactly once; on return no tap is synthesised and a finger held across stays dead until lifted (Flow Rule 17).

## Decision

**1. Classes and ownership.** Four classes under `src/presentation/input/`, none under `src/battle/`.
- `InputAdapter extends Node` is the engine-facing shell. It owns `_input`, `_unhandled_input`, `_notification` and the `size_changed` connection, sets `process_mode = Node.PROCESS_MODE_ALWAYS`, and emits `lifecycle_paused()` and `viewport_resized()` (the names in `architecture.md` B3 and Input Rule 7).
- `PointerTranslator extends RefCounted` has one static function that turns an `InputEvent` into a plain `PointerSample` (`kind`, `index`, `pos`). It is the only code that tests `InputEvent` subclasses or reads their fields. The adapter and `HudModals` both call it, so the two translate identically as Battle HUD Rule 2 requires ("translates events the way the adapter does"). The user's wording "the adapter is the only object that touches InputEvent" is therefore refined to "the translator is the only reader; the adapter and HudModals are its only callers".
- `PointerGate extends RefCounted` holds the rules that need no engine: the accept bounds, the set of forwarded indices, and the calls to the resolver. It is built by the adapter's `setup()` and is unit-testable with a recording fake resolver and no node.
- `SafeAreaMapper extends RefCounted` is a pure static function from a safe-area rectangle in window pixels, plus the inverse stretch transform, to a `FieldInsets` value (Decision 7).

The wrapper builds the adapter in `BattleWrapper.setup()` after `InputResolver.create` succeeds (ADR-0001 Decision 4), calls `adapter.setup(resolver, margin, insets, dev_error)`, adds it as a child, and makes the connections of Decision 8. A null resolver builds no adapter. The adapter holds the resolver (strong, `RefCounted`) and no reference to `Battle`, Flow or `AppRoot`; `dev_error` is a method Callable on `Battle`'s `DevErrorSink` (ADR-0001 Decision 5), unguarded.

**2. Event path: the callback split.** The adapter takes presses in `_unhandled_input` and the moves, releases and cancels of pointers it forwarded in `_input`.
- Presses go through `_unhandled_input` so a visible `mouse_filter = STOP` Control takes the whole gesture and the press never exists for the adapter (spike: "new press under a visible STOP Control"). This is how a modal "reaches nothing beneath".
- Moves and releases go through `_input` because it runs before GUI and a STOP Control that appears over a live gesture swallows moves in `_unhandled_input` (spike). Release would also have reached `_unhandled_input`, but reading both in one place keeps one rule.
- `_input` ignores presses; `_unhandled_input` ignores everything but presses. Neither calls `set_input_as_handled()`.
- Input is delivered at frame start before `_process` (spike), so resolver signals and the commands behind them run before that frame's ticks. ADR-0004 owns the frame order built on this; the premise is D1 on a device.

**3. Pointers.** The adapter forwards every press that passes the accept bounds, with its own index, to the resolver, and the resolver alone decides which pointer is active (Input Rule 1). It does not drop second fingers itself, because Rule 1's replacement of an unmoved, tap-less press by a later press only works if that later press reaches the resolver.
- `PointerGate` keeps `_forwarded`, a small `PackedInt32Array` of indices whose press it forwarded and whose end it has not seen.
- Press: outside the accept bounds, drop and do not add to `_forwarded`. Otherwise add the index if absent and call `resolver.press(index, pos)`; a press for an index already forwarded is forwarded again, because Rule 1 treats it as a lost release.
- Move: forward only if the index is in `_forwarded`. A move of a finger that started in a rejected zone, under a modal or in a previous battle is dropped. A move from a forwarded finger is forwarded wherever it is, including inside the rejected zones (Input Rule 12: a drag that started elsewhere stays valid).
- Release: if the index is in `_forwarded`, remove it and call `resolver.release(index, pos)`; otherwise drop it. This drops the release of a hidden-Control gesture (spike) and the release of a finger held across a pause or retry.
- Cancel (`canceled = true` on a release-shaped touch): if forwarded, remove and call `resolver.cancel_pointer(index)`; otherwise drop. A cancel is never turned into a release (Input contract).
- A touch with `pressed = true` and `canceled = true` is dropped by the translator.
- Every forwarded press is therefore closed by a release, a `cancel_pointer`, or the adapter's `cancel_all()` (Decision 8). A press whose end the OS never delivers is recovered by the next press of the same index (Input Rule 1); that case is not solvable without a clock and the GDD accepts it.

**4. Touch and mouse: one event family.** `project.godot` sets `input_devices/pointing/emulate_touch_from_mouse=true` and `emulate_mouse_from_touch=false`. The adapter and `HudModals` read only `InputEventScreenTouch` and `InputEventScreenDrag`; every `InputEventMouse*` event is ignored whatever its device.
- Desktop and CI-by-hand testing go through the touch path: a mouse click arrives as a `ScreenTouch` (device -1) first (spike), and the mouse event that follows is ignored. Phone builds receive native touches and no mouse echo.
- `emulate_mouse_from_touch` off removes the touch echo the spike measured for index 0 (device -1 mouse event before the touch). The spike ran this setting only in its default (on) state; the off state is an untested configuration and is D10.
- The mouse pointer index cannot collide with touch index 0 by construction: the mouse is never a pointer, only the emulated touch is. Which index the emulated touch carries is not needed by any rule and not recorded by the spike.
- The device ID is never used to decide anything. Code must not test `event.device == 0` (deprecated, 4.7). The only use of `InputEvent.DEVICE_ID_MOUSE` is a dev-only counter of mouse-class events seen while emulation is on, so a run that logs a nonzero count of mouse events delivered to the translator shows duplicates are being filtered (not that they are absent).
- Non-left mouse buttons reach the adapter only if emulation turns them into touches. That is not covered by the reference; it is checked in D10 (right and middle click on desktop). If emulation does emit a touch for them, the translator gains a guard in the same change.
- `_ready` of the adapter reads the two `ProjectSettings` keys (the spike read them the same way) and reports through `dev_error` if either is wrong, so a lost key is a loud defect and not a dead desktop build.
- Built-in widgets that rely on mouse echo (`Button` and friends) are not used in the battle scene; `HudModals` reads touch events in `gui_input` (Battle HUD Rule 2). Whether built-in widgets respond to touch with `emulate_mouse_from_touch` off is not covered (NOT SOURCEABLE).

**5. Coordinates.** `event.position` of a `ScreenTouch` or `ScreenDrag` is already in canvas units under stretch (spike), and with no Camera2D, no canvas-transform change and the wrapper at identity, canvas units are field units (TR-input-016). The adapter therefore forwards `event.position` unchanged and never computes a viewport transform for events. A press in a letterbox bar arrives as a coordinate outside 0..540 or 0..960 and is dropped by the accept bounds.
- The test oracle is the spike's measurement: window 600x1048 gives `Viewport.get_screen_transform()` scale 1.0907 and offset (6, 0); window 500x1000 gives scale 0.9259 and offset (0, 56). `SafeAreaMapper` tests use these two transforms with a tolerance of 0.001 on scale and 1 px on offset. A hand-built `InputEventScreenTouch` is never transformed in tests; `PointerGate` receives field units directly.
- Nothing may add a `Camera2D`, set `Viewport.canvas_transform`, or scale the wrapper. A Camera2D would make canvas units differ from field units and invalidate every constant in the Input and HUD GDDs.
- Using `get_canvas_transform().affine_inverse()` for events is not needed and is not adopted. The spike printed `get_canvas_transform()` and `get_screen_transform()` but recorded values only for the screen transform, so the canvas transform's role under stretch is NOT SOURCEABLE; none of this ADR depends on it.

**6. Display stretch, aspect, minimum width, tall phones.** `project.godot` sets `display/window/size/viewport_width=540`, `viewport_height=960`, `display/window/stretch/mode="canvas_items"` and `display/window/stretch/aspect="keep"`. These are the exact keys and values the spike ran on 4.7.2; the keys are explicit because the 4.7 reference only describes defaults for new projects (`canvas_items`/`expand`) and says existing projects keep theirs, and says nothing about what an absent key resolves to.
- `keep` makes the viewport always 540x960, so field units equal viewport units on every device and there is exactly one layout. Layout rules L3 and L5 to L7 hold unchanged; the Battle HUD's insets are the only variable.
- Cost on a taller phone: letterbox bars. At 360x800 dp the scale is 360/540 = 0.667, the field is 640 dp tall and 160 dp (20 percent of the screen) is bars, 80 dp above and below; at 390x844 dp it is 0.722, 693 dp, 151 dp of bars (18 percent). A phone narrower than 9:16 is width-limited; a wider one (a tablet) is height-limited and gets side bars, which the edge rejection also covers.
- Recommended and not adopted: revealing the extra height of a tall phone above the top band (the path enters off a side edge, so extra top height shows nothing the player should not see, whereas extra height below shows enemies walking off the bottom). It needs an aspect mode other than the one measured (`keep_width` or `expand`) and a field-origin offset for the extra height. Neither the behaviour of those modes on a taller or wider window nor a safe origin offset is in the reference or the spike (NOT SOURCEABLE). The reveal is the first item for the Mobile Platform GDD after D6 proves what the phones look like; it changes Decision 7's formula and nothing else here. Alternative 1.
- Minimum width: 360 dp, a constant `DisplayContract.MIN_WIDTH_DP` with the field size `FIELD_SIZE = Vector2(540, 960)`. They are structural constants derived from `target_ok` (`2 x 36 x width_dp >= 25920` gives 360), not tuning values, so they are consts guarded by one unit test that evaluates the Input GDD's integer formula. The runtime guard (Input Edge Cases) reports through `dev_error` once; the store filter is the Mobile GDD's. How to read the width in dp is NOT SOURCEABLE; the guard is wired after D6.
- The bar colour is a Mobile GDD and art decision; this ADR sets nothing.
- Resize hook: `get_viewport().size_changed`, connected in the adapter's `_ready` with a typed connection and disconnected in `_exit_tree`. `NOTIFICATION_WM_SIZE_CHANGED` is not used (spike). A resize is not a pause.

**7. Rejected zones and safe-area insets.** The accept bounds, in field units, for a press:
`x_min = max(edge_reject_margin, I_left)`, `x_max = 540 - max(edge_reject_margin, I_right)`, `y_min = I_top`, `y_max = 960 - I_bottom`. A press is rejected when `x < x_min` or `x > x_max` or `y < y_min` or `y > y_max`; a press exactly on a bound is accepted. The Input and HUD GDDs say "inside the margin" without naming the boundary; this ADR names it and the sync note below asks the GDD to adopt it.
- `edge_reject_margin` comes from the Input record via the wrapper (default 36, domain 0 to 48). It applies to the side edges only; top and bottom are bounded by the insets.
- `FieldInsets` (left, top, right, bottom, floats in field units) is produced once per battle by the wrapper and given to both the adapter and `HudLogic`, so the two cannot disagree. It is fixed for the battle (Battle HUD edge case: insets stay fixed on resize).
- MVP: `FieldInsets.zero()` everywhere, as the Battle HUD GDD already assumes ("every inset is 0 until the Mobile Platform GDD"). Desktop is always zero (Input Rule 12).
- The phone mapping is specified but not wired until D6 supplies the facts it needs. `SafeAreaMapper.to_field_insets(safe_px, window_px, screen_to_canvas)` takes the safe rectangle, the window size in pixels, and `get_viewport().get_screen_transform().affine_inverse()`; it maps the rectangle's two corners to canvas units and returns `left = max(0, a.x)`, `top = max(0, a.y)`, `right = max(0, 540 - b.x)`, `bottom = max(0, 960 - b.y)`. Under `keep` the letterbox bars absorb any inset that lies inside them: a corner above the field gives a negative `a.y` and `top = 0`. Worked oracle (screen transform scale 0.9259, offset (0, 56), window 500x1000): a safe rectangle starting at y = 100 px gives `top = (100 - 56) / 0.9259 = 47.5` field units; one starting at y = 40 px gives 0.
- Whether `get_display_safe_area()` returns window pixels, screen pixels or something else on a phone, whether its origin is the window's, and what an Android edge-to-edge window reports (the reference lists "Android: Edge-to-edge display" in one line) are NOT SOURCEABLE. The spike's desktop result (screen minus menu bar) is in screen space, a different space from the window, which is exactly why the units cannot be assumed. D6 prints the rectangle with window size, screen size, scale and the screen transform on four devices; the mapper is wired from that.
- QQ-12 rule and hand-off numbers. The HUD never clamps an inset, because clamping puts HUD art under the notch. Layout uses the true inset the mapper returns. The adapter always rejects presses inside the true inset. Numbers the Mobile Platform GDD inherits, all from the Battle HUD GDD in field units (1.5 units is 1 dp at 360 dp width):

| Inset | Field units | dp at 360 | What happens |
|---|---|---|---|
| `I_top` 11 | 11 | 7.3 | The starter stage's arc top panel (y 117) meets the prompt (ends at y 106 + `I_top`). |
| `I_top` 68 | 68 | 45 | The prompt stops clearing the lane's edge. |
| `I_top` 102 | 102 | 68 | The prompt overlaps the lane by its 34 maximum. Above this the HUD layout is outside what was checked. |
| `I_bottom` 72 | 72 | 48 | `B` caps at 72; the burst button's y clamps at 816. |
| `I_bottom` 92 | 92 | 61 | Play again enters the inset. |
| `I_bottom` 96 | 96 | 64 | The burst hit disc enters the inset. |
| `I_bottom` 164 | 164 | 109 | Play again is wholly dead with no other exit. |

  If a device reports an inset above 102 (top) or 92 (bottom) after absorption by the bars, the wrapper reports it once through `dev_error` and runs on; the fix (extra shrink of the field so the inset falls into a bar, or a HUD response) is the Mobile Platform GDD's. A phone whose bars already hold the notch (a 360x800 dp phone has 80 dp bars against typical status-bar heights) needs none of these numbers. That claim is arithmetic on the spike's letterbox model, not a measured phone, so it is stated as a hypothesis for D6.

**8. Lifecycle.** The adapter handles the notifications, in its own `_notification`; no wrapper script, `AppRoot` or gameplay class does. The adapter is a child of the wrapper and receives them as the spike's child node did.

| Notification | Value | Seen on desktop | Action |
|---|---|---|---|
| `NOTIFICATION_APPLICATION_FOCUS_OUT` | 2017 | yes | loss |
| `NOTIFICATION_WM_WINDOW_FOCUS_OUT` | 1005 | yes | loss |
| `NOTIFICATION_APPLICATION_PAUSED` | 2015 | no | loss (phones; unverified) |
| `NOTIFICATION_APPLICATION_FOCUS_IN` | 2016 | yes | re-arm |
| `NOTIFICATION_WM_WINDOW_FOCUS_IN` | 1004 | yes | re-arm |
| `NOTIFICATION_APPLICATION_RESUMED` | 2014 | no | re-arm (phones; unverified) |
| `NOTIFICATION_WM_SIZE_CHANGED` | n/a | does not arrive | not used |

The code names the constants, not the numbers. The task brief listed 2016 as the focus-out value; the reference and the spike give 2016 as FOCUS_IN and 2017 as FOCUS_OUT, and this ADR follows the reference.
- Loss handling, exactly once per event. A boolean `_lost` starts false. On any loss notification: if `_lost` is true, return; else set it, call `_gate.cancel_all()` (clears `_forwarded` and calls `resolver.cancel()`), then emit `lifecycle_paused()`. On any re-arm notification, clear `_lost`. One real focus loss on desktop sends both 2017 and 1005 and gives one pause; a phone sending 2015 plus focus-out gives one. Flow's `pause()` and its injected `cancel_input()` that follow find the resolver Idle (Input Rule 7), so double cancel is safe by the Idle rule, not by coordination.
- Wiring, in `BattleWrapper.setup()`: `adapter.lifecycle_paused` connects to Flow's `pause` and to `HudLogic.modal_cancel`; `adapter.viewport_resized` connects to `HudLogic.modal_cancel` alone. Both are plain connections with no flags (ADR-0001 Decision 5), to targets `Battle` and the wrapper hold.
- Resize handling: on `size_changed`, `cancel_all()` then emit `viewport_resized()`. No pause. If `size_changed` fires at startup, a cancel with no gesture is a no-op (Input Edge Cases).
- Resume: no tap is synthesised and no release is made from a cancel. `_forwarded` was cleared, so the finger held across the pause has moves and release dropped by the gate and a new press is needed. The resume tap is a press on the Paused modal, which is a STOP Control shown by `HudLogic` on `phase_changed(PAUSED)` and takes the press before `_unhandled_input` (Decision 2), so it reaches nothing beneath. On desktop the refocus click may be that tap or may arrive before the modal is up; the Flow GDD accepts either, and D9 records which.
- The pause is Flow's state, not `SceneTree.paused`. `get_tree().paused` is never set. The tick stops because `Battle.tick` returns at once outside WAVE and INTERMISSION and the wrapper zeroes its accumulator (Flow Rule 17; ADR-0004). `PROCESS_MODE_ALWAYS` on the adapter is the defensive setting the Input GDD asks for, so a future tree-level pause cannot strand a gesture.
- A focus-out at startup is possible (the spike saw 1005 and 2017 during launch before the window had focus). The adapter treats it as real. If the Boot story shows a spurious Paused on every launch, the fix is an arming rule in `_ready`, decided then from D9's frame numbers. Whether a notification can be dispatched inside `Battle.tick` is ADR-0004's check; the expectation is that engine callbacks run on the main thread one after another.

**9. HUD Controls and modals.**
- Every battle HUD `Control` is parented under a `CanvasLayer`, never under the wrapper's `Node2D` or any other `Node2D` (spike: a Control under a Node2D gets a zero-size rect and no GUI input). ADR-0011 places the layer; ADR-0001's `HudTopBand`, `HudField` and `HudModals` are children of it.
- Only `HudModals` (the Paused and result screens) is `mouse_filter = Control.MOUSE_FILTER_STOP`. Every other HUD Control is `MOUSE_FILTER_IGNORE`, because the burst button, build arc and world targets are resolver discs, not Controls (TR-input-013); a stray STOP or PASS Control over the field would swallow presses before the adapter.
- Modals are built once and toggled with `visible`, never freed (TR-hud-002). A modal that hides inside its own press handler (the resume tap) keeps touch focus and still receives the drag and release (spike); its handler must treat them as no-ops. On desktop with emulation, the mouse focus is dropped and the echo reaches `_unhandled_input`; the adapter ignores it because it is mouse-class.
- A modal appearing over a live gesture: the adapter keeps receiving that gesture's moves and release through `_input` (spike), so it closes normally. `modal_cancel()` is wired for lifecycle and resize only.
- `HudModals` reads touches through `PointerTranslator` and routes a `CANCEL` sample to `modal_cancel_pointer`, never to a release (Battle HUD Rule 2). The mapping from sample to `HudLogic` call is ADR-0010's and ADR-0011's.

**10. Device verification plan (owed run).** Everything the spike could not prove. Run the spike scene on a physical Android phone and an iPhone with real fingers, adding a manual mode (the spike injects events by frame number; D1 to D5 need a human, so the run extends `main.gd` with a flag that skips the injected script, shows the Modal on a timer or a second-finger press, and prints the same `SPIKE|f<frame>|` lines). Output is read from `adb logcat | grep 'SPIKE|'` and the Xcode console. Retain logs under `production/qa/evidence/adr-0003-device-run/`. Include a 360x800 dp phone (or nearest) and a near-9:16 device.

| Run | Do on the device | Each must print or show | If the premise fails, reopen |
|---|---|---|---|
| D1 Event order | One finger: press, drag, lift, several times | For every event, the `main._input` line and the `field._unhandled_input` line carry a frame number whose first `main._process` mark comes after them; `_input` precedes `_unhandled_input` | ADR-0004 frame order; Battle HUD TR-hud-005 and Rules 10 and 11; cross-GDD scenarios 1, 3, 5 (QQ-22) |
| D2 Fields | Same, plus two fingers down at once, lift in both orders, and a press at an edge swipe | Lines show `idx`, `pressed`, `canceled`, `pos`, `dev` for touch and drag; whether `idx` of a second finger is 1 and whether an index is reused while another finger is down; `canceled` true on a system gesture steal | Input Rule 1 (pointer model), Adapter contract on `canceled`, TR-input-003, Hero release mis-fire rows |
| D3 STOP over a gesture | Hold a finger on the field, make the Modal appear under it (timer), keep dragging, lift | `_input` receives every move and the release after the Modal appears; the Modal's `gui_input` also receives moves; a NEW press under the Modal reaches only the Modal | Input adapter contract, Battle HUD Rule 2, TR-hud-002, TR-input-013, QQ-22 |
| D4 Control hides mid-gesture | Press on the visible Modal, hide it during the hold, drag, lift | Where the drag and release arrive (hidden Control's `gui_input` and/or `_input`); the adapter-equivalent line for the never-forwarded index drops | PointerGate release rule; HudModals no-op rule |
| D5 Lifecycle | Home button, app switcher, lock button, notification shade pull-down (Android), Control Center (iOS), incoming call or permission dialog, return each time | Which of 2017, 1005, 2015 fire, in what order, per cause; which of 2016, 1004, 2014 fire on return; the count of `lifecycle_paused` the dedupe would emit (must be one per loss) | Flow Rule 17, TR-state-010, TR-input-004, Flow acceptance row 12 and the lifecycle deferred criterion |
| D6 Resize and safe area | Print at launch and after any window change (Android multi-window if supported): `size_changed` occurrences, `DisplayServer.get_display_safe_area()`, `window_get_size()`, `screen_get_size()`, `screen_get_scale()`, `screen_get_dpi()`, `Viewport.get_screen_transform()`; press in a letterbox bar and at the field corners | Rectangle space (window or screen pixels), origin, and whether it includes the status bar and the cutout; the mapper's `FieldInsets` for each device; whether presses in the bars arrive and with which coordinates; the dp width computed from dpi | Input Rule 12, TR-input-006, TR-hud-014, the inset table in Decision 7; Mobile Platform GDD scope |
| D7 Edge margin | Swipe from each side edge, with Android gesture navigation on | Whether the touch is delivered at all and its x; whether 36 units clears the gesture zone | Input GDD open question on `edge_reject_margin` (already open) |
| D8 `free()` with a finger down | Hold finger A anywhere; with finger B tap Retry on the Lost screen; keep A moving, then lift | No error; no gesture from A; A's lift and next press start clean | ADR-0001 Verification item 3 (closed by this run) |
| D9 Startup and resume | Cold launch, then background and return | Frame numbers of the launch notifications relative to `_ready` and the first `_process`; whether Paused would appear on launch; whether the refocus tap on desktop is the resume tap | Decision 8 arming rule |
| D10 Emulation | Desktop: run the spike with `emulate_mouse_from_touch=false` and the `PointerTranslator` stub; right and middle click with emulation on; touch injection of a second finger. Device: tap with the setting off | Zero mouse events echoing a touch; no `ScreenTouch` for non-left buttons; `Button`-free modals still receive touches | TR-input-005; Battle HUD Rule 2 translation |

D1 to D4 close QQ-22 on Android and iOS. A failure of D1 or D3 reopens Approved Input and Battle HUD rules.

### Architecture Diagram

```
Engine frame start (input flushed before _physics_process / _process)
 │
 ├─ _input(event)  on every node ──────────────────────────────────────────┐
 │     InputAdapter._input: PointerTranslator.read → MOVE / RELEASE / CANCEL│
 │         └─► PointerGate: forwarded? ──► resolver.move / release / cancel_pointer
 ├─ GUI (CanvasLayer HUD)                                                   │
 │     HudModals (STOP) takes presses under it; every other HUD Control IGNORE
 └─ _unhandled_input(event)                                                 │
       InputAdapter._unhandled_input: PRESS only                            │
           └─► PointerGate: inside accept bounds? ──► resolver.press ◄──────┘
 
InputAdapter._notification: FOCUS_OUT / WM_WINDOW_FOCUS_OUT / APPLICATION_PAUSED
 └─► (once per loss) PointerGate.cancel_all() ─► resolver.cancel()
                    emit lifecycle_paused ─► Flow.pause · HudLogic.modal_cancel
Viewport.size_changed ─► cancel_all() ─► emit viewport_resized ─► HudLogic.modal_cancel

BattleWrapper (Node2D, identity)
 ├─ InputAdapter (Node, PROCESS_MODE_ALWAYS)   ← only InputEvent consumer for gameplay
 ├─ HUD: CanvasLayer ─ HudTopBand · HudField (IGNORE) · HudModals (STOP)
 └─ field views / stage scene (no Camera2D)
project.godot: viewport 540x960 · stretch canvas_items · aspect keep
               emulate_touch_from_mouse=true · emulate_mouse_from_touch=false
```

### Key Interfaces

```gdscript
class_name DisplayContract extends RefCounted
const FIELD_SIZE := Vector2(540.0, 960.0)   # canvas units == field units (no Camera2D)
const MIN_WIDTH_DP := 360                    # derived from target_ok; not a tuning value
const STRETCH_MODE := "canvas_items"         # asserted against ProjectSettings at boot (dev_error)
const STRETCH_ASPECT := "keep"

class_name FieldInsets extends RefCounted
var left: float
var top: float
var right: float
var bottom: float
static func zero() -> FieldInsets

class_name PointerSample extends RefCounted
enum Kind { NONE, PRESS, MOVE, RELEASE, CANCEL }
var kind: Kind = Kind.NONE
var index: int = -1
var pos: Vector2 = Vector2.ZERO             # canvas units == field units

class_name PointerTranslator extends RefCounted
## The only code that reads InputEvent subclasses. Fills `out`, returns false for anything that is not a
## ScreenTouch or ScreenDrag (every InputEventMouse* is false). ScreenTouch: pressed and not canceled -> PRESS;
## not pressed and canceled -> CANCEL; not pressed -> RELEASE; pressed and canceled -> false. ScreenDrag -> MOVE.
static func read(event: InputEvent, out: PointerSample) -> bool

class_name PointerGate extends RefCounted
func _init(resolver: InputResolver, edge_reject_margin: float, insets: FieldInsets, dev_error: Callable) -> void
func press(index: int, pos: Vector2) -> void          ## Drops outside the accept bounds; else forwards and records the index.
func move(index: int, pos: Vector2) -> void           ## Forwards only recorded indices.
func release(index: int, pos: Vector2) -> void        ## Forwards and forgets a recorded index; drops others.
func cancel_pointer(index: int) -> void               ## As release, to resolver.cancel_pointer.
func cancel_all() -> void                             ## Forgets every index, then resolver.cancel().
func accepts(pos: Vector2) -> bool                    ## The Decision 7 bounds, boundary inclusive.

class_name SafeAreaMapper extends RefCounted
## Pure. safe_px is the engine's safe-area rectangle (space unverified, D6); screen_to_canvas is
## get_viewport().get_screen_transform().affine_inverse(). Insets are floored at 0; letterbox absorbs the rest.
static func to_field_insets(safe_px: Rect2, screen_to_canvas: Transform2D) -> FieldInsets

class_name InputAdapter extends Node
signal lifecycle_paused()          ## Once per focus loss or background; wrapper -> Flow.pause, HudLogic.modal_cancel
signal viewport_resized()          ## Wrapper -> HudLogic.modal_cancel only. A resize never pauses.
func setup(resolver: InputResolver, edge_reject_margin: float, insets: FieldInsets, dev_error: Callable) -> void
func _input(event: InputEvent) -> void              # MOVE, RELEASE, CANCEL of forwarded pointers
func _unhandled_input(event: InputEvent) -> void    # PRESS only
func _notification(what: int) -> void               # loss and re-arm per the Decision 8 table
```

`Battle.set_input_cancel` still receives `resolver.cancel` (ADR-0001). It does not clear `_forwarded`; the leftover indices are harmless, because the resolver drops moves and releases in Idle and drops other-index calls while another pointer is active.

### Implementation Guidelines
- `project.godot` **must** contain `display/window/size/viewport_width=540`, `viewport_height=960`, `display/window/stretch/mode="canvas_items"`, `display/window/stretch/aspect="keep"`, `input_devices/pointing/emulate_touch_from_mouse=true` and `emulate_mouse_from_touch=false`. ADR-0007's lint greps all six; the adapter checks them at boot.
- Only `PointerTranslator` **may** test `InputEvent` subclasses or read their fields. `InputAdapter` and `HudModals` **must** call it and **must never** name `InputEventMouse*`, `InputEventKey` or `event.device` in gameplay or HUD code.
- The adapter **must** read presses in `_unhandled_input` and moves, releases and cancels in `_input`; it **must never** read a press in `_input` and **must never** read a move or release in `_unhandled_input`. It **must never** call `set_input_as_handled()`.
- The adapter **must** forward `event.position` unchanged; the wrapper **must never** gain a `Camera2D`, a canvas-transform change or a scale, and the adapter **must never** transform event positions.
- The adapter **must** pass every press inside the accept bounds to the resolver and **must never** drop a second finger itself; it **must** drop moves and releases of indices it did not forward.
- A `canceled` touch **must** go to `cancel_pointer` and **must never** be treated as a release; the adapter **must never** synthesise a release or a tap from a cancel, a pause or a resume.
- The adapter **must** run with `process_mode = PROCESS_MODE_ALWAYS` and **must** handle lifecycle in its own `_notification`; no other class **may** handle `NOTIFICATION_APPLICATION_*` or `NOTIFICATION_WM_WINDOW_FOCUS_*` for pause or cancel.
- A loss **must** produce one `lifecycle_paused`; a resize **must never** produce one. A pause **must never** use `SceneTree.paused`.
- The adapter **must** connect `size_changed` with a typed connection, disconnect it in `_exit_tree`, and **must never** use `NOTIFICATION_WM_SIZE_CHANGED`.
- Every battle HUD `Control` **must** be under a `CanvasLayer` and **must never** be under a `Node2D`. `HudModals` **must** be the only `MOUSE_FILTER_STOP` Control in the battle scene; every other HUD Control **must** be `MOUSE_FILTER_IGNORE`.
- Modals **must** be built once and toggled with `visible`; a modal **must never** be freed from its own handler.
- Layout **must** use the true `FieldInsets`; the HUD **must never** clamp an inset. The accept bounds **must** be computed once per battle from the same `FieldInsets` object `HudLogic` receives.
- `FIELD_SIZE`, `MIN_WIDTH_DP` and the stretch constants **must** live in `DisplayContract` only; no other class **may** write 540, 960 or 360 for display purposes.
- `PointerGate` and `SafeAreaMapper` **must** extend `RefCounted` and **must never** touch a node, `DisplayServer` or `Engine`, so tests run headless. The adapter is the only caller of `DisplayServer`.
- Nothing under `src/` **may** test `event.device == 0`.

## Alternatives Considered

### Alternative 1: Reveal the extra height of a tall phone (`keep_width` or `expand` with an origin offset)
- **Description**: The viewport keeps 540 units of width and grows taller with the phone; the field is shifted down so the extra height sits above the HUD band, hiding the off-field entry.
- **Pros**: No letterbox; a 360x800 dp phone uses all 800 dp instead of 640; matches the architecture's recommendation.
- **Cons**: Relies on stretch aspect modes the reference and spike do not cover; needs an origin offset that every field-unit conversion must honour; a wider-than-9:16 window under `keep_width` would shrink the height below 960 and cut the field; every HUD inset and the bar-absorption property of Decision 7 change.
- **Rejection Reason**: Not sourceable. `keep` has two measured oracles and a single layout; the reveal is deferred to the Mobile Platform GDD with D6's measurements, and the cost of waiting is 18 to 20 percent of a tall screen as bars.

### Alternative 2: `canvas_items` with `expand` (the 4.7 new-project default)
- **Description**: Leave the editor default.
- **Pros**: No letterbox on any aspect.
- **Cons**: Viewport size varies in both axes, so field units no longer equal viewport units, a wider window reveals the off-side-edge entry (Enemy & Wave GDD), the 540-wide edge-margin rule and the layout rules need a per-aspect response, and nothing in the spike measured it.
- **Rejection Reason**: Breaks TR-input-016 (field units equal viewport units) and the hidden entry.

### Alternative 3: Adapter reads everything in `_unhandled_input`
- **Description**: Presses, moves and releases all in `_unhandled_input`, the Input GDD's first note.
- **Pros**: One callback.
- **Cons**: A modal appearing over a live drag swallows its moves (spike); the aim freezes while the finger moves.
- **Rejection Reason**: Disproved by the spike.

### Alternative 4: Adapter reads everything in `_input`
- **Description**: Presses too, with the adapter hit-testing the modal itself.
- **Pros**: Never starved by a Control.
- **Cons**: The adapter then sees presses meant for the modal and needs a geometry test of modal state, which duplicates the engine's Control routing and gets out of sync; the "resume tap reaches nothing beneath" guarantee becomes code instead of routing.
- **Rejection Reason**: Presses in `_unhandled_input` get the guarantee for free.

### Alternative 5: The adapter drops extra fingers
- **Description**: Track one active index in the adapter and ignore every other touch.
- **Pros**: Simpler resolver contract.
- **Cons**: Input Rule 1 lets a later press replace an unmoved, tap-less press so a resting palm cannot block the thumb; that requires the later press to reach the resolver. It also duplicates the resolver's state.
- **Rejection Reason**: Contradicts Input Rule 1.

### Alternative 6: Pause with `SceneTree.paused`
- **Description**: `get_tree().paused = true` on focus loss.
- **Pros**: Stops every `_process` at once.
- **Cons**: Needs `process_mode` on every node that must keep running (the modal, the adapter, the clearance timer after an outcome); freezes the Paused modal's own animation; how Controls and `_input` behave under a paused tree is not in the reference; it is a second pause mechanism beside Flow's Paused.
- **Rejection Reason**: Flow already has Paused as a state; ADR-0004 already gates the tick and zeroes the accumulator.

### Alternative 7: Handle lifecycle in the wrapper or `AppRoot`
- **Description**: A wrapper `_notification` calls Flow and the resolver directly.
- **Pros**: One fewer signal.
- **Cons**: Two owners of "cancel on pause"; the Input GDD gives the adapter the notifications; `AppRoot` has no battle knowledge beyond `is_over()`.
- **Rejection Reason**: The adapter owns lifecycle (Input Rule 7, Flow Rule 17); the wrapper only connects.

### Alternative 8: Handle both event families
- **Description**: Emulation off both ways; the adapter reads `InputEventMouseButton` for desktop and `ScreenTouch` for phones.
- **Pros**: No engine emulation to trust.
- **Cons**: Two code paths, two sets of tests; desktop no longer exercises the phone path; pointer index for mouse must be invented; HudModals must do the same.
- **Rejection Reason**: Desktop testing through the touch path is the reason emulation exists (Input Rule 5, TR-input-005).

### Alternative 9: Leave `emulate_mouse_from_touch` at its default (on)
- **Description**: Touches also produce mouse events, as measured in the spike.
- **Pros**: Built-in widgets work with touch.
- **Cons**: A second event per press on index 0 (device -1 before the touch), which every consumer must ignore; no built-in widget is used.
- **Rejection Reason**: Off removes the duplicate at its source; the untested state is D10.

## Consequences

### Positive
- The adapter's rules are three small testable pieces and a thin Node; most of TR-input-003 and TR-input-006 is provable headless.
- The same translator serves the adapter and `HudModals`, so the two cannot disagree on event family or on `canceled`.
- `keep` makes one layout with two measured oracles, and absorbs insets into bars on tall phones.
- Presses are blocked by routing, not by code, so a modal can never leak a tap beneath.
- The desktop build exercises the phone path, so the resume and cancel code runs every day.

### Negative
- Tall phones show letterbox bars, 18 to 20 percent of the screen at 360x800 and 390x844 dp, until the Mobile Platform GDD revisits the reveal.
- A startup focus-out can show a spurious Paused on launch; a rule is deferred to D9.
- Several phone premises are unverified until the device run; QQ-22 stays open.
- The wording "adapter is the only InputEvent reader" becomes "translator is the only reader" and `HudModals` shares it.
- Four new classes where the architecture sketch showed one.

## Risks
- **Real touches differ from emulation** (index reuse, `canceled` semantics, event order). Mitigation: D1, D2, D3, D8; every rule that depends is on the gate, so a change touches one class.
- **The Android or iOS pause notification differs from the desktop one.** Mitigation: all three loss notifications map to one deduplicated path; D5 picks the real set; the sync note flags Flow's row.
- **Safe-area rectangle units are wrong.** Mitigation: insets are zero until D6; the mapper is pure and takes a transform so a unit change is one test.
- **A STOP or PASS Control creeps over the field.** Mitigation: ADR-0007 scene lint on `mouse_filter` of everything under the HUD layer.
- **`keep` bars waste screen on tall phones and hurt target size.** Mitigation: the field scale is width-limited at the minimum width (0.667), where the 48 dp targets were sized; height-limited devices are wider than 9:16 and scale higher. The reveal is a documented follow-up.
- **A rejected-zone boundary mismatch with a GDD test.** Mitigation: the boundary is named here and flagged for the Input and HUD GDDs.
- **The startup focus-out pauses every launch.** Mitigation: D9; the fix is a small arming rule inside the adapter.
- **A lost release strands a gesture.** Mitigation: Input Rule 1's replacement by the next press; the adapter's contract plus `cancel_all()` on pause and resize.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-002: one thin adapter node is the only engine-facing input code; maps touch and mouse events to the five calls in 540x960 field units | Decisions 1, 3, 5: `InputAdapter` over `PointerTranslator` and `PointerGate`; `event.position` is already in field units (spike) |
| input-gesture-resolver.md | TR-input-003: every forwarded press is followed by a release or cancel; STOP Control; `canceled` honoured | Decisions 2, 3: presses in `_unhandled_input`, moves and releases in `_input`; `canceled` goes to `cancel_pointer`; D3, D4 |
| input-gesture-resolver.md | TR-input-004: `PROCESS_MODE_ALWAYS`; cancel on pause, focus loss, resize; one lifecycle signal | Decision 8: `lifecycle_paused`, `viewport_resized`, `cancel_all()`; D5 |
| input-gesture-resolver.md | TR-input-005: one event family; no duplicate presses; mouse index never collides; non-left buttons dropped | Decision 4: emulation settings, mouse events ignored, translator reads only touch; D10 for non-left buttons |
| input-gesture-resolver.md | TR-input-006: edge and safe-area rejection via `get_display_safe_area()` converted to field units | Decision 7: accept bounds, `SafeAreaMapper`; the safe-area API's phone behaviour is NOT SOURCEABLE until D6 |
| input-gesture-resolver.md | TR-input-013: burst, arc and world targets are discs; HUD Controls consume events before the adapter | Decisions 2, 9: only `HudModals` is STOP; other HUD Controls IGNORE |
| input-gesture-resolver.md | TR-input-016: min width 360 dp, stretch keeps field units equal to viewport units, no Camera2D, cancel on resize | Decisions 5, 6, 8: `keep` on 540x960, `DisplayContract`, resize hook; the dp read is NOT SOURCEABLE |
| game-state-stage-flow.md | TR-state-010: focus loss or backgrounding enters Paused, ticks stop, input cancels, a resume tap reaches nothing beneath | Decision 8: notification table, once per loss, `lifecycle_paused` to `Flow.pause`; tick stop and accumulator are ADR-0004's |
| battle-hud.md | TR-hud-002: Result and Paused screens are full-screen modal Controls, built once, consuming events before the adapter, hidden in their own handler | Decision 9; spike rows on STOP and hiding |
| battle-hud.md | TR-hud-003: HudLogic's modal press model repeats the adapter's rules; lifecycle and focus loss clear it | Decisions 1, 3, 7, 8: shared `PointerTranslator` and accept bounds; `modal_cancel` wired to both signals |
| battle-hud.md | TR-hud-014: layout in 540x960 field units with insets converted to field units | Decisions 6, 7: `keep`, `FieldInsets`, mapper, and the inset hand-off table |

## Performance Implications
- **CPU**: Per event: one type test, one `PackedInt32Array` search over at most a few entries and one resolver call. The adapter reuses one `PointerSample`, so no per-event allocation. Cost is negligible against the 16.6 ms frame; no measurement is claimed before D1.
- **Memory**: Four small objects per battle, freed with the wrapper.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
Greenfield: `src/` holds no `.gd` file. Add the six display and input keys to `project.godot` (currently it has only `[application]` and `[rendering]`). Create `src/presentation/input/` with the classes above and `tests/unit/input/` fixtures. Extend the spike with the manual mode for D1 to D10 when a device is at hand. The prototype is not migrated. On acceptance: update TR-input-006's registry text (the safe-area source is not fixed), the Input GDD's ADR note, the Flow GDD's lifecycle row, and the architecture's B3 block (see the sync note).

## Validation Criteria
- `PointerGate` fixtures with a recording fake resolver: a press inside bounds forwards; a press at x = 35.9 with margin 36 is dropped and a press at x = 36 forwards; a move of a never-forwarded index drops; a release of a never-pressed index drops; two fingers forward two presses and the fake logs both; after `cancel_all()` a held finger's move and release drop; a `CANCEL` calls `cancel_pointer` and never `release`; a repeated press of one index forwards twice (TR-input-003, Input fixtures 5, 17, 36).
- `PointerTranslator` fixtures: every `ScreenTouch` combination of `pressed` and `canceled`, a `ScreenDrag`, a `MouseButton` (device 32 and device -1) and a key event produce the table in Key Interfaces (TR-input-005).
- `SafeAreaMapper` fixtures with the spike oracle: scale 0.9259, offset (0, 56), safe rectangle at y = 100 px gives `top` 47.5; at y = 40 gives 0; scale 1.0907, offset (6, 0), left edge at 0 gives `left` 0 (TR-input-006, TR-hud-014).
- A `DisplayContract` test evaluates `2 x 36 x MIN_WIDTH_DP >= 48 x 540` and `2 x 35 x MIN_WIDTH_DP < 48 x 540` (Input criterion 33; TR-input-016).
- ADR-0007's lint: the six `project.godot` keys, no `Camera2D` in the wrapper scene, every `Control` under the HUD `CanvasLayer` is IGNORE except `HudModals`, no `Control` whose ancestor chain contains a `Node2D` that is not a `CanvasLayer`.
- Flow acceptance row 12 and the Lifecycle row with a scene test: a loss notification delivered to the adapter gives one `lifecycle_paused`, a second loss notification before a re-arm gives none, a `size_changed` gives one `viewport_resized` and no `lifecycle_paused` (TR-state-010, TR-input-004).
- D1 to D10 results retained under `production/qa/evidence/adr-0003-device-run/`; QQ-22 closes when D1 to D4 pass on both platforms.
- The ADR is wrong if D1 shows events delivered after the frame's `_process` on a device, or D3 shows `_input` missing the moves of a live gesture under a STOP Control.

## NOT SOURCEABLE
These are not covered by `docs/engine-reference/godot/` or the spike, are not asserted anywhere above, and are all under Verification Required.
- NOT SOURCEABLE: `DisplayServer.get_display_safe_area()` space, units and origin on Android and iOS, and what Android edge-to-edge reports.
- NOT SOURCEABLE: whether `NOTIFICATION_APPLICATION_PAUSED` and `_RESUMED` arrive on Android and iOS, and which of 2017, 1005 and 2015 fire for each cause.
- NOT SOURCEABLE: `InputEventScreenTouch.index` assignment and reuse on real devices, and when `canceled` is set (the property exists; the spike only read it).
- NOT SOURCEABLE: the value an absent `display/window/stretch/*` key resolves to in an existing 4.7 project (the reference covers only new-project defaults), which is why the keys are written explicitly.
- NOT SOURCEABLE: the behaviour of stretch aspect modes other than `keep` on a taller or wider window (`keep_width`, `expand`), and any field-origin offset.
- NOT SOURCEABLE: how to read the window width in dp, and how to decide at runtime that the device is a phone.
- NOT SOURCEABLE: behaviour with `emulate_mouse_from_touch` off, whether non-left buttons emit emulated touches, whether built-in widgets respond to touch with it off, and the 4.7 name of the `agile_event_flushing` setting.
- NOT SOURCEABLE: the role of `get_canvas_transform()` under stretch (values not recorded), and when a lifecycle notification is dispatched relative to `_process`.

## Related
- `docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md`: Decisions 4 and 5, Verification item 3 (D8).
- `docs/architecture/architecture.md` v4: Data Flow 1 and 6, B2, B3, QQ-02, QQ-06, QQ-12, QQ-22.
- `design/gdd/input-gesture-resolver.md` Rules 1, 7, 10, 12; Adapter contract; Edge Cases on resize and cancel.
- `design/gdd/game-state-stage-flow.md` Rule 17; Paused state.
- `design/gdd/battle-hud.md` Rule 2; Layout and the layout checks.
- `docs/engine-reference/godot/modules/input.md`, section Verified on 4.7.2; spike `prototypes/adr-0003-spike/`.
