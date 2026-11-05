# Control Manifest

> **Engine**: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D; 2D portrait phone game)
> **Last Updated**: 2026-11-05
> **Manifest Version**: 2026-11-05
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011
> **Status**: Active. Regenerate with `/create-control-manifest update` when an ADR changes.

`Manifest Version` is the date this manifest was made. Stories embed it when they
are written, and `/story-readiness` compares a story's version with this one to
find stories written against old rules. It always equals `Last Updated`: the same
date, for different readers.

This is a quick rules sheet for programmers, taken from the eleven Accepted ADRs
(with every dated amendment applied over the text it amends), `project.yaml`,
`.claude/docs/technical-preferences.md` and `docs/engine-reference/godot/`
(`deprecated-apis.md`, `current-best-practices.md`, `probe-results.md`). For the
reason behind a rule, read its ADR. `Gn` is an ADR's Implementation Guideline n,
`Dn` its Decision n, `Alt n` its Alternative n. `L-*` IDs are lints from ADR-0007
Decision 6 (index at the end).

**Where the layers sit in `src/`** (ADR-0007 L-LAYER-1): Foundation
`src/foundation/` < Core `src/core/` < Feature `src/feature/` < Presentation
`src/presentation/` < composition root `src/root/`. A lower layer never names a
higher one. The composition root (AppRoot, BattleBuilder, Battle, BattleWrapper)
is engine start-up, so its rules sit under Foundation. Rules go under the layer of
the code they govern, so an ADR that spans folders shows up in more than one layer.

---

## Foundation Layer Rules

*Applies to: composition root and app lifecycle (`src/root/`), catalogue data
(`src/foundation/data/`), tick time (`src/foundation/time/`), the input resolver
(`src/foundation/input/`), signal wiring, the input adapter and display settings,
and the test harness and CI.*

### Required Patterns

**App root, Builder and Battle**
- **`project.godot` has no `[autoload]` section, and `run/main_scene` is `res://src/root/app_root.tscn`** (L-APP-1). Source: ADR-0001 D1, G1
- **`BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler) -> Battle` is a static function on a `RefCounted` class.** It touches no node and is never called from a signal handler. Name the parameter `rng_seed`, never `seed`. Source: ADR-0001 D2
- **The Builder checks the battle latch after each build step and returns `null` once it is set; AppRoot adds no wrapper after a null build.** Source: ADR-0001 G8
- **Build order inside step (d): `DevErrorSink`, then `TickMath`, then `TickGuard`, then the sims.** The wrapper owns its own `DevErrorSink` for `TickClock` and its views. Source: ADR-0004 D2
- **Every object behind an injected Callable is a member of `Battle` or `AppRoot`.** Source: ADR-0001 G5
- **Inject method Callables on Builder-owned objects only.** Inject `HaltGate.halted`, never `Battle.halted`. Inject the battle's one `stat_accessor` and `battle.combat` as objects. Source: ADR-0001 D3, G4, G6, Amendment 2026-11-04 (ADR-0005); ADR-0005 D7, G15; ADR-0009 D5
- **`Battle` exposes `flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`, `input_resolver`, `stat_accessor` and `halt_gate` as public read-only members, and keeps `_tick_math`, `_dev_error_sink`, `_wiring`, `_tick_guard` private.** Source: ADR-0001 D2, Amendments 2026-11-04; ADR-0004 Key Interfaces
- **Flow's injected targets are `EnemyWave.wave_index`, `EnemyWave.start_next_wave`, `InputResolver.cancel` (as `cancel_input()`), `TickMath`, the dev-error sink and `TickGuard.in_tick`, `enter`, `exit`.** Nothing points back at a sim that points at it. Source: ADR-0001 D3; ADR-0004 Amendment 2026-11-04; ADR-0006 D7; ADR-0010 D3
- **Every connection to a sim signal goes through a `Wiring` record**: the Builder's for gameplay, the wrapper's `view_wiring` for views. Use `connect_recorded()` with no flags; it checks the `Error` from `connect()` and reports a failure to the dev-error sink without recording the pair. `Wiring.pairs()` returns a read-only copy. Source: ADR-0001 G3, Amendment 2026-11-04 (ADR-0006); ADR-0006 D1
- **AppRoot acts on the retry and fatal latches only from its own `_process`, fatal first.** A Retry handler only calls `request_retry()`, which frees nothing. A retry latch outside WON or LOST is cleared and ignored. Source: ADR-0001 D5, G11
- **Teardown runs in this order: stop the clock, `resolver.cancel()`, wrapper `process_mode = PROCESS_MODE_DISABLED`, `view_wiring.disconnect_all()`, `remove_child()` then `queue_free()` the wrapper, `battle.unwire()`, null every reference.** Source: ADR-0001 D5, G12
- **AppRoot checks that the wrapper scene loads and instantiates; on a failure it calls `fatal("wrapper_scene_failed")` on the app latch.** Source: ADR-0001 D4, G13
- **One `FatalLatch` class, two instances (battle, forwarding; app, none).** `fatal(cause)` keeps the first cause; on the first call it forwards, else calls `push_error(cause)`, then emits `latched(cause)` once. Every fatal source takes this path. Source: ADR-0001 D6
- **`FatalScreen` is a code-built `Control` named by class, never by path.** It loads no resource and reads no catalogue data. Debug builds show the first cause and every `ValidationError`; release builds show one generic line. Source: ADR-0001 D6, G14
- **Every caller of an accessor read, an injected Callable or a signal emit inside a tick checks `halted()` after it and returns at once when true.** Source: ADR-0001 G9; ADR-0006 D2
- **Use the injected fatal handler or the dev-error sink for every check that matters.** The game's `DevErrorSink.report` calls `push_error` and never halts. Source: ADR-0001 D7, G10
- **Battle randomness, once a GDD adds it: one `RandomNumberGenerator` per consumer, made by the Builder, held by `Battle`, seeded `splitmix64(rng_seed * 1_000_003 + SALT)`.** Cosmetic randomness uses a wrapper-owned generator never seeded from `rng_seed`. At MVP no sim draws a random number. Source: ADR-0004 D8

**Wrapper, frame order and display**
- **The wrapper holds no gameplay logic and no branch on a gameplay value.** It builds Clock, adapter, HeroInput, TowerInput, HudLogic, HUD and views from `battle.input_resolver` and `PresentationSettings`. Source: ADR-0001 D4
- **Only `BattleWrapper.step` calls `battle.tick`, with `battle.tick_seconds()`, never a literal** (tests and bots apart; L-TIME-2). Source: ADR-0004 G1, G2
- **`BattleWrapper.step(delta)` runs: (1) real-time models with `ms = min(delta * 1000.0, MAX_REAL_MS_PER_FRAME)`; (2) up to `n = clock.advance(delta, battle.clock_running())` ticks, stopping once `clock_running()` is false; (3) view refresh, then `queue_redraw()`.** No other battle node reads sim state from `_process`. Source: ADR-0004 D4, G3
- **`TickClock`: zero while closed; `0.5 + min(delta / dt, 1.0)` on the first running frame; `owed = floori(acc + 1e-6)`; cap only when owed exceeds `max_ticks`, then keep only the fraction below one tick.** Negative or non-finite `delta` counts as 0 with a dev error. Source: ADR-0004 D3, G4
- **`Battle.tick(dt)` runs: dt check (`fatal("tick_dt_mismatch")`), `clock_running()` gate, `_tick_guard.enter()`, then `flow.tick()`, `enemy_wave.advance()`, `combat.tick_status(roster)`, `tower_sim.tick()`, `hero_sim.tick()`, `enemy_wave.reap()`, with `if halted(): break` after each; then `_tick_count += 1` and `exit()`.** Source: ADR-0004 D5, G5; ADR-0009 D4
- **`project.godot` pins, checked through `ProjectSettings`, never file text** (L-PROJ-1): `physics/common/physics_ticks_per_second` 60, `physics/common/max_physics_steps_per_frame` 8, `application/run/max_fps` 60, `application/run/low_processor_mode` off, `display/window/vsync/vsync_mode` enabled, `application/run/delta_smoothing` on. Source: ADR-0004 G11, Amendment 2026-11-04 (E3)
- **`project.godot` sets every ADR-0003 Decision 1 key**: `config/quit_on_go_back=false`; viewport 540x960; `window/size/mode=0`, `mode.mobile=3`; stretch `canvas_items`, aspect `keep`, scale 1.0, `scale_mode="fractional"`; `handheld/orientation=1`; `emulate_touch_from_mouse=false`; `emulate_mouse_from_touch=true`; `agile_event_flushing=false`. Seven equal the default and drop on save; test effective values. Source: ADR-0003 D1, G1, Amendment 2026-11-04
- **The Android export preset sets `screen/edge_to_edge=true` beside `screen/immersive_mode`** (an export option, not a project setting). Source: ADR-0003 Amendment 2026-11-04
- **Insets: desktop all 0; mobile reads `SafeAreaMath.field_insets(get_display_safe_area(), window_rect, Vector2(540, 960))` once at battle build, in the wrapper.** One `FieldInsets` goes to the adapter and HudLogic. Source: ADR-0003 D3, G12
- **The minimum-size guard (`dp_per_unit = s * 160 / screen_get_dpi()` at least 2/3) runs once in `BattleWrapper._ready()` on mobile, reports to the dev-error sink and never blocks play.** Source: ADR-0003 D1
- **The wrapper builds HUD Controls under one `HudLayer` (`CanvasLayer`, layer 1) after `FieldViews`; the wrapper root is a `Node2D`.** Source: ADR-0011 D1, G13; ADR-0003 D4, Amendment 2026-11-05
- **The wrapper takes the result snapshot once, in the first frame step 3 whose `flow.phase()` poll finds WON or LOST, through `Battle.take_result_snapshot()`, and hands the one instance to HudLogic and RunLog.** It deep-copies each container and calls `make_read_only()` at each level. FATAL takes none. Source: ADR-0006 D9

