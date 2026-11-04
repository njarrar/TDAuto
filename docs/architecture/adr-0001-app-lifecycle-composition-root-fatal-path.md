# ADR-0001: App Lifecycle, Composition Root and Fatal Path

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.
> Do not accept this ADR until verification items V1 to V5 (Engine
> Compatibility) have a recorded result in `docs/engine-reference/godot/`.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only. The live Godot 4.7 documentation was not reachable from the authoring session (`docs.godotengine.org` is outside the session's network policy), so every engine behaviour below that the pinned reference does not cover is marked NEEDS VERIFICATION and listed in V1 to V5.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS on the first draft, findings 1 to 11 applied in this revision), godot-specialist (engine check: no blocking issues, minor notes applied). Authored with the `/architecture-decision` flow.

## Summary

The game needs one place that owns the app's lifetime, the loaded catalogue and the single failure path, with no autoloads, so that every battle system runs headless and a retry leaves no old state behind. This ADR decides a minimal main-scene `AppRoot` (states Boot, InStage, Fatal), a scene-free `BattleBuilder` that creates and wires one `Battle` from `(catalogue, stage_id, rng_seed, fatal_handler)`, injection by `obj.method` Callables only (no lambdas, no `bind()`, no string names), a pure idempotent `FatalLatch` on the battle and on the root, release-safe checks that use `push_error` and never `assert`, and a retry that detaches and drops the old battle and builds a new one.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (post-cutoff version; app lifecycle is unreferenced in the pinned docs) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`. No `modules/` file covers Core, scripting or scene lifetime (modules present: animation, audio, input, navigation, networking, physics, rendering, ui). |
| **Post-Cutoff APIs Used** | None by name. Two 4.7 changes bear on the decision: an override of a typed-return method inherits the return type and needs an explicit `return` (4.7); lambdas capture locals by value (all Godot 4). `@abstract` (4.5) is optional and not required here. |
| **Verification Required** | V1 to V5 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: the reference-count behaviour of a method `Callable`; whether a lambda binds `self` strongly; `queue_free()` and `remove_child()` timing; whether `push_error` output survives a release export; `ResourceLoader.load()` and `PackedScene.instantiate()` failure behaviour. The engine check (godot-specialist) agrees with the expected results from pre-4.4 knowledge only; that is not a source. |

Verification items (the gap is wired to acceptance: this ADR stays `Proposed` until each has a recorded result):

- **V1. Callable reference semantics.** Does `obj.method` on a `RefCounted` object keep the object alive, or hold only its object ID? Does a signal connection keep its target alive? Does a lambda or `bind()` that captures a `RefCounted` hold a strong reference, and does a lambda written inside a method bind `self` strongly even when it captures no locals? Expected (unsourced): method Callables and connections hold an ID only; lambdas and `bind()` hold strong references. The Builder's own wiring relies on the first answer, because `halted`, `in_build` and `cancel_input` point back at `Battle` and `FatalRelay` and Flow point at each other. Method: a headless test that builds objects wired this way, drops every other reference and reads `weakref(...).get_ref()`. Owner: the ADR-0007 test harness story; first run before any sim story starts. This closes QQ-17.
- **V2. Teardown timing.** After `wrapper.detach()`, `remove_child(wrapper)` and `wrapper.queue_free()`, do `_process`, `_input` and `_unhandled_input` stop firing on the wrapper and its children at once, and are the old battle, each sim and the resolver released (weakrefs null) one frame later? Method: integration test over two frames, plus one manual run on the editor with a Control under the pointer.
- **V3. Load and instantiate failure.** What do `ResourceLoader.load()` and `PackedScene.instantiate()` return, and what is logged, for a missing scene path, a scene with a broken script and a scene with a missing sub-resource, in the editor and in an Android export? Method: deliberately broken scenes in a throwaway project, run in the editor and from an export.
- **V4. Release error output.** Does `push_error` print or log in a release export, and does `OS.is_debug_build()` read false there? Method: first Android export run reading `adb logcat`.
- **V5. Main scene key.** `application/run/main_scene` is the key that names the main scene, and `project.godot` has no `[autoload]` section. Method: read the file after the first story sets it; fail CI if an `[autoload]` section appears (see Validation Criteria).

Lifecycle notification names (`NOTIFICATION_APPLICATION_PAUSED`, `..._FOCUS_OUT`, `NOTIFICATION_WM_WINDOW_FOCUS_OUT`) and which fire on which platform are NOT decided here. ADR-0003 owns them (spike first).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (catalogue load is called by AppRoot), ADR-0003 (adapter lifecycle signal wires through the Builder), ADR-0004 (the clock lives in the wrapper), ADR-0005, ADR-0006 (wiring rule), ADR-0007 (headless harness uses `BattleBuilder`), ADR-0009, ADR-0010 |
| **Blocks** | Every epic that builds a battle system (Data & Config, Game State & Stage Flow, Input, Combat, Enemy & Wave, Tower, Hero, Battle HUD): none may start until this ADR is Accepted |
| **Ordering Note** | Write and accept first. ADR-0002 to ADR-0010 cite the injected-callable list (B9 in `architecture.md`), the no-lambda rule and the session-lifetime rule from here. ADR-0005 must define how the accessor receives the per-battle `fatal` (Decision 5, session-lifetime rule). Accepting this ADR closes only the composition-root item of QQ-08 (scene-free builder); its other three items wait on ADR-0004 and ADR-0009. V1 closes QQ-17. |

## Context

### Problem Statement

The GDDs for Data & Config, Game State, Enemy & Wave, Tower and Hero all assume the same shape and defer it to one ADR: a root that exists before the catalogue loads, a builder that wires one battle with explicit connections, injected failure and halt checks, and a retry that rebuilds. Without a decision, each system's first story picks its own wiring, and the first autoload or capturing lambda breaks both the headless test path and the weakref proof that a retry leaks nothing. The prototype's hand-listed reset of 22 fields is the failure this prevents.

### Current State

No code exists (`src/` holds only a CLAUDE.md; `project.godot` sets no main scene and no autoload). `docs/architecture/architecture.md` v2 gives working defaults for the root, the builder, the init order, the retry path and the fatal path. They are marked ADR-pending. This ADR ratifies or changes each.

### Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Everything runs on the main thread (TR-state-003).
- No autoloads or globals (TR-data-011, TR-state-001). Dependency injection over singletons is a project coding standard.
- GDScript has no exceptions. After a failure the calling function still finishes, so every caller must check a flag (TR-state-011).
- `assert` is stripped from export builds, so it cannot guard release behaviour.
- GDScript has no cycle collector for `RefCounted`. A reference cycle leaks the battle, and the weakref proof then fails.
- Solo, part-time developer. One extra framework (a container, an event bus) costs more than it saves.
- 4.7 typed-return rule: any base-class method with a typed return that a subclass overrides needs an explicit `return` in the override.

### Requirements

- The root exists before the catalogue loads, so a load failure has a screen to show (TR-state-001, TR-data-006).
- The battle builds without a scene, so tests and bots call it directly (TR-state-002).
- Every battle system reads halt, hand, targets and errors through injected callables (TR-enemy-005, TR-tower-006, TR-hero-004, TR-data-009).
- One fatal path, idempotent, first cause kept, partial build discarded, fatal screen guaranteed to load (TR-state-011).
- A retry drops the whole battle, and a weakref to the old battle reads null (TR-state-009, TR-tower-013, TR-hud-006).
- The catalogue survives a retry and is never reloaded (TR-data-004).

## Decision

### 1. No autoloads, one main scene

`project.godot` sets `application/run/main_scene="res://src/root/app_root.tscn"` and has no `[autoload]` section. A test in CI fails if an `[autoload]` section exists. Singletons are replaced by injection: whatever a system needs is a constructor argument or an injected `Callable`.

### 2. AppRoot

`AppRoot` is a `Node` scene (`src/root/app_root.tscn`, script `app_root.gd`). It holds no gameplay logic and makes no gameplay decision. It owns:

- `_catalogue: Catalogue` (the Ready catalogue for the whole session; never reloaded; survives retry),
- `_app_latch: FatalLatch`,
- `_state: AppState` (`BOOT`, `IN_STAGE`, `FATAL`),
- `_battle: Battle` and `_wrapper: BattleWrapper` (null outside `IN_STAGE`),
- `_retry_requested: bool` (the retry latch),
- `_rng_seed: int`.

`AppRoot` preloads no scene. The fatal screen and the wrapper scene are loaded at run time with `ResourceLoader.load()` and checked for null, so a missing or broken scene file cannot stop `app_root.gd` itself from loading (a failed `preload` would fail the script that holds the fallback). This also avoids `preload` cycles between `AppRoot`, `Battle` and `BattleBuilder`.

States and transitions follow the Game State GDD: `BOOT` goes to `IN_STAGE` when the catalogue is Ready, and to `FATAL` on failure; `IN_STAGE` goes to `FATAL` through the fatal path; a retry stays in `IN_STAGE` with a new battle; `FATAL` is absorbing (no transition leaves it; relaunch is the only exit at MVP).

Boot order (`_ready`):

1. Create `_app_latch`. State is `BOOT`.
2. `Catalogue.load_manifest(manifest_path)` (ADR-0002; static, returns a `LoadResult`). On `ok == false`, call `_fatal("catalogue load failed: ...")`. Nothing else runs (no fallbacks, no save access). During `BOOT` the catalogue reports failure through its `LoadResult`, never through a stored callable.
3. (Vertical Slice) inject saved progression. Reserved; not built at MVP.
4. Pick `stage_id` (the first stage the catalogue lists at MVP) and `_rng_seed`. The seed is chosen once per app session and reused on retry, so a retry with the same commands replays the same sim. This policy is a working default; ADR-0004 owns the seeded and cosmetic RNG split and may refine it. State becomes `IN_STAGE`.
5. Build the first battle (section 5).

`AppRoot` accepts an optional `configure(options: Dictionary)` call before `add_child`, with `manifest`, `stage_id`, `rng_seed`, `wrapper_scene_path` and `fatal_scene_path` keys, so an integration test can boot it with a fixture catalogue. Unset keys take production defaults.

### 3. FatalLatch and the fatal path

`FatalLatch` (`src/foundation/fatal_latch.gd`, `extends RefCounted`) is pure: no scene, no catalogue, no engine call except `push_error`.

```gdscript
class_name FatalLatch extends RefCounted

## Records the first fatal cause. Later calls change nothing.
func fatal(cause: String) -> void
## True once fatal() has been called.
func is_fatal() -> bool
## The first cause, or "" if not fatal.
func cause() -> String
```

There are two latches. The app latch lives on `AppRoot`. The battle latch is created by the Builder first, before any system exists, so a fatal during build has somewhere to land.

The injected `fatal(cause: String) -> void` is the `fatal` method of a `FatalRelay` (`src/root/fatal_relay.gd`, `extends RefCounted`, one per battle, owned by `Battle`). Its steps, in this order:

1. If the battle latch is already fatal, return. (Idempotent; first cause kept. This also stops re-entry from a listener of `phase_changed(FATAL)`.)
2. Set the battle latch, call `push_error` with the cause.
3. Call the app handler the Builder received as `fatal_handler` (`AppRoot.on_fatal`, which sets the app latch), after `is_valid()`.
4. If a Flow hook is set (`flow.enter_fatal`, a method Callable set by the Builder right after Flow is built), call it after `is_valid()`. Flow commits FATAL, then emits `phase_changed(FATAL)`.

Commit, then emit: latches are set before any listener runs.

`Battle.halted()` is true when Flow is WON, LOST or FATAL, or the battle latch is set. It is false while PAUSED. Every system that makes a read or emits a signal checks the injected `halted()` after the call and returns at once if true.

A fatal that `AppRoot` itself raises while `IN_STAGE` with a live battle (for example the wrapper fails to load, instantiate or attach) goes through `battle.report_fatal(cause)`, which calls the relay, so both latches are set and Flow enters FATAL. `AppRoot` sets only the app latch directly (`_fatal`) in `BOOT`, or when `build` returned null.

`AppRoot` never frees the battle from inside the fatal call stack. `on_fatal` only sets the app latch. `AppRoot._process` reads the latch next frame, and if set: stops the wrapper's processing, detaches and frees the wrapper, drops the battle, instantiates the fatal screen, and sets state `FATAL`. During `BOOT` no battle exists, so `_fatal` may show the screen in the same call.

The fatal screen (`src/root/fatal_screen.tscn`) uses only default-theme `Control`s and no imported asset (no font, texture or theme resource), takes no catalogue data and has no buttons. It shows a generic message; development builds (`OS.is_debug_build()`) also show the first cause. `AppRoot` loads it with `ResourceLoader.load(fatal_scene_path)`. If the path is missing, the load returns null, the resource is not a `PackedScene`, or `instantiate()` returns null, `AppRoot` builds a single `Label` in code as the last resort. The fallback lives in `app_root.gd`, which depends on no scene file, so the fatal path cannot itself fail to display unless `app_root.gd` fails to parse, which CI catches (Validation 9). The app never opens saves in `FATAL`.

Causes that take this path: catalogue load failure, bad accessor call, wrapper scene that fails to instantiate or attach, bad stage input, and any release-relevant check that fails.

### 4. Release-safe checks and the dev-error sink

- `assert` is forbidden for any check whose failure matters in a release build. Such a check calls the injected `fatal`, or `dev_error` for a non-fatal contract breach, and then returns.
- `dev_error(msg: String) -> void` is the injected development-error sink. The default (`DevErrorSink.report`) always calls `push_error` and also records the message in an in-memory list. Tests inject a recording fake. It never changes game state.
- `print_debug` is stripped from release builds and must not carry any error report.
- Every function that can call `fatal` returns a value the caller cannot confuse with success where the type allows it (null, an enum failure code, `false`), and every caller checks `halted()` before it uses its own results or mutates state (TR-state-011, TR-enemy-005, TR-tower-006).

### 5. BattleBuilder

`BattleBuilder` (`src/root/battle_builder.gd`) has one static entry point, no state, and is never instantiated:

```gdscript
## Builds one battle from its four inputs. Needs no scene. Returns the Battle,
## or null if a fatal fired during the build (the partial battle is discarded).
static func build(catalogue: Catalogue, stage_id: StringName, rng_seed: int, fatal_handler: Callable) -> Battle
```

The parameter is `rng_seed`, not `seed`, because `seed` is a global GDScript function and the name would shadow it (a warning; unsourced in the pinned reference, so the rename is a precaution).

Steps, in order (matches Data Flow 4, step 5, in `architecture.md`):

1. Create the battle `FatalLatch` and the `FatalRelay`. Hand the relay's `fatal` to every later step.
2. Validate stage inputs. Create the `InputResolver` from the Input record's slops (`create` returns null on bad slops: call `fatal`, return null). The resolver reads the slops from the Input record directly, not through the accessor (TR-input-012).
3. Construct Flow, Combat, EnemyWave, TowerSim, HeroSim.
4. Make every signal connection and inject every callable in this one function, on statically typed locals, in the form `emitter.signal_name.connect(listener.method)` and `obj.method`. A misspelt signal or method is then a parse error, not a silent no-op. The signal wiring list is in ADR-0006 and Data Flow 3.
5. Return the `Battle`. If the battle latch is set at any point, return null and let the caller discard everything. `Battle` holds strong references to every sim object, the resolver and the relay. Nothing else holds the sims.

Rules for the Builder and for everything it builds:

- **Wiring only.** A branch on a gameplay value inside the Builder or the wrapper is a defect.
- **`obj.method` only.** Every injected or connected callable is `obj.method` on an object the Builder owns. The string forms `Callable(obj, "method")` and `connect("signal", ...)` are forbidden in `src/`, because the parser cannot check them. ADR-0007's lint rejects them.
- **No lambdas, no `bind()`.** No lambda and no `bind()` for any injected or connected callable in `src/`, whether or not it captures locals. A lambda may bind `self` implicitly, and a captured `RefCounted` is a strong reference, so either can make a cycle. One flat rule is simpler to follow and to lint. (V1 checks the reference rules.)
- **No reference fields back to `Battle`.** No sim stores `Battle` in a field. Systems reach each other only through injected callables and signals. Callables that point back at `Battle` (`halted`, `in_build`, `cancel_input`) and the mutual `FatalRelay` and Flow callables are allowed only because method Callables are expected to hold an object ID, not a reference. If V1 shows otherwise, the Rollback plan applies before any sim story starts.
- **Session lifetime.** An object that lives for the session (`AppRoot`, `Catalogue`, the stat accessor, any record) must never hold a per-battle callable or connect to a per-battle signal. The stat accessor reaches the per-battle `fatal` through a per-battle read context the Builder creates, or per call; ADR-0005 picks which. No sim connects to a catalogue signal. Otherwise a retry either leaks the old battle or sends a later fatal to a dead relay.
- **No mutable `static var`** in any class under `src/`. Static state lives per script, survives a retry and defeats the rebuild.
- **No deferred connections** on gameplay signals (TR-enemy-004, ADR-0006).
- **Headless-safe.** The Builder touches no `Node`, `SceneTree` or `DisplayServer`.
- `cancel_input() -> void` is a method on `Battle`. It calls a held `Callable` that defaults to a no-op and that the wrapper sets to the resolver's `cancel` after build. Flow gets `battle.cancel_input`. Headless, it stays a no-op.

The injected callable list is the one in `architecture.md` B9 (`halted`, `in_build`, `targets`, `cancel_input`, `left_handed`, `fatal`, `dev_error`, `to_ticks`). This ADR owns the injection mechanism; the signatures stay where B9 and the system GDDs define them.

### 6. BattleWrapper and attach

`BattleWrapper` is a scene that `AppRoot` loads at run time (`ResourceLoader.load(wrapper_scene_path)`) and instantiates. It adds the `InputAdapter`, the Clock, the HUD and the field views around the `Battle`, and holds no gameplay logic. `AppRoot` calls `wrapper.attach(battle, reduce_motion) -> bool` after `add_child`. A failed load, a null instance or a `false` return is fatal, sent through `battle.report_fatal`. The wrapper exposes `detach() -> void`, which stops processing (`set_process(false)` and the input flags), calls `resolver.cancel()`, calls `detach()` on every child node that holds a sim or resolver reference (adapter, HUD, views; each such node must implement it), disconnects its own connections and sets its references to the `Battle` and the resolver to null. After `detach()` no node in the wrapper subtree holds a sim, the resolver or the Battle. The wrapper is absent in headless runs. The Clock, tick rate, clamp and frame order are ADR-0004's; pause entry through the adapter's lifecycle signal is ADR-0003's and Flow's.

### 7. Retry and teardown

`Retry` (a HUD button inside the wrapper) calls `AppRoot.request_retry()`, which only sets `_retry_requested = true`. It never frees its caller and is idempotent. On `AppRoot`'s next `_process`:

1. If `_app_latch.is_fatal()`: show the fatal screen and stop (fatal wins over retry).
2. If `_retry_requested`: clear it. If `battle.is_over()` is false (phase not WON or LOST), ignore it (Game State edge case).
3. Stop the Clock. `resolver.cancel()`.
4. `wrapper.detach()`, `remove_child(wrapper)`, `wrapper.queue_free()`. Never `free()`: the request began inside the wrapper's own signal chain, and `queue_free()` defers deletion to a safe point.
5. `_battle = null`, `_wrapper = null`. Because `detach()` cleared every reference in the wrapper subtree, these were the last strong references, so the old `Battle`, its sims and the resolver are released at once, without waiting for the wrapper nodes to be deleted. Weakrefs to the old `Battle`, each sim and the resolver must read null (TR-state-009, TR-tower-013). A non-null weakref means a cycle or a missed `detach()` and is a defect.
6. `BattleBuilder.build(_catalogue, stage_id, _rng_seed, on_fatal)` again with the same catalogue, then a new wrapper.

Retry resets nothing in place. A retried battle opens in Build. A finger held across the retry is handled by the new adapter, which never saw the press (Game State edge case).

### 8. Reduce Motion and left-handed location (QQ-09)

`reduce_motion` and `left_handed` are fields of the Input record in the catalogue, as the Battle HUD GDD already states. `AppRoot` reads `reduce_motion` once per battle and passes it to `wrapper.attach`. The Battle never receives it (presentation only). When Settings exists (Alpha), `AppRoot`'s source for the value changes, and nothing else does. `left_handed` stays on the Battle path through the Builder, as B9 lists. The record accessor for these two fields belongs to ADR-0002 and ADR-0005.

### Architecture Diagram

```
 Engine ─► main scene ─► AppRoot (Node; no autoload)
                           │ owns: _catalogue, _app_latch, _state, _retry_requested, _rng_seed
                           │
      _ready: load ───────►│ Catalogue.load_manifest(path) ── !ok ──► fatal screen (absorbing)
                           │
                           │ BattleBuilder.build(catalogue, stage_id, rng_seed, on_fatal)
                           ▼
        Battle (RefCounted, scene-free)                   FatalRelay ──► battle FatalLatch
        ├ Flow, Combat, EnemyWave, TowerSim, HeroSim            │
        ├ InputResolver                                         ├──► AppRoot.on_fatal ──► app FatalLatch
        └ FatalRelay, cancel_input Callable                     └──► Flow.enter_fatal ──► phase_changed(FATAL)
                           ▲
                           │ attach(battle, reduce_motion) / detach()
        BattleWrapper (scene): InputAdapter, Clock, HUD, field views

 Retry:  Retry button ─► AppRoot.request_retry() sets latch
         next frame: fatal first; is_over()? stop clock, cancel, detach (whole subtree),
                     remove_child, queue_free, drop refs, weakrefs(old battle, sims,
                     resolver) == null, build again with the SAME catalogue
```

### Key Interfaces

```gdscript
# src/foundation/fatal_latch.gd
class_name FatalLatch extends RefCounted
func fatal(cause: String) -> void
func is_fatal() -> bool
func cause() -> String

# src/root/battle_builder.gd
class_name BattleBuilder extends RefCounted   # static only; never instantiated
static func build(catalogue: Catalogue, stage_id: StringName, rng_seed: int, fatal_handler: Callable) -> Battle

# src/root/battle.gd (plain object, no node)
class_name Battle extends RefCounted
func tick(dt: float) -> void            # gated inside; ADR-0004 owns the gate and order
func halted() -> bool
func in_build() -> bool
func is_over() -> bool                  # true when Flow is WON or LOST
func report_fatal(cause: String) -> void  # calls the relay; for AppRoot's own InStage failures
func cancel_input() -> void             # calls the wrapper-set Callable; no-op headless
func set_input_canceller(c: Callable) -> void

# src/root/app_root.gd
class_name AppRoot extends Node
func configure(options: Dictionary) -> void   # tests only; before add_child
func request_retry() -> void                  # sets the latch; frees nothing
func on_fatal(cause: String) -> void          # the fatal_handler; sets the app latch only

# src/root/battle_wrapper.gd
class_name BattleWrapper extends Node
func attach(battle: Battle, reduce_motion: bool) -> bool
func detach() -> void
```

Names are the contract, signatures are the contract; internal fields may change. `Battle` fields other than these are ADR-0004, ADR-0006 and ADR-0010's to define. `class_name` collision risk (QQ-16) is handled by ADR-0007; until then these names are provisional.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must set `application/run/main_scene` and must never add an `[autoload]` section.
- Must create every sim object only in `BattleBuilder.build`, and must make every sim-to-sim signal connection only there.
- Must inject every cross-system dependency as an `obj.method` Callable or a constructor argument.
- Must never use the string forms `Callable(obj, "name")` or `connect("signal", ...)` in `src/`.
- Must never use a lambda or `bind()` for an injected or connected callable in `src/`.
- Must never store `Battle` in a field of a sim object. Must never create a `RefCounted` cycle.
- Must never let a session-lived object (AppRoot, Catalogue, accessor, records) hold a per-battle callable or connect to a per-battle signal; no sim connects to a catalogue signal.
- Must never declare a mutable `static var` under `src/`.
- Must call `is_valid()` before calling a held Callable on the fatal path.
- Must never `preload` a scene in `app_root.gd`; load the fatal and wrapper scenes at run time and null-check.
- Every node in the wrapper subtree that holds a sim, the resolver or the Battle must implement `detach()` and clear those references in it.
- Must check `halted()` after every accessor read and every signal emit that can end the battle, and return at once.
- Must report a release-relevant failure through `fatal` or `dev_error`. Must never use `assert` for it.
- Must never call `fatal` expecting the callee to stop the caller. The caller returns.
- Must never free the wrapper, or drop the battle, from inside a signal handler or a `fatal` call. Only `AppRoot._process` tears down.
- Must never use `free()` on a node that took part in the current input or signal call. Use `queue_free()` after `remove_child()` and `detach()`.
- Must never reload the catalogue after `Ready`.
- The fatal screen must use no imported asset and no catalogue data.
- An override of a method with a typed return must contain an explicit `return` (4.7).
- Tests that prove teardown must hold no reference to the old battle, and must read the weakref in the same frame as the drop.

## Alternatives Considered

### Alternative 1: Autoload singletons (`Game`, `Catalogue`, `EventBus`)

- **Description**: Register the catalogue, an event bus and a game-state object as autoloads. Systems reach them by global name.
- **Pros**: Least code to write. Familiar Godot pattern. Survives scene changes for free.
- **Cons**: Hidden coupling; each system becomes untestable without the whole singleton set. Headless bots would need the autoload tree. A retry must reset the singletons by hand, which is the 22-field leak the GDD names as the failure. Violates the coding standard (dependency injection over singletons).
- **Estimated Effort**: About 0.7x the chosen approach at first; higher after the first retry bug.
- **Rejection Reason**: Breaks TR-data-011, TR-state-001 and the headless requirement.

### Alternative 2: A battle scene script as the root and wiring owner

- **Description**: The stage scene's root script constructs systems, wires them and runs the tick loop. This is the technical director's earlier note.
- **Pros**: One file; the scene tree gives lifetime management.
- **Cons**: A scene-owned root cannot run headless without a display and scene tree, so bots and unit tests would need the full scene. Gameplay logic drifts into a node.
- **Estimated Effort**: About 0.8x.
- **Rejection Reason**: Fails TR-state-002. The GDD already amends the earlier note.

### Alternative 3: Retry by `change_scene_to_packed` (reload the main scene)

- **Description**: Retry swaps the whole scene. The engine frees the old tree.
- **Pros**: Uses the engine's own teardown; no manual detach.
- **Cons**: The catalogue and `AppRoot` die with the scene unless held by an autoload, which Alternative 1 rules out. Reloading the catalogue on retry breaks TR-data-004. Scene swap timing is the same deferred-free question, with less control.
- **Estimated Effort**: About 0.9x.
- **Rejection Reason**: Needs a global to hold the catalogue, or a reload that the GDD forbids.

### Alternative 4: A dependency-injection container or service locator

- **Description**: Systems register and resolve services by key.
- **Pros**: Uniform lookup; late binding.
- **Cons**: Another framework to write and test; resolve-by-name errors appear at run time. The GDD lists a container among the things deliberately not built.
- **Estimated Effort**: 1.5x.
- **Rejection Reason**: Explicit constructor and `obj.method` injection in one builder function already gives parser-checked wiring, with no new layer.

### Alternative 5: In-place reset on retry

- **Description**: Each system gets a `reset()` and retry calls them.
- **Pros**: No rebuild cost; keeps node references.
- **Cons**: Every new field needs a matching reset line; the prototype leaked state between attempts this way.
- **Estimated Effort**: 0.8x, then growing.
- **Rejection Reason**: GDD Rule 16 (rebuild, never reset).

## Consequences

### Positive

- Every battle system runs headless from `BattleBuilder.build`, so unit, integration and bot tests share production wiring.
- One fatal path, one latch type, one place that wires signals. A failure cannot be handled two ways.
- A retry cannot leak state, and the weakref test proves it.
- The catalogue loads once; a retry costs only a rebuild.
- The fatal screen cannot fail to show: no assets, no catalogue, a code-built last resort.

### Negative

- The Builder is one long function that grows with each system. Accepted for the MVP size (five systems); revisit if it passes about 150 lines.
- The no-lambda rule costs a small named method for each callable that would otherwise be a lambda.
- Every view and HUD node that reads a sim must implement `detach()`. A missed one shows up only as a non-null weakref in the retry test.
- Fatal shows on the next frame, not inside the failing call. One frame of stale view is possible; the in-sim gate halts the sim at once, so state is correct.
- A cycle leaks silently in GDScript. Only the weakref test catches it, so that test is mandatory and must stay green.

### Neutral

- `AppRoot` carries a retry latch and a polling `_process` rather than a signal-driven teardown.
- `reduce_motion` lives in data until Settings exists; the source changes later, the call site does not.

## Risks

- **A method Callable keeps an object alive (V1).** Then the Builder's own wiring (callables back to `Battle`, the relay and Flow pointing at each other) forms cycles by construction, and the weakref stays non-null. Mitigation: V1 test before any sim story; if it fails, add an explicit `Battle.dispose()` that disconnects every connection and clears every held Callable, called from teardown, and amend this ADR.
- **`queue_free()` timing differs from the plan (V2).** Mitigation: the battle's release does not depend on node deletion, because `detach()` clears every reference in the wrapper subtree first.
- **A string-form Callable or a lambda slips in.** Mitigation: the ADR-0007 lint rejects `Callable(`, string `connect(`, `func(` used as a value, and `.bind(` under `src/`.
- **A per-battle callable leaks into a session-lived object.** Mitigation: the session-lifetime rule, and the retry weakref test run after a battle that made a bad accessor call.
- **`push_error` is silent in release (V4).** Then release failures show only the generic fatal screen. Mitigation: the fatal path still latches and halts; add a write to the run log in dev builds; check on the first Android export.
- **The fatal scene is missing or broken in an export (V3).** Mitigation: it is loaded at run time, not preloaded, so `app_root.gd` still loads and the code-built Label shows. Boot tests cover a missing path and a null instance. Accepted residual risk: if `app_root.gd` itself fails to parse, nothing can show; CI's headless boot test catches that before export.
- **The Builder grows into a god object.** Mitigation: the "wiring only" rule, a lint (ADR-0007) that rejects `if` on gameplay fields in `src/root/`.
- **Seed policy is a working default.** ADR-0004 may change it; the interface (`rng_seed` as a Builder argument) does not change.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-001: minimal main-scene root, no autoload, triggers load, holds catalogue, owns fatal screen, survives retry | Decision 1, 2, 3 |
| game-state-stage-flow.md | TR-state-002: scene-free `build(catalogue, stage_id, seed, fatal_handler)` with explicit connections; thin wrapper | Decision 5, 6 (parameter renamed `rng_seed`; parser-checked `obj.method` wiring) |
| game-state-stage-flow.md | TR-state-009: retry destroys and rebuilds between ticks, driven by a root latch; weakref to old battle is null | Decision 7 |
| game-state-stage-flow.md | TR-state-011: one idempotent fatal handler, first cause, halts tick, discards partial build, fatal screen loads | Decision 3, 4 |
| data-config-pipeline.md | TR-data-004: load once, all-or-nothing, started by the app root, no reload | Decision 2 (boot order, never reload) |
| data-config-pipeline.md | TR-data-006: no fallbacks; load failure shows a catalogue-free fatal screen; dev names each error | Decision 3 |
| data-config-pipeline.md | TR-data-009: bad accessor call goes to an injected, test-replaceable handler that survives release | Decision 3, 4 (`fatal`, `dev_error`, no `assert`) |
| data-config-pipeline.md | TR-data-011: no autoload; the root holds the catalogue and the builder injects it | Decision 1, 2, 5 |
| input-gesture-resolver.md | TR-input-012: Game State builds the resolver and adapter per battle and injects the one resolver | Decision 5 (resolver in the Builder), 6 (adapter in the wrapper) |
| enemy-wave.md | TR-enemy-005: injected `halted()` checked after every read and signal; no Flow reference | Decision 5 (`halted`), 4 |
| enemy-wave.md | TR-enemy-012: wave control logs to an injected dev-error sink, not `assert` | Decision 4 |
| tower-system.md | TR-tower-006: injected `halted()`; stats read before mutation | Decision 5, 4 (check rule; read-before-mutate is ADR-0005 and ADR-0010) |
| tower-system.md | TR-tower-013: retry leaves no old battle alive through a connection | Decision 5 (no back-refs, method Callables), 7 |
| hero-system.md | TR-hero-004: builder injects `halted()`, `in_build()`, the hand flag, the Hero record ID and `burst_id` | Decision 5 (injection mechanism; the list is B9) |
| battle-hud.md | TR-hud-006: retry sets an idempotent root latch and never frees its caller | Decision 7 |

## Performance Implications

- **CPU**: Boot and each retry run one `build` call: object construction and a fixed set of connections (tens, not thousands). Expected well under one frame. Not measured; confirm at the first device run. No per-frame cost beyond one boolean read of the retry and fatal latches in `AppRoot._process`.
- **Memory**: One `Battle` plus its sims. Retry drops the old one before the new one is used, so no two live battles overlap beyond one frame. The catalogue stays resident for the session.
- **Load Time**: Catalogue load happens once at boot, synchronously at MVP. The 1000 ms median budget on an Adreno 5xx-class device is QQ-11 and is measured under ADR-0002.
- **Network**: None.

## Migration Plan

No code exists, so nothing migrates. First stories, in order: `FatalLatch` and tests; `AppRoot` skeleton with `main_scene` and the CI `[autoload]` check; `BattleBuilder` with an empty `Battle` and the weakref test (this also runs V1 and V2); fatal screen and the headless force-fail test (V3); the first sim wiring arrives with each system's own story.

**Rollback plan**: If V1 shows method Callables keep objects alive, keep the structure and add `Battle.dispose()` as in Risks. If the Builder proves unmanageable, split it into per-system `wire_*` functions called from `build`, with no change to the public signature. Superseding this ADR would require every system ADR to be re-read, so prefer amendment.

## Validation Criteria

Automated, headless (gdUnit4 under `tests/unit/root/` and `tests/integration/root/`):

1. `FatalLatch`: first cause kept on a second call; `is_fatal()` true after one call; idempotent.
2. `BattleBuilder.build` with a fixture catalogue returns a `Battle` with no node, no `SceneTree` and no `await`.
3. Weakref proof, headless: build, hold only weakrefs to the `Battle`, each sim and the resolver, drop the `Battle`, assert every `get_ref() == null` in the same frame. Repeat after a full scripted micro-battle (kill, leak, win) and after a battle that made a bad accessor call.
3a. Weakref proof, with the wrapper: retry through `AppRoot`, then one frame after `queue_free()` assert the same weakrefs and a weakref to the old wrapper are null.
3b. V1 probe: an object connected through `obj.method`, and one held by a lambda written inside a method, report their weakref result; the test records which holds a strong reference.
4. Fatal during build: a bad slop fixture returns null, the app latch is set, no tick runs.
5. Fatal twice: the first cause survives in both latches.
6. Fatal path: after `fatal`, `halted()` is true and a scripted `tick` changes nothing.
7. Listener-count wiring test (ADR-0006) passes on a built battle.
8. CI check: `project.godot` has `application/run/main_scene` and no `[autoload]` section.
9. Boot test with a failing catalogue fixture ends in `FATAL` with the fatal scene shown. With `fatal_scene_path` set to a path that does not exist, and again with a scene whose instance is null, the code-built Label appears. A headless boot of the real `app_root.tscn` runs in CI, so a parse error in `app_root.gd` fails the build.
10. Retry twice in one frame sets one rebuild. Retry while `is_over()` is false is ignored.
11. Wrapper load failure while `IN_STAGE` sets both latches and Flow reads FATAL.
12. Lint (ADR-0007): no `Callable(` string form, no string `connect(`, no lambda or `.bind(` used as a connected or injected callable, no mutable `static var`, under `src/`.

Manual evidence in `production/qa/evidence/` (cannot run headless): V2 teardown with a Control under the pointer; V3 and V4 from the first Android export; fatal screen screenshot (dev and release builds).

The decision is wrong if: the weakref test cannot pass without a `dispose()` in every sim, or the Builder needs a gameplay branch, or a retry shows state from the old battle.

## Related

- Depends on none. Enables ADR-0002 to ADR-0010 (see Dependencies).
- `docs/architecture/architecture.md`: Module Ownership (Composition Root), Data Flow 4 to 7, API Boundaries B9, Principles 1, 2 and 5, QQ-08 (composition-root item), QQ-09 (answered in Decision 8), QQ-16, QQ-17 (closed by V1).
- `design/gdd/game-state-stage-flow.md` Core Rules 1 to 3, 15 to 18, Edge Cases.
- `design/gdd/data-config-pipeline.md`, `enemy-wave.md`, `tower-system.md`, `hero-system.md`, `input-gesture-resolver.md`, `battle-hud.md`.
- `docs/architecture/tr-registry.yaml` (the 15 TR IDs above).
- Not covered here, owned elsewhere: lifecycle notification names (ADR-0003); tick rate, clamp and frame order (ADR-0004); signal list and ID types (ADR-0006); test harness and `class_name` lint (ADR-0007).
