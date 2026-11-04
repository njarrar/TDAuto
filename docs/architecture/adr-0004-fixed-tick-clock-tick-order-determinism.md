# ADR-0004: Fixed-Tick Clock, Tick Order, Frame Order and Determinism

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
> **Acceptance preconditions.** (1) ADR-0001 and ADR-0003 are Accepted. (2) Verification
> items V1 to V6 (Engine Compatibility) have a recorded result in
> `docs/engine-reference/godot/` (V5 is recorded whatever it shows; the others may change a
> decision, and where one does, this ADR is revised to that branch first). (3) The user has
> confirmed or overturned each item under "Choices pending user confirmation" (Decision 11),
> one by one, not by approving the ADR whole. Accepting this ADR records technical-director
> acceptance of QQ-08's "one tick order" item, on the user's confirmation.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only. The live Godot 4.7 documentation was not reachable from the authoring session, and no device was available, so every engine behaviour below that the pinned reference does not cover is marked NEEDS VERIFICATION and listed in V1 to V8.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode.

## Summary

The battle must advance in fixed, reproducible steps that humans, bots and tests share, with one tick order, player commands only between ticks, real-time presentation clocks kept outside the simulation, and results that depend only on `(catalogue, stage_id, rng_seed, command script)` on a given CPU architecture. This ADR decides a 60 Hz tick driven by a pure `BattleClock` accumulator in `BattleWrapper._process` (not `_physics_process`), a catch-up clamp of `MAX_TICKS_PER_FRAME = 3` that drops any further backlog so the game slows rather than jumps, a stall rule and a backlog drop around Paused, one fixed frame order (adapter flush, real-time models, ticks, views), the Data Flow 2 tick order run inside a gated `Battle.tick`, one `SimTime.to_ticks` conversion with explicit half-away-from-zero rounding, an integer-only seeded `SimRng` kept apart from cosmetic randomness, and a float policy with bot baselines kept per CPU architecture.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core (main loop timing, GDScript numerics) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (post-cutoff version; the main loop, frame timing, `delta`, the physics step settings, `RandomNumberGenerator` and numeric behaviour are all absent from the pinned reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` (`Time.get_ticks_msec()` replaces `OS.get_ticks_msec()`; `$NodePath` in `_process()`), `current-best-practices.md`, `modules/physics.md` (checked: the sim uses no physics, so the Jolt rows do not apply), `modules/input.md` (its only `_physics_process` example is a movement sample, not a timing statement). No `modules/` file covers the main loop, scripting or numerics. Binding ADRs read: ADR-0001, ADR-0003 (Spike items, Decisions 2, 6, 9), ADR-0005 (Performance), ADR-0009 (Engine Compatibility, Decisions 2, 7, 9). |
| **Post-Cutoff APIs Used** | None. One 4.7 language rule applies: an override of a typed-return method inherits the return type and needs an explicit `return` (`breaking-changes.md`, 4.6 to 4.7). It affects every test spy that subclasses `SimRng`, `SimTime` or `BattleClock`. |
| **Verification Required** | V1 to V8 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: when input events are delivered against `_process`; the order of `_process` and `_physics_process` callbacks; what `delta` holds after a main-thread stall or a return from the background, and whether the engine caps it; whether `Engine.time_scale` scales `delta`; `Engine.max_physics_steps_per_frame` and `physics/common/physics_ticks_per_second` behaviour; the frame cadence on 90 and 120 Hz phones and any frame-rate cap key; the algorithm, seeding and cross-platform reproducibility of `RandomNumberGenerator` and of the global `randi()`/`randf()`; that GDScript `float` is IEEE-754 binary64 and `int` is 64-bit two's complement; whether `float` results differ between x86-64 and ARM64 builds of the engine; how to read the CPU architecture at run time; `Time.get_unix_time_from_system()`. The design is chosen so that only V1, V2 and V6 can change a number or a branch; the rest confirm assumptions the rules already guard. |

> **Note**: If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated if the
> project upgrades engine versions. Flag it as "Superseded" and write a new ADR.

### Verification items

Each item names the expected result (unsourced, from pre-cutoff knowledge only), the method, the owner, and what this ADR does for each outcome. The gap is wired to acceptance (Status note): this ADR stays `Proposed` until V1 to V6 have recorded results.

- **V1. Input against `_process` (reuses ADR-0003 SP1; no new kit item).** Expected: every input event is delivered between frames, before the next frame's `_process`. ADR-0003 Decision 2 queues every resolver call and `adapter.flush()` drains the queue in frame step 0, so SP1 decides only latency, never order: an event delivered after the wrapper's `_process` waits one frame for the next `flush()`, in order, and still runs before that frame's ticks. SP1 also logs `PHYS` markers, so it records the `_process` and `_physics_process` order as a by-product; this ADR does not rely on that order (Decision 1). Neither outcome changes this ADR. Owner: as ADR-0003 SP1.
- **V2. `delta` on a stall and on return (reuses ADR-0003 SP11; adds proposed kit item SP14).** Expected: after a main-thread stall of T ms, the next `_process` `delta` is about T ms and is not capped by the engine; on return from the background the first `delta` is large (SP11 already records it). *If the engine caps `delta`*: the clamp and the stall rule (Decision 2) still hold; record the cap. *If `delta` is 0 or negative on return*: the clock runs no ticks that frame, which is already the rule. Proposed SP14 (the kit is not edited by this ADR; ADR-0003's owner adds it; SP13 is already ADR-0003's focus item): a "Stall" action that blocks the main thread for 300 ms and for 1000 ms (`OS.delay_msec`, itself unsourced) and logs the next two `PROC` `delta_ms` values; plus a 10-second steady log of every frame's `delta_ms` (V3). Owner: the user runs the kit; godot-specialist records the result.
- **V3. Frame cadence (proposed kit item SP14, same run).** Expected: on a 60 Hz phone `delta` stays near 16.7 ms; on a 90 or 120 Hz phone `_process` runs at the display rate, so some frames owe 0 ticks. Record the distribution, `Engine.max_fps` (already in the kit's start-up `INFO runtime` line), and whether enemy movement looks uneven. *If it looks uneven on a 90 or 120 Hz phone*: a follow-up decides between capping the frame rate at 60 (the key is unsourced; find it in the editor's Project Settings) and view interpolation (Alternative 7). No sim change either way. Owner: as V2.
- **V4. Numeric golden values (headless unit test, plus proposed kit item SP15 for the phone).** Expected: GDScript `float` is IEEE-754 binary64 (`0.1 + 0.2 == 0.30000000000000004` reads true; `16777217.0 + 1.0 == 16777218.0` reads true); `int` is 64-bit two's complement (`-1 & 0xFFFFFFFF == 4294967295`; `(0xFFFFFFFF << 13)` does not overflow); `floor`, `int()` (truncates toward zero), `sqrt`, `absf`, `is_finite` behave as IEEE; `SimTime.to_ticks` gives every value in the GDD tables (Validation 3); `SimRng.new(1)` gives `270369, 67634689, 2647435461`, `SimRng.new(0)` gives `1085196063, 2447379481, 2618286376` and `SimRng.new(-1)` gives `253983, 4228382207, 1958451267` (computed for this ADR in IEEE double and Python integers, not in Godot). Also record which call names the CPU architecture (`OS.has_feature("x86_64")`, `OS.has_feature("arm64")` or another; unsourced) for the baseline key (Decision 9). Proposed SP15: the same script as a kit action on the phone, printing one digest line. *If any golden value differs on desktop*: stop; Decisions 6, 7 and 9 are revised before any sim story. *If it differs only on the phone*: Decision 9's per-architecture baselines already cover it; record which operation differs. Owner: gameplay-programmer (desktop test in the first Foundation story); the user runs SP15.
- **V5. Cross-architecture sim equality (informational).** Run the Validation 6 determinism script on x86-64 (CI) and on ARM64 (the user's Mac if it is Apple Silicon, and the first Android build), and compare the per-tick digests. Expected: unknown; equality is likely for the operations Decision 9 allows, but nothing here depends on it. Either result is recorded; baselines stay per architecture (TR-combat-014). Method: the first phone build carries a development-only bot-run entry (ADR-0007 and ADR-0010 own it). Owner: performance-analyst.
- **V6. Whole-tick cost sets `MAX_TICKS_PER_FRAME` (reuses ADR-0009 V4; QQ-11).** Measure one whole `battle.tick` at the worst case (48 alive enemies, five towers, hero and burst release) on the low-end Android device (Adreno 5xx class): median and 99th percentile over at least 1,000 ticks. Then set `MAX_TICKS_PER_FRAME = clamp(floor(4.0 ms / p99_tick_ms), 2, 4)` (Decision 2). *If p99 is above 2.0 ms*: N = 2 does not fit Data Flow 10; apply ADR-0009 Decision 9's other levers (bucketing inside the helpers, reused allocations) and ADR-0005's flat stat table, then re-measure. N never goes below 2 (Decision 2). Also measure the Data Flow 10 slices with development-only timers in the wrapper (Decision 10). Owner: performance-analyst at the first phone build.
- **V7. Pause notification against the first frame after return (reuses ADR-0003 SP10 and SP11).** Expected: the notifications arrive before the first `_process`. *Either way* the stall rule and the backlog drop around Paused (Decision 3) mean no sim time passes that the player did not see, except at most `MAX_TICKS_PER_FRAME` ticks in SP10 Branch C on a frame whose `delta` is below the stall threshold. Record the result; no branch here changes this ADR.
- **V8. Session seed source.** `Time.get_unix_time_from_system()` exists on 4.7.2 and returns seconds as a `float`. Expected: yes. *If not*: AppRoot uses `Time.get_ticks_msec()` (sourced name, `deprecated-apis.md`) instead. That value varies little between launches, which is acceptable because no MVP rule reads randomness (Decision 7). Method: the first AppRoot story parses and logs it. Owner: gameplay-programmer.

Not relied on, so not verified: the order of `_process` and `_physics_process` (no `_physics_process` exists in `src/`); `Engine.max_physics_steps_per_frame` and `physics_ticks_per_second` (left at their defaults; the sim uses no physics, Flow Rule 4); `RandomNumberGenerator` reproducibility (the sim never uses it; cosmetic randomness needs none); `Dictionary` iteration order (the sim never depends on it, Decision 9); the order in which sibling nodes' `_process` callbacks run (only one node in the battle subtree runs per-frame code, Decision 5).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed): `Battle.tick(dt)` gated inside, `halted()`, `BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler)`, `rng_seed` chosen once per session and reused on retry, method Callables only, `BattleWrapper.attach`/`detach`, no autoloads, no mutable `static var`. ADR-0003 (Proposed): the queued adapter with `adapter.flush()` as frame step 0 (Decision 2), SP1, `lifecycle_paused` into `Flow.pause`, SP10 and SP11 results. Both must be Accepted before this ADR is implemented. Also binding and not redecided: ADR-0005 (stat reads at use time; 0.5 ms per-tick read ceiling) and ADR-0009 (float-pair positions, `advance()`/`reap()`/`tick_status(roster)`, whole-tick budget note in Decision 9, no per-tick allocation beyond the per-hit ones). |
| **Enables** | ADR-0006 (signals emitted inside a tick follow this order; `phase_changed` gains the wrapper as a listener), ADR-0007 (determinism test, numeric golden test, lint rules for engine time and randomness in the sim), ADR-0010 (command script format keyed by `ticks_run()`, bot equivalence on the fixed tick, optional `between_ticks()` check), ADR-0011 (views refresh in frame step 4; no interpolation at MVP). |
| **Blocks** | Game State & Stage Flow epic (Flow tick, intermission countdown, pause), Enemy & Wave epic (schedule ticks, advance and reap slots), Tower epic (cooldown ticks, ChipWindow feed), Hero epic (HeroSim slot, HeroInput `update()`), Battle HUD epic (`advance(ms)`, displayed bonus), every bot gate (re-baselined on the fixed tick). The Combat epic's `tick_status` and `to_ticks` stories. |
| **Ordering Note** | Draft after the ADR-0003 spike has run if possible: V1, V2 and V7 reuse its log. The decision does not change with SP1's result, so drafting before the spike is safe; acceptance is not. ADR-0009 Decision 9 defers `MAX_TICKS_PER_FRAME` here; V6 sets the final value. This ADR owns QQ-01, the float policy part of QQ-05, the frame-split part of QQ-11 (ADR-0011 owns draw calls), and QQ-08's tick-order item. |

## Context

### Problem Statement

Five GDDs (Game State, Combat, Enemy & Wave, Tower, Hero) assume one fixed tick, one tick order and commands between ticks, and two (Battle HUD, Tower) need real-time clocks that keep running while the simulation is stopped. The prototypes used variable time for humans and 1/30 s for bots, so their numbers do not transfer and "5.0 s" took 301 ticks (Game State Rule 4). Every bot gate, every to-the-tick acceptance criterion and the "displayed bonus equals paid bonus" rule (TR-hud-005) depend on decisions nobody has made yet: which engine callback drives time, at what rate, how a long frame is handled, in which order a frame runs, how seconds become ticks, where randomness comes from and how far float results can be trusted. They must be fixed before the first sim story, because every sim class's tick method and every test fixture encodes them.

### Current State

No code exists. `architecture.md` states working defaults: Data Flow 1 (frame order), Data Flow 2 (tick order), Data Flow 6 (pause), Data Flow 10 (frame budget), B4, B5 and B9, all marked ADR-pending. ADR-0001 fixed `Battle.tick(dt)` with the gate inside and left the clock, the order and the seed refinement to this ADR. ADR-0003 queues every resolver call for `flush()` at frame step 0 (its Decision 2) and asked this ADR to handle the first frame after a resume (SP11). ADR-0009 cited the tick order as a default and deferred `MAX_TICKS_PER_FRAME` and the float policy here.

### Constraints

- Godot 4.7.2, GDScript, main thread only; no thread may be added without an ADR (Data Flow preamble).
- No autoloads, no mutable `static var`, method Callables only, no lambdas or `bind()` (ADR-0001).
- Gameplay classes never read `Engine`, `Time`, `OS`, a timer or `await` (B4 invariant), and use no `_process` or physics areas (Flow Rule 4).
- The sim runs headless with no scene: bots and tests call `battle.tick` directly (Flow Rule 2).
- `project.yaml`: 60 fps target (16.6 ms), 30 fps floor on low-end Android, Adreno 5xx class.
- The Data & Config validator's interval floor is one tick, 1/60 s (Data & Config field domains).
- Solo, part-time developer: one clock, one order, small classes, nothing that needs an editor to test.
- Engine timing and numeric facts are unsourced (V1 to V8).

### Requirements

- Simulation time enters only through `battle.tick(dt)` at a fixed rate; the wrapper clamps owed ticks (TR-state-003).
- One documented tick order; commands only between ticks (TR-state-004, TR-combat-009, TR-enemy-003, TR-tower-005, TR-hero-003).
- Randomness only from the injected seed; waves use none; cosmetic randomness is separate (TR-state-005, TR-enemy-007).
- Outcomes stop the clock at once and the rest of the tick is skipped (TR-state-007); Flow is a pure machine with a readable result (TR-state-006).
- One `to_ticks`, halves away from zero; integer countdowns; absolute spawn schedule (TR-state-012, TR-enemy-002).
- Real-time presentation clocks outside the sim, frozen while Paused where the GDD says so (TR-state-014, TR-tower-010, TR-hero-011, TR-hud-007).
- Pause stops sim time exactly; Build runs no ticks, Intermission does (TR-hero-013).
- Frame order: input commands, real-time models, ticks, views (TR-hud-005).
- Determinism per CPU architecture, baselines per architecture; PinGeometry in float scalars (TR-combat-014, TR-hero-006).
- Fit Data Flow 10's 4.0 ms simulation slice at 60 fps, including the catch-up frames (QQ-11).

## Decision

### 1. Tick driver: a pure accumulator in `BattleWrapper._process`

The simulation is advanced by `BattleWrapper._process(delta)` through a pure `BattleClock` (`src/root/battle_clock.gd`, `extends RefCounted`, no scene, unit-testable). `_physics_process` is not used anywhere in `src/`, and `physics/common/physics_ticks_per_second` and `Engine.max_physics_steps_per_frame` are left at their defaults and never read. No `Timer` node, `SceneTree.create_timer`, `Tween` callback, `await` or `Engine.time_scale` drives or scales sim time. Headless, there is no clock: bots and tests call `battle.tick(battle.sim_time.dt)` themselves.

Why `_process`: one callback per frame holds the whole frame order (Decision 5) in one function this project controls, so the order does not depend on how the engine interleaves physics steps with input and `_process` (unsourced, V1), and the clamp is ours to test headless.

### 2. Rate, clamp and stall

- **Rate.** 60 ticks per second. `SimTime.TICKS_PER_SECOND := 60` (a `const`), `dt = 1.0 / 60.0`. This is an engine constant, not a catalogue value (Game State Formulas). The Data & Config interval floor (1/60 s) is tied to it: changing the rate changes that floor in the same change.
- **Clamp.** `BattleClock.MAX_TICKS_PER_FRAME := 3`, a working default until V6. It covers the 30 fps floor (2 ticks a frame) with one tick of jitter, so the game keeps real-time speed down to 20 fps and slows below it. V6 sets the final value with `N = clamp(floor(4.0 ms / p99_tick_ms), 2, 4)`. N is never below 2, or a phone at the 30 fps floor would run at half speed.
- **Backlog.** When a frame owes more than N ticks, N run and the backlog beyond one tick is dropped: the game slows rather than jumps (Game State Edge Cases). One tick of carry is kept so frame jitter at 30 fps does not lose ticks.
- **Stall.** A frame whose `delta` is above `BattleClock.STALL_SECONDS := 0.5` runs no ticks and zeroes the accumulator. Such a frame is a suspension, a debugger break or a window drag, not play; running N ticks the player never saw would be worse than running none. This also covers ADR-0003 SP11's case of a `_process` that runs before the resume notifications (V7).
- **Bad `delta`.** A `delta` that is not finite or not above 0 runs no ticks and changes nothing.

`BattleClock.advance(delta)` returns the number of ticks to run this frame:

```
if not is_finite(delta) or delta <= 0.0:   return 0
if delta > STALL_SECONDS:                  _acc = 0.0; return 0
_acc += delta
var owed := int(floor(_acc * float(_ticks_per_second)))
var run := mini(owed, MAX_TICKS_PER_FRAME)
_acc -= float(run) * _dt
if run == MAX_TICKS_PER_FRAME:             _acc = minf(_acc, _dt)   # drop backlog beyond one tick
return run
```

The clock's float arithmetic affects only how ticks line up with frames, never a sim result: a human's command timing is not reproducible anyway, and bots and tests do not use the clock.

### 3. The in-sim gate, outcomes and Paused

`Battle.tick(dt)` (ADR-0001) runs these checks first, in this order, and returns at once if any fails:

1. Not already inside a tick (a re-entrant call calls `dev_error` and returns).
2. `dt == sim_time.dt` exactly. A caller passing another `dt` (the prototype's bots used 1/30) calls `dev_error` and returns. `dt` is fixed at build.
3. `halted()` is false.
4. `flow.phase()` is `WAVE` or `INTERMISSION`.

So Build, Paused, Won, Lost and Fatal run no ticks, headless included, and Intermission runs them (TR-hero-013, TR-tower-005). "Stop the clock" in Flow Rule 15's commit order needs no separate step: the gate reads the phase, so sim time stops the moment Flow commits the state, before `cancel_input()` and before `phase_changed` is emitted (TR-state-007). Resume restores the remembered phase, and walk, telegraph, cooldowns and countdowns continue from exactly where they stopped, because no tick ran in between and every countdown is an integer (TR-hero-013).

The wrapper's clock keeps running while the gate is closed; the ticks it owes are calls that return at once. The wrapper connects `flow.phase_changed` to its own `_on_phase_changed(value)` (method Callable, disconnected in `detach()`), which calls `clock.drop_backlog()` when the new phase is `PAUSED` and when the previous phase was `PAUSED`. Entering Paused zeroes the accumulator (Flow Rule 17); leaving it zeroes it again, so the first frame after a resume tap carries nothing from before. `drop_backlog()` only zeroes the accumulator; it is not a reset of a battle system (the `in_place_reset` ban applies to sims), and the clock is rebuilt with each wrapper anyway.

### 4. The one tick order

Inside the gate, `Battle.tick` runs these steps, in this order, every tick, Intermission included. This is `architecture.md` Data Flow 2 and Combat Rule 11, ratified here; Game State Rule 5, Enemy & Wave Rule 12, Tower Rule 9 and the Hero GDD's "Tick" list cite it and do not restate it.

```
1. flow.tick()                               intermission countdown, wave start
2. enemy_wave.advance()                      spawn from the absolute schedule, move, leak
3. combat.tick_status(enemy_wave.roster())   slow countdown over the roster
4. tower_sim.tick()                          by ascending slot index
5. hero_sim.tick()                           walk, attack, cooldown, telegraph, release (burst after hero)
6. enemy_wave.reap()                         corpses in spawn_id order, enemy_killed(bounty), clear check
```

- Before each of steps 2 to 6, `Battle.tick` checks `halted()` and returns if true. Each system also checks `halted()` after every accessor read and every signal it emits (ADR-0001, ADR-0009), so an outcome or a fatal committed mid-step stops the rest of that step too. Leaks resolve in step 2, before any fire, so a fatal leak pays no bounty (Game State Rule 14).
- After step 6 the tick counter `_ticks_run` rises by one. `ticks_run()` counts ticks that passed the gate; Build, Paused and terminal calls do not count. It is the index a bot's command script uses (ADR-0010) and the tick number in the dev run log.
- Order inside each step belongs to the owning ADR or GDD: spawn order and `spawn_id` (ADR-0009, Enemy & Wave Rule 8), slot order (Tower Rule 9), the hero's sub-steps (the Hero GDD's "Tick" list). No step may call another system's tick entry, and no listener of a signal emitted inside a tick may call a tick entry or a command (ADR-0006 owns the listener rule).
- Adding a tick entry (a Vertical Slice system) means editing this list in a superseding ADR and in Data Flow 2, never inserting a call from inside another system.

### 5. Frame order

`BattleWrapper._process(delta)` is the only per-frame code in the battle subtree. No node under the wrapper other than the `InputAdapter` (and only if ADR-0003 SP12 shows that `size_changed` does not fire, for its size poll) overrides `_process` or `_physics_process`; views and the HUD refresh when the wrapper calls them. The order of sibling `_process` callbacks therefore never matters. One frame:

```
(engine) input callbacks: InputAdapter (_input, _unhandled_input, _notification); Paused and Result Controls
          └─ adapter queues press/move/release (no resolver call yet); a lifecycle loss calls cancel_all() and
             lifecycle_paused ─► Flow.pause() at once; a modal Control's tap (resume, Retry latch) acts here
