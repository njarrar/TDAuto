# Battle HUD & Build UI

> **Status**: Designed (pending independent review)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (compact Won panel, hint removal condition, wrong-disc fallback, Rule 10 overclaim, Flow's brighten row).
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-02
> **Last Verified**: 2026-11-02
> **Implements Pillar**: Pillar 4 (Thumb-First); Pillar 2 (the result shows damage by source, with no ranking)

## Summary

Everything the player reads and taps that is not the battle itself: lives, gold, wave pips, the build arc, the upgrade chip, Start/Call, the burst button's look, one-line prompts and the result screen. Players feel it as calm, because only what a decision needs is on screen, and nothing draws the eye off the lane. It owns drawing, placement, button arming and the human play log, and no gameplay state: every number it shows belongs to another system.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Game State & Stage Flow, Tower System, Hero System, Input & Gesture Resolver`

## Overview

The Battle HUD is how the player sees the battle's bookkeeping and spends gold. A thin top band shows lives, wave pips and gold. A tap on a slot opens three role discs above it, and a tap on a tower shows a cost chip. One button starts the first wave or calls the next early, showing the bonus against the burst's state. A short prompt names the next thing to try, and only until it is done. When a stage ends, a plain screen says what happened, one line for next time, and offers Retry. It exists because the player's thumb and eyes are both on the lane, so the HUD must answer at a glance and never ask to be read. It owns no game state: it shows values from Flow, Tower, Hero, Combat and Enemy & Wave, and sends their commands. It does not run headless, so nothing in the battle depends on it.

## Detailed Design

### Core Rules

**Shape.**

1. **Three pieces, built by the wrapper, absent headless, destroyed on retry.**

| Piece | Holds |
|---|---|
| HudLogic | Plain and testable with fakes: the arc model, armed buttons, prompt choice, ring count, result text, formulas |
| HudTopBand | Display-only Controls for gold, lives and pips, which ignore input |
| HudField | One `_draw` for arc, chip, Start/Call, burst button art and rings, with its hit targets as Input discs |

2. **Modal screens are Controls.** The result and Paused screens are full-screen Controls that consume every event before the adapter sees it (Input, UI Requirements), so a tap on them cannot reach a tower or the hero. So Input needs no second resolver and no gate in each owner. Everything else that can be tapped is an Input disc. A Control fires only on a release whose press it saw while Armed, and it clears that press on the lifecycle signal, so a thumb held across a screen change or a focus loss cannot fire it. Paused has no timer but follows the same rule. Whether the engine helps here is unverified in 4.7, so the ADR must check, and this rule holds either way.
3. **No gameplay state, no reset.** The HUD keeps only presentation state. Retry rebuilds it (Flow Rule 16).

**What is on screen, and when.**

4. **Always:** lives, pips, gold and the burst button. **Build and Intermission add:** Start/Call and the next-wave line. Nothing else. Damage numbers, HP bars, tower stats, spawn timings and hit counters are not shown. No pause button exists at MVP (Flow Rule 17), which corrects art bible §7 and Input.
5. **Next-wave line.** "Next", then a glyph and a total count per enemy type, in fixed order, drawn from the Wave records. There are no timings or groups, so convergences must still be seen on the field. With no selling, blind buying is costly, and one wave ahead spoils little. This settles Enemy & Wave's question.

**Build arc.**

6. **Tap a slot, get three discs.** `slot_tapped` from TowerInput registers one backdrop (TAP 250, a sink covering the field) and three discs (TAP 300), which compete from the next press. Order is always triangle, hexagon, square, left to right, on every slot and both hands, for motor memory. A panel above each disc holds its word and cost on two lines: Single, Splash, Slow. While the arc is open, each disc shows a short looping icon of its effect: one target hit, a group hit, a slowed enemy. So the first purchase shows the role before any wave. Under Reduce Motion the icon is static. In Wave and Intermission the new tower firing at once demonstrates the role. A disc press within 200 ms of opening is ignored as a build and closes the arc (Rule 8), since a slot's disc and the hexagon's are only 4 units apart, and a double tap on a slot must dismiss rather than buy a tower that cannot be sold (Tower). Start/Call is registered but disabled while an arc is open, because at priority 350 it would otherwise beat the backdrop; an arc open when Intermission begins makes Start/Call Disabled; when its phase ends it goes Hidden. An arc that opens while Start/Call is Arming or Armed makes it Disabled, and when the arc closes it starts a new 300 ms arming (States and Transitions).
7. **Tap a disc: `build`.** The disc always calls `build`, and the result decides: `OK` closes the arc and unregisters it at once, with a 120 ms collapse as art only. `NO_GOLD` leaves it open with a nudge. `HALTED` closes it. Anything else closes it and logs a development error. Costs are read through the accessor on opening and on `gold_changed` while open, at level 1 only, so nothing can ask past a level count. An unaffordable disc is dimmed and struck through, updated live.
8. **Closing.** `pressed` with a best tap that is not one of the discs closes the arc and unregisters it, and the later `tap(backdrop)` is ignored. A disc press within 200 ms of opening also closes it and builds nothing (Rule 6), so a double tap on a slot dismisses. `drag_started` closes it. A finger rolling off a disc leaves it open. A phase change among Build, Wave and Intermission leaves it open. Paused, an outcome and Fatal close it.

**Upgrade chip.**

9. **The chip is its own target, owned by TowerInput.** It must sit above the thumb to be seen, so a tap on what the player sees must work. TowerInput registers a TAP disc at priority 300, radius 40, at (x, y − 76) of the tower while the window is open, and treats `tap(chip)` as a second `tap(tower)` (Tower Rule 8). The HUD draws from `chip_state()`, which gives the slot, the elapsed time and the level: the cost, the level-2 glyph, and a 3-unit bar draining over the 1.5 s window, so the window has a visible clock. Below the affordable cost it is dimmed and struck through. A tap that returns `NO_GOLD` gives the same nudge as the arc (Rule 7), and the window does not restart. A tap on a level-2 tower gives `tower_inspected(slot_index)`, which shows its range ring for 1.5 s and opens no chip.

**Start/Call.**

10. **One button, two jobs, hidden in Wave.** Build: "Start". Intermission: "Call +8" (a full 15 s countdown pays 8, Tower; bare "Call" when the bonus is 0), and under it the seconds left and a small burst glyph showing the same state as the button: full ring, wedge or dotted. Telegraphing draws as an empty wedge, the same as the button (Rule 12), so a telegraph in flight at wave clear has a state. Once armed, it has no pulse, warning or advice. It shows the numbers, and the bots show no cost the HUD could honestly claim. The bonus comes through Tower's formula. Each frame advances real-time models, then ticks, then refreshes views, and commands run before ticks, so what is shown is what is paid, subject to the ADR's check on that order. A press inside the hero's grab disc is the hero's: when `pressed` names Start/Call as `best_tap` and the hero as `best_drag`, the HUD ignores that gesture's tap (HeroInput exposes the hero's ID as `hero_target_id()`, Hero Rule 16), so a tap meant for the hero cannot call a wave, a drag from there past 64 re-pins, and a drag cancels as Hero Rule 14 says: a hero drag that never passes 64 from its press point, or comes back within 48 of it, pins nothing. It is decided at press and holds for the gesture. Only that overlap is dead; the rest of the button works, even while the hero walks past (user decision, 2026-11-02, replacing a disable of the whole button while the hero was under 104). Stage's `pin_exclusion` keeps a pinned hero's centre 60 from the button's, so the button's centre is never in the overlap. Build is unaffected, because the hero waits at `hero_start`, 164 away.
11. **Arming.** A button goes Hidden, Arming, Armed, over 300 ms of real time (Flow, Game Feel). It registers on appearing, not on arming, or an early press would land on what lies beneath. A tap from a press during Arming is dead, even if released once Armed (a drag from the hero beneath is still a drag), and a press begun before it appeared cannot win under Input Rule 2. The clock is `advance(ms)` from the wrapper's frame time, clamped to 100 per frame, so a hitch cannot arm an unseen button, and HudLogic ignores it while Paused. A return from Paused is not a new appearance. Retry uses the same model, starting when its text shows. A phase begins on each `phase` signal into it, except one that returns from Paused, and also on the single `phase(Build)` Flow emits after a battle is built (Flow Rule 6). The HUD treats that signal as Build beginning, so Start goes from Hidden to Arming on first launch and after every Retry.

