# ADR-0006: Input Adapter and Resolver Integration

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories that reference this ADR stay `Blocked` while it is `Proposed`.

TD-ADR: not run per ADR; batch review after all ADRs are written.

Engine specialist validation: written by the Godot engine specialist against the 4.7.2 class reference; no separate specialist pass was run.

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

Godot engine specialist (author, autonomous mode). Pending: technical-director batch review, user acceptance.

## Summary

The Input & Gesture Resolver is a plain object that needs one engine-facing node to turn Godot touch events into its five calls without losing a release to a Control or sending a press twice. This ADR puts that node, the InputAdapter, on the `Node._input` path, reads touch events only (mouse becomes touch through `emulate_touch_from_mouse`), never marks an event handled, and replaces "a modal Control hides events from the adapter" with an explicit modal gate that the ShellBuilder wires.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2.stable, installed and pinned) |
| **Domain** | Input |
| **Layer** | Core |
| **Knowledge Risk** | HIGH (4.7 device IDs, 4.6 dual focus, 4.5 recursive mouse behaviour; touch is not covered by the pinned reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/input.md`, `modules/ui.md`, `breaking-changes.md`, `deprecated-apis.md`; official 4.7.2 class reference from `raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/`: `Viewport.xml`, `Node.xml`, `Control.xml`, `InputEvent.xml`, `InputEventScreenTouch.xml`, `InputEventScreenDrag.xml`, `InputEventFromWindow.xml`, `ProjectSettings.xml` |
| **Post-Cutoff APIs Used** | `InputEvent.DEVICE_ID_MOUSE` and `DEVICE_ID_KEYBOARD` (4.7; used only in a guard), `Control.mouse_behavior_recursive` and `get_mouse_filter_with_override()` (4.5; used only in a test) |
| **Verification Required** | The NOT SOURCEABLE items under Validation Criteria. Each blocks acceptance until a desktop run and an Android and iOS phone run record the result |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary (the resolver is a plain sim-style object; the adapter is shell). ADR-0002 App Lifecycle and Composition (AppRoot calls `adapter.cancel()` on focus loss; ShellBuilder builds and frees the adapter; the pause mechanism) |
| **Enables** | ADR-0010 Tower System and ADR-0011 Hero System (TowerInput and HeroInput register discs and listen to resolver signals); ADR-0012 (modal Controls and the top band) |
| **Blocks** | Every Input & Gesture Resolver story; TowerInput, HeroInput and HUD input stories |
| **Ordering Note** | ADR-0008 fixes the coordinate space this ADR forwards. The two must be accepted together: the adapter's "event position is field units" rule holds only under ADR-0008's stretch settings and its no-Camera2D rule |

## Context

### Problem Statement

The resolver (`design/gdd/input-gesture-resolver.md`) is clock-free and engine-free. It is only correct if the adapter keeps one contract: every `press` it forwards is followed by exactly one `release`, `cancel_pointer` or `cancel()` of that index, whatever Controls lie under the finger. Godot offers several input callbacks, two emulation settings and a `canceled` flag on touch events. A wrong pick sends each press twice (touch plus emulated mouse), strands a gesture when a Control swallows the release, or turns an Android touch-cancel into a tap. Master architecture QQ-03 asks which path feeds the adapter and whether a `MOUSE_FILTER_STOP` Control hides events from it.

### Current State

No input code exists. `project.godot` sets no `input_devices/*` key, so `emulate_mouse_from_touch` is `true` and `emulate_touch_from_mouse` is `false` (both defaults, `ProjectSettings.xml`).

### Constraints

- Sim and shell split (ADR-0001): the resolver never sees an `InputEvent`, a viewport or a clock.
- AppRoot is the single receiver of lifecycle notifications and calls `adapter.cancel()` (architecture, Module Ownership, Composition; ADR-0002).
- Positions passed to the resolver are field units on the 540 x 960 field (ADR-0008).
- No autoload; the ShellBuilder builds the adapter and frees it on retry.
- Engine facts come from the 4.7.2 class reference or a device run, never memory.

### Requirements

- One event family reaches the resolver; no press arrives twice.
- A Control under a moving finger can never swallow the active pointer's move or release.
- Result and Paused screens stop a tap from reaching any disc beneath (HUD Rule 2).
- An OS touch-cancel never becomes a release.
- The adapter keeps working while the battle is Paused.
- The edge reject margin and safe-area insets reject presses, not drags that move into them (Input Rule 12).

## Decision

### 1. The adapter reads events in `Node._input`

`Viewport.push_input` (`Viewport.xml`) documents the propagation order: `Node._input`, then `Control._gui_input`, then `_shortcut_input`, `_unhandled_key_input`, `_unhandled_input`, and "if an earlier method marks the input as handled via `set_input_as_handled`, any later method in this list will not be called." `Node._unhandled_input` (`Node.xml`) is "called when an InputEvent hasn't been consumed by `_input` or any GUI Control item." So:

- In `_input`, the adapter sees every event before any Control's `_gui_input`, so a `MOUSE_FILTER_STOP` Control (whose events "are automatically marked as handled", `Control.xml`, `MOUSE_FILTER_STOP`) cannot hide a move or release from it.
- In `_unhandled_input`, a Control that consumed the event would hide it, which is the stranded-gesture case the GDD forbids.

The adapter **must never** call `Viewport.set_input_as_handled()`. Controls then still receive every event, which the modal screens need.

**QQ-03 answer.** The adapter runs before Controls and a STOP Control does not hide events from it, as far as `Viewport.push_input` documents. That method is the documented path for pushed events; that the OS path follows the same order is corroborated by `Node._input` and `Node._unhandled_input` wording but is not stated outright, so it stays a blocking device check (V-1).

### 2. Touch only; mouse becomes touch

- `project.godot` gains `input_devices/pointing/emulate_touch_from_mouse=true`, which "sends touch input events when clicking or dragging the mouse" (`ProjectSettings.xml`).
- `input_devices/pointing/emulate_mouse_from_touch` stays at its default `true`, which "sends mouse input events when tapping or swiping on the touchscreen" (`ProjectSettings.xml`). Controls (Retry, Play again, the Paused panel) then receive mouse events on phones without code of their own.
- The adapter handles `InputEventScreenTouch` and `InputEventScreenDrag` only, and ignores every `InputEventMouse*` event. Desktop and phone therefore share one code path and one pointer index space (`InputEventScreenTouch.index`, "one index = one finger"), so a mouse index can never collide with touch index 0.
- The adapter never compares `event.device` to `0`. Emulated touch from a mouse reports `InputEvent.DEVICE_ID_EMULATION` (`-1`) and a real mouse `DEVICE_ID_MOUSE` (`32`) (`InputEvent.xml`, constants). Neither is needed for routing; a debug-only assert may check that a touch event never carries `DEVICE_ID_MOUSE` or `DEVICE_ID_KEYBOARD`.

The `ProjectSettings.xml` text does not say which mouse buttons `emulate_touch_from_mouse` maps, so right and middle clicks on desktop are a check (V-3). Input Rule 10 ("non-left mouse buttons never reach the resolver") holds only if V-3 passes; if it fails, the adapter adds a mouse-button filter as the fallback in V-3.

### 3. Event to call mapping

| Event | Condition | Call |
|---|---|---|
| `InputEventScreenTouch` | `pressed == true` | edge and inset check (section 5), modal check (section 4), then `press(index, position)` |
| `InputEventScreenTouch` | `pressed == false` and `canceled == true` | `cancel_pointer(index)` |
| `InputEventScreenTouch` | `pressed == false` and `canceled == false` | `release(index, position)` |
| `InputEventScreenDrag` | any | `move(index, position)` |
| anything else | | ignored |

`canceled` is checked before `pressed == false` is treated as a release. Field names are from `InputEventScreenTouch.xml` (`canceled`, `index`, `position`, `pressed`, `double_tap`) and `InputEventScreenDrag.xml` (`index`, `position`). `double_tap` is ignored: the resolver and the chip window own taps.

`InputEventScreenDrag.relative` and `velocity` "are automatically scaled according to the content scale factor" (`InputEventScreenDrag.xml`). The adapter never uses them; it forwards absolute `position` only.

Positions are forwarded unchanged. `position` is "the touch position in the viewport the node is in, using the coordinate system of this viewport" (`InputEventScreenTouch.xml`). Under ADR-0008 (canvas_items stretch, base size 540 x 960, no Camera2D, identity canvas transform) that coordinate system is the field. A press in a letterbox bar arrives outside 0 to 960, which Input's edge cases already allow ("hit test runs unmodified"). That bar presses carry such positions is V-4.

### 4. The modal gate replaces "Controls consume first"

Because the adapter runs before Controls, a tap on the Result or Paused screen also reaches the adapter. The adapter therefore holds one boolean, `modal`, set through `set_modal(on: bool)`:

- `set_modal(true)` calls `cancel()` on the resolver, then drops every later `press` until `set_modal(false)`. Moves and releases are still forwarded; with no active pointer the resolver drops them in Idle (Input transition table, Idle rows).
- The ShellBuilder wires the HUD's modal visibility (HudLogic's "a modal is showing" state, ADR-0012) to `set_modal`. This is a call down from the shell's composition, not a signal into the sim.
- The modal Controls keep `mouse_filter = MOUSE_FILTER_STOP` and `focus_mode = FOCUS_NONE` (`Control.xml`: STOP marks events handled; `FOCUS_NONE` "cannot grab focus"). Each still applies HUD Rule 2: it fires only on a release whose press it saw while Armed, and clears that press on the lifecycle signal.

Result: a tap on a modal never reaches a disc, and a gesture in flight when a modal opens is closed with one `cancel()`, which meets the adapter contract.

### 5. Edge and inset rejection

On `press` only, the adapter drops the event when `x < edge_reject_margin`, `x > 540 - edge_reject_margin`, `y < inset_top` or `y > 960 - inset_bottom`, with insets in field units from ADR-0008's `FieldFrame`. It records the index as rejected and drops that index's later moves and release until its next press. A drag that began elsewhere and moves into a zone is forwarded (Input Rule 12). `edge_reject_margin` comes from the Input catalogue record (ADR-0004) and is injected at `attach`.

### 6. Pause, process mode, resize and lifecycle

- The adapter sets `process_mode = PROCESS_MODE_ALWAYS`, which "keeps processing, ignoring `SceneTree.paused`" (`Node.xml`). This holds whichever pause mechanism ADR-0002 chooses (tree pause or Flow's own early return), so this ADR does not wait on that choice. Whether `_input` delivery is gated by process mode under tree pause is not stated in `Node.xml`; `ALWAYS` covers both outcomes (V-5).
- Lifecycle: the adapter receives no notification. AppRoot calls `adapter.cancel()` (architecture, Composition). This follows the master architecture over the Input GDD, which gives the adapter the notifications (see GDD Sync below).
- Resize: the ShellBuilder connects the root viewport's `size_changed` signal ("emitted when the size of the viewport is changed", `Viewport.xml`) to `adapter.cancel`, so a gesture never spans two coordinate spaces (Input Rule 7, Edge Case "viewport resized mid-gesture"). On a resize ADR-0008's `FieldFrame` also recomputes insets.

### 7. Top band, dual focus and recursive disable

- Every top-band Control sets `mouse_filter = MOUSE_FILTER_IGNORE` on itself. The ADR does not rely on 4.5 recursive behaviour reaching children: each node sets its own value, and a test asserts `get_mouse_filter_with_override() == MOUSE_FILTER_IGNORE` on every band node (`Control.xml`: `get_mouse_filter_with_override` reflects `mouse_behavior_recursive`). This settles the architecture's "unverified recursive disable" note by not depending on it.
- Because the adapter reads in `_input`, the band's filter has no effect on discs. IGNORE exists so the band never takes mouse or touch focus (4.6 dual focus, `modules/ui.md`) and never blocks a modal.
- No Control in the battle takes keyboard focus: `focus_mode = FOCUS_NONE` on all of them. There is no keyboard or gamepad path at MVP (HUD "Deliberately not built").

### Architecture Diagram

```
 OS touch / desktop mouse
        │  emulate_touch_from_mouse=true   (mouse → InputEventScreenTouch/Drag, device -1)
        │  emulate_mouse_from_touch=true   (touch → InputEventMouse* for Controls)
        ▼
 root Viewport propagation (Viewport.push_input order)
   1. Node._input ──▶ InputAdapter (shell Node, PROCESS_MODE_ALWAYS, never set_input_as_handled)
   │                    │ ScreenTouch/ScreenDrag only; edge+inset reject on press; modal gate
   │                    ▼
   │                 InputResolver (RefCounted) press/move/release/cancel_pointer/cancel
   │                    │ signals
   │                    ▼
   │                 TowerInput, HeroInput, HudLogic, GestureLog
   2. Control._gui_input ──▶ Result / Paused (STOP, FOCUS_NONE); top band IGNORE
   ...
 AppRoot (lifecycle) ──▶ adapter.cancel()
 ShellBuilder wires: viewport.size_changed ──▶ adapter.cancel ; HUD modal state ──▶ adapter.set_modal
```

### Key Interfaces

```gdscript
class_name InputAdapter extends Node
## Shell-only. Built and freed by ShellBuilder. The only code that reads InputEvent for gameplay.

## Wires the adapter to one resolver for one battle. frame supplies insets (ADR-0008).
func attach(resolver: InputResolver, edge_reject_margin: float, frame: FieldFrame) -> void
## Closes any gesture in flight. Called by AppRoot (focus loss), by size_changed, by set_modal(true).
func cancel() -> void
## true: cancel() now, then drop new presses until false. Called by ShellBuilder wiring.
func set_modal(on: bool) -> void

func _input(event: InputEvent) -> void   # touch only; never calls set_input_as_handled()
```

Resolver interface: as in architecture API Boundaries, `InputResolver`. See GDD Sync for three members the GDD needs that the architecture block lacks.

`project.godot` keys this ADR requires (written by the ADR-0008 change, not by this ADR's author):

```ini
[input_devices]

pointing/emulate_touch_from_mouse=true
```

`pointing/emulate_mouse_from_touch` is left unset (default `true`).

### Implementation Guidelines

- The adapter **must** read gameplay input only in `_input`. It **must never** use `_unhandled_input`, `_gui_input` or `Input` polling for gameplay.
- The adapter **must never** call `set_input_as_handled()`.
- The adapter **must** handle only `InputEventScreenTouch` and `InputEventScreenDrag` and **must** ignore all `InputEventMouse*` events.
- Code **must never** test `event.device == 0`. Classify by event type.
- A touch with `pressed == false` **must** be checked for `canceled` first; a canceled touch **must** become `cancel_pointer(index)` and never `release`.
- The adapter **must never** synthesise a `release` from a cancel, a modal or a resize.
- The adapter **must** forward absolute `position`; it **must never** use `relative` or `velocity`.
- The adapter **must** set `process_mode = PROCESS_MODE_ALWAYS`.
- Lifecycle notifications **must** reach only AppRoot; the adapter **must not** override `_notification` for focus or application events.
- Every top-band Control **must** set its own `mouse_filter = MOUSE_FILTER_IGNORE`; every battle Control **must** set `focus_mode = FOCUS_NONE`.
- No Camera2D and no non-identity `canvas_transform` may exist in the battle scene (ADR-0008); a debug assert in `attach` checks `get_viewport().canvas_transform == Transform2D.IDENTITY`.
- The resolver **must** stay free of engine input types; tests drive it with the five calls only.

## Alternatives Considered

### Alternative 1: `_unhandled_input` adapter, Controls consume first

- **Description**: The adapter reads `_unhandled_input`; modal Controls with STOP swallow taps, so no modal gate is needed. This is what HUD Rule 2 and the Input GDD Interactions table describe.
- **Pros**: The engine does the modal blocking; less adapter state.
- **Cons**: `Node._unhandled_input` is skipped for events "consumed by `_input` or any GUI Control item" (`Node.xml`). A Control appearing under a moving finger (the Lost panel during a hero drag) consumes the release and strands the gesture, which the adapter contract forbids. A fallback that synthesises `cancel_pointer` needs to know which events a Control swallowed, which the adapter cannot see.
- **Estimated Effort**: Lower at first; higher once the stranding fallback is added.
- **Rejection Reason**: It breaks the one-release-per-press contract by construction.

### Alternative 2: Read both touch and mouse events, mouse on a reserved index

- **Description**: Leave `emulate_touch_from_mouse` false. Map `InputEventMouseButton` (left only) and `InputEventMouseMotion` to a reserved pointer index such as `-2`, and set `emulate_mouse_from_touch=false` so phones do not double every press.
- **Pros**: Explicit control of mouse buttons; no reliance on emulation.
- **Cons**: With `emulate_mouse_from_touch=false`, phone taps no longer produce mouse events, so Buttons on modals need their own touch handling (whether `Control._gui_input` receives `InputEventScreenTouch` is not documented in `Control.xml`). Two code paths, two test matrices.
- **Estimated Effort**: Higher.
- **Rejection Reason**: More code and a new unsourced dependency for no player benefit.

### Alternative 3: Hidden full-screen Control as the adapter (`_gui_input`)

- **Description**: A transparent Control under the HUD receives events through `_gui_input`.
- **Pros**: Modal Controls above it would block it naturally.
- **Cons**: Same stranding problem as Alternative 1 when a Control appears mid-drag; also subject to mouse filter, focus and dual-focus rules.
- **Estimated Effort**: Similar to Alternative 1.
- **Rejection Reason**: Same as Alternative 1.

## Consequences

### Positive

- The one-release-per-press contract holds by construction: nothing upstream of `_input` can consume an event.
- One event family on every platform; desktop testing uses the phone code path.
- Modal blocking is explicit, testable with a fake resolver, and independent of engine focus rules.
- The ADR does not depend on the 4.5 recursive disable or on the ADR-0002 pause mechanism.

### Negative

- The adapter holds a small amount of state (modal flag, rejected indices) that the GDD meant the engine to provide.
- HUD Rule 2 wording ("consume every event before the adapter sees it") no longer describes the mechanism; the GDD needs a wording sync.
- Desktop mouse behaviour depends on `emulate_touch_from_mouse`, whose button mapping is not documented (V-3).

### Neutral

- `emulate_mouse_from_touch` stays default; Controls see emulated mouse events on phones.

## Risks

- **OS events do not follow the `push_input` order** (V-1). Mitigation: a device test logs the order of `_input` and a STOP Button's `_gui_input` for one tap; if Controls run first, fall back to Alternative 1 plus a `cancel()` on every modal open, which still closes in-flight gestures.
- **Emulated touch from a right click** (V-3). Mitigation: the adapter also listens to `InputEventMouseButton` solely to set a "non-left down" flag and drops touch presses while it is set.
- **A press seen by the adapter and the modal in the same frame** opens a modal and then reaches nothing: the gate is set before the press only if `set_modal` ran earlier. The modal opens on a HUD state change, never inside the tap that causes it, except Retry, which only sets a latch. Accepted.
- **Pause stops `_input`** under tree pause despite `PROCESS_MODE_ALWAYS` (V-5). Mitigation: the Paused screen's resume is a Control, so resume still works; the risk is only a stranded gesture, already closed by AppRoot's `cancel()`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-001: one active pointer, two frozen winners, slop classification | The adapter forwards one index space (touch `index`) and every move, so the resolver's rules see a complete stream |
| input-gesture-resolver.md | TR-input-002: registry of discs | Unchanged resolver API; the adapter never touches the registry |
| input-gesture-resolver.md | TR-input-003: five calls, edge reject margin, works while Paused, `cancel()` for AppRoot | Sections 3, 5 and 6 |
| input-gesture-resolver.md | TR-input-004: one `drag_moved` per input call, never per frame | One `move` per `InputEventScreenDrag`; the adapter has no `_process` |
| input-gesture-resolver.md | Adapter contract: one release, cancel_pointer or cancel per press; `canceled` checked first | Sections 1, 3 and 4 |
| battle-hud.md | TR-hud-002: modal screens block taps; everything else is a disc | Section 4 modal gate plus STOP Controls |
| battle-hud.md | TR-hud-008: hit targets at least 48 dp | Positions are field units (ADR-0008); `target_ok` holds at 360 dp width under ADR-0008's width-fit |
| battle-hud.md | TR-hud-011: modals `focus_mode` NONE, top band `mouse_filter` IGNORE | Section 7, with a test on `get_mouse_filter_with_override()` |
| enemy-wave.md | Presses in masked bars reach Input as positions outside the field | Positions forwarded unchanged (section 3, V-4) |

**GDD sync required.**

- `input-gesture-resolver.md` Core Rules (the "Becomes an ADR" paragraph) and Interactions: "the adapter, not Game State stories, owns the lifecycle notifications". This ADR follows the master architecture: AppRoot owns them and calls `adapter.cancel()`.
- `input-gesture-resolver.md` Interactions (Battle HUD row) and `battle-hud.md` Rule 2: "Controls ... consume their own events before the adapter". The adapter now sees them first and drops presses through `set_modal`.
- `input-gesture-resolver.md` uses `centre`, `set_centre(id, pos)`, `set_enabled(id, on)` and a `sink` field. The architecture's `HitTarget` uses `center` and has no `sink`, and `InputResolver` lists no `set_centre` or `set_enabled`. This ADR does not rename them; `/architecture-review` must reconcile the architecture API block with the GDD before resolver stories start.

## Performance Implications

- **CPU**: One type check and at most five float compares per event. Negligible.
- **Memory**: One node, one small dictionary of rejected indices.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

No code exists. Implementation order: add the `input_devices` key with ADR-0008's `project.godot` change; write the adapter with a fake resolver in unit tests; run V-1 to V-5 on desktop and on one Android and one iOS phone.

**Rollback plan**: If V-1 fails, switch the adapter to Alternative 1 and keep `set_modal` as a cancel-only hook. The resolver and its owners do not change.

## Validation Criteria

Automated (gdUnit4, `tests/unit/input/`):

- Each row of the section 3 table, with synthetic events and a recording fake resolver.
- `canceled == true` with `pressed == false` produces `cancel_pointer`, never `release`.
- `set_modal(true)` calls `cancel()` once and drops later presses; moves and releases still pass.
- A press inside the edge margin is dropped, and that index's drag and release are dropped; a drag that enters the margin is forwarded.
- No `InputEventMouse*` event produces a call.
- Every top-band Control returns `MOUSE_FILTER_IGNORE` from `get_mouse_filter_with_override()`.

**NOT SOURCEABLE, blocking acceptance** (each needs a device run, logged to `production/qa/evidence/`):

- V-1. NOT SOURCEABLE: that OS-delivered events follow the `Viewport.push_input` order (`_input` before `_gui_input`). The class reference states the order for `push_input` only; needs a device run.
- V-2. NOT SOURCEABLE: whether a phone tap produces both an `InputEventScreenTouch` and an emulated mouse event in one frame, and in which order, under `emulate_mouse_from_touch=true`; needs a device run.
- V-3. NOT SOURCEABLE: which mouse buttons `emulate_touch_from_mouse` maps to touch; needs a desktop run.
- V-4. NOT SOURCEABLE: that a press in a letterbox bar reports a position outside 0 to 960 in viewport coordinates; needs a device run at 9:19.5.
- V-5. NOT SOURCEABLE: whether `_input` is called under `SceneTree.paused` for a `PROCESS_MODE_ALWAYS` node; needs a run once ADR-0002 fixes the pause mechanism.
- V-6. NOT SOURCEABLE: when Android and iOS set `canceled` (system gesture, incoming call, focus loss); needs a device run.

## Related

- ADR-0001 Simulation and Shell Boundary (depends on)
- ADR-0002 App Lifecycle and Composition (depends on; AppRoot calls `cancel()`; pause mechanism)
- ADR-0008 Stretch Mode, Safe Area and the Field (coordinate space and insets; accept together)
- ADR-0010 Tower System, ADR-0011 Hero System (register discs)
- ADR-0012 Field and HUD Rendering and Performance Budget (modal Controls, top band)
- ADR-0014 Debug Logs (GestureLog listens to resolver signals)
- `design/gdd/input-gesture-resolver.md`, `design/gdd/battle-hud.md`, `design/gdd/enemy-wave.md`
- `docs/architecture/architecture.md` (Module Ownership, API Boundaries `InputResolver`, Open Questions QQ-03)
