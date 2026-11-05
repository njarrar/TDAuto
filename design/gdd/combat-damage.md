# Combat & Damage

> **Status**: Approved (fourth design review 2026-11-03, lean: APPROVED; its recommended items applied afterwards) Cross-GDD text reconciliation later the same day changed no rule or value and kept this status; see the review log.
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-02 — CONCERNS applied (share is a lower bound with burst reported separately, splash gate, burst visual owner, kill-attribution test; the lower-bound wording was retracted in the 2026-11-03 review). User kept the invulnerable hero and instant hits; concept reworded.
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 2 (One Hero, Not an Army: hero share is measured here); Pillar 1 (hits and slows must be visible)

## Summary

The one path for all damage: attackers name a victim, an amount and a dealer, and Combat applies it, marks the dead, applies slows and counts who dealt what. Players feel instant, readable hits; the design feels an honest hero share, because overkill and dead targets cannot inflate it. It owns no targeting decisions, timers or enemy list, and the hero cannot be hurt at MVP.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `to_ticks`; the Combat view also listens to Hero's `burst_started`

## Overview

Combat & Damage is where a hit becomes lost health. Towers and the hero decide whom to attack; they hand Combat the victim, the amount and who dealt it, and Combat applies the damage, marks the enemy dead at 0 health, applies slows and records who dealt what. Players feel it as immediate, readable hits: a thin cyan line and a flash for a tower, a heavier white-gold one for the hero. It exists so that there is one path for all damage, which is what makes the hero's share of damage (Pillar 2's 25–30% target, still unproven) an honest number. It is deliberately small: it owns no targeting, range, attack timers, gold, lives or enemy list. The hero cannot be hurt at MVP, as in the prototype that tested well: leaks and lives carry the stakes.

## Detailed Design

### Core Rules

**Three pieces.** The systems index asked for four to avoid a god object. A ProjectileSpawner is cut, because every hit is instant and nothing flies. Attackers enumerate victims at fire time, so adding projectiles later would change them too; that cost is accepted. The technical director has yet to confirm this.

