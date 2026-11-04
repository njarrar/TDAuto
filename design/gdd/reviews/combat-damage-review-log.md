# Review Log: Combat & Damage

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, ai-programmer, gameplay-programmer, creative-director
Blocking items: 8 | Recommended: 8
Summary: The design is sound: arithmetic, tick order and the one-path model all hold. The defects are API contracts implementers would have to guess, plus acceptance criteria with no expected values. Nothing strategic needs the user; the only open option is reopening the 75% splash gate, and the creative director recommends leaving it.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Rule 7, Rule 9, Dependencies: `apply_slow` has no signature, and Tower's seconds need `dt` and `to_ticks`, contradicting "depends on nothing" and "Upstream: none".
- [BLOCKING] Rule 10: helpers have no signatures or empty returns; "furthest along", range, victim order and "unslowed" are undefined.
- [BLOCKING] Core Rules, Rule 3: what an `enemy` exposes, and what `deliver` returns for a dead or removed enemy, are unstated.
- [BLOCKING] Rule 12: signal arguments have no types, the death disc has no trigger, and views could hold a reaped `event.target`.
- [BLOCKING] Acceptance Criteria: invariant `I` uses exact float equality, has no scope for reaped enemies, and its evidence is not a kept test.
- [BLOCKING] Deferred criteria: the Pillar 2 and splash rows drifted from Hero's table, which owns the thresholds.
- [BLOCKING] Dependencies: Battle HUD listed against the wrong interface, Hero's `report_attack` and `hp_left` missing, one stale sentence.
- [BLOCKING] Acceptance Criteria: AC 10 and 11 have no expected values; removed enemy, empty burst, ±INF, counters after the outcome and buffed-tower attribution have no criteria.
- [RECOMMENDED] Visual Requirements: name the clearance suppressor and trigger; the window is defined in Hero.
- [RECOMMENDED] Visual Requirements: view timers on the frame clock; flash state per enemy in the view.
- [RECOMMENDED] Visual Requirements: retrigger keeps the higher alpha, evict tower flashes first, state burst flash alpha.
- [RECOMMENDED] Formulas: store at least 1 tick for a slow and expire at or below 0; a 0-tick slow is reachable only in fixtures.
- [RECOMMENDED] Edge Cases: "gets the kill" is untestable, as Combat keeps no kill counter.
- [RECOMMENDED] Formulas: "never a stun" overclaims for a strength near 1.
- [RECOMMENDED] Acceptance Criteria: split bundled AC 2 and 12; add pass/fail thresholds to the Manual items.
- [RECOMMENDED] Tuning Knobs: section absent (advisory at standard).
Reviewed-Content-Hash: design/gdd/combat-damage.md 9fe61dab43d04486b54833702d9215b1c72762b5
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: design/gdd/hero-system.md 46ad9bcd91aba136a13a06cea4ab80b6f14eb118
Reviewed-Content-Hash: design/gdd/enemy-wave.md 1bd009a5c7b32416c88350ff0f1adb16df3da819
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/battle-hud.md 06b90a96f9ffef54b0f7ea5de79ddb809bdba094
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 72c80e73e19aaff142fbf3c22477bdecfd092e99
Reviewed-Content-Hash: design/gdd/game-concept.md 74aec3a9e2b7094565a249d773621ecaee83c7c7

