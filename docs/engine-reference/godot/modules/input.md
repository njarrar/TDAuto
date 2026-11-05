# Godot Input — Quick Reference

Last verified: 2026-10-17 (4.7 changes); 2026-02-12 (rest) | Engine: Godot 4.7

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
- **Mouse and keyboard device IDs**: `InputEvent.device` is
  `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (was `0`, which some
  joypads also use). Identify events by type, not `device == 0` (4.7 migration guide: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html)
- **`VirtualJoystick` node**: on-screen joystick with Fixed, Dynamic and
  Following modes
- **Gamepad gyro and accelerometer** readings are available (4.7 release notes: https://godotengine.org/releases/4.7/)

### 4.6 Changes
- **Dual-focus system**: Mouse/touch focus is now separate from keyboard/gamepad focus
  - Visual feedback differs by input method
  - Custom focus implementations may need updating
- **Select Mode keybind changed**: "Select Mode" is now `v` key; old mode renamed "Transform Mode" (`q` key)

### 4.5 Changes
- **SDL3 gamepad driver**: Gamepad handling delegated to SDL library for better cross-platform support
- **Recursive Control disable**: Single property disables mouse/focus for entire node hierarchies

### 4.3 Changes (in training data)
- **InputEventShortcut**: Dedicated event type for menu shortcuts (optional)

## Current API Patterns

### Input Actions (unchanged)
```gdscript
func _physics_process(delta: float) -> void:
    var input_dir: Vector2 = Input.get_vector(
        &"move_left", &"move_right", &"move_forward", &"move_back"
    )
    if Input.is_action_just_pressed(&"jump"):
        jump()
```

### Input Events (unchanged)
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            handle_click(event.position)
    elif event is InputEventKey:
        if event.keycode == KEY_ESCAPE and event.pressed:
            toggle_pause()
```

### Focus Management (4.6 — CHANGED)
```gdscript
# Mouse/touch and keyboard/gamepad focus are now SEPARATE
# Visual styles may differ depending on which input method is active
# If you have custom focus drawing, test with both input methods

# Standard approach still works:
func _ready() -> void:
    %StartButton.grab_focus()  # Keyboard/gamepad focus

# But be aware: mouse hover focus != keyboard focus in 4.6
```

### Gamepad (4.5+ — SDL3 backend)
```gdscript
# API unchanged, but SDL3 provides:
# - Better device detection across platforms
# - Improved rumble support
# - More consistent button mapping

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton:
        if event.button_index == JOY_BUTTON_A and event.pressed:
            confirm_selection()
```

## Common Mistakes
- Not testing both mouse and keyboard focus paths (dual-focus in 4.6)
- Assuming `grab_focus()` affects mouse focus (it only affects keyboard/gamepad in 4.6)
- Using string literals instead of `StringName` (`&"action"`) for action names in hot paths

## Verified on 4.7.2 (desktop spike, 2026-11-04)

Source: `prototypes/adr-0003-spike/` run on macOS with `4.7.2.stable.official`,
`canvas_items`/`keep` stretch, both pointer emulations on, events injected with
`Input.parse_input_event`. Desktop only: Android and iOS behaviour is still owed.