**Input adapter** (ADR-0003)
- **`InputAdapter` is the only node that reads pointer events for gameplay** (L-INPUT-1). `process_mode = PROCESS_MODE_ALWAYS`; `setup()` takes `is_mobile: bool` from the wrapper, so the adapter reads no OS. Source: ADR-0003 D2, G2, Amendment 2026-11-04 (ADR-0007)
- **Presses come only from `_unhandled_input`; moves, releases and cancels only from `_input`, and only for pointers in `_down`.** The adapter never calls `set_input_as_handled()`. Source: ADR-0003 D2.1, G3
- **Drop any pointer event with `device == InputEvent.DEVICE_ID_EMULATION`; map mouse to `MOUSE_POINTER = 1 << 16`; forward only `MOUSE_BUTTON_LEFT`.** Source: ADR-0003 D2.2, G4, G5
- **Drop a press when the gate is closed, outside `[0, 540] x [0, 960]`, or in a rejected zone; a release with `event.is_canceled()` becomes `resolver.cancel_pointer(i)`.** Source: ADR-0003 D2.3, D3, G6
- **Lifecycle: the first away notification of an episode (`APPLICATION_FOCUS_OUT`, `APPLICATION_PAUSED`, `WM_WINDOW_FOCUS_OUT`) calls `resolver.cancel()`, clears `_down`, then emits `lifecycle_paused()`; `WM_GO_BACK_REQUEST` always does.** Focus-in never resumes; a viewport resize cancels with no pause. Source: ADR-0003 D2.5
- **On `NOTIFICATION_EXIT_TREE` the adapter sets `_live = false` and never calls the resolver again.** Source: ADR-0003 D2.3, G7
- **A story that rests on an `[Sn]` spike item may not close until that check passes or its fallback is in place.** Source: ADR-0003 G15

**Catalogue and data** (ADR-0002)
- **Catalogue data is UTF-8 JSON in `res://assets/data/catalogue/`, one `{"type", "records"}` object per file, listed in `manifest.json`, read with `FileAccess` and parsed with a `JSON` instance.** Strip a leading byte-order mark. Source: ADR-0002 D1, D2, G1
- **`Catalogue.load_manifest()` is the only code that touches `FileAccess`, and it reads only listed files.** Source: ADR-0002 D5, G2
- **Load runs once, synchronously, from AppRoot `_ready()`; a failed `LoadResult` carries no catalogue.** Source: ADR-0002 D5
- **Every record field is in `schema.gd`; parser, validator and snapshot read that table and nothing else, and it matches each record class by name and type both ways.** Source: ADR-0002 G3, G4
- **A missing key gives `field_missing`, an undeclared key `unknown_property`, a non-integral number in an `int` field `fractional_int`.** Accept JSON numbers as `int` or `float` (JSON returns `float`); an `int` field stores `int(v)`. Source: ADR-0002 D1, G5; probe-results.md ADR-0002 E1
- **Check kind with `typeof()`, then `is_finite()`, then bounds; collect every record-tier error; stop after Tier 0a or 0b on any error.** Source: ADR-0002 G6
- **Compare JSON keys as `String`; turn each ID into a `StringName` once; look up by `StringName` only.** Source: ADR-0002 G7
- **Fill each typed array property with `append()` or `assign()`, then call `make_read_only()` on it and on every nested container** (the call is not recursive). Source: ADR-0002 D4, G8
- **Records extend `RefCounted`, hold referenced IDs (never record objects), and use typed `Array`, not packed arrays.** Source: ADR-0002 D4
- **The `Catalogue` holds no `FatalLatch`, handler, battle or node; lookups return null on an unknown ID; each battle gets its own `StatAccessor`.** Source: ADR-0002 G10; ADR-0001 G7
- **Build the read-only proof with `CatalogueSnapshot.take()` and compare with `diff()`.** Source: ADR-0002 D6, G11
- **Every content rule has a unit test that breaks only that rule and sees exactly its one error; a rule that mirrors runtime maths calls the runtime function.** Source: ADR-0002 G12
- **Check `scene_ref` with `ResourceLoader.exists()` and `load()`.** Source: ADR-0002 G13
- **Player-facing export presets include `res://assets/data/catalogue/*.json` and exclude `res://tests/*`, `res://addons/gdUnit4/*`, `res://tools/ci/*`, with the `res://` prefix.** Source: ADR-0002 D8, G15
- **Every one-tick floor in the validator reads `TickMath.TICK_SECONDS`.** Source: ADR-0004 G13; ADR-0002 D3

**Tick time** (ADR-0004)
- **`TickMath.TICK_RATE = 60`, `TICK_SECONDS = 1.0 / TICK_RATE`; `to_ticks(seconds)` is `roundi(seconds / dt)`.** Non-finite or negative input reports a dev error and returns 0. Source: ADR-0004 D2
- **Every countdown is an `int` of ticks; every authored duration goes through `to_ticks`.** Source: ADR-0004 G6
- **Real-time models take time only from the wrapper's `advance(ms)` or `update()`.** Source: ADR-0004 G8
- **Bot baselines live under `tests/baselines/<os>_<arch>/`; determinism is promised per OS and CPU only, and a missing baseline is a report, not a pass.** Source: ADR-0004 D9, G12

**Commands and the tick guard**
- **Every public command has one shape and one return path: `if in_tick(): report ERR_COMMAND_IN_TICK: <Class>.<command>; return BUSY`, then `enter(); var r := _body(...); exit(); return r`.** Internal transitions call private functions, never the public command. Source: ADR-0004 D6, G7, Amendments 2026-11-04, 2026-11-05; ADR-0006 D7; ADR-0010 D2
- **`TickGuard.enter()` reports a dev error if already entered; `Battle.tick` reports and resets a guard it finds set; `Flow.pause()` and `resume()` call `enter()`/`exit()` only when `in_tick()` is false.** Source: ADR-0004 Amendment 2026-11-04; ADR-0006 D7

**Stat accessor** (ADR-0005)
- **Read every tower, enemy, hero and burst stat in `StatKeys.ROWS` through `stat_int(ctx, key)` or `stat_float(ctx, key)`.** Read Stage, Wave and Input fields and refs such as `burst_id` directly. Source: ADR-0005 D1, G1
- **Name keys only through `StatKeys` constants** (L-STAT-1). Source: ADR-0005 D3, G5
- **A bad call checks the six causes in order (`stat_null_context`, `stat_unresolved_def`, `stat_unknown_key`, `stat_inapplicable_key`, `stat_type_mismatch`, `stat_bad_level`), calls the handler once with `"<code> def=<def_id> key=<key> level=<level>"`, and returns `0` / `0.0`.** Source: ADR-0005 D2, G10
- **`StatKeys` is `@abstract class_name StatKeys extends RefCounted`, constants only, with `KIND`, `ROWS`, `ROLE_TAG` as `const` Dictionaries read with `get(key, default)`.** Source: ADR-0005 D3, Amendment 2026-11-04
- **A numeric field added to `tower_level`, `enemy`, `hero` or `burst` gets its `StatKeys` constant, `KIND` and `ROWS` entries in the same change.** Source: ADR-0005 G13
- **Each caller makes its `ReadContext`s once and reuses them; only the owner writes a context; the live entity is held only through `WeakRef`, `null` when absent, never a `Node`.** Source: ADR-0005 D4, G6, G7, G8
- **`StatAccessor` holds only the Catalogue and the handler.** Source: ADR-0005 G9
- **`is_tower` and `level_count` never call the handler; commands call them before a read when an ID or level comes from an argument.** Source: ADR-0005 D6, G11
- **A grant modifier names its granter `grant_kind` and `grant_id`, never `source_*`, and does not reuse a reserved `GRANT_*` value.** Source: ADR-0005 D8, G16

**Signals** (ADR-0006)
- **Fire every battle signal with `sig.emit(...)` on the emitter's own `Signal`, in the call that changed the state.** Source: ADR-0006 D1
- **Commit every state change, counters included, before the first emit; keep the fixed order for multi-emit actions; a refusal changes nothing and emits nothing.** Tower: `gold_changed`, then `tower_built` or `tower_upgraded`. Flow outcome: lives and phase, `cancel_input()`, `lives_changed` if lives moved, `phase_changed`. Source: ADR-0006 D2, G3
- **Each signal has one role (WIRING, VIEW, INPUT) and exactly the typed payload in ADR-0006 Decision 4, with the 2026-11-04 `damage_applied` plain-value row.** Each WIRING signal has exactly one gameplay listener in the Builder's record. Source: ADR-0006 D3, D4, Amendment 2026-11-04 (ADR-0009)
- **Signal names are past tense (`tapped`, `ground_tapped`, `became_idle`, `waves_completed`, `phase_changed`; `pressed` kept); sim handlers are `_on_<signal>`.** Source: ADR-0006 D4, D5
- **Catalogue IDs are `StringName`; runtime IDs (`spawn_id`, `slot_index`, target ids, `level`, `telegraph_ticks`) are `int`; `String` carries only human text.** Source: ADR-0006 D6, G6
- **A new battle signal gets a `battle_signals.gd` row in the same change.** Source: ADR-0006 G7; ADR-0007 R4

