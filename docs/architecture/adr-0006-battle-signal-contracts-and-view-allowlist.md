# ADR-0006: Battle Signal Contracts and View Allowlist

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories that reference this ADR stay `Blocked` while it is `Proposed`.

TD-ADR: batch review 2026-11-04, CONCERNS; fixes applied.

## Date

2026-11-04

## Last Verified

2026-11-04 (against the Godot 4.7.2 class reference, tag `4.7.2-stable`, and `docs/engine-reference/godot/`)

## Decision Makers

GDScript specialist (author, orchestrated run against `docs/architecture/architecture.md` v3). Pending: technical-director batch review and user acceptance.

## Summary

Battle systems tell each other and the views what happened through synchronous typed signals, and the master architecture left the final names, payload types, ID type and the view allowlist open (QQ-04, QQ-07). This ADR fixes every battle signal, its payload and its emit order, renames the five signals that broke the past-tense rule, types IDs as `StringName`, and specifies the wiring test with its view allowlist.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting, signals) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM (architecture table; signal behaviour is stable since 4.0 per `breaking-changes.md`, but several details are not in the pinned reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; Godot 4.7.2 class reference fetched from `raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/`: `Signal.xml`, `Object.xml`, `RefCounted.xml`, `@GlobalScope.xml` |
| **Post-Cutoff APIs Used** | None. The 4.7 rule that a typed-return override needs an explicit `return` applies to the recording fakes in ADR-0007 |
| **Verification Required** | The NOT SOURCEABLE items below, run headless on the desktop editor before the wiring-test story, and item 5 from ADR-0001's export probe |

### Sourced from the 4.7.2 class reference

- `Signal.emit` "emits this signal. All Callables connected to this signal will be triggered" and takes a variable number of arguments (`Signal.xml`).
- `Signal.get_connections` returns an array of dictionaries with `signal`, `callable` and `flags` (`Signal.xml`).
- A signal connects once to the same `Callable`; a second connect returns `ERR_INVALID_PARAMETER` and raises an error unless `CONNECT_REFERENCE_COUNTED` is set. If the callable's object is freed, the connection is lost (`Object.xml`, `Signal.xml`).
- `CONNECT_DEFERRED` and `CONNECT_ONE_SHOT` exist (`Object.xml`). Deferred calls run at idle time, at the end of the process or physics frame (`Object.xml`), so a deferred battle connection would run after every tick of that frame.
- `RefCounted` instances caught in a cycle are not freed automatically (`RefCounted.xml`); `get_reference_count()` exists.
- `@GlobalScope.is_finite(x)` and `push_error` exist (`@GlobalScope.xml`).

### NOT SOURCEABLE (blocks Acceptance)

Each item is not covered by `docs/engine-reference/godot/` or by the class reference text above. Until its run is logged in `production/qa/evidence/`, this ADR cannot move to Accepted.

1. NOT SOURCEABLE: the order in which one signal calls its listeners. `Signal.xml` and `Object.xml` do not state it. Run: headless 4.7.2 desktop test that connects three listeners to one signal and records the call order. The decision never relies on the result, so a failure changes only the test text.
2. NOT SOURCEABLE: whether an enum-typed signal parameter (`value: Flow.Phase`) is enforced at `emit()` or at `connect`. `Signal.xml` says only that arguments are passed. Run: headless test that emits an out-of-range int and a wrong type, once per declared type. The recording fakes assert payloads whatever the result is.
3. NOT SOURCEABLE: whether `Object.get_signal_list()` lists script-declared signals on a `RefCounted`. `Object.xml` says only "the list of existing signals". Run: headless test on a `RefCounted` subclass with two declared signals, before the wiring-test story. Fallback if it does not: each class declares a `const SIGNAL_NAMES: Array[StringName]` that the test cross-checks against a source scan.
4. NOT SOURCEABLE: what happens when a listener connects or disconnects the same signal during an emit. Run: headless test. The decision avoids it (Builder connects once, before any tick), so the run only confirms the avoidance is enough.
5. NOT SOURCEABLE: that a connection to a `RefCounted` listener neither keeps it alive nor leaves a callable that errors when the listener is gone. The editor probe in architecture QQ-17 saw both on 4.7.2; `Object.xml` states only the freed-object case. Run: none here. ADR-0001 owns the probe (QQ-17), on a desktop export and an Android export; this ADR cites its result for rule 9.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 App Lifecycle, Composition Root and Fatal Path (Builder, FatalLatch, method-Callable-only rule, retry by dropping references); ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism (the tick order that signals fire inside; commands run between ticks) |
| **Enables** | ADR-0007 (recording fakes and the listener-count test), ADR-0008 (resolver signal names), ADR-0009 (Combat signals use `Combat.SourceKind` and `DamageEvent`, which ADR-0009 declares), ADR-0010, ADR-0011 |
| **Blocks** | Stories for Flow, EnemyWave, TowerSim, HeroSim and Combat signals; the wiring-test story; every HUD story that listens |
| **Ordering Note** | ADR-0009 owns the `DamageEvent` and `Combat.SourceKind` types named in two payloads. This ADR fixes only how they travel. ADR-0008 applies the same naming rule to the resolver signals. |

## Context

### Problem Statement

Signals fire inside loops that walk the roster (advance, leak, reap). If a listener changed the roster or spent gold from inside such a loop, state would change under the loop. The GDDs also require that an unconnected signal is a test failure, that leak and clear events keep a fixed order, and that views never affect the result. Five signal names break the past-tense rule (QQ-07), and the type of `tower_id` across signals is open (QQ-04). One written contract must exist before the first system is coded.

### Constraints

- One thread. Signals are synchronous when connected without `CONNECT_DEFERRED`.
- No autoload and no event bus (Principle 2). Only the Builder connects the signals the sim consumes (Data Flow 3, rule 3).
- GDScript has no exceptions. A function keeps running after a fatal unless it checks `halted()`.
- A frame can run several ticks, so an end-of-frame connection would see only the last tick's state.
- Injected callables are method Callables only: no lambda or `bind()` that captures a sim object (ADR-0001, B4).

### Requirements

- Typed parameters and past-tense `snake_case` names (TR-data-014, TR-tower-012).
- Commit state, then emit (TR-tower-004, TR-hero-008, TR-combat-010).
- Leak before clear, spawn_id order, no `CONNECT_DEFERRED` (TR-enemy-004, TR-state-008).
- A battle with every view listener removed gives identical state (TR-tower-012, TR-hud-004, TR-combat-010).
- The HUD reads through signals and view-only queries (TR-hud-010) and builds the result snapshot outside the signal stack (TR-hud-012).

## Decision

### 1. The battle signal table

Each signal is declared on its owner (a `RefCounted` sim class). `Battle` never re-emits one. The data store emits none (TR-data-014): each emitter declares its own and the Builder wires them.

| Signal | Owner | Payload | Gameplay listener (Builder connects) | On view allowlist |
|---|---|---|---|---|
| `enemy_leaked` | EnemyWave | `lives_cost: int` | Flow | no |
| `enemy_killed` | EnemyWave | `bounty: int` | TowerSim (gold) | no |
| `wave_cleared` | EnemyWave | `intermission_duration: float` | Flow | no |
| `waves_completed` | EnemyWave | none | Flow | no |
| `wave_called_early` | Flow | `seconds_left: float` | TowerSim | no |
| `phase_changed` | Flow | `value: Flow.Phase` | TowerSim (chip) | yes |
| `lives_changed` | Flow | `current: int` | none | yes |
| `gold_changed` | TowerSim | `current: int` | none | yes |
| `tower_built` | TowerSim | `slot_index: int, tower_id: StringName` | none | yes |
| `tower_upgraded` | TowerSim | `slot_index: int, level: int` | none | yes |
| `hero_pinned` | HeroSim | `position: Vector2` | none | yes |
| `burst_started` | HeroSim | `aim_point: Vector2, telegraph_ticks: int` | none | yes |
| `attack_fired` | Combat | `source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float` | none | yes |
| `damage_applied` | Combat | `event: DamageEvent, applied: float, position: Vector2, killed: bool, spawn_id: int` | none | yes |

Payload and name rules:

- **QQ-07 is closed here.** `waves_complete` becomes `waves_completed`. `phase` is already `phase_changed`. The four resolver names are settled in ADR-0008.
- **QQ-04 is closed here.** Every ID in a signal is a `StringName` (`tower_id`, `source_id`). Slot positions are `int` indices. The B0 default holds.
- Payload `Vector2` values are copies. `attack_fired` and `damage_applied` carry positions copied at emit time, so a view never holds a reference into the roster (TR-combat-010).
- A payload object (`DamageEvent`) is read-only by convention: a listener must not store or change it after its call returns.
- An enum-typed parameter is declared with its enum type, as in B5. Whether the engine enforces it is NOT SOURCEABLE item 2, so tests assert the payload.
- Combat's two signals carry what the Combat GDD lists (`killed`, `spawn_id` are extra to the architecture's short form). The architecture and the GDD agree on the rest.
- TowerInput's `slot_tapped(slot_index: int)` and `tower_inspected(slot_index: int)` live on a shell object that `Battle` does not hold. They are outside the battle wiring test (TR-tower-012 covers their typing; ADR-0007 tests them with the HUD fakes).

