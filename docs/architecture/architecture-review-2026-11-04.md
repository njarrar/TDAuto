## Architecture Review Report
Date: 2026-11-04
Mode: full
Workflow: full (project tier); all 8 reviewed GDDs carry a `standard` system override in `project.yaml`
Engine: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D)
GDDs Reviewed: 8 (systems index, game concept and the cross-GDD review read for context; no requirements drawn from them)
ADRs Reviewed: 8 (ADR-0001 to ADR-0008, all Accepted)
Reviewer: a fresh `/architecture-review` pass, autonomous mode. This reviewer wrote none of the ADRs and judged them on what the files say.

Reviewed-Content-Hash: docs/architecture/adr-0001-app-lifecycle-composition-root-fatal-path.md 1de2a3c82b6137f051cd26dea3f1b86e91af5eca
Reviewed-Content-Hash: docs/architecture/adr-0002-catalogue-storage-format-manifest-validation.md 3372caf60c16a5db09026b618700f0d0d7fd4fa7
Reviewed-Content-Hash: docs/architecture/adr-0003-input-adapter-display-stretch-platform-lifecycle.md 5645e0a897726103b9afb654a4139997f9daf0d0
Reviewed-Content-Hash: docs/architecture/adr-0004-fixed-tick-clock-tick-order-frame-order-determinism.md 72a71a54dfdcb32a3e0740b9f39b07cfdc43df11
Reviewed-Content-Hash: docs/architecture/adr-0005-stat-accessor-read-context-contract.md 4b4c52f58f60f8ce1909e345fdddb630261079ad
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-signal-contracts-view-allowlist.md d1951c68c69462ff8c3d354129ce1cc1d86f6282
Reviewed-Content-Hash: docs/architecture/adr-0007-headless-test-harness-gdunit4-layer-lint.md 020d2ee6364ae254a5cff21234764a6983f11dac
Reviewed-Content-Hash: docs/architecture/adr-0008-input-resolver-core-signal-contract.md ebea45aa022ce4234586a383b7a0e410501336f3
Reviewed-Content-Hash: design/gdd/battle-hud.md 7e937906274db58faf635115e241779eee1fa8ad
Reviewed-Content-Hash: design/gdd/combat-damage.md a0efb5b45cc5545ffa2118e6a309c0fca4735c42
Reviewed-Content-Hash: design/gdd/data-config-pipeline.md 9812e1460eafaa01e9901016a0aa0b819b9a8970
Reviewed-Content-Hash: design/gdd/enemy-wave.md 948f639c78e20280eb7abc3a91749a256fc41d1c
Reviewed-Content-Hash: design/gdd/game-concept.md 69276bc59133ed1fc4125a561b829e3bd7eb4156
Reviewed-Content-Hash: design/gdd/game-state-stage-flow.md 95a7dd6f795ac4ecf6f7a9d06f57cd2015aaa3b5
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md 7b9dc10d39366084b506416339d377adc20fb3ec
Reviewed-Content-Hash: design/gdd/hero-system.md 998a0e6f9e345ba6136b03bad32f05730ea8685c
Reviewed-Content-Hash: design/gdd/input-gesture-resolver.md 4e034772ff47e826f54e2e71a40c11e00b0a8fd4
Reviewed-Content-Hash: design/gdd/systems-index.md 04ed8ca4e409f7c290fd501c9ef8710f737245b5
Reviewed-Content-Hash: design/gdd/tower-system.md 6f03a5473e1c8444e3020dbb0b0d36866fddec19
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 7275883f22e8a0b4d01cce3a99a1ba50ea98f265
Reviewed-Content-Hash: docs/architecture/architecture.md 8b2f528453184cd091edb86e4e58a6f94b933eaa
Reviewed-Content-Hash: docs/engine-reference/godot/VERSION.md fcf85779788e0facbeca26aeda9fd41955e2633e
Reviewed-Content-Hash: docs/engine-reference/godot/breaking-changes.md 4bc55e16796664ff88c7582c9f08e3530f7c94d4
Reviewed-Content-Hash: docs/engine-reference/godot/current-best-practices.md a45cd2c39a8ec53eaa3e924f39f93594e62085fd
Reviewed-Content-Hash: docs/engine-reference/godot/deprecated-apis.md 6a1353983e1db0d7bc0cc41a568b039495b5413c
Reviewed-Content-Hash: docs/engine-reference/godot/probe-results.md 2a39a0315bb72eeca8680e1933e07a90e57192c0
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
Prior report: `architecture-review-2026-11-03b.md` (Mode full, Workflow full, FAIL). It covers this run's mode and tier. The check found no `UNRESOLVED` line and these changes:

