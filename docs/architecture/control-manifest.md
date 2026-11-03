# Control Manifest

> **Engine**: Godot 4.7.2
> **Last Updated**: 2026-11-03
> **Manifest Version**: 2026-11-03
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005
> **Status**: Active. Regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Stories embed it when
they are written, and `/story-readiness` compares a story's version with this one
to find stories written against old rules. It always equals `Last Updated`: the
same date, for different readers.

This manifest is a programmer's quick reference taken from the Accepted ADRs, the
project config and the engine reference docs. For the reason behind a rule, read
its ADR.

**Not covered yet:** ADR-0006, ADR-0007 and ADR-0008 are Proposed. They wait for
the phone spike. Their rules are not in this manifest.

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
- **`halted()` must reach systems through the shared `HaltLatch`, which `Battle` creates and hands to each system. On Retry the wrapper must call `Battle.dispose()`.** source: ADR-0002
- **Only two places may connect signals. `BattleBuilder.build` connects sim to sim. `BattleWrapper` connects sim to view and the wrapper-only signals of TowerInput and HeroInput.** source: ADR-0002
- **Connections must be written `emitter.signal_name.connect(listener.method)` with a bound method. The builder and the wrapper must hold every emitter and listener in a statically typed variable.** source: ADR-0002
- **A lambda may be connected only if it captures nothing it then writes.** source: ADR-0002
- **No result may depend on which listener of one signal runs first. A sim signal must have at most one sim listener.** source: ADR-0002
- **A read that returns an `Array` or `Dictionary` must return a copy the caller cannot use to write into the simulation. Records returned by reads must be read-only `RefCounted` records, not Dictionaries.** source: ADR-0002
- **A listener must not keep a `DamageEvent`, its `target`, or any `EnemyInstance` after the call returns.** source: ADR-0002
- **The wiring test must derive its covered set from `battle.systems()` and `get_script_signal_list()`. One test per signal must emit it from a fixture and assert the argument types.** source: ADR-0002

### Forbidden Approaches
- **Never add an event-bus or global signal-hub autoload.** Hidden global; breaks headless fixtures and the derived wiring test. registry: `event_bus_autoload`. source: ADR-0002
- **Never let a system connect itself to peers in `_init`.** The dependency graph spreads over many files and the builder can no longer show the whole wiring. source: ADR-0002
- **Never connect a signal by string, such as `connect("name", ...)`.** Deprecated since 4.0; the parser cannot catch a misspelt name. registry: `string_signal_connect`. source: ADR-0002
- **Never depend on the order in which two listeners of one signal run.** Listener order is unverified (S1). registry: `listener_order_dependence`. source: ADR-0002
- **Never use `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT` or `await` on a signal in gameplay code.** Gameplay signals are synchronous. registry: `deferred_or_awaited_gameplay_signals`. source: ADR-0002
- **Never let a battle system hold a reference to `Battle`.** It makes a reference cycle. registry: `system_holds_battle`. source: ADR-0002
- **Never keep a hand-written allowlist of unheard signals in the wiring test.** It goes stale as signals are added. source: ADR-0002
- **Never rename the six existing signals to past tense.** Eight GDDs cite them and a rename changes no behaviour. source: ADR-0002
- **Never emit from a sim system after `halted()` is true, except the two named cases.** source: ADR-0002
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

### Performance Guardrails
- **Catalogue load and validation**: boot only, never during a battle. Proposed device budget 1000 ms, measured on the first phone build. Data files far below 1 MB. source: ADR-0001
- **Catalogue memory**: records only. The parsed plain data must be dropped after the build. source: ADR-0001
- **Accessor read**: one dictionary lookup plus one `Object.get` through a `Variant`. Cost is unmeasured (V4). source: ADR-0001
- **Signal emit**: a direct call per listener, about one listener per sim signal, tens of emits per tick at MVP. source: ADR-0002
- **Read records (`slot_state`, `chip_state`)**: allocate a small object each frame. Acceptable at MVP. If profiling on the phone shows a cost, the fallback is that the owner caches one record per slot and updates it in place; that needs a revision of ADR-0005 section 4 first. source: ADR-0002

### Engine API Constraints
- **Verify on the phone or in the first story:** a JSON file under `res://data/catalogue/` is in an Android and an iOS export with the include filter (V1); a parsed JSON number arrives as `float` (V2); `FileAccess.get_open_error()`, `JSON.get_error_line()` and `get_error_message()` report what the manifest tier needs (V3). source: ADR-0001
- **Typed `Dictionary[K, V]` (4.4) is unverified from the pinned reference.** source: ADR-0002
- **Verify in the first wiring-test story:** listeners run in connection order (S1); `get_script_signal_list()` lists script-declared signals and `get_signal_connection_list(name)` reports connections on a `RefCounted` (S2); typed signal parameters are not checked at `emit` time (S3). source: ADR-0002
- **A typed-return override must end in an explicit `return` (4.7).** Applies to any record or test double that overrides a typed method. source: ADR-0002

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

