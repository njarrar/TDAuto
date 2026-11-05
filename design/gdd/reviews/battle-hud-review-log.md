# Review Log: Battle HUD & Build UI

## Review — 2026-11-05 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: none spawned. This review ran as a subagent with no Agent tool, so no specialist or director agent ran. One reviewer took the ux-designer, ui-programmer, game-designer, systems-designer, qa-lead, godot-specialist, performance-analyst and creative-director views in turn. No specialist or director passed this GDD; a re-review should spawn them.
Blocking items: 4 (all wording, all fixed in this pass) | Recommended: 12
Summary: The design is sound, its layout and formula arithmetic checks out, and every dependency GDD exists and lists this one. The four blockers were stale text against Accepted ADRs (result values not all from the snapshot, the chip disc's owner, a "HUD ADR" and `free()` that no ADR has, and no `HudLayer`), all fixed in this pass. What is left needs the user: a 120 ms versus 300 ms arming line, text sizes against AR-V-01, and gaps in the criteria (no test for the AccessKit name and live setting).
Prior verdict resolved: First review
Completeness: 6 of 6 required at `standard` (Overview, Detailed Design, Formulas, Edge Cases, Dependencies, Acceptance Criteria). Player Fantasy and Tuning Knobs absent, advisory at `standard`.
Registry: `design/registry/entities.yaml` is an empty stub, so values were checked against the dependency GDDs and ADRs instead.
Findings:
- [BLOCKING, fixed] Rule 15: N was the live `wave_index()`; ADR-0006 Decision 9 and L-SIG-5 take every result value from the snapshot. Now `last_wave_started`, `wave_count`, `lives_left`, `starting_lives`.
- [BLOCKING, fixed] Interactions with Other Systems: the HUD was listed as registering the chip disc; Rule 9 and ADR-0010 Decision 1 make it TowerInput's. Tower and Hero rows now name TowerSim, TowerInput and the wrapper's one-time pass of `burst_button_centre()`.
- [BLOCKING, fixed] Acceptance Criteria, Deferred: owner "HUD ADR" does not exist, and "`free()` timing" contradicts ADR-0001 (never `free()` on the wrapper). Now ADR-0003 S0, ADR-0004 V14, ADR-0001.
- [BLOCKING, fixed] Rule 1: no `HudLayer`; ADR-0011 Decision 1 (amended 2026-11-05) and Guideline 13 put HudTopBand and HudField under one `CanvasLayer`, since a `Control` under a `Node2D` gets no parent area.
- [RECOMMENDED] UI Requirements: "120 ms: arc, presses, arming" contradicts Rule 11, the Visual table and IP-21, which all give arming 300 ms. User to confirm and drop "arming" from the 120 ms list.
- [RECOMMENDED] Visual/Audio, UI Requirements: AR-V-01 says 16 dp for labels and costs and an 18 dp floor for the burst digit; Start/Call labels are 14 dp, the arc panel's word and cost size is unstated, and the burst digit size (24 dp in ADR-0011 Decision 6) is not in the GDD.
- [RECOMMENDED] Acceptance Criteria: no criterion checks that HudTopBand sets `accessibility_name` and `accessibility_live` (`AccessibilityServer.LIVE_POLITE`) on a gold or lives change (TR-hud-001, ADR-0011 Decision 6).
- [RECOMMENDED] Acceptance Criteria 5: covers the static refusal cue for the arc only; add the chip and the locked burst button (AR-V-11, IP-24).
- [RECOMMENDED] Acceptance Criteria 1, 29, 33: "a new instance holds nothing", "identical full state" and "watched failing once" need a measurable form, for example `battle_state.digest()` and `counters()` equal after every tick (ADR-0010 Decision 7).
- [RECOMMENDED] Rule 6: the arc disc radius (36) appears only in AC 4; state it in the rule beside TAP 300.
- [RECOMMENDED] Rule 16 item 4: count times `lives_cost` needs each type's `lives_cost` from the Enemy records, which the snapshot does not carry, while L-SIG-5 limits ResultScreen to snapshot values. Say HudLogic reads `lives_cost` from the records, or raise an ADR-0006 amendment to put lives lost by type in the snapshot.
- [RECOMMENDED] Tuning Knobs (advisory at `standard`): list the constants with their owner per ADR-0011 Decision 9: HudLogic (arming 300 ms, disc guard 200 ms, `R` 76, disc radius 36, Start/Call radius 48, three ground rings, result delays 400 and 1,000 ms) and ViewStyle (pixel timings, alphas, sizes).
- [RECOMMENDED] Player Fantasy (advisory at `standard`): the Summary's "calm" line could seed it.
- [RECOMMENDED] Formulas, burst_y: an `I_bottom` above 72 clamps the button to 816, which can sit inside the unsafe area. Add to the Mobile Platform Open Questions row.
- [RECOMMENDED] AR-V-03: panels are sized for 100% text only; note the Alpha owner beside the Visual table.
- [RECOMMENDED] Other documents, not edited here: Input GDD line 129 says the top-band Controls consume their own events (HUD Rule 1: HudTopBand ignores input) and counts ground rings per session (HUD Rule 14: per battle); IP-23 still puts the retry latch in Flow (already logged by `architecture-review-2026-11-05.md`).
- [NICE-TO-HAVE] Rule 19: "damage by source and kind" could name the snapshot fields. Header "Last Verified 2026-11-02" predates the ADR-0006, ADR-0010 and ADR-0011 syncs.
Wording fixes also made in this pass (not blockers): Rule 2 names ADR-0003's S0 checks in place of "the ADR"; Rule 18 says teardown in place of "frees"; Rule 19 drops the call parentheses from the snapshot field `slows_applied`; the ADR note under Core Rules now reads "Settled by ADRs"; the Edge Case on displayed and paid bonus cites ADR-0004 Decision 4 and AC 31; UI Requirements names `PresentationSettings` and `MotionPolicy` (ADR-0001, ADR-0011 Decision 8).
Status set: GDD header and systems index to In Review. The hash below is of the GDD after these fixes, so a re-review without further edits reads UNCHANGED; the recommended items above are the next revision.
Reviewed-Content-Hash: design/gdd/battle-hud.md 39c88b57183b7d8d33c33a5faa5b802499925045
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 93a774e02d9d14747e67ead5ce82140d1718b81f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d0971ae2056275d68099e04af472c70bac83009d
Reviewed-Content-Hash: design/gdd/tower-system.md 0d7fc21d197c7b1ae4c7bc6f6749df6d58d7b886
Reviewed-Content-Hash: design/gdd/hero-system.md 88c68ce97af3b80dd0dff559a3ab3d65a2cfa1f2
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4e034772ff47e826f54e2e71a40c11e00b0a8fd4
Reviewed-Content-Hash: design/gdd/enemy-wave.md adfe9932b1756518dd4219a26cdb9c048950950d
Reviewed-Content-Hash: design/gdd/combat-damage.md e4df04fab059c0779ec3460522a8b4f0f6605fc1
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md fb484d24990461f0800de4d022afa95997ee512d

## Revision — 2026-11-05 — review recommendations applied
Status unchanged (In Review; re-review pending). The user asked for the recommended items to be applied. Wording and criteria only; no balance value or design intent changed.
- UI Requirements: arming moves from the 120 ms list to its own 300 ms entry, matching Rule 11, the Visual table and IP-21.
- Rule 6: the arc discs state radius 36 beside TAP 300.
- Rule 16 item 4: the count is the snapshot's `got_through`; HudLogic reads each type's `lives_cost` from its Enemy record through the accessor in frame step 3 (ADR-0005 Decision 5), since the snapshot does not carry it.
- Rule 19: "damage by source and kind" now names the snapshot fields `damage_towers`, `damage_hero`, `damage_burst` and `hero_share`.
- New Tuning Knobs section: the HudLogic constants (arming 300 ms, disc guard 200 ms, `R` 76, disc radius 36, Start/Call radius 48, three ground rings, result delays 400 and 1,000 ms) with safe ranges, and a pointer to ADR-0011's `ViewStyle` for pixel-only values.
- AC 1, 29 and 33 rewritten in a measurable form: AC 1 compares a rebuilt HudLogic with a fresh one; AC 29 compares `battle_state.digest(battle)` and `counters()` after every tick (ADR-0007 helper, ADR-0010 Decision 7); AC 33 needs each check to fail on its own fixture while the others pass.
- AC 5 now covers the static refusal cue on the chip and the locked burst button too (AR-V-11, IP-24).
- New AC 34: HudTopBand sets `accessibility_name` and `accessibility_live` (`AccessibilityServer.LIVE_POLITE`) on a gold or lives change (TR-hud-001, ADR-0011 Decision 6).
- Header Last Verified set to 2026-11-05.
Deferred: text sizes against AR-V-01 (may break layout clearances; needs the UX spec); Player Fantasy (advisory at `standard`); a bottom inset over 72 units (handed to the Mobile Platform GDD); 125% text (Alpha).
Other documents: `design/ux/interaction-patterns.md` IP-02 now cites Input Rule 3 for sticky drag; IP-23 already put the retry latch on the app root, so it needed no change. `design/gdd/game-concept.md` Pillar 4 and its design risk now ask for at least two non-developer testers (Input GDD P1).
