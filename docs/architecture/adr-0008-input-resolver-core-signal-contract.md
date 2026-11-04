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
> 2. V1 to V8 have recorded results in `docs/engine-reference/godot/current-best-practices.md`
>    with the engine version. V2 and V3 count once ADR-0009 V1 and V3 are recorded; V1 shares one
>    script with ADR-0006 V4 and V5. A result that takes a branch revises this ADR first. V7 and V8
>    need a desktop result; their phone results come at the first phone build.
> 3. The cascade edits (section a) are applied, or the user overturns them one by one.
> 4. The user has confirmed or overturned each of the seven choices in Decision 11.
>
> **After acceptance:** the Input GDD's 37 Logic criteria become the resolver's unit tests. Reopen
> trigger: any Validation Criterion that cannot pass as written, or a phone-test log (Pillar 4 gate
> P1) showing a mis-fire the resolver caused, amends this ADR before the next input story closes.

## Date

2026-11-04

## Last Verified

2026-11-04, against the pinned engine reference only (Godot 4.7.2); `docs.godotengine.org` was not reachable. The resolver is plain GDScript with no engine call in its decision path; each engine behaviour it relies on that the reference does not cover is a verification item, not a fact.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS on the first draft, findings T1 to T9 applied in this revision), godot-specialist (engine check: blocking findings E1 and E2 and the minor notes applied). Authored with the /architecture-decision flow in autonomous mode.

## Summary

