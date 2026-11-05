## Architecture Review Report
Date: 2026-11-05
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override in `project.yaml`
Engine: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D)
GDDs Reviewed: 8 (systems index, game concept and the cross-GDD review read for context; no requirements drawn from them)
ADRs Reviewed: 11 (ADR-0001 to ADR-0011, all Accepted)
Reviewer: a fresh `/architecture-review` pass, autonomous mode. This reviewer wrote none of the ADRs and judged them on what the files say.

Reviewed-Content-Hash: docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md 5f13ef0dd8831294e4a3e00379acf5b4d2639149
Reviewed-Content-Hash: docs/architecture/adr-0002-catalogue-storage-format-manifest-validation.md 65a5fbdd0606124b20b1370a4065a5453c3378c3
Reviewed-Content-Hash: docs/architecture/adr-0003-input-adapter-display-stretch-platform-lifecycle.md 5f1b1ded4f5fa3df09ef2f5bcbeb9c1b00b1be99
Reviewed-Content-Hash: docs/architecture/adr-0004-fixed-tick-clock-tick-order-frame-order-determinism.md 7e2eab5c72a2dac54126bc49bc49691931d8dda0
Reviewed-Content-Hash: docs/architecture/adr-0005-stat-accessor-read-context-contract.md b9c5c7817137e14d1f64977daa075aad7b03dff1
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-signal-contracts-view-allowlist.md 56b7ec6083ef547dcc32edff1f621419a37295d1
Reviewed-Content-Hash: docs/architecture/adr-0007-headless-test-harness-gdunit4-layer-lint.md 7423138f3e71f2a117907533a51c9c780c7031c1
Reviewed-Content-Hash: docs/architecture/adr-0008-input-resolver-core-signal-contract.md 784dd51eecd37f86856684ec15e0672ed0f09866
Reviewed-Content-Hash: docs/architecture/adr-0009-enemy-entity-roster-combat-api.md 2a21515e8a7809f35b274bc710ef815404df8da1
Reviewed-Content-Hash: docs/architecture/adr-0010-sim-input-split-command-results-dev-telemetry.md a59213bcadb86783d86bcbe1b61eefe90fba4c60
Reviewed-Content-Hash: docs/architecture/adr-0011-battle-field-rendering-draw-call-budget.md 6fe2610f434c88cc17d33769865fd7906dc9ccc1
Reviewed-Content-Hash: design/gdd/battle-hud.md fee763f2989f7c98b6ba47be1120cab4ca79b7ec
Reviewed-Content-Hash: design/gdd/combat-damage.md e4df04fab059c0779ec3460522a8b4f0f6605fc1
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md fb484d24990461f0800de4d022afa95997ee512d
Reviewed-Content-Hash: design/gdd/enemy-wave.md adfe9932b1756518dd4219a26cdb9c048950950d
Reviewed-Content-Hash: design/gdd/game-concept.md 93a774e02d9d14747e67ead5ce82140d1718b81f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md d0971ae2056275d68099e04af472c70bac83009d
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md 7b9dc10d39366084b506416339d377adc20fb3ec
Reviewed-Content-Hash: design/gdd/hero-system.md 88c68ce97af3b80dd0dff559a3ab3d65a2cfa1f2
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4e034772ff47e826f54e2e71a40c11e00b0a8fd4
Reviewed-Content-Hash: design/gdd/systems-index.md 04ed8ca4e409f7c290fd501c9ef8710f737245b5
Reviewed-Content-Hash: design/gdd/tower-system.md 0d7fc21d197c7b1ae4c7bc6f6749df6d58d7b886
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 7ffac93807116ec27760c32d88ff7ffbff243262
Reviewed-Content-Hash: docs/architecture/architecture.md a5925b448215e308aec8cadeeefa4dd07d86b2cb
Reviewed-Content-Hash: docs/engine-reference/godot/VERSION.md fcf85779788e0facbeca26aeda9fd41955e2633e
Reviewed-Content-Hash: docs/engine-reference/godot/breaking-changes.md e5917f8723640a1e6908d8b2c23daab46f9bc97c
Reviewed-Content-Hash: docs/engine-reference/godot/current-best-practices.md b245cfe8012eaf104f7303fd32fcabf0eaa3c9a0
Reviewed-Content-Hash: docs/engine-reference/godot/deprecated-apis.md 6a1353983e1db0d7bc0cc41a568b039495b5413c
Reviewed-Content-Hash: docs/engine-reference/godot/probe-results.md 07333500d80f9a964a6bca12fcad96364da158ec
Reviewed-Content-Hash: docs/engine-reference/godot/modules/animation.md ee51f50a46f8c63b771f62fe438947d4d84c59e3
Reviewed-Content-Hash: docs/engine-reference/godot/modules/audio.md c72af247505908a04f84a1dd3e765939efe700bd
Reviewed-Content-Hash: docs/engine-reference/godot/modules/input.md 3406b1b813858898696e510ea0accfcc7df98af8
Reviewed-Content-Hash: docs/engine-reference/godot/modules/navigation.md 7ae18ffbd2c3230cb19d610373225bfba187a472
Reviewed-Content-Hash: docs/engine-reference/godot/modules/networking.md 6606880462a2241014f77feb9610c5611e659ec6
Reviewed-Content-Hash: docs/engine-reference/godot/modules/physics.md 3b6ac8947f3f3e8c9ac9e6e0ff6cac06fdb8d805
Reviewed-Content-Hash: docs/engine-reference/godot/modules/rendering.md 2a303185bb57eed31dd1151a036784820747b211
Reviewed-Content-Hash: docs/engine-reference/godot/modules/ui.md 30ad166ab8c4e92c15aa37ed3464483b92b7845b
Reviewed-Content-Hash: project.yaml e704941bbbf4ca25188e8eb8acecac18e6387d0e
Reviewed-Content-Hash: .claude/docs/technical-preferences.md e64f1a53e5b13cb503622f1c3e0691e56789becb
Reviewed-Content-Hash: .claude/skills/architecture-review/SKILL.md 1a9d28aadbcbd26b5fc6b8ed1c64d73ae82b7b73
Reviewed-Content-Hash: .claude/skills/architecture-review/references/1-load.md 9a65759ebdbb2cb1f9744775bfed18cb25e76347
Reviewed-Content-Hash: .claude/skills/architecture-review/references/2-extract-requirements.md d08ea0b0e9ab9760b0d8bfe0cd9115f0bc40f8e2
Reviewed-Content-Hash: .claude/skills/architecture-review/references/3-traceability.md bb7b6b65c5e5e5b8869fa692413aa831615dede7
Reviewed-Content-Hash: .claude/skills/architecture-review/references/4-conflicts.md 0d30f8173b23248a32523a365b606dd1ce9642ab
Reviewed-Content-Hash: .claude/skills/architecture-review/references/5-engine.md 318ecbc1361d430badaf5dd8ce4cfc6ab0dff0ca
Reviewed-Content-Hash: .claude/skills/architecture-review/references/6-document-coverage.md dcce78482ec2ce60048989b6f9d1f797dd0a9a0e
Reviewed-Content-Hash: .claude/skills/architecture-review/references/7-report.md a007fd66bdac87812dc272e4b14cd231174e979d
Reviewed-Content-Hash: .claude/skills/architecture-review/references/8-write.md bf6d8946fc7b9e19eda7f65503a5c8f593a0d2b1
Reviewed-Content-Hash: .claude/skills/architecture-review/references/9-handoff.md fd5f681f4c3517c6a2e388c6d78075d82dded22e