### 2. Emit rules

1. **Commit, then emit.** State is final before the first listener runs (TR-tower-004, TR-hero-008).
2. **Fixed order where the GDDs fix it.**
   - `enemy_leaked` fires in `spawn_id` order, before `wave_cleared` or `waves_completed` (TR-enemy-004, TR-state-008).
   - A fatal leak ends the tick before any kill: no bounty is paid after it and `waves_completed` is never emitted.
   - `gold_changed` fires before `tower_built` or `tower_upgraded`.
   - A refused command emits nothing (TR-tower-004).
   - Flow follows its Rule 15 order: set state, act, then emit in order.
3. **Halt check after every emit.** After each emit that can latch a fatal or an outcome, the emitting loop reads `halted()` and returns at once if true. Flow stops its emit sequence if Fatal latched during an emit (B5).
4. **No order among listeners of one signal is assumed.** NOT SOURCEABLE item 1. Every gameplay listener must give the same result whatever runs first, and a view listener must not depend on the gameplay listener having run. Gameplay listeners per signal are listed in section 1, and the wiring test fixes their exact number.
5. **Wiring signals** (the rows with a gameplay listener) are connected only in `BattleBuilder.build`, in one function, once per pair, with `Signal.connect(callable)` and no flags. They are never deferred (TR-enemy-004).
6. **No `CONNECT_DEFERRED`, no `CONNECT_ONE_SHOT`, no `CONNECT_REFERENCE_COUNTED`, no editor connections** for battle signals. The sourced deferred timing (end of frame) breaks per-tick state.
7. **Heavy work stays out of the signal stack.** A listener records what happened in a field and returns. The result screen and log snapshot is built on the first `advance(ms)` after the outcome, never inside `phase_changed`, and not at all if `phase()` is Fatal (TR-hud-012).
8. **No battle listener issues a command.** Handlers of `hero_pinned`, `burst_started`, `attack_fired`, `damage_applied` and every other row change only their own system and never call a Flow, TowerSim or HeroSim command or `Combat.deliver`. Commands run between ticks, from the input call stack (ADR-0004). Battle has no in-tick guard in B4, so a test and the layer lint (ADR-0007) enforce this rule (see Risks).
9. **Listeners are held by their owners, not by connections.** Signal connections do not own listeners. Every listener has a strong holder in `Battle` (Flow Rule 2a, QQ-17). A listener that is freed has its connection removed (`Object.xml`). Retry drops the `Battle`; the weakref proof is ADR-0001's, and this ADR adds that wiring makes no extra owner. Item 5 above confirms this on an export.