BattleWrapper._process(delta):
  0. adapter.flush()                 queued resolver calls ─► gesture signals ─► HeroInput / TowerInput / HudLogic
                                     ─► commands (pin, burst, build, upgrade, start_wave, call_early)
  1. real-time models                frame_ms = (delta finite and > 0) ? delta * 1000.0 : 0.0
       hud_logic.advance(frame_ms); tower_input.advance(frame_ms)  (feeds its ChipWindow); hero_input.update()
  2. clock                           var n := clock.advance(delta)
  3. ticks                           for i in n: battle.tick(battle.sim_time.dt)
  4. views                           refresh view-models from read-only queries; queue_redraw()
(engine) render
```

Rules:

- **Commands only between ticks.** Gesture commands run in step 0, from the resolver signals `flush()` produces. `Flow.pause()` runs from the lifecycle notification, `Flow.resume()` from the Paused screen's `_gui_input`, both engine callbacks outside `_process`. A command from step 1 would also be between ticks, but no GDD has one. Nothing runs a command from step 3. Nothing inside `Battle.tick` issues a command. `Battle.between_ticks() -> bool` (false only while a tick runs) is exposed so ADR-0010 can make commands check it in development builds.
- **Displayed equals paid (TR-hud-005).** Step 4 of frame F draws the Call bonus from `intermission_left` after frame F's ticks. The player's tap is queued by the adapter and reaches the HUD in frame F+1's step 0, before frame F+1's ticks, so `call_early` reads the same `intermission_left` the player saw, and the bonus paid is the bonus shown. The same holds for costs, cooldowns and `targets()`. This relies on `flush()` running in step 0 (ADR-0003 Decision 2) and on render following `_process` (SP1's log); a late event only moves the tap to the next frame's step 0, which keeps the rule.
- **HeroInput's centre (Hero Rule 15).** `hero_input.update()` in step 1 sets the hero's hit-disc centre from the position after frame F's ticks, which is the position drawn in frame F, so the disc a finger touches is the hero the player sees.
- A frame in which the gate is closed still runs steps 0, 1 and 4.

### 6. Time conversion: one `to_ticks`, integer countdowns

`SimTime` (`src/foundation/sim_time.gd`, `extends RefCounted`) holds `ticks_per_second: int` and `dt: float`, read-only by contract, and is the one conversion from authored seconds to ticks:

```
to_ticks(seconds) = sign(x) * floor(abs(x) + 0.5),  where x = seconds * ticks_per_second
```

- This is Enemy & Wave's `round(seconds / dt)`, rounding halves away from zero, written with the integer rate so that a binary-exact half (0.125 s at 60, 0.375 s at 60, 0.125 s at 4) is exactly `.5` before rounding. For this ADR both forms were computed in IEEE double over 299,999 durations (every 1 ms to 200 s, every 1/8000 s to 12.5 s): they agree on all of them and on every GDD example. The implementation uses `floor`, not `round()`, so it does not depend on `round()`'s unsourced half rule. Non-finite input returns 0 (inputs are catalogue fields, which ADR-0002 rejects when non-finite, or Combat values after its `is_finite` guard).
- The Builder creates one `SimTime.new()` (60) per battle, owned by `Battle` as the read-only member `sim_time`, and injects `sim_time.to_ticks` (method Callable, B9) and the value `sim_time.dt` wherever ADR-0001 B9 and ADR-0009 list them (Flow, Combat, EnemyWave, TowerSim, HeroSim). Tests build `SimTime.new(4)` for the GDDs' `dt` 0.25 fixtures.
- Every countdown is an integer tick counter set once from `to_ticks` and decremented by 1 per tick: `intermission_left`, `cooldown_left`, `attack_left`, `telegraph_left`, `walk_left`, `Status.ticks_left`, the wave's `wave_tick`. No sim code subtracts `dt` from a float duration, ever.
- Spawn ticks come from Enemy & Wave's absolute schedule, `to_ticks(start_delay + i * spawn_interval)`, compared against the integer `wave_tick` (TR-enemy-002).
- Movement is not authored time: Hero's `walk_ticks` uses its own `ceil` with a tolerance (Hero Formulas), and positions advance by `speed * speed_factor * dt` per tick (ADR-0009). Those are the only other float-to-tick or float-times-`dt` uses allowed.
- Display: `seconds = ticks * dt` for payloads such as `wave_called_early(seconds_left)`; the HUD's `display_seconds` uses `sim_time.ticks_per_second` (Battle HUD Formulas).

### 7. Randomness: one seeded `SimRng`, cosmetic randomness apart

- **Sim randomness.** `SimRng` (`src/foundation/sim_rng.gd`, `extends RefCounted`) is a 32-bit xorshift (shifts 13, 17, 5) in integer arithmetic, masked to 32 bits, with no multiplication, so no step can overflow a 64-bit `int` and no float is involved. State is `rng_seed & 0xFFFFFFFF`, with 0 replaced by `0x6D2B79F5`. The Builder creates one `SimRng.new(rng_seed)` per battle, owned by `Battle` as `sim_rng`. It is injected only into a system whose GDD states a random rule. **No MVP GDD has one** (waves are authored, Enemy & Wave Rule 6; targeting breaks ties by `spawn_id`), so at MVP nothing receives it, and `sim_rng.draw_count()` stays 0 through a whole battle. That read is how Enemy & Wave Acceptance 42 ("a spy shows the seed never read") is tested.
- `RandomNumberGenerator`, the global `randi()`, `randf()`, `randi_range()`, `randf_range()`, `randomize()` and `seed()` are never used in sim code. Their algorithm and cross-platform behaviour are unsourced, and an engine upgrade could change them under the bot baselines.
- **Session seed (refines ADR-0001 Decision 2).** AppRoot picks `rng_seed` once per app session as `int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF` (V8), using 1 if that is 0, and reuses it on every retry, so a retry with the same commands replays the same sim. `AppRoot.configure({rng_seed})` overrides it for tests. Development builds write the seed to the run log at each build (ADR-0010). AppRoot is not a gameplay class, so its one `Time` read is allowed.
- **Cosmetic randomness** (Enemy & Wave's ±1.5 px jitter, any VFX) lives only in Presentation. A view that needs it owns its own `RandomNumberGenerator` instance, seeded with a fixed constant so retained screenshots repeat, or derives the offset from `spawn_id` and its own frame count. It never reads `rng_seed`, `sim_rng` or any sim state other than through the read-only queries, and never feeds a value back (TR-enemy-007).

### 8. Real-time presentation clocks

- Real-time models are pure classes with an explicit step: `HudLogic.advance(ms: float)`, `ChipWindow.advance(ms: float)` (held by TowerInput, which exposes `advance(ms)` and forwards it), `HeroInput.update()`. None reads `Engine`, `Time`, a `Timer` or `delta` itself; tests drive them with numbers.
- The wrapper passes the raw frame time in milliseconds (`delta * 1000.0`, or 0.0 for a bad `delta`) in step 1. Each model applies its own GDD's clamp and freeze, not the wrapper: HudLogic clamps to 100 ms per call and ignores `advance` while Paused (Battle HUD Rule 11, Acceptance 12: `advance(5000)` counts 100); ChipWindow has no clamp, because a long frame can only make a chip expire early, the safe direction, and it closes on `phase_changed(PAUSED)` (Tower Rule 8 table).
- Presentation timers that outlive the sim (Lost's 400 ms text delay, Won's 1,000 ms beat, Retry and Start/Call arming at 300 ms) run in HudLogic on `advance(ms)`, so they keep running after Won or Lost while ticks are gated (TR-state-014). Only Paused freezes them.
- A real-time model never issues a command from `advance` or `update`, and never changes sim state.

### 9. Determinism and float policy

**What is promised.** On one CPU architecture and one engine build, the same `(catalogue, stage_id, rng_seed, command script)` gives the same state after every tick, bit for bit: every `pos_x`, `pos_y`, `distance`, `hp`, every counter, every signal payload and the `StageResult`. Across architectures nothing is promised (Combat Edge Cases; V5 records what is true), so bot baselines are stored and compared per architecture (TR-combat-014).

**Float policy for sim code** (`src/core/`, `src/feature/` sim classes, `src/foundation/` sim helpers, `src/root/battle.gd`):

1. Numbers are GDScript `float` (binary64, V4) and `int`. Sim positions are float scalar pairs (ADR-0009 Decision 2; `Vector2` only at the boundaries it lists). PinGeometry uses float scalars only (TR-hero-006).
2. Allowed operations on values that reach sim state: `+`, `-`, `*`, `/`, `sqrt`, `absf`, `minf`, `maxf`, `clampf` (and the int forms), `floor`, `ceil`, `int()` truncation, comparisons, `is_finite`. IEEE-754 makes each of these correctly rounded, so they are the ones most likely to agree across CPUs.
3. Forbidden on values that reach sim state: `sin`, `cos`, `tan`, `atan2`, `pow`, `exp`, `log`, `fmod`/`fposmod`, `lerp`, `move_toward`, `snapped`, any `Vector2`/`Vector3` method, and `round()` (whose half rule is unsourced). Transcendental functions come from the platform maths library and may differ by CPU and OS. A GDD that needs one must name it, and a superseding ADR decides.
4. Time is integer ticks (Decision 6). No float time accumulates in the sim.
5. Exact float comparison is allowed where a GDD states an inclusive or exclusive edge (range tests on squared distances, ADR-0009) or a tolerance (Hero's `walk_ticks`, PinGeometry margins). Everywhere else compare integers.
6. Order never comes from anything that differs between runs: no `Dictionary` iteration where order matters (iterate arrays in `spawn_id` or slot order; dictionaries are lookups only), no `get_instance_id()`, object hash or `str(object)` in ordering or in a payload, no threads.
7. No engine time, no frame counts and no randomness other than `sim_rng` in the sim (Decision 1, Decision 7).

**Baselines.** Bot baselines and determinism digests are files under `tests/baselines/<arch>/` (for example `x86_64`, `arm64`; the run-time call that names the architecture is V4's). CI runs on one architecture and compares only against that directory. A missing directory for the running architecture is a NOT ASSESSED result, never a pass. A new architecture's baseline is recorded by a deliberate run and reviewed, never written by the test that compares it. ADR-0007 owns the harness; ADR-0010 owns the bot and script format.

### 10. Frame budget split (QQ-11)

Data Flow 10 is confirmed as the proposal, with the clamp's numbers filled in. All figures are unmeasured until V6.

| Slice | Budget at 60 fps | With this ADR |
|---|---|---|
| Input, resolver, commands (steps 0 and the input callbacks) | 0.5 ms | One finger; small event counts |
| Real-time models (step 1) | inside the 0.5 ms above | Three small updates |
| Simulation ticks (steps 2 and 3) | 4.0 ms total | Normal frame: 1 tick. At the clamp: 3 ticks, so one worst-case tick must fit **1.33 ms** (4.0 / N). ADR-0005's 0.5 ms stat-read ceiling sits inside that tick. At the 30 fps floor a normal frame runs 2 ticks in a 33.3 ms frame |
| Views and HUD (step 4 and `_draw`) | 3.0 ms | ADR-0011 owns draw calls |
| Engine, render submit, OS | 7.0 ms | Mobile renderer, 2D only |
| Headroom | 2.1 ms | Kept for allocation spikes |

Development builds time steps 0 to 4 in the wrapper (the wrapper is not a gameplay class, so reading `Time` there is allowed) and write the per-step figures to the run log, so V6 has the slice data as well as the whole-tick cost. Release builds do not time.

### 11. Choices pending user confirmation

This ADR was drafted in autonomous mode. Each choice below is the recommended option; the user confirms or overturns each one before acceptance (Status note).

1. **60 Hz tick** (Decision 2), against 30 Hz (half the cost, but the Data & Config floor and every GDD example assume 1/60) and 120 Hz (double the cost).
2. **`_process` accumulator, no `_physics_process`** (Decision 1).
3. **`MAX_TICKS_PER_FRAME = 3`**, range 2 to 4 set by V6; the game slows below 20 fps (Decision 2).
4. **A frame over 0.5 s runs no ticks** (Decision 2). Stronger than Game State's "clamps, so the game slows": a stall freezes game time instead of running 3 ticks.
5. **Backlog beyond one tick is dropped** at the clamp; there is no catch-up burst (Decision 2).
6. **Backlog dropped on entering and on leaving Paused** (Decision 3). Flow Rule 17 names only the entry.
7. **`Battle.tick` rejects a `dt` that differs from the build `dt`** (Decision 3).
8. **Own integer PRNG (`SimRng`, xorshift32)** instead of `RandomNumberGenerator`, with no MVP consumer (Decision 7).
9. **Session seed from the wall clock**, logged, reused on retry (Decision 7).
10. **`to_ticks` written as `floor(|seconds * rate| + 0.5)` with sign** instead of the GDD's `round(seconds / dt)` text; same results on every tested value (Decision 6). The Enemy & Wave Formulas text gains an implementation note.
11. **No `round()`, transcendental functions or `Vector2` methods in sim values** (Decision 9).
12. **HudLogic and ChipWindow get raw frame ms; each applies its own GDD clamp; ChipWindow has none** (Decision 8).
13. **No view interpolation and no frame-rate cap at MVP**; V3 decides whether 90 and 120 Hz phones need either (Alternative 7).

### Architecture Diagram

```
 Godot main loop (one frame)
 ├─ input callbacks ─► InputAdapter queue · lifecycle loss ─► cancel_all(), Flow.pause() · Paused tap ─► Flow.resume()
 │                                                                         (queued; pause and modal taps act at once)
 ├─ BattleWrapper._process(delta)          ← the only per-frame code in the battle subtree
 │    0  adapter.flush() ─► resolver ─► gesture commands (between ticks)
 │    1  hud_logic.advance(ms) · tower_input.advance(ms) ─► ChipWindow · hero_input.update()
 │    2  n = BattleClock.advance(delta)     clamp N = 3 · stall > 0.5 s ─► 0 · backlog dropped
 │    3  n × battle.tick(sim_time.dt)
 │         ┌─ gate: not re-entrant · dt == sim_time.dt · !halted() · phase ∈ {WAVE, INTERMISSION}
 │         ├─ 1 flow.tick()
 │         ├─ 2 enemy_wave.advance()           ── halted()? return
 │         ├─ 3 combat.tick_status(roster())   ── halted()? return
 │         ├─ 4 tower_sim.tick()               ── halted()? return
 │         ├─ 5 hero_sim.tick()                ── halted()? return
 │         ├─ 6 enemy_wave.reap()              ── halted()? return
 │         └─ ticks_run += 1
 │    4  views refresh (read-only) · queue_redraw()
 └─ render

 Flow.phase_changed(PAUSED) or leaving PAUSED ─► BattleWrapper._on_phase_changed ─► clock.drop_backlog()

 Battle (built by BattleBuilder)                 Presentation only
 ├ sim_time: SimTime (60, dt, to_ticks) ─► injected to_ticks / dt     view RandomNumberGenerator (fixed seed)
 └ sim_rng:  SimRng(rng_seed)  ─► no MVP consumer; draw_count() == 0  never reads rng_seed or sim_rng
