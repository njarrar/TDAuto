# ADR-0006: Battle Signal Contracts and View Allowlist

## Status
Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation.

## Date
2026-11-04

## Last Verified
2026-11-04 (against `docs/engine-reference/godot/` for Godot 4.7.2, `architecture.md` v4, ADR-0001 to ADR-0005 as Accepted, `tr-registry.yaml`, `docs/registry/architecture.yaml` and the eight MVP GDDs; not yet reviewed)

## Decision Makers
- Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`, 2026-11-04)
- godot-specialist: not run. TD-ADR: not run. See Reviews still owed.
- Acceptance: the user.

## Summary
Battle systems talk through Godot signals, and the GDDs leave open how those signals fire, what they carry, what they are called and who may listen. This ADR fixes one catalogue of every battle signal with typed payloads, sync emit only, commit before emit, three listener roles (wiring, view, input) that form the view allowlist, final names for QQ-07, `StringName` and `int` IDs for QQ-04, a listener-count test that fails on a signal with no listener, and one result snapshot that feeds both the result screen and the log.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core (scripting, signals) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM. Every signal API used dates from 4.0, and `breaking-changes.md` lists no 4.4 to 4.7 change to `Signal`, `Object.connect` or `emit`. But no file in `docs/engine-reference/godot/` covers signals, so every behaviour below rests on memory of about 4.3 and is unverified on 4.7.2. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (4.4 to 4.7, no signal rows); `deprecated-apis.md` (string `connect()` replaced by `Signal.connect(Callable)`; typed connections preferred); `current-best-practices.md` (4.5 rest parameters; 4.7 typed-return overrides). No `modules/` file covers signals. `architecture.md` v4 (Module Ownership, Data Flow 1 to 6, B0 to B10, Required ADRs, QQ-04, QQ-07); `tr-registry.yaml`; ADR-0001, ADR-0003, ADR-0004, ADR-0005 |
| **Post-Cutoff APIs Used** | None needed. Used: `signal` declarations with typed parameters, `Signal.emit()`, `Signal.connect()`, `Signal.disconnect()`, `Signal.is_connected()`, `Signal.get_connections()`, `Object.get_signal_list()`, `Object.get_signal_connection_list()`, `Script.get_script_signal_list()`, `Object.CONNECT_DEFERRED` and `CONNECT_ONE_SHOT` (as values to reject), `typeof()`, `Array.make_read_only()`, `Dictionary.make_read_only()`. Tests may use 4.5 rest parameters (`...args`) in recording fakes. |
| **Verification Required** | All from memory; none is in the pinned reference and none can be checked offline. Each probe (`tests/unit/engine/test_signal_probes.gd`, proposed) runs on a 4.7.2 binary before the first story that relies on it; results go into `docs/engine-reference/godot/` with date and version. **E1** `get_script().get_script_signal_list()` on an instance of a `RefCounted` script returns only signals that script (and any base script) declares, not `RefCounted`'s or `Object`'s built-ins, with each `args` entry giving `name`, `type` and `class_name`; record what a typed enum parameter (`Flow.Phase`) and a `StringName` parameter report. **E2** `emit()` with a wrong argument type or count: record whether the parser, `emit` or the listener call reports it, and how (the working belief: `emit` checks nothing in 4.x, a wrong count fails at the listener call, and a wrong type may convert silently). **E3** A `String` passed where a listener's parameter is typed `StringName` converts with no error, and `"a" == &"a"` is true, so equality alone cannot catch the drift. **E4** `get_signal_connection_list(name)` and `Signal.get_connections()` return one Dictionary per connection with `signal`, `callable` and `flags`, and `flags` is 0 for a plain `connect(callable)`. **E5** Listeners of one signal run in connection order, and a nested emit inside a listener runs to the end before the outer emit's next listener. No result here depends on E5 (one gameplay listener per wiring signal); record it anyway. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): the Builder's `Wiring` record and the wrapper's `view_wiring`; method Callables only; listeners are `Battle` members; `halted()` checked after every emit; teardown undoes both records. ADR-0003 (Accepted): `InputAdapter.lifecycle_paused()` and `TapScreen.tapped()` reach `Flow.pause` and `Flow.resume` through `view_wiring`. ADR-0004 (Accepted): tick order; `TickGuard` refuses commands inside a tick; Flow's commit order (set state, `cancel_input()`, emit); deferred calls land after `_process`; the clock polls `clock_running()`, not `phase_changed`. ADR-0005 (Accepted): HudLogic never reads the accessor inside a sim signal handler; on `gold_changed` it marks costs dirty and reads in frame step 3. |
| **Enables** | ADR-0007 (the listener-count test, recording fakes that check payload types, lints L-SIG-1 to L-SIG-6), ADR-0008 (resolver signal names fixed here; payloads stay ADR-0008's), ADR-0009 (`attack_fired`, `damage_applied` payload types), ADR-0010 (command guard use, run counters join the snapshot, run log takes the snapshot) |
| **Blocks** | Every story that declares, emits or connects a battle signal: Flow, Enemy & Wave, Tower, Hero, Combat, HUD, Input resolver and the Builder. No epic or story exists yet (`production/` has none), so none is blocked by path today. |
| **Ordering Note** | Write before ADR-0007 and ADR-0008. Decision 7 needs a dated amendment to ADR-0004 Decision 6 on acceptance; until then the rule holds by lint and test only. The GDD renames in Migration 2 are due with acceptance and before any test uses the names. |

## Context

### Problem Statement
Eight GDDs declare signals in prose. Some names break the past-tense rule (QQ-07); the type of `tower_id` is open (QQ-04). The GDDs name "Flow's view allowlist" but never list it, and the architecture wants a test that fails on a signal with no listener but not how it finds the signals. GDScript checks payloads late or not at all, so a renamed signal or wrong payload type passes a parse check and fails in play. Every sim story, ADR-0007 and ADR-0008 need these answers first.

### Constraints
- One thread, no autoloads, no event bus (ADR-0001). Every sim connection is a method Callable recorded in a `Wiring` record.
- Commands run only between ticks; `TickGuard.in_tick()` refuses them inside a tick (ADR-0004).
- Views may read but must never change a result (Architecture Principle 4).
- No code exists yet, so names can change at no cost now and at real cost later.
- Solo part-time developer: the rules must be few and checked by machine.

### Requirements
TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012, and the shared part of TR-state-006 (result contents and phase signals) that ADR-0004 handed over.

## Decision

### 1. Sync emit only
- Every battle signal fires with `sig.emit(...)` on the emitter's own `Signal` member, in the call that changed the state. Never `emit_signal("name")`, never `call_deferred` around an emit, never an emit from a timer or `await`.
- Every connection is made with no flags; `Wiring.connect_recorded()` passes none. `CONNECT_DEFERRED` is banned: a deferred call lands after `_process` (ADR-0004 E7), when its tick has moved on. `CONNECT_ONE_SHOT` is banned: Godot would drop the connection behind the `Wiring` record's back.
- No `await` on a battle signal anywhere in `src/` (ADR-0004 bans `await` in sim folders; this extends it to presentation).

### 2. Commit, then emit
- An emitter commits every state change of the action, counters included, before its first emit. A listener that reads any query inside its handler sees the final state (Combat AC 12).
- When one action emits more than once, the order is fixed in the catalogue (Decision 4) and never changes. Tower: `gold_changed`, then `tower_built` or `tower_upgraded`. Flow outcome: set lives and phase, `cancel_input()`, then `lives_changed` if lives moved, then `phase_changed`.
- A refusal changes nothing and emits nothing (TR-tower-004, Hero, Flow).
- After each emit inside a tick, the emitter checks `halted()` and returns at once when true (ADR-0001 Guideline 9). A loop of emits (leaks, kills) checks after each one.
- A wiring listener (Decision 3) may change its own state and emit its own signals; that nested chain ends before the outer emitter goes on. It never calls the emitter's mutating API.

### 3. Three listener roles; the view allowlist
Every battle signal has exactly one role, written in the catalogue. The roles together are the view allowlist the GDDs name.

| Role | Signals | Listeners | May the signal have no listener headless? | What a listener may do |
|---|---|---|---|---|
| **WIRING** | `enemy_leaked`, `enemy_killed`, `wave_cleared`, `waves_completed`, `wave_called_early`, `latched` | **Exactly one** gameplay listener, connected by the Builder in `Battle`'s `Wiring` record. Views may add listeners through `view_wiring` | **No.** The listener-count test fails | The gameplay listener changes its own state and emits its own signals. A view listener follows the VIEW rules |
| **VIEW** (allowlisted) | `phase_changed`, `lives_changed`, `gold_changed`, `tower_built`, `tower_upgraded`, `hero_pinned`, `burst_started`, `attack_fired`, `damage_applied` | View-only listeners, through `view_wiring` only. **No sim listens**: the Builder makes no connection to them | Yes, and headless they must have **none** | Copy the payload, mark data dirty, call read-only queries. Never a command, never a mutating method, never the accessor (ADR-0005), never keep a list or object from the payload or a query past the handler |
| **INPUT** (allowlisted) | Resolver: `pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `became_idle` | Input owners in the wrapper (HeroInput, TowerInput, HudLogic), through `view_wiring` | Yes, and headless they have none | Owners may issue commands from these handlers; that is their job (Data Flow 1). A handler of `drag_cancelled` or `became_idle` must not command, since `Flow` fires them inside a tick through `cancel_input()` |

