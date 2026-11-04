# ADR-0008: Input Resolver Core and Signal Contract

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories that reference this ADR stay `Blocked` while it is `Proposed`.

TD-ADR: not run per ADR; batch review after all ADRs are written.

## Date

2026-11-04

## Last Verified

2026-11-04 (against the Godot 4.7.2 class reference, tag `4.7.2-stable`, and `docs/engine-reference/godot/`)

## Decision Makers

GDScript specialist (author, orchestrated run against `docs/architecture/architecture.md` v3 and `design/gdd/input-gesture-resolver.md`). Pending: technical-director batch review and user acceptance.

## Summary

Touch gestures must turn into tap, drag and press events for the hero, towers and HUD with zero mis-fires, and the Input GDD defines the rules but leaves the code shape open. This ADR fixes the resolver as a pure `RefCounted` object with a disc registry, a four-state machine, a FIFO queue for calls made inside handlers, payload types, final signal names (closing QQ-07 for the resolver) and a dev-only gesture log.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM (the resolver calls no input API; risk sits in signal and typed-array behaviour listed below) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/input.md`; Godot 4.7.2 class reference fetched from `raw.githubusercontent.com/godotengine/godot/4.7.2-stable/doc/classes/`: `Signal.xml`, `Object.xml`, `RefCounted.xml`, `@GlobalScope.xml`, `Vector2.xml` |
| **Post-Cutoff APIs Used** | None. The 4.7 rule that a typed-return override needs an explicit `return` applies to the resolver fakes in ADR-0007 |
| **Verification Required** | The NOT SOURCEABLE items below, run headless on 4.7.2 before the resolver's first story |

### Sourced from the 4.7.2 class reference

- `Vector2.is_finite()` "returns true if this vector is finite, by calling `@GlobalScope.is_finite` on each component" (`Vector2.xml`). `@GlobalScope.is_finite(x)` is false for NaN and both infinities (`@GlobalScope.xml`).
- `push_error` pushes to the debugger and the OS terminal (`@GlobalScope.xml`). It does not stop the project.
- `Signal.emit` triggers all connected callables and takes any number of arguments; `Signal.get_connections` returns dictionaries with `signal`, `callable`, `flags` (`Signal.xml`).
- A signal connects once to the same `Callable`; a freed callable's object loses its connection (`Object.xml`, `Signal.xml`).
- `RefCounted` instances in a reference cycle are not freed automatically (`RefCounted.xml`).

### NOT SOURCEABLE (blocks Acceptance)

None of these is covered by `docs/engine-reference/godot/` or by the class text above. Until each run is logged in `production/qa/evidence/` with the 4.7.2 build string, this ADR cannot move to Accepted.

1. NOT SOURCEABLE: the order in which one signal calls its listeners (`Signal.xml` and `Object.xml` do not state it). The decision never relies on it: the resolver orders its own emits one after another, and no owner may depend on another owner's handler having run. Run: the headless listener-order test in ADR-0006 (item 1); a failure changes only the test text.
2. NOT SOURCEABLE: that `emit()` on a plain connection returns only after every listener has run, including a listener that calls back into the emitting object. The queue (rule 7) is designed for exactly this case. Run: headless 4.7.2 test with a listener that calls `press()` from `tapped`, asserting the nested call returns before the outer emit does and runs no gesture code itself.
3. NOT SOURCEABLE: whether a typed array of a script inner class (`Array[HitTarget]` with `class HitTarget` inside `input_resolver.gd`) is accepted at 4.7.2. Run: parse and run test in the editor. Fallback: a top-level `class_name InputHitTarget` in its own file (subject to the QQ-16 collision lint).
4. NOT SOURCEABLE: `Vector2` component precision on 4.7 (QQ-05, documented as 32-bit in a stock build but unverified). The GDD requires exact boundary rules: slop exactly equal is a drag, and a press exactly on a disc edge hits. Run: boundary tests whose coordinates are exact in 32-bit floats (such as 3-4-5 triangles with radius 5), on the desktop editor and on the ARM phone run that ADR-0004 schedules. Results go in the QQ-05 record.
5. NOT SOURCEABLE: what happens when a listener connects or disconnects a resolver signal during an emit. Run: headless test shared with ADR-0006 (item 4). Owners connect once at build, before the first press, so the avoidance is in the contract; the run confirms it suffices.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle (the only caller of the five gesture calls; positions arrive in field units; it calls `cancel()` on pause, focus loss and resize); ADR-0006 Battle Signal Contracts and View Allowlist (naming rule, commit-then-emit, listener-count test, typed payloads); ADR-0001 App Lifecycle, Composition Root and Fatal Path (the wrapper builds the resolver, `create()` null calls the failure handler, injected `cancel_input()`, method-Callable-only rule) |
| **Enables** | ADR-0007 (resolver fixtures and fakes), ADR-0010 (HeroInput and TowerInput register discs and bot equivalence), ADR-0011 (HUD draws from these signals) |
| **Blocks** | Every Input & Gesture Resolver story; TowerInput, HeroInput and HUD input stories; the gesture-log story |
| **Ordering Note** | ADR-0006 is accepted first so the naming rule and payload style are settled. The architecture lists ADR-0008 as depending on ADR-0003 and ADR-0006 only; ADR-0001 is added here because the build, null-handling and cancel injection rules come from it. |

## Context

### Problem Statement

The Input GDD fixes behaviour in detail: one pointer, two winners frozen at press, per-press slop, a four-state machine, queued re-entrant calls. It leaves open the code shape: registry storage, how the queue works, the payload types, the signal names that break the past-tense rule (QQ-07), who builds the object, and where the dev gesture log lives. The Pillar 4 phone test needs a gesture log the same week the resolver lands.

### Constraints

- The resolver is a pure, scene-free, clock-free `RefCounted` (TR-input-001). It reads no `Engine`, `Time`, `OS`, camera or display.
- Positions are 540 x 960 field units; the adapter converts (ADR-0003). The resolver handles positions outside the field unmodified.
- Only the adapter drives the five calls; tests drive them directly. Headless bots call the Hero and Tower commands and never reach the resolver (Input Rule 11).
- No autoload. The wrapper builds one resolver per battle and injects it (QQ-20 closed).
- Hit tests run once per press, with about 15 discs registered.
- Math avoids `Vector2` methods that depend on unverified precision (QQ-05). It uses component arithmetic.

### Requirements

- Registry with `register`, `unregister`, `set_centre`, `set_enabled`, legal in any state and effective at once (TR-input-007).
- Four-state machine with frozen winners and per-press slop (TR-input-008).
- Signal API and `idle` last on every exit to Idle (TR-input-009).
- State commits before emit; nested calls queue FIFO and drain in the outermost call (TR-input-010).
- Injected slops, `validate`, `create` returning null, non-finite input dropped with `push_error` (TR-input-011).
- Dev gesture log (TR-input-015).
- Owner contracts for TowerInput, HeroInput and the HUD (TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009).

## Decision

### 1. The resolver is a pure `RefCounted` object

`class_name InputResolver extends RefCounted`, proposed at `src/foundation/input/input_resolver.gd`. The API is B2 of the architecture, copied from the GDD, with the signal names of section 3.

```gdscript
class_name InputResolver extends RefCounted
enum Accepts { TAP, DRAG }
const NONE: int = -1