**Input resolver** (ADR-0008)
- **`InputResolver extends RefCounted` in `src/foundation/input/`; it holds no battle object and calls no injected Callable.** Source: ADR-0008 D1, G1
- **Build a resolver only through `InputResolver.create(drag_slop, tap_slop)`, which returns null unless `validate()` passes (8 to 30, 16 to 34, `tap_slop > drag_slop`).** Source: ADR-0008 D1, G3
- **Resolver maths uses `float` scalars, squared distances, inclusive `dx * dx + dy * dy <= r * r`.** Source: ADR-0008 D2, G2
- **Refuse non-finite positions and bad `register` input with `push_error`; registry ids start at 1 and never repeat.** Source: ADR-0008 D2, D4, G6
- **Ties break by higher priority, then smaller squared distance, then lower id, within a class; freeze winners and the tap disc at press.** Source: ADR-0008 D2, D3, G7, G8
- **Commit every field before the first emit; a call made mid-drain is queued FIFO, never nested or deferred; at most `MAX_QUEUED_PER_DRAIN := 64` non-cancel ops per drain.** Source: ADR-0008 D4, G4, G5
- **Every exit to Idle ends with `became_idle()`; a replacing press runs the whole cancel before the press.** Source: ADR-0008 D3, G9, G10
- **Only the adapter makes gesture calls; only the adapter, Flow's `cancel_input()` and AppRoot teardown call `cancel()`** (L-INPUT-6). Source: ADR-0008 G12; ADR-0001 D7
- **Every resolver signal has a `battle_signals.gd` row; resolver tests drive the five calls with synthetic positions into an `EventLog`.** Source: ADR-0008 G15, G16

**Test harness and CI** (ADR-0007)
- **Run tests only through `tools/ci/run_tests.sh`: import (one retry), parse check, lint, tests, exit map; read only exit codes and `results.xml`.** Source: ADR-0007 D1, G1
- **The test step is `"$GODOT" --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode -c </dev/null`.** Source: ADR-0007 D1, Amendment 2026-11-05; coding-standards.md
- **Parse check with `res://.claude/scripts/godot-parse-check.gd`; lint with `res://tools/ci/lint/lint_main.gd`, run by Godot headless.** Source: ADR-0007 D1, D6
- **Use gdUnit4 6.2.2; CI downloads Godot 4.7.2 from a URL and SHA512 pinned in `tests.yml`.** Source: ADR-0007 D1
- **`project.godot` keeps `[gdunit4] report/godot/push_error=true`; claim each expected error or warning with an awaited `assert_error(...).is_push_error(msg)` or `is_push_warning(msg)`.** Source: ADR-0007 D5, G4
- **Unit tests build catalogues only through `catalogue_fixtures.gd`; only `tests/integration/` reads files.** Source: ADR-0007 D3, G2; ADR-0002 G14
- **Record signals into an `EventLog` through hand-written `RefCounted` fakes loaded by `preload`; a THEN compares the whole log in order with no `type_errors()`.** Source: ADR-0007 D4, G3
- **A test holds its spy, handler and sink for its whole run, frees every `Node` through `auto_free()`, and awaits one `process_frame` before a scene weakref check.** Source: ADR-0007 D2, G5
- **Suites `extends GdUnitTestSuite`, files `<system>_<feature>_test.gd`, functions `test_<scenario>_<expected>`, helpers start with `_`** (L-TEST-4). Source: ADR-0007 D2
- **Engine probes print `PROBE <id> <answer>`; a run on a new engine or gdUnit4 version adds rows to `probe-results.md`.** Source: ADR-0007 D7
- **Manual evidence (M1 to M9b) goes to `production/qa/evidence/<story-slug>/`, captured with `--write-movie`, never `--headless`.** Source: ADR-0007 D8

### Forbidden Approaches

**App lifecycle**
- **Never use autoload singletons or an event bus.** They hide dependencies, survive retry and defeat the listener-count test. Source: ADR-0001 Alt 1
- **Never own the battle from a scene root or reload a scene to retry.** Bots and headless tests could not build it. Source: ADR-0001 Alt 2
- **Never reset in place; no system has a reset function.** Hand-listed resets leaked state. Source: ADR-0001 D5, Alt 3
- **Never rely on Callable semantics alone at teardown; always `unwire()`.** Source: ADR-0001 Alt 4
- **Never load the fatal screen from a `.tscn`.** A load at the worst moment can fail. Source: ADR-0001 Alt 5
- **Never call `free()` on the wrapper, and never act on a latch from inside the wrapper's call stack** (L-APP-4). Source: ADR-0001 D5, G12
- **Never use `assert` for a check that matters in release, and never put a side effect in one** (L-APP-5, L-STAT-3). Source: ADR-0001 G10; ADR-0005 G10; ADR-0009 G7
- **Never set `SceneTree.paused`** (L-APP-6). Pause is a Flow phase. Source: ADR-0001 G16; ADR-0003 G14; ADR-0004 G11
- **Never name `AppRoot`, `BattleBuilder`, `Battle` or `BattleWrapper` from gameplay or Foundation code** (L-LAYER-2). Source: ADR-0001 G2
- **Never let a sim object hold `Battle`, `AppRoot` or any `Node`.** Source: ADR-0001 D3, G6
- **Never pass a lambda, or `bind()` with a sim object argument, in the Builder or the wrapper** (L-APP-3). Source: ADR-0001 G4
- **Never set `gui/theme/custom` or a custom font** (L-APP-8). Source: ADR-0001 D6, G14
- **Never `.connect(` a sim signal outside `wiring.gd`** (L-APP-2). Source: ADR-0001 G3; ADR-0006 D1

**Data**
- **Never store records as `.tres` / `.res`, with or without sentinel defaults, and never load data files through `load()` or `ResourceLoader`.** A Resource load hides missing, unknown and fractional fields. Source: ADR-0002 G1, Alt 1, Alt 2
- **Never use `ConfigFile` for catalogue data.** Variant text can build objects. Source: ADR-0002 Alt 3
- **Never keep the file list in a GDScript constant.** Adding a stage would change code. Source: ADR-0002 Alt 4
- **Never guard record fields with sealed setters.** Packed-array element writes and typed-array `append()` skip them. Source: ADR-0002 Alt 5
- **Never use `DirAccess` in `src/`** (L-DATA-1). Source: ADR-0002 G2
- **Never assign a record field or mutate a record's list outside `src/foundation/data/`** (L-DATA-2). Source: ADR-0002 G9
- **Never snapshot records with `duplicate()` or `duplicate_deep()`.** Neither copies `RefCounted` fields. Source: ADR-0002 D6, G11
- **Never check `scene_ref` with `FileAccess.file_exists()`.** Exports remap `.tscn`. Source: ADR-0002 G13
- **Never name a method `load`.** It shadows the global `load()`. Source: ADR-0002 D5

**Time and determinism**
- **Never tick from `_physics_process`.** It loses the pause reset and this project's cap. Source: ADR-0004 Alt 1
- **Never tick with a variable `dt`.** Source: ADR-0004 Alt 2
- **Never run a 30 Hz tick.** Source: ADR-0004 Alt 3
- **Never queue commands for the tick to drain (the S1 queue).** Results would come a tick late. Source: ADR-0004 Alt 4; ADR-0010 Alt 2
- **Never use one shared sim RNG.** One stream lets a new consumer shift all others. Source: ADR-0004 Alt 5
- **Never uncap the frame rate on high-refresh panels.** Source: ADR-0004 Alt 6
- **Never implement `_process` or `_physics_process`, create a `Timer`, use `await`, or read `Engine`, `Time` or `OS` in `src/foundation`, `src/core`, `src/feature`; never call `Input.flush_buffered_events`, `Input.parse_input_event` or `Viewport.push_input` there** (L-TIME-1). Source: ADR-0004 D9, G2
- **Never set `Engine.time_scale` or `Engine.physics_ticks_per_second`.** Source: ADR-0004 D9, G11
- **Never count down with `-=` of `dt`, `delta`, `TICK_SECONDS` or `tick_seconds()`** (L-TIME-3). Source: ADR-0004 G6
- **Never call global `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed`, `rand_from_seed`, `Array.shuffle()`, `Array.pick_random()` or `RandomNumberGenerator.new()` in `src/` outside the Builder and wrapper; never `rng.randfn()` in sim folders** (L-RNG-1). Source: ADR-0004 D8
- **Never use `Vector2` / `Rect2` operators or methods, `PackedVector2Array` maths, `Curve2D` / `Path2D` sampling or transcendentals for sim maths in `src/foundation`, `src/core`, `src/feature`.** Allowed: `float`/`int` scalars, `+ - * /`, `sqrt`, `min`, `max`, `abs`, `floor`, `ceil`, `round`, `floori`, `roundi`, `int()`, `clampf`, `clampi`, `is_finite`, `is_nan`, compares; `Vector2` as storage (L-VEC-1). Source: ADR-0004 D9, G10
- **Never use `sqrt` in the resolver.** Source: ADR-0008 G2

**Stat accessor**
- **Never read a stat as `Variant`, and never coerce a wrong-kind call.** Source: ADR-0005 D1, G12, Alt 1, Alt 2
- **Never cache a stat past the action that read it** (only `max_hp` seeding `Health`). Source: ADR-0005 D5, G2, Alt 3
- **Never inject the accessor as method Callables, key stats by an `int` enum, hold the live entity strongly, or add a `Battle.stat_accessor()` getter.** Source: ADR-0005 Alt 4, Alt 5, Alt 6, Alt 8
- **Never pass a `String` or `&"..."` literal key to `stat_int` / `stat_float`** (L-STAT-1). Source: ADR-0005 G5
- **Never read a `StatKeys.ROWS` field directly outside `src/foundation/data/`** (L-STAT-2). Source: ADR-0005 G1
- **Never call `ReadContext.new()` in a read path or outside the owner files** (L-STAT-4). Source: ADR-0005 G6

**Signals**
- **Never use `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT`, `CONNECT_REFERENCE_COUNTED`, `add_user_signal`, `emit_signal("...")`, string `connect("...")`, `call_deferred` around an emit, or `await` / `Tween.tween_await()` on a battle signal** (L-SIG-1, L-SIG-2). Source: ADR-0006 D1, G1, G2, Alt 1
- **Never add a naming exception for old signal names.** Source: ADR-0006 Alt 2
- **Never use `String` or `int` catalogue IDs; never type a `*_id` parameter or variable `String`** (L-SIG-4). Source: ADR-0006 D6, Alt 3
- **Never replace roles with one flat allowlist, and never rely on a lint alone instead of the command guard.** Source: ADR-0006 Alt 4, Alt 6

