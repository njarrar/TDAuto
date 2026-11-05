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

## Revision — 2026-11-04 — ADR sync
Tables only; no balance value changed. Interactions and the downstream Dependencies table gain a row for Input's Rule 13 gesture log, which hears `tower_upgraded` and reads `chip_state()` in development builds. The log belongs to the test harness story, not the resolver. This makes the link two-way, as cross-review N3 asked (gdd-cross-review-2026-11-03.md, Consistency Re-check), alongside the ADR-0001 to ADR-0003 sync of the other GDDs.

## Revision — 2026-11-04 — ADR-0004 to ADR-0008 sync
No balance value changed; Status unchanged. Signal renames: `tap` to `tapped`, `phase` to `phase_changed`, `waves_complete` to `waves_completed` (ADR-0006 Decision 5). Rule 17 and both gesture-log rows name `GestureLog` and its `set_prompt` (ADR-0008 Decision 8), and Rule 17 says the HUD reads costs when drawing, never in a sim signal handler (ADR-0005 Decision 5). The ADR note records that the wrapper feeds `ChipWindow.advance(ms)` in frame step 1 (ADR-0004 Decision 4). Not applied: ADR-0008 makes `chip_state()` TowerSim's read, but this GDD gives it and the chip window to TowerInput; left for the user to settle.

## Note — 2026-11-04 — `chip_state()` owner settled
The GDD stands: `chip_state()` and `ChipWindow` belong to TowerInput (Rules 8 and 17). It is presentation state on a real-time clock, so keeping it out of TowerSim keeps the sim identical with or without views. architecture.md, ADR-0008's review table and the registry entry now match the GDD. No GDD text changed.

## Revision — 2026-11-04 — accessibility and pattern fixes (MVP)
No balance value changed; Status unchanged. Sources: `design/accessibility-requirements.md` (GDD and ADR Changes Needed, MVP rows) and `design/ux/interaction-patterns.md` (OI items).
- Rule 7: an unaffordable disc still calls `build`, gets `NO_GOLD` and shows a refusal, matching Battle HUD Rule 7 (OI-09). The deferred Arc row now says the same.
- Rule 8 and its event table (user decision): the 200 ms chip guard counts from the press, as the arc's does. A press that begins within 200 ms is ignored even if released later; the window end still counts at release. Criteria 13, 15 and 16 give press and release times (IP-10, OI-11).
- Visual table, Range ring: the next-level ring is a dashed 2 px cyan line at alpha 0.5 or above, 3:1 or above on the path, told apart from the current ring by pattern (AR-V-06, OI-02).
- UI Requirements (user decision): under Reduce Motion a refused disc or chip shows a dotted outline and "Need N gold" for 1 s, with no motion (AR-V-11, IP-24, OI-04). The UX flag now asks the pass to place that cue.

## Revision — 2026-11-05 — ADR-0010 sync
Wording and tables only; no balance value changed; Status unchanged. Source: ADR-0010 (Accepted 2026-11-05) Migration item 5.
- Rule 5: the result table gains `BUSY` (a call inside a tick or another command) before all other checks, and `HALTED` also covers a cost read that latched Fatal.
- Rule 17: `slot_state(slot_index)` returns the slot's own `SlotState`; a bad index returns one shared empty sentinel and reports once. `slot_count()` is listed as a read.

