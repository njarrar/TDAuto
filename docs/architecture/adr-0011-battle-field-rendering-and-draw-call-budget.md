# ADR-0011: Battle Field Rendering and Draw-Call Budget

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer in an autonomous run (no questions asked; every open point is a Verification row). Reviewed 2026-11-05 by godot-specialist (BLOCK: 3 blockers, 8 minors) and technical-director (CONCERNS: 7 concerns, 5 advisories); every finding was applied in the same day's fix round (draw-primitive rule from the windowed probe, tint on the field base, glow, modals inside the 12-call cap, DangerRule, kill styling from `damage_applied`). A re-review of the revised ADR is still owed before Acceptance. Fix round 2026-11-05 after architecture-review-2026-11-05 (items applied: C1 observer row cross-reference, D2, D3, D4, D11, Depends On ADR-0001 and ADR-0007). Fix round 2 2026-11-05 after architecture-review-2026-11-05b (items applied: K1 Depends On no longer lists ADR-0007, which stays under Delegates To; E1 step b order and step letters follow ADR-0004; V1 logs the rendering driver).

## Summary
Presentation leaves open how the battle field is drawn, how many draw calls it may cost, how the HUD decides to redraw, and how outcomes tint the field. This ADR makes every field view one node with one `_draw` (enemy, tower, combat, path, hero, `HudField`), turns the "pools" into slot arrays inside those draws rather than into nodes, fixes the redraw key as a pure merge plus a shared quantiser, places the view-model refresh after the ticks, and carries the clearance window, the outcome tint, the no-shader hit flash, the no-interpolation policy and the evidence naming. The 60-call budget stays provisional until a device run.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (pinned; 4.7.2 installed at pin time) |
| **Domain** | Rendering |
| **Layer** | Presentation |
| **Knowledge Risk** | HIGH (VERSION.md: 4.7 is post-cutoff); architecture table rates Rendering (2D, Mobile) MEDIUM |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `prototypes/adr-0011-probe/output-review.txt` (windowed, Mobile renderer), `modules/rendering.md` (4.7: `CanvasItem` lines lose the antialiasing feather; MSAA 2D listed as an option; no 2D batching text), `breaking-changes.md:31` (widen lines that relied on the old thickness), `current-best-practices.md:76`; ADR-0003 Decision 9, ADR-0004 Decisions 6 and 8, ADR-0006 Decisions 5 and 10, ADR-0009 Decisions 2 and 6; art bible §2 and §8; the probe table below (4.7.2 probe, 2026-11-05, `prototypes/adr-0011-probe/`; P and Q rows desktop headless, R rows windowed on desktop with `--rendering-method mobile` in `output-review.txt`; the same counts on an Android device are owed, V1) |
| **Post-Cutoff APIs Used** | None new. `CanvasItem.draw_arc` / `draw_polyline` / `draw_colored_polygon` are pre-4.7; their 4.7 line look is the open point (V3) |
| **Verification Required** | See the Verification table: the same draw-call counts on an Android device and one `Label` = one call (V1), line width and antialiasing look (V3), MSAA 2D on the Mobile renderer (V14), views and HUD at 3.0 ms (V9), judder at 30, 60, 90 and 120 Hz (V5), art-director rows V11 to V13 |

### Probe results (4.7.2 probe, 2026-11-05, `prototypes/adr-0011-probe/`; outputs `output.txt`, `output2.txt` desktop headless; `output-review.txt` windowed desktop, Mobile renderer; `output3.txt` headless)

