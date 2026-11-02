# Enemy & Wave

> **Status**: Revised after seventh design review (2026-11-02, NEEDS REVISION, 2 blocking items and 6 recommended addressed; other recommended items open in the review log); pending re-review
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (towers-only gate no longer requires a win, entry from either side, Pillar 2 bots pointed at wave design, human burst hit counts).
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-02
> **Last Verified**: 2026-11-02
> **Implements Pillar**: Pillar 2 (waves are tuned assuming the hero). **Enables** Pillar 3 (Every Stage Reads Differently) through data-driven stage geometry and layout rules; it is delivered at Vertical Slice, when a second stage of a different shape passes L1 to L13

## Summary

The enemies and the stage they walk: one authored path, build slots, three enemy types and six fixed waves whose shape makes bursts, re-pins and tower choices worth deciding. Players feel it as pressure with a readable shape, where only reaching the exit hurts, and it reports every kill and leak so lives and gold stay honest. It owns the path, roster, spawning, movement and clearing, and no damage, lives, gold or timers beyond its own schedule.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Data & Config Pipeline, Combat & Damage, Game State & Stage Flow`

## Overview

Enemy & Wave is what the player defends against. It holds the stage's one path and build slots, sends authored waves down that path, moves each enemy, and reports every enemy that dies or leaks. Enemies never attack: they walk, and the only threat is reaching the exit. Players meet it as pressure with a shape. Fast enemies pull ahead and open a second front, heavy ones soak tower fire so followers slip past, and packets catch up at points worth a burst. It exists so that wave shape, not hidden stat growth, is what gives the player's towers and hero something to decide. Waves are tuned with the hero in, so the hero stays needed (Pillar 2). It owns the path, the roster, spawning, movement, leaks and wave clearing. It does not own damage, lives, gold, the intermission clock, or who attacks whom.

## Detailed Design

### Core Rules

**The stage.**

1. **One path.** A stage has one continuous path, and an enemy's progress is one distance along it. MVP and Vertical Slice need nothing more, because Vertical Slice's "different paths" are shape changes. Forks, parallel lanes and flyer gaps wait until after Vertical Slice, and would need `path_id` on wave groups and an amended art bible §6. On one path, "the leaking lane" means the stretch the player's towers do not cover, so it depends on the build. Whether that makes players re-pin is unproven (Open Questions).
2. **Stage geometry is data.** `path_points[]`, `slot_positions[]` and `path_width` are new fields on the Stage record. This amends Data & Config, which placed them in the stage scene. Path length sets time to leak and slots set tower coverage, so they are gameplay values (Data Rule 1), and the builder and tests run without a scene (Flow Rule 2). The scene keeps the look only: field hue, base value and grid tilt. A view draws the path from the same points, so the two cannot disagree. Curves, if ever wanted, are baked to points once at load.
3. **Slots belong to the stage.** This GDD owns the layout rules below, the Stage record holds the positions, and the content test (Data Rule 9) enforces them. Tower reads `slot_positions` directly, and a slot's index is its identity, which is the order towers fire in. Hit radii come from the Input GDD: slot 36, burst 48.

**Layout rules, checked by the content test.** All numbers are proposed and in field units on the 540 × 960 field. Insets are converted at the narrowest supported width, 360 dp, where 1 dp is 1.5 units (Input, Battle HUD), because a fixed dp inset is largest in field units there. So the rules allow up to 72 units (48 dp) at the bottom and 102 units (68 dp) at the top, which puts the top band's lower edge at 174 (Battle HUD). A 59 pt notch on a 390 pt phone is about 82 units, inside that. The insets are unverified on devices. L1 and L6 keep a margin of 16 at the starter stage.

**Nothing outside the field is ever shown.** On a screen taller or wider than 9:16, everything outside the 540 × 960 field is masked, so the path's off-field ends stay unseen on every shape. How it is masked is the stretch mode decision record's (Open Questions); this rule is what that record must meet. So L5 tests against the field, not the screen. The two ways to mask treat insets differently. With letterbox bars, the notch and gesture areas fall in the bars and the in-field insets are near 0. With panels over a width-fit view, the insets above apply in full. The rules assume the second, the worse case. A screen scaled by height, wider than 9:16, shrinks the dp per unit below 0.667, Input's floor, and would push a 68 dp inset past 102 units, so the record must either keep the scale at or above that floor or recheck L1 and L6. Presses in the bars reach Input as positions outside the field, which Input's adapter already allows (Input ADR).

| # | Rule | Starter stage |
|---|---|---|
| L1 | Slot x within 138 to 402, y at least 304: its hit disc and build arc stay in the field and below the band, with no flip code (Battle HUD) | x margin 32; y 320, margin 16 |
| L2 | Slot to path centreline at least `path_width / 2 + 40`: a 56 px slot at any tilt stays off the path | 76 needed, 80 |
| L3 | Slot to the burst button's centre line, either hand (x 456 or 84, y 816 to 888, confirmed by Battle HUD), at least 92: hit discs never touch | 144 |
| L4 | Slot to slot at least 72 | 160 |
| L5 | First and last path points at least 16 outside the field, since the largest enemy's radius is 15: it enters and exits unseen | 40, 20 |
| L6 | In-field path clear of the top band at the largest inset: `y − path_width / 2` at least 174 | 190, margin 16 |
| L7 | Path centreline to the burst button's centre line at least `path_width / 2 + 64` | 100 needed, 186 |
| L8 | Separate legs stay apart: wherever two centreline points lie less than `path_width + 60` apart in a straight line, the path between them is at most 1 / sin 22.5° (about 2.61) times that distance long. Checked at every path point and every 2 units along the path, off-field ends included. A bend, a jog or a curve baked to points passes, since its points are close only where the path between them is short; parallel legs and any turn sharper than 135° fail, since there the path between close points is long | 132 needed; separate legs 160 apart |
| L9 | In-field length at least 800 | 1,644 |
| L10 | Each slot covers at least 200 of path at the lowest level-1 tower range | 223 at range 150 |
| L11 | Some disc of burst radius, searched on a grid of 10, holds at least 2.5 × that radius of path, so a bend exists to burst. Every stage: a fully straight stage is not allowed, since the burst needs a bend (user, 2026-11-02) | 196 against 175, at radius 70 |
| L12 | 3 to 5 slots, as in the concept | 5 |
| L13 | Interior points inside the field; the path enters by the left or right edge and leaves by the bottom, crossing the boundary exactly twice. Since the field is convex and both end points lie outside it (L5), the path crosses exactly twice whenever every interior point is inside, so one check covers both clauses. A segment that doubles back on the one before, a turn sharper than 135°, fails L8, so L13 has no turn clause | Pass; every turn 90° |

L10 and L11 need tower range and burst radius, so they join the test in the Tower and Hero stories. L9's 800 and L10's 200 are proposed from the starter stage, not derived from a constraint, so recheck them when stages 2 and 3 are sketched (Open Questions). A new stage must also pass Battle HUD's layout checks (Start/Call clearances and the arc rules), which the same content test runs.

**Build arcs may cover the path.** An arc's discs are an overlay drawn above the field, and enemies take no input, so no rule keeps them off the path. On the starter stage, slot 0's top disc at (270, 244) lies on the top row, and slot 1's top and left discs lie on the path.

**Entry and exit.**

4. **Enemies enter and leave unseen.** The path starts off a side edge below the top band, so it never runs under a panel, and ends off the bottom. The starter stage enters from the left. An enemy is **targetable only while its centre is inside the field**, edges included (0 to 540, 0 to 960), so nothing is hit before it can be seen. Body radius is not data, so an enemy partly visible at the edge may briefly be untargetable, which is accepted. Art bible §7's "never routed under a panel" is why the prototype's top entry is not reused. While enemies move, every Battle HUD panel, the prompt included, sits in the top band, so L6 keeps the path clear of them at any inset. The exceptions are brief overlays, the build arc and the upgrade chip (Build arcs may cover the path), and the Lost, Won and Paused screens, which cover the field only when no enemy moves (art bible §7).

**Enemies.**

5. **Three types at MVP, each with a job.** HP is fixed per type, because a hidden HP scale on an identical circle cannot be read: waves escalate through count, mix and overlap. Enemies have no attacks, armour or abilities. True armour, flying and splitters are Vertical Slice. Lane-switchers need parallel lanes, so they wait with them. The `heavy` soaks fire with no armour rule at all, because towers shoot first along the path, so followers slip past it.

| Type | Job for the player |
|---|---|
| `normal` | Forms the packets that burst and splash want |
| `fast` | Runs ahead and opens a second front; asks for slow or a re-pin |
| `heavy` | Soaks "first along the path" fire; asks for single-target damage |

**Waves.**

6. **Authored, with no randomness.** Waves are fixed so a stage can be learned. This settles Flow's retry question: a retry reuses the seed, which nothing here reads. Cosmetic jitter never uses the simulation seed.
7. **Wave control.** Flow calls `start_next_wave()` with no argument. This system owns the index into `wave_ids` and resets its per-wave state on each start, storing nothing on the record, so repeated wave IDs work. A start during an active wave or past the last wave logs a development error and is ignored. The call commits at once: the wave is Active at `wave_tick` 0. Members due at tick 0 spawn in the next advance slot, and `wave_tick` rises at the end of that slot. So a countdown's end spawns in that same tick, since Flow's slot runs first, and an early call or Start Wave spawns on the next tick.
8. **Spawning uses an absolute schedule.** Each member's whole tick is computed from wave start (Formulas), never by repeating a float countdown. Members spawn when `wave_tick` reaches their tick, with groups scanned in authored order and members in ascending order. Each takes the next battle-wide `spawn_id`, which also breaks ties, and gets its Health (seeded once from `max_hp`) and Status. A member joins the roster, and its `spawn_id` is used, only after its `max_hp` read passes the halt check (Rule 13); a halt during that read adds nothing and spends no ID. `spawn_interval` has no effect when `count` is 1.
9. **Movement.** Each enemy reads `move_speed` through the stat accessor at use time, with a read context made once per enemy (the context is reused, not the value), and multiplies by Combat's `speed_factor`. An enemy moves on the tick it spawns, as in the prototype. Its position is computed once in the move step and kept for that tick's targeting and views, clamped to the path's end.
10. **Leaks.** An enemy whose distance reaches the path length leaks. In ascending `spawn_id` order, its `lives_cost` is read through the accessor, it leaves the roster at once, and `enemy_leaked(lives_cost)` fires synchronously. A fatal leak ends the loop (Rule 13).
11. **Kills and clearing.** In the reap slot, dead enemies are handled in ascending `spawn_id` order: `bounty` is read through the accessor, the corpse is removed, and `enemy_killed(bounty)` fires, as Rule 10 does for leaks. Then comes the clear check. **It runs every tick, not only on a kill**, or a wave whose last enemy leaks would never clear, and only while a wave is active, or an empty field would emit forever. A wave is clear when its schedule is exhausted and the roster is empty, with no separate counter that could disagree. By index, not ID, the last wave emits `waves_complete()` and any other emits `wave_cleared(intermission_duration)`, with the state committed first. Leak events therefore always precede the clear, as Flow Rule 13 requires.
12. **Tick order confirmed.** Combat Rule 11 stands: Flow, then this system's advance slot (spawn, move, leak), Status countdown, towers by slot index, hero then burst, then this system's reap slot. So this system has two tick entries, and the battle's tick passes the roster to Combat's countdown, since Flow owns no roster. A corpse is reaped on the tick it dies, so it never moves.
13. **Halting.** The builder injects Flow's `halted()`, true on Won, Lost and Fatal (Flow Rules 15 and 18), so this system needs no reference to Flow. It is checked immediately after every accessor read, before the value is used, and after every signal. Spawn, move, leak and reap return at once when it is true, so nothing follows a fatal leak, and a bad read can never persist a garbage value or emit one. Enemies left on the roster at an outcome freeze where they are.
14. **Reading the enemies.** `roster()` is every enemy not yet removed, corpses awaiting the reap included, in `spawn_id` order. `targets()` is that list limited to those inside the field. Tower and Hero pass `targets()` to Combat's helpers, which skip the dead, and the burst uses it too. Both lists are read-only by rule and never kept past the reader's slot. An enemy exposes `spawn_id`, `def_id`, `distance` and `position`. Views also read `wave_index()` and `got_through_by_type()`, counts kept only for the result. How Health and Status attach is left to Combat's ADR.
15. **Room for splitters, nothing built.** One add-enemy step serves the schedule, and the clear test looks only at the schedule and the roster. So splitter children at Vertical Slice can join atomically before the clear check, with new `spawn_id`s, with no fields or code added now.

**Starter values.** These are fixtures, not balance. The Tower and Hero GDDs ran them through a scripted simulation with towers and a hero, and raised HP about 3 times, because at the first values a hero alone and towers alone both won, and set every intermission to 15 s, so that waiting restores the burst (Hero System, Simulated results). They replace the prototype's, whose top entry and 6 slots do not carry over.

| Stage field | Value |
|---|---|
| `path_points` | (−40, 226), (430, 226), (430, 400), (110, 400), (110, 570), (270, 570), (270, 980) |
| `slot_positions` | (270, 320), (190, 485), (350, 485), (170, 700), (370, 700) |
| `path_length` | 1,704 in all, 1,644 in field (calculated) |
| `path_width`, `starting_lives`, `starting_gold` | 72, 10, 120 |

| Enemy | `max_hp` | `move_speed` | `bounty` | `lives_cost` | `visual_key` |
|---|---|---|---|---|---|
| `normal` | 125 | 60 | 4 | 1 | `enemy_normal` |
| `fast` | 60 | 110 | 3 | 1 | `enemy_fast` |
| `heavy` | 750 | 38 | 16 | 2 | `enemy_heavy` |

**Bounties follow count and `lives_cost`, not HP.** A heavy pays 16 because it costs 2 lives and soaks fire, and a fast pays least per kill, though most per HP, because it dies quickly. A leak loses 4 gold per life for a normal, 3 for a fast and 8 for a heavy, so the enemy that hurts most to leak also pays most to kill. Targeting is by position, not value, so bounty per HP never steers a tower.

A group below is type × count @ `spawn_interval` + `start_delay`, in seconds from wave start.

| Wave | Groups | Total HP | `intermission_duration` | Intent |
|---|---|---|---|---|
| 1 | normal×8 @1.5 +0 | 1,000 | 15 | Learn the path; cannot be lost. A string by intent (a burst takes 2), so the burst first pays off in wave 2 |
| 2 | normal×6 @0.6 +0; normal×6 @0.6 +12 | 1,500 | 15 | Two packets, one burst cooldown apart |
| 3 | normal×12 @0.7 +0; fast×8 @0.5 +0 | 1,980 | 15 | First two fronts |
| 4 | heavy×2 @3 +0; normal×8 @0.6 +8 | 2,500 | 15 | A packet catches the heavies, mostly in the hairpin |
| 5 | fast×8 @0.4 +0; heavy×2 @4 +0; normal×10 @0.5 +4; fast×8 @0.4 +16 | 3,710 | 15 | An early leak, then a convergence |
| 6 | heavy×4 @3 +0; normal×12 @0.5 +10; fast×10 @0.4 +20; normal×8 @0.5 +24 | 6,100 | 15 (unused on the last wave) | Catches run the whole path: the first normals reach the heavies from about 100, and the fasts reach both from about 600; the last normals catch only the last heavy, from about 1,550, near the exit |

Each wave's total HP is 1.26 to 1.64 times the last.

**Stage length comes from the scripted simulation**, `tools/balance-sim/hero_bots.py`, not from a hand model. With the mid-skill driven hero on the four mixed builds, a stage runs 5.0 to 5.3 minutes with nothing called early, at the floor of the concept's 5 to 8, and 3.7 to 3.8 minutes with every wave called. These figures come from a run on the stage as this revision moved it (top row at y 226, slot 0 at y 320), and a rerun on 2026-11-02 reproduced them. Calling saves 1.3 to 1.6 minutes, more than the 75 s of skipped intermissions, because in the script each call also pays its bonus, which buys towers sooner and so ends later waves sooner. No human has played the stage, so an advisory criterion checks its length at first playable (Deferred criteria).

**Wave rules, checked by the content test.** All bounds are proposed. Waves are checked per position in `wave_ids`, because IDs repeat. A real stage also needs `starting_lives` of at least 2 and at least 2 waves, or the lives rules below cannot all hold; code-built fixtures are exempt. The `intermission_duration` and `peak_alive_ub` rows need Burst and Tower data, so they join in the Hero and Tower stories.

| Check | Bound | Starter | Reason |
|---|---|---|---|
| First spawn of a wave | At most 2 s | 0 s | The field is not empty after Start |
| Largest gap between scheduled spawns | At most 12 s | 9 s | A wave cannot be called early. This is Flow's cap on `start_delay`, measured where it matters |
| `time_to_exit`, total `path_length` ÷ `move_speed`, for each enemy type any wave of the stage uses | 12 to 60 s | 15.5 (fast) to 44.8 s (heavy) | Time for a burst; no stalled waves. A stage rule, reported as `time_to_exit_min` or `time_to_exit_max`, though a broken Enemy record can trip it. It bounds path length by the types used: with fasts at least 1,320, with heavies at most 2,280 (Open Questions) |
| `intermission_duration` of every position but the last | In ticks, `to_ticks(intermission_duration)` at least `to_ticks(cooldown) + max(1, to_ticks(telegraph_duration))`, matching how Hero counts its cycle; and at most 30 s | 900 ticks against 615, and 30 s | Waiting always restores the burst. A compare in seconds could miss by one tick at equality, since Hero rounds each part and gives the telegraph at least 1 tick. The cap keeps the early-call bonus at most 16 gold a call at Tower's 1.8 s per gold (user, 2026-11-02). Tower's 10% bonus share binds first, at about 25 s a call: 14 gold a call, 70 across five calls (gold_upper_bound) |
| First position's `lives_at_risk` | Below `starting_lives` | 8 against 10 | The first wave cannot be lost, with no runtime rule: an idle player still leaks and feels it |
| Every wave's `lives_at_risk` | At least 1 | 8 to 38 | No decorative waves |
| Stage's total `lives_at_risk` | At least `starting_lives` | 120 against 10 | Stronger than Flow's "some cost above 0", since one 1-cost enemy against 10 lives cannot lose |
| Any `lives_cost` | At most `ceil(starting_lives / 3)` | 2 | One miss does not end the stage |
| `peak_alive_ub` | At most 48 | 34 | Art bible §8's enemy pool |

Bot gates sit in Acceptance Criteria, since they cannot run until towers and the hero exist.

**Tuned assuming the hero (Pillar 2).** Waves are tuned against the driven bot first, then the towers-only shortfall is measured. Towers-only may win narrowly at MVP, and must lose from Vertical Slice.

**Handed to owning GDDs.**
- **Tower:** reads `slot_positions`; supplies DPS per type and level, and keeps its own gold bound using `gold_upper_bound`. It must ensure `starting_gold` buys its cheapest tower, or the stage soft-locks.
- **Hero:** walks re-pins at 240 in a straight line, so two fronts cost about 2 s. Keeps `fast` speed × `telegraph_duration` at most half the burst radius, or fast enemies escape the burst. The starter telegraph of 0.25 s gives 27.5 against 35 by Hero's tick-based check; the most it allows at `fast` 110 is about 0.31 s. Reads "bursts hitting 3 or more" knowing it barely tests aim here (Formulas).
- **Battle HUD:** done. It confirms the burst line, shows the next wave's enemies by glyph and count, and reports got-through by type.

**Deliberately not built for MVP.** Forks and lanes, armour, flying, splitters, lane-switchers, per-wave HP scaling, bounty multipliers, randomness, enemy attacks, a spawn signal (views read the roster), and leaks per lane.

→ Becomes an ADR: how Health and Status attach to an enemy, and the storage form of `path_points` and `slot_positions`.

### States and Transitions

| Wave control | Meaning | Transitions |
|---|---|---|
| Waiting | Before a start, or between waves; the clear check does nothing | `start_next_wave` → Active |
| Active | Schedule running or enemies remain | Clear on a non-last wave → Waiting. Clear on the last wave → Finished |
| Finished | `waves_complete` emitted | None |

| Enemy | Meaning | Transitions |
|---|---|---|
| Off field | On the roster, moving, not targetable | Centre enters the field → In field. Distance reaches the end → Leaked |
| In field | On the roster and targetable | HP 0 → Dead. Centre leaves the field → Off field |
| Dead | Not targetable; still in `roster()` until the reap | Reap → removed, with bounty |
| Leaked | Removed at once; never a target again | None |

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Data & Config | reads | Enemy through the accessor; Wave and Stage directly | Data (values); this system (meaning, balance ranges) |
| Game State & Stage Flow | commanded, emits | `start_next_wave()`; `enemy_leaked(lives_cost: int)`, `wave_cleared(intermission_duration: float)`, `waves_complete()`. Flow owns lives, the countdown and the wave count it reports | This system (signals); Flow (phases, wiring) |
| Combat & Damage | calls | Creates Health and Status; reads `speed_factor` and `is_dead`. Counts down Status from the roster passed by the battle's tick | Combat (state); this system (roster, reap) |
| Tower System | emits, serves | `enemy_killed(bounty: int)` to gold; `targets()`; `slot_positions` | This system (signals, list); Tower (gold, targeting) |
| Hero System | serves | `targets()` for attack and burst | This system (list); Hero (targeting) |
| Battle HUD and views | serves | Views read `roster()` and the path each frame; the HUD may read Wave records directly | This system (data); views (drawing) |
| Bots and tests | call | Reach it through the builder and commands | Harness |

## Formulas

The **to_ticks** formula is defined as:

`to_ticks(seconds) = round(seconds / dt)`, rounding halves away from zero

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `seconds` | float, seconds | 0 and up | data file or calculated | An authored duration or a spawn time |
| `dt` | float, seconds | 1/60 proposed | constant | The fixed tick |

**Output Range:** 0 and up, in whole ticks. Any interval at or above the one-tick floor gives at least 1.
**Example:** 0.9 s gives 54. 5.0 s gives 300, where a repeated subtraction takes 301.

This is the one conversion for authored time (Flow Rule 4). `ceil` is not used: floating point pushes exact products just over a whole number, so 3 × 0.1 s at 1/60 gives 19 rather than 18, and 409 of 6,240 tested spawn times came out a tick late. With `round`, none of 7,000 tested times was off by more than half a tick, and no two members of a group shared one.

The **spawn_tick** formula is defined as:

`spawn_tick(i) = to_ticks(start_delay + i × spawn_interval)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `i` | int | 0 to `count` − 1 | calculated | Member index |
| `start_delay` | float, seconds | 0–600 | data file | Group offset from wave start |
| `spawn_interval` | float, seconds | `dt`–600 | data file | Gap between members. Below one tick, two members would share a tick, so the validator rejects it when `count` is 2 or more; at `count` 1 it is unused and unchecked. Code-built fixtures are exempt |

