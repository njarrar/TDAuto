# Art Bible: TowerRiot

> **Status**: Under Review
> **Owned By**: art-director
> **Last Updated**: 2026-11-01
> **Art Director Sign-Off (AD-ART-BIBLE)**: REVISED 2026-11-01 — CONCERNS (3 numeric inconsistencies, 5 clarifications) applied inline; device verification of alpha, contrast and batching still pending

`/art-bible` writes these nine sections in this order and replaces each
section's `[To be designed]` line as that section is approved. A section still
holding its placeholder is incomplete; a later run fills only those.

## 1. Visual Identity Statement

**Visual rule:** *Shape is role, colour is state, and only the hero glows.*

Glow budget (amended by Sections 2–4): *persistent* glow is hero-only; *transient* glow is allowed only on hero-owned burst VFX. Danger is shown by contrast and motion, never glow. Gold is exclusive to the hero and the burst button; UI never uses it. Zone outline alpha floors and the two-tone rule over the lifted path are set in Section 7.

Tiebreaker: when a thing could mean two things, its shape says WHAT it is and a colour change only says HOW it is doing right now. Colour never changes a role. Role hues (towers cool, enemies warm, hero white/gold) are fixed and secondary; state (ready, damaged, slowed, danger) is a separate channel named in Section 2 and never carried by colour alone.

**Principles**

1. **Role by primitive** (Pillar 2: One Hero, Not an Army). Towers are regular polygons, enemies small circles, the hero is the one asymmetric shape and the only glow. *Test:* when two elements compete for attention, the one with less glow and less asymmetry yields. Desaturate a screenshot and shrink it to a quarter: the hero must be found in one second.
2. **Growth by accretion** (Pillar 1: Growth You Can See). Each upgrade adds geometry (ring, spike, layer), never only a recolour. *Test:* when an upgrade could be shown as a tint or as an added element, add the element. Two towers must be rankable by level at phone scale with no number shown.
3. **Zones are drawn, not lit** (Pillar 4: Thumb-First, protecting Pillar 2). The leash circle and the burst reticle and radius preview are thin, unfilled, low-alpha outlines. They never glow, bloom or fill opaque. The leash is dashed, the burst preview is solid. *Test:* when a zone overlaps the hero, the zone's alpha drops and the hero stays on top. Because tapping ground does nothing, the leash must never look like a button (no fill, no hover-style brightening). The reticle is drawn offset from the finger so the thumb never covers it.
4. **Stage by field** (Pillar 3: Every Stage Reads Differently). Stages differ by background, path curve and grid tilt, with no bespoke scenery. *Test:* two stage thumbnails are told apart in two seconds. Where ambiguous, change the path geometry, not the palette alone, since a palette-only change fails colour-blind players and does not satisfy the "no reskinned map" test.

**Known weak points carried into later sections**
- "Colour is state" was undefined in the concept anchor; Section 2 must name the state set and Section 4 its non-colour backups.
- Colour-blind failure points needing a shape or pattern backup: danger magenta versus enemy orange, enemy state tints (slowed, armoured, low health), tower and burst-button ready/cooldown, stage identity by hue alone, leash in-zone versus out-of-zone feedback.
- The concept's orientation line ("hero steered", "ground tapped") is stale; the confirmed model is hold-a-pin and drag-aim. Leash and reticle are the most-seen visuals in play and the main motion language.
- Sound is often off, so every state needs a visual cue.
- Exact leash and alpha values are not set here and need on-device testing at 540x960.

## 2. Mood & Atmosphere

Field values are **offsets from the stage's base V** (Section 6 lets a stage author pick base V 8–14%; the reference stage #0B1020 in Section 4 is base V 12.5%). The glow budget is the number of simultaneous glow sources on screen.

