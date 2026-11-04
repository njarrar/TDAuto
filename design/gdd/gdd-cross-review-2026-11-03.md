# Cross-GDD Review Report

Date: 2026-11-03
GDDs Reviewed: 8 of 8 present
Not read: none. Data & Config and Input had only Summary, Overview, Game Feel and Open Questions read for the design-theory pass; all sections the consistency pass needs were read.
Focus: full
Systems Covered: Data & Config, Input & Gesture Resolver, Game State & Stage Flow, Combat & Damage, Enemy & Wave, Tower, Hero, Battle HUD
Pillars: Growth You Can See; One Hero, Not an Army; Every Stage Reads Differently; Thumb-First. Anti-pillars: roguelite, idle/clicker, hero action game, multiplayer in v1.

**Status at review time.** Combat, Enemy & Wave and Hero were Approved. Data & Config and Tower were In Review, and Input was Revised, pending re-review (the index says In Review). Flow and Battle HUD were Designed, with no review log. The skill's "after all MVP GDDs are approved" precondition was therefore not met on disk.

**Inputs and limits.** The entity registry is empty, so consistency relies on the GDDs alone; run `/consistency-check` to populate it. No GDD has a Player Fantasy section (advisory at `standard`), so the fantasy check used Summary, Overview and Game Feel. Only Combat has a Tuning Knobs section, so knob ownership was checked against Data's domain tables instead. `tools/balance-sim/hero_bots.py` is a bot, not a person, and no human has played these values. The GDD content reached the agents as per-phase slice files rather than pasted text.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **B1. Bots run through the resolver, or around it**
- `input-gesture-resolver.md` Deferred criteria, row "Pin, aim and burst meaning", owner Hero stories: "bot acceptance modes run only through" the resolver. Edge Cases: "The bot and the thumb share one path (Rule 11)".
- `hero-system.md` Core Rules: "Bots call the two commands directly, since the resolver is not in the headless build (Input Rule 11)". Input's own Rule 11 agrees: "headless bots call Hero's and Tower's commands directly".
- `game-state-stage-flow.md` Cross-References: "bots through one path". Handed to owning GDDs: "Input's Rule 11 covers only the hero".
- Hero stories own a criterion that the architecture makes impossible. Options: reword Input's row and edge case to Hero's equivalence test and update Flow's two phrases; or make the resolver available headless, amending Hero and Flow Rule 2.

🔴 **B2. Battle HUD's cooldown total does not exist in Hero**
- `battle-hud.md` Handed to owning GDDs: "Hero: exposes the cooldown's total for the wedge". Rule 12 and Interactions draw the wedge from `cooldown_left()` and `burst_state()`.
- `hero-system.md` Rule 16 reads: `position()`, `pin_target()`, `pin_state()`, `burst_state()`, `cooldown_left()`, with no total, and its "Battle HUD: done" handoff does not list one.
- The wedge has no denominator. Options: add a read to Hero Rule 16 and its criteria; or have the HUD read Burst `cooldown` through the accessor, convert with `to_ticks`, and drop the handoff line.

🔴 **B3. Input's Pillar 4 gate cites a chip log nothing defines**
- `input-gesture-resolver.md` P1: "**GIVEN** the Rule 13 gesture log and Tower's chip log". The phrase "chip log" appears in no other GDD.
- `tower-system.md` Rule 17 defines signals, reads and `chip_state()` only. Battle HUD Rule 19's log has no chip fields.
- P1 is the MVP+ exit gate, and part of it cannot be measured as written. Options: add a development chip log to Tower; extend Rule 13's harness to listen to `tower_upgraded` and `chip_state()`; or add it to HUD Rule 19.

### Warnings (should resolve, but won't block)

