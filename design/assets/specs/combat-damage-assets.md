# Asset Specs: System: combat-damage

> **Source**: design/gdd/combat-damage.md
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-11-05
> **Status**: 7 assets specced / 0 approved / 0 in production / 0 done
> **Reviewers**: art-director (description, prompt, anchors); technical-artist (size, format, naming, constraints). Every asset is drawn in code unless the Format row says otherwise; the generation prompt is for concept or mock-up images only.

## ASSET-014: Hit flash

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | Disc sized to the body it covers; 80 ms |
| Format | Code: _draw() white disc in a pooled marker; alpha 1.0 hero, about 0.6 tower. |
| Naming | vfx_hit_flash |
| Polycount | n/a (2D) |
| Engine constraints | Pool of 16 markers at scene load, drop oldest flash if pool is empty. Pooled nodes use null material and modulate for alpha, no shader needed. Draw over body at higher z means z-index interleaving can break batches; keep one flash layer above all bodies. |
| LOD | none |
| Source | combat-damage.md |

**Visual Description:**
A white disc laid over the struck body for 80 ms, the same size as the body. Hero and burst hits use alpha 1.0, and tower hits about 0.6 so towers never outshine the hero. A retrigger restarts the clock and keeps the higher alpha.

**Art Bible Anchors:**
- §1 Principle 1: role by primitive, less glow yields to the hero
- §2 Mood: transient effects stay glowless outside hero burst
- §8 pool of 16 flash markers (see GDD)
- §4 Color: white is a flash, not a role colour

**Generation Prompt:**
Flat vector sprite comparison, an orange #FF7A2F circle with a pure white circle of the same size on top, two frames: full white and 60% white, on flat #0B1020 field. Negative: glow, bloom, halo, sparks, ring, gradient, shadow, texture, text, 3D.

**Flags:**
- Art bible lists hit flash as shader 1 of 3 but also defines it as an 80 ms white disc. A drawn disc needs no shader; recommend 0 shaders (frees a slot). Ruling needed.

**Status:** Needed

## ASSET-015: Tower tracer

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | 2 px segment, 100 ms fade |
| Format | Code: one _draw() node drawing up to 64 live segments (draw_line per segment or one draw_multiline). |
| Naming | vfx_tower_tracer |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Pool of 64 is a slot array inside ONE node, not 64 nodes. Per-segment alpha needs per-colour lines; use draw_line per slot (up to 64 calls inside one canvas item batch). Null material. Redraw only while any slot is live. |
| LOD | none |
| Source | combat-damage.md |

**Visual Description:**
A thin 2 px straight segment in #2EC4D6 from a tower to its target, fading to zero over 100 ms. It has no glow, arrowhead or trail. Its origin on the polygon is what tells it from the hero line.

**Art Bible Anchors:**
- §2 Mood: Combat, thin cyan lines, no glow
- §4 Color: cyan = towers and tower effects
- §1 Principle 1: width and origin tell tower from hero
- §3 Line styles: lines thinner than entities

**Generation Prompt:**
Flat vector game effect, one thin 2 px cyan #2EC4D6 straight line from a hexagon tower to an orange circle, with a faded copy showing the fade, on flat #0B1020 field. Negative: glow, bloom, arrowhead, projectile, trail, spark, gradient, thick line, text, 3D.

**Flags:**
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed).

**Status:** Needed

## ASSET-016: Hero shot line

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | 3 px line from the tip |
| Format | Code: _draw() draw_line, tip recoil is an offset on the hero kite. |
| Naming | vfx_hero_shot_line |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. One shared drawer with the tracer node or its own single node. Null material. |
| LOD | none |
| Source | combat-damage.md |

**Visual Description:**
A 3 px straight line in white-gold #FFE9A8 from the hero's tip to its target. It has no glow. The tip stretches 10% toward the target on each shot and then recoils.

**Art Bible Anchors:**
- §5 Character: attacking, tip stretches 10%, thin white-gold line, no glow
- §1 Identity: glow budget stays at 1
- §4 Color: gold = hero only
- §1 Principle 1: hero line is heavier than a tower line

**Generation Prompt:**
Flat vector game effect, a white-gold #FFE9A8 kite pointing right with a 3 px straight line from its tip to an orange #FF7A2F circle, on flat #0B1020 field, kite tip slightly stretched. Negative: glow, bloom, spark, trail, muzzle flash, arrowhead, gradient, text, 3D.

**Flags:**
- 3 px is above the 2 px risk band; still thinner under 4.7. Low risk.

**Status:** Needed

## ASSET-017: Splash ring

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | 2 px unfilled ring at true radius, 100 ms, static |
| Format | Code: _draw() draw_arc full circle, no scale tween. |
| Naming | vfx_splash_ring |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. Share drawer with tracer node or one small pooled node. Null material. Never scales, so it cannot read as a burst. |
| LOD | none |
| Source | combat-damage.md |