**Burst button.**

12. **Look only.** HudField draws the button at the active hand's shape in Stage's `pin_exclusion`, in every phase. HeroInput registers it and decides what a press means. Locked (dotted) comes from `in_build()` and `pin_state()`; otherwise `burst_state()` gives Ready, or Cooling with its wedge and digit, and Telegraphing draws as an empty wedge. Once Won, Lost or Fatal is latched, the button keeps the look it had on the last completed tick before the latch, not the outcome snapshot (Rule 15), which is built a frame later, and no longer follows `burst_state()`. A burst Telegraphing on the last tick keeps drawing as Telegraphing. The press responses are the Hero GDD's.

**Prompts.**

13. **One prompt line, first match, for this battle only, in Build, Wave and Intermission, with the Call prompt last.** It hides on the act and never on a timer. There are no arrows, pauses or captured input. Because conditions are read per battle, nothing has to survive a rebuild.
    1. Hero unpinned: "Drag the hero"
    2. No tower built, in Build or Intermission: "Tap a slot to build"
    3. In Wave only, once the burst is Ready and none has started: "Drag from the big button", latched until `burst_started`. The latch holds for the whole battle across phase changes, but the prompt is hidden in Intermission and Build, so it never invites a first burst onto an empty field

    These teach verbs only, never where or when, which leaves room for the user's first-run target. This amends the Hero GDD, which called the first the only tutorial text.

    The Call prompt shares the one Prompt panel and comes after this list. It shows only when no prompt above applies, so prompt 2 wins. It shows in Intermission when `bursts_started` is at least 1 and at least one tower is built, and only if the never-call gate has failed (Open Questions). Its text is "Tap Call to start early." It hides on the first call, on the act, and is final after that.

**Rejection ring.**

14. **Three per battle.** `ground_tap` draws a dim rejection ring for the first three in a battle, and none after. It is dotted, never solid, and fades as the art bible says (§7, Ground tap), so it cannot be read as the hero's solid pin ring. It resets on retry, since nothing else survives one. A dismissal is `tap(backdrop)`, so it draws none.

**Result.**

15. **Plain text, fixed order, same weight.** A transparent modal Control mounts at the outcome, so input is dead at once. The text appears 400 ms after a Lost and 1,000 ms after a Won. All values come from one snapshot built on the frame after the outcome, so every leak is counted, and it also feeds the log, so screen and log cannot disagree.

| Order | Lost | Won |
|---|---|---|
| 1 | Broke on wave N of `wave_ids` size | Stage clear |
| 2 | Next-try line, if any | Lives N of `starting_lives` |
| 3 | Got through: glyph and count per enemy type | Same |
| 4 | Damage: Towers, Hero, Burst, each rounded to a whole number | Same |
| 5 | Retry, the only filled shape | Play again, the same rebuild, since there is no next stage at MVP |

