# Control Manifest

> **Engine**: Godot 4.7.2
> **Last Updated**: 2026-11-03
> **Manifest Version**: 2026-11-03
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008
> **Status**: Active. Regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Stories embed it when
they are written, and `/story-readiness` compares a story's version with this one
to find stories written against old rules. It always equals `Last Updated`: the
same date, for different readers.

This manifest is a programmer's quick reference taken from the Accepted ADRs, the
project config and the engine reference docs. For the reason behind a rule, read
its ADR.

**Device assumptions.** ADR-0006, ADR-0007 and ADR-0008 were accepted on best-guess
device assumptions, not on a phone spike: `docs/architecture/device-assumptions.md`
(memory, unverified, untested). Any rule that rests on an unverified engine item
carries `[assumed: see device-assumptions.md Dn/In/Ln]` before its source. The first
device build replaces each guess with a fact. A failed check revises its ADR, and
this manifest must then be regenerated.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine start-up*

### Required Patterns

Catalogue (ADR-0001)
- **Catalogue data must live under `res://data/catalogue/` as JSON text files, listed in one `manifest.json`. The loader must open only the files the manifest lists. A repeated path is a manifest error.** source: ADR-0001
- **Each data file must be `{"kind": ..., "records": [...]}`. `kind` must be one of `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`, `options`. `input` and `options` must hold exactly one record.** source: ADR-0001
- **The export presets must list the data files with an explicit `data/catalogue/*.json` include pattern.** source: ADR-0001
- **Data must be validated as plain `Dictionary` and `Array` values by `CatalogueValidator` against the `CatalogueSchema` table before any record is built. The manifest tier must run first and stop everything after it. The record tier must then collect every error.** source: ADR-0001
- **A failed value must be an error, never a repair. Code must never fill in a default.** source: ADR-0001
- **After validation passes, `CatalogueBuilder` must build typed records. Each record must be a `RefCounted` subclass with typed members set once in `_init` and no setters.** source: ADR-0001
- **A record method that returns a collection must return `.duplicate()` of it. This includes packed arrays. The stored collection must never leave the record.** source: ADR-0001
- **`Catalogue` must hold its records in private dictionaries and must have no method that returns them.** source: ADR-0001
- **`CatalogueLoader.load_manifest` must be the only code that opens a file. It must parse with `JSON.new()` then `parse()`. On any error it must call `on_failure` once with the whole `Array[CatalogueError]` and return `null`.** source: ADR-0001
- **Tests and the harness must build a catalogue with `Catalogue.from_data(data, source_label, on_failure)`, with no file I/O.** source: ADR-0001
- **The app root must hold the `Catalogue` across Retry. The battle builder must build one `StatAccessor` per battle with that battle's fatal handler and hand the `Catalogue` and the accessor to consumers.** source: ADR-0001
- **Stats must be read through `StatAccessor.get_float(ctx, key)` and `get_int(ctx, key)`. A bad call must call `on_failure` every time and return a typed zero. The check must be an `if`.** source: ADR-0001
- **Callers must read stats at use time and must not cache them. The one exception is `max_hp`, read once at spawn.** source: ADR-0001
- **Stage geometry (`path_points`, `slot_positions`, `hero_start`, `pin_rect`, `pin_exclusion`) must live in `stages.json`, in 540 by 960 field units, not in a scene.** source: ADR-0001
- **`pin_exclusion` must stay authored data per hand. The content test must check that each left-hand burst shape equals the mirror of its right-hand shape.** source: ADR-0001, ADR-0006
- **A new field must be added to the schema table and the validator in the same change.** source: ADR-0001
- **`Catalogue.snapshot()` must be used by tests only.** source: ADR-0001
- **Code must use typed arrays and typed variables. Public classes and methods must carry doc comments.** source: ADR-0001
- **Catalogue code must live in `res://src/data/`. Unit tests must live in `res://tests/unit/data/`, integration tests in `res://tests/integration/data/`, and the content test in `res://tests/integration/content/`.** source: ADR-0001

Signals and wiring (ADR-0002)
- **Every signal must be declared with typed parameters and listed in the ADR-0002 canonical table before a story uses it.** source: ADR-0002
- **A signal argument must be a value (`int`, `float`, `bool`, `StringName`, `Vector2`, `Rect2`) or a read-only record. Positions must be copies, never a reference into the simulation. `DamageEvent` is the one record argument.** source: ADR-0002
- **New signals must be past tense. Only `phase`, `pressed`, `tap`, `ground_tap`, `idle` and `waves_complete` may keep a non-past-tense name.** source: ADR-0002
- **A sim emitter inside a tick must check `halted()` and emit nothing once it is true. Only two cases may emit after it: StageFlow emits `phase(Won)`, `phase(Lost)` or `phase(Fatal)` once after the latch, and the resolver emits `drag_cancelled` and `idle()` from the end-of-frame `cancel()`.** source: ADR-0002
- **Gameplay signal emits must be synchronous.** source: ADR-0002
- **Each battle system must declare `const VIEW_SIGNALS: Array[StringName]`. An empty list must be written `[]`.** source: ADR-0002
- **StageFlow must declare `phase`, `lives_changed` and `wave_called_early`. `Battle` must declare no signals.** source: ADR-0002
- **`halted()` must reach systems through the shared `HaltLatch`. The builder (not `Battle`) must create the latch and hand it to each system and to `Battle`. On Retry, `wrapper.shutdown()` must call `battle.dispose()`.** source: ADR-0002, ADR-0008
- **Only two places may connect signals. `BattleBuilder.build` connects sim to sim. `BattleWrapper` connects sim to view and the wrapper-only signals of TowerInput and HeroInput. `InputAssembly.build` is the wrapper's own wiring: only `BattleWrapper.attach()` and tests may call it.** source: ADR-0002, ADR-0008
- **Connections must be written `emitter.signal_name.connect(listener.method)` with a bound method. The builder and the wrapper must hold every emitter and listener in a statically typed variable.** source: ADR-0002
- **A lambda may be connected only if it captures nothing it then writes.** source: ADR-0002
- **No result may depend on which listener of one signal runs first. A sim signal must have at most one sim listener.** source: ADR-0002
- **A read that returns an `Array` or `Dictionary` must return a copy the caller cannot use to write into the simulation. Records returned by reads must be read-only `RefCounted` records, not Dictionaries.** source: ADR-0002
- **A listener must not keep a `DamageEvent`, its `target`, or any `EnemyInstance` after the call returns.** source: ADR-0002
- **The wiring test must derive its covered set from `battle.systems()` and `get_script_signal_list()`. One test per signal must emit it from a fixture and assert the argument types.** source: ADR-0002
- **The `lifecycle_changed` forward to AppRoot must be the callable `AppServices.on_lifecycle(state)`, not a signal connection. `resized` does not pause.** source: ADR-0002, ADR-0008

Stretch, field space and safe area (ADR-0006)
- **`project.godot` must carry these `[display]` keys: `window/size/viewport_width=540`, `window/size/viewport_height=960`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, `window/handheld/orientation=1`. The game is portrait only. No code may change stretch settings at runtime.** [assumed: see device-assumptions.md D1/D8] source: ADR-0006
- **`project.godot` must set `input_devices/pointing/emulate_mouse_from_touch=false` and `emulate_touch_from_mouse=false`. Debug builds must read both values back from `ProjectSettings` at boot and log an error if either is not `false`.** [assumed: see device-assumptions.md D12/I5] source: ADR-0006, ADR-0007
- **Gameplay must have one coordinate space: field units, origin at the field's top-left, x right, y down, field rect `Rect2(0, 0, 540, 960)`. Path points, slots, the hero, enemies, hit discs, `pin_rect`, `pin_exclusion`, aim points and the HUD layout table must be in it.** source: ADR-0006
- **`FieldSpace` must be a pure Foundation `RefCounted` at `res://src/input/field_space.gd`, with constants `FIELD_SIZE` and `FIELD_RECT` and members `origin`, `event_to_canvas`, `visible_rect`. Its API is `make`, `to_field`, `to_canvas`, `contains` (edges included), `margin_rects` and `mirror_x`.** source: ADR-0006
- **The wrapper must build one `FieldSpace` at battle build and a new one after each resize. A `FieldSpace` never changes after construction.** source: ADR-0006
- **540 by 960 must be a constant, not a catalogue field.** source: ADR-0006
- **Placement must centre the field horizontally and bottom-anchor it vertically in the visible rect: `origin.x = visible.position.x + (visible.size.x - 540) / 2`, `origin.y = visible.end.y - 960`.** [assumed: see device-assumptions.md D3] source: ADR-0006
- **`FieldSpace.make` alone must compute `event_xform` from the viewport's stretch transform.** [assumed: see device-assumptions.md D2] source: ADR-0006
- **Every screen position must enter gameplay through `FieldSpace.to_field`. No other code may read an event position, a camera, or the viewport size for gameplay.** source: ADR-0006
- **Simulation code must not hold a `FieldSpace` instance. It may read `FieldSpace.FIELD_RECT` and `FIELD_SIZE`. `targets()` must test `FieldSpace.FIELD_RECT.has_point(position)` with the constant.** source: ADR-0006
- **Headless code must not build a `FieldSpace` instance. Tests must build one from a fixture rect.** source: ADR-0006
- **`SafeAreaSource` (injected; desktop and tests return the full rect) must supply `safe_rect_canvas() -> Rect2`. `FieldInsets.from(space, safe)` must be pure: `top = max(0, safe.position.y - space.origin.y)`, `bottom = max(0, (space.origin.y + 960) - safe.end.y)`, plus `left` and `right`.** [assumed: see device-assumptions.md D4] source: ADR-0006
- **Insets must be recomputed only with a new `FieldSpace`, so layout never shifts mid-gesture. If no usable platform safe-area call exists, `SafeAreaSource` must return authored per-platform insets from the Options record.** [assumed: see device-assumptions.md D4/D5] source: ADR-0006
- **Below 360 dp the wrapper must log a development error once at build and must not refuse to run.** [assumed: see device-assumptions.md D10] source: ADR-0006
- **Code must not depend on a renderer-only feature. The renderer stays Mobile (`renderer/rendering_method="mobile"`); a switch to Compatibility is a project setting, recorded by amending ADR-0006 section 9.** [assumed: see device-assumptions.md D9] source: ADR-0006

