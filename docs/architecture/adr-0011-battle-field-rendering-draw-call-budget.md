# ADR-0011: Battle Field Rendering and Draw-Call Budget

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05, against `architecture.md` v7, `tr-registry.yaml` (123 entries), ADR-0001 to ADR-0009 (all Accepted) with their amendments, ADR-0010 (Proposed), and probes R1 to R13 run on 4.7.2 headless (below).

## Decision Makers
Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`). Reviews still owed: godot-specialist and TD-ADR (the author could not start subagents). Acceptance: the user.

## Summary
The battle field and HUD must draw up to 48 enemies, the towers, the hero, combat feedback and the HUD inside 60 draw calls and 3.0 ms a frame on an Adreno 5xx-class phone, with Reduce Motion, pause and retry handled the same way everywhere. This ADR fixes one `_draw` node per view family in a fixed tree order, a path baked once into polygons, fixed view pools, no shaders (QQ-10: the hit flash is a drawn disc), all HUD text in one final pass by size, one view clock and one Reduce Motion policy, and a draw-call and CPU budget with named measurements, a desktop trigger and a fallback.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Rendering (2D, Mobile renderer) and UI |
| **Layer** | Presentation |
| **Knowledge Risk** | MEDIUM: 4.7 removed the antialias feather on `CanvasItem` lines; the RD 2D batching rules and the 2D draw-call count are not in the pinned reference |
| **References Consulted** | `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `modules/rendering.md`, `modules/ui.md`, `probe-results.md` (ADR-0004 E2, E3, E7, E8; ADR-0003 S9) |
| **Post-Cutoff APIs Used** | `draw_circle(position, radius, color, filled, width, antialiased)` (4.4 signature, R3). Behaviour change relied on: no line feather (4.7), so no width here assumes a feather |
| **Verification Required** | R1 to R13: verified 4.7.2 headless (below). Needs a GPU: the draw-call count (M9a, desktop windowed, Mobile renderer) and frame time on the phone (M9b); text sharpness at device scale; 90 and 120 Hz pacing (ADR-0004 V13) |

