# Control Manifest

> **Engine**: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D; 2D portrait phone game)
> **Last Updated**: 2026-11-05
> **Manifest Version**: 2026-11-05
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011
> **Status**: Active. Regenerate with `/create-control-manifest update` when an ADR changes.

`Manifest Version` is the date this manifest was made. Stories embed it, and
`/story-readiness` compares it to find stories written against old rules. It
always equals `Last Updated`.

Sources: the eleven Accepted ADRs (amendments applied), `project.yaml`, the
engine reference; read the ADR for reasons. `[0001 D5, G12; 0004 A11-04]` cites
ADR-0001 Decision 5, Guideline 12, and ADR-0004's 2026-11-04 amendment. The Lint
Index holds ADR-0007's token bans; Forbidden lists name lints (`APP 1-8`).
**Rejected designs: see each ADR's Alternatives.**

**Layers** (L-LAYER-1): `src/foundation/` < `src/core/` < `src/feature/` <
`src/presentation/` < `src/root/`. No layer names a higher one; only root names
a root class (L-LAYER-2).

---

## Composition Root and Wrapper Rules

*Applies to: `src/root/` (AppRoot, Builder, Battle, wrapper, TickClock,
FatalScreen), wiring, the input adapter, display settings.*

### Required Patterns

**App root and Builder**
- No `[autoload]`, no event bus; `run/main_scene` is `res://src/root/app_root.tscn`. [0001 D1, G1]
- `BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler) -> Battle` is static on a `RefCounted`, touches no node, is never called from a handler; never name it `seed`. [0001 D2]
- The Builder returns `null` once the latch sets (checked each step); then AppRoot adds no wrapper. [0001 G8]
- Step (d) order: `DevErrorSink`, `TickMath`, `TickGuard`, sims. The wrapper owns a second `DevErrorSink` for `TickClock` and views. [0004 D2]
- Callable targets are `Battle` or `AppRoot` members; inject method Callables of Builder-owned objects (`HaltGate.halted`, not `Battle.halted`); `stat_accessor`, `battle.combat` go as objects. [0001 D3, G4, G5; 0005 D7; 0009 D5]
- `Battle`'s sims, `fatal_latch`, `input_resolver`, `stat_accessor`, `halt_gate` are public read-only; `_tick_math`, `_dev_error_sink`, `_wiring`, `_tick_guard` private. [0001 D2; 0004]
- Flow's injected targets are `EnemyWave.wave_index`, `EnemyWave.start_next_wave`, `InputResolver.cancel` (as `cancel_input()`), `TickMath`, the dev-error sink, and `TickGuard.in_tick`, `enter`, `exit`; nothing that points at `HeroSim`, `TowerSim` or `HaltGate`. No cycle. [0001 D3, A11-05; 0010 D3]
- Sim signals connect only via a `Wiring` record's `connect_recorded()`, no flags (Builder's for gameplay, `view_wiring` for views); a failed `connect()` is reported, unrecorded; `pairs()` is read-only. [0001 G3; 0006 D1]
- AppRoot acts on the retry and fatal latches only in its `_process`, fatal first. Retry handlers only `request_retry()`; a latch outside WON or LOST clears. Retry builds anew; nothing has a reset. [0001 D5, G11]
- Teardown: stop clock, `resolver.cancel()`, wrapper `PROCESS_MODE_DISABLED`, `view_wiring.disconnect_all()`, `remove_child()`, `queue_free()`, `battle.unwire()`, null all references. [0001 D5, G12]
- A wrapper scene that fails to load or instantiate: `fatal("wrapper_scene_failed")` on the app latch. [0001 G13]
- One `FatalLatch` class, two instances (battle forwards; app not); `fatal(cause)` keeps the first cause, forwards or `push_error`s, emits `latched(cause)` once. All fatals use it. [0001 D6]
- `FatalScreen`: a code-built `Control` named by class, no resource, no catalogue; debug shows the first cause and each `ValidationError`, release one generic line. [0001 D6, G14]
- In a tick, check `halted()` after each accessor read, Callable call or emit; return when true. [0001 G9; 0006 D2]
- Checks that matter go to the fatal handler or the dev-error sink (`push_error`, never halts). [0001 D7, G10]
- Randomness (none at MVP): one `RandomNumberGenerator` per consumer, Builder-made, held by `Battle`, seeded `splitmix64(rng_seed * 1_000_003 + SALT)`; cosmetic ones are the wrapper's, not from `rng_seed`. [0004 D8]

**Wrapper and display**
- The wrapper has no gameplay logic or branch; it builds Clock, adapter, inputs, HudLogic, HUD, views from `battle.input_resolver`, `PresentationSettings`. [0001 D4]
- Only `BattleWrapper.step` (and tests, bots) calls `battle.tick`, with `battle.tick_seconds()`. [0004 G1, G2]
- `step(delta)`: (1) real-time models, `ms = min(delta * 1000.0, MAX_REAL_MS_PER_FRAME)`; (2) up to `clock.advance(delta, battle.clock_running())` ticks while running; (3) refresh, `queue_redraw()`. No other node reads sim state in `_process`. [0004 D4, G3]
- `TickClock`: 0 while closed, `0.5 + min(delta / dt, 1.0)` on reopening, `owed = floori(acc + 1e-6)`, cap only above `max_ticks` (keep the sub-tick part); bad `delta` is 0 and a dev error. [0004 D3, G4]
- `Battle.tick(dt)`: dt check (`fatal("tick_dt_mismatch")`), `clock_running()`, `enter()`; `flow.tick()`, `enemy_wave.advance()`, `combat.tick_status(roster)`, `tower_sim.tick()`, `hero_sim.tick()`, `enemy_wave.reap()`, each then `halted()` break; count; `exit()`. [0004 D5, G5; 0009 D4]
- `project.godot` holds ADR-0004 G11's pins (60 physics ticks, 8 steps, `max_fps` 60, vsync, delta smoothing) and ADR-0003 Decision 1's keys (540x960, `canvas_items`, `keep`); tests read effective values. [0004 G11; 0003 D1, G1]
- The Android preset sets `screen/edge_to_edge=true` beside `immersive_mode`. [0003 A11-04]
- Insets: desktop 0; mobile: `SafeAreaMath.field_insets(get_display_safe_area(), window_rect, Vector2(540, 960))` once at build in the wrapper; one `FieldInsets` for adapter, HudLogic. [0003 D3, G12]
- On mobile the size guard (`s * 160 / screen_get_dpi()` at least 2/3) runs once in `_ready()`, report only. [0003 D1]
- Wrapper root: a `Node2D`; HUD Controls in one `HudLayer` (layer 1) after `FieldViews`; identity field transform. [0011 D1, G13; 0003 G8, G9]
- The wrapper takes one snapshot in the first step 3 that polls WON or LOST, via `Battle.take_result_snapshot()` (deep, read-only copy), for HudLogic and RunLog; none on FATAL. [0006 D9]
- Wrapper code animates only with `create_tween()` on its own nodes. [0001 D4, G17]