| Premise | Result |
|---|---|
| Input arrives before the frame's ticks | Yes. Buffered events are flushed at the start of the frame, before `_physics_process` and `_process`. An event queued during `_process` of frame N is delivered at the start of N+1. |
| Callback order per event | `_input` on every node, then GUI (`Control.gui_input`), then `_unhandled_input`. A Control that takes the event stops it before `_unhandled_input`. |
| A STOP Control appears over a gesture already under way | Its **moves** go to the Control's `gui_input` and never reach `_unhandled_input`. Its **release** is not taken and reaches `_unhandled_input`. Read moves and releases of an active pointer in `_input` if a modal may open mid-drag. |
| A new press under a visible STOP Control | Press, moves and release all go to the Control. Nothing reaches `_unhandled_input`. |
| A Control hides while it holds a press | Touch focus stays on the hidden Control (its `gui_input` still gets the drag and release). Mouse focus is dropped: the mouse motion and release reach `_unhandled_input`. Ignore releases of an index you never saw pressed. |
| Mouse to touch emulation (`emulate_touch_from_mouse`) | Each mouse event yields an `InputEventScreenTouch`/`ScreenDrag` with `device = -1` (emulation) delivered **before** the mouse event, which keeps `device = 32` (`InputEvent.DEVICE_ID_MOUSE` is 32 on 4.7). |
| Touch to mouse emulation (`emulate_mouse_from_touch`, default on) | Touch index 0 yields an `InputEventMouseButton`/`MouseMotion` with `device = -1` delivered **before** the touch event. A second finger (index 1) yields no mouse event. |
| Event positions under stretch | Already converted to the 540x960 canvas. The screen transform is anisotropic (integer-rounded viewport rect). Window 600x1048: `Transform2D(Vector2(1.090741, 0), Vector2(0, 1.091667), Vector2(6, 0))`. Window 500x1000: `Transform2D(Vector2(0.925926, 0), Vector2(0, 0.925), Vector2(0, 56))`. |
| Resize | `Viewport.size_changed` fired on the same frame as `DisplayServer.window_set_size`. `NOTIFICATION_WM_SIZE_CHANGED` did not reach a child node in the following 4 frames; use the signal. |
| Lifecycle notifications | `NOTIFICATION_APPLICATION_FOCUS_IN` (2016) and `_OUT` (2017) and `NOTIFICATION_WM_WINDOW_FOCUS_IN` (1004) and `_OUT` (1005) all reach child nodes on desktop. At startup the sequence was 2016, 1005, 2017, then 1004 and 2016 once the window got focus: expect a focus-out before the first gesture. `NOTIFICATION_APPLICATION_PAUSED` (2015) and `_RESUMED` (2014) cannot be exercised on desktop. |
| Safe area | `DisplayServer.get_display_safe_area()` returned the screen minus the menu bar on macOS. Meaningless off-device. |
| A Control parented to a Node2D | Gets a zero-size anchorable rect and never receives GUI input. Put HUD Controls under a CanvasLayer or a Control root. |

The spike read `input/buffering/agile_event_flushing`, the wrong key prefix; the
setting is `input_devices/buffering/agile_event_flushing` (see below).

### Echo off: `emulate_mouse_from_touch=false` (4.7.2 probe, 2026-11-05, `prototypes/adr-0003-spike/echo-off-probe/`)

Same project as the spike with the six keys ADR-0003 adopts (`emulate_touch_from_mouse=true`, `emulate_mouse_from_touch=false`), run on macOS 4.7.2.

| Premise | Result |
|---|---|
| Callback split with the echo off | Identical to the rows above. A new touch under a visible STOP Control goes to `_input` and the Control's `gui_input`, nothing to `_unhandled_input`. With the Control shown mid-gesture, drags reach `_input` and `gui_input` (not `_unhandled_input`); the release reaches `_input` and `_unhandled_input`. |
| `Button` with the echo off | Receives the raw `InputEventScreenTouch` in `gui_input`, swallows it before `_unhandled_input`, and fires `pressed` on release. A `Button` is `MOUSE_FILTER_STOP` by default. |
| Left mouse click | `ScreenTouch` index 0, device `DEVICE_ID_EMULATION` (-1), then `MouseButton` device 32. |
| Right click | `MouseButton` only (device 32); no touch is emitted. Middle click not probed. |
| `agile_event_flushing` | Setting is `input_devices/buffering/agile_event_flushing`, default false. |
| Press in a letterbox bar | Arrives with a coordinate outside the field: window (1, 500) at 600x1048 gave (-4.584, 458.0); window (250, 10) at 500x1000 gave (270.0, -49.73). |
| `aspect="expand"` | Never shrinks below 540x960; grows the long axis only, origin (0, 0), extra at the right or bottom: 549x960 at 600x1048, 540x1080 at 500x1000. A bar press at (1, 500) arrives inside the field (x 0.915). `keep_width` was not probed. |
| `DisplayServer.window_is_focused()` | False at `_ready` on a launch where the window never got focus; no focus notification arrived in that run. |
