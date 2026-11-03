# ADR-0003: Frame Order: Command Queue, Ticks and View Update

## Status
Accepted (2026-11-02, by njarrar; the Migration Plan edits landed in the same change)

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
njarrar (project owner); technical-director and lead-programmer (architecture gates, 2026-11-02, finding GF7). Engine specialist and TD-ADR reviews are recorded under Related.

## Summary
Simulation time, player commands, the real-time upgrade chip and the views all meet once per engine frame, and the GDDs need their order fixed without trusting the engine's own event order. Each frame applies every queued command first, then runs at most 5 fixed 1/60 s ticks, then updates the hero's hit disc and the views, then runs the end-of-frame steps; commands are typed records that report their result in the same frame.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (main loop, scripting) |
| **Layer** | Core |
| **Knowledge Risk** | HIGH for frame order (the engine's input-versus-process order is unverified); this ADR is built so that determinism does not depend on it |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.7: an override of a typed method needs an explicit `return`), `deprecated-apis.md` (`OS.get_ticks_msec()` is replaced by `Time.get_ticks_msec()`), `current-best-practices.md` (`@abstract`, 4.5+) |
| **Post-Cutoff APIs Used** | `@abstract` class and method (4.5) for `BattleCommand`; 4.7 typed-return overrides (each `apply` override ends in an explicit `return`) |
| **Verification Required** | Assumes `Engine.time_scale` stays 1.0 (it scales `delta`; memory, unverified). **NOT SOURCEABLE** from `docs/engine-reference/godot/` (no main-loop coverage): (F1) whether `_input` events of a frame arrive before or after that frame's `_process`; the design holds either way, but command latency is one frame or two; (F2) `Time.get_ticks_msec()` is monotonic on Android and iOS across a focus loss; (F3) `_process(delta)` on a phone after a long stall returns the real elapsed time, so the clamp sees it; (F4) the `class_name` cycle `BattleCommand` to `Battle` to `Array[BattleCommand]` parses with `@abstract`. All four are checked on the phone spike (GF5); F4 also by the first command story's parse check |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted): signal and command names, `Battle.enqueue`, the `HaltLatch` and the emit rules. ADR-0001 (Accepted) through ADR-0002 |
| **Enables** | ADR-0004 (the harness drives `Battle` with the same command records and replays a command log), ADR-0007 (the adapter queues commands from its input handlers), ADR-0008 (AppRoot hosts the frame driver defined here) |
| **Blocks** | Every MVP epic that sends a command or runs a tick: Flow, Enemy & Wave, Tower, Hero, Battle HUD |
| **Ordering Note** | ADR-0008 decides where AppRoot and the wrapper live and how Retry rebuilds; it must keep the frame steps in the order this ADR fixes |

## Context

### Problem Statement
Flow Rule 4 says simulation time enters only through `battle.tick(dt)` at a fixed rate with a clamped accumulator; Rule 5 says commands apply only between ticks. Battle HUD Rule 18 says commands run from the input call stack before the frame's ticks, and that this engine order is unverified. The architecture gate (GF7) answered with a command queue applied at the start of the next tick, a 5-tick catch-up cap and a 2 ms per-tick budget. Two gaps remain:

1. **The clock is stopped in Build** (Flow Rule 6), so no tick runs until the player taps Start. A command applied only "at the next tick" would never apply in Build, where the player builds the first towers.
2. **A refused command needs a visible answer** (Open Question A11). `NO_GOLD` leaves the arc open with a nudge (HUD Rule 7); a refused pin shows the ghost clamp. With `enqueue` returning nothing, the result has no route back.

The upgrade chip runs on real time while the clock is stopped (Tower Rule 8; `200 ≤ elapsed < 1500` ms at release), and the hero's hit disc follows the walking hero every frame (TR-hero-008). Both must sit somewhere fixed in the frame.

### Constraints
- Gameplay uses no `_process`, timers, `await`, wall clock or physics (Flow Rule 4). Only the frame driver and one injected real-time clock touch engine time.
- Single-threaded. No path crosses a thread boundary.
- Determinism: the same stage, seed and command script give an identical result (Flow Rule 5).
- Commands are queued from the input call stack and bots use the same queue (GF7, registry `battle_signal_wiring`).
- Retry only sets a latch; destroying the caller inside input is unsafe (HUD Rule 18).
- An outcome or Fatal latches mid-tick, then its second step (stop the clock, emit `phase`, request `cancel()`) runs after the tick, and `cancel()` runs at the end of the frame (Flow Rules 15, 18).