| # | Claim | Result |
|---|---|---|
| P1 | `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` exists headless | Callable; returns `0` (no frame is drawn). The enum value is 2; `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (13) is the profiler monitor |
| P2 (superseded by T1) | Tint maths on `(0.4, 0.6, 0.8)`: luminance 0.5719; 60% desaturation `c.lerp(Color(l,l,l), 0.6)` = `(0.5032, 0.5832, 0.6632)`; `.darkened(0.04)` = `(0.483, 0.5598, 0.6366)`; `c.lightened(0.04)` = `(0.424, 0.616, 0.808)` | As computed; `darkened(a)` scales RGB by `1-a`, `lightened(a)` moves each channel `a` of the way to 1 |
| P3 | `Color.BLACK.lerp(Color.WHITE, 0.25)` | `(0.25, 0.25, 0.25, 1)` |
| Q1 | `PackedInt32Array` `==` / `!=` compare contents | `[1,2,3]==[1,2,3]` true; `[1,2,3]==[1,2,4]` false |
| Q2 | Signatures from `ClassDB` | `draw_arc(center, radius, start_angle, end_angle, point_count, color, width, antialiased)`; `draw_polyline(points, color, width, antialiased)`; `draw_circle(position, radius, color, filled, width, antialiased)`; `draw_colored_polygon(points, color, uvs, texture)`; `draw_string(font, pos, text, alignment, width, font_size, modulate, ..., oversampling)`. The `antialiased` parameter exists; it is not a no-op (R2) and its look is V3 |
| R1 | Windowed, Mobile renderer, draw calls per primitive mix (`output-review.txt`) | `draw_colored_polygon`, `draw_arc` and filled `draw_circle`: one call each (48 of them = 48 calls; 48 polygons plus 48 arcs = 96); `draw_string("123")` one call, 3 objects; 48 `draw_line` = 1 call; `get_rendering_info(...TOTAL_DRAW_CALLS_IN_FRAME)` counts 2D canvas calls (empty frame 0, one primitive 1) |
| R2 | Same run, batching (`output-review.txt`) | 48 `draw_primitive` or `draw_rect` = 1 call; `draw_multiline` batches; `draw_set_transform` between primitives does not break the batch; rect + line + primitive = 3 calls (each change of type is a call); `draw_line(antialiased = true)` emits 18 objects per line against 1, still one call |
| T1 | Tint on the field base, `Color("0B1020")` (V 0.1255, S 0.656), `output3.txt` | Won `from_hsv(h, s, v + 0.04)` = (0.0569, 0.0827, 0.1655); Lost `from_hsv(h, s * 0.4, v - 0.04)` = (0.063, 0.0684, 0.0855); Lost at half ramp = (0.057, 0.0686, 0.1055) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (composition root, wrapper `setup(battle, dev_telemetry)`); ADR-0003 (Accepted or Proposed per its file: Decision 9, one `CanvasLayer` for every HUD Control, only `HudModals` STOP; field units); ADR-0004 (Decision 8 `view_dt`, `VIEW_DT_MAX`; the frame steps); ADR-0006 (view allowlist, polling contract, `modal_changed`); ADR-0009 (`roster()`, `targets()`, `removed`, reused buffers); ADR-0010 (`slot_tapped`, `tower_inspected`, HeroInput reads, `ChipWindow`, `early_call_bonus`). Proposed ones must be Accepted before any story that implements this ADR |
| **Delegates To** | ADR-0007 (lints named in Decision 13; test runner for the pure units); ADR-0010 (the sims' read methods exist as named; input; commands); ADR-0004 (clock, ticks); `technical-artist` / `art-director` (the ring width bias, glyph shapes, tint wording, V3 and V7); `ui-programmer` (HudTopBand Controls) |
| **Enables** | Every Presentation story: HudField, field views, Combat view, hero view, outcome presentation; ADR-0007's evidence items |
| **Blocks** | The first HudField or Combat-view story (architecture.md Required ADRs). Only Decision 11's numbers stay provisional |
| **Ordering Note** | `architecture.md` edits at `/architecture-review` are in the closing sync section. TR-combat-015 and TR-hero-016 were registered at `/architecture-review` on 2026-11-05 |

## Context

### Problem Statement
Eight requirements are waiting on one rendering decision: TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015, TR-hud-017, and TR-combat-015 (clearance) and TR-hero-016 (view clause). Four ADRs delegate here: view classes and handlers (ADR-0006), the frame-clock rule (ADR-0004), judder (ADR-0004), screenshot evidence (ADR-0007). The owner decided on 2026-11-05 that the Defeat and Victory field shifts are in MVP as one tint (hero-system.md:473).

### Constraints
- The battle is a pure function of (catalogue, stage_id, seed, command script). `src/battle/` is `RefCounted` only; views live in `src/presentation/`. No autoloads. Views observe, never steer.
- Views read the HUD read surface (B10) and the ADR-0006 allowlist only; ADR-0006 deliberately has no `enemy_spawned`, `wave_started`, `tower_fired`, `status_applied`, hero-move or `burst_fired` signal.
- 60 fps, 60 draw calls, 256 MB; views and HUD 3.0 ms; HUD about 8 of 60 (max 12); at most 3 text draws (architecture.md §10, proposal, unmeasured).
- Portrait 540x960 field units, stretch `canvas_items`/`keep`, letterbox (ADR-0003). Draw in field units; never in pixels.
- 4.7 `CanvasItem` lines have no antialiasing feather. Art bible §8: everything drawn in code, at most 3 distinct CanvasItem shaders, uniform `modulate` is fine, per-node materials break batching (unverified).

### Requirements
- Enemy view pool of at least 48; flash markers at most 16; fixed three-pass enemy draw order; Reduce Motion honoured.
- HudField redraws on a quantised key and while a timed visual runs, never every frame.
- The redraw key and tint maths testable headless with fakes.
- Outcome presentation, clearance and flashes run on the frame clock (`view_dt`), so Pause freezes them and an outcome does not.

## Decision

**1. One node, one `_draw`, per view kind; entity logic in RefCounted slot objects.** Field nodes under one `FieldRoot` `Node2D`, in `src/presentation/field/`: `PathView` (backdrop rect, path, edge; redrawn on build and on tint change), `TowerView`, `EnemyView`, `CombatView` (flash markers, splash rings, tower fire lines), `HeroView` (hero, leash, reticle, reach ring, kill preview, Ready ticks, **the hero glow and the burst-glow pool of 8**), and `HudField` in `src/presentation/hud/`. The glow is a `GradientTexture2D` sprite drawn with `draw_texture_rect` (art bible §8), so it is a texture draw with its own call (Decision 11); the burst-glow pool is 8 records (`age_left`, position, radius) reusing the same texture. Each node issues its primitives from its own `_draw`, grouped by primitive type (Decision 11); none has a child node per entity and none has a material. "Pool" in TR-enemy-015 and art bible §8 is met as **slot arrays inside `EnemySlots`** (Decision 3), which allocates nothing mid-wave. Alternatives (per-enemy `Node2D`s, one shared node) are under Alternatives.

**2. Z order, back to front in tree order.** `PathView`, `TowerView`, `EnemyView`, `CombatView`, `HeroView` under `FieldRoot`; `HudField`, `HudTopBand`, `HudModals` under the ADR-0003 `CanvasLayer`. No `z_index` is set anywhere (z interleaving breaks batching per art bible §8); tree order is the draw order. Enemy passes inside `EnemyView._draw`: (1) bodies, (2) danger chevrons, (3) health or state marks.

**3. `EnemySlots` (RefCounted) holds the slot table; `EnemyView` only draws it.** `src/presentation/field/enemy_slots.gd` is pure and headless-testable; `EnemyView` (Node2D) owns one and reads its arrays in `_draw`. Parallel arrays sized `ENEMY_SLOTS = 48` (from the stage's `peak_alive_ub`, never below 48): `_slot_id: PackedInt32Array` (0 = free), `_slot_pos: PackedVector2Array`, `_slot_def: Array[StringName]`, `_slot_age: PackedFloat32Array` (view-clock seconds), `_slot_state: PackedByteArray` (LIVE, DYING_KILL, DYING_LEAK), plus `_by_id: Dictionary[int, int]` (spawn_id to slot) and a free-slot stack. **Spawn detection is a roster compare** (no `enemy_spawned`): `sync(roster, view_dt)` iterates `roster()` (the reused buffer is passed in; fields are copied and the array is never stored: ADR-0009:150-151, ADR-0007's no-stored-roster lint). An id absent from `_by_id` acquires a slot (LIVE, age 0); a present id updates `_slot_pos`. A slot whose id was not seen this sync ends: DYING_KILL if `mark_killed(spawn_id)` named it since the last sync, else DYING_LEAK. **Kills are styled from `damage_applied(event, applied, position, killed, spawn_id)`** (ADR-0006 Decision 5; `EnemyView.on_damage_applied` calls `mark_killed` when `killed` is true). `enemy_killed(bounty)` carries no id and its only allowlisted listener is TowerSim, so no view connects to it; `enemy_leaked` carries no id, so a vanished id that was not marked killed is a leak. ADR-0006's two limits hold: an enemy spawned and killed inside one frame never appears in a roster read and gets no slot (its `killed` id is ignored), and a leak has no id. A dying slot keeps its last position for `DYING_SECONDS` of `view_dt` (data, default 0.12 for a kill, 0.0 for a leak). If the stack is empty the table grows by 16, logs through the injected `dev_error`, and continues (an invisible enemy is worse than a hitch; art bible §8). The `removed` skip is redundant by ADR-0009:150 (`roster()` excludes removed enemies) and is kept as one cheap guard. A missed signal can mis-style a death, never leak a slot.

**4. Flash markers.** `CombatView` owns `FLASH_MARKERS = 16` records in `PackedFloat32Array` / `PackedInt32Array` form: `(spawn_id, kind {TOWER, HERO}, age_left, x, y)`. A marker is taken on `damage_applied` (kind from the event's source kind; BURST ranks as HERO). When all 16 are in use the oldest TOWER marker is dropped, else the oldest HERO marker, and a TOWER flash never evicts a HERO flash and is dropped itself (combat-damage.md:158). A flash suppressed by the clearance window takes no marker. A marker draws as a small filled polygon in a lighter shade of the enemy colour for `FLASH_SECONDS` (data) on `view_dt`; damage is unaffected.

**5. Hit flash (QQ-10): none, no shader.** The flash is a polygon that `CombatView` draws, not a `modulate` or a shader on a pooled node, because no enemy node exists (Decision 1). This removes the hit-flash shader from art bible §8's three-shader allowance; the other two (chevron pulse, outline) stay allowed but this ADR uses neither, so the MVP scene has **zero** shaders. Closes QQ-10; the Combat GDD already uses none. A marker beside the body versus the body drawn in the flash colour (no extra call, since the body is already a `draw_primitive` run) is an art-director call (V13).

**6. `ClearanceWindow` (TR-combat-015).** (HudLogic's path, deferred here by ADR-0010: `src/presentation/hud/hud_logic.gd`, with `HudField`, `HudTopBand` and `HudModals` beside it as `hud_field.gd`, `hud_top_band.gd`, `hud_modals.gd`.) A `RefCounted` in `src/presentation/field/clearance_window.gd` (with the views), advanced by `advance(view_dt)` from the wrapper (ADR-0004 step b). Rules: `burst_started` opens it (open, no tail yet). The next BURST `attack_fired` (it fires even for an empty burst) is the release and starts a tail of `CLEARANCE_TAIL_SECONDS` (data, 0.15, owned by Hero's Visual Requirements). `advance` runs the tail down and closes at 0. If a `phase_changed` to WON, LOST or FATAL arrives while open and not released, the window closes at once; a `phase_changed` to anything else, **Paused included**, is ignored; once released, an outcome does not stop the tail (frame clock). Paused freezes the tail because `view_dt` is 0. While `is_open()`, `CombatView` suppresses tower flashes and splash rings and draws no other gold, glow or expanding ring (the burst stays the brightest thing).

**7. Frame order inside `BattleWrapper._process`** (ADR-0004 fixes the slots; this ADR places the rest):
```
a. view_dt                                   (ADR-0004, 8)
b. HudLogic.advance(view_dt_ms), TowerInput.advance(view_dt_ms), HeroInput.update(),
   RunLog.advance / RunLog.flush (only when dev telemetry is on),
   ClearanceWindow.advance(view_dt), flash timers, tint.advance(view_dt)
   (the order of ADR-0004 Decision 7 step b)