The Input & Gesture Resolver turns one pointer's press, moves and release into exactly one tap, one drag or nothing for one registered disc; its GDD fixes the rules but not how a pure object meets them under re-entrant handlers, frozen winners and a development gesture log. This ADR decides an `InputResolver extends RefCounted` built by `BattleBuilder` through `create(drag_slop, tap_slop, dev_error)` and held as `Battle.resolver`; a value-only registry keyed by never-reused `int` ids; a four-state machine with winners frozen as scalars at press; one FIFO call queue drained by the outermost call, each call committing and then emitting its whole batch; `Vector2` only at the API with 64-bit scalar maths inside; ADR-0006's signals exactly; and a `GestureRecord` that a development-only `GestureLog` writes out for the Pillar 4 phone test.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM. No engine input API is used (ADR-0003's adapter holds those HIGH facts). What remains is GDScript behaviour: synchronous delivery with a call back into the emitter, object lifetime during a member call, `Vector2` width, `is_finite`, enum arguments, `Callable()` defaults, inner classes; and, for the development log, `OS` and `FileAccess`. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md` (no touch coverage; nothing applies). ADR-0001, 0003, 0004, 0006, 0009; `docs/registry/architecture.yaml`. |
| **Post-Cutoff APIs Used** | None. Pinned facts used: a typed-method override needs an explicit `return` (4.7), which binds test fakes; packed-array element writes skip a setter (4.7), irrelevant here; `FileAccess.store_*` returns `bool` (4.4). |
| **Verification Required** | V1 to V8. NOT SOURCEABLE in `docs/engine-reference/godot/**`: synchronous `emit()` with a call back into the emitter; lifetime of a `RefCounted` during its own member call; a callee's script error and its caller; disconnect during `emit()`; `Vector2` width; `is_finite`; out-of-range enum arguments; `Callable()` defaults; inner classes as `Array` element types; `OS.get_model_name()`, `OS.is_debug_build()`; `FileAccess` open modes and `seek_end`. |

### Verification items

Owner: godot-specialist writes the scripts; the user runs them headless on 4.7.2 (`godot --headless -s <script>`, outside `src/`); results go into `current-best-practices.md`. "Expected" is not a source.

- **V1. Delivery, re-entry, lifetime** (one script with ADR-0006 V4 and V5, `prototypes/adr-0006-signal-check/`, extended). (a) Listener A of `s` calls `emitter.poke(1)`, listener B logs: does `s.emit(7)` run A then B before returning, with no error from the call back? (b) `while i < arr.size()` sees an element a listener appended mid-loop. (c) A listener disconnected during an emit still receives that emit? (d) A listener drops the emitter's last strong reference mid-emit: with `var _hold := self` in the emitting method, does it finish and free afterwards; without it, what happens? (e) A script error in a callee called from a loop: does the caller abort, leaving its flags set (debug run)? Expected: (a) to (d) yes; (e) aborts. **Decision 7 depends on (a), (b), (d).** Branch: if (a) fails, this ADR and ADR-0006 Decision 1 reopen together.
- **V2. `Vector2` width (QQ-05).** ADR-0009 V1, plus `Vector2(299.0, 500.0).x - 270.0 == 29.0`. No decision depends on it.
- **V3. Non-finite floats.** ADR-0009 V3, plus `is_finite(Vector2(NAN, 0.0).x)` and `is_finite(Vector2(INF, 0.0).x)` false.
- **V4. Out-of-range enum arguments** (`5`, `-1`, another enum's value) to an `Accepts` parameter. Expected: no runtime check, possibly `INT_AS_ENUM_WITHOUT_CAST` or `INT_AS_ENUM_WITHOUT_MATCH` warnings. No branch: `register` checks explicitly.
- **V5. `Callable()` defaults** on `create` and `_init` parse, and `Callable().is_valid()` is false. Branch: the argument becomes required everywhere.
- **V6. Inner classes and fakes.** An inner `class Target extends RefCounted` as the element type of `Array[Target]`; `remove_at` keeps order (ADR-0009 V2(e)); `create()` calling `InputResolver.new(a, b, c)`; a test `FakeResolver extends InputResolver` built with `FakeResolver.new(15.0, 28.0)`, `_init` forwarding `super(a, b)`, typed overrides with explicit `return`. `FakeResolver.create()` returns a plain `InputResolver` (statics are not virtual), so tests never call it. Branch: untyped `Array`; or ADR-0007 fakes wrap the resolver and owners type it `Object`.
- **V7. Development facts.** `OS.is_debug_build()` true in an editor run and a debug export (release: ADR-0001 V4); `OS.get_model_name()` non-empty. Branch: a tester-typed device label.
- **V8. File append.** `WRITE` truncates; `READ_WRITE` fails on a missing file; `seek_end()` then `store_string()` appends; `flush()` writes through; `store_*` returns `bool`. Branch: if `READ_WRITE` truncates, the sink rewrites from memory at each flush.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Proposed): only the adapter makes gesture calls, queued and delivered in `InputAdapter.flush()` at frame step 0; `cancel_all()` empties its queue and calls `resolver.cancel()`; `Vector2` field units (registry `resolver_drive`). ADR-0006 (Proposed): signal names, parameters and types, `int` ids with `NONE = -1`, G7 and G8 listeners never issue commands, wrapper connections with flags 0. Both must be Accepted first. Binding, not gating: ADR-0001 (Builder step 2, null is fatal; method Callables; no RefCounted cycle; no mutable `static var`; `dev_error`; Decision 7: only `AppRoot._process` tears down; weakref proof), ADR-0004 (frame order, float policy, V4), ADR-0009 (Decision 2, V1, V3), ADR-0002 (`InputRecord`). ADR-0005 is not used (TR-input-012). |
| **Enables** | ADR-0007 (resolver tests, fakes, lints), ADR-0010, ADR-0011 (views draw owners' state, never the resolver's). |
| **Blocks** | Input & Gesture Resolver stories; HeroInput, TowerInput and HudLogic stories that register targets or listen to gestures; the Pillar 4 harness story. |
| **Ordering Note** | ADR-0010 inherits only the resolver API (Key Interfaces), the registry calls and `GestureRecord`; owner behaviour (Decision 9) is the GDDs', and ADR-0010 decides the open items listed there. ADR-0006's GDD renames are applied, so tests use the new names. |

## Context

### Problem Statement

The Input GDD states the rules completely (13 rules, a transition table, edge cases, 37 Logic criteria as exact signal logs). Five questions remain. (1) Listeners call `press`, `cancel` or `register` from inside handlers (the HUD registers arc discs inside `tapped(slot)`; a bot presses from `tapped`), so a nested call needs one exact rule. (2) Owners register targets; the registry must not hold them, or retry leaks (ADR-0001). (3) ADR-0003 and ADR-0006 fix `Vector2` at the API, while ADR-0004 and ADR-0009 ban `Vector2` arithmetic on values that reach sim state, and the resolver chooses which command runs. (4) The gesture log (Rule 13) needs data no signal carries, and the resolver stays clock-free. (5) `Battle` has no resolver member (ADR-0003 used a placeholder), and the error path for a bad registration is unstated.

### Current State

No code. `architecture.md` B2 sketches the API with ADR-0006's names; ADR-0003 fixed the adapter queue; ADR-0001 put creation in Builder step 2; ADR-0004 put `HeroInput.update()` in frame step 4. The mouse prototype resolved presses inline, with no registry or queue.

### Constraints

- Godot 4.7.2, GDScript, one thread (TR-state-003); no engine input API in the resolver.
- ADR-0001: no autoload, no mutable `static var`, no cycle, method Callables only, `dev_error`, no `assert` for release checks, teardown only from `AppRoot._process`.
- ADR-0006: names and types fixed; G1 to G6 fire only from `flush()`; G7 and G8 may fire inside a tick or an engine callback.
- ADR-0004: commands between ticks only; no engine time in sim code or real-time models; float policy.
- Registry `sim_position_representation`: `Vector2` only for adapter input and view-signal payloads.

### Requirements

The eleven TRs in GDD Requirements Addressed, testable headless from the GDD criteria as written, inside the 0.5 ms input slice (ADR-0004 Decision 10).

## Decision

### 1. One pure class

`InputResolver` (`src/foundation/input/input_resolver.gd`, `class_name InputResolver extends RefCounted`). It reads no node, scene tree, viewport, display, `Input`, `Engine`, `Time`, `OS`, timer or `await`, overrides no engine callback, and references no project class but `GestureRecord`. Inputs: five gesture calls, four registry calls, two slops, a `dev_error` Callable. Outputs: eight signals, return values, three queries (`state()`, `centre_of(id)`, `last_gesture()`). It holds no reference to any battle object, owner or node.

In production only `InputAdapter.flush()` calls `press`, `move`, `release` and `cancel_pointer`; `cancel()` comes from the adapter's `cancel_all()` (lifecycle, resize, Flow's `cancel_input()`, ADR-0003 Decision 9) and the wrapper's `detach()`. Tests and the equivalence harness (Hero criterion 27) call them directly. Owners call none.