---

### Freshness Check
Prior report: `architecture-review-2026-11-04.md` (Mode full, Workflow full, FAIL). It covers this run's mode and tier. The check found no `UNRESOLVED` line and these changes:

- `NEW`: ADR-0009, ADR-0010, ADR-0011.
- `CHANGED`: ADR-0001 to ADR-0008 (dated amendments); seven system GDDs and the game concept; `tr-registry.yaml` (v7); `architecture.md` (now v9); `breaking-changes.md`, `current-best-practices.md`, `probe-results.md`.
- `UNCHANGED`: the Input GDD, the systems index, the cross-GDD review, `VERSION.md`, `deprecated-apis.md`, the module docs, `project.yaml`, `technical-preferences.md`, this skill.

Three new ADRs, plus changes to the registry, `architecture.md` and the engine reference, reach every phase. So this run is a full review, not a `single-gdd` scope (decision logged).

### How the inputs were read
- Denominators: 10 files in `design/gdd/` (8 system GDDs, plus `game-concept.md` and `gdd-cross-review-2026-11-03.md` for context only; 8 carry `## Summary`). 11 ADRs; all 11 carry Status, Decision, GDD Requirements Addressed, Engine Compatibility, ADR Dependencies and Performance Implications. No structural gap.
- Every file over 40 KB was read by section (Grep for headings, then ranges): ADR-0001, ADR-0003, ADR-0007, `architecture.md`, four GDDs, `accessibility-requirements.md` and `interaction-patterns.md`. No whole read of any of them. ADR-0009, ADR-0010 and ADR-0011 (each about 30 KB) were read whole, because all three are new and their Decision, Amendments and requirement tables are what this review checks.
- ADR-0001 to ADR-0008: Status to ADR Dependencies, GDD Requirements Addressed and Amendments, plus the sections a finding needed (ADR-0004 Decision 7, ADR-0007 lint table and scopes, ADR-0008 Decision 5).
- GDDs: the registry already held 123 requirements checked by three reviews. This run read every GDD change since the third review (`git diff aa9768e..HEAD -- design/gdd`) and matched each change against the registry. Unchanged GDD text was not re-extracted.
- No stories exist (`production/epics/` is absent), so Phase 3b (story and test linkage) did not run.
- `docs/consistency-failures.md` does not exist, so there are no known conflict-prone areas to surface.