**View-only listeners** (the named list): HudLogic (for every VIEW and WIRING signal), HudTopBand, HudField, every field view (enemy, tower, combat, path), ResultScreen, PausedScreen, RunLog, GestureLog, Audio (Alpha) and test recording fakes. HeroInput and TowerInput are view-only for every signal except INPUT signals and the presentation signals below.

**Presentation signals** live on wrapper nodes, not on `Battle` members, so they are outside the headless test. They go through `view_wiring` too: `InputAdapter.lifecycle_paused()` to `Flow.pause`, `PausedScreen.tapped()` to `Flow.resume` (ADR-0003), `TowerInput.slot_tapped(slot_index)` and `TowerInput.tower_inspected(slot_index)` to HudLogic. ResultScreen's Retry `tapped()` calls `AppRoot.request_retry()` (ADR-0001).

**Why `phase_changed` is VIEW, not WIRING**: HeroSim reads Flow through the injected `in_build()`, the clock polls `clock_running()` (ADR-0004), and the upgrade chip that "listens for Fatal" is TowerInput, a view. No sim consumes it.

### 4. The signal catalogue (final names and typed payloads)
Each emitter declares its signals with typed parameters, exactly as below. Parameter names are part of the contract (the listener-count test checks them).

| Emitter | Signal | Role | Fired | Gameplay listener (Builder) |
|---|---|---|---|---|
| EnemyWave | `enemy_leaked(lives_cost: int)` | WIRING | Advance slot, per leak, ascending `spawn_id`, after the enemy leaves the roster | `Flow._on_enemy_leaked` |
| EnemyWave | `enemy_killed(bounty: int)` | WIRING | Reap slot, per corpse, ascending `spawn_id`, before the corpse is removed from the list but after `bounty` is read | `TowerSim._on_enemy_killed` |
| EnemyWave | `wave_cleared(intermission_duration: float)` | WIRING | Reap slot, after every leak and kill of the tick, state committed (seconds; Flow converts with `to_ticks`) | `Flow._on_wave_cleared` |
| EnemyWave | `waves_completed()` | WIRING | Same slot, for the last wave by index, in place of `wave_cleared` | `Flow._on_waves_completed` |
| Flow | `wave_called_early(seconds_left: float)` | WIRING | From the `call_early()` command, after the next wave starts; then `phase_changed(WAVE)` | `TowerSim._on_wave_called_early` |
| FatalLatch (battle) | `latched(cause: String)` | WIRING | Once, on the first `fatal()`, after the forward (ADR-0001) | `Flow._on_latched` |
| Flow | `phase_changed(value: Flow.Phase)` | VIEW | On every change of phase, once, never for the same phase; on resume with the restored phase | none |
| Flow | `lives_changed(current: int)` | VIEW | When a leak changes lives; not when `lives_cost` is 0 | none |
| TowerSim | `gold_changed(current: int)` | VIEW | After a build, upgrade, bounty or early-call bonus commits | none |
| TowerSim | `tower_built(slot_index: int, tower_id: StringName)` | VIEW | After `gold_changed`, from `build()` | none |
| TowerSim | `tower_upgraded(slot_index: int, level: int)` | VIEW | After `gold_changed`, from `upgrade()`; `level` as `slot_state()` reports it | none |
| HeroSim | `hero_pinned(position: Vector2)` | VIEW | From `pin()`, after the pin target is set | none |
| HeroSim | `burst_started(aim_point: Vector2, telegraph_ticks: int)` | VIEW | From `burst()`, after the burst state is set | none |
| Combat | `attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)` | VIEW | From `report_attack`, before the attack's `deliver` calls | none |
| Combat | `damage_applied(event: DamageEvent, applied: float, position: Vector2, killed: bool, spawn_id: int)` | VIEW | From `deliver`, after HP, dead state and counters commit | none |
| InputResolver | `pressed(best_tap: int, best_drag: int, p: Vector2)` and the seven others in Decision 3 | INPUT | Payloads and order: ADR-0008 (B2 sketch stands) | none |