### 2. Construction and ownership

- `static func validate(drag_slop, tap_slop) -> bool`: both finite, `8 <= drag_slop <= 30`, `16 <= tap_slop <= 34`, `tap_slop > drag_slop` (Input Rule 9).
- `static func create(drag_slop, tap_slop, dev_error: Callable = Callable()) -> InputResolver`: null when `validate` fails, else `InputResolver.new(...)`; reports nothing. `_init` takes the same arguments and default and squares the slops once. Slops are fixed per battle.
- **Builder step 2** calls `InputResolver.create(record.drag_slop, record.tap_slop, dev_error)`; on null, `fatal("input record: invalid slops")` and return null; else it sets **`Battle.resolver: InputResolver`**, read-only like `input_record`. This names ADR-0003's placeholder and is ADR-0006's emitter key `&"resolver"`.
- **Reports**: `_report(msg)` calls `dev_error` when valid, else `push_error`. ADR-0001's default sink calls `push_error`, so "dropped with `push_error`" holds; tests pass a recording fake.
- **Lifetime**: `Battle` holds the only strong reference outside the wrapper. The wrapper passes `battle.resolver` to the adapter, HeroInput, TowerInput, HudLogic and `GestureLog`, connects G1 to G8 in `_connect_signals()`, and each node drops it in `detach()`. Retry builds a new one; nothing is reset. The weakref proof covers it.

### 3. Positions: `Vector2` at the API, `float` scalars inside (QQ-05)

- **API**: every position is `Vector2` in 540x960 field units, as ADR-0003 and ADR-0006 fixed and the registry allows (adapter input, view payloads).
- **Inside**: no `Vector2` method or operator. `.x` and `.y` are read into `float` (64-bit); `dx * dx + dy * dy` is compared with `r * r` or a slop squared; geometry is stored as `float` pairs. This follows ADR-0004's float policy because the resolver chooses which command runs and the equivalence test compares bit for bit.
- **Exactness**: a 32-bit component (expected, V2) widens exactly; differences, squares and sums of field-sized values round at most once in 64 bits, and not at all for the integer positions the criteria use, so the boundaries of criteria 30 and 31 compare exactly.
- **Pass-through**: every payload position is a received value (`p`, `release_pos`, and `press_pos` kept as a `Vector2` copy), so the resolver adds no rounding to positions owners pass to commands; owners convert to scalars there (ADR-0009 Decision 2).

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

