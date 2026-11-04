# Review Log: Game State & Stage Flow

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, creative-director
Blocking items: 5 | Recommended: 13
Summary: The structure holds (pure Flow, builder, rebuild on retry). The call-early gate cannot detect a free habit, so the Overview's claim is false; Fatal against terminal states and the order of commit, start and emit contradict; injected Callables do not keep their targets alive (4.7.2 editor probe, desktop only); and the criteria test the wrong seam. Specialists raised 13 blocking; the creative director kept 5.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Overview, Rule 9, Always-call row: the gate cannot detect dominance for a hero player. Awaits the user's decision on what call-early is.
- [BLOCKING] States table, Rule 15, AC8: Fatal overrides Won, Lost and Paused (creative director's ruling, siding with systems-designer); add Fatal-per-state coverage.
- [BLOCKING] Rule 15, AC1-3, AC12: one rule for commit, then start or cancel, then emit, stopping if Fatal latched; `phase` fires on every change.
- [BLOCKING] Rules 15, 18; architecture B4, B9: Battle strongly holds every helper, guarded public `cancel_input()`, one accessor per battle.
- [BLOCKING] Acceptance Criteria: add a `cancel_input` fake and wiring row, cover Rule 18's null route, give "broken scene" a code path or remove it.
- [RECOMMENDED] Rule 2, Hero Rule 2: a pin in Build looks failed. User decision (place at once recommended).
- [RECOMMENDED] Edge Cases: no exit from a doomed stage. User decision (defer recommended).
- [RECOMMENDED] Game Feel: Won's 1 s beat may read as a hang; use 400 ms until the brighten exists.
- [RECOMMENDED] AC12: prove Paused freezes the other systems.
- [RECOMMENDED] Rules 10, 15: `in_build()` stays true while Paused from Build; say where Paused refusal lives.
- [RECOMMENDED] Rule 2: `build` needs a failure contract.
- [RECOMMENDED] Rule 6, AC1: the opening phase needs an initial read.
- [RECOMMENDED] Formulas: `seconds_left` pays one tick more than a call saves; send to Tower pricing.
- [RECOMMENDED] Deferred Retry row: weakrefs to every sim, the accessor and the resolver, owned by Game State stories.
- [RECOMMENDED] Rule 18: Fatal during wrapper assembly and the wrapper's fate after Fatal.
- [RECOMMENDED] AC6, AC7, AC11, AC14, AC15: fixture and sequencing repairs; error sink; Rule 15a coverage.
- [RECOMMENDED] Deferred Clamp row: owner is a document; accumulator zero and retry edge cases need owners.
- [RECOMMENDED] Rule 15: result values and `in_build()`/`halted()` reads have no criterion.
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 1a1ff7b3a75e514e0b299f59f42e60e3fbff29fc
Reviewed-Content-Hash: design/gdd/enemy-wave.md 780379132e91e72db9206809509ec5b4381372ee
Reviewed-Content-Hash: design/gdd/battle-hud.md 1d9cb4faf2507cd8e9bb0c1328bc4fc9d291608f
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md efca210206aac0ad9edac1737852de990ba42de5
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 5e5df4a50191c71f81644957fb43ef96b38ab6d5
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/tower-system.md 29b611f32294caeca03b4114b86d3bd9ebe260ee
Reviewed-Content-Hash: design/gdd/hero-system.md f6addad6559296cd1f8f60724b24f7c0db0284df
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4c34ae187a1d77212e8c66bd6454c8d7a170ad95
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f

## Revision — 2026-11-04 — after the review above (not a new verdict)
User accepted every recommendation ("All recommended"). Decisions: call-early is an honest fast-forward with new gates (call when Ready within 2 lives of never calling; a fully called won stage at least 3.5 minutes, proposed); a pin in Build places the hero at once (Hero Rule 2; bot table unchanged); Retry on Paused deferred. Applied: all 5 blocking and the recommended repairs, including Won's beat at 0.4 s, Rule 2a, the one-order rule, Fatal overriding Won, Lost and Paused, and the criteria rewrites. Not done: the ADR's tick cap, and the probe on an export build.
Re-review pending: the hashes above no longer match this document.

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, creative-director
Blocking items: 4 | Recommended: 15
Summary: The prior five blockers and the user's decisions are applied correctly and the structure holds. Four contradictions remained: when a called wave starts, whether systems tick in Build, Rule 14's legal tie against Rule 15a's breach log, and resting cancel safety on a validity check that Rule 2a's own probe does not support. The creative director kept those four and rejected the game designer's challenges to the user's fast-forward and Build-pin decisions as reopening them without new evidence.
Prior verdict resolved: Yes (all 5 prior blocking items)
Findings:
- [BLOCKING] Rule 9, Formulas, AC3, AC15: call timing ambiguous ("at once" vs "next tick"); "pays one tick more" not derived.
- [BLOCKING] Rule 6, AC1, AC12: Build ticks no system, but AC12 expected +1 after a resume into Build.
- [BLOCKING] Rules 14, 15a, AC7, AC8: same-tick tie must not log; later events after an outcome must; sink counts unasserted.
- [BLOCKING] Rules 2a, 15: cancel safety must rest on the wrapper clearing the cancel, not on is_valid(); needs a headless test.
- [RECOMMENDED] AC9, AC13: mid-tick skip for Won and Fatal; after-Fatal commands; first cause observable.
- [RECOMMENDED] Deferred Retry row: latch plus Fatal in one frame; Fatal during the rebuild.
- [RECOMMENDED] AC18: placeholder value; start count.
- [RECOMMENDED] Formulas: range as to_ticks(600); dt injected.
- [RECOMMENDED] Rule 15: state the emit order; listeners of the emit in progress cannot be stopped.
- [RECOMMENDED] Rule 15: resume re-emits phase; listeners must be idempotent.
- [RECOMMENDED] Rule 10: the Paused guard covers people, not bots.
- [RECOMMENDED] Rule 18: broken-script claim unverified; root type check after instantiate (ADR-0001).
- [RECOMMENDED] Rule 16: align teardown with the architecture's free() vs queue_free() question (ADR-0001).
- [RECOMMENDED] Rule 17: per-platform notification set and doubled delivery (ADR-0001, ADR-0003).
- [RECOMMENDED] Rule 4: clamp value and delta source (ADR-0004).
- [RECOMMENDED] Negative lives_cost validation (Data & Config).
- [RECOMMENDED] AC10, AC12 wording; AC17 full in_build()/halted() matrix incl. damage by source.
- [RECOMMENDED] Tuning Knobs section; prototype reference as context only.
- [RECOMMENDED] Call-early 3.5 min gate has about 0.1 min headroom over throwaway bots; user to reconfirm after the fixed-tick re-baseline (advisory, user decision).
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 70d0e7681e95807f16f083f1f2ce650c97d328c0
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: docs/architecture/architecture.md 1bc205b5b722ffc015d14444df535b375764cb42

## Revision — 2026-11-04 — after the review above (not a new verdict)
Applied in autonomous mode: all 4 blocking items (Rule 9 timing and the worked example; AC1 and AC12 Build counts; Rule 14 and 15a split with sink counts in AC7 and AC8; Rule 15 cancel safety on clearing plus new AC19) and recommended items: AC9 Won and Fatal cases, AC13 events and cause, AC18 value, new AC20 (wave_cleared from inside a tick) and AC21 (Fatal on phase(Lost)), Retry row cases, Formulas range and injected dt, Rule 15 emit order and listeners, resume idempotence, bots and Paused, Rule 16 and 18 ADR-0001 notes, Tuning Knobs section, prototype reference as context only.
Not done: AC17's full matrix, the per-platform notification list and the clamp value (ADR-0001, ADR-0003, ADR-0004), negative lives_cost (Data & Config), the 3.5 min gate (user).
Re-review pending: the hashes above are of the reviewed text, not this revision.

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, creative-director
Blocking items: 8 | Recommended: 21
Summary: Third pass. The rules held and no settled decision was reopened; the game designer found no blocker. What remained were eight text fixes, two of them introduced by the second revision (the fake's wave_index and the doubled "C"): a stale Rule 4 line after Data's floor change, the extra-leak edge case, nested emit order, clear-before-release in teardown, two criteria depending on connection order, and one reading a released fake. The creative director would approve on those conditions with a spot-check of the changed lines, not a fourth full review.
Prior verdict resolved: Yes (all 4 prior blocking items)
Findings:
- [BLOCKING] Rule 4: "matching the Data & Config interval floor" stale after the floor became 1/30 s.
- [BLOCKING] Edge Cases: extra same-tick leaks called "ignored"; Enemy & Wave stops its loop, and one that arrived would be a Rule 15a breach.
- [BLOCKING] Rule 15: nested emit; define stale payloads, with phase() authoritative.
- [BLOCKING] Rule 16 and architecture Data Flow 5: clear the cancel before release.
- [BLOCKING] Acceptance Criteria: "C" is both a recording system and the cancel counter.
- [BLOCKING] Acceptance Criteria AC2: the fake's wave_index contradicted the expected raised index.
- [BLOCKING] AC18, AC21: recorder connection order and phase() == FATAL.
- [BLOCKING] AC19: a released fake cannot be read; external counter and assert_error.
- [RECOMMENDED] Start arms 0.3 s when Build opens after a retry; the retry seed.
- [RECOMMENDED] Fatal clears the remembered phase; in_build() after Fatal from Paused-from-Build; a second focus loss while Paused; ticks alongside seconds_left; presentation timers cancelled on retry or Fatal; a bot pin in Paused-from-Build tested.
- [RECOMMENDED] AC9 callback into E; AC11 Paused origin; sink counts cumulative or reset; AC13 vacuous checks, sink count after Fatal, distinct causes; AC12 countdown value; Rule 17 finger before Paused, Retry twice, Rule 5 commands between ticks untested; Manual beat as 0.4 s within a frame; AC6 and AC17 as tables; damage-by-source result; Deferred row gaps.
- [RECOMMENDED] phase as an alias of phase_changed; instantiate and Callable-lifetime claims unverified (QQ-17); the weakref proof as an expectation; ADR-0003 for a finger across a pause.
- [RECOMMENDED] Routed: ADR-0001 (instantiate, Callable lifetime, free timing, weakref sampling); Enemy & Wave (confirm the fatal-leak skip is written there); Battle HUD (Start arming after retry, seed wording); backlog (dead input after a loss, Play again as a replay, frozen last frame, timers on focus loss, a doomed stage).
- [RECOMMENDED] Disagreements: systems-designer's tie and extra-leak blockers answered by Enemy & Wave's fatal-leak skip; godot's clear-before-release partly answered by architecture Data Flow 4 and its two-cancel-paths blocker by Input Rule 7.
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d79fe3bf982a1d15a806cc0725421521a6a735d5
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/battle-hud.md 4a8b31f64adc1ad85b770314b77dc0aa5435f39c
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b58a9270cca3749146c6a2291b7324583865c6c6
Reviewed-Content-Hash: design/gdd/tower-system.md 2c025196c3039eee362885ab82138a8999c3dd01
Reviewed-Content-Hash: design/gdd/hero-system.md c33a93e052ee88976c0bb5baab4ce8d475530a84
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 23d2a60fac1632b52fa5c9a35394466973c672ba

## Revision — 2026-11-04 — after the review above (not a new verdict)
Applied in autonomous mode: all eight conditions (Rule 4 floor wording; the extra-leak edge case and a pointer in Rule 14; Rule 15 stale-payload definition; Rule 16 and architecture Data Flow 5 clear the cancel before release; the cancel counter renamed X; the fake's start raises wave_index; AC18 and AC21 recorder order and phase() == FATAL; AC19 external counter and assert_error) and recommended: Start arms when Build opens after a retry (Game Feel), retry and Play again use the same seed (Rule 16), phase as the architecture's phase_changed (Rule 15).
Not done: the other recommended and routed items.
The creative director judged a spot-check of the changed lines enough to approve; that choice is left to the user, as for the Hero GDD's lighter exit.
