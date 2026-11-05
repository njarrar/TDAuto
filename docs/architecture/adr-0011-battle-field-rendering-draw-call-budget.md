# ADR-0011: Battle Field Rendering and Draw-Call Budget

## Status
Accepted

## Date
2026-11-05

## Last Verified
2026-11-05, against `architecture.md` v7, `tr-registry.yaml` (123 entries), ADR-0001 to ADR-0010 (all Accepted) with their amendments, and probes R1 to R20 run on 4.7.2 headless (below).

## Decision Makers
- Accepted: 2026-11-05 by the user (njarrar), with the dated ADR-0009 and ADR-0010 amendments and the HUD, Enemy and art bible syncs
Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`). Reviews: godot-specialist CONCERNS, TD-ADR CONCERNS, resolved below. User decision 2026-11-05: Reduce Motion follows AR-V-10. Acceptance: the user.

## Summary
The battle field and HUD must draw up to 48 enemies, the towers, the hero, combat feedback and the HUD inside 60 GPU draw calls and 3.0 ms of CPU a frame on an Adreno 5xx-class phone, with Reduce Motion, pause and retry handled one way. This ADR fixes one `_draw` node per view family in a fixed tree order, a path baked once into polygons, fixed view pools, no shaders (QQ-10: the hit flash is a drawn disc), all HUD text in one pass by size, one view clock and one Reduce Motion policy, and a budget with named measurements, a desktop trigger and a MultiMesh fallback.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Rendering (2D, Mobile renderer) and UI |
| **Layer** | Presentation |
| **Knowledge Risk** | MEDIUM: 4.7 removed the line feather; RD 2D batching across CanvasItems and the 2D draw-call count are not in the pinned reference |
| **References Consulted** | `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `modules/rendering.md`, `modules/ui.md`, `probe-results.md` (ADR-0004 E2, E7, E8; ADR-0003 S9) |
| **Post-Cutoff APIs Used** | `draw_circle(..., filled, width, antialiased)` (4.4, R3); `Control.accessibility_name`, `accessibility_live` (4.5, R18). Relied-on change: no line feather (4.7) |
| **Verification Required** | R1 to R20 verified 4.7.2 headless. Needs a GPU: draw calls and batching across nodes (M9a desktop windowed, M9b phone), frame time (M9b), the MultiMesh layout and per-instance colour (F1), text sharpness and disc edges (M3), 90 and 120 Hz pacing (ADR-0004 V13) |

All verified 4.7.2 headless (Linux x86_64, 4 cores, editor binary, debug):

