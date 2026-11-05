# ADR-0001: App Lifecycle, Composition Root and Fatal Path

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
njarrar (user), with technical-director and godot-specialist review. Drafted in autonomous mode from `docs/architecture/architecture.md` v4 and the approved MVP GDDs.

## Summary
TowerRiot needs one place that loads the catalogue, builds and rebuilds a battle, and fails the same way from every system, with no autoload and a simulation that runs headless. This ADR decides a main-scene AppRoot, a scene-free `BattleBuilder` that returns a `Battle` holding every helper in a typed field, one idempotent fatal path through per-battle and app-level latches, retry by dropping references and proving release with `weakref`, and `push_error` through injected sinks rather than `assert`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scene tree, object lifetime, scripting) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH: GDScript language and object lifetime changed after the model's training (4.5 to 4.7), and app lifecycle notifications are not in the pinned reference |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; `docs/architecture/architecture.md` (Engine Knowledge Gap Summary, Composition Root, Data Flow 4 to 7, B4, B9, QQ-17) |
| **Post-Cutoff APIs Used** | None new. The decision rests on behaviour, not new APIs: a method `Callable` or signal connection does not keep a `RefCounted` target alive, and `.call()` on a dead one raises a script error that aborts the caller (observed on the 4.7.2 desktop editor, QQ-17). A typed override in 4.7 needs an explicit `return` |
| **Verification Required** | Probes P1 to P5 in the appendix. P1 (Callable lifetime on an export template and a phone) and P4 (`push_error` survives a release export) must pass before this ADR is Accepted for phone builds; desktop development may proceed on the editor probe |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (catalogue load runs from AppRoot), ADR-0003 (adapter lives in the wrapper this ADR defines), ADR-0004 (Clock lives in the wrapper; `Battle.tick` is the only time entry), ADR-0005 (one accessor per battle, failure handler injected here), ADR-0006, ADR-0007 (test harness builds battles through `BattleBuilder`), ADR-0009 |
| **Blocks** | Every MVP epic: no system can be wired, tested headless or retried until the composition root exists |
| **Ordering Note** | Write and accept first. ADR-0003's device spike can run in parallel with P1 to P5, since both need the same first phone export |

## Context

### Problem Statement
Eight approved GDDs share one battle. Each system must be unit-testable with fakes, the whole battle must run headless for bots and CI, and a retry must leave nothing of the old battle alive. GDScript has no exceptions, export builds strip `assert`, and a 4.7.2 editor probe showed that a `Callable` does not keep its target alive. Without one decided composition root and failure path, each system would invent its own wiring, its own reset and its own error handling, which is how the prototype leaked 22 hand-reset fields between attempts. This is the first ADR because every other ADR places its parts inside the structure it defines.

### Constraints
- No autoload or global (Data Rule 12, Flow Rule 1, Architecture Principle 2).
- The simulation runs headless: the builder touches no node (Flow Rule 2).
- Gameplay classes extend `RefCounted` and read no `Engine`, `Time`, `OS`, timer or `await` (Flow Rule 4).
- A `Callable` does not keep a `RefCounted` target alive (QQ-17); an unguarded `.call()` on a dead or empty one is a script error that aborts the caller.
- `assert` is stripped in release exports, so no check that matters may use it (Data Rule 10).
- Solo, part-time developer: the structure must be small enough to hold in one head.

### Requirements
- Load the catalogue once, all or nothing, before the first battle; hold it across retries (TR-data-004, TR-data-011, TR-state-001).
- No fallbacks in any build; a catalogue-free fatal screen that never opens saves (TR-data-006).
- A test-replaceable failure handler that survives release (TR-data-009).
- One idempotent fatal handler that keeps the first cause, overrides Won, Lost and Paused, latches, halts the tick and discards a partial build (TR-state-011).
- Scene-free `build(catalogue, stage_id, seed, fatal_handler)` with explicit connections (TR-state-002).
- Strong typed fields for every helper; the builder holds nothing (TR-state-015).
- A guarded public `cancel_input()` (TR-state-016).
- Retry rebuilds through a latch on AppRoot, never resets, and leaves a null `weakref` (TR-state-009, TR-hud-006, TR-tower-013).
- Injected `halted()`, `in_build()`, IDs, hand flag and dev-error sink (TR-enemy-005, TR-enemy-012, TR-tower-006, TR-hero-004).
- The wrapper builds the resolver and adapter per battle (TR-input-012).