### Traceability Summary
Total requirements: 124 (123 registered at the last review, plus 1 new)
✅ Covered: 119 (all by Accepted ADRs; 9 split across two Accepted ADRs)
🟡 Covered (Proposed): 0
⚠️ Partial: 5
❌ Gaps: 0

By requirement layer tag: Foundation 55 (52 covered, 3 partial), Core 46 (45 covered, 1 partial), Feature 3 (3 covered), Presentation 20 (19 covered, 1 partial).

Registry changes (registry v8; no renumbering, no deprecation, no provisional IDs in `architecture.md`):
- **New** TR-state-015: Flow's `start_wave()` and `call_early()` run between ticks and return their own result enums in fixed check order (`OK`, `BUSY`, `HALTED`, then `NOT_BUILD`; `NOT_INTERMISSION`, `NO_TIME_LEFT`); a refusal changes and emits nothing. Source: Game State Rules 6 and 9, which now name both results. No entry held it: TR-state-004 covers only when commands run. Covered by ADR-0010 Decisions 2 and 3 (QQ-18). Layer tag Core. Engine risk LOW.
- **Revised** TR-hud-001: the HUD is four pieces (Battle HUD Rule 1, ADR-0011 Decision 1). The old text said "HudTopBand (display-only Controls)". The GDD and ADR-0011 now say one HudTopBand `Control` that draws no text and sets `accessibility_name` and `accessibility_live` for gold and lives; HudField draws all HUD text in one last pass; RangeRingView is a second HUD `_draw` node under the entities. ADR-0011 Migration item 5 asked for this sync.
- **Revised** TR-data-013: the content test also fails a `path_points` coordinate that a 32-bit float cannot hold exactly (Data Rule 9 and AC 10, ADR-0009 Decision 4).
- **Revised** TR-hero-002: `BUSY` first, then `HALTED`; every stat read comes before the commit, and a read that latches Fatal returns `HALTED` (Hero Rules 2 and 6, ADR-0010 Decision 3).
- TR-hero-012 was already revised on 2026-11-05 to ADR-0010's isolation proof; Hero AC 28 now reads the same.