```

### Key Interfaces

```gdscript
# src/foundation/sim_time.gd
class_name SimTime extends RefCounted
const TICKS_PER_SECOND := 60
var ticks_per_second: int          # read-only by contract; >= 1
var dt: float                      # 1.0 / ticks_per_second; read-only by contract
func _init(p_ticks_per_second: int = TICKS_PER_SECOND) -> void
## Whole ticks for an authored duration: x = seconds * ticks_per_second,
## sign(x) * floor(abs(x) + 0.5). Non-finite input returns 0.
func to_ticks(seconds: float) -> int

# src/foundation/sim_rng.gd
class_name SimRng extends RefCounted
func _init(rng_seed: int) -> void  # state = rng_seed & 0xFFFFFFFF; 0 becomes 0x6D2B79F5
func next_u32() -> int             # xorshift32 (13, 17, 5), result in 0 .. 4294967295
func next_below(n: int) -> int     # n >= 1; next_u32() % n (modulo bias accepted and documented)
func draw_count() -> int           # calls to next_u32 so far

# src/root/battle_clock.gd   (pure; owned by BattleWrapper; absent headless)
class_name BattleClock extends RefCounted
const MAX_TICKS_PER_FRAME := 3     # working default; V6 sets 2 to 4
const STALL_SECONDS := 0.5
func _init(ticks_per_second: int) -> void
func advance(delta: float) -> int  # ticks to run this frame (Decision 2)
func drop_backlog() -> void        # zero the accumulator (Paused entry and exit)

