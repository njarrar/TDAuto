# ADR-0006: Battle Signal Contracts and View Allowlist

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Why this is stated here: stories referencing a `Proposed` ADR are set `Blocked`,
> and epics require `Accepted`, so the field needs a named owner.
> `technical-director` is the role `coordination-rules.md` already escalates
> technical conflicts to, and an ADR is that decision made durable.
>
> This does **not** relax the existing rule that `Status: Accepted` is never set
> without explicit user confirmation. It narrows *which agent* may set it once
> that confirmation exists. An agent that believes an ADR is ready says so and
> escalates; it does not edit this field.
>
> **Before acceptance** (none of these needs a story):
> 1. ADR-0001 and ADR-0004 are Accepted.
> 2. V1 to V6 (Engine Compatibility) have recorded results from one headless check
>    script run outside `src/` (`prototypes/adr-0006-signal-check/` or a scratch folder),
>    copied into `docs/engine-reference/godot/current-best-practices.md`. Where a result
>    takes a branch, this ADR is revised to that branch first.
> 3. The GDD, `architecture.md`, ADR-0003 and ADR-0009 edits for Decisions 3 and 4 are
>    applied, or the user overturns them one by one (cascade notes, section d); then
>    `/architecture-review` runs so the TR registry and the traceability matrix pick up
>    the renames. User part MET: the section d choices (items 1 to 15) were confirmed by
>    the user, 2026-11-04, as recommended, so the edits stand. Still open:
>    `/architecture-review`.
> 4. MET: The user has confirmed or overturned each item in Decision 9.
>    Confirmed by the user, 2026-11-04, as recommended (items 1 to 3).
>
> Verification progress, 2026-11-04 (macOS arm64, headless, Godot 4.7.2 editor binary; run
> from `prototypes/adr-checks/`, which replaces `prototypes/adr-0006-signal-check/`): V1 to V6
> are RECORDED in `docs/engine-reference/godot/verification-results.md` (that file stands in
> for `current-best-practices.md` for this run). No branch was taken: emits are depth-first
> and synchronous, connections use snapshots, enum params and the Flow/StageResult cycle parse,
> so the ADR text is unchanged. No verification item remains open; items 1 (ADR-0001 and
> ADR-0004 Accepted) and 3 (`/architecture-review`) still hold acceptance.
>
> Phone checks (user instruction, 2026-11-04): phone testing is set aside for now, and the
> future device is an iPhone. No item here needs a phone; ADR-0004 V6 (whole tick on a
> device, views connected) is after acceptance, on the iPhone. This ADR has no open
> before-acceptance item except ADR-0001 and ADR-0004 being Accepted and
> `/architecture-review`.
>
> Amended 2026-11-05 after /architecture-review.
> (Depends On no longer names ADR-0008 (cycle cut). Decision 5: HudLogic joins P7. Decision 7
> rule 1: Flow owns the wrong-phase wave event checks, TR-state-018.)
>
> **After acceptance:** the listener-count tests (Decision 8) are written by the ADR-0007
> harness story and by the first story that builds `BattleWrapper`. Reopen trigger: if
> the headless test, the wrapper test or the with-and-without-listeners run (Validation
> 2 to 4) shows the contract cannot be met as written, this ADR is amended before the
> next story closes. A phone result that contradicts this ADR reopens it before the next
> story in its area closes.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only (Godot 4.7.2). The live Godot 4.7 documentation was not reachable from the authoring session (`docs.godotengine.org` is outside the session's network policy). The pinned reference covers almost nothing about signals, so every engine behaviour this ADR relies on is a numbered verification item (V1 to V6), not a fact.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS on the first draft, findings T1 to T12 applied in this revision), godot-specialist (engine check: no blocking issues, minor notes applied to V1, V3, V4, V6, Decision 2, Key Interfaces and Risks). Authored with the /architecture-decision flow in autonomous mode.

## Summary

Battle systems talk through Godot signals whose names, payloads, ID types, timing and listeners were spread over seven GDDs, with five names that break the project's past-tense rule, an undecided `tower_id` type, and no rule for which signals may go unheard. This ADR fixes one signal contract for the battle: synchronous emit after commit, connections made only by `BattleBuilder` (sim to sim) or `BattleWrapper.attach` (sim to view), never deferred; final names (`tapped`, `ground_tapped`, `became_idle`, `waves_completed`; `pressed` kept); typed payloads with `StringName` catalogue IDs and `int` slot, spawn and target IDs; a `damage_applied` payload that carries no sim object; `StageResult`; and a listener-count test against a named view allowlist.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM (signals are stable since 4.0 per `breaking-changes.md`, which lists no signal change in 4.4 to 4.7 for the classes used here; but emit-time type checks, introspection return shapes and nested-emit order are not in the pinned reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`. No `modules/` file covers Core, scripting or signals (modules present: animation, audio, input, navigation, networking, physics, rendering, ui). |
| **Post-Cutoff APIs Used** | None. Two pinned facts bear on the decision: `deprecated-apis.md` replaces `connect("signal", obj, "method")` with `signal.connect(callable)` (4.0) and lists string-based `connect()` as a deprecated pattern; `current-best-practices.md` records that a one-argument lambda on a zero-argument signal errors "Method expected 1 argument(s), but called with 0" when the signal fires (observed on 4.6.1), so an arity mismatch shows at call time, not at `connect`. |
| **Verification Required** | V1 to V6 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: emit-time type, arity and conversion behaviour; the shapes of `get_script_signal_list()`, `get_signal_connection_list()` and `Signal.get_connections()`, and their flags; duplicate-connect behaviour; call order and changes to connections during an emit; nested-emit order; enum-typed parameters and cyclic class references. Whether a signal connection holds its target strongly is ADR-0001 V1 and is not repeated here. |

### Verification items

The gap is wired to acceptance: this ADR stays `Proposed` until each item has a recorded result. All six run in one headless script with no game code (`godot --headless -s check.gd` on throwaway `RefCounted` emitters and recording listeners). Owner: godot-specialist writes the script; the user runs it on the pinned 4.7.2 editor and the results go into `current-best-practices.md` with the engine version. The engine check (godot-specialist) expects the results noted below from its own knowledge; that is not a source.

- **V1. Emit-time types and arity.** For `signal s(a: int, b: StringName)`: what do `s.emit("x", "y")`, `s.emit(1.5, &"y")`, `s.emit(1, "y")` and `s.emit(1)` do? Are values silently converted into a typed listener parameter (`String` to `StringName`, `1.5` to `int`)? Does an arity or type error in one listener log and let the emit continue to the next listener? Does the 4.7 analyzer check an `emit()` argument count at parse time? Expected: no type check at emit; a listener error is logged and the emit continues. **No decision depends on the answer**: recording fakes assert payload types with `typeof()`/`is` (Implementation Guidelines, ADR-0007), and tests capture engine errors with gdUnit4's error capture and fail on any.
  - Result (2026-11-04, macOS arm64, headless): no type check at emit; values convert silently into typed listener params (`1.5` arrives as int 1, `String` as `StringName`); an incompatible value or a missing argument logs an error, skips that listener, and the emit continues; the analyzer does not check `emit()` arity; see docs/engine-reference/godot/verification-results.md.
- **V2. Script signal list.** Does `get_script().get_script_signal_list()` return exactly the script-declared signals (own and inherited script classes) as `Dictionary` entries with a `name` key, without `Object`'s `script_changed` and `property_list_changed`? Branch: if unusable, `get_signal_list()` minus the names `RefCounted.new().get_signal_list()` returns.
  - Result (2026-11-04, macOS arm64, headless): own and inherited script signals only, as Dictionaries with `name`; the fallback form gives the same list; see docs/engine-reference/godot/verification-results.md.
- **V3. Connections and flags.** Does `get_signal_connection_list(name)` return `Dictionary` entries with `signal`, `callable` and `flags`, with `callable.get_object()` the target and `callable.get_method()` a `StringName`, and `flags` 0 for a plain `connect`? Does `Signal.get_connections()` return the same shape? Does `CONNECT_DEFERRED` show as a non-zero flag? Expected: a second `connect` of the same Callable pushes an error, returns `ERR_INVALID_PARAMETER` and adds nothing; a connection made in a `.tscn` carries `CONNECT_PERSIST` (2); a freed listener object's connections are dropped automatically.
  - Result (2026-11-04, macOS arm64, headless): entries have `signal`, `callable`, `flags` with the target object and a StringName method; flags 0 plain, 1 deferred; `Signal.get_connections()` has the same shape; a double connect errors (ERR_INVALID_PARAMETER) and adds nothing; `.tscn` connection flags 34 include PERSIST; a freed listener's connections drop; see docs/engine-reference/godot/verification-results.md.
- **V4. Call order and changes during an emit.** With listeners connected A, B, C, does one emit call A, B, C, and after `disconnect(B)` and `connect(B)`, A, C, B? If a listener connects or disconnects during the emit, does the running emit use a snapshot of the list? No outcome depends on order (Decision 7 rule 6) and both changes during an emit are forbidden; the answers fix what test logs may assume.
  - Result (2026-11-04, macOS arm64, headless): ABC, then ACB; a connect or disconnect during an emit works on a snapshot (the running emit is unchanged); see docs/engine-reference/godot/verification-results.md.
- **V5. Nested emit.** If listener A of `s` emits `t`, do all of `t`'s listeners finish before `s` reaches listener B? Is re-emitting `s` from its own listener delivered in full? Decision 5 relies on the first (Flow emits `lives_changed` and `phase_changed` inside `enemy_leaked`); the second is forbidden (Decision 7 rule 7). Branch: if nesting is not depth-first, Flow and TowerSim queue nested emits in a per-emitter outbox drained after the outer emit, and this ADR is revised.
  - Result (2026-11-04, macOS arm64, headless): nested emits are depth-first (A, T1, T2, B); a re-emit is delivered in full (R1, R2, B, B). No outbox branch; see docs/engine-reference/godot/verification-results.md.
- **V6. Enum and cyclic typed references.** Do `signal phase_changed(value: Phase)` in `Flow`, `signal damage_applied(source_kind: SourceKind, ...)` in `Combat`, and `var outcome: Flow.Phase` in `StageResult` (while `Flow` returns `StageResult`) parse and run on 4.7.2? Does `const EMITTER_KEYS: Array[StringName] = [...]` parse? ADR-0009 relies on the same cycle (`DamageEvent.source_kind: Combat.SourceKind`). Branch: enum parameters and fields typed `int` holding the enum value; an untyped const array; names and order unchanged.
  - Result (2026-11-04, macOS arm64, headless): enum-typed signal params and fields and the Flow/StageResult cycle parse and run; `EMITTER_KEYS` parses as a typed, read-only `Array[StringName]`. No branch; see docs/engine-reference/godot/verification-results.md.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed): `BattleBuilder` makes every sim connection in one function as `emitter.signal_name.connect(listener.method)`; no lambdas, no `bind()`, no string forms; no deferred connections; commit then emit; the fatal path ends in `phase_changed(FATAL)`; `BattleWrapper.attach`/`detach`; check `halted()` after every signal. ADR-0004 (Proposed): the tick order (Decision 4), the frame order (Decision 5: commands in step 0, ticks in step 3, views in step 4), `Battle.between_ticks()`, and the wrapper's `_on_phase_changed`. Both must be Accepted before this one. Also binding, not gating: ADR-0002 (record IDs are `StringName`), ADR-0003 (`lifecycle_paused`, `display_changed`), ADR-0009 (Combat and EnemyWave signal declarations). The emitter `battle.resolver` is the member ADR-0001 Decision 5 step 2 creates. |
