# ADR-0001: Simulation and Shell Boundary

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

Godot specialist (author, autonomous run). TD-ADR: not run per ADR; batch review after all ADRs are written. Engine specialist gate: not run per ADR; same batch review.

## Summary

TowerRiot must run the same battle on a phone, in unit tests and in headless bots, so gameplay code cannot depend on the scene tree. Every gameplay module is a plain `RefCounted` object (sim); nodes, Controls and drawing (shell) only read sim state through `BattleReadModel` and send commands through `Battle`, and a headless test proves the sim loads with no scene tree.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2 installed, matches the pin) |
| **Domain** | Core (Scripting) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (GDScript 4.5 and 4.7 changes are post-cutoff) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.6 to 4.7, 4.4 to 4.5), `deprecated-apis.md`, `current-best-practices.md` (GDScript 4.5+, GDScript 4.7, Command Line); official class reference at tag 4.7.2-stable: `doc/classes/RefCounted.xml`, `doc/classes/Object.xml`, `doc/classes/Node.xml`, `doc/classes/float.xml`, `doc/classes/Vector2.xml`, `modules/gdscript/doc_classes/@GDScript.xml` |
| **Post-Cutoff APIs Used** | `@abstract` class and method annotation (4.5); the 4.7 rule that an override of a typed-return method inherits that return type |
| **Verification Required** | (1) The headless sim test (below) passes under `godot --headless` on 4.7.2. (2) A `BattleReadModel` fake subclass parses on 4.7.2 with an explicit `return` in every override. (3) A retired battle is released (reference-count test below). |

### Sourced engine facts

| Claim | Source |
|---|---|
| `RefCounted` objects are released automatically when no longer referenced and need no `free()` | doc/classes/RefCounted.xml@4.7.2-stable, class description |
| `RefCounted` instances in a reference cycle are not freed automatically; `weakref` breaks the cycle | doc/classes/RefCounted.xml@4.7.2-stable, class description; doc/classes/@GlobalScope.xml@4.7.2-stable, `weakref` |
| `_process`, `_physics_process` and `_input` are only called when the node is in the scene tree | doc/classes/Node.xml@4.7.2-stable, `_process`, `_physics_process`, `_input` (Note: "only called if the node is present in the scene tree") |
| `Object.free()` deletes the object at once; existing references become invalid | doc/classes/Object.xml@4.7.2-stable, `free` |
| An abstract class cannot be instantiated; an abstract method has no body; a subclass must implement every abstract method or be abstract itself | modules/gdscript/doc_classes/@GDScript.xml@4.7.2-stable, `@abstract` |
| GDScript `float` is 64-bit; `Vector2` uses 32-bit floats unless the engine is built with `precision=double` | doc/classes/float.xml@4.7.2-stable, class description; doc/classes/Vector2.xml@4.7.2-stable, class description |
| An override of a typed-return method inherits that type and needs an explicit `return` (4.7) | `docs/engine-reference/godot/breaking-changes.md`, 4.6 to 4.7, GDScript row |
| Writing one element of a packed array no longer calls the property setter (4.7) | `docs/engine-reference/godot/breaking-changes.md`, 4.6 to 4.7, GDScript row |

### NOT SOURCEABLE (blocks Acceptance)

- NOT SOURCEABLE: whether a signal connection to a `Callable` on a `RefCounted` target holds a strong reference to that target, and so whether builder-made connections between sim modules form a reference cycle that keeps a retired battle alive; needs a device run (the reference-count test in Validation Criteria, run on 4.7.2).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002, ADR-0003, ADR-0004, ADR-0005, and every later ADR that places a module in sim or shell |
| **Blocks** | Every epic and story that writes gameplay code; the bot harness (ADR-0013) |
| **Ordering Note** | Written first; ADR-0002 builds on the Composition tier and the builders named here |

## Context

### Problem Statement

The design asks for one simulation driven three ways: by a player on a phone, by unit tests, and by scripted bots that measure balance headless. If any gameplay module reaches the scene tree, a renderer or a real clock, the bots and tests cannot run it, and the split decays one shortcut at a time. This decision must exist before any gameplay code is written, because every file's base class depends on it.

### Current State

No code exists. `architecture.md` version 2 states the split as its first principle and names this ADR to fix it.

### Constraints

