# Review Log: Hero System

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, creative-director
Blocking items: 6 | Recommended: 13
Summary: The design holds against the pillars; the defects are contract and test definitions. The pin clamp has no algorithm and refuses at the rect's corner, a read and a command share a name, and the bot gates rest on a script not in the repo. Run in the authoring session, so the specialists were independent and the synthesis was not; a fresh-session re-review should follow the revision.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules 2, 12, 14: clamp needs min-distance over a candidate set and a tolerance; (492,888) must give (352,888); state pin_exclusion's shape and where 104 lives.
- [BLOCKING] Core Rule 16: pin(position) command and pin() read clash in GDScript; rename the read.
- [BLOCKING] Acceptance Criteria 28, 29: equivalence and never-touched are not implementable as written.
- [BLOCKING] Acceptance Criteria 1, 2, 6, 11-15: undefined fixtures and unobservable aim state.
- [BLOCKING] Deferred criteria: "4 above" fails on single-only and slow-only, so scope to mixed builds; tighten Dominant build.
- [BLOCKING] Simulated results: add a bot parameter table; no bot script exists in the repo.
- [RECOMMENDED] UI Requirements: hint text and locked feedback, route to /ux-design.
- [RECOMMENDED] Formulas: walk ratio as float and assign the pin at walk_left 0; walk_ticks short hops run 1.5x speed.
- [RECOMMENDED] Acceptance Criteria 25: cite to_ticks rounding and pick better values.
- [RECOMMENDED] Acceptance Criteria: coverage gaps and manual evidence list, at story level.
- [RECOMMENDED] Deferred criteria: radius phone pass mark at MVP+.
- [RECOMMENDED] Core Rule 8: stale "44 units", now 27.5.
- [RECOMMENDED] Core Rule 4: "one ring" is false with reach.
- [RECOMMENDED] Dependencies: Battle HUD now has a GDD; Combat still says the burst releases next tick.
- [RECOMMENDED] Core Rule 7: effective reach during a walk is 220, and pin then burst measures from the old position.
- [RECOMMENDED] Core Rule 12: aim cannot reach the path's last 30 to 78 units, and bots ignore the offset.
- [RECOMMENDED] Core Rule 16: commands from a handler mid-tick; hero_pinned timing; interface gaps.
- [RECOMMENDED] Visual/Audio: reach dots at alpha 0.35 likely fail 3:1; gold and white-gold use to check against the bible.
- [RECOMMENDED] Formulas: hero_share_bound cadence allows 30 bursts, 58%; burst_safe_distance unbounded below.
Reviewed-Content-Hash: design/gdd/hero-system.md 25f137389aff67a4686a49e44cdf9e8646647be7
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 827afe61e2bdd72bec6b82ee2774f4727c1f2885
Reviewed-Content-Hash: design/gdd/combat-damage.md 1dc2f7e50108bda144bdb05a9f03f6ac962784bd
Reviewed-Content-Hash: design/gdd/enemy-wave.md b54c78785944be6bfd376a6a80eca92dca9c770f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md ce4bd37fa46552d33d7035804f750475320db550
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md b3ade581d79c340adf236a11d85202bf8e764b77
Reviewed-Content-Hash: design/gdd/tower-system.md 763823b55c9bc4171fa4ad94c5f63793351a286b
Reviewed-Content-Hash: design/gdd/battle-hud.md a57d8a6778580b52c5a1e1246c2927f61864d8b8

