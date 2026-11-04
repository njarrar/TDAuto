# ADR-0008: Input Resolver Core and Signal Contract

## Status
Proposed

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. Route: `/architecture-decision accept ADR-0008`. Reviews still owed (see Reviews).

## Date
2026-11-04

## Last Verified
2026-11-04 (against `docs/engine-reference/godot/` for Godot 4.7.2, `architecture.md` v4, ADR-0001 to ADR-0007 as Accepted, `tr-registry.yaml`, `docs/registry/architecture.yaml`, and the Input, Tower, Hero and Battle HUD GDDs by section)

## Decision Makers
- Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`, 2026-11-04)
- godot-specialist: not yet run. TD-ADR: not yet run. Both owed before acceptance.
- Acceptance: the user.

## Summary
The Input GDD defines a pure gesture resolver, and ADR-0003 and ADR-0006 fix its caller and its signal names, but no ADR fixes its class, registry, state machine, queue, payloads or the dev gesture log. This ADR decides a clock-free `InputResolver extends RefCounted` with a `validate()`/`create()` factory, a disc registry with a total tie-break, a four-state machine with one active pointer and frozen winners, a bounded FIFO queue drained in the outermost call, typed payloads for all eight signals, a read-only `GestureTrace` per gesture, and a wrapper-side `GestureLog` harness for the Pillar 4 phone test.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Input (the pure core; no engine input API) and Core (signals) |
| **Layer** | Foundation (`InputResolver`, `GestureTrace`); the `GestureLog` harness it specifies is Presentation |
| **Knowledge Risk** | MEDIUM. The resolver uses only 4.0-era language features: `RefCounted`, typed `signal`, `emit()`, `enum`, `const`, `is_finite`, `push_error`, `Vector2` storage. `breaking-changes.md` lists no 4.4 to 4.7 change to any of them, but no file in `docs/engine-reference/godot/` covers signals or float precision, so the behaviours named under Verification Required are unverified on 4.7.2. `modules/input.md` covers no touch API; none is used here (ADR-0003 owns events). |
| **References Consulted** | `VERSION.md`; `modules/input.md` (4.7 device IDs, nothing on touch); `breaking-changes.md` (4.7 typed-return overrides); `deprecated-apis.md` (string `connect()`); `current-best-practices.md` (4.5 rest parameters, lambda capture, 4.7 overrides). `architecture.md` v4 (B2, Data Flow 1, 3, 9, Required ADRs); `tr-registry.yaml`; ADR-0001, ADR-0003, ADR-0004, ADR-0006, ADR-0007 |
| **Post-Cutoff APIs Used** | None in `src/`. Test fakes may use 4.5 rest parameters (`...args`), as ADR-0006 and ADR-0007 allow. |
| **Verification Required** | Probes R1 to R5 (Validation Criteria) on a 4.7.2 binary before the first resolver story closes. Each answer below is from memory, not the pinned reference. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): Builder creates the resolver, `Battle.input_resolver`, null from `create()` goes to `fatal("input_record_invalid")`, three `cancel()` callers, method Callables only. ADR-0003 (Accepted): the adapter makes the five calls in 540x960 field units, presses after GUI, endings before, `MOUSE_POINTER = 1 << 16`, TapScreens are Controls. ADR-0004 (Accepted): input commands run at frame step 0, before ticks; float policy; no clock in sim folders. ADR-0006 (Accepted): the eight signal names, the INPUT role, commit before emit, `int` runtime IDs, registry calls legal from owner handlers, no listener calls `cancel()` or `cancel_pointer()`. ADR-0007 (Accepted): helpers in `tests/helpers/`, `EventLog` fakes with `typeof()` checks, the lint tool, L-TIME-1 and L-VEC-1. |
| **Enables** | ADR-0010 (HeroInput and TowerInput meaning, bot equivalence test TR-hero-012, the JSONL sink the gesture log shares with RunLog) |
| **Blocks** | Every story that builds `InputResolver`, registers a target, or listens to a resolver signal (Input, Hero UI, Tower UI and HUD stories). No epic or story exists yet, so none is blocked by path today. |
| **Ordering Note** | ADR-0003's spike S0a (ADR-0007 M1) must run before a story that rests on adapter behaviour, not before resolver unit stories, which never touch an event. |

## Context

### Problem Statement
Every MVP verb (pin, aim, build, upgrade, Start/Call) passes through one resolver. The Input GDD states its rules in detail, and B2 sketches its API, but five things are open: the payload of each renamed signal (ADR-0006 left payloads here), how re-entrant calls are queued and bounded, how the registry breaks ties and rejects bad input, what a "real tap winner" means in code, and how the Rule 13 gesture log gets data that no signal carries. A wrong choice here turns a miss into a mis-fire, which spends gold or moves the hero without consent (Pillar 4).

### Constraints
- Pure and clock-free: no `Node`, no scene tree, no engine events, no `Time`, `Engine`, `OS`, `Timer` or `await` (TR-input-001; L-TIME-1 covers `src/foundation`).
- Sim float policy (ADR-0004 Decision 9): `Vector2` is storage only in `src/foundation`; maths on `.x` and `.y` as `float` scalars; no `Vector2` operators or methods (L-VEC-1). `Vector2` components are 32-bit in a stock build (ADR-0004 E2); GDScript `float` is 64-bit.
- Sync emit only, commit before emit, no deferred calls, method Callables only (ADR-0001, ADR-0006).
- Errors use `push_error`, never `assert` (ADR-0001 Guideline 10).
- One thread. Gesture calls arrive from adapter callbacks before `_process`, or from `cancel()` inside a tick (Flow) or at teardown (AppRoot).

### Requirements
TR-input-001, TR-input-007, TR-input-008, TR-input-009, TR-input-010, TR-input-011, TR-input-015, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009, and the disc part of TR-input-013 handed over by ADR-0003 (sync item A2).

## Decision

### 1. The class and its factory (TR-input-001, TR-input-011)
- `class_name InputResolver extends RefCounted` in `src/foundation/input/input_resolver.gd`. It holds no reference to any other battle object and calls no injected Callable.
- The slops come only through `static func create(drag_slop: float, tap_slop: float) -> InputResolver`. It returns `null` unless `validate()` is true. The constructor `_init()` takes no arguments and is private by contract; only `create()` and tests of `create()` call `InputResolver.new()`.
- `static func validate(drag_slop: float, tap_slop: float) -> bool` is true only when both are finite (`is_finite`), `8.0 <= drag_slop <= 30.0`, `16.0 <= tap_slop <= 34.0`, and `tap_slop > drag_slop`. The bounds are the resolver's `const`s `DRAG_SLOP_MIN`, `DRAG_SLOP_MAX`, `TAP_SLOP_MIN`, `TAP_SLOP_MAX`. They are invariants, not balance; the Input record holds the tuned values. A test checks that these `const`s equal the Input record's schema domains (ADR-0002), so the two cannot drift.
- Comparisons are plain `float` comparisons. No epsilon: the bounds are exact in binary, and a value of 15.99 must fail (GDD AC 19).
- The Builder sends `null` to `fatal("input_record_invalid")` (ADR-0001 Decision 2, unchanged).

### 2. The registry (TR-input-007, TR-input-013 disc part)
- A target is a disc with seven fields: `id: int`, `centre: Vector2`, `radius: float`, `accepts: Accepts`, `priority: int`, `enabled: bool`, `sink: bool`. Stored as one private inner class instance per target in an `Array`, in id order. With about 15 MVP discs a linear scan costs less than a lookup structure.
- `enum Accepts { TAP, DRAG }`. `const NONE := -1`.
- `register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int` returns the next id from a counter that starts at 1 and never reuses a value. It returns `NONE` with `push_error` and registers nothing when: `centre.x` or `centre.y` is not finite; `radius` is not finite or not above 0; `accepts` is neither `TAP` nor `DRAG`; or `sink` is true with `DRAG` (a sink is TAP only). A new target starts enabled.
- `unregister(id)`, `set_centre(id, centre)` and `set_enabled(id, enabled)` act at once. An id never issued or already unregistered is a no-op with `push_error`. `set_centre` with a non-finite component keeps the old centre, with `push_error`.
- All four are legal in every state, inside any handler, and never queued (ADR-0006 Decision 3). They never change the gesture in flight, because its winners and the tap winner's disc are frozen (Decision 3).
- **Hit test** at press: a target is a candidate when `enabled` and `dx * dx + dy * dy <= r * r`, with `dx = p.x - c.x`, `dy = p.y - c.y`, all in 64-bit `float`, inclusive of the edge.
- **Tie-break within a class** is total: higher `priority`, then smaller squared distance, then lower `id`. TAP and DRAG never compete; a priority number means nothing across classes.
- **Discs, not Controls** (TR-input-013, disc part): the burst button, its sink, the Start/Call button, the build-arc discs and backdrop, the upgrade chip, towers, slots and the hero are registry discs drawn by field views. None is a `Control` that takes input. ADR-0003 and L-INPUT-2 already keep every wrapper `Control` but the TapScreens at `MOUSE_FILTER_IGNORE`.

### 3. The state machine (TR-input-008)
- `enum State { IDLE, PRESSED, DRAGGING, DEAD }`; `state() -> State` is a read-only query for tests and the log.
- Per gesture the resolver holds: `_active` pointer, `_press_x`, `_press_y`, `_best_tap`, `_best_drag`, the frozen tap disc as three floats (`_tap_cx`, `_tap_cy`, `_tap_r`), `_real_tap: bool` (best tap exists and is not a sink), `_slop_sq: float`, and the current `GestureTrace` (Decision 7).
- **Press slop**: `tap_slop` when there is a real tap winner or no winner at all; else `drag_slop` (a drag winner with no real tap winner, or only a sink). Stored squared; compared with `>=`, so a move of exactly slop crosses.
- The transition table is the Input GDD's "States and Transitions" table, verbatim, with the ADR-0006 names. The rules that need code-level wording:
  - **One active pointer.** In Pressed, Dragging and Dead, a call with another pointer is dropped, except a press when the gesture is **replaceable**: Pressed with no real tap winner, or Dead with no real tap winner. A replaceable press is replaced as `cancel()` then `press` in one call.
  - **Re-press of the active pointer** in any non-Idle state is `cancel()` then `press`.
  - **Replacement order.** The cancel part runs whole first: commit to Idle, finish the old trace, emit its signals (`drag_cancelled` only from Dragging, then `became_idle`). Then the press part commits and emits `pressed`. So a `became_idle` handler still reads the old gesture's `last_trace()`, and no argument copy is needed.
  - **`cancel_pointer(i)`** is `cancel()` when `i` is active, else dropped.
  - **Idle** drops `move`, `release` and `cancel_pointer`; `cancel()` in Idle emits nothing.
  - **Sticky drag**: once Dragging, never Pressed again.
  - **Release at or past slop in Pressed** (moves lost): with a drag winner, `drag_started` then `drag_ended` in that one call; with none, Dead then Idle with no gesture signal. Never a tap.
  - **Tap test at release** uses the frozen disc with no `enabled` term.
- **`became_idle()` closes every exit to Idle**, cancel included, after the gesture's own signal. Idle-to-Idle calls emit nothing.

### 4. Commit, emit and the re-entrancy queue (TR-input-010)
- **Commit before emit.** Each step writes every field (state, winners cleared to locals, trace finished) before its first `emit`. A handler that calls `state()` or `last_trace()` sees the final state.
- **One batch per gesture call.** A step's signals, its `became_idle()` included, form one batch delivered whole before the next queued call runs.
- **The queue.** The five gesture calls go through one private `_submit(op, pointer, pos)`. When `_draining` is false, it sets it, runs the op, then runs queued ops in FIFO order until none is left, then clears it. When `_draining` is true, it appends the op and returns at once. So a call from a handler runs after the current batch reaches every listener, in the outermost call's stack, synchronously. Nothing is deferred to a later frame.
- **Bound.** At most `MAX_QUEUED_PER_DRAIN := 64` ops are queued in one drain. A further op is dropped with `push_error`. A handler that presses from every `pressed` handler would otherwise loop forever; no legal chain comes near 64 (the longest in the GDD is one queued `cancel()` or `press`).
- **Non-finite positions** are dropped at `_submit`, before queueing, with `push_error`; state is unchanged (TR-input-011). `cancel()` has no position and is always accepted.
- **Queued `cancel()`** covers the case where a command in a handler raises a fatal and Flow calls `cancel_input()` mid-drain: the cancel runs after the batch.
- The queue lives in two reused arrays (`_q_ops: PackedInt32Array`, `_q_args: Array`) and a head index, cleared at the end of each drain. Nothing allocates per move.

### 5. Signal payloads (TR-input-009, TR-hud-009)
Names are ADR-0006 Decision 5's. Parameter names and types are part of the contract and go into `tests/integration/wiring/battle_signals.gd` as the eight INPUT rows. IDs are `int` (ADR-0006 Decision 6); positions are `Vector2` in field units, copied by value. No name reads as a `Node2D` property.

| Signal | When | Notes |
|---|---|---|
| `pressed(best_tap: int, best_drag: int, press_pos: Vector2)` | Idle to Pressed | Both winners, either may be `NONE`. A sink can be `best_tap`. The HUD ignores a Start/Call tap when `best_drag` names the hero (TR-hud-009) |
| `tapped(target: int, release_pos: Vector2)` | Release under slop inside the frozen tap disc | `target` is `best_tap`, sink included |
| `ground_tapped(release_pos: Vector2)` | Release under slop with no winner at all | Never after a replacement |
| `drag_started(target: int, press_pos: Vector2, pos: Vector2)` | First move at or past slop with a drag winner, or a lost-move release | The first `drag_moved` is the next move |
| `drag_moved(target: int, press_pos: Vector2, pos: Vector2)` | Each later move while Dragging | One per input call, never per frame |
| `drag_ended(target: int, press_pos: Vector2, release_pos: Vector2)` | Release while Dragging | `release_pos` unclamped; owners clamp |
| `drag_cancelled(target: int)` | `cancel()` while Dragging | Owner reverts |
| `became_idle()` | Last signal of every exit to Idle | No arguments |

### 6. What listeners may do (ADR-0006 INPUT role, made exact)
- Listeners are the three input owners (HeroInput, TowerInput, HudLogic), the GestureLog, and test fakes, all through `view_wiring.connect_recorded()` with flags 0. No sim connects. Headless, the resolver has no connection (ADR-0006 V1).
- From `pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved` and `drag_ended`, an owner may issue commands (ADR-0006 guard applies).
- From `drag_cancelled` and `became_idle`, an owner must never issue a command. Both come from `cancel()`, which Flow calls inside a tick and AppRoot calls at teardown; an owner only reverts or clears its own presentation state there.
- Any owner handler may call `register`, `unregister`, `set_enabled` and `set_centre`. No listener ever calls `press`, `move`, `release`, `cancel_pointer` or `cancel`. Only resolver fixture tests call gesture methods from a handler; the queue keeps them correct.
- Listeners never rely on their order among themselves.

### 7. The gesture trace (TR-input-015, resolver side)
Rule 13 needs facts that no signal carries: travel under slop, where a silent gesture ended, and why a winner won. The resolver keeps them in a plain value and stays clock-free.
- `class_name GestureTrace extends RefCounted` in `src/foundation/input/gesture_trace.gd`, read-only by contract. Fields: `pointer: int`, `press_pos: Vector2`, `end_pos: Vector2` (last accepted position), `max_travel_sq: float`, `press_slop: float`, `best_tap: int`, `best_drag: int`, `tap_is_sink: bool`, `candidates: int`, `tap_rule: StringName`, `drag_rule: StringName` (`&"none"`, `&"only"`, `&"priority"`, `&"distance"`, `&"id"`: the first tie-break term that decided), `outcome: Outcome`.
- `enum Outcome { TAPPED, ROLLED_OFF, GROUND_TAPPED, DRAG_ONLY_RELEASED, DRAG_ENDED, DRAG_CANCELLED, DEAD, CANCELLED, REPLACED }`, declared in `GestureTrace`.
- A fresh trace starts at each press, so a reader holding an old one never sees it change. `last_trace() -> GestureTrace` returns the latest; `null` before the first press. It is final before `became_idle()` is emitted.
- Cost: one small object per press and a max per move. It runs in every build, so the resolver has one code path.
- Only `src/presentation/dev/` and tests may call `last_trace()` (L-INPUT-7). No owner may base meaning on it.

### 8. The gesture log harness (TR-input-015, harness side; Data Flow 9)
- `class_name GestureLog extends RefCounted` in `src/presentation/dev/gesture_log.gd`. The BattleWrapper builds it only when `OS.is_debug_build()` is true; release builds never build it, so they never write.
- `setup(resolver: InputResolver, device: String, insets: FieldInsets, now_ms: Callable, append_line: Callable, chip_state: Callable, dev_error: Callable)`. Every Callable is a method Callable (ADR-0001). `now_ms` is the wrapper's `Time.get_ticks_msec` wrapper, so tests inject a fake clock; `append_line(line: String) -> bool` is ADR-0010's JSONL sink to `user://gesture_log.jsonl`; `chip_state` is TowerInput's read.
- It listens through `view_wiring` to all eight resolver signals and to TowerSim's `tower_upgraded(slot_index, level)`. It is view-only (ADR-0006): no command, no registry call, no gesture call, no kept payload object.
- `set_prompt(action: StringName, target: int, target_centre: Vector2)` is called by the phone-test prompter. For a tower prompt it reads `chip_state()` at that moment.
- One JSON line per gesture, written in its `became_idle` handler: `t_down_ms`, `t_up_ms`, `hold_ms`, `device`, `insets`, `press`, `end`, `max_travel` (the harness takes the square root; it is not sim code), `press_slop`, both winners, `tap_is_sink`, both rules, `outcome`, the signal it emitted, the prompt's `action` and `target`, the press offset from `target_centre`, and `chip_open`. One line per `tower_upgraded`, with its time. The P1 table computes misses and mis-fires from these lines.
- `append_line` returning false reports once to `dev_error` and the log goes on; a failed write never touches the battle.

