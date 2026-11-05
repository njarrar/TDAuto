# ADR-0006: Battle Signal Contracts and View Allowlist

## Status
Accepted

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation.

## Date
2026-11-04

## Last Verified
2026-11-04 (against `docs/engine-reference/godot/` for Godot 4.7.2, `architecture.md` v4, ADR-0001 to ADR-0005 as Accepted, `tr-registry.yaml`, `docs/registry/architecture.yaml` and the eight MVP GDDs; revised after godot-specialist and TD-ADR reviews)

## Decision Makers
- Accepted: 2026-11-04 by the user (njarrar), with the dated ADR-0001 and ADR-0004 amendments, the signal renames, and the Flow Rule 15 and HUD Rule 15 result change
- Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`, 2026-11-04)
- godot-specialist: CONCERNS. TD-ADR: CONCERNS. Findings resolved under Reviews; D7 and the `StageResult` choice made by the coordinator.
- Acceptance: the user.

## Summary
Battle systems talk through Godot signals, and the GDDs leave open how signals fire, what they carry, what they are called and who may listen. This ADR fixes one signal table with typed payloads, sync emit only, commit before emit, three listener roles that form the view allowlist, final names (QQ-07), `StringName` and `int` IDs (QQ-04), a command guard so no handler can steer, a listener-count test contract, and one result snapshot for screen, log and bots.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Core (scripting, signals) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM. The signal APIs date from 4.0 and `breaking-changes.md` lists no 4.4 to 4.7 change to them, but no file in `docs/engine-reference/godot/` covers signals, so probes E1 to E6 check each behaviour here. All six are verified 4.7.2 headless and match (`docs/engine-reference/godot/probe-results.md`). |
| **References Consulted** | `VERSION.md`; `breaking-changes.md` (4.4 to 4.7); `deprecated-apis.md` (string `connect()`); `current-best-practices.md` (4.5 rest parameters; 4.7 typed-return overrides). `architecture.md` v4; `tr-registry.yaml`; ADR-0001, ADR-0003, ADR-0004, ADR-0005 |
| **Post-Cutoff APIs Used** | Rest parameters (`...args`, 4.5) in fakes only; the 4.7 typed-return override rule applies to any fake that overrides a typed method (return on every path). All else dates from 4.0: typed `signal` parameters, `Signal` methods, `get_signal_list`, `get_signal_connection_list`, `get_property_list`, `get_script_signal_list`, `ClassDB.class_get_signal_list`, `typeof()`, `make_read_only()`. |
| **Verification Required** | Probes E1 to E6 (Validation Criteria) are verified 4.7.2 headless (`docs/engine-reference/godot/probe-results.md`); all match. They still become CI tests (ADR-0007 Decision 7). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted; amended 2026-11-04: `Wiring.pairs()`): `Wiring` records, method Callables, `halted()` after emits, `request_retry()` latch. ADR-0003 (Accepted): `lifecycle_paused`, `TapScreen.tapped`. ADR-0004 (Accepted; amended 2026-11-04: Decision 6, Guideline 7): tick order, `TickGuard`, commit order, clock poll. ADR-0005 (Accepted): no accessor read in a sim handler. |
| **Enables** | ADR-0007 (listener-count test, recording fakes, lints L-SIG-1 to L-SIG-5; TR-state-013 is ADR-0007's, with Decision 8 as its contract), ADR-0008 (resolver signal names fixed here; payloads stay ADR-0008's), ADR-0009 (`damage_applied` payload), ADR-0010 (command guard, result codes, run counters, run log), ADR-0011 (VIEW listeners through `view_wiring`; views never command or keep payloads) |
| **Blocks** | Every story that declares, emits or connects a battle signal. No epic or story exists yet, so none is blocked by path today. |
| **Ordering Note** | Before ADR-0007 and ADR-0008. The two amendments and the GDD renames take effect with acceptance. |

## Context

### Problem Statement
Eight GDDs declare signals in prose. Some names break the past-tense rule (QQ-07); `tower_id`'s type is open (QQ-04); "Flow's view allowlist" is named but never listed; the listener-count test has no method. GDScript checks payloads late or not at all, so a wrong name or type passes a parse check and fails in play.

### Constraints
- One thread, no autoloads, no event bus; every sim connection is a recorded method Callable (ADR-0001).
- Commands run only between ticks (ADR-0004). Views may read but never change a result (Principle 4).
- No code exists yet, so names change at no cost now.

### Requirements
TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012, and the shared part of TR-state-006 (result contents, phase signals) from ADR-0004.

## Decision

### 1. Sync emit only
- Every battle signal fires with `sig.emit(...)` on the emitter's own `Signal`, in the call that changed the state.
- Every connection goes through `Wiring.connect_recorded()` with no flags. Banned in `src/`: `CONNECT_DEFERRED` (the call lands after `_process`, when its tick has moved on; ADR-0004 E7), `CONNECT_ONE_SHOT` (Godot drops the connection behind the record's back), `CONNECT_REFERENCE_COUNTED`, `add_user_signal`, `emit_signal("...")`, string `connect("...")`, `call_deferred` around an emit, and `await` or `Tween.tween_await()` on a battle signal.
- `connect_recorded()` checks the `Error` that `connect()` returns and reports anything but `OK` to the dev-error sink, without recording the pair.

### 2. Commit, then emit
- An emitter commits every state change of the action, counters included, before its first emit, so a handler that reads a query sees the final state (Combat AC 12).
- When one action emits more than once, the order is fixed (Decision 4). Tower: `gold_changed`, then `tower_built` or `tower_upgraded`. Flow outcome: set lives and phase, `cancel_input()`, then `lives_changed` if lives moved, then `phase_changed`.
- A refusal changes nothing and emits nothing.
- After each emit inside a tick, the emitter checks `halted()` and returns when true (ADR-0001 Guideline 9).
- A WIRING listener may change its own state and emit its own signals; that nested chain ends before the outer emitter goes on. It never calls the emitter's mutating API.

### 3. Three listener roles: the view allowlist
Every battle signal has one role, stored in the signal table (Decision 8).

| Role | Signals | Listeners | No listener headless? | What a listener may do |
|---|---|---|---|---|
| **WIRING** | `enemy_leaked`, `enemy_killed`, `wave_cleared`, `waves_completed`, `wave_called_early`, `latched` | Exactly one gameplay listener, in the Builder's record; views may add more through `view_wiring` | **No**: the test fails | The gameplay listener changes its own state and emits its own signals; view listeners follow the VIEW rules |
| **VIEW** (allowlisted) | `phase_changed`, `lives_changed`, `gold_changed`, `tower_built`, `tower_upgraded`, `hero_pinned`, `burst_started`, `attack_fired`, `damage_applied` | View-only listeners through `view_wiring`. No sim listens | Yes; headless they have **none** | Copy the payload, mark dirty, call read-only queries. Never a command; never a mutating method or field write on a sim member (`flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`, `stat_accessor`, `halt_gate`); never the accessor; never keep a payload object or list |
| **INPUT** (allowlisted) | Resolver: `pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `became_idle` | Input owners (HeroInput, TowerInput, HudLogic) through `view_wiring` | Yes; headless none | Owners may issue commands; the guard (Decision 7) refuses any that `cancel_input()` would trigger inside a tick. ADR-0008 narrows this: no command from `drag_cancelled` or `became_idle` (amendment) |

