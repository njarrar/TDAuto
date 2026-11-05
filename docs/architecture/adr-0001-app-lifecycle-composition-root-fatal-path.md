# ADR-0001: App Lifecycle, Composition Root and Fatal Path

## Status
Accepted

## Date
2026-11-03

## Last Verified
2026-11-03 (against `docs/engine-reference/godot/` for Godot 4.7.2 and `docs/architecture/architecture.md` v3; revised after TD-ADR and godot-specialist reviews)

## Decision Makers
- Accepted: 2026-11-04 by the user (njarrar); also records the user's sign-off on QQ-08's composition-root part (scene-free builder)
- Author: `/architecture-decision`, run in autonomous mode (decisions logged in `production/session-logs/decision-log.md`)
- Engine specialist (godot-specialist): CONCERNS, all findings resolved below (see Reviews)
- Technical director (TD-ADR): CONCERNS, all findings resolved below (see Reviews)
- Acceptance: the user. QQ-08's composition-root part (the scene-free builder) was accepted by the user 2026-11-04.

## Summary
TowerRiot needs one place that loads the catalogue, builds a battle, tears it down on retry and stops everything on a fatal error, without autoloads, so the battle runs the same headless and on a phone. This ADR decides a main-scene `AppRoot` with three app states, a scene-free `BattleBuilder` that injects method Callables whose targets `Battle` holds, recorded wiring that teardown undoes so retry frees the old battle whatever Godot's Callable reference rules turn out to be, and one idempotent two-level `FatalLatch` that ends on a code-built fatal screen.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core (app lifecycle and composition) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (architecture.md rates the App lifecycle row HIGH; the APIs this ADR itself calls date from 4.0 and show no change in 4.5 to 4.7 in `breaking-changes.md`, but it leans on three behaviours; (1) and (2) below are now verified) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md`; `docs/architecture/architecture.md` v3 (Layer Map, Module Ownership, Data Flow 4, 5, 7, API Boundaries B0, B4, B9, Required ADRs, Open Questions); `docs/architecture/tr-registry.yaml` |
| **Post-Cutoff APIs Used** | None. Used: `RefCounted`, `Callable`, `Signal.connect()` / `disconnect()` / `is_connected()`, `weakref()`, `Node.remove_child()`, `Node.queue_free()`, `Node.process_mode`, `Node.create_tween()`, `PackedScene.instantiate()`, `ResourceLoader.load()`, `push_error()`, `OS.is_debug_build()`, `Control`, `Label`, `ScrollContainer`. All exist since 4.0. 4.7's typed-return override rule applies to any class here that overrides a typed method. |
| **Verification Required** | (1) QQ-17, answered: method Callables and signal connections are weak; `bind()` args and lambda captures are strong (V1; verified 4.7.2 headless, see probe-results.md). (2) A subtree removed with `remove_child()` gets no further `_process`, `_input` or `_unhandled_input` callback before its queued free (V6; same). (3) That `push_error()` still reports in an exported release build, and under which log settings (test V8). None of these is in the pinned reference. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (catalogue format; this ADR fixes who loads it and where a load failure goes; ADR-0002 should not name a loader method `load`, which shadows the global `load()`), ADR-0003 (adapter; this ADR fixes who builds and frees it and who else calls `cancel()`), ADR-0004 (clock; this ADR fixes the wrapper that holds it), ADR-0005 (accessor; this ADR fixes one accessor per battle and the failure handler it calls), ADR-0006 (signals; this ADR fixes that every sim-signal connection goes through a `Wiring` record, which gives the listener-count test its list), ADR-0007 (harness; this ADR names the weakref, fatal and wiring tests), ADR-0009 (enemy entity; this ADR fixes the no-back-reference rule the weakref test needs), ADR-0010 (sims and inputs; this ADR fixes the Builder and the method Callables they connect with), ADR-0011 (views; this ADR fixes the wrapper that holds every view and `PresentationSettings`) |
| **Blocks** | Every MVP epic. No epic or story exists yet (`production/` holds none), so no story is blocked by path today. Once `/create-epics` runs, any story that builds AppRoot, the Builder, the BattleWrapper, the FatalLatch, the fatal screen or a retry path waits for this ADR to be Accepted. |
| **Ordering Note** | Write and accept first among ADR-0001 to ADR-0008 (architecture.md Priority). ADR-0003's device spike may change which notifications reach the adapter, but not anything this ADR decides. |

## Context

### Problem Statement
Eight MVP GDDs assume one composition root that nobody has designed yet. The Game State GDD (Rules 1 to 3, 16 and 18) asks for an app root with no autoload, a scene-free builder, retry by rebuild and one fatal path. Data asks that a load failure and a bad accessor call reach a fatal screen in every build, without `assert`. Enemy & Wave, Tower and Hero ask for an injected `halted()` and no reference to Flow. Tower and Flow ask that a retry leave no old battle alive, proved by a `weakref`. HUD asks that Retry never free its own caller.

These must be fixed before any code exists, because every other Foundation ADR plugs into them. Two facts the design leans on cannot be checked offline: whether a method `Callable` keeps its object alive on 4.7 (QQ-17), and whether a subtree removed from the tree can still get a callback before its queued free runs. The design must hold either way, and name the test that settles each.

### Current State
No code. `src/` holds only a `CLAUDE.md`. `project.godot` sets no main scene, no `[autoload]` section, no custom theme and no custom font. No other ADR exists. `docs/registry/architecture.yaml` holds only this ADR's entries.

