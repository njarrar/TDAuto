# Godot 4.7.2 Verification Results

Results of the headless ADR verification scripts. One row per checked item.
"Matches" is `yes` (the ADR's expected result), `no` (the engine did something
else), or `recorded` (the ADR asked only for the value).

## Run 1: 2026-11-04

| Field | Value |
|---|---|
| Date | 2026-11-04 |
| Machine | Mac16,10, macOS, arm64 (Apple Silicon) |
| Binary | Godot 4.7.2 editor binary (`/Applications/Godot.app/Contents/MacOS/Godot`), run headless |
| Build | debug (`OS.is_debug_build()` true) |
| Run command | `cd prototypes/adr-checks && GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./run_all.sh` (each script: `"$GODOT" --headless --path . -s res://<script>`) |
| Scripts | `prototypes/adr-checks/` (README lists which script covers which item) |
| Evidence | `production/qa/evidence/adr-checks-mac-2026-11-04.txt` |
| Totals | 186 RESULT lines; 2 FAIL (both ADR-0009 V7); 0 NOT_RUN; 0 INCOMPLETE |
| Run by | the user (njarrar) |

Some ADRs name `current-best-practices.md` (ADR-0006, 0007, 0008, 0010) or
`modules/rendering.md` (ADR-0011) as the place for results. This file is that
record for this run; each ADR's result lines point here.

The two FAIL lines are engine facts, not script bugs: the script expected an
error and the engine gave none (see ADR-0009 V7).

## ADR-0001: App lifecycle

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| V1 method-callable | Target freed; the Callable reads invalid | yes | A method Callable holds an object ID only: the Builder's back-callables are safe |
| V1 connection-target | Target freed; 0 connections left | yes | A connection does not keep its target |
| V1 connection-emitter | Emitter freed while its target lives | recorded | A connection does not keep its emitter either |
| V1 connected-lambda | Captured object alive while the lambda is connected | recorded | A connected lambda holds what it captures; lambda ban stands |
| V1 lambda-capture | Captured object alive | yes | Lambdas hold captured RefCounted strongly |
| V1 lambda-release | Captured object still alive after the lambda is dropped | recorded (unexpected) | Needs a second look: the check may still hold a reference. Matters for tests only (lambdas are banned in `src/`) |
| V1 bind-arg | Bound argument alive | yes | `bind()` holds its arguments strongly; ban stands |
| V1 bind-target | Method target freed while the bound Callable lives (Callable invalid) | recorded | The inner method Callable holds an ID |
| V1 lambda-self-nocapture | Object freed after a lambda made in its method (no `self` use) outlives it | recorded | A lambda that never uses `self` does not keep `self` alive |
| V1 lambda-self-use | Object alive after a lambda that reads a member outlives it | yes | A lambda that uses `self` holds it strongly |
| V1 cycle-method | Both objects freed | yes | Method-Callable cycles do not leak: no `Battle.dispose()` needed |
| V1 cycle-lambda | Lambda cycle leaked | recorded | Confirms the reason for the lambda ban |

## ADR-0002: Catalogue format

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| W1 numbers | `3`, `3.0`, `160` all parse as `float` | yes | Integer check tests the value, as planned |
| W1 NaN | Parse error ("Expected 'true', 'false', or 'null', got 'NaN'") | recorded | Non-finite tokens never reach the validator; `non_finite` stays for computed values |
| W1 Infinity | Parse error | recorded | As NaN |
| W1 -Infinity | Parse error ("Expected ','") | recorded | As NaN |
| W1 duplicate-key | Parses OK; the last value wins (`{"a": 2.0}`), no error | recorded | The parser is silent: the CI `duplicate_key` scan stays |
| W1 bom-string | A leading U+FEFF in a string is a parse error | recorded | Not what the loader sees (next row) |
| W1 bom-file | `get_file_as_string` strips the file's BOM; parse OK | recorded | A BOM file loads correctly: the CI `bom_present` check is dropped |
| W1 null-document | Parse OK, data null | yes | The Error code decides, as planned |
| W1 make_read_only | Read-only; an in-place write is an error (+1) and the value stays 1 | recorded | The optional guard in Decision 5 is confirmed usable |
| W3 sort-every-level | Keys sorted at every level | yes | Canonical snapshot holds |
| W3 equal-snapshots | Different insertion orders give equal strings | yes | Snapshot detector works |
| W3 full-precision | Every value round-trips; a one-ulp change gives a different string | yes | No custom serializer needed |

