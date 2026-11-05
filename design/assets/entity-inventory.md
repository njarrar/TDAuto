# Visual Entity & Screen Inventory

> Generated: 2026-11-05
> Sources: `design/gdd/systems-index.md`; Visual/Audio Requirements of `design/gdd/combat-damage.md`, `enemy-wave.md`, `tower-system.md`, `hero-system.md`, `battle-hud.md`, `game-state-stage-flow.md`, `input-gesture-resolver.md`; `design/art/art-bible.md` §1 to §8; `design/ux/hud.md`, `arc-and-chip.md`, `pin-and-aim.md`
> Scope: MVP only. Vertical Slice and Alpha systems (menus, skill trees, weapons, audio) have no approved GDD yet and are listed under Deferred.

**Source format.** Art bible §8: everything is drawn in code (`_draw()`, `Polygon2D`, `Line2D`). PNG only for the hero halo (a `GradientTexture2D`, so no file) and UI icons. "Code" below means a drawing spec, not an image file. No `design/registry/entities.yaml` entries exist, so names come from the GDDs.

## Entities

| # | Name | Type | Description | Source | Status |
|---|------|------|-------------|--------|--------|
| 1 | Hero (`char_hero`) | Character | White-gold kite, tip locked on the pin, long axis +6% while walking; glow halo behind it; dims to an outline on defeat | hero-system.md, art bible §5 | Needed |
| 2 | Hero halo | Character | 128 × 128 single-channel radial `GradientTexture2D` behind the hero; the burst glow reuses it from a pool of 8 | art bible §8 | Needed |
| 3 | Enemy `normal` (`enemy_normal`) | Enemy | 22 px orange plain disc, bobs ±1 px | enemy-wave.md | Needed |
| 4 | Enemy `fast` (`enemy_fast`) | Enemy | 16 px orange disc with one V-notch facing its segment, jitters ±1.5 px | enemy-wave.md | Needed |
| 5 | Enemy `heavy` (`enemy_heavy`) | Enemy | 30 px orange plain disc, no ring, never bobs | enemy-wave.md | Needed |
| 6 | Tower `single_target` (`tower_tri`, `tower_tri_l2`) | Building | Point-up cyan triangle, 55 px wide; level 2 adds a 3 px field-colour inset at 60% | tower-system.md | Needed |
| 7 | Tower `splash` (`tower_hex`, `tower_hex_l2`) | Building | Flat-top cyan hexagon, 56 px wide; level 2 inset | tower-system.md | Needed |
| 8 | Tower `slow` (`tower_sq`, `tower_sq_l2`) | Building | Upright cyan square, 44 px side; level 2 inset | tower-system.md | Needed |
| 9 | Tower ready and cooling ring | Building | 2 px ring, radius 34; regrows clockwise while cooling | tower-system.md | Needed |
| 10 | Field background (`field_stage01`) | Environment | Flat field, hue 170 to 280, V ≤ 14%, grid at alpha 0.08 with a per-stage tilt; lives in the stage scene | art bible §4, §6 | Needed |
| 11 | Path (`path_stage01`) | Environment | 72-wide line at +6% V, then 68 at +3%, square corners, ends off field | enemy-wave.md | Needed |
| 12 | Build slot (`slot_build`) | Environment | 56 px square, 1 px outline at alpha 0.3, four corner dots; hidden under a tower | enemy-wave.md | Needed |
| 13 | Exit strip chevrons | Environment | Three downward chevrons at the last path point; dormant alpha 0.3, danger pulse 2 Hz with double outline, leak pop 1.25× in 200 ms | enemy-wave.md | Needed |
| 14 | Hit flash | VFX | White disc over the body, 80 ms; alpha 1.0 hero, about 0.6 tower; pool of 16 | combat-damage.md | Needed |
| 15 | Tower tracer | VFX | Cyan 2 px segment, 100 ms fade; one `_draw()` node, pool of 64 | combat-damage.md | Needed |
| 16 | Hero shot line | VFX | White-gold 3 px line from the tip, with tip recoil | combat-damage.md | Needed |
| 17 | Splash ring | VFX | Static cyan 2 px unfilled ring at true radius, 100 ms, never expands | combat-damage.md | Needed |
| 18 | Slow drag lines | VFX | Two violet drag lines, 15% wobble; one `draw_multiline` | combat-damage.md | Needed |
| 19 | Damaged core | VFX | Dark core 0 to 60% of radius, enemies ≥ 22 px only | combat-damage.md | Needed |
| 20 | Death disc | VFX | White disc shrinking to zero in 120 ms (death particles deferred) | combat-damage.md | Needed |
| 21 | Burst wind-up, ring and release | VFX | Field −3%, hero 1.3× snap, gold ring growing to the preview, spokes to each kill, ring width 3 + 1 per kill; no-kill and Reduce Motion variants | hero-system.md | Needed |
| 22 | Build and upgrade overlay | VFX | White overlay alpha 0.6, scale 1.15 to 1 in 120 ms; Reduce Motion: fade only | tower-system.md | Needed |
| 23 | Range ring | Zone | Solid 2 px cyan, alpha 0.5, unfilled; next level at 0.25 | tower-system.md | Needed |
| 24 | Leash (`zone_leash`) | Zone | 2 px dashed, alpha 0.5, two-tone over the path | hero-system.md, input-gesture-resolver.md | Needed |
| 25 | Kite ghost and pin ring | Zone | 2 px unfilled kite at the pin point; 2 px solid ground ring radius 30 on release | hero-system.md | Needed |
| 26 | Reticle and radius preview (`zone_reticle`, `zone_preview`) | Zone | Offset reticle, no flip; solid 2 px preview; alpha 0.3 when cancelling | hero-system.md, pin-and-aim.md | Needed |
| 27 | Reach ring (`zone_reach`) | Zone | Neutral, dotted 3 on 13 off, 2 px, alpha 0.6; ±20° arc solid at 0.7 when clamped | hero-system.md | Needed |
| 28 | Kill preview mark | Zone | Body knocked out to field colour with a 2 px white contour | hero-system.md | Needed |
| 29 | Hero Ready ticks and grab ring | Zone | Four 3 px ticks at radius 40; dashed grab ring radius 56 while unpinned | hero-system.md | Needed |
| 30 | Ground tap ring | Zone | 2 px neutral, radius 16, alpha 0.35; 150 ms in, 600 ms hold, 200 ms out | battle-hud.md | Needed |

