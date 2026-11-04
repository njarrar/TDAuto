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