### 9. Owner contracts this ADR fixes (TR-tower-011, TR-hero-010, TR-hud-008)
Meaning stays with the owners and ADR-0010. The resolver-facing rules are:
- **TowerInput** registers each slot and tower as TAP 200 (r 36), and the chip as TAP 300 (r 40) at the tower's (x, y - 76) while the chip is open. It calls `set_enabled(slot, false)` from its `tower_built` handler, unregisters the chip on close and from its `phase_changed` handler, and ignores taps while `halted()` is true.
- **HeroInput** registers the hero as DRAG 200 (r 56), the burst button as DRAG 100 (r 48) and its sink as TAP 400 (r 48, `sink = true`). It calls `set_centre(hero, ...)` from `update()` in frame step 1 (ADR-0004 Decision 4) while the hero walks. Cancel hysteresis (64 out, 48 back) is its own scalar test on the drag positions; the resolver knows nothing of it.
- **HudLogic** registers the arc backdrop (TAP 250, sink) and three discs (TAP 300) inside its `slot_tapped` handler, which runs inside TowerInput's `tapped` handler; the ids come back at once and compete from the next press. It unregisters them on close (`pressed` naming another best tap, `drag_started`, `phase_changed` to Paused, an outcome or Fatal), and calls `set_enabled(start_call, false)` while an arc is open.