### Required Patterns

Frame order, commands and ticks (ADR-0003)
- **Only AppRoot must drive simulation time. Its `_process` must call `wrapper.step(delta)`, then run its own end-of-frame latches.** source: ADR-0003
- **The frame order in `step` must stay fixed: (a) chip feed, (b) lifecycle then `battle.apply_queued()`, (c) ticks, (d) outcome step, (e) hero disc, (f) views, (f2) late outcome, (g) `resolver.cancel()` if requested. Then AppRoot runs the Fatal latch first, else the Retry latch.** source: ADR-0003
- **`Battle.DT` must be the constant `1.0 / 60.0`.** source: ADR-0003
- **With the clock running, the wrapper must add `delta` to the accumulator and compute `owed = floori(accumulator / DT)`. If `owed <= 5` it must run `owed` ticks and subtract `owed * DT` from the accumulator. If `owed > 5` it must run 5 ticks and set the accumulator to 0.0. With the clock stopped it must run no tick and set the accumulator to 0.0.** source: ADR-0003
- **`battle.tick` must be called only with `Battle.DT`. Headless callers must call `battle.tick(Battle.DT)` in a loop.** source: ADR-0003
- **`tick` must call `apply_queued()` first. If the clock is stopped it must return after the drain without counting. Otherwise it must run the slot order (StageFlow, WaveSim advance, Status, TowerSim, HeroSim then burst, WaveSim reap), check `halted()` before the first slot and between slots, then increment `tick_count`.** source: ADR-0003
- **The wrapper must call `apply_queued()` every frame, clock running or not, before any tick.** source: ADR-0003
- **Commands must be `BattleCommand` subclasses (`BuildCommand`, `UpgradeCommand`, `PinCommand`, `BurstCommand`, `StartNextWaveCommand`). `BattleCommand` must be `@abstract`.** source: ADR-0003
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
- **Every `BattleCommand.apply` override must end in an explicit `return` of its result code.** source: ADR-0003
- **Debug builds (`OS.is_debug_build()`) must log a clamp drop with `push_warning`, at most once per second.** source: ADR-0003
- **`Engine.time_scale` must stay 1.0.** source: ADR-0003