| State | Emotional target | Field / contrast / glow | Descriptors | Energy | Carrier |
|---|---|---|---|---|---|
| Build / stage start | Calm, deliberate competence (Pillar 3: the player reads a new path) | base V, low contrast, path slightly lifted, glow 1 (hero) | patient, legible, open, quiet, ordered | low | The path outline draws itself in on entry, showing the new geometry |
| Combat | Tactical calm with machine rhythm | base V, medium contrast, glow 1 | steady, ticking, busy-but-sorted, rhythmic | medium | Tower fire pulses: thin cyan lines, no glow, so "the machine working" reads |
| Hero burst | "I did that" (Pillar 2) | Field dips base −3% for ~0.4 s; high contrast; glow 2 (hero + burst) | decisive, sudden, bright, brief, earned | peak | An expanding gold ring matching the radius preview exactly, so the preview becomes the payoff; hero stays on top |
| Leak / danger | Urgent but fixable, not panic | base V, magenta chevron strip at the lane exit, no added glow | tense, pulsing, edge-driven, clear | high | 2 Hz pulsing downward chevrons at the exit plus a dash-count of lives; reads with sound off and the hero stays brightest |
| Victory | Satisfied relief (Pillar 1: growth shown) | base +4%, soft contrast, glow 1 | warm, released, spacious, earned | low-medium | Towers' accretion elements brighten in sequence (no glow), rewarding the build |
| Defeat | Disappointed but eager to retry; no shame | base −4%, desaturated 60%, low contrast, glow 0 | muted, still, hollow, brief | low | The hero dims to an outline; the retry button is the only filled shape |
| Menu / skill tree | Considered anticipation (the unspent point is the hook) | base +2%, medium contrast, glow 1 | structured, browsable, quiet, hopeful | low | Node grammar: owned nodes filled, available nodes outlined and slowly pulsing |

**State set.** Colour never carries a state alone.

| State | Non-colour channel |
|---|---|
| Ready | Solid fill plus complete outer ring |
| Cooling down | Outline with the fill returning behind it as a clockwise sweep wedge; remaining-seconds digit on the burst button |
| Damaged | Dark inner core disc growing from 0 to 60% of body radius |
| Slowed | Two trailing parallel drag lines plus a 15% size-pulse wobble (tinted violet) |
| Armoured | Thick 2 dp outer ring that breaks into an arc as armour is stripped |
| Danger | Pulsing chevrons at the exit plus a double outline on the threatened element |

## 3. Shape Language

**Silhouette philosophy.** The shape family tells the player what kind of thing it is at quarter scale: a desaturated, shrunk screenshot must still sort into hero, towers and enemies. A fingertip covers about 100 reference px, so the hero and reticle never depend on interior detail; identity lives in the outer contour and in ring and notch features at the edge (Pillar 4).

**Polygon vocabulary** (Pillar 2). Tower role to polygon is the art director's proposal and must be confirmed by the Tower GDD.
- Triangle: precision, single-target.
- Square: sustained rapid fire.
- Hexagon: area and control, including slow.
- Enemies are circles only. Type is told by size and notch: fast = smallest with one forward V-notch; normal = plain; armoured = largest with a thick outer ring; flying = an offset shadow ring that lags its body in motion (one feature; notches dropped per AD-ART-BIBLE); splitter = a centre seam in the field colour; lane-switcher = one flat chord edge on the side it will move toward.

**Hero.** The only asymmetric shape: one long axis and one off-centre point so it never reads as a regular polygon; its facing is its long tip; the only persistent glow; never smaller than 44 px visible; no supporting shape may share its contour.

**Accretion** (Pillar 1). Level 1 is the bare polygon; level 2 adds an inset concentric outline; level 3 adds a spike on each vertex and the outer ring. The base footprint never changes. Ranking two towers by level needs no digit.

**UI shape grammar.** Controls are rounded rectangles and discs, never tower polygons or enemy circles. Disc buttons are reserved for hero actions. Tree nodes use the role shape (polygon for tower, asymmetric for hero, circle for economy): owned filled, available outlined, locked dotted.

**Line styles.** Leash: 2 px dashed circle (10 on, 8 off) at 90 px radius, alpha 0.5, never filled. Reticle: 3 px solid ring with four ticks, alpha 0.7, drawn offset above the finger. Radius preview: solid unfilled outline. Zones are always thinner than any entity.

