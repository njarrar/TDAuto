# ADR-0011: Battle Field Rendering and Draw-Call Budget

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. No other agent and no skill may do it alone. Stories that cite this ADR stay blocked while it is `Proposed`.

TD-ADR: not run per ADR; batch review after all ADRs are written.

Engine validation (godot-specialist): written by the Godot specialist against the 4.7.2 class reference and `docs/engine-reference/godot/`; no separate validation pass.

## Date

2026-11-04

## Last Verified

2026-11-04 (against `docs/engine-reference/godot/` and the Godot class reference at tag `4.7.2-stable`)

## Decision Makers

Godot specialist (author). Pending: technical-director batch review, technical-artist on the hit-flash shader question, user acceptance.

## Summary

The battle field and HUD are drawn from primitives on a low-end phone inside a project budget of 60 draw calls, with the HUD at about 8 and at most 12, at most 3 text draws, and none of it measured. This ADR fixes one `_draw` node per view kind (path, tower, enemy, hero, combat, HUD field) plus a few `Control`s, fixed record pools (at least 48 enemy slots, 16 flash markers), the draw order, the path as a baked polygon, a redraw-on-change policy driven by the frame order, positive line widths after the 4.7 line change, no shaders at MVP, and how each budget is measured on a device.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2.stable, installed and pinned) |
| **Domain** | Rendering |
| **Layer** | Presentation |
| **Knowledge Risk** | MEDIUM (architecture.md: 4.7 `CanvasItem` lines lose their antialiasing feather; the Mobile renderer reference is desktop-leaning; the draw-call budget is unmeasured) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/rendering.md`, `modules/ui.md`, `breaking-changes.md` (4.6 to 4.7 Rendering rows), `deprecated-apis.md`, `current-best-practices.md`; Godot 4.7.2 class reference: `CanvasItem.xml` (`queue_redraw`, `draw_line`, `draw_polyline`, `draw_multiline`, `draw_arc`, `draw_circle`, `draw_colored_polygon`, `draw_string`), `Performance.xml` (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `TIME_PROCESS`, `MEMORY_STATIC`), `ProjectSettings.xml` (`rendering/renderer/rendering_method`, `rendering/anti_aliasing/quality/msaa_2d`, `rendering/2d/batching/item_buffer_size`), `RenderingServer.xml` (`get_current_rendering_method`), `Control.xml` |
| **Post-Cutoff APIs Used** | None new. Behaviour change relied on: 4.7 `CanvasItem` line drawing adds no antialiasing feather (`breaking-changes.md`) |
| **Verification Required** | Every budget, on the low-end target phone; line widths and path corners by screenshot. See NOT SOURCEABLE |

### NOT SOURCEABLE (blocks Acceptance)

Each item is settled by the **first phone build run** on the low-end target phone, release and debug builds, with results and screenshots kept in `production/qa/evidence/`, unless another run is named.

- **V-1. Actual draw calls of this node structure on the Mobile renderer**, and whether one `_draw` with mixed primitives is one draw call or several. 2D batching rules are not in the class reference; `ProjectSettings.xml` gives only `item_buffer_size`. Run: read `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` in Build, in the Wave worst case, and with each modal shown.
- **V-2. Draw cost of `Label` and `draw_string` text per font size.** Run: the same session, with text toggled off and on.
- **V-3. Frame time and memory** (16.6 ms at 60 fps, 30 fps floor, 256 MB). Run: a release build with the OS GPU profiler and memory tools.
- **V-4. Whether 2 and 3 unit lines read after the 4.7 no-feather change.** Run: device screenshots at 360 dp and 430 dp widths.
- **V-5. That the Mobile renderer runs on the target phone without fallback.** Run: the boot log line from Decision 7.
- **V-6. Square 90 degree path corners at width 72.** The class reference does not say how `draw_polyline` joins thick segments. Decision 4 avoids it with a baked polygon. Run: a frame-stepped screenshot of the starter path, desktop and device.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 Enemy Entity, Roster and Combat API (`roster()`, `Enemy.def_id`, `position`, `distance`, Combat view signals); ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry (`slot_state()`, HeroInput and HeroSim reads). Text also relies on: ADR-0001 (BattleWrapper builds views, absent headless, rebuilt on retry), ADR-0003 (stretch mode, field units, safe area, `reduce_motion` read), ADR-0004 (frame order and frame budget split), ADR-0006 (view allowlist, signal payloads), ADR-0008 (hit-target discs) |
| **Enables** | Visual Feedback & VFX (Vertical Slice) takes over the Combat view under these budgets |
| **Blocks** | Battle HUD stories; path, tower, enemy, hero and combat view stories |
| **Ordering Note** | Can be deferred to the first phone build, when draw calls are first measured (architecture.md, Priority). View stories may start on desktop under the rules here; Acceptance waits on V-1 to V-6 |

## Context

### Problem Statement

All field art is code-drawn primitives with 2 and 3 unit strokes, and 4.7 draws `CanvasItem` lines "without an antialiasing feather, so lines look thinner" (`breaking-changes.md`). `project.yaml` sets 60 draw calls, 16.6 ms and 256 MB with a 30 fps floor on low-end Android. Battle HUD UI Requirements set "expected 8, at most 12 of 60 draw calls, and text at most 3, one per size. Modals add about 4, inside the 12". Combat wants a 16-marker flash pool and no shaders; Enemy & Wave wants a view pool of at least 48 and a fixed draw order; the art bible §8 budgets a hit-flash shader (QQ-10). The node layout, pools and measures must be fixed before view code exists.

### Current State

No rendering code. `project.godot` sets `rendering/renderer/rendering_method="mobile"`.

### Constraints

- Views read only; the sim never references Presentation and gives identical results without it (architecture.md, Dependency rule 3).
- Views and the HUD live under the BattleWrapper, which is absent headless (ADR-0001).
- One coordinate space, field units 540x960, no `Camera2D` (ADR-0003).
- No shaders, particles, audio, 3D or physics at MVP (Combat, Enemy & Wave and Tower Visual Requirements).
- Frame slice for views and HUD: 3.0 ms of 16.6 ms (architecture.md, Data Flow 10, a proposal).
- Engine facts from the class reference or a device run only.

### Requirements

- TR-combat-011: Combat view draws from one `_draw` per kind, no shaders or particles, 16-marker flash pool on the frame clock.
- TR-enemy-015: views read `roster()` and the path each frame; fixed three-pass draw order; view pool of at least 48 that grows with a dev error; Reduce Motion honoured.
- TR-tower-015: all towers from one `_draw` with primitive polygons, level inset and cooldown ring, Reduce Motion fallbacks.
- TR-hud-001: HudLogic, HudTopBand, HudField, HudModals; built before HeroInput, absent headless, rebuilt on retry.
- TR-hud-015: HUD about 8 (max 12) of 60 draw calls, at most 3 text draws; hit targets at least 72 units; text at least 21 units.

## Decision

### 1. Node structure: one `_draw` per view kind

```
 BattleWrapper (Node2D, ADR-0001)
 ├─ PathView    (Node2D, _draw)  baked path polygon, free-slot squares, exit chevrons and danger
 ├─ TowerView   (Node2D, _draw)  every tower: polygon, level inset, ready/cooling ring, range rings
 ├─ EnemyView   (Node2D, _draw)  every enemy from the slot pool, three passes
 ├─ HeroView    (Node2D, _draw)  hero, leash, reticle, reach ring, kill preview, Ready ticks
 ├─ CombatView  (Node2D, _draw)  attack lines, splash rings, slow drag lines, flash markers, death discs
 ├─ HudField    (Node2D, _draw)  arc, chip, Start/Call, burst button art and digit, rings, prompt
 └─ HudLayer    (CanvasLayer)
     ├─ HudTopBand (Control, mouse_filter IGNORE)  gold, lives, pips, next-wave line
     └─ HudModals  (Control)                        Result and Paused, built once, hidden unless shown
 HudLogic: RefCounted, held by the BattleWrapper, no node