| **Enables** | ADR-0007 (listener-count test, recording fakes that assert payloads, lint rules from Implementation Guidelines), ADR-0008 (resolver signal names and payload types are fixed here; its internals, queue and state machine are its own), ADR-0010 (command signals and the HUD's result snapshot use the contract), ADR-0011 (views connect in `attach` under these rules). |
| **Blocks** | Every story that declares, emits or listens to a battle signal: Game State & Stage Flow, Enemy & Wave, Combat, Tower, Hero, Input & Gesture Resolver, Battle HUD. |
| **Ordering Note** | ADR-0008 must not be written until this ADR's names (Decision 3) are settled, because the Input GDD's tests use them. The GDD renames (cascade section a) should land before any test file names a signal. ADR-0009 kept `damage_applied(event, ...)` as a working default pending this ADR; Decision 4 replaces it, and ADR-0009 is amended in the same change. |

## Context

### Problem Statement

Seven GDDs declare battle signals; four say "on Flow's view allowlist", which no document defines. Open items block code: QQ-07 (five names break `naming.signals: past_tense`), QQ-04 (the `tower_id` type), ADR-0009's recommendation to stop passing `DamageEvent` to views, and `StageResult`, which B0 assigns here without fields. GDScript signals fail quietly: an unconnected signal does nothing, and the pinned reference does not say whether a wrong payload type is caught. Without one contract, the first deferred connection or state-changing listener breaks the tick order and the "same result with or without views" guarantee the bots rely on.

### Current State

No code exists. `architecture.md` Data Flow 3 lists the signals and five rules; B2 and B5 to B8 sketch declarations; ADR-0001, ADR-0003, ADR-0004 and ADR-0009 (all Proposed) defer naming, payload types and the allowlist here. The GDDs use `tap`, `ground_tap`, `idle`, `waves_complete` and `phase`.

### Constraints

- Godot 4.7.2, GDScript, single main thread (TR-state-003). The battle sim is plain `RefCounted` objects, absent a scene headless.
- ADR-0001: method Callables only; connections in the Builder; no autoload, no global event bus; no mutable `static var`; no RefCounted cycle.
- ADR-0004: commands run only between ticks; tick entries are called only from `Battle._run_steps()`.
- Registry `sim_position_representation`: `Vector2` only at boundaries, view-signal payloads included.
- Registry `listener_stores_damage_event` (ADR-0009): no listener keeps a `DamageEvent` or reads `event.target`.
- GDD acceptance criteria are written as signal logs ("each THEN is the entire log"), so names and payload order are test-visible.
- Solo, part-time developer: the contract must be checkable by one test and a lint, not by review alone.

### Requirements

- Every battle signal fires synchronously, after its state is committed, never deferred (TR-enemy-004, TR-tower-004, TR-hero-008, TR-combat-010).
- Gameplay never depends on a view listener: a battle with every view listener removed gives identical state (TR-tower-012, TR-hud-004, TR-combat-010).
- One test fails when a battle signal has no listener, except signals on a named view allowlist (TR-state-013, owned by ADR-0007; contract here).
- Payloads are typed, with one ID type per kind of ID (TR-tower-012, QQ-04).
- The data store emits no signals (TR-data-014).
- The result screen and log come from one snapshot built the frame after the outcome (TR-hud-012).
- Names follow `naming.signals: past_tense`.

## Decision

### 1. Synchronous emit, commit first, check `halted()` after

1. Every battle signal is emitted with `signal_name.emit(args)` at the point its event happens, synchronously. The string form `emit_signal("name", ...)` is forbidden in `src/` (the parser cannot check it, the same reason ADR-0001 bans string `connect`).
2. **Commit, then emit.** Every state change the event describes, and every counter it affects, is final before the `emit()` call. A listener that reads any query inside its handler sees the post-event state (Tower Acceptance 12, Combat Acceptance 12).
3. **Exactly once per committed event, never on a refusal or a no-op.** A command that refuses changes nothing and emits nothing. A `*_changed` signal fires only when the value differs from before (Flow Rule 11, Tower Rule 14). A dead or removed target emits nothing from `deliver`.
4. **Check after.** An emitter checks the injected `halted()` after every emit and returns at once if it is true, because a listener can end the battle (a leak through Flow, or a view's accessor read that reaches `fatal`). Combat is the one exception ADR-0009 Decision 4 records: Combat injects no `halted()`, which holds only because Decision 7 rule 4 below forbids listeners of Combat's two signals from reading the accessor, so they cannot end the battle.
5. **Order inside a batch** is the emitter's loop order, stated per signal in Decision 5 (for example `spawn_id` ascending for EnemyWave, gold before tower for TowerSim).

### 2. Two places make connections, both with flags 0

| Connection | Made in | Undone in | Examples |
|---|---|---|---|
| **Wiring** (sim to sim) | `BattleBuilder.build`, ADR-0001 step 4, one function, statically typed locals | never (dropped with the battle) | W1 to W5 in Decision 5 |
| **Wrapper** (sim, resolver or adapter to an object the wrapper owns: a node in its subtree or a model it holds, such as HudLogic) | `BattleWrapper.attach`, one function `_connect_signals()` | `BattleWrapper.detach`, one function `_disconnect_signals()`, same list | P1 to P9, G1 to G8, A1, A2 |

- Every connection is `emitter.signal_name.connect(listener.method)` in code with no flags argument. `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT` and `CONNECT_REFERENCE_COUNTED` are forbidden on every battle signal (TR-enemy-004 names deferred; the other two hide a connection's lifetime from the listener-count test). No battle signal is connected in a `.tscn` or the editor (those carry `CONNECT_PERSIST`, V3).
- `attach` runs once per wrapper; a second `connect` of the same Callable is an engine error (V3), which the wrapper test fails on.
- In `src/`, no connection is made or removed anywhere else, and never from inside a signal handler. **Tests are exempt:** code under `tests/` may connect recording fakes, disconnect a wiring edge (Decision 8 step 6) and call test seams such as `add_enemy` from a listener (Enemy & Wave Acceptance 28, ADR-0009 loop rules). Decisions 2 and 7 bind `src/` only. `register`/`unregister` on the resolver are registry calls, not connections, and stay legal in handlers (Input GDD).
- No battle signal is connected to a lambda, a bound Callable or a string-named Callable (ADR-0001).
- The resolver is part of `Battle` (ADR-0001), but all its listeners live in the wrapper, so its signals are wrapper connections.

### 3. Final names (QQ-07)

`naming.signals: past_tense` holds with no exception. Renamed:

| Old (GDD) | New | Emitter | Why this name |
|---|---|---|---|
| `tap` | `tapped` | InputResolver | Past tense of the gesture |
| `ground_tap` | `ground_tapped` | InputResolver | Same, keeps the `ground_` prefix the HUD keys on |
| `idle` | `became_idle` | InputResolver | Names the transition into the Idle state; `gesture_ended` was rejected as too close to `drag_ended` |
| `waves_complete` | `waves_completed` | EnemyWave | Past tense; still distinct from `wave_cleared` |
| `phase` | `phase_changed` | Flow | Already renamed in `architecture.md` (a signal and the `phase()` read cannot share a name); this ADR makes the GDDs match |

Kept: `pressed` (already a past participle, the same form as `tower_built`), and every other battle signal name, all already past tense: `enemy_leaked`, `enemy_killed`, `wave_cleared`, `lives_changed`, `wave_called_early`, `gold_changed`, `tower_built`, `tower_upgraded`, `hero_pinned`, `burst_started`, `attack_fired`, `damage_applied`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`; wrapper-side `lifecycle_paused`, `display_changed`, `slot_tapped`, `tower_inspected`.

A signal may not share a name with a method, property or inherited native member of its class: GDScript rejects it at parse time ("member already exists"). None of the names above collides. An emitter that ever extends `Node` must also avoid `Node`'s own names (`ready`, `renamed`, `visibility_changed` and the rest).

Reason for renaming over recorded exceptions: no code or test exists, so the cost today is document edits only (listed exactly in the cascade notes); after the first test it is code, tests and documents. An exception list would grow and every later reviewer would have to check it.

GDD log notation follows the names: a log entry reads `phase_changed(WAVE)` (enum value in its code spelling), `tapped(T)`, `became_idle`.

### 4. Payloads and ID types (QQ-04)

**ID types, one per kind of ID:**

| Kind | Type | Examples | Reason |
|---|---|---|---|
| Catalogue record ID | `StringName` | `tower_id`, `def_id`, `source_id`, `stage_id` | ADR-0002 stores every record ID as `StringName`; one type end to end means no conversion at the boundary; comparisons are cheap and the value reads in logs |
| Slot | `int` | `slot_index` | Index into `StageRecord.slot_positions`, 0-based |
| Enemy instance | `int` | `spawn_id` | EnemyWave's counter (ADR-0009) |
| Resolver target | `int` | `best_tap`, `best_drag` | Resolver ids from 1, `NONE = -1` (Input GDD) |
| Tower level | `int` | `level` | As the Tower GDD numbers it in its logs |
| Enum value | the enum | `Flow.Phase`, `Combat.SourceKind` | Typed; `int` only if V6 fails |

`String` is never used for an ID in a signal, command or field. A literal ID in code is written `&"arrow"`.

**Payload rules:**

- Every parameter is typed. Payloads carry value types only: `int`, `float`, `bool`, `StringName`, `Vector2`, an enum. **No payload carries a sim object** (`Targetable`, `Enemy`, `DamageEvent`, `Health`, `Status`, `ReadContext`, a record, a system, `Battle`). A view therefore cannot keep a reaped enemy alive or reach sim state through a payload.
- Positions in payloads are `Vector2` copies in field units (registry `sim_position_representation` allows view-signal payloads), built at emit time.
- **`damage_applied` drops `event`.** New signature: `damage_applied(source_kind: SourceKind, source_id: StringName, applied: float, position: Vector2, killed: bool, spawn_id: int)`. This takes ADR-0009's recommendation: the old `event: DamageEvent` parameter exposed `event.target` to every view. The registry pattern `listener_stores_damage_event` is replaced by `sim_object_in_signal_payload`, which holds by construction.
- Parameter names are the GDDs' where they gave one (`lives_cost`, `bounty`, `intermission_duration`, `seconds_left`, `current`, `slot_index`, `tower_id`, `level`, `aim_point`, `telegraph_ticks`, `best_tap`, `best_drag`, `press_pos`, `release_pos`, `p`). Flow's is `value` (B5).

### 5. The signal table

Every battle signal, its listeners and its timing. "Tick step" refers to ADR-0004 Decision 4; "frame step" to ADR-0004 Decision 5.

**Wiring signals (connected by `BattleBuilder`, the sim consumes them):**

| ID | Signal | Listener | Emitted | Commit before emit |
|---|---|---|---|---|
| W1 | `EnemyWave.enemy_leaked(lives_cost: int)` | `Flow.on_enemy_leaked` | tick step 2, ascending `spawn_id` | enemy removed from roster, targets and contexts; counts and per-type leak count updated |
| W2 | `EnemyWave.enemy_killed(bounty: int)` | `TowerSim.on_enemy_killed` | tick step 6, ascending `spawn_id` | corpse removed; counts updated |
| W3 | `EnemyWave.wave_cleared(intermission_duration: float)` | `Flow.on_wave_cleared` | tick step 6, after every kill of the tick | wave state committed |
| W4 | `EnemyWave.waves_completed()` | `Flow.on_waves_completed` | tick step 6, instead of W3 for the last wave | wave state FINISHED |
| W5 | `Flow.wave_called_early(seconds_left: float)` | `TowerSim.on_wave_called_early` | frame step 0, inside `call_early()`, before `phase_changed(WAVE)` | early call committed |

Leaks precede the clear because W1 fires in tick step 2 and W3/W4 in step 6 (TR-enemy-004, Flow Rule 13).

**View signals (on the allowlist; connected by the wrapper):**

| ID | Signal | Listeners (MVP) | Emitted | Required after attach |
|---|---|---|---|---|
| P1 | `Flow.phase_changed(value: Phase)` | `BattleWrapper._on_phase_changed` (ADR-0004), HudLogic, TowerInput (chip), RunLog (development builds, ADR-0010) | each phase change; outcomes and PAUSED after Flow Rule 15's commit order (state, gate, `cancel_input()`, emit); FATAL from `Flow.enter_fatal` on the fatal path | yes |
| P2 | `Flow.lives_changed(current: int)` | HudLogic | inside W1's handler, only on a change, before any `phase_changed(LOST)` | yes |
| P3 | `TowerSim.gold_changed(current: int)` | HudLogic | after `build`/`upgrade` commit and before P4/P5; inside W2 and W5 handlers; only on a change | yes |
| P4 | `TowerSim.tower_built(slot_index: int, tower_id: StringName)` | TowerInput (slot to tower disc, ADR-0010), RunLog (development builds); FieldBackdrop and TowerView poll (ADR-0011) | after P3 in `build` | yes |
| P5 | `TowerSim.tower_upgraded(slot_index: int, level: int)` | gesture log (development builds) | after P3 in `upgrade` | no |
| P6 | `HeroSim.hero_pinned(position: Vector2)` | RunLog (development builds, ADR-0010); HeroView polls (ADR-0011) | inside `pin()` after state set | no |
| P7 | `HeroSim.burst_started(aim_point: Vector2, telegraph_ticks: int)` | CombatViewModel (clearance window, ADR-0011), HudLogic (Battle HUD Rule 13, burst button state; amended 2026-11-05), RunLog (development builds, ADR-0010) | inside `burst()` after state set | yes |
| P8 | `Combat.attack_fired(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)` | CombatViewModel (ADR-0011) | inside `report_attack`, before the attacker's `deliver` calls | yes |
| P9 | `Combat.damage_applied(source_kind: SourceKind, source_id: StringName, applied: float, position: Vector2, killed: bool, spawn_id: int)` | CombatViewModel (ADR-0011) | inside `deliver`, after HP, dead state and counters; never when `applied` is 0 | yes |
| G1 | `InputResolver.pressed(best_tap: int, best_drag: int, p: Vector2)` | HeroInput, TowerInput, HudLogic | frame step 0 (`flush()`) | yes |
| G2 | `InputResolver.tapped(best_tap: int, p: Vector2)` | TowerInput, HudLogic | frame step 0 | yes |
| G3 | `InputResolver.ground_tapped(p: Vector2)` | HudLogic | frame step 0 | yes |
| G4 | `InputResolver.drag_started(best_drag: int, press_pos: Vector2, p: Vector2)` | HeroInput, HudLogic | frame step 0 | yes |
| G5 | `InputResolver.drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)` | HeroInput | frame step 0, one per `move` call | yes |
| G6 | `InputResolver.drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)` | HeroInput | frame step 0 | yes |
| G7 | `InputResolver.drag_cancelled(best_drag: int)` | HeroInput | frame step 0, **or inside a tick or an engine callback** through `cancel_input()` | yes |
| G8 | `InputResolver.became_idle()` | HeroInput, HudLogic | last signal of every exit to Idle; same timing as the signal before it, G7's included | yes |

The resolver's state machine, re-entrancy queue and which row emits what are ADR-0008's; this ADR fixes only names, payload types and the listener rules.

**Wrapper-side signals (not battle signals; connected in `attach`, listed so the wrapper test covers them):** A1 `InputAdapter.lifecycle_paused()` to `Flow.pause` and the HUD press clear (ADR-0003 Decision 6); A2 `InputAdapter.display_changed()` to the wrapper's inset hand-off (ADR-0003 Decision 7); `TowerInput.slot_tapped(slot_index: int)` and `TowerInput.tower_inspected(slot_index: int)` to HudLogic (ADR-0010 owns them). A1 is the one wrapper connection whose listener is a sim command. It is legal because the adapter emits it from an engine callback, between ticks (ADR-0004 Decision 5), and `Flow.pause()` is idempotent.

**Emitters.** Only these declare signals in battle code: `Flow`, `EnemyWave`, `TowerSim`, `HeroSim`, `Combat`, `InputResolver` (the battle emitters), and the wrapper-side `InputAdapter`, `TowerInput`, `HeroInput`, `HudLogic`. `Catalogue`, every record class, `StatAccessor`, `ReadContext`, `Targetable`, `Enemy`, `Health`, `Status`, `DamageEvent`, `StageResult`, `FatalLatch`, `FatalRelay` and `Battle` declare none (TR-data-014). A new emitter or a new signal is an amendment to this table.

**Listener methods** for Builder-made connections are public and named `on_<signal_name>` (`Flow.on_enemy_leaked`), documented "called only by the W-n connection". A node connecting its own method may use `_on_<signal_name>` (ADR-0004's `_on_phase_changed`).

### 6. `StageResult` and the result snapshot (TR-hud-012)

```gdscript
# src/core/flow/stage_result.gd
class_name StageResult extends RefCounted
## Built once by Flow when an outcome commits. Holds values only, no references,
## so a view may keep it after the battle is dropped.
var outcome: Flow.Phase          # WON, LOST or FATAL
var last_wave_started: int       # EnemyWave.wave_index() at the outcome
var lives_left: int
var dealt_tower: float           # Combat.dealt_by_kind(TOWER)
var dealt_hero: float            # Combat.dealt_by_kind(HERO)
var dealt_burst: float           # Combat.dealt_by_kind(BURST)
var dealt_total: float           # Combat.dealt_total()
```

- Flow builds it as part of the outcome commit (WON, LOST, FATAL), before `cancel_input()` and before `phase_changed`, so a `phase_changed` listener can already call `result()`. `Flow.result()` returns null before an outcome and the same object after. It is read-only by contract.
- Flow gets the reads as three injected method Callables (B9 additions): `wave_index` (`enemy_wave.wave_index`), `dealt_by_kind` (`combat.dealt_by_kind`), `dealt_total` (`combat.dealt_total`). Flow keeps no wave count and no reference to EnemyWave or Combat (Game State Rule 15). Each defaults to an empty `Callable()`, and Flow calls it only after `is_valid()`; a fatal during ADR-0001's Builder step 3, before step 4 injects them, leaves those fields 0, and the Builder returns null then anyway.
- Every sim value is frozen once `halted()` is true, so building at the commit and building a frame later give the same numbers.
- **The HUD's snapshot** (screen and run log, Battle HUD Rule 15) is taken once, in the first `HudLogic.advance(ms)` after HudLogic hears `phase_changed(WON)` or `phase_changed(LOST)`. WON and LOST commit only inside a tick (frame step 3), so that `advance` is frame step 1 of the next frame: the frame after the outcome, as the GDD requires. The snapshot holds the `StageResult` plus the other reads the GDD lists (got through by type, `slows_applied()`, Hero counters, `hero_share()`); its class and fields are ADR-0010's. Screen and log read only the snapshot.

### 7. Listener rules

These rules bind `src/`; test code is exempt (Decision 2).

1. **Wiring listeners** (W1 to W5) may change only their own system's state and emit their own signals. They never call a command, a tick entry, `deliver`, `apply_slow`, or another system's method.
   **Flow owns the wrong-phase checks** (TR-state-018; amended 2026-11-05). `Flow.on_wave_cleared` (W3) and `Flow.on_waves_completed` (W4) check the phase first: outside WAVE they call the injected `dev_error` and change nothing. `Flow.on_enemy_leaked` (W1) in BUILD, PAUSED or after an outcome calls `dev_error` and changes nothing; in INTERMISSION it calls `dev_error` and still applies the leak. EnemyWave emits without checking Flow's phase. Flow takes `dev_error` in its constructor (default `Callable()`, `is_valid()` before use).
2. **View listeners** (P1 to P9) hold presentation state only. They may read queries and set flags; they never call a command, a tick entry, `deliver`, a sim setter, `request_retry`, or `connect`/`disconnect`; they never emit a battle signal; they never keep an object reached through a query past the handler (ADR-0009's roster rule). Heavy work waits for frame step 4.
3. **Gesture listeners** (G1 to G6) may issue commands, because those signals fire only from `flush()` in frame step 0, between ticks (Data Flow 1). **G7 and G8 listeners never issue a command**: they can fire inside a tick (an outcome's `cancel_input()`) or inside an engine callback. They only revert or hide presentation state (the hero's leash, an aim).
4. **Listeners of P8 and P9 never read the `StatAccessor`**, so they cannot reach `fatal` and Combat needs no `halted()` (ADR-0009 Decision 4).
5. **No sim listens to a view signal.** A sim object connected to any P or G signal is a defect; the headless test (Decision 8) proves it.
6. **No outcome depends on listener order.** Two listeners of one signal must not rely on which runs first. A view that needs another system's new state listens to that system's own signal (gold from `gold_changed`, not from `enemy_killed`). V4 records the engine's actual order for test authors only.
7. **No emitter re-emits the signal being delivered** from inside one of its own listeners (V5, second case).
8. **Gameplay never depends on listeners.** A battle run with no wrapper connections, and the same battle with recording fakes on every P and G signal that also call every read-only query in each handler (fakes on P8 and P9 skip the `StatAccessor`, rule 4), produce identical per-tick digests (ADR-0004 Validation 6), signal logs on W1 to W5 and `StageResult` (TR-tower-012, TR-hud-004, TR-combat-010).

### 8. The allowlist and the listener-count tests (TR-state-013 contract)

The contract lives with the tests, because production code does not need it: `tests/integration/battle_wiring/battle_signal_contract.gd`, a script of `const` data copied from Decision 5:

- `WIRING`: for each key `"emitter.signal"` (`"enemy_wave.enemy_leaked"`), the exact list of `[emitter_key, method_name]` listeners (`["flow", &"on_enemy_leaked"]`).
- `VIEW_ALLOWLIST`: the 17 keys P1 to P9 and G1 to G8, each with `required_after_attach: bool` from the table.

`Battle` exposes the emitters for tests and tools:

```gdscript
const EMITTER_KEYS: Array[StringName] = [&"flow", &"combat", &"enemy_wave", &"tower_sim", &"hero_sim", &"resolver"]
func emitters() -> Array[Object]   # same order as EMITTER_KEYS; read-only use
```

**Headless test** (ADR-0007 harness; `BattleBuilder.build` on a fixture catalogue, no scene; the test holds the `Battle` throughout, because a freed listener drops its connections, V3; any engine error logged during the test fails it):

1. For every emitter, every signal from `get_script().get_script_signal_list()` (V2) must have a key in `WIRING` or `VIEW_ALLOWLIST`. An unlisted signal fails, naming it.
2. Every key in either list must exist on its emitter. A stale key fails, naming it.
3. For each `WIRING` key, the connection list (`get_signal_connection_list`, V3) must equal the expected listeners exactly: target object (by identity with the battle's system), method name, `flags == 0`. A missing or extra connection fails, naming emitter, signal and listener.
4. For each `VIEW_ALLOWLIST` key, the connection list must be empty headless (rule 5: no sim listens to a view signal).
5. The data-store classes and the other non-emitters named in Decision 5 declare no signal.
6. Self-proof (Game State deferred criterion "watched failing once"): the same check run on a battle after the test disconnects W2 must report exactly `enemy_wave.enemy_killed` missing `tower_sim.on_enemy_killed`. The output of that run is kept with the test evidence.

**Wrapper test** (first `BattleWrapper` story; needs the wrapper scene):

1. After `attach`, every `VIEW_ALLOWLIST` key with `required_after_attach` has at least one connection, each listener exactly once, all with `flags == 0`, all to objects the wrapper owns (nodes in its subtree or the models it holds); A1 and A2 are connected as ADR-0003 states. No engine error is logged.
2. After `detach`, every battle emitter's connections equal the `WIRING` set exactly: no wrapper connection survives (supports TR-tower-013 and ADR-0001's weakref proof).

### 9. Choices pending user confirmation

Three choices are design content in the HUD and acceptance criteria, not only architecture. They are proposed here and need the user (game-designer or ux-designer input optional) before acceptance:

1. **`StageResult` fields** (Decision 6): outcome, last wave started, lives left, damage by the three kinds and the total; no per-tower-ID breakdown (the HUD snapshot reads that).
2. **HUD snapshot timing** (Decision 6): the first `HudLogic.advance` after `phase_changed(WON)` or `phase_changed(LOST)`.
3. **Log notation** (Decision 3): GDD acceptance logs write `phase_changed(WAVE)`, `tapped(T)`, `became_idle`.

The other autonomous choices are listed in the cascade notes, section d, and are approved one by one with the edits (precondition 3).

Items 1 to 3, and the section d choices 1 to 15: confirmed by the user, 2026-11-04, as recommended. Confirmed by the user as project owner, 2026-11-04; the named roles (game-designer, ux-designer) were not consulted separately.

### Architecture Diagram

```
 BattleBuilder.build (headless; wiring only, flags 0)
   EnemyWave ──enemy_leaked W1──────────► Flow.on_enemy_leaked ──► lives_changed P2, phase_changed P1 (LOST)
             ──wave_cleared W3──────────► Flow.on_wave_cleared ──► phase_changed P1 (INTERMISSION)
             ──waves_completed W4───────► Flow.on_waves_completed ─► StageResult, phase_changed P1 (WON)
             ──enemy_killed W2──────────► TowerSim.on_enemy_killed ─► gold_changed P3
   Flow      ──wave_called_early W5─────► TowerSim.on_wave_called_early ─► gold_changed P3
   FatalRelay ─(method call)─► Flow.enter_fatal ─► StageResult, cancel_input(), phase_changed P1 (FATAL)

 BattleWrapper.attach / detach (wrapper subtree; flags 0; undone on detach)
   Flow P1, P2 · TowerSim P3 to P5 · HeroSim P6, P7 · Combat P8, P9 ──► HudLogic, TowerInput, views, wrapper
   InputResolver G1 to G8 (frame step 0; G7, G8 also inside cancel_input) ──► HeroInput, TowerInput, HudLogic
   InputAdapter A1 lifecycle_paused ──► Flow.pause, HUD press clear;  A2 display_changed ──► wrapper

 Every emit: commit first, emit synchronously, then the emitter checks halted().
 Payloads: int, float, bool, StringName, Vector2, enums. Never a sim object.
```

### Key Interfaces

```gdscript
# src/core/flow/flow.gd (adds to B5)
signal phase_changed(value: Phase)
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
func result() -> StageResult                     # null before the outcome
func on_enemy_leaked(lives_cost: int) -> void    # W1 only
func on_wave_cleared(intermission_duration: float) -> void   # W3 only
func on_waves_completed() -> void                # W4 only
# injected by the Builder: wave_index, dealt_by_kind, dealt_total (method Callables), dev_error (wrong-phase W1, W3, W4; Decision 7 rule 1)

# src/feature/enemy_wave/enemy_wave.gd (B7, renamed)
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_completed()

# src/feature/tower/tower_sim.gd (B8)
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)
signal tower_upgraded(slot_index: int, level: int)
func on_enemy_killed(bounty: int) -> void        # W2 only
func on_wave_called_early(seconds_left: float) -> void   # W5 only