**Hero vs supporting shapes.** Supporting shapes are flat and unlit. The hero's glow, asymmetry and white-gold fill are exclusive.

**Minimum sizes** (540 px ≈ 360 dp, 1.5 px per dp; 48 dp = 72 px).

| Element | Visible | Hit area |
|---|---|---|
| Hero | 44 px | 72 px |
| Tower | 56 px | 72 px |
| Build slot | 56 px | 72 px |
| Burst button | 84 px | 96 px |
| Build-arc disc | 56 px | 72 px |
| Enemy | 16 px (fast) to 30 px (armoured) | none |

## 4. Color System

Contrast ratios are against the base field #0B1020 (hand-calculated approximations; verify on device).

| Role | Hex | Contrast |
|---|---|---|
| Field (reference stage, base V 12.5%) | #0B1020 | — |
| Hero (white-gold) | #FFE9A8 | 16:1 |
| Tower | #2EC4D6 | 9.0:1 |
| Enemy | #FF7A2F | 7.3:1 |
| Danger | #FF2E93 | 5.5:1 |
| Status / slow | #8E7CFF | 5.8:1 |
| Neutral UI | #C8D0E0 | 12.2:1 |

**Semantic vocabulary.** One hue, one gameplay fact: gold = hero only; cyan = towers and tower effects; orange = enemies; violet = a status effect on an enemy; magenta = danger only; neutral = information. Magenta and orange are never used for the same fact.

**Field rules per stage** (Pillar 3). Hue range 170–280 so it never approaches enemy orange or danger magenta; value capped at V 14%; path body lifted ~3% lighter than the field, its edge line +6%; grid lines at alpha 0.08. Identity is carried by path curve, path width and grid tilt (0°, 15°, 30°). Hue alone never separates two stages.

**UI palette divergence.** UI uses neutral #C8D0E0 on panel #141B30 with no gold, cyan or orange. The one exception is the burst button, gold because it belongs to the hero. Panels sit at 85% opacity over the field so the action stays visible.

**Colour-blind safety.**

| Pair | Risk | Backup cue |
|---|---|---|
| Danger magenta vs enemy orange | Protan/deutan confusion | Chevron shape plus 2 Hz pulse |
| Slowed vs normal enemy | Tint-only | Drag lines plus size wobble |
| Armoured vs damaged | Both read as "darker" | Outer ring vs inner core |
| Ready vs cooling (tower, button) | Fill-level only | Outline vs filled plus sweep wedge |
| Stage A vs stage B | Hue-only | Path curve and grid tilt |
| Leash in-zone vs out-of-zone | Tint-only | Dash density 10-on to solid |

## 5. Character Design Direction

**Hero archetype: the Pin.** The hero is a flat kite: a four-point asymmetric quad with one long axis (ratio about 1:1.8), the far point stretched into a tip and the near point blunt, the widest cross-point off-centre toward the tip. It is the only shape on the field with no rotational symmetry, so it cannot be mistaken for a tower (regular polygon) or an enemy (circle), even desaturated at quarter scale (Section 1, Principle 1). Fill #FFE9A8 with a soft persistent glow of about 1.2× body radius: the hero's glow is the only soft edge in a game of hard edges, which is why it carries attention. Facing is the long tip, always. The game verb is *pin*, so the hero reads as a pin: it points at what it fights and drops where you put it.

**Pose language (no limbs, no faces).** Intent reads through orientation, scale and the glow envelope, each a single flat-shape transform.
- *Idle (unpinned, in build):* slow 0.5 Hz breathing scale (±4%), tip drifting toward the nearest path, glow at rest.
- *Pinned:* a 2 px solid ground ring snaps in under the hero (the pin lands); the body settles 6% smaller for 0.1 s then returns; the tip tracks targets inside the leash. The ground ring is the pin, the dashed leash is the territory.
- *Attacking:* the tip stretches 10% toward the target on each shot and recoils; shots are thin white-gold lines with no glow (glow budget stays at 1).
- *Bursting:* the body compresses to a near-circle for 0.15 s (wind-up, the one moment the hero loses its asymmetry), then snaps back at 1.3× as the gold ring expands (Section 2). Glow budget 2 for ~0.4 s.

