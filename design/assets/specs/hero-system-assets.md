# Asset Specs: System: hero-system

> **Source**: design/gdd/hero-system.md
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-11-05
> **Status**: 9 assets specced / 0 approved / 0 in production / 0 done
> **Reviewers**: art-director (description, prompt, anchors); technical-artist (size, format, naming, constraints). Every asset is drawn in code unless the Format row says otherwise; the generation prompt is for concept or mock-up images only.

## ASSET-001: Hero (`char_hero`)

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | Kite, long axis to short axis about 1.8:1, tip far, widest cross-point off-centre toward the tip (art bible §5); never below 44 px on the long axis (§5). Long axis +6% while walking. |
| Format | Code: Polygon2D kite (static shape) plus outline Polygon2D behind it for the defeat outline state. No file. |
| Naming | char_hero (scene char_hero.tscn, state as exported property) |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Null material. Halo sprite sits directly behind it with the same material (null) so it can batch. Avoid z-index interleaving with enemy drawers. One node, 0 shaders. |
| LOD | none |
| Source | hero-system.md, art bible §5 |

**Visual Description:**
A flat kite in #FFE9A8 with one long axis (about 1:1.8) and no rotational symmetry. The far point is a stretched tip, the near point is blunt, and the widest cross-point sits off centre toward the tip. It is never smaller than 44 px, shows no face or limbs, and sits on top of its halo. While walking, the tip locks on the pin and the long axis grows 6%. On defeat the fill and glow go away and only a 2 px #FFE9A8 outline stays.

**Art Bible Anchors:**
- §1 Identity: only the hero glows; shape is role
- §3 Shape Language: Hero is the only asymmetric shape, 44 px minimum
- §4 Color: hero #FFE9A8, 16:1 on #0B1020
- §5 Character: Pin kite, 1:1.8, walking +6% axis, defeat outline
- §2 Mood: Defeat dims the hero to an outline, glow 0

**Generation Prompt:**
Flat vector game sprite, minimalist signal-board style, single asymmetric kite shape pointing up, long tip and blunt base, solid #FFE9A8 fill, soft round halo behind it only, centred on a flat #0B1020 field, top-down, no interior detail, readable at 44 px. Palette: #FFE9A8 on #0B1020. Negative: face, limbs, armour, texture, gradient on the body, outline on the body, drop shadow, 3D, bloom on anything else, extra shapes, text, photo, painterly.

**Flags:**
- Hero size is not in the asset list. The bible gives only the 44 px floor and the 1:1.8 ratio. Proposed: 56 px long axis, about 31 px cross width. Confirm against hero-system.md.

**Status:** Needed

## ASSET-002: Hero halo

| Field | Value |
|-------|-------|
| Category | Sprite / 2D (code) |
| Dimensions | 128 x 128 px texture |
| Format | GradientTexture2D resource, radial fill (GradientTexture2D.FILL_RADIAL), white colour with alpha falloff. No PNG, no import step, no mipmaps, no VRAM compression, filter linear. |
| Naming | vfx_hero_halo (art bible lists PNG halo as raster, so a 2x suffix would apply only if baked to PNG) |
| Polycount | n/a (2D) |
| Engine constraints | Hero halo is 1 sprite; burst glow reuses the same texture from a pool of 8 Sprite2D, alpha and scale tweened, null material, modulate only. 128x128 RGBA is 64 KB, far under 16 MB. 0 shaders. Pool at scene load. |
| LOD | none |
| Source | art bible §8 |

**Visual Description:**
A soft round white radial gradient, 128 x 128, single channel, fading from full at the centre to zero at the edge. The game tints it #FFE9A8 and scales it to about 1.2 times the hero body radius. It is the only soft edge in the game and must not tint the path, grid or neighbours.

**Art Bible Anchors:**
- §1 Identity: persistent glow is hero-only
- §5 Character: soft glow about 1.2x body radius
- §9 Reference: Flavin, glow is the object, no colour wash
- §4 Color: tint #FFE9A8 only

**Generation Prompt:**
Single soft circular radial glow on pure black, white centre fading smoothly to black at the edge, perfectly round, centred, 128 px square, greyscale mask. Tint note: #FFE9A8 when used. Negative: rays, flare, star shape, noise, colour fringes, hard edge, banding, texture, shape inside.