### Architecture Diagram

```
InputAdapter (ADR-0003) ── press / move / release / cancel_pointer / cancel ──┐
Flow.cancel_input() (in tick) ── cancel ─────────────────────────────────────┤
AppRoot teardown ── cancel ──────────────────────────────────────────────────┤
                                                                              ▼
                     InputResolver (RefCounted, src/foundation/input)
   _submit ─► drop non-finite ─► draining? ─yes─► queue (FIFO, max 64 per drain)
                                    │no
                                    ▼
                  run op: commit state + trace ─► emit batch ─► drain queue
   registry: register / unregister / set_centre / set_enabled  (immediate, any state)
                                    │ 8 signals (sync, view_wiring, flags 0)
          ┌─────────────────────────┼──────────────────────┬──────────────────┐
          ▼                         ▼                      ▼                  ▼
      HeroInput                TowerInput              HudLogic      GestureLog (debug only)
   pin / burst commands   chip, build / upgrade      arc, Start/Call   reads last_trace(),
   (not from drag_cancelled or became_idle)                            tower_upgraded, chip_state()
```

### Key Interfaces

```gdscript
class_name InputResolver extends RefCounted
enum Accepts { TAP, DRAG }
enum State { IDLE, PRESSED, DRAGGING, DEAD }
const NONE := -1
const DRAG_SLOP_MIN := 8.0
const DRAG_SLOP_MAX := 30.0
const TAP_SLOP_MIN := 16.0
const TAP_SLOP_MAX := 34.0
const MAX_QUEUED_PER_DRAIN := 64

## True only for finite slops inside their domains with tap_slop > drag_slop.
static func validate(drag_slop: float, tap_slop: float) -> bool
## Null when validate() is false. The only way to build a resolver.
static func create(drag_slop: float, tap_slop: float) -> InputResolver

## Gesture calls. Adapter only (and tests). Field units. Queued when called mid-drain.
func press(pointer: int, pos: Vector2) -> void
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
## Callers: adapter, Flow via cancel_input(), AppRoot at teardown.
func cancel() -> void

## Registry. Any state, any owner handler, never queued.
func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void

## Read-only queries.
func state() -> State
func last_trace() -> GestureTrace     # src/presentation/dev/ and tests only

signal pressed(best_tap: int, best_drag: int, press_pos: Vector2)
signal tapped(target: int, release_pos: Vector2)
signal ground_tapped(release_pos: Vector2)
signal drag_started(target: int, press_pos: Vector2, pos: Vector2)
signal drag_moved(target: int, press_pos: Vector2, pos: Vector2)
signal drag_ended(target: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(target: int)
signal became_idle()

class_name GestureTrace extends RefCounted   # read-only by contract; fresh per press
enum Outcome { TAPPED, ROLLED_OFF, GROUND_TAPPED, DRAG_ONLY_RELEASED, DRAG_ENDED,
               DRAG_CANCELLED, DEAD, CANCELLED, REPLACED }
var pointer: int
var press_pos: Vector2
var end_pos: Vector2
var max_travel_sq: float
var press_slop: float
var best_tap: int
var best_drag: int
var tap_is_sink: bool
var candidates: int
var tap_rule: StringName
var drag_rule: StringName
var outcome: Outcome

class_name GestureLog extends RefCounted     # src/presentation/dev/; debug builds only
func setup(resolver: InputResolver, device: String, insets: FieldInsets, now_ms: Callable,
           append_line: Callable, chip_state: Callable, dev_error: Callable) -> void
func set_prompt(action: StringName, target: int, target_centre: Vector2) -> void
```

