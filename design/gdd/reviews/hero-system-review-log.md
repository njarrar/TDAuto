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