static func validate(drag_slop: float, tap_slop: float) -> bool
static func create(drag_slop: float, tap_slop: float) -> InputResolver   # null when invalid

func press(pointer: int, pos: Vector2) -> void
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
func cancel() -> void

func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void
```

- `validate` returns false unless both slops are finite, `drag_slop` is in 8 to 30, `tap_slop` is in 16 to 34, and `tap_slop` is above `drag_slop` (GDD Rule 9). The bounds are named constants in this class. The catalogue validator rejects the same cases at load (Data Rule 7); a content test asserts the two bound sets agree.
- `create` calls `validate` and returns null on failure, because a constructor cannot refuse and `assert` is stripped from exports. The wrapper's null result calls the injected failure handler (Flow Rule 18). Nothing else calls `InputResolver.new()` outside tests.
- The resolver holds no reference to any owner, node or Callable. It holds no clock. Signals are its only output.
- The resolver is outside the deterministic sim path: it takes no part in `(catalogue, stage_id, seed, command script)` (Principle 1). Bots skip it.

### 2. Registry

- Storage is an `Array[HitTarget]` in ascending `id` order (NOT SOURCEABLE item 3). `HitTarget` is a small `RefCounted` with `id: int`, `centre: Vector2`, `radius: float`, `accepts: Accepts`, `priority: int`, `enabled: bool`, `sink: bool`.
- `id` comes from a counter that starts at 1 and never reuses a value. `NONE` is -1. A stale id cannot alias a live target.
- Lookup by id is a linear scan over about 15 entries. No Dictionary is used, so no iteration-order question arises.
- `register` returns `NONE` and calls `push_error` unless `radius` is finite and above 0 and `centre` is finite. NaN would otherwise pass a "radius is 0 or less" test. A `sink` on a DRAG target is also refused with `NONE` and `push_error` (the GDD makes `sink` TAP-only and is silent on this call; this is the proposed handling).
- `unregister`, `set_centre` and `set_enabled` on an unknown id do nothing and call `push_error`. `set_centre` with a non-finite position keeps the old centre and calls `push_error`.
- Registry calls are never queued. `register` returns its id at once, because the HUD registers arc discs inside the `tapped` handler. A registry change cannot alter a gesture in flight, because winners and their discs are frozen at press.

### 3. Signals: final names and payloads (closes QQ-07 for the resolver)

| Signal | Payload | Emitted when |
|---|---|---|
| `pressed` | `best_tap: int, best_drag: int, p: Vector2` | Every accepted press, winners may be `NONE` |
| `tapped` | `best_tap: int, p: Vector2` | Release under slop with `best_tap` set and `p` inside its frozen disc (a sink target still emits it) |
| `ground_tapped` | `p: Vector2` | Release under slop with no winner of either class |
| `drag_started` | `best_drag: int, press_pos: Vector2, p: Vector2` | First move at or past slop with a drag winner, or a release at or past slop that stands in for it |
| `drag_moved` | `best_drag: int, press_pos: Vector2, p: Vector2` | Each later `move` call. One per input call, never per frame |
| `drag_ended` | `best_drag: int, press_pos: Vector2, release_pos: Vector2` | Release while dragging |
| `drag_cancelled` | `best_drag: int` | `cancel()` while dragging |
| `became_idle` | none | Last signal of every exit to Idle, cancel included |

Rename decisions:

- `tap` becomes `tapped`, `ground_tap` becomes `ground_tapped`, `idle` becomes `became_idle`. `waves_complete` is ADR-0006's.
- `pressed` stays. It is already past tense, so it needs no change, and no exception is recorded. QQ-07 listed it in error.
- No signal name equals a method name on the class (the Flow `phase` lesson, B5): the methods are `press`, `move`, `release`, `cancel_pointer`, `cancel`.
- IDs are `int`, positions are `Vector2` copies, there are no enum payloads.

### 4. State machine

Four states: Idle, Pressed, Dragging, Dead. The transition table of the GDD (States and Transitions) is the contract and is not repeated here. These implementation rules complete it:

- **Press.** In Idle, `press(i, p)` drops a non-finite `p` with `push_error`. Otherwise it collects every enabled disc that contains `p`, with an edge counting as inside, and keeps the best of each class. Ties break by higher `priority`, then smaller squared distance to the centre, then lower `id`. It stores both winners, each winner's centre and radius, `press_pos`, the active pointer and the press's slop, then emits `pressed`.
- **Press slop.** `tap_slop` when `best_tap` is a real tap target (set and not a sink), or when both winners are `NONE`. `drag_slop` in every other case (a drag winner with no tap winner, or only a sink).
- **Under slop** is `dx*dx + dy*dy < slop*slop` from `press_pos`, computed on components. At or past slop is a drag or Dead. Exactly equal is a drag (NOT SOURCEABLE item 4).
- **Release in Pressed** at or past slop is a final move first (move events lost): `drag_started` then `drag_ended` in one call when a drag winner exists, nothing but `became_idle` otherwise. It is never a tap.
- **Tap test** uses the frozen disc of `best_tap`, not the live registry entry. The finger rolling off the disc gives no signal.
- **Replacement.** A `press` by another pointer while the state is Pressed or Dead and `best_tap` is not a real tap target acts as `cancel()` then `press`. In Dragging, or with a real tap target, it is dropped. A `press` by the active pointer is `cancel()` then `press` in every state.
- **One pointer.** Any other call naming a pointer that is not active is dropped with nothing emitted. `cancel_pointer(i)` acts as `cancel()` only for the active pointer.
- **Dead** ignores moves until the pointer lifts. It emits nothing but `became_idle`.
- **Idle** drops `move`, `release` and `cancel_pointer` (hover moves and focus-return events land here).
- **Every exit to Idle** emits `became_idle` after the gesture's own signal. `cancel()` never synthesises a release.

### 5. State commits before emit

Each call computes its transition, writes all new state (winners, frozen discs, state, active pointer), and only then emits its batch. For cancel-then-press, both transitions commit first, then the cancel batch emits with the arguments captured before the new press committed, then `pressed`. So an owner never hears `became_idle` after the `pressed` that caused it (GDD, States and Transitions).

### 6. Slop and non-finite handling

A non-finite `pos` (checked with `Vector2.is_finite()`, sourced above) makes the call do nothing and call `push_error`, whatever the state. NaN would otherwise hold a press under slop forever and emit a `tapped` at nowhere.

### 7. Re-entrancy queue

- The resolver keeps a private `_draining: bool` and a queue stored as three parallel packed arrays (`kind`, `pointer`, `pos`) plus a head index.
- A public gesture call (`press`, `move`, `release`, `cancel_pointer`, `cancel`) made while `_draining` is true appends to the queue and returns at once. It does not run.
- The outermost call sets `_draining`, runs its own transition and emits its batch, then pops and runs queued calls one at a time in FIFO order, each only after the whole previous batch has reached every listener. It clears the queue and `_draining` when empty.
- A nested `press` from a `tapped` handler therefore starts after that gesture's `became_idle`. A queued `cancel()` from a `pressed` handler means every listener hears `pressed` then `became_idle`, and the real release is dropped in Idle.
- Registry calls are not queued (section 2).
- A runaway handler that queues a call on every call would loop forever. The drain stops at 64 queued calls per outermost call, drops the rest and calls `push_error`. The limit is an addition to the GDD, a safety stop rather than a gameplay value, and a test covers it.
- This depends on NOT SOURCEABLE item 2.

### 8. Owner contracts (TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009)

Owners register and unregister their own discs. The resolver never learns what a target is. Hit radii are named constants on each owner's input object (art bible section 3) and priorities are structural constants, neither tuned. The priority ladder from the GDD is a single reviewed test: burst sink 400, Start/Call 350, build-arc disc 300, upgrade chip 300, arc backdrop 250 (sink), tower and slot 200, hero drag 200, burst button drag 100.

- **TowerInput** (TR-tower-011): registers each slot and tower as TAP 200 (same tier, nearest centre wins) and the chip disc as TAP 300 while a chip is open. It disables a slot with `set_enabled(id, false)` once built, closes the chip on `phase_changed` and on a `pressed` naming anything else, and ignores `tapped` while `halted()`.
- **HeroInput** (TR-hero-010): registers the hero (DRAG 200), the burst button (DRAG 100) and the burst sink (TAP 400). It calls `set_centre` on the hero's disc every frame of a walk and on every pin. The cancel hysteresis (stops over 64 from the button, resumes at 48) is HeroInput's own hit test, not the resolver's.
- **HudLogic** (TR-hud-008): registers arc discs (TAP 300) and one field-wide backdrop (TAP 250, sink) when an arc opens and unregisters them on close. It registers Start/Call (TAP 350) and disables it while an arc is open. It closes the arc on outcome, Paused or Fatal, and on `pressed` unless `best_tap` is one of its discs, so the disc is still registered when its `tapped` builds. It also closes on `drag_started`.
- **Winners on `pressed`** (TR-hud-009): the payload carries both `best_tap` and `best_drag`, so the HUD can ignore a Start/Call tap that also hits the hero.
- An owner that unregisters mid-drag keeps getting that gesture's remaining signals under the old id and ignores them.
- Owners connect their handlers once at build, before the first press (NOT SOURCEABLE item 5).

### 9. Cancel path and lifetime

The resolver exposes `cancel()` and `cancel_pointer()` only. Flow's injected `cancel_input()` (a method Callable on `Battle`, guarded with `is_valid()`) calls `cancel()` on Won, Lost, Paused and Fatal. AppRoot calls it on retry. The adapter calls it on lifecycle events and resize (ADR-0003). A call in Idle does nothing, so double calls are safe by that rule and need no coordination (QQ-19 closed). The wrapper holds the resolver strongly. The resolver holds nothing back, so there is no reference cycle (`RefCounted.xml`). Owners hold the resolver; signal connections do not count as owners (ADR-0006 rule 9).

### 10. Gesture log (TR-input-015)

- `GestureLog` is a dev-only `RefCounted` listener. The wrapper builds and connects it when the dev flag is set (the flag mechanism belongs to ADR-0010's dev telemetry). `BattleBuilder` never builds it, and nothing in a release build references it.
- It connects to the resolver's signals, to `TowerSim.tower_upgraded` and to `HeroSim.burst_started`. Only `burst_started` counts as a burst, because a `drag_ended` from the button may be a cancel (Hero Rule 13).
- It reads `TowerInput.chip_state()` through an injected method Callable at each tower prompt, and takes its timestamps from an injected `now_ms` Callable. The resolver stays clock-free.
- Each record holds device, insets, down and up position and time, hold duration, maximum travel, press offset from the prompted target's centre, both winners and the rule that chose them, classification, the emitted signal, and the `expected_action` and `expected_target` that were prompted. The phone test computes misses and mis-fires from it.
- It writes through an injected line sink. File output belongs to the wrapper. It never changes the result, and a battle with the log removed is identical (Principle 4).
- The log needs the resolver to keep a per-press record of which rule chose each winner. The resolver exposes `last_press_info()`, a read-only copy valid until the next press, only when a log is attached. The method name is proposed.

### Architecture Diagram

```
 InputAdapter (ADR-0003, Node)
      | press / move / release / cancel_pointer / cancel      (field units)
      v
 InputResolver (RefCounted, pure)                <--- register / unregister / set_centre / set_enabled
   registry: Array[HitTarget]                          from TowerInput, HeroInput, HudLogic
   state: Idle | Pressed | Dragging | Dead
   queue: FIFO, drained in the outermost call
      | pressed, tapped, ground_tapped, drag_started/moved/ended/cancelled, became_idle
      v
 TowerInput   HeroInput   HudLogic   GestureLog (dev only)

 Flow.cancel_input() / AppRoot (retry) ---> resolver.cancel()
