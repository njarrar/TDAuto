# HUD Design

> **Status**: In Review (drafted 2026-11-05 in autonomous mode; `/ux-review` not run; specialist reviews owed, see Open Questions)
> **Author**: njarrar + ux-designer (autonomous run; decisions in `production/session-logs/decision-log.md`)
> **Last Updated**: 2026-11-05
> **Platform Targets**: Mobile (iOS, Android), portrait, one thumb, touch only; desktop dev build at 540 x 960, mouse as one finger (ADR-0003 2.2). No gamepad, no keyboard path.
> **Template**: HUD Design
> **Screen**: the battle screen (Build, Wave, Intermission, Paused, Won, Lost)
> **Sources**: `design/gdd/battle-hud.md` (Rules 1 to 19, Layout, Visual table, Tuning Knobs, ACs), `design/accessibility-requirements.md` (AR- IDs), `design/ux/interaction-patterns.md` (IP-01 to IP-29), `design/art/art-bible.md` §4 and §7, ADR-0011 (nodes, `HudLayer`, text, `ViewStyle`, budget), ADR-0003 (letterbox, `TapScreen`, insets), `design/gdd/game-concept.md` (pillars). Where this spec and a source differ, the source wins and the gap is an open item here.

**Units.** All positions are field units on the 540 x 960 field. At the smallest supported screen (360 dp wide) 1.5 units is 1 dp, so 14 dp is 21 units, 16 dp is 24 and 24 dp is 36 (ADR-0003 1, ADR-0011 Decision 6). `I_top` and `I_bottom` are the safe-area insets in field units, read once per battle and usually 0 (ADR-0003 3).

**What this spec adds.** The GDD and ADRs already fix every element, position, timing and colour. This spec adds four things: text sizes checked against AR-V-01 and the layout, the anchor and panel for the static refusal cue's text line (IP-24 left it open), the cooling-digit panel anchor, and the HUD's state, budget, notification and test tables. It adds no mechanic.

---

## HUD Philosophy

**Minimal and decision-only, with density set by phase.** The player's eyes and thumb are both on the lane, so the HUD must answer at a glance and never ask to be read (HUD GDD Overview). Only what a decision needs is on screen: bookkeeping sits in a thin top band, choices appear at the slot or tower that asked for them, and the one hero control sits under the thumb. Wave shows the least; Build and Intermission add the one button and the next-wave line, because that is when the player plans.

Three rules follow from it, and every later section obeys them:

1. **If it points at a place, it lives at that place** (art bible §7). Arc, chip, range rings and refusal cues sit on the field beside their object. Only the band, the burst button and Start/Call are screen-space.
2. **Nothing hurries or ranks the player.** No pulse, warning or advice on Start/Call once armed (Rule 10); no percentages, bars or highlights on the result (Rule 15, Pillar 2); prompts hide on the act, never on a timer (AR-C-03).
3. **Calm is a feature.** Nothing in screen space loops or glows (art bible §7). Motion is short (120 to 300 ms) and each motion has a still twin under Reduce Motion (AR-V-10).

**Who it is for.** Mid-core players aged 16 to 40, on a phone held in one hand, often on a commute with sound off (concept, Target Player Profile). No user research exists yet. All evidence is the hero-pin prototype and one developer on a mouse (Pillar 4: UNTESTED on a phone). The first phone build's Pillar 4 test (Input GDD P1) and the first-run test are the research this spec waits on; their questions are in Open Questions.

**Alternative considered.** An information-dense HUD (tower stats, damage numbers, spawn timers) would help optimisers, but it puts reading between the player and the lane and breaks Rule 4's cut list. Rejected by the GDD; recorded here so later systems do not reopen it without a pillar case.

---

## Information Architecture

### Full Information Inventory

Every on-screen item the eight system GDDs ask for. All eight have a UI Requirements section (8 of 8 matched): Combat, Data, Enemy & Wave and Input own no screen and hand their items to the HUD; Flow owns only the Fatal screen; Tower and Hero supply state the HUD draws.