Rules and ownership:
- ⚠️ **C1. Cross-invalid Input record has no failure path.** Data leaves `tap_slop > drag_slop` to the resolver's `validate()`; Input's `create` returns null; Flow Rule 18 lists no such route. `drag_slop` 25 with `tap_slop` 20 passes the catalogue and yields no resolver, against Data Rule 8's "No fallbacks". Options: check it in Data or the content test, or add a Fatal route in Flow.
- ⚠️ **C2. Who calls `cancel()`.** Input Rule 7 names the adapter on pause, focus loss and resize. Flow says Won, Lost, Paused, Fatal and retry call it, while its stage logic is a pure headless object. Options: widen Input Rule 7 and inject a callback (App Lifecycle ADR), or route through the adapter.
- ⚠️ **C3. Top-band input.** Input's Interactions and Dependencies say the Controls consume their events. HUD Rule 1 and Input's own UI Requirements say they ignore input. Correct Input.
- ⚠️ **C4. Reticle and cancel-state drawer.** Input: "Hero System computes, HUD draws". Hero's Visual table claims them, HUD Rule 1 omits them, and HUD's Manual list includes "cancelling state". Name one drawer.
- ⚠️ **C5. Range rings.** Tower says the HUD draws them in several states. HUD specifies only `tower_inspected`'s 1.5 s ring. Add the states to HUD, or keep them on Tower.
- ⚠️ **C6. Hit-radius ownership is circular.** Input Rule 9: "the owners' values". Enemy & Wave Rule 3: "Hit radii come from the Input GDD". No record has the field. Add catalogue fields, or declare named presentation constants with one owner.
- ⚠️ **C7. `edge_reject_margin` can break its layout invariant.** Domain 0 to 48, but HUD's x 84 satisfies Input Rule 12 only at 36 or below, and no content rule ties them. Cap the domain, or add a row.
- ⚠️ **C8. L11 is conditional in Enemy & Wave and unconditional in Hero's content table.** A straight stage fails Hero's row as written. Add the condition or refer to L11.
- ⚠️ **C9. `requires_bend` and `visual_key` are incomplete.** `requires_bend` is missing from Data Rule 10's Stage list and Enemy & Wave's starter table. Tower and Hero starter tables have no `visual_key`, though Data Rule 7 makes missing fields boot-fatal.
- ⚠️ **C10. Who caps `max_slow`.** Enemy & Wave credits Combat. Tower's content rule actually does it (0.6), and Combat reads no data. Correct the attribution.
- ⚠️ **C11. Ground rings.** Input Interactions: "per session". HUD Rule 14 and Input's Visual table: per battle. Correct Input.
- ⚠️ **C12. Input record shape is stale.** Input says three fields; Data has five, including `left_handed` and `reduce_motion`, which Hero and the HUD read.
- ⚠️ **C13. Path draw-in.** Flow still lists it; Enemy & Wave and the HUD defer it. Mark Flow's row deferred.

Acceptance criteria and story ownership:
- ⚠️ **C14. Bot-gate owner disagrees.** Enemy & Wave gives Mono-role and the Always-call rows to Tower stories. Tower and Hero give them to Hero stories. Flow's "must not beat a driven hero" has no direct Hero row.
- ⚠️ **C15. Criteria owned by stories that do not acknowledge them.** Flow gives Combat stories full determinism and the micro-battle. Input gives Game State the injection row. Enemy & Wave gives Tower and Hero stories L14, which neither mentions. Data gives Flow the bad-accessor Fatal, and Flow's Boot row checks only failed load and broken scene.

Stale references and tables:
- ⚠️ **C16. Stale text.** HUD Rule 15 "amends" Combat rows that already read "no percentage". Enemy & Wave's Input Open Question on slots and its "(Open Questions)" next-wave note are gone or settled by HUD Rule 5. Enemy & Wave asks where Reduce Motion lives, which Data has settled. Input asks instant or walk for re-pinning, which Hero Rule 3 has settled.
- ⚠️ **C17. Dependency tables.** Input and Flow, and Combat and Flow, each list the other as downstream. Combat's `to_ticks` upstream is missing from Enemy & Wave's downstream. Enemy & Wave calls the HUD hard, and the HUD calls Enemy & Wave soft. Data, Input and Flow still say downstream GDDs mostly do not exist.
- ⚠️ **C18. Systems index.** Dependency cells for Hero, HUD and Combat are short. Progress reads "Design docs approved | 2" against 3. High-Risk reads "Four-piece decomposition" against Combat's three pieces.
- ⚠️ **C19. Unwritten targets, all in the index.** Mobile Platform owns the L6 prompt overlap, with a deadline before the first phone build. The others (Stat & Modifier, VFX, Stage Progression, Onboarding, Settings and more) need no action now.

