# ADR-0006: Battle Signal Contracts and View Allowlist

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer. Reviewed 2026-11-05 by godot-specialist (2 BLOCKING, 8 MINOR, plus an 8-row engine probe) and technical-director (TD-ADR: CONCERNS, 3 blockers, 7 concerns, 6 advisories); all findings were applied in the same-day fix round, except where the Decision text records a different choice. A re-review of the revised text follows. Fix round 2026-11-05 after architecture-review-2026-11-05 (items applied: C1, StageResult counters, D5, D8, D12, ordering note, flow-enum pointer).

## Summary
Battle systems talk through signals, and the GDDs, ADR-0004, ADR-0005 and ADR-0009 each leave open the same questions: when an emit is allowed, what the final names and payloads are, who may listen, and when Flow emits `phase_changed(FATAL)`. This ADR decides: every emit is synchronous over a direct connection with no flags, state is committed before the first `emit`, sim reactors and view observers are two classes of listener with different re-entrancy rights, the signal catalogue (with the QQ-07 renames `waves_completed`, `tapped`, `ground_tapped`, `became_idle`) and typed payloads, `StringName` record IDs and `int` instance IDs, one named view allowlist checked by a listener-count test, and a once-only `phase_changed(FATAL)` that Flow emits at the first of three named observation points.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf, probed 2026-11-01) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM. `Signal.connect(Callable)` is a 4.0 API (`deprecated-apis.md` lists the string-based `connect` as replaced). Nothing here depends on a 4.5 to 4.7 change; the risk was the behaviours the reference does not cover, now observed on desktop by the probe (see Verification Required). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (no signal row for 4.4 to 4.7); `deprecated-apis.md` (Callable-based connect); `current-best-practices.md` (the variadic-lambda note, which this ADR does not use because lambdas are banned under `src/battle/`); ADR-0001's 4.7.2 probe table (a signal connection does not keep a `RefCounted` listener alive and `emit()` then does nothing); architecture QQ-15 and the 4.7.2 probe, 2026-11-05, prototypes/adr-0006-probe/ row 6 (the signal declaration's parameter types are not checked at `emit()`; a typed handler rejects a non-convertible argument with a console error and is skipped, `float` to `int` truncates and an out-of-range enum `int` passes silently); architecture Data Flow 3 and API Boundaries B1 (a signal and a method cannot share a name: `signal phase` plus `func phase()` fails to parse on 4.7.2); ADR-0002's probe (`String` and `StringName` interoperate as keys) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Observed on 4.7.2 desktop, headless debug editor (4.7.2 probe, 2026-11-05, prototypes/adr-0006-probe/; outputs `output.txt`, `output2.txt`): (1) a direct-connected handler runs to completion before `emit()` returns (the ADR-0009 premise; cite this row there); (2) handlers run in connection order; (3) an `emit()` from inside a handler runs depth-first and synchronously; (4) `Signal.get_connections()` and `Object.get_signal_connection_list()` return the same dictionaries with keys `signal`, `callable`, `flags`, and `callable.get_object()` and `.get_method()` name the target; (5) `emit()` with no connections is silent; (6) a typed handler given a `String` for an `int` prints an error and is skipped while the next handler runs, `float` 2.75 into `int` arrives as 2, `99` into an enum-typed parameter arrives as 99, and a parameter-count mismatch connects with `OK` and fails at the first `emit()`; (7) a second `connect` of the same method returns `ERR_INVALID_PARAMETER`, prints an error and leaves the count unchanged; (8) releasing a `RefCounted` listener removes its connection at once. **Caveat: desktop debug editor only. Repeat the probe on a release export template before Accepted (a device run joins ADR-0003's D1 to D4).** Later observed: `get_object().get_script().get_global_name()` works as the class read for the allowlist test (ADR-0007 V7, `prototypes/adr-0007-probe/output-review.txt`). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted: Decisions 3, 5 and 6, the connection site and the no-flags rule); ADR-0004 (Proposed: Decision 5 `Flow.phase()` reads FATAL from the latch, Decision 6 the slot order, Decision 7 commands between ticks, Decision 9 `view_dt`); ADR-0005 (Proposed: Decision 3 the FATAL read, the tower-level commit); ADR-0009 (Proposed: roster, reap, `deliver`, and its delegations to this ADR); ADR-0002 (`StringName` record IDs) |
| **Enables** | ADR-0007 (recording fakes, listener-count test runner), ADR-0008 (resolver signal names), ADR-0009 (final `waves_completed` name), ADR-0010 (command guard, RunLog listeners), ADR-0011 (view registration) |
| **Blocks** | Every Flow, EnemyWave, Combat, TowerSim and HeroSim story that declares, emits or connects a signal; every HudLogic, TowerInput and view story that connects one |
| **Delegates To** | ADR-0007: the recording-fake classes, the payload type assertions, the listener-count test runner and the per-build-configuration wiring test mechanism. ADR-0008: the resolver's signal payloads (names fixed here). ADR-0010: command result codes including the re-entrancy refusal code (Flow's own enums, `Flow.StartResult` and `Flow.CallResult`, are decided in ADR-0010 Decision 2), RunLog schema and flush order, TowerInput's `slot_tapped` and `tower_inspected` payload details. ADR-0011: view classes, their `on_*` handlers, the redraw key, view-clock rules, and their rows in the Observer table. ADR-0009: `DamageEvent` fields and `Combat.SourceKind` values (this ADR fixes only the signal signature that carries them). ADR-0010 inherits TowerSim as the gold owner and the `gold_changed` emitter (architecture Module Ownership and Data Flow 3; the brief grouped it under Flow and the architecture wins) and the two TowerSim reactor edges; moving gold is a revision of this ADR; the refusal code for a guarded command called while `in_dispatch()` is true is also ADR-0010's. ADR-0011 inherits the view polling contract of Decision 5 (roster diff, `attack_fired`, `damage_applied(killed)`) and its two limits. ADR-0007 also owns the lints named in Decisions 1, 3 and 10: no `connect(func` under `src/presentation/` or `src/app/`, no `.deliver(` outside `src/battle/`, no `get_connections()` or `get_signal_connection_list()` under `src/`. |
| **Ordering Note** | ADR-0006 and ADR-0007 reference the later-numbered ADR-0009; accept ADR-0009 with them. ADR-0004 and ADR-0005 are Proposed and cite this ADR for the FATAL emit and commit-before-emit. Accept ADR-0004, ADR-0005 and this ADR together. ADR-0008 and ADR-0009 must adopt the Decision 5 names before they are Accepted. **Edits made to ADR-0004 in this round:** its Key Interfaces line `in_tick()` and the Decision 7 Must rule (commands refuse when `in_tick()` is true) now refer to `Battle.in_dispatch()`, of which `in_tick()` is a subset, and its Migration line no longer injects `in_tick` into Flow, TowerSim and HeroSim (Battle calls down into each sim's `in_command()`; nothing is injected). |

## Context

### Problem Statement
Eleven systems exchange state change notices. Five documents already rely on rules this ADR must now fix: ADR-0004 and ADR-0005 say "ADR-0006 owns the once-only `phase_changed(FATAL)` emit" and "owns commit-before-emit"; ADR-0009 delegates the names and payloads of six signals and the `waves_complete` rename; the Input GDD's tests already use `tap`, `ground_tap`, `idle`; and architecture QQ-04 leaves the ID type of `tower_id` open. Without one contract, each system would pick its own emit timing, and a listener that reads the sim mid-handler would see half-committed state. The signal declaration's parameter types are not checked at `emit()`; a typed handler rejects a non-convertible argument with a console error and is skipped, while `float` to `int` truncation and an out-of-range enum value pass silently (probe row 6). So the contract must also say how payload types are proven.

### Constraints
- Gameplay classes are `RefCounted` under `src/battle/`, with no autoload, no lambda, no `bind()`, no `static var`, no `CONNECT_DEFERRED`, no `CONNECT_ONE_SHOT` (ADR-0001 Decisions 3 and 5; registry `capturing_callable_injection`).
- Every battle-internal connection is made in `BattleBuilder.build()`; wrapper-side connections in `BattleWrapper.setup()` (ADR-0001 Decisions 3 and 10).
- A battle with every view and log listener removed produces identical state (Principle 4; TR-tower-012, TR-hud-004). The deterministic baseline (ADR-0004 Decision 12) is taken with no view.
- The tick order is fixed (ADR-0004 Decision 6); commands run only between ticks (ADR-0004 Decision 7).
- A signal and a method of the same name cannot coexist (4.7.2, architecture B1).
- Hardware: a low-end Android phone at 60 fps (30 fps floor); signal traffic must stay inside the 4.0 ms simulation slice (ADR-0004 Decision 14), unmeasured.

### Requirements
- TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012 (the table near the end).
- Decide the QQ-07 names and the QQ-04 ID types.
- State the commit-before-emit rule, the emit order inside one slot, and the FATAL emit's timing so ADR-0001 Decision 6, ADR-0004 Decision 5 and ADR-0005 Decision 3 stay true.

## Decision

**1. Emit model.** Every battle signal is declared with typed parameters on its owner, emitted with `emit(...)`, and connected with `Signal.connect(obj.method)` over a method Callable whose target has a named strong holder (ADR-0001 Decision 5). No flags: no `CONNECT_DEFERRED`, no `CONNECT_ONE_SHOT`, no `CONNECT_REFERENCE_COUNTED`, no `CONNECT_PERSIST`. No `await` on a signal in `src/battle/`. No lambda anywhere in `src/battle/`; in `src/presentation/` a signal target is also a method Callable (the registry ban already covers injection; this ADR extends the signal-target part to the wrapper and views so the listener-count test can read a target's method name). A handler runs to completion before `emit()` returns, so every emit is a synchronous call (observed on 4.7.2 desktop, 4.7.2 probe, 2026-11-05, prototypes/adr-0006-probe/ row 1; the release-export caveat is in Verification Required). The design depends on that and on the other observed rows only. A lint (ADR-0007) finds no `connect(func` and no `.bind(` under `src/presentation/` or `src/app/`, extending ADR-0001's `src/battle/` scan. A signal name never equals a method name on the same class (4.7.2, B1); the past-tense name stays on the signal and the read keeps the bare name (`phase_changed` and `phase()`).

**2. Commit before emit (hard rule).** Before the first `emit` of a transition, every piece of state the transition changes is final: the roster removal (`removed = true` and the `_live` splice, ADR-0009 Decision 13), gold, lives, `wave_index`, the phase, the built tower's `ReadContext.level` and slot occupant (ADR-0005 Decision 3: debit, write `level`, then emit), the hero pin target and the burst state. A listener that reads any public query inside its handler therefore sees the final state (Tower criterion 12 demands this for `slot_state`). A refused command changes nothing and emits nothing. A command that emits more than one signal commits all of its state first, then emits in the table order of Decision 4. Cause of the rule: a handler can read the sim at any moment, and the sim cannot un-publish a half-set state. The ordering inside a transition is "set state, act, emit" (Flow Rule 15): "act" is setting the halt that `Battle.tick`'s gate reads (ADR-0004 Decision 5) and calling the guarded `cancel_input()`, so a listener reading `halted()` or `phase()` and the resolver's state sees the settled outcome. The wrapper's `Clock` is stopped by AppRoot, never by Flow (ADR-0004 Decision 4). **Early-call gold is the one place order matters:** `wave_called_early` is consumed by the TowerSim reactor, which credits the bonus, so an observer of `wave_called_early` (HudLogic, RunLog) must not read gold in that handler; it reads gold on `gold_changed`. In general an observer of a reactor-consumed signal must not read state that the signal's reactor writes. The reactors are connected in `build()` before any observer in `setup()`, so connection order (observed, row 2) also puts them first, but correctness does not rely on it.

**3. Two classes of listener.** Re-entrancy is decided by who the listener is, because the sim itself consumes five signals and a blanket "no emit from a handler" rule would forbid its own wiring.
- **Reactors** are the sim methods connected in `build()`: `Flow.on_enemy_leaked`, `Flow.on_wave_cleared`, `Flow.on_waves_completed` (all from EnemyWave) and `TowerSim.on_enemy_killed`, `TowerSim.on_wave_called_early` (from EnemyWave and Flow). A reactor may commit its own state and emit its own signals, once its own state is final. The cascade is a fixed acyclic graph, written here as the only one: `enemy_leaked` to `lives_changed` (and `phase_changed(LOST)`); `wave_cleared` to `phase_changed(INTERMISSION)`; `waves_completed` to `phase_changed(WON)`; `enemy_killed` to `gold_changed`; `wave_called_early` to `gold_changed`. A new reactor edge is an edit to this ADR. A reactor never calls a command method and never reads a signal's later effects.
- **Observers** are every other listener: HudLogic, TowerInput, the views, BattleWrapper, RunLog, GestureLog and the bots. An observer handler must never call a Flow, TowerSim or HeroSim command (`start_wave`, `call_early`, `pause`, `resume`, `build`, `upgrade`, `pin`, `burst`), never call `Combat.deliver`, never emit a battle signal, and never write sim state. It may call public read-only queries, set its own presentation flags, and emit presentation-layer signals (`modal_changed`, `slot_tapped`, the resolver's own); a battle signal never. It may not read state its signal's reactor writes (Decision 2). Slow or deferred work (HudLogic's result snapshot) records a flag and runs in `advance(ms)` or the view step (ADR-0004 Decision 9); a chip close that must take effect at once may call the resolver, which is not a sim command. Enforcement: `Battle.in_dispatch() -> bool` returns `in_tick() or _flow.in_command() or _tower_sim.in_command() or _hero_sim.in_command()`. Battle already holds the three sims, so this is call-down only: no injection, no shared flag and no sim reference to Battle (registry `refcounted_back_reference`). Each guarded command method (`start_wave`, `call_early`, `pause`, `resume`, `build`, `upgrade`, `pin`, `burst`) checks `in_dispatch()` through the one method Callable it already has for ADR-0004's guard, and, only after its refusal checks pass, sets its own private `_in_command` and clears it at the wrapper's single return (ADR-0010 Decision 3), so a private commit that returns early cannot leak it (GDScript has no `finally`). Each sim's flag is its own, so a nested command in another sim cannot clear it (`call_early` runs Flow's flag while TowerSim's reactor runs its own). A refused guarded command makes no change; it reports through `dev_error` only for `REENTERED`, not for `HALTED`, `NO_GOLD` or the pure refusals (ADR-0010 Decision 2). Flow's wave start on `call_early` is a private helper inside Flow's command, not a guarded public method. `Combat.deliver` is **not** guarded by `in_dispatch()` (sims legitimately call it inside a tick); its ban on observers is a structural lint (no `.deliver(` outside `src/battle/`, ADR-0007). Unit tests prove the guard with a recording probe that calls each guarded command from inside each observer-signal handler, a fatal tripped mid-command, and a refusal leaving `in_dispatch()` false once the outer command returns.

**4. Emit order inside one slot and across a tick.** Within a tick, emits occur in slot order (ADR-0004 Decision 6), and inside a slot in this order, each step committed before the next begins:
1. Slot 2 (EnemyWave `advance`): for each leaker in ascending `spawn_id`, the roster removal first, then `enemy_leaked(lives_cost)`. The reactor commits lives and emits `lives_changed(current)`; if lives reach 0 it then emits `phase_changed(LOST)`. A lethal leak (lives reach 0) ends the loop: no `enemy_killed`, no clear (Enemy GDD Edge Cases). A handler running inside the loop may read `roster()` (rebuilt before the emit) and must not add or remove roster entries; EnemyWave iterates `_live` by index, re-reading `size()`, and a `halted()` return is the only early exit (ADR-0009 Decisions 12 and 13), so a re-entrant `phase_changed(LOST)` from the reactor cannot invalidate the iteration.
2. Slots 4 and 5 (TowerSim, HeroSim): inside `Combat.deliver`, `damage_applied` is emitted last, after HP, counters and the `killed` flag are final (ADR-0009). `attack_fired` is emitted by the caller before `deliver`, with positions copied at that moment; it is view-only. `burst_started` and `hero_pinned` come after the state is set.
3. Slot 6 (EnemyWave `reap`): in ascending `spawn_id`, for each corpse the removal is committed, then `enemy_killed(bounty)`; the TowerSim reactor commits gold and emits `gold_changed(current)` before the next corpse. After the corpses, the clear check emits `waves_completed()` for the last wave position and otherwise `wave_cleared(intermission_duration)`, never both (Enemy GDD Rule 11; a `waves_completed` arriving in Intermission would be an out-of-phase breach under Flow Rule 15a). Leaks come before the clear (TR-state-008). This commit-first order (the removal precedes `enemy_killed`) supersedes the GDD Rule 11 narrative "fires, and the corpse is removed" (ADR-0009 Decision 13); the sync file lists that line.
Across a tick the observable order of one enemy's life is therefore: `attack_fired`, `damage_applied(killed = true)`, `enemy_killed`, `gold_changed`; a leak's `enemy_leaked`, `lives_changed`, `phase_changed` precede all of that tick's fire. Nothing in gameplay relies on observer order (Decision 8).

**5. The signal catalogue, final names (QQ-07 included).** Names are past tense. Rename decisions: `waves_complete` becomes `waves_completed`; the Input GDD's `tap` becomes `tapped`, `ground_tap` becomes `ground_tapped`, `idle` becomes `became_idle`. `pressed` is kept: it is already past tense (a past participle, and Godot's own `BaseButton.pressed` is the same word), so QQ-07's listing of it is closed without a change. The GDD, UX and architecture occurrences are listed for the orchestrator in the sync file. `gold_changed` stays with TowerSim, as architecture Module Ownership and Data Flow 3 have it. By emitter:

| Emitter | Signal and payload | Listeners (reactors in bold) |
|---|---|---|
| Flow | `phase_changed(value: Flow.Phase)` | HudLogic, TowerInput (closes the chip), BattleWrapper (zeroes the Clock accumulator on PAUSED, reads `value`), Combat view and Hero view (clearance), RunLog |
| Flow | `lives_changed(current: int)` | HudLogic, HUD views, RunLog |
| Flow | `wave_called_early(seconds_left: float)` | **TowerSim** (early-call gold), HudLogic, RunLog |
| EnemyWave | `enemy_leaked(lives_cost: int)` | **Flow** |
| EnemyWave | `enemy_killed(bounty: int)` | **TowerSim** |
| EnemyWave | `wave_cleared(intermission_duration: float)` | **Flow** |
| EnemyWave | `waves_completed()` | **Flow** |
| Combat | `attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)` | Combat view, audio (Alpha) |
| Combat | `damage_applied(event: DamageEvent, applied: float, position: Vector2, killed: bool, spawn_id: int)` | Combat view, EnemyView, audio (Alpha) |
| TowerSim | `gold_changed(current: int)` | HudLogic, RunLog |
| TowerSim | `tower_built(slot_index: int, tower_id: StringName)` | HudLogic, tower views, RunLog |
| TowerSim | `tower_upgraded(slot_index: int, level: int)` | tower views, GestureLog (dev) |
| HeroSim | `hero_pinned(position: Vector2)` | HudLogic, Hero view, RunLog |
| HeroSim | `burst_started(aim_point: Vector2, telegraph_ticks: int)` | HudLogic, Hero view, Combat view (clearance), GestureLog (dev), RunLog |

`Flow.Phase` is the enum owned by Flow (BUILD, WAVE, INTERMISSION, PAUSED, WON, LOST, FATAL). `gold_changed` stays with TowerSim, the owner of gold (Data Flow 3, Tower Rule 14), and is emitted only when gold changes. There is **no separate outcome signal**: the outcome is `phase_changed(WON)` or `phase_changed(LOST)` plus the `result()` read, as the Flow GDD has it. **No `enemy_spawned`, `wave_started`, `tower_fired`, `status_applied`, hero-move or `burst_fired` signal is created**: no GDD names a listener for any of them, a spawn is visible in the roster read, a wave start is `phase_changed(WAVE)`, a tower shot is `attack_fired`, a slow is counted by `slows_applied()`, and the hero's motion is the `position()` read. A signal with no listener is dead weight and one more row in the wiring test; adding one is a revision of this ADR. **How views learn what the dropped signals would have said (an inherited constraint on ADR-0011):** spawn, move, leak and slow come from a per-frame `roster()` diff by `spawn_id` plus `position()` and `Status` reads; a tower shot and a burst detonation come from `attack_fired` (`SourceKind`); a death comes from `damage_applied(killed = true)`; hero motion comes from `position()`. Two limits are accepted: an enemy that spawns and dies within one frame is never drawn, and `enemy_leaked(lives_cost)` carries no `spawn_id` (no GDD listener needs one; adding it would be a payload revision here), so a leak is inferred from the roster diff, not named.
`StageResult` (architecture B0 names this ADR as its owner): `class_name StageResult extends RefCounted` in `src/battle/stage_result.gd` (B0's `src/core/flow/` path is superseded by ADR-0001 Decision 10), fields written once by Flow at the outcome commit and read through `Flow.result()`: `outcome: Flow.Phase` (WON, LOST or FATAL), `last_wave_started: int`, `lives_left: int`, `damage_by_id: Dictionary` (`StringName` to `float`), `damage_by_kind: Array[float]` (by `Combat.SourceKind`), `damage_total: float`, copied from Combat's counters (ADR-0009 Decision 8) before the outcome's `phase_changed`. It carries no signal. Flow fills the damage fields from Combat's counters that the builder injects as method Callables (ADR-0001 Decision 3 injection; ADR-0009 Decision 8 owns the counters), read once when the outcome commits.
UI-layer signals that follow the same naming and payload rules but are not battle-state signals: `TowerInput.slot_tapped(slot_index: int)` and `tower_inspected(slot_index: int)` (listener HudLogic; payload detail ADR-0010). Adapter signals (ADR-0003): `lifecycle_paused()` and `viewport_resized()`.
Inherited constraint on the resolver (ADR-0008 writes the payloads): `pressed(best_tap: int, best_drag: int, p: Vector2)`, `tapped(best_tap: int, p: Vector2)`, `ground_tapped(p: Vector2)`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `became_idle()` keep the payload shapes in the Input GDD with the four new names; hit-target IDs are `int` (resolver registration ids, never record IDs).

**6. ID and payload types (QQ-04, said once).** Record IDs (`tower_id`, `source_id`, wave and enemy def IDs, hero and burst IDs) are `StringName` in every signal payload (ADR-0002's `record_id_type`). Instance identifiers are `int`: `spawn_id`, `slot_index`, resolver target ids. Durations and amounts: whole-number economy values (`bounty`, `lives_cost`, `current` gold or lives, `level`, `telegraph_ticks`) are `int`; `applied`, `radius`, seconds-valued payloads are `float`; positions are `Vector2` copies made at emit time. Enums are typed by their owner (`Flow.Phase`, `Combat.SourceKind`) and cross the signal as the enum, never as a bare `int` or `String`. A payload never carries a `Dictionary` or `Array`. The one object payload is `DamageEvent`; an observer never stores, mutates or re-emits it. Payload parameter names are the GDD's names, so a recording fake names fields the way a GDD criterion does.

**7. The payload and read-back rule (HUD).** A payload carries the value the signal announces plus the identifiers an observer needs to key its own presentation (`gold_changed(current)`, `tower_built(slot_index, tower_id)`). It does not try to carry the whole view-model. Because state is committed before the emit (Decision 2), an observer may call a public read-only query from its handler and will see the final state, but it must not cache a stat value beyond the step that read it (ADR-0005 `stat_value_caching`) and a HUD handler that reads a cost or stat checks `phase() == FATAL` after the read (ADR-0005). Observers do their drawing and slow work in the view step after the ticks (ADR-0004 Decision 9), not in the handler: the handler sets a dirty flag or a counter. This rule favours reading the public query at the view step over widening every payload, because a payload that grows with every view need becomes a second copy of the sim's state.

**8. Gameplay never depends on observers.** A battle whose every observer connection is removed is state-identical: same per-tick snapshots, same RNG state, same result (TR-tower-012, TR-hud-004; Principle 4). One carve-out: an observer's read of the accessor (a HUD cost read, ADR-0005 Decision 3) can latch the `FatalLatch` on a defect, which changes the outcome; the latch is the only sim state an observer can reach, it is reached only on a defect, and the identical-state tests run on a valid catalogue where no read latches. The sim never holds a reference to a presentation object and never connects to one (the layer lint, ADR-0007, covers `src/battle/` naming nothing under `src/presentation/` or `src/app/`). Observers connect only from `BattleWrapper.setup()` (and, for dev builds, the same function when the dev flag is set), after `build()` returned, so the build-time connections are the only reactor edges. The wrapper never connects a battle signal to a method on a sim.

**9. The Observer allowlist.** The table in Decision 5 is the allowlist: the named observer classes per signal. A connection on a battle signal is legal when it is (a) a reactor edge listed in Decision 3, made in `build()`, or (b) an observer from the allowlist, made in `BattleWrapper.setup()` (view and HUD classes connect through their `on_<signal>` methods; a view that is not in the table is not wired). Signals with no reactor are the "no sim listener" set: `phase_changed`, `lives_changed`, `gold_changed`, `tower_built`, `tower_upgraded`, `hero_pinned`, `burst_started`, `attack_fired`, `damage_applied`. Headless they have zero connections, and that is correct, so they are on the named allowlist of the architecture's Rule 4 (TR-state-013). The five reactor-consumed signals (`enemy_leaked`, `enemy_killed`, `wave_cleared`, `waves_completed`, `wave_called_early`) have exactly one connection headless. A single source of truth for both lists is a constants file, `src/battle/battle_signals.gd` (`class_name BattleSignals extends RefCounted`, `const` only, no `static var`). Each entry names its emitter class and, for a reactor edge, its target class and method: `REACTED := {&"enemy_killed": [&"EnemyWave", &"TowerSim", &"on_enemy_killed"], ...}` (count implied 1), and `OBSERVED_ONLY: Dictionary` maps each signal name to its emitter class. The test asserts the table against each emitter's `get_script().get_script_signal_list()`: the declared signals and `BattleSignals` for that emitter must be equal sets, so a new undeclared signal fails, and `enemy_killed` wired to Flow instead of TowerSim fails. ADR-0011's views register by adding their class to the Observer column of Decision 5 and to a wrapper wiring table; they do not connect anywhere else. EnemyView styles kills from `damage_applied(killed, spawn_id)` (ADR-0011 Decision 3).

**10. The listener-count wiring test (what it asserts; ADR-0007 owns the runner).** For each signal in `BattleSignals`: (a) headless (`build()` only), the connection count equals `REACTED[name]` or 0 for `OBSERVED_ONLY`, and each connection's target is a reactor from Decision 3; (b) in a dev-flagged wrapper with RunLog and GestureLog attached, each signal those logs consume has at least one connection whose target is that log; (c) where a scene can be built, each allowlisted view and HUD class has a connection on every signal the table assigns it, and no connection on a battle signal has a target class outside the table; (d) no connection has a flag set. The test reads `Signal.get_connections()` (one signal, no string name; same dictionaries as `get_signal_connection_list`, probe row 4): `d["callable"].get_object()`, `.get_method()` and `d["flags"] == 0`; the target's class is read with `get_object().get_script().get_global_name()` (4.3+ API, observed, ADR-0007 V7, `prototypes/adr-0007-probe/output-review.txt`). (e) The headless `build()` and the whole test run emit no console error: this explicit assertion is the net for a duplicate `connect` (refused with an error and an unchanged count, row 7, so "exactly 1" alone would pass) and for a typed-handler rejection. (f) The `get_connections()` and `get_signal_connection_list()` calls are test-only (lint, ADR-0007; each allocates an `Array` of `Dictionary`). The test holds every fake and observer in a field for its whole run: a connection vanishes the instant its `RefCounted` listener is released (row 8), which would read 0 silently. The recording fake declares every handler parameter **untyped** (`func on_gold_changed(current) -> void`) and asserts argument count, `typeof` and enum range itself, because a typed fake handler would be skipped with a console error instead of recording the bad value (row 6); float to int truncation and an out-of-range enum `int` are the silent cases the `typeof` and range assertions exist for.

**11. `phase_changed(FATAL)` is emitted exactly once, by Flow, at the first observation.** Flow holds `_fatal_emitted: bool` and one method, `observe_fatal() -> void`: if `_fatal_emitted` return; if `is_fatal()` (the injected method Callable `Battle.is_fatal`, ADR-0004 Decision 5) is false return; set `_fatal_emitted`; set the halt the `Battle.tick` gate reads and call the guarded `cancel_input()` (Rule 15 order; the wrapper's `Clock` is stopped by AppRoot, never by Flow); then `emit phase_changed(FATAL)`. No stored-phase write is needed: `phase()` already derives FATAL from `is_fatal()`, and `result()` keeps the replaced outcome's fields separately (Flow Rule 18); `outcome` on `StageResult` is FATAL only when `result()` is read after a fatal. Nothing emits from inside `FatalLatch.fatal()`: a fatal is raised in the middle of a sim operation, and emitting there would break commit-before-emit. The three observation points, in the order they occur:
1. Flow's own checks after acting and after each emit of its own sequence (Flow Rule 15): a listener that latches a fatal during an emit gets the FATAL emit at once, after the emit under way finishes delivering and with no further emit of the transition (Flow criterion 18).
2. `Battle.tick` at every `halted()` check, the entry gate included (a fatal that arrived between ticks by a command, a HUD read or an adapter event is announced before the gate returns), the checks between slots, and once after slot 6. A fatal raised inside slot N is announced at the slot boundary, the same tick; the tick halts there (ADR-0001 Decision 6: "halts at the next `halted()` check") with the emit made before the return, never mid-slot.
3. `BattleWrapper._process`, after input and before `Clock.advance`, through `Battle.observe_fatal()` (Battle forwards to Flow; the wrapper holds Battle). A fatal on a frame with no tick is announced the same frame.
Fatal overrides Won, Lost and Paused (Flow Rule 18): the replaced outcome's emit stays emitted, and FATAL is the last. `Flow.phase()` is ratified as returning FATAL whenever `is_fatal()` is true, derived on the same line as the latch set (a derived read, not a stored field) (ADR-0004 Decision 5, ADR-0005 Decision 3, Validation 8 here); `phase_changed(FATAL)` follows later at the earliest observation point and observers must read `phase()`, never wait for the signal. If AppRoot tears the wrapper down in the same frame before point 3, no FATAL signal is delivered and none is needed, because the listeners are being freed; nothing may depend on receiving it. This is honest about a gap: the relative order of AppRoot's and the wrapper's `_process` is NOT SOURCEABLE here and no rule above relies on it.

**12. Result snapshot (TR-hud-012).** HudLogic's handler for `phase_changed(WON)` or `phase_changed(LOST)` emits the presentation signal `modal_changed(result)` at once (HUD Rule 15: the modal Control is visible and input dead immediately) and sets a pending-outcome flag. Only the snapshot waits: the result screen and log record are built from one snapshot on the first `advance(ms)` after the outcome, outside the tick's signal stack. If `phase() == FATAL` the snapshot is not built. Flow copies Combat's damage-by-source counters into the stage result at the outcome commit, before `phase_changed(WON)` or `phase_changed(LOST)` (ADR-0009 Decision 8).

**13. Catalogue emits nothing (TR-data-014).** `Catalogue`, `CatalogueBuilder`, the validator and every record declare no `signal`. Each emitter declares its own; `build()` wires them.

**14. GDScript 4.7 pitfalls.** (a) Parameter types on a `signal` declaration are not checked at `emit()`; a typed handler rejects a non-convertible argument with a console error and is skipped, and `float` to `int` truncation and out-of-range enum values pass silently, so payload tests use an untyped recording fake that asserts types itself (Decision 10). (b) A `connect` to a method with a different parameter count returns `OK` and fails at the first `emit()`, so a signal never emitted in a test passes; every signal is emitted at least once in the wiring and payload tests, and the console-error assertion catches the rest. (c) Every handler is `func on_<signal>(...) -> void` with an explicit return type; a typed-return override in a test double has an explicit `return` (QQ-15). (d) No lambda in `src/battle/`; a test fake connects with a method per signal. (e) `emit()` argument order is the declaration order; a payload edit changes the fake and the GDD in the same commit.

**15. Delegations.** Resolver payload shapes: ADR-0008. Recording fakes, runner, listener-count mechanism, per-build wiring: ADR-0007. RunLog schema and flush: ADR-0010. Views, the redraw key and view clocks: ADR-0011. `DamageEvent` and `SourceKind` field lists: ADR-0009.

### Architecture Diagram

```
 build()  (battle-internal, no flags, method Callables)
   EnemyWave --enemy_leaked/wave_cleared/waves_completed--> Flow (reactor)
   EnemyWave --enemy_killed-------------------------------> TowerSim (reactor)
   Flow ------wave_called_early---------------------------> TowerSim (reactor)

 Flow.on_enemy_leaked --> lives_changed --> [phase_changed(LOST)]
 TowerSim.on_enemy_killed --> gold_changed          (reactor cascade; acyclic)

 setup()  (observers; wrapper only, after build)
   phase_changed, lives_changed, wave_called_early --> HudLogic, TowerInput, Wrapper, views, RunLog
   gold_changed, tower_*, hero_*, burst_started --> HudLogic, views, GestureLog/RunLog (dev)
   attack_fired, damage_applied --> Combat view (audio at Alpha)
   damage_applied --> EnemyView (kills styled from killed, spawn_id)
 sim never connects to a view.   headless: only the build() edges exist.

 Fatal: latch set --(no emit)--> Flow.observe_fatal() at 1 own post-emit checks | 2 every halted() check
        in Battle.tick (entry gate, slot boundaries, after slot 6) | 3 wrapper _process, before Clock  --> phase_changed(FATAL) once
```

### Key Interfaces

```gdscript
# src/battle/flow.gd
signal phase_changed(value: Phase)       # inside flow.gd the enum is written Phase
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
func observe_fatal() -> void            # idempotent; emits phase_changed(FATAL) once
func in_command() -> bool               # private _in_command flag; TowerSim and HeroSim have the same read
func on_enemy_leaked(lives_cost: int) -> void
func on_wave_cleared(intermission_duration: float) -> void
func on_waves_completed() -> void

# src/battle/enemy_wave.gd
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_completed()                # renamed from waves_complete (QQ-07)

# src/battle/combat.gd
signal attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(event: DamageEvent, applied: float, position: Vector2, killed: bool, spawn_id: int)

# src/battle/tower_sim.gd
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)
signal tower_upgraded(slot_index: int, level: int)
func on_enemy_killed(bounty: int) -> void
func on_wave_called_early(seconds_left: float) -> void

# src/battle/hero_sim.gd
signal hero_pinned(position: Vector2)
signal burst_started(aim_point: Vector2, telegraph_ticks: int)

# src/battle/battle.gd (additions)
func observe_fatal() -> void            # forwards to Flow.observe_fatal()
func in_dispatch() -> bool              # in_tick() or _flow/_tower_sim/_hero_sim .in_command(); call-down only

# src/battle/battle_signals.gd   (const only; emitter and target named per entry)
class_name BattleSignals extends RefCounted
const REACTED := {
	&"enemy_leaked": [&"EnemyWave", &"Flow", &"on_enemy_leaked"],
	&"wave_cleared": [&"EnemyWave", &"Flow", &"on_wave_cleared"],
	&"waves_completed": [&"EnemyWave", &"Flow", &"on_waves_completed"],
	&"enemy_killed": [&"EnemyWave", &"TowerSim", &"on_enemy_killed"],
	&"wave_called_early": [&"Flow", &"TowerSim", &"on_wave_called_early"],
}
const OBSERVED_ONLY := {
	&"phase_changed": &"Flow", &"lives_changed": &"Flow", &"gold_changed": &"TowerSim",
	&"tower_built": &"TowerSim", &"tower_upgraded": &"TowerSim", &"hero_pinned": &"HeroSim",
	&"burst_started": &"HeroSim", &"attack_fired": &"Combat", &"damage_applied": &"Combat",
}

# src/battle/stage_result.gd
class_name StageResult extends RefCounted
var outcome: Flow.Phase
var last_wave_started: int
var lives_left: int
var damage_by_id: Dictionary
var damage_by_kind: Array[float]
var damage_total: float

# Resolver (ADR-0008 owns payloads; names fixed here)
signal pressed(best_tap: int, best_drag: int, p: Vector2)
signal tapped(best_tap: int, p: Vector2)
signal ground_tapped(p: Vector2)
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(best_drag: int)
signal became_idle()
```

### Implementation Guidelines

Must:
- Commit all state, including roster removal, gold, lives, phase and a built tower's level, before the first `emit` of a transition; emit in the Decision 4 order; check `halted()` after each emit as ADR-0001 requires.
- Connect battle-internal signals only in `BattleBuilder.build()` and observers only in `BattleWrapper.setup()`, with `signal.connect(obj.method)` and no flags.
- Declare every signal with typed parameters and the GDD's parameter names; type enums by owner; use `StringName` for record IDs and `int` for instance ids.
- Call `Flow.observe_fatal()` at the three observation points and nowhere else; guard it with `_fatal_emitted`.
- Make HudLogic's outcome handler set a flag; build the snapshot on the next `advance(ms)`.
- Name every handler `on_<signal>` with `-> void`; keep a reactor's state commit before its own emit.
- Add any new signal to `BattleSignals` and to the Decision 5 table in the same change.
Must never:
- Emit from inside `FatalLatch.fatal()`, from `build()`, or before a transition's state is final.
- Use `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT`, `CONNECT_REFERENCE_COUNTED`, `CONNECT_PERSIST`, `await` on a battle signal, a lambda, `bind()` or `bindv()` as a signal target.
- Let an observer call a command, `deliver`, or emit a battle signal, or write sim state; or let a sim hold or connect to a presentation object.
- Let a reactor emit a signal outside the Decision 3 cascade, or form a cycle.
- Let gameplay read an observer's state; or let a result differ with listeners removed.
- Pass a `Dictionary`, an `Array`, or a record ID that is not a `StringName` in a payload; store a `DamageEvent` in a handler.
- Give a signal the same name as a method on its class.

## Alternatives Considered

### Alternative 1: Keep the QQ-07 exceptions (`tap`, `ground_tap`, `idle`, `waves_complete`)
- **Description**: Record the four names as an exception to "signals past tense" and change no GDD.
- **Pros**: Zero GDD edits (about 160 hit lines across the GDDs, UX docs, the architecture file and the registry, listed in the sync file); the Input GDD's tests stay as written.
- **Cons**: A permanent exception list the lint and every new author must remember; `idle` collides with the state name "Idle" in prose and tests; `tap` reads as a command next to `build`.
- **Rejection Reason**: Architecture QQ-07 and the naming rule recommend renaming before any test uses the names; the cost is mechanical and one-off, and it is cheapest now, before ADR-0008 and any code exist. `pressed` is the one kept name because it is already past tense.

### Alternative 2: Emit the FATAL phase change from `FatalLatch.fatal()` (a latch signal wired to Flow)
- **Description**: The latch emits `latched`; Flow commits FATAL and emits at once.
- **Pros**: Zero latency; no observation points to maintain.
- **Cons**: The emit runs inside whatever sim operation raised the fault, before that operation's own state is final, which breaks commit-before-emit; a listener reacting to FATAL could read half-committed state; `build()` would emit during construction.
- **Rejection Reason**: Violates Decision 2. The observation points bound the latency to the same tick or the same frame instead.

### Alternative 3: Deferred observer connections (`CONNECT_DEFERRED`) instead of the reactor/observer split
- **Description**: Connect observers deferred so they never see mid-tick state and never re-enter.
- **Pros**: No re-entrancy risk from observers; no read-back rule needed.
- **Cons**: ADR-0001 bans the flag; deferred delivery moves handlers to idle time the reference does not cover, which loses the same-frame guarantee the chip close and result snapshot rely on, and a deferred delivery order cannot be asserted headless.
- **Rejection Reason**: Contradicts ADR-0001 Decision 5 and removes the synchronous test surface.

### Alternative 4: Fat payloads (a view-model snapshot per signal)
- **Description**: Each signal carries all state an observer might draw.
- **Pros**: Observers never read the sim.
- **Cons**: A second copy of sim state to keep in step, allocation per emit, and a payload edit for every view change.
- **Rejection Reason**: Commit-before-emit already makes a read-back safe; reads at the view step are cheaper and keep one source of truth (Decision 7).

### Alternative 5: An event bus or autoload signal hub
- **Description**: One hub object relays all battle signals.
- **Pros**: One place to count listeners.
- **Cons**: A global (forbidden: `autoload_singleton`) or a held object that outlives a retry; adds a hop and hides the emitter.
- **Rejection Reason**: ADR-0001 rejected the autoload `EventBus`; direct emitter ownership keeps the weakref retry proof.

### Alternative 6: Signals for `enemy_spawned`, `wave_started`, `tower_fired`, `status_applied`, `burst_fired` and hero moves
- **Description**: Add signals the brief's wider list suggested.
- **Pros**: Future audio and VFX hooks ready.
- **Cons**: No GDD names a listener; each adds a row to the wiring test and a payload to keep typed.
- **Rejection Reason**: Not needed by any current GDD; views poll per Decision 5 and ADR-0011 inherits that contract; add by revision when Alpha audio needs them.

## Consequences

### Positive
- One emit model, testable headless: the same recording fake works in every system's tests.
- Observer and sim are separable by a mechanical test, so Principle 4 ("views observe, never steer") has a check.
- The FATAL emit has a bounded latency and cannot fire twice; the HUD reads `phase()` and never waits for it.
- QQ-04 and QQ-07 close, before ADR-0008 and any code uses the old names.

### Negative
- About 160 GDD, UX, architecture and registry lines to edit for the renames (the sync file lists them).
- A `Battle.in_dispatch()` guard with one `_in_command` flag per sim, set after the refusal checks and cleared at the wrapper's single return; ADR-0004's `in_tick()` is now a subset of it and the Callable injected for the guard is `in_dispatch`, not `in_tick`.
- Observers must do deferred work in `advance` or the view step by discipline; only the test and review enforce it.
- The reactor cascade is a short, hand-maintained graph.

## Risks
- **Premises observed on desktop only**: rows 1 to 8 were observed on the 4.7.2 debug editor, not on a release export or a device. Mitigation: repeat the probe on an export template before Accepted. Commit-before-emit makes every observer order safe except for state a reactor writes inside the same signal (early-call gold, Decision 2); that case is covered by the read-on-`gold_changed` rule, not by order.
- **FATAL not delivered if AppRoot tears down first**: mitigated by Decision 11 (nothing relies on the signal; `phase()` is the contract).
- **Fatal inside an observer handler**: the observer's reads may latch while Flow is mid-emit; handled by observation point 1 and by the observer's own `phase() == FATAL` check.
- **Cascade drift**: a new reactor edge sneaks in. Mitigation: the wiring test asserts exact headless counts and targets.
- **A wrong payload is sometimes silent** (float to int truncation, out-of-range enum) and otherwise a console error plus a skipped handler (probe row 6). Mitigation: untyped recording-fake assertions (Validation 1) and the console-error assertion (Validation 10).
- **Class-name read**: `get_script().get_global_name()` was observed (ADR-0007 V7, `prototypes/adr-0007-probe/output-review.txt`); no open risk.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-014: the data store emits no signals; each emitter declares its own and the composition root wires them | Decision 13; a unit test greps `src/data/` and `Catalogue` for `signal`; `build()` is the one wiring site (Decision 9) |
| game-state-stage-flow.md | TR-state-008: Flow listens to synchronous `wave_cleared`, `waves_complete` and `enemy_leaked` (leak before complete) and emits `lives_changed`, phase and `wave_called_early` | Decisions 1, 3, 4, 5: reactor edges, no flags, leak before clear; `waves_complete` becomes `waves_completed`; `phase` is `phase_changed` |
| combat-damage.md | TR-combat-010: view-only `attack_fired` and `damage_applied` emit after commit with copied positions; listeners never call `deliver`; results match with or without listeners | Decisions 2, 3, 4, 5, 8: `damage_applied` last in `deliver`, positions copied at emit; the observer `deliver` ban is a structural lint (no `.deliver(` outside `src/battle/`), not `in_dispatch()` |
| enemy-wave.md | TR-enemy-004: `enemy_leaked`, `enemy_killed`, `wave_cleared` and `waves_complete` fire synchronously (no `CONNECT_DEFERRED`) in `spawn_id` order after commit; leaks before the clear | Decisions 1, 2, 4 (removal committed before `enemy_killed`, leak removed before `enemy_leaked`, the last wave emits `waves_completed` and no `wave_cleared`), 5 (final `waves_completed`) |
| tower-system.md | TR-tower-004: command commit is atomic; state commits before `gold_changed` then `tower_built` or `tower_upgraded`; a refusal changes and emits nothing | Decision 2 (debit, write level, then emit in table order; refusal emits nothing) |
| tower-system.md | TR-tower-012: signals have typed signatures (`tower_id` type undecided); gameplay may not depend on them | Decisions 5, 6, 8: `tower_id: StringName`; Validation 9 headless-identical |
| hero-system.md | TR-hero-008: `hero_pinned` and `burst_started` emit after state is set and are on the view allowlist; handlers never issue commands | Decisions 2, 3, 9 (allowlist row, observer command ban and guard) |
| battle-hud.md | TR-hud-004: the HUD holds presentation state only and no reset path; sim state identical with or without the HUD | Decisions 3, 7, 8; Validation 9 |
| battle-hud.md | TR-hud-010: the HUD reads via signals and view-only queries; `phase_changed` and `lives_changed` join the view allowlist | Decisions 5, 7, 9 (Observer column lists HudLogic for each signal named in the requirement) |
| battle-hud.md | TR-hud-012: the result screen and log come from one snapshot built on the first `advance(ms)` after the outcome, never in the tick's signal stack; none if Fatal | Decision 12 (`modal_changed(result)` and a flag in the handler, snapshot in `advance`, none on `phase() == FATAL`; `StageResult` defined in Decision 5) |

## Performance Implications
- **CPU**: Per tick, at most a few dozen emits (kills and fire dominate), each with one to five listeners; unmeasured, inside the 4.0 ms simulation slice (ADR-0004 Decision 14). Observer handlers do flag writes only, so view cost stays in the 3.0 ms view slice. No allocation is added by the contract beyond the engine's own argument passing, whose cost is NOT SOURCEABLE; Validation 15 ties it to ADR-0004's device measurement (its Verification 3).
- **Memory**: No new per-signal state; `BattleSignals` is a const table; `Flow` gains one bool.
- **Load Time**: None.
- **Network**: Not applicable.

## Migration Plan
Greenfield: `src/` holds no `.gd` file. Create `src/battle/battle_signals.gd` with the first signal-bearing class. At acceptance the orchestrator applies the sync file (four renames) to the Input GDD, Enemy and Wave GDD, Game State GDD, Battle HUD GDD, Tower GDD, systems index, UX docs, `architecture.md` (Data Flow 3 row for `waves_complete`, B2/B5 rows, QQ-04 and QQ-07 closed, the ADR-0006 paragraph gains these names) and `tr-registry.yaml` text for TR-state-008 and TR-enemy-004; B0's `StageResult` and `DamageEvent` paths change from `src/core/...` to `src/battle/...` (ADR-0001 Decision 10); the GDD Rule 11 line "fires, and the corpse is removed" is reworded to commit-first. ADR-0004 was edited in this round (Key Interfaces line, the Decision 7 Must rule, the Migration line; see the Ordering Note); ADR-0009's `waves_complete` becomes `waves_completed` (three lines).

## Validation Criteria
1. (TR-tower-012, QQ-15) A recording fake connected to every signal in `BattleSignals` has untyped handlers and asserts argument count, `typeof` of each argument, `StringName` IDs and enum range itself, for each payload of the Decision 5 table, driven by a scripted battle that emits every signal at least once, with an explicit assertion that the run printed no console error.
2. (TR-tower-004) With a listener on `gold_changed` and on `tower_built`, a `build` shows in the first handler: gold already debited, the slot occupied, `ReadContext.level` written; the log is `gold_changed, tower_built`; a refused `build` logs nothing and changes nothing.
3. (TR-enemy-004) A leaker and a killed enemy on one tick: the first handler of `enemy_leaked` already reads the roster without it; the log (a non-last wave) is `enemy_leaked`, `lives_changed`, then fire, `damage_applied(killed = true)`, `enemy_killed`, `gold_changed`, `wave_cleared`; the last wave logs `waves_completed` and no `wave_cleared`; two kills in one tick give two `gold_changed` in ascending `spawn_id`.
4. (TR-state-008) The Flow criteria 6, 11, 15 and 20 pass with the renamed `waves_completed`; leak precedes clear.
5. (TR-combat-010) `damage_applied` fires after HP and counters are final; the lint finds no `.deliver(` call outside `src/battle/`.
6. (Decision 11, three observation points) Once-only FATAL: a spy in slot 3 latches; `phase()` reads FATAL on the next line with no emit yet; the log is exactly one `phase_changed(FATAL)` at the slot boundary of the same tick, slots 4 to 6 do not run; a second `fatal()`, a following tick entry and a following `_process` add no second emit. A fatal between ticks (a command read) emits at the next `Battle.tick` gate or the wrapper's point 3, whichever first. A listener that latches inside a `wave_called_early` handler yields `wave_called_early`, `phase_changed(FATAL)` and no `phase_changed(WAVE)` (Flow criterion 18).
7. (Decision 3) Each command (`start_wave`, `call_early`, `pause`, `resume`, `build`, `upgrade`, `pin`, `burst`) called from inside each observer-signal handler is refused and changes no snapshot field; a refusal leaves `in_dispatch()` false once the outer command returns; a fatal tripped mid-command clears the flag on its early return.
8. (ADR-0005) With a spy accessor that latches on a HUD cost read, `Flow.phase() == FATAL` on the very next line.
9. (TR-hud-004, TR-tower-012, TR-hero-008, Principle 4) A scripted battle to Won, run headless with every observer connection removed and again with the full wrapper attached, gives equal per-tick snapshots, equal `rng.state` and equal result.
10. (Decision 10, TR-state-013, TR-hud-010) The listener-count test: headless counts equal `REACTED` and zero for `OBSERVED_ONLY`, each connection's target is a reactor; the full and the dev-flagged builds have at least one connection from every Observer-column class on its signals, none from a class outside the table, none with a flag set, the declared signals of each emitter (`get_script_signal_list()`) equal its `BattleSignals` set, and no console error in the run (duplicate connect).
11. (TR-hud-012) With `phase_changed(WON)` delivered, no snapshot exists until the next `advance(ms)`; on `FATAL` none is built.
12. (TR-data-014) A grep test finds no `signal` declaration under `src/data/` or on `Catalogue`.
13. (Verification) Rows 1 to 8 were observed on desktop (4.7.2 probe, 2026-11-05, prototypes/adr-0006-probe/); the same probe is repeated on a release export template before Accepted (the `get_global_name()` read was observed, ADR-0007 V7).
14. (Lint, ADR-0007) No `CONNECT_*` flag name, no `await` on a battle signal, no signal named like a method, no `connect(func` under `src/presentation/` or `src/app/`, no `get_connections()` or `get_signal_connection_list()` under `src/`.
15. (Performance, NOT SOURCEABLE cost) The per-emit argument-passing cost is measured with ADR-0004's device plan (its Verification 3) in the release export: p99 of a tick with the wave-6 emit load.
