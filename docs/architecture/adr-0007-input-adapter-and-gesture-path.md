# ADR-0007: Input Adapter and Gesture Path

## Status
Accepted (2026-11-03, by njarrar, on best-guess device assumptions; no phone test was possible). Every verification item is answered by a best guess in docs/architecture/device-assumptions.md and checked by its First device build checklist; a failed check revises this ADR, it is not worked around.

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
njarrar (project owner); technical-director and lead-programmer (architecture gates, 2026-11-02, findings GF4, GF5 and GF6); godot-specialist (draft author). Engine specialist and TD-ADR reviews are still to run.

## Summary
The Gesture Resolver is pure and clock-free, so one engine-facing node must turn Godot touch and mouse events into its five calls, and the Input GDD binds it to a hard contract: every forwarded press ends in exactly one `release`, `cancel_pointer` or `cancel()`, whatever Controls or the OS do. This ADR reads every event in `_input` on a plain `Node` (before any Control can take it), decodes engine events in one small function into a pure `PointerGate` that holds all the rules (field conversion through ADR-0006's `FieldSpace`, edge and inset rejection, one event family at a time, touch indexes forwarded unchanged and the mouse as index 1024, cancel flag checked before any release, the press block), turns both emulation settings off in `project.godot`, and keeps the adapter free of signals, lifecycle and commands.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (Input is HIGH in VERSION.md; `modules/input.md` has no touch coverage) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `modules/input.md` (4.7 `DEVICE_ID_MOUSE` and `DEVICE_ID_KEYBOARD`; `_input` and `_unhandled_input` as callbacks; `InputEventMouseButton`, `button_index`, `MOUSE_BUTTON_LEFT`, `pressed`, `position`; 4.6 dual focus; 4.5 recursive Control disable); `breaking-changes.md` (4.7 device IDs: identify events by type or compare `device` to the constants; 4.7 typed-return overrides); `deprecated-apis.md` (`event.device == 0` replaced by class checks or the constants); `current-best-practices.md` (UI and Input 4.7) |
| **Post-Cutoff APIs Used** | `InputEvent.DEVICE_ID_MOUSE` (4.7, sourced). 4.7 typed-return rule for any override in this ADR's classes (each ends in an explicit `return`). No other post-cutoff API |
| **Verification Required** | **NOT SOURCEABLE** from `docs/engine-reference/godot/` unless marked; every belief below is memory, unverified. (I1) A `Node`'s `_input` receives every input event before the GUI hands it to any Control, and a Control's `accept_event()` or `mouse_filter = STOP` cannot stop that delivery; only another node's `set_input_as_handled()` in `_input` can. (I2) Touch classes and fields on 4.7.2: `InputEventScreenTouch` (`index: int`, `position: Vector2`, `pressed: bool`) and `InputEventScreenDrag` (`index`, `position`). (I3) The cancel flag: memory says `InputEvent.is_canceled()` and a `canceled` property on `InputEventScreenTouch` (added around 4.2) are true for an Android touch cancel and an iOS touches-cancelled, on an event with `pressed = false`. (I4) Multi-touch indexes: the first finger down is 0, indexes are small non-negative integers (well under 1024), a second finger gets its own index while the first is still down, and an index is reused only after its finger lifts. (I5) Emulation keys `input_devices/pointing/emulate_mouse_from_touch` (memory: default true) and `input_devices/pointing/emulate_touch_from_mouse` (memory: default false); with mouse-from-touch on, each touch also arrives as an `InputEventMouseButton`, believed to carry a device other than `DEVICE_ID_MOUSE` (memory: `DEVICE_ID_EMULATION`, -1). (I6) With mouse-from-touch off, a full-screen `Control` still receives `InputEventScreenTouch` in `_gui_input`, and stock `Button`s outside the battle still respond to touch. (I7) Desktop: the left-button release of a press that began inside the window reaches `_input` even when the cursor is outside the window; `InputEventMouseMotion.button_mask` and `MOUSE_BUTTON_MASK_LEFT` exist under those names. (I8) `process_mode = PROCESS_MODE_ALWAYS` keeps `_input` running while `SceneTree.paused` is true. (I9) An Android back gesture from a side edge, and a system bar swipe, deliver a touch cancel or nothing, never a plain release, to the game. (I10) On focus loss with a finger down, the OS delivers a cancel, a release, or nothing; the design holds in all three cases. (I11) Event positions in `_input` are in the space ADR-0006 D2 assumes (shared with D2; `FieldSpace.event_to_canvas` absorbs either answer) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted): resolver signal names and shapes, wiring in the wrapper, emit rules. ADR-0003 (Accepted): `Battle.enqueue`, command records, `RealClock`, step 1g `resolver.cancel()`, no `_process` or engine time in input pieces, no `cancel()` inside a tick or `apply_queued`. ADR-0006 (Accepted): `FieldSpace.to_field`, `FIELD_RECT`, `FieldInsets`, the CanvasLayer order (World 0, HudLayer 10, ModalLayer 20), the modal screens' `_gui_input`, `set_input_blocked`, `ResumeCommand`. ADR-0001 (Accepted): the Input record (`drag_slop`, `tap_slop`, `edge_reject_margin`) |
| **Enables** | ADR-0008 (the wrapper builds, injects and frees the adapter and calls `forget_open_presses` at step 1g); the Input adapter, HeroInput and TowerInput stories; the phone test (TR-input-005) and its gesture log (TR-input-008) |
| **Blocks** | Input & Gesture Resolver epic (adapter stories); every story that needs real touch input, including the Pillar 4 phone test |
| **Ordering Note** | ADR-0006 is Accepted before this one (GF4). Accepted on the best guesses in `docs/architecture/device-assumptions.md` by the user's decision of 2026-11-03, with no phone test: I1 to I6 and I9 to I11 (phone items), and I7 and I8 (desktop items, closed by the first adapter story). The first device build runs that file's checklist and adds each answer to `docs/engine-reference/godot/modules/input.md`. If I1 fails, see Risks; if I6 fails, the emulation decision in section 6 flips for menus outside the battle (see Risks) and the family lock carries it |

## Context

### Problem Statement
The resolver (TR-input-001) has no scene-tree dependency. Something must read engine events, convert them to field units and make the five calls `press`, `move`, `release`, `cancel_pointer`, `cancel`. The Input GDD leaves that piece to an ADR (Overview; Core Rules, "Becomes an ADR") and puts a binding contract on it (Dependencies, "Adapter contract"): every forwarded press gets exactly one closer, and a touch cancel must never be read as a release, or an Android cancel becomes a `tap` or `drag_ended`, a mis-fire. Pillar 4 allows zero mis-fires (TR-input-005).

Five questions are open:
1. **Which engine path.** The GDD suggests `_unhandled_input` for presses but warns that a `mouse_filter = STOP` Control can swallow a move or release mid-drag. ADR-0006 puts two STOP Controls (the modal screens) on layer 20 and a press block in the adapter as a backstop.
2. **Touch cancel.** The flag and its name are not in the reference.
3. **Desktop mouse.** It must act as one touch pointer, found by event class (4.7), and one physical press must give one gesture (TR-input-004). With emulation on, one touch can arrive twice.
4. **Multi-touch.** The resolver tracks one active pointer (Input Rule 1) but needs to see other fingers' presses for its palm replacement rule.
5. **Tablet slop** (Open Question A6): `drag_slop` is about 22 dp at 800 dp wide.

### Constraints
- The adapter owns no lifecycle state (GF6). Focus, quit, resize and back belong to the BattleWrapper.
- The adapter emits no signals (architecture 4.2; ADR-0002's table lists none for it).
- Input handlers only enqueue commands (ADR-0003; registry forbidden pattern `direct_sim_command_from_input`). The adapter itself builds no command.
- No input piece uses `_process` or reads engine time; real time comes from the injected `RealClock` (ADR-0003).
- `cancel_pointer` and `cancel()` must never run inside a tick or inside `apply_queued` (ADR-0003). Modals mount from `phase` handlers, some of which run inside `apply_queued` (step 1b, `ResumeCommand`).
- Every screen position enters gameplay through `FieldSpace.to_field` (ADR-0006).
- The resolver and adapter are rebuilt per battle; headless runs have no adapter (Input GDD, Interactions, Game State row).

### Requirements
- TR-input-001: the resolver stays pure; only the adapter touches the engine.
- TR-input-002: one press gives at most one gesture, to one target; the adapter must not create a second press from one finger.
- TR-input-003: every forwarded press ends in exactly one `release`, `cancel_pointer` or `cancel()`, across Controls and OS cancels.
- TR-input-004: desktop mouse maps to one touch pointer; one physical press gives one gesture; events told apart by class.
- TR-input-005: 44 pt / 48 dp targets and slop; at most 5% misses and zero mis-fires over 20 attempts.
- TR-input-008: a gesture log records each gesture, with the landed pin for a hero drag.

## Decision

### 1. Two pieces: a thin node and a pure gate
- **`InputAdapter`** (`res://src/input/input_adapter.gd`, `extends Node`, not a Control) is the only code that reads an `InputEvent`. Its `_input(event)` calls one function, `_decode(event)`, which turns each event into at most one primitive call on the gate. Every NOT SOURCEABLE class and field name (I2, I3, I7) lives in `_decode` and nowhere else, so a spike answer changes one function.
- **`PointerGate`** (`res://src/input/pointer_gate.gd`, `extends RefCounted`) holds every rule in this ADR. It takes primitives (index, position, pressed, canceled), never an `InputEvent`, so its tests run headless with no engine events and no scene tree.
- **Who builds them.** `BattleWrapper.attach()` (ADR-0008) builds, in this order: the resolver, HeroInput, TowerInput, then `PointerGate.create(resolver, catalogue.input().edge_reject_margin, clock, log_sink)`, then `InputAdapter` with `setup(gate)`. `clock` is the injected `RealClock` (ADR-0003). `log_sink` is the debug log's sink in debug builds and a no-op Callable otherwise. Owners register before the gate exists, so no event can reach a resolver with an empty registry.

### 2. The engine path: `_input` (questions 1 and the GDD's STOP warning)
The adapter reads events in `_input`. In Godot's long-standing order (I1, memory) `_input` runs before the GUI hands the event to Controls, so no Control, STOP or not, can swallow a move or release of an open press. The release guarantee then rests on the adapter's own bookkeeping, not on which Controls lie under the finger.

- The adapter must never call `set_input_as_handled()`, so the modal screens still get every event in `_gui_input` (ADR-0006 section 5).
- No other node in the project may call `set_input_as_handled()` from `_input`, since that could hide an event from the adapter.
- `process_mode = PROCESS_MODE_ALWAYS` on the adapter (Input GDD, "Becomes an ADR"; I8), so an engine pause can never strand a gesture.
- Because the adapter now sees taps meant for a modal screen, **the press block is the main modal route, not a backstop** (section 5). The architecture's 3.1 diagram already shows `InputAdapter._input`; the GDD lines that say modal Controls take events "before the adapter sees them" change (Migration Plan).

### 3. Field space, rejection and what is forwarded
- Every position goes through the gate's current `FieldSpace.to_field` (ADR-0006). The wrapper hands the gate a new space with `set_space(space, insets)` at build and, after a resize, at step 1g after `resolver.cancel()`, so a gesture never mixes two spaces (TR-input-006, ADR-0006 section 4).
- **A press is not forwarded** (and so opens nothing) when: its field point is outside `FieldSpace.FIELD_RECT` (ADR-0006); its canvas x lies within `edge_reject_margin` of the left or right edge of `visible_rect`; or its field point lies inside an inset strip (`y < insets.top`, `y > 960 - insets.bottom`, `x < insets.left`, `x > 540 - insets.right`) (Input Rule 12). `edge_reject_margin` comes from the Input record, injected as a float.
- Moves and releases of an open press are converted but never clamped or rejected; a drag that moves into a rejected zone stays valid (Rule 12), and owners clamp (Input edge case "drag ends outside the field").
- Moves and releases with no open press are dropped (Rule 10: hover and stray moves never reach the resolver).

### 4. Closers: how the contract holds by construction (TR-input-003)
The gate keeps `open: Dictionary` of forwarded, not yet closed indexes, and the `family` that owns them (section 6). Each forwarded `press(i)` adds `i`; exactly one of these removes it:

| Event | Gate call | Why |
|---|---|---|
| Release of open `i` with the cancel flag false | `release(i, p)` | Normal end |
| Release of open `i` with the cancel flag true | `cancel_pointer(i)` | Flag checked **before** a release is considered (GDD contract; I3). A cancel never emits `tap` or `drag_ended` |
| Press of an `i` that is already open (its release was lost) | `cancel_pointer(i)`, then `press(i, p)` | Closes the old press before the new one; the resolver's "press again" row then never fires from the adapter |
| Mouse motion while the mouse press is open but the left button is no longer held (I7) | `cancel_pointer(MOUSE_INDEX)` | A lost mouse release ends as a cancel, never a late release |
| Wrapper step 1g ran `resolver.cancel()` | none; the wrapper then calls `forget_open_presses()`, which clears `open` and resets `family` to `NONE` | `cancel()` is the closer for every open index; a later release of that finger is dropped as "no open press" |

`cancel()` comes only from the wrapper (Paused, outcome, Fatal, resize, focus loss: ADR-0003 step 1g, ADR-0008). The adapter never calls `cancel()`. On Retry the old adapter is freed with its state; a finger held across Retry meets a new gate with nothing open, so its moves and release are dropped.

**Focus loss with a finger down (I10).** If the OS sends a cancel, the table closes it; if it sends a release, that release reaches the resolver, but the wrapper also requests `cancel()` for `focus_lost` (ADR-0008), and a release while the game is pausing at worst completes a gesture whose commands drain in step 1b before the pause applies, the same as any release in that frame. If the OS sends nothing, step 1g's `cancel()` closes it. All three end in exactly one closer.

### 5. The press block (ADR-0006 `set_input_blocked`, revised per the ADR-0006 review)
`set_input_blocked(true)` makes the gate forward nothing at all: no new press, and no move, release or `cancel_pointer` of a press that is already open. **The gate never calls `cancel_pointer` itself when the block is set**, because modals mount from `phase` handlers and some of those run inside `apply_queued` (step 1b), where ADR-0003 forbids cancels. The open press is closed by the `cancel()` that the same frame's step 1g runs: every modal mount comes with a cancel request (Paused, Won, Lost and Fatal all request `cancel()`, Flow Rules 15, 17 and 18), and the wrapper then calls `forget_open_presses()`. Rule: **the HUD may call `set_input_blocked(true)` only in a frame in which a resolver `cancel()` has been requested**; a debug check in the wrapper reports a block with open presses and no request at step 1g.

While blocked, events still reach the modal screens through the GUI, which is now the main modal route: the adapter sees the resume tap in `_input`, drops it, and PausedScreen judges it in `_gui_input`. If ADR-0006 D6 fails (the Control gets no touch press), ADR-0006's fallback `modal_sink: Callable` applies: while blocked, the gate passes raw press and release points in field units to the sink instead of dropping them. `set_input_blocked(false)` re-opens forwarding; a finger held across the block has no open press and stays dead (ADR-0006 section 5).

### 6. Desktop mouse as touch, and emulation (question 3; TR-input-004)
**Project settings, written on purpose in `project.godot`:**
- `input_devices/pointing/emulate_mouse_from_touch = false`
- `input_devices/pointing/emulate_touch_from_mouse = false`

(Key names I5, memory, unverified.) A misspelt key in `project.godot` is silently ignored and the engine default returns, so **debug builds read both values back from `ProjectSettings` at boot and log an error if either is not `false`**; the phone spike checks the same read-back on the device. The family lock below still holds if a key is wrong. With both off, a phone touch arrives only as touch events and a desktop mouse only as mouse events, so neither the adapter nor a modal screen sees one physical press twice.

**ADR-0006 must agree, and its modals use the family lock now, not only as a fallback.** Its modal screens accept both `InputEventScreenTouch` and `InputEventMouseButton` by class, and each must accept a release only from the event family of the press it saw while Armed, dropping the other family until that press closes. I6 is likely to fail (stock `BaseButton`s may stop answering touch with mouse-from-touch off; memory, unverified). If it does, the project turns `emulate_mouse_from_touch` back on, and the adapter (family lock plus the device filter below) and the modals (same lock) are already correct (Migration Plan).

**Desktop mouse-as-touch is the adapter's own mapping, not engine emulation.** `_decode` maps:
- `InputEventMouseButton` with `button_index == MOUSE_BUTTON_LEFT` (sourced): `pressed` true to a press at `MOUSE_INDEX`, false to a release (with the cancel flag check). Other buttons are dropped (Rule 10).
- `InputEventMouseMotion` (I7) to a move at `MOUSE_INDEX`, with `left_held` from its button mask.
- Events are identified by class. A mouse-class event is also dropped unless `event.device == InputEvent.DEVICE_ID_MOUSE`, the 4.7 constant (sourced; `deprecated-apis.md` lists this comparison as correct). This drops mouse events emulated from touch if emulation is ever on (I5). `device == 0` is never used.
- `MOUSE_INDEX = 1024`, far above any touch index (I4), so a mouse press can never be mistaken for finger 0 on a touchscreen laptop (Input GDD, "Becomes an ADR").

**Family lock.** The gate's `family` is `NONE`, `TOUCH` or `MOUSE`. A press sets it when `open` is empty. While any press is open, every event of the other family, presses included, is dropped. It returns to `NONE` when `open` empties. So one physical press yields one gesture whatever order a double delivery takes, and a touchscreen laptop cannot run a mouse gesture and a touch gesture at once.

### 7. Multi-touch (question 4)
The gate forwards **every touch index unchanged**, each with its own closer. It does not pick the active pointer: the resolver does (Rule 1: the first press while Idle is active; other indexes are dropped, except the palm replacement of a press nothing waits on). If the gate dropped second fingers itself, Rule 1's palm replacement and criterion 17 (`cancel_pointer(1)` leaves pointer 0's drag alive) could not work. Calls for non-active indexes cost the resolver one comparison each. The adapter never maps or renumbers touch indexes, so the resolver's "active pointer" is the engine's touch index (or 1024 for the mouse).

### 8. Tablet slop (Open Question A6): no scale cap at MVP
Slop stays in field units with no cap. At 800 dp the 15-unit `drag_slop` is about 22 dp and the 28-unit `tap_slop` about 41 dp (Input GDD, Formulas table); a height-limited tablet scales by height instead (Formulas, field_scale note), which gives less, about 20 dp at 1280 dp tall under ADR-0006's `expand` placement. A cap needs display density in the resolver, which the GDD keeps out on purpose ("Deliberately not built for MVP: display-density handling"), and tablets are not the Pillar 4 phone-test device. The gesture log records maximum travel per gesture, so a tablet playtest can reopen A6 with numbers; any fix is a different Input record per platform, not code.

### 9. The gesture log (TR-input-008)
In development builds the wrapper injects `log_sink: Callable`; release builds pass an empty Callable and the gate skips logging when `not log_sink.is_valid()`. For each call it forwards (and each press it rejects, with the reason), the gate calls `log_sink` with a plain `PointerLogEntry` record: kind (`press`, `move`, `release`, `cancel_pointer`, `rejected`, `forgotten`), family, index, field position, `RealClock.now_ms()` from the injected clock, and at press the current insets. The gesture log object (HUD debug-log story) joins these with the resolver's signals to get down and up positions and times, maximum travel, winners and the emitted signal; HeroInput adds the landed pin after `clamp_pin` (Input Rule 13). The adapter reads no engine time and the resolver stays clock-free.

### 10. What the adapter does not do
No signals (ADR-0002). No lifecycle notifications, no `size_changed` hook, no Android back (GF6: the BattleWrapper). No commands: resolver handlers in HeroInput, TowerInput and the HUD build `BattleCommand`s and call `Battle.enqueue` (ADR-0003). No `_process`, no timers, no `await`. No registry calls (`register`, `set_centre` belong to owners). No `cancel()`.

### Architecture Diagram

```
OS touch / mouse
   |
   v
Viewport --> InputAdapter._input(event)        (Node, PROCESS_MODE_ALWAYS, before GUI; I1)
   |              |  _decode: class checks, DEVICE_ID_MOUSE filter, cancel flag
   |              v
   |         PointerGate (pure)  -- FieldSpace.to_field, FieldInsets, edge_reject_margin
   |              |  family lock, open set, closers, block, log_sink(PointerLogEntry)
   |              v
   |         GestureResolver.press / move / release / cancel_pointer
   |              |  signals (ADR-0002)
   |              v
   |         HeroInput / TowerInput / HUD handlers --> BattleCommand --> Battle.enqueue
   |
   +--> GUI: ModalLayer 20 PausedScreen / ResultScreen _gui_input (STOP) --> ResumeCommand
            HudLayer 10 Controls: IGNORE

Wrapper (ADR-0008): setup, set_space at build and step 1g, set_input_blocked via HUD Callable,
step 1g: resolver.cancel(); adapter.forget_open_presses(); if resized: set_space(new)
```

### Key Interfaces

```gdscript
class_name InputAdapter extends Node
# No signals. No lifecycle. Only reads InputEvents and feeds PointerGate.
func setup(gate: PointerGate) -> void
func _input(event: InputEvent) -> void          # calls _decode(event); never set_input_as_handled
func _decode(event: InputEvent) -> void         # the only place touch and mouse class and field names appear

class_name PointerGate extends RefCounted
const MOUSE_INDEX: int = 1024
enum Family { NONE, TOUCH, MOUSE }
static func create(resolver: GestureResolver, edge_reject_margin: float,
        clock: RealClock, log_sink: Callable) -> PointerGate
func set_space(space: FieldSpace, insets: FieldInsets) -> void
func set_input_blocked(blocked: bool) -> void   # ADR-0006 name; never calls the resolver
func forget_open_presses() -> void              # wrapper only, right after resolver.cancel(); clears open, family = NONE
func touch_button(index: int, pos: Vector2, pressed: bool, canceled: bool) -> void
func touch_drag(index: int, pos: Vector2) -> void
func mouse_button(pos: Vector2, pressed: bool, canceled: bool) -> void   # left button only
func mouse_motion(pos: Vector2, left_held: bool) -> void
func open_indexes() -> Array[int]               # tests and the step 1g debug check

class_name PointerLogEntry extends RefCounted   # plain values only
```

`InputAdapter.set_input_blocked` named in ADR-0006 is the gate's method; the wrapper injects `gate.set_input_blocked` into the HUD as the `Callable`.

### Implementation Guidelines
- The adapter must read events only in `_input`; it must never use `_unhandled_input`, `_gui_input` or a Control.
- The adapter must never call `set_input_as_handled()`, and no node may call it from `_input`.
- Touch and mouse class and field names must appear only in `InputAdapter._decode`.
- Events must be identified by class; `event.device == 0` must never be used. Mouse-class events must also match `InputEvent.DEVICE_ID_MOUSE`.
- The cancel flag must be checked before a `pressed = false` event is treated as a release.
- Every forwarded press must get exactly one closer, per the section 4 table; a press of an already-open index must be preceded by `cancel_pointer` of that index.
- The gate must forward touch indexes unchanged and the mouse as `MOUSE_INDEX`; it must not choose the active pointer.
- The gate must drop every event of the other family while any press is open.
- The gate must not forward a press outside `FIELD_RECT`, inside `edge_reject_margin` of a visible side edge, or inside an inset strip.
- Positions must go through `FieldSpace.to_field`; the gate must not clamp moves or releases.
- While blocked the gate must forward nothing and must never call `cancel_pointer` or `cancel()`; `set_input_blocked(true)` is legal only in a frame with a requested `cancel()`.
- The wrapper must call `forget_open_presses()` right after every `resolver.cancel()` it runs.
- The adapter must have `process_mode = PROCESS_MODE_ALWAYS`.
- `project.godot` must set both emulation keys to `false`, and debug builds must read both back from `ProjectSettings` at boot and log an error if either is not `false`.
- Modal screens must accept a release only from the event family of the press they saw.
- `BattleWrapper.attach()` must build the resolver, HeroInput, TowerInput, `PointerGate`, then `InputAdapter`, in that order.
- At step 1g the order must be `resolver.cancel()`, `forget_open_presses()`, then `set_space` if resized.
- The adapter and gate must emit no signals, build no commands, read no engine time (only `RealClock`), and hold no lifecycle state.
- Logging must run only when `log_sink.is_valid()`.

## Alternatives Considered

### Alternative 1: `_unhandled_input` (the GDD's suggestion for presses)
- **Description**: Read events after the GUI, so modal Controls take theirs first and the adapter never sees them.
- **Pros**: Modals block gameplay input by engine order alone; no press block needed for them.
- **Cons**: Any STOP Control under a drag can swallow its release, which breaks the contract; the result depends on D6 and on how the GUI routes touch, both NOT SOURCEABLE; 4.6 dual focus adds more GUI behaviour in the path.
- **Rejection Reason**: The contract would rest on unverified GUI behaviour. The GDD itself says moves and releases must be read where a STOP Control cannot swallow them.

### Alternative 2: A full-screen catcher Control with `_gui_input`
- **Description**: A Control under the HUD with `mouse_filter = STOP` receives all gameplay input.
- **Pros**: Uses the GUI's own hit testing and capture.
- **Cons**: Touch routing to Controls is NOT SOURCEABLE (I6); a drag that leaves the Control depends on GUI capture; it adds a third input-stopping Control, against ADR-0006's rule that only the modals stop input.
- **Rejection Reason**: Same unverified dependency as Alternative 1, plus a conflict with ADR-0006.

### Alternative 3: Two `_unhandled_input` presses with `_input` moves and releases
- **Description**: The GDD's split: presses after the GUI, the rest before it.
- **Pros**: Modals stop new presses by engine order.
- **Cons**: Two entry points must agree on one open set; a press swallowed by a modal still sends its release to `_input`, which must then be told apart; the modal block is still needed for a press open when a modal mounts.
- **Rejection Reason**: More moving parts for no gain once the press block exists.

### Alternative 4: Keep mouse-from-touch emulation on and filter in the adapter
- **Description**: Leave the engine default and drop emulated mouse events by device.
- **Pros**: Stock Controls outside the battle keep their touch path with no question.
- **Cons**: Every modal screen must repeat the filter or see each tap twice; the emulated device ID is NOT SOURCEABLE (I5).
- **Rejection Reason**: Off is simpler for every reader. Kept as the named fallback if I6 fails.

### Alternative 5: The gate tracks only the first touch index
- **Description**: Drop all touch indexes but one in the adapter.
- **Pros**: Fewer resolver calls.
- **Cons**: Breaks Input Rule 1's palm replacement and acceptance criterion 17; moves the one-pointer rule out of the pure, tested resolver (TR-input-001).
- **Rejection Reason**: The resolver owns pointer choice.

### Alternative 6: Mouse as index 0, or a scale cap on tablet slop
- **Description**: Map the mouse to index 0; cap `field_scale` for slop on wide devices.
- **Pros**: Index 0 needs no constant; a cap keeps tablet slop near phone size.
- **Cons**: Index 0 collides with the first finger on touchscreen laptops (the GDD asks for no collision); a cap needs display density in the resolver, which the GDD keeps out of MVP.
- **Rejection Reason**: Both break a stated GDD rule.

## Consequences

### Positive
- The release guarantee does not depend on any Control or on GUI routing; it holds by the gate's own bookkeeping and is fully testable headless.
- Every unverified engine name sits in one function; a spike answer is a one-function change.
- One physical press gives one gesture on every device, by family lock, emulation off and the device filter, each alone enough for the common case.
- No signals, commands, clock reads or lifecycle in the adapter, so ADR-0002, ADR-0003 and GF6 hold unchanged.

### Negative
- The adapter sees modal taps too, so correctness during a modal rests on the press block and the same-frame `cancel()`; a HUD bug that blocks without a cancel request would leave a press open until the next press of that index (caught by the step 1g debug check).
- `forget_open_presses()` is one more call the wrapper must make after each `resolver.cancel()`.
- Emulation off may need touch handling in any non-battle menu if I6 fails.
- Tablet drags need a little more travel than phone drags until A6 is reopened.

## Risks
- **I1 fails (a Control can stop `_input`, or `_input` runs after the GUI).** Mitigation: the gate does not change; the adapter becomes a `Viewport`-level hook chosen by the spike, and if no path sees events before the GUI, the adapter adds a synthetic `cancel_pointer` for any open press when a STOP Control is visible (the GDD's second option). Only `InputAdapter` changes.
- **I3 fails (no cancel flag).** Mitigation: `_decode` treats the cancel flag as false; the spike records how Android delivers a cancel (for example a release at the edge with no flag) and `_decode` maps that to `canceled = true`. Until then the phone test logs any `tap` or `drag_ended` from an edge release as a candidate mis-fire.
- **I4 fails (indexes collide with 1024 or are renumbered).** Mitigation: change `MOUSE_INDEX`; renumbering would need a map in the gate, still pure.
- **I6 fails.** Mitigation: turn `emulate_mouse_from_touch` on (section 6); the adapter is already correct; ADR-0006's modals adopt the family lock. The battle uses no stock `Button` (ADR-0006: modals use `_gui_input`, other HUD Controls IGNORE), so I6 failing does not flip the emulation decision for the battle; it matters only for menus outside the battle.
- **A HUD blocks input without a cancel request.** Mitigation: the rule in section 5 and the step 1g debug check; the next press of the index still recovers (Rule 1).
- **Edge rejection removes real presses on a phone with large insets.** Mitigation: insets and margin are data; the gesture log records each `rejected` press with its reason.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | Core Rules, "What the resolver is": pure object; an adapter makes the five calls (TR-input-001) | `InputAdapter` plus pure `PointerGate`; the resolver touches no engine API |
| input-gesture-resolver.md | Dependencies, Adapter contract: exactly one closer; check `canceled` before a release (TR-input-003) | Section 4 closer table; cancel flag checked first; `forget_open_presses` after `cancel()` |
| input-gesture-resolver.md | Rule 1 one pointer, palm replacement; criterion 17 (TR-input-002) | Section 7: every touch index forwarded unchanged; the resolver chooses |
| input-gesture-resolver.md | "Becomes an ADR": mouse index that cannot collide; one event family only; `PROCESS_MODE_ALWAYS`; STOP Controls must not swallow moves and releases (TR-input-004) | Sections 2 and 6: `_input`, `MOUSE_INDEX = 1024`, emulation off, family lock, class checks with `DEVICE_ID_MOUSE` |
| input-gesture-resolver.md | Rule 10: hover and non-left buttons never reach the resolver | Section 3 drops moves with no open press; `_decode` drops non-left buttons |
| input-gesture-resolver.md | Rule 12: edge margin and inset presses rejected; drags into them stay valid | Section 3 |
| input-gesture-resolver.md | Rule 13 gesture log, landed pin (TR-input-008) | Section 9: `log_sink` with `PointerLogEntry` and `RealClock`; HeroInput adds the pin |
| input-gesture-resolver.md | Formulas, target_ok and the slop table; Pillar 4 phone test (TR-input-005) | Slop and radii stay field units; section 8 keeps them uncapped; the log gives misses and mis-fires |
| input-gesture-resolver.md | Edge case "cancel() ran and the OS later delivers the same pointer's move or release" | After `forget_open_presses` the gate drops them, so the resolver never sees them |
| battle-hud.md | Rule 2: a tap on a modal screen cannot reach a tower or the hero (TR-hud-001) | Section 5: press block is the main route; the modal judges the tap in `_gui_input` |
| game-state-stage-flow.md | Flow Rules 15, 17, 18: `cancel()` at the end of a frame, never in a tick | The gate never cancels; the wrapper's step 1g does |

## Performance Implications
- **CPU**: One `_input` call and one gate call per event; at most a few resolver calls per event. Negligible against the 2 ms tick budget. Logging only in development builds.
- **Memory**: One small Dictionary of open indexes (usually 0 to 2 entries); log entries owned by the debug log.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
These edits land in the same change that marks this ADR Accepted:
- `docs/architecture/architecture.md` Required ADRs, ADR-0007 row (line 686): replace "(`_unhandled_input` versus Control `_gui_input`)" with "(decided: `_input` on a Node)" and add `PointerGate`, emulation off and the press block as the main modal route.
- `architecture.md` 4.2 (lines 382 to 426): add the `PointerGate` interface, `MOUSE_INDEX`, `set_space`, `set_input_blocked` (forwards nothing, never cancels), `forget_open_presses`, and the family lock to the adapter contract paragraph.
- `architecture.md` 3.1 step g (line 271): "cancel the resolver if requested" becomes "cancel the resolver if requested, then `gate.forget_open_presses()`".
- `architecture.md` 4.6 invariant (line 540) and TR-hud-001 (line 657): "consume every event before the adapter sees it" becomes "take every event in `_gui_input` while the adapter's press block drops it".
- `architecture.md` 4.7 table: add `InputEventMouseMotion`, the cancel flag, the emulation keys and `PROCESS_MODE_ALWAYS` (NOT SOURCEABLE or memory, per I-items).
- `architecture.md` Open Questions A6 (line 745): closed, decided by ADR-0007 (no cap at MVP; reopen from tablet log data).
- `design/gdd/input-gesture-resolver.md` line 21 and the "Becomes an ADR" paragraph (line 78): name ADR-0007 and its answers (`_input`, `MOUSE_INDEX`, emulation off, `PROCESS_MODE_ALWAYS`).
- `input-gesture-resolver.md` line 240 (press outside the field): a press outside `FIELD_RECT` is not forwarded (ADR-0006, ADR-0007).
- `input-gesture-resolver.md` line 316 and `design/gdd/battle-hud.md` Rule 2 (line 34): modal screens are Controls that take every event in `_gui_input`; the adapter's press block keeps the same taps from the resolver.
- ADR-0003 (Accepted) step 1g (line 89) and its Implementation Guidelines: add "then `forget_open_presses()`" after `resolver.cancel()`. This is additive and changes no frame order.
- ADR-0006 (Proposed, not yet Accepted, so edited in its own review): section 5 to the revised block (forwards nothing, never calls `cancel_pointer`; legal only with a cancel request); D6 text to say the adapter reads `_input`; section 5 and its guideline "Modal screens must use `_gui_input` with class checks" gain the family lock (a modal accepts a release only from the family of the press it saw), required now; the step 1g line of its Architecture Diagram ("wrapper step 1g") and its guideline "The wrapper must replace `FieldSpace` only at step 1g, after `resolver.cancel()`" both gain "then `forget_open_presses()`", so the step 1g order is `resolver.cancel()`, `forget_open_presses()`, then `set_space`.
- Open Question A6 is closed by this ADR: no slop scale cap at MVP (section 8); the architecture A6 row edit above records it.
- `project.godot`: add the two emulation keys (first adapter story).

## Validation Criteria
- Gate unit tests (`tests/unit/input/`, headless, a recording fake resolver, a fake `RealClock`, a fixture `FieldSpace`): every sequence of touch and mouse primitives, including random interleavings from a fixed seed list, leaves each forwarded press with exactly one closer, and `open_indexes()` empty after the last release or `forget_open_presses()`.
- Named cases: cancel flag true gives `cancel_pointer`, never `release`; re-press of an open index gives `cancel_pointer` then `press`; mouse motion without the left button gives `cancel_pointer(1024)`; a touch during an open mouse press is dropped, and the reverse; a press outside the field, in the edge margin or in an inset strip opens nothing and logs `rejected`; while blocked nothing is forwarded and no cancel is called; after `forget_open_presses` a release is dropped.
- A test that `InputAdapter` and `PointerGate` declare no signals, and a source check that they contain no `_process`, `Time.`, `set_input_as_handled` or `device == 0`.
- Wrapper integration test (`tests/integration/input/`): a modal mount with an open press, then step 1g, ends with `drag_cancelled` and `idle` once, and the debug check fires when a block has no cancel request.
- First device build (device-assumptions.md checklist): I1 to I6 and I9 to I11 confirmed and written into `modules/input.md`; a scripted run of edge swipes, palm touches and focus loss with a finger down gives zero `tap` or `drag_ended` from a cancel.
- Pillar 4 phone test (TR-input-005): zero mis-fires and at most 5% misses over 20 attempts, from the gesture log.

## Related
- Depends on ADR-0002 (resolver signals), ADR-0003 (queue, `RealClock`, step 1g), ADR-0006 (`FieldSpace`, layers, press block, `ResumeCommand`), ADR-0001 (Input record).
- Enables ADR-0008 (wrapper owns the adapter, lifecycle and the step 1g calls).
- Amends ADR-0003 step 1g additively (Migration Plan) and asks ADR-0006 to adopt the revised press block and emulation stance.
- Reviews: engine specialist and TD-ADR not yet run.