# src/feature/hero/hero_sim.gd (B8)
signal hero_pinned(position: Vector2)
signal burst_started(aim_point: Vector2, telegraph_ticks: int)

# src/core/combat/combat.gd (B6, damage_applied changed)
signal attack_fired(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(source_kind: SourceKind, source_id: StringName, applied: float, position: Vector2, killed: bool, spawn_id: int)

# src/foundation/input/input_resolver.gd (B2, renamed; internals ADR-0008)
signal pressed(best_tap: int, best_drag: int, p: Vector2)
signal tapped(best_tap: int, p: Vector2)
signal ground_tapped(p: Vector2)
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(best_drag: int)
signal became_idle()

# src/root/battle.gd (adds to ADR-0001 and ADR-0004)
const EMITTER_KEYS: Array[StringName] = [&"flow", &"combat", &"enemy_wave", &"tower_sim", &"hero_sim", &"resolver"]
func emitters() -> Array[Object]

# src/core/flow/stage_result.gd: Decision 6
```

File paths are the proposed module folders of `architecture.md`; `class_name` collisions (QQ-16) are checked by ADR-0007 NAME-1 to NAME-4; names stand unless ADR-0007 V6 reports one. Every signal declaration carries a `##` doc comment naming its ID (W1, P3, ...) and its timing.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must emit with `signal_name.emit(...)`; must never use `emit_signal("name", ...)` in `src/`.
- Must commit every state change and counter an event describes before emitting it; must check `halted()` after every emit and return at once if true (Combat excepted, ADR-0009 Decision 4).
- Must emit nothing on a refusal or a no-op; a `*_changed` signal fires only on an actual change.
- Must make sim-to-sim connections only in `BattleBuilder.build` and wrapper connections only in `BattleWrapper.attach`, undone in `detach`; must never connect or disconnect anywhere else or inside a handler.
- Must connect as `emitter.signal_name.connect(listener.method)` with no flags; must never use `CONNECT_DEFERRED`, `CONNECT_ONE_SHOT` or `CONNECT_REFERENCE_COUNTED` on a battle signal; must never connect a battle signal in a `.tscn` or the editor.
- Must never give a signal the name of a method, property or inherited member of its class.
- Must type every signal parameter; must use `StringName` for catalogue IDs and `int` for `slot_index`, `spawn_id`, resolver ids and `level`; must never use `String` for an ID.
- Must never put a sim object (`Targetable`, `Enemy`, `DamageEvent`, `Health`, `Status`, `ReadContext`, a record, a system, `Battle`) in a signal payload.
- Wiring listeners must change only their own system's state; view listeners must never call a command, tick entry, `deliver`, sim setter, `request_retry`, `connect` or `disconnect`, and must never emit a battle signal.
- Listeners of `drag_cancelled` and `became_idle` must never issue a command.
- Listeners of `attack_fired` and `damage_applied` must never call the `StatAccessor`.
- No sim object may connect to a view or gesture signal.
- Must never rely on the order in which two listeners of one signal run.
- An emitter must never emit a signal from inside a listener of that same signal.
- `Catalogue`, records, `StatAccessor`, `ReadContext`, entity and value classes, `FatalLatch`, `FatalRelay` and `Battle` must declare no signal.
- A new battle signal must be added to this ADR's table, to `battle_signal_contract.gd`, and to its GDD in the same change.
- Builder-connected listener methods are public `on_<signal_name>`; wrapper-subtree listener methods are `_on_<signal_name>` (ADR-0007 WIRE-8); each signal has a `##` doc comment with its table ID.
- Recording fakes must log the signal name and every argument, and assert argument types with `typeof()`/`is` (a `StringName` is checked as `TYPE_STRING_NAME`), not only call counts (ADR-0007).

## Alternatives Considered

### Alternative 1: A per-battle event bus

- **Description**: One `BattleEvents` object owned by `Battle` declares every signal; systems emit on it and listeners connect to it.
- **Pros**: One file lists every signal; the listener-count test needs one emitter.
- **Cons**: Any system can emit any event, so ownership of "who commits before emit" is lost; every system needs a reference to the bus, which is one more object reachable from everything; GDD signatures name their emitters (`EnemyWave.enemy_leaked`), so every GDD changes.
- **Estimated Effort**: About the same to build; more to review.
- **Rejection Reason**: Ownership of commit order matters more than a single list, and Decision 5's table already gives the single list.

### Alternative 2: Deferred connections or an end-of-tick event queue

- **Description**: Emitters queue events, and listeners run after the tick (or `CONNECT_DEFERRED` to idle time).
- **Pros**: Listeners can never see half-finished tick state; re-entrancy disappears.
- **Cons**: A fatal leak would not stop the tick at once (Game State Rule 14, "a tie is a loss" needs the leak to latch LOST before the reap); leaks before clear would depend on queue order; deferred calls run outside the clock, breaking determinism and headless runs.
- **Estimated Effort**: More (a queue, flush points, ordering rules).
- **Rejection Reason**: TR-enemy-004 requires synchronous signals, and the halt-mid-tick rule depends on them.

### Alternative 3: Injected Callables instead of wiring signals

- **Description**: EnemyWave receives `on_leak: Callable` from the Builder instead of emitting `enemy_leaked`.
- **Pros**: Exactly one target, checked at injection; no listener-count test needed for wiring.
- **Cons**: Views that also want the event need a second mechanism; the GDDs specify signals; acceptance logs record signals.
- **Estimated Effort**: Similar.
- **Rejection Reason**: The listener-count test gives the same guarantee and keeps one mechanism for sim and view listeners.

### Alternative 4: Keep the GDD names and record exceptions

- **Description**: `tap`, `ground_tap`, `idle`, `waves_complete` stay; an exception list in this ADR excuses them.
- **Pros**: No GDD edit now.
- **Cons**: The exception list must be checked on every review and lint; the names read as commands or states, not events (`idle` reads as a state).
- **Estimated Effort**: Less now, more later.
- **Rejection Reason**: Nothing uses the names yet, so renaming costs only document edits today.

### Alternative 5: Keep `damage_applied(event: DamageEvent, ...)`

- **Description**: The GDD payload, with the existing rule that no listener stores the event or reads `event.target`.
- **Pros**: No GDD or ADR-0009 change.
- **Cons**: The rule is enforced only by review; a view keeping the event keeps a reaped enemy alive and breaks the retry weakref proof.
- **Estimated Effort**: None now.
- **Rejection Reason**: Removing the object from the payload makes the rule true by construction, at the cost of two edits.

### Alternative 6: `int` or `String` IDs in signals

- **Description**: Towers identified by an `int` index into the catalogue, or by `String`.
- **Pros**: `int` is the cheapest compare; `String` needs no `&""` literal.
- **Cons**: `int` needs an ID table and makes logs unreadable; `String` differs from ADR-0002's `StringName` records, so every boundary converts, and V1 may show the mismatch is not caught at emit.
- **Estimated Effort**: More for `int` (a mapping), similar for `String`.
- **Rejection Reason**: One ID type end to end, matching ADR-0002.

### Alternative 7: Allowlist by naming convention

- **Description**: View signals carry a `view_` prefix; the test exempts any signal so named.
- **Pros**: No separate list.
- **Cons**: Renames nine GDD signals; a misnamed signal silently joins the exemption.
- **Estimated Effort**: Similar.
- **Rejection Reason**: An explicit list is reviewable and fails on anything unlisted.

## Consequences

### Positive

- One table answers "who emits, who listens, when, with what types" for every battle signal.
- The headless test catches a missing, extra, deferred or stale connection and any new unlisted signal, naming it.
- Views cannot change a result: they cannot reach a sim object through a payload, and no sim listens to them.
- No signal name needs an exception; ADR-0008 can be written against fixed names.
- `StageResult` holds no references, so the HUD may keep it across teardown without a leak.

### Negative

- About 140 text edits across eight GDDs, `architecture.md`, ADR-0003, ADR-0004 and ADR-0009 for the renames and the payload change (exact list in the cascade notes), then an `/architecture-review` run so the TR registry and traceability matrix follow.
- Two places make connections (Builder and wrapper), so a reader checks two functions.
- The contract is copied into a test file; a new signal needs three edits (ADR, contract, GDD).
- Flow gains three injected callables.

### Neutral

- `pressed` keeps its name.
- The wrapper test needs the wrapper scene, so it runs later than the headless test.

## Risks

- **Emit-time types are unchecked (V1).** A `String` passed for a `StringName` may be converted silently, and a listener error is logged while the emit continues. Mitigation: recording fakes check `typeof()`; tests fail on any captured engine error; IDs always come from records, which are `StringName` (ADR-0002).
- **Introspection shape differs (V2, V3).** Mitigation: each item has a fallback; the test is written only after the result is recorded.
- **Nested emit is not depth-first (V5).** Mitigation: the branch in V5 (per-emitter outbox) is stated; this ADR is revised before any Flow story.
- **Enum-typed parameters fail (V6).** Mitigation: `int` with the same names.
- **A gesture listener issues a command from `drag_cancelled` inside a tick.** Mitigation: Decision 7 rule 3, ADR-0004's development check in commands (`between_ticks()`), and an ADR-0007 lint on G7 and G8 handlers.
- **A view does heavy work inside a handler during a three-tick frame.** Mitigation: views set flags and redraw in frame step 4; the tick budget (ADR-0004 V6) is measured with views connected.
- **The contract file drifts from this ADR.** Mitigation: the test fails on any unlisted or stale key, so drift shows as a failure, not a silent gap.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-014: the data store emits no signals; each emitter declares its own and the composition root wires them | Decision 5 (emitter list; data classes declare none); Decision 2 (Builder and wrapper wire); Decision 8 headless test step 5 |
| game-state-stage-flow.md | TR-state-008: Flow listens to synchronous `wave_cleared`, `waves_completed` and `enemy_leaked` (leak before complete) and emits `lives_changed`, `phase_changed` and `wave_called_early` | Decision 5 W1, W3, W4 (Flow listeners, timing in tick steps 2 and 6), P1, P2, W5; Decision 3 (`phase` renamed) |
| combat-damage.md | TR-combat-010: view-only `attack_fired` and `damage_applied` emit after commit with copied positions; listeners never call `deliver`; results match with or without listeners | Decision 4 (`damage_applied` payload without `event`, `Vector2` copies); Decision 5 P8, P9; Decision 7 rules 2, 4, 8 |
| enemy-wave.md | TR-enemy-004: `enemy_leaked`, `enemy_killed`, `wave_cleared`, `waves_completed` fire synchronously (no `CONNECT_DEFERRED`) in `spawn_id` order after commit; leaks before the clear | Decision 1 (synchronous, commit first); Decision 2 (flags 0, Builder only); Decision 5 W1 to W4 (order); Decision 8 step 3 asserts `flags == 0` |
| tower-system.md | TR-tower-004: command commit is atomic; state before `gold_changed` then `tower_built` or `tower_upgraded`; a refusal changes and emits nothing | Decision 1 items 2 and 3; Decision 5 P3 to P5 order |
| tower-system.md | TR-tower-012: typed signatures (`tower_id` type undecided); gameplay may not depend on them; results match with or without listeners | Decision 4 (`tower_id: StringName`, all parameters typed); Decision 7 rules 5 and 8 |
| hero-system.md | TR-hero-008: `hero_pinned` and `burst_started` emit after state is set and are on the view allowlist; handlers never issue commands | Decision 5 P6, P7; Decision 7 rule 2; Decision 8 `VIEW_ALLOWLIST` |
| battle-hud.md | TR-hud-004: the HUD holds presentation state only and no reset path; full sim state is identical with or without the HUD | Decision 7 rules 2, 5 and 8 (with and without listeners test); HUD connections only in `attach`, undone in `detach` |
| battle-hud.md | TR-hud-010: the HUD reads Flow, Tower, Hero, Enemy & Wave and Combat via signals and view-only queries; `phase_changed` and `lives_changed` join the view allowlist | Decision 5 P1, P2, P3, P7, G1 to G4, G8 (HudLogic listeners); Decision 8 allowlist. The new view-only queries are ADR-0010's |
| battle-hud.md | TR-hud-012: the result screen and log come from one snapshot built the frame after the outcome | Decision 6 (`StageResult` at commit; HUD snapshot in the first `advance` after the outcome, frame step 1 of the next frame) |
| game-state-stage-flow.md | TR-state-013 (ADR-0007's): tests fail when any battle signal has no listener, views on an allowlist | Contract only: Decision 8 (allowlist, `Battle.emitters()`, both tests). ADR-0007 owns the harness |
| input-gesture-resolver.md | TR-input-009 (ADR-0008's): the resolver's signal API | Names and payload types only: Decision 3 and Decision 5 G1 to G8 |
| tower-system.md | TR-tower-013 (ADR-0001's): no old battle alive through a signal connection; a listener-count wiring test names any missing connection | Supports it: Decision 8 headless step 3 and wrapper test step 2 |

## Performance Implications

- **CPU**: One `emit()` per committed event. The busiest are `damage_applied` (one per victim per hit) and `attack_fired` (one per attack). Headless, view signals have no listeners. Unmeasured; ADR-0004 V6 measures the whole tick on a device and must do so with the wrapper's views connected.
- **Memory**: No allocation beyond `Vector2` payload values; no payload holds an object, so no listener extends an object's life. `StageResult` is one small object per battle.
- **Load Time**: Builder makes five connections; the wrapper about 25. Negligible.
- **Network**: None.

## Migration Plan

No code exists. Apply the GDD, `architecture.md`, ADR-0003, ADR-0004 and ADR-0009 edits in the cascade notes before the first story that names a signal, then run `/architecture-review`, which owns the TR registry and traceability matrix and takes the cascade's section e as input. ADR-0007 writes `battle_signal_contract.gd` and the headless test with its first harness story.

**Rollback plan**: If V5 shows nested emits are not depth-first, replace synchronous nested emits in Flow and TowerSim with a per-emitter outbox flushed right after the outer emit, and revise Decision 1. If V6 fails, type enum parameters as `int`. If V2 or V3 fails, use the stated fallbacks. Renames are not rolled back once tests exist.

## Validation Criteria

1. V1 to V6 recorded in `current-best-practices.md` before acceptance.
2. The headless listener-count test passes on a fixture battle, and its self-proof run (W2 removed) fails naming `enemy_wave.enemy_killed`; the failing output is kept.
3. The wrapper test passes after `attach` and after `detach`.
4. The with-and-without-listeners run gives identical per-tick digests, W1 to W5 logs and `StageResult` (Decision 7 rule 8).
5. Recording-fake logs in the Game State, Enemy & Wave, Tower, Hero, Combat and Input acceptance criteria use the Decision 3 names and Decision 4 payloads, with argument types asserted.
6. ADR-0007 lint, over battle modules only (`src/core/`, `src/feature/`, `src/foundation/input/`, `src/presentation/` battle views, `battle_builder.gd`, `battle_wrapper.gd`; menus, `AppRoot` and modal screens are out of scope), finds no `emit_signal(`, no `CONNECT_` flag, no connection to a battle emitter's signal outside `battle_builder.gd` and `battle_wrapper.gd`, no battle-signal connection in a `.tscn`, no `signal` in `src/foundation/data/`, and no `String`-typed ID parameter.
7. A `StageResult` read after a LOST by a fatal leak shows that leak counted (Battle HUD Acceptance 19).

## Related

- Depends on: ADR-0001 (wiring mechanism, fatal path), ADR-0004 (tick and frame order).
- Binds and is bound by: ADR-0002 (`StringName` IDs), ADR-0003 (`lifecycle_paused`, `display_changed`), ADR-0009 (Combat and EnemyWave signals; this ADR changes `damage_applied`'s payload, which ADR-0009 deferred here).
- Enables: ADR-0007, ADR-0008, ADR-0010, ADR-0011.
- Amends: ADR-0004 V6 (measured with the wrapper's views connected) and ADR-0009 (the `damage_applied` payload), through the cascade notes.
- Supersedes registry entry `listener_stores_damage_event` (ADR-0009) with `sim_object_in_signal_payload`.
- Closes QQ-04 and QQ-07 in `docs/architecture/architecture.md`.
- GDDs: `design/gdd/game-state-stage-flow.md`, `enemy-wave.md`, `tower-system.md`, `hero-system.md`, `combat-damage.md`, `input-gesture-resolver.md`, `battle-hud.md`, `data-config-pipeline.md`.
- Code (once written): `src/root/battle_builder.gd`, `src/root/battle_wrapper.gd`, `src/core/flow/stage_result.gd`, `tests/integration/battle_wiring/battle_signal_contract.gd`.