Percentages, bars and highlights are not shown, because hero share is a balance metric rather than a goal (Pillar 2). This amends Combat's deferred row and UI note, which asked for hero share shown: the three rows are the raw counters, and the log keeps the share. Median kills stays in the log too, since a 0 can read as shame. Strings are exactly those in this table and Rule 16 (art bible §2).

16. **Next-try line, first match, in the same order as Rule 13.** Next-try lines are advice after a battle, so they are exempt from Rule 13's "never where". A burst counts as started once it commits, on `burst_started`, as in Rule 13. The next-try test reads Hero's `bursts_started`, not `bursts_fired` (releases). It helps most when the player missed a verb, since the mid-skill bot loses every mixed build without the burst (Hero GDD, Simulated results).
    1. Hero never pinned: "Next try: drag the hero"
    2. No tower built: "Next try: tap a slot to build"
    3. No `burst_started` this attempt: "Next try: drag from the big button"
    4. Otherwise the type with the most lives lost, as count × `lives_cost`, if its role is not yet built: `heavy` "Triangles hit heavies", `normal` "Hexagons hit groups". `fast` has no type line until Hero's "Slow value" row shows one slow tower ending with at least one more life than the same build with that slow swapped for a single tower (Hero, Deferred, "Slow value"); whatever towers are built, a loss led by fast enemies gets the verb line "Next try: drag the hero to the leak." Once Hero's "Slow value" row passes, the slow type line "Next try: squares slow the fast" replaces it, and it shows only then. Ties go in that order. If its role is built, there is no line, since the hint would have nothing to add.

**Paused.**

17. **Tap to resume.** A 40% scrim and "Paused. Tap to resume" at centre. The whole screen is the Control. It resumes on the release of a press it saw, with no countdown (Flow Rule 17).

**Commands.**

18. **Between ticks.** All commands run from the input call stack, before the frame's ticks. That order is unverified, and the ADR must check it. Retry's handler runs inside input and would destroy its own caller, so it only sets a latch on the app root, and the root's frame then checks for Fatal first, and otherwise stops the clock, cancels input, frees the battle and builds a new one. It is idempotent, so a second tap does nothing.

**The human log.**

19. **Debug builds append four kinds of record: attempt, call, wave and Fatal.** An attempt record is written per finished attempt, and holds `instructed`. A call record is written per call. A wave record is written per wave, wave 1 included, which has no call fields. A Fatal attempt writes one Fatal record, with outcome Fatal. Each record carries a `kind` field: attempt, call, wave or fatal. `instructed` is true or false, set from a debug toggle the tester turns on for Hero's instructed extension attempts. The HUD caches the reads the Fatal record needs after every completed tick (Flow Rule 18). Three GDDs need human numbers at first playable, and none owned writing them down. Each record holds a launch ID, the build hash and `attempt_seq`, which counts from 1 per launch and rises each time a battle is built or rebuilt. A failed build still raises `attempt_seq`. A Fatal during `build`, after Retry, writes one Fatal record with empty counters under the new `attempt_seq`. The launch ID is a random string made at launch, used only by the log and never by gameplay. Records group by launch ID plus `attempt_seq`. The attempt and Fatal records key on launch ID plus `attempt_seq`, with no `wave_index`. Each per-wave record also holds `wave_index`. Attempt: towers built, lives, last wave, `gold_left`, gold spent per wave, damage by source and kind, `repins`, burst counters with `bursts_started`, `kills_per_burst[]`, `best_victims`, got through by type, and the real seconds to first pin, build and burst. Seconds to a first pin or first burst that never happens are null. Gold spent in Build, or in the Intermission before wave N, counts to wave N. `kills_per_burst[]` gets an entry only per release. Seconds to first pin count from the first `phase(Build)` of the attempt and exclude Paused time. A per-wave record opens when `wave_index()` changes, never on a `phase` signal, so a resume is never counted as a new wave. It is written at that wave's `wave_cleared` or at the outcome. Each per-wave record also holds `repins` and Wave seconds for that wave. Wave seconds exclude Paused time. Per call: `seconds_left`, burst readiness (the burst state at the call), lives lost in the called wave. Per wave started after a full wait, the same record with `seconds_left` 0, so called and waited waves compare wave by wave (Hero, Deferred criteria). Wave 1 opens a per-wave record too, with `repins` and Wave seconds but no call or wait fields, since it started from Build. The file is `user://run_log.jsonl`, and a tester sends it by hand. A quit attempt writes no attempt record, which is accepted. On app focus loss, the open per-wave record is written at once as provisional, so a quit keeps the wave in progress. The reader keeps only the last record per launch ID, `attempt_seq`, `wave_index` and `kind`, so a provisional record and its final one never both count. Its per-wave records are kept, and since they group by launch ID plus `attempt_seq`, they never merge into another attempt. The reader skips a truncated last line. It reads burst state itself and never through Tower (Flow Rule 9). It is not a save, and release builds do not write it.

**Layout.** In field units, on the 540 × 960 reference, with `I` the safe-area inset in field units, 0 on desktop. 1.5 units is 1 dp at a 360 dp width.

