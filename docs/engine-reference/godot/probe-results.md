# Godot Engine Probe Results

| Field | Value |
|-------|-------|
| **Date** | 2026-11-04 |
| **Engine** | 4.7.2.stable.official.ed1daf0bf (official Linux build, SHA512 checked against the release's `SHA512-SUMS.txt`) |
| **Platform** | Linux x86_64, `--headless` (DisplayServer `headless`), debug build (`OS.is_debug_build()` true) |
| **gdUnit4** | Not used in the 2026-11-04 run; 6.2.0 in the 2026-11-05 run (see "gdUnit4 6.2.0 on 4.7.2") |

## How these probes were run

Each probe is a throwaway `extends SceneTree` script in a scratch Godot project outside the repo. Each script prints `PROBE <ADR>-<id> <answer>` lines and quits. Every run used `--headless` under `timeout 60`. Settings probes read effective values through `ProjectSettings`, once in an empty project (engine defaults) and once in a project that sets every ADR-0003 Decision 1 key. Godot never ran against this repo, and no `.godot/` folder was written here.

These scripts are not the permanent probes. Per ADR-0007 Decision 7, the CI story brings the probe tests under `tests/unit/engine/` and adds a row here per probe on each new engine or gdUnit4 version. An answer that differs from a row below is a review item.

Status key: **verified 4.7.2 headless** means the answer below came from a run. **not run** names who or what the check still needs.

## ADR-0001: App lifecycle

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0001-V1a | Does `Callable(a, &"m")` stored on `b` keep RefCounted `a` alive? | No. `a` frees at once; the stored Callable then reads `is_valid() == false`. | Yes | ADR treats the answer as unknown and holds either way. Method Callables are weak: the Builder must keep every Callable target alive by a strong ref elsewhere. verified 4.7.2 headless |
| ADR-0001-V1b | Does a connection `a.sig` to `b.m` keep target `b` alive? | No. `b` frees, and the connection is removed (`a.sig.get_connections()` is empty). | Yes | Signal connections form no strong cycle. verified 4.7.2 headless |
| ADR-0001-V1c | Does that connection keep source `a` alive? | No. `a` frees. | Yes | verified 4.7.2 headless |
| ADR-0001-V1d | Does `Callable(b, &"m").bind(a)` keep `a` alive? | Yes: bound args are strong. The target `b` is still weak (frees on drop). | Yes | Backs the B9 ban on `bind()` with a sim object. verified 4.7.2 headless |
| ADR-0001-V1e | Does a lambda that captures `a` keep `a` alive? | Yes. Setting the outer local to null does not free it (capture is by value). It frees once the lambda is dropped and its frame has returned. | Yes | Backs the B9 ban on lambdas. verified 4.7.2 headless |
| ADR-0001-V1f | Battle kept, sim holds `Callable(battle, &"halted")`: does the call return a `bool`? | Yes (`false`). Dropping `battle` then frees it: no cycle. | Yes | Must-pass case passes. verified 4.7.2 headless |
| ADR-0001-V6a | After `remove_child()` (plus `PROCESS_MODE_DISABLED` and `queue_free()` in the same call stack), does a child view get `_process`, or an adapter with `PROCESS_MODE_ALWAYS` get `_input` or `_unhandled_input`? | No. Over 2 injected mouse presses and 3 frames, all counts stayed 0, for a queued subtree and for one kept alive out of the tree (`can_process()` false). In the tree, the same nodes did get all three. | Yes | Presses sent by `Input.parse_input_event()`. verified 4.7.2 headless |
| ADR-0001-V6b | After `queue_free()`, `await process_frame`: do weakrefs read null? | Yes, for the wrapper Node, its child, and a RefCounted held only by the child. | Yes | verified 4.7.2 headless |
| ADR-0001-V8 | Does `push_error()` reach the log in an exported release build? | Not run | n/a | not run (needs device: exported release build on a phone) |

## ADR-0002: Catalogue storage

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0002-E1 | Does `JSON.parse()` return `50` as `int` or `float`? | `float`. So are `50.0` and `1e3`, also through `JSON.parse_string()`. `9007199254740993` reads back as `9007199254740992.0`. | Yes | Ceilings up to 1,000,000 stay exact. verified 4.7.2 headless |
| ADR-0002-E2 | What does a repeated key do? | Last value wins (`{"k": 2.0}`), `parse()` returns `OK`, no error message. | Yes | Only the CI raw-text scan catches it. verified 4.7.2 headless |
| ADR-0002-E3a | Index write `a[0] = 9` on a read-only Array: does the next line run? | No. `SCRIPT ERROR: Invalid assignment on read-only value`; the function aborts; its caller goes on. | Yes | verified 4.7.2 headless |
| ADR-0002-E3b | `append()` on a read-only Array? | Logs `ERROR: Array is in read-only state`, the array stays unchanged, the next line runs. | Yes | verified 4.7.2 headless |
| ADR-0002-E3c | Key write on a read-only Dictionary? | Logs `ERROR: Dictionary is in read-only state` and a `SCRIPT ERROR`, then the function aborts; its caller goes on. | Yes | Same as the Array index write. verified 4.7.2 headless |
| ADR-0002-E3d | Is `make_read_only()` deep? | No. An inner Array of a read-only Dictionary still takes `append()` and reports `is_read_only() == false`. | Yes | Matches ADR-0006's "it is shallow". verified 4.7.2 headless |
| ADR-0002-BOM | How is a UTF-8 BOM handled? | `FileAccess.get_as_text()` strips a UTF-8 BOM (text length 8 for `{"x": 1}`), and that text parses. A String that still starts with U+FEFF fails `JSON.parse()` with error 43, "Unexpected character". | Yes | The ADR's own strip is a harmless second guard. verified 4.7.2 headless |
| ADR-0002-KEY | String vs StringName Dictionary keys | Each hits the other: a String-keyed dict finds `&"id"`, a StringName-keyed dict finds `"id"`. Writing `"id"` then `&"id"` leaves one entry whose key stays `String`. JSON keys are `String`. `"a" == &"a"` is true. | Partly | Lookups cannot tell the two key types apart, so V5 must test `typeof()` of each key, not hits. verified 4.7.2 headless |

## ADR-0003: Input adapter, display, lifecycle (S0a headless part)

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0003-S0a-1 | Does `InputEvent.DEVICE_ID_EMULATION` exist, and its value? | Yes, `-1`. | Yes | verified 4.7.2 headless |
| ADR-0003-S0a-2 | `InputEventScreenTouch.canceled` and `InputEvent.is_canceled()`? | Both exist. Default false; after `canceled = true`, `is_canceled()` is true and `is_pressed()` false. `InputEventMouseButton` also has `canceled`. | Yes | Real cancel delivery is S4 (device). verified 4.7.2 headless |
| ADR-0003-S0a-3 | The six focus and pause notifications and their values | `NOTIFICATION_APPLICATION_RESUMED` 2014, `_PAUSED` 2015, `_FOCUS_IN` 2016, `_FOCUS_OUT` 2017, `NOTIFICATION_WM_WINDOW_FOCUS_IN` 1004, `_FOCUS_OUT` 1005. | Yes | Names only; which ones fire where is S5. verified 4.7.2 headless |
| ADR-0003-S0a-4 | `NOTIFICATION_WM_GO_BACK_REQUEST`? | Exists, 1007. | Yes | verified 4.7.2 headless |
| ADR-0003-S0a-5 | `DisplayServer.get_display_safe_area()`, `screen_get_dpi()`, `get_display_cutouts()` | All exist (also `screen_get_scale()`, `screen_get_usable_rect()`). Headless values mean nothing: safe area zero rect, dpi 96, cutouts `[]`. | Yes | Real values are S7 and S8 (device). verified 4.7.2 headless |
| ADR-0003-S0a-6 | Does the names probe pass through `res://.claude/scripts/godot-parse-check.gd`? | Yes: `ok`, exit 0. | Yes | verified 4.7.2 headless |
| ADR-0003-S9-stretch | `display/window/stretch/mode`, `aspect`, `scale`, `scale_mode` | All exist. Engine defaults: `disabled`, `keep`, `1.0`, `fractional`. Set values read back `canvas_items`, `keep`, `1.0`, `fractional`. | Yes | Three of the four equal the engine default, so the editor drops them on save. The dump checks effective values, as S0a says. verified 4.7.2 headless |
| ADR-0003-S9-window | `display/window/size/viewport_width`, `viewport_height`, `mode` | Exist. Defaults 1152, 648, 0. Set values read 540, 960, 0. `WINDOW_MODE_WINDOWED` is 0. | Yes | verified 4.7.2 headless |
| ADR-0003-S9-mobile | `display/window/size/mode.mobile=3` override | Not a setting until the file sets it. Once set, `has_setting()` is true and it reads 3; on desktop `get_setting_with_override("display/window/size/mode")` still gives 0. `WINDOW_MODE_FULLSCREEN` is 3. | Yes | Override use on a phone is S0b. verified 4.7.2 headless |
| ADR-0003-S9-orient | `display/window/handheld/orientation=1` is portrait? | Exists, default 0. Hint order "Landscape, Portrait, ...", and `DisplayServer.SCREEN_PORTRAIT` is 1. | Yes | verified 4.7.2 headless |
| ADR-0003-S9-pointing | `input_devices/pointing/emulate_touch_from_mouse`, `emulate_mouse_from_touch` | Exist. Defaults false and true, the same as the ADR's values. | Yes | Editor drops both on save. verified 4.7.2 headless |
| ADR-0003-S9-agile | `input_devices/buffering/agile_event_flushing` | Exists, default false. | Yes | verified 4.7.2 headless |
| ADR-0003-S9-goback | `application/config/quit_on_go_back` | Exists, default true. Set false reads false. | Yes | verified 4.7.2 headless |
| ADR-0003-S9-edge | Name of the 4.5+ Android edge-to-edge key | No `ProjectSettings` key holds "edge_to_edge". The binary has `screen/edge_to_edge` in the Android export options block, beside `screen/immersive_mode` and `screen/support_*`. | No | It is an Android export preset option (`export_presets.cfg`), not a `project.godot` key, so a settings dump cannot check it. Name from binary strings, not from the export UI. verified 4.7.2 headless (name only) |
| ADR-0003-S9-run | `application/run/max_fps`, `low_processor_mode`, `display/window/vsync/vsync_mode`, `application/run/delta_smoothing` | All exist. Defaults 0, false, 1 (`VSYNC_ENABLED`), true. | Yes | See ADR-0004 E6 and E8. verified 4.7.2 headless |
| ADR-0003-S9-mouse | Name of the 4.5 recursive mouse disable on Control | `mouse_behavior_recursive` (int). Also `focus_behavior_recursive`. | Yes | verified 4.7.2 headless |
| ADR-0003-S1 | Event order across input, process and physics callbacks | Not run | n/a | not run (needs person: real mouse on desktop; Android part on device) |
| ADR-0003-S2 | Emulated mouse beside real touch | Not run | n/a | not run (needs device and person) |
| ADR-0003-S3 | Control consumption of press, move, release | Not run | n/a | not run (needs person: real clicks and drags) |
| ADR-0003-S4 | Cancel by shade, system gesture, call, palm | Not run | n/a | not run (needs device) |
| ADR-0003-S5 | Which lifecycle notifications reach which node | Not run | n/a | not run (needs person on desktop: focus, alt-tab, minimise; device for phone cases) |
| ADR-0003-S6 | Positions and resize | Not run | n/a | not run (needs person: real window and clicks) |
| ADR-0003-S7 | Safe area and cutouts | Not run | n/a | not run (needs device) |
| ADR-0003-S8 | Density | Not run | n/a | not run (needs device) |
| ADR-0003-TapScreen | 50 taps give 50 `tapped` | Not run | n/a | not run (needs device and person) |

## ADR-0004: Fixed tick clock

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0004-E1 | Do `round` and `roundi` round halves away from zero, negatives too? | Yes: 0.5 to 1, 1.5 to 2, 2.5 to 3, -0.5 to -1, -1.5 to -2, -2.5 to -3. `floori(-0.5)` is -1. `round` returns `float`, `roundi` returns `int`. | Yes | verified 4.7.2 headless |
| ADR-0004-E2 | Is `Vector2` 32-bit? | Yes. `Vector2(0.1, 0).x == 0.1` is false (stored 0.10000000149011612); `Vector2(16777217, 0).x` reads 16777216. | Yes | verified 4.7.2 headless |
| ADR-0004-E3a | Is `_process` delta unclamped real seconds? | No. It is clamped to about `max_physics_steps_per_frame / physics_ticks_per_second`. At defaults (8, 60), stalls of 0.25, 0.5 and 1.0 s gave deltas of 0.13 to 0.15 s. With 2 steps: about 0.035 to 0.047 s. With 100 steps: 0.49, 0.999, 0.254 (real time). `delta_smoothing` off gave the same clamp. | No | The physics settings set the clamp, so they are not free to change. The clock's own cap (4 ticks) is below this clamp, so the clock still behaves as written. verified 4.7.2 headless |
| ADR-0004-E3b | Is delta scaled by `Engine.time_scale`? | Yes. With `time_scale = 2.0`, a 0.1 s stall gave delta 0.198. | Yes | verified 4.7.2 headless |
| ADR-0004-E3c | First frame delta | Not tied to wall time: 0.0167 (1/60) or 0.0083 across runs. | Partly | The first-running-frame rule (`min(delta / dt, 1.0)`) bounds it anyway. Whether smoothing changes paced frames cannot be judged headless (no vsync). verified 4.7.2 headless |
| ADR-0004-E4 | Does `Engine.get_architecture_name()` exist? | Yes, returns `x86_64`. `OS.has_feature("x86_64")` true, `"arm64"` false. | Yes | arm64 value needs a phone. verified 4.7.2 headless |
| ADR-0004-E5a | Does an equal `seed` repeat on `RandomNumberGenerator`? | Yes, also for `randi_range` and `randf_range`. | Yes | verified 4.7.2 headless |
| ADR-0004-E5b | Does saving and restoring `state` repeat? | Yes. | Yes | verified 4.7.2 headless |
| ADR-0004-E5c | Do `Array.shuffle()`, `pick_random()` and global `randi()` use the global generator? | Yes: after `seed(777)` twice, all three repeat. A local `RandomNumberGenerator` does not disturb the global stream. | Yes | L-RNG must ban all three in sim code. verified 4.7.2 headless |
| ADR-0004-E6 | Is low processor mode off by default? | Yes: setting false, `OS.low_processor_usage_mode` false. | Yes | verified 4.7.2 headless |
| ADR-0004-E7 | Parent `_process` before child at equal priority; deferred calls after `_process`? | Yes: order `parent`, `child`, then the call the parent deferred. | Yes | verified 4.7.2 headless |
| ADR-0004-E8 | `application/run/max_fps` name and default | Exists, default 0; set 60 gives `Engine.max_fps` 60. | Yes | Pacing on a 90 or 120 Hz panel is V13. verified 4.7.2 headless |
| ADR-0004-V13 | Tick cost and pacing on a phone | Not run | n/a | not run (needs device) |

## ADR-0005: Stat accessor

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0005-E1 | Do `const K := &"x"` and `const` Dictionaries keyed by them parse, and are `ROWS`, each inner table, `KIND`, `ROLE_TAG` read-only? | Yes to all. Keys are `StringName`. `const` makes inner tables read-only too. | Yes | verified 4.7.2 headless |
| ADR-0005-E3a | `Object.get(&"damage")` returns a script `var`? | Yes, `12.5` as `float`. | Yes | verified 4.7.2 headless |
| ADR-0005-E3b | `Object.get(&"nope")` on an unknown name | Returns `null`, logs nothing. | Yes | verified 4.7.2 headless |
| ADR-0005-E3c | Does a StringName-keyed Dictionary hit on a `String` key? | Yes: `ROWS[&"tower"].get("cost", false)` is true. | Yes | Risk R2 takes its "hits" branch. verified 4.7.2 headless |
| ADR-0005-E4 | Does `WeakRef.get_ref()` read null once the last strong ref drops? | Yes, at once. A self weakref made in `_init` does not keep the owner alive. | Yes | verified 4.7.2 headless |
| ADR-0005-E5 | Does a `String` literal into a `StringName` parameter cost more than a constant? | Not a literal: 200,000 calls took the same time (ratio 0.99). A `String` variable did cost more (ratio 1.42). | No | The compiler converts a literal once. L-STAT-1 still stands on typo safety, not on cost. verified 4.7.2 headless |
| ADR-0005-E6 | Do reads create no Object and keep `MEMORY_STATIC` flat? | Yes: 10,000 reads after warm-up, `OBJECT_COUNT` 1492 to 1492, `MEMORY_STATIC` delta 0 bytes. One `RefCounted.new()` moves `OBJECT_COUNT` by 1, so the monitor sees RefCounted objects. | Yes | Read path is a stand-in, not the real accessor. verified 4.7.2 headless |
| ADR-0005-E7 | `ClassDB.class_exists()` for `StatKeys`, `ReadContext`, `StatAccessor` | All false. None of the other 21 ADR class names checked is an engine class either. | Yes | verified 4.7.2 headless |
| ADR-0005-ABS | Does `@abstract` on a `class_name` stop all instancing? | Partly. `StatKeys.new()` in code is a parse error ("Cannot construct abstract class"). But `load(path).new()` builds an instance with the script attached and logs nothing, and `can_instantiate()` is true (`is_abstract()` true). | Partly | "It can never be instanced" holds only for static calls. verified 4.7.2 headless |

## ADR-0006: Battle signal contracts

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0006-E1 | Shape of `get_script().get_script_signal_list()` | Script signals only, base script included; no native signals. Entry keys `name`, `args`, `default_args`, `flags`, `id`, `return`. Arg keys `name`, `class_name`, `type`, `hint`, `hint_string`, `usage`. `int`: type 2, usage 0. `StringName`: type 21, usage 0. Enum: type 2, `class_name` `SigEmitterProbe.Phase`, usage 65536 (`PROPERTY_USAGE_CLASS_IS_ENUM`). Object param: type 24, `class_name` the script or native class. Untyped: type 0, usage 131072. | Yes | Plain typed args have usage 0, not the default usage flags. verified 4.7.2 headless |
| ADR-0006-E2a | `emit()` with a wrong type | `emit()` does not check. Each listener call fails with `ERROR: Error calling from signal ... Cannot convert argument 1 from int to StringName`; no listener runs; the emitter's next line runs. | Yes | One engine error per listener. verified 4.7.2 headless |
| ADR-0006-E2b | `emit()` with too few or too many args | Each listener call fails with "Method expected 2 argument(s), but called with 1" (or 3); the emitter goes on. | Yes | verified 4.7.2 headless |
| ADR-0006-E2c | Does a wrong type ever convert? | Yes: `float` 2.7 into an `int` parameter arrives as 2, with no error. | Yes | verified 4.7.2 headless |
| ADR-0006-E3 | Does a `String` convert to a typed `StringName` parameter? | Yes, silently, in `emit()` and in a direct call. `"a" == &"a"` is true. | Yes | A fake with a typed `StringName` parameter cannot see a `String` payload, so V6's fake must take untyped args and check `typeof()`. verified 4.7.2 headless |
| ADR-0006-E4 | Dictionary keys and `flags` for a plain `connect()` | Both `get_signal_connection_list()` and `Signal.get_connections()` give `signal`, `callable`, `flags`; `flags` is 0; `signal` is a `Signal`. | Yes | verified 4.7.2 headless |
| ADR-0006-E5 | Listener order, and a nested emit | Connection order. A nested emit from listener 2 runs all its listeners before listener 3 of the outer emit. | Yes | verified 4.7.2 headless |
| ADR-0006-E6 | Does a rest-parameter method `func m(...args: Array)` work as a connection Callable? | Yes, for signals of 2, 1 and 1 (untyped) args. | Yes | verified 4.7.2 headless |

## ADR-0007: Headless test harness (parts that need no gdUnit4)

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0007-H4 | Does a typed override with no `return` fail the parse check? | Yes: "Not all code paths return a value" (also with a partial return, and in a non-override). `return null` in an `-> int` override also fails. An untyped override of a typed method passes. | Yes | Parse check exits 1. verified 4.7.2 headless |
| ADR-0007-H5 | Does `debug/gdscript/warnings/confusable_capture_reassignment` exist? | Yes, default 1 (warn). Set to 2, a lambda that assigns a captured local fails to parse ("Reassigning lambda capture does not modify the outer local variable"). | Yes | verified 4.7.2 headless |
| ADR-0007-F2 | Does `debug/gdscript/warnings/exclude_addons` exist? | No. Not a setting on 4.7.2, and setting it in `project.godot` does nothing. The setting now is `debug/gdscript/warnings/directory_rules`, default `{"res://addons": 0}`; that default already skips warnings in `res://addons/` (the same H5 file failed at the root and passed under `addons/`). | No | Rename the key in F2. verified 4.7.2 headless |
| ADR-0007-CLASH-native | `class_name` equal to a native class | Parse error: `Class "Timer" hides a native class`. | Yes | `Battle` is not native and passes. verified 4.7.2 headless |
| ADR-0007-CLASH-script | Two scripts with one `class_name` | `--import` reports no error. At parse, one of the two fails (`hides a global script class`); the other, and a script that uses the name, load fine. | Yes | So L-NAME-1 is still needed for script clashes. verified 4.7.2 headless |
| ADR-0007-H8 | Do scripts under a hidden folder load? | Yes: `-s res://.claude/scripts/...` runs, `load()` is not null, `ResourceLoader.exists()` true. | Yes | No copy to `tools/ci/` needed. verified 4.7.2 headless |
| ADR-0007-H7 | Linux archive name and SHA512 | `Godot_v4.7.2-stable_linux.x86_64.zip`, SHA512 `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65` (matches the downloaded zip). | Partly | Download URL is for the CI story to copy from the release page. verified 4.7.2 headless (name and hash) |
| ADR-0007-H1, H2 (c) | gdUnit4 exit codes, unclaimed push_error | See "gdUnit4 6.2.0 on 4.7.2" | Yes | verified 4.7.2 headless on 6.2.0 |
| ADR-0007-H2 (a), (b), (d), (e), H3, H6, H9 | Other push_error cases, orphans, fresh clone, un-awaited `is_push_error` | Not run | n/a | not run (needs gdUnit4) |

## ADR-0008: Input resolver core

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0008-R1 | Does a call made inside a handler return before `emit()` calls the next listener? | Yes. Trace: `a.start`, `a.helper_returned`, `a.end`, then the next listener. | Yes | verified 4.7.2 headless |
| ADR-0008-R2a | A runtime error in one handler: are later listeners still called? | Yes. Handler `b` aborts at the error, `c` runs, the emitter goes on. | Yes | Debug build. verified 4.7.2 headless |
| ADR-0008-R2b | A runtime error in the emitter's own function mid-loop | Aborts that function only (loop stops at the error); the caller goes on. | Yes | verified 4.7.2 headless |
| ADR-0008-R3a | `Vector2(306.0, 480.0).x == 306.0`; NaN and INF survive in `Vector2`? | All true: x and y exact; `is_nan`, `is_inf` (also `-INF`) true. | Yes | verified 4.7.2 headless |
| ADR-0008-R3b | Squared-slop edge at 36 units | Integer press (306, 480) to (342, 480): `dx*dx + dy*dy` is exactly 1296.0, so `>= 36*36` is true. Press at x 306.3 plus 36: stored dx is exactly 36. Press at 306.7 plus 35.99999: stored dx 35.999969, under slop. `Vector2(16777217, 0).x != 16777217`. | Yes | Below 2^24 integer positions are exact; non-integer ones round to float32. verified 4.7.2 headless |
| ADR-0008-R4 | `is_finite()` for NAN, INF, -INF, 0.0 | false, false, false, true. | Yes | verified 4.7.2 headless |
| ADR-0008-R5 | Does an `int` signal parameter report `TYPE_INT`? | Yes: `target` type 2; `release_pos` type 5 (`TYPE_VECTOR2`). | Yes | verified 4.7.2 headless |
| ADR-0008-R6 | Does a bad int pass into a typed enum parameter? | Yes. `2 as Accepts` and `99 as Accepts` both pass with no error, and so does an untyped `Variant` 7. | Yes | Decision 2's range check is required. verified 4.7.2 headless |

## ADR-0009: Enemy entity, roster and Combat API

Copied from ADR-0009's probe table (desktop debug, 4-core Xeon VM). They join the probe suite as `combat_probe_test.gd` (ADR-0007 Decision 7).

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0009-B1 | Is `Array[Enemy]` accepted where `Array[Targetable]` is expected? | No: typed, it fails at parse time; through a `Variant` the callee aborts silently and the caller goes on. `Array[Targetable]` takes an `Enemy`. `as Enemy` on a plain `Targetable` is null. | Yes | verified 4.7.2 headless |
| ADR-0009-B2 | Does `for t: Targetable in list` work? | Yes. | Yes | verified 4.7.2 headless |
| ADR-0009-B3 | Does `Callable.call()` keep the array type? | Yes, and it returns the same instance. | Yes | verified 4.7.2 headless |
| ADR-0009-B4 | Do `Combat` and `DamageEvent` naming each other parse and load? | Yes. Payload types `int`, `StringName`, `float`, `Vector2`, `bool`, `int`. | Yes | verified 4.7.2 headless |
| ADR-0009-X1 | What does `+=` on a missing `Dictionary` key do? | It errors and aborts. | Yes | verified 4.7.2 headless |
| ADR-0009-X2 | Does `var t := max(...)` parse? | No: `inference_on_variant` is an error. | Yes | verified 4.7.2 headless |
| ADR-0009-X3 | Cost of `remove_at` on 60 items | About 0.36 µs. | Yes | Desktop debug. verified 4.7.2 headless |
| ADR-0009-X4 | Is GDScript `float` 64-bit? | Yes. | Yes | verified 4.7.2 headless |
| ADR-0009-X5 | Does `Enemy`'s typed `_init` work? | Yes, because `Targetable` has none. A subclass `_init()` without `super()` silently skips a base `_init`. | Yes | verified 4.7.2 headless |
| ADR-0009-X6 | Cost of 480 range checks a tick | 157 µs p50, 199 µs p95 (about 0.33 µs a check); 88 µs p95 with `PackedFloat64Array` data. | Yes | Desktop debug, 4-core Xeon VM. verified 4.7.2 headless |
| ADR-0009-X7 | Is `DamageEvent.target` a strong reference? | Yes; setting it to null frees the enemy. | Yes | verified 4.7.2 headless |
| ADR-0009-P2 | Targeting bench in a release export | Not run | n/a | not run (needs a release export) |

## ADR-0010: Sim/input split, command results, dev telemetry

Copied from ADR-0010's probe table (Linux, editor binary; T by the author, R and K by godot-specialist).

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0010-T1, R4 | `FileAccess.open` on a missing file, and appends | `open(p, READ_WRITE)`: `null`, error 7. `WRITE` creates it. `READ_WRITE` plus `seek_end()` appends. `get_length()` tracks appends; static `get_size()` exists; dropping a handle without `close()` loses no flushed line. | Yes | verified 4.7.2 headless |
| ADR-0010-T2, T3 | `open()` in a missing directory; `store_line()` return | `null`, error 7, no engine message. `store_line()` returns `bool`, `false` on a `READ` handle, silently; `flush()` and `close()` return `void`. | Yes | verified 4.7.2 headless |
| ADR-0010-T4, R7 | `user://` headless; debug flags in the editor binary | `user://` writes headless. `OS.is_debug_build()` and `has_feature("debug")` are true, `template_release` false. | Yes | verified 4.7.2 headless |
| ADR-0010-T5, R8 | `JSON.stringify` on telemetry values | Sorts keys; `StringName` becomes a string; default precision keeps the values. `NAN` becomes `null` with an engine warning; `INF`, even in a nested `Array`, writes `1e99999`, invalid JSON. | Yes | verified 4.7.2 headless |
| ADR-0010-T6, R1, R9 | Named enum `OK` against `Error.OK` | `enum E { OK, BUSY }`: `E.OK == 0`, qualified compare works. Bare `OK` in the class is `Error.OK`. Returning bare `OK` from a `-> BuildResult` function is a parse error; a caller's `r == OK` parses silently and is true. | Yes | verified 4.7.2 headless |
| ADR-0010-T7, K | `store_line` plus `flush` cost and crash safety | About 2 µs a line. A flushed line survives SIGKILL; an unflushed one is lost. | Yes | Desktop. verified 4.7.2 headless |
| ADR-0010-R2 | `call_bonus` as instance or static method | Both work; `int / int` truncates. | Yes | verified 4.7.2 headless |
| ADR-0010-R3 | Does a method `Callable` keep its sink alive? | No: the sink frees at once and the `Callable` goes invalid. | Yes | verified 4.7.2 headless |
| ADR-0010-R5, R6 | `Time`, `Crypto` headless; default version string | `Time.get_unix_time_from_system()` and `Crypto.generate_random_bytes()` work headless; `application/config/version` is `""` by default. | Yes | verified 4.7.2 headless |
| ADR-0010-M4, M2 | Release-export `OS.is_debug_build()` false; Android `user://` writes | Not run | n/a | not run (needs a release export and a phone) |

## ADR-0011: Battle field rendering and draw-call budget

Copied from ADR-0011's probe table (run 2026-11-05; Linux x86_64, 4 cores, editor binary, debug). ADR-0011 cites R1 to R20; its table has rows for the IDs below. R8 to R12 and R19 have no row there, so none is recorded here.

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| ADR-0011-R1, R2 | Do the draw-call and frame-time monitors exist? | Yes: `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `TIME_PROCESS`, `RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`, `Performance.add_custom_monitor`. The draw-call monitor reads 0 headless. | Yes | Counts need M9a. verified 4.7.2 headless |
| ADR-0011-R3, R14 | `draw_circle` signature; default line width | `draw_circle(position, radius, color, filled = true, width = -1.0, antialiased = false)`. `draw_polyline`, `draw_multiline`, `draw_arc`, `draw_line` default `width = -1.0`, a thin line primitive, not a quad. No dashed arc. | Yes | Never pass width -1. verified 4.7.2 headless |
| ADR-0011-R4, R16 | Does `Geometry2D.offset_polyline` give square path corners? | Yes: `offset_polyline(path, 36 or 34, JOIN_MITER, END_BUTT)` gives exact square 90 degree corners, flush ends, one polygon that triangulates. A sharp turn bevels. A self-crossing path merges into one valid polygon with no error. A loop wider than the path adds a clockwise hole polygon. | Yes | So the bake checks crossings itself. verified 4.7.2 headless |
| ADR-0011-R5 | Is the RD 2D batcher present? | Yes: `rendering/2d/batching/item_buffer_size` (16384) exists. `msaa_2d` is 0. `project.godot` sets `rendering_method="mobile"`. | Yes | Batching across nodes needs M9a. verified 4.7.2 headless |
| ADR-0011-R6, R20 | Does `_draw` run headless, and in what order? | Yes, after that frame's `_process`. Sibling `_draw`s run in tree order. A node not queued keeps its old commands. | Yes | verified 4.7.2 headless |
| ADR-0011-R7, R15 | Fallback font sizes; `TextLine`; radial gradient | `ThemeDB.fallback_font` is a `FontFile`; it draws at 21, 24, 36 (a test string measured 100x30, 115x34, 173x50). `TextLine.add_string(text, font, font_size, ...)` and `TextLine.draw(canvas, pos, color, oversampling)` exist. `GradientTexture2D.FILL_RADIAL` exists. | Yes | Sharpness needs M3. verified 4.7.2 headless |
| ADR-0011-R13 | Cost of one `_draw` of about 115 commands | 1 polygon, 112 discs, one multiline, one ring, one string: 259 µs p50, 410 µs p95 over 400 frames. Command recording on a dummy renderer: about 2.2 µs a command. | Yes | A floor on GDScript cost, debug. verified 4.7.2 headless |
| ADR-0011-R17 | Does `MultiMeshInstance2D` exist? | Yes, with `texture`. Per-instance colour cannot be checked headless. | Yes | F1 layout needs a windowed check. verified 4.7.2 headless |
| ADR-0011-R18 | Which nodes carry AccessKit properties? | `Control` has `accessibility_name`, `accessibility_description`, `accessibility_live`; `Node` has none. | Yes | verified 4.7.2 headless |
| ADR-0011-M9a, M9b, F1, M3 | Draw calls and batching across nodes, frame time, MultiMesh layout and per-instance colour, text and disc edges | Not run | n/a | not run (needs a GPU: M9a desktop windowed, M9b phone) |

## gdUnit4 6.2.0 on 4.7.2

Run 2026-11-05 by the godot-specialist in the engine consultation of the fourth review: official Linux build of 4.7.2, `--headless`, the committed `addons/gdUnit4` 6.2.0. ADR-0007 reruns H1 and H2 after the 6.2.2 upgrade.

| Probe ID | Question | Result | Matches the ADR's expectation? | Note |
|---|---|---|---|---|
| GD-VER | Which gdUnit4 is committed? | `addons/gdUnit4` is 6.2.0. | n/a | ADR-0007 still upgrades to 6.2.2 (Migration 0). verified 4.7.2 headless |
| GD-IMPORT | Does `--headless --import` exit 0 with the addon? | Yes, exit 0. | Yes | verified 4.7.2 headless |
| ADR-0007-H1 pass | Exit code of a passing run | A suite of 2 passing tests exits 0: `Overall Summary: 2 test cases \| 0 errors \| 0 failures \| 0 flaky \| 0 skipped \| 0 orphans \|`. | Yes | verified 4.7.2 headless |
| ADR-0007-H1 fail | Exit code of a failing run | A deliberate failure exits 100. The CI form (`-d --remote-debug tcp://127.0.0.1:0`, stdin closed) also exits 100 on failures. | Yes | verified 4.7.2 headless |
| ADR-0007-H1 cache | Run with no class cache (no `.godot/`) | Exit 1, `Could not find type GdUnitTestCIRunner`. | Yes | Step 1 (`--import`) rebuilds it. verified 4.7.2 headless |
| ADR-0007-H1 empty | Run with no test cases | Exit 0, `No test cases found, abort test run!`. | Yes | The script maps it to 113 from `results.xml`. verified 4.7.2 headless |
| ADR-0007-H2c | Does an unclaimed `push_error` fail a test? | Only with `[gdunit4] report/godot/push_error=true` in `project.godot`: then exit 100. By default it passes (`GdUnitSettings.gd:135` defaults the setting to false). | Yes | The CI story commits the setting. H2 (b) is the setting-off case. verified 4.7.2 headless |
| GD-FAILFAST | What does a run without `-c` do after a failure? | Fail-fast is on (`GdUnitTestCIRunner.gd:107`): a suite stops at its first failed test; the rest are left out of the count and not reported as skipped. | n/a | `-c` keeps every test running and counted. verified 4.7.2 headless |
| GD-REMOTE | What does `--remote-debug tcp://127.0.0.1:0` print? | `ERROR: The remote port number must be between 1 and 65535` and `Unable to connect to host`. With `-d`, a script error opens a `debug>` prompt; stdin closed avoids it. | n/a | `run_tests.sh` drops the flag and closes stdin (`</dev/null`). verified 4.7.2 headless |
| ADR-0007-H10 file | Do `mock()`, `do_return()`, `spy()`, `verify()` work on a `class_name` file class with a typed `-> int` method? | Yes, all pass. | n/a | verified 4.7.2 headless |
| ADR-0007-H10 inner | Does `mock()` work on a class declared inside the test suite? | No: `Could not find base class` (MockBuilder error). | n/a | Doubles only of `class_name` file classes, or hand-written fakes. verified 4.7.2 headless |
| GD-PASSED | Does the per-suite `PASSED` label mean no failures? | No: it prints even when failures are counted. | n/a | The harness reads the exit code and `results.xml`, never that text. verified 4.7.2 headless |
| ADR-0011-HUD1 | What does a `Control` with `PRESET_TOP_WIDE` under a `Node2D` get? | `get_parent_area_size()` is (0, 0), size (0, 80), and it takes the `Node2D`'s offset. | No | ADR-0011 moves `HudTopBand` and `HudField` to a `CanvasLayer` (layer 1). verified 4.7.2 headless |
| ADR-0011-A11Y | Does `AccessibilityServer` hold the live-mode constants? | Yes: `LIVE_OFF`, `LIVE_POLITE`, `LIVE_ASSERTIVE` (also still on `DisplayServer`). `accessibility_live = AccessibilityServer.LIVE_POLITE` works. | Yes | verified 4.7.2 headless |

## Side findings (no ADR probe)

- `debug/gdscript/warnings/inference_on_variant` defaults to 2 (error). `var w := weakref(x)` fails to parse; write `var w: WeakRef = weakref(x)`. verified 4.7.2 headless
- A script variable named `log` shadows the global `log()` function and breaks the parse. verified 4.7.2 headless
- Seven of the 13 ADR-0003 Decision 1 keys equal the engine default, so the editor drops them from `project.godot` on save. The settings dump must check effective values, as S0a already says. verified 4.7.2 headless
