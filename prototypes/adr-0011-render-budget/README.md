# ADR-0011 render budget (V1 to V5, desktop leg)

PROTOTYPE - NOT FOR PRODUCTION. A small standalone Godot 4.7 project. Nothing in
`src/` may load or copy from it.

## What it tests

ADR-0011 (`docs/architecture/adr-0011-battle-field-rendering-draw-call-budget.md`),
Engine Compatibility, Verification items V1 to V5. V6 is headless and already
recorded by `prototypes/adr-checks/`. V1, V2 and V4 also need a phone run
later (it can share the ADR-0003 device spike session).

Hypothesis: on the Mobile renderer, untextured `_draw` primitives in one node
with no material batch into a few draw calls; at least one in-engine counter
counts 2D canvas draw calls; baked quads give square path corners; and
`LINE_BIAS` 1.0 is right for 4.7 lines with AA off.

Status: **not yet run.** Written without an editor. If a script shows an error
when you open the project, copy the error into Notes below and tell the session.

Findings: none yet. They go in the results table at the end.

## What is in it

Seven drawers as in Decision 1 (`FieldBackdrop`, `TowerView`, `EnemyView`,
`CombatView`, `HeroView`, `HudField` as `Node2D`, `HudTopBand` as a `Control`
with `MOUSE_FILTER_IGNORE`), in that order, one canvas, no material. The worst
case is Decision 9's: 48 enemies of three styles with keylines, 16 flashes,
48 death discs, 64 tracer segments through `draw_multiline_colors`, five towers
with one range ring, the hero with its 128x128 `GradientTexture2D` glow, HUD text
at 21, 24 and 36, and 48 `max_hp` reads per frame through a stand-in accessor.

Counters logged (each is read only if its constant exists; `-1` means absent):
`perf` = `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`,
`rs` = `RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`,
`vp` = `Viewport.get_render_info(RENDER_INFO_TYPE_CANVAS, RENDER_INFO_DRAW_CALLS_IN_FRAME)`.
Also: frame time p50 and p99, `step4_us_p99` (buffer fill and accessor reads),
`draw_us_p99` (time inside every `_draw`, command recording only). A `STAT`
line prints every 600 frames and on P.

| Key | Does |
|---|---|
| 1 to 5 | V1: empty field; 1 disc; 10 discs; 48 discs in one `_draw`; 48 discs in 48 nodes |
| 6 / 7 | V2 worst case in Decision 6 order / interleaved order |
| 8 | V2 branch: enemies as one `canvas_item_add_triangle_array` (on or off) |
| F1 to F7 | Hide or show drawer 1 to 7 (each node's share) |
| T | All HUD text at one size (glyph atlas question) |
| M | V5: the 16 flashes on a separate node with one `ShaderMaterial` |
| 9, C | V3: path corners; C cycles `draw_polyline`, `Line2D` (sharp joints), baked quads |
| Z | Zoom 4x on the next corner (cycles 5 corners, then back to 1x) |
| 0 | V4: rings, dashed leash, 1 px slot outline at bias 0 and 1, AA off and on; full arcs at 8 to 32 points |
| A, B | AA on or off; `LINE_BIAS` 1 or 0 (worst case) |
| V | vsync on or off (off shows real cost, on shows capped frame time) |
| S | Screenshot to `user://adr0011_<n>_<mode>.png` |
| P | Print a `STAT` line now |
| H | Overlay text (adds draw calls; keep off when reading numbers) |

## How to run it (macOS)

1. `cd prototypes/adr-0011-render-budget`
2. `/Applications/Godot.app/Contents/MacOS/Godot --path . > results-desktop.txt 2>&1`
   (windowed; never `--headless`). Click the window once so it has focus.
3. For each step, press the key, wait about 12 seconds for a `STAT window`
   line, then go on:
   - V1: 1, 2, 3, 4, 5. Also open the editor's Debugger > Monitors tab
     (run from the editor with F5 instead) and note Raster > Draw calls for each.
   - V2: 6, then F1 to F7 one at a time (press again to show), then 7, then
     6 and 8 (triangle array), 8 again, then T, T. With vsync off (V) repeat 6 and 7.
   - V5: 6, M (wait), M.
   - V3: 9. For each of C (three methods): Z five times, S at each corner.
   - V4: 0, S; Z is not used here. Then 6, A (wait), A, B (wait), B, S each time.
4. Optional external capture: Xcode's Metal frame capture is not set up for a
   Godot binary by default; skip unless you already use it. Write "no capture"
   in V1 Notes.
5. Close the window. Screenshots and `adr0011_log.txt` are in
   `~/Library/Application Support/Godot/app_userdata/adr-0011-render-budget/`.
6. Optional for V4: open the project in a Godot 4.6 build too, press 0 and S,
   and compare the screenshots.

## Results

Date: `<date>`  OS and CPU: macOS, arm64  `godot --version`: `<paste>`  GPU (`adapter=`): `<paste>`

| ADR item | What to record | Desktop | Phone | Notes |
|---|---|---|---|---|
| ADR-0011 V1 | `perf`, `rs`, `vp` for keys 1 to 5 (and Monitors tab); which counter moves with 2D content | | | |
| ADR-0011 V2 order | Key 6 and 7: counters, `frame_ms_p99`, `step4_us_p99`, `draw_us_p99` | | | |
| ADR-0011 V2 per node | Drop in counters when each of F1 to F7 hides its drawer | | | |
| ADR-0011 V2 branch | Key 8: counters and `draw_us_p99` with the triangle array | | | |
| ADR-0011 V2 fonts | Key T: counter change with one text size | | | |
| ADR-0011 V3 | Screenshots per method and corner: square, notched, rounded or seams? | | | |
| ADR-0011 V4 | Line test screenshots: bias 0 vs 1, AA off vs on; arc seam at which point counts; AA cost (key A in key 6) | | | |
| ADR-0011 V5 | Key M: counter and frame time difference | | | |

The art-director picks `LINE_BIAS` from the V4 screenshots. Results go to
`docs/engine-reference/godot/modules/rendering.md` with device, OS and date.