var _targets: Array[Target] = []      # ascending id; append on register, remove_at on unregister
var _next_id: int = 1                 # never reset, never reused
const MIN_SUPPORTED_WIDTH_DP := 360   # equals FieldMapping.MIN_FIELD_WIDTH_DP (unit-tested)
```

- **No owner reference.** A row holds values only, never an owner, node, Callable or object; owners keep the `int` id. No cycle can form, and a freed owner leaves only an unused id.
- **Calls**, immediate, legal in any state and inside handlers, never queued:

| Call | Rejected when | On rejection |
|---|---|---|
| `register(centre, radius, accepts, priority, sink = false) -> int` | `centre` non-finite; `radius` non-finite or `<= 0`; `accepts` not `TAP` or `DRAG` (V4); `sink` with `DRAG` | `NONE`, nothing added, `_report` |
| `unregister(id)` | unknown id | no-op, `_report` |
| `set_centre(id, centre)` | unknown id, or non-finite `centre` | no-op (old centre kept), `_report` |
| `set_enabled(id, enabled)` | unknown id | no-op, `_report` |

- `register` appends with `id = _next_id` and increments; `unregister` uses an index loop and `remove_at`.
- **Effective at once** means the next hit test sees it. Hit tests run only at a press, so a change inside a handler affects the next press, never the gesture in flight (Input criteria 6, 26, 27).
- **48 dp guard**: `register` calls `target_ok(radius, MIN_SUPPORTED_WIDTH_DP)` and on false calls `_report` but registers. The local constant keeps the class free of ADR-0003 names; a unit test asserts it equals `FieldMapping.MIN_FIELD_WIDTH_DP`.
- No `Dictionary`, so no result depends on iteration order. Duplicates are the owner's bug.

### 5. Press: winners, frozen discs, the press's slop

A press that starts a gesture scans `_targets` once in id order. A row is a candidate when `enabled` and `dx*dx + dy*dy <= radius*radius`. Per class the best is: higher `priority`, then smaller squared distance, then lower id; in ascending id order a later row wins only on higher priority, or equal priority with strictly smaller distance.

Frozen in scalar fields: each winner's id, centre and radius (and the tap winner's sink flag), or `NONE`; the press point as scalars and as the `Vector2`; the active pointer; `_slop_sq`, which is the tap slop squared if the press has a **real tap winner** (not a sink) or no winner at all, else the drag slop squared (Input Rule 3). The registry is not read again for the gesture: a release tests the frozen tap disc with no `enabled` term, and a target changed or removed mid-gesture still receives its signals under its old id.

### 6. The state machine

`enum State { IDLE, PRESSED, DRAGGING, DEAD }`, read with `state()`. The branches restate the GDD's transition table, which stays the source.

**`press(i, p)`**: (1) `IDLE`: begin (Decision 5), commit `PRESSED`, emit `pressed(best_tap, best_drag, p)`. (2) `i` is the active pointer: end as a cancel (outcome `REPRESSED`), then begin. (3) Replaceable (state `PRESSED` or `DEAD` with no real tap winner): end as a cancel (`REPLACED`), then begin with `i` active; `DRAGGING` or a real tap winner never is (Input Rule 1). (4) Otherwise dropped.

**`move(i, p)`**: dropped in `IDLE` or for another pointer. Else update the record's travel; in `PRESSED`, if `crossed` (squared distance from the press point `>= _slop_sq`): with a drag winner commit `DRAGGING` and emit `drag_started(drag, press_pos, p)` only, without one commit `DEAD`; in `DRAGGING` emit `drag_moved(drag, press_pos, p)`, one per call.

**`release(i, p)`**: dropped in `IDLE` or for another pointer. Else decide the batch, capture arguments, commit `IDLE` (clear pointer and frozen fields, finalise the record), then emit:

| State | Condition | Batch |
|---|---|---|
| `PRESSED` | crossed, drag winner (lost moves) | `drag_started`, `drag_ended(drag, press_pos, p)`, `became_idle` |
| `PRESSED` | crossed, no drag winner | `became_idle` |
| `PRESSED` | under slop, tap winner (sink included), `p` inside its frozen disc | `tapped(tap, p)`, `became_idle` |
| `PRESSED` | under slop, tap winner, `p` outside it | `became_idle` |
| `PRESSED` | under slop, no winner | `ground_tapped(p)`, `became_idle` |
| `PRESSED` | under slop, only a drag winner | `became_idle` |
| `DRAGGING` | any | `drag_ended(drag, press_pos, p)`, `became_idle` |
| `DEAD` | any | `became_idle` |

**`cancel()`**, and **`cancel_pointer(i)`** for the active pointer, end the gesture as a cancel (`CANCELLED`) outside `IDLE`; otherwise nothing. **End as a cancel**: capture whether it was dragging and its winner, commit `IDLE`, finalise the record, emit `drag_cancelled(drag)` if it was dragging, then `became_idle`. No release is synthesised; no cancel, replacement or re-press emits `ground_tapped`.

**Cancel-then-press is two steps in one call**: the cancel step commits and emits its batch; then the press step hit-tests the registry as it stands, commits and emits `pressed`. A registry change made on that `became_idle` reaches the new press; calls queued during either step run after both (Decision 11, choice 3).

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
    var _hold: InputResolver = self     # keeps this object alive until return (V1 d)
    if _aborting:
        return                          # calls made while an abort ends the gesture are discarded
    _q_kind.append(kind)
    _q_pointer.append(pointer)
    _q_pos.append(pos)
    if _draining:
        return                          # a handler's call: runs after the current batch
    _draining = true
    var i := 0
    while i < _q_kind.size():           # size re-read: handlers append mid-loop (V1 b)
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

- **A batch** is every signal one call emits, `became_idle` included (both steps of a cancel-then-press). `_run` commits with arguments in locals, then emits with `signal.emit(...)`; each emit reaches every listener before returning (V1 a), so the batch is delivered when `_run` returns.
- **A nested gesture call** appends and returns; it runs after the current batch, in arrival order. So a `cancel()` from a `pressed` handler lets every listener hear `pressed` before any hears `became_idle`, and a `press` from `tapped` starts after that gesture's `became_idle` (Input criterion 27). Registry calls are never queued, so `register` inside `tapped` returns an id at once.
- **Non-finite positions** are dropped before the queue with `_report`.
- **Cancels outside a drain run at once** (`cancel_all()` from a loss notification; Flow's `cancel_input()` inside a tick), so G7 and G8 fire inside that callback, as ADR-0006 allows. A `cancel()` during a drain queues behind the batch.
- **Runaway cap**: reaching 64 calls in one drain is a defect. `_abort_drain()` sets `_aborting`, calls `_report`, ends any live gesture as a cancel (listeners' gesture calls are discarded, so no nested drain starts), and clears `_aborting`; `_enqueue` then clears the queue.
- **Teardown mid-drain** is forbidden by ADR-0001 Decision 7 (only `AppRoot._process` tears down, never a handler or fatal call); `_hold` guards a defect (V1 d).
- **Stuck flag**: a script error inside `_run` aborts `_enqueue` in a debug run with `_draining` still true (V1 e; ADR-0004 V4 records release). Branch decided: `InputAdapter.flush()`, never nested, first calls `resolver.recover_if_stuck() -> bool`. If `_draining` is true there, the resolver reports, clears queue and flags, ends any live gesture as a cancel (with `_draining` set while it emits), and returns true. Resetting the flag inside `_enqueue` instead would break re-entrancy (Alternative 9).
- Packed `clear()` may reallocate small arrays per drain: negligible. The queue is per resolver, never static.

### 8. Signals, the gesture record and the development log

**Signals** are ADR-0006's G1 to G8, copied exactly (Key Interfaces), each with a `##` comment naming its id, emitted with `name.emit(...)`. G1 to G6 (`pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended`) fire only inside a drain `flush()` started, or in a test, which is what lets their listeners issue commands (ADR-0006 rule 3). G7 `drag_cancelled` and G8 `became_idle` may also fire inside a tick or an engine callback through `cancel()`. `became_idle` is last in every exit to `IDLE` and fires exactly once per gesture. **`pressed` carries both frozen winners** (TR-hud-009), so owners decide at press for the whole gesture. A listener disconnected during an emit may still get that emit (V1 c): owners ignore signals after their `detach()`.

