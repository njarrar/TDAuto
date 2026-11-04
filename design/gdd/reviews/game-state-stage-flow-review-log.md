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