**Input adapter**
- `InputAdapter` alone reads gameplay pointer events; `PROCESS_MODE_ALWAYS`; `setup()` takes `is_mobile: bool` (no OS read). [0003 D2, G2]
- Presses from `_unhandled_input`; moves, releases, cancels from `_input`, for pointers in `_down`; no `set_input_as_handled()`. [0003 D2.1, G3]
- Drop `device == InputEvent.DEVICE_ID_EMULATION`; mouse is `MOUSE_POINTER = 1 << 16`; forward only `MOUSE_BUTTON_LEFT`. [0003 D2.2, G4, G5]
- Drop a press if the gate is closed, outside `[0, 540] x [0, 960]` or in a rejected zone; an `is_canceled()` release is `cancel_pointer(i)`. [0003 D2.3, G6]
- An episode's first `APPLICATION_FOCUS_OUT`, `APPLICATION_PAUSED` or `WM_WINDOW_FOCUS_OUT`, and every `WM_GO_BACK_REQUEST`: `resolver.cancel()`, clear `_down`, emit `lifecycle_paused()`. Focus-in never resumes; a resize cancels, no pause. [0003 D2.5]
- On `NOTIFICATION_EXIT_TREE`, `_live = false`; no resolver call after. [0003 D2.3, G7]
- `lifecycle_paused`, Paused `tapped` reach `Flow.pause` / `resume` via `view_wiring`. [0003 D2.6, G13]
- An `[Sn]` spike story closes only once its check passes or its fallback is in. [0003 G15]

### Forbidden Approaches
- Lints: APP 1-8, INPUT 1, 4, 5, PROJ, TIME 2, RNG.
- Never act on a latch inside the wrapper's call stack. [0001 D5, G12]
- Never let a sim object hold `Battle`, `AppRoot` or a `Node`. [0001 D3, G6]
- Never set `Engine.time_scale`, `Engine.physics_ticks_per_second`; pause is a Flow phase. [0004 G11; 0001 G16]
- Never tick from `_physics_process`. [0004 D1]
- Never re-read insets mid-battle or make up a release. [0003 G7, G12]
- Never build the snapshot in a `phase_changed` handler. [0006 D9]

### Performance Guardrails
- **Frame**: input 0.5 ms, sim 4.0, views 3.0, engine 7.0, spare 2.1. **Tick**: 2.0 ms p95, Adreno 5xx-class phone, worst starter wave. [0004 D7]
- **`MAX_TICKS_PER_FRAME`**: 4 for now; the first phone build sets `clamp(floori(8.0 / p95_tick_ms), 2, 4)` by amendment; over 4.0 ms a tick reopens the budget. [0004 D3, D7]
- **`MAX_REAL_MS_PER_FRAME`**: 100 ms. Engine delta cap about 8 / 60 s, above the 4-tick clock cap. [0004 D1, D4]
- **Battles**: one alive; `halted()` is two reads; no per-tick clock allocation. [0001; 0004]

---

## Foundation Layer Rules

*Applies to: `src/foundation/` `data/`, `time/`, `input/`; command guard,
accessor, signals; tests and CI.*

### Required Patterns

**Catalogue and data**
- Data: UTF-8 JSON in `res://assets/data/catalogue/`, one `{"type", "records"}` a file, listed in `manifest.json`, read by `FileAccess`, parsed by a `JSON` instance; strip a BOM. [0002 D1, D2, G1]
- `Catalogue.load_manifest()` is the only `FileAccess` user outside `src/presentation/dev/`, reading only listed files (L-DEV-1 exempts `catalogue.gd`). [0002 G2, A11-05]
- Load once, synchronously, from AppRoot `_ready()`; a failed `LoadResult` has no catalogue. [0002 D5]
- `schema.gd` lists every record field, matches each record class by name and type both ways, and is all parser, validator and snapshot read. [0002 G3, G4]
- Missing key `field_missing`; undeclared key `unknown_property`; non-integral `int` `fractional_int`. JSON numbers arrive as `float`; `int` fields store `int(v)`. [0002 D1, G5; probe E1]
- Check `typeof()`, then `is_finite()`, then bounds; collect every record-tier error; stop after Tier 0a or 0b on any error. [0002 G6]
- Compare JSON keys as `String`; make each ID a `StringName` once; look up by `StringName`; test each index key with `typeof(key) == TYPE_STRING_NAME`. [0002 G7, V5]
- Fill typed arrays with `append()` or `assign()`, then `make_read_only()` each, nested ones too. [0002 D4, G8]
- Records extend `RefCounted`, hold IDs (not records), use typed `Array`, not packed arrays. [0002 D4]
- The `Catalogue` holds no latch, handler, battle or node; unknown IDs give null; each battle gets its own `StatAccessor`. [0002 G10; 0001 G7]
- Prove read-only with `CatalogueSnapshot.take()` and `diff()`. [0002 D6, G11]
- Each content rule has a unit test breaking only it, with one error; rules mirroring runtime maths call the runtime function. [0002 G12]
- Check `scene_ref` with `ResourceLoader.exists()` and `load()`. [0002 G13]
- Exports include `res://assets/data/catalogue/*.json`, exclude `res://tests/*`, `res://addons/gdUnit4/*`, `res://tools/ci/*`. [0002 D8]
- Each one-tick floor in the validator reads `TickMath.TICK_SECONDS`. [0004 G13]

