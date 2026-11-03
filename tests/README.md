# Test Infrastructure

**Engine**: Godot 4.7.2
**Test Framework**: GdUnit4 6.2.2, pinned and committed under `addons/gdUnit4/` (ADR-0004)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-11-01

## Directory Layout

```
tests/
  support/        # Harness, plain GDScript, no _test suffix (ADR-0004): BattleRig, RigOptions,
                  # FatalRecorder, FixtureCatalogue, SnapshotTool, TickTrace, Replay,
                  # CommandFactory, WiringCheck, FreedCheck, RecordingSlot, SignalTap
  support/bots/   # BattleBot (abstract), ScriptedBot, BotProfile
  fixtures/       # Bot profiles, recorded baselines, forbidden-token list (all JSON)
  tools/          # record_baseline.gd, a SceneTree script run with -s
  unit/<system>/  # Isolated unit tests; no file I/O, fixture catalogues built in code
  unit/harness/   # Meta tests that keep each harness check known to fail; canary_test.gd
  integration/<system>/  # Real catalogue files, bots, wrapper tests
  smoke/          # Critical path test list for /smoke-check gate
```

Code outside `tests/` never imports anything under `tests/` (ADR-0004).

```
production/qa/
  evidence/       # Screenshot logs and manual test sign-off records
```

> **Manual evidence lives under `production/qa/evidence/`, not `tests/`** — that
> is where every consumer reads it.

## Installing GdUnit4

GdUnit4 is **not installed yet** (`addons/gdUnit4/` does not exist), so
`commands.test` cannot run until it is.

1. Open Godot → Asset Store (AssetLib before Godot 4.7) → search "GdUnit4" → install it
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: `res://addons/gdUnit4/bin/GdUnitCmdTool.gd` exists (capital U)

## Running Tests

Run the import first. A fresh clone has no `.godot/` class cache, and a run
without one exits 1 having run nothing.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Exit **0** = all pass, **100** = a test failed, **101** = all passed but a test
leaked nodes, **103/104** = gdUnit4 could not run, **105** = a test
script does not parse. Two `ERROR:` lines about the remote port `127.0.0.1:0`
are expected. `No test cases found` with exit 0 is **not** a pass.

**Exit-code rules (ADR-0004).** Only exit 0 passes. 100, 101 (orphans), 103,
105 and 1 fail the step. `No test cases found` fails the step, so
`tests/unit/harness/canary_test.gd` always exists.

## CI Procedure (ADR-0004)

1. Run `--import`. Retry it once if it crashes (the first-import crash was seen
   on Windows only).
2. Parse-check the scripts in `tests/support/`.
3. Run the gdUnit4 command above. Apply the exit-code rules.

## Baselines (ADR-0004)

- Python results do not carry over to the fixed-tick game. Gates assert the
  relations the GDDs write on integers (lives left, waves cleared), never the
  Python numbers.
- `tests/tools/record_baseline.gd` writes integer baselines, one set per CPU
  architecture, into `tests/fixtures/`. Cast each value with `int()` on load,
  since JSON numbers may load as float.
- A missing baseline fails the test with `NO BASELINE for <arch>`. Baselines are
  never compared across architectures.
- Thresholds marked "proposed" in the GDDs are set from the first recorded run,
  in a GDD edit.
- Floats are compared exactly in replay and equivalence tests, with no epsilon.
  The first CI run executes the replay test twice in two processes; a
  difference reopens ADR-0004 section 5.

## Test Naming

- Godot: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`
  — `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `production/qa/evidence/` |
| UI | Retained screenshot of each screen touched | `production/qa/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.
