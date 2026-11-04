# ADR-0003: Input Adapter, Display Stretch and Platform Lifecycle

## Status
Accepted

## Date
2026-11-03

## Last Verified
2026-11-03 (against `docs/engine-reference/godot/` for Godot 4.7.2, `docs/architecture/architecture.md` v3 and ADR-0001 Proposed at writing (Accepted 2026-11-04); revised after TD-ADR and godot-specialist reviews). No spike run yet: every item marked **[Sn]** is unverified until that check passes.

## Decision Makers
- Accepted: 2026-11-04 by the user (njarrar); the five product defaults in Decision 5 are confirmed
- Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`)
- godot-specialist: CONCERNS, 2026-11-03. Resolved below (Reviews).
- Technical director (TD-ADR): CONCERNS, 2026-11-03. Resolved below (Reviews).
- Acceptance: the user, 2026-11-04, with the product choices in Decision 5 confirmed. S0a had not run at acceptance: every **[Sn]** item stays unverified, and per Guideline 15 any story that rests on one waits for that check.

## Summary
The pure input resolver needs one engine-facing node that turns Godot touch and mouse events into its five calls in 540x960 field units, never strands a gesture, keeps modal screens from leaking taps to the field, and pauses the battle when the app goes away; little of the engine behaviour this rests on is in the pinned reference. This ADR decides an explicit `canvas_items` + `keep` letterbox at a 540x960 viewport, an `InputAdapter` that reads presses in `_unhandled_input` and tracked endings in `_input`, a modal press gate, emulated pointer events dropped at the adapter, a mouse-only `TapScreen` for modals, a set of lifecycle notifications plus the Android back request, safe-area insets read once per battle on mobile, and a two-part spike (S0a desktop, S0b device) with pass/fail checks.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Input (with UI and display, and app lifecycle) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH. 4.5 to 4.7 are post-cutoff; `modules/input.md` has no touch coverage; the pinned reference names no lifecycle notification and no safe-area API. |
| **References Consulted** | `docs/engine-reference/godot/` (`VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md`, `modules/ui.md`); `architecture.md` v3 (Gap Summary, Module Ownership, Data Flow 1, 5, 6, B2, B3, Required ADRs, QQ-02, QQ-06, QQ-20); `tr-registry.yaml`; ADR-0001; `docs/registry/architecture.yaml` |
| **Post-Cutoff APIs Used** | In the pinned reference: the 4.7 `event.device == 0` ban (the adapter identifies events by class), the 4.7 new-project stretch defaults (overridden by explicit keys), 4.6 dual focus (avoided: `focus_mode = FOCUS_NONE`), 4.5 recursive Control mouse disable (optional, S9). **From memory, unverified**: `InputEvent.DEVICE_ID_EMULATION`, `InputEvent.is_canceled()`, `DisplayServer.get_display_safe_area()`, `get_display_cutouts()`, `screen_get_dpi()`, the notifications `NOTIFICATION_APPLICATION_FOCUS_OUT` / `_IN` / `_PAUSED` / `_RESUMED`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT` / `_IN`, `NOTIFICATION_WM_GO_BACK_REQUEST`, and every setting name in Decision 1. S0a parse-checks the names offline; behaviour needs S0a or S0b. The names and every Decision 1 key are now verified 4.7.2 headless, see probe-results.md; edge-to-edge is an export preset option, not a setting (Decision 1). |
| **Verification Required** | Task S0 (S0a desktop, S0b device), per check. Guideline 15. S0a's parse check and settings dump are verified 4.7.2 headless (`docs/engine-reference/godot/probe-results.md`); S1 to S8 and TapScreen are not run. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): who builds and frees the adapter, the teardown order, `view_wiring`, the three `cancel()` callers. Cannot be Accepted before ADR-0001. |
| **Enables** | ADR-0004 (input before ticks rests on S1), ADR-0008 (the five calls' caller and contract), ADR-0011 (viewport size and stretch), the Mobile Platform & Performance GDD (inherits stretch, safe area, minimum size) |
| **Blocks** | No story exists yet. After `/create-epics`, stories that build the adapter, a modal screen, the display settings, the insets or the pause path wait for acceptance, and each waits only on the spike checks it names (Guideline 15). |
| **Ordering Note** | S0a runs first, within two sessions. S0b runs at the first phone build; if it slips, its rows read NOT ASSESSED and only mobile stories wait. |

## Context

### Problem Statement
The Input GDD defines a pure resolver with five calls and leaves the mapping of engine events to this ADR. The Battle HUD GDD needs modal Controls that block the field and safe-area insets for its layout. The Game State GDD needs focus loss to enter Paused. All three name engine behaviour the pinned reference does not cover, and `project.godot` sets no display or input key, so the 4.7 new-project defaults may or may not apply. ADR-0004 and ADR-0008 both lean on what the adapter guarantees, and the HUD layout and hit-target rule depend on the stretch mode, so this comes before code.

### Constraints
- **Engine**: Godot 4.7.2, single main thread. No device was available to the author; where possible each decision holds under either answer, with a named check.
- **Architecture**: the resolver is pure and clock-free (B2); the adapter is the only engine-facing input code (TR-input-002); no autoloads and no `SceneTree.paused` (ADR-0001); no Camera2D (TR-input-016).
- **ADR-0001 contracts**: three `cancel()` callers: the adapter (pause, focus loss, resize), Flow through `cancel_input()` (Won, Lost, Paused, Fatal), AppRoot at teardown. Every wrapper connection to a sim goes through `view_wiring.connect_recorded()`. Method Callables only. ADR-0001 Guideline 12, verbatim: "Teardown order must be: stop the clock, `resolver.cancel()`, wrapper `process_mode = PROCESS_MODE_DISABLED`, `view_wiring.disconnect_all()`, `remove_child()` and `queue_free()` the wrapper, `battle.unwire()`, drop every reference. Never call `free()` on the wrapper."
- **Team**: solo part-time developer, desktop first (`commands.run` uses `--resolution 540x960`).
- **Testing**: the adapter's logic and `SafeAreaMath` run headless; event order, notifications and safe area need S0.

### Requirements
TR-input-002, 003, 004, 005, 006, 013, 016; TR-state-010; TR-hud-002, 003, 014 (text in `tr-registry.yaml`; mapping in GDD Requirements Addressed).

## Decision

Items that rest on an unverified engine fact carry **[Sn]**, and the S0 table says what changes if that check fails.

### 0. Task S0: the spike
A throwaway scene under `prototypes/input_spike/` (outside the code root). It logs events, notifications and display values to `user://spike_log.txt` and **scores itself on screen**: one PASS / FAIL / NOT ASSESSED line per check. Results go into a dated "Spike results" section here and into `docs/engine-reference/godot/modules/input.md`, with logs and photos in `production/qa/evidence/`. A fail switches to the fallback and this ADR is revised before acceptance.

**S0a, desktop (macOS, pinned 4.7.2, no device; two sessions at most):**
- Parse check, offline: a probe script that names `InputEvent.DEVICE_ID_EMULATION`, `is_canceled()`, the seven notification constants above, `get_display_safe_area()`, `screen_get_dpi()` and `get_display_cutouts()`, run through `res://.claude/scripts/godot-parse-check.gd`. A name that fails is renamed here. All pass (verified 4.7.2 headless, see probe-results.md).
- Settings dump: a headless `SceneTree` script prints `ProjectSettings.has_setting()` and `get_setting()` for every key in Decision 1. The editor drops a value equal to the engine default on save, so the dump checks effective values, never file text. 7 of the 13 Decision 1 keys equal the default (verified 4.7.2 headless, see probe-results.md).
- Then S1, S2, S3, S5, S6 and S9 on desktop, each run both embedded in the editor's Game workspace and as a separate window.

**S0b, device (one Android phone with gesture navigation and a cutout; iOS if available, else NOT ASSESSED, which blocks only an iOS export):** S1 and S2 on Android, S4, S5 mobile, S7, S8, the TapScreen check, and the export preset check: the Android preset in `export_presets.cfg` sets `screen/edge_to_edge=true` beside `screen/immersive_mode`.

| Check | What to do | Pass | If it fails |
|---|---|---|---|
| **S1 Event order** | Log a monotonic sequence number in `_input`, `_unhandled_input`, `_process`, `_physics_process`; force several physics steps per frame (`physics_ticks_per_second` 240, `max_fps` 30); 200 taps, 50 drags | Every input callback of frame N runs before `_process` of N and never between two physics steps of one frame | ADR-0004 queues commands and drains them at the start of its tick driver |
| **S2 Emulation** | 50 taps; log class and `device` of each pointer event | Android: one real `InputEventScreenTouch` and one `InputEventMouseButton` with `device == DEVICE_ID_EMULATION` per touch, the emulated one first, only for the first finger. Desktop: no touch events. The adapter forwards one press per physical press | Fallback F2: one family per platform (`OS.has_feature("mobile")`: touch only, else mouse only) |
| **S3 Control consumption** | Full-rect STOP Control; press it by touch and mouse. Then press open field, drag over it, release on it | (a) The press never reaches `_unhandled_input`. (b) The open-field press's move and release reach `_input`. (c) Controls get the emulated mouse events | (a): the press gate is then the only guard; record it. (b): reopen this ADR. (c): TapScreen also reads `InputEventScreenTouch` with the same keying |
| **S4 Cancel** | Drag, then pull the shade, swipe a system gesture, take an incoming call or alarm, add a palm touch | Each ends the drag by `is_canceled()` or a lifecycle notification; none emits `tap` or `drag_ended`. "Not observed" is an allowed result for each case | Rename if the API differs; the lifecycle path still covers the case |
| **S5 Lifecycle** | Phone: home, app switcher, shade, lock, call, back swipe. Desktop: alt-tab, minimise, click another window. Log each `NOTIFICATION_*` per node class (adapter Node, root Window, a Control) | Every case reaches the adapter by at least one notification in its set, and the battle shows Paused. Note which edge swipes the OS takes before the app sees them | Add the notification seen. If `WM_WINDOW_FOCUS_*` reaches only the Window: fallback, connect `get_window().focus_exited` / `focus_entered` to adapter methods |
| **S6 Positions and resize** | Windows 540x960, 720x1600, 1080x1440; press the field corners and a bar; resize by hand | Corners read (0, 0) and (540, 960) within 1 unit; a bar press reads outside the field; `get_viewport().size_changed` fires on resize | Window pixels: convert with `get_viewport().get_final_transform().affine_inverse()`. No signal: poll `get_window().size` each frame |
| **S7 Safe area** | With the Decision 1 window keys, and the export preset's `screen/edge_to_edge` and immersive settings recorded: log `get_display_safe_area()`, `get_display_cutouts()`, window rect, at frame 1 and after 3 s; draw the computed safe rect as debug outlines; photograph the screen | Outlines clear the cutout in the photo; safe area and cutouts agree; values are stable by battle build | Units differ: scale by `screen_get_scale()`; unstable: sample later |
| **S8 Density** | Log `screen_get_dpi()` | `width_dp` within 5% of the published value | The guard only logs; the store device filter is the gate |
| **S9 Settings** | Settings dump; open Project Settings (Advanced) | Every Decision 1 key exists with that effective value; the 4.5 recursive mouse-filter property is named (`mouse_behavior_recursive`). verified 4.7.2 headless, see probe-results.md. Edge-to-edge is no setting; S0b checks it in the export preset | Use the 4.7.2 name and revise |
| **TapScreen** | 50 taps on the Paused screen, by touch | 50 `tapped`, never 100 | See Decision 4 |

### 1. Display, window and platform settings (QQ-02)
`project.godot` must set these keys explicitly, so the 4.7 new-project defaults never apply by accident **[S9]**:

```ini
[application]
config/quit_on_go_back=false

[display]
window/size/viewport_width=540
window/size/viewport_height=960
window/size/mode=0
window/size/mode.mobile=3
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/stretch/scale=1.0
window/stretch/scale_mode="fractional"
window/handheld/orientation=1

[input_devices]
pointing/emulate_touch_from_mouse=false
pointing/emulate_mouse_from_touch=true
buffering/agile_event_flushing=false
```

7 of these 13 keys equal the engine default (`mode`, `aspect`, `scale`, `scale_mode`, both `pointing` keys, `agile_event_flushing`), so the editor drops them on save. A11 and S9 check effective values, so that is fine (verified 4.7.2 headless, see probe-results.md).

**Export preset, not `project.godot`**: the Android preset in `export_presets.cfg` sets `screen/edge_to_edge=true`, beside `screen/immersive_mode`, so the window reaches the cutout and `SafeAreaMath` sees it. It is not a `ProjectSettings` key, so the settings dump cannot see it; S0b checks the preset. `orientation=1` is portrait; `mode` 0 is windowed on desktop and `mode.mobile` 3 is fullscreen (feature override; names verified 4.7.2 headless, see probe-results.md; use on a phone is S0b). `quit_on_go_back=false` is a product choice the user confirmed (Decision 5).

- **`canvas_items` + `keep`**: the viewport scales by `s = min(window_w / 540, window_h / 960)` and centres. Tall phones letterbox top and bottom, squat screens left and right. Field units equal viewport units with no offset **[S6]**.
- **No Camera2D** in the battle; the field root keeps the identity transform.
- **Taller phones letterbox; they do not reveal the off-field entry.** On a 360x800 dp phone each bar is about 80 dp and usually holds the notch and gesture bar, so in-field insets are often 0. Revealing more field needs a superseding ADR.
- **Minimum size guard (TR-input-016)**: `dp_per_unit = s * 160 / screen_get_dpi()` must be at least 2/3, so a 72-unit target is at least 48 dp: width at least 360 dp **and** height at least 640 dp. It runs once in `BattleWrapper._ready()` on mobile, calls the dev-error sink, and never blocks play **[S8]**.
- **Tablets**: `keep` scales a height-limited screen by height, so no scale cap at MVP.

### 2. The InputAdapter
`InputAdapter extends Node`, built by `BattleWrapper` with the resolver, `edge_reject_margin`, the battle's `FieldInsets` and the dev-error sink's `report`. `process_mode = PROCESS_MODE_ALWAYS` (TR-input-004). It is the only node that reads pointer events for gameplay.

**2.1 Event path (QQ-06) [S1, S3].** Godot runs `_input`, then GUI, then `_unhandled_input`.
- **Presses** are read in `_unhandled_input()`, so a STOP Control under the press takes it first (TR-input-013, TR-hud-002).
- **Moves, releases and cancels** of a forwarded pointer are read in `_input()`, so a STOP Control under a drag cannot swallow them (TR-input-003). Each callback forwards only its own kind.
- The adapter never calls `set_input_as_handled()`.

**2.2 One event family (TR-input-005) [S2].**
- Event class decides the source; `event.device == 0` is never tested.
- Any pointer event with `device == InputEvent.DEVICE_ID_EMULATION` is dropped at the adapter. A phone touch yields one real touch (forwarded) and an emulated mouse event (dropped here, still seen by Controls). A desktop mouse yields one real mouse event.
- Mouse maps to pointer `MOUSE_POINTER = 1 << 16`, which no touch index reaches.
- Only `MOUSE_BUTTON_LEFT` is forwarded; other buttons, the wheel and hover with no forwarded press are dropped (Input Rule 10).

**2.3 Exactly-once forwarding (TR-input-003).** `_down: Dictionary` holds the pointers the adapter forwarded a press for.
- **Press**: drop if the gate is closed (2.4), outside `[0, 540] x [0, 960]`, or in a rejected zone (Decision 3). Else `resolver.press(i, pos)` and set `_down[i]`. A press of an index already in `_down` is forwarded as-is; the resolver treats it as `cancel()` then press (Input Rule 1).
- **Move**: `resolver.move(i, pos)` only if `i` is in `_down`; positions outside the field are forwarded unclamped.
- **Release**: if `i` is in `_down`, erase it, then `resolver.cancel_pointer(i)` if `event.is_canceled()`, else `resolver.release(i, pos)` **[S4]**.
- **Adapter cancel** (lifecycle, back request, resize): `resolver.cancel()`, clear `_down`.
- **Cancels by others** (Flow, AppRoot) leave `_down` alone; the stale release reaches the resolver in Idle and is dropped there. ADR-0001's three callers stay as they are.
- **Teardown safety**: `PROCESS_MODE_ALWAYS` overrides the inherited `PROCESS_MODE_DISABLED` in ADR-0001's step, so that guard skips the adapter. What makes it safe is `remove_child()` in the same call stack as `resolver.cancel()`, plus `_live`: on `NOTIFICATION_EXIT_TREE` the adapter sets `_live = false` and never calls the resolver again. It does not cancel on exit; AppRoot already has.

**2.4 Modal press gate (TR-hud-002) [S3].** `set_presses_blocked(blocked)`. While closed, presses drop; endings of pointers in `_down` still flow, so a drag begun before the modal ends once. The wrapper closes it in the handler that shows a modal and opens it when the modal hides. It holds whatever S3 (a) finds.

**2.5 Lifecycle (TR-input-004, TR-state-010) [S5].**
- `_notification(what)`: `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED` or `NOTIFICATION_WM_WINDOW_FOCUS_OUT` is "away". The first away notification of an episode calls `resolver.cancel()`, clears `_down`, then emits `lifecycle_paused()`. Later ones in the episode do nothing.
- `NOTIFICATION_APPLICATION_FOCUS_IN`, `_RESUMED` or `NOTIFICATION_WM_WINDOW_FOCUS_IN` ends the episode. None resumes the battle; only the Paused screen's tap does (Game State Rule 17).
- `NOTIFICATION_WM_GO_BACK_REQUEST` (Android back) always cancels and emits `lifecycle_paused()`, outside the episode latch, since no focus-in follows it. Confirmed by the user (Decision 5). Gesture navigation often takes edge swipes before the app sees them (S4, S5; `edge_reject_margin`).
- The set is a union because which notifications fire where is unverified; `Flow.pause()` is idempotent and a terminal phase ignores it.
- **Resize**: `get_viewport().size_changed` calls `resolver.cancel()` and clears `_down`, without a pause **[S6]**. On mobile it also reports to the dev-error sink, because insets are not re-read (Decision 3).
- Order on focus loss: adapter `cancel()`, then `lifecycle_paused()`; `Flow.pause()` enters Paused, calls `cancel_input()` (a no-op now) and emits `phase_changed(PAUSED)`; the wrapper shows Paused, closes the gate, calls `clear_press()`; the Clock zeroes its accumulator (ADR-0004).

**2.6 Wiring.** The wrapper connects `adapter.lifecycle_paused` to `battle.flow.pause`, and the Paused `TapScreen.tapped` to `battle.flow.resume`, both through `view_wiring.connect_recorded()` with method Callables. `view_wiring.disconnect_all()` undoes them before `queue_free()`, so nothing holds the old Flow after teardown.

### 3. Safe area and rejected zones (TR-input-006, TR-hud-014)
- `FieldInsets` (RefCounted, read-only by contract): `top`, `bottom`, `left`, `right`, field units.
- **Desktop**: all 0 by rule; `get_display_safe_area()` is not called there, since it may report the screen's work area.
- **Mobile**: `BattleWrapper` calls `SafeAreaMath.field_insets(get_display_safe_area(), window_rect, Vector2(540, 960))` once at battle build **[S7]**. The pure function finds the window-pixel insets of the safe rect against the window rect (clamped at 0), subtracts the letterbox offset on each side (`ox = (window_w - 540 s) / 2`, `oy = (window_h - 960 s) / 2`), clamps at 0 and divides by `s`. An inset inside a bar costs the field nothing.
- The one `FieldInsets` goes to the adapter and HudLogic. HeroInput reads `burst_button_centre()` once at registration, so insets never change mid-battle.
- **Rejected press zones**: `x < max(edge_reject_margin, left)`, `x > 540 - max(edge_reject_margin, right)`, `y < top`, `y > 960 - bottom`. A drag that moves into a zone stays valid (Input Rule 12).
- **Gesture insets**: no Godot API for them is in the pinned reference; `edge_reject_margin` stands in at MVP, and the Mobile Platform GDD owns the rest (sync item A3).

### 4. Modal screens (TR-hud-002, TR-hud-003)
- Result and Paused use `TapScreen extends Control`: full rect, `MOUSE_FILTER_STOP`, `focus_mode = FOCUS_NONE`. Not `Button`, because its press clearing on focus loss is unverified.
- `TapScreen._gui_input()` reads the **mouse family only**: left `InputEventMouseButton`, real or emulated (`emulate_mouse_from_touch = true`). It keys a real mouse press by `MOUSE_POINTER` and an emulated one by its `device`. It does **not** drop `DEVICE_ID_EMULATION`: on a phone the emulated event is the only one it reads. It fires `tapped` only on the release of a press it saw, ignores a release where `is_canceled()`, and clears every held press after firing. `clear_press()` forgets all held presses. It calls `accept_event()` on every pointer event.
- So a phone tap (touch plus its emulated mouse) fires once. The godot-specialist notes only the first finger is emulated and the emulated event comes first, so mouse-only is enough for a one-finger modal; S2 and S3 (c) confirm.
- Retry and Play again are `TapScreen` regions with the same rule.
- The wrapper calls `clear_press()` on show and on `lifecycle_paused` (HUD Rule 2). Paused resumes on `tapped`; its press was taken by the screen and gated at the adapter, so it reaches nothing beneath (TR-state-010).
- **Every non-interactive Control** in the wrapper has `mouse_filter = MOUSE_FILTER_IGNORE`, set on each node and checked by a lint. The 4.5 recursive property (`mouse_behavior_recursive`, named by S9) may replace that. The wrapper root is a `Node2D`, never a full-rect Control.

### 5. Product choices (confirmed by the user 2026-11-04)
1. Letterbox at MVP, reviewed before Vertical Slice.
2. A notification-shade pull pauses.
3. On desktop the click that refocuses the window resumes. If it feels wrong, TapScreen ignores the first press after a desktop focus-in.
4. Insets are not re-read; a mid-battle resize on mobile logs a dev error.
5. Android back pauses (`quit_on_go_back=false`, back request as a pause) instead of quitting mid-battle.

### Architecture Diagram

```
OS / DisplayServer
  │ touch; emulated mouse from first touch (DEVICE_ID_EMULATION)     [S2]
  ▼
Viewport (canvas_items + keep, 540x960), positions in field units      [S6]
  ├─ _input ────────► InputAdapter: move / release / is_canceled
  │                   (pointers in _down only) ─► resolver.move / release / cancel_pointer
  ├─ GUI ───────────► TapScreen (STOP, mouse family) consumes presses   [S3]
  │                   other Controls IGNORE
  └─ _unhandled_input ► InputAdapter: press (gate open, in field, not rejected) ─► resolver.press

_notification away (first of episode) | GO_BACK_REQUEST                 [S5]
  InputAdapter ─► resolver.cancel(); _down.clear() ─► lifecycle_paused()
     ─(view_wiring)► Flow.pause() ─► phase_changed(PAUSED)
        ─► wrapper: show Paused, gate closed, clear_press(); Clock zeroes acc
size_changed ─► resolver.cancel(); _down.clear()  (mobile: dev error)

BattleWrapper build (mobile): SafeAreaMath.field_insets ─► FieldInsets ─► adapter, HudLogic
cancel() callers (ADR-0001): adapter · Flow.cancel_input() · AppRoot teardown
```

### Key Interfaces

```gdscript
class_name InputAdapter extends Node      # process_mode = PROCESS_MODE_ALWAYS
const MOUSE_POINTER := 1 << 16
## Once per away episode, and on each back request, after resolver.cancel().
signal lifecycle_paused()
## Built by BattleWrapper only.
func setup(resolver: InputResolver, edge_reject_margin: float, insets: FieldInsets, dev_error: Callable, is_mobile: bool) -> void
## Closed while a modal TapScreen shows. Drops presses only.
func set_presses_blocked(blocked: bool) -> void

class_name FieldInsets extends RefCounted   # read-only by contract
var top: float
var bottom: float
var left: float
var right: float

class_name SafeAreaMath extends RefCounted
static func field_insets(safe_px: Rect2i, window_px: Rect2i, field: Vector2) -> FieldInsets
## dp per field unit under keep; the guard needs >= 2.0 / 3.0.
static func dp_per_unit(window_px: Vector2i, field: Vector2, dpi: float) -> float
static func is_rejected(pos: Vector2, field: Vector2, edge_reject_margin: float, insets: FieldInsets) -> bool

class_name TapScreen extends Control      # MOUSE_FILTER_STOP, FOCUS_NONE, mouse family only
## Fires on the release of a press this screen saw; then clears every held press.
signal tapped()
func clear_press() -> void
```

Names are proposed here; `MOUSE_POINTER`, `setup()`, `set_presses_blocked()`, `FieldInsets`, `SafeAreaMath` and `TapScreen` are new against B3. `lifecycle_paused` keeps B3's name and is past tense. QQ-16 may add a prefix (ADR-0007).

### Implementation Guidelines
1. `project.godot` must hold every Decision 1 key with that effective value; test A11 checks it through `ProjectSettings`, not file text.
2. The `InputAdapter` must be the only node that reads pointer events for gameplay. HUD modals use `TapScreen._gui_input` only.
3. The adapter must forward presses only from `_unhandled_input`, and moves, releases and cancels only from `_input`, only for pointers in `_down`.
4. Code must never test `event.device == 0`. The adapter must drop `DEVICE_ID_EMULATION`; `TapScreen` must not.
5. Mouse must use `MOUSE_POINTER`; only the left button counts.
6. A release where `event.is_canceled()` must become `cancel_pointer(i)` in the adapter and must be ignored by `TapScreen`.
7. The adapter must never synthesise a release, and never call the resolver once `_live` is false.
8. The battle must never contain a Camera2D; the field root keeps the identity transform.
9. Every non-interactive Control in the wrapper must have `mouse_filter = MOUSE_FILTER_IGNORE`, set on each node and linted. The wrapper root must not be a full-rect Control.
10. `TapScreen` must fire only on the release of a press it saw, then clear every held press; the wrapper must call `clear_press()` on show and on `lifecycle_paused`. Every Control here has `focus_mode = FOCUS_NONE`.
11. The wrapper must close the press gate in the handler that shows a modal and open it when the modal hides.
12. Insets must be read once per battle, on mobile only, through `SafeAreaMath.field_insets`. No HUD or view calls `get_display_safe_area()`.
13. `lifecycle_paused` and `TapScreen.tapped` must reach Flow through `view_wiring.connect_recorded()` with method Callables.
14. Nothing may set `SceneTree.paused`.
15. A story that depends on a **[Sn]** item may not close until that check passes or its fallback is in place. Stories with no **[Sn]** item do not wait on S0.

## Alternatives Considered

### Alternative 1: `canvas_items` + `expand` (the 4.7 new-project default)
- **Description**: the viewport grows on the long side (540 x 1200 on a 9:20 phone).
- **Pros**: no bars; the whole screen is used.
- **Cons**: field units no longer equal viewport units unless the field sits at the origin, and centring it breaks the identity transform; the HUD band and burst line float away from the screen edges they assume.
- **Rejection Reason**: breaks TR-input-016 and the HUD layout at MVP; the Mobile Platform GDD may revisit it under a superseding ADR.

### Alternative 2: `keep_width`
- **Description**: width fixed at 540; taller screens show more height.
- **Cons / Rejection Reason**: the same offset and identity-transform problem as Alternative 1.

### Alternative 3: Every event in `_input`, with the adapter's own Control check
- **Pros**: one callback; no reliance on GUI order.
- **Cons / Rejection Reason**: the adapter must hit-test HUD Controls and contradicts TR-input-013. The chosen split plus a one-flag gate knows nothing about Controls.

### Alternative 4: Adapter as a full-rect PASS Control using `_gui_input`
- **Cons / Rejection Reason**: GUI drag capture sends endings to the Control that took the press, and GUI touch routing is unverified. More unverified behaviour than the chosen split.

### Alternative 5: Touch family only (`emulate_touch_from_mouse = true`)
- **Cons / Rejection Reason**: on a touch laptop a real touch 0 and the mouse's emulated touch 0 collide, the case TR-input-005 forbids.

### Alternative 6: One lifecycle notification per platform
- **Cons / Rejection Reason**: a missed case leaves the battle running in the background; the union is safe because pause is idempotent and resume is by tap.

### Alternative 7: Live safe area, re-read on resize
- **Cons / Rejection Reason**: `burst_button_centre()` is read once by HeroInput, so a live change desyncs the hit disc from Hero's cancel distances. Portrait is locked; the Mobile Platform GDD may add it with re-registration.

### Alternative 8: TapScreen reads touch and drops emulated mouse (godot-specialist's B1 fix)
- **Cons / Rejection Reason**: if S3 (c) shows Controls get no touch events, every modal would die on phones. Mouse-only works whichever way S3 falls.

## Consequences

### Positive
- The resolver never sees an engine event, so B2 stays headless.
- Exactly-once holds by construction: presses enter in one place, endings in another, `_down` decides.
- Modals block the field twice over (engine order and gate); a phone tap fires a modal once.
- Field units equal viewport units; no conversion code exists outside `SafeAreaMath`.
- Letterbox bars usually swallow the notch, so most phones run with zero in-field insets.
- ADR-0001's callers, teardown order and `view_wiring` rule are unchanged.

### Negative
- Bars waste about 20% of a 9:20 screen (Decision 5).
- A shade pull pauses; a desktop refocus click resumes (Decision 5).
- `TapScreen` is a custom Control: keyboard users cannot resume with a key, and it loses `Button`'s AccessKit role. It should get an accessible name if 4.5's AccessKit allows one on a plain Control (unverified).
- S0b needs hardware the project has not set up.
- Three GDDs, `tr-registry.yaml` text and architecture.md need edits (Migration Plan).

### Neutral
- `Input.use_accumulated_input` stays true: motion events merge, and the resolver handles a release beyond slop, so no outcome changes.

## Risks
- **S1 fails**: the shown bonus could differ from the paid bonus (TR-hud-005). ADR-0004 queues commands.
- **S2 fails**: fallback F2; a touch laptop's mouse is then ignored in development.
- **S3 (a) fails**: the gate covers it; record so later HUD work does not rely on Control occlusion for touch.
- **A system gesture steals a touch with no cancel and no notification**: the pointer strands until its next press; a miss, never a mis-fire.
- **`edge_reject_margin` is too narrow for back-swipe**: it is data (0 to 48); S5 and the Pillar 4 test tune it.
- **Safe-area units or timing are off**: S7; `SafeAreaMath` is pure, so a fix is one line plus tests.
- **`screen_get_dpi()` is wrong**: the guard only logs.
- **Setting names differ in 4.7.2**: S0a parse check and settings dump; A11 catches drift.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-002: one adapter node maps touch and mouse to the five calls in field units | Decision 1 and 2; Guideline 2 [S6]. **Full** |
| input-gesture-resolver.md | TR-input-003: exactly one release or cancel per press, even under a STOP Control; `canceled` honoured | 2.1, 2.3 [S3, S4]. **Full** |
| input-gesture-resolver.md | TR-input-004: `PROCESS_MODE_ALWAYS`; cancel on pause, focus loss, resize; one lifecycle signal | 2, 2.5 [S5, S6]. **Full** |
| input-gesture-resolver.md | TR-input-005: one event family; no duplicates; no index collision; non-left dropped | 1, 2.2 [S2, F2]. **Full** |
| input-gesture-resolver.md | TR-input-006: reject presses in `edge_reject_margin` and safe-area insets in field units | 3 [S7]. **Partial**: gesture insets go to the Mobile Platform GDD (sync item A3) |
| input-gesture-resolver.md | TR-input-013: targets are discs; HUD Controls consume their events before the adapter | 2.1, 2.4, 4. **Partial**: the disc part goes to ADR-0008 (sync item A2) |
| input-gesture-resolver.md | TR-input-016: minimum 360 dp guard; field units equal viewport units; no Camera2D; cancel on resize | 1, 2.5. **Full**, guard widened to height (sync item G1) |
| game-state-stage-flow.md | TR-state-010: focus loss enters Paused; ticks stop, input cancels, accumulator zeroed; resume tap reaches nothing | 2.5, 4. **Partial**: tick gate and accumulator go to ADR-0004 (sync item A1) |
| battle-hud.md | TR-hud-002: Result and Paused are modal Controls that consume every event before the adapter | 2.1, 2.4, 4. **Full** (endings of an earlier drag still reach the adapter; sync item G3) |
| battle-hud.md | TR-hud-003: a Control fires only on a release whose press it saw, and clears it on lifecycle signals | 4. **Full** for modals; Start/Call arming is HudLogic's (ADR-0004) |
| battle-hud.md | TR-hud-014: layout in field units with insets converted; `burst_y` formula | 1, 3. **Full**; the formula stays the HUD's |

## Performance Implications
- **CPU**: a few comparisons and one dictionary lookup per pointer event; nothing per tick.
- **Memory**: one node, one `FieldInsets`, a small dictionary.
- **Load Time / Network**: none.
- **Rendering**: a fixed 540x960 canvas, scaled; ADR-0011 budgets against it.

## Migration Plan
No code exists. This ADR edits no GDD, `project.godot`, `tr-registry.yaml` or architecture.md; the first input story applies Decision 1. On acceptance:

**GDD sync items (game designer owns them):**
- **G1** `input-gesture-resolver.md`: `field_scale` becomes `min(width_dp / 540, height_dp / 960)`; `target_ok`'s integer form gains a height term (`2 × r × height_dp ≥ 46080`, 48 × 960); AC 33 adds a height case; the Output Range top value and the "width below 360 dp" edge case follow; the tablet scale-cap question closes for MVP.
- **G2** `input-gesture-resolver.md` Rule 12: gesture insets have no engine source at MVP. The adapter Open Questions row is answered pending S0. Rule 7's `cancel()` callers (already ADR-0001's item).
- **G3** `battle-hud.md` Rule 2: presses are consumed before the adapter; endings of a pointer already forwarded still reach it. Name `TapScreen` and the gate. Rule 17 and Edge Cases: the desktop refocus click resumes.
- **G4** `battle-hud.md` Layout: insets are read once per battle, 0 on desktop and often 0 under letterbox; the stretch items and Open Question are answered.
- **G5** `game-state-stage-flow.md` Rule 17: the notification set and `lifecycle_paused`; Android back pauses. The manual desktop row ("unfocus, refocus, tap") notes that the refocus click is the tap.
- **G6** `tr-registry.yaml` text (via `/architecture-review`): TR-input-016 "minimum 360 dp" becomes "minimum 360 x 640 dp effective scale"; TR-hud-002 "consume every event" becomes "consume every press".