| Probe | Result (verified 4.7.2 headless, Linux x86_64, 4 cores, editor binary, debug) |
|---|---|
| R1 | `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `TIME_PROCESS` exist. Headless they read 0 (no renderer) |
| R2 | `RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME` and `Performance.add_custom_monitor` exist |
| R3 | `CanvasItem` has `draw_polyline`, `draw_colored_polygon`, `draw_arc`, `draw_multiline`, `draw_dashed_line`, `draw_string`, `draw_texture_rect`, all with `antialiased = false` by default where they take it; `draw_circle(position, radius, color, filled = true, width = -1.0, antialiased = false)`. No dashed arc. `TextLine.draw(canvas: RID, pos, color, oversampling)` exists |
| R4 | `Geometry2D.offset_polyline(path, 36.0, JOIN_MITER, END_BUTT)` on a path with two 90 degree turns gives 1 polygon of 10 points with exact square corners (outer (336, 264), inner (264, 336) for a corner at (300, 300)), ends cut flush at the end points; `triangulate_polygon` gives 8 triangles. Width 68 (`delta` 34) gives the same shape 2 units in |
| R5 | `rendering/2d/batching/item_buffer_size` (16384) and `uniform_set_cache_size` (4096) exist, so the RD 2D batcher is present. `msaa_2d` 0, `snap_2d_vertices_to_pixel` false, `rendering_method.mobile` `mobile`. The repo's `project.godot` already sets `renderer/rendering_method="mobile"` |
| R6 | `_draw` runs headless: 5 calls in 5 frames with `queue_redraw()` from `_process`, and each frame's `_draw` runs after that frame's `_process` |
| R7 | `ThemeDB.fallback_font` is a `FontFile` headless and measures strings; `TextLine.add_string()` works. `GradientTexture2D.FILL_RADIAL` exists (R8); `Line2D` has `LINE_JOINT_SHARP` (R10). Headless runs `forward_plus` on a dummy display, so renderer facts need a windowed run (R11) |
| R13 | One `_draw` of 1 polygon, 96 discs, 16 flash discs, one 24-dash `draw_multiline`, one ring and one string (about 115 calls): 259 µs p50, 410 µs p95 over 400 frames. Command recording only (dummy renderer), so a floor on GDScript cost, not a GPU cost: about 2.2 µs a call |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0009 (all Accepted 2026-11-04); ADR-0010 (Proposed: the B10 read surface and `SlotState`) |
| **Enables** | Visual Feedback & VFX (Vertical Slice) inherits the Combat view; the Mobile Platform & Performance GDD inherits the budget |
| **Blocks** | Every field view story and the HudField and HudTopBand stories. No story exists yet |
| **Ordering Note** | Accept after ADR-0010, which fixes `SlotState`. At acceptance, ADR-0009 and ADR-0007 take the dated amendments in Migration items 1 and 2 |

## Context

### Problem Statement
Five TRs ask for single `_draw` nodes, a fixed enemy draw order, view pools, Reduce Motion fallbacks and a HUD draw budget. ADR-0004 left interpolation here, ADR-0009 left QQ-10, and QQ-11 left the draw-call budget and render share. The Enemy GDD doubts `draw_polyline` at width 72; art bible §8's batching claims predate 4.4 and no pinned doc backs them.

### Constraints
- ADR-0003: 540x960, `canvas_items` + `keep`, no Camera2D, so field units are canvas units. ADR-0004: frame order, views read in step 3, `max_fps` 60. ADR-0001: the wrapper holds every view; tweens only on own nodes; Reduce Motion only from `PresentationSettings`. ADR-0005: only HudLogic reads stats in step 3. ADR-0006: VIEW listeners through `view_wiring`, never command or keep payloads. ADR-0009: plain-value `damage_applied`; 64-bit `x`, `y`; one reused `roster()`; `Health` read only through `hp_left`, `is_dead`, `speed_factor`.
- Solo part-time developer: few node types, nothing a profiler has not asked for.

### Requirements
- TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015 (GDD Requirements Addressed).
- Data Flow 10: views and HUD 3.0 ms; 60 draw calls; HUD about 8, at most 12, text at most 3.
- AR-V-04 contrast floors, AR-V-08 flash limits, AR-V-10 Reduce Motion rows, AR-V-13 hero always readable.

## Decision

### 1. One `_draw` node per view family, tree order is draw order
The wrapper builds one `FieldViews` `Node2D` at the canvas origin. Its children draw in this fixed order, each from one `_draw`:

| # | Node | Draws | Redraws |
|---|---|---|---|
| 1 | `BackdropView` | Field fill, faint grid, path polygons, slot marks for free slots | At build and when a slot fills; the burst dip is its `modulate`, no redraw |
| 2 | `ExitStripView` | Three chevrons, danger alpha and double outline | Each frame while in danger or popping |
| 3 | `RangeRingView` (HUD-owned) | Range rings, solid current and dashed next | When HudLogic's ring list changes or fades |
| 4 | `TowerView` | Every tower: body, level-2 inset, Ready or Cooling ring, build and upgrade overlay | Each frame while any tower cools or an overlay runs |
| 5 | `HeroZoneView` | Leash, reach ring, ground ring, unpinned ring, kite ghost | When HeroInput or HeroSim state changes |
| 6 | `EnemyView` | Every enemy in three passes, then state cues (damaged core), then all slow drag lines in one `draw_multiline` | Each frame with a non-empty roster |
| 7 | `CombatView` | Splash rings, tracers, hit flashes, death discs, in that pass order | Each frame with a live entry |
| 8 | `HeroView` | Halo texture, kite, Ready ticks, burst ring, spokes, aim reticle and radius preview, kill-preview contours | Each frame in Wave and Intermission |
| 9 | `HudTopBand` (`Control`) | Band panel, lives dashes, pips; no text | On change |
| 10 | `HudField` | Arc, chip, Start/Call, burst button, prompt panel, ground-tap ring, refusal cues, then all HUD text (Decision 6) | Each frame a HUD element animates or changes |

- **No node per entity**, ever; views hold plain records (replaces art bible §8's per-enemy ideal). **"One `_draw` per kind"** (TR-combat-011) reads as one node per view family, one pass per kind inside; both readings ban a node per instance.
- **Range rings sit under entities** (Tower Visual table), so the HUD owns two field nodes: `RangeRingView` under, `HudField` over. HudField keeps one `_draw` for all it shows above the field (TR-hud-001). Sync item for the HUD GDD.
- **Batching hygiene**: no `z_index`, `CanvasLayer`, material, `Light2D` or `CanvasModulate` in nodes 1 to 10; untextured shapes first, then textures, then text; `modulate` is free. Modals sit after node 10.
- **Redraw only on change**: `queue_redraw()` in step 3 only when a model changed or animates, so a static `BackdropView` costs no CPU per frame (R6).
- **Line widths** are the GDD widths with `antialiased = false` (4.7 adds no feather anyway); a must-see line is at least 2 px; keylines are a disc 1 unit larger. The device review may add 1 px; MSAA 2D stays off unless M9b shows it is free.

### 2. The path is baked once into polygons
- At wrapper build, `BackdropView` runs `Geometry2D.offset_polyline(path_points, path_width / 2, JOIN_MITER, END_BUTT)` for the edge and `offset_polyline(path_points, path_width / 2 - 2, ...)` for the body (art bible §6: 72 at +6% V, 68 at +3%, 2 px edges). R4 shows exact square corners at 90 degrees, so no joint code is needed. Path points off the field put the ends off the field (Enemy L13).
- It checks each polygon with `Geometry2D.triangulate_polygon()`. An empty result reports one dev error and draws that path with `draw_polyline(path_points, colour, width)` instead, so a bad stage still shows a path. Content test L13 already bans a path that doubles back.
- Tilted grids mitre the same way. A corner with an interior angle under about 60 degrees passes the default mitre limit and bevels; Vertical Slice stage rules check it.
- `TowerView`'s Cooling ring is `cooldown_left / cooldown_full` from `SlotState`, so no view reads `attack_interval` (Migration item 3).

### 3. Positions: 64-bit sim floats to 32-bit draw calls
- A view builds `Vector2(t.x, t.y)` only at the draw call, from the `Targetable` it reads in step 3. It never stores a `Targetable` past step 3, keeps the `roster()` array, or writes back. Per-enemy view state is keyed by `spawn_id` (an `int`).
- The 32-bit cast loses under 0.0001 units inside 960 (E2). Views may use `Vector2` maths: L-VEC-1 covers sim folders only.
- Enemy bob, jitter and the hero's facing are view offsets added after the cast. Bob and jitter phases derive from `spawn_id` and the view clock, so they need no per-enemy record.

### 4. Draw order inside `EnemyView` (TR-enemy-015)
- One scan of `roster()` (already in `spawn_id` order) sorts each enemy's index into one of three reused buckets by pass: heavy (30 px), normal (22 px), fast (16 px). The pass comes from a `visual_key` to style table the view builds once at build from the catalogue's Enemy records (not a stat; ADR-0005 does not apply). Each bucket draws in `spawn_id` order. No sort runs, so ties are stable (Enemy story notes).
- Per enemy: keyline disc, body disc, the `fast` notch; then its state cue. Feature budget (Combat Visual): under 22 px, flash and slow only; slowed and damaged, slow shows and the core hides.
- The damaged core needs the HP fraction. Views read no stat, and `Health` is readable only through three queries, so this ADR adds one view-only query, `Combat.hp_ratio(enemy) -> float` (`hp / max_hp`, 1.0 when unattached). Migration item 1.
- Slow drag lines for every slowed enemy collect into one reused `PackedVector2Array` and draw with one `draw_multiline` after the passes (art bible §8).
- Corpses before the reap are in `roster()`; `EnemyView` skips them (`Combat.is_dead`), since the death disc belongs to `CombatView`.

### 5. Pools, and how they grow
All pools are made once at wrapper build, reset by the rebuild on retry, and never shared between views. A view holds no `static var`.

| Pool | Size | When full |
|---|---|---|
| Enemy draw buffers (buckets, drag lines) | 48 (art bible §8, Enemy `peak_alive_ub`) | Grow to the roster size, once, and report one dev error per battle through the wrapper's `DevErrorSink`. An enemy is never hidden (TR-enemy-015) |
| Hit-flash markers | 16 (`FLASH_MARKER_LIMIT`) | Combat Edge Cases eviction: oldest tower flash, then oldest hero flash; a tower flash never evicts a hero flash; a suppressed flash takes none |
| Death discs | 48 | Drop the oldest; cosmetic |
| Tracers and burst spokes | 64 | Drop the oldest |
| Splash rings | 16 | Drop the oldest |
| Burst glow sprites | 8 | Drop the oldest |

### 6. Text
- **No `Label` in the battle HUD.** `HudField` draws every HUD string, the gold digits included, in one final pass after all its primitives, grouped by size: 21 units (14 dp), 24 units (16 dp), 36 units (24 dp, the burst digit). Glyphs of one size share one atlas texture, so this pass is at most 3 text batches, whatever the engine does across nodes. `HudTopBand` places the gold digits; `HudField` draws them there.
- **Font caching**: the wrapper loads one font once at build (the chosen font, or `ThemeDB.fallback_font` until the art-director picks one, R7), with tabular numerals on. Each text slot (gold, each cost, each label, the prompt, the digit, the refusal line) holds one `TextLine`, re-shaped only when its string or size changes, and drawn with `TextLine.draw(get_canvas_item(), pos, colour)` (R3). No string is built per frame when its value has not changed.
- The modal TapScreens may use `Label`s (HUD GDD: modals add about 4 calls); the battle field is still drawn under them.
- Every text size is at least 21 units and every text colour meets 4.5:1 on its panel in every state (AR-V-04, AR-V-05); both come from one style table (Decision 9) that tests read.

### 7. No shaders (QQ-10)
- **The hit flash is a drawn disc, not a shader.** `CombatView` draws a white disc over the enemy for `FLASH_SECONDS` (0.08 s), alpha 1.0 for hero and burst hits and `TOWER_FLASH_ALPHA` (0.6) for tower hits; a retrigger restarts it and keeps the higher alpha. It draws at the enemy's current position while the enemy is in `roster()`, found by `spawn_id`, and at `hit_position` once it is reaped. `damage_applied` carries all of this (ADR-0009 Decision 6), so the handler records plain values and reads nothing else.
- **No `ShaderMaterial` or `CanvasItemMaterial` in nodes 1 to 10 at MVP.** The danger pulse is an alpha the `_draw` computes from the view clock; outlines are a second shape behind the first. Reasons: a `TIME`-driven shader keeps running in Pause and ignores Reduce Motion, a per-node material breaks batching, and a disc is the same pixels. Art bible §8's ceiling of 3 shaders stays open for Vertical Slice and is not used. Sync item for the art bible.
- Glow: the hero halo and burst glow are one 128x128 `GradientTexture2D` (`FILL_RADIAL`, R7) made in code at build and drawn with `draw_texture_rect` and `modulate` in `HeroView`. No `Environment.glow`, `Light2D` or `CanvasModulate`. Death particles stay deferred (Combat GDD), so no `CPUParticles2D` at MVP.

### 8. One view clock; Reduce Motion as one policy
- **`ViewClock`** (one per wrapper) advances in step 3 by the step's clamped `ms` (ADR-0004 step 1's `min(delta * 1000, 100)`), except while `Flow.phase()` is `PAUSED`. Every field and HUD-primitive timing (flash, tracer, overlay, chevron pop, danger hold, refusal cue, burst ring) reads it. It keeps running on Won and Lost so transients finish. Retry rebuilds it. HudLogic's own `advance(ms)` (step 1, arming) is unchanged.
- **No `Tween`, no `SceneTree` timer, no `Time` call** in nodes 1 to 10 (the dev probe in Decision 10 apart). ADR-0001 allows tweens on own nodes; this ADR does not use them, so pause and retry need no extra code.
- **`MotionPolicy`** (`RefCounted`, `src/presentation/motion_policy.gd`) is made once per wrapper from `PresentationSettings.reduce_motion`. It has one field per row of AR-V-10 (the one list, IP-26): slides, danger pulse, burst dip, wind-up and snap, nudges (with the static refusal cue), overlay scale, arc collapse, hero breathing, enemy motion traits, clocks. Views ask the policy, never the flag. Under Reduce Motion, enemy bob and jitter **stay on** (AR-V-10 row "enemy motion traits"; they are telegraphs). The Enemy GDD's line "Bob and jitter stop" conflicts; sync item for the user.

### 9. Style table
`ViewStyle` (`src/presentation/view_style.gd`, constants only) holds every colour, alpha, width, size, radius and duration the views draw, keyed by the GDD tables. It is presentation tuning, not gameplay, so it is not catalogue data. The contrast unit test (accessibility test plan) and the floor test (V5) read it.

### 10. Budget and how it is measured (QQ-11, draw-call and render parts)

**Draw calls, 60 a frame at the design point** (worst starter wave, 48 enemies alive, 6 towers, 16 flashes, burst firing):

| Part | Cap |
|---|---|
| Field views, nodes 1 to 8 | 36 |
| HUD, nodes 9 and 10 (expected 8, TR-hud-015) | 12, of which text at most 3 |
| Modals, when shown | 4 |
| Engine (clear, letterbox, blit) | 4 |
| Spare | 4 |

**CPU, views and HUD 3.0 ms p95 on the phone** (Data Flow 10): step 3's refresh plus every `_draw` body. The render submit itself sits in the engine's 7.0 ms.

**Measurement.**
- **P-V1 `bench_views`** (`tests/performance/`, `--perf`, headless): builds the views over a scripted battle at the design point and times step 3 plus each `_draw` with `Time.get_ticks_usec()`. R6 shows `_draw` runs headless; it times GDScript work only. **Desktop trigger**: 3.0 / 15 = **0.2 ms p95 in a release export**, the same factor as ADR-0009. R13 suggests a debug run passes it (about 2.2 µs a call, around 230 calls at the design point), so the debug number is logged and the release export decides.
- **M9a, desktop windowed** (Mobile renderer, any GPU): a debug-only `RenderBudgetProbe` logs `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` each frame through the design-point scene, once with all views, once with only nodes 9 and 10, once with only the modals. The count comes from the renderer's batching, so desktop and phone should agree, since both run the Mobile renderer on Vulkan. If the monitor reads 0 for a 2D-only frame, count from a RenderDoc capture instead, and record which.
- **M9b, phone** (first phone build, ADR-0007 M9): the same probe plus p95 of step 3 and `_draw` time and `Performance.TIME_PROCESS`, retained in `production/qa/evidence/`.
- **Fallback F1**, built by the first story whose P-V1 release run or M9b fails: enemy bodies draw from one `MultiMeshInstance2D` per shape, written as one `PackedFloat32Array` buffer per frame, and flashes the same, which removes about 100 calls. F2, at no cost: skip `queue_redraw()` for nodes whose model did not change (already a rule).

### 11. View interpolation: deferred
Views draw the last tick's state. No interpolation at MVP.
- `max_fps` 60 gives one tick per 60 Hz frame and two at the 30 fps floor, both even. ADR-0004 seeds the accumulator mid-tick, so frame jitter under half a tick never makes a 0-tick or 2-tick frame.
- Interpolation shows state a tick old, against "the flash appears on the first frame after the hit".
- **Trigger**: V13 or M9b sees judder on a 60, 90 or 120 Hz phone. **Seam**: every view reads an entity position through one helper per view, so adding it changes one place, plus a read-only `TickClock.fraction()` (an ADR-0004 amendment then).

### Architecture Diagram
```
BattleWrapper.step(delta): 1 real-time models  2 ticks  3 views:
  ViewClock.advance(ms, paused); each view refresh(): read B10, roster(), Combat queries
  -> own model -> queue_redraw() if changed