## ADR-0004: Clock and determinism

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| V4 0.1+0.2 | 0.30000000000000004 | yes | binary64 floats |
| V4 16777217+1 | 16777218.0 | yes | binary64 floats |
| V4 mask | `-1 & 0xFFFFFFFF` = 4294967295 | yes | 64-bit int |
| V4 shift | `0xFFFFFFFF << 13` = 35184372080640 | yes | No overflow, 64-bit int |
| V4 typed-math | floori, ceili, absf, sqrt, isnan, is_finite as IEEE | yes | Decision 9 holds |
| V4 to_ticks | All Validation 3 values match | yes | Decision 6 holds |
| V4 float-countdown | 301 ticks for 5.0 s by repeated subtraction | yes | Confirms the integer-countdown rule |
| V4 SimRng(1), (0), (-1) | Golden values match, draw_count 3 | yes | Decision 7 holds on desktop arm64 |
| V4 clock-basic, bad-delta, 1800, drop_backlog | All as expected | yes | BattleClock rules hold |
| V4 jitter-half-phase | 600 one-tick frames of 600 | yes | Half-phase start gives one tick per frame at 60 Hz |
| V4 jitter-zero-phase | 300 zero-tick and 300 two-tick frames (control) | yes | Confirms why the half phase is needed |
| V4 round | `round(0.5)`=1, `round(2.5)`=3, `round(-0.5)`=-1 | recorded | Half away from zero |
| V4 arch | arm64 (`get_architecture_name`=arm64) | recorded | This run is the arm64 desktop baseline |
| V4 unwind-debug | After a runtime error the callee stopped and the caller continued | recorded | Single-path flag design holds in debug; release leg (SP15) still open |
| V9 | `application/run/delta_smoothing` exists, default true | yes | Key confirmed; `project.godot` sets it false (PROJ-4) |

## ADR-0006: Battle signals

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| V1 emit-continues | No type check at emit. `1.5` arrives as int 1 and `"y"` as StringName in typed params (silent). An incompatible value (`"x"` into `int`) or a missing argument logs an error, skips that listener, and the emit goes on | yes | Recording fakes must check types at record time (ADR-0007), as planned |
| V1 parse-time | `s.emit(1)` and `s.emit("x", "y")` reload OK | recorded | The analyzer does not check `emit()` arity |
| V2 | `get_script_signal_list()` gives own and inherited script signals only, as Dictionaries with `name` | yes | Main form used; fallback not needed |
| V2 branch | Fallback form gives the same list | recorded | Fallback also works |
| V3 connection-list | Keys `signal`, `callable`, `flags`; target is the object; method is StringName; flags 0 | yes | Listener-count tests read this shape |
| V3 get_connections | Same shape | yes | Either call may be used |
| V3 double-connect | ERR_INVALID_PARAMETER, an error pushed, nothing added | yes | As planned |
| V3 deferred-flag | flags 1 | yes | WIRE-5 can see deferred connections |
| V3 tscn-persist | flags 34 (includes CONNECT_PERSIST 2) | yes | `.tscn` connections are detectable |
| V3 freed-listener | 1 connection before free, 0 after | yes | Freed listeners drop out |
| V4 order | ABC, then ACB after disconnect and reconnect of B | yes | Test logs may assume connect order |
| V4 connect-during-emit | Running emit used a snapshot (MB; next emit BD) | recorded | Snapshot semantics |
| V4 disconnect-during-emit | Snapshot (MBC) | recorded | Snapshot semantics |
| V5 nested | A, T1, T2, B | yes | Depth-first: Decision 5 holds, no outbox |
| V5 re-emit | R1, R2, B, B | recorded | Re-emit is delivered in full (still forbidden, rule 7) |
| V6 loads (flow, stage_result), damage_applied, phase_changed, StageResult | All load and run; enum params deliver ints | yes | Enum-typed params and fields stand; no `int` branch |
| V6 EMITTER_KEYS | Parses; 3 StringName values, typed, read-only | yes | Typed const array stands |

## ADR-0007: Test harness and lint

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| V3 counts | Variadic lambda sees 0, 1, 6, 6 arguments | yes | One variadic lambda fake works; no per-arity branch |
| V3 stringname | `&"a"` reads TYPE_STRING_NAME | yes | Type check by `typeof()` works |
| V3 string-into-stringname | `"a"` stays TYPE_STRING (raw emitted type, no conversion) | yes | The fake catches a String sent for a StringName ID |
| V3 declared-types | `[2, 3, 4, 21, 5, 1]` | yes | Declared types readable from the signal list |
| V6 regex | Lookbehind `(?<![\w.])` matches as expected | yes | MATH-1 pattern works |
| V6 dir-access | 97 files listed under `res://types`, nested probe found | yes | Lint can walk the tree headless |
| V6 classdb-scan | 39 names from 12 ADR files | recorded | Scan works |
| V6 classdb (36 project names) | `class_exists` false for all 36 | yes | No class_name collides with an engine class |
| V6 classdb controls | Node, Input, Engine true | yes | Control check valid |
| V6 connection-token | `[connection signal=` found in a scene saved by ResourceSaver | yes | WIRE-7 token holds (editor save not run) |