Grading agrees with `architecture.md` v9 (118 full and 5 partial of 123), plus TR-state-015 as covered. Three rows whose ADR says "Full once" a sync lands are graded Covered, because each sync is on disk:
- TR-hero-012 (ADR-0010): Hero AC 28 is rewritten and the registry text revised.
- TR-enemy-015 (ADR-0011): the Enemy GDD's Reduce Motion line now reads "bob, jitter and lean stay on".
- TR-tower-015 (ADR-0011): the user confirmed the ADR-0010 `cooldown_full` amendment.

With ADR-0010 Accepted, the four rows the last review graded Partial (TR-input-014, TR-input-015, TR-tower-006, TR-hud-010) are now Covered (split).

The five Partial rows and who owns the rest:

| TR | Covered now | Rest owned by |
|---|---|---|
| TR-data-003 | ADR-0002 manifest, export filter, X1 | ADR-0002 X2, Android export proof (Technical Setup) |
| TR-data-015 | ADR-0002 small synchronous load | ADR-0002 P1, P2 device timings |
| TR-input-006 | ADR-0003 edge margin and safe-area insets | Mobile Platform GDD (does not exist; QQ-21) |
| TR-combat-013 | ADR-0009 Decision 8 split, P2 bench, shared-pass fallback | ADR-0009 P2 in a release export; ADR-0004 V13 on device |
| TR-hud-015 | ADR-0011 Decisions 6, 9, 10 | ADR-0011 M9a (desktop windowed), M9b (phone) |

None of the five waits on an unwritten ADR. Each rest is a device or GPU proof, or a GDD that does not exist yet.

The full matrix is in `docs/architecture/requirements-traceability.md`.

### Coverage Gaps (no ADR exists)
None.

### Cross-ADR Conflicts
Known conflict-prone areas: none recorded (`docs/consistency-failures.md` does not exist).

No 🔴 blocking conflict was found. The two conflicts the last review raised are closed. ADR-0003's S1 fail branch now points to ADR-0004 (both amended 2026-11-04). ADR-0009 Decision 8 splits the 2.0 ms tick, so stat reads (0.7 ms) and targeting (0.8 ms) add up inside one number. The frame budget sums (0.5 + 4.0 + 3.0 + 7.0 + 2.1 = 16.6 ms), the tick split sums to 2.0 ms and the draw-call split sums to 60.

Two non-blocking conflicts:

## Conflict: ADR-0010 Decision 7 (with ADR-0007 lint row L-HERO-1) vs ADR-0010 Decision 1 and ADR-0001 Decision 4
Type: Integration
ADR-0010 Decision 7 and ADR-0007's L-HERO-1 row claim: L-HERO-1 fails any `src/root/` file but `battle.gd` and `battle_builder.gd` that names `hero_sim` or `HeroSim`.
ADR-0010 Decision 1 and Key Interfaces, with ADR-0001 Decision 4, claim: only the wrapper builds the Inputs, and `HeroInput.setup(resolver, hero_sim, combat, ...)` takes the HeroSim. The wrapper also hands HeroSim to HeroView, HudLogic and RunMeasures. ADR-0007's scopes put the wrapper at `src/root/battle_wrapper.gd`.
Impact: the first wrapper story that builds HeroInput writes `battle.hero_sim`, and L-HERO-1 fails CI on a file the design needs. A story author may then work around the lint (pass `battle` whole, or read the member by string), which weakens the isolation proof the lint exists for.
Resolution options:
  1. A dated amendment to ADR-0010 and ADR-0007: add `src/root/battle_wrapper.gd` to L-HERO-1's exempt list. The wrapper runs no tick, so "`Battle.tick` reaches Hero only through `hero_sim.tick()`" still holds.
  2. Narrow L-HERO-1 in `src/root/` to a call on the token other than passing it on, so the wrapper's hand-off stays legal.

