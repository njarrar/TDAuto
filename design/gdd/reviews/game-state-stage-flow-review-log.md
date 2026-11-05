# Review Log: Game State & Stage Flow

## Review: 2026-11-05: Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L (multi-system composition root, 2 formulas, 9 dependencies; no new ADR needed, since ADR-0001, 0003, 0004, 0006 and 0010 already cover it)
Specialists: none spawned. This session had no Agent tool, so the main reviewer did the game-designer, systems-designer, qa-lead, godot-specialist, ux-designer and creative-director passes from each role's view. None of these agents reviewed or passed this document.
Blocking items: 8 (all wording, all fixed in this pass) | Recommended: 9
Summary: The design is sound and matches the Accepted ADRs on every rule that matters: tick order, commit then emit, retry teardown, pause, fatal path, result snapshot and command result codes. The blockers were stale text written before the ADRs were accepted, plus three criteria that broke the section's own "each THEN is the entire log" rule or left the phase unstated against AC 11. All are fixed; what is left is advisory or waits on first playable.
Prior verdict resolved: First review
Findings:
- [BLOCKING, fixed] Open Questions: rows 2, 4 and 5 said the App Lifecycle ADR, the test hooks and the plain builder were still open. ADR-0001, 0003, 0004, 0006 and 0007 settle all three; the rows now say Resolved and cite them.
- [BLOCKING, fixed] Dependencies: "none but Input has a GDD" was stale; all seven MVP GDDs exist and list this one.
- [BLOCKING, fixed] Rule 15: "the battle exposes `in_build()` and `halted()`" read as a Callable on Battle, which ADR-0001 Decisions 2 and 3 forbid; now the Builder injects Flow's `in_build()` and the `HaltGate`'s `halted()`, false while Paused.
- [BLOCKING, fixed] Rule 15a: "development builds log an error" contradicted ADR-0001 Decision 7 (the sink logs in every build); now names the dev-error sink.
- [BLOCKING, fixed] Rule 4 and Formulas `dt`: "60 per second proposed" and "1/60 proposed"; ADR-0004 fixes `TICK_RATE` 60.
- [BLOCKING, fixed] Acceptance Criteria 6 and 7: no phase in the GIVEN, while AC 11 says a leak in Build is ignored, so a test author could write a contradicting test; now "Wave" and "the last wave".
- [BLOCKING, fixed] Acceptance Criteria 12 and 13: the THEN did not state the whole log, against the section header; now `phase_changed(Paused), phase_changed(<that phase>)` and `phase_changed(Fatal)` alone, as ADR-0003 2.5, ADR-0006 Decision 4 and ADR-0001 Decision 6 give.
- [BLOCKING, fixed] Deferred criteria: the clamp and tick order row was owned by "App Lifecycle ADR", which is ADR-0001; tick rules are ADR-0004's, so the owner is Game State stories under ADR-0004's Validation Criteria.
- [RECOMMENDED] Edge Cases: no line for `Flow.pause()` arriving inside a tick; ADR-0004 Decision 5 and ADR-0006 Decision 7 say it reports a dev error, applies, and the tick finishes whole.
- [RECOMMENDED] Acceptance Criteria: none asserts the `StartResult` and `CallResult` codes (`BUSY`, `HALTED`, `NOT_BUILD`, `NOT_INTERMISSION`, `NO_TIME_LEFT`) of TR-state-015; ACs 1, 4 and 15 check only the log.
- [RECOMMENDED] Acceptance Criteria 11: should also assert one dev-error report in each case (Rule 15a), with ADR-0007's recording sink.
- [RECOMMENDED] Acceptance Criteria header: say that "tick" means `Battle.tick` with fakes, since the Paused and Build gate lives there (ADR-0004 Decision 5), not in `Flow.tick`; AC 1 and 12 depend on it.
- [RECOMMENDED] Deferred criteria: "Retry" is owned by Enemy & Wave stories and the always-call gate wording differs from the Hero GDD's thresholds (gains at most 2 lives, flips no loss), which own it; point the row at Hero's deferred table (cross-review C14, C15).
- [RECOMMENDED] Design (game-designer view): the Hero GDD's bots find calling early close to free (no lives lost, stage under 4 minutes against the concept's 5 to 8). The MVP rule is decided (no overlap, bot gate, overlap as the fallback); whether humans pay a cost is a first-playable question for the user, not a wording fix.
- [RECOMMENDED] Player Fantasy (advisory at `standard`): absent; Game Feel carries most of it.
- [RECOMMENDED] Tuning Knobs (advisory at `standard`): absent; Flow's knobs live elsewhere (`starting_lives`, `intermission_duration`, `MAX_TICKS_PER_FRAME`, HUD delays); a short pointer table would help.
- [RECOMMENDED] Other document, not edited: the systems index Core Layer TD note still says "technical-director to confirm" the plain builder; ADR-0001 confirms it.
Wording fixes also made in this pass (not blockers): Rule 2 says ADR-0001 adopts the plain builder; the Wiring paragraph cites ADR-0006 Decision 8; the Enemy & Wave interactions row names `start_next_wave()` (ADR-0010 Decision 3); the Dependencies footer lists which GDDs already link back; UI Requirements says "N of M" with M the `wave_ids` size, 6 on the starter stage (Battle HUD Rule 15); the Cross-References row says ADR-0001 adopts the amendment; header Last Verified set to 2026-11-05.
Why not APPROVED: the review found blockers, and this skill holds that a revision verdict is not an approval. The fixes are wording only and change no value or intent, but no one has checked them but their author, and no specialist agent ran. A short re-check of these edits, or the user's acceptance, decides Approved.
Status set: GDD header and systems index to In Review. The hash below is of the GDD after these fixes, so a re-review without further edits reads UNCHANGED.
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 8061a4bdcda61243e597c23dc1214d8448ba9119
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md eb4deee4f73f034bc672f49d569d8d5601822d8e
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md add0f1c5a5b8b8bd7f52b3683fd9985b84c911b2
Reviewed-Content-Hash: design/gdd/enemy-wave.md adfe9932b1756518dd4219a26cdb9c048950950d
Reviewed-Content-Hash: design/gdd/tower-system.md feecd55d693e8bc9c802b4115d51ee494ea5bfba
Reviewed-Content-Hash: design/gdd/hero-system.md 88c68ce97af3b80dd0dff559a3ab3d65a2cfa1f2
Reviewed-Content-Hash: design/gdd/combat-damage.md e4df04fab059c0779ec3460522a8b4f0f6605fc1
Reviewed-Content-Hash: design/gdd/battle-hud.md 9cae820470e28dccf98015d4a423e8c9d9626a5a
Reviewed-Content-Hash: design/gdd/game-concept.md 5fc68e4c2eda531b8ef80a5663b2f33961b139cf