### 3. View allowlist

The allowlist is one `const VIEW_ALLOWLIST: Array[StringName]` in the wiring test file. It holds every signal that may have zero connections in a headless build with no views: `phase_changed`, `lives_changed`, `gold_changed`, `tower_built`, `tower_upgraded`, `hero_pinned`, `burst_started`, `attack_fired`, `damage_applied`. `phase_changed` is also wired to TowerSim by the Builder, so its entry matters only when TowerSim's chip listener is absent. TR-hud-010 names `phase_changed` and `lives_changed` as allowlist members, and this list keeps both.

Adding a signal to the battle means adding a row in section 1 and either a Builder connection or an allowlist entry in the same change.

### 4. Wiring test (TR-state-013, built in ADR-0007)

The test runs headless on a battle from `BattleBuilder.build`. It does four checks:

1. For each system held by `Battle`, list signals with `get_signal_list()` (NOT SOURCEABLE item 3), drop those a bare `RefCounted` also lists, and fail on any signal with an empty `get_connections()` that is not on `VIEW_ALLOWLIST`.
2. Fail if an allowlist entry names a signal that does not exist.
3. For every signal with a gameplay listener in section 1, fail unless the connection count equals the number listed (one now, so a second listener must update this ADR).
4. Fail if any connection carries a flag.

A second test runs one scripted battle with and without recording view listeners and asserts identical final state and identical `StageResult` (TR-tower-012, TR-hud-004, TR-combat-010).

### Architecture Diagram