## Decision

### 1. AppRoot: the main scene, three states
`AppRoot` is the project's main scene, a `Node` with no gameplay references and no autoload. It owns the app states **Boot**, **InStage** and **Fatal**, the Ready catalogue, the app-level `FatalLatch`, and the retry latch.

- **Boot:** its `_ready` makes the app `FatalLatch`, confirms the catalogue-free fatal scene can load, and starts `Catalogue.load(manifest)` (format: ADR-0002). `Failed` goes to Fatal; `Ready` moves to InStage.
- **InStage:** it picks `stage_id` and `seed`, calls `BattleBuilder.build`, checks the result for `null` first and then the latch, and only then builds a `BattleWrapper` around the `Battle`.
- **Fatal:** terminal for the session. It tears down any wrapper, drops the battle, shows the fatal scene and never opens saves. Development builds show the first cause.

### 2. BattleBuilder: scene-free, holds nothing
```gdscript
class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, seed: int,
		fatal_handler: Callable) -> Battle
```
In one function, in this order: create the per-battle `FatalLatch`; validate stage inputs (a null Stage record calls `fatal_handler` and returns `null`); construct Flow, Combat, EnemyWave, TowerSim, HeroSim and the one `StatAccessor`; make every signal connection by name in this function, so the parser catches a misspelt signal; inject the B9 callables and values; return the `Battle`. It touches no node, is never called from inside a signal, and keeps no reference to anything it built.

### 3. Battle: the strong holder
`Battle extends RefCounted` holds a typed field for every helper the builder creates: each system, the `FatalLatch` and the accessor. Nothing else holds them strongly. No sim holds a reference back to `Battle`.
```gdscript
class_name Battle extends RefCounted
func tick(dt: float) -> void          # the only way simulation time advances (ADR-0004 owns the body)
func halted() -> bool                 # Flow is WON, LOST or FATAL, or the battle latch is set
func set_input_cancel(cancel: Callable) -> void   # wrapper only; never set headless
func cancel_input() -> void           # if _cancel.is_valid(): _cancel.call()
func fatal_cause() -> String          # the first cause, or "" when not latched
```
`cancel_input()` guards with `is_valid()`: headless it is never set and does nothing; the wrapper clears it with `set_input_cancel(Callable())` before releasing the resolver.

### 4. Injection rules
- Every injected callable is a **method Callable on an object `Battle` holds**: no lambda, and no `bind()` that captures a sim object. Capturing would create a cycle the weakref test cannot see past.
- The B9 table in `architecture.md` is the list: `halted`, `in_build`, `targets`, `cancel_input`, the Hero record ID, `burst_id`, `wave_index`, `left_handed`, `fatal`, `dev_error`, `to_ticks`, `dt`. Adding one is an amendment to this ADR.
- Every caller of a callable that can latch Fatal checks `halted()` after it and returns. Systems read every stat before mutating anything, so a bad read halts with nothing half done (TR-tower-006).

### 5. FatalLatch and the fatal path
```gdscript
class_name FatalLatch extends RefCounted
func latch(cause: String) -> void     # keeps the FIRST cause; later calls do nothing
func is_set() -> bool
func cause() -> String
```
The injected `fatal(cause)` is a method on `Battle` (or, during build before the `Battle` exists, on a builder-local latch object the `Battle` later takes over) that latches the battle latch and calls AppRoot's handler, which latches the app latch. It is idempotent. During build it only latches, and build returns `null`. After build, Flow enters FATAL from any phase, Won, Lost and Paused included, calls `cancel_input()`, and emits `phase_changed(FATAL)`; Flow checks the latch before each of its own emits. AppRoot acts on its next frame: tear down the wrapper, drop the battle, show the fatal scene.