Rules for payloads:
- `Vector2`, `int`, `float`, `bool`, `StringName` and enums are values, so a listener gets a copy and cannot move an enemy by writing to it (TR-combat-010 "copied positions").
- `damage_applied` is the one payload that carries an object (`DamageEvent`, holding a `Targetable`). A listener must never write to it or keep it past the handler. ADR-0009 may replace it with plain values; if so, it amends this row.
- Durations keep the unit their GDD gives: seconds as `float` in `wave_cleared` and `wave_called_early`, ticks as `int` in `burst_started`. A seconds payload is never used as a countdown; the listener converts it with `to_ticks` (ADR-0004).
- Sim signal handlers are named `_on_<signal>` on the listener, so the catalogue names the target method.

### 5. Final signal names (QQ-07)
The project rule is `naming.signals: past_tense` (`project.yaml`; `technical-preferences.md`: snake_case past tense).

| Old name (GDD) | Final name | Why |
|---|---|---|
| `tap(best_tap, p)` | `tapped(best_tap, p)` | Past tense. Same name as `TapScreen.tapped`, on another class; the catalogue keys by class and name |
| `ground_tap(p)` | `ground_tapped(p)` | Past tense |
| `idle()` | `became_idle()` | Past tense, and `idle` reads as a state, not an event |
| `waves_complete()` | `waves_completed()` | Past tense |
| `phase(value)` | `phase_changed(value)` | Already renamed by architecture.md (TD-ARCHITECTURE B1); confirmed here |
| `pressed(...)` | `pressed(...)`, **kept** | Already a past-tense verb, as in Godot's own `BaseButton.pressed`. QQ-07 listed it in error |

