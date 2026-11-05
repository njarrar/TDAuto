# Asset Specs: System: enemy-wave

> **Source**: design/gdd/enemy-wave.md
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-11-05
> **Status**: 7 assets specced / 0 approved / 0 in production / 0 done
> **Reviewers**: art-director (description, prompt, anchors); technical-artist (size, format, naming, constraints). Every asset is drawn in code unless the Format row says otherwise; the generation prompt is for concept or mock-up images only.

## ASSET-003: Enemy `normal` (`enemy_normal`)

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | 22 px disc |
| Format | Code: _draw() draw_circle (notch via draw_colored_polygon or polygon). No file. |
| Naming | enemy_normal |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Null material. Pool of 48 enemies made at scene load, never instantiate mid-wave except empty pool (create one, log error). Per-enemy _draw() node; if enemies pass about 40 on device, move to one batched drawer node (bobs +-1 px is a transform offset, not a new node). 0 shaders. Draw order: keep one z-index for all enemies. |
| LOD | none |
| Source | enemy-wave.md |

**Visual Description:**
A plain flat disc, 22 px across, filled #FF7A2F with no ring, notch or glow. It bobs 1 px along its travel. A 1 px dark keyline separates it from equal discs when stacked.

**Art Bible Anchors:**
- §3 Shape Language: enemies are circles only; normal is plain
- §4 Color: enemy #FF7A2F, 7.3:1
- §5 Character: feature budget, one motion trait (bob)
- §1 Identity: no glow on enemies

**Generation Prompt:**
Flat vector game sprite, single plain circle, solid #FF7A2F fill, no outline, no shading, centred on a flat #0B1020 field, tiny sprite readable at 22 px. Negative: eyes, face, glow, bloom, gradient, highlight, shadow, texture, 3D, extra marks, text.

**Flags:**
- Per-enemy nodes vs the 60 draw call budget: batching claims are unverified, test on Adreno 5xx.

**Status:** Needed

## ASSET-004: Enemy `fast` (`enemy_fast`)

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | 16 px disc, V-notch facing its segment |
| Format | Code: _draw() draw_circle (notch via draw_colored_polygon or polygon). No file. |
| Naming | enemy_fast |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Null material. Pool of 48 enemies made at scene load, never instantiate mid-wave except empty pool (create one, log error). Per-enemy _draw() node; if enemies pass about 40 on device, move to one batched drawer node (jitters +-1.5 px is a transform offset, not a new node). 0 shaders. Draw order: keep one z-index for all enemies. |
| LOD | none |
| Source | enemy-wave.md |

**Visual Description:**
The smallest enemy: a 16 px disc in #FF7A2F with one V-shaped notch cut from the edge, on the side facing its path segment. The notch is the only feature. It jitters forward 1.5 px.

**Art Bible Anchors:**
- §3 Shape Language: fast = smallest with one forward V-notch
- §5 Character: LOD at 16 px, small plus one notch only
- §4 Color: enemy #FF7A2F
- §5 Character: expression through motion, forward jitter

**Generation Prompt:**
Flat vector game sprite, small solid circle with one V-shaped notch bitten from one edge, solid #FF7A2F, no outline, centred on flat #0B1020 field, readable at 16 px and in greyscale. Negative: glow, eyes, face, second notch, ring, gradient, shadow, texture, 3D, text.

**Status:** Needed

## ASSET-005: Enemy `heavy` (`enemy_heavy`)

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | 30 px disc, no ring |
| Format | Code: _draw() draw_circle (notch via draw_colored_polygon or polygon). No file. |
| Naming | enemy_heavy |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Null material. Pool of 48 enemies made at scene load, never instantiate mid-wave except empty pool (create one, log error). Per-enemy _draw() node; if enemies pass about 40 on device, move to one batched drawer node (never bobs is a transform offset, not a new node). 0 shaders. Draw order: keep one z-index for all enemies. |
| LOD | none |
| Source | enemy-wave.md |

**Visual Description:**
The largest MVP enemy: a plain 30 px disc in #FF7A2F with no ring, no notch and no glow. It never bobs. Size alone sets it apart from the 22 px normal.

