# Hero System (incl. Burst Skill, Pin & Aim Feedback)

> **Status**: Approved 2026-11-03 by the user, on a lighter exit after the seventh design review (NEEDS REVISION; two blockers applied, the revised criteria confirmed by one reader, no eighth full review)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (pin shortfall stated, re-pin counter, calling restated, first pin taught, first-run measure). User then set the cooldown to 10 s, accepted the value of re-pinning, first about 3 lives and then about 2 (Rule 7), and set the first-run target; the burst was reworked to fit, after the gate.
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> Sections Player Fantasy and Tuning Knobs added 2026-11-05 from existing content; no rule changed.
> **Implements Pillar**: Pillar 2 (One Hero, Not an Army); Pillar 4 (Thumb-First)

## Summary

The player's hands on the field: one hero pinned by a drag, fighting whatever enters its leash, with one small, lethal aimed burst every 10 seconds. Players feel it as the deciding move, because where the hero stands limits where the burst can land, and a well-aimed burst kills most of what it touches. It owns the pin, the auto-attack, the burst and their feedback, and no damage, targeting helpers, enemy list or button placement.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Input & Gesture Resolver, Combat & Damage, Enemy & Wave, Data & Config Pipeline, Game State & Stage Flow`

## Overview

The hero is the one thing the player steers. A drag from the hero sets its pin, and it walks there in a straight line and holds. It chips at whatever enters its leash, and that is minor by design. Its real weight is the burst: a drag from one large button aims a small, lethal hit, every 10 seconds, at a spot within reach of where the hero stands. So the pin decides which stretch of path can be burst, and aim decides how many die. It exists because towers alone must not be enough (Pillar 2) and because aiming a burst into a bunch and re-pinning to a leak were the prototype's best moments. An untouched hero does nothing at all. The hero cannot be hurt at MVP. It owns the pin, leash, walk, auto-attack, burst timing and aim. Combat applies the damage, and the HUD places the button.

## Player Fantasy

The player should feel that the hero is the deciding move. The hero is the one thing the player steers: a drag pins it, and it walks there and holds. Its auto-attack is minor by design. Its weight is the burst, a small, lethal hit every 10 s, aimed at a spot within reach of where the hero stands, so the pin decides which stretch of path can be burst, and aim decides how many die (Overview). A well-aimed burst kills most of what it touches (Summary, Rule 10). The pin commits on release: the ground ring lands first and the hero follows, so the decision feels instant even though the walk takes time. The ring and the preview closing at release turn the aim into the payoff, and spokes count the kills with sound off. The Ready ticks say the burst is back without a look at the corner (Game Feel). An untouched hero does nothing, so active play must clearly beat a hero left alone. This serves Pillar 2 (One Hero, Not an Army): towers hold ground, the hero decides fights, and hero plus burst targets 25% to 30% of stage damage. It serves Pillar 4 (Thumb-First): the pin and the aim are each one drag. Aiming a burst into a bunch and re-pinning to a leak were the prototype's best moments. The main MDA aesthetic is Challenge, through aim. All timings wait for the first phone test, so the feeling is unverified.

## Detailed Design

### Core Rules

**Two pieces, as for Tower.** Bots run headless, and the resolver lives in the wrapper.

| Piece | Built by | Holds |
|---|---|---|
| HeroSim | Battle builder, also headless | Pin, position, attack and burst timers, the two commands, counters, the tick entry |
| HeroInput | Wrapper, absent headless | Input registration, pin clamping, the aim state, previews |

HeroInput changes the battle only through the two commands. Bots call the two commands directly, since the resolver is not in the headless build (Input Rule 11). One test keeps the intent: the same script through the resolver and HeroInput, and through direct commands, gives identical state.

**The pin.**