- **View-only listeners are every node under the BattleWrapper**, the wrapper's own handlers included (for example its `phase_changed(PAUSED)` handler), ChipWindow, the TapScreens, RunLog, GestureLog, and later Audio, plus test recording fakes. Input owners are view-only too, except that they may command from INPUT and presentation signal handlers.
- **Resolver registry**: any handler of an input owner may call `register`, `unregister`, `set_enabled` and `set_centre` (B2 makes them legal in handlers). No listener ever calls `cancel()` or `cancel_pointer()`; those belong to the adapter, `cancel_input()` and AppRoot.
- **Presentation signals** on wrapper nodes go through `view_wiring`: `InputAdapter.lifecycle_paused()` to `Flow.pause`, the Paused TapScreen's `tapped()` to `Flow.resume` (ADR-0003), TowerInput's `slot_tapped(slot_index)` and `tower_inspected(slot_index)` to HudLogic. Retry calls `AppRoot.request_retry()`.
- `phase_changed` is VIEW: HeroSim uses `in_build()`, the clock polls `clock_running()`, and the chip is TowerInput, a view.

### 4. Signal table: names and typed payloads
Parameter names and types are part of the contract.

| Emitter | Signal | Role | Fired | Gameplay listener |
|---|---|---|---|---|
| EnemyWave | `enemy_leaked(lives_cost: int)` | WIRING | Advance slot, per leak, by `spawn_id`, after it leaves the roster | `Flow._on_enemy_leaked` |
| EnemyWave | `enemy_killed(bounty: int)` | WIRING | Reap slot, per corpse, by `spawn_id`, after `bounty` is read | `TowerSim._on_enemy_killed` |
| EnemyWave | `wave_cleared(intermission_duration: float)` | WIRING | Reap slot, after the tick's leaks and kills; seconds | `Flow._on_wave_cleared` |
| EnemyWave | `waves_completed()` | WIRING | Same slot, last wave by index, in place of `wave_cleared` | `Flow._on_waves_completed` |
| Flow | `wave_called_early(seconds_left: float)` | WIRING | From `call_early()`, after the next wave starts; then `phase_changed(WAVE)` | `TowerSim._on_wave_called_early` |
| FatalLatch | `latched(cause: String)` | WIRING | Once, first `fatal()`, after the forward (ADR-0001) | `Flow._on_latched` |
| Flow | `phase_changed(value: Flow.Phase)` | VIEW | Once per change of phase; on resume with the restored phase | none |
| Flow | `lives_changed(current: int)` | VIEW | When a leak changes lives; not when `lives_cost` is 0 | none |
| TowerSim | `gold_changed(current: int)` | VIEW | After a build, upgrade, bounty or early-call bonus commits | none |
| TowerSim | `tower_built(slot_index: int, tower_id: StringName)` | VIEW | After `gold_changed`, from `build()` | none |
| TowerSim | `tower_upgraded(slot_index: int, level: int)` | VIEW | After `gold_changed`, from `upgrade()`; `level` as `slot_state()` reports it | none |
| HeroSim | `hero_pinned(pin_position: Vector2)` | VIEW | From `pin()`, after the pin target is set | none |
| HeroSim | `burst_started(aim_point: Vector2, telegraph_ticks: int)` | VIEW | From `burst()`, after the burst state is set | none |
| Combat | `attack_fired(source_kind: Combat.SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)` | VIEW | From `report_attack`, before its `deliver` calls | none |
| Combat | `damage_applied(source_kind: Combat.SourceKind, source_id: StringName, applied: float, hit_position: Vector2, killed: bool, spawn_id: int)` | VIEW | From `deliver`, after HP, dead state and counters commit | none |
| InputResolver | the eight INPUT signals | INPUT | Payloads and order: ADR-0008 | none |