## Conflict: ADR-0011 Decision 10 vs ADR-0009 Decision 8 and the Enemy & Wave GDD (L12)
Type: Performance budget (design point)
ADR-0011 claims: the draw-call and P-V1 design point has 48 enemies, **6 towers**, 16 flashes and a burst firing.
ADR-0009 and the Enemy GDD claim: a stage has 3 to 5 slots (L12, starter value 5); ADR-0009's tick design point is 5 towers and the hero.
Impact: small. Six towers overstate the view load, so the budget errs safe. But P-V1, M9a and P2 then measure different scenes, and no content stage can hold the 6-tower fixture.
Resolution options:
  1. A dated amendment to ADR-0011: 5 towers and the hero, the same scene as ADR-0009's design point.
  2. Keep 6 and call it a stress case above the content cap, built on a test-only stage.

Same-ADR staleness found while checking (not conflicts between ADRs):
- ADR-0009 Decisions 4 and 7 still say each QQ-08 part is settled "pending the user's acceptance". Decision Makers records both accepted, and the Combat and Enemy GDDs say so.
- ADR-0010's 2026-11-05 amendment adds reads to "Decision 6's Combat row", but Decision 6's table has no Combat row (`architecture.md` B10 does). ADR-0010's TR-hero-012 row still says "Full only once" the AC 28 and TR syncs land; both have landed.
- ADR-0011's TR-enemy-015 and TR-tower-015 rows still say "Full once"; both conditions are met.
- ADR-0001 Decision Makers still says QQ-08's composition-root acceptance "also waits for the user"; the bullet above it records the sign-off.
- ADR-0005's GDD Requirements row for TR-hud-011 still paraphrases the old wording ("read through the accessor on arc open and `gold_changed`"); its "How" column has the current rule.
- Reverse edges: the Enables rows of ADR-0001, ADR-0005 and ADR-0006 do not list ADR-0010 or ADR-0011, which depend on them. ADR-0011's Depends On does not list ADR-0007, though ADR-0007's Enables row names ADR-0011 and ADR-0011 amends ADR-0007 (L-VIEW-1, L-VIEW-2, M9a, M9b). The graph script reads Depends On only, and the missing edge points to an earlier ADR, so the order below holds.
- ADR-0007's L-VIEW-1 and L-VIEW-2 scope reads "`src/presentation/field/`, battle HUD". "Battle HUD" names no folder, and ADR-0011 Decision 6 lets modal TapScreens use `Label`s. `scopes.gd` needs a HUD path that keeps ResultScreen and PausedScreen out, or L-VIEW-1 fails them.

### ADR Dependency Order
From `adr-dep-graph.sh`: 11 ADRs, 42 edges, no `CYCLE`, no `BLOCKED_BY_CYCLE`, no `NO_DEPS_SECTION`, no `UNFILLED_DEPS`. ADR-0001 states "None" outright. Every edge points to an Accepted ADR, so no ADR waits on a Proposed one. The `Depends on` column of `architecture.md`'s Required ADRs table matches each ADR's own row.

Recommended implementation order (as emitted):
Foundation (no dependencies):
  1. ADR-0001 App Lifecycle, Composition Root and Fatal Path
Depends on Foundation:
  2. ADR-0002 Catalogue Storage Format, Manifest and Validation (requires ADR-0001)
  3. ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle (requires ADR-0001)
  4. ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism (requires ADR-0001, ADR-0003)
  5. ADR-0005 Stat Accessor and Read-Context Contract (requires ADR-0001, ADR-0002, ADR-0004)
  6. ADR-0006 Battle Signal Contracts and View Allowlist (requires ADR-0001, ADR-0003, ADR-0004, ADR-0005)
  7. ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint (requires ADR-0001 to ADR-0006)
  8. ADR-0008 Input Resolver Core and Signal Contract (requires ADR-0001, ADR-0003, ADR-0004, ADR-0006, ADR-0007)
Core layer:
  9. ADR-0009 Enemy Entity, Roster and Combat API (requires ADR-0001, ADR-0002, ADR-0004, ADR-0005, ADR-0006, ADR-0007)
  10. ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry (requires ADR-0001, ADR-0004 to ADR-0009)
Presentation layer:
  11. ADR-0011 Battle Field Rendering and Draw-Call Budget (requires ADR-0001, ADR-0003 to ADR-0006, ADR-0009, ADR-0010)

