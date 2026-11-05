## Architecture Review Report
Date: 2026-11-05
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
GDDs Reviewed: 8 (systems index and game concept read for context; the two `gdd-cross-review-*.md` files are review reports and add no requirements)
ADRs Reviewed: 11 (ADR-0001 Accepted, ADR-0002 to ADR-0011 Proposed)

Independence: this review ran in a session that did not author the ADRs. Freshness check: the prior report (`architecture-review-2026-11-04b.md`) covered 0 ADRs and all 11 are new, so the full review ran.

Reviewed-Content-Hash: docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md 626b686dd3dff5ce2e353ba7c05b32fe323a1c61
Reviewed-Content-Hash: docs/architecture/adr-0002-catalogue-storage-format-manifest-and-validation.md dd70920155be15e08ab7f3dda880e895134d1cfa
Reviewed-Content-Hash: docs/architecture/adr-0003-input-adapter-display-stretch-and-platform-lifecycle.md c8a97f26da9cc511994a035a348a28dcdb9abed9
Reviewed-Content-Hash: docs/architecture/adr-0004-fixed-tick-clock-tick-order-frame-order-and-determinism.md 7b24cb8e08d61246280ff90ab95b3381f30b0277
Reviewed-Content-Hash: docs/architecture/adr-0005-stat-accessor-and-read-context-contract.md f64b46ec9ac786883bd9e2bd2c267237bd72a5f1
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-signal-contracts-and-view-allowlist.md 904819b9e2f33677aabd46ce92a0a4acd1b79018
Reviewed-Content-Hash: docs/architecture/adr-0007-headless-test-harness-gdunit4-and-layer-lint.md bfb5d0c257983374a25f98dc5c6dff8e3b013b2d
Reviewed-Content-Hash: docs/architecture/adr-0008-input-resolver-core-and-signal-contract.md 8d483fbebf5f8cc05e23ea54f4b4ad451b092a2b
Reviewed-Content-Hash: docs/architecture/adr-0009-enemy-entity-roster-and-combat-api.md 7ee2b11ea784e4b1748155480b3d96d567770b98
Reviewed-Content-Hash: docs/architecture/adr-0010-sim-input-split-command-result-codes-and-dev-telemetry.md 3cce8487005e06e896e1da6cc8233795043d29ca
Reviewed-Content-Hash: docs/architecture/adr-0011-battle-field-rendering-and-draw-call-budget.md 2f265afad55a709bcebb47f7bd6a150f8da20c9d
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
Reviewed-Content-Hash: docs/architecture/architecture.md a4e7c8c4e806dab16d6ddfe0c57494746b1e7b8d
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

Three cross-ADR conflicts cannot both be implemented as written (C1, C3, C4 below). Each has a one-paragraph fix, none needs a new ADR, and two of them touch the Accepted ADR-0001, so they need the owner's sign-off. Nothing else blocks: every requirement has an ADR, the dependency graph has no cycle, and no engine finding is blocking.

What would move the verdict to CONCERNS: resolve C1, C3 and C4 in the ADR text. What would move it to PASS after that: accept ADR-0002 to ADR-0011 (118 of 128 requirements rest on a Proposed ADR).

### What this run changed

| File | Change |
|---|---|
| `tr-registry.yaml` | TR-combat-015, TR-hero-016 and TR-hud-018 appended at the end of their systems (version 5, 128 entries). Nothing renumbered or reworded. `registry.sh validate`: 0 duplicate, 0 unknown, 0 missing path, 0 status, 0 layout. |
| `adr-0004`, `adr-0010`, `adr-0011` | The "(provisional)" marks on those three IDs now read as registered (15 phrases). No decision text changed. ADR-0009 does not cite TR-combat-015; only ADR-0011 does. |
| `architecture.md` | 108 edits from the ADRs' sync lists (listed under Architecture Document Coverage). |
| `requirements-traceability.md` | Rebuilt from the ADRs' requirement tables. |

Left for `/architecture-decision accept`, as instructed: every GDD edit, every registry wording edit, the ADR-to-ADR edits in the sync lists, and the `docs/registry/architecture.yaml` stances.

---

### Traceability Summary
Total requirements: 128
✅ Covered by an Accepted ADR: 10
🟡 Covered, resting on at least one Proposed ADR: 118
⚠️ Partial: 0
❌ Gaps: 0

