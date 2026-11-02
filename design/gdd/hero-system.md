# Hero System (incl. Burst Skill, Pin & Aim Feedback)

> **Status**: Designed (pending independent review)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (pin shortfall stated, re-pin counter, calling restated, first pin taught, first-run measure). User then set the cooldown to 10 s, accepted re-pinning at about 2 lives and set the first-run target; the burst was reworked to fit, after the gate.
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-02
> **Last Verified**: 2026-11-02
> **Implements Pillar**: Pillar 2 (One Hero, Not an Army); Pillar 4 (Thumb-First)

## Summary

The player's hands on the field: one hero pinned by a drag, fighting whatever enters its leash, with one small, lethal aimed burst every 10 seconds. Players feel it as the deciding move, because where the hero stands limits where the burst can land, and a well-aimed burst kills most of what it touches. It owns the pin, the auto-attack, the burst and their feedback, and no damage, targeting helpers, enemy list or button placement.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Input & Gesture Resolver, Combat & Damage, Enemy & Wave, Data & Config Pipeline, Game State & Stage Flow`

## Overview

The hero is the one thing the player steers. A drag from the hero sets its pin, and it walks there in a straight line and holds. It chips at whatever enters its leash, and that is minor by design. Its real weight is the burst: a drag from one large button aims a small, lethal hit, every 10 seconds, at a spot within reach of where the hero stands. So the pin decides which stretch of path can be burst, and aim decides how many die. It exists because towers alone must not be enough (Pillar 2) and because aiming a burst into a bunch and re-pinning to a leak were the prototype's best moments. An untouched hero does nothing at all. The hero cannot be hurt at MVP. It owns the pin, leash, walk, auto-attack, burst timing and aim. Combat applies the damage, and the HUD places the button.

## Detailed Design

### Core Rules

**Two pieces, as for Tower.** Bots run headless, and the resolver lives in the wrapper.

| Piece | Built by | Holds |
|---|---|---|
| HeroSim | Battle builder, also headless | Pin, position, attack and burst timers, the two commands, counters, the tick entry |
| HeroInput | Wrapper, absent headless | Input registration, pin clamping, the aim state, previews |

HeroInput changes the battle only through the two commands. This amends Input Rule 11, which had bots call `press`, `move` and `release`: the resolver is not in the headless build. One test keeps the intent: the same script through the resolver and HeroInput, and through direct commands, gives identical state.

**The pin.**

1. **Nothing happens until the first pin.** The hero starts unpinned at the stage's `hero_start`. It fights nothing, and the burst is refused until it is pinned, so the button stays locked. A never-pinned run is therefore identical to towers-only by rule (Combat's deferred gate), which is the prototype's pet test, and the first thing a player learns is the pin.
2. **`pin(position)` sets the destination.** It runs between ticks, and returns `HALTED` (`halted()` is true), `BAD_POSITION` (not finite), `OUT_OF_BOUNDS` (outside `pin_rect`), `BUTTON_ZONE` (under 104 from either hand's burst button line, in Stage's `pin_exclusion`: the hero's radius of 56 plus the button's 48), or `OK`, checked in that order. A refusal changes nothing. In Build a pin applies at once and walking starts on the first tick (Flow Rule 10).
3. **The hero walks in a straight line.** At `walk_speed`, 240 units per second, with no path-following, so "no pathfinding" stands. It does not attack while walking, and a new pin restarts from where it is. There is no re-pin cooldown. Crossing the starter hairpin takes about 2 s, so two fronts cost something, but it is not a chore.
4. **The leash is the hero's whole reach.** The hero stands at its pin and attacks the nearest enemy from `targets()` inside `leash_radius`. There is no separate range and no chasing inside the leash: one ring means one thing, which is how the prototype's players read it. This amends Combat Rule 10 and its criterion 11.
5. **Auto-attack is deliberately small.** It exists to make the pin feel inhabited, at 4 damage per second against a level-1 single tower's 20. About 5% of a stage's damage comes from it, and 8% at the very most.

**The burst.**