| Piece | Holds |
|---|---|
| DamageEvent | `target`, `amount`, `source_kind` (TOWER, HERO or BURST), `source_id` (the dealer's definition ID, a `StringName` everywhere). These name the dealer only; a future modifier's grantor gets its own field |
| Health | One per enemy: current HP, seeded once from `max_hp` at spawn |
| Status | One per enemy: one slow slot, with strength and whole ticks left |

**What Combat sees of an enemy.** Enemy & Wave's enemy exposes `spawn_id` (int, battle-wide, never reused), `distance` (float, along the path) and `position` (Vector2, world units, y down), both cached once per tick, and `removed` (bool), true once it has left the roster by leak or reap. A removed enemy stays a valid reference while anything holds it, so the guard in Rule 3 can read it; the ADR's object kind must allow that. Combat adds its Health and Status. How they attach, and what kind of object Combat is, belong to the ADR below; every signature here takes that same `enemy`.

**Rules.**

1. **All hits are instant.** A tower's or hero's attack resolves when it fires, with no travel, no miss and no lost target. A burst resolves when it releases, with victims computed then from current positions, so a telegraphed burst can land on no one. A fading line shows each attack. Chaining later needs no projectiles: each jump is another instant hit.
2. **One path, inside the tick.** Every point of damage enters through `deliver(event)`, one event per victim, which returns the amount applied, and `deliver` never runs outside a tick. A burst commanded between ticks releases in the Hero-and-burst slot, or it could leave a corpse that moves and leaks before the reap. Nothing else may change HP, so the counters cannot be bypassed.
3. **Real damage only.** `deliver` applies at most the HP remaining, and only that counts, so overkill cannot inflate hero share. A negative or non-finite amount applies 0 with a development error, which means `push_error` throughout this GDD, since `assert` is stripped from release builds. `deliver` returns a float: the amount applied, so 0 for a dead or removed enemy and for any amount it rejects. Naming a removed enemy is also a development error. The checks run in a fixed order, removed, then amount, then dead, and only the first failure reports, so −5 on a removed enemy reports removed alone and a valid amount on a dead enemy is silent. Each guard has one fixed message, a named constant on Combat (`ERR_REMOVED`, `ERR_BAD_AMOUNT`, `ERR_BAD_SLOW`), so a test can name it.
4. **Death is immediate.** An enemy is dead the moment HP reaches 0. A dead enemy cannot be targeted or damaged: a later hit in the same tick changes nothing, emits nothing and counts nothing. Enemy & Wave's reap step removes the corpse and emits `enemy_killed(bounty)` once. An enemy that leaks leaves the roster in the leak step, and is never a target or victim after that.
5. **Counters.** `dealt[source_id]` adds the damage applied, with its kind kept beside it, so towers, hero, burst and each tower type can all be reported. The reads are `dealt_by_id(source_id: StringName) -> float` (0 for an unknown ID), `dealt_by_kind(kind: Combat.SourceKind) -> float`, `dealt_total() -> float` and `hero_share() -> float` (Formulas). Counters stay readable after the outcome until the battle is destroyed. Damage from a tower the hero buffs counts as that tower's (concept, Pillar 2).
6. **Splash and burst.** Everyone within the radius of the impact point takes full damage, with no falloff and no cap, since falloff cannot be read at phone scale. A tower's impact point is its target's position at fire time, and the target is included once; a burst's is its aim point. Each victim is one event. A radius alone cannot protect the burst, because splash repeats while the burst waits on its cooldown, so the Tower GDD sets a measurable gate. It is not a total over the same cooldown, since towers must out-total a burst there or the wave is lost: it compares one burst against one splash shot, and measures in bots whether splash takes the burst's share (Tower System, Formulas; Pillar 2).
7. **Slow.** One slot per enemy; slows do not stack. A stronger slow replaces the current one. An equal one keeps the longer time remaining. A weaker one is ignored. A slow on a dead enemy does nothing. Strength is the fraction of speed removed, so 0.4 removes 40%. Time is held in whole ticks, because repeated float subtraction can add a move (a 0.5 s slow at 1/60 counted 31 moves rather than 30). The call is `apply_slow(enemy, strength, seconds)`, which returns nothing, and Combat converts the seconds. A strength not strictly between 0 and 1, or seconds that are non-finite or not above 0, change nothing, with a development error; the data rules should already prevent both, so this guards caller bugs. A removed enemy also changes nothing, with `ERR_REMOVED`, and the checks run in Rule 3's order: removed, then values, then dead. An attacker delivers its damage first, so a slow never lands on an enemy that hit killed. Strengths are authored values compared exactly, never computed.
8. **Slow is not a stat.** It does not go through the stat accessor, which answers a Data & Config Open Question: the resolver is pure, and a slow is per-instance countdown state. Enemy & Wave reads `move_speed` through the accessor at use time, then multiplies by Combat's `speed_factor(enemy)`.
9. **No catalogue.** Combat reads no data. Callers read through the stat accessor and pass values in, so Combat depends on no catalogue and needs only plain fixtures to test. Its one outside need is `to_ticks` (Flow Rule 4; Enemy & Wave Formulas), a pure conversion, with the fixed `dt` given at build. The one value kept from spawn is HP: `max_hp` seeds Health once, an exception to Data & Config's "never cache at spawn", because current HP is state.
10. **Targeting helpers.** Combat exposes `hp_left(enemy) -> float` for read-only previews, and `is_dead(enemy) -> bool`, true when HP is at or below 0, which stays answerable after the reap (a leaked enemy is removed but not dead). It owns three pure helpers over a list the caller passes:

   | Helper | Returns |
   |---|---|
   | `first_in(list, origin, max_range)` | The enemy with the greatest `distance`, among those in range; null if none |
   | `nearest_in(list, origin, max_range)` | The enemy with the smallest squared distance to `origin`, among those in range; null if none |
   | `all_in_radius(list, impact, radius)` | Every enemy in range of `impact`, in input order; empty if none. Callers pass `spawn_id` order (`targets()` is, Enemy & Wave Rule 14), so events run in ascending `spawn_id`. A primary target is in this list and gets no separate event |

   In range is the **in_radius** test against an enemy's cached `position`, with `max_range` as the radius (`range` would shadow GDScript's global function), applied before any ranking, so a further-along enemy out of range never wins. The helpers compare exact values, break ties by lowest `spawn_id`, scan rather than sort, and skip the dead through `is_dead`. Attackers re-pick on every attack and hold no target, so no reference can dangle. Policies are fixed, with no upgrade or UI at MVP (Pillar 4): towers use first along the path, a slow tower prefers the first unslowed enemy so it does not waste slow on a slowed leader (the caller filters on `speed_factor` exactly 1, then falls back to all, Tower Rule 9), and the hero uses nearest to itself. The hero stands at its pin, so its target must be inside the leash and nothing else; the prototype skipped the leash check, which let the hero hit far past it.