### Requirements
- TR-flow-003: time enters only through `battle.tick(dt)`, fixed 60 ticks per second, clamped accumulator (at most 5 ticks per frame).
- TR-flow-004: fixed tick order; commands queued and applied between ticks, bots included; identical replay.
- TR-tower-005: the chip uses real time while the clock is stopped, with the 200 ms bounce guard, and a defined order of input against the real-time feed.
- TR-hero-008: HeroInput calls `set_centre` every frame while the hero walks.
- TR-hud-003: commands come from the input call stack and run before the frame's ticks; Retry only sets a latch.

## Decision

### 1. One frame driver
AppRoot drives simulation time. Each frame its `_process` calls `wrapper.step(delta)`, then runs its own end-of-frame latches. AppRoot, not the wrapper, is the driver because Retry rebuilds the wrapper (architecture 3.5), and an object that is being rebuilt cannot drive its own teardown. No sim object, input piece or HUD logic uses `_process` or reads engine time; nothing relies on the order in which Godot calls `_process` on different nodes (not in the pinned reference). Views may animate in their own `_process` (ADR-0006), reading only. Real time for the chip comes from one injected `RealClock` (`now_ms() -> int`, wrapping `Time.get_ticks_msec()`), so tests pass a fake. ADR-0008 owns where AppRoot and the wrapper live and how Retry rebuilds; this ADR owns what `step` does.

### 2. The frame, in order

```
engine delivers input events  (input path chosen by ADR-0007; before or after step: F1, either is safe)
   InputAdapter -> GestureResolver -> HeroInput / TowerInput / HUD
   handlers only ENQUEUE commands or set latches; nothing in the sim runs here
   TowerInput feeds ChipWindow with RealClock.now_ms() when its handler runs (section 5)
   lifecycle notifications are held by the wrapper and forwarded in step 1b

AppRoot._process(delta)
 1. wrapper.step(delta):
    a. chip feed:      TowerInput.advance_chip(now_ms)
    b. lifecycle:      forward held lifecycle states (lifecycle_changed), then
       apply commands: battle.apply_queued()          even when the clock is stopped
    c. ticks:          if flow.clock_running(): owed = clamp(accumulate(delta)); repeat owed: battle.tick(DT)
                       else: accumulator = 0
    d. outcome step:   if an outcome or Fatal latched this frame: stop clock, emit phase(...), request cancel()
    e. hero disc:      HeroInput.set_centre(hero_id, battle.hero().position())  while the hero walks
    f. views:          views redraw from reads (roster(), position(), cooldown_left(), chip_state(), ...)
    f2. late outcome:  if a Fatal latched during f, run the outcome step d now (once per latch)
    g. frame end:      if cancel() was requested: resolver.cancel(); gate.forget_open_presses(); after a resize, swap FieldSpace
 2. AppRoot end of frame: Fatal latch first (fatal screen), else Retry latch (ADR-0008 owns the rebuild)
```

The step order is fixed and is the only order the game relies on.

### 3. Ticks and the clamp
- `DT = 1.0 / 60.0`, a constant in `Battle`. 60 per second matches the Data GDD's one-tick interval floor. It is a structural constant, not a catalogue value.
- The wrapper keeps `accumulator: float`. Each frame with the clock running: `accumulator += delta`; `owed = floori(accumulator / DT)`.
  - If `owed <= 5`: run `owed` ticks and `accumulator -= owed * DT`.
  - If `owed > 5`: run 5 ticks and set `accumulator = 0.0`, dropping the rest. When `OS.is_debug_build()`, log the drop with `push_warning`, at most once per second, with the ticks dropped since the last log.