---

## Game Design Issues

### Blocking

None. Every issue below sits in data, bots, gates or content rules, so an architecture built now inherits none of them.

### Warnings

- ⚠️ **D1. Every simulated gate comes from a bot with no thumb limit.** `hero_bots.py` can re-pin, burst and buy on one tick, with no travel, no chip wait and no lock while aiming. Tower Rule 6 names the real cost: "the thumb cannot re-pin at the same time". So share, lives, upgrade order and placement all describe play one thumb cannot do. Options: a one-thumb bot with an action lock (recommended), reported beside mid-skill; or treat all gates as bot-only until human logs; or re-baseline mid-skill, which moves approved tables.
- ⚠️ **D2. Pressing the burst when ready beats holding it, and pushes share past the band** (measured; see the table below). Firing on any victim count gains 1 life on all four mixed builds, or on three of them when fired strictly on cooldown, and moves the median share above the 25-30% band and stage length under the concept's 5 minutes. The 40% cap holds. So the "mid-skill" row is not the good strategy, and the simplest human rule likely lands outside the band. Hero Game Feel's "A burst every 10 s keeps the thumb busy" describes twice the rate the band was fitted to. Options: add these runs to the sweeps and widen the share gate to cover them (recommended); make a wasted or small burst cost more; or reword Game Feel and let human logs decide.

| Burst trigger, mid-skill otherwise | Lives, four mixes | Share, four mixes | Median | Bursts | Length (min) |
|---|---|---|---|---|---|
| Hold for 5 (table) | 9, 9, 9, 9 | 25, 35, 24, 25 | 25 | 10-11 | 5.0-5.3 |
| Need 3 | 9, 9, 9, 9 | 31, 35, 29, 32 | 31.5 | 12-14 | 4.9-5.2 |
| Need 2 | 10, 10, 10, 10 | 31, 38, 31, 30 | 31 | 13-16 | 4.7-5.0 |
| Need 1 | 10, 10, 10, 10 | 31, 39, 29, 30 | 30.5 | 18-19 | 4.7-4.8 |
| On cooldown (need 1, no wait) | 10, 7, 10, 10 | 31, 34, 33, 32 | 32.5 | 22-23 | 4.6-5.2 |

- ⚠️ **D3. Hero share swings widely by wave, and the stage median hides it** (measured per wave). Pillar 2's 25-30% describes a total no wave resembles.

| Mix | W1 | W2 | W3 | W4 | W5 | W6 |
|---|---|---|---|---|---|---|
| 3 single, 1 splash, 1 slow | 18 | 6 | 52 | 32 | 23 | 20 |
| 2 single, 2 splash, 1 slow | 16 | 8 | 51 | 44 | 32 | 38 |
| 3 single, 2 splash | 18 | 6 | 27 | 33 | 32 | 21 |
| 2 single, 1 splash, 2 slow | 18 | 6 | 52 | 33 | 23 | 22 |

  Wave 2 was authored around "Two packets, one burst cooldown apart", yet the hero does 6-8% of its damage, which may be the 5-victim trigger rather than the wave. Options: report per-wave share in the script (recommended) and re-check wave 2 under D2's triggers; gate the last wave as well; or leave it to the Stage Progression and Skill Tree GDDs. Vertical Slice tower multipliers could widen this.