| # | Item | Content | Source of the value | Asked for by |
|---|---|---|---|---|
| 1 | Lives | 2 rows of 5 dashes; lost dash at alpha 0.2 | Flow `lives_changed` | HUD Rule 4, Flow, Enemy & Wave |
| 2 | Wave pips | 20 x 10 pills: filled done, outlined current, dotted upcoming | Flow phase, `wave_index()`, `wave_ids` size | HUD Rule 4, Visual table |
| 3 | Gold | Tabular digits, top-right | Tower `gold()`, `gold_changed` | HUD Rule 4, Tower UI Req |
| 4 | Next-wave line | "Next", then glyph and total count per enemy type, fixed order | Wave records | HUD Rule 5, AR-C-05 |
| 5 | Burst button | Ready, Cooling (wedge, digit), Telegraphing, Locked (dotted) | Hero `burst_state()`, `cooldown_left()`, `pin_state()`, Flow `in_build()` | HUD Rule 12, Hero UI Req |
| 6 | Cooling digit on press | Seconds left, above the thumb, on panel | HeroInput `cooldown_digit()` | Hero UI Req, art bible §7 |
| 7 | Start/Call | "Start"; "Call +N" or "Call"; seconds left; burst glyph | Flow `intermission_left`, Tower `call_bonus()` | HUD Rules 10, 11 |
| 8 | Prompt line | One of three verb prompts | Hero, Tower, Enemy & Wave reads | HUD Rule 13, Hero UI Req |
| 9 | Build arc | Three role polygons; panels with word and cost; unaffordable strike | Data accessor, Tower `gold()` | HUD Rules 6 to 8, Tower UI Req |
| 10 | Upgrade chip | Cost, level-2 polygon, 1.5 s draining bar | TowerInput `chip_state()` | HUD Rule 9, Tower Rule 8 |
| 11 | Range rings | Solid current, dashed next level; inspect ring 1.5 s | HudLogic ring list (RangeRingView) | Tower UI Req, AR-V-06 |
| 12 | Ground ring | Dim ring for the first three ground taps | Input `ground_tapped` | HUD Rule 14, art bible §7 |
| 13 | Refusal feedback | Nudge, or the static cue under Reduce Motion | Tower `NO_GOLD`, Hero Locked | HUD Rule 7, AR-V-11, IP-24 |
| 14 | Result (Lost, Won) | Fixed-order text, Retry or Play again | `ResultSnapshot` | HUD Rules 15, 16, Combat UI Req, Flow UI Req |
| 15 | Paused | Scrim and "Paused. Tap to resume" | Flow phase | HUD Rule 17, AR-C-02 |
| 16 | Fatal screen | Generic fatal text | Flow | Flow UI Req, Data UI Req (not specced here) |

Drawn by other views, not the HUD, and listed so nothing is assumed missing: leash, reach ring, reticle, radius preview, kill contours, Ready ticks and the Ready-press ring at radius 64 (HeroView); tower rings and overlays (TowerView); chevrons (ExitStripView). The pin-and-aim and arc-and-chip specs own their detail.

### Categorization

| Category | Items | Why |
|---|---|---|
| **Must Show** | Lives, pips, gold, burst button | Rule 4 "Always". Lives and gold drive every spend; the burst button is the hero's only control |
| **Contextual** | Start/Call and next-wave line (Build, Intermission); prompt (until its act); cooling digit (on a cooling press); refusal cue (1 s after a refusal, Reduce Motion); ground ring (first three ground taps); result; Paused | Each appears only when its moment comes and hides on a rule, never on a whim |
| **On Demand** | Build arc (slot tap), chip (tower tap), inspect ring (tap on a level-2 tower) | The player asks with a tap; the arc and chip are the only spend paths |
| **Hidden** | Damage numbers, HP bars, tower stats, spawn timings, hit counters, wave number digit, gold icon, percentages, per-tower damage | Rule 4 and "Deliberately not built". Danger is told in the field by chevrons; a leak by the lost dash |

The Must Show list has four items in a 72-unit band plus one corner button. That fits the philosophy.

---

## Layout Zones

The GDD's Layout table is adopted unchanged; content rules L1, L3, L6, L7 and Stage `pin_exclusion` protect it (decision log: "Section C"). Values below are at `I_top` = `I_bottom` = 0; each `I_top +` row moves down with the inset.

```text
x:0                    185            355     434        540
y:0  +-----------------------------------------------------+
     | ===== =====     [] [] [] [] [] []           120 g   |  Z1 band: lives (row centres 22, 34),
     | ===== =====                                         |     pips (centre 22), gold (right 516)
     |            Next  > 10   o 20   O 4                  |     next-wave line (centre 53, x 165-395)
  72 +-----------------------------------------------------+
     |          [      Drag the hero       ]               |  Z2 prompt: panel 300 x 34, centre (270, 89)
 106 |                                                     |
     |              [ Need 20 gold ]                       |  Z3 field: refusal cue above the arc
     |               [Splash]                              |     arc panels and polygons above a slot
     |        [Single]  <H>  [Slow ]                       |
     |          <T>             <S>                        |
     |                 (slot)                              |
     |              . . . lane, slots, hero . . .          |
 764 |          +--------+                                 |  Z4 Start/Call: rect 88 x 72 at (186, 800)
     |          | Call +7|                     [ 9 ]       |     (Build and Intermission only)
     |          | 12  (o)|                     ( B )       |  Z5 burst: (456, 888) or (84, 888) left hand;
 960 +-----------------------------------------------------+     cue and digit panels above it
```

| Zone | Bounds | Holds | Input |
|---|---|---|---|
| Z1 Top band | y 0 to `I_top + 72` (at most 174, L6) | Lives, pips, gold, next-wave line | None: ignores input (Rule 1, IP-20) |
| Z2 Prompt strip | Panel centre (270, `I_top + 89`), 300 x 34 | Prompt line | None |
| Z3 Field overlay | The field, anchored to slots and towers | Arc, chip, range rings, ground ring, refusal cues | Input discs (arc, chip), backdrop sink |
| Z4 Start/Call | Rect x 142 to 230, y 764 to 836; hit radius 48 | Start/Call | TAP 350 disc |
| Z5 Burst corner | Centre x 456 (84 left hand), `burst_y = clamp(888 - I_bottom, 816, 888)` | Burst button, cooling digit, Locked cue | HeroInput disc (DRAG 100, tap sink) |
| Z6 Modal | Full screen, above `HudLayer` content | Lost panel (x 48 to 492, y 200 to 752), Won panel (x 48 to 492, y 752 to 944), Paused panel 300 x 64 at centre | `TapScreen` only |

