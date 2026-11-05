## Architecture Review Report
Date: 2026-11-05
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
GDDs Reviewed: 8 (systems index and game concept read for context; the two `gdd-cross-review-*.md` files are review reports and add no requirements)
ADRs Reviewed: 11 (ADR-0001 Accepted and amended, ADR-0002 to ADR-0011 Proposed)

Freshness check: against `architecture-review-2026-11-05.md` (full, workflow full), nine ADRs and `architecture.md` were CHANGED by the fix round (commit 50da8eb); GDDs, the TR registry, the engine reference and this skill were UNCHANGED. Since `architecture.md` changed, the full review ran again, scoped by reading the fix round's diff in full.

Reviewed-Content-Hash: docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md f6051f24964e707c7718f2f0a037299a2792d2fd
Reviewed-Content-Hash: docs/architecture/adr-0002-catalogue-storage-format-manifest-and-validation.md 127cbebf45d09acd3963c96458417d969342e8a8
Reviewed-Content-Hash: docs/architecture/adr-0003-input-adapter-display-stretch-and-platform-lifecycle.md c8a97f26da9cc511994a035a348a28dcdb9abed9
Reviewed-Content-Hash: docs/architecture/adr-0004-fixed-tick-clock-tick-order-frame-order-and-determinism.md 63aefbc0fac8c7059556c21ac89132a1b6e0631d
Reviewed-Content-Hash: docs/architecture/adr-0005-stat-accessor-and-read-context-contract.md f64b46ec9ac786883bd9e2bd2c267237bd72a5f1
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-signal-contracts-and-view-allowlist.md 6cd6500e594487fa5f43f41fb98910a3cb81ccb7
Reviewed-Content-Hash: docs/architecture/adr-0007-headless-test-harness-gdunit4-and-layer-lint.md 0c982282be76675e8f4eec8b91655f9a94995452
Reviewed-Content-Hash: docs/architecture/adr-0008-input-resolver-core-and-signal-contract.md eef62d58ed67c702ba610dd97525bc775d343afd
Reviewed-Content-Hash: docs/architecture/adr-0009-enemy-entity-roster-and-combat-api.md f60a29cc120295eb96982ec8353d0729e41da2d6
Reviewed-Content-Hash: docs/architecture/adr-0010-sim-input-split-command-result-codes-and-dev-telemetry.md 7cbdb94926aa6814861371f8a958cb26d3c7964b
Reviewed-Content-Hash: docs/architecture/adr-0011-battle-field-rendering-and-draw-call-budget.md 85b3371c0d52b9e23be73864ea83dd9ba0569eee
Reviewed-Content-Hash: design/gdd/battle-hud.md aae945e5534a6bf05f5970b0ecf620dde49b0357
Reviewed-Content-Hash: design/gdd/combat-damage.md bad2d9173d91b32993e7ddc7b48e037cd6da88e7
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 2f50ce1c10f5128835ec01dd5c46e8358293da85
Reviewed-Content-Hash: design/gdd/enemy-wave.md 3f153a465d0025528528d1d290819dea7ddecd05
Reviewed-Content-Hash: design/gdd/game-concept.md f6a170aa9c3f4bb23b271cee9616a605f88d4f3f
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md b47442be7138b8145491d9383cc93c3839ad3201
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md 5a40dd61c36f3a56fc886d773347673fe38878c0
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-04.md dc8dc921f08eaa3bf13ec9938c43e751552deaf5
Reviewed-Content-Hash: design/gdd/hero-system.md 9b9443d98113536d1b834d30cb598465620e36fe
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 89b9bb2561ad1fc4bb997dd69bae2f3ee026d264
Reviewed-Content-Hash: design/gdd/systems-index.md 5a966f004e35ed33200b2bbe60c291cbd8212100
Reviewed-Content-Hash: design/gdd/tower-system.md 3e5d34fca905ea6fd7343cdddebdb8939539ac38
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 421f63bb38b43b35afc7c93b33f9ecebdccc43f7
Reviewed-Content-Hash: docs/architecture/architecture.md 13d54cb4ccc579ad77d256601e755e18e1ca0b24
Reviewed-Content-Hash: docs/engine-reference/godot/VERSION.md fcf85779788e0facbeca26aeda9fd41955e2633e
Reviewed-Content-Hash: docs/engine-reference/godot/breaking-changes.md 4bc55e16796664ff88c7582c9f08e3530f7c94d4
Reviewed-Content-Hash: docs/engine-reference/godot/current-best-practices.md 977bf7937df4c6ad5d4ef818bcaa1231d208ffa2
Reviewed-Content-Hash: docs/engine-reference/godot/deprecated-apis.md 6a1353983e1db0d7bc0cc41a568b039495b5413c
Reviewed-Content-Hash: docs/engine-reference/godot/modules/animation.md ee51f50a46f8c63b771f62fe438947d4d84c59e3
Reviewed-Content-Hash: docs/engine-reference/godot/modules/audio.md c72af247505908a04f84a1dd3e765939efe700bd
Reviewed-Content-Hash: docs/engine-reference/godot/modules/input.md 622ab9a08a1a689d1efad242579534bcc52bd7d3
Reviewed-Content-Hash: docs/engine-reference/godot/modules/navigation.md 7ae18ffbd2c3230cb19d610373225bfba187a472
Reviewed-Content-Hash: docs/engine-reference/godot/modules/networking.md 6606880462a2241014f77feb9610c5611e659ec6
Reviewed-Content-Hash: docs/engine-reference/godot/modules/physics.md 3b6ac8947f3f3e8c9ac9e6e0ff6cac06fdb8d805
Reviewed-Content-Hash: docs/engine-reference/godot/modules/rendering.md 2a303185bb57eed31dd1151a036784820747b211
Reviewed-Content-Hash: docs/engine-reference/godot/modules/ui.md 30ad166ab8c4e92c15aa37ed3464483b92b7845b
Reviewed-Content-Hash: project.yaml 0e9e0b4ae6b0f195bb7aa7c062a5d43698a74c8b
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

