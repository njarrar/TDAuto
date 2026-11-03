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

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, creative-director
Blocking items: 4 | Recommended: 8
Summary: No pillar problems and the arithmetic holds; the script reproduces every table row (median share 25.2%, so the earlier 25.1% note was stale). But the share gate measured restraint: a bot that fires whenever Ready keeps one more life and reaches a median of 29.8%, and with exact aim 34% to 41%. The other blockers were the kill preview's timing basis, the cancel ring's radius and stale figures.
Prior verdict resolved: Yes; all eight review-4 blockers fixed
Findings:
- [BLOCKING] Simulated results and Share gate: the gate measures the mid-skill trigger, not the cooldown; firing on Ready is better play and lifts share to 28% to 38% (41% with exact aim); rounding and inclusivity unstated.
- [BLOCKING] Visual/Audio, kill preview: positions at lift or at landing unstated; a fast enemy moves 27.5 in the telegraph.
- [BLOCKING] UI Requirements and Rule 13: the ring at 64 is called the cancel boundary, but a Live aim cancels at 48, so a lift at 55 fires.
- [BLOCKING] Open Questions line 446 and the revision note: 35% and 44% and 25.1% are stale (32%, 40%, 25.2%).
- [RECOMMENDED] Left-hand Start/Call is 7.2 units (4.8 dp) from the mirrored button (Battle HUD).
- [RECOMMENDED] A thumb cannot aim below y 860, hiding the leak-save near the exit.
- [RECOMMENDED] Wording: "the pin decides which stretch" while re-pinning is free; "release" meant lift and landing.
- [RECOMMENDED] Acceptance Criteria: tick numbering unstated; criteria 16, 19, 21, 24, 26, 27 need numeric THENs; one array name per burst-outcome gate; real bots not tied to the script; human rows lack sample sizes; Manual list misses rows and sign-off.
- [RECOMMENDED] Prompts retire on a first burst that hits nobody.
- [RECOMMENDED] Engine: retry teardown (gameplay-programmer rated blocking; held as for Tower); handlers-issue-no-commands unenforced; update() contract; button "centre" point; Vector2 precision unverified.
- [RECOMMENDED] Reduce Motion leaves a dead press silent; reach ring contrast unspecified; one input path for the burst.
- [RECOMMENDED] Formulas: burst_safe_distance assumes the slow outlasts the telegraph; hero_start valid for both hands; clamp's 0.03 bound only for starter shapes; cooldown_left floor is Data's one tick (gameplay-programmer rated blocking; fixture only).
Disagreements: gameplay-programmer's two blockers (stuck Cooling, retry teardown) held at recommended, since Data floors the cooldown and Tower's teardown item was held today; qa-lead's real-bot, counter-value and array-name blockers held at story level as in review 4, while the share tolerance stayed blocking because the greedy median sits at 30%.
Fixed in the same session, with three user decisions (2026-11-03): the share gate runs on a greedy bot (fires when Ready at any victim, mid-skill aim and re-pin), median 25% to 30% inclusive and unrounded, none above 40%, today 29.81% and 37.7%; the greedy ceiling above 40% is accepted as skill; `hero_bots.py --greedy` reproduces and asserts it. The kill preview projects positions to landing, with criterion 32. The ring is at 64 while Cancelling and 48 while Live, read through `aim_ring_radius()`, in criterion 13. Stale figures replaced; tick numbering stated; "release" means the landing. Tower's line 120 now cites the greedy gate.
Reviewed-Content-Hash: design/gdd/hero-system.md 6318793eec275f8d1f5e0bd0b3c3f7a2a7d5aa5f
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ed25cb702da175ffd4e9fbebb4a42b147cbffa0d
Reviewed-Content-Hash: design/gdd/combat-damage.md 9fe61dab43d04486b54833702d9215b1c72762b5
Reviewed-Content-Hash: design/gdd/enemy-wave.md 2890a42203fd47a724a105634efd2349ba0b18bf
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b81528a4102d977ed04d869e0f4ecc9a1b117559
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/tower-system.md 2b6f6a42bcfb5c3598682e28cc32b16c150eef2d
Reviewed-Content-Hash: design/gdd/battle-hud.md a8f14586cae3c5c253117dbf2e0960855d3ec009
