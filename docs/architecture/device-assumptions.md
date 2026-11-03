# Device Assumptions: iPhone 16, 17 and 18 (Godot 4.7.2)

## What this is

- These are **best guesses from memory. They are NOT sourced and NOT tested.** No one on the team has a phone, so no device build has run.
- They stand in for the phone spike (GF5, A7) so that ADR-0006, ADR-0007 and ADR-0008 can move to Accepted. Each ADR cites this file in place of the spike.
- The first device build replaces every guess here with a measured fact (see the checklist at the end).
- **Any check that fails revises its ADR.** A failed check is not a footnote: the owning ADR is amended, using the fallback it already names, before the next story that depends on it closes.
- Scope of the guesses: Godot 4.7.2, GDScript, 2D portrait, base field 540 x 960, stretch `canvas_items` + `expand`, Mobile renderer, `emulate_mouse_from_touch = false` and `emulate_touch_from_mouse = false`, input read in `_input`.
- Android stays in scope. Android-only items carry an Android guess and the note "not tested on iPhone; Android stays in scope".

## 1. Reference devices

Every value in this table is **memory, unverified**. Insets are portrait, in points.

| Device | Logical (pt) | Scale | Native (px) | Refresh | Top inset (Dynamic Island) | Bottom inset (home indicator) | Chip |
|---|---|---|---|---|---|---|---|
| iPhone 16 | 393 x 852 | 3x | 1179 x 2556 | 60 Hz | 59 | 34 | A18 |
| iPhone 16 Plus | 430 x 932 | 3x | 1290 x 2796 | 60 Hz | 59 | 34 | A18 |
| iPhone 16 Pro | 402 x 874 | 3x | 1206 x 2622 | 120 Hz ProMotion | 62 | 34 | A18 Pro |
| iPhone 16 Pro Max | 440 x 956 | 3x | 1320 x 2868 | 120 Hz ProMotion | 62 | 34 | A18 Pro |
| iPhone 17 | 402 x 874 | 3x | 1206 x 2622 | 120 Hz ProMotion | 62 | 34 | A19 |
| iPhone 17 Air | 420 x 912 | 3x | 1260 x 2736 | 120 Hz ProMotion | 62 (lowest confidence in this table) | 34 | A19 Pro |
| iPhone 17 Pro | 402 x 874 | 3x | 1206 x 2622 | 120 Hz ProMotion | 62 | 34 | A19 Pro |
| iPhone 17 Pro Max | 440 x 956 | 3x | 1320 x 2868 | 120 Hz ProMotion | 62 | 34 | A19 Pro |
| iPhone 18 family | **No figures.** | | | | | | |

**iPhone 18:** the model has no figures for any iPhone 18 model. Assume each one matches the iPhone 17 model of the same size (logical points, scale, insets, refresh). No iPhone 18 number appears in this file, and none may be added until one is measured or sourced.

## 2. Derived field numbers

Formulas (ADR-0006 sections 2 and 6, `expand`, field centred and bottom-anchored):

- field scale `s = width_pt / 540` (points per field unit)
- visible height in field units `H = 540 x height_pt / width_pt`
- top margin above the field `M = H - 960`
- an inset in field units `= inset_pt / s = inset_pt x 540 / width_pt`
- `I_top = max(0, top_inset - M)`, because the field starts `M` below the top
- `I_bottom = bottom inset in field units`, because the field ends at the screen bottom
- burst centre `y = clamp(888 - I_bottom, 816, 888)`, radius 48

**Worked example, iPhone 16 (393 x 852 pt):**

- `s = 393 / 540 = 0.7278` pt per unit
- `H = 540 x 852 / 393 = 1170.7` units; `M = 1170.7 - 960 = 210.7`
- top inset `59 x 540 / 393 = 81.1` units, inside the 210.7 margin, so `I_top = 0`
- bottom inset `34 x 540 / 393 = 46.7` units, so `I_bottom = 46.7`
- burst `y = clamp(888 - 46.7, 816, 888) = 841.3`; its lowest point is `841.3 + 48 = 889.3`
- safe area ends at `960 - 46.7 = 913.3`; clearance `913.3 - 889.3 = 24.0` units, or `24 x 0.7278 = 17.5` pt
- without the shift the button would reach `888 + 48 = 936`, which is under the home indicator. The shift is needed.