### Implementation Guidelines
1. `InputResolver` must extend `RefCounted`, live in `src/foundation/input/`, and must never reference a `Node`, a scene, an engine input class, `Time`, `Engine`, `OS`, a `Timer` or `await` (L-TIME-1, L-LAYER-1).
2. Resolver maths must use `float` scalars from `.x` and `.y`; it must never use a `Vector2` operator or method (L-VEC-1). Squared distances only; no `sqrt` in the resolver.
3. Code must build a resolver only through `create()`; game code must never call `InputResolver.new()`.
4. Every gesture call must pass through `_submit`; every step must commit all fields, the trace included, before its first `emit`.
5. A call made while draining must be queued, never run nested and never deferred; the outermost call must drain the queue before it returns.
6. The resolver must drop a non-finite position with `push_error` before it queues, and must reject a non-finite or non-positive radius, a non-finite centre, a bad `accepts` or a DRAG sink at `register` with `NONE` and `push_error`.
7. Ties must break by higher priority, then smaller squared distance, then lower id; TAP and DRAG must never be compared.
8. Winners and the tap disc must be frozen at press; no registry call may change a gesture in flight.
9. Every exit to Idle must emit `became_idle()` last; Idle-to-Idle calls must emit nothing.
10. A replacing press must run the cancel part whole (commit, emit) before the press part commits.
11. Owners must never issue a command from `drag_cancelled` or `became_idle`.
12. Only the adapter may call `press`, `move`, `release` and `cancel_pointer`; only the adapter, Flow's injected `cancel_input()` and AppRoot may call `cancel()` (L-INPUT-6).
13. No owner may read `last_trace()`; only `src/presentation/dev/` and tests may (L-INPUT-7).
14. The BattleWrapper must build `GestureLog` only when `OS.is_debug_build()` is true; `GestureLog` must never command, call the registry or keep a payload object.
15. Every resolver signal must have a row in `battle_signals.gd` with the Decision 5 names and types.
16. Resolver tests must drive the five calls with synthetic positions and record into ADR-0007's `EventLog`; they must never use an engine input event, a scene or a timer.

