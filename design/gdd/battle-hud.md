# Battle HUD & Build UI

> **Status**: Approved (lean check 2026-11-04 after the third full review; 2 recommended items in the review log; engine behaviour awaits ADR-0003)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (compact Won panel, hint removal condition, wrong-disc fallback, Rule 10 overclaim, Flow's brighten row).
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-04
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

1. **Four pieces, absent headless, destroyed on retry.** Only HudLogic decides anything. The wrapper builds in this order: resolver, TowerInput, HudLogic, HeroInput (which reads `burst_button_centre()`), then the views, which can read HeroInput directly.

| Piece | Holds |
|---|---|
| HudLogic | Plain and testable with fakes. Registers and unregisters every HUD disc with the injected resolver, listens to `pressed`, `tap`, `drag_started`, `idle`, `ground_tap`, `slot_tapped`, `tower_inspected`, `phase_changed` and the rest of the Dependencies table's signals, and issues every command. Holds the arc, the armed buttons, the modal press model, prompts, ring count, range-ring states, the result snapshot and text, the formulas and `burst_button_centre()`, and exposes all of it as view-model reads |
| HudTopBand | Display-only Controls for gold, lives, pips and the next-wave line, which ignore input |
| HudField | A node that only draws, with one `_draw` for arc, chip, Start/Call, burst button art and digit, all rings and the prompt. It redraws when a quantised key changes (fill in steps of 1/60 of a turn, digit, bonus label, visible set, arming state, held press, affordability of each open disc and chip) and every frame while a timed visual runs: chip bar, ring fade, nudge, collapse |
| HudModals | The result and Paused Controls, built once and toggled visible on `modal_changed`, which forward presses, moves and releases to HudLogic |

**HudLogic's seam.** The wrapper injects all of this, so a fake can supply each: the resolver; Flow's, Tower's, Hero's, Combat's and Enemy & Wave's reads and commands; the accessor; the Stage and Wave records and tower IDs and role tags; a log sink with the launch ID and build hash; the app root's retry latch; `tap_slop`, `edge_reject_margin`, `left_handed`, `reduce_motion`, the field width and the safe-area insets, which stay fixed for the battle until the Mobile Platform GDD. The battle exposes what the headless builder holds and the wrapper needs: `burst_id`, `in_build()`, `dt` and `to_ticks`. Calls in: `advance(ms)`, `modal_press(pointer, pos)`, `modal_move(pointer, pos)`, `modal_release(pointer, pos)`, `modal_cancel_pointer(pointer)` and `modal_cancel()`, the last wired to the adapter's `lifecycle_paused` and `viewport_resized`. Out: the view-model reads, and `modal_changed(kind)`, with kind none, paused or result. It emits that synchronously with the phase change, and none on Fatal, so HudLogic owns which modal shows and input is dead at once. When built, it reads `phase()` once and treats that as the phase beginning, since Flow emits nothing for the opening Build (Flow Rule 6).

2. **Modal screens are Controls.** The result and Paused screens are full-screen Controls that stop presses before the adapter sees them, while moves and releases of a gesture already under way still reach it (binding on ADR-0003; Input's adapter contract). So a tap on them cannot reach a tower or the hero, Input needs no second resolver, and no owner needs a gate. Everything else that can be tapped is an Input disc. Because presses skip the adapter, HudLogic's modal press model repeats its rules:
    - **Translation.** HudModals translates events the way the adapter does: field units, pointer index, one event family, left button only, and a `canceled` touch goes to `modal_cancel_pointer`, never to a release (binding on ADR-0003).
    - **Rejected presses.** A press inside `edge_reject_margin` of a side edge or inside an inset does not count (Input Rule 12). It holds nothing and replaces nothing, so a grip touch cannot kill the thumb's tap.
    - **Target.** Hit-tested at press: the screen outside rejected zones on Paused; Retry's or Play again's rect on a result screen, where any other press does nothing and holds nothing.
    - **Tap.** It counts only if the same pointer releases under `tap_slop` from its press and, on a result screen, inside the rect. A move to `tap_slop` kills the press. There is no hold limit (Input Rule 3).
    - **Second press.** The same pointer pressing while held is a lost release, so it cancels the held press and starts again (Input Rule 1). On Paused, any later non-rejected press replaces whatever is held, since every press has the same effect. On a result screen, another pointer's press is ignored while a counting press is held, since replacing it could fire a screen-changing button from a second brush. A dead press, killed or begun during Arming, blocks nothing.
    - **Cancel.** `modal_cancel_pointer(i)` clears that pointer's press, and `modal_cancel()` clears any. A cancelled press never counts. A resize or focus loss does this on the result screen too, where the phase does not change.
    - **Arming.** Retry and Play again count only a press begun while Armed (Rule 11), so a thumb held across a screen change cannot fire them. **Paused has no arming** (user decision, 2026-11-04): its clock is frozen, so it could never arm, and Flow Rule 17 says a tap resumes. A press held across the focus loss was never seen by the Control, so its release counts for nothing. The accepted cost is that a brush can resume a live wave, which the phone test watches (Open Questions).

    Whether the engine helps here is unverified in 4.7, so ADR-0003 must check, and this rule holds either way.
3. **No gameplay state, no reset.** The HUD keeps only presentation state. Retry rebuilds it (Flow Rule 16).

**What is on screen, and when.**

4. **Always:** lives, pips and gold. **Build, Wave and Intermission add:** the burst button, which Paused shows as the phase it left. **Build and Intermission add:** Start/Call and the next-wave line. **Won and Lost hide the burst button** (user decision, 2026-11-04): Won's panel would cover it, and nothing can fire. **Fatal hides all of it**: only Flow's fatal screen shows. Nothing else. Damage numbers, HP bars, tower stats, spawn timings and hit counters are not shown. No pause button exists at MVP (Flow Rule 17).
5. **Next-wave line.** "Next", then a glyph and a total count per enemy type, in the order heavy, normal, fast with absent types omitted, drawn from the Wave records. There are no timings or groups, so convergences must still be seen on the field. With no selling, blind buying is costly, and one wave ahead spoils little. This settles Enemy & Wave's question.

**Build arc.**

6. **Tap a slot, get three discs.** `slot_tapped` from TowerInput registers one backdrop (TAP 250, a sink covering the field) and three discs (TAP 300, radius 36), which compete from the next press. Order is always triangle, hexagon, square, left to right, on every slot and both hands, for motor memory. A panel above each disc holds its word and cost on two lines: Single, Splash, Slow. The new tower firing at once demonstrates the role. A disc press under 200 ms after opening, sampled at `pressed` on `advance`'s clock, counts as a press outside the discs: it closes the arc and buys nothing, since a double tap that drifts onto a disc must dismiss rather than buy a tower that cannot be sold. Start/Call is registered but disabled while an arc is open, because at priority 350 it would otherwise beat the backdrop; an arc open across a phase change keeps it so.
7. **Tap a disc: `build`.** The disc always calls `build(slot_index, tower_id)`, with the tower whose role tag matches its shape, and the result decides: `OK` closes the arc and unregisters it at once, with a 120 ms collapse as art only. `NO_GOLD` leaves it open with a nudge: ±2 px once for 120 ms, skipped under Reduce Motion. `HALTED` closes it. Anything else closes it and logs a development error. There is no refund for a wrong disc (user decision, 2026-11-04: deferred to phone data). Costs are read through the accessor on opening and on `gold_changed` while open, at level 1 only, so nothing can ask past a level count. An unaffordable disc is dimmed and struck through, updated live.
8. **Closing.** `pressed` with a best tap that is not one of the discs, or a disc under Rule 6's guard, closes the arc and unregisters it, and the later `tap` of an id no longer live is ignored. `drag_started` closes it. A finger rolling off a disc leaves it open. A phase change among Build, Wave and Intermission leaves it open. Paused, an outcome and Fatal close it.

**Upgrade chip.**

9. **The chip is its own target, owned by TowerInput.** It must sit above the thumb to be seen, so a tap on what the player sees must work. TowerInput registers a TAP disc at priority 300, radius 40, at (x, y − 76) of the tower while the window is open, and treats `tap(chip)` as a second `tap(tower)` (Tower Rule 8). The HUD draws from `chip_state()`, which gives the slot, the elapsed time, the window length and the level: the cost, the level-2 glyph, and a 3-unit bar draining over the 1.5 s window, so the window has a visible clock. Below the affordable cost it is dimmed and struck through. A tap on a level-2 tower gives `tower_inspected(slot_index)`, which shows its range ring for 1.5 s and opens no chip. HudField draws Tower's other range-ring states too: arc open, one ring per distinct level-1 range; chip open, current plus next at alpha 0.25; after a build or upgrade, 400 ms then a 200 ms fade (Tower, Visual Requirements).

**Start/Call.**

10. **One button, two jobs, hidden in Wave.** Build: "Start". Intermission: "Call +7" (bare "Call" when the bonus is 0), and under it the seconds left and a small burst glyph showing the same state as the button: full ring, wedge or dotted. Once armed, it has no pulse, warning or advice. It shows the numbers, and the bots show no cost the HUD could honestly claim. The bonus is Tower's `early_call_bonus` read, given `intermission_left × dt`. Each frame advances real-time models, then ticks, then refreshes views, and commands run before ticks, so what is shown is what is paid, subject to ADR-0004's check on that order. A press inside the hero's grab disc is the hero's: when `pressed` names Start/Call as `best_tap` with any `best_drag`, the HUD ignores that gesture's tap, since the hero is the only drag target that can overlap it, so a tap meant for the hero cannot call a wave, and a drag from there re-pins. It is decided at press and holds for the gesture. Only that overlap is dead; the rest of the button works, even while the hero walks past (user decision, 2026-11-02, replacing a disable of the whole button while the hero was under 104). A hero crossing the button's centre covers all of it, for under 0.1 s at `walk_speed`. Stage's `pin_exclusion` keeps a pinned hero's centre 60 from the button's, so the button's centre is never in the overlap. With a hero exactly 60 away, the worst distance, about 36% of the hit disc is dead. That is a miss, which a second tap on the side away from the hero fixes, and never a mis-fire, which is why the rule stands (user decision, 2026-11-04). It applies in Build too, since a pin there places the hero at once; before a first pin the hero waits at `hero_start`, 164 away.
11. **Arming.** A button goes Hidden, Arming, Armed, over 300 ms of real time (Flow, Game Feel). It registers on appearing, not on arming, or an early press would land on what lies beneath. A tap from a press during Arming is dead, even if released once Armed (a drag from the hero beneath is still a drag), and a press begun before it appeared cannot win under Input Rule 2. The clock is `advance(ms)` from the wrapper's frame time, clamped to 100 per frame, so a hitch cannot arm an unseen button, and HudLogic ignores it while Paused. A return from Paused is not a new appearance. Retry and Play again use the same model, starting when their text shows, through the modal press model rather than a registered disc. Paused has no arming (Rule 2). Start's first Arming comes from HudLogic's opening read of `phase()` (Rule 1).

**Burst button.**

12. **Look only.** HudField draws the button at `burst_button_centre()`, on the active hand's shape in Stage's `pin_exclusion`, in the phases Rule 4 lists, so art and hit disc share one point. HeroInput registers it and decides what a press means. Locked (dotted) comes from `in_build()` and `pin_state()`; otherwise `burst_state()` gives Ready, or Cooling with its fill and digit, and Telegraphing draws at fill 0. The fill is the burst_fill formula, returning clockwise as art bible §2 asks, reading Burst `cooldown` through the accessor at use (Data Rule 10), with the ID the wrapper injects, so Hero needs no extra read. The Hero GDD specifies the press responses, and the HUD draws the button's. **HeroInput owns the digit and the aim state**: HudField reads `cooldown_digit()`, `aim_state()` and `button_press()` from it, and HudLogic reads none, since it is built first. While Cooling the digit sits on the button; during a cooling press it moves above the thumb and the button is bare, since the thumb covers it (user decision, 2026-11-04). `button_press()` also drives the Locked nudge. The reticle, reach ring, kill preview and Ready ticks belong to Hero's view.

**Prompts.**

13. **One prompt line, first match, for this battle only, in Build, Wave and Intermission.** It hides on the act and never on a timer, and each act ends its prompt for the battle: a first pin, a first `tower_built`, a first `burst_started`, none of which can be undone. Prompt 2 also hides while an arc is open. There are no arrows, pauses or captured input. Because conditions are read per battle, nothing has to survive a rebuild.
    1. Hero unpinned: "Drag the hero"
    2. No tower built, in Build or Intermission: "Tap a slot to build"
    3. In Wave, once the burst is Ready and none has ever started: "Drag from the corner button". It stays up through spawn gaps, hides outside Wave, and ends on `burst_started`

    These teach verbs only, never where or when, which leaves room for the user's first-run target.

**Ground ring.**

14. **Three per battle.** `ground_tap` draws a dim ring for the first three in a battle, and none after. It resets on retry, since nothing else survives one. A dismissal is `tap(backdrop)`, so it draws none.

**Result.**

15. **Plain text, fixed order, same weight.** On `phase_changed` naming the outcome, HudLogic emits `modal_changed(result)` and the transparent modal Control turns visible, so input is dead at once. `phase_changed` sets a due flag, and the first `advance(ms)` after it builds the snapshot and starts the text timer: 400 ms for both Lost and Won, since Won's longer beat waits for the brighten sequence (Flow, Game Feel). `advance` keeps running after an outcome; only the tick accumulator stops. This avoids building inside the tick's signal stack. If `phase()` is Fatal, no snapshot is built. In Lost's row 1, N is `wave_index()`; in Won's row 2 it is the lives left. The snapshot also feeds the log, so screen and log cannot disagree.

| Order | Lost | Won |
|---|---|---|
| 1 | Broke on wave N of `wave_ids` size | Stage clear |
| 2 | Next-try line, if any | Lives N of `starting_lives` |
| 3 | "Got through", then a glyph and count per type, in Rule 5's order, omitting 0 | Omitted, and kept in the log (user decision, 2026-11-04): it needs about 270 units against a 198 column |
| 4 | "Towers N", "Hero N", "Burst N", each rounded half up to a whole number, then "Slowed N" if a slow tower was built | Same, as Won's right-hand column |
| 5 | Retry, the only filled shape | Play again, the same rebuild, since there is no next stage at MVP |

Percentages, bars and highlights are not shown, because hero share is a balance metric rather than a goal (Pillar 2). As Combat's deferred row and UI note say, the three rows are the raw counters, and the log keeps the share. Median kills stays in the log too, since a 0 can read as shame. Strings are exactly those in this table and Rule 16, in the no-shame tone of art bible §2.

16. **Next-try line, first match, in the same order as Rule 13.** It helps most when the player missed a verb, since the mid-skill bot loses every mixed build without the burst.
    1. Hero never pinned: "Next try: drag the hero"
    2. No tower built: "Next try: tap a slot to build"
    3. `burst_started` never fired: "Next try: drag from the corner button", which names the button the next try will show
    4. Otherwise the type with the most lives lost, as count × `lives_cost`, if its role is not yet built: `heavy` "Triangles hit big enemies", `normal` "Hexagons hit groups", `fast` "Squares slow fast enemies". Ties go in that order, and a type with no line ranks last. If the top type's role is built, or it has no line, there is no line, since the hint would have nothing to add. A line longer than the panel wraps.

**Paused.**

17. **Tap to resume.** A 40% scrim and "Paused. Tap to resume" at centre. The whole screen is the Control, under Rule 2's press model. It resumes on a counted release, with no arming and no countdown (Flow Rule 17). On resume HudLogic emits `modal_changed(none)`, and the Control is only hidden, never freed inside its own handler.

**Commands.**

18. **Between ticks.** All commands run from the input call stack, before the frame's ticks. That order is unverified, and ADR-0004 must check it. Retry's handler runs inside input and would destroy its own caller, so it only sets a latch on the app root, and the root's frame then checks for Fatal first, and otherwise stops the clock, cancels input, frees the battle and builds a new one. It is idempotent, so a second tap does nothing.

**The human log.**

19. **Debug builds append one record per finished attempt and one per call.** Three GDDs need human numbers at first playable, and none owned writing them down. Each record holds a launch ID and the build hash. Attempt: towers built, lives, last wave, damage by source and kind, `slows_applied()`, `repins`, burst counters, `kills_per_burst[]`, `best_victims`, got through by type, and the real seconds to first pin, build and burst. Per call, written at the next `wave_cleared` or outcome: `seconds_left` and burst readiness, both sampled at the call, and lives lost in the called wave. The file is `user://run_log.jsonl`, and a tester sends it by hand. A quit attempt leaves no record, which is accepted. It reads burst state itself and never through Tower (Flow Rule 9). It is not a save, and release builds do not write it.

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
| Prompt | Panel 300 × 34, one line, centre (270, `I_top + 89`), between the band and the path, clear of the path's edge up to `I_top` 68 units, or 45 dp. Above that it overlaps the lane, by 34 at most at `I_top` 102, and the Mobile Platform GDD owns it (L6) |
| Lost panel | x 48 to 492, y 200 to 752; Retry 128 × 72 at (270, 700) |
| Won panel | Compact, x 48 to 492, y 744 to 944, moved up by `B = min(I_bottom, 72)`, so the finished build stays visible above it (Pillar 1). Two columns from y 756 − `B` to 860 − `B`: rows 1 and 2 at x 64 to 262, row 4's up to four lines at x 278 to 476, each 26 tall, so 104 at most (user decision, 2026-11-04). Play again 128 × 72 at (270, 904 − `B`). Sizes are unrendered, and `/ux-design` confirms them |

This confirms the burst line that L3, L7 and `pin_exclusion` assumed, so nothing moves. Start/Call clears: the left burst's hit disc by 7.2 at its worst, the right by 174.5, the slot at (170, 700) by 17.3, `hero_start` by 60, and the lane's edge at x 234 with its rect ending at x 230. A pinned hero never covers its centre, since Stage's `pin_exclusion` holds a disc of radius 60 there for both hands, above the hero's grab radius of 56 (user decision, 2026-11-02).

**Content rules, added to the content test.** All bounds are proposed.

| Check | Bound | Starter |
|---|---|---|
| L1 (Enemy & Wave), tightened | Slot x 156 to 384, y 304 to 924, so every arc disc stays clear of `edge_reject_margin`, the slot's disc stays on screen and no flip code is needed | Pass, 170 to 370 and 305 to 700 |
| Arc disc to the burst line, either hand | At least 84 | 164 |
| Arc disc to Start/Call's hit disc | At least 16 clear, rechecked if `R` grows | 78.5 |
| Start/Call to any slot's hit disc | At least 16 clear | 17.3 |
| Start/Call to `hero_start` | At least 48 | 60 |
| Start/Call to the left burst's hit disc | Clear, because Rule 10 treats any `best_drag` as the hero | 7.2 |
| Start/Call to the path's edge | Rect clear of it | 4 |
| Next-wave line | At most 3 types at true size | 3 |
| Waves in a stage, starting lives | At most 6, and at most 10, the pips and dashes that fit. Larger waits for a later stage's layout | 6, 10 |
| Burst line to a side edge | At least `edge_reject_margin` + 48 (Input Rule 12) | 84 against 84 |
| Arc panels against the band and prompt | Clear at inset 0. The starter's top panel reaches y 117 and the prompt ends at y 106 + `I_top`, so they meet at `I_top` 11, which is the Mobile GDD's | Pass, 11 |
| Largest early-call bonus | At most 2 digits, so "Call +N" fits | 8 |
| Enemy types | Each has a next-try line in Rule 16 | 3 of 3 |
| Chip's disc to Start/Call's hit disc | At least 16 clear, since Start/Call's priority 350 would otherwise take an upgrade tap and call a wave | 88.7 |
| Chip's disc to the burst button's hit disc, either hand | At least 16 clear | 122.4 |
| A tower body against Won's panel | Clear at `B` 0, so the finished build stays in view (Pillar 1) | Clear, up to `B` 16 |

**Handed to owning GDDs.**
- **Enemy & Wave:** exposes `wave_index()` and a view-only `got_through_by_type()`, since `enemy_leaked(lives_cost)` carries no type.
- **Flow:** exposes reads of lives, phase, `intermission_left` and the result; the root takes the retry latch.
- **Hero:** prompt text moves here.
- **Tower:** Rule 8 gains the chip's target, `chip_state()` and `tower_inspected`.
- **Technical director:** stretch mode. 540 × 960 is 9:16 and a 360 × 800 dp phone is taller, so insets must be converted to field space. MVP is on desktop at 540 × 960, so every inset here is 0 until the Mobile Platform GDD.

**Deliberately not built for MVP.** A build refund, a pause button, settings UI, wave number digit, gold icon, percentages, bars, per-tower damage, arc flip code, a localization path (strings are fixed English), path draw-in, Won's brighten sequence, stage select, onboarding beyond three lines, and any keyboard, gamepad or screen-reader path, since every game action is a disc.

→ Becomes ADRs: Control event order against the adapter, safe-area and stretch (ADR-0003); input before ticks in a frame (ADR-0004); `free()` timing on retry (ADR-0001); draw-call cost of the single `_draw` (ADR-0011). All numbers are provisional.

### States and Transitions

| Armed button | Meaning | Transitions |
|---|---|---|
| Hidden | Start/Call: not registered. Retry and Play again: no disc at any point, not hit-tested | Start/Call: its phase begins, or HudLogic's opening read finds it → Arming, registered and dimmed. Retry and Play again: their text shows → Arming |
| Arming | 300 ms running; a tap from a press now is dead | 300 ms → Armed. Its phase ends → Hidden. Paused: held, clock frozen |
| Armed | A new press counts | A counted tap → command. Its phase ends → Hidden. Paused: held |

| Build arc | Meaning | Transitions |
|---|---|---|
| Closed | No targets registered | `slot_tapped` → Open |
| Open | Discs and backdrop registered; Start/Call disabled | Rules 6 to 8 |

| Prompt | Meaning | Transitions |
|---|---|---|
| Showing one line | First match of Rule 13 | Act done → next match, or None. A phase change or an arc can hide it |
| None | Nothing to show now | Final once all three acts are done; before that, a phase change can bring a prompt back |

### Interactions with Other Systems

| Element | Source | Updated | Owner of the value |
|---|---|---|---|
| Gold | `gold()`, `gold_changed` | Signal | Tower |
| Lives | Flow read, `lives_changed` | Signal | Flow |
| Pips, Start/Call, overlays | Flow reads, `phase_changed`, `wave_index()`, `wave_ids` size | Signal | Flow, Enemy & Wave |
| Countdown, bonus | `intermission_left` and the `dt` injected from the battle, through Tower's `early_call_bonus` | Frame, redrawn on a quantised key | Flow, Tower |
| Digit | HeroInput's `cooldown_digit()`, `aim_state()`, `button_press()`, read by HudField | Frame, redrawn on a quantised key | Hero |
| Fill | `cooldown_left()`, `burst_state()`; Burst `cooldown` through the accessor at use | Frame, redrawn on a quantised key | Hero, Data |
| Arc and chip costs, range rings | Accessor by `def_id` and level | On opening, and on `gold_changed` while open | Data, Tower |
| Next-wave line | Wave records directly | On phase change | Enemy & Wave |
| Result | Flow result, Combat counters, `got_through_by_type()`, `slows_applied()` | Once, on the first `advance` after the outcome | Flow, Combat, Enemy & Wave, Tower |
| Prompts | `hero_pinned`, `tower_built`, `burst_started`; `burst_state()` | Signals, and the frame for Ready | Hero, Tower |

| System | Direction | Interface | Owner |
|---|---|---|---|
| Input & Gesture Resolver | registers, listens | Arc, backdrop, Start/Call discs (the chip is TowerInput's); `pressed`, `tap`, `drag_started`, `idle`, `ground_tap` | Input (API); HUD (meaning) |
| Tower System | calls, listens | `build`; `slot_tapped`; `chip_state()`; `tower_inspected`; TowerInput is built first | Tower |
| Hero System | reads, serves | State and timers; HeroInput reads `burst_button_centre()` and registers the button | Hero |
| Game State & Stage Flow | calls, listens | Start/Call, Retry, resume, `phase_changed` | Flow |

Headless wiring tests are unaffected, since the HUD is absent, and `phase_changed` and `lives_changed` join Flow's view allowlist.

## Formulas

The **arc_disc** formula is defined as:

`arc_disc(k) = slot + R × (sin(a_k), −cos(a_k))`, with `a` −60°, 0° and 60° for triangle, hexagon and square

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `slot` | 2D point | field units | data file | Slot position |
| `R` | float, units | 96 | constant | Presentation (user decision, 2026-11-04, up from 76 so panels fit text); chords come to 96, leaving 24 between discs of radius 36, and 24 to the slot's own disc |
| `a_k` | angle | −60°, 0°, 60° | constant | Fan angle per disc |

**Output Range:** inside x 72 to 468, and y 208 to `slot y − 48` under tightened L1.
**Example:** slot (270, 305): (186.9, 257), (270, 209), (353.1, 257).

The **display_seconds** formula is defined as:

`display_seconds = (ticks + ticks_per_second − 1) div ticks_per_second`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `ticks` | int | 0 and up | calculated (Flow, Hero) | Whole ticks left |
| `ticks_per_second` | int | 60 proposed | injected | `to_ticks(1.0)`, so a test's `dt` of 0.25 gives 4 |

**Output Range:** 0 only at 0, so a digit never shows 0 while time remains.
**Example:** 600 → 10, 541 → 10, 540 → 9, 1 → 1.

The **burst_y** formula is defined as:

`burst_y = clamp(888 − I_bottom, 816, 888)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `I_bottom` | float, units | 0 and up | platform | Bottom inset in field units |

**Output Range:** 816 to 888, the whole line `pin_exclusion` already covers, so the simulation is unchanged by a device.
**Example:** inset 0: 888. Inset 72, or 48 dp: 816. Above an `I_bottom` of 96 the hit disc enters the inset, which is the Mobile GDD's.

`burst_button_centre() -> Vector2` returns x 456, or 84 left-handed, and `burst_y`. It is the one centre for the hit disc, Hero's cancel distances and the ring (Hero Rule 15).

The **burst_fill** formula is defined as:

`burst_fill = 1 − clamp(float(cooldown_left) / max(1, to_ticks(cooldown)), 0, 1)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `cooldown_left` | int, ticks | 0 and up | calculated (Hero) | Ticks until Ready |
| `cooldown` | float, seconds | one tick to 600 | data file (Burst) | Read through the accessor |

**Output Range:** 0 when Cooling begins, rising to 1 at Ready, in float, so whole-number division cannot truncate it, and the `max` guards a zero divisor. Above the total it clamps to 0. The fill returns as a clockwise sweep (art bible §2).
**Example:** 600 left of a 600-tick cooldown: 0. 300 left: 0.5. 0 left: 1.

The **chip_bar** formula is defined as:

`chip_bar = clamp(1 − elapsed / window, 0, 1)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `elapsed` | float, ms | 0 and up | calculated (Tower's `chip_state()`) | Real time since the chip opened |
| `window` | float, ms | 1,500 | Tower's `chip_state()` | The chip's window, so the HUD holds no copy |

**Output Range:** 0 to 1. It is a display of Tower's window, and defines no new value.
**Example:** 750 ms: 0.5.

## Edge Cases

- **If gold rises while an arc is open**: discs re-dim at once, and a disc that became affordable works.
- **If a slot is tapped while its neighbour's arc is open**: the backdrop takes the press and dismisses, as Input requires. The next tap opens the new arc.
- **If an arc is open when the hero's walk reaches a disc**: nothing changes. A drag from the overlap goes to the hero and closes the arc (Input).
- **If Start/Call appears under a resting thumb**: that press stays dead under Rule 11, or is frozen out under Input Rule 2.
- **If an arc is open when Wave ends**: Start/Call registers disabled, and enables when the arc closes.
- **If the countdown ends during a press on Call**: Flow ignores the late tap. The wave has started and the button is hidden.
- **If the bonus falls to 0 while shown**: the label becomes "Call", and a call still starts the wave.
- **If a call's displayed bonus and paid bonus could differ**: they do not, under the frame order in Rule 10, since both use Tower's formula on the same tick count. The ADR verifies that order.
- **If Retry is tapped twice**: the latch is idempotent, so there is one rebuild.
- **If a press is down when the result appears, or the app loses focus with one down**: the Control never saw it, or clears it on the lifecycle signal, so it cannot fire.
- **If a second finger lands on a modal**: on Paused its press replaces whatever is held, and the first finger's release counts for nothing; on a result screen it is ignored while a counting press is held (Rule 2).
- **If a double tap on a slot drifts onto a disc inside 200 ms**: the arc closes and nothing is bought (Rule 6).
- **If a tap lands on an arc panel's word**: it dismisses the arc, as any press off the discs does. `/ux-design` decides whether panels become targets.
- **If the chip is tapped in its first 200 ms**: Tower's bounce guard makes it dead, and a second tap works. The phone test watches it.
- **If the viewport resizes during a modal press**: `modal_cancel()` clears it (Rule 2). Insets stay fixed for the battle until the Mobile Platform GDD, so the button's art and hit disc cannot split.
- **If a chip's press is held past 1,500 ms**: the window has expired, so the tap does nothing (Tower Rule 8).
- **If `build` is called twice from a double tap on a disc**: the arc unregistered on the first `OK`, so there is no second.
- **If the player has built nothing, never pinned and loses**: rule 1 of the next-try line shows. Hero 0 and Burst 0 appear as they are.
- **If no enemy got through on a Lost**: unreachable, since losing means leaks.
- **If two types tie for most lives lost**: heavy, then normal, then fast.
- **If damage total is 0**: the three rows read 0, with no division anywhere.
- **If the chip's disc overlaps a neighbouring tower**: the chip wins by priority while open. Starter slots are 160 apart, so it cannot overlap; L4 permits 72, so a later stage may. Accepted, and watched in the Pillar 4 test.
- **If the arc's cost would be asked past a level count**: unreachable. The arc reads level 1, and the chip reads `level + 1` only below the count.
- **If `phase()` turns Fatal during a cost read or the snapshot**: the read is abandoned, no snapshot is written, and the Fatal screen replaces the HUD, ahead of any retry latch. `halted()` is not the test, because it is also true on Won and Lost.
- **If the app loses focus with an arc open**: Paused closes it, and the resume tap reaches nothing beneath.
- **If a player taps Play again after a Won**: the same rebuild, with the same seed.
- **If the log file cannot be written**: a development error, and play goes on. It is never fatal.
- **If handedness is left**: only the burst button and its digit mirror. Start/Call stays, 7.2 clear at the worst.

## Dependencies

**Upstream (hard):**

| System | Interface |
|---|---|
| Game State & Stage Flow | `phase_changed`, `lives_changed`, `wave_called_early` for the log, reads of lives, `intermission_left` and result; Start/Call, Retry, resume |
| Tower System | `gold()`, `gold_changed`, `tower_built`, `tower_upgraded`, `slot_tapped`, `build`, `chip_state()`, `tower_inspected`, `slows_applied()`, `early_call_bonus(seconds_left)` |
| Hero System | `burst_state()`, `cooldown_left()`, `pin_state()`, `hero_pinned`, `burst_started`, counters, `best_victims`; HeroInput's `cooldown_digit()`, `aim_state()` and `button_press()`; Flow's `in_build()` |
| Input & Gesture Resolver | Registry, `pressed`, `tap`, `drag_started`, `idle`, `ground_tap` |
| Data & Config Pipeline | Costs and stats through the accessor by `def_id`; level count; tower IDs and role tags; Stage and Wave directly; the Input record's fields, injected |
| Enemy & Wave | `wave_index()`, `got_through_by_type()`, `wave_cleared` for the log; `to_ticks` and `dt` are exposed by the battle and injected by the wrapper |

**Soft:** Combat (counters for the result, and `dealt_by_kind` for the log).

**Downstream (these have no GDD yet):**

| System | Interface |
|---|---|
| Onboarding Prompts (Vertical Slice) | Replaces Rule 13 |
| Menu & Screen Flow (Vertical Slice) | Replaces Play again |
| Stage Progression (Vertical Slice) | Replaces the result screen with its report; uses the log's snapshot |
| Settings & Accessibility (Alpha) | Left-hand and Reduce Motion flags; an alternative path to discs |
| Mobile Platform (Vertical Slice) | Insets and stretch |

Per the bidirectional rule, each must list this one when authored. Flow, Tower, Hero, Input, Enemy & Wave, Combat and Data already do.

## Visual/Audio Requirements

Primitives only, and nothing has been rendered. Text sits on panel. Tower and Hero own their field visuals, which are not restated. Audio: none at MVP.

| Element | Visual |
|---|---|
| Lives | Neutral dashes, gap 3. A lost dash goes to alpha 0.2 in 200 ms, still countable |
| Pips | 20 × 10 pills, since discs would match the glyphs below. Filled done, outlined current, dotted upcoming. With `wave_index()` W: Build has pip 1 current; Wave and Lost have W − 1 done and W current; Intermission has W done and W + 1 current; Won has all done; Paused shows the phase it left |
| Gold | 16 dp tabular digits |
| Next-wave line | Neutral glyphs at true size, 16, 22 and 30, with the fast's notch, because at a smaller size normal and heavy merge. Counts 14 dp |
| Start/Call | Panel rect, 2 px neutral outline, two 14 dp lines. Arming: alpha 0.5, stepping to full at Armed, since art bible §7 never animates panel opacity (user decision, 2026-11-04). Burst glyph 16 px neutral |
| Arc | The disc is a hit area only and is not drawn. A tower-size polygon with panel fill and a 3 px cyan contour. Panel above, 80 × 56, with the word and cost on two 14 dp lines. Provisional: `/ux-design` settles panels, targets and contrast |
| Chip | 76 × 44 panel, 16 dp cost, 20 px cyan level-2 polygon, neutral bar |
| Unaffordable | Alpha 0.55, cost struck through |
| Prompt | 14 dp, one line, on panel |
| Result | All 16 dp, left-aligned, no headline size. Lost glyphs outlined. Retry neutral fill. Retry and Play again sit at alpha 0.5 until Armed, stepping to full, and lighten while a counting press is held, so a slide-off shows. Won's panel is compact and two-column, with the board visible above it |
| Paused | Static 40% scrim, 300 × 64 panel |
| Ground ring | 2 px neutral, radius 16, alpha 0.35, 150 ms in, unlike the pin's 30 |

**Colour.** Field-anchored polygons, in the arc and chip, stay cyan: that tower, there. Screen space stays neutral, including enemy and burst glyphs. Backups for colour: strike, alpha, and fill, outline or dots.

📌 **Asset Spec:** once the art bible is approved, run `/asset-spec system:battle-hud`.

## Game Feel

A purchase, a tap and a press all answer on the next frame, and nothing bounces. Lost: the outlined hero holds for 0.4 s, then only Retry is filled, so the eye goes to it, and a retry is one tap. The next-try line reads as advice rather than blame, since it avoids "you" and the past tense. Won: with brightening cut, the reward is a short 0.4 s hold and the finished build left in view above a compact panel, which is thin (Open Questions). Start/Call never hurries the player. All timings wait for a first phone test.

## UI Requirements

This whole document is UI. Tower's and Hero's UI Requirements stand, and are drawn here.

- 120 ms: arc, presses. Arming is a step at 300 ms. 200 ms: dash, 12-unit panel slides, with opacity fixed. Paused is instant.
- Reduce Motion cuts slides, while fades and clock bars stay. It is the `reduce_motion` data flag until Settings exists, as the hand is `left_handed`, both on Data's Input record.
- Budget: expected 8, at most 12 of 60 draw calls, and text at most 3, one per size. Modals add about 4, inside the 12, since no arc or chip is open behind them. Unverified, and ADR-0011 measures it.
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
| Priorities, registry, ring count, Controls | `design/gdd/input-gesture-resolver.md` | Priority table; Rule 2; UI Requirements | Rule dependency; amended |
| Slots, L1, L3, L7, wave records, next-wave line, leaks | `design/gdd/enemy-wave.md` | Layout; Open Questions | Value dependency; amended |
| Counters shown | `design/gdd/combat-damage.md` | Rule 5; Deferred; UI Requirements | Rule dependency; amended |
| Costs, accessor, level count, preview context | `design/gdd/data-config-pipeline.md` | Rule 10 | Rule dependency |
| Band, panels, type, colour, lives, chip | `design/art/art-bible.md` | §2, §3, §4, §7, §8 | Value dependency; amended |

## Acceptance Criteria

Unit tests drive HudLogic with fakes: resolver, reads, commands, log sink; a spy accessor; `advance(ms)`. The recorded fake calls in each THEN are the complete list, and any extra call fails. Outputs are HudLogic's view-model fields. `advance` steps at most 100 at a time, since it clamps, except where a criterion tests the clamp. No scene or time assertions.

**CI: Logic**
1. (Rule 3; Data, Enemy & Wave rows) **GIVEN** a spy changing cost, **WHEN** the arc reopens, **THEN** the spy records a new read and the new cost shows. A new instance on the same fakes has its arc Closed, 0 rings, no prompt latched, buttons Hidden and an empty snapshot.
2. (Rule 4; Pips row) **GIVEN** Fatal, **THEN** the visible set is empty. **GIVEN** each of Build, Wave, Intermission, Paused, Lost and Won, **THEN** the visible set is: lives, pips and gold in all; burst button in the first four; Start/Call and next-wave line in Build and Intermission, and in Paused when it left one of them. The pips match `wave_index()` as that row states, read after the phase's emit.
3. (Rule 5) **GIVEN** a wave with heavy 2 + 1 and fast 3 in split groups, **THEN** `[heavy 3, fast 3]`. A wave with all three types, listed fast first, reads heavy, normal, fast. With different records per wave, Build at `wave_index()` 0 shows wave 1 and Intermission at 1 shows wave 2.
4. (Rule 6) **WHEN** `slot_tapped`, **THEN** backdrop TAP 250, discs TAP 300 radius 36, triangle, hexagon, square on either hand; Start/Call disabled. **GIVEN** an arc opened at 0, **WHEN** the hexagon is pressed at `advance` total 199 and released at 500, **THEN** no `build`, the arc closed and its targets unregistered. On a fresh arc pressed at 200 and released at once, one `build(slot_index, tower_id)` with that slot and the splash tower's ID. Across fresh arcs, the triangle builds the single tower, the hexagon splash and the square slow, and each panel shows that tower's word and cost.
5. (Rule 7; Tower row) `OK` closes and unregisters at once; `NO_GOLD` stays and nudges, with the nudge off under `reduce_motion`; `HALTED` closes; others close and log an error. One tap, one `build`, with the tapped slot and that disc's tower ID.
6. (Rule 7; Rule 1) Level 1 read on opening and `gold_changed`; dimming flips both ways; a newly affordable disc builds. With the burst Ready and no other key changing, a `gold_changed` that crosses a cost changes HudField's redraw key, and one that crosses none does not.
7. (Rule 8; Input row) A press outside closes and unregisters; a later `tap(backdrop)` does nothing, with no ring. `drag_started` closes. Roll-off and a phase change stay open. Paused, outcome and Fatal close.
8. (Rule 9) A fake `chip_state()` with window 1,500 at elapsed 0, 750 and 1,499 gives the bar 1, 0.5 and just above 0; a fake window of 3,000 at 750 gives 0.75; dimmed below cost. `tower_inspected`: ring visible at 1,499 ms, gone at 1,500, no chip. Arc open: one ring per distinct level-1 range. Chip open: current plus next at alpha 0.25. After a build or upgrade: alpha 1 at 400 ms, about 0.5 at 500, gone at 600.
9. (Rule 10) "Start"; "Call +7"; bonus 0 "Call", and a call there still issues the command; hidden in Wave; the glyph is the full ring on Ready, the wedge on Cooling and Telegraphing, and dotted when Locked. **WHEN** `pressed(best_tap = start_call, best_drag = hero)` then `tap(start_call)`, **THEN** no command. **WHEN** `pressed(best_tap = start_call, best_drag = none)` then `tap(start_call)`, **THEN** one command, even if a later read puts the hero over the button.
10. (Rule 11; Flow row) A press during Arming, released once Armed, does nothing; the next press commands once. The drag beneath is criterion 36.
11. (Hidden) Unregistered; its phase begins: registered and dimmed. A new HudLogic on a fake reading Build, with no emit, has Start Arming and Armed 300 ms later.
12. (Arming) 299 no, 300 Armed; `advance(5000)` counts 100; phase end Hidden; Paused holds, and return does not restart it. Retry and Play again start Arming when their text shows and are Armed 300 ms later, with the same clamp. Paused has no arming state.
13. (Armed) A counted tap: one command; phase end Hidden. Press while Armed, phase end, release: no command.
14. (Arc states) Closed: no targets. Open: all registered. An arc across Wave's end: Start/Call registers disabled, and enables on close.
15. (Rule 12) Build pinned reads Locked, and Wave unpinned reads Locked, each its own fixture; Ready reads Ready; Telegraphing reads fill 0; Cooling reads its fill; x 456, left 84. The spy records a Burst `cooldown` read while Cooling, and a changed value changes the fill.
16. (Rule 13) Each prompt on its fixture; first match wins; pinned with no tower in Wave gets prompt 3; prompt 3 stays through a spawn gap, hides in Intermission and returns in the next Wave; prompt 2 hides while an arc is open; no prompt on an outcome or in Paused; a prompt survives 60,000 ms of `advance` and hides on its signal.
17. (Prompt states) **GIVEN** pinned, no tower and `burst_started` fired, **WHEN** Intermission begins, **THEN** prompt 2 shows. **GIVEN** pinned, a tower built and `burst_started` fired, **THEN** no prompt in any later phase.
18. (Rule 14) Three rings, then none; a dismissal draws none; a rebuild resets.
19. (Rule 15; Combat row) (a) One snapshot, built on the first `advance` after the outcome, includes the fatal leak, and screen and log sink get equal values. (b) A Lost in wave 3 reads "Broke on wave 3 of 6", then each Lost line as the table states. (c) Each Won line likewise, with "Lives 7 of 10" for 7 left and no "Got through" line on screen while the log sink still receives it. (d) Text hidden at 399 ms and shown at 400, on both. (e) Damage 2.5 reads 3; 0 reads 0; "Slowed" is absent with no slow tower built, and reads "Slowed 0" if it never fired.
20. (Rule 16) Each next-try line in order; a fixture where count and lives disagree; ties heavy, normal, fast; a no-line type with the most lives lost gives the next type's line; a top type whose role is built, with an unbuilt runner-up, gives no line.
21. (Rules 2, 17) **Result, once Armed:** `modal_press` and `modal_release` inside the rect: one command. The rect moves with `B`: Play again at (270, 904) at `B` 0 and (270, 832) at `I_bottom` 100. A press outside the rect, or a press inside it released outside: none. A release with no press: none. A release at `tap_slop` from its press, or a `modal_move` to `tap_slop` then a move back: none. A press within `edge_reject_margin` or an inset: none, and it does not disturb a held press. **Second press:** p1 press, p2 press, p2 release: none, and p1's release then gives one command. A killed press, or one begun during Arming, does not block a later p2 tap. p1 press, p1 press again, release: one command, from the second press. A press held 10,000 ms then released in place: one command. Press, `modal_cancel()`, release: none. Press, `modal_cancel_pointer(i)`, release: none; the same call for another pointer leaves it held. A press during Arming, released once Armed: none. **Paused:** a press and release at `advance` total 0 resumes once, anywhere outside the rejected zones. A press in a rejected zone, or a move to `tap_slop`: none. Any later non-rejected press replaces whatever is held, moved or killed included, and only the later one's release resumes. A rejected press leaves a held press counting. A release with no press: none. Press, `modal_cancel()`, release: none. Each `modal_changed` fires synchronously with its change: result, paused, none, and none on Fatal.
22. (Rule 18) A Retry tap makes one latch call and calls nothing that frees.
23. (Rule 19) One record per attempt and per call, all fields, the call's written at the next `wave_cleared` or outcome with the burst readiness it had at the call, even if the burst changed state since, each fixtured; burst state not through Tower; a sink failure is non-fatal, and logs a development error.
24. (arc_disc) Slot (270, 305): the three example points, within 0.1.
25. (display_seconds) 600→10, 541→10, 540→9, 1→1, 0→0.
26. (burst_y) 0→888, 72→816, 200→816.
27. (chip_bar) 0→1, 750→0.5, 1,500→0, 2,000→0.
28. (Rule 1) A fake supplying each injected value builds HudLogic with no Node, and a changed `tap_slop`, `edge_reject_margin` or inset changes criterion 21's boundaries. `dt` 0.25 reaches `early_call_bonus`, and a fake `to_ticks` of 4 per second shows 2 for 5 ticks.
29. (burst_fill) 600 of 600→0; 300 of 600→0.5; 0 of 600→1; 700 of 600→0; 0 of 0→1; 5 of 0→0.
30. (Rule 15) On the outcome, the modal model is active before any `advance`. A press at 399 with the text hidden, released once Armed, issues no command. On a Lost, a spy accessor's snapshot completes with `halted()` true. If `phase()` turns Fatal during it, no snapshot is written.
31. (Edge cases) The spy sees no read of `level + 1` at the top level. With `reduce_motion`, slides are cut, and fades and clock bars stay. A left hand leaves Start/Call's position unchanged.

**CI: Integration.** Rig detail waits on ADR-0001 and ADR-0004; each row states what it must prove.
32. (Independence) With a fixed seed and one sim-level command list at fixed ticks, run A uses headless wiring and run B adds HudLogic with a null view. At every tick a named state dump (phase, lives, gold, slots, wave index, enemy positions and HP, hero and burst state) is equal, and HudLogic issued no commands. The list reaches an outcome, and HudLogic's snapshot is non-empty, so an unwired HudLogic fails.
33. (Rule 1) Headless wiring builds no HUD piece.
34. (Paid) With real Tower, Flow and HudLogic, advance to a non-zero bonus and read the shown value, then call before the next tick. Gold rises by exactly that value. Repeat at a whole-second boundary.
35. (Retry) With a real app root and battle, two Retry requests before the root's frame give one rebuild; a latch with Fatal raised shows Fatal and builds nothing. The new HudLogic is Closed, with 0 rings. After a Won, Play again rebuilds once with the same seed.
36. (Real resolver) With real resolver, HeroInput and HudLogic, slops from the starter Input record, Start/Call Armed in Intermission and the hero 60 from its centre: a press inside both discs released in place calls nothing; moved past `tap_slop` it re-pins and calls nothing; a press at the centre calls. With Start/Call Arming, a press in the overlap moved past `tap_slop` re-pins and issues no command. With an arc open, a press on Start/Call or a neighbouring slot closes the arc and issues no command, and the next tap on that slot opens its arc.
37. (Content) Real records pass; each check fails on its own fixture, watched failing once.
38. (Pillar 4, 44 pt / 48 dp) With the real wrapper's HudLogic, TowerInput and HeroInput, each registered radius (arc, chip, Start/Call, burst) passes Input's `target_ok` at 360 dp; Retry's and Play again's rect has a short side of at least 72 units.
39. (Rule 12) With real HudLogic, HudField's reads and HeroInput: Cooling with no press shows the digit on the button; a cooling press shows it above the thumb at `button_press()`'s position, with the button bare; on release it returns to the button; a Locked press nudges. A build in the order of Rule 1 raises no null read.
40. (Rule 2) With real HudModals and HudLogic, a real press and release on Retry issues the latch call and on Paused resumes; a `canceled` touch issues nothing; each of `lifecycle_paused` and `viewport_resized` clears a held press.
41. (Rule 1, Flow Rule 6) With real Flow and HudLogic, a new battle has Start Arming with no emit, and Armed 300 ms later.

**Deferred criteria.** Done for this system means every numbered criterion, the Manual list and every row below pass, integration included. Until then a row stays open under the owner in its Owner column. A story may close while a row is open, never on one that has failed.

| Criterion | Owner | Passes when |
|---|---|---|
| First run | User, first playable | Hero's First run row passes |
| Human log | Battle HUD stories | A record is written per attempt and call on a debug build |
| Rule 2 | ADR-0003 and its device spike | Manual evidence shows a press held across a screen change or focus loss does not fire a Control, and one physical press gives one `modal_press` with a stable index, on mouse and touch |
| Rule 10 | ADR-0003 for event order, ADR-0004 for frame order | Input is observed before ticks in one frame |
| Rule 18 | ADR-0001 | A rebuild from the latch is safe under the chosen `free()` timing, and hiding Paused inside its own handler is safe |
| Draw calls | ADR-0011 | At most 12, text at most 3, measured on the arc-open and modal frames |
| Phone targets | Mobile Platform | Hit discs measure 48 dp at a 360 dp width |

**Manual** (retained as `production/qa/evidence/[story-slug]/[NN]-[state].png` at 540 × 960, blocking for UI, per `.claude/docs/run-and-observe.md`). The first HUD story sets the project viewport to 540 × 960 and adds debug routes to each state below; without them, its evidence reads NOT VERIFIED: Build; Wave; Intermission; arc open with one unaffordable disc; chip open; the range-ring states; Locked, Ready, Cooling and Telegraphing; Arming against Armed; "Call" against "Call +7"; the three burst glyphs; the `NO_GOLD` nudge; Won, with the board visible and all rows inside the panel; Lost with a next-try line and Slowed; Paused; each prompt; left hand; ground ring; Reduce Motion. Burst press response: three or more ordered frames. Render tests, each with lead sign-off: three glyphs in grey at quarter scale can be told apart; fast's notch shows at 16; pills read apart from dashes; the level-2 inset reads at 20 px; "Call +7", "Call +99", "Splash" and "Drag from the corner button" are unclipped in their panels; alpha 0.55 text is legible; the hero outline reads beside the Lost panel. `/ux-design` adds any further pass conditions.

**Checked by code review, not tests:** HudLogic has no Node dependency; HudTopBand ignores input; Start/Call has no pulse or advice once armed; release builds do not write the log.

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Do the next-try hints help? "Squares slow fast enemies" is unproven: no bot isolates it, a square earns nothing alone, and nothing can be sold, so it could prompt a permanent bad buy. Remove that line if human logs do not support it | Human logs | First playable |
| A wrong arc disc is a permanent mis-fire against a bar of zero. At `R` 96 adjacent discs are 24 units apart, and the 200 ms guard stops double taps only. Measure the rate. Fallbacks in order: hit radius up to 44, which leaves the top panel 3 units from the prompt and needs L1 tightened to x 164 to 376, then a 1.5 s build refund, which touches no-selling and Tower | Pillar 4 phone test | First phone build |
| Is a 0.4 s hold and a compact panel enough reward for a hard-won first win? | First-run test | First playable |
| Could "Broke on wave N" read as out of gold? Flow's wording stands for now | User + playtest | First playable |
| Do three prompts crowd a first run, or still leave room for the first-run target? | First-run test | First playable |
| Is the prompt at the top seen, while the eyes are on the lane? | First-run test | First playable |
| Which font? Tabular figures and a licence must be checked | art-director | First render |
| Does the stretch mode change every inset check? A 360 × 800 dp phone is taller than 9:16 | technical-director | Mobile Platform |
| At a large top inset, the band meets the arc's top panel and the prompt. Won's panel also overlaps tower bodies above `B` 16. Play again enters the inset above `I_bottom` 92 and is wholly dead at 164, with no other exit | Mobile Platform GDD | Mobile Platform |
| Does a brush resume a live wave too often, now Paused has no arming? Log unintended resumes; the fallback is Paused's own 300 ms clock. Also log unintended Retry and Play again fires: a resting palm that lifts on the button would rebuild and lose the Won screen | Pillar 4 phone test | First phone build |
| Arc panels cover the lane in Wave at slot (270, 305), against art bible §7's "never under a panel" | art-director, `/ux-design` | Before epics |
| "Burst N" is the only use of that word on screen, and N is not labelled as damage. Won's column has no spare row for a heading | `/ux-design` | Before epics |
| Every game action is a disc, so there is no keyboard, gamepad or screen-reader path, and touch alone is a motor barrier | Settings & Accessibility GDD | Alpha |
| Is 7.2 enough clearance beside the left-hand button? | Pillar 4 phone test | First phone build |
| Do misses on Start/Call's dead overlap matter? Fallback: count a tap whose press is nearer the button's centre than the hero's, at the risk that a tap meant for the hero calls a wave | Pillar 4 phone test | First phone build |
| Does a second tap on a tower spend gold by accident, given the chip sits above it? | Pillar 4 phone test | First phone build |
| The phone test also needs reach, occlusion and a required left-hand run, which the P1 gate omits | Pillar 4 phone test | First phone build |
| Should arc panels be targets, and do unaffordable panels meet contrast? | `/ux-design` | Before epics |
