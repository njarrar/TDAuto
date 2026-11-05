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

## Review — 2026-11-05 — Verdict: APPROVED
Review mode: full · Workflow: standard
Scope signal: L
Specialists: none spawned. This re-review ran as a subagent with no Agent tool, so no specialist or director agent ran. One fresh reviewer (not the author of the GDD or its edits) took the ux-designer, ui-programmer, game-designer, systems-designer, qa-lead, godot-specialist and creative-director views in turn. No specialist or director passed this GDD.
Blocking items: 1 (wording, fixed in this pass) | Recommended: 6
Summary: A re-check requested by the user, with attention on the edits the two earlier passes made. The four first-review fixes hold against the Accepted ADRs (ADR-0001, ADR-0006 Decision 9, ADR-0010 Decision 1, ADR-0011 Decision 1 with its HudLayer amendment), and the second pass's edits (UI Requirements arming line, Rule 6 radius 36, Rule 16 item 4, Rule 19 field names, Tuning Knobs, AC 1, 5, 29, 33, new AC 34) each check out against ADR-0005, ADR-0006, ADR-0007, ADR-0010 and ADR-0011. One leftover of the first blocker's kind was in Rule 15's table and is fixed; no blocking item remains. Text sizes against AR-V-01 stay open in design/ux/hud.md (H-01 to H-10), owned by that spec.
Prior verdict resolved: Yes (first review's 4 blockers stay fixed; its recommended items were applied, except those it deferred)
Completeness: 6 of 6 required at standard (Overview, Detailed Design, Formulas, Edge Cases, Dependencies, Acceptance Criteria). Tuning Knobs now present; Player Fantasy absent, advisory at standard.
Dependency graph: all seven upstream GDDs exist and each names this one; the five downstream systems have no GDD yet, as the Dependencies section states.
Registry: design/registry/entities.yaml lists no entries (0 names), so values were checked against the dependency GDDs and ADRs.
Findings:
- [BLOCKING, fixed] Rule 15 table, Lost row 1: "Broke on wave N of `wave_ids` size" named a live read, while the prose and ADR-0006 Decision 9 / L-SIG-5 take the stage size from the snapshot. Now `wave_count`.
- [RECOMMENDED] Rule 16 item 4: "if its role is not yet built" needs which roles are built, and the snapshot carries only `slow_tower_built` and `towers_built` (ADR-0006 Decision 9, ADR-0010 Decision 5). Name the source (for example TowerSim's `slot_state()` read in the same frame step 3, since towers cannot change after the outcome) or add per-role built flags to the snapshot by an ADR-0006 amendment. User or architecture decision; not edited.
- [RECOMMENDED] Rule 16 item 4: ADR-0005 Decision 5 lists HudLogic's frame-step-3 keys as `cost`, `range` and Burst `cooldown`; the GDD's `lives_cost` read follows the same site and rules (and the control manifest's general HudLogic line) but is not listed. Recorded in the GDD as an ADR-0005 sync item; raise it at the next architecture review.
- [RECOMMENDED] Tuning Knobs: two rows give no safe range (Arc disc guard: a note on its clock; Result text delay: "waits for the first phone test"). Add ranges when the phone test sets them.
- [RECOMMENDED] Tuning Knobs / UI Requirements: the 1 s static refusal cue duration (AC 5) has no named owner. Under ADR-0011 Decision 9 it changes pixels only, so it belongs in ViewStyle and would run on ViewClock; AC 5 tests it through HudLogic's advance(ms). Say which.
- [RECOMMENDED] Visual/Audio table: Start/Call labels 14 dp, the arc word size, the burst digit size and Paused text size against AR-V-01 (16 dp labels and costs, 18 dp digit). Known open items owned by design/ux/hud.md H-01 to H-04 and H-10; update this table when they are decided. Not a GDD blocker per the user's scope.
- [RECOMMENDED] Player Fantasy (advisory at standard): still absent; the Summary's "calm" line could seed it.
- [NICE-TO-HAVE] Header: the CD-GDD-ALIGN line and Quick reference use the em dash; leave unless the doc is restyled.
Wording fixes made in this pass (no balance value or design intent changed):
- Rule 15 table: `wave_ids` size to `wave_count` (the blocker above).
- Rule 16 item 4: adds the `halted()` check after each `lives_cost` read (ADR-0005 Decision 5, control manifest) and names the ADR-0005 key-list sync item.
- Rule 1 note: the stale paraphrase of TR-hud-001 ("display-only Controls") now cites the registry wording of 2026-11-05, which states the same four pieces.
- Dependencies, Enemy & Wave row: the result takes `wave_index()` through the snapshot's `last_wave_started`, not live.
- AC 5: "up at 999 ms of advance(ms)" now reads "after 999 ms in total of advance(ms) calls", since advance clamps each call to 100 (Rule 11, AC 12).
- Status line set to APPROVED.
Status set: GDD header APPROVED; systems index row 8 Approved; Progress Tracker "Design docs approved" recounted from the rows to 8 (another session approved Flow and Input in the same window).
Reviewed-Content-Hash: design/gdd/battle-hud.md cd07c983f92f8e1e43dbeb2d17466e009c080739
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 5fc68e4c2eda531b8ef80a5663b2f33961b139cf
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md aafb834a099f79bf46c3d14ec868a3d5c177e54e
Reviewed-Content-Hash: design/gdd/tower-system.md feecd55d693e8bc9c802b4115d51ee494ea5bfba
Reviewed-Content-Hash: design/gdd/hero-system.md 88c68ce97af3b80dd0dff559a3ab3d65a2cfa1f2
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 166b1059eda8e25c6ab0dd9e623c021508a64190
Reviewed-Content-Hash: design/gdd/enemy-wave.md adfe9932b1756518dd4219a26cdb9c048950950d
Reviewed-Content-Hash: design/gdd/combat-damage.md e4df04fab059c0779ec3460522a8b4f0f6605fc1
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md eb4deee4f73f034bc672f49d569d8d5601822d8e
Reviewed-Content-Hash: design/ux/hud.md b936013f098a15685f1d35ad23a01e878d5e0a95
Reviewed-Content-Hash: design/accessibility-requirements.md b0574e2ac2870c485edb5d038e477577e9d46700