| Probe | Result |
|---|---|
| R1, R2 | `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `TIME_PROCESS`, `RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`, `Performance.add_custom_monitor` exist. The draw-call monitor reads 0 headless |
| R3, R14 | `draw_circle(position, radius, color, filled = true, width = -1.0, antialiased = false)`; `draw_polyline`, `draw_multiline`, `draw_arc`, `draw_line` default `width = -1.0`, a thin line primitive, not a quad. No dashed arc |
| R4, R16 | `Geometry2D.offset_polyline(path, 36 or 34, JOIN_MITER, END_BUTT)` gives exact square 90 degree corners, ends flush, one polygon that triangulates. A sharp turn bevels. A self-crossing path merges into one valid polygon that triangulates with no error. A loop wider than the path adds a clockwise hole polygon |
| R5 | `rendering/2d/batching/item_buffer_size` (16384) exists, so the RD 2D batcher is present. `msaa_2d` 0. `project.godot` sets `rendering_method="mobile"` |
| R6, R20 | `_draw` runs headless, after that frame's `_process`. Sibling `_draw`s run in tree order. A node not queued keeps its old commands |
| R7, R15 | `ThemeDB.fallback_font` is a `FontFile`; it draws at 21, 24, 36 (a test string measured 100x30, 115x34, 173x50). `TextLine.add_string(text, font, font_size, ...)` and `TextLine.draw(canvas, pos, color, oversampling)` exist. `GradientTexture2D.FILL_RADIAL` exists |
| R13 | One `_draw` of about 115 draw commands (1 polygon, 112 discs, one multiline, one ring, one string): 259 µs p50, 410 µs p95 over 400 frames. Command recording on a dummy renderer: about 2.2 µs a command, a floor on GDScript cost |
| R17 | `MultiMeshInstance2D` exists with `texture`. Per-instance colour cannot be checked headless |
| R18 | `Control` has `accessibility_name`, `accessibility_description`, `accessibility_live`; `Node` has none |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0009 (Accepted 2026-11-04), ADR-0010 (Accepted 2026-11-05) |
| **Enables** | Visual Feedback & VFX (Vertical Slice) inherits the Combat view; the Mobile Platform & Performance GDD inherits the budget |
| **Blocks** | Every field view story and the HudField and HudTopBand stories. No story exists yet |
| **Ordering Note** | At acceptance the user confirms the dated amendments already written into ADR-0009 (`hp_ratio`) and ADR-0010 (`cooldown_full`, B10 Combat row); ADR-0007 takes Migration item 2 |

## Context

### Problem Statement
Five TRs ask for single `_draw` nodes, a fixed enemy draw order, view pools, Reduce Motion fallbacks and a HUD draw budget. ADR-0004 left interpolation here, ADR-0009 left QQ-10, and QQ-11 left the draw-call budget and render share. The Enemy GDD doubts `draw_polyline` at width 72. Art bible §8's batching claims predate 4.4.

### Constraints
- ADR-0003: 540x960, `canvas_items` + `keep`, no Camera2D, so field units are canvas units. ADR-0004: frame order, views read in step 3, `max_fps` 60. ADR-0001: the wrapper holds every view; Reduce Motion only from `PresentationSettings`. ADR-0005: only HudLogic reads stats in step 3. ADR-0006: VIEW listeners through `view_wiring`, never command or keep payloads. ADR-0009: plain-value `damage_applied`; 64-bit `x`, `y`; one reused `roster()`.
- Solo part-time developer: few node types, nothing a profiler has not asked for.

### Requirements
TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015; Data Flow 10 (3.0 ms; 60 draw calls; HUD about 8, at most 12, text at most 3); AR-V-04, AR-V-08, AR-V-10, AR-V-13.

## Decision

### 1. One `_draw` node per view family, tree order is draw order
The wrapper builds one `FieldViews` `Node2D`. Its children draw in this order, each from one `_draw` (R20):

| # | Node | Draws | Redraws |
|---|---|---|---|
| 1 | `BackdropView` | Field fill, grid, path polygons, free-slot marks | At build and when a slot fills; the burst dip is its `modulate` |
| 2 | `ExitStripView` | Chevrons, danger alpha and outline, leak pop | While in danger or popping |
| 3 | `RangeRingView` (HUD-owned) | Range rings, solid current, dashed next | When HudLogic's ring list changes or fades |
| 4 | `TowerView` | Bodies, level-2 inset, Ready or Cooling ring, build and upgrade overlay | While any tower cools or an overlay runs |
| 5 | `EnemyView` | Enemies in three passes, then state cues, then all slow drag lines in one `draw_multiline` | With a non-empty roster |
| 6 | `CombatView` | Splash rings, tracers, hit flashes, death discs, in that order | With a live entry |
| 7 | `HeroView` | Leash, reach ring, ground ring, unpinned ring, ghost; halo texture, kite, Ready ticks, burst ring, spokes, reticle, preview, kill contours | In Wave and Intermission |
| 8 | `HudTopBand` (`Control`) | Band panel, lives dashes, pips; no text | On change |
| 9 | `HudField` | Arc, chip, Start/Call, burst button, prompt panel, ground-tap ring, refusal cues, then all HUD text (Decision 6) | When a HUD element animates or changes |

- **No node per entity**; views hold plain records. "One `_draw` per kind" (TR-combat-011) reads as one node per view family, one pass per kind inside; both readings ban a node per instance.
- Hero zones now draw above enemies (TD trim). They are thin and unfilled, so they hide nothing.
- **Range rings sit under entities** (Tower Visual table), so the HUD owns `RangeRingView` under and `HudField` over. HudField keeps one `_draw` for all it shows above the field (TR-hud-001).
- **Origin**: `FieldViews` and `HudTopBand` stay at the canvas origin with no transform, so field units are local units. Code that must work elsewhere converts with `get_global_transform()`.
- **Batching hygiene**: no `z_index`, `CanvasLayer`, material, `Light2D` or `CanvasModulate` in nodes 1 to 9; untextured shapes first, then textures (the halo apart, which sits under the kite), then text; `modulate` is free. Modals sit after node 9.
- **Redraw only on change**: `queue_redraw()` in step 3 only when a model changed or animates; a node not queued keeps its commands (R20), so a static `BackdropView` costs no CPU.
- **Lines**: every line command passes a width of at least 2.0 from `ViewStyle`, dashed rings and drag lines included, and `antialiased = false`. Width -1.0 is a thin primitive (R14) and is never used. Keylines are a disc 1 unit larger. The device review may add 1 px; `msaa_2d` stays off unless M9b shows it is free.

### 2. The path is baked once into polygons
- At wrapper build, `PathMesh.bake` checks `path_points` for self-crossing first: every pair of non-adjacent segments through `Geometry2D.segment_intersects_segment`. R16 shows `offset_polyline` merges a crossing into one valid polygon with no error, so this check is the only way to see it.
- It then runs `offset_polyline(points, path_width / 2, JOIN_MITER, END_BUTT)` for the edge and `path_width / 2 - 2` for the body (art bible §6: 72 at +6% V, 68 at +3%). R4 shows exact square corners. Path points off the field put the ends off the field (Enemy L13).
- **Fallback** on a crossing, more than one polygon, any clockwise (hole) polygon, or an empty `triangulate_polygon()` (second guard): one dev error, then `draw_polyline(points, colour, path_width)`. It has no mitred corners; it is a dev-only state after a dev error, so that is acceptable. Content test L13 already bans a path that doubles back.
- A corner with an interior angle under about 60 degrees passes the mitre limit and bevels (R16); Vertical Slice stage rules check it.

### 3. Positions: 64-bit sim floats to 32-bit draw commands
- A view builds `Vector2(t.x, t.y)` only at the draw command, from the `Targetable` it reads in step 3. It never keeps a `Targetable` or the `roster()` array past step 3, and never writes back. Per-enemy view state is keyed by `spawn_id`.
- The cast loses under 0.0001 units inside 960 (E2). Views may use `Vector2` maths; L-VEC-1 covers sim folders only.
- Bob, jitter, lean and the hero's facing are view offsets after the cast, with phases from `spawn_id` and the view clock, so they need no per-enemy record.

### 4. `EnemyView` and `TowerView`
- One scan of `roster()` (in `spawn_id` order) puts each enemy's index into one of three reused buckets: heavy (30 px), normal (22 px), fast (16 px). The pass comes from a `visual_key` to style table built once from the Enemy records (not a stat). Each bucket draws in `spawn_id` order; no sort runs, so ties are stable.
- Per enemy: keyline disc, body disc, the `fast` notch, then its state cue. Feature budget (Combat Visual): under 22 px, flash and slow only; slowed and damaged, slow shows and the core hides.
- The damaged core reads `Combat.hp_ratio(enemy)` (ADR-0009 amendment); slow reads `speed_factor`. Corpses before the reap are skipped (`is_dead`); `CombatView` owns the death disc.
- `TowerView`'s Cooling ring is `cooldown_left / cooldown_full` from `SlotState` (ADR-0010 amendment), and 0 when `cooldown_full` is 0. No view reads `attack_interval`.

### 5. Pools, and how they grow
Made once at wrapper build, reset by the rebuild on retry, never shared, no `static var`.

| Pool | Size | When full |
|---|---|---|
| Enemy draw buffers | 48 (art bible §8, `peak_alive_ub`) | Grow to the roster size, once, with one dev error per battle; an enemy is never hidden |
| Hit-flash markers | 16 (`FLASH_MARKER_LIMIT`) | Combat Edge Cases eviction; a tower flash never evicts a hero flash; a suppressed flash takes none |
| Death discs 48, tracers and spokes 64, splash rings 16, glow sprites 8 | as listed | Drop the oldest |

### 6. Text
- **No `Label` in the battle HUD.** `HudField` draws every HUD string in one final pass after its primitives, grouped by size: 21 units (14 dp), 24 (16 dp), 36 (24 dp, the burst digit). One atlas per size is expected, not guaranteed, so this is at most 3 text batches if it holds; M9a counts them.
- **Gold digits** (MVP): `HudTopBand` owns the gold layout and string as a plain record; `HudField` only draws it there (V2 checks). If M9a shows text batches merge across nodes, the digits go back to `HudTopBand`.
- **Accessibility**: drawn text has no AccessKit node, so `HudTopBand` (a `Control`, R18) sets `accessibility_name` and `accessibility_live` for gold and lives on change.
- **Fonts**: the wrapper loads one font once (the chosen font, or `ThemeDB.fallback_font`, R15). Tabular numerals need a `FontVariation` with `tnum` in `opentype_features`; the fallback may not honour it. Each text slot caches one `TextLine`, re-shaped only when its string or size changes, drawn with `TextLine.draw(get_canvas_item(), pos, colour)`.
- **Larger text (AR-V-03, Alpha)**: the 125% step scales the three sizes, still 3 batches. Wrapping uses `TextParagraph` or the UX spec's shortening rule.
- Modal TapScreens may use `Label`s (about 4 draw calls).
- Text sizes are at least 21 units; text meets 4.5:1 on its panel in every state (AR-V-04, AR-V-05).

### 7. No shaders (QQ-10)
- **The hit flash is a drawn disc.** `CombatView` draws a white disc over the enemy for `FLASH_SECONDS` (0.08 s), alpha 1.0 for hero and burst hits and `TOWER_FLASH_ALPHA` (0.6) for tower hits; a retrigger restarts it and keeps the higher alpha. It follows the enemy by `spawn_id` while it is in `roster()`, then stays at `hit_position`. `damage_applied` carries all of this, so the handler records plain values only.
- **No `ShaderMaterial` or `CanvasItemMaterial` at MVP.** The danger pulse is an alpha `_draw` computes from the view clock; outlines are a second shape. A `TIME`-driven shader runs through Pause and ignores Reduce Motion, and a material breaks batching. Art bible §8's 3-shader ceiling stays unused until Vertical Slice.
- **Glow**: hero halo and burst glow are one 128x128 `GradientTexture2D` (`FILL_RADIAL`) made in code, drawn with `draw_texture_rect` and `modulate`. No `Environment.glow`, `Light2D`, `CanvasModulate` or particles; the death pop stays deferred.

### 8. One view clock; Reduce Motion as one policy
- **`ViewClock`** (one per wrapper) takes an injected phase read (the method Callable `Flow.phase`) and `advance(ms)` with step 1's clamped `ms`, called in step 3. It does nothing while the phase is `PAUSED`, and keeps running on Won and Lost so transients finish. Every field and HUD-primitive timing reads it. Retry rebuilds it. HudLogic's own `advance(ms)` is unchanged.
- **No `Tween`, `SceneTree` timer, `await` or `Time` call** in nodes 1 to 9, the debug probe apart. ADR-0001 allows tweens on own nodes; this ADR does not use them.
- **`MotionPolicy`** is made once per wrapper from `PresentationSettings.reduce_motion`. It has a field only for each AR-V-10 row that changes under Reduce Motion: `slides`, `danger_pulse`, `burst_dip`, `burst_shape` (wind-up, snap, Ready pop), `nudge` (static refusal cue instead), `overlay_scale`, `arc_collapse`, `breathing`, `leak_pop` (a still double outline for 200 ms instead). Rows kept in both modes (enemy jitter, bob and lean, clocks, fades) have no field. Views ask the policy, never the flag.
- **User decision 2026-11-05**: AR-V-10 wins; bob, jitter and lean stay on (they are telegraphs). The Enemy GDD line changes (sync item).
- A Reduce Motion change takes effect at the next wrapper build; the Alpha Settings story inherits that rule.

### 9. Style table
`ViewStyle` (`src/presentation/view_style.gd`) holds every colour, alpha, width, size, radius and duration the views draw. **Rule**: a value is gameplay if it changes a sim result or how a tap resolves; those live in the catalogue or with their input owner (hit radii stay with HeroInput, TowerInput and HudLogic). A value that only changes pixels is a presentation constant in this one table. Combat's `FLASH_SECONDS`, `TOWER_FLASH_ALPHA` and `FLASH_MARKER_LIMIT` live here (sync item). The contrast test and V5 read it.

### 10. Budget and measurement (QQ-11, draw-call and render parts)
**GPU draw calls, 60 a frame at the design point** (48 enemies, 6 towers, 16 flashes, burst firing). Provisional until M9a; no per-node cap.

| Part | Share |
|---|---|
| HUD, nodes 8 and 9 (expected 8) | At most 12, text batches at most 3 |
| Engine (clear, letterbox, blit) | 4 |
| Spare (no modal shows during play; a modal's about 4 come from here) | 8 |
| Field views, nodes 1 to 7 | What is left: 36 |

**CPU, views and HUD 3.0 ms p95 on the phone** (Data Flow 10): step 3's refresh plus every `_draw` body, counted in draw commands.

- **P-V1 `bench_views`** (`tests/performance/`, headless, R6): times step 3 and each `_draw` at the design point. **Trigger**: 3.0 / 15 = **0.2 ms p95 in a release export** (ADR-0009's factor). About 230 commands at 2.2 µs (R13) is about 0.5 ms p50 and 0.8 ms p95 in debug, so debug fails the trigger by 2.5 to 4 times. **F1 is the likely path.** The first `EnemyView` story runs P-V1 in a release export before it builds the per-disc path. A cheaper first cut: drop the keyline disc under 22 px.
- **F1 MultiMesh**: one `MultiMeshInstance2D` per pass (heavy, normal, fast), children of `EnemyView` with `show_behind_parent`, so they take its slot and the cues still draw on top. The mesh is a disc `ArrayMesh` fan whose rim vertices are dark and centre white, so each instance draws its own keyline and the overlap order stays per enemy; only cues move after all bodies, which is acceptable. `use_colors = true` before `instance_count`; the buffer is one `PackedFloat32Array` a frame, believed 12 floats an instance (8 transform, 4 colour; unverified, check windowed). Flashes use one more. This cuts about 100 commands.
- **M9a, desktop windowed** (Vulkan, Mobile renderer): a debug-only `RenderBudgetProbe` logs `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` through the design-point scene in two runs, all views then HUD only. If it reads 0 for 2D, count from a RenderDoc capture. Batching across separate CanvasItems is unverified; M9a is where it is seen.
- **M9b, phone** (ADR-0007 M9): the same two runs on the Adreno phone, plus p95 of step 3, `_draw` and `TIME_PROCESS`, retained in `production/qa/evidence/`.

### 11. View interpolation: deferred
Views draw the last tick. `max_fps` 60 gives one tick per 60 Hz frame and two at 30 fps; ADR-0004's mid-tick seed absorbs jitter under half a tick. Interpolation would show a tick-old state against "the flash appears on the first frame after the hit". **Trigger**: V13 or M9b sees judder. **Seam**: one position helper per view, plus a read-only `TickClock.fraction()` (an ADR-0004 amendment then).

### Key Interfaces
```gdscript
class_name ViewClock extends RefCounted        # src/presentation/view_clock.gd
func _init(phase: Callable) -> void            # method Callable Flow.phase
func advance(ms: float) -> void                # step 3; no-op while PAUSED
func now_ms() -> float