- ⚠️ **D4. Re-pinning is the concept's named decision and the weakest verb.** Using the burst decides win or loss; placement moves lives by up to 10; upgrade order by a median of +0.5 to +2; re-pinning against the best single pin by +1, +1, +2 and +4, over up to about 80 re-pins in a stage (about 237 s of wave time at a 3 s cadence). The user's acceptance of about 2 lives is recorded and not reopened. New here: under one thumb each re-pin takes time from verbs worth more, and instant retry makes finding a good pin cheap. Recommended: add parked and re-pinning one-thumb modes to D1's bot.
- ⚠️ **D5. Single-only with always-call ties the best mixes, through a gap between gates.** Single only: 6 lives uncalled, 9 with every call, and every mix is 9. Mono-role is checked uncalled, and Always-call does not gate single-only. Recommended: extend Mono-role to the always-calling column.
- ⚠️ **D6. Pillar 2's band against Pillar 3's changing geometry (open decision for the user).** Moving slot 1 by 5 units gave 24.4%, single level 2 damage 20 gave 24.8%, and burst radius 65 and 75 gave 24% and 32%. The band is 5 points wide and today clears by 0.1, so a per-stage band is unlikely to survive stage 2. Options: measure across stages with a wider per-stage tolerance (recommended); tune the burst per stage; or gate on `dealt_burst` and lives, with share as telemetry.
- ⚠️ **D7. Three of five slots commit in the zone UX calls out of thumb reach.** Arc discs and the chip sit up to 76 above a slot, so the slots at y 305 and y 485 commit above the field's midline. A pin can gain a finger offset, a tap cannot, and the first build and upgrade need the reach. Options: add top-of-field arc and chip taps to gate P1 and record regrips (recommended); a content rule that moves slots, needing a re-simulation; or arcs below the slot.
- ⚠️ **D8. Calling early has high system cost and no measured decision weight.** It changes 0 lives on mixed builds, pays at most 40 gold, and takes the stage to 3.6-3.8 minutes, while needing arming, an exclusion disc, the press-overlap rule, a Stage field and two bot modes. The user kept it for MVP. Recommended: decide from the specified human call log, and state that the 5 to 8 minute target applies to uncalled play. D2 shows it can fail even uncalled.
- ⚠️ **D9. "Gold never fills the board" depends on the weakest slot.** Slot 5's coverage is a strict subset of slot 4's. Four fully upgraded singles cost 440 against 456 held before wave 6, and 3 single plus 1 splash cost 480 against 496 with calls. So the 496 < 550 gate holds only by counting a slot always bought last. The Open Question misses this link. Recommended: differentiate slot 5 at the first baseline and re-check both.
- ⚠️ **D10. Pillar 1's only growth event can arrive late, and Hero and the HUD disagree on the personal number.** Fill-first buys its first upgrade around wave 5 (hand estimate). Hero Rule 17 makes median kills per burst "the personal number", while HUD Rule 15 keeps it in the log only. Recommended: settle where it shows in the Stage Progression GDD.
- ⚠️ **D11. Slow is the risk role, and the HUD points players at it.** The no-slow mix has the best floor (fill first 6-9 lives, pairs 3-9, against ranges reaching 0 or 1), and the 2-slow mix the worst medians (4 and 6). Only 4 of 21 compositions were tested. Recommended: run all 21 at the first baseline, then decide the "Squares slow fast enemies" hint.
- ⚠️ **D12. Spare lives soften wave 6 until stars exist.** At full lives three heavies can leak for 9 lives and 48 gold, taking wave 6 from 6,100 to 3,850 HP, about 1.04 times wave 5. Recommended: leave at MVP, and price it in the star thresholds.
- ⚠️ **D13. "Calm" and "busy" are not one game.** The concept's "tactical calm punctuated by hero bursts" and the HUD's "calm" fit Enemy & Wave's pressure as one commander identity. Hero's "keeps the thumb busy" and the bot's re-pin cadence do not. "The deciding move" also takes only 17% of a heavy. Recommended: state the intended cadence in Hero Game Feel after D2's sweep.

### Attention at the peak (wave 6, about 24-28 s in)