```
 EnemyWave --enemy_killed---------> TowerSim.on_enemy_killed
           --enemy_leaked---------> Flow.on_enemy_leaked ---> latch outcome --> emitter sees halted()
           --wave_cleared---------> Flow.on_wave_cleared
           --waves_completed------> Flow.on_waves_completed
 Flow      --wave_called_early----> TowerSim.on_wave_called_early
           --phase_changed--------> TowerSim (chip) + views (allowlist)
 Flow, TowerSim, HeroSim, Combat --view signals--> HUD, field views, audio (allowlist, record only)

 Input call stack --> command (between ticks) --> owner --> commit --> signals (sync)
```

### Key Interfaces

```gdscript
# EnemyWave
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_completed()
# Flow
signal phase_changed(value: Phase)
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
# TowerSim
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)
signal tower_upgraded(slot_index: int, level: int)
# HeroSim
signal hero_pinned(position: Vector2)
signal burst_started(aim_point: Vector2, telegraph_ticks: int)
# Combat
signal attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(event: DamageEvent, applied: float, position: Vector2, killed: bool, spawn_id: int)
```

`Flow.phase_changed` uses the enum `Flow.Phase` from B5. A recording fake in ADR-0007 stores each payload and asserts its `typeof` and range.

### Implementation Guidelines

- A signal must declare typed parameters, use a past-tense name, and appear in section 1.
- A system must commit state before it emits.
- An emit loop must check `halted()` after each emit that can latch an outcome, and must return when it is true.
- `BattleBuilder` must make every battle connection, in one function, with plain `connect(callable)`.
- Battle code must never use `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT`, `CONNECT_REFERENCE_COUNTED`, `await` on a battle signal, or a string-based `connect`.
- A connected target must be a method `Callable` on an object that `Battle` holds. A lambda or `bind()` that captures a sim object is forbidden.
- A listener must never call a command, `Combat.deliver`, or `Battle.tick`.
- A listener must never store a payload object past its call, and must never mutate it.
- Gameplay must never read state a view listener wrote.
- A heavy snapshot must never be built inside a listener.
- Every refusal must have a test that proves no state changed and no signal fired.

## Alternatives Considered

### Alternative 1: A global event bus autoload

- **Description**: One `EventBus` node re-emits every battle event.
- **Pros**: Any code can listen with no wiring.
- **Cons**: Breaks Principle 2 (no autoload) and headless isolation; one bus is shared by two battles on retry; wiring becomes invisible to the test.
- **Estimated Effort**: Low
- **Rejection Reason**: The Flow GDD rejects it and the architecture bans autoloads.

### Alternative 2: Deferred connections for views

- **Description**: Views connect with `CONNECT_DEFERRED` so they never run inside a tick.
- **Pros**: A view cannot disturb a loop.
- **Cons**: Deferred calls run at the end of the frame (`Object.xml`), and a frame can hold several ticks, so a view sees a later state than the payload describes and per-tick order is lost.
- **Estimated Effort**: Low
- **Rejection Reason**: Listeners that only record state give the same safety with known timing.

### Alternative 3: Keep `tap`-style names and record an exception

- **Description**: Document the present-tense GDD names as an exception to the naming rule.
- **Pros**: No GDD edit, tests already use the names.
- **Cons**: The exception list grows with each new signal and lint cannot tell a deliberate name from a slip.
- **Estimated Effort**: Low now, higher later
- **Rejection Reason**: Five renames cost less than a standing exception. No test uses the new names yet.

## Consequences

### Positive

- A listener cannot change the roster under a loop, because no listener issues a command.
- A forgotten connection fails a test, and so does a stray one.
- Payload types and ID types are fixed once, so recording fakes can assert them.
- The result is identical with or without views, and a test shows it.

### Negative

- `waves_complete` must change in `enemy-wave.md`, `game-state-stage-flow.md` and `data-config-pipeline.md`, and in the registry text of TR-state-008 (see GDD Sync).
- The wiring test depends on `get_signal_list()` behaviour that is not sourced (item 3), with a source-scan fallback.
- Command-in-listener is caught by test and lint, not at runtime.

### Neutral

- `tower_id` stays `StringName` as the working default in B0.
- `slot_tapped` and `tower_inspected` stay outside the battle test.

## Risks

