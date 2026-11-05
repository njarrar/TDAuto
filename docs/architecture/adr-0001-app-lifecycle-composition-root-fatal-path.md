# ADR-0001: App Lifecycle, Composition Root and Fatal Path

## Status
Accepted (2026-11-05, on the owner's instruction to close the open items; the Verification Required items stay open and are tracked by the Boot story). Amended 2026-11-05 on the owner's sign-off after architecture-review-2026-11-05 (C3: `HALTED` is an ordinary result; C4: `setup(battle, dev_telemetry)`)

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted on 2026-11-04 from the Game State & Stage Flow GDD and `docs/architecture/architecture.md` v4. Reviewed once each on 2026-11-05 by `godot-specialist` (four blocking facts, ten minor notes, all applied) and `technical-director` under gate TD-ADR (CONCERNS: 26 findings, all applied in this revision). No second review pass was run; the findings and their fixes are listed under Risks and in the probe table. Fix round 2026-11-05 after architecture-review-2026-11-05 (items applied: C3, C4, Enables row).

## Summary
The game needs one place that boots, holds the catalogue, builds and tears down battles, and catches every unrecoverable failure, without autoloads and without a scene, so bots and tests can run a battle headless. This ADR fixes that shape: a minimal `AppRoot` main scene with three states, a static scene-free `BattleBuilder.build()` that returns a `Battle` holding every helper in a typed field, method-Callable-only injection with no back-references, a per-battle `FatalLatch` forwarding to the root, retry by `free()` and rebuild from the root's `_process`, and a script-free preloaded fatal screen.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; installed 4.7.2.stable.official) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH until the export and phone checks under Verification Required pass; LOW on the desktop evidence gathered so far. The APIs used (`Node`, `RefCounted`, `Callable`, `Signal.connect`, `WeakRef`, `Object.free`, `preload`, `load`, `push_error`) predate 4.3 and appear in neither `breaking-changes.md` nor `deprecated-apis.md`. The live 4.7 class reference was **not** consulted; every claim below rests on the local reference library and on probes run on the installed binary. The architecture table rates ADR-0001 HIGH because the Flow GDD marks every engine behaviour unverified until a phone run, and that rating stands. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (lines 17, 69), `deprecated-apis.md`, `current-best-practices.md` (GDScript 4.5+, 4.7, Command Line), `modules/input.md` (section Verified on 4.7.2), `.claude/scripts/godot-parse-check.gd` (header) |
| **Post-Cutoff APIs Used** | None. Code under this ADR must never override a method with a typed return without an explicit `return` (4.7 break) and uses no `@abstract` class (4.5). |
| **Verification Required** | (1) Run `prototypes/adr-0003-spike/lifecycle_probe.gd` and `adr0001_checks/probe2.gd` on an Android **release** export template: Callable and signal lifetime as in the table below; `push_error` still prints; and record whether `.call()` on a dead Callable aborts the calling function or returns null (debug-only behaviour is expected). (2) A scene test instantiates `FATAL_SCENE` with a null catalogue on an Android export, which also proves the export filter kept the scene (shared with ADR-0002's manifest proof). (3) `free()` of the wrapper from `AppRoot._process` on a phone while a finger is down raises no error and the next gesture starts clean. (4) The `OBJECT_COUNT` retry check below holds on a device. |

Probe results on the installed 4.7.2 binary (a debug build; `lifecycle_probe.gd` on 2026-11-04, `adr0001_checks/probe2.gd` on 2026-11-05), which this decision relies on:

| Behaviour | Observed |
|---|---|
| Method Callable keeps its `RefCounted` target alive | No. `is_valid()` turns false once the target is released. |
| Signal connection keeps the listener alive, in either direction between two `RefCounted` objects | No. The connection is removed when the listener dies; `emit()` then does nothing. |
| `Callable.call()` on a dead method Callable | **Debug build:** script error, the function that made the call aborts there, its caller continues. Release behaviour unverified (Verification item 1); correctness never depends on it. |
| Unset `Callable` | `is_valid()` false, `is_null()` true. A Callable on a freed `Node` is `is_valid()` false but `is_null()` false, so guards use `is_valid()`. |
| `queue_free()` | Node still valid in the same frame. |
| `free()` of a child `Node2D` from the parent's `_process`, with a touch and a drag queued in the same frame | Node invalid at once; a `Battle` held in a typed field on it is released; no error; the child's `_process` does not run again; the queued events go nowhere next frame. |
| `RefCounted` back-reference (a sim holding `Battle`, or anything that holds the sim) | Cycle, never released. The weakref test catches only the objects it names. |
| `Callable.bind()` | Holds its bound `RefCounted` arguments strongly; does not hold its target. |
| Lambda connected to a sibling's signal, capturing only `self` | Does not leak. Flow Rule 2a's earlier probe reports a lambda capturing a local target does keep it alive. |
| `static var` on a `RefCounted` class | Persists across instances, so it would outlive a retry. |
| `preload` of a `.tscn` whose script has a parse error | The host script still loads; the instance is a bare `Control` with no script. Only a **missing** file fails the host script, which then runs with no script at all. |
| `--check-only -s` on a file with a parse error | Exits 0 on this install (macOS). It is not a parse check and not an autoload lint. |
| `push_error()` | Prints and execution continues. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None. This is the first ADR; it defines the composition root the others plug into. |
| **Enables** | ADR-0002 (the catalogue the root loads and holds), ADR-0003 (the adapter the wrapper builds and the lifecycle events it forwards), ADR-0004 (the Clock lives in the wrapper this ADR places), ADR-0005 (the modifier and cost accessor the sims read through the root-built context), ADR-0006 (every battle-internal signal is connected in `build()`), ADR-0007 (the headless harness calls `build()` with fake callables), ADR-0008 (the resolver the wrapper creates per battle), ADR-0009 (the sims are built and injected in `build()`), ADR-0010 (HeroInput and TowerInput are wrapper objects), ADR-0011 (views live in the wrapper). |
| **Delegates To** | ADR-0002: the load API and whether it is synchronous or threaded, and the validator's per-field error text (TR-data-006's "name each error"). ADR-0003: which lifecycle notifications reach the adapter, and Verification item 3. ADR-0004: the Clock, `stop_clock()`, and where the seed comes from. ADR-0007: the autoload lint, the parse check, the injected-callable and `static var` lint, the listener-count wiring test (TR-tower-013) and class-name prefixing (QQ-16). ADR-0008: `InputResolver.create`. ADR-0009: Enemy & Wave's Waiting/Active/Finished machine (TR-enemy-012's first clause). ADR-0010: the wrapper-built RunLog, and Tower's read-before-mutate rule (TR-tower-006's second clause) and the hit radii as constants on the input objects (TR-input-012's last clause). |
| **Blocks** | Every Game State & Stage Flow story (Boot, Retry, Cancel wiring, Fatal), and the first story of every other system, since nothing can be instantiated without `build()`. No stories exist yet. |
| **Ordering Note** | Write before any `.gd` file under `src/`. ADR-0002 must be Proposed before the Boot story starts, because boot step 2 calls its load API. If ADR-0007 prefixes class names (QQ-16), the names here are renamed without reopening this ADR. |

## Context

### Problem Statement
TowerRiot's two prototypes leaked state between attempts through hand-listed resets and reached gameplay through scene-owned roots that could not run without a window. The GDDs now require a battle that is a pure function of `(catalogue, stage_id, seed, command script)`, bots and tests that build one headless, a retry that rebuilds instead of resetting, and one fatal path with no fallbacks (Flow Rules 1, 2, 2a, 16, 18; Data Rules on load and failure). Every other ADR assumes a composition root with these properties, so it must be decided first.

### Constraints
- Godot 4.7.2, GDScript, no exceptions: a failing function finishes on a garbage value, so the fatal path has to be a latch every caller checks, not a thrown error (Flow Rule 18).
- `RefCounted` lifetime is reference-counted. A method Callable or a signal connection is not a reference; a back-reference, a `bind()` argument, a `static var` or a lambda capturing a local is (probe table).
- `queue_free()` keeps a node, and anything it holds, alive to the end of the frame (probe), so a retry that must prove the old battle is gone cannot use it.
- Solo developer, workflow `full`: the decision must be checkable by a lint and a code review, not by discipline alone.
- Headless CI runs gdUnit4 with no window and no main scene; nothing gameplay may touch a node (TR-state-002, TR-data-012).
- Android kills an app that blocks its main thread for about 5 s (ANR), against a catalogue load budget of at most 1000 ms median (QQ-11).

### Requirements
- One main scene, no autoload, that triggers the catalogue load once, holds the Ready catalogue for the session and owns the fatal screen (TR-state-001, TR-data-004, TR-data-011).
- A scene-free `build(catalogue, stage_id, seed, fatal_handler)` that wires every system by explicit signal connections, runs headless, and on a stage that cannot be built calls the handler and returns null (TR-state-002).
- Injected callables for `halted()`, `in_build()`, `targets()`, `cancel_input()`, `wave_index()`, `fatal()`, `dev_error()`, `to_ticks()` plus the hand flag and the Hero and Burst IDs (TR-enemy-005, TR-tower-006, TR-hero-004, TR-enemy-012, TR-data-009).
- The battle holds a strong typed field for every helper; the builder holds nothing (TR-state-015).
- One idempotent fatal handler that keeps the first cause, overrides Won, Lost and Paused, latches, halts the tick, discards a partial build, and is reached by load failure, bad accessor call, a stage scene that fails to load and a null resolver `create` (TR-state-011, TR-data-006).
- Retry by latch on the root, acted on next frame, Fatal first; the whole battle destroyed and rebuilt between ticks; a `weakref` to the old battle null afterwards; no listener kept alive by a signal connection (TR-state-009, TR-hud-006, TR-tower-013).
- `cancel_input()` a guarded public `Battle` method set by the wrapper; the wrapper builds the resolver and adapter per battle and injects the one resolver (TR-state-016, TR-input-012).

## Decision

**1. Main scene and app states.** `res://src/app/app_root.tscn` is the project's `run/main_scene`. Its script `AppRoot extends Node` has exactly three states, `BOOT`, `IN_STAGE` and `FATAL`, in one private field `_state` (the read is `state()`, so the field cannot share the name), and no gameplay reference: it reads `Battle.is_over()` and nothing else about a battle. `project.godot` has no `[autoload]` section; ADR-0007's lint is `! grep -q '^\[autoload\]' project.godot`, since `--check-only` is neither a parse check nor an autoload detector on this install (probe table). `AppRoot` owns: the `Catalogue` once Ready, the app-level `FatalLatch`, the retry latch (a `bool`), the current `Battle` and `BattleWrapper` references, and a preloaded fatal scene.

**2. Boot.** In `_ready()`, in order: (a) construct the app `FatalLatch` with no upstream; (b) `const FATAL_SCENE: PackedScene = preload("res://src/app/fatal_screen.tscn")` is a script-free scene (a `Control` with a `Label`; `AppRoot` sets the text), so a broken script in it is impossible, and a missing file fails the parse check in CI and the first run of each export, which is what "guaranteed to load" means here; (c) call the catalogue load (API in ADR-0002) once; `Failed` calls `fatal(cause)`; `AppRoot` enters `IN_STAGE` only on `Ready`, and whether the load is synchronous or threaded is ADR-0002's, bounded by the ANR constraint above; (d) on Ready, pick `stage_id` (MVP: the one stage) and take the seed from ADR-0004's seed source, record both through the wrapper-built RunLog (ADR-0010), then run step 4 below. No reload path exists; a failed load is Fatal.

**3. Builder and Battle.** `BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler) -> Battle` is a `static` function on a `RefCounted` class with no instance state. In one function it: creates the per-battle `FatalLatch(fatal_handler)` first; validates the stage inputs (a null Stage record calls `latch.fatal()` and returns null); constructs the one `StatAccessor`, then Flow, Combat, EnemyWave, TowerSim and HeroSim; makes every connection between battle systems with `Signal.connect(obj.method)` and no flags; injects every callable of `architecture.md` B9 as a method Callable; and returns a `Battle extends RefCounted` whose typed fields hold every object it made. `build()` never touches a node, never reads `Engine`, `Time` or `OS`, and is never called from inside a signal handler. If `latch.is_set` after any step, `build()` returns null and the partial objects die with the function's locals. `Battle` exposes the reads the wrapper injects onward: `left_handed`, `hero_id`, `burst_id`, `dt`, `to_ticks`, `in_build`, plus `is_over()` for `AppRoot`. This reinterprets TR-hero-004's "the builder injects … into HeroInput and the HUD": the builder injects into the sims; the wrapper injects into HeroInput and HudLogic from `Battle`'s reads, as B4 and B9 already say. The registry text should be updated at `/architecture-review`.

**4. Wrapper.** `BattleWrapper` is a scene (`res://src/app/battle_wrapper.tscn`, root `Node2D`) that `AppRoot` loads at runtime with `load()` after `build()` returns non-null, null-checks (`null` calls `fatal("wrapper scene failed to load")`), instances, adds as a child, and gives the `Battle` through `setup(battle, dev_telemetry)`, where `AppRoot` passes `OS.is_debug_build()` (the only read of it) and the wrapper builds RunLog and GestureLog only when `dev_telemetry` is true. `setup` runs the assembly of `architecture.md` Data Flow 4 step 6, checking `battle.fatal_latch.is_set` after each step and stopping at the first set latch. It loads the Stage record's look-only scene the same way, with `load()` and a null check into `fatal()`. It creates `InputResolver.create(drag_slop, tap_slop)` from the Input record; a null result calls `battle.fatal_latch.fatal("resolver create returned null")` and builds no adapter. It injects that one resolver into HeroInput, TowerInput and HudLogic (no global; the hit radii are constants on those objects, ADR-0010), connects the HUD's listeners (`tower_built`, `tower_inspected`), injects `AppRoot.request_retry` into HudLogic, and calls `battle.set_input_cancel(resolver.cancel)`. The wrapper holds no gameplay logic, never references `AppRoot` as a type (no preload cycle), and is absent headless.

**5. Injection and ownership rules.** Every injected value is either a plain value fixed at build or a method Callable whose target has a named strong holder that outlives every call: `Battle` for battle objects, `BattleWrapper` for the resolver, adapter and input objects, `AppRoot` for itself. No lambda, no `Callable.bind()` or `bindv()`, no `static var` under `src/battle/`, and no `CONNECT_DEFERRED` or `CONNECT_ONE_SHOT` on gameplay signals. No object `Battle` holds may store a reference to `Battle` or to any object that holds it, and no two sims may hold each other; reads go through method Callables such as `battle.halted` (probe: a back-reference is a cycle the weakref test cannot see). Exactly two Callables may be unset and are guarded with `is_valid()`: `Battle.cancel_input()` (headless) and the `FatalLatch` upstream (tests). Every other injected Callable is set in `build()` or `setup()`, and a call on it that fails is a defect. The lint (ADR-0007) greps `src/battle/` for `func(`, `func (`, `.bind(`, `bindv(` and `static var`; this bans every lambda in gameplay code, including `sort_custom(func…)`, so ADR-0009's targeting helpers use method Callables, which is intended.

**6. Fatal path.** `FatalLatch extends RefCounted` has `is_set: bool`, `cause: String` and `fatal(p_cause: String) -> void`: if already set, return; else set both fields and call the upstream Callable if `is_valid()`. The per-battle latch's upstream is `AppRoot.fatal`, so one call latches both. `Battle.halted()` reads the battle latch and Flow's outcome. After the battle latch sets, Flow commits `FATAL` and emits `phase_changed(FATAL)` once (Flow Rule 15), the tick in progress halts at the next `halted()` check, and later ticks return at once. `AppRoot.fatal` sets the app latch and `_state = FATAL`; on its next `_process` it stops the clock, calls `battle.cancel_input()` if a battle exists, tears the wrapper down with step 7's call if one exists, drops the battle, instances `FATAL_SCENE` and shows it with `cause` when `OS.is_debug_build()`, otherwise a fixed string. The screen reads nothing from the catalogue. Fatal overrides Won, Lost and Paused (creative director's ruling, Flow Rule 18); the Flow GDD's open question on text fallback for the result reads is answered **no** for MVP: a bad read is a defect that must surface, and nothing is saved, so the cost is one retry. Revisit when saves arrive; the GDD row is updated when this ADR is Accepted.