No exception to the naming rule is recorded. Every other battle signal name already fits.

### 6. ID types across signals (QQ-04)
- **Catalogue IDs are `StringName`** in every signal, query result and command parameter: `tower_id`, `source_id`, `def_id`, enemy type keys in `got_through_by_type()`, `burst_id`. This matches ADR-0002's record IDs and ADR-0005's keys.
- **Runtime IDs are `int`**: `spawn_id`, `slot_index`, resolver target ids (`best_tap`, `best_drag`, `NONE = -1`), `level`, `telegraph_ticks`.
- **`String` is never an ID.** It carries only human text: `latched(cause: String)` (ADR-0001), dev-error messages, `ValidationError.detail`.
- GDScript converts a `String` to a typed `StringName` parameter silently, and `"a" == &"a"` is true (E3), so recording fakes take untyped parameters and check `typeof()` per argument (Decision 8).

### 7. Listeners never command: the command guard
ADR-0004 refuses commands inside a tick. Some signals fire from commands, between ticks (`hero_pinned`, `burst_started`, `gold_changed`, `tower_built`, `tower_upgraded`, `wave_called_early`, `phase_changed` on Start or Call), where `in_tick()` is false, so a view that commanded there would not be stopped.
- **Each command holds the `TickGuard` for its body**: it checks `in_tick()` first and refuses as ADR-0004 says; otherwise it calls `enter()`, runs a private body, calls `exit()` on every return path and returns the result. Any command called from a handler of a signal that a command or a tick fired is then refused with `ERR_COMMAND_IN_TICK` and changes nothing. The Builder injects `TickGuard.enter` and `TickGuard.exit` as method Callables into Flow, TowerSim and HeroSim beside `in_tick`.
- `Flow.pause()` and `Flow.resume()` stay outside the guard (ADR-0004 Decision 5 already handles a pause during a tick).
- This changes ADR-0004 Decision 6 ("commands hold the guard for their body"), so it needs a dated amendment to ADR-0004 on acceptance. Until then, lint L-SIG-4 and test V5 hold the rule.

### 8. The listener-count test (contract for ADR-0007)
The catalogue lives once, as data, in `tests/integration/wiring/battle_signals.gd` (path proposed; ADR-0007 may move it): one entry per signal with emitter class, name, role, parameter names and `typeof` codes, and for WIRING the Battle member and method of the one gameplay listener. Tests read it; game code never does. The Builder still wires by explicit `connect_recorded()` lines, so the parser catches a misspelt signal (Flow Rule 2).

`test_battle_signal_listeners` (headless) builds a battle from the fixture catalogue, then for each public `Battle` member that is a battle object (`flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`, `input_resolver`):
1. **Enumerate**: `member.get_script().get_script_signal_list()` (E1). If E1 shows built-in signals leak in, subtract `ClassDB.class_get_signal_list(&"RefCounted")` from `get_signal_list()` instead.
2. **Declared equals catalogued**: a signal the engine lists but the catalogue lacks fails, naming it (a new signal needs a role before it ships). A catalogue entry the engine does not list fails (a rename). Each entry's parameter names and types must match the engine's `args`.
3. **WIRING**: `member.get_signal_connection_list(name)` must hold exactly one connection whose Callable's object and method match the catalogue; an empty list fails with "signal `<class>.<name>` has no listener". Its `flags` must be 0.
4. **VIEW and INPUT**: the list must be empty headless; a connection means a sim depends on a view signal.
5. **No stray connections**: every connection found is in `battle._wiring.pairs()`, and the record holds nothing else .
6. **Data store**: an instance of `Catalogue` and of `StatAccessor` declares no signals (TR-data-014).

`test_wrapper_view_wiring` (scene integration, desktop): builds a wrapper, then asserts that `view_wiring.pairs()` equals an expected list, every connection on a battle object outside the Builder's record is in `view_wiring`, and every `flags` is 0. The expected list includes the non-sim pairs: `InputAdapter.lifecycle_paused` to `Flow.pause`, `PausedScreen.tapped` to `Flow.resume`, the resolver's INPUT signals to their owners, and TowerInput's two signals to HudLogic.

Both tests read **`Wiring.pairs() -> Array[Dictionary]`**, a read-only copy of `{signal, callable}` per pair: one method added to ADR-0001's `Wiring`.

**Recording fakes** (ADR-0007) take `...args` or untyped parameters and fail on a wrong count or `typeof()`, so payload drift fails a unit test though `emit` checks nothing (E2).