11. **Tick order.** Flow, then Enemy & Wave (spawn, move, leak), Status countdown (`tick_status(roster: Array) -> void`; the battle's tick passes Enemy & Wave's roster), Towers by slot index, Hero then burst, then Enemy & Wave's reap (kills, then clear checks). Leaks resolve before fire, as in the prototype, so an enemy reaching the end leaks even if a tower could have killed it that tick, a fatal leak skips the rest of the tick and pays no bounty, and a slow first affects the next tick's move. Enemy & Wave confirms this. `tick_status` takes 1 from every slow in the list and empties any slot at or below 0, for a dead enemy too, which is harmless; removed enemies never reach it (Enemy & Wave Rule 14). It emits nothing.
12. **Views listen, combat does not wait.** `attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)` draws lines and rings, even for a zero-damage slow attack; `radius` is 0 for a single-target attack. `damage_applied(event: DamageEvent, applied: float, position: Vector2, killed: bool, spawn_id: int)` draws flashes and the death disc. An attacker calls `report_attack` with `attack_fired`'s five arguments, and it only emits `attack_fired`. `damage_applied` fires after HP, the dead state and the counters are committed, so `killed` reads committed state, and no listener may call `deliver`. Both signals carry copied positions, because a killed target is reaped before its flash is drawn, so views use `position` and `spawn_id`, and never `event.target`. Both are on Flow's view allowlist, and nothing in gameplay depends on them. At MVP a small Combat view draws them; Visual Feedback & VFX takes it over at Vertical Slice.

**Not owned.** Who attacks whom and when: range, attack timers, burst cooldown and telegraph belong to Tower and Hero. Also the enemy roster, movement, gold, lives, and stat reads.

**Handed to owning GDDs.**
- **Tower:** sets the splash-versus-burst gate (Rule 6, set), fires by slot index, holds range and timers, and passes role values in.
- **Hero:** has no HP at MVP (user decision). Owns the burst's visual at MVP, the expanding gold ring of art bible §2, since it is the payoff, and it has no row in the table above. Reports `dealt_burst` separately in bot baselines. Needs no attack range field, since the leash is its whole reach. Runs its burst's telegraph in its tick slot and releases there. Counts bursts that hit 3 or more enemies.
- **Enemy & Wave:** battle-wide unique `spawn_id`, one position per enemy per tick (cached, because walking the path is the costly part), removing a leaked enemy at once, stopping its leak loop once a fatal leak ends the stage, the reap step, `enemy_killed`, and whether splitter children inherit a slow (Vertical Slice).

**Deliberately not built for MVP.** Projectiles, damage types, armour, resist, falloff, splash caps, hero health, enemy attacks, damage numbers, critical hits, stacking status effects and targeting options.