The bottom 30% (y above 672) holds only the field, the burst button and, in Build and Intermission, Start/Call (art bible §7). The lane never routes under a band panel.

---

## HUD Element Specifications

### Text sizes (AR-V-01 check)

AR-V-01: 14 dp for any text, 16 dp for gold, lives, labels and costs, 18 dp floor for the burst digit. ADR-0011 Decision 6 allows three text batches, one per size: 21, 24 and 36 units. This spec keeps those three sizes and adds no 18 dp size, which would be a fourth batch. "Label" here means a word on a control or beside a price: Start/Call's lines, the arc's role words, the result and Paused text.

Width figures are estimates for a medium geometric humanist sans (about 0.5 em for lowercase, 0.6 em for tabular digits). The font is not chosen, so every row is rechecked at the first render (GDD manual render tests).

| Element | GDD today | This spec | Fits its box? |
|---|---|---|---|
| Gold digits | 16 dp | **16 dp** (24 u) | Yes: 5 digits about 72 of the 82 reserved (x 434 to 516) |
| Lives | dashes, no text | No text drawn | n/a: AR-V-01 names lives, but none is text (H-05) |
| Next-wave line, word and counts | counts 14 dp; "Next" unset | **14 dp** (21 u), one size for the line | Yes at 14 dp: starter wave 6 ("Next", 3 glyphs, counts 4, 20, 10) about 218 of 230. At 16 dp about 232: **breaks by about 2** (H-04) |
| Start/Call line 1 ("Start", "Call +N") | 14 dp | **16 dp** (24 u) | "Call +8" about 76 of 76 inside (88 less 2 px outline and 4 padding each side): **fits with no margin**. A two-digit bonus breaks (about 90). Starter maximum is +8 (15 s at 1.8 s per gold) (H-03) |
| Start/Call line 2 (seconds, burst glyph 16 px) | 14 dp | **16 dp** | Yes: two lines at pitch 26 plus 2 x 5 padding = 62 of 68 inside |
| Arc panel: role word | unset | **16 dp** | **Breaks** (H-01): "Splash" about 74 wide in a 60-wide panel, and two 16 dp lines need about 60 tall in a 44-tall panel |
| Arc panel: cost | 16 dp (IP-17) | **16 dp** | Width yes (3 digits about 43); height breaks with the word above (H-01) |
| Chip cost | 16 dp | **16 dp** | Yes: cost about 29 plus polygon 20 plus gap 6 in 76; 24 tall plus 3-unit bar in 44 |
| Prompt | 14 dp | **14 dp** | Yes: "Drag from the big button" about 252 of 300 less padding |
| Refusal cue line | 14 dp (UI Req) | **14 dp** | Yes: "Need 999 gold" about 137 in a 160 panel |
| Burst digit (in button) | 24 dp | **24 dp** (36 u) | Yes: 2 digits about 43 in the 84 visible disc; above the 18 dp floor |
| Cooling digit on press | unset | **24 dp** | Yes: own panel 56 x 48 (below) |
| Result rows (Lost, Won) | 16 dp | **16 dp** | Lost yes (8 lines at pitch 28 = 224 above Retry). **Won breaks** (H-02) |
| Paused line | unset | **16 dp** (a modal `Label` is allowed) | Yes: about 252 of 300 |

**Clearances checked.** Band: next-wave line glyphs (up to 30 tall at centre 53) span 38 to 68, inside 72. Prompt panel 72 to 106 meets the band exactly at inset 0, as the GDD states. Start/Call keeps its 88 x 72 rect, hit radius 48 and every content-rule clearance, since a text size moves no box. Breaks are listed, not fixed: the GDD is unchanged.

### Element table