c. Clock.advance(delta)  -> runs the owed ticks itself, each battle.tick(dt); the wrapper has no tick loop
d. refresh, once per frame, after the ticks (this ADR; ADR-0004 step d):
   1. EnemySlots.sync(roster, view_dt), DangerRule.observe(...)  -> sets _dirty if any tick ran, a slot is dying, or a timer runs
   2. TowerView / HeroView / CombatView read their surfaces
   3. bonus = tower_sim.early_call_bonus(seconds_left)    -> read here, after the ticks, never cached across frames
   4. key = HudRedrawKey.merge(...)           -> HudField compares to last key, calls queue_redraw() on change
   5. each field view: if _dirty: queue_redraw()
```
Signal handlers (`on_*`) only set flags or push into the small buffers of Decisions 3 and 4; they never draw and never read the sims. A view never reads the engine delta. Commands from input still run before step a (ADR-0004), so the bonus shown equals the bonus paid (TR-hud-005).

**8. The redraw key (TR-hud-017, reworded).** The key is a `PackedInt32Array` (equality by contents, probe Q1), never a per-frame `Dictionary`. Two pure pieces in `src/presentation/hud/`, no node, no engine call:
- `HudQuantiser`: `static func fill_step(fraction: float) -> int` (`clampi(roundi(fraction * 60.0), 0, 60)`, 1/60 of a turn), `static func seconds_digit(left: float) -> int` (`maxi(ceili(left), 0)`), `static func pos_step(v: float) -> int` (`roundi(v)`, one field unit). Float steps and the quantiser's rounding are tested directly.
- `HudRedrawKey.merge(logic_part: PackedInt32Array, aim_state: int, button_press: int, cooldown_digit: int, aim_cell: Vector2i) -> PackedInt32Array`: concatenates HudLogic's part (fill step, bonus seconds, visible set bits, Locked and burst state, prompt, arming, affordability of each open disc and chip) with HeroInput's reads. HudLogic builds its part with the quantiser; `HudField` holds the previous key and, only if `key != _last`, assigns it and calls `queue_redraw()`. `HudField` also redraws every frame while a timed visual runs (`_timed_visuals > 0`: ground ring fades, range-ring fades, arming, prompt fades), the count owned by HudLogic.
- **Steps per `merge` argument.** `aim_state` and `button_press` are enum ints taken as they are; `cooldown_digit` is the integer HeroInput already derives with `HudQuantiser.seconds_digit`; `aim_cell` is `Vector2i(pos_step(aim_point().x), pos_step(aim_point().y))`, one field unit. Chip state and affordability reach `logic_part` because `HudField` reads chip state through HudLogic's read surface (HudLogic reads `TowerInput.chip_state()` and listens to `tower_inspected`); `HudField` never reads TowerInput directly.
- **Completeness proof.** "Holds every value `_draw` reads" cannot be shown by one key test, so `tests/unit/hud/hud_redraw_key_test.gd` is table-driven: a fixture holds a baseline of every input, the test changes each input one at a time to the next quantum and asserts the key changed, and changes it by less than a quantum and asserts the key is equal. Adding a value to `_draw` without a table row is a review failure (the table lists `_draw`'s reads). Criterion 6 covers HudLogic's part; screenshots keep the rest.

**9. Outcome presentation: `FieldTint`** (hero-system.md:473, decided 2026-11-05; technical-director ruling on the ±4%). Art bible §6 L146 sets the field base value at V 8 to 14% and calls defeat at 4% the darkest field, so the shift is an **offset on the field base Value**, not a scale on every colour. `FieldTint` is a `RefCounted`: `commit(outcome)`, `advance(view_dt)`, `backdrop(base: Color) -> Color`, `glow_scale() -> float`, `is_identity()`, `outcome()`. It commits when the wrapper sees `phase_changed(WON)` or `phase_changed(LOST)` and ramps `t` from 0 to 1 over `TINT_SECONDS` (data, default 0.4, the Won beat) on `view_dt`; Reduce Motion jumps `t` to 1. Won: `Color.from_hsv(h, s, v + 0.04 * t)`. Lost: `Color.from_hsv(h, s * (1 - 0.6 * t), v - 0.04 * t)` (60% desaturation). Golden values from T1: base `#0B1020` gives Won (0.0569, 0.0827, 0.1655) and Lost (0.063, 0.0684, 0.0855) at `t = 1`. `PathView._draw` draws the backdrop rect with `backdrop(stage_base)` as its first run, which also gives the letterbox bars a fixed boundary (Decision 17). Towers, enemies, the path and the HUD keep their colours; whether desaturation reaches the hero and the enemies is an art-director call (V12). **Glow:** `glow_scale()` is 1 for Build, Combat and Won (art bible §2: Victory glow 1) and falls to 0 over the ramp on Lost (Defeat glow 0); `HeroView` multiplies the hero-glow alpha and the burst-glow alpha by it. On Lost `HeroView` draws the hero as a dimmed outline (`outcome() == LOST`); the tower brighten sequence stays deferred past MVP (art bible §2). Retry rebuilds the views and the tint (identity again); "field restores" means this. `FieldTint` runs on `view_dt`, so Paused freezes the ramp.