| Element | Position |
|---|---|
| Band | y 0 to `I_top + 72`; at most 174, which L6 holds |
| Lives | 2 rows of 5 dashes, 24 × 4.5, x 24 to 156, row centres `I_top + 22` and `I_top + 34` |
| Pips | 6 × 20, gap 10, x 185 to 355, row centre `I_top + 22` |
| Gold | Right edge x 516, reserved from x 434 |
| Next-wave line | x 165 to 395, row centre `I_top + 53` |
| Burst button | x 456, or 84 left-handed; `y = clamp(888 − I_bottom, 816, 888)` |
| Start/Call | (186, 800), rect 88 × 72, corner 24, hit radius 48, for both hands |
| Prompt | Panel 300 × 34, one line, centre (270, `I_top + 104`), above the path |
| Lost panel | x 48 to 492, y 200 to 752; Retry 128 × 72 at (270, 700) |
| Won panel | Compact, x 48 to 492, y 752 to 944, so the finished build stays visible above it (Pillar 1); Play again 128 × 72 at (270, 904) |

This confirms the burst line that L3, L7 and `pin_exclusion` assumed, so nothing moves. Start/Call clears: the left burst's hit disc by 7.2 at its worst, the right by 174.5, the slot at (170, 700) by 17.3, `hero_start` by 60, and the lane's edge at x 234 with its rect ending at x 230. A pinned hero never covers its centre, since Stage's `pin_exclusion` holds a disc of radius 60 there for both hands, above the hero's grab radius of 56 (user decision, 2026-11-02).

**Content rules, added to the content test.** All bounds are proposed.

| Check | Bound | Starter |
|---|---|---|
| L1 (Enemy & Wave), tightened | Slot x 138 to 402, y at least 304, so every arc disc stays on the field and no flip code is needed | Pass, 170 to 370 and 305 |
| Arc disc to the burst line, either hand | At least 84 | 155 |
| Start/Call to any slot's hit disc | At least 16 clear | 17.3 |
| Start/Call to `hero_start` | At least 48 | 60 |
| Start/Call to the path's edge | Rect clear of it | 4 |
| Next-wave line | At most 3 types at true size | 3 |
| Waves in a stage, starting lives | At most 6, and at most 10, the pips and dashes that fit. Larger waits for a later stage's layout | 6, 10 |
| Arc panels against the band | Clear at inset 0; a large inset is the Mobile GDD's, since the starter's top panel reaches y 149 | Pass |

**Handed to owning GDDs.**
- **Enemy & Wave:** exposes `wave_index()` and a view-only `got_through_by_type()`, since `enemy_leaked(lives_cost)` carries no type.
- **Flow:** exposes reads of lives, phase, `intermission_left` and the result; the root takes the retry latch.
- **Hero:** no Hero change needed. The HUD reads Burst `cooldown` through the accessor at use time for the wedge; prompt text moves here.
- **Tower:** Rule 8 gains the chip's target, `chip_state()` and `tower_inspected`.
- **Technical director:** stretch mode. 540 × 960 is 9:16 and a 360 × 800 dp phone is taller, so insets must be converted to field space. MVP is on desktop at 540 × 960, so every inset here is 0 until the Mobile Platform GDD.

**Deliberately not built for MVP.** A pause button, settings UI, wave number digit, gold icon, percentages, bars, per-tower damage, arc flip code, path draw-in, Won's brighten sequence, stage select, onboarding beyond three lines, and any keyboard, gamepad or screen-reader path, since every game action is a disc.

→ Becomes an ADR: Control event order against the adapter, input before ticks in a frame, `free()` timing on retry, safe-area and stretch.

### States and Transitions

| Armed button | Meaning | Transitions |
|---|---|---|
| Hidden | Not registered | Its phase begins, including the `phase(Build)` Flow emits after a battle is built (Flow Rule 6, Rule 11) → Arming, registered and dimmed. Start/Call only: phase begins, arc closed → Arming; phase begins, arc open → Disabled (Rule 6) |
| Arming | 300 ms running; a tap from a press now is dead | 300 ms → Armed. Start/Call only: arc opens → Disabled. Its phase ends → Hidden. Paused: held, clock frozen |
| Armed | A new press counts | A counted tap → command. Start/Call only: arc opens → Disabled. Its phase ends → Hidden. Paused: held |
| Disabled | Start/Call only: registered but disabled while a build arc is open (Rule 6); it ignores presses | Arc closes → Arming (a new 300 ms arming). Its phase ends → Hidden; an arc closing while Start/Call is Hidden changes nothing |

A press held across two phase changes may name an old target ID. The HUD ignores a gesture for an ID it no longer holds (Input).

| Build arc | Meaning | Transitions |
|---|---|---|
| Closed | No targets registered | `slot_tapped` → Open |
| Open | Discs and backdrop registered; Start/Call disabled | Rules 7 and 8 |

| Prompt | Meaning | Transitions |
|---|---|---|
| Showing one line | First match of Rule 13; the Call prompt only when no other prompt applies | Act done → next match, or None |
| None | Nothing to show now | Prompts 1 to 3 are final after the first burst; before that, prompts 2 and 3 can follow a phase change. The Call prompt is final after the first call |

The Call prompt (Rule 13) shares this one panel and has its own gate, so "One prompt line" holds.

### Interactions with Other Systems

| Element | Source | Updated | Owner of the value |
|---|---|---|---|
| Gold | `gold()`, `gold_changed` | Signal | Tower |
| Lives | Flow read, `lives_changed` | Signal | Flow |
| Pips, Start/Call, overlays | Flow reads, `phase`, `wave_index()`, `wave_ids` size | Signal | Flow, Enemy & Wave |
| Countdown, bonus | `intermission_left` through Tower's formula | Frame, comparing whole ticks | Flow, Tower |
| Digit, wedge, ticks | `cooldown_left()`, `burst_state()` | Frame, comparing whole ticks | Hero |
| Arc and chip costs, range rings | Accessor by `def_id` and level | On opening, and on `gold_changed` while open | Data, Tower |
| Next-wave line | Wave records directly | On phase change | Enemy & Wave |
| Result | Flow result, Combat counters, `got_through_by_type()` | Once at the outcome | Flow, Combat, Enemy & Wave |
| Prompts | `pin_state()`, `slot_state()`, `targets()`, burst counters | Frame | Hero, Tower, Enemy & Wave |