| Element | Category | Visual form | Update | Trigger | Animation (Reduce Motion) | Patterns |
|---|---|---|---|---|---|---|
| Lives | Must Show | 10 dashes 24 x 4.5, gap 3, 2 rows | Signal `lives_changed` | Always | Lost dash fades to 0.2 in 200 ms (kept) | IP-20 |
| Pips | Must Show | 6 pills 20 x 10, gap 10 | Signal `phase_changed` | Always; pip states per Visual table row | Swap, no motion | IP-20 |
| Gold | Must Show | 16 dp tabular digits, right edge 516 | Signal `gold_changed` | Always | Digits swap, never bounce (AR-V-02) | IP-20 |
| Next-wave line | Contextual | 14 dp; glyphs at true size 16, 22, 30 | On phase change | Build, Intermission | None | IP-20 |
| Burst button | Must Show | 84 visible, hit 48; gold Ready, neutral wedge, dotted Locked | Frame, whole ticks | Every phase | Ready pop 1.15 to 1 in 120 ms (cut) | IP-18, IP-27 |
| Cooling digit | Contextual | 24 dp on a 56 x 48 panel, centre (`burst_x`, `burst_y - 76`) | Frame | While a cooling press is held | None | IP-03, IP-25 |
| Start/Call | Contextual | 88 x 72 panel rect, corner 24, 2 px neutral outline, two 16 dp lines | Frame (whole ticks) | Build: "Start". Intermission: "Call +N" or "Call", seconds, glyph. Hidden in Wave | Arming: outline only, alpha 0.5 to 1 over 300 ms linear; labels stay at 4.5:1 or above, panel at 85% (kept, it is a clock) | IP-15, IP-16 |
| Prompt | Contextual | 300 x 34 panel, 14 dp, one line | Frame | First match of Rule 13 | 12-unit slide in 200 ms (cut; fade kept) | IP-19 |
| Build arc | On Demand | Tower-size polygon, panel fill, 3 px cyan contour; panel above each with word and cost | Opening and `gold_changed` mark dirty; read in step 3 | `slot_tapped` | Collapse 120 ms (instant) | IP-09, IP-17 |
| Chip | On Demand | 76 x 44 panel at (x, y - 76): 16 dp cost, 20 px cyan polygon, 3-unit neutral bar | Frame (`chip_state()`) | Tower tap below last level | Bar drains linearly (kept) | IP-10, IP-25 |
| Range rings | On Demand | Solid current, dashed next at 0.5 or above | HudLogic ring list | Arc open, chip open, inspect 1.5 s | Fade only | IP-11 |
| Ground ring | Contextual | 2 px neutral, radius 16, alpha 0.35 | Signal `ground_tapped` | First three per battle | 150 ms fade-in (kept) | IP-14 |
| Refusal cue | Contextual | Dotted outline on the refused item plus a 14 dp line on panel | On `NO_GOLD` or Locked | Reduce Motion on | Static, 1 s real time | IP-24 |
| Result | Contextual | Modal panel, all 16 dp, left-aligned; Retry or Play again 128 x 72, the only filled shape | Once (`ResultSnapshot`) | Won or Lost | Text after 400 ms (Lost) or 1,000 ms (Won) | IP-21, IP-23 |
| Paused | Contextual | Static 40% scrim, 300 x 64 panel, 16 dp | On phase | Paused | None | IP-21, IP-22 |

### Static refusal cue placement (IP-24, AR-V-11)

Under Reduce Motion a refused tap shows a dotted outline on the refused item and one 14 dp line naming the reason, for 1 s of real time, with no motion. N is the cost minus gold at the refusal. This spec places the line.

**Rule: the line sits on its own panel, directly above the refused item, 4 units clear of it.** The thumb comes from below and covers the item and what lies under it, so above is the one place the line is seen at the moment of the tap. The arc and chip panels cannot carry it: "Need 20 gold" is about 126 wide at 14 dp, and those panels are 60 and 76.

| Refused item | Dotted outline on | Line | Panel | Centre |
|---|---|---|---|---|
| Arc disc (`NO_GOLD`) | That disc's polygon only | "Need N gold" | 160 x 34 | (`slot.x`, `slot.y - 177`): above the arc's top panel (which ends at `slot.y - 156`) |
| Chip (`NO_GOLD`) | The chip panel | "Need N gold" | 160 x 34 | (`tower.x`, `tower.y - 119`): above the chip (which ends at `tower.y - 98`) |
| Locked burst press | The button (already dotted) | "Locked" | 96 x 34 | (`burst_x`, `burst_y - 69`): the cooling digit's spot, since the two never show together |

**Clearances.** Arc: with L1 slots at y 304 or more, the arc cue spans y 110 to 144, 4 units below the prompt panel (106) at inset 0; a larger `I_top` is the Mobile Platform GDD's, like the arc panels (L6). Slot x 138 to 402 keeps the 160 panel inside x 58 to 482. Chip: towers at y 304 or more put the cue at y 168 or lower, clear of the prompt. Burst: the right-hand cue spans x 408 to 504, inside the 36-unit edge margin; the left-hand cue spans x 36 to 132, 10 clear of Start/Call's rect (x 142), which shows in Build when a locked press is most likely. Cue panels are not tap targets, so they take no press.

**Alternatives considered.** Inside the refused item's own panel: too narrow (above). Below the item: under the thumb. A fixed screen spot (the prompt strip): far from the item, and it would fight the prompt. Above the item won.

---

## HUD States by Gameplay Context

The template's four contexts map to the battle's phases. "Exploration" is Build (planning, no enemies); "combat" is Wave; "dialogue/cutscene" does not exist at MVP (no dialogue, no cutscene, no voice; AR Auditory), so that row is N/A; "paused" is Paused.

| State | Trigger | Visible | What changes on entry |
|---|---|---|---|
| Build (exploration) | Battle built | Band (lives, pip 1 current, gold, next-wave line), burst button Locked (dotted), Start/Call "Start", prompt 1 or 2 | Start/Call registers and arms over 300 ms (outline only) |
| Wave (combat) | Start or Call, or countdown 0 | Band without next-wave line, burst button (any state), prompt 1 or 3 | Start/Call and the next-wave line hide at once; Start/Call unregisters |
| Intermission | `wave_cleared` | Band with next-wave line, burst button, Start/Call "Call +N", seconds, glyph, prompt 1 or 2 | Start/Call registers and arms again; an open arc keeps it disabled until it closes |
| Dialogue / cutscene | n/a at MVP | n/a | n/a |
| Paused | Focus loss, app pause, Android back, shade pull | Phase it left, frozen, under a 40% scrim and "Paused. Tap to resume" | Arc and chip close; aim cancels; arming clocks freeze; no motion runs |
| Lost | Lives 0 | Board held 400 ms, then Lost panel (y 200 to 752) | Input dead at once (modal mounts); Retry arms 300 ms after the text |
| Won | `waves_completed` | Board held 1,000 ms, then compact Won panel (y 752 to 944) | As Lost; the finished build stays in view above (Pillar 1) |
| Fatal | Halt | Flow's Fatal screen replaces the HUD | Nothing of the HUD draws |