### Verdict: FAIL

One blocking item, and the fix round created it: ADR-0007 and ADR-0011 now each list the other under Depends On, so neither can be accepted first (K1 below). The fix is to drop one Depends On entry. The first review's advisory to add ADR-0007 to ADR-0011's Depends On led to this cycle; that advice was wrong.

Everything else from the first review holds as fixed: C1 to C4 are resolved, D1 to D12 are fixed, Flow's result enums exist (QQ-18 closed), and every requirement still has an ADR.

What would move the verdict to CONCERNS: break the K1 cycle. What would move it to PASS after that: accept ADR-0002 to ADR-0011 (118 of 128 requirements rest on a Proposed ADR).

### What this run changed

| File | Change |
|---|---|
| `requirements-traceability.md` | Notes only: C1 to C4 and D2 marked resolved on their rows, a pointer to this report. The ADRs' requirement tables are byte-identical before and after the fix round, so no row changed. |
| `architecture.md` | QQ-18 marked resolved and the Flow command comment updated, per ADR-0010's sync line. |
| `tr-registry.yaml` | Nothing. No GDD changed, so there is no new, reworded or deprecated requirement. `registry.sh validate`: 0 duplicate, 0 unknown, 0 missing path, 0 status, 0 layout. |

---

### Traceability Summary
Total requirements: 128
✅ Covered by an Accepted ADR: 10
🟡 Covered, resting on at least one Proposed ADR: 118
⚠️ Partial: 0
❌ Gaps: 0

Checked by script: 128 registered IDs, all cited in at least one ADR's `GDD Requirements Addressed` table, 0 unknown IDs. No ADR changed status, so the split is the same as the first review (the ten ✅ are listed there). The first review's requirement delta, registry wording list and candidate requirements stand unchanged.

### Coverage Gaps (no ADR exists)
None.

---

### Cross-ADR Conflicts

Known conflict-prone areas: none on record (`docs/consistency-failures.md` does not exist, so nothing was appended).

#### First-review items, re-checked

| Item | State | Where |
|---|---|---|
| C1 `damage_applied` observers | Resolved | EnemyView on the row (adr-0006:86) and in the graph; ADR-0011 points back (adr-0011:191) |
| C2 RunLog's trigger | Resolved | Keys on `phase_changed(INTERMISSION)`, no `wave_cleared` handler (adr-0010:167) |
| C3 `HALTED` a dev error? | Resolved | ADR-0001 Decision 8 amended with the owner's sign-off (adr-0001:96); matches adr-0010:94 |
| C4 dev-telemetry flag | Resolved | `setup(battle, dev_telemetry: bool)` (adr-0001:170); AppRoot the only reader of `OS.is_debug_build()` (adr-0010:164); both shapes in one process (adr-0007:71) |
| D1 to D12 | Fixed | No old guard name, old command names, `early_call_bonus()`, wrapper tick loop or stale QQ-07 text left in the ADRs |
| Flow result enums (QQ-18) | Closed | `Flow.StartResult`, `Flow.CallResult` (adr-0010:100-103) |
| Dropped delegations to ADR-0007 | Mostly closed | Pointer fixtures, L16 files, L32 to L36 added. Still missing: the field-view rule against `material`, `z_index`, per-entity `modulate` and `enemy_killed` (asked at adr-0011:324) |