```

- Draw order is sibling order: path, towers, enemies, hero, combat, HUD field, then the CanvasLayer. Combat lines and flashes sit over every body; the hero sits over enemies so the player always finds it.
- Enemies, towers, rings, tracers and flashes are **records drawn inside one `_draw`**, never nodes. The CanvasItem count is fixed at six plus the HUD Controls, whatever the game state.
- HudLogic, HudTopBand, HudField and HudModals are built by the BattleWrapper before HeroInput (HeroInput reads `burst_button_centre()`), are absent headless, and are rebuilt with the wrapper on retry (ADR-0001). HudField registers no hit targets; HudLogic registers every HUD disc (TR-hud-001).

### 2. Pools and per-view clocks

All pools are built at view build. A frame in steady state allocates nothing.

| Pool | Size | Owner | Overflow |
|---|---|---|---|
| Enemy slots (`EnemyViewSlot`: `spawn_id`, `def_id`, cosmetic bob phase, leak-pop timer) | 48, one named constant shared with the `peak_alive_ub` content test | EnemyView | Add one slot, log one development error (Enemy & Wave edge case) |
| Flash markers (`spawn_id`, alpha, time left, hero or tower rank) | 16 (`FLASH_MARKER_LIMIT`) | CombatView | Evict per Combat Edge Cases: oldest tower flash, then oldest hero flash; a tower flash never evicts a hero flash; a flash suppressed by burst clearance takes no marker |
| Death discs (`position`, time left) | 48 | CombatView | Drop the oldest; damage is unaffected |
| Tracers and splash rings (origin, impact, radius, kind, time left) | 32, proposed | CombatView | Drop the oldest; tune on device |

- EnemyView binds slots by `spawn_id` each frame from `roster()`: a `Dictionary[int, int]` maps `spawn_id` to slot index, and an `Array[int]` holds free indices. A slot whose `spawn_id` left the roster returns to the free list. Enemies are drawn at `Enemy.position`, never from `distance`.
- Flash and death state live in the view, keyed by `spawn_id`, never in `Health` (Combat, View clocks). `damage_applied` and `attack_fired` carry copied positions, so a reaped target still flashes (ADR-0009).
- Every view timer runs on the frame clock in milliseconds fed by the BattleWrapper, stops on Pause and is dropped on retry with the view.

### 3. Draw order inside a view

- **EnemyView, three passes** (Enemy & Wave, Stacked enemies): heavy, then normal, then fast; inside a pass, ascending `spawn_id`. Each pass is one loop over the roster that skips other types, so no sort runs. The 1 px keyline is drawn with each disc.
- **CombatView**: tracers and splash rings, then slow drag lines, then flash discs, then death discs.
- **TowerView**: range rings first (under entities, Tower Visual table), then bodies by slot index, then insets and state rings.

### 4. The path is a baked polygon

At build, PathView turns `StageRecord.path_points` into one `PackedVector2Array` per layer (width 72 at +6% V, width 68 at +3% V). Each segment becomes a rectangle extended by half the width at both ends, so a 90 degree joint gets a square outer corner by construction. Each rectangle is drawn with `draw_colored_polygon`, which "draws a colored polygon of any number of points, convex or concave" (`CanvasItem.xml`). Path colours must be opaque, so overlaps at joints do not show. Only straight and 90 degree joints are promised; any other angle needs a screenshot review before a stage ships it. This avoids `draw_polyline`, whose joint shape at width 72 is not documented (V-6).

The path polygons and slot squares are built once and redrawn only when the danger state changes. Views read the path from the same `path_points` that `PathTable` uses (ADR-0009).

### 5. Redraw policy

- `queue_redraw()` "queues the CanvasItem to redraw. During idle time, if CanvasItem is visible, NOTIFICATION_DRAW is sent and `_draw` is called. This only occurs once per frame, even if this method has been called multiple times" (`CanvasItem.xml`). Repeat calls in one frame cost nothing extra.
- Views have no `_process`. In step 4 of the frame path (architecture.md, Data Flow 1, owned by ADR-0004), the BattleWrapper calls `refresh(ms)` on each view in sibling order, after the frame's ticks.
- `refresh(ms)` advances view timers and calls `queue_redraw()` only when its change key changed:

| View | Redraws when |
|---|---|
| PathView | Danger starts, ends or pulses (frozen under Reduce Motion) |
| TowerView | `tower_built`, `tower_upgraded`, `gold_changed`, a cooling ring, a range-ring or overlay timer |
| EnemyView | One or more ticks ran this frame and the roster is not empty, or a leak-pop timer runs |
| HeroView | Hero state, aim state or finger position changed, or a hero timer runs |
| CombatView | A Combat view signal this frame, or any tracer, flash or disc still alive |
| HudField | A HudLogic presentation timer runs, or HudLogic state or its quantised key changed |
| HudTopBand | Labels are set only when their text changes |

- Signal handlers on the view allowlist (ADR-0006) only set flags or fill pool records; `refresh` does the drawing work, so a burst of signals in one tick costs one redraw.

### 6. Lines, widths and the 4.7 change

- Every `draw_line`, `draw_polyline`, `draw_multiline`, `draw_arc` and stroked `draw_circle` passes a **positive** width in field units. `CanvasItem.xml`: with a negative width "a two-point primitive will be drawn instead of a four-point one. This means that when the CanvasItem is scaled, the line will remain thin."
- `antialiased` stays `false`, the documented default, and `rendering/anti_aliasing/quality/msaa_2d` stays at its default. Widths stay at the GDDs' 2 and 3 units.
- If V-4 shows lines too thin: first raise widths by 1 unit. Second, `msaa_2d` at 2x, which "is only supported in the Forward+ and Mobile rendering methods" and "can be significantly slower on some hardware" (`ProjectSettings.xml`); its cost is then measured against the budget.

### 7. Renderer

Keep `rendering_method="mobile"`. `ProjectSettings.xml` describes Mobile as "Modern renderer designed for mobile devices. Has a lower base overhead than Forward+, but does not scale as well to large scenes", Forward+ as "Not suitable for older devices or mobile", and Compatibility as the low-end renderer for "OpenGL 3.3 / OpenGL ES 3.0". The engine "may automatically change" the method as a fallback, so a debug build logs `RenderingServer.get_current_rendering_method()` at boot (V-5). Compatibility is the recorded fallback; it loses `msaa_2d`, the second line fallback.

### 8. Hit flash: no shader (QQ-10)

Flashes are white `draw_circle` discs at alpha 1.0 (hero, burst) or 0.6 (tower) for `FLASH_SECONDS`, inside CombatView's `_draw`. No shader, `CanvasGroup`, `Light2D`, particle node or second viewport at MVP. Reasons: the Combat and Enemy & Wave GDDs both say no shaders; a shader on a per-enemy material would need per-enemy nodes, which Decision 1 bars; and a shader's draw-call and batching effect on Mobile is not documented. The art bible §8 shader line stays unused budget. The technical-artist owns the art bible edit; adding any shader later must revise this ADR's budget first.

### 9. Draw-call and text budget

| Budget | Value | Source |
|---|---|---|
| Whole frame, battle | at most 60 | `project.yaml` |
| HUD (top band, HUD field, modals) | expected 8, at most 12, modals included | Battle HUD UI Requirements (TR-hud-015) |
| Field views (path, tower, enemy, hero, combat) | at most 48, the remainder; target set by V-1 | 60 minus 12 |
| Text draws | at most 3, one per font size, one font | Battle HUD |
| Views and HUD CPU | 3.0 ms per frame | architecture.md, Data Flow 10 |

- Measure: `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)`, "the total number of draw calls performed in the last rendered frame. This metric doesn't include culled objects (either via hiding nodes ...)" (`Performance.xml`). So a hidden HudModals costs no draw calls, and the modal cost is read with it shown.
- Frame time: `Performance.TIME_PROCESS`, "time it took to complete one frame", plus the OS GPU profiler. Memory: OS tools in release; `MEMORY_STATIC` is "not available in release builds" (`Performance.xml`).
- A debug-only `PerfProbe` node, built by the BattleWrapper in development builds, samples these once per second in the worst-case scene (48 enemies, every slot built, burst aiming, arc open) and writes them to the dev log (ADR-0010). Device budgets are not CI gates; they block this ADR's Acceptance.
- First levers if over: HUD, move `draw_string` text into top-band Labels or cut a size; field, merge CombatView into EnemyView.

### 10. HUD size floors (TR-hud-015)

- Every HUD hit target is at least 72 units across. HudLogic registers each disc with the resolver (ADR-0008); a headless test reads every registered disc and fails if one is under 36 units in radius.
- Every HUD text is at least 21 units high. Font sizes are named constants in one place; a headless test fails on any size under 21.

### 11. Reduce Motion

Views read `reduce_motion` once at build from the input record (QQ-09, closed) through the wrapper. Under it: enemy bob and jitter stop and the leak pop becomes a static double outline for 200 ms; danger freezes at alpha 1.0 with its outline; the tower refuse nudge is skipped; tower build and upgrade overlays draw without the scale step. Shape cues, the `fast` notch, ready and cooling rings and Combat's drag lines stay.

### Key Interfaces

```gdscript
## Base of every field view. Built by the BattleWrapper; reads only sim queries and allowlisted signals.
class_name BattleView extends Node2D
func bind(battle: Battle, reduce_motion: bool) -> void
func refresh(ms: float) -> void      # once per frame after ticks; queue_redraw() only on change
func _draw() -> void                 # positive widths only; never writes sim state

