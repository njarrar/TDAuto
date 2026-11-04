# ADR-0008: Input Resolver Core and Signal Contract

## Status
Accepted

> Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation. Route: `/architecture-decision accept ADR-0008`.

## Date
2026-11-04

## Last Verified
2026-11-04 (against `docs/engine-reference/godot/` for Godot 4.7.2, `architecture.md` v4, ADR-0001 to ADR-0007 as Accepted, `tr-registry.yaml`, `docs/registry/architecture.yaml`, and the Input, Tower, Hero and Battle HUD GDDs by section; revised after godot-specialist and TD-ADR reviews)

## Decision Makers
- Accepted: 2026-11-04 by the user (njarrar), with the dated ADR-0006 and ADR-0007 amendments
- Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`, 2026-11-04)
- godot-specialist: CONCERNS. TD-ADR: CONCERNS. Findings resolved under Reviews.
- Acceptance: the user, who also confirms the ADR-0006 and ADR-0007 amendments.

## Summary
The Input GDD defines a pure gesture resolver, and ADR-0003 and ADR-0006 fix its caller and signal names, but no ADR fixes its class, registry, state machine, queue, payloads or the dev gesture log. This ADR decides a clock-free `InputResolver extends RefCounted` built by `create()`, a disc registry with a total tie-break, a four-state machine with frozen winners, a FIFO queue drained in the outermost call, typed payloads for all eight signals, a `GestureTrace` per gesture, and a debug-only `GestureLog` harness.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript) |
| **Domain** | Input (pure core; no engine input API) and Core (signals) |
| **Layer** | Foundation (`InputResolver`, `GestureTrace`); the `GestureLog` harness is Presentation |
| **Knowledge Risk** | MEDIUM. Only 4.0-era features: `RefCounted`, typed `signal`, `emit()`, `enum`, `is_finite`, `push_error`, `Vector2` storage. `breaking-changes.md` lists no 4.4 to 4.7 change to them, but no reference file covers signals or float storage, so probes R1 to R6 check them. All six are verified 4.7.2 headless and match (`docs/engine-reference/godot/probe-results.md`). `modules/input.md` covers no touch API; none is used (ADR-0003 owns events). |
| **References Consulted** | `VERSION.md`; `modules/input.md`; `breaking-changes.md` (4.7 typed-return overrides); `deprecated-apis.md`; `current-best-practices.md` (rest parameters, lambda capture). `architecture.md` v4 (B2, Data Flow 1, 3, 9, Required ADRs); `tr-registry.yaml`; ADR-0001, ADR-0003, ADR-0004, ADR-0006, ADR-0007 |
| **Post-Cutoff APIs Used** | None in `src/`. Fakes use 4.5 rest parameters and follow the 4.7 typed-override rule. |
| **Verification Required** | Probes R1 to R6 are verified 4.7.2 headless (`docs/engine-reference/godot/probe-results.md`); all match. They still become CI tests (ADR-0007 Decision 7). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Builder creates the resolver; `Battle.input_resolver`; null `create()` goes to `fatal("input_record_invalid")`; three `cancel()` callers; method Callables). ADR-0003 (the adapter makes the five calls in field units; TapScreens are Controls). ADR-0004 (input commands at frame step 0; float policy; no clock in sim folders). ADR-0006 (names, INPUT role, commit before emit, `int` runtime IDs). ADR-0007 (helpers, `EventLog`, lints). All Accepted. |
| **Enables** | ADR-0010 (HeroInput and TowerInput meaning, bot equivalence, the JSONL sink the log shares with RunLog) |
| **Blocks** | Every story that builds the resolver, registers a target or listens to a resolver signal. No story exists yet. |
| **Ordering Note** | ADR-0003's spike S0a gates adapter stories, not resolver unit stories. |

## Context

### Problem Statement
Every MVP verb passes through one resolver. The GDD states its rules, and B2 sketches its API, but open points remain: payloads (ADR-0006 left them here), the queue and its bound, tie-break and bad-input rules, what a "real tap winner" is in code, and how the Rule 13 log gets data no signal carries. A wrong choice turns a miss into a mis-fire, which spends gold or moves the hero without consent (Pillar 4).

### Constraints
Pure and clock-free; `Vector2` as storage only (ADR-0004 Decision 9, L-VEC-1); sync emit, commit before emit, `push_error` not `assert` (ADR-0001, ADR-0006); one thread, where `cancel()` also comes from Flow inside a tick or mid-drain and from AppRoot at teardown.

### Requirements
TR-input-001, 007, 008, 009, 010, 011, 015, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009, and the disc part of TR-input-013 (ADR-0003 sync item A2).

## Decision

### 1. Class and factory (TR-input-001, TR-input-011)
- `class_name InputResolver extends RefCounted`, `src/foundation/input/input_resolver.gd`. It holds no battle object and calls no injected Callable.
- `static func create(drag_slop, tap_slop) -> InputResolver` returns `null` unless `validate()` is true. Nothing but `create()` and tests calls `InputResolver.new()` (L-INPUT-6).
- `static func validate(drag_slop, tap_slop) -> bool`: both `is_finite`, `DRAG_SLOP_MIN <= drag_slop <= DRAG_SLOP_MAX` (8, 30), `TAP_SLOP_MIN <= tap_slop <= TAP_SLOP_MAX` (16, 34), `tap_slop > drag_slop`. Plain float compares, no epsilon; 15.99 fails (GDD AC 19). The bounds are invariants; a test checks they equal the Input record's schema domains (ADR-0002).

### 2. Registry (TR-input-007, TR-input-013 disc part)
- A target holds `id: int`, `centre: Vector2`, `radius: float`, `accepts: Accepts`, `priority: int`, `enabled: bool`, `sink: bool`, one private inner object each, in an `Array` in id order. About 15 MVP discs make a linear scan the cheapest choice.
- `register(...)` returns the next id from a counter that starts at 1 and never reuses a value. It returns `NONE` with `push_error`, uses no id and stores nothing, when: a `centre` component is not finite; `radius` is not finite or not above 0; `accepts` is neither `TAP` nor `DRAG` (required: GDScript does not check an enum argument's value); or `sink` is true with `DRAG`.
- `unregister`, `set_centre`, `set_enabled` act at once. An unknown or removed id is a no-op with `push_error`. `set_centre` with a non-finite component keeps the old centre, with `push_error`.
- All four are legal in every state and inside any owner handler, and are never queued. They never change the gesture in flight (Decision 3).
- **Hit test**: a candidate is `enabled` and `dx * dx + dy * dy <= r * r` (`dx = p.x - c.x`, `dy = p.y - c.y`), inclusive, in 64-bit `float`.
- **Tie-break within a class**: higher `priority`, then smaller squared distance, then lower `id`. TAP and DRAG never compete.
- **Discs, not Controls**: the burst button and its sink, Start/Call, the arc discs and backdrop, the chip, towers, slots and the hero are registry discs drawn by field views. ADR-0003 holds the Control part (L-INPUT-2).
- The resolver never stores a computed `float` in a `Vector2` field it later compares; frozen discs and press positions are kept as `float` scalars.

### 3. State machine (TR-input-008)
- `enum State { IDLE, PRESSED, DRAGGING, DEAD }`; `state()` is a read-only query for tests and the log (L-INPUT-7).
- Per gesture, all as scalars: active pointer, press x and y, `best_tap`, `best_drag`, the frozen tap disc (cx, cy, r), `real_tap` (best tap exists and is not a sink), squared press slop, and the trace counters (Decision 7).
- **Press slop**: `tap_slop` with a real tap winner or no winner at all; else `drag_slop`. Crossing is `>=`.
- The transition table is the Input GDD's States and Transitions table, with ADR-0006 names. Code-level wording:
  - In Pressed, Dragging and Dead, a call from another pointer is dropped, except a press when the gesture is **replaceable** (Pressed or Dead with no real tap winner).
  - A replaceable gesture, or any re-press of the active pointer, is replaced as `cancel()` then `press` in one call.
  - **Replacement order (deliberate choice)**: the whole cancel runs first (commit to Idle, build the trace, emit `drag_cancelled` from Dragging, then `became_idle`), then the new press does its hit test, commits and emits `pressed`. So a `became_idle` handler reads the old trace, and a registry change it makes (say, disabling a target) applies to the replacing press. The GDD's "arguments captured before the new press commits" holds with no copy.
  - `cancel_pointer(i)` is `cancel()` for the active pointer, else dropped. Idle drops `move`, `release`, `cancel_pointer`; `cancel()` in Idle emits nothing.
  - Once Dragging, never Pressed again. A release at or past slop in Pressed gives `drag_started` then `drag_ended` with a drag winner, else nothing. Never a tap.
  - The tap test at release uses the frozen disc with no `enabled` term.
- Every exit to Idle emits `became_idle()` last; Idle-to-Idle emits nothing.

### 4. Commit, emit and the queue (TR-input-010)
- Each step commits every field, the trace included, before its first `emit`. Its signals, `became_idle()` included, form one batch delivered whole before the next queued call runs.
- The five gesture calls go through `_submit(op, pointer, pos)`. If not draining, it sets `_draining`, runs the op, runs queued ops FIFO until none is left, then clears the queue and the flag. If draining, it appends and returns at once. Nothing is deferred.
- **Dev guard**: at most `MAX_QUEUED_PER_DRAIN := 64` `press`, `move`, `release` and `cancel_pointer` ops per drain; one more is dropped with `push_error`. `cancel()` is never counted and never dropped. No legal chain nears 64; the guard turns a handler loop into a dev error.
- A non-finite position is dropped at `_submit`, before queueing, with `push_error`.
- A `cancel()` that arrives mid-drain (a command in a handler raises a fatal, and Flow calls `cancel_input()`) queues and runs after the batch.
- **Stuck-drain recovery**: the resolver counts open emits in `_emitting`. A `cancel()` that finds `_draining` true and `_emitting` 0 means no handler is running, so the drain died (R2b). It reports with `push_error`, clears the queue and the flags, then cancels as usual.
- The queue is a plain `Array` cleared at the end of each drain; it may allocate. A drain is rare and short.

### 5. Signal payloads (TR-input-009, TR-hud-009)
IDs are `int`, positions `Vector2` in field units, both copied by value. Names and types go into `battle_signals.gd` as the eight INPUT rows. Godot does not check these types at `emit()`; the V2 `typeof()` recorder is the only type check (ADR-0006 E2).

| Signal | When |
|---|---|
| `pressed(best_tap: int, best_drag: int, press_pos: Vector2)` | Idle to Pressed; either winner may be `NONE`; a sink may be `best_tap` |
| `tapped(target: int, release_pos: Vector2)` | Release under slop inside the frozen tap disc |
| `ground_tapped(release_pos: Vector2)` | Release under slop, no winner at all |
| `drag_started(target: int, press_pos: Vector2, pos: Vector2)` | First move at or past slop with a drag winner, or a lost-move release |
| `drag_moved(target: int, press_pos: Vector2, pos: Vector2)` | Each later move while Dragging; one per call |
| `drag_ended(target: int, press_pos: Vector2, release_pos: Vector2)` | Release while Dragging; unclamped |
| `drag_cancelled(target: int)` | `cancel()` while Dragging |
| `became_idle()` | Last signal of every exit to Idle |

### 6. What listeners may do (narrows ADR-0006's INPUT role for two signals)
- Listeners are HeroInput, TowerInput, HudLogic, GestureLog and test fakes, through `view_wiring` with flags 0. Headless, none (ADR-0006 V1).
- From `pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved` and `drag_ended`, owners may command (ADR-0006 guard applies).
- From `drag_cancelled` and `became_idle`, owners must never command. Both are cleanup edges. `became_idle` ends every gesture and can run inside a Flow tick or at AppRoot teardown; ADR-0006's guard covers the tick but not teardown, and no GDD owner needs a command there. Enforced by V12, not by lint.
- Any owner handler may call the four registry methods. No listener calls a gesture method; only resolver fixtures do, and the queue keeps them correct.
- A handler that calls `cancel()` gets control back at once; `state()` reads the old state until the batch ends.
- Listeners never rely on their order.

### 7. Gesture trace (TR-input-015, resolver side)
Rule 13 needs facts no signal carries: travel under slop, the end of a silent gesture, and why a winner won.
- `class_name GestureTrace extends RefCounted`, `src/foundation/input/gesture_trace.gd`. Fields: `pointer`, `press_pos`, `end_pos` (last accepted position), `max_travel_sq`, `press_slop`, `best_tap`, `best_drag`, `tap_is_sink`, `tap_rule`, `drag_rule`, `outcome`.
- `enum Rule { NONE, ONLY, PRIORITY, DISTANCE, ID }` (the first tie-break term that decided). `enum Outcome { TAPPED, ROLLED_OFF, GROUND_TAPPED, DRAG_ONLY_RELEASED, DRAG_ENDED, DRAG_CANCELLED, DEAD, CANCELLED, REPLACED }`.
- The resolver keeps running values in its own scalars and builds the trace once, from `_init` arguments, at the exit to Idle, before `became_idle()`. So `last_trace()` always returns a finished trace (the previous gesture's while one is live), or `null` before the first. Read-only holds by L-INPUT-7 and review, not by the language.
- It runs in every build: one small object per gesture.

### 8. Gesture log harness (TR-input-015, harness side; Data Flow 9)
- `class_name GestureLog extends RefCounted`, `src/presentation/dev/gesture_log.gd`. Shipped but never built in release: the BattleWrapper builds it only when `OS.is_debug_build()` is true. The file stays in the pck and the wrapper may name it statically; an export preset filter is not chosen.
- `setup(resolver, device, insets, now_ms, append_line, chip_state, dev_error)`, all method Callables. `now_ms` wraps `Time.get_ticks_msec` (tests inject a fake); `append_line(line: String) -> bool` is ADR-0010's JSONL sink to `user://gesture_log.jsonl`; `chip_state` is TowerSim's read.
- Listens through `view_wiring` to the eight resolver signals and TowerSim's `tower_upgraded`. View-only: no command, registry or gesture call, no kept payload object.
- `set_prompt(action: StringName, target: int, target_centre: Vector2)` comes from the phone-test prompter; a tower prompt reads `chip_state()` then.
- In its `became_idle` handler it writes one JSON line holding every Rule 13 field (Input GDD), plus `press_slop` and `tap_is_sink`, from `last_trace()`, its own times and the prompt. Each `tower_upgraded` gives one line.
- A false `append_line` reports once to `dev_error`; logging goes on, and the battle is never touched.

