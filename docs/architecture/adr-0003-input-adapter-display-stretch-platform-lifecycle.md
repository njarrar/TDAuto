# ADR-0003: Input Adapter, Display Stretch and Platform Lifecycle

## Status
Proposed

## Date
2026-11-03

## Last Verified
2026-11-03 (against `docs/engine-reference/godot/` for Godot 4.7.2, `docs/architecture/architecture.md` v3 and ADR-0001 Proposed). No device run yet: every row marked **[spike Sn]** is unverified until task S0 below passes.

## Decision Makers
- Author: `/architecture-decision`, run in autonomous mode (decisions logged in `production/session-logs/decision-log.md`)
- Engine specialist (godot-specialist): NOT ASSESSED in this run. See Validation Criteria, "Reviews still owed".
- Technical director (TD-ADR): NOT ASSESSED in this run. See Validation Criteria, "Reviews still owed".
- Acceptance: the user, after spike S0 has run and its results are written into this ADR.

## Summary
The pure input resolver needs one engine-facing node that turns Godot touch and mouse events into its five calls in 540x960 field units, never strands a gesture, keeps modal screens from leaking taps to the field, and pauses the battle when the app loses focus; none of the engine behaviour this rests on is in the pinned reference. This ADR decides a `canvas_items` + `keep` letterbox stretch at a 540x960 viewport, an `InputAdapter` that reads presses in `_unhandled_input` and tracked moves and releases in `_input`, a modal press gate, one event family with emulated events dropped, a union of three lifecycle notifications, safe-area insets sampled once per battle on mobile only, and a device spike (task S0) with pass/fail checks that runs before the first input story.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Input (with UI and display, and app lifecycle) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH. VERSION.md rates 4.5 to 4.7 HIGH; architecture.md rates Input, UI and display, and App lifecycle HIGH for this project. `modules/input.md` has no touch coverage, and the pinned reference names no lifecycle notification and no safe-area API. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md`, `modules/ui.md`; `docs/architecture/architecture.md` v3 (Engine Knowledge Gap Summary, Module Ownership, Data Flow 1, 5, 6, B2, B3, What cannot be tested headless, Required ADRs, QQ-02, QQ-06, QQ-20); `docs/architecture/tr-registry.yaml`; ADR-0001; `docs/registry/architecture.yaml` |
| **Post-Cutoff APIs Used** | Checked in the pinned reference: `InputEvent.DEVICE_ID_MOUSE` (4.7, not compared against; the adapter identifies events by class), the `event.device == 0` ban (4.7), the 4.7 stretch defaults for new projects (`canvas_items` / `expand`, which this ADR overrides with explicit keys), 4.6 dual focus (avoided: every Control here has `focus_mode = FOCUS_NONE`), 4.5 recursive Control mouse disable (optional helper). **Not in the pinned reference, cannot be checked offline**: `InputEvent.DEVICE_ID_EMULATION`, `InputEventScreenTouch.canceled`, `DisplayServer.get_display_safe_area()`, `DisplayServer.screen_get_dpi()`, `Node.NOTIFICATION_APPLICATION_FOCUS_OUT` / `_FOCUS_IN` / `_PAUSED` / `_RESUMED`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT` / `_IN`, the `input_devices/pointing/*` and `input_devices/buffering/agile_event_flushing` setting names. These exist in Godot 4.x from memory; each has a spike check below. |
| **Verification Required** | Task S0 (checks S1 to S9). Until S0 passes, no input story may close. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed). It fixes who builds and frees the adapter (the `BattleWrapper`), the teardown order, and the three `cancel()` callers. This ADR cannot be Accepted before ADR-0001 is. |
| **Enables** | ADR-0004 (frame order and the claim that input runs before the frame's ticks rest on check S1), ADR-0008 (resolver core; this ADR fixes the five calls' caller and its contract), ADR-0011 (draw budget; this ADR fixes the stretch and viewport size), the Mobile Platform & Performance GDD (Vertical Slice; inherits stretch, safe area and minimum size from here) |
| **Blocks** | No epic or story exists yet (`production/` holds none), so no story is blocked by path today. Once `/create-epics` runs, any story that builds the `InputAdapter`, a modal screen, the display settings in `project.godot`, the safe-area insets or the pause path waits for this ADR to be Accepted. |
| **Ordering Note** | Task S0 is the first piece of work under this ADR, before any input story and before ADR-0004 is Accepted. architecture.md Priority: "Treat that spike as real work, not paperwork." |

## Context

### Problem Statement
The Input & Gesture Resolver GDD defines a pure resolver with five calls and leaves "the mapping of engine events to the five calls" to this ADR. The Battle HUD GDD needs modal Controls that block the field and a safe-area inset for its layout. The Game State GDD needs focus loss to enter Paused. All three name engine behaviour the pinned reference does not cover: event order against `_process` and Controls, touch fields, emulation, lifecycle notifications, safe area, and the stretch mode, which `project.godot` does not set at all.

This must be fixed before code, because ADR-0004 (frame order) and ADR-0008 (resolver) both lean on what the adapter guarantees, and because the HUD layout, every field-unit conversion and the hit-target size rule depend on the stretch mode.

### Current State
No code. `project.godot` sets only the name, the 4.7 and Mobile features and the mobile renderer: no `[display]` and no `[input_devices]` section. 4.7 changed the stretch defaults for new projects, and whether a key absent from this file reads as the old or the new default cannot be checked offline. ADR-0001 (Proposed) puts the adapter in the `BattleWrapper` and lists it as one of three `cancel()` callers.