**Input adapter and display**
- **Never test `event.device == 0` or `!= 0`** (L-INPUT-3). Source: ADR-0003 G4; deprecated-apis.md
- **Never read `_input` / `_unhandled_input` outside the adapter, or `_gui_input` outside `tap_screen.gd`** (L-INPUT-1). Source: ADR-0003 G2
- **Never synthesise a release in the adapter.** Source: ADR-0003 G7
- **Never put a `Camera2D` in the battle; the field root keeps the identity transform** (L-INPUT-4). Source: ADR-0003 D1, G8
- **Never call `get_display_safe_area()` outside the wrapper, and never re-read insets mid-battle** (L-INPUT-5). Source: ADR-0003 G12, Alt 7
- **Never use stretch aspect `expand` or `keep_width`.** They break the identity transform and HUD layout. Source: ADR-0003 Alt 1, Alt 2
- **Never read every event in `_input` with the adapter's own Control check, or make the adapter a full-rect PASS Control.** Source: ADR-0003 Alt 3, Alt 4
- **Never set `emulate_touch_from_mouse = true`.** Source: ADR-0003 Alt 5
- **Never listen to one lifecycle notification per platform; use the union.** Source: ADR-0003 Alt 6

**Input resolver**
- **Never pick with `Area2D` / `input_pickable`, make targets `Control`s, or let each owner hit-test.** Source: ADR-0008 Alt 1, Alt 2, Alt 3
- **Never `call_deferred` a resolver call, and never let the queue grow unbounded.** Source: ADR-0008 Alt 4, Alt 6
- **Never call `InputResolver.new()` outside `create()` and tests** (L-INPUT-6). Source: ADR-0008 D1, G3
- **Never touch a `Node`, scene, input event, `Time`, `Engine`, `OS`, `Timer` or `await` in the resolver.** Source: ADR-0008 G1
- **Never call `last_trace()`, `state()` or name `GestureTrace` outside `src/foundation/input/`, `src/presentation/dev/` and tests** (L-INPUT-7). Source: ADR-0008 G13

**Tests and CI**
- **Never use the gdUnit4 GitHub Action.** Source: ADR-0007 Alt 1
- **Never lint with shell / Python regex or gdtoolkit.** Source: ADR-0007 Alt 2, Alt 3
- **Never use gdUnit4 `mock()`, `spy()`, `assert_signal` or `monitor_signals`; if an ADR ever allows a double, double only a `class_name` file class** (L-TEST-1). Source: ADR-0007 D4, G3, G8, Alt 4
- **Never treat exit 101 (orphans) as a pass, and never add lint suppression markers.** Source: ADR-0007 D1, D6, Alt 6
- **Never read a file, load a scene, call `get_tree()`, draw a random number or assert a time in a unit test** (L-TEST-2). Source: ADR-0007 G2
- **Never call `set_time_factor(` or `create_timer(` in tests** (L-TEST-1). Source: ADR-0007 D6
- **Never call `assert_error(` without `await`** (L-TEST-5). Source: ADR-0007 D5
- **Never pass a weakref target to an assert before its weakref check** (L-TEST-3). Source: ADR-0007 G5
- **Never use `--check-only` as a parse check, and never pass `--remote-debug` to the test step.** Source: ADR-0007 D1, F4, Amendment 2026-11-05
- **Never name `res://tests/`, `res://addons/`, `res://tools/` or a `GdUnit` class from `src/`** (L-LAYER-4). Source: ADR-0007 D6; ADR-0002 D8

### Performance Guardrails
- **Frame split at 60 fps**: input 0.5 ms, sim 4.0 ms, views 3.0 ms, engine 7.0 ms, headroom 2.1 ms. Source: ADR-0004 D7
- **One tick**: at most 2.0 ms p95 on an Adreno 5xx-class phone at the worst starter wave. Source: ADR-0004 D7
- **`MAX_TICKS_PER_FRAME`**: 4, provisional; at the first phone build set it to `clamp(floori(8.0 / p95_tick_ms), 2, 4)` and record it by amendment. Above 4.0 ms a tick, the budget reopens. Source: ADR-0004 D3, D7
- **`MAX_REAL_MS_PER_FRAME`**: 100 ms for real-time models. Source: ADR-0004 D4
- **Engine `_process` delta cap**: about `max_physics_steps_per_frame / physics_ticks_per_second` (8 / 60, about 0.13 s), above the clock's cap of 4 ticks (about 0.067 s). Source: ADR-0004 D1, Amendment 2026-11-04
- **Stat reads, all callers**: 0.7 ms p95 phone per tick (about 90 reads; 7.8 µs a read); ADR-0005 P1 decides, with the `match` fallback. Source: ADR-0009 D8; ADR-0005 Performance Implications
- **Allocation**: no per-tick allocation in the clock; no per-read allocation in the accessor. Source: ADR-0004 Performance Implications; ADR-0005 Performance Implications
- **Catalogue**: one synchronous load at boot, estimated well under 1000 ms (P1, unmeasured); under 1 MB. Source: ADR-0002 Performance Implications
- **Battles**: one alive at a time after the wrapper's end-of-frame free; `halted()` costs two reads. Source: ADR-0001 Performance Implications
- **Resolver**: at most 64 queued ops per drain; under 4 KB. Source: ADR-0008 D4, Performance Implications
- **CI job**: `timeout-minutes: 20`. Source: ADR-0007 D1

---

## Core Layer Rules

*Applies to: Combat (`src/core/combat/`), Flow and the result snapshot
(`src/core/flow/`), the core gameplay loop.*

### Required Patterns
- **`Combat` is a `RefCounted` made by `Combat.new(to_ticks, dev_error)` with method Callables `TickMath.to_ticks` and `DevErrorSink.report`, and nothing else.** It takes no `dt`, no `halted()`, reads no stat, calls no fatal and holds nothing that points at a sim. Source: ADR-0009 D5
- **Every HP change goes through `Combat.deliver`; only Combat creates or writes `Health` and `Status`.** Outside `src/core/combat/`, read them only through `hp_left`, `is_dead`, `speed_factor`, `hp_ratio`. Source: ADR-0009 D1, G1, Amendment 2026-11-05
- **`deliver(event) -> float` runs inside a tick only, with guards in this order: null event, target or health (`ERR_NO_TARGET`); removed (`ERR_REMOVED`); amount not finite or below 0 (`ERR_BAD_AMOUNT`); kind outside `SourceKind` (`ERR_BAD_KIND`); dead (silent); `applied = minf(amount, hp)`, 0.0 returns with no emit; then commit and emit `damage_applied`.** Source: ADR-0009 D5
- **Add to a counter key with `_dealt_by_id[id] = _dealt_by_id.get(id, 0.0) + applied`.** Source: ADR-0009 D5; probe X1
- **`attach(target, max_hp)` guards null (`ERR_NO_TARGET`), attached twice (`ERR_ATTACHED_TWICE`), bad `max_hp` (`ERR_BAD_MAX_HP`), each with one `push_error`, `false`, nothing changed.** Source: ADR-0009 D2
- **`apply_slow`: stronger or empty replaces, equal keeps `maxi(slow_ticks, ticks)`, weaker is ignored; slow time is `maxi(1, to_ticks(seconds))`.** Source: ADR-0009 D5
- **Target helpers (`first_in`, `nearest_in`, `all_in_radius`) check the radius first (`ERR_BAD_RANGE`), test `dx * dx + dy * dy <= r * r` on `x`, `y`, skip the dead, never sort or mutate, and tie to the lowest `spawn_id`.** Source: ADR-0009 D5
- **Call `report_attack` before the matching `deliver` calls.** Source: ADR-0009 D5
- **`Targetable` has no `_init`, ever; its `x`, `y`, `distance` are 64-bit `float`s; signals build `Vector2(t.x, t.y)`.** Source: ADR-0009 D1, D2, G5
- **Type enemy lists `Array[Targetable]` from construction; convert only with `Array(src, TYPE_OBJECT, &"RefCounted", Targetable)`.** Source: ADR-0009 G3
- **Typed results use `maxi`, `minf`, `maxf`.** Source: ADR-0009 G6
- **Every Combat guard reports one `push_error` through `dev_error` with its named constant.** Source: ADR-0009 G7
- **`attack_fired` and `damage_applied` carry plain values only and stay VIEW.** Source: ADR-0009 D6; ADR-0006 Amendment 2026-11-04
- **`hp_ratio(enemy)` is view-only: `hp / max_hp`, 1.0 for an unattached enemy; it changes no state and the sim never calls it.** Source: ADR-0009 Amendment 2026-11-05
- **Flow's outcome commit order: set state (closes the gate), `cancel_input()`, then `lives_changed` if lives moved, then `phase_changed`.** Source: ADR-0004 D5; ADR-0006 D2
- **`Flow.result() -> StageResult` is filled in the outcome commit, before any emit, and never changes; before an outcome it returns `null`.** Source: ADR-0006 D9
- **`ResultSnapshot extends RefCounted` holds plain values only, each array `make_read_only()`.** Source: ADR-0006 D9, Amendment 2026-11-05
- **Flow commands `start_wave()` and `call_early()` use the command shell and return `StartResult { OK, BUSY, HALTED, NOT_BUILD }` and `CallResult { OK, BUSY, HALTED, NOT_INTERMISSION, NO_TIME_LEFT }`.** Flow's `HALTED` is phase WON, LOST or FATAL. `pause()` and `resume()` stay `void`. Source: ADR-0010 D2, D3
- **Flow starts a wave through the injected method Callable `EnemyWave.start_next_wave`; Core never names Feature.** Source: ADR-0010 D3; ADR-0007 L-LAYER-1
- **A `Flow.pause()` that runs during a tick reports a dev error and applies; the tick finishes whole.** Source: ADR-0004 D5
- **Every result enum starts `OK, BUSY`, then the GDD's check order; the first failing check wins.** Source: ADR-0010 D2, G2
- **Compare results qualified: `if r == Flow.StartResult.OK`.** Source: ADR-0010 D2, G3