Test harness and snapshot (ADR-0004)
- **Harness code must live under `res://tests/support/`, with file names that have no `_test` suffix.** source: ADR-0004
- **Tests must drive a battle only through `BattleRig` or its three entry points: `BattleBuilder.build`, `Battle.enqueue`, `Battle.tick(Battle.DT)`.** source: ADR-0004
- **Unit tests must build catalogues with `FixtureCatalogue`. Its helpers must always copy.** source: ADR-0004
- **`Battle` must receive all its parts in one `BattleParts` record through `_init(parts)` and run an ordered list of `TickSlot` objects. Production code must construct `Battle` only in the builder.** source: ADR-0004
- **A `Battle` with `flow == null` must treat the clock as running.** source: ADR-0004
- **Every battle system in `systems()` must implement `snapshot() -> Dictionary` and declare `SNAPSHOT_EXEMPT` (even `[]`).** source: ADR-0004
- **Every `snapshot()` must follow ADR-0004 section 5: first key `"system"`; values only `bool`, `int`, `float`, `String`, `Vector2`, `Array`, or `Dictionary` with `String` keys; a deep copy; sets and maps as ordered `Array`; ints stay `int`; keys are member names without a leading `_` (renames only through `SNAPSHOT_KEYS`).** source: ADR-0004
- **A holder must embed state another system owns only through that owner's formatter.** source: ADR-0004
- **Snapshots must be compared with `SnapshotTool.diff`. Floats must be compared exactly.** source: ADR-0004
- **A replay must compare the log record by record (`tick`, `kind`, `args`, `result`), then compare `SnapshotTool.take` of both battles.** source: ADR-0004
- **A run loop must have a `max_steps` limit. A TIMEOUT must fail the test and must never be read as Lost.** source: ADR-0004
- **The only randomness must be the injected `seed` in `RigOptions`. A test that needs variety must loop over a fixed list of seeds. Tests that touch the chip must pass a fake `RealClock`.** source: ADR-0004
- **Seconds must become ticks in tests only through `ticks_for`.** source: ADR-0004
- **The token scan must derive its covered set from the live scripts of `Battle`, `BattleBuilder` and `battle.systems()`.** source: ADR-0004
- **A test that creates a `Node` must wrap it in `auto_free(...)` or give it to the scene runner.** source: ADR-0004
- **CI must pass only on exit 0. Exits 100, 101, 103, 105 and 1 must fail, and `No test cases found` must fail the step. CI must run `--import` first (retried once), then the parse check on `tests/support/`, then the gdUnit4 command. `tests/unit/harness/canary_test.gd` must always exist.** source: ADR-0004
- **A baseline must hold only integers, be stored per architecture, and fail when missing.** source: ADR-0004
- **Every harness check must have a meta test that shows it failing.** source: ADR-0004
- **Bots must read only what a view reads and must build commands.** source: ADR-0004
- **The wrapper must build its input pieces through one function that loads no stage scene and creates no `InputAdapter` or views (for example `InputAssembly.build(battle, catalogue, clock)`). This is a requirement on ADR-0008.** source: ADR-0004
- **`SignalTap` must attach only to signals in a system's `VIEW_SIGNALS`.** source: ADR-0004
- **Every `decide` and `run` override must end in an explicit `return` where it has a return type.** source: ADR-0004
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
- **Every override must end in an explicit `return` (4.7).** source: ADR-0005
- **The builder must create objects in this order: `TickConverter`, `Combat`, `WaveSim`, `TowerSim`, `HeroSim`, `StageFlow`. This is a requirement on ADR-0008.** source: ADR-0005
- **The ownership scan test, the HP conservation test and the no-bypass test must exist and pass.** source: ADR-0005

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
- **Never import from `tests/` in production code.** registry: `src_depends_on_tests` (named in ADR-0004, not in the registry list checked here). source: ADR-0004
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
- **Never use `assert` for checks.** source: ADR-0005
- **Never rely on `Array.make_read_only()`.** Its behaviour on 4.7.2 is not sourceable. source: ADR-0005
- **Never keep an attacker's target between attacks.** It goes stale after a reap. source: ADR-0005
- **Never let `Combat` hold StageFlow or any other system.** It would form a cycle. source: ADR-0005
- **Never declare a setter on a packed-array property in a sim class.** source: ADR-0005
- **Never store HP and slow outside the enemy components (no flat fields, no Dictionaries, no parallel packed arrays, no Combat tables keyed by `spawn_id`).** source: ADR-0005
- **Never add a spawner behind `deliver` now.** `ProjectileSpawner` is cut. A projectile system later is a new slot that calls the same `deliver`. source: ADR-0005
- **Never rely on list position or a non-strict comparator for ties.** source: ADR-0005

### Performance Guardrails
- **Tick**: 2 ms per tick on the target phone (proposed). Five catch-up ticks are at most 10 ms of the 16.6 ms frame. If the phone spike fails it, the cap must drop, not the tick rate. source: ADR-0003
- **Commands**: a handful per frame, one small object each. source: ADR-0003
- **Command log**: a few hundred small records per stage, in memory in every build. File writes are deferred to the Mobile Platform ADR. source: ADR-0003
- **Roster copies**: about 2 `targets()` copies and 1 `roster()` copy per tick, at most 48 elements each (E = 48, S = 5). Estimated, unmeasured. The first WaveSim story must measure it. Above 10% of the 2 ms tick, the fallback is a sealed shared array. source: ADR-0005
- **Sim objects**: 48 enemies x 3 objects, plus 5 tower and 1 hero instance. Negligible. source: ADR-0005
- **Harness**: a full snapshot of 48 enemies is about 5 KB (estimate). A 36 000-tick per-tick full trace is about 180 MB (estimate) and is not allowed. The bot suite CI time budget is set at the first baseline. source: ADR-0004
- **Snapshots** run in tests only. source: ADR-0004

