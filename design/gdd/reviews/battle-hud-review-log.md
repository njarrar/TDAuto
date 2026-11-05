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
Specialists: ux-designer, ui-programmer, systems-designer, godot-specialist, qa-lead, creative-director
Blocking items: 4 | Recommended: 14
Summary: The six prior blockers are fixed and the systems designer verified every formula, example and clearance. Four local contradictions remained: the Paused screen could never arm, the Won panel's "build stays visible" claim fails once a bottom inset exceeds 8 units, the criteria's "complete list of fake calls" cannot hold beside per-frame reads, and single advance steps cannot reach boundaries under the 100 ms clamp. The creative director routed the other specialist blockers to architecture.md B9/B10, ADR-0003 and /ux-design, and reopened no user decision.
Prior verdict resolved: Yes (all 6 prior blocking items)
Findings:
- [BLOCKING] Rules 2, 17, States table: the Paused screen counts only while Armed but its clock is frozen, so it can never resume.
- [BLOCKING] Layout, Won panel: the "finished build stays visible" claim is false once B > 8 (bottom towers reach y 736).
- [BLOCKING] Acceptance Criteria preamble: "recorded fake calls are the complete list" cannot pass with per-frame reads.
- [BLOCKING] Rule 11, AC 4, 8, 12, 19: name the clamped clocks; tests step at most 100 ms.
- [RECOMMENDED] Arc panel word outside the hit disc: a safe miss; /ux-design decides disc plus panel (downgraded from ux-designer's blocker).
- [RECOMMENDED] Content rules: early-call bonus cap enforced as one digit over the stage's waves.
- [RECOMMENDED] Formulas: burst_y and Play again clamp into insets above 72 (Mobile Platform GDD).
- [RECOMMENDED] Content rules: L1 and burst-line bounds as formulas over edge_reject_margin 0 to 48.
- [RECOMMENDED] Rule 10: 36% holds at rest only.
- [RECOMMENDED] Formulas: ticks_per_second as to_ticks(1.0); chip window read from ChipWindow.
- [RECOMMENDED] Formulas: cite Hero Rules 13 and 15.
- [RECOMMENDED] Rule 15: omit an empty "Got through" row on Won.
- [RECOMMENDED] Rule 7: a non-motion NO_GOLD cue under Reduce Motion.
- [RECOMMENDED] Rule 10: feedback for a swallowed dead-overlap tap; Lost panel compaction (/ux-design).
- [RECOMMENDED] Rules 10, 11: describe one dead-gesture flag.
- [RECOMMENDED] Rule 1: `phase` vs `phase_changed` (ADR-0006, QQ-07).
- [RECOMMENDED] Acceptance Criteria: Rule 13 act-ends, Rule 1 build order, Rule 9 chip target and untested edges; split compound criteria; move criterion 30's latch part to 35; Manual pass conditions.
- [RECOMMENDED] Architecture B9/B10: modal press inputs and move events, lifecycle route to HudLogic, Retry callable, log reads, static burst_button_centre(), reduce_motion, signal list (routed, not GDD).
Reviewed-Content-Hash: design/gdd/battle-hud.md a8f89fe590ea44636a835021accab97e365ff7f3
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d79fe3bf982a1d15a806cc0725421521a6a735d5
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: design/gdd/hero-system.md 377e450bbee022ae776076cebdd1ed1c092a02fc
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4c34ae187a1d77212e8c66bd6454c8d7a170ad95
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f
Reviewed-Content-Hash: docs/architecture/architecture.md 1bc205b5b722ffc015d14444df535b375764cb42

## Revision — 2026-11-04 — after the review above (not a new verdict)
Applied in autonomous mode: all 4 blocking items (Paused screen does not arm and counts a press begun after it showed, Rule 2, Rule 17, States table, AC21; Won panel claim restated with the inset trade; criteria preamble limited to commands, registrations and log writes, with diagnostics sink and injected values; one clamped HudLogic clock named in Rule 11 and steps of at most 100 ms in the criteria) and recommended: bottom anchoring line, bonus cap of 9 as a content rule, 36% at rest, empty Won row omitted, NO_GOLD cost flash, ticks_per_second as to_ticks(1.0), chip window from ChipWindow, Hero Rules 13 and 15, arc panel hit shape added to Open Questions for /ux-design.
Not done: criteria splits and new criteria, margin formulas, inset clamps, dead-gesture flag wording, Lost panel, and the items routed to architecture.md B9/B10, ADR-0003 and /ux-design.
Re-review pending: the GDD hash above is of the reviewed text, not this revision.

## Review — 2026-11-05 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: ux-designer, ui-programmer, systems-designer, godot-specialist, qa-lead, creative-director
Blocking items: 5 | Recommended: 24
Summary: The four prior blockers are fixed. Five new local blockers remained: a fresh HUD never armed Start/Call, since Flow sends no signal for the opening phase; the layout's bottom-anchoring line, added by the last revision, contradicted its top-origin coordinates; Rule 1 gave HudLogic the chip and burst discs that Tower and Hero own, so AC28 could not run; arc and chip were not shown to exclude each other; and the ground ring had no lifetime. The creative director downgraded the margin domain, Reduce Motion, Won column offsets, the pattern library and the bonus divisor to recommended, and routed the engine conditions to ADR-0003 and ADR-0004.
Prior verdict resolved: Yes (all 4 prior blocking items)
Findings:
- [BLOCKING] Rule 11, States, AC1: HudLogic must read phase() when built and treat it as that phase beginning.
- [BLOCKING] Layout: "measured from the bottom edge" contradicts top-origin positions; clearances hold in reference space only.
- [BLOCKING] Rule 1, AC28: HudLogic registers only the backdrop, arc discs and Start/Call.
- [BLOCKING] Rule 8: state why an arc and a chip are never open together (Tower Rule 8 table; backdrop 250 over towers 200).
- [BLOCKING] Rule 14: ground ring hold and fade-out.
- [RECOMMENDED] Content rules: L1 and burst-line bounds as formulas of edge_reject_margin.
- [RECOMMENDED] Content rules: bonus bound cites Tower's early_call_bonus with its max(1, ...) guard.
- [RECOMMENDED] Formulas: display_seconds and chip_bar divisor guards; ticks_per_second 30 to 60.
- [RECOMMENDED] Layout: every Won y value minus B.
- [RECOMMENDED] UI Requirements: Reduce Motion for the arc's open and collapse; full table of moving elements to /ux-design.
- [RECOMMENDED] UI Requirements: "no chip behind modals" restated.
- [RECOMMENDED] Rule 13: prompt hidden in Paused.
- [RECOMMENDED] Rule 1: full listen list; idle clears Rule 10's flag.
- [RECOMMENDED] Rule 2: engine conditions named for ADR-0003 and ADR-0004 (_unhandled_input, mouse filter, pause mode, unscaled time).
- [RECOMMENDED] interaction-patterns.md P-11 (Won text 400 ms, Paused does not arm) and P-12 gap closed.
- [RECOMMENDED] Acceptance Criteria: AC12 observables, AC19(d) timer start, AC22 can fail, Deferred row for the chip's target.
- [RECOMMENDED] Acceptance Criteria: split AC4, AC8, AC19; view-model field names; first-match and count-vs-lives fixtures; one cooldown read per Cooling; AC32, AC37; uncovered rules (Rule 13 act-ends, Rule 1 build order, moved press, roll-off build, NO_GOLD flash, other best_drag); manual steps and thresholds.
- [RECOMMENDED] Layout: gold field overflows at 6 digits; burst digit box; "Call +9" width check.
- [RECOMMENDED] Safe area in physical pixels, converted and re-read on size_changed (ADR-0003).
- [RECOMMENDED] Rule 10: frame order is not the engine default when ticks run in _physics_process (ADR-0004).
- [RECOMMENDED] Rule 2: ScreenTouch canceled, named lifecycle notifications, emulated mouse hides a second pointer (ADR-0003).
- [RECOMMENDED] Tweens killed on close or free; HudLogic disconnects on exit; redraw keys and animation redraws (ADR-0011).
- [RECOMMENDED] Dead Start/Call tap feedback, third review running: /ux-design decides or closes it.
- [RECOMMENDED] Routed: haptics, top-row reach, Paused side-margin taps (/ux-design); insets above about 92 and notch clearance (Mobile Platform); no keyboard, gamepad or screen reader as a tier decision and AccessKit labels (accessibility-requirements.md).
- [RECOMMENDED] Disagreements: systems-designer's margin domain and the bonus guard, ux-designer's Reduce Motion, Won offsets and pattern library, godot-specialist's input order and Control settings, and qa-lead's chip target were all held as recommended or routed by the creative director; ui-programmer's chip-and-arc blocker was closed by stating existing Tower and Input rules, not by a new mechanism.
Reviewed-Content-Hash: design/gdd/battle-hud.md 4a8b31f64adc1ad85b770314b77dc0aa5435f39c
Reviewed-Content-Hash: design/ux/interaction-patterns.md f6520a827ff93e133ec3d331aee664dd578a1f01
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 318de9b091a58161cab40b290a44203ff8486f99
Reviewed-Content-Hash: design/gdd/tower-system.md 2c025196c3039eee362885ab82138a8999c3dd01
Reviewed-Content-Hash: design/gdd/hero-system.md 22b23c09a786eb7b142e7e998c12cf1b7ff090ce
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 23d2a60fac1632b52fa5c9a35394466973c672ba
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md b58a9270cca3749146c6a2291b7324583865c6c6
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c

## Revision — 2026-11-05 — after the review above (not a new verdict)
Applied in autonomous mode: all 5 blocking items (Rule 11 reads phase() when built and arms Start/Call, States and AC1, new clause in AC31 for a HUD built in Wave; layout line replaced with reference-space wording and ADR-0003's choice; Rule 1 lists only HudLogic's own discs, AC28 split to owners; Rule 8 sentence and two edge cases for arc and chip; Rule 14 lifetime of 650 ms, visual row and AC18) and recommended: margin formulas, bonus bound citing Tower, display_seconds and chip_bar guards, Won y values minus B, Reduce Motion for the arc, modal budget wording, prompt hidden in Paused, listen list, engine conditions, AC12, AC19(d), AC22, Deferred chip row, pattern library P-08, P-11 and P-12.
A ui-programmer spot-check of the revision found that it had wrongly made HudLogic arm the burst button (HeroInput owns it), that AC12's steps summed to 201, an untestable AC7 clause, and a rounded margin given three ways. All four were fixed before commit.
Not done: criteria splits, new fixtures and criteria, digit and text width checks, and every routed item.
Re-review pending: the GDD hash above is of the reviewed text, not this revision.
