# ADR-0013: Content Test and Bot Harness

## Status

Proposed

> TD-ADR: not run per ADR; batch review after all ADRs are written.
> Engine specialist validation: not run (no agents spawned for this batch).

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

lead-programmer (draft). Acceptance rests with the user or technical-director.

## Summary

Content rules (layout, wave, tower and hero checks) and the balance gates (hero share, towers-only loss) are enforced today only by throwaway Python in `tools/balance-sim/`. This ADR puts both into gdUnit4 suites in GDScript, run in CI over the real catalogue and a headless `Battle`, keeps the Python as a cross-check until the GDScript reproduces its numbers, and keeps device budgets out of CI.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (testing and tooling) |
| **Layer** | Feature |
| **Knowledge Risk** | HIGH for the version (VERSION.md). The harness calls no rendering, physics or audio API. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `.claude/docs/coding-standards.md` (the CI command); `tests/README.md` (runner, exit codes); `addons/gdUnit4/plugin.cfg` (gdUnit4 6.2.0). The live 4.7.2 class reference was not fetched for this ADR. |
| **Post-Cutoff APIs Used** | None known. |
| **Verification Required** | NOT SOURCEABLE: how a scene file is tested for existence from GDScript (the content test must open each `scene_ref`); the API is not cited here. NOT SOURCEABLE: whether the headless run has a usable display server for a test that instantiates a scene. NOT SOURCEABLE: wall-clock time of the full bot table in CI. Run each once in CI before this ADR is Accepted. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary |
| **Enables** | The first bot story; Tower and Hero content rules; later stage content |
| **Blocks** | The first bot story and the content test story |
| **Ordering Note** | Needs ADR-0004 (Catalogue Format, Loader, Validator and Stat Accessor) for fixture records, ADR-0003 (Fixed Tick, Time and Determinism) for per-architecture baselines, and ADR-0010 and ADR-0011 for the tower and hero rules and bots. These are real inputs but not listed as dependencies because the harness shape here does not change with them. `architecture.md` has no layer-map row for a test harness; Feature is chosen because it is needed before the first bot story, not before coding starts. |

## Context

### Problem Statement

Several GDD rules say "the content test checks this" and "a scripted bot reproduces this", and none says where the code lives or how it runs in CI. The only implementations are two Python scripts that say they are not game code. Without a harness, the layout rules L1 to L14, the wave rules, the tower and hero rules and the share gate are checked by hand, and a data edit can pass review and fail the game.

### Current State