- `NEW`: all eight ADRs; `docs/engine-reference/godot/probe-results.md`.
- `CHANGED`: seven GDDs and the systems index; `tr-registry.yaml`; `architecture.md` (now v5).
- `UNCHANGED`: the rest of the engine reference, `project.yaml`, `technical-preferences.md`, this skill.

New ADRs warrant a full run, so the prior report was not stood on (decision logged).

### How the inputs were read
- Every file over 40 KB was read by section (Grep for headings, then ranges): ADR-0001, ADR-0003, ADR-0007, `architecture.md` and four GDDs. No whole read of any of them.
- ADRs: Status, Summary, Engine Compatibility, ADR Dependencies, Decision (ADR-0004, ADR-0006 in full; others by section), GDD Requirements Addressed, Performance Implications, Amendments.
- GDDs: the registry already held 121 requirements checked by the last two reviews. This run read every GDD change since the second review (`git diff bdf48cc..HEAD -- design/gdd`, 347 changed lines) and matched each change against the registry. Unchanged GDD text was not re-extracted.
- No stories exist (`production/epics/` is absent), so Phase 3b (story and test linkage) did not run.
- `docs/consistency-failures.md` does not exist, so there are no known conflict-prone areas to surface.

### Traceability Summary
Total requirements: 123 (121 registered at the last review, plus 2 new)
✅ Covered: 84 (all by Accepted ADRs; 3 split across two Accepted ADRs)
🟡 Covered (Proposed): 0
⚠️ Partial: 7
❌ Gaps: 32

By requirement layer tag: Foundation 55 (50 covered, 4 partial, 1 gap), Core 45 (19 covered, 1 partial, 25 gaps), Feature 3 (2 covered, 1 partial), Presentation 20 (13 covered, 1 partial, 6 gaps).