- With the clock stopped (Build, Paused, Won, Lost, Fatal) no tick runs and `accumulator = 0.0`, so no time jump follows Start or resume (Flow Rule 17).
- `battle.tick(dt)` is called only with `DT`. Headless callers (bots, tests, the harness) call `battle.tick(Battle.DT)` directly in a loop; they never pass a frame delta.
- Inside `tick`: `apply_queued()` first (a no-op when the wrapper already drained this frame). If the clock is stopped, `tick` returns right after the drain and does not count (Flow Rule 17). Otherwise it runs the slot order of architecture 3.1 (StageFlow, WaveSim advance, Status, TowerSim, HeroSim then burst, WaveSim reap) (refined by ADR-0004 and ADR-0005), checking `halted()` before the first slot and between slots (GF8), and then increments `tick_count`. So `tick_count` is the number of ticks that ran slots, and a drain always sees the count of ticks already completed, on the headless path and the wrapper path alike.
- **Budget:** 2 ms per tick on the target phone (proposed). Five catch-up ticks are then at most 10 ms of a 16.6 ms frame. The phone spike measures it; if it fails, the cap drops, not the tick rate.

### 4. Commands

Illustrative; each `class_name` lives in its own file. `BattleCommand` is abstract, so tests use the subclasses.

```gdscript
@abstract
class_name BattleCommand extends RefCounted
var on_result: Callable          # optional; checked with is_valid(), called once, then cleared
@abstract func apply(target: Battle) -> int
@abstract func to_record(tick: int, result: int) -> CommandRecord

class_name BuildCommand extends BattleCommand          # slot_index: int, tower_id: StringName  -> TowerSim.build
class_name UpgradeCommand extends BattleCommand        # slot_index: int                        -> TowerSim.upgrade
class_name PinCommand extends BattleCommand            # position: Vector2                      -> HeroSim.pin
class_name BurstCommand extends BattleCommand          # aim_point: Vector2                     -> HeroSim.burst
class_name StartNextWaveCommand extends BattleCommand  # (none)                                  -> StageFlow.start_next_wave; returns OK
class_name ResumeCommand extends BattleCommand        # (none)                                  -> StageFlow.resume; OK, HALTED, NOT_PAUSED (ADR-0008)

# Battle
func enqueue(command: BattleCommand) -> void   # appends; never applies; legal from any handler
func apply_queued() -> void                    # drains in arrival order; called by the wrapper each frame and by tick()
func command_log() -> Array[CommandRecord]    # every drained command, for replay (ADR-0004)
func tick_count() -> int

class_name CommandRecord extends RefCounted     # plain data, no callbacks
var tick: int                # tick_count at the drain
var kind: StringName         # &"build", &"upgrade", &"pin", &"burst", &"start_next_wave"
var args: Array              # values only: int, StringName, Vector2
var result: int              # the code the command returned (HALTED included)
```

- `enqueue` appends and returns. It never runs the command, so no sim code runs on the input call stack, whatever the engine's event order (F1).
- `apply_queued` takes the queue as it stands, empties it, and applies each command in arrival order. A command enqueued during another command's `on_result` waits for the next drain. Each `apply` calls the owner's command from ADR-0002's table and returns its result code. After each command, the drain appends `to_record(tick_count, result)` to the log. The log covers **every** drained command: applied, refused and `HALTED`. A replay rebuilds commands from records, applies each before the same tick, and asserts each result code matches, which is a stronger determinism check than the final state alone (TR-flow-004).
- If `halted()` is true, `apply_queued` applies nothing: each command's `on_result` gets `HALTED`, each is logged with `HALTED`, and the queue empties.
- `on_result` is called synchronously inside `apply_queued`, after the owner's command returns, only if `on_result.is_valid()`, and is then set to an empty `Callable()`. The log never holds a callback, so no record points back at a view or input piece (registry `system_holds_battle`). The HUD and the input pieces use it for refusals: `NO_GOLD` nudges the disc and keeps the arc open, `OK` closes it (HUD Rule 7); a refused pin keeps the ghost (Hero Rule 2). Because commands drain in step 1b and views redraw in step 1f, a refusal shows in the same frame it is applied. This answers Open Question A11.
- The result codes stay each command's own contract (ADR-0002). `on_result` only delivers them.
- Bots and the harness build the same command records and call `enqueue` then `tick`. There is no second path into the simulation.
- `enqueue` replaces architecture 4.3's `enqueue(command: Callable)`.