**10. TR-hero-016's view clause.** The hero view's outcome rows (dimmed outline, reticle and preview teardown) run on `view_dt`, not on a tick or a sim signal, so a Won or Lost commit does not stop them, and the Won 0.4 s beat plays in full. `HudModals` toggles on `modal_changed` only (built once); the field keeps drawing under it, and while a modal is open `HudTopBand` hides its Labels and pips (Decision 12).

**11. Draw-call budget (provisional; the Android device run decides).** The rule, observed on the 4.7.2 Mobile renderer in a windowed desktop run (`prototypes/adr-0011-probe/output-review.txt` R1, R2): `draw_primitive` (3 or 4 points), `draw_rect` and `draw_line`/`draw_multiline` each batch a run of the same type into one call (48 of any = 1 call); `draw_set_transform` between them does not break the run; every change of primitive type starts a new call (rect + line + primitive = 3); `draw_colored_polygon`, `draw_arc` and filled `draw_circle` cost **one call each** and are therefore forbidden in per-entity loops. So each `_draw` is written in type-grouped order, bodies, markers and glyphs are `draw_primitive`/`draw_rect` (circles are precomputed fans of 3-point primitives, about 8 per enemy), rings are segment lists (Decision 13), and a node's calls equal the number of type runs it emits. The glow sprite shares one texture; a run of draws with the same texture and different modulate is assumed to batch (not observed, V1).

| Node | Type runs in draw order | Worst-case calls |
|---|---|---|
| `PathView` | backdrop `draw_rect`; path `draw_primitive`; edge `draw_multiline` | 3 |
| `TowerView` | bodies and level inset `draw_primitive`; state and cooldown rings `draw_multiline` | 2 |
| `EnemyView` | pass 1 bodies and pass 2 chevrons `draw_primitive`; pass 3 marks `draw_multiline` | 3 (one spare for a mark that is a primitive) |
| `CombatView` | flash markers `draw_primitive`; splash rings and fire lines `draw_multiline` | 3 (one spare for an overlay rect) |
| `HeroView` | glow and burst-glow pool `draw_texture_rect` (one texture); kite `draw_primitive`; leash, reticle, reach ring `draw_multiline` | 4 (3 plus one spare if burst glows interleave) |
| `HudField` | fills and glyph digits (`draw_rect`/`draw_primitive`), then rings `draw_multiline`, split by z | 8 (cap 12) |
| `HudTopBand` | 3 `Label`s (gold, lives, next-wave) and one pip `Control` | 4 |
| `HudModals` | hidden while playing; open: at most 4 calls and 3 text draws, with the band hidden (Decision 12) | 0 in play |
| **Total in play** | 15 field + 8 HudField + 4 band | **27** of 60 (33 spare) |
| **Modal open** | 15 field + 8 HudField + 4 modal | **27** |

The HUD share is `HudField` 8 plus band or modal 4 = **12, the cap**, not the GDD's expected 8; that is the first number to measure on the device (battle-hud.md:372 expects 8). Measurement: `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` counts 2D canvas calls on the Mobile renderer in a windowed run (R1), read once a second by a dev-only overlay and cross-checked with `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (P1). First count on desktop; the same counts on an Android device and the cost of one `Label` (outline, shadow, atlas pages) are V1. The numbers stay provisional until V1 closes.