## Revision — 2026-11-02 — Six blockers applied, re-review pending
Applied in the authoring session: clamp_pin with a tolerance and a typed pin_exclusion; pin() read renamed pin_target(); ACs 28 and 29 rewritten; fixtures and aim reads defined; gate wording scoped; bot parameter table added. User decisions: no pin under Start/Call (a disc of radius 104 added; bots re-run, results unchanged); radius 70 phone pass mark of at most 25% empty bursts and median kills of at least 2. Also fixed: stale 44 units, "one ring", Hero and Combat dependency text, walk_ticks. Bot scripts are still not in the repo.

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, creative-director
Blocking items: 6 | Recommended: 10
Summary: One short pass, with no redesign; the pillars and conclusions hold. The clamp_pin rule can miss the true nearest point, two criteria cannot test what they claim, and the results table is stale against the corrected simulation. Again run in the authoring session, so the specialists were independent and the synthesis was not.
Prior verdict resolved: Partly. The name clash, fixtures, gate wording and parameter table landed; the clamp rule was defined but is wrong at (480,850).
Findings:
- [BLOCKING] Formulas, clamp_pin; Acceptance Criteria 14: candidates must add both flat sides, endpoint circles and rect corners, with a fixed degenerate direction, tie epsilon, working type, and a brute-force nearest check.
- [BLOCKING] Core Rule 14: name PinGeometry.is_valid and PinGeometry.clamp, headless, since bots call the clamp.
- [BLOCKING] Acceptance Criteria 12: passes vacuously after the first OK; use fresh state per point.
- [BLOCKING] Acceptance Criteria 2: use (352,850)/(353,850), (84,712)/(84,713), (186,696)/(186,697).
- [BLOCKING] Simulated results, Core Rule 7, Open Questions, Pinned once row: refresh against the corrected run (mid-skill 9,9,9,7; best pin 6,7,4,6; share median about 26).
- [BLOCKING] Acceptance Criteria 17, Burst outcome: define the median for even counts and empty sets, and per build or pooled.
- [RECOMMENDED] Formulas, walk_ticks: use max(1, ceil(distance / step - 1e-4)).
- [RECOMMENDED] Visual/Audio: reach dots to alpha 0.6, unless the art director overrules.
- [RECOMMENDED] UI Requirements: locked-press reason line, ghost hysteresis, exclusion outline, hit-test wording, to /ux-design.
- [RECOMMENDED] Acceptance Criteria 28, 29: snapshot and script names, at story level.
- [RECOMMENDED] Acceptance Criteria: manual evidence states and sign-off, at story level.
- [RECOMMENDED] Acceptance Criteria: fixture gaps for hero_start and repins, at story level.
- [RECOMMENDED] Deferred criteria: bot-table details, row label, Dominant build tightening, human sample sizes, at story level.
- [RECOMMENDED] Core Rule 16: signatures, result enums, re-entrancy guard, Build pending pin, at story level.
- [RECOMMENDED] Open Questions: bottom-tail row stands; simulation shows mixed builds unchanged with the thumb limit.
- [RECOMMENDED] Simulated results: slow-only cannot win at any skill; state it as a trap build.
Reviewed-Content-Hash: design/gdd/hero-system.md dd2bbe7eaa6e0333c8df168f8a9b29119cc0e3bb
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 827afe61e2bdd72bec6b82ee2774f4727c1f2885
Reviewed-Content-Hash: design/gdd/combat-damage.md 6752d513d2ea4eca4d31747a1087005417d40ee7
Reviewed-Content-Hash: design/gdd/enemy-wave.md b54c78785944be6bfd376a6a80eca92dca9c770f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 69fea420a0dcb2eddbd3da3f53b05e166c3167e0
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md b3ade581d79c340adf236a11d85202bf8e764b77
Reviewed-Content-Hash: design/gdd/tower-system.md 763823b55c9bc4171fa4ad94c5f63793351a286b
Reviewed-Content-Hash: design/gdd/battle-hud.md ab70307efbff1830a433cc8f2056f80511a8f1f4