| Variant | Trigger | What changes |
|---|---|---|
| Arc open | `slot_tapped` | Arc and rings show; Start/Call disabled; backdrop sink registered |
| Chip open | Tower tap | Chip, current and dashed next ring; bar drains |
| Unaffordable | Cost above gold | Cost text alpha 0.6, struck through; arc polygon may be 0.55 |
| Refusal | `NO_GOLD` or Locked | Nudge 2 px 120 ms; under Reduce Motion the static cue |
| Empty or no data | Damage 0; no next-try line; bonus 0; no prompt | "0" shows as is; the row is absent; "Call" with no number; no prompt panel drawn |
| Left hand | `left_handed` | Burst button, digit, cue move to x 84; nothing else moves |
| Reduce Motion | `reduce_motion` via `MotionPolicy` | AR-V-10 rows; static refusal cue |

---

## Information Hierarchy

| Element | Tier | Reason | When hidden, what carries it |
|---|---|---|---|
| Lives | MUST KEEP | Loss condition | n/a |
| Gold | MUST KEEP | Every spend | n/a |
| Burst button | MUST KEEP | The hero's only control (Pillar 2) | n/a |
| Start/Call | MUST KEEP in Build and Intermission | The only way to start a stage | n/a |
| Arc, chip | MUST KEEP while open | The spend paths | n/a |
| Refusal cue | MUST KEEP while shown | A refused tap must not read as a miss (AR-V-11) | n/a |
| Result, Paused | MUST KEEP | Modal | n/a |
| Pips | SHOULD KEEP | Stage progress | Next-wave line and the result's "wave N of M" |
| Next-wave line | SHOULD KEEP | Plan one wave ahead (AR-C-05) | The field, once the wave starts |
| Cooling digit | SHOULD KEEP | Says why a press did nothing | The wedge on the button |
| Prompt | CAN HIDE | Teaches a verb once | The next-try line on the result (Rule 16) |
| Ground ring | CAN HIDE | A hint; a ground tap does nothing either way | Nothing (accepted exception, AR Known Limitations) |
| Damage numbers, HP bars, stats, timings, counters | ALWAYS HIDE | Rule 4 | Field cues; result counters |

---

## Visual Budget

| Measure | Limit | Worst case at MVP |
|---|---|---|
| Screen share outside modals | **At most 16%** of the 540 x 960 field | Build with arc open, prompt and refusal cue: about 15.5% (band 7.5, prompt 2.0, arc about 2.7, Start/Call 1.2, burst 1.1, cue 1.0) |
| Screen share in Wave | **At most 15%** | Arc open in Wave with prompt 3 and a cue: about 14.3%; Wave at rest (band and burst) about 8.6% |
| Simultaneous HUD elements | **At most 10** | 9 (lives, pips, gold, next-wave line, burst, Start/Call, prompt, arc, cue). Arc and chip never show together; a ground tap cannot land while an arc is open |
| Draw calls | Expected 8, at most 12 of 60; text at most 3 batches | Sizes 21, 24, 36 units only (ADR-0011 Decisions 6, 10). Modals add about 4 from the spare 8. Unverified until M9a |

**Drop order** if a later system would break a limit: CAN HIDE first (ground ring, then prompt), then SHOULD KEEP (cooling digit, next-wave line, pips). MUST KEEP never drops; a new MUST KEEP item needs a budget change here.

---

## Feedback & Notification Systems

The HUD has no toasts and no queue of messages (toast is out of scope, IP library Standard controls). These are its transient cues.

| Cue | Trigger system | Position | Duration | Max at once | Priority | Queue behaviour |
|---|---|---|---|---|---|---|
| Refusal nudge | Tower `NO_GOLD`, Hero Locked | The refused item | 120 ms | 1 | High | A new refusal restarts it on the new item |
| Static refusal cue | Same, under Reduce Motion | Above the refused item (placement table) | 1 s real time | **1** | High | Never queued: a new refusal replaces the shown cue and restarts 1 s with the new N. A queued "Need N gold" would describe a stale tap. Freezes while Paused; cleared by an outcome or Fatal |
| Locked prompt repeat | Hero, before the first pin, normal mode | Prompt strip | 1 s | 1 | Medium | Replaces; skipped under Reduce Motion (the cue stands in) |
| Cooling digit | HeroInput on a cooling press | Above the burst button | While pressed | 1 | Medium | Not queued; never shows with the Locked cue (states exclude) |
| Ground ring | Input `ground_tapped` | The tap point | 150 ms fade-in; hold time unstated (H-07) | Up to 3 per battle | Low | Each tap draws its own; none after the third |
| Inspect ring | Tower `tower_inspected` | The tower | 1.5 s | 1 | Low | A new inspect replaces it |
| Lost-life dash | Flow `lives_changed` | Band | 200 ms fade | Any | Low | Each dash fades on its own; never held |
| Prompt line | HudLogic | Prompt strip | Until its act | 1 | Medium | First match only; not a notification, never times out (AR-C-03) |