**`GestureRecord`** (`src/foundation/input/gesture_record.gd`, `RefCounted`, no signal, references no other script) holds values: `serial` (from 1), `pointer`, `press_pos`, `end_pos`, `moves`, `max_travel` (`sqrt` of the largest squared travel over moves and the release), `best_tap`, `best_drag`, `tap_sink`, `tap_centre`, `drag_centre`, `tap_candidates`, `drag_candidates`, `tap_rule` and `drag_rule` (`WinRule`: the comparison that last decided the winner), `slop`, and `outcome` (`Outcome`, `OPEN` while live). The resolver fills it at press, updates it per call, and finalises `outcome` and `end_pos` before the ending batch, so a `became_idle` listener reads the finished gesture. It is kept in every build (a few field writes; no build check in a pure class). **`last_gesture()` returns null before the first gesture**, else a new copy.

**`GestureLog`** (`src/presentation/dev/gesture_log.gd`, `extends Node`), binding parts only:

- Created by `BattleWrapper.attach` only when `OS.is_debug_build()` (V7). A view listener under ADR-0006 rule 2: reads only, no command, no sim write.
- `attach(resolver, adapter, sink: Callable, chip_open: Callable = Callable())`. The wrapper connects `resolver.pressed`, `resolver.became_idle` and `tower_sim.tower_upgraded` (ADR-0006 P5) to it in `_connect_signals()`, undone in `detach()`. `chip_open` is `tower_input.is_chip_open` (ADR-0010 Decision 8). The sink is `dev_logs.gesture_sink.write_line`, writing `user://gesture_log.jsonl` (ADR-0010 Decision 10).
- Timing: `Time.get_ticks_msec()` (sourced, ADR-0004 V8) in its `pressed` and `became_idle` handlers; frame-quantised, enough for Pillar 4. Not sim code and not a real-time model, so outside `engine_time_in_sim`; the lint excludes `src/presentation/dev/` (cascade).
- Device from `OS.get_model_name()` (V7); insets and width from `adapter.field_insets()` and `field_width_dp()`.
- Output through `sink` (`write_line(text: String) -> bool`). No `Vector2` in a record: `x` and `y` fields, `JSON.stringify(record, "", true, true)`. A write failure is reported once through `dev_error`, never fatal. A file sink must append (V8): `READ_WRITE` if the file exists, else `WRITE`; `seek_end()`; one handle; `flush()` per line (Android kills apps); check every `store_*` `bool`.
- The prompter, press-offset rule, JSON field list and interim file are the Pillar 4 harness story's, within these rules.

### 9. What owners get (non-binding restatement)

The resolver decides no meaning. This restates how the GDDs use the guaranteed calls; the GDD rules and ADR-0010 are the source, and no value here binds.

- **TowerInput** (Tower Rule 8, Interactions; Battle HUD Rule 9): registers slots, towers and the chip; `set_enabled` on a built slot; unregisters the chip on close; closes it on `phase_changed`, since `cancel()` in Idle emits nothing; ignores taps while halted.
- **HeroInput** (Hero Rules 13, 15): registers hero, button and sink; calls `set_centre` in `update()` at frame step 4 (ADR-0004 Decision 5), outside any drain; tests cancel hysteresis itself on the unchanged drag positions.
- **HudLogic** (Battle HUD Rules 6 to 8, 10, 11, 14): registers arc discs and backdrop inside `slot_tapped`, which runs inside the `tapped` batch, so they compete from the next press; toggles Start/Call with `set_enabled`; unregisters on close.
- Owners keep ids as `int`, compare with `==`, and ignore signals for ids they dropped.

**Open items for ADR-0010** (not decided here): (1) who owns `chip_state()`: Tower GDD Rule 17 says TowerInput, `architecture.md` B10 says TowerSim; ADR-0010 also wires `GestureLog`'s `chip_open`. (2) `halted()` injection into TowerInput (TR-tower-011 needs it; B9 injects it into EnemyWave, TowerSim, HeroSim and HudLogic only). (3) Scalar conversion of gesture positions in HeroInput and TowerInput commands.

### 10. Formulas in code

`inside` and the tie-break: Decision 5. `is_drag`, `is_dead`: Decision 6. `target_ok` is static and pure, so Input criterion 33 tests production code:

```gdscript
## True when a disc of this radius is at least 48 dp across at this width.
## Integers only: both floored first, compared without division (Input Formulas).
static func target_ok(radius: float, width_dp: float) -> bool:
    if not (is_finite(radius) and is_finite(width_dp)):
        return false
    return 2 * floori(radius) * floori(width_dp) >= 25920   # 48 * 540
```

True for 36 and 48 at 360, false for 35. The runtime width check stays ADR-0003's `FieldMapping.width_supported`; they agree at radius 36.

### 11. Choices made in autonomous mode

Each can be overturned (Status step 4; cascade section d):

