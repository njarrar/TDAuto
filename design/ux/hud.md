# HUD Design

> **Status**: In Design (autonomous draft, 2026-11-04; revised after three `/ux-review hud` passes the same day, the third aligning it with the Battle HUD GDD approved in PR #7)
> **Author**: ux-designer (autonomous mode; user to review)
> **Last Updated**: 2026-11-04
> **Conformed**: to the GDDs approved on 2026-11-04
> **Platform Targets**: iOS and Android, portrait, touch only (a mouse stands in for touch on the desktop development build at 540 x 960)
> **Template**: HUD Design
> **Source of truth**: `design/gdd/battle-hud.md` owns the rules, formulas and layout numbers. This document is the UX layer on top: it organises them as a HUD design, adds states, hierarchy, budget, feedback and accessibility, and records conflicts. Where a number appears here it is copied from that GDD (rule numbers in brackets) or computed from it, and the computation is shown. If the two ever differ, the GDD is right and this file is stale.
> **Related**: `design/ux/interaction-patterns.md` (pattern IDs P-nn), `design/accessibility-requirements.md`, `design/art/art-bible.md` sections 3, 4, 7

---

## HUD Philosophy

**Minimal, with the field as the display.** Anything that answers "what is happening in the field" is drawn in the field, anchored where it happens (leash, reticle, cooldown rings, range rings, the build arc at its slot). Only bookkeeping lives in screen space: lives, wave pips, gold, the burst button and Start/Call (art bible 7: "if a HUD element points at a position, it lives at that position").

The player never reads numbers to decide a fight. The HUD deliberately shows **no** damage numbers, HP bars, tower stats, spawn timings or hit counters [Rule 4]. It teaches three verbs with three one-line prompts [Rule 13] and then goes quiet. A resting thumb must never be punished: the bottom 30% of the screen holds only the burst button and the field, so the pinned thumb never hides the lower lane.

**Constraints this philosophy sets for every decision below:**
1. No element may cover the lane. Panels sit in the top band; the lane is never routed under a panel. Arc panels at slot (270, 305) are the open exception (HQ-17).
2. Screen-space colour stays neutral; cyan, orange, gold, violet and magenta each mean one gameplay fact and appear in the field (art bible 4).
3. Nothing in screen space loops, glows or animates counters. Digits swap; they never bounce.
4. Every control is a 48 dp target, and every state has a non-colour cue.

---

## Information Architecture

### Full Information Inventory

Drawn from the UI Requirements sections of all 8 GDDs. Combat, Data & Config and Enemy & Wave own no screen; Flow, Tower and Hero supply state that the Battle HUD draws; Input supplies the hit-target rules.

| # | Information | Source system | Owner of the value |
|---|---|---|---|
| 1 | Lives remaining | Flow (`lives_changed`) | Flow |
| 2 | Wave progress (pips) | Flow, Enemy & Wave (`wave_index()`, `wave_ids` size) | Flow, Enemy & Wave |
| 3 | Gold | Tower (`gold_changed`) | Tower |
| 4 | Next-wave line (glyph and count per enemy type) | Wave records | Enemy & Wave |
| 5 | Start / Call button, with the early-call bonus, the seconds left and a burst glyph | Flow, Tower (`early_call_bonus`) | Flow, Tower |
| 6 | Burst button: Locked, Ready, Telegraphing, Cooling (returning fill and digit) | Hero (`burst_state()`, `cooldown_left()`), Data (Burst `cooldown`) | Hero |
| 7 | Build arc: three tower discs, their words and costs | Tower (`build`), Data (costs) | Tower |
| 8 | Upgrade chip: cost, level-2 glyph, draining bar | Tower (`chip_state()`) | Tower |
| 9 | Tower range rings (inspect, arc open, chip open, after build) | Tower, Data | Tower |
| 10 | Tower and hero state rings (ready, cooling); tower level-2 inset (outline at 60% scale, 3 px) | Tower, Hero | Tower, Hero |
| 11 | Hero field visuals (leash, pin ghost, reticle, radius preview, reach ring, kill preview, Ready ticks) | Hero | Hero (its own view) |
| 12 | Enemy glyphs, danger chevrons, hit flashes | Enemy & Wave, Combat | Enemy & Wave, Combat |
| 13 | First-time prompt (one line) | Hero, Tower | Battle HUD |
| 14 | Ground-tap rejection ring | Input (`ground_tap`) | Battle HUD |
| 15 | Result: Won or Lost text, got-through glyphs (Lost only), damage by source | Flow, Combat, Enemy & Wave, Tower | Battle HUD |
| 16 | Paused screen | Flow | Battle HUD |
| 17 | Fatal screen | Flow | Flow (generic, catalogue-free) |
| 18 | Hero share of damage as a percentage | Combat | Not shown (balance metric; log only) |
| 19 | Build slots: free, blocked, selected (outline alpha 0.6) | Tower, Stage record | Tower (field view) |
| 20 | Debug run log and gesture log | Battle HUD Rule 19; Input Rule 13 | Dev builds only; no screen |

### Categorization

| Category | Items | Why |
|---|---|---|
| **Must Show** (always while it applies) | 1 lives, 2 pips, 3 gold, 6 burst button (Build, Wave, Intermission; Paused shows the phase it left), 5 Start/Call (Build and Intermission), 12 enemy glyphs, 10 state rings, 19 build slots | The player decides with these on every wave. Lives, pips and gold are always on, short of Fatal, which hides all of it; the others follow the phase [Rule 4] |
| **Contextual** | 4 next-wave line (Build and Intermission), 7 build arc (slot tapped), 8 upgrade chip (tower tapped, 1.5 s), 9 range rings, 11 Hero field visuals (while aiming or pinned), 13 prompt (until its act is done), 14 ground ring (first three taps), 15 result (outcome), 16 Paused (focus lost), 17 Fatal | Shown only when the situation calls for them |
| **On Demand** | none | There is no menu, toggle or hold-to-reveal at MVP. Tapping a level-2 tower shows its range ring for 1.5 s, which is the closest thing, and it is contextual |
| **Hidden** | Damage numbers, HP bars, tower stats, spawn timings, hit counters, hero share percentage, 20 the debug logs | Deliberately never on screen [Rule 4, Rule 15]. The human log keeps hero share and median kills; the logs are files, written in debug builds only |

**Two axes.** Category (above) says *when* an item shows. The priority tier in Information Hierarchy says *what is dropped first* when space or budget runs out. An item can be Must Show and still sit in SHOULD KEEP: pips always show, but are the first of the always-on items to give way.

**UI systems not covered here, and why.** The systems index lists three systems in the UI category. This document covers Battle HUD & Build UI (#8). **Menu & Screen Flow (#15)** is Vertical Slice and has no GDD; it owns everything outside a battle, so it adds nothing to the in-battle HUD. **Visual Feedback & VFX (#19)** is Vertical Slice and has no GDD; it will own field effects (hit flashes, burst ring, kill spokes), which are field art rather than HUD, and any new screen-space feedback it proposes must be added here. Two related systems are outside the UI category: **Onboarding Prompts (#17)** is not needed at MVP because the three prompts here teach the verbs (Rule 13), and **Settings & Accessibility (#21, Alpha)** owns the toggles listed under Tuning Knobs.

**Conflict check against the philosophy.** Must Show is 8 items, three of which are the always-on top band. That fits "minimal". One tension is recorded: the burst button is a Must Show but is hidden on Won and Lost (nothing can fire) [Rule 4].

---

## Layout Zones

Field units on the 540 x 960 reference. `I_top` and `I_bottom` are the safe-area insets in field units (0 on desktop and at MVP). 1.5 units = 1 dp at a 360 dp width, so 72 units = 48 dp. [Layout table, GDD]

### Zone Diagram

Approximate, not to scale vertically. Phase shown: Intermission (Build is the same with "Start" and no countdown).

```
 x=0                                                        x=540   y
 +----------------------------------------------------------------+  0
 | TOP BAND  (panel, display only, ignores input)                 |
 | [lives ||||| ]    [pips o o o o o o]            gold 120      |  I_top+22/34
 |                [ Next: tri 3  hex 5  sq 2 ]                    |  I_top+53
 +----------------------------------------------------------------+  I_top+72
 |  [ Drag the hero ]  <- prompt, 300 x 34, centre (270, I_top+89)|
 |                                                                |
 |                    FIELD (path, slots, towers,                 |
 |                    enemies, hero)                              |
 |                                                                |
 |        (arc opens above a tapped slot, radius 96)              |
 |                                                                |
 |                                                                |
 |      [ Call +7 ]                                               |  y 800
 |      [ 12 s  * ]                                     ( BURST ) |  y 816..888
 +----------------------------------------------------------------+  960
   Start/Call: centre (186,800), rect 88x72      Burst: x 456 (84 if left-handed)
```

### Layout Zones (specification table)

| Zone | Rect / position (units) | Holds | Input | Source |
|---|---|---|---|---|
| Top band | y 0 to `I_top + 72`, at most 174 | Lives, pips, gold, next-wave line | None (Controls that ignore input) | [Layout] |
| Lives | x 24 to 156; 2 rows of 5 dashes, each 24 x 4.5, gap 3; row centres `I_top + 22` and `I_top + 34` | P-19 | None | [Layout] |
| Pips | 6 pills, each 20 x 10, gap 10, x 185 to 355, row centre `I_top + 22` | P-20 | None | [Layout] |
| Gold | right edge x 516, reserved from x 434, 16 dp digits | P-18 | None | [Layout] |
| Next-wave line | x 165 to 395, row centre `I_top + 53` | Glyph and count per type | None | [Layout] |
| Prompt | panel 300 x 34, one line, centre (270, `I_top + 89`) | P-17 | None | [Layout] |
| Field | everything between the band and the bottom | Path, slots, towers, enemies, hero, arc, chip, rings | Resolver discs | [Layout] |
| Start/Call | centre (186, 800), rect 88 x 72, corner 24, hit radius 48, both hands | P-08 | Resolver disc, priority 350 | [Layout] |
| Burst button | x 456 (84 left-handed); y = clamp(888 - `I_bottom`, 816, 888); 84 px visible, 96 px hit | P-10, P-14, P-15 | Resolver discs (drag 100; sink tap 400) | [Layout] |
| Lost panel | x 48 to 492, y 200 to 752; Retry 128 x 72 at (270, 700) | P-11 | Modal Control | [Layout] |
| Won panel | x 48 to 492, y 744 to 944, moved up by `B = min(I_bottom, 72)`; two columns from y 756 - `B` to 860 - `B`, rows 1 and 2 at x 64 to 262, damage rows at x 278 to 476; Play again 128 x 72 at (270, 904 - `B`) | P-11 | Modal Control | [Layout] |
| Paused | full-screen 40% scrim, centre panel 300 x 64 | P-11 | Modal Control | [Rule 17, Visual] |

**Zone rationale (UX alternatives; the GDD records only the choice).** Three arrangements were weighed against the philosophy.
- *Everything in the top band* (rejected): Start/Call is irreversible, and a button the thumb has to stretch to would be reached by mistake less often but would break one-thumb play.
- *Bottom bar with all controls* (rejected): it would cover the lower lane and the pinned thumb would hide it; the art bible reserves the bottom 30% for the burst button and the field.
- *Top band for bookkeeping, a single bottom-left button for Start/Call, burst in the dominant-hand corner* (chosen, and what the GDD specifies). Start/Call sits at x 186 so the burst corner stays free for either hand.

**Content rules that protect the layout** (checked by the content test on Stage records; GDD "Content rules"): slots x 156 to 384 and y 304 to 924 (starter 170 to 370, 305 to 700); arc disc to the burst line at least 84 (starter 164); arc disc to Start/Call at least 16 clear (78.5); Start/Call to any slot at least 16 clear (17.3); Start/Call to `hero_start` at least 48 (60); chip disc to Start/Call's hit disc at least 16 clear (88.7), since Start/Call's priority 350 would otherwise take an upgrade tap; chip disc to the burst button's hit disc at least 16 clear, either hand (122.4); a tower body clear of the Won panel at `B` 0 (clear up to `B` 16); arc panels clear of the band and prompt at inset 0 (they meet at `I_top` 11); at most 3 enemy types in the next-wave line; at most 6 waves and 10 lives.

---

## HUD Element Specifications

One row per element. "Pattern" refers to `design/ux/interaction-patterns.md`; "Tier" is the drop priority from Information Hierarchy.

| Element | Category | Zone | Source (owner) | Content | Visual form | Update | Trigger | Animation | Tier | Pattern |
|---|---|---|---|---|---|---|---|---|---|---|
| Lives | Must Show | Top band, left | Flow | Dashes, one per life | Two rows of 5 neutral dashes, 24 x 4.5 | Signal (`lives_changed`) | Always | A lost dash fades to alpha 0.2 in 200 ms and stays countable | MUST KEEP | P-19 |
| Pips | Must Show | Top band, centre | Flow, Enemy & Wave | Waves done, current, upcoming | 6 pills 20 x 10: filled done, outlined current, dotted upcoming | Signal (`phase_changed`, `wave_index()`) | Always | None | SHOULD KEEP | P-20 |
| Gold | Must Show | Top band, right | Tower | Integer gold | 16 dp tabular digits, right-aligned at x 516 | Signal (`gold_changed`) | Always | Digits swap; never count up or bounce | MUST KEEP | P-18 |
| Next-wave line | Contextual | Top band, second row | Enemy & Wave (Wave records) | "Next", then a glyph and count per type, order heavy, normal, fast, absent types omitted | Neutral glyphs at true size 16, 22 and 30 with the fast's notch; counts 14 dp | On phase change | Build, Intermission | None | SHOULD KEEP | none (pattern gap, HQ-14) |
| Start / Call | Must Show (Build, Intermission) | Bottom left, centre (186, 800) | Flow, Tower (bonus) | "Start" in Build. "Call +N" in Intermission (bare "Call" when N is 0), seconds left, burst glyph 16 px | Panel rect 88 x 72, 2 px neutral outline, two 14 dp lines | Frame, redrawn on a quantised key | Build, Intermission; hidden in Wave | Arming: alpha 0.5, stepping to full at Armed (panel opacity never animates, art bible 7). No pulse or advice once armed | MUST KEEP | P-08 |
| Burst button | Must Show (Build, Wave, Intermission) | Bottom corner, dominant hand | Hero, Data | State: Locked, Ready, Telegraphing, Cooling | Dotted outline (Locked); gold fill and full ring (Ready); fill 0 (Telegraphing); neutral outline with the gold fill returning as a clockwise sweep, `burst_fill = 1 - clamp(cooldown_left / max(1, to_ticks(cooldown)), 0, 1)`, and a seconds digit (Cooling). On a cooling press the digit shows above the thumb and the button is bare | Frame, redrawn on a quantised key | Hidden on Won and Lost; Paused shows the phase it left | 2 px nudge once, 120 ms, on a Locked press (skipped under Reduce Motion) | MUST KEEP | P-10, P-14, P-15 |
| Build arc | Contextual | Field, above the tapped slot | Tower, Data (costs) | Three tower discs and their word and cost | Triangle (Single), hexagon (Splash), square (Slow), left to right, radius 96 above the slot; panels 80 x 56 with two 14 dp lines; 3 px cyan contour | On open, and on `gold_changed` while open | Slot tap | 120 ms collapse on a build (art only) | MUST KEEP while open | P-06 |
| Upgrade chip | Contextual | Field, 76 above the tapped tower | Tower | Cost, level-2 glyph, draining bar | 76 x 44 panel, 16 dp cost, 20 px cyan polygon, neutral bar 3 units tall | Frame during its 1.5 s | Tap on a level-1 tower | Bar drains linearly | MUST KEEP while open | P-07 |
| Range rings | Contextual | Field, around a tower | Tower, Data | Tower reach | Solid unfilled outlines: arc open, one per distinct level-1 range; chip open, current plus next at alpha 0.25; after build or upgrade, 400 ms then a 200 ms fade; level-2 tap, 1.5 s | Event | As listed | Fade only | CAN HIDE | none (drawn by HudField; Tower Visual Requirements) |
| Prompt | Contextual | Below the band, centre (270, `I_top + 89`) | Hero, Tower (acts) | One of three lines | 14 dp, one line, on panel | Signals and the frame | First match of Rule 13; Build, Wave, Intermission | Hidden on its act, never on a timer | SHOULD KEEP | P-17 |
| Ground ring | Contextual | Field, at the tap | Input (`ground_tap`) | Rejection cue | 2 px neutral ring, radius 16, alpha 0.35 | Event | First three `ground_tap`s of a battle | 150 ms fade in, 600 ms hold, 200 ms fade out | CAN HIDE | P-16 |
| Result (Lost) | Contextual | Lost panel, x 48 to 492, y 200 to 752 | Flow, Combat, Enemy & Wave, Tower | "Broke on wave N of M", next-try line, "Got through" glyphs, Towers, Hero, Burst, Slowed, Retry | Plain 16 dp text, left-aligned, no headline; Retry the only filled shape, at alpha 0.5 until Armed, stepping to full, and lighter while a counting press is held so a slide-off shows | Once, on the first `advance` after the outcome | Lost | Text appears 400 ms after | MUST KEEP | P-11, P-08 |
| Result (Won) | Contextual | Won panel, x 48 to 492, y 744 to 944 minus `B` | Flow, Combat, Enemy & Wave, Tower | "Stage clear", "Lives N of M" (left column); Towers, Hero, Burst, Slowed (right column); Play again. No "Got through" row: it needs about 270 units against a 198-unit column, so the log keeps it (user decision, 2026-11-04) | Compact two-column panel, board visible above it; Play again looks and arms like Retry | Once | Won | Text appears 400 ms after; brighten sequence cut | MUST KEEP | P-11, P-08 |
| Paused | Contextual | Full screen | Flow | "Paused. Tap to resume" | 40% scrim, 300 x 64 panel | Instant | Focus loss | None | MUST KEEP | P-11 |
| Fatal | Contextual | Full screen | Flow | Generic failure text | Catalogue-free screen | Instant | Fatal | None | MUST KEEP | P-11 |

**Redraw and modal visibility** [Rule 1]. HudField redraws when a quantised key changes (every value `_draw` reads: fill in steps of 1/60 of a turn, digit and its position, bonus label and seconds, visible set, Locked and burst state, prompt, aim state, arming state, held press, affordability of each open disc and chip) and every frame while a timed visual runs: chip bar, ring fade, nudge, collapse. HudLogic owns which modal shows: it emits `modal_changed` (none, paused or result) synchronously with the phase change, and none on Fatal, and HudModals toggles visible on it.

**Drawn by other systems, not by this HUD.** Inventory items 10 (tower and hero state rings), 11 (hero field visuals), 12 (enemy glyphs, danger chevrons, hit flashes) and 19 (build slots) are drawn by the Tower, Hero, Enemy & Wave and Combat views. They appear in this document for the budget and hierarchy only; their specs live in those GDDs and, for the hero, in the pin and aim spec still to be written.

**Next-wave line detail.** Fixed order heavy, normal, fast; absent types omitted; no timings or groups, so convergences must still be seen in the field. The count is the total for the next wave. One wave ahead spoils little, and with no selling, blind buying is costly [Rule 5].

**Result text, exact order** [Rule 15]. Lost: (1) "Broke on wave N of M"; (2) the next-try line if any; (3) "Got through", a glyph and a count per type, omitting 0; (4) "Towers N", "Hero N", "Burst N", rounded half up, then "Slowed N" if a slow tower was built; (5) Retry. Won: (1) "Stage clear"; (2) "Lives N of M", both in the left column; (3) omitted on screen and kept in the log; (4) the damage rows as the right-hand column; (5) Play again. No percentages, bars or highlights.

**Next-try line, first match** [Rule 16]: never pinned, "Next try: drag the hero"; no tower built, "Next try: tap a slot to build"; no burst fired, "Next try: drag from the corner button"; otherwise the type that cost the most lives, if its role is not yet built: heavy "Triangles hit big enemies", normal "Hexagons hit groups", fast "Squares slow fast enemies". Ties go heavy, normal, fast.

---

## HUD States by Gameplay Context

The game has no exploration, dialogue or cutscene. The four contexts the review checks map as: **exploration** is Build and Intermission, **combat** is Wave, **dialogue or cutscene** is the Result modal (the only full-screen text), and **paused** is Paused. Fatal is added.

| Context | Clock | Always on | Added | Hidden | What changes on entry |
|---|---|---|---|---|---|
| Build (exploration) | Stopped | Lives, pips, gold | Burst button (Locked until a first pin), Start, next-wave line; at most one prompt line: prompt 1 while the hero is unpinned, else prompt 2 while no tower is built (prompt 2 hides while an arc is open) | Call | Start arms over 300 ms |
| Wave (combat) | Running | Lives, pips, gold | Burst button; at most one prompt line: prompt 1 while the hero is unpinned, else prompt 3 once the burst is Ready and none has fired | Start/Call, next-wave line | Start/Call is hidden |
| Intermission (exploration) | Running | Lives, pips, gold | Burst button, "Call +N", seconds left, next-wave line; at most one prompt line: prompt 1 while the hero is unpinned, else prompt 2 while no tower is built | none | Call arms over 300 ms |
| Paused | Stopped | Lives, pips, gold; the burst button as the phase it left; Start/Call and the next-wave line if that phase had them; all frozen | 40% scrim and "Paused. Tap to resume" | Prompt (none in Paused); arc and chip are closed | Instant. Start/Call's arming clock is held, not reset. The Paused screen has no arming: a counted release resumes |
| Won | Stopped | Lives, pips (all done), gold | Won panel, Play again | Burst button, Start/Call, prompt | Brighten sequence cut; text after 400 ms |
| Lost | Stopped | Lives, pips, gold | Lost panel, Retry | Burst button, Start/Call, prompt | Text after 400 ms |
| Fatal | Stopped | none | Generic fatal screen | Everything else | Overrides Won, Lost and Paused |

### State variants of individual elements

| Element | Variant | Trigger | What changes |
|---|---|---|---|
| Burst button | Locked | Build, or before a first pin | Dotted outline, no fill, no digit; a press nudges 2 px once and, before a first pin, repeats prompt 1 |
| Burst button | Ready / Telegraphing / Cooling | `burst_state()` | See the element table |
| Gold / cost | Unaffordable | Gold below cost | Dimmed (alpha in Tuning Knobs, HQ-01) and cost struck through, live |
| Build arc | Disabled Start/Call | Arc open | Start/Call registers but ignores presses; enables when the arc closes |
| Start/Call, Retry, Play again | Arming | 300 ms after appearing | Alpha 0.5, stepping to full at Armed; a press begun now never counts. Paused has no arming (user decision, 2026-11-04) |
| Retry, Play again | Press held | A counting press is held | Lighter, so a slide-off shows |
| Lives | Low | One life left | No change to the HUD; urgency is carried by in-field chevrons (art bible 7) |
| Pips | Empty | Before any wave | Pip 1 is current in Build |
| Empty data | Next-wave line | No waves left | The line is omitted |

---

## Information Hierarchy

When a state would exceed the budget or a safe-area inset squeezes the layout, drop from the bottom of this table first.

| Tier | Element | Reason | What carries the information when hidden |
|---|---|---|---|
| MUST KEEP | Lives | Loss condition | Nothing; visible in every phase but Fatal |
| MUST KEEP | Gold | Every build decision | Nothing |
| MUST KEEP | Burst button | The hero's one verb | Nothing |
| MUST KEEP | Start/Call (Build, Intermission) | The only way to start a wave | Nothing |
| MUST KEEP | Build arc, while open | The only way to build | Nothing; it closes, never hides |
| MUST KEEP | Upgrade chip, while open | The only way to upgrade | Nothing; it closes, never hides |
| MUST KEEP | Result and Retry or Play again; Paused; Fatal | The only way forward | Nothing |
| MUST KEEP (other systems) | Enemy glyphs, danger chevrons; tower and hero state rings; build slots | The battle itself | Nothing; never dropped by the HUD |
| MUST KEEP (other systems) | Hero field visuals while pinning or aiming (leash, reticle, preview, reach ring) | The hero's drag needs them | Nothing |
| SHOULD KEEP | Pips | Progress, not a decision | The next-wave line and the lane |
| SHOULD KEEP | Next-wave line | One-wave lookahead for buying | Nothing until the next wave appears in the field |
| SHOULD KEEP | Prompt | Teaches three verbs | The next-try line on the result |
| CAN HIDE | Range rings | Aids a build choice | Nothing; reach is learned by watching a tower fire |
| CAN HIDE | Ground ring | Cue for the first three missed taps | Nothing |
| CAN HIDE (other systems) | Hit flashes | Feedback, not information | Damage is still applied and seen as enemies fall |
| ALWAYS HIDE | Damage numbers, HP bars, tower stats, spawn timings, hit counters, hero share; debug logs | Pillar 2 and the no-shame tone | The log |

---

## Visual Budget

| Budget | Limit | Source |
|---|---|---|
| Draw calls for the whole HUD | Expected 8, at most 12, of the project's 60 | HUD UI Requirements; `project.yaml` performance |
| Text draws | At most 3, one per size (24, 16, 14 dp) | HUD UI Requirements |
| Modals | Add about 4, inside the 12, since no arc or chip is open behind them | HUD UI Requirements |
| **Simultaneous HUD elements** | **At most 14** (provisional). Worst case today is 9: lives, pips, gold, next-wave line, burst button, Start/Call (disabled), prompt 1, build arc, range rings, in Build with the hero unpinned and an arc open | This document |
| **Screen share, screen-space HUD, live phases** | **At most 12.5%** (provisional). Worst case today 12.05% | This document |
| **Screen share including field-anchored HUD (arc panels or chip)** | **At most 15.5%** (provisional). Worst case today 14.64% | This document |
| Unverified | All draw-call counts are estimates; ADR-0011 measures them on a device | |

**Screen share, computed from the rects above** (540 x 960 = 518,400 sq units):

| Piece | Size | Share |
|---|---|---|
| Top band | 540 x 72 | 7.50% |
| Burst button | 84 x 84 | 1.36% |
| Start/Call | 88 x 72 | 1.22% |
| Prompt panel | 300 x 34 | 1.97% |
| Arc panels (3) | 3 x 80 x 56 | 2.59% |
| Upgrade chip | 76 x 44 | 0.65% (never open with an arc: a tower tap with an arc open is taken by the backdrop) |
| Won panel | 444 x 200 | 17.13% |
| Lost panel | 444 x 552 | 47.28% |

Per phase, live: Wave 8.86% (band, burst), plus the prompt 10.83%; Build and Intermission 10.08% (band, burst, Start/Call), plus the prompt 12.05% (the screen-space worst case), plus open arc panels 14.64% (the overall worst case). The Lost panel is the one large covering and is accepted because the clock has stopped and nothing is live. The ceilings were first proposed at 12% and raised to 12.5% because today's layout already reaches 12.05%.

**If a state exceeds the budget**, drop in the order of the hierarchy: ground ring, range rings, then the prompt, then the next-wave line.

---

## Feedback & Notification Systems

The HUD has no toasts or banners. The transient items are below. None queues: each is replaced, not stacked.

| Notification | Trigger | Position | Duration | Max at once | Priority | Queue behaviour |
|---|---|---|---|---|---|---|
| Prompt line | Rule 13 acts | Below the band, centre (270, `I_top + 89`) | Until the act, never on a timer | 1 | Low | First match only; the next match shows when its act is done. Prompt 2 also hides while an arc is open. Never queued |
| Ground ring | `ground_tap`, first three per battle | At the tap | 150 ms in, holds 600 ms, fades out over 200 ms (accepted 2026-11-04, HQ-13) | 1 per tap | Lowest | After the third, none. Resets on retry. A dismiss tap (arc backdrop) draws none |
| Refused-press nudge | `NO_GOLD` on a disc; a burst press while Locked | On the element | 120 ms | 1 per element | Medium | Dropped if another press arrives; skipped under Reduce Motion (**gap: needs a non-motion cue, P-12**) |
| Range ring (inspect) | Tap a level-2 tower | Around the tower | 1.5 s | 1 | Low | Replaced by the next ring state |
| Range ring (after build or upgrade) | `tower_built`, `tower_upgraded` | Around the tower | 400 ms hold, 200 ms fade | 1 per tower | Low | Replaced if a new state begins |
| Upgrade chip | Tap a level-1 tower | Above the tower | 1.5 s, draining bar | 1 | Medium | A second tower tap commits; a tap elsewhere closes it |
| Lost dash | `lives_changed` | In the lives rows | 200 ms fade | up to 10 | Medium | All fades run together; the dash stays countable |
| Result text | Outcome | Panel | Appears after 400 ms, stays | 1 | Highest | The result is shown once; Fatal overrides it |

---

## Platform Adaptation

| Topic | Rule | Source |
|---|---|---|
| Field space | All numbers are in 540 x 960 field units. The field scales with device width; a 360 dp phone has 1.5 units per dp. A taller phone letterboxes or reveals more field (**not yet decided**, QQ-02) | Input GDD; `architecture.md` |
| Insets | `I_top` and `I_bottom` are zero on desktop and at MVP. Until the Mobile Platform GDD exists, all inset behaviour below is a plan | HUD GDD |
| Top band | Grows with `I_top`: y 0 to `I_top + 72`, at most 174, which layout rule L6 holds | [Layout] |
| Prompt | Clear of the path up to `I_top` of 68 units (45 dp). Above that it overlaps the lane, by 34 units at most at `I_top` 102, and the Mobile Platform GDD owns the fix | [Layout] |
| Burst button | `y = clamp(888 - I_bottom, 816, 888)`; hit box at least 24 dp from the side edge and 16 dp above the OS gesture inset | [Layout]; art bible 7 |
| Won panel | Moves up by `B = min(I_bottom, 72)` | [Layout] |
| Edge rejection | Presses inside `edge_reject_margin` (default 36 units, domain 0 to 48) of a side edge or inside an inset do not count, including on modal screens | Input Rule 12; HUD Rule 2 |
| Desktop | Mouse stands in for touch; no hover state exists | Technical preferences |
| Keyboard, gamepad | Not supported; every game action is a disc | HUD GDD |
| Dropped on a platform | Nothing | |

**Per platform.** Cells marked "Assumed" are not backed by any source in this repository and must be confirmed on a device. Every value below is "to be measured" on a device; none is in the pinned engine reference, and `DisplayServer.get_display_safe_area()` is unverified on 4.7 (ADR-0003).

| Topic | iOS | Android |
|---|---|---|
| Top inset (`I_top`) | Assumed: status bar plus notch or Dynamic Island; varies by model. To be measured | Assumed: status bar plus display cutout (punch-hole or notch); varies by model. To be measured |
| Bottom inset (`I_bottom`) | Assumed: home indicator area. To be measured | Assumed: gesture navigation handle, or the 3-button bar when that mode is on (assumed larger). To be measured for both modes |
| Side edges | Assumed: no system back gesture from the side in a full-screen game. To be confirmed | Assumed: back gesture from both side edges in gesture navigation; the burst hit box ends at least 24 dp from the side (unverified) |
| System back | Assumed: none. To be confirmed | The back button or gesture in battle is undefined (HQ-07) |
| Landscape | Not supported; portrait only | Not supported; portrait only |
| Elements moved or dropped | None | None |

---

## Accessibility

Cross-reference: `design/accessibility-requirements.md` (tier Standard, phased; the Basic subset is the MVP baseline).

**Text size and contrast.** Text floor is 14 dp (21 units); 16 dp for gold, lives, labels and costs; 24 dp for the burst digit (floor 18 dp). Text sits on panel `#141B30` at 85% opacity. Contrast, computed from the art bible's hex values:

| Element | Foreground on panel | Ratio | Pass (4.5:1 text, 3:1 non-text) |
|---|---|---|---|
| Neutral text | `#C8D0E0` | 11.0:1 | Yes |
| Tower cyan contour (arc, chip) | `#2EC4D6` | 8.1:1 | Yes |
| Unaffordable text at alpha 0.6 | neutral at 0.6 | 4.80:1 | Yes |
| Start/Call, Retry, Play again during Arming (alpha 0.5 for 300 ms, then a step to full) | neutral at 0.5 | 3.75:1 | Below 4.5, but the state lasts 300 ms and the button cannot be used in it (advisory) |
| Ground ring (alpha 0.35, on the field) | neutral at 0.35 | 2.46:1 | Below 3:1; transient and non-essential (advisory, HQ-02) |
| Lost life dash (alpha 0.2) | neutral at 0.2 | 1.63:1 | Deliberately low: it means "lost". The remaining full dashes carry the count |

**Colour independence.** No state in the HUD relies on colour. Screen space is neutral. Unaffordable has a strike-through. Burst Ready vs Cooling differs by outline vs filled plus the returning fill and a digit. Pips differ by fill, outline and dots. Lives are counted by dashes. The arc's three towers differ by shape and word (all cyan).

**Reduced motion.** Under Reduce Motion (data flag `reduce_motion` until Settings exists) the HUD drops the 2 px nudges and the 12-unit panel slides and cuts the 120 ms arc collapse. Fades and clock bars stay: lost dash, ground ring, range-ring fades, cooldown sweep, chip drain bar. **Gap:** a refused press then has only the standing dim, so a non-motion refusal cue is needed (P-12, AQ-10).

**Focus order and keyboard.** Not applicable: touch only, every action is a disc. A hardware keyboard or gamepad path is out of scope for MVP (HUD GDD "Deliberately not built").

**Screen reader.** The top band is display-only `Control`s and can carry accessibility labels (lives, wave, gold). The field (`HudField`, a single `_draw`) cannot. The Result, Paused and Fatal screens are `Control`s and should be labelled. Verification on iOS and Android with Godot's AccessKit is open (AQ-05). The field limitation is recorded in the accessibility requirements.

**Text size option.** Standard requires an adjustable text size, but the HUD is built to three sizes, a 72-unit band and at most 3 text draws. Options: scale only the result and Paused screens and the band's labels; or reflow the band. Open (AQ-03, HQ-03).

**One-hand and handedness.** The whole HUD is reachable with one thumb. `left_handed` mirrors the burst button and its digit only; Start/Call stays at x 186 for both hands (7.2 units clear of the left burst's hit disc at the worst).

---

## Tuning Knobs

**Player-adjustable settings.** None at MVP. Two data flags on the Input record stand in for a settings screen: `left_handed` and `reduce_motion`. At Alpha, Settings & Accessibility adds these (from `accessibility-requirements.md`). No HUD scale, opacity or per-element show/hide option is planned.

| Setting | Range | Default | Affects |
|---|---|---|---|
| Reduce Motion | Off / On | Off | Nudges, slides, arc collapse, danger pulse, burst dip |
| Left-handed | Off / On | Off | Burst button and its digit move to x 84 |
| Chip window | 1x, 2x, 3x of 1.5 s | 1x | How long the upgrade chip stays open; the range ring after a level-2 tap follows it |
| Colourblind palette | Off / On | Off | Danger and enemy hues; scope to be decided (AQ-04) |
| Text size | To be decided (AQ-03, HQ-03) | 100% | Result, Paused and possibly the band's labels |
| Music volume | 0 to 100% | 80% | Audio (Alpha) |
| SFX volume | 0 to 100% | 80% | Audio (Alpha) |

**Designer constants** (all provisional until the phone test; none has a verified safe range):

| Constant | Value | Affects |
|---|---|---|
| Arming time | 300 ms | How long a new button ignores presses |
| Arc disc guard | 200 ms | A double tap that drifts onto a disc dismisses instead of buying |
| Arc radius `R` | 96 units | Panel legibility vs reach; chords leave 24 between discs of radius 36 |
| Chip window | 1.5 s, owned by Tower and read from `chip_state()`, so the HUD holds no copy and the Alpha multiplier needs no HUD change | The commit window for an upgrade |
| Result text delay | 400 ms | The beat before the result appears |
| `advance(ms)` clamp | 100 ms per frame | Stops a hitch arming an unseen button |
| Ground rings per battle | 3 | How long a new player is told a tap hit nothing |
| Unaffordable alpha | 0.6 (HQ-01, closed) | Legibility of a dimmed cost |
| Prompt count | 3 | How much the HUD teaches |

---

## Acceptance Criteria

Each can be checked by a tester with a build and the numbers here. Positions are field units at inset 0; "dp" assumes a 360 dp width.

- [ ] **Safe zone.** At inset 0 the top band occupies y 0 to 72 and the burst button's centre is at y 888, x 456 (x 84 with `left_handed`). With a bottom inset of 24 units the burst button's centre moves to y 864; with 100 units it stops at y 816.
- [ ] **Elements per phase.** Build shows lives, pips, gold, the burst button (dotted until a first pin), "Start" and the next-wave line, and not "Call". Wave shows lives, pips, gold and the burst button, and no Start/Call or next-wave line. Intermission shows "Call +N" (or "Call" when N is 0), seconds left, the next-wave line and the burst button. In Build, Wave and Intermission, at most one prompt line may also show: "Drag the hero" while the hero has never been pinned in this battle; then, in Build and Intermission, "Tap a slot to build" while no tower has been built (hidden while an arc is open); then, in Wave, "Drag from the corner button" once the burst is Ready and none has fired. Won and Lost show no burst button, no Start/Call and no prompt.
- [ ] **Budget.** With a build arc open, the HUD uses at most 12 draw calls and at most 3 text draws on a device.
- [ ] **Targets.** Every tappable or draggable target measures at least 48 dp (72 units) on a 360 dp phone: Start/Call, burst button, arc discs, chip, tower, slot, hero; and Retry's and Play again's rects (128 x 72) have a short side of at least 72 units, exactly at the limit.
- [ ] **Arming.** Pressing a newly shown Start/Call within 300 ms of it appearing does nothing, including when the finger lifts after 300 ms.
- [ ] **Double tap.** Double-tapping a slot so the second tap lands on a disc inside 200 ms closes the arc and buys nothing.
- [ ] **Unaffordable.** A disc or chip whose cost exceeds gold shows its cost struck through and dimmed, and the dimmed cost has a contrast ratio of at least 4.5:1 on the panel.
- [ ] **Result.** On a Lost, the modal stops every new press at once, the text appears 400 ms later in the stated order with no percentage, and Retry rebuilds the battle in one tap even if tapped twice. A Won shows "Stage clear" and "Lives N of M" in the left column and the damage rows in the right after 400 ms, with no "Got through" row, a compact panel and the board visible above it. Retry and Play again stay at alpha 0.5 and ignore presses for 300 ms after their text shows.
- [ ] **Paused.** Switching away from the app shows "Paused. Tap to resume" and no prompt line; a tap outside the rejected zones resumes and does not select a tower or move the hero; a finger held across the pause does nothing, even when lifted.
- [ ] **Reduce Motion.** With the flag on, a refused press shows no 2 px nudge and no panel slide, and the arc closes without the 120 ms collapse (proposal: the GDD does not yet say what Reduce Motion does to the collapse, HQ-04); the lost-life fade and cooldown sweep still play.
- [ ] **Colour independence.** With a battle screenshot passed through a protanopia and a deuteranopia simulator, these can still be told apart: burst Ready (filled, full ring) vs Cooling (outline, returning fill, digit); an affordable cost vs a struck-through cost; done, current and upcoming pips (filled, outlined, dotted); a full life dash vs a lost one.
- [ ] **Ground ring cap.** In a fresh battle, four taps on empty field show a ring for the first three and none for the fourth; a tap that dismisses an open arc shows none; after Retry, the count starts again at three.
- [ ] **Screen share.** In Build with the hero unpinned and an arc open, the HUD's screen-space pieces (band, burst button, Start/Call, prompt) cover no more than 12.5% of the screen, and with the arc panels no more than 15.5%.
- [ ] **Prompts.** "Drag the hero" shows until the first pin and never again in that battle; the other two prompts end on their act; none disappears on a timer.
- [ ] **Left-handed.** With `left_handed` on, only the burst button and its digit move; Start/Call and the arc stay put.

---

## Open Questions

| ID | Question | Owner |
|---|---|---|
| HQ-01 | Closed 2026-11-04: the GDD's unaffordable alpha is now 0.6, which gives 4.80:1 on panel. | closed |
| HQ-02 | Ground ring at alpha 0.35 computes to 2.46:1 on the field, under the 3:1 non-text minimum. It is a transient, non-essential cue; raise to about 0.5 (3.8:1 equivalent) or accept. | art-director |
| HQ-03 | Text size option vs the fixed HUD budget (see Accessibility). Which elements scale, and does the band reflow? | ux-designer, AQ-03 |
| HQ-04 | Closed 2026-11-04: the refusal cue (full-alpha cost with a 3 px neutral outline for 120 ms, at most once per 400 ms) is accepted and in the Battle HUD GDD. | closed |
| HQ-05 | Arc panels: do they become tap targets, or keep dismissing the arc (PQ-08)? | ux-designer |
| HQ-06 | Closed 2026-11-04: Paused has no arming (user decision in the Battle HUD GDD, Rule 2). Its cost is HQ-16. | game-designer |
| HQ-07 | What the Android back button or gesture does in battle (PQ-10). | game-designer |
| HQ-08 | Safe-area values on real devices, stretch mode and a taller phone (QQ-02); the prompt overlaps the lane above an `I_top` of 68 units. | technical-director, ADR-0003, Mobile Platform GDD |
| HQ-09 | Won panel sizes are unrendered; the two-column layout (left x 64 to 262, right x 278 to 476, rows 26 tall, at most four lines in the right column) fits 104 units against 104 available. Confirm by rendering at a 360 dp width with the longest strings. | art-director, ui-programmer |
| HQ-10 | Font is not chosen (tabular numerals, medium weight, geometric humanist, licence). It sets the text draw-call budget. | art-director |
| HQ-11 | Median kills stays out of the result because a 0 can read as shame (Rule 15). Confirm in the first phone test that a Hero 0 or Burst 0 row does not read as blame. | game-designer |
| HQ-12 | The Tower and Hero GDDs each carry UX flags that belong to the arc and chip spec and the pin and aim spec, not to this HUD document: chip bar readable under a thumb, a polygon plus digits in 56 px, range-ring contrast over the path, expired and armed chip looks, a maximum-level cue, a chip leaving the field, the unit-to-dp scale, reticle far from the thumb when clamped, preview overhanging the reach ring, ring clipping at 540 wide, reach-dot contrast, re-grabbing a high pin. Tracked as PQ-03 to PQ-05 in the pattern library. | ux-designer |
| HQ-13 | Closed 2026-11-04: the ground ring holds 600 ms and fades out over 200 ms, accepted and in the Battle HUD GDD. | closed |
| HQ-14 | The next-wave line has no interaction pattern. It is display only, so a short Display pattern ("Count by glyph") would let the menu screens reuse it. | ux-designer |
| HQ-15 | The visual-budget ceilings (14 elements, 12.5% screen-space, 15.5% with field overlays) are provisional and should be confirmed after the first phone build. | ux-designer, art-director |
| HQ-16 | With no arming on Paused, a brush can resume a live wave; and a resting palm that lifts on Retry or Play again would rebuild the battle and lose the Won screen. Both are logged in the Pillar 4 phone test; the fallback is a 300 ms clock on Paused. | game-designer, phone test |
| HQ-17 | Arc panels cover the lane in Wave at slot (270, 305), against the art bible's rule that the lane is never under a panel (Battle HUD Open Questions). | art-director, arc and chip spec |
| HQ-18 | "Burst N" is the only use of that word on screen and N is not labelled as damage; Won's right column has no spare row for a heading. | ux-designer |
| HQ-19 | Play again enters the bottom inset above `I_bottom` 92 and is wholly dead at 164, with no other exit; Won's panel overlaps tower bodies above `B` 16. | Mobile Platform GDD |