### Forbidden Approaches
- **Never put flat HP and slow fields on `Targetable`.** Source: ADR-0009 Alt 1
- **Never keep Combat state in a `Dictionary` keyed by `spawn_id`.** Source: ADR-0009 Alt 2
- **Never make enemies `Node2D`s.** A freed node cannot honour `removed`, and `position` collides. Source: ADR-0009 Alt 3
- **Never type Combat on `Object` with no base class.** Source: ADR-0009 Alt 4
- **Never put a `DamageEvent` in the `damage_applied` payload.** A view would reach a live enemy. Source: ADR-0009 Alt 5
- **Never store an enemy's place as `position: Vector2`.** Source: ADR-0009 Alt 6
- **Never name `.health`, `.status`, `Health.new(` or `Status.new(` outside `src/core/combat/`** (L-COMBAT-1). Source: ADR-0009 G1
- **Never write `var t := max(...)` or use `max` / `min` for a typed result.** It fails to parse. Source: ADR-0009 G6; probe X2
- **Never `+=` a missing `Dictionary` key.** It errors and aborts. Source: ADR-0009 D5; probe X1
- **Never use one shared result enum for all commands.** Source: ADR-0010 Alt 3
- **Never test a result with `if r:` or compare it to bare `OK`** (L-CMD-2). `OK` is 0 and `Error.OK`. Source: ADR-0010 D2, G3

### Performance Guardrails
- **Combat targeting**: 0.8 ms p95 phone per tick at the design point (384 checks); desktop trigger P2 0.053 ms. Source: ADR-0009 D8
- **Combat `deliver`, `tick_status`, emits**: 0.1 ms p95 phone (about 15 delivers, 48 steps); trigger 0.007 ms. Source: ADR-0009 D8
- **Flow, Tower, Hero bookkeeping and every `halted()` call**: 0.2 ms p95 phone. Source: ADR-0009 D8
- **ADR-0009's code**: 1.1 ms of the 2.0 ms tick; reads keep 0.7 ms. Source: ADR-0009 Performance Implications
- **Commands**: inside the 0.5 ms input slice. Source: ADR-0010 Performance Implications

---

## Feature Layer Rules

*Applies to: EnemyWave and Enemy (`src/feature/enemy_wave/`), TowerSim
(`src/feature/tower/`), HeroSim, HeroCounters, PinGeometry (`src/feature/hero/`).*

### Required Patterns
- **EnemyWave owns `_roster` and `_targets`, both `Array[Targetable]`, made once and reused.** `roster()` is every enemy not yet removed, corpses included, by ascending `spawn_id`; `targets()` the subset inside `0.0..FIELD_MAX_X (540.0)` and `0.0..FIELD_MAX_Y (960.0)`. Both return the internal array. Source: ADR-0009 D3
- **Only EnemyWave writes `spawn_id`, `distance`, `x`, `y`, `removed`, or changes a `roster()` / `targets()` result.** Source: ADR-0009 G2
- **Rebuild `_targets` after the leak loop; remove with `remove_at` on one enemy, then emit, so every emit sees whole lists.** Source: ADR-0009 D3
- **One add-enemy step `_add_enemy(def_id, start_distance) -> Enemy`: read `max_hp`, check `halted()`, `attach`, and on `false` call `fatal("enemy_attach_failed")`.** `spawn_id` only rises. Source: ADR-0009 D2, D3
- **`Enemy._init` sets `spawn_id`, `def_id` and `ctx = ReadContext.new(def_id, 0, self)`.** Source: ADR-0009 D2
- **EnemyWave builds one `PathTable` (`px`, `py`, `cum` as `PackedFloat64Array`, `length`) at build; each component is computed apart and `x`, `y` are rebuilt each tick.** Source: ADR-0009 D4
- **`advance()` takes no argument: spawn, move (`move_speed x speed_factor x dt`), leak by `spawn_id`, rebuild `_targets`; `reap()` handles corpses by `spawn_id`, then the clear check.** Source: ADR-0009 D4; ADR-0004 D5
- **Fire EnemyWave signals at their slots: `enemy_leaked` per leak after it leaves the roster; `enemy_killed` per corpse after `bounty` is read; then `wave_cleared(intermission_duration)` or, on the last wave, `waves_completed()`.** Source: ADR-0006 D4
- **`wave_index()` and `got_through_by_type()` are view-only.** Source: ADR-0009 D3
- **Read stats in a tick before changing state: EnemyWave `move_speed`, `lives_cost`, `bounty`, and `max_hp` once at spawn; TowerSim `range`, then `damage`, `attack_interval` and role keys; HeroSim Hero and Burst keys.** Source: ADR-0005 D5, G4
- **TowerSim ticks in ascending slot; HeroSim ticks the hero, then the burst.** Source: ADR-0004 D5
- **TowerSim and HeroSim commands use the shell and return `BuildResult`, `UpgradeResult`, `PinResult`, `BurstResult` (`OK, BUSY`, then the GDD order).** Source: ADR-0010 D2, G1, G2
- **A command makes every lookup, then every read through the owner's context, each read followed by `if halted(): return HALTED`, before its first write.** Source: ADR-0010 D3, G4; ADR-0005 D5
- **A refusal changes no field, counter or registry and emits nothing.** Source: ADR-0010 G5; ADR-0006 D2
- **The `build`, `upgrade`, `pin`, `burst` checks, reads and commits follow ADR-0010 Decision 3's table; `burst` sets `telegraph_left = maxi(1, to_ticks(...))`.** Source: ADR-0010 D3; ADR-0009 G6
- **TowerSim sets a slot context's `level` only after an upgrade commits; sims never change `def_id`.** Source: ADR-0005 G8
- **Gold is one `int` `_gold`, never negative, written only by TowerSim; each gold writer checks `halted()` first; `gold_changed` fires only on a change.** Source: ADR-0010 D4, G6
- **`call_bonus(ticks_left) -> int` is a side-effect-free instance method that truncates; the early-call handler pays `call_bonus(to_ticks(seconds_left))`.** Source: ADR-0010 D4
- **TowerSim and HeroSim each own one `DamageEvent`, reused; set `target = null` at the start of each attack and on every exit.** Source: ADR-0009 D5, G4
- **Check `halted()` after each Combat call that emits, per victim in splash and burst loops.** Source: ADR-0009 D5
- **Tower's "unslowed first" filters into a scratch list TowerSim owns.** Source: ADR-0009 D5
- **HeroSim owns one `HeroCounters`; `counters()` returns the same instance, read-only by contract. TowerSim exposes `towers_built()` and `slows_applied()`.** Source: ADR-0010 D5
- **`SlotState` is one owned instance per slot, updated at each commit, with `cooldown_full` (unchanged on upgrade); a bad index returns one shared empty sentinel and reports once.** Source: ADR-0010 D6, Amendment 2026-11-05
- **`PinGeometry` stays pure: `pin()` validates with `is_valid`; HeroInput and bots clamp with `clamp`.** Source: ADR-0010 D1
- **Sim-to-sim connections use method Callables, never self-capturing lambdas.** Source: ADR-0010 D1; ADR-0001 G4

### Forbidden Approaches
- **Never fold a sim and its input into one Tower or Hero object.** No test could prove input acts only through commands. Source: ADR-0010 Alt 1
- **Never mutate or keep a `roster()` / `targets()` result outside `enemy_wave.gd`, and never assign `spawn_id`, `distance`, `x`, `y`, `removed` outside `src/feature/enemy_wave/`** (L-COMBAT-2, L-COMBAT-4). Source: ADR-0009 G2
- **Never call `DamageEvent.new(` outside `tower_sim.gd` and `hero_sim.gd`** (L-COMBAT-3). Source: ADR-0009 G4
- **Never name `hero_sim` or `HeroSim` in sim folders outside `src/feature/hero/`, or in `src/root/` outside `battle.gd`, `battle_builder.gd`, `battle_wrapper.gd`** (L-HERO-1). Source: ADR-0010 D7, Amendment 2026-11-05
- **Never let `enemy_wave/`, `tower/` and `hero/` name each other** (L-LAYER-3). Source: ADR-0007 D6
- **Never build a ProjectileSpawner at MVP; every hit is instant.** Source: ADR-0009 D7
- **Never use `FileAccess` in a sim folder** (L-DEV-1; see Open Items for the catalogue loader). Source: ADR-0010 G9

### Performance Guardrails
- **EnemyWave move, path, leak, reap**: 0.2 ms p95 phone (48 moves); desktop trigger 0.013 ms. Source: ADR-0009 D8
- **Alive enemies**: at most 48 (`peak_alive_ub`). Source: ADR-0009 D8, Performance Implications
- **P2 `bench_targeting`**: run in debug and in a release export. If the release run fires, build the shared pass (`Combat.first_in_each`) in the first Tower story; if that misses 0.053 ms, amend ADR-0009 before the story closes. Source: ADR-0009 D8
- **Counter writes**: inside the 0.2 ms bookkeeping share. Source: ADR-0010 D5

---

## Presentation Layer Rules

*Applies to: field views (`src/presentation/field/`), the battle HUD
(`src/presentation/hud/`), TowerInput and HeroInput (`src/presentation/tower/`,
`src/presentation/hero/`), modal TapScreens, dev telemetry
(`src/presentation/dev/`), `ViewStyle`, `ViewClock`, `MotionPolicy`.*

### Required Patterns