**Art Bible Anchors:**
- §3 Shape Language: heavy = largest, plain
- §5 Character: armoured ring is reserved, heavy wears none
- §4 Color: enemy #FF7A2F
- §5 Character: LOD, size says the type

**Generation Prompt:**
Flat vector game sprite, large plain circle, solid #FF7A2F, no ring, no notch, no outline, centred on flat #0B1020 field, readable at 30 px next to a 22 px twin. Negative: armour ring, glow, face, eyes, gradient, highlight, shadow, texture, 3D, text.

**Status:** Needed

## ASSET-010: Field background (`field_stage01`)

| Field | Value |
|-------|-------|
| Category | Environment (code) |
| Dimensions | Full field 540 x 960 field units |
| Format | Code: _draw() or ColorRect plus one grid drawer; grid lines alpha 0.08 with per-stage tilt. Lives in the stage scene. No file. |
| Naming | field_stage01 |
| Polycount | n/a (2D) |
| Engine constraints | Background is drawn once; keep it static (no per-frame redraw). Grid as one draw_multiline call. Null material. Do not put grid in a CanvasLayer other than the field layer (breaks batching). Hue and V values are art-director data; no palette chosen here. |
| LOD | none |
| Source | art bible §4, §6 |

**Visual Description:**
A flat plane in #0B1020 (hue 227, base V 12.5%) with a faint square grid of 1 px lines at alpha 0.08 in the neutral #C8D0E0, tilted by the stage value (0, 15 or 30 degrees). No texture, gradient, vignette or props. Every field element stays at V 20% or less.

**Art Bible Anchors:**
- §4 Color: field #0B1020, hue 170-280, V 14% or less, grid alpha 0.08
- §6 Environment: flat texture philosophy, prop density zero
- §6 Environment: five stage knobs, tilt 0, 15, 30
- §9 Reference: Tempest, stage by field geometry

**Generation Prompt:**
Flat vector game background, portrait 540x960, solid near-black navy #0B1020, very faint square grid lines at 8% opacity, grid tilted 15 degrees, nothing else, top-down. Negative: texture, noise, gradient, vignette, glow, props, scenery, stars, border, 3D, perspective, text.

**Flags:**
- Grid line width not set in any doc; proposed 2 px at alpha 0.08, since 4.7 lines lose the AA feather. Test on device.

**Status:** Needed

## ASSET-011: Path (`path_stage01`)

| Field | Value |
|-------|-------|
| Category | Environment (code) |
| Dimensions | 72 px wide outer line, 68 px inner; square corners; ends off field |
| Format | Code: two Line2D nodes (art bible lists path as Line2D), square joint and cap modes, antialiased off. |
| Naming | path_stage01 |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line2D width 72 and 68 is far above the 2 px AA risk, so AA off is safe. Null material. Two nodes, 1 per stage. Use sharp joints (LINE_JOINT_SHARP) with square caps to keep square corners; verify on device (Line2D joint behaviour in 4.7 NOT SOURCEABLE). |
| LOD | none |
| Source | enemy-wave.md |

**Visual Description:**
A 72 px wide stroke along the path points. The outer line is #10172F (+6% V), then a 68 px inner body in #0E1428 (+3% V), leaving 2 px edges. Corners are square, and both ends run off the field. No bevel, glow or texture.

**Art Bible Anchors:**
- §6 Environment: path edge 2 px at +6%, body +3%, no bevel, no glow
- §4 Color: path lifted about 3%, edge about 6%
- §6 Environment: legibility rule, V 20% max, no hue near entity colours
- §2 Mood: Build state, path slightly lifted

**Generation Prompt:**
Flat vector game map, top-down winding path cut into a near-black navy field #0B1020, path body slightly lighter #0E1428 with a 2 px edge line a little lighter still #10172F, square 90 degree corners, path runs off the top and bottom of the frame. Negative: bevel, glow, texture, gradient, grass, stone, props, shadow, 3D, rounded corners, bright colours, text.

