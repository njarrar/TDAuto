# Review Log: Enemy & Wave

## Review — 2026-11-02 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, level-designer, economy-designer, qa-lead, ux-designer, godot-specialist, creative-director
Blocking items: 11 | Recommended: 15
Summary: The design is sound and serves the pillars. The defects are stated facts that went stale or never matched the wave data, plus two test seams, and all are text edits with no balance change. The one real creative call is whether the heavy is too cheap to leak, which belongs to the bot baseline.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Dependencies: Tower, Hero and Battle HUD are listed as having no GDD yet; all exist and list this one.
- [BLOCKING] Formulas, packet_length: every starter packet fails `packet_length ≤ 2 × burst_radius` (180 to 462 against 140), even at factor 0.5; keep only the splash floor, since Burst fit tests the rest.
- [BLOCKING] Formulas, packet_length: "the gates here use 5" contradicts Burst fit's 4; five at spacing 36 span 144, over a 140 disc. Tower's `burst_spike` also cites a gate of 5 hits.
- [BLOCKING] Layout L3, L7: 92 is slot 36 plus hero grab 56, not "hit discs never touch"; L7's +64 has no derivation.
- [BLOCKING] Layout L6, Battle HUD prompt: at the largest inset the panel spans y 155 to 189 over the path's edge at 174, against Rule 4's "never routed under a panel"; centre it at `I_top + 89`.
- [BLOCKING] Rule 5, Type table: the heavy soaks only while it leads; followers pass it at 60 against 38, then draw fire while it trails.
- [BLOCKING] Starter values: total HP is 1.26 to 1.64 times the last, not 1.25.
- [BLOCKING] Wave 4 Intent, catch_up example: meeting points run 518 to 1,264, starting before the hairpin.
- [BLOCKING] Wave 6 Intent: fronts stagger from 104 to 1,552 rather than converging before the exit.
- [BLOCKING] Rule 14, Acceptance Criteria 10, 12: no reader exists for wave state or `wave_tick`.
- [BLOCKING] Acceptance Criteria 11: both waves use 2.0, so a and b cannot be told apart; use 2.0 and 3.0.
- [RECOMMENDED] Starter values: heavy `lives_cost` 3 and/or bounty 24, since a heavy is cheap to leak (lives per HP .0027 against .008). User decision, needs a bot run.
- [RECOMMENDED] Tuned assuming the hero: towers-only may win only with 3 lives or fewer; current bots all lose.
- [RECOMMENDED] Wave 1, wave rules: "cannot end the stage", since an idle player keeps 2 lives.
- [RECOMMENDED] Formulas: `peak_alive_ub` tolerance on `ceil`; no shared tick only for interval ≥ dt; `catch_up` only when the faster spawns later; move_speed 2,000 is code-built only.
- [RECOMMENDED] Core Rules, States: Rule 7 same latency by two entries; Rule 14 readers do not reset per wave; In field to Leaked for code-built paths.
- [RECOMMENDED] Acceptance Criteria: split 18 and 19 per rule with boundary pairs, add edges to 1, unbundle, add `wave_index`, `got_through_by_type`, Rule 13's reads, the `d_next` boundary and the `to_ticks` floor, name the fakes, and cover `packet_length`, `catch_up` and danger.
- [RECOMMENDED] Deferred criteria: define the fixed script set, say a failed Empty field reopens wave 2, split Always-call and Order, run Burst fit and Two fronts now if they need no towers, and give the Manual list pass conditions and a sign-off.
- [RECOMMENDED] Layout: every in-field path point within leash of a legal pin; an L rule for arc discs against Start/Call and the burst line; L11 a stage flag, not an ID; re-examine L8; slot 1 to y 310 at the next bot run.
- [RECOMMENDED] Visual/Audio: one Reduce Motion line for bob, jitter and leak pop; leak-pop restart limit.
- [RECOMMENDED] Acceptance Criteria, Manual: a render test with thresholds for free-slot contrast, 22 against 30 px, keyline, notch and danger-cue habituation.
- [RECOMMENDED] Game Feel, Open Questions: an observable target; no wave-start telegraph, so qualify "seen seconds ahead"; state stretch mode and minimum dp.
- [RECOMMENDED] Story notes: Path corners by screenshot rather than `draw_polyline` (unverified for 4.7); reused typed buffers; injected sink; no `CONNECT_DEFERRED` on the two signals; the roster as sole owner; cached `cum[]`; three draw passes; Vector2 float32 edge care.
- [RECOMMENDED] Open Questions: wave 6's dead gold, HP per gold, no heavy-only intro or relief wave, dead time, the leak ratchet.
- [RECOMMENDED] Pillar 3: paper-sketch stages 2 and 3 through L1 to L13 before authoring them, as the Open Question already asks.
- [RECOMMENDED] Wave 2: 1.75 s of slack against burst recovery; watch it at the bot baseline.
Reviewed-Content-Hash: design/gdd/enemy-wave.md 44814c33b176fbfebd32d6dee614a28102c1d9f2
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 74aec3a9e2b7094565a249d773621ecaee83c7c7
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b81528a4102d977ed04d869e0f4ecc9a1b117559
Reviewed-Content-Hash: design/gdd/combat-damage.md 9fe61dab43d04486b54833702d9215b1c72762b5
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d30777d982233c4efe7199017dec3a529ef504fc
Reviewed-Content-Hash: design/gdd/tower-system.md d490ea056b53fcf56a7eb9f35281272e3661275a
Reviewed-Content-Hash: design/gdd/hero-system.md 1f980cde56d56f1a28f2806b0c4a1c0927f168a3
Reviewed-Content-Hash: design/gdd/battle-hud.md 3cdc44a0cd4f605edb485cf23a9c85513b2b670a
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 133c303cce1942462fc2472acdaae66522a2fba0

## Revision — 2026-11-02 — Eleven blockers, one user decision and all recommended items applied, re-review pending
User decision: a heavy now costs 3 lives. A bounty of 24 was simulated too and rejected, since single alone then caught the best mixes, so the gold tables are unchanged. The Hero table, Tower's upgrade table and Tower's 68 gold, now 48, follow.
Blockers: Dependencies lists the existing GDDs; `packet_length` keeps only the splash floor, and the gates use 4; L3 and L7 state their reasons; Battle HUD's prompt moved to `I_top + 89`, so L6 protects it; Rule 5 says a heavy soaks only while leading; 1.26; wave 4's and wave 6's Intents match the meeting points; `wave_state()` and `wave_tick()` are reads; wave a and b differ in criterion 32.
Recommended: L14 and the `requires_bend` flag are added, with a Data edit, and an arc row in Battle HUD; slot 1 at y 310 was simulated and rejected at a 24.4% share median, so it stays; criteria went from 19 to 64, with bundles split, edges and missing rules covered and fakes named; Burst fit and Two fronts now run with no towers, and pass; a render test with pass marks and fallbacks replaces the Manual grey test; notes for stories and new Open Questions are recorded.
The bots re-ran in both hands. Every gate passes, with the share median still at 25.1%, the band's floor.