**Output Range:** 0 up to 18,000,000 at the domain's limits; the largest-gap check keeps real waves far below it. Error stays within half a tick and never accumulates. A member at tick 0 spawns on the wave's first slot.
**Example:** interval 0.125 s gives 0, 8, 15, 23.

The **d_next** formula is defined as:

`d_next = d + move_speed × speed_factor × dt`; the enemy leaks if `d_next ≥ path_length`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `d` | float, units | 0 to `path_length` | calculated | Distance travelled |
| `move_speed` | float, units/s | above 0, up to 2,000 | data file via the accessor | Read at use time; Data's validator rejects 0 or less |
| `speed_factor` | float | above 0, up to 1 | Combat | Slow; Combat keeps `slow_strength` below 1 |
| `path_length` | float, units | above 0 | calculated | Defined as `cum[last]`, the same running sum the position lookup uses, so the two can never differ by rounding; 1,704 on the starter stage, off-field ends included |

**Output Range:** a step of above 0 to 33.33 units. Overshoot is discarded. The `time_to_exit` floor keeps a path from being crossed in one step.
**Guard.** A catalogue stage cannot stall, because the validator and Combat keep both inputs above 0. A code-built fixture can. If `move_speed × speed_factor` is 0 or less, or not a finite number, the move step logs a development error and sets `d` to `path_length`, so the enemy leaks that tick through the normal leak path. The wave still clears, and position stays defined.
**Example:** speed 60 at factor 0.6: a step of 0.6 units per tick.

