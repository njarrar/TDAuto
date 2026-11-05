# Test Infrastructure

**Engine**: Godot 4.7.2
**Test Framework**: GdUnit4
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-11-01

## Directory Layout

```
tests/
  unit/<system>/        # Logic tests: fakes, code-built fixtures; no files, scenes, engine input or skips
  unit/lint/            # Lint self-tests: every rule's seeded bad sample and near miss
  integration/<system>/ # Cross-system tests; real data (data/, content/), battle_wiring/, lint/, hud/
  helpers/              # Shared helpers (no class_name; preload by path)
  baselines/<arch>/     # Determinism baselines, written only by tools/baseline/record_baselines.gd
  smoke/                # Critical path test list for /smoke-check gate
```

```
production/qa/
  evidence/       # Screenshot logs and manual test sign-off records
```

> **Manual evidence lives under `production/qa/evidence/`, not `tests/`** — that
> is where every consumer reads it.

## GdUnit4

GdUnit4 **6.2.0** is vendored in `addons/gdUnit4/` and pinned (ADR-0007 Decision 1).
CI uses this copy (`version: 'installed'` in `.github/workflows/tests.yml`). Upgrade it
only in its own reviewed change, and rerun ADR-0007 V1 and V2. The editor plugin is
optional; the command-line runner does not need it.

`project.godot` keeps, under `[gdunit4]`, `report/godot/push_error=true`,
`report/godot/script_error=true` and `report/verbose_orphans=true`: any `push_error`,
`push_warning` or engine error a test does not assert fails it, and a leaked node gives
exit 101 (ADR-0007 Decision 7; lint PROJ-5).

## Running Tests

Run the import first, every time. The class cache
(`.godot/global_script_class_cache.cfg`) is tracked, but it is stale whenever a change
adds or renames a `class_name`, and nothing else under `.godot/` is tracked. Retry the
import once on any exit above 128 (a known crash on exit). The import is not a parse
check: it exits 0 on a parse error. Commit the regenerated cache with any change that
adds or renames a `class_name`.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Exit **0** = all pass, **100** = a test failed, **101** = all passed but a test
leaked nodes (**fails the gate**, ADR-0007 C1), **103/104** = gdUnit4 could not run,
**105** = a test script does not parse, **1** = run before the first import. Any other
code is NOT ASSESSED. Two `ERROR:` lines about the remote port `127.0.0.1:0` are
expected. `No test cases found` with exit 0 is **not** a pass; CI fails a run whose
JUnit report has 0 tests.

The architecture lint runs inside this command (`tests/integration/lint/`). To run it
alone: `godot --headless --path . -s res://tools/lint/run_lint.gd`. Its rules:
`docs/architecture/adr-0007-lint-rules.md`.

## Test Naming

- Godot: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`
  — `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## Test Rules (ADR-0007)

- No `class_name` anywhere under `tests/` (NAME-3); preload helpers by path.
- No `assert_signal` or `monitor_signals`: use `tests/helpers/recording_fake.gd` (TEST-1).
- No skipped tests: no `do_skip` or `skip_reason`, and no test parameter gdUnit4 does not
  know, because gdUnit4 skips such a test silently (TEST-6).

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