Input adapter and gate (ADR-0007)
- **`InputAdapter` (`res://src/input/input_adapter.gd`, `extends Node`, not a Control) must be the only code that reads an `InputEvent`. Its `_input(event)` must call `_decode(event)`, which turns each event into at most one primitive call on the gate. Touch and mouse class and field names must appear only in `_decode`.** [assumed: see device-assumptions.md I2/I3/I7] source: ADR-0007
- **`PointerGate` (`res://src/input/pointer_gate.gd`, `extends RefCounted`) must hold every input rule. It must take primitives (index, position, pressed, canceled), never an `InputEvent`.** source: ADR-0007
- **The adapter must never call `set_input_as_handled()`, and no other node may call it from `_input`.** source: ADR-0007
- **The adapter must read events only in `_input`, and identify them by class.** [assumed: see device-assumptions.md I1] source: ADR-0007
- **The adapter must have `process_mode = PROCESS_MODE_ALWAYS`.** [assumed: see device-assumptions.md I8] source: ADR-0007
- **`BattleWrapper.attach()` must call `InputAssembly.build` (resolver, HeroInput, TowerInput), then `PointerGate.create(...)`, then `InputAdapter` with `setup(gate)`, then the views and HUD.** source: ADR-0008, ADR-0007
- **The gate must not forward a press when: its field point is outside `FieldSpace.FIELD_RECT`; its canvas x lies within `edge_reject_margin` of the left or right edge of `visible_rect`; or its field point lies inside an inset strip (`y < insets.top`, `y > 960 - insets.bottom`, `x < insets.left`, `x > 540 - insets.right`). `edge_reject_margin` comes from the Input record, injected as a float.** source: ADR-0007, ADR-0006
- **Moves and releases of an open press must be converted but never clamped or rejected. Moves and releases with no open press must be dropped.** source: ADR-0007
- **Every forwarded press must get exactly one closer. A release of an open index with the cancel flag false is `release(i, p)`. With the cancel flag true it is `cancel_pointer(i)`. A press of an index already open must be preceded by `cancel_pointer(i)`. Mouse motion with the mouse press open but the left button not held is `cancel_pointer(MOUSE_INDEX)`. The cancel flag must be checked before a `pressed = false` event is treated as a release.** [assumed: see device-assumptions.md I3/I7] source: ADR-0007
- **`cancel()` must come only from the wrapper (Paused, outcome, Fatal, resize, focus loss). The adapter and gate must never call `cancel()`.** source: ADR-0007
- **The wrapper must call `gate.forget_open_presses()` right after every `resolver.cancel()` it runs. It clears `open` and resets `family` to `NONE`.** source: ADR-0007
- **The gate must forward touch indexes unchanged and the mouse as `MOUSE_INDEX = 1024`. It must not choose the active pointer: the resolver does.** [assumed: see device-assumptions.md I4] source: ADR-0007
- **The gate keeps a `family` of `NONE`, `TOUCH` or `MOUSE`. A press sets it when `open` is empty. While any press is open, the gate must drop every event of the other family, presses included. `family` returns to `NONE` when `open` empties.** source: ADR-0007
- **`_decode` must map `InputEventMouseButton` with `button_index == MOUSE_BUTTON_LEFT` to a press or release at `MOUSE_INDEX`, and drop other buttons. It must map `InputEventMouseMotion` to a move at `MOUSE_INDEX`, with `left_held` from its button mask. A mouse-class event must also be dropped unless `event.device == InputEvent.DEVICE_ID_MOUSE`.** [assumed: see device-assumptions.md I5/I7] source: ADR-0007
- **While blocked, the gate must forward nothing: no new press, and no move, release or `cancel_pointer`. It must never call `cancel_pointer` or `cancel()`. `set_input_blocked(true)` is legal only in a frame in which a resolver `cancel()` has been requested. `set_input_blocked(false)` re-opens forwarding.** source: ADR-0007, ADR-0006
- **The wrapper must run a debug check at step 1g that reports a block with open presses and no `cancel()` request.** source: ADR-0007
- **If a full-screen STOP Control gets no touch press, ADR-0006's fallback applies: while blocked, the gate passes raw press and release points, in field units, to an injected `modal_sink: Callable` instead of dropping them.** [assumed: see device-assumptions.md D6/I6] source: ADR-0006, ADR-0007
- **Slop must stay in field units with no scale cap at MVP.** source: ADR-0007
- **In development builds the wrapper must inject `log_sink: Callable`. Release builds must pass an empty `Callable`. The gate must log only when `log_sink.is_valid()`, with a plain `PointerLogEntry` record (kind, family, index, field position, `RealClock.now_ms()`, and at press the current insets).** source: ADR-0007
- **The adapter and the gate must emit no signals, build no commands, read no engine time (only the injected `RealClock`), hold no lifecycle state, and make no registry calls. The adapter must have no `_process`, no timers and no `await`.** source: ADR-0007

App start-up (ADR-0008)
- **`app_root.tscn` must be the main scene (`application/run/main_scene`). Its root must be one plain `Node` with `app_root.gd` and `process_mode = PROCESS_MODE_ALWAYS`. The scene file must hold two exported values: `launch_stage_id` and `manifest_path`. There must be no autoload.** [assumed: see device-assumptions.md L10] source: ADR-0008
- **AppRoot must hold exactly: `_catalogue`, `_launch_id` (set once in `_ready`), `_attempt_seq`, `_call_prompt_done`, `_relay`, `_wrapper`, `_retry_requested`, `_quit_requested`. AppRoot must hold no gameplay reference and must never read a gameplay value.** source: ADR-0008
- **`AppRoot._ready` must run in this order: (1) build the `FatalScreen`; (2) create the `FatalRelay` and the `RealClock`, set `_launch_id = int(Time.get_unix_time_from_system())` and assign `_quit = get_tree().quit` (not as a member initialiser); (3) `CatalogueLoader.load_manifest(manifest_path, _relay.report_boot)`, where `null` is the boot Fatal; (4) otherwise `_start_attempt()`.** [assumed: see device-assumptions.md L10] source: ADR-0008
- **The `FatalScreen` must be built in code, on a `CanvasLayer` (layer 30, `PROCESS_MODE_ALWAYS`) holding one `ColorRect` and one `Label` made with `.new()`, anchored full-rect in code. It must set a dark `ColorRect` colour, a light `Label` colour and the text size with `add_theme_font_size_override`, in code. It must use the engine default theme and font. Its text must be a fixed generic message, the launch ID and a cause code from the closed set `BOOT`, `BUILD`, `SCENE`, `READ`.** [assumed: see device-assumptions.md L8] source: ADR-0008
- **The `FatalScreen` must live in AppRoot, never in the HUD or the wrapper tree. Its `ColorRect` must have `mouse_filter = STOP`.** source: ADR-0008, ADR-0006
- **`FatalRelay.report(cause: String)` must be the one `fatal_handler`. It must keep the first cause, ignore later calls and have no dependency on the battle.** source: ADR-0008
- **The Fatal screen is absorbing. After `_enter_fatal` the Retry latch must be ignored, the screen must have no button, and `_enter_fatal` must be idempotent.** source: ADR-0008
- **Directories: `res://src/app/` (`app_root`, `app_services`, `fatal_relay`, `fatal_screen`, `real_clock`), `res://src/sim/`, `res://src/input/` and `res://src/wrapper/`. `src/sim/` must hold no `Node`. A new sim folder must go under `src/sim/`. Only `src/app/` and `src/wrapper/` may touch engine time, notifications and the tree.** source: ADR-0008