class_name MotionPolicy extends RefCounted     # src/presentation/motion_policy.gd
func _init(reduce_motion: bool) -> void
var slides: bool; var danger_pulse: bool; var burst_dip: bool; var burst_shape: bool
var nudge: bool; var overlay_scale: bool; var arc_collapse: bool; var breathing: bool; var leak_pop: bool

# Each view in src/presentation/field/ and the HUD:
func setup(reads: Object, clock: ViewClock, policy: MotionPolicy, dev_error: Callable) -> void
func refresh() -> void                         # step 3; reads, updates model, maybe queue_redraw()

class_name PathMesh extends RefCounted         # src/presentation/field/path_mesh.gd
static func bake(points: PackedVector2Array, width: float, dev_error: Callable) -> PathMesh
var edge: Array[PackedVector2Array]; var body: Array[PackedVector2Array]; var fallback: bool

# Amendments of 2026-11-05, confirmed by the user 2026-11-05 at this ADR's acceptance:
# Combat.hp_ratio(enemy: Targetable) -> float  (ADR-0009)
# SlotState.cooldown_full: int                  (ADR-0010)
```

### Implementation Guidelines
1. Views must never create a node per enemy, tower, flash, tracer or ring.
2. Views must not set `z_index`, add a `CanvasLayer`, set a material, or use `Light2D`, `CanvasModulate`, `Environment.glow` or particles.
3. Views must not use `Tween`, `create_tween()`, a `SceneTree` timer, `await` or `Time` (the debug `RenderBudgetProbe` apart); every timing reads `ViewClock`.
4. Views must read Reduce Motion only through `MotionPolicy`.
5. Views must read sim state only in `refresh()`, through B10, `roster()`, `targets()` and Combat's four view queries `hp_left`, `is_dead`, `speed_factor`, `hp_ratio`; a VIEW handler must store plain values and read no stat.
6. Views must never keep a `Targetable`, `roster()` or `SlotState` past `refresh()`, and never write a sim value.
7. Each `_draw` must draw untextured shapes, then textures, then text; only `HudField` draws HUD text, in its final pass by size.
8. Text slots must cache a `TextLine`; no `Label` in the battle HUD.
9. Every line command must pass a `ViewStyle` width of at least 2.0 and `antialiased = false`.
10. A node must call `queue_redraw()` only when its model changed or it animates.
11. Pools must be sized per Decision 5; only the enemy buffers grow, with one dev error per battle.
12. Every pixel-only value must come from `ViewStyle`; gameplay values never live there.

## Alternatives Considered
1. **A node per entity** (art bible §8 ideal): each entity redraws alone, but 48 to 120 nodes to pool and tear down, and three TRs ask for one node. Rejected.
2. **The path with `draw_polyline` or `Line2D`**: no geometry step, but unmitred joints, 4.7 line changes, and a node type for one shape. Rejected: R4 gives exact corners from one bake.
3. **One hit-flash shader** (QQ-10): exact body shape, but it breaks batching and its time ignores Pause and Reduce Motion. Rejected: a disc over a disc is the same pixels.
4. **`Label` nodes for HUD text**: layout, AccessKit and autowrap for free, but text interleaves with primitives across nodes, so batches can pass 3. Rejected for MVP; Decision 6 names when to revisit.
5. **Interpolate now**: smooth on any refresh rate, but a tick of lag, a buffer per enemy and an ADR-0004 amendment with no judder seen. Deferred (Decision 11).

## Consequences

### Positive
- Nine nodes, each with one `_draw`, so the draw order is the tree.
- Pause, retry and Reduce Motion each live in one place (`ViewClock`, rebuild, `MotionPolicy`).
- Zero shaders; the path costs one bake; the budget has a bench, two device checks and a fallback.

### Negative
- `EnemyView` and `CombatView` re-run their whole `_draw` each frame in Wave; CPU scales with draw commands.
- No `Label` means drawn HUD text has no AccessKit node and no autowrap; `HudTopBand` carries the names for gold and lives only. A battle screen reader is already out of scope.
- HudField draws the gold digits HudTopBand lays out.
- `ViewStyle` is code, so a colour change is a code change.

## Risks
- **CPU from draw commands passes 3.0 ms on the phone.** Debug already fails the trigger (Decision 10). Mitigation: P-V1 in a release export first; F1 MultiMesh; drop small keylines; redraw on change.
- **Batching does not merge across nodes**, or breaks on the halo texture, so the field passes 36. Mitigation: M9a; merge `ExitStripView` into `BackdropView` first.
- **The draw-call monitor does not count 2D.** Mitigation: RenderDoc in M9a.
- **The F1 layout or per-instance colour differs** from the belief. Mitigation: a windowed check before F1 ships.
- **Text is soft at device scale**, or `tnum` is missing from the fallback font. Mitigation: M3; the chosen font's `FontVariation`.
- **Lines look thin on the phone.** Mitigation: widths in `ViewStyle`.
- **A path falls back** to unmitred `draw_polyline`. Mitigation: dev error; L13.
- **`max_fps` 60 judders.** Mitigation: Decision 11's trigger.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-011: Combat view draws primitives from one `_draw()` per kind, no shaders or particles, 16-marker flash pool on the frame clock | Decisions 1, 5, 7, 8: `CombatView`, one pass per kind; zero shaders; 16 markers; `ViewClock` |
| enemy-wave.md | TR-enemy-015: views read `roster()` and the path each frame; three-pass draw order; a view pool of at least 48 that grows with a dev error; Reduce Motion honoured | Decisions 2, 4, 5, 8. **Full once** the Enemy GDD's Reduce Motion line is synced to the user's decision |
| tower-system.md | TR-tower-015: all towers from one `_draw()` node, primitive polygons, level inset and a cooldown ring, with Reduce Motion fallbacks | Decisions 1, 4, 8: `TowerView`; ring from `cooldown_full`; overlay scale cut. **Full once** the ADR-0010 amendment is confirmed |
| battle-hud.md | TR-hud-001: HudLogic, HudTopBand (display-only Controls), HudField (one `_draw`, targets as resolver discs), absent headless, rebuilt on retry | Decisions 1, 6: HudTopBand one display-only `Control`; HudField one `_draw` above the field; `RangeRingView` a second HUD node under entities (sync item); wrapper-built (ADR-0001) |
| battle-hud.md | TR-hud-015: HUD about 8 (max 12) of 60 draw calls, at most 3 text draws; targets at least 72 units, text at least 21 | Decisions 6, 9, 10: one text pass by 3 sizes; V5 reads sizes from `ViewStyle` and hit radii from their owners; M9a counts |

Also settled: QQ-10 (closes with Decision 7); QQ-11's draw-call and render parts, pending M9a and M9b; ADR-0004's interpolation question, deferred.

## Performance Implications
**CPU** 3.0 ms p95 phone; trigger 0.2 ms desktop release. **GPU** 60 draw calls, flat fills, one 128x128 texture. **Memory** pools under 100 KB, one atlas per font size. **Load** one bake and one texture per battle, under 1 ms.

## Migration Plan
No code exists. At acceptance:
1. **ADR-0009 and ADR-0010**: the user confirms their 2026-11-05 amendments (`hp_ratio`; `cooldown_full` and the B10 Combat row).
2. **ADR-0007** (dated amendment): L-VIEW-1 bans `Tween`, `create_tween`, materials, `z_index`, `CanvasLayer`, `Light2D`, particles and `Label` in `src/presentation/field/` and the battle HUD; L-VIEW-2 bans `Time.` there but `render_budget_probe.gd`; M9 splits into M9a and M9b.
3. **architecture.md**: Presentation table (nine nodes), Data Flow 10 (shares, P-V1), rendering gap row (R1 to R20), Required ADRs, QQ-10 closed, QQ-11.
4. **Enemy & Wave GDD** (game-designer): the Reduce Motion line reads "bob, jitter and lean stay on; the leak pop becomes a still double outline for 200 ms"; the `draw_polyline` note is settled.
5. **Battle HUD GDD** (game-designer signs off): Rule 1 table: HudTopBand is one display-only `Control` with no text; HudField draws all HUD text; `RangeRingView` is a second HUD node under entities; TR-hud-001's wording follows. Combat GDD: Rule 12's "per kind" reading; `ViewStyle` named as the home of the three flash knobs.
6. **Art bible §8** (art-director): zero shaders, the hit flash a disc; no shared `TIME` pulse material (the pulse comes from `ViewClock`); no alpha-tweened burst glow (no tweens); no `CPUParticles2D` death pop (deferred); one enemy drawer; the path a baked polygon; RD 2D batching present (R5), unmeasured.
7. **Accessibility requirements**: drawn HUD text has no AccessKit node; HudTopBand names gold and lives.
8. **`probe-results.md`**: an ADR-0011 section with R1 to R20 when the CI probe story lands.

## Validation Criteria
- **V1 Path** (unit): the starter path gives one edge and one body polygon with R4's square corners; a self-crossing path (caught by the segment check), a looped path (clockwise hole) and an empty triangulation each report one dev error and set `fallback`.
- **V2 Order** (unit, over view models): three buckets in `spawn_id` order; flashes after enemies; text after primitives in `HudField`; the gold string comes from `HudTopBand`'s record.
- **V3 Pools** (unit): 17 flashes evict per Combat Edge Cases; a 49-enemy roster grows the buffers with one dev error, the 50th none.
- **V4 Clock and policy** (unit): `ViewClock` stops while `PAUSED` and runs on Won; every AR-V-10 row is a `MotionPolicy` field or on the kept list.
- **V5 Floors** (unit): `ViewStyle` text sizes at least 21; hit radii at least 36, read from their owners; text and must-see graphics meet AR-V-04.
- **V6 Isolation** (integration): every view connected gives the same digest as none (TR-hud-004).
- **P-V1** release export at most 0.2 ms p95, or F1 is built. **M9a** at most 60 draw calls, HUD at most 12, text batches at most 3. **M9b** views p95 at most 3.0 ms; 30 fps holds.
- **M3** screenshots: square path corners, disc edges (no MSAA, no feather), sharp text, readable lines at device scale.

## Reviews
**godot-specialist: CONCERNS. TD-ADR: CONCERNS.** All findings applied.

| # | Finding | Resolution |
|---|---|---|
| B1 (TD 1) | ADR-0010 is Accepted | Last Verified, Dependencies, Ordering Note, Key Interfaces, TR-tower-015, Migration 1; dated amendments written |
| B2 (both) | P-V1 arithmetic; F1 detail | Decision 10: 0.5 to 0.8 ms debug, F1 likely, release run first, keyline cut; F1 mesh, order, layout; commands vs calls; top Risk |
| B3 (godot 2) | Self-crossing passes silently | Decision 2 segment check, polygon count, clockwise; V1 |
| B4 (TD 3) | Reduce Motion conflict | User decision: AR-V-10; Migration 4 |
| G3 | Cross-item batching unverified | Decision 10 M9a, M9b, RenderDoc |
| G4 | Width -1 is thin | Decision 1, Guideline 9 |
| G5 | Atlas per size; `tnum` | Decision 6 |
| G6 | Drawn text and AccessKit | Decision 6, Negative, Migration 7 |
| G8 | Fallback unmitred | Decision 2 |
| G9 | Disc edges | M3 |
| G13 | Origin | Decision 1 |
| TD 4, 5, 6 | Policy fields; clock phase; setting change | Decision 8; V4; Key Interfaces |
| TD 7 | Hit radii; flash knobs | Decision 9; V5; Migration 5 |
| TD 8, 9 | HUD Rule 1; art bible items | Migration 5, 6 |
| TD 10 | Larger text | Decision 6 |
| TD 11, 12 | Four queries; ratio at 0 | Guideline 5; Decision 4 |
| TD trims | Fold HeroZoneView; derived shares; field cap | Nine nodes; Decision 10; ViewStyle rule and gold conditions per TD |

GDD sync (5 GDDs checked): no renamed names; content sync items in Migration 4 to 7.

## Related
- Depends on ADR-0001, 0003, 0004, 0005, 0006, 0009, 0010; amends ADR-0009 and ADR-0010 (confirmed 2026-11-05), ADR-0007 at acceptance.
- GDDs above; art bible §5 to §8; accessibility AR-V-03, 04, 08, 10, 13; interaction patterns IP-26 and Animation Standards.
- Open items for the user: none beyond confirming the two amendments.
