# UX Spec: Build Arc and Upgrade Chip

> **Status**: In Design (autonomous draft, 2026-11-04; revised after the first `/ux-review` the same day)
> **Author**: ux-designer (autonomous mode; user to review)
> **Last Updated**: 2026-11-04
> **Journey Phase(s)**: none recorded; `design/player-journey.md` does not exist (UQ-10). The arc and chip appear in every battle, from the first wave onward
> **Platform Target**: iOS and Android, portrait, touch only. The desktop development build uses the mouse as touch. No keyboard, gamepad or hover input exists (technical preferences)
> **Template**: UX Spec
> **Source of truth**: `design/gdd/tower-system.md` (Core Rules 5 to 8, Visual/Audio, UI Requirements) and `design/gdd/battle-hud.md` (Rules 6 to 9 and 11, Layout, Content rules) own every rule and number. This spec organises them as a screen-level UX spec and settles the points the Tower GDD flags for this pass. A value marked **(proposal)** is mine, not the GDDs'; a value marked **(derived)** is computed from GDD numbers, with the arithmetic shown. If this spec and a GDD ever differ, the GDD is right and this file is stale.
> **Related**: `design/ux/hud.md`, `design/ux/interaction-patterns.md` (patterns P-nn), `design/accessibility-requirements.md`, `design/art/art-bible.md` sections 3, 4, 7
> **Relation to the pattern library**: this spec is the screen-level statement for the arc and chip. Patterns P-06 and P-07 keep a summary and point here; when the two differ, this spec (after the GDDs) is right.

---

## Purpose & Player Need

The build arc and the upgrade chip are how the player turns gold into towers. They are not screens: each is a small overlay anchored to the thing the player touched, in the field, never in a corner.

**The player arrives at a free slot wanting to put the right tower on it with one confident tap, and arrives at a built tower wanting to make it stronger without paying by accident.**

What goes wrong without them, or when they are hard to use:
- There is no selling and no refund at MVP (Tower Rule 4). A wrong disc costs gold at once, and the mistake may only show at wave 6, minutes later. So a mis-tap here is the most expensive input in the game, and the design's job is to make the right tap easy and the wrong one hard.
- Pillar 4 (Thumb-First) says every action is one tap, no target under 48 dp. The arc is two taps (slot, then disc) and the chip is two taps (tower, then tower or chip); both must work one-thumbed, with the thumb never hiding what it just touched.
- Pillar 1 (Growth You Can See) needs the payoff on the first frame: a new tower appears and may fire at once, and a level-2 tower shows its inset outline at once.

**Design stance.** Choosing should read from shape and one word, not from numbers. Cost is the only number on screen, and it is shown where the choice is made. The two guards (a 200 ms guard on the arc, and the chip step on an upgrade) are the mis-spend safeguards, and they must be visible, not just present in code.

---

## Player Context on Arrival

| Question | Answer |
|---|---|
| When does the player first meet this? | In the first battle. Once the hero is pinned and while no tower is built, the prompt in Build and Intermission is "Tap a slot to build" (in Wave it is the burst prompt instead) (Battle HUD Rule 13). Nothing else teaches it |
| What were they just doing? | Planning in Build (clock stopped, calm), or mid-wave watching enemies approach (time-pressured), or in Intermission deciding whether to call early |
| Emotional state to design for | Build and Intermission: deliberate, a little uncertain which tower fits. Wave: hurried, one thumb possibly still near the hero. The arc must be safe to open by accident and quick to dismiss |
| Voluntary or sent? | Voluntary. The player opens the arc by tapping a slot; nothing opens it for them |
| Prior knowledge | None assumed on the first battle. The three tower shapes are new; the words Single, Splash, Slow on the panels carry the meaning |

Phases where the arc and chip work: Build, Wave and Intermission. The commands are never phase-locked (Tower Rule 6; Flow Rule 10). The cost of building mid-wave is attention: the thumb cannot re-pin at the same time.

---

## Navigation Position

This is an in-battle overlay, not a navigable screen.

`App Root` → `Battle` → (tap a free slot) → **Build arc**
`App Root` → `Battle` → (tap a level-1 tower) → **Upgrade chip**
`App Root` → `Battle` → (tap a level-2 tower) → range ring and a "Max" label (no chip)