### 6. Errors: `push_error`, never `assert`
- `fatal(cause)` is for broken data or contracts: play cannot continue.
- `dev_error(msg)` is the injected development-error sink for faults play survives (an unexpected command result, a log write failure). In the game it calls `push_error`, which survives release builds (probe P4); tests replace it with a recorder.
- `assert` is forbidden on any path whose check must hold in release.

### 7. BattleWrapper and teardown
`BattleWrapper` is a scene added under AppRoot. It holds, in typed fields, the `InputResolver` (null from `create` calls the failure handler), the adapter, the Clock and the views (input path: ADR-0003; clock: ADR-0004). After each assembly step it checks `battle.halted()` and stops if set. It exposes one teardown used by both retry and Fatal:
```gdscript
func teardown() -> void   # stop the Clock and set_process(false); battle.cancel_input();
                          # battle.set_input_cancel(Callable()); disconnect views; drop the resolver
```

### 8. Retry: rebuild, never reset
The Retry and Play again handlers only set an idempotent latch on AppRoot; they never free their own caller. On AppRoot's next `_process`:
1. If the app latch is set: go to Fatal and stop.
2. `wrapper.teardown()`.
3. `remove_child(wrapper)`, then `wrapper.free()`. AppRoot is outside the wrapper's call stack here, so an immediate `free()` is safe and the wrapper's fields release the resolver at once (probe P3 confirms; `queue_free()` is the fallback, with weakrefs sampled one frame later).
4. Drop AppRoot's reference to the `Battle`.
5. Development builds only: the `weakref`s taken at build to the `Battle`, every system, the accessor and the resolver must all read `null`; any that does not is a development error naming it.
6. `BattleBuilder.build` again with the same catalogue and seed (Play again) or the same catalogue and the next seed rule (ADR-0004).

A latch set outside Won or Lost causes no rebuild.

### Architecture Diagram
```
AppRoot (main scene, Node)            states: Boot -> InStage -> Fatal
 |- Catalogue (Ready, held for the session)
 |- FatalLatch (app)
 |- retry latch
 |- BattleWrapper (scene, per battle; absent headless)
 |    |- InputResolver   (typed field)        |- Clock (ADR-0004)
 |    |- InputAdapter    (ADR-0003)           '- HUD, field views
 |    '- holds a reference to Battle
 '- Battle (RefCounted, per battle)  <- built by BattleBuilder.build (scene-free)
      |- FatalLatch (battle)  |- StatAccessor (one)
      '- Flow, Combat, EnemyWave, TowerSim, HeroSim   (typed fields; no back-references)
```

### Key Interfaces
`AppRoot`, `BattleBuilder.build`, `Battle` (`tick`, `halted`, `set_input_cancel`, `cancel_input`, `fatal_cause`), `FatalLatch` (`latch`, `is_set`, `cause`), `BattleWrapper.teardown`, and the injected `fatal(cause)` and `dev_error(msg)`. Signatures as above; B4 and B9 of `architecture.md` are amended to add `fatal_cause()`, `FatalLatch.cause()` and `teardown()`.

### Implementation Guidelines
- Must never add an autoload or a global accessor for any gameplay object.
- Must construct every battle system in `BattleBuilder.build` and nowhere else; must never call `build` from inside a signal handler.
- Must hold every helper in a typed field on `Battle`; the builder must hold nothing after it returns.
- Must inject callables as method Callables on held objects; must never use a lambda or `bind()` that captures a sim object, and no sim may reference `Battle`.
- Must guard every injected optional callable with `is_valid()` before `.call()`.
- Must check `halted()` after every accessor read and every call that can latch Fatal, and return.
- Must read every stat a command needs before mutating any state.
- Must use the injected `fatal` or `dev_error`, never `assert`, for any check that matters in release.
- Must never free a node from inside its own handler; Retry sets a latch.
- Must never add a reset function to a system; retry rebuilds.
- Gameplay classes must never read `Engine`, `Time`, `OS`, a timer or `await`.

## Alternatives Considered