Engine, after _process: _draw of each queued node, in tree order 1..10, then modals
VIEW signals via view_wiring -> plain records only
```

### Key Interfaces
```gdscript
class_name ViewClock extends RefCounted        # src/presentation/view_clock.gd
func advance(ms: float, paused: bool) -> void  # wrapper step 3 only
func now_ms() -> float

class_name MotionPolicy extends RefCounted     # src/presentation/motion_policy.gd
func _init(reduce_motion: bool) -> void
var slides: bool; var danger_pulse: bool; var burst_dip: bool; var wind_up: bool
var nudge: bool; var overlay_scale: bool; var arc_collapse: bool; var breathing: bool
var enemy_traits: bool                         # true in both modes (AR-V-10)

# Each field view (src/presentation/field/*.gd) extends Node2D:
func setup(battle_reads: Object, clock: ViewClock, policy: MotionPolicy, dev_error: Callable) -> void
func refresh() -> void                         # wrapper step 3; reads, updates model, maybe queue_redraw()

class_name PathMesh extends RefCounted         # src/presentation/field/path_mesh.gd
static func bake(points: PackedVector2Array, width: float, dev_error: Callable) -> PathMesh
var edge: Array[PackedVector2Array]; var body: Array[PackedVector2Array]; var fallback: bool

