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
Summary: All 5 prior blockers are resolved, though the fix for criteria introduced a name collision. Four small text repairs remain: AC12 on Paused from Build, what "stops emitting" promises, the Formulas example against Rule 9, and `C`'s two meanings. No blocker needs a user decision. Specialists raised 16 blocking; the creative director kept 4. The sim, suite and phone behaviour were not run.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] AC12: one tick after resume adds nothing from Paused from Build; scope that clause to Wave and Intermission.
- [BLOCKING] Rule 15, AC18, Edge Cases: Flow makes no further emit, but delivery under way continues; say so, pin the recorder first connected and bind `s`.
- [BLOCKING] Formulas example: a call commits at once and members spawn next tick (Enemy & Wave Rule 7); reword to match Rule 9 and AC3.
- [BLOCKING] Acceptance Criteria: `C` names both the cancel counter and a system; rename.
- [RECOMMENDED] Rule 9: "played without calling" is not what the concept says, whose 5 to 8 minutes is for 8 to 12 waves; correct the gloss.
- [RECOMMENDED] Rule 9: bonus still one-directional. User option: keep, checked at first playable (recommended), or remove.
- [RECOMMENDED] Hero's gate: derive the 3.5-minute floor and re-run on the fixed tick (Hero stories).
- [RECOMMENDED] Rule 15: one post-act check for Fatal; systems' leak-during-start case is unreachable under Enemy & Wave Rule 7.
- [RECOMMENDED] AC6: add a sink count to the further-leak case.
- [RECOMMENDED] Rule 16: `queue_free` leaves the battle alive to frame end, `free()` does not; ADR-0001 names the call, and Rules 16 and 18 use it.
- [RECOMMENDED] Rule 18: criterion that commands are inert once latched; wrapper removed before the battle is dropped.
- [RECOMMENDED] Rules 10, 17: commands in Paused from Build (a bot pin would move the hero); refocus click may be the resume tap.
- [RECOMMENDED] Formulas: negative or NaN payload and `lives_cost`; name the validator.
- [RECOMMENDED] Rule 2a: lint for lambdas and `bind()` on injected callables (lambda retention observed in a probe).
- [RECOMMENDED] Rule 17, AC12: test the notification mapping; which notifications fire per OS is NOT SOURCEABLE until ADR-0001.
- [RECOMMENDED] Rule 18: result reads with a text fallback, so a Won screen is not the likeliest Fatal.
- [RECOMMENDED] Rule 14: note it is a defensive guard; Enemy & Wave's fatal leak skips the clear.
- [RECOMMENDED] Criteria: E emitting inside its tick, AC9 for Won and Fatal, null cancel, AC17 damage by source, finger across pause, Micro-battle and Listener owners.
- [RECOMMENDED] `tests/README.md` says gdUnit4 is not installed; 6.2.0 is present.
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 70d0e7681e95807f16f083f1f2ce650c97d328c0
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 5e5df4a50191c71f81644957fb43ef96b38ab6d5
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4c34ae187a1d77212e8c66bd6454c8d7a170ad95
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: design/gdd/hero-system.md 377e450bbee022ae776076cebdd1ed1c092a02fc
Reviewed-Content-Hash: design/gdd/battle-hud.md a8f89fe590ea44636a835021accab97e365ff7f3
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f

## Revision — 2026-11-04 — after the review above (not a new verdict)
User accepted every recommendation ("Implement all recomended"). Applied: all 4 blocking and most recommended, including Rule 9's gloss, a third gate (mono-role while calling), `phase_changed`, `cancels` for the counter and the teardown call. Moved to Open Questions: a text fallback for result reads. The 3.5-minute floor is derived as about two thirds of the uncalled stage, and is not yet re-run on the fixed tick.
Re-review pending: the hashes above no longer match this document.

## Review — 2026-11-04 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean; one reader with a shell)
Blocking items: 0 | Recommended: 4
Summary: All 4 prior blockers resolved, and today's text holds under hand traces of AC12, 13, 18, 19 and 20. `hero_bots.py --calls` matches Rule 9. Suite and phone not run.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Rule 9: label its time ranges as mixed builds; Hero's and Enemy & Wave's 5 to 8 lines still apply the concept to 6 waves.
- [RECOMMENDED] Rule 10: "takes every event" is stale against Battle HUD Rule 2.
- [RECOMMENDED] Rule 18: "every command is inert" covers Flow's in AC13; the reader's claim that Hero has no halted check is wrong, since Hero Rule 2 returns `HALTED`.
- [RECOMMENDED] Review log: the 3.5-minute note is stale for the script, which runs at 1/60; real bots are still owed.
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md b869a7ca338cf3100f72219f98e64207b252dec6
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 05e3e8f4ca5b1c2a34b39d2ebc9215b0d5342861
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 0804873149506940e730239e7998a943f8bcc5cd
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md c67e5441a28be83b92efa4b903b15c4e76918a6b
Reviewed-Content-Hash: design/gdd/tower-system.md 86f753dacdcc4d904575ab5d6bdfffb8fd4f6415
Reviewed-Content-Hash: design/gdd/hero-system.md d075d8207bffb1b7f4a23a2f0467da21c2509528
Reviewed-Content-Hash: design/gdd/battle-hud.md 044488039c9a221f998173317300db5f3cd7ab5b
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f

## Revision — 2026-11-04 — after the review above (not a new verdict)
Recommended text applied after the Approved verdict (Rule 9's label, Rule 10's wording, Rule 18's command sentence, the battle's exposure for the wrapper). Status stands; the hashes above no longer match.

## Revision — 2026-11-04 — after a lean read (not a new verdict)
One adversarial reader checked the day's added rules (S1, S2, the four cross-review decisions) and returned NEEDS REVISION with 18 findings. All five rated BLOCKING were fixed (Flow Rule 9, Thumb cost pass condition, redraw key, criterion 6, HUD 0.55 evidence). Recommended items 3, 7, 9 to 14, 16 to 18 and part of 8 were fixed. Not done: concept `towers-only` unit at Vertical Slice (15). The fix pass was not re-read, per the one-review, one-fix cap the producer recommended. No hash stamped, because this text has no review verdict.
