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
> 1. ADR-0003 and ADR-0006 are Accepted (ADR-0006 depends on ADR-0001 and ADR-0004, so those are Accepted too).
> 2. V1 to V6 (Engine Compatibility) have recorded results from one headless script run outside
>    `src/` (`prototypes/adr-0008-resolver-check/check.gd`), copied into
>    `docs/engine-reference/godot/current-best-practices.md` with the engine version. Items that reuse
>    another ADR's check (V2 = ADR-0009 V1, V3 = ADR-0009 V3) count once they are recorded there.
>    Where a result takes a branch, this ADR is revised to that branch first. V7 has a desktop result;
>    its phone result is recorded at the first phone build and changes one log field only.
> 3. The edits in the cascade notes (section a) are applied, or the user overturns them one by one.
> 4. The user has confirmed or overturned each autonomous choice listed in Decision 12.
>
> **After acceptance:** the GDD's 37 Logic criteria become the resolver's unit tests (first resolver
> story). Reopen trigger: a criterion that cannot pass as this ADR is written, or a phone-test log
> (Pillar 4 gate P1) that shows a mis-fire the resolver caused, amends this ADR before the next
> input story closes.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only (Godot 4.7.2). The live Godot 4.7 documentation was not reachable from the authoring session (`docs.godotengine.org` is outside the session's network policy). The resolver is plain GDScript with no engine calls in its decision path, so the engine facts it relies on are few; each one the pinned reference does not cover is a numbered verification item (V1 to V7), not a fact.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode.

## Summary

The Input & Gesture Resolver turns one pointer's press, moves and release into exactly one tap, one drag or nothing for exactly one registered disc, and the GDD fixes its rules but not how a pure object meets them under re-entrant handlers, frozen winners and a dev gesture log. This ADR decides an `InputResolver extends RefCounted` built by `BattleBuilder` through `create(drag_slop, tap_slop, dev_error)` and held as `Battle.resolver`; a value-only target registry keyed by never-reused `int` ids (no owner reference, so no cycle); a four-state machine whose winners and discs are frozen as scalars at press; one FIFO call queue drained by the outermost call, where each call commits its state and then emits its whole batch; `Vector2` only at the API and 64-bit scalar maths inside; ADR-0006's signal names and payloads exactly; and a `GestureRecord` read that a development-only `GestureLog` node turns into the Pillar 4 phone-test log.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM. The resolver calls no engine input API (the adapter, ADR-0003, holds every HIGH input fact). What remains is GDScript language behaviour: synchronous signal delivery with a listener calling back into the emitter, `Vector2` component precision, `is_finite`, enum-typed parameters, default `Callable` parameters, inner classes, and the 4.7 typed-override rule for test fakes. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md` (no touch coverage; nothing in it applies to a pure resolver). Binding ADRs: ADR-0001, ADR-0003, ADR-0004, ADR-0006, ADR-0009 (Decision 2, V1, V3). Registry: `docs/registry/architecture.yaml`. |
| **Post-Cutoff APIs Used** | None. Two pinned 4.7 facts bear on the decision: an override of a typed method inherits the return type and needs an explicit `return` (`breaking-changes.md`, 4.6 to 4.7, "GDScript breaks"), which applies to test fakes that extend `InputResolver`; and packed-array element writes no longer call a property setter (`current-best-practices.md`), which does not matter here because the queue uses `append` and `clear` only and has no setter. |
| **Verification Required** | V1 to V7 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: whether a listener may call a method on the emitting object during `emit()` and whether `emit()` returns only after every listener ran; `Vector2` component width (ADR-0009 V1); `is_finite` on NaN and infinities (ADR-0009 V3); what an out-of-range `int` does when passed to an enum-typed parameter; a `Callable()` default argument and `is_valid()` on it; an inner `RefCounted` class in a typed `Array` field; `OS.get_model_name()`. |

### Verification items

The gap is wired to acceptance: this ADR stays `Proposed` until each item has a recorded result (Status, step 2). V1 and V4 to V6 run in one headless script with no game code (`godot --headless -s prototypes/adr-0008-resolver-check/check.gd` on throwaway classes). Owner: godot-specialist writes the script; the user runs it on the pinned 4.7.2 editor; results go into `current-best-practices.md` with the engine version. "Expected" below is the author's expectation and is not a source.

- **V1. Calling back into the emitter during `emit()`.** A `RefCounted` emitter with `signal s(a: int)` and a method `poke(x: int)` that appends `x` to a `PackedInt64Array` and returns. Listener A, connected first, calls `emitter.poke(1)`; listener B, connected second, appends to its own log. Questions: does `s.emit(7)` run A then B before it returns (a line after `emit` sees both logs filled)? Does `poke` run normally from inside A, with no "already emitting" error? If A calls `s.emit(8)` (forbidden here, ADR-0006 rule 7), what happens (recorded only)? Also: `while i < arr.size()` over a `PackedInt64Array` that a listener appends to during the loop sees the new element. Expected: synchronous, no error, the loop sees it. **Decision 7 depends on the first two.** Branch: if `emit()` returned before its listeners ran, the queue could not know when a batch is delivered; the resolver would then not use signals for delivery, and ADR-0006 Decision 1 would be reopened with it. Partly overlaps ADR-0006 V4 and V5; this item adds the call-back case.
- **V2. `Vector2` component precision (QQ-05).** Reuses ADR-0009 V1 (`Vector2(0.1, 0.0).x == 0.1` false and `Vector2(16777217.0, 0.0).x == 16777217.0` false if components are 32-bit). Add one line to that script: `var v := Vector2(299.0, 500.0); var dx: float = v.x - 270.0` gives exactly `29.0`. **No decision depends on the answer**: Decision 3 holds for 32-bit and 64-bit components, because the resolver never rounds a position it passes on and does its arithmetic in `float`.
- **V3. Non-finite floats.** Reuses ADR-0009 V3 (`is_finite(NAN)`, `is_finite(INF)`, `is_finite(-INF)` false). Add: `is_finite(Vector2(NAN, 0.0).x)` and `is_finite(Vector2(INF, 0.0).x)` are false, so a non-finite component survives the `Vector2` and is caught. Branch: if `Vector2` turned NaN into a finite value, the guard still runs on the component, and the GDD's criterion 21 would need rewording only.
- **V4. Enum-typed parameter with an out-of-range value.** For `enum Accepts { TAP, DRAG }` and `func register(..., accepts: Accepts, ...)`: what do `register(..., 5, ...)`, `register(..., -1, ...)` and passing a value from another enum do on 4.7.2 (parse error, runtime error, warning, or silent)? Expected: a plain `int` is accepted, possibly with a warning. **Nothing branches**: Decision 4 checks `accepts` against both members explicitly either way; the result only tells test authors what to expect.
- **V5. A default `Callable` argument.** `static func create(a: float, b: float, dev_error: Callable = Callable()) -> InputResolver` parses; `Callable().is_valid()` is false; `obj.method` passed in is valid and callable with one `String`. Expected: yes. Branch: if a `Callable()` default does not parse, the parameter becomes required, every caller passes it, and fixtures pass a recording fake.
- **V6. Inner class rows and test fakes.** In a `class_name InputResolver extends RefCounted` script: an inner `class Target extends RefCounted` with typed fields; a field `var _targets: Array[Target] = []`; `append`, then `remove_at(i)` keeps the order of the rest (ADR-0009 V2(e)); `create()` calling `InputResolver.new(a, b)` from its own script. A fake `class_name FakeResolver extends InputResolver` (test folder) that overrides `register(...) -> int` with an explicit `return`, and overrides `set_centre(...) -> void`, parses and runs, and its `_init` forwards to `super(a, b)` (ADR-0009 V7). Expected: all parse and run. Branch: if the inner class cannot be typed in `Array[...]`, the field is an untyped `Array` with the same discipline; if a fake cannot extend `InputResolver`, ADR-0007 fakes wrap it instead and owners type their parameter `Object` (recorded in ADR-0007).
- **V7. Device label for the gesture log (development builds only).** Does `OS.get_model_name()` return a non-empty string on desktop (expected `GenericDevice` or similar) and a model name on Android? Does `OS.is_debug_build()` read true in an editor run and a debug export (ADR-0001 V4 covers the release side)? Desktop result gates acceptance; the Android value is recorded at the first phone build. Branch: if empty or generic on the phone, the tester types a device label into the harness config and the log writes that. Affects one log field only.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Proposed): the adapter is the only production caller of the five gesture calls; it queues them and delivers them in `InputAdapter.flush()` at frame step 0; `cancel_all()` empties its queue and calls `resolver.cancel()`; `lifecycle_paused`; positions are `Vector2` in 540x960 field units (registry `resolver_drive`). ADR-0006 (Proposed): the resolver's signal names (`pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `became_idle`), parameter names and types, ids as `int` with `NONE = -1`, listener rules (G7 and G8 listeners never issue commands), wrapper connections only, flags 0. Both must be Accepted before this one. Binding, not gating: ADR-0001 (Builder step 2 creates the resolver, null is fatal; method Callables only; no RefCounted cycle; no mutable `static var`; `dev_error`; teardown and the weakref proof), ADR-0004 (frame order: step 0 flush, step 4 `HeroInput.update()` before views; float policy), ADR-0009 (Decision 2 scalar positions, V1, V3), ADR-0002 (`InputRecord` fields). ADR-0005 is not used: the slops are read from the record directly (TR-input-012). |
| **Enables** | ADR-0007 (resolver unit tests from the GDD criteria, recording fakes, the `FakeResolver` pattern, lints in Implementation Guidelines), ADR-0010 (HeroInput and TowerInput placement and their registrations; the run-log sink this ADR's `GestureLog` writes through), ADR-0011 (views and HudField draw from owners' state, never from the resolver). |
| **Blocks** | Input & Gesture Resolver stories; every HeroInput, TowerInput and HudLogic story that registers a target or listens to a gesture signal; the Pillar 4 phone-test harness story. |
| **Ordering Note** | ADR-0006's GDD renames (its cascade section a) land before any resolver test file is written, so the tests use `tapped`, `ground_tapped` and `became_idle` from the start. ADR-0010 is written after this ADR and inherits Decisions 9 and 10. ADR-0006 is being revised in its text only at the time of writing; its decisions, which this ADR copies, are unchanged. |

