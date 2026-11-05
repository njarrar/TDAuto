## Review — 2026-11-01 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M (producer should verify before sprint planning)
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, level-designer, economy-designer, creative-director (senior)
Blocking items: 9 | Recommended: deferred with owners
Summary: Architecture sound (manifest, all-or-nothing load, one accessor, injection); gaps were unlisted vocabularies, an ill-defined accessor and weak criteria. Guiding rule: contracts get fixed now, fields go to their owning GDD. All 9 blocking items applied the same day; re-review pending. Run in the authoring session at the user's request: specialists were independent, the orchestrator was not.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules: add field-domain table with interval floor and anti-typo ceilings — applied
- [BLOCKING] Core Rules: list MVP tags, tag-to-fields table, reject role fields without tag, list stat keys — applied
- [BLOCKING] Core Rules: define cost semantics and level base — applied, Tower GDD may overturn
- [BLOCKING] Rule 10: read context without a live entity, expose level count, injected failure handler — applied
- [BLOCKING] Interactions/Dependencies: Input contradiction resolved, no record until Input GDD adds one — applied
- [BLOCKING] Core Rules: extension rule, no empty reserved fields — applied
- [BLOCKING] Core Rules: stage visual knobs live in the scene — applied
- [BLOCKING] Overview: guarantees base values only; share measured from DamageEvent — applied
- [BLOCKING] Acceptance Criteria: AC 1, 2, 6, 7, 9, 11, 12 rewritten; deferred-criteria table with owners — applied
- [RECOMMENDED] Open Questions: routes, enemy fields, refund, faucets, preview data, tooling deferred to named owners
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 9c246edf8cf6e7f3a59a7bacc1ab2605f2e5030e
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 2eb89302dc6d316c2f3f8c74c11f10d44219e5b2
Reviewed-Content-Hash: design/art/art-bible.md f27f37cc8274e7edee283103be2c318dc98e43d7
Reviewed-Content-Hash: design/gdd/systems-index.md cf271b09df51fc518cf5accfb0fa9123f6625817
## Review — 2026-11-01 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: L (producer should verify before sprint planning)
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, creative-director (senior)
Blocking items: 8 | Recommended: 10
Summary: The structure is sound — a read-only, validated, all-or-nothing catalogue behind one accessor, balance left to the owners. What blocks is local: the accessor cannot serve the HUD cost chip or a maxed tower's "next level" without a fatal error; "never returns a number" cannot be implemented in typed GDScript; the stat-key, tag→role-field and field-invariant tables are missing; and two promises (modifiers with no call-site changes; a stage is just data) overclaim. Each fix is a sentence or a table, not a redesign. Storage-mechanism questions go to the ADR; missing record fields go to the consumer GDDs.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules (Rule 10): add a definition-level accessor form (def_id, level, key) plus a max_level query so HUD/build-menu/next-level reads are not fatal
- [BLOCKING] Core Rules (Rule 10) / AC7: failure = handler with enum cause + paused tree + always-processing fatal overlay; return value unspecified; AC7 split into four rows
- [BLOCKING] Core Rules: publish the MVP stat-key table (key, record type, levels, int/float) and the accessor/direct boundary; fixes L77 Combat ambiguity
- [BLOCKING] Core Rules (Rule 7): field invariant table (type, min incl/excl, unit); cost per-step vs cumulative; level base; bounds for leash_radius, Burst, damage/range/splash signs; slow_strength → [0,1) and fix AC3
- [BLOCKING] Core Rules (Rule 7): tag vocabulary and tag→role-field map owned here; AC2 unbuildable without it
- [BLOCKING] Edge Cases / AC5 / Rule 2: error cascade policy (manifest/file errors stop record checks), reconcile L91-92 with AC5, define "no lookup served" in Failed, add ID regex to Rule 7 with an AC row
- [BLOCKING] Summary L12 / Rule 10 L48 / Overview L18: narrow "no call-site changes" to numeric stats; "add a stage" = record + scene, add a zero-script-diff AC
- [BLOCKING] AC11: split into 11a comparer self-test (value equality, synthetic mutator, CI now) and 11b post-battle snapshot gated to Tower/Enemy stories
- [RECOMMENDED] Detailed Design L59: add ADR-requirements line (missing ≠ zero, unknown property rejected, value-equality snapshot, lazy scene_ref, exporter includes manifest files)
- [RECOMMENDED] Acceptance Criteria: gate AC10 on Enemy & Wave and AC12 on Game State with seam tests now; move AC15 out of ACs
- [RECOMMENDED] Core Rules (Rule 3): scope to record-to-record refs; scene_ref is an asset ref; content test checks visual_key exists
- [RECOMMENDED] Core Rules (Rule 12): app composition root injects, not battle root (menus/preview need Stage)
- [RECOMMENDED] Interactions / Dependencies L128: no Input record at MVP until Input GDD; fix wording
- [RECOMMENDED] Core Rules: define spawn_interval at count=1; optional sanity-ceiling column; empty tags legality; Hero level
- [RECOMMENDED] Tuning Knobs (advisory): list this system's own knobs (10 s, 1 s, manifest)
- [RECOMMENDED] Acceptance Criteria: AC9 temp dir; AC13 save canary hash; AC14 timing start/stop or advisory; AC3 add -inf and NaN-on-int; name test paths
- [RECOMMENDED] Open Questions: enable gdUnit4 in project.godot
- [RECOMMENDED] Player Fantasy: not a real gap at standard — do not add
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 0af586e4c6c05c88c26674c7ea7d7194b03d7d50
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 2eb89302dc6d316c2f3f8c74c11f10d44219e5b2
Reviewed-Content-Hash: design/gdd/systems-index.md 941dc953b87336a149fe249c484a103dcba5531e
Reviewed-Content-Hash: design/art/art-bible.md f27f37cc8274e7edee283103be2c318dc98e43d7
## Review — 2026-11-01 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M (producer should verify before sprint planning)
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, economy-designer, level-designer, creative-director (senior)
Blocking items: 6 | Recommended: 13
Summary: Document is byte-identical to the previous (8-blocker) review; this round should have been skipped per Phase 1 and largely confirms that entry. Architecture and the "contracts now, fields to owners" rule hold; ~70% of new findings belong to downstream GDDs or the storage ADR. Six one-sentence fixes remain, four of them prior-entry blockers never applied: accessor failure/return type, levelless-record level, format must detect missing/fractional/unknown fields, coded error identity with cascade, slow_strength (0,1), AC6 applicable keys. Next pass: diff against this log line by line, not a fresh specialist round.
Prior verdict resolved: No
Findings:
- [BLOCKING] Core Rules (Rule 10) / AC7: "returns null, never a number" not expressible in typed GDScript; handler is the contract, return type per key declared (prior #34 unapplied)
- [BLOCKING] Core Rules (Rule 10) / AC6: level argument undefined for Enemy/Hero/Burst (prior #46 unapplied)
- [BLOCKING] Detailed Design L102 (ADR line): format must detect missing field, fractional int, unknown property, else Rule 8 "no fallbacks" is void on typed Resources (prior #41 unapplied)
- [BLOCKING] Acceptance Criteria AC1/2/4/5: error = {code, source, record_id, field}; unknown tag suppresses role checks; manifest errors stop record checks (prior #38 partly unapplied)
- [BLOCKING] Core Rules (field domains L47) / AC3: slow_strength must be (0,1) exclusive; 0 is dead data, 1 freezes (prior #36 unapplied)
- [BLOCKING] Acceptance Criteria AC6: "every key" contradicts AC7 on role-less towers; read only applicable keys
- [RECOMMENDED] Core Rules (Rule 10): cumulative_cost derived read, must-answer before HUD story (3 specialists; CD demotes)
- [RECOMMENDED] Core Rules: "cost means gold"; tick floor literally 1/60 s; app (not battle) composition root (prior #44)
- [RECOMMENDED] Edge Cases / Rule 8: fatal-screen ownership circular; boot script owns load/validate/fatal
- [RECOMMENDED] Summary L12 / Overview L18 / Status L3: fix overclaims
- [RECOMMENDED] Acceptance Criteria: deferred rows copied verbatim into owner GDD ACs; visual_key differs per level AC; headless load for bot modes
- [RECOMMENDED] Core Rules (Rule 3): scene_ref is the sanctioned path exception, stored typed so it packs in export
- [RECOMMENDED] Acceptance Criteria: wave-group reads are mutable refs → to_dict snapshot (ADR); AC10 frees instances
- [RECOMMENDED] Core Rules: stage gold-budget formula computable now
- [RECOMMENDED] Acceptance Criteria: test paths/story types; AC3 split; AC7 four rows; AC12 into AC7; AC15 out (prior #42/#48 unapplied)
- [RECOMMENDED] Open Questions L250: traits/"shots chain" deadline before VS tree design
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 0af586e4c6c05c88c26674c7ea7d7194b03d7d50
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 2eb89302dc6d316c2f3f8c74c11f10d44219e5b2
Reviewed-Content-Hash: design/gdd/systems-index.md 0a5770dc43319d90e92722647769f47ab2b44814
Reviewed-Content-Hash: design/art/art-bible.md f27f37cc8274e7edee283103be2c318dc98e43d7
## Review — 2026-11-01 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M (producer should verify before sprint planning)
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, creative-director (senior)
Blocking items: 4 | Recommended: 11
Summary: Third round's 6 blockers confirmed applied. Four contract defects remained, all internal contradictions an implementer hits on day one: unknown property required by the ADR line but absent from Rule 7/AC2; "record type has no records" in the wrong error tier vs AC5; Stage ints with no declared read path; AC3 "lives 0" ambiguous. CD kept 4 of 9 proposed blockers and downgraded the rest (wave sequencing, format detectability, export packing, per-key return type, slow_duration floor) to owners or the ADR. All 4 applied the same session (autonomous mode); CD recommends a targeted check, not a fifth full review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Core Rules (Rule 7) / AC2: unknown property never classified as an error — applied (check list, Edge Cases, AC2)
- [BLOCKING] Core Rules (Rule 7) / Edge Cases / AC5: empty record type is post-parse but treated as manifest-tier — applied (defined as post-parse, pre-validation manifest-tier check)
- [BLOCKING] Core Rules (stat keys, Rule 10): starting_gold/starting_lives have no read path — applied (Stage fields declared direct-read, no stat-key row)
- [BLOCKING] Acceptance Criteria AC3: "lives 0" ambiguous — applied (starting_lives 0 fails, lives_cost 0 passes)
- [RECOMMENDED] Open Questions L246: wave-to-wave sequencing must resolve in the MVP Enemy & Wave GDD, not before VS
- [RECOMMENDED] Detailed Design L104: let the ADR weigh JSON vs Resources evenly; detection may be CI-only under Resources (engine claims unverified for 4.7.2)
- [RECOMMENDED] Core Rules (Rule 4) / L237: state export constraint (include filters; ResourceLoader.exists)
- [RECOMMENDED] Core Rules (Rule 10): failure handler must halt simulation; AC13 needs a release-build trigger for a bad call
- [RECOMMENDED] Field domains: slow_duration floor "above 0"; spawn_interval at count=1 required-but-ignored
- [RECOMMENDED] Open Questions: rounding of int stats under % modifiers → Stat GDD
- [RECOMMENDED] Acceptance Criteria AC3/AC7: table-drive per domain row; enumerate levels 0/-1/max+1/missing; 1/60 as named constant
- [RECOMMENDED] Acceptance Criteria: error-code vocabulary → ADR; AC2 add two role tags, empty groups[], empty enemy tags passes
- [RECOMMENDED] Acceptance Criteria AC13: split; hash save before/after; depends on Game State fatal screen; deferred rows for Rules 5, 8, 12; AC11/12 are Logic; name test paths
- [RECOMMENDED] Core Rules (Rule 12 vs 5): who holds the Ready catalogue across scenes; gdUnit4 CI --import retry
- [RECOMMENDED] Open Questions: hero pin-mechanic fields untracked → Hero GDD row
Receipt note: the document was reviewed before its 4 fixes and was not committed, so that hash is unrecoverable. The zero hash below makes the next check report CHANGED, because the fixes have not been reviewed.
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 0000000000000000000000000000000000000000
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 2eb89302dc6d316c2f3f8c74c11f10d44219e5b2
Reviewed-Content-Hash: design/gdd/systems-index.md 941dc953b87336a149fe249c484a103dcba5531e
Reviewed-Content-Hash: design/art/art-bible.md f27f37cc8274e7edee283103be2c318dc98e43d7

## Revision — 2026-11-04 — ADR sync
Wording and tables only; no domain bound or balance value changed.
- Rule 7: `unknown_property` is a field the record's own type does not declare; `record_count` (exactly one Input and one Hero record) joins the manifest tier; "empty lists" becomes each list's `min_count` (ADR-0002 Decisions 3 and 5).
- Rule 9: the content test also fails an unlisted data file, a manifest path whose case differs from the file, and a key repeated in one JSON object (ADR-0002 Decision 7).
- The "Becomes an ADR" note and the format and snapshot Open Questions rows point to ADR-0002 and read JSON; only the Android export proof stays open. The unknown-property edge case matches Rule 7.
- Interactions and Dependencies rows for the HUD add Burst `cooldown` through the accessor for the wedge (cross-review N2).

## Revision — 2026-11-04 — ADR-0004 to ADR-0008 sync
No balance value changed; Status unchanged. The one-tick floor reads `TickMath.TICK_SECONDS` (ADR-0004 Decision 2). Rule 10, Edge Cases and AC 7 list the six bad-call causes in order (null context, unresolved `def_id`, unknown key, inapplicable key, type mismatch, bad level) and say the returned `0` or `0.0` is unusable (ADR-0005 Decisions 1 and 2). The signal `waves_complete` is now `waves_completed` (ADR-0006 Decision 5).

## Revision — 2026-11-04 — ADR-0009 sync
No balance value changed; Status unchanged. Rule 9: the CI content test fails a `path_points` coordinate that a 32-bit float cannot hold exactly (ADR-0009 Decision 4). Criterion 10 adds a fixture case for it.

## Review — 2026-11-05 — Verdict: APPROVED
Review mode: full · Workflow: standard
Scope signal: M (producer should verify before sprint planning)
Specialists: none spawned. This session had no agent tool, so the main reviewer did the game-designer, systems-designer, godot-specialist, qa-lead and creative-director passes from each role's view. None of those agents reviewed or passed this document.
Blocking items: 0 after fixes (5 found, all wording, all applied) | Recommended: 6
Summary: Checked line by line against the eleven Accepted ADRs, with ADR-0002 and ADR-0005 as the source of truth. The five blocking items were all stale or contradicting text, not design gaps, and each was fixed by wording that follows an ADR. No balance value or design intent changed. No design decision for this system is open: the open rows in Open Questions are owned by other GDDs, by Technical Setup proofs or by Vertical Slice. APPROVED because no blocking item remains and no decision is open; the open recommendations are advisory.
Prior verdict resolved: Yes (the fourth review's 4 blockers stayed applied; the three ADR syncs of 2026-11-04 checked and kept)
Findings:
- [BLOCKING, fixed] Field domains: "world units" for lengths, speeds and the Input fields; ADR-0003 and the Input GDD say field units. Now "field units", with one line defining them
- [BLOCKING, fixed] Acceptance Criteria AC9: "the real manifest plus an unlisted file gives zero errors" contradicted Rule 9's unlisted-file check; now a fixture manifest in res://tests/fixtures/catalogue/ (ADR-0002 Decision 2, V3)
- [BLOCKING, fixed] Edge Cases / AC5: record_count, a bad file envelope and an unknown record type were boot-fatal in Rule 7 and ADR-0002 but had no edge case or criterion; added (ADR-0002 Decision 5, V2)
- [BLOCKING, fixed] Core Rules (Rule 7) / Edge Cases / AC2: missing ID, JSON null and wrong kind (ADR-0002 Tier 1) were not listed; added
- [BLOCKING, fixed] Detailed Design ("Becomes an ADR" note): still recommended typed Resources ahead of the ADR-0002 result; rewritten to state the decision
- [RECOMMENDED, fixed] Core Rules (Rule 3): scene_ref is a path, not a record reference (ADR-0002 Decision 1)
- [RECOMMENDED, fixed] Core Rules (Rule 6) / Edge Cases: the engine does guard stored lists after validation (ADR-0002 Decision 4); "nothing blocks it" was wrong
- [RECOMMENDED, fixed] Interactions / Dependencies: HUD also reads range for range rings (ADR-0005 Decision 5); Dependencies said no downstream GDD exists, but all seven MVP GDDs exist and list this one
- [RECOMMENDED, fixed] Field domains (tap_slop): the CI content test also checks tap_slop > drag_slop (ADR-0002 Decision 7)
- [RECOMMENDED, fixed] Open Questions / Deferred criteria: scene-check row closed by ADR-0002 Decision 8 (X1); export row names ADR-0002 X1 and X2; new row for the pin_exclusion min_count owned by Hero or Enemy & Wave
- [RECOMMENDED, open] Other GDD: combat-damage.md line 32 still says "world units" for the cached enemy position; the Combat owner should change it to field units
- [RECOMMENDED, open] Acceptance Criteria AC13: no way named to force a bad accessor call in a release build (carried from the fourth review)
- [RECOMMENDED, open] Acceptance Criteria AC7: could name the ADR-0005 cause codes (stat_null_context and the rest) so tests compare the first token
- [RECOMMENDED, open] Player Fantasy and Tuning Knobs absent: advisory at standard; the proposed 10 s and 1000 ms thresholds and the domain ceilings are the knobs
- [RECOMMENDED, open] Open Questions: tests/README.md is still stale (says gdUnit4 is not installed), owner gameplay-programmer
- [RECOMMENDED, open] Header: Creative Director Review line dates from 2026-11-01; no CD gate has run on the ADR syncs
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md eb4deee4f73f034bc672f49d569d8d5601822d8e
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 5fc68e4c2eda531b8ef80a5663b2f33961b139cf
Reviewed-Content-Hash: design/gdd/systems-index.md 971496057bf0c58f61f40f19e60298032121850a
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md add0f1c5a5b8b8bd7f52b3683fd9985b84c911b2
Reviewed-Content-Hash: design/gdd/battle-hud.md 9cae820470e28dccf98015d4a423e8c9d9626a5a
Reviewed-Content-Hash: design/gdd/combat-damage.md e4df04fab059c0779ec3460522a8b4f0f6605fc1
Reviewed-Content-Hash: design/gdd/enemy-wave.md adfe9932b1756518dd4219a26cdb9c048950950d
Reviewed-Content-Hash: design/gdd/tower-system.md 0d7fc21d197c7b1ae4c7bc6f6749df6d58d7b886
Reviewed-Content-Hash: design/gdd/hero-system.md 88c68ce97af3b80dd0dff559a3ab3d65a2cfa1f2
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d0971ae2056275d68099e04af472c70bac83009d