**Visual Description:**
A 2 px unfilled ring in #2EC4D6 drawn once at the true splash radius around the impact point, for 100 ms. It never expands or fills, so it cannot read as a burst.

**Art Bible Anchors:**
- §1 Principle 3: zones are drawn, not lit
- §2 Mood: burst is the only expanding ring
- §4 Color: cyan = tower effects
- §3 Line styles: 2 px, thinner than any entity

**Generation Prompt:**
Flat vector game effect, one thin 2 px unfilled cyan #2EC4D6 circle outline around an orange cluster of circles, on flat #0B1020 field, perfectly static. Negative: glow, fill, expanding ripple, double ring, shockwave, gold, gradient, particles, text, 3D.

**Flags:**
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed).

**Status:** Needed

## ASSET-018: Slow drag lines

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | Two violet lines per slowed enemy, 15% wobble |
| Format | Code: one node, one draw_multiline call for all slowed enemies. |
| Naming | vfx_slow_drag_lines |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Single draw_multiline per frame (colour is uniform per call, so one colour only). Line width NOT given in the list; use the GDD value. 4.7 no-feather applies. Null material. |
| LOD | none |
| Source | combat-damage.md |

**Visual Description:**
Two short parallel trailing lines in violet #8E7CFF behind a slowed enemy, along its travel line. The enemy body also pulses 15% in size. The lines are the cue, not the tint.

**Art Bible Anchors:**
- §2 Mood: Slowed = two drag lines plus 15% wobble, violet
- §4 Color: violet only on an enemy, never a tower
- §4 Colour-blind table: slowed vs normal needs lines and wobble
- §5 Character: one state cue per enemy

**Generation Prompt:**
Flat vector game status marker, orange #FF7A2F circle with two short parallel violet #8E7CFF trailing lines behind it, as if dragged, on flat #0B1020 field. Negative: glow, motion blur, smoke, snowflake, ice, gradient, tint on the whole body, text, 3D.

**Flags:**
- Line width not stated in the list; needs GDD value. Also violet is a palette choice by art-director.

**Status:** Needed

## ASSET-019: Damaged core

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | Dark core, 0 to 60% of radius; enemies >= 22 px only |
| Format | Code: _draw() draw_circle inside the enemy drawer, radius scaled by damage. |
| Naming | vfx_damaged_core |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Part of the enemy _draw(), no extra node, so no extra batch. Skip drawing for the 16 px fast enemy. |
| LOD | LOD by size: skipped under 22 px (rule from the GDD). |
| Source | combat-damage.md |

**Visual Description:**
A dark disc inside the enemy body, centred, growing from 0 to 60% of the body radius as health falls. It shows only on enemies of 22 px or more. It is hidden when slowed, and during the kill-preview knockout.

**Art Bible Anchors:**
- §2 Mood: Damaged = dark inner core 0 to 60% of radius
- §4 Colour-blind table: armoured ring vs damaged core
- §5 Character: interior details only at 22 px or more
- §5 Character: feature budget, one state cue

**Generation Prompt:**
Flat vector game status sprite, orange #FF7A2F circle with a smaller dark circle in its centre, three frames at 0, 30 and 60 percent of the radius, dark core #2A1208, on flat #0B1020 field. Negative: crack, blood, glow, gradient, ring, outline, text, 3D, notch.

**Flags:**
- No bible or GDD hex for the core. Proposed #2A1208 (dark brown), kept apart from the field colour #0B1020 so it never looks like a kill-preview knockout.

**Status:** Needed

## ASSET-020: Death disc

| Field | Value |
|-------|-------|
| Category | VFX (code) |
| Dimensions | White disc shrinks to 0 in 120 ms |
| Format | Code: _draw() disc, radius tween; no particles at MVP. |
| Naming | vfx_death_disc |
| Polycount | n/a (2D) |
| Engine constraints | Pool with the hit flash markers or its own small pool (pool size NOT given; the pool list in the art bible has no death disc entry, so size is not sourceable). Null material. Uses 0 of the 300 particle budget. CPUParticles2D pop is deferred. |
| LOD | none |
| Source | combat-damage.md |

**Visual Description:**
A white disc the size of the dying body, shrinking to nothing in 120 ms. It is flat with no glow, ring or particles.

**Art Bible Anchors:**
- §1 Principle 1: role by primitive, no extra shapes
- §2 Mood: no glow outside hero burst
- §4 Color: white is a flash, not a role colour
- §8 no particles at MVP (see GDD)

**Generation Prompt:**
Flat vector animation strip, a pure white circle shrinking over four frames from full size to a dot, on flat #0B1020 field. Negative: glow, particles, sparks, ring, debris, smoke, gradient, explosion, text, 3D.

**Flags:**
- No pool size for death discs in the art bible pool list (64/48/8/16). Pick one: reuse the 16 flash markers or add a pool.

**Status:** Needed