| Device | s (pt/unit) | H (units) | Top margin M | Top inset (units) | I_top | I_bottom (units) | Burst y | Button bottom | Safe end | Clears? |
|---|---|---|---|---|---|---|---|---|---|---|
| 16 | 0.7278 | 1170.7 | 210.7 | 81.1 | 0 | 46.7 | 841.3 | 889.3 | 913.3 | Yes, 24 u (17.5 pt) |
| 16 Plus | 0.7963 | 1170.4 | 210.4 | 74.1 | 0 | 42.7 | 845.3 | 893.3 | 917.3 | Yes, 24 u (19.1 pt) |
| 16 Pro, 17, 17 Pro | 0.7444 | 1174.0 | 214.0 | 83.3 | 0 | 45.7 | 842.3 | 890.3 | 914.3 | Yes, 24 u (17.9 pt) |
| 16 Pro Max, 17 Pro Max | 0.8148 | 1173.3 | 213.3 | 76.1 | 0 | 41.7 | 846.3 | 894.3 | 918.3 | Yes, 24 u (19.6 pt) |
| 17 Air | 0.7778 | 1172.6 | 212.6 | 79.7 | 0 | 43.7 | 844.3 | 892.3 | 916.3 | Yes, 24 u (18.7 pt) |
| 18 family | as the 17 model of the same size | | | | | | | | | |

Notes:

- The clearance is always 24 units while the clamp is not hit: `(960 - I_bottom) - (888 - I_bottom + 48) = 24`. The clamp (816) bites only when `I_bottom > 72` units, about 52 pt on an iPhone 16. No listed iPhone comes near it.
- The Dynamic Island never reaches the field on these phones: every top inset sits inside the top margin, so `I_top = 0` everywhere.
- The burst disc (radius 48 units) is about 70 to 78 pt across, above Apple's 44 pt minimum.
- Every phone is wider than 360 dp (393 pt minimum), so the D10 guard never logs on them.
- In pixels (for D4), the bottom inset is about 102 px at 3x.

## 3. Verification items

Confidence: **high** (long-standing behaviour, well remembered), **medium** (remembered, details may have moved), **low** (a guess).

### ADR-0006 (D1 to D12)