### 9. The result snapshot (TR-hud-012, TR-state-006 shared part)
- **Flow's own result**: `Flow.result() -> StageResult` holds the fields Flow owns: `outcome: Flow.Phase` (WON, LOST or FATAL), `last_wave_started: int` (from the injected `wave_index()`), `lives_left: int`. Flow fills it in the outcome commit, before any emit, and never changes it; before an outcome it returns `null`. Combat's damage is not copied into it; Combat's counters stay readable because `halted()` stops every later change.
- **One snapshot**: `class_name ResultSnapshot extends RefCounted` in `src/core/flow/result_snapshot.gd`, a data holder with no dependency. `Battle.take_result_snapshot() -> ResultSnapshot` (root, so it may read every member) fills it from `flow.result()`, the stage's wave count and `starting_lives`, `combat.dealt_by_kind()` for TOWER, HERO and BURST, `combat.hero_share()`, `enemy_wave.got_through_by_type()`, `tower_sim.slows_applied()`, whether a slow tower was built, and `battle.tick_count()`. ADR-0010 adds the run counters under the same rules.
- **Plain values only**: `int`, `float`, `bool`, `StringName`, enums, and `Dictionary` or `Array` of those, deep-copied and made read-only. No object reference, so the snapshot cannot keep a battle alive and nothing can steer through it.
- **When**: the wrapper polls `flow.phase()` in frame step 3 (ADR-0004 Decision 4). On the first step 3 that finds WON or LOST, it calls `take_result_snapshot()` once and hands the **same instance** to HudLogic (result screen) and RunLog (debug log). Outcomes commit only inside ticks, so this step 3 runs after the outcome's tick, with nothing left to change (every leak counted), and never inside a handler. FATAL shows the Fatal screen (ADR-0001) and takes no snapshot.
- Bots and tests call `take_result_snapshot()` headless after the outcome and get the same values the screen shows.
- HudLogic reveals the text after 400 ms (Lost) or 1,000 ms (Won); the snapshot does not change meanwhile.

### Architecture Diagram

```
Builder (Battle._wiring, WIRING only, flags 0)        Wrapper (view_wiring, flags 0)
 EnemyWave.enemy_leaked ───► Flow._on_enemy_leaked      VIEW signals ─► HudLogic, views, RunLog
 EnemyWave.wave_cleared ───► Flow._on_wave_cleared      INPUT signals ─► HeroInput, TowerInput, HudLogic
 EnemyWave.waves_completed ► Flow._on_waves_completed   lifecycle_paused ─► Flow.pause
 EnemyWave.enemy_killed ───► TowerSim._on_enemy_killed  PausedScreen.tapped ─► Flow.resume
 Flow.wave_called_early ───► TowerSim._on_wave_called_early
 FatalLatch.latched ───────► Flow._on_latched

Emitter: commit all state ─► emit (sync) ─► listeners run ─► if halted(): return
Command: in_tick()? refuse : enter() ─► body (commit, emit) ─► exit()
Frame step 3: phase WON/LOST and no snapshot ─► battle.take_result_snapshot()
                                              ─► same instance ─► ResultScreen, RunLog
```

### Key Interfaces

```gdscript
# Sim signals: exactly the signatures in the Decision 4 table.
class_name EnemyWave extends RefCounted
signal waves_completed()                      # was waves_complete (QQ-07)

class_name Flow extends RefCounted
func result() -> StageResult                  # null before the outcome; fixed after
# Handlers: _on_enemy_leaked, _on_wave_cleared, _on_waves_completed, _on_latched

class_name StageResult extends RefCounted     # src/core/flow/stage_result.gd, read-only by contract
var outcome: Flow.Phase
var last_wave_started: int
var lives_left: int

class_name TowerSim extends RefCounted
signal tower_built(slot_index: int, tower_id: StringName)   # QQ-04: StringName
# Handlers: _on_enemy_killed, _on_wave_called_early

class_name InputResolver extends RefCounted   # payloads: ADR-0008
signal pressed(best_tap: int, best_drag: int, p: Vector2)
signal tapped(best_tap: int, p: Vector2)      # was tap
signal ground_tapped(p: Vector2)              # was ground_tap
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(best_drag: int)
signal became_idle()                          # was idle

class_name ResultSnapshot extends RefCounted  # src/core/flow/result_snapshot.gd; plain values only
# outcome, last_wave_started, wave_count, lives_left, starting_lives: int or Flow.Phase
# damage_towers, damage_hero, damage_burst, hero_share: float
# got_through: Dictionary (StringName -> int, read-only copy); slow_tower_built: bool
# slows_applied, tick_count: int

# Battle (root) addition:  func take_result_snapshot() -> ResultSnapshot
# Wiring (ADR-0001) addition: func pairs() -> Array[Dictionary]   # read-only copy
# Injected (B9 additions): TickGuard.enter, TickGuard.exit -> Flow, TowerSim, HeroSim
```

