# Review Log: Enemy & Wave

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, level-designer, economy-designer, qa-lead, creative-director
Blocking items: 7 | Recommended: 12
Summary: The layout, HP, lives and gold arithmetic all reproduce, and the design's direction holds: one path and one stage are stated MVP scope, so they do not block. The blockers are claims the doc cannot back (stage length), one soft-lock in `d_next`, a packet metric every starter group breaks, layout margins of 0 to 1 against an unmeasured inset, and criteria that cannot pass on their own fixture. All are local fixes.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Dependencies, Cross-References: Tower, Hero and Battle HUD are listed as having no GDD yet; all three exist and name this GDD.
- [BLOCKING] Starter values (line 102): 5.2 and 3.8 minutes do not reproduce; the doc's own model (kills at 60%, 15 s intermissions) gives 4.4 and 3.2. State the kill depth, cite the sim or say there is none, and add an advisory duration criterion.
- [BLOCKING] Formulas, d_next: a `move_speed` or `speed_factor` of 0 stalls an enemy and the wave never clears; a negative value leaves position undefined. Guard it and say what the validator does. Guard `catch_up` at equal speeds too.
- [BLOCKING] Formulas, packet_length: the target `packet_length ≤ 2 × burst_radius` (140) fails for every starter group, including the doc's example (180); it measures group length, not density. Replace it with a spacing metric.
- [BLOCKING] Layout rules L1, L6: margins of 1 and 0 against an unverified 68 dp top inset; dp and canvas units are not reconciled (a 59 pt notch is about 82 units). Settle units and re-author with 12 to 16 of margin; check that a taller screen cannot show the exit at y 960 to 980.
- [BLOCKING] Acceptance Criteria: C5, C7, C9 expect `wave_cleared` on a one-wave fixture that would emit `waves_complete`; C5 needs a cost-2 enemy; C11 cannot tell a from b; C18 must list its rules; C19 is past tense; C1 misses the edge ticks; pin `dt` in the factory, which also settles AC13's same-tick collision.
- [BLOCKING] Open Questions (line 435): "instant retry" accepts compounding loss here and in Tower line 229, while Tower line 47 rejects selling because retry undersells the price. Reconcile it; reword the question around lives, which never regenerate.
- [RECOMMENDED] Wave groups: reserve an optional `path_id`, default 0, so pulling lanes forward is not a data migration; state a pinned-once margin to beat at first playable.
- [RECOMMENDED] Header (line 8): say the design enables Pillar 3, not delivers it; make the stage 2 and 3 sketch a Vertical Slice entry condition.
- [RECOMMENDED] Deferred criteria: define "first baseline", "build scripts", "mono-role" and "mixed"; Burst fit uses 4 while line 230 says 5; restate Empty field as a measured threshold, since wave 2's field is empty about 3 s, not 9.
- [RECOMMENDED] Formulas: HP ratio floor is 1.26; half-tick ties can collide; tie the interval floor to `dt`; let count 1 omit `spawn_interval`; peak bound assumes slows do not stack; match domains to content bounds; name L5's radius 15; forbid same-type groups on one tick; say `path_length` is the full 1,720.
- [RECOMMENDED] Layout rules: add a lower y bound and build-arc clearance for slots D and E; a minimum turn angle and segment length; scope L11 by property and clip it to the field; state L10's range source; add a mirrored fixture.
- [RECOMMENDED] Waves: the Two fronts gate uses straight-line distance on a folded path; wave 4 has a catch at 518, before the hairpin; wave 5's "early leak" is an outcome; wave 6 does not fully converge; consider one lull wave.
- [RECOMMENDED] Economy: add a bounty lower bound; define "full board" and the 54 gold margin; say bounties are pegged to count, not HP; wave 6's 174 gold arrives too late to spend.
- [RECOMMENDED] Wave rules: idle wave 1 leaves 2 lives against 12 at risk in wave 2; the 120 against 10 total check is trivial.
- [RECOMMENDED] Missing sections: add Tuning Knobs with safe ranges and a Player Fantasy line; register the enemy and stage values in entities.yaml.
- [RECOMMENDED] Game Feel, Visual: fast enemies get 2.2 s of danger warning against a 2 s re-pin walk; give the feel lines playtest questions with pass criteria.
- [RECOMMENDED] Acceptance Criteria: split bundled criteria; add a dev-error sink seam; cover speed 2,000, `lives_cost` 0, overshoot, off-field burst, short path and the two read accessors; make the manual screenshot line pass or fail; name test files.
- [RECOMMENDED] Detailed Rules: run a build-counter check at MVP, two builds each beating a different wave.
- [RECOMMENDED] Structure: split the layout rules and test specs out if the doc keeps growing.
Reviewed-Content-Hash: design/gdd/enemy-wave.md b54c78785944be6bfd376a6a80eca92dca9c770f
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 3d5b79031d45c84e007b288e1998a9df110c0ac2
Reviewed-Content-Hash: design/gdd/tower-system.md cf723cfe4b3dddc56688772c9678adb7b9c0de12
Reviewed-Content-Hash: design/gdd/combat-damage.md 9fe61dab43d04486b54833702d9215b1c72762b5
Reviewed-Content-Hash: design/gdd/hero-system.md 1f980cde56d56f1a28f2806b0c4a1c0927f168a3
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/battle-hud.md 1b140d9f6ac912e83e0fdad2caf8f19b63d8e187
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b81528a4102d977ed04d869e0f4ecc9a1b117559
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, level-designer, economy-designer, qa-lead, creative-director
Blocking items: 3 | Recommended: 10
Summary: All 7 prior blockers are resolved, and the design, numbers and layout hold up when recomputed. What remains is two acceptance criteria that cannot pass or cannot fail as written (C6 case 2, C10), and three stale lines in Battle HUD and Hero left over from the stage move. About an hour of edits, with no design change.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Acceptance Criteria, C6 case 2: expects position (10, 980), but Rule 13 halts on the `move_speed` read before use, so d stays 50 at (10, 970). Name the read that latches.
- [BLOCKING] Acceptance Criteria, C10: both enemies pay bounty 4, so the order check cannot fail; the THEN also omits `wave_cleared(2.0)`.
- [BLOCKING] Cross-document: Battle HUD line 127 still says slot y 305; line 134 claims arc panel clearance, but the panel now reaches y 164, 10 into the band at the largest inset; Hero line 4 still says re-pinning is worth about 3 lives.
- [RECOMMENDED] Deferred criteria: Two fronts gate does not discriminate (a wave 1 string spans over 180); require a fast and a non-fast over 180 apart.
- [RECOMMENDED] Layout rules, Manual: the masking rule has no criterion; add 9:19.5 and 4:3 screenshots; say whether insets apply over letterbox bars and what input on the bars does.
- [RECOMMENDED] Deferred criteria: stage length floor of 5 minutes sits on the script's 5.0; define the measurement and require a win.
- [RECOMMENDED] Formulas, Open Questions: define "full board" and compare it with gold before wave 6 (at most 496); 68 gold is a worst case, about one tower.
- [RECOMMENDED] Waves: wave 6 "everything converges before the exit" is false for the tail group; add wave 4's 518 catch.
- [RECOMMENDED] Header, Open Questions: Pillar 3 is enabled, not delivered; merge the two re-pin questions and add a numeric trigger for lanes.
- [RECOMMENDED] Acceptance Criteria: C4, C5, C6, C12, C14, C16, C18, C19 and C20 need counts, values, IDs or an extra case; drop the file output from C20.
- [RECOMMENDED] Economy: say bounties follow count and `lives_cost`, not HP; cap `intermission_duration`.
- [RECOMMENDED] Layout rules: build-arc discs over the path are unstated; L9 to L11 are fitted to the starter stage, so later stages need a burst-bend rule.
- [RECOMMENDED] Game Feel, Waves: no pass criteria; wave 1 is a pure string; no lull inside waves.
Reviewed-Content-Hash: design/gdd/enemy-wave.md 4787fc0fcfe528357d441bf2be73cd3b741652d4
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 3d5b79031d45c84e007b288e1998a9df110c0ac2
Reviewed-Content-Hash: design/gdd/tower-system.md 73aeab735d3511e2c67be2fca7deea1d3cdd5f2e
Reviewed-Content-Hash: design/gdd/combat-damage.md 9fe61dab43d04486b54833702d9215b1c72762b5
Reviewed-Content-Hash: design/gdd/hero-system.md 71766f6b9722fd231212281a50efbece710a5ed3
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/battle-hud.md af284f3429e50b681d9fec23fdf16d6c64627b57
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b81528a4102d977ed04d869e0f4ecc9a1b117559
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, level-designer, economy-designer, qa-lead, creative-director
Blocking items: 3 | Recommended: 11
Summary: The second review's C6 case 2 and C10 are fixed, and four specialists reproduced every number. Three narrow blockers remain: Battle HUD's prompt covers the top path row on notched phones, C6 case 4 cannot fail, and two "about 3 lives" lines are still stale. The creative-director lowered the game-designer's Pillar 2 and fast-enemy blockers to recommended, since the user already accepted those terms for MVP.
Prior verdict resolved: Partly (2 of 3; the stale-line item is still open in Hero line 444 and concept line 249)
Findings:
- [BLOCKING] Layout rules, cross-document: Battle HUD's prompt (centre y I_top + 104, 34 tall) covers the top path row (edge y 190) from I_top 69 up, in every phase, and slot 0's top arc disc. This breaks the "never under a panel" rule (Rule 4). Docking it in the band makes L6 208 and moves the top row to y 244, so path length becomes 1,686 and L2 keeps no margin; the sim needs a rerun.
- [BLOCKING] Acceptance Criteria, C6 case 4: does not say when the latch fires, so a slot-entry-only check passes. Latch on the bounty read, assert the corpse stays in roster() and no clear, and add a two-corpse case latching on the first enemy_killed.
- [BLOCKING] Cross-document: hero-system.md line 444 and game-concept.md line 249 still say re-pinning is worth "about 3 lives"; this GDD and Hero Rule 7 say 1 to 4, median 2.
- [RECOMMENDED] Enemies: fast enemies' "asks for slow or a re-pin" (line 65) is untested, since the Two fronts gate checks geometry only; add a never-pinned leak criterion for waves 3, 5, 6 or restate their role.
- [RECOMMENDED] Open Questions, Deferred criteria: name the bot, waves and threshold for the lanes trigger and the driven margin.
- [RECOMMENDED] Formulas: integer tick rate; validate spawn ticks strictly rising per group; spacing from quantised ticks; path_length as cum[n]; largest gap in ticks; start_delay 0 to 600 against the 12 s cap.
- [RECOMMENDED] Economy: early-call bonus is worth 2 to 8 gold, so always-call dominates; say so or change the cost, and fix the Always-call rationale.
- [RECOMMENDED] Economy: the slow plus slow opening spends all 120 on no damage with no sell, and wave 1 pays 40 against a 50 tower; gate it or name it a trap.
- [RECOMMENDED] Open Questions: reword the leak cost around purchase delay; add a recovery bot scenario.
- [RECOMMENDED] Layout rules: 26% of the in-field path is covered by no slot, and slots 3 and 4 cover the same stretch; add a union rule or restate line 26.
- [RECOMMENDED] Layout rules: Start/Call with L3 and L7 force every exit run into x 270 to 356; make it a Stage field or accept it before claiming Pillar 3.
- [RECOMMENDED] Acceptance Criteria: fixtures for C6 cases 2, 3, 5; exact IDs in C20 and two copies for min_lives_waves; coverage gaps; read-at-use in C3 and C4; deferred thresholds need a setting method; manual checks need signers and counts.
- [RECOMMENDED] Waves, Game Feel: wave 1 teaches no burst; no dip before wave 6; flat 15 s intermissions; no "loss feels fair" check.
- [RECOMMENDED] Layout rules, Formulas: L13 turn angle and segment length; L11 disc centre in field; masking as a clip; cap max_slow; peak_alive_ub off by one; bounty safe ranges (54 gold headroom); wave 6 text: only 3 of the last 8 normals catch the last heavy.
Reviewed-Content-Hash: design/gdd/enemy-wave.md 42576cc3659a90519d9986cd0c8ce9819b85f9a0
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 3d5b79031d45c84e007b288e1998a9df110c0ac2
Reviewed-Content-Hash: design/gdd/tower-system.md 73aeab735d3511e2c67be2fca7deea1d3cdd5f2e
Reviewed-Content-Hash: design/gdd/hero-system.md debf0092334099aea64b5ce771f798c7711d1452
Reviewed-Content-Hash: design/gdd/battle-hud.md 2e4bd49127174290d01f7e829c096530820186fe

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, level-designer, economy-designer, qa-lead, creative-director
Blocking items: 3 | Recommended: 9
Summary: Commit 17e8927 closed all three third-review blockers, and every number and formula reproduces. The fix itself added a false Rule 4 claim, a fatal leak or final kill had no test that a missing halt guard would fail, and the moved prompt met slot 0's arc panel at the largest inset. All three are text and test edits with no design rework.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Core Rules, Rule 4: "every lasting panel in the top band" is false; the Lost and Won panels cover the field. Reword to panels shown while enemies move, and align art bible §7.
- [BLOCKING] Acceptance Criteria, C6: no case fails an unguarded clear after a fatal leak or a halting kill; add a one-entry single-`e` leak latch and a single-kill latch.
- [BLOCKING] Cross-document, Battle HUD: at inset 102 the prompt (y 142 to 172) overlaps slot 0's top arc panel (to y 164) during the first build; hide the prompt while an arc is open.
- [RECOMMENDED] Battle HUD Rule 13: a player who never pins keeps prompt 1 and loses the next-wave line all stage; limit prompts 1 and 2 to before the first Start or Call.
- [RECOMMENDED] Core Rules, Rule 11: corpse removal and signal order unstated; remove first as Rule 10 does, and assert the first corpse in C6.
- [RECOMMENDED] Acceptance Criteria, C6 cases 2 and 3: "criterion 5's fixture" should be "one `e`".
- [RECOMMENDED] Acceptance Criteria, C14: swap the authoring order so a member-first scan fails.
- [RECOMMENDED] Cross-document, Battle HUD: Play again (y 868 to 940) is not clamped to the bottom inset.
- [RECOMMENDED] Acceptance Criteria, C20: one broken copy per clause of L1, L3, L5 and L13, not per rule ID.
- [RECOMMENDED] Formulas: at the 30 s intermission cap, gold before wave 6 is 536, so the full-board guard has 14 gold headroom, not 54.
- [RECOMMENDED] Game Feel: add a foresight survey item for wave 5's first fast front.
- [RECOMMENDED] Acceptance Criteria, C4: the Health clause has no probe until Combat's ADR.
Reviewed-Content-Hash: design/gdd/enemy-wave.md c924907b3d909870d357c27ab89c5a7a43e76a74
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ed25cb702da175ffd4e9fbebb4a42b147cbffa0d
Reviewed-Content-Hash: design/gdd/tower-system.md 73aeab735d3511e2c67be2fca7deea1d3cdd5f2e
Reviewed-Content-Hash: design/gdd/hero-system.md 6318793eec275f8d1f5e0bd0b3c3f7a2a7d5aa5f
Reviewed-Content-Hash: design/gdd/battle-hud.md 215af862f7a01649cb10e1928084654fc667789a