### Forbidden Approaches

Signals and wiring (ADR-0002)
- **Never add an event-bus or global signal-hub autoload.** Hidden global; breaks headless fixtures and the derived wiring test. registry: `event_bus_autoload`. source: ADR-0002
- **Never let a system connect itself to peers in `_init`.** The dependency graph spreads over many files and the builder can no longer show the whole wiring. source: ADR-0002
- **Never connect a signal by string, such as `connect("name", ...)`.** Deprecated since 4.0; the parser cannot catch a misspelt name. registry: `string_signal_connect`. source: ADR-0002
- **Never depend on the order in which two listeners of one signal run.** Listener order is unverified (S1). registry: `listener_order_dependence`. source: ADR-0002
- **Never use `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT` or `await` on a signal in gameplay code.** Gameplay signals are synchronous. registry: `deferred_or_awaited_gameplay_signals`. source: ADR-0002
- **Never let a battle system hold a reference to `Battle`.** It makes a reference cycle. registry: `system_holds_battle`. source: ADR-0002
- **Never keep a hand-written allowlist of unheard signals in the wiring test.** It goes stale as signals are added. source: ADR-0002
- **Never rename the six existing signals to past tense.** Eight GDDs cite them and a rename changes no behaviour. source: ADR-0002
- **Never connect a lambda that writes an outer local.** Lambdas capture by value, so the write does nothing. source: ADR-0002
- **Never return a stored Dictionary or Array from a read.** source: ADR-0002

Catalogue (ADR-0001)
- **Never use `assert` to check catalogue data or an accessor call.** The pinned reference does not say a release export keeps `assert`. registry: `assert_for_runtime_checks`. source: ADR-0001
- **Never reach the catalogue or the stat accessor through an autoload or a global.** The builder injects both. registry: `catalogue_global_access`. source: ADR-0001
- **Never assign to a record member, never mutate a collection a record returns, and never use a Dictionary as a record.** Records are read-only after load. registry: `mutable_catalogue_records`. source: ADR-0001
- **Never scan a directory for data files.** Exported builds rename and package files, so only the manifest lists them. registry: `data_directory_scan`. source: ADR-0001
- **Never read a JSON file outside `CatalogueLoader`.** source: ADR-0001
- **Never store the catalogue as typed `.tres` Resource files.** The rule for a missing field is not sourceable on 4.7.2, so TR-data-004 cannot be carried. source: ADR-0001
- **Never store the catalogue as GDScript constants.** It puts gameplay numbers in code. source: ADR-0001
- **Never use `JSON.parse_string` for catalogue files.** An error then carries no line or message. source: ADR-0001
- **Never use the typed zero from a bad accessor call, and never branch on a zero read.** source: ADR-0001

Stretch and field space (ADR-0006)
- **Never read an event position or the viewport size for gameplay outside `FieldSpace`.** One coordinate space per gesture. registry: `raw_screen_position`. source: ADR-0006
- **Never use `canvas_items` with `keep` (letterbox).** Bars fall outside the viewport, so a press in a bar gives a position outside the field. source: ADR-0006
- **Never use the `viewport` stretch mode.** It blurs 14 dp text and the thinner 4.7 lines. source: ADR-0006
- **Never place the field with a `Camera2D`.** Field units would then differ from viewport units. source: ADR-0006
- **Never centre the field vertically on tall phones.** It lifts the burst button off the thumb's edge. source: ADR-0006

Input adapter and gate (ADR-0007)
- **Never tell mouse from touch by `device == 0`. Use the event class, and `InputEvent.DEVICE_ID_MOUSE` for mouse-class events.** Changed in 4.7 (`deprecated-apis.md`). registry: `device_zero_check`. source: ADR-0007
- **Never call `set_input_as_handled()` in `_input`.** It would hide events from the adapter. registry: `input_handled_in_input`. source: ADR-0007
- **Never read input in `_unhandled_input`.** Any STOP Control under a drag can swallow its release, which breaks the contract. [assumed: see device-assumptions.md D6/I1] source: ADR-0007
- **Never split input into `_unhandled_input` presses and `_input` moves and releases.** Two entry points must agree on one open set. source: ADR-0007
- **Never make the gate track only the first touch index, never map the mouse to index 0, and never cap `field_scale` for slop.** Each breaks an Input GDD rule (palm replacement, no collision with finger 0, no display density in the resolver). source: ADR-0007
- **Never use a full-screen catcher Control with `_gui_input` for gameplay input.** It rests on unverified touch routing and adds a third input-stopping Control. [assumed: see device-assumptions.md I6] source: ADR-0007
- **Never keep mouse-from-touch emulation on and filter by device in the adapter.** Every modal screen would repeat the filter. It is the named fallback only if I6 fails. [assumed: see device-assumptions.md I5/I6] source: ADR-0007

App start-up (ADR-0008)
- **Never let the fatal screen load a file (no scene, font, texture, string table or catalogue data).** It must show when data or scenes are broken. registry: `fatal_screen_loads_files`. source: ADR-0008
- **Never replace the scene for Retry with `change_scene_to_packed`.** The engine frees the old scene at an unsourced time, and AppRoot would be freed with the catalogue and counters. source: ADR-0008

### Performance Guardrails
- **Catalogue load and validation**: boot only, never during a battle. Proposed device budget 1000 ms, measured on the first phone build. Data files far below 1 MB. source: ADR-0001
- **Catalogue memory**: records only. The parsed plain data must be dropped after the build. source: ADR-0001
- **Accessor read**: one dictionary lookup plus one `Object.get` through a `Variant`. Cost is unmeasured (V4). source: ADR-0001
- **Signal emit**: a direct call per listener, about one listener per sim signal, tens of emits per tick at MVP. source: ADR-0002
- **Read records (`slot_state`, `chip_state`)**: allocate a small object each frame. Acceptable at MVP. If profiling on the phone shows a cost, the fallback is that the owner caches one record per slot and updates it in place; that needs a revision of ADR-0005 section 4 first. source: ADR-0002
- **Input**: one `to_field` per input event, one `_input` call and one gate call per event, at most a few resolver calls per event. Negligible against the 2 ms tick. Gesture logging runs only in development builds. source: ADR-0006, ADR-0007

### Engine API Constraints
- **Verify on the phone or in the first story:** a JSON file under `res://data/catalogue/` is in an Android and an iOS export with the include filter (V1); a parsed JSON number arrives as `float` (V2); `FileAccess.get_open_error()`, `JSON.get_error_line()` and `get_error_message()` report what the manifest tier needs (V3). source: ADR-0001
- **Typed `Dictionary[K, V]` (4.4) is unverified from the pinned reference.** source: ADR-0002
- **Verify in the first wiring-test story:** listeners run in connection order (S1); `get_script_signal_list()` lists script-declared signals and `get_signal_connection_list(name)` reports connections on a `RefCounted` (S2); typed signal parameters are not checked at `emit` time (S3). source: ADR-0002
- **Stretch and field space (ADR-0006), unverified:** event `position` units under `canvas_items` (D2); where `expand` puts the extra area, read from `get_viewport().get_visible_rect()` (D3); `DisplayServer.get_display_safe_area()` units and Android edge-to-edge (D4); `Viewport.size_changed` as the resize hook (D5); the display key names and portrait value 1 (D8); width in dp (D10); `CanvasLayer.layer` and `offset` (D11); emulation key names and effect (D12). [assumed: see device-assumptions.md D1/D2/D3/D4/D5/D8/D10/D11/D12] source: ADR-0006
- **Input (ADR-0007), unverified:** `_input` runs before the GUI (I1); touch class and field names (I2); the cancel flag `is_canceled()` / `canceled` (I3); touch index range and reuse (I4); emulation defaults and emulated device id (I5); Controls get touch with mouse-from-touch off (I6, low confidence); desktop release outside the window, `button_mask` names (I7); `PROCESS_MODE_ALWAYS` keeps `_input` running (I8); Android back gesture sends cancel or nothing (I9, low confidence); focus loss with a finger down (I10); event space matches D2 (I11). [assumed: see device-assumptions.md I1/I2/I3/I4/I5/I6/I7/I8/I9/I10/I11] source: ADR-0007
- **App start-up (ADR-0008):** `application/run/main_scene` is the right setting name and `Time.get_unix_time_from_system()` returns a float (L10); a `Label` made in code with the default theme and font draws on export with no resource load (L8). [assumed: see device-assumptions.md L8/L10] source: ADR-0008

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

### Required Patterns