| Item | Question | Best guess (iOS, these iPhones) | Conf. | If wrong (ADR's own fallback) | First device build check |
|---|---|---|---|---|---|
| D1 | With no stretch keys, which mode applies? | `disabled`; I do not recall the default changing. Differs from the ADR's memory, but moot. | medium | Moot: the ADR writes the keys. | Desktop: open Project Settings after the display-keys story. |
| D2 | Is an event `position` in base viewport units under `canvas_items`? | Yes. The window applies the inverse stretch transform before `_input`, so positions run 0 to 540 wide. | medium | `FieldSpace.event_to_canvas` holds the inverse stretch transform; `make` computes it. | Tap the four field corners; log raw `position`. |
| D3 | Where does `expand` put the extra area; how is it read? | `get_viewport().get_visible_rect()` gives origin (0, 0), size about 540 x 1171; the extra area is below (and right on wide screens). | medium | `FieldSpace` computes the origin from the visible rect, so placement survives. | Log the visible rect at build. |
| D4 | Safe-area call and units; Android edge-to-edge default? | iOS: `DisplayServer.get_display_safe_area()` returns `Rect2i` in screen pixels (about y 177 to 2454 on an iPhone 16). Android: edge-to-edge is an opt-in export or project option, off by default. Android not tested on iPhone; Android stays in scope. | medium (iOS), low (Android) | `SafeAreaSource` returns authored per-platform insets from the Options record. | Log the rect; draw it as an outline; screenshot. |
| D5 | Which notification fires on resize or safe-area change? | `Viewport.size_changed` (and `Window.size_changed`) on resize. No separate safe-area signal. On a portrait-locked iPhone neither fires during play after start. | medium | Insets are read at build and on each resize only (ADR's stated fallback). | Log every `size_changed` from launch to quit. |
| D6 | Does a full-screen STOP Control get the touch press and release, and stop them before `_unhandled_input`? | Yes: the viewport routes `InputEventScreenTouch` to the Control under the point, and STOP marks it handled. Since input is read in `_input`, the adapter's press block is the main route anyway. | medium | The `modal_sink` fallback route (section 5) becomes primary. | Open PausedScreen; tap; log `_gui_input` and `_unhandled_input`. |
| D7 | Does an IGNORE Control pass touch through? | Yes. | high | Set the HUD art Controls to non-Control nodes. | Tap through the HUD art; the adapter logs the press. |
| D8 | Key names and portrait value? | `display/window/size/viewport_width`, `viewport_height`, `display/window/handheld/orientation`; portrait = 1. | high | Rename the keys in the story. | Desktop: Project Settings. |
| D9 | Does Mobile start and hold 30 fps; does 4.7.2 fall back to Compatibility without Vulkan? | iOS: yes, Mobile runs on Metal (native Metal driver since 4.4, memory) and holds 60 or 120 fps on A18/A19 with ease. Android low end: unknown. `rendering/rendering_device/fallback_to_opengl3` exists. Android not tested on iPhone; Android stays in scope. | high (iOS), low (low-end Android) | Switch to Compatibility, amend section 9. | Run a full wave; read the FPS monitor. |
| D10 | Which API gives width in dp? | `DisplayServer.screen_get_scale()` returns 3.0 on these iPhones; width px / 3 = points (393 to 440). `screen_get_dpi()` returns a table value, less useful. | medium | The guard only logs; swap the API. | Log both calls. |
| D11 | Does `CanvasLayer.layer` order drawing and input; does `offset` use base units? | Yes to both. | high | Reorder layers by tree order. | Overlap two layers; screenshot. |
| D12 | Emulation key names and effect with both false? | Names are right. With both false, a phone touch arrives as `InputEventScreenTouch` only, a desktop click as `InputEventMouseButton` only. | high | Family lock keeps one touch from firing twice. | Log the class of each event for one tap. |

### ADR-0007 (I1 to I11)

| Item | Question | Best guess | Conf. | If wrong (ADR's own fallback) | First device build check |
|---|---|---|---|---|---|
| I1 | Does `_input` see every event before any Control, unstoppable by Controls? | Yes. Order: `_input`, GUI, `_shortcut_input`, `_unhandled_key_input`, `_unhandled_input`. | high | ADR-0007 Risks. | Log order in `_input` and a Control's `_gui_input`. |
| I2 | Touch class and field names? | `InputEventScreenTouch` (`index`, `position`, `pressed`), `InputEventScreenDrag` (`index`, `position`, plus `relative`, `velocity`). | high | Rename in the adapter. | Log one tap and one drag. |
| I3 | Cancel flag on iOS touches-cancelled? | `InputEventScreenTouch.canceled` and `is_canceled()` exist (about 4.2). iOS `touchesCancelled` sends `pressed = false`, `canceled = true`. | medium | The design treats an unflagged release from an edge as a release; the gate's edge reject margin limits harm. | Hold a finger, swipe down Control Center; log the event. |
| I4 | Multi-touch indexes? | iOS assigns the first free slot from a small fixed table (memory: 32): first finger 0, second 1, reused only after lift. | medium | The gate keys on index; a larger index changes nothing below 1024. | Two-finger tap; log indexes. |
| I5 | Emulation key defaults and emulated device id? | `emulate_mouse_from_touch` default true, `emulate_touch_from_mouse` default false. Emulated mouse events carry `DEVICE_ID_EMULATION` (-1). | high (keys), medium (device id) | The family lock handles a double event. | With the key on in a test build, log `device`. |
| I6 | With mouse-from-touch off, do Controls take touch, and do stock `Button`s still work? | **Split guess.** A full-screen Control gets `InputEventScreenTouch` in `_gui_input`: medium. Stock `Button`s: I believe `BaseButton` reacts to mouse buttons and `ui_accept`, not raw screen touch, so they **may not respond** with emulation off. | **low** | ADR's own: the section 6 emulation decision flips (mouse-from-touch on) and the family lock carries it. | Tap a stock Button on the title screen with both keys false. |
| I7 | Desktop: release outside the window reaches `_input`; `button_mask`, `MOUSE_BUTTON_MASK_LEFT` names? | Yes on Windows, macOS and X11 (the OS captures the mouse during a drag). Names right. | medium (release), high (names) | Closed on desktop by the first adapter story. | Desktop drag out and release. |
| I8 | Does `PROCESS_MODE_ALWAYS` keep `_input` running while paused? | Yes. | high | Closed on desktop. | Desktop pause test. |
| I9 | Android back gesture and bar swipe: cancel or nothing, never a plain release? | Android 10+ gesture nav: the app gets the touch down, then `ACTION_CANCEL` once the system claims the gesture, which Godot maps to a cancelled touch. Not tested on iPhone; Android stays in scope. iOS: home swipe from the bottom edge gives touches-cancelled. | **low** | The gate's edge reject margin drops presses that start at the edge. | Android: back-swipe from a side edge. iPhone: home swipe with a finger down. |
| I10 | Focus loss with a finger down: cancel, release or nothing? | iOS: touches-cancelled when the app resigns active (call, Control Center, Siri). | medium | ADR says the design holds in all three cases. | Hold a finger; pull Control Center; return. |
| I11 | Event space in `_input` matches D2? | Yes, same as D2. | medium | `FieldSpace.event_to_canvas` absorbs it. | Same as D2. |

### ADR-0008 (L1 to L10)

| Item | Question | Best guess | Conf. | If wrong (ADR's own fallback) | First device build check |
|---|---|---|---|---|---|
| L1 | Which notifications fire for home, app switch, lock, system dialog, return? | iOS: resign active gives `NOTIFICATION_APPLICATION_FOCUS_OUT`; enter background gives `NOTIFICATION_APPLICATION_PAUSED`; return gives `RESUMED` then `FOCUS_IN`. Home, app switch and lock: FOCUS_OUT then PAUSED. Control Center, notification pull, system alert: FOCUS_OUT only. | medium | Map pause to FOCUS_OUT, which fires in every case. | Log every notification for each of the five actions. |
| L2 | Do they reach a deep node's `_notification`? | Yes: the tree propagates application notifications to every node. | high | Forward from AppRoot. | Log in the wrapper. |
| L3 | Android back as `NOTIFICATION_WM_GO_BACK_REQUEST`; `application/config/quit_on_go_back`? | Yes to both names; the notification arrives even with a focused Control. No back button on iPhone. Not tested on iPhone; Android stays in scope. | high (names), medium (focus) | Read `ui_cancel` as a second route. | Android: press back in battle and in Paused. |
| L4 | Desktop close request; no quit notification when iOS kills the app? | Desktop: `NOTIFICATION_WM_CLOSE_REQUEST` reaches every node when `auto_accept_quit` is false; `quit()` then ends it. iOS: a suspended app is killed with no notification. | high | Write records on FOCUS_OUT or PAUSED, never only on quit. | Swipe the app away from the switcher; check the record. |
| L5 | When does `Window.size_changed` fire, how often per drag? | iPhone portrait-locked: at most once at start; no split screen on iPhone. Desktop: once per OS resize event, many per drag. | medium | The rebuild is idempotent; coalesce to one per frame. | Log count from launch. |
| L6 | `free()` from `AppRoot._process` with no wrapper method on the stack: no locked-object error? When does `queue_free()` run? | No error; locked-object errors come from freeing during the object's own signal emission or call. `queue_free()` runs at the end of the current frame's process step. | medium | Use `queue_free()` and a one-frame gap. | Retry ten times; read the log. |
| L7 | Does `_process` run in the background; first `delta` on return? | It stops while the app is backgrounded on iOS. The first `delta` may be large (the real gap) or small; unknown. | **low** (delta) | ADR-0003 F3 clamp bounds any delta. | Background 10 s; log the first `delta`. |
| L8 | Does a code-made `Label` draw on export with the default font? | Yes: the default font is built into the engine. Default text colour is light grey; set colours in code as the ADR plans. Default size (16) is small at base 540. | high | Ship one font resource. | Trigger the fatal screen; screenshot. |
| L9 | `ResourceLoader.load` on a missing path returns null; broken scene `instantiate()` null; script failure? | Missing path: null plus an error log, game continues. Broken scene: null. A failing script: the scene may load with the script missing, so the root type check is needed. | medium | The ADR already checks the root type. | Point `scene_ref` at a missing file in a test build. |
| L10 | `Time.get_unix_time_from_system()` float; `application/run/main_scene`? | Yes to both. | high | Rename. | Desktop. |

## 4. iPhone risks the ADRs may not cover

1. **120 Hz ProMotion.** On 16 Pro, 17 and later, frames may arrive every 8.3 ms. If `Battle.DT` is 1/60 s, each frame runs 0 or 1 ticks, never 2, so the frame order must not assume a tick every frame. `hud.advance(ms)` gets small deltas; the 100 ms clamp is fine. Views that animate per frame run twice as often. Memory: iOS caps apps at 60 Hz unless the plist sets `CADisableMinimumFrameDurationOnPhone`; whether the Godot 4.7.2 export sets it is unknown. Setting `application/run/max_fps = 60` is an option for battery, not a decision made here.
2. **Metal under the Mobile renderer.** On iOS the Mobile renderer runs on Metal (memory). Memory limits are the OS jetsam limit, not a fixed budget; a large texture atlas could get the app killed with no log. The Mobile Platform ADR owns budgets; measure peak memory in Xcode.
3. **System edge gestures.** Home swipe (bottom edge), Control Center (top right) and Notification Center (top) may deliver a touch down, then a cancelled touch. The burst button sits 24 units above the safe area, but a thumb sliding off it toward the bottom edge can start a home swipe. Godot may or may not defer system gestures on edges; unknown.
4. **Low Power Mode** caps the display at 60 Hz. The game must not tie any rule to frame rate (already true under ADR-0003).
5. **Thermal throttling.** Long sessions on a warm phone drop the frame rate. The tick catch-up cap must hold under 30 fps for minutes, not just a spike.
6. **Dynamic Island and the top margin.** The island sits in the 210-unit top margin. Whatever the Mobile Platform GDD puts there must stay clear of the top 59 to 62 pt.

## 5. First device build checklist

Run on any iPhone 16 or later, with a debug export of Godot 4.7.2 and a small test scene that logs to the debug log and screen. Record each result in the "Result" table below, in this file, then copy the confirmed fact to the place named. Keep each screenshot in `production/qa/evidence/`.

| # | Step | Confirms | Record in |
|---|---|---|---|
| 1 | Launch. Log `get_visible_rect()`, window size, `screen_get_scale()`, `screen_get_dpi()`, and every `size_changed`. | D3, D5, D10, L5 | `docs/engine-reference/godot/` (new display module) |
| 2 | Log `get_display_safe_area()`; draw it and the 540 x 960 field as outlines; screenshot. | D4, section 2 table | same; `production/qa/evidence/` |
| 3 | Tap the four field corners and the burst centre; log raw `position` and `to_field`. | D2, I11 | `docs/engine-reference/godot/modules/input.md` |
| 4 | Tap once, drag once, two-finger tap; log class, `index`, `device`, `pressed`. | I2, I4, D12 | `modules/input.md` |
| 5 | Log the order of `_input`, a Control's `_gui_input` and `_unhandled_input` for one tap on a STOP Control and one on an IGNORE Control. | I1, D6, D7 | `modules/input.md` |
| 6 | Tap a stock `Button` with both emulation keys false. Then repeat with `emulate_mouse_from_touch` true and log both events. | I6, I5 | `modules/input.md`; amend ADR-0007 section 6 if the Button is dead |
| 7 | Hold a finger, then: swipe home, pull Control Center, pull Notification Center. Log each event and its `canceled`. | I3, I9 (iOS part), I10 | `modules/input.md` |
| 8 | For home, app switch, lock, a system alert and return: log every notification and the first `delta` after return. | L1, L2, L7 | ADR-0008 engine reference entry (new lifecycle module) |
| 9 | Swipe the app away in the switcher; relaunch; check the debug record was written before. | L4 | same |
| 10 | Play one full wave; read the FPS monitor and frame time; note 60 or 120 Hz; repeat in Low Power Mode. | D9, risks 1 and 4 | `production/qa/evidence/`; Mobile Platform ADR |
| 11 | Trigger the fatal screen; Retry ten times; screenshot; read the log for errors. | L6, L8, L9 | ADR-0008 entry; `production/qa/evidence/` |
| 12 | Play 15 minutes; watch frame rate and Xcode memory. | risks 2 and 5 | Mobile Platform ADR |
| 13 | Android (any target phone, when one exists): back gesture, bar swipe, back press, edge-to-edge, lowest target fps. | I9, L3, D4 (Android), D9 | `modules/input.md`, ADR-0008 entry |

### Result

| Item | Guess held? | Measured value | Device and iOS version | Date | ADR revised? |
|---|---|---|---|---|---|
| (one row per item, filled by the tester) | | | | | |