### Alternative 1: Autoload singletons (GameState, Catalogue)
- **Description**: A `GameState` autoload owns the battle and the catalogue; systems reach it by name.
- **Pros**: Idiomatic in many Godot projects; no injection boilerplate; easy access from any script.
- **Cons**: Every system gains a hidden dependency on a global; headless tests must stand up the autoload; retry must reset global state in place, which is the prototype's leak; load order between autoloads becomes a source of faults.
- **Rejection Reason**: Contradicts the no-globals rule in three GDDs and the coding standard of dependency injection over singletons, and makes the weakref proof of a clean retry impossible.

### Alternative 2: The battle scene's root script as composition root
- **Description**: The battle `.tscn` root script builds and wires the systems in `_ready`, as the technical director's earlier note proposed.
- **Pros**: Familiar scene-first structure; the editor shows the battle as one scene.
- **Cons**: A scene root cannot run headless, so bots and CI need the scene tree; wiring order follows node `_ready` order, which is implicit.
- **Rejection Reason**: Breaks the headless requirement (Flow Rule 2). The wrapper keeps the scene-side work (input, clock, views) without owning any gameplay wiring (QQ-08 records this amendment).

### Alternative 3: Reset in place on retry
- **Description**: Keep one battle and give each system a `reset()`.
- **Pros**: No allocation on retry; references stay stable.
- **Cons**: Every new field needs a matching reset line; a missed one leaks state between attempts, silently.
- **Rejection Reason**: The prototype did this with 22 hand-listed fields and leaked; Flow Rule 16 forbids it.

### Alternative 4: `queue_free()` for the wrapper with no explicit teardown
- **Description**: Let the engine free the wrapper at frame end.
- **Pros**: The usual safe default.
- **Cons**: Its fields keep the resolver alive until frame end, so the weakref check must wait a frame; input may still reach a half-dead wrapper in that window.
- **Rejection Reason**: An explicit `teardown()` then an immediate `free()` from AppRoot is deterministic. `queue_free()` remains the fallback if P3 finds `free()` unsafe there.

## Consequences

### Positive
- A battle is a plain function of `(catalogue, stage_id, seed, commands)` and runs headless, so bots, tests and the phone share one code path.
- Retry cannot leak state: nothing survives but AppRoot and the catalogue, and a development check proves it each time.
- One failure path: every system fails the same way, release builds included, and the first cause is kept.
- Each system is testable alone with fakes for every injected callable.

### Negative
- Injection boilerplate: the builder's one wiring function will be long, and B9 changes need an ADR amendment.
- `halted()` checks after every read are easy to forget; the listener-count and weakref tests catch some misses, review catches the rest.
- An immediate `free()` depends on probe P3.

## Risks
- **Callable lifetime differs on export or Android (P1).** Mitigation: the strong-holder rule makes the design safe either way; the probe confirms no extra reference is needed.
- **`is_valid()` reads true for a released `RefCounted` target (P2).** Mitigation: never rely on `is_valid()` for liveness, only for "was it set"; clear the cancel before releasing the resolver.
- **A reference cycle keeps the old battle alive.** Mitigation: the no-lambda, no-bind, no-back-reference rules, and the development weakref check on every retry.
- **`push_error` behaves differently in a release export (P4).** Mitigation: the probe runs on the first export; if it is silent, `dev_error` writes to the run log instead.
- **A long builder function becomes hard to read.** Mitigation: helper functions per system are allowed as long as all connections stay inside `build`'s call and the builder keeps no state.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-004: load once, all or nothing, started by the app root | AppRoot Boot state loads before any battle; Failed goes to Fatal |
| data-config-pipeline.md | TR-data-006: no fallbacks; catalogue-free fatal screen; never opens saves | AppRoot Fatal state and the catalogue-free fatal scene |
| data-config-pipeline.md | TR-data-009: injected, test-replaceable failure handler that survives release | `fatal(cause)` injected into the accessor; no `assert` |
| data-config-pipeline.md | TR-data-011: no autoload; app root holds the catalogue; builder injects it | AppRoot holds Ready catalogue; `BattleBuilder.build` takes it |
| input-gesture-resolver.md | TR-input-012: wrapper builds resolver and adapter per battle | BattleWrapper holds the resolver in a typed field; null `create` is Fatal |
| game-state-stage-flow.md | TR-state-001: minimal main-scene app root, no autoload | AppRoot, Decision 1 |
| game-state-stage-flow.md | TR-state-002: scene-free builder with explicit connections, headless | BattleBuilder, Decision 2 |
| game-state-stage-flow.md | TR-state-009: retry destroys and rebuilds; weakref null | Decision 8 |
| game-state-stage-flow.md | TR-state-011: one idempotent fatal handler, first cause, overrides outcomes | FatalLatch and fatal path, Decision 5 |
| game-state-stage-flow.md | TR-state-015: strong typed fields; builder holds nothing | Battle, Decision 3 |
| game-state-stage-flow.md | TR-state-016: guarded public `cancel_input()` | Battle, Decision 3 |
| enemy-wave.md | TR-enemy-005: injected `halted()` checked after every read and signal | Injection rules, Decision 4 |
| enemy-wave.md | TR-enemy-012: dev-error sink, not assert | `dev_error`, Decision 6 |
| tower-system.md | TR-tower-006: `halted()` after every read; read before mutate | Injection rules, Decision 4 |
| tower-system.md | TR-tower-013: no old battle alive through a connection; listener-count test | Decision 8 and Validation |
| hero-system.md | TR-hero-004: builder injects `halted()`, `in_build()`, hand, Hero and Burst IDs | B9 list, Decision 4 |
| battle-hud.md | TR-hud-006: Retry sets an idempotent latch and never frees its caller | Decision 8 |