| System | Direction | Interface | Owner |
|---|---|---|---|
| Input & Gesture Resolver | registers, listens | Arc, backdrop, Start/Call discs; `pressed`, `tap`, `drag_started`, `idle`, `ground_tap` | Input (API); HUD (meaning) |
| Tower System | calls, listens | `build`; `slot_tapped`; `chip_state()`; `tower_inspected`; `gold()`; `gold_changed`; `slot_state` | Tower |
| Hero System | listens, reads | `burst_state()`, `cooldown_left()`, `pin_state()`, `position()`, `burst_started`; `hero_target_id()`; HeroInput registers the button | Hero |
| Data & Config Pipeline | reads | Costs and stats through the accessor; level count; Stage and Wave directly; the Options record directly | Data |
| Combat & Damage | listens, reads | `damage_applied`; per-source counters for the result (soft) | Combat |
| Enemy & Wave | reads | `wave_index()`, `got_through_by_type()`, `targets()` (soft) | Enemy & Wave |
| Game State & Stage Flow | calls, listens | Start/Call, Retry, resume, `phase`, `lives_changed`, `in_build()`, `intermission_left` | Flow |

Headless wiring tests are unaffected, since the HUD is absent, and `phase` and `lives_changed` join Flow's view allowlist.

## Formulas

The **arc_disc** formula is defined as:

`arc_disc(k) = slot + R × (sin(a_k), −cos(a_k))`, with `a` −60°, 0° and 60° for triangle, hexagon and square

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `slot` | 2D point | field units | data file | Slot position |
| `R` | float, units | 76 | constant | Presentation; chords come to 76, so discs do not overlap |
| `a_k` | angle | −60°, 0°, 60° | constant | Fan angle per disc |

**Output Range:** inside x 72 to 468, and y 228 to `slot y − 38` under tightened L1.
**Example:** slot (270, 305): (204.2, 267), (270, 229), (335.8, 267).

The **display_seconds** formula is defined as:

`display_seconds = (ticks + ticks_per_second − 1) div ticks_per_second`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `ticks` | int | 0 and up | calculated (Flow, Hero) | Whole ticks left |
| `ticks_per_second` | int | 60 proposed | constant | From the fixed tick |

**Output Range:** 0 only at 0, so a digit never shows 0 while time remains.
**Example:** 600 → 10, 541 → 10, 540 → 9, 1 → 1.

The **burst_y** formula is defined as:

`burst_y = clamp(888 − I_bottom, 816, 888)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `I_bottom` | float, units | 0 and up | platform | Bottom inset in field units |

**Output Range:** 816 to 888, the whole line `pin_exclusion` already covers, so the simulation is unchanged by a device.
**Example:** inset 0: 888. Inset 72, or 48 dp: 816.

The **chip_bar** formula is defined as:

`chip_bar = clamp(1 − elapsed / 1500, 0, 1)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `elapsed` | float, ms | 0 and up | calculated (Tower's `chip_state()`) | Real time since the chip opened |

**Output Range:** 0 to 1. It is a display of Tower's window, and defines no new value.
**Example:** 750 ms: 0.5.

## Edge Cases

- **If gold rises while an arc is open**: discs re-dim at once, and a disc that became affordable works.
- **If a slot is tapped while its neighbour's arc is open**: the backdrop takes the press and dismisses, as Input requires. The next tap opens the new arc.
- **If an arc is open when the hero's walk reaches a disc**: nothing changes. A drag from the overlap goes to the hero and closes the arc (Input).
- **If Start/Call appears under a resting thumb**: that press stays dead under Rule 11, or is frozen out under Input Rule 2.
- **If an arc is open when Wave ends**: Start/Call registers disabled, and re-arms (a new 300 ms) when the arc closes.
- **If the countdown ends during a press on Call**: Flow ignores the late tap. The wave has started and the button is hidden.
- **If the bonus falls to 0 while shown**: the label becomes "Call", and a call still starts the wave.
- **If a call's displayed bonus and paid bonus could differ**: they do not, under the frame order in Rule 10, since both use Tower's formula on the same tick count. The ADR verifies that order.
- **If Retry is tapped twice**: the latch is idempotent, so there is one rebuild. The second tap either belongs to a destroyed button or is a new press in the new Build, where it reaches whatever is beneath (Flow, Edge Cases). Rule 11's arming applies to the new Retry only.
- **If a press is down when the result appears, or the app loses focus with one down**: the Control never saw it, or clears it on the lifecycle signal, so it cannot fire.
- **If a chip's press is held past 1,500 ms**: the window has expired, so the tap does nothing (Tower Rule 8).
- **If `build` is called twice from a double tap on a disc**: the arc unregistered on the first `OK`, so there is no second.
- **If the player has built nothing, never pinned and loses**: rule 1 of the next-try line shows. Hero 0 and Burst 0 appear as they are.
- **If no enemy got through on a Lost**: unreachable, since losing means leaks.
- **If two types tie for most lives lost**: heavy, then normal, then fast.
- **If damage total is 0**: the three rows read 0, with no division anywhere.
- **If the chip's disc overlaps a neighbouring tower**: the chip wins by priority while open. Starter slots are 160 apart, so it cannot overlap; L4 permits 72, so a later stage may. Accepted, and watched in the Pillar 4 test.
- **If the arc's cost would be asked past a level count**: unreachable. The arc reads level 1, and the chip reads `level + 1` only below the count.
- **If `halted()` turns true during a cost read**: the read is abandoned, and the Fatal screen replaces the HUD, ahead of any retry latch.
- **If the app loses focus with an arc open**: Paused closes it, and the resume tap reaches nothing beneath.
- **If a player taps Play again after a Won**: the same rebuild, with the same seed.
- **If the log file cannot be written**: a development error, and play goes on. It is never fatal.
- **If handedness is left**: only the burst button and its digit mirror. Start/Call stays, 7.2 clear at the worst.

## Dependencies

**Upstream (hard):**

| System | Interface |
|---|---|
| Game State & Stage Flow | `phase`, `lives_changed`, reads of lives, `intermission_left` and result; `in_build()`; Start/Call, Retry, resume |
| Tower System | `gold()`, `gold_changed`, `slot_state`, `slot_tapped`, `build`, `chip_state()`, `tower_inspected` |
| Hero System | `burst_state()`, `cooldown_left()`, `pin_state()`, `position()`, `hero_target_id()`, `burst_started`, counters |
| Input & Gesture Resolver | Registry, `pressed`, `tap`, `drag_started`, `idle`, `ground_tap` |
| Data & Config Pipeline | Costs and stats through the accessor; level count; Stage and Wave directly; the Options record (`left_hand`, `reduce_motion`) directly |

**Soft:** Combat (`damage_applied` for hit marks; per-source counters for the result), Enemy & Wave (`wave_index()`, `got_through_by_type()`, `targets()`; Wave records). The HUD places the burst button, and Enemy & Wave's L3 and L7 test the coordinates the HUD uses (from Stage's `pin_exclusion`), so the HUD does not receive them from Enemy & Wave.

