## Architecture Review Report

**Summary.** Verdict: **CONCERNS**. The eleven ADRs (ADR-0001 to ADR-0011) cite all 120 registered requirements, and checking each claim against the GDD text holds up well: of 158 requirements (120 registered plus 38 found in this review), 145 are fully addressed, 11 partly and 2 not at all. No requirement is covered by an Accepted ADR, because all eleven are still Proposed, so the verdict cannot pass. The one Foundation-layer gap (TR-data-021, save-data ID stability) is Vertical Slice scope by the GDD's own terms, so no MVP requirement in the Foundation or Core layers lacks an ADR. The ADR-0006 and ADR-0008 dependency cycle is a one-line text fix (ADR-0006 already marks that link "binding, not gating"), and the other nine cross-ADR conflicts are small interface or wording mismatches. The largest open risks are the engine items that no ADR decides or verifies: the renderer choice on the target phone, 2D batching behind the draw-call budget, and the platform order (iPhone first versus Android first). `architecture.md` is out of date: it still says no ADRs exist. Files changed: `docs/architecture/architecture-review-2026-11-05.md` (this report, new); `docs/architecture/requirements-traceability.md` (rebuilt: 158 rows); `docs/architecture/tr-registry.yaml` (38 new IDs, 11 entries reworded, version 3); `design/gdd/systems-index.md` (six GDDs set to Needs Revision). No ADR was edited and none was set to Accepted.

Date: 2026-11-05
Mode: full
Workflow: full
Engine: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D)
GDDs Reviewed: 8 (systems index, game concept and the 2026-11-03 cross-review read for context only)
ADRs Reviewed: 11 (plus the companion `adr-0007-lint-rules.md`)

Reviewed-Content-Hash: docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md 7ad85d5eccae4c2bc0b4fdcbcdc3276e79059ea5
Reviewed-Content-Hash: docs/architecture/adr-0002-catalogue-storage-format-manifest-validation.md 1a77102bd84fde6a26e357bdd545f0f5addeb075
Reviewed-Content-Hash: docs/architecture/adr-0003-input-adapter-display-stretch-platform-lifecycle.md 56636606fe33faf4fd049cdc236c27a5537ce94f
Reviewed-Content-Hash: docs/architecture/adr-0004-fixed-tick-clock-tick-order-determinism.md 14f92314f37e55326205ddddab4d5699bac2f855
Reviewed-Content-Hash: docs/architecture/adr-0005-stat-accessor-read-context-contract.md bd1b51f140efe978eac11578d957e36abfed15f5
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-signal-contracts-view-allowlist.md 3d4431813acd215602559309dd192cb57cbbf49f
Reviewed-Content-Hash: docs/architecture/adr-0007-headless-test-harness-gdunit4-layer-lint.md 13c84a2cd043882bec71ea61dbb7264d599f0bb9
Reviewed-Content-Hash: docs/architecture/adr-0007-lint-rules.md 54ae6431b42931cfcd3f56e5d7933fcd6267550b
Reviewed-Content-Hash: docs/architecture/adr-0008-input-resolver-core-signal-contract.md 0bf4d31830082cc542d2e3837ef1f4668a6a9b44
Reviewed-Content-Hash: docs/architecture/adr-0009-enemy-entity-roster-combat-api.md 317f7f6baed13eeb820a20e2fb4e4d395113cb48
Reviewed-Content-Hash: docs/architecture/adr-0010-sim-input-split-command-result-codes-dev-telemetry.md 0d56dc01f42af2c746428bd1bb3734c44d541505
Reviewed-Content-Hash: docs/architecture/adr-0011-battle-field-rendering-draw-call-budget.md e3c8eadcb25a5c432834e386348d6b4a7fce9b37
Reviewed-Content-Hash: design/gdd/battle-hud.md df8cde9a193c17d881ef8ba5300387a9439c3a4a
Reviewed-Content-Hash: design/gdd/combat-damage.md 58e61e5cdc65f77a3bd4ff4c924f57aaa4ac1cd2
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 7af99426b787d2bb3b07acc6467439382a3d50b7
Reviewed-Content-Hash: design/gdd/enemy-wave.md ee2012fb05114169ee133bd3ede5e08664df9734
Reviewed-Content-Hash: design/gdd/game-concept.md 69276bc59133ed1fc4125a561b829e3bd7eb4156
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 9916bcb8fed6a453e684757ad8c699a417c63bee
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md 715aaf91204dc9bd493071f2678a97fd6eb13f41
Reviewed-Content-Hash: design/gdd/hero-system.md 1583706c010da299b7423a89ab8f655da4fa0be3
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md cda4c3b792830207e4c3c6ce11b1e6be7acad94f
Reviewed-Content-Hash: design/gdd/systems-index.md d285f81e739fc544606cef466592f8f6724d922e
Reviewed-Content-Hash: design/gdd/tower-system.md df36809d86c28272f1536d52f45f3279601a81a6
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 223c5965cd3d9b083804e0cfd4a024dd78403577
Reviewed-Content-Hash: docs/architecture/architecture.md d47205569ade462970dbad8f6d6f73059e400940
Reviewed-Content-Hash: docs/engine-reference/godot/VERSION.md fcf85779788e0facbeca26aeda9fd41955e2633e
Reviewed-Content-Hash: docs/engine-reference/godot/breaking-changes.md 4bc55e16796664ff88c7582c9f08e3530f7c94d4
Reviewed-Content-Hash: docs/engine-reference/godot/current-best-practices.md a45cd2c39a8ec53eaa3e924f39f93594e62085fd
Reviewed-Content-Hash: docs/engine-reference/godot/deprecated-apis.md 6a1353983e1db0d7bc0cc41a568b039495b5413c
Reviewed-Content-Hash: docs/engine-reference/godot/verification-results.md 059f24025605814134396f7fc43fdb4308fd56e0
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

