# Engine Verification Plan: ADR-0001 to ADR-0011

> **Created**: 2026-11-04
> **Why**: All 11 ADRs are Proposed. The user chose on 2026-11-04 to keep each one Proposed until its own engine checks pass. This page groups those checks into runs. The authority for each check is the "NOT SOURCEABLE (blocks Acceptance)" list in its ADR, and this page only indexes it. Counts below come from those lists.
> **Accept with**: `/architecture-decision accept ADR-NNNN`, in dependency order (`.claude/scripts/adr-dep-graph.sh`: 0001 to 0011). The batch TD-ADR review (2026-11-04) asks that ADR-0001, 0003 and 0004 be accepted together, after the ADR-0003 spike.

## Open items per ADR

| ADR | Blocking items | Settled by |
|---|---|---|
| 0001 App Lifecycle, Composition Root and Fatal Path | 5 | Desktop and Android export probe (Callable and weakref proof); `push_error` reaching logcat |
| 0002 Catalogue Storage Format, Manifest and Validation | 9 | Android and iOS export: `*.json` export filter, whether `.json` counts as a resource, load time, scene checks |
| 0003 Input Adapter, Display Stretch and Platform Lifecycle | 12 | The device spike S-1 to S-11 written into the ADR |
| 0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism | 6 | Phone: event order against `_process`, `delta` spread, `Battle.tick` cost (at most 2.0 ms), arm64 bot baseline |
| 0005 Stat Accessor and Read-Context Contract | 4 | Export run: Callable behaviour, read cost |
| 0006 Battle Signal Contracts and View Allowlist | 5 | Desktop headless (listener order, enum-typed payloads, `get_signal_list`); its export probe is ADR-0001's |
| 0007 Headless Test Harness, gdUnit4 and Layer Lint | 8 | CI run of the harness |
| 0008 Input Resolver Core and Signal Contract | 5 | Desktop headless and CI |
| 0009 Enemy Entity, Roster and Combat API | 4 | Phone profile of the whole `Battle.tick` |
| 0010 Sim/Input Split, Command Result Codes and Dev Telemetry | 8 | Phone: `user://` access, log survives a kill, write stall, `build_info.json` packed in the export |
| 0011 Battle Field Rendering and Draw-Call Budget | 6 | First phone build: V-1 to V-6 (draw calls, line widths, frame time) |

## Run A: desktop and CI (no phone)

This run settles ADR-0006, 0007 and 0008, plus the desktop halves of 0001 and 0004. CI already runs green on `main` (gdUnit4 6.2.0, `.github/workflows/tests.yml`), so most of Run A is new test files on an existing pipeline.

## Run B: one instrumented phone session

Use a low-end Android phone, an iPhone and a 4:3 screen, with a debug export. Run the ADR-0003 spike first, because ADR-0004 and ADR-0008 depend on its event-order result. One build can log everything in the "Settled by" column for 0001 to 0005 and 0009 to 0011. Save each screenshot to `production/qa/evidence/`.

## After the runs

1. In each ADR, replace the NOT SOURCEABLE line with the observed fact and the device it was seen on.
2. Accept the ADRs in dependency order.
3. Re-run `/architecture-review`, then `/create-control-manifest`, then `/gate-check pre-production`.
