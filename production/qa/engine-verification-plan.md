# Engine Verification Plan: ADR-0001 to ADR-0014

> **Created**: 2026-11-04
> **Why**: All 14 ADRs are Proposed. The user chose on 2026-11-04 to keep every one of them Proposed until it passes its own engine checks. This page gathers those checks into two runs. Each check is copied from the ADR's "Verification Required" row or its "NOT SOURCEABLE (blocks Acceptance)" list. The ADR file is the authority, and this page is only an index into it.
> **Accept with**: `/architecture-decision accept ADR-NNNN`, in dependency order: 0001, 0002, 0003, 0014, 0004, 0005, 0006, 0008, 0007, 0009, 0010, 0011, 0012, 0013 (from `.claude/scripts/adr-dep-graph.sh`). An ADR can be accepted only after every ADR it depends on is Accepted.

## Run A: desktop and CI (Godot 4.7.2, headless)

This run needs no phone. It is enough for ADR-0001, 0005, 0007 and 0013, and for the sim half of ADR-0009.

| ADR | Check | Pass when |
|---|---|---|
| 0001 | Headless sim test under `godot --headless` | Test passes with no scene tree |
| 0001 | A `BattleReadModel` fake parses, with an explicit typed `return` in every override (4.7 rule) | Parse succeeds |
| 0001, 0005 | Reference-count test: a retired battle is released after `Battle.dispose()` | Every system's reference count reaches zero |
| 0005 | Order in which one signal calls its listeners | Result recorded (the design does not depend on it) |
| 0005 | `Object.get_signal_list()` on a `RefCounted` includes script-declared signals | Listed, or the wiring test is rewritten |
| 0005 | Enum-typed signal parameter enforcement | Result recorded (payloads are `int` either way) |
| 0005 | Connect or disconnect during an emit | Result recorded |
| 0007 | The scalar `float` distance path gives the expected exact results | Test passes |
| 0013 | Headless CI has a usable display server for a test that instantiates a scene | Integration test runs |
| 0013 | Wall-clock time of the full bot table in CI | Time recorded; within the CI budget |
| 0003 | x86 bot baseline recorded (the ARM half is in Run B) | Baseline file in `tests/fixtures/` |
| 0004 | `JSON.parse` returns `int` or `float` for a whole number; duplicate keys; a write to a read-only `Dictionary` or `Array`; whether the editor imports `.json` | Each result recorded in ADR-0004 |
| 0014 | Whether `FileAccess` `READ_WRITE` creates a missing file; whether `JSON.stringify` output is one line | Results recorded |

## Run B: one instrumented phone session

Run it on a low-end Android phone, an iPhone, and a 4:3 screen, all with a debug export. One build should log everything below. The technical director suggested scheduling it as one spike before Technical Setup.

| ADR | Check |
|---|---|
| 0002 | Whether `NOTIFICATION_APPLICATION_FOCUS_OUT` and `_PAUSED` reach AppRoot; their order and whether both fire when the app goes to the background; when they arrive within a frame; whether `queue_free`d nodes still get a call in the same frame |
| 0002 | Whether clicking the editor debugger fires FOCUS_OUT (editor run, both embedded and separate window) |
| 0002, 0010 | Whether input is dispatched before that frame's `_process` (HUD Rule 18), logged per frame |
| 0003 | The spread of `_process` `delta` on the low-end phone, and how often the 6-tick clamp engages; ARM bot baseline compared with x86 |
| 0004 | The Android and iOS exports load every JSON catalogue file |
| 0006 | Every NOT SOURCEABLE item under its Validation Criteria: OS event order against `push_input`, whether a tap also sends a mouse event, which buttons are emulated, presses in the letterbox bars, `_input` while paused, when `canceled` is set |
| 0011 | When `canceled` is set on touch events on Android and iOS, and the thumb offset and aim ring feel |
| 0008 | Letterbox masking on a 9:19.5 phone and on 4:3; the pixel space of the safe area; the dp source for the scale guard |
| 0009, 0012 | Draw calls for 48 enemies and the full HUD (about 8 expected, 12 at most); at most 3 text draws; frame time within 16.6 ms; memory within 256 MB; line widths after the 4.7 no-feather change (screenshot to `production/qa/evidence/`); the Mobile renderer on the target phone |
| 0007 | The 400-check targeting worst case is near 2 ms |
| 0014 | Log flush survives an OS kill; phone `user://` access and retrieval; no stall from main-thread writes |

## After the runs

1. Write each result into its ADR, replacing the NOT SOURCEABLE line with the observed fact and the device it was seen on.
2. Accept the ADRs in the order above.
3. Re-run `/architecture-review`, then `/create-control-manifest`, then `/gate-check pre-production`.