## ADR-0008: Input resolver

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| V1a | A7, poke1, B7, returned; no error | yes | Synchronous emit with call back works; Decision 7 holds |
| V1b | Loop sees appended elements (3 of 3) | yes | Size-read loop holds |
| V1c | Listener disconnected mid-emit still gets that emit (MBC) | yes | Snapshot semantics |
| V1d hold | With `_hold := self`, finishes then frees | yes | Self-hold pattern works |
| V1d nohold | No crash; finishes and frees; no error | recorded | Even without the hold it was safe here; keep the hold |
| V1e | Callee stopped at the error; the caller continued all 3 passes (callee_after 0, caller_after 3) | no (ADR expected the caller to abort) | In debug the flag is not left set, so `recover_if_stuck` may never trigger in debug; keep it for release (ADR-0004 V4 release leg) |
| V2 | `Vector2(299, 500).x - 270` = 29.0 | yes | With ADR-0009 V1 |
| V3 | `is_finite` false for NAN and INF in a Vector2 | yes | Guards hold |
| V4 int-literal | Warning (raised to error in this project) | recorded | Callers must pass enum members |
| V4 cast-nomatch | Warning (raised to error in this project) | recorded | As above |
| V4 other-enum | Hard error (even with the warning ignored) | recorded | Another enum's value never parses |
| V4 runtime | No runtime check: 5, -1, 7 arrive unchanged, no error | yes | `register` must check explicitly, as planned |
| V5 | `Callable()` defaults parse; `is_valid()` false | yes | Defaults stay; no branch |
| V6 | `Array[Target]` with an inner class; `remove_at` keeps order; FakeResolver `super(a, b)` forwards; typed override works through the base type; `create()` returns plain InputResolver; override with no return does not load | yes | Fake pattern stands |
| V7 | `is_debug_build()` true in the editor run; `get_model_name()` = "Mac16,10" | yes | Desktop half done |
| V8 | WRITE truncates; READ_WRITE fails on a missing file; READ_WRITE plus `seek_end` appends; `flush` writes through; every `store_*` returns bool | yes | Append sink design holds |

## ADR-0009: Enemy entity and Combat

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| V1 | `Vector2(0.1, 0).x == 0.1` false; `Vector2(16777217, 0).x == 16777217` false; single-precision build | yes | Components are 32-bit; scalar rule stands |
| V2a | Analyzer rejects passing `Array[Enemy]` as `Array[Targetable]`; at run time it is an error | yes | Dependency rule 5 now sourced |
| V2b | Append of Enemy to `Array[Targetable]` works | yes | As planned |
| V2c | `as Enemy` returns the instance | yes | As planned |
| V2d | `targets.call()` assigns to `Array[Targetable]`, keeps type, same buffer | yes | As planned |
| V2e | `remove_at` and `erase` keep order | yes | Loop rules hold |
| V2f | Not observable from GDScript | recorded | Not required |
| V2g | `Dictionary[int, ReadContext]` parses and rejects a wrong value | yes | `_contexts` may now be typed |
| V3 | `is_finite` false for NAN, INF, -INF; NAN comparisons false | yes | Guards hold |
| V5 reap | Enemy, Health, Status, ReadContext all freed | yes | One-way ownership frees |
| V5 retry | 0 of 8 objects left; wave and combat freed | yes | Retry frees everything |
| V6 loads and run | All stubs load; `damage_applied` delivers `[2, 5]`; Enemy is Targetable | yes | No CombatTypes fallback needed |
| V6 int-to-enum-var | Warning (raised to error in this project) | recorded | Callers pass enum members |
| V7 no-super | Subclass `_init` with no `super(...)` loads and builds with no error; `spawn_id` stays 0 (default) | no (FAIL) | The engine does not enforce forwarding. Rule stays; enforced by lint INIT-1 |
| V7 no-init-noargs | Subclass with no `_init`, built with no args: error | yes | The engine checks args when no `_init` is written |
| V7 no-init-onearg | Subclass with no `_init`, built with one arg: works | yes | As planned |
| V7 combat-no-forward | Combat fake `_init()` with no `super(...)` builds with no error | no (FAIL) | Same as no-super; INIT-1 covers fakes under `tests/` |
| V7 combat-forward | Combat fake that forwards builds with no error | yes | The forwarding pattern works |