| System | Active? | Cost (assumed, unmeasured) |
|---|---|---|
| Re-pin | Yes: drag, walk up to about 2 s | 0.6 s |
| Burst aim | Yes, when Ready: locks the thumb | 1 s + 0.25 s telegraph |
| Upgrade and chip | Yes: two taps 200-1,500 ms apart | 0.8 s + travel |
| Build | Only if a slot is empty | 0.8 s + travel |
| Field read | Yes, continuous, eyes only | Constant |
| Call early | No, hidden in Wave | n/a |

**Four command systems, five with the field read, above the limit of 4,** all in series through one thumb. Matching the bot through wave 6 is about 35% thumb occupancy before travel or gaze cost (estimate).

### Resource map

| Resource | Sources | Sinks | Condition |
|---|---|---|---|
| Gold | Start 120, bounties 510 at most, call bonus 40 at most | Builds, upgrades; no selling or interest | Scarce early, bounded, dead after the last wave |
| Lives | Start 10; no restore | Leaks: 1, heavy 3 | Sole stake at MVP; a cliff, not a spiral (D12) |
| Burst cooldown | Time, not in Build | Every burst | Always restored between waves (15 s against 10.25 s); does not scale |
| Slots | 5 | Permanent builds | Fifth is dominated (D9) |
| Time | Build unlimited, Intermission 15 s, wave time | Calling, thumb actions | Thumb time is scarcest and unmodelled (D1) |

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. Fatal leak on the tick of the last kill (Enemy & Wave, Combat, Flow, Tower, HUD)
2. Wave clears with an aim or telegraph in flight, then a call (Enemy & Wave, Hero, Flow, Tower, HUD)
3. Focus loss with a chip open, an aim held and a telegraph running (Flow, Input, Tower, Hero, HUD, Enemy & Wave)
4. First run: Start with no pin, then Lost (Flow, Hero, Enemy & Wave, HUD)
5. Call early, bonus, then a mid-wave build (HUD, Flow, Tower, Hero)

### Blockers

🔴 **Scenario 4: `wave_index()` has no defined base or update time. Enemy & Wave, Flow, Battle HUD.** At the Lost step, the HUD's "Broke on wave N of `wave_ids` size" and its pips (filled done, outlined current) read `wave_index()`, which Enemy & Wave defines only as the "index into `wave_ids`" and tests only as having "risen". Flow's result separately carries "last wave started". Whether the index is 0- or 1-based, whether it moves at start or at clear, and which source the HUD uses are all undefined, so a player can be told the wrong wave. It is also unclear what "current" means during Intermission. A one-line definition in Enemy & Wave Rule 14 and a named source in HUD Rule 15 settle it.

### Warnings

⚠️ **Scenario 3: `cancel()` caller, Flow, Input (C2).** Focus loss is covered by the adapter, but outcomes and retry depend on the unresolved caller. The chip, arc, aim and arming rules otherwise agree.

⚠️ **Scenario 2: wedge state, HUD, Hero (B2).** The Intermission button shows the burst's wedge, so its small glyph inherits B2.

⚠️ **Scenario 5: mid-wave build against aim and re-pin, Tower, Hero, HUD (D1, D8).** The data flow is correct: the bonus is paid before the first spawn, and the arc disables Start/Call. The unmodelled cost is the thumb.

### Info

ℹ️ **Scenario 1.** Clean. The leak resolves first, the reap is skipped, no bounty is paid, and the snapshot on the next frame counts the leak. Flow Rules 12 to 15, Combat Rule 11 and Enemy & Wave Rules 10, 11 and 13 agree.

ℹ️ **Scenario 2.** A held aim survives the phase change (Flow Rule 10), and releasing it on an empty field spends the cooldown (Hero Rule 8), with 15 s still restoring it unless the player calls at once. The script freezes walking and telegraphs during Intermission where the rules keep ticking; Hero records this as slightly pessimistic.