**Listeners and reads**
- **A VIEW listener copies the payload, marks dirty and calls read-only queries only.** Source: ADR-0006 D3, G4
- **HudLogic reads the accessor only in frame step 3, never inside a sim signal handler, and checks `halted()` after each read.** `gold_changed` and arc open only mark costs dirty. Source: ADR-0005 D5, G14
- **HeroInput reads only in frame step 1, between ticks, in the Cancelling and Live aim states: Burst `reach`, `radius`, `damage` through its own `ReadContext`, and Combat `hp_left`, `is_dead`, each followed by `halted()`.** Source: ADR-0005 D5, Amendment 2026-11-05; ADR-0010 D1
- **Input owners command only from `pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended` and presentation signals; any owner handler may call `register`, `unregister`, `set_enabled`, `set_centre`.** Source: ADR-0006 D3; ADR-0008 D6
- **Owners register discs as ADR-0008 Decision 9 sets out** (TowerInput slots, towers and chip; HeroInput hero, button and sink; HudLogic Start/Call and the arc). Source: ADR-0008 D9
- **Call commands only from their owner files: `build`, `start_wave`, `call_early` from `hud_logic.gd`; `upgrade` from `tower_input.gd`; `pin`, `burst` from `hero_input.gd`** (L-CMD-1). Source: ADR-0010 D1, G7
- **On a result, HudLogic and TowerInput keep their UI open on `NO_GOLD` and close on anything else; HudLogic reports codes other than `HALTED`; HeroInput reports anything but `OK` or `HALTED`.** Source: ADR-0010 D2
- **The wrapper passes `burst_button_centre()` from the HUD to `HeroInput.setup()` once.** Source: ADR-0010 D1
- **Views read `reduce_motion` and `left_handed` only from the injected `PresentationSettings`, and Reduce Motion only through `MotionPolicy`.** Source: ADR-0001 D3, G15; ADR-0011 D8, G4
- **Views read sim state only in `refresh()`, through B10, `roster()`, `targets()` and Combat's `hp_left`, `is_dead`, `speed_factor`, `hp_ratio`; a VIEW handler stores plain values and reads no stat.** Source: ADR-0011 G5
- **ResultScreen and RunLog take result values only from the one `ResultSnapshot`** (L-SIG-5). Source: ADR-0006 G8

**Drawing** (ADR-0011)
- **One `_draw` node per view family, in tree order: `BackdropView`, `ExitStripView`, `RangeRingView`, `TowerView`, `EnemyView`, `CombatView`, `HeroView` under `FieldViews` (`Node2D`); `HudTopBand`, `HudField` under `HudLayer`.** A `Control` is never a child of a `Node2D`. Source: ADR-0011 D1, G13
- **`FieldViews` and `HudLayer` stay at the canvas origin with no transform.** Source: ADR-0011 D1
- **Build `Vector2(t.x, t.y)` only at the draw command; key per-enemy view state by `spawn_id`.** Views may use `Vector2` maths. Source: ADR-0011 D3
- **In each `_draw`: untextured shapes, then textures, then text; only `HudField` draws HUD text, in a final pass grouped by size (21, 24, 36 units).** Source: ADR-0011 D1, D6, G7
- **Each text slot caches one `TextLine`, re-shaped only when its string or size changes; the wrapper loads one font once.** Source: ADR-0011 D6, G8
- **Every line command passes a `ViewStyle` width of at least 2.0 and `antialiased = false`.** Source: ADR-0011 D1, G9; current-best-practices.md (4.7 no line feather)
- **Call `queue_redraw()` in step 3 only when a model changed or animates.** Source: ADR-0011 D1, G10
- **Size pools as ADR-0011 Decision 5 sets; made once at wrapper build, never shared, no `static var`; only enemy buffers grow, with one dev error per battle.** Source: ADR-0011 D5, G11
- **Every pixel-only value comes from `ViewStyle`; gameplay values never live there.** Source: ADR-0011 D9, G12
- **`PathMesh.bake` checks self-crossing first, then `offset_polyline(points, path_width / 2, JOIN_MITER, END_BUTT)`; on a crossing, several polygons, a hole or an empty triangulation: one dev error, then `draw_polyline` fallback.** Source: ADR-0011 D2
- **One `ViewClock` per wrapper drives every field and HUD timing; it does nothing while PAUSED.** Source: ADR-0011 D8, G3
- **The hit flash is a drawn white disc for `FLASH_SECONDS` (0.08 s); glow is one 128x128 `GradientTexture2D` (`FILL_RADIAL`) drawn with `draw_texture_rect`.** Source: ADR-0011 D7
- **TowerView's Cooling ring is `cooldown_left / cooldown_full`, 0 when `cooldown_full` is 0; the damaged core reads `hp_ratio`, slow reads `speed_factor`; skip corpses (`is_dead`).** Source: ADR-0011 D4
- **`HudTopBand` sets `accessibility_name` and `accessibility_live = AccessibilityServer.LIVE_POLITE` for gold and lives on change.** Source: ADR-0011 D6, Amendment 2026-11-05
- **Text is at least 21 units and meets 4.5:1 contrast on its panel in every state.** Source: ADR-0011 D6

**Modals and Controls** (ADR-0003)
- **Result and Paused use `TapScreen extends Control`: full rect, `MOUSE_FILTER_STOP`, `focus_mode = FOCUS_NONE`, children of `HudLayer` after `HudField`.** Source: ADR-0003 D4, Amendment 2026-11-05
- **`TapScreen._gui_input()` reads the left mouse family only, real or emulated, keeps `DEVICE_ID_EMULATION`, fires `tapped` only on the release of a press it saw, ignores `is_canceled()` releases, clears every held press after firing, and calls `accept_event()`.** Source: ADR-0003 D4, G4, G6, G10
- **Retry and Play again arm with `arm_ms = 300` from when the result text shows; Paused keeps 0.** Source: ADR-0003 D4, Amendment 2026-11-04
- **The wrapper calls `clear_press()` on show and on `lifecycle_paused`; it closes the press gate in the handler that shows a modal and opens it when the modal hides.** Source: ADR-0003 G10, G11
- **Every non-interactive Control in the wrapper has `mouse_filter = MOUSE_FILTER_IGNORE`, set on each node; every Control has `focus_mode = FOCUS_NONE`** (L-INPUT-2). Source: ADR-0003 D4, G9, G10
- **`lifecycle_paused` and the Paused `TapScreen.tapped` reach `Flow.pause` / `Flow.resume` through `view_wiring.connect_recorded()` with method Callables.** Source: ADR-0003 D2.6, G13
- **Wrapper code animates only with `create_tween()` on its own nodes** (field and HUD views use none). Source: ADR-0001 D4, G17; ADR-0011 D8

**Dev telemetry** (ADR-0010, ADR-0008)
- **The wrapper builds the sinks, `RunMeasures`, `RunLog` and `GestureLog` only when `OS.is_debug_build()` is true, holds each sink in a field until teardown, then calls `close()`.** Source: ADR-0010 D8, G10; ADR-0008 D8, G14
- **`JsonlFileSink.append_line` opens on the first line (`READ_WRITE` plus `seek_end()`, else `WRITE`), does `store_line` then `flush()`, and stops at `max_bytes` (8 MB) with `false`.** Source: ADR-0010 D8
- **Writers replace every non-finite float with `null`, nested values included, before `JSON.stringify`; each line has `v: 1`, `kind`, `launch_id`, `build`.** Source: ADR-0010 D8, G12
- **RunLog and GestureLog report their first `false` from the sink once to `dev_error` and go on.** Source: ADR-0010 D8, G11; ADR-0008 D8
- **GestureLog writes one JSON line per `became_idle` from `last_trace()`, and one per `tower_upgraded`; it stays view-only.** Source: ADR-0008 D8