**architecture.md sync items:**
- **A1** Required ADRs: TR-state-010 joins ADR-0004's Covers.
- **A2** Required ADRs: TR-input-013 joins ADR-0008's Covers.
- **A3** Open Questions: a new QQ for Android gesture insets, owned by the Mobile Platform GDD.
- **A4** B3: add the new interfaces; point the NEEDS VERIFICATION paragraph at the spike results.
- **A5** Data Flow 1: presses after GUI, endings before GUI; event order points to S1. Data Flow 6: the order in 2.5, the gate, `clear_press()`, back request, `view_wiring`.
- **A6** Module Ownership: adapter row gains the gate and `FieldInsets`; Result and Paused become `TapScreen`; Mobile Platform inherits `SafeAreaMath`.
- **A7** Gap Summary: the UI and display row reads "set explicitly by ADR-0003"; move verified items out of HIGH after S0.
- **A8** QQ-02 resolved; QQ-06 resolved pending S0; QQ-12 narrowed by letterbox.

## Validation Criteria

**S0a and S0b** as in Decision 0.

Headless gdUnit4 tests (ADR-0007 places them; names proposed). Constructed `InputEvent`s go through a test-only entry (`_route(event, phase)`) to a recording fake resolver:
- **A1** press, moves, release arrive once and in order; a second release is dropped.
- **A2** a release with `is_canceled()` gives `cancel_pointer(i)`, never `release`.
- **A3** `DEVICE_ID_EMULATION` events, non-left buttons, wheel and hover reach nothing; a left mouse press arrives as `MOUSE_POINTER`.
- **A4** gate closed: a press drops, an earlier press's release arrives.
- **A5** presses in each zone and outside the field drop; a drag moving into a zone still forwards.
- **A6** two away notifications give one cancel and one `lifecycle_paused`; after focus-in the next one fires again; two back requests give two; a stale release after cancel drops.
- **A7** resize cancels without a pause, and reports a dev error on mobile.
- **A8** silent once `_live` is false.
- **A9** `SafeAreaMath`: 540x960 (zero); 1080x2400 with a 96 px cutout inside the bar (zero); 1080x1920 with an 80 px cutout (positive `top`); 1536x2048 (side bars); `dp_per_unit` is exactly 2/3 at 360x800 dp and fails at 400x600 dp.
- **A10** `TapScreen`: a release with no seen press does nothing; `clear_press()` between press and release does nothing; a canceled release does nothing; a seen press and release fires once.
- **A10b** a real touch press and release plus its emulated mouse press and release give exactly one `tapped`.
- **A11** `ProjectSettings` reports every Decision 1 key with its value (part of ADR-0007's lint). Effective values, since the editor drops the 7 default-valued keys on save.

Manual evidence (`production/qa/evidence/`, blocking for UI stories): desktop at 540x960 and resized; Paused on alt-tab and resume by click; Lost and Won block the field; on the phone, letterbox, insets, back swipe, 50 taps on Paused give 50 `tapped`.

## Reviews

2026-11-03. TD-ADR: CONCERNS. godot-specialist: CONCERNS. All findings applied.

| # | Finding | Resolution |
|---|---|---|
| B1 | TapScreen fires twice per phone tap | Mouse family only, keyed per source, ignores canceled, clears after firing; A10b; device check. TD fix chosen over G's (Alt 8) |
| B2 | Partial TRs had no owner | Sync items A1 to A3 |
| B3 | Android back quits mid-battle | `quit_on_go_back=false`; back request pauses; user confirmed; S5 back swipe |
| B4 | Window mode, edge-to-edge, cutouts | Pinned in Decision 1; S7 runs with them, logs cutouts and immersive |
| B5 | Editor drops default values | Settings dump and A11 check effective values; comment removed; `stretch/scale=1.0` |
| TD3 | ALWAYS skips the DISABLED guard | 2.3 Teardown safety; Guideline 12 quoted in Constraints |
| TD4 | Lifecycle connections outside `view_wiring` | 2.6 and Guideline 13; frame-wait risk dropped |
| TD5, G9 | Window focus may reach only the Window | S5 per node class; fallback window signals; facts marked unverified |
| TD6 | Resize signal under keep | S6 checks it, poll fallback |
| TD7 | Editor-embedded run differs | S0a runs embedded and windowed |
| TD8 | Sync item 1 too narrow | G1 and G6 |
| TD9 | Alt 1 cost overstated | Restated |
| TD10 | Game State manual row | G5 |
| TD11 | Immersive setting | Recorded in S7 |
| TD S0, G13 | Spike scope | S0a and S0b; parse check; self-scoring; time limit; Guideline 15 per check |
| TD product | Choices need the user | Decision 5 |
| G6 | `canceled` field | `is_canceled()` on both classes |
| G7 | Safe area timing | S7 logs frame 1 and 3 s |
| G14 | S1 physics half | Kept (ADR-0004 may tick in `_physics_process`, QQ-01), with a sequence number and forced steps |
| G15 | Bar colour | Dropped |
| G16 | TapScreen accessibility | Negative consequences |
| G17 | Recursive mouse filter | Per-node rule and lint; recursive optional after S9 |
| G18 | Screenshot cannot show a cutout | Debug outlines, photo, cutouts |
| G19 | More cancel cases | S4: call, alarm, palm; "not observed" allowed |

## Related
- ADR-0001 (Accepted): depends on it; consistent with its callers, teardown, `view_wiring` and bans.
- Enables ADR-0004, ADR-0008, ADR-0011 (not written).
- `architecture.md` v3: Gap Summary, Data Flow 1 and 6, B2, B3, QQ-02, QQ-06, QQ-12, QQ-20; `tr-registry.yaml` (the 11 TRs above).
- GDDs: `input-gesture-resolver.md` (Rules 1, 7, 10, 12; Formulas; adapter contract), `battle-hud.md` (Rules 2, 17, 18; Layout; `burst_y`), `game-state-stage-flow.md` (Rule 17).
- Mobile Platform & Performance GDD (VS, not written): inherits Decisions 1 and 3.

## Amendments
- **2026-11-04, with ADR-0007 (confirmed by the user 2026-11-04 at ADR-0007 acceptance).** InputAdapter.setup() gains `is_mobile: bool`, passed by the wrapper, so the adapter reads no OS and A7's mobile branch and F2 run on Linux CI.
- **2026-11-04, from verified engine probes** (docs/engine-reference/godot/probe-results.md; Status stays Accepted). Android edge-to-edge is the export preset option `screen/edge_to_edge` in `export_presets.cfg`, not a `ProjectSettings` key: Decision 1 moves it to an export preset note, S0b checks it, and S7 and S9 follow. Decision 1, S0a, S9 and A11 record that 7 of the 13 Decision 1 keys equal engine defaults and are dropped on save, so checks read effective values. S9 names `mouse_behavior_recursive`. S0a's parse check and settings dump are marked verified 4.7.2 headless.