ℹ️ **Scenario 3.** The danger timer uses view time, so `danger_until` can lapse during a pause. Presentation only.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| input-gesture-resolver.md | B1 bot path; B3 chip log; C1 to C3, C6, C7, C11, C12, C16, C17 | Consistency | Blocking |
| game-state-stage-flow.md | B1 stale phrases; scenario 4 result source; C1, C2, C13, C15, C17 | Consistency | Blocking |
| battle-hud.md | B2 cooldown total; scenario 4 `wave_index()` source; C4, C5, C16, C17 | Consistency | Blocking |
| enemy-wave.md | Scenario 4 `wave_index()` definition; C6, C9, C10, C14 to C17 | Consistency | Blocking |
| hero-system.md | B2 if the read is added there; C4, C8, C9; D2, D3, D13 | Consistency, Design Theory | Warning, pending the B2 decision |
| tower-system.md | B3 if the log goes there; C5, C9; D5, D9, D11 | Consistency, Design Theory | Warning, pending the B3 decision |
| data-config-pipeline.md | C1, C7, C9, C17 | Consistency | Warning |
| combat-damage.md | C15, C17 | Consistency | Warning |
| systems-index.md | C18 | Consistency | Warning |

---

## Verdict: FAIL

Four blocking items, all in cross-document text; none needs a balance value changed.

### Required actions before re-running

1. **B1:** choose the bot path, then reword Input's row and edge case and Flow's two phrases, or amend Hero and Flow Rule 2.
2. **B2:** choose where the cooldown total comes from, then amend Hero Rule 16 or remove the HUD's handoff line.
3. **B3:** choose who owns the chip log, then define it in Tower, Input's Rule 13 harness or HUD Rule 19.
4. **`wave_index()`:** define base and update time in Enemy & Wave Rule 14, and name the result's source in HUD Rule 15 and Flow.

### Coverage notes

The measured tables came from a throwaway driver over the unmodified `hero_bots.py`, whose base run reproduced the Hero table. They replace hand estimates that were materially off: 39-56% for on-cooldown share (measured at most 34%), and a share falling steadily by wave (measured as a swing). Not checked: most art bible value citations, prototype internals, the concept's "amended" claims, L8, L10, L11 and L14's starter numbers in the consistency pass, and all human behaviour and phone reach.

---

## Resolution — 2026-11-03

The user chose the recommended fix for all four blockers. Applied, pending `/review-all-gdds consistency`; the 19 + 13 warnings stay open.
- **B1:** Hero's design stands. Input's deferred row and edge case, and Flow's two phrases, now say bots call commands directly.
- **B2:** The HUD computes the wedge from `cooldown_left()` and Burst `cooldown` through the accessor. Hero is unchanged. Flow's builder also passes the HUD the Burst's ID.
- **B3:** Input's Rule 13 harness logs `tower_upgraded` and `chip_state()`. P1 no longer cites a Tower log. Tower is unchanged.
- **Scenario 4:** `wave_index()` is defined in Enemy & Wave Rule 14 (1-based, 0 before a start, set at commit, unchanged by a clear). The HUD's pips and "Broke on wave N" and Flow's result all use it, with Flow's value injected by the builder.

Statuses: Input and Enemy & Wave are In Review; Flow and Battle HUD are back to Designed, since neither has had a review.

---

## Consistency Re-run — 2026-11-03 (after the four fixes)

GDDs Reviewed: 8 of 8 present
Not read: none. All eight GDDs and `systems-index.md` were read in full; `game-concept.md` from Core Mechanics to Anti-Pillars, plus the MVP section.
Focus: consistency only, design theory not run. The D warnings above stay open and were not rechecked. The scenarios were re-walked only for the four fixes.
Systems Covered: Data & Config, Input & Gesture Resolver, Game State & Stage Flow, Combat & Damage, Enemy & Wave, Tower, Hero, Battle HUD

**Method.** This pass ran in the main session rather than through a `game-designer` sub-agent, since there was no second phase to run beside it. So it is not independent of the session that loaded the text. The entity registry is still empty.

### The four fixes hold