**Tick time and sim maths**
- `TICK_RATE = 60`, `TICK_SECONDS = 1.0 / TICK_RATE`, `to_ticks(s) = roundi(s / dt)` (bad input reports, gives 0). [0004 D2]
- Countdowns are `int` ticks; durations go through `to_ticks`; real-time models get time only from `advance(ms)` or `update()`. [0004 G6, G8]
- `SIM` maths uses only scalars, `+ - * /`, compares and ADR-0004 D9's list (`sqrt`, `min`, `max`, `abs`, the rounding and clamp functions, `is_finite`, `is_nan`); `Vector2` is storage. Typed results use `mini`, `maxi`, `minf`, `maxf`. [0004 D9, G10, A11-05; 0009 G6]
- Baselines: `tests/baselines/<os>_<arch>/`, deterministic per OS and CPU; a missing one is a report, not a pass. [0004 D9, G12]

**Command guard**
- Each public command: `if in_tick(): report ERR_COMMAND_IN_TICK: <Class>.<command>; return BUSY`, then `enter(); var r := _body(...); exit(); return r`; internal transitions are private. [0004 D6, G7; 0006 D7; 0010 D2]
- `enter()` reports a double entry; `Battle.tick` reports and resets a set guard; `pause()` / `resume()` enter and exit only outside a tick. [0004 A11-04]

**Stat accessor**
- Read `StatKeys.ROWS` stats via `stat_int(ctx, key)` / `stat_float(ctx, key)` with `StatKeys` constants; Stage, Wave, Input fields and refs (`burst_id`) directly. [0005 D1, G1, G5]
- A bad call checks D2's six causes in order, calls the handler once with `"<code> def=<def_id> key=<key> level=<level>"`, returns `0` / `0.0`. [0005 D2, G10]
- `StatKeys` is `@abstract`, `extends RefCounted`, constants only; `const` `KIND`, `ROWS`, `ROLE_TAG` read by `get(key, default)`; a new numeric field adds its constant, `KIND`, `ROWS` in one change. [0005 D3, G13]
- Owners make `ReadContext`s once, reuse and alone write them; the entity is a `WeakRef` (`null` if absent), not a `Node`. [0005 D4, G6, G7, G8]
- `StatAccessor` holds only the Catalogue and the handler. [0005 G9]
- `is_tower`, `level_count` never call the handler; commands call them before reading an argument's ID or level. [0005 D6, G11]
- Grant modifiers use `grant_kind`, `grant_id` (never `source_*`), no reserved `GRANT_*`. [0005 D8, G16]

**Signals**
- Emit by `sig.emit(...)` on the emitter's `Signal`, in the call that changed state. [0006 D1]
- Commit all changes, counters too, before the first emit; keep fixed emit orders (Tower: `gold_changed`, then `tower_built` / `tower_upgraded`); a refusal changes no field, counter or registry, emits nothing. [0006 D2, G3; 0010 G5]
- One role per signal (WIRING, VIEW, INPUT) and exactly D4's typed payload; one gameplay listener per WIRING signal, in the Builder's record. [0006 D3, D4, A11-04]
- Names are past tense (`pressed` kept); sim handlers are `_on_<signal>`. [0006 D4, D5]
- Catalogue IDs `StringName`; runtime IDs (`spawn_id`, `slot_index`, target ids, `level`, `telegraph_ticks`) `int`; `String` only for human text. [0006 D6]

**Input resolver**
- `InputResolver extends RefCounted` in `src/foundation/input/`; no battle object, no injected Callable. [0008 D1, G1]
- Only `InputResolver.create(drag_slop, tap_slop)` builds one: null unless `validate()` passes (8 to 30, 16 to 34, `tap_slop > drag_slop`). [0008 D1, G3]
- `float` scalars and squared distances, inclusive `dx * dx + dy * dy <= r * r`. [0008 D2, G2]
- `push_error` refuses non-finite positions and bad `register` input; ids start at 1, never repeat. [0008 G6]
- Ties: higher priority, smaller squared distance, lower id, within a class; freeze winners and the tap disc at press. [0008 D3, G7, G8]
- A mid-drain call queues FIFO, never nests; at most `MAX_QUEUED_PER_DRAIN := 64` non-cancel ops a drain. [0008 D4, G4, G5]
- Each exit to Idle ends with `became_idle()`; a replacing press runs the whole cancel first. [0008 D3, G9, G10]
- Only the adapter makes gesture calls; only it, Flow's `cancel_input()` and AppRoot teardown call `cancel()`. [0008 G12]
- Resolver tests drive the five calls with synthetic positions into an `EventLog`. [0008 G15, G16]

**Test harness and CI**
- Tests run only via `tools/ci/run_tests.sh` (import, one retry; parse check; lint; tests; exit map), reading only exit codes and `results.xml`. [0007 D1, G1]
- Test step `"$GODOT" --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit -a res://tests/integration --ignoreHeadlessMode -c </dev/null`. [0007 D1 step 4]
- Parse check `res://.claude/scripts/godot-parse-check.gd`, lint `res://tools/ci/lint/lint_main.gd`, both Godot headless; gdUnit4 6.2.2; `tests.yml` pins the Godot 4.7.2 URL and SHA512. [0007 D1, D6]
- Keep `[gdunit4] report/godot/push_error=true`; claim each expected error or warning with an awaited `assert_error(...).is_push_error(msg)` / `is_push_warning(msg)`. [0007 D5, G4]
- Unit tests build catalogues only via `catalogue_fixtures.gd`; only `tests/integration/` reads files. [0007 D3, G2; 0002 G14]
- Hand-written `RefCounted` fakes (`preload`) log signals to an `EventLog`; a THEN compares the whole log, in order, no `type_errors()`. [0007 D4, G3]
- A test holds spy, handler and sink to the end, `auto_free()`s each `Node`, awaits one `process_frame` before a scene weakref check. [0007 D2, G5]
- `extends GdUnitTestSuite`; `<system>_<feature>_test.gd`; `test_<scenario>_<expected>`; helpers start with `_`. [0007 D2]
- Probes print `PROBE <id> <answer>`; a new engine or gdUnit4 adds `probe-results.md` rows. [0007 D7]
- Manual evidence M1 to M9b: `production/qa/evidence/<story-slug>/`, by `--write-movie`, not `--headless`. [0007 D8]

