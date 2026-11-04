# TowerRiot: Master Architecture

## Document Status

- Version: 2
- Last Updated: 2026-11-04
- Engine: Godot 4.7.2 (GDScript, Mobile renderer, 2D, portrait 540 x 960 field)
- GDDs Covered: design/gdd/data-config-pipeline.md, input-gesture-resolver.md, game-state-stage-flow.md, combat-damage.md, enemy-wave.md, tower-system.md, hero-system.md, battle-hud.md (8 of 8 MVP systems; all In Review, with no blocking issue left in the cross-GDD review of 2026-11-04)
- ADRs Referenced: ADR-0001 to ADR-0014, all written 2026-11-04 and all Proposed. Each lists engine checks that block its acceptance; see `production/qa/engine-verification-plan.md`.
- TR registry: `/architecture-review` (2026-11-04) registered 74 permanent IDs in `docs/architecture/tr-registry.yaml`: the 70 below kept their numbers, and it added TR-input-008, TR-wave-010, TR-wave-011 and TR-hud-014. The registry and `requirements-traceability.md` are the authority now; the "(provisional)" tags in the baseline table are historical.
- TD-ARCHITECTURE: CONCERNS on version 1 (2026-11-04), no blocker. All eight issues are addressed in version 2: a Composition tier, a ShellBuilder, commands on the Battle facade, one name per command, owners for `to_ticks`, the seed, the view pool, the gesture log and lifecycle, four unsourced claims withdrawn, recounted TR coverage, and ADR order, split and a performance budget. QQ-07 accepted with conditions (see Open Questions).
- LP-FEASIBILITY: CONCERNS on version 1 (2026-11-04), no blocker. All ten issues are addressed in version 2: typed `EnemyState`, `HitTarget` and `SlotState`, typed catalogue reads, an injected `HaltState` that breaks the FlowSim and EnemyWave cycle, the `Phase` enum, full signatures and supporting types, a `BattleReadModel` base for fakes, logic moved out of nodes into plain classes, `Vector2` precision stated, and a re-entrancy default.
- Version 2 has not been re-reviewed. `/architecture-review` is the next check.

## Engine Knowledge Gap Summary

Engine: Godot 4.7.2. The model's training covers Godot up to about 4.3, so 4.5, 4.6 and 4.7 are all post-cutoff. This game is 2D, mobile, single-thread and uses no physics server (every hit test is a distance check, Flow Rule 4 bans physics areas), no audio at MVP, no navigation, no networking and no 3D. That removes most of the HIGH-risk surface. What remains:

| Domain | Risk | What changed | Where this game touches it |
|---|---|---|---|
| GDScript (Core) | HIGH | 4.5 variadic arguments and `@abstract`; 4.7 an override of a method with a typed return now inherits that return type and needs an explicit `return`; 4.7 writing one element of a packed array no longer calls the property setter | Every module is GDScript. Base classes with typed returns need care. Typed signals and typed arrays are mandatory (deprecated patterns table) |
| Input | HIGH | 4.7 mouse and keyboard events report `DEVICE_ID_MOUSE` and `DEVICE_ID_KEYBOARD`, not device 0; 4.6 dual focus | InputAdapter must classify events by type, never by `device == 0`. Touch is the primary input; mouse emulates it on desktop |
| UI | HIGH | 4.6 dual focus (touch focus separate from keyboard focus); 4.5 recursive disable of mouse and focus on a Control hierarchy; 4.7 new projects stretch by default | Modal screens and the top band are Controls. `focus_mode` NONE on modals, `mouse_filter` IGNORE on the top band |
| Rendering (2D canvas) | HIGH | 4.7 `CanvasItem` lines are drawn without an antialiasing feather, so they look thinner | All field art is `_draw` primitives with 2 px and 3 px strokes. Widths need a device check. Renderer is Mobile (the reference calls Forward+ desktop-focused) |
| Project settings | HIGH | 4.7 new projects default to `stretch/mode` canvas_items and `stretch/aspect` expand. The 4.7 change writes those values into newly created `project.godot` files; the setting defaults in the 4.7.2 class reference (`ProjectSettings.xml`) stay `disabled` and `keep`. `project.godot` sets no stretch key today, so this project currently runs with no stretch at all. ADR-0008 writes `canvas_items` and `keep` explicitly | The 540 x 960 field on taller phones. Expand shows area outside the field, which Enemy & Wave requires masked (ADR-0008) |
| Animation | MEDIUM | 4.7 `Tween.tween_await()` | Presentation tweens only (120 ms and 200 ms motions) |
| Physics, Audio, Navigation, Networking | n/a | not used | `project.yaml` and the technical preferences name Godot Physics 2D; `project.godot` sets no physics key. No physics body, area or server call exists in the design |

**NOT SOURCEABLE.** The pinned engine reference does not cover the items below, and the GDDs already list most of them as ADR work. They are written here as gaps, not filled from memory, and each gap makes the dependent decision `Proposed` until its ADR cites the live 4.7 documentation or a device run:

- NOT SOURCEABLE: lifecycle notifications on each platform (`NOTIFICATION_APPLICATION_*`, `NOTIFICATION_WM_*`), which of them enters Paused, and desktop focus-out behaviour in the editor and exports. Not covered by docs/engine-reference/godot/.
- NOT SOURCEABLE: whether Paused uses the engine's tree pause and `process_mode`, or only Flow's own early return. It follows that whether the InputAdapter needs `PROCESS_MODE_ALWAYS` to keep receiving events while Paused is also open (ADR-0002, ADR-0006).
- NOT SOURCEABLE: where the fixed tick accumulator lives (`_process` or `_physics_process`), `Engine.physics_ticks_per_second`, `max_physics_steps_per_frame`, and `Engine.time_scale`.
- NOT SOURCEABLE: input path ordering: `_input` against `_unhandled_input` against `Control._gui_input`, and whether a Control with `mouse_filter` STOP hides an event from the adapter.
- NOT SOURCEABLE: touch and mouse emulation settings, and the `canceled` flag on `InputEventScreenTouch`.
- NOT SOURCEABLE: `queue_free` against `free` timing, `weakref` and `is_instance_valid` timing, and freed-object Callables.
- NOT SOURCEABLE: safe-area query and conversion to field units (`DisplayServer`), and the stretch and aspect behaviour on taller phones.
- NOT SOURCEABLE: `FileAccess` flush and close behaviour for the debug log on mobile.
- NOT SOURCEABLE: draw-call batching for one `_draw` node against the budget of 8 expected and 12 at most.

Because the GDDs also state these from memory, the whole group is routed to ADR-0002, ADR-0003, ADR-0006, ADR-0008 and ADR-0012, each of which must verify against live 4.7 documentation and a phone run before it is Accepted.

**Stated, not a gap.** `Vector2` holds 32-bit floats in default (single-precision) builds, as it has since Godot 4.0, while a GDScript `float` scalar is 64-bit. So the 64-bit pin-clamp rule cannot hold on `Vector2` fields: `PinGeometry` and the targeting compares keep scalar `float` and convert at the boundary.

## System Layer Map

The five-layer model applies with one addition that this game needs: every module is either **sim** (plain objects with no scene tree, runs headless under bots and tests) or **shell** (nodes, Controls and drawing, absent headless). The sim never references the shell. This is the rule the GDDs lean on most (Flow Rules 2 to 4, Tower and Hero "two pieces", HUD Rule 1), so it is the first principle below and the subject of ADR-0001.

```
 COMPOSITION    SIM     BattleBuilder (wires one battle)
                SHELL   AppRoot (main scene, no autoload)   ShellBuilder (wires input, HUD, views)
 ---------------------------------------------------------------------------------------------
 PRESENTATION   SHELL   HudTopBand  HudField  Modal screens (Result, Paused)  FieldView (+ enemy pool)
                        TowerView  HeroView  CombatView  FatalScreen  HumanLog  GestureLog
                SIM     HudLogic, HudArcModel (plain, tested with fakes of BattleReadModel)
 ---------------------------------------------------------------------------------------------
 FEATURE        SIM     EnemyWave        TowerSim          HeroSim
                        (plain)          ChipWindow        PinGeometry  AimModel
                SHELL   (none)           TowerInput        HeroInput           (thin node adapters)
 ---------------------------------------------------------------------------------------------
 CORE           SIM     FlowSim          Combat            InputResolver*      FixedStepClock
                SHELL   BattleWrapper (calls the clock)    InputAdapter
 ---------------------------------------------------------------------------------------------
 FOUNDATION     SIM     Catalogue (Loader, Validator, StatAccessor)   SimTime (to_ticks, seed)
                        HaltState   BattleReadModel (abstract)   shared types (EnemyState ...)
 ---------------------------------------------------------------------------------------------
 PLATFORM        Godot 4.7.2 (Mobile renderer, 2D), Android and iOS, desktop for development
```