Combat's two signals keep B6's signatures. Names are proposed; QQ-16 may add a class prefix (ADR-0007).

### Implementation Guidelines
1. Every battle signal must be declared with typed parameters as in Decision 4 and emitted with `sig.emit(...)` in the call that changed the state. `emit_signal("...")` and string `connect("...")` must never appear in `src/` (lint L-SIG-1).
2. Every connection must go through `Wiring.connect_recorded()` with no flags. `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT`, a deferred emit and `await` on a battle signal must never appear in `src/` (lint L-SIG-2).
3. An emitter must commit all state before its first emit, emit in the catalogue's order and check `halted()` after each emit in a tick. A refusal must change and emit nothing.
4. The Builder must connect each WIRING signal to exactly its one gameplay listener, and must never connect a VIEW or INPUT signal.
5. A VIEW signal handler must only copy the payload, mark data dirty or call read-only queries. It must never call a command, a mutating method, the stat accessor, or keep a payload object or query list past the handler. Presentation code must never assign to a field of a `Battle` member (lint L-SIG-3).
6. Presentation code must issue commands only from INPUT signal handlers and presentation signals, never from a handler of a WIRING or VIEW signal, and never from `drag_cancelled` or `became_idle` (lint L-SIG-4, by handler name `_on_<signal>`).
7. Each command must check `in_tick()`, then hold the `TickGuard` with `enter()` and `exit()` around a private body, with `exit()` on every return path (Decision 7, once ADR-0004 is amended).
8. Catalogue IDs in signals, queries and commands must be `StringName`; runtime IDs `int`; `String` never carries an ID (lint L-SIG-5: no `String`-typed parameter named `*_id`).
9. Sim signal handlers must be named `_on_<signal>` and must be method Callables on `Battle` members (ADR-0001).
10. A new battle signal must get a catalogue entry and role in the same change, or the listener-count test fails.
11. The result screen and the run log must take the one `ResultSnapshot` the wrapper builds in frame step 3; neither may read the sims for result values (lint L-SIG-6 on ResultScreen and RunLog files).
12. Recording fakes must check argument count and `typeof()` against the catalogue, not only call counts.

## Alternatives Considered

### Alternative 1: Deferred view signals
- **Description**: views connect with `CONNECT_DEFERRED` so they run after the tick.
- **Pros**: a view handler never runs inside a tick.
- **Cons**: the call lands after `_process`, after step 3 drew the old state, so views lag a frame and payloads describe a state that has moved on; ADR-0005's mark-dirty rule already handles in-tick signals.
- **Rejection Reason**: TR-enemy-004 bans it for gameplay signals, and for views it trades a clear rule for a frame of lag.

### Alternative 2: Record an exception for the old names
- **Description**: keep `tap`, `ground_tap`, `idle`, `waves_complete` and note an exception to the past-tense rule.
- **Pros**: no GDD edits; the Input GDD's 40-odd test lines stay as written.
- **Cons**: the rule gets holes later signals can cite; `idle` reads as a state.
- **Rejection Reason**: renaming is cheapest now, before ADR-0008 and any test.

### Alternative 3: `String` or `int` IDs in signals
- **Description**: `tower_id: String`, or an `int` index into a record list.
- **Pros**: `String` prints plainly; `int` compares fast.
- **Cons**: `String` converts at each boundary and its drift from `StringName` is invisible to `==`; `int` needs an index table, breaks when the manifest order changes and makes logs unreadable.
- **Rejection Reason**: records and keys are already `StringName` (ADR-0002, ADR-0005).

### Alternative 4: One flat allowlist of signals that may have no listener
- **Description**: a set of signal names exempt from the listener-count check, as the GDDs word it.
- **Pros**: smallest rule.
- **Cons**: says nothing of what a listener may do.
- **Rejection Reason**: roles give the same exemption and also fix who may steer.

### Alternative 5: HudLogic builds the snapshot in its `phase_changed` handler
- **Description**: the HUD hears `phase_changed(LOST)` and copies the result then.
- **Pros**: no wrapper code.
- **Cons**: the handler runs inside the tick; ADR-0005 bans reads in sim handlers; bots have no HUD.
- **Rejection Reason**: one function on `Battle`, called in step 3, serves screen, log and bots alike.

### Alternative 6: Rule and lint only, no command guard
- **Description**: rely on Guideline 6's lint and review for between-tick emits.
- **Pros**: no ADR-0004 amendment; no two extra injected Callables.
- **Cons**: a lint by handler name misses a helper the handler calls; the bug is silent and order-dependent.
- **Rejection Reason**: one `enter()` and `exit()` pair per command makes the rule mechanical for six commands.

## Consequences

### Positive
- One table says what each signal carries, who hears it and what the hearer may do.
- A misspelt, renamed, unwired or retyped signal fails a headless test with its name in the message.
- Views cannot change a result: they have no sim listeners, no command path and no mutation path, and a battle with all of them removed matches (TR-hud-004, TR-tower-012, TR-combat-010).
- Screen, log and bots read one snapshot, so they cannot disagree.