### Forbidden Approaches
- Lints: DATA, DEV, TIME 1, 3, VEC, STAT, SIG 1, 2, 4, INPUT 6, 7, TEST, LAYER 4.
- Never `.tres` / `.res` records, or data via `load()` / `ResourceLoader`. [0002 G1]
- Never snapshot with `duplicate()` / `duplicate_deep()`, check `scene_ref` with `FileAccess.file_exists()`, or name a method `load`. [0002 D5, G11, G13]
- Never `min` / `max` a typed result (`var t := max(...)` fails to parse). [0009 G6; probe X2]
- Never read a stat as `Variant`, coerce a wrong kind, or cache a stat past its action (but `max_hp` for `Health`). [0005 D1, D5, G2, G12]
- Never `call_deferred` a resolver call, or use `sqrt`, a `Node`, scene, input event, `Time`, `Engine`, `OS`, `Timer` or `await` in it. [0008 G1, G2]
- Never hit-test with `Area2D`, `input_pickable`, `Control` targets or per-owner tests. [0008 D2]
- Never `mock()` / `spy()`; a double, if an ADR ever allows one, doubles only a `class_name` file class. [0007 D4, G8]
- Never pass exit 101 (orphans); never `--check-only` as a parse check; never `--remote-debug` in the test step. [0007 D1, F4]

### Performance Guardrails
- **Stat reads**: 0.7 ms p95 phone a tick (about 90, 7.8 µs each); P1 decides (`match` fallback); no per-read allocation. [0009 D8; 0005]
- **Catalogue**: one boot load, well under 1000 ms (P1, unmeasured), under 1 MB. **Resolver**: under 4 KB. **CI**: `timeout-minutes: 20`. [0002; 0008; 0007 D1]

---

## Core Layer Rules

*Applies to: Combat (`src/core/combat/`), Flow and the result snapshot (`src/core/flow/`).*

### Required Patterns
- `Combat` is a `RefCounted` from `Combat.new(to_ticks, dev_error)` only: no `dt`, `halted()`, stat, fatal or sim pointer. [0009 D5]
- HP changes only via `Combat.deliver`; only Combat makes or writes `Health`, `Status`; others read `hp_left`, `is_dead`, `speed_factor`, `hp_ratio`. [0009 D1, G1]
- `deliver(event) -> float`, in a tick only: D5's guards (`ERR_NO_TARGET`, `ERR_REMOVED`, `ERR_BAD_AMOUNT`, `ERR_BAD_KIND`, dead silent); `applied = minf(amount, hp)` (0.0: no emit); commit; `damage_applied`. [0009 D5]
- Counters: `_dealt_by_id[id] = _dealt_by_id.get(id, 0.0) + applied`. [0009 D5; probe X1]
- `attach(target, max_hp)` guards `ERR_NO_TARGET`, `ERR_ATTACHED_TWICE`, `ERR_BAD_MAX_HP`: `push_error`, `false`, no change. [0009 D2]
- `apply_slow`: stronger or empty replaces, equal keeps `maxi(slow_ticks, ticks)`, weaker is ignored; slow time `maxi(1, to_ticks(seconds))`. [0009 D5]
- Target helpers check radius first (`ERR_BAD_RANGE`), test squared on `x`, `y`, skip the dead, never sort or mutate, tie to lowest `spawn_id`; `report_attack` precedes its `deliver`s. [0009 D5]
- Enemies are `RefCounted` `Targetable`s (no `_init`; `x`, `y`, `distance` 64-bit `float`s); signals build `Vector2(t.x, t.y)`. [0009 D1, D2, G5]
- Enemy lists are `Array[Targetable]` from the start; convert only by `Array(src, TYPE_OBJECT, &"RefCounted", Targetable)`. [0009 G3]
- Each Combat guard sends one `push_error` via `dev_error` with its named constant. [0009 G7]
- `attack_fired`, `damage_applied` carry plain values only and stay VIEW. `hp_ratio(enemy)` (`hp / max_hp`, 1.0 unattached) is view-only. [0009 D6, A11-05]
- Outcome commit: lives and phase (gate closes), `cancel_input()`, `lives_changed` if moved, `phase_changed`. [0004 D5; 0006 D2]
- `Flow.result() -> StageResult`: set in the outcome commit before any emit, then fixed; `null` before. [0006 D9]
- `ResultSnapshot extends RefCounted`: plain values only, the fields ADR-0006 Decision 9 lists, arrays read-only. [0006 D9]
- `start_wave() -> StartResult { OK, BUSY, HALTED, NOT_BUILD }`; `call_early() -> CallResult { OK, BUSY, HALTED, NOT_INTERMISSION, NO_TIME_LEFT }`; `HALTED` is WON, LOST, FATAL; `pause()`, `resume()` are `void`. [0010 D2, D3]
- Flow starts a wave via the injected `EnemyWave.start_next_wave`; Core never names Feature. [0010 D3]
- A `Flow.pause()` in a tick reports and applies; the tick finishes whole. [0004 D5]
- Each command has its own result enum: `OK, BUSY`, then the GDD's check order; first failure wins; compare qualified (`r == Flow.StartResult.OK`), never `if r:` or bare `OK`. [0010 D2, G2, G3]