**12. Text and digits: at most 3 text draws; modals inside the cap.** The 3 are the `HudTopBand` `Label`s (gold, lives, next-wave line). Every digit inside the field (burst cooldown digit, bonus seconds, chip and arc costs of up to 3 digits) is drawn as pre-built glyph polygons from a `DigitGlyphs` table (`PackedVector2Array` of 3-point primitives per digit 0 to 9, built once, scaled in the draw), not `draw_string`. The reason is the project's 3-text cap: one `draw_string("123")` is one call (R1), but four to six digit sites would exceed three text draws. The cost is glyph design (HQ-12 asks for "a polygon plus digits in 56 px") and legibility at 21 units (V11). **Modals** count inside the 12 calls and the 3 text draws (battle-hud.md:372, 450; no GDD edit): while a modal is open (`modal_changed`) `HudTopBand` hides its three Labels and its pips, so the modal's at most 3 Labels (title, body, button caption) take those text slots and its at most 4 calls take the band's 4; `HudField` keeps drawing. The earlier 8-call Result figure is withdrawn; V1 counts the Result and Paused frames.

**13. Rings and arcs without a feather, as segment lists.** `draw_arc` and `draw_polyline` per ring cost one call per ring (R1), so no ring uses them. Each ring radius class has a precomputed `PackedVector2Array` of segment pairs (fixed segment count per radius, a table, never computed per frame); a `_draw` emits **one `draw_multiline` per colour group** with `ring_width_bias` added to the GDD width (a data constant; breaking-changes.md:31 says widen lines that relied on the old thickness; the amount is not sourced, default 1.0, tuned at the first screenshot). Several rings of one colour share the call by concatenating their pairs into one array per refresh. Filled shapes are `draw_primitive` fans. `antialiased` is passed `false` explicitly: it is not a no-op in 4.7.2 (an antialiased line emits 18 objects against 1, R2), so the choice is deliberate and the look is V3. If the device look is rejected the fallback is MSAA 2D, whose existence for the Mobile renderer's 2D canvas and Android cost are NOT SOURCEABLE (V14), not a shader.

**14. Judder: no interpolation at MVP.** With ticks at 60 Hz and `view_dt = min(delta, 0.1)`, a frame may carry 0 or 2 ticks (jitter at 60 Hz, or a 90 or 120 Hz display), shown as a one-tick step in enemy positions (ADR-0004 Consequences). **On the 30 fps Android floor every frame carries 2 ticks, 1 to 3 under jitter, so the visible step doubles to two ticks.** Views draw `position` as read. Rationale: interpolating needs `Clock.alpha()`, a previous position per slot (48 `Vector2`s, a memcopy per sync) and draws the world one tick (16.7 ms) late, which costs input-to-result latency in a game whose hero aim is the whole fun. Enemy speeds are low, so a step is a fraction of an enemy radius at 60 fps; V5 measures it at 30, 60, 90 and 120 Hz, and 30 fps is the worst case. If adopted it is a change to `EnemySlots.sync` only.

**15. Evidence.** Screenshots are retained in `production/qa/evidence/` as `<story-id>_<screen>_<yyyy-mm-dd>[_<device>].png`: story id as in the story file (e.g. `HUD-003`), `<screen>` kebab-case from the closed list `build-empty`, `build-arc-open`, `build-chip-open`, `wave-48-enemies`, `burst-clearance`, `paused`, `won-tint`, `lost-tint`, `result-won`, `result-lost`, `letterbox-ultrawide`; a repeat the same day adds `_2`. Capture is a dev-only `EvidenceCapture` (`src/presentation/dev/`) whose name builder `evidence_name(story_id, screen, date_iso, device) -> String` is a pure function, unit-tested; the image save (`get_viewport().get_texture().get_image()`) needs a windowed run (V8). Manual-evidence items that are ADR-0011's (added to ADR-0007 Decision 11): the per-screen draw-call counts above; views and HUD frame time; line width and antialiasing look; judder at 60, 90 and 120 Hz; the two tints against art bible §2; the clearance window with a 16-flash storm; letterbox at an ultrawide aspect.

**16. `DangerRule` (Enemy & Wave criterion 57, delegated by ADR-0009).** A pure `RefCounted` in `src/presentation/field/danger_rule.gd`, `now` injected, fed by `view_dt` sums kept by the view (no engine clock). `observe(now: float, nearest_remaining: float, lives_fell: bool) -> void` sets the trigger time when `nearest_remaining <= DANGER_DISTANCE` (240 field units, data) or when lives fell; `is_danger(now: float) -> bool` is true while `now - last_trigger < DANGER_HOLD` (1.5 s, data), so true at 1.49 s and false at 1.5 s; `on_outcome()` (Won or Lost) clears it and latches it off. An enemy at 240 triggers and one at 241 does not. `EnemyView` draws the pass-2 chevrons only while `is_danger(now)`. Paused (`view_dt` 0) freezes it.

**17. Letterbox clip rect: none.** ADR-0003 L385 delegates a clip rect here. Decision: no clip rect. The letterbox bars are the stretch's own (`canvas_items`/`keep`), the field backdrop rect is exactly 540x960 field units, and views draw only inside field units by contract. The retained `letterbox-ultrawide` screenshot (Decision 15) is the evidence and ADR-0003 Decision 6 owns the check.

### Architecture Diagram
```
BattleWrapper._process
  a/b real-time models ──► ClearanceWindow, FieldTint, flash timers (view_dt)
  c/d ticks ───────────────► Battle (RefCounted sims)
  e refresh (read-only)
      roster() ──► EnemySlots ──► EnemyView._draw (3 passes)
      slot_count()/tower_at() ──► TowerView      Combat signals ──► CombatView (16 markers) ◄─ ClearanceWindow
      HeroInput/HeroSim ──► HeroView  phase_changed WON/LOST ──► FieldTint (backdrop, glow_scale)
      HudLogic part + HeroInput ──► HudRedrawKey.merge ──► HudField.queue_redraw (on change)
CanvasLayer: HudField, HudTopBand (3 Labels + pips), HudModals (toggle on modal_changed)
```

