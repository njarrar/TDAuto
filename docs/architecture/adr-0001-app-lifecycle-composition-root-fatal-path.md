# ADR-0001: App Lifecycle, Composition Root and Fatal Path

## Status
Proposed

## Date
2026-11-03

## Last Verified
2026-11-03 (against `docs/engine-reference/godot/` for Godot 4.7.2 and `docs/architecture/architecture.md` v3)

## Decision Makers
- Author: `/architecture-decision`, run in autonomous mode (decisions logged in `production/session-logs/decision-log.md`)
- Engine specialist (godot-specialist): NOT ASSESSED in this run. See Validation Criteria, "Reviews still owed".
- Technical director (TD-ADR): NOT ASSESSED in this run. See Validation Criteria, "Reviews still owed".
- Acceptance: the user. QQ-08's technical-director acceptance of the scene-free builder also waits for the user.

## Summary
TowerRiot needs one place that loads the catalogue, builds a battle, tears it down on retry and stops everything on a fatal error, without autoloads, so the battle runs the same headless and on a phone. This ADR decides a main-scene `AppRoot` with three app states, a scene-free `BattleBuilder` that injects method Callables, a `Battle.unwire()` step plus an acyclic object graph so retry frees the old battle whatever Godot's Callable reference rules turn out to be, and one idempotent two-level `FatalLatch` that ends on a code-built fatal screen.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core (app lifecycle and composition) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (architecture.md rates the App lifecycle row HIGH; the APIs this ADR itself calls date from 4.0 and show no change in 4.5 to 4.7 in `breaking-changes.md`, but two behaviours it leans on are unverified on 4.7) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md`; `docs/architecture/architecture.md` v3 (Layer Map, Module Ownership, Data Flow 4, 5, 7, API Boundaries B0, B4, B9, Required ADRs, Open Questions); `docs/architecture/tr-registry.yaml` |
| **Post-Cutoff APIs Used** | None. Used: `RefCounted`, `Callable`, `Signal.connect()` / `disconnect()` / `is_connected()`, `weakref()`, `Node.remove_child()`, `Node.queue_free()`, `Node.set_process()`, `push_error()`, `OS.is_debug_build()`, `Control`, `Label`. All exist since 4.0. 4.7's typed-return override rule applies to any class here that overrides a typed method. |
| **Verification Required** | (1) QQ-17: whether a method `Callable`, and a signal connection, holds a strong reference to a `RefCounted` target on 4.7.2 (test V1). (2) That a node removed with `remove_child()` gets no further `_process` or input callbacks before its queued free completes (test V6). (3) That `push_error()` still reports in an exported release build (test V8). None of these is in the pinned reference. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (catalogue format; this ADR fixes who loads it and where a load failure goes), ADR-0003 (adapter; this ADR fixes who builds and frees it and who else calls `cancel()`), ADR-0004 (clock; this ADR fixes the wrapper that holds it), ADR-0005 (accessor; this ADR fixes the failure handler it calls), ADR-0006 (signals; this ADR fixes that the Builder makes and records every wiring connection), ADR-0007 (harness; this ADR names the weakref, fatal and wiring tests), ADR-0009 (enemy entity; this ADR fixes the no-back-reference rule the weakref test needs) |
| **Blocks** | Every MVP epic. No epic or story exists yet (`production/` holds none), so no story is blocked by path today. Once `/create-epics` runs, any story that builds AppRoot, the Builder, the BattleWrapper, the FatalLatch, the fatal screen or a retry path waits for this ADR to be Accepted. |
| **Ordering Note** | Write and accept first among ADR-0001 to ADR-0008 (architecture.md Priority). ADR-0003's device spike may change which notifications reach the adapter, but not anything this ADR decides. |

## Context

### Problem Statement
Eight MVP GDDs assume one composition root that nobody has designed yet. The Game State GDD (Rules 1 to 3, 16 and 18) asks for an app root with no autoload, a scene-free builder, retry by rebuild and one fatal path. Data asks that a load failure and a bad accessor call reach a fatal screen in every build, without `assert`. Enemy & Wave, Tower and Hero ask for an injected `halted()` and no reference to Flow. Tower and Flow ask that a retry leave no old battle alive, proved by a `weakref`. HUD asks that Retry never free its own caller.

