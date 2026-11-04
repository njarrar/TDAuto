# TowerRiot: Master Architecture

## Document Status

- Version: 1
- Last Updated: 2026-11-04
- Engine: Godot 4.7.2 (GDScript, Mobile renderer, 2D, portrait 540 x 960 field)
- GDDs Covered: design/gdd/data-config-pipeline.md, input-gesture-resolver.md, game-state-stage-flow.md, combat-damage.md, enemy-wave.md, tower-system.md, hero-system.md, battle-hud.md (8 of 8 MVP systems; all In Review, with no blocking issue left in the cross-GDD review of 2026-11-04)
- ADRs Referenced: none exist yet. 13 are proposed below (ADR-0001 to ADR-0013). Numbers are placeholders until `/architecture-decision` assigns them.
- TR registry: `docs/architecture/tr-registry.yaml` holds no requirements, so every ID in this document is provisional. `/architecture-review` registers them and fixes the permanent IDs.
- TD-ARCHITECTURE: pending
- LP-FEASIBILITY: pending

## Engine Knowledge Gap Summary

Engine: Godot 4.7.2. The model's training covers Godot up to about 4.3, so 4.5, 4.6 and 4.7 are all post-cutoff. This game is 2D, mobile, single-thread and uses no physics server (every hit test is a distance check, Flow Rule 4 bans physics areas), no audio at MVP, no navigation, no networking and no 3D. That removes most of the HIGH-risk surface. What remains:

| Domain | Risk | What changed | Where this game touches it |
|---|---|---|---|
| GDScript (Core) | HIGH | 4.5 variadic arguments and `@abstract`; 4.7 an override of a method with a typed return now inherits that return type and needs an explicit `return`; 4.7 writing one element of a packed array no longer calls the property setter | Every module is GDScript. Base classes with typed returns need care. Typed signals and typed arrays are mandatory (deprecated patterns table) |
| Input | HIGH | 4.7 mouse and keyboard events report `DEVICE_ID_MOUSE` and `DEVICE_ID_KEYBOARD`, not device 0; 4.6 dual focus | InputAdapter must classify events by type, never by `device == 0`. Touch is the primary input; mouse emulates it on desktop |
| UI | HIGH | 4.6 dual focus (touch focus separate from keyboard focus); 4.5 recursive disable of mouse and focus on a Control hierarchy; 4.7 new projects stretch by default | Modal screens and the top band are Controls. `focus_mode` NONE on modals, `mouse_filter` IGNORE on the top band |
| Rendering (2D canvas) | HIGH | 4.7 `CanvasItem` lines are drawn without an antialiasing feather, so they look thinner | All field art is `_draw` primitives with 2 px and 3 px strokes. Widths need a device check. Renderer is Mobile (the reference calls Forward+ desktop-focused) |
| Project settings | HIGH | 4.7 new projects default to `stretch/mode` canvas_items and `stretch/aspect` expand. Existing projects keep their settings | The 540 x 960 field on taller phones. Expand shows area outside the field, which Enemy & Wave requires masked (ADR-0008) |
| Animation | MEDIUM | 4.7 `Tween.tween_await()` | Presentation tweens only (120 ms and 200 ms motions) |
| Physics, Audio, Navigation, Networking | n/a | not used | The project file names Godot Physics 2D, but no physics body, area or server call exists in the design |

**NOT SOURCEABLE.** The pinned engine reference does not cover the items below, and the GDDs already list most of them as ADR work. They are written here as gaps, not filled from memory, and each gap makes the dependent decision `Proposed` until its ADR cites the live 4.7 documentation or a device run:

- NOT SOURCEABLE: lifecycle notifications on each platform (`NOTIFICATION_APPLICATION_*`, `NOTIFICATION_WM_*`), which of them enters Paused, and desktop focus-out behaviour in the editor and exports. Not covered by docs/engine-reference/godot/.
- NOT SOURCEABLE: whether Paused uses the engine's tree pause and `process_mode`, or only Flow's own early return.
- NOT SOURCEABLE: where the fixed tick accumulator lives (`_process` or `_physics_process`), `Engine.physics_ticks_per_second`, `max_physics_steps_per_frame`, and `Engine.time_scale`.
- NOT SOURCEABLE: input path ordering: `_input` against `_unhandled_input` against `Control._gui_input`, and whether a Control with `mouse_filter` STOP hides an event from the adapter.
- NOT SOURCEABLE: touch and mouse emulation settings, and the `canceled` flag on `InputEventScreenTouch`.
- NOT SOURCEABLE: `queue_free` against `free` timing, `weakref` and `is_instance_valid` timing, and freed-object Callables.
- NOT SOURCEABLE: safe-area query and conversion to field units (`DisplayServer`), and the stretch and aspect behaviour on taller phones.
- NOT SOURCEABLE: `FileAccess` flush and close behaviour for the debug log on mobile.
- NOT SOURCEABLE: `Vector2` component precision against the 64-bit float the GDDs assume for `PinGeometry`.
- NOT SOURCEABLE: draw-call batching for one `_draw` node against the budget of 8 expected and 12 at most.

Because the GDDs also state these from memory, the whole group is routed to ADR-0001, ADR-0003, ADR-0006, ADR-0008 and ADR-0011, each of which must verify against live 4.7 documentation and a phone run before it is Accepted.

## System Layer Map

The five-layer model applies with one addition that this game needs: every module is either **sim** (plain objects with no scene tree, runs headless under bots and tests) or **shell** (nodes, Controls and drawing, absent headless). The sim never references the shell. This is the rule the GDDs lean on most (Flow Rules 2 to 4, Tower and Hero "two pieces", HUD Rule 1), so it is the first principle below and the subject of ADR-0002.

