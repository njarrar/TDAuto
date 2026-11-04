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
Review mode: lean · Workflow: standard
Scope signal: M
Specialists: none (lean; one reader)
Blocking items: 1 | Recommended: 8
Summary: Lean re-review. All eight blockers from 2026-11-02 are resolved. New: with calling now a safe skip, its bonus lifts single-only to tie the mixes, an outcome used to reject other values, and the mono-role gate measures only uncalled play. User decision on the bonus. The reader had no shell, so the sim, diffs and scripts were not run by it.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Rule 16, Starter values: decide the bonus. Cut it, or keep it and gate mono-role while calling. Fix Rule 14 and Open Questions row 1 to match.
- [RECOMMENDED] Rule 16: the one-tick sentence should say the wave commits at once and members spawn next tick; "costs burst recovery" omits re-pin and build time.
- [RECOMMENDED] Formulas: "two with every call" holds only buying cheapest first.
- [RECOMMENDED] Hero's "from the gold": `--calls` cannot separate gold from time; add a zero-bonus comparison.
- [RECOMMENDED] Starter values: "every build loses without the hero" was tested on one placement per mix.
- [RECOMMENDED] Cross-References: no Hero or Battle HUD rows.
- [RECOMMENDED] 40 gold moves a purchase a wave earlier on some mixes; hand arithmetic, not run.
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b

## Revision — 2026-11-04 — after the review above (not a new verdict)
User accepted every recommendation ("Implement all recomended"). Decision: keep the bonus and gate mono-role while calling, on new evidence (cutting it does not end the tie and fails the 2-lives gate on one mix). Applied: Rules 14 and 16, Open Questions row 1, and recommended items including Hero and Battle HUD cross-references. The new gate fails today by design, and tuning at first playable must pass it.
Re-review pending: the hashes above no longer match this document.

## Review — 2026-11-04 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: M
Specialists: none (lean; one reader with a shell)
Blocking items: 0 | Recommended: 3
Summary: The prior blocker is resolved: the bonus stays and mono-role is gated while calling. `--calls` and the hand arithmetic match. The gate has no known passing tuning.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Open Questions row 1, Hero's row: answer "is the rate the lever?" with no.
- [RECOMMENDED] "Where to build": "every gate passes" holds only uncalled.
- [RECOMMENDED] "This run changed the enemies": qualify "win with only 6 lives" as uncalled.
Reviewed-Content-Hash: design/gdd/tower-system.md 86f753dacdcc4d904575ab5d6bdfffb8fd4f6415
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 05e3e8f4ca5b1c2a34b39d2ebc9215b0d5342861
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 0804873149506940e730239e7998a943f8bcc5cd
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md c67e5441a28be83b92efa4b903b15c4e76918a6b
Reviewed-Content-Hash: design/gdd/hero-system.md d075d8207bffb1b7f4a23a2f0467da21c2509528
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md b869a7ca338cf3100f72219f98e64207b252dec6
Reviewed-Content-Hash: design/gdd/battle-hud.md 044488039c9a221f998173317300db5f3cd7ab5b
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f

## Revision — 2026-11-04 — after the review above (not a new verdict)
Recommended text applied after the Approved verdict: the rate claim, uncalled qualifiers and `chip_state()`'s window. Status stands; the hashes above no longer match.