## Revision — 2026-11-02 — Six blockers applied, re-review pending
Applied in the authoring session: clamp_pin candidates, tolerances and degenerate directions, checked against a 2-unit brute force; PinGeometry named and headless; ACs 2, 12, 14 and 17 rewritten; median defined; results refreshed from the corrected simulation. Also: walk_ticks tolerance, reach dots to alpha 0.6, slow only stated as a trap build, always-call gate scoped to mixed builds. User decisions: re-pinning accepted at about 3 lives, the slowest bot's 5 to 7 lives accepted, simulation committed at tools/balance-sim/hero_bots.py.

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, creative-director
Blocking items: 2 | Recommended: 10
Summary: Two short edits and no redesign; the pillars, the pin rule and the results hold. Criterion 14 cannot run as written, and a tap on a hero walking across Start/Call can call a wave. Run in the authoring session again, and the creative director asks for a focused check of the two edits rather than another specialist pass.
Prior verdict resolved: Yes, all six; the clamp rule matched fine boundary sampling at 374 invalid fingers, worst excess 0.010.
Findings:
- [BLOCKING] Acceptance Criteria 14: validity on the 8-unit grid; nearness against boundary samples at 0.5 spacing at notches, circle centres and a 20-unit grid over the bottom third, tolerance 0.03; tie (186,800) gives (186,695.99).
- [BLOCKING] Battle HUD Rule 10 and a criterion, with a Hero edge case: disable Start/Call while the hero's position is strictly under 104 from its centre; a test on pin_state() would deadlock in Build.
- [RECOMMENDED] Data Rule on pin_exclusion: state it as a list of shapes, each of a, b and radius.
- [RECOMMENDED] Simulated results: state median share as 26.2, or print the rounded form.
- [RECOMMENDED] Deferred criteria: name the towers-only bot in the Towers-only row.
- [RECOMMENDED] Simulated results: the script governs where the bot table differs; 6, 7, 4, 6 is a lower bound.
- [RECOMMENDED] Simulated results: drop "from 4 to 5 hit" or print it.
- [RECOMMENDED] Formulas, clamp_pin: at story level, Rect2 half-open, parallel test, tangents, tie in two passes, hero_start at r + 0.01.
- [RECOMMENDED] Core Rule 16: digit has two owners; walk field names; non-finite input, at story level.
- [RECOMMENDED] Deferred criteria: log time to first pin; re-pin pass number at first playable.
- [RECOMMENDED] Visual/Audio: kill contour hex, slot (170,700) note, to /ux-design.
- [RECOMMENDED] Core Rule 15: press nearer the hero than the button goes to the button; add a story test.
Reviewed-Content-Hash: design/gdd/hero-system.md a1babd6e8d68732fca301bb6fbcef6138ef1ef7b
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 3d5b79031d45c84e007b288e1998a9df110c0ac2
Reviewed-Content-Hash: design/gdd/combat-damage.md 6752d513d2ea4eca4d31747a1087005417d40ee7
Reviewed-Content-Hash: design/gdd/enemy-wave.md b54c78785944be6bfd376a6a80eca92dca9c770f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 69fea420a0dcb2eddbd3da3f53b05e166c3167e0
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md b3ade581d79c340adf236a11d85202bf8e764b77
Reviewed-Content-Hash: design/gdd/tower-system.md e36b8c7a04b724ebf610ebfcedbda7f839e66f87
Reviewed-Content-Hash: design/gdd/battle-hud.md ab70307efbff1830a433cc8f2056f80511a8f1f4

## Revision — 2026-11-02 — Two blockers applied, re-review pending
Applied in the authoring session: criterion 14 rewritten to a runnable check, which the script now performs; Start/Call disabled while the hero's centre is strictly under 104 from it (user decision), in Battle HUD Rule 10 and criterion 9, with a Hero edge case. Also: Data's pin_exclusion stated as a list of shapes, median share 26.2, towers-only bot named, script decides details the bot table omits, best pin a lower bound, "4 to 5 hit" dropped.

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, creative-director
Blocking items: 8 | Recommended: 6
Summary: No pillar concerns; the design converges. Eight short text fixes, two of them where the text is wrong: tick step 5 can set Ready during a telegraph, and the bot table contradicts the script it reports. About 20 items tagged blocking by QA and the programmer go to story level, as earlier reviews decided; the creative director asks for a focused check of the eight edits next.
Prior verdict resolved: Yes, both; criterion 14 runs, and Start/Call is disabled near a crossing hero.
Findings:
- [BLOCKING] Tick step 5: "If Cooling: subtract 1; at 0, Ready", since cooldown_left is 0 while Telegraphing.
- [BLOCKING] Edge Cases: a walking hero can pass over the burst button, e.g. (340,888) to (470,700) passes 56 from the right line; state who wins the press, and test it.
- [BLOCKING] Starter values, Rule 1: hero_start is 80 from the path inside a drawn leash of 90, so it looks broken; hide the leash until the first pin, or move hero_start and tighten the content rule.
- [BLOCKING] Formulas, clamp_pin: "always a valid point" is unproven for thin regions; add a fallback (hold the last valid pin) and drop the claim.
- [BLOCKING] Simulated results: the bot table contradicts the script on the mid-skill wait (counts only with an enemy in reach), the ceiling gate and the frozen intermission; correct those lines.
- [BLOCKING] Content rules: burst damage at least the max HP of normal and fast, protecting "kills what it touches" across a 5-point margin.
- [BLOCKING] Rule 6, criterion 12: cite Enemy & Wave Rule 4 for the inclusive field, and take the grid to 540 and 960.
- [BLOCKING] Formulas, clamp_pin example: 718.41 should be 718.42.
- [RECOMMENDED] Player Fantasy: write a short section; three blockers above protect the fantasy.
- [RECOMMENDED] Formulas, hero_share_bound: not a bound; example burst_mean 300 against about 324; say whether the 40% cap applies to the ceiling bot (27% to 42%).
- [RECOMMENDED] Formulas: dt in burst_safe_distance and its negative range; walk_ticks wording.
- [RECOMMENDED] Simulated results: state the share band's tolerance rather than a knife edge.
- [RECOMMENDED] Core Rules, Tick: name Combat's call that emits attack_fired, and list it in Combat.
- [RECOMMENDED] Open Questions: record the invulnerable hero as a known gap.
Reviewed-Content-Hash: design/gdd/hero-system.md 73b430f0197ec4c4d718ff8e5f573b4076cc84e5
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 3d5b79031d45c84e007b288e1998a9df110c0ac2
Reviewed-Content-Hash: design/gdd/combat-damage.md 6752d513d2ea4eca4d31747a1087005417d40ee7
Reviewed-Content-Hash: design/gdd/enemy-wave.md b54c78785944be6bfd376a6a80eca92dca9c770f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b1ed8303576fede3018cf2eaa956e5363d02d7ca
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md b3ade581d79c340adf236a11d85202bf8e764b77
Reviewed-Content-Hash: design/gdd/tower-system.md e36b8c7a04b724ebf610ebfcedbda7f839e66f87
Reviewed-Content-Hash: design/gdd/battle-hud.md 4eb1db4b0072cb030f6e13b8bf1c8dd4469421e4