### Constraints
- **Engine**: Godot 4.7.2, single main thread. No device is available to this ADR's author, so every engine claim not in the pinned reference is written as a decision that holds under either answer where possible, with a named check.
- **Architecture**: the resolver is pure and clock-free (B2). The adapter is the only engine-facing input code (TR-input-002). No autoloads; AppRoot never uses `SceneTree.paused` (ADR-0001). No Camera2D in the battle (TR-input-016).
- **ADR-0001 contracts**: three `cancel()` callers: the adapter (pause, focus loss, resize), Flow through the injected `cancel_input()` (Won, Lost, Paused, Fatal), and AppRoot at teardown. Teardown order: stop the clock, `resolver.cancel()`, `remove_child()` and `queue_free()` the wrapper, `battle.unwire()`, drop references. Method Callables only, no lambda or `bind()` with a sim object.
- **Team**: solo part-time developer, desktop first (MVP runs at 540x960 on desktop; `commands.run` uses `--resolution 540x960`).
- **Testing**: the adapter's pure parts run headless; event order, notifications and safe area run only on a device (architecture.md, What cannot be tested headless).

### Requirements
- One thin adapter node maps touch and mouse to the five calls in field units (TR-input-002).
- Every forwarded press gets exactly one release, `cancel_pointer` or `cancel()`, even under a `mouse_filter = STOP` Control; `canceled` is honoured (TR-input-003).
- `PROCESS_MODE_ALWAYS`; `cancel()` on pause, focus loss and resize; one lifecycle signal to Flow (TR-input-004).
- One event family; no duplicate presses; the mouse index never collides with touch index 0; non-left buttons dropped (TR-input-005).
- Presses inside `edge_reject_margin` or the safe-area insets are rejected (TR-input-006).
- HUD Controls consume their events before the adapter, so routing order is fixed (TR-input-013).
- Minimum 360 dp; field units equal viewport units; no Camera2D; `cancel()` on resize (TR-input-016).
- Focus loss enters Paused, input cancels, and the resume tap reaches nothing beneath (TR-state-010).
- Result and Paused screens are modal Controls that block the field (TR-hud-002); a Control fires only on a release whose press it saw, and clears it on the lifecycle signal (TR-hud-003).
- Layout uses insets in field units; `burst_y = clamp(888 - I_bottom, 816, 888)` (TR-hud-014).

## Decision

Each item that rests on an unverified engine fact names its check as **[spike Sn]** and says what changes if the check fails.

### 0. Task S0: the device spike (first task, before any input story)
A throwaway scene under `prototypes/input_spike/` (outside the code root) that logs every input event, notification and display value to the screen and to `user://spike_log.txt`. Run on: the desktop editor build (macOS, the pinned 4.7.2), one Android phone with gesture navigation and a display cutout, and an iOS device if one is available (if not, the iOS rows are recorded NOT ASSESSED and block only an iOS export). Results go into this ADR (a new "Spike results" section, dated) and into `docs/engine-reference/godot/modules/input.md`. Each check is pass or fail; a fail switches to the named fallback and the ADR is revised before acceptance.

| Check | What to do | Pass | If it fails |
|---|---|---|---|
| **S1 Event order** | Log `Engine.get_process_frames()` in `_input`, `_unhandled_input`, `_process` and `_physics_process`; 200 taps and 50 drags on each platform | Every input callback of frame N runs before `_process` of frame N; none runs between two `_physics_process` calls of one frame with agile flushing off | ADR-0004 must not assume input precedes ticks; it queues commands and drains them at the start of `_process` |
| **S2 Emulation** | 50 taps per platform; log class and `device` of every pointer event | Android: each touch gives one `InputEventScreenTouch` with `device != DEVICE_ID_EMULATION` and one emulated `InputEventMouseButton` with `device == DEVICE_ID_EMULATION`. Desktop: mouse events have `device == DEVICE_ID_MOUSE`, no touch events. The adapter forwards exactly one press per physical press | Fallback F2: one family per platform, `OS.has_feature("mobile")` means touch only, else mouse only |
| **S3 Control consumption** | Show a full-rect `mouse_filter = STOP` Control; press on it with touch and mouse. Then press on open field, drag over the Control, release on it | (a) The press never reaches `_unhandled_input`. (b) The move and release of the open-field press reach `_input` | (a) fails: the modal press gate (Decision 2.4) becomes the only guard; record it, nothing else changes. (b) fails: impossible by Godot's documented `_input` order; if seen, the ADR is reopened |
| **S4 `canceled`** | Confirm the property name in the 4.7.2 class reference (editor F1). On Android, start a drag and pull the notification shade or swipe a system gesture mid-drag | `InputEventScreenTouch.canceled` exists. A system takeover gives `pressed = false, canceled = true` or a focus notification; neither emits `tap` or `drag_ended` | Name differs: rename in the adapter. Never observed: record "not observed"; the focus path still covers the case |
| **S5 Lifecycle** | Per platform: home, app switcher, notification shade, lock screen, incoming call (phone); alt-tab, minimise, click another window (desktop). Log every `NOTIFICATION_*` received by a node | Every case delivers at least one of `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT`, and the battle shows Paused | A case with none of the three: add the notification it does send to the adapter's set |
| **S6 Positions** | Window sizes 540x960, 720x1600 (tall) and 1080x1440 (squat); press the four field corners and a letterbox bar | Corners read (0, 0) and (540, 960) within 1 unit; a bar press reads outside 0..540 or 0..960 | Positions are window pixels: the adapter converts with `get_viewport().get_final_transform().affine_inverse()`; the rest stands |
| **S7 Safe area** | On the cutout phone, log `get_display_safe_area()`, `window_get_position()`, `window_get_size()`; screenshot and measure the cutout | Safe area and window rect share one pixel space; computed `FieldInsets` match the screenshot within 2 units | Units differ: scale by `screen_get_scale()` before `SafeAreaMath`; record the rule |
| **S8 Density** | Log `screen_get_dpi()` on the phone | `width_dp` from it is within 5% of the phone's published dp width | The size guard logs only and never blocks; the store device filter remains the real gate |
| **S9 Settings keys** | Open Project Settings in the 4.7.2 editor with Advanced on | Every key in Decision 1 exists under that exact path and reads back as written | Use the 4.7.2 name; revise this ADR's text |

