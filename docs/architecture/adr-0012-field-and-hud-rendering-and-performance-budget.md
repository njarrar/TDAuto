# ADR-0012: Field and HUD Rendering and Performance Budget

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

The field and HUD are drawn from primitives on a low-end phone with a budget of about 8 and at most 12 draw calls, 3 text draws, 16.6 ms per frame and 256 MB, none of it measured yet. This ADR fixes one `_draw` CanvasItem per view kind plus a few `Label` Controls, a redraw-on-change policy driven by the shell's frame order, positive line widths after the 4.7 line change, the Mobile renderer, and how each budget is measured on a device, with every budget left as a blocking device check.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2.stable, installed and pinned) |
| **Domain** | Rendering |
| **Layer** | Presentation |
| **Knowledge Risk** | HIGH (4.7 `CanvasItem` lines lose the antialiasing feather; renderer behaviour and batching on Mobile are not in the pinned reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/rendering.md`, `modules/ui.md`, `breaking-changes.md` (4.6 to 4.7 Rendering rows), `deprecated-apis.md`, `current-best-practices.md`; official 4.7.2 class reference: `CanvasItem.xml`, `ProjectSettings.xml`, `Performance.xml`, `RenderingServer.xml`, `Control.xml` |
| **Post-Cutoff APIs Used** | None new. Behaviour change relied on: 4.7 `CanvasItem` line drawing without a feather (`breaking-changes.md`) |
| **Verification Required** | Every budget, measured on the low-end target phone; line widths by screenshot. See Validation Criteria |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary (views read `BattleReadModel`, never write). ADR-0002 App Lifecycle and Composition (ShellBuilder builds views; frame order). ADR-0008 Stretch Mode, Safe Area and the Field (draw space, insets, no mask cost) |
| **Enables** | HUD stories; ADR-0009's view pool form (constrained here); ADR-0011's kill preview drawing |
| **Blocks** | Battle HUD & Build UI stories; FieldView, TowerView, HeroView and CombatView stories |
| **Ordering Note** | ADR-0003 owns the frame hook and `advance(ms)`; this ADR only places view refresh after the ticks in that frame |

## Context

### Problem Statement

Battle HUD (UI Requirements) sets "expected 8, at most 12 of 60 draw calls, and text at most 3, one per size. Modals add about 4. Unverified." The technical preferences set 16.6 ms and 256 MB on a low-end phone (TR-hud-013). All field art is `_draw` primitives with 2 px and 3 px strokes, and 4.7 draws `CanvasItem` lines "without an antialiasing feather, so lines look thinner" (`breaking-changes.md`). QQ-08 asks how budgets are verified; QQ-11 asks whether Mobile is the right renderer.

### Current State

No rendering code. `project.godot` sets `rendering/renderer/rendering_method="mobile"`.

### Constraints

- Views read only; nothing in gameplay depends on a view (architecture principle 5).
- One coordinate space, field units, no Camera2D (ADR-0008).
- Masking costs nothing (ADR-0008 bars) unless ADR-0008's fallback clip is needed.
- No audio, no 3D, no physics, no shaders at MVP.
- Engine facts from the class reference or a device run only.

### Requirements

- TR-hud-001: HudLogic plain; HudTopBand Controls; HudField one `_draw` plus Input discs.
- TR-hud-005: draw budget 8 expected, 12 at most; at most 3 text draws.
- TR-hud-013: 16.6 ms and 256 MB on the low-end phone.
- TR-hero-005: kill preview projects enemy positions to landing.

## Decision

### 1. Node structure: one `_draw` per kind

```
 BattleShell (Node2D, built by ShellBuilder)
 ├─ FieldView   (Node2D, _draw)  path, slots, all enemies (from the 48-entry pool records)
 ├─ TowerView   (Node2D, _draw)  tower polygons, level insets, state and range rings
 ├─ HeroView    (Node2D, _draw)  hero, leash, ghost, reticle, reach ring, kill preview, telegraph
 ├─ CombatView  (Node2D, _draw)  attack lines, hit flashes
 ├─ HudField    (Node2D, _draw)  arc, chip, Start/Call, burst button art, ground rings
 └─ HudLayer    (CanvasLayer)
     ├─ HudTopBand (Control, mouse_filter IGNORE) lives, pips, gold, next-wave line, prompt
     └─ Modals     (Control, STOP, FOCUS_NONE)    Result, Paused (hidden unless shown)
```

- Draw order is sibling order: field, towers, hero, combat, HUD field, then the CanvasLayer.
- Enemies are **not** nodes. FieldView draws every enemy in its one `_draw` from a fixed array of 48 presentation records (ADR-0009 owns the pool's contents and growth rule; this ADR requires the pool to be records, not nodes, so the enemy count adds no CanvasItems).
- Text: top-band and modal text uses `Label` Controls with one font at up to three sizes (14, 16 dp and the glyph size). `HudField` draws cost and Start/Call text with `draw_string` from the same font. The text budget (at most 3, one per size) is a measured target, V-2.

### 2. Redraw policy

- `queue_redraw()` "queues the CanvasItem to redraw. During idle time, if CanvasItem is visible, NOTIFICATION_DRAW is sent and `_draw` is called. This only occurs once per frame, even if this method has been called multiple times" (`CanvasItem.xml`). Views therefore may call it freely; repeated calls cost nothing extra.
- Views have no `_process`. The frame order (HUD Rule 10, architecture Data Flow §2) is: input and commands; `HudLogic.advance(ms)`; `FixedStepClock` ticks; `AimModel.update`; then the ShellBuilder's frame hook calls `refresh()` on each view in sibling order. ADR-0003 owns where that hook lives.
- `refresh()` compares a cheap change key and calls `queue_redraw()` only on change:

| View | Change key |
|---|---|
| FieldView | ticks advanced this frame and roster non-empty, or `phase` changed |
| TowerView | `tower_built`, `tower_upgraded`, `gold_changed` seen, or a ring timer running |
| HeroView | hero moved, `pin_state`, `burst_state`, `aim_state` or the finger position changed |
| CombatView | an `attack_fired` or `damage_applied` this frame, or a flash still fading |
| HudField | any HudLogic presentation timer running, `chip_state()` open, or a HudLogic state change |
| HudTopBand | Labels set only when their text changes (Controls redraw themselves) |

- In Build with nothing moving, no view redraws. In Wave, FieldView and usually CombatView redraw every frame.
- Signals on the view allowlist (architecture §3) only set flags; `refresh()` does the work, so a burst of signals in one tick costs one redraw.

### 3. Lines and the 4.7 change

- Every `draw_line`, `draw_polyline` and `draw_arc` passes a **positive** width in field units. `draw_line`'s doc: "If width is negative, then a two-point primitive will be drawn instead of a four-point one. This means that when the CanvasItem is scaled, the line will remain thin" (`CanvasItem.xml`). Under `canvas_items` stretch at scale 2 a positive width of 2 units is 4 screen pixels.
- `antialiased` stays `false` (the `draw_line` default, `CanvasItem.xml`) and `rendering/anti_aliasing/quality/msaa_2d` stays at its default `0`. Art widths stay at the GDD's 2 and 3. The device screenshot (V-4) decides. First fallback: raise widths by 1 unit. Second: `msaa_2d` 2x, which "is only supported in the Forward+ and Mobile rendering methods" and "can be significantly slower on some hardware" (`ProjectSettings.xml`, `msaa_2d`); its cost is then measured against the draw budget.

### 4. Kill preview

`AimModel.preview_kills()` (ADR-0011, sim side) computes the projected victims; HeroView only draws the result. The projection logic is plain and unit-tested headless; this ADR fixes only that the view draws it in HeroView's `_draw` and that it is redrawn while `aim_state` is active.

### 5. Renderer (QQ-11)

Keep `rendering/renderer/rendering_method="mobile"`. The reference describes Mobile as "Modern renderer designed for mobile devices. Has a lower base overhead than Forward+, but does not scale as well to large scenes", Forward+ as "Not suitable for older devices or mobile", and Compatibility as "Low-end renderer designed for older devices ... OpenGL 3.3 / OpenGL ES 3.0" (`ProjectSettings.xml`, `rendering/renderer/rendering_method`). `rendering_method.mobile` defaults to `"mobile"`. The engine "may automatically change" the method as a fallback, so a debug build logs `RenderingServer.get_current_rendering_method()` at boot (`ProjectSettings.xml` note; `RenderingServer.xml`), and the device report records it.

### 6. Budgets and how they are measured

| Budget | Value | Measure | Source of the measure |
|---|---|---|---|
| Draw calls, battle, no modal | expected 8, at most 12 | `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` | `Performance.xml`: "the total number of draw calls performed in the last rendered frame" |
| Draw calls, modal shown | at most 16 (12 + about 4) | same | same |
| Text draws | at most 3, one per size | count of distinct font sizes in use; draw-call delta with text hidden | Battle HUD UI Requirements |
| Frame | 16.6 ms on the low-end phone | `Performance.TIME_PROCESS` ("time it took to complete one frame"), plus the OS GPU profiler for GPU time | `Performance.xml` |
| Memory | 256 MB | Android and iOS OS memory tools in a release build; `Performance.MEMORY_STATIC` in debug only | `Performance.xml`: MEMORY_STATIC "not available in release builds" |
| Targeting | about 2 ms for 400 checks | ADR-0007 owns it | |

A debug-only `PerfProbe` node (shell, built by ShellBuilder in development builds) samples these monitors once per second during the bot-free worst-case scenario (48 enemies, full board, burst aiming, an arc open) and writes them to the development log (ADR-0014). Device budgets are not CI gates (ADR-0013); they are blocking checks for this ADR's acceptance.

**QQ-08 answer.** Keep the GDD numbers as targets, measure them with the monitors above on the low-end target phone in the worst-case scenario, and treat each as NOT SOURCEABLE until that run. If the draw count exceeds 12, the first lever is merging CombatView into FieldView (one fewer CanvasItem); the second is moving `draw_string` text into Labels in the top band.

### Key Interfaces

```gdscript
## Every field view. Built by ShellBuilder; reads only BattleReadModel and allowlisted signals.
class_name FieldViewBase extends Node2D
func bind(model: BattleReadModel) -> void
func refresh() -> void          # called once per frame after ticks; calls queue_redraw() on change
func _draw() -> void            # positive widths only; no state writes

class_name PerfProbe extends Node   # development builds only
func sample() -> Dictionary         # draw_calls, frame_s, static_mem (debug)
```

### Implementation Guidelines

- Each view kind **must** be one CanvasItem with one `_draw`. Enemies, rings and flashes **must never** be separate nodes.
- Views **must never** write sim state or call a command; they **must** read through `BattleReadModel`.
- Views **must not** override `_process` or `_physics_process`; redraw is driven by `refresh()`.
- `queue_redraw()` **must** be called only from `refresh()` or a HudLogic state change.
- Every line call **must** pass a positive width in field units.
- Text **must** use one font and at most three sizes.
- No shader, `CanvasGroup`, `Light2D` or second viewport **may** be added without updating this ADR's budget.
- `PerfProbe` **must** be absent from release builds.
- A debug build **must** log `RenderingServer.get_current_rendering_method()` at boot.

## Alternatives Considered

### Alternative 1: A node per drawable (Sprite2D or Node2D per enemy, tower, ring)

- **Description**: The usual scene approach, with a node pool of 48 enemy nodes.
- **Pros**: Familiar; per-node transforms; editor preview.
- **Cons**: CanvasItem count grows with enemies; whether the 2D batcher merges them on Mobile is not documented (`ProjectSettings.xml` gives only `rendering/2d/batching/item_buffer_size`, "maximum number of canvas item commands that can be batched into a single draw call"); the budget would rest on unsourced batching.
- **Estimated Effort**: Similar.
- **Rejection Reason**: The draw count must not depend on unsourced batching behaviour.

### Alternative 2: Redraw every view every frame

- **Description**: Each view calls `queue_redraw()` in `_process`.
- **Pros**: Simplest; no change keys.
- **Cons**: Wasted CPU and GPU in Build and Intermission, where nothing moves; battery cost on phones.
- **Estimated Effort**: Lower.
- **Rejection Reason**: The change keys are cheap and the HUD already tracks the needed state.

### Alternative 3: Compatibility renderer

- **Description**: `gl_compatibility` for the broadest device support.
- **Pros**: Runs on OpenGL ES 3.0 devices.
- **Cons**: `msaa_2d` "is only supported in the Forward+ and Mobile rendering methods, not Compatibility" (`ProjectSettings.xml`), removing the second line-width fallback. The architecture notes the fallback is untested.
- **Estimated Effort**: Same, plus a second device test matrix.
- **Rejection Reason**: Not needed until a target device fails to run Mobile; kept as the recorded fallback.

## Consequences

### Positive

- Draw-call count is bounded by the number of view kinds, not by game state.
- Idle phases cost almost nothing.
- Every budget has a named measure and a named first lever.

### Negative

- One large `_draw` per kind redraws the whole kind for any change (all enemies when one moves). Accepted: in Wave they all move anyway.
- No editor preview of field art; all art is code.

### Neutral

- Labels in the top band redraw themselves on text change.

## Risks

- **Lines too thin on device after the 4.7 change** (V-4). Mitigation: section 3 fallbacks.
- **Draw count above 12** (V-1). Mitigation: merge views; move text.
- **Low-end phone misses 16.6 ms** (V-3). Mitigation: profile with `PerfProbe`; targeting is ADR-0007's lever; rendering levers above.
- **Engine falls back from Mobile** on some device (V-5). Mitigation: boot log; Compatibility fallback.
- **ADR-0008 clip fallback** adds one draw call if V-1 of ADR-0008 fails; the at-most-12 budget absorbs it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| battle-hud.md | TR-hud-001: HudLogic plain, HudTopBand Controls, HudField one `_draw` plus discs | Section 1 node structure |
| battle-hud.md | TR-hud-005: 8 expected, at most 12 draw calls, at most 3 text draws; modals about 4 | Sections 1 and 6, measured by `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` |
| battle-hud.md | TR-hud-013: 16.6 ms and 256 MB on the low-end phone | Section 6 measures; blocking device run |
| battle-hud.md | Rule 10: frame order advance, ticks, refresh views | Section 2 `refresh()` after ticks |
| battle-hud.md | Visual table: 2 px and 3 px strokes | Section 3 positive widths and fallbacks |
| hero-system.md | TR-hero-005: kill preview projects enemy positions to landing | Section 4: computed in AimModel, drawn in HeroView |
| enemy-wave.md | TR-wave-008: at most 48 enemies; the view pool matches | Pool of records inside FieldView's one `_draw` (contents in ADR-0009) |

GDD sync: `battle-hud.md` says "2 px" and "3 px" strokes. This ADR reads them as field units (4 and 6 screen pixels at scale 2). If the art bible meant screen pixels, it must say so; no rename is involved.

## Performance Implications

- **CPU**: One `_draw` per changed view per frame; worst case in Wave, 48 enemies drawn as polygons in one call list.
- **Memory**: Five CanvasItems, a CanvasLayer and a few Controls; one font at three sizes. Well under the 256 MB target by design; the device run confirms.
- **Load Time**: One font load.
- **Network**: None.

## Migration Plan

No code exists. Build FieldView first with the worst-case scenario and `PerfProbe`, run it on the low-end phone, then add the other views.

**Rollback plan**: Views are leaves; any view can be split or merged without touching the sim or the HUD logic.

## Validation Criteria

Automated: each view's `refresh()` with a fake `BattleReadModel` calls `queue_redraw()` only on a change-key change (spy on a test subclass).

**NOT SOURCEABLE, blocking acceptance** (device run on the low-end target phone, results and screenshots in `production/qa/evidence/`):

- V-1. NOT SOURCEABLE: the actual draw-call count of this structure on the Mobile renderer, and whether one `_draw` with mixed primitives is one draw call or several (2D batching rules are not in the class reference); needs a device run reading `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` in Build, Wave worst case, and with each modal.
- V-2. NOT SOURCEABLE: the draw cost of `draw_string` and `Label` text per font size; needs a device run with text toggled.
- V-3. NOT SOURCEABLE: frame time at 16.6 ms and memory under 256 MB on the low-end phone; needs a release-build device run with OS tools.
- V-4. NOT SOURCEABLE: whether 2 and 3 unit lines read correctly after the 4.7 no-feather change; needs device screenshots at 360 dp and 430 dp widths.
- V-5. NOT SOURCEABLE: that the Mobile renderer runs on the low-end target phone without fallback; needs the boot log from a device run.

## Related

- ADR-0001 Simulation and Shell Boundary, ADR-0002 App Lifecycle and Composition, ADR-0008 Stretch Mode, Safe Area and the Field (depends on)
- ADR-0003 Fixed Tick, Time and Determinism (frame hook), ADR-0006 Input Adapter and Resolver Integration (modal Controls, top band filters)
- ADR-0007 Combat Data Model (targeting budget), ADR-0009 Enemy Roster, Position Cache and View Pooling (pool contents), ADR-0011 Hero System (kill preview logic), ADR-0013 Content Test and Bot Harness (budgets are not CI gates), ADR-0014 Debug Logs (`PerfProbe` output)
- `design/gdd/battle-hud.md` (Rules 1, 10; Visual table; UI Requirements), `design/gdd/enemy-wave.md`, `design/gdd/hero-system.md`
- `docs/architecture/architecture.md` (Module Ownership Presentation, Open Questions QQ-08, QQ-11)