The **position** formula is defined as:

`position = P[k] + (d − cum[k]) / len[k] × (P[k+1] − P[k])`, where `cum[k] ≤ d < cum[k+1]`, and the last point once `d ≥ path_length`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `P[k]` | 2D point | field units | data file | Path points |
| `len[k]` | float, units | above 0 | calculated | Segment length; the catalogue validator rejects repeated consecutive points, so it is never 0 |
| `cum[k]` | float, units | 0 to `path_length` | calculated | Length before point `k` |

**Output Range:** always on the path, including steps that cross several segments, because position is looked up from `d` rather than walked.
**Example:** on the starter stage, `d` 720 lies on the third segment, 76 along, at (354, 400).

The **spacing** formulas are defined as:

`spacing = spawn_interval × move_speed × speed_factor`
`per_burst = floor(2 × burst_radius / spacing) + 1`
`per_splash = floor(splash_radius / spacing) + 1`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `spawn_interval`, `move_speed` | float | as above | data file | Spacing inputs |
| `speed_factor` | float | above 0, up to 1 | Combat | A slow that covers the whole group tightens it |
| `burst_radius` | float, units | 70 at starter values | Hero data | Burst reach; a disc spans two radii of path |
| `splash_radius` | float, units | 75 at starter values | Tower data | Largest in the catalogue (splash level 2). Splash reaches one radius behind its impact, because its impact is the leader |

