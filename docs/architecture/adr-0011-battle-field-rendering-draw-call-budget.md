# ADR-0011: Battle Field Rendering and Draw-Call Budget

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Why this is stated here: stories referencing a `Proposed` ADR are set `Blocked`,
> and epics require `Accepted`, so the field needs a named owner.
> `technical-director` is the role `coordination-rules.md` already escalates
> technical conflicts to, and an ADR is that decision made durable.
>
> This does **not** relax the existing rule that `Status: Accepted` is never set
> without explicit user confirmation. It narrows *which agent* may set it once
> that confirmation exists. An agent that believes an ADR is ready says so and
> escalates; it does not edit this field.
>
> Acceptance preconditions: (1) ADR-0009 and ADR-0010 are Accepted; (2) V1 to V6
> below have recorded results in `docs/engine-reference/godot/modules/rendering.md`
> (each runs in the standalone prototype `prototypes/adr-0011-render-budget/`,
> not as a story; V1, V2 and V4 also need a run on the user's phone); (3) MET:
> the user confirms or overturns each choice in Decision 11 (confirmed by the
> user, 2026-11-04, as recommended); (4) art-director and
> technical-artist sign off the art bible §8 edits (cascade a6), and the user,
> art-director (§6 owner) and game-designer (Enemy & Wave owner) confirm the
> path-geometry limit of Decision 5 and its move into Stage validation. User part
> MET: confirmed by the user, 2026-11-04, as recommended; cascade a6, a15 and a18
> are applied. Role sign-offs: confirmed by the user as project owner, 2026-11-04;
> the named roles were not consulted separately. Until all
> four hold, this ADR stays `Proposed`, because the batching, line and counter
> behaviours it relies on are not sourced in the pinned reference and the art and
> geometry rules are design content.
>
> Verification progress, 2026-11-04 (macOS arm64, headless, Godot 4.7.2 editor
> binary; `prototypes/adr-checks/`): V6 is RECORDED in
> `docs/engine-reference/godot/verification-results.md` (not yet copied to
> `modules/rendering.md`); the `PackedInt32Array` const parses, no branch.
> Still open before acceptance: V1 to V5 (`prototypes/adr-0011-render-budget/`,
> desktop and phone).
>
> After acceptance: A1 (the real game's worst-case frame on the phone, shared
> with ADR-0004 V6 and ADR-0007 M7). Reopen trigger: Decision 9.

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode. TD-ADR returned CONCERNS (T1 to T8; T1 and T2 blocking) and the engine check returned two before-acceptance items (E1, E2) plus minor notes; the user's delegate chose "Revise flagged items" for all, and all are applied in this revision (2026-11-04).

## Summary

The battle field and HUD must draw inside 60 draw calls and step 4's 3.0 ms on a low-end Android phone, with every view a read-only observer that keeps no sim object and tears down on retry. Decided: seven per-kind `_draw` nodes in a fixed order on one canvas with no layer, z-index, material, shader or particle (QQ-10); a `RefCounted` model per node that copies reads into preallocated buffers (enemies 48 growing with a dev error, flashes 16, tracers 64, death discs 48); the path as a mitred quad strip with its geometry rule in Stage validation; a provisional line-width bias; and per-node ceilings totalling 34 of 60, all pending device verification.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (pinned 4.7.2, Mobile renderer, `project.godot` `renderer/rendering_method="mobile"`) |
| **Domain** | Rendering (2D) |
| **Layer** | Presentation |
| **Knowledge Risk** | MEDIUM (`architecture.md` Engine Knowledge Gap Summary, Rendering row) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `modules/rendering.md` (4.7 `CanvasItem` lines lose the AA feather; nothing on 2D batching, draw counters or `_draw` cost); `breaking-changes.md` 4.7 Rendering rows (line feather, `LinearToSRGB`, `get_format()`, particles rename, sky layers: only the first applies); `deprecated-apis.md` (nothing in 2D drawing); `current-best-practices.md` § Rendering (4.7); `modules/ui.md` (stretch defaults, already fixed by ADR-0003) |
| **Post-Cutoff APIs Used** | None new. Relies on one sourced 4.7 behaviour change: `CanvasItem` lines draw without an AA feather and look thinner. Every `draw_*` method used is pre-cutoff; its 4.7 behaviour beyond that note is unsourced |
| **Verification Required** | V1 to V6 before acceptance; A1 after acceptance (below) |

### Verification items

NOT SOURCEABLE in `docs/engine-reference/godot/**`: how the Mobile renderer batches `_draw` commands across and within CanvasItems; whether `Performance` or `RenderingServer` draw counters include 2D canvas batches; `draw_polyline` joint shape at width 72; the cost and look of `antialiased = true` on 4.7 lines; the cost of a CanvasItem material. Art bible §8's batching paragraph is pre-4.4 knowledge and is not a source either. "Expected" below is not a result.

**Before acceptance** (standalone Godot 4.7.2 project `prototypes/adr-0011-render-budget/`, Mobile renderer, 540x960 `canvas_items` / `keep` as ADR-0003 sets; owner: godot-specialist writes it, the user runs it on desktop and on their phone; results go to `modules/rendering.md`; the phone run can share the ADR-0003 device spike session):

- **V1. How to count draw calls.** Candidates: `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)`, `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`, `Viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)` (all NEEDS VERIFICATION), the editor's Monitors tab, and an external frame capture (RenderDoc on desktop, Android GPU Inspector or the vendor profiler on the phone). Method: a scene with an empty field, then 1, 10 and 48 filled discs in one `_draw`, then the same 48 in 48 nodes; compare each counter with the capture. Record which source counts canvas batches. *Branch*: if no in-engine counter counts 2D, the dev overlay (Decision 10) shows frame time only, and draw calls are checked by capture at A1 and at each milestone.
- **V2. Batching of `_draw` primitives.** The synthetic worst case of Decision 9 (seven drawers, 48 enemies of three styles with keylines, 16 flashes, 64 tracer segments through `draw_multiline_colors`, five towers with rings, the hero with its glow texture, HUD text at three sizes, and 48 `max_hp` accessor reads per frame as CombatViewModel makes them). Record total draw calls (V1's method), each node's share (toggle `visible`), and the p99 of step 4 plus render on the phone. Run it twice: commands in Decision 6's order (primitives, then textures, then text grouped by size) and interleaved, to record what the order is worth; and record whether the three font sizes share one glyph atlas. Expected (unsourced): untextured primitives in one node with no material batch into a few calls. *Branch*: if each primitive is its own call (48 enemies alone pass 48), EnemyView and CombatView build one triangle array per frame and submit it with a single `RenderingServer.canvas_item_add_triangle_array` (or `draw_mesh` of a reused `ArrayMesh`), which this prototype tests in the same run. That revision changes Decision 2, Alternative 5 and RID lifetime on retry, so it goes back through TD-ADR and godot-specialist before acceptance.
- **V3. Path corners.** The starter `path_points` at width 72 then 68, drawn three ways: `draw_polyline`, a `Line2D` with sharp joints, and Decision 5's baked quads. Zoomed screenshots of each 90 degree corner on desktop and phone. Expected: the baked quads give exact square corners; the record says what the other two do (the engine check already reports that `draw_polyline` at width 72 has no joint modes and notches corners). *Branch*: none for the bake (it uses no joint algorithm); if quads drawn with `draw_primitive` leave seams at the shared edge, the strip is submitted as one triangle array per colour.
- **V4. Line thickness on 4.7.** The reference does not say whether the lost feather was only on the `antialiased = true` path; if so, AA-off lines did not change and `LINE_BIAS` 1.0 thickens every stroke (engine check E1). Method: a 2 px ring, a 2 px dashed leash and a 1 px slot outline at bias 0.0 and 1.0, AA false and true, on 4.7.2 and a 4.6 build (or against art bible §3's stated widths measured in a screenshot), desktop and phone; record screenshots and the AA cost; also whether a full `draw_arc` (0 to TAU) shows a seam at `ring_points`' counts. The art-director picks the bias. *Branch*: a different bias, 0.0 included, or AA on, changes one constant (Decision 6).
- **V5. Material cost (informational).** The 16 flash discs drawn plain, then with one shared `ShaderMaterial` on a separate node. Record draw-call and frame-time difference. It cannot change Decision 7; it is the number a Vertical Slice reopen of QQ-10 needs.
- **V6. Packed-array constants.** `const TEXT_SIZES: PackedInt32Array = [21, 24, 36]   # V6; fallback Array[int]` parses and reads on 4.7.2, headless. *Branch*: `const TEXT_SIZES: Array[int] = [21, 24, 36]`. Owner: godot-specialist.
  - Result (2026-11-04, macOS arm64, headless): `const TEXT_SIZES: PackedInt32Array = [21, 24, 36]` parses and reads [21, 24, 36]; the fallback is not needed; see docs/engine-reference/godot/verification-results.md.

**After acceptance:**

- **A1. Real worst-case frame on the phone** (first phone build; owner: performance-analyst; reuses ADR-0004 V6's run and fills ADR-0007 M7). Starter stage, peak roster, a burst release with kills, chip and arc open. Record total draw calls, per-node calls, and p99 of step 4 plus `_draw` against Decision 9. Evidence: a retained capture and screenshot in `production/qa/evidence/`.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Proposed): `roster()` read-only buffers, float-pair positions, `view_position()`, `Combat` reads. ADR-0010 (Proposed, in review): the read surface of its Decision 7 and `ResultSnapshot` (Decision 11). Binding and already listed by those: ADR-0001, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007 |
| **Enables** | None. Feeds Visual Feedback (VS) and the Mobile Platform GDD's budget table |
| **Blocks** | Every field-view story and the HudField and HudTopBand drawing stories (Battle HUD, Combat view, Enemy view, Tower view epics). HudLogic stories do not wait on it |
| **Ordering Note** | `architecture.md` allows deferring this ADR to the first phone build; drafting now fixes the node and pool structure so view stories can be written. V1 to V6 need no game code and can run with the ADR-0003 spike. A1 needs the real game |

## Context

### Problem Statement

Four GDDs and the art bible describe field and HUD visuals, and they disagree on structure: the art bible §8 prefers per-enemy nodes, Polygon2D and Line2D for static shapes, and budgets three CanvasItem shaders; the Combat, Tower and Battle HUD GDDs require one `_draw()` per kind and no shaders. Nobody has fixed the node tree, the draw order, how a view reads the sim without keeping sim objects, what a "pool" is when one node draws every enemy, how the 72-unit path keeps square corners, or how the 60 draw-call budget splits. Field-view stories cannot be written until these are fixed.

### Current State

No view code exists. `architecture.md` marks the path joint NEEDS VERIFICATION; `project.yaml`'s 60 draw calls is an art-bible proposal; ADR-0004 gives step 4 and `_draw` 3.0 ms and leaves draw calls here.

### Constraints

- 540x960 field units, `canvas_items` stretch, `keep` aspect, letterbox, no `Camera2D` and an identity canvas transform (ADR-0003; registry `display_stretch`, `battle_camera_or_canvas_transform`).
- Views refresh in frame step 4 from read-only queries, after `hero_input.update()`; no interpolation at MVP; no `_process` outside the wrapper, AppRoot and the adapter (ADR-0004 Decision 5, TIME-2).
- View listeners hold presentation state only, never keep a sim object, and P8/P9 listeners never read the accessor; connections only in `BattleWrapper.attach` (ADR-0006 Decisions 2, 7).
- `roster()` is EnemyWave's buffer: never mutated or kept (ADR-0009, registry `mutate_roster_view`). Sim positions are float pairs; views use `view_position()` (ADR-0009 Decision 2).
- `detach()` clears every sim, resolver and Battle reference in the wrapper subtree (ADR-0001 Decision 6). `reduce_motion` arrives in `attach` (ADR-0001 Decision 8).
- Non-modal battle Controls use `MOUSE_FILTER_IGNORE` (ADR-0007 SCENE-1, registry `tappable_non_modal_control`).
- Cosmetic randomness never reads `rng_seed` or `sim_rng` (ADR-0004 Decision 7, MATH-4). No stat value is cached (registry `cached_stat_value`).
- Solo part-time developer; no renderer work, no custom shaders.

### Requirements

The five TRs in GDD Requirements Addressed; step 4 plus `_draw` within 3.0 ms (ADR-0004 Decision 10); gameplay identical with every view removed (TR-hud-004, TR-combat-010).

## Decision

### 1. Seven drawers, one canvas, fixed sibling order

The BattleWrapper scene holds these nodes as direct children, in this order (later draws on top). No `CanvasLayer`, no `z_index` other than 0, no `top_level`, no `material` on any of them or their children.

| # | Node (class) | Type | Draws (GDD owning the look) | Model |
|---|---|---|---|---|
| 1 | `FieldBackdrop` | `Node2D` | Field fill, grid, path, slots, exit chevrons (Enemy & Wave V/A; art bible §6) | `FieldBackdropModel` |
| 2 | `TowerView` | `Node2D` | Range rings, then tower bodies, level insets, state rings, build overlay (Tower V/A) | `TowerViewModel` |
| 3 | `EnemyView` | `Node2D` | Enemy bodies and keylines, three passes (Enemy & Wave V/A) | `EnemyViewModel` |
| 4 | `CombatView` | `Node2D` | Damaged cores, slow drag lines, tracers, splash rings, flashes, death discs, burst spokes (Combat V/A) | `CombatViewModel` |
| 5 | `HeroView` | `Node2D` | Leash, reach ring, ghost, preview, reticle, kill marks, glow, hero, burst ring (Hero V/A) | `HeroViewModel` |
| 6 | `HudField` | `Node2D` | Arc, chip, Start/Call, burst button, range-ring requests, ground ring, prompt (Battle HUD V/A) | `HudLogic` (ADR-0010) |
| 7 | `HudTopBand` | `Control`, `MOUSE_FILTER_IGNORE` | Band panel, lives dashes, wave pips, gold digits in its own `_draw` | `HudLogic` |
| 8, 9 | `ResultScreen`, `PausedScreen` | `Control`, `STOP` (ADR-0003 Decision 8) | Shown only when open | `ResultSnapshot`, `HudLogic` |

Range rings sit under entities because TowerView draws them first and EnemyView comes later. The kill preview's knock-out covers the damaged core because HeroView follows CombatView. The HUD sits above the field. Burst spokes are drawn by CombatView from its tracer pool (art bible §8), though the Hero GDD lists them. The InputAdapter and Clock draw nothing. HudTopBand's parent is not a Control, so its anchors would resolve against the viewport: the wrapper sets its `position` and `size` explicitly in `attach` and on `display_changed` (insets, ADR-0003 Decision 7).

### 2. Model and drawer split

Each drawer is a thin node; its model is a `RefCounted` in `src/presentation/<kind>/` that runs headless.

- `attach(...)` (called from `BattleWrapper.attach`) receives the reads it needs as objects or method Callables, `reduce_motion`, `dev_error`, and the preallocated capacities. `detach()` drops every reference.
- `refresh(view_ms: float) -> bool` runs in frame step 4. It reads queries, copies what it will draw into its own buffers (`PackedVector2Array`, `PackedFloat32Array`, `PackedInt32Array`, `PackedColorArray`), advances its view clock and returns whether anything changed.
- The drawer's `_draw()` reads only its model's buffers. It never calls a sim query, so a redraw after `detach()` draws the last frame or nothing, never a freed object.
- The wrapper calls `queue_redraw()` on a drawer only when `refresh` returned true. FieldBackdrop returns true only on a change (a built tower hides its slot, danger on or off or pulsing, a field value shift); the others usually every frame. `_draw` does not run on an invisible drawer, so one shown again is refreshed in the same step 4 first and never shows a stale frame.

Models and drawers never keep a `Targetable`, `Health`, `Status`, `DamageEvent`, record or sim system past the `refresh` call or handler that read it (ADR-0006 Decision 7 rule 2). What they keep are copies: `Vector2`, `int` `spawn_id`, `float`, `StringName`, enums.

### 3. Inputs: polling first, three connections

Models read state by polling in `refresh`, which needs no connection and cannot depend on listener order:

- EnemyViewModel: `roster()`, `Enemy.def_id`, `view_position()`.
- TowerViewModel: `slot_count()`, `slot_tower(i)`, `slot_level(i)`, `slot_cooldown_left(i)`, `slot_position(i)` (ADR-0010 Decision 7); the cooldown total and range through its own per-slot `ReadContext`s and the accessor at use time, with `halted()` after each read, as HudLogic does for the burst cooldown (ADR-0010 Decision 7).
- CombatViewModel: `Combat.is_dead`, `hp_left`, `speed_factor` per roster entry; `max_hp` through one `ReadContext` per enemy `def_id` made in `attach`, read in `refresh` only, one read per roster entry (up to 48 a frame). These reads are frame-side cost: they count in step 4's 3.0 ms, not in ADR-0005's 0.5 ms per-tick read ceiling, and V2's synthetic case includes them.
- FieldBackdropModel: `roster()` distances, `Flow.lives()` and `phase()`, `slot_tower(i)`, `HeroSim.burst_state()` (field dip).
- HeroViewModel: HeroSim queries and HeroInput's `aim_state()`, `aim_point()`.

CombatViewModel is the one model with connections, made in `BattleWrapper._connect_signals()` and undone in `detach()`: `burst_started` (P7), `attack_fired` (P8), `damage_applied` (P9), as ADR-0006's table already lists ("Combat view"); it is one of "the models it holds" that ADR-0006 Decision 8's wrapper test accepts as a listener. Its handlers write into the pools of Decision 4 with the current view time and never read the accessor. No view connects to P4 or P6 (their "may poll instead" option); P4 stays `required_after_attach` yes through TowerInput (ADR-0010). A new view connection is an amendment to ADR-0006's table.

Structural data reaches the views through two new read-only `Battle` members that the Builder sets, as it sets `input_record` (ADR-0005 Decision 8):

- `Battle.stage_record: StageRecord` (path points, path width, slot positions, `scene_ref`; HeroInput's `stage` argument in ADR-0010 Decision 8 comes from here too).
- `Battle.visual_keys: VisualKeys`, a `RefCounted` holding only `StringName`s: `enemy(def_id)`, `tower(tower_id, level)`, `hero()`, built from the records' `visual_key` fields (Data & Config). It holds no record and no Callable, so it forms no cycle.

The field look (hue, base value, grid tilt) stays in the stage scene (Data & Config: "Stage visuals are not catalogue values"). `scene_ref` names a scene whose root is `StageLook extends Node` with three exported values and no drawing; the wrapper instantiates it in `attach`, hands the values to FieldBackdropModel and frees it.

`attach` returns false (fatal, ADR-0001 Decision 6) if the stage scene fails to load, a look value is outside art bible §6's ranges, a `visual_key` has no entry in `ViewStyles`, or the path bake fails. The path rule itself is a Stage validation rule (Decision 5), so real content fails at catalogue load and in CI, for bots and headless tests too; the `attach` check guards code-built stages only. An integration content test runs the remaining checks (stage scene, look ranges, `visual_key` styles) on every Stage record so a player never sees one.

### 4. Pools: preallocated buffers, not nodes

A pool here is a fixed set of buffer slots allocated in `attach`, never `instantiate()` mid-battle.

| Pool | Owner | Capacity | When full |
|---|---|---|---|
| Enemy draw slots | EnemyViewModel | 48 (`peak_alive_ub`, art bible §8) | Grow the buffers to the roster size and call `dev_error` once per battle naming the size (Enemy & Wave Edge Cases) |
| Flash markers | CombatViewModel | 16 | Combat Edge Cases eviction order: oldest tower flash, then oldest hero flash; a tower flash never evicts a hero flash; a clearance-suppressed flash takes none |
| Tracer segments (tower and hero lines, splash rings, burst spokes) | CombatViewModel | 64 | Drop the oldest; cosmetic, no dev error |
| Death discs | CombatViewModel | 48 | Drop the oldest |
| Glow bursts | HeroViewModel | 8 | Drop the oldest |

One marker per flashing enemy, keyed by `spawn_id`; a retrigger reuses it and keeps the higher alpha (Combat V/A). Each `refresh` updates a marker's centre from the roster entry with that `spawn_id`; an enemy no longer in the roster keeps its last centre until the marker expires. Death discs use the `damage_applied` position payload. Death discs never use a flash marker.

### 5. The path: a mitred quad strip baked at attach

`PathOutline.bake(points: PackedFloat64Array, width: float) -> PackedVector2Array` (pure, `src/presentation/field/path_outline.gd`) returns four points per segment. At each interior point it offsets both neighbouring segments by `width / 2` and intersects the offset lines (a miter), so adjacent quads share one edge exactly; the first and last points (off field) get butt ends. A 90 degree turn gives an exact square corner, which is Enemy & Wave's "sharp joints keep 90 degree corners square" and art bible §6's square or mitred corners.

**Geometry rule.** Let `d_k` be the *deflection* at interior point `k` (the angle between the incoming and outgoing directions: 0 for straight on, 90 degrees for a square turn), with `d = 0` at the first and last points. With `w = path_width`:

1. Every `d_k` is at most 90 degrees. This is a style limit, not a fold condition (a miter limit or bevel could draw sharper turns); it bounds the miter length at `w / sqrt(2)` past the corner. Confirmed by the user as project owner, 2026-11-04; art-director and game-designer were not consulted separately (Status precondition 4).
2. Every segment from point `a` to point `b` has length at least `(w / 2) * (tan(d_a / 2) + tan(d_b / 2))`. Below that, the inner offsets of its two miters cross and the quad folds. Two square turns need `w`; a finely sampled curve with small deflections needs very little, so splines baked to points (Enemy & Wave Rule 2, art bible §6) pass.

The starter path passes: all deflections are 90 degrees and its shortest segment is 160 against 72. The rule belongs to Stage validation, not to this view: ADR-0002 Decision 4's geometry group checks it at catalogue load, using the record's own `path_width` (cascade), so a bot, a test and the game accept the same stages. `PathOutline.bake` re-checks it and returns an empty array for code-built points, and `attach` then fails.

FieldBackdrop bakes twice in `attach` (`path_width` for the edge colour, `path_width - 4` for the body, leaving 2-unit edges; the body passes whenever the edge does) and draws each quad with `draw_primitive` (four points, no triangulation call per quad). The bake uses no engine joint algorithm, so V3 only records what `draw_polyline` and `Line2D` would have done.

### 6. Lines, widths and antialiasing

- Every stroke width a GDD or the art bible states is drawn as `stated + ViewStyles.LINE_BIAS`. `LINE_BIAS := 1.0` is **provisional** (art bible §8, for the 4.7 thinner lines). If 4.7 only removed the feather from the `antialiased = true` path, AA-off lines did not change and the right bias is 0.0; NEEDS VERIFICATION, V4 decides against a 4.6 or stated-width reference. No width is edited per call site.
- No stroke is drawn thinner than 2.0 units after the bias; negative or zero widths (thin primitives) are never used.
- `antialiased` is false on every `draw_*` call until V4 says otherwise; 2D MSAA stays at the project default.
- Rings use `draw_arc` with a point count from `ViewStyles.ring_points(radius)`; dashed and dotted rings and slow drag lines are precomputed segment lists drawn with one `draw_multiline` (or `draw_multiline_colors`) per kind per frame.
- **Command order inside each `_draw`:** all untextured primitives first, then textured draws (HeroView's glow), then text grouped by size, one group per size. A texture or font switch between primitive passes splits a batch (unsourced). HeroView is the one exception: the glow must sit behind the hero, so it draws zones, then the glow, then the hero body and burst ring, which costs at least 3 calls. The Decision 9 "expected" column assumes this order; V2 measures it.
- Colours, sizes, widths, durations and point counts live in `ViewStyles` (`src/presentation/view_styles.gd`, `const` only), keyed by `visual_key` stem for entities. They are presentation constants, not gameplay values (Data Rule 1), and each row cites its GDD or art bible line.

### 7. No CanvasItem shaders or particles at MVP (QQ-10)

The battle uses zero CanvasItem materials and zero particle nodes. The hit flash is an alpha disc in CombatView's `_draw` (Combat V/A), the danger pulse is an alpha FieldBackdropModel computes from its view clock, and outlines are a second, larger shape drawn first. Art bible §8's three-shader budget is not used. A shader's `TIME` runs on engine time, so it would not stop on Pause or follow the view clock, and the Reduce Motion freeze would need extra uniforms. The death particles (art bible §8) stay deferred, as the Combat GDD defers them. Adding a shader or particles reopens this ADR with V5's number. The hero glow is the one texture on the field: a 128x128 `GradientTexture2D` drawn by HeroView with `draw_texture_rect` (art bible §8).

### 8. View clock, Reduce Motion, cosmetic offsets

- In step 4 the wrapper computes `view_ms` once: step 1's frame ms clamped to 100, or 0.0 while `Flow.phase()` is PAUSED, and passes it to every model's `refresh`. Every view duration (flash 80 ms, tracer 100 ms, danger hold 1.5 s, leak pop 200 ms) runs on it, freezes on Pause and is gone on retry with the model (Combat V/A "View clocks").
- Models take `reduce_motion` in `attach` and apply their GDD's Reduce Motion rows. Each such row is a unit test case with the flag both ways.
- Bob and jitter offsets come from `spawn_id` and the model's view clock (ADR-0004 Decision 7). No view reads `rng_seed`, `sim_rng` or a global random function.

### 9. Draw-call budget and the frame split (QQ-11)

Ceilings are proposals, counted by V1's method, unmeasured until V2 and A1.

| Drawer | Ceiling | Expected if V2 batches |
|---|---|---|
| FieldBackdrop | 3 | 1 |
| TowerView | 3 | 1 |
| EnemyView | 4 | 1 |
| CombatView | 4 | 1 to 2 |
| HeroView | 4 | 3 (primitives, glow texture, hero body) |
| **Field total** | **18** | **7 to 8** |
| HudField | 8 | 4 to 5 (one primitive pass, then three text sizes; more if the font sizes do not share an atlas, V2) |
| HudTopBand | 4 | 3 |
| **HUD total** (TR-hud-015) | **12** | **8** |
| ResultScreen or PausedScreen, when open | 4 | 4 |
| **Sum** | **34** | **19 to 20** |
| Engine (clear, letterbox, final blit) and headroom | 26 | |

HUD text uses one font at three sizes only, 21, 24 and 36 units (14, 16 and 24 dp), drawn with `draw_string`; a fourth size is a budget change. The synthetic worst case for V2 and A1: 48 alive (mixed styles), 16 flashes, 48 death discs, 64 tracer segments, five towers cooling with one range ring, hero aiming with glow 2, arc or chip open.

Time: step 4 (`hero_input.update()`, every `refresh`, including CombatViewModel's up to 48 `max_hp` reads and TowerViewModel's per-slot reads) plus every `_draw` fits ADR-0004's 3.0 ms slice; this ADR does not split it further.

**Reopen trigger** (after A1): total above 60, or the HUD above 12, or step 4 plus `_draw` p99 above 3.0 ms. Levers, in order: merge FieldBackdrop and TowerView; drop keylines; fewer ring points; the V2 triangle-array branch for EnemyView and CombatView. If those do not fit, escalate to `technical-director`.

### 10. Development measurement

Development builds show an overlay (in `src/presentation/dev/`, created by `DevLogs` like the run log, ADR-0010 Decision 10) with frame time, step 4 time (the wrapper's dev timers, ADR-0004 Decision 10) and V1's draw-call counter if V1 finds one. Release builds create none of it.

### 11. Choices made in autonomous mode

Each can be overturned; cascade section d lists them: the seven drawers and their order (1); the model and drawer split (2); polling except P7 to P9, and the two `Battle` members with `StageLook` (3); a fatal `attach` on presentation failure (3); the mitred strip and the Stage geometry rule (5); `LINE_BIAS`, stroke floor and AA off (6); zero shaders and particles (7); spokes in CombatView (1); the per-node ceilings and three text sizes (9).

All nine confirmed by the user, 2026-11-04, as recommended (each choice as written above). `LINE_BIAS` stays provisional at 1.0 until V4. The art bible §8 edits and the path rule were confirmed by the user as project owner, 2026-11-04; the named roles (art-director, technical-artist, game-designer) were not consulted separately.

### Architecture Diagram

```
 step 4: hero_input.update(); view_ms; each model.refresh(view_ms) -> queue_redraw() if changed
 Battle reads (roster, slot reads, Combat, HeroSim, Flow) + P7..P9 -> models (RefCounted, buffers)
 models -> drawers, one canvas, in order:
   1 FieldBackdrop  2 TowerView  3 EnemyView  4 CombatView  5 HeroView
   6 HudField  7 HudTopBand (IGNORE)  8,9 Result/Paused (STOP, when open)
 attach: stage_record, visual_keys, StageLook, path bake;  detach: models drop all reads
```

### Key Interfaces

```gdscript
# src/root/battle.gd (adds to ADR-0001's Battle; set by BattleBuilder, read-only by contract)
var stage_record: StageRecord
var visual_keys: VisualKeys

# src/foundation/data/visual_keys.gd
class_name VisualKeys extends RefCounted     # StringNames only; no records, no Callables, no signals
func enemy(def_id: StringName) -> StringName  # &"" if unknown
func tower(tower_id: StringName, level: int) -> StringName
func hero() -> StringName

# src/presentation/view_styles.gd
class_name ViewStyles extends RefCounted     # const only; never instantiated (@abstract, 4.5+, optional)
const LINE_BIAS := 1.0
const MIN_STROKE := 2.0
const ENEMY_POOL := 48
const FLASH_POOL := 16
const TRACER_POOL := 64
const DEATH_POOL := 48
const GLOW_POOL := 8
const TEXT_SIZES: PackedInt32Array = [21, 24, 36]   # V6; fallback Array[int]
static func ring_points(radius: float) -> int

# src/presentation/field/path_outline.gd
class_name PathOutline extends RefCounted
static func bake(points: PackedFloat64Array, width: float) -> PackedVector2Array   # 4 per segment; empty on failure

# src/presentation/field/stage_look.gd (root of the scene at StageRecord.scene_ref)
class_name StageLook extends Node
@export var field_hue: float       # degrees, 170 to 280
@export var base_value: float      # 0.08 to 0.14
@export var grid_tilt_deg: int     # 0, 15 or 30

# Every model (src/presentation/<kind>/<kind>_view_model.gd), extends RefCounted:
#   attach(<reads>, reduce_motion: bool, dev_error: Callable) -> bool
#   refresh(view_ms: float) -> bool      # frame step 4; true if the drawer must redraw
#   detach() -> void                     # drops every reference
# EnemyViewModel, TowerViewModel, CombatViewModel, HeroViewModel, FieldBackdropModel
# CombatViewModel listeners: _on_burst_started (P7), _on_attack_fired (P8), _on_damage_applied (P9)

# Every drawer (src/presentation/<kind>/<kind>_view.gd), extends Node2D:
#   var model: <Kind>ViewModel  (set in attach, kept through detach so a late redraw is safe)
#   func _draw() -> void        # reads model buffers only
# FieldBackdrop, TowerView, EnemyView, CombatView, HeroView, HudField; HudTopBand extends Control
```

New global names: `VisualKeys`, `ViewStyles`, `PathOutline`, `StageLook`, `FieldBackdrop`, `FieldBackdropModel`, `TowerView`, `TowerViewModel`, `EnemyView`, `EnemyViewModel`, `CombatView`, `CombatViewModel`, `HeroView`, `HeroViewModel`. Provisional until ADR-0007's NAME lints run (QQ-16). `HudField` and `HudTopBand` keep the Battle HUD GDD's names.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must draw battle visuals only from the seven drawers of Decision 1, in that sibling order, on one canvas.
- Must never add a `CanvasLayer`, a non-zero `z_index`, `top_level`, a `material`, a `ShaderMaterial`, a `.gdshader`, `Light2D`, `CanvasModulate`, a particle node, `Line2D`, `Polygon2D` or `Sprite2D` under the BattleWrapper (modal screens' own Controls excepted).
- Must never `instantiate()` a node during a battle; pools are buffers allocated in `attach`.
- `_draw()` must read only its model's buffers; models read the sim only in `refresh` or a P7 to P9 handler, and keep copies, never sim objects.
- Must never mutate or keep `roster()`; must use `view_position()` for enemy centres.
- Must never call the accessor from a P8 or P9 handler; must check `halted()` after every accessor read in `refresh`.
- Must apply `LINE_BIAS` to every stated stroke width, never draw below `MIN_STROKE`, and pass `antialiased = false`.
- Must order each `_draw` as untextured primitives, then textures, then text grouped by size (HeroView: zones, glow, hero body).
- Must draw path quads with `draw_primitive`; the path rule lives in Stage validation, never only in a view.
- Must take every colour, size, width, duration and pool size from `ViewStyles`.
- Must run every view duration on `view_ms`; never read `Engine`, `Time`, `Timer` or `delta` in a model.
- Must call `dev_error` once per battle when the enemy buffers grow.
- Must draw HUD text only at `ViewStyles.TEXT_SIZES`; every hit target at least 72 units across; no text below 21 units.
- `HudTopBand` must use `MOUSE_FILTER_IGNORE`.

## Alternatives Considered

### Alternative 1: One node per entity (art bible §8 ideal)
- **Description**: Pooled `Node2D` per enemy, tower and tracer, each with its own `_draw`; enemies move to one drawer above about 40.
- **Pros**: Simple per-entity code; engine culls and sorts.
- **Cons**: 48 enemy nodes plus 64 tracers plus 16 flashes; per-CanvasItem cost and batching unsourced; a node pool to tear down on retry; the threshold switch means two code paths. The Combat and Tower GDDs require one `_draw` per kind.
- **Estimated Effort**: Higher (two paths, pool lifecycle).
- **Rejection Reason**: Contradicts TR-combat-011 and TR-tower-015 and doubles the teardown surface for an unmeasured gain.

### Alternative 2: Engine line joints for the path (`Line2D` with sharp joints, or `draw_polyline`), Polygon2D for static shapes
- **Description**: Art bible §8 constraint: path as two `Line2D` or two `draw_polyline` calls; slots and grid as nodes.
- **Pros**: Least path code; editor-visible static art.
- **Cons**: Corner shape rests on an unsourced joint algorithm (the engine check reports `draw_polyline` at width 72 has no joint modes and notches corners); about 20 more nodes; no headless geometry test.
- **Estimated Effort**: Lower to similar.
- **Rejection Reason**: The baked strip gives exact corners by construction and is a pure, tested function. V3 records the other two.

### Alternative 3: CanvasItem shaders for flash, pulse and outline (art bible §8 budget of 3)
- **Description**: A shared flash material, a `TIME`-driven pulse material, an outline shader.
- **Pros**: Synchronised pulses; GPU work.
- **Cons**: The Combat GDD forbids shaders; `TIME` ignores Pause and the view clock; per-node materials may break batching (unsourced); shader compile on first use is a hitch risk.
- **Estimated Effort**: Higher (three shaders, uniforms for Pause and Reduce Motion).
- **Rejection Reason**: Every effect is reachable with alpha and shapes. V5 measures the cost for a later reopen.

### Alternative 4: One `_draw` for all field art
- **Description**: A single drawer for backdrop, towers, enemies, combat and hero.
- **Pros**: Fewest CanvasItems.
- **Cons**: Static backdrop redrawn every frame; four GDDs' visuals in one file; no per-kind measurement; one failure point for every story.
- **Estimated Effort**: Similar, but larger merge conflicts.
- **Rejection Reason**: Kept as the first reopen lever in a smaller form (merge FieldBackdrop and TowerView).

### Alternative 5: RenderingServer canvas items or MultiMesh from the start
- **Description**: Views own RIDs and submit triangle arrays or a `MultiMeshInstance2D`.
- **Pros**: Fewest draw calls if `_draw` does not batch.
- **Cons**: Unsourced on 4.7; manual RID lifetime on retry; more code for a solo developer.
- **Estimated Effort**: Much higher.
- **Rejection Reason**: Held as V2's branch, adopted only if V2 shows `_draw` does not batch.

## Consequences

### Positive
- View logic runs headless (order, pools, eviction, clearance, bake, Reduce Motion are unit tests); retry safety is structural; gameplay cannot depend on a view (three allowlisted connections, the rest reads); the per-node budget shows which drawer is over; no engine time, shader compile or particle cost enters the battle.

### Negative
- Every dynamic drawer rebuilds its commands each frame in GDScript; cost unmeasured until V2.
- Two new `Battle` members and a `StageLook` scene contract; ADR-0001, ADR-0005 and the Data GDD's stage-scene wording need edits.
- Stage validation gains a path rule: deflection at most 90 degrees and a per-segment miter-overlap length (Decision 5). The 90 degree cap is a style limit that needs design sign-off; finely sampled curves pass.
- Art bible §8's structure (per-enemy nodes, Line2D path, shader budget) is overridden for MVP.

### Neutral
- Letterbox bars are the engine's clear colour; ADR-0003 SP7 records it and art direction decides.

## Risks

- **`_draw` does not batch** (V2), **no counter counts 2D** (V1), **the line bias is wrong** (V4): each has a branch in its verification item.
- **Step 4 over 3.0 ms with 48 enemies** (A1). Mitigation: Decision 9 levers; ADR-0004's 2.1 ms headroom is not spent without `technical-director`.
- **Flash and death discs drift from the body**: positions update per frame by `spawn_id`; a reaped enemy's flash stays put for at most 120 ms. Accepted.
- **A view keeps a sim object by mistake.** Mitigation: `_draw` reads buffers only; the weakref test runs with all views attached; code review of every model's fields.
- **The geometry limit blocks a stage design.** Mitigation: the 90 degree cap is a style limit; a miter limit or bevel join removes it in `PathOutline` only, with the validator rule changed in the same ADR-0002 edit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-011: the Combat view draws primitives from one `_draw()` per kind with no shaders or particles and a 16-marker flash pool on the frame clock | Decision 1 (CombatView), 4 (16 markers, Combat eviction order), 7 (zero shaders and particles), 8 (`view_ms`) |
| enemy-wave.md | TR-enemy-015: views read `roster()` and the path each frame; fixed three-pass draw order; a view pool of at least 48 that grows with a dev error; Reduce Motion honoured | Decisions 2 and 3 (poll in step 4, copies only), 4 (48 slots, grow plus one `dev_error`), 5 (path from `path_points`), 8 (Reduce Motion); EnemyView draws heavy, normal, fast, each in `spawn_id` order |
| tower-system.md | TR-tower-015: all towers draw from one `_draw()` node with primitive polygons, level inset and a cooldown ring, with Reduce Motion fallbacks | Decision 1 (TowerView), 3 (slot reads plus the cooldown total through the accessor at use time), 8 (Reduce Motion) |
| battle-hud.md | TR-hud-001: HudLogic (plain), HudTopBand (display-only Controls), HudField (one `_draw`, targets as resolver discs), absent headless, rebuilt on retry | Decision 1 (HudField `Node2D`, HudTopBand `Control` with `MOUSE_FILTER_IGNORE`); models in the wrapper only; retry rebuilds the wrapper (ADR-0001 Decision 7) |
| hero-system.md | No TR covers hero visuals (TR-hero-001 to TR-hero-015 checked; TR-hero-008 is the P6/P7 emit rule) | HeroView's place in the order (Decision 1), glow texture (Decision 7) and ceiling (Decision 9) serve the Hero GDD's V/A table; `/architecture-review` may register a TR |
| battle-hud.md | TR-hud-015: HUD about 8 (max 12) of 60 draw calls, at most 3 text draws; hit targets at least 72 units, text at least 21 units | Decision 9 (HUD ceiling 12, expected 8; text at 21, 24, 36 only), Implementation Guidelines (72-unit targets), V1, V2, A1 |

## Performance Implications
- **CPU**: Per frame, one roster pass in each of three models (48 entries), 16 marker lookups, up to a few hundred `draw_*` commands. Inside ADR-0004's 3.0 ms step 4 slice; unmeasured until V2 and A1.
- **Memory**: Packed buffers of a few KB per model; two baked path arrays; one 128x128 glow texture. Well under the 256 MB and 16 MB texture ceilings.
- **Load Time**: One stage-scene instantiate and two path bakes in `attach`; under a millisecond expected, unmeasured.
- **Network**: None.

## Migration Plan

No view code exists; spike and concept prototype views are not migrated. First stories: `ViewStyles` and `PathOutline` with tests, then EnemyView and CombatView (the budget risk).

**Rollback plan**: If V2 fails, the V2 branch replaces the bodies of EnemyView and CombatView `_draw`; models, order and pools stay. If the per-kind structure itself fails A1, the first lever merges drawers without touching models.

## Validation Criteria

1. Unit (headless, ADR-0007 harness): EnemyViewModel orders heavy, normal, fast, then `spawn_id`; growing past 48 calls `dev_error` once; FlashPool follows Combat's eviction cases; clearance suppresses tower flashes and splash rings from `burst_started` to 0.15 s after the BURST `attack_fired`; `PathOutline.bake` returns exact square corners for the starter path (within 1e-9) and empty for a 120 degree deflection and for a segment shorter than `(w / 2) * (tan(d_a / 2) + tan(d_b / 2))` (and non-empty just above it); a quarter circle of radius 200 sampled at 16 points bakes at width 96; the same rule rejects and accepts the same fixtures in ADR-0002's validator; each Reduce Motion row both ways; `view_ms` 0 freezes every clock.
2. Weakref test (ADR-0001) repeated with every model attached and refreshed once, then `detach()`.
3. Integration content test: every Stage bakes, every `scene_ref` loads a `StageLook` within range, every `visual_key` has a `ViewStyles` entry.
4. Code review: no drawer calls a sim query; lint rows REND-1 to REND-3 (cascade) once ADR-0007 adds them.
5. Visual: retained screenshots in `production/qa/evidence/` for each GDD's manual list (Combat, Enemy & Wave, Tower, Battle HUD).
6. V1 to V6 recorded before acceptance; A1 within Decision 9 after it.

## Related

- Depends on ADR-0009 (roster, positions, Combat reads) and ADR-0010 (read surface, `ResultSnapshot`). Binding: ADR-0001 (attach, detach, Reduce Motion), ADR-0003 (stretch, no camera, modal Controls), ADR-0004 (step 4, no interpolation, cosmetic randomness, 3.0 ms), ADR-0006 (P7 to P9, listener rules), ADR-0007 (SCENE-1, M7, harness).
- Amends: ADR-0002 (Stage path-drawability rule and content checks), ADR-0001 and ADR-0005 (two `Battle` members), ADR-0006 (P4 and P6 polled), art bible §8 (structure and shader budget). Resolves QQ-10 and the draw-call half of QQ-11.
- `design/gdd/combat-damage.md`, `enemy-wave.md`, `tower-system.md`, `battle-hud.md`, `hero-system.md` (Visual/Audio Requirements); `design/art/art-bible.md` §3, §4, §6, §7, §8.