## Context

### Problem Statement

The Input GDD states the resolver's rules completely: 13 rules, a 30-row transition table, edge cases and 37 Logic criteria written as exact signal logs. It leaves the implementation open where a wrong choice breaks those logs or the project's other rules. Five questions stand between the GDD and the first story. (1) A listener may call `press`, `cancel` or `register` from inside a handler (the HUD registers arc discs inside `tapped(slot)`; a bot presses from a `tapped` handler), so the resolver needs one exact rule for when a nested call runs and what it sees. (2) Owners register targets; the registry must not hold its owners, or the battle leaks on retry (ADR-0001). (3) ADR-0003 and ADR-0006 fix `Vector2` at the API, while ADR-0009 and ADR-0004 ban `Vector2` arithmetic on values that reach sim state; the resolver decides which commands run, so its maths must be stated. (4) The gesture log (Rule 13, TR-input-015) needs data that no signal carries, such as maximum travel and the rule that chose a winner, while the resolver must stay clock-free. (5) `architecture.md` B2 is a sketch: `Battle` has no resolver member yet (ADR-0003 used a placeholder `resolver()`), and the error path for a bad registration is unstated.

### Current State

No code exists. `architecture.md` B2 copies the GDD's API with the old signal names; ADR-0006 renamed them and fixed the payloads; ADR-0003 fixed the adapter and its queue; ADR-0001 put resolver creation in Builder step 2 and resolver release in the weakref proof; ADR-0004 put `HeroInput.update()` (which calls `set_centre`) in frame step 4. The mouse prototype (`prototypes/hero-pin-concept/main.gd`) resolved presses inline with no registry and no queue.

### Constraints

- Godot 4.7.2, GDScript, one main thread (TR-state-003). No engine input API in the resolver (ADR-0003 owns them).
- ADR-0001: no autoload, no mutable `static var`, no `RefCounted` cycle, method Callables only (no lambda, no `bind()`, no string forms), `dev_error` for non-fatal contract breaches, `assert` never for a release-relevant check.
- ADR-0006: names and payload types as fixed; every connection is a wrapper connection with flags 0; G1 to G6 fire only from `flush()` at frame step 0; G7 and G8 may fire inside a tick or an engine callback.
- ADR-0004: commands run only between ticks; no engine time in real-time models; float policy (allowed operations, no `Vector2` methods on values that reach sim state).
- Registry `sim_position_representation`: `Vector2` allowed for adapter input and view-signal payloads, never for a stored or compared sim position.
- Solo, part-time developer: one class, testable headless from the GDD's criteria as written.

### Requirements

- Pure, scene-free, clock-free, driven only by `press`, `move`, `release`, `cancel_pointer` and `cancel` (TR-input-001).
- A disc registry with `register`, `unregister`, `set_centre`, `set_enabled`, legal in any state, effective at once (TR-input-007).
- Four states, one active pointer, both winners frozen at press, per-press slop (TR-input-008).
- ADR-0006's eight signals; `became_idle` last on every exit to Idle (TR-input-009).
- Commit before emit; nested gesture calls queue FIFO and drain in the outermost call (TR-input-010).
- `validate()` and a `create()` that returns null; non-finite input dropped with `push_error` (TR-input-011).
- A development-build gesture log with the Rule 13 fields (TR-input-015).
- Serve TowerInput, HeroInput and the HUD as their GDDs require (TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009).
- Per-call work within the 0.5 ms input slice (ADR-0004 Decision 10).

## Decision

### 1. One pure class

`InputResolver` (`src/foundation/input/input_resolver.gd`, `class_name InputResolver extends RefCounted`) is the whole resolver. It reads no node, scene tree, viewport, display, `Input` singleton, `Engine`, `Time`, `OS`, timer or `await`; it has no `_process` and no `_notification`. Its only inputs are the five gesture calls, the four registry calls and the two slops; its only outputs are its eight signals, its return values and three read-only queries (`state()`, `centre_of(id)`, `last_gesture()`). It holds no reference to any battle object, owner or node. The same class runs in unit tests, in the equivalence test (Hero criterion 27) and in the game.

Only `InputAdapter.flush()` calls the five gesture calls in production. Tests and the equivalence harness call them directly. Owners call `cancel()` only if their GDD requires it (none does at MVP) and never call `press`, `move`, `release` or `cancel_pointer`.

### 2. Construction and ownership

```gdscript
static func validate(drag_slop: float, tap_slop: float) -> bool
static func create(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> InputResolver
```