### Forbidden Approaches
- Lints: COMBAT 1, CMD 2.
- Never `+=` a missing `Dictionary` key. [0009 D5; probe X1]

### Performance Guardrails
- **Targeting**: 0.8 ms p95 phone a tick (384 checks), P2 trigger 0.053 ms. **`deliver`, `tick_status`, emits**: 0.1 ms (15 delivers, 48 steps), trigger 0.007 ms. [0009 D8]
- **Bookkeeping, `halted()`**: 0.2 ms p95 phone; ADR-0009 code 1.1 ms of the 2.0 ms tick, reads 0.7 ms. **Commands**: in the 0.5 ms input slice. [0009 D8; 0010]

---

## Feature Layer Rules

*Applies to: EnemyWave and Enemy (`src/feature/enemy_wave/`), TowerSim
(`src/feature/tower/`), HeroSim, HeroCounters, PinGeometry (`src/feature/hero/`).*

### Required Patterns
- EnemyWave owns `_roster`, `_targets` (`Array[Targetable]`, made once), returned as is: `roster()` holds all not removed, corpses too, by `spawn_id`; `targets()` those in `0..FIELD_MAX_X` (540) x `0..FIELD_MAX_Y` (960). [0009 D3]
- Only EnemyWave writes `spawn_id`, `distance`, `x`, `y`, `removed` or changes a `roster()` / `targets()` result. [0009 G2]
- Rebuild `_targets` after the leak loop; `remove_at` one enemy, then emit. [0009 D3]
- `_add_enemy(def_id, start_distance)`: read `max_hp`, `halted()`, `attach`, on `false` `fatal("enemy_attach_failed")`; `spawn_id` only rises; `Enemy._init` sets `spawn_id`, `def_id`, `ctx = ReadContext.new(def_id, 0, self)`. [0009 D2, D3]
- One `PathTable` (`px`, `py`, `cum` as `PackedFloat64Array`, `length`) at build; `x`, `y` rebuilt per tick, apart. [0009 D4]
- `advance()`: spawn, move (`move_speed x speed_factor x dt`), leak by `spawn_id`, rebuild `_targets`; `reap()`: corpses by `spawn_id`, then the clear check. [0009 D4; 0004 D5]
- Emit `enemy_leaked` per leak once off the roster, `enemy_killed` per corpse after reading `bounty`, then `wave_cleared(intermission_duration)` or `waves_completed()`. [0006 D4]
- `wave_index()`, `got_through_by_type()` are view-only. [0009 D3]
- Read before writing: EnemyWave `move_speed`, `lives_cost`, `bounty` (`max_hp` at spawn); TowerSim `range`, then `damage`, `attack_interval`, role keys; HeroSim Hero, Burst keys. [0005 D5, G4]
- TowerSim ticks by ascending slot; HeroSim ticks hero, then burst. [0004 D5]
- TowerSim and HeroSim receive `TickGuard.in_tick`, `enter` and `exit` as method Callables; commands return `BuildResult`, `UpgradeResult`, `PinResult`, `BurstResult`. [0004 A11-04; 0010 D2]
- A command does every lookup, then every read via the owner's context, each then `if halted(): return HALTED`, before its first write. [0010 D3, G4]
- `build`, `upgrade`, `pin`, `burst` follow ADR-0010 Decision 3's table; `burst` sets `telegraph_left = maxi(1, to_ticks(...))`. [0010 D3, A11-05]
- A slot context's `level` changes only after an upgrade commits; `def_id` never changes. [0005 G8]
- Gold is one `int` `_gold`, never negative, written only by TowerSim after a `halted()` check; `gold_changed` only on a change. [0010 D4, G6]
- `call_bonus(ticks_left) -> int` is pure and truncates; the early-call handler pays `call_bonus(to_ticks(seconds_left))`. [0010 D4]
- TowerSim, HeroSim each reuse one `DamageEvent`; `target = null` at each attack start and exit. [0009 D5, G4]
- `halted()` after each emitting Combat call, per splash or burst victim; "unslowed first" uses TowerSim's scratch list. [0009 D5]
- HeroSim owns one `HeroCounters` (`counters()`, read-only by contract); TowerSim has `towers_built()`, `slows_applied()`. [0010 D5]
- One `SlotState` per slot, updated each commit, with `cooldown_full` (kept on upgrade); a bad index gets a shared empty sentinel, reported once. [0010 D6, A11-05]
- `PinGeometry` is pure: `pin()` checks `is_valid`; HeroInput and bots `clamp`. Sims connect via method Callables, never self-capturing lambdas. [0010 D1]
- No ProjectileSpawner at MVP; hits are instant. [0009 D7]

### Forbidden Approaches
- Lints: COMBAT 2-4, HERO, LAYER 3, DEV.
- Never keep a `roster()` / `targets()` result outside `enemy_wave.gd`. [0009 G2]

### Performance Guardrails
- **EnemyWave**: 0.2 ms p95 phone (48 moves), trigger 0.013 ms; at most 48 alive (`peak_alive_ub`). [0009 D8]
- **P2 `bench_targeting`**: debug and release; if release fires, the first Tower story builds `Combat.first_in_each`; missing 0.053 ms then needs an ADR-0009 amendment. [0009 D8]
- **Counter writes**: inside the 0.2 ms bookkeeping share. [0010 D5]

---

## Presentation Layer Rules

*Applies to: field views (`src/presentation/field/`), HUD (`hud/`), TowerInput
and HeroInput (`tower/`, `hero/`), TapScreens, dev telemetry (`dev/`),
`ViewStyle`, `ViewClock`, `MotionPolicy`.*

### Required Patterns

