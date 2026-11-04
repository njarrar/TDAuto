# Review Log: Battle HUD & Build UI

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: ux-designer, ui-programmer, systems-designer, qa-lead, creative-director
Blocking items: 6 | Recommended: 18
Summary: Structure and clearances hold, and the repairs are local. Two layouts fail by arithmetic (Won panel, arc panels), `halted()` is misread as Fatal, Controls bypass edge and slop rules, the HudLogic split cannot satisfy the criteria, and prompts and pips contradict themselves. Specialists raised 17 blocking; the creative director kept 6. Finger-accuracy rates are unmeasured estimates.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Edge Cases: `halted()` is true on Won and Lost, so test `phase() == FATAL`.
- [BLOCKING] Layout, Rule 4, AC2: the Won panel holds under 4 rows of 5 to 7, has no inset term and covers the burst button. User decision on layout.
- [BLOCKING] Visual table: arc panels of 44 units cannot hold two 14 dp lines. User decision on `R`.
- [BLOCKING] Rules 2, 6, 8, 17: Controls apply edge margin, insets and slop; a guarded disc press closes the arc.
- [BLOCKING] Rule 1, Acceptance Criteria: replace the three-piece table so HudLogic owns registration, gestures and commands, then fix criteria 1 to 4, 8, 9, 12, 19, 21, 22, 28, the header and the "HUD ADR" owner.
- [BLOCKING] Rule 13, Prompt states, pips, Rule 10: prompt end states, the `wave_index()` order (Flow), and the false "Build is unaffected".
- [RECOMMENDED] Rule 10: Start/Call's dead overlap is 36% at the worst distance. User decision (keep the rule, fix the text recommended).
- [RECOMMENDED] Rule 7: a build refund. User decision (defer to phone data recommended).
- [RECOMMENDED] Open Questions: wrong-disc rate, chip second tap, 7.2 clearance and dead overlap go in the phone test.
- [RECOMMENDED] Visual table: arc panels as targets, unaffordable contrast and Manual pass conditions go to `/ux-design`.
- [RECOMMENDED] Integration criteria 29, 31, 32: rig detail waits on ADR-0001 and ADR-0004.
- [RECOMMENDED] Rule 1: quantise redraws; the single `_draw` reruns almost every frame.
- [RECOMMENDED] Interactions: `targets()` unused; `slot_state()` per frame; `dt` and hero id have no source.
- [RECOMMENDED] Rule 15: name the snapshot's trigger and timer start, and keep `advance` running after an outcome.
- [RECOMMENDED] Rule 2: result-screen focus loss, second finger, Resume freeing its caller; toggle modals rather than mount them.
- [RECOMMENDED] Rule 12: add the wedge formula, guarding integer division and a zero divisor.
- [RECOMMENDED] Rule 16: a fallback for a top type with no line; name the burst counter; add a content row.
- [RECOMMENDED] Rule 9: a re-tap on the tower can spend gold; sample the window at press.
- [RECOMMENDED] Rules 13, 16: "big button", "heavies" and prompt 2 during an arc.
- [RECOMMENDED] P1: reach, occlusion and a required left-hand run.
- [RECOMMENDED] Acceptance Criteria: ten rules and edges without a criterion.
- [RECOMMENDED] Prompts row: remove the read no prompt needs.
- [RECOMMENDED] Layout: Play again's edge does not move with `I_bottom`.
- [RECOMMENDED] Content rules: "Call +900" at the floor of `early_call_seconds_per_gold` does not fit.
Reviewed-Content-Hash: design/gdd/battle-hud.md 1d9cb4faf2507cd8e9bb0c1328bc4fc9d291608f
Reviewed-Content-Hash: design/gdd/enemy-wave.md 780379132e91e72db9206809509ec5b4381372ee
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 1a1ff7b3a75e514e0b299f59f42e60e3fbff29fc
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
User accepted every recommendation ("All recommended"). Decisions: `R` 96 with L1 x 156 to 384 (156, not ux-designer's 155, keeps discs clear of the edge margin) and provisional 80 x 56 panels for `/ux-design`; keep the Start/Call rule and fix its text (the 36% recomputed); build refund deferred; Won in two columns with the burst button hidden on results. Applied: all 6 blocking and most recommended items. Moved to Open Questions rather than changed: chip second tap (the 'sample at press' fix), reach and occlusion, panels as targets, contrast.
Re-review pending: the hashes above no longer match this document.

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: ux-designer, ui-programmer, systems-designer, qa-lead, creative-director
Blocking items: 7 | Recommended: 15
Summary: Structure and clearances hold, and the repairs are local. Of the 6 prior blockers, 4 are resolved, Won is partial, and the Control rules are resolved but their new text caused two blockers: Paused cannot resume, and Retry has no hit area. Specialists raised 20 blocking; the creative director kept 7, all spec repair except Won's row 3, which needs a user decision. Widths are estimates; nothing was rendered or run on a phone.
Prior verdict resolved: Partly (4 of 6)
Findings:
- [BLOCKING] Rules 2, 11, 17, AC12, AC21: Paused counts only while Armed and its clock is frozen, so it never resumes. Exempt it from arming; cut "a grip's brush".
- [BLOCKING] Rules 2, 11, 15: Retry and Play again have no hit area, so a tap on Won's board rebuilds. Hit-test the rect at press, require release inside, hold on target, replace only on Paused, and a cancelled press never counts.
- [BLOCKING] burst_wedge: 1 at Cooling start, while art bible §7 wants fill returning. Use fill = 1 − wedge and test both ends.
- [BLOCKING] Rule 15, Layout: Won row 3 fails (glyph 30 in a 26 row; about 270 against 198; bare "Got through" on no leak). User decision: omit on Won and keep in the log (recommended), or a taller panel, y 736 to 952.
- [BLOCKING] Rules 1, 12; Hero Rules 11, 12: cooling digit has no single owner; `aim_state()` and `cooldown_digit()` are absent here, HeroInput is built later and TowerInput is unplaced.
- [BLOCKING] Rules 1, 2; architecture B9: HudLogic needs `modal_move`, pointer args, cancel, lifecycle, `tap_slop`, `edge_reject_margin`, insets, `reduce_motion` and field width, in the fakes too.
- [BLOCKING] Acceptance Criteria: AC4, AC5 leave `build` args unasserted; AC4's sampling and Rule 6's "under 200 ms"; move AC28 to integration; strike AC30's root clause; "runnable today" lets AC32 to AC37 lapse.
- [RECOMMENDED] Flow, HUD, Input, Tower, Hero: `signal phase` plus `func phase()` fails to parse on 4.7.2 (probe; not re-run by the director). Rename to `phase_changed`, before stories.
- [RECOMMENDED] Rule 2: Paused's exemption means a brush can resume a live wave. Confirm with the user; phone test.
- [RECOMMENDED] Rules 1, 15, 17: HudLogic owns modal visibility, synchronously with `modal_changed`.
- [RECOMMENDED] First story: 540 × 960 viewport and debug routes to states, or evidence reads NOT VERIFIED.
- [RECOMMENDED] Interactions, Dependencies: `tower_upgraded`, `wave_called_early`, `wave_cleared`, `def_id`, `dealt_by_kind`, `best_victims`, tower IDs and role tags.
- [RECOMMENDED] Rule 8, art bible §7: arc panels cover the lane in Wave at slot (270, 305). Art-director, in `/ux-design`.
- [RECOMMENDED] L1: add y ≤ 924; fix "below the band" wording; panels meet the prompt at `I_top` 11, not only a large inset.
- [RECOMMENDED] Won `B`: columns need `− B`; tower bodies are overlapped above `B` 16. Mobile Platform.
- [RECOMMENDED] Open Questions: radius 44 needs L1 x 164 to 376.
- [RECOMMENDED] Rule 16: line 3 names a button hidden on Lost; `burst_started` then Lost advises a done act; wrap the line; rank unlisted types last.
- [RECOMMENDED] Rule 15: "Burst N" is the only use of that word; N is unlabelled as damage.
- [RECOMMENDED] Rule 10: "nearer the centre" means away from the hero; a hero crossing the centre makes the whole button dead briefly.
- [RECOMMENDED] Rules 2, 4: resize clear, "consume every event", scope "Hidden: not registered" to Start/Call, Fatal in Rule 4, `dt` from Battle.
- [RECOMMENDED] burst_y and chip: hit disc enters the inset above `I_bottom` 96; chip tap dead for its first 200 ms.
- [RECOMMENDED] Criteria: AC1, AC3, AC8, AC9, AC15, AC31, AC36 repairs; step timers by at most 100; Manual list gaps and thresholds; no localization path.
Reviewed-Content-Hash: design/gdd/battle-hud.md a8f89fe590ea44636a835021accab97e365ff7f3
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 5e5df4a50191c71f81644957fb43ef96b38ab6d5
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4c34ae187a1d77212e8c66bd6454c8d7a170ad95
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: design/gdd/hero-system.md 377e450bbee022ae776076cebdd1ed1c092a02fc
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 8bf4871b7bc7159d5507ef6f2b24756e9e39c1c5
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f

## Revision — 2026-11-04 — after the review above (not a new verdict)
User accepted every recommendation ("Implement all recomended"). Decisions: Won omits "Got through" and the log keeps it; Paused has no arming, and a brush resuming a live wave goes to the phone test. Applied: all 7 blocking and most recommended, including `phase_changed`, `modal_changed`, `burst_fill`, the build order and HudLogic's seam. Moved to Open Questions: arc panels over the lane, the "Burst N" wording, Won's overlap above `B` 16. The Criteria row's AC1, AC3, AC8, AC9, AC15, AC31 and AC36 had no itemised text in this log, so those repairs are the reviser's reading, and AC8 and AC31 were left as they stand.
Re-review pending: the hashes above no longer match this document.

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: ux-designer, ui-programmer, systems-designer, qa-lead, creative-director
Blocking items: 5 | Recommended: 14
Summary: Layout and formulas verified clean, and no structural change is needed. Specialists raised 19 blocking; the creative director kept 5, upgrading one. Rule 2, which has blocked all three rounds, still has gaps. The director advises no further full review: after the fixes, a lean check by ui-programmer and qa-lead on the changed text. Text widths are estimates; nothing was rendered or run on a phone.
Prior verdict resolved: Partly (new text in Rule 2 raised new gaps)
Findings:
- [BLOCKING] Rule 12, AC39; Hero Rules 11, 16: a cooling or Locked press has no read for held or where. Add `button_press() -> {kind, pos}` to HeroInput. User decision on where the digit shows.
- [BLOCKING] Rule 2, AC21: add `modal_cancel_pointer(i)`; same-pointer press while held is cancel plus press; on Paused any later non-rejected press replaces what is held; a dead press blocks nothing on a result; a rejected press holds and replaces nothing; bind event translation to ADR-0003.
- [BLOCKING] Rules 11, States, AC11: opening Build emits no `phase_changed`, so Start never arms. Read `phase()` after Flow enters Build, tested on real Flow.
- [BLOCKING] AC3, AC4, AC5, AC15, AC20: false passes (wave identity, all three disc mappings, separate Locked fixtures, runner-up and no-line type).
- [BLOCKING] Done sentence: deferred rows must pass and Manual is included; add AC40, Control to `modal_press` and signals to `modal_cancel()`.
- [RECOMMENDED] Rule 1: name the wrapper as injector, Battle's exposure, Combat reads, log IDs and the latch.
- [RECOMMENDED] Rule 1: extend the redraw key and state the fill step.
- [RECOMMENDED] AC2 Fatal; AC10 to AC36; AC23 clear or outcome; AC16, AC29, AC30, AC32, exact values.
- [RECOMMENDED] Compute `cooldown_digit()` on read; read `cooldown` at use or justify the cache; Fatal gives `modal_changed(none)`.
- [RECOMMENDED] HudField draws from `burst_button_centre()`; `to_ticks(1.0)`; chip_bar's literal 1500 and AC8's window.
- [RECOMMENDED] Content rows: chip against Start/Call, L1 against Won's panel.
- [RECOMMENDED] Retry's Arming look, 120 against 300 ms; Start/Call's alpha ramp against art bible §7 (user decision); palm on Play again; width render tests.
- [RECOMMENDED] Stale architecture rows; Flow Rule 10's "takes every event".
Reviewed-Content-Hash: design/gdd/battle-hud.md 044488039c9a221f998173317300db5f3cd7ab5b
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 05e3e8f4ca5b1c2a34b39d2ebc9215b0d5342861
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 0804873149506940e730239e7998a943f8bcc5cd
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md c67e5441a28be83b92efa4b903b15c4e76918a6b
Reviewed-Content-Hash: design/gdd/tower-system.md 86f753dacdcc4d904575ab5d6bdfffb8fd4f6415
Reviewed-Content-Hash: design/gdd/hero-system.md d075d8207bffb1b7f4a23a2f0467da21c2509528
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md b869a7ca338cf3100f72219f98e64207b252dec6
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f

## Revision — 2026-11-04 — after the review above (not a new verdict)
User accepted the recommendations: on a cooling press the digit shows above the thumb only; Start/Call and Retry step to full at Armed; lean check next, per the creative director. Applied: all 5 blocking and the recommended list.

## Review — 2026-11-04 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: ui-programmer, qa-lead (lean check the creative director set)
Blocking items: 0 | Recommended: 2
Summary: Kept blockers 1 to 5 resolved, on a trace of Rule 2 and a line-by-line check of AC21. QA's one finding, the Done sentence, was rewritten from its own text and not re-read. System Done now waits on ADR-0001, 0003, 0004, 0011 and Mobile Platform; stories can close while a row is open. Nothing was run, and Rule 2's event assumptions depend on ADR-0003.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Rule 2: a lost release, then a rejected re-press by that pointer, leaves the stale press; it counts only if the finger lifts within `tap_slop` of it. Same as the adapter.
- [RECOMMENDED] Rule 12: a cooling press held past the cooldown's end can show "0" above the thumb. Look only.
Reviewed-Content-Hash: design/gdd/battle-hud.md 53e31996a65be6476eb2e700352e027701c1b760
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 85f7616bf55e163f7ef55c61de49bf99b593b7ce
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md c1fd31adac239441dbdae3fe76d40b24379b3e5d
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md fda517f00006319d13c59450aeec9d155bb70c8f
Reviewed-Content-Hash: design/gdd/tower-system.md 14b131b888ccec57b15294ebb57b928615b890d0
Reviewed-Content-Hash: design/gdd/hero-system.md c9f2fd38018ff70731690e5aaaa7bd148c397746
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md f2ad63e7bb8cf880695e73dc0a744bc91b56fe70
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f

## Revision — 2026-11-04 — after a lean read (not a new verdict)
One adversarial reader checked the day's added rules (S1, S2, the four cross-review decisions) and returned NEEDS REVISION with 18 findings. All five rated BLOCKING were fixed (Flow Rule 9, Thumb cost pass condition, redraw key, criterion 6, HUD 0.55 evidence). Recommended items 3, 7, 9 to 14, 16 to 18 and part of 8 were fixed. Not done: concept `towers-only` unit at Vertical Slice (15). The fix pass was not re-read, per the one-review, one-fix cap the producer recommended. No hash stamped, because this text has no review verdict.