## Alternatives Considered

### Alternative 1: Engine picking (`Area2D` with `input_pickable`, or `CollisionObject2D._input_event`)
- **Description**: each target is an `Area2D` with a `CircleShape2D`; the engine picks the hit.
- **Pros**: no hit-test code; editor shows the shapes.
- **Cons**: needs a scene tree and engine events, so no headless unit test; pick order follows tree and z order, not per-class priority; two classes per press and frozen discs do not exist; picking behaviour under ADR-0003's `_unhandled_input` split is unverified on 4.7.
- **Rejection Reason**: breaks TR-input-001 and makes the zero mis-fire rule a hope, not a proof.

### Alternative 2: Targets as `Control`s with `mouse_filter`
- **Description**: the burst button, arc and chip are `Button`s; Godot's GUI order resolves overlaps.
- **Pros**: familiar; focus and theme come free.
- **Cons**: GUI order is not the priority table; a `Control` above the field swallows presses before the adapter (ADR-0003 forbids it); 4.6 dual focus adds risk; still untestable headless.
- **Rejection Reason**: TR-input-013 and ADR-0003 require discs.

### Alternative 3: Each owner hit-tests the five calls itself
- **Description**: no registry; the adapter fans calls out and each owner decides.
- **Pros**: less shared code.
- **Cons**: the priority order lives in four places; two owners can both act on one press; no one owns the mis-fire.
- **Rejection Reason**: the GDD and systems index fix the registry as the one owner of priority.