## Performance Implications
- **CPU**: Negligible. `halted()` is a two-field check; the builder runs once per attempt.
- **Memory**: One battle at a time; the old one is released before the new one is built.
- **Load Time**: Catalogue load once per session (budget in ADR-0002). A rebuild should take well under one frame on desktop; measured at the first phone build.
- **Network**: None.

## Migration Plan
No game code exists yet (`src/` is empty). The prototypes are throwaway and are not migrated.

## Validation Criteria
- Headless test: `BattleBuilder.build` with fixture data returns a `Battle` and touches no node.
- Headless test: a null Stage record calls the handler once and returns `null`; a second fatal keeps the first cause.
- Headless test: after a retry, `weakref`s to the old `Battle`, each system, the accessor and the resolver all read `null`.
- Listener-count test: every expected connection exists after build, and none points at an old battle after retry.
- Headless test: `cancel_input()` with nothing set does nothing and raises no error; after `set_input_cancel(Callable())`, likewise.
- Lint: no autoload in `project.godot`; no `assert` under `src/`; no lambda or `bind()` in `BattleBuilder` (ADR-0007).
- Probes P1 to P5 pass on the first export template and phone.

## Related
- `docs/architecture/architecture.md` v4: Composition Root, Data Flow 4 to 7, B4, B9, QQ-08, QQ-17, QQ-19, QQ-20.
- GDDs: game-state-stage-flow.md (Rules 1, 2, 2a, 15, 16, 18), data-config-pipeline.md (Rules 5, 8, 10, 12), battle-hud.md (Rule 18), input-gesture-resolver.md (Rule 11).
- Enables ADR-0002 to ADR-0007 and ADR-0009.

## Appendix: Probes
Probe results go here, so a phone run does not hold the desktop decision. Each records the build, device and outcome.

| ID | Probe | Pass condition | Result |
|---|---|---|---|
| P1 | A method Callable to a `RefCounted` with no other holder, on an export template (desktop) and an Android phone | The target is released, as on the 4.7.2 editor; `.call()` on it is a script error | Editor 4.7.2: as stated (QQ-17). Export, phone: pending |
| P2 | `is_valid()` on a method Callable whose `RefCounted` target was released | Recorded either way; the design never relies on it for liveness | Pending |
| P3 | `remove_child` then `free()` of the wrapper from AppRoot's `_process` | No error; `weakref`s to the resolver and battle read `null` in the same frame | Pending |
| P4 | `push_error` from a release export | The message reaches the device log | Pending |
| P5 | A signal connection from a released `RefCounted` emitter to a live listener, and the reverse | No error on emit; the listener count drops | Pending |