→ Becomes an ADR: whether a future spawner sits behind `deliver`, and how Health and Status attach to an enemy instance, what call registers them at spawn (with its `max_hp` guard), the enemy's object kind (including that a node's `position` would collide with the cached one, and that a freed enemy could not honour `removed`), ownership and reference cycles, the typing of the helpers' `list`, where `SourceKind` and `DamageEvent` are declared, and Combat's object kind and owner.

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
| Tower System | calls | `deliver`, `apply_slow`, `report_attack`, `speed_factor`, targeting helpers | Combat (API); Tower (when, whom, values) |
| Hero System | calls | `deliver` for attacks and burst, `report_attack`, `nearest_in`, `all_in_radius`, `hp_left`, `is_dead` | Combat (API); Hero (when, whom, values) |
| Enemy & Wave | calls | Creates Health and Status at spawn; reads `speed_factor`, `is_dead`; sets `removed` | Combat (state); Enemy & Wave (roster, reap) |
| Game State & Stage Flow | builds, reads | Builds it, calls `tick_status` in order with Enemy & Wave's roster, reads counters for the result | Flow (order, result) |
| Battle HUD | reads | Counters, once at the outcome | Combat (counters); HUD (display) |
| Combat view, then Visual Feedback & VFX | listens | `attack_fired`, `damage_applied`; Hero's `burst_started` for clearance | Views |

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

**Output Range:** 0–1. Target 0.25–0.30, unproven: no human data exists, and the prototype's 39% came from one tower type and a bug (see Open Questions). Read it as approximate, in no proven direction: credit follows HP applied, towers waste overkill too, and damage from a tower the hero buffs is not the hero's (Rule 5). The combined figure can reach 30% with almost no burst, so it cannot show that the hero keeps the spike: bot baselines report `dealt_burst` separately.
**Example:** 200 hero + 100 burst of 1,000 total = 0.30.

The **speed_factor** formula is defined as:

`speed_factor = 1 − slow_strength`, or 1 with an empty slot; `speed = move_speed × speed_factor`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `slow_strength` | float | above 0, below 1 | data file via the caller | Fraction of speed removed |
| `move_speed` | float, units/s | above 0, up to 2,000 | data file via the accessor | Enemy & Wave reads it at use time |

**Output Range:** above 0 and up to 1, so no slow stops an enemy by rule. A strength near 1 would in practice, so Tower's content test caps `slow_strength` at 0.6.
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

A slow of duration `d` is stored as `max(1, to_ticks(d))` whole ticks (Enemy & Wave Formulas; `ceil` came out a tick high at 4.15, 8.05 and 8.3 s), and affects that many moves, because it first applies on the next tick and counts down after each move. The slot empties when the count is at or below 0. `slow_duration` has a floor of `MIN_INTERVAL`, 1/30 s (Data & Config), which is 1 tick at 30 per second and 2 at 60; the `max` covers a fixture with a coarser `dt`.

## Edge Cases

- **If splash hits an enemy already killed earlier this tick**: nothing happens and nothing counts.
- **If `amount` is 0**: `applied` is 0, HP is unchanged and no `damage_applied` fires. A slow tower with 0 damage still applies its slow, and `attack_fired` still draws its line.
- **If `deliver` names a removed enemy**: unreachable at MVP, since attackers hold no target across ticks; the guard still logs a development error and changes nothing.
- **If two towers would finish the same enemy on one tick**: the lower slot index fires first. If its hit kills, the other picks another target, since dead enemies are skipped; if not, both hit and Rule 3 caps the second. Combat credits damage and keeps no kill counter.
- **If a tower and the hero contest a kill**: the tower resolves first and deals what it can. If that kills, the hero picks another target; if not, the hero hits too. The order is fixed so bots stay comparable.
- **If a stronger slow arrives with less time than the current one**: it replaces it entirely.
- **If a burst lands on no enemy**: no events, no counters, though `attack_fired` still draws its ring. Hero owns whether the cooldown is spent.
- **If a burst is commanded between ticks**: it releases in the Hero-and-burst slot when its telegraph ends, at least one tick later, with victims computed then.
- **If more enemies are hit than there are flash markers (16)**: the oldest tower flash is dropped, then the oldest hero flash, so hero and burst hits survive longest; damage is unaffected. BURST ranks as hero, oldest means least recently triggered, a tower flash never evicts a hero flash and is dropped itself, and a flash suppressed by clearance takes no marker.
- **If a pause or cancel lands mid-slow**: the clock stops, so the slow simply waits. Slows cannot stick.
- **If enemies spawn on one tick**: `spawn_id` is battle-wide and assigned in group order, so ties stay deterministic.
- **If an enemy is killed in the tick it would have leaked**: impossible under the tick order, since leaks resolve first.
- **If a fatal leak ends the stage**: the rest of the tick is skipped (Flow Rule 15), so nothing fires and no bounty is paid.
- **If `dealt_total` is 0 at the outcome**: share is 0 and the result reads as no damage dealt.
- **If two enemies tie on path distance**: the lowest `spawn_id` wins, in every helper.
- **If floats differ between x86 and ARM**: results may too (unverified), so bot baselines are kept per architecture.