Registry changes (no renumbering, no deprecations, no provisional IDs in `architecture.md`):
- **New** TR-data-016: the load fails with `record_count` unless there is exactly one Input record and one Hero record (Data Rule 7). Covered by ADR-0002 Decision 5, Tier 0b. Engine risk LOW.
- **New** TR-input-017: `cancel()` has three callers (adapter; Flow through `cancel_input()`; AppRoot at teardown), and a stale release after a non-adapter cancel is dropped in Idle (Input Rule 7). Covered by ADR-0001 Decision 7 (QQ-20) and ADR-0003. Engine risk LOW.
- **Revised** TR-input-009: signal names now `tapped`, `ground_tapped`, `became_idle` (the GDDs took ADR-0006's renames).
- **Revised** TR-hud-011: arc open and `gold_changed` only mark costs dirty; the read happens in frame step 3, never in a sim signal handler (HUD Rule 7, ADR-0005).
- **Revised** TR-hero-014: the one-Hero-record rule left the content test for the boot check (now TR-data-016).
- **Revised** TR-data-013: the content test also fails an omitted data file, a manifest path with the wrong case and a repeated JSON key (Data Rule 9).

Grading differs from `architecture.md` v5 (84 full, 5 partial, 32 gaps of 121) in two rows. This review grades them Partial, since each covering ADR names a part that ADR-0010 owns and ADR-0010 is not written:
- TR-tower-006: ADR-0001 gives `halted()`; "all stats read before any mutation" is "enforced by ADR-0010's command contract".
- TR-hud-010: ADR-0006 covers the signals ("Full for signals"); the view-only query surface is B10, owned by ADR-0010.

The seven Partial rows and who owns the rest:

| TR | Covered now | Rest owned by |
|---|---|---|
| TR-data-003 | ADR-0002 manifest, export filter, X1 | ADR-0002 X2, Android export proof (Technical Setup) |
| TR-data-015 | ADR-0002 small synchronous load | ADR-0002 P1, P2 device timings |
| TR-input-006 | ADR-0003 edge margin and safe-area insets | Mobile Platform GDD (does not exist) |
| TR-input-014 | ADR-0007 fakes and logs | ADR-0010 bot path and equivalence test |
| TR-input-015 | ADR-0008 trace and `GestureLog` | ADR-0010 `append_line` sink |
| TR-tower-006 | ADR-0001 `halted()` check | ADR-0010 read-before-mutate command contract |
| TR-hud-010 | ADR-0006 signals and allowlist | ADR-0010 query surface (B10) |

Structural note: ADR-0004's GDD Requirements table has a row "One-tick floor from a constant" with no TR-ID. It is part of the Data GDD's bounds table and sits under TR-data-005; it does not need its own ID, but the row should cite one.

The full matrix is in `docs/architecture/requirements-traceability.md`.

### Coverage Gaps (no ADR exists)
None of the three ADRs below is written. `architecture.md` proposes each.

| Proposed | TRs | Layer tags | Suggested | Engine risk |
|---|---|---|---|---|
| ADR-0009 Enemy Entity, Roster and Combat API | 17: TR-combat-001 to 008, TR-combat-013, TR-enemy-008, 009, 010, 011, 013, 016, TR-tower-007, TR-hero-007 | Core | `/architecture-decision Enemy Entity, Roster and Combat API` | MEDIUM |
| ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry | 10: TR-tower-001, 002, 008, 009, TR-hero-001, 002, 009, 012, 015, TR-hud-013; plus the rest of 4 Partial rows | Core (TR-hud-013 tagged Foundation) | `/architecture-decision Sim/Input Split, Command Result Codes and Dev Telemetry` | LOW |
| ADR-0011 Battle Field Rendering and Draw-Call Budget | 5: TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015 | Presentation | `/architecture-decision Battle Field Rendering and Draw-Call Budget` | MEDIUM |

Domain per ADR: ADR-0009 Core (combat data, targeting); ADR-0010 Core (commands, telemetry); ADR-0011 Rendering.

### Cross-ADR Conflicts
Known conflict-prone areas: none recorded (`docs/consistency-failures.md` does not exist).

No 🔴 blocking conflict was found. Two non-blocking conflicts:

## Conflict: ADR-0003 vs ADR-0004
Type: Integration (stale contract)
ADR-0003 claims: if spike S1 fails, "ADR-0004 queues commands and drains them at the start of its tick driver" (S0 check table, S1 row; Risks: "S1 fails ... ADR-0004 queues commands"). Its Enables row says "ADR-0004 (input before ticks rests on S1)", and review row G14 says "ADR-0004 may tick in `_physics_process`".
ADR-0004 claims: ticks run from `BattleWrapper._process`, never `_physics_process` (Decision 1); "ADR-0003's S1 queue fallback is not adopted" (Decision 4); the S1 command queue is rejected (Alternative 4); S1 no longer gates TR-hud-005 (Verification Required).
Impact: a story author who follows ADR-0003's S1 fail branch builds a command queue that ADR-0004 rejects, or holds a story on S1 that no longer gates it. `architecture.md` Data Flow 1 already sides with ADR-0004, so the code would follow ADR-0004 if the author reads both.
Resolution options:
  1. A dated amendment to ADR-0003 (Status stays Accepted): the S1 row and the S1 risk point to ADR-0004 Decision 4; the Enables row and G14 drop the `_physics_process` and queue text.
  2. A line in ADR-0004's Amendments that it supersedes ADR-0003's S1 fail branch, so a reader of either finds it.

## Conflict: ADR-0005 vs ADR-0004
Type: Performance budget (acknowledged, unmeasured)
ADR-0005 claims: about 150 accessor reads a tick "could take 0.75 to 2.25 ms against ADR-0004's 2.0 ms p95 per tick: the top of the range breaks the budget alone" (R1).
ADR-0004 claims: one whole tick takes at most 2.0 ms p95 on an Adreno 5xx-class phone (Decision 7). The Combat GDD's per-tick targeting estimate (TR-combat-013, about 400 range checks under 2 ms) also lands inside that same tick, and ADR-0009, which must budget it, is not written.
Impact: the two estimates together can reach about 4 ms per tick, twice the budget. At the catch-up cap that also lowers `MAX_TICKS_PER_FRAME` toward 2, and above 4.0 ms per tick 30 fps cannot hold full speed (ADR-0004 Decision 7).
Resolution options:
  1. Run ADR-0005 P1 on desktop with the first accessor story, as planned; its trigger builds the `match` fallback early.
  2. Have ADR-0009 state its share of the 2.0 ms tick, so the accessor and targeting budgets add up inside one number.

Same-ADR staleness found while checking (not conflicts between ADRs):
- ADR-0001: Architecture Diagram and Consequences still show private `_halt_gate` and `_stat_accessor`; the 2026-11-04 amendment says they are left as written.
- ADR-0002: "QQ-16 may add a prefix (ADR-0007)"; ADR-0007 Decision 10 chose no prefix.
- ADR-0004: Decision 5 still says the QQ-08 tick-order part is "Pending the user's acceptance"; Decision Makers records it accepted. Knowledge Risk still says "Only `_process(delta)`, `application/run/max_fps` and plain arithmetic are load-bearing"; the E3 amendment makes the physics settings load-bearing too.

### ADR Dependency Order
From `adr-dep-graph.sh`: 8 ADRs, 19 edges, no `CYCLE`, no `NO_DEPS_SECTION`, no `UNFILLED_DEPS`. ADR-0001 states "None" outright. Every edge points to an Accepted ADR, so no ADR waits on a Proposed one.

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
Planned, not written: ADR-0009 (ADR-0001, ADR-0005), ADR-0010 (ADR-0004, ADR-0008, ADR-0009), ADR-0011 (ADR-0009, ADR-0010).

Graph note: ADR-0007 writes its Depends On row as a range ("ADR-0001 to ADR-0006"). The script read only the named ends and ADR-0003, so it shows 3 of its 6 edges. The missing edges (ADR-0002, ADR-0004, ADR-0005) point to earlier ADRs, so they cannot hide a cycle and the order holds. Listing each ADR by number would let the script see them.

### GDD Revision Flags
None. All GDD assumptions are consistent with verified engine behaviour. Each probe answer that differed from an ADR (E3 delta cap, E5 string cost, edge-to-edge as an export option, F2 warning key) touches no GDD rule: grep found no GDD that names `_physics_process`, edge-to-edge, `exclude_addons` or `device == 0`. The Data GDD's old note that recommends typed Resources now carries "Settled by ADR-0002 (Accepted): JSON". Systems index left unchanged.

### Engine Compatibility Issues

### Engine Audit Results
Engine: Godot 4.7.2 (installed 4.7.2.stable.official.ed1daf0bf matches the pin, `VERSION.md`)
ADRs with Engine Compatibility section: 8 / 8 total

Deprecated API References: none. Every hit for a `deprecated-apis.md` name (`duplicate()`, string `connect("`, `device == 0`) is a ban or a lint rule (ADR-0002 Guideline 11, ADR-0003 Guideline 4, ADR-0006 Decision 1, ADR-0007 L-INPUT-3, L-SIG-1). ADR-0005 and ADR-0006 use untyped `Dictionary` on purpose, with reasons recorded (ADR-0005 Decision 3; ADR-0006 Decision 9).

Stale Version References: none. All eight ADRs target 4.7.2. Stale verification fields:
  - ADR-0008: Engine Compatibility says probes R1 to R6 are unverified on 4.7.2 and must run "before the first resolver story closes". `probe-results.md` shows all six verified 4.7.2 headless, all matching. ADR-0008 has no Amendments section; the probe commit (`8508f8c`) updated ADR-0001 to ADR-0007 only.
  - ADR-0006: Knowledge Risk says "each behaviour here is unverified on 4.7.2 (probes E1 to E6)"; its own Verification Required row says all six are verified.
  - ADR-0007: Last Verified says "engine reference of 2026-10-17 and gdUnit4 6.2.0 source; nothing run"; its Verification Required row says H4, H5, H7 and H8 are verified.

Post-Cutoff API Conflicts: none. Post-cutoff features in use and the ADRs that rely on them: `@abstract` (ADR-0005, ADR-0007), rest parameters in fakes (ADR-0006, ADR-0007, ADR-0008; probe ADR-0006-E6 passes), 4.7 typed-return overrides (all; ADR-0007-H4 passes), the 4.7 `device == 0` ban, stretch defaults, 4.6 dual focus and `mouse_behavior_recursive` (ADR-0003). No two ADRs assume different behaviour for the same API.

Probe record (`probe-results.md`, 76 probes): 68 match, 4 do not, 4 partly; 12 not run. Each "does not match" answer has a dated amendment: ADR-0003 (edge-to-edge is the export option `screen/edge_to_edge`), ADR-0004 (E3: `_process` delta is capped near `max_physics_steps_per_frame / physics_ticks_per_second`, so Guideline 11 pins 60 and 8), ADR-0005 (E5: a `String` literal costs the same as a constant), ADR-0007 (F2: `exclude_addons` does not exist; `directory_rules` replaces it). The "partly" answers (ADR-0002 KEY, ADR-0004 E3c, ADR-0005 ABS, ADR-0007 H7) are each absorbed in the ADR text.

Open engine risks (not run):
  - **gdUnit4 on 4.7.2 is unproven.** ADR-0007 says gdUnit4 6.2.x lists Godot up to 4.7.1, and H1, H2, H3, H6 and H9 (exit codes, push_error reporting, orphans, fresh clone, un-awaited `is_push_error`) need gdUnit4. The CI command in the coding standards and every Logic story rest on it. HIGH for the CI story.
  - **ADR-0003 behaviour checks.** S1 to S8 and the TapScreen check are not run (they need a person or a device). Only names and settings are verified headless. Per ADR-0003 Guideline 15, each adapter, modal and pause story waits for the check it names. The Input and app lifecycle rows stay HIGH.
  - **Device-only checks**: ADR-0001 V8 (push_error in a release export), ADR-0002 X2 and P1/P2, ADR-0004 V13, ADR-0005 P1 device run.
  - ADR-0003's S1 spike sets `physics_ticks_per_second` 240 and `max_fps` 30. It must run in a throwaway project (as `probe-results.md` did), since ADR-0004 Guideline 11 pins 60 and L-PROJ-1 fails any other value in the repo.

### Engine Specialist Findings
**Engine specialist consultation: NOT RUN in this pass.** Phase 5 asks for a `godot-specialist` second opinion. This reviewer could not start subagents, so the consultation did not happen. The engine findings above rest only on the ADRs' Engine Compatibility sections and on `docs/engine-reference/godot/probe-results.md` (verified on the official 4.7.2 Linux build, headless). Each ADR records its own godot-specialist review at authoring (all CONCERNS, findings resolved), but none of those saw the probe results, and no specialist has reviewed the eight ADRs together. This is not a pass. Run the consultation before `/gate-check pre-production`.

### Architecture Document Coverage
`docs/architecture/architecture.md` v5 (2026-11-04) checked against the 8 GDDs and the systems index.

**Clean:**
- All 22 systems in the systems index appear in the layer map; the 14 without a GDD are reserved slots with named seams. No orphaned architecture.
- Data Flows 1 to 10 cover every cross-system route the GDDs define. Data Flow 1 sides with ADR-0004 on S1 (no queue). Data Flow 9 now names ADR-0008's `GestureLog` and its `tower_upgraded` and `chip_state()` reads.
- B9 now lists the `wave_index()` and `burst_id` injections and HudLogic's accessor and `halt_gate.halted`; B10 no longer names a Hero cooldown total. The five stale items of the second review are fixed.
- Every one of the 121 registered requirements maps to one primary ADR.

**Stale (fix in a v6 sync):**
1. **v5 predates the probe results** (v5 committed 18:46, probes 19:04). QQ-17 says the Callable fact is "still open"; probe ADR-0001-V1 answers it and ADR-0001 is amended. QQ-05 says V11a "records whether `Vector2` is 32-bit"; probe ADR-0004-E2 answers yes. The Engine Knowledge Gap Summary says stretch key names "stay unverified until spike check S9" and no lifecycle notification is in the pinned reference; S0a and S9 verified the names and keys headless. The ADR Audit lists ADR-0002 E1 to E3 as open (verified) and gives ADR-0008's open engine fact as V12 (its engine probes are R1 to R6, verified). None of the amendments' facts appear: the physics settings pin (ADR-0004 Guideline 11), edge-to-edge as an export option (ADR-0003), `directory_rules` (ADR-0007 F2).
2. **Counts.** 121 requirements and "84 full, 5 partial" become 123 and, under this review's grading, 84 covered, 7 partial, 32 gaps.
3. **Required ADRs table, Depends on column**, differs from the ADRs' own rows: ADR-0005 omits ADR-0004; ADR-0006 omits ADR-0003 and ADR-0005; ADR-0007 omits ADR-0002 to ADR-0005; ADR-0008 omits ADR-0001, ADR-0004 and ADR-0007.
4. **M1 row** ("before ADR-0004 and ADR-0008 stories rest on it") is wider than the ADRs: ADR-0004 says S1 no longer gates TR-hud-005, and ADR-0008 says S0a gates adapter stories, not resolver unit stories.
5. **Review state.** TD-ARCHITECTURE and LP-FEASIBILITY have not re-reviewed it since v2.

**Context (advisory):** five of the eight GDDs are not Approved (Data & Config In Review, Input Revised, Game State Designed, Tower In Review, Battle HUD Designed). The ADRs trace to their current text; a later GDD change goes through `/propagate-design-change`.

---

### Verdict: FAIL

32 requirements have no ADR, and 26 of them carry a Foundation or Core layer tag (25 Core, 1 Foundation: TR-hud-013). ADR-0009 and ADR-0010 are not written. That is a critical gap under this skill's rule, so FAIL outranks the rest.

Everything else is CONCERNS level: no blocking conflict, two non-blocking conflicts, three ADRs with stale verification text, gdUnit4 on 4.7.2 unproven, and the engine specialist consultation not run. All 8 Foundation ADRs are Accepted, and every Foundation-tagged row but one is covered or partly covered.

`architecture.md` itself plans ADR-0009 and ADR-0010 as "before the named system's first story", so this FAIL is the expected state at this point. It blocks `/gate-check pre-production`.

### Blocking Issues (must resolve before PASS)
1. Write and accept ADR-0009 Enemy Entity, Roster and Combat API (17 Core gaps; also closes QQ-08's ProjectileSpawner and stage geometry parts).
2. Write and accept ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry (10 gaps, and the ADR-0010 part of TR-input-014, TR-input-015, TR-tower-006, TR-hud-010).
3. Run the godot-specialist consultation over all eight ADRs and `probe-results.md` (not run in this pass).

### Should fix (not blocking)
4. Dated amendment to ADR-0003: point its S1 fail branch, Enables row and G14 at ADR-0004 Decision 4 (Conflict 1).
5. Dated amendment to ADR-0008: mark R1 to R6 verified 4.7.2 headless, as ADR-0001 to ADR-0007 were. Fix the stale lines in ADR-0004 (Decision 5, Knowledge Risk), ADR-0006 (Knowledge Risk) and ADR-0007 (Last Verified).
6. ADR-0009 states its share of the 2.0 ms tick; run ADR-0005 P1 early (Conflict 2).
7. Prove gdUnit4 on 4.7.2 (ADR-0007 H1, H2) in the CI story before the first Logic story.
8. Sync `architecture.md` to v6 (Architecture Document Coverage items 1 to 4).
9. Write ADR-0007's Depends On as a list of numbers so the graph script sees every edge.

### Required ADRs
In order: ADR-0009 (Core, before any Combat or Enemy & Wave story), ADR-0010 (Core, before any Hero or Tower story), ADR-0011 (Presentation, may wait for the first phone build).

---

### Handoff
**Immediate actions:**
1. `/architecture-decision Enemy Entity, Roster and Combat API` (ADR-0009).
2. `/architecture-decision Sim/Input Split, Command Result Codes and Dev Telemetry` (ADR-0010).
3. `/architecture-decision Battle Field Rendering and Draw-Call Budget` (ADR-0011).

**Pre-gate checklist:**
- ✅ `tests/unit/` and `tests/integration/`
- ✅ `.github/workflows/tests.yml`
- ❌ `design/accessibility-requirements.md`: run `/ux-design`
- ❌ `design/ux/interaction-patterns.md`: run `/ux-design`

The two ❌ items are required steps before `/gate-check`. Re-run `/architecture-review` after each new ADR to check that coverage improves.