## Revision — 2026-11-02 — Eight blockers and two user decisions applied, re-review pending
User decisions: (A) the UX rule replaces the Start/Call disable: a press inside the hero's grab disc is the hero's, decided at press, and only that overlap is dead; the same rule makes the hero outrank the burst button in Input. (B) the game designer's exclusion: only the active hand's burst line refuses pins, and every shape shrinks from 104 to 60, the hero's 56 plus 4, so no button's centre lies in the hero's disc.
Blockers: tick step 5 acts only while Cooling; a walk over the burst button is an edge case with a criterion; the unpinned hero shows its grab ring, not its leash; clamp_pin returns the current pin when no candidate is valid and skips degenerate pieces; the bot table now matches the script's wait, ceiling and intermission; burst damage is at least normal and fast HP; OFF_FIELD cites Enemy & Wave Rule 4 and the grid reaches 540 and 960; the clamp examples are recomputed. Also amended: Battle HUD Rule 10, Rule 12, the layout note and criterion 9; Input's priority table, Hero row and criterion 28; Data's pin_exclusion rule.
The script re-ran in both hands: every bot result is unchanged, and clamp_pin matches boundary sampling with a worst excess of 0.012. Recommended items from the review stay open.

## Revision — 2026-11-02 — Tower review's changes applied, re-review still pending
Single's level 2 damage is now 21 (Tower System, user decision), so the bot table and results are refreshed and two gates are added, upgrade order and placement. `report_attack` names the call behind `attack_fired`, closing the logged gap. Every gate passes, with the share median at 25.1%, the band's floor.

