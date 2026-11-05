# Asset Specs: System: tower-system

> **Source**: design/gdd/tower-system.md
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-11-05
> **Status**: 6 assets specced / 0 approved / 0 in production / 0 done
> **Reviewers**: art-director (description, prompt, anchors); technical-artist (size, format, naming, constraints). Every asset is drawn in code unless the Format row says otherwise; the generation prompt is for concept or mock-up images only.

## ASSET-006: Tower `single_target` (`tower_tri`, `tower_tri_l2`)

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | 55 px wide triangle, point up; L2 inset 3 px at 60% |
| Format | Code: Polygon2D triangle (static). L2 inset is a second Polygon2D in field colour. |
| Naming | tower_tri, tower_tri_l2 (one scene tower_tri.tscn, level as exported property) |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Null material. Static Polygon2D. Outline is a larger Polygon2D behind with same null material, not a shader. 0 shaders. |
| LOD | none |
| Source | tower-system.md |

**Visual Description:**
A point-up equilateral triangle, 55 px wide, solid #2EC4D6. Level 1 is the bare shape. Level 2 adds a concentric inset triangle at 60% scale as a 3 px outline knocked out in the field colour #0B1020, with the same footprint.

**Art Bible Anchors:**
- §3 Shape Language: triangle = precision, single-target
- §3 Accretion: level 2 inset at 60%, 3 px, field colour
- §4 Color: tower #2EC4D6, 9.0:1
- §1 Principle 2: growth by accretion

**Generation Prompt:**
Flat vector game sprite pair, point-up equilateral triangle, solid #2EC4D6, left bare, right with a thin inset concentric triangle outline at 60% scale cut out in #0B1020, centred on flat #0B1020 field. Negative: glow, gradient, bevel, shadow, spikes, barrel, face, texture, 3D, text, extra colours.

**Flags:**
- Minor: GDD gives the triangle 55 px wide, and bible §3 sets a 56 px minimum visible tower. A 1 px gap; the GDD value stands, but the bible should read 55 for the triangle.

**Status:** Needed

## ASSET-007: Tower `splash` (`tower_hex`, `tower_hex_l2`)

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | 56 px wide flat-top hexagon; L2 inset |
| Format | Code: Polygon2D hexagon (static) plus inset Polygon2D. |
| Naming | tower_hex, tower_hex_l2 |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Null material. Same as tri. 0 shaders. |
| LOD | none |
| Source | tower-system.md |

**Visual Description:**
A flat-top regular hexagon, 56 px wide, solid #2EC4D6. Level 2 adds a 60% scale inset hexagon outline, 3 px, knocked out in #0B1020. The footprint does not change.

**Art Bible Anchors:**
- §3 Shape Language: hexagon = area, splash
- §3 Accretion: level 2 inset
- §4 Color: tower #2EC4D6
- §1 Principle 2: growth by accretion

**Generation Prompt:**
Flat vector game sprite pair, flat-top regular hexagon, solid #2EC4D6, left bare, right with a thin inset concentric hexagon outline at 60% scale cut out in #0B1020, centred on flat #0B1020 field. Negative: glow, gradient, bevel, shadow, spikes, texture, 3D, text, extra colours, pointy-top.

**Status:** Needed

## ASSET-008: Tower `slow` (`tower_sq`, `tower_sq_l2`)

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | 44 px side square; L2 inset |
| Format | Code: Polygon2D square (static) plus inset Polygon2D. |
| Naming | tower_sq, tower_sq_l2 |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Null material. Same as tri. 0 shaders. |
| LOD | none |
| Source | tower-system.md |

**Visual Description:**
An upright square, 44 px on a side, solid #2EC4D6, not rotated. It is smaller than a 56 px slot so it never reads as one. Level 2 adds a 60% scale inset square outline, 3 px, knocked out in #0B1020.

**Art Bible Anchors:**
- §3 Shape Language: square = slow, 44 px side so it never reads as a slot
- §3 Accretion: level 2 inset
- §4 Color: tower #2EC4D6
- §3 Minimum sizes: tower hit area 72 px

**Generation Prompt:**
Flat vector game sprite pair, upright square with sharp corners, solid #2EC4D6, left bare, right with a thin inset concentric square outline at 60% scale cut out in #0B1020, centred on flat #0B1020 field. Negative: rounded corners, diamond rotation, glow, gradient, shadow, texture, 3D, text, extra colours.