## Revision — 2026-11-03 — Eight blockers and six recommended items applied, re-review pending
All eight blockers are applied in `design/gdd/combat-damage.md`, along with the clearance owner, view clocks, flash priority, the 1-tick slow minimum, the "kill" rewording and the "stun" correction. Not applied: splitting AC 2 and 12 (AC 2 gained cases instead), Manual thresholds and the Tuning Knobs table.
Decided without asking, in autonomous mode: `radius` 0 for a single-target `attack_fired`, `source_id` as `StringName`, tie handling in `nearest_in`, a 0.001 tolerance on the real-stage invariant, and hero-share wording changed from "lower bound" to approximate (creative director's ruling, retracting its own earlier note).
Not done: the creative director's Data & Config row for slow strength, because Tower's content test already caps `slow_strength` at 0.6. No Tower or Hero edit was needed: both already match. No balance number changed, so the bots were not re-run.

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, ai-programmer, gameplay-programmer, creative-director
Blocking items: 6 | Recommended: 10
Summary: The design holds: the numbers, tick order and leash all checked out. About 19 raised blockers reduced to 6 contract defects, each a sentence or two; only contract defects block this GDD, while balance goes to owning GDDs and engine mechanism to the ADR. Nothing needs a user decision to unblock.
Prior verdict resolved: Yes (all 8 prior blockers addressed; 4 only partly by qa-lead's count, remainder carried below)
Findings:
- [BLOCKING] Rule 10, AC 10: "scan rather than sort" contradicts feeding 3, 1, 2 and demanding 1, 2, 3.
- [BLOCKING] Rule 10: `is_dead` has no signature, owner or criterion, yet three systems call it.
- [BLOCKING] Rule 4, AC 13: "removed enemy" is undefined, so the criterion cannot be written.
- [BLOCKING] Rule 5: the counter read API, per-kind sums and `source_id` type are unnamed.
- [BLOCKING] AC 2, Rule 3: the required development error is not asserted, and the term is undefined.
- [BLOCKING] Dependencies, Interactions: Hero's `burst_started`, the clearance end and Battle HUD are misdeclared.
- [RECOMMENDED] AC 9, Order row: apply-after-countdown order and re-apply are untested.
- [RECOMMENDED] Rule 12: `damage_applied` timing relative to commit is unstated.
- [RECOMMENDED] Rule 7: `apply_slow` has no return statement and no input guard.
- [RECOMMENDED] Visual Requirements: flash marker scope is undefined.
- [RECOMMENDED] Acceptance Criteria: negative test of `I`, AC 10, 11 and 12 wording.
- [RECOMMENDED] Manual: items lack pass/fail observations; numeric thresholds not adopted, as none has a source.
- [RECOMMENDED] Core Rules: ADR questions should be named (enemy shape, attachment, registration, `position`).
- [RECOMMENDED] Open Questions: clearance suppression may hide tower contribution (Hero owns; device check).
- [RECOMMENDED] Rule 10: `range` shadows GDScript's global function; slot-empty test over factor 1; coil-geometry and two-slow-tower cases.
- [RECOMMENDED] Hero Rule 4: the "amends Combat Rule 10" note is stale (Hero's to fix).
Reviewed-Content-Hash: design/gdd/combat-damage.md 54b8161d0a51c448a2721ade96830ea690c01c81
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: design/gdd/hero-system.md 46ad9bcd91aba136a13a06cea4ab80b6f14eb118
Reviewed-Content-Hash: design/gdd/enemy-wave.md 1bd009a5c7b32416c88350ff0f1adb16df3da819
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/battle-hud.md 06b90a96f9ffef54b0f7ea5de79ddb809bdba094
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 72c80e73e19aaff142fbf3c22477bdecfd092e99
Reviewed-Content-Hash: design/gdd/game-concept.md 74aec3a9e2b7094565a249d773621ecaee83c7c7

## Revision — 2026-11-03 — Six blockers and eight recommended items applied, re-review pending
All six blockers are applied in `design/gdd/combat-damage.md`, along with AC 9's tick script and re-apply case, the Order row, commit timing, `apply_slow`'s return and guard, marker scope, the `I` negative tests, AC 10 to 12 wording, Manual observations, the ADR questions and the clearance Open Question. `design/gdd/enemy-wave.md` Rule 14 gains the `removed` field.
Not applied: `range` rename, slot-empty test, coil and two-slow-tower cases, the 400-check derivation, the Player Fantasy and Tuning Knobs sections, Hero Rule 4's stale note. AC 11's slow-tower case is dropped on the user's approval, as the creative director advised: it duplicated Tower's criteria. Clearance suppression stays until the device check, also on the user's approval.
Decided without asking, in autonomous mode: a `removed` flag set by Enemy & Wave rather than deleting the guard, `all_in_radius` preserving input order, the counter read names, `hero_share()` as a read, a death disc using no flash marker. Rejected: splash cap and per-cooldown metric (reverses Rule 6), `unslowed_only` param (micro-optimisation), an error sink (gdUnit4's `assert_error` exists). No balance number changed, so the bots were not re-run.

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, ai-programmer, gameplay-programmer, creative-director
Blocking items: 4 | Recommended: 21
Summary: The design holds: formulas, tick order and every earlier blocker were confirmed by independent checks. Four contract defects remain, each a sentence or two: `spawn_id` missing from `damage_applied`, error criteria the test tool cannot count, slow criteria with no observable read, and an unnamed Status countdown. Nothing strategic needs the user.
Prior verdict resolved: Yes (all 6 prior blockers confirmed fixed)
Findings:
- [BLOCKING] Rule 12, View clocks: flash state is keyed by `spawn_id`, which `damage_applied` offers only through `event.target`, which views must never use.
- [BLOCKING] AC 2, 7, 13: `is_push_error` matches a message and does not count, and the GDD defines no messages, so "one development error" cannot be asserted.
- [BLOCKING] AC 7, 9: the slow slot has no read, so "keeps 1.0", "gives 2.0" and "never holds above 4" are unobservable, and AC 7 names no `dt`.
- [BLOCKING] Rule 11, AC 9: the Status countdown has no call name, signature or stated behaviour, though three GDDs depend on it.
- [RECOMMENDED] Deferred Order row: the between-ticks clause is Hero's, and two clauses have no matching owner criterion.
- [RECOMMENDED] AC 12: "fires after commit" is untested.
- [RECOMMENDED] Edge Cases, markers: BURST rank, "oldest", tower evicting hero and suppressed flashes are unstated.
- [RECOMMENDED] Rule 7: `apply_slow` on a removed enemy is unspecified.
- [RECOMMENDED] Rule 3: the check order across removed, amount and dead is unstated.
- [RECOMMENDED] Acceptance Criteria: "binary-exact" is undefined.
- [RECOMMENDED] Rule 10: `range` shadows GDScript's global function (second time raised).
- [RECOMMENDED] AC 10: `all_in_radius` feeds 1, 2, 3, so a sorting implementation passes.
- [RECOMMENDED] Edge Cases: "the lower slot deals the real damage" is true only if its hit kills.
- [RECOMMENDED] Interactions: Hero's row omits `is_dead`, which Hero Rule 16 uses.
- [RECOMMENDED] Enemy & Wave deferred: "Thresholds live in Combat" is stale; Hero's table owns them.
- [RECOMMENDED] Left, caller bugs: 1e30 seconds and a 1e-17 strength.
- [RECOMMENDED] Left, goes with spawn registration on the ADR list: `max_hp` guard.
- [RECOMMENDED] Left: extra `I` clauses, further AC splits, Manual thresholds, AC 16.
- [RECOMMENDED] Sent to the ADR, unverified against the engine reference: object lifetime, reference cycles, `class_name` and `list` typing.
- [RECOMMENDED] Sent to the first phone measurement: 400 checks per tick at the catch-up clamp.
- [RECOMMENDED] Tower's and Hero's to fix: `report_attack` `impact` and `radius` wording, `source_id` conversion.
Refuted by checking sources: a stuck clearance window from a cancel (Hero's cancel is the aim, before `burst_started`; Telegraphing has no cancel; retry rebuilds the battle); a leaked enemy being targeted (Enemy & Wave Rule 14 excludes it); signals missing from Flow's allowlist (each system declares its own, as Tower and HUD do).
Reviewed-Content-Hash: design/gdd/combat-damage.md fe71efd384e6c9a9a6f614723c2572742d237125
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: design/gdd/hero-system.md 46ad9bcd91aba136a13a06cea4ab80b6f14eb118
Reviewed-Content-Hash: design/gdd/enemy-wave.md ba3d21b305aedd92681205bd470998093d17b2ea
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/battle-hud.md 06b90a96f9ffef54b0f7ea5de79ddb809bdba094
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 72c80e73e19aaff142fbf3c22477bdecfd092e99
Reviewed-Content-Hash: design/gdd/game-concept.md 74aec3a9e2b7094565a249d773621ecaee83c7c7

## Revision — 2026-11-03 — Four blockers and eleven recommended items applied, re-review pending
All four blockers are applied in `design/gdd/combat-damage.md`: `spawn_id` on `damage_applied`, fixed guard messages with one invalid input per case, slow criteria restated as reads at `dt` 0.25, and `tick_status(roster)` named with its behaviour. Also applied: the Order row split, a commit-timing case in AC 12, marker ranking, `apply_slow` on a removed enemy, the check order, a definition of "binary-exact", `range` renamed `max_range`, AC 10's input order, the contested-kill wording and Hero's `is_dead` row. `design/gdd/enemy-wave.md` gains the corrected threshold pointer, the `tick_status` name and a tick-order row. `design/gdd/hero-system.md` gains `is_dead` in two lists and a between-ticks row.
AC 9's "never holds above 4" is restated rather than removed: ticks 1 to 14 read slowed and tick 15 reads 1, which the same behaviour implies.
Not applied: the items marked Left and Tower's and Hero's to fix in the review above. The ADR list and the 400-check Open Question gained the items sent to them.
Decided without asking, in autonomous mode: revising now, `max_range` rather than `reach`, which is already a Hero stat, the names `tick_status`, `ERR_REMOVED`, `ERR_BAD_AMOUNT` and `ERR_BAD_SLOW`. The `report_push_errors` setting is left off: the first test story turns it on. No balance number changed, so the bots were not re-run.

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean)
Blocking items: 0 | Recommended: 6
Summary: All four blockers from the third review are confirmed applied (`spawn_id` on `damage_applied`, named `ERR_*` guards, slow criteria as reads, `tick_status`), and the AC 7 and 9 tick scripts were traced by hand and hold. Names, signatures and values agree with Tower, Hero, Enemy & Wave and Data & Config. No specialist ran, and the three full reviews each found new contract defects (8, 6, 4), so this is a single-session approval; the first test story and the ADR are where a remaining gap would show.
Prior verdict resolved: Yes (all 4 prior blockers confirmed fixed)
Findings:
- [RECOMMENDED] Core Rules, Dependencies: the ADR list (enemy object kind, Health and Status attachment, spawn registration, ownership, `list` typing) is a prerequisite for the first Combat story and should be said so.
- [RECOMMENDED] Rule 12: `damage_applied` carries `event`, which holds `target`; "views never use `event.target`" is a convention with no criterion, so add it to the code-review list.
- [RECOMMENDED] Acceptance Criteria, Manual: the non-developer legibility test has no threshold until qa-lead sets one (carried from earlier reviews).
- [RECOMMENDED] Visual/Audio Requirements: 80/100/120 ms, alpha 0.6, 16 markers and 0.15 s are literals in the GDD; name them as view constants. Tuning Knobs is absent (advisory at standard).
- [RECOMMENDED] Acceptance Criteria: `assert_error(...).is_push_error` and `report_push_errors` behaviour are unverified against the engine reference; confirm in the first test story.
- [RECOMMENDED] Dependencies: Visual Feedback & VFX and Stage Progression & Stars have no GDD yet (Vertical Slice, expected).
Reviewed-Content-Hash: design/gdd/combat-damage.md 6da728d91b21aa41e5e3ca5c611edc0c155539a1
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: design/gdd/hero-system.md c07e192cca761638aa22df0fa1f69848a07a956e
Reviewed-Content-Hash: design/gdd/enemy-wave.md cfc80084d4b46610e6de31ab9abcffe6910a899d
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/battle-hud.md 06b90a96f9ffef54b0f7ea5de79ddb809bdba094
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 72c80e73e19aaff142fbf3c22477bdecfd092e99
Reviewed-Content-Hash: design/gdd/game-concept.md 74aec3a9e2b7094565a249d773621ecaee83c7c7

## Revision — 2026-11-03 — Recommended items applied after the lean approval, not re-reviewed
Applied in `design/gdd/combat-damage.md`: the ADR stated as a prerequisite for the first Combat story, `event.target` added to the code-review list, a proposed legibility threshold of 8 of 10 kills, a Tuning Knobs section naming the view's constants with proposed safe ranges, and the corrected gdUnit4 setting, `gdunit4/report/godot/push_error`. The header status now reads Approved.
Decided without asking: the 8 of 10 threshold and every safe range are proposed values with no test behind them; qa-lead and the first phone build can change them. No rule, formula or balance number changed, so the bots were not re-run.
Checked: gdUnit4 6.2.0's source confirms `assert_error`, `is_push_error` and `is_success`, the setting's default of off, and that a leftover logged error fails the test. A runtime probe was denied at the permission prompt and not run, so the first test story keeps a negative test.
No edit for the Vertical Slice item: Visual Feedback & VFX and Stage Progression & Stars have no GDD to change yet, and Dependencies already requires them to list this one when authored.

## Revision — 2026-11-03 — cross-GDD warning pass
From design/gdd/gdd-cross-review-2026-11-03.md, Consistency Re-run. Two deferred rows acknowledged from Flow (full determinism, micro-battle). No rule changed; Approved stands.