- `Vector2`, `int`, `float`, `bool`, `StringName` and enums are values, so a listener gets a copy (TR-combat-010). `hit_position` and `pin_position` avoid a name that reads as a `Node2D` property.
- `damage_applied` carries plain values only (amended 2026-11-04 with ADR-0009 Decision 6): no listener reaches an enemy or a reused `DamageEvent`.
- Durations keep their GDD unit: seconds as `float` in `wave_cleared` and `wave_called_early`, ticks as `int` in `burst_started`. A listener turns seconds into ticks with `to_ticks` (ADR-0004).
- Sim handlers are named `_on_<signal>`.

### 5. Final signal names (QQ-07)
Rule: `naming.signals: past_tense` (`project.yaml`).

| Old name | Final name | Why |
|---|---|---|
| `tap` | `tapped` | Past tense. Shares a name with `TapScreen.tapped` on another class; the table keys by class and name |
| `ground_tap` | `ground_tapped` | Past tense |
| `idle` | `became_idle` | Past tense; `idle` reads as a state |
| `waves_complete` | `waves_completed` | Past tense |
| `phase` | `phase_changed` | Renamed by architecture.md (TD-ARCHITECTURE B1); confirmed |
| `pressed` | `pressed`, kept | Already past tense, as `BaseButton.pressed`; QQ-07 listed it in error |

No exception to the rule is recorded.

### 6. ID types (QQ-04)
- **Catalogue IDs are `StringName`** in every signal, query and command: `tower_id`, `source_id`, `def_id`, `burst_id`, enemy type keys in `got_through_by_type()`. This matches ADR-0002's record IDs and ADR-0005's keys.
- **Runtime IDs are `int`**: `spawn_id`, `slot_index`, resolver target ids (`NONE = -1`), `level`, `telegraph_ticks`.
- **`String` is never an ID.** It carries only human text: `latched(cause)`, dev-error messages, `ValidationError.detail`.