Every registered ID is cited in at least one ADR's `GDD Requirements Addressed` table (checked by script: 128 IDs, 136 citations, 0 unknown IDs). The ten ✅ are the requirements ADR-0001 covers without handing part to a Proposed ADR: TR-data-011, TR-state-001, -002, -009, -011, -015, -016, TR-enemy-005, TR-hero-004, TR-hud-006. The other seven in ADR-0001's table are 🟡 because a Proposed ADR decides part of each.

Structural notes on the tables (no coverage lost):
- TR-data-004, TR-data-006, TR-data-007, TR-data-009, TR-combat-007 and TR-tower-013 are partly decided in the text of an ADR whose table does not cite the ID (ADR-0002 Decisions 7 and 9; ADR-0009 and ADR-0010 for the `def_id` clause; ADR-0005's "Rule 10" and "Rule 9" rows; ADR-0007 Decision 5). The matrix marks these "(text)".
- ADR-0006's table quotes TR-state-008 and TR-enemy-004 with the old name `waves_complete`; the registry already says `waves_completed`.
- ADR-0011 Decision 16 decides Enemy & Wave criterion 57 (the danger rule), which has no TR.

#### Requirement delta since the last review (Phase 2)
All eight GDDs changed after commit a8865ab (signal renames, review fixes, balance and visual text). No requirement was removed, so nothing is proposed for deprecation.

Registry wording that trails its GDD, same intent, ID kept (apply at acceptance):

| ID | What is stale |
|---|---|
| TR-state-007 | Emit order: Flow checks the Fatal latch after acting and after each emit; says `phase`, GDD says `phase_changed` |
| TR-state-008 | "emits lives_changed, phase" should read `phase_changed` |
| TR-state-009 | Does not say `remove_child` plus `free()` on the old wrapper, not `queue_free` |
| TR-state-015 | Missing "method Callables only, never a capturing lambda or `bind()`" |
| TR-input-004 | "one lifecycle signal": the GDD has `lifecycle_paused()` and `viewport_resized()` |
| TR-input-013, TR-hud-002 | "consume every event before the adapter": modals stop presses only; moves and releases of a live gesture still reach the adapter |
| TR-hero-010 | "each frame": the disc moves on every position change, seen in `update()` |
| TR-hero-011 | `cooldown_digit()` is computed on read; `button_press()` advances in `update()` |
| TR-tower-011 | "closes the chip on phase" should read `phase_changed` |
| TR-hud-001 | Build order is resolver, TowerInput, HudLogic, HeroInput, then views |
| TR-hud-003 | Paused has no arming; a result screen ignores a second pointer |
| TR-hud-010 | `burst_wedge` is now `burst_fill`, read at use; `phase` should read `phase_changed` |
| TR-data-005 | Exactly one Input record; the slop cross-check runs only when both values are valid |

Rewordings the ADRs themselves ask for at acceptance: TR-input-002, -005, -006, -016 and TR-hud-002 (ADR-0003); TR-input-007 and TR-input-011 (ADR-0008); TR-combat-011, TR-enemy-015 and TR-hud-017 (ADR-0011).

Candidate requirements not registered (logged decision; nearest entries cover them and the ADRs already decide them): "Battle exposes to the wrapper what only the builder holds" (nearest TR-hero-004; ADR-0001 Decisions 3 and 4) and "HudLogic is Node-free, injected, emits `modal_changed`" (nearest TR-hud-001, -003, -012; ADR-0006 Decision 12). Fold them into those entries' wording at acceptance.

TR-hud-018 was registered with the GDD's wording ("Fatal drops it"). ADR-0010's stronger clause ("Fatal drops both records, including a Won record buffered in the same tick") is in the `architecture.md` row, not in the registry, because it comes from the ADR and not from the GDD.

### Coverage Gaps (no ADR exists)
None.

---

### Cross-ADR Conflicts

Known conflict-prone areas: none on record (`docs/consistency-failures.md` does not exist, so nothing was appended to it).

The three blocking claims were re-read against the ADR text in this session before being listed.

#### 🔴 C1: ADR-0006 vs ADR-0011. `damage_applied` observers
Type: Integration contract (observer allowlist)
ADR-0006 claims: the `damage_applied` row lists "Combat view, audio (Alpha)" (adr-0006:86), and "a view that is not in the table is not wired" (adr-0006:104).
ADR-0011 claims: "`EnemyView extends Node2D` owns an `EnemySlots`, connects `damage_applied` only" (adr-0011:190); `EnemyView.on_damage_applied` marks kills (adr-0011:77).
Impact: the wiring test of ADR-0006 Decision 10 and ADR-0007 Decision 5 fails on `EnemyView`; left unwired, kills draw as leaks. ADR-0006 delegates "their rows in the Observer table" to ADR-0011, and ADR-0011 has no observer table and says views listen only to ADR-0006's allowlist, so the row exists in neither.
Resolution options:
  1. Add `EnemyView` to ADR-0006's `damage_applied` row. (Recommended)
  2. Route `mark_killed` through the Combat view, which is already on the list.

#### 🟡 C2: ADR-0006 vs ADR-0010. RunLog's trigger for the call record (not blocking)
Type: Integration contract, unstated
ADR-0006 claims: `wave_cleared` has one listener, Flow (adr-0006:83); RunLog is listed on `phase_changed`, `lives_changed`, `wave_called_early` and `gold_changed` only.
ADR-0010 claims: "A call record is written at the next `wave_cleared` or outcome" (adr-0010:160), without naming the signal RunLog connects.
Impact: a literal reading needs a `wave_cleared` connection that the allowlist does not have.
Resolution options:
  1. ADR-0010 states that RunLog keys on `phase_changed(INTERMISSION)`, already allowlisted. (Recommended; no ADR-0006 edit)
  2. Add RunLog to the `wave_cleared` row.

#### 🔴 C3: ADR-0001 (Accepted) vs ADR-0010. Is a `HALTED` return a dev error?
Type: Error-path contract
ADR-0001 claims: "A defect the design says must not halt the battle (Enemy & Wave's `start_next_wave()` in the wrong state, Tower and Hero `HALTED` returns) goes to the injected `dev_error(msg)`" (adr-0001:96).
ADR-0010 claims: "Only `REENTERED` is a dev error raised by the sim; `HALTED`, `NO_GOLD` and the pure refusals are ordinary results and report nothing" (adr-0010:94). It says this narrows ADR-0006, and does not mention ADR-0001.
Impact: a spy `dev_error` test passes under one ADR and fails under the other.
Resolution options:
  1. Amend ADR-0001 Decision 8 so `HALTED` is an ordinary result (it is expected after Won or Lost, and reporting it would flood the sink). Needs the owner's sign-off because ADR-0001 is Accepted. (Recommended)
  2. Make ADR-0010 report `HALTED`.

#### 🔴 C4: ADR-0007 vs ADR-0010 and ADR-0001. Where the dev-telemetry flag comes from
Type: Integration contract (wrapper `setup`)
ADR-0007 claims: "the wrapper takes its dev flags (RunLog, GestureLog on or off) as a `setup()` argument, not from a feature tag, so the same test builds the dev and the release-shaped wrapper in one process" (adr-0007:70).
ADR-0010 claims: "The wrapper decides once: `RunLog` exists only when `OS.is_debug_build()` is true" (adr-0010:157).
ADR-0001 claims: `func setup(battle: Battle) -> void` (adr-0001:170).
Impact: `OS.is_debug_build()` has one value per process, so ADR-0007's per-build wiring test cannot build both shapes, and ADR-0001's signature has no slot for the flag.
Resolution options:
  1. `setup(battle, dev_telemetry: bool)`, with `AppRoot` passing `OS.is_debug_build()`. Amends ADR-0001 Key Interfaces (owner's sign-off) and ADR-0010 Decision 13. (Recommended)
  2. Drop ADR-0007's one-process requirement and prove the release shape only in an export.

#### Drift (one ADR is clearly authoritative; fix the other's wording)

| # | Where | Drift | Authoritative |
|---|---|---|---|
| D1 | adr-0004:106, :351 | The command guard is still called `in_tick`; ADR-0006 injects `in_dispatch` (adr-0006:283) | ADR-0006 |
| D2 | adr-0004:107-109, adr-0011:88 | Frame step b lists `ChipWindow.advance` and `HeroInput.update()` "and nothing else"; ADR-0010 has the wrapper call `TowerInput.advance`, `RunLog.advance` and `RunLog.flush` (adr-0010:144, :159) and never names `update()`, which TR-hero-011 requires | ADR-0010 for the calls; ADR-0004 for `update()` |
| D3 | adr-0011:90-91 | The wrapper loops the owed ticks itself; ADR-0004 has `Clock.advance(delta)` run them (adr-0004:110) | ADR-0004 |
| D4 | adr-0011:95, :147, :197 | `early_call_bonus()` with no argument and `slot_state()`; ADR-0010 has `early_call_bonus(seconds_left)` and `slot_count()`/`tower_at()` (adr-0010:187, :338) | ADR-0010 |
| D5 | adr-0006:66, adr-0008:134 | Flow command `start` (and `Hero.pin`, `Tower.build`, Flow `start`/`call`); ADR-0010 and ADR-0004 say `start_wave`, `HeroSim`, `TowerSim` (adr-0010:46, :154; adr-0004:320) | ADR-0010 |
| D6 | adr-0004:95 | Slot 1 lists "clear checks"; the clear is in slot 6 (adr-0009:165, adr-0006:71) | ADR-0009 |
| D7 | adr-0002:108 | The one-tick floor is a local `1/60`; ADR-0004 points it at `TickRate.DT` (acknowledged in adr-0004:55) | ADR-0004 |
| D8 | adr-0006:94, :114 | Cites "ADR-0009 Decision 12" for the damage counters; they are Decision 8 | ADR-0009 |
| D9 | adr-0009:171, :52 | A mechanical rename left "QQ-07 may rename it (for example `waves_completed`)" | ADR-0006 |
| D10 | adr-0010:157 vs :159 | Inside one ADR: RunLog is passed "into `HudLogic`", then "`HudLogic` is unaware of `RunLog`" | the second |
| D11 | adr-0011:83 | `ClearanceWindow` sits in `src/presentation/combat_view/` while the views are in `src/presentation/field/`; ADR-0010 says HudLogic "keeps the path ADR-0011 gives it" (adr-0010:84) and ADR-0011 gives none | decide in ADR-0011 |
| D12 | adr-0008 Ordering Note; adr-0006:28; adr-0002:30 | Stale notes: ADR-0007 now has the `InputEvent`/`Time` lint (L31), `get_global_name()` was observed (ADR-0007 V7), and the broken-scene half of ADR-0002's `load()` item is closed by ADR-0007 V9 | ADR-0007 |

#### Settled points

| Point | Holds in every ADR? | Exceptions |
|---|---|---|
| `in_dispatch()` = `in_tick()` or any sim's `in_command()` | No | D1: adr-0004:106 and :351 still name `in_tick` as the guard |
| `NONE = -1` | Yes | defined at adr-0008:63, :165 only |
| `pin` and `burst` take `Vector2` | Yes | adr-0010:115, :196-197 |
| The last wave emits `waves_completed` only | Yes | adr-0006:71, adr-0009:165/170 and adr-0004:102 agree; D6 is the slot-1 wording |
| `MAX_TICKS_PER_FRAME = 3`, floor 2 | Yes | adr-0004, adr-0009:142, adr-0011:132 |
| `tapped`, `ground_tapped`, `became_idle`, `waves_completed`; `pressed` kept | Yes in every declaration | D9: one garbled sentence at adr-0009:171 |

Old-name leftovers: every hit for `waves_complete`, `tap`, `ground_tap`, `idle` and `src/core` in the ADRs is a deliberate "renamed from" mention inside ADR-0006, except adr-0009:171 (D9). `adr-0007:204` is the gdUnit4 addon's own `src/core` path.

Not found, so not counted as a conflict: no ADR states how Flow reaches Combat's counters to fill `StageResult`; no ADR gives per-system memory figures, so there is nothing to sum against 256 MB. The frame slices in ADR-0004 sum to 16.6 ms and ADR-0011 totals 27 of 60 draw calls.

#### Delegation closure ("Delegates To" taken up by the named ADR)
About 139 delegated items were checked in three passes. About 132 are taken up at a line the target ADR can be quoted for. The rest:

| From → To | Item | State | What closes it |
|---|---|---|---|
| 0003 → 0007 | PointerGate fixtures | Dropped: ADR-0007 has no `PointerGate`, `DisplayContract` or `read_pointer` | A fixture and unit-test entry in ADR-0007 Decisions 2 and 7 |
| 0004 → 0009 | The name of the range-check file the float lint covers | Dropped: ADR-0009 names no lint file; ADR-0010 fills L16 with `pin_geometry.gd` and `hero_sim.gd` only | Say whether L16 also covers `combat.gd` and `path_track.gd`; as written their range checks are outside the `Vector2` lint |
| 0010 → 0007 | Decision 12 (b) single-writer rows for `Tower`, `Hero`, `_in_command`; (c) `src/battle/` never names `TowerInput`, `HeroInput`, `RunLog`; (d) `run_log.gd` and `gesture_log.gd` never touch `OS`, `Time`, `FileAccess` or a command | Dropped: no such rows in L01 to L31, and ADR-0010's sync list does not add them | Three rule rows in ADR-0007 Decision 7 |
| 0006, 0002 → 0007 | "The layer lint covers `src/battle/` naming nothing under `src/presentation/` or `src/app/`"; the `src/data/` import direction | Dropped: L02 and L30 check `extends` only; there is no import-direction rule | One script-kind rule with a fixture |
| 0010 ↔ 0006 | Flow's own command result enums | Circular: ADR-0006 hands result codes to ADR-0010 (adr-0006:37); ADR-0010 hands Flow's back as "ADR-0006 follow-up" (V8, adr-0010:327). No ADR defines them, so QQ-18 stays open | One of the two decides `OK = 0`, `HALTED`, `REENTERED` plus Flow's refusals |
| 0006 → 0011 | View rows in the Observer table | Taken up differently: this is C1 | See C1 |
| 0002 → 0010 | The burst-line constant behind the HUD content row | Partial: `BUTTON_RADIUS = 48` exists; nothing says it is that constant | One sentence in ADR-0010 |
| 0008 → 0007 | One listener per id-bearing resolver signal per owner class | Taken up differently: ADR-0007 checks per signal against a table | One sentence in ADR-0007 Decision 5 |
| 0008 → 0011 | Rings and chip "react to `pressed`, `tapped`, `ground_tapped`" | Taken up differently: ADR-0011 polls state through the redraw key | Reword ADR-0008 ("read", not "react to") |
| 0011 → 0007; 0010 → 0007 | The field-view lint; L16's file list and bot ids; evidence naming at adr-0007:118 | Pending: listed as sync edits, not yet in ADR-0007 | Apply at acceptance |
| 0005 → future ADR | The modifier resolver | Target does not exist; Vertical Slice | Nothing now |

Depends On rows match the machine-built edge list for all 11 ADRs. Advisory: ADR-0010 omits ADR-0003 (which lists it under Enables); ADR-0011 omits ADR-0001 and ADR-0007; ADR-0007 takes lints from ADR-0003 and ADR-0008 without listing them; ADR-0006 and ADR-0007 depend on the later-numbered ADR-0009 with no ordering note; ADR-0001's Enables omits ADR-0005.

Not checked in the delegation passes: the fixtures behind ADR-0009's lints in ADR-0007; whether ADR-0007 has an injected-callable lint beyond L03; the command-script format fields.

### ADR Dependency Order
`adr-dep-graph.sh`: 11 ADRs, 36 edges, no cycle, no ADR without a dependencies section, none unfilled.

Recommended acceptance and implementation order (as emitted):
1. ADR-0001 App Lifecycle (Accepted)
2. ADR-0002 Catalogue (requires 0001)
3. ADR-0003 Input Adapter (requires 0001)
4. ADR-0004 Fixed-Tick Clock (requires 0001, 0003)
5. ADR-0005 Stat Accessor (requires 0001, 0002)
6. ADR-0009 Enemy Entity and Combat API (requires 0001, 0002, 0004, 0005)
7. ADR-0006 Battle Signals (requires 0001, 0002, 0004, 0005, 0009)
8. ADR-0007 Test Harness (requires 0001, 0002, 0004, 0005, 0006, 0009)
9. ADR-0008 Input Resolver (requires 0001, 0002, 0003, 0006)
10. ADR-0010 Sim/Input Split (requires 0001, 0004, 0005, 0006, 0008, 0009)
11. ADR-0011 Field Rendering (requires 0003, 0004, 0006, 0009, 0010)

⚠️ Unresolved dependencies: ADR-0004 to ADR-0011 each depend on at least one ADR that is still Proposed, so none of them can be safely implemented until those are Accepted. ADR-0002 and ADR-0003 depend only on the Accepted ADR-0001. ADR-0004 and ADR-0008 also hold ADR-0003 as a provisional premise until its device runs D1 and D3 pass.

### GDD Revision Flags
None. No GDD assumption conflicts with verified engine behaviour, and the systems index was not changed. The GDD wording edits the ADRs list for acceptance are clarifications, not contradictions.

---

### Engine Compatibility Issues
Engine: Godot 4.7.2 (pinned 4.7, installed 4.7.2.stable.official)
ADRs with an Engine Compatibility section: 11 / 11
Engine specialist consulted: godot-specialist (findings below are its, merged with the audit).

Version: all 11 name the same engine. Two wording forms ("Godot 4.7.2 (pinned 4.7…)" in ADR-0001 to 0005, "Godot 4.7 (installed 4.7.2…)" in ADR-0006 to 0011); cosmetic.
Deprecated API references: none used. ADR-0003 forbids `event.device == 0`; ADR-0002 rejects `duplicate_deep()`; ADR-0009:154 calls `duplicate()` on a flat `Dictionary`, which is not the deprecated nested-resource form.
Post-cutoff APIs: few and consistent (`FileAccess.store_line` returning `bool`, typed `Dictionary`, `GDScript.can_instantiate()`); no two ADRs disagree. The 4.7 typed-return override rule is handled the same way in the six ADRs that touch it. Input flushed before `_process` is assumed identically by ADR-0003, ADR-0004 and ADR-0008, and all three owe it to device run D1.

#### NOT SOURCEABLE claims and their Verification rows
58 marked lines were enumerated. ADR-0004 (7 claims), ADR-0005, ADR-0006, ADR-0007, ADR-0008 and ADR-0009: every claim maps to a Verification or device-run row. Claims with no row:

| ADR | Claim | Severity |
|---|---|---|
| ADR-0003 (431-438) | When a lifecycle notification is dispatched relative to `_process`: no device row records it (D9a is desktop launch only; D5 records order, not frame; ADR-0004 V2 checks it indirectly). ADR-0003 Decision 8 and ADR-0004 Decision 9 lean on it | CONCERN |
| ADR-0004 (337) | "Nothing above depends on any of them being true", but the accumulator's drop rule assumes `_process` delta tracks wall time over the long run; that was observed on desktop only and V5 records first-frame and resume deltas, not the long-run sum | CONCERN |
| ADR-0003 | The value of an absent stretch key; `keep_width` and the field-origin offset; the role of `get_canvas_transform()`. None is used | ADVISORY |
| ADR-0002 (29-32) | `Thread` (unused until verified); `Dictionary` type strictness, `String`/`StringName` keys and `Vector2` precision have no export re-run | ADVISORY |
| ADR-0010 | V4 (`build_id`) has a row but no run, only "add a story" | ADVISORY |
| ADR-0001 | No NOT SOURCEABLE section; its release-unverified claims sit inline and map to Verification 1 to 4 | ADVISORY |

#### Engine Specialist Findings
- CONCERN, ADR-0001 Decision 4 (adr-0001:88): the wrapper and stage scenes are loaded with `load()` and a null check into `fatal()`. ADR-0001's own probe row and ADR-0007 V9 show a scene whose script fails to parse comes back non-null as a bare node, so the null check catches only a missing file and `setup(battle)` then raises a script error instead of `fatal()`. Add a guard such as `instance.get_script() != null` or `has_method("setup")`. ADR-0002 item 5 inherits this.
- CONCERN, ADR-0007:28: "GdUnitCmdTool with no class cache exits 0" was measured through a pipe; the engine reference records exit 1 before the first import. ADR-0007's mitigation (mandatory `--import`, never trusting the exit code alone) is safe either way, but the recorded fact is unreliable. A raw re-run was not possible in this review.
- CONCERN, ADR-0007:57: gdUnit4 6.2.0 is installed; the reference's only 4.7.2 evidence is with 6.2.2, so the exit-code facts ADR-0007 takes from it were not observed on the installed version.
- CONCERN, ADR-0011: the draw-call rules were observed on the Mobile renderer on macOS. The target class (Adreno 5xx) may run or fall back to the Compatibility canvas renderer, whose batching differs. V1 should log `RenderingServer.get_current_rendering_driver_name()` and the rendering method on the device.
- ADVISORY, ADR-0010 V3: checked on 4.7.2 headless, `JSON.stringify({"a":1,"b":1.0})` gives `{"a":1,"b":1.0}`. Any count that came from catalogue JSON is a float and prints `1.0`; the telemetry writer must `int()` it.
- ADVISORY, ADR-0011 Decision 11: about 384 `draw_primitive` calls per enemy redraw from GDScript; one `canvas_item_add_triangle_array` or `draw_mesh` is the fallback if V9 misses 3.0 ms.
- ADVISORY, ADR-0006 row 7: a duplicate `connect` prints an error and returns `ERR_INVALID_PARAMETER`; a double `setup()` is caught only by the wiring test.
- No misuse of `_physics_process`, no `RefCounted` cycle pattern and no `mouse_filter` ordering error was found.

Not verified: a raw gdUnit4 exit code with no import; the Compatibility-renderer fallback behaviour; the GDD line numbers behind the specialist's GDD names.

#### Owed runs (probes ran on the desktop debug editor, macOS arm64, only)
Listed, not performed.

Android release export
- ADR-0001 V1: Callable and signal lifetime, `push_error` prints, whether a dead `.call()` aborts. V2: the fatal scene renders with a null catalogue. V4: the object-count retry check.
- ADR-0002 V1: the manifest loads to Ready with every file readable. V2: an invalid record gives the fatal screen and no `user://` file. V3: the JSON probe rows repeat. V4: median load at most 1000 ms over 5 cold launches on an Adreno 5xx. V5: the starter stage's `scene_ref` loads.
- ADR-0005 V1: median `stat_float` read within 2.5 µs on an Adreno 5xx. V2: `weakref` releases the entity.
- ADR-0006: probe rows 1 to 8 repeated on a release template before acceptance.
- ADR-0007 V10: tests, addons and tools are excluded from the export; the wiring test repeated inside a release export.
- ADR-0008 V3: P1 to P5 give the same booleans.
- ADR-0009 V1: shared with ADR-0001 V1. V2: `MAX_TICKS_PER_FRAME` × p99 tick cost at most 4.0 ms.
- ADR-0010 V1: `OS.is_debug_build()` is false and no `run_log.jsonl` exists. V10: no bot class in the APK.

Android debug export
- ADR-0010 V2: the `user://` append works and `write_lines` returns true. V12: `user://` exists on a fresh install.

Android and iOS devices
- ADR-0003 D1 to D10 on both: input before `_process`; index, `canceled` and reuse; STOP over a gesture; a hidden Control; lifecycle notifications per cause; safe area, bars and dp; edge margin; `free()` with a finger down (closes ADR-0001 V3); no Paused on launch; no mouse echo. QQ-22 closes when D1 to D4 pass on both.
- ADR-0004 V1: input log precedes `_process`. V2: `Clock.is_ticking()` false over 20 background cycles. V3: release-export tick cost, then set the cap, never below 2. V5: first-frame and resume deltas. V6: `get_ticks_usec` resolution.
- ADR-0008 V5: lost-move coalescing (with D1 and D2).
- ADR-0011 V1: worst screen at most 60 draw calls, HUD at most 12, a `Label` is 1 call. V3: ring look, art-director sign-off. V5: judder at 30, 60, 90 and 120 Hz. V8: `save_png` captures the letterboxed frame. V9: views and HUD p99 at most 3.0 ms with 48 enemies. V14: MSAA 2D within 3.0 ms, or dropped.

x86_64 desktop and the CI runner
- ADR-0004 V4 (also on Android and iOS): RNG values, `roundi`, 32-bit `Vector2`, unix time as a float, `OS.get_name()` and the architecture name.
- ADR-0007 V1: the import lists the classes. V2: the Linux strings. V8: fresh-clone parse check and `uid://`. V11: `python3` present. V12: clean `ERROR:` count. Probe rows 1 to 3 repeated on the Linux runner before acceptance.

Desktop, windowed
- ADR-0003 D9a: a focused cold launch shows no Paused.

---

### Architecture Document Coverage
`docs/architecture/architecture.md` exists (v4). All 22 systems of `systems-index.md` appear in its system-to-layer table; the 8 MVP systems have modules, data flows and API blocks; the 14 later systems are reserved slots. No module lacks a GDD.

Edits applied from the ADRs' sync lists (108 replacements, each matched exactly once):
- Folders: the four roots `src/app/`, `src/battle/`, `src/presentation/`, `src/data/`; B0 paths moved off `src/core`, `src/foundation`, `src/feature`, `src/root`.
- B0: `CatalogueLoadResult`, `CatalogueError` (`field: String`), records as `RefCounted` with `def_id`, `ReadContext.live_entity` as a `WeakRef`, `def_id` and `distance` on `Targetable`, `DamageEvent`'s reserved `granted_by`.
- B1: a bad call's return value is unspecified. B2: `Kind`, `State`, `NO_POINTER`, `dev_error`, the new `register` signature and four reads. B3: Decisions 1 to 9 of ADR-0003 replace the NEEDS VERIFICATION block. B6: the guard codes. B7: the stale QQ-07 comment. B8: `OK = 0`, `REENTERED`, `slot_count()`/`tower_at()`, the precision rule. B10: the HeroSim and TowerSim reads.
- Module Ownership: Catalogue, Validator, StatAccessor, InputResolver, TowerSim, HudField, HeroInput, TowerInput, ChipWindow, field views, RunLog/GestureLog, BattleWrapper.
- Data Flow 1 (step 1, step 4, the cap), 3 (`tower_id`), 4 (`load_from`), 6 (the notification table), 9 (dev-build gate and flush), 10 (27 draw calls).
- ADR Audit and Traceability Coverage Check; the Required ADRs table (status and real Depends On) and the ADR-0002, 0003, 0004, 0006, 0007, 0010, 0011 paragraphs; the Priority paragraph.
- Open questions: QQ-01, -02, -03, -04, -05, -10 closed; QQ-13, -15, -16, -21 resolved; QQ-06 desktop part closed; QQ-12 and QQ-22 stay open with the hand-off noted.

Left as they are, on purpose:
- The HeroInput row keeps `update()` (TR-hero-011 and ADR-0004 require it; ADR-0010's sync line dropped it, see D2).
- QQ-18 still names ADR-0010, but no ADR defines Flow's result enums (see the delegation table).
- QQ-08 waits for acceptance; QQ-11, QQ-14 and QQ-17 are unchanged.
- B4 still writes `seed` where ADR-0001 writes `rng_seed`; the InputAdapter row and Data Flow 5 keep their NEEDS VERIFICATION marks until the device runs. No sync list asks for these.

---

### Blocking Issues (must resolve before PASS)
1. C1: add `EnemyView` to ADR-0006's `damage_applied` observers (or route kills through the Combat view).
2. C3: decide whether a `HALTED` return reports through `dev_error`; amend ADR-0001 Decision 8 or ADR-0010 Decision 2.
3. C4: decide where the wrapper's dev-telemetry flag comes from; amend ADR-0001's `setup` signature and ADR-0010 Decision 13, or ADR-0007 Decision 5.

Then, for PASS: accept ADR-0002 to ADR-0011 in the order above.

### Required ADRs
None new. The eleven written ADRs cover all 128 requirements. Amendments are needed, not additions: C1, C3 and C4 above, C2's one sentence, Flow's result enums (ADR-0006 or ADR-0010), and the missing lint rows in ADR-0007.

### Handoff
Pre-gate checklist: ✅ `tests/unit/` and `tests/integration/`; ✅ `.github/workflows/tests.yml` (ADR-0007 Decision 8 rewrites it through `/test-setup`); ✅ `design/accessibility-requirements.md`; ✅ `design/ux/interaction-patterns.md`.

Next steps, in order:
1. The owner decides C3 and C4 (both touch the Accepted ADR-0001).
2. A fix round on ADR-0004, 0006, 0007, 0008, 0009, 0010 and 0011 for C1, C2 and the drift table, in an authoring session.
3. `/architecture-decision accept` per ADR in dependency order; it applies the GDD and registry wording edits.
4. Re-run `/architecture-review` in a fresh session after the fix round.
