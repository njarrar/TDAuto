# ADR-0001: App Lifecycle, Composition Root and Fatal Path

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

godot-specialist (draft). Acceptance: the user, or technical-director on the user's confirmation.

TD-ADR: batch review 2026-11-04, CONCERNS; fixes applied.

2026-11-04: TD-ADR batch review and engine check fixes applied.

## Summary

TowerRiot has no autoloads, so one node must start the game, hold the catalogue, build and rebuild each battle, and stop everything on a fatal error. AppRoot, the main scene, owns the app states Boot, InStage and Fatal and the Ready catalogue; a scene-free `BattleBuilder` wires a `Battle` (a `RefCounted`) with method Callables only; a per-battle `FatalLatch` plus an AppRoot `FatalLatch` give one idempotent fatal path; Retry is a latch that drops every reference and rebuilds, proven by a weakref test.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2 installed, matches the pin) |
| **Domain** | Core (Scripting) |
| **Layer** | Foundation (the Required ADRs table lists it there; the modules it governs sit in the Composition Root, which has no Layer value of its own) |
| **Knowledge Risk** | HIGH (GDScript 4.5 and 4.7 changes are post-cutoff; Callable lifetime is unreferenced) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/architecture/architecture.md` v3 (Engine Knowledge Gap Summary, Module Ownership, Data Flow 4, 5 and 7, API Boundaries B0, B4, B9, Open Questions); official class reference at tag 4.7.2-stable: `doc/classes/Node.xml`, `doc/classes/Object.xml`, `doc/classes/RefCounted.xml`, `doc/classes/Callable.xml`, `doc/classes/Signal.xml`, `doc/classes/WeakRef.xml`, `doc/classes/@GlobalScope.xml`, `doc/classes/OS.xml`, `doc/classes/Engine.xml`, `modules/gdscript/doc_classes/@GDScript.xml` |
| **Post-Cutoff APIs Used** | None directly. The 4.7 rule that an override of a typed-return method inherits that type and needs an explicit `return` applies to every test fake of a typed base |
| **Verification Required** | The runs in NOT SOURCEABLE below; the weakref test in Validation Criteria under `godot --headless` on 4.7.2 |

### Sourced engine facts

| Claim | Source |
|---|---|
| `RefCounted` objects are released when no longer referenced and need no `free()` | doc/classes/RefCounted.xml@4.7.2-stable, class description |
| `RefCounted` instances in a reference cycle are not freed automatically; `weakref` breaks the cycle | doc/classes/RefCounted.xml@4.7.2-stable, class description; doc/classes/@GlobalScope.xml@4.7.2-stable, `weakref` |
| A weak reference does not keep an object alive, but "until the object is actually destroyed the weak reference may return the object even if there are no strong references to it" | doc/classes/@GlobalScope.xml@4.7.2-stable, `weakref` |
| `WeakRef.get_ref()` returns `null` if the object no longer exists | doc/classes/WeakRef.xml@4.7.2-stable, `get_ref` |
| `Callable.is_valid()` is true if the callable's object exists and has a valid method name, or the callable is custom | doc/classes/Callable.xml@4.7.2-stable, `is_valid` |
| A GDScript lambda is a custom callable not tied to an `Object` instance | doc/classes/Callable.xml@4.7.2-stable, class description |
| A signal connects once to the same Callable; a second `connect` returns `ERR_INVALID_PARAMETER` and prints an error | doc/classes/Signal.xml@4.7.2-stable, `connect` |
| `_process`, `_physics_process` and the input callbacks are only called while the node is in the scene tree | doc/classes/Node.xml@4.7.2-stable, `_process`, `_physics_process`, `_input` (Note) |
| `remove_child` removes a node and its children without deleting them | doc/classes/Node.xml@4.7.2-stable, `remove_child` |
| `queue_free` deletes at the end of the current frame, after other deferred calls; safe to call more than once; children go too | doc/classes/Node.xml@4.7.2-stable, `queue_free` |
| `Object.free` deletes at once; references to the object become invalid | doc/classes/Object.xml@4.7.2-stable, `free` |
| Nodes with a lower `process_priority` run their process callbacks first, regardless of tree order | doc/classes/Node.xml@4.7.2-stable, `process_priority` |
| `_ready` runs children first, then the parent | doc/classes/Node.xml@4.7.2-stable, class description and `_ready` |
| `preload` loads the resource when the script is parsed; the path must be a constant string | modules/gdscript/doc_classes/@GDScript.xml@4.7.2-stable, `preload` |
| Code inside `assert` runs only in debug builds or from the editor; a release export behaves as if it were absent | modules/gdscript/doc_classes/@GDScript.xml@4.7.2-stable, `assert` (Warning) |
| `push_error` sends a message to the debugger and the OS terminal | doc/classes/@GlobalScope.xml@4.7.2-stable, `push_error` |
| `OS.is_debug_build()` is true in the editor and on a debug export template, false on a release template | doc/classes/OS.xml@4.7.2-stable, `is_debug_build` |
| `OS.has_feature("editor")` is true in the editor and when running from it, false in an export | doc/classes/Engine.xml@4.7.2-stable, `is_editor_hint` (Note) |

### NOT SOURCEABLE (blocks Acceptance)

- NOT SOURCEABLE: whether a method `Callable` or a signal connection keeps its `RefCounted` target alive. A 4.7.2 editor probe (architecture.md QQ-17) found it does not, and that `.call()` on a dead or empty Callable raises a script error and aborts the caller. Settled by a desktop headless run of an exported debug and release build that repeats the probe.
- NOT SOURCEABLE: whether a `RefCounted` is destroyed at once when its last strong reference drops, so that the weakref test may read `get_ref()` in the same function, or only later. The reference warns a weakref may still return the object. Settled by a desktop headless run of the weakref test (CI runs it after).
- NOT SOURCEABLE: whether a node removed with `remove_child` during AppRoot's `_process` still receives its own `_process` later in the same frame. Settled by a desktop headless run that logs the old wrapper's callbacks after Retry.
- NOT SOURCEABLE: whether `push_error` output reaches the OS log (logcat on Android) from a release export template. Settled by the phone session.
- NOT SOURCEABLE: whether the catalogue-free fatal scene, `preload`ed by AppRoot, loads from an Android export when the catalogue files are missing or corrupt. Settled by the phone session.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011 (each lists ADR-0001 in its Depends On) |
| **Blocks** | Game State & Stage Flow epic (boot, Retry, Fatal stories); every story that builds a battle; the bot and test harness |
| **Ordering Note** | Lifecycle notifications (pause, focus) and the adapter's `cancel()` belong to ADR-0003. The Clock that this ADR stops on Retry belongs to ADR-0004. Accept those two with this one. |

## Context

### Problem Statement

The game has no autoloads and no scene-owned battle. Something must own the catalogue across retries, build a battle that runs headless, wire it with no hidden references, rebuild it on Retry with nothing left over, and stop everything the same way when content or a call is bad. GDScript has no exceptions, so the fatal path must be explicit and checked by every caller.

### Current State

No code exists. `project.godot` sets no autoloads.

### Constraints

- Godot 4.7.2, typed GDScript, main thread only.
- No autoload or global (TR-data-011, TR-state-001).
- Simulation classes extend `RefCounted`, never `Node` (architecture.md API Boundaries).
- The battle must build headless for bots and tests (TR-state-002).
- `assert` is stripped from release exports, so release-relevant checks need another route.

### Requirements

- AppRoot loads the catalogue once, all or nothing, holds it, and alone survives a retry (TR-data-004, TR-state-001).
- One idempotent fatal handler that keeps the first cause and reaches a catalogue-free screen (TR-data-006, TR-state-011).
- Retry rebuilds; a weakref to the old battle reads null (TR-state-009, TR-tower-013, TR-hud-006).
- Injected `halted()`, `in_build()`, IDs, hand flag and sinks (TR-enemy-005, TR-tower-006, TR-hero-004, TR-enemy-012, TR-data-009).
- The wrapper builds the resolver and adapter per battle (TR-input-012).

## Decision

1. **AppRoot is the main scene** (`application/run/main_scene`), a `Node`. No autoload is ever added. AppRoot owns: the app state (`BOOT`, `IN_STAGE`, `FATAL`), the Ready `Catalogue`, the app-level `FatalLatch`, the retry latch, the current `Battle` and the current `BattleWrapper` node. AppRoot's states are separate from Flow's `Phase`.
2. **Boot** (Data Flow 4). In `AppRoot._ready`: create the app `FatalLatch`; the fatal scene is a `preload` constant, so it exists before any catalogue code runs. Call `Catalogue.from_manifest(manifest)` once. On `Failed`, call the app fatal handler with the error list and stop; there is no fallback and no reload, and saves are never opened. On `Ready`, keep the catalogue, pick `stage_id` and `rng_seed`, set `IN_STAGE` and build.
3. **The Builder is scene-free.** `BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler, options) -> Battle` touches no node, reads no engine clock and is never called from inside a signal. Order: (a) create the per-battle `FatalLatch` first, forwarding to `fatal_handler`; (b) validate stage inputs; (c) construct Flow, Combat, EnemyWave, TowerSim, HeroSim (skipped when `options.no_hero` is set), the one per-battle StatAccessor, whose failure Callable is the latch adapter `FatalLatch.on_accessor_fail` (Decision 7), and the tick-time object of ADR-0004; (d) make every signal connection and injection in this one function; (e) return the `Battle`. It checks `fatal_latch.is_fatal()` after each step and returns `null` once it is set, so a partial build is dropped and never ticked.
4. **Battle holds everything strongly.** `Battle` keeps typed fields for every sim, the `FatalLatch`, the StatAccessor and the `TickTime` object (added by ADR-0004). The Builder holds nothing after it returns. Because a Callable is expected not to keep its target alive (QQ-17; unsettled, see NOT SOURCEABLE item 1), every object behind an injected Callable must be a field on `Battle`.
5. **Injected callables are method Callables only.** No lambda and no `bind()` that captures a sim object, and no sim holds a reference to `Battle`. The injected set is B9 in architecture.md: `halted()`, `in_build()`, `targets()`, `cancel_input()`, `wave_index()`, `fatal(cause)`, `dev_error(msg)`, `to_ticks(seconds)`, the Hero record ID, `burst_id` and `left_handed`.
6. **Builder versus wrapper.** The Builder injects into sims only. The `BattleWrapper` scene, built by AppRoot after `build` returns a `Battle`, reads `left_handed`, `hero_id`, `burst_id`, `dt`, `to_ticks` and `in_build` from the `Battle` and injects them into HeroInput and HudLogic; the Builder never sees those. The wrapper builds `InputResolver.create(drag_slop, tap_slop)` from the Input record (a null result calls the fatal handler), calls `battle.set_input_cancel(resolver.cancel)`, then adds, in order, InputAdapter, Clock, TowerInput, HudLogic, HeroInput, HudTopBand, HudField, HudModals and the field views. It checks the battle `FatalLatch` after each step. The stage scene named by `StageRecord.scene_ref` is loaded here; a null load calls the fatal handler. Hit radii are constants on the input objects, not catalogue fields.
7. **Fatal path** (Data Flow 7). `FatalLatch` is pure: failure codes are `StringName` at the accessor (ADR-0005) and `String` here. `on_accessor_fail(cause: StringName, error: ValidationError)` is the adapter the Builder passes to the StatAccessor as its `fail` Callable; it calls `fatal(String(cause))` and keeps the error for the development screen. `fatal(cause)` keeps the first cause, is idempotent, and forwards once to its forward Callable; `is_fatal()` reads it. It emits `latched(cause)` once. The Builder connects `latched` to a Flow method, which sets Flow to `FATAL` (replacing WON, LOST or PAUSED), calls `cancel_input()` and emits `phase_changed(FATAL)`. `Battle.halted()` is true once the latch is set, so the rest of the current tick returns at once. The forward Callable is AppRoot's handler, which latches the app `FatalLatch` and sets `FATAL`. AppRoot's next `_process` tears the battle down (Decision 9, steps 2 and 3) and shows the fatal scene. Development builds (`OS.is_debug_build()`) show every error by file, record and field; release builds show the screen without them. Routes into `fatal`: catalogue load failure, a bad accessor call, a stage scene that fails to load, bad stage input, a null resolver.
8. **Errors without `assert`.** Release-relevant checks call the injected `fatal` or `dev_error` and use `push_error`; `assert` is never used for them. `dev_error(msg)` is a method Callable on a `DevErrorSink` (`RefCounted`) whose default calls `push_error` and survives release builds; tests inject a recording sink. EnemyWave's `start_next_wave()` misuse reports there (TR-enemy-012).
9. **Retry** (Data Flow 5). The Retry press only sets AppRoot's idempotent retry latch; it never frees its caller. AppRoot has a lower `process_priority` than the wrapper, so its `_process` runs first in the next process step. That step: (1) if the app state is `FATAL`, show the fatal screen and stop; (2) `wrapper.set_process(false)`, then `battle.cancel_input()`; (3) `remove_child(wrapper)` then `wrapper.queue_free()`; once out of the tree it gets no `_process` or input callbacks; (4) set the `Battle` field to null and keep no other reference; (5) `BattleBuilder.build(...)` again with the same catalogue, stage and seed; (6) build a new wrapper. Nodes are freed with `queue_free`, never `free`. Sim objects are never freed, only released.
10. **Who cancels input** (settled, QQ-19). Flow cancels through `cancel_input()` on Won, Lost, Paused and Fatal; AppRoot cancels on Retry; the adapter cancels on lifecycle events (ADR-0003). `Battle.cancel_input()` guards with `is_valid()`; headless nothing is set and it does nothing. A second cancel finds the resolver Idle and does nothing.

### Architecture Diagram

```
 engine ─▶ AppRoot (main scene, Node; process_priority below the wrapper)
             state: BOOT ─▶ IN_STAGE ─▶ FATAL (absorbing)
             owns: Catalogue, app FatalLatch, retry latch, battle, wrapper
             _ready: Catalogue.from_manifest ─Failed─▶ fatal(...) ─▶ fatal scene (preloaded)
                     BattleBuilder.build(cat, stage, rng_seed, _on_fatal) ─▶ Battle | null
                     BattleWrapper (scene): resolver, adapter, Clock, inputs, HUD, views
             _process: FATAL?  ─▶ teardown ; fatal scene
                       retry?  ─▶ set_process(false) ; cancel_input ; remove_child ;
                                  queue_free ; battle = null ; build again

 Battle (RefCounted) holds strongly:
   flow, combat, enemy_wave, tower_sim, hero_sim, stat_accessor, fatal_latch, tick time
   sims receive method Callables on those objects only; none references Battle

 fatal(cause) ─▶ battle FatalLatch (first cause) ─latched─▶ Flow.FATAL ─▶ phase_changed(FATAL)
                                    └─forward─▶ AppRoot._on_fatal ─▶ app FatalLatch ; state FATAL