### Freshness check

The prior report (`architecture-review-2026-11-03.md`, full, workflow full) reviewed 0 ADRs. Since then all 11 ADRs, `architecture.md` and `engine-reference/godot/verification-results.md` are NEW, and all 8 GDDs and the systems index CHANGED. Full re-run.

### Traceability Summary

Total requirements: 158 (120 registered before this review, 38 registered by it)
✅ Covered by an Accepted ADR: 0
🟡 Covered (Proposed): 145
⚠️ Partial: 11
❌ Gaps: 2

| System | Main layer | Registered | New | 🟡 | ⚠️ | ❌ |
|---|---|---|---|---|---|---|
| Data & Config | Foundation | 15 | 6 | 18 | 2 | 1 |
| Game State & Stage Flow | Foundation | 14 | 5 | 16 | 3 | 0 |
| Input & Gesture Resolver | Foundation | 16 | 5 | 20 | 1 | 0 |
| Combat & Damage | Core | 14 | 3 | 16 | 1 | 0 |
| Enemy & Wave | Core | 15 | 5 | 20 | 0 | 0 |
| Tower System | Core | 15 | 4 | 19 | 0 | 0 |
| Hero System | Core | 15 | 5 | 19 | 1 | 0 |
| Battle HUD | Presentation | 16 | 5 | 17 | 3 | 1 |

Layer is set per requirement; the full matrix, with each row's layer, is in `docs/architecture/requirements-traceability.md`.

**How claims were checked.** For every requirement, the cited ADR Decision text was read against the GDD's current wording. Claims that cite the wrong decision but are covered elsewhere were rated by the real source and noted: TR-data-006 and TR-data-009 (also ADR-0002 D2 and ADR-0005), TR-state-006 (ADR-0006 D6), TR-enemy-012 (ADR-0009 D7), TR-hero-010 and TR-tower-011 (binding text is ADR-0010 D8; ADR-0008 D9 says it is non-binding), TR-hero-013 (ADR-0006 G7).

### Partial coverage