**Flags:**
- Hex values #0E1428 and #10172F are my computed +3% and +6% V lifts from #0B1020. Check them on a device.

**Status:** Needed

## ASSET-012: Build slot (`slot_build`)

| Field | Value |
|-------|-------|
| Category | Environment (code) |
| Dimensions | 56 px square, 1 px outline alpha 0.3, four corner dots |
| Format | Code: _draw() draw_rect (unfilled) plus 4 draw_circle dots, or Polygon2D plus Line2D. |
| Naming | slot_build |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Hidden under a tower, so toggle visible rather than free. Null material. 0 shaders. |
| LOD | none |
| Source | enemy-wave.md |

**Visual Description:**
A 56 px square outline, 1 px, in neutral #C8D0E0 at alpha 0.3, with four small dots at the corners. It is rotated with the grid tilt and has no fill. It is hidden when a tower stands on it.

**Art Bible Anchors:**
- §6 Environment: slot 56 px, 1 px outline alpha 0.3, 4-dot free mark
- §3 Minimum sizes: slot 56 px visible, 72 px hit
- §4 Color: neutral #C8D0E0
- §3 Shape Language: slot must not look like the 44 px slow tower

**Generation Prompt:**
Flat vector game UI element, hollow square 1 px outline in pale grey-blue #C8D0E0 at 30% opacity, small dot at each corner, on flat #0B1020 field, top-down. Negative: fill, glow, thick stroke, bevel, icon, plus sign, text, texture, shadow, 3D, colour.

**Flags:**
- 1 px outline at alpha 0.3 is the thinnest line in the set and the most hurt by 4.7 (no feather). Art bible says widen about 1 px, GDD says 1 px: ruling needed. Art bible also lists free, blocked, selected (alpha 0.6) states, GDD list shows one.

**Status:** Needed

## ASSET-013: Exit strip chevrons

| Field | Value |
|-------|-------|
| Category | Environment (code) |
| Dimensions | Three downward chevrons; size NOT given in the list (read enemy-wave.md); leak pop 1.25x in 200 ms; 2 Hz pulse |
| Format | Code: three drawn polygons (art bible), plus double outline (second larger polygon, same material). |
| Naming | vfx_exit_chevrons |
| Polycount | n/a (2D) |
| Engine constraints | Uses shader slot 2 of 3 (chevron pulse). One shared TIME-driven ShaderMaterial so all pulses sync. Shader must be CanvasItem; keep to alpha modulate only. Dormant alpha 0.3 via modulate. Pop is a node scale tween. |
| LOD | none |
| Source | enemy-wave.md |

**Visual Description:**
Three stacked downward chevrons in danger magenta #FF2E93 at the last path point, ending at y 888. Dormant: static at alpha 0.3. Danger: pulse alpha 0.75 to 1.0 at 2 Hz, plus a double outline. A leak pops them to 1.25 times in 200 ms, then back.

**Art Bible Anchors:**
- §2 Mood: Leak/danger, 2 Hz chevrons, double outline, no glow
- §6 Environment: dormant strip at alpha 0.3, the one permanent prop
- §4 Color: danger #FF2E93, only for danger
- §7 Animation: pulse capped at a 25% alpha swing, Reduce Motion freezes it

**Generation Prompt:**
Flat vector game marker, three stacked downward-pointing chevrons in hot magenta #FF2E93, thick even strokes, on flat #0B1020 field at the bottom of a path, two frames: dim at 30% opacity, and bright with a second outline around the group. Negative: glow, bloom, gradient, arrows with tails, skull, text, texture, shadow, 3D, orange.

**Flags:**
- The GDD does not name the chevron colour. I use magenta #FF2E93 from bible §2 and §4. The chevrons are field-anchored, so the HUD neutral-only rule does not apply.
- Shader budget: art bible lists hit flash, chevron pulse and outline as the 3 shaders, but outline zones are said to be a Polygon2D with no shader; the list is inconsistent. Also the pulse can be a Tween on modulate with 0 shaders (saves a slot); ruling needed.

**Status:** Needed
