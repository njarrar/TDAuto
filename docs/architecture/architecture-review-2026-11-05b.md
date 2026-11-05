## Architecture Review Report
Date: 2026-11-05 (second run of the day, after the ADR fix round in commit 50da8eb)
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
GDDs Reviewed: 8 (systems index and game concept read for context; the two `gdd-cross-review-*.md` files are review reports and add no requirements)
ADRs Reviewed: 11 (ADR-0001 Accepted and amended 2026-11-05, ADR-0002 to ADR-0011 Proposed)

Freshness check: against `architecture-review-2026-11-05.md`, nine ADRs and `architecture.md` are CHANGED; every GDD, the TR registry, the engine reference, `project.yaml` and this skill are UNCHANGED. A changed `architecture.md` reaches every phase, so the full review ran. Because the requirement side did not move, Phase 2 carries the 128 registered IDs forward and this run spends its effort on the fix-round text: whether each prior finding closed, and what the edits broke.

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
Reviewed-Content-Hash: docs/architecture/architecture.md 3a7f6b6e668ef01f067bab93a4217f88923f2320
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

The fix round closed all four prior conflicts (C1 to C4), the Flow result enums (QQ-18) and most of the drift table. It also made two new blocking findings, both from edits that added text to ADR-0007 and ADR-0011:

- **CY1, a dependency cycle.** ADR-0007 now depends on ADR-0011, and ADR-0011 now depends on ADR-0007. Neither can be accepted first.
- **C5, a lint that cannot pass.** ADR-0007 rule L34 scans `src/battle/run_log.gd` and `src/battle/gesture_log.gd`; ADR-0010 puts those files in `src/presentation/telemetry/`. A rule with no files fails the run, and moving the files into `src/battle/` trips L33.

Each is a one-line fix. What moves the verdict to CONCERNS: fix CY1 and C5. What moves it to PASS after that: accept ADR-0002 to ADR-0011 (118 of 128 requirements still rest on a Proposed ADR).

### What this run changed

| File | Change |
|---|---|
| `requirements-traceability.md` | Seven matrix notes updated (C1 to C4 and D2 closed, C5 named on TR-hud-013), a re-check paragraph added. Coverage counts unchanged. |
| `tr-registry.yaml` | Not changed. No requirement is new, reworded or deprecated; `registry.sh validate` is clean (0 duplicate, 0 unknown, 0 missing path, 0 status, 0 layout). |
| `architecture.md` | Not changed. Its drift is listed under Architecture Document Coverage for the acceptance sync. |

---

### Traceability Summary
Total requirements: 128
✅ Covered by an Accepted ADR: 10
🟡 Covered, resting on at least one Proposed ADR: 118
⚠️ Partial: 0
❌ Gaps: 0

Checked by script: 128 registered IDs, every one cited in at least one ADR's `GDD Requirements Addressed` table, no cited ID missing from the registry. The ten ✅ are the same as in the last report (ADR-0001's TR-data-011, TR-state-001, -002, -009, -011, -015, -016, TR-enemy-005, TR-hero-004, TR-hud-006). ADR-0001's amendment did not change which requirements it covers.

Phase 2 delta: none. No GDD changed, so the registry wording edits and candidate requirements listed in `architecture-review-2026-11-05.md` still stand, to be applied by `/architecture-decision accept`. ADR-0006's table still quotes TR-state-008 and TR-enemy-004 with the old name `waves_complete` (adr-0006:301, :303).

### Coverage Gaps (no ADR exists)
None.

---

### Cross-ADR Conflicts

Known conflict-prone areas: none on record (`docs/consistency-failures.md` does not exist, so nothing was appended).

#### Prior findings: state after the fix round