It is context-dependent (only inside a battle, and only while no outcome or Fatal has latched), and there is one entry per overlay. At most one arc or one chip is open at a time. An open arc takes the next press as its own (the backdrop), so a chip cannot open while an arc is open, and the reverse.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Free build slot | `tap` on the slot disc (TAP 200). TowerInput emits `slot_tapped(slot_index)` and the HUD opens the arc | Current gold, the slot's index and position, the three level-1 tower IDs and costs |
| Level-1 tower | `tap` on the tower disc (TAP 200) while no chip is open for it. TowerInput opens the chip | Current gold, the tower's level (1), the level-2 cost |
| Level-1 tower with a different chip open | `pressed` naming another tower closes the first chip; that tower's own tap then opens its chip | As above |
| Level-2 tower | `tap` on the tower | Nothing; opens the range ring and the "Max" label (UQ-03), not a chip |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Battle (tower built) | `tap` on a disc at 200 ms or later, gold at least the cost | Irreversible: gold falls at once, no refund. The arc unregisters at once and the 120 ms collapse is art only |
| Battle (arc dismissed) | `pressed` with a best tap that is not a disc (backdrop sink); `drag_started`; a disc press under 200 ms after opening | No purchase. The later `tap` of an id no longer live is ignored |
| Battle (arc closed by the game) | Paused, Won, Lost or Fatal; `HALTED` from `build`; any other `build` result besides `OK` and `NO_GOLD` (also logs a development error) | `NO_GOLD` does not close the arc |
| Battle (tower upgraded) | Same tower or the chip tapped when `200 <= elapsed < 1500` ms at release, gold at least the level-2 cost | Irreversible. Any result except `NO_GOLD` closes the chip |
| Battle (chip expired) | 1,500 ms pass | Chip disc unregisters. A held press past expiry does nothing. A later tap on the tower opens a new chip and never commits |
| Battle (chip dismissed) | `pressed` naming another tap target or none | `pressed` naming the chip, or the same tower with the hero beneath, keeps it open |
| Battle (chip closed by the game) | Paused, Won, Lost, Fatal; `HALTED`; Retry destroys it with the battle | A phase change among Build, Wave and Intermission leaves it open |

One-way exits: both purchases. There is nothing to return to; the slot or tower is changed.

---

## Layout Specification

### ASCII Wireframe

Costs are placeholders (`N`); real costs come from Data. Distances are field units, not to scale. `S` is the slot's centre.

```
Build arc (slot S, R = 96, all three affordable)

             +-----------+
             |  Splash   |   panel 80 x 56, top at S.y - 188
             |     N     |
             +-----------+
  +-----------+ (hexagon)  +-----------+
  |  Single   |   disc     |   Slow    |
  |     N     |  (0,-96)   |     N     |
  +-----------+            +-----------+
   (triangle)                 (square)
   disc (-83.1,-48)           disc (+83.1,-48)

                  [ slot S ]

Upgrade chip (tower at S, level 1)

          +--------------------+
          |  /\2    N         |   panel 84 x 44 (proposal; GDD 76), centre (S.x, S.y - 76)
          | =================  |   bar, 3 units, drains left to right over 1.5 s
          +--------------------+
                  /\             tower (level 1), hit disc radius 36
```

### Layout Zones

Field units, 540 x 960 reference. Presses are tested against discs, not drawings.

| Zone | Rect / position | Holds | Input |
|---|---|---|---|
| Arc backdrop | One disc covering the field | Nothing drawn | TAP 250, sink (HUD Rule 6) |
| Arc disc, triangle (Single) | `S + (-83.1, -48)`, hit radius 36 | Tower-size polygon, panel fill, 3 px cyan contour | TAP 300 |
| Arc disc, hexagon (Splash) | `S + (0, -96)`, hit radius 36 | Same | TAP 300 |
| Arc disc, square (Slow) | `S + (+83.1, -48)`, hit radius 36 | Same | TAP 300 |
| Arc panels | 80 x 56, centred over each disc, bottom edge 8 above the polygon's top edge (**derived**: the GDD's starter panel top of y 117 at S.y 305 gives 305 - 96 - 28 - 8 - 56 = 117) | Word (14 dp) and cost (14 dp), two lines | None (display; UQ-07) |
| Chip panel | **84 x 44 (proposal, UQ-16; the GDD says 76 x 44)**, centre `(S.x, S.y - 76)` | Level-2 glyph (20 px, cyan), cost (16 dp, up to 3 digits), bar | None (the chip disc takes the press; its radius 40 is unchanged, so the 88.7 and 122.4 clearances hold) |
| Chip disc | Centre `(S.x, S.y - 76)`, radius 40, while the window is open | Nothing drawn | TAP 300 (TowerInput) |
| Chip bar | 3 units tall along the panel's bottom edge, neutral | Time left | None |
| Range rings | Centred on the slot or tower, under entities | See States | None |