**Output Range:** `spacing` above 0; `per_burst` and `per_splash` 1 and up, with no cap, since a strong slow packs a group tight. They are defined only for groups of `count` 2 or more: at `count` 1 the interval is unused and may be 0. These measure how tightly a group packs, not how long it is, so they do not grow with `count`. They assume a straight stretch of path, so a bend packs more into a burst than they predict.
**Design target:** every group the wave table below calls a packet has `per_burst` at least 4, which matches the Burst fit gate, and `per_splash` below `per_burst`, so the burst catches what splash cannot. Groups called strings or fronts are exempt: their job is to spread out. This is a design aid for authoring waves, with no code behind it, as is `catch_up`. Whether uncapped splash and stacked slows erode packets is unproven (Open Questions).
**Example:** normal at 0.6 s and speed 60: spacing 36, so a burst of radius 70 takes 4 and splash of radius 75 takes 3. **Normal at 1.5 s has spacing 90, so a burst takes 2: a string, not a packet.** A burst hits 3 or more whenever spacing is at most 70 and three are alive, so "3 or more" barely tests aim. The prototype's bursts hitting 3 or more every time likely reflect this, so the Burst fit gate asks for 4.

| Wave | Group | Role | `spacing` | `per_burst` | `per_splash` |
|---|---|---|---|---|---|
| 1 | normal×8 @1.5 | String | 90 | 2 | 1 |
| 2 | normal×6 @0.6, twice | Packet | 36 | 4 | 3 |
| 3 | normal×12 @0.7 | Packet | 42 | 4 | 2 |
| 3 | fast×8 @0.5 | Front | 55 | 3 | 2 |
| 4 | heavy×2 @3 | Soak | 114 | 2 | 1 |
| 4 | normal×8 @0.6 | Packet | 36 | 4 | 3 |
| 5 | fast×8 @0.4 +0 | Front | 44 | 4 | 2 |
| 5 | heavy×2 @4 | Soak | 152 | 1 | 1 |
| 5 | normal×10 @0.5 | Packet | 30 | 5 | 3 |
| 5 | fast×8 @0.4 +16 | Packet | 44 | 4 | 2 |
| 6 | heavy×4 @3 | Soak | 114 | 2 | 1 |
| 6 | normal×12 @0.5, normal×8 @0.5 | Packet | 30 | 5 | 3 |
| 6 | fast×10 @0.4 | Packet | 44 | 4 | 2 |

Every packet meets the target.

The **catch_up** formula is defined as:

`catch_up = v_slow × v_fast × delay / (v_fast − v_slow)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `v_slow`, `v_fast` | float, units/s | above 0, up to 2,000 | data file | Speeds, `v_fast` above `v_slow` |
| `delay` | float, seconds | 0–600 | data file | How much later the faster enemy spawns |

**Output Range:** the distance where they meet. It is evaluated only when `v_fast` is above `v_slow`: at equal or reversed speeds the gap never closes, so there is no meeting point and the formula is not used. They never meet on this path if the result exceeds `path_length`. Slows move this point, so re-derive it once towers exist.
**Example:** heavy 38, normal 60, delay 8: 829, inside the starter hairpin (644 to 1,294). Wave 4's second heavy spawns at 3 s, so against the first normal the delay is 5 and the catch is 518, on the first descent before the hairpin. Of the 16 catches between wave 4's 8 normals and 2 heavies, 13 fall in the hairpin, so its Intent says "mostly".

The **lives_at_risk** formula is defined as:

`lives_at_risk = Σ (count × lives_cost)` over a wave's groups

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `count` | int | 1–500 | data file | Group size |
| `lives_cost` | int | 0–1,000 | data file | Lives per leak |

**Output Range:** 0 and up; there is no ceiling, since lives clamp at 0.
**Example:** wave 4: 2 × 2 + 8 × 1 = 12.

The **peak_alive_ub** formula is defined as:

`peak_alive_ub` = the largest number of intervals `[spawn_tick, spawn_tick + ceil(path_length / (move_speed × (1 − max_slow) × dt)))` covering one tick

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `path_length` | float, units | above 0 | calculated | As above |
| `move_speed` | float, units/s | above 0, up to 2,000 | data file | Per enemy |
| `max_slow` | float | 0 to below 1 | data file | Highest `slow_strength` in the catalogue |

**Output Range:** 1 up to the wave's total count. It is pessimistic on purpose: no kills, always slowed. A wave whose total count is at most 48 passes outright, and waves cannot overlap at MVP, so the check is per wave.
**Example:** wave 6 has 34 enemies, so it passes outright.

The **gold_upper_bound** formula is defined as:

`gold_upper_bound(w) = starting_gold + Σ (bounty × count)` over waves 1 to `w`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `starting_gold` | int | 0–100,000 | data file | Stage value |
| `bounty`, `count` | int | 0–100,000; 1–500 | data file | Per group |

**Output Range:** 0 and up. It assumes every enemy is killed and excludes the early-call bonus, which belongs to the Tower GDD, as does any bound on this value.
**Example:** through wave 5: 456. Through wave 6: 630. A full board, all 5 slots built and at level 2, costs at least 550 at the Tower GDD's prices (all single). Gold before wave 6 is at most 496 at the starter 15 s intermissions, with every call's bonus (Tower). At `starting_gold` 120, over every legal intermission, the bound is 526: every bonus arrives before wave 6, and Tower's bonus share rule (at most 10% of `max_final_gold`) caps it at 70, 14 a call, which binds before the 30 s intermission cap would pay 80. So the headroom against 550 is 24 at starter values. It is not a floor: other legal `starting_gold` values move it, to 14 at 129 for example. What guarantees a player cannot have everything before the last wave is Tower's `gold_before_last_wave` row, which keeps the headroom above 0 on every legal stage, and that is a source of decisions. Wave 6's 174 arrives during the last wave, so it buys only mid-wave upgrades, and after the last kill it buys nothing.

## Edge Cases

- **If the last enemy leaks without ending the stage**: the leak fires in the advance slot, and the clear fires in that tick's reap.
- **If a leak is fatal**: the leak loop stops, and the reap, kills and clear are skipped, so `waves_complete` is never emitted and no bounty is paid.
- **If an outcome leaves enemies on the roster**: they freeze and stay in `roster()`. Any unprocessed leaker sits clamped at the path's end, unseen, costing nothing.
- **If an enemy reaches the end on a tick a tower could kill it**: it leaks, with no bounty (Combat Rule 11).
- **If a burst covers an off-field enemy**: it takes nothing, even if partly visible, because it is not in `targets()`.
- **If an enemy's centre lies exactly on the field edge**: it is targetable.
- **If a Fatal fires mid-spawn**: the loop stops, nothing further persists, and no leak, kill or clear follows.
- **If Start Wave is followed by focus loss before a tick**: the wave stays Active at `wave_tick` 0 with nothing spawned, and spawns on the first tick after resume.
- **If `start_next_wave` arrives during an active wave or past the last**: a development error, and it is ignored.
- **If a retry occurs**: a new battle, so index, `spawn_id` and schedule restart identically.
- **If the roster empties before a later group spawns**: no clear, because the schedule is not exhausted. The largest-gap rule bounds the wait.
- **If a wave has one enemy**: `spawn_interval` is unused, and the clear follows its death or leak.
- **If a code-built path is shorter than one step**: the enemy spawns, leaks and clears on one tick, never targetable. The `time_to_exit` floor rejects this in a real stage.
- **If a wave ID repeats**: each run starts from fresh state. Earlier runs of the last wave's ID emit `wave_cleared`, and only the final position emits `waves_complete`.
- **If `intermission_duration` is 0**: the next wave starts in the next tick's Flow slot. The content test rejects this in a real stage.
- **If a path dips off the field**: the content test fails it (L13). In a code-built fixture, its enemy simply loses and regains targetability.
- **If same-speed enemies spawn on one tick**: they stack exactly, ties go to the lowest `spawn_id`, and splash hits both.
- **If a later wave has a member at tick 0**: `spawn_id` continues battle-wide.
- **If `move_speed` is 2,000**: a step is 33.33 units, and position lookup crosses segments safely.
- **If a code-built enemy's speed times its factor is 0 or less, or not finite**: one development error, and the enemy leaks that tick at the path's end, paying its `lives_cost` as any leak does. The wave clears as usual. A catalogue stage cannot reach this (d_next, Guard).
- **If the screen is taller or wider than 9:16**: the area outside the field is masked, so the off-field path ends, including the exit at y 960 to 980, are never shown.
- **If `lives_cost` is 0**: the enemy still leaks, emits and leaves, and Flow changes nothing.
- **If handedness mirrors the burst button**: L3 and L7 already test both hands, so no slot changes.
- **If more enemies are alive than the view pool holds**: unreachable while `peak_alive_ub` passes. Otherwise the view creates one and logs a development error, since an invisible enemy is worse than a hitch. The simulation has no cap.

## Dependencies

**Upstream (hard):**

| System | Interface |
|---|---|
| Data & Config Pipeline | Enemy through the accessor; Wave and Stage directly; `path_points`, `slot_positions` and `path_width` added to Stage |
| Combat & Damage | Health, Status, `speed_factor`, `is_dead`, `deliver` for test kills; Rule 11's tick order |
| Game State & Stage Flow | `start_next_wave()`, `halted()`, wiring, tick slots, `to_ticks` in Rule 4 |
| Input & Gesture Resolver | Slot and burst hit radii (36, 48) behind Rule 3 and L1 to L3; positions outside the field for presses in masked bars |

**Downstream (hard):**

| System | GDD | Interface |
|---|---|---|
| Tower System | `design/gdd/tower-system.md` | `enemy_killed(bounty)`, `targets()`, `slot_positions`, `gold_upper_bound` |
| Hero System | `design/gdd/hero-system.md` | `targets()`; `time_to_exit` and intermission rules against burst cooldown; the field rectangle for `OFF_FIELD` |
| Battle HUD & Build UI | `design/gdd/battle-hud.md` | Burst button coordinates for L3 and L7; the top band's 174 for L6; Wave records for the next-wave line; got-through by type |

**Downstream (soft; no GDD yet):**

| System | Interface |
|---|---|
| Stage Progression & Stars (VS) | New stages against the layout and wave rules |
| Visual Feedback & VFX (VS) | Takes over the views below |

Per the bidirectional rule, each GDD must list this one. Data, Combat, Game State, Tower, Hero and Battle HUD already do, and Input names this system as owner of the slot clearance rule; the two soft ones must when authored.

## Visual/Audio Requirements

The MVP minimum, using primitives with no shaders or particles. All sizes and timings are proposed and unverified on a device. Hit flash, tracers, slow, damaged core and death belong to Combat. Audio: none at MVP.

| Event | Visual | Art bible |
|---|---|---|
| `normal` | 22 px plain disc; bobs ±1 px along its travel | §3, §5 |
| `fast` | 16 px, one V-notch facing its segment; jitters forward ±1.5 px | §5 LOD |
| `heavy` | 30 px plain disc with **no ring**; never bobs | §5 |
| Speed 110 | 3.67 px per frame at the 30 fps floor, under a quarter of its body, with no trail | §8 |
| Stacked enemies | Drawn heavy, normal, fast, then by `spawn_id`, with a 1 px dark keyline separating equal discs | §1 |
| Path | Drawn from `path_points`: a line of width 72 at +6% V, then 68 at +3%, leaving 2 px edges. Sharp joints keep 90° corners square, and ends stay off field. The draw-in is deferred | §6, §8 |
| Free slot | 56 px square, 1 px outline at alpha 0.3, four corner dots | §6 |
| Occupied slot | Hidden under its tower. No stage rule disables slots at MVP, so the blocked hairline never shows | §6 |
| Exit strip, dormant | Three downward chevrons at the last path point's x, ending at y 888; static at alpha 0.3 | §6, §7 |
| Exit strip, in danger | Alpha 0.75 to 1.0 at 2 Hz, plus a double outline | §2, §7 |
| Leak | The enemy is already unseen (L5). The chevrons scale to 1.25 and return in 200 ms; a repeat restarts this | §2 |
| Entry | No effect: it walks in along the path | §6 |

**The heavy wears no ring.** Art bible §2's ring promises armour that strips, and the heavy has none. At Vertical Slice a true `armoured` type gets 30 px plus the ring, and the heavy never gains it. Telling 22 px from 30 px by size alone must still pass §5's grey test.

**Danger is presentation only, computed by the view each frame.** `danger_until = now + 1.5 s` if any roster enemy has `path_length − distance ≤ 240`, or if lives just fell. Danger holds while `now < danger_until`, and ends at once on Won or Lost. On the starter stage that line is about y 740, just below the last slots, giving 2.2 s of warning from a fast enemy, 4 s from a normal and 6.3 s from a heavy. With sound off, motion carries it; for colour-blind players, chevron shape, alpha and outline carry it. Reduce Motion freezes it at alpha 1.0 and keeps the outline.

📌 **Asset Spec:** after the art bible is approved, run `/asset-spec system:enemy-wave`.

## Game Feel

Pacing should breathe: a string to read, then a packet that makes the player look up and choose. A packet closing on heavies in the hairpin should feel like a burst opportunity forming, seen seconds ahead and never a surprise. The 1.5 s danger hold should feel urgent yet fixable. All of this is unverified: no human has played these waves or this stage. Wave 1 is a string on purpose, and no wave has a planned lull inside it; both stay as authored until a playtest says otherwise (user, 2026-11-02). Pass criteria, checked at first playable from logs and a short survey (Deferred criteria, Game Feel):
- **Breathing:** in at least two of waves 2 to 6, there is a stretch of 6 s or more with at most 2 enemies in `targets()`.
- **Seen ahead:** asked "did you see where to burst before it was ready?", at least 4 of 5 testers say yes for wave 4's hairpin.
- **Urgent yet fixable:** at least half of danger states end without a leak, and every tester can say what the exit strip means.

## UI Requirements

None owned. Battle HUD draws lives, wave pips and the outcome screen from Flow, and any next-wave line from the Wave records (Open Questions). Slots and the path are field drawings, listed above.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Wave and Stage records, accessor, content test | `design/gdd/data-config-pipeline.md` | Core Rules; Rules 1, 9, 10 | Amended here |
| Instant hits, slow, tick order, targeting helpers, `spawn_id` | `design/gdd/combat-damage.md` | Rules 4, 7, 8, 10, 11; Handed to owning GDDs | Rule dependency; `to_ticks` amends its slow storage |
| Wave signals, lives, intermission, halt, pause | `design/gdd/game-state-stage-flow.md` | Rules 4, 7, 8, 13, 14, 15, 15a, 17, 18 | Rule dependency; `to_ticks` and payload amend it |
| Slot and burst hit radii | `design/gdd/input-gesture-resolver.md` | Open Question on slots | Answers it here |
| Starter HP, gold per wave, L10 range, no selling, the leak cost bound | `design/gdd/tower-system.md` | Core Rules 4; Simulated results; Formulas | Value dependency; amended this GDD's HP |
| Intermission against burst cycle, burst radius, re-pin walk, simulated results | `design/gdd/hero-system.md` | Rules 6, 7, 9, 17; Simulated results | Value dependency; the moved stage's re-run is above |
| Top band, burst button, field units, next-wave line | `design/gdd/battle-hud.md` | Layout; Formulas | Value dependency |
| Hero share, wave-design rule, stage length, slot count, first wave | `design/gdd/game-concept.md` | Pillar 2, MVP, Onboarding | Rule dependency |
| Enemy primitives, path, slots, chevrons, pools | `design/art/art-bible.md` | §2, §3, §5, §6, §7, §8 | Value dependency; amended |
| Prototype path, wave values | `prototypes/hero-pin-concept/main.gd` | `PATH`, `SLOTS`, `WAVES` | Evidence; not reused |

## Acceptance Criteria

A recording fake logs the four signals, and each THEN is the entire log. Factories build `stage()` with `dt` pinned at 0.25 s; a criterion that needs another `dt` states it. Path `P` is (−20, 950), (10, 950), (10, 980), length 60. Enemy `e` has speed 40 (a step of 10), bounty 4 and cost 1; enemy `h` is `e` with cost 2. Unless a criterion lists its own `wave_ids`, `stage()` has two wave positions and the criterion runs on the first, so its clear emits `wave_cleared`; every `intermission_duration` is 2.0 unless stated. `T` is advance then reap, counted from T0 of the wave under test, and kills use `deliver` between them. Development errors go to an injected sink the test reads. No scene, catalogue files or time assertions.

**CI: Logic**
1. (Rules 4, 14) **GIVEN** `e`, **WHEN** T0 to T4, **THEN** positions are (−10, 950), (0, 950), (10, 950), (10, 960), (10, 970) and `roster()` holds it on each. `targets()` is empty at T0, holds it at T1 (centre on the left edge), T2 (inside) and T3 (centre on the bottom edge), and is empty at T4.
2. (position) **GIVEN** path (0, 0), (5, 0), (5, 5), (25, 5), **THEN** `d` 10, 20, 30 give (5, 5), (15, 5), (25, 5).
3. (Rule 9, d_next) **GIVEN** `e`, **WHEN** T0, **THEN** `d` is 10, so it moved on its spawn tick; at factor 0.5 the next step is 5.
4. (Rules 5, 9, 10, 11) **GIVEN** a spy accessor doubling `move_speed` after T0, **THEN** T1 gives `d` 30. **GIVEN** a spy returning `bounty` 9 and `lives_cost` 3, and `e`×2 @0.25 with the first killed at T0, **THEN** the log is `enemy_killed(9), enemy_leaked(3), wave_cleared(2.0)`, the leak at T6. **GIVEN** a spy changing `max_hp` after T0, **THEN** that enemy's Health at T1 still holds its spawn value.
5. (Rule 10) **GIVEN** a group of `e`×1 then a group of `h`×1, both at +0, **WHEN** T5, **THEN** `enemy_leaked(1), enemy_leaked(2), wave_cleared(2.0)`, and during the first event the roster holds only `h`.
6. (Rule 13) **GIVEN** criterion 5's fixture and a listener latching halt on the first `enemy_leaked`, **THEN** the log is `enemy_leaked(1)` only, and `h` stays in `roster()`. **GIVEN** a one-entry `wave_ids` of one `e` and a listener latching halt on its `enemy_leaked`, **WHEN** T5, **THEN** the log is `enemy_leaked(1)` only, with no `waves_complete`, though the roster is empty and the schedule exhausted. **GIVEN** one `e` killed at T0 and a listener latching halt on its `enemy_killed`, **THEN** the log is `enemy_killed(4)` only, with no `wave_cleared`, though the corpse is already removed. **GIVEN** the spy latching on the sixth `move_speed` read (T5's move, from `d` 50), **THEN** an empty log, `d` 50, position (10, 970), and `e` still in `roster()`, since the halt check follows the read and the value is never used. **GIVEN** the spy latching on the `lives_cost` read at T5, **THEN** an empty log, `d` 60, position (10, 980), and `e` still in `roster()`, clamped and unseen. **GIVEN** one `e` killed at T0 and the spy latching on its `bounty` read in T0's reap, **THEN** an empty log, the corpse still in `roster()`, and no `wave_cleared`, since the halt check follows the read. **GIVEN** two groups of `e`×1, both at +0, both killed at T0, and a listener latching halt on the first `enemy_killed`, **THEN** the log is `enemy_killed(4)` only, the first corpse is gone from `roster()`, and the second is still in it with its `bounty` never read. **GIVEN** `e`×3 @0.5 and the spy latching during the second member's `max_hp` read at T2, **THEN** that member is not added and the third, due at T4, never spawns.
7. (Rule 11) **GIVEN** one `e` and no kills, **THEN** T0 to T4 log nothing and T5 logs `enemy_leaked(1), wave_cleared(2.0)`. **GIVEN** the same on a one-entry `wave_ids`, **THEN** T5 logs `enemy_leaked(1), waves_complete()`.
8. (Rule 11) **GIVEN** before a start, after a clear, and Finished, **WHEN** 100 advance-then-reap pairs run, **THEN** nothing is appended in each case.
9. (Rules 11, 15) **GIVEN** `e` ×2 @2.0 with the first killed at T0, **THEN** T0 logs `enemy_killed(4)`, T1 to T7 log nothing despite the empty roster, and the second member spawns at T8. **GIVEN** one `e` killed at T0 and a listener on its `enemy_killed` that adds an `e` through the add-enemy seam (Rule 15), **THEN** no clear at T0; the added enemy moves from T1 and leaks at T6, and the log is `enemy_killed(4), enemy_leaked(1), wave_cleared(2.0)`.
10. (Rules 11, 12) **GIVEN** a group of `e`×1 then a group of `e5`×1 (`e` with bounty 5), both at +0, with `e5` killed first and then `e` in T0, **WHEN** T0's reap, **THEN** the log is `enemy_killed(4), enemy_killed(5), wave_cleared(2.0)`, both are removed, and neither moved after T0's move. **GIVEN** a listener reading wave state on `wave_cleared`, **THEN** it sees Waiting. **GIVEN** the same on a one-entry `wave_ids`, **THEN** the log ends `waves_complete()` and the listener sees Finished.
11. (Rule 11) **GIVEN** `wave_ids` [a, b, a], each one `e`, with `intermission_duration` 2.0 on a and 3.0 on b, **WHEN** each wave is started and its enemy leaks, **THEN** the log is `enemy_leaked(1), wave_cleared(2.0), enemy_leaked(1), wave_cleared(3.0), enemy_leaked(1), waves_complete()`.
12. (Rule 7) **GIVEN** a start and no tick, **THEN** Active at `wave_tick` 0 with nothing spawned; **WHEN** T0, **THEN** tick-0 members exist. **WHEN** a start during Active, **THEN** unchanged, and the sink holds one development error. **WHEN** a start in Finished, **THEN** unchanged, and the sink holds one more.
13. (to_ticks, spawn_tick) Rounding is halves away from zero, as `to_ticks` states. **GIVEN** `dt` 1/60, in place of the factory's, **THEN** 0.9 s spawns at 0, 54, 108; 0.1 s has member 3 at 18; 0.125 s spawns at 0, 8, 15, 23; `to_ticks(5.0)` is 300. **GIVEN** the factory's `dt` 0.25, **THEN** `to_ticks(0.125)` is 1. No interval below the factory's tick is used as a `spawn_interval` here, since two members would share a tick; the validator rejects that in a real stage.
14. (Rule 8) **GIVEN** group b = `h`×2 @0.5 +0 authored before group a = `e`×1 +0.5, **THEN** T0 spawns b's first `h` (`spawn_id` 0), and T2 spawns b's second `h` (1) then a's `e` (2). A scan by member index across groups would put `e` before the second `h`, so it fails. **GIVEN** that wave run to its clear and then a second wave of `e`×1 +0, **THEN** its member takes `spawn_id` 3.
15. (Rule 6) **GIVEN** two seeds and one script through the builder, **THEN** identical logs and distances.
16. (lives_at_risk) 2×2 + 8×1 gives 12. (gold_upper_bound) **GIVEN** `starting_gold` 120, wave 1 of `e`×8 and wave 2 of `e`×2 with bounty 16, **THEN** `w` 1 gives 152 and `w` 2 gives 184.
17. (peak_alive_ub) **GIVEN** length 100, speed 40, `max_slow` 0.5 and three members, **THEN** interval 2.5 s gives 2, and 2.25 s gives 3.
18. (d_next, Guard) **GIVEN** a code-built `e` with speed 0, **WHEN** T0, **THEN** the sink holds one development error, the log is `enemy_leaked(1), wave_cleared(2.0)`, and the enemy reference kept from spawn reads position (10, 980) after it leaves the roster. The same holds for speed −40, NaN and INF, and for speed 40 with a `speed_factor` of 0 from a stub.

**CI: Integration**
19. (Rules 1 to 3, content test) **GIVEN** the real stage as records, **WHEN** the content test runs, **THEN** L1 to L9, L12 and L13 pass, and so do the wave rules for first spawn, largest gap, `time_to_exit`, the first position's `lives_at_risk`, every wave's `lives_at_risk`, the stage's total, the `lives_cost` cap, the 30 s intermission cap, `spawn_interval` at least `dt` in groups of 2 or more, and `starting_lives` at least 2 with at least 2 waves. L10, L11, the intermission floor and `peak_alive_ub` join when their data exists (Deferred criteria). Each rule has a stable ID used in its failure message: `L1` to `L13`, `first_spawn`, `max_gap`, `time_to_exit_min`, `time_to_exit_max`, `first_lives`, `wave_lives`, `stage_lives`, `lives_cost_cap`, `intermission_cap`, `interval_floor`, `min_lives_waves`, `intermission_min` and `peak_alive`.
20. (content test) **GIVEN** the copies below, each the real stage and its Enemy records with one field changed, **WHEN** the content test runs on each at `dt` 1/60, **THEN** the set of IDs it reports equals the copy's set exactly. Every rule 19 runs today has a copy, one per clause where a rule has several. The unbroken stage reports the empty set (19). So a validator that reports every ID, the wrong one, or misses a second rule a change also breaks, fails. Slots and path points are numbered from 0; "path …" lists the changed points, the rest as authored. Rows ending "passes" expect the empty set, so a validator stricter than the rule fails too. Each set was checked with `tools/balance-sim/stage_rules.py`, which implements these rules on the records and prints a match per copy.

| Copy | Changed field = value | Exact ID set |
|---|---|---|
| L1, x low | slot 3 = (130, 700) | {L1} |
| L1, x high | slot 4 = (410, 700) | {L1} |
| L1, y low | slot 0 = (270, 303) | {L1} |
| L2 | slot 1 = (180, 485) | {L2} |
| L3, left hand | slot 3 = (150, 760) | {L3} |
| L3, right hand | slot 4 = (390, 760) | {L3} |
| L4 | slot 2 = (250, 485) | {L4} |
| L5, first point | point 0 = (−10, 226) | {L5} |
| L5, last point | point 6 = (270, 970) | {L5} |
| L6 | points 0 and 1 = (−40, 200), (430, 200) | {L6} |
| L7 | path ends (270, 570), (270, 780), (400, 980) | {L7} |
| L8, close legs | path starts (−40, 226), (500, 226), (500, 300), (430, 300), then (430, 400) on | {L8} |
| L8, doubled back | path ends (270, 570), (270, 900), (250, 700), (250, 980); every interior point inside | {L8} |
| L8, baked curve passes | corner (430, 226) replaced by a quarter circle of radius 40 centred (390, 266), baked every 15°: (390, 226) to (430, 266) | {} |
| L9 | path = (−40, 620), (270, 620), (270, 980) | {L9, time_to_exit_min} |
| L12, too few | slots = slots 0 and 1 only | {L12} |
| L12, too many | slots + (350, 630) | {L12} |
| L13, interior point outside | path starts (−40, 226), (−20, 226), then (430, 226) on | {L13} |
| L13, entry by the top | path = (430, −40), then (430, 400) on | {L13, L6} |
| L13, entry by the right passes | point 0 = (580, 226) | {} |
| L13, exit by a side | path ends (110, 570), (580, 570) | {L13} |
| `first_spawn` | wave 1 group `start_delay` = 3 | {first_spawn} |
| `max_gap` | wave 2 second group `start_delay` = 17 | {max_gap} |
| `time_to_exit_min` | Enemy `fast.move_speed` = 150 | {time_to_exit_min} |
| `time_to_exit_max` | Enemy `heavy.move_speed` = 25 | {time_to_exit_max} |
| `first_lives` | `starting_lives` = 8 | {first_lives} |
| `wave_lives` | Enemy `normal.lives_cost` = 0 | {wave_lives} |
| `stage_lives` | `starting_lives` = 121 | {stage_lives} |
| `lives_cost_cap` | Enemy `heavy.lives_cost` = 5 | {lives_cost_cap} |
| `intermission_cap` | wave 1 `intermission_duration` = 31 | {intermission_cap} |
| `interval_floor` | wave 1 group `spawn_interval` = 0.01 | {interval_floor} |
| `min_lives_waves`, lives | `starting_lives` = 1 | {min_lives_waves, first_lives, lives_cost_cap} |
| `min_lives_waves`, waves | `wave_ids` = wave 1 only | {min_lives_waves, stage_lives} |

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner. Thresholds are proposed and set at the first baseline, the first time the Hero stories run the bots on the real game. "Mixed" means the four mixed builds and "mono-role" the three one-type builds (Single only, Splash only, Slow only) of Hero System, Simulated results; "mid-skill" is that section's bot. "Beat" and "below" compare lives left, then waves cleared. All the bots run on the fixed tick and the starter stage.

| Criterion | Owner | Passes when |
|---|---|---|
| Towers-only | Hero stories | The best of the seven builds in Hero System, Simulated results, played towers-only with no calls, ends with 3 lives or fewer, a loss included (MVP). Waves are never tuned to stay beatable without the hero |
| Driven margin | Hero stories | A driven hero ends at least 4 lives above that |
| Pillar 2 bots (Combat's row) | Hero stories | Thresholds live in Combat. A failure of hero-only, never-pinned or pinned-once reopens wave design here first |
| Mono-role | Tower stories | Every mono-role build ends below the best mixed build |
| Always-call | Tower stories | Towers-only always-call turns no loss into a win, gains at most 2 lives per build, and does not beat a driven hero. Waiting costs a towers-only bot nothing, so any bonus helps it, and "does not beat" would leave no bonus at all |
| Burst fit | Hero stories | In waves 2 to 6, at least 4 of `targets()` fit in one burst radius at some tick |
| Two fronts | Hero stories | In waves 3, 5 and 6, at some tick a `fast` and a non-`fast` in `targets()` are over 2 × `leash_radius` apart, straight-line. A string of one type does not count, since wave 1's alone spans over 180 |
| No input | This system's stories | With only Start pressed, the run reaches wave 2 with exactly `starting_lives` minus wave 1's `lives_at_risk` (2 at starter values), and the log holds one `enemy_leaked` per wave 1 member |
| Stage length (advisory) | Hero stories | The mid-skill driven hero (Hero System, Simulated results) wins on each of the four mixed builds, and each run lasts 5 to 8 minutes with no early calls and at least 3.5 minutes with every wave called. Length is ticks × `dt` from the first Start to the Won tick, rounded to 0.1 minute. A lost run fails the row. A miss reopens wave counts and intermissions here; it does not block a story. The simulation gives 5.0 to 5.3 and 3.7 to 3.8, so one build sits on the floor with no margin |
| Empty field | Hero stories | For the mid-skill bot, the longest run of consecutive Active ticks with empty `targets()`, from a wave's first spawn to its clear, is at most 5 s. Wave 2 counts; if it fails, wave 2's second packet moves earlier |
| Game Feel (playtest) | User, first playable | The three checks under Game Feel pass |
| L10, L11, intermission, peak rows | Tower, Hero stories | These checks join the content test and pass, and each adds its broken copies to criterion 20's table, with exact ID sets. L10 also changes existing rows: the L9, L1 x high and both L3 copies leave a slot covering under 200, so their sets gain L10 unless the copies move |
| Retry (Flow) | This system's stories | A retried battle's snapshot equals a fresh one, the old battle's `weakref` is null, and only the catalogue is shared |
| Listener test (Flow) | This system's, Tower stories | Each of this system's four signals has a non-zero connection count, and removing one connection fails with a message naming that signal |
| Order (Combat) | This system's stories | Leaks resolve before fire; a fatal leak pays nothing; `enemy_killed` fires once; no corpse moves |
| Catalogue unchanged (Data) | Tower, this system's stories | Unchanged after a battle where an enemy spawned and died |
| Never cache (Data) | Tower, Hero, HUD stories | The second use reflects the spy |

**Manual** (screenshots retained in `production/qa/evidence/`), each pass or fail: **path**, every path point lies on the drawn centreline within 2 units; **entry and exit**, no enemy pixel shows at the field edge as one enters or leaves; **types**, a tester names all three types from greyscale crops at minimum size; **exit strip**, dormant and in-danger states are both captured, with lead sign-off. **Masking:** a screenshot at 9:19.5 and one at 4:3 while an enemy is entering and one is leaving. Each passes if no pixel of the path or of an enemy outside the 540 × 960 field is visible, the exit at y 960 to 980 included, and fails otherwise.

**Checked by code review, not tests:** one distance per enemy (Rule 1), nothing stored on records (Rule 7), and lists unmodified and not kept (Rule 14).

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| On one path, does re-pinning matter, or does one good pin suffice? On the moved stage the script puts it at 1 to 4 lives, a median of 2 (Hero Rule 7), and the user accepted that for MVP. The two-front gate shows the geometry exists, not that humans use it. **Trigger** (user, 2026-11-02): parallel lanes come forward, ahead of more content, if human testers who re-pin end less than 2 lives above those who pin once, or the best-single-pin bot ends within 1 life of mid-skill on 3 of the 4 mixed builds (today 2 of 4) | qa-lead + Hero GDD | First playable |
| Do the layout rules leave room for different stages? Sketch Vertical Slice stages 2 and 3 through L1 to L13 on paper before authoring them. Two limits to weigh: `time_to_exit` holds a stage that uses fasts and heavies to a total path of 1,320 to 2,280, so L9's 800 binds only on a stage without fasts; and L3, L7 and L13 put every exit run in x 184 to 356 near the bottom | level-designer | Before Vertical Slice stages |
| The concept names bursts hitting 3 or more as a mastery metric, yet it barely tests aim here. Log human burst hit counts and revisit that threshold | Hero GDD | First playable |
| Lives never come back, so an early leak's cost lasts the whole stage, and the lost bounty adds to it. The gold side is bounded: a surviving player leaks at most 9 lives, worth at most 68 gold (worst case 4 heavies and 1 normal), about one tower; typical early leaks are normals at 4 gold each (Tower System). That bound, not instant retry, is why the loss is accepted. The real cost is the tower that gold would have bought in harder waves, a loop that reinforces itself. Open: does a player who leaks in wave 2 still feel the stage can be won, or do they retry at once? Log the wave of first leak and whether the player retried before the outcome | qa-lead | First playable |
| Do uncapped splash and slow erode the packets the burst needs? The spacing target assumes a splash radius of at most 75 and no stacked slows; a slow tightens a whole group only if it covers every member | Tower GDD + bots | First playable |
| Concept's "Stage 1 has one tower type" against an MVP stage with three | Stage Progression GDD | Vertical Slice |
| Stages are now point lists in data, with no visual path editing. Fine for one stage; a converter or editor tool is needed before 20. Point lists also fit Vertical Slice's 3 | tools-programmer + producer | Before Vertical Slice content |
| Stretch mode: this GDD requires everything outside the 540 × 960 field to be masked on any screen shape, so off-field entry and exit stay unseen. How, by letterbox or panel, and whether the insets above hold on real phones, belongs to the decision record. If it cannot mask, L3, L5, L6 and L7 must be rechecked against the visible area | technical-director | Input ADR |
| Seams the criteria assume: constructor inputs, the two tick entries, add-enemy, a development-error sink, the content test over in-memory records, the field rectangle, and the snapshot | technical-director | App Lifecycle ADR |
| Does the technical director accept moving path and slots from the scene to the Stage record, and the tick order? | technical-director | App Lifecycle ADR |
| New types debut at full stakes: `fast` first appears in wave 3 as 8 members, 8 of 10 lives at risk, and `heavy` in wave 4 as 2. Does a first-time player read the 8-fast debut as unfair? Ask at first playable; if most testers say yes, add a wave rule capping a type's first appearance at `ceil(starting_lives / 3)` lives | Playtest + this GDD | First playable |
| A `slow_strength` near 1 lets `peak_alive_ub` overflow an integer and can freeze `d_next`, since a step under half the precision of `d` adds nothing, which the Guard does not catch. Data should cap `slow_strength`, for example at 0.9 | Data GDD + Combat GDD | Before the Tower stories |
| Starter waves are one scripted simulation, on a path 18% longer than the prototype's with one fewer slot, with no human data. Every convergence point moves with real towers | Bots at first playable | First playable |