| Item | Result |
|---|---|
| B1 bot path | Holds in Input's deferred row and edge case, and in Flow. Input's Overview still has the old claim (N2) |
| B2 cooldown total | Holds. HUD Rule 12 reads `cooldown_left() / to_ticks(cooldown)`, Flow injects the Burst's ID, and no HUD text asks Hero for a total. Data's HUD row is stale (C17) |
| B3 chip log | Holds. Input Rule 13 listens to `tower_upgraded` and reads `chip_state()`, both in Tower Rule 17. Rule 13 has a similar gap for bursts (N4) |
| `wave_index()` | Holds. Enemy & Wave Rule 14 and its criteria 24, 30 and 33 agree with HUD Rule 15, the pips and Flow Rule 15 |

### Blocking

None.

### New warnings

- ⚠️ **N1. The concept's drag priority is reversed.** `game-concept.md` Pillar 4: "Drag priority: burst > hero". Hero Rule 15 and Input's table: hero DRAG 200, burst button DRAG 100, by user decision on 2026-11-02. Input's table is also described as one that "matches the concept's Pillar 4 order". The GDDs agree with each other, so correct the concept.
- ⚠️ **N2. Input's Overview contradicts Rule 11.** The Overview says "the bot acceptance modes drive the hero through the same press, move and release calls a thumb would". Rule 11 says "headless bots call Hero's and Tower's commands directly". This is what remains of B1. Replace the clause.
- ⚠️ **N3. The HUD's bonus has no read to call.** HUD Rule 10 and Interactions take the bonus "through Tower's formula", and HUD criterion 31 needs shown to equal paid. Tower Rule 17's reads and the HUD's Tower dependency row do not list it, and the formula takes seconds while the HUD holds `intermission_left` in ticks. Add a pure read to Tower Rule 17 and the HUD row, or the HUD will copy the formula.
- ⚠️ **N4. P1 cannot classify a burst from the Rule 13 log.** P1 counts "any burst not prompted" as a mis-fire. Rule 13 names the resolver's signals and Tower's only. `drag_ended` from the button can also be a cancel (Hero Rule 13), which Input's edge case calls "A miss, never a mis-fire". Have the harness also listen to Hero's `burst_started`.
- ⚠️ **N5. Rule 14 does not say when a leak is counted.** HUD criterion 19 needs the result to include the fatal leak. Enemy & Wave Rule 13 returns at once after every signal, and Rules 10 and 14 do not place the `got_through_by_type()` increment. Counted after `enemy_leaked`, the fatal leak would be lost. Say it is counted before the signal, and add a case to criterion 16.
- ⚠️ **N6. Flow's `phase(Paused)` and `phase(Fatal)` have no criterion, and two criteria exclude them.** Rule 15 emits them and Tower's chip relies on them (Tower Rule 8). Flow says "each THEN is the entire log", but criteria 12 and 13 list neither. The stage machine also has no Fatal row. Add them to the criteria and the table.

### Earlier warnings, rechecked

Open, unchanged: **C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13, C14, C15, C19.** C2 (who calls `cancel()`) and C1 (no failure path for a cross-invalid Input record) are the two that affect the architecture. Both belong in the App Lifecycle ADR. C4 also covers the HUD's "Digit, wedge, ticks" row, because Hero's Visual table claims the Ready ticks.

Open, with additions:
- **C16 stale text.** The earlier items stand. Added: Input's Formulas give `r` as "36–48 at MVP" against the hero's 56 in its own table. Hero Rule 14 says the UX offset is 105, and its Open Questions say 100. Enemy & Wave's Cross-References still cite Input's "Open Question on slots". HUD Rule 4 says it corrects Input on the pause button, which Input already says.
- **C17 dependency tables.** The earlier items stand. Added: Data's HUD row and dependency row say only "Costs", though the HUD now also reads Burst `cooldown`. Hero, Tower and the HUD use `to_ticks` without listing Enemy & Wave's formula as its source. The Cross-References tables in Data, Input and Flow have no rows for most systems written after them.

Partly resolved:
- **C18 systems index.** "Design docs approved | 2" is now correct, since Enemy & Wave went back to In Review. Still stale: "reviewed | 1", "Four-piece decomposition", the short dependency cells, the Next Steps, and the header's claim that the concept needs revision. Input's header says "Revised" where the index says "In Review". Input's and the HUD's Last Updated dates predate today's fixes.