| # | Finding | State | Where it closed |
|---|---|---|---|
| C1 | EnemyView not on the `damage_applied` allowlist | Closed | adr-0006:86, :104, :137; adr-0011:191 points back to it |
| C2 | RunLog's trigger for the call record | Closed | adr-0010:167, keys on `phase_changed(INTERMISSION)`, no `wave_cleared` handler |
| C3 | Is `HALTED` a dev error? | Closed | adr-0001:96 (amended with the owner's sign-off): ordinary; only `REENTERED` and `start_next_wave()` in the wrong state report |
| C4 | Where the dev-telemetry flag comes from | Closed | adr-0001:88, :170 `setup(battle: Battle, dev_telemetry: bool)`; adr-0010:164; adr-0007:71; adr-0011:47 |
| QQ-18 | Flow's result enums | Closed in the ADRs | adr-0010 Decision 2: `Flow.StartResult`, `Flow.CallResult`; `architecture.md:743` still lists it open |
| D1 | `in_tick` as the command guard | Closed | adr-0004:106, :199, :351 read `in_dispatch()` |
| D2 | Frame step b | Closed | adr-0004:109, adr-0011:88 and adr-0010:166 name the same calls |
| D3 | Wrapper loops the ticks | Closed | adr-0011:90 |
| D4 | `early_call_bonus()` and `slot_state()` | Closed in the ADRs | adr-0011 uses the ADR-0010 forms; `architecture.md:143`, `:612` still have no argument |
| D5, D6, D8, D9, D10 | Names, slot wording, decision number, garbled rename, RunLog in HudLogic | Closed | no hits left |
| D7 | Local `1/60` floor | Closed | adr-0004:55 |
| D11 | `ClearanceWindow` and HudLogic paths | Closed | adr-0011 Decision 6 gives both |
| D12 | Stale notes | Closed | adr-0006:28, adr-0002 ordering note |
| Delegations | Pointer fixtures; L16 file list; ADR-0010 12(b)-(d) rows; import direction; one listener per signal; Flow enums; `BUTTON_RADIUS` | Closed | adr-0007 Decision 2, L16, L32 to L36, Decision 5; adr-0010 Decision 2 |

#### 🔴 CY1: ADR-0007 ↔ ADR-0011. Dependency cycle (new)
Type: Dependency
ADR-0007 claims: Depends On "ADR-0002 … ADR-0010, ADR-0011 (Proposed: each delegates checks …; ADR-0010 and ADR-0011 supply rules L16, L32 to L34 and L36)" (adr-0007 Depends On, edited this round).
ADR-0011 claims: Depends On "ADR-0007 (lint rows, test runner)" (adr-0011 Depends On, added this round to answer the last report's advisory).
Impact: `adr-dep-graph.sh` emits `CYCLE: adr-0007 -> adr-0011` and leaves both out of `ORDER`. Neither ADR can be accepted before the other, and `/architecture-decision accept` takes them one at a time.
Resolution options:
  1. Drop ADR-0007 from ADR-0011's Depends On and name it under Enables or Delegates To. This matches ADR-0002 to ADR-0010, which all delegate checks to ADR-0007 without depending on it. (Recommended)
  2. Drop ADR-0011 from ADR-0007's Depends On and treat L36 and the evidence naming as rows ADR-0011 adds at its own acceptance.

The last report's advisory "ADR-0011 omits ADR-0007" was the wrong advice for this graph; this run withdraws it.

#### 🔴 C5: ADR-0007 vs ADR-0010. The path of RunLog and GestureLog (new)
Type: Integration contract (lint scope)
ADR-0007 claims: L34 scope is `src/battle/run_log.gd`, `src/battle/gesture_log.gd` (adr-0007:112); L33 bans the whole words `RunLog` and `GestureLog` anywhere in `src/battle/` (adr-0007:111); a rule whose scope holds 0 files prints `SKIPPED` and fails the run unless an `owed:` entry covers it (adr-0007:75).
ADR-0010 claims: `RunLog`, `FileRunLogSink`, `GestureLog` live in `src/presentation/telemetry/*.gd` (adr-0010:81).
Impact: built as ADR-0010 says, L34 scans nothing and fails CI on every run; built where L34 looks, the files' own `class_name RunLog` trips L33. ADR-0010 Decision 12(d) (the logs never touch `OS`, `Time`, `FileAccess` or a command) is then enforced nowhere.
Resolution options:
  1. Set L34's scope to `src/presentation/telemetry/run_log.gd`, `src/presentation/telemetry/gesture_log.gd`. (Recommended; one cell in ADR-0007)
  2. Move the logs to `src/battle/` and exempt their own files from L33. Not advised: ADR-0010 keeps the battle layer unaware of the logs.

#### 🟡 New drift (one ADR is clearly authoritative)

| # | Where | Drift | Authoritative |
|---|---|---|---|
| N1 | adr-0004:109 vs adr-0011:88 | Frame step b order: ADR-0004 says "in this order and nothing else" with `HudLogic.advance` first, then `TowerInput.advance`, `HeroInput.update()`, RunLog; ADR-0011 lists `TowerInput`, `HeroInput`, then `HudLogic` | ADR-0004 (it owns the frame order); ADR-0011 should copy it |
| N2 | adr-0006:38 vs adr-0004:315, adr-0006 Decision 7 | ADR-0006's note says the ADR-0004 Migration line now injects nothing ("Battle calls down into each sim's `in_command()`; nothing is injected"), but ADR-0004:315 still injects `in_dispatch` into Flow, TowerSim and HeroSim, and ADR-0006 Decision 7 has each sim check `in_dispatch()` through an injected Callable | ADR-0004:315 and Decision 7 agree; reword ADR-0006's note to say `in_command` is not injected |
| N3 | adr-0001:88 vs :92, :190 | "AppRoot passes `OS.is_debug_build()` (the only read of it)": AppRoot also reads it for the fatal screen. True of AppRoot as the only reader, not of one read | Reword to "AppRoot is the only reader" |
| N4 | adr-0011:135 | `EvidenceCapture` is "dev-only" with no statement of who builds it, under which flag, or how it stays out of a release export; with C4, `dev_telemetry` is the only flag the wrapper has | Decide in ADR-0011 (likely: built only when `dev_telemetry` is true) |

#### Settled points (re-checked)

| Point | Holds in every ADR? |
|---|---|
| `setup(battle, dev_telemetry)`, with `OS.is_debug_build()` read only in AppRoot | Yes (adr-0001, 0007, 0010, 0011, `architecture.md:350`) |
| `HALTED` ordinary; `REENTERED` reports once | Yes (adr-0001:96, adr-0010 Decision 2) |
| `in_dispatch()` = `in_tick()` or any sim's `in_command()` | Yes (D1 closed); N2 is a note's wording |
| Lint catalogue | 36 rows L01 to L36, no duplicate id; self-test covers all 36 |
| `NONE = -1`, `Vector2` commands, `waves_completed` last, `MAX_TICKS_PER_FRAME = 3` | Yes, unchanged |

Not checked this run: the delegation passes were not repeated in full; only the eleven open rows of the last report's delegation table were re-checked, and all closed.

### ADR Dependency Order
`adr-dep-graph.sh`: 11 ADRs, 43 edges (36 last run; the fix round added ADR-0010 → 0003, ADR-0011 → 0001 and → 0007, ADR-0007 → 0003, → 0008, → 0010, → 0011), no ADR without a dependencies section, none unfilled.

🔴 DEPENDENCY CYCLE: ADR-0007 → ADR-0011 → ADR-0007. This cycle must be broken before either can be accepted (CY1). No other ADR is blocked by it.

Recommended acceptance and implementation order (as emitted, then the two cycle ADRs once CY1 is cut by option 1):
1. ADR-0001 App Lifecycle (Accepted)
2. ADR-0002 Catalogue (requires 0001)
3. ADR-0003 Input Adapter (requires 0001)
4. ADR-0004 Fixed-Tick Clock (requires 0001, 0003)
5. ADR-0005 Stat Accessor (requires 0001, 0002)
6. ADR-0009 Enemy Entity and Combat API (requires 0001, 0002, 0004, 0005)
7. ADR-0006 Battle Signals (requires 0001, 0002, 0004, 0005, 0009)
8. ADR-0008 Input Resolver (requires 0001, 0002, 0003, 0006)
9. ADR-0010 Sim/Input Split (requires 0001, 0003, 0004, 0005, 0006, 0008, 0009)
10. ADR-0011 Field Rendering (requires 0001, 0003, 0004, 0006, 0009, 0010; after CY1 option 1)
11. ADR-0007 Test Harness (requires every other ADR)

⚠️ Unresolved dependencies: ADR-0004 to ADR-0011 each depend on at least one Proposed ADR. ADR-0002 and ADR-0003 depend only on the Accepted ADR-0001. ADR-0004 and ADR-0008 still hold ADR-0003 as a provisional premise until device runs D1 and D3 pass. ADR-0006's ordering note asks that ADR-0009 be accepted with ADR-0006 and ADR-0007; the order above already puts ADR-0009 first.

### GDD Revision Flags
None. No GDD assumption conflicts with verified engine behaviour, and the systems index was not changed.

---

### Engine Compatibility Issues
Engine: Godot 4.7.2 (pinned 4.7, installed 4.7.2.stable.official)
ADRs with an Engine Compatibility section: 11 / 11
Engine specialist consulted: godot-specialist (findings below).

Version: all 11 name the same engine, unchanged. Deprecated API references: none added by the fix round. Post-cutoff APIs: the fix round added none; no two ADRs disagree. Owed device and export runs: unchanged from the last report's list (ADR-0010 V1 now reads `OS.is_debug_build()` in AppRoot only; same run).

#### Engine Specialist Findings
Read-only; no Godot binary in this container, so nothing was run.

Prior concerns, all four still stand (the fix round did not take them up):
- CONCERN, ADR-0001:88 (Decision 4): the wrapper and Stage look-scene are only null-checked after `load()`; a scene whose script fails to parse loads non-null (adr-0001:44), so `setup(battle, dev_telemetry)` raises "nonexistent function" instead of `fatal()`. Fix: `instantiate() as BattleWrapper`, then null-check.
- CONCERN, ADR-0007:28: "exit 0 with no class cache" is still the pipe's exit code; the reference records exit 1. The mitigation holds either way; the recorded fact is wrong.
- CONCERN, ADR-0007:16, :46, :57: gdUnit4 6.2.0 is installed; the reference's 4.7.2 evidence is on 6.2.2.
- CONCERN, ADR-0011:112, :293 (V1): draw-call rules observed on the desktop Mobile renderer only; V1 does not log `RenderingServer.get_current_rendering_driver_name()` on the device, and an Adreno 5xx may fall back to Compatibility, which batches differently. The `draw_set_transform` and "3 primitive types = 3 calls" claims ride on the same run.

Fix-round edits:
- CONCERN, ADR-0007 L34 vs ADR-0010:81: confirms C5 from an independent reading.
- CONCERN, ADR-0007:75 and L16: L16 "carries no `owed:` entry", but with `src/` empty its scope holds 0 files, so it is SKIPPED and fails CI from the first run; a listed file that is missing is never reported. Make a missing listed file a failure, or give L16 an `owed:` entry until the files exist.
- CONCERN, L36 (adr-0007:114): an indent-tracking awk pass can find a `draw_*` call inside a `for`/`while` body, but misses the usual pattern (a loop calling `_draw_enemy(i)`), one-line `for …: draw_*` and lambdas. Simpler: ban the three calls in `src/presentation/field/` outright, with the allowlist.
- ADVISORY, L15, L22, L31 to L34: `\b`, `\w`, `\s` are GNU extensions; fine on the Linux runner, unverified on the macOS dev host. Portable forms: `(^|[^[:alnum:]_])`, `[[:alnum:]_]`, `[[:space:]]`. L33's "whole words" has no pattern written; L34's `build(` and `pin(` also match `rebuild(` and `spin(`.
- ADVISORY, ADR-0001:88 vs :92, :190: same as N3.
- ADVISORY, ADR-0010 Decision 2: the Flow enums are sound (no clash with a 4.7 built-in). `pause()` and `resume()` return nothing, so the adapter cannot see a refusal; safe because lifecycle notifications never arrive inside a tick (still owed to ADR-0003's device rows).
- ADVISORY, ADR-0010:98: "`_in_command` cleared on every return path" does not cover a runtime error; with no `finally` the flag stays set and every later command returns `REENTERED` until a retry. Flow now inherits this from the sims.

Not verified: any run of Godot 4.7.2 or gdUnit4; BSD grep on `\b`, `\w`, `\s`; whether Android falls back to Compatibility on Adreno 5xx.

---

### Architecture Document Coverage
`docs/architecture/architecture.md` exists. All 22 systems of `systems-index.md` still appear in its layer table and no module lacks a GDD. The fix round changed one line (Data Flow 9, the dev flag). Rows that now trail the ADRs, for the acceptance sync:

| Line | Stale text | Now |
|---|---|---|
| 143, 612 | `early_call_bonus()` | `early_call_bonus(seconds_left)` (ADR-0010) |
| 257 | `damage_applied` observers "Combat view, audio (Alpha)" | add EnemyView (ADR-0006, C1) |
| 633 | TR-hud-018 call record "written at the next `wave_cleared`" | `phase_changed(INTERMISSION)` (ADR-0010, C2) |
| 134, 503, 743 | QQ-18 open, names "proposed" | resolved by ADR-0010 Decision 2 (its own sync list says so) |

---

### Blocking Issues (must resolve before PASS)
1. CY1: remove ADR-0007 from ADR-0011's Depends On (or the reverse edge).
2. C5: point ADR-0007 L34 at `src/presentation/telemetry/`.

Then, for PASS: accept ADR-0002 to ADR-0011 in the order above. N1 to N4 and the `architecture.md` rows are fixed at acceptance; they do not block.

### Required ADRs
None new. The eleven ADRs cover all 128 requirements.

### Handoff
Pre-gate checklist: ✅ `tests/unit/` and `tests/integration/`; ✅ `.github/workflows/tests.yml`; ✅ `design/accessibility-requirements.md`; ✅ `design/ux/interaction-patterns.md`. `/gate-check` is still not the next step: the verdict is FAIL.

Next steps, in order:
1. A short fix round for CY1 and C5 (two cells: ADR-0011 Depends On, ADR-0007 L34), plus N1 to N4, the L16 and L36 concerns and the four carried engine concerns if convenient. Neither touches the Accepted ADR-0001 except N3's wording.
2. `/architecture-decision accept` per ADR in the order above; it applies the GDD, registry and `architecture.md` sync edits.
3. Re-run `/architecture-review` after the fix; with CY1 and C5 closed and nothing else new, the verdict would be CONCERNS until the acceptances.