**Downstream (these have no GDD yet):**

| System | Interface |
|---|---|
| Onboarding Prompts (Vertical Slice) | Replaces Rule 13 |
| Menu & Screen Flow (Vertical Slice) | Replaces Play again |
| Stage Progression (Vertical Slice) | Replaces the result screen with its report; uses the log's snapshot |
| Settings & Accessibility (Alpha) | Writes the player's choice over Data's Options record (`left_hand`, `reduce_motion`), which the HUD reads directly until then; an alternative path to discs |
| Mobile Platform (Vertical Slice) | Insets and stretch |

Per the bidirectional rule, each must list this one when authored. Flow, Tower, Hero, Input, Enemy & Wave, Combat and Data already do.

## Visual/Audio Requirements

Primitives only, and nothing has been rendered. Text sits on panel. Tower and Hero own their field visuals, which are not restated. Audio: none at MVP.

| Element | Visual |
|---|---|
| Lives | Neutral dashes, gap 3. A lost dash goes to alpha 0.2 in 200 ms, still countable |
| Pips | 20 × 10 pills, since discs would match the glyphs below. Filled done, outlined current, dotted upcoming |
| Gold | 16 dp tabular digits |
| Next-wave line | Neutral glyphs at true size, 16, 22 and 30, with the fast's notch, because at a smaller size normal and heavy merge. Counts 14 dp |
| Start/Call | Panel rect, 2 px neutral outline, two 14 dp lines. Arming: alpha 0.5, reaching full at 300 ms. Burst glyph 16 px neutral |
| Arc | The disc is a hit area only and is not drawn. A tower-size polygon with panel fill and a 3 px cyan contour. Panel above, 60 × 44, with the word and cost |
| Chip | 76 × 44 panel, 16 dp cost, 20 px cyan level-2 polygon, neutral bar |
| Unaffordable | Alpha 0.55, cost struck through |
| Prompt | 14 dp, one line, on panel |
| Result | All 16 dp, left-aligned, no headline size. Lost glyphs outlined. Retry neutral fill. Won's panel is compact, with the board visible above it |
| Paused | Static 40% scrim, 300 × 64 panel |
| Rejection ring | 2 px dotted neutral, radius 16, alpha 0.35, 150 ms in, unlike the pin's 30 |

**Colour.** Field-anchored polygons, in the arc and chip, stay cyan: that tower, there. Screen space stays neutral, including enemy and burst glyphs. Backups for colour: strike, alpha, and fill, outline or dots.

📌 **Asset Spec:** once the art bible is approved, run `/asset-spec system:battle-hud`.

## Game Feel

A purchase, a tap and a press all answer on the next frame, and nothing bounces. Lost: the outlined hero holds for 0.4 s, then only Retry is filled, so the eye goes to it, and a retry is one tap. The next-try line reads as advice rather than blame, since it avoids "you" and the past tense. Won: with brightening cut, the reward is the 1 s hold at +4% and the finished build left in view above a compact panel, which is thin (Open Questions). Start/Call never hurries the player. All timings wait for a first phone test.

## UI Requirements

This whole document is UI. Tower's and Hero's UI Requirements stand, and are drawn here.