These must be fixed before any code exists, because every other Foundation ADR plugs into them. Two facts the design leans on cannot be checked offline: whether a method `Callable` keeps its object alive on 4.7 (QQ-17), and the exact timing of `free()` against `queue_free()` for the wrapper. The design must hold either way, and name the test that settles each.

### Current State
No code. `src/` holds only a `CLAUDE.md`. `project.godot` sets no main scene and no `[autoload]` section. No ADR exists. `docs/registry/architecture.yaml` is empty.

### Constraints
- **Engine**: Godot 4.7.2, GDScript, single main thread (architecture.md Data Flow). GDScript has no exceptions, so a caller keeps running after a fatal call and must check `halted()`. `assert` is stripped from exported builds.
- **Architecture**: no autoloads (architecture.md Principle 2). Simulation classes extend `RefCounted`, never `Node` (B0). Nothing may depend on the composition root (Dependency rule 2).
- **Determinism**: a battle is a function of `(catalogue, stage_id, seed, command script)`; gameplay classes never read `Engine`, `Time`, `OS`, timers or `await` (B4).
- **Team**: solo part-time developer. Keep the root small and the number of new classes low.
- **Testing**: everything in B0 to B2 and B4 to B9 runs headless in gdUnit4, the weakref test included.

### Requirements
- Load the catalogue once, all or nothing, before the first battle, and hold it across retries (TR-data-004, TR-data-011, TR-state-001).
- Build a battle with no node, from `build(catalogue, stage_id, seed, fatal_handler)`, and wire it in one function (TR-state-002, TR-input-012, TR-hero-004).
- Inject `halted()` into every sim so none references Flow, and check it after every read and signal (TR-enemy-005, TR-tower-006).
- Give bad accessor calls and dev errors injected sinks that survive release builds (TR-data-009, TR-enemy-012).
- One idempotent fatal handler that keeps the first cause, halts the tick, discards a partial build and shows a screen that always loads and never opens saves (TR-data-006, TR-state-011).
- Retry by a latch on the root, acted on next frame, that tears down and rebuilds; a weakref to the old battle reads null and no signal connection keeps it alive (TR-state-009, TR-tower-013, TR-hud-006).

## Decision

### 1. App root and app states
- The main scene is `res://src/root/app_root.tscn`, a `Node` with script `AppRoot`. `project.godot` gets `run/main_scene` set to it and never gets an `[autoload]` section.
- `AppRoot` owns: its app state (`BOOT`, `IN_STAGE`, `FATAL`), the Ready `Catalogue`, the app-level `FatalLatch`, the retry latch, a `PresentationSettings` value, and the current `Battle` and `BattleWrapper` (or none).
- `_ready()`: create the app latch first, then call `Catalogue.load(manifest)`. On a failed `LoadResult`, call the app latch's `fatal()` with a cause built from the error list. On success, keep the catalogue, read the Input record once into `PresentationSettings`, pick `stage_id` and `seed`, and start a battle (section 3).
- `FATAL` is absorbing. No transition leaves it; the player relaunches. From VS, Save boot runs only after a Ready load, so a failed load never opens a save.
- AppRoot never uses `SceneTree.paused`. Pause is a Flow phase (ADR-0003, ADR-0004).