### 5. The upgrade chip feed (TR-tower-005)
- `ChipWindow` stays a pure object with `advance(ms: float)` (Tower Rule 8).
- TowerInput reads the injected `RealClock.now_ms()` and feeds the difference since its last feed. It feeds **when the release handler runs, before judging the tap**, and again in step 1a each frame. So `elapsed` at a release is exact to the moment the event is delivered (not to the instant the finger lifted, which the engine does not report in the pinned reference), whether delivery comes before or after `step` (F1). The 200 ms guard and the 1500 ms expiry are judged on that value.
- The chip reads real time even while the clock is stopped, because it is a presentation piece in the wrapper, not simulation. It never feeds simulation time.
- A commit tap enqueues `UpgradeCommand`; `upgrade_refused(slot_index)` is emitted from the command's `on_result` on `NO_GOLD` (ADR-0002 table).
- On a focus loss the chip closes (the Paused overlay consumes input), so a long gap in real time cannot commit a stale chip (F2).

### 6. The hero's hit disc (TR-hero-008)
- In step 1e, after the ticks, HeroInput calls `set_centre(hero_target_id, battle.hero().position())` while the hero walks. The next frame's presses test that centre.
- A press freezes its disc at press time (architecture 4.2), so a disc moved by step 1e during a drag changes nothing for that gesture.
- Because commands only enqueue, a pin issued against a disc that moves in the same frame still applies against the hero's state at the drain, never mid-tick.

### 7. The outcome step and the end of frame
- Step 1d runs once per frame, after the ticks, if an outcome or Fatal latched during this frame (inside a tick, inside a command's apply, or from a view's read in the previous step 1f). It stops the clock, emits `phase(Won|Lost|Fatal)` once (the emit exception of ADR-0002 declaration rule 4), and requests `cancel()`. Paused takes the same request (Flow Rule 17).
- Step 1g calls `resolver.cancel()` if requested, then `gate.forget_open_presses()`, then swaps `FieldSpace` after a resize (ADR-0006, ADR-0007). It is never called inside a tick or inside `apply_queued`.
- **A Fatal from a view read in step 1f** latches after step 1d has run. Step 1f2 runs the outcome step for it in the same frame (stop the clock, emit `phase(Fatal)`, request `cancel()`), once per latch, so Flow Rules 15 and 18 ("at the end of that frame") hold and step 2 never shows the fatal screen before `phase(Fatal)`, `cancel()` and the debug log's Fatal record.
- Step 2 is AppRoot's: Fatal first (fatal screen; the debug log's Fatal record is taken here from reads held at the latch, Flow Rule 18), otherwise the Retry latch. How Retry frees and rebuilds is ADR-0008's. Retry's input handler only sets the latch (HUD Rule 18).

### Architecture Diagram

```
input events ----> handlers ----> battle.enqueue(cmd)        (no sim code here)
                         \------> TowerInput.ChipWindow.advance(real ms)

AppRoot._process(delta)
  wrapper.step(delta)
    a chip feed -> b apply_queued (on_result -> HUD) -> c 0..5 x tick(DT) -> d outcome step
    -> e hero set_centre -> f views redraw -> g cancel() if requested
  AppRoot: Fatal latch, else Retry latch
```

### Key Interfaces
`BattleCommand` and its six subclasses (`ResumeCommand` is the sixth, ADR-0008), `CommandRecord`, `Battle.enqueue(command: BattleCommand)`, `Battle.apply_queued()`, `Battle.command_log()`, `Battle.tick_count()`, `Battle.DT`, `StageFlow.clock_running() -> bool`, `RealClock.now_ms() -> int`, `TowerInput.advance_chip(now_ms: int)`, `BattleWrapper.step(delta: float)`.

### Implementation Guidelines
- Only AppRoot drives simulation time. No sim object, input piece or HUD logic may use `_process` or read engine time; the chip reads only the injected `RealClock`. Views may animate in their own `_process`, reading only.
- Input handlers must only enqueue commands, feed the chip, or set latches; they must never call a sim command directly.
- `battle.tick` must only be called with `Battle.DT`.
- The wrapper must call `apply_queued()` every frame, clock running or not, before any tick.
- Code must never call `resolver.cancel()` inside a tick or inside `apply_queued`.
- Every `BattleCommand.apply` override must end in an explicit `return` of its result code (4.7 typed-return rule).
- A test must never pass a real frame delta to `tick`.
- Debug builds (`OS.is_debug_build()`) must log a clamp drop at most once per second; release builds must not.
- Code must check `on_result.is_valid()` before calling it and clear it after.
- The command log must hold only `CommandRecord` values, never a command or a callback.
- Code must leave `Engine.time_scale` at 1.0.