- 120 ms: arc, presses, arming. 200 ms: dash, 12-unit panel slides, with opacity fixed. Paused is instant.
- Reduce Motion cuts slides, while fades and clock bars stay. The `NO_GOLD` nudge becomes a 120 ms alpha blink on the disc or button, never on a panel, since panel opacity never animates (art bible §7). The 120 ms arc collapse is a slide, so the arc closes at once. The prompt pulse becomes an alpha blink. It is the Options record's `reduce_motion` (Data & Config) until Settings exists.
- Budget: expected 8, at most 12 of 60 draw calls, and text at most 3, one per size. Modals add about 4. Unverified.
- Font: one medium-weight geometric humanist sans with tabular numerals, not yet chosen.
- Text floor 14 dp, or 21 units at a 360 dp width; hit targets 48 dp, or 72 units, which every target here meets with no margin at that width.

📌 **UX Flag — Battle HUD:** run `/ux-design` for the arc, chip, Start/Call and result before writing epics. Stories then cite `design/ux/`.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Result, damage log, input priority, Won and Lost | `design/gdd/game-concept.md` | MVP items 4 to 6; Pillars 2 and 4 | Rule dependency; amended |
| Phases, arming, retry, result, focus loss | `design/gdd/game-state-stage-flow.md` | Rules 9, 15 to 18; Game Feel; UI Requirements | Rule dependency; amended |
| Arc, chip, costs, commands | `design/gdd/tower-system.md` | Rules 5 to 8, 17; UI Requirements | Rule dependency; amended |
| Prompt, button, Locked, ticks | `design/gdd/hero-system.md` | Rules 1, 11 to 16; UI Requirements | Rule dependency; amended |
| Priorities, registry, ring count, Controls | `design/gdd/input-gesture-resolver.md` | Suggested registrations; Rule 2; UI Requirements | Rule dependency; amended |
| Slots, L1, L3, L7, wave records, next-wave line, leaks | `design/gdd/enemy-wave.md` | Layout rules; Open Questions | Value dependency; amended |
| Counters shown | `design/gdd/combat-damage.md` | Rule 5; Deferred; UI Requirements | Rule dependency; amended |
| Costs, accessor, level count, preview context | `design/gdd/data-config-pipeline.md` | Rule 10 | Rule dependency |
| Band, panels, type, colour, lives, chip | `design/art/art-bible.md` | §2, §3, §4, §7, §8 | Value dependency; amended |

## Acceptance Criteria

Fakes: resolver, reads, commands, log sink; a spy accessor; `advance(ms)`. Each THEN is the entire log. No scene or time assertions.

**CI: Logic**
1. (Rule 3; Data, Enemy & Wave rows) **GIVEN** a spy changing cost, **WHEN** the arc reopens, **THEN** the new cost shows; a new instance holds nothing.
2. (Rule 4) **GIVEN** each phase, **THEN** HudLogic's visible set is exact, with the burst button in all.
3. (Rule 5) **GIVEN** split groups, **THEN** one total per type, in fixed order.
4. (Rule 6) **WHEN** `slot_tapped`, **THEN** backdrop TAP 250, discs TAP 300 radius 36, triangle, hexagon, square on either hand; Start/Call disabled. A disc press at 199 ms is ignored, and at 200 ms it counts.
5. (Rule 7; Tower row) `OK` closes and unregisters at once; `NO_GOLD` stays and nudges; `HALTED` closes; others close and log an error. One tap, one `build`.
6. (Rule 7) Level 1 read on opening and `gold_changed`; dimming flips both ways; a newly affordable disc builds.
7. (Rule 8; Input row) A press outside closes and unregisters; a later `tap(backdrop)` does nothing, with no ring. `drag_started` closes. Roll-off and a phase change stay open. Paused, outcome and Fatal close.
8. (Rule 9) `chip_state()` at 0, 750 and 1,500 ms draws the bar as 1, 0.5 and 0; dimmed below cost. `tower_inspected`: ring for 1,500 ms, no chip.
9. (Rule 10) "Start"; at 60 ticks a second and 1.8 s per gold, with 13 s left, "Call +7"; with 15 s, "Call +8"; bonus 0 "Call"; hidden in Wave; glyph matches burst state. With the hero 60 from its centre, a press inside both discs released in place calls nothing, moved 80 and released re-pins, and moved past `tap_slop` and released having never passed 64 from the press point (for example at 55) pins nothing; a press at the centre calls. With the hero walking across, a press outside the hero's disc calls. In Build at `hero_start`: calls.
10. (Rule 11; Flow row) A press during Arming, released once Armed, does nothing; the next press commands once.
11. (Hidden) Unregistered; its phase begins: registered and dimmed.
12. (Arming) 299 no, 300 Armed; `advance(5000)` counts 100; phase end Hidden; Paused holds, and return does not restart it. Retry likewise.
13. (Armed) A counted tap: one command; phase end Hidden.
14. (Arc states) Closed: no targets. Open: all registered. An arc across Wave's end: Start/Call registers disabled, and re-arms (a new 300 ms) when the arc closes. Armed, a slot tap opens the arc: Disabled; the arc closes: Arming; a Call press within 300 ms is dead; Intermission ends with the arc open: Hidden.
15. (Rule 12) Build, unpinned, Ready, Telegraphing and Cooling each map to their look; x 456, left 84. After Won, Lost or Fatal, the burst button keeps its last-tick look.
16. (Rule 13) Each prompt on its fixture; first match wins; pinned with no tower in Wave gets prompt 3; prompt 3 stays through a spawn gap and hides on `burst_started`; no prompt on an outcome. Call prompt: with the never-call gate failed, `bursts_started` at least 1 and a tower built, in Intermission with no Rule 13 prompt applying, the panel shows "Tap Call to start early."; after a call it never shows again; with prompt 2 applying, prompt 2 shows instead.
17. (Prompt states) Each act advances; for prompts 1 to 3, None is final after the first burst.
18. (Rule 14) Three rings, then none; a dismissal draws none; a rebuild resets.
19. (Rule 15; Combat row) One snapshot, taken the frame after the outcome, feeds screen and log, including the fatal leak; exact strings and order; text at 400 and 1,000 ms; damage 0 reads 0.
20. (Rule 16) Each next-try line in order; a fixture where count and lives disagree; ties heavy, normal, fast; a built role gives no line; a loss led by fast enemies with no slow built shows "Next try: drag the hero to the leak."
21. (Rules 2, 17) A Control fires only on a release whose press it saw; a press across the lifecycle signal does nothing. Paused resumes on release.
22. (Rule 18) Retry twice: one latch; the handler frees nothing; Fatal first.
23. (Rule 19) Each record kind with all fields and its `kind`: attempt (with `instructed`), per call, per wave (wave 1 included, with no call fields) and Fatal; each per-wave record with `wave_index`, `repins` and Wave seconds, opened on a `wave_index()` change and never on a resume, and written at that wave's `wave_cleared` or the outcome; the attempt record with `gold_left` and gold spent per wave; on focus loss the open record is written as provisional, and the reader keeps only the last record per launch ID, `attempt_seq`, `wave_index` and `kind`; the wave 1 record has `repins` and Wave seconds and no call fields; Wave seconds and seconds to first pin exclude Paused time; a Fatal writes one Fatal record, and a Fatal during `build` after Retry writes one with empty counters under a new `attempt_seq`; burst state not through Tower; a sink failure is non-fatal.
24. (arc_disc) Slot (270, 305): the three example points.
25. (display_seconds) 600→10, 541→10, 540→9, 1→1, 0→0.
26. (burst_y) 0→888, 72→816, 200→816.
27. (chip_bar) 0→1, 750→0.5, 1,500→0, 2,000→0.
28. (Pillar 4, 44 pt / 48 dp) Arc, chip, Start/Call and burst radii pass Input's `target_ok`, and 35 fails; Retry's short side is at least 72 units.

