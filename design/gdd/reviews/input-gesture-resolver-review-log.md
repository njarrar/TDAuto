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

## Revision — 2026-11-04 — ADR sync
Wording and tables only; no balance value changed; re-review still pending.
- Rule 7 lists all three `cancel()` callers: the adapter (pause, focus loss, resize, Android back), Flow through `cancel_input()`, and the app root at teardown (ADR-0001 Decision 7, QQ-20; ADR-0003 2.3 and 2.5). Closes cross-review C2 on this side.
- Rule 9 and the Input record domains: the CI content test checks `tap_slop` > `drag_slop`, and the Builder sends a null resolver to the fatal screen (ADR-0002 Decision 7, QQ-19). Closes C1 on this side.
- Rule 12: gesture insets have no engine source at MVP; `edge_reject_margin` stands in; insets are read once per battle (ADR-0003 Decision 3, item G2).
- Positions and units, `field_scale`, `target_ok`, the Output Ranges, the size table note, the small-screen edge case and AC 33: scale is `min(width_dp / 540, height_dp / 960)`, the minimum screen is 360 × 640 dp, and `target_ok` gains a height term (ADR-0003 Decision 1, item G1).
- Open Questions: the adapter row is answered by ADR-0003 pending S0; the tablet scale-cap row is closed for MVP. The resize edge case and both "becomes an ADR" notes point to ADR-0003.
- Rule 13, the Tower Dependencies row and Cross-References: the gesture log is the test harness story's, and it reads Tower's `tower_upgraded` and `chip_state()` (cross-review N3).
- Edge Cases: "(a bot)" reads "(a resolver fixture)" (N1). The Overview's last bot phrase, which still said bots drive the resolver, now names the equivalence test (same stale B1 text, missed by N1).

## Revision — 2026-11-04 — ADR-0004 to ADR-0008 sync
No balance value changed; Status unchanged. Signal renames in every code form, test logs included: `tap` to `tapped`, `ground_tap` to `ground_tapped`, `idle` to `became_idle` (ADR-0006 Decision 5). Rules 2, 5, 6 and 7 use the payload names `press_pos`, `release_pos`, `pos` and `target`, and a new Signal payloads paragraph lists them (ADR-0008 Decision 5). Rule 9 adds the rejects for a bad `accepts` and a DRAG sink (ADR-0008 Decision 2). Rule 11 says the Builder builds the resolver (ADR-0001). Rule 13 names `GestureLog`, `last_trace()` and `GestureTrace` (ADR-0008 Decisions 7 and 8). States and Transitions: the replacement order is the whole cancel first, then the new press, and the queue cap of 64 is noted, with `cancel()` exempt (ADR-0008 Decisions 3 and 4). The AC preamble puts the recording fake in `tests/helpers/fakes/` and the factories in `tests/helpers/fixtures/` (ADR-0007 Decision 2).