| TR-ID | What is missing |
|---|---|
| TR-data-003 | Android export clause unproven: ADR-0002 W2 moved to an iPhone export and defers the Android leg. |
| TR-data-015 | No decision sets the 1000 ms load budget; W4 is advisory and its Adreno leg is deferred. |
| TR-state-003 | "No physics areas" appears only in ADR-0004 Constraints; no decision, guideline or lint rule bans Area2D or physics queries. |
| TR-state-013 | No decided seam for injecting recording fake systems into the tick slots (Game State Acceptance 9 and 13); ADR-0007 D5 says "No new Battle API" and ADR-0004 D4 fixes the six steps. |
| TR-state-018 (new) | Wrong-phase wave events go to a dev-error sink, but no ADR assigns the check to Flow. |
| TR-input-005 | Mouse index 1000 only if spike SP5 can tell emulated mouse from touch by `device`; otherwise mouse and touch 0 share index 0. |
| TR-combat-013 | The ADRs replace the GDD's 2 ms targeting budget with a whole-tick budget (4.0 / N ms); the GDD now states 2 ms only as an Open Question. |
| TR-hero-004 | ADR-0001 D5 gives the mechanism but no Hero or Burst IDs; the real path is ADR-0010 D7, D8. Registry text reworded to match. |
| TR-hud-010 | No ADR gives the HUD the stage's Wave records; HudLogic is not a listener of `burst_started` (ADR-0006 P7) although HUD Rule 13 waits on it. |
| TR-hud-013 | Run log needs damage by source and kind, but ADR-0010 D11's `ResultSnapshot` holds only per-kind totals. |
| TR-hud-018 (new) | `burst_button_centre` is read once at attach (ADR-0010 D8) while insets can move the button mid-battle (ADR-0003 D5). |

### Coverage Gaps (no ADR exists)

❌ TR-data-021: data-config-pipeline.md → Data & Config → record IDs are never changed or reused; retired-ID list at Vertical Slice for Save/Load.
   Suggested ADR: "/architecture-decision save-data ID stability and migration" (at Vertical Slice, with Save/Load)
   Domain: Persistence
   Engine Risk: LOW

❌ TR-hud-017: battle-hud.md → Battle HUD → HudLogic reads the stage's Wave records directly to draw the next-wave line.
   Suggested fix: amend ADR-0005 D8 or ADR-0010 D7 (read-only `Battle.wave_records` or an EnemyWave view query); no new ADR needed.
   Domain: Cross-system communication
   Engine Risk: LOW

### Cross-ADR Conflicts

Ten found, all checked by reading both texts. No data-ownership or state-authority conflict; performance budgets fit (ADR-0004 D10 slices total 16.6 of 16.67 ms; draw calls 34 + 26 engine = 60).

**Conflict: ADR-0006 vs ADR-0008** (dependency cycle; must fix before either is accepted)
ADR-0006 Depends On lists "ADR-0008 (`battle.resolver`)" under "binding, not gating". ADR-0008 Depends On needs ADR-0006's signal table, which it copies exactly. The real edge is ADR-0008 → ADR-0006; ADR-0006 needs only the member name, which ADR-0001 D5 step 2 already creates. `adr-dep-graph.sh` counts every ADR number on the row, so it reports a cycle and blocks ADR-0007, ADR-0010 and ADR-0011.
Resolution: in ADR-0006's Depends On cell, replace "ADR-0003 (`lifecycle_paused`, `display_changed`), ADR-0008 (`battle.resolver`), ADR-0009 (...)" with "ADR-0003 (`lifecycle_paused`, `display_changed`), ADR-0009 (Combat and EnemyWave signal declarations). The emitter `battle.resolver` is the member ADR-0001 Decision 5 step 2 creates." The new text must not name ADR-0008. Checked on a scratch copy: the cycle goes away.
Same pattern, smaller: ADR-0008's "ADR-0005 is not used" makes a false 0008 → 0005 edge; say "The stat accessor is not used".

**Minor conflicts**