1. `Battle.resolver` as a member, not a `resolver()` method.
2. An optional `dev_error` argument on `create` and `_init`, falling back to `push_error`.
3. Cancel-then-press as two steps, the new press hit-testing after the cancel batch.
4. A cap of 64 calls per drain; the abort discards calls made while it ends the gesture.
5. `register` reports, but accepts, a radius failing `target_ok` at 360 dp.
6. `GestureRecord` kept in every build; `GestureLog` stamps `Time.get_ticks_msec()`, not a frame-fed `advance(ms)`.
7. Until ADR-0010 provides the run-log sink, the harness story uses its own JSONL file sink under V8's rules; ADR-0010 may merge both logs into one file.

### Architecture Diagram

```
 InputAdapter (ADR-0003)                    BattleBuilder step 2 (ADR-0001)
   flush() at frame step 0:                   InputResolver.create(drag_slop, tap_slop, dev_error)
     recover_if_stuck(), then queued calls    null -> fatal; else Battle.resolver
   cancel_all() -> resolver.cancel()
        | press / move / release / cancel_pointer / cancel (Vector2, field units)
        v
 +------------------------ InputResolver (RefCounted, pure) ------------------------+
 | is_finite check -> FIFO queue -> drain unless draining (aborting: discard)      |
 | _run: decide -> COMMIT (state, frozen scalars, record) -> EMIT batch            |
 | IDLE -press-> PRESSED -move>=slop-> DRAGGING | DEAD; any exit -> IDLE, became_idle|
 | Registry: Array[Target] by id, values only; 4 calls immediate                   |
 +-----+------------------------------+---------------------------------------------+
       | G1 to G6 (inside flush only)  | G7, G8 (also inside a tick or engine callback)
       v                               v
 HeroInput, TowerInput, HudLogic (wrapper connections); set_centre(hero) at step 4
 GestureLog (debug only): pressed, became_idle, tower_upgraded -> last_gesture() -> sink
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

## Gesture calls (queued): the adapter, the wrapper's detach (cancel only), tests.
func press(pointer: int, pos: Vector2) -> void
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
func cancel() -> void
func recover_if_stuck() -> bool          # InputAdapter.flush() only, first

## Registry: any state, inside handlers too; effective at the next press; never queued.
func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void

func state() -> State
func centre_of(id: int) -> Vector2       # Vector2(NAN, NAN) if unknown; logs and tests only
func last_gesture() -> GestureRecord     # null before the first gesture; else a new copy

# src/foundation/input/gesture_record.gd
class_name GestureRecord extends RefCounted
enum WinRule { NO_CANDIDATE, ONLY, PRIORITY, DISTANCE, ID }
enum Outcome { OPEN, TAPPED, GROUND_TAPPED, ROLLED_OFF, DRAG_WINNER_ONLY, DRAGGED,
               DRAGGED_LOST_MOVES, DEAD, CANCELLED, REPLACED, REPRESSED }
# fields as Decision 8; func copy() -> GestureRecord

# src/root/battle.gd (addition)
var resolver: InputResolver              # read-only by contract; set in BattleBuilder step 2

# src/presentation/dev/gesture_log.gd (debug builds only)
class_name GestureLog extends Node
func attach(resolver: InputResolver, adapter: InputAdapter, sink: Callable, chip_open: Callable = Callable()) -> void
func detach() -> void
```

`class_name` collisions (QQ-16) are checked by ADR-0007 NAME-1 to NAME-4; names stand unless ADR-0007 V6 reports one. Test classes declare no `class_name` (ADR-0007 NAME-3): `FakeResolver` is `const FakeResolver := preload("res://tests/unit/input_gesture_resolver/helpers/fake_resolver.gd")`, used as `FakeResolver.new(15.0, 28.0)`; ADR-0007 PROJ-7 also keeps `tests/` out of export presets.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- `InputResolver` must extend `RefCounted`, must never read a node, the scene tree, a viewport, `DisplayServer`, `Input`, `Engine`, `Time`, `OS`, a timer or `await`, and must reference no project class but `GestureRecord`.
- Must be created only by `InputResolver.create(...)` in Builder step 2, with `fatal` and a null return on null; `InputResolver.new(` only in its own file and `tests/`; fakes use `FakeResolver.new(...)`.
- In production only `InputAdapter.flush()` may call `press`, `move`, `release`, `cancel_pointer`, `recover_if_stuck`; `cancel()` only from `cancel_all()` and the wrapper's `detach()`. A `drag_cancelled` or `became_idle` listener must never make a gesture call or issue a command.
- A `Target` row must hold values only; owners hold `int` ids and clear them, and the resolver, in `detach()`; owners must ignore signals after `detach()`.
- The registry must be an id-ordered `Array[Target]`, never a `Dictionary`; ids never reset or reused. Registry calls immediate; gesture calls always queued.
- Each gesture call must commit state, frozen fields and record before its first `emit()`; `became_idle` last and exactly once per gesture.
- Must never use a `Vector2` method or operator in a decision; squared distances in `float`; received `Vector2` values passed to payloads unchanged.
- Non-finite positions dropped with `_report` before any change; `register` returns `NONE` for every case in Decision 4.
- Breaches go through `dev_error` (else `push_error`), never `assert` or `print`.
- ADR-0006's eight signals only, emitted with `name.emit(...)`, connected by the wrapper with flags 0. No `static var`.
- `last_gesture()` returns null before the first gesture, else a new copy; no caller keeps a record past its handler.
- `GestureLog` exists only when `OS.is_debug_build()`; issues no command; writes no `Vector2`; reports a sink failure once, never fatal; a file sink follows V8.
- Fakes extending `InputResolver` give typed overrides an explicit `return` (4.7) and forward `_init` to `super(...)`.