**Listeners and reads**
- HudLogic reads the accessor only in step 3, `halted()` after each; `gold_changed` and arc open only mark costs dirty. [0005 D5, G14]
- HeroInput reads only in step 1, Cancelling and Live: Burst `reach`, `radius`, `damage` (own `ReadContext`), Combat `hp_left`, `is_dead`, each then `halted()`. [0005 A11-05; 0010 D1]
- Owners command only from `pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended`, presentation signals; any handler may `register`, `unregister`, `set_enabled`, `set_centre`. [0006 D3; 0008 D6]
- Discs per ADR-0008 D9 (TowerInput slots, towers, chip; HeroInput hero, button, sink; HudLogic Start/Call, arc). [0008 D9]
- Commands come only from owner files: `build`, `start_wave`, `call_early` in `hud_logic.gd`; `upgrade` in `tower_input.gd`; `pin`, `burst` in `hero_input.gd`. [0010 D1, G7]
- HudLogic, TowerInput keep UI open on `NO_GOLD`, else close; HudLogic reports all but `HALTED`, HeroInput all but `OK`, `HALTED`. TowerInput reads only `level_count`. [0010 D2, G8]
- The wrapper passes `burst_button_centre()` to `HeroInput.setup()` once. [0010 D1]
- Views read `reduce_motion`, `left_handed` only from `PresentationSettings`; Reduce Motion only via `MotionPolicy`. [0001 G15; 0011 D8, G4]
- Views read sim state only in `refresh()` (B10, `roster()`, `targets()`, Combat `hp_left`, `is_dead`, `speed_factor`, `hp_ratio`), and no stat. [0011 G5]
- ResultScreen and RunLog take result values only from the one `ResultSnapshot`. [0006 G8]

**Drawing**
- One `_draw` node per family, in order: `BackdropView`, `ExitStripView`, `RangeRingView`, `TowerView`, `EnemyView`, `CombatView`, `HeroView` in `FieldViews` (`Node2D`); `HudTopBand`, `HudField` in `HudLayer`; no `Control` under a `Node2D`; roots untransformed. [0011 D1, G13]
- Build `Vector2(t.x, t.y)` only at the draw call; key per-enemy state by `spawn_id`; views may use `Vector2` maths. [0011 D3]
- Each `_draw`: shapes, textures, then text; only `HudField` draws HUD text, last, by size (21, 24, 36 units). [0011 D6, G7]
- One cached `TextLine` per slot, re-shaped on a new string or size; one font, loaded once. [0011 G8]
- Line calls pass a `ViewStyle` width of at least 2.0 and `antialiased = false`. [0011 D1, G9]
- `queue_redraw()` in step 3 only when a model changed or animates. [0011 G10]
- Pools per ADR-0011 D5: made once, unshared, no `static var`; only enemy buffers grow, one dev error a battle. [0011 G11]
- Pixel-only values come from `ViewStyle`. [0011 G12]
- `PathMesh.bake`: crossing check, then `offset_polyline(points, path_width / 2, JOIN_MITER, END_BUTT)`; a crossing, many polygons, hole or no triangles: dev error, `draw_polyline` fallback. [0011 D2]
- One `ViewClock` per wrapper drives all view timing; idle while PAUSED. [0011 D8, G3]
- Hit flash: white disc, `FLASH_SECONDS` 0.08 s. Glow: one 128x128 `GradientTexture2D` (`FILL_RADIAL`) via `draw_texture_rect`. [0011 D7]
- Cooling ring `cooldown_left / cooldown_full` (0 when `cooldown_full` is 0); damaged core `hp_ratio`; slow `speed_factor`; skip corpses. [0011 D4]
- `HudTopBand` sets `accessibility_name`, `accessibility_live = AccessibilityServer.LIVE_POLITE` for gold and lives. Text: 21 units minimum, 4.5:1 contrast in every state. [0011 D6]

**Modals and Controls**
- Result and Paused are `TapScreen extends Control`: full rect, `MOUSE_FILTER_STOP`, `FOCUS_NONE`, in `HudLayer` after `HudField`. [0003 D4]
- `TapScreen._gui_input()`: left mouse, real or emulated; `tapped` only on the release of a press it saw; ignore `is_canceled()`; clear held presses after; `accept_event()`. [0003 D4, G4, G6, G10]
- Retry and Play again arm 300 ms (`arm_ms`) after the result text shows; Paused 0. [0003 D4]
- `clear_press()` on show and on `lifecycle_paused`; the press gate closes while a modal shows. [0003 G10, G11]
- Non-interactive Controls get `MOUSE_FILTER_IGNORE`, per node; all Controls `FOCUS_NONE`. [0003 D4, G9, G10]

**Dev telemetry**
- The wrapper builds sinks, `RunMeasures`, `RunLog`, `GestureLog` only if `OS.is_debug_build()`, and holds each sink to teardown, then `close()`. [0010 D8, G10; 0008 G14]
- `JsonlFileSink.append_line` opens at the first line (`READ_WRITE` and `seek_end()`, else `WRITE`), `store_line`, `flush()`, and returns `false` past `max_bytes` (8 MB). [0010 D8]
- Writers turn non-finite floats, nested too, into `null` before `JSON.stringify`; lines carry `v: 1`, `kind`, `launch_id`, `build`. [0010 D8, G12]
- RunLog and GestureLog report a sink's first `false` once to `dev_error` and go on. [0010 G11; 0008 D8]
- RunLog writes through a `JsonlFileSink` to `user://run_log.jsonl`; GestureLog through its own to `user://gesture_log.jsonl`, a line per `became_idle` (`last_trace()`) and `tower_upgraded`; its `chip_state` is TowerInput's. [0008 D8, A11-05; 0010 D8]