## Review — 2026-11-05 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L (producer should verify before sprint planning)
Specialists: none spawned. This session had no Agent tool, so the game-designer, systems-designer, qa-lead, ux-designer, godot-specialist and creative-director views were taken by the main reviewer in one session. No specialist or director passed this review. The wording fixes below were made in the same session, so this review is not independent of them.
Blocking items: 8 (all wording, all applied in this pass) | Recommended: 7 applied, 6 open
Summary: The core model is unchanged and still holds: frozen winners per class, sticky per-press slop, the replacement rule, the queue and the host-only cancel all match ADR-0008, and all 37 criteria trace by hand against the rules and the state table. The blockers were stale text that contradicted the Accepted ADRs or the owner GDDs written since the last review: what modal Controls take from the adapter, who may call `cancel()`, how Tower's bounce guard counts, what the Input record holds, who builds the resolver and adapter, the hit-radius range, and "unmoved" in Rule 1. Each was fixed as wording with no balance value or design intent changed, so a short re-check of these edits, or the user's acceptance, can decide Approved. The open items are user calls (P1 and Hero Rule 15's re-pin trade) or other documents' fixes.
Prior verdict resolved: Yes. The third review's one blocker (Dead sink-only press) holds (criterion 37 traces); its recommended items are closed or carried below
Findings:
- [BLOCKING] UI Requirements: modal screens "consume every event before the adapter" contradicted ADR-0003 2.1, 2.4 and 4 (they take presses; a forwarded drag's endings still reach the adapter): applied
- [BLOCKING] Interactions (HUD row): "top-band Controls consume their own events" contradicted UI Requirements and ADR-0003 Decision 4 (non-interactive Controls ignore input): applied
- [BLOCKING] Edge Cases (State machine): "an owner calls `cancel()` or `press` inside a handler" contradicted ADR-0006 Decision 3 and ADR-0008 Decision 6 and Guideline 12; now Flow's `cancel_input()` or a resolver fixture: applied
- [BLOCKING] Rule 8, Interactions and Dependencies (Tower rows): the bounce guard counted "after the chip opens" and the chip disc was an "or"; Tower Rule 8 and ADR-0008 Decision 9 count from the commit's press and register the chip disc (TAP 300, radius 40) as well: applied
- [BLOCKING] Rule 9: the three slop and margin fields were "the fields" of the Input record; ADR-0002 Decision 4 gives it five, with `left_handed` and `reduce_motion`: applied
- [BLOCKING] Interactions and Dependencies (Game State rows): Game State "constructs the resolver and the adapter"; ADR-0001 Decisions 2 and 4 have the Builder create the resolver and the BattleWrapper build the adapter and the three owners: applied
- [BLOCKING] Formulas (inside, target_ok): `r` range 36–48 contradicted the hero's DRAG 56 (own registration table, Hero Rule 15, art bible §3) and the chip's 40 (Tower Rule 8); now 36–56: applied
- [BLOCKING] Core Rules (Rule 1) and Edge Cases: "an unmoved press" is replaceable, but the state table and ADR-0008 Decision 3 make any Pressed gesture (travel under slop) replaceable; now "a press still under its slop": applied
- [RECOMMENDED] Signal payloads: added ADR-0008 Decision 6 (no command from `drag_cancelled` or `became_idle`) and ADR-0006 Decision 3 (no owner calls a gesture method or `cancel()`): applied
- [RECOMMENDED] Dependencies: "none has a GDD yet" was stale; Game State, Hero, Tower and Battle HUD GDDs exist and list this one: applied
- [RECOMMENDED] Overview and Core Rules: the "becomes an ADR" text still posed questions ADR-0003 and ADR-0008 decided ("the adapter must synthesise", "project.godot has none yet"); now states the decisions, and the [Sn] items stay unverified until S0: applied
- [RECOMMENDED] Cross-References: added ADR-0006, ADR-0007, ADR-0008 and ADR-0010 rows; ADR-0001 now cites Decisions 2, 4, 5 and 7; ADR-0003 Decisions 1 to 4; radii 36 / 48 / 56: applied
- [RECOMMENDED] Interactions (HUD row): added Start/Call TAP 350, disabled while an arc is open, and its ignored tap when the press also named the hero (ADR-0008 Decision 9, HUD Rule 10); ground ring "first few per session" is "first three per battle" (HUD Rule 14): applied
- [RECOMMENDED] Overview: "a non-developer tester" now names P1's at least two: applied
- [RECOMMENDED] Acceptance Criteria (deferred table): added the resolver contract that ADR-0008 Validation Criteria V2 to V12 test beyond criteria 1 to 37: applied
- [RECOMMENDED] Rule 13 / P1 (user decision): Hero Rule 15 accepts that a hero within 92 of a slot or tower turns a thumb roll of `tap_slop` or more into a re-pin; P1 counts that as a mis-fire during a slot or tower prompt, and Rule 3's claim covers only rolls under `tap_slop`. Decide whether P1 counts it, or keep it and watch the phone test: open
- [RECOMMENDED] Acceptance Criteria fixtures: `H` has radius 36, production 56; logic is radius-free, but no criterion covers the 56-radius overlaps (hero over Start/Call, the 92 distance to a slot): open
- [RECOMMENDED] Formulas (field_scale): the 0.667–1.481 range assumes width at most 800 dp; ADR-0003 has no scale cap, so a 900 × 1,600 dp screen gives 1.667. Say the top is open or name 800 dp as an assumption: open
- [RECOMMENDED] Overview/priority table (sink): accessibility AR-M-06 (In Design) asks that "reaches nothing beneath" name the Alpha two-tap mode as its exception; wait for that document's review: open
- [RECOMMENDED] Other documents: Data & Config says "world units" for the Input fields; interaction-patterns cites "Input Rule 6" for sticky drag (Rule 3); the systems index lists Battle HUD In Review while its GDD says Designed; the concept's Pillar 4 still says "a non-developer tester"; open, not this GDD's
- [RECOMMENDED] Player Fantasy and Tuning Knobs are absent; advisory at `standard` (the Formulas tables and Input record domains carry the knobs): open
Note: the receipt below stamps the GDD as reviewed (before this pass's edits, git blob c39179fe), so the next run sees it CHANGED and re-checks the edits.
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md c39179fe9c482ec442c264a3294c20fec4e74065
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md fb484d24990461f0800de4d022afa95997ee512d
Reviewed-Content-Hash: design/gdd/game-concept.md 93a774e02d9d14747e67ead5ce82140d1718b81f
Reviewed-Content-Hash: design/gdd/systems-index.md c5f5a462ae11c1d10135730b927519a14b7dde47
Reviewed-Content-Hash: design/art/art-bible.md 02d54d6b93ccc9656dcfdfdc5e0d888cde99f7d0
Reviewed-Content-Hash: design/gdd/hero-system.md 88c68ce97af3b80dd0dff559a3ab3d65a2cfa1f2
Reviewed-Content-Hash: design/gdd/tower-system.md 0d7fc21d197c7b1ae4c7bc6f6749df6d58d7b886
Reviewed-Content-Hash: design/gdd/battle-hud.md 39c88b57183b7d8d33c33a5faa5b802499925045
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d0971ae2056275d68099e04af472c70bac83009d
Reviewed-Content-Hash: design/accessibility-requirements.md b0574e2ac2870c485edb5d038e477577e9d46700
Reviewed-Content-Hash: design/ux/interaction-patterns.md 553b98a50424056d8eab720bb9269c9ea15efc8e
Reviewed-Content-Hash: docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md a6ca1e2b2ea8e2e7de6fbce9b379c24590747650
Reviewed-Content-Hash: docs/architecture/adr-0002-catalogue-storage-format-manifest-validation.md 65a5fbdd0606124b20b1370a4065a5453c3378c3
Reviewed-Content-Hash: docs/architecture/adr-0003-input-adapter-display-stretch-platform-lifecycle.md ab8aab909e64196cd2e7559d142c70aca531d9ad
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-signal-contracts-view-allowlist.md ef2faea37127d471a4d99607607e3c3d16804956
Reviewed-Content-Hash: docs/architecture/adr-0007-headless-test-harness-gdunit4-layer-lint.md 0e5d0aa385e84dad6e121fdb502f84d69adaf5c2
Reviewed-Content-Hash: docs/architecture/adr-0008-input-resolver-core-signal-contract.md 784dd51eecd37f86856684ec15e0672ed0f09866
Reviewed-Content-Hash: docs/architecture/adr-0010-sim-input-split-command-results-dev-telemetry.md ea7126f7d91f398ee3b8691058e4a0a01a37b340