### GDD Revision Flags
None. All GDD assumptions are consistent with verified engine behaviour. Grep found no GDD that relies on `_physics_process`, a shader, `Tween`, a `Label` in the battle HUD, particles or `draw_polyline` for the path. The Enemy GDD's old `draw_polyline` note now points to ADR-0011's baked polygon (probe R4); the Combat GDD's hit-flash shader question is answered (QQ-10). Systems index left unchanged.

Design-document sync items found on the way (not engine conflicts, so not revision flags; this review edits no GDD or UX file):
- `design/ux/interaction-patterns.md` IP-23 Implementation Notes say "the retry latch sits in Flow". ADR-0001 Decision 5, TR-state-009 and TR-hud-006 put it on the app root (`request_retry()`). A story built from IP-23 would put it in the wrong place.
- `design/ux/interaction-patterns.md` IP-21 ("Proposed; needs an ADR"), its Implementation Notes ("once the amendment lands") and OI-10 ("ADR-0003 amendment still owed") are stale: ADR-0003 took the `arm_ms` amendment, confirmed by the user at ADR-0009 acceptance.
- `design/gdd/systems-index.md` (Combat & Damage note) says the ProjectileSpawner cut is "pending technical-director confirmation"; the user accepted it with ADR-0009 Decision 7.

### Engine Compatibility Issues

### Engine Audit Results
Engine: Godot 4.7.2 (installed 4.7.2.stable.official.ed1daf0bf matches the pin, `VERSION.md`)
ADRs with Engine Compatibility section: 11 / 11 total

Deprecated API References: none in use. Every hit for a `deprecated-apis.md` name is a ban, a lint rule or a "not used" note. One watch item: `deprecated-apis.md` and `breaking-changes.md` say `Control.accessibility_live` takes `AccessibilityServer.AccessibilityLiveMode` in 4.7, not the old `DisplayServer.AccessibilityLiveMode`. ADR-0011 (Decision 6, Post-Cutoff APIs Used) uses `accessibility_live` but names no enum, and probe R18 checked only that the property exists. The HudTopBand story should use the `AccessibilityServer` form. LOW.

Stale Version References: none. All eleven ADRs target 4.7.2. Stale verification fields:
  - ADR-0011 Verification Required says "R1 to R20 verified 4.7.2 headless", but its probe table and `probe-results.md` record no result for R8 to R12 or R19 (`probe-results.md` says so in its ADR-0011 note). Six probe IDs are claimed and not recorded.
  - ADR-0009 Last Verified names `architecture.md` v6; ADR-0010 and ADR-0011 name v7. The document is now v9. The later versions only synced text to these ADRs, so nothing they decide moved.

Post-Cutoff API Conflicts: none. Post-cutoff features in use: `@abstract` (ADR-0005, ADR-0007); rest parameters in fakes (ADR-0006, ADR-0007, ADR-0008); 4.7 typed-return overrides (all; ADR-0009 states the H4 rule that `return null` fails in an `-> int` override, which matches the corrected `breaking-changes.md` row); the 4.7 `device == 0` ban, stretch defaults, 4.6 dual focus and 4.5 recursive mouse disable (ADR-0003); `FileAccess.store_line() -> bool` (4.4, ADR-0010); `draw_circle` with `filled`, `width`, `antialiased` (4.4) and AccessKit on `Control` (4.5, ADR-0011); and the 4.7 removal of the line feather (ADR-0011 passes width 2.0 or more). No two ADRs assume different behaviour for the same API.

Probe record (`probe-results.md`): ADR-0009 B1 to B4 and X1 to X7, ADR-0010 T1 to T7, R1 to R9 and K, and ADR-0011 R1 to R7, R13 to R18 and R20 are verified 4.7.2 headless, and all match. Not run: ADR-0009 P2 (release export), ADR-0010 M2 and M4 (phone, release export), ADR-0011 M9a, M9b, F1 and M3 (need a GPU).

