# Battle HUD & Build UI — Review Log

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, godot-specialist, creative-director
Blocking items: 4 | Recommended: 6
Summary: The doc is sound: all sections, values match the registry, and the layout and formulas recompute. Four problems sat in what the HUD owns: who draws Tower's and Hero's visuals contradicted itself, the arc panel could not hold its text and entered the band at a legal slot, prompts 1 and 2 never expired and took the next-wave row, and timed values named no clock. Engine seams stay with the HUD ADR, as for the sibling GDDs.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Visual/Audio and UI Requirements: "Tower and Hero own their field visuals" against "drawn here"; Hero's aim_ring_radius() and preview_kills() unlisted.
- [BLOCKING] Rule 6, Visual/Audio, Layout: a 60 x 44 panel (40 x 29 dp) cannot hold two 14 dp lines; at slot y 304 its top reaches 148, 26 into the band, and an open arc covers the next-wave line.
- [BLOCKING] Rule 13: prompts 1 and 2 never expire and take the next-wave row, so towers-only and veteran players lose the line every battle.
- [BLOCKING] Rules 6, 11, 15, criterion 12: no clock named for the 200 ms guard, 400 and 1,000 ms delays or 1.5 s ring; criterion 12 cannot pass under the 100 ms clamp.
- [RECOMMENDED] Layout: left-hand burst disc 7.2 from Start/Call at the largest inset (38.7 at inset 0) with no check (game-designer downgraded it from the main review).
- [RECOMMENDED] Content rules and Acceptance Criteria: checks lacked IDs and broken copies; Manual list and render tests lack counts, thresholds and sign-off (qa-lead rated blocking; the UI gate binds at story close).
- [RECOMMENDED] Engine: Rule 2 fallback if the Control check fails, Rule 11 pause against advance, queue_free on retry, redraw policy, stretch mode (ui-programmer and godot-specialist rated blocking; ADR-owned).
- [RECOMMENDED] Formulas: ticks_per_second hard-coded at 60; chip_bar repeats Tower's 1500.
- [RECOMMENDED] Player-facing: Paused has no Restart and Android back is unspecified; NO_GOLD nudge silent under Reduce Motion; Squares hint prescribes a buy; result understates the hero; a parked hero deadens 36% of Start/Call's disc; burst_y past an inset of 96 enters the unsafe edge.
- [RECOMMENDED] Tuning Knobs missing; accessibility tier unrecorded.
Disagreements: qa-lead's criterion 16 objection rejected (the panel reaches 164 at slot y 320 as the doc said). The 7.2 gap downgraded by game-designer and the creative director. Engine items held at recommended against ui-programmer and godot-specialist. The wrong disc (4-unit gaps, no undo) went to the user.
Fixed in the same session, with user decisions (2026-11-04): an ownership table (HUD draws the UI Requirements, including the Ready-press ring from aim_ring_radius(); Tower's and Hero's views draw their Visual/Audio tables, including range rings and the kill preview); cost-only 60 x 30 panels per arc_panel, role words in the prompt row until the first Won, HUD slot floor y 318 (an earlier one-line word-and-cost option was withdrawn: it overlapped the next disc); prompts 1 and 2 retire on session flags pinned_once, built_once, won_once held by the app root; one advance clock for every HUD timer, criterion 12 rewritten; content checks given IDs, with hud_call_burst added and three exact copies in criterion 33; ticks_per_second from dt; chip_bar cites Tower's window; R 76 kept with R 90 as the first fallback.
Reviewed-Content-Hash: design/gdd/battle-hud.md a8f14586cae3c5c253117dbf2e0960855d3ec009
Reviewed-Content-Hash: design/registry/entities.yaml 92b0575de64a56f7ded6916baa1b58aa10f6be24
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ed25cb702da175ffd4e9fbebb4a42b147cbffa0d
Reviewed-Content-Hash: design/gdd/hero-system.md ae3f29802ca874d7073d6b01ee1e219d02a78361
Reviewed-Content-Hash: design/gdd/tower-system.md 510ecafa16cf862f4df9a3ac8d1a15389697527e
Reviewed-Content-Hash: design/gdd/enemy-wave.md 2890a42203fd47a724a105634efd2349ba0b18bf
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0