## Alternatives Considered

### Alternative 1: Apply commands only at the start of `battle.tick` (the gate's first wording)
- **Description**: The queue drains as step 0 of each tick.
- **Pros**: One drain point; simplest.
- **Cons**: No tick runs in Build or while paused, so a build in Build never applies; results arrive only when the next tick runs.
- **Rejection Reason**: Breaks Build. This ADR keeps the drain inside `tick` for headless callers and adds the per-frame drain.

### Alternative 2: Apply commands directly on the input call stack
- **Description**: The handler calls `tower.build(...)` at once and gets the result back.
- **Pros**: Instant result, no queue.
- **Cons**: Whether the input stack runs before or after the frame's ticks is unverified (F1, HUD Rule 18), so determinism would rest on it; a command could land between two catch-up ticks if the engine ever interleaves.
- **Rejection Reason**: The gate (GF7) rejected it.

### Alternative 3: `enqueue(command: Callable)`
- **Description**: Queue bound callables, as architecture 4.3 first wrote.
- **Pros**: No command classes.
- **Cons**: The result code is lost; the command cannot be logged with its tick for a replay; a bound callable can reach any method.
- **Rejection Reason**: Fails A11 and ADR-0004's replay.

### Alternative 4: Variable time step (`tick(delta)`)
- **Description**: Run one tick per frame with the real delta.
- **Pros**: No accumulator.
- **Cons**: Results differ by frame rate; the prototype's variable time is why its numbers do not transfer (Flow Rule 4).
- **Rejection Reason**: Breaks determinism and the bots' baseline.

## Consequences

### Positive
- Determinism rests on no engine event order: commands only enqueue, and the drain sits at a fixed step.
- Build works: commands apply every frame, clock running or not.
- A refusal shows in the frame it is applied (A11 closed).
- One code path for humans, bots and tests; the command log gives exact replays.
- The chip is exact to the event's delivery, not to the frame.

### Negative
- Five small command classes and a log.
- A command lands up to one frame later than a direct call would (two if F1 delivers input after `step`).
- Dropping catch-up time means a long stall slows the battle against real time instead of fast-forwarding it.

## Risks
- **F1 input after `step`.** Mitigation: nothing depends on it except latency; the phone spike measures it.
- **F2 monotonic clock across focus loss.** Mitigation: the chip closes on focus loss; a negative or huge difference is clamped to `0..1500` ms.
- **F3 delta after a stall.** Mitigation: the clamp, plus `accumulator = 0` on any clock stop.
- **2 ms per tick fails on the phone.** Mitigation: lower the catch-up cap first; profile the slot order; the budget is recorded in the registry as proposed.
- **A command issued inside another command's `on_result`.** Mitigation: it waits for the next drain, by rule.
- **Views read after a Fatal latched in step 1f.** Mitigation: reads return typed zeros after Fatal (ADR-0001) and step 1d of the next frame runs before any tick.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | Rule 4: time only through `battle.tick(dt)`, fixed rate, clamp (TR-flow-003) | Section 3 |
| game-state-stage-flow.md | Rule 5: fixed order, commands between ticks, identical replay (TR-flow-004) | Sections 2, 4 (`apply_queued`, `command_log`) |
| game-state-stage-flow.md | Rules 15, 17, 18: two-step outcome, end-of-frame `cancel()`, zeroed accumulator on pause | Sections 3, 7 |
| tower-system.md | Rule 8: real-time chip, 200 ms guard, order against input (TR-tower-005) | Section 5 |
| hero-system.md | `set_centre` every frame while walking (TR-hero-008); refused pin keeps the ghost | Sections 4, 6 |
| battle-hud.md | Rule 18: commands from the input stack before the frame's ticks; Retry only latches (TR-hud-003) | Sections 2, 4, 7 |
| battle-hud.md | Rule 7: `NO_GOLD` nudge, `OK` closes the arc | `on_result` (section 4) |

## Performance Implications
- **CPU**: At most 5 ticks per frame at a proposed 2 ms each; commands are a handful per frame. One small object per command.
- **Memory**: The command log grows with the battle: a few hundred small records per stage, kept in memory in every build. Writing it to a file is deferred to the Mobile Platform ADR with the other release file writes (TR-hud-005, TR-hud-008).
- **Load Time**: None.
- **Network**: None.