# Proposed additions owned elsewhere (Migration items 1 and 3):
# Combat.hp_ratio(enemy: Targetable) -> float  # view-only; 1.0 when unattached
# SlotState.cooldown_full: int                  # ticks the tower set at its last attack, 0 when empty
```

### Implementation Guidelines
1. Views must never create a node per enemy, tower, flash, tracer or ring.
2. Field and HUD views must not set `z_index`, add a `CanvasLayer`, set a material, or use `Light2D`, `CanvasModulate`, `Environment.glow`, `GPUParticles2D` or `CPUParticles2D`.
3. Views must not use `Tween`, `create_tween()`, a `SceneTree` timer, `await`, or `Time` (the debug-only `RenderBudgetProbe` apart); every timing reads `ViewClock`.
4. Views must read Reduce Motion only through `MotionPolicy`, and the policy only from `PresentationSettings`.
5. Views must read sim state only in `refresh()` (step 3), through B10, `roster()`, `targets()` and Combat's four view queries; a VIEW handler must store plain values only and read no stat.
6. Views must never keep a `Targetable`, `roster()` or `SlotState` past `refresh()`, and never write a sim value.
7. Each `_draw` must draw untextured shapes first, textured ones next, text last, except a texture that must sit under a shape (the hero halo); HUD text must be drawn only by `HudField`'s final pass, grouped by size.
8. Text slots must cache a `TextLine` and re-shape only on change; no `Label` in the battle HUD.
9. Lines must pass `antialiased = false`; a line a player must see must be at least 2 px wide.
10. A node must call `queue_redraw()` only when its model changed or it animates.
11. Pools must be sized at build per Decision 5; only the enemy buffers grow, with one dev error per battle.
12. Every colour, alpha, width, size and duration must come from `ViewStyle`.

## Alternatives Considered

### Alternative 1: A node per entity (art bible §8 ideal)
- **Description**: one `Node2D` with its own `_draw` per enemy, tower and effect, pooled.
- **Pros**: each entity redraws alone, with its own transform.
- **Cons**: 48 to 120 nodes to pool and tear down; the art bible already folds enemies into one drawer past about 40; three TRs ask for one node.
- **Rejection Reason**: more parts, no measured gain, and against three TRs.

### Alternative 2: The path with `draw_polyline` or `Line2D`
- **Description**: `draw_polyline(path_points, colour, 72)` twice, or two `Line2D` with `LINE_JOINT_SHARP`.
- **Pros**: no geometry step.
- **Cons**: unmitred joints; 4.7 changed line drawing; a node type for one shape.
- **Rejection Reason**: R4 shows a baked polygon gives exact square corners for one call at build.

### Alternative 3: One shared hit-flash shader (QQ-10)
- **Description**: a `ShaderMaterial` on the enemy node that whitens hit bodies through a per-instance flag.
- **Pros**: the flash takes the body's exact shape.
- **Cons**: a material breaks batching; shader time ignores Pause and Reduce Motion; the GDDs say zero shaders.
- **Rejection Reason**: a white disc over a disc body is the same pixels at no shader cost.

### Alternative 4: `Label` nodes for HUD text
- **Description**: one `Label` per string in HudTopBand and over HudField.
- **Pros**: layout, theme and autowrap for free.
- **Cons**: text interleaves with primitives across nodes, so text batches can pass 3; more Controls to lint.
- **Rejection Reason**: TR-hud-015's text cap is easier to hold from one pass.

### Alternative 5: Interpolate now
- **Description**: draw at `prev + (cur - prev) * fraction` from the `TickClock`.
- **Pros**: smooth on any refresh rate.
- **Cons**: one tick of lag, a buffer per enemy, an ADR-0004 amendment, and no evidence of judder yet.
- **Rejection Reason**: deferred with a trigger (Decision 11).

## Consequences

### Positive
- Ten nodes, each with one `_draw`, so the draw order is the tree.
- Pause, retry and Reduce Motion each live in one place (`ViewClock`, rebuild, `MotionPolicy`).
- Zero shaders; the path costs one bake; the budget has parts, a bench, two device checks and a fallback.

### Negative
- A full `_draw` re-runs for `EnemyView` and `CombatView` every frame in Wave: CPU cost scales with call count (R13), the first risk.
- HudField draws the gold digits that HudTopBand lays out, which splits one element across two nodes.
- Two small API additions owned by other ADRs (`hp_ratio`, `cooldown_full`).
- The style table is constants in code, not data, so a colour change is a code change.

## Risks
- **The GDScript call cost on the phone passes 3.0 ms.** R13 suggests about 2.2 µs a call on desktop debug; a phone may be 10 or more times slower. Mitigation: P-V1 trigger in a release export, then F1 (MultiMesh), F2 (redraw on change).
- **The draw-call monitor does not count 2D on the Mobile renderer.** Mitigation: M9a checks it first; a frame capture counts instead.
- **RD 2D batching does not merge across nodes**, so the field passes 36: M9a per-node counts; merge `HeroZoneView` into `HeroView` and `ExitStripView` into `BackdropView` first.
- **Text is soft at device scale** (oversampling under `canvas_items` unverified): M3 screenshot at device resolution.
- **Lines look too thin on the phone** (no feather): widths live in `ViewStyle`; the device review may add 1 px.
- **A path fails triangulation**: dev error, `draw_polyline` fallback, content test L13.
- **`max_fps` 60 judders on 90 or 120 Hz panels**: Decision 11's trigger.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-011: Combat view draws primitives from one `_draw()` per kind, no shaders or particles, 16-marker flash pool on the frame clock | Decisions 1, 5, 7, 8: `CombatView` with one pass per kind; zero shaders; 16 markers with the GDD's eviction; `ViewClock` |
| enemy-wave.md | TR-enemy-015: views read `roster()` and the path each frame; fixed three-pass draw order; a view pool of at least 48 that grows with a dev error; Reduce Motion honoured | Decisions 2, 4, 5, 8: path baked from `path_points`; three buckets in `spawn_id` order; 48 buffers that grow with one dev error; `MotionPolicy`. **Partial**: the Enemy GDD's Reduce Motion line conflicts with AR-V-10 (sync item) |
| tower-system.md | TR-tower-015: all towers from one `_draw()` node, primitive polygons, level inset and a cooldown ring, with Reduce Motion fallbacks | Decisions 1, 8: `TowerView`; overlay scale cut under Reduce Motion; the cooldown ring reads `SlotState.cooldown_full`. **Partial** until ADR-0010 takes that field |
| battle-hud.md | TR-hud-001: HudLogic, HudTopBand (display-only Controls), HudField (one `_draw`, targets as resolver discs), absent headless, rebuilt on retry | Decisions 1 and 6: HudTopBand draws band primitives, HudField one `_draw` above the field; `RangeRingView` is a second HUD node under entities (sync item); built by the wrapper, so absent headless and rebuilt on retry (ADR-0001) |
| battle-hud.md | TR-hud-015: HUD about 8 (max 12) of 60 draw calls, at most 3 text draws; targets at least 72 units, text at least 21 units | Decisions 6, 9, 10: one text pass by 3 sizes; caps per part; V5 checks the size floors from `ViewStyle`; M9a measures HUD calls |

Also settled: QQ-10 (Decision 7) and QQ-11's draw-call and render-share parts (Decision 10), the latter pending M9a and M9b. ADR-0004's interpolation question: deferred with a trigger (Decision 11).

## Performance Implications
- **CPU** 3.0 ms p95 phone (trigger 0.2 ms desktop release). **GPU** 60 calls, flat fills, one 128x128 texture. **Memory** pools under 100 KB, one atlas per font size. **Load** one bake and one texture per battle, under 1 ms.

## Migration Plan
No code exists. At acceptance:
1. **ADR-0009** (dated amendment): add `Combat.hp_ratio(enemy) -> float`, view-only, to Key Interfaces and to Decision 1's list of `Health` reads.
2. **ADR-0007** (dated amendment): lints L-VIEW-1 (no `Tween`, `create_tween`, `ShaderMaterial`, `CanvasItemMaterial`, `z_index`, `CanvasLayer`, `Light2D`, particles or `Label` in `src/presentation/field/` and the battle HUD), L-VIEW-2 (no `Time.` in those folders but `render_budget_probe.gd`); M9 splits into M9a (desktop windowed) and M9b (phone).
3. **ADR-0010** (Proposed; for its author): `SlotState` gains `cooldown_full: int`; Decision 6's Combat row adds `speed_factor` and `hp_ratio`.
4. **architecture.md**: Presentation table, Data Flow 10 (call split, P-V1), rendering gap row (R1 to R13), Required ADRs, QQ-10, QQ-11.
5. **GDDs** (game-designer, user sign-off): Enemy & Wave Visual (Reduce Motion line against AR-V-10; `draw_polyline` note settled); Battle HUD Rule 1 table (HudField draws all HUD text; range rings in a HUD node under entities); Combat Rule 12 ("one `_draw` per kind" reading).
6. **Art bible §8** (art-director): zero shaders, hit flash a disc; one enemy drawer; path a baked polygon; RD 2D batching present (R5), unmeasured.
7. **`probe-results.md`**: an ADR-0011 section with R1 to R13 when the CI probe story lands (ADR-0007 Decision 7).

## Validation Criteria
- **V1 Path bake** (unit): the starter path gives one edge and one body polygon, square corners at each 90 degree turn (R4's points), and a non-empty triangulation; a self-crossing path reports one dev error and sets `fallback`.
- **V2 Draw order** (unit, over each view's model): three buckets in `spawn_id` order for a mixed roster; flashes after enemies; text after primitives in `HudField`.
- **V3 Pools** (unit): 17 flashes evict per Combat Edge Cases; a 49-enemy roster grows the buffers and reports one dev error, the 50th none.
- **V4 Clock and policy** (unit): `ViewClock` stops while paused and runs on Won; each AR-V-10 row maps to one `MotionPolicy` field with both flag values; `enemy_traits` true in both.
- **V5 Floors** (unit): every `ViewStyle` text size at least 21 units, every HUD hit radius at least 36; every text and must-see graphic meets AR-V-04 by the contrast formula.
- **V6 Listener isolation** (integration): a battle with every view connected gives the same digest as none (ADR-0006, TR-hud-004).
- **P-V1** release export under 0.2 ms p95 at the design point, or F1 is built.
- **M9a** at most 60 calls, HUD at most 12, text batches at most 3. **M9b** views p95 at most 3.0 ms; 30 fps floor holds.
- **M3** screenshots: square path corners, sharp text, readable lines at device scale.

## Reviews
Reviews still owed: godot-specialist (engine validation, step 5.5) and TD-ADR (step 5.6). The author could not start subagents; the caller runs them.

## Related
- Depends on ADR-0001, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0009; reads ADR-0010's B10 surface. Amends ADR-0009 and ADR-0007 at acceptance.
- GDDs above; art bible §5 to §8; accessibility AR-V-04, 08, 10, 13; interaction patterns IP-26 and Animation Standards.
- Open items for the user: the Enemy GDD's Reduce Motion line against AR-V-10; `ViewStyle` as code constants rather than catalogue data; the 36-call field cap; gold digits drawn by HudField.