#### 🔴 K1: ADR-0007 vs ADR-0011. Dependency cycle (blocking)
Type: Dependency
ADR-0007 claims: Depends On ADR-0011, since ADR-0011 supplies rule L36 (adr-0007:34).
ADR-0011 claims: Depends On ADR-0007 for "lint rows, test runner" (adr-0011:47).
Impact: `adr-dep-graph.sh` reports `CYCLE: adr-0007 -> adr-0011`, and both drop out of the acceptance order. `/architecture-decision accept` in dependency order cannot take either first.
Resolution options:
  1. Drop ADR-0007 from ADR-0011's Depends On. It already sits in ADR-0011's Delegates To, which is how ADR-0010 relates to ADR-0007 without a cycle. (Recommended)
  2. Drop ADR-0011 from ADR-0007's Depends On and treat L36 as a row ADR-0011 hands over.

#### 🟡 K2: ADR-0007 L34 checks a folder RunLog does not live in (concern, not blocking)
Type: Integration (lint scope)
ADR-0007 claims: L34 scans `src/battle/run_log.gd` and `src/battle/gesture_log.gd` (adr-0007:112).
ADR-0010 claims: `RunLog`, `FileRunLogSink`, `GestureLog` live in `src/presentation/telemetry/*.gd` (adr-0010:81).
Impact: the scope holds 0 files forever, so L34 stays SKIPPED under `owed: greenfield` and never checks ADR-0010 Decision 12(d). The stale-owed check cannot catch it because the scope never fills.
Resolution: set L34's scope to `src/presentation/telemetry/run_log.gd`, `src/presentation/telemetry/gesture_log.gd` (ADR-0010 is authoritative). While there: use `(^|[^[:alnum:]_])OS\.` for portability, match `pin(` as a whole word, and add `start_next_wave(` and `DirAccess`.

#### Drift (one ADR is clearly authoritative)

| # | Where | Drift | Authoritative |
|---|---|---|---|
| E1 | adr-0011:88-89 | Frame step b runs `TowerInput.advance`, `HeroInput.update()`, then `HudLogic.advance`; ADR-0004 runs `HudLogic.advance` first (adr-0004:109). Step letters differ too (refresh is d in ADR-0004, e in ADR-0011) | ADR-0004 |
| E2 | adr-0007:75 | "L16 lists its four files and carries no `owed:` entry": while `src/` is empty its scope holds 0 files, so `/test-setup` must write `owed: greenfield` for it like any other rule. The sentence means "no `owed: ADR-0010`" | Decision 7's own SKIPPED rule |
| E3 | architecture.md B9 | ADR-0006 now has the builder inject Combat's counters into Flow for `StageResult` (adr-0006:94); B9 lists only HudLogic as their consumer | ADR-0006 |
| E4 | adr-0010:97 | The callers' rule covers HeroInput and TowerInput only. Flow's caller (the HUD) is not told that `WRONG_PHASE` and `NOT_CALLABLE` are ordinary; the GDD's call-at-expiry race (game-state-stage-flow.md:160) makes them expected | ADR-0010 should say so |

### ADR Dependency Order
`adr-dep-graph.sh`: 11 ADRs, 42 edges, no ADR without a dependencies section, none unfilled. **One cycle: ADR-0007 ↔ ADR-0011 (K1).**

Order as emitted (ADR-0007 and ADR-0011 are left out until the cycle breaks):
1. ADR-0001 App Lifecycle (Accepted)
2. ADR-0002 Catalogue (requires 0001)
3. ADR-0003 Input Adapter (requires 0001)
4. ADR-0004 Fixed-Tick Clock (requires 0001, 0003)
5. ADR-0005 Stat Accessor (requires 0001, 0002)
6. ADR-0009 Enemy Entity and Combat API (requires 0001, 0002, 0004, 0005)
7. ADR-0006 Battle Signals (requires 0001, 0002, 0004, 0005, 0009)
8. ADR-0008 Input Resolver (requires 0001, 0002, 0003, 0006)
9. ADR-0010 Sim/Input Split (requires 0001, 0003, 0004, 0005, 0006, 0008, 0009)

