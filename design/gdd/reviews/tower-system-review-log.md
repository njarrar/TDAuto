# Review Log: Tower System

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, ux-designer, qa-lead, godot-specialist, creative-director
Blocking items: 8 | Recommended: 14
Summary: The design is sound and its gold and burst arithmetic holds. The blockers are stale or false statements, two unnamed calls and two untestable criteria, all fixable without reopening a decision. The open creative question is whether fill-then-upgrade is acceptable against the concept's "specialise a few towers deeply"; it is the user's call and should be settled before the bot baseline.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules, Starter values: splash "0.57 on three victims" is wrong; 0.57 is two victims, 0.86 is three.
- [BLOCKING] Dependencies: Battle HUD and Hero are listed as having no GDD yet; both exist.
- [BLOCKING] Rule 8, UI Requirements, Open Questions: the chip is said to have no visible clock; Battle HUD Rule 9 draws a draining bar. Cite it and close the question.
- [BLOCKING] Edge Cases: "purchase rows catch a board that cannot be funded" is false, since every gold row is an upper bound; 0 bounties passes at 160 < 550. Say nothing catches it, or add a floor row.
- [BLOCKING] Rule 9 step 4: names no Combat call behind `attack_fired`; name it and add it to Combat Rule 12, which also closes Hero's logged gap.
- [BLOCKING] Rules 5, 17: name the level-count call, and drop "new" from `is_tower`, which Data Rule 10 already has.
- [BLOCKING] Acceptance Criteria 21: "before the reap" contradicts Rule 15; rewrite as `NO_GOLD` before the tick and `OK` after it.
- [BLOCKING] Acceptance Criteria 5: define the fixture as all faults set and cleared one at a time, including `upgrade` with `BAD_SLOT`.
- [RECOMMENDED] Starter values against concept line 71: fill then upgrade is dominant except splash on packets (build 0.40 dps per gold, single upgrade 0.167, splash upgrade 0.125 or 0.625). User decision: accept and amend the concept, or strengthen single's level 2.
- [RECOMMENDED] Rule 4: add the mis-fire fallback order, larger `R`, then disc gap, then refund grace; the risk stays with the phone test.
- [RECOMMENDED] Rule 12: delete "no lost progress", since an upgrade that shortens the interval keeps the longer timer.
- [RECOMMENDED] Formulas: mark starter-only output ranges; note that calling in the last 4.75 s is free; call `burst_spike` a heuristic, since hairpins change spacing.
- [RECOMMENDED] Summary: "never quite closes" is about gold, not selling.
- [RECOMMENDED] Starter values: exact-spend openings hold at most 40 gold after wave 1 against a cheapest buy of 50; accept it in writing or tune it.
- [RECOMMENDED] Content rules: scarcity is checked only at the last wave; add a wave-by-wave check.
- [RECOMMENDED] Visual/Audio, UI: slow needs visible feedback and its value in the summary, or it reads as broken.
- [RECOMMENDED] Concept: note that towers-only currently loses, which "may win narrowly" permits.
- [RECOMMENDED] Acceptance Criteria: add the missing criteria, chip disc and held-past-expiry first; tighten 14 and 22; cover Rule 9 step 3; THEN clauses as the entire log; split bundles; move 7, 13, 22, 25, 28 to Integration; fix 1 and 26's fixtures; add arc and chip screenshots; make the Manual list measurable.
- [RECOMMENDED] `/ux-design`: a non-motion refusal cue is a must; also expired and closed chip cues, a MAX cue, an off-field chip and Reduce Motion fallbacks.
- [RECOMMENDED] Input ADR, before TowerInput stories: owner of the `ChipWindow` feed and its order against input, typed signals, no commands from listeners, retry teardown.
- [RECOMMENDED] Chip: reconsider having only its disc commit after the phone test.
- [RECOMMENDED] Formulas: quantisation of values not a multiple of `dt`, and a weaker slow wasted on a stronger one about to expire.
Reviewed-Content-Hash: design/gdd/tower-system.md 82efdce00a17d9084e90d7542fa86f72f03110cc
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 3d5b79031d45c84e007b288e1998a9df110c0ac2
Reviewed-Content-Hash: design/gdd/combat-damage.md 6752d513d2ea4eca4d31747a1087005417d40ee7
Reviewed-Content-Hash: design/gdd/enemy-wave.md b54c78785944be6bfd376a6a80eca92dca9c770f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md cc7be8f00ae5d16f5fefd3430a328adf3dde22d7
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/hero-system.md 33be01b73bfae6771218f1f0be47cf520d033e50
Reviewed-Content-Hash: design/gdd/battle-hud.md 1b140d9f6ac912e83e0fdad2caf8f19b63d8e187