**Flags:**
- Art bible says single-channel PNG-class asset but also GradientTexture2D; a GradientTexture2D is RGBA (not single channel) and not a file, so no 2x tier or atlas slot is needed. Size is the GDD value; 2x for 1080x1920 not sourceable for a resource texture.

**Status:** Needed

## ASSET-021: Burst wind-up, ring and release

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | Ring grows to the preview radius; width 3 + 1 per kill; spokes to each kill; field -3%; hero 1.3x snap |
| Format | Code: one tweened draw_arc ring; spokes use the tracer pool; field -3% is a modulate/overlay, no shader. |
| Naming | vfx_burst_ring |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Ring width 3 to 3+N px: above the thin-line band. Spokes drawn from the 64 tracer slots, so a burst with many kills can starve normal tracers; reserve slots. Reduce Motion and no-kill variants are exported properties, not new scenes. Null material. Field -3% via a full-screen ColorRect modulate is one extra draw; count it. |
| LOD | none |
| Source | hero-system.md |

**Visual Description:**
Wind-up: the field dips 3% for about 0.4 s and the hero squashes to a near-circle, then snaps to 1.3 times. A gold #FFE9A8 ring grows to meet the radius preview exactly at release. On kills, 3 px spokes run from the aim point to each kill, and the ring is 3 px plus 1 per kill, up to 9, holding 150 ms. No kills: a 2 px ring fades in over 80 ms at 40% glow. Reduce Motion: no dip, snap or pop, and a static ring from T+0.1 s, 4 px at release.

**Art Bible Anchors:**
- §2 Mood: Hero burst, field -3% for 0.4 s, expanding gold ring matching the preview, glow 2
- §5 Character: bursting, near-circle then 1.3x snap
- §1 Identity: transient glow only on hero-owned burst VFX
- §7 Animation: no chained dip within 1 s; Reduce Motion skips the dip

**Generation Prompt:**
Flat vector VFX storyboard, four frames on a flat #0B1020 field: a white-gold #FFE9A8 kite compressing to a near-circle with a dashed preview circle, then a gold ring growing to meet the preview, then thin gold spokes from the centre to three orange circles, then the thick gold ring holding. Soft halo on the kite only. Negative: particles, sparks, shockwave blur, lens flare, bloom on the ring, fill, text, 3D, other colours.

**Flags:**
- Conflict: bible §5 sets the near-circle wind-up at 0.15 s, and hero-system.md sets it at T to T+0.1 s. The GDD value is newer; use 0.1 s and update the bible.
- Spokes share the 64 tracer pool: check worst-case kills plus live tower tracers. Field dim overlay adds a full-screen quad (overdraw on Adreno 5xx).

**Status:** Needed

## ASSET-024: Leash (`zone_leash`)

| Field | Value |
|-------|-------|
| Category | VFX / Zone (code) |
| Dimensions | 2 px dashed, alpha 0.5, two-tone over the path |
| Format | Code: _draw() with draw_dashed_line or manual segments (draw_dashed_line is in Godot 4 but is NOT SOURCEABLE in docs/engine-reference); two colour passes. |
| Naming | zone_leash |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Two-tone means two draw passes; keep both in one node. Dash length not in the list. Null material. |
| LOD | none |
| Source | hero-system.md, input-gesture-resolver.md |

**Visual Description:**
A 2 px dashed circle around the hero at radius 90, 10 px on and 8 px off, neutral #C8D0E0 at alpha 0.5, never filled. Where it crosses the lifted path, draw a dark outer and a light inner tone, or raise alpha to 0.7, so it clears 3:1. The dash pattern turns solid-denser out of zone.

**Art Bible Anchors:**
- §3 Line styles: leash 2 px dashed, 10 on 8 off, 90 px radius, alpha 0.5
- §7 Leash over the path: two-tone or alpha 0.7
- §1 Principle 3: must never look like a button
- §4 Colour-blind table: in-zone vs out-of-zone by dash density