**Status:** Needed

## ASSET-009: Tower ready and cooling ring

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | Ring radius 34 px, 2 px line |
| Format | Code: _draw() draw_arc; cooling regrow clockwise by arc sweep angle, point count set by caller. |
| Naming | zone_tower_ring (name not set by GDD; proposed) |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Null material; one drawer per tower or one shared drawer. 0 shaders. |
| LOD | none |
| Source | tower-system.md |

**Visual Description:**
A thin 2 px ring in #2EC4D6 at radius 34 around the tower body. Ready shows a complete ring. While cooling, the ring regrows clockwise from the top in a linear sweep, and the body stays solid. Shape, not colour, carries the state.

**Art Bible Anchors:**
- §2 Mood: state set, ready = complete ring, cooling = regrowing ring
- §4 Color: ready vs cooling needs a non-colour cue
- §3 Line styles: zones thinner than entities
- §4 Color: cyan = towers and tower effects

**Generation Prompt:**
Flat vector UI diagram, cyan hexagon tower with a thin 2 px ring around it, three frames: full ring, ring one-third grown clockwise from the top, ring two-thirds grown, solid #2EC4D6 on flat #0B1020. Negative: glow, fill inside ring, gradient, dashes, thick stroke, shadow, texture, text, extra colours.

**Flags:**
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed). Name is proposed, GDD gives none.

**Status:** Needed

## ASSET-022: Build and upgrade overlay

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | White overlay alpha 0.6, scale 1.15 to 1 over 120 ms |
| Format | Code: Polygon2D copy of tower shape, Tween on scale and modulate. |
| Naming | vfx_build_overlay |
| Polycount | n/a (2D) |
| Engine constraints | Pooled by the tower (one overlay node per tower, hidden when done). Null material. Reduce Motion variant is a fade only (skip the scale tween). Draws over the tower: keep the same z-index group. |
| LOD | none |
| Source | tower-system.md |

**Visual Description:**
On the first frame of a build or upgrade, a white overlay at alpha 0.6 covers the full tower shape. It scales from 1.15 to 1 over 120 ms. Under Reduce Motion there is no scale; the overlay fades from 0.6 to 0 over 120 ms.

**Art Bible Anchors:**
- §7 Animation: 120 ms for state changes, ease-out on entry
- §1 Principle 2: growth by accretion, the new geometry shows at once
- §2 Mood: no glow outside hero burst
- §7 Animation: Reduce Motion fades only

**Generation Prompt:**
Flat vector VFX strip, a cyan #2EC4D6 hexagon tower covered by a white 60% overlay of the same shape, three frames: 1.15 times size, 1.07 times, 1.0 times, on flat #0B1020 field. Negative: glow, sparkle, burst, ring, hammer, dust, gradient, text, 3D.

**Status:** Needed

## ASSET-023: Range ring

| Field | Value |
|-------|-------|
| Category | VFX / Zone (code) |
| Dimensions | 2 px ring at tower range radius, alpha 0.5; next level ring alpha 0.25 |
| Format | Code: _draw() draw_arc. |
| Naming | zone_range |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Two rings at most on screen. Null material. |
| LOD | none |
| Source | tower-system.md |

**Visual Description:**
A solid 2 px unfilled circle in #2EC4D6 at the tower's range, alpha 0.5, drawn under entities. When a chip is open, the next level range shows as a second ring at alpha 0.25.

**Art Bible Anchors:**
- §1 Principle 3: zones are drawn, not lit; unfilled low alpha outlines
- §4 Color: cyan = towers and tower effects
- §3 Line styles: zones thinner than any entity
- §7 Leash over the path: two-tone rule for zones over the lifted path

**Generation Prompt:**
Flat vector game zone, a thin 2 px unfilled cyan #2EC4D6 circle at 50% opacity around a hexagon tower, a second fainter ring at 25% opacity slightly larger, on flat #0B1020 field with a path crossing. Negative: fill, glow, dashes, gradient, thick line, gold, text, 3D.

**Flags:**
- Contrast risk: cyan at alpha 0.25 on #0B1020 is about 1.6:1, and at 0.5 about 3:1 by my estimate. Verify on a device; the bible leaves zone alpha floors open.
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed).

**Status:** Needed