### Alternative 4: Deferred re-entrant calls (`call_deferred`) instead of a queue
- **Description**: a call from a handler runs at the end of the frame.
- **Pros**: no queue code.
- **Cons**: lands after `_process`, past the frame's ticks, so a nested command would read a different tick (ADR-0004 E7); banned by ADR-0006 Decision 1.
- **Rejection Reason**: banned, and breaks "shown equals paid".

### Alternative 5: Gesture log from signals alone
- **Description**: the harness rebuilds every Rule 13 field from the eight signals.
- **Pros**: no new resolver query.
- **Cons**: moves under slop emit nothing, so maximum travel is unknown; a roll-off, Dead gesture or cancel has no end position; the tie-break rule is never visible.
- **Rejection Reason**: Rule 13 fields would be missing, so the P1 table could not be computed.

### Alternative 6: Unbounded queue
- **Description**: drain until empty, whatever handlers add.
- **Pros**: no constant.
- **Cons**: a buggy handler that presses from `pressed` hangs the game with no error.
- **Rejection Reason**: a bound with `push_error` turns a hang into a visible dev error at no cost to legal chains.

## Consequences

### Positive
- The whole gesture rule set runs headless with synthetic positions; GDD AC 1 to 37 map one to one to unit tests.
- Payload types are in the signal table, so a wrong type or a renamed parameter fails ADR-0006 V1 by name.
- A gesture can reach only the target on top in its own class at press, so zero mis-fires is provable.
- The phone test gets every Rule 13 field without a clock in the resolver and without a Tower log.
- Re-entrancy is deterministic: the same calls give the same log on every run (GDD AC 23).