**Generation Prompt:**
Flat vector game zone, thin 2 px dashed circle outline, 10 on 8 off, pale grey-blue #C8D0E0 at 50% opacity, around a white-gold kite, crossing a slightly lighter navy path, with a two-tone dark and light dash where it crosses, on flat #0B1020 field. Negative: fill, glow, solid line, thick stroke, button look, gradient, text, 3D.

**Flags:**
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed). Dash pattern 10 on, 8 off, radius 90 (art bible §3).

**Status:** Needed

## ASSET-025: Kite ghost and pin ring

| Field | Value |
|-------|-------|
| Category | VFX / Zone (code) |
| Dimensions | 2 px unfilled kite at the pin point; ground ring radius 30 px, 2 px solid |
| Format | Code: Polygon2D outline or _draw() polyline for the kite; draw_arc for the ring. |
| Naming | zone_pin_ghost |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Null material, one node each. |
| LOD | none |
| Source | hero-system.md |

**Visual Description:**
At the pin point, a 2 px unfilled kite outline with no glow, the same shape as the hero. On release a 2 px solid ground ring at radius 30 snaps in under the pin and stays. The ring is the pin; the leash is the territory.

**Art Bible Anchors:**
- §3 Line styles: pin ghost 2 px unfilled kite; ground ring 2 px solid radius 30
- §5 Character: pinned, the ground ring snaps in as the pin lands
- §1 Principle 3: zones thin and unfilled
- §1 Principle 1: glow only on the hero

**Generation Prompt:**
Flat vector game zone, a 2 px unfilled kite outline in pale #C8D0E0 and a thin 2 px solid circle ring of radius 30 beneath it, on flat #0B1020 field, next to a white-gold kite. Negative: fill, glow, shadow, pin icon, arrow, thick line, gradient, text, 3D.

**Flags:**
- The bible does not set the ghost and ring colour. I use neutral #C8D0E0, since gold is hero-only.
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed).

**Status:** Needed

## ASSET-026: Reticle and radius preview (`zone_reticle`, `zone_preview`)

| Field | Value |
|-------|-------|
| Category | VFX / Zone (code) |
| Dimensions | Reticle size NOT in the list; preview ring 2 px solid; cancel alpha 0.3 |
| Format | Code: _draw() reticle (offset, no flip); draw_arc preview at burst radius. |
| Naming | zone_reticle, zone_preview |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Preview ring matches the burst ring radius. Null material. |
| LOD | none |
| Source | hero-system.md, pin-and-aim.md |

**Visual Description:**
The reticle is a 3 px solid ring with four ticks at alpha 0.7, drawn 100 units above the finger with no flip. The radius preview is a solid 2 px unfilled circle at the true burst radius. While cancelling, the reticle drops to alpha 0.3, loses its ticks, and the preview hides.

**Art Bible Anchors:**
- §3 Line styles: reticle 3 px with four ticks alpha 0.7; preview solid unfilled
- §7 Reticle: offset 100 units above, no flip, cancel dims it
- §1 Principle 3: the reticle is offset so the thumb never covers it
- §9 Reference: Mini Metro, hollow line is provisional, solid is committed

**Generation Prompt:**
Flat vector game aim UI, a 3 px solid ring with four short ticks (reticle) above a fingertip position, and a large solid 2 px unfilled circle (radius preview) around it, pale #C8D0E0, on flat #0B1020 field, second frame faded to 30% with no ticks. Negative: fill, glow, crosshair lines through the centre, gold, gradient, text, 3D.

**Flags:**
- Cancel alpha 0.3 is about 2.5:1 by my estimate, below 3:1. It is a deliberate dim state, so check on a device.
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed). Reticle is a 3 px ring with four ticks, alpha 0.7, 100 units above the finger (pin-and-aim.md); its radius is not set in any doc, proposed 12 units.

**Status:** Needed

## ASSET-027: Reach ring (`zone_reach`)

| Field | Value |
|-------|-------|
| Category | VFX / Zone (code) |
| Dimensions | 2 px dotted ring, 3 on 13 off, alpha 0.6; +-20 degree arc solid at alpha 0.7 when clamped |
| Format | Code: _draw() manual dash arcs (angle based dashes), second draw_arc for clamp arc. |
| Naming | zone_reach |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Ring dashes drawn as arc segments, about 13+3 px period; dash count scales with radius, so cap it. Null material. |
| LOD | none |
| Source | hero-system.md |