## Review — 2026-11-05 — Verdict: APPROVED
Review mode: full · Workflow: standard
Scope signal: L
Specialists: none spawned. This review ran as a subagent with no Agent tool, so the main reviewer took each role's view in turn: game-designer, systems-designer, economy-designer, ux-designer, qa-lead, godot-specialist, and creative-director for the verdict. None of those agents passed this document; the views below are the main reviewer's.
Blocking items: 6, all wording, all fixed in this pass | Recommended: 7
Summary: Every blocker from 2026-11-02 is fixed, and all formulas and starter numbers check out against Enemy & Wave and the Accepted ADRs. The six blockers this time were all stale text against ADR-0008, ADR-0010 and ADR-0011: `SlotState` lacked `cooldown_full`, Rule 17 lacked `call_bonus` and `towers_built`, the build overlay had no Reduce Motion fallback, and an open question asked about an ADR that is now Accepted. Each fix is wording only, and no balance value or design intent changed. No blocker and no open design decision remain, so the verdict is APPROVED; what is left is advisory or waits for playtest.
Prior verdict resolved: Yes. All 8 blockers of 2026-11-02 are fixed in the text (splash 0.57 and 0.86, downstream GDDs listed, chip bar cited, 0-bounty case, `report_attack`, `level_count` and `is_tower`, criteria 51 and 6).
Findings:
- [BLOCKING, fixed] Rule 17: `SlotState` lacked `cooldown_full` (ADR-0010 amendment, ADR-0011 Decision 4). Added, with its meaning.
- [BLOCKING, fixed] Rule 17: "updated at each commit" did not match criterion 31 or the Cooling ring, which reads `cooldown_left` live. It now says the state also updates whenever the timer changes.
- [BLOCKING, fixed] Rule 17: reads lacked `call_bonus(ticks_left)` and `towers_built()` (ADR-0010 Decisions 4 to 6). Added.
- [BLOCKING, fixed] Visual table, Build and Cooling rows: no Reduce Motion fallback and no `SlotState` source for the ring (TR-tower-015, AR-V-10, ADR-0011 Decisions 4 and 8). Added. The UX flag no longer lists the fallbacks as open.
- [BLOCKING, fixed] Open Questions and the ADR note: asked the technical director to accept the split. ADR-0010 is Accepted, so the question is closed and the note names Decision 1.
- [BLOCKING, fixed] Rule 8: "takes the press time from `pressed`" did not match ADR-0008, where `pressed` carries no time. It now reads the window's elapsed time when `pressed` fires.
- [RECOMMENDED] Acceptance Criteria: no criterion for `BUSY` (Rule 5, ADR-0010 V1), for `call_bonus` matching the paid bonus (ADR-0010 V3), or for `cooldown_full` on fire, upgrade and empty slots. Add them before the TowerSim story.
- [RECOMMENDED] Rule 8: `advance(ms)` runs after input in frame step 1, so the elapsed time read at a press or release can be up to one frame old. The guard errs safe and the expiry errs up to one frame late. Say so, or decide otherwise.
- [RECOMMENDED] Manual evidence: add a Reduce Motion screenshot of the build overlay and of the static refusal cue.
- [RECOMMENDED] Missing sections, advisory at `standard`: Player Fantasy (Game Feel covers part of it) and Tuning Knobs. AR-M-07 at Alpha needs a home for the chip window multiplier.
- [RECOMMENDED] Formulas, gold_before_wave: the variables table does not define `w` or `early_call_bonus`.
- [RECOMMENDED] Acceptance Criteria 9, 10, 36, 37: they have no WHEN step. They can still be tested, but they do not follow the GIVEN, WHEN, THEN form.
- [RECOMMENDED] ADR-0010 Decision 6 still says `SlotState` is "updated at each commit". The technical director should line that up with ADR-0011 Decision 4. This review does not edit ADRs.
- [NOTE] Art director question: the rapid-fire tower is not in MVP. The MVP roles are single_target (triangle), splash (hexagon) and slow (square), as Rule 1 and concept MVP item 2 say. Rule 1 moved the square from rapid fire to slow. A rapid-fire tower comes later (Small Ship has 4 towers) and needs its own shape. The "Deliberately not built for MVP" list now names it.
Wording edits in this pass: Status line; Last Verified; Rule 7 (concept item 6 now matches); Rule 8 (press time); Rule 17 (reads, `SlotState`); not-built list (rapid fire); ADR note (all settled); Visual intro (`TowerView`); Visual Cooling and Build rows; UX flag; Open Questions (TD row closed).
Reviewed-Content-Hash: design/gdd/tower-system.md feecd55d693e8bc9c802b4115d51ee494ea5bfba
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 5fc68e4c2eda531b8ef80a5663b2f33961b139cf
Reviewed-Content-Hash: design/gdd/combat-damage.md e4df04fab059c0779ec3460522a8b4f0f6605fc1
Reviewed-Content-Hash: design/gdd/enemy-wave.md adfe9932b1756518dd4219a26cdb9c048950950d
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 8061a4bdcda61243e597c23dc1214d8448ba9119
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md add0f1c5a5b8b8bd7f52b3683fd9985b84c911b2
Reviewed-Content-Hash: design/gdd/battle-hud.md 9cae820470e28dccf98015d4a423e8c9d9626a5a
Reviewed-Content-Hash: design/art/art-bible.md 02d54d6b93ccc9656dcfdfdc5e0d888cde99f7d0
Reviewed-Content-Hash: design/accessibility-requirements.md b0574e2ac2870c485edb5d038e477577e9d46700
Reviewed-Content-Hash: docs/architecture/adr-0004-fixed-tick-clock-tick-order-frame-order-determinism.md 7e2eab5c72a2dac54126bc49bc49691931d8dda0
Reviewed-Content-Hash: docs/architecture/adr-0005-stat-accessor-read-context-contract.md 4a2fba915d192605197e55e326f5c867e6354cf2
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-signal-contracts-view-allowlist.md ef2faea37127d471a4d99607607e3c3d16804956
Reviewed-Content-Hash: docs/architecture/adr-0008-input-resolver-core-signal-contract.md 784dd51eecd37f86856684ec15e0672ed0f09866
Reviewed-Content-Hash: docs/architecture/adr-0009-enemy-entity-roster-combat-api.md 7f9118e71e50d26053cd7a4963f2e2bc21fac7c6
Reviewed-Content-Hash: docs/architecture/adr-0010-sim-input-split-command-results-dev-telemetry.md ea7126f7d91f398ee3b8691058e4a0a01a37b340
Reviewed-Content-Hash: docs/architecture/adr-0011-battle-field-rendering-draw-call-budget.md 3b6392fac48d19a4135579da56de56c5730239b9