### Negative
- Two new public items beyond B2: `state()` and `last_trace()`, plus the `GestureTrace` class. A lint is needed to keep owners off the trace.
- A new owner rule (no commands from `drag_cancelled` or `became_idle`) that only review and tests can check; the lint matches names, not handler roles.
- Two lint rows (L-INPUT-6, L-INPUT-7) for ADR-0007's table, which is Accepted and gains them at its next revision.
- The GDD's signal and parameter names need a sync pass (ADR-0006 Migration 2 covers the renames; this ADR adds parameter names).

### Neutral
- The resolver allocates one `GestureTrace` per press in every build.

## Risks
- **R1 fails** (a nested call inside a handler runs before the next listener of the outer emit is called): the queue already prevents nesting, so no change; record it.
- **R2 differs** (a script error in a handler stops `emit` from reaching later listeners, or returns control in an odd state): `_draining` is set and cleared in the resolver's own frame, so it stays correct either way; listeners must not assume delivery after a broken handler. Record it.
- **R3 differs** (a 32-bit `Vector2` component rounds an integer test position, or turns NaN or INF into a finite value): boundary tests use integers below 2^24, which float32 stores exactly; if NaN or INF does not survive storage, the non-finite tests move to `float` inputs and the adapter's own finite check (ADR-0003) is the guard.
- **The queue bound is hit in play**: a dev error names the drop; the cause is a handler bug, fixed in that handler.
- **A replacing press lets a palm steal an unmoved hero or burst press** (GDD Open Questions): kept by design; the phone test watches it.
- **Owners lean on `last_trace()` for meaning**: L-INPUT-7 fails the build.
- **Adapter guarantees** (exactly one ending per press) rest on ADR-0003's spike; a stranded gesture recovers on the next press of the same index.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-001: pure, scene-free, clock-free, driven only by the five calls | Decision 1; Guidelines 1, 2, 16. Full |
| input-gesture-resolver.md | TR-input-007: disc registry {id, centre, radius, accepts, priority, enabled, sink}; registry calls legal in any state, at once | Decision 2. Full |
| input-gesture-resolver.md | TR-input-008: four states, one active pointer, frozen TAP and DRAG winners, per-press slop | Decision 3. Full |
| input-gesture-resolver.md | TR-input-009: the signal API; `became_idle()` last on every exit to Idle | Decisions 3, 5 (ADR-0006 names). Full |
| input-gesture-resolver.md | TR-input-010: commit before emit; FIFO queue drained in the outermost call | Decision 4. Full |
| input-gesture-resolver.md | TR-input-011: `validate()`, `create()` null on bad input; non-finite dropped with `push_error` | Decisions 1, 2, 4. Full |
| input-gesture-resolver.md | TR-input-013 (disc part, shared with ADR-0003): burst button, build arc and world targets are discs | Decision 2. Full for the disc part; ADR-0003 holds the Control part |
| input-gesture-resolver.md | TR-input-015: dev gesture log with device, insets, timing, travel, winners, classification, `tower_upgraded`, `chip_state()` | Decisions 7, 8. Full in design; the JSONL sink is ADR-0010's, so writes wait for it |
| tower-system.md | TR-tower-011: TowerInput registers slots and chip, disables built slots, closes chip on phase, ignores taps while halted | Decisions 2, 6, 9. Full for the resolver side; result codes are ADR-0010's |
| hero-system.md | TR-hero-010: hero DRAG, button DRAG and sink TAP discs; centre updated each frame; hysteresis hit test | Decisions 2, 5, 9. Full for the resolver side; aim meaning is ADR-0010's |
| battle-hud.md | TR-hud-008: arc registers and unregisters on open and close, disables Start/Call, closes on outcome, Paused or Fatal | Decisions 2, 6, 9. Full |
| battle-hud.md | TR-hud-009: `pressed` exposes both `best_tap` and `best_drag` | Decision 5. Full |

## Performance Implications
- **CPU**: per press, one pass over at most about 20 discs (two multiplies and a compare each); per move, one squared distance and a max. Far below 0.05 ms on the target phone (unmeasured; no budget row needed). Runs at frame step 0, outside the tick slice.
- **Memory**: one inner object per target, one `GestureTrace` per press, two reused queue arrays. Under 4 KB.
- **Load Time**: none. **Network**: none.

## Migration Plan
No code exists. On acceptance:
1. **ADR-0007 handover** (rows for its lint table at its next revision): L-INPUT-6 (C3, `src/`): `press(`, `move(`, `release(`, `cancel_pointer(` or `cancel(` called on a receiver named `*resolver*` outside `input_adapter.gd`, `app_root.gd` and the Builder's Callable creation. L-INPUT-7 (T3, `src/` but `src/presentation/dev/`): `last_trace(` or `GestureTrace`. `fakes/recording_resolver.gd` also logs the four registry calls with their arguments, as the Hero, Tower and HUD GDD tests need.
2. **Signal table**: eight INPUT rows in `battle_signals.gd` with Decision 5's names and types.
3. **GDD sync** (game-designer; list only, see Related).
4. **architecture.md** (list only): B2 takes Decision 5's signal block, `state()`, `last_trace()`, the `const`s and `GestureTrace`; Module Ownership InputResolver row (names, trace); RunLog / GestureLog row (GestureLog decided here; sink ADR-0010); Data Flow 1 table (no change); Data Flow 9 (`last_trace()` read in `became_idle`); Required ADRs (ADR-0008 written, Proposed); B2's QQ-07 note removed.