```

### Key Interfaces

```gdscript
signal pressed(best_tap: int, best_drag: int, p: Vector2)
signal tapped(best_tap: int, p: Vector2)
signal ground_tapped(p: Vector2)
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)       # one per input call
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(best_drag: int)
signal became_idle()                                                    # last signal of every exit to Idle
```

The five calls and the registry are as in section 1. `last_press_info()` is a proposed dev-only read for the gesture log.

### Implementation Guidelines

- The resolver must extend `RefCounted`, must stay free of `Node`, `InputEvent`, `Engine`, `Time`, `OS`, timers and `await`, and must hold no reference to an owner.
- Tests must drive it with the five calls and synthetic positions only.
- Code must build it with `InputResolver.create`, and the wrapper must route a null result to the failure handler.
- Code must compare to `NONE` explicitly and must never test an id for truthiness.
- Code must use component arithmetic for distance tests, not `Vector2` distance methods (QQ-05).
- Every state change must commit before the first emit of that call.
- An owner handler must never call `press`, `move`, `release`, `cancel_pointer` or `cancel` expecting an immediate effect. Such a call is queued.
- An owner must never rely on a registry change affecting the gesture in flight.
- Owners must connect with plain `connect(callable)`, once, before the first press. No `CONNECT_DEFERRED` (ADR-0006).
- An owner must unregister its discs when it closes or is dropped.
- A bot must never call the resolver, except the one equivalence test (ADR-0010).
- The gesture log must never be built in a release build.

## Alternatives Considered

### Alternative 1: Resolver as a `Node` reading `InputEvent`

- **Description**: One node receives events and does hit tests and classification itself.
- **Pros**: One class, no adapter.
- **Cons**: Needs a scene and a viewport to test; couples tests to engine event types; breaks the headless rule.
- **Estimated Effort**: Lower at first
- **Rejection Reason**: TR-input-001 demands a pure object, and the adapter is ADR-0003's.

### Alternative 2: Engine hit tests with `Area2D` or `Control` per target

- **Description**: Each target is a node and the engine says which one is under the finger.
- **Pros**: Less hit-test code.
- **Cons**: Needs the scene tree; winners cannot be frozen; both classes at once and priority-tie rules do not map to engine picking; Controls consume events (ADR-0003).
- **Estimated Effort**: Medium
- **Rejection Reason**: Zero mis-fires needs rules the resolver owns, and they must run headless.

### Alternative 3: Nested dispatch with no queue

- **Description**: A call from a handler runs at once.
- **Pros**: Simple.
- **Cons**: A nested `press` from `tapped` would run before that gesture's `became_idle` and change state under the outer batch. Listeners connected later could hear `became_idle` before the `pressed` that caused it.
- **Estimated Effort**: Low
- **Rejection Reason**: The GDD fixes FIFO batches.

### Alternative 4: Defer nested calls with `call_deferred`

- **Description**: A nested call runs at the end of the frame.
- **Pros**: No queue code.
- **Cons**: Several inputs can arrive in one frame, so the nested call lands after later events; deferred timing is end of frame (`Object.xml`); tests need a frame to pass.
- **Estimated Effort**: Low
- **Rejection Reason**: The queue drains synchronously with known order.

## Consequences

### Positive

- The whole gesture contract runs headless with synthetic positions, including the nested-call and boundary cases.
- A gesture can only fire the target that was on top, in its own class, at press. The frozen winners make that provable.
- Signal names follow the naming rule, so lint can check them.
- The gesture log gives the Pillar 4 phone test its data without a clock in the resolver.

### Negative

- Three GDDs and the architecture text need new names (see GDD Sync).
- The queue adds state (`_draining`, packed arrays) that fakes in ADR-0007 must cover.
- The 64-call drain limit is an addition the GDD did not ask for.
- Exact boundary rules depend on `Vector2` precision, which is open (item 4).

### Neutral

- `pressed` keeps its name.
- Hit radii and priorities stay constants on the owners.
- The resolver is not part of the replay path.

## Risks

- **A handler issues a gesture call and expects it to run now.** Mitigation: the guideline, a fake-owner test that does it from every signal, and the drain-order assertions.
- **Emit does not return before the nested call (item 2).** Mitigation: the run is blocking; the queue design needs it.
- **Boundary rules differ on ARM (item 4).** Mitigation: boundary tests with exact values on both architectures.
- **An owner leaves a disc registered after it closes.** Mitigation: owner tests assert `unregister` on close, outcome, Paused and Fatal (TR-hud-008).
- **Typed inner-class array fails to parse (item 3).** Mitigation: the top-level `class_name` fallback.
- **The gesture log leaks into release.** Mitigation: the wrapper builds it behind the dev flag, and the layer lint (ADR-0007) fails on a reference from `src/foundation/`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-001: pure, scene-free, clock-free object driven only by five calls | Section 1, constraints, guidelines |
| input-gesture-resolver.md | TR-input-007: disc registry with `register`, `unregister`, `set_centre`, `set_enabled`, legal in any state | Section 2 |
| input-gesture-resolver.md | TR-input-008: four-state machine, one pointer, frozen winners, per-press slop | Section 4 |
| input-gesture-resolver.md | TR-input-009: signal API with `idle` last on every exit to Idle | Section 3 with final names (`became_idle`) |
| input-gesture-resolver.md | TR-input-010: state commits before emit; nested calls queue FIFO and drain in the outermost call | Sections 5 and 7 |
| input-gesture-resolver.md | TR-input-011: injected slops, `validate`, `create` returns null, wrapper null calls the failure handler, non-finite positions dropped with `push_error` | Sections 1 and 6 |
| input-gesture-resolver.md | TR-input-015: dev gesture log with winners, classification, upgrades and bursts | Section 10 |
| tower-system.md | TR-tower-011: TowerInput registers slots and chip, disables built slots, closes chip on phase, ignores taps while halted | Section 8 |
| hero-system.md | TR-hero-010: HeroInput registers hero, burst button and sink, moves hero centre each frame, owns hysteresis | Section 8 |
| battle-hud.md | TR-hud-008: arc registers and unregisters on open and close, Start/Call disabled while open, closes on outcome, Paused or Fatal | Section 8 |
| battle-hud.md | TR-hud-009: `pressed` exposes both `best_tap` and `best_drag` | Section 3 |

**GDD sync required.** These texts use names this ADR renames:

```
GDD SYNC REQUIRED
input-gesture-resolver.md (52 mentions), battle-hud.md (8), hero-system.md (3), tower-system.md (2):
  tap          -> tapped
  ground_tap   -> ground_tapped
  idle         -> became_idle      (the signal idle(); other uses of the word "idle" and the state Idle stay)
