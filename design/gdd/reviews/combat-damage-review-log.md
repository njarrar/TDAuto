# Combat & Damage — Review Log

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, gameplay-programmer, creative-director
Blocking items: 3 | Recommended: 4
Summary: The design is sound and its worked numbers check out. It lacked a written contract for the API that Tower, Hero and Enemy & Wave call: no signatures, units or bounds, so a slow of strength 1 − 2^-53 could freeze an enemy (checked: the step no longer moves it), the slow-tower preference never defined "unslowed", and "deliver never runs outside a tick" had no guard.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules: no API table; apply_slow unvalidated and its duration rounding to 0 undefined; helpers' empty result and fields unstated.
- [BLOCKING] Rule 10: "first unslowed" undefined for the slow tower.
- [BLOCKING] Rule 2: deliver outside a tick neither guarded nor tested.
- [RECOMMENDED] Cross-references: share gate is Hero's; to_ticks dependency; stale Dependencies; HUD reads counters, not damage_applied; Tower Rule 13 and Hero's separate IDs answer two programmer concerns.
- [RECOMMENDED] Formulas: fractional damage can leave ~1e-16 HP alive (not with catalogue values); NaN check before min.
- [RECOMMENDED] Acceptance Criteria: invariant I as a process claim; criterion 9 rounding uncited; Pillar 2 bot rows and splash gate differ from Hero's and Tower's.
- [RECOMMENDED] Visual/Audio and performance: no burst-victim flash row; 16 markers drop a burst's own hits; measure the 400-check cost on a low-end phone (estimated 1.2 to 4 ms there).
Disagreements: specialist blockers answered in sibling GDDs were downgraded (share gate in Hero, primary-target double hit in Tower Rule 13, counter keys in Hero, rounding in to_ticks, float dust unreachable with catalogue values). Health and Status attachment and the fakes held at recommended (ADR, sibling practice). The creative director recommended redefining "unslowed" as any slot the shot improves; that changes every bot table, so it went to the user.
Fixed in the same session, with a user decision (2026-11-04: "unslowed" is an empty slot, as Tower Rule 9 and the bot script already do): an API table for every call, with apply_slow converting seconds through to_ticks and rejecting bad strength and duration; Flow's in_tick() guards deliver (Flow Rule 15 now exposes it); Rule 3 orders the NaN check and notes whole-number catalogue values; hero_share cites Hero's gate; Dependencies, Cross-References and the deferred rows aligned with Hero and Tower; invariant I rewritten as a check; criteria 13 to 15 added.
Reviewed-Content-Hash: design/gdd/combat-damage.md 9fe61dab43d04486b54833702d9215b1c72762b5
Reviewed-Content-Hash: design/registry/entities.yaml 92b0575de64a56f7ded6916baa1b58aa10f6be24
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ed25cb702da175ffd4e9fbebb4a42b147cbffa0d
Reviewed-Content-Hash: design/gdd/enemy-wave.md 2890a42203fd47a724a105634efd2349ba0b18bf
Reviewed-Content-Hash: design/gdd/tower-system.md 510ecafa16cf862f4df9a3ac8d1a15389697527e
Reviewed-Content-Hash: design/gdd/hero-system.md ae3f29802ca874d7073d6b01ee1e219d02a78361
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 660addada205f99b45b11a4fc00fa5dc91ab9bf4
Reviewed-Content-Hash: design/gdd/battle-hud.md f97757964f690bed45312e2c2a5aff73c92a0f9f
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b81528a4102d977ed04d869e0f4ecc9a1b117559