Open engine risks (not run):
  - **gdUnit4 on 4.7.2 is unproven.** ADR-0007 H1, H2, H3, H6 and H9 still need gdUnit4, and gdUnit4 6.2.x lists Godot up to 4.7.1. The CI command and every Logic story rest on it. HIGH for the CI story.
  - **Desktop benches already point to the fallbacks.** ADR-0011 says debug P-V1 runs about 0.5 to 0.8 ms against a 0.2 ms trigger, so F1 (MultiMesh) is "the likely path", and F1's per-instance layout is unverified. ADR-0009 says debug targeting near 0.13 ms will "likely fire" P2's 0.053 ms trigger. Both ADRs run the release export first and name a ready fallback. MEDIUM.
  - **ADR-0003 behaviour checks.** S1 to S8 and the TapScreen check are not run (they need a person or a device). The Input, UI and display, and app lifecycle rows stay HIGH.
  - **Device-only checks**: ADR-0001 V8; ADR-0002 X1, X2, P1, P2; ADR-0004 V13; ADR-0005 P1 device run; ADR-0009 P2 release; ADR-0010 M2, M4; ADR-0011 M9a, M9b.
  - ADR-0003's S1 spike sets `physics_ticks_per_second` 240 and `max_fps` 30. It must run in a throwaway project, since ADR-0004 Guideline 11 pins 60 and L-PROJ-1 fails any other value in the repo.

### Engine Specialist Findings
**Engine specialist consultation: NOT RUN in this pass.** Phase 5 asks for a `godot-specialist` second opinion over every ADR with engine decisions, the engine reference and this audit. This reviewer could not start subagents, so the consultation did not happen. The engine findings above rest only on the ADRs' Engine Compatibility sections and on `docs/engine-reference/godot/probe-results.md` (verified on the official 4.7.2 Linux build, headless). ADR-0009, ADR-0010 and ADR-0011 each record their own godot-specialist review at authoring (CONCERNS, APPROVE, CONCERNS; findings applied), but no specialist has reviewed the eleven ADRs together. This is not a pass. Run the consultation before `/gate-check pre-production`. Questions to put to it: whether L-VIEW-1's `Label` ban should reach modal TapScreens; whether `HudTopBand`, a `Control` child of the `FieldViews` `Node2D`, lays out and batches as ADR-0011 expects; and the `AccessibilityServer` enum above.

### Architecture Document Coverage
`docs/architecture/architecture.md` v9 (2026-11-05) checked against the 8 GDDs and the systems index.

**Clean:**
- All 22 systems in the systems index appear in the System-to-layer table; the 14 without a GDD are reserved slots with named seams. Battle HUD lists its four pieces, RangeRingView included. No orphaned architecture.
- Data Flows 1 to 10 cover every cross-system route the GDDs define. Data Flow 9 names RunMeasures, RunLog, GestureLog and `JsonlFileSink`. Data Flow 10 carries the frame, tick and draw-call splits, and each sums.
- B10 has the Combat row (`hp_left`, `is_dead`, `speed_factor`, `hp_ratio`) and `SlotState.cooldown_full`; B6 has `hp_ratio`; B5 has Flow's result enums (QQ-18 resolved).
- The Required ADRs table's `Depends on` column matches each ADR's own row, and its TR column sums to 123. QQ-10 and QQ-18 are closed; QQ-03, QQ-11, QQ-12, QQ-14 and QQ-21 stay open with named owners.

**Stale (fix in a v10 sync; this review edits nothing in it):**
1. **Counts.** 123 requirements and "118 full, 5 partial" become 124 and 119 covered, 5 partial, 0 gaps with TR-state-015 (Document Status, Traceability Coverage Check, and the Required ADRs row for ADR-0010, where 10 becomes 11). The Traceability Coverage Check still says the index and the latest review "show the v6 counts"; this review brings both up to date.
2. **TR-hud-001 text** in the baseline follows the registry revision above.
3. **Review state line** says "v3 to v7 have not had their review"; it is now v3 to v9.
4. **ADR Quality Check** says "All eight carry dated amendments" and its "Still open" list leaves out ADR-0010 M2 and M4.
5. **Review state.** TD-ARCHITECTURE and LP-FEASIBILITY have not re-reviewed the document since v2.

