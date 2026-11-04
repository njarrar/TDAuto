# Review Log — Input & Gesture Resolver

## Review — 2026-11-01 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L (producer should verify before sprint planning)
Specialists: game-designer, systems-designer, qa-lead, ux-designer, godot-specialist, creative-director (senior)
Blocking items: 9 | Recommended: 9
Summary: The architecture holds (pure resolver, frozen winner per class, no fall-through — zero mis-fires is provable, not hoped for). Defects are in the contract wording — re-entrant emission order, when `idle()` fires, palm replacement only in Pressed, lost release / per-touch cancel soft-lock — and in the acceptance criteria (asserts untestable, logs incomplete, AC21 not computable). Burst tap-to-fire mis-fire risk is a Hero/concept decision for the user (drag-only for MVP recommended); the resolver's only part is Rule 3's "must not be tightened" wording.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design Rule 2 / L107 / Edge Cases L203: re-entrancy self-contradictory; nested emit delivers idle() before pressed(); queue signals during emission
- [BLOCKING] Rule 7 / L107 / AC10 / AC13: when idle() fires is contradictory; emit on every non-Idle→Idle, never Idle→Idle
- [BLOCKING] Rule 1 / row 87: palm that drifts past slop becomes Dead and blocks the thumb; replacement must cover Dead with no winners
- [BLOCKING] Rules 1, 7: lost release with a different pointer index soft-locks; iOS cancels per touch; add cancel_pointer(i) and a one-release-or-cancel-per-press contract
- [BLOCKING] Rules 3–4: tap presses share drag_slop so a thumb roll silently dies; add tap_slop when no drag winner + release-inside-disc
- [BLOCKING] Edge Cases L234: dismiss-and-act on an open arc is a mis-fire by the GDD's definition; press outside arc discs only dismisses
- [BLOCKING] Acceptance Criteria 2, 3, 8, 12, 15, 16: asserts untestable (validate_slop / register returns -1), NONE = -1, full logs; add ACs for id reuse, mid-gesture (un)register, re-entrancy, lost-move release with drag winner
- [BLOCKING] AC21: not computable — tester/device count, pooled vs per-tester, wrong-target = mis-fire, burst Ready, prompt protocol, upgrades via Tower log, evidence path
- [BLOCKING] Rule 3: "must not be tightened later" blocks Hero's burst fix; reword to resolver-only
- [RECOMMENDED] Detailed Design: Dead-with-no-drag-winner signal for missed-grab feedback
- [RECOMMENDED] Dependencies (Hero): grab radius ~56, pin via offset function, cancel hysteresis, leash only on hero disc, hold clock
- [RECOMMENDED] Dependencies (Tower): 200 ms bounce guard hard or chip as own target
- [RECOMMENDED] Cross-References (art bible §7): slots never overlap the burst button, hard rule now
- [RECOMMENDED] Formulas: reject NaN/INF; integer target_ok form; field units = viewport space without Camera2D
- [RECOMMENDED] L73 ADR list: stretch mode/letterbox, safe-area pixels, PROCESS_MODE_ALWAYS, mouse-emulation prototype, adapter owns lifecycle, mouse index
- [RECOMMENDED] Edge Cases L214: export cannot exclude <360 dp; runtime guard + store filter
- [RECOMMENDED] Visual/Audio L264: "50 ms" → next frame after pressed
- [RECOMMENDED] AC21 scope: ≥5 testers incl. left-handed, two widths, iOS+Android, unprompted segment; log press offset/contact size/hold (concept change, user's call)
- [DISAGREEMENT] burst tap-to-fire blocking (game-designer, ux) vs Hero/concept dependency note (creative-director); drag_slop floor 8 vs 12 (systems-designer vs creative-director) — unresolved
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 80a280f4b52886994456cc575aabd586cf20cf02
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 1544d9c5900d6acb5b019360b66736994636073e
Reviewed-Content-Hash: design/gdd/game-concept.md ce77741121e0ddeb4666278960435360cc2229d0
Reviewed-Content-Hash: design/gdd/systems-index.md 4bd12932e6eecaa23d61e48923475af9844dc3d8
Reviewed-Content-Hash: design/art/art-bible.md ff8234976852a8fc2333127c515cf19ab439e048

### Revision — 2026-11-01 (same session, after the review above)
Applied all 9 blocking items; user decision: burst is drag-only for MVP (concept Core Mechanic 2 and Pillar 4 test updated; Data & Config Input record gains `tap_slop` 16–34 under the extension rule). Not applied (left as Recommended / Hero notes): Dead-with-no-drag-winner feedback signal, hero DRAG radius, pin via offset function, snap-to-nearest, intent API, Player Fantasy and Tuning Knobs sections. Systems index set to In Review; a re-review decides Approved.

## Review — 2026-11-01 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L (producer should verify before sprint planning)
Specialists: game-designer, systems-designer, qa-lead, ux-designer, godot-specialist, creative-director (senior)
Blocking items: 8 | Recommended: 9
Summary: The core model (two winners frozen at press, class isolation, sticky classification, host-driven cancel) is stable and untouched by all five specialists; the re-review is converging. The new blockers are precision defects introduced by the same-day rewrite: the queued-emission wording contradicts AC27 and defers `register` (which must return an id); the `hit` formula's `enabled` term contradicts AC26; `tap_slop` introduced an asymmetry where a roll on a tower with the hero parked on it becomes a hero re-pin (a mis-fire by Rule 13); the adapter contract omits the `canceled` flag; "reaches nothing beneath" the burst button is false; AC19 has an arithmetic error; AC34's miss/mis-fire definitions contradict Formulas L163 and Rule 13. One targeted pass with four user decisions (slop when both winners exist; resting-palm lock policy; per-gesture vs pooled; TAP sink vs layout constraint) should reach APPROVED.
Prior verdict resolved: Yes — all 9 prior blockers were fixed; the fixes introduced the blockers above
Findings:
- [BLOCKING] States L111 / Edge L211, L213: queued emission defers `register` (must return an id) and drains before `idle()` on a literal read, contradicting AC27; registry calls never deferred, queue drains after the whole batch inside the outermost call
- [BLOCKING] Formulas L135, L152 vs AC26, Edge L212/L216: `hit` includes `enabled` so a tap winner disabled mid-press cannot tap; split geometry from the enabled filter, snapshot centre+radius at press
- [BLOCKING] Rule 3 L58: hero parked on a tower makes a 16-unit tower-tap roll a hero re-pin (Rule 13 mis-fire); user choice: tap_slop when a tap winner exists (recommended) / inner grab radius / accept and phone-test; add an AC
- [BLOCKING] Dependencies L268 adapter contract: must check `canceled` before treating pressed=false as a release; deferred table needs pass conditions, not only owners
- [BLOCKING] Interactions L121 / Edge L236: "reaches nothing beneath" the burst button is false (classes independent); register a TAP sink on the button Hero ignores, or correct the claim and make the slot-layout constraint a hard dependency
- [BLOCKING] AC19: `validate(15, 15.5)` is false (15.5 below the 16 floor)
- [BLOCKING] Rule 9 L64, L226: constructor cannot refuse in GDScript (factory returning null); radius must be finite and > 0; `set_centre` with NaN needs an outcome
- [BLOCKING] Rule 13 / AC34: ground_tap on a prompted slot is a miss not a mis-fire; a voluntary burst in the unprompted segment is not a mis-fire; space tower-tap prompts beyond Tower's 1.5 s window; retries must not inflate the denominator; decide per-gesture vs pooled now; AC34 gates the Pillar 4 milestone, not this system's Done
- [RECOMMENDED] Rule 1 L56: resting palm on a winning target (cooling burst button) holds the pointer; record a policy (extend replacement to an unmoved press with no tap winner, or document the lock and add it to the phone-test script)
- [RECOMMENDED] AC fixtures: H placement missing in AC4,5,7,8,11,14,16,17,21,26; press positions; AC17 pointer index; AC15 exact positions; fixture B (470,880) breaks Rule 12's own 84-unit margin
- [RECOMMENDED] Interactions L123 / Edge L247: HUD closes the arc on `pressed` only when best_tap is not an arc disc, else the arc closes before `tap(A)`
- [RECOMMENDED] Rule 1 L56 "replaced silently" vs AC2/3 and row L88 which emit `idle()`
- [RECOMMENDED] Rules 3/5 release-inside-disc: keep as the slide-off-to-abort affordance (not a mis-fire guard), tested against snapshotted geometry
- [RECOMMENDED] Missing ACs: press(active) in Pressed/Dead; cancel_pointer(active) in Pressed/Dead and in Idle; second press while Pressed with drag-only winner; Dead stickiness; disabled drag winner mid-drag; register/unregister inside a handler; press from an idle handler; tower-over-hero lift and roll; non-finite release/set_centre/register centre; AC1 rewrite; AC23 replace tautology with first-id-is-1; AC32 registration order
- [RECOMMENDED] Formulas L180 target_ok: specify floor/cast for float inputs
- [RECOMMENDED] For Hero/HUD GDDs: drag-only burst MVP affordance and pressed-not-dragged response; cancel-band hysteresis and unaimable disc above the button; arc lifetime; spend-tap max hold; hero grab radius ≈56; near-miss cue; retained screenshots for leash, reticle, cancel state, ring, chip, arc
- [RECOMMENDED] For the Input ADR: emulation settings vs HUD Controls (touch-only + emulate_touch_from_mouse suggested); get_display_safe_area covers cutouts not gesture zones; stretch mode decided before the ADR; gdUnit4 push_error setting pinned or an error-sink injected
- [DISAGREEMENT] Hero-over-tower roll blocking (game-designer, creative-director) vs recommended (qa-lead); resting-palm lock blocking (game-designer) vs recommended (systems-designer, creative-director); AC34 gating (qa-lead: milestone gate; ux: ≥5 testers or label smoke-only; concept: MVP+ exit); release-inside-disc drop (game-designer) vs keep as abort affordance (creative-director)
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 6ef35bbf66306ffc1c056fec8065f60020ae901d
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md a01044c2f537a73009c286da50160e13f5e94abf
Reviewed-Content-Hash: design/gdd/game-concept.md 5ce0c272e580a8869effd0883f9f43c6849a5fa7
Reviewed-Content-Hash: design/gdd/systems-index.md f191e7ccfde2381f233fd2b4f4dc4a791ff13407
Reviewed-Content-Hash: design/art/art-bible.md ff8234976852a8fc2333127c515cf19ab439e048

## Review — 2026-11-01 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L (producer should verify before sprint planning)
Specialists: none (lean). Not independent: the second-round fixes were written in the same session as this review, and no specialist has seen the sink, tap_slop or queued-emission text.
Blocking items: 1 | Recommended: 6
Summary: Core model unchanged and unchallenged; the second-round fixes hold together. All 36 criteria were traced by hand against the rules and state table and agree. One inconsistency remains in the palm-replacement rule the user decided on: a Dead press that has only a sink winner (any press while a build arc is open) is not replaceable, though an unmoved one is. Fixed in this pass, one sentence plus one criterion, awaiting re-review.
Prior verdict resolved: Yes — all 8 blockers of the second review
Findings:
- [BLOCKING] Core Rules (Rule 1) / States / Edge Cases: Dead replacement said "no winner at all"; with a sink winner (arc open) a drifting palm holds the pointer and locks the thumb out, contradicting the user's replacement decision — applied: Dead is replaceable when it has no real tap winner; criterion 37 added
- [RECOMMENDED] Rule 1: "second press wins" cuts both ways: a second touch can replace an unmoved hero or burst press and then tap a tower — recorded as an Open Question for the phone test
- [RECOMMENDED] Dependencies (Hero note): a hero DRAG radius of about 56 conflicts with art bible §3 (hero hit 72 px, radius 36); Hero GDD and art bible must be reconciled together
- [RECOMMENDED] Rule 3: a sink-only press kills at drag_slop (15) but a ground press at tap_slop (28), so leniency differs while an arc is open; harmless, noted
- [RECOMMENDED] Data & Config GDD says "world units" where this document says "field units"; label only
- [RECOMMENDED] Cross-document: Game State, Hero, Tower, Battle HUD GDDs do not exist, so every interface stays provisional
- [RECOMMENDED] Process: re-review in a fresh session with specialists, or accept; engine claims remain unverified for 4.7 (ADR items)
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md b00cf9abe930002c00eb0ec84d4875a874773725
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md a01044c2f537a73009c286da50160e13f5e94abf
Reviewed-Content-Hash: design/gdd/game-concept.md fb783d19a70f043637feb7dddc161acdef4ecdd1
Reviewed-Content-Hash: design/art/art-bible.md ff8234976852a8fc2333127c515cf19ab439e048
Reviewed-Content-Hash: design/gdd/systems-index.md bdde32bd2e24d37db0ad44a7fa73149025d063d1

## Revision — 2026-11-03 — Two cross-GDD blockers applied, re-review still pending
From design/gdd/gdd-cross-review-2026-11-03.md. B1: the deferred row and edge case now say headless bots call commands directly, matching Rule 11. B3: Rule 13's harness logs `tower_upgraded` and `chip_state()`, and P1 no longer cites a Tower chip log.

## Revision — 2026-11-03 — cross-GDD warning pass
From design/gdd/gdd-cross-review-2026-11-03.md, Consistency Re-run. Overview's bot claim, N4's `burst_started` in Rule 13, C3, C4, C6, C7, C11, C12 and stale rows. QQ-19 and QQ-20 added to Open Questions. Header set to In Review to match the index.

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, ux-designer, creative-director
Blocking items: 5 | Recommended: 13
Summary: The core model held under five specialists: two winners frozen at press, class isolation, sticky classification and host-driven cancel. The systems designer verified every formula, example and restated value. What remained was internal contradiction (Controls before the adapter stated as fact against the ADR note; P1's mis-fire definition against Edge Cases; P1's testers against the accessibility requirements), an under-tested Dead replacement criterion, and the release-inside-disc test, which the creative director now judged a source of silent misses rather than safety.
Prior verdict resolved: Yes (the third review's one blocker; cross-GDD fixes of 2026-11-03)
Findings:
- [BLOCKING] Acceptance Criteria 37: moving 20 does not prove the press is Dead; move 30.
- [BLOCKING] P1 and Rule 13: mis-fire definition counts sink taps and cancels; log lacks prompt id and time and the Start/Call, arc build and pin-landed events.
- [BLOCKING] P1: "one left-handed if available" conflicts with design/accessibility-requirements.md (one left-handed, one one-handed); state the honest bound (about 7% at n=40).
- [BLOCKING] UI Requirements, Interactions, Dependencies: Controls consuming events before the adapter stated as fact; ADR-0003 decides, and Flow's cancel_input() covers the overlap.
- [BLOCKING] Rules 3, 5, Edge Cases: release-inside-disc test adds silent misses; drop it, moving past slop is the only abort. Design decision taken in autonomous mode on the creative director's recommendation; the user may revert.
- [RECOMMENDED] Criterion 19: isolate tap_slop > drag_slop; a positive create path.
- [RECOMMENDED] Rule 3: a sink-only release-at-slop criterion.
- [RECOMMENDED] Fixtures: hero radius 36 against the real 56; boundary test.
- [RECOMMENDED] Criteria for Rule 12 edge rejection, retry with a finger held (Flow Rule 16), Pressed active re-press, cancel_pointer cases; split multi-WHEN criteria.
- [RECOMMENDED] is_drag wording for a sink-only press.
- [RECOMMENDED] target_ok boundary at 359.99 dp.
- [RECOMMENDED] Rule 12: strict reject boundary.
- [RECOMMENDED] Interactions HUD row: the 200 ms guard; chip radius 40 credited to Tower.
- [RECOMMENDED] P1: scripted palm and grip prompts; log maximum travel.
- [RECOMMENDED] drag_slop 15 near the platform's 8 dp: hold until the phone test.
- [RECOMMENDED] Routed to ADR-0003: event path and STOP-Control order, stranded-gesture watchdog, mouse pointer index, emulation, canceled flag, coordinate space and safe area, field_scale under stretch, accumulation, push_error in gdUnit4, typed payloads, live edge-margin values.
- [RECOMMENDED] Routed elsewhere: Battle HUD (margin domain 37 to 48 vs the burst line, thumb occlusion), Data & Config ("world units", third flag), Hero (tap(sink) nudge, leash lag, sticky-drag escape), Flow (cancel on intermission for a stuck thumb), Settings (tablet slop clamp), producer (P1 sample size), phone test (palm-lock rate, slop dead zone, arc dismiss cost).
- [RECOMMENDED] Not reopened: palm replacement (game-designer's blocker downgraded), hero over burst, Start/Call overlap, drag-only burst, tap_slop rule.
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4c34ae187a1d77212e8c66bd6454c8d7a170ad95
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 5e5df4a50191c71f81644957fb43ef96b38ab6d5
Reviewed-Content-Hash: design/gdd/hero-system.md 377e450bbee022ae776076cebdd1ed1c092a02fc
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: design/gdd/battle-hud.md 4a8b31f64adc1ad85b770314b77dc0aa5435f39c
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d79fe3bf982a1d15a806cc0725421521a6a735d5
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f
Reviewed-Content-Hash: design/accessibility-requirements.md e525e1253b9112f6a74c671bb6d0e1f02f96bb0f
Reviewed-Content-Hash: docs/architecture/architecture.md 1bc205b5b722ffc015d14444df535b375764cb42

## Revision — 2026-11-04 — after the review above (not a new verdict)
Applied in autonomous mode: all 5 blocking items (criterion 37 moved 30; Rule 13 logs prompt id and time and listens to hero_pinned, tower_built and Flow's phase; P1 action signals, miss and mis-fire definitions; P1 testers aligned with the accessibility requirements and the 7% bound stated; Controls order deferred to ADR-0003 in UI Requirements, Interactions and Dependencies; release-inside-disc test dropped from Rules 3 and 5, the formulas, the transitions table, Edge Cases and criteria 13 and 26) and recommended items: criterion 19 additions, new criterion 38 for sink-only slop, is_drag wording, target_ok rounding, strict edge boundary, 200 ms guard in the Interactions HUD row, chip radius credited to Tower.
Follow-on edits outside this GDD: Battle HUD Rule 8 and criterion 7, and design/ux/interaction-patterns.md, which said a finger rolling off a disc leaves the arc open; under the new rule it taps.
Not done: the remaining criteria additions and splits, and every routed item.
Re-review pending: the GDD hash above is of the reviewed text, not this revision.