### Forbidden Approaches
- Lints: SIG 3, 5, CMD 1, VIEW, INPUT 2, 3, DEV.
- A VIEW handler copies the payload and marks dirty; never commands, mutates, writes a sim field, reads the accessor or keeps a payload object or list. [0006 D3, G4]
- Never command from `drag_cancelled` or `became_idle`; never call resolver `cancel()` / `cancel_pointer()` from a listener. [0008 D6, G11; 0006 D3]
- Never write a sim field or keep a query result from TowerInput or HeroInput. [0010 G8]
- Never a node per enemy, tower, flash, tracer or ring. [0011 G1]
- Never `CanvasModulate`, `Environment.glow`, a tree timer or `await` in views (VIEW bans the rest); no MVP interpolation; no `Button` modal. [0011 D7, D8, D11; 0003 D4]
- Never `draw_polyline` / `Line2D` the path outside the fallback; never line width -1.0. [0011 D1, D2]
- Views never keep a `Targetable`, `roster()` or `SlotState` past `refresh()`, or read `attack_interval`, `Combat.hero_share()`. [0011 D4, G6; 0010 D6]
- Outside `dev/`, only the wrapper names dev classes. [0010 G9]
- No sink failure reaches `fatal`, `halted()` or a result; telemetry never commands or writes sim state. [0010 G10, G11]

### Performance Guardrails
- **Draw calls**: 60 a frame at the design point (48 enemies, 5 towers, hero, 16 flashes, burst): HUD 12 (text 3), engine 4, spare 8, field 36; provisional to M9a. [0011 D10]
- **Views CPU**: 3.0 ms p95 phone (step 3 and all `_draw`); P-V1 trigger 0.2 ms, desktop release; F1 MultiMesh likely. [0011 D10]
- **Pools**: enemies 48, flashes 16, death discs 48, tracers and spokes 64, splash rings 16, glows 8; under 100 KB. **Load**: one bake, one texture, under 1 ms; an atlas per font size. [0011 D5]
- **`msaa_2d`** off unless M9b shows it free. **Shaders**: art bible §8's 3-shader ceiling unused until Vertical Slice. [0011 D1, D7]
- **Measure**: M9a desktop windowed (all views, then HUD only); M9b phone (plus p95 of step 3, `_draw`, `TIME_PROCESS`); retained as evidence. [0011 D10; 0007 D8]
- **Telemetry**: about 2 µs a line, debug only, 8 MB a file. **Input**: commands and adapter fit 0.5 ms. [0010 D8; 0004 D7]

---

## Global Rules (All Layers)

### Naming Conventions
- Classes PascalCase, no prefix (a clash forces only `Tr`); variables, files, scenes snake_case (files match the class, scenes the file); constants SCREAMING_SNAKE; signals past tense; handlers `_on_<signal>`. [`naming.*`; 0007 D10; 0006 D4, D5]
- Tests `<system>_<feature>_test.gd`, `test_<scenario>_<expected>`. No `class_name` in `tests/`, `tools/`, or clashing in `src/`. [0007 D2, D10]

### Performance Budgets
From `project.yaml` `performance.*`: 60 fps on a mid-range phone (30 fps floor
on low-end Android; `max_fps` 60, 0004 D3); 16.6 ms frame; 60 draw calls (verify
on device at the vertical slice; 0011 D10); 256 MB memory, textures at most 16 MB.

### Approved Libraries / Addons
- None in `technical-preferences.md` yet. gdUnit4 6.2.2, tests only: out of player exports, editor plugin off. [0007 D1; 0002 D8]