1. **Nothing happens until the first pin.** The hero starts unpinned at the stage's `hero_start`. It fights nothing, and the burst is refused until it is pinned, so the button stays locked. It shows its grab ring, not its leash: `hero_start` is 80 from the path, so a leash of 90 would show enemies walking through a hero that does nothing. A never-pinned run is therefore identical to towers-only by rule (Combat's deferred gate), which is the prototype's pet test, and the first thing a player learns is the pin.
2. **`pin(position)` sets the destination.** It runs between ticks, and returns `HALTED` (`halted()` is true), `BAD_POSITION` (not finite), `OUT_OF_BOUNDS` (outside `pin_rect`), `BUTTON_ZONE` (inside an active shape in Stage's `pin_exclusion`), or `OK`, checked in that order. A refusal changes nothing. `pin_exclusion` is a list of segments, each with a radius and a hand (right, left or both), a disc being a segment of no length: each hand's burst line, and Start/Call's centre for both hands, each at radius 60. Only shapes for both hands and the active hand count, so a right-handed player keeps the bottom-left corner (user decision, 2026-11-02). The hand comes from `left_handed` on Data's Input record, which the builder reads and injects into HeroSim and the wrapper's HeroInput and HUD, and it is fixed for the battle. The radius is the hero's grab radius 56 plus 4: no button's centre ever lies inside the hero's grab disc, and the hero's centre never lies inside a button's 48, so each can always be pressed at its centre. Where the discs overlap, the hero wins (Rule 15). Every distance test compares squared distances, inclusive, so exactly 60 is `OK`. In Build a pin applies at once and walking starts on the first tick (Flow Rule 10).
3. **The hero walks in a straight line.** At `walk_speed`, 240 units per second, with no path-following, so "no pathfinding" stands. It does not attack while walking, and a new pin restarts from where it is. `hero_pinned` fires from the command, after the state is set. Signal handlers never issue commands. There is no re-pin cooldown. Crossing the starter hairpin takes about 2 s, so two fronts cost something, but it is not a chore.
4. **The leash is the hero's whole reach.** The hero stands at its pin and attacks the nearest enemy from `targets()` inside `leash_radius`. There is no separate range and no chasing inside the leash, so the leash means what the hero itself can hit, which is how the prototype's players read it. The burst's reach is a separate ring, shown only while aiming.
5. **Auto-attack is deliberately small.** It exists to make the pin feel inhabited, at 4 damage per second against a level-1 single tower's 20. About 5% of a stage's damage comes from it, and 8% at the very most.

**The burst.**

6. **`burst(aim_point)` commits at once.** It returns `HALTED`, `BUILD_PHASE`, `NOT_PINNED`, `NOT_READY`, `BAD_POSITION`, `OFF_FIELD` (outside 0 to 540 and 0 to 960, edges included, as in Enemy & Wave Rule 4), `OUT_OF_REACH` (over `reach` from the hero's current position) or `OK`, in that order, so state is checked before geometry. On `OK`, it reads `telegraph_duration`, holds `aim_point` fixed and starts `max(1, to_ticks(telegraph_duration))` ticks of telegraph. There is no cancel after release.
7. **Reach ties the burst to the pin.** The aim must lie within `reach`, 160 units, of the hero's current position, so a walking hero's reach moves with it. It is tested once, at command, so a hero walking through the telegraph can land a burst up to 220 from where it ends up, which is accepted. The auto-attack is too small to make standing anywhere matter, so reach is what could give the pin weight. On the four mixed builds, the best single pin ends 1, 0, 1 and 4 lives below an active player with no limit, 0, 0, 2 and 0 at 200, and 1, 1, 2 and 4 at 160, so reach adds little over no limit. Re-pinning is worth about 2 lives on one path against the best pin, and 4, 6, 7 and 4 against the fixed pin at (270, 480). The user accepted about 2 lives for MVP at reach 160 (2026-11-03), against about 3 on an earlier run. Enemy & Wave's lanes remain the fallback (Open Questions).
8. **Release.** When the telegraph ends, in the Hero-and-burst slot (Combat Rule 2), victims are `all_in_radius` of `aim_point` over `targets()`, using current positions. Each gets one `deliver` with source kind BURST and the Burst's ID. An auto-attack uses source kind HERO and the Hero's ID. The builder passes HeroSim the ID of the catalogue's one Hero record, used as the read context's `def_id` and the HERO `source_id`, and that record's `burst_id`, a reference read once at build rather than a stat, used the same way for the Burst. An enemy can walk out during the telegraph, and a fast one moves 27.5 units. A burst that lands on nobody still spends its cooldown, since a cancel before release is free.
9. **Cooldown runs from release, and not during the telegraph.** So one full cycle is `telegraph_duration + cooldown`, which is what Enemy & Wave's intermission rule compares against. The timer ticks wherever ticks run, so Intermission restores it, and Build does not. The burst starts Ready, and it is refused in Build (Flow Rule 10). That rule is also why a first burst is never wasted before wave 1 starts.
10. **A small, lethal burst keeps a 10 s cooldown inside the share target.** The user set 10 s (2026-11-02). Share is damage × victims × number of bursts, so with twice the bursts a wide one cannot stay near Pillar 2's target: radius 130 reached about 45% in an earlier run. So the radius is 70 and damage 130: each burst kills every `fast` and `normal` it touches, and a `heavy` loses about a sixth of its HP. Fewer victims keep share down, and a small ring makes aim the skill. Results are sensitive to radius: at reach 160, 65 gave a median share of 24%, below the band, and 75 gave 32%, above it. Overkill counts for nothing, as ever.

**Aim, in HeroInput.**

11. **Arming.** A press on the button arms an aim only if the burst is Ready, the hero has been pinned and the phase is not Build. Otherwise the whole press is dead: a cooling press shows the seconds digit above the thumb, and an early thumb presses again. There is no queue.
12. **Aim point.** `aim_point` is the finger plus (0, −100), clamped to the field, then to `reach − 0.01` from the hero, so exact comparison can never refuse it. It is recomputed every frame while the hero walks, so a still thumb's ring stays true. There is no flip, because no in-field path lies above y 174 (L6). This amends art bible §7 and Input's table. The offset is a presentation constant, since bots skip it.
13. **Cancel has hysteresis.** Every aim starts cancelling. It stops once the finger is over 64 from the button's centre, and resumes at 48 or less, measured on `drag_started`, each `drag_moved` and the release. On `drag_ended` the burst fires unless cancelling, so a finger released at 55 that never passed 64 cancels. `drag_cancelled` and `became_idle` clear the aim. A result other than `OK` or `HALTED` from a command here is a development error. HeroInput hit-tests this itself (Input Rule 7).
14. **Pin clamp.** `pin_point` is the finger plus (0, −`pin_offset`), with `pin_offset` 0 at MVP, passed through `PinGeometry.clamp`. `PinGeometry` is a plain class with no scene, used headless: `is_valid(point, rect, shapes)` returns `OUT_OF_BOUNDS`, `BUTTON_ZONE` or `OK` for `pin`, and `clamp_point(finger, rect, shapes, hold)` is the `clamp_pin` rule (Formulas), which HeroInput and the bots call with the active hand's shapes and the current `pin_target()`, or `hero_start` before a first pin, as `hold`. The ghost follows it and never refuses a person, so the drawn ring is always where the pin lands; only bots see the refusals. The ghost can jump where two valid edges are equally near. The UX proposal of a 105 offset waits for the phone test (Open Questions), and raising it is one constant.
15. **Hit target.** The hero's DRAG radius is 56, up from 36, so an occluded grab lands. A press inside the hero's grab disc is the hero's, over either button (user decision, 2026-11-02, from the UX review). The hero's DRAG priority is 200 and the burst button's 100, so a press inside both drags the hero, even while it walks over the button; a tap there still reaches the sink and does nothing. Start/Call is a tap target, so the HUD ignores its tap when the same press named the hero (Battle HUD Rule 10). The reason is cost: a hero grabbed by mistake is re-pinned in a moment, but a wave called or a burst spent cannot be undone, and every aim drags past 64 to reach a target. Tap targets still win a tap (Input Rule 3), though a hero within 92 of a slot now takes a thumb roll past `tap_slop` as a re-pin rather than a dead press, which is accepted and tested. The sink TAP 400 stays as in Input. The HUD places the button on the active hand's line and exposes its centre as `burst_button_centre()`, that line's x and `burst_y` (Battle HUD Formulas). HeroInput reads it once at registration, and tests inject it. That one point is the hit disc's centre, the cancel ring's and Rule 13's 64 and 48. While walking, the target's centre updates every frame, after that frame's ticks (ADR-0004).

**Reading and logging.**

16. **Signals and counters.** Signals: `hero_pinned(position)`, `burst_started(aim_point, telegraph_ticks)`, plus Combat's `attack_fired` and `damage_applied`, on Flow's view allowlist. Reads: `position()`, `pin_target()`, `pin_state()`, `burst_state()`, `cooldown_left()`. HeroInput adds `aim_state()`, `aim_point()` and `cooldown_digit()`, which is `display_seconds` of `cooldown_left` (Battle HUD Formulas), driven by an explicit `update()` so tests need no frames. Counted: `repins`, which rises on each `OK` pin after the first, mid-walk included, and not on a refusal or a pin at the hero's own position; and per release `bursts_fired`, `bursts_hit_0`, `bursts_hit_3` and `bursts_hit_5` (at least that many), `burst_victims`, `burst_kills`, `kills_per_burst[]`, which gains an entry on every release, a 0 included, and `kills_on_hit_3[]`, which gains that burst's kills only when it had 3 or more victims. A victim has applied above 0, as `deliver` returns, and a kill is `is_dead` after that delivery. HeroInput's story test with a fake resolver proves its wiring, as for Tower. Development builds also log `best_victims`, the best disc centred on any enemy at release, so aim can be told from timing.
17. **The mastery metric becomes kills per burst.** "Hits 3 or more" barely tests aim here (Enemy & Wave Formulas). The personal number is median kills per burst. The concept is amended.

**Tick.** In Combat Rule 11's slot, with `halted()` checked after every read and signal, returning at once:
   1. Walking: subtract 1 from `walk_left`, and set the position along the line. At 0: exactly at the pin, Pinned.
   2. If `attack_left` is above 0, subtract 1. If still above 0, or not Pinned, go to 5.
   3. Read `leash_radius`, then `nearest_in(targets(), pos_x, pos_y, leash)`, with the hero's position as two floats (ADR-0009). None: hold at 0 and go to 5.
   4. Read `damage` and `attack_interval`. Set `attack_left = to_ticks(attack_interval)`, call Combat's `report_attack`, which emits `attack_fired`, then `deliver`.
   5. If Cooling: subtract 1 from `cooldown_left`; at 0, Ready. Nothing else touches the burst here, since `cooldown_left` is also 0 while Ready and Telegraphing.
   6. Telegraphing: subtract 1 from `telegraph_left`. If still above 0, end.
   7. Release: read `radius`, `damage` and `cooldown`. Set Cooling and `cooldown_left = to_ticks(cooldown)`. Then `all_in_radius(targets(), aim_x, aim_y, radius)`, with the aim point as two floats (ADR-0009), `report_attack` with source kind BURST, the Burst's ID and the hero's position as origin (as `Vector2`, a view payload), one `deliver` per victim, then the counters.

**Starter values.** These are fixtures, not balance.

| Record | Field | Value |
|---|---|---|
| Hero | `damage`, `attack_interval` | 4, 1.0 |
| | `leash_radius`, `walk_speed` | 90, 240 |
| Burst | `damage`, `radius` | 130, 70 |
| | `cooldown`, `telegraph_duration`, `reach` | 10, 0.25, 160 |
| Stage | `hero_start` | (350, 800): 102 from the nearest slot, 80 from the path, 107 from the right-hand button |
| | `pin_rect` | x 48 to 492, y 174 to 888: a fixed worst case, so the sim needs no insets and every device agrees |
| | `pin_exclusion` | Right hand: segment (456, 816) to (456, 888). Left hand: segment (84, 816) to (84, 888). These are the lines L3 and L7 test. Both hands: the point (186, 800). Each at radius 60. The HUD conforms to them |

**Enemy & Wave and Tower are amended to fit.** Enemy HP is now `normal` 125, `fast` 60 and `heavy` 750, every `intermission_duration` is 15 s, and Tower's `early_call_seconds_per_gold` is 1.8, which keeps the bonus cap. Single's level 2 damage is 21, so upgrading competes with filling every slot (Tower System), and a `heavy` costs 3 lives (Enemy & Wave).

**Simulated results.** A throwaway script, `tools/balance-sim/hero_bots.py`, on the starter stage with the fixed tick and tick order, and scripted bots. It is not game code: the Hero stories build the real bots to this table, and the script decides any detail the table leaves out. All bots buy in the listed order as gold allows, level 1s first, in slot order 1, 0, 2, 3, 4 and then upgrades, and none is random.

| Bot | Re-pin | Burst fires when | Aim |
|---|---|---|---|
| Mid-skill | Every 3 s, to `clamp_pin` of the path point 60 ahead of the leading enemy | Once Ready, after 2 s counted only on ticks with an enemy within reach (the count restarts after each burst), when 5 enemies fit in the radius or one is past 80% of the path | (25, 25) off the enemy whose disc holds most, clamped to reach |
| Pinned once | Never; at (270, 480) | As mid-skill | As mid-skill |
| Best single pin | Never; the best valid point on a 40-unit grid, x 70 to 470 and y 200 to 840, so its lives are a lower bound | As mid-skill | As mid-skill |
| Ceiling | Every 1.5 s | As mid-skill, with no 2 s wait | Exact |

During intermission the script runs only the cooldowns: the hero does not walk and a telegraph in flight waits, which is slightly pessimistic for bots that re-pin. Bots play the right hand, and the left hand gives the same table. The new exclusion shapes left every result unchanged. Bots skip the finger offset, so they can aim lower than a thumb can. Limiting them to a thumb's y 860 left every mixed build unchanged, and took splash only from 6 lives to 5 (Open Questions). A loss counts as 0 lives.

| Build | Towers only | Pinned once, bursts | Mid-skill | Ceiling | Towers only, always calling | Mid-skill, always calling |
|---|---|---|---|---|---|---|
| Single only | Lost W3 | Lost W4 | Won, 6 | Won, 10 | Lost W3 | Won, 9 |
| Splash only | Lost W2 | Lost W3 | Won, 6 | Won, 7 | Lost W2 | Won, 6 |
| Slow only | Lost W2 | Lost W4 | Lost W4 | Lost W5 | Lost W2 | Lost W4 |
| 3 single, 1 splash, 1 slow | Lost W5 | Won, 5 | Won, 9 | Won, 10 | Lost W5 | Won, 9 |
| 2 single, 2 splash, 1 slow | Lost W3 | Won, 3 | Won, 9 | Won, 10 | Lost W3 | Won, 9 |
| 3 single, 2 splash | Lost W4 | Won, 2 | Won, 9 | Won, 10 | Lost W5 | Won, 9 |
| 2 single, 1 splash, 2 slow | Lost W5 | Won, 5 | Won, 9 | Won, 10 | Lost W5 | Won, 9 |

The pinned-once column stands at (270, 480). Searching for the best single pin on a grid of 40, per build, gives 8, 8, 7 and 5 lives on the four mixed builds, against mid-skill's 9 on each. Slow only cannot win at any skill, and it is a trap build by design, since a slow tower kills nothing.

| Measure, mid-skill on mixed builds | Result | Gate |
|---|---|---|
| Hero share | 25%, 35%, 24%, 25%; median 25.1% unrounded | Median 25% to 30%, none above 40%: passes, at the band's floor |
| Burst alone | 20% to 30% | Reported, since it decides the spike |
| Median kills, bursts hitting 3 or more, per build | 3.5 to 4 | At least 2: passes |
| Bursts per stage | 10 to 11 | None |
| Burst share in 2, 2 and 1 against single only | 30% against 25% | At least 75% of it: passes |
| Stage length | 5.0 to 5.3 min; 3.6 to 3.8 with every call | Concept's 5 to 8: passes uncalled |

Aim now counts for a lot, and share moves with it. Reacting in 1 s with perfect aim gave 29% to 44% and all 10 lives, and reacting in 3 s, 50 units off, gave 18% to 24% and 6 to 9 lives. So the 25% to 30% band describes one skill level, not every player. Hero alone loses on wave 3. The ceiling bot took 26% to 41%. Without the burst, the mid-skill bot lost on wave 5 or 6 on every mixed build, so the burst is what wins.

**Calling is still close to free for a bot.** On mixed builds it changed no lives and fired at most 1 more burst, and it cuts the stage to under 4 minutes, below the concept's 5 to 8. Single only gains 3. Bots need no preparation, and enemies take many seconds to arrive. So whether a person pays a cost moves to logs at first playable (Acceptance Criteria), with Flow's overlapping waves as the fallback.

**Content rules, added to the content test.** All bounds are proposed.

| Check | Bound | Starter |
|---|---|---|
| `leash_radius` | At least `path_width` | 72 ≤ 90 |
| Fastest enemy's `move_speed` × `max(1, to_ticks(telegraph_duration))` × `dt` | At most half the `radius` | 27.5 ≤ 35 |
| `intermission_duration` of every position but the last | At least `cooldown + telegraph_duration` (Enemy & Wave) | 15 ≥ 10.25 |
| `burst_spike` (Tower) | At least 2 | 5.78 |
| L11 (Enemy & Wave) | Some disc of `radius` holds at least 2.5 × `radius` of path, so a bend exists to burst | 196 ≥ 175 |
| `reach` | At least `radius`, at most 540 | 160 |
| `hero_start` | A valid pin; at least `path_width / 2 + 40` from the path, at least 92 from any slot | 80, 102 |
| `pin_exclusion` | Covers each hand's burst line, tagged with that hand, and Start/Call's centre for both, at a radius above both the hero's 56 and that target's hit radius | 60 |
| Burst `damage` | At least the `max_hp` of `normal` and of `fast`, so a burst kills each one it touches (Rule 10) | 130 ≥ 125 and 60 |
| `pin_rect` | x margin at least 36; top at least 174 (L6); bottom at most 888 | Pass |
| Hero records | Exactly one at MVP, so the builder selects nothing | 1 |

**Handed to owning GDDs.**
- **Battle HUD:** done. It places the button at the active hand's `pin_exclusion` shape, draws the digit, exposes `burst_button_centre()`, keeps Start/Call clear of `hero_start`, and ignores a Start/Call tap whose press named the hero.
- **Input:** done. The hero's DRAG priority is 200 and the burst button's 100.
- **Data & Config:** done. Each `pin_exclusion` shape carries a hand, and the Input record holds `left_handed` and `reduce_motion`.
- **Game State & Stage Flow:** done. The builder injects `in_build()` beside `halted()`, and passes the hand and the Hero's and Burst's IDs (Rules 2, 8).
- **Stage Progression (Vertical Slice):** reads the counters for the report.

**Deliberately not built for MVP.** Hero health, chasing, a range field, re-pin cooldown, finisher damage, cooldown reduction on kills, charges, aim queueing, aim snap, slow motion while aiming, haptics, audio, hit-count readouts, a walk-route line, recall, and handed aim offsets. `left_handed` and `reduce_motion` are data flags with no settings screen until Alpha.

→ Decided in ADR-0004 Decision 5 (input against the per-frame centre update: `HeroInput.update()` runs after the frame's ticks, before views draw, so the registered centre is the drawn hero) and ADR-0010 (where HeroInput sits in the wrapper).

### States and Transitions

| Hero | Meaning | `pin` `OK` | On tick |
|---|---|---|---|
| Unpinned | At `hero_start`; fights nothing | → Walking | No reads, no attack |
| Walking | Moving to the pin; no attacks; its attack timer still counts | Restart from the current position, or Pinned at once if the pin is its own position | At the pin → Pinned |
| Pinned | At the pin; attacks inside the leash | → Walking, or stays Pinned if the pin is its own position | Attacks |

| Burst | Meaning | `burst` | On tick |
|---|---|---|---|
| Ready | The state at battle start | → Telegraphing; `BUILD_PHASE` in Build; `NOT_PINNED` before a first pin | Nothing |
| Telegraphing | Aim fixed; no cancel | `NOT_READY` | Reaches 0 → release → Cooling |
| Cooling | Timer running | `NOT_READY` | Reaches 0 → Ready |

Aiming is HeroInput's state, never the sim's: Idle, Cancelling or Live, per Rules 11 and 13. The battle does not know a thumb is aiming.

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Data & Config | reads | Hero and Burst through the accessor at use time; `hero_start`, `pin_rect`, `pin_exclusion` directly from Stage; the left-hand flag | Data (values); this system (meaning, balance) |
| Input & Gesture Resolver | registers, listens | HeroInput registers hero (DRAG, priority 200, radius 56), button (DRAG, priority 100, radius 48) and sink (TAP, priority 400, radius 48); hears `pressed`, `drag_*`; updates the hero's centre | Input (API); HeroInput (meaning) |
| Combat & Damage | calls | `deliver`, `nearest_in`, `all_in_radius`, `report_attack`, `is_dead` for kills, `hp_left` for the preview | Combat (API); this system (when, whom, values) |
| Enemy & Wave | reads | `targets()`; rules on `time_to_exit`, intermission and fast speed | Enemy & Wave |
| Game State & Stage Flow | built, injected | Builder makes HeroSim and ticks it in order; injects `halted()` and `in_build()` | Flow (order) |
| Tower System | none directly | Balanced against through bots; `burst_spike`, gates | Bots |
| Battle HUD | listens, reads | Button placement, `burst_button_centre()`, digit, the signals and reads of Rule 16 | HUD (drawing) |
| Bots and tests | call | `pin`, `burst`, counters through the builder | Harness |

## Formulas

The **burst_total** formula is defined as:

`burst_total = Σ min(damage, hp)` over the victims

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `damage` | float | 0–1,000,000 | data file via the accessor | Burst damage |
| `hp` | float | 0–1,000,000 | calculated (Combat) | Each victim's HP at release |

**Output Range:** 0 up to `damage` × victims. Kills are enemies with `hp` at or below `damage`.
**Example:** 4 fresh normals: 500 and 4 kills. 2 fresh heavies: 260 and no kills.

The **burst_safe_distance** formula is defined as:

`burst_safe_distance = radius − move_speed × speed_factor × max(1, to_ticks(telegraph_duration)) × dt`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `radius` | float, units | above 0 to 2,000 | data file via the accessor | Burst radius |
| `move_speed` | float, units/s | above 0 to 2,000 | data file via the accessor | Enemy |
| `speed_factor` | float | above 0 to 1 | Combat | Slow |
| `telegraph_duration` | float, seconds | 0–600 | data file via the accessor | Telegraph |

**Output Range:** at most `radius`, at least half of it under the content rule. An enemy this close to the aim at command is still inside at release, unless dead or off the field. It is a design aid, with no code.
**Example:** fast 42.5, normal 55, heavy 60.5.

The **walk_ticks** formula is defined as:

`walk_ticks = max(1, ceil(distance / (walk_speed × dt) − 0.0001))` when `distance` is above 0; a pin at the hero's own position is Pinned at once. This is movement, not an authored time, so it rounds up rather than using `to_ticks`, and the tolerance stops float error adding a tick

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `distance` | float, units | 0 up to the `pin_rect` diagonal | calculated | Current position to the pin |
| `walk_speed` | float, units/s | above 0 to 2,000 | data file via the accessor | Hero |

**Output Range:** 1 up to 211 ticks across the rect's diagonal of 841, so even the smallest hop takes a tick and a bot cannot chain free moves.
**Example:** 240 units: 60 ticks. The position along the line is `from + (pin − from) × (1 − float(walk_left) / float(walk_ticks))`, with the ratio in floats, and at `walk_left` 0 the position is assigned the pin directly.

The **clamp_pin** rule is defined as:

`clamp_pin(f)` = the valid candidate nearest `f`. Squared distances within 0.000001 are a tie, which goes to the smaller y and then the smaller x

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `f` | 2D point | any | calculated | The offset finger |
| `pin_rect` | rectangle | field units | data file (Stage) | Allowed area |
| `pin_exclusion` | list of segment, radius and hand | field units | data file (Stage) | Forbidden shapes, only those for both hands and the active one |
| `hold` | 2D point | a valid pin | calculated | The current pin target, or `hero_start` before a first pin |

Each shape is treated as its two endpoint circles and, for a segment of real length, two lines parallel to it, all at radius + 0.01. These are a superset of its true boundary, and the validity filter removes what lies inside another shape or the rect's outside, so no capsule splitting is needed. A disc has only its circle. Pieces that give no point are skipped: two circles with one centre, two parallel lines, and a line that misses a circle.

Candidates, in GDScript `float` scalars using only +, −, ×, ÷ and square root, never `Vector2` methods, kept only if `PinGeometry.is_valid` gives `OK`:
1. `f` clamped to the rect, and the rect's four corners.
2. The nearest point to `f` on each circle and each parallel line. At a circle's centre, the direction is (0, −1).
3. Every crossing of a circle or parallel line with a rect edge, with the edge's coordinate assigned exactly, and every crossing of two of them.

A local nearest point lies either on one smooth piece of the boundary, which step 2 finds, or at a corner between two pieces, which steps 1 and 3 find.

**Output Range:** a valid point. If no candidate is valid, which needs a valid region thinner than 0.02, it returns `hold`, valid by rule, so the ghost stays on the current pin. Points arrive and leave as `Vector2`, 32-bit in a stock build, which moves a coordinate here by under 0.0001, well inside the 0.01 margins, so `pin` accepts what comes back. The script checks the rule against valid samples along every boundary piece, for each hand.
**Example:** right hand: `f` (492, 888) gives (395.99, 888), 96 away. `f` (480, 850) gives (492, 767.99), 82.9 away, rather than (395.99, 850), 84 away, so the ghost slides up the field's edge. `f` (200, 800) is 14 from Start/Call and moves right to (246.01, 800). Left hand: `f` (84, 850) gives (144.01, 850).

The **hero_share_bound** formula is defined as:

`hero_share_bound = min(1, (damage_per_second × T + N × burst_mean) / stage_hp)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `damage_per_second` | float | 0 and up | calculated | `damage / attack_interval` |
| `T` | float, seconds | 0 and up | bots | Seconds of a stage with a target in the leash |
| `N` | int | 0 and up | bots | Bursts fired |
| `burst_mean` | float | 0 and up | bots | Mean `burst_total` |
| `stage_hp` | float | above 0 | data file | Sum of `max_hp × count` |

**Output Range:** 0 to 1. It assumes nothing else dealt the damage, so it is a design aid.
**Example:** `stage_hp` 16,790, `T` 200, `N` 11, `burst_mean` 300: (800 + 3,300) / 16,790 = 24%. So staying under 30% allows about 385 per burst, or three fresh normals.

## Edge Cases

- **If the player pins where the hero stands**: `OK`, a walk of 0 ticks, Pinned at once. A first pin there still counts as pinning.
- **If a pin lands on a slot or tower**: it is allowed. A hero on a slot never blocks building, and the tap winner gets taps (Input).
- **If the player presses the button before any pin**: the press is dead, and the button shows Locked as it does in Build.
- **If a pin is dragged off the field or under the button**: HeroInput clamps it, so the ghost shows where it will land. Bots get `OUT_OF_BOUNDS` or `BUTTON_ZONE`.
- **If the hero is pressed while a burst aim runs**: impossible with one pointer (Input Rule 1).
- **If `burst` is called during a telegraph**: `NOT_READY`. A burst cannot be queued.
- **If an aim is held across a phase change**: it stays live (Flow Rule 10). An aim armed in Intermission can release in Wave.
- **If the hero walks across Start/Call**: a walk may cross a no-pin shape, since only a destination is tested. A press inside the hero's grab disc is the hero's: a tap there calls nothing, and a drag re-pins (Battle HUD Rule 10). The rest of the button works throughout, and a pinned hero, 60 or more away, never covers its centre.
- **If the hero walks over the burst button**: a press inside the hero's grab disc drags the hero, which outranks the button (Rule 15); the rest of the button still aims, and a tap anywhere on it reaches the sink. A crossing lasts at most 0.87 s.
- **If the player is left-handed**: only the left burst line and Start/Call refuse pins, and the bottom-right corner is open. Handedness cannot change mid-battle.
- **If the hero walks during an aim**: the reach ring moves with it, and the aim re-clamps each frame and on release, which runs between ticks, so `OUT_OF_REACH` never reaches a person.
- **If a re-pin starts during a telegraph**: the burst still lands at its fixed `aim_point`. Reach is tested once, at command.
- **If a bot's aim point is exactly on the edge of `reach` or `radius`**: inclusive, so it counts.
- **If `telegraph_duration` is 0**: the floor of one tick applies, so the burst lands on the next tick and the cycle stays the sum in the wave rule.
- **If a burst releases with no target in radius**: `attack_fired` draws the ring, nothing else fires, `bursts_hit_0` rises, and the cooldown starts.
- **If an enemy reaches the exit during a telegraph**: it leaks first (Combat Rule 11), so the burst does not touch it.
- **If an enemy is off the field at release**: untouched, since it is not in `targets()`.
- **If a fatal leak arrives during a telegraph**: the rest of the tick is skipped, so nothing lands (Flow Rule 15).
- **If Paused arrives during an aim**: `drag_cancelled` from `cancel()`: nothing fires, and the thumb starts over.
- **If Paused arrives during a telegraph or walk**: the clock stops, and both resume exactly.
- **If the last wave's burst is unused**: nothing happens. It has no value after Won.
- **If the hero is pinned and no enemy ever enters its leash**: it holds ready. The player's reach still works.
- **If `reach` covers no enemy**: an aim can still release, and it lands on nobody and spends the cooldown. The preview shows no victims first.
- **If a bad accessor read happens in a tick**: the handler halts, and step checks return at once with nothing half done (Flow Rule 18).
- **If a tower's kill empties a burst's radius first**: the tower slot runs first, so the burst finds fewer victims. Towers keep credit, which lowers hero share (Combat Rule 11).

## Dependencies

**Upstream (hard):**

| System | Interface |
|---|---|
| Input & Gesture Resolver | Registry, `pressed`, `drag_*`, `drag_cancelled`, `became_idle` (HeroInput only) |
| Combat & Damage | `deliver`, `nearest_in`, `all_in_radius`, `report_attack`, `is_dead`, `hp_left`, tick slot |
| Enemy & Wave | `targets()`, wave rules |
| Data & Config Pipeline | Hero and Burst through the accessor; `hero_start`, `pin_rect`, `pin_exclusion` |
| Game State & Stage Flow | Build, tick order, `halted()`, `in_build()` |

**Soft:** Tower System, through bot gates and `burst_spike` only. Battle HUD, which has its own GDD, reads Rule 16's reads and signals, conforms to `pin_exclusion`, and supplies the button's centre.

**Downstream (these have no GDD yet, so the interfaces are provisional until they confirm them):**

| System | Interface |
|---|---|
| Hero Weapons, Skill Tree, Synergy Hook (Vertical Slice) | Accessor context with the live hero; leash and burst keys |
| Stage Progression (Vertical Slice) | Counters |
| Visual Feedback & VFX (Vertical Slice) | `burst_started`, `attack_fired` |

Per the bidirectional rule, each must list this one when authored. Data, Input, Combat, Enemy & Wave and Flow already do.

## Tuning Knobs

Starter values are fixtures, not balance (Starter values). Every bound from this GDD's content-rule table is proposed, as that table says. A range marked "field domain" comes from the field-domain table in `design/gdd/data-config-pipeline.md`, which guards against typos and broken simulation, not balance. Bot parameters belong to the simulation, and visual sizes and timings sit in Visual/Audio Requirements, so neither is repeated here.

| Knob | Current value | Safe range | What it changes | Owner | Source |
|---|---|---|---|---|---|
| Hero `damage` | 4 (starter fixture) | 0 to 1,000,000 (field domain); Rule 5 keeps the auto-attack near 5% of stage damage, 8% at most | Auto-attack damage, and `hero_share_bound` | Hero | Rule 5: 4 per second against a level-1 single tower's 20 |
| Hero `attack_interval` | 1.0 s (starter fixture) | One tick (1/60) to 600 (field domain) | Auto-attack cadence | Hero | Rule 5 |
| `leash_radius` | 90 (starter fixture) | At least `path_width`, 72 (proposed); up to 2,000 (field domain) | What the hero itself can hit | Hero | Content rules; prototype leash 90 |
| `walk_speed` | 240 (starter fixture) | Above 0 to 2,000 (field domain) | Cost of a re-pin: crossing the hairpin takes about 2 s | Hero | Rule 3; prototype walk 240 |
| Burst `damage` | 130 (starter fixture) | At least the `max_hp` of `normal` and `fast`, 125 and 60 (proposed); up to 1,000,000 (field domain) | Kills per burst; a `heavy` loses about a sixth of its HP | Hero | Rule 10 |
| Burst `radius` | 70 (starter fixture) | The fastest enemy's travel during the telegraph at most half of it, 27.5 against 35; `reach` at least `radius` (both proposed); up to 2,000 (field domain) | Victims per burst, and so hero share | Hero | Rule 10: at reach 160, 65 gave a share median of 24% and 75 gave 32%, both outside the band |
| Burst `cooldown` | 10 s | Every `intermission_duration` but the last at least `cooldown + telegraph_duration` (proposed); one tick to 600 (field domain) | Bursts per stage, 10 to 11 simulated | Hero | User set 10 s (2026-11-02) |
| `telegraph_duration` | 0.25 s (starter fixture) | The fastest enemy's `move_speed` × `max(1, to_ticks(telegraph_duration))` × `dt` at most half the `radius` (proposed); 0 to 600 (field domain), with a floor of one tick | Time an enemy has to walk out of the aim | Hero | Content rules; `burst_safe_distance` |
| `reach` | 160 (starter fixture) | At least `radius`, at most 540 (proposed) | How far from the hero a burst may land, and so how much the pin matters | Hero | Rule 7: re-pinning is worth about 2 lives at 160, accepted by the user (2026-11-03) |
| `hero_start` | (350, 800) | A valid pin; at least `path_width / 2 + 40` from the path and at least 92 from any slot (proposed) | Where the hero waits before the first pin | Hero (Stage field) | Content rules: 80 and 102 |
| `pin_rect` | x 48 to 492, y 174 to 888 | x margin at least 36; top at least 174 (L6); bottom at most 888 (proposed) | Where a pin may land | Hero (Stage field) | Content rules |
| `pin_exclusion` radius | 60 | Above the hero's grab radius 56 and the target's hit radius (proposed) | Room kept clear of pins around each button | Hero (Stage field); the HUD conforms | Rule 2: grab radius 56 plus 4 |
| Hero grab (DRAG) radius | 56 | range not set in this GDD | How easily an occluded hero is grabbed | Hero | Rule 15 (user decision, 2026-11-02) |
| Aim offset | (0, −100) | range not set in this GDD | Where the aim sits above the thumb | Hero (presentation constant) | Rule 12 |
| `pin_offset` | 0 at MVP; a UX proposal of 105 waits for the phone test | range not set in this GDD | Where the pin sits above the thumb | Hero | Rule 14 |
| Cancel hysteresis | Stops past 64 from the button's centre, resumes at 48 or less | range not set in this GDD | When an aim stops cancelling | Hero | Rule 13 |

## Visual/Audio Requirements

Primitives only. Nothing has been rendered and every value is unverified on a device. T is `burst_started` and R is release; clocks stop on Pause. Audio: none at MVP.

| Event | Visual | Art bible |
|---|---|---|
| Press hero | Dashed leash at the hero, on the first frame | §3 |
| Drag | Leash and a 2 px unfilled, glowless kite ghost at `pin_point`. The leash carries it, since the thumb hides the ghost | §1 |
| Release | Ground ring (2 px solid, radius 30) and leash snap to the pin | §5, amended |
| Walking | Tip locked on the pin, long axis +6%, no breathing | New |
| Arrival | 6% smaller for 0.1 s, then returns | §5 |
| Aim | Reticle with no flip, and a solid 2 px radius preview | §3 |
| Reach ring | Neutral, dotted 3 on and 13 off, 2 px, alpha 0.6, unfilled, two-tone over the path | New |
| Clamped at reach | Reticle stops; ±20° of the reach arc turns solid, alpha 0.7 | New |
| Cancelling | Reticle alpha 0.3, no ticks; preview and kill marks hidden | §7 |
| Kill preview | Live aim only: an enemy in radius with `hp_left` at or below burst damage has its body knocked out to field colour, with a steady 2 px white contour; damaged core hidden | New |
| T to T+0.1 | Near-circle wind-up; preview holds; field −3% from T | §5 |
| T+0.1 to R | Hero snaps to 1.3×; gold ring grows to meet the preview exactly at R; glow 2 | §2 |
| Clearance | T to R+0.15 | Combat |
| R, with kills | Field restores in 120 ms. 3 px white-gold spokes from the aim to each kill, 100 ms. Ring 3 px + 1 per kill, up to 9, holds 150 ms. Hero pulses by 1 + 0.04 × kills | New |
| R, no kills | Field restores. 2 px ring fades in 80 ms; burst glow 40%; no spokes or pulse | New |
| Unpinned | Dashed ring at the hero's grab radius 56, not the leash, with a one-line prompt, so the first thing to touch is marked and no enemy crosses it. A press shows the leash as usual | §3, new |
| Ready | Four static 3 px ticks, 8 long, radius 40 around the hero, in Wave and Intermission, and only once pinned | New |
| Ready, first frame | Ticks close in from radius 56, button scale 1.15 to 1, 120 ms, once; no glow change | §7 |
| Reduce Motion | No dip, wind-up, snap or Ready pop; a static ring from T+0.1, 4 px at R; spokes stay | §7 |
| Defeat / Victory | Outline, glow 0 / idle, glow 1. Leash, rings and ticks removed | §2 |

📌 **Asset Spec:** once the art bible is approved, run `/asset-spec system:hero-system`.

## Game Feel

The pin commits on release: the ground ring lands first, and the hero follows, so the decision feels instant even though the walk takes time. The ring and the preview closing at release turn the aim into the payoff. Kills change the marks, not just the duration, so spokes count them with sound off. A burst every 10 s keeps the thumb busy, and the Ready ticks say it has arrived without a look at the corner. All timings wait for the first phone test.

## UI Requirements

Battle HUD draws these, and this system supplies the state.

- Locked, in Build or before a first pin: dotted neutral outline, no fill or digit. A press nudges ±2 px once for 120 ms, skipped under Reduce Motion. Before a first pin, the nudge also repeats the prompt.
- Prompt until the first pin: "Drag the hero", one line on panel, the first of three the Battle HUD owns (Rule 13 there). None needs an Onboarding system.
- Ready press: a thin ring at radius 64, which is the cancel boundary and shows beyond the fingertip, plus a cancelling reticle, as the drag affordance.
- Cooling press: the digit above the thumb, on panel.
- Left hand mirrors the button and digit only, and never the kite or the aim offset.

📌 **UX Flag — Hero System:** run `/ux-design` for pin and aim before writing epics. Open points: the reticle far from the thumb when clamped, the preview overhanging the reach ring, the ring clipping at 540 wide, the contrast of the reach dots, and re-grabbing a hero pinned high up the screen with one thumb.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Hero share, hero-only fails, pin and aim model, mastery metric | `design/gdd/game-concept.md` | Pillar 2, Core Mechanic 2, Mastery | Rule dependency; amended |
| `deliver`, helpers, tick slot, source kinds, clearance | `design/gdd/combat-damage.md` | Rules 2, 6, 10, 11, 12 | Rule dependency; amended |
| `targets()`, HP, intermission, wave rules, L3, L6, L7, L11 | `design/gdd/enemy-wave.md` | Rules 13, 14; Starter values; Layout | Value dependency; amended |
| Bot gates, `burst_spike`, bonus rate | `design/gdd/tower-system.md` | Formulas; Acceptance Criteria | Value dependency; amended |
| Records, stat keys, never cache | `design/gdd/data-config-pipeline.md` | Hero, Burst, Stage; Rule 10 | Value dependency; amended |
| Live actions, burst refused in Build, `halted()` | `design/gdd/game-state-stage-flow.md` | Rules 9, 10, 15 | Rule dependency; amended |
| Gestures, radii, bots' door, offset, cancel | `design/gdd/input-gesture-resolver.md` | Rules 3, 7, 11, 12; Dependencies | Rule dependency; amended |
| Kite, poses, line styles, reticle, button | `design/art/art-bible.md` | §2, §3, §5, §7, §8 | Value dependency; amended |
| Leash 90, walk 240, 8 s burst, best moments | `prototypes/hero-pin-concept/REPORT.md` | Result; Lessons | Evidence |

## Acceptance Criteria

A recording fake logs Hero's signals, `attack_fired` and `deliver`, and each THEN is the entire log from the WHEN on. A hit in a THEN logs `attack_fired` and then its `deliver`, and a release logs `attack_fired` first, even on nobody. A fake `targets()`, a fake clock stepping `T` (one tick), and a spy accessor that logs reads, changes values and latches `halted()`. `hero()`: `dt` 0.25; damage 4, interval 0.5; leash 90; walk 100; burst 105, radius 50, cooldown 1.0, telegraph 0.5, reach 200; starter `pin_rect` and `pin_exclusion`; a settable `in_build()` stub. `input()` adds a fake resolver and an injected button centre, (456, 852), and calls `update()` directly. Paired faults means every pair of faults in the rule's list that can occur together, the earlier code winning, and each code is also tested alone. A finger grid is every 8 units over 540 × 960, with x 540 and y 960 added so the edges are tested. Logic criteria use the right hand unless they say otherwise. Exact distance cases use axis-aligned offsets. No scene or time assertions.

**CI: Logic**
1. (Rule 1, Unpinned) **GIVEN** a target, **WHEN** 100 T, **THEN** an empty log and no reads; `burst` returns `NOT_PINNED`.
2. (Rule 2) **GIVEN** paired faults, **THEN** `HALTED`, `BAD_POSITION`, `OUT_OF_BOUNDS`, `BUTTON_ZONE` in order, unchanged. Right hand: (396, 850) `OK`, (397, 850) `BUTTON_ZONE`; (84, 850) `OK`, since that line is the left hand's. Left hand: (84, 756) `OK`, (84, 757) `BUTTON_ZONE`; (456, 850) `OK`. Start/Call, either hand: (186, 740) `OK`, (186, 741) `BUTTON_ZONE`.
3. (Rule 3, Walking) **GIVEN** a pin 50 away, **WHEN** T, **THEN** 25 along and no attack; a re-pin restarts from there.
4. (Rule 4) **GIVEN** Pinned, **THEN** the nearest within 90 inclusive is hit; the hero stays.
5. (Rule 5) **GIVEN** Pinned with a target, **WHEN** 8 T, **THEN** four hits of 4.
6. (Rule 6) **GIVEN** paired faults, **THEN** `HALTED`, `BUILD_PHASE`, `NOT_PINNED`, `NOT_READY`, `BAD_POSITION`, `OFF_FIELD`, `OUT_OF_REACH` in order. `OK`: `burst_started(aim, 2)`.
7. (Rule 7) **GIVEN** walking, **THEN** reach measures from the current position; exactly 200 is `OK`.
8. (Rule 8) **WHEN** one enemy leaves mid-telegraph and one enters, **THEN** one BURST `deliver`, to the entrant. Nobody: `attack_fired` alone, `bursts_hit_0`, and the cooldown starts.
9. (Rule 9) **GIVEN** `OK`, **THEN** release on T2, `NOT_READY` after T5, Ready on T6.
10. (Rule 10, burst_total) Six at HP 125: 630, 0 kills. HP 105: 630, 6 kills. One at 40: 40.
11. (Rule 11) Ready and pinned: `aim_state()` is Cancelling. Build, Cooling or unpinned: Idle through release, and no command. Cooling: `cooldown_digit()` 1 with `cooldown_left` 1.
12. (Rule 12) **GIVEN** a finger grid, **WHEN** for each point, from a fresh Ready, pinned state in Wave, with the hero at its pin and again mid-walk, `burst(aim_point())` is called, **THEN** `OK` every time. **GIVEN** a still finger beyond reach and a walking hero, **WHEN** `update()`, **THEN** `aim_point()` has changed and is within `reach` of the new position.
13. (Rule 13) From Cancelling: 64.0 stays, 64.01 goes Live. From Live: 48.01 stays, 48.0 goes Cancelling. A release at 55 that never passed 64 cancels. `drag_cancelled` and `became_idle` fire nothing and give Idle.
14. (Rule 14, clamp_pin) For each hand: **GIVEN** a finger grid, **THEN** `pin` is `OK` at the ghost. **GIVEN** fingers at each active shape's endpoints and on a 20-unit grid over x 0 to 540 and y 660 to 960, edges included, **THEN** the result is no more than 0.03 further from the finger than the nearest of the valid samples, taken every 0.5 along each active circle, parallel line and rect edge. Within 0.02, right hand: (492, 888) gives (395.99, 888); (480, 850) gives (492, 767.99); (200, 800) gives (246.01, 800). Left hand: (84, 850) gives (144.01, 850). At a circle's centre: (186, 800) gives (186, 739.99). Ties, right hand: (456, 816) gives (456, 755.99), the smaller y, over (395.99, 816). Ties, with one shape, segment (270, 480) to (270, 520) at radius 60: (270, 500) gives (209.99, 500), the smaller x, over (330.01, 500). **GIVEN** shapes covering the whole rect, **THEN** `clamp` returns `hold`.
15. (Rule 15) The fake resolver records hero DRAG priority 200 radius 56, button DRAG priority 100 radius 48, sink TAP 400 radius 48; a walking hero's registered centre updates on `update()`. Which target wins is criterion 32, since a fake cannot show it.
16. (Rule 16) **GIVEN** one script, with and without listeners, **THEN** identical state; bursts with 0, 3 and 5 victims and 0, 1 and 5 kills give `bursts_fired` 3, `bursts_hit_0` 1, `bursts_hit_3` 2, `bursts_hit_5` 1, `burst_victims` 8, `burst_kills` 6, `kills_per_burst` [0, 1, 5] and `kills_on_hit_3` [1, 5]. An enemy whose fake `deliver` applies 0 is no victim. `repins` is 0 after a first pin and 1 after a second, unchanged by a refusal or a pin at the hero's own position.
17. (Rule 17) The median of an even count is the mean of the middle two, and an empty list has none. Kills 3, 0, 2: median 2. Kills 5, 0, 3, 2: median 2.5.
18. (Step 1) The last walk tick: Pinned with `position()` equal to the pin, and attacking that tick.
19. (Step 2) **GIVEN** a hit, then a re-pin 100 away with the target still in the leash, **THEN** no hit for 3 T and one on the 4th, so a timer that stops while walking fails.
20. (Step 3) No target: `leash_radius` only; an entrant on T5 is hit.
21. (Step 4) Timer, `attack_fired`, `deliver` in order; changed values show on the next use; a latch stops it.
22. (Step 5) Cooling with `cooldown_left` 1, T: Ready. Telegraphing with `cooldown_left` 0, T: still Telegraphing, and `burst` still returns `NOT_READY`.
23. (Step 6) `telegraph_left` 2, T: no release. Telegraph 0: release on T1.
24. (Step 7) Reads, Cooling, `all_in_radius`, attack report, delivers, counters in order, with BURST and the Burst's ID; each latch stops the rest.
25. (walk_ticks) `dt` 0.25, speed 100: 25, 25.01 and 100 give 1, 2 and 4, and 0.001 gives 1. `dt` 1/60, speed 240: 240 and 480 give 60 and 120. Distance 0: Pinned at once. The position at half way is the midpoint.
26. (Telegraphing) `burst`: `NOT_READY`; a re-pin leaves the aim where it was.

**CI: Integration**
27. (Equivalence) A tick-indexed gesture script, unclamped, with finger = aim + (0, 100), through the real resolver and HeroInput, and the same script through direct commands: after every tick, HeroSim's fields, counters and logs are equal. The script holds at least, in this order: a press on the button in Build, a first pin, a re-pin mid-walk, an aim released Live, a press on the button in Cooling, and an aim released while cancelling. A released Live aim has its finger over 64 from the button's centre and its aim within `reach − 0.01`. Each of the two presses drags its finger over 64 from the button's centre and releases there. The cancelled aim drags to 55 from it, never passing 64, and releases there. These three issue no command, so the direct script has no entry for them. A spy on HeroSim's `pin` and `burst` records identical calls in both runs.
28. (Never pinned) A fixed script on the starter stage to Won or Lost, with HeroSim never pinned and with HeroSim absent: per-tick lives, gold, enemies, towers, the `deliver` and `attack_fired` logs and the accessor read log are equal, and HeroSim's fields keep their initial values.
29. (Content) Real records pass; each rule fails on its own broken fixture, watched failing once.
30. (Flow, Combat) Build runs no T; a fatal leak lands nothing; Paused resumes exactly.
31. (Phase) With the real Flow and resolver, an aim armed in Intermission stays Live across the change to Wave, and its release gives `burst_started`.
32. (Rule 15, drag wins) The real resolver, `hero()` values, `drag_slop` 15, the button's centre (456, 852), an injected stage with no `pin_exclusion`, burst Ready, in Wave. **GIVEN** the hero pinned at (456, 722), **WHEN** a press lands on (456, 852), **THEN** `aim_state()` is Cancelling. **GIVEN** a new press after that one is released, and a pin to (456, 872) with 4 T, so the hero is at (456, 822), **WHEN** `update()`, a press on (456, 837), 15 from each centre, and a move to (456, 822), **THEN** `drag_started` names the hero, `aim_state()` stays Idle and no `burst` is issued.
33. (Rule 15, thumb roll) The real resolver, `hero()` values, `tap_slop` 28, one TAP slot of radius 36 at (270, 480), and the hero pinned at (270, 572), 92 from it. **WHEN** a press on (270, 516), inside both discs, is released in place, **THEN** the slot gets its tap and `repins` is unchanged. **WHEN** a press there moves to (270, 543), 27 away, **THEN** no drag. **WHEN** it moves to (270, 544), 28 away, and releases, **THEN** the slot gets no tap, `repins` rises by 1 and `pin_target()` is (270, 544).

**Deferred criteria.** Bots per Simulated results. Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner | Passes when |
|---|---|---|
| Hero alone, slow-only | Hero stories | Both lose |
| Towers-only | Hero stories | On the mixed builds, the towers-only bot without calling ends with 3 lives or fewer, a loss being 0; mid-skill at least 4 above it on each |
| Pinned once | Hero stories | The best-single-pin bot, not the fixed one, ends below mid-skill on at least three of four mixed builds. This may fall short of Pillar 2's "clearly lose": today it is 1 to 4 lives lower. The user accepted about 2 for MVP (2026-11-03). If it becomes a tie on all four, or humans re-pin without gaining, lanes come forward |
| Share | Hero stories | Median of mixed builds 25% to 30%, none above 40%, at the mid-skill bot. Today's 25.1% is 0.1 above the floor, so a small bot change can flip it, and a flip goes to the user rather than a retune. It moves with skill, so ±1 s and ±25 aim are reported, not gated. Human logs replace it at first playable; if it cannot be held, the user decides whether to amend the pillar |
| Burst outcome | Hero stories | On each mixed build, the median of `kills_on_hit_3` is at least 2; an empty list fails |
| `dealt_burst` | Hero stories | 2, 2 and 1 share at least 75% of single-only's |
| Dominant build | Hero stories | On mid-skill, at least two mixed builds within 2 lives of the best one |
| Upgrade order | Hero stories | On mid-skill, over every placement of each mixed build, the median with upgrading in pairs is at least the median with filling first. Today 9, 9, 9 and 6 against 7, 7, 8.5 and 4 (Tower System) |
| Placement | Hero stories | On mid-skill, filling first, each mixed build's best placement ends at least 3 lives above its worst. Today 3 to 10 |
| Mono-role | Hero stories | Towers-only: every mono build loses. Mid-skill: every mono build ends below the best mixed build |
| Always-call, bots | Hero stories | Towers-only flips no loss and gains at most 2 lives; on mixed builds, mid-skill fires at most 1 more burst and gains at most 2 lives. Single only gains 3 today, from the gold, and is not gated |
| Always-call, humans | User, first playable | Log `seconds_left`, burst readiness and next-wave lives lost per call. If frequent callers lose no more than waiters, the user decides on Flow's overlap fallback |
| First run (challenge) | User, first playable | A non-developer finds the pin unprompted beyond the one line, and wins within three attempts, with fewer than 8 lives on the first win. Target set by the user (2026-11-02) |
| Radius 70 on a phone | User, MVP+ phone test | At most 25% of human bursts hit nobody (`bursts_hit_0` / `bursts_fired`), and median kills per burst is at least 2. Pass mark set by the user (2026-11-02). On a fail, the Open Questions fallback runs |
| Best moment | User, first playable | A non-developer names whether the burst is still a best moment, and whether a radius of 70 feels satisfying or fiddly; if not, the Open Questions fallback runs |
| Waves | Hero stories | Burst fit, two fronts and empty field, per Enemy & Wave |
| Bypass, burst state | Hero stories | Combat's invariant `I` holds; the bonus ignores burst state |
| Burst between ticks (Combat's row) | Hero stories | A burst commanded between ticks releases in the Hero-and-burst slot at least one tick later, and its corpses are reaped without moving |
| HeroInput wiring | Hero UI story | With a fake resolver, gestures reach the commands |
| Pins near a button | User, first phone build | A pin drag ending in the bottom third lands within 40 of the finger on at least 90% of attempts, and no press meant for the hero calls a wave or arms an aim (game-designer review, 2026-11-02) |

**Manual** (retained in `production/qa/evidence/`): unpinned prompt and leash; ghost; reach ring; cooling digit; cancelling state; kill preview in greyscale; telegraph and spokes; Ready ticks at quarter scale.

**Checked by code review, not tests:** HeroInput acts only through `pin` and `burst`; `burst_safe_distance` and `hero_share_bound` have no code.

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Is a gap this wide right for a first-time player: every build loses by wave 5 without the hero, while one pin plus bursts wins on all four mixes, with 2 to 5 lives at the fixed pin and 5 to 8 at the best one? | First-run test | First playable |
| Does a burst of radius 70 still feel like the best moment? The tester loved radius 150 at 8 s against much weaker enemies. A thumb's aim may be too rough for it, and bot results swing hard with radius. Fallback: a soft aim magnet toward the densest cluster, then a wider, weaker burst with share over target for the user to rule on | Non-developer test | First phone build |
| Re-pinning at about 2 lives was accepted for MVP (Rule 7). Do humans agree it earns its place? A 3 s bot re-pins about 110 times a stage for it. Log `repins` for humans against lives. Fallback: Enemy & Wave's parallel lanes | Bots + human logs | First playable |
| Is reach 160 felt as a clear limit or as the reticle getting stuck? Fallback: a wider reach, which weakens the pin | Playtest | First phone build |
| One build sits at 35%, and a better player reaches 44%. Is a single band right for players who improve? If it cannot hold, the user rules on the pillar's target | Human logs | First playable |
| Calling is nearly free for bots, against the concept's promised cost. Does a person feel preparation time? | Human logs | First playable |
| Should a pin use a finger offset? UX puts the top half out of a thumb's reach at 0 and proposes 100. MVP is on desktop, so 0 stands, and the phone test compares 0 and 100, including top-half pins | Pillar 4 phone test | First phone build |
| A thumb's aim stops at y 860, so a burst reaches the path only to y 930, leaving its last 30 units, and more with an inset, out of reach. Limiting the bots this way barely moved them. Does a person feel it as a lost save? | Pillar 4 phone test | First phone build |
| Can a thumb re-grab a hero pinned near the top? The offset extends a drop, not a grab | Pillar 4 phone test | First phone build |
| Should an early thumb wait on a cooling button instead of being dead? UX proposed tracking it | Playtest | First playable |
| Is a hollow kill mark readable at 22 px, and are alpha 0.6 dots clear on a phone? | art-director | First phone build |
| Does the technical director accept the HeroSim and HeroInput split, and PinGeometry's scalar floats against `Vector2`, whose 32-bit claim is unverified on 4.7? | technical-director | Input ADR |
| A burst does about 17% to a `heavy`, which costs 3 lives, so it answers everything but the enemy that hurts most. Is that felt as a gap? Vertical Slice's tower-resistant enemies depend on the answer | Human logs, with Enemy & Wave | First playable |
| Is an exclusion radius of 60 enough on a phone, or does a hero pinned beside a button take presses meant for it? Fallback: 104 for the active hand's line only | Pillar 4 phone test | First phone build |