- `validate` returns true only if both values are finite, `8 <= drag_slop <= 30`, `16 <= tap_slop <= 34` and `tap_slop > drag_slop` (Input Rule 9, Formulas). Pure, no output.
- `create` returns null when `validate` is false, and otherwise `InputResolver.new(drag_slop, tap_slop, dev_error)`. It reports nothing itself: the caller owns the failure.
- **Builder step 2** (ADR-0001) calls `InputResolver.create(record.drag_slop, record.tap_slop, dev_error)` with the battle's injected `dev_error`. On null it calls `fatal("input record: invalid slops")` and returns null. It stores the result as **`Battle.resolver: InputResolver`**, a read-only member like `flow` and `input_record`. This names ADR-0003's placeholder `battle.resolver()`; it is the object ADR-0006 lists as emitter key `&"resolver"`.
- The slops are fixed for the battle. `_drag_slop_sq` and `_tap_slop_sq` are computed once in `_init`. A runtime slop setter is reserved for Settings (Alpha) and not built.
- `dev_error` is ADR-0001's sink (`dev_error(msg: String) -> void`), held as a method Callable on an object that holds nothing of the battle. Every non-fatal breach below calls `_report(msg)`: `dev_error.call(msg)` when `dev_error.is_valid()`, else `push_error(msg)`. ADR-0001's default sink always calls `push_error`, so the GDD's "dropped with `push_error`" holds in every build. Tests pass a recording fake, so criteria 19 to 21 can assert the report without engine-error capture.
- `InputResolver.new(...)` is called only by `create` and by test fakes (V6). Production code must use `create`.
- **Lifetime.** `Battle` holds the only strong reference outside the wrapper. The wrapper passes `battle.resolver` to the adapter (`attach`), HeroInput, TowerInput and HudLogic, and connects G1 to G8 in `_connect_signals()` (ADR-0006 Decision 2). Every one of those nodes drops its reference in `detach()` (ADR-0001 Decision 6). Retry builds a new resolver with the new battle; nothing is reset (no `reset()`, registry `in_place_reset`). The weakref proof includes the resolver (ADR-0001 Validation 3).

### 3. Positions: `Vector2` at the API, `float` scalars inside (QQ-05)

- **API.** Every position parameter and payload is `Vector2` in 540x960 field units, as ADR-0003 (`resolver_drive`) and ADR-0006 (G1 to G8) fixed. The registry's `sim_position_representation` allows this: the calls are adapter input, and the signals are presentation-side payloads.
- **Inside.** The resolver never calls a `Vector2` method (`distance_squared_to`, `length`, operators on `Vector2`). It reads `pos.x` and `pos.y` into `float` locals (64-bit in GDScript) and computes `dx * dx + dy * dy` and compares it with `r * r` or a slop squared, all in `float`. Stored geometry (target centres, frozen discs, the press point) is kept as `float` pairs (`cx`, `cy`, `px`, `py`). This follows ADR-0004's float policy (allowed: `+ - * /`, comparisons, `is_finite`, `sqrt`) even though the resolver is input code, not sim code, because its decisions choose which command runs and the equivalence test compares results bit for bit.
- **Why this is exact enough.** If `Vector2` components are 32-bit (expected, V2), each component is a 32-bit value widened exactly to 64 bits; a difference of two such values, its square and a sum of two squares stay exact or round once in 64 bits, far below any distance that matters. For the integer positions the GDD's criteria use, every result is exact (all values are below 2^24 squared sums), so the boundary cases in criteria 30 and 31 (1296 against 1296, 225 against 225) compare exactly. Adapter-converted positions are fractional and sit on no boundary (GDD Formulas).
- **Pass-through, never re-built.** Every `Vector2` in a payload is a value the resolver received: `p` is the call's argument; `press_pos` is the press call's argument, stored as a `Vector2` copy beside its scalars; `release_pos` is the release argument. The resolver adds no rounding to any position an owner then passes to a command. HeroInput and TowerInput convert to scalars on entry to commands (ADR-0009 Decision 2, ADR-0010).
- `centre_of(id)` returns `Vector2(cx, cy)`; it is a read for the gesture log and tests only, never used in a decision.

### 4. The hit-target registry

**Storage.** An inner class holds one row per live target, and the rows sit in one typed array in ascending id order:

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
```

**No owner reference.** A row holds values only. It never stores the owner, a node, a Callable or any object; the owner keeps the `int` id that `register` returns. So the registry cannot form a cycle with HeroInput, TowerInput or HudLogic, and an owner that is freed leaves only an id nobody uses. Signals reach owners through wrapper connections, which ADR-0006 Decision 2 undoes in `detach()`.

**Calls** (all four run at once, in any state, inside a handler too; none is queued):

| Call | Valid input | Effect | On invalid input |
|---|---|---|---|
| `register(centre, radius, accepts, priority, sink = false) -> int` | `centre` finite; `radius` finite and `> 0`; `accepts` is `TAP` or `DRAG`; `sink` only with `TAP` | appends a row with `id = _next_id`, increments `_next_id`, returns the id | returns `NONE`, adds nothing, `_report(...)` |
| `unregister(id)` | a live id | removes the row (index loop, `remove_at`) | no-op, `_report(...)` |
| `set_centre(id, centre)` | a live id, finite `centre` | replaces `cx`, `cy` | unknown id: no-op, `_report`; non-finite: keeps the old centre, `_report` |
| `set_enabled(id, enabled)` | a live id | sets `enabled` | no-op, `_report(...)` |

- "Effective at once" means the next hit test sees the change. A hit test runs only at a press (Decision 5), so a change made inside a handler of one gesture affects the next press, and never the gesture in flight, whose winners and discs are frozen (GDD, registration paragraph; criteria 6, 26, 27).
- **48 dp guard.** `register` also calls `target_ok(radius, FieldMapping.MIN_FIELD_WIDTH_DP)` (Decision 11) and, when it is false, calls `_report("target under 48 dp at 360 dp")` but still registers the target. No MVP radius is below 36 (hero 56, burst button 48, chip 40, slot, tower and arc disc 36, arc backdrop 1200), so the report fires only on an owner bug.
- A double registration is the owner's bug; the resolver does not deduplicate (GDD Edge Cases).
- `Dictionary` is not used for the registry, so no result depends on iteration order (registry `unordered_iteration_in_sim`). With at most about 20 rows a linear search by id is cheaper than keeping an index.

### 5. Press: winners, frozen discs and the press's slop

On a press that starts a gesture, the resolver scans `_targets` once in id order. A row is a **candidate** when `enabled` and `inside(cx, cy, radius, p)`, where `inside` is `dx*dx + dy*dy <= radius*radius` (inclusive). For each class (`TAP`, `DRAG`) it keeps the best candidate: higher `priority`, then smaller squared distance, then lower id. Because the scan is in ascending id order, "lower id" is "seen first": a later row replaces the current best only when its priority is higher, or equal with a strictly smaller squared distance.

It then freezes, in scalar fields of the resolver itself:

- `_tap_id`, `_tap_cx`, `_tap_cy`, `_tap_r`, `_tap_sink` (or `_tap_id = NONE`);
- `_drag_id`, `_drag_cx`, `_drag_cy`, `_drag_r` (or `_drag_id = NONE`);
- `_px`, `_py` and `_press_pos` (the press `Vector2`), `_active` (the pointer);
- `_slop_sq`: `_tap_slop_sq` if the press has a **real tap winner** (`_tap_id != NONE and not _tap_sink`) or no winner at all, else `_drag_slop_sq` (Rule 3, is_drag formula).

Nothing later reads the registry for this gesture. A release tests the frozen tap disc with no `enabled` term (Formulas, inside). A target unregistered, disabled or moved mid-gesture keeps receiving this gesture's signals under its old id (criterion 26).

### 6. The state machine

`enum State { IDLE, PRESSED, DRAGGING, DEAD }`. `state()` returns the current value (tests and the gesture log). The table below is the GDD's transition table restated as the code's branches; the GDD stays the source and its criteria are the test.

**`press(i, p)`**

1. If `IDLE`: begin a gesture (Decision 5), commit `PRESSED`, emit `pressed(best_tap, best_drag, p)`.
2. Else if `i == _active` (lost release): end the current gesture as a cancel (step "end" below, outcome `REPRESSED`), then begin a new one as in 1.
3. Else if the current gesture is **replaceable**: state `PRESSED` or `DEAD`, and no real tap winner (none, or only a sink). End it as a cancel (outcome `REPLACED`), then begin the new one with `i` active. A `DRAGGING` gesture and any gesture with a real tap winner are never replaceable (Rule 1; criteria 2 to 4, 35 to 37).
4. Else: dropped, nothing emitted.

**`move(i, p)`**: dropped in `IDLE` or when `i != _active` (Rule 10). Otherwise the gesture record's travel is updated (Decision 9), then:
- `PRESSED`: `crossed = dx*dx + dy*dy >= _slop_sq` from the frozen press point. If crossed and `_drag_id != NONE`: commit `DRAGGING`, emit `drag_started(_drag_id, _press_pos, p)` only. If crossed and no drag winner: commit `DEAD`, emit nothing. Else nothing.
- `DRAGGING`: emit `drag_moved(_drag_id, _press_pos, p)`, one per call.
- `DEAD`: nothing.

**`release(i, p)`**: dropped in `IDLE` or when `i != _active`. Otherwise the resolver decides the batch from the current state and the frozen fields, captures every argument in locals, commits `IDLE` (clears `_active` and the frozen fields, finalises the gesture record), then emits:

| State at release | Condition | Batch |
|---|---|---|
| `PRESSED` | crossed and drag winner (lost moves) | `drag_started(drag, press_pos, p)`, `drag_ended(drag, press_pos, p)`, `became_idle()` |
| `PRESSED` | crossed, no drag winner | `became_idle()` |
| `PRESSED` | under slop, tap winner (sink included), `p` inside its frozen disc | `tapped(tap, p)`, `became_idle()` |
| `PRESSED` | under slop, tap winner, `p` outside its frozen disc (roll-off) | `became_idle()` |
| `PRESSED` | under slop, no winner at all | `ground_tapped(p)`, `became_idle()` |
| `PRESSED` | under slop, only a drag winner | `became_idle()` |
| `DRAGGING` | any | `drag_ended(drag, press_pos, p)`, `became_idle()` |
| `DEAD` | any | `became_idle()` |

**`cancel()`** and **`cancel_pointer(i)`** with `i == _active`: when not `IDLE`, end the gesture as a cancel (outcome `CANCELLED`). In `IDLE`, or for another pointer, nothing (criteria 16, 17, empty log).

**End as a cancel** (shared by `cancel`, `cancel_pointer`, re-press and replacement): capture `was_dragging` and `_drag_id`, commit `IDLE`, finalise the record, then emit `drag_cancelled(drag)` if `was_dragging`, then `became_idle()`. A release is never synthesised (Rule 7).

**Cancel-then-press is two steps in one call.** In rows 2 and 3 the cancel step commits and emits its whole batch first; then the press step runs its hit test against the registry as it stands at that moment, commits and emits `pressed`. So the cancel signals carry arguments captured before the new press commits (GDD transition note), and a registry change a listener makes on that `became_idle` is visible to the new press, as "effective at once" requires. Calls that listeners queue during either step run after both steps (Decision 7). Criterion 5's log (`..., drag_cancelled(H), became_idle, pressed(T, NONE)`) is the same under either reading; Decision 12 records the choice.

`ground_tapped` is never emitted on a cancel, a replacement or a re-press (GDD table row 2).

### 7. Commit before emit, and the FIFO queue

**Every gesture call goes through one queue.** The five public gesture methods check their input, append one entry, and drain if no drain is running:

```gdscript
const MAX_CALLS_PER_DRAIN := 64
var _q_kind := PackedInt64Array()      # PRESS, MOVE, RELEASE, CANCEL_POINTER, CANCEL
var _q_pointer := PackedInt64Array()
var _q_pos := PackedVector2Array()     # Vector2.ZERO for the two cancels
var _draining := false