### 7. Command guard: no handler can steer
Some signals fire from commands between ticks (`hero_pinned`, `burst_started`, the gold and tower signals, `wave_called_early`, `phase_changed` on Start or Call), where `in_tick()` is false. So every public command holds the `TickGuard` for its body (ADR-0004 amendment):
- Shape, one return path: `if in_tick(): return refusal; enter(); var r := _body(...); exit(); return r`. A command called from any handler, inside a tick or inside another command, is refused, changes nothing, reports `ERR_COMMAND_IN_TICK`, which now means "inside a tick or another command", and returns `BUSY` (ADR-0010 Decision 2; amended 2026-11-05).
- The Builder injects `TickGuard.enter` and `TickGuard.exit` as method Callables into Flow, TowerSim and HeroSim beside `in_tick`.
- `enter()` reports a dev error if already entered. `Battle.tick` reports a dev error and resets the guard if it finds it set.
- `Flow.pause()` and `Flow.resume()` call `enter()` and `exit()` only when `in_tick()` is false; no nested enter. A pause during a tick keeps ADR-0004 Decision 5's behaviour (dev error, applies, the tick finishes).

### 8. Listener-count test contract (ADR-0007 builds it)
The **signal table** is test data in `tests/integration/wiring/battle_signals.gd` (proposed): per signal, emitter class, name, role, and per argument name, `type`, `class_name` and the `PROPERTY_USAGE_CLASS_IS_ENUM` bit; for WIRING, the listener's Battle member and method. Game code never reads it; the Builder wires by explicit lines (Flow Rule 2). Tests read `battle._wiring.pairs()` and `wrapper.view_wiring.pairs()`; no `Battle` getter is added.

`test_battle_signal_listeners` (headless) runs on a fresh battle built from the fixture catalogue, with no gdUnit signal monitor or other test listener attached:
1. **Members by reflection**: walk `battle.get_property_list()` for script variables without a leading `_` that hold an `Object`. The seven emitters are `flow`, `combat`, `enemy_wave`, `tower_sim`, `hero_sim`, `fatal_latch`, `input_resolver`; every other member (such as `stat_accessor`, `halt_gate`) must declare no signals. A `Catalogue` instance declares none (TR-data-014).
2. **Enumerate** each emitter's signals with `get_script().get_script_signal_list()` (E1). If E1 shows built-ins leak in, subtract `ClassDB.class_get_signal_list(&"RefCounted")` from `get_signal_list()`.
3. **Declared equals table**: an untabled signal fails, naming it; a tabled signal the engine lacks fails (a rename); each argument's name, `type`, `class_name` and enum bit must match.
4. **WIRING**: `get_signal_connection_list(name)` holds exactly one connection whose Callable's object and method match the table, with `flags` 0; none fails with "signal `<class>.<name>` has no listener".
5. **VIEW and INPUT**: no connection headless.
6. **No strays**: every connection found is in the Builder's `pairs()`, and the record holds nothing else.

