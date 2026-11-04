# Game State & Stage Flow — Review Log

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, lead-programmer, godot-specialist, creative-director
Blocking items: 7 | Recommended: 5
Summary: The design holds: the state machine, the determinism contract and the registry values agree with the siblings, and every tick count round-trips through to_ticks. What it lacked was the contract a test or story can bind to: a signal table, a rule for commands while Paused, Fatal against Retry, outcome timers under focus loss, and three criteria that broke their own header.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules, Rule 15: no signal table; `phase` listed four values while criteria used more.
- [BLOCKING] Rule 17: no rule for commands while Paused.
- [BLOCKING] Rule 16: no winner when Fatal and Retry latch in one frame.
- [BLOCKING] Rule 17 and Game Feel: outcome timers undefined under focus loss, so a returning tap could hit an armed Retry.
- [BLOCKING] Acceptance Criteria, 8: forbade Retry, which the stage machine allows; `cancel()` unobservable.
- [BLOCKING] Acceptance Criteria, 12 and 13: no log, against the header's rule.
- [BLOCKING] Acceptance Criteria, 15: "a call at that moment" read two ways; `stage()` had no duration setting.
- [RECOMMENDED] Dependencies and Cross-References stale; two Open Questions partly answered by the bot work.
- [RECOMMENDED] Rule 16 did not say "same seed"; always-call condition scattered across GDDs (game-designer rated both blocking; settled elsewhere).
- [RECOMMENDED] App Lifecycle ADR inputs: per-platform pause notifications and a desktop debug override, tree pause against Flow's Paused, accumulator and clamp, deferred free, fatal screen independence, Android back (godot-specialist rated five blocking; line 75 hands them to the ADR).
- [RECOMMENDED] Flow API, fakes and test seams; criteria 6, 10, 11, 14; deferred owners and thresholds (lead-programmer rated the seams blocking; held as for siblings).
- [RECOMMENDED] Rule 14's "tie" case cannot occur with the real Enemy & Wave; keep as a guard.
Disagreements: godot-specialist's five engine blockers and lead-programmer's seam blockers held at recommended (ADR-owned, sibling practice). game-designer's always-call and seed items downgraded: the gate is scattered, not contradictory, and the seed is settled in Enemy & Wave Rule 6. qa-lead's payload-units item downgraded: Enemy & Wave types it in seconds.
Fixed in the same session, with user decisions (2026-11-04): a signal table (phase enum on every change including resume, lives_changed, wave_called_early before phase(WAVE)); commands ignored while Paused; Fatal beats Retry and a second Retry does nothing; Retry re-arms on focus regain in Won or Lost (also in Battle HUD Rule 11); criteria 8, 12, 13 and 15 rewritten and criterion 16 added; same seed in Rule 16; Rule 14 relabelled; Dependencies and Cross-References brought up to date; the ADR line lists the review's inputs; always-call row points to Hero's; Open Questions refreshed. User decisions: seconds_left keeps reporting L though a call saves L − 1 ticks (documented); retry cost accepted for MVP and measured through a new HUD log field.
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/registry/entities.yaml 92b0575de64a56f7ded6916baa1b58aa10f6be24
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ed25cb702da175ffd4e9fbebb4a42b147cbffa0d
Reviewed-Content-Hash: design/gdd/enemy-wave.md 2890a42203fd47a724a105634efd2349ba0b18bf
Reviewed-Content-Hash: design/gdd/tower-system.md 510ecafa16cf862f4df9a3ac8d1a15389697527e
Reviewed-Content-Hash: design/gdd/hero-system.md ae3f29802ca874d7073d6b01ee1e219d02a78361
Reviewed-Content-Hash: design/gdd/combat-damage.md 9fe61dab43d04486b54833702d9215b1c72762b5
Reviewed-Content-Hash: design/gdd/battle-hud.md 3288f44c77945d2428134b988ff351c9a602ba7a
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b81528a4102d977ed04d869e0f4ecc9a1b117559