| ADRs | Type | Conflict | Recommended fix |
|---|---|---|---|
| 0009 vs 0011 | Integration | Damaged-core view gets `max_hp` from stored Health (0009 D3) or from up to 48 accessor reads a frame (0011 D3). | Add `max_hp_of(t)` to Combat's read surface; ADR-0011 uses it. |
| 0005 vs 0008, 0010 | Integration | ADR-0005 D8 passes the `InputRecord` to the resolver and HeroSim; ADR-0008 and ADR-0010 take plain values. | Amend ADR-0005 D8. |
| 0005 vs 0010 | Integration | ADR-0005 D7: Builder injects the Burst ID into the HUD; ADR-0010 D7: HUD asks `hero_sim.burst_id()`. | Amend ADR-0005 D7. |
| 0004 vs 0007 lint | Pattern | ADR-0004 D7 allows a view's own `RandomNumberGenerator`; lint MATH-4 bans it in presentation. | Narrow MATH-4, or drop the RNG option from ADR-0004 D7. |
| 0004 vs 0010 | Pattern | ADR-0004 bans `Time.*` outside named places; ADR-0010 D10 reads it in `dev_logs.gd` (lint already allows it). | Add the exception to ADR-0004 and to ADR-0010's Amends row. |
| 0007 vs 0010 | Pattern | ADR-0007 D9 calls the between-ticks check development-only; ADR-0010 D2 runs it in every build. | Update ADR-0007's table row. |
| 0008 vs 0010 | Init order | GestureLog made in every debug build (0008 D8) versus only when `dev_logs` is non-null (0010 D10). | Amend ADR-0008 D8. |
| 0010 vs 0011 | Ownership | ADR-0011 D10 says `DevLogs` creates the dev overlay; ADR-0010 has the wrapper's `attach` create such nodes. | Amend ADR-0011 D10. |
| 0003 vs 0001, 0009 | Pattern | Adapter's 360 dp warning uses `push_error`; ADR-0001 requires `dev_error`, and ADR-0009's exception covers Combat only. | Inject `dev_error` into `InputAdapter.attach`. |

Wording risks noted but not counted: ADR-0011 D3 "frees" StageLook (ADR-0001 bans `free()`); ADR-0001 D7 calls Retry "a HUD button" while ADR-0003 D8 bans `Button` types; ADR-0001 D7 step 3 calls `resolver.cancel()` where ADR-0003 D9 routes retry through `cancel_input()`.

### ADR Dependency Order

Script output (`adr-dep-graph.sh`), current text:
- ORDER: ADR-0001, ADR-0002, ADR-0005, ADR-0003, ADR-0009, ADR-0004
- 🔴 DEPENDENCY CYCLE: ADR-0006 → ADR-0008 → ADR-0006 (cut the ADR-0006 → ADR-0008 edge, above)
- BLOCKED_BY_CYCLE: ADR-0007, ADR-0010, ADR-0011
- NO_DEPS_SECTION: adr-0007. False report: the companion `adr-0007-lint-rules.md` shares the prefix and has no dependencies section; it also makes the script count 12 ADRs. Either move the companion out of the glob or have the script skip files whose first line is not an `# ADR-NNNN:` title.

Order once the cycle edit is made (checked on a scratch copy):

Foundation (no dependencies):
1. ADR-0001: App Lifecycle, Composition Root and Fatal Path

Depends on Foundation:
2. ADR-0002: Catalogue Storage Format, Manifest and Validation (requires 0001)
3. ADR-0005: Stat Accessor and Read-Context Contract (requires 0001, 0002)
4. ADR-0003: Input Adapter, Display Stretch and Platform Lifecycle (requires 0001, 0005)
5. ADR-0009: Enemy Entity, Roster and Combat API (requires 0001, 0002, 0005)
6. ADR-0004: Fixed-Tick Clock, Tick Order, Frame Order and Determinism (requires 0001, 0003, 0005, 0009)

Feature layer:
7. ADR-0006: Battle Signal Contracts and View Allowlist (requires 0001, 0002, 0003, 0004, 0009)
8. ADR-0007: Headless Test Harness, gdUnit4 and Layer Lint (requires 0001, 0006)
9. ADR-0008: Input Resolver Core and Signal Contract (requires 0001 to 0006, 0009)
10. ADR-0010: Sim/Input Split, Command Result Codes and Dev Telemetry (requires 0001, 0002, 0004 to 0009)
11. ADR-0011: Battle Field Rendering and Draw-Call Budget (requires 0001, 0003 to 0007, 0009, 0010)

⚠️ Every ADR depends only on ADRs that are still Proposed. None can be safely implemented until the ADRs before it in this order are Accepted. ADR-0007 D2 says its own acceptance needs only ADR-0001; to let the tool honour that, move ADR-0006 from its Depends On row to its Ordering Note.

