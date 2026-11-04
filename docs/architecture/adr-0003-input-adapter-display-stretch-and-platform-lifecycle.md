# ADR-0003: Input Adapter, Display Stretch and Platform Lifecycle

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories that reference this ADR stay `Blocked` while it is `Proposed`.
> This ADR also cannot be accepted until every item under
> "NOT SOURCEABLE (blocks Acceptance)" has a recorded spike result.

TD-ADR: batch review 2026-11-04, CONCERNS; fixes applied.

2026-11-04: TD-ADR batch review and engine check fixes applied.

Engine specialist validation: written by the Godot engine specialist against the 4.7.2 class reference; no separate specialist pass was run.

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

Godot engine specialist (author). Pending: technical-director batch review, user acceptance.

## Summary

TowerRiot needs one engine-facing node that turns Godot touch and mouse events into the resolver's five calls in 540 x 960 field units, a display setup that makes those units equal viewport units on every phone shape, and one place that turns app pause and focus loss into a cancel and a pause signal. This ADR writes `canvas_items` stretch with `keep` aspect and portrait orientation into `project.godot`, splits the adapter's event path (presses in `_unhandled_input` so modal Controls stop them, moves and releases in `_input` so no Control can hide them), reads touch events only, gives the adapter the lifecycle notifications, and starts with a device spike that settles every engine fact the reference does not state.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2.stable, installed and pinned) |
| **Domain** | Input (with UI display settings and app lifecycle) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH. 4.7 changed mouse and keyboard device IDs and the stretch values written into new projects; 4.6 split touch focus from keyboard focus; the pinned `modules/input.md` has no touch coverage; the lifecycle notifications are not in the pinned reference |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.6 to 4.7 Input and Project rows, 4.6 UI dual-focus row), `modules/input.md`, `modules/ui.md`; the official 4.7.2 class reference at `raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/`: `Viewport.xml`, `Node.xml`, `Control.xml`, `Window.xml`, `InputEvent.xml`, `InputEventScreenTouch.xml`, `InputEventScreenDrag.xml`, `Input.xml`, `DisplayServer.xml`, `ProjectSettings.xml`, `SceneTree.xml`, `OS.xml` |
| **Post-Cutoff APIs Used** | `InputEvent.DEVICE_ID_MOUSE` (32) and `DEVICE_ID_EMULATION` (-1) as 4.7 documents them; `Control.get_mouse_filter_with_override()` (4.5, used only in a test). Everything else predates the cutoff, but its behaviour on touch devices is not in the pinned reference |
| **Verification Required** | The device spike in Validation Criteria (S-1 to S-11). Every item in the list below blocks acceptance |

### Sourced facts this ADR relies on

| Fact | Source (4.7.2 class reference) |
|---|---|
| `Viewport.push_input` calls `Node._input`, then `Control._gui_input`, then `_shortcut_input`, `_unhandled_key_input`, `_unhandled_input`; a method that marks the event handled stops the later ones | `Viewport.xml`, `push_input` |
| `_unhandled_input` is "called when an InputEvent hasn't been consumed by `_input` or any GUI Control item" | `Node.xml`, `_unhandled_input` |
| `MOUSE_FILTER_STOP` (value 0) receives "mouse movement input events and mouse button input events"; "these events are automatically marked as handled". `mouse_filter` defaults to 0 (STOP) | `Control.xml`, `MOUSE_FILTER_STOP`, `mouse_filter` |
| `MOUSE_FILTER_IGNORE` does not receive mouse events and does not block other Controls | `Control.xml`, `MOUSE_FILTER_IGNORE` |
| `FOCUS_NONE`: "the node cannot grab focus" | `Control.xml`, `FOCUS_NONE` |
| `display/window/stretch/mode` default `"disabled"`; `display/window/stretch/aspect` default `"keep"`. `canvas_items` and `expand` are "the default for projects created starting in Godot 4.7" | `ProjectSettings.xml` |
| `canvas_items`: the base size "is stretched to cover the whole screen (taking aspect into account)". `keep`: "black bars will be added to the top/bottom of the screen (letterboxing) or the sides (pillarboxing)" | `ProjectSettings.xml` |
| `display/window/handheld/orientation` takes `DisplayServer.ScreenOrientation`, default 0; a portrait value "does not flip the project resolution's width and height automatically" | `ProjectSettings.xml` |
| `DisplayServer.SCREEN_PORTRAIT` is 1, "default portrait orientation" | `DisplayServer.xml` |
| `display/window/size/viewport_width` defaults to 1152; `canvas_items` uses it as the stretch reference | `ProjectSettings.xml` |
| `input_devices/pointing/emulate_mouse_from_touch` defaults to `true` ("sends mouse input events when tapping or swiping on the touchscreen"); `emulate_touch_from_mouse` defaults to `false` ("sends touch input events when clicking or dragging the mouse") | `ProjectSettings.xml` |
| `InputEvent.DEVICE_ID_EMULATION` is -1, "used for emulated mouse input from a touchscreen, or for emulated touch input from a mouse"; `DEVICE_ID_MOUSE` is 32 | `InputEvent.xml` |
| `InputEventScreenTouch.canceled`: "the touch event has been canceled". `position`: "the touch position in the viewport the node is in, using the coordinate system of this viewport" | `InputEventScreenTouch.xml` |
| `DisplayServer.get_display_safe_area()` returns `Rect2i`, "the unobscured area of the display where interactive controls should be rendered", implemented on Android and iOS only; elsewhere it returns `screen_get_usable_rect(SCREEN_OF_MAIN_WINDOW)` | `DisplayServer.xml` |
| `DisplayServer.window_get_size()` returns `Vector2i` in pixels, the client area | `DisplayServer.xml` |
| `screen_get_scale()` is implemented on Android, iOS, Web, macOS and Linux (Wayland); 1.0 elsewhere | `DisplayServer.xml` |
| `NOTIFICATION_APPLICATION_FOCUS_OUT` (2017) and `FOCUS_IN` (2016): focus moves between the Godot instance and the OS or another app; desktop and mobile | `Node.xml` |
| `NOTIFICATION_APPLICATION_PAUSED` (2015) and `RESUMED` (2014): Android and iOS only; on iOS a task started by PAUSED has about 5 seconds | `Node.xml` |
| `NOTIFICATION_WM_WINDOW_FOCUS_OUT` (1005) also fires between two windows of the same instance | `Node.xml` |
| `PROCESS_MODE_ALWAYS` (3): "keeps processing, ignoring `SceneTree.paused`" | `Node.xml` |
| `SceneTree.paused` may stop `_process`, `_physics_process` and `_input`, depending on `process_mode` | `SceneTree.xml`, `paused` |
| `Viewport.size_changed` is emitted "when the size of the viewport is changed, whether by resizing of window, or some other means" | `Viewport.xml` |
| `Window.focus_exited` is emitted when the Window loses focus | `Window.xml` |
| `input_devices/buffering/agile_event_flushing` defaults to `false`: events are "flushed only once per process frame, between iterations of the engine"; implemented only on Android | `ProjectSettings.xml` |
| `Input.use_accumulated_input` is on by default and merges similar events in a frame | `Input.xml` |