### Formula compatibility

No range mismatches. Recomputed by hand from the starter tables, and all match where cited: path length 1,720 and the L5, L9 and `time_to_exit` values; wave HP and the 16,790 total; bounties, `gold_upper_bound`, `gold_before_wave`, `wave_income` and the bonus cap; `lives_at_risk`; full-board costs; `burst_spike` 5.78; burst fit against `max_hp`; `hero_start` and Start/Call clearances; arc geometry; prompt overlap. Not rechecked: bot results, which come from `hero_bots.py`.

### Cross-system scenarios, re-walked for the fixes

- ℹ️ **Lost mid-wave (Flow, Enemy & Wave, HUD).** `wave_index()` now gives "Broke on wave N" one definition. N5 is the remaining gap.
- ℹ️ **Burst wedge in Intermission (Hero, Data, HUD).** Clean. Telegraphing reads 0 and draws empty, as Hero's step 5 and HUD Rule 12 agree.
- ⚠️ **Focus loss with an aim held (Input, Flow, Hero).** Unchanged: it behaves correctly, but C2 leaves the caller of `cancel()` on an outcome or retry open.

### GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| input-gesture-resolver.md | N2, N4; C1 to C3, C6, C7, C11, C12, C16, C17 | Consistency | Warning |
| game-state-stage-flow.md | N6; C1, C2, C13, C15, C17 | Consistency | Warning |
| battle-hud.md | N3; C4, C5, C16, C17 | Consistency | Warning |
| enemy-wave.md | N5; C6, C9, C10, C14 to C17 | Consistency | Warning |
| tower-system.md | N3; C5, C9, C14, C15 | Consistency | Warning |
| hero-system.md | C4, C8, C9, C14, C16, C17 | Consistency | Warning |
| data-config-pipeline.md | C1, C7, C9, C17 | Consistency | Warning |
| combat-damage.md | C15, C17 | Consistency | Warning |
| game-concept.md | N1 | Consistency | Warning |
| systems-index.md | C18 | Consistency | Warning |

Statuses in the systems index were left unchanged, because nothing here is blocking.

### Verdict: CONCERNS (consistency only, design theory not run)

No blocking issues. 6 new warnings, and 19 earlier ones still open or partly open.

### Resolution of the re-run — 2026-11-03

Applied at the user's request, uncommitted, not re-reviewed. No balance value changed.

- **Fixed:** N1 to N6, C3, C5, C7 to C18. C19 needs no action until the Mobile Platform GDD.
- **Fixed by a choice the user can overturn:**
  - **C4:** a hero view draws field-anchored visuals; the HUD draws the button, digit and prompts.
  - **C6:** hit radii are named constants on owners' input objects, not catalogue fields.
  - **C7:** a HUD content row at 84 against 84, with no value changed.
  - **C14:** owners moved to Hero stories, as Tower and Hero already said.
  - **C17:** Flow now lists Input and Combat as upstream, and the HUD lists Enemy & Wave as hard.
- **Routed to ADR-0001, not decided:** C2 as QQ-19 and C1 as QQ-20, in `docs/architecture/architecture.md` and the Open Questions of Input, Flow and Data. ADR-0001 is not written yet.

- **Closed 2026-11-03/04:** C2 and C1 are decided, not routed: Flow cancels through the injected `cancel_input()`, AppRoot on retry, a repeat call finds Idle (Input Rule 7); the catalogue validator rejects `tap_slop` ≤ `drag_slop` (Data Rule 7), and the wrapper builds the resolver, with a null from `create` calling the failure handler (Flow Rule 18). An independent check of this pass found 6 conflicts and 9 stale references, mainly in the architecture, all fixed. No balance value changed. It also found 100 for 105 in Hero's offset prose, and word-form count fixes, which are corrections. Not re-reviewed: Data & Config, Input and Tower. Enemy & Wave re-reviewed, Approved. Battle HUD and Flow: first reviews, Needs Revision.