### GDD Revision Flags

These GDD rules conflict with an ADR decision or with the engine audit. Six GDDs are set to `Needs Revision` in the systems index. Combat & Damage and Tower System only have stale open questions and wording, so they keep their status; their items are listed after the table.

| GDD | Assumption | Reality (from ADR or engine reference) | Action |
|---|---|---|---|
| data-config-pipeline.md | Edge Case l.157 "a property no record type declares" | ADR-0002 D4 checks per record type; Rule 7 already updated | Fix the edge case wording |
| data-config-pipeline.md | Layout rules belong to the CI content test; art-bible ranges at Vertical Slice | ADR-0002 D3, D4 make path drawability boot-fatal; ADR-0002 D8 and ADR-0011 D3 check art-bible ranges at MVP | Add the checks and the stage-start fatal cause to the GDD, or narrow the ADRs |
| data-config-pipeline.md | Acceptance 15 on an Adreno 5xx device; Android export | ADR-0002 W2, W4 run on iPhone first, Android deferred; renderer on Adreno unverified (engine E1) | Platform decision for the user (see Required ADRs) |
| game-state-stage-flow.md | Stage table has no Fatal row; accumulator "zeroed" (Rule 17); identical result promise unqualified (Rule 5) | ADR-0001 D3 and ADR-0006 make Fatal a Flow phase; ADR-0004 D2, D3 reset to half a tick on entry and exit; ADR-0004 D9 promises per CPU architecture and engine build | Add the Fatal row, fix wording; add an edge case that pause may land on resume on some platforms (ADR-0003 SP10) |
| input-gesture-resolver.md | l.127 and l.274: top-band Controls consume their own events | ADR-0003 D8: every non-modal battle Control ignores input | Say "the modal Result and Paused Controls" |
| input-gesture-resolver.md | Rule 12 rejects presses in "gesture insets" | ADR-0003 D5: Godot has no gesture-exclusion API; only the safe area and `edge_reject_margin` | Drop "gesture insets" or source them |
| input-gesture-resolver.md | Inputs are only the five calls, registrations and one record; playtest P1 on Android | ADR-0008 D2, D7 add `dev_error`, `recover_if_stuck()` and a 64-call cap; iPhone is the first phone | List them; move P1 to the iPhone or mark Android deferred |
| enemy-wave.md | Rule 11: `enemy_killed` fires, then the corpse is removed | ADR-0009 D7 and ADR-0006 W2 remove first, then emit; Combat Rule 4 agrees with the ADRs | Fix Rule 11 order |
| enemy-wave.md | Formulas l.183: `to_ticks` as `sign(x) * floor(abs(x) + 0.5)` citing ADR-0004 | ADR-0004 D6 uses `floori(absf(x) + 0.5)`; D9 bans `sign`, `floor`, `abs` in sim code | Cite the ADR form |
| enemy-wave.md | Inset ranges 0 to 48 dp bottom, 0 to 68 dp top; layout rule L6 has zero margin | Real iPhone insets and safe-area units unmeasured (engine E3, ADR-0003 SP8) | Recheck L3, L5 to L7 after SP8 |
| hero-system.md | Rule 14 and Acceptance 14: `PinGeometry.clamp`, `is_valid(point, rect, shapes)` | ADR-0010: `is_valid(x, y)`, `clamp_point(fx, fy, hold_x, hold_y)`, "not clamp()" | Rename and re-sign |
| hero-system.md | Rule 16: `best_victims` in development builds only; Rule 2: builder injects into HeroInput and HUD | ADR-0010 D7 computes it in every build; wrapper and a `burst_id()` query carry the values | Fix wording |
| hero-system.md | Balance sim: hero does not walk and telegraph waits in Intermission | ADR-0004 D4 runs every step in Intermission | Re-run the bot evidence (hero share 25.1%, 0.1 above its floor) with the real tick order |
| battle-hud.md | Rule 2: modal screens consume every event before the adapter | ADR-0003 D2 reads moves and releases of held presses in `_input`; a held drag is ended by `cancel_input`, not by the modal | Reword to "modals take new presses" |
| battle-hud.md | Rule 13 waits on `burst_started`; Rule 19 logs damage by source | ADR-0006 P7 has no HudLogic listener; ADR-0010 D11 has no per-source field | Fix the ADRs (see Partial), or reword the GDD to poll `bursts_fired` |
| battle-hud.md | Draw budget 8 (max 12) of 60 calls, one per text size | 2D batching of `_draw` polygons on the Mobile renderer is unsourced (engine E2) | Mark the budget provisional until ADR-0011 V1, V2 |