**7. Retry and teardown.** The HUD's Retry button calls `AppRoot.request_retry()`, which sets the retry latch and returns; it never frees its caller. On `AppRoot`'s next `_process`: if the app latch is set, run step 6's teardown and stop; if the latch is set but `battle.is_over()` is false, clear it and do nothing; otherwise stop the Clock, call `battle.cancel_input()`, `remove_child(wrapper)` then `wrapper.free()`, set `battle = null` and `wrapper = null`, then `build()` again with the same catalogue and the seed ADR-0004 supplies for a retry, and load and set up a new wrapper (a null `build()` instances no wrapper). `free()`, not `queue_free()`: the probe shows `queue_free()` leaves the node and everything it holds alive to the frame's end, and the Retry acceptance row demands that a `weakref` to the old battle, every system, the accessor and the resolver read null right after teardown. The row's "a retried battle's snapshot equals a fresh one" compares against a fresh `build()` given the retry's seed. The resolver and adapter die with the wrapper. The retry latch is idempotent: a second press in the same frame is one rebuild. The retry test also asserts `Performance.get_monitor(Performance.OBJECT_COUNT)` is equal before `build()` and after the drop, which catches cycles the weakref list does not name.

**8. Errors that are not fatal.** `assert()` is banned in `src/`: it does not survive a release build, so a defect there runs on, and TR-data-009 requires a sink that survives release and that tests replace. A defect the design says must not halt the battle (Enemy & Wave's `start_next_wave()` in the wrong state, and a guarded command called re-entrantly, `REENTERED` in ADR-0010 Decision 2) goes to the injected `dev_error(msg)`, a method on a `DevErrorSink extends RefCounted` whose default `report()` calls `push_error(msg)` and whose test fake records; a class is needed because `push_error` is a global function, not a method Callable target. Tests always inject the recording fake, since gdUnit4 may count a `push_error` as a failure. `HALTED` is an ordinary command result that reports nothing: it is expected after Won or Lost and would flood the sink. The run log and gesture log are dev-only listeners and never on this path.

**9. Headless.** Tests and bots call `BattleBuilder.build()` directly with a `FatalLatch` whose upstream is a recording fake's method, never `AppRoot`. The Flow GDD's Boot row cases that need a scene (a wrapper given `drag_slop` 7 so `create` returns null; a wrapper or stage scene that fails to load; `FATAL_SCENE` instanced with a null catalogue) run as scene tests in the editor-driven suite, not headless.

**10. Directory layout.** `src/app/` holds `AppRoot`, the wrapper and the two scenes; `src/battle/` holds only `RefCounted` gameplay classes; `src/presentation/` holds views, HUD nodes, the Clock and the wrapper-side input objects (HeroInput, TowerInput, HudLogic, the adapter). ADR-0010 and ADR-0011 place their classes under these roots.

### Architecture Diagram

```
project.godot  run/main_scene ─► res://src/app/app_root.tscn
┌─ AppRoot (Node) ───────────────────────────────────────────────────────────┐
│ _state: BOOT | IN_STAGE | FATAL    catalogue: Catalogue (Ready, session)   │
│ app_latch: FatalLatch(no upstream) _retry_requested: bool                  │
│ const FATAL_SCENE = preload(...)   battle: Battle   wrapper: BattleWrapper │
│                                                                           │
│ _ready: load catalogue ─Failed─► fatal(cause)                             │
│         ─Ready─► battle = BattleBuilder.build(cat, stage, seed, fatal)    │
│                  wrapper = load(wrapper path).instantiate() (null ► fatal)│
│                  add_child(wrapper); wrapper.setup(battle, dbg)           │
│ _process: if app_latch.is_set ─► teardown, show FATAL_SCENE, stop        │
│           elif _retry_requested and battle.is_over() ─► stop clock,      │
│                  battle.cancel_input(), remove_child(wrapper);            │
│                  wrapper.free(); battle = null; build again (same cat)    │
└───────────────────────────────────────────────────────────────────────────┘
          │ build()                                   │ setup(battle,dbg)
          ▼                                           ▼
┌─ Battle (RefCounted, strong typed fields) ─┐  ┌─ BattleWrapper (Node2D scene) ───┐
│ fatal_latch: FatalLatch(upstream=AppRoot)  │  │ Clock · InputResolver · Adapter   │
│ accessor · flow · combat · enemy_wave      │◄─┤ TowerInput · HudLogic · HeroInput │
│ tower_sim · hero_sim · dev_sink            │  │ HudTopBand · HudField · HudModals │
│ tick(dt) · halted() · is_over()            │  │ stage look scene · field views    │
│ cancel_input()  (no back-references)       │  │ (never references AppRoot)        │
└────────────────────────────────────────────┘  └───────────────────────────────────┘
```

### Key Interfaces

```gdscript
class_name AppRoot extends Node
enum State { BOOT, IN_STAGE, FATAL }
const FATAL_SCENE: PackedScene = preload("res://src/app/fatal_screen.tscn")   # script-free scene
const WRAPPER_PATH := "res://src/app/battle_wrapper.tscn"                        # load()ed, null-checked
func state() -> State
func fatal(p_cause: String) -> void        ## App-level handler. Idempotent, first cause kept. Passed to build().
func request_retry() -> void               ## Sets the retry latch. Acted on next _process, Fatal first. Never frees the caller.

class_name FatalLatch extends RefCounted
var is_set: bool
var cause: String
func _init(upstream: Callable = Callable()) -> void
func fatal(p_cause: String) -> void        ## Idempotent. Sets fields, then upstream.call(p_cause) if upstream.is_valid().

class_name DevErrorSink extends RefCounted
func report(msg: String) -> void           ## Default: push_error(msg). Tests subclass and record.

class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, rng_seed: int, fatal_handler: Callable) -> Battle
## Returns null after calling fatal_handler when the stage cannot be built. Touches no node.

class_name Battle extends RefCounted       ## Every helper is a typed field (architecture.md B4).
func tick(dt: float) -> void
func halted() -> bool
func is_over() -> bool                     ## Flow outcome WON or LOST, or the latch set. AppRoot's only battle read.
func set_input_cancel(cancel: Callable) -> void
func cancel_input() -> void                ## Guarded with is_valid(); Flow and AppRoot call it.
# Reads the wrapper injects onward (set at build, never change):
var left_handed: bool
var hero_id: StringName
var burst_id: StringName
var dt: float
func to_ticks(seconds: float) -> int
func in_build() -> bool

class_name BattleWrapper extends Node2D
func setup(battle: Battle, dev_telemetry: bool) -> void  ## Assembles Data Flow 4 step 6; checks battle.fatal_latch.is_set after each step.
func stop_clock() -> void                  ## Clock internals are ADR-0004's.
```

### Implementation Guidelines
- `project.godot` **must** have no `[autoload]` section and **must** set `run/main_scene` to `res://src/app/app_root.tscn`.
- `AppRoot` **must** have exactly three states and **must never** hold a gameplay reference beyond `Battle.is_over()`.
- Gameplay classes (`src/battle/**`) **must** extend `RefCounted`, **must never** extend `Node`, **must never** declare a `static var`, and **must never** reference `Engine`, `Time`, `OS`, `SceneTree`, a `Timer` or `await`.
- Connections and injections between battle systems **must** happen only inside `BattleBuilder.build()`; those involving a wrapper-built object (resolver, adapter, HeroInput, TowerInput, HudLogic, views, `set_input_cancel`, `request_retry`) **must** happen only inside `BattleWrapper.setup()`; nowhere else.
- Gameplay signals **must never** be connected with `CONNECT_DEFERRED` or `CONNECT_ONE_SHOT`.
- `build()` **must never** be called from inside a signal handler.
- Injected callables **must** be method Callables whose target is held by `Battle`, `BattleWrapper` or `AppRoot`; code **must never** pass a lambda, `bind()` or `bindv()` result as an injected callable or signal target.
- No object held by `Battle` **may ever** store a reference to `Battle` or to an object that holds it, and no two sims **may ever** hold each other.
- Only `Battle.cancel_input()` and the `FatalLatch` upstream **may** be guarded with `is_valid()`; every other injected Callable **must** be unguarded, so a missing injection fails in the first test.
- Teardown **must** use `remove_child()` then `free()` on the wrapper, from `AppRoot._process` only; `queue_free()` **must never** be used on the wrapper or anything that holds a `Battle`; retry and Fatal teardown **must never** run from a signal handler or an input callback.
- The Retry button **must never** free its caller; it calls `request_retry()` and returns.
- The wrapper scene and the Stage record's scene **must** be loaded with `load()` and null-checked into `fatal()`; the fatal scene **must** be a script-free `preload` constant on `AppRoot` and **must never** read the catalogue.
- The wrapper and everything under `src/presentation/` **must never** reference `AppRoot` as a type.
- `assert()` **must never** appear under `src/`. Unrecoverable conditions call the injected `fatal()`; recoverable defects call the injected `dev_error()`.
- A call to the injected `fatal()` **must** be followed by `return` in the calling function, and every loop over systems **must** check `halted()` after each accessor read and each emit (TR-enemy-005, TR-tower-006).
- The fatal screen **must** show `cause` only when `OS.is_debug_build()`.
- No class under this ADR **must ever** override a method with a typed return without an explicit `return` (4.7 break).

## Alternatives Considered

### Alternative 1: Autoload singletons (GameManager, EventBus)
- **Description**: A `GameManager` autoload owns the catalogue, the current battle and the retry; an `EventBus` autoload carries battle signals.
- **Pros**: The idiomatic beginner shape; no injection; any node can reach anything.
- **Cons**: Global state survives a retry, which is exactly the leak the prototypes had; a headless test has to load the autoloads or stub them; the view allowlist test cannot count listeners on a global bus; the framework parse check has to be told about every autoload.
- **Rejection Reason**: Contradicts TR-data-011, TR-state-001 and the Flow GDD's "Deliberately not built" list (event-bus autoload, DI container).

### Alternative 2: Scene-owned battle root (the technical director's original note)
- **Description**: The battle scene's root script constructs and wires the systems in `_ready()`.
- **Pros**: One file to read; the scene tree shows the structure.
- **Cons**: Cannot run without a window, so bots and tests need the full scene; teardown becomes `queue_free()` by habit; views and sims share a lifetime.
- **Rejection Reason**: Flow Rule 2 amends the note for this reason; the TD-ARCHITECTURE review accepted the amendment on technical merit (QQ-08). Accepting this ADR records it.

### Alternative 3: In-place reset on retry
- **Description**: Each system exposes `reset()`; retry calls them in order.
- **Pros**: Cheaper than a rebuild; no teardown timing question.
- **Cons**: The hero-pin prototype reset 22 fields by hand and still leaked; every new field is a new leak; the pure-function-of-seed property is lost.
- **Rejection Reason**: Flow Rule 16 forbids it; the rebuild cost is one `build()` call and is budgeted under QQ-11.

### Alternative 4: `queue_free()` teardown
- **Description**: Retry calls `wrapper.queue_free()` and drops the battle; the engine frees at frame end.
- **Pros**: The documented safe default; never frees a node mid-callback.
- **Cons**: The probe shows the node, and so the old battle, is alive until the frame ends; the weakref acceptance row fails; two battles exist for part of a frame, and the old one still holds the resolver.
- **Rejection Reason**: The acceptance row is the spec. `free()` from `AppRoot._process` on a child that is not the node being processed raised no error with input queued in the same frame (probe); the phone confirmation is Verification item 3.

### Alternative 5: `assert()` for defects
- **Description**: Invariants are `assert()`ed; release builds strip them.
- **Pros**: Zero release cost; reads as documentation.
- **Cons**: Does not survive release, so a defect there runs on; in a debug build it behaves as a script error rather than latching; it cannot be replaced by a recording fake.
- **Rejection Reason**: TR-data-009 and TR-enemy-012 require a sink that survives release and that tests replace.

### Alternative 6: Preload the wrapper scene on `AppRoot`
- **Description**: `const BATTLE_WRAPPER := preload(...)` beside `FATAL_SCENE`.
- **Pros**: One less runtime load; the dependency is visible.
- **Cons**: A missing file anywhere under the wrapper's dependency tree fails `AppRoot`'s own script, and the app shows a blank main scene instead of the fatal screen; a broken script gives a script-less wrapper whose `setup()` fails outside the fatal path (probe).
- **Rejection Reason**: The fatal screen must not depend on any presentation script loading. Runtime `load()` with a null check into `fatal()` keeps the dependency one-way.

## Consequences

### Positive
- A battle is constructed by one function, so a misspelt signal is a parse error and every dependency is visible in one place.
- Bots, balance tools and tests build battles with no window and no engine clock.
- Retry is provably clean: the weakref test plus the object-count check, not a reset checklist.
- Every failure, from a missing manifest to a bad stat key, reaches one screen through one latch, and nothing half-runs after it.

### Negative
- Every new helper needs a typed field on `Battle` and a line in `build()`; forgetting the field makes the helper die silently, which is why the lint and the weakref test exist.
- Every lambda is banned in `src/battle/`, so sorting and filtering helpers use named methods.
- `free()` during `_process` is less forgiving than `queue_free()`; the teardown must stay in `AppRoot._process` and nowhere else.
- No reload: a transient disk failure at boot is a relaunch.
- A bad read on the result screen replaces a Won with Fatal (accepted for MVP).

## Risks
- **The release export differs from the editor binary on Callable lifetime, dead-call behaviour or `push_error`.** Mitigation: Verification item 1 runs both probes on an Android release export before the Boot story closes; the design never relies on the dead-call abort, only on the latch and `halted()` checks.
- **Someone adds an autoload for convenience.** Mitigation: ADR-0007's `[autoload]` grep in CI; `/create-control-manifest` carries the rule.
- **A cycle sneaks in through a back-reference or a bound argument.** Mitigation: the no-back-reference guideline, the lint, the weakref test and the `OBJECT_COUNT` check; the engine's "ObjectDB instances were leaked at exit" line is a further cheap signal.
- **The fatal scene file is dropped by an export filter or deleted.** Mitigation: the CI parse check fails on a missing `preload` path; Verification item 2 instantiates it on an export.
- **`free()` while a touch is held.** Mitigation: the new adapter never saw the press and drops its moves until lift (Flow Edge Cases); phone confirmation under Verification item 3.
- **Shadowing warnings.** `seed` shadows the global `seed()` and a `cause` parameter shadows the field, so the names are `rng_seed` and `p_cause`; the parse check does not print warnings headless, so code review watches for new shadows.
- **Stale GDD rows.** The Flow GDD's deferred criterion "Lifecycle mapping, owner ADR-0001" and its open question on the pause mechanism now belong to ADR-0003 (TR-state-010); its result-read fallback question is answered here. Update both rows, and TR-hero-004's registry text, when this ADR is Accepted.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-001: minimal main-scene root, no autoload, triggers load, holds catalogue, owns fatal screen, alone survives retry | Decision 1 and 2; `AppRoot` is the only node that survives teardown |
| game-state-stage-flow.md | TR-state-002: scene-free `build()`, explicit connections, headless, null on failure, thin wrapper | Decision 3 and 4 |
| game-state-stage-flow.md | TR-state-009: retry destroys and rebuilds between ticks, latch on root, weakref null | Decision 7; `remove_child()` + `free()`; `OBJECT_COUNT` check |
| game-state-stage-flow.md | TR-state-011: one idempotent fatal handler, first cause, overrides outcomes, latches, halts, discards partial build, four entry points, screen guaranteed | Decision 6 (handler, overrides, halt), Decision 3 (partial build), Decision 4 (stage scene and null resolver), Decision 2 (script-free preloaded screen) |
| game-state-stage-flow.md | TR-state-015: battle holds every helper in a typed field, builder holds nothing | Decision 3 and 5; probe table |
| game-state-stage-flow.md | TR-state-016: guarded public `cancel_input()` set by the wrapper, called on Won, Lost, Paused, Fatal and retry | Decision 4, 5 and 7 |
| data-config-pipeline.md | TR-data-004: load once, all-or-nothing, before the first gameplay scene, no reload | Decision 2; sync vs threaded delegated to ADR-0002 |
| data-config-pipeline.md | TR-data-006: no fallbacks, catalogue-free fatal screen, no saves, dev runs name errors | Decision 6; the per-field error text is ADR-0002's validator |
| data-config-pipeline.md | TR-data-009: bad accessor call goes to an injected, test-replaceable handler, not assert | Decision 8 (`fatal()` for accessor faults, `DevErrorSink` for recoverable defects) |
| data-config-pipeline.md | TR-data-011: no autoload or global; root holds catalogue; builder injects it | Decision 1 and 3 |
| input-gesture-resolver.md | TR-input-012: wrapper builds resolver and adapter per battle, injects the one resolver; hit radii are constants on the input objects | Decision 4 (create, inject into HeroInput, TowerInput, HudLogic); radii delegated to ADR-0010 |
| enemy-wave.md | TR-enemy-005: injected `halted()` checked after every read and signal; never references Flow | Decision 5 and 6; Implementation Guidelines |
| enemy-wave.md | TR-enemy-012: `start_next_wave()` logs to an injected dev-error sink, not assert | Decision 8 (sink); the Waiting/Active/Finished machine is ADR-0009's |
| tower-system.md | TR-tower-006: injected `halted()` checked after every read and signal; reads before mutation | Decision 5 and 6; read-before-mutate delegated to ADR-0010 |
| tower-system.md | TR-tower-013: retry leaves no old battle alive through a connection; wiring test names a missing one | Decision 7; probe (connections die with the listener); the listener-count test is ADR-0007's mechanism |
| hero-system.md | TR-hero-004: `halted()`, `in_build()`, hand, Hero ID and Burst ID reach HeroSim, HeroInput and the HUD | Decision 3 (builder into HeroSim) and 4 (wrapper into HeroInput and HudLogic from `Battle`'s reads); registry text to be reworded |
| battle-hud.md | TR-hud-006: Retry sets an idempotent latch and never frees its caller; the root's next frame checks Fatal, stops, cancels, frees, rebuilds | Decision 7 |

## Performance Implications
- **CPU**: Boot is one catalogue load (ADR-0002 budgets it, QQ-11, under the 5 s ANR limit). A retry is one `build()` plus one wrapper `load()` and instance, between ticks, in a frame where nothing else runs; unmeasured until the first phone build.
- **Memory**: One catalogue for the session; one battle at a time. The old battle is released on the retry frame, so peak is one battle plus the wrapper scene.
- **Load Time**: The fatal scene is `preload`ed with the main scene and is a single Control; the wrapper is `load()`ed once per battle.
- **Network**: None.

## Migration Plan
Greenfield: `src/` holds no `.gd` file. Create `src/app/app_root.tscn`, `app_root.gd`, `fatal_screen.tscn` (no script), `battle_wrapper.tscn`, `battle_wrapper.gd`; `src/battle/battle.gd`, `battle_builder.gd`, `fatal_latch.gd`, `dev_error_sink.gd`; `src/presentation/` as ADR-0010 and ADR-0011 fill it. Set `run/main_scene` in `project.godot`. Add a note to `docs/engine-reference/godot/current-best-practices.md` that `--check-only` exits 0 on parse errors on macOS 4.7.2 (done with this ADR). The prototypes under `prototypes/` are not migrated.

## Validation Criteria
- Flow GDD acceptance rows Boot, Retry, Cancel wiring and criterion 13 pass in `tests/` (ADR-0007 harness), with the scene-only cases in the editor-driven suite.
- The weakref test: after retry, `weakref` to the old `Battle`, each system, the accessor and the resolver returns null in the same frame (`var w: WeakRef = weakref(x)`; the untyped form does not parse). `OBJECT_COUNT` is equal before `build()` and after the drop.
- `godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- <files>` passes on every file under `src/`; `grep -q '^\[autoload\]' project.godot` finds nothing.
- ADR-0007's lint finds no `func(`, `func (`, `.bind(`, `bindv(` or `static var` under `src/battle/`.
- `lifecycle_probe.gd` and `probe2.gd` give the same results on an Android release export, with the dead-call row recorded either way.

## Related
- `docs/architecture/architecture.md` v4: Composition Root, Data Flow 4 to 7, B4, B9, QQ-08, QQ-16, QQ-17, QQ-21 (save/load seams are ADR-0002's to decide).
- `design/gdd/game-state-stage-flow.md` Rules 1, 2, 2a, 3, 15, 16, 18; Open Question on result-read fallback (answered no); deferred criterion "Lifecycle mapping" (now ADR-0003's).
- `design/gdd/data-config-pipeline.md` load and failure rules; `design/gdd/input-gesture-resolver.md` Rule 7 (cancel).
- Enables ADR-0002 to ADR-0011 as tabled above; delegations in the ADR Dependencies table.
- Probes: `prototypes/adr-0003-spike/lifecycle_probe.gd`, `prototypes/adr-0003-spike/adr0001_checks/probe2.gd` (with its `k_*.gd` parse fixtures); engine notes: `docs/engine-reference/godot/modules/input.md`, section Verified on 4.7.2.