Nothing is held during Wave: every cue answers on the next frame (Input Game Feel). No sound at MVP; from Alpha every sound repeats one of these (AR-A-01).

---

## Platform Adaptation

| Platform | What differs | Source |
|---|---|---|
| Desktop dev build | Window 540 x 960; insets 0 by rule; mouse is one finger; the refocus click resumes from Paused | ADR-0003 1, 3, 5.3 |
| Phone, 9:16 or taller | `canvas_items` + `keep` letterboxes top and bottom; the notch and gesture bar usually fall in the bars, so `I_top` and `I_bottom` are usually 0 | ADR-0003 1 |
| Phone with an in-field inset | Band grows to `I_top + 72` (at most 174); prompt and arc cue move down with it; `burst_y` rises to 816 at most; Start/Call does not move | HUD Layout, `burst_y` |
| Squat screen or tablet | Letterbox left and right; scale by height; no scale cap at MVP | ADR-0003 1 |
| Every phone | Size guard: width 360 dp and height 640 dp or more, so 72 units is 48 dp; presses inside the 36-unit side margin (24 dp) and the insets are rejected | ADR-0003 1, 3; AR-M-10 |

No element is dropped on any platform. Only the burst button and its digit and cue mirror for the left hand (IP-27). Insets are read once per battle; a mid-battle resize logs a dev error (ADR-0003 5.4).

---

## Accessibility

Committed tier: **Standard (touch-adapted, at Alpha)**, with Reduce Motion, one-thumb play and a visual twin for every sound lifted from Comprehensive (AR Tier Definition).

| Checklist item | HUD answer | AR ID |
|---|---|---|
| Focus order | N/A: no keyboard, gamepad or switch path; every action is a disc (Known Intentional Limitations). Modals take one tap anywhere | AR-M-01 |
| Text size | Sizes table above: 14 dp floor, 16 dp labels, costs and values, 24 dp digit. Three breaks open (H-01 to H-03) | AR-V-01, AR-V-02 |
| Larger text 125% | Alpha. Fits: chip, gold, refusal cue. Breaks: prompt (about 315 of 300), Start/Call, arc panel, Won panel. Wrap or shorten rules owed (H-09) | AR-V-03 |
| Contrast | Text 4.5:1 in every state: neutral on panel 11.2:1; unaffordable text alpha 0.6 (4.83:1); Start/Call dims its outline only while Arming. Graphics needed to act 3:1 (dashed next ring at 0.5 or above) | AR-V-04 to AR-V-06 |
| Colour independence | Pips by fill, outline, dots; unaffordable by strike; burst states by fill, wedge, digit, dotted line; arc roles by shape and word; refusal by dotted outline and text | Colour audit |
| Reduced motion | Every HUD motion has its AR-V-10 row; views ask `MotionPolicy`, never the flag; refusal gets the static cue | AR-V-10, AR-V-11, IP-26 |
| Flashes | None in the HUD; nothing in screen space loops or glows | AR-V-08 |
| Screen reader | Out of scope for the battle. `HudTopBand` sets `accessibility_name` and `accessibility_live` (polite) for gold and lives on change; `TapScreen` accessible name if a plain Control can carry one | AR-P-02, ADR-0011 D6 |
| Hit targets | Every HUD target 48 dp at 360 dp width: arc 36, chip 40, Start/Call 48, burst 48, Retry short side 72 | AR-M-02 |
| Timed input | Chip bar and intermission seconds are visible clocks; multipliers at Alpha. Protective delays (200 ms guards, 300 ms arming) are not windows | AR-M-07, AR-M-08, IP-25 |
| Reading time | Prompts hide on the act; result waits for Retry; Paused has no timer | AR-C-02, AR-C-03 |

---

## Tuning Knobs

**Player settings.** None is a UI setting at MVP; two are data flags on the Input record, read once into `PresentationSettings` (ADR-0001).

| Setting | Range | Default | When | Effect on the HUD |
|---|---|---|---|---|
| Reduce Motion | off, on | off (later: OS setting copied at first launch, AR-P-03) | Flag at MVP; toggle at Alpha | AR-V-10 rows; static refusal cue |
| Left hand | right, left | right | Flag at MVP; first-launch choice at Vertical Slice; setting at Alpha | Burst button, digit, cue to x 84 |
| Larger text | 100%, 125% | 100% | Alpha | Scales the three text sizes (21, 24, 36 to about 26, 30, 45); still 3 batches |
| Hit-area scale | x1, x1.25 | x1 | Alpha | Every hit radius; content clearances must be rechecked (AR-M-04, OI-15) |
| Steady hand | x1, x1.5 (clamped) | x1 | Alpha | Slop only; no HUD change |
| Two-tap mode | off, on | off | Alpha | Burst button gains a visible armed state (IP-28) |
| Chip window | x1, x2, x3 | x1 | Alpha | Bar drains over 1.5, 3.0 or 4.5 s |
| Intermission length | x1, x1.5, x2 | x1 | Alpha | Longer seconds under Call; bonus unchanged |

Not adjustable, by decision: HUD scale, opacity, per-element show or hide, repositioning beyond the left-hand mirror (AR Known Intentional Limitations).