Not flagged, for the record: combat-damage.md still asks the technical director to confirm the ProjectileSpawner cut and tick order (decided by ADR-0009 D8 and ADR-0004 D4), Rule 10 omits that helpers also skip removed enemies, and the 2 ms targeting figure differs from the ADR budget. tower-system.md still lists `tower_id` type and the input split as open (decided by ADR-0006 D4 and ADR-0010), and its header date was not bumped.

### Engine Compatibility Issues

Engine: Godot 4.7.2 (installed 4.7.2 matches the pin)
ADRs with Engine Compatibility section: 11 / 11 (the lint companion needs none)
Deprecated API references: none (mentions are bans, citations or rejected alternatives)
Stale version references: none. ADR-0007 vendors gdUnit4 6.2.0 while the reference saw 6.2.2 run on 4.7.2 (MEDIUM; ADR-0007 V1 already covers an upgrade).
Post-cutoff API conflicts: none between ADRs. ADR-0003 SP5 logs `DEVICE_ID_EMULATION`, which the reference docs do not list; treat as unverified until SP5 runs.
Verification state: `verification-results.md` Run 1 (2026-11-04, macOS arm64) has 186 results, 2 FAIL (ADR-0009 V7; covered by lint INIT-1). All phone legs and several desktop spikes are still open.

#### Engine Specialist Findings

| # | Finding | ADR | Risk | Basis |
|---|---|---|---|---|
| E1 | No ADR decides the renderer. Mobile (RenderingDevice) on Adreno 5xx is a known trouble spot and may fall back to Compatibility on Android, which changes the batching ADR-0011 measures. With iPhone first, the Android risk will not surface early. | 0011, project.yaml | HIGH | judgment |
| E2 | ADR-0011's draw-call estimate (about 1 per drawer) assumes 2D batching that may not cover circles, arcs and lines; 48 enemies with keylines could pass the 60-call trigger. Treat the triangle-array fallback as the likely path and prototype both in V2. | 0011 D9 | HIGH | judgment |
| E3 | Safe-area units (pixels or points) and edge-to-edge behaviour on iOS are unsourced. | 0003 D5, SP8 | HIGH | judgment |
| E4 | Which lifecycle notifications fire on iOS, and in what order, is unsourced; the design (any trigger pauses, never auto-resume) tolerates it. | 0003 D6, SP10 | HIGH | judgment |
| E5 | Whether `_gui_input` receives touch events directly is unsourced; branches are specified. | 0003 D2, D3, D8 | HIGH | judgment |
| E7 | A 60 Hz sim without interpolation judders on 120 Hz iPhones. Pull ADR-0004 V3 forward or cap at 60 fps. | 0004 | MEDIUM | judgment |
| E8 | `commands.smoke` uses `--quit-after`, which exits 0 on a parse error, so it is not a smoke check. | project.yaml | MEDIUM | verified; fixed 2026-11-05 (user yes): smoke now parse-checks src first |
| E9 | `commands.test` fails on a fresh clone unless the project is imported first; first import can crash (exit 139). | project.yaml, 0007 | MEDIUM | verified; fixed 2026-11-05 (user yes): test imports first |
| E16 | Mobile renderer compiles canvas pipelines on first draw; consider Shader Baker for the iOS export. | 0011 | LOW | judgment |

Confirmed sound: ticking in `_process` with an accumulator (ADR-0004), explicit stretch keys (ADR-0003), method Callables only (ADR-0001, ADR-0006; verified in Run 1), gdUnit4 headless command and exit codes (ADR-0007).

### Architecture Document Coverage