```

### Key Interfaces

```gdscript
class_name AppRoot extends Node
enum AppState { BOOT, IN_STAGE, FATAL }
func request_retry() -> void              # idempotent; sets the latch only
func _on_fatal(cause: String) -> void      # the fatal_handler passed to build; idempotent

class_name FatalLatch extends RefCounted
signal latched(cause: String)              # emitted once, on the first fatal
func _init(forward: Callable = Callable()) -> void
func fatal(cause: String) -> void          # first cause wins; forwards once if forward.is_valid()
func on_accessor_fail(cause: StringName, error: ValidationError) -> void   # adapter for ADR-0005 `fail`; calls fatal(String(cause))
func is_fatal() -> bool
func cause() -> String

class_name DevErrorSink extends RefCounted
func report(msg: String) -> void           # default: push_error(msg); tests subclass and record

class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, rng_seed: int, fatal_handler: Callable, options: BuildOptions = null) -> Battle  # null after a fatal

## Test-only. A null `options` means the full battle. `no_hero = true` builds no HeroSim
## and Battle.tick step 5 skips HeroSim when it is null. The layer lint (ADR-0007) flags
## any use of BuildOptions from src/.
class_name BuildOptions extends RefCounted
var no_hero: bool = false

class_name Battle extends RefCounted
func tick(dt: float) -> void               # ADR-0004
func halted() -> bool                      # Flow WON, LOST or FATAL, or fatal_latch set; false while PAUSED
func set_input_cancel(cancel: Callable) -> void   # wrapper only
func cancel_input() -> void                # guarded with is_valid()
```

### Implementation Guidelines

- No autoload may be added to `project.godot`.
- AppRoot must be the only holder of the catalogue between battles.
- `BattleBuilder.build` must never touch a node, `Engine`, `Time`, `OS` or `await`, and must never be called from inside a signal handler.
- The Builder must create the battle `FatalLatch` before any other object and must return `null` once it is set.
- Every connection between sims must be made in `BattleBuilder.build`, never deferred.
- Injected callables must be method Callables on objects `Battle` holds in typed fields; a lambda or `bind()` that captures a sim object is forbidden.
- No sim may hold a reference to `Battle`, AppRoot or any node.
- Every caller must check `halted()` after `fatal`, after each accessor read and after each signal, and return.
- `assert` must never guard a release-relevant check; use the injected `fatal` or `dev_error`.
- The Retry handler must only set the latch. Teardown runs in AppRoot's `_process`, Fatal checked first.
- Nodes must be freed with `queue_free` after `remove_child`; `free()` must never be called on a sim object.
- A call through a stored Callable that may be unset must be guarded with `is_valid()`.

## Alternatives Considered

### Alternative 1: Autoload app manager
- **Description**: An autoload holds the catalogue and builds battles.
- **Pros**: Reachable from anywhere.
- **Cons**: A global the sims can reach, which breaks headless tests and injection.
- **Estimated Effort**: Lower at first.
- **Rejection Reason**: TR-data-011 and TR-state-001 forbid it.

### Alternative 2: Rebuild with `SceneTree.reload_current_scene`
- **Description**: Retry reloads the main scene.
- **Pros**: One call.
- **Cons**: Drops the catalogue, which must survive a retry; reload would mean a second load.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Breaks TR-data-004 (no reload) and TR-state-001.

### Alternative 3: Scene-owned battle (a node per system)
- **Description**: Each sim is a node under a battle scene.
- **Pros**: Editor inspection.
- **Cons**: Cannot run without a tree; a freed node cannot honour `removed`.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Breaks the headless build (TR-state-002).

### Alternative 4: `assert` for contract checks
- **Description**: Guard bad calls with `assert`.
- **Pros**: Debugger break in the editor.
- **Cons**: Does not run in a release export (@GDScript.xml, `assert`).
- **Estimated Effort**: Lower.
- **Rejection Reason**: Release builds would carry on with bad state (TR-data-009).

## Consequences

### Positive
- The battle is a plain object: bots, tests and the phone build run the same code.
- One fatal route, idempotent, with the first cause kept.
- Retry cannot leak state: everything is rebuilt.

### Negative
- AppRoot and the Builder depend on every layer by design.
- Every sim must check `halted()` by hand; GDScript has no exceptions.
- The Builder's one wiring function will grow long.

### Neutral
- Lifecycle notifications live in ADR-0003, not here.

## Risks

- **A retired battle stays alive through a cycle.** Mitigation: the weakref test in CI; the method-Callable-only rule.
- **A Callable target dies early** because nothing strong holds it. Mitigation: every target is a typed field on `Battle`; guarded `is_valid()` on optional Callables.
- **The old wrapper processes once more after Retry.** Mitigation: `set_process(false)` and `remove_child` before `queue_free`; the desktop headless run confirms.
- **A fatal during a signal emit leaves later listeners running.** Mitigation: Flow stops emitting once the latch is set (Flow Rule 15); every listener checks `halted()`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-004: load once, all or nothing, started by the app root, no reload | Decision 2 |
| data-config-pipeline.md | TR-data-006: no fallbacks; catalogue-free fatal screen that never opens saves; dev runs name each error | Decisions 2 and 7; preloaded fatal scene |
| data-config-pipeline.md | TR-data-009: bad accessor call goes to an injected, test-replaceable handler that survives release | Decisions 7 and 8 |
| data-config-pipeline.md | TR-data-011: no autoload; app root holds the catalogue; builder injects it | Decisions 1 and 3 |
| input-gesture-resolver.md | TR-input-012: wrapper builds resolver and adapter per battle and injects the resolver; hit radii are constants | Decision 6 |
| game-state-stage-flow.md | TR-state-001: minimal main-scene app root, no autoload, owns load, catalogue and fatal screen, survives retry | Decisions 1 and 2 |
| game-state-stage-flow.md | TR-state-002: scene-free builder, explicit connections, headless, null on failure; thin wrapper | Decisions 3 and 6 |
| game-state-stage-flow.md | TR-state-009: retry rebuilds between ticks from an app-root latch; weakref null | Decision 9; Validation Criteria |
| game-state-stage-flow.md | TR-state-011: one idempotent fatal handler, first cause, overrides outcomes, halts, discards partial build, wrapper checks after each step | Decisions 3, 6 and 7 |
| enemy-wave.md | TR-enemy-005: injected `halted()` checked after every read and signal; never references Flow | Decisions 5 and 7 |
| enemy-wave.md | TR-enemy-012: `start_next_wave()` misuse logs to an injected dev-error sink, not assert | Decision 8 |
| tower-system.md | TR-tower-006: `halted()` checked after every read and signal; reads before mutation | Decision 5; Implementation Guidelines |
| tower-system.md | TR-tower-013: no old battle alive through a signal connection; wiring test names missing connections | Decisions 4, 5 and 9; weakref test (listener-count test is ADR-0006 and ADR-0007) |
| hero-system.md | TR-hero-004: `halted()`, `in_build()`, hand flag, Hero ID and `burst_id` injected into HeroSim, HeroInput and the HUD | Decisions 5 and 6 (Builder into HeroSim; wrapper into HeroInput and HudLogic) |
| battle-hud.md | TR-hud-006: Retry sets an idempotent latch and never frees its caller; next frame checks Fatal, stops, cancels, frees, rebuilds | Decision 9 |

## Performance Implications
- **CPU**: Negligible. Method calls replace node callbacks.
- **Memory**: One battle at a time; the old one is released before the new one is built.
- **Load Time**: Catalogue loads once per session; Retry costs one build.
- **Network**: None.

## Migration Plan

No code exists. New code follows this ADR from the first story.

**Rollback plan**: Supersede this ADR before moving any sim into a node or adding an autoload; the headless build and the weakref test would fail first.

## Validation Criteria

- Unit (headless): `BattleBuilder.build` with a fixture catalogue returns a `Battle` and creates no node.
- Unit: a bad stage input calls the handler once and `build` returns null; a second fatal keeps the first cause.
- Unit: a fatal during a tick sets Flow to FATAL, emits `phase_changed(FATAL)` once and later tick steps do nothing.
- Unit: after Retry, a `weakref` to the old `Battle` reads null once the test drops its own reference.
- Unit: Fatal and Retry set in the same frame show the fatal scene and build nothing.
- Unit: `Battle.cancel_input()` with nothing set does nothing and raises no error.
- Desktop headless run and phone session: the NOT SOURCEABLE items above.

## Related

- ADR-0002 (catalogue format), ADR-0003 (adapter, lifecycle), ADR-0004 (Clock, tick), ADR-0006 (signal contracts, listener-count test), ADR-0007 (test harness)
- `docs/architecture/architecture.md` v3: Module Ownership (Foundation, Composition Root); Data Flow 4, 5 and 7; API Boundaries B0, B4 and B9; QQ-08, QQ-17, QQ-19, QQ-20
- `design/gdd/game-state-stage-flow.md`, `design/gdd/data-config-pipeline.md`, `design/gdd/battle-hud.md`, `design/gdd/input-gesture-resolver.md`, `design/gdd/enemy-wave.md`, `design/gdd/tower-system.md`, `design/gdd/hero-system.md`
