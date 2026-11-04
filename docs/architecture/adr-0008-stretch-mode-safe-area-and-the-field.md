# ADR-0008: Stretch Mode, Safe Area and the Field

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

The game is laid out on a fixed 540 x 960 field, but phones are taller than 9:16, `project.godot` sets no stretch key, and Enemy & Wave requires everything outside the field to be masked on every screen shape. This ADR writes `canvas_items` stretch with `keep` aspect into `project.godot`, so the engine letterboxes the field and no mask code exists, and defines one `FieldFrame` object that turns the platform safe area into field-unit insets for the HUD and the input adapter.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2.stable, installed and pinned) |
| **Domain** | UI (project settings, display) |
| **Layer** | Core |
| **Knowledge Risk** | HIGH (4.7 changed the stretch defaults for new projects; safe-area behaviour is not in the pinned reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/ui.md`, `modules/input.md`, `breaking-changes.md` (4.6 to 4.7 Project row); official 4.7.2 class reference: `ProjectSettings.xml`, `DisplayServer.xml`, `Viewport.xml`, `InputEventScreenTouch.xml`, `CanvasItem.xml` |
| **Post-Cutoff APIs Used** | None. The stretch keys predate the cutoff; only their new-project defaults changed in 4.7 |
| **Verification Required** | The NOT SOURCEABLE items under Validation Criteria, each on a 9:19.5 phone (Android and iOS) and a 4:3 screen |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary (`FieldFrame` is shell; the sim never reads it). ADR-0002 App Lifecycle and Composition (ShellBuilder builds `FieldFrame`; AppRoot owns the root scene) |
| **Enables** | ADR-0006 (coordinate space and insets for the adapter), ADR-0012 (layout and draw space), Enemy & Wave content rules L1 to L14 against the field |
| **Blocks** | The first phone build; HUD layout stories; any story that converts a screen position |
| **Ordering Note** | Accept together with ADR-0006. The `project.godot` change below is one commit that also carries ADR-0006's `input_devices` key |

## Context

### Problem Statement

Every GDD position, radius and threshold is in field units on 540 x 960 (Input "Positions and units", HUD "Layout", Enemy & Wave layout rules). The architecture (Engine Knowledge Gap Summary, Project settings row) notes that 4.7 changed new-project defaults to `canvas_items` and `expand`, and that `project.godot` sets no stretch key. `ProjectSettings.xml` gives the setting defaults as `display/window/stretch/mode = "disabled"` and `display/window/stretch/aspect = "keep"`, and says `canvas_items` and `expand` are "the default for projects created starting in Godot 4.7". Which value an unset key takes in this project is therefore unclear from the reference itself; writing both keys removes the question. QQ-04 asks for the stretch mode and the masking method.

### Current State

`project.godot` holds only `config/name`, `config/features` and `renderer/rendering_method="mobile"`. No `[display]` section exists, so the base size is the setting default of 1152 x 648 (`ProjectSettings.xml`, `display/window/size/viewport_width` and `viewport_height`), a landscape size.

### Constraints

- Enemy & Wave Rule "Nothing outside the field is ever shown" and its Masking criterion: screenshots at 9:19.5 and 4:3, no pixel of path or enemy outside 540 x 960, exit at y 960 to 980 included.
- Input `target_ok`: 72 units must be at least 48 dp, so dp per field unit must not fall below 0.667 (360 dp width).
- Enemy & Wave and HUD content rules assume insets of at most 102 units at the top and 72 at the bottom.
- The sim is device-independent: `burst_y` clamps to 816 to 888 so no inset changes the simulation (HUD Formulas).
- Do not fill engine facts from memory.

### Requirements

- One coordinate space for drawing and input: field units.
- Nothing outside the field visible on any shape.
- Insets available to the HUD and adapter in field units, 0 on desktop.
- Portrait orientation on phones.

## Decision

### 1. `project.godot` keys

The ADR-0008 implementation story writes exactly these keys (no other keys change; `[rendering]` is untouched):

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

Sources, all `ProjectSettings.xml` unless noted:

- `display/window/size/viewport_width` and `viewport_height`: "the game's main viewport width ... Stretch mode settings also use this as a reference when using the `canvas_items` or `viewport` stretch modes"; on desktop also the initial window size.
- `display/window/stretch/mode = "canvas_items"`: "the base size ... is stretched to cover the whole screen (taking aspect into account) ... everything is rendered directly at the target resolution."
- `display/window/stretch/aspect = "keep"`: "the viewport retains its original size regardless of the screen resolution, and black bars will be added to the top/bottom of the screen ('letterboxing') or the sides ('pillarboxing')."
- `display/window/handheld/orientation = 1`: the setting takes `DisplayServer.ScreenOrientation`; `SCREEN_PORTRAIT` is value `1`, "default portrait orientation" (`DisplayServer.xml`). The setting "does not flip the project resolution's width and height automatically", which is why width 540 and height 960 are written explicitly.
- `input_devices/pointing/emulate_touch_from_mouse = true` belongs to ADR-0006 and ships in the same change.
- `display/window/stretch/scale` (1.0) and `scale_mode` ("fractional") stay at their defaults. `integer` would clip on windows smaller than the base size (`scale_mode` note).

**QQ-04 answer: `canvas_items` with `keep`.** On a phone taller than 9:16 the field fits the width and the engine adds bars above and below. On a screen wider than 9:16 it fits the height and adds side bars. The area outside the field is a bar, not scene content, so masking needs no code.

### 2. One coordinate space

- The battle scene uses no `Camera2D` and leaves the root viewport's `canvas_transform` at identity. Every CanvasItem draws in field units, and `InputEventScreenTouch.position` is "in the viewport ... using the coordinate system of this viewport" (`InputEventScreenTouch.xml`), which under this stretch is the 540 x 960 base space.
- Nothing converts screen pixels except `FieldFrame` (below).

### 3. `FieldFrame`: safe area to field insets

```
W, H        = root window size in pixels
scale       = min(W / 540, H / 960)                  # keep: uniform, fits inside
ox, oy      = (W - 540 * scale) / 2, (H - 960 * scale) / 2   # bar sizes
S           = DisplayServer.get_display_safe_area()  # Rect2i
I_top       = clamp(max(0, S.position.y - oy) / scale, 0, 102)
I_bottom    = clamp(max(0, (oy + 960 * scale) - (S.position.y + S.size.y)) / scale, 0, 72)
I_left, I_right  likewise on x, clamped to 0 .. edge_reject_margin bound of 48
```

- `DisplayServer.get_display_safe_area()` returns `Rect2i`, "the unobscured area of the display where interactive controls should be rendered", implemented on Android and iOS; elsewhere it returns `screen_get_usable_rect(SCREEN_OF_MAIN_WINDOW)` (`DisplayServer.xml`). On desktop that fallback is the usable screen area, not the window, so `FieldFrame` **forces all insets to 0 on desktop** (`OS.has_feature("mobile")` is false), matching "insets are zero on desktop" (Input Rule 12, HUD Layout).
- With letterbox bars a notch or gesture area that fits inside a bar gives an inset of 0. Only the part that reaches into the field counts. This is the "letterbox bars" case Enemy & Wave describes; its content rules assume the worse "panels over a width-fit view" case, so they remain safe margins.
- A clamp that bites is logged as a development error with the raw value; the content rules then need a recheck for that device.
- `FieldFrame` recomputes on the root viewport's `size_changed` signal (`Viewport.xml`); ADR-0006 cancels the gesture on the same signal.
- Insets flow down from `FieldFrame` to HudLogic (injected by the ShellBuilder) and to the InputAdapter (`attach`). The sim never reads them; `burst_y`'s clamp keeps the simulation device-independent.

### 4. Field scale floor

Under `keep` on a portrait phone (taller than 9:16) the field fits the width, so dp per unit is `width_dp / 540`, Input's `field_scale`, and `target_ok` holds at 360 dp. A screen wider than 9:16 fits the height, dp per unit is `height_dp / 960`, which only falls below 0.667 when `height_dp < 640`; no supported portrait phone is that short. A debug-only guard logs when the computed dp per unit is below 0.667. How to get dp from the reference is not settled (NOT SOURCEABLE V-5), so the guard is advisory and never blocks play.

### Architecture Diagram

```
 physical screen (e.g. 1080 x 2340 px, 9:19.5)
 ┌──────────────────────┐
 │  bar (oy px)  notch  │  ← engine letterbox, no scene content
 ├──────────────────────┤
 │                      │
 │   root viewport      │  540 x 960 field units, scale = W/540
 │   (canvas_items,     │  FieldView, TowerView, HeroView, CombatView, HudField, HudTopBand
 │    keep, no Camera2D)│  InputEventScreenTouch.position already in field units
 │                      │
 ├──────────────────────┤
 │  bar (oy px) gesture │
 └──────────────────────┘
 DisplayServer.get_display_safe_area() ─▶ FieldFrame ─▶ I_top, I_bottom (field units)
                                               ├──▶ HudLogic layout (band, burst_y)
                                               └──▶ InputAdapter (press reject zones)
```

### Key Interfaces

```gdscript
class_name FieldFrame extends RefCounted
## Shell-only. Built by ShellBuilder, refreshed on Viewport.size_changed.
const FIELD := Rect2(0.0, 0.0, 540.0, 960.0)

## Recompute from window size and safe area. Pure given its inputs; tests call it directly.
static func compute(window_px: Vector2i, safe_px: Rect2i, is_mobile: bool) -> FieldFrame
func inset_top() -> float      # field units, 0..102
func inset_bottom() -> float   # field units, 0..72
func inset_left() -> float
func inset_right() -> float
func scale() -> float          # screen pixels per field unit
```

### Implementation Guidelines

- `project.godot` **must** carry the five `[display]` keys and the `[input_devices]` key above, written once by the implementation story. No code may change stretch settings at runtime.
- The battle scene **must not** contain a `Camera2D` and **must not** change the root viewport's `canvas_transform`.
- All layout and hit geometry **must** be in field units. Only `FieldFrame` **may** read window pixels or `DisplayServer`.
- `FieldFrame.compute` **must** be a pure static function so it is unit-tested with synthetic sizes.
- On desktop `FieldFrame` **must** return 0 insets.
- No masking node, scrim or clip **may** be added unless V-1 fails (see Risks).
- The sim **must never** read `FieldFrame`.

## Alternatives Considered

### Alternative 1: `canvas_items` with `expand` (the 4.7 new-project default) plus drawn masks

- **Description**: The viewport grows on the long axis (`expand`, `ProjectSettings.xml`), the field is centred, and opaque panels are drawn over the area outside it. Insets apply in full over the width-fit view.
- **Pros**: Edge-to-edge colour; panels can host HUD elements in the extra space later.
- **Cons**: Mask code and its draw cost (ADR-0012 budget); positions shift by an offset, so either a Camera2D or a canvas transform is needed and input and drawing no longer share the base space; insets reach the field in full, which is the GDD's worst case.
- **Estimated Effort**: Higher.
- **Rejection Reason**: It builds masking that `keep` gives for free, and it breaks the single coordinate space.

### Alternative 2: `canvas_items` with `keep_width`

- **Description**: On a taller screen the viewport grows downward ("Expand Vertically", `ProjectSettings.xml`); on a wider screen, side bars.
- **Pros**: More vertical room for HUD panels.
- **Cons**: The area below the field shows scene content, so the path exit at y 960 to 980 is visible unless masked. Same mask cost as Alternative 1, on one side.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Fails the Masking criterion without extra code.

### Alternative 3: `viewport` stretch with `keep`

- **Description**: The scene renders to a 540 x 960 viewport, then scales to the screen (`ProjectSettings.xml`).
- **Pros**: Same masking result; identical pixels on every device.
- **Cons**: Rendering at base resolution then scaling softens 2 px and 3 px strokes and 14 dp text on a 1080 px wide screen. The reference recommends it "for games that use a pixel art aesthetic"; this game draws primitives.
- **Estimated Effort**: Same.
- **Rejection Reason**: Worse line and text quality for no gain.

### Alternative 4: Leave the keys unset

- **Rejection Reason**: The architecture requires both keys written explicitly, and the reference does not settle what an unset key means for this project (see Problem Statement).

## Consequences

### Positive

- Masking holds by construction on every shape; zero mask code and zero mask draw calls.
- Drawing, hit tests and input share one space with no conversion.
- Insets in the field are usually 0 on tall phones, because notches and gesture bars fall in the bars.

### Negative

- Bars waste screen area on tall phones (about 10 percent of height at 9:19.5).
- Bar colour is the engine's ("black bars"); it cannot match the field background without more work.

### Neutral

- The desktop window opens at 540 x 960.

## Risks

- **Scene content drawn outside 0 to 960 shows in the bars** (V-1). Mitigation: the off-field path ends would then be visible. Fallback: FieldView's root CanvasItem draws the field rectangle and sets `clip_children`, which makes it clip its children "acting as a mask" (`CanvasItem.xml`, `clip_children`); all field views become its children. Costs about one draw call.
- **Safe-area rect is in screen, not window, pixels** (V-2). On full-screen mobile they coincide; if not, `FieldFrame` subtracts the window position.
- **A notch larger than the bar on a 9:16-ish phone** gives a non-zero inset: covered by the clamp and the content rules' 102 and 72 margins.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| enemy-wave.md | TR-wave-007: targetable only inside the field; everything outside the field masked on any screen shape | `keep` letterboxes; nothing outside 540 x 960 is scene content (V-1). Targetability stays a sim rule on field coordinates |
| enemy-wave.md | Masking criterion at 9:19.5 and 4:3 | Bars on both shapes; screenshot evidence is V-1 |
| enemy-wave.md | A height-scaled wider screen must keep dp per unit at or above 0.667, or recheck L1 and L6 | Section 4; portrait phones fit width; guard logs |
| input-gesture-resolver.md | TR-input-007: thresholds and radii in field units; targets at least 48 dp | One coordinate space; width-fit on phones gives `field_scale = width_dp / 540` |
| input-gesture-resolver.md | Stretch mode and whether event positions are in the 540 x 960 space | Section 2; V-3 |
| battle-hud.md | TR-hud-007: layout in field units with safe-area insets | `FieldFrame` gives `I_top`, `I_bottom` in field units, 0 on desktop |

GDD sync: `battle-hud.md` and `enemy-wave.md` describe insets "converted at 360 dp (1 dp is 1.5 units)". This ADR converts from pixels through `scale` and needs no dp value. The 360 dp figures remain correct as the worst-case bound for the content rules, so no GDD number changes.

## Performance Implications

- **CPU**: `FieldFrame.compute` runs on build and on resize only.
- **Memory**: None.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

One commit adds the `[display]` and `[input_devices]` keys. The editor's 2D view and the desktop window switch to portrait 540 x 960. No code exists to migrate.

**Rollback plan**: Remove the keys or switch `aspect` to `expand` and add the Alternative 1 mask; the field-unit layout does not change.

## Validation Criteria

Automated (`tests/unit/shell/`): `FieldFrame.compute` with 1080 x 2340 and safe area (0, 120, 1080, 2100) gives `scale` 2.0, bars of 210 px, `I_top` 0 and `I_bottom` 0; with safe-area top at 300 px it gives `I_top` 45; desktop gives all zeros; clamps hold at 102 and 72.

**NOT SOURCEABLE, blocking acceptance** (screenshots in `production/qa/evidence/`):

- V-1. NOT SOURCEABLE: that with `canvas_items` and `keep`, CanvasItems drawn outside the 540 x 960 base rect are not visible in the bars; needs the Enemy & Wave Masking screenshots at 9:19.5 and 4:3.
- V-2. NOT SOURCEABLE: the coordinate space of `get_display_safe_area()` (screen or window pixels) on Android and iOS; needs a device run on a notched phone.
- V-3. NOT SOURCEABLE: that `InputEventScreenTouch.position` reaches `_input` in base 540 x 960 coordinates under this stretch; needs a device run tapping the four field corners.
- V-4. NOT SOURCEABLE: that the unset stretch keys before this change resolve to `disabled` and `keep` (setting default) rather than the 4.7 new-project values; moot once the keys are written, recorded for the audit.
- V-5. NOT SOURCEABLE: a reliable dp source for the 0.667 guard (`DisplayServer.screen_get_scale` or `screen_get_dpi`); needs a device run comparing against the OS dp width.

## Related

- ADR-0001 Simulation and Shell Boundary, ADR-0002 App Lifecycle and Composition (depends on)
- ADR-0006 Input Adapter and Resolver Integration (accept together)
- ADR-0012 Field and HUD Rendering and Performance Budget (draws in this space)
- `design/gdd/enemy-wave.md` (Layout rules, Rule 4, Masking criterion), `design/gdd/battle-hud.md` (Layout, `burst_y`), `design/gdd/input-gesture-resolver.md` (Formulas `field_scale`, `target_ok`)
- `docs/architecture/architecture.md` (Engine Knowledge Gap Summary, Open Questions QQ-04)