**Designer constants.** HudLogic's knobs (arming 300 ms, arc guard 200 ms, `R` 76, radii, ground rings 3, result delays) stay as the GDD Tuning Knobs table sets them. The values this spec adds only change pixels, so they live in ADR-0011's `ViewStyle`:

| Constant | Value | Safe range | Changes |
|---|---|---|---|
| Text sizes | 21, 24, 36 units | At least 21; a new size is a new text batch (budget) | All HUD text |
| Refusal cue panel | 160 x 34 (gold), 96 x 34 (Locked) | Wide enough for the longest string at 125% at Alpha | Cue panels |
| Cue gap above item | 4 units | 4 to 8; the arc cue's clearance to the prompt is 4 at slot y 304 | Cue anchors |
| Cue duration | 1,000 ms real time | Fixed by AR-V-11 | How long the cue shows |
| Cooling digit panel | 56 x 48, centre `burst_y - 76` | Bottom at least 4 above the hit disc | Digit on press |
| Result line pitch | 28 units at 16 dp | 26 to 30 | Result layout |

---

## Acceptance Criteria

Visual items are retained screenshots in `production/qa/evidence/` (BLOCKING for UI); logic items are HudLogic unit tests with fakes.

- [ ] **Safe zone, desktop.** At 540 x 960 with insets 0, the band ends at y 72, the prompt panel spans y 72 to 106, Start/Call's rect spans x 142 to 230 and y 764 to 836, and the burst button centre is (456, 888), or (84, 888) left-handed.
- [ ] **Safe zone, phone.** With `I_top` 30 and `I_bottom` 72, the band ends at 102, the prompt centre is at 119, and the burst centre is at y 816; no HUD element sits inside a rejected zone except the band, which takes no input.
- [ ] **Build context.** On a fresh battle the screen shows exactly: 10 lives dashes, 6 pips with pip 1 outlined, gold, the next-wave line, the burst button dotted, Start/Call "Start", and "Drag the hero". Nothing else.
- [ ] **Wave context.** After Start, Start/Call and the next-wave line are gone on the next frame and Start/Call is unregistered; band and burst button remain.
- [ ] **Intermission context.** After `wave_cleared`, Start/Call shows "Call +N" with seconds and a burst glyph matching the button's state; at bonus 0 it reads "Call".
- [ ] **Paused context.** On focus loss, a static 40% scrim and "Paused. Tap to resume" show at once; an open arc closes; no HUD element moves while Paused (frame capture shows no change over 2 s).
- [ ] **Won and Lost.** Lost text shows 400 ms after the outcome, Won 1,000 ms; Retry or Play again is the only filled shape; a tap before it arms does nothing.
- [ ] **Text sizes.** A render at 540 x 960 measures gold, Start/Call lines, arc words and costs, chip cost and result text at 24 units; prompt, next-wave line and refusal line at 21; burst digits at 36. No other size appears.
- [ ] **Contrast.** The contrast unit test reads `ViewStyle` and passes 4.5:1 for every HUD text colour on panel in every state, including unaffordable (alpha 0.6) and Start/Call while Arming (labels unchanged, outline only at 0.5).
- [ ] **Refusal cue, arc.** Under Reduce Motion, with 100 gold and a 120-cost disc, a tap on that disc shows a dotted outline on that disc only and "Need 20 gold" on a panel centred at (`slot.x`, `slot.y - 177`); there is no nudge; it shows at 999 ms of `advance(ms)` and is gone at 1,000.
- [ ] **Refusal cue, chip and burst.** Under Reduce Motion a refused upgrade shows "Need N gold" centred at (`tower.x`, `tower.y - 119`); a press on the Locked burst button shows "Locked" centred at (`burst_x`, `burst_y - 69`), mirrored for the left hand, 10 or more units clear of Start/Call's rect.
- [ ] **Cue queueing.** Two refusals 300 ms apart show one cue: the second replaces the first, with the second N, and ends 1,000 ms after the second refusal. With Reduce Motion off, no cue text ever shows.
- [ ] **Visual budget.** In the worst Build case (arc open, prompt, cue) the HUD's drawn area is 16% or less of the field, and in Wave at rest 10% or less, measured from `ViewStyle` rects in a unit test.
- [ ] **Draw calls.** M9a measures the HUD at 12 draw calls or fewer with at most 3 text batches (ADR-0011 Decision 10).
- [ ] **Left hand.** With `left_handed`, only the burst button, its digit and its cue move to x 84; Start/Call, arc order and the band are unchanged.
- [ ] **Accessibility names.** After a gold change and a life lost, `HudTopBand.accessibility_name` names the new values and `accessibility_live` is polite (HUD AC 34).

---

## Open Questions

### Open items (needed changes; no GDD, ADR or AR doc edited)