### Key Interfaces
```gdscript
class_name HudQuantiser extends RefCounted
static func fill_step(fraction: float) -> int          # 0..60
static func seconds_digit(left: float) -> int          # >= 0, ceil
static func pos_step(v: float) -> int

class_name HudRedrawKey extends RefCounted
static func merge(logic_part: PackedInt32Array, aim_state: int, button_press: int,
		cooldown_digit: int, aim_cell: Vector2i) -> PackedInt32Array

class_name ClearanceWindow extends RefCounted
func _init(tail_seconds: float) -> void
func on_burst_started() -> void
func on_burst_released() -> void                       # next BURST attack_fired
func on_outcome_phase() -> void                        # WON, LOST or FATAL only
func advance(view_dt: float) -> void
func is_open() -> bool

class_name FieldTint extends RefCounted
func _init(seconds: float, reduce_motion: bool) -> void
func commit(outcome: int) -> void                      # WON or LOST; later calls ignored
func advance(view_dt: float) -> void
func backdrop(base: Color) -> Color                    # field base Value offset (Decision 9)
func glow_scale() -> float                             # 1, or falling to 0 on Lost
func is_identity() -> bool
func outcome() -> int

class_name DangerRule extends RefCounted
func observe(now: float, nearest_remaining: float, lives_fell: bool) -> void
func is_danger(now: float) -> bool
func on_outcome() -> void

class_name EnemySlots extends RefCounted
func sync(roster: Array[Targetable], view_dt: float) -> void   # reads, never stores roster
func mark_killed(spawn_id: int) -> void                        # from damage_applied(killed)
```
`EnemyView extends Node2D` owns an `EnemySlots`, connects `damage_applied` only, and draws. Its row in the Observer allowlist lives in ADR-0006 Decision 5 (`damage_applied`: Combat view, EnemyView, audio (Alpha)); ADR-0011 adds no observer the table lacks.

### Implementation Guidelines
- Each field view must be a single `Node2D` with one `_draw`, and must never create a child node per entity or set a material, a shader, a `z_index` or per-entity `modulate`.
- A view must never call a sim method that mutates, never hold a reference to a sim in a field that outlives the battle, and must listen only to the ADR-0006 allowlist.
- Views must receive `view_dt` from the wrapper and must never read the engine delta, `Time` or `Engine`; they must never be driven by a tick for the duration of a visual.
- `roster()` and `targets()` results must never be stored; copy fields into the slot arrays each refresh.
- `early_call_bonus(seconds_left)` must be read after the ticks of the same frame and never cached across frames.
- `HudField` must call `queue_redraw()` only when `HudRedrawKey` changed or a timed visual runs; field views only when `_dirty`.
- Every numeric visual constant (flash seconds, tail, tint seconds and amounts, ring width bias, slot counts, dying seconds) comes from the catalogue or the HUD record, never a literal.
- Field `_draw`s must use `draw_primitive` (3 or 4 points), `draw_rect`, `draw_line`/`draw_multiline` and `draw_texture_rect`, grouped by type, and must never call `draw_colored_polygon`, `draw_arc` or filled `draw_circle` in a per-entity loop.
- Views must never connect to `enemy_killed` or `enemy_leaked`; kills come from `damage_applied(killed, spawn_id)`.
- Digits inside the field must be glyph polygons; only `HudTopBand` draws text.

## Alternatives Considered

### Alternative 1: One pooled `Node2D` per enemy (and per tower, flash)
- **Description**: 48 enemy nodes, 16 flash nodes, each with `modulate` for the flash.
- **Pros**: Closest to the engine's idioms; per-node `modulate` makes the flash trivial.
- **Cons**: 48 + 16 + towers = 70 or more CanvasItems, above the 60-call budget: the probe shows one call per `draw_colored_polygon` or filled circle (R1), and per-node items batch only if nothing breaks the run (V1); pool bookkeeping lives in the scene tree; every position change touches a node.
- **Rejection Reason**: Cannot be shown to fit 60 calls; the slot design costs at most 3 calls per kind.

### Alternative 2: One single-draw node for the whole field
- **Description**: One `FieldCanvas` draws path, towers, enemies, flashes and hero.
- **Pros**: Fewest items (1), simplest ordering.
- **Cons**: Any change redraws everything, including the static path polygon; the 3.0 ms slice is spent every frame; views lose their separate owners and tests.
- **Rejection Reason**: Redraw cost is not proportional to what changed; separate kinds keep `PathView` static.

### Alternative 3: A hit-flash shader (art bible §8)
- **Description**: One `ShaderMaterial` on the enemy layer with a flash uniform.
- **Pros**: Matches the art bible budget line.
- **Cons**: A material on a single-draw node flashes all or none; per-enemy flash needs a per-instance uniform, i.e. nodes; shaders break batching and need device warm-up.
- **Rejection Reason**: Not needed by any GDD; the polygon marker does the job (Decision 5).

### Alternative 4: `draw_string` for field digits
- **Description**: Use the theme font for cooldown digit, bonus and costs.
- **Pros**: No glyph table; accessible scaling.
- **Cons**: Up to 6 text sites against a cap of 3 (one `draw_string` is one call, R1; the cap is the reason).
- **Rejection Reason**: Decision 12.

### Alternative 5: Interpolate enemy positions between ticks
- **Description**: Lerp between the last two tick positions with `acc / dt`.
- **Pros**: Smooth on 90 and 120 Hz.
- **Cons**: One tick of latency, extra state, a wrapper API.
- **Rejection Reason**: Decision 14; kept as a V5 follow-up.

## Consequences

### Positive
- 27 worst-case calls leaves 33 of 60 spare, with 10 scene items.
- Zero shaders and zero particles in MVP; nothing to warm up.
- The redraw key, quantiser, clearance window, tint and evidence name are pure units tested headless with fakes.
- A missed signal cannot leak a view slot (roster compare is authoritative).