Frame order, commands and ticks (ADR-0003)
- **Only AppRoot must drive simulation time. Its `_process` must call `wrapper.step(delta)`, then run its own end-of-frame latches.** source: ADR-0003
- **The frame order in `step` must stay fixed: (a) chip feed and `hud.advance(min(delta_ms, 100))` beside `advance_chip` and before any tick (the HUD ignores it while Paused), (b) lifecycle then `battle.apply_queued()`, (c) ticks, (d) outcome step, (e) hero disc, (f) views, (f2) late outcome, (g) `resolver.cancel()` if requested, then `gate.forget_open_presses()`, then the `FieldSpace` swap if resized. Then AppRoot runs, in order, the Fatal latch, the quit check, and the Retry latch.** source: ADR-0003, ADR-0006, ADR-0007, ADR-0008
- **`Battle.DT` must be the constant `1.0 / 60.0`.** source: ADR-0003
- **With the clock running, the wrapper must add `delta` to the accumulator and compute `owed = floori(accumulator / DT)`. If `owed <= 5` it must run `owed` ticks and subtract `owed * DT` from the accumulator. If `owed > 5` it must run 5 ticks and set the accumulator to 0.0. With the clock stopped it must run no tick and set the accumulator to 0.0.** source: ADR-0003
- **`battle.tick` must be called only with `Battle.DT`. Headless callers must call `battle.tick(Battle.DT)` in a loop.** source: ADR-0003
- **`tick` must call `apply_queued()` first. If the clock is stopped it must return after the drain without counting. Otherwise it must run the slot order (StageFlow, WaveSim advance, Status, TowerSim, HeroSim then burst, WaveSim reap), check `halted()` before the first slot and between slots, then increment `tick_count`.** source: ADR-0003, ADR-0008
- **The wrapper must call `apply_queued()` every frame, clock running or not, before any tick.** source: ADR-0003
- **Commands must be `BattleCommand` subclasses (`BuildCommand`, `UpgradeCommand`, `PinCommand`, `BurstCommand`, `StartNextWaveCommand`, `ResumeCommand`). `BattleCommand` must be `@abstract`.** source: ADR-0003, ADR-0008
- **`Battle.enqueue(command)` must only append, never apply, and must be legal from any handler.** source: ADR-0003
- **`apply_queued` must take the queue as it stands, empty it, apply each command in arrival order, and append `to_record(tick_count, result)` to the log for every drained command, refused and `HALTED` ones included.** source: ADR-0003
- **If `halted()` is true, `apply_queued` must apply nothing. Each command's `on_result` must get `HALTED`, each must be logged with `HALTED`, and the queue must empty.** source: ADR-0003
- **`on_result` must be called synchronously inside `apply_queued`, only if `on_result.is_valid()`, and then cleared to an empty `Callable()`. A command enqueued during `on_result` must wait for the next drain.** source: ADR-0003
- **The command log must hold only plain `CommandRecord` values.** source: ADR-0003
- **Bots and the harness must build the same command records and call `enqueue` then `tick`.** source: ADR-0003
- **Real time for the chip must come from one injected `RealClock` (`now_ms() -> int`).** source: ADR-0003
- **TowerInput must feed the chip when the release handler runs, before it judges the tap, and again in step 1a each frame.** source: ADR-0003
- **On a focus loss the chip must close.** source: ADR-0003
- **HeroInput must call `set_centre(hero_target_id, battle.hero().position())` in step 1e while the hero walks.** source: ADR-0003
- **The outcome step must run once per latch: stop the clock, emit `phase(Won|Lost|Fatal)` once, request `cancel()`. A Fatal latched in step 1f must run it in step 1f2 in the same frame.** source: ADR-0003
- **Debug builds (`OS.is_debug_build()`) must log a clamp drop with `push_warning`, at most once per second.** source: ADR-0003
- **`Engine.time_scale` must stay 1.0.** source: ADR-0003

Test harness and snapshot (ADR-0004)
- **Harness code must live under `res://tests/support/`, with file names that have no `_test` suffix.** source: ADR-0004
- **Tests must drive a battle only through `BattleRig` or its three entry points: `BattleBuilder.build`, `Battle.enqueue`, `Battle.tick(Battle.DT)`.** source: ADR-0004
- **Unit tests must build catalogues with `FixtureCatalogue`. Its helpers must always copy.** source: ADR-0004
- **`Battle` must receive all its parts in one `BattleParts` record through `_init(parts)` and run an ordered list of `TickSlot` objects. Production code must construct `Battle` only in the builder.** source: ADR-0004, ADR-0008
- **A `Battle` with `flow == null` must treat the clock as running.** source: ADR-0004
- **Every battle system in `systems()` must implement `snapshot() -> Dictionary` and declare `SNAPSHOT_EXEMPT` (even `[]`).** source: ADR-0004
- **Every `snapshot()` must follow ADR-0004 section 5: first key `"system"`; values only `bool`, `int`, `float`, `String`, `Vector2`, `Array`, or `Dictionary` with `String` keys; a deep copy; sets and maps as ordered `Array`; ints stay `int`; keys are member names without a leading `_` (renames only through `SNAPSHOT_KEYS`).** source: ADR-0004
- **A holder must embed state another system owns only through that owner's formatter.** source: ADR-0004
- **Snapshots must be compared with `SnapshotTool.diff`. Floats must be compared exactly.** source: ADR-0004
- **A replay must compare the log record by record (`tick`, `kind`, `args`, `result`), then compare `SnapshotTool.take` of both battles.** source: ADR-0004
- **A run loop must have a `max_steps` limit. A TIMEOUT must fail the test and must never be read as Lost.** source: ADR-0004
- **The only randomness must be the injected `seed` in `RigOptions`. A test that needs variety must loop over a fixed list of seeds. Tests that touch the chip must pass a fake `RealClock`.** source: ADR-0004
- **Seconds must become ticks in tests only through `ticks_for`.** source: ADR-0004
- **The token scan must derive its covered set from the live scripts of `Battle`, `BattleBuilder` and `battle.systems()`. It covers every `.gd` file under `res://src/sim/`.** source: ADR-0004, ADR-0008
- **A test that creates a `Node` must wrap it in `auto_free(...)` or give it to the scene runner.** source: ADR-0004
- **CI must pass only on exit 0. Exits 100, 101, 103, 105 and 1 must fail, and `No test cases found` must fail the step. CI must run `--import` first (retried once), then the parse check on `tests/support/`, then the gdUnit4 command. `tests/unit/harness/canary_test.gd` must always exist.** source: ADR-0004
- **A baseline must hold only integers, be stored per architecture, and fail when missing.** source: ADR-0004
- **Every harness check must have a meta test that shows it failing.** source: ADR-0004
- **Bots must read only what a view reads and must build commands.** source: ADR-0004
- **The wrapper and the tests must build the input pieces through the one function `InputAssembly.build(battle, catalogue, clock) -> InputPieces`, which loads no stage scene and creates no `InputAdapter` or views.** source: ADR-0004, ADR-0008
- **`SignalTap` must attach only to signals in a system's `VIEW_SIGNALS`.** source: ADR-0004
- **Test files must be named `[system]_[feature]_test.gd` with `test_[scenario]_[expected]` methods.** source: ADR-0004

Simulation state (ADR-0005)
- **Sim data classes must be `RefCounted`, one `class_name` per file, under `res://src/sim/` (`core/`, `combat/`, `wave/`, `tower/`, `hero/`). Tests must live in `res://tests/unit/sim/` and `res://tests/integration/sim/`.** source: ADR-0005
- **Single writers must hold: Combat writes `health`, `status` and every field inside them; WaveSim writes `spawn_id`, `def_id`, `distance`, `position`, `in_play` and roster membership; TowerSim writes `TowerInstance` fields, gold and the slot table; HeroSim writes `HeroInstance` fields.** source: ADR-0005
- **WaveSim must call `combat.attach(enemy, max_hp)` once in its add step. `attach` must create Health and Status and seed Health.** source: ADR-0005
- **`Combat` must be built with `Combat.new(latch, ticks, dev_error)` and must hold no catalogue, accessor, enemy list or other system.** source: ADR-0005
- **Every damage point must go through `Combat.deliver`, one event per victim. Only `TowerSim` and `HeroSim` may call it, each inside its tick slot.** source: ADR-0005
- **`deliver` must check in this order, with `if`: latch halted (return `0.0`, emit nothing); null event or target, or target not `in_play` (`dev_error`, `0.0`); target dead (`0.0`, silent); amount negative or not finite (`dev_error`, `0.0`). Then it applies `min(amount, hp)`, counts it under `source_id` and emits `damage_applied` with a copied position.** source: ADR-0005
- **Combat helpers must scan without sorting, skip enemies that are dead or not `in_play`, and break ties on the lower `spawn_id`, compared explicitly.** source: ADR-0005
- **Attackers must re-pick the target on every attack from a `targets()` copy and keep no enemy past the slot.** source: ADR-0005
- **All seconds-to-ticks conversion must use `TickConverter`.** source: ADR-0005
- **`WaveSim.add_enemy(def_id)` must be the one add step. It must assign `spawn_id` (an `int` from 0, never reused) only there, after the `max_hp` read passed the latch check. It must return `null` without consuming the id if the latch turned halted.** source: ADR-0005
- **Leak and reap must collect the affected enemies into a local array, process them in ascending `spawn_id`, then rebuild `_roster` from the survivors. The latch must be checked right after every accessor read and every emit.** source: ADR-0005
- **`roster()` and `targets()` must return a new typed copy (`.duplicate()`) on every call. `got_through_by_type()` must return a copy.** source: ADR-0005
- **`_targets` must be rebuilt from the roster with the centre inside `field`, edges inclusive, compared with explicit `>=` and `<=`.** source: ADR-0005
- **Geometry must come from the `StageDef` the builder passes, never from a scene.** source: ADR-0005
- **Records (`SlotState`, `HeroCounters`, `CombatCounters`, `BattleResult`) must be read-only `RefCounted` records built fresh on each read, fields set in `_init`, no setters.** source: ADR-0005
- **`CombatCounters` must sum in order of `String(source_id)`. Ids must sort by `String(id)`. Every sort comparator must be strict and total with a final tie-break.** source: ADR-0005
- **Each system's `snapshot()` must follow ADR-0004, must not call the `StatAccessor`, must not mutate, and must work while halted.** source: ADR-0005
- **Checks must use `if` and `dev_error`.** source: ADR-0005
- **The ownership scan test, the HP conservation test and the no-bypass test must exist and pass.** source: ADR-0005

