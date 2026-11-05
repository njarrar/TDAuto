# Asset Specs: System: battle-hud

> **Source**: design/gdd/battle-hud.md, design/ux/hud.md, design/ux/arc-and-chip.md
> **Art Bible**: design/art/art-bible.md
> **Generated**: 2026-11-05
> **Status**: 13 assets specced / 0 approved / 0 in production / 0 done
> **Reviewers**: art-director (description, prompt, anchors); technical-artist (size, format, naming, constraints). Every asset is drawn in code unless the Format row says otherwise; the generation prompt is for concept or mock-up images only.

## ASSET-030: Ground tap ring

| Field | Value |
|-------|-------|
| Category | VFX / Zone (code) |
| Dimensions | Ring radius 16, 2 px, alpha 0.35; 150 ms in, 600 ms hold, 200 ms out |
| Format | Code: _draw() draw_arc, Tween on modulate alpha. |
| Naming | zone_ground_tap |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Art bible says widen such lines by about 1 px, which would change the GDD size: needs art-director and GDD owner ruling. One pooled node (pool size NOT given). Null material. |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
A small 2 px ring at the tap point in neutral #C8D0E0, radius 16, alpha 0.35. It fades in over 150 ms, holds 600 ms, then fades out over 200 ms. It is a rejection cue only, not a button.

**Art Bible Anchors:**
- §7 Ground tap: tiny unanimated dim ring, 150 ms fade in, rejection cue
- §1 Principle 3: must not read as a button
- §4 Color: neutral = information
- §3 Line styles: pin ring is 30, so this is smaller

**Generation Prompt:**
Flat vector game feedback, small thin 2 px circle ring, radius 16, pale #C8D0E0 at 35% opacity, on flat #0B1020 field, three frames fading in, holding and fading out. Negative: fill, glow, ripple, expanding rings, check mark, gradient, text, 3D, colour.

**Flags:**
- Bible §7 limits this cue to the first three taps of a battle; the GDD does not say so. Contrast is about 2.5:1 at alpha 0.35 by my estimate. Confirm both with the UX designer.
- 4.7 thin-line conflict: GDD width vs art bible +1 px advice (ruling needed). Alpha 0.35 on a 2 px line is faint without feather.

**Status:** Needed

## ASSET-031: Lives dashes

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | Dash length NOT given; gap 3 px |
| Format | Code: _draw() rects or draw_line; lost dash goes to alpha 0.2. |
| Naming | ui_lives_dashes |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. HUD sits on a CanvasLayer; a CanvasLayer change breaks batching with the field, so count HUD as its own batch group. Null material. |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
Two rows of five dashes at top-left, each 16 x 3 dp, in neutral #C8D0E0 on the #141B30 panel, with a gap of 3. A lost dash fades to alpha 0.2 in 200 ms and stays in place so the count is clear.

**Art Bible Anchors:**
- §7 Lives and wave: two rows of five dashes, 16x3 dp, lost dash alpha 0.2 in 200 ms
- §4 Color: neutral UI #C8D0E0 on panel #141B30
- §7 Panel placement: top 48 dp band
- §4 Color: magenta is danger only

**Generation Prompt:**
Flat vector HUD element, two rows of five short horizontal dashes, pale #C8D0E0 on a dark panel #141B30, three of them dimmed to 20% opacity, small even gaps, top-left of a portrait screen. Negative: hearts, icons, glow, red, magenta, gradient, text, shadow, 3D.

**Flags:**
- The GDD gap of 3 has no unit. Read it as 3 dp, matching the 3 dp dash height.
- Dash width and length not in the list.

**Status:** Needed

## ASSET-032: Wave pips

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | 20 x 10 px pills |
| Format | Code: _draw() draw_rect with rounded ends (StyleBoxFlat or polygon); filled, outlined, dotted states. |
| Naming | ui_wave_pips |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Dotted pill outline is many small segments; limit to current wave count. HUD CanvasLayer batch group. |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
Pills 20 x 10 at top-centre, one per wave. Done is filled neutral #C8D0E0. Current is a 2 px outline. Upcoming is a dotted outline. They are pills, not discs, so they never match enemy glyphs.