**CI: Integration**
29. (Independence) One script with and without the HUD: identical full state.
30. (Rule 1) Headless wiring builds no HUD piece.
31. (Paid) With real Tower and Flow, the shown bonus equals the paid one.
32. (Retry) Two taps, one rebuild, a clean HUD.
33. (Content) Real records pass; each check fails on its own fixture, watched failing once.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner | Passes when |
|---|---|---|
| First run | User, first playable | Hero's First run row passes |
| Human log | Battle HUD stories | On a debug build, an attempt record (with `instructed`), a record per call, a record per wave (wave 1 included, with no call fields, and with `wave_index`) and a Fatal record are written; fields as in criterion 23 |
| Rules 2, 10, 18 | HUD ADR | A held press cannot fire a Control; input precedes ticks; `free()` timing is safe |
| Phone targets | Mobile Platform | Hit discs measure 48 dp at a 360 dp width |

**Manual** (retained in `production/qa/evidence/`, blocking for UI): Build; Wave; Intermission; arc open with one unaffordable disc; chip open; Won, with the full board visible; Lost; Paused; each prompt; left hand; rejection ring; burst press response; cancelling state. Render tests: three glyphs in grey at quarter scale; fast's notch at 16; pills against dashes; the level-2 inset at 20 px; "Call +7" in 88 at 14 dp; "Splash" in a 60-wide panel; alpha 0.55 text; hero outline beside the Lost panel; measured draw calls.

**Checked by code review, not tests:** HudTopBand ignores input; the Start/Call button itself has no pulse or advice once armed (the Call prompt is a Rule 13 line, not part of the button); release builds do not write the log.

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Do the next-try hints help? "Squares slow fast enemies" is unproven: no bot isolates it, a square earns nothing alone, and nothing can be sold, so it could prompt a permanent bad buy. It is removed from Rule 16. It returns only when Hero's "Slow value" row shows that one slow tower ends with at least one more life than the same build with that slow swapped for a single tower (Hero, Deferred, "Slow value") | Hero GDD + bots | First playable |
| Do players find Call? Count only free attempts, not Hero's instructed extension attempts, that reached at least one wave after wave 1. An attempt never calls when none of those waves was started by a call. Count only records with `instructed` false (Rule 19). If over half of them never call, the gate has failed and the Call prompt (Rule 13) shows "Tap Call to start early." | Human logs | First playable |
| Adjacent arc discs are 4 units apart in the fan, and a wrong disc is a permanent mis-fire against a bar of zero. The 200 ms guard stops double taps only. First fallback: a larger `R` | Pillar 4 phone test | First phone build |
| Is a 1 s hold and a compact panel enough reward for a hard-won first win? | First-run test | First playable |
| Could "Broke on wave N" read as out of gold? Flow's wording stands for now | User + playtest | First playable |
| Do three prompts crowd a first run, or still leave room for the first-run target? | First-run test | First playable |
| Is the prompt at the top seen, while the eyes are on the lane? | First-run test | First playable |
| Which font? Tabular figures and a licence must be checked | art-director | First render |
| Does the stretch mode change every inset check? A 360 × 800 dp phone is taller than 9:16. Tracked in Input's adapter row | technical-director | Before the first input story |
| At a large top inset, the band meets the arc's top panel and the prompt | Mobile Platform GDD | Mobile Platform |
| Every game action is a disc, so there is no keyboard, gamepad or screen-reader path, and touch alone is a motor barrier | Settings & Accessibility GDD | Alpha |
| Is 7.2 enough clearance beside the left-hand button? | Pillar 4 phone test | First phone build |