## Revision — 2026-11-02 — Eight blockers and one user decision applied, re-review pending
User decision: filling every slot before upgrading must not be the answer. Single's level 2 damage rose from 18 to 21, where upgrading in pairs leads filling first on all four mixes, single alone stays behind them and every gate passes (20 fell below the share band, and 24 let single alone catch the mixes); the Hero table and two new gates, upgrade order and placement, follow. `tools/balance-sim/hero_bots.py --orders` reproduces it, and its assert covers both gates.
Blockers: the splash figure now reads 0.57 on two victims and 0.86 on three; Battle HUD and Hero are listed as existing downstream GDDs; Rule 8 cites the chip's draining bar, and the question is closed; the 0-bounty edge case says no content row catches it; Combat Rule 12 names `report_attack`, used by Tower and Hero; Data Rule 10 names `level_count(def_id)`, and `is_tower` is no longer called new; criteria 21 and 5 are rewritten.
The bots re-ran in both hands. Every gate passes, but the share median is now 25.1%, at the band's floor. Recommended items from the review stay open.

## Revision — 2026-11-02 — All recommended items applied, re-review pending
User asked for all 14. Fill then upgrade was settled in the last revision. Rule 4 has the mis-fire fallback order; Rule 12 no longer claims no lost progress; the Summary separates gold from commitment; the opening dead zone is accepted in writing; `wave_income` adds a floor and a ceiling per wave, and the floor now catches a 0-bounty stage; Rule 16 records the free 4.75 s; `burst_spike` is called a heuristic; quantisation and the wasted weak slow are recorded.
New: `slows_applied()` on Tower and Slowed N on the result, in Battle HUD Rules 15 and 19, so slow shows its value. The concept notes that towers-only now loses. The UX flag lists what `/ux-design` must specify; the ADR note lists what must be settled before TowerInput stories; the chip's disc-only commit is an Open Question.
Acceptance Criteria are rewritten: 28 become 67, bundles split, missing rules covered, Integration moved, fixtures fixed, Manual made measurable.
Decided without asking, in autonomous mode: the income bounds (cheapest cost, twice the dearest), accepting the dead zone, and the Slowed line. None changes a balance number, so the bots were not re-run. Whether Slowed fits Won's panel is unverified.

## Revision — 2026-11-02 — Enemy & Wave review's change applied, re-review still pending
A `heavy` now costs 3 lives, so the upgrade order table and the leak worth are refreshed; single alone now wins with 6 lives. `burst_spike` no longer cites a gate of 5 hits, since Enemy & Wave's gates use 4.