Battle composition (ADR-0008)
- **AppRoot (not the wrapper) must call `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler) -> Battle`. The seed is the constant `0`.** source: ADR-0008
- **The builder must run in this order: (1) `HaltLatch.new()`, passed to `Battle` and to each system; (2) `StatAccessor.new(catalogue, on_failure)`, where `on_failure` trips the latch and then calls `fatal_handler(cause)`; (3) `TickConverter`; (4) `Combat`, `WaveSim`, `TowerSim`, `HeroSim`, `StageFlow`; (5) every signal connection as an explicit typed connect; (6) one `TickSlot` per row of architecture 3.1 in tick order; (7) fill one `BattleParts` record, construct `Battle` and return it. This meets ADR-0005's order requirement.** source: ADR-0005, ADR-0008
- **`build` must always run to its last line and return a `Battle`. It must never return `null`. The caller must check `battle.halted() or _relay.is_fatal()`.** source: ADR-0008
- **`build` must not create the `GestureResolver` or any input object. `InputAssembly.build` makes them.** source: ADR-0008
- **`_start_attempt` must: add 1 to `_attempt_seq`; make `AppServices`; call `build`; on a halted battle or a latched relay call `_fatal_before_views(battle, "build")` and return; create the wrapper and call `configure(battle, services)`; call `wrapper.prepare()` and on `false` call `_fatal_before_views(battle, "scene", wrapper)`; `add_child(wrapper)`; `wrapper.attach()`; set `_wrapper`; set `get_tree().auto_accept_quit = false`.** source: ADR-0008
- **`_fatal_before_views` must be the single path for every Fatal that latches before any view exists. It must call `battle.dispose()`, free the unattached wrapper if there is one, write the Fatal record through an injected `FatalRecordWriter` callable (fields `launch_id`, `attempt_seq`, `cause`, `stage` one of `boot`, `build`, `scene`), and enter Fatal. It must read nothing else from the battle.** source: ADR-0008
- **`auto_accept_quit` must be set to `true` explicitly in `_fatal_before_views`, in `_enter_fatal` and at the start of `_retry`.** [assumed: see device-assumptions.md L4] source: ADR-0008
- **`wrapper.prepare()` must be the first wrapper call and the only runtime scene load. It must read `scene_ref` through the battle's accessor path, call `ResourceLoader.load`, check the result is a `PackedScene`, call `instantiate()`, and check that the result is not `null` and that its root is the stage script class (`is StageScene`). On any failure it must call `services.report_fatal("SCENE")` and return `false`.** [assumed: see device-assumptions.md L9] source: ADR-0008
- **After `attach()` has connected all views, the wrapper must call the single StageFlow method that emits `phase(Build)` once (named `announce_build()` in ADR-0008; ADR-0005 owns the final name; `BattleRig.make` calls the same one). `build` must never call it. It must not be called when any Fatal latched before the views connected.** source: ADR-0008
- **The wrapper must get no pointer to AppRoot. AppRoot must hand it one `AppServices` (`RefCounted`) with `catalogue`, `clock`, `launch_id`, `attempt_seq`, `request_retry`, `call_prompt_done`, `set_call_prompt_done`, `report_fatal` and `on_lifecycle`. AppRoot implements `request_retry()` and `set_call_prompt_done()` as methods. Tests must pass fake callables.** source: ADR-0008
- **AppRoot `_process` must run in this order: `_wrapper.step(delta)` if a wrapper exists; `_enter_fatal()` if the relay is fatal; if `_quit_requested`, call `_quit` and return; if `_retry_requested` and the Fatal screen is not shown, `_retry()`. Nothing in step 2 may run inside a signal handler or an input callback.** source: ADR-0003, ADR-0008
- **`InputAssembly.build` must make the resolver with the Input record, register `HeroInput` and `TowerInput` with it, connect `flow.phase` to `TowerInput` (the chip), and connect the resolver's signals to the two input objects. Neither input object may hold the `Battle` reference beyond construction. They must queue commands with `battle.enqueue` and read the sim through the typed reads.** source: ADR-0008
- **`TowerInput` signals `slot_tapped`, `tower_inspected` and `upgrade_refused` are wrapper only. `WiringCheck.wrapper` must cover them.** source: ADR-0002, ADR-0008

Lifecycle, pause and Retry (ADR-0008)
- **The `BattleWrapper` must be the only lifecycle owner. The input adapter has no lifecycle state.** source: ADR-0008
- **`LifecycleGate` (a `RefCounted` held by the wrapper) must receive raw engine events from the wrapper's `_notification` and its connection to the root window's `size_changed`, and hold them in an ordered array. The notification callback must only append. The five states are `focus_lost`, `focus_gained`, `quit_requested`, `resized`, `back`.** [assumed: see device-assumptions.md L1/L2/L5] source: ADR-0008
- **The gate must keep `_focused: bool` (true at attach). It must append `focus_lost` only on a true-to-false change and `focus_gained` only on a false-to-true change. Only the `NOTIFICATION_APPLICATION_*` focus notifications are mapped, in the single table in `lifecycle_gate.gd`; the `NOTIFICATION_WM_WINDOW_FOCUS_*` ones are not mapped.** [assumed: see device-assumptions.md L1] source: ADR-0008
- **At step 1b, before `apply_queued()`, the wrapper must first call `battle.discard_queued(&"resume")` when a held state is `focus_lost`, `back` or `quit_requested` (each `ResumeCommand` gets `on_result` DISCARDED and is logged). Then it must emit `lifecycle_changed(state)` for each held state in arrival order and clear the array. The forward to AppRoot is the one callable `services.on_lifecycle(state)`.** source: ADR-0008, ADR-0003
- **Held states must survive a frame where the app is suspended and run first on return, in order, while the clock is still stopped.** [assumed: see device-assumptions.md L7] source: ADR-0008
- **State effects: `focus_lost` enters Paused if in Build, Wave or Intermission (no effect in Paused or a terminal state) and requests `cancel()`; `focus_gained` does nothing; `back` is the same as `focus_lost` and never exits the battle; `resized` does not pause, re-lays out the HUD, requests `cancel()`; `quit_requested` makes the HUD write the provisional debug record in its handler and makes AppRoot set `_quit_requested`.** [assumed: see device-assumptions.md L3/L5] source: ADR-0008, ADR-0006
- **While a wrapper exists, AppRoot must set `auto_accept_quit = false`. With no wrapper (boot, after Fatal, during a rebuild) it must set it back to `true` and treat a back request as a quit. The quit must run at AppRoot step 2b, after `step` returned and after any Fatal in the same frame was handled.** [assumed: see device-assumptions.md L3/L4] source: ADR-0008
- **Entering Paused must store the phase left (`_resume_to`, one of Build, Wave, Intermission) in Flow and stop the clock. Leaving Paused must happen only through a queued `ResumeCommand` (no args, `to_record` kind `resume`). `focus_gained` must never resume by itself. `back` while Paused changes nothing.** source: ADR-0008
- **`StageFlow.resume() -> int` must return `OK` (Paused ended; Flow emits `phase(_resume_to)` and restarts the clock), `HALTED` (battle halted; nothing changes) or `NOT_PAUSED` (nothing changes). `ResumeCommand.apply` must return that code through the same result path as the other commands.** source: ADR-0008
- **Pause must be a Flow state. `get_tree().paused` must stay false, and the wrapper must zero the tick accumulator whenever the clock is stopped.** source: ADR-0008, ADR-0003
- **`_retry()` must run at step 2c in this order: clear `_retry_requested`; take `old = _wrapper` and set `_wrapper = null`; set `auto_accept_quit = true`; `old.shutdown()`; `remove_child(old)`; `old.free()`; `_start_attempt()`.** [assumed: see device-assumptions.md L6] source: ADR-0008
- **`wrapper.shutdown()` must run in this order: `resolver.cancel()` inline; `gate.forget_open_presses()`; `gate.set_input_blocked(true)`; disconnect the wrapper's own engine connections (window `size_changed`); `battle.dispose()` (idempotent); set `_battle`, the pieces and every held view reference to `null`.** source: ADR-0008, ADR-0002
- **If `free()` errors or leaves orphans, the fallback must be `queue_free()` after `remove_child`, `set_input_blocked(true)` and `shutdown()`.** [assumed: see device-assumptions.md L6] source: ADR-0008
- **AppRoot, `_launch_id`, `_attempt_seq`, `_call_prompt_done`, the `Catalogue`, the relay, the `RealClock` and the fatal screen must survive Retry. `_attempt_seq` must rise at the start of every `_start_attempt`. A retried battle must open in Build and emit `phase(Build)` once, after its new views connect.** source: ADR-0008
- **The tick loop must check `halted()` before the first slot and at every slot edge. Every system must check `halted()` before it emits a signal. No system checks `halted()` after each read; a typed zero lets the function finish. Exception: WaveSim `add_enemy`, leak and reap check the latch right after each accessor read and emit and stop the loop.** source: ADR-0008, ADR-0005
- **Runtime Fatal must have three sources only: the `StatAccessor`, `BattleBuilder.build`, and the wrapper's `prepare()` scene load. Catalogue load failure is a boot Fatal before any battle. `FatalRelay.report` is the one entry for all four.** source: ADR-0008
- **A Fatal latched outside a tick must take the same second step at the end of the frame (ADR-0003 steps d and f2).** source: ADR-0008