## Dependencies

**Upstream:** `to_ticks`, a pure conversion defined in Enemy & Wave's Formulas, with no enemy state, so it makes no cycle. Combat reads no data, which corrects the systems index (callers read and pass values in). The Combat view, not Combat, also listens to Hero's `burst_started` for the clearance window.

**Downstream (hard):**

| System | Interface |
|---|---|
| Tower System | `deliver`, `apply_slow`, `report_attack`, `speed_factor`, helpers |
| Hero System | `deliver`, `report_attack`, `nearest_in`, `all_in_radius`, `hp_left`, `is_dead` |
| Enemy & Wave | Health, Status, `speed_factor`, `is_dead`, reap, `spawn_id`, `removed` |
| Game State & Stage Flow | Tick order, `tick_status`, counters for the result |
| Visual Feedback & VFX (VS) | `attack_fired`, `damage_applied` |

**Downstream (soft):** Battle HUD (counters, once at the outcome); Stage Progression & Stars at Vertical Slice (counters).

**Prerequisite:** the ADR named under Core Rules must be accepted before the first Combat story starts. It decides the enemy's object kind, how Health and Status attach, the spawn registration call, ownership and the typing of `list`, and no signature here can be written in code without them.

Per the bidirectional rule, each of these GDDs must list this one. All the MVP ones already do; the Vertical Slice ones must when authored.

## Tuning Knobs

Combat has no gameplay knobs: damage, slow strength, slow duration and radius are the callers' values (Rule 9). Its only tunables are the view's presentation constants below, which are the values used in Visual/Audio Requirements. They are named constants on the Combat view with no Data & Config record, since Combat reads no data and none of them can change a result. Safe ranges are proposed and unverified on a device.

| Constant | Value | Safe range | Affects |
|---|---|---|---|
| `FLASH_SECONDS` | 0.08 | 0.05–0.15 | Hit flash length; too long hides the body |
| `TOWER_FLASH_ALPHA` | 0.6 | 0.4–0.8 | Tower flash strength; must stay below the hero's 1.0, so towers never outshine the hero |
| `TOWER_LINE_SECONDS` | 0.10 | 0.05–0.20 | Tower line fade |
| `SPLASH_RING_SECONDS` | 0.10 | 0.05–0.20 | Splash ring length |
| `DEATH_DISC_SECONDS` | 0.12 | 0.08–0.25 | Death disc shrink |
| `FLASH_MARKER_LIMIT` | 16 | Up to art bible §8's budget | Flashes shown at once; damage is unaffected |
| `CLEARANCE_TAIL_SECONDS` | 0.15 | 0.10–0.30 | Clearance after release; the value is owned by Hero's Visual Requirements, and a change there comes here |

## Visual/Audio Requirements

The MVP minimum, drawn with primitives from one `_draw()` per kind, with no shaders or particles. All values are unverified on a device.

| Event | Visual | Art bible principle |
|---|---|---|
| Any hit | White disc over the body for 80 ms; a retrigger restarts it. Hero and burst hits at alpha 1.0, tower hits about 0.6, so towers never outshine the hero; a retrigger keeps the higher alpha | §1 Role by primitive |
| Tower fires | Cyan 2 px segment, 100 ms fade, no glow | §1, §2 Combat |
| Hero fires | White-gold 3 px line from the tip, with tip recoil | §1, §5 |
| Tower splash | Static cyan 2 px unfilled ring at the true radius, 100 ms; it never expands, so it cannot read as a burst | §1 Zones are drawn |
| Slow | Two drag lines, 15% wobble, violet tint | §2 state set |
| Damaged | Dark core from 0 to 60% of radius, enemies of 22 px or more only | §2 state set, §5 LOD |
| Death | White disc shrinking to zero, 120 ms, from `damage_applied` with `killed` | §1 |

