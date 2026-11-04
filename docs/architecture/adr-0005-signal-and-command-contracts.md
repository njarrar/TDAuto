# ADR-0005: Signal and Command Contracts

## Status

Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. No other agent, and no skill on its own.

TD-ADR: not run per ADR; batch review after all ADRs are written.
Engine validation (godot-specialist): not run per ADR; batch review after all ADRs are written.

## Date

2026-11-04

## Last Verified

2026-11-04 (against the Godot 4.7.2 class reference, tag `4.7.2-stable`, and `docs/engine-reference/godot/`)

## Decision Makers

Authored in an autonomous run against `docs/architecture/architecture.md` (version 2). Open for the user and `technical-director` to accept or change.

## Summary

Battle systems talk to each other through synchronous typed signals, and the shell talks to the battle through commands on `Battle`, and the architecture left the re-entrancy rule open (QQ-10). This ADR fixes every battle signal, its payload and its emit order, confirms the rule that no battle listener calls a command and a command during `in_tick()` is refused, and specifies the wiring test and its allowlist.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting, signals) |
| **Layer** | Foundation (the architecture lists this ADR with the Foundation group; it constrains FlowSim, Combat, EnemyWave, TowerSim and HeroSim) |
| **Knowledge Risk** | HIGH (GDScript is HIGH in `VERSION.md`) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; Godot 4.7.2 class reference: `Signal.xml`, `Object.xml`, `RefCounted.xml`, `Callable.xml` (fetched, not quoted), `@GlobalScope.xml`, `@GDScript.xml` |
| **Post-Cutoff APIs Used** | None. The 4.7 rule that a typed-return override needs an explicit `return` applies to `Battle` and every `BattleReadModel` fake |
| **Verification Required** | (1) Order in which one signal calls its listeners. (2) Whether `Object.get_signal_list()` lists script-declared signals on a `RefCounted`. (3) Whether an enum-typed signal parameter is enforced. (4) What happens when a listener connects or disconnects during an emit. (5) Reference counts drop to zero after `Battle.dispose()` |

### NOT SOURCEABLE (blocks Acceptance)