**Art Bible Anchors:**
- §7 Lives and wave: pills at top-centre, filled done, outlined current, dotted upcoming
- §3 UI shape grammar: tree-node fill states, rounded rectangles
- §4 Color: neutral UI on panel
- §2 Mood: state needs a non-colour cue (fill, outline, dots)

**Generation Prompt:**
Flat vector HUD element, a row of small rounded pills on dark panel #141B30, first three solid pale #C8D0E0, fourth a plain outline, rest dotted outlines, top-centre of a portrait screen. Negative: circles, dots as fills, glow, gradient, numbers, colour, shadow, 3D.

**Flags:**
- Dotted outline at 20 x 10 is thin under 4.7; width not set in any doc, proposed 2 px.

**Status:** Needed

## ASSET-033: Gold

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | 16 dp tabular digits |
| Format | Font glyphs via Label; font file asset 042. |
| Naming | ui_gold (Label in HUD scene) |
| Polycount | n/a (2D) |
| Engine constraints | Label uses the HUD font, no material. Redraw only when the value changes. dp to field unit conversion is NOT SOURCEABLE; the project is portrait 540x960. |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
The gold count at top-right as neutral #C8D0E0 digits, 16 dp, medium weight, tabular lining numerals so the width never shifts. It sits on the panel. Digits swap with no bounce or tween.

**Art Bible Anchors:**
- §7 Typography: 16 dp, tabular lining numerals, medium weight
- §4 UI palette: no gold in UI, neutral on #141B30
- §7 Animation: counters swap, never bounce
- §7 Lives and wave: gold is the number at top-right

**Generation Prompt:**
Flat vector HUD text mock-up, the number 1250 in a medium-weight geometric humanist sans with tabular figures, pale #C8D0E0 on a dark panel #141B30, top-right of a portrait screen. Negative: coin icon, gold colour, glow, outline, italic, shadow, gradient, 3D.

**Flags:**
- dp vs field-unit conversion not sourceable here.

**Status:** Needed

## ASSET-034: Next-wave line

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | Enemy glyphs 16, 22, 30 px (true size); 14 dp counts |
| Format | Code: _draw() discs (reuse enemy shape code) plus Label counts. |
| Naming | ui_next_wave_line |
| Polycount | n/a (2D) |
| Engine constraints | Glyph discs drawn neutral colour, null material. Labels use the HUD font. HUD CanvasLayer group. |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
A row of neutral #C8D0E0 enemy glyphs at true size (16, 22 and 30 px), with the fast one keeping its V-notch, and a 14 dp count by each. Glyphs are neutral, not orange. They sit on the panel.

**Art Bible Anchors:**
- §4 Semantic vocabulary: all other screen-space glyphs stay neutral
- §3 Shape Language: enemies are circles, fast has one notch
- §7 Typography: 14 dp floor for body text
- §5 Character: LOD, glyphs at true size

**Generation Prompt:**
Flat vector HUD element, three pale #C8D0E0 filled circles of different sizes 16, 22 and 30 px, the smallest with a V-notch, each followed by a small count like x4, on dark panel #141B30. Negative: orange, glow, icons, outline, gradient, shadow, 3D, extra marks.

**Status:** Needed

## ASSET-035: Start/Call button

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | Panel size NOT in the list; 2 px outline; two 14 dp lines |
| Format | Code: Button or PanelContainer with StyleBoxFlat (2 px border) plus Labels. |
| Naming | ui_btn_start |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Arming alpha via modulate. StyleBoxFlat with null material. Hit area for touch size is a design number NOT in this list. |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
A rounded panel in #141B30 at 85% opacity with a 2 px neutral #C8D0E0 outline and two lines of 14 dp neutral text, plus a 16 px burst glyph. While arming it sits at alpha 0.5, then steps to full at Armed with no tween. It sits in the bottom band only during Build and Intermission.