func press(pointer: int, pos: Vector2) -> void:
    if not (is_finite(pos.x) and is_finite(pos.y)):
        _report("InputResolver.press: non-finite position")
        return
    _enqueue(_PRESS, pointer, pos)

func _enqueue(kind: int, pointer: int, pos: Vector2) -> void:
    _q_kind.append(kind)
    _q_pointer.append(pointer)
    _q_pos.append(pos)
    if _draining:
        return                          # a handler's call: runs after the current batch
    _draining = true
    var i := 0
    while i < _q_kind.size():           # size re-read: handlers append during the loop (V1)
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

- **A batch** is every signal one call emits, its `became_idle()` included (both steps of a cancel-then-press belong to that call). `_run` commits the call's state change first, with all arguments in locals, then emits the batch with `signal.emit(...)`. Godot delivers each emit to every listener before `emit()` returns (V1), so by the time `_run` returns, its whole batch has reached every listener.
- **A nested call** (a listener calling `press`, `move`, `release`, `cancel_pointer` or `cancel` while `_draining` is true) appends and returns at once. It runs after the current call's batch is complete, in arrival order. This gives the GDD's logs: a `cancel()` from a `pressed` handler lets every listener hear `pressed` before any hears `became_idle` (criterion 27, first case); a `press` from a `tapped` handler starts after that gesture's `became_idle` (criterion 27, second case).
- **Registry calls are never queued** (Decision 4), so `register` inside `tapped` returns a valid id at once (criterion 27, third case).
- **Non-finite positions** are dropped before they enter the queue, with `_report`, and change nothing (criterion 21). The two cancels take no position.
- **Cancels from outside a drain** run at once. That is the normal case for the adapter's `cancel_all()` on a loss notification and for Flow's `cancel_input()` inside a tick (ADR-0003 Decision 9): G7 and G8 then fire inside that callback, which ADR-0006 already allows for those two only. A `cancel()` that arrives during a drain (Flow's `cancel_input()` reached from a command a gesture listener issued, for example a fatal inside `build`) is queued and runs after the current batch.
- **Runaway guard.** A drain that reaches `MAX_CALLS_PER_DRAIN` calls is a defect (a listener that presses on every `pressed`, for example). `_abort_drain()` calls `_report`, clears the queue, ends any live gesture as a cancel (its own signals may queue more calls, which are discarded), clears the queue again, and returns. No legal flow comes near the cap: the adapter delivers at most a few calls per frame for one finger, and a handler adds at most one or two.
- The queue is per resolver, so it is dropped with the battle; it is not static (registry `mutable_static_var`).

### 8. Signals and when each fires

The declarations are ADR-0006 Decision 5 (G1 to G8), copied exactly:

```gdscript
signal pressed(best_tap: int, best_drag: int, p: Vector2)
signal tapped(best_tap: int, p: Vector2)
signal ground_tapped(p: Vector2)
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(best_drag: int)
signal became_idle()
```

| Signal | Emitted by | Can it fire outside `flush()`? |
|---|---|---|
| `pressed` | `press` that begins a gesture (Decision 6, rows 1 to 3) | no |
| `tapped` | `release` in `PRESSED`, under slop, inside the frozen tap disc | no |
| `ground_tapped` | `release` in `PRESSED`, under slop, no winner at all | no |
| `drag_started` | first crossing `move`, or a crossing `release` with a drag winner | no |
| `drag_moved` | each `move` in `DRAGGING` | no |
| `drag_ended` | `release` in `DRAGGING`, or a crossing `release` in `PRESSED` with a drag winner | no |
| `drag_cancelled` | end as a cancel while `DRAGGING` | **yes**: `cancel()` from `cancel_input()` inside a tick, or from `cancel_all()` in an engine callback |
| `became_idle` | last signal of every exit to `IDLE` | **yes**, with the signal before it |

- G1 to G6 fire only inside a drain that `InputAdapter.flush()` started at frame step 0, or inside a test. That is what lets their listeners issue commands (ADR-0006 rule 3). It holds because no production code other than the adapter calls `press`, `move` or `release` (Decision 1), and a G7 or G8 listener must never call them (Implementation Guidelines).
- **`pressed` carries both winners** (TR-hud-009): the HUD ignores the tap of a gesture whose `pressed` named Start/Call as `best_tap` and the hero as `best_drag` (Battle HUD Rule 10), and TowerInput keeps its chip open when `pressed` names the chip or the same tower (Tower Rule 8). Each owner records what it needs from `pressed` for the rest of the gesture.
- `became_idle` is always last in its batch and is emitted exactly once per gesture, so an owner that reacted to `pressed` always gets one matching edge (Rule 2).
- Every signal is emitted with `name.emit(...)`, never `emit_signal("name", ...)` (ADR-0006 Decision 1).

### 9. The gesture record and the development gesture log (TR-input-015)

**In the resolver: one value record per gesture, always kept.** `GestureRecord` (`src/foundation/input/gesture_record.gd`, `class_name GestureRecord extends RefCounted`, declares no signal) holds values only:

| Field | Type | Meaning (Rule 13 item) |
|---|---|---|
| `serial` | `int` | gesture number from 1 in this resolver |
| `pointer` | `int` | the active pointer |
| `press_pos`, `end_pos` | `Vector2` | down and up positions; `end_pos` is the release argument, or the last move position on a cancel, or `press_pos` if no move came |
| `moves` | `int` | move calls received while active |
| `max_travel` | `float` | `sqrt` of the largest squared distance from the press point over every move and the release |
| `best_tap`, `best_drag` | `int` | the frozen winners (`NONE` if absent) |
| `tap_sink` | `bool` | `best_tap` was a sink |
| `tap_centre`, `drag_centre` | `Vector2` | the frozen centres (`Vector2.ZERO` if absent) |
| `tap_candidates`, `drag_candidates` | `int` | candidates per class at press |
| `tap_rule`, `drag_rule` | `GestureRecord.WinRule` | `NO_CANDIDATE`, `ONLY`, `PRIORITY`, `DISTANCE`, `ID`: the comparison that last decided the winner ("the rule that chose them") |
| `slop` | `float` | the press's slop (`tap_slop` or `drag_slop`) |
| `outcome` | `GestureRecord.Outcome` | `TAPPED`, `GROUND_TAPPED`, `ROLLED_OFF`, `DRAG_WINNER_ONLY`, `DRAGGED`, `DRAGGED_LOST_MOVES`, `DEAD`, `CANCELLED`, `REPLACED`, `REPRESSED`, or `OPEN` while the gesture is live; the classification and, through it, the signal emitted |

The resolver fills the record at press, updates `moves` and the travel on each call, and finalises `outcome` and `end_pos` in the commit step, before the ending batch is emitted. `last_gesture() -> GestureRecord` returns **a new copy** of the current or last record, so a caller can never keep or mutate the resolver's own. A `became_idle` listener therefore reads the finished gesture. Keeping the record costs a few field writes per call, so the resolver does it in every build and needs no build check; only `last_gesture()` allocates, and only the gesture log and tests call it. `GestureRecord` references no other script, so no cyclic `class_name` reference arises (ADR-0006 V6, ADR-0009 V6).

**Outside the resolver: `GestureLog`, development builds only.** `GestureLog` (`src/presentation/dev/gesture_log.gd`, `extends Node`) is created by `BattleWrapper.attach` only when `OS.is_debug_build()` is true (V7, ADR-0001 V4), and freed with the wrapper. Release builds never create it, so they never write.

- **Wiring.** `GestureLog.attach(resolver, adapter, tower_input, sink)`; the wrapper connects, in `_connect_signals()`, `resolver.pressed` to `GestureLog._on_pressed`, `resolver.became_idle` to `GestureLog._on_became_idle`, and `tower_sim.tower_upgraded` to `GestureLog._on_tower_upgraded` (ADR-0006 P5, which already names the gesture log as its listener). These are extra wrapper connections on allowlisted signals; `detach()` undoes them. It is a view listener under ADR-0006 rule 2: it reads queries, changes nothing, issues no command.
- **Timing.** The resolver stays clock-free (Rule 13). `GestureLog` stamps `Time.get_ticks_msec()` (sourced: ADR-0004 V8) in `_on_pressed` and `_on_became_idle`; hold duration is their difference. Both run inside `flush()`, so times are frame-quantised (about 17 ms at 60 Hz), which the Pillar 4 test does not need finer. `GestureLog` is neither sim code nor a real-time model, so ADR-0004's `engine_time_in_sim` pattern does not cover it; the lint scope must exclude `src/presentation/dev/` for `Time.*` (cascade section a).
- **Device and insets.** `OS.get_model_name()` (V7) and `adapter.field_insets()` and `adapter.field_width_dp()` (ADR-0003), read once per record.
- **Prompt fields.** The Pillar 4 harness story's prompter calls `GestureLog.prompt(expected_action: StringName, expected_target: int)` before each attempt; the log writes both, and the press offset `press_pos - resolver.centre_of(expected_target)` (or the frozen centre when the prompted target won). At each tower prompt it also reads `tower_input.chip_state()` (Rule 13), so Tower needs no log of its own.
- **Output.** One JSON line per gesture (`JSON.stringify` of a `Dictionary` built from the record copy, the stamps and the prompt), plus one line per `tower_upgraded`, written through the injected `sink: Callable` (`write_line(text: String) -> bool`). ADR-0010 owns the file sink it shares with the run log; until it exists the harness story uses a sink that appends to `user://gesture_log.jsonl` with `FileAccess` and checks the `bool` that `store_*` returns (4.4, `breaking-changes.md`). A write failure is reported once through `dev_error` and is never fatal (Data Flow 9).

### 10. What owners get (TR-tower-011, TR-hero-010, TR-hud-008)

The resolver decides no meaning; each owner's GDD does. This ADR guarantees the calls those GDDs rely on:

- **TowerInput** registers each slot and each tower as TAP 200 radius 36, and the chip as TAP 300 radius 40 while a window is open; `set_enabled(slot, false)` when a slot is built; `unregister(chip)` on close. Its `phase_changed` handler (ADR-0006 P1) closes the chip on Paused, an outcome and Fatal, because `cancel()` in Idle emits nothing. It ignores every `tapped` while the injected `halted()` is true. All of these are registry calls or owner logic; all are legal inside its `pressed` and `tapped` handlers.
- **HeroInput** registers the hero as DRAG 200 radius 56, the burst button as DRAG 100 radius 48 and its sink as TAP 400 radius 48 at `burst_button_centre()`. In `update()` (frame step 4, ADR-0004 Decision 5) it calls `set_centre(hero_id, hero position)`; that runs outside any drain, so the next frame's `flush()` tests presses against the hero the player saw. The cancel hysteresis (64 out, 48 back) is HeroInput's own scalar distance test on the `p` of `drag_started`, each `drag_moved` and `drag_ended`, against the button centre it registered; the resolver passes those positions unchanged (Decision 3).
- **HudLogic** registers the arc backdrop (TAP 250, sink, radius 1200) and three arc discs (TAP 300 radius 36) inside its `slot_tapped` handler, which runs inside the resolver's `tapped` batch; they compete from the next press. It calls `set_enabled(start_call, false)` while the arc is open and `true` on close; `unregister` on every arc close; closes on `pressed` when `best_tap` is not one of its discs, on `drag_started`, and on `phase_changed` to Paused, an outcome or Fatal. Start/Call registers on appearing (TAP 350).
- Owners keep ids as `int` fields and compare them with `==`; `NONE` (-1) is never a live id. An owner that unregistered a target ignores later signals naming it.

### 11. Formulas in code

- `inside`: Decision 5. `is_drag` and `is_dead`: Decision 6 (`crossed` against `_slop_sq`). Tie-break: Decision 5.
- **`target_ok`** is a static pure function so criterion 33 tests the production code:

```gdscript
## True when a disc of this radius is at least 48 dp across at this field width.
## Integers only: radius and width floored first, compared without division (Input Formulas).
static func target_ok(radius: float, width_dp: float) -> bool:
    if not (is_finite(radius) and is_finite(width_dp)):
        return false
    return 2 * floori(radius) * floori(width_dp) >= 25920   # 48 * 540
```

`target_ok(36.0, 360.0)` and `target_ok(48.0, 360.0)` are true; `target_ok(35.0, 360.0)` is false. `register` uses it with `FieldMapping.MIN_FIELD_WIDTH_DP` (Decision 4). The runtime width check stays ADR-0003's `FieldMapping.width_supported`; at radius 36 the two agree (`2 * 36 * 360 = 25920`).
- `field_scale` is ADR-0003's (`FieldMapping.field_scale`); the resolver needs no display density.

### 12. Choices made in autonomous mode

Recorded so the user can overturn each one (cascade notes, section d, repeat them):

1. `Battle.resolver` as a read-only member, not a `resolver()` method (Decision 2).
2. `create` takes an optional third argument `dev_error`; bad registrations and non-finite input report through it, falling back to `push_error` (Decision 2).
3. Cancel-then-press runs as two steps in one call, with the new press's hit test after the cancel batch (Decision 6).
4. A runaway cap of 64 calls per drain (Decision 7).
5. `register` reports (but accepts) a radius that fails `target_ok` at 360 dp (Decision 4).
6. `GestureRecord` kept in every build; `GestureLog` stamps time with `Time.get_ticks_msec()` rather than a frame-fed clock (Decision 9).

### Architecture Diagram

```
 InputAdapter (ADR-0003)                      BattleBuilder step 2 (ADR-0001)
   queue ─ flush() at frame step 0              InputResolver.create(drag_slop, tap_slop, dev_error)
   cancel_all() ─► resolver.cancel()             null ─► fatal ; else Battle.resolver
        │ press / move / release / cancel_pointer / cancel (Vector2, field units)
        ▼
 ┌──────────────────────────── InputResolver (RefCounted, pure) ────────────────────────────┐
 │ entry: is_finite check ─► FIFO queue (kind, pointer, Vector2) ─► drain if not draining   │
 │ _run(call): decide ─► COMMIT (state, frozen scalars, GestureRecord) ─► EMIT whole batch  │
 │                                                                                         │
 │ State: IDLE ─press─► PRESSED ─move≥slop─► DRAGGING (drag winner) / DEAD (none)          │
 │        any ─release / cancel / re-press / replacement─► IDLE (+ became_idle last)       │
 │                                                                                         │
 │ Registry: Array[Target] by id {cx, cy, radius, accepts, priority, enabled, sink}        │
 │   register / unregister / set_centre / set_enabled: immediate, never queued             │
 │   no owner reference: owners hold int ids                                               │
 └───┬──────────────────────────────┬───────────────────────────────┬───────────────────────┘
     │ G1 to G6 (inside flush only)  │ G7 drag_cancelled, G8 became_idle (also inside a tick │
     ▼                               ▼  or an engine callback, via cancel)                  │
 HeroInput · TowerInput · HudLogic (wrapper connections, flags 0, ADR-0006)                 │
   registry calls inside handlers; commands from G1 to G6 only                              │
   HeroInput.update() at frame step 4 ─► set_centre(hero)                                   │
                                                                                            ▼
 GestureLog (dev builds only): pressed, became_idle, tower_upgraded ─► last_gesture() copy ─► JSONL sink
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

signal pressed(best_tap: int, best_drag: int, p: Vector2)            # G1
signal tapped(best_tap: int, p: Vector2)                             # G2
signal ground_tapped(p: Vector2)                                     # G3
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)  # G4
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)    # G5, one per move call
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)  # G6
signal drag_cancelled(best_drag: int)                                # G7, may fire inside a tick
signal became_idle()                                                 # G8, last of every exit to Idle

## Construction (Builder step 2 only; tests may use new() through a fake).
static func validate(drag_slop: float, tap_slop: float) -> bool
static func create(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> InputResolver
static func target_ok(radius: float, width_dp: float) -> bool

## Gesture calls: InputAdapter.flush() and tests only. Queued; drained by the outermost call.
func press(pointer: int, pos: Vector2) -> void
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
func cancel() -> void

## Registry: legal in any state and inside handlers; effective at once; never queued.
func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void

## Read-only queries.
func state() -> State
func centre_of(id: int) -> Vector2          # Vector2(NAN, NAN) for an unknown id; logs and tests only
func last_gesture() -> GestureRecord        # a new copy each call; logs and tests only

# src/foundation/input/gesture_record.gd
class_name GestureRecord extends RefCounted
enum WinRule { NO_CANDIDATE, ONLY, PRIORITY, DISTANCE, ID }
enum Outcome { OPEN, TAPPED, GROUND_TAPPED, ROLLED_OFF, DRAG_WINNER_ONLY, DRAGGED,
               DRAGGED_LOST_MOVES, DEAD, CANCELLED, REPLACED, REPRESSED }
var serial: int
var pointer: int
var press_pos: Vector2
var end_pos: Vector2
var moves: int
var max_travel: float
var best_tap: int
var best_drag: int
var tap_sink: bool
var tap_centre: Vector2
var drag_centre: Vector2
var tap_candidates: int
var drag_candidates: int
var tap_rule: WinRule
var drag_rule: WinRule
var slop: float
var outcome: Outcome
func copy() -> GestureRecord

# src/root/battle.gd (addition to ADR-0001, ADR-0003, ADR-0004)
var resolver: InputResolver                 # read-only by contract; set by BattleBuilder step 2

# src/presentation/dev/gesture_log.gd (development builds only)
class_name GestureLog extends Node
func attach(resolver: InputResolver, adapter: InputAdapter, tower_input: Object, sink: Callable) -> void
func detach() -> void
func prompt(expected_action: StringName, expected_target: int) -> void
```

`tower_input` is typed `Object` here until ADR-0010 names the `TowerInput` class; ADR-0010 tightens it. Names are provisional until ADR-0007 settles `class_name` collisions (QQ-16). Every signal carries a `##` doc comment with its ADR-0006 id (G1 to G8), as ADR-0006 requires.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- `InputResolver` must extend `RefCounted` and must never read a node, the scene tree, a viewport, `DisplayServer`, `Input`, `Engine`, `Time`, `OS`, a timer or `await`, or override `_process`, `_input` or `_notification`.
- Production code must create the resolver only with `InputResolver.create(...)`, only in `BattleBuilder.build` step 2, and must call `fatal` and return null when it returns null. `InputResolver.new(` must appear only in `input_resolver.gd` and under `tests/`.
- Only `InputAdapter.flush()` may call `press`, `move`, `release` or `cancel_pointer` in production; owners must never call them. A listener of `drag_cancelled` or `became_idle` must never call any gesture call or command.
- The registry must store values only: never an owner, node, Callable or other object in a `Target` row. Owners must hold their ids as `int` and must clear them (and their resolver reference) in `detach()`.
- The registry must be an `Array[Target]` in ascending id order; it must never be a `Dictionary`; ids must come from a counter that starts at 1 and is never reset or reused.
- Registry calls must take effect at once and must never be queued; gesture calls must always go through the queue.
- Every gesture call must commit its state, frozen fields and gesture record before its first `emit()`, with every argument captured in locals; `became_idle` must be the last signal of every exit to Idle and must be emitted exactly once per gesture.
- The resolver must never call a `Vector2` method or `Vector2` operator in a decision; it must read `.x` and `.y` into `float` and compare squared distances in `float`. It must pass received `Vector2` values to payloads unchanged and never build a payload position from arithmetic.
- Every public method taking a position must drop a non-finite one with `_report` before it changes or queues anything; `register` must return `NONE` for a non-finite centre, a radius that is non-finite or `<= 0`, an `accepts` value other than `TAP` or `DRAG`, or `sink` with `DRAG`.
- Non-fatal breaches must go through the injected `dev_error` (falling back to `push_error`), never `assert` or `print`.
- Signals must be the eight of ADR-0006 with exactly those names and parameter types; must be emitted with `name.emit(...)`; must be connected only by the wrapper with flags 0.
- No `static var` in `InputResolver` or `GestureRecord`; constants only.
- `last_gesture()` must return a new copy; no caller may keep a `GestureRecord` past its handler except as serialised text.
- `GestureLog` must be created only when `OS.is_debug_build()` is true, must never issue a command or write sim state, and must report a sink failure once through `dev_error`, never as fatal.
- Test fakes that extend `InputResolver` must give every override of a typed method an explicit `return` (4.7) and forward `_init` arguments to `super(...)`.

## Alternatives Considered

### Alternative 1: Engine picking (`Area2D` input or `Control` targets)
- **Description**: Each target is an `Area2D` with a `CollisionShape2D` (or a `Control`), and the engine's picking chooses what was hit.
- **Pros**: No hit-test code; shapes edited in the scene.
- **Cons**: Needs a scene, so no headless tests and no equivalence test; the priority order and "frozen at press" would be spread over engine callbacks; picking order, `input_pickable` and touch behaviour on 4.7 are unsourced (HIGH, `architecture.md` Engine Knowledge Gap); ADR-0003 already made every non-modal Control `MOUSE_FILTER_IGNORE`.
- **Estimated Effort**: Lower to write, much higher to test and verify.
- **Rejection Reason**: Breaks TR-input-001 (pure, scene-free) and the GDD's test method.

### Alternative 2: Deferred emission (`call_deferred` or `CONNECT_DEFERRED`) instead of a queue
- **Description**: Emit signals deferred, so nested calls run later in the frame.
- **Pros**: No queue code.
- **Cons**: ADR-0006 forbids deferred connections on battle signals; deferred work runs after frame step 0, so commands from gestures would run after the ticks and the HUD would pay a bonus it did not show (TR-hud-005); order across calls becomes engine-defined.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Contradicts ADR-0006 Decision 2 and ADR-0004 Decision 5.

### Alternative 3: Immediate re-entry (no queue)
- **Description**: A nested `press` or `cancel` runs at once, inside the listener that called it.
- **Pros**: Simplest code.
- **Cons**: Listeners after the caller hear `became_idle` before `pressed` (the GDD's own counter-example, criterion 27); state would change in the middle of a batch whose arguments were already captured.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Violates TR-input-010 and the GDD's logs.

### Alternative 4: Registry rows that hold the owner (callback objects)
- **Description**: `register(owner, ...)`, and the resolver calls `owner.on_tap(...)` instead of emitting signals.
- **Pros**: No id bookkeeping in owners.
- **Cons**: A strong reference from the resolver to wrapper nodes, against ADR-0001's teardown rule; a second delivery path beside ADR-0006's signals, outside the listener-count test; per-owner interfaces would name features in a Foundation class.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Cycle and contract risk; ADR-0006 already fixed signals as the delivery path.

### Alternative 5: `Vector2` maths inside the resolver
- **Description**: Store centres as `Vector2` and use `distance_squared_to`.
- **Pros**: Shorter code; matches the GDD's pseudocode.
- **Cons**: If components are 32-bit (V2), the method computes in 32 bits, against ADR-0004's float policy and ADR-0009's reasoning; boundary results could differ from the 64-bit references the tests compute.
- **Estimated Effort**: Slightly lower.
- **Rejection Reason**: The scalar form costs a few lines and removes the question.

### Alternative 6: `float` pairs in the public API
- **Description**: `press(pointer, x, y)` and payloads with `x, y` pairs.
- **Pros**: No `Vector2` anywhere in input.
- **Cons**: Changes signatures ADR-0003 and ADR-0006 fixed and the registry records; doubles every payload; gains nothing, since the resolver passes positions through unchanged.
- **Estimated Effort**: Higher (edits to two ADRs, the registry and four GDDs).
- **Rejection Reason**: Contradicts registered stances for no gain.

### Alternative 7: A clock in the resolver for the gesture log
- **Description**: The resolver stamps press and release times itself.
- **Pros**: Hold time in one place.
- **Cons**: Breaks Rule 13 ("the resolver itself stays clock-free") and TR-input-001; makes resolver logs time-dependent in tests.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Violates the GDD; the dev-only node can stamp instead.

### Alternative 8: One batch for cancel-then-press
- **Description**: Commit both the cancel and the new press first, then emit `drag_cancelled`, `became_idle`, `pressed` as one batch.
- **Pros**: One commit point per call.
- **Cons**: A registry change a listener makes on that `became_idle` would not reach the new press, which contradicts "effective at once"; the new gesture's state would already be live while listeners still handle the old one's end.
- **Estimated Effort**: Same.
- **Rejection Reason**: The two-step form keeps "commit, then emit" true for each step. Recorded in Decision 12 because the GDD wording admits both.

## Consequences

### Positive
- Every GDD criterion runs headless against the real class, with a recording fake and integer positions.
- No reference from the resolver to any owner or node: retry frees it with the battle, and the weakref proof covers it.
- One queue gives a single, testable rule for nested calls; registry calls stay immediate, so the HUD's arc works as designed.
- The resolver adds no rounding to positions, so the equivalence test compares like with like.
- The gesture log gets every Rule 13 field without a clock or a build flag in the resolver.

### Negative
- Owners must keep and compare ids themselves, and ignore signals for ids they dropped.
- The queue adds three packed arrays and a drain loop to a small class; a defect that presses from every `pressed` handler is cut off after 64 calls rather than looping.
- `Battle.resolver`, the third `create` argument, `state()`, `centre_of()`, `last_gesture()`, `GestureRecord`, `GestureLog` and `target_ok()` are new names other documents must pick up (cascade notes).
- `GestureLog` uses `Time.get_ticks_msec()`, so the `engine_time_in_sim` lint must exclude `src/presentation/dev/`.

### Neutral
- The resolver keeps a gesture record in release builds too (a few field writes per call).
- Positions stay `Vector2` at the API, as ADR-0003 and ADR-0006 fixed.

## Risks
- **`emit()` is not fully synchronous, or a call back into the emitter fails (V1).** Then batches could interleave. Mitigation: V1 runs before acceptance; its branch reopens this ADR and ADR-0006 together.
- **A runtime error inside a listener or inside `_run` leaves `_draining` true.** In GDScript a runtime error aborts the failing function and returns to its caller (ADR-0004 V4 records release behaviour), so the drain loop continues and resets the flag; if V4 shows otherwise in release, every later call would queue forever. Mitigation: the first resolver story adds a test with a listener that errors; development builds stop on the error; if release unwinding differs, `_enqueue` resets `_draining` at entry when the queue is empty.
- **The cap hides a real defect.** Mitigation: `_report` names it, and the test for the cap watches it fire once.
- **Owners forget to unregister** (an arc disc left behind). Mitigation: HUD criterion 14 (arc states) and Tower's chip criterion check registry calls on a fake; `centre_of` lets tests assert absence.
- **A stale id in an owner aliases nothing but still matches a signal** (an owner compares against an id it unregistered). Mitigation: ids are never reused, so the comparison can only match signals for the target it really was, which the GDD says the owner ignores.
- **Adapter `flush()` and `cancel_all()` interleave.** A gesture listener's command can reach `cancel_all()` (through a fatal's `cancel_input()`) while `flush()` is iterating the adapter's queue. The resolver side is safe (the `cancel()` queues behind the current batch); the adapter must tolerate its queue being emptied during `flush()`. Mitigation: cascade note to ADR-0003 (section a) and an adapter unit test.
- **Phone data moves the slops.** Changing them is a data edit; `validate()` bounds stay.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-001: pure, scene-free, clock-free object driven only by `press`, `move`, `release`, `cancel_pointer`, `cancel` | Decision 1 (`RefCounted`, no engine reads), Decision 7 (the five calls are the only gesture inputs) |
| input-gesture-resolver.md | TR-input-007: disc registry `{id, centre, radius, accepts, priority, enabled, sink}`; `register`, `unregister`, `set_centre`, `set_enabled` legal in any state, applied at once | Decision 4 (`Target` rows, never-reused ids, immediate calls, no owner reference), Decision 5 (next press sees changes) |
| input-gesture-resolver.md | TR-input-008: four states, one active pointer, TAP and DRAG winners frozen at press, per-press slop | Decisions 5 and 6 (scalar frozen fields, real-tap-winner slop rule, replacement and re-press rows) |
| input-gesture-resolver.md | TR-input-009: signal API; every exit to Idle emits the idle signal last | Decision 8 (ADR-0006's eight signals, `became_idle` last and once) |
| input-gesture-resolver.md | TR-input-010: state commits before emit; nested gesture calls queue FIFO and drain synchronously in the outermost call | Decision 7 (queue, drain loop, batch definition, registry calls immediate), Decision 6 (two-step cancel-then-press) |
| input-gesture-resolver.md | TR-input-011: slops injected through static `validate()` and a `create()` that returns null; non-finite positions dropped with `push_error` | Decision 2 (`validate`, `create`, Builder step 2 fatal), Decision 7 and Decision 4 (non-finite checks through `dev_error`, falling back to `push_error`) |
| input-gesture-resolver.md | TR-input-015: dev builds carry a gesture-log harness recording device, insets, timing, travel, winners and classification | Decision 9 (`GestureRecord` in the resolver; `GestureLog` node in debug builds; JSONL through a sink) |
| input-gesture-resolver.md | Formulas: inside, is_drag, tie-break, integer `target_ok` | Decisions 5, 6, 11 (`target_ok` static, used by `register` and criterion 33) |
| tower-system.md | TR-tower-011: TowerInput registers slots and the chip disc, disables built slots, closes the chip on phase, ignores taps while halted | Decision 4 (registry calls legal in handlers), Decision 10 (TowerInput's calls; the phase and halted parts are TowerInput logic that needs nothing more from the resolver) |
| hero-system.md | TR-hero-010: HeroInput registers hero DRAG, button DRAG and sink TAP discs, updates the walking hero's centre each frame, hit-tests cancel hysteresis | Decision 10 (registrations; `set_centre` in frame step 4 outside any drain), Decision 3 (positions passed unchanged for HeroInput's own hysteresis test) |
| battle-hud.md | TR-hud-008: the build arc registers and unregisters targets on open and close, disables Start/Call while open, closes on outcome, Paused or Fatal | Decision 4 (`register` inside `tapped` returns at once; `set_enabled`), Decision 10 (HUD calls), Decision 8 (`cancel` emits only G7 and G8, so closing on `phase_changed` is the HUD's) |
| battle-hud.md | TR-hud-009: `pressed` exposes both `best_tap` and `best_drag` so the HUD can ignore a Start/Call tap that also hits the hero | Decision 8 (`pressed(best_tap, best_drag, p)`, both frozen at press) |

## Performance Implications
- **CPU**: A press scans at most about 20 rows once (a few float operations each). A move or release is a constant number of float operations and at most three emits. A typical frame with one finger delivers one to three calls. Well inside the 0.5 ms input slice (ADR-0004 Decision 10, registry `input-and-realtime-models`); unmeasured, like the rest of that slice.
- **Memory**: about 20 `Target` rows, three packed queue arrays that hold at most a few entries, one `GestureRecord`. `last_gesture()` allocates one copy per call, development builds only in practice.
- **Load Time**: none (built with the battle).
- **Network**: none.

## Migration Plan

No code exists, so nothing migrates. Document edits (cascade notes, section a): `architecture.md` B2 (signature of `create`, new reads, internals summary), B4 and B0 (`Battle.resolver`), Module Ownership (InputResolver Consumes and Exposes cells), Data Flow 9 (gesture log); ADR-0001 Builder step 2 (`dev_error` argument, `Battle.resolver`); ADR-0003 Decision 1 (`battle.resolver` replaces the placeholder) and a `flush()` robustness note; ADR-0006 Depends On (`battle.resolver`); ADR-0004's `engine_time_in_sim` lint scope; the Input GDD's `create` signature and Rule 13's harness location. The TR registry and traceability matrix are `/architecture-review`'s.

**Rollback plan**: The resolver is one class plus one value class. Replacing the queue, the cap or the cancel-then-press order changes `input_resolver.gd` and its tests only; the signals, the registry API and `Battle.resolver` stay. Dropping `GestureLog` removes one dev node and three wrapper connections.

## Validation Criteria

1. The GDD's 37 Logic criteria pass as unit tests in `tests/unit/input_gesture_resolver/` with the renamed signals, a recording fake that logs every argument with its type (ADR-0006, ADR-0007), and a recording `dev_error` fake; criteria 19 to 21 also assert the reports.
2. Added tests: `register` inside `became_idle` of a cancel-then-press is a candidate for that new press (Decision 6); a listener that presses on every `pressed` stops at 64 calls with one report and the state `IDLE`; `cancel()` called while not draining emits at once; `last_gesture()` returns a different object each call with equal fields, and mutating it leaves the next copy unchanged.
3. `GestureRecord` fields for criteria 7, 8, 14, 16, 28, 32, 35 and 37 (outcome, winners, rules, travel) match hand-computed values.
4. The ADR-0001 weakref proof reads null for the resolver after a battle with registered targets and connected fakes.
5. ADR-0006's headless test lists the resolver's eight signals under `VIEW_ALLOWLIST` with no headless connection; the wrapper test finds at least one listener on each after `attach` and none after `detach`.
6. Hero criterion 27 (equivalence through the real resolver) gives identical per-tick state.
7. Lint (ADR-0007): no `Vector2` method or operator in `input_resolver.gd`; `InputResolver.new(` only in the resolver file and tests; no `Dictionary` field in the resolver; no `emit_signal(`.
8. Pillar 4 gate P1: the phone-test table computes from `GestureLog` output alone (GDD deferred criterion "Gesture log contents").

## Related
- Depends on: ADR-0003 (adapter, queue, `cancel_all`, field units), ADR-0006 (names, payloads, listener rules). Binding: ADR-0001, ADR-0004, ADR-0009, ADR-0002.
- Enables: ADR-0007, ADR-0010, ADR-0011.
- Design: `design/gdd/input-gesture-resolver.md` (Core Rules 1 to 13, States and Transitions, Formulas, Edge Cases, Acceptance Criteria), `design/gdd/hero-system.md` (Rules 13, 15; criteria 15, 27, 32, 33), `design/gdd/tower-system.md` (Rule 8; TowerInput wiring), `design/gdd/battle-hud.md` (Rules 6 to 11, 14).
- Architecture: `docs/architecture/architecture.md` B2, B3, B9, Data Flow 1, 3, 9.
- Code (once written): `src/foundation/input/input_resolver.gd`, `src/foundation/input/gesture_record.gd`, `src/presentation/dev/gesture_log.gd`, `tests/unit/input_gesture_resolver/`.