## ADR-0010: Sim/input split

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| V1 | Same file results as ADR-0008 V8; `get_open_error()` after a failed open = 7 (ERR_FILE_NOT_FOUND) | yes | Run-log sink holds |
| V2 (debug half) | `is_debug_build()` true in the editor run | yes | Release half waits on ADR-0001 V4 |
| V3 (desktop, path only) | `OS.get_user_data_dir()` = `/Users/<user>/Library/Application Support/Godot/app_userdata/<project>` | recorded | Path known; the windowed write-and-find step is still to run |
| V4 typeof | TYPE_INT | yes | As planned |
| V4 find_key | `E.find_key(2)` = "B" | yes | Names from `find_key` work |
| V4 keys | `keys()` = OK, A, C, B (declaration order); values 0, 1, 3, 2 | recorded | `keys()[v]` would give the wrong name: use `find_key` |
| V4 override-explicit, inferred | Both load; `pick()` returns 2 | yes | As planned |
| V4 override no-return, null | Neither loads | yes | Enum overrides need an explicit enum return |
| V4 cycle | `try_pin(-1)`=1, `try_pin(1)`=0 | yes | Cyclic class_name reference works; no HeroResults branch |

## ADR-0011: Rendering

| Item | Observed | Matches | Consequence for the ADR |
|---|---|---|---|
| V6 | `const TEXT_SIZES: PackedInt32Array = [21, 24, 36]` parses and reads `[21, 24, 36]` | yes | Packed const stands; fallback not needed |
| V6 fallback | `Array[int]` form also parses, typed | recorded | Fallback available |

## Still open

Verification items this run did not answer. Phone checks (user instruction,
2026-11-04): phone testing is set aside for now, and the future device is an
iPhone. Each item is tagged "before acceptance, Mac", "after acceptance,
iPhone" or "after acceptance, Android-only deferred" (waits for an Android
device; the iPhone run covers the iOS equivalent where one exists).

- **ADR-0001**: V2 teardown timing (integration test plus a manual editor run with a Control under the pointer): before acceptance, Mac. V3 editor leg: before acceptance, Mac. V1 lambda-release second look: before acceptance, Mac (tests only). V3 export leg (iOS export): after acceptance, iPhone. V4 release error output (iOS release export, Xcode console): after acceptance, iPhone. V3 and V4 Android export and `adb logcat`: after acceptance, Android-only deferred.
- **ADR-0002**: W2 export of the data files (iOS export): after acceptance, iPhone. W2 Android export: after acceptance, Android-only deferred.
- **ADR-0004**: desktop legs of V1, V2 and V7 (ADR-0003 spike SP1, SP14, SP10, SP11): before acceptance, Mac. V4 release-export unwind leg (Mac release export): before acceptance, Mac. V9 SP14 stall compare with smoothing on and off: before acceptance, Mac. Phone legs of V1, V2 and V7, V3 cadence (SP14) and the V4 phone leg (SP15): after acceptance, iPhone. V7 Android lifecycle leg: after acceptance, Android-only deferred.
- **ADR-0006**: none of V1 to V6. (Other preconditions, such as `/architecture-review`, are not verification items.)
- **ADR-0007**: V1 gdUnit4 exit ladder (Mac and Linux); V2 error capture; V4 import on a fresh clone; V5 CI action (scratch branch); V6 editor save of a scene and no `prototypes/` path under the main project's `.godot/`; V7 export preset file (filter keys, iOS preset signing fields): all before acceptance, Mac. V7 Android keystore leg: after acceptance, Android-only deferred.
- **ADR-0008**: none before acceptance. V7 debug-export and phone legs and V8 phone leg: after acceptance, iPhone. The V1e release leg is ADR-0004 V4's (before acceptance, Mac).
- **ADR-0009**: none before acceptance (V2f is recorded as not observable). V4 whole-tick cost: after acceptance, iPhone; the Adreno device run: after acceptance, Android-only deferred.
- **ADR-0010**: V3 desktop windowed run (write one line, find the file at the recorded path): before acceptance, Mac. V2 release half (from ADR-0001 V4): after acceptance, iPhone. V3 phone run (file from the app container via Xcode): after acceptance, iPhone. V3 `adb exec-out run-as` leg: after acceptance, Android-only deferred.
- **ADR-0011**: V1 to V5 desktop legs (render-budget prototype): before acceptance, Mac. V1 to V4 phone legs (Xcode Metal frame capture for V1): after acceptance, iPhone. Android GPU Inspector leg: after acceptance, Android-only deferred.
- **ADR-0003** (spike results live in `prototypes/adr-0003-device-spike/README.md`): SP0 to SP13 desktop legs: before acceptance, Mac. Phone legs: after acceptance, iPhone. SP4 predictive back, SP8 Android export dialog, SP9 Android density, SP10 Android backgrounding and back gesture (C1), SP12 split screen: after acceptance, Android-only deferred.