\* InputResolver is a plain object but is built only by the ShellBuilder, so headless bots never see it (Input Rule 11).

**Why a Composition tier.** Version 1 put AppRoot and BattleBuilder in Foundation and then made an exception to rule 1 for them. The technical director's review rejected that: they reference every layer, and AppRoot owns the fatal screen and presentation flags. They now sit above Presentation, where depending on everything below is the normal rule, not an exception. Foundation holds only what everything else may read: the catalogue, time conversion, the halt state and the shared types.

**Layer assignment, with the reason for each.**

| System (index #) | Layer | Reason | Engine risk touched |
|---|---|---|---|
| Data & Config Pipeline (1) | Foundation | Everything reads it; it depends on nothing but the engine's file API | GDScript typing (HIGH) |
| Game State & Stage Flow (3) | Composition for AppRoot and BattleBuilder; Core for FlowSim; Foundation for SimTime and HaltState | The systems index calls it Core. The composition root references every layer, so it sits on top; the phase machine and lives are Core; `to_ticks`, the seed and the halt flags are read by everything, so they sit at the bottom. One GDD, three layers | Lifecycle notifications, pause, fixed tick (NOT SOURCEABLE) |
| Input & Gesture Resolver (2) | Core | Turns touches into gestures for Feature and Presentation owners | Input (HIGH), device IDs, dual focus |
| Combat & Damage (4) | Core | One damage path that both Feature systems call; reads no data and depends only on Foundation (`HaltState` for `in_tick()`, `EnemyState`) | GDScript only |
| Enemy & Wave (5) | Feature | Gameplay: stage, roster, spawning, movement | GDScript only |
| Tower System (6) | Feature | Gameplay: towers and gold | Input for TowerInput |
| Hero System (7) | Feature | Gameplay: pin and burst | Input for HeroInput |
| Battle HUD & Build UI (8) | Presentation | Draws and sends commands; owns no game state | UI (HIGH), Rendering (HIGH), stretch (HIGH) |

The systems index lists Combat under the Gameplay category. The architecture puts it in Core because Tower, Hero and Enemy & Wave all call it and it calls none of them. The category is a design grouping; the layer is a dependency rule.

**Dependency rules.**

1. A module may depend on modules in its own layer or below, never above.
2. Sim modules never depend on shell modules. Shell modules read sim state and send commands, and never write it.
3. Within Feature, EnemyWave, TowerSim and HeroSim do not call each other. They meet through Combat (damage), the roster that EnemyWave exposes (`targets()`), and signals the builder wires.
4. A lower layer may emit a signal that a higher layer listens to, and a higher layer may emit one a lower layer listens to, but only BattleBuilder makes the connection. The listener's class never names the emitter's class. This is how FlowSim (Core) hears EnemyWave (Feature) without depending on it.
5. Nothing reads `halted()`, `in_build()` or `in_tick()` from FlowSim directly. FlowSim writes a `HaltState` object (Foundation) that BattleBuilder injects into every system. This breaks the FlowSim and EnemyWave cycle that version 1 had.
6. BattleBuilder and ShellBuilder only wire. A branch on a gameplay value inside either is a defect (Flow Rule 3), checked in code review.

**Alternatives considered.** (a) A single autoload event bus for all cross-system messages: rejected by the GDDs (Flow "Deliberately not built") because an unconnected signal becomes a silent bug and tests cannot isolate systems; explicit connections in one builder function give the parser a chance to catch a misspelt name. (b) A scene-owned battle root as the technical director's note first said: rejected in Flow Rule 2 because a scene-owned root cannot run headless, and bots measure the game. (c) Treating the sim and shell split as a convention only: rejected, because without a test that the sim loads with no scene tree the split decays. ADR-0001 adds that test.

## Module Ownership

### Composition

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| AppRoot (main scene) | The Ready catalogue, the retry latch, the Fatal latch, the fatal screen, the presentation session flags (`pinned_once`, `built_once`, `won_once`), the Retry-to-Start timer. **The single receiver of lifecycle notifications**: on focus loss it calls `adapter.cancel()` and `battle.pause()` | Starts the load, builds and frees battles | Catalogue, BattleBuilder, ShellBuilder | `Node`, scene tree notifications and free timing (NOT SOURCEABLE) |
| BattleBuilder | Wiring of one battle | `build(catalogue, stage_id, seed, fatal_handler) -> Battle` | Catalogue and every sim module | none: plain `RefCounted` |
| ShellBuilder | Wiring of the shell around one battle: InputResolver, InputAdapter attach, TowerInput, HeroInput, AimModel, HudLogic, HUD nodes, views, BattleWrapper | `build(battle, catalogue, session_flags: SessionFlags, parent: Node) -> Shell`; `Shell.dispose()` (not `free()`, which would override `Object.free`) | Battle, Catalogue | `Node` creation and freeing |

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Catalogue | Every authored gameplay record (Tower, Enemy, Wave, Stage, Hero, Burst, Input), read-only after load | `read_int`, `read_float`, `read_bool` `(ctx, key)`, `level_count(def_id)`, `is_tower(id)`, `stage(id)` | A `TextSource` (injected) for the files the manifest names | `FileAccess` only inside the real `TextSource`, typed `Array` and `Dictionary` (HIGH: GDScript) |
| CatalogueValidator | The error list `CatalogueError{code, source, record_id, field}` | `validate(records) -> Array[CatalogueError]` | Records | none |
| SimTime | The tick length (1/60), `to_ticks(seconds)`, the injected seed | `DT`, `to_ticks(s) -> int`, `seed() -> int` | Nothing | none |
| HaltState | The three flags read by every system | `halted()`, `in_build()`, `in_tick()`; written only by FlowSim and Battle | Nothing | none |
| BattleReadModel | The read-only view of a battle, as an `@abstract` base class (4.5+) | Every read HudLogic and views need (lives, gold, phase, slots, hero, roster) | Nothing | `@abstract` (HIGH: 4.5; every override needs an explicit typed `return` under the 4.7 rule) |
| Shared types | `EnemyState`, `DamageEvent`, `ReadContext`, `StageRecord`, `SlotState`, `HitTarget` | See API Boundaries | Nothing | none |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| FlowSim | Phase (`enum Phase`: BUILD, WAVE, INTERMISSION, PAUSED, WON, LOST, FATAL), lives, `intermission_left`, the outcome latch; writes `HaltState` | `tick()`, `start_wave()`, `call_early()`, `pause()`, `resume()`, `on_enemy_leaked`, `on_wave_cleared`, `on_waves_complete`; signals `phase_changed`, `lives_changed`, `wave_called_early` | Stage record; EnemyWave signals connected by the builder; `EnemyWave.start_next_wave` as an injected Callable | none |
| Combat | Health and Status per enemy, the damage counters, the targeting helpers | `deliver`, `apply_slow`, `report_attack`, `first_in`, `nearest_in`, `all_in_radius`, `hp_left`, `is_dead`, `speed_factor`, `tick_status`, `dealt_by_id`, `dealt_by_kind`; signals `attack_fired`, `damage_applied` | `HaltState` (for `in_tick()`); callers pass every value in | none |
| InputResolver | The target registry, the single active pointer, the two frozen winners | `press`, `move`, `release`, `cancel`, `cancel_pointer`, `register`, `unregister`; signals `pressed`, `tap`, `ground_tap`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `idle` | Input record (two slops, injected) | none: plain object |
| FixedStepClock | The real-time accumulator and its clamp, as a plain class | `advance(real_seconds) -> int` (ticks owed), `reset()` | `SimTime.DT` | none: tested headless |
| InputAdapter (shell) | The mapping from engine events to the resolver's five calls, the edge reject margin | `attach(resolver)`, `cancel()` (called by AppRoot) | `InputEvent` stream | `InputEventScreenTouch`, `InputEventScreenDrag`, `InputEventMouseButton`, `DEVICE_ID_MOUSE` (HIGH, 4.7); `process_mode` while Paused is open (ADR-0002, ADR-0006) |
| BattleWrapper (shell) | Nothing but the frame hook: it asks `FixedStepClock` how many ticks are owed and calls `battle.tick()` that many times | none | Battle, FixedStepClock | `_process` (or `_physics_process`, NOT SOURCEABLE), `Engine.time_scale` |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| EnemyWave | The stage geometry in use, the wave index, the spawn schedule, the roster of `EnemyState`, `spawn_id`, leaks, reaping, per-wave clearing | `start_next_wave()`, `roster()`, `targets()`, `wave_index()`, `got_through_by_type()`, `advance()`, `reap()`; signals `enemy_killed`, `enemy_leaked`, `wave_cleared`, `waves_complete` | Catalogue (Wave, Stage, Enemy), Combat (Health, Status), `HaltState`, `SimTime` | none |
| TowerSim | Gold, slot states, tower instances, attack timers | `build`, `upgrade`, `gold()`, `slot_state()`, `tick()`, `on_enemy_killed`, `on_wave_called_early`; signals `gold_changed`, `tower_built`, `tower_upgraded` | Catalogue, Combat, `targets()` as a Callable, `HaltState`, `SimTime` | none |
| HeroSim | Pin, position, walk, attack and burst timers, counters | `pin`, `burst`, `position()`, `pin_target()`, `pin_state()`, `burst_state()`, `cooldown_left()`, `tick()`; signals `hero_pinned`, `burst_started` | Catalogue, Combat, `targets()` as a Callable, `HaltState`, `SimTime`, PinGeometry | none |
| ChipWindow | The 200 to 1500 ms upgrade window and the chip state | `advance(ms)`, `open`, `close`, `elapsed`, `state()` | Nothing | none: plain class |
| PinGeometry | Pin validity and `clamp_pin` | `is_valid`, `clamp` | Stage shapes | none: plain class, scalar `float` fields |
| AimModel | Aim state, cancel hysteresis (64 and 48), the shared aim-point function, the kill preview, the cooldown digit | `aim_state()`, `aim_point()`, `aim_ring_radius()`, `preview_kills()`, `cooldown_digit()`, `update(hero, roster, finger)` | HeroSim reads, Combat helpers, Stage shapes | none: plain class |
| TowerInput (shell) | Tower and slot target registration only, and the chip disc while the window is open | forwards `slot_tapped`, `tower_inspected`; calls `TowerSim.upgrade` on a chip commit | InputResolver, ChipWindow, TowerSim, FlowSim `phase_changed` | `Node` (thin adapter) |
| HeroInput (shell) | Hero and burst button registration only | forwards resolver gestures to AimModel; calls `HeroSim.pin` and `burst` | InputResolver, AimModel, HeroSim | `Node` (thin adapter) |

Two shell callers reach TowerSim on purpose: HudLogic calls `build` (from the arc) and TowerInput calls `upgrade` (from the chip). This is not a duplication to merge. Both TowerInput and HeroInput get an equivalence test: a resolver-driven script and a direct-command script must give the same battle.

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| HudLogic | Arc model, armed buttons, prompt choice, session-flag reads, result text, the human-log records | Plain methods; `advance(ms)` | A `BattleReadModel` (tests pass a fake subclass) | none |
| HudTopBand | Lives, pips, gold, next-wave line, prompt row | none | HudLogic | `Control`, `Label`, `mouse_filter` IGNORE (HIGH: UI) |
| HudField | The arc, chip, Start/Call, burst button art, ground rings; their Input discs | none | HudLogic, InputResolver | `CanvasItem._draw`, `queue_redraw`, `draw_string` (HIGH: line thickness in 4.7) |
| Modal screens | Result and Paused | Retry, Play again, resume | HudLogic | `Control`, `mouse_filter` STOP, `focus_mode` NONE (HIGH: dual focus) |
| FieldView, TowerView, HeroView, CombatView | Path, slots, enemies, towers, hero, lines, flashes, range rings, kill preview. **FieldView owns the 48-enemy view pool** | none | `BattleReadModel` and the view-allowlist signals | `CanvasItem._draw` |
| FatalScreen | The generic failure text, which uses no catalogue data | none | A cause string | `Control` |
| HumanLog | `user://run_log.jsonl`, debug builds only | `record_attempt`, `record_call` | HudLogic snapshot, a `LineWriter` (injected) | `FileAccess` only in the real `LineWriter` (MEDIUM: 4.4 `store_*` return `bool`) |
| GestureLog | The development-build gesture log with the Input Rule 13 fields | `record(gesture)` | InputResolver signals, a `LineWriter` (injected) | as HumanLog |

### Dependency diagram

```
   COMPOSITION   AppRoot ── owns ──▶ Catalogue (read-only)
                    │ builds and frees
                    ├──▶ BattleBuilder ──wires──▶ ┌────────────────────────────────────────────┐
                    │                             │ Battle (sim, headless)                      │
                    │                             │                                             │
                    │                             │  FlowSim ◀─ signals (builder) ─ EnemyWave    │
                    │                             │     │ writes          roster, targets │      │
                    │                             │     ▼                                ▼      │
                    │                             │  HaltState ──read by──▶ every system        │
                    │                             │  TowerSim ──deliver──▶ Combat ◀──deliver── HeroSim
                    │                             └───────────────────────┬─────────────────────┘
                    │                                                     │ BattleReadModel (reads)
                    └──▶ ShellBuilder ──wires──▶ InputAdapter ▶ InputResolver ▶ TowerInput, HeroInput
                                                 HudLogic, HUD nodes, views ◀──────┘
                                                 BattleWrapper ▶ FixedStepClock ▶ battle.tick()
   Commands (between ticks only): HudLogic ▶ Battle.start_wave / call_early / resume / build
                                  TowerInput ▶ Battle.upgrade      HeroInput ▶ Battle.pin / burst
                                  HudLogic (Retry) ▶ AppRoot latch
   Lifecycle: engine notification ▶ AppRoot ▶ adapter.cancel() + battle.pause()
```

Tick order (Combat Rule 11, confirmed by Enemy & Wave and Flow): FlowSim, then EnemyWave advance (spawn, move, leak), Combat status countdown, TowerSim by slot index, HeroSim (hero attack, then burst), then EnemyWave reap (kills, then the clear check). `Battle.tick()` owns that order and no module reorders it.

**Engine awareness check.** Every engine API in the tables was checked against the pinned reference. Verified: typed `Array`, typed signals and `Callable` connections (deprecated-apis patterns), `_draw` and `queue_redraw` (rendering module, with the 4.7 line-thickness change), `Control.mouse_filter` (ui module), `DEVICE_ID_MOUSE` (input module, 4.7), `FileAccess.store_*` returning `bool` (breaking-changes 4.4), `@abstract` (4.5). **Unverified:** whether the 4.5 recursive disable propagates through a top-band `mouse_filter` IGNORE as this design needs; the reference only says it "can propagate", so ADR-0006 must check it on a device. Also not verifiable from the reference: see the NOT SOURCEABLE list above.

## Data Flow

Single thread. Nothing in the sim crosses a thread boundary. The one question is the debug log write (ADR-0014), which runs on the main thread and is flagged there.

### 1. Boot and initialisation order

```
 engine starts ─▶ AppRoot._ready
   1. Catalogue.from_manifest(manifest, text_source, fail)   validate all, collect all errors, fail whole
        └─ failure ─▶ FatalScreen (no catalogue data) ; stop
   2. BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)
        a. SimTime, HaltState
        b. Combat               (HaltState)
        c. FlowSim              (stage record, starting_lives, HaltState)
        d. EnemyWave            (stage, waves, Combat, HaltState, SimTime)
        e. TowerSim             (starting_gold, Combat, EnemyWave.targets as Callable, HaltState)
        f. HeroSim              (hero, burst, Combat, EnemyWave.targets as Callable, HaltState)
        g. connect signals      (one function, explicit Callables); inject start_next_wave into FlowSim
   3. ShellBuilder.build(battle, catalogue, session_flags, parent)
        InputResolver, InputAdapter.attach, TowerInput, HeroInput, AimModel, HudLogic, HUD nodes,
        views, BattleWrapper with a fresh FixedStepClock
   4. first frame
```

Order rule: a module boots after everything it reads. SimTime and HaltState read nothing, so they are first. Wiring (2g) comes after every module exists, so a signal can never fire into a missing listener. A fatal during `build` discards the partial battle without ticking it (Flow Rule 18). The shell is built only after the battle is whole.

### 2. Frame update path

```
 each rendered frame
   InputAdapter (input callback) ─▶ InputResolver.press/move/release
        └─ gestures ─▶ TowerInput / HeroInput / HudLogic handlers
              └─ commands on Battle (build, upgrade, pin, burst, start_wave, call_early) [between ticks]
   BattleWrapper (frame callback): n = FixedStepClock.advance(real_delta) ; repeat n: battle.tick()
              FlowSim ▶ EnemyWave.advance ▶ Combat.tick_status ▶ TowerSim ▶ HeroSim ▶ EnemyWave.reap
   HudLogic.advance(ms) ; AimModel.update ; views read BattleReadModel ; queue_redraw where state changed
```

Data names: input events (producer engine, consumer adapter, synchronous call); gestures (resolver to owners, signal); commands (owners to Battle, synchronous call with a result code); tick (wrapper to battle, synchronous call); sim state (read by views and HUD through `BattleReadModel`, read-only). Commands run before the frame's ticks; this order is unverified and ADR-0002 must check it (HUD Rule 18).

### 3. Event and signal paths

| Event | Producer | Consumers | Kind | Notes |
|---|---|---|---|---|
| `enemy_killed(bounty)` | EnemyWave (reap) | TowerSim | signal, synchronous | Gold is spendable from the next command |
| `enemy_leaked(lives_cost)` | EnemyWave (advance) | FlowSim | signal, synchronous | Fires before `waves_complete`; a fatal leak stops the loop |
| `wave_cleared(seconds)` | EnemyWave (reap) | FlowSim | signal | Payload is the intermission in seconds |
| `waves_complete()` | EnemyWave (reap) | FlowSim | signal | Ignored after a Lost |
| `wave_called_early(seconds_left)` | FlowSim | TowerSim | signal | Bonus paid before the next spawn and before `phase_changed(WAVE)` |
| `phase_changed(p)`, `lives_changed(n)` | FlowSim | HudLogic, TowerInput, views | signal, view allowlist | Emitted after state is committed; `p` is an `int` holding a `FlowSim.Phase` |
| `gold_changed`, `tower_built`, `tower_upgraded` | TowerSim | HudLogic, views | signal, view allowlist | Nothing in gameplay depends on them |
| `hero_pinned`, `burst_started` | HeroSim | HudLogic, views | signal, view allowlist | Handlers never issue commands |
| `attack_fired`, `damage_applied` | Combat | CombatView | signal, view allowlist | Copied positions |
| `pressed`, `tap`, `drag_*`, `ground_tap`, `idle` | InputResolver | owners that registered; GestureLog | signal | Frozen winners per gesture |

Wiring is tested, not trusted: one test fails if any battle signal has no listener unless it is on the view allowlist (Flow, wiring paragraph).

**Re-entrancy (proposed default for ADR-0005).** Battle signals are synchronous and fire inside the advance and reap loops. No listener inside the battle may call a command. Shell listeners may only record state for the next frame; they issue commands from the input call stack, which runs between ticks. A command called while `in_tick()` is true is refused with a development error. This keeps the roster from changing while a loop walks it.

### 4. Gameplay scenarios

**Kill to next wave.** `Combat.deliver` brings HP to 0, then the corpse waits for the reap slot. EnemyWave reaps in ascending `spawn_id`, reads `bounty` through the accessor, removes the corpse, emits `enemy_killed` (TowerSim adds gold, emits `gold_changed`), then runs the clear check. A wave that is clear emits `wave_cleared(15.0)` (or `waves_complete` on the last), FlowSim enters Intermission with `intermission_left = SimTime.to_ticks(15.0)` and emits `phase_changed(INTERMISSION)`, and the HUD arms Start/Call over 300 ms.

**Leak to Lost.** In EnemyWave's advance slot an enemy reaches the path end, reads `lives_cost`, leaves the roster, emits `enemy_leaked`. FlowSim applies `lives_after = max(0, lives_before - lives_cost)`, emits `lives_changed`, and on 0 commits Lost, sets `HaltState`, emits `phase_changed(LOST)`. `halted()` is now true, so EnemyWave, TowerSim and HeroSim return at once and nothing pays a bounty. The HUD snapshots results on the next frame and shows the screen after 400 ms.

**Early call.** The HUD calls `Battle.call_early()`. FlowSim emits `wave_called_early(seconds_left)`; TowerSim pays `to_ticks(seconds_left) div to_ticks(rate)`; FlowSim then calls the injected `start_next_wave` and emits `phase_changed(WAVE)`. The first spawn is on the next tick.

**Retry.** The Retry tap sets a latch on AppRoot. AppRoot's frame checks Fatal first, then disposes the shell (which stops the clock and cancels input), frees the old battle, builds a new one with the same stage and seed, and builds a new shell. The catalogue and the session flags survive; nothing else does.

**Focus loss.** AppRoot alone receives the lifecycle notification. It calls `adapter.cancel()` and `battle.pause()`; FlowSim enters Paused and the shell resets its `FixedStepClock`. A tap on the Paused screen calls `battle.resume()` and reaches nothing beneath. Which notification triggers this is NOT SOURCEABLE until ADR-0002.

**Fatal.** Any system calls the injected `fatal_handler(cause)`. It is idempotent, keeps the first cause, latches on the battle and the root, and stops all ticking in the same tick. The root shows FatalScreen. Systems check `halted()` after every accessor read and every signal, because GDScript has no exceptions and a function keeps running on a garbage value. Typed catalogue reads (below) narrow what that garbage can be.

### 5. Save and load

None at MVP. Nothing is saved: an app killed by the OS loses the stage, there is no save file, and the catalogue is content shipped in the build. The only files written are the debug logs under `user://`, in debug builds, which are not saves. No module owns serialisation. Stage Progression and Save/Load (Vertical Slice) will add one; their ADR is deferred, and the catalogue's stable IDs and the "no fallbacks" rule are what they inherit.

### 6. Determinism path

The same stage, seed and command script give an identical result (Flow Rule 5). `SimTime` owns the seed; no MVP system reads it, and cosmetic jitter never uses it. Time enters only through `Battle.tick()`, one fixed step per call. Authored seconds become whole ticks through one function, `SimTime.to_ticks(seconds) = round(seconds / DT)`, halves away from zero. Bot baselines are kept per CPU architecture because float results may differ between x86 and ARM (Combat Edge Cases, unverified).

## API Boundaries

Language: typed GDScript. Types below are the contract. Engine types are flagged where they appear. Signal parameters that carry an enum are typed `int`, because enum-typed signal parameters are not enforced.

### Shared types (Foundation)

```gdscript
class_name EnemyState extends RefCounted     # one live enemy; owned by EnemyWave, read by all
var spawn_id: int
var def_id: StringName
var distance: float                          # along the path, field units
var in_field: bool                           # cached per tick; targets() keeps only these (ADR-0009)
var position: Vector2                        # cached once per tick from distance (ADR-0009)
var health: Health                           # attached by Combat at spawn (ADR-0007)
var status: Status

class_name DamageEvent extends RefCounted
var target: EnemyState
var amount: float
var source_kind: int                         # Combat.SourceKind
var source_id: StringName

class_name ReadContext extends RefCounted     # what a stat read is about
var entity: int                               # record kind (tower, enemy, hero, burst ...); ADR-0004
var def_id: StringName
var level: int                                # 0 for records with no levels

class_name SlotState extends RefCounted
var tower_id: StringName                      # &"" when empty
var level: int
var cooldown_left: int                        # ticks

class_name HitTarget extends RefCounted       # one Input disc (fields per the Input GDD; ADR-0006)
var centre: Vector2
var radius: float
var priority: int
var accepts: int                              # bit mask of InputResolver.Gesture
var enabled: bool
var sink: bool                                # takes the gesture and does nothing (tap sink)
var owner_tag: StringName
func set_centre(p: Vector2) -> void
func set_enabled(on: bool) -> void

class_name StageRecord extends RefCounted     # structural fields, read directly (full list in ADR-0004)
var scene_ref: String
var wave_ids: Array[StringName]
var starting_gold: int
var starting_lives: int
var early_call_seconds_per_gold: float
var path_points: PackedVector2Array
var path_width: float
var slot_positions: PackedVector2Array
var hero_start: Vector2
var pin_rect: Rect2
var pin_exclusion: Array[PinShape]         # two points, a radius and a hand, per the Data GDD

class_name CatalogueError extends RefCounted
var code: StringName
var source: String
var record_id: StringName
var field: StringName

class_name HaltState extends RefCounted
func halted() -> bool                         # Won, Lost, Fatal
func in_build() -> bool
func in_tick() -> bool

@abstract class_name BattleReadModel extends RefCounted
@abstract func phase() -> int
@abstract func lives() -> int
@abstract func gold() -> int
@abstract func slot(i: int) -> SlotState
@abstract func roster() -> Array[EnemyState]
# hero position, pin and burst state, cooldown, wave index, intermission_left ...

class_name SessionFlags extends RefCounted     # owned by AppRoot; survives retry, not app restart
var pinned_once: bool
var built_once: bool
var won_once: bool
```

Each `class_name` lives in its own file. Packed arrays on `StageRecord` are read-only after load, so the 4.7 change to packed-array element setters does not reach them.

### Catalogue

```gdscript
class_name Catalogue extends RefCounted

enum StatKey { COST, DAMAGE, RANGE, ATTACK_INTERVAL, SPLASH_RADIUS, SLOW_STRENGTH, SLOW_DURATION,
               BOUNTY, LIVES_COST, MAX_HP, MOVE_SPEED, LEASH_RADIUS, WALK_SPEED, RADIUS, REACH,
               COOLDOWN, TELEGRAPH_DURATION }

static func from_manifest(manifest: String, source: TextSource, fail: Callable) -> Catalogue   # null on failure; JSON files (ADR-0004)
func read_int(ctx: ReadContext, key: StatKey) -> int        # sentinel 0 on failure
func read_float(ctx: ReadContext, key: StatKey) -> float    # sentinel 0.0 on failure
func read_bool(ctx: ReadContext, key: StatKey) -> bool      # sentinel false on failure
func level_count(def_id: StringName) -> int                 # non-fatal
func is_tower(id: StringName) -> bool                       # non-fatal
func stage(id: StringName) -> StageRecord
# also wave(), hero(), input_record(), tower_ids(), visual_key(), snapshot(): ADR-0004
```

Invariants: records are read-only after load; callers never cache a read (the next use reflects a changed value). A bad key, a wrong-type key for the accessor, or a bad context calls the injected failure handler and returns the documented sentinel; the caller checks `halted()` before using it. A typed accessor turns a type mistake into a parse error or a handler call instead of a silent `Variant`. `TextSource` is injected so unit tests build catalogues with no file I/O. Guarantee: either every record is valid or the game does not start.

### Battle (the facade the wrapper, bots and the shell hold)

```gdscript
class_name Battle extends BattleReadModel

var flow: FlowSim            # read-only references for signal wiring by ShellBuilder
var waves: EnemyWave
var towers: TowerSim
var hero: HeroSim
var combat: Combat

func tick() -> void                                   # one fixed step; returns at once when Paused or halted
func halted() -> bool
func in_build() -> bool
func in_tick() -> bool
# commands: each forwards to its owner and is refused while in_tick()
func start_wave() -> bool                             # Build only
func call_early() -> bool                             # Intermission only
func pause() -> void
func resume() -> bool                                 # Paused only
func build(slot_index: int, tower_id: StringName) -> TowerSim.Result
func upgrade(slot_index: int) -> TowerSim.Result
func pin(position: Vector2) -> HeroSim.PinResult
func burst(aim_point: Vector2) -> HeroSim.BurstResult
func dispose() -> void                               # breaks the FlowSim and EnemyWave reference cycle (ADR-0005)
# test seams (ADR-0001, ADR-0002): used by tests and bots, never by the shell
func systems() -> Array[RefCounted]                  # every system the builder made, in tick order
func snapshot() -> Dictionary                         # plain copy of sim state for equality checks
```

Bots and the shell hold only `Battle`. Signals stay on their owning modules (`battle.flow.phase_changed`, `battle.towers.gold_changed`); `Battle` does not re-emit them. `Battle` implements `BattleReadModel`, so the HUD and views read the same interface a test fake provides.

### FlowSim

```gdscript
class_name FlowSim extends RefCounted

enum Phase { BUILD, WAVE, INTERMISSION, PAUSED, WON, LOST, FATAL }
func tick() -> void                         # tick slot 1
func start_wave() -> bool
func call_early() -> bool
func pause() -> void
func resume() -> bool
func on_enemy_leaked(lives_cost: int) -> void
func on_wave_cleared(intermission_duration: float) -> void
func on_waves_complete() -> void
func phase() -> int
func lives() -> int
func intermission_left() -> int             # ticks
signal phase_changed(p: int)
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
```

FlowSim never names `EnemyWave`. It starts a wave through a `start_next_wave: Callable` the builder injects, and it hears EnemyWave through the three `on_` handlers the builder connects.

### Combat

```gdscript
class_name Combat extends RefCounted

enum SourceKind { TOWER, HERO, BURST }
func register(enemy: EnemyState, max_hp: float) -> void   # EnemyWave calls at spawn (ADR-0007)
func release(enemy: EnemyState) -> void
func deliver(event: DamageEvent) -> float        # returns applied; 0 outside a tick or on a bad amount
func apply_slow(enemy: EnemyState, strength: float, seconds: float) -> void   # rejects strength outside (0,1)
func report_attack(source_kind: int, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func first_in(list: Array[EnemyState], origin: Vector2, range_: float) -> EnemyState    # null when none
func nearest_in(list: Array[EnemyState], origin: Vector2, range_: float) -> EnemyState
func all_in_radius(list: Array[EnemyState], center: Vector2, radius: float) -> Array[EnemyState]
func hp_left(enemy: EnemyState) -> float
func is_dead(enemy: EnemyState) -> bool
func speed_factor(enemy: EnemyState) -> float
func tick_status(roster: Array[EnemyState]) -> void
func dealt_by_id(source_id: StringName) -> float
func dealt_by_kind(kind: int) -> float
signal attack_fired(source_kind: int, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(event: DamageEvent, applied: float, position: Vector2)
```

Distance compares run on scalar `float` components, not on `Vector2.distance_to`, where exact results matter (see the `Vector2` note in the Engine Knowledge Gap Summary). ADR-0007 decides whether that applies to every helper or only to the pin clamp.

### EnemyWave

```gdscript
class_name EnemyWave extends RefCounted

func start_next_wave() -> void                   # injected into FlowSim; a start during Active or past the last is ignored with a development error
func advance() -> void                           # tick slot 2: spawn, move, leak
func reap() -> void                              # last tick slot: kills, then clear check
func roster() -> Array[EnemyState]               # every enemy not yet removed, corpses included, in spawn_id order; read-only
func targets() -> Array[EnemyState]              # roster limited to enemies inside the field; read-only
func wave_index() -> int
func got_through_by_type() -> Dictionary[StringName, int]   # view-only counts for the result
signal enemy_killed(bounty: int)
signal enemy_leaked(lives_cost: int)
signal wave_cleared(intermission_duration: float)
signal waves_complete()
```

Invariants for callers: both lists are never modified and never kept past the reader's slot. Guarantees: leak events fire synchronously and before `waves_complete`; a clear check runs every tick while a wave is active.

### TowerSim

```gdscript
class_name TowerSim extends RefCounted

enum Result { OK, HALTED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_TOWER, MAX_LEVEL, NO_GOLD }
func build(slot_index: int, tower_id: StringName) -> Result      # live in every phase
func upgrade(slot_index: int) -> Result
func gold() -> int
func slot_state(slot_index: int) -> SlotState
func tick() -> void
func on_enemy_killed(bounty: int) -> void
func on_wave_called_early(seconds_left: float) -> void
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)
signal tower_upgraded(slot_index: int, level: int)
```

Each enum above is a separate named enum per class; two classes both defining `HALTED` do not share one enum. Guarantee: a refusal changes nothing and emits nothing.

### HeroSim and AimModel

```gdscript
class_name HeroSim extends RefCounted

enum PinResult { OK, HALTED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE }
enum BurstResult { OK, HALTED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH }
func pin(position: Vector2) -> PinResult
func burst(aim_point: Vector2) -> BurstResult
func tick() -> void
func position() -> Vector2
func pin_target() -> Vector2
func pin_state() -> int
func burst_state() -> int
func cooldown_left() -> int
signal hero_pinned(position: Vector2)
signal burst_started(aim_point: Vector2, telegraph_ticks: int)

class_name AimModel extends RefCounted
func begin(p: Vector2) -> void                 # drag started on the burst button
func move(p: Vector2) -> void
func release(p: Vector2) -> Vector2            # aim point to pass to burst, or the cancel result (ADR-0011)
func clear() -> void
func update(battle: BattleReadModel) -> void   # per frame while the hero walks
func aim_state() -> int
func aim_point() -> Vector2
func aim_ring_radius() -> float
func preview_kills() -> Array[EnemyState]
func cooldown_digit() -> int

class_name PinGeometry extends RefCounted
func is_valid(x: float, y: float) -> bool
func check(x: float, y: float) -> int          # three-valued result (ADR-0011)
func clamp(x: float, y: float, hold: Vector2) -> Vector2   # 64-bit scalars, converted once at the end
```

HeroInput changes the battle only through `pin` and `burst`; one equivalence test keeps a resolver-driven script and a direct-command script identical. The same holds for TowerInput and `upgrade`.

### InputResolver

```gdscript
class_name InputResolver extends RefCounted

enum Gesture { TAP = 1, DRAG = 2 }
static func create(drag_slop: float, tap_slop: float) -> InputResolver   # null when validate() is false
func register(target: HitTarget) -> int
func unregister(id: int) -> void
func press(pointer: int, p: Vector2) -> void
func move(pointer: int, p: Vector2) -> void
func release(pointer: int, p: Vector2) -> void
func cancel() -> void
func cancel_pointer(pointer: int) -> void
signal pressed(best_tap: HitTarget, best_drag: HitTarget, p: Vector2)    # either may be null
signal tap(target: HitTarget, p: Vector2)
signal ground_tap(p: Vector2)
signal drag_started(target: HitTarget, press_pos: Vector2, p: Vector2)
signal drag_moved(target: HitTarget, press_pos: Vector2, p: Vector2)
signal drag_ended(target: HitTarget, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(target: HitTarget)
signal idle()
```

The resolver is clock-free and emits no per-frame signal. A gesture reaches only its class winner or nothing, and the winners are frozen at press.

### Shell clocks and file seams

```gdscript
class_name FixedStepClock extends RefCounted
func advance(real_seconds: float) -> int     # ticks owed this frame, after the clamp
func reset() -> void                          # on pause, resume and retry

class_name ChipWindow extends RefCounted
func open() -> void
func close() -> void
func advance(ms: int) -> void
func elapsed() -> int
func state() -> int

class_name TextSource extends RefCounted      # real one wraps FileAccess; tests pass strings
func read_text(path: String) -> String

class_name LineWriter extends RefCounted      # real one wraps FileAccess; tests collect lines
func write_line(line: String) -> bool
```

### Shell to sim commands

One name per command. Every command goes through `Battle`.

| From | Call on Battle | Owner | Result |
|---|---|---|---|
| HudLogic (Start) | `start_wave()` | FlowSim | `false` unless Build |
| HudLogic (Call) | `call_early()` | FlowSim | `false` unless Intermission; `wave_called_early` only for a real call |
| AppRoot (focus loss) | `pause()` | FlowSim | idempotent |
| HudLogic (Paused screen tap) | `resume()` | FlowSim | `false` unless Paused |
| HudLogic (arc disc) | `build(slot, id)` | TowerSim | `Result`; `NO_GOLD` leaves the arc open |
| TowerInput (chip commit) | `upgrade(slot)` | TowerSim | `Result`; the only way TowerInput changes state |
| HeroInput | `pin(position)`, `burst(aim_point)` | HeroSim | result enums above |
| HudLogic (Retry) | none: sets the AppRoot latch | AppRoot | idempotent; Fatal wins in the same frame |

`EnemyWave.start_next_wave()` is not a shell command. Only FlowSim calls it, through the injected Callable.

**Engine awareness check.** Types used in contracts: `RefCounted`, `Signal` and typed signals, `Callable`, `Vector2`, `Rect2`, `PackedVector2Array`, `StringName`, typed `Array` and typed `Dictionary`, `@abstract`. All are in the pinned reference or stable since 4.0; `@abstract` needs 4.5 or later. Two 4.7 rules apply to every class here: an override of a typed-return method inherits that return type and needs an explicit `return` (this bites every `BattleReadModel` subclass, including test fakes); and writing one element of a packed array no longer calls the property setter, so a setter on a packed-array property cannot be relied on for element writes.

## ADR Audit

Existing ADRs (updated 2026-11-04, after `/create-architecture` version 2): ADR-0001 to ADR-0014 are written, all Proposed. Each passed a batch TD-ADR review (5 APPROVE, 9 CONCERNS, all fixed) and an engine-specialist check against the 4.7.2 class reference. Each lists engine checks that block acceptance; see `production/qa/engine-verification-plan.md`. The full audit is in `architecture-review-2026-11-04.md`.

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|-----|--------------|---------|-------------|-----------|-------|
| 0001 to 0014 | Section present in all 14 | 4.7.2 in all 14 | GDD Requirements Addressed in all 14 | None open (dependency graph acyclic) | Proposed; blocked on Run A or Run B |

### Technical Requirements Baseline

Extracted from 8 GDDs | 70 total requirements | 0 registered, 70 provisional
(TR registry: read, 0 entries). Every ID is provisional; do not cite one as permanent until `/architecture-review` registers it.

Every GDD contributed requirements; none was dropped. Requirements are stated at architecture level (a decision is needed to support them), not as every rule in a GDD.

| Req ID | GDD | System | Requirement | Domain | ADR |
|--------|-----|--------|-------------|--------|-----|
| TR-data-001 (provisional) | data-config-pipeline | Data | Load the whole catalogue once from an explicit manifest before the first gameplay scene; all records valid or the game does not start | Core | ADR-0004 |
| TR-data-002 (provisional) | data-config-pipeline | Data | Validate everything, collect all errors as `{code, source, record_id, field}`, then fail | Core | ADR-0004 |
| TR-data-003 (provisional) | data-config-pipeline | Data | Definitions are read-only after load; runtime instances hold `def_id` (and level for towers) | Core | ADR-0004 |
| TR-data-004 (provisional) | data-config-pipeline | Data | One stat accessor taking a read context and key, returning the declared type, with non-fatal `level_count` and `is_tower` | Core | ADR-0004 |
| TR-data-005 (provisional) | data-config-pipeline | Data | Stage geometry (`path_points`, `slot_positions`, `path_width`, `hero_start`, `pin_rect`, `pin_exclusion`) lives on the Stage record, read directly | Core | ADR-0004 |
| TR-data-006 (provisional) | data-config-pipeline | Data | The catalogue is injected, never an autoload; tests build fixture catalogues in code with no file I/O | Core | ADR-0004 |
| TR-data-007 (provisional) | data-config-pipeline | Data | No fallbacks in any build; a bad accessor call reaches the failure handler and the Fatal screen | Core | ADR-0002 |
| TR-data-008 (provisional) | data-config-pipeline | Data | A CI content test opens each `scene_ref` and applies the layout, wave and tower rules to the records | Testing | ADR-0013 |
| TR-data-009 (provisional) | data-config-pipeline | Data | Edit a value, save, run: the new value is in the game within 10 s, no live reload | Tooling | ADR-0004 |
| TR-input-001 (provisional) | input-gesture-resolver | Input | One active pointer; two winners (tap, drag) frozen at press; tap and drag classified by slop; a gesture reaches only its class winner | Input | ADR-0006 |
| TR-input-002 (provisional) | input-gesture-resolver | Input | A registry of discs with priority, accepted gestures and an enabled flag; owners register and unregister themselves | Input | ADR-0006 |
| TR-input-003 (provisional) | input-gesture-resolver | Input | The adapter maps engine events to five calls, applies the edge reject margin, keeps receiving events while Paused (mechanism open: ADR-0002), and exposes `cancel()` for AppRoot to call on lifecycle events | Input | ADR-0006 |
| TR-input-004 (provisional) | input-gesture-resolver | Input | The resolver is clock-free and emits one `drag_moved` per input call, never per frame | Input | ADR-0006 |
| TR-input-005 (provisional) | input-gesture-resolver | Input | The resolver is built only by the ShellBuilder; bots call commands on `Battle`; one equivalence test through the resolver | Core | ADR-0001 |
| TR-input-006 (provisional) | input-gesture-resolver | Input | A development-build gesture log with the Rule 13 fields | Tooling | ADR-0014 |
| TR-input-007 (provisional) | input-gesture-resolver | Input | All thresholds and hit radii are in field units on the 540 x 960 field; hit targets are at least 48 dp | Input | ADR-0008 |
| TR-flow-001 (provisional) | game-state-stage-flow | Flow | The app root is a minimal main scene with no autoload; it holds the catalogue, the fatal screen, the retry latch and the presentation session flags | Core | ADR-0002 |
| TR-flow-002 (provisional) | game-state-stage-flow | Flow | `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)` constructs and wires one battle with explicit connections and no scene | Core | ADR-0002 |
| TR-flow-003 (provisional) | game-state-stage-flow | Flow | Simulation time enters only through `Battle.tick()`, one fixed 1/60 s step per call; no `_process`, engine timer, `await`, wall clock or physics area in gameplay | Core | ADR-0003 |
| TR-flow-004 (provisional) | game-state-stage-flow | Flow | A fixed system tick order; commands apply only between ticks | Core | ADR-0003 |
| TR-flow-005 (provisional) | game-state-stage-flow | Flow | A phase machine (Build, Wave, Intermission, Paused, Won, Lost, Fatal) with an outcome latch and `halted()`, `in_build()`, `in_tick()` | Core | ADR-0005 |
| TR-flow-006 (provisional) | game-state-stage-flow | Flow | Lives formula `max(0, before - cost)`; leak events synchronous and before `waves_complete`; a fatal leak beats a clear | Core | ADR-0005 |
| TR-flow-007 (provisional) | game-state-stage-flow | Flow | Retry destroys and rebuilds the whole battle with the same seed, through a latch on the root, Fatal first | Core | ADR-0002 |
| TR-flow-008 (provisional) | game-state-stage-flow | Flow | Focus loss enters Paused: clock stops, input cancels, accumulator zeroed, a tap resumes | Platform | ADR-0002 |
| TR-flow-009 (provisional) | game-state-stage-flow | Flow | The failure handler is idempotent, keeps the first cause, discards a partial battle, and shows a generic screen with no catalogue data | Core | ADR-0002 |
| TR-flow-010 (provisional) | game-state-stage-flow | Flow | A wiring test fails if any battle signal has no listener unless allowlisted for views | Testing | ADR-0005 |
| TR-flow-011 (provisional) | game-state-stage-flow | Flow | The same stage, seed and command script give an identical result | Core | ADR-0003 |
| TR-flow-012 (provisional) | game-state-stage-flow | Flow | One conversion for authored time, `to_ticks(seconds) = round(seconds / dt)`, halves away from zero | Core | ADR-0003 |
| TR-combat-001 (provisional) | combat-damage | Combat | One damage path, `deliver(event)`, only inside a tick, returning the amount applied | Core | ADR-0007 |
| TR-combat-002 (provisional) | combat-damage | Combat | Health per enemy seeded once from `max_hp`; death is immediate; counters by source id and kind | Core | ADR-0007 |
| TR-combat-003 (provisional) | combat-damage | Combat | Status with one slow slot per enemy, held in whole ticks, no stacking | Core | ADR-0007 |
| TR-combat-004 (provisional) | combat-damage | Combat | Pure targeting helpers with exact compares, ties to the lowest `spawn_id`, skipping the dead, never modifying the list | Core | ADR-0007 |
| TR-combat-005 (provisional) | combat-damage | Combat | Combat reads no data; callers pass values in | Core | ADR-0007 |
| TR-combat-006 (provisional) | combat-damage | Combat | `attack_fired` and `damage_applied` carry copied positions and feed views only | Presentation | ADR-0005 |
| TR-combat-007 (provisional) | combat-damage | Combat | The targeting worst case (about 400 checks) stays within about 2 ms on a low-end phone | Performance | ADR-0007 |
| TR-wave-001 (provisional) | enemy-wave | Enemy & Wave | One path per stage; position is computed from one distance along it; a view draws from the same points | Core | ADR-0009 |
| TR-wave-002 (provisional) | enemy-wave | Enemy & Wave | An authored absolute spawn schedule in whole ticks, no randomness | Core | ADR-0003 |
| TR-wave-003 (provisional) | enemy-wave | Enemy & Wave | `enemy_killed`, `enemy_leaked`, `wave_cleared`, `waves_complete` emitted synchronously; reap in ascending `spawn_id` | Core | ADR-0005 |
| TR-wave-004 (provisional) | enemy-wave | Enemy & Wave | Movement `d_next = d + speed x factor x dt`; leak at path length; a guard for a bad speed | Core | ADR-0003 |
| TR-wave-005 (provisional) | enemy-wave | Enemy & Wave | `halted()` is checked after every accessor read and every signal | Core | ADR-0005 |
| TR-wave-006 (provisional) | enemy-wave | Enemy & Wave | Layout rules L1 to L14 and the wave rules run in the content test | Testing | ADR-0013 |
| TR-wave-007 (provisional) | enemy-wave | Enemy & Wave | An enemy is targetable only inside the field; everything outside the field is masked on any screen shape | Rendering | ADR-0008 |
| TR-wave-008 (provisional) | enemy-wave | Enemy & Wave | At most 48 enemies alive; the view pool matches | Performance | ADR-0009 |
| TR-wave-009 (provisional) | enemy-wave | Enemy & Wave | One add-enemy step serves the schedule and later splitter children | Core | ADR-0009 |
| TR-tower-001 (provisional) | tower-system | Tower | TowerSim (headless) and TowerInput (wrapper only); TowerInput changes state only through `upgrade` | Core | ADR-0010 |
| TR-tower-002 (provisional) | tower-system | Tower | `build` and `upgrade` return ordered result codes, work in every phase, and are shared by players and bots | Core | ADR-0010 |
| TR-tower-003 (provisional) | tower-system | Tower | Gold is one non-negative integer; kills and early calls add, the two commands spend; the bonus is `to_ticks(seconds_left) div to_ticks(rate)` | Core | ADR-0010 |
| TR-tower-004 (provisional) | tower-system | Tower | Attack timers in integer ticks with ready-and-holding; a slow tower prefers an empty slow slot | Core | ADR-0010 |
| TR-tower-005 (provisional) | tower-system | Tower | A pure `ChipWindow` fed real milliseconds (200 to 1500) and a chip disc registered while open | Input | ADR-0010 |
| TR-tower-006 (provisional) | tower-system | Tower | Signals `gold_changed`, `tower_built`, `tower_upgraded`; wrapper-only `slot_tapped`, `tower_inspected`, `chip_state()` | Core | ADR-0005 |
| TR-tower-007 (provisional) | tower-system | Tower | Content rules: two levels, cost bounds, the bonus share, `gold_before_last_wave` below the cheapest full board | Testing | ADR-0013 |
| TR-hero-001 (provisional) | hero-system | Hero | HeroSim (headless) and HeroInput (wrapper only); HeroInput changes the battle only through `pin` and `burst` | Core | ADR-0011 |
| TR-hero-002 (provisional) | hero-system | Hero | Ordered result codes for `pin` and `burst`; a straight-line walk in whole ticks; `PinGeometry.clamp` as a plain class | Core | ADR-0011 |
| TR-hero-003 (provisional) | hero-system | Hero | Aim in HeroInput with cancel hysteresis (64 and 48), recomputed every frame while the hero walks | Input | ADR-0011 |
| TR-hero-004 (provisional) | hero-system | Hero | Telegraph and cooldown in integer ticks; release in the hero slot; burst counters | Core | ADR-0011 |
| TR-hero-005 (provisional) | hero-system | Hero | The kill preview projects enemy positions to landing | Presentation | ADR-0012 |
| TR-hero-006 (provisional) | hero-system | Hero | Scripted bots reproduce the share gate headless on the fixed tick | Testing | ADR-0013 |
| TR-hud-001 (provisional) | battle-hud | HUD | Three pieces: HudLogic (plain, testable), HudTopBand (Controls), HudField (one `_draw` plus Input discs) | Presentation | ADR-0012 |
| TR-hud-002 (provisional) | battle-hud | HUD | Result and Paused screens are Controls that consume every event; everything else tappable is an Input disc | Input | ADR-0006 |
| TR-hud-003 (provisional) | battle-hud | HUD | Commands run from the input call stack before the frame's ticks; Retry only sets a latch | Core | ADR-0002 |
| TR-hud-004 (provisional) | battle-hud | HUD | Real-time models run on `advance(ms)` clamped to 100 ms and ignored while Paused | Core | ADR-0003 |
| TR-hud-005 (provisional) | battle-hud | HUD | Draw budget: about 8 and at most 12 of 60 draw calls; at most 3 text draws | Performance | ADR-0012 |
| TR-hud-006 (provisional) | battle-hud | HUD | A debug-only `user://run_log.jsonl` with one record per attempt and per call | Persistence | ADR-0014 |
| TR-hud-007 (provisional) | battle-hud | HUD | Layout in field units with safe-area insets converted at 360 dp (1 dp is 1.5 units) | Rendering | ADR-0008 |
| TR-hud-008 (provisional) | battle-hud | HUD | Every hit target is at least 48 dp, with no margin at 360 dp | Input | ADR-0006 |
| TR-hud-009 (provisional) | battle-hud | HUD | Prompt retirement flags survive a retry and reset when the app restarts | Core | ADR-0002 |
| TR-hud-010 (provisional) | battle-hud | HUD | The HUD is absent headless; nothing in the battle depends on it | Core | ADR-0001 |
| TR-hud-011 (provisional) | battle-hud | HUD | Modal screens use `focus_mode` NONE and top-band Controls use `mouse_filter` IGNORE (4.6 dual focus) | UI | ADR-0006 |
| TR-hud-012 (provisional) | battle-hud | HUD | Every HUD timer runs on one `advance` clock; the chip bar displays Tower's window | Core | ADR-0003 |
| TR-hud-013 (provisional) | battle-hud | HUD | Frame time stays within 16.6 ms and memory within 256 MB on the low-end target phone (technical preferences) | Performance | ADR-0012 |

### Traceability Coverage Check

Coverage at version 2 (before the ADRs existed): 0 covered, 70 gaps. Current coverage (architecture review, 2026-11-04): 71 of 74 covered by Proposed ADRs, 3 partial, 0 gaps; see `requirements-traceability.md`. Each gap is a **Required New ADR** below. Gap count per proposed ADR, counted from the last column of the table: ADR-0001: 2, ADR-0002: 8, ADR-0003: 8, ADR-0004: 7, ADR-0005: 7, ADR-0006: 7, ADR-0007: 6, ADR-0008: 3, ADR-0009: 3, ADR-0010: 5, ADR-0011: 4, ADR-0012: 4, ADR-0013: 4, ADR-0014: 2 (total 70). Version 1 said 66 and gave counts that added up to 75; both were wrong. The table had 69 rows, and version 2 adds TR-hud-013 for the frame and memory budget.

## Required ADRs

Grouped by layer, Foundation first. Run in number order: each ADR depends only on lower numbers, except where a dependency is named.

**Foundation (must exist before any coding):**

1. ADR-0001 Simulation and Shell Boundary: the headless contract (sim loads with no scene tree), `RefCounted` against `Node` rules, the Composition tier, `HaltState`, `BattleReadModel` and fakes, the test seams the criteria assume (injected recording systems, enumerating a battle's systems, a snapshot), `TextSource` and `LineWriter`, typed GDScript conventions including the 4.7 override rule and `Vector2` precision. Covers TR-input-005, TR-hud-010. Written first because ADR-0002 builds on it.
2. ADR-0002 App Lifecycle and Composition: AppRoot as the single lifecycle receiver, `BattleBuilder` and `ShellBuilder`, the retry latch and teardown, the pause mechanism (tree pause or not, and the adapter's `process_mode`), the lifecycle notifications on each platform (with a development override so a click on the debugger does not pause), the fatal screen, input before ticks in a frame. Covers TR-data-007, TR-flow-001, 002, 007, 008, 009, TR-hud-003, 009. Engine risk: HIGH, with NOT SOURCEABLE items that it must verify.
3. ADR-0003 Fixed Tick, Time and Determinism: the 1/60 tick, `FixedStepClock` and its clamp, where the frame hook lives, `SimTime.to_ticks`, the tick order, the seed, float policy and per-architecture baselines, the HUD `advance(ms)` clock. Covers TR-flow-003, 004, 011, 012, TR-wave-002, 004, TR-hud-004, 012. Engine risk: NOT SOURCEABLE.
4. ADR-0004 Catalogue Format, Loader, Validator and Stat Accessor: the data file format and manifest, `CatalogueError`, the typed accessors and their sentinels, `ReadContext`, `StageRecord`, injection. Covers TR-data-001 to 006, 009.
5. ADR-0005 Signal and Command Contracts: typed signals, emit order, the re-entrancy rule (proposed default in Data Flow §3), `FlowSim.Phase` and `int` payloads, the commands on `Battle`, the wiring test and its allowlist. Uses the `DamageEvent` type fixed in this document's API Boundaries; ADR-0007 may change its allocation, not its fields. Covers TR-flow-005, 006, 010, TR-combat-006, TR-wave-003, 005, TR-tower-006.

**Core:**

6. ADR-0006 Input Adapter and Resolver Integration: which Godot input path feeds the adapter, Control against disc routing, touch and mouse emulation, the 4.7 device-ID rule, dual focus, whether recursive disable reaches the top band, `cancel()`. Covers TR-input-001 to 004, TR-hud-002, 008, 011. Engine risk: HIGH, NOT SOURCEABLE.
7. ADR-0007 Combat Data Model: how `Health` and `Status` attach to `EnemyState`, `DamageEvent` allocation, the targeting helpers' contracts and cost measure, and the recorded cost of reversing the ProjectileSpawner cut (attackers would stop choosing victims at fire time). Covers TR-combat-001 to 005, 007.
8. ADR-0008 Stretch Mode, Safe Area and the Field: the 540 x 960 field on taller phones, masking outside the field, inset conversion, and writing `stretch/mode` and `stretch/aspect` explicitly into `project.godot`. Covers TR-input-007, TR-wave-007, TR-hud-007. Engine risk: HIGH.

**Feature:**

9. ADR-0009 Enemy Roster, Position Cache and View Pooling: roster storage, the per-tick position on `EnemyState`, `spawn_id`, FieldView's 48-enemy pool, the add-enemy seam for splitters. Covers TR-wave-001, 008, 009.
10. ADR-0010 Tower System: the TowerSim and TowerInput split, the result enum, `ChipWindow` and its real-time feed, the two shell callers, the equivalence test. Covers TR-tower-001 to 005.
11. ADR-0011 Hero System: the HeroSim and HeroInput split, the result enums, `PinGeometry` on scalar floats, `AimModel` and the shared aim-point function, the equivalence test. Covers TR-hero-001 to 004.

**Presentation:**

12. ADR-0012 Field and HUD Rendering and Performance Budget: one `_draw` per kind, the redraw policy (`queue_redraw` on change), the draw-call and text budgets and how to measure them on a device, line widths after the 4.7 change, the kill preview, the 16.6 ms frame and 256 MB memory budgets, and the renderer choice. Covers TR-hero-005, TR-hud-001, 005, 013.

**Testing and tooling:**

13. ADR-0013 Content Test and Bot Harness: the CI content test, the headless bot runner, gdUnit4 conventions. Device budgets are not CI gates. Covers TR-data-008, TR-wave-006, TR-tower-007, TR-hero-006.
14. ADR-0014 Debug Logs: HumanLog and GestureLog, flush on mobile, thread. Covers TR-input-006, TR-hud-006. Deferrable.

**Priority.**

- Must have before coding starts (Foundation and Core): ADR-0001 to ADR-0008.
- Should have before the relevant system is built: ADR-0009 (before Enemy & Wave stories), ADR-0010 (before Tower stories), ADR-0011 (before Hero stories), ADR-0012 (before HUD stories), ADR-0013 (before the first bot story).
- Can defer to implementation: ADR-0014.

## Architecture Principles

1. **The simulation never knows the scene tree.** Every gameplay module is a plain object that loads and runs with no node, renderer or real clock. The shell reads it through `BattleReadModel` and sends commands through `Battle`. A bot, a test and a phone all drive the same sim.
2. **One way in for time, one for commands.** Time enters only through `Battle.tick()` at a fixed step; commands arrive only between ticks and return a result code. Nothing in gameplay uses `_process`, a timer, `await` or a wall clock.
3. **Data, not code, holds balance and geometry.** Gameplay numbers and stage layout are catalogue fields read at the moment of use through typed accessors. Nothing is cached, nothing has a fallback, and a bad read is Fatal. Two builders wire explicit connections; there is no global bus and no autoload.
4. **Refuse in the open, fail loudly.** Every refused command is a named result that changes and emits nothing. Every unrecoverable read stops the battle and shows a generic screen. A step that cannot run must say so; silence is never a pass.
5. **Views read; they never write.** Presentation draws from `BattleReadModel` and signals on an allowlist, and nothing in gameplay depends on a view.
6. **Engine behaviour that is not sourced is a gap, not a fact.** Anything the pinned reference does not cover is marked NOT SOURCEABLE and blocks Acceptance of the ADR that depends on it until that ADR cites the live 4.7 documentation or a device run.

## Open Questions

| ID | Summary | Priority | Resolution Path |
|----|---------|----------|-----------------|
| QQ-01 | Which lifecycle notification enters Paused on each platform, and how a desktop developer avoids pausing on every focus-out | High | ADR-0002 |
| QQ-02 | Where the frame hook lives (`_process` or `_physics_process`) and the `FixedStepClock` clamp value | High | ADR-0003 |
| QQ-03 | Control event order against the adapter, and whether a STOP Control hides events from it | High | ADR-0006 |
| QQ-04 | Stretch mode and masking on taller phones. `project.godot` has no stretch keys, so the class-reference defaults (`disabled`, `keep`) apply until ADR-0008 writes `canvas_items` and `keep`, letting the letterbox bars mask the area outside the field | High | ADR-0008 |
| QQ-05 | Catalogue file format and manifest form | High | ADR-0004 |
| QQ-06 | How Health and Status attach to `EnemyState` (fields, or Combat-side tables keyed by `spawn_id`) | High | ADR-0007, ADR-0009 |
| QQ-07 | **Resolved by TD-ARCHITECTURE, 2026-11-04.** BattleBuilder composition root: accepted, moved to the Composition tier with a ShellBuilder beside it; "no branch on a gameplay value" is a review rule. TowerSim and TowerInput split: accepted; TowerInput holds only registration and the chip disc, gets an equivalence test, and the two shell callers are documented. ProjectileSpawner cut: accepted for MVP; ADR-0007 records the reversal cost, and the Mobile Platform & Performance system should rescope "heavy projectile load" to tracer and effect pooling | Closed | ADR-0002, ADR-0007, ADR-0010 carry the conditions |
| QQ-08 | The draw-call, frame, memory and 400-check targeting budgets are unverified on a device | Medium | ADR-0012, ADR-0007, first phone build |
| QQ-09 | Per-architecture bot baselines (x86 against ARM). The `Vector2` half is resolved: 32-bit in default builds, so exact compares use scalar `float` | Medium | ADR-0003 |
| QQ-10 | Re-entrancy: version 2 proposes that no battle listener calls a command and a command during `in_tick()` is refused; ADR-0005 must confirm or replace it | Medium | ADR-0005 |
| QQ-11 | Rendering backend: the project uses Mobile; the reference calls Forward+ desktop-focused, and the Compatibility fallback is untested | Low | ADR-0012 |