- Whether one signal calls its listeners in connection order (`Signal.xml`, `Object.xml` do not say). Run: headless desktop test on 4.7.2; the decision already avoids relying on it, so a failure changes only the test.
- Whether enum-typed signal parameters are enforced. Run: headless desktop test. Payloads are typed `int` either way.
- Whether `Object.get_signal_list()` on a `RefCounted` includes script-declared signals, which the wiring test needs. Run: headless desktop test before the wiring-test story.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary (`HaltState`, plain-object rule, test seam that enumerates a battle's systems); ADR-0002 App Lifecycle and Composition (`BattleBuilder`, teardown); ADR-0003 Fixed Tick, Time and Determinism (tick order) |
| **Enables** | ADR-0007 Combat Data Model, ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0013 |
| **Blocks** | Stories for FlowSim, EnemyWave, TowerSim, HeroSim, Combat signals, the wiring test, and every HUD story that listens |
| **Ordering Note** | ADR-0002 owns `BattleBuilder`, which makes the connections this ADR specifies, and the teardown that calls `Battle.dispose()`. ADR-0003 owns the tick order that signals fire inside. |

## Context

### Problem Statement

Signals fire inside loops that walk the roster (advance, reap). If a listener changed the roster or spent gold from inside such a loop, state would change under the loop. The GDDs also require that an unconnected signal is a test failure, that leak and clear events keep a fixed order, and that views never affect gameplay. These need one written contract before the first system is coded.

### Current State

No ADR and no code exist. `architecture.md` Data Flow section 3 proposes a re-entrancy default and lists the events. Flow's GDD rejects a global event bus.

### Constraints

- Single thread. Signals are synchronous (`Object.xml`, `CONNECT_DEFERRED`: deferred connections run "at the end of the frame, rather than instantly", so a plain connection runs at once).
- No autoload and no event bus (Principle 3); only `BattleBuilder` connects (dependency rule 4).
- GDScript has no exceptions; a function keeps running after a fatal unless it checks `halted()`.
- Several ticks can run in one frame, so a deferred (end-of-frame) connection would run after all of them.

### Requirements

- Typed payloads, past-tense snake_case names.
- Leak before `waves_complete`; a fatal leak beats a clear (TR-flow-006).
- Wiring test that fails on a signal with no listener unless allowlisted (TR-flow-010).
- `attack_fired` and `damage_applied` carry copied positions and feed views only (TR-combat-006).
- Synchronous emit with `halted()` checks after every emit (TR-wave-003, TR-wave-005).

## Decision

### 1. Battle signal table (the contract)

All signals are declared on the owning plain `RefCounted` class and are never re-emitted by `Battle`. Payloads are value types or immutable-by-convention objects. A payload that holds an enum value is typed `int`; NOT SOURCEABLE: whether GDScript enforces an enum type on a signal parameter (`Signal.xml` says only that declared arguments must be passed on emit), so `int` stays the rule, as in `architecture.md`.

| Signal | Owner | Payload | Gameplay listener (wired by BattleBuilder) | View allowlist |
|---|---|---|---|---|
| `enemy_killed` | EnemyWave | `bounty: int` | TowerSim `on_enemy_killed` | no |
| `enemy_leaked` | EnemyWave | `lives_cost: int` | FlowSim `on_enemy_leaked` | no |
| `wave_cleared` | EnemyWave | `intermission_duration: float` | FlowSim `on_wave_cleared` | no |
| `waves_complete` | EnemyWave | none | FlowSim `on_waves_complete` | no |
| `wave_called_early` | FlowSim | `seconds_left: float` | TowerSim `on_wave_called_early` | no |
| `phase_changed` | FlowSim | `p: int` (a `FlowSim.Phase`) | none | yes |
| `lives_changed` | FlowSim | `current: int` | none | yes |
| `gold_changed` | TowerSim | `current: int` | none | yes |
| `tower_built` | TowerSim | `slot_index: int, tower_id: StringName` | none | yes |
| `tower_upgraded` | TowerSim | `slot_index: int, level: int` | none | yes |
| `hero_pinned` | HeroSim | `position: Vector2` | none | yes |
| `burst_started` | HeroSim | `aim_point: Vector2, telegraph_ticks: int` | none | yes |
| `attack_fired` | Combat | `source_kind: int, source_id: StringName, origin: Vector2, impact: Vector2, radius: float` | none | yes |
| `damage_applied` | Combat | `event: DamageEvent, applied: float, position: Vector2` | none | yes |

The master table calls the FlowSim signal `phase`; the FlowSim API in the same document, which this ADR follows, declares `phase_changed` (the method `phase()` already uses the short name). Resolver signals (`pressed`, `tap`, `drag_*`, `idle`) belong to ADR-0006; they are not battle signals and are outside the wiring test. TowerInput's `slot_tapped` and `tower_inspected` are shell-only signals (TR-tower-006) and are likewise outside it.

### 2. Emit rules

1. **Commit, then emit.** A system commits its state before it emits, so any reader called from a listener sees the new state.
2. **Fixed order where the GDDs fix it.** `enemy_leaked` fires synchronously in the leak step, before `waves_complete`. `wave_called_early` fires before `phase_changed(WAVE)` and before the first spawn, so the bonus is paid first. `phase_changed` and `lives_changed` fire after state is committed.
3. **Halt check after every emit.** After each emit and each accessor read, the emitting loop reads `HaltState.halted()` and returns at once if true. A fatal leak sets Lost inside `enemy_leaked`'s listener chain; the advance loop sees `halted()` and stops. No bounty is paid after it.
4. **No order among listeners of one signal.** NOT SOURCEABLE: the order in which one signal calls its listeners (`Signal.xml` and `Object.xml` do not state it). So every gameplay signal has exactly one gameplay listener, and view listeners must not depend on each other or on the gameplay listener having run.
5. **Disconnection.** `Object.xml` and `Signal.xml` say a connection is lost when the callable's object is freed, and connecting the same callable twice is an error unless `CONNECT_REFERENCE_COUNTED` is used. The builder connects each pair once and never uses reference-counted connections.
6. **No deferred connections in the battle.** `CONNECT_DEFERRED` is banned for battle wiring: it would run a handler after later ticks of the same frame. Shell listeners that need "next frame" behaviour record the event in a field and read it on the next frame (rule 7), and do not use deferred connection.

### 3. Re-entrancy (resolves QQ-10)

Confirmed as proposed in `architecture.md`:

- **No listener inside the battle may call a command.** The listeners of section 1 are `on_` handlers that change only their own system's state.
- **Shell listeners only record.** They store what they need for the next frame; they issue commands from the input call stack, which runs between ticks.
- **A command called while `in_tick()` is true is refused.** `Battle` checks `HaltState.in_tick()` first. The command changes nothing, emits nothing and reports a development error with `push_error` (`@GlobalScope.xml`: it does not pause the project). It returns the same refusal code as a halted battle: `false` for `start_wave`, `call_early`, `resume`; the owner's `HALTED` value for `build`, `upgrade`, `pin`, `burst`; `pause()` is a no-op.

Reusing `HALTED` is a choice, discussed under Alternatives. The refusal is also covered by a test that calls every command from inside a listener.

### 4. Commands

The command table in `architecture.md` ("Shell to sim commands") is adopted unchanged. Rules:

- Every command goes through `Battle`; `Battle` forwards to the owner.
- A refusal changes nothing and emits nothing; the result is a named value (TR-tower-002, TR-hero-002).
- Commands run between ticks. ADR-0002 and ADR-0003 verify that input callbacks run before the frame's ticks.
- `EnemyWave.start_next_wave()` is not a shell command; only FlowSim calls it through its injected `Callable`.

### 5. Wiring test and allowlist

The test runs headless on a built `Battle`. For each battle system it lists declared signals with `Object.get_signal_list()`, drops signals that a bare `Object` or `RefCounted` also lists, and for each remaining signal checks `Signal.get_connections()` is non-empty (`Signal.xml`: returns an array of dictionaries with `signal`, `callable`, `flags`). A signal with no connection must be on the view allowlist in section 1, held as one constant in the test file. The test also fails if an allowlist entry names a signal that does not exist, and if a gameplay-listened signal has more than one connection (rule 4 above). NOT SOURCEABLE: whether `get_signal_list()` includes script-declared signals on a `RefCounted`; `Object.xml` says only "the list of existing signals". If it does not, the fallback is a per-class `const SIGNALS` list asserted equal to the class's own declarations by a source scan.

### 6. Teardown breaks reference cycles

`RefCounted.xml` says objects in a reference cycle are not freed. `EnemyWave` signals connect to `FlowSim` handlers, and `FlowSim` holds a `Callable` bound to `EnemyWave`, which is a cycle. `Battle.dispose()` must disconnect every wiring connection, clear every injected `Callable`, and clear every held system reference. ADR-0002 calls it on retry and on exit. A test checks `RefCounted.get_reference_count()` reaches the expected floor after `dispose()` (`RefCounted.xml`).

### Architecture Diagram

```
 EnemyWave --enemy_killed--------> TowerSim.on_enemy_killed        (builder connects once)
           --enemy_leaked--------> FlowSim.on_enemy_leaked   --> HaltState (Lost) --> emitter sees halted()
           --wave_cleared/complete> FlowSim.on_wave_cleared / on_waves_complete
 FlowSim   --wave_called_early---> TowerSim.on_wave_called_early
 all view signals ---------------> shell listeners (record only; allowlisted)

 Shell input stack --> Battle.command() --[in_tick? refuse]--> owner --> signals (sync)
```

### Key Interfaces

The signal declarations are those in `architecture.md` API Boundaries with the names in section 1. The `Battle` command signatures are unchanged from `architecture.md`. New: `Battle.dispose() -> void`.

### Implementation Guidelines

- Signals must be declared with typed parameters. Enum values must be passed as `int`.
- An `on_` handler must change only its own system and must never call a `Battle` command.
- Systems must commit state before emit, and must check `halted()` after every emit and every accessor read.
- BattleBuilder must make every connection in one function, once per pair, with `Signal.connect(callable)`; no string-based `connect`, no deferred or one-shot flag, no editor connections.
- A listener must not store a payload object past its call unless it treats it as immutable.
- Nothing in gameplay may depend on a view-allowlist signal.
- Every refusal must be covered by a test that proves no state changed and no signal fired.

## Alternatives Considered

### Alternative 1: Queue commands issued during a tick and run them after
- **Description**: A command in `in_tick()` is stored and applied at the end of the tick.
- **Pros**: No refusal path for listeners.
- **Cons**: Hidden ordering; the caller already got a result code, so a queued command cannot return its real result; changes what a bot's script means.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Violates "commands return a result code between ticks" and hides bugs that refusal exposes.

### Alternative 2: Allow re-entrant commands and snapshot the roster in each loop
- **Description**: Advance and reap iterate a copy of the roster.
- **Pros**: Tolerates listener misuse.
- **Cons**: A copy per loop per tick; kills mid-iteration are still ambiguous; hides the defect.
- **Estimated Effort**: Medium.
- **Rejection Reason**: The roster rule ("never modified during the walk") is cheaper and stricter.

### Alternative 3: Deferred connections for shell listeners
- **Description**: Use `CONNECT_DEFERRED` so shell code runs at end of frame.
- **Pros**: Shell code never runs inside a tick.
- **Cons**: Several ticks can run in one frame, so handlers see only the final state and lose per-tick ordering; the exact timing relative to the frame hook is not sourced.
- **Estimated Effort**: Low.
- **Rejection Reason**: Recording state in a field gives the same safety with known timing.

### Alternative 4: A new `IN_TICK` value in each result enum
- **Description**: `TowerSim.Result`, `HeroSim.PinResult` and `BurstResult` each gain `IN_TICK`.
- **Pros**: Callers and tests tell "halted" from "called at the wrong time".
- **Cons**: Edits three enums that ADR-0010 and ADR-0011 own and the GDDs list.
- **Estimated Effort**: Medium.
- **Rejection Reason**: Not needed for MVP; the development error names the cause. Revisit if a bot needs the difference.

## Consequences

### Positive
- A listener cannot change the roster under a loop.
- A misspelt or forgotten connection fails a test.
- One gameplay listener per signal removes dependence on an unsourced order.

### Negative
- The `HALTED` code now also means "called inside a tick" for those commands.
- Teardown needs an explicit `dispose()`; forgetting it leaks the battle.
- The wiring test may need the `SIGNALS` fallback (Verification 2).

### Neutral
- `architecture.md` names the FlowSim signal `phase` in its event table and `phase_changed` in its API. This ADR uses `phase_changed`. The table should be corrected in the next revision (not edited here).

## Risks

- **Listener order assumed by accident.** Mitigation: the test fails on more than one gameplay connection per signal.
- **A view listener starts issuing commands.** Mitigation: the in-tick refusal plus the call-from-listener test.
- **Cycle leak on retry.** Mitigation: `dispose()` and the reference-count test.
- **Enum-typed parameter behaviour differs from the `int` assumption.** Mitigation: `int` is safe either way.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-flow-005: phase machine with `halted()`, `in_build()`, `in_tick()` | `phase_changed` payload and commit-then-emit; halt reads after emits |
| game-state-stage-flow.md | TR-flow-006: leak before `waves_complete`; fatal leak beats a clear | Emit rule 2 and 3 |
| game-state-stage-flow.md | TR-flow-010: wiring test with view allowlist | Section 5 |
| combat-damage.md | TR-combat-006: `attack_fired`, `damage_applied` with copied positions, views only | Table rows, allowlist, copied `Vector2` payloads |
| enemy-wave.md | TR-wave-003: synchronous kill, leak, clear signals; reap in `spawn_id` order | Table rows and emit order |
| enemy-wave.md | TR-wave-005: `halted()` checked after every read and signal | Emit rule 3 |
| tower-system.md | TR-tower-006: `gold_changed`, `tower_built`, `tower_upgraded`; shell-only signals | Table rows; shell signals outside the test |

## Performance Implications
- **CPU**: A synchronous signal with one listener is a call; a handful per tick. Cost per emit is not sourced and is not claimed.
- **Memory**: One `DamageEvent` per hit (ADR-0007).
- **Load Time**: Negligible.
- **Network**: None.

## Migration Plan
Nothing exists to migrate. BattleBuilder (ADR-0002) implements the wiring function; the wiring test lands with the first story that adds a signal.

**Rollback plan**: If the refusal rule blocks a legitimate flow, switch to Alternative 1 for that command only and record it in a superseding ADR.

## Validation Criteria
- Every command called from inside every gameplay listener changes nothing and emits nothing.
- The wiring test fails when a connection is deleted and when an allowlist entry is misspelt.
- A scripted fatal leak pays no bounty and emits no `waves_complete`.
- `get_reference_count()` check passes after `dispose()`.

## Related
- `docs/architecture/architecture.md` (Data Flow section 3, API Boundaries, QQ-10)
- `design/gdd/combat-damage.md`, `design/gdd/game-state-stage-flow.md`, `design/gdd/enemy-wave.md`, `design/gdd/tower-system.md`
- ADR-0001 Simulation and Shell Boundary; ADR-0002 App Lifecycle and Composition; ADR-0003 Fixed Tick, Time and Determinism; ADR-0004 Catalogue Format, Loader, Validator and Stat Accessor; ADR-0007 Combat Data Model
- GDD sync: checked 4 referenced GDD(s) by name against this ADR; one naming difference sits in `architecture.md` (`phase` against `phase_changed`), none in the GDDs.
