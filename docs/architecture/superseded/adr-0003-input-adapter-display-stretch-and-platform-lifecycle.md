# ADR-0003: Input Adapter, Display Stretch and Platform Lifecycle

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer from the 2026-11-04 desktop spike; reviewed 2026-11-05 by godot-specialist (2 blocking, 9 minor, with a 4.7.2 probe of the adopted keys) and technical-director under gate TD-ADR (CONCERNS: 3 blockers, 13 concerns); all findings were applied in this revision. No second review pass was run.

## Summary
Touch, display scaling and app focus are the three places the engine reaches the game, and the GDDs rest on unverified premises about all three (QQ-02, QQ-06, QQ-22). This ADR fixes one wrapper-built `InputAdapter` node that reads presses in `_unhandled_input` and the moves and releases of pointers it forwarded in `_input`, takes only `ScreenTouch`/`ScreenDrag` events with mouse-to-touch emulation on and touch-to-mouse off, rejects edge and inset presses, maps focus loss to `cancel()` plus one `lifecycle_paused` signal and a resize to `cancel()` plus `viewport_resized`, and sets the project to `canvas_items` stretch with `keep` aspect on a 540x960 base so field units equal canvas units; everything about phones stays in a device-run plan until Android and iOS confirm it.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; installed 4.7.2.stable.official) |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (QQ-02, QQ-06). The pinned reference has no touch, safe-area or lifecycle coverage beyond the section "Verified on 4.7.2" in `modules/input.md`, which is a desktop run. Every phone statement below is a decision taken on desktop evidence and is listed under Verification Required. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (lines 24, 39), `deprecated-apis.md` (line 53), `current-best-practices.md` (4.7, Platform), `modules/input.md` (section Verified on 4.7.2), `modules/ui.md`, the spike itself, and the echo-off probe (4.7.2 probe, 2026-11-05, prototypes/adr-0003-spike/echo-off-probe/): `prototypes/adr-0003-spike/README.md`, `main.gd`, `field.gd`, `main.tscn`, `project.godot` |
| **Post-Cutoff APIs Used** | None in code. `InputEvent.DEVICE_ID_MOUSE` (32) and `DEVICE_ID_EMULATION` (-1) are named only in the verified tables and in test fixtures. Stretch keys and `ProjectSettings` names are those the spike and the echo-off probe ran on 4.7.2. No override here has a typed return (all `void`) and `_forwarded` is a `PackedInt32Array` field with no setter, so the 4.7 typed-return and packed-array rules do not apply. |
| **Verification Required** | The owed Android and iOS device run, D1 to D10 under Decision 10, every run on the six adopted `project.godot` keys: event order, STOP-Control behaviour with a real finger, `canceled` and `index` on real touches, lifecycle notifications per OS, `size_changed`, safe-area rectangle space and units, bar contents, `free()` with a finger down (ADR-0001 item 3), dp readout, the agile-flushing value. Plus the NOT SOURCEABLE items at the end. |

### What the desktop runs verified (4.7.2, macOS, `canvas_items`/`keep`, events injected with `Input.parse_input_event`)
This ADR relies on these rows and nothing else about the engine. Source: `modules/input.md`, section Verified on 4.7.2. The first table is the 2026-11-04 spike, run with both emulations on. The second is the 4.7.2 probe, 2026-11-05, prototypes/adr-0003-spike/echo-off-probe/ with the six adopted keys (`emulate_mouse_from_touch=false`), which repeats the routing rows: they hold unchanged.