### Forbidden Approaches

Frame order, commands and ticks (ADR-0003)
- **Never call a sim command directly from an input handler, a view or a bot. Build a `BattleCommand` and call `Battle.enqueue`.** The input-versus-process order is unverified, so determinism cannot rest on it. registry: `direct_sim_command_from_input`. source: ADR-0003
- **Never pass a frame delta to `battle.tick`. Only `Battle.DT`.** A variable time step breaks determinism and the bots' baseline. registry: `real_delta_tick`. source: ADR-0003
- **Never use `_process` or read engine time in a sim object, an input piece or HUD logic.** Only AppRoot drives time; the chip reads only the injected `RealClock`. registry: `engine_time_outside_driver`. source: ADR-0003
- **Never put a command object or a `Callable` in the command log.** registry: `callbacks_in_command_log`. source: ADR-0003
- **Never rely on the order in which Godot calls `_process` on different nodes.** It is not in the pinned reference. source: ADR-0003
- **Never queue bound `Callable`s as commands (`enqueue(command: Callable)`).** The result code and the log are lost, and replay fails. source: ADR-0003
- **Never apply commands only at the start of `battle.tick`.** A build in the Build phase would never apply. source: ADR-0003
- **Never call `resolver.cancel()` inside a tick or inside `apply_queued`.** source: ADR-0003
- **Never change `Engine.time_scale` from 1.0.** It scales `delta`. source: ADR-0003
- **Release builds must never log a clamp drop.** source: ADR-0003
- **A test must never pass a real frame delta to `tick`.** source: ADR-0003

Test harness and snapshot (ADR-0004)
- **Never import from `tests/` in production code.** registry: `src_depends_on_tests` (ADR-0004). source: ADR-0004
- **Never call `snapshot()` or read the command log in gameplay code.** registry: `snapshot_in_gameplay`. source: ADR-0004
- **Never compare snapshots with `==`. Use `SnapshotTool.diff`.** registry: `snapshot_equality`. source: ADR-0004
- **Never use a float tolerance in a replay or equivalence test.** It hides a real divergence. source: ADR-0004
- **Never put an `Object`, `RefCounted`, `Node`, `Callable`, `Signal`, `WeakRef`, instance id or NaN in a snapshot.** source: ADR-0004
- **Never add a test flag to the builder or use test subclasses of `Battle`.** It adds a gameplay branch. source: ADR-0004
- **Never build the snapshot by reflection (copy every property).** Reflection is only for the completeness check. source: ADR-0004
- **Never build a single `Battle.snapshot()` that knows every system's fields.** source: ADR-0004
- **Never call `build`, `upgrade`, `pin` or `burst` on a system from a test or a bot. Enqueue a `BattleCommand`.** source: ADR-0004
- **Never use `_process`, `_physics_process`, `Time.`, `OS.get_ticks`, `create_timer`, `Timer`, `await`, `randi(`, `randf(`, `randomize(`, `shuffle(` or `pick_random(` in `Battle`, `BattleBuilder`, any battle system or any `.gd` file in their directories (the token scan fails on them). A seeded `RandomNumberGenerator` whose seed comes from the builder is allowed by review only. Test code must not use `randi`, `randf`, `randomize`, `shuffle`, a wall clock, `Time` or `OS` tick counters.** source: ADR-0004
- **Never change a fixture dictionary in place.** source: ADR-0004
- **Never tap a sim-only signal with `SignalTap`.** source: ADR-0004
- **Never store a full per-tick trace of a long run.** source: ADR-0004
- **Never drive bots through a scene-based harness.** It is slow and frame-timed. source: ADR-0004
- **Never skip or ignore exit code 101.** source: ADR-0004
- **Never create a harness object in a release build.** source: ADR-0004

Simulation state (ADR-0005)
- **Never remove from the roster while iterating it. Collect first, then rebuild.** registry: `remove_while_iterating_roster`. source: ADR-0005
- **Never declare a class member of type `EnemyInstance` or `Array[EnemyInstance]` outside WaveSim and Combat.** `DamageEvent.target` is the one exception. A view must key by `spawn_id`. registry: `enemy_reference_members`. source: ADR-0005
- **Never call the Health or Status mutators (`remove`, `seed`, `set_slow`, `count_down`) outside `src/sim/combat/`.** source: ADR-0005
- **Never write `spawn_id`, `distance`, `position`, `in_play` or a roster array outside `src/sim/wave/`.** source: ADR-0005
- **Never call `deliver` from a command or from any file except `tower_sim.gd` and `hero_sim.gd`.** source: ADR-0005
- **Never rely on `Array.make_read_only()`.** Its behaviour on 4.7.2 is not sourceable. source: ADR-0005
- **Never keep an attacker's target between attacks.** It goes stale after a reap. source: ADR-0005
- **Never let `Combat` hold StageFlow or any other system.** It would form a cycle. source: ADR-0005
- **Never declare a setter on a packed-array property in a sim class.** source: ADR-0005
- **Never store HP and slow outside the enemy components (no flat fields, no Dictionaries, no parallel packed arrays, no Combat tables keyed by `spawn_id`).** source: ADR-0005
- **Never add a spawner behind `deliver` now.** `ProjectileSpawner` is cut. A projectile system later is a new slot that calls the same `deliver`. source: ADR-0005
- **Never rely on list position or a non-strict comparator for ties.** source: ADR-0005

Lifecycle and composition (ADR-0008)
- **Never let anything but the `BattleWrapper` own lifecycle states or map OS notifications.** One owner (GF6). registry: `second_lifecycle_owner`. source: ADR-0008
- **Never use `get_tree().paused` for gameplay pause.** It would also stop AppRoot, the lifecycle gate and the modal screens, and two pause states can disagree. Pause is a StageFlow state. registry: `tree_pause_gameplay`. source: ADR-0008
- **Never pause on `resized`.** A desktop drag would pause every frame, and a phone rotation would need a tap for no visible reason. source: ADR-0008
- **Never let the wrapper call `BattleBuilder.build`.** A Fatal during `build` would leave the wrapper holding a partial battle, with two paths for a Fatal before the views. source: ADR-0008

### Performance Guardrails
- **Tick**: 2 ms per tick on the target phone (proposed). Five catch-up ticks are at most 10 ms of the 16.6 ms frame. If the phone spike fails it, the cap must drop, not the tick rate. source: ADR-0003
- **Commands**: a handful per frame, one small object each. source: ADR-0003
- **Command log**: a few hundred small records per stage, in memory in every build. File writes are deferred to the Mobile Platform ADR. source: ADR-0003
- **Roster copies**: about 2 `targets()` copies and 1 `roster()` copy per tick, at most 48 elements each (E = 48, S = 5). Estimated, unmeasured. The first WaveSim story must measure it. Above 10% of the 2 ms tick, the fallback is a sealed shared array. source: ADR-0005
- **Sim objects**: 48 enemies x 3 objects, plus 5 tower and 1 hero instance. Negligible. source: ADR-0005
- **Harness**: a full snapshot of 48 enemies is about 5 KB (estimate). A 36 000-tick per-tick full trace is about 180 MB (estimate) and is not allowed. The bot suite CI time budget is set at the first baseline. source: ADR-0004
- **Snapshots** run in tests only. source: ADR-0004
- **Retry frame**: build, scene instantiate and view build happen once. Proposed budget 200 ms on the target phone, measured by the spike. source: ADR-0008
- **Retry memory**: with immediate `free()` one battle exists at a time. With the `queue_free()` fallback two scene copies exist for one frame. source: ADR-0008

