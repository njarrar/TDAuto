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
Review mode: full · Workflow: standard
Scope signal: M
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, creative-director
Blocking items: 5 | Recommended: 12
Summary: The architecture held and no settled decision was reopened. Five text contradictions remained: AC3's Input fixture gave two errors while claiming one, Rule 7's empty-list ban clashed with empty enemy tags, the one-tick floor of 1/60 was below one tick at the 30 Hz Flow now allows, the Input record's "false by default" bools contradicted Rules 7 and 8, and AC2's "exactly one error" had no stated precedence. The creative director rejected the drift, float-precision and storage-format blockers as already handled or mistaken.
Prior verdict resolved: Yes (the fourth review's 4 blocking items)
Findings:
- [BLOCKING] Acceptance Criteria AC3: drag_slop 15 / tap_slop 15 fails tap_slop's floor too, so two errors; use 20 / 20.
- [BLOCKING] Rule 7, MVP tags: "empty lists" vs enemy tags that may be empty; name the lists that must be non-empty.
- [BLOCKING] Field domains: interval floor of one tick (1/60) is below one tick at 30 Hz (Flow Tuning Knobs); user decision, recommended fixed 1/30 s.
- [BLOCKING] Record table, Input row: bools "false by default" contradict Rules 7 and 8; authored explicitly, false at MVP.
- [BLOCKING] Rule 7, AC2: no precedence for "exactly one error" (unknown tag vs role-tag count, missing field vs domain).
- [RECOMMENDED] Rules 9, 13: a local content-test command; typos are the content test's.
- [RECOMMENDED] Rule 3: scene_ref is an asset reference, not a record reference.
- [RECOMMENDED] Field domains: "world units" to "field units" (flagged four times).
- [RECOMMENDED] Field domains: positive minimums for "above 0" floors; a move_speed ceiling.
- [RECOMMENDED] Rule 9: name Battle HUD's one-digit bonus cap.
- [RECOMMENDED] Rule 7: more boot-fatal cross-field checks (hero_start in pin_rect, duplicate slots, typed enemy_id and wave_ids).
- [RECOMMENDED] Rule 1: list exempt constants.
- [RECOMMENDED] Acceptance Criteria: AC1 duplicate count, AC4 named errors, AC5 per-fault table, AC6 key list, AC8 mutation isolation, AC9 fixture path, AC3 codes and NaN, level_count/is_tower on an unknown ID.
- [RECOMMENDED] Intent notes for lives_cost 0, cost 0, damage 0.
- [RECOMMENDED] Routed to ADR-0002: ResourceLoader under export remapping, JSON include filters, duplicate_deep and a recursive compare, JSON numbers as float, NaN reachability, --import before headless CI, null-return error codes, untrusted .tres scripts, synchronous load, no assert on the handler path.
- [RECOMMENDED] Routed to content tests and owning GDDs: load and can_instantiate() in AC10, visual_key check, last-wave intermission, count x interval, lives_cost vs starting_lives, cost vs starting_gold; Input GDD's record line to list the bools.
- [RECOMMENDED] Rejected as blocking: scene and data drift (the Stage record holds the layout), slow_strength float precision (GDScript float is 64-bit), storage-format detection and assert stripping (already deferred to the ADR).
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 5e5df4a50191c71f81644957fb43ef96b38ab6d5
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md b17a450b756471e44e54fb3b565a8e5e3defea1b
Reviewed-Content-Hash: design/gdd/systems-index.md 46346acf72e112720034dfd4bcd5b35b83b5f552
Reviewed-Content-Hash: design/art/art-bible.md 56d68c718c99871a28b826b22a8dc87694ab2d7f
Reviewed-Content-Hash: design/gdd/tower-system.md 83803cb361c7fe6971b87874234be4f565d8651c
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/hero-system.md 377e450bbee022ae776076cebdd1ed1c092a02fc
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 23d2a60fac1632b52fa5c9a35394466973c672ba
Reviewed-Content-Hash: design/gdd/battle-hud.md 4a8b31f64adc1ad85b770314b77dc0aa5435f39c
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d79fe3bf982a1d15a806cc0725421521a6a735d5
Reviewed-Content-Hash: docs/architecture/architecture.md 1bc205b5b722ffc015d14444df535b375764cb42

## Revision — 2026-11-04 — after the review above (not a new verdict)
Applied in autonomous mode: all 5 blocking items (AC3 fixture at 20 / 20 with 21 passing; named non-empty lists with tags exempt; interval floor 1/30 s citing Flow's Tuning Knobs, decision taken on the creative director's recommendation, since every starter interval is at least 0.125 s; Input bools authored explicitly; Rule 7 precedence and AC2 fixtures) and recommended: field units throughout, Rule 3 scene_ref note, Rule 9 HUD cap and local content-test command, Rule 1 exempt constants, AC1 duplicate count, AC3 NaN exactly one error, level_count and is_tower on an unknown ID.
Not done: positive minimums, extra cross-field checks, AC4/AC5/AC6/AC8/AC9 rewrites, intent notes, and every routed item.
Re-review pending: the GDD hash above is of the reviewed text, not this revision.

## Review — 2026-11-05 — Verdict: NEEDS REVISION
Review mode: full · Workflow: standard
Scope signal: M
Specialists: game-designer, systems-designer, godot-specialist, qa-lead, creative-director
Blocking items: 4 | Recommended: 20
Summary: The five prior fixes held and the architecture stood through a sixth review. Four text faults remained: the interval floor written `1/30`, which GDScript reads as integer division, 0; Rule 10's accessor contract, which made a false claim about typed GDScript and left the value after a bad call unspecified; "above 0" floors with no positive minimum, so a walk_speed of 5e-324 divides by zero in Hero; and Rule 9's content-test promises with no owner or criterion, plus an ambiguous tag vocabulary. The creative director prescribed a spot-check of the changed lines rather than a seventh full review.
Prior verdict resolved: Yes (all 5 prior blocking items)
Findings:
- [BLOCKING] Field domains: `1/30` is integer division in GDScript; named constant MIN_INTERVAL = 1.0 / 30.0 with a 1e-6 tolerance; to_ticks (round) named.
- [BLOCKING] Rule 10: after a bad call the handler stops play and the accessor returns 0 or 0.0, never NAN; signature to ADR-0002.
- [BLOCKING] Field domains: speeds, lengths and max_hp floor at 1, not "above 0".
- [BLOCKING] Rule 9, Rule 7, AC2, AC10: a content-test register naming each owner's table and proof; per-type tag vocabulary, Enemy's empty; at least one Stage and non-empty rationale asserted.
- [RECOMMENDED] combat-damage.md: slow_duration floor restated as one tick at 1/60 (routed, fixed in the same change).
- [RECOMMENDED] Rule 6: make_read_only() is shallow, nothing on Resource properties (ADR-0002).
- [RECOMMENDED] Rule 7: unknown property is a field its own record type does not declare; type and enum checks, hand enum, type rows for non-numeric fields.
- [RECOMMENDED] Cross-References: Flow's 30 per second minimum; edge_reject_margin ceiling equals its starter value, so raising it is a HUD layout change first.
- [RECOMMENDED] Intent notes for 0 values; "default" against "no fallbacks"; content test at 30 and 60 per second.
- [RECOMMENDED] Acceptance Criteria (story-level, qa-lead): error code table and cause enum, multiset duplicates, two role tags, empty groups, table-driven AC3 and AC5, programmatic key iteration, unknown-ID cases, mutation isolation, AC9 fixture path, AC11 per category, release-build check in CI (ADR-0007), AC14 and AC15 timing, load once.
- [RECOMMENDED] Routed to ADR-0002: accessor signature, fractional ints in .tres, release-build assert mechanism.
- [RECOMMENDED] Disagreements: the creative director lifted only qa-lead's "at least one Stage" assertion to blocking and held the rest of the criteria list as story-level; game-designer and qa-lead both raised Rule 9 and were merged.
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md d6ed4447e34cf1dd88ee67ee9136c4f6dbc29db4
Reviewed-Content-Hash: design/gdd/tower-system.md 2c025196c3039eee362885ab82138a8999c3dd01
Reviewed-Content-Hash: design/gdd/hero-system.md 22b23c09a786eb7b142e7e998c12cf1b7ff090ce
Reviewed-Content-Hash: design/gdd/enemy-wave.md 437b5194ddeb6edaf088ad48cc87f07ca7cffc6c
Reviewed-Content-Hash: design/gdd/combat-damage.md bf6997474386b88583de7a3789dd0f3ea938ad9a
Reviewed-Content-Hash: design/gdd/battle-hud.md c523e7d611336730edba829d7f4c8d8109fc0482
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 9d6ec8138446d49ffa36df14ddb9b3c9d9fa1ce7
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 318de9b091a58161cab40b290a44203ff8486f99

## Revision and spot-check — 2026-11-05 — APPROVED
Applied in autonomous mode: all 4 blocking items (MIN_INTERVAL constant and tolerance, to_ticks named; Rule 10 return value and handler stop, signature to ADR-0002, AC7 asserts it; floors of 1 for range, leash_radius, radius, reach, splash_radius, move_speed, walk_speed, max_hp and path_width, AC3 boundaries; per-type tag vocabulary, AC2 fixture; content-test register, AC10 extended) and recommended: Rule 6 make_read_only wording, Rule 7 unknown property per own type, Flow cross-reference row. Follow-on edits outside this GDD: combat-damage.md slow_duration floor, move_speed and radius ranges; enemy-wave.md spawn_interval, move_speed, v_slow and v_fast ranges; hero-system.md radius, move_speed and walk_speed ranges.
A godot-specialist spot-check closed its three items and caught a Unicode minus in the code span; fixed. A systems-designer spot-check closed the floors, the interval and the tag fixture, and found the first register retold the owners' rules wrongly (rules filed under the wrong owner, rules no owner has, criteria pointers to stories). The register was rewritten to name each owner's content table and the criterion that proves it, all pointers confirmed by that check, and the stale "above 0" and 1/60 ranges in other GDDs were aligned.
Verdict: APPROVED, on the creative director's ruling that a spot-check of the changed lines decides approval. Not done: every remaining recommended and routed item above.