## Migration Plan
No code exists yet. **These edits land in the same change that marks this ADR Accepted**, as for ADR-0002:

- `docs/architecture/architecture.md`:
  - 3.1: replace "0. apply queued commands" inside `tick` with the frame of section 2 (drain every frame, then ticks, outcome step, hero disc, views, frame end); AppRoot drives `wrapper.step`.
  - 4.3: `enqueue(command: BattleCommand)`, `apply_queued()`, `command_log()`, `DT`; `StageFlow.clock_running()`.
  - 4.6: the HUD gets refusals through `on_result`.
  - Open Question A11: closed by ADR-0003.
- `design/gdd/battle-hud.md` Rule 18: "All commands are queued from the input call stack and applied once per frame before the frame's ticks (ADR-0003); the engine order is no longer load-bearing."
- `design/gdd/tower-system.md` Rule 8: the chip is fed at each release and each frame from an injected real-time clock (ADR-0003).
- `docs/architecture/adr-0002-signal-contracts-and-wiring-conventions.md` (Accepted): add a cross-reference note, not a change of decision, that its wording "applied at the start of the next tick" (around lines 48 and 137) is refined by ADR-0003: commands drain once per frame before the ticks, and inside `tick` for headless callers.
- `docs/registry/architecture.yaml`: registered with this ADR's write (see below), as Proposed stances.

## Validation Criteria
- A headless test applies a `BuildCommand` in Build (clock stopped) and sees the tower built with no tick run.
- A replay test runs a scripted battle, replays its `command_log()` on a fresh battle with the same seed, and gets an identical result and counters.
- A clamp test feeds `step(0.5)` and sees exactly 5 ticks and a zero accumulator.
- A chip test with a fake `RealClock` feeds releases at 199, 200, 1499 and 1500 ms and sees ignore, commit, commit, expire.
- A test makes a view read latch a Fatal in step 1f and sees `phase(Fatal)` and the `cancel()` request in the same frame, before step 2.
- A headless test drains a command with the clock stopped and sees the same `CommandRecord.tick` as the wrapper path.
- An `on_result` test sees `NO_GOLD` delivered before the frame's views redraw.
- The phone spike records F1 to F3 and the per-tick time.

## Related
- Architecture: `docs/architecture/architecture.md` 3.1, 3.6, 4.3, 4.6; Gate Finding GF7; Open Question A11.
- ADR-0001 (Accepted), ADR-0002 (Accepted).
- Reviews, 2026-11-02: godot-specialist found no blocking issues; five minor notes folded in (illustrative class block, `on_result.is_valid()`, `time_scale` 1.0, rate-limited debug log, a class-cycle parse check as F4). TD-ADR: CONCERNS, eight items; items 1 to 7 revised in this draft (same-frame late outcome step 1f2, plain `CommandRecord` log with cleared callbacks, tick counting and stopped-clock drains, the ADR-0002 note and registry entries, the narrowed `_process` rule with Retry left to ADR-0008, `RealClock` and "exact to delivery", release log writes deferred); item 8 needed no change.
- Cross-reference to ADR-0004 (Accepted 2026-11-03): the slot loop runs an ordered list of `TickSlot` objects that the builder builds (ADR-0004 section 4). The decision of this ADR is unchanged.
- Cross-reference to ADR-0005 (Accepted 2026-11-03): the slot names are `StageFlow`, `WaveSim.advance`, `Combat.tick_status`, `TowerSim`, `HeroSim`, `WaveSim.reap`. The decision of this ADR is unchanged.
- Cross-reference to ADR-0006 (Accepted 2026-11-03): step 1a also calls `hud.advance(min(delta_ms, 100))`, and step 1g swaps `FieldSpace` and the insets after a forwarded `resized`. The frame order is unchanged.
- Amended 2026-11-03 by ADR-0008 (user sign-off): the command list gains `ResumeCommand` as the sixth subclass; step 1g gains `gate.forget_open_presses()` between `resolver.cancel()` and the `FieldSpace` swap; step 1b loses "(ADR-0008 confirms)". Step 2 order (Fatal, then Retry) is unchanged; the quit check sits between them.