### NOT SOURCEABLE (blocks Acceptance)

Each item names the spike run (Validation Criteria) that settles it.

- NOT SOURCEABLE: that OS-delivered touch and mouse events follow the `push_input` order (`_input`, then `_gui_input`, then `_unhandled_input`). The reference states the order for `push_input` only. Settled by **S-1** (Android, iOS, desktop export).
- NOT SOURCEABLE: that events flushed for a frame are dispatched before that frame's `_process`. The reference states when events are flushed, not their order against `_process`. Settled by **S-1**.
- NOT SOURCEABLE: when Android and iOS set `canceled` on a touch (edge back gesture, notification shade, incoming call, focus loss), and that a canceled touch arrives with `pressed == false`. Settled by **S-2** (Android, iOS).
- NOT SOURCEABLE: whether a `MOUSE_FILTER_STOP` Control consumes an `InputEventScreenTouch` press, so it never reaches `_unhandled_input`. `Control.xml` documents STOP for mouse events only. Settled by **S-3** (Android, iOS, desktop export with mouse).
- NOT SOURCEABLE: which events a STOP Control's `_gui_input` receives for one phone tap and one desktop click (touch, emulated mouse, or both, and their order). Settled by **S-4** (Android, iOS, desktop export).
- NOT SOURCEABLE: how many events one physical phone press produces under the emulation settings, and their `device` values; that an emulated touch from a desktop mouse carries `device == -1`; which mouse buttons `emulate_touch_from_mouse` turns into touch (right and middle). Settled by **S-5** (Android, desktop export).
- NOT SOURCEABLE: that `InputEventScreenTouch.position` reaches the adapter in base 540 x 960 coordinates under `canvas_items` and `keep`, and that a press in a letterbox bar reports a position outside 0 to 960. Settled by **S-6** (a 9:19.5 phone and a 4:3 window).
- NOT SOURCEABLE: the coordinate space of `get_display_safe_area()` on Android and iOS (screen or window pixels), and the feature tag names `"android"` and `"ios"` used to detect them (they are in the feature-tags tutorial, not the class reference). Settled by **S-7** (notched Android, notched iOS).
- NOT SOURCEABLE: which of `NOTIFICATION_APPLICATION_FOCUS_OUT`, `_PAUSED`, `_FOCUS_IN` and `_RESUMED` reach a non-root child node such as the adapter through `_notification`, in what order, and whether both FOCUS_OUT and PAUSED always fire on backgrounding; whether a click on the editor debugger fires FOCUS_OUT; whether the refocusing click on desktop also arrives as a press. Settled by **S-8** (Android, iOS, desktop export, editor run).
- NOT SOURCEABLE: what arrives on return from background for a finger held across it (a release, a `canceled` touch or nothing). Settled by **S-9** (Android, iOS).
- NOT SOURCEABLE: a reliable dp source for the 360 dp guard (`window_get_size().x / screen_get_scale()` against the OS's own dp width). Settled by **S-10** (two Android phones of different density, one iOS phone).
- NOT SOURCEABLE: that CanvasItems drawn outside the 540 x 960 base rect are not visible in the bars under `canvas_items` and `keep`. Settled by **S-11** (screenshots at 9:19.5 and 4:3).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 App Lifecycle, Composition Root and Fatal Path (no autoloads; the BattleWrapper builds and frees the adapter per battle; AppRoot cancels input on retry; the dev-error sink) |
| **Enables** | ADR-0004 (frame order rests on S-1's input-before-`_process` result), ADR-0008 (the resolver is driven only by this adapter, in field units), ADR-0011 (draws in the field space fixed here), ADR-0007 (the manual-evidence list gains S-1 to S-11) |
| **Blocks** | Every Input & Gesture Resolver adapter story; HudModals and HUD layout stories; the Flow pause story; the first phone build |
| **Ordering Note** | The spike (S-1 to S-11) runs first and is real work. ADR-0004 and ADR-0008 must not be accepted before S-1 and S-3 are recorded. The resolver API the adapter calls is the one in architecture B2; this ADR does not depend on ADR-0008, because ADR-0008 depends on it. The `edge_reject_margin` value comes from the Input record (ADR-0002), but the adapter takes a plain `float`, so the catalogue format does not affect it |

## Context

### Problem Statement

The Input & Gesture Resolver is a pure object. It is correct only if one adapter node keeps a contract: every press it forwards is followed by a release, `cancel_pointer` or `cancel()` for that index, and the first closes it, whatever Controls lie under the finger. At the same time the Result and Paused screens are Controls that must stop presses before the adapter sees them (Battle HUD Rule 2). Every position must be in 540 x 960 field units, but `project.godot` has no display keys, so today the base size is the 1152 x 648 default and stretch is the `disabled` default. Phones are taller than 9:16 and have notches and gesture areas. Losing focus or backgrounding must pause the game. None of the touch, safe-area or lifecycle behaviour is in the pinned engine reference.

### Current State

`project.godot` holds `config/name`, `config/features` and `renderer/rendering_method="mobile"`. It has no `[display]` and no `[input_devices]` section. No input code exists.

### Constraints

- No autoloads (ADR-0001). The BattleWrapper builds the adapter per battle and frees it on retry.
- The resolver never sees an `InputEvent`, a viewport or a clock (architecture B2).
- The adapter, not AppRoot and not Flow, receives the lifecycle notifications (architecture B3 and Data Flow 6; Input Rule 7).
- Pause is Flow's PAUSED phase plus the in-sim tick gate inside `Battle.tick`. The game never sets `SceneTree.paused` (architecture Data Flow 6).
- HUD insets stay fixed for a battle until the Mobile Platform GDD (Battle HUD Edge Cases).
- Engine facts come from the 4.7.2 class reference or a device run, never memory.

### Requirements

- One event family reaches the resolver; one physical press gives one gesture on touch and mouse.
- A Control under a moving finger never hides the active pointer's move or release.
- Modal screens stop new presses before the adapter.
- An OS touch-cancel never becomes a release.
- Field units equal viewport units on every screen shape; nothing outside the field is visible.
- Insets in field units for the adapter and the HUD; zero on desktop.
- Focus loss and backgrounding cancel input and pause; a resize cancels without pausing.

## Decision

### 1. `project.godot` keys

The first implementation story of this ADR writes exactly these keys. No other key changes.

```ini
[display]

window/size/viewport_width=540
window/size/viewport_height=960
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/handheld/orientation=1

[input_devices]

pointing/emulate_touch_from_mouse=true
```

- The setting defaults are `disabled` and `keep`; 4.7 writes `canvas_items` and `expand` only into new projects. This project was created without them, so writing both keys removes any doubt about what an unset key means.
- `canvas_items` renders at the target resolution and keeps one coordinate space for drawing and input. `keep` letterboxes rather than revealing more world, which `expand` would do.
- `orientation=1` is `SCREEN_PORTRAIT`. Width 540 and height 960 are written explicitly, because a portrait value does not flip them.
- `emulate_touch_from_mouse=true` turns a desktop mouse into touch events, so desktop runs the phone code path. `emulate_mouse_from_touch` stays at its default `true`.
- `stretch/scale` and `stretch/scale_mode` stay at their defaults. No code changes stretch settings at runtime.

**Tall and wide screens (QQ-02).** On a phone taller than 9:16 the field fits the width and bars appear above and below. On a screen wider than 9:16 it fits the height and bars appear at the sides. The bars are not scene content, so no mask code exists, and the off-field entry and exit (layout rule L5) are never revealed (S-11 confirms).

**Minimum width.** 360 dp, where a 72-unit target is 48 dp. A runtime guard computes `width_dp = window_get_size().x / screen_get_scale()` once at battle build and logs through the dev-error sink when it is below 360. It never blocks play. The store listing's device filter does the excluding (Input Edge Cases). Whether that dp formula is right is S-10; until then the guard is advisory.

### 2. One coordinate space

- The battle scene has no `Camera2D` and leaves the root viewport's `canvas_transform` at identity.
- Under Decision 1, `InputEventScreenTouch.position` and `InputEventScreenDrag.position` are in field units. The adapter forwards them unchanged. It never uses `relative` or `velocity`.
- A press in a letterbox bar arrives outside 0 to 540 or 0 to 960. The edge and inset check (Decision 5) rejects a side-bar press; a top or bottom bar press falls inside the inset band or is hit-tested unmodified, which the Input GDD allows.

### 3. The event path is split

The adapter reads two callbacks and never calls `Viewport.set_input_as_handled()`.

| Callback | Events it acts on | Why |
|---|---|---|
| `_unhandled_input` | `InputEventScreenTouch` with `pressed == true` | A modal Control (`MOUSE_FILTER_STOP`) under the finger handles the press first, so a tap on Result or Paused never reaches a disc (TR-hud-002, TR-input-013) |
| `_input` | `InputEventScreenDrag`, and `InputEventScreenTouch` with `pressed == false`, for pointers the adapter has open | `_input` runs before any Control, so a Control that appears under a moving finger cannot hide the move or the release (TR-input-003) |

The adapter keeps a set of open pointers. A press it forwards opens that pointer. In `_input`, events for a pointer that is not open are ignored, so a press a modal consumed never has its release forwarded. A release or `cancel_pointer` closes the pointer; `cancel()` closes all.

| Event | Condition | Call |
|---|---|---|
| `InputEventScreenTouch` in `_unhandled_input` | `pressed == true`, passes Decision 5 | `press(pointer, position)`, pointer opened |
| `InputEventScreenTouch` in `_input` | `pressed == false`, `canceled == true`, pointer open | `cancel_pointer(pointer)`, pointer closed |
| `InputEventScreenTouch` in `_input` | `pressed == false`, `canceled == false`, pointer open | `release(pointer, position)`, pointer closed |
| `InputEventScreenDrag` in `_input` | pointer open | `move(pointer, position)` |
| anything else | | ignored |

`canceled` is checked before `pressed == false` is read as a release. A release is never made up from a cancel, a resize or a lifecycle event. `double_tap` is ignored.

**If S-3 fails** (a touch press passes a STOP Control and reaches `_unhandled_input`), the adapter gains `set_press_gate(open: bool)`. The wrapper connects HudLogic's `modal_changed(kind)` to it: any kind but none drops every new press until none. Moves and releases are unchanged. This is the only fallback, and it is chosen here so the spike result only switches it on.

### 4. Touch and mouse: one event family

- The adapter handles `InputEventScreenTouch` and `InputEventScreenDrag` only. It ignores every `InputEventMouse*` event. A real mouse reaches it as emulated touch; a phone's emulated mouse events are left to Controls.
- Pointer numbers come from one pure helper, `PointerMap.pointer_of(event)`, shared with HudModals so both number pointers the same way:
  - a touch event with `device == InputEvent.DEVICE_ID_EMULATION` (-1) is emulated from a mouse and gets `PointerMap.MOUSE_POINTER` (-2), so it never collides with touch index 0;
  - any other touch event gets its `index`.
- No code compares `event.device` to `0`. The 4.7 mouse ID is `DEVICE_ID_MOUSE` (32); classify by event type and the two constants.
- Non-left mouse buttons must never reach the resolver (TR-input-005). If S-5 shows right or middle clicks become touch, the adapter also reads `InputEventMouseButton` in `_input`, only to hold a "non-left button down" flag, and drops emulated-touch presses while it is set.
- HudModals read their own events in `_gui_input` with `PointerMap`, and S-4 decides which family they act on. If a STOP Control receives both a touch event and an emulated mouse event for one tap, it acts on the touch event and ignores `InputEventMouse*` with `device == -1`, so one press gives one `modal_press`.

### 5. Edge and inset rejection

On a press only, the adapter drops the event when `x < edge_reject_margin + I_left`, `x > 540 - edge_reject_margin - I_right`, `y < I_top` or `y > 960 - I_bottom`. A dropped press opens no pointer, so its moves and release are ignored. A drag that began elsewhere and moves into a zone is forwarded (Input Rule 12). HudLogic's modal press model applies the same rule with the same injected values (TR-hud-003).

**`FieldInsets`.** One pure helper turns the window size and safe area into field-unit insets:

```
W, H       = window size in pixels
scale      = min(W / 540, H / 960)                       # keep: uniform fit
ox, oy     = (W - 540 * scale) / 2, (H - 960 * scale) / 2  # bar sizes in pixels
S          = DisplayServer.get_display_safe_area()        # Rect2i
I_top      = clamp(max(0, S.position.y - oy) / scale, 0, 102)
I_bottom   = clamp(max(0, (oy + 960 * scale) - S.end.y) / scale, 0, 72)
I_left     = clamp(max(0, S.position.x - ox) / scale, 0, 48)
I_right    = clamp(max(0, (ox + 540 * scale) - S.end.x) / scale, 0, 48)
```

- Only the part of a notch or gesture area that reaches into the field counts; a cutout that fits in a bar gives 0.
- The clamps are the layout limits the GDDs assume: 102 (L6, the top band), 72 (`burst_y` and the Won panel's `B`), 48 (the `edge_reject_margin` domain maximum). A clamp that bites is logged with the raw value, and the content rules need a recheck for that device.
- On desktop, `get_display_safe_area()` returns the usable screen rect, not the window, so `FieldInsets` returns 0 for all four unless the platform is Android or iOS.
- The wrapper computes `FieldInsets` once at battle build and injects the same object into the adapter and HudLogic. Insets stay fixed for the battle (Battle HUD Edge Cases); a resize cancels input but does not recompute them until the Mobile Platform GDD says otherwise.
- `burst_y = clamp(888 - I_bottom, 816, 888)` stays HudLogic's; the sim never reads insets.

### 6. Lifecycle, pause and resize

- **Receiver.** The adapter overrides `_notification` and is the only node that acts on lifecycle notifications.
- **Pause triggers.** `NOTIFICATION_APPLICATION_FOCUS_OUT` (desktop and mobile) and `NOTIFICATION_APPLICATION_PAUSED` (Android and iOS). Each calls `resolver.cancel()`, closes all open pointers, then emits `lifecycle_paused()`. The adapter emits it once per episode: a latch set on the first trigger is cleared by `NOTIFICATION_APPLICATION_FOCUS_IN` or `_RESUMED`. Neither FOCUS_IN nor RESUMED resumes the game; only the tap on the Paused screen does (Flow Rule 17).
- **Not used.** `NOTIFICATION_WM_WINDOW_FOCUS_OUT`, because it also fires between two windows of the same instance (the editor's embedded game window included).
- **Wiring.** The wrapper connects `lifecycle_paused` to Flow's pause command (`pause()`, name proposed in QQ-18) and to `HudLogic.modal_cancel()`. Flow enters PAUSED, calls the injected `cancel_input()` (which finds Idle), emits `phase_changed(PAUSED)`, and the BattleWrapper zeroes its accumulator. Pausing a terminal state does nothing (Flow's rule).
- **Pause mechanism.** The game never sets `SceneTree.paused`. The adapter still runs `PROCESS_MODE_ALWAYS` (TR-input-004), so a later tree pause, if one is ever added, cannot strand a gesture.
- **Resize.** The adapter connects its viewport's `size_changed` in `_ready`. On it, it calls `resolver.cancel()`, closes all pointers and emits `viewport_resized()`, which the wrapper connects to `HudLogic.modal_cancel()` only. A resize never pauses.
- **iOS budget.** The PAUSED handler makes two calls and does no I/O, well inside the roughly 5 seconds iOS allows.
- **Editor.** FOCUS_OUT also pauses in the editor, so the path is proven on desktop before the first phone build (Flow Rule 17). A click on the debugger may pause the game; one tap resumes. S-8 records whether that click fires FOCUS_OUT and whether the refocusing click also arrives as a press; either outcome is acceptable to Flow Rule 17.
- **Fallback.** If S-8 shows the application notifications do not reach a child node, the adapter connects `get_window().focus_exited` for focus loss, and a revision of this ADR picks the PAUSED path. Handlers are not scattered across other nodes.

### 7. Frame order

The adapter has no `_process`. It acts only inside input callbacks, so commands it triggers run before that frame's ticks if events are dispatched before `_process` (S-1). This ADR leaves `agile_event_flushing` and `use_accumulated_input` at their defaults. Accumulation can merge several drags into one `move`; the resolver needs only the latest position, so that is fine. ADR-0004 owns the frame order that rests on S-1.

### 8. Controls

- Every battle Control that is not a modal sets its own `mouse_filter = MOUSE_FILTER_IGNORE`. The default is STOP, so a forgotten container would swallow presses meant for discs. A test asserts `get_mouse_filter_with_override() == MOUSE_FILTER_IGNORE` on each.
- HudModals' full-screen Controls keep `MOUSE_FILTER_STOP` and set `focus_mode = FOCUS_NONE`. They are built once, toggled visible, and only hidden inside their own handler, never freed (TR-hud-002).
- No battle Control takes keyboard focus. There is no keyboard or gamepad path at MVP.

### Architecture Diagram

```
 OS touch                desktop mouse
    │                        │ emulate_touch_from_mouse=true  (touch, device -1, pointer -2)
    ▼                        ▼
 root Viewport (540 x 960, canvas_items, keep, portrait, no Camera2D)
   1. Node._input ─────────▶ InputAdapter  [moves, releases, cancels of OPEN pointers]
   2. Control._gui_input ──▶ HudModals (STOP, FOCUS_NONE) ──▶ HudLogic.modal_*
                             HudTopBand (IGNORE)
   3. Node._unhandled_input ▶ InputAdapter  [presses: edge + inset check, open pointer]
                                   │
                                   ▼ press / move / release / cancel_pointer / cancel
                              InputResolver ──▶ gesture signals ──▶ HeroInput, TowerInput, HudLogic

 InputAdapter._notification:
   APPLICATION_FOCUS_OUT | APPLICATION_PAUSED ─▶ resolver.cancel(); emit lifecycle_paused (once)
        lifecycle_paused ─▶ Flow.pause() ; HudLogic.modal_cancel()   (wired by the wrapper)
   APPLICATION_FOCUS_IN | APPLICATION_RESUMED ─▶ clear the once-latch (no resume)
 Viewport.size_changed ─▶ resolver.cancel(); emit viewport_resized ─▶ HudLogic.modal_cancel()

 Wrapper at build: FieldInsets.compute(window_get_size(), get_display_safe_area(), is_handheld)
                   ─▶ InputAdapter.setup(...)  and  HudLogic (injected)
```

### Key Interfaces

```gdscript
class_name InputAdapter extends Node
## The only engine-facing input code. Built per battle by the BattleWrapper, freed on retry.
## process_mode = PROCESS_MODE_ALWAYS. Never calls set_input_as_handled().

## Pause and focus loss only. The wrapper connects it to Flow's pause command and HudLogic.modal_cancel().
signal lifecycle_paused()
## A viewport resize. Cancels input without pausing. Connected to HudLogic.modal_cancel() only.
signal viewport_resized()

## Call before add_child. Holds the resolver for the battle's life.
func setup(resolver: InputResolver, edge_reject_margin: float, insets: FieldInsets) -> void
## Fallback only, enabled if spike S-3 fails. true drops new presses; moves and releases still pass.
func set_press_gate(open: bool) -> void

func _input(event: InputEvent) -> void            # moves and releases of open pointers
func _unhandled_input(event: InputEvent) -> void  # presses
func _notification(what: int) -> void             # lifecycle
```

```gdscript
class_name PointerMap extends RefCounted
## Pure. Shared by InputAdapter and HudModals.
const MOUSE_POINTER := -2   # emulated touch from a desktop mouse
const NOT_A_POINTER := -3   # an event this game does not read as a pointer

## Touch with device DEVICE_ID_EMULATION -> MOUSE_POINTER; other touch -> its index; else NOT_A_POINTER.
static func pointer_of(event: InputEvent) -> int
```

```gdscript
class_name FieldInsets extends RefCounted
## Pure. Field-unit insets for one battle. Built by the BattleWrapper, read by the adapter and HudLogic.
const FIELD_SIZE := Vector2(540.0, 960.0)
const MAX_TOP := 102.0
const MAX_BOTTOM := 72.0
const MAX_SIDE := 48.0

var top: float
var bottom: float
var left: float
var right: float
var clamped: bool           # true when any raw inset exceeded its maximum

## window_px from DisplayServer.window_get_size(); safe_px from get_display_safe_area().
## is_handheld false returns all zeros (desktop fallback is the screen, not the window).
static func compute(window_px: Vector2i, safe_px: Rect2i, is_handheld: bool) -> FieldInsets
static func zero() -> FieldInsets
## The 360 dp guard. Advisory; the dp source is spike S-10.
static func width_dp(window_px_width: int, screen_scale: float) -> float
```

The resolver interface is architecture B2, unchanged.

### Implementation Guidelines

- `project.godot` **must** carry the five `[display]` keys and the one `[input_devices]` key in Decision 1. Code **must never** change stretch settings at runtime.
- The battle scene **must not** contain a `Camera2D` and **must not** change the root viewport's `canvas_transform`.
- The adapter **must** read presses only in `_unhandled_input`, and moves, releases and cancels only in `_input`, and only for pointers it has open.
- The adapter **must never** call `set_input_as_handled()`, use `Input` polling, or override `_gui_input`.
- The adapter **must** act only on `InputEventScreenTouch` and `InputEventScreenDrag`, except the non-left-button flag if S-5 requires it.
- Code **must never** compare `event.device` to `0`. Pointer numbers **must** come from `PointerMap.pointer_of`.
- A touch with `pressed == false` **must** be checked for `canceled` first, and a canceled touch **must** become `cancel_pointer`, never `release`.
- The adapter **must never** make up a `release`.
- The adapter **must** forward absolute `position` only, never `relative` or `velocity`.
- The adapter **must** set `process_mode = PROCESS_MODE_ALWAYS`.
- The adapter **must** be the only node that acts on `NOTIFICATION_APPLICATION_*`. It **must not** act on `NOTIFICATION_WM_WINDOW_FOCUS_OUT`.
- The game **must never** set `SceneTree.paused`.
- Only `FieldInsets` and the wrapper's one build-time call **may** read window pixels, `screen_get_scale` or `get_display_safe_area`. `FieldInsets.compute` **must** stay a pure static function.
- The sim **must never** read `FieldInsets`.
- Every non-modal battle Control **must** set its own `mouse_filter = MOUSE_FILTER_IGNORE`. Every battle Control **must** set `focus_mode = FOCUS_NONE`.
- No mask node, scrim or clip **may** be added to hide off-field drawing unless S-11 fails.

## Alternatives Considered

### Alternative 1: All events in `_unhandled_input`

- **Description**: The adapter reads presses, moves and releases in `_unhandled_input`, and Controls consume first.
- **Pros**: One callback; the engine does all modal blocking.
- **Cons**: `_unhandled_input` is skipped for events a Control consumed. A Result panel that appears under a hero drag would take the release and strand the gesture, which the adapter contract forbids. The resolver has no clock and cannot recover.
- **Rejection Reason**: It breaks TR-input-003 by construction.

### Alternative 2: All events in `_input` with a modal gate as the main path

- **Description**: The adapter sees every event first and drops presses while a modal shows, through a flag the wrapper sets from `modal_changed`.
- **Pros**: Independent of whether a STOP Control consumes touch.
- **Cons**: The modal Controls would no longer stop presses before the adapter, which TR-hud-002, TR-input-013 and Battle HUD Rule 2 require. It adds adapter state the engine should provide.
- **Rejection Reason**: It contradicts the architecture and the HUD GDD. It is kept as the S-3 fallback (`set_press_gate`), not the main path.

### Alternative 3: Two event families, mouse on its own pointer

- **Description**: Leave `emulate_touch_from_mouse` off; read `InputEventMouseButton` (left only) and `InputEventMouseMotion` directly, and filter phone-emulated mouse events by `device == -1`.
- **Pros**: Non-left buttons are filtered in code without a spike.
- **Cons**: Two code paths and two test matrices; TR-input-005 asks for one family. Desktop would not exercise the phone path.
- **Rejection Reason**: More code for no player benefit; the non-left case has a named fallback.

### Alternative 4: `expand` aspect, showing more world on tall phones

- **Description**: Use the 4.7 new-project value `expand`, so a tall phone shows extra space above and below the field.
- **Pros**: No black bars.
- **Cons**: Reveals the off-field entry and exit (L5) and anything else drawn outside the field. Viewport size then varies per device, so field units stop being one fixed space and every layout rule needs a recheck.
- **Rejection Reason**: The GDDs require nothing outside the field to be shown.

### Alternative 5: Lifecycle notifications on AppRoot

- **Description**: AppRoot handles the notifications and calls the adapter.
- **Pros**: One handler at the top of the tree.
- **Cons**: The architecture and the Input GDD give the adapter the lifecycle wiring and the `lifecycle_paused` signal; AppRoot would have to reach into the battle it builds.
- **Rejection Reason**: The adapter already owns `cancel()` on resize and is rebuilt per battle; keeping all three triggers in one node is simpler. AppRoot still cancels on retry.

## Consequences

### Positive

- The one-close-per-press contract holds by construction: nothing runs before `_input`.
- Modal Controls stop presses as the HUD GDD describes, with no gate state in the main path.
- Desktop and phone share one event family and one code path.
- One coordinate space; no mask code; the sim is device-independent.
- One node owns all three cancel triggers (pause, focus loss, resize).

### Negative

- The adapter keeps an open-pointer set and, if S-3 fails, a press gate.
- Bars on tall phones waste some screen.
- Desktop mouse behaviour depends on `emulate_touch_from_mouse`, whose button mapping the reference does not state (S-5).
- The editor pauses on focus loss, which interrupts debugging.

### Neutral

- `emulate_mouse_from_touch` stays at its default, so Controls get emulated mouse events on phones.

## Risks

- **OS events do not follow the `push_input` order (S-1).** Mitigation: if Controls run before `_input`, the split still holds for presses; moves and releases then need a `cancel()` on every modal open, which HudLogic's `modal_changed` can drive. A revision of this ADR records it.
- **A STOP Control does not consume a touch press (S-3).** Mitigation: `set_press_gate`, already specified.
- **Notifications do not reach a child node (S-8).** Mitigation: `Window.focus_exited` for focus loss; a revision picks the PAUSED path.
- **Safe area is in screen pixels, not window pixels (S-7).** Mitigation: `FieldInsets.compute` takes the window's screen offset as one more input; the change stays inside the helper.
- **The 36-unit edge margin is wrong on real devices.** It is a catalogue value; the phone test (Input P1) tunes it. No code change.
- **An inset larger than the clamps.** Logged; the Mobile Platform GDD owns the fix (QQ-12).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-002: one thin adapter node is the only engine-facing input code; it maps Godot touch and mouse events to the five calls in 540x960 field units | `InputAdapter` (Decisions 3 and 4); positions are field units under Decisions 1 and 2 |
| input-gesture-resolver.md | TR-input-003: every forwarded press is followed by a release or cancel for that index, and the first closes it, even under a STOP Control; `canceled` is honoured | Moves and releases read in `_input` for open pointers; `canceled` checked first (Decision 3) |
| input-gesture-resolver.md | TR-input-004: the adapter runs `PROCESS_MODE_ALWAYS` and calls `cancel()` on app pause, focus loss and viewport resize, forwarding one lifecycle signal to Game State | Decision 6: notifications on the adapter, once-latch, `size_changed`, `PROCESS_MODE_ALWAYS` |
| input-gesture-resolver.md | TR-input-005: one event family; emulation settings stop duplicate presses; the mouse pointer never collides with touch index 0; non-left buttons dropped | Decision 4: touch only, `emulate_touch_from_mouse`, `MOUSE_POINTER` -2, S-5 fallback for non-left buttons |
| input-gesture-resolver.md | TR-input-006: presses inside `edge_reject_margin` and safe-area insets via `get_display_safe_area()` are rejected, in field units | Decision 5 and `FieldInsets` |
| input-gesture-resolver.md | TR-input-013: discs are not Controls; HUD Controls consume their events before the adapter, so routing order is fixed | Presses in `_unhandled_input`; Decision 8; S-3 and its fallback |
| input-gesture-resolver.md | TR-input-016: 360 dp minimum by runtime guard; stretch keeps field units equal to viewport units, no Camera2D, `cancel()` on resize | Decisions 1, 2 and 6 |
| game-state-stage-flow.md | TR-state-010: focus loss or backgrounding enters Paused: ticks stop, input cancels, accumulator zeroed, resume tap reaches nothing beneath | Decision 6 wiring to Flow's pause; modal Paused screen stops the resume press (Decision 3) |
| battle-hud.md | TR-hud-002: Result and Paused are full-screen modal Controls, built once and toggled, that stop presses before the adapter; hidden only in their own handler | Decisions 3 and 8 |
| battle-hud.md | TR-hud-003: HudLogic's modal press model repeats the adapter's rules (edge and inset rejection, same-pointer release, lifecycle clears it) | Same `edge_reject_margin` and `FieldInsets` injected; `PointerMap` shared; `lifecycle_paused` and `viewport_resized` drive `modal_cancel()` |
| battle-hud.md | TR-hud-014: layout in 540x960 field units with insets in field units; `burst_y = clamp(888 - I_bottom, 816, 888)` | Decisions 1 and 5; `FieldInsets.bottom` clamped to 72 |

**GDD sync notes.**

- `input-gesture-resolver.md` (the "Becomes an ADR" paragraph) states that `get_display_safe_area()` returns window pixels. The reference does not say so; S-7 settles it.
- `game-state-stage-flow.md` Rule 17: the desktop refocus click is recorded by S-8, as the rule asks.
- TR-hud-002 in the registry says the modals "consume every event before the Input adapter sees it". Battle HUD Rule 2 and this ADR say they stop presses only, while moves and releases still reach the adapter. The registry wording is stricter than the GDD and needs `/architecture-review` to align it.

## Performance Implications

- **CPU**: A type check, a dictionary lookup and at most four float compares per event. Negligible.
- **Memory**: One node, one small open-pointer set, one `FieldInsets`.
- **Load Time**: One `get_display_safe_area()` call per battle build.
- **Network**: None.

## Migration Plan

No code exists. Order: run the spike (S-1 to S-11) from a throwaway probe scene under `prototypes/`, record results, revise this ADR if any fallback is switched on, then write the `project.godot` keys, `PointerMap`, `FieldInsets` and the adapter with a recording fake resolver.

**Rollback plan**: Every fallback is local. S-1 or S-3 failing changes only the adapter (and wiring of `set_press_gate`). S-7 changes only `FieldInsets.compute`. S-8 changes only the adapter's lifecycle hook. Changing aspect or stretch mode supersedes this ADR.

## Validation Criteria

### Verification spike (runs first)

A throwaway probe scene under `prototypes/input-spike/` (outside the code root) with the Decision 1 keys. It holds: a root `Node2D` drawing the field border, corner marks and a shape 40 units outside each field edge; a logging node deep in the tree that logs `_input`, `_unhandled_input` and `_notification` with the frame number from `Engine.get_process_frames()`; a full-screen STOP Control (toggleable) that logs `_gui_input`; a `_process` logger; a `size_changed` logger; and an on-screen readout of `window_get_size()`, `get_display_safe_area()`, `screen_get_scale()` and `FieldInsets`. Each event line logs class, `device`, `index`, `pressed`, `canceled` and `position`. Devices: one Android phone with gesture navigation and a notch, one notched iOS phone, a desktop export with a mouse, and an editor run. Logs and screenshots go to `production/qa/evidence/adr-0003-spike/`.

| Run | What it does | Pass | If it fails |
|---|---|---|---|
| **S-1** Event order | One tap and one drag with the STOP Control shown and hidden; log the callback order and the frame number against `_process` | `_input` before `_gui_input` before `_unhandled_input`; events logged before the same frame's `_process` | Risk 1 mitigation; ADR-0004 told before acceptance |
| **S-2** Touch cancel | Start a drag, then swipe from the edge (back gesture), pull the notification shade, receive a call | A `canceled == true`, `pressed == false` touch, or none; never a plain release for a cancelled touch | Record per OS; if a plain release comes, revise Decision 3 |
| **S-3** STOP consumes touch press | Tap the STOP Control on each device and with the desktop mouse | No `InputEventScreenTouch` press reaches `_unhandled_input` | Switch on `set_press_gate` |
| **S-4** What a Control receives | Same taps; log the Control's `_gui_input` | Recorded; HudModals' family chosen from it | Decision 4 last bullet applies |
| **S-5** Emulation | One phone tap; one desktop left, right and middle click | One touch press per phone tap (plus emulated mouse for Controls, device -1); left click gives a touch with device -1; right and middle give no touch | Switch on the non-left-button flag |
| **S-6** Positions | Tap the four field corners and each bar on a 9:19.5 phone and in a 4:3 window | Corners within 2 units of (0,0), (540,0), (0,960), (540,960); bar presses outside the field | Revise Decision 2 |
| **S-7** Safe area | Read the safe area on notched Android and iOS against a screenshot | Units identified; `FieldInsets` matches the visible notch and gesture areas | Revise `FieldInsets.compute` (Risk 4) |
| **S-8** Lifecycle | Home, app switcher, notification shade, incoming call on phones; alt-tab on desktop export; click the editor debugger | Which notifications reach the child node, their order; exactly one `lifecycle_paused` per episode; refocus click behaviour recorded | `Window.focus_exited` fallback; revise for PAUSED |
| **S-9** Held finger across background | Hold a finger, background, return, lift | Whatever arrives is ignored, because the pointer is closed | None needed if ignored; record it |
| **S-10** dp source | Compare `window_get_size().x / screen_get_scale()` to the OS dp width on two Android densities and one iOS phone | Within 1 dp | Pick another source; the guard stays advisory |
| **S-11** Masking | Screenshots at 9:19.5 and 4:3 | No pixel of the outside shapes visible in the bars | Add a clip, revising Decision 1 |

### Automated (gdUnit4, `tests/unit/input/`)

- Each row of the Decision 3 table, with synthetic events fed to `_input` and `_unhandled_input` and a recording fake resolver that asserts payloads.
- A release or drag for a pointer that was never opened produces no call.
- `canceled == true` with `pressed == false` produces `cancel_pointer`, never `release`.
- No `InputEventMouse*` event produces a call.
- `PointerMap.pointer_of`: a touch with device -1 gives -2; a touch with device 0 and index 0 gives 0; a mouse event gives `NOT_A_POINTER`.
- Edge and inset rejection: a press inside the margin or an inset is dropped along with its moves and release; a drag that enters a zone is forwarded.
- `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` then `_notification(NOTIFICATION_APPLICATION_PAUSED)` calls `cancel()` and emits `lifecycle_paused` exactly once; after `FOCUS_IN`, a new FOCUS_OUT emits again. `NOTIFICATION_WM_WINDOW_FOCUS_OUT` does nothing.
- A `size_changed` emit calls `cancel()` and emits `viewport_resized`, not `lifecycle_paused`.
- `FieldInsets.compute(Vector2i(1080, 2340), Rect2i(0, 120, 1080, 2100), true)` gives top 0 and bottom 0 (bars of 210 px, scale 2.0); with the safe area starting at y 300 it gives top 45; `is_handheld == false` gives all zeros; raw insets above 102, 72 and 48 clamp and set `clamped`.
- Every non-modal battle Control returns `MOUSE_FILTER_IGNORE` from `get_mouse_filter_with_override()`.

### Manual evidence (ADR-0007 list)

S-1 to S-11 above, plus Battle HUD criterion 40 and the Rule 2 row of its evidence table: a press held across a screen change or focus loss does not fire a Control, and one physical press gives one `modal_press` with a stable index, on mouse and touch.

## Related

- ADR-0001 App Lifecycle, Composition Root and Fatal Path (depends on)
- ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism (relies on S-1)
- ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint (manual-evidence list)
- ADR-0008 Input Resolver Core and Signal Contract (driven by this adapter)
- ADR-0011 Battle Field Rendering and Draw-Call Budget (draws in this field space)
- `design/gdd/input-gesture-resolver.md` (Rules 7, 10, 12; Adapter contract; Formulas `field_scale`, `target_ok`)
- `design/gdd/battle-hud.md` (Rule 2, Rule 17, Layout, `burst_y`)
- `design/gdd/game-state-stage-flow.md` (Rules 10, 15, 17)
- `design/gdd/enemy-wave.md` (Layout rules L5, L6)
- `docs/architecture/architecture.md` (Engine Knowledge Gap Summary; B2, B3; Data Flow 1 and 6; QQ-02, QQ-06, QQ-12)