**Visual Description:**
A neutral #C8D0E0 ring showing the burst reach: 2 px, dotted 3 on and 13 off, alpha 0.6, unfilled, two-tone over the path. When the reticle is clamped, the 20 degree arc on each side of the aim turns solid at alpha 0.7.

**Art Bible Anchors:**
- §3 Line styles: reach ring neutral, dotted 3 on 13 off, 2 px, alpha 0.6
- §7 Leash over the path: two-tone rule
- §4 Color: neutral = information
- §1 Principle 3: zones are drawn, not lit

**Generation Prompt:**
Flat vector game zone, large thin 2 px dotted circle, 3 on 13 off, pale #C8D0E0 at 60% opacity, with one short arc section drawn solid at 70% opacity, centred on a white-gold kite, flat #0B1020 field. Negative: fill, glow, dashes of equal length, thick stroke, colour, gradient, text, 3D.

**Flags:**
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed). 3 px dashes are small; the pattern may blur without feather.

**Status:** Needed

## ASSET-028: Kill preview mark

| Field | Value |
|-------|-------|
| Category | VFX / Zone (code) |
| Dimensions | Body outline: 2 px white contour on the body size |
| Format | Code: _draw() draw_circle in field colour plus draw_arc 2 px white on the enemy shape. |
| Naming | vfx_kill_preview |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Drawn per previewed enemy in the enemy drawer or a pooled overlay. Field colour fill is a flat disc, not an alpha cut. Null material. Using the outline shader would use a slot; do not. |
| LOD | none |
| Source | hero-system.md |

**Visual Description:**
An enemy the burst would kill has its body knocked out to the field colour #0B1020 and a steady 2 px white contour. The damaged core is hidden. It shows only during a live aim and is steady, not pulsing.

**Art Bible Anchors:**
- §3 Line styles: kill mark during aim, body knocked out, steady 2 px white contour
- §5 Character: feature budget, the damaged core is hidden
- §1 Principle 3: drawn, not lit
- §4 Color: shape cue, not an orange or magenta change

**Generation Prompt:**
Flat vector game marker, a hollow circle with a thin 2 px white outline and the interior the same as the background, beside a normal solid orange #FF7A2F circle, on flat #0B1020 field. Negative: glow, fill, cross, skull, pulse rings, gradient, text, 3D.

**Flags:**
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed).

**Status:** Needed

## ASSET-029: Hero Ready ticks and grab ring

| Field | Value |
|-------|-------|
| Category | VFX / Zone (code) |
| Dimensions | Four 3 px ticks at radius 40; dashed grab ring radius 56 |
| Format | Code: _draw() draw_line ticks plus dashed arc. |
| Naming | zone_hero_ready |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. 3 px ticks fine. Grab ring dash values not given. Null material. |
| LOD | none |
| Source | hero-system.md |

**Visual Description:**
Four static 3 px ticks, 8 px long, at radius 40 around the pinned hero, in white-gold #FFE9A8, with no glow, shown in Wave and Intermission. At first Ready they close in from radius 56. While unpinned, a dashed grab ring at radius 56 in neutral #C8D0E0 marks the hero.

**Art Bible Anchors:**
- §3 Line styles: Ready ticks four static 3 px, 8 long, radius 40
- §2 Mood: Ready = solid fill plus complete outer ring, with a non-colour cue
- §1 Principle 3: zones thin, unfilled, dashed means provisional
- §3 Minimum sizes: hero hit area 112 px

**Generation Prompt:**
Flat vector game UI, white-gold kite with four short 3 px radial tick marks around it at 12, 3, 6 and 9 o'clock, second frame showing a dashed circle ring around the kite instead, pale #C8D0E0, on flat #0B1020 field. Negative: glow on the ticks, fill, solid ring, spinning arrows, text, gradient, 3D.

**Flags:**
- The bible does not name the tick colour or the grab ring dash. I use #FFE9A8 for ticks (hero-owned) and the leash dash style for the grab ring.
- Grab ring dash pattern not set in any doc; proposed to match the leash, 10 on, 8 off, at radius 56.

**Status:** Needed