| Behaviour | Observed |
|---|---|
| Frame order | Buffered input is flushed at frame start, before `_physics_process` and `_process`; an event queued in `_process` of frame N arrives at N+1. |
| Callback order | `_input` on every node, then GUI (`gui_input`), then `_unhandled_input`. |
| STOP Control appears over a live gesture | Its moves go to `gui_input` and never reach `_unhandled_input`; its release is not taken and reaches `_unhandled_input`. |
| New press under a visible STOP Control | Press, moves, release all go to the Control; nothing reaches `_unhandled_input`. |
| Control hides while holding a press | Touch focus stays on the hidden Control; mouse focus is dropped, so mouse motion and release reach `_unhandled_input`. |
| `emulate_touch_from_mouse` | Each mouse event yields a `ScreenTouch`/`ScreenDrag` with device -1 delivered before the mouse event, which keeps device 32 (`DEVICE_ID_MOUSE`). |
| `emulate_mouse_from_touch` (default on) | Touch index 0 yields a mouse event (device -1) before the touch; index 1 yields none. |
| Positions under stretch | Already in canvas units. The screen transform is anisotropic. 600x1048 window: `Transform2D(Vector2(1.090741, 0), Vector2(0, 1.091667), Vector2(6, 0))`. 500x1000: `Transform2D(Vector2(0.925926, 0), Vector2(0, 0.925), Vector2(0, 56))`. |
| Resize | `Viewport.size_changed` fired the same frame as `window_set_size`; `NOTIFICATION_WM_SIZE_CHANGED` did not reach a child in 4 frames. |
| Focus notifications | `NOTIFICATION_APPLICATION_FOCUS_IN` 2016, `_OUT` 2017, `NOTIFICATION_WM_WINDOW_FOCUS_IN` 1004, `_OUT` 1005 reach child nodes. Startup sequence 2016, 1005, 2017, then 1004, 2016. `NOTIFICATION_APPLICATION_PAUSED` 2015 and `_RESUMED` 2014 were not testable. |
| Safe area | `DisplayServer.get_display_safe_area()` returned the screen minus the menu bar on macOS. Meaningless off-device. |
| Control under a Node2D | Zero-size rect, never receives GUI input; a `CanvasLayer` parent works (the spike's `HUD` layer). |
| `agile_event_flushing` | The spike read the wrong key (`input/` prefix) and got null; see the probe table. |

Echo-off probe (adopted keys; 4.7.2 probe, 2026-11-05, prototypes/adr-0003-spike/echo-off-probe/):

| Behaviour | Observed |
|---|---|
| Callback split, echo off | Identical to the spike rows: a new touch under a visible STOP Control reaches `_input` and `gui_input`, never `_unhandled_input`; with the Control shown mid-gesture, drags reach `_input` and `gui_input`, the release reaches `_input` and `_unhandled_input`. |
| `Button`, echo off | Receives the raw `ScreenTouch` in `gui_input`, swallows it before `_unhandled_input`, fires `pressed` on release. `MOUSE_FILTER_STOP` by default. |
| Left mouse click | `ScreenTouch` index 0 with device `DEVICE_ID_EMULATION` (-1) first, then `MouseButton` device 32. |
| Right click | `MouseButton` only; no touch is emitted. Middle click was not probed; D10 checks it on a device. |
| `input_devices/buffering/agile_event_flushing` | Default false. |
| Press in a letterbox bar | Arrives outside the field: (-4.584, 458.0) and (270.0, -49.73) in the two probe windows. |
| `aspect="expand"` | Grows the long axis only, origin (0, 0): 549x960 at 600x1048, 540x1080 at 500x1000; never shrinks. `keep_width` not probed. |
| `DisplayServer.window_is_focused()` | False at `_ready` on a launch that never received focus; no focus notification arrived in that run. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): the wrapper builds the adapter per battle in `setup()` (Decision 4), it lives under `src/presentation/`, and `Battle.set_input_cancel` receives `resolver.cancel`. |
| **Enables** | ADR-0004 (the frame order its commands wait for rests on Decision 2; provisional on D1 and D3 until the device run), ADR-0008 (the five resolver calls and positions in field units are this ADR's output contract; provisional on D3), ADR-0010 (HeroInput and TowerInput receive positions only through the resolver), ADR-0011 (inherits Decision 9: one `CanvasLayer` child of the wrapper holds every HUD Control; field and band coordinates are field units). |
| **Delegates To** | ADR-0004: the Clock and wrapper `_process` ordering, the frame a lifecycle notification is handled in relative to `Battle.tick`, the accumulator zeroing on `phase_changed(PAUSED)`, how view clocks freeze. ADR-0006 first, then ADR-0008 conforming: the signal names that break the past-tense rule (QQ-07: `tapped`, `ground_tapped`, `pressed`, `became_idle`). ADR-0007: the `project.godot` key lint, the Control `mouse_filter` scene lint, the no-lambda lint over `src/presentation/input/`, the `PointerGate` fixtures and the manual-evidence list for D1 to D10. ADR-0008: resolver internals (`press`, `move`, `release`, `cancel_pointer`, `cancel`, `create`, `validate`, re-entrancy). ADR-0010: what a pin or tap means and the hit radii as constants. ADR-0011: HUD and field drawing and any clip rect that keeps field art out of the letterbox bars; it inherits Decision 9's CanvasLayer placement. Not delegated to any ADR: `HudLogic`'s modal press model, which Battle HUD Rule 2 and criterion 21 already specify completely (Decision 9). The Mobile Platform & Performance GDD (Vertical Slice): per-platform numbers (orientation lock, edge-to-edge, gesture insets, the layout response beyond the inset table in Decision 7, the dp readout, bar colour). |
| **Blocks** | Every Input adapter story, the HudModals story (it shares the translator), the first story that sets `project.godot` display keys, and the Flow story for Rule 17 (Paused). |
| **Ordering Note** | Departure from `architecture.md` Priority, which says ADR-0003 "starts with a short verification spike on a device": no device was available, so this ADR rests on a desktop spike and probe and lists the phone premises. Deadline: D1 to D4 run before the first phone build or the Vertical Slice gate, whichever comes first; a risk-register entry carries that trigger. ADR-0004 and ADR-0008 mark their Depends On row on ADR-0003 as resting on a provisional premise (D1, D3) when they are written. Stays Proposed until the reviews are applied and accepted; acceptance does not require the device run. QQ-22 stays open until D1 to D4 pass on Android and iOS. |

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

**1. Classes and ownership.** Two classes and two value types under `src/presentation/input/`, none under `src/battle/`.
- `InputAdapter extends Node` is the engine-facing shell. It owns `_input`, `_unhandled_input` and `_notification`, sets `process_mode = Node.PROCESS_MODE_ALWAYS`, and emits `lifecycle_paused()` and `viewport_resized()` (the names in `architecture.md` B3 and Input Rule 7). It also carries `static func read_pointer(event: InputEvent) -> PointerSample`, the only code that tests `InputEvent` subclasses or reads their fields. `HudModals` calls the same static, so the two translate identically as Battle HUD Rule 2 requires, and TR-input-002's "the adapter" wording stays true. `read_pointer` returns a new `PointerSample` or null; the allocation is negligible at touch rates.
- `PointerGate extends RefCounted` holds the rules that need no engine: the set of forwarded indices and the calls to the resolver. It is built by the adapter's `setup()` and is unit-testable with a recording fake resolver and no node. The accept-bounds test is not a method on it: it is the one pure static `DisplayContract.accepts(pos, margin, insets)`, called by `PointerGate` and by `HudLogic`, so the two cannot compute different bounds (TR-hud-003).
- `PointerSample` (kind, index, pos) and `FieldInsets` (left, top, right, bottom) are plain value types.
- The safe-area conversion (Decision 7) is a formula and an oracle, not a class, until D6 supplies its input.

The wrapper builds the adapter in `BattleWrapper.setup()` after `InputResolver.create` succeeds (ADR-0001 Decision 4), calls `adapter.setup(resolver, margin, insets, dev_error)`, adds it as a child, and makes the connections of Decision 8, including the `size_changed` one. A null resolver builds no adapter. The adapter holds the resolver (strong, `RefCounted`) and no reference to `Battle`, Flow or `AppRoot`; `dev_error` is a method Callable on `Battle`'s `DevErrorSink` (ADR-0001 Decision 5), unguarded.

**2. Event path: the callback split.** The adapter takes presses in `_unhandled_input` and the moves, releases and cancels of pointers it forwarded in `_input`.
- Presses go through `_unhandled_input` so a visible `mouse_filter = STOP` Control takes the whole gesture and the press never exists for the adapter (spike: "new press under a visible STOP Control"). This is how a modal "reaches nothing beneath".
- Moves and releases go through `_input` because it runs before GUI and a STOP Control that appears over a live gesture swallows moves in `_unhandled_input` (spike). Release would also have reached `_unhandled_input`, but reading both in one place keeps one rule.
- `_input` ignores presses; `_unhandled_input` ignores everything but presses. Neither calls `set_input_as_handled()`.
- Input is delivered at frame start before `_process` (spike), so resolver signals and the commands behind them run before that frame's ticks. ADR-0004 owns the frame order built on this; the premise is D1 on a device. Routing is verified for the adopted keys: the echo-off probe (4.7.2 probe, 2026-11-05, prototypes/adr-0003-spike/echo-off-probe/) reproduced every spike row (press under a visible STOP Control reaches `_input` and `gui_input` only; a modal shown mid-gesture leaves drags in `_input` and the release in `_input` and `_unhandled_input`).

**3. Pointers.** The adapter forwards every press that passes the accept bounds, with its own index, to the resolver, and the resolver alone decides which pointer is active (Input Rule 1). It does not drop second fingers itself, because Rule 1's replacement of an unmoved, tap-less press by a later press only works if that later press reaches the resolver.
- `PointerGate` keeps `_forwarded`, a small `PackedInt32Array` of indices whose press it forwarded and whose end it has not seen.
- Press: outside the accept bounds, drop and do not add to `_forwarded`. Otherwise add the index if absent and call `resolver.press(index, pos)`; a press for an index already forwarded is forwarded again, because Rule 1 treats it as a lost release.
- Move: forward only if the index is in `_forwarded`. A move of a finger that started in a rejected zone, under a modal or in a previous battle is dropped. A move from a forwarded finger is forwarded wherever it is, including inside the rejected zones (Input Rule 12: a drag that started elsewhere stays valid).
- Release: if the index is in `_forwarded`, remove it and call `resolver.release(index, pos)`; otherwise drop it. This drops the release of a hidden-Control gesture (spike) and the release of a finger held across a pause or retry.
- Cancel (`canceled = true` on a release-shaped touch): if forwarded, remove and call `resolver.cancel_pointer(index)`; otherwise drop. A cancel is never turned into a release (Input contract).
- A touch with `pressed = true` and `canceled = true` is dropped by `read_pointer`.
- Every forwarded press is therefore closed by a release, a `cancel_pointer`, or the adapter's `cancel_all()` (Decision 8). A press whose end the OS never delivers is recovered by the next press of the same index (Input Rule 1); that case is not solvable without a clock and the GDD accepts it.

**4. Touch and mouse: one event family.** `project.godot` sets `input_devices/pointing/emulate_touch_from_mouse=true` and `emulate_mouse_from_touch=false`. The adapter and `HudModals` read only `InputEventScreenTouch` and `InputEventScreenDrag` through `InputAdapter.read_pointer`; every `InputEventMouse*` event is ignored whatever its device.
- Desktop testing goes through the touch path: a left click arrives as a `ScreenTouch` with index 0 and device `InputEvent.DEVICE_ID_EMULATION` (-1) first, and the `MouseButton` (device 32) that follows is ignored (4.7.2 probe, 2026-11-05, prototypes/adr-0003-spike/echo-off-probe/). Phone builds receive native touches.
- With `emulate_mouse_from_touch` off the routing rows hold unchanged (probe): this was the unverified part of the first draft and is now measured on desktop.
- The mouse cannot collide with touch index 0 by construction: the mouse is never a pointer, only the emulated touch (index 0) is. No code reads `event.device`; nothing under `src/` may test `device == 0` (deprecated in 4.7).
- Non-left buttons: a right click emits no touch (probe; middle click unprobed, D10), so TR-input-005's "non-left buttons are dropped" is met by the engine's emulation and needs no code. A translator guard is impossible anyway, because an emulated `ScreenTouch` carries no button and arrives before the mouse event that does. If a device or a later engine version emits one, the fallback is `emulate_touch_from_mouse=false` with a desktop-only mouse path (Alternative 8), which reopens this ADR. D10 repeats the check on a device build.
- `_ready` reads the two `ProjectSettings` keys (as the spike did) and reports through `dev_error` if either is wrong, so a lost key is a loud defect and not a dead desktop build.
- Built-in `Button`s respond to raw touches with the echo off (probe) but are not used in the battle scene. A `Button` is `MOUSE_FILTER_STOP` by default and would swallow field presses, which ADR-0007's `mouse_filter` lint catches. `HudModals` reads touches in `gui_input` (Battle HUD Rule 2).

**5. Coordinates.** `event.position` of a `ScreenTouch` or `ScreenDrag` is already in canvas units under stretch (spike), and with no Camera2D, no canvas-transform change and the wrapper at identity, canvas units are field units (TR-input-016). The adapter therefore forwards `event.position` unchanged and never computes a viewport transform for events. A press in a letterbox bar arrives as a coordinate outside 0..540 or 0..960 (probe: (-4.584, 458.0) and (270.0, -49.73)) and is dropped by the accept bounds.
- The test oracle is the measured screen transform, as full `Transform2D` values: window 600x1048 gives `Transform2D(Vector2(1.090741, 0), Vector2(0, 1.091667), Vector2(6, 0))`; window 500x1000 gives `Transform2D(Vector2(0.925926, 0), Vector2(0, 0.925), Vector2(0, 56))`. The transform is anisotropic (integer-rounded viewport rect), so no scalar scale or scalar tolerance is used; fixtures build the transform and compare the converted result to 0.01 field units. A hand-built `InputEventScreenTouch` is never transformed in tests; `PointerGate` receives field units directly.
- Nothing may add a `Camera2D`, set `Viewport.canvas_transform`, or scale the wrapper. A Camera2D would make canvas units differ from field units and invalidate every constant in the Input and HUD GDDs.
- Using `get_canvas_transform().affine_inverse()` for events is not needed and is not adopted. The spike printed `get_canvas_transform()` and `get_screen_transform()` but recorded values only for the screen transform, so the canvas transform's role under stretch is NOT SOURCEABLE; none of this ADR depends on it.

**6. Display stretch, aspect, minimum width, tall phones.** `project.godot` sets `display/window/size/viewport_width=540`, `viewport_height=960`, `display/window/stretch/mode="canvas_items"` and `display/window/stretch/aspect="keep"`. These are the exact keys the spike and the probe ran on 4.7.2; they are written explicitly because the 4.7 reference only describes defaults for new projects (`canvas_items`/`expand`) and says nothing about an absent key in an existing one.
- `keep` makes the viewport always 540x960, so field units equal viewport units on every device and there is one layout. This closes QQ-02 on evidence. `expand` loses on a measured line: it never shrinks, grows the long axis only from origin (0, 0), and gave 549x960 at 600x1048 and 540x1080 at 500x1000 (probe), so the field would not be centred and a taller window would show 120 field units below the field with the HUD `CanvasLayer` stretching and the field art not (enemies walking off the bottom).
- Decision: letterbox. Cost on a taller phone: bars. At 360x800 dp the scale is 360/540 = 0.667, the field is 640 dp tall and 160 dp (20 percent) is bars, 80 dp above and below; at 390x844 dp it is 0.722, 693 dp, 151 dp of bars (18 percent). A window wider than 9:16 (a tablet, a wide desktop window) is height-limited and gets side bars, which the edge rejection also covers.
- A reveal of extra height is out of scope for MVP and the Vertical Slice unless D6 shows the bars are unacceptable. Adopting it needs an aspect mode other than the measured one, a field-origin offset, and positions that are no longer canvas units, so it supersedes Decisions 5, 6 and 7 and four Implementation Guidelines (forward positions unchanged, no canvas-transform change, the four display keys, insets absorbed by bars) through a new ADR. The Mobile Platform GDD may request it; it does not own it. Alternative 1.
- Layout rules affected by letterboxing (L1 to L7 are Enemy & Wave's; the Battle HUD cites them):

| Rules | Effect of `keep` |
|---|---|
| Enemy & Wave L1 to L4, L6, L7 | Unchanged: field-relative. |
| Enemy & Wave L5 (enemies enter and exit unseen) | Holds only if nothing at negative x, x above 540 or negative y is visible in the bars. Not measured; D6 checks it. If it fails, the 16-unit margin no longer hides entry and a clip rect on the field is ADR-0011's. |
| Battle HUD Layout and content-rule tables | Unchanged at inset 0; inset rows per the Decision 7 table. |
| Battle HUD prompt overlap at large `I_top` (QQ-12) | Still the Mobile Platform GDD's. |

- Minimum width is 360 dp, a constant `DisplayContract.MIN_WIDTH_DP` beside `FIELD_SIZE = Vector2(540, 960)`. They are structural constants derived from `target_ok` (`2 x 36 x width_dp >= 25920` gives 360), not tuning values. The guard measures field width in dp, not window width: under `keep` the scale is `min(w/540, h/960)`, so a height-limited window has a lower scale than its width suggests. `DisplayContract.field_width_dp(width_dp, height_dp) = min(width_dp, height_dp x 540/960)` must be at least 360. Portrait split-screen windows about 400 dp tall fail it (a 72-unit target is then 0.075 x 400 = 30 dp). The guard reports once through `dev_error`; the store filter is the Mobile GDD's. How to read the window size in dp is NOT SOURCEABLE; the guard is wired after D6, which also covers a multi-window case. Phone detection is not needed at MVP: the guard keys on field dp, not on device class.
- The bar colour is a Mobile GDD and art decision.
- Resize hook: `get_viewport().size_changed` (spike: same frame as the resize). `NOTIFICATION_WM_SIZE_CHANGED` is not used. The wrapper connects it in `setup()` to `adapter.on_viewport_resized`, so the connection is inside ADR-0001's `setup()` rule and dies with the wrapper; no `_exit_tree` disconnect is needed. A resize is not a pause.

**7. Rejected zones and safe-area insets.** The accept bounds, in field units, for a press, as the one pure static `DisplayContract.accepts(pos, edge_reject_margin, insets) -> bool`:
`x_min = max(edge_reject_margin, I_left)`, `x_max = 540 - max(edge_reject_margin, I_right)`, `y_min = I_top`, `y_max = 960 - I_bottom`. A press is rejected when `x < x_min` or `x > x_max` or `y < y_min` or `y > y_max`; a press exactly on a bound is accepted. The Input and HUD GDDs say "inside the margin" without naming the boundary; the sync section asks both to adopt this. `PointerGate` and `HudLogic` (modal presses) both call it with the same arguments.
- `edge_reject_margin` comes from the Input record via the wrapper (default 36, domain 0 to 48). It applies to the side edges only; top and bottom are bounded by the insets.
- `FieldInsets` is produced once per battle by the wrapper and given to both the adapter and `HudLogic`. It is fixed for the battle (Battle HUD edge case: insets stay fixed on resize).
- MVP: `FieldInsets` is all zeros, as the Battle HUD GDD already assumes. Desktop is always zero (Input Rule 12).
- The phone mapping is a specified formula, with no class, test or story until D6 supplies its input space. Given the safe rectangle `safe_px` and `T = get_viewport().get_screen_transform().affine_inverse()`, map the rectangle's corners to canvas units, `a = T * safe_px.position`, `b = T * safe_px.end`, and set `left = max(0, a.x)`, `top = max(0, a.y)`, `right = max(0, 540 - b.x)`, `bottom = max(0, 960 - b.y)`. Under `keep` the bars absorb any inset that lies inside them: a corner above the field gives negative `a.y` and `top = 0`. Worked oracle with the 500x1000 transform above: a safe rectangle starting at y = 100 px gives `top = (100 - 56) / 0.925 = 47.57` field units; one starting at y = 40 gives 0. The window size is not an input.
- Whether `get_display_safe_area()` returns window pixels, screen pixels or something else on a phone, its origin, and what an Android edge-to-edge window reports (the reference lists "Android: Edge-to-edge display" in one line) are NOT SOURCEABLE. The spike's desktop result (screen minus menu bar) is in screen space, a different space from the window, which is why the units cannot be assumed. D6 prints the rectangle with window size, screen size and the screen transform on four devices.
- QQ-12 rule and hand-off numbers. The HUD never clamps an inset, because clamping puts HUD art under the notch. Layout uses the true inset. The adapter always rejects presses inside the true inset. Numbers the Mobile Platform GDD inherits, all from the Battle HUD GDD in field units (1.5 units is 1 dp at 360 dp width):

| Inset | Field units | dp at 360 | What happens |
|---|---|---|---|
| `I_top` 11 | 11 | 7.3 | The starter stage's arc top panel (y 117) meets the prompt (ends at y 106 + `I_top`). |
| `I_top` 68 | 68 | 45 | The prompt stops clearing the lane's edge. |
| `I_top` 102 | 102 | 68 | The prompt overlaps the lane by its 34 maximum. Above this the HUD layout is outside what was checked. |
| `I_bottom` 72 | 72 | 48 | `B` caps at 72; the burst button's y clamps at 816. |
| `I_bottom` 92 | 92 | 61 | Play again enters the inset. |
| `I_bottom` 96 | 96 | 64 | The burst hit disc enters the inset. |
| `I_bottom` 164 | 164 | 109 | Play again is wholly dead with no other exit. |

  If a device reports an inset above 102 (top) or 92 (bottom) after bar absorption, the wrapper reports it once through `dev_error` and runs on; the fix (shrinking the field so the inset falls into a bar, or a HUD response) is the Mobile Platform GDD's. That a 360x800 dp phone's 80 dp bars already hold typical status-bar heights is arithmetic on the letterbox model, not a measured phone: a hypothesis for D6.

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

The code names the constants, not the numbers.
- Launch guard (decided here). `var _armed := false` and `var _lost := false`. In `_ready` and on every re-arm notification, `_armed = _armed or DisplayServer.window_is_focused()`: the call is sampled, not assumed, because the first re-arm notification of the spike's launch sequence (2016) arrives before the window has focus. A loss notification is ignored while `_armed` is false. A real loss must follow a moment the window had focus; launch losses precede one. The probe saw `window_is_focused()` false at `_ready` on an unfocused launch; the focused-launch case and the phone values are D9a and D9b. Four lines, no frame counting.
- Loss handling, exactly once per event. On a loss notification while armed: if `_lost` is true, return; else set it, call `_gate.cancel_all()` (clears `_forwarded` and calls `resolver.cancel()`), then emit `lifecycle_paused()`. On any re-arm notification, clear `_lost`. One real focus loss on desktop sends both 2017 and 1005 and gives one pause. Flow's `pause()` and its injected `cancel_input()` that follow find the resolver Idle (Input Rule 7), so double cancel is safe by the Idle rule.
- Wiring, in `BattleWrapper.setup()`: `adapter.lifecycle_paused` connects to Flow's `pause` and to `HudLogic.modal_cancel`; `adapter.viewport_resized` connects to `HudLogic.modal_cancel` alone; `get_viewport().size_changed` connects to `adapter.on_viewport_resized`. All plain connections with no flags (ADR-0001 Decision 5), to targets `Battle` and the wrapper hold.
- Resize handling: `on_viewport_resized` runs `cancel_all()` then emits `viewport_resized()`. No pause. If `size_changed` fires at startup, a cancel with no gesture is a no-op (Input Edge Cases).
- Resume: no tap is synthesised and no release is made from a cancel. `_forwarded` was cleared, so a finger held across the pause has its moves and release dropped by the gate, and a new press is needed. The resume tap is a press on the Paused modal, a STOP Control shown by `HudLogic` on `phase_changed(PAUSED)`, which takes the press before `_unhandled_input` (Decision 2), so it reaches nothing beneath. On desktop the refocus click may be that tap or may arrive before the modal is up; the Flow GDD accepts either, and D9a records which.
- The pause is Flow's state, not `SceneTree.paused`, which is never set. The tick stops because `Battle.tick` returns at once outside WAVE and INTERMISSION and the wrapper zeroes its accumulator (Flow Rule 17; ADR-0004). `PROCESS_MODE_ALWAYS` is the defensive setting the Input GDD asks for.
- Ignoring early losses costs nothing: the battle opens in Build with its clock stopped. Whether a notification can be dispatched inside `Battle.tick` is ADR-0004's check; the expectation is that engine callbacks run on the main thread one after another.

**9. HUD Controls and modals.**
- One `CanvasLayer`, a child of the wrapper, holds every battle HUD `Control`; none is under the wrapper's `Node2D` or any other `Node2D` (spike: a Control under a Node2D gets a zero-size rect and no GUI input). This placement is decided here; ADR-0011 inherits it and decides only how the controls draw (`HudTopBand`, `HudField`, `HudModals` are its children).
- Only `HudModals` (the Paused and result screens) is `mouse_filter = Control.MOUSE_FILTER_STOP`. Every other HUD Control is `MOUSE_FILTER_IGNORE`, because the burst button, build arc and world targets are resolver discs, not Controls (TR-input-013); a stray STOP or PASS Control, and a `Button` (STOP by default), would swallow presses before the adapter.
- Modals are built once and toggled with `visible`, never freed (TR-hud-002). A modal that hides inside its own press handler (the resume tap) keeps touch focus and still receives the drag and release (spike); its handler treats them as no-ops. On desktop with emulation, the mouse focus is dropped and the echo reaches `_unhandled_input`; the adapter ignores it because it is mouse-class.
- A modal appearing over a live gesture: the adapter keeps receiving that gesture's moves and release through `_input` (spike and probe), so it closes normally. The modal's `gui_input` also receives those moves; `HudLogic`'s held-pointer model drops moves and releases of an index it never saw pressed.
- TR-hud-003 is decided here as far as it is architectural: `HudModals` translates through the same static `InputAdapter.read_pointer` (touch only, left button by emulation, `canceled` to `modal_cancel_pointer`, never to a release) and tests presses with the same `DisplayContract.accepts`; `modal_cancel()` is wired to both signals (Decision 8). The remaining clauses (a tap counts only on the same pointer's release within `tap_slop` while Armed, a later press replaces an unmoved one) are fully specified by Battle HUD Rule 2 and criterion 21, need no architectural decision, and `HudLogic` implements them.

**10. Device verification plan (owed run).** Everything the desktop runs could not prove. Every D run uses the six `project.godot` keys of the Implementation Guidelines and states its key set in its log header. The spike's own `project.godot` and `README.md` are updated to the six keys, with the key set stated per run, before the first device run; the keys are already stated in `prototypes/adr-0003-spike/echo-off-probe/README.md`. Run the spike scene on a physical Android phone and an iPhone with real fingers, extending `main.gd` with a manual mode (the spike injects events by frame number; D1 to D5 need a human, so the run adds a flag that skips the injected script, shows the Modal on a timer or a second-finger press, and prints the same `SPIKE|f<frame>|` lines). Read output from `adb logcat | grep 'SPIKE|'` and the Xcode console. Retain logs under `production/qa/evidence/adr-0003-device-run/`. Include a 360x800 dp phone (or nearest) and a near-9:16 device. Deadline: D1 to D4 before the first phone build or the Vertical Slice gate, whichever comes first.

| Run | Do on the device | Each must print or show | If the premise fails, reopen |
|---|---|---|---|
| D1 Event order | One finger: press, drag, lift, several times; print `input_devices/buffering/agile_event_flushing` and its value | For every event, the `main._input` and `field._unhandled_input` lines carry a frame number whose first `main._process` mark comes after them; `_input` precedes `_unhandled_input`; the setting value on the device build | ADR-0004 frame order; Battle HUD TR-hud-005 and Rules 10 and 11; cross-GDD scenarios 1, 3, 5 (QQ-22) |
| D2 Fields | Same, plus two fingers down at once, lift in both orders, and a press at an edge swipe | `idx`, `pressed`, `canceled`, `pos`, `dev` for touch and drag; whether a second finger is index 1; whether an index is reused while another finger is down; `canceled` true on a system gesture steal | Input Rule 1, Adapter contract on `canceled`, TR-input-003, Hero release rows |
| D3 STOP over a gesture | Hold finger A on the field, make the Modal appear under it (timer), keep dragging, lift. Then, with the Modal visible and A still held, press a second finger B under it | `_input` receives every move and the release of A after the Modal appears; the Modal's `gui_input` also receives A's moves; B's press, moves and release reach only the Modal | Input adapter contract, Battle HUD Rule 2, TR-hud-002, TR-input-013, cross-GDD scenario 3, QQ-22 |
| D4 Control hides mid-gesture | Press on the visible Modal, hide it during the hold, drag, lift | Where the drag and release arrive (hidden Control's `gui_input` and/or `_input`); the gate-equivalent line for the never-forwarded index drops | PointerGate release rule; HudModals no-op rule |
| D5 Lifecycle | Home button, app switcher, lock button, notification shade pull-down (Android), Control Center (iOS), incoming call or permission dialog, return each time | Which of 2017, 1005, 2015 fire, in what order, per cause; which of 2016, 1004, 2014 fire on return; the count of `lifecycle_paused` the dedupe would emit (one per loss) | Flow Rule 17, TR-state-010, TR-input-004, Flow acceptance row 12 and the lifecycle deferred criterion |
| D6 Resize, safe area, bars | At launch and after any window change (Android multi-window if supported): `size_changed` count, `get_display_safe_area()`, `window_get_size()`, `screen_get_size()`, `screen_get_scale()`, `screen_get_dpi()`, `get_screen_transform()`; press in a letterbox bar and at the field corners; a sprite at x = -30 and at y = -30 and one at x = 570 | Rectangle space and origin, whether it includes the status bar and cutout; the formula's insets per device; whether bar presses arrive and where; the dp width; nothing drawn into the bars (L5); a height-limited multi-window case against `field_width_dp` | Input Rule 12, TR-input-006, TR-hud-014, TR-input-016, Enemy & Wave L5, the Decision 7 table; Mobile Platform GDD scope |
| D7 Edge margin | Swipe from each side edge, Android gesture navigation on | Whether the touch is delivered and its x; whether 36 units clears the gesture zone | Input GDD open question on `edge_reject_margin` |
| D8 `free()` with a finger down | Hold finger A anywhere; with finger B tap Retry on the Lost screen; keep A moving, then lift | No error; no gesture from A; A's lift and next press start clean | ADR-0001 Verification item 3 (closed by this run) |
| D9a Launch, desktop | Cold launch focused and unfocused; Alt-tab away and back; click to refocus. Runs before the adapter story closes | Frame numbers of launch notifications relative to `_ready` and the first `_process`; `window_is_focused()` at `_ready` for a focused launch; no Paused modal on a focused launch (retained screenshot); one Paused on a real loss; whether the refocus click is the resume tap | Decision 8 launch guard (fallback: also ignore losses before the first `_process`) |
| D9b Launch and resume, device | Cold launch, then background and return | `window_is_focused()` on Android and iOS; no Paused on launch | Decision 8 launch guard |
| D10 Emulation, device | Tap with the setting off on a device build; a `Button`-free modal still receives touches | Zero mouse events echoing a touch; touches reach the modal. The desktop half (callback split, `Button`, right and middle click) is done by the echo-off probe | TR-input-005; Battle HUD Rule 2 translation |

D1 to D4 close QQ-22 on Android and iOS. A failure of D1 or D3 reopens Approved Input and Battle HUD rules and the provisional premise under ADR-0004 and ADR-0008.

### Architecture Diagram

```
Engine frame start (input flushed before _physics_process / _process)
 │
 ├─ _input(event)  on every node ──────────────────────────────────────────┐
 │     InputAdapter._input: InputAdapter.read_pointer → MOVE / RELEASE / CANCEL│
 │         └─► PointerGate: forwarded? ──► resolver.move / release / cancel_pointer
 ├─ GUI (CanvasLayer HUD)                                                   │
 │     HudModals (STOP) takes presses under it; every other HUD Control IGNORE
 └─ _unhandled_input(event)                                                 │
       InputAdapter._unhandled_input: PRESS only                            │
           └─► PointerGate: inside accept bounds? ──► resolver.press ◄──────┘
 
InputAdapter._notification: FOCUS_OUT / WM_WINDOW_FOCUS_OUT / APPLICATION_PAUSED
 └─► (once per loss, only when armed) PointerGate.cancel_all() ─► resolver.cancel()
                    emit lifecycle_paused ─► Flow.pause · HudLogic.modal_cancel
Viewport.size_changed ─► (wrapper connects) adapter.on_viewport_resized ─► cancel_all() ─► emit viewport_resized ─► HudLogic.modal_cancel

BattleWrapper (Node2D, identity)
 ├─ InputAdapter (Node, PROCESS_MODE_ALWAYS)   ← only InputEvent consumer for gameplay
 ├─ HUD: one CanvasLayer ─ HudTopBand · HudField (IGNORE) · HudModals (STOP)
 └─ field views / stage scene (no Camera2D)
project.godot: viewport 540x960 · stretch canvas_items · aspect keep
               emulate_touch_from_mouse=true · emulate_mouse_from_touch=false
```

### Key Interfaces

```gdscript
class_name DisplayContract extends RefCounted
const FIELD_SIZE := Vector2(540.0, 960.0)   # canvas units == field units (no Camera2D)
const MIN_WIDTH_DP := 360                    # derived from target_ok; not a tuning value
const STRETCH_MODE := "canvas_items"         # checked against ProjectSettings at boot (dev_error)
const STRETCH_ASPECT := "keep"
## Field width in dp under keep: min(width_dp, height_dp * 540/960). Must be >= MIN_WIDTH_DP.
static func field_width_dp(width_dp: float, height_dp: float) -> float
## The one accept-bounds test, shared by PointerGate and HudLogic. Boundary inclusive.
static func accepts(pos: Vector2, edge_reject_margin: float, insets: FieldInsets) -> bool

class_name FieldInsets extends RefCounted
var left: float
var top: float
var right: float
var bottom: float

class_name PointerSample extends RefCounted
enum Kind { PRESS, MOVE, RELEASE, CANCEL }
var kind: Kind
var index: int
var pos: Vector2                             # canvas units == field units

class_name PointerGate extends RefCounted
## dev_error reports a non-finite position (which is dropped).
func _init(resolver: InputResolver, edge_reject_margin: float, insets: FieldInsets, dev_error: Callable) -> void
func press(index: int, pos: Vector2) -> void          ## Drops outside DisplayContract.accepts; else forwards and records the index.
func move(index: int, pos: Vector2) -> void           ## Forwards only recorded indices.
func release(index: int, pos: Vector2) -> void        ## Forwards and forgets a recorded index; drops others.
func cancel_pointer(index: int) -> void               ## As release, to resolver.cancel_pointer.
func cancel_all() -> void                             ## Forgets every index, then resolver.cancel().

class_name InputAdapter extends Node
signal lifecycle_paused()          ## Once per focus loss or background, when armed; wrapper -> Flow.pause, HudLogic.modal_cancel
signal viewport_resized()          ## Wrapper -> HudLogic.modal_cancel only. A resize never pauses.
func setup(resolver: InputResolver, edge_reject_margin: float, insets: FieldInsets, dev_error: Callable) -> void
func on_viewport_resized() -> void                  ## Wrapper connects Viewport.size_changed here in setup().
func _input(event: InputEvent) -> void              # MOVE, RELEASE, CANCEL of forwarded pointers
func _unhandled_input(event: InputEvent) -> void    # PRESS only
func _notification(what: int) -> void               # loss, re-arm and the launch guard per Decision 8
## The only code that reads InputEvent subclasses; HudModals calls it too. Returns null for anything that is not a
## ScreenTouch or ScreenDrag (every InputEventMouse* is null). ScreenTouch: pressed and not canceled -> PRESS;
## not pressed and canceled -> CANCEL; not pressed -> RELEASE; pressed and canceled -> null. ScreenDrag -> MOVE.
static func read_pointer(event: InputEvent) -> PointerSample
```

`Battle.set_input_cancel` still receives `resolver.cancel` (ADR-0001). It does not clear `_forwarded`; the leftover indices are harmless, because the resolver drops moves and releases in Idle and drops other-index calls while another pointer is active.

### Implementation Guidelines
- `project.godot` **must** contain `display/window/size/viewport_width=540`, `viewport_height=960`, `display/window/stretch/mode="canvas_items"`, `display/window/stretch/aspect="keep"`, `input_devices/pointing/emulate_touch_from_mouse=true` and `emulate_mouse_from_touch=false`. ADR-0007's lint greps all six; the adapter checks them at boot. Every device run **must** use these six.
- Only `InputAdapter.read_pointer` **may** test `InputEvent` subclasses or read their fields. `InputAdapter` and `HudModals` **must** call it and **must never** name `InputEventMouse*`, `InputEventKey` or `event.device` in gameplay or HUD code.
- The adapter **must** read presses in `_unhandled_input` and moves, releases and cancels in `_input`; it **must never** read a press in `_input` and **must never** read a move or release in `_unhandled_input`. It **must never** call `set_input_as_handled()`.
- The adapter **must** forward `event.position` unchanged; the wrapper **must never** gain a `Camera2D`, a canvas-transform change or a scale, and the adapter **must never** transform event positions.
- The adapter **must** pass every press inside the accept bounds to the resolver and **must never** drop a second finger itself; it **must** drop moves and releases of indices it did not forward. `PointerGate` and `HudLogic` **must** call `DisplayContract.accepts` and **must never** re-implement the bounds.
- A `canceled` touch **must** go to `cancel_pointer` and **must never** be treated as a release; the adapter **must never** synthesise a release or a tap from a cancel, a pause or a resume.
- The adapter **must** run with `process_mode = PROCESS_MODE_ALWAYS` and **must** handle lifecycle in its own `_notification`; no other class **may** handle `NOTIFICATION_APPLICATION_*` or `NOTIFICATION_WM_WINDOW_FOCUS_*` for pause or cancel. Loss notifications **must** be ignored until the window has been seen focused (Decision 8).
- A loss **must** produce one `lifecycle_paused`; a resize **must never** produce one. A pause **must never** use `SceneTree.paused`.
- `Viewport.size_changed` **must** be connected by the wrapper in `setup()`; `NOTIFICATION_WM_SIZE_CHANGED` **must never** be used. The adapter **must never** contain a lambda (`func(`); ADR-0007's lint covers `src/presentation/input/`.
- One `CanvasLayer` child of the wrapper **must** hold every battle HUD `Control`; a HUD `Control` **must never** be under a `Node2D`. `HudModals` **must** be the only `MOUSE_FILTER_STOP` Control in the battle scene; every other HUD Control (a `Button` included) **must** be `MOUSE_FILTER_IGNORE`.
- Modals **must** be built once and toggled with `visible`; a modal **must never** be freed from its own handler.
- Layout **must** use the true `FieldInsets`; the HUD **must never** clamp an inset. The accept bounds **must** be computed from the same `FieldInsets` object `HudLogic` receives.
- The viewport size, stretch keys and minimum width **must** live in `DisplayContract` only (HUD layout constants relative to 540 or 960 are not covered by this rule).
- `PointerGate` **must** extend `RefCounted` and **must never** touch a node, `DisplayServer` or `Engine`, so tests run headless. The adapter is the only caller of `DisplayServer`.
- Nothing under `src/` **may** test `event.device == 0`.

## Alternatives Considered

### Alternative 1: Reveal the extra height of a tall phone (`keep_width` or `expand` with an origin offset)
- **Description**: The viewport keeps 540 units of width and grows taller with the phone; the field is shifted down so the extra height sits above the HUD band, which would hide the off-side-edge entry.
- **Pros**: No letterbox; a 360x800 dp phone uses all 800 dp instead of 640.
- **Cons**: `expand` was measured and grows the long axis only from origin (0, 0), extra at the bottom or right (549x960, 540x1080), so the extra shows below, not above, and shows enemies walking off the bottom; moving it above needs an origin offset on every position, which ends canvas units equal to field units; `keep_width` was not probed; it changes the aspect key and the bar-absorption property of the insets.
- **Rejection Reason**: Out of scope for MVP and the Vertical Slice unless D6 shows the bars are unacceptable. It supersedes Decisions 5, 6 and 7 and four guidelines through a new ADR; the cost of waiting is 18 to 20 percent of a tall screen as bars.

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
- **Cons**: Two code paths, two sets of tests (and the fallback if emulation ever emits a touch for non-left buttons); desktop no longer exercises the phone path; pointer index for mouse must be invented; HudModals must do the same.
- **Rejection Reason**: Desktop testing through the touch path is the reason emulation exists (Input Rule 5, TR-input-005).

### Alternative 9: Leave `emulate_mouse_from_touch` at its default (on)
- **Description**: Touches also produce mouse events, as measured in the spike.
- **Pros**: None over the adopted setting; a `Button` receives raw touches either way (probe).
- **Cons**: A second event per press on index 0 (device -1 before the touch), which every consumer must ignore; no built-in widget is used.
- **Rejection Reason**: Off removes the duplicate at its source; the probe measured the off state and the routing rows are unchanged.

## Consequences

### Positive
- The adapter's rules are three small testable pieces and a thin Node; most of TR-input-003 and TR-input-006 is provable headless.
- The same translator serves the adapter and `HudModals`, so the two cannot disagree on event family or on `canceled`.
- `keep` makes one layout with two measured oracles, and absorbs insets into bars on tall phones.
- Presses are blocked by routing, not by code, so a modal can never leak a tap beneath.
- The desktop build exercises the phone path, so the resume and cancel code runs every day.

### Negative
- Tall phones show letterbox bars, 18 to 20 percent of the screen at 360x800 and 390x844 dp, until the Mobile Platform GDD revisits the reveal.
- The launch guard relies on `DisplayServer.window_is_focused()`, measured only on an unfocused desktop launch until D9a and D9b.
- Several phone premises are unverified until the device run; QQ-22 stays open.
- `HudModals` shares the adapter's static `read_pointer`, so it depends on the adapter's file (still one-way: presentation to presentation).
- Two classes and two value types where the architecture sketch showed one class.

## Risks
- **Real touches differ from emulation** (index reuse, `canceled` semantics, event order). Mitigation: D1, D2, D3, D8; every rule that depends is in `PointerGate` or `read_pointer`, so a change touches one class. Trigger: D1 to D4 before the first phone build or the Vertical Slice gate, whichever comes first.
- **The Android or iOS pause notification differs from the desktop one.** Mitigation: all three loss notifications map to one deduplicated path; D5 picks the real set; the Flow row is in the sync section.
- **Safe-area rectangle units are wrong.** Mitigation: insets are zero until D6; the formula takes a transform so a unit change is one test.
- **A STOP or PASS Control (a `Button` included) creeps over the field.** Mitigation: ADR-0007 scene lint on `mouse_filter` of everything under the HUD layer.
- **`keep` bars waste screen on tall phones.** At the minimum width the scale is width-limited (0.667), where the 48 dp targets were sized. A height-limited window (wider than 9:16, or a short split-screen window) has a scale of `h/960`, which is lower than `w/540`, and its targets shrink; `field_width_dp` is the guard (Decision 6) and the multi-window case is in D6. The reveal needs a new ADR.
- **Letterbox bars show field art (L5).** Mitigation: D6 check; a clip rect is ADR-0011's.
- **The launch guard misfires**, for example `window_is_focused()` true at `_ready` on a focused launch with 1005 and 2017 still to come. Mitigation: D9a; fallback is also ignoring losses before the first `_process`.
- **A rejected-zone boundary mismatch with a GDD test.** Mitigation: one static `DisplayContract.accepts`; the boundary is in the sync section.
- **A lost release strands a gesture.** Mitigation: Input Rule 1's replacement by the next press; `cancel_all()` on pause and resize.
- **The desktop-only evidence accepts premises early** (departure from `architecture.md` Priority). Mitigation: ADR-0004 and ADR-0008 record a provisional premise; the deadline in Decision 10.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-002: one thin adapter node is the only engine-facing input code; maps touch and mouse events to the five calls in 540x960 field units | Decisions 1, 3, 5: `InputAdapter` with `PointerGate`; `event.position` is already in field units (spike); `HudModals` calls the adapter's static `read_pointer` |
| input-gesture-resolver.md | TR-input-003: every forwarded press is followed by a release or cancel; STOP Control; `canceled` honoured | Decisions 2, 3: presses in `_unhandled_input`, moves and releases in `_input`; `canceled` goes to `cancel_pointer`; D3, D4 |
| input-gesture-resolver.md | TR-input-004: `PROCESS_MODE_ALWAYS`; cancel on pause, focus loss, resize; one lifecycle signal | Decision 8: `lifecycle_paused`, `viewport_resized`, `cancel_all()`; D5 |
| input-gesture-resolver.md | TR-input-005: one event family; no duplicate presses; mouse index never collides; non-left buttons dropped | Decision 4: emulation settings, mouse events ignored, only touch read; right and middle clicks emit no touch (probe), so no code is needed; the fallback is Alternative 8 and reopens this ADR |
| input-gesture-resolver.md | TR-input-006: edge and safe-area rejection via `get_display_safe_area()` converted to field units | Decision 7: `DisplayContract.accepts` and the conversion formula; zero insets until D6; the safe-area API's phone behaviour is NOT SOURCEABLE |
| input-gesture-resolver.md | TR-input-013: burst, arc and world targets are discs; HUD Controls consume events before the adapter | Decisions 2, 9: only `HudModals` is STOP; other HUD Controls IGNORE |
| input-gesture-resolver.md | TR-input-016: min width 360 dp, stretch keeps field units equal to viewport units, no Camera2D, cancel on resize | Decisions 5, 6, 8: `keep` on 540x960, `field_width_dp` guard (field width, not window width), resize hook; the dp read is NOT SOURCEABLE |
| game-state-stage-flow.md | TR-state-010: focus loss or backgrounding enters Paused, ticks stop, input cancels, a resume tap reaches nothing beneath | Decision 8: notification table, once per loss, `lifecycle_paused` to `Flow.pause`; tick stop and accumulator are ADR-0004's |
| battle-hud.md | TR-hud-002: Result and Paused screens are full-screen modal Controls, built once, consuming events before the adapter, hidden in their own handler | Decision 9; spike rows on STOP and hiding |
| battle-hud.md | TR-hud-003: HudLogic's modal press model repeats the adapter's rules; lifecycle and focus loss clear it | Decision 9 decides the architectural clauses (shared `read_pointer`, shared `DisplayContract.accepts`, `modal_cancel` wired to both signals); the rest is Battle HUD Rule 2 and criterion 21, implemented by `HudLogic` |
| battle-hud.md | TR-hud-014: layout in 540x960 field units with insets converted to field units | Decisions 6, 7: `keep`, `FieldInsets`, mapper, and the inset hand-off table |

## Performance Implications
- **CPU**: Per event: one type test, one small `PointerSample` allocation, one `PackedInt32Array` search over at most a few entries and one resolver call. Cost is negligible against the 16.6 ms frame; no measurement is claimed before D1.
- **Memory**: A few small objects per battle, freed with the wrapper.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
Greenfield: `src/` holds no `.gd` file. Add the six display and input keys to `project.godot` (currently only `[application]` and `[rendering]`). Create `src/presentation/input/` with the classes above and `tests/unit/input/` fixtures. Update the spike's `project.godot` and `README.md` to the six keys before any device run, and extend it with the manual mode for D1 to D10. Prototypes are not migrated. On acceptance apply the "GDD and Registry Sync at Acceptance" section.

## Validation Criteria
- `PointerGate` fixtures with a recording fake resolver: a press inside bounds forwards; at margin 36, x = 35.9 is dropped, x = 36 forwards, x = 504 forwards and x = 504.1 is dropped; with `I_top` 20, y = 20 forwards and y = 19.9 drops; a move of a never-forwarded index drops; a release of a never-pressed index drops; two fingers forward two presses and the fake logs both; after `cancel_all()` a held finger's move and release drop; a `CANCEL` calls `cancel_pointer` and never `release`; a repeated press of one index forwards twice; a non-finite position drops and reports (TR-input-003, Input fixtures 5, 17, 36).
- `read_pointer` fixtures: every `ScreenTouch` combination of `pressed` and `canceled`, a `ScreenDrag`, a `MouseButton` (device 32 and device -1) and a key event produce the table in Key Interfaces (TR-input-005).
- `DisplayContract.accepts` is the only bounds function: a grep finds no second copy under `src/`; `HudLogic` fixtures call it (TR-hud-003).
- `DisplayContract` tests: `field_width_dp(360, 800)` is 360 and passes; `field_width_dp(412, 400)` is 225 and fails; `MIN_WIDTH_DP` passes `target_ok` for radius 36 (`2 x 36 x 360 >= 25920`) and `MIN_WIDTH_DP - 1` fails it, so the test checks the derivation of 360 (TR-input-016).
- After D6 only: the safe-area formula fixtures from the measured transforms (500x1000: safe y = 100 px gives `top` 47.57, y = 40 gives 0; 600x1048: `left` 0), compared to 0.01 field units (TR-input-006, TR-hud-014).
- ADR-0007's lint: the six `project.godot` keys, no `Camera2D` in the wrapper scene, every `Control` under the HUD `CanvasLayer` is IGNORE except `HudModals`, no HUD `Control` with a `Node2D` ancestor, no `func(` under `src/presentation/input/`.
- Scene tests reproducible headless: a notification is delivered with `adapter.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` and a resize with `get_viewport().size_changed.emit()`. A loss when armed gives one `lifecycle_paused`; a second loss before a re-arm gives none; a loss before the window has been seen focused (fake `window_is_focused` false) gives none; `size_changed` gives one `viewport_resized` and no `lifecycle_paused` (TR-state-010, TR-input-004).
- Routing re-run on the adopted keys: the echo-off probe (4.7.2 probe, 2026-11-05, prototypes/adr-0003-spike/echo-off-probe/) is the retained evidence for the callback split; D3 and D4 repeat it on devices.
- D9a: a desktop cold launch with the window focused shows no Paused (retained screenshot in `production/qa/evidence/adr-0003-device-run/`).
- D1 to D10 results retained under `production/qa/evidence/adr-0003-device-run/`; QQ-22 closes when D1 to D4 pass on both platforms.
- The ADR is wrong if D1 shows events delivered after the frame's `_process` on a device, or D3 shows `_input` missing the moves of a live gesture under a STOP Control.

## NOT SOURCEABLE
These are not covered by `docs/engine-reference/godot/`, the spike or the echo-off probe, are not asserted anywhere above, and are all under Verification Required. Items the probe sourced on desktop (the callback split with the echo off, `Button` behaviour, right and middle click, the agile-flushing key, bar-press coordinates, `expand` geometry, `window_is_focused()` on an unfocused launch) moved to the verified tables.
- NOT SOURCEABLE: `DisplayServer.get_display_safe_area()` space, units and origin on Android and iOS, and what Android edge-to-edge reports.
- NOT SOURCEABLE: whether `NOTIFICATION_APPLICATION_PAUSED` and `_RESUMED` arrive on Android and iOS, and which of 2017, 1005 and 2015 fire for each cause.
- NOT SOURCEABLE: `ScreenTouch.index` assignment and reuse on real devices, and when `canceled` is set (the property exists; the spike only read it).
- NOT SOURCEABLE: the value an absent `display/window/stretch/*` key resolves to in an existing 4.7 project, which is why the keys are written explicitly.
- NOT SOURCEABLE: `keep_width`, and any field-origin offset.
- NOT SOURCEABLE: how to read the window size in dp.
- NOT SOURCEABLE: `DisplayServer.window_is_focused()` on a focused desktop launch and on Android and iOS (D9a, D9b), the value of `agile_event_flushing` on a device build (D1), and emulation behaviour on a device (D10).
- NOT SOURCEABLE: the role of `get_canvas_transform()` under stretch (values not recorded), and when a lifecycle notification is dispatched relative to `_process`.

## GDD and Registry Sync at Acceptance
Apply when this ADR is Accepted. Each line is a clause change; no document is edited by this ADR while it is Proposed.
- **`tr-registry.yaml`**: TR-input-002 add "HudModals calls the adapter's static `read_pointer`, so translation exists once". TR-input-005 add "non-left buttons emit no touch under emulation (4.7.2 probe)". TR-input-006 replace "via DisplayServer.get_display_safe_area()" with "from the platform safe area (source fixed by ADR-0003 D6; zero until then)". TR-input-016 replace "Minimum width 360 dp by runtime guard" with "field width in dp, min(width_dp, height_dp x 540/960), at least 360 by runtime guard". TR-hud-002 replace "that consume every event before the Input adapter sees it" with "that take every press before the Input adapter sees it (moves and releases of a gesture already under way still reach the adapter through `_input`)". Stamp `revised:` on each.
- **Input GDD**: Rule 12 and the Edge Cases: "inside the margin" becomes "strictly inside (a press exactly on the bound is accepted)". The "Becomes an ADR" note (line 78) and the Open Questions row for the adapter path: answered by ADR-0003 Decisions 2 to 5, device run owed.
- **Battle HUD GDD**: Rule 2 same boundary wording; the Technical director note on stretch (Detailed Design) and the Open Question "Does the stretch mode change every inset check?": answered, `keep`, insets in field units after bar absorption (Decision 6, 7).
- **Enemy & Wave GDD**: the Open Question "Stretch mode and the minimum supported width": answered, `keep` and the 360 dp field-width guard; L5 conditional on D6's bar check.
- **Flow GDD**: the deferred row "Lifecycle mapping (Rule 17)" and the Open Question on the pause mechanism cite ADR-0003 Decision 8 (Flow-state pause, no `SceneTree.paused`; device run D5 owed); Rule 17's "ADR-0003 checks" becomes "D9a records".
- **`architecture.md`**: B3 replace the NEEDS VERIFICATION block with Decisions 1 to 9 of this ADR; Data Flow 6 replace "(notification names NEEDS VERIFICATION, ADR-0003)" with the Decision 8 table; the Priority paragraph "ADR-0003 starts with a short verification spike on a device" becomes "desktop spike 2026-11-04 and echo-off probe 2026-11-05; device run D1 to D4 before the first phone build or the Vertical Slice gate"; the ADR-0011 paragraph gains "the HUD Controls sit in the one `CanvasLayer` ADR-0003 Decision 9 places"; the ADR-0006 paragraph gains the QQ-07 names. QQ-02 closed (device bars check D6), QQ-06 desktop part closed with D1 to D5 owed, QQ-12 rule and numbers handed to the Mobile Platform GDD (stays open), QQ-22 stays open.
- **ADR-0004 and ADR-0008 (when written)**: Depends On row marks ADR-0003 as a provisional premise until D1 and D3 pass.
- **`docs/registry/architecture.yaml`**: append the candidate entries (adapter callback split, event family, stretch, CanvasLayer parenting, lifecycle contract, two forbidden patterns).

## Related
- `docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md`: Decisions 4 and 5, Verification item 3 (D8).
- Echo-off probe: `prototypes/adr-0003-spike/echo-off-probe/`.
- `docs/architecture/architecture.md` v4: Data Flow 1 and 6, B2, B3, QQ-02, QQ-06, QQ-12, QQ-22.
- `design/gdd/input-gesture-resolver.md` Rules 1, 7, 10, 12; Adapter contract; Edge Cases on resize and cancel.
- `design/gdd/game-state-stage-flow.md` Rule 17; Paused state.
- `design/gdd/battle-hud.md` Rule 2; Layout and the layout checks.
- `docs/engine-reference/godot/modules/input.md`, section Verified on 4.7.2; spike `prototypes/adr-0003-spike/`.