### Forbidden APIs (Godot 4.7.2)
The ones a 2D phone game can hit; the rest: `deprecated-apis.md`.
- `event.device == 0` for mouse or keyboard: use the event class or `DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (4.7).
- `DisplayServer.AccessibilityLiveMode` for `accessibility_live`: use `AccessibilityServer.LIVE_POLITE` (4.7).
- Untyped `Array` / `Dictionary`: type them. Exceptions: `StatKeys` `KIND`, `ROWS`, `ROLE_TAG` (0005 D3); `got_through`, `got_through_by_type()` (0006 D9); `_dealt_by_id` (0009 D5).
- String `connect("signal", obj, "method")`: use `signal.connect(callable)`, here only via `Wiring.connect_recorded()`.
- `$NodePath` in `_process()`: cache an `@onready var`.

### Cross-Cutting Constraints

**GDScript 4.7 rules** (ADR-0007 Decision 9)
- R1: an override of a typed method returns that type on every path; `int`, `float`, `bool` never `return null` (F4). [0007 D9; 0001 G18; 0002 G16; 0004 G14; 0005 G17]
- R2: to change one element of a packed-array property whose setter must run, assign the whole array, not `arr[i] = v` (F1). [0007 D9]
- R3: state a lambda changes lives in an `Array`, `Dictionary` or member, never a captured local (F2); `confusable_capture_reassignment` = 2; `directory_rules` stays default. [0007 D9, A11-04]
- R4: a new battle or resolver signal gets its `battle_signals.gd` row in the same change; fakes check each argument; never trust declared types at runtime (F3). [0007 D9; 0006 G7; 0008 G15]
- R5: a rest parameter is `...name: Array` or untyped, last. R6: helpers load by `const X := preload(...)`. [0007 D9]
- N1: `var w: WeakRef = weakref(x)`, never `:=`. N2: never name a variable `log`. `@abstract` methods have no body. [0007 D9; current-best-practices.md]

**Architecture and process**
- Dependency injection, never singletons. Gameplay values live in the catalogue or their input owner, never in `ViewStyle`. [0001 G1; 0011 D9]
- No lint suppression; a real exception changes the ADR or `scopes.gd`. [0007 D6]
- A fresh clone runs `"$GODOT" --headless --path . --import` first; neither it nor `--quit-after` is a parse check. [0007 D1]
- Filter GDScript with `rg --glob "*.gd"` (Grep `glob: "*.gd"`), never `--type gdscript`. [current-best-practices.md]
- A player-observable story closes only with a screenshot kept in `production/qa/evidence/`. [0007 D8]

### Lint Index (ADR-0007 Decision 6)
Entries split by `|` read `number kind+when fails-on`; scope is `src/` unless named. Kind: T token, C code, S settings, X scene, A alias, R review, D deferred. When: 1 before the first Logic story, 2 the first sim story, 3 with the file's story.

- **L-LAYER**: 1 C1 higher-layer class or `res://src/` path | 2 C1 a `src/root/` class outside root | 3 C3 `enemy_wave/`, `tower/`, `hero/` naming each other | 4 T1 `res://tests/`, `res://addons/`, `res://tools/`, `GdUnit`.
- **L-APP**: 1 S1 any autoload; `run/main_scene` not `app_root.tscn` | 2 T3 `.connect(` outside `wiring.gd` and named engine-node files | 3 T3 lambda or `.bind(` in Builder, wrapper | 4 T3 `.free()` in `src/root/` | 5 T3 `assert(` | 6 T3 assigning tree `paused` | 7 T3 `get_tree().create_tween(`, `create_timer(` | 8 S1 `gui/theme/custom`, `custom_font` set.
- **L-DATA**: 1 T3 `DirAccess` | 2 C3 record field write or list mutation outside `foundation/data/`.
- **L-INPUT**: 1 T3 `_input`, `_unhandled_input` outside adapter; `_gui_input` outside `tap_screen.gd` | 2 X3 Control not IGNORE (TapScreen: STOP); `focus_mode` not NONE; full-rect wrapper root | 3 T3 `device == 0`, `device != 0` | 4 T3 `Camera2D`, also in `.tscn` | 5 T3 `get_display_safe_area(` outside the wrapper | 6 C3 gesture calls outside adapter; `cancel(` outside its three callers; `InputResolver.new(` outside its file | 7 T3 `last_trace(`, `GestureTrace`, resolver `state(` outside `foundation/input/`, `presentation/dev/`.
- **L-PROJ**: 1 S1 an ADR-0003 D1 or ADR-0004 G11 key off its value.
- **L-TIME**: 1 T2 `_process`, `_physics_process`, `Timer`, `await`, `Engine.`, `Time.`, `OS.`, input injection in `SIM` | 2 T2 `battle.tick(` outside wrapper; `.tick(` with a literal | 3 C2 `-=` of `dt`, `delta`, `TICK_SECONDS`, `tick_seconds()`.
- **L-RNG**: 1 T2 global RNG, `.shuffle(`, `.pick_random(`, `RandomNumberGenerator.new(` outside `RNG_EXEMPT`; `.randfn(` in `SIM`.
- **L-VEC**: 1 C2 `Vector2` / `Rect2` methods or operators, curve and packed maths, transcendentals in `SIM`.
- **L-STAT**: 1 T3 string or `&"..."` key in `stat_int(` / `stat_float(` | 2 C3 direct `ROWS` field read outside `foundation/data/` | 3 A L-APP-5 for `stat_accessor.gd`, `read_context.gd` | 4 T3 `ReadContext.new(` outside enemy, tower_sim, hero_sim, hud_logic, hero_input.
- **L-SIG**: 1 T3 `emit_signal(`, `connect("`, `add_user_signal(` | 2 T3 `CONNECT_` flags; deferred emit; `await` on a battle signal; `tween_await(` | 3 C3 presentation or wrapper assigning a sim member field | 4 C3 `*_id` typed `String` | 5 T3 sim member or class in ResultScreen, RunLog.
- **L-COMBAT**: 1 T3 `.health`, `.status`, `Health.new(`, `Status.new(` outside `core/combat/` | 2 C3 writing `spawn_id`, `distance`, `x`, `y`, `removed` outside `feature/enemy_wave/` | 3 T3 `DamageEvent.new(` outside `tower_sim.gd`, `hero_sim.gd` | 4 C3 mutating `roster()` / `targets()` outside `enemy_wave.gd`.
- **L-CMD**: 1 C3 a command called outside its owner file | 2 C3 `if`, `not`, `and`, `or` before a command call; bare `OK` beside a result.
- **L-DEV**: 1 T3 `FileAccess` in `presentation/dev/` but `jsonl_file_sink.gd`, in `SIM` but `FILE_EXEMPT`.
- **L-HERO**: 1 T2 `hero_sim`, `HeroSim` outside `feature/hero/` and three root files.
- **L-VIEW**: 1 T3 `Tween`, `create_tween(`, material, `z_index`, `CanvasLayer`, `Light2D`, particles, `Label` in field, hud | 2 T3 `Time.` there (probe apart).
- **L-NAME**: 1 C1 `class_name` clashing with an engine or global class | 2 T1 any `class_name` in `tests/`, `tools/`.
- **L-GD**: 1 D `arr[i] = v` on a property with a setter.
- **L-TEST** (`tests/`): 1 T1 `assert_signal(`, `monitor_signals(`, `set_time_factor(`, `create_timer(`, global RNG | 2 T1 file, manifest, scene or `get_tree()` in `tests/unit/` | 3 R weakref target passed to an assert first | 4 C1 suite not `*_test.gd`; public non-`test_` function | 5 T1 `assert_error(` with no `await`.

Scopes (`tools/ci/lint/scopes.gd`): `SIM` = `src/foundation`, `src/core`,
`src/feature`; `RNG_EXEMPT` = `battle_builder.gd`, `battle_wrapper.gd`;
`FILE_EXEMPT` = `src/foundation/data/catalogue.gd`. Full token lists: ADR-0007
Decision 6.

---

## Open Items

Each item says whether it needs an ADR amendment. None does now.

**Closed 2026-11-05:**
1. `FileAccess` in Foundation: fixed by the ADR-0002, ADR-0007, ADR-0010 amendments (`FILE_EXEMPT`). No amendment needed.
2. Test command: `commands.test`, `current-best-practices.md` and `test-run.sh` carry the 4.7.2 form; `run_tests.sh` replaces it later. No amendment needed.
3. `max` in a typed result: fixed by the ADR-0010 and ADR-0004 amendments. No amendment needed.
4. Flow's Callable targets: fixed by the ADR-0001 amendment. No amendment needed.

**Left out** (no amendment): the 3D, audio and rarely hit 2D rows of
`deprecated-apis.md` (`TileMap`, `yield()` and the rest); add one when needed.
