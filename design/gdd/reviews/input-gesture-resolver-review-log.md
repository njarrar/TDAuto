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