**Art Bible Anchors:**
- §4 UI palette: neutral on #141B30, panels at 85% opacity
- §3 UI shape grammar: controls are rounded rectangles
- §7 Panel placement: Start/Call may sit in the bottom band during Build and Intermission
- §7 Animation: panel opacity never animates, so Armed is a step

**Generation Prompt:**
Flat vector HUD button, rounded rectangle, dark fill #141B30 at 85%, 2 px pale #C8D0E0 outline, two short lines of small text, a small round-burst glyph at the left, two frames: half-dim and full. Negative: gold, cyan, gradient, glow, drop shadow, bevel, 3D, icon pack look.

**Flags:**
- Size from hud.md: rect 88 x 72, corner 24, centre (186, 800), hit radius 48.

**Status:** Needed

## ASSET-036: Burst button (`ui_btn_burst_ready`)

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | Button size NOT in the list; gold with cooldown wedge |
| Format | Code: Button with StyleBoxFlat; wedge via draw_colored_polygon; Ready pop via scale tween. Icon PNGs only if code cannot do it. |
| Naming | ui_btn_burst_ready |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. If an icon PNG is used it needs the _2x suffix and goes into the one 1024x1024 atlas. Null material. |
| LOD | none |
| Source | battle-hud.md, hero-system.md |

**Visual Description:**
An 84 px disc button in the bottom corner. Ready: solid gold #FFE9A8 fill with a complete outer ring. Cooling: a neutral outline with the gold fill returning behind it as a clockwise linear wedge, and a neutral seconds digit. Locked: dotted neutral outline, no fill or digit. Ready pop is scale 1.15 to 1 in 120 ms.

**Art Bible Anchors:**
- §7 Burst button: 84 px, ready = gold fill plus ring, cooling = outline plus wedge plus digit, locked = dotted
- §4 Color: gold only for hero and the burst button
- §2 Mood: cooling state set, non-colour cue
- §7 Typography: 24 dp cooldown digit, UX floor 18 dp

**Generation Prompt:**
Flat vector game button, round 84 px disc, three states side by side: solid #FFE9A8 fill with a full outer ring, a pale #C8D0E0 outline with a gold clockwise wedge filling and a number 7, a dotted outline only, on dark #0B1020. Negative: glow, bloom, gradient, bevel, icon, shadow, 3D, cyan, orange.

**Flags:**
- Asset list does not state the digit size. Use 24 dp (bible), not less than 18 dp. The digit is hidden while the thumb holds the button, as hero-system.md decides.
- Size from hud.md: 84 px visible, 96 px hit, x 456 (84 left-handed). State variant names (locked, cooling, telegraphing) proposed as ui_btn_burst_[state].

**Status:** Needed

## ASSET-037: Build arc

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | Tower-size polygon with 3 px cyan contour; 80 x 56 panel per disc |
| Format | Code: Polygon2D shape plus Line2D contour plus StyleBoxFlat panel. |
| Naming | ui_build_arc |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. 3 px contour is above the thin-line band. One arc shows at most 3 discs. Null material, HUD or overlay CanvasLayer batch group. |
| LOD | none |
| Source | battle-hud.md, arc-and-chip.md |

**Visual Description:**
Three discs in an arc above the slot. Each shows a tower-size polygon with panel fill #141B30 and a 3 px cyan #2EC4D6 contour. The disc itself is a hit area and is not drawn. Above each sits an 80 x 56 panel with the tower word and cost on two 14 dp lines. Discs and panels sit at alpha 0.5 for the first 200 ms.

**Art Bible Anchors:**
- §7 Build/upgrade affordance: three 56 px role-polygon discs in an arc above the slot, no modal
- §4 Semantic vocabulary: field-anchored polygons in the arc stay cyan
- §3 Minimum sizes: arc disc 56 px visible, 72 px hit
- §7 Flags: the disc is a hit area, not drawn