### 9. Owner registration rules (TR-tower-011, TR-hero-010, TR-hud-008)
Radii, offsets and priorities come from the owner GDDs' tables (Input GDD priority table; Tower Rule 8; Hero Interactions; HUD Rules 6, 9, 11 and layout table). The rules:
- **TowerInput**: each slot and tower is one TAP disc, no sink, registered at battle start. The chip is one TAP disc, registered when the chip opens, unregistered on close and from its `phase_changed` handler. Its `tower_built` handler calls `set_enabled(slot, false)`. It ignores taps while `halted()` is true.
- **HeroInput**: the hero is a DRAG disc, the burst button a DRAG disc and its sink a TAP sink, all at battle start. `update()` (frame step 1) calls `set_centre(hero, ...)` while the hero walks. Cancel hysteresis is its own scalar test on drag positions.
- **HudLogic**: Start/Call is one TAP disc, no sink, registered when the button appears (HUD Rule 11), unregistered when hidden, and disabled with `set_enabled` while an arc is open. Its `slot_tapped` handler (inside TowerInput's `tapped` handler) registers the arc backdrop (TAP sink) and three discs (TAP); they compete from the next press. It unregisters them on `pressed` naming another best tap, on `drag_started`, and from its `phase_changed` handler on Paused, an outcome or Fatal.

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
const MAX_QUEUED_PER_DRAIN := 64     # dev guard; cancel() exempt

static func validate(drag_slop: float, tap_slop: float) -> bool
static func create(drag_slop: float, tap_slop: float) -> InputResolver   # null when invalid

func press(pointer: int, pos: Vector2) -> void           # adapter only
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
func cancel() -> void                                    # adapter, Flow cancel_input(), AppRoot

func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void

func state() -> State                                    # L-INPUT-7 scope only
func last_trace() -> GestureTrace                        # L-INPUT-7 scope only

signal pressed(best_tap: int, best_drag: int, press_pos: Vector2)
signal tapped(target: int, release_pos: Vector2)
signal ground_tapped(release_pos: Vector2)
signal drag_started(target: int, press_pos: Vector2, pos: Vector2)
signal drag_moved(target: int, press_pos: Vector2, pos: Vector2)
signal drag_ended(target: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(target: int)
signal became_idle()

class_name GestureTrace extends RefCounted
enum Rule { NONE, ONLY, PRIORITY, DISTANCE, ID }
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
var tap_rule: Rule
var drag_rule: Rule
var outcome: Outcome

class_name GestureLog extends RefCounted   # src/presentation/dev/; built only in debug builds
func setup(resolver: InputResolver, device: String, insets: FieldInsets, now_ms: Callable,
           append_line: Callable, chip_state: Callable, dev_error: Callable) -> void
func set_prompt(action: StringName, target: int, target_centre: Vector2) -> void
```

### Implementation Guidelines
1. `InputResolver` must extend `RefCounted` in `src/foundation/input/` and never touch a `Node`, scene, input event, `Time`, `Engine`, `OS`, `Timer` or `await` (L-TIME-1, L-LAYER-1).
2. Resolver maths must use `float` scalars, never `Vector2` operators or methods, and no `sqrt` (L-VEC-1).
3. Game code must build a resolver only through `create()` (L-INPUT-6).
4. Every step must commit all fields before its first emit (Decision 4).
5. A call made mid-drain must be queued, never nested or deferred (Decision 4).
6. Non-finite positions and bad `register` input must be refused with `push_error` (Decisions 2, 4).
7. Ties must break by priority, squared distance, then id, within a class (Decision 2).
8. Winners and the tap disc must be frozen at press (Decision 3).
9. Every exit to Idle must end with `became_idle()` (Decision 3).
10. A replacing press must run the whole cancel before the press (Decision 3).
11. Owners must never command from `drag_cancelled` or `became_idle` (Decision 6).
12. Only the adapter may make gesture calls; only the adapter, Flow's `cancel_input()` and AppRoot may call `cancel()` (L-INPUT-6).
13. Only `src/foundation/input/`, `src/presentation/dev/` and tests may call `last_trace()` or `state()` or name `GestureTrace` (L-INPUT-7).
14. The wrapper must build `GestureLog` only when `OS.is_debug_build()`; it must stay view-only.
15. Every resolver signal must have a `battle_signals.gd` row.
16. Resolver tests must drive the five calls with synthetic positions into ADR-0007's `EventLog`, with no input event, scene or timer.

## Alternatives Considered

### Alternative 1: Engine picking (`Area2D`, `input_pickable`)
Needs a scene and engine events, so no headless test; picks by tree and z order, not per-class priority; no frozen discs. Rejected: breaks TR-input-001 and the provable zero mis-fire rule.

### Alternative 2: Targets as `Control`s
GUI order is not the priority table, a Control over the field swallows presses (ADR-0003), and 4.6 dual focus adds risk. Rejected: TR-input-013 and ADR-0003 require discs.

### Alternative 3: Each owner hit-tests the five calls
Puts priority in four places, and two owners can act on one press. Rejected: the GDD makes the registry the one owner of priority.

### Alternative 4: `call_deferred` instead of a queue
Lands after `_process`, past the frame's ticks, and ADR-0006 Decision 1 bans it.

### Alternative 5: Gesture log from signals alone
Sub-slop moves, silent endings and tie-break rules emit nothing, so the P1 table could not be computed.

### Alternative 6: Unbounded queue
A handler loop hangs the game with no error; the dev guard costs legal chains nothing.

## Consequences

### Positive
- The rule set runs headless; GDD AC 1 to 37 map one to one to tests, and the same calls give the same log every run.
- A gesture reaches only the target on top in its class at press, so zero mis-fires is provable.
- The phone test gets every Rule 13 field with no clock in the resolver and no Tower log.

### Negative
- `state()`, `last_trace()` and `GestureTrace` go beyond B2; L-INPUT-7 keeps owners off them.
- The no-command rule for two signals rests on one integration test (V12).
- ADR-0006 and ADR-0007 carry dated amendments; GDD and architecture.md need sync passes.

## Risks
- **R1 differs** (a nested call runs before the outer emit's next listener): the queue prevents nesting; record it.
- **R2a differs** (a handler error stops `emit` reaching later listeners): listeners must not assume delivery after a broken handler; the resolver's own flags are unaffected.
- **R2b** a runtime error inside the resolver's own op code mid-drain may leave `_draining` true, so every later call queues and input dies. Recovery: the next `cancel()` from Flow or AppRoot clears it (Decision 4, V11); a retry builds a new resolver.
- **R3 differs** (32-bit storage rounds integer positions, or loses NaN or INF): tests use integers below 2^24; if NaN or INF does not survive, non-finite tests use `float` inputs and the adapter's own check guards.
- **Dev guard hit in play**: a handler bug; the dev error names it.
- **A replacing press lets a palm steal an unmoved hero or burst press**: kept by design; the phone test watches it.
- **Adapter guarantees** rest on ADR-0003's spike; a stranded gesture recovers on the next press of that index.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-001: pure, scene-free, clock-free, five calls | Decision 1; Guidelines 1, 2, 16. Full |
| input-gesture-resolver.md | TR-input-007: disc registry; registry calls in any state, at once | Decision 2. Full |
| input-gesture-resolver.md | TR-input-008: four states, one pointer, frozen winners, per-press slop | Decision 3. Full |
| input-gesture-resolver.md | TR-input-009: signal API; `became_idle()` last | Decisions 3, 5. Full |
| input-gesture-resolver.md | TR-input-010: commit before emit; FIFO queue in the outermost call | Decision 4. Full |
| input-gesture-resolver.md | TR-input-011: `validate()`, `create()` null; non-finite dropped | Decisions 1, 2, 4. Full |
| input-gesture-resolver.md | TR-input-013: targets are discs, HUD Controls first | Decision 2. Partial, shared with ADR-0003 (Control part) |
| input-gesture-resolver.md | TR-input-015: dev gesture log with every Rule 13 field | Decisions 7, 8. Partial until ADR-0010 decides the sink |
| tower-system.md | TR-tower-011: TowerInput registers slots and chip, disables built slots, closes chip on phase, ignores taps while halted | Decisions 2, 6, 9. Full |
| hero-system.md | TR-hero-010: hero DRAG, button DRAG, sink TAP; centre each frame; hysteresis hit test | Decisions 2, 5, 9. Full |
| battle-hud.md | TR-hud-008: arc registers and unregisters, disables Start/Call, closes on outcome, Paused, Fatal | Decisions 2, 6, 9. Full |
| battle-hud.md | TR-hud-009: `pressed` carries both winners | Decision 5. Full |

## Performance Implications
- **CPU**: per press one pass over about 20 discs; per move one squared distance. Frame step 0, outside the tick slice; unmeasured, no budget row.
- **Memory**: under 4 KB. **Load Time**, **Network**: none.

## Migration Plan
No code exists. On acceptance:
1. **Amendments** (dated 2026-11-04, confirmed by the user at acceptance): ADR-0007 gains L-INPUT-6, L-INPUT-7 and the registry logging in `recording_resolver.gd`; ADR-0006's INPUT role row notes the narrowing (Decision 6). Fakes that override a typed method (`register() -> int`, `state() -> State`, `last_trace() -> GestureTrace`) return a value on every path or call `super` (4.7); fakes on `became_idle` use `func(...args)`.
2. **Signal table**: eight INPUT rows in `battle_signals.gd` (Decision 5).
3. **GDD sync** (game-designer; not made here):
   - Input GDD: ADR-0006 renames; parameter names (`p` to `press_pos`, `release_pos`, `pos`; winners to `target`); Rule 9 adds the DRAG-sink and bad-`accepts` rejects; Rule 11 says the Builder builds the resolver (ADR-0001); Rule 13 names `GestureTrace` and `last_trace()`; States and Transitions: the line 115 sentence ("A cancel-then-press row emits its cancel signals with arguments captured before the new press commits") becomes "the whole cancel runs, then the new press" (Decision 3), and the dev guard is noted; AC preamble points to `tests/helpers/fakes/`.
   - Hero GDD Rule 13: no command from `drag_cancelled` or `became_idle`.
   - Tower GDD Rule 17 and log rows: `GestureLog`, `set_prompt`.
   - Battle HUD GDD: ADR-0006 names.
4. **architecture.md** (not made here): B2 takes Key Interfaces; Module Ownership InputResolver row and RunLog / GestureLog row (log decided here, sink ADR-0010); Data Flow 9 reads `last_trace()` in `became_idle`; Required ADRs: ADR-0008 written, Proposed, and TR-input-015 (sink part) added to ADR-0010's Covers as shared; B2's QQ-07 note removed.

## Validation Criteria
Unit tests in `tests/unit/input_gesture_resolver/` (names proposed), shared fakes from `tests/helpers/`; each THEN is the whole `EventLog`. Errors are claimed with `await assert_error(callable).is_push_error(msg)` (ADR-0007 Decision 5).
- **V1**: Input GDD AC 1 to 37, with ADR-0006 names, one test each.
- **V2 payload types**: each signal once; the recorder checks count and `typeof()` per argument against `battle_signals.gd`; no `type_errors()`.
- **V3 replacement**: a `became_idle` listener during a replacing press reads `outcome == REPLACED` and the old `press_pos`; a listener that disables the new press's target there makes the replacing `pressed` name `NONE` for it.
- **V4 dev guard**: on pointer 0, a listener that re-presses pointer 0 from every `pressed` gives 1 + 64 `pressed` entries and one claimed `push_error`, and returns.
- **V4b cancel exempt**: fill the guard as in V4, then a listener queues `cancel()`; it runs, and the log ends `became_idle`.
- **V5 queued cancel**: `cancel()` inside `pressed` gives `pressed, became_idle` to every listener in order; a later release adds nothing (AC 27).
- **V6 register rejects**: radius 0, -1, NAN, INF; centre with NAN or INF; `2 as InputResolver.Accepts`; DRAG with `sink`. Each returns `NONE` with one `push_error`; the next id is unchanged.
- **V7 trace**: for a tap, roll-off, ground tap, drag, cancel and Dead press, each field matches; a trace held from gesture 1 is unchanged after gesture 2; `last_trace()` mid-gesture returns the previous trace.
- **V8 bounds**: the four slop `const`s equal the schema domains.
- **V9 GestureLog** (fake clock and sink): a tap, a drag and a cancel give three lines with every Rule 13 field; `tower_upgraded` gives one; a false sink gives one dev error and logging goes on.
- **V10 lints**: L-INPUT-6 and L-INPUT-7 fail on planted samples.
- **V11 stuck drain**: set `_draining` true with `_emitting` 0; `cancel()` reports one `push_error`, empties the queue and leaves Idle; the next press works.
- **V12 no command from cleanup edges** (integration): with fakes on `drag_cancelled` and `became_idle` that would command, `cancel()` from Dragging inside a tick, outside a tick, and at teardown issues no command; the real owners' handlers log none.
- **Engine probes** (`tests/unit/engine/resolver_probes_test.gd`, proposed). Every answer below is verified 4.7.2 headless, see probe-results.md; each probe still becomes a CI test, with results recorded in `docs/engine-reference/godot/` with date and version.
  - **R1** a call made inside a handler returns before `emit()` calls the next listener. Verified 4.7.2 headless: yes.
  - **R2a** a runtime error in one handler: `emit()` still calls later listeners and returns. Verified 4.7.2 headless: yes, in a debug build.
  - **R2b** a runtime error in the emitter's own function mid-loop aborts that function only, and its caller goes on. Verified 4.7.2 headless: yes.
  - **R3** `Vector2(306.0, 480.0).x == 306.0`; `is_nan(Vector2(NAN, 0.0).x)`, `is_inf(Vector2(INF, 0.0).x)`. Verified 4.7.2 headless: all true (probe R3a; R3b also checks the slop edge at 36 units).
  - **R4** `is_finite()` false for NAN, INF, -INF; true for 0.0. Verified 4.7.2 headless: yes.
  - **R5** an `int` signal parameter reports `TYPE_INT` in `get_script_signal_list()`. Verified 4.7.2 headless: yes.
  - **R6** `2 as InputResolver.Accepts` passes into a typed `Accepts` parameter with no error. Verified 4.7.2 headless: yes (so do `99` and an untyped `Variant` 7), so Decision 2's check is required.

## Reviews

godot-specialist: **CONCERNS** (none blocking). TD-ADR: **CONCERNS**. All findings relayed were applied.

| Finding | Resolution |
|---|---|
| T1 L-INPUT-7 scope | Exempts `src/foundation/input/`; adds `state(` |
| T2 cap must not drop `cancel()` | Cap counts four ops only; `cancel()` exempt; V4b; "dev guard" |
| T3 no-command reason | Restated as cleanup edges; teardown not guarded; narrows ADR-0006; V12, no lint |
| T4 replacement order | Named a deliberate choice; GDD line 115 in sync; V3 extended |
| T5 TR coverage | Tower and Hero Full; TR-input-013 and 015 Partial; ADR-0010 sync item |
| T6 `chip_state()` owner | TowerInput, which owns `ChipWindow` (Tower GDD Rules 8 and 17); settled 2026-11-04 after review, architecture.md moved to match |
| T7 Decision 9 values | Rules only; GDD tables cited; Start/Call registration added |
| T8, G5 enum not checked | V6 uses `2 as InputResolver.Accepts`; check required; R6 |
| T11 trace fields | `candidates` dropped; `Rule` enum |
| T12 trims | Applied; diagram dropped |
| G2 typed overrides in fakes | Migration Plan 1 |
| G3 stuck drain | Recovery by outermost `cancel()`; V11; R2b |
| G4 allocation claim | Claim dropped; plain `Array` |
| G6 emit checks no types | Decision 5 |
| G8 float in `Vector2` | Decision 2, last line |
| G10 cancel from a handler; V4 pointer; error capture | Decision 6; V4; Validation preamble |
| G12 trace built at exit | Decision 7 |
| G13 shipped, never built | Decision 8 |
| G16 resolver-internal error | R2b |

## Related
- Depends on ADR-0001, ADR-0003, ADR-0004, ADR-0006, ADR-0007 (Accepted). Narrows ADR-0006's INPUT role for `drag_cancelled` and `became_idle`, and amends ADR-0006 and ADR-0007 (confirmed 2026-11-04). Enables ADR-0010.
- GDDs: `design/gdd/input-gesture-resolver.md` (primary), `tower-system.md`, `hero-system.md`, `battle-hud.md`. Sync items: Migration Plan 3 and 4.

## Amendments
- **2026-11-04, from the third architecture review; Status stays Accepted** (`architecture-review-2026-11-04.md`, Should fix 5). Probes R1 to R6 ran on 4.7.2 headless and all match (`docs/engine-reference/godot/probe-results.md`). Engine Compatibility (Knowledge Risk, Verification Required) and the Engine probes list under Validation Criteria now mark them verified. The R3 line now names the probe file's R3a (storage, NaN, INF) and R3b (the slop edge). The probes still become CI tests (ADR-0007 Decision 7). Nothing else in this ADR changes.
