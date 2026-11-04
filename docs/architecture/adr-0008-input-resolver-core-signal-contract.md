# ADR-0008: Input Resolver Core and Signal Contract

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
> 1. ADR-0003 and ADR-0006 are Accepted (so ADR-0001 and ADR-0004 are too).
> 2. V1 to V8 (Engine Compatibility) have recorded results in
>    `docs/engine-reference/godot/current-best-practices.md` with the engine version. V2 and V3 count
>    once ADR-0009 V1 and V3 are recorded; V1 shares one script with ADR-0006 V4 and V5. Where a
>    result takes a branch, this ADR is revised to that branch first. V7 and V8 need a desktop result;
>    their phone results come at the first phone build and change one log field or the sink only.
> 3. The cascade edits (section a) are applied, or the user overturns them one by one.
> 4. The user has confirmed or overturned each of the seven choices in Decision 11.
>
> **After acceptance:** the Input GDD's 37 Logic criteria become the resolver's unit tests (first
> resolver story). Reopen trigger: any Validation Criterion that cannot pass as written, or a
> phone-test log (Pillar 4 gate P1) showing a mis-fire the resolver caused, amends this ADR before
> the next input story closes.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only (Godot 4.7.2). The live Godot 4.7 documentation was not reachable from the authoring session (`docs.godotengine.org` is outside the session's network policy). The resolver is plain GDScript with no engine call in its decision path; each engine behaviour it relies on that the pinned reference does not cover is a verification item (V1 to V8), not a fact.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS on the first draft, findings T1 to T9 applied in this revision), godot-specialist (engine check: blocking findings E1 and E2 and the minor notes applied to Decision 7, Decision 8, V1, V6, V8 and Risks). Authored with the /architecture-decision flow in autonomous mode.

## Summary

The Input & Gesture Resolver turns one pointer's press, moves and release into exactly one tap, one drag or nothing for exactly one registered disc; its GDD fixes the rules but not how a pure object meets them under re-entrant handlers, frozen winners and a development gesture log. This ADR decides an `InputResolver extends RefCounted` built by `BattleBuilder` through `create(drag_slop, tap_slop, dev_error)` and held as `Battle.resolver`; a value-only target registry keyed by never-reused `int` ids (no owner reference, so no cycle); a four-state machine whose winners and discs are frozen as scalars at press; one FIFO call queue drained by the outermost call, in which each call commits and then emits its whole batch; `Vector2` only at the API with 64-bit scalar maths inside; ADR-0006's signal names and payloads exactly; and a `GestureRecord` read that a development-only `GestureLog` node writes out for the Pillar 4 phone test.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM. The resolver calls no engine input API (ADR-0003's adapter holds every HIGH input fact). What remains is GDScript behaviour: synchronous delivery with a listener calling back into the emitter, reference holding during a member call, `Vector2` component width, `is_finite`, enum-typed parameters, default `Callable` arguments, inner classes, and, for the development log only, `OS` and `FileAccess` behaviour. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md` (no touch coverage; nothing applies to a pure resolver). ADR-0001, ADR-0003, ADR-0004, ADR-0006, ADR-0009; `docs/registry/architecture.yaml`. |
| **Post-Cutoff APIs Used** | None. Pinned facts used: an override of a typed method inherits its return type and needs an explicit `return` (4.7, `breaking-changes.md`), which binds test fakes; packed-array element writes skip a property setter (4.7, `current-best-practices.md`), irrelevant here (no setter, `append` only); `FileAccess.store_*` returns `bool` (4.4, `breaking-changes.md`). |
| **Verification Required** | V1 to V8. NOT SOURCEABLE in `docs/engine-reference/godot/**`: synchronous `emit()` with a call back into the emitter; whether a running member function keeps its `RefCounted` object alive; what a script error inside a callee does to its caller; disconnect during `emit()`; `Vector2` width (ADR-0009 V1); `is_finite` (ADR-0009 V3); out-of-range enum arguments; `Callable()` defaults; inner classes as typed `Array` elements; `OS.get_model_name()`, `OS.is_debug_build()`; `FileAccess` open modes and `seek_end`. |

### Verification items

This ADR stays `Proposed` until each item has a recorded result (Status, step 2). Owner: godot-specialist writes the scripts; the user runs them headless on the pinned 4.7.2 editor (`godot --headless -s <script>`, outside `src/`); results go into `current-best-practices.md`. "Expected" is the author's or the engine check's expectation, not a source.

- **V1. Delivery, re-entry and lifetime** (one script with ADR-0006 V4 and V5, `prototypes/adr-0006-signal-check/`, extended). (a) A `RefCounted` emitter with `signal s(a: int)` and a method `poke(x)` that appends to a `PackedInt64Array`: listener A (connected first) calls `emitter.poke(1)`, listener B logs; does `s.emit(7)` run A then B before it returns, with no error from the call back? (b) `while i < arr.size()` sees an element a listener appended during the loop. (c) A listener that calls `disconnect` on itself or another listener during the emit: does the running emit still call it (expected: yes, the list is copied first)? (d) An emitter whose only strong reference a listener drops during the emit: with `var _hold := self` at the top of the emitting method, does the method finish and the object free after it returns; without it, what happens? (e) A script error inside a callee `_run()` called from a loop in `_enqueue()`: in the editor's debug run, does `_enqueue` continue, or abort with its locals and flags as they were? Expected: (a), (b), (c) yes; (d) the hold keeps it alive; (e) aborts in debug (engine check). **Decision 7 depends on (a), (b) and (d).** Branch: if (a) fails, the resolver cannot know when a batch is delivered and this ADR and ADR-0006 Decision 1 are reopened together; if (d) shows no hold is needed, the line stays as a harmless guard.
- **V2. `Vector2` component width (QQ-05).** Reuses ADR-0009 V1. Add: `Vector2(299.0, 500.0).x - 270.0 == 29.0`. No decision depends on it (Decision 3 holds for 32-bit and 64-bit components).
- **V3. Non-finite floats.** Reuses ADR-0009 V3. Add: `is_finite(Vector2(NAN, 0.0).x)` and `is_finite(Vector2(INF, 0.0).x)` are false. Branch: none needed, since the guard reads the component.
- **V4. Out-of-range enum arguments.** Passing `5`, `-1` or another enum's value to a parameter typed `Accepts`. Expected: no runtime check, possibly `INT_AS_ENUM_WITHOUT_CAST` or `INT_AS_ENUM_WITHOUT_MATCH` warnings. Nothing branches: `register` checks the value explicitly (Decision 4).
- **V5. `Callable()` defaults.** `static func create(a: float, b: float, dev_error: Callable = Callable())` and `func _init(a: float, b: float, dev_error: Callable = Callable())` parse; `Callable().is_valid()` is false; a method Callable passed in is valid. Branch: if a default does not parse, the argument becomes required everywhere and fixtures pass a recording fake.
- **V6. Inner classes and fakes.** In `class_name InputResolver extends RefCounted`: an inner `class Target extends RefCounted`; `var _targets: Array[Target] = []`; `remove_at` keeps order (ADR-0009 V2(e)); `create()` calls `InputResolver.new(a, b, c)`. A test-folder `class_name FakeResolver extends InputResolver` overrides `register(...) -> int` with an explicit `return` and is built with `FakeResolver.new(15.0, 28.0)` (its `_init` forwards to `super(a, b)`, relying on the third argument's default). `FakeResolver.create(...)` returns an `InputResolver`, not a fake (static methods are not virtual), so tests never call it. Branch: if the inner class cannot be an `Array` element type, `_targets` is an untyped `Array`; if a fake cannot extend `InputResolver`, ADR-0007 fakes wrap it and owners type the parameter `Object`.
- **V7. Development-build facts.** `OS.is_debug_build()` true in an editor run and a debug export (release side: ADR-0001 V4); `OS.get_model_name()` non-empty on desktop and Android. Desktop gates acceptance; the Android value is recorded at the first phone build. Branch: an empty or generic phone value means the tester types a device label into the harness config.
- **V8. Appending to a file (development builds only).** `FileAccess.open(path, FileAccess.WRITE)` truncates; `READ_WRITE` fails on a missing file; `seek_end()` then `store_string()` appends; `flush()` writes through; each `store_*` returns `bool`. Expected per the engine check: as stated. Branch: if `READ_WRITE` truncates, the sink rewrites the file from an in-memory list at each flush. Desktop gates acceptance; Android at the first phone build.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Proposed): the adapter is the only production caller of the five gesture calls; it queues them and delivers them in `InputAdapter.flush()` at frame step 0; `cancel_all()` empties its queue and calls `resolver.cancel()`; positions are `Vector2` in 540x960 field units (registry `resolver_drive`). ADR-0006 (Proposed): signal names (`pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `became_idle`), parameter names and types, `int` ids with `NONE = -1`, listener rules (G7 and G8 listeners never issue commands), wrapper connections only, flags 0. Both must be Accepted before this one. Binding, not gating: ADR-0001 (Builder step 2 creates the resolver and null is fatal; method Callables only; no RefCounted cycle; no mutable `static var`; `dev_error`; Decision 7: only `AppRoot._process` tears down, never inside a signal handler or a fatal call; the weakref proof), ADR-0004 (frame order; float policy; V4 release unwinding), ADR-0009 (Decision 2 scalar positions, V1, V3), ADR-0002 (`InputRecord`). ADR-0005 is not used (TR-input-012). |
| **Enables** | ADR-0007 (resolver unit tests, recording and `FakeResolver` fakes, lints from Implementation Guidelines), ADR-0010, ADR-0011 (views draw owners' state, never the resolver's). |
| **Blocks** | Input & Gesture Resolver stories; every HeroInput, TowerInput and HudLogic story that registers a target or listens to a gesture signal; the Pillar 4 phone-test harness story. |
| **Ordering Note** | ADR-0010 inherits from this ADR only the resolver API (Key Interfaces), the registry calls and `GestureRecord`; owner behaviour (Decision 9) is the GDDs', and ADR-0010 decides its open items. ADR-0006's GDD renames are applied, so resolver tests use the new names from the start. |

## Context

### Problem Statement

The Input GDD states the resolver's rules completely: 13 rules, a transition table, edge cases and 37 Logic criteria written as exact signal logs. Five questions remain before the first story. (1) A listener may call `press`, `cancel` or `register` from inside a handler (the HUD registers arc discs inside `tapped(slot)`; a bot presses from a `tapped` handler), so the resolver needs one exact rule for when a nested call runs and what it sees. (2) Owners register targets; the registry must not hold them, or the battle leaks on retry (ADR-0001). (3) ADR-0003 and ADR-0006 fix `Vector2` at the API, while ADR-0004 and ADR-0009 ban `Vector2` arithmetic on values that reach sim state, and the resolver chooses which command runs. (4) The gesture log (Rule 13, TR-input-015) needs data no signal carries (maximum travel, the rule that chose a winner) while the resolver stays clock-free. (5) `Battle` has no resolver member yet (ADR-0003 used a placeholder `resolver()`), and the error path for a bad registration is unstated.

### Current State

No code exists. `architecture.md` B2 sketches the API with ADR-0006's names; ADR-0003 fixed the adapter and its queue; ADR-0001 put creation in Builder step 2 and the resolver in the weakref proof; ADR-0004 put `HeroInput.update()` (which moves the hero's disc) in frame step 4. The mouse prototype (`prototypes/hero-pin-concept/main.gd`) resolved presses inline with no registry and no queue.

### Constraints

- Godot 4.7.2, GDScript, one main thread (TR-state-003). No engine input API in the resolver (ADR-0003).
- ADR-0001: no autoload, no mutable `static var`, no RefCounted cycle, method Callables only, `dev_error` for non-fatal breaches, no `assert` for a release-relevant check, teardown only from `AppRoot._process`.
- ADR-0006: names and payload types as fixed; wrapper connections, flags 0; G1 to G6 fire only from `flush()` at frame step 0; G7 and G8 may fire inside a tick or an engine callback.
- ADR-0004: commands only between ticks; no engine time in sim code or real-time models; float policy.
- Registry `sim_position_representation`: `Vector2` allowed for adapter input and view-signal payloads, never for a stored or compared sim position.
- Solo, part-time developer: one class, testable headless from the GDD criteria as written.

### Requirements

- Pure, scene-free, clock-free, driven only by the five gesture calls (TR-input-001).
- A disc registry whose four calls are legal in any state and apply at once (TR-input-007).
- Four states, one active pointer, winners frozen at press, per-press slop (TR-input-008).
- ADR-0006's eight signals, `became_idle` last on every exit to Idle (TR-input-009).
- Commit before emit; nested gesture calls queue FIFO and drain in the outermost call (TR-input-010).
- `validate()` and a `create()` that returns null; non-finite input dropped with `push_error` (TR-input-011).
- A development-build gesture log with the Rule 13 fields (TR-input-015).
- Serve TowerInput, HeroInput and the HUD as their GDDs require (TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009).
- Within the 0.5 ms input slice (ADR-0004 Decision 10).

## Decision

### 1. One pure class

`InputResolver` (`src/foundation/input/input_resolver.gd`, `class_name InputResolver extends RefCounted`) is the whole resolver. It reads no node, scene tree, viewport, display, `Input`, `Engine`, `Time`, `OS`, timer or `await`, overrides no engine callback, and references no other project class except `GestureRecord` (Decision 8). Inputs: the five gesture calls, the four registry calls, the two slops and the `dev_error` Callable. Outputs: eight signals, return values and three read-only queries (`state()`, `centre_of(id)`, `last_gesture()`). It holds no reference to any battle object, owner or node.

Only `InputAdapter.flush()` calls `press`, `move`, `release` and `cancel_pointer` in production; tests and the equivalence harness (Hero criterion 27) call them directly. `cancel()` is called by the adapter's `cancel_all()` (lifecycle, resize, and Flow's `cancel_input()`, ADR-0003 Decision 9) and by the wrapper's `detach()` (ADR-0001 Decision 6). Owners call none of the five at MVP.

### 2. Construction and ownership

- `static func validate(drag_slop: float, tap_slop: float) -> bool`: true only if both are finite, `8 <= drag_slop <= 30`, `16 <= tap_slop <= 34` and `tap_slop > drag_slop` (Input Rule 9).
- `static func create(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> InputResolver`: null when `validate` is false, else `InputResolver.new(drag_slop, tap_slop, dev_error)`. It reports nothing; the caller owns the failure. `_init` takes the same three arguments, the third with the same default, and computes `_drag_slop_sq` and `_tap_slop_sq` once. The slops are fixed for the battle (a slop setter is reserved for Settings, Alpha).
- **Builder step 2** (ADR-0001) calls `InputResolver.create(record.drag_slop, record.tap_slop, dev_error)` with the battle's injected `dev_error`; on null it calls `fatal("input record: invalid slops")` and returns null; otherwise it stores the result as **`Battle.resolver: InputResolver`**, a read-only member like `input_record`. This names ADR-0003's placeholder and is ADR-0006's emitter key `&"resolver"`.
- **Reports.** Every non-fatal breach calls `_report(msg)`: `dev_error.call(msg)` when `dev_error.is_valid()`, else `push_error(msg)`. ADR-0001's default sink always calls `push_error`, so "dropped with `push_error`" holds in every build; tests pass a recording fake and assert the report.
- `InputResolver.new(` appears only in `create` and in test fakes.
- **Lifetime.** `Battle` holds the only strong reference outside the wrapper. The wrapper passes `battle.resolver` to the adapter, HeroInput, TowerInput, HudLogic and `GestureLog`, connects G1 to G8 in `_connect_signals()` (ADR-0006 Decision 2), and each node drops the reference in `detach()`. Retry builds a new resolver; nothing is reset. The weakref proof includes it (ADR-0001 Validation 3).

### 3. Positions: `Vector2` at the API, `float` scalars inside (QQ-05)

- **API.** Every position parameter and payload is `Vector2` in 540x960 field units, as ADR-0003 (`resolver_drive`) and ADR-0006 (G1 to G8) fixed and the registry's `sim_position_representation` allows (adapter input, view-signal payloads).
- **Inside.** The resolver never calls a `Vector2` method or operator. It reads `.x` and `.y` into `float` locals (64-bit), compares `dx * dx + dy * dy` with `r * r` or a slop squared in `float`, and stores geometry as `float` pairs. This follows ADR-0004's float policy, although the resolver is input code, because its decisions choose which command runs and the equivalence test compares bit for bit.
- **Why this is exact enough.** A 32-bit component (expected, V2) widens to 64 bits exactly; differences, squares and sums of field-sized values then round at most once in 64 bits. For the integer positions the GDD criteria use, every result is exact, so the boundary cases of criteria 30 and 31 (1296 against 1296, 225 against 225) compare exactly. Adapter-converted positions are fractional and sit on no boundary (Input Formulas).
- **Pass-through.** Every payload position is a value the resolver received: `p` and `release_pos` are the call's argument, `press_pos` is the press argument kept as a `Vector2` copy beside its scalars. The resolver adds no rounding to a position an owner then passes to a command; owners convert to scalars on entry to commands (ADR-0009 Decision 2).

### 4. The hit-target registry

```gdscript
class Target extends RefCounted:
    var id: int
    var cx: float
    var cy: float
    var radius: float
    var accepts: int        # Accepts.TAP or Accepts.DRAG, checked at register
    var priority: int
    var enabled: bool
    var sink: bool

var _targets: Array[Target] = []   # ascending id; append on register, remove_at on unregister
var _next_id: int = 1              # never reset, never reused
const MIN_SUPPORTED_WIDTH_DP := 360   # equals FieldMapping.MIN_FIELD_WIDTH_DP (unit-tested)
```

- **No owner reference.** A row holds values only: never an owner, node, Callable or object. The owner keeps the `int` id. The registry therefore cannot form a cycle with any owner, and a freed owner leaves only an id nobody uses.
- **Calls**, all immediate, legal in any state and inside handlers, never queued:

| Call | Rejected when | On rejection |
|---|---|---|
| `register(centre, radius, accepts, priority, sink = false) -> int` | `centre` non-finite; `radius` non-finite or `<= 0`; `accepts` not `TAP` or `DRAG` (V4); `sink` with `DRAG` | returns `NONE`, adds nothing, `_report` |
| `unregister(id)` | unknown id | no-op, `_report` |
| `set_centre(id, centre)` | unknown id, or `centre` non-finite | no-op (old centre kept), `_report` |
| `set_enabled(id, enabled)` | unknown id | no-op, `_report` |

- A successful `register` appends a row with `id = _next_id`, increments the counter and returns the id. `unregister` removes with an index loop and `remove_at` (registry `remove_during_foreach`).
- **Effective at once** means the next hit test sees the change. Hit tests run only at a press (Decision 5), so a change made inside a handler affects the next press, never the gesture in flight (Input criteria 6, 26, 27).
- **48 dp guard.** `register` also calls `target_ok(radius, MIN_SUPPORTED_WIDTH_DP)` (Decision 10) and, when false, calls `_report` but still registers. The constant is local, so the pure class names no ADR-0003 class; a unit test asserts it equals `FieldMapping.MIN_FIELD_WIDTH_DP`. No MVP radius is below 36, so the report means an owner bug.
- No `Dictionary`: no result can depend on iteration order (registry `unordered_iteration_in_sim`). Duplicates are the owner's bug (Input Edge Cases).

### 5. Press: winners, frozen discs and the press's slop

A press that starts a gesture scans `_targets` once in id order. A row is a **candidate** when `enabled` and `inside`: `dx*dx + dy*dy <= radius*radius`. Per class it keeps the best candidate: higher `priority`, then smaller squared distance, then lower id. Since the scan runs in ascending id, a later row replaces the current best only on a higher priority, or an equal one with a strictly smaller squared distance.

It then freezes, in scalar fields: the tap winner's id, centre, radius and sink flag (or `NONE`); the drag winner's id, centre and radius (or `NONE`); the press point as scalars and as the press `Vector2`; the active pointer; and `_slop_sq`, which is `_tap_slop_sq` if the press has a **real tap winner** (a tap winner that is not a sink) or no winner at all, else `_drag_slop_sq` (Input Rule 3, is_drag formula). Nothing later reads the registry for this gesture: a release tests the frozen tap disc with no `enabled` term, and a target unregistered, disabled or moved mid-gesture still receives the gesture's signals under its old id.

### 6. The state machine

`enum State { IDLE, PRESSED, DRAGGING, DEAD }`; `state()` returns it. The branches restate the GDD's transition table; the GDD stays the source and its criteria are the test.

**`press(i, p)`**
1. `IDLE`: begin a gesture (Decision 5), commit `PRESSED`, emit `pressed(best_tap, best_drag, p)`.
2. `i` is the active pointer (lost release): end the gesture as a cancel (outcome `REPRESSED`), then begin as in 1.
3. The gesture is **replaceable** (state `PRESSED` or `DEAD`, and no real tap winner): end it as a cancel (outcome `REPLACED`), then begin with `i` active. `DRAGGING`, or any real tap winner, is never replaceable (Input Rule 1).
4. Otherwise dropped.

**`move(i, p)`**: dropped in `IDLE` or for another pointer. Otherwise update the gesture record's travel, then: in `PRESSED`, if `crossed` (squared distance from the press point `>= _slop_sq`) with a drag winner, commit `DRAGGING` and emit `drag_started(drag, press_pos, p)` only; crossed with no drag winner, commit `DEAD`; in `DRAGGING`, emit `drag_moved(drag, press_pos, p)`, one per call; in `DEAD`, nothing.

**`release(i, p)`**: dropped in `IDLE` or for another pointer. Otherwise decide the batch, capture its arguments in locals, commit `IDLE` (clear the active pointer and frozen fields, finalise the record), then emit:

| State | Condition | Batch |
|---|---|---|
| `PRESSED` | crossed, drag winner (lost moves) | `drag_started(drag, press_pos, p)`, `drag_ended(drag, press_pos, p)`, `became_idle()` |
| `PRESSED` | crossed, no drag winner | `became_idle()` |
| `PRESSED` | under slop, tap winner (sink included), `p` inside its frozen disc | `tapped(tap, p)`, `became_idle()` |
| `PRESSED` | under slop, tap winner, `p` outside the frozen disc | `became_idle()` |
| `PRESSED` | under slop, no winner at all | `ground_tapped(p)`, `became_idle()` |
| `PRESSED` | under slop, only a drag winner | `became_idle()` |
| `DRAGGING` | any | `drag_ended(drag, press_pos, p)`, `became_idle()` |
| `DEAD` | any | `became_idle()` |

**`cancel()`**, and **`cancel_pointer(i)`** for the active pointer: outside `IDLE`, end the gesture as a cancel (outcome `CANCELLED`); otherwise nothing.

**End as a cancel**: capture whether it was `DRAGGING` and its drag winner, commit `IDLE`, finalise the record, then emit `drag_cancelled(drag)` if it was dragging, then `became_idle()`. No release is ever synthesised, and no cancel, replacement or re-press emits `ground_tapped`.

**Cancel-then-press is two steps in one call.** In rows 2 and 3 the cancel step commits and emits its batch; then the press step hit-tests the registry as it stands, commits and emits `pressed`. The cancel signals carry arguments captured before the new press commits (GDD transition note), and a registry change a listener makes on that `became_idle` reaches the new press. Calls queued during either step run after both. Input criterion 5's log is the same under either reading (Decision 11, choice 3).

### 7. Commit before emit, and the FIFO queue

```gdscript
const MAX_CALLS_PER_DRAIN := 64
var _q_kind := PackedInt64Array()      # PRESS, MOVE, RELEASE, CANCEL_POINTER, CANCEL
var _q_pointer := PackedInt64Array()
var _q_pos := PackedVector2Array()     # Vector2.ZERO for the two cancels
var _draining := false
var _aborting := false

func press(pointer: int, pos: Vector2) -> void:
    if not (is_finite(pos.x) and is_finite(pos.y)):
        _report("InputResolver.press: non-finite position")
        return
    _enqueue(_PRESS, pointer, pos)

func _enqueue(kind: int, pointer: int, pos: Vector2) -> void:
    var _hold: InputResolver = self     # E1 guard: keeps this object alive until return (V1 d)
    if _aborting:
        return                          # calls made while an abort ends the gesture are discarded
    _q_kind.append(kind)
    _q_pointer.append(pointer)
    _q_pos.append(pos)
    if _draining:
        return                          # a handler's call: runs after the current batch
    _draining = true
    var i := 0
    while i < _q_kind.size():           # size re-read: handlers append during the loop (V1 b)
        if i == MAX_CALLS_PER_DRAIN:
            _abort_drain()
            break
        _run(_q_kind[i], _q_pointer[i], _q_pos[i])
        i += 1
    _q_kind.clear()
    _q_pointer.clear()
    _q_pos.clear()
    _draining = false
```

- **A batch** is every signal one call emits, `became_idle()` included; both steps of a cancel-then-press belong to that call. `_run` commits first, with all arguments in locals, then emits with `signal.emit(...)`. Godot delivers each emit to every listener before `emit()` returns (V1 a), so when `_run` returns its whole batch has reached every listener.
- **A nested call** (any gesture call while `_draining` is true) appends and returns; it runs after the current call's batch, in arrival order. This gives the GDD's logs: a `cancel()` from a `pressed` handler lets every listener hear `pressed` before any hears `became_idle`; a `press` from a `tapped` handler starts after that gesture's `became_idle` (Input criterion 27).
- **Registry calls are never queued**, so `register` inside `tapped` returns a valid id at once.
- **Non-finite positions** are dropped before the queue, with `_report`. The two cancels take no position.
- **Cancels outside a drain run at once**: the adapter's `cancel_all()` from a loss notification, and Flow's `cancel_input()` inside a tick. G7 and G8 then fire inside that callback, as ADR-0006 allows for those two only. A `cancel()` arriving during a drain (a gesture listener's command reaching a fatal) is queued behind the current batch.
- **Runaway guard.** Reaching `MAX_CALLS_PER_DRAIN` calls in one drain is a defect (for example a listener that presses on every `pressed`). `_abort_drain()` sets `_aborting = true`, calls `_report`, ends any live gesture as a cancel (its listeners' gesture calls are discarded by the `_aborting` check, so no nested drain can start), then sets `_aborting = false`; `_enqueue` clears the queue after the loop. Legal flows stay far below the cap: one finger gives a few calls per frame, and a handler adds one or two.
- **Teardown during a drain.** ADR-0001 Decision 7 forbids freeing the wrapper or dropping the battle inside a signal handler or a fatal call: only `AppRoot._process` tears down, so no listener can drop the last reference mid-drain. The `_hold` local guards the remaining case where a defect does (V1 d).
- **A stuck flag.** A script error inside `_run` aborts `_enqueue` in a debug run with `_draining` still true (engine check; V1 e), and ADR-0004 V4 records release unwinding. Branch decided now: `InputAdapter.flush()`, which is never nested (frame step 0, top of `_process`), first calls `resolver.recover_if_stuck() -> bool`. If `_draining` is true there, the resolver calls `_report`, clears the queue and both flags, ends any live gesture as a cancel (emitting normally, with `_draining` set during it), and returns true. In tests the original error already fails the test; in play the next frame recovers. This adds one adapter line (cascade, ADR-0003 Decision 2).
- **Allocation.** Packed-array `clear()` may free storage, so a drain may reallocate three small arrays: negligible at this call rate.
- The queue is per resolver and is dropped with the battle (registry `mutable_static_var`).

### 8. Signals, the gesture record and the development log

**Signals** are ADR-0006 Decision 5 (G1 to G8), copied exactly (Key Interfaces), each with a `##` comment naming its id, emitted with `name.emit(...)`.

| Signal | Emitted by | Outside `flush()`? |
|---|---|---|
| `pressed` | a press that begins a gesture (Decision 6, rows 1 to 3) | no |
| `tapped`, `ground_tapped` | `release` in `PRESSED` under slop (Decision 6 table) | no |
| `drag_started`, `drag_moved`, `drag_ended` | crossing `move`, `move` while `DRAGGING`, `release` (Decision 6) | no |
| `drag_cancelled` | end as a cancel while `DRAGGING` | **yes** (cancel inside a tick or an engine callback) |
| `became_idle` | last signal of every exit to `IDLE`, exactly once per gesture | **yes**, with the signal before it |

- G1 to G6 fire only inside a drain that `flush()` started, or in a test; that is what lets their listeners issue commands (ADR-0006 rule 3). It holds because no production code but the adapter calls `press`, `move` or `release`, and a G7 or G8 listener must never call a gesture call.
- **`pressed` carries both frozen winners** (TR-hud-009), so an owner can decide at press for the whole gesture (Battle HUD Rule 10, Tower Rule 8).
- A listener disconnected during an emit may still receive that emit (V1 c), so an owner must ignore a signal that arrives after its `detach()`.

**`GestureRecord`** (`src/foundation/input/gesture_record.gd`, `class_name GestureRecord extends RefCounted`, no signal, references no other script) holds values only: `serial` (from 1), `pointer`, `press_pos`, `end_pos` (release argument; on a cancel the last move, or `press_pos`), `moves`, `max_travel` (`sqrt` of the largest squared distance from the press point over every move and the release), `best_tap`, `best_drag`, `tap_sink`, `tap_centre`, `drag_centre` (frozen; `Vector2.ZERO` if absent), `tap_candidates`, `drag_candidates`, `tap_rule` and `drag_rule` (`WinRule`: `NO_CANDIDATE`, `ONLY`, `PRIORITY`, `DISTANCE`, `ID`, the comparison that last decided the winner), `slop`, and `outcome` (`Outcome`: `OPEN`, `TAPPED`, `GROUND_TAPPED`, `ROLLED_OFF`, `DRAG_WINNER_ONLY`, `DRAGGED`, `DRAGGED_LOST_MOVES`, `DEAD`, `CANCELLED`, `REPLACED`, `REPRESSED`).

The resolver fills it at press, updates travel and `moves` per call, and finalises `outcome` and `end_pos` in the commit step, before the ending batch, so a `became_idle` listener reads the finished gesture. The record is kept in every build (a few field writes per call; no build check in a pure class). **`last_gesture() -> GestureRecord` returns null before the first gesture**, and otherwise a new copy of the current or last record (`outcome == OPEN` while live), so no caller can keep or change the resolver's own.

**`GestureLog`** (`src/presentation/dev/gesture_log.gd`, `extends Node`) is the Rule 13 harness. Binding parts:

- Created by `BattleWrapper.attach` only when `OS.is_debug_build()` is true (V7); release builds never create it and never write. It is a view listener under ADR-0006 rule 2: reads only, no command, no sim write.
- `attach(resolver, adapter, sink: Callable, chip_open: Callable = Callable())`. The wrapper connects `resolver.pressed`, `resolver.became_idle` and `tower_sim.tower_upgraded` (ADR-0006 P5 already names the gesture log) to its handlers in `_connect_signals()`, undone in `detach()`. `chip_open` is a method Callable that ADR-0010 wires once it decides who owns the chip read; until then it is invalid and the field is written as null.
- **Timing**: the resolver stays clock-free. `GestureLog` stamps `Time.get_ticks_msec()` (sourced: ADR-0004 V8) in its `pressed` and `became_idle` handlers. Both run inside `flush()`, so times are frame-quantised, enough for the Pillar 4 test. `GestureLog` is neither sim code nor a real-time model, so `engine_time_in_sim` does not cover it; its lint excludes `src/presentation/dev/` (cascade).
- Device label from `OS.get_model_name()` (V7); insets and width from `adapter.field_insets()` and `adapter.field_width_dp()` (ADR-0003).
- Output goes through the injected `sink` (`write_line(text: String) -> bool`). Records hold no `Vector2`: positions are written as separate `x` and `y` fields, serialised with `JSON.stringify(record, "", true, true)` (sorted keys, full precision; as ADR-0002 uses it). A write failure is reported once through `dev_error`, never fatal. Any file sink must append correctly (V8): open `READ_WRITE` when the file exists, else `WRITE`, then `seek_end()`; keep one handle; `flush()` after each line, because Android can kill the app; check the `bool` every `store_*` returns.
- The prompter, the press-offset rule, the record's JSON field list and the interim file are the Pillar 4 harness story's, within these rules.

### 9. What owners get (non-binding restatement)

The resolver decides no meaning. This section restates, without deciding, how the GDDs use the guaranteed calls; the GDD rules and ADR-0010 are the source, and no number here binds.

- **TowerInput** (Tower Rule 8, Interactions; Battle HUD Rule 9): registers slots, towers and the chip; disables a built slot with `set_enabled`; unregisters the chip on close; closes it on `phase_changed` (ADR-0006 P1), because `cancel()` in Idle emits nothing; ignores taps while the battle is halted.
- **HeroInput** (Hero Rules 13 and 15, Interactions): registers the hero, the burst button and its sink; calls `set_centre` for the hero in `update()` at frame step 4 (ADR-0004 Decision 5), outside any drain, so the next `flush()` tests presses against the drawn hero; tests the cancel hysteresis itself on the unchanged positions of `drag_started`, `drag_moved` and `drag_ended`.
- **HudLogic** (Battle HUD Rules 6 to 8, 10, 11, 14): registers the arc backdrop and discs inside its `slot_tapped` handler, which runs inside the resolver's `tapped` batch, so they compete from the next press; disables and re-enables Start/Call with `set_enabled`; unregisters on every arc close; decides closing from `pressed`, `drag_started` and `phase_changed`.
- Owners keep ids as `int` fields and compare them with `==`; `NONE` is never a live id; an owner ignores signals naming an id it dropped.

**Open items for ADR-0010** (this ADR decides none of them):
1. Who owns `chip_state()`: Tower GDD Rule 17 puts it on TowerInput, `architecture.md` B10 on TowerSim. ADR-0010 resolves the conflict and wires `GestureLog`'s `chip_open`.
2. `halted()` injection into TowerInput: Tower's "ignores taps while halted" (TR-tower-011) needs it, but B9 injects `halted()` only into EnemyWave, TowerSim, HeroSim and HudLogic.
3. Scalar conversion of gesture positions in HeroInput and TowerInput command calls (ADR-0009 Decision 2 already requires it).

### 10. Formulas in code

- `inside` and the tie-break: Decision 5. `is_drag` and `is_dead`: Decision 6.
- **`target_ok`**, static and pure so Input criterion 33 tests the production function:

```gdscript
## True when a disc of this radius is at least 48 dp across at this field width.
## Integers only: radius and width floored first, compared without division (Input Formulas).
static func target_ok(radius: float, width_dp: float) -> bool:
    if not (is_finite(radius) and is_finite(width_dp)):
        return false
    return 2 * floori(radius) * floori(width_dp) >= 25920   # 48 * 540
```

`target_ok(36.0, 360.0)` and `target_ok(48.0, 360.0)` are true, `target_ok(35.0, 360.0)` false. The runtime width check stays ADR-0003's `FieldMapping.width_supported`; at radius 36 the two agree. `field_scale` is ADR-0003's.

### 11. Choices made in autonomous mode

Each can be overturned (Status, step 4; cascade section d):

1. `Battle.resolver` as a read-only member, not a `resolver()` method (Decision 2).
2. An optional third `create` and `_init` argument `dev_error`, falling back to `push_error` (Decision 2).
3. Cancel-then-press as two steps, the new press hit-testing after the cancel batch (Decision 6).
4. A cap of 64 calls per drain, with abort discarding calls made while it ends the gesture (Decision 7).
5. `register` reports, but accepts, a radius that fails `target_ok` at 360 dp (Decision 4).
6. `GestureRecord` kept in every build; `GestureLog` stamps `Time.get_ticks_msec()` rather than a frame-fed `advance(ms)` (Decision 8).
7. Until ADR-0010 provides the run-log sink, the harness story uses its own JSONL file sink under V8's rules; ADR-0010 may merge both logs into one file (Decision 8).

### Architecture Diagram

```
 InputAdapter (ADR-0003)                      BattleBuilder step 2 (ADR-0001)
   flush() at frame step 0:                     InputResolver.create(drag_slop, tap_slop, dev_error)
     recover_if_stuck(), then queued calls      null -> fatal ; else Battle.resolver
   cancel_all() -> resolver.cancel()
        | press / move / release / cancel_pointer / cancel (Vector2, field units)
        v
 +--------------------------- InputResolver (RefCounted, pure) ---------------------------+
 | entry: is_finite check -> FIFO queue -> drain unless draining (or aborting: discard)   |
 | _run(call): decide -> COMMIT (state, frozen scalars, GestureRecord) -> EMIT batch      |
 | IDLE -press-> PRESSED -move>=slop-> DRAGGING (drag winner) | DEAD (none)              |
 | any -release / cancel / re-press / replacement-> IDLE, became_idle last               |
 | Registry: Array[Target] by id, values only; 4 calls immediate, never queued           |
 +-----+--------------------------------+-------------------------------------------------+
       | G1 to G6 (inside flush only)    | G7, G8 (also inside a tick or engine callback)
       v                                 v
 HeroInput, TowerInput, HudLogic (wrapper connections, flags 0); set_centre(hero) at step 4
 GestureLog (debug builds): pressed, became_idle, tower_upgraded -> last_gesture() copy -> sink
```

### Key Interfaces

```gdscript
# src/foundation/input/input_resolver.gd
class_name InputResolver extends RefCounted
## Pure gesture resolver: one active pointer, disc targets, four states. No clock, no scene.

enum Accepts { TAP, DRAG }
enum State { IDLE, PRESSED, DRAGGING, DEAD }
const NONE := -1
const MAX_CALLS_PER_DRAIN := 64
const MIN_SUPPORTED_WIDTH_DP := 360

signal pressed(best_tap: int, best_drag: int, p: Vector2)                    # G1
signal tapped(best_tap: int, p: Vector2)                                     # G2
signal ground_tapped(p: Vector2)                                             # G3
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)          # G4
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)            # G5
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)  # G6
signal drag_cancelled(best_drag: int)                                        # G7
signal became_idle()                                                         # G8

static func validate(drag_slop: float, tap_slop: float) -> bool
static func create(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> InputResolver
static func target_ok(radius: float, width_dp: float) -> bool
func _init(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> void

## Gesture calls: InputAdapter only (cancel also wrapper detach), and tests. Queued.
func press(pointer: int, pos: Vector2) -> void
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
func cancel() -> void
func recover_if_stuck() -> bool             # InputAdapter.flush() only, first, never nested

## Registry: legal in any state and inside handlers; effective at the next press; never queued.
func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void

## Read-only queries.
func state() -> State
func centre_of(id: int) -> Vector2          # Vector2(NAN, NAN) for an unknown id; logs and tests only
func last_gesture() -> GestureRecord        # null before the first gesture; else a new copy

# src/foundation/input/gesture_record.gd
class_name GestureRecord extends RefCounted
enum WinRule { NO_CANDIDATE, ONLY, PRIORITY, DISTANCE, ID }
enum Outcome { OPEN, TAPPED, GROUND_TAPPED, ROLLED_OFF, DRAG_WINNER_ONLY, DRAGGED,
               DRAGGED_LOST_MOVES, DEAD, CANCELLED, REPLACED, REPRESSED }
# fields as Decision 8; func copy() -> GestureRecord

# src/root/battle.gd (addition)
var resolver: InputResolver                 # read-only by contract; set by BattleBuilder step 2

# src/presentation/dev/gesture_log.gd (debug builds only)
class_name GestureLog extends Node
func attach(resolver: InputResolver, adapter: InputAdapter, sink: Callable, chip_open: Callable = Callable()) -> void
func detach() -> void
```

Names are provisional until ADR-0007 settles `class_name` collisions (QQ-16). ADR-0007 also excludes `tests/` from export presets, since a test `class_name FakeResolver` registers globally.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- `InputResolver` must extend `RefCounted`; must never read a node, the scene tree, a viewport, `DisplayServer`, `Input`, `Engine`, `Time`, `OS`, a timer or `await`; must reference no project class but `GestureRecord`.
- Production code must create it only with `InputResolver.create(...)` in `BattleBuilder.build` step 2, and must call `fatal` and return null on null. `InputResolver.new(` only in `input_resolver.gd` and `tests/`; fakes are built with `FakeResolver.new(...)`, never `create`.
- Only `InputAdapter.flush()` may call `press`, `move`, `release`, `cancel_pointer` and `recover_if_stuck` in production; `cancel()` only from `cancel_all()` and the wrapper's `detach()`. A `drag_cancelled` or `became_idle` listener must never call a gesture call or a command.
- A `Target` row must hold values only; owners hold `int` ids and clear them, and the resolver reference, in `detach()`.
- The registry must be an `Array[Target]` in ascending id order, never a `Dictionary`; ids from a counter starting at 1, never reset or reused.
- Registry calls must take effect at once and never be queued; gesture calls must always go through the queue.
- Every gesture call must commit state, frozen fields and the gesture record before its first `emit()`, with arguments in locals; `became_idle` must be last and emitted exactly once per gesture.
- Must never call a `Vector2` method or operator in a decision; must compare squared distances in `float` from `.x` and `.y`; must pass received `Vector2` values to payloads unchanged.
- Must drop a non-finite position with `_report` before it changes or queues anything; `register` must return `NONE` for every case in Decision 4's table.
- Non-fatal breaches must go through `dev_error` (falling back to `push_error`), never `assert` or `print`.
- Signals must be ADR-0006's eight, emitted with `name.emit(...)`, connected only by the wrapper with flags 0.
- No `static var` in `InputResolver` or `GestureRecord`.
- `last_gesture()` must return null before the first gesture and a new copy after; no caller may keep a record past its handler.
- `GestureLog` must exist only when `OS.is_debug_build()` is true; must never issue a command or write sim state; must write no `Vector2` (separate `x`, `y`); must report a sink failure once through `dev_error`, never as fatal; a file sink must follow V8's append rules.
- Owners must tolerate one signal arriving after their `detach()`.
- Test fakes extending `InputResolver` must give every typed override an explicit `return` (4.7) and forward `_init` arguments to `super(...)`.

## Alternatives Considered

### Alternative 1: Engine picking (`Area2D` input or `Control` targets)
- **Description**: Each target is an `Area2D` or a `Control`; the engine picks what was hit.
- **Pros**: No hit-test code; shapes edited in scenes.
- **Cons**: Needs a scene, so no headless tests or equivalence test; priority and freezing spread over callbacks; 4.7 picking and touch are unsourced (HIGH); ADR-0003 made non-modal Controls `MOUSE_FILTER_IGNORE`.
- **Estimated Effort**: Lower to write, much higher to test and verify.
- **Rejection Reason**: Breaks TR-input-001 and the GDD's test method.

### Alternative 2: Deferred emission instead of a queue
- **Description**: `call_deferred` or `CONNECT_DEFERRED`, so nested calls run later.
- **Pros**: No queue code.
- **Cons**: ADR-0006 forbids deferred connections; deferred work runs after frame step 0, so gesture commands would follow the ticks (TR-hud-005); cross-call order becomes engine-defined.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Contradicts ADR-0006 Decision 2 and ADR-0004 Decision 5.

### Alternative 3: Immediate re-entry (no queue)
- **Description**: A nested call runs inside the listener that made it.
- **Pros**: Simplest.
- **Cons**: Later listeners hear `became_idle` before `pressed` (Input criterion 27); state changes mid-batch.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Violates TR-input-010.

### Alternative 4: Registry rows that hold their owners
- **Description**: `register(owner, ...)`; the resolver calls `owner.on_tap(...)`.
- **Pros**: No id bookkeeping in owners.
- **Cons**: A strong reference from the resolver to wrapper nodes (ADR-0001 teardown); a second delivery path outside ADR-0006's listener-count test; feature-shaped interfaces in a Foundation class.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Cycle and contract risk; ADR-0006 fixed signals as the path.

### Alternative 5: `Vector2` maths inside
- **Description**: `Vector2` centres and `distance_squared_to`.
- **Pros**: Shorter.
- **Cons**: 32-bit arithmetic if V2 holds, against ADR-0004's float policy and ADR-0009's reasoning.
- **Estimated Effort**: Slightly lower.
- **Rejection Reason**: The scalar form costs a few lines and removes the question.

### Alternative 6: `float` pairs in the public API
- **Description**: `press(pointer, x, y)` and scalar payloads.
- **Pros**: No `Vector2` in input.
- **Cons**: Changes signatures ADR-0003, ADR-0006 and the registry fixed; gains nothing, since positions pass through unchanged.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Contradicts registered stances for no gain.

### Alternative 7: A clock in the resolver for the log
- **Description**: The resolver stamps press and release times.
- **Pros**: Hold time in one place.
- **Cons**: Breaks Rule 13 and TR-input-001; time-dependent tests.
- **Estimated Effort**: Lower.
- **Rejection Reason**: The development node can stamp instead.

### Alternative 8: One batch for cancel-then-press
- **Description**: Commit cancel and press, then emit `drag_cancelled`, `became_idle`, `pressed` together.
- **Pros**: One commit point per call.
- **Cons**: A registry change on that `became_idle` would miss the new press; the new gesture is live while listeners still handle the old one's end.
- **Estimated Effort**: Same.
- **Rejection Reason**: Two steps keep "commit, then emit" per step (Decision 11, choice 3).

### Alternative 9: Reset the stuck flag at `_enqueue` entry
- **Description**: `_enqueue` clears `_draining` when it finds the queue empty.
- **Pros**: No adapter change.
- **Cons**: An empty queue with `_draining` true is also the legal state while an abort or the last call of a drain emits; resetting there starts a nested drain and breaks re-entrancy (TD-ADR T3).
- **Estimated Effort**: Same.
- **Rejection Reason**: `recover_if_stuck()` at the one point known not to be nested is safe.

## Consequences

### Positive
- Every GDD criterion runs headless against the real class with a recording fake and integer positions.
- No reference from the resolver to any owner: retry frees it with the battle; the weakref proof covers it.
- One queue gives one testable rule for nested calls; registry calls stay immediate, so the HUD's arc works as designed.
- The resolver adds no rounding to positions, so the equivalence test compares like with like.
- The gesture log gets every Rule 13 field with no clock or build flag in the resolver.

### Negative
- Owners keep and compare ids and ignore signals for ids they dropped, or that arrive after `detach()`.
- Queue, cap, abort flag and `recover_if_stuck()` add code to a small class and one line to the adapter.
- New names (`Battle.resolver`, the `dev_error` argument, `state()`, `centre_of()`, `last_gesture()`, `recover_if_stuck()`, `GestureRecord`, `GestureLog`, `target_ok()`) must reach other documents (cascade).
- The `engine_time_in_sim` lint must exclude `src/presentation/dev/`.

### Neutral
- The gesture record is kept in release builds (a few field writes per call).
- Positions stay `Vector2` at the API.

## Risks
- **`emit()` not synchronous, or the call back fails (V1 a).** Batches could interleave. Mitigation: V1 runs before acceptance; its branch reopens this ADR and ADR-0006 together.
- **A script error leaves `_draining` true (V1 e, ADR-0004 V4).** Mitigation: `recover_if_stuck()` at the next `flush()`, reported through `dev_error`; the first resolver story tests it by forcing the flag.
- **Teardown mid-drain.** Mitigation: ADR-0001 Decision 7 forbids it; `_hold` covers a defect (V1 d).
- **The cap hides a real defect.** Mitigation: `_report` names it; a test watches it fire once.
- **Owners forget to unregister.** Mitigation: HUD and Tower wiring criteria check registry calls on a fake; `centre_of` lets tests assert absence.
- **Adapter `flush()` and `cancel_all()` interleave.** A gesture listener's command can reach `cancel_all()` (through a fatal's `cancel_input()`) while `flush()` iterates the adapter's queue. The resolver side is safe (the `cancel()` queues behind the batch); the adapter must tolerate its queue being emptied mid-`flush()`. Mitigation: cascade edit to ADR-0003 and an adapter unit test.
- **A late signal after `detach()` (V1 c).** Mitigation: owners ignore it (Implementation Guidelines).
- **The gesture log loses lines on Android.** Mitigation: `flush()` per line (V8).
- **Phone data moves the slops.** A data edit; `validate()` bounds stay.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-001: pure, scene-free, clock-free object driven only by the five gesture calls | Decision 1; Decision 7 (the five calls are the only gesture inputs) |
| input-gesture-resolver.md | TR-input-007: disc registry with four calls legal in any state, applied at once | Decision 4 (value rows, never-reused ids, immediate calls, no owner reference); Decision 5 |
| input-gesture-resolver.md | TR-input-008: four states, one pointer, winners frozen at press, per-press slop | Decisions 5 and 6 |
| input-gesture-resolver.md | TR-input-009: the signal API; every exit to Idle emits the idle signal last | Decision 8 (ADR-0006's names; `became_idle` last and once) |
| input-gesture-resolver.md | TR-input-010: commit before emit; nested calls queue FIFO, drained in the outermost call | Decision 7 (queue, batch, abort, recovery); Decision 6 (two-step cancel-then-press) |
| input-gesture-resolver.md | TR-input-011: static `validate()`, `create()` returning null; non-finite positions dropped with `push_error` | Decision 2; Decisions 4 and 7 (`dev_error`, falling back to `push_error`) |
| input-gesture-resolver.md | TR-input-015: dev-build gesture log with device, insets, timing, travel, winners, classification | Decision 8 (`GestureRecord`, `GestureLog` wiring, timing, sink rules) |
| input-gesture-resolver.md | Formulas: inside, is_drag, tie-break, integer `target_ok` | Decisions 5, 6, 10 |
| tower-system.md | TR-tower-011: TowerInput registers slots and the chip, disables built slots, closes the chip on phase, ignores taps while halted | Decision 4 (calls legal in handlers); Decision 9 (restatement; `halted()` injection is ADR-0010 open item 2) |
| hero-system.md | TR-hero-010: HeroInput registers hero, button and sink discs, updates the walking hero's centre each frame, hit-tests cancel hysteresis | Decision 4 (`set_centre` immediate); Decision 9 (step 4, outside any drain); Decision 3 (positions unchanged for HeroInput's own test) |
| battle-hud.md | TR-hud-008: the arc registers and unregisters targets, disables Start/Call while open, closes on outcome, Paused or Fatal | Decision 4 (`register` inside `tapped` returns at once; `set_enabled`); Decision 8 (`cancel` emits only G7 and G8, so closing on `phase_changed` is the HUD's) |
| battle-hud.md | TR-hud-009: `pressed` exposes `best_tap` and `best_drag` | Decision 8 (`pressed(best_tap, best_drag, p)`, both frozen) |

## Performance Implications
- **CPU**: A press scans at most about 20 rows once; a move or release is a constant number of float operations and at most three emits; one finger gives one to three calls per frame. Inside the 0.5 ms input slice (registry `input-and-realtime-models`); unmeasured, like the slice.
- **Memory**: about 20 `Target` rows, three small packed queue arrays, one `GestureRecord`; `last_gesture()` allocates one copy per call (the log and tests only).
- **Load Time**: none.
- **Network**: none.

## Migration Plan

No code exists. Document edits are in the cascade notes, section a: `architecture.md` B0, B2, B4, B9, Module Ownership and Data Flow 9; ADR-0001 Builder step 2; ADR-0003 Decisions 1 and 2 and its guidelines; ADR-0006 Depends On; the registry note on `engine_time_in_sim`; the Input GDD's Rule 9, Rule 13 and criterion 36. The TR registry and traceability matrix are `/architecture-review`'s.

**Rollback plan**: The resolver is one class plus one value class. Changing the queue, the cap, the recovery or the cancel-then-press order touches `input_resolver.gd`, its tests and one adapter line; signals, registry API and `Battle.resolver` stay. Dropping `GestureLog` removes one development node and three wrapper connections.

## Validation Criteria

1. The Input GDD's 37 Logic criteria pass in `tests/unit/input_gesture_resolver/` with a recording fake that logs every argument and its type (ADR-0006, ADR-0007) and a recording `dev_error`; criteria 19 to 21 also assert the reports.
2. Added tests: a `register` in the `became_idle` handler of a cancel-then-press is a candidate for the new press; a listener that presses on every `pressed` stops at 64 calls with one report, state `IDLE`, and no nested drain; a forced `_draining` makes `recover_if_stuck()` return true once, report, and leave `IDLE`; a `cancel()` outside a drain emits at once; `last_gesture()` is null on a fresh resolver and a new, equal copy after; `MIN_SUPPORTED_WIDTH_DP == FieldMapping.MIN_FIELD_WIDTH_DP`.
3. `GestureRecord` fields for Input criteria 7, 8, 14, 16, 28, 32, 35 and 37 match hand-computed values.
4. ADR-0001's weakref proof reads null for the resolver after a battle with registered targets and connected fakes.
5. ADR-0006's headless test lists the eight resolver signals under `VIEW_ALLOWLIST` with no headless connection; the wrapper test finds listeners after `attach` and none after `detach`.
6. Hero criterion 27 (equivalence through the real resolver) gives identical per-tick state.
7. Lint (ADR-0007): no `Vector2` method or operator in `input_resolver.gd`; `InputResolver.new(` only in the resolver and tests; no `Dictionary` field in the resolver; no `emit_signal(`; `Time.*` allowed only under `src/presentation/dev/` among wrapper nodes.
8. Pillar 4 gate P1: the phone-test table computes from `GestureLog` output alone.

## Related
- Depends on: ADR-0003, ADR-0006. Binding: ADR-0001, ADR-0002, ADR-0004, ADR-0009.
- Enables: ADR-0007, ADR-0010 (open items in Decision 9), ADR-0011.
- Design: `design/gdd/input-gesture-resolver.md` (Core Rules 1 to 13, States and Transitions, Formulas, Edge Cases, Acceptance Criteria), `design/gdd/hero-system.md` (Rules 13, 15; criteria 15, 27), `design/gdd/tower-system.md` (Rules 8, 17), `design/gdd/battle-hud.md` (Rules 6 to 11, 14).
- Architecture: `docs/architecture/architecture.md` B2, B3, B9, B10, Data Flow 1, 3, 9.
- Code (once written): `src/foundation/input/input_resolver.gd`, `src/foundation/input/gesture_record.gd`, `src/presentation/dev/gesture_log.gd`, `tests/unit/input_gesture_resolver/`.