### Negative
- The Alpha view code is custom `_draw`: no editor preview of enemies, flashes or rings.
- Digit glyphs are art work (7 to 10 polygons) and lose font scaling.
- The HUD sits at the 12-call cap by design; one added HUD element needs a measured saving elsewhere.
- Circles are 8-triangle fans, about 384 `draw_primitive` calls from GDScript per enemy redraw (V9).
- No interpolation: judder is accepted until V5.

## Risks
- **Batching differs on an Android device (V1).** Mitigation: the table is a count of type runs observed on desktop; it fits even at double (about 54), and the type-grouping rule is a lint.
- **Aliased lines look wrong on a phone (V3).** Mitigation: `ring_width_bias` is data; fallback MSAA 2D (V14).
- **Same-frame spawn-death or a missed `damage_applied`.** Mitigation: ADR-0006's two limits are stated in Decision 3; only the death style is lost, never a slot.
- **The HUD at the 12-call cap.** Mitigation: it is the first number measured (V1).
- **Redraw key misses a value `_draw` reads.** Mitigation: the table-driven test and review rule; screenshots.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-damage.md | TR-combat-011: one `_draw` per kind, no shaders or particles, 16-marker flash pool on the frame clock | Decisions 1, 4, 5 |
| combat-damage.md | TR-combat-015: burst clearance from `burst_started` to 0.15 s after release | Decision 6 |
| enemy-wave.md | TR-enemy-015: roster and path read each frame, fixed three-pass order, pool of at least 48 growing with a dev error, Reduce Motion | Decisions 2, 3 |
| tower-system.md | TR-tower-015: one `_draw` node, primitive polygons, level inset, cooldown ring, Reduce Motion fallbacks | Decisions 1, 13 |
| hero-system.md | TR-hero-016: view clause, outcome rows on the frame clock; hero-system.md:473 field shift | Decisions 9, 10 |
| battle-hud.md | TR-hud-001: HudField one `_draw`, HudTopBand display-only, HudModals built once | Decisions 1, 2, 10 |
| battle-hud.md | TR-hud-015: about 8 (max 12) of 60 draw calls, at most 3 text draws, modals inside (L372, L450) | Decisions 11, 12 |
| enemy-wave.md | Criterion 57: danger rule, 240 units, 1.5 s, `now` injected, ends on Won or Lost | Decision 16 |
| battle-hud.md | TR-hud-017 (reworded): quantised redraw key over every value `_draw` reads | Decision 8 |

## Performance Implications
- **CPU**: Views and HUD target 3.0 ms (unmeasured). The enemy sync is O(roster) with 48 dictionary lookups, and a redraw issues about 384 `draw_primitive` calls from GDScript; `HudRedrawKey.merge` allocates one small `PackedInt32Array` per frame (the only per-frame allocation, V9).
- **Memory**: About 48 slots of under 40 bytes each, 16 markers, 8 burst glows, the glyph and ring tables, a few KB, plus one small `GradientTexture2D` for the glow.
- **Load Time**: Glyph and ring tables built once at construction. No shader compile.
- **Network**: None.

## Migration Plan
Greenfield. Order of stories: `HudQuantiser` and `HudRedrawKey` with the table test; `ClearanceWindow`; `FieldTint`; `DangerRule`; `EnemySlots` with a fake roster; then the nodes; then the device run for V1 to V11.

## Validation Criteria
- The completeness table test fails when any `_draw` read is added without a row.
- A scripted 48-enemy wave leaves no live slot after the last reap, and an exhaustion test grows once with one `dev_error`.
- Clearance tests: the three closing cases and the Paused case of Decision 6.
- `FieldTint` golden values from T1 at `t = 1` and `t = 0.5` for base `#0B1020`; `DangerRule` at 240 / 241 and 1.49 s / 1.5 s; `EnemySlots` kill, leak and same-frame cases.
- Device: total draw calls in the worst screen at or under 60 (target 26), views and HUD at or under 3.0 ms.

## Verification

| # | Claim | Status | Check | Pass when |
|---|---|---|---|---|
| V1 | NOT SOURCEABLE: the same draw-call counts on an Android device (desktop Mobile renderer observed, R1, R2); one `Label` is one call (outline, shadow, atlas pages); a run of `draw_texture_rect` calls sharing one texture batches | Open (desktop observed) | Windowed desktop count per evidence screen first, then an Adreno 5xx-class phone; count the Result and Paused frames; log `RenderingServer.get_current_rendering_driver_name()` and the `rendering/renderer/rendering_method` in use, since an Adreno 5xx may fall back to the Compatibility renderer, whose batching differs | At or under 60 on the worst screen; HUD at or under 12 |
| V2 | Consecutive same-type primitives batch into one call, `draw_set_transform` does not break the run | Observed, 4.7.2 probe, 2026-11-05, prototypes/adr-0011-probe/output-review.txt (R2); desktop windowed, Mobile renderer | Re-run `probe4.gd` | 1 call for 48 `draw_primitive` |
| V3 | What `ring_width_bias = 1.0` looks like with `antialiased = false` on a phone | Open (`antialiased` is not a no-op, R2) | Screenshot of every ring | art-director accepts, or MSAA 2D decided |
| V4 | NOT SOURCEABLE: an unchanged `_draw` is not re-run and its retained commands are resubmitted without a script cost | Open | Profiler with a static scene | No `_draw` call between key changes |
| V5 | Judder at 30, 60, 90 and 120 Hz is acceptable without interpolation; 30 fps (2 ticks per frame, 1 to 3 under jitter) is the worst case | Open | Playtest plus a frame log of ticks per frame | Owner accepts, else adopt Decision 14's alternative |
| V6 | `damage_applied(event, applied, position, killed, spawn_id)` and `attack_fired(source_kind, ...)` carry the id and kind; `enemy_killed(bounty)` carries no id | Closed: confirmed for `damage_applied` and `attack_fired`, denied for `enemy_killed` (ADR-0006 Decision 5; godot-specialist review 2026-11-05) | None | Views connect to `damage_applied` only |
| V7 | "Base ±4%" is an offset on the field base Value (art bible §6 L146) | Ruled by technical-director, 2026-11-05; T1 | art-director confirms the wording in §2 | Wording matches |
| V8 | NOT SOURCEABLE: `get_viewport().get_texture().get_image().save_png` captures the letterboxed frame on a device | Open | One windowed capture | File written, correct size |
| V9 | Views and HUD at or under 3.0 ms, including the per-frame key allocation and about 384 `draw_primitive` calls | Open | Profiler, 48 enemies | p99 at or under 3.0 ms |
| V10 | `PackedInt32Array` equality compares contents | Observed, 4.7.2 probe, 2026-11-05, prototypes/adr-0011-probe/ (Q1) | Re-run `probe2.gd` | `true` / `false` |
| V11 | Digit glyph polygons are legible at 21 units under a thumb | Open | Screenshot, art-director | Accepted |
| V12 | Whether Defeat desaturation reaches the hero and the enemies, or only the field base (art-director call) | Open | art-director | Decision recorded in art bible §2 |
| V13 | Flash marker beside the body versus the body drawn in the flash colour (art-director call; same call count) | Open | art-director | One chosen |
| V14 | NOT SOURCEABLE: MSAA 2D applies to the Mobile renderer's 2D canvas, its project-setting name, and its Android cost (rendering.md:51 lists it as a settings bullet only) | Open | Windowed run with the setting on, then a phone | Cost within the 3.0 ms slice, or dropped |
| V15 | Pre-built glyph and ring tables keep the per-redraw cost within V9 | Open | Profiler | Within V9 |