### Constraints
- **Engine**: Godot 4.7.2, GDScript, single main thread (architecture.md Data Flow). GDScript has no exceptions, so a caller keeps running after a fatal call and must check `halted()`. `assert` is stripped from exported builds.
- **Architecture**: no autoloads (architecture.md Principle 2). Simulation classes extend `RefCounted`, never `Node` (B0). Nothing may depend on the composition root (Dependency rule 2).
- **Determinism**: a battle is a function of `(catalogue, stage_id, rng_seed, command script)`; gameplay classes never read `Engine`, `Time`, `OS`, timers or `await` (B4).
- **Team**: solo part-time developer. Keep the root small and the number of new classes low.
- **Testing**: everything in B0 to B2 and B4 to B9 runs headless in gdUnit4, the weakref test included.

### Requirements
- Load the catalogue once, all or nothing, before the first battle, and hold it across retries (TR-data-004, TR-data-011, TR-state-001).
- Build a battle with no node, from `build(catalogue, stage_id, rng_seed, fatal_handler)`, and wire it in one function (TR-state-002, TR-input-012, TR-hero-004).
- Inject `halted()` into every sim so none references Flow, and check it after every read and signal (TR-enemy-005, TR-tower-006).
- Give bad accessor calls and dev errors injected sinks that survive release builds (TR-data-009, TR-enemy-012).
- One idempotent fatal handler that keeps the first cause, halts the tick, discards a partial build and shows a screen that always loads and never opens saves (TR-data-006, TR-state-011).
- Retry by a latch on the root, acted on next frame, that tears down and rebuilds; a weakref to the old battle reads null and no signal connection keeps it alive (TR-state-009, TR-tower-013, TR-hud-006).

## Decision

### 1. App root and app states
- The main scene is `res://src/root/app_root.tscn`, a `Node` with script `AppRoot`. `project.godot` gets `[application] run/main_scene` set to it and never gets an `[autoload]` section.
- `AppRoot` owns: its app state (`BOOT`, `IN_STAGE`, `FATAL`), the Ready `Catalogue`, the failed `LoadResult` (when there is one), the app-level `FatalLatch`, the retry latch, a `PresentationSettings` value, and the current `Battle` and `BattleWrapper` (or none).
- `_ready()`: create the app latch first, then load the catalogue. On a failed `LoadResult`, keep it and call the app latch's `fatal()` with a cause built from its errors. On success, keep the catalogue, read the Input record once into `PresentationSettings`, pick `stage_id` and `rng_seed`, and start a battle (section 5, step 7).
- `FATAL` is absorbing. No transition leaves it; the player relaunches. From VS, Save boot runs only after a Ready load, so a failed load never opens a save.
- Nothing sets `SceneTree.paused`. Pause is a Flow phase (ADR-0003, ADR-0004).

### 2. Builder and Battle
- `BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler) -> Battle` is a static function on a `RefCounted` class. It touches no node, so tests and bots call it headless. It is never called from inside a signal handler. The parameter is `rng_seed`, not `seed`, so it does not shadow the global `seed()`.
- Build order: (a) create the battle `FatalLatch`, forwarding to `fatal_handler`; (b) create a fresh `StatAccessor` over the shared read-only `Catalogue`, with the battle latch's `fatal` as its failure handler; (c) read the Stage, Input and Hero records and check stage inputs; create `InputResolver.create(drag_slop, tap_slop)` and call `fatal("input_record_invalid")` if it returns null (this closes the Builder's part of QQ-19); (d) construct `HaltGate`, `TickMath`, `DevErrorSink`, `Wiring`, `Flow`, `Combat`, `EnemyWave`, `TowerSim`, `HeroSim`; (e) inject values and make every signal connection, each through `Wiring.connect_recorded()`; (f) return the `Battle`.
- After each step the Builder checks the battle latch. If it is set, `build` drops its locals and returns `null`, so a partial battle is never ticked.
- `Battle` is a `RefCounted`. Public read-only members: `flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`, `input_resolver` (new, see Consequences), `stat_accessor` and `halt_gate` (amended 2026-11-04, ADR-0005). Private strong members: `_tick_math`, `_dev_error_sink`, `_wiring`.
- **Every object behind an injected Callable is a member of `Battle` or `AppRoot`.** So while the battle lives, every Callable a sim holds has a live target, whether Callables are strong or weak.
- The `Catalogue` holds no per-battle reference. Each battle's accessor points at the catalogue; the catalogue points at nothing in a battle. ADR-0005 follows this.
- `Battle.halted()` is a pass-through to its `HaltGate`, for the wrapper and tests. Sims get `HaltGate.halted`, never a Callable on `Battle`.

### 3. Injection rules and the acyclic graph
- Everything a sim needs from outside arrives as an injected value or a method `Callable` bound to a Builder-owned object (B9). The Builder never passes a lambda, and never uses `bind()` with a sim object as an argument.
- **No sim object holds a reference to `Battle`, to `AppRoot` or to any `Node`.** `HaltGate` holds `Flow` and the battle `FatalLatch`, and `halted()` is true when `flow.phase()` is `WON`, `LOST` or `FATAL`, or the latch is set. It is false while `PAUSED`; the tick gate stops time then.
- Injected Callables point only one way, so they form no cycle on their own. The targets are: `HaltGate.halted`, `TickMath.to_ticks`, `DevErrorSink.report`, the battle latch's `fatal`, the battle's `StatAccessor` (injected as an object, not a method Callable; ADR-0005), `EnemyWave.targets` and `EnemyWave.wave_index`, `Flow.in_build`, and `InputResolver.cancel` (as `cancel_input()`). Flow holds Callables to `EnemyWave`, the resolver, `TickMath` and the sink only; it holds nothing that points at `HeroSim`, `TowerSim` or `HaltGate`. Nothing points back at a sim that points at it.
- Signal connections do point both ways (for example `EnemyWave.enemy_leaked` to `Flow`, while `Flow` holds `EnemyWave.wave_index`). If Godot treats a connection as a strong reference, that is a cycle. Section 5 removes it at teardown.
- `left_handed` and `reduce_motion` come from the Input record. The Builder passes `left_handed` to `HeroSim` with the Hero record ID and `burst_id` (TR-hero-004). The wrapper passes `PresentationSettings` (both flags) to HeroInput, HudLogic and every view. Views read Reduce Motion only from `PresentationSettings`, never from the catalogue (QQ-09). At Alpha, Settings becomes the source of `PresentationSettings` and no view changes.