**Generation Prompt:**
Flat vector game build menu, three outlined tower shapes (triangle, hexagon, square) in a shallow arc above a square slot, each with a 3 px cyan #2EC4D6 contour and dark #141B30 fill, a small dark panel above each with two lines of small pale #C8D0E0 text, on flat #0B1020 field. Negative: round button backgrounds, glow, gradient, gold, drop shadow, 3D, icon pack look.

**Flags:**
- Bible §7 says the lane is never routed under a panel and panels live in the top band. These field-anchored 80 x 56 panels sit over the field and may cover the lane. The bible does not cover this case; ask the UX designer to rule.

**Status:** Needed

## ASSET-038: Upgrade chip

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | 84 x 44 panel, 16 dp cost, 20 px cyan L2 polygon |
| Format | Code: PanelContainer StyleBoxFlat, Label, Polygon2D. |
| Naming | ui_upgrade_chip |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Null material. One instance, repositioned. |
| LOD | none |
| Source | battle-hud.md, arc-and-chip.md |

**Visual Description:**
An 84 x 44 panel in #141B30 at 85% with a 16 dp neutral cost, a 20 px cyan #2EC4D6 level-2 polygon beside it, and a thin neutral draining bar for 1.5 s. It sits at alpha 0.5 for its first 200 ms. It closes with a 120 ms fade on expiry, or a cut on a commit.

**Art Bible Anchors:**
- §7 Build/upgrade affordance: cost chip for 1.5 s with draining bar
- §4 Semantic vocabulary: field-anchored polygon stays cyan
- §7 Typography: 16 dp costs, tabular numerals
- §3 Accretion: the level-2 polygon shows the inset

**Generation Prompt:**
Flat vector game upgrade chip, small rounded panel dark #141B30, a small cyan #2EC4D6 hexagon with an inset outline on the left, the number 45 in pale #C8D0E0 on the right, a thin pale draining bar along the bottom, on flat #0B1020 field. Negative: gold, glow, gradient, shadow, coin icon, arrow, 3D, bevel.

**Flags:**
- Same placement question as ASSET-037: a field-anchored panel over the lane, not covered by bible §7 panel placement.

**Status:** Needed

## ASSET-039: Unaffordable and refusal cue

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | Cost alpha 0.6 struck through; 3 px outline flash 120 ms |
| Format | Code: Label with modulate and a draw_line strike; outline via StyleBoxFlat border tween. |
| Naming | ui_refusal_cue |
| Polycount | n/a (2D) |
| Engine constraints | Code asset, no size suffix. Line width kept at the GDD value; 4.7 CanvasItem lines get no AA feather so they look thinner. Flash is a Tween on border or modulate, not a shader (do not spend shader slot). |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
When gold is short, the cost text drops to alpha 0.6 and gets a strike-through line. Never multiply it by another dim, since 0.6 gives 4.80:1 on the panel. On a refused tap the cost steps to full alpha with a 3 px neutral outline for 120 ms, at most once per 400 ms.

**Art Bible Anchors:**
- §7 Build/upgrade affordance: insufficient gold dims the cost, struck through, no magenta
- §4 Color: magenta = danger only
- §2 Mood: state needs a non-colour cue (strike)
- §7 Animation: 120 ms for state changes

**Generation Prompt:**
Flat vector HUD detail, two small panels dark #141B30, left with the number 120 in pale #C8D0E0 at 60% with a horizontal strike-through line, right with the number 120 at full strength inside a thick 3 px pale outline. Negative: red, magenta, shake lines, glow, cross icon, gradient, shadow, 3D.

**Status:** Needed

## ASSET-040: Prompt line

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | 14 dp one line on panel |
| Format | Label on StyleBoxFlat panel. |
| Naming | ui_prompt_line |
| Polycount | n/a (2D) |
| Engine constraints | Same HUD font, null material, update text only on change. |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
One line of 14 dp neutral #C8D0E0 text on a #141B30 panel at 85% opacity, placed just below the top band. It holds short advice such as 'Drag the hero'. It never wraps and never animates.

