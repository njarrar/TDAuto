# ADR-0006: Stretch Mode, Coordinate Space, Safe Area and HUD Layering

## Status
Proposed. **Must not be Accepted until the phone spike (architecture Gate Finding GF5, Open Question A7) confirms verification items D2 to D7, D9, D10 and D12 on a target phone running Godot 4.7.2, and a desktop run confirms D1 and D8.** Touch events, safe-area APIs and part of the stretch behaviour are NOT SOURCEABLE from `docs/engine-reference/godot/`; see Engine Compatibility.

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
njarrar (project owner); technical-director and lead-programmer (architecture gates, 2026-11-02, findings GF4 and GF5); godot-specialist (draft author). Engine specialist and TD-ADR reviews are still to run.

## Summary
The resolver, `targets()`, the views and the HUD need one coordinate space, a stretch mode that is set on purpose (`project.godot` sets none, Open Question A4), a way to turn safe-area insets into that space, and a fixed layer order so modal screens take every event before gameplay input (warning M6). This ADR sets `canvas_items` stretch with `expand` aspect at a 540 by 960 base, places one 540 by 960 field (the only space gameplay knows) bottom-centred in the visible area behind opaque margin curtains, routes every screen point through one pure `FieldSpace` object, puts the HUD and modal screens on fixed `CanvasLayer`s with a press block in the adapter as a backstop, adds a queued `ResumeCommand` for the Paused tap, draws enemies and effects from fixed record pools in one canvas item each, and keeps the Mobile renderer pending a device check.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | UI / Rendering |
| **Layer** | Presentation (its coordinate space, `FieldSpace`, is a Foundation object used by the input adapter and WaveSim) |
| **Knowledge Risk** | HIGH (UI and Input are HIGH in VERSION.md; 4.7 changed stretch defaults for new projects; safe area and touch are not in the reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (4.7 stretch defaults for NEW projects only; `CanvasItem` lines lose the antialiasing feather; `DEVICE_ID_MOUSE`); `deprecated-apis.md` (`event.device == 0`); `current-best-practices.md` (4.7 stretch defaults; Android edge-to-edge display in 4.5+); `modules/ui.md` (4.5 recursive mouse disable, 4.6 dual focus); `modules/rendering.md` (Forward+, Mobile, Compatibility); `modules/input.md` (no touch coverage) |
| **Post-Cutoff APIs Used** | The 4.7 stretch keys `display/window/stretch/mode` and `display/window/stretch/aspect` (values sourced). 4.7 `CanvasItem` line drawing without feather (sourced; tracers widened). 4.7 typed-return overrides apply to `ResumeCommand.apply`. No other post-cutoff API |
| **Verification Required** | **NOT SOURCEABLE** from `docs/engine-reference/godot/` unless marked. (D1) With no stretch keys in `project.godot`, which mode applies on 4.7.2: memory believes the setting's default changed, so an absent key means `canvas_items`/`expand`, but the reference says only "new projects". Moot once the keys are written (this ADR writes them); confirm in the editor's Project Settings. (D2) Under `canvas_items`, an input event's `position` as delivered to a Node is in base viewport units (memory, unverified), not window pixels; `FieldSpace` holds an event-to-canvas transform so either answer works; `FieldSpace.make` computes `event_xform` from the viewport's stretch transform, nothing else does. (D3) Where `expand` puts the extra area and how to read it: memory says `get_viewport().get_visible_rect()` with origin (0, 0) and the extra area right and below; `FieldSpace` computes the origin from the visible rect, so placement survives either. (D4) Safe area: memory says `DisplayServer.get_display_safe_area()` returns a `Rect2i` in screen pixels on iOS and Android; also whether Android edge-to-edge (listed for 4.5+) is on by default, so the game draws under the system bars. Hidden behind `SafeAreaSource`, which returns pixels; `FieldSpace` alone converts them to canvas units with the same stretch transform. (D5) Which notification fires on a window resize or safe-area change (memory: `Viewport.size_changed`); ADR-0008 owns the hook, this ADR the rebuild it triggers. If no safe-area signal exists, insets are read at build and on each resize only. (D6) A full-screen `Control` with `mouse_filter = STOP` on a higher `CanvasLayer` receives the touch press and release in `_gui_input` under the event family ADR-0007 picks, and stops them before `_unhandled_input` (memory). The adapter's press block makes correctness independent of the answer; D6 decides only whether the fallback route is needed. If ADR-0007 feeds the adapter from `_input`, which runs before GUI input (memory), the press block is the main route, not the backstop. (D7) `mouse_filter = IGNORE` Controls pass touch through to the adapter's input path (memory). (D8) Key names `display/window/size/viewport_width`, `viewport_height` and `display/window/handheld/orientation` (portrait = 1) (memory). (D9) The Mobile renderer starts and holds the 30 fps floor on the lowest target Android; whether 4.7.2 falls back to Compatibility on a device without Vulkan (memory: `rendering/rendering_device/fallback_to_opengl3`). (D10) The API giving width in dp for the 360 dp guard (memory: `DisplayServer.screen_get_dpi()` or `screen_get_scale()`); the guard only logs. (D11) `CanvasLayer.layer` orders drawing and input between layers, and `CanvasLayer.offset` moves a layer in base viewport units under `canvas_items` (memory, long-standing, LOW). (D12) Touch and mouse emulation: the keys `input_devices/pointing/emulate_mouse_from_touch` and `emulate_touch_from_mouse` (memory, unverified names), their effect, and that with both `false` a phone touch reaches a Control's `_gui_input` as `InputEventScreenTouch` only and a desktop click as `InputEventMouseButton` only. With emulation on, a modal accepting both classes could see one touch twice |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted): canonical signals, reads and commands, the wiring rules, `VIEW_SIGNALS`. ADR-0003 (Accepted): the frame steps, `Battle.enqueue`, `BattleCommand`, `RealClock`, step 1g `cancel()`. ADR-0001 (Accepted) for the Options and Stage records |
| **Enables** | ADR-0007 (the adapter converts every position through `FieldSpace` and honours the press block); ADR-0008 (the wrapper builds the layers named here and forwards `resized`); the Mobile Platform ADR (deferred: device budgets, tall-phone margin look) |
| **Blocks** | Battle HUD epic; every story that converts a screen position (Input adapter, TowerInput, HeroInput); the enemy and combat view stories; the `project.godot` display keys |
| **Ordering Note** | Accepted before ADR-0007 (GF4). **This ADR must not be Accepted until the phone spike (GF5, A7) has run** and confirmed, on Godot 4.7.2 on a target phone: D2 (event positions under `canvas_items`), D3 (visible rect and extra-area placement), D4 (safe-area call and units; Android edge-to-edge), D5 (resize and safe-area notifications), D6 (modal Control receives touch and stops it), D7 (IGNORE passes touch), D9 (Mobile renderer on the lowest target Android, or the fallback), D10 (dp width). D1 and D8 are closed on desktop by the first display-keys story. The spike extends `docs/engine-reference/godot/` with each answer. If D6 fails, the fallback route in section 5 becomes the primary route before acceptance |

## Context

### Problem Statement
Every gameplay position in the GDDs is in field units on a 540 by 960 reference (Input GDD, Positions and units; Enemy & Wave Rule 4: targetable only inside 0 to 540, 0 to 960). The engine delivers points in its own space, which depends on the stretch mode, and `project.godot` sets none. The 4.7 change to stretch defaults applies to new projects only (`breaking-changes.md`), and this project's file has no keys, so the effective mode is unknown (A4). Phones are taller than 9:16 (a 360 by 800 dp phone, HUD "Handed to owning GDDs"), have notches and gesture bars, and a wider tablet could reveal the off-field path entry (Enemy & Wave open question). The HUD layout needs insets in field units (`I_top`, `I_bottom`). Modal screens must take every event before the adapter (HUD Rule 2, architecture 4.6), but the Paused resume tap has no route (M6). Enemy and effect views need a pooling rule (TR-enemy-007). The renderer is Mobile in `project.godot` and `project.yaml`, and its fit on low-end Android is open (A8). This must be fixed before ADR-0007, because the adapter converts positions into the space chosen here (GF4).

### Constraints
- Simulation is plain objects with no scene, no camera and no display reads (Flow Rule 2). The resolver never reads a camera, the display or the clock (Input GDD).
- No autoload; dependencies are injected by the builder or the wrapper (registry `catalogue_global_access`, `event_bus_autoload`).
- Views never write; they read and queue commands (ADR-0002 wiring rule 5, registry `direct_sim_command_from_input`).
- No sim object, input piece or HUD logic uses `_process` or reads engine time (registry `engine_time_outside_driver`); views may animate in their own `_process`, reading only (ADR-0003 section 1).
- The minimum supported width is 360 dp, where 72 field units is 48 dp (Input formula `target_ok`; art bible §3).
- MVP runs on desktop at 540 by 960, where every inset is 0 (HUD Layout).
- Engine facts outside the reference are verification items, and the design must survive either answer where it can.

### Requirements
- TR-input-006: the gesture coordinate space stays fixed for a gesture's life; a resize or restretch cancels it; reference field 540 by 960; below 360 dp unsupported.
- TR-enemy-007: at most 48 enemies alive (`peak_alive_ub`); views pool.
- TR-hud-001: modal result and Paused screens are full-screen Controls that consume events before the adapter; the HUD holds no gameplay state.
- TR-hud-002: arc discs TAP 300, backdrop TAP 250 sink, Start/Call TAP 350 radius 48, registered with the resolver.
- TR-hud-004: layout anchors to safe areas; targets at least 44 pt / 48 dp; portrait 540 by 960 reference.
- TR-hud-007: Start/Call arms over 300 ms of real time; `call_prompt_done` is set on the first call after the prompt shows.

## Decision

### 1. Stretch settings, written on purpose (A4)
`project.godot` gets these keys, so the result does not depend on how 4.7 treats a file with none (D1):

```
[display]
window/size/viewport_width=540
window/size/viewport_height=960
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1
```

- **`canvas_items`**: 2D draws at the screen's own resolution with a scale transform, so text and lines stay sharp on a phone. This matters more in 4.7, where `CanvasItem` lines draw with no feather and look thinner (sourced). `viewport` mode would render at 540 by 960 and upscale, blurring 14 dp text.
- **`expand`**: the scale is `min(width / 540, height / 960)`, so a taller phone scales by width (the Input GDD's `field_scale = width_dp / 540`) and a wider tablet by height (the Input GDD's "height-limited tablet"). The extra area becomes visible canvas, not black bars, which the curtains in section 3 then cover. `keep` would put letterbox bars outside the viewport, where event positions fall outside the field and safe-area insets may sit inside bars.
- **Portrait only**, base 540 by 960. The orientation key's name and value are D8.
- Desktop opens a 540 by 960 window; resizing it is a `resized` lifecycle state (section 4).

### 2. The field space
There is one gameplay coordinate space: **field units**, origin at the field's top-left, x right, y down, field rect `Rect2(0, 0, 540, 960)`. Path points, slots, the hero, enemies, hit discs, `pin_rect`, `pin_exclusion`, aim points and the HUD layout table are all in it. One field unit is one base viewport unit; under `canvas_items` it is `scale` screen pixels.

`FieldSpace` is a pure Foundation object (`res://src/input/field_space.gd`). The wrapper builds one at battle build and a new one after each resize; it never changes after construction.

```gdscript
class_name FieldSpace extends RefCounted
const FIELD_SIZE := Vector2(540.0, 960.0)
const FIELD_RECT := Rect2(Vector2.ZERO, FIELD_SIZE)

var origin: Vector2              # field top-left, in canvas (base viewport) units
var event_to_canvas: Transform2D # identity if D2 holds; else the inverse stretch transform
var visible_rect: Rect2          # the visible canvas rect (D3)

static func make(visible: Rect2, event_xform: Transform2D) -> FieldSpace
func to_field(event_pos: Vector2) -> Vector2      # event_to_canvas * event_pos - origin
func to_canvas(field_pos: Vector2) -> Vector2     # field_pos + origin
func contains(field_pos: Vector2) -> bool         # FIELD_RECT.has_point, edges included
func margin_rects() -> Array[Rect2]               # visible area outside the field, in field units
static func mirror_x(x: float) -> float           # FIELD_SIZE.x - x, for the handed elements
```

- **Placement.** The field is centred horizontally and **bottom-anchored** vertically in the visible rect: `origin.x = visible.position.x + (visible.size.x - 540) / 2`, `origin.y = visible.end.y - 960`. Bottom anchoring keeps the burst button and the lower lane at the thumb (Principle 7, art bible §7 "bottom 30%"), and makes `I_bottom` the inset that matters, which is what the HUD's burst formula `y = clamp(888 - I_bottom, 816, 888)` assumes. On a 9:20 phone the extra 240 units sit above the field. How that top margin looks (an extended band, plain colour) is the Mobile Platform GDD's; it is one value in `make` and moves nothing else.
- **The adapter** converts every event position with `to_field` and forwards field units (ADR-0007 owns which events). A press whose field point is outside `FIELD_RECT` is not forwarded (no press, so the adapter contract has nothing to close). Moves and releases of a forwarded press are converted but not clamped; what they mean off the field is ADR-0007's and the owners'.
- **`targets()`** tests `FieldSpace.FIELD_RECT.has_point(position)` with the constant. WaveSim never holds a `FieldSpace` instance; it reads only the constant, a same-or-lower-layer reference.
- **540 by 960 is structural**, like `Battle.DT`: it is the space the data is authored in, not a tuning value, so it is a constant, not a catalogue field.
- **One space per gesture (TR-input-006).** The adapter reads the wrapper's current `FieldSpace` per event; the wrapper replaces it only at frame step 1g, after `resolver.cancel()` (section 4). So a gesture never mixes two spaces.
- **Headless:** nothing builds a `FieldSpace` instance; tests build one from a fixture rect.

### 3. Layers and the wrapper's tree
The wrapper (ADR-0008 owns its lifetime) builds this order. Lower layers draw first; higher layers take GUI input first (D11).

```
BattleWrapper (Node)
├─ InputAdapter (Node, not a Control; ADR-0007)
├─ World (Node2D, position = FieldSpace.origin)              canvas layer 0
│   ├─ Stage scene (scene_ref, look only)
│   ├─ Tower views, Hero view
│   ├─ EnemyLayer (one Node2D, one _draw)                     section 7
│   └─ CombatView (one Node2D, one _draw)                     section 7
├─ HudLayer (CanvasLayer, layer 10, offset = FieldSpace.origin)
│   ├─ Curtains (Node2D; draws margin_rects() opaque)
│   ├─ HudField (Node2D; one _draw: arc, chip, Start/Call, burst art, rings)
│   └─ HudTopBand (Control tree; mouse_filter IGNORE throughout)
└─ ModalLayer (CanvasLayer, layer 20, offset 0)
    ├─ PausedScreen (Control, full visible rect, mouse_filter STOP, hidden)
    └─ ResultScreen (Control, full visible rect, mouse_filter STOP, hidden)
AppRoot FatalScreen: CanvasLayer 30 (ADR-0008)
```

- **Curtains** cover everything outside the field with the panel colour, on a layer above the world. So an enemy entering by a side edge or leaving by the bottom stays unseen on any aspect, and "visible" equals "targetable" (Enemy & Wave Rule 4). This answers Enemy & Wave's stretch question: layout rules L3, L5, L6 and L7 see the same 540 by 960 field on every device, so only the inset-dependent ones need a recheck. No clip API is used, only `draw_rect`.
- **The only Controls that can stop input are the two modal screens.** Every other HUD Control has `mouse_filter = IGNORE` (HUD Rule 1: the top band ignores input). This settles a conflict: the Input GDD's HUD row says the top-band Controls "consume their own events"; HUD Rule 1, the owner, says they ignore input, and this ADR follows the owner (Migration Plan). HudField is a `Node2D`, so it is never in GUI hit testing; its tappable parts are resolver discs.
- **All hit discs are registered in field units**, by their owners, at the priorities of the Input GDD table: Start/Call TAP 350 radius 48, arc discs TAP 300, arc backdrop TAP 250 sink, chip TAP 300 radius 40 (TowerInput), burst sink TAP 400 and burst DRAG 100 (HeroInput) (TR-hud-002). Every thumb target's radius is at least 36, so `2 × r × 360 ≥ 48 × 540` holds at the minimum width.

### 4. Resize and the gesture's life
- A resize (desktop window, or a safe-area change on a phone, D5) reaches the wrapper's notification hook. ADR-0003 holds lifecycle states and forwards them in step 1b; for `resized` the wrapper also requests `cancel()` (the same request as Paused).
- At step 1g, after `resolver.cancel()`, the wrapper builds a new `FieldSpace` from the viewport, moves `World` and `HudLayer`, and recomputes the insets (section 6). This extends ADR-0003 step 1g; nothing else in the frame moves.
- A press that arrived after the real resize but before the step used the old space and is cancelled at 1g. A whole tap completed inside one frame of a resize keeps the old space, which TR-input-006 permits ("one coordinate space for the gesture's life").
- A resize does not pause the battle (Input GDD Rule 7).

### 5. Modal screens and the Paused resume route (TR-hud-001, M6)
**Primary route: the Control.** PausedScreen and ResultScreen are full-visible-rect Controls with `mouse_filter = STOP` on layer 20. Each handles its own `_gui_input`, accepting both `InputEventScreenTouch` and `InputEventMouseButton` by class, never by device (4.7, `deprecated-apis.md`). They are plain Controls with HudLogic models, not `Button`s, so the HUD rule holds exactly: a screen fires only on a release whose press it saw while Armed, and clears that press on any `lifecycle_changed(state)` (HUD Rule 2).

**Backstop: the adapter's press block.** Whether a STOP Control stops the adapter depends on the input path ADR-0007 picks and on D6. So correctness does not rest on it:

```gdscript
# InputAdapter (ADR-0007 implements; this ADR fixes the contract)
func set_input_blocked(blocked: bool) -> void
# true: if a forwarded press is open, call resolver.cancel_pointer(index) at once;
#       forward no new press until false. Moves and releases of no open press are dropped.
```

The wrapper injects `adapter.set_input_blocked` into the HUD as a `Callable`. The HUD calls it with `true` when it mounts a modal and `false` when it unmounts one. Modals mount only from `phase` handlers for Paused, Won, Lost and Fatal, which ADR-0003 emits outside any tick (steps 1b, 1d, 1f2), so `cancel_pointer` never runs inside a tick. This is one gate in the adapter, not a gate in each owner, so HUD Rule 2's "no second resolver and no gate in each owner" still holds.

**Fallback route if D6 fails** (the Control gets no touch press under ADR-0007's event family): while blocked, the adapter passes raw press and release points, in field units, to an injected `modal_sink: Callable` instead of dropping them, and the modal screen judges them with the same HudLogic model. Only the adapter and the modal screens change.

**Resume.** A resume tap on PausedScreen queues a new command:

```gdscript
class_name ResumeCommand extends BattleCommand   # (no args) -> StageFlow.resume(); returns OK, HALTED or NOT_PAUSED
```

It drains in step 1b with the clock stopped, like every command (ADR-0003), and is logged like the rest. StageFlow returns to the phase it left and emits `phase` (Flow Rule 17); the HUD unmounts PausedScreen and unblocks the adapter in that `phase` handler. A finger held across the pause stays dead: its press was cancelled by the block, and the screen never saw it. This answers M6 and replaces a direct call from a view into StageFlow, which ADR-0002 rule 5 forbids. It adds a sixth command to ADR-0002's table and ADR-0003's subclass list (Migration Plan).

ResultScreen's Retry and Play again call `AppRoot.request_retry()` (ADR-0002), which only sets a latch (HUD Rule 18).

### 6. Safe area (TR-hud-004)
```gdscript
class_name SafeAreaSource extends RefCounted     # injected; desktop and tests return the full rect
func safe_rect_canvas() -> Rect2                 # the safe area in canvas units (D4 converts pixels)

class_name FieldInsets extends RefCounted        # pure
static func from(space: FieldSpace, safe: Rect2) -> FieldInsets
var top: float     # max(0, safe.position.y - space.origin.y)
var bottom: float  # max(0, (space.origin.y + 960) - safe.end.y)
var left: float
var right: float
```

- `I_top` and `I_bottom` in the HUD layout table are `FieldInsets.top` and `.bottom`. With bottom anchoring, a notch usually sits in the top margin, so `I_top` is often 0 on tall phones and `I_bottom` carries the gesture bar.
- The phone implementation wraps the platform call (D4). If the spike finds no usable call, `SafeAreaSource` returns authored per-platform insets from the Options record, and nothing else changes.
- Insets are recomputed only with a new `FieldSpace` (section 4), so layout never shifts mid-gesture.
- **Below 360 dp** (D10): the wrapper logs a development error once at build. It does not refuse to run; the store filter excludes those devices (Input GDD edge case).

### 7. Left-hand mirroring
- Only the burst button, its digit, and the burst's `pin_exclusion` shapes are handed (HUD edge case; Hero Rule 2; Hero "Left hand mirrors the button and digit only"). Start/Call, the arc order and everything in the field stay put.
- The hand is the Options record's `left_hand`, read once at build and fixed for the battle (Hero Rule 2). Changing it needs a rebuild.
- One pure function places the button for both its art and its disc: `HudLayout.burst_centre(left_hand: bool, insets: FieldInsets) -> Vector2`, giving x 456 or `FieldSpace.mirror_x(456)` = 84 and `y = clamp(888 - insets.bottom, 816, 888)`. HudField draws there; HeroInput registers there. The two can never disagree.
- The field transform is never flipped: a negative scale would mirror text and the path.
- `pin_exclusion` stays authored data per hand (ADR-0001); the content test adds a check that each left-hand burst shape equals the mirror of its right-hand shape.

### 8. Views, pools and `_process`
- **Enemies (TR-enemy-007).** One `EnemyLayer` canvas item draws every enemy in one `_draw`, from `wave().roster()` read in step 1f. Per-enemy presentation state (fade, notch angle) lives in a record pool pre-sized to 48 (`peak_alive_ub`'s bound), keyed by `spawn_id` and reused. No node is created or freed per enemy. If the roster exceeds the pool, the pool grows and logs a development error, because an invisible enemy is worse than a hitch (Enemy & Wave edge case). The pool is rebuilt with the views on Retry.
- **Effects.** CombatView draws tracers and flashes in one `_draw` from a ring buffer of 64 effect records filled by `attack_fired` and `damage_applied`. When full, the oldest is overwritten and debug builds warn once per second; a lost tracer is cosmetic. Tracers are drawn at least 2 field units wide to offset the 4.7 thinner lines (sourced).
- **`_process` in views.** Views may animate in their own `_process` and use `Tween` for art only (alpha, fades, icon loops, the 120 ms collapse), reading only. A view `_process` must never queue a command, register or unregister a target, change HudLogic state, or write anything another object reads. HUD state that the rules depend on (Start/Call and Retry arming) advances only through `hud.advance(ms)`, called by the wrapper in step 1f with the frame's delta in ms clamped to 100, and ignored while Paused (HUD Rule 11, TR-hud-007). `call_prompt_done` is set by the HUD from the `StartNextWaveCommand`'s `on_result` when the prompt has shown (HUD Rule 13).

### 9. Renderer (A8)
Keep **Mobile** (`renderer/rendering_method="mobile"`, as set). The game draws only 2D `CanvasItem` primitives and text, with no custom shaders, so switching to Compatibility is one project setting with no code change. Rule: no code or asset may depend on a renderer-only feature. The spike runs the build on the lowest target Android (D9); if Mobile fails to start or misses the 30 fps floor there, the project switches to Compatibility, recorded by amending this section. Draw-call and memory budgets stay with the deferred Mobile Platform ADR (TR-hud-008).

### Architecture Diagram

```
engine event --> InputAdapter --FieldSpace.to_field--> GestureResolver (field units)
                     ^  set_input_blocked(bool) <-- HUD (modal mount/unmount, via injected Callable)
                     |
ModalLayer 20   PausedScreen / ResultScreen (STOP) --ResumeCommand--> Battle.enqueue
HudLayer 10     Curtains | HudField (_draw) | HudTopBand (IGNORE)       offset = origin
World 0         Stage | Towers | Hero | EnemyLayer (pool 48) | CombatView (ring 64)   position = origin

wrapper step 1b: forward `resized` + request cancel
wrapper step 1f: hud.advance(min(delta_ms, 100)); views redraw from reads
wrapper step 1g: resolver.cancel(); if resized: new FieldSpace, move layers, new FieldInsets
```

### Key Interfaces
`FieldSpace` (constants `FIELD_SIZE`, `FIELD_RECT`; `make`, `to_field`, `to_canvas`, `contains`, `margin_rects`, `mirror_x`); `SafeAreaSource.safe_rect_canvas() -> Rect2`; `FieldInsets.from(space, safe)`; `HudLayout.burst_centre(left_hand, insets) -> Vector2`; `InputAdapter.set_input_blocked(blocked: bool)`; fallback `modal_sink: Callable`; `ResumeCommand` (sixth `BattleCommand`) and `StageFlow.resume() -> int` (`OK`, `HALTED`, `NOT_PAUSED`); `BattleHud.advance(ms: float)`.

### Implementation Guidelines
- `project.godot` must carry the five display keys of section 1; no code may change stretch settings at runtime.
- Every screen position must enter gameplay through `FieldSpace.to_field`; no other code may read an event position, a camera, or the viewport size for gameplay.
- Simulation code must never hold a `FieldSpace` instance; it may read `FieldSpace.FIELD_RECT` and `FIELD_SIZE`.
- The wrapper must replace `FieldSpace` only at step 1g, after `resolver.cancel()`.
- The adapter must not forward a press outside `FIELD_RECT`.
- Every HUD Control other than PausedScreen and ResultScreen must have `mouse_filter = IGNORE`.
- Modal screens must use `_gui_input` with class checks, never `Button`, and must fire only on a release whose press they saw while Armed.
- The HUD must call `set_input_blocked(true)` on every modal mount and `false` on unmount, only from `phase` handlers.
- The Paused tap must queue `ResumeCommand`; no view may call `StageFlow` directly.
- The burst button's art and disc must both come from `HudLayout.burst_centre`.
- No transform in the wrapper tree may have a negative scale.
- Enemy and effect views must not create or free nodes per enemy or per effect during a battle.
- View `_process` code must only change its own art state.
- No code or asset may depend on a renderer-only feature.

## Alternatives Considered

### Alternative 1: `canvas_items` with `keep` (letterbox)
- **Description**: Scale the 540 by 960 base to fit and show bars elsewhere.
- **Pros**: The visible canvas is exactly the field; no curtains or origin.
- **Cons**: Bars fall outside the viewport, so a press in a bar gives a position outside the field; the safe area may sit inside a bar and cannot be used; a 9:20 phone loses a fifth of its screen to bars with no chance to extend the band.
- **Rejection Reason**: `expand` plus curtains gives the same visible field and keeps the margins usable later.

### Alternative 2: `viewport` stretch mode
- **Description**: Render at 540 by 960 and scale the image.
- **Pros**: Pixel-identical on every device.
- **Cons**: Blurry 14 dp text and thin 4.7 lines on a 1080-pixel phone.
- **Rejection Reason**: Legibility at the text floor (art bible §7).

### Alternative 3: A `Camera2D` to place the field
- **Description**: Position the field with a camera instead of moving `World`.
- **Pros**: Familiar.
- **Cons**: Field units then differ from viewport units, and the Input GDD notes field units are viewport space only with no `Camera2D`; HUD layers would need separate handling.
- **Rejection Reason**: Adds a transform with no gain.

### Alternative 4: The Paused screen as a resolver sink (M6's other option)
- **Description**: Register a field-wide TAP sink at top priority while Paused.
- **Pros**: No reliance on Control input.
- **Cons**: Presses in the margins miss it; it contradicts HUD Rule 2 and architecture 4.6 ("modal screens are Controls"); the Result screen would need the same.
- **Rejection Reason**: The block plus the fallback route reaches the same safety and keeps the GDD rule.

### Alternative 5: One node per enemy from a node pool
- **Description**: Pre-instantiate 48 enemy scenes and toggle visibility.
- **Pros**: Per-enemy tweens.
- **Cons**: 48 canvas items to sort and batch; enemies are plain circles drawn from primitives (art bible §3).
- **Rejection Reason**: One canvas item meets TR-enemy-007's intent (no node churn) at lower cost. The TR wording is updated to say "views pool enemy presentation".

### Alternative 6: Centre the field vertically on tall phones
- **Description**: Split the extra height above and below.
- **Pros**: Balanced margins.
- **Cons**: Lifts the burst button 120 units off the thumb's edge on a 9:20 phone.
- **Rejection Reason**: Thumb first (Principle 7). The Mobile Platform GDD may revisit it; it is one line in `FieldSpace.make`.

## Consequences

### Positive
- Gameplay, tests and data share one fixed space; no sim code knows the screen.
- Stretch is explicit, so the 4.7 default question (A4) no longer matters.
- Every device shows exactly the authored field; off-field entry stays hidden on any aspect.
- Modal safety does not depend on unverified engine event order (D6).
- The Paused resume has a queued, logged route (M6).
- Renderer switching costs one setting.

### Negative
- A sixth command and a `StageFlow.resume()` read; ADR-0002 and ADR-0003 tables must be amended.
- A tall phone shows an empty top margin until the Mobile Platform GDD styles it.
- The adapter gains a block flag and possibly a modal sink.
- One `_draw` for all enemies redraws every frame even when little moves.

## Risks
- **D2 wrong (positions in window pixels).** Mitigation: `event_to_canvas` absorbs it; a unit test feeds both.
- **D6 fails.** Mitigation: the block keeps gameplay safe; the fallback route makes resume work. Decided on the spike before acceptance.
- **D4 has no usable API on one platform.** Mitigation: authored insets through `SafeAreaSource`.
- **Burst `pin_exclusion` data assumes y 888 while `I_bottom` moves the button to 816.** Mitigation: the content test checks exclusion against the worst inset the Mobile GDD sets (Enemy & Wave L3/L7 recheck).
- **A tap fully inside a resize frame.** Accepted; rare on a portrait-locked phone.
- **Mobile renderer fails on low-end Android (D9).** Mitigation: Compatibility switch with no code change.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | Positions and units: field units on 540 by 960; one space per gesture, resize cancels (TR-input-006, Edge Cases "resized mid-gesture") | Sections 2, 4 |
| input-gesture-resolver.md | `target_ok` at 360 dp; below 360 dp unsupported | Sections 3, 6 |
| enemy-wave.md | Rule 4, targetable inside 0 to 540, 0 to 960; Edge Cases, view pool overflow; open question on stretch (TR-enemy-007) | Sections 2, 3 (curtains), 8 |
| battle-hud.md | Rule 2, modal Controls consume before the adapter; Rule 17, tap to resume (TR-hud-001, M6) | Section 5 |
| battle-hud.md | Rule 6 and Input table priorities (TR-hud-002) | Section 3 |
| battle-hud.md | Layout table, `I_top`, `I_bottom`; "Handed to owning GDDs: stretch mode" (TR-hud-004) | Sections 1, 2, 6 |
| battle-hud.md | Rule 11, 300 ms real-time arming, clamp 100 per frame; Rule 13, `call_prompt_done` (TR-hud-007) | Section 8 |
| battle-hud.md | Edge case "handedness is left" | Section 7 |
| hero-system.md | Rule 2, `left_hand` read at build, `pin_exclusion` per hand | Section 7 |
| game-state-stage-flow.md | Rule 17, a tap resumes and reaches nothing beneath | Section 5 |
| art-bible.md | §3 minimum sizes; §7 bottom 30% and panel band | Sections 2, 3 |

## Performance Implications
- **CPU**: One `to_field` per input event; one `_draw` each for enemies (at most 48 circles), effects (at most 64 records) and HudField per frame. Negligible against the 16.6 ms frame.
- **Memory**: 48 enemy records and 64 effect records per battle, rebuilt on Retry. No per-enemy nodes.
- **Load Time**: None beyond building the three layers.
- **Network**: None.

## Migration Plan
No code exists yet. **These edits land in the same change that marks this ADR Accepted:**

- `project.godot`: add the five `[display]` keys of section 1.
- `docs/architecture/architecture.md`:
  - 3.1: step f gains `hud.advance(min(delta_ms, 100))`; step g gains "then, after a forwarded `resized`, rebuild `FieldSpace` and insets".
  - 4.2: add `InputAdapter.set_input_blocked(blocked: bool)` and the optional `modal_sink`; add `FieldSpace` to Foundation; the adapter drops presses outside `FIELD_RECT`.
  - 4.3: add `ResumeCommand` to the command list and `StageFlow.resume() -> int`.
  - 4.5: `targets()` uses `FieldSpace.FIELD_RECT`.
  - 4.6: modal screens are Controls on layer 20 with the adapter block as a backstop; the Paused tap queues `ResumeCommand`.
  - 4.7: `DisplayServer` safe-area row points to `SafeAreaSource` and D4.
  - Module Ownership, Foundation: add `FieldSpace`, `FieldInsets`, `SafeAreaSource`; Presentation: Curtains, EnemyLayer.
  - Baseline TR-enemy-007: "views pool enemy presentation records (one canvas item)".
  - Open Questions A4, M6 and A8: closed by ADR-0006 (A8 pending D9).
- `docs/architecture/adr-0002-signal-contracts-and-wiring-conventions.md` (Accepted): add a cross-reference note, not a change of decision, that the Commands table gains `resume() -> int` on StageFlow (`OK`, `HALTED`, `NOT_PAUSED`) by ADR-0006, and the Reads table gains nothing.
- `docs/architecture/adr-0003-frame-order-command-queue-ticks-and-view-update.md` (Accepted): cross-reference note that `ResumeCommand` is a sixth subclass, step 1f includes `hud.advance`, and step 1g swaps `FieldSpace` after a resize, by ADR-0006.
- `design/gdd/input-gesture-resolver.md`: Battle HUD row (around line 127): "its top-band Controls ignore input; its modal screens consume events" (HUD Rule 1 wins). Implementation note (around line 78) and Open Questions row (around line 398): stretch mode is `canvas_items`/`expand`, decided by ADR-0006.
- `design/gdd/battle-hud.md`: Rule 17: "the tap queues a resume command (ADR-0006)"; "Handed to owning GDDs, Technical director": stretch decided by ADR-0006, field bottom-anchored, margins curtained; the burst position comes from one function shared with HeroInput.
- `design/gdd/game-state-stage-flow.md` Rule 17 and Interactions (around line 109): resume reaches Flow as a queued command, `StageFlow.resume()`.
- `design/gdd/enemy-wave.md` open question on stretch (around line 437) and Layout rules note (around line 30): answered by ADR-0006 (curtains; only inset-dependent rules recheck).
- `docs/registry/architecture.yaml`: register the candidates below as Proposed stances.

## Validation Criteria
- Unit tests (`tests/unit/field_space/`): `to_field` with identity and with a scaled `event_to_canvas`; bottom-anchored origin for 540x960, 540x1200 and 720x960 visible rects; `margin_rects` empty at 540x960; `mirror_x(456) == 84`; `FieldInsets` for a notch inside and outside the top margin.
- `HudLayout.burst_centre` gives (456, 888) right-handed at inset 0 and (84, 816) left-handed at inset 100.
- Integration test: every Control under HudLayer has `mouse_filter = IGNORE`; both modal roots are STOP on layer 20.
- Integration test: mounting PausedScreen during a hero drag emits `drag_cancelled` and no `drag_ended`; a release after unmount of a press made while blocked emits nothing.
- Headless test: `ResumeCommand` in Paused returns `OK` and `phase` returns to the left phase; in Wave it returns `NOT_PAUSED`.
- An enemy pool test runs a 48-enemy fixture with no node created after build.
- Retained screenshots in `production/qa/evidence/`: desktop 540x960 HUD; a 9:20 window showing curtains and the bottom-anchored field; left-handed burst.
- Phone spike records D2 to D7, D9, D10; desktop records D1, D8.

## Related
- Architecture: `docs/architecture/architecture.md` Gate Findings GF4, GF5; Open Questions A4, A7, A8, M6; API Boundaries 4.2, 4.5, 4.6, 4.7; Required ADRs row ADR-0006.
- ADR-0001, ADR-0002, ADR-0003 (Accepted; this ADR extends 0002 and 0003 by note). ADR-0007 and ADR-0008 (not yet written) depend on it.
- GDDs: `design/gdd/battle-hud.md` Rules 1, 2, 6, 11, 13, 17, Layout; `input-gesture-resolver.md` Positions and units, Rule 7, `target_ok`; `enemy-wave.md` Rule 4; `hero-system.md` Rule 2; `game-state-stage-flow.md` Rule 17; `design/art/art-bible.md` §3, §7; cross-review `design/gdd/gdd-cross-review-2026-11-02j.md` M6.
