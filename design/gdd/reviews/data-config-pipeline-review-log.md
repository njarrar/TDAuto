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

## Revision — 2026-11-03 — cross-GDD warning pass
From design/gdd/gdd-cross-review-2026-11-03.md, Consistency Re-run. `requires_bend` in Rule 10, HUD rows, Input record note, cross-references, QQ-20 in Open Questions.

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: M
Specialists: none (lean; one reader)
Blocking items: 1 | Recommended: 6
Summary: Lean re-review. Rule 7's new cross-field check has no order against field checks, so one typo can give two errors or blame a valid field. No new lower bound is needed; Flow's are covered. The reader had no shell, so the sim, diffs and scripts were not run by it.
Prior verdict resolved: See summary
Findings:
- [BLOCKING] Rule 7, AC3: run the `tap_slop` check only when both fields are present, finite and in domain, and add those cases.
- [RECOMMENDED] Input singleton: "one Input record" is enforced nowhere.
- [RECOMMENDED] Edge Cases: no `tap_slop` ≤ `drag_slop` entry.
- [RECOMMENDED] Rule 7: "one cross-field check", though `pin_rect` is also cross-field; "empty lists" against empty Enemy tags.
- [RECOMMENDED] Criteria: inverted `pin_rect`, `pin_exclusion` radius 0, out-of-range coordinates, empty `groups[]`.
- [RECOMMENDED] AC3: table-drive floors per domain row.
- [RECOMMENDED] Interactions: Flow also reads `left_handed` and the Hero ID.
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 5e5df4a50191c71f81644957fb43ef96b38ab6d5
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b

## Revision — 2026-11-04 — after the review above (not a new verdict)
User accepted every recommendation ("Implement all recomended"). Applied: the blocker (Rule 7's cross-field check runs only when both fields are valid) and recommended items, including the one-Input-record check, the Enemy `tags` exception, new edge cases and criteria, and Flow's reads. `tests/README.md` was corrected for gdUnit4, so that Open Questions row is gone.
Re-review pending: the hashes above no longer match this document.

## Review — 2026-11-04 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: M
Specialists: none (lean; one reader with a shell)
Blocking items: 2 | Recommended: 2
Summary: The Rule 7 guard is fixed, but AC3's positive case cannot reach it: `tap_slop` 15 is below its floor. A tower with empty tags gives two errors where AC2 demands one. Fixtures were not run.
Prior verdict resolved: Partly
Findings:
- [BLOCKING] AC3: use `drag_slop` 20 with `tap_slop` 20 for the error, and 20 with 21 for the pass.
- [BLOCKING] Rule 7, AC2: a Tower with empty or missing `tags` reports one error; name its code and add the missing case.
- [RECOMMENDED] AC3: state the base for inclusive bounds, `drag_slop` 15 with `tap_slop` 31.
- [RECOMMENDED] Rule 7: run `pin_rect`'s ordering only on finite values; say which extra Input record is reported.
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 05e3e8f4ca5b1c2a34b39d2ebc9215b0d5342861
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 0804873149506940e730239e7998a943f8bcc5cd
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md c67e5441a28be83b92efa4b903b15c4e76918a6b
Reviewed-Content-Hash: design/gdd/tower-system.md 86f753dacdcc4d904575ab5d6bdfffb8fd4f6415
Reviewed-Content-Hash: design/gdd/hero-system.md d075d8207bffb1b7f4a23a2f0467da21c2509528
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md b869a7ca338cf3100f72219f98e64207b252dec6
Reviewed-Content-Hash: design/gdd/battle-hud.md 044488039c9a221f998173317300db5f3cd7ab5b
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f

## Revision — 2026-11-04 — after the review above (not a new verdict)
Applied: both blocking (AC3's values; one error for empty or missing Tower tags) and both recommended.

## Review — 2026-11-04 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: M
Specialists: none (lean check; one reader with a shell)
Blocking items: 0 | Recommended: 0
Summary: Both blockers resolved: `drag_slop` 20 with `tap_slop` 20 reaches only the cross-field check, and a Tower's empty or missing `tags` gives one error. No fixtures were run.
Prior verdict resolved: Yes
Findings:
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 85f7616bf55e163f7ef55c61de49bf99b593b7ce
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md c1fd31adac239441dbdae3fe76d40b24379b3e5d
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/enemy-wave.md fda517f00006319d13c59450aeec9d155bb70c8f
Reviewed-Content-Hash: design/gdd/tower-system.md 14b131b888ccec57b15294ebb57b928615b890d0
Reviewed-Content-Hash: design/gdd/hero-system.md c9f2fd38018ff70731690e5aaaa7bd148c397746
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md f2ad63e7bb8cf880695e73dc0a744bc91b56fe70
Reviewed-Content-Hash: design/gdd/battle-hud.md 53e31996a65be6476eb2e700352e027701c1b760
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f