## Alternatives Considered

### Alternative 1: Engine picking (`Area2D` or `Control` targets)
- **Description**: The engine picks the hit target.
- **Pros**: No hit-test code.
- **Cons**: Needs a scene (no headless or equivalence tests); 4.7 picking and touch unsourced (HIGH); non-modal Controls are `MOUSE_FILTER_IGNORE` (ADR-0003).
- **Estimated Effort**: Lower to write, far higher to verify.
- **Rejection Reason**: Breaks TR-input-001.

### Alternative 2: Deferred emission instead of a queue
- **Description**: `call_deferred` or `CONNECT_DEFERRED`.
- **Pros**: No queue code.
- **Cons**: Forbidden by ADR-0006; gesture commands would follow the ticks (TR-hud-005).
- **Estimated Effort**: Similar.
- **Rejection Reason**: Contradicts ADR-0006 Decision 2 and ADR-0004 Decision 5.

### Alternative 3: Immediate re-entry
- **Description**: A nested call runs inside its caller's handler.
- **Pros**: Simplest.
- **Cons**: Later listeners hear `became_idle` before `pressed` (criterion 27).
- **Estimated Effort**: Lower.
- **Rejection Reason**: Violates TR-input-010.

### Alternative 4: Rows that hold their owners
- **Description**: `register(owner, ...)` with callbacks.
- **Pros**: No id bookkeeping.
- **Cons**: Resolver-to-node references against ADR-0001 teardown; a delivery path outside ADR-0006's tests.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Cycle and contract risk.

### Alternative 5: `Vector2` maths inside
- **Description**: `distance_squared_to` on `Vector2` centres.
- **Pros**: Shorter.
- **Cons**: 32-bit arithmetic if V2 holds, against ADR-0004's float policy.
- **Estimated Effort**: Slightly lower.
- **Rejection Reason**: Scalars cost a few lines and remove the question.

### Alternative 6: `float` pairs in the API
- **Description**: `press(pointer, x, y)`, scalar payloads.
- **Pros**: No `Vector2` in input.
- **Cons**: Changes ADR-0003, ADR-0006 and the registry for no gain.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Contradicts registered stances.

### Alternative 7: A clock in the resolver
- **Description**: The resolver stamps times for the log.
- **Pros**: One place.
- **Cons**: Breaks Rule 13 and TR-input-001.
- **Estimated Effort**: Lower.
- **Rejection Reason**: The development node stamps instead.

### Alternative 8: One batch for cancel-then-press
- **Description**: Commit both, then emit all three signals.
- **Pros**: One commit point.
- **Cons**: A registry change on that `became_idle` misses the new press.
- **Estimated Effort**: Same.
- **Rejection Reason**: Two steps keep commit-then-emit per step.

### Alternative 9: Reset the stuck flag inside `_enqueue`
- **Description**: Clear `_draining` when the queue is empty at entry.
- **Pros**: No adapter change.
- **Cons**: An empty queue with `_draining` true is also legal while an abort or a drain's last call emits; resetting starts a nested drain (TD-ADR T3).
- **Estimated Effort**: Same.
- **Rejection Reason**: `recover_if_stuck()` runs at the one point known not to be nested.

## Consequences

### Positive
- Every GDD criterion runs headless against the real class with integer positions.
- No resolver-to-owner reference: retry frees it; the weakref proof covers it.
- One testable rule for nested calls; immediate registry calls keep the HUD's arc working.
- No rounding added to positions; the equivalence test compares like with like.
- Every Rule 13 field reaches the log with no clock or build flag in the resolver.

### Negative
- Owners keep ids and ignore signals for dropped ids or after `detach()`.
- Queue, cap, abort flag and `recover_if_stuck()` add code, plus one adapter line.
- New names other documents must pick up (cascade).
- The `engine_time_in_sim` lint must exclude `src/presentation/dev/`.

### Neutral
- The record is kept in release builds; positions stay `Vector2` at the API.