- **A listener starts issuing commands.** Mitigation: rule 8, the layer lint in ADR-0007, and a test that calls each command from inside each recording listener and asserts no state change beyond the owner's own.
- **Listener order assumed by accident.** Mitigation: rule 4; the test fixes the gameplay connection count; item 1 gives the real order for review.
- **Enum-typed parameter is not enforced.** Mitigation: recording fakes assert type and range.
- **A connection to a dropped listener errors at runtime (QQ-17).** Mitigation: strong holders in `Battle`; item 5 on an export template.
- **The allowlist hides a signal that should have a listener.** Mitigation: check 3 fixes the gameplay count, and the allowlist is a single reviewed constant.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-014: the data store emits no signals; each emitter declares its own and the composition root wires them | Section 1 intro and emit rule 5 |
| game-state-stage-flow.md | TR-state-008: Flow listens to synchronous `wave_cleared`, `waves_complete` and `enemy_leaked` (leak before complete) and emits `lives_changed`, `phase_changed`, `wave_called_early` | Section 1 table with `waves_completed`; emit rules 2, 3 and 5 |
| combat-damage.md | TR-combat-010: view-only `attack_fired` and `damage_applied` emit after commit with copied positions; listeners never call `deliver`; same results with or without listeners | Payload rules, emit rules 1 and 8, the with/without-views test |
| enemy-wave.md | TR-enemy-004: kill, leak, clear and complete signals fire synchronously in `spawn_id` order after commit; leaks before the clear | Emit rules 1, 2, 5 and 6 |
| tower-system.md | TR-tower-004: atomic commit, `gold_changed` then `tower_built` or `tower_upgraded`, a refusal emits nothing | Emit rule 2, refusal test |
| tower-system.md | TR-tower-012: typed signatures (`tower_id` decided), results match with or without listeners | `StringName` decision, section 1 types, the with/without-views test |
| hero-system.md | TR-hero-008: `hero_pinned` and `burst_started` emit after state is set, on the view allowlist, handlers never issue commands | Section 3 allowlist, emit rules 1 and 8 |
| battle-hud.md | TR-hud-004: the HUD holds presentation state only; sim state is identical with or without it | With/without-views test, allowlist, rule 8 |
| battle-hud.md | TR-hud-010: the HUD reads through signals and view-only queries; `phase_changed` and `lives_changed` join the allowlist | Section 1 and 3 |
| battle-hud.md | TR-hud-012: the result snapshot is built on the first advance after the outcome, never inside the signal stack, and not at Fatal | Emit rule 7 |

**GDD sync required.** These GDD and registry texts use a name this ADR renames:

```
GDD SYNC REQUIRED
enemy-wave.md, game-state-stage-flow.md, data-config-pipeline.md:
  waves_complete -> waves_completed
tr-registry.yaml TR-state-008 text:
  "emits lives_changed, phase and wave_called_early" -> phase_changed;  waves_complete -> waves_completed
architecture.md Data Flow 3 and Open Question QQ-07:
  waves_complete -> waves_completed;  QQ-04 and QQ-07 close in this ADR
```

This run does not edit those files.

## Performance Implications

- **CPU**: A synchronous signal with one listener is one call. A tick emits a handful of signals. Per-emit cost is not sourced and is not claimed. Profile before changing the design.
- **Memory**: One `DamageEvent` per hit (ADR-0009). Copied `Vector2` payloads are values.
- **Load Time**: Negligible. Six gameplay connections are made at build (section 1).
- **Network**: None.

## Migration Plan

No code exists. The Builder (ADR-0001) writes the wiring function. The wiring test and the recording fakes land in ADR-0007's first story, before any system adds a second signal.

**Rollback plan**: If NOT SOURCEABLE item 3 fails and the fallback proves heavy, replace the signal-list check with the `SIGNAL_NAMES` constant plus a source scan and record the change in a superseding ADR.

## Validation Criteria

- The wiring test fails when a Builder connection is deleted, when an allowlist entry is misspelt, and when a flag is added.
- The with/without-views test gives identical `StageResult` and sim state for one scripted battle.
- A scripted fatal leak pays no bounty and emits no `waves_completed`.
- Recording fakes pass for every row: payload count, type and range.
- Each NOT SOURCEABLE run is logged in `production/qa/evidence/` with the 4.7.2 build string.

## Related

- `docs/architecture/architecture.md` (Data Flow 3, B5, B10, QQ-04, QQ-07, QQ-17)
- `design/gdd/game-state-stage-flow.md`, `design/gdd/enemy-wave.md`, `design/gdd/combat-damage.md`, `design/gdd/tower-system.md`, `design/gdd/hero-system.md`, `design/gdd/battle-hud.md`, `design/gdd/data-config-pipeline.md`
- ADR-0001, ADR-0004 (depend on); ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011 (enabled)
- GDD sync: 7 referenced GDD(s) checked by name; the one renamed signal (`waves_complete`) appears in three of them, listed above.