**Art Bible Anchors:**
- §7 Typography: 14 dp floor, text on panel only
- §7 Panel placement: prompt line is the exception below the band
- §4 UI palette: neutral on #141B30 at 85%
- §7 Animation: panel opacity never animates

**Generation Prompt:**
Flat vector HUD text strip mock-up, one line of small medium-weight geometric sans text reading Drag the hero, pale #C8D0E0 on a thin dark panel #141B30, below the top HUD band of a portrait screen. Negative: all caps, italic, glow, icon, gradient, shadow, outline, 3D.

**Status:** Needed

## ASSET-041: Max label

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | 14 dp text 'Max' on a panel above an L2 tower |
| Format | Label on StyleBoxFlat panel. |
| Naming | ui_max_label |
| Polycount | n/a (2D) |
| Engine constraints | Same HUD font. Show only for L2 selection, one pooled node. |
| LOD | none |
| Source | battle-hud.md |

**Visual Description:**
The word 'Max' in 14 dp neutral #C8D0E0 on a small #141B30 panel, centred 76 px above a level-2 tower. It shows for 1.5 s, the same as the range ring, to explain why no chip opens.

**Art Bible Anchors:**
- §7 Typography: 14 dp floor, text on panel
- §3 Accretion: level 2 is the top MVP level
- §4 UI palette: no gold in UI
- §7 Panel placement: panels keep clear of the lane

**Generation Prompt:**
Flat vector game label, tiny dark panel #141B30 with the word Max in small pale #C8D0E0 medium-weight sans, floating above a cyan #2EC4D6 hexagon tower with an inset outline, on flat #0B1020 field. Negative: crown, star, glow, gold, gradient, shadow, icon, 3D.

**Flags:**
- Another field-anchored panel (see ASSET-037). At y - 76 it can overlap the lane for towers near the path.

**Status:** Needed

## ASSET-042: UI font

| Field | Value |
|-------|-------|
| Category | UI (code) |
| Dimensions | 14 dp and 16 dp sizes; one font |
| Format | Font file (TTF or OTF) imported as FontFile; tabular digits needed. Font choice and licence NOT SOURCEABLE in the project docs; art-director picks. Import: hinting and antialiasing settings NOT SOURCEABLE; MSDF off recommended for small text (unverified). |
| Naming | ui_font_main (proposed) |
| Polycount | n/a (2D) |
| Engine constraints | Dynamic font glyph atlas counts against the 16 MB texture budget but is small for 2 sizes. One font file only. Tabular digit support must be verified in the chosen font (OpenType tnum feature, FontVariation feature setting). |
| LOD | none |
| Source | battle-hud.md, art bible §7 |

**Visual Description:**
One medium-weight geometric humanist sans, no italics, no all-caps body, with tabular lining numerals. Sizes: 14 dp floor for body, 16 dp for gold, lives, labels and costs, and 24 dp for the burst cooldown digit. Colour is neutral #C8D0E0 on panel only.

**Art Bible Anchors:**
- §7 Typography: geometric humanist sans, medium weight, tabular lining numerals
- §7 Typography: 24 dp digit, 16 dp labels, 14 dp floor
- §4 UI palette: neutral #C8D0E0 on panel #141B30
- §8 text budget: three sizes, one font (see GDD)

**Generation Prompt:**
Typeface specimen sheet, medium-weight geometric humanist sans-serif, digits 0123456789 in tabular lining figures, lowercase and capitals, pale #C8D0E0 on dark #141B30, three sizes shown. Negative: serif, script, italic, decorative, condensed, outline, gradient, glow, shadow, 3D.

**Flags:**
- Asset list names 14 and 16 dp only. The bible adds the 24 dp burst digit (UX floor 18 dp); the GDD text budget of three sizes fits it. The font itself is not chosen yet.
- Font not chosen. Tabular digit support unverified. dp to px mapping not sourceable.

**Status:** Needed