architecture.md B2 signal block and QQ-07; tr-registry.yaml TR-input-009 text:
  same three renames; pressed is unchanged
```

The counts come from a text search that also matches non-signal uses, so each file needs a read, not a blind replace. This run does not edit those files.

## Performance Implications

- **CPU**: One press tests about 15 discs with a few float operations each. A move is one compare and at most one emit. A queue is touched only on a nested call. No per-frame work and no `_process`.
- **Memory**: One `HitTarget` per disc, a small queue, a few fields. The only allocation per gesture is signal argument passing.
- **Load Time**: None.
- **Network**: None.

No benchmark is claimed. Press cost is small by construction, and a profiler run is the check if a phone shows input lag.

## Migration Plan

No code exists. Order of work: the resolver with its fixtures and a recording fake owner (ADR-0007); the boundary and queue tests; the NOT SOURCEABLE runs; the owner contracts with TowerInput, HeroInput and HudLogic in their own stories; the gesture log last.

**Rollback plan**: If item 2 fails (emit does not return before a nested call), replace the queue trigger with an explicit batch list that each call fills and the outermost call walks, and record the change in a superseding ADR. The public API does not change.

## Validation Criteria

- Every row of the GDD transition table has a unit test with synthetic positions.
- The nested-call tests pass: `press` from `tapped`, `cancel` from `pressed`, and a runaway handler stopped at 64.
- Boundary tests pass on desktop and ARM: slop exactly equal is a drag; a press exactly on an edge hits.
- `create` returns null for each invalid slop pair, and `validate` agrees with the catalogue bounds.
- A non-finite position, radius or centre is dropped with `push_error` and changes no state.
- The priority ladder test passes against the constants on each owner.
- A listener-count test (ADR-0006, ADR-0007) shows the expected connections on every resolver signal.
- Each NOT SOURCEABLE run is logged in `production/qa/evidence/` with the 4.7.2 build string.

## Related

- `design/gdd/input-gesture-resolver.md` (Core Rules, States and Transitions, Edge Cases)
- `design/gdd/battle-hud.md`, `design/gdd/hero-system.md`, `design/gdd/tower-system.md`, `design/gdd/game-state-stage-flow.md`
- `docs/architecture/architecture.md` (B2, B3, B4, Open Questions QQ-05, QQ-07, QQ-16, QQ-19, QQ-20)
- ADR-0001, ADR-0003, ADR-0006 (depend on); ADR-0007, ADR-0010, ADR-0011 (enabled)
- GDD sync: 5 referenced GDD(s) checked by name; renamed signals appear in four of them, listed above.