### Forbidden Approaches
- **Never command, call a mutating method, write a field of a sim member, read the accessor, or keep a payload object or list from a VIEW handler** (L-SIG-3). Source: ADR-0006 D3, G4
- **Never command from `drag_cancelled` or `became_idle`.** Source: ADR-0008 D6, G11; ADR-0006 Amendment 2026-11-04
- **Never call `cancel()` or `cancel_pointer()` on the resolver from a listener.** Source: ADR-0006 D3
- **Never write a sim field or keep a query result from TowerInput or HeroInput; TowerInput uses only the non-fatal `level_count`.** Source: ADR-0010 G8
- **Never create a node per enemy, tower, flash, tracer or ring.** Source: ADR-0011 G1, Alt 1
- **Never set `z_index`, add a `CanvasLayer` (the wrapper's one `HudLayer` apart), set a material, or use `Light2D`, `CanvasModulate`, `Environment.glow` or particles in views** (L-VIEW-1). Source: ADR-0011 D1, D7, G2
- **Never use `Tween`, `create_tween()`, a SceneTree timer, `await` or `Time` in views (the debug `RenderBudgetProbe` apart)** (L-VIEW-1, L-VIEW-2). Source: ADR-0011 D8, G3
- **Never use a `Label` in `src/presentation/field/` or `src/presentation/hud/`** (L-VIEW-1). Modal TapScreens may. Source: ADR-0011 D6, Alt 4
- **Never use a `ShaderMaterial` or `CanvasItemMaterial` at MVP, including for the hit flash.** Source: ADR-0011 D7, Alt 3
- **Never draw the path with `draw_polyline` or `Line2D` outside the dev fallback.** Source: ADR-0011 Alt 2
- **Never pass line width -1.0.** Source: ADR-0011 D1
- **Never interpolate views at MVP.** Source: ADR-0011 D11, Alt 5
- **Never keep a `Targetable`, `roster()` or `SlotState` past `refresh()`.** Source: ADR-0011 G6; ADR-0010 D6
- **Never read `attack_interval` in a view, or `Combat.hero_share()` in any view.** Source: ADR-0011 D4; ADR-0010 D6
- **Never use `Button` for a modal, and never make TapScreen read touch and drop emulated mouse.** Source: ADR-0003 D4, Alt 8
- **Never make the wrapper root a full-rect Control.** Source: ADR-0003 G9
- **Never build the result snapshot in a `phase_changed` handler.** Source: ADR-0006 Alt 5
- **Never let RunLog name a sim or sim class** (L-SIG-5). Source: ADR-0010 D8, Alt 4
- **Never buffer telemetry lines for a per-frame flush.** Source: ADR-0010 Alt 5
- **Never name `FileAccess` in `src/presentation/dev/` outside `jsonl_file_sink.gd`; never name dev classes outside `src/presentation/dev/` except in the wrapper** (L-DEV-1). Source: ADR-0010 G9
- **Never let a sink failure reach `fatal`, `halted()` or a result, and never command or write sim state from telemetry.** Source: ADR-0010 G10, G11

### Performance Guardrails
- **GPU draw calls**: 60 a frame at the design point (48 enemies, 5 towers and the hero, 16 flashes, burst firing): HUD at most 12 (text batches at most 3), engine 4, spare 8, field views 36. Provisional until M9a. Source: ADR-0011 D10, Amendment 2026-11-05; project.yaml `performance.draw_call_limit`
- **Views and HUD CPU**: 3.0 ms p95 on the phone (step 3 plus every `_draw`); P-V1 trigger 0.2 ms p95 in a desktop release export. F1 MultiMesh is the likely path. Source: ADR-0011 D10
- **Pools**: enemy buffers 48; hit flashes 16 (`FLASH_MARKER_LIMIT`); death discs 48; tracers and spokes 64; splash rings 16; glow sprites 8; under 100 KB. Source: ADR-0011 D5, Performance Implications
- **Load**: one path bake and one texture per battle, under 1 ms; one atlas per font size. Source: ADR-0011 Performance Implications
- **`msaa_2d`** stays off unless M9b shows it is free. Source: ADR-0011 D1
- **Shaders**: art bible §8's 3-shader ceiling stays unused until Vertical Slice. Source: ADR-0011 D7
- **Measure**: M9a desktop windowed (all views, then HUD only) and M9b on the phone (plus p95 of step 3, `_draw`, `TIME_PROCESS`), retained in `production/qa/evidence/`. Source: ADR-0011 D10; ADR-0007 D8
- **Telemetry**: about 2 µs a line, debug only; 8 MB cap per sink file. Source: ADR-0010 D8, Performance Implications
- **Input**: input owners' commands and the adapter run inside the 0.5 ms input slice. Source: ADR-0004 D7; ADR-0010 Performance Implications

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example | Source |
|---------|-----------|---------|--------|
| Classes | PascalCase; no project prefix (a clash forces only a `Tr` prefix) | `TickClock` | `naming.classes` in project.yaml; ADR-0007 D10 |
| Variables | snake_case | `move_speed` | `naming.variables` in project.yaml |
| Signals/Events | snake_case, past tense | `gold_changed`, `became_idle` | `naming.signals` in project.yaml; ADR-0006 D5 |
| Files | snake_case, matching the class | `tick_clock.gd` | `naming.files` in project.yaml |
| Scenes | snake_case, matching the file | `app_root.tscn` | `naming.scenes` in project.yaml |
| Constants | SCREAMING_SNAKE | `MAX_TICKS_PER_FRAME` | `naming.constants` in project.yaml |
| Test files and functions | `<system>_<feature>_test.gd`; `test_<scenario>_<expected>` | `tick_clock_cap_test.gd` | ADR-0007 D2; L-TEST-4 |
| Signal handlers | `_on_<signal>` | `_on_enemy_killed` | ADR-0006 D4 |

- **No `class_name` in `tests/` or `tools/`; load helpers with `const X := preload(...)`** (L-NAME-2). Source: ADR-0007 D9 R6, F5
- **A `class_name` in `src/` must not clash with an engine or addon class** (L-NAME-1). Source: ADR-0007 D10

### Performance Budgets
| Target | Value | Source |
|--------|-------|--------|
| Framerate | 60 fps on a mid-range phone (30 fps floor on low-end Android); `max_fps` 60 | `performance.target_framerate` in project.yaml; technical-preferences.md; ADR-0004 D3 |
| Frame budget | 16.6 ms | `performance.frame_budget_ms` in project.yaml |
| Draw calls | 60 per frame (verify on device at the vertical slice) | `performance.draw_call_limit` in project.yaml; ADR-0011 D10 |
| Memory ceiling | 256 MB total, textures at most 16 MB | `performance.memory_ceiling_mb` in project.yaml; technical-preferences.md |

### Approved Libraries / Addons
- `technical-preferences.md` lists none yet.
- gdUnit4 6.2.2: approved for tests only, excluded from player exports, editor plugin kept off. Source: ADR-0007 D1; ADR-0002 D8

### Forbidden APIs (Godot 4.7.2)
These are deprecated or renamed for Godot 4.7.2 and apply to this 2D phone project.
Source: `docs/engine-reference/godot/deprecated-apis.md`.
- `TileMap`: use `TileMapLayer` (4.3), if a tile map is ever used; the MVP field draws with `_draw`.
- `VisibilityNotifier2D`: use `VisibleOnScreenNotifier2D` (4.0).
- `YSort`: use `Node2D.y_sort_enabled` (4.0).
- `Navigation2D`: use `NavigationServer2D` (4.0).
- `yield()`: use `await signal` (4.0); this project bans `await` in sim folders and views anyway.
- `connect("signal", obj, "method")` and string-based `connect()`: use `signal.connect(callable)` (4.0), here only through `Wiring.connect_recorded()`.
- `instance()` / `PackedScene.instance()`: use `instantiate()` (4.0).
- `OS.get_ticks_msec()`: use `Time.get_ticks_msec()` (4.0), only where time reads are allowed.
- `duplicate()` for nested resources: use `duplicate_deep()` (4.5); catalogue snapshots use neither (ADR-0002 G11).
- `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT`: use `UPDATE_WIDTH_UNIT` (4.7), if `RichTextLabel` is used.
- `add_image()` / `update_image()` `width_in_percent`, `height_in_percent`: use `width_unit`, `height_unit` (`RichTextLabel.ImageUnit`) (4.7).
- `DisplayServer.AccessibilityLiveMode` for `Control.accessibility_live`: write `AccessibilityServer.LIVE_POLITE` (4.7).
- `event.device == 0` to detect mouse or keyboard: use the event class or `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (4.7).
- `$NodePath` in `_process()`: use an `@onready var` cached reference.
- Untyped `Array` / `Dictionary`: use `Array[Type]` and typed variables. Settled ADR exceptions: `StatKeys` `KIND` / `ROWS` / `ROLE_TAG` (ADR-0005 D3), `got_through` and `got_through_by_type()` (ADR-0006 D9, ADR-0009 D3), Combat `_dealt_by_id` (ADR-0009 D5).
- Installing addons from the editor's AssetLib tab: use the Asset Store workspace (4.7).
- `Texture2D` in `Shader.set_default_texture_parameter()` / `get_default_texture_parameter()`: use `Texture` (4.4), once shaders arrive (none at MVP, ADR-0011 D7).

### Cross-Cutting Constraints

**GDScript 4.7 rules** (ADR-0007 Decision 9, binding for every layer)
- **R1: an override of a typed method returns that type on every path.** For `int`, `float`, `bool` return a real value (`return 0`, `return 0.0`); `return null` fits only `Object` / `Variant`. Source: ADR-0007 D9 R1, F4; ADR-0001 G18; ADR-0002 G16; ADR-0004 G14; ADR-0005 G17; ADR-0009 Engine Compatibility; current-best-practices.md
- **R2: to change one element of a packed-array property whose setter must run, assign the whole array.** Source: ADR-0007 D9 R2; current-best-practices.md
- **R3: keep state a lambda changes in an `Array`, `Dictionary` or object member.** Lambdas capture locals by value. Source: ADR-0007 D9 R3; current-best-practices.md
- **R4: every battle signal has a `battle_signals.gd` row, and fakes check each argument, since `emit()` checks no types.** Source: ADR-0007 D9 R4
- **R5: a rest parameter is `...name: Array` or untyped, and comes last.** Source: ADR-0007 D9 R5; current-best-practices.md
- **R6: helpers load by `const X := preload(...)`.** Source: ADR-0007 D9 R6
- **F1: never rely on a setter for `arr[i] = v` on a packed array** (L-GD-1, lands with the first such property). Source: ADR-0007 D9 F1
- **F2: never assign a captured outer local in a lambda.** Set `debug/gdscript/warnings/confusable_capture_reassignment` to 2 (error); keep `debug/gdscript/warnings/directory_rules` at its default `{"res://addons": 0}` (4.7.2 has no `exclude_addons`). Source: ADR-0007 D9 F2, Amendment 2026-11-04
- **F3: never trust declared signal types at runtime.** A `String` converts silently into a `StringName` parameter. Source: ADR-0007 D9 F3; ADR-0006 D8, Amendment 2026-11-04
- **F4: never `return null` in an override typed `int`, `float` or `bool`; never use `--check-only` as a parse check.** Source: ADR-0007 D9 F4
- **F5: never put `class_name` in `tests/` or `tools/`.** Source: ADR-0007 D9 F5
- **N1: type a `weakref()` local explicitly (`var w: WeakRef = weakref(x)`), never `:=`** (`inference_on_variant` is an error by default). Source: ADR-0007 D9 N1; probe-results.md side findings
- **N2: never name a variable `log`.** It shadows `log()` and breaks the parse. Source: ADR-0007 D9 N2; probe-results.md side findings
- **`@abstract` methods have no body; a variadic parameter is written `...values: Array`.** Source: current-best-practices.md (GDScript 4.5+)

**Architecture and process**
- **Layer direction: Foundation < Core < Feature < Presentation < root; no file names a higher layer's class or `res://src/` path** (L-LAYER-1). Source: ADR-0007 D6
- **Dependency injection, no autoloads, no `SceneTree.paused`, no `assert`.** Source: ADR-0001 G1, G10, G16; coding-standards.md
- **Gameplay values live in the catalogue or with their input owner; pixel-only values live in `ViewStyle`.** Source: ADR-0011 D9; coding-standards.md
- **`FileAccess` is used only by `Catalogue.load_manifest()` (`src/foundation/data/`) and `JsonlFileSink` (`src/presentation/dev/`).** Source: ADR-0002 G2; ADR-0010 G9 (see Open Items)
- **Lints have no suppression marker; a real exception changes the ADR or `tools/ci/lint/scopes.gd`.** Source: ADR-0007 D6, Alt 6
- **A fresh clone runs `"$GODOT" --headless --path . --import` before any test; `--import` and `--quit-after` are not parse checks.** Source: ADR-0007 D1; current-best-practices.md
- **Filter GDScript files with `rg --glob "*.gd"` (or Grep `glob: "*.gd"`), never `--type gdscript`.** Source: current-best-practices.md (Tooling)
- **Player-observable stories close only with a retained screenshot in `production/qa/evidence/`.** Source: ADR-0007 D8; coding-standards.md

### Lint Index (ADR-0007 Decision 6)
When: 1 before the first Logic story, 2 before the first sim story, 3 with the story that adds the file. Kind: T token table, C own code, S settings suite, X scene test, A alias, R review, D deferred.

| ID | Kind/When | Fails on (short) |
|---|---|---|
| L-LAYER-1 | C1 | Higher-layer class name or `res://src/` path |
| L-LAYER-2 | C1 | Any `src/root/` class outside root |
| L-LAYER-3 | C3 | `enemy_wave/`, `tower/`, `hero/` naming each other |
| L-LAYER-4 | T1 | `res://tests/`, `res://addons/`, `res://tools/`, `GdUnit` in `src/` |
| L-APP-1 | S1 | Any autoload; `run/main_scene` not `app_root.tscn` |
| L-APP-2 | T3 | `.connect(` outside `wiring.gd` and named engine-node files |
| L-APP-3 | T3 | Lambda or `.bind(` in Builder, wrapper |
| L-APP-4 | T3 | `.free()` in `src/root/` |
| L-APP-5 | T3 | `assert(` in `src/` |
| L-APP-6 | T3 | Assigning `paused` on the tree |
| L-APP-7 | T3 | `get_tree().create_tween(`, `create_timer(` |
| L-APP-8 | S1 | `gui/theme/custom` or `custom_font` set |
| L-DATA-1 | T3 | `DirAccess` in `src/` |
| L-DATA-2 | C3 | Record field writes or list mutation outside `foundation/data/` |
| L-INPUT-1 | T3 | `_input`, `_unhandled_input` outside adapter; `_gui_input` outside `tap_screen.gd` |
| L-INPUT-2 | X3 | Control not IGNORE (TapScreen not STOP); `focus_mode` not NONE; full-rect wrapper root |
| L-INPUT-3 | T3 | `device == 0`, `device != 0` |
| L-INPUT-4 | T3 | `Camera2D` in `src/` or `.tscn` |
| L-INPUT-5 | T3 | `get_display_safe_area(` outside the wrapper |
| L-INPUT-6 | C3 | Gesture calls outside adapter; `cancel(` outside its three callers; `InputResolver.new(` |
| L-INPUT-7 | T3 | `last_trace(`, `GestureTrace`, resolver `state(` outside `foundation/input/`, `presentation/dev/` |
| L-PROJ-1 | S1 | ADR-0003 D1 or ADR-0004 G11 key off its value |
| L-TIME-1 | T2 | `_process`, `_physics_process`, `Timer`, `await`, `Engine.`, `Time.`, `OS.`, input injection in `SIM` |
| L-TIME-2 | T2 | `battle.tick(` outside wrapper; `.tick(` with a number literal |
| L-TIME-3 | C2 | `-=` then `dt`, `delta`, `TICK_SECONDS`, `tick_seconds()` |
| L-RNG-1 | T2 | Global RNG, `.shuffle(`, `.pick_random(`, `RandomNumberGenerator.new(`; `.randfn(` in `SIM` |
| L-VEC-1 | C2 | `Vector2` / `Rect2` methods or operators, curve and packed maths, transcendentals in `SIM` |
| L-STAT-1 | T3 | String or `&"..."` key in `stat_int(` / `stat_float(` |
| L-STAT-2 | C3 | Direct `ROWS` field read outside `foundation/data/` |
| L-STAT-3 | A | L-APP-5 for `stat_accessor.gd`, `read_context.gd` |
| L-STAT-4 | T3 | `ReadContext.new(` outside enemy, tower_sim, hero_sim, hud_logic, hero_input |
| L-SIG-1 | T3 | `emit_signal(`, `connect("`, `add_user_signal(` |
| L-SIG-2 | T3 | `CONNECT_` flags; `call_deferred` emit; `await` on a battle signal; `tween_await(` |
| L-SIG-3 | C3 | Presentation or wrapper assigning a sim member field |
| L-SIG-4 | C3 | `*_id` typed `String` |
| L-SIG-5 | T3 | Sim member or class name in ResultScreen, RunLog |
| L-COMBAT-1 | T3 | `.health`, `.status`, `Health.new(`, `Status.new(` outside `core/combat/` |
| L-COMBAT-2 | C3 | Writing `spawn_id`, `distance`, `x`, `y`, `removed` outside `feature/enemy_wave/` |
| L-COMBAT-3 | T3 | `DamageEvent.new(` outside `tower_sim.gd`, `hero_sim.gd` |
| L-COMBAT-4 | C3 | Mutating a `roster()` / `targets()` result outside `enemy_wave.gd` |
| L-CMD-1 | C3 | A command called outside its owner file |
| L-CMD-2 | C3 | `if` / `not` / `and` / `or` before a command call; bare `OK` beside a result |
| L-DEV-1 | T3 | `FileAccess` in `presentation/dev/` outside `jsonl_file_sink.gd`; any `FileAccess` in `SIM` |
| L-HERO-1 | T2 | `hero_sim`, `HeroSim` outside `feature/hero/` and three root files |
| L-VIEW-1 | T3 | `Tween`, `create_tween(`, material, `z_index`, `CanvasLayer`, `Light2D`, particles, `Label` in field, hud |
| L-VIEW-2 | T3 | `Time.` in field, hud (probe apart) |
| L-NAME-1 | C1 | `class_name` clashing with an engine or global class |
| L-NAME-2 | T1 | Any `class_name` in `tests/`, `tools/` |
| L-GD-1 | D | `arr[i] = v` on a property with a setter |
| L-TEST-1 | T1 | `assert_signal(`, `monitor_signals(`, `set_time_factor(`, `create_timer(`, global RNG in tests |
| L-TEST-2 | T1 | File, manifest, scene or `get_tree()` in `tests/unit/` |
| L-TEST-3 | R | Weakref target passed to an assert first |
| L-TEST-4 | C1 | Suite not `*_test.gd`; public non-`test_` function |
| L-TEST-5 | T1 | `assert_error(` with no `await` |

`SIM` = `src/foundation`, `src/core`, `src/feature`; `RNG_EXEMPT` = `battle_builder.gd`, `battle_wrapper.gd` (`tools/ci/lint/scopes.gd`).

---

## Open Items

**ADR conflicts found while building this manifest** (none edited here; each
needs an ADR amendment by its owner):
1. **`FileAccess` in Foundation.** ADR-0007 L-DEV-1 (amended 2026-11-05) and ADR-0010 G9 ban any `FileAccess` in `SIM`, and `SIM` includes `src/foundation`. ADR-0002 D5, G2 make `Catalogue.load_manifest()` in `src/foundation/data/` the one `FileAccess` user. As written, the lint fails the catalogue loader. This manifest keeps both owners' intent: only the loader and `JsonlFileSink` use `FileAccess`. `scopes.gd` needs an exemption for the loader.
2. **Test command.** ADR-0007 D1 (amended 2026-11-05) drops `--remote-debug tcp://127.0.0.1:0`, closes stdin and adds `-c`. `current-best-practices.md` ("the command the framework uses") and `project.yaml` `commands.test` still carry `--remote-debug` and no `-c` or `</dev/null`. This manifest follows ADR-0007 and coding-standards.md.
3. **`max` in a typed result.** ADR-0010 D3's burst row writes `telegraph_left = max(1, to_ticks(...))`; ADR-0009 G6 bans `max` / `min` for typed results (probe X2). This manifest uses `maxi`.
4. **Flow's Callable targets.** ADR-0001 D3 says Flow holds Callables to EnemyWave, the resolver, `TickMath` and the sink only. ADR-0004 and ADR-0006 amendments add `TickGuard.in_tick`, `enter`, `exit`, and ADR-0010 D3 adds `EnemyWave.start_next_wave`. The graph stays acyclic; ADR-0001's list is stale. This manifest lists the full set.

**Engine reference entries left out** (unclear whether they apply to this 2D
project; add them when a system needs them): `GodotPhysics3D` to Jolt,
`VisibilityNotifier3D`, `get_world()` to `get_world_3d()`, the `Skeleton3D`
signal rename, `AnimationPlayer.method_call_mode` / `playback_active` (no
`AnimationPlayer` is planned), `EditorSceneFormatImporterFBX` and the
`EditorSceneFormatImporter.IMPORT_*` enum (3D import), `AudioEffectSpectrumAnalyzer.tap_back_pos`
and the 4.7 `AudioStreamPlayer2D.area_mask` default (no audio ADR yet), and the
`Compositor` post-processing row.