## GDD and Registry Sync at Acceptance

Applied 2026-11-05 at acceptance; items not applied are listed below.

- Not applied: `tr-registry.yaml` TR-combat-011, TR-enemy-015, TR-hud-017: held for the TR-registry pass (another owner).
- Not applied: `design/art/art-bible.md` (V7, V12, V13): routed to the art-director.
- Not applied: `design/gdd/hero-system.md`, `design/gdd/enemy-wave.md` and `design/ux/hud.md` items: held for the GDD and UX pass (another owner).


Edits owed when this ADR moves to Accepted (recorded 2026-11-05 from the drafting sync list; line numbers are as of that date):

- docs/architecture/architecture.md:24 (Rendering risk row): "The 60 draw-call budget is a proposal, not measured." -> add "ADR-0011 targets 27 worst-case calls by type run (observed on a desktop Mobile renderer); the Android count is unmeasured (V1)"
- docs/architecture/architecture.md:153-154 (HudField, HudModals rows): "redrawn on a quantised key and while a timed visual runs" -> add "`HudQuantiser` and `HudRedrawKey.merge` (ADR-0011 Decision 8)"; Field views row (line ~158): "Pools, draw order, flash markers (16 max), enemy view pool (at least 48)" -> "One `_draw` node per kind; slot arrays in `EnemySlots`; flash markers (16 max); `ClearanceWindow`, `FieldTint`, `DangerRule` (ADR-0011)"
- docs/architecture/architecture.md:218 (Data Flow 1, step 4): "Refresh views from read-only queries" -> "Refresh after the ticks (ADR-0011 Decision 7): roster compare, `early_call_bonus` read, redraw key, `queue_redraw`"
- docs/architecture/architecture.md:337-348 (Frame budget): add "27 worst-case calls by node (ADR-0011 Decision 11), HUD at the 12 cap, provisional"
- docs/architecture/architecture.md:593 (TR-hud-017 row): add "key type `PackedInt32Array`; `HudRedrawKey.merge`; table test (ADR-0011 Decision 8)"
- docs/architecture/architecture.md:660-670 (ADR-0011 entry) and :696 (QQ-10): entry "Decides ..." -> "Decided; Status Proposed"; QQ-10 -> "Closed: no shader, polygon markers (ADR-0011 Decision 5; art-director V13)"
- docs/architecture/architecture.md:10 (TR counts; applied 2026-11-05): register TR-combat-015 and TR-hero-016 at /architecture-review, with the Decision 6 and 10 text
- docs/architecture/tr-registry.yaml:446 (TR-combat-011), :572 (TR-enemy-015), :915 (TR-hud-017): "a 16-marker flash pool" -> "a 16-marker flash pool drawn by the Combat view, no shader"; "a view pool of at least 48" -> "a slot array of at least 48 inside the single enemy `_draw`"; "a quantised view-model key" -> "a quantised `PackedInt32Array` key from `HudRedrawKey.merge`"
- design/art/art-bible.md:192 and :194 (route to art-director, not a direct edit): "Max 3 distinct CanvasItem shaders per scene (hit flash, chevron pulse, outline)" -> "MVP uses none; the hit flash is a polygon marker (ADR-0011 Decision 5)"; "Pool ... 48 enemies, 16 hit-flash markers" -> "slot arrays in single-draw nodes"; also route V12 and V13, and the §2 wording of the ±4% as a field-base Value offset (V7)
- design/gdd/hero-system.md:473 (open question): "ADR-0011 carries the tint as a view value" -> "carried by ADR-0011 Decision 9"
- design/gdd/enemy-wave.md:458 (criterion 57): add owner note "the pure rule is `DangerRule`, ADR-0011 Decision 16"
- docs/architecture/adr-0007-headless-test-harness-gdunit4-and-layer-lint.md:118 (Decision 11): "file naming and screenshot capture are ADR-0011's" -> "naming `<story-id>_<screen>_<yyyy-mm-dd>[_<device>].png` and the items of ADR-0011 Decision 15"; add a lint that no `draw_colored_polygon`, `draw_arc` or filled `draw_circle` appears in a loop under `src/presentation/field/`, and that no field view sets a `material`, `z_index` or per-entity `modulate`, or connects to `enemy_killed`
- design/ux/hud.md:151 (Redraw and modal visibility): add "key and quantiser per ADR-0011 Decision 8"
- design/gdd/battle-hud.md:372 and :450: no edit (modals count inside the 12 calls and 3 text draws; ADR-0011 Decision 12 complies)
- docs/registry/architecture.yaml: registry entries (interfaces, api_decisions, forbidden_patterns, performance_budgets) are merged at commit