### 4. BattleWrapper
- AppRoot loads the `BattleWrapper` scene and instantiates it after a non-null `build`. If the load returns null or `instantiate()` returns null, AppRoot calls the app latch's `fatal("wrapper_scene_failed")`.
- The wrapper holds the Clock, the `InputAdapter`, HeroInput, TowerInput, HudLogic, the HUD and the field views, all built from `battle.input_resolver` and `PresentationSettings` (TR-input-012). It holds no gameplay logic and has no branch on a gameplay value.
- The wrapper owns its own `Wiring` record, `view_wiring`. Every connection it makes to a sim signal (`phase_changed`, `lives_changed`, `gold_changed` and the rest) goes through `view_wiring.connect_recorded()`. ADR-0006's listener-count test reads both records.
- Wrapper code animates with `create_tween()` on its own nodes only. It uses no SceneTree tween, no SceneTree timer, and no `await` on a SceneTree timer, so nothing outlives the wrapper.
- Headless runs have no wrapper.

### 5. Retry and teardown
- The Result screen's Retry handler calls `AppRoot.request_retry()`, which sets an idempotent latch and returns. It frees nothing (TR-hud-006).
- `AppRoot._process()` acts on pending work in this order, each frame:
  1. If the app latch is set: tear down (steps 3 to 6, if a battle exists), show the fatal screen, set `FATAL`, call `set_process(false)`. Stop.
  2. If the retry latch is set and Flow is `WON` or `LOST`: clear the latch, tear down, then rebuild. A retry latch outside `WON` or `LOST` is cleared and ignored.
  3. Teardown: stop the Clock; `battle.input_resolver.cancel()`; set `wrapper.process_mode = PROCESS_MODE_DISABLED` (children inherit it), as a second guard.
  4. `wrapper.view_wiring.disconnect_all()`, then `remove_child(wrapper)`, then `wrapper.queue_free()`. `remove_child()` is what stops the subtree's processing and input at once; the node is deleted at the end of the frame.
  5. `battle.unwire()`: disconnect every connection in the Builder's `Wiring` record, then clear it. Idempotent.
  6. Set AppRoot's `battle` and `wrapper` fields to null.
  7. Build: `BattleBuilder.build()` with the same catalogue. If it returns null, add no wrapper; the next frame's step 1 shows Fatal. Otherwise add a new wrapper (section 4) and set `IN_STAGE`. The new battle opens in Build, which runs no ticks, so it does not matter whether the new wrapper's `_process` runs in this frame.
- AppRoot acts from its own `_process`, never from inside the wrapper's call stack. `free()` is not used on the wrapper.
- Retry resets nothing in place. No system has a reset function. `unwire()` lives on `Battle` in the composition root and changes no gameplay state.