## Risks
- **`emit()` not synchronous (V1 a)**: batches interleave. V1 runs before acceptance; its branch reopens this ADR with ADR-0006.
- **Stuck `_draining` (V1 e, ADR-0004 V4)**: `recover_if_stuck()` at the next `flush()`; a test forces the flag.
- **Teardown mid-drain**: forbidden by ADR-0001 Decision 7; `_hold` covers a defect (V1 d).
- **The cap hides a defect**: `_report` names it; a test watches it fire.
- **Owners forget to unregister**: HUD and Tower wiring criteria check fakes; `centre_of` asserts absence.
- **Adapter `flush()` and `cancel_all()` interleave**: a gesture listener's command can reach `cancel_all()` (a fatal's `cancel_input()`) mid-`flush()`. The resolver queues the `cancel()`; the adapter must tolerate its queue emptying mid-loop (cascade edit to ADR-0003, plus an adapter test).
- **A late signal after `detach()` (V1 c)**: owners ignore it.
- **Lost log lines on Android**: `flush()` per line (V8).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-001: pure, scene-free, clock-free, driven only by the five calls | Decisions 1, 7 |
| input-gesture-resolver.md | TR-input-007: disc registry; four calls legal in any state, applied at once | Decisions 4, 5 |
| input-gesture-resolver.md | TR-input-008: four states, one pointer, winners frozen at press, per-press slop | Decisions 5, 6 |
| input-gesture-resolver.md | TR-input-009: signal API; idle signal last on every exit to Idle | Decision 8 (ADR-0006 names; `became_idle` last, once) |
| input-gesture-resolver.md | TR-input-010: commit before emit; nested calls FIFO, drained in the outermost call | Decision 7; Decision 6 (two-step cancel-then-press) |
| input-gesture-resolver.md | TR-input-011: static `validate()`, null-returning `create()`; non-finite dropped with `push_error` | Decision 2; Decisions 4, 7 (`dev_error`, else `push_error`) |
| input-gesture-resolver.md | TR-input-015: dev-build gesture log (device, insets, timing, travel, winners, classification) | Decision 8 |
| input-gesture-resolver.md | Formulas: inside, is_drag, tie-break, integer `target_ok` | Decisions 5, 6, 10 |
| tower-system.md | TR-tower-011: TowerInput registers slots and chip, disables built slots, closes the chip on phase, ignores taps while halted | Decision 4; Decision 9 (restatement; `halted()` injection is ADR-0010 open item 2) |
| hero-system.md | TR-hero-010: HeroInput registers hero, button and sink, updates the walking hero's centre each frame, hit-tests hysteresis | Decision 4 (`set_centre`); Decision 9 (step 4, outside a drain); Decision 3 (unchanged positions) |
| battle-hud.md | TR-hud-008: the arc registers and unregisters, disables Start/Call while open, closes on outcome, Paused or Fatal | Decision 4 (`register` in `tapped` returns at once; `set_enabled`); Decision 8 (`cancel` emits only G7, G8) |
| battle-hud.md | TR-hud-009: `pressed` exposes `best_tap` and `best_drag` | Decision 8 |

## Performance Implications
- **CPU**: a press scans about 20 rows; a move or release is a few float operations and at most three emits; one to three calls per frame. Inside the 0.5 ms input slice; unmeasured.
- **Memory**: about 20 rows, three small queue arrays, one record; `last_gesture()` allocates one copy per call.
- **Load Time**: none.
- **Network**: none.

## Migration Plan

No code exists. Document edits: cascade notes, section a (`architecture.md` B0, B2, B4, B9, Module Ownership, Data Flow 9; ADR-0001 step 2; ADR-0003 Decisions 1 and 2 and guidelines; ADR-0006 Depends On; the registry note on `engine_time_in_sim`; Input GDD Rules 9 and 13 and criterion 36). The TR registry and matrix are `/architecture-review`'s.

**Rollback plan**: one class plus one value class. Changing the queue, cap, recovery or cancel-then-press order touches `input_resolver.gd`, its tests and one adapter line; signals, registry API and `Battle.resolver` stay. Dropping `GestureLog` removes one dev node and three connections.

## Validation Criteria

1. The Input GDD's 37 Logic criteria pass in `tests/unit/input_gesture_resolver/` with a recording fake that logs each argument and its type, and a recording `dev_error`; criteria 19 to 21 also assert the reports.
2. Added tests: `register` in the `became_idle` of a cancel-then-press is a candidate for the new press; a listener pressing on every `pressed` stops at 64 calls with one report, state `IDLE`, no nested drain; a forced `_draining` makes `recover_if_stuck()` return true once and leave `IDLE`; `cancel()` outside a drain emits at once; `last_gesture()` is null when fresh and a new, equal copy after; `MIN_SUPPORTED_WIDTH_DP == FieldMapping.MIN_FIELD_WIDTH_DP`.
3. `GestureRecord` fields for Input criteria 7, 8, 14, 16, 28, 32, 35, 37 match hand-computed values.
4. ADR-0001's weakref proof reads null for the resolver after a battle with targets and connected fakes.
5. ADR-0006's tests: the eight signals on `VIEW_ALLOWLIST`, no headless connection, listeners after `attach`, none after `detach`.
6. Hero criterion 27 gives identical per-tick state.
7. Lint (ADR-0007): no `Vector2` method or operator in `input_resolver.gd`; `InputResolver.new(` only there and in tests; no `Dictionary` field; no `emit_signal(`; `Time.*` among wrapper nodes only under `src/presentation/dev/`.
8. Pillar 4 gate P1: the phone-test table computes from `GestureLog` output alone.

## Related
- Depends on ADR-0003, ADR-0006; binding ADR-0001, 0002, 0004, 0009; enables ADR-0007, ADR-0010 (open items, Decision 9), ADR-0011.
- `design/gdd/input-gesture-resolver.md` (Rules 1 to 13, States and Transitions, Formulas, Edge Cases, Acceptance Criteria); `hero-system.md` (Rules 13, 15; criteria 15, 27); `tower-system.md` (Rules 8, 17); `battle-hud.md` (Rules 6 to 11, 14).
- `docs/architecture/architecture.md` B2, B3, B9, B10, Data Flow 1, 3, 9.
- Code (once written): `src/foundation/input/input_resolver.gd`, `gesture_record.gd`, `src/presentation/dev/gesture_log.gd`, `tests/unit/input_gesture_resolver/`.