**Weapons by accretion, never recolour** (Principle 2). Each Vertical Slice weapon adds one element to the kite's contour and never alters fill, glow or long axis: weapon A adds a short barb pair at the cross-point; weapon B adds an inset secondary kite outline. Rule for any future weapon: one added element, attached at the cross-point or blunt end, never at the tip, and the 44 px silhouette must still contain exactly one tip. Weapons are visible from the first frame of a stage so the preview is honest about loadout. (Weapon names are placeholders until the Hero Weapons GDD exists.)

**Enemy distinguishing features.** All enemies are circles; type is carried by size and one edge feature per Section 3. *Feature budget:* one type-feature per enemy plus at most one state cue from Section 2 (damaged core, slow drag lines, armour arc). A third mark is forbidden: at 16–30 px three edge features merge into noise. Where a type-feature and a state cue would share an edge (armoured ring vs armour arc), the state cue replaces the type-feature; size still says "armoured".

**Expression through motion.** Each enemy has exactly one motion trait: fast ones jitter forward; flyers bob ±2 px with the shadow ring lagging; armoured ones do not bob; splitters pulse the seam before splitting; lane-switchers lean toward the chord 0.5 s before switching. Telegraphs are motion, not colour, so they survive colour-blindness and sound-off.

**LOD at phone scale.** At 16 px only fill hue, outer-ring presence and one notch survive, so the fast enemy is "small + one notch" and nothing else, and the armoured ring is 2 dp (3 px), never thinner. Interior details are allowed only on enemies of 22 px or larger. The hero never drops below 44 px, so tip, cross-point and one weapon element always survive. *Test:* render each enemy at its minimum size in grey and name it in one second.

**Flying vs armoured at 16–22 px:** both carry a ring, so the flyer's ring is offset and lags in motion while the armoured ring is concentric and static. If device tests show confusion, swap the flyer's ring for a dashed one.

## 6. Environment Design Language

**Architecture.** The field is a near-black plane with a faint grid; the path is the only architecture. Path edge: a 2 px solid line at field +6% V with the path body at +3% (Section 4); no bevel, no glow; square-capped corners on 0° grids and mitred on tilted grids, so the path reads as cut into the field, not laid on it. Build slots are 56 px squares with a 1 px outline at alpha 0.3, rotated with the grid tilt. *Free* slots show a 4-dot corner mark; *blocked* slots (occupied or disabled by stage rule) show no corners and a single diagonal hairline. Free vs blocked is shape, with alpha as secondary support only.

