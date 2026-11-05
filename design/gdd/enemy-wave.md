# Enemy & Wave

> **Status**: Approved 2026-11-04 (lean design review 2026-11-03 APPROVED; the `wave_index()` definition added after the cross-GDD review passed the consistency re-check, and the user approved it. Six recommended items remain in the review log)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (towers-only gate no longer requires a win, entry from either side, Pillar 2 bots pointed at wave design, human burst hit counts).
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-05
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 3 (Every Stage Reads Differently); Pillar 2 (waves are tuned assuming the hero)

## Summary

The enemies and the stage they walk: one authored path, build slots, three enemy types and six fixed waves whose shape makes bursts, re-pins and tower choices worth deciding. Players feel it as pressure with a readable shape, where only reaching the exit hurts, and it reports every kill and leak so lives and gold stay honest. It owns the path, roster, spawning, movement and clearing, and no damage, lives, gold or timers beyond its own schedule.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Data & Config Pipeline, Combat & Damage, Game State & Stage Flow`

## Overview

Enemy & Wave is what the player defends against. It holds the stage's one path and build slots, sends authored waves down that path, moves each enemy, and reports every enemy that dies or leaks. Enemies never attack: they walk, and the only threat is reaching the exit. Players meet it as pressure with a shape. Fast enemies pull ahead and open a second front, heavy ones soak tower fire while they lead, then trail the followers that pass them, and packets catch up at points worth a burst. It exists so that wave shape, not hidden stat growth, is what gives the player's towers and hero something to decide. Waves are tuned with the hero in, so the hero stays needed (Pillar 2). It owns the path, the roster, spawning, movement, leaks and wave clearing. It does not own damage, lives, gold, the intermission clock, or who attacks whom.

## Detailed Design

### Core Rules

**The stage.**

1. **One path.** A stage has one continuous path, and an enemy's progress is one distance along it. MVP and Vertical Slice need nothing more, because Vertical Slice's "different paths" are shape changes. Forks, parallel lanes and flyer gaps wait until after Vertical Slice, and would need `path_id` on wave groups and an amended art bible §6. On one path, "the leaking lane" means the stretch the player's towers do not cover, so it depends on the build. Whether that makes players re-pin is unproven (Open Questions).
2. **Stage geometry is data.** `path_points[]`, `slot_positions[]` and `path_width` are new fields on the Stage record. This amends Data & Config, which placed them in the stage scene. Path length sets time to leak and slots set tower coverage, so they are gameplay values (Data Rule 1), and the builder and tests run without a scene (Flow Rule 2). The scene keeps the look only: field hue, base value and grid tilt. A view draws the path from the same points, so the two cannot disagree. Curves, if ever wanted, are baked to points once at load.
3. **Slots belong to the stage.** This GDD owns the layout rules below, the Stage record holds the positions, and the content test (Data Rule 9) enforces them. Tower reads `slot_positions` directly, and a slot's index is its identity, which is the order towers fire in. Hit radii come from the Input GDD: slot 36, burst 48.

**Layout rules, checked by the content test.** All numbers are proposed. Insets assumed are 0 to 48 dp at the bottom and 0 to 68 dp at the top, unverified on devices. These must be rechecked once the stretch mode is decided (Input Open Questions).

| # | Rule | Starter stage |
|---|---|---|
| L1 | Slot x within 138 to 402, y at least 304: its hit disc and build arc stay in the field and below the band, with no flip code (Battle HUD) | Pass |
| L2 | Slot to path centreline at least `path_width / 2 + 40`: a 56 px slot at any tilt stays off the path | 76 needed, 80 |
| L3 | Slot to the burst button's centre line, either hand (x 456 or 84, y 816 to 888, confirmed by Battle HUD), at least 92, the slot's hit radius 36 plus the hero's grab 56, the same clearance as Hero's `hero_start` | 144 |
| L4 | Slot to slot at least 72 | 160 |
| L5 | First and last path points at least 16 outside the field, since the largest enemy's radius is 15: it enters and exits unseen | 40, 20 |
| L6 | In-field path clear of the top band at the largest inset, `I_top` 102 units or 68 dp, where the band ends: `y − path_width / 2` at least 174. Battle HUD's prompt panel clears this edge only up to `I_top` 68 units, or 45 dp; above that it overlaps the lane, by 34 at most, and the Mobile Platform GDD owns it (Open Questions) | 174, no margin |
| L7 | Path centreline to the burst button's centre line at least `path_width / 2 + 64`, a proposed margin with no derivation: the button's hit radius 48 plus 16 | 100 needed, 186 |
| L8 | Non-adjacent path segments at least `path_width + 60` apart | 132 needed, 160 |
| L9 | In-field length at least 800 | 1,660 |
| L10 | Each slot covers at least 200 of path in total, not necessarily contiguous, at the lowest level-1 tower range | 223 at range 150 |
| L11 | On a stage with `requires_bend`, some disc of burst radius, searched on a grid of 10, holds at least 2.5 × that radius of path, so a bend exists to burst. A new Stage flag, since a straight stage cannot pass | 196 against 175, at radius 70 |
| L12 | 3 to 5 slots, as in the concept | 5 |
| L13 | Interior points inside the field; the path enters by the left or right edge and leaves by the bottom, crossing the boundary exactly twice; no segment doubles back on the one before | Pass |
| L14 | Every in-field path point within `leash_radius` of a legal pin, either hand, so no stretch is out of the hero's reach | 74 at worst, against 90 |

L10, L11 and L14 need tower range, burst radius and hero data, so they join the test in the Tower and Hero stories. Arc discs against Start/Call and the burst line are Battle HUD's content rows, since `R` is its value. L8 does not promise room for a slot between two lanes: that takes 152, from L2 on both sides, and L2 decides it per slot.

Slot 1 sits 1 unit inside L1, and L6 has no margin. Moving slot 1 to y 310 was simulated, and it took the hero share median to 24.4%, below its band, so it stays at 305.

**Entry and exit.**

4. **Enemies enter and leave unseen.** The path starts off a side edge below the top band, so it never runs under the band, and ends off the bottom. The starter stage enters from the left. An enemy is **targetable only while its centre is inside the field**, edges included (0 to 540, 0 to 960), so nothing is hit before it can be seen. Body radius is not data, so an enemy partly visible at the edge may briefly be untargetable, which is accepted. Art bible §7's "never routed under a panel" is why the prototype's top entry is not reused.

**Enemies.**

5. **Three types at MVP, each with a job.** HP is fixed per type, because a hidden HP scale on an identical circle cannot be read: waves escalate through count, mix and overlap. Enemies have no attacks, armour or abilities. True armour, flying and splitters are Vertical Slice. Lane-switchers need parallel lanes, so they wait with them. The `heavy` soaks fire with no armour rule at all, because towers shoot first along the path, but only while it leads. Followers at 60 pass it at 38, then they draw the fire and it trails.

| Type | Job for the player |
|---|---|
| `normal` | Forms the packets that burst and splash want |
| `fast` | Runs ahead and opens a second front; asks for slow or a re-pin |
| `heavy` | Soaks "first along the path" fire while it leads, and trails once passed; asks for single-target damage |

**Waves.**

6. **Authored, with no randomness.** Waves are fixed so a stage can be learned. This settles Flow's retry question: a retry reuses the seed, which nothing here reads. Cosmetic jitter never uses the simulation seed.
7. **Wave control.** Flow calls `start_next_wave()` with no argument. This system owns the index into `wave_ids` and resets its per-wave state on each start, storing nothing on the record, so repeated wave IDs work. A start during an active wave or past the last wave logs a development error and is ignored. The call commits at once: the wave is Active at `wave_tick` 0. Members due at tick 0 spawn in the next advance slot, and `wave_tick` rises at the end of that slot. Either way, members spawn in the first advance slot after the commit: a countdown's end commits in Flow's slot, so that same tick, and an early call or Start Wave commits between ticks, so the next one.
8. **Spawning uses an absolute schedule.** Each member's whole tick is computed from wave start (Formulas), never by repeating a float countdown. Members spawn when `wave_tick` reaches their tick, with groups scanned in authored order and members in ascending order. Each takes the next battle-wide `spawn_id`, which also breaks ties, and gets its Health (seeded once from `max_hp`) and Status. `spawn_interval` has no effect when `count` is 1.
9. **Movement.** Each enemy reads `move_speed` through the stat accessor at use time, with a read context made once per enemy (the context is reused, not the value), and multiplies by Combat's `speed_factor`. An enemy moves on the tick it spawns, as in the prototype. Its cached position, stored as `x`, `y` (64-bit `float`), is computed once in the move step from `distance` and kept for that tick's targeting and views, clamped to the path's end.
10. **Leaks.** An enemy whose distance reaches the path length leaks. In ascending `spawn_id` order, its `lives_cost` is read through the accessor, it leaves the roster at once, and `enemy_leaked(lives_cost)` fires synchronously. A fatal leak ends the loop (Rule 13).
11. **Kills and clearing.** In the reap slot, dead enemies are handled in ascending `spawn_id` order: `bounty` is read through the accessor, `enemy_killed(bounty)` fires, and the corpse is removed. Then comes the clear check. **It runs every tick, not only on a kill**, or a wave whose last enemy leaks would never clear, and only while a wave is active, or an empty field would emit forever. A wave is clear when its schedule is exhausted and the roster is empty, with no separate counter that could disagree. By index, not ID, the last wave emits `waves_completed()` and any other emits `wave_cleared(intermission_duration)`, with the state committed first. Leak events therefore always precede the clear, as Flow Rule 13 requires.
12. **Tick order confirmed.** Combat Rule 11 stands: Flow, then this system's advance slot (spawn, move, leak), Status countdown, towers by slot index, hero then burst, then this system's reap slot. So this system has two tick entries, `advance()` and `reap()`, and the battle's tick passes the roster to Combat's countdown, since Flow owns no roster. `advance()` takes no argument: this system owns `wave_tick` (Rule 7), so a second counter could not disagree (ADR-0009). A corpse is reaped on the tick it dies, so it never moves.
13. **Halting.** The builder injects Flow's `halted()`, true on Won, Lost and Fatal (Flow Rules 15 and 18), so this system needs no reference to Flow. It is checked immediately after every accessor read, before the value is used, and after every signal. Spawn, move, leak and reap return at once when it is true, so nothing follows a fatal leak, and a bad read can never persist a garbage value or emit one. Enemies left on the roster at an outcome freeze where they are.
14. **Reading the enemies.** `roster()` is every enemy not yet removed, corpses awaiting the reap included, in `spawn_id` order. `targets()` is that list limited to those inside the field. Tower and Hero pass `targets()` to Combat's helpers, which skip the dead, and the burst uses it too. Both lists are `Array[Targetable]`, read-only by rule and never kept past the reader's slot. An enemy is a `Targetable` (ADR-0009) and exposes `spawn_id`, `def_id`, `distance`, a cached position stored as `x`, `y`, and `removed`, which this system sets when it leaves the roster by leak or reap (Combat Rule 3). Views also read `wave_index()` and `got_through_by_type()`, kept for the result and never reset per wave. `wave_index()` is the 1-based position in `wave_ids` of the last wave started: 0 before the first start, set when `start_next_wave` commits (Rule 7), and unchanged by a clear or an outcome, so it reads N through wave N and the Intermission after it. `wave_state()` (Waiting, Active or Finished) and `wave_tick()` are reads too, for tests and any view. The add-enemy step calls Combat's `attach(enemy, max_hp)` to add Health and Status; on `false` it calls fatal and returns (ADR-0009).
15. **Room for splitters, nothing built.** One add-enemy step serves the schedule, and the clear test looks only at the schedule and the roster. So splitter children at Vertical Slice can join atomically before the clear check, with new `spawn_id`s, with no fields or code added now.

**Starter values.** These are fixtures, not balance. The Tower and Hero GDDs ran them through a scripted simulation with towers and a hero, and raised HP about 3 times, because at the first values a hero alone and towers alone both won, and set every intermission to 15 s, so that waiting restores the burst (Hero System, Simulated results). They replace the prototype's, whose top entry and 6 slots do not carry over.

| Stage field | Value |
|---|---|
| `path_points` | (−40, 210), (430, 210), (430, 400), (110, 400), (110, 570), (270, 570), (270, 980) |
| `slot_positions` | (270, 305), (190, 485), (350, 485), (170, 700), (370, 700) |
| `path_width`, `starting_lives`, `starting_gold` | 72, 10, 120 |

| Enemy | `max_hp` | `move_speed` | `bounty` | `lives_cost` | `visual_key` |
|---|---|---|---|---|---|
| `normal` | 125 | 60 | 4 | 1 | `enemy_normal` |
| `fast` | 60 | 110 | 3 | 1 | `enemy_fast` |
| `heavy` | 750 | 38 | 16 | 3 | `enemy_heavy` |

**A heavy costs 3 lives (user, 2026-11-02).** At 2, skipping the heavies in waves 4 and 5 cost 8 lives and spared 3,000 HP of tower fire, so they were cheap to leak. A bounty of 24 was also simulated, and single alone then caught the best mixes, so the bounty stays 16 and the gold tables are unchanged.

A group below is type × count @ `spawn_interval` + `start_delay`, in seconds from wave start.

| Wave | Groups | Total HP | `intermission_duration` | Intent |
|---|---|---|---|---|
| 1 | normal×8 @1.5 +0 | 1,000 | 15 | Learn the path; cannot end the stage |
| 2 | normal×6 @0.6 +0; normal×6 @0.6 +12 | 1,500 | 15 | Two packets, one burst cooldown apart |
| 3 | normal×12 @0.7 +0; fast×8 @0.5 +0 | 1,980 | 15 | First two fronts |
| 4 | heavy×2 @3 +0; normal×8 @0.6 +8 | 2,500 | 15 | A packet catches the heavies from before the hairpin through it (518 to 1,264) |
| 5 | fast×8 @0.4 +0; heavy×2 @4 +0; normal×10 @0.5 +4; fast×8 @0.4 +16 | 3,710 | 15 | An early leak, then a convergence |
| 6 | heavy×4 @3 +0; normal×12 @0.5 +10; fast×10 @0.4 +20; normal×8 @0.5 +24 | 6,100 | 15 (unused on the last wave) | Fronts stagger from the entry to past the last slot |

Each wave's total HP is 1.26 to 1.64 times the last. With nothing called early, a stage where enemies die about 60% along the path runs about 5.2 minutes in simulation, inside the concept's 5 to 8, or about 3.8 with every wave called.

**Wave rules, checked by the content test.** All bounds are proposed. Waves are checked per position in `wave_ids`, because IDs repeat. A real stage also needs `starting_lives` of at least 2 and at least 2 waves, or the lives rules below cannot all hold; code-built fixtures are exempt. The `intermission_duration` and `peak_alive_ub` rows need Burst and Tower data, so they join in the Hero and Tower stories.

| Check | Bound | Starter | Reason |
|---|---|---|---|
| First spawn of a wave | At most 2 s | 0 s | The field is not empty after Start |
| Largest gap between scheduled spawns | At most 12 s | 9 s | A wave cannot be called early. This is Flow's cap on `start_delay`, measured where it matters |
| `time_to_exit`, path length ÷ `move_speed` | 12 to 60 s | 15.6 to 45.3 s | Time for a burst; no stalled waves |
| `intermission_duration` of every position but the last | At least `cooldown + telegraph_duration` | 15 s against 10.25 s | Waiting always restores the burst |
| First position's `lives_at_risk` | Below `starting_lives` | 8 against 10 | The first wave cannot end the stage, with no runtime rule: an idle player still leaks and feels it, keeping 2 lives |
| Every wave's `lives_at_risk` | At least 1 | 8 to 42 | No decorative waves |
| Stage's total `lives_at_risk` | At least `starting_lives` | 128 against 10 | Stronger than Flow's "some cost above 0", since one 1-cost enemy against 10 lives cannot lose |
| Any `lives_cost` | At most `ceil(starting_lives / 3)` | 3 against 4 | One miss does not end the stage |
| `peak_alive_ub` | At most 48 | 34 | Art bible §8's enemy pool |
| Spawn ticks within a group | Strictly increasing | Pass | Float noise can break `to_ticks`'s no-sharing claim at an interval of exactly `dt` |

Bot gates sit in Acceptance Criteria, since they cannot run until towers and the hero exist.

**Tuned assuming the hero (Pillar 2).** Waves are tuned against the driven bot first, then the towers-only shortfall is measured. Towers-only may win at MVP only with 3 lives or fewer (Deferred criteria), and must lose from Vertical Slice. Today every towers-only bot loses (Hero System).

**Handed to owning GDDs.**
- **Tower:** reads `slot_positions`; supplies DPS per type and level, and keeps its own gold bound using `gold_upper_bound`. It must ensure `starting_gold` buys its cheapest tower, or the stage soft-locks.
- **Hero:** walks re-pins at 240 in a straight line, so two fronts cost about 2 s. Keeps `fast` speed × `telegraph_duration` at most half the burst radius (0.31 s at starter values), or fast enemies escape the burst. Reads "bursts hitting 3 or more" knowing it barely tests aim here (Formulas).
- **Battle HUD:** done. It confirms the burst line, shows the next wave's enemies by glyph and count, and reports got-through by type.

**Deliberately not built for MVP.** Forks and lanes, armour, flying, splitters, lane-switchers, per-wave HP scaling, bounty multipliers, randomness, enemy attacks, a spawn signal (views read the roster), and leaks per lane.

→ Becomes an ADR: how Health and Status attach to an enemy, and the storage form of `path_points` and `slot_positions`. **Decided by ADR-0009 (Accepted 2026-11-04):** `attach`, and the geometry stays on the Stage record.

**Notes for stories, all unverified on 4.7.** Square path corners: settled by ADR-0011 Decision 2. The path is a polygon baked once from `path_points`, not `draw_polyline`; probe R4 gives exact square corners, and M3 screenshots check them. Reused typed buffers for the two lists, with a snapshot when erasing. An injected failure sink rather than `assert`, which release builds strip. No `CONNECT_DEFERRED` on `enemy_leaked` or `enemy_killed`, since Rules 10 and 13 need them synchronous. The roster as sole owner of its enemies, so a retried battle frees. A cached `cum[]`. Three draw passes rather than an unstable sort. `Vector2` is 32-bit, so keep `distance` a float and take care with edge tests.

### States and Transitions

| Wave control | Meaning | Transitions |
|---|---|---|
| Waiting | Before a start, or between waves; the clear check does nothing | `start_next_wave` → Active |
| Active | Schedule running or enemies remain | Clear on a non-last wave → Waiting. Clear on the last wave → Finished |
| Finished | `waves_completed` emitted | None |

| Enemy | Meaning | Transitions |
|---|---|---|
| Off field | On the roster, moving, not targetable | Centre enters the field → In field. Distance reaches the end → Leaked |
| In field | On the roster and targetable | HP 0 → Dead. Centre leaves the field → Off field. On a code-built path ending inside the field, distance reaches the end → Leaked |
| Dead | Not targetable; still in `roster()` until the reap | Reap → removed, with bounty |
| Leaked | Removed at once; never a target again | None |

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Data & Config | reads | Enemy through the accessor; Wave and Stage directly | Data (values); this system (meaning, balance ranges) |
| Game State & Stage Flow | commanded, emits | `start_next_wave()`; `enemy_leaked(lives_cost: int)`, `wave_cleared(intermission_duration: float)`, `waves_completed()`. Flow owns lives and the countdown, and reads `wave_index()` for the result | This system (signals); Flow (phases, wiring) |
| Combat & Damage | calls | Creates Health and Status; reads `speed_factor` and `is_dead`. Counts down Status through `tick_status`, from the roster passed by the battle's tick | Combat (state); this system (roster, reap) |
| Tower System | emits, serves | `enemy_killed(bounty: int)` to gold; `targets()`; `slot_positions` | This system (signals, list); Tower (gold, targeting) |
| Hero System | serves | `targets()` for attack and burst | This system (list); Hero (targeting) |
| Battle HUD and views | serves | Views read `roster()` and the path each frame; the HUD reads `wave_index()` for the pips in every phase and for the result, `got_through_by_type()` for the result, and may read Wave records directly | This system (data); views (drawing) |
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

This is the one conversion for authored time (Flow Rule 4). `ceil` is not used: floating point pushes exact products just over a whole number, so 3 × 0.1 s at 1/60 gives 19 rather than 18, and 409 of 6,240 tested spawn times came out a tick late. With `round`, none of 7,000 tested times was off by more than half a tick, and no two members of a group shared one, which holds for any interval above `dt`. At exactly `dt` with a half-tick offset, float noise can put two on one tick, so the content test requires strictly increasing ticks.

The **spawn_tick** formula is defined as:

`spawn_tick(i) = to_ticks(start_delay + i × spawn_interval)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `i` | int | 0 to `count` − 1 | calculated | Member index |
| `start_delay` | float, seconds | 0–600 | data file | Group offset from wave start |
| `spawn_interval` | float, seconds | 1/60–600 | data file | Gap between members |

