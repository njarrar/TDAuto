# ADR-0008: Input Resolver Core and Signal Contract

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer in an autonomous run (no questions asked; every open point is a Verification row or a Risk). Reviewed 2026-11-05 by technical-director (TD-ADR: CONCERNS, 2 blockers, 4 concerns, 6 advisories) and godot-specialist (APPROVE WITH FIXES, 0 blocking, 8 minor, plus a 6-row review probe); all findings were applied in the same-day fix round. A re-review of the revised text follows. Fix round 2026-11-05 after architecture-review-2026-11-05 (items applied: D5 sim and command names, D12 stale L31 note, ring and chip reworded to read).

## Summary
The Input & Gesture Resolver GDD fixes the behaviour (two frozen winners, one pointer, per-press slop, host-driven cancel) but leaves the class, registry API, re-entrancy mechanism, payload types and test seams open. This ADR decides: `InputResolver extends RefCounted` under `src/presentation/input/`, driven only by five calls, built by the wrapper and injected as a constructor argument; `create()`/`validate()` that refuse bad slops; an integer-id registry (`NONE = -1`, ids from 1, never reused) with `Kind` TAP, SINK, DRAG; a four-state machine whose every transition is a table row; a FIFO call queue drained by the outermost call, with registry calls applied at once and never queued; typed `int`/`Vector2` payloads for the eight signals named by ADR-0006; a 32-entry integer ring of recent transitions; and a pure unit-test seam.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf, probed 2026-11-01) |
| **Domain** | Input |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW for the resolver itself: it uses `RefCounted`, `Vector2`, `signal`, `PackedInt32Array` and `Dictionary`, `PackedInt32Array` changed only in setter semantics on element write in 4.7 (`current-best-practices.md`), irrelevant to a private field, and nothing else changed in 4.4 to 4.7 per `breaking-changes.md`. MEDIUM only in the signal re-entrancy behaviour (HIGH-risk engine, behaviours not in the reference), which is taken from ADR-0006's probe. The resolver never sees an `InputEvent`; the HIGH-risk input path is ADR-0003's. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/modules/input.md` ("Verified on 4.7.2", used only to confirm that input arrives before the frame's ticks, so resolver signals and the commands behind them run before that frame's ticks); 4.7.2 probe, 2026-11-05, prototypes/adr-0006-probe/ (direct-connected handlers run synchronously in connection order, nested emits run depth-first, typed handlers reject non-convertible arguments with an error and are skipped, a duplicate `connect` returns `ERR_INVALID_PARAMETER`, releasing a `RefCounted` listener removes its connection); 4.7.2 probe, 2026-11-05, prototypes/adr-0008-probe/ (rows below) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Observed on 4.7.2 desktop, headless debug editor (4.7.2 probe, 2026-11-05, prototypes/adr-0008-probe/, `output.txt`): (P1) `Vector2.is_finite()` is false for a NaN component, for +INF and for -INF, true for finite; (P2) float `is_nan`, `is_inf`, `is_finite` behave as named; (P3) `NAN <= 36.0` and `NAN >= 15.0` are both false, so an unchecked NaN would never trip a slop test (the reason positions are screened first); (P4) `Vector2(306,480).distance_squared_to(Vector2(270,480)) <= 36.0*36.0` is true and at 307 false (the boundary-inclusive hit test is exact for integer centre, radius and position; `Vector2` is float32, so for values not representable in float32 the edge result is within one ulp, and touch positions after stretch are fractional anyway); (P5) 10 000 `distance_squared_to` comparisons took 283 us and 10 000 `distance_to` took 249 us, so neither is meaningfully cheaper in GDScript at this size and the squared form is chosen for exactness, not speed. A second probe from the review (4.7.2 probe, 2026-11-05, prototypes/adr-0008-probe/output-review.txt, `review_probe.gd`): R1 the signatures compile (the `class_name` self-return of `create` was probed through an inner class only), R2 `Callable().is_valid()` is false, R3 `PackedInt32Array.find`/`remove_at` keep ascending order, R4 the float32 edge behaviour above, R5 in-place `PackedInt32Array` writes allocate nothing while an `Array` append allocates, R6 frozen winners survive an unregister, register and `press()` inside a handler. **Caveat: desktop debug editor only; the release-export re-run joins ADR-0003's device runs.** Unsourced claims are listed as NOT SOURCEABLE in the Verification table at the end of the Decision. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted: Decision 4 wrapper builds the resolver and a null `create` is a fatal; Decision 5 method-Callable injection, no flags; Decision 8 `dev_error`); ADR-0002 (`InputRecord` supplies `drag_slop`, `tap_slop`; Decision for `tap_not_above_drag` says the resolver repeats it in `validate()`); ADR-0003 (Proposed: the adapter and `PointerGate` call the five resolver methods; `src/presentation/input/`); ADR-0006 (Proposed: Decision 5 fixed the signal names, Decision 6 and 7 the payload and ID types, Decision 14 the pitfalls) |
| **Enables** | ADR-0007 (resolver unit-test seam, recording fake, signal-set test), ADR-0010 (TowerInput, HeroInput and HudLogic register against this API; the RunLog/GestureLog consume the ring), ADR-0011 (ring and chip visuals read resolver-driven state through HudLogic's redraw key, ADR-0011 Decision 8, rather than reacting to `pressed`, `tapped`, `ground_tapped`; HudLogic is the listener) |
| **Blocks** | Every InputResolver, TowerInput, HeroInput and HudLogic story that registers a target or connects a gesture signal; the Pillar 4 phone test (P1) |
| **Delegates To** | ADR-0010: hit-radius and priority constants on each input object (the resolver has none), the registrations list (authoritative; Decision 11's table and registrations are informative), the GestureLog harness (Rule 13) and the RunLog schema. ADR-0003: adapter, `PointerGate`, `DisplayContract.accepts`, lifecycle and the `cancel()` callers. ADR-0006: the signal emit model. ADR-0007: the runner, the recording-fake classes, the lints (including L31 for `InputEvent` and `Time` reads in `input_resolver.gd`) and the per-build wiring test, including one listener per id-bearing signal per owner class. ADR-0011: ring and chip visuals. Tower System: the 1.5 s cost-chip window and the 200 ms bounce guard (never the resolver's). |
| **Ordering Note** | Accept ADR-0003, ADR-0006 and this ADR together: all three describe one call path. Three items change the GDD and architecture B2 text and are owed at acceptance (sync file): `Kind` replaces `accepts` plus `sink`, `validate()` stops at finite, positive and `tap_slop > drag_slop` (domain bounds stay with the Data validator), and `create` takes an optional `dev_error`. |

## Context

### Problem Statement
Three owners (TowerInput, HeroInput, HudLogic) and the adapter share one resolver, and a handler of one signal routinely calls back into it: the HUD registers arc discs inside `tapped(slot)`, a handler may `cancel()` or `press()` (bots), and the owner who closes an arc on `pressed` unregisters the disc whose `tapped` would follow. The GDD gives the behaviour in prose and 37 acceptance criteria but not the class, the registry API, how registration inside a handler returns an id, the payload types or where the file lives. Architecture B2 adds details the GDD lacks (the `register` argument order and the `Accepts`/`sink` pair; `NONE` is -1 in both). Without one contract each owner will guess, and a half-committed state seen by a handler is the failure that produces a mis-fired upgrade.

### Constraints
- Battle = pure function of (catalogue, stage_id, seed, command script). The resolver is presentation-side input, not battle: it never mutates a sim; its listeners issue commands (Principle 4).
- No autoload, no lambda, no `bind()`, no `static var`, no `CONNECT_DEFERRED`/`CONNECT_ONE_SHOT` (ADR-0001 Decision 5); roots `src/app/`, `src/battle/`, `src/presentation/`, `src/data/`. The resolver observes the same style rules although the `src/battle/` lint does not cover `src/presentation/input/` (ADR-0007 extends the lambda lint to it, ADR-0003).
- Positions are 540x960 field units (ADR-0003 Decision 5); the adapter forwards `event.position` unchanged and the resolver never reads a camera, display or clock.
- Hardware: low-end Android phone, 60 fps; a press is a few tens of target comparisons (probe P5: 10k comparisons about 0.28 ms on desktop, so about 28 ns each, unmeasured on device).
- A signal and a method of one name cannot coexist (ADR-0006 B1): the signals are past tense, the methods are imperative.

### Requirements
- TR-input-001, 007, 008, 009, 010, 011, 015; TR-tower-011; TR-hero-010; TR-hud-008, TR-hud-009 (quoted in GDD Requirements Addressed).
- GDD acceptance criteria 1 to 37 must be runnable against this API with a recording fake and no scene.
- `register` returns its id synchronously, even inside a handler.

## Decision

**1. Class and placement.** `class_name InputResolver extends RefCounted` in `src/presentation/input/input_resolver.gd`, the root ADR-0003 chose for `PointerGate` and the adapter. It is pure: no `Node`, no `InputEvent`, no `Time`, no `Engine`, no `OS`, no `DisplayServer`, no scene. The wrapper builds it with `InputResolver.create(...)` in `BattleWrapper.setup()` (ADR-0001 Decision 4), keeps the strong reference, and injects it by constructor argument into `PointerGate`/`InputAdapter.setup`, TowerInput, HudLogic and HeroInput, in the HUD GDD's build order (resolver, TowerInput, HudLogic, HeroInput). Injection is object injection of the typed `InputResolver` (owners call its public methods); it is rebuilt per battle with the wrapper, and `Battle.set_input_cancel` receives `resolver.cancel` as a method Callable (ADR-0001). No owner stores a lambda of it. No autoload, no `static var`.

**2. Construction and validation.** `static func create(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> InputResolver` returns `null` when `validate(drag_slop, tap_slop)` is false; otherwise a new instance. `static func validate(drag_slop: float, tap_slop: float) -> bool` is true only when both are finite, `drag_slop > 0.0` and `tap_slop > drag_slop` (probe P1/P2 for the finite tests). It is the second line behind the Data validator's `tap_not_above_drag` (ADR-0002 criteria; the catalogue-driven values arrive from `InputRecord`); the numeric domains (8 to 30, 16 to 34) stay with the Data validator, so the resolver holds no copy of a catalogue number. The slops are read once, stored squared (`_drag_slop_sq`, `_tap_slop_sq`) and are immutable (a runtime setter is reserved for Settings at Alpha and would add a method, not change a signal). `dev_error` is a method Callable on the `DevErrorSink` (ADR-0001 Decision 8); when the Callable is not valid the resolver falls back to `push_error`, never silence. A null `create` makes the wrapper call its failure handler (Flow Rule 18).

**3. Hit-target registry.** `enum Kind { TAP, SINK, DRAG }`; `const NONE := -1`; `const FIRST_ID := 1`. A target is `{id, kind, priority, centre, radius, enabled}`. `SINK` is a TAP-class target that absorbs taps its owner ignores, does not raise the press's slop and does not hold the pointer (GDD Hit targets); encoding it as a `Kind` removes the GDD's invalid state "sink on a DRAG target" and the architecture's `sink` flag (sync file). A target that answers both classes registers twice, under two ids.
- `register(kind: Kind, priority: int, centre: Vector2, radius: float, enabled: bool = true) -> int` assigns `_next_id` (initially 1, incremented after use, never decremented or reused) and returns it. A non-finite `centre`, or a `radius` of zero, negative or non-finite, calls `dev_error` with the ring context, registers nothing and returns `NONE` without consuming an id.
- `unregister(id: int)`, `set_centre(id: int, centre: Vector2)`, `set_enabled(id: int, enabled: bool)`: an id that is not live (never issued, or unregistered) is a `dev_error` no-op (ADR-0001 `dev_error` path; criterion 20 asserts the next press is unaffected). A non-finite `set_centre` is a `dev_error` and the old centre stays.
- Storage: `_targets: Dictionary` (id to a small inner `RefCounted` record) and `_ids: PackedInt32Array` in ascending id order. Hit tests iterate `_ids`, never the Dictionary, so the lower-id tie-break needs no engine iteration-order claim. `unregister` removes the id from both.
- `enabled` is tested only at press; a target moved, disabled or unregistered mid-gesture still receives that gesture's remaining signals under its old id (frozen winners, Decision 5).
- There is no hit-radius, priority or placement constant in the resolver; those belong to the input objects (ADR-0010). The suggested priority table in the GDD is a registration convention, not resolver data.

**4. The hit test.** A target is hit by `p` when `p.distance_squared_to(centre) <= radius * radius` (a press exactly on the edge hits; probe P4 shows 36 hits and 37 misses at radius 36). Per class (TAP-class = `TAP` and `SINK`; DRAG-class = `DRAG`) the winner is the enabled hit target with the highest `priority`; on equal priority the smaller distance squared; on equal distance the lower id. Ascending-id iteration with replacement only when strictly better gives the third rule without a compare. Priorities compare only within a class. Winners are `best_tap` and `best_drag` (either may be `NONE`). A press stores, in the press record: `_best_tap`, `_best_drag`, the tap winner's centre and radius at that moment (`_tap_centre`, `_tap_radius`), `_tap_is_sink`, `_press_pos` and `_slop_sq`. Nothing afterwards re-targets them. The release tests `p` against the frozen tap disc only.

**5. State machine.** `enum State { IDLE, PRESSED, DRAGGING, DEAD }`. One active pointer, `_active` (index; `const NO_POINTER := -1`). Per press: a *real tap winner* is a `best_tap` that is not a sink. `_slop_sq = _tap_slop_sq` when there is a real tap winner or no winner at all, else `_drag_slop_sq` (drag winner without a tap winner, or only a sink; GDD Rule 3). Moves compare `distance_squared_to(press_pos) >= _slop_sq` (exactly equal is a drag; criterion 31). Replacement (Rule 1): a `press(other, p)` while PRESSED or DEAD with no real tap winner behaves as `cancel()` then `press(other, p)`; any other `press(other, ...)`, and every `move`, `release` or `cancel_pointer` naming a non-active pointer, is dropped, nothing emitted and nothing logged. `press(active, p)` in any non-Idle state is `cancel()` then `press`. Cancel is host-driven only: `cancel()` and `cancel_pointer(active)` are the only cancels; the resolver never emits a drag cancel on its own initiative except as the answer to those calls (Rule 7).

**6. Emit sequence per transition.** Every transition commits the state, the winners and the log entry first (commit-then-emit, ADR-0006 Decision 2), builds its batch from values captured before the commit, then emits the batch in the order shown. `became_idle()` is the last signal of every row that leaves PRESSED, DRAGGING or DEAD for IDLE and is never emitted by an IDLE-to-IDLE row.

| From | Call and guard | To | Batch (in order) |
|---|---|---|---|
| IDLE | `press(i, p)` | PRESSED | `pressed(best_tap, best_drag, p)` |
| PRESSED/DEAD, no real tap winner | `press(other, p)` | as `cancel()` then `press` | `became_idle()`, then `pressed(...)`; no `ground_tapped` |
| PRESSED, DRAGGING, DEAD | `press(active, p)` | as `cancel()` then `press` | cancel batch, then `pressed(...)` |
| PRESSED | `move`, under slop | PRESSED | none |
| PRESSED | `move`, at or past slop, drag winner | DRAGGING | `drag_started(best_drag, press_pos, p)` |
| PRESSED | `move`, at or past slop, no drag winner | DEAD | none |
| PRESSED | `release`, under slop, tap winner, `p` inside frozen disc | IDLE | `tapped(best_tap, p)`, `became_idle()` |
| PRESSED | `release`, under slop, tap winner, `p` outside | IDLE | `became_idle()` |
| PRESSED | `release`, under slop, no winner at all | IDLE | `ground_tapped(p)`, `became_idle()` |
| PRESSED | `release`, under slop, only a drag winner | IDLE | `became_idle()` |
| PRESSED | `release`, at or past slop, drag winner | IDLE | `drag_started(...)`, `drag_ended(best_drag, press_pos, release_pos)`, `became_idle()` |
| PRESSED | `release`, at or past slop, no drag winner | IDLE | `became_idle()` |
| DRAGGING | `move` | DRAGGING | `drag_moved(best_drag, press_pos, p)` |
| DRAGGING | `release` | IDLE | `drag_ended(best_drag, press_pos, release_pos)`, `became_idle()` |
| DEAD | `move` | DEAD | none |
| DEAD | `release` | IDLE | `became_idle()` |
| DRAGGING | `cancel()` or `cancel_pointer(active)` | IDLE | `drag_cancelled(best_drag)`, `became_idle()` |
| PRESSED, DEAD | `cancel()` or `cancel_pointer(active)` | IDLE | `became_idle()` |
| IDLE | `cancel()`, `move`, `release`, `cancel_pointer(any)` | IDLE | none |

A sink-only tap (`tapped(sink)`) is emitted like any tap; owners ignore it. A press whose `best_tap` is a sink and whose `best_drag` is the burst button drags the burst (criterion 28). `drag_moved` is emitted once per `move` call, never per frame, and never for the move that starts the drag.

**7. Re-entrancy: FIFO call queue; registry calls are not queued.**
- `press`, `move`, `release`, `cancel_pointer` and `cancel` are public entry points. Each first screens its arguments (Decision 10), then appends `[op, pointer, pos]` to `_queue` (an `Array`; a `_head` index walks it, so there is no `pop_front` and no shifting). If `_draining` is false the call sets it, drains `while _head < _queue.size()`, processes each entry completely (commit, then the whole batch delivered to every listener, depth-first, in connection order, 4.7.2 probe, 2026-11-05, prototypes/adr-0006-probe/ rows 1 to 3), and then clears `_queue`, `_head` and `_draining`. If `_draining` is true (the call came from a handler) the call only appends and returns; the outermost call delivers it after the current batch has reached every listener. A cancel-then-press row is one queue entry processed as the cancel batch followed by the press: the new press's hit test runs after the cancel batch has been delivered, so a registration made by a `became_idle` handler is visible to it; the cancel batch itself is captured before the new press commits.
- Registry calls (`register`, `unregister`, `set_centre`, `set_enabled`) are **not queued and take effect at once**, legal in any state including inside a handler. `register` therefore returns its id synchronously with no special case: the counter increments in the call. **Decision on the GDD review flag:** the lead's alternative (allocate the id at once and apply the registration after the current dispatch) was rejected, because (a) the only code that reads the registry is the hit test, and the hit test runs only when a queue entry starts processing, never during emission, so no handler can ever observe a half-applied registry change in flight; (b) the in-flight gesture's winners and discs are frozen values copied at press, so a registry edit cannot alter it (GDD Edge Cases); (c) a deferred apply would need its own queue entries and an ordering rule against queued presses, which is the machinery this decision avoids. The consequence is stated and tested: an arc disc registered inside a `tapped` handler receives nothing from the gesture in flight, and competes from the next press, including a `press` queued by the same handler. The reverse also holds: a later listener of the same emit can receive a winner id that an earlier listener has already unregistered; owners compare it with their own ids and never look it up (there is no lookup API), so this is harmless (review probe R6).
- A runaway guard: `const QUEUE_LIMIT := 64` entries processed in one outermost call; beyond it the resolver calls `dev_error` with the ring context, discards the rest of the queue, and runs one final `cancel()` whose handlers' gesture calls are dropped, so the resolver always ends IDLE and every press is still closed (ADR-0003). A bot that presses from `became_idle` forever cannot hang the frame. This is a structural constant, not a tuning value.
- A handler may call `cancel()` and `press()`, and no handler may assume a signal batch is not followed by another call's batch. Handlers never call back into a signal's emitter beyond the public methods.

**8. Payloads and types (ADR-0006 Decisions 6 and 7).** Target ids and `NONE` are `int`; positions are `Vector2` field-unit copies made at emit time; no payload carries a `Dictionary`, `Array`, record ID or object. A winner id is not a record ID: it is a registration id local to one resolver. Declarations, in this order (`emit()` argument order is declaration order, ADR-0006 Decision 14e):

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
`pressed` always fires on an accepted press (with `NONE`, `NONE` on bare ground) so chips and arcs close on the press itself. `tapped` is never emitted with `NONE`. A listener compares ids with `==`; `NONE` is -1 and ids start at 1, so an unset owner id field (0) matches neither `NONE` nor any issued id. Names and their meaning are the GDD's; the table of listeners is in Decision 11.

**9. Gesture log (ring of recent transitions).** `const LOG_CAPACITY := 32` and `const LOG_FIELDS := 7`. The resolver keeps `_log: PackedInt32Array` of `LOG_CAPACITY * LOG_FIELDS` ints, a write cursor and `_seq`, and records one entry per transition per state change; a replacement writes two entries (the replaced press's exit to IDLE, then the new press); a `dev_error`, a registry one included, writes no entry (it reads the ring for context): `seq`, `call` (an `enum Call { PRESS, MOVE, RELEASE, CANCEL_POINTER, CANCEL }`), `pointer`, `state_before`, `state_after`, `best_tap`, `best_drag`. `DRAGGING` to `DRAGGING` moves and dropped calls are not logged, so a drag cannot flood the ring. Writes are in place on the packed array, with no allocation per entry (4.7.2 probe, 2026-11-05, prototypes/adr-0008-probe/output-review.txt R5: 200 000 in-place writes, zero static-memory delta), in every build (it is not dev-gated; the cost is 7 int stores per transition). Reads: `recent_transitions() -> PackedInt32Array` returns the entries oldest first as flat records (a copy, called by `dev_error` formatting and by ADR-0010's RunLog/GestureLog), and `describe_recent() -> String` formats the last few for `dev_error` context. `_seq` is a transition counter, never a time: the ring has no clock (Decision 12). The Rule 13 gesture-log harness (positions, hold time, travel, expected action) is ADR-0010's GestureLog, a listener on the signals plus `tower_upgraded`, `burst_started` and `chip_state()`; it supplies times from its own view clock, not from here.

**10. Bad input.** Every entry point that takes a position (`press`, `move`, `release`) checks `pos.is_finite()` before queueing (probe P1); a non-finite position is dropped with `dev_error` (ring context included), the state is unchanged, nothing is emitted, nothing queued (criterion 21; probe P3 shows NaN would otherwise never trip a slop test and would hold a press forever). `register` and `set_centre` screen as in Decision 3. Pointer indices are any `int`; the resolver does not bound them. A dropped wrong-pointer call, a move or release in IDLE and a `cancel()` in IDLE are silent no-ops and not errors (they are expected: ADR-0003 forwards a lost finger's calls and `cancel_all()` calls `cancel()` unconditionally).

**11. Wiring and listeners.** The wrapper connects the resolver's signals in `BattleWrapper.setup()` after the three owners are built, with plain `Signal.connect(obj.method)` over method Callables and no flags, in this fixed order per signal: TowerInput, HudLogic, HeroInput, then the dev GestureLog. No listener may depend on that order (each owner's handler is written order-independent; the order only makes runs repeatable). This holds because exactly one owner holds any given winner id (TowerInput its towers, slots and chip; HeroInput its hero, button and sink; HudLogic its arc, backdrop and Start/Call discs), so one gesture issues at most one command; the ADR-0007 wiring test asserts one listener per id-bearing signal per owner class. An order dependency may exist only among presentation listeners (leash, arc closing), never in the command script. The resolver does not hold its listeners and never connects to anything.

| Signal | Listeners and use |
|---|---|
| `pressed` | TowerInput (closes an open chip when `best_tap` is not its chip disc), HudLogic (closes the arc unless `best_tap` is one of its discs, TR-hud-009; ignores a Start/Call tap that also hits the hero via `best_drag`), HeroInput (leash, samples cooling) |
| `tapped` | TowerInput (chip open and second-tap commit), HudLogic (arc discs, Start/Call; ignores the backdrop), HeroInput (ignores sinks) |
| `ground_tapped` | HudLogic (rejection ring) |
| `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled` | HeroInput (pin, burst aim and fire); HudLogic (`drag_started` closes the arc) |
| `became_idle` | HudLogic, HeroInput (hides the leash); GestureLog (dev) |

Informative; ADR-0010 (the input objects) and ADR-0007 (the per-build wiring test) are the authority for registrations and listener uses. Owners register: TowerInput towers and slots TAP 200 and the chip disc TAP 300, disabling a built slot (TR-tower-011); HeroInput the hero DRAG 200, the burst button DRAG 100 and its sink TAP 400 (`Kind.SINK`), re-centring the hero's target each position change (TR-hero-010); HudLogic arc discs TAP 300, the arc backdrop SINK 250 and Start/Call TAP 350, registering on open and unregistering on close (TR-hud-008). The table above follows the GDD Interactions table and the consumer GDDs; ADR-0010 and the ADR-0007 wiring test are the authority if a row is wrong. These radii and priorities are constants on the owners' input objects (ADR-0010). **No resolver listener mutates a sim directly**; each calls a command (`HeroSim.pin`, `HeroSim.burst`, `TowerSim.build`, `TowerSim.upgrade`, Flow `start_wave` and the early-call command `call_early`), which refuses while `Battle.in_dispatch()` is true (ADR-0006/ADR-0010 re-entrancy refusal; input arrives between ticks, ADR-0004 Decision 7).

**12. Determinism.** The resolver is driven only by its five calls; it reads no clock, no `Engine`, no random number and no `Input` singleton; a given call list on a fresh resolver yields an identical signal log (criterion 23; the ring's `_seq` is a counter). The 1.5 s cost-chip window and the 200 ms bounce guard are Tower System's. The resolver is never part of the headless build: bots call the Hero and Tower commands directly (GDD Rule 11), and one equivalence test passes through the resolver.

**13. Testing seam (ADR-0007 owns the runner).** Pure GDScript unit tests in `tests/unit/input/` (ADR-0007's `tests/unit/<system>/` rule; the GDD's `tests/unit/input_gesture_resolver/` changes, sync file) with a recording fake that connects to all eight signals, declares every handler parameter untyped and asserts argument count, `typeof` and range itself (ADR-0006 Decision 10; a typed fake would be skipped with a console error). Fixtures are factory functions (the GDD's `T`, `S`, `H`, `B`, `Z`, `A`, `K`) in field units, with the starter slops 15 and 28 read from the fixture factory, not inline. Validation criteria map to GDD acceptance criteria numbers: 1 to 5 (one pointer, palm replacement, lost release), 6 (frozen winners), 7 to 12 and 34 (classification, per-press slop, tap slop), 13 to 15 (taps, release, drag payload positions), 16 to 17 (cancel and per-pointer cancel), 18 (repeat taps), 19 (validation, with the narrower contract in the sync file), 20 (unknown id), 21 (non-finite), 22 (idle ignores movement), 23 (ids and determinism), 24 to 26 (registry and mid-gesture), 27 (re-entrancy), 28 to 29 (sink and arc), 30 to 33 (hit, is_drag, tie-break, target_ok), 35 to 37 (replacement). Added by this ADR: ring contents and capacity, `register` inside `tapped`/`pressed`/`became_idle` returns the id at once and the new target competes only from the next press, the queue limit, `dev_error` on each bad input, and a signal-set test (`get_script().get_script_signal_list()` equals the eight names, ADR-0006 Decision 9 style).

**14. GDScript 4.7 pitfalls.** (a) Signal parameter types are not checked at `emit()`; payloads are `int` and `Vector2` and the fake asserts types (ADR-0006 14a). (b) A `connect` to a method with the wrong parameter count fails at the first `emit()`; every one of the eight signals is emitted in the wiring test. (c) `register` and `create` have explicit return types; handlers are `func on_<signal>(...) -> void`. (d) No lambda anywhere in `src/presentation/input/`. (e) Never use `Dictionary` iteration order for the tie-break (Decision 3). (f) A handler must not `await`.

**15. Delegations.** See ADR Dependencies, Delegates To.

### Architecture Diagram

```
InputAdapter (Node) ─► PointerGate ─► resolver.press / move / release / cancel_pointer / cancel
                                           │ (screen non-finite, queue, drain)
                                           ▼
                      InputResolver (RefCounted)  state · frozen winners · registry · _queue · _log ring
                                           │ signals (synchronous, connection order)
        ┌───────────────┬───────────────────┼───────────────────┬──────────────┐
   TowerInput       HudLogic            HeroInput          GestureLog (dev)
   register/unregister/set_enabled ─────────► registry (applied at once, any state)
Owners issue commands (Tower/Hero/Flow); they never touch the sim directly.
```

### Key Interfaces

```gdscript
class_name InputResolver extends RefCounted
enum Kind { TAP, SINK, DRAG }
enum State { IDLE, PRESSED, DRAGGING, DEAD }
enum Call { PRESS, MOVE, RELEASE, CANCEL_POINTER, CANCEL }
const NONE := -1
const NO_POINTER := -1
const FIRST_ID := 1
const LOG_CAPACITY := 32
const LOG_FIELDS := 7
const QUEUE_LIMIT := 64

static func validate(drag_slop: float, tap_slop: float) -> bool       ## finite, drag_slop > 0, tap_slop > drag_slop
static func create(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> InputResolver   ## null when invalid

func press(pointer: int, pos: Vector2) -> void
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
func cancel() -> void

func register(kind: Kind, priority: int, centre: Vector2, radius: float, enabled: bool = true) -> int   ## NONE on bad input
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void

func state() -> State
func active_pointer() -> int                                          ## NO_POINTER when Idle
func recent_transitions() -> PackedInt32Array                         ## oldest first, LOG_FIELDS ints each
func describe_recent() -> String
# signals: see Decision 8
```

### Implementation Guidelines
- `InputResolver` **must** extend `RefCounted` and **must never** reference a `Node`, `InputEvent`, `Time`, `Engine`, `OS`, `DisplayServer`, `Input`, a camera or the scene tree; **must never** read a clock or random number.
- Owners **must** receive the resolver as a constructor argument; there **must never** be an autoload, a `static var` holder or a global accessor for it.
- The five gesture methods **must** screen non-finite positions before queueing and **must** queue (not recurse) when called from a handler. Registry methods **must never** be queued and **must** apply at once.
- The resolver **must** commit state, winners and the log entry before emitting the first signal of a batch, and **must** emit `became_idle()` last on every exit to IDLE. It **must never** emit `became_idle()` from an IDLE-to-IDLE row.
- A gesture **must** reach only its class winner; **must never** fall through to the other class or a lower-priority target. A cancel **must never** be turned into a `tapped` or `drag_ended`.
- `register` **must** return `NONE` and consume no id on bad arguments; ids **must** be assigned from 1 and **must never** be reused. Ties **must** be broken by priority, then distance squared, then lower id, iterating `_ids` and not the Dictionary.
- Hit radii, priorities, placement and `edge_reject_margin` **must not** appear in the resolver; owners declare them as constants (ADR-0010). The slops **must** come from the `InputRecord` by injection and **must not** be literals in the resolver.
- A listener **must** connect through `Signal.connect(obj.method)` with no flags, from `BattleWrapper.setup()`; a listener **must never** mutate a sim, only issue commands. A handler **must never** assume a later listener has run.
- Every handler **must** be `func on_<signal>(...) -> void`. Tests **must** use the untyped recording fake.

## Alternatives Considered

### Alternative 1: Resolver as a `Node` that reads events and uses `await`/`call_deferred` for re-entrancy
- **Description**: Merge adapter and resolver; use deferred calls instead of a queue.
- **Pros**: One class; deferred calls are an engine feature.
- **Cons**: Not unit-testable without a scene; deferred calls make emit order depend on frame timing and break criterion 27; ADR-0001 bans deferred connects.
- **Rejection Reason**: Violates the pure-object requirement (TR-input-001) and the synchronous drain the GDD specifies.

### Alternative 2: Registry mutations queued with the gesture calls (id allocated at once)
- **Description**: `register`/`unregister`/`set_*` inside a handler append a queue entry; the id comes from the counter immediately.
- **Pros**: A strictly serial history; the hit test and the registry change in one total order.
- **Cons**: A second queue entry type and an ordering rule for a registration followed by a queued press; `set_centre` for a walking hero would also be delayed behind a drain; the GDD and every owner story say "effective at once".
- **Rejection Reason**: No handler can observe the registry mid-batch (the hit test only runs between batches), so the order buys nothing (Decision 7).

### Alternative 3: Keep `Accepts` and a `sink` flag as in the GDD and architecture B2
- **Description**: Use the draft API unchanged.
- **Pros**: No GDD edits.
- **Cons**: `sink` on a DRAG target is representable and meaningless.
- **Rejection Reason**: `Kind` removes an invalid state. The cost is a sync edit (GDD target table, architecture B2).

### Alternative 4: Object references instead of `int` ids as winners
- **Description**: Payloads carry the target object.
- **Pros**: No id lookup for owners.
- **Cons**: A stale reference after `unregister` aliases freed memory; ADR-0006 Decision 6 says instance identifiers are `int`; `NONE` has no clean value.
- **Rejection Reason**: Ids that are never reused cannot alias a live target.

## Consequences

### Positive
- The resolver is testable with a recording fake and no scene, and all 37 GDD criteria map to it.
- Registration inside a handler is trivial: no queue entry type for it, no async id.
- A non-finite input or a runaway re-entrant bot cannot corrupt state or hang a frame.
- The ring gives `dev_error` and the RunLog a bounded recent history with no allocation per transition.

### Negative
- Three sync edits to the GDD and architecture B2 (`Kind`, `validate` narrowing, optional `dev_error`).
- `validate()` no longer enforces the 8 to 30 and 16 to 34 domains the GDD criterion 19 lists; those three cases move to the Data & Config tests (Data & Config GDD Rule 7 boundary criterion 3, line 230, and its `tap_slop` edge case, line 160; ADR-0002 line 107 `tap_not_above_drag`), since the catalogue is the single source of the numbers.
- A registration in a handler applies before the batch has finished delivering to later listeners: a later listener of the same signal can see a target an earlier listener just registered (it cannot affect the gesture in flight).

## Risks
- Hit testing is O(targets) per press; with tens of targets it is a few microseconds (probe P5, desktop, unmeasured on device). Mitigation: owners disable rather than churn targets; revisit only if a stage registers hundreds.
- Palm replacement relies on the adapter forwarding every second press (ADR-0003 Decision 3). Mitigation: criteria 1 to 5 and 35 to 37 run against the real resolver; the P1 phone test watches for hero/burst palm replacement (GDD Rule 1).
- An owner that unregisters inside a drag continues to receive `drag_*` for its old id. Mitigation: documented; owners ignore them (GDD).
- The queue limit of 64 is a guess for a defensive bound; a legitimate script cannot approach it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-gesture-resolver.md | TR-input-001: "The resolver is a pure, scene-free, clock-free object driven only by press, move, release, cancel_pointer and cancel" | Decision 1 and 12: `RefCounted`, no engine types, five entry points, no time reads |
| input-gesture-resolver.md | TR-input-007: "A registry of disc hit targets {id, centre, radius, accepts, priority, enabled, sink}; register, unregister, set_centre and set_enabled are legal in any state and apply at once" | Decision 3 and 7: `Kind` replaces `accepts` plus `sink`; registry calls apply at once and are never queued |
| input-gesture-resolver.md | TR-input-008: "A four-state machine (Idle, Pressed, Dragging, Dead) with one active pointer freezes TAP and DRAG winners at press and classifies by per-press slop" | Decisions 4 to 6: frozen winners, per-press slop, full transition table |
| input-gesture-resolver.md | TR-input-009: "Signal API pressed, tapped, ground_tapped, drag_started, drag_moved, drag_ended, drag_cancelled, became_idle; every exit to Idle emits became_idle() last" | Decision 6 and 8: the table and the typed declarations |
| input-gesture-resolver.md | TR-input-010: "State commits before emit; gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call" | Decision 7: queue, `_draining`, head index, queue limit |
| input-gesture-resolver.md | TR-input-011: "Slops come by injection through static validate() and a create() factory returning null on bad input, and a null create() in the wrapper calls the failure handler; non-finite positions are dropped with push_error" | Decision 2 and 10: `create`/`validate`; non-finite positions go to the injected `dev_error` (falling back to `push_error`) |
| input-gesture-resolver.md | TR-input-015: "Dev builds carry a gesture-log harness recording device, insets, timing, travel, winners and classification, listening to tower_upgraded, chip_state() at tower prompts and burst_started (only it counts as a burst), for the Pillar 4 phone test" | Decision 9: the resolver supplies the transition ring and the signals; the harness itself is ADR-0010 |
| tower-system.md | TR-tower-011: "TowerInput registers slots and the chip disc with the resolver, disables built slots, closes the chip on phase, and ignores taps while halted" | API supplied; owner behaviour ADR-0010. Decisions 3 and 11: `register`, `set_enabled`, `unregister` |
| hero-system.md | TR-hero-010: "HeroInput registers hero DRAG, button DRAG and sink TAP discs, updates the walking hero's hit centre each frame, and hit-tests cancel hysteresis" | API supplied; owner behaviour ADR-0010. Decisions 3 and 11: `Kind.DRAG`, `Kind.SINK`, `set_centre` applied at once; hysteresis stays Hero's |
| battle-hud.md | TR-hud-008: "The build arc registers and unregisters resolver targets on open and close, disables Start/Call while open, and closes on outcome, Paused or Fatal" | API supplied; owner behaviour ADR-0010. Decisions 3 and 7: registration inside a handler returns its id and competes from the next press |
| battle-hud.md | TR-hud-009: "The resolver's pressed payload exposes both best_tap and best_drag so the HUD can ignore a Start/Call tap that also hits the hero" | Decision 8: `pressed(best_tap, best_drag, p)` |

## Performance Implications
- **CPU**: one press tests every enabled target (tens, about 28 ns each on desktop, probe P5); moves are O(1); drag signals are one per input call (roughly the touch rate). Negligible against the 4.0 ms simulation slice.
- **Memory**: a few records, the 224-int ring (32 x 7), a short queue array; no allocation while idle, and each gesture call appends one small `Array` queue entry (about 189 B, review probe R5) released when the queue clears.
- **Load Time**: none.
- **Network**: not applicable.

## Migration Plan
Greenfield (`src/` holds no resolver). Create `src/presentation/input/input_resolver.gd`; the wrapper builds it in `setup()`; owner stories register against the API above. The sync file lists the GDD and architecture edits owed at acceptance.

## Validation Criteria
1. Criteria 1 to 37 of the Input GDD pass as unit tests in `tests/unit/input/` (mapping in Decision 13), plus the added tests there.
2. The signal-set test passes: exactly the eight signals; the wiring test shows each has at least the listeners of Decision 11 and no console error.
3. Registering inside `pressed`, `tapped` and `became_idle` returns a fresh id at once and affects only later presses.
4. A bot that presses from every `became_idle` stops at the queue limit with one `dev_error` and the resolver is IDLE afterwards.
5. No script under `src/presentation/input/input_resolver.gd` names an engine input type or time function (an ADR-0007 lint that ADR-0007 does not list yet; sync file).
6. The Pillar 4 phone test (P1) is run with this resolver and the ADR-0010 input objects.

### Verification Table

| # | Claim | Status | What to run | Expected |
|---|-------|--------|-------------|----------|
| V1 | `get_script().get_script_signal_list()` on a `RefCounted` resolver returns the eight declared signals | NOT SOURCEABLE — not covered by `docs/engine-reference/godot/` or the cited probes | In a unit test: `InputResolver.new().get_script().get_script_signal_list()`, collect `name` | Exactly the eight names |
| V2 | `Callable()` has `is_valid() == false`, so the `push_error` fallback runs when no `dev_error` is given | Observed, 4.7.2 probe, 2026-11-05, prototypes/adr-0008-probe/output-review.txt R2 | Re-run `review_probe.gd` | `false` |
| V3 | The probe rows P1 to P5 hold in a release export, not only the debug editor | NOT SOURCEABLE — probe is desktop debug editor only | Re-run `prototypes/adr-0008-probe/probe.gd` from an exported build on a device | Same booleans |
| V4 | `PackedInt32Array.find` and `remove_at` remove one id and keep ascending order | Observed, 4.7.2 probe, 2026-11-05, prototypes/adr-0008-probe/output-review.txt R3; unit criteria 23 and 24 repeat it | Re-run `review_probe.gd` | Ascending order kept; ids never reused |
| V5 | Real touch coalescing delivers the lost-move cases of GDD criteria 8 and 9 | Owed to ADR-0003 device runs D1/D2 | Per ADR-0003 | Per ADR-0003 |
| V6 | `static func create(...) -> InputResolver` returning `null` or `new()` from inside the `class_name` file compiles | NOT SOURCEABLE — probed through an inner class only (review probe R1) | First unit test that calls `InputResolver.create(15, 28)` and `create(NAN, 28)` | Instance, then `null` |

## GDD and Registry Sync at Acceptance

Edits owed when this ADR moves to Accepted (recorded 2026-11-05 from the drafting sync list; line numbers are as of that date):

- design/gdd/input-gesture-resolver.md:38 and :41: the "`accepts` | `TAP` or `DRAG`" row (38) and the "`sink` | bool, TAP only" row (41) -> one `kind` row: `TAP`, `SINK` (TAP-class, absorbs ignored taps) or `DRAG`; "A target that answers both gestures registers twice" unchanged
- design/gdd/input-gesture-resolver.md:117: add after "`register` returns its id at once": "Registry calls are not queued at all; they apply at once, and the hit test only runs between batches, so no handler observes a half-applied change"
- design/gdd/input-gesture-resolver.md:68 (Rule 9, validate): "returns false for ..." -> "validate(drag_slop, tap_slop) is true only for finite values with drag_slop > 0 and tap_slop > drag_slop; the numeric domains stay with the Data validator"; add optional dev_error to create
- design/gdd/input-gesture-resolver.md:234: "If `drag_slop` is outside 8-30, `tap_slop` outside 16-34, ... `validate()` returns false for all of them" -> "outside-domain values are rejected by the Data & Config validator only (Data & Config Rule 7 boundary criterion 3, edge case at line 160); `validate()` rejects non-finite, drag_slop <= 0 and tap_slop <= drag_slop"
- design/gdd/input-gesture-resolver.md:235, 237, 238: "`push_error`" -> "the injected `dev_error` (push_error when none is injected)"
- design/gdd/input-gesture-resolver.md:360 (criterion 19): drop `validate(7, 28)`, `validate(31, 34)`, `validate(15, 35)` from the false list (moved to Data & Config tests); add `validate(0, 28)`, `validate(-1, 28)`, `validate(15, INF)` as false
- design/gdd/input-gesture-resolver.md:339 (Acceptance Criteria preamble): test path "tests/unit/input_gesture_resolver/" (and its helpers/ directory) -> "tests/unit/input/" (ADR-0007 tests/unit/<system>/ rule)
- design/gdd/input-gesture-resolver.md Rule 6 and the transition-table `drag_ended` rows: third argument "p" -> "release_pos" (matches the declaration)
- docs/architecture/architecture.md:397: "enum Accepts { TAP, DRAG }" -> "enum Kind { TAP, SINK, DRAG }" (NONE stays -1)
- docs/architecture/architecture.md:401: add "dev_error: Callable = Callable()" to `create`; `validate` comment "finite, drag_slop > 0, tap_slop > drag_slop"
- docs/architecture/architecture.md:411: "func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int" -> "func register(kind: Kind, priority: int, centre: Vector2, radius: float, enabled: bool = true) -> int"
- docs/architecture/architecture.md:425: "`sink` is TAP-only" -> "SINK is a TAP-class Kind"; "`push_error`" -> "`dev_error`"; remove the "QQ-07 ... to be settled before ADR-0008" sentence (closed by ADR-0006)
- docs/architecture/architecture.md:393-422 (B2 code block): add "enum State { IDLE, PRESSED, DRAGGING, DEAD }", "const NO_POINTER := -1" and, after the registry methods, "func state() -> State", "func active_pointer() -> int  # NO_POINTER when Idle", "func recent_transitions() -> PackedInt32Array", "func describe_recent() -> String"; the `drag_ended` signal names its third argument release_pos
- docs/architecture/architecture.md:~124 (Module Ownership InputResolver row): add `state()`, `active_pointer()`, `recent_transitions()`, `describe_recent()`
- docs/architecture/tr-registry.yaml TR-input-007: requirement "{id, centre, radius, accepts, priority, enabled, sink}" -> "{id, kind (TAP, SINK, DRAG), centre, radius, priority, enabled}" (revised date); TR-input-011 "push_error" -> "dev_error"
- docs/architecture/adr-0007-headless-test-harness-gdunit4-and-layer-lint.md: ADR-0007: applied, lint L31 for InputEvent/Time reads in input_resolver.gd; wiring test asserts one listener per id-bearing resolver signal per owner class
- docs/architecture/adr-0002-catalogue-storage-format-manifest-and-validation.md:107 and adr-0003 PointerGate line 267: no edit