- `tools/balance-sim/stage_rules.py` implements layout rules L1 to L9 and L12 to L14 and the wave rules that `enemy-wave.md` criterion 19 runs today. It checks the real stage and a table of broken copies (criterion 20), prints the set of reported rule IDs per copy, and exits 0 only when every set matches. Its IDs include `L1` to `L9`, `L12` to `L14`, `first_spawn`, `max_gap`, `time_to_exit_min`, `time_to_exit_max`, `intermission_cap`, `first_lives`, `wave_lives`, `stage_lives`, `lives_cost_cap`, `interval_floor` and `min_lives_waves`.
- `tools/balance-sim/hero_bots.py` is a throwaway sim ("not game code"; its header says to replace it with the Hero stories' real bots). It holds the bots (mid-skill, pinned once, best single pin, ceiling, greedy, greedy ceiling), the results table in `hero-system.md`, a `clamp_pin` check, and a `--greedy` run that asserts the share gate: median share 25% to 30% inclusive and none above 40%.
- gdUnit4 6.2.0 is vendored in `addons/gdUnit4/`. The CI command is in `coding-standards.md`. `tests/README.md` lists the exit codes and warns that "No test cases found" with exit 0 is not a pass. The only test today is a sanity suite in `tests/unit/framework/`.
- `data-config-pipeline.md` Rule 9: the CI content test opens each `scene_ref`, applies the layout and wave rules, and enforces a non-empty `rationale` on every record and any balance range an owning GDD declares.

### Constraints

- The harness runs the same `Battle` that ships (ADR-0001). It builds a battle through `BattleBuilder` with an injected catalogue and no shell.
- Tests are deterministic: fixed fixtures, explicit ticks, no random seeds, no time assertions (`coding-standards.md`).
- Device budgets (frame time, memory, draw calls) are not CI gates.
- A check that did not run must say so. It must never read as a pass.
- Bot baselines are per CPU architecture because float results may differ between x86 and ARM (architecture.md Determinism path; ADR-0003).

### Requirements

- TR-data-008: a CI content test opens each `scene_ref` and applies the layout, wave and tower rules to the records.
- TR-wave-006: layout rules L1 to L14 and the wave rules run in the content test.
- TR-tower-007: tower content rules (two levels, cost bounds, bonus share, `gold_before_last_wave`).
- TR-hero-006: scripted bots reproduce the share gate headless on the fixed tick.

## Decision

### 1. Layout

```
 tests/unit/content/          rule functions on in-memory records (fast, pure)
 tests/integration/content/   the real catalogue: scene_ref existence, rationale, all rules
 tests/integration/bots/      bot runs over a headless Battle, the gates
 tests/fixtures/ (or inline)  fixture factories: a stage(), an enemy(), broken copies
 src/tools/ (code root)       ContentRules, BotRunner, Bot policies   (see 2 and 3)
```

Rules and bots are game-side plain classes so that tests and a future in-editor command can call them. The exact `src/` subfolder is a naming choice for the first story and is not decided here.

### 2. Content test

- `ContentRules` is a plain class with one function per rule family. It takes catalogue records (or the `Catalogue`) and returns an `Array[ContentError]`, where `ContentError` has `rule_id: StringName`, `stage_id`, and `record_id`. Rule IDs are the same strings as the Python (`L1`, `first_spawn`, and so on), so a failure names the GDD rule.
- Rules are pure functions of records. They use no scene and no tick. Layout geometry uses 64-bit scalar `float`, as in the Python.
- The suite has four parts:
  1. Rule unit tests on fixtures, one per rule, including the boundary cases the GDD gives.
  2. The copies table (`enemy-wave.md` criterion 20): each broken copy of the real stage must report exactly its ID set, and the unbroken stage the empty set. A validator that reports every ID, the wrong one, or misses a second rule fails.
  3. The real catalogue: every Stage's `scene_ref` exists (the existence call is NOT SOURCEABLE here), every record has a non-empty `rationale`, and every rule family reports the empty set.
  4. A zero-input guard: if the catalogue holds no Stage record or no Tower record, the test fails with a message that says what was missing. Zero stages checked is not a pass.
- Rule families join as their systems are built: layout and wave rules now (L1 to L9, L12 to L14, the wave rules); L10, L11, `intermission_min`, `peak_alive_ub` and the tower and hero rows in the Tower and Hero stories. Each new rule adds its broken copies to the table with exact ID sets.
- Opening a `scene_ref` is the only file access. It sits behind the `TextSource` seam style of ADR-0001: a `SceneProbe` interface with a real and a fake implementation, so unit runs need no file I/O.

### 3. Bot harness

```gdscript
class_name BotRunner extends RefCounted
## Runs one scripted bot against one headless battle to an outcome. Deterministic.
func run(catalogue: Catalogue, stage_id: StringName, seed: int, bot: Bot, max_ticks: int) -> BotResult

class_name Bot extends RefCounted
## One decision step. Called between ticks only, and only through Battle commands.
func act(battle: Battle) -> void
```

- `BotRunner` builds a battle with `BattleBuilder.build`, then loops: `bot.act(battle)`, `battle.tick()`, until `battle.halted()` or `max_ticks`. Time enters only through `Battle.tick()`.
- Bots hold only `Battle` (ADR-0001) and call `build`, `upgrade`, `pin`, `burst`, `start_wave` and `call_early`. They never touch the resolver, a view, or a signal.
- `BotResult` holds the outcome (Won, Lost, Fatal, or `max_ticks`), lives, last wave, ticks, `hero_share` (from `Combat.dealt_by_kind`), burst counters and the bot ID.
- If `max_ticks` is reached, the result is `TIMED_OUT`, which fails any gate. A bot that never ended is not a pass.
- Policies follow the table in `hero-system.md` (Simulated results): mid-skill, pinned once, best single pin, ceiling, greedy (the share-gate bot) and greedy ceiling, with the build orders listed there. Each bot is a small class with its parameters passed in, not literals.

### 4. Gates in CI

| Gate | Source | Rule |
|---|---|---|
| Hero share (greedy bot) | `hero-system.md` | Median 25% to 30% inclusive, unrounded, none above 40%, over the four mixed builds |
| Towers only | `hero-system.md`, `enemy-wave.md` | Every build loses without the hero (MVP), and slow-only loses even with it |
| Median kills on bursts hitting 3 or more | `hero-system.md` | At least 2 |
| Hero-unaided check | `tower-system.md` | A hero alone with no towers does not win (Pillar 2) |
| Never-pinned equals towers-only | `hero-system.md` Rule 1 | Identical snapshots |

Gates compare with the baseline for the CPU architecture the CI runner has. A baseline file per architecture is kept in `tests/fixtures/`; a missing baseline for the current architecture fails with "NOT ASSESSED: no baseline for <arch>", not a pass. The architecture query itself is NOT SOURCEABLE here (ADR-0003 settles it).

### 5. Relation to the Python tools

- The GDScript harness is the authority from the day its parity test passes. Until then the Python is the authority.
- Parity test: for each result row in `hero-system.md` (the 7-build table and the share table), the GDScript bots must produce the same outcome and the same lives, and shares within the unrounded gate. Where float order differs, the GDScript baseline is recorded and the difference is written in the test. The Python is not run in CI (it needs a Python install that the Godot CI job may lack; NOT SOURCEABLE which runners the CI uses).
- `stage_rules.py` stays as the independent oracle for the copies table: the GDScript test must give the same ID sets. A mismatch is a defect in one of them and is resolved by the GDD.
- After parity, both scripts are frozen (kept, not edited) and their headers get a line pointing to the GDScript. Deleting them is a later call.
- A tuning change in a GDD is made in the catalogue and checked by the GDScript gates. The Python is not edited to follow it.

### 6. What CI does not gate

Frame time, memory, draw calls, and the 400-check targeting cost are device measurements (ADR-0012, ADR-0007). They are recorded in `production/qa/` by hand on a phone. They never fail CI.

### 7. gdUnit4 conventions

- File `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`, arrange-act-assert (`.claude/rules/test-standards.md`).
- Suites extend `GdUnitTestSuite`. Nodes are created with `auto_free` so no orphan leaks (exit 101).
- CI runs the import step and then the gdUnit4 command from `coding-standards.md`. A run with "No test cases found" fails the job even when the exit code is 0.
- Exit codes follow `tests/README.md`: 0 pass, 100 fail, 101 orphan warning, 103 or 104 runner failure, 105 parse failure. All non-zero fail the job.
- Fixtures are factory functions, not shared mutable state.

### Architecture Diagram

```
 real Catalogue / fixture records --> ContentRules --> Array[ContentError] --> gdUnit4 suites
 BattleBuilder.build(fixture or real catalogue) --> Battle --> BotRunner --> BotResult --> gates
        ^ Bot.act(battle): commands only                                (per-arch baselines)
 tools/balance-sim/*.py : cross-check until parity, then frozen
```

### Key Interfaces

`ContentRules`, `ContentError`, `SceneProbe`, `Bot`, `BotRunner`, `BotResult` as sketched. All public methods carry doc comments.

### Implementation Guidelines

- Rules must be pure functions of records and must return IDs, not booleans.
- Every test that passes on zero input must instead fail with a message naming the missing input.
- Bots must call only `Battle` commands and must never read the resolver or a view.
- `BotRunner` must end with a `TIMED_OUT` result at `max_ticks`, not an unbounded loop.
- No test may use a random seed, a real clock or a file path other than a fixture or the real catalogue.
- Baselines must be per architecture; a missing baseline must fail as not assessed.
- Device budgets must not appear as CI assertions.

## Alternatives Considered

### Alternative 1: Keep the Python as the only checker and run it in CI

- **Description**: CI runs `stage_rules.py` and `hero_bots.py --greedy`.
- **Pros**: Already works. No new code.
- **Cons**: The Python re-implements the game, so it can drift from the code that ships. Its header says it is not game code. It cannot see the real catalogue loader or `Battle`.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: The point of a gate is to test the shipped code.

### Alternative 2: A GDScript harness only; delete the Python now

- **Description**: Port and delete.
- **Pros**: One source of truth.
- **Cons**: No oracle during the port; a port error would become the baseline.
- **Estimated Effort**: Same as chosen.
- **Rejection Reason**: The parity step is cheap and catches port errors. Deletion can follow.

### Alternative 3: Bots drive the resolver with simulated touches

- **Description**: Bots send `press`, `move`, `release`.
- **Pros**: Exercises the input path every run.
- **Cons**: Needs the shell; breaks the headless rule; slower.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Input Rule 11; the equivalence tests in ADR-0010 and ADR-0011 cover the path.

### Alternative 4: Check content only at boot

- **Description**: The validator rejects layout violations at load.
- **Pros**: No separate test.
- **Cons**: Data Rule 9 and the Enemy & Wave GDD put scene and layout checks in the content test, because checking scenes at load means instancing every stage.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Contradicts the GDDs.

## Consequences

### Positive

- A data edit that breaks a rule or the share band fails CI with the GDD rule ID.
- Bots are the shipped sim, so a bot result is a game result.
- The copies table catches a validator that is too loose or too strict.

### Negative

- Two implementations (Python and GDScript) exist until parity is shown.
- Baselines per architecture add files to maintain.
- The bot table may be slow in CI; its time is unknown (see Risks).

### Neutral

- Gate numbers stay in the GDDs; the harness reads them from the catalogue and test constants that cite the GDD section.

## Risks

- Bot runtime in CI is unknown. Mitigation: measure at the first bot story; split into a fast gate (greedy share) and a slower nightly table if needed. No budget figure is set now because none was given.
- Float order differences between Python and GDScript change a result. Mitigation: record GDScript baselines and explain each difference in the parity test.
- The headless run may lack a display server for scene existence checks. Mitigation: the `SceneProbe` fake keeps unit runs independent; the real probe runs in the integration suite, which is checked once in CI.
- A GDD gate changes (the share band was moved by the user on 2026-11-03). Mitigation: the constants cite the GDD section and change with it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-008, Rule 9: CI content test opens each `scene_ref`, applies layout and wave rules, enforces `rationale` | Section 2, parts 1 to 4 |
| enemy-wave.md | TR-wave-006: L1 to L14 and wave rules in the content test; criteria 19 and 20 | `ContentRules` with the copies table and exact ID sets |
| tower-system.md | TR-tower-007: levels, cost bounds, bonus share, `gold_before_last_wave` | Rule families added in the Tower stories |
| hero-system.md | TR-hero-006: scripted bots reproduce the share gate headless | Sections 3 to 5 |

TR IDs are provisional until `/architecture-review` registers them.

## Performance Implications

- **CPU**: CI time only. Not measured. L8 samples every 2 units on every pair, which is quadratic in path length; the Python does the same on the starter stage. The GDScript time is unknown.
- **Memory**: Test process only.
- **Load Time**: None in the game.
- **Network**: None.

## Migration Plan

1. Port `stage_rules.py` to `ContentRules` and the copies table. Compare ID sets with the Python.
2. Build `BotRunner` and the greedy bot. Reproduce the share gate.
3. Port the other bots and the results table. Record baselines.
4. Freeze the Python.

**Rollback plan**: Keep the Python as the CI gate and mark the GDScript suites advisory, if the port cannot reach parity in a reasonable time.

## Validation Criteria

- The unbroken real stage reports no content errors; every broken copy reports exactly its set.
- A catalogue with no Stage record fails the content test with a named message.
- The greedy bot reproduces the 25% to 30% median and the 40% cap.
- A bot that never ends returns `TIMED_OUT`.
- CI fails on "No test cases found".

## Related

- ADR-0001 Simulation and Shell Boundary (depends on)
- ADR-0003 Fixed Tick, Time and Determinism; ADR-0004 Catalogue Format, Loader, Validator and Stat Accessor; ADR-0010 Tower System; ADR-0011 Hero System
- `tools/balance-sim/stage_rules.py`, `tools/balance-sim/hero_bots.py`
- `design/gdd/data-config-pipeline.md` (Rule 9), `enemy-wave.md` (layout and wave rules, criteria 19 and 20), `tower-system.md` and `hero-system.md` (content rules, Simulated results)
- `tests/README.md`, `.claude/docs/coding-standards.md`