## Revision — 2026-11-02 — Enemy & Wave review's change applied, re-review still pending
A `heavy` now costs 3 lives (Enemy & Wave, user decision), so the bot table, best pins and skill sweep are refreshed. Every gate passes, with the share median at 25.1%.

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, creative-director
Blocking items: 5 | Recommended: 16
Summary: No pillar concerns and the design has converged: five contract fixes, down from eight, one of them needing a script re-run. The bot table and the mechanics hold; what is missing is where the hand and the IDs come from, the button's centre, two counter definitions, and one current set of re-pin figures. The creative director proposes a focused check of the five edits over a sixth full review.
Prior verdict resolved: Yes (the fourth review's eight blockers are applied)
Findings:
- [BLOCKING] Rule 2: the left-hand flag has no home in Data; `reduce_motion` has the same gap.
- [BLOCKING] Rule 8, Tick: the Hero's `def_id` and the Burst's ID are never sourced.
- [BLOCKING] Rules 13, 15: the burst button's centre is device-dependent through `burst_y`, and nothing carries it to HeroInput.
- [BLOCKING] Rule 16: `repins` and `kills_on_hit_3` membership are undefined, and deferred gates depend on them.
- [BLOCKING] Rule 7, Simulated results, Deferred: two sets of best-pin figures on a user-accepted trade-off.
- [RECOMMENDED] Rule 4, Handed to owning GDDs, header: stale text.
- [RECOMMENDED] Tick steps 4, 7: state the burst's `report_attack` impact and radius.
- [RECOMMENDED] Rules 2, 6, 14: one filter site and a type for the return codes.
- [RECOMMENDED] Rule 14: `pin_target()` before a first pin.
- [RECOMMENDED] Simulated results: real bots follow the rules in intermission, so results may shift.
- [RECOMMENDED] Rules 2, 6: the return value of a failed read inside a command.
- [RECOMMENDED] Simulated results: state the share band's tolerance; report median kills over all bursts; add a casual bot.
- [RECOMMENDED] Formulas: walk_ticks' "free moves" wording; `dt` in two variable tables.
- [RECOMMENDED] UI Requirements: a non-motion cue for a dead press under Reduce Motion.
- [RECOMMENDED] UI Requirements, Input: ring on press, reticle timing; Input's row disagrees.
- [RECOMMENDED] Visual Requirements: complete the Reduce Motion row.
- [RECOMMENDED] UI Requirements: non-kill victims and a zero-victim aim have no mark (`/ux-design`).
- [RECOMMENDED] Visual Requirements: say the preview shows current positions, up to 27.5 units from where a fast enemy lands.
- [RECOMMENDED] Open Questions: a burst does 17% to a heavy; record the risk for Enemy & Wave.
- [RECOMMENDED] Battle HUD log: mis-grabs, cancels per aim, presses captured by the hero.
- [RECOMMENDED] Player Fantasy, Tuning Knobs: absent (advisory at standard).
Refuted by checking sources: a stuck cooldown at 0 ticks (Data floors both at one tick, at the real `dt`); an unstated arrival-tick attack (criterion 18); a wrong aim-offset sign passing (criterion 28); an unreaped corpse among victims (Combat's helpers skip the dead); the aim dead zone as a defect (the hard hole is radius 48, no starter path enters it, and radius 70 covers it).
Reviewed-Content-Hash: design/gdd/hero-system.md c07e192cca761638aa22df0fa1f69848a07a956e
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 74aec3a9e2b7094565a249d773621ecaee83c7c7
Reviewed-Content-Hash: design/gdd/combat-damage.md 40ae59c616520d9cd4b3a5eea61c1ec824b8c0d8
Reviewed-Content-Hash: design/gdd/enemy-wave.md cfc80084d4b46610e6de31ab9abcffe6910a899d
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 72c80e73e19aaff142fbf3c22477bdecfd092e99
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: design/gdd/battle-hud.md 06b90a96f9ffef54b0f7ea5de79ddb809bdba094

## Revision — 2026-11-03 — Five blockers and the stale text applied, re-review pending
Applied in `design/gdd/hero-system.md`: `left_handed` and `reduce_motion` on Data's Input record, read by the builder; the Hero's ID and `burst_id` passed at build, with a content rule of exactly one Hero record; `burst_button_centre()` as the one button centre; `repins`, `kills_per_burst` and `kills_on_hit_3` defined, with cases added to criterion 16; Rule 7's figures replaced from a fresh run. `design/gdd/data-config-pipeline.md`, `design/gdd/battle-hud.md` and `design/gdd/game-concept.md` carry the matching changes. Rule 4's amend note and the done Combat bullet are removed.
The script re-ran on the starter stage, default, `--sweeps` and `--left`. The bot table, share median of 25.1% and sweep results match the GDD; only Rule 7's figures were stale, at 3, 2, 5 and 1 against 1, 1, 2 and 4 today. The change is a correction of text, not balance, and the gates are unchanged.
Awaits the user: they accepted about 3 lives at reach 160 on an earlier run, and today it is about 2 (a mean of 2 on the best pin), with no limit at 1, 0, 1 and 4, so reach adds little. Reach stays 160 until they rule.
Decided without asking, in autonomous mode: revising now; a pin at the hero's own position does not count as a re-pin (creative director, against qa-lead's reading); the flags' home on the Input record, read directly. The recommended items above stay open.

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, godot-specialist, creative-director
Blocking items: 6 | Recommended: 15 grouped lines
Summary: The mechanics, numbers and pillars hold, and no specialist's design objection survived checking. What remained was a builder contract missing from Flow, a test convention that fails correct code, and contradictory or untestable text. The creative director asks that most of the 40-plus findings be treated as precision, not fuel for another round.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Handed to owning GDDs, Flow: `in_build()`, the hand and the Hero's and Burst's IDs are absent from the builder's owner, which says only "Builds and ticks it".
- [BLOCKING] Acceptance Criteria preamble, 4, 5, 8: "the entire log" omits the `attack_fired` that Tick steps 4 and 7 emit, so a strict test fails correct code.
- [BLOCKING] Open Questions, row 1: "4 to 5 lives" contradicts the table (5, 3, 2, 5) and Rule 7 (8, 8, 7, 5).
- [BLOCKING] Formulas clamp_pin, criterion 14: "64-bit floats" against `Vector2` interfaces is unstated, and the "tie" at (186, 800) is the circle-centre rule, so the tie-break was untested.
- [BLOCKING] Criterion 27: it cannot fail, since the fixture has only `in_build()`.
- [BLOCKING] Criterion 16: "set the counters" has no values.
- [RECOMMENDED] Rule 1, Input Rule 11, Handed to owning GDDs: stale amend text and Input bullet.
- [RECOMMENDED] Open Questions: the 17% burst against a heavy, raised twice now.
- [RECOMMENDED] Rule 3: a guard behind "signal handlers never issue commands", for the ADR.
- [RECOMMENDED] Criteria 4, 7, 15, 18 to 21, 23, 31 and compound criteria 2, 11, 13: exact values and splits; 12, 25, 28, 29, 30 tightened.
- [RECOMMENDED] Acceptance Criteria coverage: builder injection, `hero_pinned` order, first pin at own position, inclusive radius, non-fatal leak in a telegraph, tower kill emptying the radius, press while Telegraphing, left-hand runs.
- [RECOMMENDED] Deferred criteria: unmeasurable rows (Hero alone, Best moment, First run, Always-call humans, Radius 70, Pins near a button, Burst between ticks), and "Hero stories" as an owner.
- [RECOMMENDED] Manual list: no pass descriptions or lead sign-off.
- [RECOMMENDED] Simulated results: share gate margin of 0.1; `hero_share_bound` has no cadence cap; `damage_per_second` ignores tick rounding.
- [RECOMMENDED] Formulas: `speed_factor` range, walk_ticks tolerance units, a NaN finger's path to `hold`, leash against `path_width` units.
- [RECOMMENDED] Rules 7, 9, 3: the reach ring understates landing reach by up to 60; the cooldown is not the pacing lever (about 2 bursts a wave); a `repins` per wave trigger.
- [RECOMMENDED] Rule 14, UI: a pin has no cancel; cooling digit offset unspecified; finger-to-reticle tether; re-grab at high pins; hero over the button; prompt 700 units from the hero; left-hand unmirrored list and no way to test it (`/ux-design`).
- [RECOMMENDED] Rule 13: lift-off drift cancels at 65 to 70, no non-visual cue, log `release_state`.
- [RECOMMENDED] Visual Requirements: Reduce Motion row still incomplete; 2 px and alpha 0.6 primitives; kill-mark flicker hold.
- [RECOMMENDED] Engine, for the ADR: `update()` after physics ticks; desktop mouse emulation; Callable cycles need a teardown; an enum for return codes; criterion 28's exact-integer scripts.
- [RECOMMENDED] Player Fantasy, Tuning Knobs: absent (advisory at standard).
Disagreements, for the user: ux-designer wants exclusion 104 or zone ownership now, against Rule 15's user decision of 60 until the phone test; game-designer wants reach re-simulated or dropped, against keeping 160.
Refuted by checking sources: a stuck cooldown at 0 ticks (Data floors it, again); `halted()` must include Paused (Flow 15, 17 cancel input and hold a finger dead); Start/Call as a `Button` (HUD draws an Input disc); criterion 29's read log (`burst_id` is not an accessor read); HUD and Hero disagree on the digit (HUD Rule 12 gives press responses to Hero); the hero owning half the button (36% at exclusion 60); FMA across platforms (no GDD promises cross-platform identity); radius 70 unguarded (a user-set pass mark and fallback exist); Pillar 2 requiring a heavy answer at MVP (its clause starts at Vertical Slice).
Reviewed-Content-Hash: design/gdd/hero-system.md def3c97f988a2d766746461c1534444080e7cb73
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 69276bc59133ed1fc4125a561b829e3bd7eb4156
Reviewed-Content-Hash: design/gdd/combat-damage.md 40ae59c616520d9cd4b3a5eea61c1ec824b8c0d8
Reviewed-Content-Hash: design/gdd/enemy-wave.md cfc80084d4b46610e6de31ab9abcffe6910a899d
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 9ab10a8976932d538c3e9eced0c9ccd235555840
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: design/gdd/battle-hud.md 8353173991a0de3cd1ef4522de1abfe8f5b42af2

## Revision — 2026-11-03 — Six blockers applied, re-review pending
Applied in `design/gdd/hero-system.md`: the log convention stated once in the Acceptance Criteria preamble, with criteria 5 and 8 corrected; criterion 14 given real ties, in y on the starter shape and in x on an injected one, both run against the script's `clamp_pin`; PinGeometry's scalar floats and the 32-bit margin stated, with the technical director to confirm; criterion 16 given values; criterion 19 made able to fail; criterion 27 moved to integration as 31, with 28 to 31 renumbered 27 to 30; the stale Open Question, amend text and Input bullet corrected; the heavy risk added to Open Questions; the share margin noted on its gate. `design/gdd/game-state-stage-flow.md` carries the builder's injections.
Not changed: balance, Rule 15, reach. No script re-run, since no value moved.
Awaits the user: whether about 2 lives (1, 1, 2, 4) satisfies the concept's "clearly lose" at reach 160. Creative director recommends accepting for MVP. The recommended items above stay open.
Decided without asking, in autonomous mode: revising now; scalar floats as the representation, pending the technical director.

## User ruling — 2026-11-03
Accepted about 2 lives (1, 1, 2, 4) as satisfying the concept's "clearly lose" for MVP, with reach staying at 160 (creative director's recommendation). The Pinned once gate and the lanes fallback are unchanged. Updated Rule 7, the Pinned once row, the Open Question and the header.

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, godot-specialist, creative-director
Blocking items: 2 | Recommended: 9
Summary: Every stated example recomputes, sibling values agree and the sixth review's blockers are fixed. Two test gaps remain: criterion 15 lets a fake resolver decide the user's "hero wins overlap" ruling, and a pin-only script passes criterion 27, the only proof that bot numbers apply to HeroInput. The creative director finds no design, balance or simulation change is needed, and that the main open risk, thumb aim, needs a phone rather than another review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Acceptance Criteria, criterion 15: drag-wins is tested through a fake resolver, with no coordinates.
- [BLOCKING] Acceptance Criteria, criterion 27: the gesture script has no required content, and the thumb roll is joined to the equivalence test.
- [RECOMMENDED] Rule 13, Radius 70 row: log `release_state` before the first phone build, since the pass mark counts only fired bursts and a silently cancelling thumb can pass it. Raised twice now.
- [RECOMMENDED] Rule 10, Share row: run radii 68 and 72 and several variations; 65, 70 and 75 give 24%, 25.1% and 32%, and 25.1% sits on the floor.
- [RECOMMENDED] Deferred criteria: "Hero stories" is not an owner; human rows lack sample sizes; Best moment cannot fail; "within 40" should exclude fingers within 20 of a button centre.
- [RECOMMENDED] Open Questions: re-pin (`repins`) and reach have no numeric trigger for their fallbacks.
- [RECOMMENDED] Criteria 2, 6, 7, 8, 11, 13, 14, 16, 18, 21, 24, 29, 30: missing edges, a Telegraphing press, a loose oracle, compound asserts.
- [RECOMMENDED] Coverage: Intermission restoring the cooldown, tower kill emptying the radius, enemy exit and off-field in a telegraph, HERO source ID, Paused during an aim.
- [RECOMMENDED] Simulated results: the real bots must rule out 4-unit hops, which attack at full walking speed; intermission rule in ticks; `hero_share_bound` denominator against Combat's `dealt_total`; `burst_safe_distance` unbounded below; a NaN finger in `clamp`.
- [RECOMMENDED] For `/ux-design` and the phone test: cancelling shape cue, committed cue, clamp cue, Reduce Motion and photosensitivity, reach dot size, cooling digit under the thumb, left-hand aim row, mis-call row.
- [RECOMMENDED] For the Input ADR, verified on 4.7: float tolerance in tests and float32-exact boundary values, PinGeometry's single conversion seam, position from start, `_ticking` guard, Callable teardown, `update()` timing, touch emulation and index, typed return enums, gdUnit4 on 4.7.2. Player Fantasy and Tuning Knobs stay absent (advisory at standard).
Disagreements, for the user: game-designer wants a human-error bot gate or the aim magnet now, against the user-set phone gate and fallback; ux-designer wants cancel feedback and logging blocking, against a desktop MVP; qa-lead listed six blockers, of which the creative director keeps two.
Refuted by checking sources: no first-pin teaching (the prompt, the nudge and HUD Rule 13 exist); burst never taught (HUD prompt 3 reads "Drag from the big button"); a realistic human cannot win (the 3 s, 50-off bot keeps 6 to 9 lives); cancelling is alpha only (ticks, preview and kill marks also go); arrival-tick attack unsettled (criteria 18 and 19 settle it).
Reviewed-Content-Hash: design/gdd/hero-system.md e53f138d7dcb82f81ec97959546593402872937d
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 69276bc59133ed1fc4125a561b829e3bd7eb4156
Reviewed-Content-Hash: design/gdd/combat-damage.md 40ae59c616520d9cd4b3a5eea61c1ec824b8c0d8
Reviewed-Content-Hash: design/gdd/enemy-wave.md cfc80084d4b46610e6de31ab9abcffe6910a899d
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md bf732dff9591608ebee0b1d8d7127d51c3c9cd2b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 9ab10a8976932d538c3e9eced0c9ccd235555840
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: design/gdd/battle-hud.md 8353173991a0de3cd1ef4522de1abfe8f5b42af2