With option 1 of K1: 10. ADR-0011 Field Rendering, then 11. ADR-0007 Test Harness (which depends on every other ADR).

⚠️ Unresolved dependencies: ADR-0004 to ADR-0011 each depend on at least one Proposed ADR. ADR-0002 and ADR-0003 depend only on the Accepted ADR-0001.

### GDD Revision Flags
None. No GDD changed, and no fix-round decision contradicts a GDD assumption. The systems index was not changed.

---

### Engine Compatibility Issues
Engine: Godot 4.7.2 (pinned 4.7, installed 4.7.2.stable.official)
ADRs with an Engine Compatibility section: 11 / 11
Engine specialist consulted: godot-specialist, on the fix-round diff and the carried findings.

No deprecated API, no stale version, no post-cutoff disagreement. The fix round's engine-facing changes are sound: reading `OS.is_debug_build()` once in AppRoot (fixed per process), `TickRate.DT` under `src/data/` (allowed by L35), `Clock.advance` owning the tick loop, and `OK = 0` inside named enums (no clash with `@GlobalScope.OK`).

#### Engine Specialist Findings
- CONCERN, new, ADR-0007 L36 (adr-0007:114): a for/while-body check misses a `draw_*` in a helper called from a loop, and a loop in a lambda or `Array.map`. It also leaves out `draw_polyline` (one call per ring, adr-0011:131) and `draw_string` (one call each, adr-0011:39). Add both to the rule and keep ADR-0011 V1's `TOTAL_DRAW_CALLS_IN_FRAME` count as the real gate.
- CONCERN, new: the step-b order drift, E1 above.
- CONCERN, carried, not closed: ADR-0001 Decision 4 (adr-0001:88) still guards `load()` with a null check only; a scene whose script failed to parse reaches `setup()` as a bare node. Add `get_script() != null` or `has_method("setup")`.
- CONCERN, carried, not closed: gdUnit4 6.2.0 installed (`addons/gdUnit4/plugin.cfg`), 4.7.2 evidence only with 6.2.2. ADR-0007 reads the exit codes from 6.2.0's source, which lowers the risk; no run was observed.
- CONCERN, carried, not closed: ADR-0011 V1 still does not log `RenderingServer.get_current_rendering_driver_name()` or the rendering method on the device (Compatibility fallback on Adreno 5xx).
- ADVISORY, new, ADR-0007 Decision 5: the wiring test that builds the wrapper twice should give each a fresh `Battle` and `free()` the first wrapper, not `queue_free()` it, or the listener counts double until the frame ends.
- ADVISORY, new: an exported debug APK also reads `OS.is_debug_build()` as true and writes telemetry; V1 covers only the release export.
- Unchanged from the first review: the piped exit-code fact at adr-0007:28, the JSON float-count, `draw_primitive` volume and double-`connect` advisories, and the NOT SOURCEABLE rows without a Verification row (ADR-0003 lifecycle timing, ADR-0004 long-run delta).

The owed device and export runs listed in the first review are unchanged; none ran.

---

### Architecture Document Coverage
`docs/architecture/architecture.md` exists. All 22 systems of `systems-index.md` appear in its system-to-layer table; no module lacks a GDD. The fix round updated Data Flow 9 for the `dev_telemetry` argument. This run applied ADR-0010's QQ-18 sync line. Left open: E3 (the B9 consumer list), and the items the first review left on purpose.

---

### Blocking Issues (must resolve before PASS)
1. K1: break the ADR-0007 ↔ ADR-0011 cycle; drop ADR-0007 from ADR-0011's Depends On.

Then, for PASS: accept ADR-0002 to ADR-0011 in the order above.

Should fix before acceptance (not blocking): K2 (L34 scope), E1 to E4, the L36 gaps, the missing field-view rule, and the ADR-0001 Decision 4 load guard.

### Required ADRs
None new. The eleven ADRs cover all 128 requirements. Amendments only: K1, K2, E1 to E4 and the engine concerns above.

### Handoff
Pre-gate checklist: ✅ `tests/unit/` and `tests/integration/`; ✅ `.github/workflows/tests.yml`; ✅ `design/accessibility-requirements.md`; ✅ `design/ux/interaction-patterns.md`.

Next steps, in order:
1. A short fix round: K1 (one Depends On line in ADR-0011), K2, E1 to E4, L36 and the ADR-0001 load guard (ADR-0001 is Accepted, so that one needs the owner's sign-off).
2. `/architecture-decision accept` per ADR in dependency order.
3. Re-run `/architecture-review` after the fix round.
