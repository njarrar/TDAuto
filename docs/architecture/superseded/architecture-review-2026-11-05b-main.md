## Architecture Review Report

> **Not in force.** This report reviews the ADR set that was on `main` at 5aea8df (ADR-0001 to ADR-0011, PRs 22 to 24). While the review ran, PR 25 replaced that set with the one now in `docs/architecture/` and moved the reviewed files into this folder (`superseded/`). The verdict below applies to the superseded set only and gates nothing. It is kept, like the other reviews here, so its points can be checked against the same topics in the live ADRs.
>
> How to read the citations: `adr-NNNN:line` means the file of that number in this folder (ADR-0001 is `adr-0001-...-main.md`); all eleven are byte-identical to what was reviewed. `architecture.md`, the registries and `requirements-traceability.md` were replaced by PR 25, so line numbers into them refer to commit 5aea8df. The receipt lines below record the old paths and will not match the live tree.
Date: 2026-11-05 (second report of the day: independent re-review of the ADR fix round, commit 50da8eb, merged as 5aea8df)
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
GDDs Reviewed: 8 (systems index and game concept read for context; the two `gdd-cross-review-*.md` files are review reports and add no requirements)
ADRs Reviewed: 11 (ADR-0001 Accepted, ADR-0002 to ADR-0011 Proposed)

Independence: this review ran in a session that authored neither the ADRs nor the fix round. Freshness check against `architecture-review-2026-11-05.md`: nine ADRs and `architecture.md` changed; every GDD, the TR registry, the engine reference, `project.yaml` and this skill are unchanged. `architecture.md` is a document that reaches every phase, so the full review ran. `docs/consistency-failures.md` does not exist, so nothing was appended to it.

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
Reviewed-Content-Hash: docs/architecture/architecture.md afd92e86b4388dc2e7d861d7fcf9fac54be378ee
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

One blocking finding, and the fix round introduced it: ADR-0007 and ADR-0011 now depend on each other (N1). `/architecture-decision accept` refuses an ADR whose dependency is not Accepted, so neither can be accepted in any order. The fix is one cell in ADR-0007's Depends On row.

Everything the last review called blocking is closed. C1, C3 and C4 are fixed in the ADR text, and so is C2. Of the 30 prior items, 24 are closed, 5 are partly closed, 1 is deferred to Vertical Slice as before, and none is fully open.

What moves the verdict to CONCERNS: break the cycle (N1). What moves it to PASS after that: fix N2, then accept ADR-0002 to ADR-0011 (118 of 128 requirements still rest on a Proposed ADR).

### What this run changed