- Godot 4.7.2, typed GDScript only, single thread.
- No autoloads (Flow Rule 2; TR-flow-001, owned by ADR-0002).
- Unit tests must not touch file I/O (coding standards), so file access needs an injected seam.
- 4.7 typed-return override rule applies to every subclass of a typed base, including test fakes.

### Requirements

- The sim loads and runs with no `SceneTree`, node, renderer or real clock (TR-hud-010).
- The `InputResolver` is built only by the shell; bots call commands on `Battle` (TR-input-005).
- The shell reads through one interface that tests can fake.
- Tests can enumerate a battle's systems, inject recording systems, and take a snapshot.

## Decision

Every module is either **sim** or **shell**, and the boundary is enforced by a test, not by convention.

1. **Sim** modules extend `RefCounted` (or a plain class derived from it). They hold no `Node`, `Control`, `CanvasItem`, `SceneTree`, `Engine` timing, `Time`, `OS` or `FileAccess` reference. They are: Catalogue, CatalogueValidator, SimTime, HaltState, BattleReadModel, the shared types, FlowSim, Combat, EnemyWave, TowerSim, HeroSim, ChipWindow, PinGeometry, AimModel, HudLogic, HudArcModel, FixedStepClock, InputResolver, BattleBuilder and Battle.
2. **Shell** modules are nodes and Controls: AppRoot, ShellBuilder's products, InputAdapter, BattleWrapper, TowerInput, HeroInput, HUD nodes, views, FatalScreen, HumanLog and GestureLog. They read sim state through `BattleReadModel` and change it only through `Battle` commands.
3. **Composition tier.** AppRoot, BattleBuilder and ShellBuilder sit above Presentation. Only they reference every layer. They wire; a branch on a gameplay value inside a builder is a defect.
4. **Dependency direction.** Sim never names a shell class. Shell never writes sim fields.
5. **`HaltState`** is a Foundation `RefCounted` written only by FlowSim and Battle and injected into every system by BattleBuilder; no system reads FlowSim for these flags.
6. **`BattleReadModel`** is an `@abstract` `RefCounted`. `Battle` implements it; tests subclass it as fakes. Every override declares the same return type and ends in an explicit `return`.
7. **File seams.** `TextSource` and `LineWriter` are `RefCounted` interfaces. Only their real implementations call `FileAccess`, and those live in the shell. Tests pass in-memory ones.
8. **Precision.** Gameplay math that needs exact compares uses scalar `float` (64-bit). `Vector2` (32-bit by default) is used for positions passed across the boundary and converted once at the end of a computation.
9. **The headless test.** One gdUnit4 suite builds a full battle from a fixture catalogue through `BattleBuilder`, ticks it, issues every command, and asserts the run used no node. A second check greps sim files for banned names (Implementation Guidelines).

### Architecture Diagram

```
  COMPOSITION   AppRoot (Node)   BattleBuilder (RefCounted)   ShellBuilder (RefCounted, makes nodes)
  -------------------------------------------------------------------------------------------
  SHELL (nodes)           |  reads BattleReadModel           |  commands on Battle
  InputAdapter, BattleWrapper, TowerInput, HeroInput, HUD nodes, views, logs
  -------------------------------------------------------------------------------------------
  SIM (RefCounted, headless)
  Battle : BattleReadModel ── FlowSim, EnemyWave, TowerSim, HeroSim, Combat
  HaltState, SimTime, Catalogue, shared types, HudLogic, AimModel, InputResolver, FixedStepClock
  -------------------------------------------------------------------------------------------
  Tests and bots hold Battle only. No sim file names a shell class.
```

### Key Interfaces

```gdscript
@abstract class_name BattleReadModel extends RefCounted
@abstract func phase() -> int
@abstract func lives() -> int
@abstract func gold() -> int
@abstract func slot(i: int) -> SlotState
@abstract func roster() -> Array[EnemyState]
# remaining reads as listed in architecture.md, API Boundaries

class_name HaltState extends RefCounted
func halted() -> bool
func in_build() -> bool
func in_tick() -> bool

class_name TextSource extends RefCounted
func read_text(path: String) -> String

class_name LineWriter extends RefCounted
func write_line(line: String) -> bool

# Test seams on Battle (test use only; not called by the shell)
func systems() -> Array[RefCounted]      # every sim system the builder made, in tick order
func snapshot() -> Dictionary            # plain values only, for equality checks between runs
```

BattleBuilder accepts optional replacement systems for tests (a recording system in place of a real one) through its build options; the exact parameter is fixed by ADR-0002.

