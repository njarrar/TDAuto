# Combat & Damage

> **Status**: Designed (pending independent review)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (share is a lower bound with burst reported separately, splash gate, burst visual owner, kill-attribution test). User kept the invulnerable hero and instant hits; concept reworded.
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-02
> **Last Verified**: 2026-11-02
> **Implements Pillar**: Pillar 2 (One Hero, Not an Army: hero share is measured here); Pillar 1 (hits and slows must be visible)

## Summary

The one path for all damage: attackers name a victim, an amount and a dealer, and Combat applies it, marks the dead, applies slows and counts who dealt what. Players feel instant, readable hits; the design feels an honest hero share, because overkill and dead targets cannot inflate it. It owns no targeting decisions, timers or enemy list, and the hero cannot be hurt at MVP.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `None`

## Overview

Combat & Damage is where a hit becomes lost health. Towers and the hero decide whom to attack; they hand Combat the victim, the amount and who dealt it, and Combat applies the damage, marks the enemy dead at 0 health, applies slows and records who dealt what. Players feel it as immediate, readable hits: a thin cyan line and a flash for a tower, a heavier white-gold one for the hero. It exists so that there is one path for all damage, which is what makes the hero's share of damage (Pillar 2's 25–30% target, still unproven) an honest number. It is deliberately small: it owns no targeting, range, attack timers, gold, lives or enemy list. The hero cannot be hurt at MVP, as in the prototype that tested well: leaks and lives carry the stakes.

## Detailed Design

### Core Rules

**Three pieces.** The systems index asked for four to avoid a god object. A ProjectileSpawner is cut, because every hit is instant and nothing flies. Attackers enumerate victims at fire time, so adding projectiles later would change them too; that cost is accepted. The technical director has yet to confirm this.