**Telling towers from the hero.** The line's origin (polygon or kite) reads first, then width and flash strength, which all survive greyscale. Hue only reinforces.

**Feature budget.** A flash is transient and does not count. Under 22 px: flash and slow only. Slowed and damaged together: slow shows and the core hides.

**Burst clearance (about 0.4 s).** Tower flashes and splash rings are suppressed, with no other gold, glow or expanding ring, so the burst stays the brightest thing on screen (Pillar 2). The Combat view does this, from Hero's `burst_started` to 0.15 s after release (Hero, Visual Requirements). Release is the next `attack_fired` of kind BURST, which fires even for an empty burst. Tower-hit feedback is the accepted cost.

**Flash markers.** The Combat view holds one global pool of 16 (art bible §8), one marker per flashing enemy, so a retrigger reuses that enemy's marker. Death discs use none. Edge Cases gives the eviction order.

**View clocks.** Every duration here runs on the frame clock, stops on Pause and clears on retry, as Hero's do. Flash state is the view's, per enemy by `spawn_id`, and never sits in Health.

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
| `to_ticks`, `spawn_id`, `distance`, `position` | `design/gdd/enemy-wave.md` | Formulas; Rule 14 | Rule dependency |
| Clearance window, `burst_started`, burst victims | `design/gdd/hero-system.md` | Rule 16; Visual Requirements | Value dependency |
| Hit flash, tracer, state set, feature budget, pools | `design/art/art-bible.md` | §1, §2, §3, §5, §8 | Value dependency; amended |
| Negative-damage bug, hit model evidence | `prototypes/hero-pin-concept/main.gd` | `_hit`, `_step` | Evidence |

## Acceptance Criteria

A recording fake logs `attack_fired` and `damage_applied`, and each THEN is the entire log. Fixtures come from factories, with no scene and no catalogue, since Combat reads no data. After every test the invariant `I` is checked: the sum of logged `applied` equals the sum of counters equals the sum of `max_hp − hp` over every enemy the test created, reaped ones included. Damage and HP fixtures are multiples of ¼ with every sum below 2²⁰, so these sums compare exactly; share and factor criteria compare with the same literal. `I` is a callable check. Kept negative tests each tamper with one of HP, a counter and the log, call it directly and assert that it reports failure. A development error is asserted one invalid input per case, as gdUnit4's `assert_error(call).is_push_error(message)` against Rule 3's constant, and a silent case uses `is_success`. That assertion does not count, so "exactly one" relies on the project setting `gdunit4/report/godot/push_error`, off by default: with it on, each assertion clears one matching logged error and any left over fails the test, a second identical one included. This is read from gdUnit4 6.2.0's source and has not been run, so the first test story turns the setting on and keeps a negative test proving it. With it on, an unasserted `push_error` fails any test. No time assertions.

**CI: Logic**
1. (Rules 1–3) **GIVEN** HP 12, **WHEN** `deliver` 30, **THEN** `applied(12)`, HP 0, dead, counter 12.
2. (Applied) **GIVEN** HP 12, **WHEN** 12, **THEN** dead; 11.5, alive at 0.5; 0, an empty log, and a slow still applies.
   (Rule 3) **GIVEN** HP 12, **WHEN** each of −5, NaN, INF and −INF, **THEN** an empty log, HP unchanged, returns 0, `ERR_BAD_AMOUNT`.