### Implementation Guidelines

- Sim classes must extend `RefCounted` and must never extend `Node` or any `Node` subclass.
- Sim files must never contain `Node`, `Control`, `CanvasItem`, `get_tree`, `SceneTree`, `Engine.`, `Time.`, `OS.`, `FileAccess`, `await`, `Timer` or `_process`.
- Shell modules must never assign a sim field; they call a `Battle` command or nothing.
- Every `class_name` must live in its own file.
- Every variable, parameter, return and signal must be typed; arrays must be typed `Array[T]`.
- Every override of a typed-return method must declare the same return type and end in an explicit `return`.
- Exact geometric compares must use scalar `float`, never `Vector2` components compared after arithmetic.
- `FileAccess` must appear only in the real `TextSource` and `LineWriter`.
- Builders must never branch on a gameplay value.
- Sim modules must never call `free()`; they are released by reference count.

## Alternatives Considered

### Alternative 1: Scene-owned battle root (nodes for every system)
- **Description**: Each system is a node under a battle scene and ticks in `_process`.
- **Pros**: Idiomatic for small Godot games; inspector editing.
- **Cons**: `_process` runs only for nodes in the tree (Node.xml, `_process`), so headless bots need a running `SceneTree`; tests must build scenes.
- **Estimated Effort**: Lower at first, higher once bots exist.
- **Rejection Reason**: Breaks Flow Rule 2 and the bot requirement.

### Alternative 2: Split by convention only
- **Description**: Same split, enforced by review.
- **Pros**: No test to write.
- **Cons**: Decays silently.
- **Estimated Effort**: Slightly lower.
- **Rejection Reason**: architecture.md rejects it; this ADR adds the test.

### Alternative 3: Autoload event bus and singletons
- **Description**: Global autoloads hold state and route signals.
- **Pros**: Easy access from anywhere.
- **Cons**: Unconnected signals fail silently; tests cannot isolate systems; autoloads are nodes.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Rejected by the Flow GDD ("Deliberately not built") and TR-data-006.

## Consequences

### Positive
- One sim serves phone, tests and bots.
- Unit tests run with no file I/O and no scene.
- Fakes of `BattleReadModel` make HUD logic testable.

### Negative
- More plain classes and an explicit builder instead of scene wiring.
- No inspector editing of gameplay objects.
- Every fake must follow the 4.7 explicit-return rule.

### Neutral
- Shell nodes stay thin; most logic sits in plain classes.

## Risks

- **A retired battle leaks through a reference cycle.** `RefCounted` cycles are not freed (RefCounted.xml). Mitigation: the reference-count test below; break cycles with `weakref` if it fails.
- **Float results differ by CPU.** Covered by ADR-0003 (per-architecture baselines).
- **A sim file gains a shell name.** Mitigation: the banned-name check runs in CI.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-005 (provisional): resolver built only by the ShellBuilder; bots call commands on `Battle`; one equivalence test | InputResolver is sim code but built only in the shell; bots hold only `Battle` |
| battle-hud.md | TR-hud-010 (provisional): the HUD is absent headless; nothing in the battle depends on it | HUD nodes are shell; HudLogic reads only `BattleReadModel`; the headless test runs with no HUD |
| game-state-stage-flow.md | Flow Rules 2 to 4 (headless battle, builders, no physics areas), as cited in architecture.md | Sim is `RefCounted`; builders wire it; no node or area in the sim |

## Performance Implications
- **CPU**: Negligible; plain method calls replace node callbacks.
- **Memory**: Lower than nodes per system.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

No code exists. New code follows this from the first story.

**Rollback plan**: Moving a sim module into a node is local, but would break the headless test; supersede this ADR first.

## Validation Criteria

- The headless sim suite passes under the CI command in coding-standards.md.
- The banned-name check finds nothing in sim files.
- After Retry, a `weakref` to the old `Battle` returns `null` once the root drops it (reference-count test).
- A `BattleReadModel` fake parses and runs on 4.7.2.

## Related

- `docs/architecture/architecture.md` (System Layer Map, Module Ownership, API Boundaries, Architecture Principles 1 and 5)
- ADR-0002 (composition and lifecycle), ADR-0003 (time and determinism)
- `design/gdd/game-state-stage-flow.md`, `design/gdd/input-gesture-resolver.md`, `design/gdd/battle-hud.md`