## Revision — 2026-11-03 — cross-GDD warning pass
From design/gdd/gdd-cross-review-2026-11-03.md, Consistency Re-run. `early_call_bonus(seconds_left)` added to Rule 17's reads (N3), `visual_key` names, `to_ticks` dependency.

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, godot-specialist, qa-lead, creative-director
Blocking items: 6 | Recommended: 14
Summary: The prior eight blockers held and every recomputed table checked. Six items remained: "one tick" floors that, after Data's change to 1/30 s, let the bonus divide by zero at a coarse test dt; an unstated clock and clamp for the chip window; a wave_income floor checked on an optimistic bound (wave 2's bounties alone pay 48 against a cheapest buy of 50); a "9 lives on all four builds" line that reads as contradicting the placement table; an impossible AC6; and Rule 16 still framing the bonus as a trade-off after the user made calling a fast-forward.
Prior verdict resolved: Yes (all 8 prior blocking items)
Findings:
- [BLOCKING] Formulas, content rows, Rule 9: "one tick" floors; early_call_bonus and the cooldown divide or reload at 0 ticks under a coarse dt.
- [BLOCKING] Rule 8 and chip criteria: ChipWindow's clock and clamp unstated, so 199/200/1499/1500 are ambiguous.
- [BLOCKING] Content rules, wave_income: floor checked on an optimistic bound; user decision (creative director recommends raising wave 2's bounties so bounties alone pay 50).
- [BLOCKING] Starter values, Open Questions: fixed-placement "9 lives on all four" vs the placement table's medians.
- [BLOCKING] Acceptance Criteria AC6: "every fault at once" impossible for upgrade; HALTED vs NO_GOLD precedence; is_tower and level_count vs "no accessor read".
- [BLOCKING] Rule 16, Open Questions: bonus framed as a cost after the user's fast-forward decision.
- [RECOMMENDED] Formulas: the death spiral is placement as well as timing; "9 lives worth 48 gold" means three heavies.
- [RECOMMENDED] Starter values: the slow and slow opening is a trap; "real choice" overclaims.
- [RECOMMENDED] Content rules: bounds for splash_radius and slow_duration; burst_spike range and epsilon; seconds_left with a 0 duration; a ceiling on last-wave bounty share; gold_before_last_wave for tutorial stages.
- [RECOMMENDED] Rule 8 table: `phase` vs `phase_changed` (ADR-0006, QQ-07).
- [RECOMMENDED] Acceptance Criteria: AC18 wording; AC14 to Integration; AC52's reap dependency; target HP and whether T includes the reap in AC31, 38, 39, 40, 51; AC58 cutoff; missing criteria (Paused, opening tap, chip_state draining, Won gold, HUD preview past the last level); upgrade versions of AC7 to AC12; AC22 and AC42 splits; level-2 role values; two slows of different levels; AC59 per part; Manual pass conditions.
- [RECOMMENDED] Routed to ADRs and architecture: slot_state arity vs B8, input vs ChipWindow feed order, an emitting guard, TowerInput's typed fields, tower_id as StringName, TowerInput signals in B8, targets() cached per tick, _draw batching.
- [RECOMMENDED] Routed to Battle HUD: +N and a first-time hint on calling, ring layer order, 4.7 line feather with a device screenshot, chip disc near the top edge, a bonus-cap row.
- [RECOMMENDED] Routed to playtest: per-tower result line, the chip's mid-wave cost and disc-only commit, a readable level-2 slow, wave 1 leak sensitivity, the 8-gold bonus, back-loaded wave 6 bounties and stranded gold.
- [RECOMMENDED] Disagreements: game-designer's coverage-cue blocker mostly answered by Battle HUD Rule 9's arc range rings; qa-lead's AC65 point mistaken (it uses a starter-shaped factory). The creative director's fix for the chip clock (ticks) was not applied: the sim clock is stopped in Build, so the chip keeps real time with HUD Rule 11's 100 ms clamp.
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d79fe3bf982a1d15a806cc0725421521a6a735d5
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b58a9270cca3749146c6a2291b7324583865c6c6
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 23d2a60fac1632b52fa5c9a35394466973c672ba
Reviewed-Content-Hash: design/gdd/hero-system.md 377e450bbee022ae776076cebdd1ed1c092a02fc
Reviewed-Content-Hash: design/gdd/battle-hud.md 4a8b31f64adc1ad85b770314b77dc0aa5435f39c
Reviewed-Content-Hash: docs/architecture/architecture.md 1bc205b5b722ffc015d14444df535b375764cb42

## Revision — 2026-11-04 — after the review above (not a new verdict)
Applied in autonomous mode: blockers 1, 2, 4, 5 and 6 (max(1, to_ticks(...)) on the bonus divisor and the reload, 1/30 s floors citing Data; ChipWindow on real time with a 100 ms clamp per advance, frozen while Paused, and chip criteria in advance totals; the fixed-placement runs named as one placement per mix; AC6 rewritten per fault with HALTED ahead of NO_GOLD; Rule 16 and Open Question 1 recast for the fast-forward). Blocker 3 applied as the interim option: the wave_income row and Formulas prose now say the bound is optimistic and that a player who never calls is 2 gold short after wave 2. Raising wave 2's bounties is left to the user, since it changes Enemy & Wave's data and needs the bots re-run.
Also applied: the death spiral line, three heavies, AC58's cutoff.
Not done: the remaining recommended items and every routed item.
Re-review pending: the GDD hash above is of the reviewed text, not this revision.