```
 PRESENTATION   SHELL   HudTopBand  HudField  Modal screens (Result, Paused)  FieldView  TowerView
                        HeroView  CombatView  FatalScreen  HumanLog
                SIM     HudLogic (plain, tested with fakes)
 ---------------------------------------------------------------------------------------------
 FEATURE        SIM     EnemyWave        TowerSim          HeroSim
                SHELL   (none)           TowerInput        HeroInput
                                         + ChipWindow*     + PinGeometry*      (* plain classes)
 ---------------------------------------------------------------------------------------------
 CORE           SIM     FlowSim          Combat            InputResolver*
                SHELL   BattleWrapper (tick loop)          InputAdapter
 ---------------------------------------------------------------------------------------------
 FOUNDATION     SIM     Catalogue (Loader, Validator, StatAccessor)       BattleBuilder
                SHELL   AppRoot (main scene, no autoload)
 ---------------------------------------------------------------------------------------------
 PLATFORM        Godot 4.7.2 (Mobile renderer, 2D), Android and iOS, desktop for development
```

\* InputResolver is a plain object but is built only by the wrapper, so headless bots never see it (Input Rule 11).

**Layer assignment, with the reason for each.**

| System (index #) | Layer | Reason | Engine risk touched |
|---|---|---|---|
| Data & Config Pipeline (1) | Foundation | Everything reads it; it depends on nothing but the engine's file API | GDScript typing (HIGH) |
| Game State & Stage Flow (3) | Foundation for AppRoot and BattleBuilder; Core for FlowSim | The systems index calls it Core. The composition root and the catalogue holder have to exist before any other module, so they are Foundation; the phase machine and lives are Core. One GDD, two layers | Lifecycle notifications, pause, fixed tick (NOT SOURCEABLE) |
| Input & Gesture Resolver (2) | Core | Turns touches into gestures for Feature and Presentation owners | Input (HIGH), device IDs, dual focus |
| Combat & Damage (4) | Core | One damage path that both Feature systems call; reads no data and depends on nothing | GDScript only |
| Enemy & Wave (5) | Feature | Gameplay: stage, roster, spawning, movement | GDScript only |
| Tower System (6) | Feature | Gameplay: towers and gold | Input for TowerInput |
| Hero System (7) | Feature | Gameplay: pin and burst | Input for HeroInput |
| Battle HUD & Build UI (8) | Presentation | Draws and sends commands; owns no game state | UI (HIGH), Rendering (HIGH), stretch (HIGH) |

The systems index lists Combat under the Gameplay category. The architecture puts it in Core because Tower, Hero and Enemy & Wave all call it and it calls none of them. The category is a design grouping; the layer is a dependency rule.

**Dependency rules.**

1. A module may depend on modules in its own layer or below, never above.
2. Sim modules never depend on shell modules. Shell modules read sim state and send commands, and never write it.
3. Within Feature, EnemyWave, TowerSim and HeroSim do not call each other. They meet through Combat (damage), the roster that EnemyWave exposes (`targets()`), and signals the builder wires.
4. BattleBuilder is the composition root. It is the one place allowed to reference every layer, it only wires, and a branch on a gameplay value inside it is a defect (Flow Rule 3).

**Alternatives considered.** (a) A single autoload event bus for all cross-system messages: rejected by the GDDs (Flow "Deliberately not built") because an unconnected signal becomes a silent bug and tests cannot isolate systems; explicit connections in one builder function give the parser a chance to catch a misspelt name. (b) A scene-owned battle root as the technical director's note first said: rejected in Flow Rule 2 because a scene-owned root cannot run headless, and bots measure the game. (c) Treating the sim and shell split as a convention only: rejected, because without a test that the sim loads with no scene tree the split decays. ADR-0002 adds that test.

## Module Ownership

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Catalogue | Every authored gameplay record (Tower, Enemy, Wave, Stage, Hero, Burst, Input), read-only after load | `read(ctx, key)`, `level_count(def_id)`, `is_tower(id)`, typed record lookup | Data files named in the manifest | `FileAccess` or `ResourceLoader` (format decided in ADR-0004), typed `Array` and `Dictionary` (HIGH: GDScript) |
| CatalogueValidator | The error list `{code, source, record_id, field}` | `validate(records) -> Array[Error]` | Records | none |
| BattleBuilder | Wiring of one battle | `build(catalogue, stage_id, seed, fatal_handler) -> Battle` | Catalogue and every sim module | none: plain GDScript |
| AppRoot (main scene) | The Ready catalogue, the retry latch, the Fatal latch, the fatal screen, the presentation session flags (`pinned_once`, `built_once`, `won_once`) and the Retry-to-Start timer | Starts the load, builds and frees battles | Catalogue, BattleBuilder, BattleWrapper | `Node`, scene tree notifications and free timing (NOT SOURCEABLE) |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| FlowSim | Phase (Build, Wave, Intermission, Paused, Won, Lost, Fatal), lives, `intermission_left`, the outcome latch | `tick(dt)`, `start_next_wave()` command via the HUD, `call_early()`, `retry` latch read, `halted()`, `in_build()`, `in_tick()`, signals `phase`, `lives_changed`, `wave_called_early` | EnemyWave signals, Stage record | none |
| Combat | Health and Status per enemy, the damage counters, the targeting helpers | `deliver`, `apply_slow`, `report_attack`, `first_in`, `nearest_in`, `all_in_radius`, `hp_left`, `is_dead`, `speed_factor`, `tick_status`, `dealt_by_id`, `dealt_by_kind`; signals `attack_fired`, `damage_applied` | Nothing (callers pass values in) | none |
| InputResolver | The target registry, the single active pointer, the two frozen winners | `press`, `move`, `release`, `cancel`, `cancel_pointer`, `register`, `unregister`; signals `pressed`, `tap`, `ground_tap`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `idle` | Input record (two slops, injected) | none: plain object |
| InputAdapter (shell) | The mapping from engine events to the resolver's five calls, the edge reject margin, lifecycle `cancel()` | `attach(resolver)` | `InputEvent` stream, lifecycle notifications | `InputEventScreenTouch`, `InputEventScreenDrag`, `InputEventMouseButton`, `DEVICE_ID_MOUSE` (HIGH, 4.7), `PROCESS_MODE_ALWAYS` |
| BattleWrapper (shell) | The real-time accumulator and the tick loop | Calls `battle.tick(dt)` | Battle | `_process` (or `_physics_process`, NOT SOURCEABLE), `Engine.time_scale` |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| EnemyWave | The stage geometry in use, the wave index, the spawn schedule, the roster, `spawn_id`, leaks, reaping, per-wave clearing | `start_next_wave()`, `roster()`, `targets()`, `wave_index()`, `got_through_by_type()`, `advance(...)`, `reap(...)`; signals `enemy_killed`, `enemy_leaked`, `wave_cleared`, `waves_complete` | Catalogue (Wave, Stage, Enemy), Combat (Health, Status), `halted()` | none |
| TowerSim | Gold, slot states, tower instances, attack timers | `build`, `upgrade`, `gold()`, `slot_state()`, `tick`; signals `gold_changed`, `tower_built`, `tower_upgraded`; receives `enemy_killed` and `wave_called_early` | Catalogue, Combat, `targets()`, `halted()` | none |
| HeroSim | Pin, position, walk, attack and burst timers, counters | `pin`, `burst`, `position()`, `pin_target()`, `pin_state()`, `burst_state()`, `cooldown_left()`, `tick`; signals `hero_pinned`, `burst_started` | Catalogue, Combat, `targets()`, `halted()`, `in_build()` | none |
| TowerInput (shell) | The chip window feed, tower and slot target registration | `slot_tapped`, `tower_inspected`, `chip_state()` | InputResolver, TowerSim, FlowSim `phase` | `Node` |
| ChipWindow | The 200 to 1500 ms upgrade window | `advance(ms)`, `open`, `close`, `elapsed` | Nothing | none: plain class |
| HeroInput (shell) | Hero and button registration, aim state, preview | `aim_state()`, `aim_point()`, `aim_ring_radius()`, `preview_kills()`, `cooldown_digit()`, `update()` | InputResolver, HeroSim, Combat helpers | `Node` |
| PinGeometry | Pin validity and `clamp_pin` | `is_valid`, `clamp` | Stage shapes | none: plain class, scalar `float` fields |

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| HudLogic | Arc model, armed buttons, prompt choice, session-flag reads, result text, the human-log records | Plain methods tested with fakes; `advance(ms)` | Reads of every sim module | none |
| HudTopBand | Lives, pips, gold, next-wave line, prompt row | none | HudLogic | `Control`, `Label`, `mouse_filter` IGNORE (HIGH: UI) |
| HudField | The arc, chip, Start/Call, burst button art, ground rings; their Input discs | none | HudLogic, InputResolver | `CanvasItem._draw`, `queue_redraw`, `draw_string` (HIGH: line thickness in 4.7) |
| Modal screens | Result and Paused | Retry, Play again, resume | HudLogic | `Control`, `mouse_filter` STOP, `focus_mode` NONE (HIGH: dual focus) |
| FieldView, TowerView, HeroView, CombatView | Path, slots, enemies, towers, hero, lines, flashes, range rings, kill preview | none | Sim reads and the view-allowlist signals | `CanvasItem._draw` |
| FatalScreen | The generic failure text, which uses no catalogue data | none | A cause string | `Control` |
| HumanLog | `user://run_log.jsonl`, debug builds only | `record_attempt`, `record_call` | HudLogic snapshot | `FileAccess` (MEDIUM: 4.4 `store_*` return `bool`) |

### Dependency diagram

```
                 AppRoot ──── owns ──── Catalogue
                    │  builds                │ read-only
                    ▼                        ▼
              BattleBuilder ──wires──▶ ┌──────────────────────────────────────────┐
                                       │ Battle (sim, headless)                    │
                                       │                                           │
                                       │  FlowSim ◀──signals── EnemyWave           │
                                       │     │ phase, halted      │ roster, targets │
                                       │     ▼                    ▼                 │
                                       │  TowerSim ──deliver──▶ Combat ◀──deliver── HeroSim
                                       │     ▲ enemy_killed       ▲                  │
                                       └─────┼──────────────────┼──────────────────┘
        BattleWrapper ── tick(dt) ──────────▶│                   │ reads (views, HUD)
        InputAdapter ▶ InputResolver ▶ TowerInput ─build/upgrade─┤
                                       HeroInput  ─pin/burst─────┤
        HudLogic ◀── reads ──────────────────────────────────────┘
        HudLogic ── Start/Call, Retry, resume ──▶ FlowSim, AppRoot
```

Tick order (Combat Rule 11, confirmed by Enemy & Wave and Flow): FlowSim, then EnemyWave advance (spawn, move, leak), Combat status countdown, TowerSim by slot index, HeroSim (hero attack, then burst), then EnemyWave reap (kills, then the clear check). The wrapper calls `battle.tick(dt)`; the battle owns that order and no module reorders it.

**Engine awareness check.** Every engine API in the tables was checked against the pinned reference. Verified: typed `Array`, typed signals and `Callable` connections (deprecated-apis patterns), `_draw` and `queue_redraw` (rendering module, with the 4.7 line-thickness change), `Control.mouse_filter` and recursive disable (ui module, 4.5), `DEVICE_ID_MOUSE` (input module, 4.7), `FileAccess.store_*` returning `bool` (breaking-changes 4.4). Not verifiable from the reference: see the NOT SOURCEABLE list above.

## Data Flow

Single thread. Nothing in the sim crosses a thread boundary. The one question is the debug log write (ADR-0013), which runs on the main thread and is flagged there.

### 1. Boot and initialisation order

```
 engine starts ─▶ AppRoot._ready
   1. Catalogue.load(manifest)          validate all, collect all errors, fail whole
        └─ failure ─▶ FatalScreen (no catalogue data) ; stop
   2. AppRoot builds InputAdapter + resolver factory (shell)
   3. BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)
        a. Combat
        b. FlowSim              (stage record, starting_lives)
        c. EnemyWave            (stage, waves, Combat)
        d. TowerSim             (starting_gold, Combat, EnemyWave.targets)
        e. HeroSim              (hero, burst, Combat, EnemyWave.targets)
        f. connect signals      (one function, explicit Callables)
   4. BattleWrapper builds InputResolver, TowerInput, HeroInput, HudLogic, views
   5. first tick loop frame
```

Order rule: a module boots after everything it reads. Combat reads nothing, so it is first. Wiring (3f) comes after every module exists, so a signal can never fire into a missing listener. A fatal during `build` discards the partial battle without ticking it (Flow Rule 18).

### 2. Frame update path

```
 each rendered frame
   InputAdapter._input(event) ─▶ InputResolver.press/move/release
        └─ gestures ─▶ TowerInput / HeroInput / HudLogic handlers
              └─ commands (build, upgrade, pin, burst, start/call, retry latch)    [between ticks]
   BattleWrapper._process(delta)
        accumulate real time (clamped) ; while owed ticks: battle.tick(1/60)
              FlowSim ▶ EnemyWave.advance ▶ Combat.tick_status ▶ TowerSim ▶ HeroSim ▶ EnemyWave.reap
   HudLogic.advance(ms) ; views read sim state ; queue_redraw where state changed
```

Data names: input events (producer engine, consumer adapter, synchronous call); gestures (resolver to owners, signal); commands (owners to sim, synchronous call with a result code); tick (wrapper to battle, synchronous call); sim state (read by views and HUD, shared state read-only). Commands run before the frame's ticks; this order is unverified and ADR-0001 must check it (HUD Rule 18).

### 3. Event and signal paths

| Event | Producer | Consumers | Kind | Notes |
|---|---|---|---|---|
| `enemy_killed(bounty)` | EnemyWave (reap) | TowerSim | signal, synchronous | Gold is spendable from the next command |
| `enemy_leaked(lives_cost)` | EnemyWave (advance) | FlowSim | signal, synchronous | Fires before `waves_complete`; a fatal leak stops the loop |
| `wave_cleared(seconds)` | EnemyWave (reap) | FlowSim | signal | Payload is the intermission in seconds |
| `waves_complete()` | EnemyWave (reap) | FlowSim | signal | Ignored after a Lost |
| `wave_called_early(seconds_left)` | FlowSim | TowerSim | signal | Bonus paid before the next spawn and before `phase(WAVE)` |
| `phase(p)`, `lives_changed(n)` | FlowSim | HudLogic, TowerInput, views | signal, view allowlist | Emitted after state is committed |
| `gold_changed`, `tower_built`, `tower_upgraded` | TowerSim | HudLogic, views | signal, view allowlist | Nothing in gameplay depends on them |
| `hero_pinned`, `burst_started` | HeroSim | HudLogic, views | signal, view allowlist | Handlers never issue commands |
| `attack_fired`, `damage_applied` | Combat | CombatView | signal, view allowlist | Copied positions |
| `pressed`, `tap`, `drag_*`, `ground_tap`, `idle` | InputResolver | owners that registered | signal | Frozen winners per gesture |

Wiring is tested, not trusted: one test fails if any battle signal has no listener unless it is on the view allowlist (Flow, wiring paragraph).

### 4. Gameplay scenarios

**Kill to next wave.** `Combat.deliver` brings HP to 0, then the corpse waits for the reap slot. EnemyWave reaps in ascending `spawn_id`, reads `bounty` through the accessor, removes the corpse, emits `enemy_killed` (TowerSim adds gold, emits `gold_changed`), then runs the clear check. A wave that is clear emits `wave_cleared(15.0)` (or `waves_complete` on the last), FlowSim enters Intermission with `intermission_left = to_ticks(15.0)` and emits `phase(INTERMISSION)`, and the HUD arms Start/Call over 300 ms.

**Leak to Lost.** In EnemyWave's advance slot an enemy reaches the path end, reads `lives_cost`, leaves the roster, emits `enemy_leaked`. FlowSim applies `lives_after = max(0, lives_before - lives_cost)`, emits `lives_changed`, and on 0 commits Lost, calls `cancel()`, emits `phase(LOST)`. `halted()` is now true, so EnemyWave, TowerSim and HeroSim return at once and nothing pays a bounty. The HUD snapshots results on the next frame and shows the screen after 400 ms.

**Early call.** The HUD sends call. FlowSim emits `wave_called_early(seconds_left)`; TowerSim pays `to_ticks(seconds_left) div to_ticks(rate)`; FlowSim then calls `EnemyWave.start_next_wave()` and emits `phase(WAVE)`. The first spawn is on the next tick.

**Retry.** The Retry tap sets a latch on AppRoot. AppRoot's frame checks Fatal first, then stops the clock, cancels input, frees the old battle, builds a new one with the same stage and seed, and the wrapper rebuilds resolver, HUD and views. The catalogue and the session flags survive; nothing else does.

**Focus loss.** The adapter and FlowSim enter Paused: the clock stops, input cancels, the accumulator is zeroed. A tap resumes and reaches nothing beneath. Which notification triggers this is NOT SOURCEABLE until ADR-0001.

**Fatal.** Any system calls the injected `fatal_handler(cause)`. It is idempotent, keeps the first cause, latches on the battle and the root, and stops all ticking in the same tick. The root shows FatalScreen. Systems check `halted()` after every accessor read and every signal, because GDScript has no exceptions and a function keeps running on a garbage value.

### 5. Save and load

None at MVP. Nothing is saved: an app killed by the OS loses the stage, there is no save file, and the catalogue is content shipped in the build. The only file written is the debug human log under `user://`, in debug builds, which is not a save. No module owns serialisation. Stage Progression and Save/Load (Vertical Slice) will add one; their ADR is deferred, and the catalogue's stable IDs and the "no fallbacks" rule are what they inherit.

### 6. Determinism path

The same stage, seed and command script give an identical result (Flow Rule 5). Randomness uses the injected seed, though no MVP system reads it; cosmetic jitter never uses it. Time enters only through `tick(dt)`. Authored seconds become whole ticks through one function, `to_ticks(seconds) = round(seconds / dt)`, halves away from zero. Bot baselines are kept per CPU architecture because float results may differ between x86 and ARM (Combat Edge Cases, unverified).

## API Boundaries

Language: typed GDScript. Types below are the contract. Engine types are flagged where they appear.

### Catalogue (Foundation)

```gdscript
class_name Catalogue extends RefCounted   # engine type: RefCounted (stable)

enum StatKey { COST, DAMAGE, RANGE, ATTACK_INTERVAL, SPLASH_RADIUS, SLOW_STRENGTH, SLOW_DURATION,
               BOUNTY, LIVES_COST, MAX_HP, MOVE_SPEED, LEASH_RADIUS, WALK_SPEED, RADIUS, REACH,
               COOLDOWN, TELEGRAPH_DURATION }

func read(ctx: ReadContext, key: StatKey) -> Variant   # returns the type the key table declares
func level_count(def_id: StringName) -> int             # non-fatal; callers never ask past the maximum
func is_tower(id: StringName) -> bool                   # non-fatal
func stage(id: StringName) -> StageRecord               # structural fields read directly
```

Invariants: records are read-only after load; callers never cache what `read` returns (the next use reflects a changed value); a bad key or a wrong-type context calls the injected failure handler and returns a safe value, and the caller checks `halted()` before using it. Guarantee: either every record is valid or the game does not start.

### Battle (the facade the wrapper and bots hold)

```gdscript
class_name Battle extends RefCounted

func tick(dt: float) -> void          # the only entry for simulation time; returns at once when Paused or halted
func halted() -> bool                 # true on Won, Lost and Fatal
func in_build() -> bool               # Hero refuses the burst here
func in_tick() -> bool                # true while the battle's tick slots run; Combat.deliver checks it
signal phase(p: int)                  # enum Phase.BUILD ... FATAL
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
```

### Combat

```gdscript
class_name Combat extends RefCounted

func deliver(event: DamageEvent) -> float                      # returns applied; 0 outside a tick or on a bad amount
func apply_slow(enemy: Variant, strength: float, seconds: float) -> void   # rejects strength outside (0,1)
func report_attack(source_kind: int, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func first_in(list: Array, origin: Vector2, range_: float) -> Variant      # enemy or null
func nearest_in(list: Array, origin: Vector2, range_: float) -> Variant
func all_in_radius(list: Array, center: Vector2, radius: float) -> Array
func hp_left(enemy: Variant) -> float
func is_dead(enemy: Variant) -> bool
func speed_factor(enemy: Variant) -> float
func tick_status(roster: Array) -> void
func dealt_by_id(source_id: StringName) -> float
func dealt_by_kind(kind: int) -> float
signal attack_fired(source_kind: int, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(event: DamageEvent, applied: float, position: Vector2)
```

`enemy: Variant` stands for the enemy instance type that ADR-0007 fixes. `Vector2` is an engine type whose component precision is NOT SOURCEABLE here; the sim keeps positions as scalar `float` where exact comparison matters (`PinGeometry`, helpers) until the ADR decides.

### EnemyWave

```gdscript
class_name EnemyWave extends RefCounted

func start_next_wave() -> void              # called by FlowSim; a start during Active or past the last is ignored with a development error
func advance(...) -> void                   # spawn, move, leak (tick slot 2)
func reap(...) -> void                      # kills, then clear check (last tick slot)
func roster() -> Array                      # every enemy not yet removed, corpses included, in spawn_id order; read-only
func targets() -> Array                     # roster limited to enemies inside the field; read-only
func wave_index() -> int
func got_through_by_type() -> Dictionary    # view-only counts for the result
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
func slot_state(slot_index: int) -> Variant                      # empty, or tower_id, level, cooldown_left
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)
signal tower_upgraded(slot_index: int, level: int)
```

Each enum above is a separate named enum per class; two classes both defining `HALTED` do not share one enum. Guarantee: a refusal changes nothing and emits nothing.

### HeroSim

```gdscript
class_name HeroSim extends RefCounted

enum PinResult { OK, HALTED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE }
enum BurstResult { OK, HALTED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH }
func pin(position: Vector2) -> PinResult
func burst(aim_point: Vector2) -> BurstResult
func position() -> Vector2
func pin_target() -> Vector2
func pin_state() -> int
func burst_state() -> int
func cooldown_left() -> int
signal hero_pinned(position: Vector2)
signal burst_started(aim_point: Vector2, telegraph_ticks: int)
```

HeroInput changes the battle only through `pin` and `burst`; one equivalence test keeps a resolver-driven script and a direct-command script identical.

### InputResolver

```gdscript
class_name InputResolver extends RefCounted

static func create(drag_slop: float, tap_slop: float) -> InputResolver   # null when validate() is false
func register(target: HitTarget) -> int     # shape, priority, gestures accepted, enabled flag
func unregister(id: int) -> void
func press(pointer: int, p: Vector2) -> void
func move(pointer: int, p: Vector2) -> void
func release(pointer: int, p: Vector2) -> void
func cancel() -> void
func cancel_pointer(pointer: int) -> void
signal pressed(best_tap: Variant, best_drag: Variant, p: Vector2)
signal tap(target: Variant, p: Vector2)
signal ground_tap(p: Vector2)
signal drag_started(target: Variant, press_pos: Vector2, p: Vector2)
signal drag_moved(target: Variant, press_pos: Vector2, p: Vector2)
signal drag_ended(target: Variant, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(target: Variant)
signal idle()
```

The resolver is clock-free and emits no per-frame signal. A gesture reaches only its class winner or nothing, and the winners are frozen at press.

### Shell to sim commands

| From | To | Call | Result |
|---|---|---|---|
| HudLogic (Start/Call) | FlowSim | `start()` in Build, `call_early()` in Intermission | ignored when the phase does not match; `wave_called_early` only for a real call |
| HudLogic (Retry) | AppRoot | set the retry latch | idempotent; Fatal wins in the same frame |
| HudLogic (resume) | FlowSim | `resume()` | only from Paused |
| HudLogic (arc disc) | TowerSim | `build(slot, id)` | `Result`; `NO_GOLD` leaves the arc open |
| TowerInput (chip commit) | TowerSim | `upgrade(slot)` | `Result`; the only way TowerInput changes state |
| HeroInput | HeroSim | `pin(position)`, `burst(aim_point)` | result enums above |

**Engine awareness check.** Types used in contracts: `RefCounted`, `Signal` and typed signals, `Callable`, `Vector2`, `StringName`, typed `Array` and `Dictionary`. All are stable across 4.3 to 4.7 as far as the pinned reference shows. Two 4.7 rules apply to every class here: an override of a typed-return method inherits that return type and needs an explicit `return`, so base classes expose typed returns only where every override is written to match; and writing one element of a packed array no longer calls the property setter, so a setter on a packed-array property cannot be relied on for element writes.

## ADR Audit

Existing ADRs: none. `docs/architecture/` holds only the empty TR registry. The quality check is therefore vacuous: nothing conflicts with the layers and ownership above, and nothing is stale for 4.7.2.

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|-----|--------------|---------|-------------|-----------|-------|
| (none exist) | n/a | n/a | n/a | n/a | n/a |

### Technical Requirements Baseline

Extracted from 8 GDDs | 66 total requirements | 0 registered, 66 provisional
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
| TR-data-007 (provisional) | data-config-pipeline | Data | No fallbacks in any build; a bad accessor call reaches the failure handler and the Fatal screen | Core | ADR-0001 |
| TR-data-008 (provisional) | data-config-pipeline | Data | A CI content test opens each `scene_ref` and applies the layout, wave and tower rules to the records | Testing | ADR-0012 |
| TR-data-009 (provisional) | data-config-pipeline | Data | Edit a value, save, run: the new value is in the game within 10 s, no live reload | Tooling | ADR-0004 |
| TR-input-001 (provisional) | input-gesture-resolver | Input | One active pointer; two winners (tap, drag) frozen at press; tap and drag classified by slop; a gesture reaches only its class winner | Input | ADR-0006 |
| TR-input-002 (provisional) | input-gesture-resolver | Input | A registry of discs with priority, accepted gestures and an enabled flag; owners register and unregister themselves | Input | ADR-0006 |
| TR-input-003 (provisional) | input-gesture-resolver | Input | The adapter maps engine events to five calls, applies the edge reject margin, runs while the tree is paused, and calls `cancel()` on lifecycle events | Input | ADR-0006 |
| TR-input-004 (provisional) | input-gesture-resolver | Input | The resolver is clock-free and emits one `drag_moved` per input call, never per frame | Input | ADR-0006 |
| TR-input-005 (provisional) | input-gesture-resolver | Input | The resolver is built only by the wrapper; bots call commands; one equivalence test through the resolver | Core | ADR-0002 |
| TR-input-006 (provisional) | input-gesture-resolver | Input | A development-build gesture log with the Rule 13 fields | Tooling | ADR-0013 |
| TR-input-007 (provisional) | input-gesture-resolver | Input | All thresholds and hit radii are in field units on the 540 x 960 field; hit targets are at least 48 dp | Input | ADR-0008 |
| TR-flow-001 (provisional) | game-state-stage-flow | Flow | The app root is a minimal main scene with no autoload; it holds the catalogue, the fatal screen, the retry latch and the presentation session flags | Core | ADR-0001 |
| TR-flow-002 (provisional) | game-state-stage-flow | Flow | `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)` constructs and wires one battle with explicit connections and no scene | Core | ADR-0001 |
| TR-flow-003 (provisional) | game-state-stage-flow | Flow | Simulation time enters only through `battle.tick(dt)` at a fixed 1/60 s tick; no `_process`, engine timer, `await`, wall clock or physics area in gameplay | Core | ADR-0003 |
| TR-flow-004 (provisional) | game-state-stage-flow | Flow | A fixed system tick order; commands apply only between ticks | Core | ADR-0003 |
| TR-flow-005 (provisional) | game-state-stage-flow | Flow | A phase machine (Build, Wave, Intermission, Paused, Won, Lost, Fatal) with an outcome latch and `halted()`, `in_build()`, `in_tick()` | Core | ADR-0005 |
| TR-flow-006 (provisional) | game-state-stage-flow | Flow | Lives formula `max(0, before - cost)`; leak events synchronous and before `waves_complete`; a fatal leak beats a clear | Core | ADR-0005 |
| TR-flow-007 (provisional) | game-state-stage-flow | Flow | Retry destroys and rebuilds the whole battle with the same seed, through a latch on the root, Fatal first | Core | ADR-0001 |
| TR-flow-008 (provisional) | game-state-stage-flow | Flow | Focus loss enters Paused: clock stops, input cancels, accumulator zeroed, a tap resumes | Platform | ADR-0001 |
| TR-flow-009 (provisional) | game-state-stage-flow | Flow | The failure handler is idempotent, keeps the first cause, discards a partial battle, and shows a generic screen with no catalogue data | Core | ADR-0001 |
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
| TR-wave-006 (provisional) | enemy-wave | Enemy & Wave | Layout rules L1 to L14 and the wave rules run in the content test | Testing | ADR-0012 |
| TR-wave-007 (provisional) | enemy-wave | Enemy & Wave | An enemy is targetable only inside the field; everything outside the field is masked on any screen shape | Rendering | ADR-0008 |
| TR-wave-008 (provisional) | enemy-wave | Enemy & Wave | At most 48 enemies alive; the view pool matches | Performance | ADR-0009 |
| TR-wave-009 (provisional) | enemy-wave | Enemy & Wave | One add-enemy step serves the schedule and later splitter children | Core | ADR-0009 |
| TR-tower-001 (provisional) | tower-system | Tower | TowerSim (headless) and TowerInput (wrapper only); TowerInput changes state only through `upgrade` | Core | ADR-0010 |
| TR-tower-002 (provisional) | tower-system | Tower | `build` and `upgrade` return ordered result codes, work in every phase, and are shared by players and bots | Core | ADR-0010 |
| TR-tower-003 (provisional) | tower-system | Tower | Gold is one non-negative integer; kills and early calls add, the two commands spend; the bonus is `to_ticks(seconds_left) div to_ticks(rate)` | Core | ADR-0010 |
| TR-tower-004 (provisional) | tower-system | Tower | Attack timers in integer ticks with ready-and-holding; a slow tower prefers an empty slow slot | Core | ADR-0010 |
| TR-tower-005 (provisional) | tower-system | Tower | A pure `ChipWindow` fed real milliseconds (200 to 1500) and a chip disc registered while open | Input | ADR-0010 |
| TR-tower-006 (provisional) | tower-system | Tower | Signals `gold_changed`, `tower_built`, `tower_upgraded`; wrapper-only `slot_tapped`, `tower_inspected`, `chip_state()` | Core | ADR-0005 |
| TR-tower-007 (provisional) | tower-system | Tower | Content rules: two levels, cost bounds, the bonus share, `gold_before_last_wave` below the cheapest full board | Testing | ADR-0012 |
| TR-hero-001 (provisional) | hero-system | Hero | HeroSim (headless) and HeroInput (wrapper only); HeroInput changes the battle only through `pin` and `burst` | Core | ADR-0010 |
| TR-hero-002 (provisional) | hero-system | Hero | Ordered result codes for `pin` and `burst`; a straight-line walk in whole ticks; `PinGeometry.clamp` as a plain class | Core | ADR-0010 |
| TR-hero-003 (provisional) | hero-system | Hero | Aim in HeroInput with cancel hysteresis (64 and 48), recomputed every frame while the hero walks | Input | ADR-0010 |
| TR-hero-004 (provisional) | hero-system | Hero | Telegraph and cooldown in integer ticks; release in the hero slot; burst counters | Core | ADR-0010 |
| TR-hero-005 (provisional) | hero-system | Hero | The kill preview projects enemy positions to landing | Presentation | ADR-0011 |
| TR-hero-006 (provisional) | hero-system | Hero | Scripted bots reproduce the share gate headless on the fixed tick | Testing | ADR-0012 |
| TR-hud-001 (provisional) | battle-hud | HUD | Three pieces: HudLogic (plain, testable), HudTopBand (Controls), HudField (one `_draw` plus Input discs) | Presentation | ADR-0011 |
| TR-hud-002 (provisional) | battle-hud | HUD | Result and Paused screens are Controls that consume every event; everything else tappable is an Input disc | Input | ADR-0006 |
| TR-hud-003 (provisional) | battle-hud | HUD | Commands run from the input call stack before the frame's ticks; Retry only sets a latch | Core | ADR-0001 |
| TR-hud-004 (provisional) | battle-hud | HUD | Real-time models run on `advance(ms)` clamped to 100 ms and ignored while Paused | Core | ADR-0003 |
| TR-hud-005 (provisional) | battle-hud | HUD | Draw budget: about 8 and at most 12 of 60 draw calls; at most 3 text draws | Performance | ADR-0011 |
| TR-hud-006 (provisional) | battle-hud | HUD | A debug-only `user://run_log.jsonl` with one record per attempt and per call | Persistence | ADR-0013 |
| TR-hud-007 (provisional) | battle-hud | HUD | Layout in field units with safe-area insets converted at 360 dp (1 dp is 1.5 units) | Rendering | ADR-0008 |
| TR-hud-008 (provisional) | battle-hud | HUD | Every hit target is at least 48 dp, with no margin at 360 dp | Input | ADR-0006 |
| TR-hud-009 (provisional) | battle-hud | HUD | Prompt retirement flags survive a retry and reset when the app restarts | Core | ADR-0001 |
| TR-hud-010 (provisional) | battle-hud | HUD | The HUD is absent headless; nothing in the battle depends on it | Core | ADR-0002 |
| TR-hud-011 (provisional) | battle-hud | HUD | Modal screens use `focus_mode` NONE and top-band Controls use `mouse_filter` IGNORE (4.6 dual focus) | UI | ADR-0006 |
| TR-hud-012 (provisional) | battle-hud | HUD | Every HUD timer runs on one `advance` clock; the chip bar displays Tower's window | Core | ADR-0003 |

### Traceability Coverage Check

Coverage: 0 covered by an accepted or proposed ADR, 66 gaps. Each gap is a **Required New ADR** below. Gap count per proposed ADR: ADR-0001: 8, ADR-0002: 2, ADR-0003: 9, ADR-0004: 7, ADR-0005: 8, ADR-0006: 8, ADR-0007: 6, ADR-0008: 3, ADR-0009: 3, ADR-0010: 12, ADR-0011: 3, ADR-0012: 4, ADR-0013: 2 (the last column of the table is the source of these counts).

## Required ADRs

Grouped by layer, Foundation first. Run order inside a group is top to bottom.

**Foundation (must exist before any coding):**

1. ADR-0001 App Lifecycle and Composition: the app root, `BattleBuilder`, the retry latch and teardown, the pause mechanism and the lifecycle notifications on each platform (including a development override so a click on the debugger does not pause), the fatal screen, input before ticks in a frame. Covers TR-data-007, TR-flow-001, 002, 007, 008, 009, TR-hud-003, 009. Engine risk: HIGH, with NOT SOURCEABLE items that it must verify.
2. ADR-0002 Simulation and Shell Boundary: the headless contract (sim loads with no scene tree), `RefCounted` against `Node` rules, the test seams the criteria assume (injected recording systems, enumerating a battle's systems, a snapshot), typed GDScript conventions including the 4.7 override rule. Covers TR-input-005, TR-hud-010.
3. ADR-0003 Fixed Tick, Time and Determinism: the 1/60 tick, where the accumulator lives and its clamp, `to_ticks`, the tick order, the seed, float policy and per-architecture baselines, the HUD `advance(ms)` clock. Covers TR-flow-003, 004, 011, 012, TR-wave-002, 004, TR-hud-004, 012. Engine risk: NOT SOURCEABLE.
4. ADR-0004 Catalogue Format, Loader, Validator and Stat Accessor: the data file format and manifest, the error structure, the typed accessor and read context, the Stage record, injection. Covers TR-data-001 to 006, 009, TR-wave-001 (the data half).
5. ADR-0005 Signal and Command Contracts: typed signals, emit order, re-entrancy (whether a listener may call a command), the phase enum and payloads, `halted()` and `in_tick()`, the wiring test and its allowlist. Covers TR-flow-005, 006, 010, TR-combat-006, TR-wave-003, 005, TR-tower-006.

**Core:**

6. ADR-0006 Input Adapter and Resolver Integration: which Godot input path feeds the adapter, Control against disc routing, touch and mouse emulation, the 4.7 device-ID rule, dual focus, lifecycle `cancel()`. Covers TR-input-001 to 004, TR-hud-002, 008, 011. Engine risk: HIGH, NOT SOURCEABLE.
7. ADR-0007 Combat Data Model: the enemy instance type, how Health and Status attach, `DamageEvent` type and allocation, the targeting helpers' contracts and cost measure. Covers TR-combat-001 to 005, 007.
8. ADR-0008 Stretch Mode, Safe Area and the Field: the 540 x 960 field on taller phones, masking outside the field, inset conversion, and the 4.7 stretch defaults. Covers TR-input-007, TR-wave-007, TR-hud-007. Engine risk: HIGH.

**Feature:**

9. ADR-0009 Enemy Roster, Position Cache and View Pooling: roster storage, the per-tick position, `spawn_id`, the 48-enemy pool, the add-enemy seam for splitters. Covers TR-wave-001 (the runtime half), 008, 009.
10. ADR-0010 Tower and Hero Systems: the sim and wrapper split for both, command result enums, `ChipWindow` and its real-time feed, `PinGeometry`, aim state and the shared aim-point function. Covers TR-tower-001 to 005, TR-hero-001 to 004.

**Presentation:**

11. ADR-0011 Field and HUD Rendering: one `_draw` per kind, the redraw policy (`queue_redraw` on change), the draw-call and text budgets and how to measure them, line widths after the 4.7 change, the kill preview. Covers TR-hero-005, TR-hud-001, 005.

**Testing and tooling:**

12. ADR-0012 Content Test and Bot Harness: the CI content test, the headless bot runner, gdUnit4 conventions. Covers TR-data-008, TR-wave-006, TR-tower-007, TR-hero-006.
13. ADR-0013 Debug Logs: the human log and gesture log, flush on mobile, thread. Covers TR-input-006, TR-hud-006. Deferrable.

**Priority.**

- Must have before coding starts (Foundation and Core): ADR-0001 to ADR-0008.
- Should have before the relevant system is built: ADR-0009 (before Enemy & Wave stories), ADR-0010 (before Tower and Hero stories), ADR-0011 (before HUD stories), ADR-0012 (before the first bot story).
- Can defer to implementation: ADR-0013.

## Architecture Principles

1. **The simulation never knows the scene tree.** Every gameplay module is a plain object that loads and runs with no node, renderer or real clock. The shell reads it and sends commands. A bot, a test and a phone all drive the same sim.
2. **One way in for time, one for commands.** Time enters only through `tick(dt)` at a fixed step; commands arrive only between ticks and return a result code. Nothing in gameplay uses `_process`, a timer, `await` or a wall clock.
3. **Data, not code, holds balance and geometry.** Gameplay numbers and stage layout are catalogue fields read at the moment of use. Nothing is cached, nothing has a fallback, and a bad read is Fatal. A composition root wires explicit connections; there is no global bus and no autoload.
4. **Refuse in the open, fail loudly.** Every refused command is a named result that changes and emits nothing. Every unrecoverable read stops the battle and shows a generic screen. A step that cannot run must say so; silence is never a pass.
5. **Views read; they never write.** Presentation draws from sim state and signals on an allowlist, and nothing in gameplay depends on a view.
6. **Engine behaviour that is not sourced is a gap, not a fact.** Anything the pinned reference does not cover is marked NOT SOURCEABLE and blocks Acceptance of the ADR that depends on it until that ADR cites the live 4.7 documentation or a device run.

## Open Questions

| ID | Summary | Priority | Resolution Path |
|----|---------|----------|-----------------|
| QQ-01 | Which lifecycle notification enters Paused on each platform, and how a desktop developer avoids pausing on every focus-out | High | ADR-0001 |
| QQ-02 | Where the fixed-tick accumulator lives and the clamp value | High | ADR-0001, ADR-0003 |
| QQ-03 | Control event order against the adapter, and whether a STOP Control hides events from it | High | ADR-0006 |
| QQ-04 | Stretch mode and masking on taller phones given the 4.7 expand default | High | ADR-0008 |
| QQ-05 | Catalogue file format and manifest form | High | ADR-0004 |
| QQ-06 | Enemy instance type (plain record or node) and how Health and Status attach | High | ADR-0007, ADR-0009 |
| QQ-07 | Does the technical director accept the BattleBuilder composition root, the TowerSim and TowerInput split, and cutting ProjectileSpawner (Combat Open Questions, Flow Open Questions)? | High | TD-ARCHITECTURE gate, then ADR-0001 and ADR-0010 |
| QQ-08 | The draw-call, memory and 400-check targeting budgets are unverified on a device | Medium | ADR-0011, ADR-0007, first phone build |
| QQ-09 | `Vector2` precision against the 64-bit float the pin-clamp rule assumes, and per-architecture bot baselines | Medium | ADR-0002, ADR-0003 |
| QQ-10 | Whether a listener may call a command from inside a signal (re-entrancy) | Medium | ADR-0005 |
| QQ-11 | Rendering backend: the project uses Mobile; the reference calls Forward+ desktop-focused, and the Compatibility fallback is untested | Low | ADR-0011 |