| Piece | Holds |
|---|---|
| DamageEvent | `target`, `amount`, `source_kind` (TOWER, HERO or BURST), `source_id` (the dealer's definition ID). These name the dealer only; a future modifier's grantor gets its own field |
| Health | One per enemy: current HP, seeded once from `max_hp` at spawn |
| Status | One per enemy: one slow slot, with strength and whole ticks left |

**Rules.**

1. **All hits are instant.** A tower's or hero's attack resolves when it fires, with no travel, no miss and no lost target. A burst resolves when it releases, with victims computed then from current positions, so a telegraphed burst can land on no one. A fading line shows each attack. Chaining later needs no projectiles: each jump is another instant hit.
2. **One path, inside the tick.** Every point of damage enters through `deliver(event)`, one event per victim, which returns the amount applied, and `deliver` never runs outside a tick. A burst commanded between ticks releases in the Hero-and-burst slot, or it could leave a corpse that moves and leaks before the reap. Nothing else may change HP, so the counters cannot be bypassed.
3. **Real damage only.** `deliver` applies at most the HP remaining, and only that counts, so overkill cannot inflate hero share. A negative or non-finite amount applies 0 with a development error.
4. **Death is immediate.** An enemy is dead the moment HP reaches 0. A dead enemy cannot be targeted or damaged: a later hit in the same tick changes nothing, emits nothing and counts nothing. Enemy & Wave's reap step removes the corpse and emits `enemy_killed(bounty)` once. An enemy that leaks leaves the roster in the leak step, and is never a target or victim after that.
5. **Counters.** `dealt[source_id]` adds the damage applied, with its kind kept beside it, so towers, hero, burst and each tower type can all be reported. Counters stay readable after the outcome until the battle is destroyed. Damage from a tower the hero buffs counts as that tower's (concept, Pillar 2).
6. **Splash and burst.** Everyone within the radius of the impact point takes full damage, with no falloff and no cap, since falloff cannot be read at phone scale. A tower's impact point is its target's position at fire time, and the target is included once; a burst's is its aim point. Each victim is one event. A radius alone cannot protect the burst, because splash repeats while the burst waits on its cooldown, so the Tower GDD sets a measurable gate. It is not a total over the same cooldown, since towers must out-total a burst there or the wave is lost: it compares one burst against one splash shot, and measures in bots whether splash takes the burst's share (Tower System, Formulas; Pillar 2).
7. **Slow.** One slot per enemy; slows do not stack. A stronger slow replaces the current one. An equal one keeps the longer time remaining. A weaker one is ignored. A slow on a dead enemy does nothing. Strength is the fraction of speed removed, so 0.4 removes 40%. Time is held in whole ticks, because repeated float subtraction can add a move (a 0.5 s slow at 1/60 counted 31 moves rather than 30).
8. **Slow is not a stat.** It does not go through the stat accessor, which answers a Data & Config Open Question: the resolver is pure, and a slow is per-instance countdown state. Enemy & Wave reads `move_speed` through the accessor at use time, then multiplies by Combat's `speed_factor(enemy)`.
9. **No catalogue.** Combat reads no data. Callers read through the stat accessor and pass values in, so Combat depends on nothing and needs only plain fixtures to test. The one value kept from spawn is HP: `max_hp` seeds Health once, an exception to Data & Config's "never cache at spawn", because current HP is state.
10. **Targeting helpers.** Combat exposes `hp_left(enemy)` for read-only previews, and owns three pure helpers over a list the caller passes, with ranges passed in: `first_in` (furthest along the path), `nearest_in` (nearest to the attacker) and `all_in_radius` (every victim of a splash or burst). They compare exact values, break ties by lowest `spawn_id`, scan rather than sort, and skip the dead. Attackers re-pick on every attack and hold no target, so no reference can dangle. Policies are fixed, with no upgrade or UI at MVP (Pillar 4): towers use first along the path, a slow tower prefers the first unslowed enemy so it does not waste slow on a slowed leader, and the hero uses nearest to itself. The hero stands at its pin, so its target must be inside the leash and nothing else; the prototype skipped the leash check, which let the hero hit far past it.
11. **Tick order.** Flow, then Enemy & Wave (spawn, move, leak), Status countdown (the battle's tick passes it Enemy & Wave's roster), Towers by slot index, Hero then burst, then Enemy & Wave's reap (kills, then clear checks). Leaks resolve before fire, as in the prototype, so an enemy reaching the end leaks even if a tower could have killed it that tick, a fatal leak skips the rest of the tick and pays no bounty, and a slow first affects the next tick's move. Enemy & Wave confirms this.
12. **Views listen, combat does not wait.** `attack_fired(source_kind, source_id, origin, impact, radius)` draws lines and rings, even for a zero-damage slow attack. `damage_applied(event, applied, position)` draws flashes. An attacker calls `report_attack` with those same five arguments, and it only emits `attack_fired`. Both signals carry copied positions, because a killed target is reaped before its flash is drawn. Both are on Flow's view allowlist, and nothing in gameplay depends on them. At MVP a small Combat view draws them; Visual Feedback & VFX takes it over at Vertical Slice.

**Not owned.** Who attacks whom and when: range, attack timers, burst cooldown and telegraph belong to Tower and Hero. Also the enemy roster, movement, gold, lives, and stat reads.

**Handed to owning GDDs.**
- **Tower:** sets the splash-versus-burst gate (Rule 6, set), fires by slot index, holds range and timers, and passes role values in.
- **Hero:** has no HP at MVP (user decision). Owns the burst's visual at MVP, the expanding gold ring of art bible §2, since it is the payoff, and it has no row in the table above. Reports `dealt_burst` separately in bot baselines. Needs no attack range field, since the leash is its whole reach. Runs its burst's telegraph in its tick slot and releases there. Counts bursts that hit 3 or more enemies.
- **Enemy & Wave:** battle-wide unique `spawn_id`, one position per enemy per tick (cached, because walking the path is the costly part), removing a leaked enemy at once, stopping its leak loop once a fatal leak ends the stage, the reap step, `enemy_killed`, and whether splitter children inherit a slow (Vertical Slice).

**Deliberately not built for MVP.** Projectiles, damage types, armour, resist, falloff, splash caps, hero health, enemy attacks, damage numbers, critical hits, stacking status effects and targeting options.

→ Becomes an ADR: whether a future spawner sits behind `deliver`, and how Health and Status attach to an enemy instance.

### States and Transitions

| Enemy health state | Meaning | Transitions |
|---|---|---|
| Alive | HP above 0; targetable and damageable | `deliver` reaching 0 → Dead |
| Dead | HP 0; not targetable; hits do nothing | Reap removes it |

| Slow slot | Transitions |
|---|---|
| Empty | Any slow → Active |
| Active | Stronger → replaced. Equal → longer time remaining. Weaker → unchanged. Time left reaches 0 → Empty |

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Tower System | calls | `deliver`, `apply_slow`, `report_attack`, targeting helpers | Combat (API); Tower (when, whom, values) |
| Hero System | calls | `deliver` for attacks and burst, targeting helper | Combat (API); Hero (when, whom, values) |
| Enemy & Wave | calls | Creates Health and Status at spawn; reads `speed_factor`, `is_dead` | Combat (state); Enemy & Wave (roster, reap) |
| Game State & Stage Flow | builds, reads | Builds it, ticks Status in order with Enemy & Wave's roster, reads counters for the result | Flow (order, result) |
| Combat view, then Visual Feedback & VFX | listens | `attack_fired`, `damage_applied` | Views |

## Formulas

The **applied** formula is defined as:

`applied = min(amount, hp)`, then `hp = hp − applied`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `amount` | float | 0–1,000,000 | data file via the caller | Damage offered |
| `hp` | float | 0–1,000,000 | calculated, seeded from `max_hp` | Current health |
| `applied` | float | 0–1,000,000 | calculated | Damage actually dealt and counted |

**Output Range:** 0 for a dead enemy or zero damage, up to `hp`. HP can never go negative.
**Example:** 30 on 12 HP applies 12, leaving 0, so the enemy is dead.

The **hero_share** formula is defined as:

`hero_share = (dealt_hero + dealt_burst) / dealt_total`, where `dealt_total` is the sum of the kind sums, and 0 when that is 0

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `dealt_hero`, `dealt_burst` | float | 0 and up | calculated | Sums of `applied` by source kind |
| `dealt_total` | float | 0 and up | calculated | `dealt_tower + dealt_hero + dealt_burst`, so rounding cannot push share above 1 |

**Output Range:** 0–1. Target 0.25–0.30, unproven: no human data exists, and the prototype's 39% came from one tower type and a bug (see Open Questions). Read it as a lower bound, because towers resolve first and a burst finishing softened enemies is credited only with what it dealt. The combined figure can reach 30% with almost no burst, so it cannot show that the hero keeps the spike: bot baselines report `dealt_burst` separately.
**Example:** 200 hero + 100 burst of 1,000 total = 0.30.

The **speed_factor** formula is defined as:

`speed_factor = 1 − slow_strength`, or 1 with an empty slot; `speed = move_speed × speed_factor`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `slow_strength` | float | above 0, below 1 | data file via the caller | Fraction of speed removed |
| `move_speed` | float, units/s | above 0, up to 2,000 | data file via the accessor | Enemy & Wave reads it at use time |

**Output Range:** above 0 and up to 1, so a slow can never become a stun.
**Example:** speed 60, strength 0.4: factor 0.6, speed 36.

The **in_radius** formula is defined as:

`in_radius = dx² + dy² ≤ radius²`, from the impact point

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `dx`, `dy` | float | any in the field | calculated | Enemy position minus impact point |
| `radius` | float, field units | above 0, up to 2,000 | data file via the caller | Splash or burst radius |

**Output Range:** true or false, inclusive, so an enemy exactly on the edge is hit and a primary target at distance 0 always is.
**Example:** radius 50, enemy at (30, 40): 2,500 ≤ 2,500, a hit.

A slow of duration `d` is stored as `to_ticks(d)` whole ticks (Enemy & Wave Formulas; `ceil` came out a tick high at 4.15, 8.05 and 8.3 s), and affects that many moves, because it first applies on the next tick and counts down after each move. `slow_duration` has a floor of one tick (Data & Config).

## Edge Cases

- **If splash hits an enemy already killed earlier this tick**: nothing happens and nothing counts.
- **If `amount` is 0**: `applied` is 0, HP is unchanged and no `damage_applied` fires. A slow tower with 0 damage still applies its slow, and `attack_fired` still draws its line.
- **If `deliver` names a removed enemy**: unreachable at MVP, since attackers hold no target across ticks; the guard still logs a development error and changes nothing.
- **If two towers would finish the same enemy on one tick**: the lower slot index gets the kill and the real damage; the other picks another target, since dead enemies are skipped.
- **If a tower and the hero contest a kill**: the tower resolves first and wins it, which slightly lowers hero share. The order is fixed so bots stay comparable.
- **If a stronger slow arrives with less time than the current one**: it replaces it entirely.
- **If a burst lands on no enemy**: no events, no counters, though `attack_fired` still draws its ring. Hero owns whether the cooldown is spent.
- **If a burst is commanded between ticks**: it releases in the Hero-and-burst slot when its telegraph ends, at least one tick later, with victims computed then.
- **If more enemies are hit than there are flash markers (16)**: the oldest flash is dropped; damage is unaffected.
- **If a pause or cancel lands mid-slow**: the clock stops, so the slow simply waits. Slows cannot stick.
- **If enemies spawn on one tick**: `spawn_id` is battle-wide and assigned in group order, so ties stay deterministic.
- **If an enemy is killed in the tick it would have leaked**: impossible under the tick order, since leaks resolve first.
- **If a fatal leak ends the stage**: the rest of the tick is skipped (Flow Rule 15), so nothing fires and no bounty is paid.
- **If `dealt_total` is 0 at the outcome**: share is 0 and the result reads as no damage dealt.
- **If two enemies tie on path distance**: the lowest `spawn_id` wins, in every helper.
- **If floats differ between x86 and ARM**: results may too (unverified), so bot baselines are kept per architecture.

## Dependencies

**Upstream:** none. Combat reads no data, which corrects the systems index (callers read and pass values in).

**Downstream (hard):**

| System | Interface |
|---|---|
| Tower System | `deliver`, `apply_slow`, `report_attack`, helpers |
| Hero System | `deliver`, helpers |
| Enemy & Wave | Health, Status, `speed_factor`, reap, `spawn_id` |
| Game State & Stage Flow | Tick order, counters for the result |
| Battle HUD, Visual Feedback & VFX (VS) | `damage_applied` |
| Stage Progression & Stars (VS) | Counters (soft) |

Per the bidirectional rule, each of these GDDs must list this one when authored. Game State and Enemy & Wave already do.

## Visual/Audio Requirements

The MVP minimum, drawn with primitives from one `_draw()` per kind, with no shaders or particles. All values are unverified on a device.

| Event | Visual | Art bible principle |
|---|---|---|
| Any hit | White disc over the body for 80 ms; a retrigger restarts it. Hero hits at alpha 1.0, tower hits about 0.6, so towers never outshine the hero | §1 Role by primitive |
| Tower fires | Cyan 2 px segment, 100 ms fade, no glow | §1, §2 Combat |
| Hero fires | White-gold 3 px line from the tip, with tip recoil | §1, §5 |
| Tower splash | Static cyan 2 px unfilled ring at the true radius, 100 ms; it never expands, so it cannot read as a burst | §1 Zones are drawn |
| Slow | Two drag lines, 15% wobble, violet tint | §2 state set |
| Damaged | Dark core from 0 to 60% of radius, enemies of 22 px or more only | §2 state set, §5 LOD |
| Death | White disc shrinking to zero, 120 ms | §1 |

**Telling towers from the hero.** The line's origin (polygon or kite) reads first, then width and flash strength, which all survive greyscale. Hue only reinforces.

**Feature budget.** A flash is transient and does not count. Under 22 px: flash and slow only. Slowed and damaged together: slow shows and the core hides.

**Burst clearance (about 0.4 s).** Tower flashes and splash rings are suppressed, with no other gold, glow or expanding ring, so the burst stays the brightest thing on screen (Pillar 2).

Audio: none at MVP. Sound is often off, so nothing here depends on it.

**Deferred:** death particles, damage numbers, screen shake.

## Game Feel

Every hit lands the moment it fires, so a tower's rhythm reads as the machine working and the hero's heavier line reads as a person acting. The flash appears on the first frame after the hit. Nothing here waits on a view, and no view can change a result. All timings are starting points for the first phone test.

## UI Requirements

None. The HUD shows the counters as plain text at stage end, as Towers, Hero and Burst, with no percentage, because hero share is a balance metric rather than a goal. The human log keeps the share (Battle HUD Rule 15).

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Hero share metric, target, hero-only must fail | `design/gdd/game-concept.md` | Pillar 2 | Rule dependency |
| Four pieces, source field, hit flashes here | `design/gdd/systems-index.md` | Core Layer TD note | Amended here |
| Slow strength domain, never cache, dealer vs grantor | `design/gdd/data-config-pipeline.md` | Field domains; Rule 10; Not owned | Rule dependency; exception stated |
| Fixed tick, no timers, mid-tick outcome, tick order | `design/gdd/game-state-stage-flow.md` | Rules 4, 5, 14, 15 | Rule dependency |
| Hit flash, tracer, state set, feature budget, pools | `design/art/art-bible.md` | §1, §2, §3, §5, §8 | Value dependency; amended |
| Negative-damage bug, hit model evidence | `prototypes/hero-pin-concept/main.gd` | `_hit`, `_step` | Evidence |

## Acceptance Criteria

A recording fake logs `attack_fired` and `damage_applied`, and each THEN is the entire log. Fixtures come from factories, with no scene and no catalogue, since Combat reads no data. After every test the invariant `I` is checked: the sum of logged `applied` equals the sum of counters equals the sum of `max_hp − hp`. A direct HP write must fail `I`; this was watched failing once, with the output kept. No time assertions.

**CI: Logic**
1. (Rules 1–3) **GIVEN** HP 12, **WHEN** `deliver` 30, **THEN** `applied(12)`, HP 0, dead, counter 12.
2. (Applied) **GIVEN** HP 12, **WHEN** 12, **THEN** dead; 11.5, alive at 0.5; 0, an empty log, and a slow still applies. **WHEN** −5 or NaN, **THEN** an empty log, HP unchanged.
3. (Rule 4) **GIVEN** a dead enemy, **WHEN** `deliver` or a slow, **THEN** an empty log, with counters and factor unchanged.
4. (Rule 5, share) **GIVEN** no hits, **THEN** share 0. **WHEN** 700 tower, 200 hero, 100 burst, **THEN** exact by id and kind, share 0.30.
5. (in_radius) **GIVEN** radius 50 from (0, 0), **THEN** (30, 40) and (0, 0) hit; (30, 40.5) misses.
6. (Rule 6) **GIVEN** a target, an edge enemy, an outsider and a corpse, **WHEN** a splash of 10 through `all_in_radius`, **THEN** two events, each applying 10.
7. (Rule 7) **GIVEN** a slot of strength 0.5 and 1.0 s, **WHEN** 0.75 for 0.25 s, **THEN** replaced; 0.5 for 0.5 s keeps 1.0; 0.5 for 2.0 gives 2.0; 0.25 for 8.0 is ignored.
8. (speed_factor) **GIVEN** an empty slot, **THEN** 1; **WHEN** 0.25, **THEN** 0.75; 0.4 gives 0.6; 1 − 2⁻⁵³ stays above 0.
9. (Duration) **GIVEN** `dt` 0.25, **WHEN** read then count down, **THEN** a 1.0 s slow affects 4 reads and 0.625 s affects 3. **GIVEN** `dt` 1/60 and 0.5 s, **THEN** exactly 30 reads.
10. (Rule 10) **GIVEN** each helper, **THEN** no epsilon; ties give the lowest `spawn_id` in any input order; the dead are skipped; all-dead gives none; the input list is unmodified.
11. (Rule 10) **GIVEN** hero at pin (0, 0), leash 90, **THEN** (90, 0) is in, (90.5, 0) is out, and the nearest is chosen. **GIVEN** a slow tower with a slowed leader and an unslowed follower in range, **THEN** the follower; with all slowed, **THEN** the leader.
12. (Rule 12) **GIVEN** one script, **WHEN** run with and without a listener, **THEN** identical state. **GIVEN** a zero-damage attack, **THEN** `attack_fired` only. **GIVEN** a killed target, **THEN** `damage_applied` carries its position.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner | Passes when |
|---|---|---|
| Bypass (Rule 2) | Tower, Hero stories | `I` holds over a real stage |
| Order (Rules 2, 4, 11) | Enemy & Wave stories | Leaks resolve before fire; a fatal leak pays nothing; `enemy_killed` fires once; a burst commanded between ticks leaves no moving corpse |
| Pillar 2 bots | Hero stories | Hero-only fails; never-pinned is identical to towers-only; pinned-once loses to active play by a margin set at the first baseline; the always-call bot does not beat a driven hero |
| Damage shown | Battle HUD stories | Won and Lost show Towers, Hero and Burst, matching the counters, with no percentage; retained screenshot |
| Splash vs burst gate (Rule 6) | Tower, Hero stories | `burst_spike` is at least 2 in the content test, and `dealt_burst`'s share with splash is at least 75% of its share with none |

**Manual** (frame-stepped screenshots retained in `production/qa/evidence/`): tower and hero hits distinct in greyscale; static splash ring at its true radius; slow drag lines; damaged core at 22 px and above; burst clearance, with no tower flash or ring. On the first phone build, a non-developer identifies hero kills from tower kills with sound off. This proves the hits are legible, not that they are satisfying, which only playtests can judge.

**Checked by code review, not tests:** slow stays out of the accessor (Rule 8), Combat reads no data (Rule 9).

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Does the technical director accept cutting ProjectileSpawner and the tick order? Both override existing notes | technical-director | App Lifecycle ADR |
| What is the hero's real share? The prototype's 39% had one tower type, bot-fitted values and a bug that could credit negative damage, by an unmeasured amount. Re-run once all three tower roles exist | qa-lead | First playable |
| Does uncapped splash, sharpened by slow clumping enemies, erode the burst's spike? Gate set in the Tower GDD; first simulated with a pass | Tower GDD + bots | First playable |
| Instant hits leave weapon upgrades a thin 100 ms line to show growth on (Pillar 1). What makes them visible? | Weapons GDD (Vertical Slice) | Vertical Slice |
| Do full-strength hero flashes during a burst hold up on a device, and does the 0.6 tower flash read? | art-director | First phone build |
| Art bible §8 budgets a hit-flash shader while saying zero shaders; this spec uses none | technical-artist | First phone build |
| Is the 400-check targeting worst case fine on a low-end phone? Estimated under 2 ms, unmeasured | performance-analyst | First phone build |