**Stage by field, production rule.** A stage author may vary exactly five things: field hue (170–280), base field value (V 8–14%; Section 2's state offsets apply on top, so the darkest on-screen field is defeat at 4%), path curve (one continuous polyline or spline), path width (56–96 px) and grid tilt (0°, 15°, 30°). Nothing else: no bespoke props, no extra shapes, no changed line weights, no changed entity colours, no second path colour. Two consecutive campaign stages must differ in path curve or grid tilt, never hue alone (Section 4 colour-blind table). A five-knob stage costs an afternoon, which is how 20 stages become affordable (Pillar 3 without a scenery budget).

**Texture philosophy: flat.** No textures, gradients or noise on the field. Every texture competes with the hero's single glow (Principle 1); flat fills draw in one pass on the Mobile renderer; and flatness is the style's authenticity: a Signal Board is a readout, not a place.

**Prop density: zero.** One exception: the lane exit carries the danger chevron strip permanently in a dormant state (static, alpha 0.3) so the player always knows where leaks happen; it animates only in danger. It is shared by every stage, so it is not bespoke scenery. Anything else decorative is a scope request to the producer, not an art decision.

**Environmental storytelling without text.** The stage preview tells its attack type through path and lattice alone: a flying-heavy stage shows a path with a visible gap only flyers cross; a splitter stage forks and rejoins; a lane-switcher stage shows two close parallel lanes; a fast stage is short and straight; an armoured stage is a long serpentine. The preview is the real field geometry rendered small, so what it promises is what the player gets.

**Legibility rule.** No field, path or slot element may exceed V 20% (base cap 14% plus the 6% edge lift) or carry hue within 30° of cyan, orange, gold, magenta or status violet (#8E7CFF, hue ~248, sits inside the 170–280 field range and is excluded by this rule). Every entity therefore sits at 5:1 or better against anything beneath it, and the dimmest entity (an enemy over a lifted path) is brighter than the brightest environment line.

## 7. UI/HUD Visual Direction

*Art direction by art-director; required changes from the ux-designer alignment check are merged below and marked (UX).*

**Diegetic vs screen-space.** Everything that answers "what is happening in the field" is drawn in the field: leash, reticle, radius preview, burst ring, tower cooldown rings, accretion, danger chevrons, and the build/upgrade affordance anchored to its slot. Only bookkeeping is screen-space: the burst button, the gold/lives/wave strip and pause. Rule: if a HUD element points at a position, it lives at that position.

**Typography.** Geometric humanist sans, medium weight, no italics, no all-caps body; tabular lining numerals so counters never shift width. Three sizes: 24 dp for the wave number and the burst cooldown digit (UX floor for the digit: 18 dp); 16 dp for gold, lives, labels and costs; 14 dp (21 px) is the floor for any body text (UX; the art draft's 12 dp is rejected). Neutral #C8D0E0 text sits on panel only, never on the raw field at small sizes.

**Iconography.** Flat, single-colour, 2 dp stroke, built from Section 3's primitives. A tower polygon appears in UI only to mean "that tower", never as decoration.

**Animation.** 120 ms for presses and state changes, 200 ms for panel in/out, ease-out on entry, ease-in on exit; the cooldown sweep is linear because it is a clock. Never animates: the leash (its dash density switches), panel opacity, counter values (digits swap, never bounce). Nothing in screen-space loops or glows. (UX, photosensitivity:) the 2 Hz danger pulse is capped at a 25% alpha swing or rendered as travelling chevrons; the 0.4 s burst field dip never chains (no re-dip within 1 s); a Reduce Motion setting freezes the pulse and skips the dip.

**Burst button.** 84 px visible / 96 px hit, bottom corner on the dominant-hand side, inside the safe area, with the hit box ending at least 24 dp from the side edge (Android back-swipe zone, unverified) and 16 dp above the OS gesture inset (UX); left-handed mirror is a setting. Ready: gold fill and complete outer ring. Cooling: neutral outline with the gold fill returning behind it as a clockwise wedge, seconds digit in neutral (this is how Section 2's "outline only" cooling state should be read). Drag from it to aim.

**Reticle (UX).** Offset *away from the thumb*, default 60–80 dp above; clamped to the viewport and flipped below the finger when the pin is near the top. The aim vector stays finger-relative. While the finger is inside the burst button during an aim, the reticle dims and the radius preview hides, because releasing there cancels.

**Leash over the path (UX).** Where any arc of the dashed leash crosses the lifted path, draw it in two tones (dark outer, light inner) or raise alpha to 0.7, so it clears 3:1. Still thin, still unfilled.

**Build/upgrade affordance.** No modal popup. Slot tap opens three 56 px role-polygon discs in an arc above the slot (never below, where the thumb is); tapping one builds and the arc collapses in 120 ms. Tower tap shows a cost chip for 1.5 s; a second tap on the tower commits. Insufficient gold: the chip dims and the cost is struck through, no magenta (danger only). The chip-then-tap step is the mis-spend safeguard; the Tower GDD and its UX spec own the final call.

**Ground tap (UX).** No success feedback. For the first few taps of a session, a tiny unanimated dim ring fades in over 150 ms as a rejection cue, so new players do not assume the touch was missed. Motion-light so it never reads as a button (Principle 3).

**Lives and wave.** Lives are a dash row at top-left, one 16×3 dp dash each; a lost dash fades in 200 ms, with urgency carried by the in-field chevrons. Waves are pips at top-centre: filled done, outlined current, dotted upcoming (the tree-node grammar). Gold is the number at top-right.

**Panel placement.** Screen-space panels sit only in the top 48 dp band plus safe area, #141B30 at 85% opacity, and the lane is never routed under a panel (UX). The bottom 30% of the screen holds nothing but the burst button and the field, so the pinned thumb never hides the lower lane.

**Flags against Sections 1–4.** Section 3 reserves discs for hero actions, so pause is a rounded rect; the picker discs are in-field tower-role shapes, not UI controls (make them rounded squares if that reads as a stretch). The cooldown digit is hidden while the thumb is on the button; acceptable since pressing the button while cooling does nothing, but device-test it.

## 8. Asset Standards

*Two halves: the art ideal (art-director) and the hard constraints (technical-artist). Where they conflict, the **constrained standard is the rule** for the low-end Android target and the ideal is an upgrade path to re-test at the vertical slice. Batching and renderer claims are pre-4.4 knowledge, NOT SOURCEABLE in `docs/engine-reference/godot/`, and must be verified on device.*

**Source format.** Everything is drawn in code: `_draw()`, Polygon2D, Line2D. Not SVG (rasterised at import, a PNG with extra steps), not PNG sprites. The style is polygons, rings and lines; code gives crisp edges at every DPI with no resolution tiers; accretion is literally "add a ring"; every Section 2 state channel is a parameter, not a sprite sheet. PNG only where code cannot do it cheaply: the hero's halo and UI icons. *Constraint:* static shapes as Polygon2D/Line2D; hot per-frame geometry (projectiles, drag lines, hit flashes) from **one** `_draw()` node per kind, never one node per projectile. Per-enemy `_draw()` nodes are the ideal; if enemy counts pass ~40 on device, enemies move to a single batched drawer.

**Glow.** *Rule:* no bloom. `Environment.glow` on the Mobile renderer is a full-screen downsample chain, too costly on low-end Android, and `Light2D`/`CanvasModulate` glow is banned. Hero glow is one 128×128 single-channel radial `GradientTexture2D` behind the hero; the burst glow is the same sprite scaled and alpha-tweened from a pool of 8. Zero shaders. *Ideal:* 2D HDR glow, re-test at vertical slice.

**Batching rules.** Godot 2D batches consecutive CanvasItems sharing texture, material, blend mode and z-index (unverified). Batching breaks on per-node materials, z-index interleaving, CanvasLayer changes and Light2D; uniform `modulate` is fine. Max **3 distinct CanvasItem shaders** per scene (hit flash, chevron pulse, outline); everything else `null` material. The 2 Hz pulse uses one shared `TIME`-driven material, so all pulsing elements pulse in sync. Outline zones are a second, slightly larger Polygon2D behind each shape with the same material, not a shader. Drag lines for slowed enemies come from one `draw_multiline` call.

**Pooling and particles.** Pool at scene load: 64 projectiles, 48 enemies, 8 glow bursts, 16 hit-flash markers; never `instantiate()` mid-wave. VFX are animated shapes, not particles: burst ring = one tweened arc matching the radius preview; hit flash = 80 ms fill-to-white tween; chevrons = three drawn polygons; tower fire = a 100 ms fading segment drawn by the one projectile `_draw()` node, not a Line2D node per shot. Particles only for the enemy death pop, **CPUParticles2D**, at most 32 per emitter and **300 live particles total** (GPUParticles2D on Android drivers is a known risk; ideal, re-test later).

**Lines.** Godot 4.7 draws CanvasItem lines with no AA feather and they look thinner (`breaking-changes.md`): widen every line that relied on it by ~1 px. Line2D `antialiased` costs a second pass on Mobile (unverified): prefer width ≥ 2 px with AA off, or a 1 px feather baked into a 4×1 gradient texture. *Ideal:* `antialiased = true` everywhere, re-test.

**Raster assets (PNG only).** One 1024×1024 atlas max, lossless PNG, VRAM compression off (ETC2 bleeds hard edges), mipmaps off, filter linear. Base 1x px = Section 3 visible sizes; ship a single 2x tier (covers 1080×1920), add 3x only if device tests show softness. Texture budget **≤ 16 MB**.

**Naming** (`[category]_[name]_[variant]_[size].[ext]`, snake_case): `char_hero`, `tower_tri_l2`, `enemy_fast`, `slot_build`, `path_stage01`, `zone_leash`, `ui_btn_burst_ready`, `vfx_burst_ring`. Scenes use the stem only (`tower_tri.tscn`) with level and state as exported properties, never one scene per level. Size suffix omitted for code assets, required for PNG (`_2x`). A data record's `visual_key` (`design/gdd/data-config-pipeline.md`) holds this asset stem, e.g. `tower_tri_l2`, `enemy_fast`, `char_hero`.

**Budgets (written to `project.yaml` → `performance`):** 60 fps, 16.6 ms frame (30 fps / 33 ms floor), **60 draw calls** per frame, **256 MB** memory ceiling, textures ≤ 16 MB, 300 particles. Target class: Adreno 5xx.

**Per-element checklist.**

| Element | Source | Variants | States |
|---|---|---|---|
| Hero | code + halo PNG | 1 | glow, dimmed outline (defeat) |
| Towers | code | 3 roles × 3 levels | ready, cooling |
| Enemies | code (one batched drawer if > 40) | 6 types | damaged, slowed, armoured |
| Build slot | code | 1 | free, blocked, selected |
| Path | code (Line2D) | 1 per stage | draw-in entry |
| Zones | code | leash, reticle, preview | in/out of zone |
| UI | code + icon PNGs | panel, buttons, tree nodes | owned, available, locked |

## 9. Reference Direction

Each reference supplies one element the Signal Board needs and nothing else; together they cover the four load-bearing visuals (hero glow, zone lines, enemy primitives, stage geometry) without overlapping. The concept's game references (Kingdom Rush, Plants vs. Zombies, Vampire Survivors, Bloons TD 6) are mechanics-only and deliberately absent here.

**1. Dan Flavin, fluorescent light works (1963–96) — the hero's glow.** *Take:* a single soft light source as the only soft edge in a room of hard, matte architecture; the glow *is* the object, not an effect on it (Section 5's 1.2× halo, Section 8's one radial sprite). *Avoid:* Flavin's colour wash across walls and floor. The field stays flat #0B1020 under the hero; the halo never tints path, grid or neighbours.

**2. Mini Metro (Dinosaur Polo Club, 2015) — dashed vs solid zones.** *Take:* the grammar in which a dashed or hollow line is provisional and a solid one is committed, with line weight as the whole hierarchy (leash dashed = territory, preview solid = commitment; zones always thinner than entities). *Avoid:* its cream field and its station-shape-equals-demand system, which would collide with tower polygons: here polygons are roles, never requests, and lines never carry colour meaning.

**3. Geometry Wars: Retro Evolved (Bizarre Creations, 2005) — enemies at 16 px.** *Take:* one primitive plus one motion trait per enemy type, readable inside a swarm of forty (Section 5's feature budget and motion telegraphs). *Avoid:* everything else: neon glow on every entity, grid warp, bloom and particle spray. Its enemies work *despite* the bloom; ours must work with none.

**4. Tempest (Atari, 1981) — stage by field geometry.** *Take:* level identity carried entirely by the shape of the playfield, with no scenery, props or palette swap; a player names the level from its silhouette (Section 6's five knobs, Principle 4's two-second thumbnail test). *Avoid:* wireframe-everything, phosphor glow and implied 3D depth. The path is a flat cut in the field, read top-down, and the field itself is never outlined.

**Working rule.** If a future asset is defended with "it looks like [reference]", that is a failure: a reference supplies one element, and the Signal Board owns the whole.

*Release dates are from memory; verify before sharing the bible externally.*