### Engine API Constraints
- **`@abstract` (4.5) is used for `BattleCommand`, `BattleBot` and `TickSlot`. 4.7 typed-return overrides need an explicit `return`.** source: ADR-0003, ADR-0004
- **`Time.get_ticks_msec()` replaces `OS.get_ticks_msec()`. `RealClock` wraps it.** source: ADR-0003
- **Verify on the phone spike (GF5):** `_input` order versus `_process` (F1); `Time.get_ticks_msec()` is monotonic across a focus loss on Android and iOS (F2); `_process(delta)` after a long stall returns the real elapsed time (F3); the `BattleCommand` to `Battle` to `Array[BattleCommand]` `class_name` cycle parses with `@abstract` (F4). source: ADR-0003
- **gdUnit4 6.2.2 is post-cutoff.** Unverified from the reference (H1 to H7): gdUnit4 ignores non-suite scripts under `res://tests/` (if wrong, move support to `res://tests_support/`); suite API names other than `auto_free`; `Script.get_script_property_list()` with `PROPERTY_USAGE_SCRIPT_VARIABLE`; `weakref()` timing for `RefCounted` and `Node`; method `Callable` versus lambda and `.bind()` references; `FileAccess`, `DirAccess` and `Script.resource_path` under `--headless -s`; the call that names the CPU architecture. source: ADR-0004
- **Typed `Dictionary[K, V]` (4.4) is used for `_ctx`, `_got_through`, `_dealt`, `_kind`.** source: ADR-0005
- **4.7: writing one element of a packed array no longer calls the property setter.** No sim class may put a setter on a packed-array property. source: ADR-0005
- **Unverified (V1 to V7), checked by the first WaveSim and Combat stories:** `make_read_only()`; `RefCounted` cycles and `weakref`; `Dictionary` order and `==`; `Array.duplicate()` keeps the type; `floori` and `is_finite`; typed `Dictionary` `erase` and `duplicate()`; `Array.sort_custom` is not stable and `StringName` order may differ from text order. source: ADR-0005

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

No Accepted ADR governs this layer yet.

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

### Required Patterns
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

### Forbidden Approaches
- **Never let a view call a sim command directly. Use `Battle.enqueue`.** registry: `direct_sim_command_from_input`. source: ADR-0002, ADR-0003
- **Never let a view write to the simulation.** Systems also never use view reads to reach each other. source: ADR-0002
- **Never connect a view to anything outside `BattleWrapper`.** source: ADR-0002
- **Never use `_process` or read engine time in HUD logic or input pieces.** The chip reads only the injected `RealClock`. registry: `engine_time_outside_driver`. source: ADR-0003
- **Never write to the simulation from a view's `_process`.** It reads only. source: ADR-0003
- **Never hold an `EnemyInstance` or `Array[EnemyInstance]` as a view member.** registry: `enemy_reference_members`. source: ADR-0005
- **Never keep a `DamageEvent` or its `target` after the listener returns.** The target may be reaped. source: ADR-0002, ADR-0005
- **Never re-connect a new view into a freed battle on Retry.** The wrapper drops the old battle and views and wires the new ones. source: ADR-0002
- **Never tap a sim-only signal from a view.** source: ADR-0004

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
- `event.device == 0` to detect mouse or keyboard: check `event is InputEventMouse` or `InputEventKey`, or use `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (4.7). source: deprecated-apis.md
- Installing addons from the editor's AssetLib tab: use the Asset Store workspace (4.7). source: deprecated-apis.md
- If the UI shows `RichTextLabel` images: `ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` becomes `UPDATE_WIDTH_UNIT`, and `add_image()` / `update_image()` take `width_unit` / `height_unit` (`RichTextLabel.ImageUnit`) in place of `width_in_percent` / `height_in_percent` (4.7). source: deprecated-apis.md

Left out as 3D-only (not rules for this 2D project): `GodotPhysics3D` to Jolt, `Navigation3D`, `Skeleton3D` `bone_pose_updated`, `VisibilityNotifier3D`, `get_world()`.

Left out and unresolved (not named for this project, not judged): `EditorSceneFormatImporterFBX`, `AnimationPlayer.method_call_mode` and `playback_active`, `DisplayServer.AccessibilityLiveMode`, `AudioEffectSpectrumAnalyzer.tap_back_pos`, `EditorSceneFormatImporter.IMPORT_*`, `Texture2D` in `Shader.set_default_texture_parameter()`, manual post-process viewport chains.

### Cross-Cutting Constraints
- **Typed-return overrides must end in an explicit `return` in 4.7.** The migration fix is `return null`. source: current-best-practices.md
- **Lambdas capture locals by value.** A lambda cannot reassign an outer local. Share state through a Dictionary, an Array or an object and mutate its contents. source: current-best-practices.md
- **Writing one element of a packed array (`arr[i] = v`) no longer calls the property's setter in 4.7.** Assign the whole array where a setter must run. source: current-best-practices.md
- **`@abstract` methods must have no body, and subclasses must override them.** source: current-best-practices.md
- **Code must never use `assert` for runtime checks of data or calls.** Use `if` and the injected failure handler or `dev_error`. source: ADR-0001, ADR-0005
- **No autoloads and no event bus. The builder injects every dependency.** source: ADR-0001, ADR-0002
- **Public classes and methods must carry doc comments.** source: ADR-0001
- **Determinism must hold: the simulation uses fixed `Battle.DT` ticks and an injected seed, and never real time.** source: ADR-0003, ADR-0004
