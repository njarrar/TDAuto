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

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, ux-designer, godot-specialist, creative-director
Blocking items: 4 | Recommended: 11
Summary: The core loop, gold arithmetic and review 1 fixes hold; every revision item is factual or testability. The prose claimed more than the data: "9 lives on all four" is one placement, and a paired run shows upgrading in pairs better on 22 of 90 placements, equal on 51 and worse on 17, with a positive mean on every mix. creative-director put the user decision back as a confirmation: accept "weakly better, placement matters more" or demand a clear lead through another retune.
Prior verdict resolved: Yes; all eight review-1 blockers fixed
Findings:
- [BLOCKING] Starter values, line 118: "wins with 9 lives on all four mixed builds" is one fixed placement; medians are 5 to 9 and lows reach 0.
- [BLOCKING] Starter values, line 120: "filling first never comes out ahead" holds for medians only; fill first wins 17 of 90 placements.
- [BLOCKING] Starter values and log: share median 25.2% (Hero) against 25.1% (revision log); the gate sits at its 25% floor.
- [BLOCKING] Acceptance Criteria, 5: the upgrade fixture cannot hold NO_TOWER and MAX_LEVEL at once; spy scope over is_tower and level_count unclear.
- [RECOMMENDED] Formulas: cite the project's to_ticks (systems-designer and godot-specialist rated "undefined" blocking; false, it is defined in Enemy & Wave).
- [RECOMMENDED] Rule 12: "no lost progress" still false (open since review 1).
- [RECOMMENDED] Rule 5: HALTED against NO_GOLD precedence after the cost read.
- [RECOMMENDED] Manual: no chip or arc screenshot with sign-off (qa-lead rated blocking; the UI gate binds at story close).
- [RECOMMENDED] Rule 8: a reflexive double tap at 200 to 300 ms can commit; phone test has no sample size (ux-designer rated blocking).
- [RECOMMENDED] ADR line: re-entrancy and the ChipWindow clock and order (godot-specialist rated blocking; review 1 deferred them to the Input ADR).
- [RECOMMENDED] Content rules: no per-wave scarcity check; 750 > 670 tests gold too late to spend; about one decision per wave.
- [RECOMMENDED] Economy and roles: slow can be a trap (second slow redundant, weakest upgrade); wrong builds unrecoverable; early-call bonus barely a decision.
- [RECOMMENDED] UX: Reduce Motion refusal gives no cue (ux-designer rated blocking; stays a /ux-design must); nothing teaches the second tap; 1.5 s not adjustable; slot 0 chip reach; arc panel text fit.
- [RECOMMENDED] Acceptance Criteria: tighten 10, 14, 21, 22, 26, 27; assert the upgrade success log; cover Rules 7, 8, 10, 17 and edge cases; define fixtures B and C; thresholds for deferred and manual rows.
- [RECOMMENDED] Engine: every chip close path unregisters its disc; retry teardown of registrations; chip routing in a pure class; event-driven redraw.
Disagreements: to_ticks "undefined" (systems-designer, godot-specialist) against the main review, which found it defined; "670 does not follow" (systems-designer) false, line 216 defines it; share gate on seed variance (game-designer) moot, the bots are not random; ADR-deferred items, the double-tap guard, Reduce Motion feedback and the chip screenshot held at recommended by creative-director against their specialists' blocking ratings.
Fixed in the same session: all four blockers (line 118 now separates the fixed placement from the medians; line 120 gives the paired result and the share at its floor; criterion 5 is a sequence with spy scope stated), plus the to_ticks citation, Rule 12's wording, HALTED before NO_GOLD, chip and arc screenshots in Manual, the phone test's sample size and 300 ms fallback, and re-entrancy on the ADR line. User decision taken in autonomous mode, logged, open to the user: accept as delivered (upgrading weakly better, placement matters more) rather than retune.
Reviewed-Content-Hash: design/gdd/tower-system.md 73aeab735d3511e2c67be2fca7deea1d3cdd5f2e
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ed25cb702da175ffd4e9fbebb4a42b147cbffa0d
Reviewed-Content-Hash: design/gdd/combat-damage.md 9fe61dab43d04486b54833702d9215b1c72762b5
Reviewed-Content-Hash: design/gdd/enemy-wave.md 2890a42203fd47a724a105634efd2349ba0b18bf
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b81528a4102d977ed04d869e0f4ecc9a1b117559
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/hero-system.md 6318793eec275f8d1f5e0bd0b3c3f7a2a7d5aa5f
Reviewed-Content-Hash: design/gdd/battle-hud.md a8f14586cae3c5c253117dbf2e0960855d3ec009