const ENEMY_VIEW_POOL := 48          # shared with the peak_alive_ub content test
const FLASH_MARKER_LIMIT := 16

class_name PerfProbe extends Node    # development builds only
func sample() -> Dictionary          # draw_calls, frame_s, static_mem (debug only)
```

### Implementation Guidelines

- Each view kind must be one CanvasItem with one `_draw`; enemies, towers, rings, tracers and flashes must never be nodes.
- Views must never write sim state, call `deliver` or issue a command.
- Views must not override `_process` or `_physics_process`; drawing is driven by `refresh`.
- `queue_redraw()` must be called only from `refresh` or a HudLogic state change.
- Every line or stroke call must pass a positive width in field units.
- Pools must be built at view build; a steady-state frame must not allocate.
- Text must use one font and at most three sizes, none under 21 units.
- No shader, `CanvasGroup`, `Light2D`, particle node or extra viewport may be added without revising this ADR.
- The path must be drawn as baked polygons, not `draw_polyline`.
- `PerfProbe` must be absent from release builds; a debug build must log the current rendering method at boot.

## Alternatives Considered

### Alternative 1: A node per drawable (a `Node2D` or `Sprite2D` per enemy, tower, ring)

- **Description**: Scene-style views with a node pool of 48 enemies.
- **Pros**: Familiar; per-node transforms; editor preview.
- **Cons**: CanvasItem count grows with the game; whether Mobile batches them is not documented, so the budget would rest on unsourced batching.
- **Rejection Reason**: The draw count must not depend on unsourced batching. The GDDs ask for one `_draw` per kind.

### Alternative 2: Redraw every view every frame

- **Description**: Each view calls `queue_redraw()` in `_process`.
- **Pros**: Simplest; no change keys.
- **Cons**: Wasted CPU and GPU in Build and Intermission; battery cost on phones.
- **Rejection Reason**: The change keys are cheap, and HudLogic already tracks the state.

### Alternative 3: Hit-flash shader (art bible §8)

- **Description**: A flash uniform on each enemy's material.
- **Pros**: Matches the art bible line; a flash could tint the body itself.
- **Cons**: Needs per-enemy CanvasItems; shader cost and batching on Mobile are not documented; the GDDs say no shaders.
- **Rejection Reason**: Decision 8.

### Alternative 4: Path with `draw_polyline`

- **Description**: One thick polyline per path layer.
- **Pros**: Two calls; fewer points.
- **Cons**: Joint shape at width 72 is not documented (V-6).
- **Rejection Reason**: The baked rectangles give square corners by construction.

### Alternative 5: Compatibility renderer

- **Description**: `gl_compatibility` for the widest device support.
- **Pros**: Runs on OpenGL ES 3.0 devices.
- **Cons**: No `msaa_2d`, losing the second line fallback; a second device matrix.
- **Rejection Reason**: Not needed until a target device fails Mobile; kept as the fallback.

## Consequences

### Positive

- Draw calls are bounded by the number of view kinds, not by enemies or towers.
- Idle phases cost almost nothing.
- Every budget has a named measure and a named first lever.
- Views are leaves: any one can split or merge without touching the sim.

### Negative

- One large `_draw` redraws the whole kind on any change. Accepted: in Wave every enemy moves anyway.
- No editor preview; all field art is code.
- Tracer pool size 32 is a guess until the device run.

### Neutral

- The 49th enemy slot exists but is unreachable while the `peak_alive_ub` content test passes.

## Risks

- **Draw calls over budget (V-1).** Mitigation: merge views; move text to Labels.
- **Lines too thin after the 4.7 change (V-4).** Mitigation: Decision 6 fallbacks.
- **Low-end phone misses 16.6 ms (V-3).** Mitigation: `PerfProbe`; targeting is ADR-0009's lever; the clamp is ADR-0004's.
- **Engine falls back from Mobile (V-5).** Mitigation: boot log; Compatibility fallback.
- **Art bible and GDDs disagree on the flash shader (QQ-10).** Mitigation: this ADR decides no shader; the technical-artist edits the art bible.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-011: one `_draw` per kind, no shaders or particles, 16-marker flash pool on the frame clock | CombatView (Decision 1), flash pool and frame clock (Decision 2), no shader (Decision 8) |
| enemy-wave.md | TR-enemy-015: views read `roster()` and the path each frame; three-pass order; pool of at least 48 that grows with a dev error; Reduce Motion | EnemyView binding and pool (Decision 2), passes (Decision 3), path from `path_points` (Decision 4), Decision 11 |
| tower-system.md | TR-tower-015: one `_draw` for all towers, primitive polygons, level inset, cooldown ring, Reduce Motion fallbacks | TowerView (Decisions 1, 3), Decision 11 |
| battle-hud.md | TR-hud-001: HudLogic, HudTopBand, HudField, HudModals; built before HeroInput; absent headless; rebuilt on retry | Node structure and build order (Decision 1) |
| battle-hud.md | TR-hud-015: about 8 (max 12) of 60 draw calls, at most 3 text draws; hit targets at least 72 units; text at least 21 units | Decisions 9 and 10 |

GDD sync: checked 4 referenced GDDs. No renames. The view names (PathView, TowerView, EnemyView, HeroView, CombatView) are new; the GDDs say "the Combat view" and "one `_draw()` node", which match.

## Performance Implications

- **CPU**: One `_draw` per changed view per frame; in Wave, EnemyView and usually CombatView redraw every frame. Target 3.0 ms for views and HUD, unmeasured.
- **Memory**: Six CanvasItems, a CanvasLayer, a few Controls, one font at up to three sizes, and fixed pools of a few hundred small records.
- **Load Time**: One font load; path polygons baked once per battle.
- **Network**: None.

## Migration Plan

No code exists. Build EnemyView and PathView first with the worst-case scene and `PerfProbe`, run on the phone, then add the other views.

**Rollback plan**: Views are leaves. Any view can split, merge or change its draw method without touching the sim or HudLogic.

## Validation Criteria

- Headless: each view's `refresh` with fake reads calls `queue_redraw()` only when its change key changes (spy subclass).
- Headless: the flash pool evicts in the Combat Edge Cases order; a 49th enemy adds one slot and logs one dev error; every HUD disc radius is at least 36; every font size is at least 21.
- Headless: a battle with every view removed gives identical state (TR-hud-004, ADR-0006).
- Device and screenshots, blocking Acceptance: V-1 to V-6, kept in `production/qa/evidence/`.

## Related

- `docs/architecture/architecture.md` v3: Module Ownership (Presentation), Data Flow 1 and 10, Engine Knowledge Gap Summary (Rendering row), QQ-09, QQ-10, QQ-11
- `design/gdd/combat-damage.md` (Visual/Audio Requirements, Edge Cases); `design/gdd/enemy-wave.md` (Visual/Audio Requirements, Edge Cases); `design/gdd/tower-system.md` (Visual/Audio Requirements); `design/gdd/battle-hud.md` (UI Requirements)
- ADR-0009, ADR-0010 (depends on); ADR-0001, ADR-0003, ADR-0004, ADR-0006, ADR-0008 (relied on)