3. (Rule 4) **GIVEN** a dead enemy, **WHEN** `deliver` or a slow, **THEN** an empty log, `deliver` returns 0, with counters and factor unchanged, and `is_success`.
4. (Rule 5, share) **GIVEN** no hits, **THEN** share 0. **WHEN** 700 tower, 200 hero, 100 burst, **THEN** `dealt_by_id`, `dealt_by_kind` and `dealt_total` are exact, `hero_share` 0.30, and an unknown ID reads 0.
5. (in_radius) **GIVEN** radius 50 from (0, 0), **THEN** (30, 40) and (0, 0) hit; (30, 40.5) misses.
6. (Rule 6) **GIVEN** a target, an edge enemy, an outsider and a corpse, **WHEN** a splash of 10 through `all_in_radius`, **THEN** two events in ascending `spawn_id`, each applying 10, and the target is hit once. **GIVEN** 17 enemies in radius, **THEN** 17 events.
7. (Rule 7) **GIVEN** `dt` 0.25, a fresh slot of strength 0.5 and 1.0 s each time, and each tick reading `speed_factor` then calling `tick_status`, **WHEN** 0.75 for 0.25 s, **THEN** one read at 0.25, then 1; 0.5 for 0.5 s gives four reads at 0.5; 0.5 for 2.0 s gives eight; 0.25 for 8.0 s gives four at 0.5. **WHEN** strength 0, 1, 1.5, −0.5 or NaN, or seconds 0, −1, NaN, INF or −INF, **THEN** four reads at 0.5, `ERR_BAD_SLOW`.
8. (speed_factor) **GIVEN** an empty slot, **THEN** 1; **WHEN** 0.25, **THEN** 0.75; 0.4 gives 0.6; strength 1 − 2⁻⁵³ gives a factor above 0.
9. (Duration) **GIVEN** `dt` 0.25, **WHEN** read then `tick_status`, **THEN** a 1.0 s slow affects 4 reads and 0.625 s affects 3. **GIVEN** `dt` 1/60 and 0.5 s, **THEN** exactly 30 reads. **GIVEN** `dt` 0.25 and 1/60 s, **THEN** 1 read, then the slot is empty. **GIVEN** `dt` 0.25 and each tick reading, calling `tick_status`, then applying, **WHEN** a 1.0 s slow is applied in tick 0, **THEN** tick 0 reads 1, ticks 1 to 4 read slowed, and tick 5 reads 1. **WHEN** an equal slow is reapplied in ticks 0 to 10, **THEN** ticks 1 to 14 read slowed and tick 15 reads 1.
10. (Rule 10, `first_in`) **GIVEN** origin (0, 0), `max_range` 100, and A `distance` 50 at (10, 0), B 80 at (20, 0), C 200 at (200, 0), **THEN** B, in every input order. **GIVEN** B dead, **THEN** A. **GIVEN** all dead or an empty list, **THEN** null. **GIVEN** equal `distance` on `spawn_id` 3 at (30, 0) and 1 at (0, 30), **THEN** 1, in both input orders.
    (Rule 10, others) **GIVEN** `nearest_in` with `spawn_id` 5 at (10, 0) and 2 at (−10, 0), **THEN** 2; with 2 dead, **THEN** 5. **GIVEN** `all_in_radius` with `spawn_id` 3, 1, 2 in that order and 2 out of range, **THEN** 3, 1; none in range gives an empty list. After any helper, the input list's size and order equal a snapshot taken before the call.