6. **`burst(aim_point)` commits at once.** It returns `HALTED`, `BUILD_PHASE`, `NOT_PINNED`, `NOT_READY`, `BAD_POSITION`, `OFF_FIELD`, `OUT_OF_REACH` (over `reach` from the hero's current position) or `OK`, in that order, so state is checked before geometry. On `OK`, it reads `telegraph_duration`, holds `aim_point` fixed and starts `max(1, to_ticks(telegraph_duration))` ticks of telegraph. There is no cancel after release.
7. **Reach ties the burst to the pin.** The aim must lie within `reach`, 160 units, of the hero's current position, so a walking hero's reach moves with it. The auto-attack is too small to make standing anywhere matter, so without this, one well-placed pin matched an active player, and at 200 it nearly did. At 160, the best single pin found ends 1 to 3 lives lower on the four mixed builds. So re-pinning is worth about 2 lives on one path. The user accepted that for MVP (2026-11-02), and Enemy & Wave's lanes remain the fallback (Open Questions).
8. **Release.** When the telegraph ends, in the Hero-and-burst slot (Combat Rule 2), victims are `all_in_radius` of `aim_point` over `targets()`, using current positions. Each gets one `deliver` with source kind BURST. An enemy can walk out during the telegraph, and a fast one moves 44 units. A burst that lands on nobody still spends its cooldown, since a cancel before release is free.
9. **Cooldown runs from release, and not during the telegraph.** So one full cycle is `telegraph_duration + cooldown`, which is what Enemy & Wave's intermission rule compares against. The timer ticks wherever ticks run, so Intermission restores it, and Build does not. The burst starts Ready, and it is refused in Build (Flow Rule 10). That rule is also why a first burst is never wasted before wave 1 starts.
10. **A small, lethal burst keeps a 10 s cooldown inside the share target.** The user set 10 s (2026-11-02). Share is damage × victims × number of bursts, so with twice the bursts a wide one cannot stay near Pillar 2's target: radius 130 reached about 45%. So the radius is 70 and damage 130: each burst kills every `fast` and `normal` it touches, and a `heavy` loses about a sixth of its HP. Fewer victims keep share down, and a small ring makes aim the skill. Results are sensitive to radius: 65 gave a median share of 28% at reach 200, and 75 gave 37%. Overkill counts for nothing, as ever.

**Aim, in HeroInput.**

11. **Arming.** A press on the button arms an aim only if the burst is Ready, the hero has been pinned and the phase is not Build. Otherwise the whole press is dead: a cooling press shows the seconds digit above the thumb, and an early thumb presses again. There is no queue.
12. **Aim point.** `aim_point` is the finger plus (0, −100), clamped to the field, then to just inside `reach` from the hero, so exact comparison can never refuse it. It is recomputed every frame while the hero walks, so a still thumb's ring stays true. There is no flip, because no in-field path lies above y 174 (L6). This amends art bible §7 and Input's table. The offset is a presentation constant, since bots skip it.
13. **Cancel has hysteresis.** Every aim starts cancelling. It stops once the finger is over 64 from the button's centre, and resumes at 48 or less, measured on `drag_started`, each `drag_moved` and the release. On `drag_ended` the burst fires unless cancelling, so a finger released at 55 that never passed 64 cancels. `drag_cancelled` and `idle` clear the aim. A non-`OK` result from a command here is a development error. HeroInput hit-tests this itself (Input Rule 7).
14. **Pin clamp.** `pin_point` is the finger plus (0, −`pin_offset`), with `pin_offset` 0 at MVP, then moved to the nearest point just inside `pin_rect` and outside the button zone. The ghost slides along the boundary and never refuses a person, so the drawn ring is always where the pin lands; only bots see the refusals. The UX proposal of a 105 offset waits for the phone test (Open Questions), and raising it is one constant.
15. **Hit target.** The hero's DRAG radius is 56, up from 36, so an occluded grab lands. Tap targets still win a tap (Input Rule 3), though a hero within 92 of a slot now takes a thumb roll past `tap_slop` as a re-pin rather than a dead press, which is accepted and tested. The burst button's DRAG 200 and sink TAP 400 stay as in Input. The HUD places the button and HeroInput registers it. While walking, the target's centre updates every frame.

**Reading and logging.**

16. **Signals and counters.** Signals: `hero_pinned(position)`, `burst_started(aim_point, telegraph_ticks)`, plus Combat's `attack_fired` and `damage_applied`, on Flow's view allowlist. Reads: `position()`, `pin()`, `pin_state()`, `burst_state()`, `cooldown_left()`. Counted: `repins`, and per release `bursts_fired`, `bursts_hit_0`, `bursts_hit_3` and `bursts_hit_5` (at least that many), `burst_victims`, `burst_kills`, `kills_per_burst[]` and `kills_on_hit_3[]`. A victim has applied above 0, as `deliver` returns, and a kill is `is_dead` after that delivery. HeroInput's story test with a fake resolver proves its wiring, as for Tower. Development builds also log `best_victims`, the best disc centred on any enemy at release, so aim can be told from timing.
17. **The mastery metric becomes kills per burst.** "Hits 3 or more" barely tests aim here (Enemy & Wave Formulas). The personal number is median kills per burst. The concept is amended.

**Tick.** In Combat Rule 11's slot, with `halted()` checked after every read and signal, returning at once:
   1. Walking: subtract 1 from `walk_left`, and set the position along the line. At 0: exactly at the pin, Pinned.
   2. If `attack_left` is above 0, subtract 1. If still above 0, or not Pinned, go to 5.
   3. Read `leash_radius`, then `nearest_in(targets(), position, leash)`. None: hold at 0 and go to 5.
   4. Read `damage` and `attack_interval`. Set `attack_left = to_ticks(attack_interval)`, report the attack so Combat emits `attack_fired`, then `deliver`.
   5. If `cooldown_left` is above 0, subtract 1. At 0: Ready.
   6. Telegraphing: subtract 1 from `telegraph_left`. If still above 0, end.
   7. Release: read `radius`, `damage` and `cooldown`. Set Cooling and `cooldown_left = to_ticks(cooldown)`. Then `all_in_radius`, report the attack with source kind BURST, the Burst's ID and the hero's position as origin, one `deliver` per victim, then the counters.

**Starter values.** These are fixtures, not balance.

| Record | Field | Value |
|---|---|---|
| Hero | `damage`, `attack_interval` | 4, 1.0 |
| | `leash_radius`, `walk_speed` | 90, 240 |
| Burst | `damage`, `radius` | 130, 70 |
| | `cooldown`, `telegraph_duration`, `reach` | 10, 0.25, 160 |
| Stage | `hero_start` | (350, 800): 102 from the nearest slot, 80 from the path, 107 from the right-hand button |
| | `pin_rect` | x 48 to 492, y 174 to 888: a fixed worst case, so the sim needs no insets and every device agrees |
| | `pin_exclusion` | x 456 or 84, y 816 to 888: the values L3 and L7 test, and the HUD conforms to them |

**Enemy & Wave and Tower are amended to fit.** Enemy HP is now `normal` 125, `fast` 60 and `heavy` 750, every `intermission_duration` is 15 s, and Tower's `early_call_seconds_per_gold` is 1.8, which keeps the bonus cap.

**Simulated results.** A throwaway script on the starter stage with the fixed tick and tick order, and scripted bots. The mid-skill bot re-pins every 3 s just ahead of the leading enemy, waits 2 s after the burst is ready and aims 25 units off. The pinned-once bot does the same but never re-pins. The ceiling bot re-pins every 1.5 s and aims perfectly.

| Build | Towers only | Pinned once, bursts | Mid-skill | Ceiling | Towers only, always calling | Mid-skill, always calling |
|---|---|---|---|---|---|---|
| Single only | Lost W3 | Lost W4 | Won, 3 | Won, 8 | Lost W3 | Won, 2 |
| Splash only | Lost W2 | Lost W3 | Won, 4 | Won, 7 | Lost W2 | Won, 6 |
| Slow only | Lost W2 | Lost W4 | Lost W5 | Lost W5 | Lost W2 | Lost W5 |
| 3 single, 1 splash, 1 slow | Lost W5 | Won, 4 | Won, 9 | Won, 10 | Lost W5 | Won, 9 |
| 2 single, 2 splash, 1 slow | Lost W3 | Won, 5 | Won, 9 | Won, 10 | Lost W3 | Won, 9 |
| 3 single, 2 splash | Lost W5 | Won, 4 | Won, 7 | Won, 10 | Lost W5 | Won, 9 |
| 2 single, 1 splash, 2 slow | Lost W5 | Won, 4 | Won, 7 | Won, 10 | Lost W5 | Won, 9 |

The pinned-once column stands at (270, 480). Searching for the best single pin on a grid of 40 gives 7, 7, 4 and 6 lives on the four mixed builds, against mid-skill's 9, 9, 7 and 7.

| Measure, mid-skill on mixed builds | Result | Gate |
|---|---|---|
| Hero share | 28%, 38%, 26%, 28%; median 28% | Median 25% to 30%, none above 40%: passes |
| Burst alone | 21% to 33% | Reported, since it decides the spike |
| Median kills, bursts hitting 3 or more | 3 to 4, from 4 to 5 hit | At least 2: passes |
| Bursts per stage | 10 to 12 | None |
| Burst share in 2, 2 and 1 against single only | 33% against 25% | At least 75% of it: passes |
| Stage length | 5.1 to 5.3 min; 3.7 to 3.9 with every call | Concept's 5 to 8: passes uncalled |

Aim now counts for a lot, and share moves with it. At reach 200, reacting in 1 s with perfect aim gave 30% to 45% and all 10 lives, and reacting in 3 s, 50 units off, gave 18% to 23% and 5 to 7 lives. So the 25% to 30% band describes one skill level, not every player. Hero alone loses on wave 3. The ceiling bot took 27% to 41%. Without the burst, the mid-skill bot lost on wave 5 or 6 on every mixed build, so the burst is what wins.

**Calling is still close to free for a bot.** On mixed builds it cost no lives, and gained 2 on two builds from the gold, and it cuts the stage to under 4 minutes, below the concept's 5 to 8. Bots need no preparation, and enemies take many seconds to arrive. So whether a person pays a cost moves to logs at first playable (Acceptance Criteria), with Flow's overlapping waves as the fallback.

**Content rules, added to the content test.** All bounds are proposed.

| Check | Bound | Starter |
|---|---|---|
| `leash_radius` | At least `path_width` | 72 ≤ 90 |
| Fastest enemy's `move_speed` × `to_ticks(telegraph_duration)` × `dt` | At most half the `radius` | 27.5 ≤ 35 |
| `intermission_duration` of every position but the last | At least `cooldown + telegraph_duration` (Enemy & Wave) | 15 ≥ 10.25 |
| `burst_spike` (Tower) | At least 2 | 5.78 |
| L11 (Enemy & Wave) | Some disc of `radius` holds at least 2.5 × `radius` of path, so a bend exists to burst | 196 ≥ 175 |
| `reach` | At least `radius`, at most 540 | 160 |
| `hero_start` | A valid pin; at least `path_width / 2 + 40` from the path, at least 92 from any slot | 80, 102 |
| `pin_rect` | x margin at least 36; top at least 174 (L6); bottom at most 888 | Pass |

**Handed to owning GDDs.**
- **Combat:** Rule 10's leash check loses its separate range, `deliver` returns what it applied, and a read of remaining HP is added for the aim preview.
- **Battle HUD:** places the button at `pin_exclusion`'s coordinates, draws the digit, and keeps Start/Call clear of `hero_start`.
- **Game State & Stage Flow:** injects `in_build()` beside `halted()`.
- **Stage Progression (Vertical Slice):** reads the counters for the report.

**Deliberately not built for MVP.** Hero health, chasing, a range field, re-pin cooldown, finisher damage, cooldown reduction on kills, charges, aim queueing, aim snap, slow motion while aiming, haptics, audio, hit-count readouts, a walk-route line, recall, and handed aim offsets. Left-hand and Reduce Motion are data flags with no settings screen until Alpha.

→ Becomes an ADR: where HeroInput sits in the wrapper, and input against the view's per-frame centre update.

### States and Transitions

| Hero | Meaning | `pin` `OK` | On tick |
|---|---|---|---|
| Unpinned | At `hero_start`; fights nothing | → Walking | No reads, no attack |
| Walking | Moving to the pin; no attacks; its attack timer still counts | Restart from the current position | At the pin → Pinned |
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
| Data & Config | reads | Hero and Burst through the accessor at use time; `hero_start`, `pin_rect`, `pin_exclusion` directly from Stage | Data (values); this system (meaning, balance) |
| Input & Gesture Resolver | registers, listens | HeroInput registers hero (DRAG 100), button (DRAG 200) and sink (TAP 400); hears `pressed`, `drag_*`; updates the hero's centre | Input (API); HeroInput (meaning) |
| Combat & Damage | calls | `deliver`, `nearest_in`, `all_in_radius`, `attack_fired`, `hp_left` for the preview | Combat (API); this system (when, whom, values) |
| Enemy & Wave | reads | `targets()`; rules on `time_to_exit`, intermission and fast speed | Enemy & Wave |
| Game State & Stage Flow | built, injected | Builder makes HeroSim and ticks it in order; injects `halted()` and `in_build()` | Flow (order) |
| Tower System | none directly | Balanced against through bots; `burst_spike`, gates | Bots |
| Battle HUD | listens, reads | Button placement, digit, the signals and reads of Rule 16 | HUD (drawing) |
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

`burst_safe_distance = radius − move_speed × speed_factor × to_ticks(telegraph_duration) × dt`

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

`walk_ticks = max(1, to_ticks(distance / walk_speed))` when `distance` is above 0; a pin at the hero's own position is Pinned at once

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `distance` | float, units | 0 up to the `pin_rect` diagonal | calculated | Current position to the pin |
| `walk_speed` | float, units/s | above 0 to 2,000 | data file via the accessor | Hero |

**Output Range:** 1 up to 210 ticks across the rect's diagonal of 841, so even the smallest hop takes a tick and a bot cannot chain free moves.
**Example:** 240 units: 60 ticks. The position along the line is `from + (pin − from) × (1 − walk_left / walk_ticks)`.

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
| Input & Gesture Resolver | Registry, `pressed`, `drag_*`, `drag_cancelled`, `idle` (HeroInput only) |
| Combat & Damage | `deliver`, `nearest_in`, `all_in_radius`, `attack_fired`, `hp_left`, tick slot |
| Enemy & Wave | `targets()`, wave rules |
| Data & Config Pipeline | Hero and Burst through the accessor; `hero_start`, `pin_rect`, `pin_exclusion` |
| Game State & Stage Flow | Build, tick order, `halted()`, `in_build()` |

**Soft:** Tower System, through bot gates and `burst_spike` only.

**Downstream (these have no GDD yet, so the interfaces are provisional until they confirm them):**

| System | Interface |
|---|---|
| Battle HUD & Build UI | Rule 16's reads and signals; button placement |
| Hero Weapons, Skill Tree, Synergy Hook (Vertical Slice) | Accessor context with the live hero; leash and burst keys |
| Stage Progression (Vertical Slice) | Counters |
| Visual Feedback & VFX (Vertical Slice) | `burst_started`, `attack_fired` |

Per the bidirectional rule, each must list this one when authored. Data, Input, Combat, Enemy & Wave and Flow already do.

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
| Reach ring | Neutral, dotted 3 on and 13 off, 2 px, alpha 0.35, unfilled, two-tone over the path | New |
| Clamped at reach | Reticle stops; ±20° of the reach arc turns solid, alpha 0.7 | New |
| Cancelling | Reticle alpha 0.3, no ticks; preview and kill marks hidden | §7 |
| Kill preview | Live aim only: an enemy in radius with `hp_left` at or below burst damage has its body knocked out to field colour, with a steady 2 px white contour; damaged core hidden | New |
| T to T+0.1 | Near-circle wind-up; preview holds; field −3% from T | §5 |
| T+0.1 to R | Hero snaps to 1.3×; gold ring grows to meet the preview exactly at R; glow 2 | §2 |
| Clearance | T to R+0.15 | Combat |
| R, with kills | Field restores in 120 ms. 3 px white-gold spokes from the aim to each kill, 100 ms. Ring 3 px + 1 per kill, up to 9, holds 150 ms. Hero pulses by 1 + 0.04 × kills | New |
| R, no kills | Field restores. 2 px ring fades in 80 ms; burst glow 40%; no spokes or pulse | New |
| Unpinned | Dashed leash stays on around the hero, with a one-line prompt, so the first thing to touch is marked | §3, new |
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
- Prompt until the first pin: "Drag the hero", one line on panel. It is the MVP's only tutorial text, and it needs no Onboarding system.
- Ready press: a thin ring at radius 64, which is the cancel boundary and shows beyond the fingertip, plus a cancelling reticle, as the drag affordance.
- Cooling press: the digit above the thumb, on panel.
- Left hand mirrors the button and digit only, and never the kite or the aim offset.

📌 **UX Flag — Hero System:** run `/ux-design` for pin and aim before writing epics. Open points: the reticle far from the thumb when clamped, the preview overhanging the reach ring, the ring clipping at 540 wide, the contrast of alpha 0.35 dots, and re-grabbing a hero pinned high up the screen with one thumb.

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

A recording fake logs Hero's signals, `attack_fired` and `deliver`, and each THEN is the entire log. A fake `targets()`, a fake clock stepping `T` (one tick), and a spy accessor that logs reads, changes values and latches `halted()`. `hero()`: `dt` 0.25; damage 4, interval 0.5; leash 90; walk 100; burst 105, radius 50, cooldown 1.0, telegraph 0.5, reach 200. `input()` adds a fake resolver. No scene or time assertions.

**CI: Logic**
1. (Rule 1, Unpinned) **GIVEN** a target, **WHEN** 100 T, **THEN** an empty log and no reads; `burst` returns `NOT_PINNED`.
2. (Rule 2) **GIVEN** paired faults, **THEN** `HALTED`, `BAD_POSITION`, `OUT_OF_BOUNDS`, `BUTTON_ZONE` in order, unchanged. Exactly 104: `OK`.
3. (Rule 3, Walking) **GIVEN** a pin 50 away, **WHEN** T, **THEN** 25 along and no attack; a re-pin restarts from there.
4. (Rule 4) **GIVEN** Pinned, **THEN** the nearest within 90 inclusive is hit; the hero stays.
5. (Rule 5) **GIVEN** a target, **WHEN** 8 T, **THEN** four hits of 4.
6. (Rule 6) **GIVEN** paired faults, **THEN** `HALTED`, `BUILD_PHASE`, `NOT_PINNED`, `NOT_READY`, `BAD_POSITION`, `OFF_FIELD`, `OUT_OF_REACH` in order. `OK`: `burst_started(aim, 2)`.
7. (Rule 7) **GIVEN** walking, **THEN** reach measures from the current position; exactly 200 is `OK`.
8. (Rule 8) **WHEN** one enemy leaves mid-telegraph and one enters, **THEN** one BURST `deliver`, to the entrant. Nobody: `bursts_hit_0`, and the cooldown starts.
9. (Rule 9) **GIVEN** `OK`, **THEN** release on T2, `NOT_READY` after T5, Ready on T6.
10. (Rule 10, burst_total) Six at HP 125: 630, 0 kills. HP 105: 630, 6 kills. One at 40: 40.
11. (Rule 11) Ready and pinned arms; Build, Cooling or unpinned is dead through release; Cooling reports the digit.
12. (Rule 12) **GIVEN** a finger grid and a walking hero, **THEN** clamped aims are never refused, and a still thumb's aim tracks each frame.
13. (Rule 13) Live above 64, cancelling at 48, unchanged between; a release at 55 that never passed 64 cancels; `drag_cancelled` and `idle` fire nothing and clear it.
14. (Rule 14) **GIVEN** a finger grid, **THEN** `pin` is `OK` at the ghost, including the rect's corner by the button.
15. (Rule 15) Hero DRAG 100 radius 56, button DRAG 200, sink TAP 400; a walking centre updates per frame; a thumb roll past `tap_slop` on a slot within 92 re-pins.
16. (Rule 16) **GIVEN** one script, with and without listeners, **THEN** identical state; bursts on 0, 3 and 5 set the counters, "at least".
17. (Rule 17) Kills 0, 2, 3 in `kills_per_burst`: median 2.
18. (Step 1) The last walk tick: Pinned at exactly the pin, and attacking that tick.
19. (Step 2) The attack timer counts while walking.
20. (Step 3) No target: `leash_radius` only; an entrant on T5 is hit.
21. (Step 4) Timer, `attack_fired`, `deliver` in order; changed values show on the next use; a latch stops it.
22. (Step 5) `cooldown_left` 1, T: Ready.
23. (Step 6) `telegraph_left` 2, T: no release. Telegraph 0: release on T1.
24. (Step 7) Reads, Cooling, `all_in_radius`, attack report, delivers, counters in order, with BURST and the Burst's ID; each latch stops the rest.
25. (walk_ticks) `dt` 1/60, speed 240: 240, 1.9 and 2.1 give 60, 1, 1. Distance 0: Pinned at once.
26. (Telegraphing) `burst`: `NOT_READY`; a re-pin leaves the aim where it was.
27. (Phase) An aim armed in Intermission fires in Wave.

**CI: Integration**
28. (Equivalence) One script through the resolver and HeroInput, and through direct commands: identical state.
29. (Never touched) Full state is identical to towers-only.
30. (Content) Real records pass; each rule fails on its own broken fixture, watched failing once.
31. (Flow, Combat) Build runs no T; a fatal leak lands nothing; Paused resumes exactly.

**Deferred criteria.** Bots per Simulated results. Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner | Passes when |
|---|---|---|
| Hero alone, slow-only | Hero stories | Both lose |
| Towers-only | Hero stories | The best non-calling script ends with 3 lives or fewer, a loss included; mid-skill at least 4 above |
| Pinned once | Hero stories | The best single pin on a grid of 40 ends below mid-skill on at least three of four mixed builds. This falls short of Pillar 2's "clearly lose": today it is 1 to 3 lives lower, which the user accepted for MVP. If it becomes a tie on all four, or humans re-pin without gaining, lanes come forward |
| Share | Hero stories | Median of mixed builds 25% to 30%, none above 40%, at the mid-skill bot. It moves with skill, so ±1 s and ±25 aim are reported, not gated. Human logs replace it at first playable; if it cannot be held, the user decides whether to amend the pillar |
| Burst outcome | Hero stories | Median kills on bursts hitting 3 or more is at least 2 |
| `dealt_burst` | Hero stories | 2, 2 and 1 share at least 75% of single-only's |
| Dominant build | Hero stories | At least two mixed builds within 2 lives of each other |
| Mono-role | Hero stories | Towers-only: every mono build loses. Mid-skill: every mono build ends below the best mixed build |
| Always-call, bots | Hero stories | Towers-only flips no loss and gains at most 2 lives; mid-skill fires at most 1 more burst and gains at most 2 lives on any build |
| Always-call, humans | User, first playable | Log `seconds_left`, burst readiness and next-wave lives lost per call. If frequent callers lose no more than waiters, the user decides on Flow's overlap fallback |
| First run (challenge) | User, first playable | A non-developer finds the pin unprompted beyond the one line, and wins within three attempts, with fewer than 8 lives on the first win. Target set by the user (2026-11-02) |
| Best moment | User, first playable | A non-developer names whether the burst is still a best moment, and whether a radius of 70 feels satisfying or fiddly; if not, the Open Questions fallback runs |
| Waves | Hero stories | Burst fit, two fronts and empty field, per Enemy & Wave |
| Bypass, burst state | Hero stories | Combat's invariant `I` holds; the bonus ignores burst state |
| HeroInput wiring | Hero UI story | With a fake resolver, gestures reach the commands |

**Manual** (retained in `production/qa/evidence/`): unpinned prompt and leash; ghost; reach ring; cooling digit; cancelling state; kill preview in greyscale; telegraph and spokes; Ready ticks at quarter scale.

**Checked by code review, not tests:** HeroInput acts only through `pin` and `burst`; `burst_safe_distance` and `hero_share_bound` have no code.

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Is a gap this wide right for a first-time player: every build loses by wave 5 without the hero, while one pin plus bursts wins three of four mixes? | First-run test | First playable |
| Does a burst of radius 70 still feel like the best moment? The tester loved radius 150 at 8 s against much weaker enemies. A thumb's aim may be too rough for it, and bot results swing hard with radius. Fallback: a wider, weaker burst, with share over target for the user to rule on | Non-developer test | First phone build |
| Re-pinning at about 2 lives is accepted for MVP. Do humans agree it earns its place? A 3 s bot re-pins about 110 times a stage for it. Log `repins` for humans against lives. Fallback: Enemy & Wave's parallel lanes | Bots + human logs | First playable |
| Is reach 160 felt as a clear limit or as the reticle getting stuck? Fallback: a wider reach, which weakens the pin | Playtest | First phone build |
| One build sits at 38%, and a better player reaches 45%. Is a single band right for players who improve? If it cannot hold, the user rules on the pillar's target | Human logs | First playable |
| Calling is nearly free for bots, against the concept's promised cost. Does a person feel preparation time? | Human logs | First playable |
| Should a pin use a finger offset? UX proposes 105, the systems view 0 until misses show. The leash ring shows past the thumb, so 0 stands for now | Pillar 4 phone test | First phone build |
| Can a thumb re-grab a hero pinned near the top? The offset extends a drop, not a grab | Pillar 4 phone test | First phone build |
| Should an early thumb wait on a cooling button instead of being dead? UX proposed tracking it | Playtest | First playable |
| Is a hollow kill mark readable at 22 px, and alpha 0.35 dots on a phone? | art-director | First phone build |
| Does the technical director accept the HeroSim and HeroInput split, which changes Input Rule 11? | technical-director | Input ADR |