## Revision — 2026-11-03 — Two blockers applied, re-review pending
Applied in `design/gdd/hero-system.md`: criterion 15 now covers only registration and the centre update; drag-wins moved to new integration criterion 32, with coordinates and the real resolver; criterion 27 given the required content of its script; the thumb roll moved to new criterion 33. Existing criteria keep their numbers.
Not changed: rules, balance, formulas, simulation. No script re-run, since no value moved. The recommended items above stay open.
Decided without asking, in autonomous mode: revising now. Left for the user: an eighth full review or the creative director's lighter exit.

## User ruling — 2026-11-03 — APPROVED on a lighter exit
The user chose the creative director's lighter exit over an eighth full review. One reader (qa-lead) checked criteria 15, 27, 32 and 33 only. 15, 32 and 33 passed. 27 failed on three points: presses released in place never reach `drag_ended`, a wrongly issued `burst` is refused and so invisible to a field comparison, and an aim between `reach − 0.01` and `reach` gets clamped. Its replacement wording was applied and checked against Rules 11 to 13 by the main session, not by a second reader.
This was not a full review, so this entry has no Review mode line and does not cover a later `/design-review`. The recommended items in the seventh review stay open; `release_state` logging should land before the first phone build.
Reviewed-Content-Hash: design/gdd/hero-system.md 6c42e0f35c803d364a8156eb02ebd5a781b47949
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 69276bc59133ed1fc4125a561b829e3bd7eb4156
Reviewed-Content-Hash: design/gdd/combat-damage.md 40ae59c616520d9cd4b3a5eea61c1ec824b8c0d8
Reviewed-Content-Hash: design/gdd/enemy-wave.md cfc80084d4b46610e6de31ab9abcffe6910a899d
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md bf732dff9591608ebee0b1d8d7127d51c3c9cd2b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 9ab10a8976932d538c3e9eced0c9ccd235555840
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/tower-system.md 0585c980cc24320d71f48360b7c452812b4e0df6
Reviewed-Content-Hash: design/gdd/battle-hud.md 8353173991a0de3cd1ef4522de1abfe8f5b42af2

## Revision — 2026-11-03 — cross-GDD warning pass
From design/gdd/gdd-cross-review-2026-11-03.md, Consistency Re-run. Hero view named as drawer of field-anchored visuals (C4, new wording), `visual_key`, L11 condition, L14 row, always-call clause, 100 offset. No rule value changed; Approved stands, pending the user's view.