# src/root/battle.gd   (adds to ADR-0001's Battle)
var sim_time: SimTime              # read-only member
var sim_rng: SimRng                # read-only member
func tick(dt: float) -> void       # gate then Decision 4 order; the only way sim time advances
func ticks_run() -> int            # ticks that passed the gate
func between_ticks() -> bool       # false only while tick() runs

# src/root/battle_wrapper.gd   (adds to ADR-0001's BattleWrapper)
func _process(delta: float) -> void          # Decision 5, steps 0 to 4
func _on_phase_changed(value: Flow.Phase) -> void   # drop_backlog on PAUSED entry and exit

# Real-time models (owned by their ADRs; this ADR fixes the step signatures)
# HudLogic.advance(ms: float) -> void; TowerInput.advance(ms: float) -> void (forwards to ChipWindow);
# ChipWindow.advance(ms: float) -> void; HeroInput.update() -> void
```

`BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler)` is unchanged (ADR-0001). Names are provisional until ADR-0007 settles the `class_name` collision rule (QQ-16); `BattleClock` replaces the bare "Clock" of `architecture.md` for that reason.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must advance sim time only through `Battle.tick(dt)`; must never call a system's tick entry from anywhere but `Battle.tick`.
- Must never override `_physics_process` in `src/`. Must never override `_process` in `src/` except in `BattleWrapper`, `AppRoot` (ADR-0001) and `InputAdapter` (only for ADR-0003 SP12's size poll).
- Must never use `Timer`, `SceneTree.create_timer`, `await`, `Engine.time_scale`, `Engine.get_*_frames`, `Time.*` or `OS.get_ticks_*` in sim code or in real-time models. `AppRoot` may read `Time` once for the seed; the wrapper may read `Time` in development builds for step timing.
- `Battle.tick` must check, in order: not re-entrant, `dt == sim_time.dt`, `halted()`, phase is WAVE or INTERMISSION; then run the six steps of Decision 4 in order, checking `halted()` before steps 2 to 6.
- Must run the frame in Decision 5's order, with `adapter.flush()` always called in step 0.
- Must never issue a command from inside a tick, from a signal listener, or from a real-time model's `advance` or `update`.
- Must convert every authored duration with the injected `to_ticks`, once, when the countdown starts; must never subtract `dt` from a float duration; every countdown must be an `int`.
- Must never use `round()`, `sin`, `cos`, `tan`, `atan2`, `pow`, `exp`, `log`, `fmod`, `fposmod`, `lerp`, `move_toward`, `snapped` or any `Vector2`/`Vector3` method on a value that reaches sim state.
- Must never iterate a `Dictionary` where the order affects sim state or a payload; must never order by instance ID or object hash.
- Must never use `RandomNumberGenerator`, `randi`, `randf`, `randi_range`, `randf_range`, `randomize` or `seed` in sim code; sim randomness comes only from `Battle.sim_rng`, injected only where a GDD states a random rule.
- Presentation code that needs randomness must own its own `RandomNumberGenerator` and must never read `rng_seed` or `sim_rng`.
- `BattleWrapper.detach()` must disconnect `phase_changed` from `_on_phase_changed` and stop processing (ADR-0001 Decision 6).
- Every test spy that overrides a typed method of `SimTime`, `SimRng` or `BattleClock` must contain an explicit `return` (4.7).
- Bot baselines must live under `tests/baselines/<arch>/`; a test must never write the baseline it compares against.

## Alternatives Considered

### Alternative 1: `_physics_process` as the tick driver
- **Description**: Set `physics_ticks_per_second = 60`, tick the battle from `_physics_process`, and use `Engine.max_physics_steps_per_frame` as the clamp.
- **Pros**: The engine does the accumulation; a familiar pattern.
- **Cons**: The order of input, physics steps and `_process` inside a frame is unsourced (V1), so the frame order of Decision 5 would span callbacks whose order nobody has verified; step 0's `flush()` and the real-time models live in `_process` anyway; the clamp's behaviour on a stall and `max_physics_steps_per_frame` are unsourced; the setting is project-global; the clamp could not be unit-tested headless.
- **Estimated Effort**: Similar code, more verification.
- **Rejection Reason**: It moves the one thing this ADR must fix, the frame order, into engine behaviour nobody can source.

### Alternative 2: One tick per rendered frame (lockstep)
- **Description**: `battle.tick` once per `_process`, no accumulator.
- **Pros**: Simplest; never more than one tick per frame.
- **Cons**: A 30 fps phone runs at half speed, a 120 Hz phone at double speed; durations in seconds lose meaning.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Breaks real-time pacing and the 30 fps floor.

### Alternative 3: Variable `dt` ticks
- **Description**: `battle.tick(delta)` with the frame's real `delta`.
- **Pros**: No accumulator; smooth on any display.
- **Cons**: Results depend on frame timing; countdowns become float subtraction (5.0 s took 301 ticks); bots and humans differ; TR-state-003 and TR-state-012 forbid it.
- **Estimated Effort**: Lower now, far higher in bugs.
- **Rejection Reason**: Destroys determinism.

### Alternative 4: 30 Hz or 120 Hz tick
- **Description**: A different fixed rate.
- **Pros**: 30 Hz halves sim cost; 120 Hz smooths fast displays.
- **Cons**: 30 Hz breaks the Data & Config 1/60 floor and every GDD example; 120 Hz doubles cost against a 4.0 ms slice.
- **Estimated Effort**: Same code; GDD and content changes for 30 Hz.
- **Rejection Reason**: 60 Hz matches the GDDs and the 60 fps target.

### Alternative 5: `RandomNumberGenerator` for sim randomness
- **Description**: One `RandomNumberGenerator` per battle seeded with `rng_seed`.
- **Pros**: Built in; good statistical quality.
- **Cons**: Its algorithm and cross-platform reproducibility are unsourced; an engine upgrade could change the sequence and silently break every baseline; nothing at MVP consumes it.
- **Estimated Effort**: Slightly lower.
- **Rejection Reason**: A 15-line integer generator with a golden-value test is fully specified and can never drift under the project.

### Alternative 6: Keep the whole backlog and catch up
- **Description**: Run N ticks per frame until the accumulator is drained.
- **Pros**: Game time always matches wall time.
- **Cons**: After a hitch the game runs fast for several frames, which reads as a jump; a slow device spirals.
- **Estimated Effort**: Same.
- **Rejection Reason**: Game State Edge Cases: the game slows rather than jumps.

### Alternative 7: View interpolation between ticks
- **Description**: Views draw positions blended between the last two ticks by the accumulator's remainder.
- **Pros**: Smooth motion on 90 and 120 Hz displays.
- **Cons**: Every view keeps a previous position; drawn positions are ones the sim never had, so a hit disc and its drawing can disagree; more code before any device data exists.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Not needed until V3 shows judder; revisit then with a frame-rate cap as the cheaper option.

### Alternative 8: Engine timers for presentation delays
- **Description**: `SceneTree.create_timer` or `Timer` nodes for arming, Lost and Won delays and the chip window.
- **Pros**: Less code.
- **Cons**: Untestable without frames; the GDDs require `advance(ms)` models (Tower Rule 8, Battle HUD Rule 11); timers keep running through Paused unless handled.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Contradicts TR-tower-010, TR-hud-007 and TR-hero-011.

## Consequences

### Positive
- One clock, one gate, one order, one conversion: a sim story never decides any of them.
- The frame order is a single function, and the adapter's queue drains in it, so TR-hud-005 holds whatever SP1 shows.
- The clamp, stall rule and backlog drop are pure and unit-tested headless.
- Bots, tests and the phone run the same ticks; retries replay exactly.
- No engine RNG or transcendental maths sits under a baseline, so an engine patch is less likely to move bot numbers.

### Negative
- Below 20 fps (or 30 fps if V6 forces N = 2) the game runs slow.
- A stall over 0.5 s freezes game time for that frame, so wall time and game time drift apart after hitches (accepted; nothing measures wall time).
- 90 and 120 Hz phones may show uneven motion until V3 decides.
- Sim code gives up `Vector2` methods, `round()` and trig; a future mechanic that needs an angle needs a superseding ADR.
- Baselines must be recorded once per architecture.

### Neutral
- `BattleClock` replaces "Clock" in `architecture.md`; `Battle` gains `sim_time`, `sim_rng`, `ticks_run()` and `between_ticks()`.
- `SimRng` exists with no MVP consumer, held for Vertical Slice rules and for the "seed never read" test.

## Risks
- **V6 shows a worst-case tick over 1.33 ms.** Mitigation: N drops to 2 (2.0 ms per tick); then ADR-0009 Decision 9's bucketing and reused allocations and ADR-0005's flat table. Over 2.0 ms is an escalation to technical-director with the measurements.
- **Floats differ between the CI runner and the user's Mac or phone.** Mitigation: per-architecture baselines; V5 records the size of the gap; outcome-level bot gates (lives, wave reached) can be compared across architectures by hand.
- **A GDScript numeric assumption is wrong (V4).** Mitigation: the golden-value test runs in the first Foundation story, before any sim story; a failure stops the sim epics.
- **Input arrives after `_process` on some platform (SP1).** Mitigation: the queue holds it for the next `flush()`; one frame of latency, order kept; no change here.
- **A later system adds its own `_process`.** Mitigation: an ADR-0007 lint rejects `_process` and `_physics_process` outside the three allowed files.
- **Someone subtracts `dt` from a float.** Mitigation: lint for `-= dt` and `- dt` in sim folders; code review; the GDD drift examples as regression tests.
- **The stall threshold hides a real performance problem.** Mitigation: development builds log every stall frame with its `delta` to the run log.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-003 (Rule 4): sim time only through `battle.tick(dt)` at a fixed rate; no `_process`, Timers, await, wall clock or physics areas in gameplay; the wrapper clamps owed ticks | Decision 1 (`BattleClock` in `BattleWrapper._process`, nothing else drives time), Decision 2 (60 Hz, clamp 3, stall), Implementation Guidelines (bans) |
| game-state-stage-flow.md | TR-state-004 (Rule 5): one fixed documented order; commands only between ticks | Decision 4 (the order), Decision 5 (gesture commands in step 0 after `flush()`, pause and resume from engine callbacks, never in step 3; `between_ticks()`) |
| game-state-stage-flow.md | TR-state-005 (Rule 5): all randomness from the injected seed; stage, seed and script give an identical result | Decision 7 (`SimRng` from `rng_seed`, no engine RNG in the sim), Decision 9 (determinism promise and rules) |
| game-state-stage-flow.md | TR-state-006: Flow is a pure stage state machine with a result readable after the outcome | Decision 3 (Flow is ticked only by `Battle.tick` step 1 and holds no clock; its phase alone opens or closes the gate; the result stays readable because nothing ticks after the outcome) |
| game-state-stage-flow.md | TR-state-007 (Rule 15): committing an outcome sets state, stops the clock, cancels input, then emits; remaining systems skip the tick | Decision 3 (the gate reads the phase, so time stops when state is set), Decision 4 (`halted()` before steps 2 to 6, plus each system's own checks) |
| game-state-stage-flow.md | TR-state-012 (Rule 4): durations become whole ticks through one `to_ticks`; countdowns are integer tick counters | Decision 6 (`SimTime.to_ticks`, injected once per battle; every countdown an `int`) |
| game-state-stage-flow.md | TR-state-014: Lost delay, Won beat and button arming run on the frame clock outside the sim | Decision 8 (HudLogic on `advance(ms)` in frame step 1, running while ticks are gated) |
| combat-damage.md | TR-combat-009 (Rule 11): Flow, Enemy & Wave advance, `tick_status`, towers by slot, hero then burst, reap; leaks before fire | Decision 4 (ratified order; leaks in step 2) |
| combat-damage.md | TR-combat-014 (Edge Cases): determinism per CPU architecture only; baselines per architecture | Decision 9 (promise per architecture, `tests/baselines/<arch>/`, NOT ASSESSED when missing), V4, V5 |
| enemy-wave.md | TR-enemy-002 (Formulas, Rule 8): fixed `dt`, one `to_ticks` rounding halves away from zero; spawn ticks from an absolute schedule | Decision 6 (explicit half-away rounding; schedule compared to integer `wave_tick`; `dt` fixed at build and checked in `Battle.tick`) |
| enemy-wave.md | TR-enemy-003 (Rule 12): two tick entries, advance and reap, in Combat's order; the battle passes the roster to `tick_status` | Decision 4 (steps 2, 3 and 6; `combat.tick_status(enemy_wave.roster())` in `Battle.tick`) |
| enemy-wave.md | TR-enemy-007 (Rule 6): waves use no randomness and never read the seed; cosmetic jitter uses a separate RNG; retry rebuilds identical `spawn_id` and schedule | Decision 7 (`sim_rng` not injected into EnemyWave; `draw_count()` 0 test; cosmetic RNG in views only; seed reused on retry) |
| tower-system.md | TR-tower-005 (Rules 9, 10): towers tick by ascending slot; `cooldown_left` an integer that runs every tick, Intermission included | Decision 3 (gate open in Intermission), Decision 4 (step 4), Decision 6 (integer countdown) |
| tower-system.md | TR-tower-010 (Rule 8): chip window on real time while the sim clock is stopped, via a pure `ChipWindow.advance(ms)` fed by the wrapper | Decision 5 step 1 and Decision 8 (`tower_input.advance(ms)` forwards to ChipWindow; raw frame ms; closes on Paused) |
| hero-system.md | TR-hero-003 (Hero "Tick" list): HeroSim ticks in the Hero-and-burst slot, uses `to_ticks`, returns when halted | Decision 4 (step 5, `halted()` before it), Decision 6 (injected `to_ticks`) |
| hero-system.md | TR-hero-006 (Rule 14, Formulas): PinGeometry in float scalars only, no `Vector2` methods, stated tolerances | Decision 9 (float policy: allowed and forbidden operations; tolerances only where a GDD states them) |
| hero-system.md | TR-hero-011 (Rule 16): HeroInput's aim state and `cooldown_digit()` advance through an explicit `update()` | Decision 5 step 1 (`hero_input.update()` called by the wrapper), Decision 8 |
| hero-system.md | TR-hero-013 (Edge Cases): pause stops the sim clock so walk and telegraph resume exactly; Build runs no ticks, Intermission does | Decision 3 (gate; integer countdowns untouched while Paused; backlog dropped on entry and exit) |
| battle-hud.md | TR-hud-005 (Rules 10, 18): input commands, then real-time models, then ticks, then views, so displayed bonus equals paid bonus | Decision 5 (frame order and the displayed-equals-paid argument; V1) |
| battle-hud.md | TR-hud-007 (Rule 11): arming Hidden, Arming, Armed on `advance(ms)` clamped to 100 ms, frozen while Paused | Decision 8 (raw ms from the wrapper; HudLogic owns the 100 ms clamp and the Paused freeze) |

Also answered: QQ-01 (driver, rate, clamp, stall), QQ-05 (float policy; `Vector2` precision stays ADR-0009 V1), QQ-08 (the one tick order, accepted with this ADR on the user's confirmation), QQ-11 (frame split and the per-tick figure; device numbers through V6), and ADR-0003 SP11's request (Decision 2 stall rule, Decision 3 backlog drop).

## Performance Implications
- **CPU**: The clock is a few float operations per frame. The gate is four checks per tick call. The tick's own cost is the systems' (ADR-0009 V4, V6 here). Worst-case frame: 3 ticks at 1.33 ms each inside the 4.0 ms slice.
- **Memory**: One `SimTime`, one `SimRng`, one `BattleClock` per battle; no per-tick allocation added by this ADR.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

No code exists. Order of first stories: (1) `SimTime`, `SimRng` and the V4 golden-value test, headless; (2) `BattleClock` with unit tests for the clamp, carry, stall, bad `delta` and `drop_backlog`; (3) `Battle.tick` gate and order with recording fake systems (Game State Acceptance 9 and 13 style); (4) the wrapper's `_process` and `_on_phase_changed`, verified by a manual run; (5) the determinism test once two sims exist. Prototype numbers are not carried over; every bot gate is re-baselined on the fixed tick (Game State Rule 4).

**Rollback plan**: The driver is one function in the wrapper and one pure class; moving to `_physics_process` (Alternative 1) changes `battle_wrapper.gd` only. The clamp and stall are constants. Swapping `SimRng`'s algorithm changes one file and every baseline, and needs a superseding ADR. Relaxing the float policy needs a superseding ADR and new baselines.

## Validation Criteria

1. **Clock (headless unit tests).** At 60: `advance(1/60)` gives 1; `advance(1/30)` gives 2; `advance(0.2)` gives 3 and leaves at most one tick of carry; `advance(0.6)` gives 0 and zeroes the accumulator; `advance(0.0)`, `advance(-1.0)`, `advance(NAN)` and `advance(INF)` give 0 and change nothing; 1,800 calls of `advance(1/30)` give 3,600 ticks in total; `drop_backlog()` then `advance(0.01)` gives 0.
2. **Gate (headless).** With recording fake systems: Build, Paused, Won, Lost and Fatal run no step and `ticks_run()` stays 0; Wave and Intermission run all six steps in order; a `halted()` latched by step N's fake stops steps N+1 to 6 (Game State Acceptance 9, 13); `tick(1.0 / 30.0)` on a 60 Hz battle runs nothing and records one development error; a re-entrant `tick` records one.
3. **`to_ticks` (headless).** At 60: 0.9 s is 54, 5.0 s is 300, 1/60 s is 1, 0 is 0; 0.125 s steps give 0, 8, 15, 23; 0.1 s member 3 is 18; 0.025 s is 2. At 4: 0.125 s is 1. `NAN` and `INF` are 0. A float countdown of 5.0 s by repeated subtraction is shown to take 301 ticks, as the regression reason.
4. **`SimRng` (headless).** The golden sequences in V4; `draw_count()` counts; two instances with one seed give one sequence.
5. **Seed never read.** A scripted battle through the Builder with two different seeds gives identical logs and distances, and `battle.sim_rng.draw_count()` is 0 (Enemy & Wave Acceptance 42).
6. **Determinism (headless, ADR-0007 harness).** One `(catalogue fixture, stage, seed, command script)` run twice in one process gives identical per-tick digests (positions, HP, counters, phase, gold) and identical signal logs; the digest is compared against `tests/baselines/<arch>/`.
7. **Pause.** Headless: in each live phase, `pause()`, 100 tick calls, `resume()` leaves every countdown and position unchanged (Game State Acceptance 12). Manual, retained in `production/qa/evidence/`: focus loss mid-walk and mid-telegraph on desktop and phone; on return the hero continues from the same point.
8. **Displayed equals paid.** Manual on desktop and phone: tap Call on the frame the countdown digit changes, 20 times; the gold gained equals the bonus shown every time (dev run log records shown and paid).
9. **Budget.** V6 records the whole-tick p99, the step timings, and the N set from them; Data Flow 10 is updated with measured figures.

The decision is wrong if: a GDD rule cannot be met without a second clock or a different order; bots disagree with themselves on one architecture; or the frame order cannot keep displayed and paid values equal.

## Related

- Depends on ADR-0001 (Battle, Builder, wrapper, seed policy it lets this ADR refine) and ADR-0003 (queued adapter and `flush()` at step 0, lifecycle pause, SP1, SP10 and SP11). Binding: ADR-0005 (per-tick read ceiling inside the 1.33 ms tick), ADR-0009 (float-pair positions, `advance()`/`reap()`/`tick_status`, whole-tick budget, `MAX_TICKS_PER_FRAME` deferred here).
- Enables ADR-0006, ADR-0007, ADR-0010, ADR-0011.
- `docs/architecture/architecture.md`: Data Flow 1, 2, 6, 10; B0, B4, B5, B9; QQ-01, QQ-05, QQ-08, QQ-11.
- `design/gdd/game-state-stage-flow.md` (Rules 4, 5, 15, 17, Edge Cases), `combat-damage.md` (Rule 11, Edge Cases), `enemy-wave.md` (Rules 6, 8, 12, Formulas), `tower-system.md` (Rules 8, 9, 10), `hero-system.md` (Tick list, Rules 15, 16, Formulas), `battle-hud.md` (Rules 10, 11, 15, 18, Formulas), `input-gesture-resolver.md` (Rule 6, adapter contract), `data-config-pipeline.md` (interval floor).
- Spike kit: `prototypes/adr-0003-device-spike/` (SP1, SP10, SP11 reused; SP14 and SP15 proposed, not added by this ADR).
- Code (once implemented): `src/foundation/sim_time.gd`, `src/foundation/sim_rng.gd`, `src/root/battle_clock.gd`, `src/root/battle.gd`, `src/root/battle_wrapper.gd`.