## UI Screens

| # | Screen Name | Description | Source | Status |
|---|-------------|-------------|--------|--------|
| 1 | Battle HUD | Top band, field overlays, burst button, modals | `design/ux/hud.md` | UX specced |
| 2 | Build arc and upgrade chip | Three role discs over a slot; 84 × 44 cost chip | `design/ux/arc-and-chip.md` | UX specced |
| 3 | Pin and aim | Hero pin and burst aim feedback | `design/ux/pin-and-aim.md` | UX specced |
| 4 | Result panel (Won, Lost) | Left-aligned 16 dp text, Retry or Play again; Won compact, two-column | battle-hud.md, hud.md | UX specced (in hud.md) |
| 5 | Paused overlay | 40% scrim, 300 × 64 panel, "Paused. Tap to resume" | battle-hud.md, hud.md | UX specced (in hud.md) |
| 6 | Fatal screen | Generic text on the field colour, no catalogue data, script-free scene | game-state-stage-flow.md, ADR-0001 | Needed |

## HUD Elements

| # | Element | Description | Source | Status |
|---|---------|-------------|--------|--------|
| 1 | Lives dashes | Neutral dashes, gap 3; a lost dash goes to alpha 0.2 | battle-hud.md | Needed |
| 2 | Wave pips | 20 × 10 pills: filled done, outlined current, dotted upcoming | battle-hud.md | Needed |
| 3 | Gold | 16 dp tabular digits | battle-hud.md | Needed |
| 4 | Next-wave line | Neutral enemy glyphs at true size (16, 22, 30) and 14 dp counts | battle-hud.md | Needed |
| 5 | Start/Call button | Panel rect, 2 px neutral outline, two 14 dp lines, arming alpha | battle-hud.md | Needed |
| 6 | Burst button (`ui_btn_burst_ready`) | Gold button, cooldown wedge and digit, Ready pop | battle-hud.md, hero-system.md | Needed |
| 7 | Build arc | Tower-size polygon with 3 px cyan contour, 80 × 56 panel per disc | battle-hud.md, arc-and-chip.md | Needed |
| 8 | Upgrade chip | 84 × 44 panel, 16 dp cost, 20 px cyan level-2 polygon | battle-hud.md, arc-and-chip.md | Needed |
| 9 | Unaffordable and refusal cue | Cost at alpha 0.6, struck through; 3 px outline flash for 120 ms | battle-hud.md | Needed |
| 10 | Prompt line | 14 dp, one line, on panel | battle-hud.md | Needed |
| 11 | Max label | 14 dp "Max" on panel above a level-2 tower | battle-hud.md | Needed |
| 12 | UI font | One font, tabular digits, 14 and 16 dp | battle-hud.md, art bible §7 | Needed |

## Audio

| # | Name | Type (SFX / Music / Ambient) | Description | Source | Status |
|---|------|------------------------------|-------------|--------|--------|
| — | None at MVP | — | Every MVP GDD states "Audio: none at MVP". The Audio system is Alpha | systems-index.md | Not needed at MVP |

## Deferred (no approved GDD yet)

Enemy types 4 to 7 and the `armoured` ring (Vertical Slice); death particles (CPUParticles2D); path draw-in; Victory tower brighten sequence; menus, stage select, skill trees, weapons (Vertical Slice); audio (Alpha).
