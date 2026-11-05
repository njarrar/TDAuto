# Tower System (incl. Gold Economy)

> **Status**: In Review (first design review 2026-11-02 NEEDS REVISION; eight blockers, one user decision and all recommended items applied, re-review pending)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (burst outcome gate, share gate on a mid-skill bot, always-call with a hero, dominant-build gate, price of no refund).
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-05
> **Last Verified**: 2026-11-02
> Sections Player Fantasy and Tuning Knobs added 2026-11-05 from existing content; no rule changed.
> Revised 2026-11-05 to match ADR-0001 to ADR-0011 after /architecture-review.
> **Implements Pillar**: Pillar 1 (Growth You Can See: upgrades add geometry); Pillar 2 (One Hero, Not an Army: towers keep sustained DPS)

## Summary

The player's standing army and the money that buys it: three tower roles on a stage's slots, two upgrades each (level 3 added after first playable, 2026-11-05), and gold from kills and early calls. Players feel it as a choice that never quite closes, because gold cannot fill the board before the last wave, and as a commitment, because selling pays back only 70%. It owns tower attacks, gold and the build and upgrade commands, and no damage, targeting helpers, enemy list or arc drawing.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Enemy & Wave, Combat & Damage, Input & Gesture Resolver, Data & Config Pipeline, Game State & Stage Flow`

## Overview

Towers are what holds the path while the hero decides fights. The player taps an empty slot and picks one of three roles from an arc, then later taps a tower and taps again to upgrade it. From then on towers fire by themselves at the first enemy along the path in range. Gold comes from starting gold, kills and calling a wave early, and it is always too little to fill the board before the last wave, so each purchase says what the player thinks is coming. There is no selling, so a tower is a commitment and growth stays on the field: each upgrade adds visible geometry. The system exists so the hero has something to complement: towers carry the steady damage, and no tower build may clear the stage comfortably without the hero (Pillar 2). It owns attack timing, gold, slots' build state and the two commands that spend gold. Combat applies the damage, and the HUD draws the arc and the chip.

## Player Fantasy

The player should feel that each purchase says what they think is coming. Gold never quite fills the board before the last wave, so the choice never closes, and with no selling each build is a commitment (Summary, Rule 4). A purchase lands on the first frame, and a new tower may fire at once (Game Feel, Rule 11). Each upgrade adds visible geometry, so growth stays on the field (Pillar 1, Growth You Can See). Towers tick along steadily and read as the machine working while the hero acts: towers keep the sustained damage, the hero keeps the spike, and no tower build clears the stage comfortably without the hero (Pillar 2, One Hero, Not an Army). Where to build and when to upgrade are the decisions, and filling every slot first must not be the answer (user, 2026-11-02). Gold funds one or two decisions per wave, so the board visibly changes each wave. The main MDA aesthetic is Challenge, through the choice of what to buy. No human has played this, so the feeling is unverified.

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

2. **Three levels (first playable, user 2026-11-05; was two at MVP).** Level 3 gives gold a use once every slot is full. Starter level 3: single 80 gold, damage 32, range 180; splash 100, damage 42, range 180, radius 90; slow 85, range 180, strength 0.6 for 3.0 s. Each level holds absolute values. `cost` at level N is the price of reaching N, as Data & Config proposed. The content rule now asks for exactly three levels; the drawer shows one pip per level.
3. **Slow deals no damage.** A slow tower with `damage` 0 never earns a kill by itself, and cannot win alone. Combat Rule 10 sets its target: the first unslowed enemy, else the first enemy.
4. **Sell pays back 70% (first playable, user 2026-11-05; was: no selling at MVP).** The user filled every slot and then had no way to change a tower or keep growing, so selling is in. `sell(slot_index)` pays `sell_refund_percent` (a Stage field, optional, default 70, 0 to 100) of everything spent on that slot, its build plus every upgrade, rounded down, and empties the slot so any role can be built there. Check order: between ticks, halted, slot, tower; results `OK`, `HALTED`, `BAD_SLOT`, `NO_TOWER`. It emits `gold_changed` only when the refund is not 0 and no new signal: views poll `slot_tower()`. The 30% loss keeps a build a commitment and stops free moves to chase each packet. Sell lives on the tower panel (Rule 8).

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

IDs and levels are checked before any accessor read, through Data's non-fatal `is_tower(id)` and `level_count(def_id)` (Data Rule 10), so a bot's bad ID or a last-level upgrade returns a refusal rather than reaching the fatal handler. Cost is read through the accessor at use time, never cached from when the arc or chip opened. On success, in one step and with nothing between: gold falls by the cost, the tower is created or its level raised, then `gold_changed` fires, then `tower_built` or `tower_upgraded`. All state is committed before the first signal, and a listener to these signals must not call a command. A refusal changes nothing and emits nothing.

6. **Live in every phase.** The commands work in Build, Wave and Intermission (Flow Rule 10), and no phase refuses them. Paused needs no check, since input is cancelled, a tap only resumes and bots never pause. The cost of building mid-wave is attention: the thumb cannot re-pin at the same time.
7. **The arc disc builds at once.** Slot tap then disc tap is already two taps, and the discs compete only from the next press, so a double tap on a slot dismisses rather than builds. This corrects the concept's MVP item 6, which also asked for a chip on build. A disc shows its cost, and one the player cannot afford is dimmed and does nothing. The arc belongs to the HUD, which calls `build`.
8. **The tower panel (first playable, user 2026-11-05; was a 1.5 s timed chip).** A tap on a tower opens its panel and shows its range ring: an **Upgrade** button with the next level's cost (only below the last level), left of the tower, and a **Sell** button with the refund, right of it, both radius 36 (the 48 dp touch floor, Input Rule 2) and 76 px above the tower centre (TowerInput `PANEL_DX` 44). The panel has no time limit. It closes on Sell, on a second tap on the same tower, on a press anywhere else, and on Paused, an outcome or Fatal. Upgrade keeps it open on the new level and removes the Upgrade button at the last level. A button tap in the first 200 ms after opening is ignored, the bounce guard (Input Rule 8), fed by `ChipWindow.advance(ms)` on real time. On `NO_GOLD` the panel stays open with the cost dimmed. The table below is the earlier timed chip's, kept for history; where it differs, this rule wins.

| Event while a chip is open | Result |
|---|---|
| Same tower tapped under 200 ms | Ignored; the window keeps running |
| Same tower tapped inside the window | Calls `upgrade`. On `NO_GOLD` it stays open and dimmed, and the window does not restart. Any other result closes it |
| Window expires, then the tower is tapped | Opens a new chip; never commits. The chip's disc unregisters, and a chip press held past expiry does nothing |
| `pressed` naming the chip | Stays open |
| `pressed` naming another tap target, or none | Closes. If it names another tower, that tap opens that tower's own chip |
| `pressed` over the same tower with the hero beneath | Stays open (Input edge case) |
| Phase changes among Build, Wave and Intermission | Stays open (Flow Rule 10) |
| Paused, Won, Lost, Fatal | Closes on Flow's `phase_changed` signal, which now names Paused and Fatal too, since `cancel()` emits nothing when input is idle. While `halted()` is true, TowerInput ignores every tap, so no chip or arc reopens |
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
12. **An upgrade leaves the timer alone.** New damage, range and role values apply from the tower's next read, because stats are read at use time, and a new interval applies at the next reload. There is no free shot, and a running timer keeps its length even if the new interval is shorter. Starter intervals are equal across levels, so this does not arise yet.
13. **Splash.** The victims are `all_in_radius` of the target's position from `targets()`, so a splash cannot hit an enemy outside the field. Its range decides only whom it may aim at.

**Gold.**

14. **Gold is one integer, never negative, with no cap, and `gold_changed` fires only when it changes.** Faucets: `starting_gold` when the battle is built (read directly from Stage); `enemy_killed(bounty)`, whoever dealt the kill; and the early-call bonus. Sinks: the two commands. Leaks pay nothing. There is no interest or stipend, which would add hoarding and blur what calling early costs. Gold freezes once `halted()` is true: a fatal leak skips the reap, so nothing is paid (Combat Rule 11).
15. **A bounty is spendable from the next command.** Kills pay in the reap slot in ascending `spawn_id`, and commands run between ticks, so they cannot interleave.
16. **The early-call bonus scales with time given up.** `wave_called_early(seconds_left)` pays the bonus at once, before the next wave's first spawn (Formulas). A flat bonus would make calling on the last tick free money. It reads no burst state (Flow Rule 9), and Start Wave in Build pays nothing. Calling costs burst recovery only while the burst could still be cooling: at starter values it needs 10.25 s of the 15 s, so a call with 4.75 s or less left costs no recovery and pays at most 2 gold. That is accepted. The rate is a new Stage field, `early_call_seconds_per_gold`, which keeps gold values on the records that spend or earn them.

**Reading.**

17. **Signals and reads.** Signals: `gold_changed(current)`, `tower_built(slot_index, tower_id)`, `tower_upgraded(slot_index, level)`, all on Flow's view allowlist, with nothing in gameplay depending on them. A read `slows_applied()` counts every `apply_slow` call, so the result can show what a tower that kills nothing did (Battle HUD Rule 15). TowerInput adds `slot_tapped(slot_index)` for the HUD's arc, `tower_inspected(slot_index)` and `chip_state()`. It exists only in the wrapper, so headless wiring tests cannot see it and a story test with a fake resolver proves that a tap reaches the arc. Reads: `gold()`, `slot_count()`, and per slot `slot_tower(slot_index)` (`&""` when empty), `slot_level(slot_index)` and `slot_cooldown_left(slot_index)` (ADR-0010). The HUD reads costs and stats through the accessor by `def_id` and level, after checking `level_count`, since asking past the last level is Fatal (Data Rule 10).

**Starter values.** These are fixtures, not balance. They were run through a throwaway simulation of the starter stage on the fixed tick and Combat Rule 11's order, using scripted bots. All costs are gold, and all times seconds.

| Tower | Level | `cost` | `damage` | `range` | `attack_interval` | Role values |
|---|---|---|---|---|---|---|
| `tower_single` | 1 | 50 | 12 | 150 | 0.6 | None |
| | 2 | 60 | 21 | 165 | 0.6 | |
| `tower_splash` | 1 | 70 | 20 | 150 | 1.0 | `splash_radius` 55 |
| | 2 | 80 | 30 | 165 | 1.0 | `splash_radius` 75 |
| `tower_slow` | 1 | 60 | 0 | 150 | 0.6 | `slow_strength` 0.4, `slow_duration` 2.0 |
| | 2 | 70 | 0 | 165 | 0.6 | `slow_strength` 0.5, `slow_duration` 2.5 |

Stage: `early_call_seconds_per_gold` 1.8. On a packet splash is worth more per gold at level 1: 0.57 on the two victims its radius reaches at 36 spacing, and 0.86 on three, against single's 0.40. On a string or a heavy, single wins: 0.40 against 0.29. Mono builds are what the bots below rule out. A full board costs 550 all single, 610 for 3 single, 1 splash and 1 slow, 650 for 2, 2 and 1, or 750 all splash. An opening of 160 (first playable rebalance, 2026-11-05; was 120) buys three level-1 towers in most mixes (single, single and slow is 160; single, single and single 150), or two with an upgrade.

**This run changed the enemies.** At Enemy & Wave's original HP a hero alone with no towers won, which breaks Pillar 2. So HP rose about 3 times, to `normal` 125, `fast` 60 and `heavy` 750, with bounties unchanged, and Enemy & Wave is amended. The full bot table, with the hero values it depends on, is in the Hero GDD (Simulated results), so it is kept in one place. For towers: every build loses without the hero, from wave 2 to wave 5, and no calling flips that. A mid-skill hero wins with 9 lives on all four mixed builds. Slow alone loses even with a hero, and single or splash alone win with only 6 lives, so mixes earn their slots. Calling early helps a towers-only bot, because waiting costs it nothing. A rate of 1.0 s per gold flipped a lost build into a win, and at 1.8 s no build flips.

**Spending the whole opening has a price.** Single and splash, or slow and slow, leave 0 gold and at most 48 after wave 1, below the cheapest purchase of 50, so nothing new arrives until wave 2 pays. Single and single can reach 68, and single and slow 58. **First playable (user, 2026-11-05):** the opening felt like a trap: the start bought only two singles, kills paid too little, and enemies took too many shots. A bounty step to 5 was not enough, so the stage was rebalanced: `starting_gold` 160, bounties 7, 4, 24, and enemy HP down about 30% (Enemy & Wave). The user chose fun over two gates, "gold never fills the board" and "the first buy is a forced choice", which now fail by choice (Formulas). The bot runs above used the old values and have not been rerun: the user then found that level-3 towers won with no hero. Wave `hp_scale` (Enemy & Wave) answers it: in the updated bot run every towers-only build loses and a mid-skill hero wins every mix.

**Where to build and when to upgrade are the decisions (user, 2026-11-02).** Filling every slot before upgrading must not be the answer, which the concept also asks for: players "specialise a few towers deeply". Single's level 2 damage rose from 18 to 21 for this. At 18 neither order led. At 20 upgrading early led, but the hero share median fell to 24.8%, below its band. At 24 single alone caught the best mixes. At 21 upgrading early leads on all four mixes, single alone stays behind and every gate passes. Across every placement of each mix (`tools/balance-sim/hero_bots.py --orders`), mid-skill lives are:

| Mix | Placements | Fill first: median, range | Upgrade in pairs: median, range |
|---|---|---|---|
| 3 single, 1 splash, 1 slow | 20 | 7, 0 to 9 | 9, 0 to 10 |
| 2 single, 2 splash, 1 slow | 30 | 7, 0 to 10 | 9, 1 to 10 |
| 3 single, 2 splash | 10 | 8.5, 6 to 9 | 9, 3 to 9 |
| 2 single, 1 splash, 2 slow | 30 | 4, 0 to 10 | 6, 0 to 10 |

Upgrading in pairs means build two, upgrade both, and repeat. A new single still offers more damage per gold, 0.40 against the upgrade's 0.25, but only while it stands where the enemies are. So the same towers can end anywhere from 0 to 10 lives, and placement matters more than order. These are scripted fixed orders, so whether people find this waits for first playable.

**Content rules, added to the content test.** All bounds are proposed.

| Check | Bound | Starter |
|---|---|---|
| Levels per tower | Exactly 2 at MVP | 2 |
| Level 2 against level 1 | `damage`, `range` and role values not lower, `attack_interval` not longer | Pass |
| `cost` | At least 1 | 50 |
| Every level-1 `cost` | At most `starting_gold` | 70 ≤ 160 |
| The two dearest different roles' level-1 costs together, on a stage offering two or more | Above `starting_gold` (**relaxed** by the first playable rebalance, user 2026-11-05) | 130 < 160, fails by choice |
| `gold_before_last_wave` | Below the cheapest full board, which is slot count × the cheapest tower's total level costs (**relaxed**, user 2026-11-05) | 742 > 550, fails by choice |
| Dearest full board, likewise | Above `max_final_gold` (**relaxed**, user 2026-11-05) | 750 < 1018, fails by choice |
| Bonus share | At most 10% of `max_final_gold` | 3.9% |
| `wave_income`, every wave from the second | At least the cheapest level-1 `cost`, so no later wave funds nothing | 56 ≥ 50 |
| `wave_income`, every wave | At most twice the dearest `cost`, so a wave funds one or two decisions | 128 ≤ 160 |
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

**Deliberately not built for MVP.** Undo, targeting options, unlocks, per-role gold bonuses, interest, stipends, tower damage to the hero, and a chip on build.

→ Becomes an ADR, before any TowerInput story: where TowerInput sits in the wrapper, who owns the real-time feed to `ChipWindow` given Flow Rule 4's ban on `_process` in gameplay systems, the order of input against that feed, typed signal signatures including `tower_id`'s type, and retry teardown, so that no old battle stays alive through a connection. Decided: ADR-0010 builds TowerInput in `BattleWrapper.attach` with its own `ChipWindow` fed by `advance(ms)` (Decisions 1 and 8); ADR-0004 Decision 5 runs input before the ticks; ADR-0006 Decision 4 types `tower_id` as `StringName`; ADR-0001 Decision 7 owns retry teardown.

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
| Input & Gesture Resolver | registers, listens | TowerInput registers slots and towers as TAP 200, disables a slot once built; hears `tapped`, `pressed` | Input (API); TowerInput (meaning, chip) |
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

**Output Range:** 0 up to `to_ticks(intermission_duration) div to_ticks(early_call_seconds_per_gold)` per call, which is 8 per call and 40 per stage at starter values. A call with less than one rate's worth left pays 0 and still starts the wave.
**Example:** at 1.8 s, 108 ticks: 900 ticks left pays 8, 863 pays 7, 107 pays 0.

Every authored time passes through `to_ticks`, so a value that is not a whole number of ticks is rounded, by at most half a tick: 1.8 s at `dt` 0.25 is 7 ticks, or 1.75 s. Starter values are exact at `dt` 1/60.

The **gold_before_wave** formula is defined as:

`gold_before_wave(w) = gold_upper_bound(w − 1) + Σ early_call_bonus(intermission_duration(i))` over waves `i` before `w`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `gold_upper_bound` | int | 0 and up | calculated (Enemy & Wave) | Starting gold plus every bounty through that wave |
| `intermission_duration` | float, seconds | as Wave | data file | The whole intermission, as if called at once |

**Output Range:** 0 and up. It assumes every enemy is killed and every call is instant. `gold_before_last_wave` is this at the last wave, and `max_final_gold` is that plus the last wave's bounties.
**Example:** 224, 316, 440, 552 and 742 before waves 2 to 6; `max_final_gold` 1018, of which the bonus is 40, or 3.9% (first playable rebalance, 2026-11-05: start 160, bounties 7, 4, 24; before it 160, 216, 296, 368, 496 and 670).

| After wave | Bounties | `gold_upper_bound` | Before next wave, with bonus |
|---|---|---|---|
| Start | 0 | 160 | 160 |
| 1 | 56 | 216 | 224 |
| 2 | 84 | 300 | 316 |
| 3 | 116 | 416 | 440 |
| 4 | 104 | 520 | 552 |
| 5 | 182 | 702 | 742 |
| 6 | 276 | 978 | 1018 at the end |

The **wave_income** formula is defined as:

`wave_income(w) = gold_before_wave(w + 1) − gold_before_wave(w)`, for every wave but the last

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `gold_before_wave` | int | 0 and up | calculated | As above |

**Output Range:** 0 and up. `gold_before_wave` only rises, so the last-wave rows bound the total, and this bounds each step.
**Example:** 40, 56, 80, 72 and 128 at starter values. The first wave's 40 is below the cheapest purchase, which is why the content row starts at the second wave.

That supports one or two decisions per wave. Filled first, the 2, 2 and 1 board has 2 towers at the start and 5 by wave 5, and goes into wave 6 three upgrades short with no calls, two with every call. A surviving player can leak at most 9 lives, worth 48 gold, and the bonus adds up to 40 more, so winners end within about two decisions of each other. The death spiral is about timing, not total gold, and instant retry is its answer until a playtest says otherwise.

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
| `n` | int | at least 5 | data file | A group's count; smaller groups are not checked, being too few to threaten the burst's spike |
| `s` | float, units | above 0 | calculated | Unslowed spacing |

**Output Range:** above 0. Below 2, one splash shot looks like half a burst. It ignores HP limits, kills, overlapping groups and hairpins, which change spacing, so it is a heuristic, not a bound.
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
- **If two slow towers of different levels hit one enemy**: the stronger replaces the weaker, and the weaker is then ignored until the slot empties, even with one tick left. So a level-1 slow beside a level-2 one does little. Accepted at MVP.
- **If a splash tower's target is the only one in range but others stand beyond range inside the radius**: they are hit. Range picks the aim; the radius picks the victims.
- **If a splash's impact lies near the field's edge**: only enemies in `targets()` can be hit.
- **If the last target dies to an earlier tower this tick**: the later tower finds no target, holds at 0 and fires on the next tick with one.
- **If Won is reached**: `waves_completed` makes Flow latch in the reap slot, and gold keeps whatever the reap paid first. Leftover gold is worth nothing at MVP.
- **If a fatal leak ends the stage with a tower about to fire**: the tick is skipped (Flow Rule 15) and nothing fires.
- **If the player calls with less than one rate's worth left**: the bonus is 0, no `gold_changed` fires, and the wave starts.
- **If a stage has 0 bounty on every enemy**: only starting gold and the bonus exist. The `wave_income` floor fails it, since 8 is below the cheapest level-1 `cost`. A code-built fixture simply earns nothing.
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
| Input & Gesture Resolver | Target registry, `tapped`, `pressed` (TowerInput only) |
| Game State & Stage Flow | Build, tick order, `halted()`, `wave_called_early(seconds_left)`, `phase_changed` for the chip |

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

## Tuning Knobs

Starter values are fixtures, not balance (Starter values). Every bound from this GDD's content-rule table is proposed, as that table says. A range marked "field domain" comes from the field-domain table in `design/gdd/data-config-pipeline.md`, which guards against typos and broken simulation, not balance. Visual sizes and timings sit in Visual/Audio Requirements and UI Requirements, and are not repeated here.

| Knob | Current value | Safe range | What it changes | Owner | Source |
|---|---|---|---|---|---|
| `cost`, per level | Single 50, 60; splash 70, 80; slow 60, 70 (starter fixture) | At least 1 (proposed); every level-1 cost at most `starting_gold`; the two dearest different roles' level-1 costs together above `starting_gold`; `gold_before_last_wave` below the cheapest full board; the dearest full board above `max_final_gold` (all proposed); up to 100,000 (field domain) | Price of each build and upgrade, the full-board cost, and the first-buy choice | Tower | Starter values; content rules; `gold_before_wave` |
| `damage`, per level | Single 12, 21; splash 20, 30; slow 0, 0 (starter fixture) | Exactly 0 on `slow`, above 0 otherwise; level 2 not lower (proposed); up to 1,000,000 (field domain) | Damage per victim, and so `tower_dps`, kills and gold | Tower | Single's level 2 rose from 18 to 21 (user, 2026-11-02): at 20 the hero share median fell to 24.8%, and at 24 single alone caught the best mixes |
| `range`, per level | 150, 165 on every role (starter fixture) | Above 0 to 260; level 2 not lower (proposed); Enemy & Wave's L10 needs 200 of path per slot at the lowest level-1 range | Whom a tower may aim at, and path coverage | Tower | Content rules; L10 passes at 223 |
| `attack_interval`, per level | Single 0.6, splash 1.0, slow 0.6, equal across levels (starter fixture) | At least 0.2 (proposed), up to 600 (field domain); level 2 not longer (proposed) | Fire cadence, and so `tower_dps` | Tower | Starter values; `tower_dps` |
| `splash_radius`, per level | 55, 75 (starter fixture) | Above 0 to 2,000 (field domain); level 2 not lower; `burst_spike` at least 2 at every splash level (proposed) | Victims per splash, and how much splash takes from the burst | Tower | `burst_spike`: 5.78 at starter values |
| `slow_strength`, per level | 0.4, 0.5 (starter fixture) | Above 0 to 0.6; level 2 not lower (proposed) | Enemy speed while slowed | Tower; meaning owned by Combat | Content rules |
| `slow_duration`, per level | 2.0, 2.5 s (starter fixture) | One tick (1/60) to 600 (field domain); level 2 not lower (proposed) | How long a slow lasts | Tower | Starter values |
| `early_call_seconds_per_gold` | 1.8 s (starter fixture) | One tick to 600 (field domain, boot-fatal); bonus share at most 10% of `max_final_gold` (proposed) | Bonus per second given up: 8 per call and 40 per stage at starter values | Tower (Stage field) | `early_call_bonus`; at 1.0 a lost towers-only build flipped to a win, and at 1.8 none flips (Starter values) |
| Levels per tower | 2 | Exactly 2 at MVP (proposed) | Upgrade depth | Tower | Rule 2 |
| Wave-income bounds | `wave_income` at least the cheapest level-1 `cost` from the second wave, at most twice the dearest `cost` (proposed) | range not set in this GDD | How many decisions each wave funds | Tower | Content rules; `wave_income` |
| Chip window and bounce guard | 1,500 ms, 200 ms | range not set in this GDD | Time to confirm an upgrade, and the guard against a bounce | Tower (presentation constants) | Rule 8; Input Rule 8 |
| Chip disc | Radius 40, at the tower's y − 76 | range not set in this GDD | Where the chip tap lands | Tower (TowerInput) | Rule 8 |

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
| Slow fires | Cyan line, no flash; violet only on the victim, plus Combat's slow drag lines, so a slowed enemy reads without a number | §4 |
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

📌 **UX Flag — Tower System:** run `/ux-design` for the arc and chip before writing epics. Open points: whether the chip's draining bar reads under a thumb, a dimmed cost must stay legible, a polygon plus digits in 56 px is tight, and the range ring's contrast over the path. That pass must specify a refusal cue that does not rely on motion, since Reduce Motion leaves a refused tap with only the standing dim. It must also cover an expired or closed chip, an armed look after the 200 ms guard, a maximum-level cue beside the range ring, a chip that would leave the field, static fallbacks for the build overlay and arc collapse, and the unit-to-dp scale behind the 44 pt / 48 dp targets.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Sustained DPS, spike, towers-only and hero-only tests; three towers, level 2; one-tower first stage | `design/gdd/game-concept.md` | Pillars 1 and 2; MVP Definition; Onboarding | Rule dependency; amended |
| Tower fields, stat keys, never cache, level and cost meaning, sell and level questions | `design/gdd/data-config-pipeline.md` | Field domains; Tower levels and cost; Rule 10 | Value dependency; amended |
| `deliver`, `apply_slow`, helpers, tick order, splash gate | `design/gdd/combat-damage.md` | Rules 2, 6, 7, 10, 11 | Rule dependency; Rule 6 amended |
| Slots, `targets()`, `enemy_killed`, `to_ticks`, `gold_upper_bound`, L10, starter HP, bot gates | `design/gdd/enemy-wave.md` | Rules 3, 11, 14; Formulas; Starter values | Value dependency; amended |
| Early call, live actions, `halted()`, `phase_changed`, wiring test | `design/gdd/game-state-stage-flow.md` | Rules 2, 3, 9, 10, 15 | Rule dependency |
| Tap, `pressed`, target registry, bounce guard, chip window | `design/gdd/input-gesture-resolver.md` | Rule 8; Dependencies | Rule dependency; amended |
| Polygons, accretion, states, affordance, budgets | `design/art/art-bible.md` | §2, §3, §4, §7, §8 | Value dependency; amended |
| Prior prices and range, "too basic" finding | `prototypes/hero-pin-concept/REPORT.md` | Report | Evidence |

## Acceptance Criteria

A recording fake logs Tower's signals, `attack_fired`, `deliver` and `apply_slow`, and each THEN is the entire log. A spy accessor logs reads, changes values or latches `halted()`. Factories build `sim()`: `dt` 0.25, gold 100; `A` single, cost 30/40, damage 10/15, range 100/120, interval 0.5/0.25; `B` as `A`, splash, radius 50; `C` as `A`, slow, damage 0, strength 0.5, 1.0 s. `T` is one tick. `ChipWindow` uses `advance(ms)`, a fake `upgrade` and a fake `phase_changed`, and chip criteria start open at 0. No scene, catalogue files or time assertions, except where a criterion names real records.

**CI: Logic**
1. (Rule 1) **GIVEN** `sim()`, **WHEN** `build` `A`, `B`, `C` on slots 0, 1, 2, **THEN** each is `OK`, gold is 10, the log is `gold_changed(70), tower_built(0, A), gold_changed(40), tower_built(1, B), gold_changed(10), tower_built(2, C)`, and no unlock is read.
2. (Rule 2) **GIVEN** `A` built, **WHEN** `upgrade`, **THEN** `OK`, gold 30, `gold_changed(30), tower_upgraded(0, 2)`.
3. (Rule 2) **GIVEN** `A` upgraded and a target, **WHEN** T, **THEN** `attack_fired, deliver(15)`.
4. (Rule 3) **GIVEN** `C` and a target, **WHEN** T, **THEN** `attack_fired, deliver(0), apply_slow(0.5, 1.0)`.
5. (Rule 4) **GIVEN** a built slot, **WHEN** `build`, **THEN** `SLOT_OCCUPIED`, gold unchanged, an empty log.
6. (Rule 5) **GIVEN** a fixture with every fault set at once, **WHEN** each command runs and one fault is cleared per call, **THEN** `build` returns `HALTED`, `BAD_SLOT` (−1 and the count), `BAD_TOWER` (an enemy's ID), `SLOT_OCCUPIED`, `NO_GOLD` in that order, and `upgrade` returns `HALTED`, `BAD_SLOT` (−1 and the count), `NO_TOWER`, `MAX_LEVEL`, `NO_GOLD`. Every refusal leaves gold and slots unchanged and the log empty, and no refusal before the cost read makes an accessor read.
7. (Rule 5) **GIVEN** gold 30, **WHEN** `build` `A`, **THEN** `OK`, gold 0, `gold_changed(0), tower_built(0, A)`.
8. (Rule 5) **GIVEN** gold 29, **WHEN** `build` `A`, **THEN** `NO_GOLD`, gold 29, an empty log.
9. (Rule 5) **GIVEN** a spy doubling cost between two builds, **THEN** the second build falls by the new cost.
10. (Rule 9) **GIVEN** a spy doubling damage between two shots, **THEN** the second `deliver` carries the new damage.
11. (Rule 5) **GIVEN** a latch in the cost read, **WHEN** `build`, **THEN** `HALTED`, gold and slots unchanged, an empty log.
12. (Rule 5) **GIVEN** a `gold_changed` listener, **WHEN** `build` is `OK`, **THEN** the listener already reads the tower through `slot_tower` and `slot_level`.
13. (Rule 8) Tap at 199: no `upgrade`, expiry unmoved.
14. (Rule 8) Closed, last level: a tap opens no chip and emits `tower_inspected(slot_index)`.
15. (Chip commit) Tap at 200: one `upgrade`.
16. (Chip commit) Tap at 1499: one `upgrade`.
17. (Chip commit) `upgrade` returns `OK`: closes.
18. (Chip commit) `upgrade` returns `NO_GOLD`: stays dimmed, expiry unmoved.
19. (Chip commit) `upgrade` returns `HALTED`: closes.
20. (Chip expiry) Tap at 1500: a new chip, no `upgrade`.
21. (Chip disc) A tap naming the chip at 500: one `upgrade`.
22. (Chip disc) A tap naming the chip after expiry, from a press held past it: no `upgrade`, no new chip.
23. (Chip pressed) `pressed` naming the chip: stays.
24. (Chip pressed) `pressed` naming another tower: closes, and that tap opens its chip.
25. (Chip pressed) `pressed` naming nothing: closes.
26. (Chip pressed) `pressed` over the same tower, hero beneath: stays.
27. (Chip phase) A change among Build, Wave and Intermission: stays.
28. (Chip outcome) Each of Paused, Won, Lost and Fatal: closes.
29. (Chip outcome) While halted, a tap opens nothing.
30. (Chip retry) A new battle: closed.
31. (Rule 9) **GIVEN** two ready towers and a target, **WHEN** T, **THEN** slot 0's `attack_fired, deliver`, then slot 1's, and each `attack_fired` listener already reads that tower's `cooldown_left` as 2.
32. (Rule 9) **GIVEN** a Cooling tower still above 0 after step 1, **WHEN** T, **THEN** no reads and an empty log.
33. (Rule 9) **GIVEN** a ready tower and no target, **WHEN** T, **THEN** `range` is the only read and the log is empty.
34. (Rule 9) **GIVEN** a firing tower, **WHEN** `halted()` latches at each read and signal in turn, **THEN** the log ends at that point and no later tower acts.
35. (Rule 9) **GIVEN** `B` and a latch on the `splash_radius` read, **WHEN** T, **THEN** `cooldown_left` is 0 and the log is empty.
36. (Rule 9) **GIVEN** `C`, a slowed leader and an unslowed follower, **THEN** `C` targets the follower.
37. (Rule 9) **GIVEN** `C` with that follower out of range or slowed, **THEN** `C` targets the leader.
38. (Rule 9) **GIVEN** two towers and one target the first kills, **WHEN** T, **THEN** only the first logs, and the second holds at 0.
39. (Rule 10) **GIVEN** a constant target, **THEN** fires on T0, T2, T4.
40. (Rule 10) **GIVEN** a target present only at T0 and from T5, **THEN** the tower reaches 0 on T2, holds, and fires on T0 and T5.
41. (Rule 11) **WHEN** built between ticks with a target, **THEN** it fires on the next T.
42. (Rule 12) **GIVEN** `A` just fired, **WHEN** `upgrade`, **THEN** the timer is unchanged, the next shot deals 15 at range 120, and the next reload is 1 tick.
43. (Rule 13) **GIVEN** `B`, **THEN** an enemy beyond range inside the radius is hit.
44. (Rule 13) **GIVEN** `B`, **THEN** an enemy inside the radius but outside `targets()` is not hit.
45. (Rule 14) `gold()` starts at the fixture's `starting_gold`.
46. (Rule 14) A kill by a tower and one by `HERO` each log `gold_changed` with the bounty added.
47. (Rule 14) A leak: an empty log.
48. (Rule 14) After `halted()`, a kill and a call: an empty log.
49. (Rule 14) A bounty of 0 and a bonus of 0: an empty log.
50. (Rule 14) Gold passes 100,000 uncapped.
51. (Rule 15) **GIVEN** gold 26, a cost of 30, and a tower about to kill an enemy worth 4, **WHEN** `build`, **THEN** `NO_GOLD`. **WHEN** T, then `build`, **THEN** `OK`.
52. (Rule 15) **GIVEN** two kills in one tick, worth 4 and 3, **WHEN** T, **THEN** `gold_changed` twice, in ascending `spawn_id`.
53. (Rule 17) **GIVEN** one script, with and without listeners, **THEN** identical state; the slot reads give `&""`, then `A`, level 1, `cooldown_left` 0.
54. (Rule 17) **GIVEN** `C` and a target, **WHEN** T, **THEN** `slows_applied()` is 1. `A` leaves it at 0.
55. (early_call_bonus) `dt` 0.25, rate 1.0: 3.0, 2.75, 0.75 pay 3, 2, 0.
56. (early_call_bonus) `dt` 1/60, rate 1.8: `to_ticks` gives 108, and 900, 863, 108, 107 ticks pay 8, 7, 1, 0.
57. (burst_spike) Burst 130, radius 70; splash 30, radius 75; `s` 36 from 0.6 × 60; `n` 6: 520 / 90, within 0.005.
58. (burst_spike) `n` 5 is checked, and `n` 4 is not.

**CI: Integration**
59. (Content) **GIVEN** real records, **THEN** every row with data passes, L10 and `peak_alive_ub` included; one broken copy per row fails naming it, watched failing once.
60. (Flow, Data) The listener count is non-zero; removing kill-to-gold or call-to-bonus fails naming it. The catalogue is unchanged after a battle.
61. (Rule 6) **GIVEN** the builder, **THEN** both commands are `OK` in Build, Wave and Intermission.
62. (Rule 10) **GIVEN** the builder and a tower that fired just before the clear, **WHEN** Intermission's ticks run, **THEN** its timer reaches 0.
63. (Rule 16, Flow row) **GIVEN** the builder at `dt` 1/60, **WHEN** called twice with 900 ticks left, **THEN** gold rises by 8 once, before the first spawn.
64. (Rule 16) A call with 107 ticks left: no `gold_changed`, and the wave starts. Start in Build pays nothing.
65. (gold_before_wave, wave_income) A starter-shaped factory at `dt` 1/60 with 900-tick intermissions: 224, 316, 440, 552, 742; final 1018; income 64, 92, 124, 112, 190.
66. (Edge cases) A hero over a slot does not block `build`.
67. (Edge cases) A fatal leak skips the tick: no `attack_fired` that tick.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner. Margins are set at the first baseline.

| Criterion | Owner | Passes when |
|---|---|---|
| Bot gates | Hero stories | The Hero GDD's deferred table owns towers-only, hero-only, mono-role, dominant build, upgrade order, placement, share, burst outcome, always-call and `dealt_burst`, each with its threshold |
| `burst_spike`, L11, intermission, Combat's bypass row | Hero stories | They join the content test; Combat's invariant `I` holds over a real stage |
| Burst state (Flow) | Hero stories | The bonus is unaffected by burst state; the burst is refused in Build |
| TowerInput wiring | Tower UI story | With a fake resolver, the chip's disc is TAP 300, radius 40, at (x, y − 76) while open and unregistered on close; taps reach `ChipWindow`; a built slot is disabled; `slot_tapped` fires; `phase_changed` closes the chip |
| Arc, result | Battle HUD stories | A disc builds once; an unaffordable one does nothing; a double tap on a slot dismisses; damage by source and Slowed are shown; screenshots retained |
| Phone test (Input P1) | Producer | Under the Pillar 4 protocol, no accidental upgrades or wrong discs on the first phone build |

**Manual** (retained in `production/qa/evidence/`):
- Before and after screenshots show the 60% inset on the first frame after an upgrade.
- 5 of 5 viewers name the higher level of two towers from a screenshot, with no digit.
- Triangle, hexagon, square and an empty slot are each named correctly by 5 of 5 viewers, at full and quarter scale, in greyscale, with art-director sign-off.
- One screenshot each: arc open, arc with an unaffordable disc, chip open, chip dimmed, range ring, and a tower's Ready and Cooling rings.

**Checked by code review, not tests:** no sell command (Rule 4); TowerInput changes state only through `upgrade`; the bonus reads no burst state; `tower_dps` has no code.

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Calling early is nearly free for a hero bot, though the concept promises a cost (Hero GDD, Open Questions) | qa-lead + Hero GDD | First playable |
| Do human results land between pinned once and driven? All numbers here are one scripted simulation, not game code, with slot order fixed by hand | qa-lead | First playable |
| Is one mix the solved build? All four tested mixes tie on the mid-skill bot, and no fixed bot can tell | Bots + playtest | First playable |
| Is the early-call bonus noticed at 1.8 s per gold? It pays 40 gold at most, below any tower's price on its own | Playtest | First playable |
| Does a wrong disc happen often enough to need undo? | Pillar 4 phone test | First phone build |
| Should only the chip's own disc commit, which would remove the same-tower commit and the 200 ms guard? | Pillar 4 phone test | First phone build |
| Does a wrong plan that surfaces at wave 6 feel fair without selling? | Playtest | First playable |
| Does the hexagon read apart from the square at quarter scale? | art-director | First render |
| Are 3 px insets enough to rank levels on a phone? The fallback is 4 px | art-director | First phone build |
| Closed: ADR-0010 decides the TowerSim and TowerInput split (Decisions 1 and 8), and ADR-0006 Decision 4 types `tower_id` as `StringName`. Both ADRs are Proposed until accepted | technical-director | ADR acceptance, before TowerInput stories |