- Missing systems: none. All 22 systems in the index appear in the layer table; the 14 Vertical Slice and Alpha systems sit in reserved slots.
- Stale statements versus the ADRs (the main problem): Document Status, ADR Quality Check and the coverage table still say no ADRs exist and 0 of 120 covered. The catalogue format text ("Resource or JSON", `duplicate_deep()`) contradicts ADR-0002 (JSON and typed RefCounted records). Reduce Motion location and `queue_free()` are still listed as open (settled by ADR-0001). The B4 sketch uses `seed` (now `rng_seed`). The accumulator is "zeroed" (ADR-0004: half a tick). Tower and hero signal listeners disagree with ADR-0006, ADR-0010 and ADR-0011, and the HUD's `burst_started` dependency has no listener in ADR-0006.
- API boundary gaps: the Battle sketch lacks members the ADRs add (`resolver`, `combat`, `stat_accessor`, `input_record`, `stage_record`, `visual_keys`), and how hero and burst IDs reach their users is undefined there.
- Layering: Save/Load sits in Foundation but loads state into Feature-layer progression systems, which breaks the document's own "no upward dependency" rule (Vertical Slice concern).
- Orphaned architecture: none.
- Baseline: no standalone Technical Requirements Baseline with provisional IDs, only a count; all 120 IDs match the registry.

Action: update `architecture.md` to the ADR set (status, coverage, the items above).

---

### Verdict: CONCERNS

- No requirement rests on an Accepted ADR: all 145 covered rows rest on Proposed ADRs. Route out: `/architecture-decision accept ADR-NNNN`, in the order above.
- 11 partial and 2 gap rows. TR-hud-017 is Presentation. TR-data-021 is Foundation but Vertical Slice scope (the GDD defers the retired-ID list to Save/Load), so it is not counted as a critical MVP gap; if the project treats it as MVP, the verdict becomes FAIL until an ADR covers it.
- The ADR-0006 and ADR-0008 cycle is reported, not counted as blocking: ADR-0006's own text marks the link "binding, not gating", the gating edges alone form no cycle, and one sentence fixes it. It must be fixed before either ADR is accepted.
- Nine minor cross-ADR conflicts, several unverified HIGH engine risks, and a stale `architecture.md`.

### Blocking Issues

None at FAIL level. Fix before accepting any ADR in the affected chain:
1. ADR-0006 Depends On edit (cycle).
2. ADR-0009/ADR-0011 `max_hp` source, ADR-0005 D7/D8 wording, ADR-0008 D8 GestureLog creation: these are the conflicts a story writer would trip on first.

### Required ADRs

1. **Renderer and first target device** (Foundation, HIGH engine risk). Decide Mobile versus Compatibility for a canvas-only game, and iPhone-first versus Android-first, with which renderer each device run records. Resolves engine E1 and the platform contradictions in data-config-pipeline.md and game-concept.md (TR-data-003, TR-data-015).
2. **Amendments, not new ADRs:** Wave records for the HUD (TR-hud-017, ADR-0005 or ADR-0010); `burst_started` listener and per-source damage in the result snapshot (TR-hud-010, TR-hud-013, ADR-0006 and ADR-0010); burst button centre on inset change (TR-hud-018); recording-fake seam for the tick slots (TR-state-013, ADR-0004 or ADR-0007); physics-area ban as a lint rule (TR-state-003, ADR-0007); wrong-phase wave events in Flow (TR-state-018); whole-tick budget replacing TR-combat-013.
3. **Save-data ID stability and migration** (Vertical Slice, with Save/Load): TR-data-021.

### Handoff

Immediate actions:
1. Make the ADR-0006 Depends On edit and the ADR-0008 "ADR-0005 is not used" rewording, then re-run `adr-dep-graph.sh`.
2. Write the renderer and target-device ADR: `/architecture-decision renderer and first target device`.
3. Apply the ADR amendments in Required ADRs item 2, then accept ADRs in the order above.

Pre-gate checklist:
- ✅ `tests/unit/` and `tests/integration/`
- ✅ `.github/workflows/tests.yml`
- ❌ `design/accessibility-requirements.md`: run `/ux-design`
- ❌ `design/ux/interaction-patterns.md`: run `/ux-design`

Do not run `/gate-check pre-production` until both UX files exist and the ADRs are Accepted. Re-run `/architecture-review` after each new or amended ADR to confirm coverage improves.