### 2. Builder and Battle
- `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler) -> Battle` is a static function on a `RefCounted` class. It touches no node, so tests and bots call it headless. It is never called from inside a signal handler.
- Build order: (a) create the battle `FatalLatch`, forwarding to `fatal_handler`; (b) read the Stage, Input and Hero records and check stage inputs; create `InputResolver.create(drag_slop, tap_slop)` and call `fatal("input_record_invalid")` if it returns null (this closes the Builder's part of QQ-19); (c) construct `Flow`, `Combat`, `EnemyWave`, `TowerSim`, `HeroSim`, `HaltGate`, `TickMath`; (d) inject values and make every signal connection, each through `Wiring.connect_recorded()`; (e) return the `Battle`.
- After each step the Builder checks the battle latch. If it is set, `build` drops its locals and returns `null`, so a partial battle is never ticked. The caller treats `null` as "a fatal is pending" and must not retry the build.
- `Battle` is a `RefCounted` holding read-only members `flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`, `input_resolver` (new, see Consequences) and a private `wiring`.
- `Battle.halted()` is a pass-through to its `HaltGate`, for the wrapper and tests. Sims get `HaltGate.halted`, never a Callable on `Battle`.

### 3. Injection rules and the acyclic graph
- Everything a sim needs from outside arrives as an injected value or a method `Callable` bound to a Builder-owned object (B9). The Builder never passes a lambda, and never uses `bind()` with a sim object as an argument.
- **No sim object holds a reference to `Battle`, to `AppRoot` or to any `Node`.** `HaltGate` holds `Flow` and the battle `FatalLatch`, and `halted()` is true when `flow.phase()` is `WON`, `LOST` or `FATAL`, or the latch is set. It is false while `PAUSED`; the tick gate stops time then.
- Injected Callables point only "down" a fixed order, so they form no cycle on their own: sims point at `HaltGate`, `TickMath`, the dev-error sink, the battle latch, `EnemyWave` (`targets()`, `wave_index()`) and the resolver (`cancel_input()`). Nothing points back at a sim that points at it.
- Signal connections do point both ways (for example `EnemyWave.enemy_leaked` to `Flow`, while `Flow` holds `EnemyWave.wave_index`). If Godot treats a connection as a strong reference, that is a cycle. Section 5 removes it at teardown.
- `left_handed` and `reduce_motion` come from the Input record. The Builder passes `left_handed` to `HeroSim` with the Hero record ID and `burst_id` (TR-hero-004). The wrapper passes `PresentationSettings` (both flags) to HeroInput, HudLogic and every view. Views read Reduce Motion only from `PresentationSettings`, never from the catalogue (QQ-09). At Alpha, Settings becomes the source of `PresentationSettings` and no view changes.

### 4. BattleWrapper
- `BattleWrapper` is a scene that AppRoot adds as a child after a non-null `build`. It holds the Clock, the `InputAdapter`, HeroInput, TowerInput, HudLogic, the HUD and the field views, all built from `battle.input_resolver` and `PresentationSettings` (TR-input-012). It holds no gameplay logic and has no branch on a gameplay value.
- Headless runs have no wrapper.

### 5. Retry and teardown
- The Result screen's Retry handler calls `AppRoot.request_retry()`, which sets an idempotent latch and returns. It frees nothing (TR-hud-006).
- `AppRoot._process()` acts on pending work in this order, each frame:
  1. If the app latch is set: tear down (steps 3 to 6 below, if a battle exists), show the fatal screen, set `FATAL`, call `set_process(false)`. Stop.
  2. If the retry latch is set and Flow is `WON` or `LOST`: clear the latch and tear down, then rebuild. A retry latch outside `WON` or `LOST` is cleared and ignored.
  3. Teardown: `wrapper.set_process(false)` and stop the Clock; `battle.input_resolver.cancel()`.
  4. `remove_child(wrapper)` then `wrapper.queue_free()`. The wrapper leaves the tree at once and is deleted at the end of the frame.
  5. `battle.unwire()`: disconnect every connection in the `Wiring` record, then clear the record. Idempotent.
  6. Set AppRoot's `battle` and `wrapper` fields to null.
  7. Rebuild: `BattleBuilder.build()` with the same catalogue, then a new wrapper. The new battle opens in Build, which runs no ticks, so it does not matter whether the new wrapper's `_process` runs in this frame.
- AppRoot acts from its own `_process`, never from inside the wrapper's call stack, so `queue_free()` is used for tidy end-of-frame deletion, not for stack safety. `free()` is not used on the wrapper.
- Retry resets nothing in place. No system has a reset function. `unwire()` lives on `Battle` in the composition root and changes no gameplay state.

### 6. Fatal path
- One `FatalLatch` class, two instances: one per battle, one on AppRoot. `fatal(cause: String)` keeps the first cause, counts later calls, calls `push_error(cause)` on the first call only, then emits `latched(cause)` once. `is_fatal()` and `first_cause()` read it.
- The battle latch also calls the forwarded `fatal_handler` (the app latch's `fatal`) on its first call. The Builder connects `latched` to `Flow`, which enters `FATAL`, calls `cancel_input()` and emits `phase_changed(FATAL)`. From then on `halted()` is true, so later steps in the tick return at once (TR-state-011).
- The app latch only records. AppRoot acts on it in its next `_process` (section 5, step 1), so a fatal raised deep in a tick never frees the wrapper from inside that tick.
- Every fatal source takes this path: a failed catalogue load (AppRoot calls the app latch), a bad accessor call (the accessor's injected handler is the battle latch's `fatal`), a bad stage input or invalid Input record (the Builder), and a broken stage scene (the wrapper, when it fails to instance `scene_ref`, calls the battle latch).
- The fatal screen is `FatalScreen extends Control`, built in code with one `Label` and the default theme. It loads no `.tscn`, font, texture or catalogue data, so it has nothing that can fail to load. In a debug build (`OS.is_debug_build()`) it shows the first cause and, for a load failure, every `ValidationError` by file, record and field. In a release build it shows one generic line. Its text is a code constant at MVP; it moves to the localisation table when one exists.
- `assert` is never used for a check that matters in release. Release-relevant checks call an injected handler.

### 7. Error sinks
- **Fatal**: the battle latch's `fatal`, injected into the accessor, the Builder steps and every sim.
- **Dev error**: `DevErrorSink.report(msg: String)`, injected into EnemyWave (TR-enemy-012), Flow (Rule 15a) and others. The game's sink calls `push_error(msg)` in all builds and does not halt. Tests inject a recording fake.
- **`cancel()` callers (QQ-20)**: the adapter (pause, focus loss, resize; ADR-0003), Flow through the injected `cancel_input()` (Won, Lost, Paused, Fatal), and AppRoot at teardown (retry and fatal). Input Rule 7 must be widened to list all three.

### Architecture Diagram

```
AppRoot (Node, main scene; state BOOT | IN_STAGE | FATAL)
  owns: Catalogue, app FatalLatch, retry latch, PresentationSettings
  │
  │ build(catalogue, stage_id, seed, app_latch.fatal)      [no node touched]
  ▼
Battle (RefCounted) ─ holds ─► Flow, Combat, EnemyWave, TowerSim, HeroSim,
  │                            battle FatalLatch, InputResolver, HaltGate, Wiring
  │
  │  injected Callables (point one way only):
  │    sims ──► HaltGate ──► Flow, battle FatalLatch
  │    sims ──► TickMath, DevErrorSink, battle FatalLatch.fatal
  │    TowerSim, HeroSim ──► EnemyWave.targets      Flow ──► EnemyWave.wave_index
  │    Flow ──► InputResolver.cancel                FatalLatch ──► app latch.fatal
  │
  │  signal connections (both ways, every one recorded in Wiring):
  │    EnemyWave ─► Flow, TowerSim     Flow ─► TowerSim     FatalLatch ─► Flow
  │
  ▼
BattleWrapper (Node scene, absent headless)
  Clock, InputAdapter, HeroInput, TowerInput, HudLogic, HUD, views

Retry / fatal teardown, in AppRoot._process:
  stop clock ─► resolver.cancel() ─► remove_child + queue_free(wrapper)
  ─► battle.unwire() ─► drop Battle ─► (retry) build again | (fatal) FatalScreen
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
static func build(catalogue: Catalogue, stage_id: StringName, seed: int, fatal_handler: Callable) -> Battle

class_name Battle extends RefCounted
var flow: Flow                       # read-only by contract
var combat: Combat
var enemy_wave: EnemyWave
var tower_sim: TowerSim
var hero_sim: HeroSim
var fatal_latch: FatalLatch
var input_resolver: InputResolver
func tick(dt: float) -> void         # gate and order: ADR-0004
func halted() -> bool                # pass-through to HaltGate
## Disconnects every Builder connection. Idempotent. Composition root only.
func unwire() -> void

class_name HaltGate extends RefCounted
## True on WON, LOST or FATAL, or when the battle latch is set. False while PAUSED.
func halted() -> bool

class_name FatalLatch extends RefCounted
signal latched(cause: String)        # once, on the first fatal()
## Idempotent. Keeps the first cause. push_error on the first call only.
func fatal(cause: String) -> void
func is_fatal() -> bool
func first_cause() -> String

class_name Wiring extends RefCounted
## Connects and records the pair, so unwire() can undo it.
func connect_recorded(sig: Signal, target: Callable) -> void
func disconnect_all() -> void

class_name DevErrorSink extends RefCounted
func report(msg: String) -> void     # push_error in every build; never halts

class_name PresentationSettings extends RefCounted
var left_handed: bool
var reduce_motion: bool

class_name FatalScreen extends Control
func show_cause(first_cause: String, errors: Array[ValidationError]) -> void
```

Names are proposed by this ADR. `Battle.input_resolver`, `HaltGate`, `Wiring`, `PresentationSettings`, `DevErrorSink` and `FatalLatch.latched` are new against architecture.md v3. QQ-16 (global `class_name` collisions) may add a prefix; ADR-0007 decides.

### Implementation Guidelines
1. `project.godot` must never contain an `[autoload]` section. CI fails if it does.
2. Gameplay and Foundation code must never reference `AppRoot`, `BattleBuilder`, `Battle` or `BattleWrapper` by name.
3. The Builder must make every gameplay signal connection through `Wiring.connect_recorded()`. A direct `.connect()` on a sim signal anywhere outside the Builder is forbidden.
4. Injected Callables must be method Callables on Builder-owned objects. Lambdas, and `bind()` with a sim object argument, are forbidden in the Builder and the wrapper.
5. No sim object may hold a reference to `Battle`, `AppRoot` or any `Node`. `halted()` is injected as `HaltGate.halted`, never as `Battle.halted`.
6. `BattleBuilder.build()` must check the battle latch after each step and return `null` once it is set.
7. Every caller of an accessor read, an injected Callable or a signal emit inside a tick must check `halted()` after it and return at once when true.
8. `assert` must never guard a release-relevant check. Use the injected fatal handler or the dev-error sink.
9. AppRoot must act on the retry and fatal latches only from its own `_process`, fatal first. A Retry handler must only call `request_retry()`.
10. Teardown order must be: stop the clock, `resolver.cancel()`, `remove_child()` and `queue_free()` the wrapper, `battle.unwire()`, drop every reference. Never call `free()` on the wrapper.
11. The fatal screen must load no resource and read no catalogue data. Debug builds show the cause; release builds show one generic line.
12. Views must read `reduce_motion` and `left_handed` only from the injected `PresentationSettings`.
13. A typed override in any of these classes must end with an explicit `return` (4.7 rule).

## Alternatives Considered

### Alternative 1: Autoload singletons (a `Game` autoload holding the catalogue, plus an event bus)
- **Description**: register a global `Game` node that loads and holds the catalogue, and an `Events` autoload that systems emit on and listen to.
- **Pros**: the most common Godot pattern; any script reaches the catalogue in one line; no wiring code.
- **Cons**: every system gains a hidden dependency on a global, so unit tests need the autoload or a stub of it; an autoload survives retry, so state can leak between attempts; an event bus hides who listens, which defeats the listener-count wiring test (TR-tower-013); autoload load order becomes a failure mode before the fatal path exists.
- **Rejection Reason**: the Data and Game State GDDs both forbid autoloads (TR-data-011, TR-state-001), and dependency injection is a coding standard here.

### Alternative 2: Scene-owned battle root
- **Description**: a `battle.tscn` whose root script wires child system nodes in `_ready()`; retry reloads the scene.
- **Pros**: familiar; the editor shows the battle's parts; scene reload frees everything.
- **Cons**: needs a scene tree, so bots and headless tests cannot build a battle; systems become `Node`s, whose built-in `position` collides with Combat's and whose `free()` breaks `removed` (B0); scene reload timing is engine-defined and hard to test.
- **Rejection Reason**: TR-state-002 requires a scene-free builder that runs headless. This is the change QQ-08 records.

### Alternative 3: Reset in place on retry
- **Description**: keep the battle and call `reset()` on each system.
- **Pros**: no teardown cost; no weakref question.
- **Cons**: every new field needs a matching reset line; the prototype's hand-listed reset of 22 fields is how state leaked between attempts (Game State Rule 16).
- **Rejection Reason**: the GDD rules it out.

### Alternative 4: Trust Callable semantics, no unwire (architecture.md v3 default)
- **Description**: drop the `Battle` and rely on there being no strong cycle, with `halted()` injected as `Battle.halted`.
- **Pros**: less code; no `Wiring` record.
- **Cons**: correct only if method Callables and signal connections are weak on 4.7, which nobody has checked (QQ-17). If they are strong, `Battle.halted` injected into each sim is a sim-to-Battle cycle (against B4's own rule), and two-way signal links form more. The weakref test would then fail with no clear fix.
- **Rejection Reason**: it bets the retry design on an unverified engine fact. The chosen design holds either way, and the V1 probe still records the answer.

### Alternative 5: Fatal screen as a `.tscn` loaded on demand
- **Description**: `load("res://src/root/fatal_screen.tscn")` when entering `FATAL`.
- **Pros**: the screen can be laid out in the editor.
- **Cons**: a load at the worst moment is one more thing that can fail, and a broken export could drop the file.
- **Rejection Reason**: TR-state-011 asks that the screen be guaranteed to load. A code-built `Control` has no resource to lose.

## Consequences

### Positive
- One code path builds a battle for the phone, bots and tests, so a bot result is a test of the shipped wiring.
- Retry frees the old battle whatever QQ-17's answer is, and the weakref test proves it on every CI run.
- Every fatal source ends in the same latch and the same screen, in every build; a fatal deep in a tick never frees the node whose code is running.
- Systems never know about Flow, Battle or the root. Each is unit-tested with fakes for `halted()`, the sinks and `targets()`.
- Reduce Motion has one read point today and one swap point at Alpha.

### Negative
- Six small classes join the root and Foundation (`HaltGate`, `Wiring`, `DevErrorSink`, `PresentationSettings`, `FatalScreen`, `AppRoot`), on top of those architecture.md already named.
- `unwire()` is one more teardown step to keep in order. A missed `connect_recorded()` call (a direct `.connect()`) would leave a connection undone; the lint in Implementation Guideline 3 and test V2 guard it.
- A fatal shows one frame late, because AppRoot acts in its next `_process`. The sim halts at once, so no state changes in that frame.
- At MVP the only exit from `FATAL` is to relaunch.
- architecture.md v3 needs four edits to match (see Migration Plan).

### Neutral
- `Battle.halted()` stays as a pass-through, so the wrapper and tests read it as before.
- The fatal screen's look is plain text at MVP, which matches the Game State GDD's Visual section.

## Risks
- **Callables or connections are strong, and a hidden cycle remains** (a sim that stores another sim's Callable that points back). Mitigation: Implementation Guidelines 4 and 5, and test V2, which checks the weakref of every sim, not only `Battle`.
- **Callables are weak, and an injected target dies early.** All targets are held by `Battle` for its whole life, so this cannot happen while the battle lives. After `unwire()`, nothing calls them. V1 records the answer.
- **A removed wrapper still gets a `_process` or input call before its free.** Mitigation: `set_process(false)` and the clock stop come before `remove_child()`; the gate in `Battle.tick` also returns once halted. Test V6 checks it.
- **`push_error()` is silent in a release export.** Then a release fatal still reaches the screen (the latch does not rely on the log), but no log line exists. Test V8 checks it; if it fails, the release build writes the cause to the screen's hidden debug field only.
- **The app latch and battle latch disagree.** The battle latch always forwards on its first call, and AppRoot reads only its own latch. Test V3 covers both orders.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-004: load once, all or nothing, started by the app root before the first gameplay scene, no reload | Decision 1: AppRoot `_ready()` calls `Catalogue.load()` once; `BOOT` moves to `IN_STAGE` only on a Ready load; no reload path exists |
| data-config-pipeline.md | TR-data-006: no fallbacks; a load failure shows a catalogue-free fatal screen that never opens saves; dev runs name each error | Decision 1 and 6: a failed load goes to the app latch and `FatalScreen`, which uses no catalogue data; Save boot runs only after Ready; debug builds list each `ValidationError` |
| data-config-pipeline.md | TR-data-009: a bad accessor call goes to an injected, test-replaceable handler that survives release builds (not assert) | Decision 6 and 7: the accessor gets the battle latch's `fatal`; tests inject a spy; `assert` is forbidden for this |
| data-config-pipeline.md | TR-data-011: no autoload or global; the app root holds the catalogue across retries; the builder injects it | Decision 1 and 5: AppRoot holds the catalogue and passes the same object to every `build()`; Guideline 1 bans autoloads |
| input-gesture-resolver.md | TR-input-012: Game State builds the resolver and adapter per battle from the Input record and injects the one resolver into Hero, Tower and HUD wrappers | Decision 2 and 4: the Builder creates the resolver from the Input record and exposes it as `battle.input_resolver`; the wrapper builds the adapter and hands that one resolver to HeroInput, TowerInput and HudLogic; both die on retry |
| game-state-stage-flow.md | TR-state-001: a minimal main-scene app root, no autoload, triggers the load, holds the catalogue, owns the fatal screen, alone survives a retry | Decision 1, 5 and 6 |
| game-state-stage-flow.md | TR-state-002: scene-free `build(catalogue, stage_id, seed, fatal_handler)` wires every system by explicit connections and runs headless; a thin wrapper adds tick loop, adapter and views | Decision 2 to 4: static `build()` touches no node and records every connection in `Wiring`; `BattleWrapper` holds no logic |
| game-state-stage-flow.md | TR-state-009: retry destroys the whole battle and builds a new one between ticks, driven by a latch on the app root; a weakref to the old battle is null | Decision 5: latch, teardown in AppRoot `_process`, `unwire()`, drop, rebuild; tests V2 and V5 |
| game-state-stage-flow.md | TR-state-011: one idempotent fatal handler keeps the first cause, latches, halts the tick, discards a partial build; the fatal screen is guaranteed to load | Decision 6: `FatalLatch` semantics, `halted()` through `HaltGate`, `build()` returns null, code-built `FatalScreen` |
| enemy-wave.md | TR-enemy-005: the builder injects `halted()` checked after every read and signal; the system never references Flow | Decision 3: `HaltGate.halted` injected; Guideline 7 |
| enemy-wave.md | TR-enemy-012: wave control logs to an injected dev-error sink, not assert | Decision 7: `DevErrorSink` injected, recording fake in tests |
| tower-system.md | TR-tower-006: injected `halted()` checked after every read and signal; all stats read before any mutation | Decision 3 and Guideline 7 provide and require the check. The read-before-mutate order is TowerSim's own rule, enforced by ADR-0010's command contract |
| tower-system.md | TR-tower-013: retry teardown leaves no old battle alive through a signal connection; a listener-count wiring test names any missing connection | Decision 5: `unwire()` disconnects every recorded connection; test V2 checks every sim's weakref. The `Wiring` record gives ADR-0006's listener-count test its list |
| hero-system.md | TR-hero-004: the builder injects `halted()`, `in_build()`, the hand flag, the Hero record ID and `burst_id` into HeroSim, HeroInput and the HUD | Decision 3: the Builder injects them into HeroSim; the wrapper passes `PresentationSettings`, `in_build` and `burst_id` to HeroInput and HudLogic |
| battle-hud.md | TR-hud-006: Retry sets an idempotent latch on the app root and never frees its caller; the root's next frame checks Fatal, stops, cancels, frees and rebuilds | Decision 5: `request_retry()` and the `_process` order, fatal first |

## Performance Implications
- **CPU**: none per tick. `HaltGate.halted()` is two reads. Retry costs one build plus one teardown, once per attempt, outside any tick.
- **Memory**: one battle alive at a time after the wrapper's end-of-frame free. The `Wiring` record holds about 20 pairs.
- **Load Time**: the catalogue load (budget owned by ADR-0002) runs once per session. The fatal screen adds no load.
- **Network**: none.

## Migration Plan
No code exists, so nothing migrates. When this ADR is Accepted, these documents need edits to match. This ADR does not make them, because only the user can accept it:
1. `docs/architecture/architecture.md`: B0 adds `input_resolver` to `Battle`; B9 changes `halted()` from `Battle.halted()` to `HaltGate.halted()`; Data Flow 5 adds the `unwire()` step and the `remove_child` plus `queue_free` order; Composition Root table adds `HaltGate`, `Wiring`, `PresentationSettings`, `FatalScreen`; QQ-09, QQ-17 (design part), QQ-20 marked resolved by ADR-0001.
2. `design/gdd/input-gesture-resolver.md` Rule 7: list Flow (through `cancel_input()`) and AppRoot (teardown) as `cancel()` callers beside the adapter (QQ-20, cross-review C2).
3. `design/gdd/game-state-stage-flow.md` Rule 16: name `unwire()` in the retry order, after removing the wrapper.
4. `design/gdd/enemy-wave.md` Open Questions row at line 515: Reduce Motion location is settled.

## Validation Criteria
Headless gdUnit4 tests (ADR-0007 places them; names proposed):
- **V1 `test_callable_ref_semantics_probe`** (settles QQ-17): (a) store `Callable(a, &"m")` on `b`, drop every other ref to `a`, check `weakref(a).get_ref()`; (b) connect `a.sig` to `b.m`, drop `b`, check `weakref(b)`; (c) the same with the source dropped. It asserts nothing about which answer is right; it records the answer, and the result goes into `docs/engine-reference/godot/` with the date and version. Until it runs, this ADR treats the answer as unknown.
- **V2 `test_retry_frees_old_battle`**: build, run a scripted micro-battle to `LOST`, call `unwire()`, drop the battle, then check that the weakref of `Battle` and of each sim reads null. A second case skips `unwire()` and records whether it still passes, which shows whether `unwire()` is load-bearing on 4.7.2.
- **V3 `test_fatal_latch_first_cause`**: two `fatal()` calls keep the first cause, emit `latched` once and forward once; both latch orders tested.
- **V4 `test_fatal_during_build_returns_null`**: a bad Input record makes `build()` return null with the app latch set; nothing ticks.
- **V5 `test_fatal_mid_tick_halts_later_steps`**: a spy accessor fires `fatal` inside `EnemyWave.advance`; TowerSim and HeroSim do nothing that tick.
- **V6 `test_retry_latch_and_teardown_order`** (integration, scene tree, headless): two Retry calls give one rebuild; the handler frees nothing; a fatal pending with a retry shows Fatal; the removed wrapper's `_process` is not called after `remove_child()`.
- **V7 `test_no_autoload`**: `project.godot` has no `[autoload]` section (part of ADR-0007's lint).
- **V7b `test_fatal_screen_loads_bare`**: `FatalScreen.new()` builds and shows a cause with no catalogue and no resources.
Manual evidence (`production/qa/evidence/`, first phone build):
- **V8**: an exported release build with one invalid record shows the fatal screen, leaves saves untouched, and a bad accessor call reaches it too; check the device log for the `push_error` line (Data AC 13).

**Reviews still owed.** This run had no way to spawn review agents, so the godot-specialist check (Step 5.5) and the technical-director TD-ADR gate (Step 5.6) did not run. Both must run before acceptance. `review_mode` is `full`, so TD-ADR is required.

## Related
- `docs/architecture/architecture.md` v3: Composition Root, Data Flow 4, 5 and 7, B4, B9, QQ-08, QQ-09, QQ-17, QQ-19 (Builder part), QQ-20
- `docs/architecture/tr-registry.yaml`: the 15 TRs above
- GDDs: `design/gdd/game-state-stage-flow.md` (Rules 1 to 3, 15 to 18), `design/gdd/data-config-pipeline.md` (Rules 8, 10), `design/gdd/input-gesture-resolver.md` (Rule 7, Interactions), `design/gdd/enemy-wave.md` (Rule 13), `design/gdd/tower-system.md`, `design/gdd/hero-system.md`, `design/gdd/battle-hud.md` (Rule 18)
- Enables ADR-0002 to ADR-0007 and ADR-0009 (none written yet)
