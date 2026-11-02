# Tower System (incl. Gold Economy)

> **Status**: In Review (first design review 2026-11-02 NEEDS REVISION; eight blockers and one user decision applied, re-review pending)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (burst outcome gate, share gate on a mid-skill bot, always-call with a hero, dominant-build gate, price of no refund).
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-02
> **Last Verified**: 2026-11-02
> **Implements Pillar**: Pillar 1 (Growth You Can See: upgrades add geometry); Pillar 2 (One Hero, Not an Army: towers keep sustained DPS)

## Summary

The player's standing army and the money that buys it: three tower roles on a stage's slots, one upgrade each, and gold from kills and early calls. Players feel it as a choice that never quite closes, because gold cannot fill the board before the last wave and a build cannot be undone. It owns tower attacks, gold and the build and upgrade commands, and no damage, targeting helpers, enemy list or arc drawing.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Enemy & Wave, Combat & Damage, Input & Gesture Resolver, Data & Config Pipeline, Game State & Stage Flow`

## Overview

Towers are what holds the path while the hero decides fights. The player taps an empty slot and picks one of three roles from an arc, then later taps a tower and taps again to upgrade it. From then on towers fire by themselves at the first enemy along the path in range. Gold comes from starting gold, kills and calling a wave early, and it is always too little to fill the board before the last wave, so each purchase says what the player thinks is coming. There is no selling, so a tower is a commitment and growth stays on the field: each upgrade adds visible geometry. The system exists so the hero has something to complement: towers carry the steady damage, and no tower build may clear the stage comfortably without the hero (Pillar 2). It owns attack timing, gold, slots' build state and the two commands that spend gold. Combat applies the damage, and the HUD draws the arc and the chip.

## Detailed Design

### Core Rules

**Two pieces.** A battle must run with no scene (Flow Rule 2), yet the upgrade window needs real time, because the clock is stopped in Build. So the system splits:

| Piece | Built by | Holds |
|---|---|---|
| TowerSim | Battle builder, also headless | Gold, slot states, tower instances, attack timers, the two commands, the tick entry |
| TowerInput | Wrapper, absent headless | Input registration for slots and towers, the upgrade chip window |

TowerInput's only way to change anything is the `upgrade` command the bots also use, so it cannot affect a result by another route. It is its own object, not the wrapper, so Flow Rule 3's ban on gameplay branches in the wrapper still holds.

**Roles.**

1. **Three roles, one job each.** All three are available from the start at MVP; the concept's one-tower first stage waits for Vertical Slice. The first play of "which tower" is the point, and unlock logic is cut until then.

| Role tag | Polygon | Best at | Worst at |
|---|---|---|---|
| `single_target` | Triangle | Heavies, and finishing whatever leads | Packets: one victim per shot |
| `splash` | Hexagon | Packets, more so when slowed | Strings and heavies: one victim, slow cadence |
| `slow` | Square | Fast enemies, and making neighbours' fire last longer | Kills nothing, so earns nothing alone |

This confirms the art bible's open proposal, and it changes square's meaning from rapid fire to slow. A rapid-fire tower at Small Ship needs another shape.

2. **Two levels at MVP.** The concept's level 1 and 2 stand; the art bible's level 3 is later vocabulary. Each level holds absolute values. `cost` at level N is the price of reaching N, as Data & Config proposed. A content rule requires exactly two levels, so the rule is one edit away when level 3 arrives.
3. **Slow deals no damage.** A slow tower with `damage` 0 never earns a kill by itself, and cannot win alone. Combat Rule 10 sets its target: the first unslowed enemy, else the first enemy.
4. **No selling or refund at MVP.** A second gesture on a tower would compete with the upgrade tap, and live refunds would let players move towers to follow packets. A wrong disc costs gold at once, and a wrong plan can surface only at wave 6, minutes later, so instant retry undersells the price. That is accepted as the weight of a choice. Revisit if the phone test shows arc mis-fires, or a playtest shows lost stages that players blame on one early build. This means no tower is ever removed, so the Input edge case on re-enabling a slot does not arise.

**Building and upgrading.**

5. **Two commands, shared by players and bots.** `build(slot_index, tower_id)` and `upgrade(slot_index)` run between ticks and return one result:

| Result | Meaning | Checked |
|---|---|---|
| `HALTED` | `halted()` is true | 1st, and again after the cost read |
| `BAD_SLOT` | `slot_index` outside 0 to the slot count minus 1, since a negative index would wrap | 2nd |
| `BAD_TOWER` | Data's `is_tower(id)` is false, `build` only | 3rd |
| `SLOT_OCCUPIED` / `NO_TOWER` | `build` on a built slot / `upgrade` on an empty one | 4th |
| `MAX_LEVEL` | Already at the last level, `upgrade` only | 5th |
| `NO_GOLD` | Gold below the cost | After the cost read |
| `OK` | Applied | Last |

IDs and levels are checked before any accessor read, through Data's non-fatal `is_tower(id)` and `level_count(def_id)` (Data Rule 10), so a bot's bad ID or a last-level upgrade returns a refusal rather than reaching the fatal handler. Cost is read through the accessor at use time, never cached from when the arc or chip opened. On success, in one step and with nothing between: gold falls by the cost, the tower is created or its level raised, then `gold_changed` fires, then `tower_built` or `tower_upgraded`. A refusal changes nothing and emits nothing.

6. **Live in every phase.** The commands work in Build, Wave and Intermission (Flow Rule 10), and no phase refuses them. Paused needs no check, since input is cancelled, a tap only resumes and bots never pause. The cost of building mid-wave is attention: the thumb cannot re-pin at the same time.
7. **The arc disc builds at once.** Slot tap then disc tap is already two taps, and the discs compete only from the next press, so a double tap on a slot dismisses rather than builds. This corrects the concept's MVP item 6, which also asked for a chip on build. A disc shows its cost, and one the player cannot afford is dimmed and does nothing. The arc belongs to the HUD, which calls `build`.
8. **The upgrade chip is the safeguard for upgrades.** A tap on a tower below its last level opens the chip for 1.5 s. A tap on the same tower commits when `200 ≤ elapsed < 1500` ms at release. Taps in the first 200 ms are ignored, a hard guard against a bounce (Input Rule 8), and the chip expires at 1500 ms. The window runs on real time, fed by the wrapper to a pure `ChipWindow` with `advance(ms)`, so tests need no engine. While the window is open, TowerInput also registers the chip's own disc (TAP 300, radius 40, at the tower's x, y − 76), and a tap on it counts as a tap on the tower. The HUD draws from `chip_state()`, with a bar draining over the window, so the window has a visible clock (Battle HUD Rule 9). Both durations are presentation constants, not catalogue values (Data Rule 1).

| Event while a chip is open | Result |
|---|---|
| Same tower tapped under 200 ms | Ignored; the window keeps running |
| Same tower tapped inside the window | Calls `upgrade`. On `NO_GOLD` it stays open and dimmed, and the window does not restart. Any other result closes it |
| Window expires, then the tower is tapped | Opens a new chip; never commits. The chip's disc unregisters, and a chip press held past expiry does nothing |
| `pressed` naming the chip | Stays open |
| `pressed` naming another tap target, or none | Closes. If it names another tower, that tap opens that tower's own chip |
| `pressed` over the same tower with the hero beneath | Stays open (Input edge case) |
| Phase changes among Build, Wave and Intermission | Stays open (Flow Rule 10) |
| Paused, Won, Lost, Fatal | Closes on Flow's `phase` signal, which now names Paused and Fatal too, since `cancel()` emits nothing when input is idle. While `halted()` is true, TowerInput ignores every tap, so no chip or arc reopens |
| Retry | Destroyed with the battle |

A tower at its last level opens no chip, and emits `tower_inspected(slot_index)` for the range ring. Only one chip is open at a time.

**Attacks.**

9. **Tick.** Towers run in Combat Rule 11's slot, by ascending slot index, with `halted()` checked after every accessor read and every signal, returning at once:
   1. If `cooldown_left` is above 0, subtract 1. If it is still above 0, go to the next slot, with no reads.
   2. Read `range`. Pick from Enemy & Wave's `targets()` with Combat's `first_in`. A `slow` tower asks first among enemies with `speed_factor` 1, then, if none of those is in range, among all of them. No target: hold at 0, emit nothing and read nothing more.
   3. Read every other stat this attack needs, before changing anything. A bad read halts here with nothing half done.
   4. Set `cooldown_left = to_ticks(attack_interval)`, then call Combat's `report_attack`, which emits `attack_fired`, then `deliver` one event per victim. A `slow` tower then calls `apply_slow` per victim, passing seconds, since Combat converts them. Its `damage` of 0 applies nothing and can kill nobody.
10. **Ready and holding.** A timer counts on every tick that runs, Intermission included. A ready tower holds at 0, and it fires on the first tick that has a target, so a tower fires every N ticks exactly under constant fire.
11. **A new tower starts ready.** It gives instant feedback, and without selling the exploit is five free shots at most.
12. **An upgrade leaves the timer alone.** New damage, range and role values apply from the tower's next read, because stats are read at use time, and a new interval applies at the next reload. There is no free shot and no lost progress.
13. **Splash.** The victims are `all_in_radius` of the target's position from `targets()`, so a splash cannot hit an enemy outside the field. Its range decides only whom it may aim at.

**Gold.**

14. **Gold is one integer, never negative, with no cap, and `gold_changed` fires only when it changes.** Faucets: `starting_gold` when the battle is built (read directly from Stage); `enemy_killed(bounty)`, whoever dealt the kill; and the early-call bonus. Sinks: the two commands. Leaks pay nothing. There is no interest or stipend, which would add hoarding and blur what calling early costs. Gold freezes once `halted()` is true: a fatal leak skips the reap, so nothing is paid (Combat Rule 11).
15. **A bounty is spendable from the next command.** Kills pay in the reap slot in ascending `spawn_id`, and commands run between ticks, so they cannot interleave.
16. **The early-call bonus scales with time given up.** `wave_called_early(seconds_left)` pays the bonus at once, before the next wave's first spawn (Formulas). A flat bonus would make calling on the last tick free money. It reads no burst state (Flow Rule 9), and Start Wave in Build pays nothing. The rate is a new Stage field, `early_call_seconds_per_gold`, which keeps gold values on the records that spend or earn them.

**Reading.**

17. **Signals and reads.** Signals: `gold_changed(current)`, `tower_built(slot_index, tower_id)`, `tower_upgraded(slot_index, level)`, all on Flow's view allowlist, with nothing in gameplay depending on them. TowerInput adds `slot_tapped(slot_index)` for the HUD's arc, `tower_inspected(slot_index)` and `chip_state()`. It exists only in the wrapper, so headless wiring tests cannot see it and a story test with a fake resolver proves that a tap reaches the arc. Reads: `gold()`, `slot_state(slot_index)` (empty, or `tower_id`, `level` and `cooldown_left`). The HUD reads costs and stats through the accessor by `def_id` and level, after checking `level_count`, since asking past the last level is Fatal (Data Rule 10).

**Starter values.** These are fixtures, not balance. They were run through a throwaway simulation of the starter stage on the fixed tick and Combat Rule 11's order, using scripted bots. All costs are gold, and all times seconds.

| Tower | Level | `cost` | `damage` | `range` | `attack_interval` | Role values |
|---|---|---|---|---|---|---|
| `tower_single` | 1 | 50 | 12 | 150 | 0.6 | None |
| | 2 | 60 | 21 | 165 | 0.6 | |
| `tower_splash` | 1 | 70 | 20 | 150 | 1.0 | `splash_radius` 55 |
| | 2 | 80 | 30 | 165 | 1.0 | `splash_radius` 75 |
| `tower_slow` | 1 | 60 | 0 | 150 | 0.6 | `slow_strength` 0.4, `slow_duration` 2.0 |
| | 2 | 70 | 0 | 165 | 0.6 | `slow_strength` 0.5, `slow_duration` 2.5 |

Stage: `early_call_seconds_per_gold` 1.8. On a packet splash is worth more per gold at level 1: 0.57 on the two victims its radius reaches at 36 spacing, and 0.86 on three, against single's 0.40. On a string or a heavy, single wins: 0.40 against 0.29. Mono builds are what the bots below rule out. A full board costs 550 all single, 610 for 3 single, 1 splash and 1 slow, 650 for 2, 2 and 1, or 750 all splash. An opening of 120 buys single and single, single and slow, single and splash or slow and slow, and never splash and slow, so the first buy is a real choice.

**This run changed the enemies.** At Enemy & Wave's original HP a hero alone with no towers won, which breaks Pillar 2. So HP rose about 3 times, to `normal` 125, `fast` 60 and `heavy` 750, with bounties unchanged, and Enemy & Wave is amended. The full bot table, with the hero values it depends on, is in the Hero GDD (Simulated results), so it is kept in one place. For towers: every build loses without the hero, from wave 2 to wave 5, and no calling flips that. A mid-skill hero wins with 9 lives on all four mixed builds. Slow alone loses even with a hero, and single or splash alone win with only 7 or 6 lives, so mixes earn their slots. Calling early helps a towers-only bot, because waiting costs it nothing. A rate of 1.0 s per gold flipped a lost build into a win, and at 1.8 s no build flips.

**Where to build and when to upgrade are the decisions (user, 2026-11-02).** Filling every slot before upgrading must not be the answer, which the concept also asks for: players "specialise a few towers deeply". Single's level 2 damage rose from 18 to 21 for this. At 18 neither order led. At 20 upgrading early led, but the hero share median fell to 24.8%, below its band. At 24 single alone caught the best mixes. At 21 upgrading early leads on all four mixes, single alone stays behind and every gate passes. Across every placement of each mix (`tools/balance-sim/hero_bots.py --orders`), mid-skill lives are:

| Mix | Placements | Fill first: median, range | Upgrade in pairs: median, range |
|---|---|---|---|
| 3 single, 1 splash, 1 slow | 20 | 8, 2 to 9 | 9, 1 to 10 |
| 2 single, 2 splash, 1 slow | 30 | 8, 2 to 10 | 9, 3 to 10 |
| 3 single, 2 splash | 10 | 8.5, 6 to 9 | 9, 4 to 9 |
| 2 single, 1 splash, 2 slow | 30 | 5, 0 to 10 | 6, 0 to 10 |

Upgrading in pairs means build two, upgrade both, and repeat. A new single still offers more damage per gold, 0.40 against the upgrade's 0.25, but only while it stands where the enemies are. So the same towers can end anywhere from 0 to 10 lives, and placement matters more than order. These are scripted fixed orders, so whether people find this waits for first playable.

**Content rules, added to the content test.** All bounds are proposed.

| Check | Bound | Starter |
|---|---|---|
| Levels per tower | Exactly 2 at MVP | 2 |
| Level 2 against level 1 | `damage`, `range` and role values not lower, `attack_interval` not longer | Pass |
| `cost` | At least 1 | 50 |
| Every level-1 `cost` | At most `starting_gold` | 70 ≤ 120 |
| The two dearest different roles' level-1 costs together, on a stage offering two or more | Above `starting_gold` | 130 > 120 |
| `gold_before_last_wave` | Below the cheapest full board, which is slot count × the cheapest tower's total level costs | 496 < 550 |
| Dearest full board, likewise | Above `max_final_gold` | 750 > 670 |
| Bonus share | At most 10% of `max_final_gold` | 6.0% |
| `damage` | Exactly 0 on `slow`, above 0 otherwise | Pass |
| `range` | At most 260 | 165 |
| `attack_interval` | At least 0.2 | 0.6 |
| `slow_strength` | At most 0.6 | 0.5 |
| `burst_spike` | At least 2 at every splash level (Hero stories) | 5.78 |
| `early_call_seconds_per_gold` | One tick at least (Data, boot-fatal), so the formula never divides by 0 | 1.8 |

Enemy & Wave's L10 reads level-1 range 150 and passes at 223 for the tightest slot, and `peak_alive_ub` passes outright at 34. L11 and `burst_spike` wait for the Hero record.

**Handed to owning GDDs.**
- **Hero:** done. It sets the burst's values and owns the bot table.
- **Battle HUD:** done. It draws the arc, chip, cost, dimming and the range ring (Battle HUD GDD).
- **Enemy & Wave:** its starter HP is amended here, and its "550" gold example is now the all-single minimum.

**Deliberately not built for MVP.** Selling, undo, level 3, targeting options, unlocks, per-role gold bonuses, interest, stipends, tower damage to the hero, and a chip on build.

→ Becomes an ADR: where TowerInput sits in the wrapper, and the order of input against the real-time feed to `ChipWindow`.

### States and Transitions

| Slot | Meaning | Transitions |
|---|---|---|
| Empty | No tower; its Input target is enabled | `build` `OK` → Built, and the slot target is disabled |
| Built | Holds a tower; never returns to Empty at MVP | None |

| Tower attack | Meaning | Transitions |
|---|---|---|
| Ready | `cooldown_left` 0, holding | A target in range → fires, Cooling |
| Cooling | `cooldown_left` above 0 | Step 1 reaches 0 → step 2 in the same tick: target → fires and stays Cooling; none → Ready |

| Upgrade chip | Meaning | Transitions |
|---|---|---|
| Closed | No window | Tap on a tower below its last level → Open |
| Open | Window running for one tower | See Rule 8 |

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Data & Config | reads | Tower stats through the accessor by `def_id` and level; `starting_gold`, `slot_positions`, `early_call_seconds_per_gold` directly from Stage | Data (values); this system (meaning, balance) |
| Enemy & Wave | listens, reads | `enemy_killed(bounty)`; `targets()`; `slot_positions` | Enemy & Wave |
| Combat & Damage | calls | `deliver`, `apply_slow`, `first_in`, `all_in_radius`, `speed_factor`, `report_attack` | Combat (API); this system (when, whom, values) |
| Game State & Stage Flow | built, listens | Builder makes TowerSim and ticks it in order; injects `halted()`; forwards `wave_called_early(seconds_left)` | Flow (order); this system (bonus) |
| Input & Gesture Resolver | registers, listens | TowerInput registers slots and towers as TAP 200, disables a slot once built; hears `tap`, `pressed` | Input (API); TowerInput (meaning, chip) |
| Battle HUD | listens, calls | The signals and reads of Rule 17; calls `build` from the arc | HUD (drawing) |
| Hero System | none directly | Balanced against through bots | Bots |
| Bots and tests | call | `build`, `upgrade`, `gold()` through the builder | Harness |

## Formulas

The **early_call_bonus** formula is defined as:

`early_call_bonus = to_ticks(seconds_left) div to_ticks(early_call_seconds_per_gold)`, with whole-number division

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `seconds_left` | float, seconds | above 0, up to `intermission_duration` | calculated (Flow) | Time given up; a whole number of ticks times `dt` |
| `early_call_seconds_per_gold` | float, seconds | one tick to 600 | data file (Stage) | Seconds given up per gold |

**Output Range:** 0 to 8 per call and 40 per stage at starter values. A call with less than one rate's worth left pays 0 and still starts the wave.
**Example:** at 1.8 s, 108 ticks: 900 ticks left pays 8, 863 pays 7, 107 pays 0.

The **gold_before_wave** formula is defined as:

`gold_before_wave(w) = gold_upper_bound(w − 1) + Σ early_call_bonus(intermission_duration(i))` over waves `i` before `w`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `gold_upper_bound` | int | 0 and up | calculated (Enemy & Wave) | Starting gold plus every bounty through that wave |
| `intermission_duration` | float, seconds | as Wave | data file | The whole intermission, as if called at once |

**Output Range:** 0 and up. It assumes every enemy is killed and every call is instant. `gold_before_last_wave` is this at the last wave, and `max_final_gold` is that plus the last wave's bounties.
**Example:** 160, 216, 296, 368 and 496 before waves 2 to 6; `max_final_gold` 670, of which the bonus is 40, or 6.0%.

| After wave | Bounties | `gold_upper_bound` | Before next wave, with bonus |
|---|---|---|---|
| Start | 0 | 120 | 120 |
| 1 | 32 | 152 | 160 |
| 2 | 48 | 200 | 216 |
| 3 | 72 | 272 | 296 |
| 4 | 64 | 336 | 368 |
| 5 | 120 | 456 | 496 |
| 6 | 174 | 630 | 670 at the end |

That supports one or two decisions per wave. Filled first, the 2, 2 and 1 board has 2 towers at the start and 5 by wave 5, and goes into wave 6 three upgrades short with no calls, two with every call. A surviving player can leak at most 9 lives, worth 68 gold, and the bonus adds up to 40 more, so winners end within about two decisions of each other. The death spiral is about timing, not total gold, and instant retry is its answer until a playtest says otherwise.

The **tower_dps** formula is defined as:

`tower_dps = damage × victims / attack_interval`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `damage` | float | 0–1,000,000 | data file via the accessor | Per victim |
| `victims` | int | 1 up to the enemies in radius | calculated | 1 unless splash |
| `attack_interval` | float, seconds | one tick to 600 | data file via the accessor | Between shots |

**Output Range:** 0 for a slow tower. Starter single: 20, then 35. Splash on one victim: 20, then 30; on three victims: 60, then 90.
**Example:** a level-2 splash hitting three normals deals 30 × 3 / 1.0 = 90 per second, offered. This is a design aid, with no code behind it.

The **burst_spike** formula is defined as:

`burst_spike = (D_b × V_b) / (d × V_s)`, with `V_s = min(n, 1 + floor(r / s))`, `V_b = min(n, 1 + floor(2 × R / s))` and `s = spawn_interval × move_speed`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `D_b`, `R` | float | above 0 | data file (Burst) | Burst damage and radius |
| `d`, `r` | float | above 0 | data file (splash level) | Splash damage and radius. `r` counts one side, since the impact is the leading target |
| `n` | int | at least 5 | data file | A group's count; smaller groups are not checked, matching the burst gate of 5 hits |
| `s` | float, units | above 0 | calculated | Unslowed spacing |

**Output Range:** above 0. Below 2, one splash shot looks like half a burst. It ignores HP limits, kills and overlapping groups, so it is only a floor.
**Example:** burst 130 at radius 70, level-2 splash 30 at radius 75, normal×6 @0.6: `s` 36, `V_s` 3, `V_b` 4, so 520 / 90 = 5.78, the lowest of the starter groups.

**The gate Combat Rule 6 asked for has three parts, and none is the one it named.** One burst against splash's total over the same cooldown cannot be the test. Towers must carry the steady damage, so a level-2 splash tower on a dense packet offers more than a burst per cooldown at these values, and any fixture that lost that race would lose the wave too. What protects the spike is that it lands at once, and that splash does not take its work away:

1. `burst_spike` of at least 2, for every splash level on every group of 5 or more, in the content test.
2. In bots, `dealt_burst`'s share in the 2, 2 and 1 build is at least 75% of its share in the single-only build. Simulated, burst only: 30% against 25%, a pass.
3. In bots, the median burst hitting 3 or more enemies kills at least 2, measured on the mid-skill bot. `burst_spike` can pass on victim count alone, so this measures the outcome. Simulated: 3.5 to 4, a pass.

Combat Rule 6 is amended to match. Slow tightening a group raises `V_s` and `V_b` together, so bots rather than this formula measure it.

## Edge Cases

- **If gold exactly equals the cost**: the purchase succeeds and gold reaches 0.
- **If `build` is called on a slot the hero stands over**: it builds. A hero on a slot never blocks building (Input).
- **If a command arrives with too little gold**: `NO_GOLD`, nothing changes, nothing is emitted. Waiting a tick for a bounty is the caller's business.
- **If a bad accessor read happens during a command's cost read**: the handler halts the battle, the command returns `HALTED`, and gold and slots are unchanged.
- **If `upgrade` is called twice between ticks with gold for one**: the first is `OK`, and the second is `MAX_LEVEL`, checked before gold, since two levels are all there are.
- **If a kill and a chip commit fall on the same frame**: the tick finishes first or the command runs first, and each sees whole state. The bounty is available only to commands after the reap.
- **If a tower is built in Build**: it is Ready and holds until the first tick with a target.
- **If a slot has no path within range**: unreachable at starter values, because L10 requires 200 of path at the lowest range. A code-built fixture simply never fires.
- **If a slow tower's only targets are all slowed**: it fires at the first enemy, and Combat Rule 7 decides: equal strength keeps the longer time, and a weaker slow is ignored.
- **If two slow towers of different levels hit one enemy**: the stronger replaces the weaker, and the weaker is then ignored until the slot empties.
- **If a splash tower's target is the only one in range but others stand beyond range inside the radius**: they are hit. Range picks the aim; the radius picks the victims.
- **If a splash's impact lies near the field's edge**: only enemies in `targets()` can be hit.
- **If the last target dies to an earlier tower this tick**: the later tower finds no target, holds at 0 and fires on the next tick with one.
- **If Won is reached**: `waves_complete` makes Flow latch in the reap slot, and gold keeps whatever the reap paid first. Leftover gold is worth nothing at MVP.
- **If a fatal leak ends the stage with a tower about to fire**: the tick is skipped (Flow Rule 15) and nothing fires.
- **If the player calls with less than one rate's worth left**: the bonus is 0, no `gold_changed` fires, and the wave starts.
- **If a stage has 0 bounty on every enemy**: only starting gold and the bonus exist. No content row catches this, because every gold row is an upper bound: 160 is below 550 and passes. Accepted at MVP, with one authored stage.
- **If `upgrade` returns `HALTED` from the chip**: the chip closes. It cannot reopen, since taps are ignored while halted.
- **If the HUD previews a level past the last**: that is Fatal (Data Rule 10), so it checks `level_count` first.
- **If a wave is called while gold is short and the player buys nothing**: nothing special happens. A player with no towers still leaks and feels it, and wave 1 cannot end the stage (Enemy & Wave).
- **If `starting_gold` is below every level-1 cost**: the content test fails it. A code-built fixture simply cannot build.
- **If the app loses focus with a chip open**: Paused closes the chip, so the tap that resumes cannot commit an upgrade.

## Dependencies

**Upstream (hard):**

| System | Interface |
|---|---|
| Data & Config Pipeline | Tower levels through the accessor; `is_tower(id)`; `level_count(def_id)`; `starting_gold`, `slot_positions`, `early_call_seconds_per_gold` |
| Enemy & Wave | `enemy_killed(bounty)`, `targets()`, `slot_positions`, `gold_upper_bound` |
| Combat & Damage | `deliver`, `apply_slow`, `first_in`, `all_in_radius`, `speed_factor`, `report_attack`, tick slot |
| Input & Gesture Resolver | Target registry, `tap`, `pressed` (TowerInput only) |
| Game State & Stage Flow | Build, tick order, `halted()`, `wave_called_early(seconds_left)`, `phase` for the chip |

**Downstream, with their own GDDs:**

| System | Interface |
|---|---|
| Battle HUD & Build UI | Rule 17's signals and reads; calls `build` |
| Hero System | None in code; bot gates and `burst_spike` |

**Downstream (these have no GDD yet, so the interfaces are provisional until they confirm them):**

| System | Interface |
|---|---|
| Stat & Modifier (Vertical Slice) | Reads through the same accessor |
| Skill Tree, Synergy Hook (Vertical Slice) | Tags and accessor context with the live tower |

Per the bidirectional rule, each must list this one when authored. Data, Enemy & Wave, Combat, Input, Flow, Battle HUD and Hero already do.

## Visual/Audio Requirements

The MVP minimum, primitives only, drawn by one `_draw()` node for all towers. All values are unverified on a device and none has been rendered. Lines, flashes and splash rings belong to Combat.

| Event | Visual | Art bible |
|---|---|---|
| `single_target` | Point-up triangle, 55 px wide, solid cyan | §3 |
| `splash` | Flat-top hexagon, 56 px wide, solid cyan | §3 |
| `slow` | Upright square, 44 px side, solid cyan, so it never reads as a 56 px hairline slot | §3 |
| Level 2 | Inset outline at 60% scale, 3 px, field colour | §3 Accretion |
| Ready | Complete 2 px ring, radius 34 | §2 |
| Cooling | The ring regrows clockwise, linear; the body stays solid | §2, §4, amended |
| Build | First frame: full geometry, white overlay alpha 0.6, scale 1.15 to 1, 120 ms | §8 |
| Upgrade | First frame: the inset is present, with the same overlay | §1 |
| Slow fires | Cyan line, no flash; violet only on the victim | §4 |
| Range ring | Solid 2 px cyan, unfilled, alpha 0.5, under entities. Arc open: one ring per distinct level-1 range. Chip open: current, plus next at alpha 0.25. After a build or upgrade: 400 ms, then a 200 ms fade | §1 |

**Budget per tower.** Contour, level element, state ring. Burst clearance suppresses overlays and rings, but geometry still changes.

**Hexagon against square at quarter scale is the weakest pair**, and it needs a render test. A diamond is rejected as too near the hero's kite. Audio: none at MVP.

📌 **Asset Spec:** once the art bible is approved, run `/asset-spec system:tower-system`.

## Game Feel

A purchase lands on the first frame, with nothing to wait for, and a new tower may fire at once. Gold funds one or two decisions per wave, so the board visibly changes each wave. Towers tick along steadily, so they read as the machine working while the hero acts. No human has played this, and every timing is a starting point for the first phone test.

## UI Requirements

Battle HUD draws these; this system supplies the data.

- Gold at top-right, as digits that swap.
- Cost on each arc disc and on the chip, on a panel.
- Unaffordable: dimmed plus struck through, updated live. A refused tap nudges ±2 px once for 120 ms, with no magenta, and is skipped under Reduce Motion.
- A tap on a level-2 tower shows its range ring for 1.5 s, so the tap is not silent. It opens no chip.

📌 **UX Flag — Tower System:** run `/ux-design` for the arc and chip before writing epics. Open points: whether the chip's draining bar reads under a thumb, a dimmed cost must stay legible, a polygon plus digits in 56 px is tight, and the range ring's contrast over the path.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Sustained DPS, spike, towers-only and hero-only tests; three towers, level 2; one-tower first stage | `design/gdd/game-concept.md` | Pillars 1 and 2; MVP Definition; Onboarding | Rule dependency; amended |
| Tower fields, stat keys, never cache, level and cost meaning, sell and level questions | `design/gdd/data-config-pipeline.md` | Field domains; Tower levels and cost; Rule 10 | Value dependency; amended |
| `deliver`, `apply_slow`, helpers, tick order, splash gate | `design/gdd/combat-damage.md` | Rules 2, 6, 7, 10, 11 | Rule dependency; Rule 6 amended |
| Slots, `targets()`, `enemy_killed`, `to_ticks`, `gold_upper_bound`, L10, starter HP, bot gates | `design/gdd/enemy-wave.md` | Rules 3, 11, 14; Formulas; Starter values | Value dependency; amended |
| Early call, live actions, `halted()`, `phase`, wiring test | `design/gdd/game-state-stage-flow.md` | Rules 2, 3, 9, 10, 15 | Rule dependency |
| Tap, `pressed`, target registry, bounce guard, chip window | `design/gdd/input-gesture-resolver.md` | Rule 8; Dependencies | Rule dependency; amended |
| Polygons, accretion, states, affordance, budgets | `design/art/art-bible.md` | §2, §3, §4, §7, §8 | Value dependency; amended |
| Prior prices and range, "too basic" finding | `prototypes/hero-pin-concept/REPORT.md` | Report | Evidence |

## Acceptance Criteria

A recording fake logs Tower's signals, `attack_fired`, `deliver` and `apply_slow`, and each THEN is the entire log. A spy accessor logs reads, changes values or latches `halted()`. Factories build `sim()`: `dt` 0.25, gold 100; `A` single, cost 30/40, damage 10/15, range 100/120, interval 0.5/0.25; `B` likewise splash, radius 50; `C` slow, damage 0, strength 0.5, 1.0 s. `T` is one tick. `ChipWindow` uses `advance(ms)` and a fake `upgrade`, and chip criteria start open at 0. No scene, catalogue files or time assertions.

**CI: Logic**
1. (Rule 1) **GIVEN** `sim()`, **WHEN** `build` each role, **THEN** `OK`, with no unlock read.
2. (Rule 2) **GIVEN** `A`, **WHEN** `upgrade`, **THEN** gold falls 40 and the next shot deals 15.
3. (Rule 3) **GIVEN** `C` and a target, **WHEN** T, **THEN** `attack_fired, deliver(0), apply_slow(0.5, 1.0)`.
4. (Rule 4) **GIVEN** a built slot, **WHEN** `build`, **THEN** `SLOT_OCCUPIED`, with no refund.
5. (Rule 5) **GIVEN** a fixture with every fault set at once, **WHEN** each command runs and one fault is cleared per call, **THEN** `build` returns `HALTED`, `BAD_SLOT` (−1 and the count), `BAD_TOWER` (an enemy's ID), `SLOT_OCCUPIED`, `NO_GOLD` in that order, and `upgrade` returns `HALTED`, `BAD_SLOT` (−1 and the count), `NO_TOWER`, `MAX_LEVEL`, `NO_GOLD`. Every refusal leaves gold and slots unchanged and the log empty, and no refusal before the cost read makes an accessor read.
6. (Rule 5) **GIVEN** gold 30, **THEN** `OK`, gold 0, `gold_changed(0), tower_built(0, A)`. Gold 29: `NO_GOLD`. A changed cost: the second use reflects it. A latch in the cost read: `HALTED`, unchanged.
7. (Rule 6) **GIVEN** the builder, **THEN** both commands are `OK` in Build, Wave and Intermission.
8. (Rule 7) **WHEN** one `build`, **THEN** the tower exists, with no confirm step.
9. (Rule 8) Tap at 199: no `upgrade`, expiry unmoved. Closed, last level: a tap opens none.
10. (Chip commit) Tap at 200 or 1499: one `upgrade`. `OK` closes; `NO_GOLD` stays dimmed with expiry unmoved; `HALTED` closes.
11. (Chip expiry) Tap at 1500: a new chip, no `upgrade`.
12. (Chip pressed) Another tower: closes, and its tap opens its chip. None: closes. Same tower, hero beneath: stays.
13. (Chip phase, outcome, retry) A phase change among Build, Wave, Intermission: stays. Paused, Won, Lost, Fatal: closes; while halted, a tap opens nothing. A new battle: closed.
14. (Rule 9) **GIVEN** two ready towers, **WHEN** T, **THEN** slot order, with the timer set before `attack_fired`. Cooling: no reads. No target: `range` only. Any latch stops it.
15. (Rule 9) **GIVEN** `C`, a slowed leader and an unslowed follower, **THEN** the follower; with the follower out of range or slowed, the leader.
16. (Rule 10) **GIVEN** a constant target, **THEN** fires T0, T2, T4; with the target absent until T5, fires T5.
17. (Rule 11) **WHEN** built between ticks, **THEN** fires on the next T.
18. (Rule 12) **GIVEN** `A` just fired, **WHEN** `upgrade`, **THEN** the timer is unchanged, the next shot deals 15 at range 120, and the next reload is 1.
19. (Rule 13) **GIVEN** `B`, **THEN** an enemy beyond range inside the radius is hit; one outside `targets()` is not.
20. (Rule 14) A `HERO` kill pays; a leak pays nothing; after `halted()`, a kill and a call pay nothing. A bonus of 0 emits nothing.
21. (Rule 15) **GIVEN** gold 26, a cost of 30, and a tower about to kill an enemy worth 4, **WHEN** `build`, **THEN** `NO_GOLD`. **WHEN** T, then `build`, **THEN** `OK`.
22. (Rule 16, Flow row) **GIVEN** the builder, **WHEN** called twice, **THEN** one bonus, before the first spawn. Start in Build pays nothing.
23. (Rule 17) **GIVEN** one script, with and without listeners, **THEN** identical state; `slot_state` empty, then `A`, 1, 0.
24. (early_call_bonus) `dt` 0.25, rate 1.0: 3.0, 2.75, 0.75 pay 3, 2, 0. `dt` 1/60, rate 1.8: 900, 863, 108, 107 ticks pay 8, 7, 1, 0.
25. (gold_before_wave) A starter-shaped factory: 160, 216, 296, 368, 496; final 670.
26. (burst_spike) 130, 70, 30, 75, interval 0.5, speed 72, `n` 6: 520 / 90. `n` 4 is unchecked.

**CI: Integration**
27. (Content) **GIVEN** real records, **THEN** every row with data passes, L10 and `peak_alive_ub` included; one broken copy per row fails naming it, watched failing once.
28. (Flow, Data) The listener count is non-zero; removing kill-to-gold or call-to-bonus fails naming it. The catalogue is unchanged after a battle.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner. Margins are set at the first baseline.

| Criterion | Owner | Passes when |
|---|---|---|
| Bot gates | Hero stories | The Hero GDD's deferred table owns towers-only, hero-only, mono-role, dominant build, upgrade order, placement, share, burst outcome, always-call and `dealt_burst`, with their current results |
| `burst_spike`, L11, intermission, bypass | Hero stories | They join the content test; Combat's invariant `I` holds over a real stage |
| Burst state (Flow) | Hero stories | The bonus is unaffected by burst state; the burst is refused in Build |
| Never-cache (Data Rule 10) | This system's stories | A spy changing cost or damage between uses shows the next use reflecting it |
| TowerInput wiring | Tower UI story | With a fake resolver, taps reach `ChipWindow`, a built slot is disabled, `slot_tapped` fires, and `phase` closes the chip |
| Arc, damage by source | Battle HUD stories | A disc builds once; an unaffordable one does nothing; counters are shown; screenshots retained |
| Phone test (Input P1) | Producer | No accidental upgrades or wrong discs on the first phone build |

**Manual** (retained in `production/qa/evidence/`): a level-2 upgrade changes shape within one wave; two towers are ranked by level with no digit; triangle, hexagon, square and an empty slot are told apart at full and quarter scale in greyscale.

**Checked by code review, not tests:** no sell command (Rule 4); TowerInput changes state only through `upgrade`; the bonus reads no burst state; `tower_dps` has no code.

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Calling early is nearly free for a hero bot, though the concept promises a cost (Hero GDD, Open Questions) | qa-lead + Hero GDD | First playable |
| Do human results land between pinned once and driven? All numbers here are one scripted simulation, not game code, with slot order fixed by hand | qa-lead | First playable |
| Is one mix the solved build? All four tested mixes tie on the mid-skill bot, and no fixed bot can tell | Bots + playtest | First playable |
| Is the early-call bonus noticed at 1.8 s per gold? It pays 40 gold at most, below any tower's price on its own | Playtest | First playable |
| Does a wrong disc happen often enough to need undo? | Pillar 4 phone test | First phone build |
| Does a wrong plan that surfaces at wave 6 feel fair without selling? | Playtest | First playable |
| Does the hexagon read apart from the square at quarter scale? | art-director | First render |
| Are 3 px insets enough to rank levels on a phone? The fallback is 4 px | art-director | First phone build |
| Does the technical director accept the TowerSim and TowerInput split, and input against the real-time feed? | technical-director | Input ADR |