**Output Range:** 0 up to 18,000,000 at the domain's limits; the largest-gap check keeps real waves far below it. Error stays within half a tick and never accumulates. A member at tick 0 spawns on the wave's first slot.
**Example:** interval 0.125 s gives 0, 8, 15, 23.

The **d_next** formula is defined as:

`d_next = d + move_speed × speed_factor × dt`; the enemy leaks if `d_next ≥ path_length`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `d` | float, units | 0 to `path_length` | calculated | Distance travelled |
| `move_speed` | float, units/s | above 0, up to 2,000 | data file via the accessor | Read at use time |
| `speed_factor` | float | `1 − max_slow` up to 1 | Combat | Slow. Slows do not stack (Combat Rule 7), so this is its floor, and `peak_alive_ub` relies on it. A `max_slow` near 1 would stall a wave, so Combat keeps it well below |
| `path_length` | float, units | above 0 | calculated | Sum of segment lengths |

**Output Range:** a step of above 0 to 33.33 units. Overshoot is discarded. The `time_to_exit` floor keeps a path from being crossed in one step, and caps a real stage near 143 units/s on the starter path, so 2,000 is code-built only.
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
**Example:** on the starter stage, `d` 720 lies on the third segment, 60 along, at (370, 400).

The **packet_length** formula is defined as:

`packet_length = (count − 1) × spawn_interval × move_speed × speed_factor`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `count` | int | 1–500 | data file | Living group members |
| `spawn_interval`, `move_speed` | float | as above | data file | Spacing inputs |
| `speed_factor` | float | above 0, up to 1 | Combat | Slow tightens a fully slowed group |

**Output Range:** 0 for one enemy. The design target is `splash_radius < packet_length`, so a packet outlasts one splash, and Burst fit (criterion 60) tests what a burst catches. Splash reaches one radius rather than two, because its impact is the leader. Whether uncapped splash lets it hold is unproven.
This is a design aid for authoring waves, with no code behind it, as is `catch_up`. **Example:** 6 at 0.6 s and speed 60: 180, wider than a burst of radius 70, so on a straight a burst takes about 4 of 6. **A wave of 8 at 1.5 s and speed 60 has gaps of 90 and is a string, not a packet.** A burst hits 3 or more whenever the spacing is at most 70 and three are alive, with room to spare, so "3 or more" barely tests aim. The prototype's bursts hitting 3 or more every time likely reflect this, so the gates here use 4, the most a burst holds on a straight at wave 2's spacing: five at spacing 36 span 144, over a 140 disc. A bend holds 6 (criterion 60).

The **catch_up** formula is defined as:

`catch_up = v_slow × v_fast × delay / (v_fast − v_slow)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `v_slow`, `v_fast` | float, units/s | above 0, up to 2,000 | data file | Speeds, `v_fast` above `v_slow`; it applies only when the faster enemy spawns later |
| `delay` | float, seconds | 0–600 | data file | How much later the faster enemy spawns |

**Output Range:** the distance where they meet. They never meet on this path if it exceeds `path_length`, and at equal speeds they never meet at all. Slows move this point, so re-derive it once towers exist.
**Example:** heavy 38, normal 60, delay 8: 829, inside the starter hairpin (660 to 1,310). Wave 4's second heavy spawns at 3 s, so its delay is 5: 518, before the hairpin.

The **lives_at_risk** formula is defined as:

`lives_at_risk = Σ (count × lives_cost)` over a wave's groups

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `count` | int | 1–500 | data file | Group size |
| `lives_cost` | int | 0–1,000 | data file | Lives per leak |

**Output Range:** 0 and up; there is no ceiling, since lives clamp at 0.
**Example:** wave 4: 2 × 3 + 8 × 1 = 14. By wave: 8, 12, 20, 14, 32, 42, or 128 in all.

The **peak_alive_ub** formula is defined as:

`peak_alive_ub` = the largest number of intervals `[spawn_tick, spawn_tick + ceil(path_length / (move_speed × (1 − max_slow) × dt) − 1e-9))` covering one tick

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `path_length` | float, units | above 0 | calculated | As above |
| `move_speed` | float, units/s | above 0, up to 2,000 | data file | Per enemy |
| `max_slow` | float | 0 to below 1 | data file | Highest `slow_strength` in the catalogue |

**Output Range:** 1 up to the wave's total count. It is pessimistic on purpose: no kills, always slowed. The tolerance is there because `ceil` would otherwise run a tick high on exact products (`to_ticks`). A wave whose total count is at most 48 passes outright, and waves cannot overlap at MVP, so the check is per wave.
**Example:** wave 6 has 34 enemies, so it passes outright.

The **gold_upper_bound** formula is defined as:

`gold_upper_bound(w) = starting_gold + Σ (bounty × count)` over waves 1 to `w`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `starting_gold` | int | 0–100,000 | data file | Stage value |
| `bounty`, `count` | int | 0–100,000; 1–500 | data file | Per group |

**Output Range:** 0 and up. It assumes every enemy is killed and excludes the early-call bonus, which belongs to the Tower GDD, as does any bound on this value.
**Example:** through wave 5: 456. Through wave 6: 630. A full board costs at least 550 at the Tower GDD's prices, so a player cannot have everything before the last wave, which is a source of decisions.

## Edge Cases

- **If the last enemy leaks without ending the stage**: the leak fires in the advance slot, and the clear fires in that tick's reap.
- **If a leak is fatal**: the leak loop stops, and the reap, kills and clear are skipped, so `waves_completed` is never emitted and no bounty is paid.
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
- **If a wave ID repeats**: each run starts from fresh state. Earlier runs of the last wave's ID emit `wave_cleared`, and only the final position emits `waves_completed`.
- **If `intermission_duration` is 0**: the next wave starts in the next tick's Flow slot. The content test rejects this in a real stage.
- **If a path dips off the field**: the content test fails it (L13). In a code-built fixture, its enemy simply loses and regains targetability.
- **If same-speed enemies spawn on one tick**: they stack exactly, ties go to the lowest `spawn_id`, and splash hits both.
- **If a later wave has a member at tick 0**: `spawn_id` continues battle-wide.
- **If `move_speed` is 2,000**: a step is 33.33 units, and position lookup crosses segments safely.
- **If `lives_cost` is 0**: the enemy still leaks, emits and leaves, and Flow changes nothing.
- **If handedness mirrors the burst button**: L3 and L7 already test both hands, so no slot changes.
- **If more enemies are alive than the view pool holds**: unreachable while `peak_alive_ub` passes. Otherwise the view creates one and logs a development error, since an invisible enemy is worse than a hitch. The simulation has no cap.

## Dependencies

**Upstream (hard):**

| System | Interface |
|---|---|
| Data & Config Pipeline | Enemy through the accessor; Wave and Stage directly; `path_points`, `slot_positions` and `path_width` added to Stage |
| Combat & Damage | Health, Status, `speed_factor`, `is_dead`, `deliver` for test kills; Rule 11's tick order |
| Game State & Stage Flow | `start_next_wave()`, `halted()`, wiring, tick slots, `to_ticks` in Rule 4, `wave_index()` read for the result |

**Downstream (hard, with their own GDDs):**

| System | Interface |
|---|---|
| Tower System | `enemy_killed(bounty)`, `targets()`, `slot_positions`, `gold_upper_bound` |
| Hero System | `targets()`; `time_to_exit` and intermission rules against burst cooldown |
| Battle HUD & Build UI | Burst button coordinates for L3 and L7; Wave records for any next-wave line; `wave_index()` and `got_through_by_type()` for the pips and the result |

**Downstream (soft; no GDD yet, so each interface is provisional until that GDD confirms it):**

| System | Interface |
|---|---|
| Stage Progression & Stars (VS) | New stages against the layout and wave rules (soft) |
| Visual Feedback & VFX (VS) | Takes over the views below (soft) |

Per the bidirectional rule, each of these GDDs must list this one when authored. Data, Combat, Game State, Tower, Hero and Battle HUD already do.

## Visual/Audio Requirements

The MVP minimum, using primitives with no shaders or particles. All sizes and timings are proposed and unverified on a device. Hit flash, tracers, slow, damaged core and death belong to Combat. Audio: none at MVP.

| Event | Visual | Art bible |
|---|---|---|
| `normal` | 22 px plain disc; bobs ±1 px along its travel | §3, §5 |
| `fast` | 16 px, one V-notch facing its segment; jitters forward ±1.5 px | §5 LOD |
| `heavy` | 30 px plain disc with **no ring**; never bobs | §5 |
| Speed 110 | 3.67 px per frame at the 30 fps floor, under a quarter of its body, with no trail | §8 |
| Stacked enemies | Drawn heavy, normal, fast, then by `spawn_id`, with a 1 px dark keyline separating equal discs | §1 |
| Path | Baked once from `path_points` into two polygons (ADR-0011): 72 wide at +6% V, then 68 at +3%, leaving 2 px edges. Sharp joints keep 90° corners square, and ends stay off field. The draw-in is deferred | §6, §8 |
| Free slot | 56 px square, 1 px outline at alpha 0.3, four corner dots | §6 |
| Occupied slot | Hidden under its tower. No stage rule disables slots at MVP, so the blocked hairline never shows | §6 |
| Exit strip, dormant | Three downward chevrons at the last path point's x, ending at y 888; static at alpha 0.3 | §6, §7 |
| Exit strip, in danger | Alpha 0.75 to 1.0 at 2 Hz, plus a double outline | §2, §7 |
| Leak | The enemy is already unseen (L5). The chevrons scale to 1.25 and return in 200 ms; a repeat restarts this, at most once per second, so pulse plus pop stay at or below 3 per second | §2 |
| Entry | No effect: it walks in along the path | §6 |

**The heavy wears no ring.** Art bible §2's ring promises armour that strips, and the heavy has none. At Vertical Slice a true `armoured` type gets 30 px plus the ring, and the heavy never gains it. Telling 22 px from 30 px by size alone must still pass §5's grey test.

**Danger is presentation only, computed by the view each frame.** `danger_until = now + 1.5 s` if any roster enemy has `path_length − distance ≤ 240`, or if lives just fell. Danger holds while `now < danger_until`, and ends at once on Won or Lost. On the starter stage that line is about y 740, just below the last slots, giving 2.2 s of warning from a fast enemy, 4 s from a normal and 6.3 s from a heavy. With sound off, motion carries it; for colour-blind players, chevron shape, alpha and outline carry it. Reduce Motion freezes it at alpha 1.0 and keeps the outline. The 2 Hz pulse is under WCAG 2.3.1's limit of three flashes per second.

**Reduce Motion, elsewhere.** Bob, jitter and lean stay on, since they are telegraphs (AR-V-10; user decision 2026-11-05, ADR-0011 Decision 8). The leak pop becomes a still double outline for 200 ms. Shape cues, the `fast` notch and Combat's drag lines stay.

📌 **Asset Spec:** after the art bible is approved, run `/asset-spec system:enemy-wave`.

## Game Feel

Pacing should breathe: a string to read, then a packet that makes the player look up and choose. A packet closing on heavies in the hairpin should feel like a burst opportunity forming, seen seconds ahead once it has entered and never a surprise. A group's arrival has no telegraph of its own, since the next-wave line hides during Wave. The target to observe: the first burst-worthy packet is in view at least 3 s before it reaches the hairpin, which starter wave 2 gives at about 10 s. The 1.5 s danger hold should feel urgent yet fixable. All of this is unverified: no human has played these waves or this stage.

## UI Requirements

None owned. Battle HUD draws lives, wave pips and the outcome screen from Flow, and any next-wave line from the Wave records (Open Questions). Slots and the path are field drawings, listed above.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Wave and Stage records, accessor, content test | `design/gdd/data-config-pipeline.md` | Core Rules; Rules 1, 9, 10 | Amended here |
| Instant hits, slow, tick order, targeting helpers, `spawn_id` | `design/gdd/combat-damage.md` | Rules 4, 7, 8, 10, 11; Handed to owning GDDs | Rule dependency; `to_ticks` amends its slow storage |
| Wave signals, lives, intermission, halt, pause | `design/gdd/game-state-stage-flow.md` | Rules 4, 7, 8, 13, 14, 15, 15a, 17, 18 | Rule dependency; `to_ticks` and payload amend it |
| Slot and burst hit radii | `design/gdd/input-gesture-resolver.md` | Open Question on slots | Answers it here |
| Hero share, wave-design rule, stage length, slot count, first wave | `design/gdd/game-concept.md` | Pillar 2, MVP, Onboarding | Rule dependency |
| Enemy primitives, path, slots, chevrons, pools | `design/art/art-bible.md` | §2, §3, §5, §6, §7, §8 | Value dependency; amended |
| Prototype path, wave values | `prototypes/hero-pin-concept/main.gd` | `PATH`, `SLOTS`, `WAVES` | Evidence; not reused |

## Acceptance Criteria

A recording fake logs the four signals, and a THEN that names an event or the log is the entire log; a THEN about state alone says nothing of the log. Combat's Health, Status and `deliver`, Flow's `halted()` and the development-error sink are fakes, so these run before those systems exist. Factories build `stage()`: `dt` 0.25, path `P` of (−20, 950), (10, 950), (10, 980), length 60; enemy `e` with speed 40 (a step of 10), bounty 4, cost 1; intermission 2.0; `wave_ids` [w, w] with `e` in w unless a criterion says otherwise, so the first clear emits `wave_cleared`. `T` is advance then reap, counted from T0, and kills use `deliver` between them. No scene, catalogue files or time assertions, except where a criterion names real records.

**CI: Logic**
1. (Rule 4) **GIVEN** `e`, **WHEN** T0, T2, T4, **THEN** positions are (−10, 950), (10, 950), (10, 970).
2. (Rule 14) **GIVEN** `e`, **WHEN** T0, T2, T4, **THEN** `roster()` holds it each time, and `targets()` is empty, holds it, then is empty.
3. (Rule 4) **GIVEN** `e`, **THEN** (0, 950) at T1 and (10, 960) at T3 are in `targets()`.
4. (Rule 4) **GIVEN** a right-side path (560, 950), (530, 950), (530, 980), **THEN** (550, 950) at T0 is not in `targets()`, and (540, 950) at T1 is.
5. (position) **GIVEN** path (0, 0), (5, 0), (5, 5), (25, 5), **THEN** `d` 10, 20, 30 give (5, 5), (15, 5), (25, 5).
6. (position) **GIVEN** that path and speed 60, **WHEN** T0, **THEN** a step across two corners lands at (10, 5).
7. (Rule 9) **GIVEN** `e`, **WHEN** T0, **THEN** `d` is 10, so it moved on its spawn tick.
8. (d_next) **GIVEN** factor 0.5, **WHEN** T, **THEN** the step is 5.
9. (d_next) **GIVEN** `d_next` called directly at factor 0.5, **THEN** `d` 55 gives 60 and leaks, and `d` 54.5 gives 59.5 and does not.
10. (Rule 9) **GIVEN** a spy doubling `move_speed` after T0, **THEN** T1 gives `d` 30.
11. (Rule 10) **GIVEN** a spy changing `lives_cost` to 2, **WHEN** T5, **THEN** `enemy_leaked(2), wave_cleared(2.0)`.
12. (Rule 11) **GIVEN** a spy changing `bounty` to 7 and a kill, **WHEN** reap, **THEN** `enemy_killed(7), wave_cleared(2.0)`.
13. (Rule 5) **GIVEN** a spy changing `max_hp` after spawn, **THEN** current HP is unchanged.
14. (Rule 10) **GIVEN** two stacked enemies with costs 1 and 2, **WHEN** T5, **THEN** `enemy_leaked(1), enemy_leaked(2), wave_cleared(2.0)`.
15. (Rule 10) **GIVEN** that stack, **THEN** during the first event the roster holds only the second.
16. (Rule 13) **GIVEN** that stack and a listener latching halt on the first event, **THEN** `enemy_leaked(1)` only, and the second stays.
17. (Rule 13) **GIVEN** an enemy at `d` 50 and a spy latching during its `move_speed` read, **WHEN** the move, **THEN** an empty log, `d` 50 and position (10, 970).
18. (Rule 13) **GIVEN** a corpse and the latch, **WHEN** reap, **THEN** an empty log.
19. (Rule 13) **GIVEN** a spy latching during the second member's `max_hp` read, **THEN** that enemy is not added and no later member spawns.
20. (Rule 13) **GIVEN** a spy latching during a `lives_cost` read, **THEN** an empty log.
21. (Rule 13) **GIVEN** a spy latching during a `bounty` read, **THEN** an empty log.
22. (Edge cases) **GIVEN** an outcome with enemies on the roster, **WHEN** 10 T, **THEN** they stay where they are, and the log is empty.
23. (Rule 11) **GIVEN** one `e` and no kills, **THEN** T0 to T4 log nothing, and T5 logs `enemy_leaked(1), wave_cleared(2.0)`.
24. (Rule 11) **GIVEN** before a start, **WHEN** 100 T, **THEN** an empty log, and `wave_index()` is 0.
25. (Rule 11) **GIVEN** after a clear, **WHEN** 100 T, **THEN** nothing is appended.
26. (Rule 11) **GIVEN** Finished, **WHEN** 100 T, **THEN** nothing is appended.
27. (Rule 11) **GIVEN** `e` at +0 and +2.0 with the first killed at T0, **THEN** `enemy_killed(4)`, nothing more through T12 despite the empty roster at T1 to T7, and T13 logs `enemy_leaked(1), wave_cleared(2.0)`.
28. (Rule 15) **GIVEN** a kill listener calling add-enemy, **WHEN** that kill is reaped, **THEN** `enemy_killed(4)` and no clear, and the clear follows that enemy's leak.
29. (Rules 11, 12) **GIVEN** two enemies killed highest `spawn_id` first, **WHEN** reap, **THEN** bounties in ascending `spawn_id` order, then `wave_cleared(2.0)`, both removed, neither moved.
30. (Rule 11) **WHEN** a non-last wave clears, **THEN** its listener already reads `wave_state()` as Waiting, and `wave_index()` is unchanged.
31. (Rule 11) **WHEN** the last wave clears, **THEN** its listener already reads `wave_state()` as Finished.
32. (Rule 11) **GIVEN** `wave_ids` [a, b, a], a's intermission 2.0 and b's 3.0, **WHEN** all clear, **THEN** `wave_cleared(2.0), wave_cleared(3.0), waves_completed()`.
33. (Rules 7, 14) **GIVEN** a start and no tick, **THEN** `wave_state()` is Active, `wave_tick()` is 0, `wave_index()` is 1, and `roster()` is empty.
34. (Rule 7) **WHEN** T0, **THEN** tick-0 members exist, and `wave_tick()` is 1.
35. (Rule 7) **WHEN** a start during Active, **THEN** unchanged, with one development error.
36. (Rule 7) **WHEN** a start during Finished, **THEN** unchanged, with one development error.
37. (to_ticks) **GIVEN** `dt` 1/60, **THEN** 0.9 s is 54, 5.0 s is 300, 1/60 s is 1, and 0 is 0.
38. (spawn_tick) **GIVEN** `dt` 1/60, **THEN** 0.9 s spawns at 0, 54, 108; 0.1 s has member 3 at 18; 0.125 s spawns at 0, 8, 15, 23.
39. (to_ticks) **GIVEN** `dt` 0.25, **THEN** 0.125 s is 1.
40. (Rule 8) **GIVEN** group b ×1 +0.5 authored before group a ×2 @0.5, **THEN** T0 spawns a's first, and T2 spawns b's then a's second, with `spawn_id`s ascending in that order.
41. (Rule 8) **GIVEN** a second wave, **THEN** its first `spawn_id` continues from the first wave's last.
42. (Rule 6) **GIVEN** two seeds and one script through the builder, **THEN** identical logs and distances, and a spy shows the seed never read.
43. (lives_at_risk) 2×3 + 8×1 gives 14.
44. (gold_upper_bound) 120 + 8×4 gives 152.
45. (peak_alive_ub) **GIVEN** `dt` 0.25, length 100, speed 40, `max_slow` 0.5 and three members, **THEN** interval 2.5 s gives 2.
46. (peak_alive_ub) **GIVEN** the same, **THEN** interval 2.25 s gives 3.
47. (packet_length) A design aid with no code, so no test; Formulas' worked example stands.
48. (catch_up) A design aid with no code, so no test; Formulas' worked example stands.
49. (Rule 14) **WHEN** an enemy leaks and a later wave starts, **THEN** `got_through_by_type()` keeps its count and `wave_index()` has risen.
50. (Edge cases) **GIVEN** a wave of one enemy, **THEN** `spawn_interval` is unused, and the clear follows its leak.
51. (Edge cases) **GIVEN** a path shorter than one step, **WHEN** T0, **THEN** `enemy_leaked(1), wave_cleared(2.0)`, never in `targets()`.
52. (Edge cases) **GIVEN** `lives_cost` 0, **WHEN** it leaks, **THEN** `enemy_leaked(0), wave_cleared(2.0)`, and it leaves the roster.
53. (Edge cases) **GIVEN** two same-speed enemies spawned on one tick, **THEN** `roster()` orders them by `spawn_id`.
54. (Rule 14) **GIVEN** a corpse before the reap, **THEN** it is in `roster()`.
55. (Combat Rule 11) **GIVEN** an enemy leaking on a tick a kill would land, **THEN** `enemy_leaked(1), wave_cleared(2.0)`, with no `enemy_killed`.
56. (Edge cases) **GIVEN** a new battle after a finished one, **THEN** index, `spawn_id` and schedule restart identically.
57. (Danger) **GIVEN** the view's pure rule with `now` passed as an argument, **THEN** an enemy at 240 from the end sets danger, one at 241 does not, a fall in lives sets it with no enemy near, it is true 1.49 s after the last trigger and false at 1.5 s, and Won or Lost ends it at once.

**CI: Integration.** 58 to 61 need the content test and real records. 62 to 64 need the builder, so they run in its story, not before it exists.
58. (Layout and wave rules) **GIVEN** the real stage as in-memory records, **THEN** one case per row of L1 to L9, L12, L13 and the wave rules passes.
59. (Layout and wave rules) **GIVEN** a copy with one field broken per row, **THEN** each fails naming its row, with boundary pairs where a bound is exact: L6 at 174 passes and 173.99 fails, and `lives_cost` 4 passes and 5 fails.
60. (Burst fit) **GIVEN** the real waves, no kills and no slow, **THEN** in each of waves 2 to 6, at least 4 of `targets()` fit in a disc of radius 70 at some tick, searching disc centres on L11's grid of 10. Today 6, 7, 8, 12 and 14.
61. (Two fronts) **GIVEN** the same, **THEN** in waves 3, 5 and 6, two of `targets()` are over 180, or 2 × `leash_radius`, apart at some tick. Today 761, 784 and 758.
62. (Rule 7) **GIVEN** the builder, **THEN** a countdown's end spawns in that same tick, and a call spawns on the next.
63. (Rule 12) **GIVEN** the builder, **THEN** Combat's `tick_status` receives this system's roster.
64. (Rule 3) **GIVEN** the builder, **THEN** slot `i` is at `slot_positions[i]`.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner. Thresholds are proposed and set at the first baseline. "Beat" and "below" compare lives left, then waves cleared. All the bots run on the fixed tick and the starter stage, and a mixed build means one of the four in the Hero GDD's table.

| Criterion | Owner | Passes when |
|---|---|---|
| Towers-only | Hero stories | Each mixed build's towers-only bot ends with 3 lives or fewer, a loss included (MVP), and at 0 from Vertical Slice. Waves are never tuned to stay beatable without the hero |
| Driven margin | Hero stories | A driven hero ends at least 4 lives above that |
| Pillar 2 bots (Combat's row) | Hero stories | Thresholds live in Hero's deferred table. A failure of hero-only, never-pinned or pinned-once reopens wave design here first |
| Mono-role | Tower stories | Every build of one role ends below the best mixed build |
| Always-call, flips | Tower stories | Towers-only always-call turns no loss into a win |
| Tick order (Combat's Order row) | Enemy & Wave stories | In a scripted tick, `tick_status` runs after the leak step and before any tower fires |
| Always-call, lives | Tower stories | It gains at most 2 lives per build. Waiting costs a towers-only bot nothing, so any bonus helps it, and "does not beat" alone would leave no bonus at all |
| Always-call, against the hero | Tower stories | It does not beat a driven hero |
| No input | This system's stories | With only Start pressed, the run ends wave 1 with at least 2 lives |
| Empty field | Hero stories | A driven hero's longest empty `targets()` during a wave is at most 5 s. Wave 2's 9 s gap may fail this unless the first packet lives long enough, and a fail reopens wave 2 |
| L10, L11, L14, intermission, peak rows | Tower, Hero stories | These checks join the content test and pass |
| Retry (Flow) | This system's stories | A retried battle's snapshot equals a fresh one, the old battle's `weakref` is null, and only the catalogue is shared |
| Listener test (Flow) | This system's, Tower stories | The count is non-zero, and removing a connection fails naming it |
| Order, leaks (Combat) | This system's stories | On the real tick, leaks resolve before fire |
| Order, fatal leak (Combat) | This system's stories | A fatal leak pays nothing |
| Order, kills (Combat) | This system's stories | `enemy_killed` fires once, and no corpse moves |
| Catalogue unchanged (Data) | Tower, this system's stories | Unchanged after a battle where an enemy spawned and died |
| Never cache (Data) | Tower, Hero, HUD stories | A spy's change shows on the next use; this system's are criteria 10, 11 and 12 |

**Manual** (screenshots retained in `production/qa/evidence/`, with art-director sign-off):
- Path points overlaid on the drawn path, with no visible deviation, and square corners.
- Frames at the first and last in-field tick, showing entry and exit unseen.

**Render test, on a phone, before the first playable.** Each row has a fallback if it fails:

| Check | Pass | Fallback |
|---|---|---|
| Free slot on the field | Contrast at least 3:1, and 5 of 5 viewers find every free slot | 2 px outline at alpha 0.5, with 4 px corner dots at alpha 0.6 |
| 22 against 30 px in grey | 5 of 5 viewers tell them apart, 34 enemies on screen, at the minimum width | `heavy` at 34 px |
| Stacked enemies | The keyline separates equal discs | 2 px keyline, outside the radius |
| `fast` notch in grey, with jitter | 5 of 5 viewers name it | Notch at least 25% of the diameter |
| Exit strip | Dormant and danger states shown; 5 of 5 viewers notice danger during a long wave tail | Dormant alpha 0.45, and a stronger state for a `heavy` |

**Checked by code review, not tests:** one distance per enemy (Rule 1), nothing stored on records (Rule 7), and lists unmodified and not kept (Rule 14).

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| On one path, does re-pinning matter, or does one good pin suffice? The two-front gate shows the geometry exists, not that humans use it. If the pinned-once bot or a tester says it does not, parallel lanes are the first thing to pull forward, ahead of more content | qa-lead + Hero GDD | First playable |
| Do the layout rules leave room for different stages? Sketch Vertical Slice stages 2 and 3 through L1 to L13 on paper before authoring them. They pass only if they differ in the bottom third, and a mirror does not count; if the rules forbid that, amend the rows, which are data | level-designer | Before Vertical Slice stages |
| The concept names bursts hitting 3 or more as a mastery metric, yet it barely tests aim here. Log human burst hit counts and revisit that threshold | Hero GDD | First playable |
| A leak loses both a life and its bounty, so failure compounds. Accepted because retry is instant; unproven | qa-lead | First playable |
| Do uncapped splash and slow erode the packets the burst needs? The packet target assumes splash radius below 90 at starter values | Tower GDD + bots | First playable |
| Concept's "Stage 1 has one tower type" against an MVP stage with three | Stage Progression GDD | Vertical Slice |
| Stages are now point lists in data, with no visual path editing. Fine for one stage; a converter or editor tool is needed before 20. Point lists also fit Vertical Slice's 3 | tools-programmer + producer | Before Vertical Slice content |
| Stretch mode and the minimum supported width in dp: if a 9:16 field is centred on a taller phone, or a wider one reveals off-field entry, L3, L5, L6 and L7 must be rechecked. L6's zero margin at the largest inset is unverified on devices | technical-director | Input ADR |
| Seams the criteria assume: constructor inputs, the two tick entries, add-enemy, a development-error sink, the content test over in-memory records, the field rectangle, a callable `d_next`, and the snapshot. Also decide: one tick driver with a constant `dt`, and what a stall does; compacting the roster after a loop, on the halt path too; the enemy's base type and no back-references, for the `weakref` check; and where the Reduce Motion setting lives (answered: `reduce_motion` is a field on the Input record, Data GDD and ADR-0002, passed to views through `PresentationSettings`, ADR-0001). Answered by ADR-0009: the base type (`Targetable`), the two tick entries, add-enemy and the field rectangle | technical-director | App Lifecycle ADR |
| Does the technical director accept moving path and slots from the scene to the Stage record, and the tick order? **Tick order: accepted 2026-11-04 (ADR-0004 Decision 5). Path and slots move: accepted 2026-11-04 (ADR-0009 Decision 4).** | technical-director | App Lifecycle ADR |
| Wave 6 pays 174 of 510 bounty gold. At most 496 is held at its start, 54 short of the cheapest full board and 254 of the dearest, so some of it still buys upgrades mid-wave, and what arrives late buys nothing. How much is that? HP per gold in stock runs 8.3, 9.4, 9.2, 8.4, 10.1, 12.3, so it rises only at the end. Is the last wave's reward worth anything? | economy-designer + bots | First playable |
| There is no heavy-only introduction and no relief wave, and waiting is about 24% of an uncalled stage. Does the curve need either, or less waiting? | Playtest | First playable |
| Nothing restores a lost life, so early leaks shrink the cushion for wave 6. Is that fair? | Playtest | First playable |
| Wave 2's packets are 12 s apart against a 10.25 s burst recovery, so 1.75 s of slack. Does a real thumb make it? | Pillar 4 phone test | First phone build |
| Prompt panel at insets above 45 dp overlaps the entry lane, by 34 at 68 dp. Fix it in the HUD, or move the entry to y 244, which needs a re-simulation with the share median at its floor | Mobile Platform GDD | Before the first phone build |
| Tower reach: 29.8% of the in-field path is out of every level-1 tower's range, and 20.8% at level 2; past 1,571 only the hero can hit, and slot 5's coverage is a strict subset of slot 4's. Rule 1 intends a leaking lane, but is this much right, and does slot 5 earn its place? Slots are simulation-sensitive, so test any move | Bots at first baseline | First playable |
| Human checks the bots cannot make: the 3 s sight target on waves 4 to 6, how often a heavy leaks, and whether a strong run falls under the concept's 5 minutes | qa-lead | First playable |
| No entry for this system's cues in `design/accessibility-requirements.md`, which does not exist yet | Settings & Accessibility | When that file is authored |
| Starter waves are one scripted simulation, on a path 19% longer than the prototype's with one fewer slot, with no human data. Every convergence point moves with real towers | Bots at first playable | First playable |