| ID | Item | Options | Owner | Resolve by |
|---|---|---|---|---|
| H-01 | **Arc panel breaks at 16 dp.** AR-V-01 needs 16 dp for the role word and cost; the 60 x 44 panel needs about 82 x 60. It cannot widen past about 62 at `R` 76: side and centre panels overlap in height (at 44 tall the side panels span `slot.y - 118` to `- 74` and the centre one `- 156` to `- 112`; any taller panel overlaps more), and their centres are 65.8 apart. By estimate "Splash" overflows 60 even at 14 dp | (a) A larger `R`, about 100, which is also AR-M-11's first fallback; rechecks L1, the edge margin, the prompt and Start/Call clearances. (b) An AR-V-01 exception: role word 14 dp, cost 16 dp (word still may not fit). (c) Drop the word and rely on shape plus cost (changes the Colour audit row) | User; then Battle HUD GDD Visual table and Layout, AR doc | First render with the chosen font |
| H-02 | **Won compact panel breaks at 16 dp.** 192 tall holds about 3 lines above Play again (868 to 940); Won needs "Stage clear", lives, got through and damage, about 7 lines (one per source) or 4 if damage fit one line, which it does not at 444 wide | (a) Taller Won panel, about y 640 to 944, and recheck the "board visible" test (Pillar 1). (b) Play again beside the text instead of at (270, 904). (c) 14 dp result text (breaks AR-V-01 for labels) | User; Battle HUD GDD Layout | First render |
| H-03 | **Start/Call at 16 dp has no margin.** "Call +8" just fits 76 inside; "Call +10" or more breaks | (a) Content rule: full-intermission bonus at most 9. (b) Widen the rect to the left only (hit disc and centre unchanged). Also fails at 125% (H-09) | User; Battle HUD GDD content rules or Visual table | Before the Start/Call story |
| H-04 | **Is the next-wave line a "label"?** This spec reads it as glance text at 14 dp, like the prompt. If AR-V-01 counts it as a label, 16 dp breaks the 230-unit line by about 2 on starter wave 6 | Confirm 14 dp in AR-V-01's wording, or widen the line (x 165 to 395 is bounded by pips and gold) | User; AR doc | Before `/ux-review` |
| H-05 | AR-V-01 lists "lives" at 16 dp, but lives are dashes with no text | AR-V-01 wording: drop "lives" or say "the lives label, if any" | AR doc owner | Next AR revision |
| H-06 | **Refusal cue now placed here.** IP-24, AR-V-11, the HUD GDD UI Requirements and the Tower and Hero UX flags say "the arc-and-chip and pin-and-aim specs place the line" | Point those to this spec's placement table; close the library's Gaps row; the two later specs cite it | ux-designer; GDD owners; pattern library | Next revision of each |
| H-07 | Ground ring hold and fade-out times are stated nowhere (only "150 ms in") | Set in the HUD GDD Visual table or `ViewStyle` | Battle HUD GDD | Before the ground ring story |
| H-08 | Pause control placement (IP-29, OI-06, AR-C-01): the band ignores input (Rule 1) and the bottom 30% is reserved (art bible §7), so any spot needs a source change | Decide with Menu & Screen Flow | ux-designer, Flow GDD | Before the first phone build |
| H-09 | 125% text (AR-V-03, OI-14): prompt, Start/Call, arc panel and Won panel break; chip, gold, cue fit. No wrap or shorten rule is named | Name a wrap rule per panel or grow panels | Battle HUD GDD (AR change 7) | Alpha |
| H-10 | The HUD GDD Visual table still says Start/Call lines 14 dp and leaves the arc word size, cooling digit panel and Paused text size unset | Update to this spec's sizes once H-01 to H-03 are decided | Battle HUD GDD | With H-01 to H-03 |
| H-11 | Font not chosen; every width here is an estimate | Re-run the sizes table at the first render | art-director | First render |

### Other open questions

| Question | Owner | Resolve by |
|---|---|---|
| No player journey map exists. Author `design/player-journey.md` from `.claude/docs/templates/player-journey.md` to establish player context for this screen | ux-designer | Before Vertical Slice UX specs |
| Is the prompt at the top seen while the eyes are on the lane? Is the cue above an arc seen at the moment of the tap? | First-run test | First playable |
| Does the cooling digit above the thumb read on a phone (art bible §7 flag)? | Pillar 4 phone test | First phone build |
| Do three prompts crowd a first run? Is a 1 s hold and a compact panel enough reward for a first win? | First-run test | First playable |

### Cross-reference check (2026-11-05)

- **GDD requirements:** 16 of 16 inventory items covered (Fatal screen named, owned by Flow, not specced). Tower and Hero UI Requirements: all covered.
- **New patterns for the library:** the refusal cue anchors (above the item, one cue at a time) extend IP-24; the cooling-digit panel extends IP-18. Flagged as a gap, not added (H-06).
- **Navigation mismatches:** none. No other screen spec exists; Retry and Play again rebuild the battle (Rule 18).
- **Accessibility gaps:** H-01 to H-05 and H-09.
- **Missing empty states:** none. Damage 0 reads 0; no next-try line hides the row; bonus 0 reads "Call"; no prompt draws no panel; next-wave line hides in Wave.

### Reviews

| Review | Status |
|---|---|
| ux-designer (this skill's primary agent) | **Review owed.** This session could not start agents; the spec was drafted in session in autonomous mode |
| art-director (sizes, panel looks, cue look) | **Review owed** |
| ui-programmer (`HudField` text pass, anchors, `ViewStyle` fields) | **Review owed** |
| accessibility-specialist (AR-V-01 reading, H-04, H-05) | **Review owed** |
| `/ux-review design/ux/hud.md` | Not run. Required before `/team-ui` and the Production gate |