### 6. Fatal path
- One `FatalLatch` class, two instances: one per battle, built with a forward Callable, and one on AppRoot, built with none. `fatal(cause: String)` keeps the first cause and counts later calls. On the first call it does three things in this order: forward to the forward Callable if it has one; otherwise `push_error(cause)`; then emit `latched(cause)` once. So only the app latch logs, and the log line appears once. `is_fatal()` and `first_cause()` read it.
- The Builder connects the battle latch's `latched` to `Flow`, which enters `FATAL`, calls `cancel_input()` and emits `phase_changed(FATAL)`. From then on `halted()` is true, so later steps in the tick return at once (TR-state-011).
- The app latch only records. AppRoot acts on it in its next `_process` (section 5, step 1), so a fatal raised deep in a tick never frees the wrapper from inside that tick.
- Every fatal source takes this path: a failed catalogue load (AppRoot calls the app latch), a bad accessor call (the battle's accessor calls the battle latch), a bad stage input or invalid Input record (the Builder), a wrapper scene that fails to load (AppRoot), and a broken stage scene (the wrapper, when it fails to instance `scene_ref`, calls the battle latch).
- The fatal screen is `class_name FatalScreen extends Control`, built in code and referred to by class name, never by path. It loads no `.tscn`, font, texture or catalogue data. It uses full-rect anchors, and so does its `Label`, which uses `AUTOWRAP_WORD_SMART`. In a debug build (`OS.is_debug_build()`) it shows the first cause and, for a load failure, every `ValidationError` from AppRoot's kept `LoadResult`, by file, record and field, inside a code-built `ScrollContainer`. In a release build it shows one generic line and nothing else. Its text is a code constant at MVP; it moves to the localisation table when one exists.
- The screen uses the default theme and font. The project must not set `gui/theme/custom` or a custom font; if it ever does, a failure to load either counts as a boot failure. On a high-DPI phone the default font is small until ADR-0003 sets the stretch mode.
- `assert` is never used for a check that matters in release, and never holds a side effect.

### 7. Error sinks
- **Fatal**: the battle latch's `fatal`, injected into the accessor, the Builder steps and every sim.
- **Dev error**: `DevErrorSink.report(msg: String)`, injected into EnemyWave (TR-enemy-012), Flow (Rule 15a), `Wiring` and others. The game's sink calls `push_error(msg)` in all builds and does not halt. Tests inject a recording fake.
- **`cancel()` callers (QQ-20)**: the adapter (pause, focus loss, resize; ADR-0003), Flow through the injected `cancel_input()` (Won, Lost, Paused, Fatal), and AppRoot at teardown (retry and fatal). Input Rule 7 must be widened to list all three.

### Architecture Diagram

```
AppRoot (Node, main scene; state BOOT | IN_STAGE | FATAL)
  owns: Catalogue, failed LoadResult, app FatalLatch, retry latch, PresentationSettings
  │
  │ build(catalogue, stage_id, rng_seed, app_latch.fatal)      [no node touched]
  ▼
Battle (RefCounted) ─ holds ─► Flow, Combat, EnemyWave, TowerSim, HeroSim,
  │                            battle FatalLatch, InputResolver,
  │                            halt_gate, stat_accessor,
  │                            _tick_math, _dev_error_sink, _wiring
  │
  │  injected Callables (point one way only; every target held by Battle):
  │    sims ──► HaltGate ──► Flow, battle FatalLatch
  │    sims ──► TickMath, DevErrorSink, StatAccessor, battle FatalLatch.fatal
  │    TowerSim, HeroSim ──► EnemyWave.targets     HeroSim ──► Flow.in_build
  │    Flow ──► EnemyWave.wave_index, InputResolver.cancel
  │    StatAccessor ──► Catalogue (shared, read-only, points at no battle)
  │    battle FatalLatch ──► app FatalLatch.fatal
  │
  │  signal connections (both ways, every one recorded in _wiring):
  │    EnemyWave ─► Flow, TowerSim     Flow ─► TowerSim     FatalLatch ─► Flow
  │
  ▼
BattleWrapper (Node scene, absent headless; owns view_wiring)
  Clock, InputAdapter, HeroInput, TowerInput, HudLogic, HUD, views
  sim signals ─► views, each recorded in view_wiring

Retry / fatal teardown, in AppRoot._process:
  stop clock ─► resolver.cancel() ─► wrapper DISABLED ─► view_wiring.disconnect_all()
  ─► remove_child + queue_free(wrapper) ─► battle.unwire() ─► drop Battle
  ─► (retry) build again | (fatal) FatalScreen
```

### Key Interfaces

```gdscript
class_name AppRoot extends Node
enum AppState { BOOT, IN_STAGE, FATAL }
func state() -> AppState
## Called by the Result screen. Sets a latch; frees nothing; idempotent.
func request_retry() -> void

class_name BattleBuilder extends RefCounted
## Returns null when a fatal fired during the build. Touches no node.
static func build(catalogue: Catalogue, stage_id: StringName, rng_seed: int, fatal_handler: Callable) -> Battle

class_name Battle extends RefCounted
var flow: Flow                       # read-only by contract
var combat: Combat
var enemy_wave: EnemyWave
var tower_sim: TowerSim
var hero_sim: HeroSim
var fatal_latch: FatalLatch
var input_resolver: InputResolver
var stat_accessor: StatAccessor      # read-only by contract; one per battle (ADR-0005)
var halt_gate: HaltGate              # read-only by contract; held so injected Callables stay valid (ADR-0005)
var _tick_math: TickMath
var _dev_error_sink: DevErrorSink
var _wiring: Wiring
func tick(dt: float) -> void         # gate and order: ADR-0004
func halted() -> bool                # pass-through to HaltGate
## Disconnects every Builder connection. Idempotent. Composition root only.
func unwire() -> void

class_name HaltGate extends RefCounted
## True on WON, LOST or FATAL, or when the battle latch is set. False while PAUSED.
func halted() -> bool

class_name FatalLatch extends RefCounted
signal latched(cause: String)        # once, on the first fatal()
func _init(forward: Callable = Callable()) -> void
## Idempotent. Keeps the first cause. First call: forward, else push_error; then emit.
func fatal(cause: String) -> void
func is_fatal() -> bool
func first_cause() -> String

class_name Wiring extends RefCounted
## Stores (Signal, Callable) values, not objects. Skips a pair that is already
## connected and reports it to the dev-error sink.
func _init(dev_error: Callable) -> void
func connect_recorded(sig: Signal, target: Callable) -> void
## Disconnects each pair only if is_connected(); then clears the record. Idempotent.
func disconnect_all() -> void
## Read-only copy of {signal, callable} per pair (amended 2026-11-04 with ADR-0006).
func pairs() -> Array[Dictionary]

class_name DevErrorSink extends RefCounted
func report(msg: String) -> void     # push_error in every build; never halts

class_name PresentationSettings extends RefCounted
var left_handed: bool
var reduce_motion: bool

class_name FatalScreen extends Control
func show_cause(first_cause: String, errors: Array[ValidationError]) -> void
```

Names are proposed by this ADR. `Battle.input_resolver`, the private `Battle` members, `HaltGate`, `Wiring`, `PresentationSettings`, `DevErrorSink` and `FatalLatch.latched` are new against architecture.md v3. QQ-16 (global `class_name` collisions) may add a prefix; ADR-0007 decides.

### Implementation Guidelines
1. `project.godot` must never contain an `[autoload]` section. CI fails if it does.
2. Gameplay and Foundation code must never reference `AppRoot`, `BattleBuilder`, `Battle` or `BattleWrapper` by name.
3. Every connection to a sim signal must go through a `Wiring` record: the Builder's for gameplay wiring, the wrapper's `view_wiring` for views. A direct `.connect()` on a sim signal anywhere else is forbidden.
4. Injected Callables must be method Callables on Builder-owned objects. Lambdas, and `bind()` with a sim object argument, are forbidden in the Builder and the wrapper.
5. Every object behind an injected Callable must be a member of `Battle` or `AppRoot`.
6. No sim object may hold a reference to `Battle`, `AppRoot` or any `Node`. `halted()` is injected as `HaltGate.halted`, never as `Battle.halted`.
7. The `Catalogue` must hold no reference to anything in a battle. Each battle gets its own `StatAccessor`.
8. `BattleBuilder.build()` must check the battle latch after each step and return `null` once it is set. AppRoot must add no wrapper after a null build.
9. Every caller of an accessor read, an injected Callable or a signal emit inside a tick must check `halted()` after it and return at once when true.
10. `assert` must never guard a release-relevant check and must never hold a side effect. Use the injected fatal handler or the dev-error sink.
11. AppRoot must act on the retry and fatal latches only from its own `_process`, fatal first. A Retry handler must only call `request_retry()`.
12. Teardown order must be: stop the clock, `resolver.cancel()`, wrapper `process_mode = PROCESS_MODE_DISABLED`, `view_wiring.disconnect_all()`, `remove_child()` and `queue_free()` the wrapper, `battle.unwire()`, drop every reference. Never call `free()` on the wrapper.
13. AppRoot must check that the wrapper scene loads and instantiates, and call the app latch if either fails.
14. The fatal screen must load no resource and read no catalogue data. Debug builds show the cause and error list; release builds show one generic line. The project must not set `gui/theme/custom` or a custom font.
15. Views must read `reduce_motion` and `left_handed` only from the injected `PresentationSettings`.
16. Nothing may set `SceneTree.paused`. If AppRoot is ever set to `PROCESS_MODE_ALWAYS`, the wrapper must set `PROCESS_MODE_PAUSABLE` on itself explicitly.
17. Wrapper code must animate with `create_tween()` on its own nodes; no SceneTree tweens or timers, and no `await` on a SceneTree timer.
18. An override of a method with a non-void typed return must return a value on every path (4.7 rule).

## Alternatives Considered

### Alternative 1: Autoload singletons (a `Game` autoload holding the catalogue, plus an event bus)
- **Description**: register a global `Game` node that loads and holds the catalogue, and an `Events` autoload that systems emit on and listen to.
- **Pros**: the most common Godot pattern; any script reaches the catalogue in one line; no wiring code.
- **Cons**: every system gains a hidden dependency on a global, so unit tests need the autoload or a stub of it; an autoload survives retry, so state can leak between attempts; an event bus hides who listens, which defeats the listener-count wiring test (TR-tower-013); autoload load order becomes a failure mode before the fatal path exists.
- **Rejection Reason**: the Data and Game State GDDs both forbid autoloads (TR-data-011, TR-state-001), and dependency injection is a coding standard here.

### Alternative 2: Scene-owned battle root
- **Description**: a `battle.tscn` whose root script wires the battle's systems in `_ready()`; retry reloads the scene.
- **Pros**: familiar; the editor shows the battle's parts; scene reload frees everything.
- **Cons**: building a battle needs a scene tree, so bots and headless tests cannot build one the way the phone does; scene reload timing is engine-defined and hard to test.
- **Rejection Reason**: TR-state-002 requires a scene-free builder that runs headless and gives bots the shipped wiring. This is the change QQ-08 records.

### Alternative 3: Reset in place on retry
- **Description**: keep the battle and call `reset()` on each system.
- **Pros**: no teardown cost; no weakref question.
- **Cons**: every new field needs a matching reset line; the prototype's hand-listed reset of 22 fields is how state leaked between attempts (Game State Rule 16).
- **Rejection Reason**: the GDD rules it out.

### Alternative 4: Trust Callable semantics, no unwire (architecture.md v3 default)
- **Description**: drop the `Battle` and rely on there being no strong cycle, with `halted()` injected as `Battle.halted`.
- **Pros**: less code; no `Wiring` record.
- **Cons**: correct only if method Callables and signal connections are weak on 4.7, which nobody has checked (QQ-17). If they are strong, `Battle.halted` injected into each sim is a sim-to-Battle cycle (against B4's own rule), and two-way signal links form more. If they are weak, a helper object that only a Callable points at could die early. The weakref test would then fail, or a sim would call a dead target, with no clear fix.
- **Rejection Reason**: it bets the retry design on an unverified engine fact. The chosen design holds either way, and the V1 probe still records the answer.

### Alternative 5: Fatal screen as a `.tscn` loaded on demand
- **Description**: `load("res://src/root/fatal_screen.tscn")` when entering `FATAL`.
- **Pros**: the screen can be laid out in the editor.
- **Cons**: a load at the worst moment is one more thing that can fail, and a broken export could drop the file.
- **Rejection Reason**: TR-state-011 asks that the screen be guaranteed to load. A code-built `Control` has no resource to lose.

## Consequences

### Positive
- One code path builds a battle for the phone, bots and tests, so a bot result is a test of the shipped wiring.
- Retry frees the old battle whatever QQ-17's answer is, and the weakref test proves it on every CI run. While a battle lives, every injected Callable has a live target.
- Every fatal source ends in the same latch and the same screen, in every build, with one log line; a fatal deep in a tick never frees the node whose code is running.
- Systems never know about Flow, Battle or the root. Each is unit-tested with fakes for `halted()`, the sinks and `targets()`.
- Both `Wiring` records give ADR-0006's listener-count test an exact list of connections.
- Reduce Motion has one read point today and one swap point at Alpha.

### Negative
- Six small classes join the root and Foundation (`HaltGate`, `Wiring`, `DevErrorSink`, `PresentationSettings`, `FatalScreen`, `AppRoot`), on top of those architecture.md already named, and `Battle` gains three private members (`_tick_math`, `_dev_error_sink`, `_wiring`) and two public read-only ones (`halt_gate`, `stat_accessor`).
- Teardown has more ordered steps. A direct `.connect()` that skips a `Wiring` record would leave a connection undone; Implementation Guideline 3, its lint and test V2 guard it.
- A fatal shows one frame late, because AppRoot acts in its next `_process`. The sim halts at once, so no state changes in that frame.
- One `StatAccessor` per battle costs one small allocation per retry.
- At MVP the only exit from `FATAL` is to relaunch.
- architecture.md v3 needs edits to match (see Migration Plan).

### Neutral
- `Battle.halted()` stays as a pass-through, so the wrapper and tests read it as before.
- The fatal screen's look is plain text at MVP, which matches the Game State GDD's Visual section.

## Risks
- **Callables or connections are strong, and a hidden cycle remains** (a sim that stores another sim's Callable that points back). Mitigation: Implementation Guidelines 4 to 6, and test V2, which checks the weakref of every sim, not only `Battle`. V1: both are weak; B9 bans the strong forms (`bind()`, lambdas).
- **Callables are weak, and an injected target dies early.** Every target is a member of `Battle` or `AppRoot` (Guideline 5), so this cannot happen while the battle lives. After `unwire()`, nothing calls them. V1 case (f) proves it. V1: they are weak, so Guideline 5 is load-bearing.
- **A removed wrapper still gets a callback before its free.** Mitigation: `remove_child()` stops processing and input; `PROCESS_MODE_DISABLED` is a second guard; the gate in `Battle.tick` also returns once halted. Test V6 checks a child view's `_process` and the adapter's `_input`.
- **`push_error()` is silent in a release export.** A release fatal still reaches the screen, because the latch does not rely on the log. Test V8 checks it. If V8 shows no log line, the app latch also writes the first cause to `user://last_fatal.txt` on its first call, and the screen still shows one generic line.
- **The app latch and battle latch disagree.** The battle latch always forwards on its first call, before it emits, and AppRoot reads only its own latch. Test V3 covers both orders.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-004: load once, all or nothing, started by the app root before the first gameplay scene, no reload | Decision 1: AppRoot `_ready()` loads the catalogue once; `BOOT` moves to `IN_STAGE` only on a Ready load; no reload path exists |
| data-config-pipeline.md | TR-data-006: no fallbacks; a load failure shows a catalogue-free fatal screen that never opens saves; dev runs name each error | Decision 1 and 6: a failed load goes to the app latch and `FatalScreen`, which uses no catalogue data; Save boot runs only after Ready; debug builds list each `ValidationError` from the kept `LoadResult` |
| data-config-pipeline.md | TR-data-009: a bad accessor call goes to an injected, test-replaceable handler that survives release builds (not assert) | Decision 2, 6 and 7: each battle's accessor gets the battle latch's `fatal`; tests inject a spy; `assert` is forbidden for this |
| data-config-pipeline.md | TR-data-011: no autoload or global; the app root holds the catalogue across retries; the builder injects it | Decision 1, 2 and 5: AppRoot holds the catalogue and passes the same object to every `build()`; the catalogue holds no battle reference; Guideline 1 bans autoloads |
| input-gesture-resolver.md | TR-input-012: Game State builds the resolver and adapter per battle from the Input record and injects the one resolver into Hero, Tower and HUD wrappers | Decision 2 and 4: the Builder creates the resolver from the Input record and exposes it as `battle.input_resolver`; the wrapper builds the adapter and hands that one resolver to HeroInput, TowerInput and HudLogic; both die on retry |
| game-state-stage-flow.md | TR-state-001: a minimal main-scene app root, no autoload, triggers the load, holds the catalogue, owns the fatal screen, alone survives a retry | Decision 1, 5 and 6 |
| game-state-stage-flow.md | TR-state-002: scene-free `build(catalogue, stage_id, seed, fatal_handler)` wires every system by explicit connections and runs headless; a thin wrapper adds tick loop, adapter and views | Decision 2 to 4: static `build()` (parameter named `rng_seed`) touches no node and records every connection in `Wiring`; `BattleWrapper` holds no logic |
| game-state-stage-flow.md | TR-state-009: retry destroys the whole battle and builds a new one between ticks, driven by a latch on the app root; a weakref to the old battle is null | Decision 5: latch, teardown in AppRoot `_process`, both `Wiring` records undone, drop, rebuild; tests V2 and V6 |
| game-state-stage-flow.md | TR-state-011: one idempotent fatal handler keeps the first cause, latches, halts the tick, discards a partial build; the fatal screen is guaranteed to load | Decision 6: `FatalLatch` semantics, `halted()` through `HaltGate`, `build()` returns null and AppRoot adds no wrapper, code-built `FatalScreen` |
| enemy-wave.md | TR-enemy-005: the builder injects `halted()` checked after every read and signal; the system never references Flow | Decision 3: `HaltGate.halted` injected; Guideline 9 |
| enemy-wave.md | TR-enemy-012: wave control logs to an injected dev-error sink, not assert | Decision 7: `DevErrorSink` injected, recording fake in tests |
| tower-system.md | TR-tower-006: injected `halted()` checked after every read and signal; all stats read before any mutation | Decision 3 and Guideline 9 provide and require the check. The read-before-mutate order is TowerSim's own rule, enforced by ADR-0010's command contract |
| tower-system.md | TR-tower-013: retry teardown leaves no old battle alive through a signal connection; a listener-count wiring test names any missing connection | Decision 4 and 5: both `Wiring` records are undone at teardown; test V2 checks every sim's weakref. The records give ADR-0006's listener-count test its list |
| hero-system.md | TR-hero-004: the builder injects `halted()`, `in_build()`, the hand flag, the Hero record ID and `burst_id` into HeroSim, HeroInput and the HUD | Decision 3: the Builder injects them into HeroSim (`in_build` as `Flow.in_build`); the wrapper passes `PresentationSettings`, `in_build` and `burst_id` to HeroInput and HudLogic |
| battle-hud.md | TR-hud-006: Retry sets an idempotent latch on the app root and never frees its caller; the root's next frame checks Fatal, stops, cancels, frees and rebuilds | Decision 5: `request_retry()` and the `_process` order, fatal first |

## Performance Implications
- **CPU**: none per tick. `HaltGate.halted()` is two reads. Retry costs one build plus one teardown, once per attempt, outside any tick.
- **Memory**: one battle alive at a time after the wrapper's end-of-frame free. The two `Wiring` records hold about 20 and about 30 pairs.
- **Load Time**: the catalogue load (budget owned by ADR-0002) runs once per session. The fatal screen adds no load.
- **Network**: none.

## Migration Plan
No code exists, so nothing migrates. When this ADR is Accepted, these documents need edits to match. This ADR does not make them, because only the user can accept it:
1. `docs/architecture/architecture.md`:
   - B0: add `input_resolver` and the private members to `Battle`.
   - B9 and Data Flow 7: `halted()` is `HaltGate.halted()`, not `Battle.halted()`.
   - Data Flow 4, step 1: replace "the catalogue-free fatal scene is loadable" with the code-built `FatalScreen`; step 5: the Builder creates one `StatAccessor` per battle and the parameter is `rng_seed`.
   - Data Flow 5: add the `view_wiring` and `unwire()` steps and the `PROCESS_MODE_DISABLED`, `remove_child`, `queue_free` order.
   - Composition Root table: the Fatal screen row calls it a scene; make it a code-built `Control`. Add `HaltGate`, `Wiring`, `PresentationSettings`, `DevErrorSink`.
   - Open Questions: mark QQ-09, QQ-17 (answered by V1, 2026-11-04), QQ-20 and QQ-19 (Builder part) as resolved by ADR-0001.
2. `design/gdd/input-gesture-resolver.md` Rule 7: list Flow (through `cancel_input()`) and AppRoot (teardown) as `cancel()` callers beside the adapter (QQ-20, cross-review C2).
3. `design/gdd/game-state-stage-flow.md` Rule 16: name the unwire steps in the retry order.
4. `design/gdd/enemy-wave.md` Open Questions row at line 515: Reduce Motion location is settled.

## Validation Criteria
Headless gdUnit4 tests (ADR-0007 places them; names proposed). No test passes a battle or sim object into a gdUnit assert before its weakref check, because the assert would hold a reference and leave orphans (exit 101).
- **V1 `test_callable_ref_semantics_probe`** (settles QQ-17): (a) store `Callable(a, &"m")` on `b`, drop every other ref to `a`, check `weakref(a).get_ref()`; (b) connect `a.sig` to `b.m`, drop `b`, check `weakref(b)`; (c) the same with the source dropped; (d) store `Callable(b, &"m").bind(a)`, drop `a`, check `weakref(a)`; (e) store a lambda that captures `a`, drop `a`, check `weakref(a)`. Cases (a) to (e) assert nothing about which answer is right; they record it, and the result goes into `docs/engine-reference/godot/` with the date and version. (f) Build a battle, drop every local except the `Battle`, call `halted` through a sim's injected Callable, and expect a `bool`. Case (f) must pass. Run: (a) to (c) weak (a freed target's connection is removed; no cycle), (d) and (e) strong, (f) passes; verified 4.7.2 headless, see probe-results.md.
- **V2 `test_retry_frees_old_battle`**: build, connect a recording fake listener to each sim signal through a second `Wiring` record (standing in for `view_wiring`), run a scripted micro-battle to `LOST`, call `disconnect_all()` on the fake record and `unwire()`, drop every reference, then check at once that the weakref of `Battle` and of each sim reads null. A second case skips both undo steps and records whether it still passes, which shows whether they are load-bearing on 4.7.2.
- **V3 `test_fatal_latch_first_cause`**: two `fatal()` calls keep the first cause; the battle latch forwards once, before it emits `latched` once; only the app latch calls `push_error`; both latch orders tested.
- **V4 `test_fatal_during_build_returns_null`**: a bad Input record makes `build()` return null with the app latch set; nothing ticks.
- **V5 `test_fatal_mid_tick_halts_later_steps`**: a spy accessor fires `fatal` inside `EnemyWave.advance`; TowerSim and HeroSim do nothing that tick.
- **V6 `test_retry_latch_and_teardown_order`** (integration, scene tree, headless): two Retry calls give one rebuild; the handler frees nothing; a fatal pending with a retry shows Fatal; a null build adds no wrapper; after `remove_child()`, a child view's `_process` and the adapter's `_input` are not called (verified 4.7.2 headless, see probe-results.md). The test then awaits `get_tree().process_frame` before it checks the weakref of the old battle.
- **V7 `test_no_autoload_and_main_scene`**: `project.godot` has no `[autoload]` section, and `[application] run/main_scene` names `app_root.tscn` by path or by a `uid://` value that resolves to it. Part of ADR-0007's lint; re-run whenever an addon is added.
- **V7b `test_fatal_screen_loads_bare`**: `FatalScreen.new()` builds and shows a cause and a 50-error list with no catalogue and no resources.
- **V7c `test_wiring_duplicate_and_disconnect`**: a second `connect_recorded()` of the same pair reports to the dev-error sink and adds nothing; `disconnect_all()` twice raises no error.

Manual evidence (`production/qa/evidence/`, first phone build):
- **V8**: an exported release build with one invalid record shows the fatal screen, leaves saves untouched, and a bad accessor call reaches it too (Data AC 13). Check the device log for the `push_error` line, and record the values of `application/run/disable_stderr` and `debug/file_logging/enable_file_logging` in the evidence. If no line appears, apply the `user://last_fatal.txt` fallback from Risks.

## Reviews

**TD-ADR (technical-director): CONCERNS.** **godot-specialist: CONCERNS.** Both ran on the first draft. Every finding is applied below.

| # | Finding | Kind | Resolution |
|---|---|---|---|
| 1 | Callable targets (`halt_gate`, `tick_math`, `dev_error_sink`, `wiring`) had no strong owner | Blocking, both | Decision 2: private `Battle` members; Guideline 5; V1 case (f); `Flow.in_build` added to Decision 3, and Flow points at no `HeroSim` |
| 2 | Guideline 3 banned the view connections the wrapper needs | Blocking, both | Decision 4: wrapper `view_wiring`, undone before `queue_free`; Guideline 3 reworded; folded into V2 and the ADR-0006 list |
| 3 | Accessor ownership unclear across retries | Blocking | Decision 2: one `StatAccessor` per battle with its latch, held by `Battle`; Catalogue holds no battle reference; Guideline 7 |
| 4 | FatalLatch first-call order and double logging | Advisory | Decision 6: forward, else `push_error`, then emit; only the app latch logs; V3 |
| 5 | Load errors did not reach the screen | Advisory | Decision 1 and 6: AppRoot keeps the failed `LoadResult` and passes its errors to `show_cause()` |
| 6 | Null build path and a wrong cross-reference | Advisory | Section 5 step 7 adds no wrapper on null; Decision 1 now points at section 5, step 7 |
| 7 | Wrapper scene load not checked | Advisory | Decision 4 and Guideline 13 |
| 8 | `set_process(false)` is not recursive | Advisory | `remove_child()` named as the real stop; `PROCESS_MODE_DISABLED` as second guard; V6 checks a child view and the adapter; Context line matches |
| 9 | Weakref timing and gdUnit orphans | Advisory | V2 checks at once; V6 awaits a frame; no object passes through an assert first |
| 10 | Wiring robustness | Advisory | `is_connected` guards, duplicate goes to the sink, stores values; V7c |
| 11 | Ban on `bind()` and lambdas had no recorded reason | Advisory | V1 cases (d) and (e) |
| 12 | V8 settings, assert side effects, fallback clash | Advisory | V8 records both settings; Guideline 10; one fallback (`user://last_fatal.txt`); hidden debug field dropped |
| 13 | FatalScreen layout and theme | Advisory | Decision 6 and Guideline 14: no custom theme or font, full-rect anchors, `AUTOWRAP_WORD_SMART`, `ScrollContainer`, class name only, high-DPI note |
| 14 | Pause and process mode | Advisory | Guideline 16 |
| 15 | SceneTree tweens and timers | Advisory | Decision 4 and Guideline 17 |
| 16 | `seed` shadows global `seed()` | Advisory | Renamed `rng_seed`; ADR-0002 note on `load` in Enables |
| 17 | Guideline 13 wording | Advisory | Now Guideline 18, reworded |
| 18 | V7 precision | Advisory | V7 names `[application] run/main_scene`, accepts `uid://`, re-runs on new addons |
| 19 | Alternative 2 rested on a claim not forced | Advisory | Rejection now rests on headless and bot builds and reload timing only |
| 20 | Migration Plan gaps | Advisory | Item 1 adds Data Flow 7, Data Flow 4 step 1, the Fatal screen row and QQ-19's Builder part |

## Related
- `docs/architecture/architecture.md` v3: Composition Root, Data Flow 4, 5 and 7, B4, B9, QQ-08, QQ-09, QQ-17, QQ-19 (Builder part), QQ-20
- `docs/architecture/tr-registry.yaml`: the 15 TRs above
- GDDs: `design/gdd/game-state-stage-flow.md` (Rules 1 to 3, 15 to 18), `design/gdd/data-config-pipeline.md` (Rules 8, 10), `design/gdd/input-gesture-resolver.md` (Rule 7, Interactions), `design/gdd/enemy-wave.md` (Rule 13), `design/gdd/tower-system.md`, `design/gdd/hero-system.md`, `design/gdd/battle-hud.md` (Rule 18)
- Enables ADR-0002 to ADR-0007 and ADR-0009 (none written yet)

## Amendments
- **2026-11-04, with ADR-0005** (Status stays Accepted; confirmed by the user 2026-11-04 when ADR-0005 was accepted). The battle's `StatAccessor` moves from the private member `_stat_accessor` to the public read-only member `stat_accessor`, beside `input_resolver` (Decision 2, Key Interfaces). The Builder injects it into EnemyWave, TowerSim and HeroSim as an object, not a method Callable (Decision 3); the wrapper passes `battle.stat_accessor` to HudLogic. `_halt_gate` likewise becomes the public read-only member `halt_gate`, so the wrapper can pass `battle.halt_gate.halted` to HudLogic as a method Callable; B9's rule against injecting `Battle.halted()` stands. Still one accessor per battle, made in build step (b). The Architecture Diagram's `_halt_gate` and `_stat_accessor` and Consequences' "five private members" now read `halt_gate`, `stat_accessor` and three; they are left as written.
- **2026-11-04, with ADR-0006 (confirmed by the user 2026-11-04 at ADR-0006 acceptance).** Status stays Accepted. `Wiring` gains `func pairs() -> Array[Dictionary]`, a read-only copy of `{signal, callable}` per recorded pair, so ADR-0006's listener-count tests read both records (Key Interfaces). `connect_recorded()` also checks the `Error` that `connect()` returns and sends a failure to the dev-error sink without recording the pair (ADR-0006 Decision 1). Nothing else in this ADR changes.
- **2026-11-04, from verified engine probes** (docs/engine-reference/godot/probe-results.md; Status stays Accepted). QQ-17 is answered: method Callables and signal connections are weak (a freed target's connection is removed; no cycle); `bind()` args and lambda captures are strong. This confirms the design: Battle or AppRoot holds every Callable target (Guideline 5). Engine Compatibility, Risks, V1, V6 and Migration say so.
- **2026-11-04, from the third architecture review; Status stays Accepted** (`architecture-review-2026-11-04.md`). The ADR-0005 amendment left two spots as written; they now match it. The Architecture Diagram shows the public `halt_gate` and `stat_accessor` and the three private members `_tick_math`, `_dev_error_sink`, `_wiring`. Consequences says `Battle` gains three private members and two public read-only ones. Nothing else in this ADR changes.
- **2026-11-05, from the fourth architecture review; Status stays Accepted** (`architecture-review-2026-11-05.md`, Should fix 5). Decision Makers now says QQ-08's composition-root part was accepted by the user 2026-11-04, in place of "also waits for the user". Nothing else in this ADR changes.
- **2026-11-05, from the engine consultation of the fourth review; Status stays Accepted.** Enables adds ADR-0010 and ADR-0011, which depend on this ADR. Nothing else changes.