**Context (advisory):** five of the eight GDDs are not Approved in the systems index (Data & Config In Review, Input In Review, Game State Designed, Tower In Review, Battle HUD Designed). The ADRs trace to their current text; a later GDD change goes through `/propagate-design-change`.

---

### Verdict: CONCERNS

Every one of the 124 requirements has an Accepted ADR: 119 are covered and 5 are partly covered, with no gap and none resting on a Proposed ADR. All eleven ADRs are Accepted, the dependency graph has no cycle, and no blocking conflict was found. That clears FAIL.

It is not PASS, for four reasons:
- Five requirements are only partly covered (three Foundation, one Core, one Presentation). Each rest is a device or GPU proof, or the Mobile Platform GDD.
- Two non-blocking conflicts: L-HERO-1 against the wrapper, and ADR-0011's 6-tower design point.
- The godot-specialist consultation did not run in this pass.
- gdUnit4 on 4.7.2 is unproven, and the desktop benches already point to both named performance fallbacks.

### Blocking Issues (must resolve before PASS)
The verdict is CONCERNS, not FAIL, so nothing here blocks under this skill's rule. These must be resolved before a PASS:
1. Run the godot-specialist consultation over all eleven ADRs and `probe-results.md` (not run in this pass).
2. Close the five Partial rows: ADR-0002 X2, P1, P2; the Mobile Platform GDD for TR-input-006 (QQ-21); ADR-0009 P2 release run and ADR-0004 V13; ADR-0011 M9a and M9b.
3. A dated amendment to ADR-0010 and ADR-0007: exempt `src/root/battle_wrapper.gd` from L-HERO-1, or narrow the rule (Conflict 1).

### Should fix (not blocking)
4. A dated amendment to ADR-0011: one design point with ADR-0009 (5 towers and the hero), or call the 6-tower case a stress fixture (Conflict 2). Record R8 to R12 and R19, or drop them from "R1 to R20". Add ADR-0007 to Depends On.
5. Stale text: ADR-0009 Decisions 4 and 7 ("pending the user's acceptance"); ADR-0010's amendment against its Decision 6 table (no Combat row) and its TR-hero-012 row; ADR-0011's "Full once" rows; ADR-0001 Decision Makers; ADR-0005's TR-hud-011 paraphrase.
6. Give L-VIEW-1's "battle HUD" scope a folder path in `scopes.gd` that keeps the modal TapScreens out.
7. Fix `interaction-patterns.md` IP-23 (the retry latch is on the app root, not Flow) and the stale IP-21 and OI-10 notes; fix the systems index's ProjectileSpawner note.
8. Prove gdUnit4 on 4.7.2 (ADR-0007 H1, H2) in the CI story before the first Logic story.
9. Sync `architecture.md` to v10 (Architecture Document Coverage items 1 to 4), and have TD-ARCHITECTURE re-review it.

### Required ADRs
None. The eleven Accepted ADRs cover every registered requirement. The fixes above are dated amendments to existing ADRs, not new ADRs.

---

### Handoff
**Immediate actions** (no ADR gap remains, so these are the top three follow-ups, not new ADRs):
1. Run the godot-specialist consultation over ADR-0001 to ADR-0011 and `probe-results.md`.
2. A dated amendment to ADR-0010 and ADR-0007 for L-HERO-1 and the wrapper (`/architecture-decision`).
3. A dated amendment to ADR-0011 for the design point, the unrecorded probe IDs and Depends On.

**Pre-gate checklist:**
- ✅ `tests/unit/` and `tests/integration/` (both exist; each holds only a placeholder file)
- ✅ `.github/workflows/tests.yml`
- ✅ `design/accessibility-requirements.md`
- ✅ `design/ux/interaction-patterns.md`

All four pre-gate items exist, and no blocking ADR gap remains, so `/gate-check pre-production` is open. The CONCERNS above will reach that gate, the unrun specialist consultation first among them. Re-run `/architecture-review` after each amendment to check that the findings close.