11. (Rule 10) **GIVEN** `nearest_in` from a hero at pin (0, 0), with `max_range` the leash, 90, **THEN** (90, 0) is in and (90.5, 0) is out; with enemies at (40, 0) and (30, 0), **THEN** (30, 0).
12. (Rule 12) **GIVEN** one script, **WHEN** run with and without a listener, **THEN** counters, every enemy's HP and slow slot, and every return value are equal. **GIVEN** a zero-damage attack, **THEN** `attack_fired` only, with `radius` 0 for a single target. **GIVEN** a killed target, **THEN** `damage_applied` carries its position, its `spawn_id` and `killed` true; a surviving one carries false. **GIVEN** a listener reading inside its handler, **THEN** `hp_left`, `is_dead` and `dealt_total` already show the hit.
13. (Rule 4) **GIVEN** an enemy with `removed` true, dead or not, **WHEN** `deliver`, of 10 or of −5, **THEN** `ERR_REMOVED`, an empty log, returns 0, counters unchanged. **WHEN** `apply_slow`, **THEN** `ERR_REMOVED`, slot unchanged.
14. (Rule 6) **GIVEN** a burst whose radius holds no enemy, **WHEN** `report_attack`, then `all_in_radius`, **THEN** `attack_fired` only, counters unchanged.
15. (Rule 5) **GIVEN** counted hits, **WHEN** every enemy is reaped and the counters are read, **THEN** unchanged.
16. (Rule 5) **GIVEN** an event of kind TOWER from a tower the hero buffs, **THEN** it counts under that tower and the hero and burst sums are unchanged.
17. (Rule 10) **GIVEN** HP 12, **WHEN** `hp_left`, **THEN** 12 with HP unchanged and an empty log; a dead enemy gives 0.
18. (Rule 10) **GIVEN** HP 12, **THEN** `is_dead` is false; after `deliver` 12, true, and still true with `removed` set by a reap. **GIVEN** a leaked enemy, `removed` true at HP 12, **THEN** false.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner | Passes when |
|---|---|---|
| Full determinism (Flow) | Combat stories | The same stage, seed and script give an identical result |
| Micro-battle (Flow) | Combat stories | A kill raises gold by the bounty, a leak drops lives, and clearing all waves wins |
| Bypass (Rule 2) | Tower, Hero stories | `I` holds over a real stage, within 0.001 since real values are not binary-exact, with reaped enemies counted and the output retained in `production/qa/evidence/` |
| Order (Rules 2, 4, 11) | Enemy & Wave stories | Status counts down before Towers fire, and Towers fire by slot index; leaks resolve before fire; a fatal leak pays nothing; `enemy_killed` fires once. `deliver` running only inside a tick is caller discipline, checked here |
| Burst between ticks (Rule 2) | Hero stories | A burst commanded between ticks releases in the Hero-and-burst slot at least one tick later, and its corpses are reaped without moving |
| Pillar 2 bots | Hero stories | Hero's deferred table, which owns the thresholds: hero alone, towers-only, pinned once, always-call and share. Never-pinned is identical to towers-only |
| Damage shown | Battle HUD stories | Won and Lost show Towers, Hero and Burst, matching the counters, with no percentage; retained screenshot |
| Splash vs burst gate (Rule 6) | Tower, Hero stories | Tower's `burst_spike` content test and Hero's `dealt_burst` row, which own the thresholds |

**Manual** (frame-stepped screenshots retained in `production/qa/evidence/`): tower and hero hits tell apart in greyscale, in a side-by-side lead sign-off; a static splash ring whose drawn radius equals the data radius at the screen's scale; drag lines on every slowed enemy; a damaged core on enemies of 22 px and above and none below; no tower flash or ring in any frame of the clearance window. On the first phone build, a non-developer names hero or tower correctly on at least 8 of 10 kills with sound off (proposed; qa-lead confirms or changes it before that test). This proves the hits are legible, not that they are satisfying, which only playtests can judge.

**Checked by code review, not tests:** slow stays out of the accessor (Rule 8), Combat reads no data (Rule 9), no view reads `event.target` (Rule 12).

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Does the technical director accept cutting ProjectileSpawner and the tick order? Both override existing notes | technical-director | App Lifecycle ADR |
| What is the hero's real share? The prototype's 39% had one tower type, bot-fitted values and a bug that could credit negative damage, by an unmeasured amount. Re-run once all three tower roles exist | qa-lead | First playable |
| Does uncapped splash, sharpened by slow clumping enemies, erode the burst's spike? Gate set in the Tower GDD; first simulated with a pass | Tower GDD + bots | First playable |
| Instant hits leave weapon upgrades a thin 100 ms line to show growth on (Pillar 1). What makes them visible? | Weapons GDD (Vertical Slice) | Vertical Slice |
| Do full-strength hero flashes during a burst hold up on a device, does the 0.6 tower flash read, and does suppressing tower flashes in clearance hide what towers did? If so, dim rather than suppress | art-director | First phone build |
| Art bible §8 budgets a hit-flash shader while saying zero shaders; this spec uses none | technical-artist | First phone build |
| Is the 400-check targeting worst case fine on a low-end phone, per tick at Flow's catch-up clamp? Estimated under 2 ms, unmeasured | performance-analyst | First phone build |