### 1. Display stretch (QQ-02)
`project.godot` must set these keys explicitly, so the 4.7 new-project defaults never apply by accident **[spike S9 for the exact names]**:

```ini
[display]
window/size/viewport_width=540
window/size/viewport_height=960
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/stretch/scale_mode="fractional"
window/handheld/orientation=1        ; portrait

[input_devices]
pointing/emulate_touch_from_mouse=false
pointing/emulate_mouse_from_touch=true
buffering/agile_event_flushing=false
```

- **Mode `canvas_items`, aspect `keep`**: the 540x960 viewport is scaled uniformly by `s = min(window_w / 540, window_h / 960)` and centred. A taller phone letterboxes top and bottom; a squat screen or tablet letterboxes left and right. Field units equal viewport units with no offset, so the resolver, the HUD layout rules and `pin_exclusion` need no conversion code (TR-input-016). Positions delivered to `_input` are viewport units **[spike S6]**.
- **No Camera2D** in the battle, ever. The field root has the identity transform.
- **The taller phone letterboxes; it does not reveal the off-field entry.** On a 360x800 dp phone the bars are about 80 dp each, and they usually hold the notch and the gesture bar, so the in-field insets are often 0. Revealing more field is a Mobile Platform GDD question and needs a superseding ADR, because it breaks "field units equal viewport units".
- **Bars**: drawn by the engine outside the viewport. Their colour is cosmetic and is checked in S6's screenshot; if they are not the clear colour, the Mobile Platform GDD decides.
- **Minimum size guard (TR-input-016)**: under `keep` the effective scale is `dp_per_unit = s * 160 / screen_get_dpi()`, which must be at least 2/3 (a 72-unit target is then at least 48 dp). That means width at least 360 dp **and** height at least 640 dp; a width-only test would pass a squat screen whose targets fall under 48 dp. The guard runs once in `BattleWrapper._ready()` on mobile and calls the dev-error sink (`push_error`); it never blocks play, and the store listing's device filter is the real gate **[spike S8]**.
- **Tablets**: `keep` already scales a height-limited screen by height, so no scale cap is needed at MVP (closes the Input GDD's tablet question for MVP).

### 2. The InputAdapter
`InputAdapter extends Node`, built by `BattleWrapper` with the battle's resolver, the Input record's `edge_reject_margin` and the battle's `FieldInsets` (Decision 3). `process_mode = PROCESS_MODE_ALWAYS` (TR-input-004). It is the only node that reads pointer events for gameplay.

**2.1 Event path (QQ-06) [spike S1, S3].**
- **Presses** are read in `_unhandled_input()`. Godot runs `_input`, then GUI (`Control._gui_input`), then `_unhandled_input`, so a Control with `mouse_filter = STOP` under the press consumes it first and the field never hears it (TR-input-013, TR-hud-002).
- **Moves, releases and touch cancels** of a forwarded pointer are read in `_input()`, before GUI, so a STOP Control lying under a drag cannot swallow them (TR-input-003). `_input()` never forwards a press; `_unhandled_input()` never forwards anything but a press.
- The adapter never calls `set_input_as_handled()`, so it changes nothing for any other node.

**2.2 One event family (TR-input-005) [spike S2].**
- Event class decides the source: `InputEventScreenTouch` / `InputEventScreenDrag` are touch, `InputEventMouseButton` / `InputEventMouseMotion` are mouse. `event.device == 0` is never tested (4.7 ban).
- Any pointer event with `device == InputEvent.DEVICE_ID_EMULATION` is dropped. With `emulate_touch_from_mouse = false` and `emulate_mouse_from_touch = true`, a phone touch yields one real touch (forwarded) and one emulated mouse event (dropped, but still seen by Controls, so modal screens work on phones). A desktop mouse yields one real mouse event.
- Mouse maps to pointer index `MOUSE_POINTER = 1 << 16`. Touch indices are small and non-negative, so the two never collide.
- Only `MOUSE_BUTTON_LEFT` is forwarded. Other buttons, the wheel and hover motion with no forwarded press are dropped (Input Rule 10).
- Fallback F2 if S2 fails: the adapter keeps one family per platform (`OS.has_feature("mobile")`: touch only; else mouse only).

**2.3 Forwarding and the exactly-once contract (TR-input-003).**
The adapter keeps `_down: Dictionary` (pointer index to `true`) of the pointers it forwarded a press for.
- **Press** (in `_unhandled_input`): drop if the press gate is closed (2.4), if the position is outside the field `[0, 540] x [0, 960]`, or if it is in a rejected zone (Decision 3). Otherwise call `resolver.press(i, pos)` and set `_down[i]`. A press of an index already in `_down` (its release was lost) is forwarded as-is; the resolver treats it as `cancel()` then press (Input Rule 1).
- **Move** (in `_input`): forward `resolver.move(i, pos)` only if `i` is in `_down`. Positions outside the field are forwarded unclamped.
- **Release** (in `_input`): if `i` is in `_down`, erase it, then: if the event is a touch with `canceled == true`, call `resolver.cancel_pointer(i)`; otherwise `resolver.release(i, pos)` **[spike S4]**.
- **Adapter cancel**: on a lifecycle notification or a viewport resize, call `resolver.cancel()` and clear `_down`. A later move or release of a cleared index is dropped by the adapter (and would be dropped by the resolver in Idle anyway).
- **Cancels by others** (Flow's `cancel_input()`, AppRoot teardown) do not touch `_down`. The stale release that follows reaches the resolver in Idle and is dropped there (Input Edge Cases). This keeps ADR-0001's three callers unchanged: the adapter needs no hook from Flow or AppRoot.
- **Exit**: on `NOTIFICATION_EXIT_TREE` the adapter sets `_live = false` and never calls the resolver again. AppRoot has already called `resolver.cancel()` (ADR-0001 teardown step 3) before `remove_child()`, so the adapter does not cancel on exit.

**2.4 Modal press gate (TR-hud-002) [spike S3].**
`set_presses_blocked(blocked: bool)`. While blocked, every press is dropped; moves and releases of pointers already in `_down` still flow, so a drag that began before the modal still ends exactly once. The wrapper closes the gate in the same handler that shows a modal screen (Result or Paused, on `phase_changed`) and opens it when the modal hides. This holds whatever S3 finds about touch events and STOP Controls, at the cost of a few lines.

**2.5 Lifecycle (TR-input-004, TR-state-010) [spike S5].**
- `_notification(what)`: any of `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT` is "away". The first away notification of an episode calls `resolver.cancel()`, clears `_down`, then emits `lifecycle_paused()` once. Later away notifications in the same episode do nothing.
- Any of `NOTIFICATION_APPLICATION_FOCUS_IN`, `NOTIFICATION_APPLICATION_RESUMED`, `NOTIFICATION_WM_WINDOW_FOCUS_IN` ends the episode. It does **not** resume the battle. Only the Paused screen's tap resumes (Game State Rule 17).
- The union of three is chosen because which ones fire on each platform is unverified. A pause is idempotent in Flow, and a terminal phase ignores it, so an extra notification costs nothing.
- **Resize**: the adapter connects `get_viewport().size_changed` to its own method and calls `resolver.cancel()` and clears `_down`. A resize does not emit `lifecycle_paused`. Insets are not re-read (Decision 3).
- Order on focus loss: adapter `resolver.cancel()`, then `lifecycle_paused()`; the wrapper's connection calls `Flow.pause()`, which enters Paused, calls `cancel_input()` (a no-op, the resolver is already Idle) and emits `phase_changed(PAUSED)`; the wrapper shows the Paused screen and closes the press gate; the Clock zeroes its accumulator (ADR-0004). This is architecture.md Data Flow 6 with the order fixed.

**2.6 Wiring.**
The wrapper connects `adapter.lifecycle_paused` to the method Callable `battle.flow.pause` (no lambda, no `bind()`). The connection lives on the adapter, a Node, and dies when the wrapper is freed. It is not in the Builder's `Wiring` record, because the Builder never sees the adapter. An integration weakref test of the old battle must wait one frame after teardown, so the wrapper's `queue_free()` has completed.

### 3. Safe area and rejected zones (TR-input-006, TR-hud-014)
- `FieldInsets` (RefCounted, read-only by contract): `top`, `bottom`, `left`, `right` as floats in field units.
- **Desktop**: all four are 0 by rule (Input Rule 12, HUD Layout). `get_display_safe_area()` is not called, because on desktop it may report the screen's work area (taskbar), not the window's insets.
- **Mobile** (`OS.has_feature("mobile")`): `BattleWrapper` calls `SafeAreaMath.field_insets(DisplayServer.get_display_safe_area(), window_rect, Vector2(540, 960))` once when it is built, where `window_rect` is `Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())` **[spike S7]**.
- `SafeAreaMath.field_insets` is a pure static function: it computes `s` and the letterbox offsets `ox = (window_w - 540 s) / 2`, `oy = (window_h - 960 s) / 2`, the window-pixel insets of the safe rect against the window rect (clamped at 0), then `top = max(0, inset_top_px - oy) / s`, and the same for the other three sides with their own offset. An inset that lies inside a letterbox bar costs the field nothing.
- The same `FieldInsets` object is injected into the adapter and into HudLogic. The HUD uses `top` and `bottom` for its band and `burst_y` (HUD Layout); HeroInput reads `burst_button_centre()` once at registration, which is why insets are sampled once and never change mid-battle.
- **Rejected press zones** (adapter, presses only): `x < max(edge_reject_margin, left)`, `x > 540 - max(edge_reject_margin, right)`, `y < top`, `y > 960 - bottom`. A drag that began elsewhere and moves into a zone stays valid (Input Rule 12).
- **Gesture insets**: the pinned reference names no Godot API for Android system-gesture insets. `edge_reject_margin` (default 36 units) is the only side-gesture guard at MVP; check S5's gesture swipes record whether it is wide enough on the test phone.

### 4. Modal screens (TR-hud-002, TR-hud-003)
- Result and Paused screens use one small custom Control, `TapScreen extends Control`: full rect, `mouse_filter = MOUSE_FILTER_STOP`, `focus_mode = FOCUS_NONE` (so 4.6 dual focus never applies). It does not use `Button`, because how `BaseButton` clears a held press on focus loss is unverified on 4.7.
- `TapScreen._gui_input()` handles left `InputEventMouseButton` (real or emulated) and `InputEventScreenTouch`, keyed by pointer index. It records a press it saw and fires `tapped` only on the release of that same press. `clear_press()` forgets any held press. It calls `accept_event()` on every pointer event it gets.
- Buttons inside the Lost and Won panels (Retry, Play again) are `TapScreen` regions with the same rule.
- The wrapper calls `clear_press()` on every `TapScreen` when it shows one and on `lifecycle_paused`, so a thumb held across a screen change or a focus loss cannot fire it (HUD Rule 2).
- Paused resumes on `tapped` (`Flow.resume()`); the resume tap's press was consumed by the Paused screen and gated at the adapter, so it reaches nothing beneath (TR-state-010).
- **Every other Control in the wrapper** (HudTopBand and any container) has `mouse_filter = MOUSE_FILTER_IGNORE`, set on the top Control with 4.5's recursive disable or on each node. The wrapper's root is a `Node2D`, never a full-rect Control, or it would swallow every press.

### Architecture Diagram

```
OS / DisplayServer
  │ touch, mouse (emulated mouse events from touch carry DEVICE_ID_EMULATION)  [S2]
  ▼
Viewport (canvas_items + keep, 540x960)  positions in field units                [S6]
  │
  ├─ _input ────────────► InputAdapter._input:   move / release / canceled
  │                         (only pointers in _down)          ─► resolver.move / release / cancel_pointer
  ├─ GUI ───────────────► TapScreen (Result, Paused; STOP)   consumes presses   [S3]
  │                       HudTopBand (IGNORE)                 passes everything
  └─ _unhandled_input ──► InputAdapter._unhandled_input:  press
                            gate open? in field? not in a rejected zone?   ─► resolver.press

_notification: FOCUS_OUT | PAUSED | WM_WINDOW_FOCUS_OUT  (first of episode)         [S5]
  InputAdapter ─► resolver.cancel(); _down.clear() ─► lifecycle_paused()
                                                       └─► Flow.pause() ─► phase_changed(PAUSED)
                                                             └─► wrapper: show Paused, gate closed,
                                                                 clear_press(); Clock zeroes acc
Viewport.size_changed ─► InputAdapter ─► resolver.cancel(); _down.clear()

BattleWrapper._ready (mobile):  SafeAreaMath.field_insets(safe_area, window_rect) ─► FieldInsets
                                ─► InputAdapter (rejected zones), HudLogic (band, burst_y)

cancel() callers (ADR-0001): adapter (above) · Flow.cancel_input() · AppRoot teardown
```

### Key Interfaces

```gdscript
class_name InputAdapter extends Node      # process_mode = PROCESS_MODE_ALWAYS
const MOUSE_POINTER := 1 << 16
## Emitted once per away episode, after resolver.cancel(). The wrapper connects it to Flow.pause.
signal lifecycle_paused()
## Built by BattleWrapper only. insets is the battle's one FieldInsets.
func setup(resolver: InputResolver, edge_reject_margin: float, insets: FieldInsets) -> void
## Closed while a modal TapScreen shows. Drops presses only.
func set_presses_blocked(blocked: bool) -> void

class_name FieldInsets extends RefCounted   # read-only by contract
var top: float
var bottom: float
var left: float
var right: float

class_name SafeAreaMath extends RefCounted
## Pure. Window-pixel safe rect to field-unit insets under canvas_items + keep.
static func field_insets(safe_px: Rect2i, window_px: Rect2i, field: Vector2) -> FieldInsets
## Pure. dp per field unit under keep; the size guard needs >= 2.0 / 3.0.
static func dp_per_unit(window_px: Vector2i, field: Vector2, dpi: float) -> float
## Pure. True when a press at pos must be dropped.
static func is_rejected(pos: Vector2, field: Vector2, edge_reject_margin: float, insets: FieldInsets) -> bool

class_name TapScreen extends Control      # mouse_filter STOP, focus_mode FOCUS_NONE
## Fires on the release of a press this screen saw. Never on a release alone.
signal tapped()
func clear_press() -> void
```

Names are proposed by this ADR. `MOUSE_POINTER`, `set_presses_blocked`, `FieldInsets`, `SafeAreaMath` and `TapScreen` are new against architecture.md v3 B3. `lifecycle_paused` keeps B3's name and is past tense, so it is not a QQ-07 item. QQ-16 (global `class_name` collisions) may add a prefix; ADR-0007 decides.

### Implementation Guidelines
1. `project.godot` must hold every key in Decision 1 explicitly. CI fails if `display/window/stretch/mode` or `display/window/stretch/aspect` is missing or differs.
2. The `InputAdapter` must be the only node that reads pointer events for gameplay. No other gameplay or HUD node may override `_input` or `_unhandled_input` for pointer events; HUD modals use `TapScreen._gui_input` only.
3. The adapter must forward presses only from `_unhandled_input`, and moves, releases and cancels only from `_input`, and only for pointers in `_down`.
4. Code must never test `event.device == 0`. Identify the source by event class; drop `device == InputEvent.DEVICE_ID_EMULATION`.
5. Mouse must use pointer index `MOUSE_POINTER`; only the left button is forwarded.
6. A touch release with `canceled == true` must become `cancel_pointer(i)`, never `release`.
7. The adapter must never synthesise a release, and never call the resolver after `NOTIFICATION_EXIT_TREE`.
8. The battle must never contain a Camera2D, and the field root must keep the identity transform.
9. Every Control in the wrapper except `TapScreen` must have `mouse_filter = MOUSE_FILTER_IGNORE`. The wrapper root must not be a full-rect Control.
10. `TapScreen` must fire only on the release of a press it saw, and the wrapper must call `clear_press()` on show and on `lifecycle_paused`. Every Control here must have `focus_mode = FOCUS_NONE`.
11. The wrapper must close the adapter's press gate in the same handler that shows a modal, and open it when the modal hides.
12. Insets must be read once per battle, on mobile only, through `SafeAreaMath.field_insets`; desktop insets are 0. Never call `get_display_safe_area()` from the HUD or a view.
13. The lifecycle signal must be connected with a method Callable (`flow.pause`), never a lambda or `bind()` (ADR-0001 Guideline 4).
14. Nothing may set `SceneTree.paused` (ADR-0001). Pause is a Flow phase.
15. Until task S0 has passed and its results are recorded here, no story that depends on a **[spike Sn]** item may close.

## Alternatives Considered

### Alternative 1: Stretch `canvas_items` + `expand` (the 4.7 new-project default)
- **Description**: the viewport grows on the long side (540 x 1200 on a 9:20 phone); the field sits at the origin or is centred by a canvas offset.
- **Pros**: no letterbox bars; the whole screen is used; it is what a fresh 4.7 project does.
- **Cons**: field units no longer equal viewport units unless the field sits at y 0 with empty space below, which moves the burst button away from the thumb; centring needs an offset in every conversion; HUD layout rules L3, L5 to L7 and `pin_exclusion` assume a 960-unit height.
- **Rejection Reason**: breaks TR-input-016 and the HUD layout at MVP. The Mobile Platform GDD may bring it back as "reveal the off-field entry" under a superseding ADR.

### Alternative 2: Stretch `keep_width`
- **Description**: width fixed at 540; a taller screen shows more height below the field.
- **Pros**: no side bars on phones; thumbs reach the bottom.
- **Cons**: the same offset problem as `expand` for centring, and a squat screen crops nothing but still needs height logic.
- **Rejection Reason**: same as Alternative 1.

### Alternative 3: Read every event in `_input` with the adapter's own modal check
- **Description**: one callback; the adapter asks the HUD whether a modal or a Control lies under the press.
- **Pros**: one code path; does not depend on GUI order at all.
- **Cons**: the adapter must know about HUD Controls, duplicating GUI hit testing; it contradicts TR-input-013 ("HUD Controls consume their events before the adapter").
- **Rejection Reason**: the chosen split keeps the engine's order for presses and adds only a one-flag gate, which knows nothing about Controls.

### Alternative 4: Adapter as a full-rect Control with `mouse_filter = PASS`, using `_gui_input`
- **Description**: put the adapter at the bottom of the GUI so Controls above it occlude it naturally.
- **Pros**: occlusion comes from Control order.
- **Cons**: GUI drag capture sends moves and releases to the Control that took the press, and touch routing to Controls is unverified on 4.7; a PASS Control at the bottom still interacts with focus.
- **Rejection Reason**: rests on more unverified GUI behaviour than the chosen split.

### Alternative 5: Touch family only (`emulate_touch_from_mouse = true`)
- **Description**: the adapter reads only `InputEventScreenTouch` / `ScreenDrag`; desktop mice become touch index 0.
- **Pros**: one code path for both platforms.
- **Cons**: on a touch laptop, a real touch 0 and the emulated mouse touch 0 collide (the very case TR-input-005 forbids); emulated touch from mouse on desktop is itself unverified.
- **Rejection Reason**: the chosen design needs one `device` check and a reserved index, and keeps real touch and real mouse apart.

### Alternative 6: One lifecycle notification per platform
- **Description**: pick `APPLICATION_PAUSED` on mobile and `WM_WINDOW_FOCUS_OUT` on desktop.
- **Pros**: smaller; no episode latch.
- **Cons**: which ones fire is unverified; a missed case leaves the battle running in the background, which Game State Rule 17 forbids.
- **Rejection Reason**: the union is safe because pause is idempotent and resume is by tap only.

### Alternative 7: Live safe area, re-read on every resize
- **Description**: recompute `FieldInsets` on `size_changed` and re-lay out the HUD.
- **Pros**: handles foldables and orientation changes.
- **Cons**: `burst_button_centre()` is read once by HeroInput; a live change would desync the hit disc from Hero's cancel distances mid-gesture. Portrait is locked, so phones do not change insets at MVP.
- **Rejection Reason**: not needed at MVP; the Mobile Platform GDD may add it with a re-registration step.

## Consequences

### Positive
- The resolver never sees an engine event, a viewport or a device, so B2 stays fully headless.
- The exactly-once contract holds by construction: presses enter in one place, endings in another, and `_down` decides what is forwarded.
- Modal screens block the field twice over (engine order and the gate), so TR-hud-002 holds whatever S3 finds.
- Field units equal viewport units, so no conversion code exists outside `SafeAreaMath`, and every HUD and stage number stays valid on every phone.
- On tall phones the letterbox usually swallows the notch, so most phones run with zero in-field insets.
- ADR-0001's three `cancel()` callers and its teardown order are unchanged.

### Negative
- Letterbox bars waste about 20% of a 9:20 screen. Accepted for MVP; the Mobile Platform GDD owns any change.
- One more custom Control (`TapScreen`) instead of stock `Button`.
- A notification shade pull pauses the battle. Accepted: Game State Rule 17 pauses on any focus loss.
- On desktop, the click that refocuses the window also lands on the Paused screen and resumes on its release. One click both refocuses and resumes; S5 records whether that feels wrong.
- The spike is real work before any input story, on hardware the project has not yet set up.
- architecture.md B3 and three GDDs need edits to match (Migration Plan).

### Neutral
- `Input.use_accumulated_input` stays at its default (true): consecutive motion events merge, so `drag_moved` fires at most about once per frame. The resolver tests slop on every move it gets and handles a release beyond slop, so merging changes no outcome.

## Risks
- **S1 fails (input interleaves with ticks or arrives after `_process`).** Then the HUD's shown bonus could differ from the paid bonus (TR-hud-005). Mitigation: ADR-0004 queues commands and drains them at the start of `_process`; this ADR does not change.
- **S2 fails (emulated events carry no `DEVICE_ID_EMULATION`).** Mitigation: fallback F2, one family per platform. A touch laptop then needs its mouse ignored during development; accepted.
- **S3 (a) fails (STOP Controls do not consume touch presses).** Mitigation: the press gate already covers it. Record the result so ADR-0011 and later HUD work do not rely on Control occlusion for touch.
- **A system gesture steals a touch with no `canceled` flag and no focus notification.** Then the active pointer is stranded until its next press of the same index (Input Rule 1). Mitigation: S4 and S5 look for it; the cost is a miss, never a mis-fire, because the resolver never synthesises a release.
- **`edge_reject_margin` is too narrow for Android back-swipe.** Mitigation: it is data (0 to 48 units); S5's gesture swipes and the Pillar 4 phone test tune it.
- **`get_display_safe_area()` is in a different pixel space from the window.** Mitigation: S7 and its fallback; `SafeAreaMath` is pure, so a unit fix is one line and its tests.
- **`screen_get_dpi()` is wrong on some phones.** Mitigation: the size guard only logs; the store filter is the gate.
- **The 4.7 keys differ from the names written here.** Mitigation: S9; Implementation Guideline 1 makes CI catch a missing key.
- **The wrapper's `lifecycle_paused` connection keeps the old `Flow` alive until the wrapper's end-of-frame free.** Mitigation: an integration weakref test waits one frame (Decision 2.6). Headless V2 in ADR-0001 has no wrapper and is unaffected.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-002: one thin adapter node is the only engine-facing input code; it maps touch and mouse to the five calls in 540x960 field units | Decision 2 and Guideline 2; Decision 1 makes viewport units field units [S6]. **Full** |
| input-gesture-resolver.md | TR-input-003: every forwarded press gets exactly one release or cancel, even under a STOP Control; `canceled` honoured | Decision 2.1 and 2.3: endings read in `_input` for pointers in `_down`; `canceled` becomes `cancel_pointer` [S3, S4]. **Full** (design), verified by S3 and S4 |
| input-gesture-resolver.md | TR-input-004: `PROCESS_MODE_ALWAYS`; `cancel()` on pause, focus loss and resize; one lifecycle signal | Decision 2 and 2.5 [S5]. **Full** |
| input-gesture-resolver.md | TR-input-005: one event family; no duplicates; mouse index never collides with touch 0; non-left buttons dropped | Decision 1 settings and 2.2: drop `DEVICE_ID_EMULATION`, `MOUSE_POINTER`, left only [S2, fallback F2]. **Full** |
| input-gesture-resolver.md | TR-input-006: reject presses inside `edge_reject_margin` and safe-area insets via `get_display_safe_area()` in field units | Decision 3: `SafeAreaMath`, `is_rejected` [S7]. **Partial**: Input Rule 12 also names "gesture insets"; no Godot API for them is in the pinned reference, so `edge_reject_margin` stands in |
| input-gesture-resolver.md | TR-input-013: burst, arc and world targets are discs, not Controls; HUD Controls consume their events before the adapter | Decision 2.1 (presses after GUI), 2.4 (gate), 4 (only `TapScreen` takes input). **Partial**: this ADR fixes the routing order; that those targets are discs is ADR-0008's and the HUD's |
| input-gesture-resolver.md | TR-input-016: minimum 360 dp by runtime guard; field units equal viewport units; no Camera2D; `cancel()` on resize | Decision 1 (`keep`, no Camera2D, guard as `dp_per_unit >= 2/3`) and 2.5 (resize). **Full**, with the guard widened to height (GDD sync item 1) |
| game-state-stage-flow.md | TR-state-010: focus loss or backgrounding enters Paused; ticks stop, input cancels, the accumulator is zeroed, and a resume tap reaches nothing beneath | Decision 2.5 (notifications, cancel, signal to `Flow.pause`) and 4 (Paused `TapScreen`, gate). **Partial**: the tick gate and the zeroed accumulator are ADR-0004's |
| battle-hud.md | TR-hud-002: Result and Paused screens are full-screen modal Controls that consume every event before the adapter | Decision 2.1 and 2.4 and 4. **Full**. Moves and releases of a drag begun before the modal still reach the adapter, as the Input adapter contract requires (GDD sync item 3) |
| battle-hud.md | TR-hud-003: a Control fires only on a release whose press it saw while Armed, and clears that press on lifecycle or focus-loss signals | Decision 4: `TapScreen` and `clear_press()`. **Full** for modal Controls; the Armed model of Start/Call is a disc and HudLogic's (ADR-0004 clocks) |
| battle-hud.md | TR-hud-014: layout in 540x960 field units with insets converted to field units; `burst_y = clamp(888 - I_bottom, 816, 888)` | Decision 1 and 3: `FieldInsets` injected into HudLogic once per battle. **Full**; the formula itself stays the HUD's |

## Performance Implications
- **CPU**: a few comparisons and one dictionary lookup per pointer event; nothing per tick. `SafeAreaMath` runs once per battle.
- **Memory**: one adapter node, one `FieldInsets`, a dictionary of at most a few entries.
- **Load Time**: none.
- **Network**: none.
- **Rendering**: `keep` renders 540x960 scaled, which fixes the fill area ADR-0011 budgets against.

## Migration Plan
No code exists, so nothing migrates. This ADR does not edit `project.godot`, the GDDs or architecture.md; the first input story applies Decision 1 to `project.godot`. When this ADR is Accepted, these need edits to match:

**GDD sync items (not made here):**
1. `design/gdd/input-gesture-resolver.md` Formulas, `field_scale` and `target_ok`: under `keep` the scale is `min(width_dp / 540, height_dp / 960)`, and the minimum is width 360 dp **and** height 640 dp. Edge Cases "width below 360 dp" follows. The tablet scale-cap Open Question is closed for MVP.
2. `design/gdd/input-gesture-resolver.md` Rule 12: "gesture insets" have no engine source at MVP; `edge_reject_margin` is the side guard. Open Questions row "Adapter: which Godot path feeds the five calls..." is answered by this ADR (pending S0).
3. `design/gdd/battle-hud.md` Rule 2: "consume every event before the adapter sees it" holds for presses; moves and releases of a pointer the adapter already forwarded still reach it, by the Input adapter contract. Name `TapScreen` and the press gate. Rule 17 and Edge Cases: on desktop the refocusing click resumes.
4. `design/gdd/battle-hud.md` Layout: `I_top` and `I_bottom` are sampled once per battle and are 0 on desktop and on most tall phones (letterbox). The "stretch mode" item handed to the technical director and the Open Question "Does the stretch mode change every inset check?" are answered.
5. `design/gdd/game-state-stage-flow.md` Rule 17 and the "Becomes an ADR" note: the notifications are the union in Decision 2.5; the pause mechanism is a Flow phase driven by `lifecycle_paused`.
6. `design/gdd/input-gesture-resolver.md` Rule 7 (already listed by ADR-0001): `cancel()` callers are the adapter, Flow and AppRoot. This ADR adds nothing.

**architecture.md sync items (not made here):**
1. B3: add `MOUSE_POINTER`, `setup()`, `set_presses_blocked()`, `FieldInsets`, `SafeAreaMath`, `TapScreen`; replace the "NEEDS VERIFICATION" paragraph with a pointer to this ADR's spike results once S0 has run.
2. Data Flow 1: the input row becomes "presses after GUI, endings before GUI"; the NEEDS VERIFICATION note on event order points to S1.
3. Data Flow 6: fix the order as in Decision 2.5 and add the press gate and `clear_press()`.
4. Module Ownership: InputAdapter row gains the press gate and `FieldInsets`; ResultScreen and PausedScreen become `TapScreen`; the Mobile Platform (VS) row inherits safe-area mapping from `SafeAreaMath`.
5. Engine Knowledge Gap Summary: the "UI and display" row's `project.godot sets none` becomes "set explicitly by ADR-0003"; after S0, move verified items out of HIGH.
6. Open Questions: QQ-02 resolved by ADR-0003; QQ-06 resolved pending S0 (event order, notifications, moves after cancel); QQ-12 (large top inset) narrowed, since letterboxing absorbs most insets.

## Validation Criteria

**Task S0 (manual, device, first):** checks S1 to S9 in Decision 0, results recorded in this ADR and in `docs/engine-reference/godot/modules/input.md`, with screenshots and logs in `production/qa/evidence/`.

Headless gdUnit4 tests (ADR-0007 places them; names proposed). The adapter's logic is tested by feeding it constructed `InputEvent` objects through a test-only entry (`_route(event, phase)`), with a recording fake resolver:
- **A1 `test_adapter_press_release_once`**: a touch press, moves, release give press, moves, release in order; a second release of the same index is dropped.
- **A2 `test_adapter_canceled_becomes_cancel_pointer`**: `pressed = false, canceled = true` gives `cancel_pointer(i)`, never `release`.
- **A3 `test_adapter_drops_emulated_and_non_left`**: events with `device == DEVICE_ID_EMULATION`, right and middle buttons, the wheel and hover motion reach nothing; a left mouse press arrives as `MOUSE_POINTER`.
- **A4 `test_adapter_press_gate`**: with the gate closed, a press is dropped but the release of an earlier press still arrives.
- **A5 `test_adapter_rejected_zones`**: presses in each zone and outside the field are dropped; a drag that began outside a zone and moves into it still forwards its moves and release.
- **A6 `test_adapter_lifecycle_once_per_episode`**: two away notifications give one `cancel()` and one `lifecycle_paused`; after a focus-in, the next away gives another; a stale release after the cancel is dropped.
- **A7 `test_adapter_resize_cancels_without_pause`**.
- **A8 `test_adapter_silent_after_exit_tree`**.
- **A9 `test_safe_area_math`**: fixtures for 540x960 (zero), a 1080x2400 phone with a 96 px top cutout inside the bar (zero in field), a 1080x1920 phone with an 80 px cutout (positive `top`), and a squat 1536x2048 tablet (side bars); `dp_per_unit` at 360x800 dp is exactly 2/3 and at 400x600 dp fails.
- **A10 `test_tap_screen_fires_only_on_seen_press`**: a release with no seen press does nothing; `clear_press()` between press and release does nothing; a seen press and release fires once.
- **A11 `test_project_display_keys`** (part of ADR-0007's lint): `project.godot` holds the Decision 1 keys.

Manual evidence (`production/qa/evidence/`, blocking for the UI stories): desktop at 540x960 and resized; Paused on alt-tab and resume by click; Lost and Won screens block the field; on the phone, the letterbox, insets, and a drag that ends over the Paused screen after a shade pull.

**Reviews still owed.** This run had no way to spawn review agents, so the godot-specialist check (Step 5.5) and the technical-director TD-ADR gate (Step 5.6) did not run. Both must run before acceptance. `review_mode` is `full`, so TD-ADR is required. The godot-specialist should check in particular: the Decision 1 key names, the `_input` / GUI / `_unhandled_input` order, `DEVICE_ID_EMULATION`, `InputEventScreenTouch.canceled`, the six lifecycle notification names, and the `get_display_safe_area()` pixel space.

## Related
- ADR-0001 (Proposed): depends on it. Consistent with its three `cancel()` callers, its teardown order (Guideline 10) and its ban on `SceneTree.paused`, lambdas and `bind()`.
- Enables ADR-0004 (frame order; S1), ADR-0008 (resolver core), ADR-0011 (draw budget; viewport size). None written yet.
- `docs/architecture/architecture.md` v3: Engine Knowledge Gap Summary, Data Flow 1 and 6, B2, B3, QQ-02, QQ-06, QQ-12, QQ-20
- `docs/architecture/tr-registry.yaml`: the 11 TRs above
- GDDs: `design/gdd/input-gesture-resolver.md` (Rules 1, 7, 10, 12; Formulas; Dependencies, adapter contract; Open Questions), `design/gdd/battle-hud.md` (Rules 2, 17, 18; Layout; `burst_y`; UI Requirements), `design/gdd/game-state-stage-flow.md` (Rule 17; Edge Cases)
- Mobile Platform & Performance GDD (Vertical Slice, not written): inherits Decisions 1 and 3