### Negative
- Seven GDDs and the systems index need name edits (Migration 2); architecture.md needs sync edits.
- ADR-0004 and ADR-0001 each need a small dated amendment (command guard; `Wiring.pairs()`).
- The catalogue is a second copy of every signal line. The test keeps it honest, but a new signal costs two edits.
- `damage_applied` still carries an object until ADR-0009 decides.

### Neutral
- `phase_changed` has no sim listener; only `wave_called_early` and `latched` link two sims besides Enemy & Wave's four.

## Risks
- **E1 fails** (built-ins leak in, or base-script signals go missing): use Decision 8's `ClassDB` subtraction.
- **E2 or E3 differ** (`emit` does check types on 4.7.2): no change; the fakes still check.
- **E5 differs** (listener order unstable): no result depends on it; views must not assume an order.
- **A view handler reaches a command through a helper**: the command guard refuses it once ADR-0004 is amended; until then test V5 catches it in the paths tests run.
- **The catalogue and the code drift apart**: the test fails both ways (Decision 8 step 2).
- **A GDD edit is missed and a story uses an old name**: the parse check fails on a missing signal; Migration 2 lists every file.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-014: the data store emits no signals; each emitter declares its own and the root wires them | Decision 8 step 6 (Catalogue and StatAccessor declare none); Decision 4 (each emitter declares its own); Builder wiring (ADR-0001). **Full** |
| game-state-stage-flow.md | TR-state-008: Flow listens to sync `wave_cleared`, `waves_complete`, `enemy_leaked` (leak before complete) and emits `lives_changed`, `phase`, `wave_called_early` | Decisions 1, 2, 4: the four WIRING links, sync, leaks in the advance slot before the reap-slot clear; Flow's three signals with typed payloads; names now `waves_completed` and `phase_changed`. **Full** |
| game-state-stage-flow.md | TR-state-006 (shared with ADR-0004): result readable after the outcome; phase signals | Decision 9: `StageResult` filled at the outcome commit and fixed; `ResultSnapshot` for the cross-system values; Decision 4: `phase_changed` once per change, outcome order. **Partial by design**: ADR-0004 covers the pure machine and gate |
| combat-damage.md | TR-combat-010: view-only `attack_fired`, `damage_applied` emit after commit with copied positions; listeners never call `deliver`; results match with or without listeners | Decisions 2, 3, 4: VIEW role, value payloads, commit first; Guideline 5; test V4. **Full** (the `DamageEvent` object in the payload is noted for ADR-0009) |
| enemy-wave.md | TR-enemy-004: the four signals fire sync (no `CONNECT_DEFERRED`) in `spawn_id` order after commit; leaks before the clear | Decisions 1, 2, 4; Decision 8 step 3 checks `flags` 0. **Full** |
| tower-system.md | TR-tower-004: commit before `gold_changed`, then `tower_built` or `tower_upgraded`; a refusal changes and emits nothing | Decision 2; Guideline 3; test V3. **Full** |
| tower-system.md | TR-tower-012: typed signatures (`tower_id` type undecided); gameplay does not depend on them; results match without listeners | Decisions 4, 6 (`tower_id: StringName`); VIEW role with no Builder connection; test V4. **Full** |
| hero-system.md | TR-hero-008: `hero_pinned`, `burst_started` emit after state is set, are on the view allowlist; handlers never command | Decisions 3, 4, 7; Guidelines 5, 6. **Full** |
| battle-hud.md | TR-hud-004: the HUD holds presentation state only; sim state identical with or without the HUD | Decision 3 (view-only listener rules); test V4 compares full state with and without view listeners. **Full** (no reset path: ADR-0001 rebuild) |
| battle-hud.md | TR-hud-010: the HUD reads via signals and view-only queries; `phase` and `lives_changed` join the allowlist | Decision 3 puts both in VIEW; the HUD read surface stays B10 (queries owned by their GDDs, ADR-0010). **Full** for the signal side |
| battle-hud.md | TR-hud-012: result screen and log come from one snapshot built the frame after the outcome | Decision 9. **Full** |

## Performance Implications
- **CPU**: one call per listener per emit; `damage_applied` and `attack_fired` are the busiest, well inside ADR-0004's 2.0 ms tick slice. The guard adds two calls per command; the snapshot runs once per attempt.
- **Memory**: one snapshot (a few dozen values) per attempt; the catalogue lives in tests only.
- **Load Time**: none.
- **Network**: none.

