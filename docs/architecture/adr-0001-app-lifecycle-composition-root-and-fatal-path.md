# ADR-0001: App Lifecycle, Composition Root and Fatal Path

## Status
Proposed

## Date
2026-11-04

## Last Verified
2026-11-04

## Decision Makers
njarrar (project owner, autonomous mode with recommended options logged in `production/session-logs/decision-log.md`); godot-specialist (engine validation); technical-director (TD-ADR review).

## Summary
TowerRiot needs one place that builds a battle, holds what must outlive it, tears it down on retry and stops everything on a fatal error, without any autoload or global. This ADR decides that a main-scene `AppRoot` holds the Ready catalogue and an app-level `FatalLatch`, a scene-free static `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)` returns a `Battle` that strongly holds every helper, retry drops the battle and rebuilds it with `remove_child()` plus `free()` on the wrapper, and every failure goes through one idempotent injected `fatal(cause)` that latches, halts and shows a catalogue-free screen.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2 installed, matches the pin) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (VERSION.md: 4.5 to 4.7 are past the model's training; the App lifecycle row of `architecture.md` is HIGH and unreferenced) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `current-best-practices.md` (lambdas capture by value), `deprecated-apis.md` (Callable-based `connect`), `docs/architecture/architecture.md` (Engine Knowledge Gap Summary, Composition Root, Data Flow 4, 5 and 7, B4, B9) |
| **Post-Cutoff APIs Used** | None new. The decision rests on long-standing APIs (`RefCounted`, `Callable`, `Signal.connect`, `Node.free`, `Node.remove_child`, `weakref`, `push_error`, `PackedScene.instantiate`) whose 4.7.2 behaviour was probed, not sourced. NOT SOURCEABLE: Callable and signal lifetime against `RefCounted` targets, and `free()` versus `queue_free()` timing, are not covered by `docs/engine-reference/godot/`. |
| **Verification Required** | (1) Repeat the Callable lifetime probe on an export template (desktop release, then Android): a method Callable and a signal connection must not keep a `RefCounted` target alive, and `.call()` on a dead target must raise a script error (QQ-17). (2) Repeat the teardown probe on export: after `remove_child(wrapper)` and `wrapper.free()` plus dropping the `Battle`, a `weakref` to the old battle reads null in the same frame. (3) A release export with an invalid record shows the fatal screen and leaves saves untouched; a bad accessor call reaches it too (Data criterion 13). (4) A lambda that captures a `RefCounted` keeps it alive (probed on desktop; the ban stands whatever export shows). (5) `push_error` still writes to the log in a release export (NOT SOURCEABLE from the pinned reference). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (Catalogue), ADR-0003 (Input Adapter and Lifecycle), ADR-0004 (Tick and Determinism), ADR-0005 (Stat Accessor), ADR-0006 (Signal Contracts), ADR-0007 (Test Harness and Layer Lint), ADR-0009 (Enemy Entity and Combat API) |
| **Blocks** | Every epic: Game State and Stage Flow (AppRoot, Builder, FatalLatch), Data and Config (load trigger, failure handler), and each sim's constructor (injected `halted()` and `fatal`) cannot start until this ADR is Accepted |
| **Ordering Note** | First ADR in dependency order. Acceptance of this ADR records the technical director's acceptance of the scene-free builder amendment (QQ-08, one of four), on the user's confirmation. Export-template probes (Verification 1 to 3) may run after acceptance, at the first export build, but before the Foundation epic closes. |

## Context

### Problem Statement
The design bans autoloads and globals (Data Rule on no global, Flow Rule 1) so every battle can be built in a test, run headless by a bot and thrown away whole. That leaves four questions nobody else can answer, and every system's constructor depends on the answers:

1. **Who builds a battle, and from what?** Something must load the catalogue once, keep it across retries, and wire Flow, Combat, Enemy and Wave, Tower and Hero together. If that something is a scene, nothing runs headless. If it is an autoload, state leaks between attempts and tests share a singleton.
2. **What keeps the battle alive, and what lets it die?** A 4.7.2 editor probe (Flow review, 2026-11-04) showed that a method `Callable` and a signal connection do not keep a `RefCounted` target alive, and that `.call()` on a dead target raises a script error and aborts the caller. A lambda that captures its target does keep it alive. So holding too little crashes the game, and holding the wrong way leaks the old battle into the retry.
3. **How does retry work?** The prototype reset 22 fields by hand and leaked state. The GDD chose "rebuild, never reset", which needs a teardown call that frees the old battle before the new one starts. The probe showed `queue_free()` leaves the old battle alive to the end of the frame and `remove_child()` plus `free()` does not.
4. **What happens on a fatal error?** GDScript has no exceptions, and `assert` is stripped from release builds. A bad catalogue, a bad stat read, a null resolver or a stage scene that will not load must all stop the game the same way, keep the first cause, and never touch saves.

This must be settled first: every later ADR names `fatal`, `halted()`, the `Battle` fields or the builder.

### Constraints
- No autoload, no singleton, no global state (TR-data-011, TR-state-001).
- The builder must touch no node, so headless bots and gdUnit4 tests call it directly (TR-state-002).
- Gameplay classes are `RefCounted` and never read `Engine`, `Time`, `OS`, a timer or `await` (B4 invariant, ADR-0004 to enforce).
- Error paths must survive release builds: no `assert` for anything that guards play (TR-data-009, TR-enemy-012).
- Solo part-time developer: one pattern, few classes, nothing clever.
- Callable and teardown behaviour are probed on the 4.7.2 desktop editor only; export behaviour is unverified.

### Requirements
- Load the catalogue once, all or nothing, before the first battle, with no reload (TR-data-004).
- On load failure show a catalogue-free fatal screen that never opens saves; development builds name each error (TR-data-006).
- Route bad accessor calls to an injected, test-replaceable handler (TR-data-009).
- Build per battle the resolver and adapter in the wrapper and inject the one resolver into the Hero, Tower and HUD input objects (TR-input-012).
- Retry destroys the whole battle between ticks via a latch on AppRoot; a weakref to the old battle reads null (TR-state-009, TR-hud-006, TR-tower-013).
- One idempotent fatal handler that keeps the first cause, overrides Won, Lost and Paused, halts the tick, discards a partial build, and is guaranteed a screen that loads (TR-state-011).
- Inject `halted()` into every sim, checked after each accessor read and signal; read all stats before any change (TR-enemy-005, TR-tower-006).
- Inject `in_build()`, the hand flag, the Hero record ID and `burst_id` where needed (TR-hero-004).
- A development-error sink, not `assert`, for misuse such as `start_next_wave()` in the wrong state (TR-enemy-012).

## Decision

**A three-part composition root: `AppRoot` (main scene) holds the session; `BattleBuilder` (static, scene-free) makes one `Battle`; `BattleWrapper` (scene) adds the clock, input and views. Every failure goes through one injected `fatal(cause)`. Retry and fatal both tear down with `remove_child()` then `free()` on the wrapper, then drop the `Battle`.**

The reasoning, part by part:

**AppRoot is the main scene, not an autoload.** The main scene already exists before anything else, so a catalogue failure has a screen to land on. An autoload would do the same job but is reachable from every script, which is the leak the design bans. AppRoot holds exactly four things: the Ready `Catalogue`, the app-level `FatalLatch`, the retry latch, and the current wrapper plus `Battle`. It has three states taken from the Game State GDD: `BOOT` (loading), `IN_STAGE` (one battle exists) and `FATAL` (absorbing). Only AppRoot and the catalogue survive a retry.

**The builder is a static function on a `RefCounted` class.** `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler) -> Battle` creates the per-battle `FatalLatch` first, so a failure during the build has somewhere to land; then validates the stage inputs; then constructs Flow, Combat, EnemyWave, TowerSim and HeroSim; then makes every signal connection and injection in one function; then returns. It holds nothing afterwards. A null Stage record or any other unbuildable input calls `fatal_handler` and returns `null`. It touches no node, so a test or bot calls it with no scene tree. Branching on a gameplay value inside the builder or the wrapper is a defect (Flow Rule 3): they wire, they do not decide.

**`Battle` holds every helper in a strong typed field.** Because a method Callable does not keep its target alive, whatever owns the target must. `Battle` keeps a typed field for each sim, the battle `FatalLatch` and the one per-battle `StatAccessor`. No sim holds a reference back to `Battle`. Injected callables are plain method Callables on objects `Battle` holds. Lambdas and `bind()` are banned for injection and connection: a capturing lambda keeps its target alive and can form a cycle that defeats teardown, and `bind()` is unprobed. This one rule makes both failure modes impossible: nothing dies early because `Battle` holds it, and nothing outlives the battle because nothing else holds it.

**The wrapper adds what needs the scene tree.** `BattleWrapper` builds the resolver with `InputResolver.create(drag_slop, tap_slop)` read from the Input record (a null result calls `fatal`), sets `battle.set_input_cancel(resolver.cancel)`, then adds, in order: InputAdapter, Clock, TowerInput, HudLogic, HeroInput, HudTopBand, HudField, HudModals and the field views. It checks `battle.halted()` after each step and stops if set. It loads the stage scene with a null check that calls `fatal`. It holds no gameplay logic. Headless runs have no wrapper.

**One failure path.** `fatal(cause: String)` is a method Callable on the battle's `FatalLatch`. The first call stores the cause and sets the latch; later calls do nothing. Setting it also sets AppRoot's latch (the builder injects AppRoot's `on_fatal` method as the `fatal_handler` the latch forwards to), tells Flow to enter `FATAL`, which overrides Won, Lost and Paused, and makes `Battle.halted()` true so the rest of the current tick is skipped. Because GDScript has no exceptions, each caller checks `halted()` after every accessor read and every signal and returns; all stats are read before any change, so a bad read halts with nothing half done. Catalogue load failure (in `BOOT`, before any battle) calls AppRoot's handler directly. The fatal screen is a separate scene that uses no catalogue data; development builds show the cause by file, record and field, release builds show generic text.

**Errors that are not fatal go to a sink.** A misuse that should be seen in development but must not stop play, such as `start_next_wave()` outside `Waiting`, calls an injected `dev_error(msg)` that wraps `push_error`. It reaches the log only, never the player; that it still logs in a release export is Verification 5. Tests replace it with a recorder. `assert` is never used to guard behaviour; it may appear only in test code.

**Retry rebuilds between frames.** The Retry button sets AppRoot's retry latch and returns; it never frees its caller. At the top of AppRoot's next `_process`, in this order: if fatal, handle fatal and stop; stop the Clock; call `battle.cancel_input()`; `remove_child(wrapper)` then `wrapper.free()`; drop the `Battle` and resolver references; build again with the same catalogue. `queue_free()` is not used for the wrapper because it keeps the old battle alive until the end of the frame, overlapping two battles. The weakref test proves the old battle is gone.

**Fatal teardown uses the same call.** After `fatal`, AppRoot's next frame removes and frees the wrapper with `remove_child()` plus `free()`, drops the `Battle`, sets state `FATAL` and shows the fatal screen. A fatal during `build` returns null and the root discards it unticked.

### Architecture Diagram

```
                ┌────────────────────────── AppRoot (main scene) ──────────────────────────┐
                │ state: BOOT ─► IN_STAGE ─► FATAL (absorbing)                             │
                │ holds: Catalogue (Ready) · app FatalLatch · retry latch · wrapper · Battle│
                │ _process(): if retry or fatal pending, act here, never inside a signal   │
                └──────┬──────────────────────────────┬──────────────────────────┬─────────┘
                       │ build(cat, stage, seed,       │ add_child               │ on FATAL
                       │       on_fatal)               ▼                         ▼
          ┌────────────▼───────────┐   ┌──────────── BattleWrapper (scene) ──┐  Fatal screen
          │ BattleBuilder (static) │   │ resolver = InputResolver.create()   │  (no catalogue)
          │ 1 FatalLatch first     │   │ adapter · Clock · TowerInput ·      │
          │ 2 validate stage       │   │ HudLogic · HeroInput · HUD · views  │
          │ 3 construct sims       │   │ checks battle.halted() after each   │
          │ 4 connect + inject     │   └──────────────┬──────────────────────┘
          │ 5 return Battle / null │                  │ calls tick(dt), reads
          └────────────┬───────────┘                  ▼
                       └───────────────►  Battle (RefCounted)
                                          strong typed fields: flow, combat, enemy_wave,
                                          tower_sim, hero_sim, fatal_latch, stat_accessor
                                          no sim refers back to Battle

  Failure:  any caller ─► fatal(cause) ─► battle FatalLatch (first cause wins)
                                       ─► AppRoot.on_fatal ─► app latch; Flow ─► FATAL
                                       ─► halted() true; callers return
  Retry:    Retry button ─► AppRoot.retry_latch = true
            next frame: fatal? stop ─► Clock.stop ─► battle.cancel_input()
                        ─► remove_child(wrapper); wrapper.free() ─► drop Battle ─► build()
```

### Key Interfaces

```gdscript
class_name AppRoot extends Node
enum AppState { BOOT, IN_STAGE, FATAL }
func request_retry() -> void              # idempotent; sets the latch only
func on_fatal(cause: String) -> void      # idempotent; first cause kept; acts next frame

class_name FatalLatch extends RefCounted
func _init(forward: Callable) -> void     # forward is AppRoot.on_fatal, or a test spy
func fatal(cause: String) -> void         # idempotent; keeps the first cause; calls forward once
func is_set() -> bool
func cause() -> String

class_name Battle extends RefCounted
func tick(dt: float) -> void              # only way sim time advances (gate detail: ADR-0004)
func halted() -> bool                     # Flow WON, LOST or FATAL, or fatal_latch.is_set()
func set_input_cancel(cancel: Callable) -> void   # wrapper only; never set headless
func cancel_input() -> void               # forwards if the Callable is_valid(), else does nothing
# Reads for the wrapper: left_handed, hero_id, burst_id, dt, to_ticks, in_build

class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, seed: int,
		fatal_handler: Callable) -> Battle    # null on failure, after calling fatal_handler
```

Injected values and callables are as listed in `architecture.md` B9: `halted()`, `in_build()`, `targets()`, `cancel_input()`, the Hero record ID, `burst_id`, `wave_index()`, `left_handed`, `fatal(cause)`, `dev_error(msg)`, `to_ticks(seconds)` and `dt`. The `Catalogue`, `StatAccessor` and sim class shapes belong to ADR-0002, ADR-0005 and ADR-0009/0010.

### Implementation Guidelines

- The project must have no autoloads. `project.godot` `[autoload]` stays empty; the layer lint (ADR-0007) fails CI if one appears.
- AppRoot must be the main scene and must not hold gameplay references other than the `Catalogue`, the app `FatalLatch`, the retry latch, the current wrapper and the current `Battle`.
- `BattleBuilder.build` must create the per-battle `FatalLatch` before anything else and must not touch a `Node`, the scene tree, `Engine`, `Time` or `OS`.
- `BattleBuilder` must not keep any reference after `build` returns.
- `Battle` must hold every helper `build` creates in a strong, typed field. No sim may hold a reference to `Battle`.
- Injected callables and signal connections must be plain method Callables (`obj.method`). A lambda or `bind()` must never be used to inject or connect anything in the battle; code review checks this and ADR-0007 adds a lint if feasible.
- Gameplay signals must not use `CONNECT_DEFERRED`.
- Signals run one way across the sim and scene boundary: wrapper nodes connect their own methods to sim signals, and a sim must never hold a Callable or connection that targets a node. Godot drops a connection when its target node is freed, so a sim emit after teardown reaches nothing. The one sim-side Callable into the wrapper's world, `input_cancel`, targets the `RefCounted` resolver, not a node.
- Every sim must call the injected `halted()` after every accessor read and after every signal it emits, and return at once if true. A command must read every stat it needs before it changes any state.
- `fatal(cause)` must be idempotent and keep the first cause. Nothing may persist after it is set.
- Behaviour must never be guarded by `assert`. Fatal conditions call `fatal`; development-only misuse calls the injected `dev_error`, which wraps `push_error` and stays in release builds.
- The Retry button must only call `AppRoot.request_retry()`. Retry and fatal teardown run at the top of AppRoot's `_process`, never inside a signal or a tick.
- Teardown must call `battle.cancel_input()` first, then clear it with `battle.set_input_cancel(Callable())`, then `remove_child(wrapper)` and `wrapper.free()`. `cancel_input()` must test `is_valid()` before calling, so an empty or dead Callable does nothing. `queue_free()` must never be used to tear down the battle wrapper.
- After teardown AppRoot must drop every reference to the old `Battle` and resolver. A test must hold only a `weakref` and assert it reads null.
- The wrapper must check `battle.halted()` after each assembly step and stop if set, and must null-check the stage scene load and the resolver `create` result, calling `fatal` on null.
- The fatal screen scene must not read the catalogue, open saves or depend on any battle object. AppRoot holds it with `preload`, so a missing file fails when the project loads, before any battle.
- `Battle`, the sims and `FatalLatch` must never name the `AppRoot` type; anything from the root arrives as a `Callable`. This keeps `class_name` references one way and avoids cyclic parse errors.
- Call `BattleBuilder.build` through the class name only.
- 4.7: an override of a typed method needs an explicit `return` (typed-return override rule); this applies to every sim base class.
- Retry has no reset function anywhere; no system may expose `reset()`.

## Alternatives Considered

### Alternative 1: Autoload singletons (GameManager, Catalogue, ErrorHandler)
- **Description**: Register the catalogue, the fatal handler and a battle manager as autoloads; systems reach them by name.
- **Pros**: The usual Godot pattern, familiar from tutorials; no injection boilerplate; the catalogue survives retries for free.
- **Cons**: Every script can reach every singleton, so hidden dependencies grow unchecked. Tests share one global instance and must reset it, which is the hand-written reset the design bans. A headless bot cannot run two battles side by side. `--check-only` misreports scripts that name an autoload (`current-best-practices.md`). Failures in an autoload's `_ready` run before any screen exists.
- **Rejection Reason**: Breaks TR-data-011 and TR-state-001 directly and makes the weakref teardown proof meaningless, since the singleton keeps state alive between attempts.

### Alternative 2: Scene-owned battle root (the battle scene's script wires the systems)
- **Description**: The battle scene's root node builds the systems in `_ready`, owns them as children or fields, and is freed on retry. This was the technical director's original note.
- **Pros**: One scene per battle is easy to see in the editor; retry is `change_scene_to_packed`; no separate builder class.
- **Cons**: Nothing runs without a scene tree, so bots and unit tests need the full scene, input and views. Wiring hides in `_ready` order across nodes. Scene change timing (deferred) brings back the two-battles-alive overlap. The catalogue would need an autoload to survive the change.
- **Rejection Reason**: Cannot run headless (TR-state-002), and forces Alternative 1 for the catalogue. The GDD amended the note (QQ-08); this ADR records it.

### Alternative 3: Builder plus reset in place
- **Description**: Build once; on retry call `reset()` on each system instead of rebuilding.
- **Pros**: No teardown timing question; no reference lifetime question; fewer allocations.
- **Cons**: Each system must list every field to reset, and a missed one leaks state between attempts. The prototype had 22 hand-reset fields and leaked anyway.
- **Rejection Reason**: Flow Rule 16 bans it ("rebuild, never reset"), and a rebuild is cheap at MVP size.

### Alternative 4: `queue_free()` for teardown
- **Description**: Use the idiomatic deferred free on the wrapper, then build the new battle.
- **Pros**: Safe against freeing a node still on the call stack; the common Godot idiom.
- **Cons**: The probe showed the old battle stays alive until the end of the frame, so two battles and two resolvers coexist for one frame, and the weakref proof can only run a frame later.
- **Rejection Reason**: Teardown already runs at the top of AppRoot's frame, never from a signal, so the stack-safety benefit does not apply, and the overlap is a real risk.

## Consequences

### Positive
- Every battle can be built and run in a unit test or bot with one function call and no scene.
- Retry cannot leak state: there is nothing to reset, and the weakref test proves the old battle is gone.
- One failure path, one screen, one first cause. Release builds keep every check because nothing relies on `assert`.
- Ownership is visible in one place: if a helper is not a field on `Battle`, it does not exist after `build` returns, and the bug shows up at once as a script error rather than a slow leak.
- Systems never reference each other, Flow, AppRoot or the resolver directly; they meet only through injected method Callables and signals the builder connects.

### Negative
- Injection boilerplate: each sim's constructor takes several Callables and values, and the builder grows long. Accepted: it is one function and the parser checks every name.
- Developers must check `halted()` after each read and signal by hand. Missing one lets a sim run a few lines on a garbage value; tests per sim catch the common cases, not all.
- Banning lambdas and `bind()` in wiring removes a convenient GDScript tool and must be enforced by review until ADR-0007 adds a lint.
- `free()` on the wrapper is unforgiving: if anything later in the same frame touches a freed node, it errors. Teardown must stay at the top of the frame.
- The rule rests on a desktop-editor probe; an export template could behave differently (see Risks).

## Risks

- **Callable lifetime differs on export (QQ-17).** If a method Callable did keep its target alive on export, the weakref test would still catch any cycle; if `.call()` on a dead target did not error on export, a missing field would fail silently instead of loudly. Mitigation: Verification 1 at the first export build; the strong-field rule is safe either way.
- **Teardown timing differs on export.** Mitigation: Verification 2 runs the weakref test in an export build; the fallback is to skip the retry build until the next frame.
- **A node in the wrapper holds a `Battle` reference after `free()`.** A freed node drops its script's references, so this cannot keep the battle alive, but a signal from the battle to a freed node would error. Mitigation: `cancel_input()` and Clock stop come first, and teardown runs between ticks, so no signal fires during it.
- **A missed `halted()` check.** Mitigation: per-sim tests that inject a latch set mid-command and assert no later change; listener-count wiring test (TR-tower-013).
- **The fatal screen itself fails to load.** Mitigation: it is a small scene with no script dependencies on game data, held by AppRoot with `preload`, so a missing or broken file fails when the project loads, in every build, never mid-game.
- **Freeing a node during its own callback.** Retry and fatal are latched and act at the top of `_process`, never from the button's handler, so the button is never freed under its own call.
- **Lambda keeps a target alive.** Probed on desktop; the ban stands whatever the export result.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-004: load once, all or nothing, started by the app root before the first gameplay scene, no reload | AppRoot starts the load in `BOOT`; only a Ready catalogue moves to `IN_STAGE`; no reload path exists |
| data-config-pipeline.md | TR-data-006: no fallbacks; a load failure shows a catalogue-free fatal screen that never opens saves; dev runs name each error | Load failure calls AppRoot's `on_fatal`; the fatal scene reads no catalogue and no saves; development builds show the stored cause |
| data-config-pipeline.md | TR-data-009: a bad accessor call goes to an injected, test-replaceable handler that survives release builds | The accessor receives `fatal(cause)` from the builder; tests inject a spy; no `assert` |
| data-config-pipeline.md | TR-data-011: no autoload or global; the app root holds the catalogue across retries and the builder injects it | AppRoot holds the catalogue; `build` takes it as a parameter; autoloads are banned |
| input-gesture-resolver.md | TR-input-012: the wrapper builds resolver and adapter per battle from the Input record and injects the one resolver into Hero, Tower and HUD input objects | The wrapper calls `InputResolver.create` per battle (null calls `fatal`) and passes the resolver to TowerInput, HudLogic and HeroInput; hit radii stay constants on those objects |
| game-state-stage-flow.md | TR-state-001: a minimal main-scene app root, no autoload, triggers load, holds the catalogue, owns the fatal screen, alone survives retry | AppRoot as specified, states `BOOT`, `IN_STAGE`, `FATAL` |
| game-state-stage-flow.md | TR-state-002: scene-free `build(catalogue, stage_id, seed, fatal_handler)` wires every system by explicit connections, runs headless, calls the handler and returns null when unbuildable; thin wrapper adds tick, resolver, adapter, views | Static `BattleBuilder.build` with that signature and behaviour; `BattleWrapper` as specified |
| game-state-stage-flow.md | TR-state-009: retry destroys the whole battle between ticks via a latch on the app root; weakref to the old battle is null | Retry latch acted on at the top of AppRoot's frame; `remove_child` plus `free`; references dropped; weakref test |
| game-state-stage-flow.md | TR-state-011: one idempotent fatal handler, first cause, overrides Won/Lost/Paused, latches, halts, discards partial build; wrapper checks the latch per step; all four failure sources reach it; fatal screen guaranteed to load | `FatalLatch.fatal`; Flow enters FATAL; `halted()`; null build discarded; wrapper checks per step; preloaded fatal scene |
| enemy-wave.md | TR-enemy-005: builder injects `halted()` checked after every accessor read and signal; never references Flow | `Battle.halted` injected as a method Callable; the sim names no Flow class |
| enemy-wave.md | TR-enemy-012: `start_next_wave()` misuse logs to an injected dev-error sink, not assert | `dev_error(msg)` injected, wraps `push_error`, survives release; tests replace it. The Waiting/Active/Finished machine itself is EnemyWave's (ADR-0009) |
| tower-system.md | TR-tower-006: `halted()` checked after every read and signal; all stats read before any change | Implementation Guidelines make both mandatory for every sim |
| tower-system.md | TR-tower-013: retry teardown leaves no old battle alive through a signal connection; listener-count wiring test | Strong-field and no-back-reference rule plus the weakref test; the listener-count test belongs to ADR-0007's harness |
| hero-system.md | TR-hero-004: builder injects `halted()`, `in_build()`, the hand flag, Hero record ID and `burst_id` into HeroSim, HeroInput and HUD; Burst ID into HUD | Builder injects into HeroSim; `Battle` exposes these reads and the wrapper injects them into HeroInput and HudLogic |
| battle-hud.md | TR-hud-006: Retry sets an idempotent latch on the app root and never frees its caller; next frame checks Fatal, stops, cancels, frees and rebuilds | `AppRoot.request_retry()` and the retry order above |

## Performance Implications
- **CPU**: None per tick. `halted()` checks are one method call and a bool test each; at MVP sizes (tens of enemies) this is far under the frame budget (ADR-0004 owns the budget). A build runs once per attempt.
- **Memory**: One battle alive at a time; `free()` releases the old wrapper's nodes before the new build, so peak memory never holds two battles.
- **Load Time**: Retry rebuild is construction of five sims and the wrapper's nodes; expected well under one frame on desktop, to be measured on the first phone build. The catalogue loads once per session.
- **Network**: None.

## Migration Plan
No game code exists yet; prototypes under `prototypes/` are throwaway and are not migrated. The first Game State story creates `AppRoot`, `FatalLatch`, `Battle` and `BattleBuilder` with fake sims, then each system's first story replaces its fake.

## Validation Criteria
- **Headless build**: a gdUnit4 test calls `BattleBuilder.build` with a fixture catalogue and no scene tree and gets a non-null `Battle` whose `halted()` is false.
- **Null stage**: `build` with a null Stage record calls a spy handler once and returns null.
- **Idempotent fatal**: two `fatal` calls with different causes keep the first; the forward spy fires once.
- **Halt mid-command**: a sim given a latch that fires during a read makes no later change (one test per sim).
- **Weakref teardown**: after the retry sequence, a `weakref` to the old `Battle` reads null in the same frame (headless with a stand-in wrapper; editor and export as manual evidence). The test keeps no local, array, `print` argument or debugger watch on the battle, since any stray `Variant` delays the null.
- **Retry latch**: pressing Retry twice in one frame builds once; Retry after Fatal builds nothing.
- **No autoload**: CI lint finds an empty `[autoload]` section.
- **Release fatal**: an exported release build with one invalid record shows the fatal screen and leaves the save file unchanged (Data criterion 13, screenshot in `production/qa/evidence/`).
- **Export Callable probe**: QQ-17 re-run on an export template, result recorded in this ADR's Last Verified line.

## Related
- `docs/architecture/architecture.md`: Composition Root, Data Flow 4, 5 and 7, B4, B9, QQ-08, QQ-17 (lifetime half closed), QQ-19, QQ-20.
- ADR-0002 (Catalogue): defines `Catalogue` and the load states this ADR's AppRoot drives.
- ADR-0003 (Input Adapter and Lifecycle): pause and focus cancel paths; device spike.
- ADR-0004 (Tick and Determinism): the `Battle.tick` gate and Clock stop.
- ADR-0005 (Stat Accessor): the accessor that receives `fatal`.
- ADR-0007 (Test Harness and Layer Lint): weakref test, listener-count test, autoload and lambda lint.
- GDDs: `design/gdd/game-state-stage-flow.md` Rules 1, 2, 2a, 3, 16, 18; `design/gdd/data-config-pipeline.md`; `design/gdd/input-gesture-resolver.md`; `design/gdd/enemy-wave.md`; `design/gdd/tower-system.md`; `design/gdd/hero-system.md`; `design/gdd/battle-hud.md`.