### Engine API Constraints
- **`@abstract` (4.5) is used for `BattleCommand`, `BattleBot` and `TickSlot`.** source: ADR-0003, ADR-0004
- **`Time.get_ticks_msec()` replaces `OS.get_ticks_msec()`. `RealClock` wraps it.** source: ADR-0003
- **Verify on the phone spike (GF5):** `_input` order versus `_process` (F1); `Time.get_ticks_msec()` is monotonic across a focus loss on Android and iOS (F2); `_process(delta)` after a long stall returns the real elapsed time (F3); the `BattleCommand` to `Battle` to `Array[BattleCommand]` `class_name` cycle parses with `@abstract` (F4). source: ADR-0003
- **gdUnit4 6.2.2 is post-cutoff.** Unverified from the reference (H1 to H7): gdUnit4 ignores non-suite scripts under `res://tests/` (if wrong, move support to `res://tests_support/`); suite API names other than `auto_free`; `Script.get_script_property_list()` with `PROPERTY_USAGE_SCRIPT_VARIABLE`; `weakref()` timing for `RefCounted` and `Node`; method `Callable` versus lambda and `.bind()` references; `FileAccess`, `DirAccess` and `Script.resource_path` under `--headless -s`; the call that names the CPU architecture. source: ADR-0004
- **Typed `Dictionary[K, V]` (4.4) is used for `_ctx`, `_got_through`, `_dealt`, `_kind`.** source: ADR-0005
- **4.7: writing one element of a packed array no longer calls the property setter.** No sim class may put a setter on a packed-array property. source: ADR-0005
- **Unverified (V1 to V7), checked by the first WaveSim and Combat stories:** `make_read_only()`; `RefCounted` cycles and `weakref`; `Dictionary` order and `==`; `Array.duplicate()` keeps the type; `floori` and `is_finite`; typed `Dictionary` `erase` and `duplicate()`; `Array.sort_custom` is not stable and `StringName` order may differ from text order. source: ADR-0005
- **Application lifecycle (ADR-0008), unverified; the reference holds nothing on these:** which `NOTIFICATION_APPLICATION_*` notifications fire per platform (L1); they reach a deep node (L2); `NOTIFICATION_WM_GO_BACK_REQUEST` and `application/config/quit_on_go_back` (L3); `NOTIFICATION_WM_CLOSE_REQUEST` with `auto_accept_quit` false, and no quit notification on an OS kill (L4); `Window.size_changed` triggers (L5); `Node.free()` from `AppRoot._process` (L6); `_process` in the background and the first `delta` (L7); `ResourceLoader.load` and `instantiate()` on a broken scene (L9). [assumed: see device-assumptions.md L1/L2/L3/L4/L5/L6/L7/L9] source: ADR-0008

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

No Accepted ADR governs this layer yet.

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

### Required Patterns

Reads, signals and views (ADR-0002, ADR-0003, ADR-0005)
- **Views must read through `Battle.flow()`, `combat()`, `wave()`, `tower()` and `hero()` and queue commands through `Battle.enqueue`.** source: ADR-0002
- **Views must connect signals only in `BattleWrapper`. No view may connect to anything outside the wrapper.** source: ADR-0002
- **Each view listener of a multi-listener signal (`phase`, `pressed`, `lifecycle_changed`) must be correct whichever listener runs first.** source: ADR-0002
- **A view must listen only to signals in a system's `VIEW_SIGNALS`, or to the wrapper-only signals of the resolver, TowerInput, HeroInput and the wrapper.** source: ADR-0002
- **The HUD must compare time in whole ticks.** source: ADR-0002
- **Views must redraw from reads in step 1f of `step`.** source: ADR-0003
- **A view may animate in its own `_process`, reading only.** source: ADR-0003
- **Input handlers must only enqueue commands, feed the chip, or set latches. Retry's input handler must only set the latch.** source: ADR-0003
- **Refusals (`NO_GOLD`, a refused pin) must reach the HUD and input pieces through `on_result`.** source: ADR-0003
- **A view that must remember an enemy must keep its `spawn_id` (an `int`) and look it up in `roster()` each frame.** source: ADR-0005
- **View listeners must treat positions from signals as copies and must not keep a `DamageEvent`.** source: ADR-0002, ADR-0005

Layers and the wrapper's tree (ADR-0006)
- **The wrapper must build this tree: `BattleWrapper` (Node) holding `InputAdapter`; `World` (Node2D, `position = FieldSpace.origin`, canvas layer 0) with the stage scene, tower views, hero view, `EnemyLayer` and `CombatView`; `HudLayer` (CanvasLayer, layer 10, `offset = FieldSpace.origin`) with `Curtains`, `HudField` and `HudTopBand`; `ModalLayer` (CanvasLayer, layer 20, offset 0) with `PausedScreen` and `ResultScreen`. The AppRoot FatalScreen is on CanvasLayer 30.** [assumed: see device-assumptions.md D11] source: ADR-0006
- **`Curtains` must belong to the wrapper, not to the Battle HUD. They must draw `margin_rects()` opaque in the panel colour with `draw_rect` and use no clip API, so an enemy outside the field stays unseen on any aspect.** source: ADR-0006
- **`HudField` must be a `Node2D` with one `_draw` (arc, chip, Start/Call, burst art, rings). `HudTopBand` must be a Control tree with `mouse_filter = IGNORE` throughout.** [assumed: see device-assumptions.md D7] source: ADR-0006
- **Every HUD Control other than `PausedScreen` and `ResultScreen` must have `mouse_filter = IGNORE`. The two modal screens are the only Controls that may stop input.** [assumed: see device-assumptions.md D6/D7] source: ADR-0006
- **`PausedScreen` and `ResultScreen` must be full-visible-rect Controls with `mouse_filter = STOP` on layer 20, plain Controls with HudLogic models, not `Button`s. Each must handle `_gui_input`, accept `InputEventScreenTouch` and `InputEventMouseButton` by class, never by device, and fire only on a release whose press it saw while Armed. It must clear that press on any `lifecycle_changed(state)`.** [assumed: see device-assumptions.md D6] source: ADR-0006
- **A modal screen must remember the event family of the press it saw and accept only a release of that family. It must ignore the other family until that press ends.** Unconditional; [assumed: see device-assumptions.md D12/I6] source: ADR-0006, ADR-0007
- **All hit discs must be registered in field units by their owners at these priorities: Start/Call TAP 350 radius 48; arc discs TAP 300; arc backdrop TAP 250 sink; chip TAP 300 radius 40 (TowerInput); burst sink TAP 400 and burst DRAG 100 (HeroInput). Every thumb target's radius must be at least 36.** source: ADR-0006
- **At step 1g, after `resolver.cancel()` and `forget_open_presses()`, the wrapper must build a new `FieldSpace` from the viewport, move `World` and `HudLayer`, and recompute the insets, only if resized.** [assumed: see device-assumptions.md D5] source: ADR-0006, ADR-0007

Modal screens and Paused (ADR-0006, ADR-0007)
- **The HUD must call `set_input_blocked(true)` on every modal mount and `set_input_blocked(false)` on unmount, through the `Callable` the wrapper injects (`gate.set_input_blocked`), only from `phase` handlers. Modals must mount only from `phase` handlers for Paused, Won and Lost.** source: ADR-0006, ADR-0007
- **A resume tap on `PausedScreen` must queue a `ResumeCommand` through `Battle.enqueue`. The HUD must unmount `PausedScreen` and unblock the adapter in the handler of the `phase` that StageFlow emits.** source: ADR-0006, ADR-0008
- **`ResultScreen`'s Retry and Play again must call `AppServices.request_retry()`, which only sets a latch.** source: ADR-0006, ADR-0008
- **The HUD must set `call_prompt_done` from the `StartNextWaveCommand`'s `on_result` when the prompt has shown.** source: ADR-0006
- **The HUD must not treat the `phase` returned by `ResumeCommand` as a new appearance (HUD Rule 11).** source: ADR-0008

Enemy and effect views (ADR-0006)
- **`EnemyLayer` must be one canvas item that draws every enemy in one `_draw` from `wave().roster()` read in step 1f. Per-enemy presentation state (fade, notch angle) must live in a record pool pre-sized to 48, keyed by `spawn_id` and reused. If the roster exceeds the pool, the pool must grow and log a development error. The pool must be rebuilt with the views on Retry.** source: ADR-0006
- **`CombatView` must draw tracers and flashes in one `_draw` from a ring buffer of 64 effect records filled by `attack_fired` and `damage_applied`. When full, the oldest must be overwritten and debug builds must warn once per second. Tracers must be drawn at least 2 field units wide.** source: ADR-0006
- **Views may animate in their own `_process` and use `Tween` for art only (alpha, fades, icon loops, the 120 ms collapse), reading only. A view `_process` must change only its own art state.** source: ADR-0006