## Migration Plan
No code exists. On acceptance:
1. **ADR amendments** (dated, by section, status stays Accepted): ADR-0004 Decision 6 and Key Interfaces (commands hold the guard; `enter` and `exit` injected). ADR-0001 Key Interfaces (`Wiring.pairs()`). The user confirms each.
2. **GDD renames** (due with acceptance, before any test uses them):
   - `input-gesture-resolver.md`: `tap` to `tapped`, `ground_tap` to `ground_tapped`, `idle` to `became_idle` everywhere (Rules 2 to 8, 13, the States and Transitions table and its note, Interactions, Acceptance Criteria, Open Questions); `pressed` stays.
   - `battle-hud.md`: `tap(...)`, `ground_tap`, `idle` (Rules 8, 14; Interactions; Dependencies; AC 7); `phase` to `phase_changed` (Interactions, the allowlist line); Rule 15 "the frame after the outcome" reads "the first frame view step after the outcome's tick" (Decision 9).
   - `enemy-wave.md`: `waves_complete` to `waves_completed` (Rule 11, States table, Interactions, Edge Cases, Acceptance Criteria).
   - `game-state-stage-flow.md`: `waves_complete` to `waves_completed`; `phase` to `phase_changed` (Rules 13, 15, 15a; Interactions; Dependencies); Rule 15 result: Combat's damage is read through the snapshot, not copied into Flow's result.
   - `tower-system.md`: `phase` to `phase_changed` (Rule 8 table, Rule 17); `tap` to `tapped` (Interactions, Dependencies); `waves_complete` (one line).
   - `hero-system.md`: `idle` to `became_idle` (Dependencies row, AC 13).
   - `data-config-pipeline.md`: `waves_complete` to `waves_completed` ("Not owned" paragraph).
   - `systems-index.md`: `waves_complete` (one line).
3. **architecture.md** sync items are listed under Related.
4. **tr-registry.yaml**: TR-state-008, TR-enemy-004 and TR-hud-010 quote old names; revise their text with acceptance, keeping the IDs.

## Validation Criteria
- **V1 `test_battle_signal_listeners`**: Decision 8 steps 1 to 6 pass on the fixture battle; a fixture that drops one Builder line fails naming that signal; a fixture that adds an uncatalogued signal fails naming it; one with a changed parameter type fails.
- **V2 `test_wrapper_view_wiring`** (scene, desktop): `view_wiring.pairs()` equals the expected list, including `lifecycle_paused` to `Flow.pause` and `PausedScreen.tapped` to `Flow.resume`; no connection outside the two records; every `flags` 0.
- **V3 commit order**: for build, upgrade, a leak to Lost, a clear to Won, an early call and a pin, a recording fake that reads the relevant queries inside each handler sees the final state, and the log order matches Decision 4. A refusal logs nothing.
- **V4 listeners removed**: one scripted battle runs with no view listeners, then with fakes on every VIEW and INPUT signal that call every read-only query; ADR-0007's state snapshot is equal after every tick.
- **V5 hostile listener**: a fake on each VIEW signal calls each command inside its handler; every call returns the in-tick refusal and changes nothing (needs Decision 7).
- **V6 payload types**: each recording fake checks `typeof()` per argument; a test emits `tower_built` with a `String` id and expects the fake to fail.
- **V7 snapshot**: after a fatal leak, the snapshot counts that leak; screen and log share one instance; a later frame does not rebuild it; it holds no `Object`; bots read the same values headless.
- **V8 lints**: L-SIG-1 to L-SIG-6 each fail on a planted sample.
- **E1 to E5** probes recorded in the engine reference.

## Reviews still owed
- **godot-specialist**: not run (no review subagents here). To check: E1 to E5, the `ClassDB` fallback, typed enum signal parameters, `make_read_only()` on nested containers, any 4.7.2 signal change the reference omits.
- **TD-ADR** (`technical-director`): not run. To check: the three roles against Principle 4, the command guard as an ADR-0004 amendment, `StageResult` losing damage (B0, Seams), the snapshot on `Battle`, the rename list.

## Related
- Depends on ADR-0001, ADR-0003, ADR-0004, ADR-0005 (all Accepted). Amends ADR-0001 (`Wiring.pairs()`) and ADR-0004 (Decision 6) on acceptance. Enables ADR-0007, ADR-0008, ADR-0009, ADR-0010.
- GDDs: the eight MVP GDDs listed in Migration 2 and GDD Requirements Addressed.
- **architecture.md sync items** (not made here): Module Ownership InputResolver row (signal names), Flow row (`waves_completed`), EnemyWave row, Wiring row (`pairs()`); Data Flow 3 (`waves_completed`; `phase_changed` listeners are HUD and TowerInput only, drop TowerSim and the BattleWrapper per ADR-0004; rule 4 reads as Decision 3's roles; rule 5: QQ-04 settled); B0 `StageResult` row (no damage) and a new `ResultSnapshot` row; B2 and B7 signal names and the QQ-07 notes; B4 `take_result_snapshot()`; B8 `tower_id` note; B9 `TickGuard.enter` and `exit`; Seams table (Stage Progression reads the snapshot); Required ADRs (ADR-0006 written, Proposed; TR-state-006 shared); QQ-04 and QQ-07 resolved.