## Validation Criteria
Unit tests in `tests/unit/input_gesture_resolver/` (names proposed), shared fakes from `tests/helpers/`; every THEN compares the whole `EventLog`.
- **V1 GDD criteria**: AC 1 to 37 of the Input GDD, with ADR-0006 names, each as one test.
- **V2 payload types**: each signal recorded once; the recorder checks count and `typeof()` per argument against `battle_signals.gd` (int ids, `Vector2` positions) with no `type_errors()`.
- **V3 replacement order**: a listener reading `last_trace()` in `became_idle` during a replacing press sees `outcome == REPLACED` and the old `press_pos`; the next `pressed` names the new winners.
- **V4 queue bound**: a listener that calls `press` from every `pressed` handler gives exactly 1 + 64 `pressed` entries, one `push_error`, and returns.
- **V5 queued cancel**: a listener calling `cancel()` inside `pressed` gives `pressed, became_idle` to every listener in order; a later release adds nothing (AC 27).
- **V6 register rejects**: radius 0, -1, NAN, INF; centre with NAN or INF; `accepts` 2; DRAG with `sink`; each returns `NONE`, one `push_error`, and the next id is unchanged.
- **V7 trace**: for a tap, a roll-off, a ground tap, a drag, a cancel and a Dead press, each field of `last_trace()` matches; a trace held from gesture 1 is unchanged after gesture 2.
- **V8 bounds match schema**: the four slop `const`s equal the Input record's schema domains.
- **V9 GestureLog** (unit, fake clock and sink): one scripted tap, drag and cancel give three lines with every Rule 13 field; a `tower_upgraded` gives one line; a sink returning false gives one dev error and logging goes on.
- **V10 lints**: L-INPUT-6 and L-INPUT-7 fail on planted samples.
- **Engine probes** (`tests/unit/engine/resolver_probes_test.gd`, proposed). Unverified offline; results go into `docs/engine-reference/godot/` with date and version.
  - **R1** a call made inside a signal handler returns before `emit()` calls the next listener (ADR-0006 E5).
  - **R2** a runtime error in one handler: does `emit()` still call later listeners and return to the emitter?
  - **R3** `Vector2(306.0, 480.0).x == 306.0`; `is_nan(Vector2(NAN, 0.0).x)` and `is_inf(Vector2(INF, 0.0).x)` are true; `(306.0 - 270.0) * (306.0 - 270.0) <= 36.0 * 36.0` is true.
  - **R4** `is_finite()` is false for NAN, INF and -INF and true for 0.0.
  - **R5** a typed signal parameter of `int` on a `RefCounted` script reports `TYPE_INT` in `get_script_signal_list()` (ADR-0006 E1 shape).

## Reviews
Reviews still owed: godot-specialist (Step 5.5) and TD-ADR (Step 5.6) were not run in this session; the caller runs them. GDD sync: checked 4 referenced GDDs; inconsistencies found and listed under Related, not edited.

## Related
- Depends on ADR-0001, ADR-0003, ADR-0004, ADR-0006, ADR-0007 (all Accepted). Enables ADR-0010. Supersedes nothing; contradicts nothing.
- GDDs: `design/gdd/input-gesture-resolver.md` (primary), `tower-system.md`, `hero-system.md`, `battle-hud.md`.
- GDD sync items, not made here:
  - **Input GDD**: signal renames (`tap`, `ground_tap`, `idle`; ADR-0006 Migration 2); payload parameter names (`p` becomes `press_pos`, `release_pos` or `pos`; `best_tap`/`best_drag` become `target` in `tapped` and `drag_*`); Rule 9 adds "a DRAG sink or an unknown `accepts` returns `NONE`"; Rule 11 says the Builder builds the resolver and the wrapper builds the adapter (ADR-0001); Rule 13 names `last_trace()` and `GestureTrace` as the source of travel, end position and tie-break rule; States and Transitions notes the 64-call drain bound; Acceptance Criteria preamble moves the fake to `tests/helpers/fakes/` (ADR-0007).
  - **Hero GDD**: Rule 13 and the Interactions row name `became_idle` and state that no command is issued from `drag_cancelled` or `became_idle`.
  - **Tower GDD**: Rule 17 and the gesture-log rows name `GestureLog` and `set_prompt`.
  - **Battle HUD GDD**: rows naming `tap`, `idle`, `ground_tap` take ADR-0006 names.