Left-hand mirroring (ADR-0006)
- **Only the burst button, its digit and the burst's `pin_exclusion` shapes are handed. Start/Call, the arc order and everything in the field stay put.** source: ADR-0006
- **The hand must be the Options record's `left_hand`, read once at build and fixed for the battle. Changing it needs a rebuild.** source: ADR-0006
- **One pure function `HudLayout.burst_centre(left_hand: bool, insets: FieldInsets) -> Vector2` must place the button for both its art and its disc: x 456 or `FieldSpace.mirror_x(456)` = 84, `y = clamp(888 - insets.bottom, 816, 888)`. HudField and HeroInput must both use it.** source: ADR-0006

Lifecycle in views (ADR-0008)
- **The HUD's `lifecycle_changed` handler must write the provisional debug record synchronously on `quit_requested`.** source: ADR-0008
- **If views were connected when Fatal latched, the HUD must have written the Fatal record from reads held at the latch (Flow Rule 18, steps d and f2). Otherwise the root writes it.** source: ADR-0008
- **Every view's `_exit_tree` must cope with references that `shutdown()` already set to `null`.** source: ADR-0008

### Forbidden Approaches
- **Never let a view write to the simulation.** Systems also never use view reads to reach each other. source: ADR-0002
- **Never connect a view to anything outside `BattleWrapper`.** source: ADR-0002
- **Never write to the simulation from a view's `_process`.** It reads only. source: ADR-0003
- **Core forbidden rules from ADR-0003 and ADR-0005 apply to views.** source: ADR-0003, ADR-0005
- **Never re-connect a new view into a freed battle on Retry.** The wrapper drops the old battle and views and wires the new ones. source: ADR-0002
- **Never tap a sim-only signal from a view.** source: ADR-0004
- **Never create or free nodes per enemy or per effect during a battle, and never use one node per enemy from a node pool.** 48 canvas items would need sorting and batching. registry: `per_enemy_nodes`. source: ADR-0006
- **Never register a field-wide TAP sink at top priority as the Paused screen.** Presses in the margins miss it, and it contradicts HUD Rule 2. source: ADR-0006
- **Never use a `Button` for a modal screen.** source: ADR-0006
- **Never let a view call `StageFlow` directly to resume. Queue `ResumeCommand`.** source: ADR-0006, ADR-0002
- **Never put a negative scale on any transform in the wrapper tree.** It would mirror text and the path. source: ADR-0006

### Performance Guardrails
- **Per frame**: one `_draw` each for enemies (at most 48 circles), effects (at most 64 records) and HudField. Negligible against the 16.6 ms frame. source: ADR-0006
- **View memory**: 48 enemy records and 64 effect records per battle, rebuilt on Retry. No per-enemy nodes. source: ADR-0006

### Engine API Constraints
- **Unverified (ADR-0006):** STOP Control gets touch in `_gui_input` before `_unhandled_input` (D6); IGNORE Controls pass touch through (D7); Mobile holds 30 fps on the lowest Android (D9); `CanvasLayer` order and offset (D11). [assumed: see device-assumptions.md D6/D7/D9/D11] source: ADR-0006

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example | Source |
|---------|-----------|---------|--------|
| Classes | PascalCase | `BattleWrapper` | `naming.classes` in project.yaml |
| Variables | snake_case | `spawn_id` | `naming.variables` in project.yaml |
| Signals/Events | past_tense | `enemy_killed` | `naming.signals` in project.yaml |
| Files | snake_case | `catalogue_loader.gd` | `naming.files` in project.yaml |
| Scenes | snake_case | `battle_hud.tscn` | `naming.scenes` in project.yaml |
| Constants | SCREAMING_SNAKE | `VIEW_SIGNALS` | `naming.constants` in project.yaml |

Signal exceptions: ADR-0002 allows six signals to stay non-past-tense: `phase`, `pressed`, `tap`, `ground_tap`, `idle` and `waves_complete`. They are the only exceptions. source: ADR-0002

### Performance Budgets
| Target | Value | Source |
|--------|-------|--------|
| Framerate | 60 fps | `performance.target_framerate` in project.yaml |
| Frame budget | 16.6 ms | `performance.frame_budget_ms` in project.yaml |
| Draw calls | 60 | `performance.draw_call_limit` in project.yaml (art bible proposal, Adreno 5xx class; verify on device) |
| Memory ceiling | 256 MB | `performance.memory_ceiling_mb` in project.yaml (textures <= 16 MB) |
| `battle_tick` | 2 ms per tick (proposed, target phone) | ADR-0003 |
| Catch-up tick cap | 5 ticks per frame, at most 10 ms of the 16.6 ms frame | ADR-0003 |
| Retry frame | 200 ms (proposed, target phone) | ADR-0008 |

### Approved Libraries / Addons
- gdUnit4 6.2.2: approved for tests, vendored in `addons/gdUnit4/`. source: ADR-0004

`technical-preferences.md` configures no other approved libraries and no forbidden patterns or libraries.

### Forbidden APIs (Godot 4.7.2)
These APIs are deprecated or renamed for Godot 4.7.2. Use the replacement.
- `TileMap`: use `TileMapLayer` (since 4.3). source: deprecated-apis.md
- `VisibilityNotifier2D`: use `VisibleOnScreenNotifier2D` (since 4.0). source: deprecated-apis.md
- `YSort`: use `Node2D.y_sort_enabled` (since 4.0). source: deprecated-apis.md
- `Navigation2D`: use `NavigationServer2D` (since 4.0). source: deprecated-apis.md
- `yield()`: use `await signal` (since 4.0). source: deprecated-apis.md
- `connect("signal", obj, "method")` and any string-based `connect()`: use `signal.connect(callable)` (since 4.0). source: deprecated-apis.md
- `instance()` and `PackedScene.instance()`: use `instantiate()` (since 4.0). source: deprecated-apis.md
- `OS.get_ticks_msec()`: use `Time.get_ticks_msec()` (since 4.0). source: deprecated-apis.md
- `duplicate()` for nested resources: use `duplicate_deep()` (since 4.5). source: deprecated-apis.md
- Untyped `Array` and `Dictionary`: use `Array[Type]` and typed variables. source: deprecated-apis.md
- `$NodePath` in `_process()`: use a cached `@onready var`. source: deprecated-apis.md
- `event.device == 0` to detect mouse or keyboard: check `event is InputEventMouse` or `InputEventKey`, or use `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (4.7). Never use `device == 0`. registry: `device_zero_check`. source: deprecated-apis.md, ADR-0007
- Installing addons from the editor's AssetLib tab: use the Asset Store workspace (4.7). source: deprecated-apis.md
- If the UI shows `RichTextLabel` images: `ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` becomes `UPDATE_WIDTH_UNIT`, and `add_image()` / `update_image()` take `width_unit` / `height_unit` (`RichTextLabel.ImageUnit`) in place of `width_in_percent` / `height_in_percent` (4.7). source: deprecated-apis.md

Left out as 3D-only (not rules for this 2D project): `GodotPhysics3D` to Jolt, `Navigation3D`, `Skeleton3D` `bone_pose_updated`, `VisibilityNotifier3D`, `get_world()`.

Left out and unresolved (not named for this project, not judged): `EditorSceneFormatImporterFBX`, `AnimationPlayer.method_call_mode` and `playback_active`, `DisplayServer.AccessibilityLiveMode`, `AudioEffectSpectrumAnalyzer.tap_back_pos`, `EditorSceneFormatImporter.IMPORT_*`, `Texture2D` in `Shader.set_default_texture_parameter()`, manual post-process viewport chains.

### Cross-Cutting Constraints
- **Typed-return overrides must end in an explicit `return` in 4.7.** The migration fix is `return null`. This applies to `apply`, `decide`, `run`, records and test doubles. source: current-best-practices.md
- **Lambdas capture locals by value.** A lambda cannot reassign an outer local. Share state through a Dictionary, an Array or an object and mutate its contents. source: current-best-practices.md
- **Writing one element of a packed array (`arr[i] = v`) no longer calls the property's setter in 4.7.** Assign the whole array where a setter must run. source: current-best-practices.md
- **`@abstract` methods must have no body, and subclasses must override them.** source: current-best-practices.md
- **Code must never use `assert` for runtime checks of data or calls.** Use `if` and the injected failure handler or `dev_error`. source: ADR-0001, ADR-0005
- **No autoloads and no event bus. The builder injects every dependency.** source: ADR-0001, ADR-0002, ADR-0008
- **Public classes and methods must carry doc comments.** source: ADR-0001
- **Determinism must hold: the simulation uses fixed `Battle.DT` ticks and an injected seed, and never real time.** source: ADR-0003, ADR-0004