`test_wrapper_view_wiring` (scene, desktop): `view_wiring.pairs()` equals an expected list, including the non-sim pairs (`lifecycle_paused` to `Flow.pause`, the Paused TapScreen's `tapped` to `Flow.resume`), the INPUT signals to their owners and TowerInput's two signals to HudLogic; no connection on a battle object lies outside both records; every `flags` is 0.

**Recording fakes** take `...args` or untyped parameters and check count and `typeof()` per argument. Limits: `typeof()` cannot tell an enum from an `int`; an object payload needs an `is` check; an `int` sent for a `float` fails the fake though a typed listener converts it (stricter on purpose). A `String` converts silently to a `StringName` parameter and `"a" == &"a"` is true (E3), so only `typeof()` catches that drift.

### 9. Result snapshot (TR-hud-012, TR-state-006 shared part)
- **`Flow.result() -> StageResult`** keeps only what Flow owns: `outcome` (WON, LOST or FATAL), `last_wave_started` (injected `wave_index()`), `lives_left`. Flow fills it in the outcome commit, before any emit, and never changes it; before an outcome it returns `null`.
- **Per-source damage moves to the snapshot.** Combat's counters stay readable after the outcome, since `halted()` stops every change. This changes Flow Rule 15, Flow's Interactions row for Combat and its Dependencies, and HUD Rule 15: GDD changes that need the user's sign-off at acceptance.
- **`ResultSnapshot extends RefCounted`** (`src/core/flow/result_snapshot.gd`) holds plain values only: `outcome`, `last_wave_started`, `wave_count`, `lives_left`, `starting_lives`, `damage_towers`, `damage_hero`, `damage_burst`, `hero_share`, `got_through` (`StringName` to `int`), `slow_tower_built`, `slows_applied`, `tick_count`. ADR-0010 Decision 5 adds, as plain copies: `towers_built` and every `HeroCounters` field, `ever_pinned`, `repins`, `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `burst_victims`, `burst_kills`, `kills_per_burst` (`Array[int]`), `kills_on_hit_3` (`Array[int]`), each array `make_read_only()` (amended 2026-11-05).
- **`Battle.take_result_snapshot()`** (root) fills it, deep-copies each container and calls `make_read_only()` at each level (it is shallow). `got_through` stays an untyped `Dictionary`: typed `Dictionary[K, V]` (4.4) is unverified offline, as in ADR-0005; V7 checks its types.
- **When**: the first frame step 3 (ADR-0004 Decision 4) whose poll of `flow.phase()` finds WON or LOST takes it once and hands the same instance to HudLogic and RunLog. Outcomes commit only in ticks, so nothing is left to change; it is never built in a handler. FATAL takes none.
- **Result API**: `Battle.take_result_snapshot()` is the result API for bots, tests and Stage Progression. AppRoot may keep the snapshot past teardown, since it holds no object.

### Architecture Diagram

```
Builder record: WIRING signal ─► its one gameplay listener (Decision 4), flags 0
view_wiring:    VIEW and INPUT signals ─► wrapper nodes; lifecycle_paused ─► Flow.pause;
                Paused TapScreen.tapped ─► Flow.resume

Emitter: commit all state ─► emit (sync) ─► listeners ─► if halted(): return
Command: in_tick()? refuse : enter() ─► _body() (commit, emit) ─► exit()
Frame step 3: WON/LOST, no snapshot yet ─► take_result_snapshot() ─► ResultScreen, RunLog
```

### Key Interfaces

```gdscript
# Sim signals: exactly the signatures in the Decision 4 table.
# Resolver signal names (payloads: ADR-0008): pressed, tapped, ground_tapped, drag_started,
#   drag_moved, drag_ended, drag_cancelled, became_idle

class_name Flow extends RefCounted
func result() -> StageResult                 # null before the outcome; fixed after
# Handlers: _on_enemy_leaked, _on_wave_cleared, _on_waves_completed, _on_latched

class_name StageResult extends RefCounted    # src/core/flow/stage_result.gd, read-only by contract
var outcome: Flow.Phase
var last_wave_started: int
var lives_left: int

class_name TowerSim extends RefCounted
# Handlers: _on_enemy_killed, _on_wave_called_early

class_name ResultSnapshot extends RefCounted # src/core/flow/result_snapshot.gd; fields in Decision 9

# Battle (root):  func take_result_snapshot() -> ResultSnapshot
# Wiring (ADR-0001 amendment): func pairs() -> Array[Dictionary]
# Injected (ADR-0004 amendment): TickGuard.enter, TickGuard.exit -> Flow, TowerSim, HeroSim
```

Names are proposed; QQ-16 may add a class prefix (ADR-0007).

### Implementation Guidelines
1. Signals are declared and fired as Decisions 1 and 4 say. `emit_signal`, string `connect` and `add_user_signal` never appear in `src/` (lint L-SIG-1).
2. Connections follow Decision 1: no flags; no `call_deferred` emit; no `await` or `tween_await()` on a battle signal (lint L-SIG-2).
3. Emitters follow Decision 2's commit, order, refusal and `halted()` rules.
4. Listeners follow Decision 3's roles. Presentation code never assigns a field of a sim member (lint L-SIG-3).
5. Commands take Decision 7's shape.
6. IDs follow Decision 6; no `String`-typed parameter named `*_id` (lint L-SIG-4).
7. A new battle signal gets a signal-table row in the same change.
8. ResultScreen and RunLog take result values only from the one `ResultSnapshot` (lint L-SIG-5).
9. Recording fakes check count and `typeof()` per argument (Decision 8).

## Alternatives Considered

### Alternative 1: Deferred view signals
- **Description / Pros / Cons**: views connect with `CONNECT_DEFERRED` and never run in a tick, but lag a frame and see a moved-on state.
- **Rejection Reason**: TR-enemy-004 bans it for gameplay; ADR-0005's mark-dirty rule already covers in-tick views.

### Alternative 2: Record an exception for the old names
- **Description / Pros / Cons**: keep `tap`, `ground_tap`, `idle`, `waves_complete`; no GDD edits, but the rule gets holes later signals can cite.
- **Rejection Reason**: renaming is cheapest now, before ADR-0008 and any test.

### Alternative 3: `String` or `int` catalogue IDs
- **Description / Pros / Cons**: `String` prints plainly but its drift is invisible to `==`; an `int` index compares fast but breaks when the manifest order changes.
- **Rejection Reason**: records and keys are already `StringName`.

### Alternative 4: One flat allowlist
- **Description / Pros / Cons**: a set of names exempt from the listener check; smallest, but says nothing of what a listener may do.
- **Rejection Reason**: roles give the same exemption and fix who may steer.

### Alternative 5: HudLogic builds the snapshot in its `phase_changed` handler
- **Description / Pros / Cons**: no wrapper code, but it runs inside the tick, ADR-0005 bans reads there, and bots have no HUD.
- **Rejection Reason**: one `Battle` function, called in step 3, serves screen, log and bots.

### Alternative 6: Lint only, no command guard
- **Description / Pros / Cons**: no ADR-0004 amendment, but a lint by handler name misses a helper the handler calls.
- **Rejection Reason**: TD-ADR prefers the guard; it makes the rule mechanical.

## Consequences

### Positive
- One table says what each signal carries, who hears it and what the hearer may do.
- A misspelt, renamed, unwired or retyped signal fails a headless test by name.
- Views cannot change a result, so a battle with all of them removed matches (TR-hud-004, TR-tower-012, TR-combat-010).
- Screen, log and bots read one snapshot.

### Negative
- Seven GDDs and the systems index need renames; Flow Rule 15 and HUD Rule 15 need sign-off.
- ADR-0001 and ADR-0004 carry dated amendments.
- The signal table copies every signal line; the test keeps it honest, but a new signal costs two edits.

### Neutral
- `phase_changed` has no sim listener.

## Risks
- **E1 fails** (built-ins leak in, or base-script signals go missing): use Decision 8's `ClassDB` subtraction.
- **E2 or E3 differ** (for example `emit` checks types on 4.7.2): no change; the fakes still check.
- **E5 differs** (listener order unstable): no result depends on it; views must not assume an order.
- **Retry or teardown from inside a battle signal handler** would free objects mid-emit. Never allowed: Retry only sets ADR-0001's `request_retry()` latch, which AppRoot acts on in its own `_process`.
- **The signal table and code drift apart**: the test fails both ways.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-014: data store emits no signals | Decisions 4, 8. Full |
| game-state-stage-flow.md | TR-state-008: Flow's listened and emitted signals | Decisions 1, 2, 4, 5. Full |
| game-state-stage-flow.md | TR-state-006 (shared): result after the outcome; phase signals | Decisions 4, 9. Partial by design (ADR-0004 has the rest) |
| combat-damage.md | TR-combat-010: view-only Combat signals, copied positions | Decisions 2, 3, 4, 7. Full |
| enemy-wave.md | TR-enemy-004: sync, `spawn_id` order, leaks before clear | Decisions 1, 2, 4, 8. Full |
| tower-system.md | TR-tower-004: commit, then gold, then tower signal; refusal silent | Decision 2. Full |
| tower-system.md | TR-tower-012: typed signatures; gameplay independent of listeners | Decisions 3, 4, 6. Full |
| hero-system.md | TR-hero-008: Hero signals after state; handlers never command | Decisions 3, 4, 7. Full |
| battle-hud.md | TR-hud-004: same sim state with or without the HUD | Decisions 3, 7. Full |
| battle-hud.md | TR-hud-010: HUD signals join the allowlist | Decision 3 (queries: B10, ADR-0010). Full for signals |
| battle-hud.md | TR-hud-012: one snapshot for screen and log | Decision 9. Full |

## Performance Implications
- **CPU**: one call per listener per emit, well inside ADR-0004's 2.0 ms tick slice; two calls per command for the guard; one snapshot per attempt.
- **Memory**: one snapshot per attempt; the signal table lives in tests.
- **Load Time** and **Network**: none.

## Migration Plan
No code exists. On acceptance:
1. **Amendments** (dated 2026-11-04, confirmed by the user at acceptance): ADR-0001 (`Wiring.pairs()`); ADR-0004 (Decision 6, Guideline 7).
2. **GDD renames** (the game-designer makes them): in the seven GDDs (`input-gesture-resolver`, `battle-hud`, `enemy-wave`, `game-state-stage-flow`, `tower-system`, `hero-system`, `data-config-pipeline`) and `systems-index.md`, rename every code form of `tap`, `ground_tap`, `idle`, `waves_complete` and `phase` (backticked names, calls such as `tap(T)`, and names in backticked test logs) to Decision 5's names. Plain English ("a tap", "idle") stays. Done when this returns no lines (107 on 2026-11-04):
   ```bash
   grep -nE '`(tap|ground_tap|idle|waves_complete|phase)(\(|`)|[(, ](tap|ground_tap|waves_complete)\(|, idle(`|,)' design/gdd/{input-gesture-resolver,battle-hud,enemy-wave,game-state-stage-flow,tower-system,hero-system,data-config-pipeline,systems-index}.md
   ```
   Also, with the user's sign-off: Flow Rule 15, its Combat Interactions row and Dependencies, and HUD Rule 15 (Decision 9).
3. **architecture.md** (list only):
   - Module Ownership: InputResolver, Flow and EnemyWave rows (names); Wiring row (`pairs()`).
   - Data Flow 3: `waves_completed`; `phase_changed` listeners are wrapper nodes only (no TowerSim, per ADR-0004 no clock link); rules 4 and 5 point here; QQ-04 settled.
   - B0: `StageResult` row (no damage); new `ResultSnapshot` row. B2, B7 names. B4 `take_result_snapshot()`. B8 `tower_id`. B9 `TickGuard.enter`, `exit`.
   - Seams: Stage Progression reads `Battle.take_result_snapshot()`; AppRoot may keep it past teardown.
   - Required ADRs: ADR-0006 written, Proposed. QQ-04, QQ-07 resolved.
4. **tr-registry.yaml** (list only; keep IDs): reword TR-state-008, TR-enemy-004 and TR-hud-010 (old names), TR-tower-012 (`tower_id` settled) and TR-hud-012 (snapshot built in the first view step after the outcome's tick).

## Validation Criteria
- **V1 `test_battle_signal_listeners`**: Decision 8 passes; a missing Builder line, an untabled signal, or a changed argument type, `class_name` or enum bit each fail by name.
- **V2 `test_wrapper_view_wiring`**: as Decision 8, with the two non-sim pairs.
- **V3 commit order**: for build, upgrade, a leak to Lost, a clear to Won, an early call and a pin, a fake reads the queries inside each handler and asserts they show the committed values (gold, tower, lives, phase); the log order matches Decision 4; a refusal logs nothing.
- **V4 listeners removed**: one scripted battle runs with no view listeners, then with fakes on every VIEW and INPUT signal that call every read-only query; the ADR-0007 state snapshot (resolver registry excluded) is equal after every tick, and the fakes' logs hold the expected events.
- **V5 command guard**: a fake on each VIEW and WIRING signal calls each command; inside a tick or a command each returns `BUSY`, reports `ERR_COMMAND_IN_TICK` and changes nothing; a nested `enter()` and a stuck guard at `Battle.tick` each report a dev error; a mid-tick `Flow.pause()` follows ADR-0004 Decision 5.
- **V6 payload types**: emitting `tower_built` with a `String` id fails the fake. The fake takes untyped arguments and checks `typeof()`, since a typed `StringName` parameter takes a `String` silently (E3).
- **V7 snapshot**: counts a fatal leak; one instance for screen and log, never rebuilt; no `Object`; every nested container read-only; `got_through` is `StringName` to `int`; bots read the same values.
- **V8 lints**: L-SIG-1 to L-SIG-5 each fail on a planted sample.
- **Engine probes** (`tests/unit/engine/test_signal_probes.gd`, proposed). Every answer below is verified 4.7.2 headless, see probe-results.md; each probe still becomes a CI test.
  - **E1** `get_script_signal_list()` lists only script signals, base script included, with `name`, `type`, `class_name`, `usage` per argument; an enum reports `TYPE_INT`, its `class_name` and the enum bit.
  - **E2** `emit()` does not check argument types; a wrong count fails at the listener call; a wrong type may convert.
  - **E3** a `String` converts silently to a `StringName` parameter, and `"a" == &"a"` is true.
  - **E4** `get_signal_connection_list()` and `Signal.get_connections()` give `signal`, `callable`, `flags`; `flags` is 0 for a plain `connect()`.
  - **E5** listeners run in connection order; a nested emit finishes before the outer emit's next listener.
  - **E6** a method with a 4.5 rest parameter (`func m(...args)`) works as a connection Callable for a signal of any arity.

## Reviews

godot-specialist: **CONCERNS**. TD-ADR: **CONCERNS**. All findings relayed were applied (G9 was not relayed).

| Finding | Resolution |
|---|---|
| T1 "mutating method" too wide; registry calls needed | Decision 3: sim members only; registry calls allowed, `cancel()` never; V4 excludes the registry |
| T2, G1 pause and resume against the guard | Decision 7 |
| T3 Migration section list fragile | Migration 2: one rule, one grep |
| T4 resolver payloads are ADR-0008's | Key Interfaces: names only |
| T5 `StageResult` and damage | Kept; damage to the snapshot; GDD sign-off flagged; Seams reworded |
| T6 view-only list incomplete | Every node under the BattleWrapper |
| TD advisory (signal table name, reflection, `_wiring` read, E6, TR rewording, TR-state-013 owner, Paused TapScreen, trims) | Applied |
| G2 guard shape | Decision 7: one return path; tick resets a stuck guard |
| G3 enum and class in arg types | Decision 8 |
| G4 `typeof()` limits | Decision 8 |
| G5 more flags; connect errors | Decision 1 |
| G6 `tween_await()` | Decision 1, L-SIG-2 |
| G7 tests assert effects | V3, V4 |
| G8 `position` param name | `pin_position`, `hit_position` |
| G10 post-cutoff list | Engine Compatibility |
| G11 shallow `make_read_only()`; typed Dictionary | Decision 9 |
| G12 test listeners skew counts | Decision 8: fresh battle, no monitors |
| G13 teardown from a handler | Risks |
| D7 (coordinator) keep the guard | Decision 7; ADR-0004 amended; handler lint dropped |

## Amendments
- **2026-11-04, with ADR-0008** (confirmed by the user 2026-11-04 at ADR-0008 acceptance; Status stays Accepted). Decision 3, INPUT row: owners never command from `drag_cancelled` or `became_idle`, the cleanup edges that `cancel()` fires inside a tick or at teardown (ADR-0008 Decision 6).
- **2026-11-04, from verified engine probes** (docs/engine-reference/godot/probe-results.md; Status stays Accepted). Probe E3 confirms that a `String` payload converts silently into a typed `StringName` parameter. Decision 8 already says recording fakes take untyped arguments and check `typeof()`; V6 now says so too. E1 to E6 are marked verified in Engine Compatibility and Validation Criteria.
- **2026-11-04, from the third architecture review; Status stays Accepted** (`architecture-review-2026-11-04.md`, Should fix 5). The Knowledge Risk line now agrees with Verification Required: probes E1 to E6 are verified 4.7.2 headless. Nothing else in this ADR changes.
- **2026-11-04, with ADR-0009** (confirmed by the user at ADR-0009 acceptance); Status stays Accepted. Decision 4, Combat `damage_applied` row: the payload is now plain values, `(source_kind, source_id, applied, hit_position, killed, spawn_id)`, as ADR-0009 Decision 6 sets. The `event: DamageEvent` argument is gone, so no VIEW payload holds an object. Combat Rule 12 and the registry `battle_signal_catalogue` entry change with it.
- **2026-11-05, with ADR-0010 (confirmed by the user at ADR-0010 acceptance); Status stays Accepted.** Decision 7 and V5: the refusal value is `BUSY`; the dev-error text stays `ERR_COMMAND_IN_TICK`. Decision 9: `ResultSnapshot` gains `towers_built` and every `HeroCounters` field (`ever_pinned`, `repins`, `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `burst_victims`, `burst_kills`, `kills_per_burst`, `kills_on_hit_3`) as plain copies, each array read-only. Nothing else in this ADR changes.
- **2026-11-05, from the engine consultation of the fourth review; Status stays Accepted.** Enables and Related add ADR-0011, which depends on this ADR. Nothing else changes.

## Related
- Depends on ADR-0001, ADR-0003, ADR-0004, ADR-0005 (Accepted); amends ADR-0001 and ADR-0004 (confirmed 2026-11-04). Enables ADR-0007 to ADR-0011.
- GDDs: the eight MVP GDDs; sync items in Migration 2 to 4.