**Geometry check (derived from the GDD's formula `arc_disc(k) = S + R(sin a_k, -cos a_k)`, a = -60, 0, 60 degrees, R = 96).**
- Offsets are (-83.1, -48.0), (0, -96.0), (+83.1, -48.0). The chord between neighbouring disc centres is 96, so the 36-radius hit discs leave 24 units clear between them.
- A slot's own disc (radius 36) is 24 clear of the nearest arc disc at the starter layout (GDD content rule), and Start/Call's hit disc is at least 16 clear (starter 78.5).
- At the extreme slots allowed by rule L1 (x 156 and 384), the outer discs sit at x 72.9 and x 467.1. Their hit discs span x 36.9 to 108.9 and 431.1 to 503.1, clear of the 36-unit edge-reject margin by 0.9 and 0.9 units. That is why L1 is x 156 to 384.
- At the lowest slot y allowed (304) the top panel reaches y 116, clear of the band at inset 0 (the band ends at y 72) and meeting the prompt line at `I_top` 11 (GDD).
- The chip's top is at `S.y - 98` and `S.y >= 304`, so the chip never reaches above y 206 and never meets the band (at most 174 high). Its hit disc is 88.7 from Start/Call's and 122.4 from either burst button (GDD content rules). **The "chip leaving the field" flag cannot occur under L1.**

### Text Fit

The Tower GDD flags that "a polygon plus digits in 56 px is tight". In the GDDs' design the digits are never inside the 56 px polygon: the arc puts word and cost in an 80 x 56 panel above each disc, and the chip puts a 20 px glyph beside the cost in its own panel. What must fit is the panel. Costs can have 3 digits: the content rules allow a level-1 cost up to `starting_gold` (120 in the starter), and nothing caps a level-2 cost. Starter costs are 50 to 80.

**Estimate** (the font is not chosen, PQ-07; a tabular digit or average letter is taken as 0.55 em; 14 dp = 21 units, 16 dp = 24 units):

| Element | Content, worst case | Width needed | Width available | Fits? |
|---|---|---|---|---|
| Arc panel, line 1 | "Splash", 6 letters at 14 dp | 69.3 units of text | 80 | Yes, with about 5 units each side |
| Arc panel, line 2 | 3 digits at 14 dp | 34.7 | 80 | Yes |
| Chip, at the GDD's 76 | 8 padding + 20 glyph + 8 + 3 digits at 16 dp (39.6) + 8 | 83.6 | 76 | **No**: only 2 digits fit (70.4) |
| Chip, at 84 (proposal) | Same | 83.6 | 84 | Yes, just |

**Decision (proposal, UQ-16):** widen the chip panel to 84 x 44 and keep its hit disc (radius 40) where it is. Recheck on a render once the font is chosen; the alternative is a content rule that every cost stays at 2 digits. Two lines of 14 dp in a 56-unit panel need 42 units of text height, leaving 7 above and below.

**Clearance check for the wider chip (derived).** At inset 0, a sweep over every slot the content rules allow (x 156 to 384, y 304 to 924, in 0.5-unit steps, keeping the slot and chip-disc clearances to Start/Call and both burst buttons) finds no position where an 84 x 44 chip panel overlaps Start/Call's 88 x 72 rect or either burst button's 84-unit disc. The same holds at 76. Recheck when insets are known.

### Component Inventory

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Arc backdrop | Hit disc (sink) | None | Yes (dismisses) | P-04 |
| Arc disc (x3) | Hit disc + drawn polygon | Tower polygon | Yes (builds) | P-06 |
| Arc panel (x3) | Drawn panel | Word, cost | No | P-06, P-13 |
| Build overlay | Visual | White overlay on the new tower's first frame | No | P-06 (new fallback, UQ-01) |
| Upgrade chip | Hit disc + drawn panel | Level-2 glyph, cost, bar | Yes (commits) | P-07 |
| Chip bar | Drawn bar | Time left | No | P-07 |
| Range ring | Drawn outline | Reach | No | none (new; UQ-11) |
| "Max" label | Drawn panel, 14 dp | "Max" | No | none (**new pattern**, UQ-03) |
| Guard look | Visual state | Alpha 0.5 on discs and chip for the first 200 ms | No | none (**new pattern**, UQ-02) |
| Refusal cue | Visual state | Brightness step on the refused cost | No | P-12 (**fills its gap**, UQ-01) |

### Information Hierarchy

Arc, in order of attention: (1) which tower, by shape; (2) what it is for, by the word; (3) whether it can be afforded, by the cost and its strike-through. The shape is first because the tower will be seen on the field in that shape.
Chip, in order: (1) the cost to upgrade; (2) the time left, by the bar; (3) the level-2 glyph (what it becomes).
Discovered rather than shown: tower stats, damage and range numbers (never shown, HUD Rule 4). The range ring shows reach; nothing shows damage.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Arc closed | Default | No targets registered |
| Arc open, guard | `slot_tapped`, first 200 ms | Backdrop and three discs registered. **Guard look (proposal, UQ-02):** discs and panels at alpha 0.5, stepping to full at 200 ms. A disc press now counts as a press outside the discs: it closes the arc and buys nothing |
| Arc open, live | 200 ms after opening | Discs full alpha. Start/Call is registered but disabled |
| Disc affordable | Gold at least the cost | Cost shown plain |
| Disc unaffordable | Gold below the cost | Alpha at the floor (**0.6, HQ-01**), cost struck through, updated live as gold changes |
| All discs unaffordable | Gold below every cost | All three dimmed and struck through. The arc stays open; a tap on a disc is refused (below) |
| Disc refused | `build` returns `NO_GOLD` | Arc stays open. The 2 px nudge for 120 ms (skipped under Reduce Motion) **and** the refusal cue (proposal, UQ-01) |
| Disc committed | `build` returns `OK` | Arc closes and unregisters at once; 120 ms collapse (art); new tower on the first frame with the build overlay; range ring 400 ms then a 200 ms fade |
| Arc closed by dismiss | Press outside, drag, guard | No collapse (a cut; proposal) |
| Chip closed | Default for a tower | No chip |
| Chip open, guard | Tower tap, first 200 ms | **Guard look (proposal):** panel at alpha 0.5, stepping to full at 200 ms. A tap on the tower or the chip is ignored; the window keeps running |
| Chip open, live | 200 ms to 1,500 ms | Full alpha. The bar drains linearly |
| Chip unaffordable | Gold below the level-2 cost | Cost dimmed (alpha 0.6) and struck through, live. A commit returns `NO_GOLD`: the chip stays open and dimmed, the window does not restart, and the refusal cue plays |
| Chip expiring | The last frames before 1,500 ms | The bar reaches zero; the chip then closes |
| Chip expired | 1,500 ms | **Proposal:** a 120 ms fade out (a fade, kept under Reduce Motion). The disc unregisters |
| Chip committed | `upgrade` returns `OK` | Chip closes; the tower shows its level-2 inset on the first frame with the build overlay; range ring 400 ms then 200 ms fade |
| Level-2 tower tapped | `tap` on a level-2 tower | `tower_inspected`: range ring 1.5 s, solid 2 px cyan, alpha 0.5, plus the "Max" label (proposal, UQ-03); no chip |
| Max-level (explained) | Same | The label answers "why no chip" |
| Overlay closed by game | Paused, Won, Lost, Fatal, `HALTED` | Closes at once. The resume tap reaches nothing beneath |
| Reduce Motion | `reduce_motion` flag | No 2 px nudge, no scale 1.15 to 1 on the build overlay, arc collapse is a cut. Fades and the bar stay. The refusal cue is a brightness step, which stays (UQ-01) |
| Left-handed | `left_handed` flag | No change. The arc and chip do not mirror (only the burst button and its digit do) |
| Loading | n/a | Everything is read synchronously from Data and Tower |
| Empty | n/a | A battle with no towers defined is a content-test failure; a missing ID is Fatal |
| Error | `HALTED` or a bad read | The overlay closes; the Fatal screen replaces the HUD |

Range-ring states, from Tower Visual/Audio: arc open, one ring per distinct level-1 range; chip open, the current range plus the next level's at alpha 0.25; after a build or upgrade, 400 ms then a 200 ms fade; a level-2 tap, 1.5 s.

---

## Interaction Map

Mapping interactions for: **touch** (the desktop build's mouse stands in for it). Keyboard and gamepad are not supported.

| Component | Action | Input | Immediate feedback | Outcome |
|---|---|---|---|---|
| Free slot | Tap | Tap, TAP 200 | Arc opens on the next frame (guard look) | `slot_tapped`; arc state Open |
| Arc disc | Tap whose **press** is at 200 ms or later after the arc opened | Tap, TAP 300 | Gold falls; tower appears on the first frame; arc collapses | `build(slot_index, tower_id)` returns `OK` |
| Arc disc | Tap while unaffordable | Tap, TAP 300 | Nudge (unless Reduce Motion) plus the refusal cue; arc stays open | `build` returns `NO_GOLD`; nothing changes |
| Arc disc | Tap whose **press** is under 200 ms after opening (released whenever) | Tap | Arc closes (a cut) | No `build` call |
| Arc backdrop | Tap or press outside the discs | Tap, TAP 250 sink | Arc closes | Dismiss; the later `tap` is ignored |
| Arc | Drag | `drag_started` | Arc closes | Dismiss; the drag then goes to whichever owner it started on |
| Level-1 tower | Tap | Tap, TAP 200 | Chip opens (guard look) | Chip state Open, window starts |
| Tower or chip | Tap whose **release** falls at `200 <= elapsed < 1500` ms | Tap | Gold falls; level-2 inset on the first frame; chip closes | `upgrade(slot_index)` returns `OK` |
| Tower or chip | Tap released under 200 ms | Tap | None | Ignored; the window keeps running |
| Tower or chip | Tap, unaffordable | Tap | Refusal cue; chip stays open and dimmed | `upgrade` returns `NO_GOLD`; window does not restart |
| Other tower | Tap while a chip is open | `pressed`, then `tap` | The first chip closes; that tower's own chip opens | Dismiss, then a new chip |
| Empty field | Tap while an arc is open | `pressed` naming the backdrop | Arc closes; no ground ring, because the backdrop takes the tap (Battle HUD Rule 14) | Dismiss |
| Empty field | Tap while a chip is open | `pressed` naming no target, then `ground_tap` | Chip closes; the ground ring draws if this is one of the first three ground taps of the battle | Dismiss |
| Level-2 tower | Tap | Tap | Range ring 1.5 s plus the "Max" label | `tower_inspected`; no chip |
| Start/Call | Press while an arc is open | `pressed` naming the backdrop | Ignored by Start/Call; the arc closes | Dismiss only, no command |

Navigation targets: none (no screens). Spec dependencies: `design/ux/hud.md` (Start/Call, prompts, bands), and the pin and aim spec for drags that begin on a hero beside a slot.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|------|--------------|--------------|-------|
| Level-1 cost of each of the three towers | Data (accessor by `def_id` and level 1) | Read | Read on opening and on `gold_changed` while open; never cached from when the arc opened (Tower Rule 5). Level 1 only, so nothing asks past a level count |
| Level-2 cost | Data (accessor, `level + 1`) | Read | Read only below the level count: `level_count(def_id)` is checked first (Data Rule 10), because a read past the last level is Fatal |
| Current gold | Tower (`gold()`, `gold_changed`) | Read | Event-driven: each change redraws the dim and strike |
| Tower IDs and role tags | Data | Read | The disc whose shape matches a role tag calls `build` with that tower's ID |
| Slot position and index | Stage record; Tower (`slot_state()`) | Read | Fixed per stage |
| `chip_state()` | Tower | Read | Slot, elapsed time, window length (1,500 ms), level. The HUD holds no copy of the window |
| Range of each tower, per level | Data | Read | For the range rings |
| Tower level | Tower (`slot_state()`) | Read | Decides chip vs Max label |
| `build(slot_index, tower_id)` and `upgrade(slot_index)` | Tower | **Write (commands)** | Between ticks, from the input call stack. Results: `OK`, `HALTED`, `BAD_SLOT`, `BAD_TOWER`, `SLOT_OCCUPIED` or `NO_TOWER`, `MAX_LEVEL`, `NO_GOLD` |

No data element is owned by the UI. The HUD keeps only presentation state (arc open or closed, the guard clock, the ring states). Persistent state: none; gold and towers exist for one battle and are rebuilt on retry.

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Tap a free slot | `slot_tapped` | `slot_index` |
| Tap a disc | none directly; the HUD calls the `build` command | `slot_index`, `tower_id`. On `OK` Tower emits `gold_changed` then `tower_built` |
| Tap tower or chip to upgrade | none directly; TowerInput calls `upgrade` | `slot_index`. On `OK` Tower emits `gold_changed` then `tower_upgraded` |
| Tap a level-2 tower | `tower_inspected` | `slot_index` |
| Refused tap, dismiss, guard-ignored tap | none | A refusal changes and emits nothing (Tower Rule 5) |
| Any of the above | Analytics: none | No network or analytics at MVP |

Debug builds only: Battle HUD Rule 19 appends a record per attempt (towers built), and the gesture log (Input Rule 13) listens to `tower_upgraded` and reads `chip_state()` at each tower prompt. Neither can change a result. No action here modifies persistent game state (nothing is saved at MVP), so no action needs architecture review for saves.

---

## Transitions & Animations

Durations are the GDDs' unless marked **(proposal)**. Under Reduce Motion, motion is cut and fades stay.

| Transition | Normal | Reduce Motion | Source |
|---|---|---|---|
| Arc appears | On the frame after `slot_tapped`; no slide | Same | Game Feel ("answers on the next frame"); proposal that no open animation is added |
| Arc disappears on a build | 120 ms collapse (art only; the arc unregisters at once) | Cut | HUD Rule 7; Tower UX flag |
| Arc disappears on a dismiss | Cut | Cut | Proposal |
| Guard look | Alpha 0.5 for 200 ms, then a step to full | Same (a step, not motion) | Proposal, matching P-08 |
| Refused disc or chip | 2 px nudge, once, 120 ms; **plus** the refusal cue | Nudge skipped; the cue stays | Tower UI Requirements; proposal for the cue |
| Refusal cue | The refused cost steps to full alpha and a 3 px neutral outline appears on the panel for 120 ms, then returns to the dim; at most one per disc or chip per 400 ms (keeps it under 3 flashes per second) | Same | Proposal (UQ-01) |
| Build overlay | White overlay alpha 0.6 on the tower's first frame, scale 1.15 to 1 over 120 ms | No scale: the overlay alone fades from 0.6 to 0 over 120 ms | Tower Visual/Audio; proposal for the fallback |
| Upgrade overlay | Same overlay; the level-2 inset is present from the first frame | Same fallback | Tower Visual/Audio |
| Range ring after build or upgrade | Visible 400 ms, then a 200 ms fade | Same (a fade) | Tower Visual/Audio |
| Chip appears | On the frame after the tap | Same | Proposal |
| Chip bar | Drains linearly over 1,500 ms (a clock) | Same | HUD Rule 9; art bible 7 |
| Chip disappears on expiry or dismiss | 120 ms fade | Same (a fade) | Proposal (UQ-12) |
| Chip disappears on a commit | Cut; the overlay on the tower takes the eye | Same | Proposal |
| Level-2 range ring and "Max" label | 1.5 s, then a 200 ms fade | Same | Tower UI Requirements; proposal for the label |

No animation here loops, glows or flashes above 3 Hz. The refusal cue is a single 120 ms brightness change, capped at one per 400 ms.

---

## Input Method Completeness Checklist

**Touch** (also the desktop build's mouse): the only supported method.

- [x] Every control is reachable by a tap: slot, tower, disc, chip, backdrop.
- [x] Hit targets: arc disc 72 units across, which is exactly 48 dp at a 360 dp width and grows on wider phones (see Accessibility). Chip disc 80 units, 53.3 dp at 360 dp. Slot and tower 72 units.
- [x] Dismiss by tapping elsewhere (backdrop sink) or by dragging.
- [x] Motion alternatives: the nudge is optional (Reduce Motion), the cue is not motion.
- [ ] Android system back (button or gesture) in battle and with an overlay open is **undefined**: no document says what it does (UQ-08).
- [ ] A press that begins on an arc disc and is released on another: the GDD says "a finger rolling off a disc leaves it open"; whether the disc under the release is committed is not stated beyond that rule (UQ-13).
- [ ] Minimum width 360 dp at which arc discs meet exactly 48 dp has no margin; confirm on a device (PQ-02).

**Keyboard, gamepad:** not supported; there is no focus order, no focus trap and no controller-disconnect state, because every action is a disc (Battle HUD, Deliberately not built).

---

## Accessibility

Cross-reference: `design/accessibility-requirements.md` (tier Standard, phased; the Basic subset is the MVP baseline).

| Check | Result |
|---|---|
| Target size | Arc disc 72 units = 48.0 dp at 360 dp, 54.9 dp at 412 dp, 57.3 dp at 430 dp (the field scales with width: dp per unit = width / 540). Chip disc 80 units = 53.3 dp at 360 dp. Exactly at the limit on the narrowest phone |
| Text size | Panel text 14 dp (the floor) for word and cost; chip cost 16 dp. Both at or above the floors |
| Text contrast | Neutral `#C8D0E0` on panel `#141B30`: 11.0:1. Dimmed cost at alpha 0.6: 4.80:1 passes; at the GDD's 0.55: 4.25:1 fails (HQ-01). **This spec uses 0.6** |
| Non-text contrast, tower contour | Cyan `#2EC4D6` 3 px contour on panel: 8.1:1 |
| Non-text contrast, range ring | Solid 2 px cyan at alpha 0.5 over a path assumed to be the field colour with its value raised 3 points (about `#0E1428`; the art bible gives only "about 3% lighter"): computed 3.05:1, just over the 3:1 minimum. The next-level ring at alpha 0.25 computes 1.65:1, under 3:1 (UQ-11). Contrast also varies with each stage's field hue |
| Colour independence | All three arc discs are cyan; the choice is carried by shape (triangle, hexagon, square) and by the word on the panel. Unaffordable is carried by the strike-through, not the dim alone. The guard look and the refusal cue are brightness steps with an outline, not hue |
| Timed input | The chip's 1.5 s commit window is the one timed input. An expired chip loses nothing; the player taps again. A window multiplier (1x, 2x, 3x) is planned for Alpha (accessibility requirements). The arc has no timer |
| Reduce Motion | Nudge skipped, build overlay scale skipped, arc collapse becomes a cut. Fades (ring, chip, overlay) and the bar stay. A refusal cue that is not motion exists (UQ-01), which the Tower GDD required |
| Photosensitivity | No flash above 3 Hz: one 120 ms cue per disc or chip per 400 ms; the build overlay fades once |
| One-handed | Every action is one tap or one drag; the arc opens above the slot so the thumb does not cover it |
| Screen reader | The arc and chip are drawn in the field and cannot be labelled. Known limitation (accessibility requirements) |
| Focus order | Not applicable (touch only) |

---

## Localization Considerations

Strings are fixed English at MVP; a localization path is deliberately not built (Battle HUD, Deliberately not built). The constraints below matter when that changes.

| Element | Constraint | 40% expansion |
|---|---|---|
| Arc panel word ("Single", "Splash", "Slow") | 80 x 56 panel, 14 dp, one line. "Splash" (6 letters) leaves about 5 units each side (estimate, see Text Fit) | "Splash" has 6 characters; at +40% it is 8 or 9, which overflows. **HIGH PRIORITY** if localised: allow two lines or widen the panel (the panels are 3 units apart, so widening needs the discs apart) |
| Arc panel cost | 1 to 3 digits, tabular numerals | No expansion; numbers need locale-neutral formatting only |
| Chip cost | 16 dp, 1 to 3 digits in an 84 x 44 panel (proposal; 76 fits only 2 digits) | None |
| "Max" label (proposal) | 3 characters, 14 dp | Low risk |

---

## Acceptance Criteria

Each can be checked by a tester with a build and the numbers here. Positions are field units at inset 0; "dp" assumes a 360 dp width unless stated. `S` is the tapped slot's centre.

- [ ] **Arc geometry.** Tapping a free slot opens an arc on the next frame (within 16.6 ms at 60 fps) with three discs at `S + (-83.1, -48)`, `S + (0, -96)` and `S + (+83.1, -48)` (within 0.1), showing a triangle, a hexagon and a square left to right, in that order, with the right-handed and left-handed setting alike.
- [ ] **Panels.** Each disc has a panel above it with two lines: the words "Single", "Splash" and "Slow" and that tower's current cost; panel text is at least 14 dp and the panels do not overlap each other or any disc.
- [ ] **Hit areas.** A press within 36 units of a disc's centre selects it; a press in the 24-unit gap between two discs selects neither and closes the arc without a purchase (the backdrop takes it); each disc's diameter measures at least 48 dp at a 360 dp width.
- [ ] **Guard.** A second tap whose press lands on a disc under 200 ms after the arc opened (even if released later) closes the arc, buys nothing and leaves gold unchanged. At 200 ms or later a tap on a disc builds.
- [ ] **Build.** With gold at least the cost, tapping a disc reduces gold by exactly that cost, closes the arc, and shows the new tower at its slot on the first frame with a white overlay that fades over 120 ms (and scales from 1.15 to 1 unless Reduce Motion is on).
- [ ] **Unaffordable disc.** A disc whose cost exceeds gold shows its cost struck through and dimmed to at least alpha 0.6 (depends on HQ-01: the GDD's 0.55 gives 4.25:1 and fails this; 4.5:1 against the panel); tapping it leaves the arc open and gold unchanged, and shows a visible cue even with Reduce Motion on. Raising gold above the cost makes the disc live at once.
- [ ] **Dismiss.** A press anywhere off the discs, or a drag, closes the arc without a purchase; pausing the app closes it; a change from Build to Wave or Intermission to Wave leaves it open; Start/Call does nothing while it is open.
- [ ] **Chip open.** Tapping a level-1 tower opens a chip centred 76 units above it, showing the level-2 cost, a level-2 glyph and a bar that drains from full to empty in 1,500 ms. Only one chip is open at a time.
- [ ] **Chip guard and commit.** Tapping the tower or chip under 200 ms after it opened does nothing and the window keeps running. A tap between 200 and 1,499 ms, with gold at least the level-2 cost, upgrades the tower, reduces gold by that cost, closes the chip and shows the level-2 inset on the first frame.
- [ ] **Chip expiry.** At 1,500 ms the chip disappears. Tapping the tower then opens a new chip and does not upgrade. A press held past 1,500 ms does nothing.
- [ ] **Chip unaffordable.** With gold below the level-2 cost, a tap in the window leaves the chip open, dimmed and struck through, does not restart the bar, and shows the refusal cue.
- [ ] **Chip switching.** With a chip open on tower A, tapping tower B closes A's chip and opens B's chip; tapping empty field closes A's chip.
- [ ] **Max level.** Tapping a level-2 tower shows its range ring for 1.5 s and opens no chip; it also shows the label "Max" (proposal, UQ-03).
- [ ] **Guard look (proposal, UQ-02).** For 200 ms after an arc or chip opens, its discs, panels or chip draw at alpha 0.5, then step to full; no fade between.
- [ ] **Range rings.** With an arc open, one ring per distinct level-1 range is visible under the entities; with a chip open, the current range ring plus the next at alpha 0.25; after a build or upgrade, a ring visible at 400 ms and gone by 600 ms.
- [ ] **Reduce Motion.** With the flag on, no 2 px nudge, no scale on the build overlay and (proposal, UQ-01 and HUD HQ-04) no arc collapse animation play; a refused tap still shows the cue; the bar, ring fades and overlay fade still play.
- [ ] **Closing by the game.** Pausing, winning, losing or a fatal error closes any arc or chip at once, and the tap that resumes cannot commit a purchase.
- [ ] **Never off the field.** For every slot allowed by the content rules (x 156 to 384, y 304 to 924), the whole arc (discs and panels) and the chip lie within x 0 to 540 and y 0 to 960, and the chip never overlaps the top band.
- [ ] **Budget.** With an arc open, the whole HUD uses at most 12 draw calls and at most 3 text draws on a device.
- [ ] **Resolution.** At 540 x 960 and at a 360 x 800 dp phone, no arc or chip element is clipped by the screen edge, and no press inside a disc is rejected as an edge press at the extreme slots (x 156 and 384).

---

## Open Questions

| ID | Question | Owner |
|---|---|---|
| UQ-01 | **Refusal cue (proposal).** The Tower GDD requires a cue that does not rely on motion. Proposed: the refused cost steps to full alpha with a 3 px neutral outline for 120 ms, at most once per 400 ms. Confirm, or choose another (for example a short neutral outline only). Closes HQ-04 and AQ-10 when accepted | ux-designer, game-designer |
| UQ-02 | **Guard look (proposal).** Showing the arc and chip at alpha 0.5 for the first 200 ms makes the guard visible but may make the overlay feel sluggish. Test in the phone build; fallback is no visible guard | ux-designer, phone test |
| UQ-03 | **"Max" label is a new string.** The Tower GDD only says the level-2 tap shows a range ring so the tap is not silent. The label tells the player why no chip appears. It needs adding to the HUD and Tower GDDs | game-designer |
| UQ-04 | **Chip bar thickness.** The GDD sets 3 units (2 dp). Whether it reads under a thumb is a device question. Fallback: 6 units | ux-designer, phone test |
| UQ-05 | **Arc panels over the lane.** In Wave at slot (270, 305) the arc panels cover the lane, against the art bible's rule that the lane is never under a panel (HQ-17). Options: accept (panels are brief and the clock is stopped in Build only), raise panel transparency, or shift the arc | art-director |
| UQ-06 | **No refund for a wrong disc** (user decision, 2026-11-04; Tower Rule 4). This spec adds no undo. Watch the mis-fire rate in the Pillar 4 test; fallbacks in order are a larger hit radius (44), then a 1.5 s refund | game-designer, phone test |
| UQ-07 | **Should arc panels become tap targets?** A tap on a panel's word dismisses the arc today (Battle HUD edge case; HQ-05, PQ-08). This spec keeps that, so the word a player reads is not a target | ux-designer |
| UQ-08 | **Android system back** with an overlay open (PQ-10, HQ-07). Candidate: back closes the overlay first, then pauses | game-designer |
| UQ-09 | **Panel text overflow if localised** ("Splash" at +40%) | localization-lead, later |
| UQ-10 | **No player-journey document.** Context on arrival is inferred from the GDDs and prompts | ux-designer |
| UQ-11 | **Range ring contrast.** The current-level ring computes 3.05:1 over the path (just passing) and the next-level ring at alpha 0.25 computes 1.65:1 (fails 3:1). Alpha 0.4 gives 2.38:1, and 3:1 needs about 0.5, the same as the current ring, which would make the preview as loud as the real range. The path colour is an assumption (see Accessibility), and the result also depends on each stage's field hue. Decide, and add a per-stage contrast check to the content test | art-director |
| UQ-12 | **Chip closing fade (proposal)** of 120 ms on expiry or dismiss; the GDDs say the chip closes but not how | ux-designer |
| UQ-13 | **Roll-off from a disc.** A press on one disc released on another: confirm the disc under the release does not commit unless it also received the press | game-designer, Input |
| UQ-14 | **Start/Call 78.5 units from the arc** at the starter layout; rechecked if `R` grows. If the phone test forces `R` up (UQ-06), recheck the content rules | game-designer |
| UQ-15 | Arc discs are exactly 48 dp across at a 360 dp width, with no margin (Input Method Checklist; PQ-02). Confirm on the narrowest supported phone | technical-director, phone test |
| UQ-16 | **Chip width (proposal).** Widen the chip panel from 76 to 84 units so a 3-digit cost fits beside the glyph; or add a content rule capping costs at 2 digits. Needs a Battle HUD GDD edit either way; confirm on a render once the font is chosen | game-designer, art-director |
| UQ-17 | **Unaffordable alpha.** This spec uses 0.6 (4.80:1); the approved GDD says 0.55 (4.25:1, under 4.5:1). Same question as HUD HQ-01 | game-designer |