Only this report. The review also prepared `architecture.md` edits for the fix round (QQ-18 resolved, Flow's enums in B5, `setup(battle, dev_telemetry)` in B4, B9 and Data Flow 4, the `src/presentation/` sub-folders, the Depends on column). They were not merged, because PR 25 replaced `architecture.md` with the live set's version. No ADR, no ADR Status line, no GDD and no registry was edited.

---

### Closure of the prior findings

Checked against the ADR text on `main` at 5aea8df, now the files in this folder.

| Prior item | State | Evidence |
|---|---|---|
| C1 `damage_applied` observers | Closed | adr-0006:86 "Combat view, EnemyView, audio (Alpha)"; adr-0006:104 "EnemyView styles kills from `damage_applied(killed, spawn_id)`"; adr-0006:137 (diagram); adr-0011:191 "Its row in the Observer allowlist lives in ADR-0006 Decision 5" |
| C2 RunLog's trigger for the call record | Closed | adr-0010:167 "written when `RunLog` sees `phase_changed(INTERMISSION)` (already allowlisted in ADR-0006) or the outcome phase; RunLog connects no `wave_cleared` handler"; adr-0006:78 lists RunLog on `phase_changed`. One test case to add, see A1 below |
| C3 `HALTED` as a dev error | Closed | adr-0001:96 "`HALTED` is an ordinary command result that reports nothing"; the dev-error examples there are now `start_next_wave()` in the wrong state and `REENTERED`; adr-0010:94 "ADR-0001 Decision 8 was amended to match on 2026-11-05" |
| C4 dev-telemetry flag | Closed | adr-0001:170 `func setup(battle: Battle, dev_telemetry: bool) -> void`; adr-0001:88, :114, :120; adr-0010:164 "`AppRoot` is the only reader of `OS.is_debug_build()` and passes it in"; adr-0007:71 "builds the wrapper twice in one process, with `dev_telemetry` true and false"; adr-0011:47. No single-argument `setup(battle)` is left in any ADR |
| D1 `in_tick` named as the guard | Closed | adr-0004:106 "`Battle.in_dispatch()` ... is the command guard"; adr-0004:351; adr-0004:199 |
| D2 frame step b call list | Closed | adr-0004:109 and :149, adr-0010:166 and adr-0011:88-90 name the same calls: `HudLogic.advance`, `TowerInput.advance`, `HeroInput.update()`, `RunLog.advance` and `RunLog.flush` (dev only), then the view clocks. The order inside step b differs, see N3 |
| D3 wrapper tick loop | Closed | adr-0011:91 "Clock.advance(delta) -> runs the owed ticks itself" |
| D4 `early_call_bonus()` and `slot_state()` | Closed | adr-0011:96, :198 `early_call_bonus(seconds_left)`; adr-0011:148 `slot_count()/tower_at()` |
| D5 command and sim names | Closed | adr-0006:66 and :327 `start_wave`; adr-0008:134 `HeroSim.pin`, `TowerSim.build`, Flow `start_wave` and `call_early` |
| D6 slot 1 "clear checks" | Closed | adr-0004:95 "intermission countdown (integer ticks), wave start" |
| D7 local `1/60` floor | Closed | adr-0002:108 "`TickRate.DT` (ADR-0004), referenced by the schema and never a local `1/60`"; adr-0002:43. adr-0004:55 still describes the floor as "a local copy of `1/60` until its code references `TickRate.DT`" (stale note, cosmetic) |
| D8 "ADR-0009 Decision 12" | Closed | adr-0006:94 and :114 cite Decision 8, which is "Splash, burst and damage-by-source" (adr-0009:144) |
| D9 garbled `waves_completed` sentence | Closed | adr-0009:171 "the name is `waves_completed`, final per ADR-0006"; adr-0009:52, :273 |
| D10 RunLog passed "into `HudLogic`" | Closed | adr-0010:164 "The wrapper holds `RunLog` as a nullable field"; adr-0010:166 "`HudLogic` is unaware of `RunLog`" |
| D11 `ClearanceWindow` and HudLogic paths | Partly | Fixed in the ADR: adr-0011:83 `src/presentation/field/clearance_window.gd` and `src/presentation/hud/hud_logic.gd`. Not followed in the registry: `docs/registry/architecture.yaml`:646-647 still say `src/presentation/combat_view/` and `tests/unit/combat_view/` |
| D12 stale notes | Closed | adr-0008:37 names L31; adr-0006:28, :294, :333 record `get_global_name()` as observed (ADR-0007 V7, adr-0007:231); adr-0002:30 closes the broken-scene half by ADR-0007 V9 (adr-0007:233) |
| Flow result enums, QQ-18 | Closed | adr-0010:100-101 `Flow.StartResult { OK = 0, HALTED, REENTERED, WRONG_PHASE }`, `Flow.CallResult { OK = 0, HALTED, REENTERED, WRONG_PHASE, NOT_CALLABLE }`; adr-0006:37 points there; adr-0010:334 closes V8; registry entry `flow_command_result_codes` (architecture.yaml:1185). Checked against the Flow GDD below |
| StageResult counter injection | Partly | The sentence now exists: adr-0006:94 "Flow fills the damage fields from Combat's counters that the builder injects as method Callables". Two gaps remain. ADR-0001 Decision 3 injects "every callable of `architecture.md` B9" (adr-0001:86), and B9 lists Combat's counters for HudLogic only. And `StageResult.damage_by_id` is a `Dictionary` (adr-0006:94, :202) while Combat exposes only the per-id read `dealt_by_id(id)` (adr-0009:254), so no named read returns the table |
| Delegation 0003 → 0007, pointer fixtures | Closed | adr-0007:63 `pointer_gate_test.gd`, `display_contract_accepts_test.gd`, `input_adapter_read_pointer_test.gd`, `PointerEventFactory`; adr-0007:219 |
| Delegation 0004 → 0009, range-check files | Closed | adr-0009:302 names `src/battle/combat.gd` and `src/battle/path_track.gd`; adr-0007:94 lists both in L16 with ADR-0010's two files, no `owed:` entry |
| Delegation 0010 → 0007, Decision 12 (b), (c), (d) | Partly | L32 (adr-0007:110) and L33 (adr-0007:111) are right. L34 (adr-0007:112) points at the wrong folder, see N2 |
| Delegation 0006, 0002 → 0007, import direction | Closed | adr-0007:113, L35 with a fixture |
| Delegation 0010 ↔ 0006, Flow enums | Closed | Same evidence as QQ-18 |
| Delegation 0006 → 0011, view rows | Closed | Same evidence as C1 |
| Delegation 0002 → 0010, burst-line constant | Closed | adr-0010:147 "`BUTTON_RADIUS = 48` on HeroInput is the burst-line constant that ADR-0002's HUD content row reads" |
| Delegation 0008 → 0007, one listener per owner class | Closed | adr-0007:71 "For resolver signals that carry an id, there is exactly one listener per owner class (ADR-0008 Decision 11)" |
| Delegation 0008 → 0011, "react to" | Closed | adr-0008:35 "read resolver-driven state through HudLogic's redraw key, ADR-0011 Decision 8, rather than reacting" |
| Delegation 0011 → 0007 and 0010 → 0007, pending sync | Partly | Applied: L16 file list (adr-0007:94), bot ids (adr-0007:73, same five as adr-0010:157), evidence naming (adr-0007:124, same pattern as adr-0011:135), the draw-loop lint L36 (adr-0007:114). Not applied: the second half of adr-0011:324 ("no field view sets a `material`, `z_index` or per-entity `modulate`") has no rule, and adr-0011:253 says "the type-grouping rule is a lint" where ADR-0007 has none. The `enemy_killed` clause is covered by the wiring test (adr-0007:71, part c) |
| Delegation 0005 → future ADR, modifier resolver | Not applicable | Vertical Slice, unchanged |
| Advisory: Depends On rows | Partly | Applied: adr-0010:45 adds ADR-0003; adr-0011:47 adds ADR-0001 and ADR-0007; adr-0007:34 adds ADR-0003 and ADR-0008; adr-0006:38 has the ordering note; adr-0001:53 Enables adds ADR-0005. But adr-0007:34 also gained ADR-0010 and ADR-0011, which closes a cycle, see N1 |

Totals: 30 items. Closed 24. Partly 5 (D11, StageResult, the 0010 → 0007 lint rows, the pending field-view lint, the Depends On rows). Not applicable 1. Open 0.

### Points the task asked to check

| Point | Result |
|---|---|
| `TowerInput.advance(view_dt_ms)`: unit and name | Consistent. Milliseconds everywhere: adr-0004:109 `TowerInput.advance(view_dt * 1000.0)`; adr-0010:151 and :223 `advance(view_dt_ms: float)`; adr-0011:88. `RunLog.advance(view_dt)` and `ClearanceWindow.advance(view_dt)` are seconds in all three (adr-0010:166, :228; adr-0004:109; adr-0011:90, :170) |
| `call_early` against the GDDs | No conflict. Neither the Flow GDD nor the Enemy & Wave GDD names a Flow command method: the Flow GDD says "the same button starts the next wave at once" (game-state-stage-flow.md:41) and "a call-early command" (:160); Enemy & Wave's only related method is its own `start_next_wave()`. The name is the ADRs', and it is the same in all of them: adr-0004:322, adr-0006:66 and :327, adr-0007:112, adr-0008:134, adr-0010:118 and :161. ADR-0010 Decision 2 writes "The early call" without the method name (adr-0010:103); cosmetic |
| Wrapper per-frame call lists | Same calls in ADR-0004, ADR-0010 and ADR-0011. Order inside step b differs between ADR-0004 and ADR-0011, see N3 |
| `setup(battle: Battle, dev_telemetry: bool)` | Consistent in adr-0001:170, adr-0007:71, adr-0010:164, adr-0011:47 |
| `pause()`/`resume()` | adr-0010:103 "return nothing and are inert in a wrong state; under `in_dispatch()` they refuse and call `dev_error` once". Agrees with adr-0006:66, which lists both as guarded commands whose refusal reports through `dev_error`. No ADR gives them a return value. See A2 for the one case where a refused pause would be lost |
| `Flow.StartResult`, `Flow.CallResult` against the Flow GDD | Match. `WRONG_PHASE` for start: "the second tap finds no Build and is ignored" (flow GDD:161) and "Flow's own commands do nothing there" for Paused (:42). `WRONG_PHASE` for call: "finds no Intermission and is ignored" (:160), "A wave cannot be called while another is running at MVP" (:41). `NOT_CALLABLE`: "a call at 0 is ignored with no signal" (:143). `HALTED`: "Once the latch is set, Flow's commands do nothing" (:63) |
| ADR-0007 rule count of 36 | Consistent. 36 table rows L01 to L36 (adr-0007:79-114); "36-rule catalogue" (adr-0007:16); "all 36 rules fire" (adr-0007:213); 36 `pattern: Lnn` entries in the registry. No "31" is left |

---

### New findings

#### 🔴 N1: ADR-0007 and ADR-0011 depend on each other (blocking)
Type: Dependency cycle. Introduced by the fix round.
ADR-0007 claims: Depends On "ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0008, ADR-0009, ADR-0010, ADR-0011 (Proposed: ... ADR-0010 and ADR-0011 supply rules L16, L32 to L34 and L36)" (adr-0007:34).
ADR-0011 claims: Depends On "ADR-0007 (lint rows, test runner)" (adr-0011:47).
`adr-dep-graph.sh` output: `CYCLE: adr-0007 -> adr-0011`, `CYCLE: adr-0011 -> adr-0007`, and its `ORDER:` row stops at ADR-0010 with neither in it.
Impact: `/architecture-decision accept` refuses an ADR that depends on one not yet Accepted (`.claude/skills/architecture-decision/references/0-accept.md`:38). With the cycle, ADR-0007 and ADR-0011 can never be accepted, and ADR-0007 blocks the first test and the first `.gd` under `src/` (adr-0007:36). ADR-0007's own "it is accepted with them" does not help, because acceptance is one ADR at a time. The same row also contradicts adr-0007:35, which lists ADR-0010 and ADR-0011 under Enables.
Resolution options:
  1. Remove ADR-0010 and ADR-0011 from ADR-0007's Depends On, and keep the fact that they supplied rules L16, L32 to L34 and L36 in the Ordering Note. ADR-0007 now carries those rule texts itself, so it needs nothing from them to be accepted. (Recommended)
  2. Remove ADR-0007 from ADR-0011's Depends On. It is already under Delegates To (adr-0011:48). This leaves ADR-0007 waiting on the last ADR in the chain, so the harness would be accepted last.

#### 🟡 N2: ADR-0007 L34 vs ADR-0010 Decision 1. The run log's folder (not blocking)
Type: Integration contract (lint scope). Introduced by the fix round.
ADR-0007 claims: L34 scope is "`src/battle/run_log.gd`, `src/battle/gesture_log.gd`" (adr-0007:112).
ADR-0010 claims: "`RunLog`, `FileRunLogSink`, `GestureLog` | `src/presentation/telemetry/*.gd`" (adr-0010:81).
ADR-0007 also claims: L33 forbids "the whole words `TowerInput`, `HeroInput`, `RunLog`, `GestureLog`" anywhere under `src/battle/` (adr-0007:111), so a `run_log.gd` there would fail L33 on its own `class_name`.
Impact: L34's scope never holds a file. The runner prints `SKIPPED 0 files`, which passes only under an `owed:` entry that never goes stale (adr-0007:75), so ADR-0010 Decision 12 (d) is never enforced. The registry copies the wrong path (`architecture.yaml`:1736).
Resolution: set L34's scope to `src/presentation/telemetry/run_log.gd` and `src/presentation/telemetry/gesture_log.gd`, and the registry `path` with it.

#### 🟡 N3: ADR-0004 vs ADR-0011. Order inside frame step b (drift)
ADR-0004 lists `HudLogic.advance`, then `TowerInput.advance`, then `HeroInput.update()` (adr-0004:109, :149), under "in this order and nothing else" (adr-0004:107). ADR-0011 lists `TowerInput.advance`, `HeroInput.update()`, then `HudLogic.advance` (adr-0011:88). ADR-0011 also keeps an empty step d ("no wrapper tick loop", adr-0011:92), so its refresh is step e where ADR-0004 calls the same step 2d (adr-0004:111, :113).
Authoritative: ADR-0004. Reorder adr-0011:88 and drop the empty step so the letters match.

#### Advisory
- A1, C2 follow-up: Flow re-emits the phase it left on resume (flow GDD:260), so a pause and resume during Intermission sends a second `phase_changed(INTERMISSION)` with no wave cleared. ADR-0010's rule (adr-0010:167) is safe only if RunLog writes a call record when one is pending. Add that case to the RunLog tests.
- A2, pause under `in_dispatch()`: a guarded `pause()` that arrives while a tick or command is on the stack is refused (adr-0006:66, adr-0010:103) and the pause is lost. ADR-0004 holds that this cannot happen, owes device run V2 for it, and names a wrapper latch as the fallback (adr-0004:275). The two fit together, but if V2 fails the latch becomes required, not optional. This predates the fix round; it only restated it.
- A3: adr-0001:88 calls the `setup` argument "the only read" of `OS.is_debug_build()`, while adr-0001:92 and :190 read it again for the fatal screen's cause. Both reads are in `AppRoot`, so adr-0010:164 ("`AppRoot` is the only reader") holds. No lint enforces it.
- A4: adr-0006:66 still says "A refused guarded command ... reports through `dev_error`" without limiting it to `REENTERED`. ADR-0010 narrows it and lists the edit for acceptance (adr-0010:366). Unchanged from the last review.
- A5: `architecture.md` rows for TowerSim and B10 still write `early_call_bonus()` in their name lists; the signature at B8 is right.

### Coverage (Phases 2 and 3)

No GDD and no registry entry changed since the last report (the freshness check shows only ADR-0001, 0002, 0004, 0006 to 0011 and `architecture.md` as changed), so no requirement was added, reworded or removed.

Total requirements: 128
✅ Covered by an Accepted ADR: 10
🟡 Covered, resting on at least one Proposed ADR: 118
⚠️ Partial: 0
❌ Gaps: 0

Checked by script: 128 registered IDs, 136 citations in the ADRs' `GDD Requirements Addressed` tables, 0 unknown IDs, 0 uncited IDs. The fix round changed no table row's ID. The registry wording that trails its GDD (13 entries) and the rewordings the ADRs ask for at acceptance are as listed in `architecture-review-2026-11-05.md`.

`bash .claude/scripts/registry.sh validate`: tr 128, architecture 183; duplicate 0, tr_unknown 0, path_missing 0, status 0, layout 0. The validator checks form, so it does not see the two stale paths named above (D11 and N2).

### Coverage Gaps (no ADR exists)
None.

### ADR Dependency Order
`adr-dep-graph.sh`: 11 ADRs, 43 edges (36 before the fix round), one cycle (N1), no ADR without a dependencies section, none unfilled.

Order as emitted: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0009, ADR-0006, ADR-0008, ADR-0010. ADR-0007 and ADR-0011 are on the cycle and have no place until it is cut.

🔴 DEPENDENCY CYCLE: ADR-0007 → ADR-0011 → ADR-0007. With option 1 of N1 the order continues ADR-0007, then ADR-0011.

⚠️ Unresolved dependencies: as before, ADR-0004 to ADR-0011 each depend on at least one Proposed ADR. ADR-0002 and ADR-0003 depend only on the Accepted ADR-0001.

### GDD Revision Flags
None. No GDD assumption conflicts with verified engine behaviour, and the systems index was not changed.

---

### Engine Compatibility Issues
Engine: Godot 4.7.2 (pinned 4.7, installed 4.7.2.stable.official). The engine reference is unchanged since the last report.
ADRs with an Engine Compatibility section: 11 / 11
Engine specialist consulted: godot-specialist, on the fix round's text. It ran a headless probe on 4.7.2 in a scratch project outside the repo.

Version: all 11 name the same engine. Three wording forms now ("Godot 4.7.2 (pinned 4.7; installed ...)", "Godot 4.7 (installed 4.7.2...)", "Godot 4.7 (pinned; 4.7.2 installed at pin time)"); cosmetic.
Deprecated API references: none used, and the fix round added none.
Post-cutoff APIs: the fix round added none.

#### Engine claims the fix round added

| Claim | Result |
|---|---|
| `get_object().get_script().get_global_name()` returns the class name (adr-0006:28, adr-0007:231) | Confirmed by probe |
| `load()` of a `.tscn` with a missing `ext_resource` returns a non-null instantiable `PackedScene` (adr-0002:30, adr-0007:233) | Confirmed by probe: three `ERROR:` lines, `can_instantiate()` true, instance with a null script |
| The wrapper built twice in one process with `dev_telemetry` true and false (adr-0007:71) | Workable. Not run. The first wrapper must be freed with `free()` before the second is built, or both adapters stay connected to `Viewport.size_changed`; the test must inject `FakeRunLogSink`, or a headless run writes the real `user://run_log.jsonl` |
| Hand-built pointer events in `PointerEventFactory` (adr-0007:63) | Workable, with a trap: a hand-built touch or drag event has `device = 0`, a hand-built mouse button has the mouse device id, and emulated events use -1 (`modules/input.md`:95-96, :114). The factory must set `device` explicitly |
| L35 import direction by a bash script (adr-0007:113) | Workable: `--import` writes `.godot/global_script_class_cache.cfg` with class-to-path entries, which gives the script its map |
| L36 (adr-0007:114) against ADR-0011 | Matches the Must rule at adr-0011:201. It catches only a literal `for`/`while` body, not a helper called from a loop, and it leaves out `draw_polyline`, which adr-0011:131 also prices at one call per ring |

#### Prior engine findings (not in the fix round's scope)

| Finding | State |
|---|---|
| ADR-0001 Decision 4: a wrapper scene whose script fails to load comes back non-null, so the null check misses it (adr-0001:88, :228) | Open. No `has_method("setup")` or `get_script() != null` guard is stated. The probe confirms the instance has no script, so `setup()` fails outside the fatal path |
| ADR-0007: gdUnit4 exit code with no class cache | Acceptable as written: adr-0007:28 no longer treats the exit code as a gate, and `--import` is mandatory |
| ADR-0007: gdUnit4 6.2.0 installed, 6.2.2 in the reference | Open (adr-0007:57; `current-best-practices.md`:198, :204) |
| ADR-0011 V1: log the rendering driver and method on the device | Open (adr-0011:293) |
| ADR-0010 V3: JSON number printing | Can close: the probe prints ints as `1` and floats as `2.0`. adr-0010:329 still says "assumed". A count that passed through float maths prints `.0`, so the writer must `int()` it |
| ADR-0003 and ADR-0004: lifecycle notification timing has no device row; ADR-0004's long-run delta assumption | Open, unchanged |

Not verified: device or release-export behaviour, the Linux CI runner, and the double-wrapper test (reasoned, not run). The owed runs are as listed in `architecture-review-2026-11-05.md`; none was performed.

---

### Architecture Document Coverage
`docs/architecture/architecture.md` exists (v4). All 22 systems of `systems-index.md` appear in its system-to-layer table; the 8 MVP systems have modules, data flows and API blocks; no module lacks a GDD. This describes `architecture.md` at 5aea8df; the edits this run prepared for it were not merged (see the top).

Left as they are:
- B9 has no row for the Combat counter reads that ADR-0006 says the builder injects into Flow, because no ADR names those reads yet (StageResult row above).
- B4 still writes `seed` where ADR-0001 writes `rng_seed`; the InputAdapter row and Data Flow 5 keep their NEEDS VERIFICATION marks until the device runs.
- QQ-08 waits for acceptance; QQ-11, QQ-12, QQ-14, QQ-17 and QQ-22 are unchanged.

---

### Blocking Issues (must resolve before PASS)
1. N1: cut the ADR-0007 ↔ ADR-0011 cycle. Recommended: remove ADR-0010 and ADR-0011 from ADR-0007's Depends On.

Then, before accepting ADR-0007: N2 (L34's scope and the registry path).
Then, for PASS: accept ADR-0002 to ADR-0011 in dependency order.

### Recommended fixes, in one list

| # | File | Fix |
|---|---|---|
| N1 | adr-0007:34 | Drop ADR-0010 and ADR-0011 from Depends On; move the "supply rules" clause to the Ordering Note |
| N2 | adr-0007:112; `architecture.yaml`:1736 | L34 scope and registry path to `src/presentation/telemetry/` |
| N3 | adr-0011:88, :92 | List step b in ADR-0004's order; drop the empty step d |
| D11 | `architecture.yaml`:646-647 | `src/presentation/field/` and the matching tests folder |
| StageResult | adr-0006:94, adr-0009 Key Interfaces, `architecture.md` B9 | Name the injected reads; add a read that returns the by-id table, or have Flow receive the id list; add the B9 row for Flow |
| Field lint | adr-0007 Decision 7 | A rule for `material`, `z_index` and per-entity `modulate` under `src/presentation/field/`; either add the type-grouping lint or reword adr-0011:253 |
| Engine | adr-0001:88 | Guard the instanced wrapper with `has_method("setup")` before calling it, into `fatal()` |
| Cosmetic | adr-0001:88; adr-0004:55; adr-0010:329 | "the only read"; the stale local-copy note; V3 "assumed" |

### Required ADRs
None new. The eleven written ADRs cover all 128 requirements.

### Handoff
Pre-gate checklist: ✅ `tests/unit/` and `tests/integration/`; ✅ `.github/workflows/tests.yml`; ✅ `design/accessibility-requirements.md`; ✅ `design/ux/interaction-patterns.md`.

Next steps: none for this set, which is not in force. If it is ever revived, start with N1, N2 and N3 and the fix table above, then re-run `/architecture-review`.

Worth carrying to the live ADR set (not checked there by this review): whether its ADR-0007 and ADR-0011 depend on each other (N1), whether its run-log lint scopes the folder the run log is placed in (N2), whether its frame-order lists agree call for call (N3), and whether a wrapper scene whose script fails to load is guarded before `setup()` is called (the open engine finding on ADR-0001 Decision 4).
