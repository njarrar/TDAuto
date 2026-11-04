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
> **Before acceptance** (none of these needs a story):
> 1. ADR-0001 and ADR-0003 are Accepted.
> 2. V1, V2, V3 and V7 have recorded results from the ADR-0003 device spike, and V4 and V9
>    from a headless check script run outside `src/` (`prototypes/` or a scratch folder),
>    copied into `docs/engine-reference/godot/`. Where a result takes a branch, this ADR is
>    revised to it first.
> 3. The user has confirmed or overturned each item in Decision 11, one by one.
>
> **After acceptance** (they need stories, which stay Blocked while this ADR is Proposed):
> V5, V6 and V8 run in the stories named in each item. `MAX_TICKS_PER_FRAME = 3` is
> provisional until V6. Reopen trigger: a V6 p99 tick above 1.33 ms changes N in place
> (2 to 4, Decision 2) with no new ADR; above 2.0 ms it is escalated to `technical-director`
> with the measurements. V5 and V8 change no decision.
>
> Accepting this ADR records technical-director acceptance of QQ-08's "one tick order"
> item, on the user's confirmation.

## Date

2026-11-04

## Last Verified

2026-11-04. Checked against the pinned engine reference only. The live Godot 4.7 documentation was not reachable and no device was available, so every engine behaviour the pinned reference does not cover is NEEDS VERIFICATION and listed in V1 to V9.

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate: CONCERNS on the first draft; T1 to T3 blocking and T4 to T10 advisory, all applied in this revision), godot-specialist (engine check: E1 to E3 blocking and the minor notes, all applied). Authored with the /architecture-decision flow in autonomous mode.

## Summary

The battle must advance in fixed, reproducible steps shared by humans, bots and tests, with one tick order, commands only between ticks, real-time presentation clocks outside the sim, and results set by `(catalogue, stage_id, rng_seed, command script)` on one CPU architecture. This ADR decides a 60 Hz tick from a pure `BattleClock` accumulator (phased at half a tick) in `BattleWrapper._process`, a provisional clamp of 3 ticks per frame that drops further backlog, a stall rule and backlog drop around Paused, one frame order (flush, real-time models, ticks, HeroInput sync, views), the Data Flow 2 order inside a gated `Battle.tick`, one typed `SimTime.to_ticks`, an integer `SimRng` apart from cosmetic randomness, and a float policy with baselines per architecture.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (GDScript, Mobile renderer) |
| **Domain** | Core (main loop timing, GDScript numerics) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (post-cutoff; main loop, frame timing, `delta`, physics step settings, `RandomNumberGenerator` and numerics are absent from the pinned reference) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` (`Time.get_ticks_msec()` replaces `OS.get_ticks_msec()`), `current-best-practices.md`, `modules/physics.md` (the sim uses no physics, so the Jolt rows do not apply), `modules/input.md` (its `_physics_process` sample is not a timing statement). No module covers the main loop, scripting or numerics. Binding ADRs: ADR-0001, ADR-0003 (Spike items, Decisions 2, 6, 9), ADR-0005 (Performance), ADR-0009 (Decisions 2, 7, 9). |
| **Post-Cutoff APIs Used** | None. One 4.7 rule applies: an override of a typed-return method inherits the type and needs an explicit `return` (`breaking-changes.md`, 4.6 to 4.7); it affects every spy of `SimRng`, `SimTime` or `BattleClock`. |
| **Verification Required** | V1 to V9 below. NOT SOURCEABLE in `docs/engine-reference/godot/**`: input delivery against `_process`; `_process` against `_physics_process`; `delta` after a stall or return, any cap, delta smoothing, `Engine.time_scale` scaling; the physics step settings; cadence at 90 and 120 Hz, adaptive refresh, the fps cap key; `low_processor_mode`; `RandomNumberGenerator` and global random functions; `round()`'s half rule; binary64 `float` and 64-bit `int`; x86-64 against ARM64 results (FMA in engine C++; the GDScript VM is believed to evaluate operators separately); naming the CPU architecture; `Time.get_unix_time_from_system()`; release unwinding after a runtime error. Only V2, V3, V6 and V9 can change a number or branch. |

> **Note**: If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated if the
> project upgrades engine versions. Flag it as "Superseded" and write a new ADR.

### Verification items

Expected results are unsourced (pre-cutoff knowledge only). Split before and after acceptance as in the Status note.

**Before acceptance**

- **V1. Input against `_process` (reuses ADR-0003 SP1).** Expected: events arrive between frames, flushed once per frame. The adapter queues every resolver call and `flush()` drains it at step 0 (ADR-0003 Decision 2), so SP1 decides latency only: a late event waits one frame, in order, still before that frame's ticks. Record the late-event rate beside Validation 9. SP1's `PHYS` markers record `_process` against `_physics_process` order; nothing relies on it. No outcome changes this ADR.
- **V2. `delta` on a stall and on return (reuses SP11; proposed kit item SP14).** Expected: after a T ms stall the next `delta` is about T ms, uncapped; the first `delta` after a return is large. *If capped*: record it; clamp and stall rule hold. *If 0 or negative*: no ticks, already the rule. SP14 (for ADR-0003's owner to add; SP13 is its focus item): a "Stall" action blocking 300 ms and 1,000 ms (`OS.delay_msec`, unsourced), logging the next two `PROC delta_ms`. Owner: the user runs the kit; godot-specialist records.
- **V3. Cadence and tick distribution (SP14).** Ten seconds of per-frame `delta_ms` and the ticks a kit copy of `BattleClock` would run, on a 60 Hz phone and a 90 or 120 Hz one if available; record `Engine.max_fps`, refresh rate, and adaptive-refresh changes. Expected: 60 Hz gives exactly 1 tick every frame; 90 or 120 Hz a regular 0/1 mix. *0- and 2-tick frames at 60 Hz*: revise phase or cap before acceptance. *Uneven motion at 90 or 120 Hz*: a follow-up picks a 60 fps cap (key unsourced; uneven on a 90 Hz panel too) or interpolation (Alternative 7). No sim change.
- **V4. Numeric golden values (headless script outside `src/`, run with `godot --headless -s`; proposed kit item SP15 on the phone).** Expected: `0.1 + 0.2 == 0.30000000000000004` and `16777217.0 + 1.0 == 16777218.0` (binary64); `-1 & 0xFFFFFFFF == 4294967295`, `0xFFFFFFFF << 13` no overflow (64-bit `int`); `floori`, `ceili`, `absf`, `sqrt`, `is_finite` as IEEE; Validation 3's `to_ticks` values; `SimRng.new(1)`: `270369, 67634689, 2647435461`; `SimRng.new(0)`: `1085196063, 2447379481, 2618286376`; `SimRng.new(-1)`: `253983, 4228382207, 1958451267` (computed in Python for this ADR). Record `round(0.5)`, `round(2.5)`, `round(-0.5)`, the call naming the CPU architecture (`OS.has_feature("x86_64")`, `"arm64"` or other), and whether a runtime error in a callee returns to the caller in a release export (Decision 3). *Desktop mismatch*: revise Decisions 6, 7, 9 first. *Phone-only mismatch*: per-architecture baselines cover it; record it. Owner: godot-specialist; the user runs SP15.
- **V7. Pause notification against the first frame after return (reuses SP10, SP11).** Expected: notifications first. Either way the stall rule and backlog drop (Decision 3) leave at most `MAX_TICKS_PER_FRAME` unseen ticks, only in SP10 Branch C below the stall threshold. Recorded; no branch.
- **V9. Delta smoothing (V4 script plus SP14).** `application/run/delta_smoothing` is believed to exist, default on; it could hide 60 Hz aliasing and spread a stall so no `delta` exceeds 0.5 s. Decision: `project.godot` sets it off (key NEEDS VERIFICATION). Method: read it in the script; in SP14 compare stall `delta` on and off. *If the key is absent*: the stall rule covers only stalls that reach `_process` as one large `delta`; the clamp bounds the rest.

**After acceptance**

- **V5. Cross-architecture equality (informational).** Validation 6's script on x86-64 (CI) and ARM64 (the user's Mac if Apple Silicon; the first Android build); compare digests; either result is recorded, baselines stay per architecture. Method: a dev-only bot-run entry in the first phone build (ADR-0007, ADR-0010). Owner: performance-analyst.
- **V6. Whole-tick cost (reuses ADR-0009 V4; QQ-11).** Worst case (48 alive, five towers, hero and burst release) on the Adreno 5xx-class device: median and p99 over at least 1,000 ticks, the helpers' share against the GDD's 2.0 ms ceiling (TR-combat-013), and the Data Flow 10 slices from the wrapper's dev timers. Sets N (Decision 2). Owner: performance-analyst, first phone build.
- **V8. Seed source.** `Time.get_unix_time_from_system()` exists and returns `float`. *If not*: `Time.get_ticks_msec()` (sourced); near-constant between launches, acceptable because no MVP rule reads randomness. Method: first AppRoot story.

Not relied on: `_process` against `_physics_process` order, `max_physics_steps_per_frame` and `physics_ticks_per_second` (no `_physics_process`; defaults never read), `RandomNumberGenerator` reproducibility (never in the sim), `Dictionary` order (Decision 9), sibling `_process` order (Decision 5).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed): gated `Battle.tick(dt)`, `halted()`, `BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler)`, session seed reused on retry, method Callables, `attach`/`detach`. ADR-0003 (Proposed): queued adapter, `flush()` at step 0, `lifecycle_paused` into `Flow.pause`, SP1, SP10, SP11. Both Accepted first. Binding, not redecided: ADR-0005 (reads at use time, 0.5 ms per-tick ceiling), ADR-0009 (scalar positions, `advance()`, `reap()`, `tick_status(roster)`, whole-tick budget). |
| **Enables** | ADR-0006 (signals in a tick follow this order), ADR-0007 (determinism and numeric tests, sim lints), ADR-0010 (scripts keyed by `ticks_run()`, `between_ticks()`), ADR-0011 (views in step 4, no interpolation). |
| **Blocks** | Game State, Enemy & Wave, Tower, Hero and Battle HUD epics; Combat's `tick_status` and `to_ticks` stories; every bot gate (re-baselined). |
| **Ordering Note** | SP1's result changes nothing here, so drafting before the spike is safe; acceptance is not. ADR-0009's V4 is V6 here and runs after acceptance. Owns QQ-01, QQ-05's float policy, QQ-11's frame split, QQ-08's tick order, and the Hero GDD's HeroInput question. |

## Context

### Problem Statement

Five GDDs assume one fixed tick, one order and commands between ticks; Battle HUD and Tower need real-time clocks that run while the sim is stopped. The prototypes used variable time for humans and 1/30 s for bots, so "5.0 s" took 301 ticks and no number transfers (Game State Rule 4). Every bot gate, to-the-tick criterion and TR-hud-005 depend on the driver, rate, long-frame rule, frame order, conversion, randomness source and float trust, so they are fixed before the first sim story.

### Current State

No code exists. `architecture.md` Data Flow 1, 2, 6, 10 and B4, B5, B9 hold ADR-pending defaults. ADR-0001 fixed the gated `Battle.tick(dt)`; ADR-0003 queues resolver calls for `flush()` at step 0 and asked for the SP11 resume case; ADR-0009 deferred the clamp and float policy here.

### Constraints

- Godot 4.7.2, GDScript, main thread only.
- No autoloads, no mutable `static var`, method Callables only, no lambdas or `bind()` (ADR-0001).
- Gameplay classes never read `Engine`, `Time`, `OS`, a timer or `await` (B4), and use no `_process` or physics areas (Flow Rule 4).
- The sim runs headless: bots and tests call `battle.tick` directly.
- `project.yaml`: 60 fps target (16.6 ms), 30 fps floor on low-end Android (Adreno 5xx class).
- The Data & Config interval floor is one tick, 1/60 s.
- Solo, part-time developer: one clock, one order, small classes, testable without an editor.

### Requirements

- Time only through `battle.tick(dt)` at a fixed rate, clamped (TR-state-003); one order, commands between ticks (TR-state-004 and the order TRs); seeded randomness, none in waves (TR-state-005, TR-enemy-007); outcomes stop time and skip the tick (TR-state-006, TR-state-007).
- One `to_ticks`, integer countdowns, absolute schedule (TR-state-012, TR-enemy-002); real-time clocks outside the sim (TR-state-014, TR-tower-010, TR-hero-011, TR-hud-007); exact pause (TR-hero-013); frame order with displayed equal to paid (TR-hud-005).
- Determinism per architecture; scalar PinGeometry (TR-combat-014, TR-hero-006); Data Flow 10's 4.0 ms sim slice (QQ-11).

## Decision

### 1. Tick driver: a pure accumulator in `BattleWrapper._process`

`BattleWrapper._process(delta)` advances the sim through `BattleClock` (`src/root/battle_clock.gd`, pure `RefCounted`, tested headless). No `_physics_process` in `src/`; the physics step settings stay at defaults, unread. No `Timer`, `create_timer`, `Tween` callback, `await` or `Engine.time_scale` drives or scales sim time. `low_processor_mode` stays off; `delta_smoothing` is set off (V9). Nothing sets `get_tree().paused`; Flow's PAUSED plus the gate is the only pause, and the wrapper uses `PROCESS_MODE_ALWAYS` so steps 0, 1 and 4 run while Paused even if a later system pauses the tree. Headless, bots and tests call `battle.tick(battle.sim_time.dt)`.

Why `_process`: one function this project controls holds the whole frame order, independent of the unsourced physics-step interleaving, and the clamp is testable headless.

### 2. Rate, phase, clamp and stall

- **Rate.** 60 ticks per second: `SimTime.TICKS_PER_SECOND := 60`, `dt = 1.0 / 60.0`, an engine constant, not a catalogue value; the Data & Config 1/60 floor is tied to it.
- **Phase.** The accumulator starts at `0.5 * dt`, and every reset (`drop_backlog()`, the stall branch) returns it there, so a 60 Hz `delta` lands half a tick from a boundary and small jitter still gives one tick per frame. Starting at 0 puts the boundary on the `delta`: simulated ±0.1 ms jitter gave 14 zero-tick and 14 two-tick frames per 10 s, against none at half a tick.
- **Clamp.** `MAX_TICKS_PER_FRAME := 3`, provisional until V6. At the 30 fps floor a normal frame runs 2 ticks, which must fit the sim's share of 33.3 ms, so N is at least 2. At 60 fps an occasional N-tick catch-up frame must fit the 4.0 ms slice, so one worst-case tick must fit 4.0 / N ms (1.33 ms at 3). The clamp also stops a spiral, where a slow frame makes the next slower. N = 3 keeps real-time speed down to 20 fps. After V6, `N = clamp(floor(4.0 / p99_tick_ms), 2, 4)`. A tick within the Combat GDD's 2.0 ms targeting ceiling (TR-combat-013) can still exceed 1.33 ms; then N is 2. Above 2.0 ms no N fits (Status note).
- **Backlog.** Past the clamp the accumulator is capped at `1.5 * dt`: one tick of carry, on phase. The rest is dropped: the game slows, never jumps.
- **Stall.** `delta` above `STALL_SECONDS := 0.5` (suspension, debugger, window drag) runs no ticks and resets the accumulator; this covers ADR-0003 SP11's resume case (V7).
- **Bad `delta`** (not finite, not above 0): no ticks, no change.

```gdscript
func advance(delta: float) -> int:
	if not is_finite(delta) or delta <= 0.0:
		return 0
	if delta > STALL_SECONDS:
		_acc = 0.5 * _dt
		return 0
	_acc += delta
	var run: int = mini(floori(_acc * float(_ticks_per_second)), MAX_TICKS_PER_FRAME)
	_acc = maxf(_acc - float(run) * _dt, 0.0)    # few-ULP negatives
	if run == MAX_TICKS_PER_FRAME:
		_acc = minf(_acc, 1.5 * _dt)             # drop backlog beyond one tick
	return run
```

The clock's float arithmetic only aligns ticks with frames; it never affects a sim result (bots and tests do not use it).

### 3. The in-sim gate, outcomes and Paused

`Battle.tick(dt)` checks in order, returning at once on a failure: not inside a tick (else `dev_error`); `dt == sim_time.dt` (else `dev_error`; the prototype's bots used 1/30); `halted()` false; phase WAVE or INTERMISSION. It then sets `_ticking`, calls the private `_run_steps()` (Decision 4), which holds every early `halted()` return, and clears `_ticking` on its single path back, so an outcome mid-tick cannot leave the flag set. Whether a runtime error in a callee unwinds to `tick()` in a release export is NEEDS VERIFICATION (V4); development builds stop on it.

Build, Paused, Won, Lost and Fatal run no ticks, headless too; Intermission does. Flow Rule 15's "stop the clock" needs no step of its own: the gate reads the phase, so time stops when Flow commits the state, before `cancel_input()` and `phase_changed` (TR-state-007). Resume restores the phase; integer countdowns, walk and telegraph continue exactly (TR-hero-013).

The clock runs while the gate is closed; its ticks return at once. The wrapper connects `flow.phase_changed` to `_on_phase_changed(value)` (method Callable, disconnected in `detach()`), which calls `clock.drop_backlog()` on entering PAUSED and on leaving it, so nothing carries across. That is a clock call, not a sim reset (the `in_place_reset` ban covers sims).

### 4. The one tick order

`_run_steps()` runs, every tick, Intermission included (Data Flow 2 and Combat Rule 11, ratified; Game State Rule 5, Enemy & Wave Rule 12, Tower Rule 9 and the Hero "Tick" list cite it):

```
1. flow.tick()                               intermission countdown, wave start
2. enemy_wave.advance()                      spawn from the absolute schedule, move, leak
3. combat.tick_status(enemy_wave.roster())   slow countdown
4. tower_sim.tick()                          ascending slot index
5. hero_sim.tick()                           walk, attack, cooldown, telegraph, release (burst after hero)
6. enemy_wave.reap()                         corpses by spawn_id, enemy_killed(bounty), clear check
then _ticks_run += 1
```

- `halted()` is checked before steps 2 to 6, and by each system after every read and signal. Leaks resolve before fire, so a fatal leak pays no bounty (Game State Rule 14).
- `ticks_run()` counts ticks past the gate; it indexes bot scripts (ADR-0010) and the dev log.
- Order inside a step is its owner's. No step calls another's tick entry; no listener of an in-tick signal calls a tick entry or command (ADR-0006).
- A new entry (Vertical Slice) needs a superseding ADR and a Data Flow 2 edit.

### 5. Frame order

`BattleWrapper._process(delta)` is the only per-frame code in the battle subtree, apart from the adapter's size poll if ADR-0003 SP12 needs it. Views and HUD refresh when the wrapper calls them, so sibling `_process` order never matters.

```
(engine) input callbacks: InputAdapter (_input, _unhandled_input, _notification); Paused and Result Controls
          press/move/release queued, no resolver call yet; a loss calls cancel_all(), then
          lifecycle_paused -> Flow.pause() at once; Paused tap -> Flow.resume(); Retry sets AppRoot's latch
BattleWrapper._process(delta):
  0. adapter.flush()   queue -> resolver -> gesture signals -> HeroInput/TowerInput/HudLogic -> commands
  1. real-time models  ms = delta * 1000.0 (0.0 if not finite or not above 0)
                       hud_logic.advance(ms); tower_input.advance(ms)  (feeds its ChipWindow)
  2. clock             var n := clock.advance(delta)
  3. ticks             n times: battle.tick(battle.sim_time.dt)
  4. sync and views    hero_input.update(); refresh view-models (read-only); queue_redraw()
(engine) render
```

- **Commands only between ticks.** Gesture commands run in step 0; `Flow.pause()` and `Flow.resume()` from engine callbacks outside `_process`; nothing in step 3. `Battle.between_ticks()` lets ADR-0010 check this in development builds.
- **HeroInput syncs after the ticks (TR-hero-011; the Hero GDD's open question).** `hero_input.update()` runs first in step 4: it sets the hit-disc centre, re-clamps `aim_point()` and updates `cooldown_digit()` from post-tick state, which is what step 4 draws. Next frame's `flush()` tests a press against the hero the player saw. In step 1 the centre would lag the drawn hero by a frame. TR-hud-005's "real-time models before ticks" covers HudLogic and ChipWindow; `update()` is a view-side sync of sim state, so it goes with the views.
- **Displayed equals paid (TR-hud-005).** Step 4 of frame F draws the bonus from post-tick `intermission_left`; the tap reaches the HUD in F+1's step 0, before F+1's ticks, so `call_early` pays the most recently rendered value. A late event (SP1) is handled a frame later, still against the most recently rendered value. Relies on `flush()` in step 0 and render after `_process`.
- **Other per-frame nodes.** `AppRoot._process` (ADR-0001) acts on the retry and fatal latches: before the wrapper it tears down at once, after it one frame later, and ticks after a fatal or outcome are gated either way. The adapter's size poll calls `cancel_all()`: before `flush()` it empties this frame's queue, after it the next frame's; either is a cancelled gesture, never a wrong one. So no `process_priority` is set.
- A frame with the gate closed still runs steps 0, 1 and 4.

### 6. Time conversion: one typed `to_ticks`, integer countdowns

`SimTime` (`src/foundation/sim_time.gd`, `RefCounted`) holds `ticks_per_second: int` and `dt: float`, read-only by contract:

```gdscript
func to_ticks(seconds: float) -> int:
	if not is_finite(seconds):
		return 0
	var x: float = seconds * float(ticks_per_second)
	var t: int = floori(absf(x) + 0.5)
	return -t if x < 0.0 else t
```

- This is Enemy & Wave's `round(seconds / dt)`, halves away from zero, written with the integer rate so binary-exact halves (0.125 s at 60 and at 4) are exactly `.5`. Both forms agree, in IEEE double, on 299,999 durations (every 1 ms to 200 s, every 1/8000 s to 12.5 s) and every GDD example. Typed `floori`/`absf` replace the Variant-returning `floor`, `abs`, `sign` and the unsourced `round()`. Edge: `x = 0.49999999999999994` gives 1 (`x + 0.5` rounds to 1.0); no authored duration produces it. Non-finite gives 0 (ADR-0002 rejects such fields; Combat guards with `is_finite`).
- The Builder creates one `SimTime.new()` per battle (`Battle.sim_time`) and injects `sim_time.to_ticks` and `sim_time.dt` where B9 and ADR-0009 list them. Tests use `SimTime.new(4)` for the dt 0.25 fixtures.
- Every countdown is an `int`, set once from `to_ticks`, minus 1 per tick: `intermission_left`, `cooldown_left`, `attack_left`, `telegraph_left`, `walk_left`, `Status.ticks_left`, `wave_tick`. No sim code subtracts `dt` from a duration. Spawn ticks come from the absolute schedule against `wave_tick` (TR-enemy-002).
- Other float-to-tick uses: only Hero's `walk_ticks` (its own `ceil` with tolerance) and movement by `speed * speed_factor * dt` (ADR-0009). Payload seconds are `ticks * dt`; the HUD's `display_seconds` uses `sim_time.ticks_per_second`.

### 7. Randomness: one seeded `SimRng`, cosmetic randomness apart

- **Sim.** `SimRng` (`src/foundation/sim_rng.gd`, `RefCounted`) is a 32-bit xorshift in integers, masked after each left shift, no multiplication, so nothing overflows, state stays non-negative and no float enters: `x ^= (x << 13) & M; x ^= x >> 17; x ^= (x << 5) & M`, `M = 0xFFFFFFFF`, starting at `rng_seed & M` (0 becomes `0x6D2B79F5`). The Builder creates one per battle (`Battle.sim_rng`), injected only where a GDD states a random rule. **No MVP GDD has one** (waves are authored; ties break by `spawn_id`), so `draw_count()` stays 0, which tests Enemy & Wave Acceptance 42.
- Sim code never uses `RandomNumberGenerator`, `randi`, `randf`, `randi_range`, `randf_range`, `randomize` or `seed` (unsourced algorithm; could change under the baselines).
- **Session seed (refines ADR-0001 Decision 2).** AppRoot picks `int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF` (V8; 1 if 0) once per session and reuses it on retry; `configure({rng_seed})` overrides it; dev builds log it (ADR-0010).
- **Cosmetic** randomness (±1.5 px jitter, VFX) lives in Presentation: a view's own `RandomNumberGenerator` with a fixed seed so screenshots repeat, or offsets from `spawn_id` and the view's frame count. It never reads `rng_seed` or `sim_rng` and feeds nothing back (TR-enemy-007).

### 8. Real-time presentation clocks

- Real-time models are pure classes stepped explicitly: `HudLogic.advance(ms: float)`, `ChipWindow.advance(ms: float)` (held by TowerInput, which forwards its own `advance(ms)`). `HeroInput.update()` is stepped the same way but in step 4 (Decision 5). None reads `Engine`, `Time`, a `Timer` or `delta`; tests drive them with numbers.
- The wrapper passes raw frame ms in step 1. Each model applies its own GDD's clamp and freeze: HudLogic clamps to 100 ms per call and ignores `advance` while Paused (Battle HUD Rule 11, Acceptance 12); ChipWindow has no clamp, because a long frame can only expire a chip early, the safe direction, and it closes on `phase_changed(PAUSED)` (Tower Rule 8).
- Lost's 400 ms text delay, Won's 1,000 ms beat and the 300 ms arming of Retry and Start/Call run in HudLogic on `advance(ms)`, so they keep running after Won or Lost while ticks are gated (TR-state-014); only Paused freezes them.
- A real-time model never issues a command and never changes sim state.

### 9. Determinism and float policy

**Promise.** On one CPU architecture and engine build, the same `(catalogue, stage_id, rng_seed, command script)` gives the same state after every tick, bit for bit (positions, `distance`, `hp`, counters, payloads, `StageResult`). Across architectures nothing is promised (V5 records the truth); baselines are per architecture (TR-combat-014).

**Float policy for sim code** (`src/core/`, sim classes in `src/feature/` and `src/foundation/`, `src/root/battle.gd`):

1. `float` (binary64, V4) and `int`; positions are float scalar pairs (ADR-0009); PinGeometry is scalar (TR-hero-006).
2. Allowed on values reaching sim state: `+ - * /`, `sqrt`, `absf`, `minf`, `maxf`, `clampf`, `absi`, `mini`, `maxi`, `clampi`, `floorf`, `floori`, `ceilf`, `ceili`, `int()`, comparisons, `is_finite`: correctly rounded under IEEE and typed.
3. Forbidden on them: `floor`, `ceil`, `abs`, `sign`, `round`, `sin`, `cos`, `tan`, `atan2`, `pow`, `exp`, `log`, `fmod`, `fposmod`, `lerp`, `move_toward`, `snapped`, any `Vector2`/`Vector3` method. A GDD that needs one names it; a superseding ADR decides.
4. Time is integer ticks; no float time accumulates.
5. Exact float comparison only at a GDD-stated edge (ADR-0009 range tests) or tolerance (Hero `walk_ticks`, PinGeometry); otherwise compare integers.
6. Nothing run-dependent decides order: no order-sensitive `Dictionary` iteration (use arrays in `spawn_id` or slot order), no `get_instance_id()`, hashes or `str(object)` in ordering or payloads, no threads.
7. No engine time, frame counters or randomness but `sim_rng`; banned by name: `Engine.get_frames_drawn`, `Engine.get_process_frames`, `Engine.get_physics_frames`, `Engine.time_scale`, `Time.*`, `OS.get_ticks_*`.

**Baselines** live under `tests/baselines/<arch>/` (`x86_64`, `arm64`; V4 names the call). CI compares only with its own architecture; a missing directory is NOT ASSESSED, never a pass; baselines are recorded by a reviewed run, never by the comparing test. ADR-0007 owns the harness, ADR-0010 the bot format.

### 10. Frame budget split (QQ-11)

Data Flow 10 confirmed as a proposal; unmeasured until V6.

| Slice | Budget at 60 fps | With this ADR |
|---|---|---|
| Input callbacks, steps 0 and 1 | 0.5 ms | One finger; two small updates |
| Ticks, steps 2 and 3 | 4.0 ms | 1 tick normally; 3 at the clamp, so one worst-case tick fits **1.33 ms**, with ADR-0005's 0.5 ms reads and ADR-0009's targeting inside it. 30 fps floor: 2 ticks in 33.3 ms |
| Step 4 and `_draw` | 3.0 ms | Draw calls are ADR-0011's |
| Engine, render, OS | 7.0 ms | Mobile, 2D |
| Headroom | 2.1 ms | Allocation spikes |

Dev builds time steps 0 to 4 in the wrapper and log them; release builds do not.

### 11. Choices pending user confirmation

Autonomous mode; each is the recommended option, and the user confirms or overturns each before acceptance.

1. 60 Hz tick (against 30 Hz, which breaks the 1/60 floor, and 120 Hz, double cost).
2. `_process` accumulator; no `_physics_process`.
3. `MAX_TICKS_PER_FRAME = 3`, provisional, 2 to 4 after V6; slow below 20 fps.
4. A frame over 0.5 s runs no ticks (stronger than Game State's "slows").
5. Backlog beyond one tick dropped; no catch-up burst.
6. Backlog dropped on entering and leaving Paused (Flow Rule 17 names entry only).
7. Accumulator phased at half a tick.
8. `Battle.tick` rejects a `dt` other than the build `dt`.
9. Own integer `SimRng` (xorshift32), not `RandomNumberGenerator`; no MVP consumer.
10. Session seed from the wall clock, logged, reused on retry.
11. `to_ticks` with `floori` and the integer rate, not the GDD's `round(seconds / dt)` text; same results tested.
12. Float policy bans (Decision 9).
13. Raw frame ms to real-time models; HudLogic clamps itself; ChipWindow has no clamp.
14. No interpolation or fps cap at MVP (V3 decides); delta smoothing off (V9).
15. `Battle.between_ticks()` exposed; ADR-0010 decides enforcement.
16. `BattleClock` instead of "Clock" (QQ-16).
17. HeroInput `update()` after the ticks, in step 4.

### Architecture Diagram

Decision 5's frame block is the main diagram. Ownership:

```
AppRoot ─ BattleWrapper (PROCESS_MODE_ALWAYS) ─┬─ BattleClock (phase 0.5 dt, clamp 3, stall 0.5 s, carry 1.5 dt)
                                               ├─ InputAdapter (queue; flush() at step 0)
                                               ├─ HudLogic, TowerInput ─ ChipWindow, HeroInput, views
                                               └─ listens: flow.phase_changed ─► _on_phase_changed ─► drop_backlog()
Battle ─┬─ sim_time: SimTime (60, dt, to_ticks) ─► injected to_ticks and dt
        ├─ sim_rng: SimRng(rng_seed) ─► no MVP consumer; draw_count() == 0
        └─ tick(dt): gate ─► _run_steps(): Flow ─ advance ─ tick_status ─ towers ─ hero ─ reap
Presentation randomness: a view's own RandomNumberGenerator; never rng_seed or sim_rng
```

### Key Interfaces

```gdscript
# src/foundation/sim_time.gd
class_name SimTime extends RefCounted
const TICKS_PER_SECOND := 60
var ticks_per_second: int          # read-only by contract; >= 1
var dt: float                      # 1.0 / ticks_per_second; read-only by contract
func _init(p_ticks_per_second: int = TICKS_PER_SECOND) -> void
func to_ticks(seconds: float) -> int   # Decision 6; non-finite gives 0

# src/foundation/sim_rng.gd
class_name SimRng extends RefCounted
func _init(rng_seed: int) -> void  # state = rng_seed & 0xFFFFFFFF; 0 becomes 0x6D2B79F5
func next_u32() -> int             # xorshift32 (13, 17, 5), 0 .. 4294967295
func next_below(n: int) -> int     # n >= 1; next_u32() % n (modulo bias accepted)
func draw_count() -> int

# src/root/battle_clock.gd   (pure; owned by BattleWrapper; absent headless)
class_name BattleClock extends RefCounted
const MAX_TICKS_PER_FRAME := 3     # provisional; V6 sets 2 to 4
const STALL_SECONDS := 0.5
func _init(ticks_per_second: int) -> void   # accumulator starts at 0.5 * dt
func advance(delta: float) -> int  # ticks to run this frame (Decision 2)
func drop_backlog() -> void        # accumulator back to 0.5 * dt

# src/root/battle.gd   (adds to ADR-0001's Battle)
var sim_time: SimTime              # read-only
var sim_rng: SimRng                # read-only
func tick(dt: float) -> void       # gate, then _run_steps(); the only way sim time advances
func ticks_run() -> int
func between_ticks() -> bool       # false only while tick() runs

# src/root/battle_wrapper.gd   (adds to ADR-0001's BattleWrapper)
func _process(delta: float) -> void                  # Decision 5, steps 0 to 4
func _on_phase_changed(value: Flow.Phase) -> void    # drop_backlog on PAUSED entry and exit

# Step signatures fixed here, classes owned by their ADRs:
# HudLogic.advance(ms: float); TowerInput.advance(ms: float) -> ChipWindow.advance(ms: float); HeroInput.update()
```

`BattleBuilder.build(...)` is unchanged (ADR-0001). Names are provisional until ADR-0007 settles QQ-16.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must advance sim time only through `Battle.tick(dt)`; tick entries are called only from `Battle._run_steps()`, in Decision 4's order, with `halted()` checked before steps 2 to 6.
- `Battle.tick` must check re-entrancy, `dt`, `halted()`, phase in that order, set `_ticking`, call `_run_steps()`, clear `_ticking` on its one return path.
- Must never override `_physics_process` in `src/`; `_process` only in `BattleWrapper`, `AppRoot` and (SP12 poll only) `InputAdapter`.
- Must never use `Timer`, `SceneTree.create_timer`, `await`, `Engine.time_scale`, `Engine.get_frames_drawn`, `Engine.get_process_frames`, `Engine.get_physics_frames`, `Time.*` or `OS.get_ticks_*` in sim code or real-time models (AppRoot's seed read and the wrapper's dev timers excepted).
- Must never set `get_tree().paused` or enable `low_processor_mode`; must set `delta_smoothing` off; the wrapper uses `PROCESS_MODE_ALWAYS`.
- `BattleClock` must start and reset at `0.5 * dt`.
- Must run Decision 5's frame order: `flush()` first in step 0, `hero_input.update()` first in step 4.
- Must never issue a command inside a tick, from a signal listener, or from `advance`/`update`.
- Must convert each authored duration once with the injected `to_ticks`; countdowns are `int`; never subtract `dt` from a duration.
- Must use only Decision 9's allowed operations on sim values; never iterate a `Dictionary` where order matters; never order by instance ID or hash.
- Must never use `RandomNumberGenerator` or global random functions in sim code; Presentation randomness never reads `rng_seed` or `sim_rng`.
- `BattleWrapper.detach()` disconnects `_on_phase_changed` (ADR-0001 Decision 6).
- Spies overriding typed methods of `SimTime`, `SimRng`, `BattleClock` need an explicit `return` (4.7).
- Baselines live under `tests/baselines/<arch>/`; no test writes the baseline it compares against.

## Alternatives Considered

### Alternative 1: `_physics_process` as the tick driver
- **Description**: `physics_ticks_per_second = 60`, tick in `_physics_process`, clamp with `max_physics_steps_per_frame`.
- **Pros**: The engine accumulates.
- **Cons**: Input, physics-step and `_process` order is unsourced; `flush()` and real-time models live in `_process` anyway; stall behaviour unsourced; project-global; not testable headless.
- **Estimated Effort**: Similar code, more verification.
- **Rejection Reason**: Puts the frame order on unsourced engine behaviour.

### Alternative 2: One tick per rendered frame
- **Description**: `battle.tick` once per `_process`.
- **Pros**: Simplest.
- **Cons**: Half speed at 30 fps, double at 120 Hz.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Breaks real-time pacing.

### Alternative 3: Variable `dt` ticks
- **Description**: `battle.tick(delta)`.
- **Pros**: No accumulator.
- **Cons**: Results depend on frame timing; float countdowns drift; TR-state-003 and TR-state-012 forbid it.
- **Estimated Effort**: Lower, then far higher in bugs.
- **Rejection Reason**: Destroys determinism.

### Alternative 4: 30 Hz or 120 Hz tick
- **Description**: Another fixed rate.
- **Pros**: 30 Hz halves cost; 120 Hz smooths fast displays.
- **Cons**: 30 Hz breaks the 1/60 floor and GDD examples; 120 Hz doubles cost.
- **Estimated Effort**: Same code; content changes at 30 Hz.
- **Rejection Reason**: 60 Hz matches the GDDs and the target.

### Alternative 5: `RandomNumberGenerator` for the sim
- **Description**: One per battle seeded with `rng_seed`.
- **Pros**: Built in.
- **Cons**: Algorithm and reproducibility unsourced; an upgrade could break every baseline.
- **Estimated Effort**: Slightly lower.
- **Rejection Reason**: A 15-line integer generator with golden values cannot drift.

### Alternative 6: Keep the whole backlog
- **Description**: Run N ticks a frame until drained.
- **Pros**: Game time tracks wall time.
- **Cons**: Fast-forward after a hitch reads as a jump; a slow device spirals.
- **Estimated Effort**: Same.
- **Rejection Reason**: Game State Edge Cases: slow, never jump.

### Alternative 7: View interpolation
- **Description**: Views blend the last two ticks by the remainder.
- **Pros**: Smooth at 90 and 120 Hz.
- **Cons**: Previous positions in every view; drawn positions the sim never had, so a disc and its drawing can disagree.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Not needed until V3 shows judder.

### Alternative 8: Engine timers for presentation delays
- **Description**: `create_timer` or `Timer` nodes for arming, delays and the chip.
- **Pros**: Less code.
- **Cons**: Untestable without frames; run through Paused; the GDDs require `advance(ms)`.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Contradicts TR-tower-010, TR-hud-007, TR-hero-011.

### Alternative 9: HeroInput `update()` in step 1
- **Description**: `architecture.md`'s original order, with the real-time models.
- **Pros**: All updates in one place.
- **Cons**: The hit-disc centre and `aim_point()` lag the drawn hero by a frame.
- **Estimated Effort**: Same.
- **Rejection Reason**: Step 4 matches the drawn frame (TD-ADR T2).

## Consequences

### Positive
- One clock, gate, order and conversion; the frame order and queue drain are one function, so TR-hud-005 holds whatever SP1 shows.
- Clamp, phase, stall and backlog rules are pure and tested headless.
- Bots, tests and phone run the same ticks; retries replay exactly; no engine RNG or platform maths under a baseline.

### Negative
- Slow below 20 fps (30 if N is 2); a stall over 0.5 s freezes game time.
- 90 and 120 Hz phones may look uneven until V3.
- No `Vector2` methods, `round()` or trig in the sim; baselines per architecture.

### Neutral
- `BattleClock` replaces "Clock"; `Battle` gains `sim_time`, `sim_rng`, `ticks_run()`, `between_ticks()`; `SimRng` has no MVP consumer.

## Risks

- **V6 tick above 1.33 ms.** N becomes 2 in place; then ADR-0009 Decision 9's levers and ADR-0005's flat table; above 2.0 ms, escalate.
- **Floats differ across architectures.** Per-architecture baselines; V5 records the gap; outcome-level gates compared by hand.
- **A numeric assumption is wrong (V4).** It runs before acceptance, so it stops the sim epics before any story.
- **Late input (SP1).** Held for the next `flush()`; one frame of latency, order kept.
- **A runtime error leaves `_ticking` set in release.** Development builds stop on it; V4 records release unwinding; if the flag can stick, the guard becomes development-only.
- **Extra `_process`, `dt` subtraction or banned maths creeps in.** ADR-0007 lints over sim folders; the 301-tick regression test.
- **The stall threshold hides a performance problem.** Development builds log every stall frame.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | TR-state-003 (Rule 4): time only via `battle.tick(dt)` at a fixed rate; no `_process`, Timers, await, wall clock or physics in gameplay; the wrapper clamps | Decisions 1 and 2; Guidelines |
| game-state-stage-flow.md | TR-state-004 (Rule 5): one documented order; commands only between ticks | Decision 4; Decision 5 (commands in step 0 or engine callbacks, never step 3; `between_ticks()`) |
| game-state-stage-flow.md | TR-state-005 (Rule 5): randomness only from the seed; identical results | Decisions 7 and 9 |
| game-state-stage-flow.md | TR-state-006: Flow a pure machine; result readable after the outcome | Decision 3 (Flow ticked only in step 1, holds no clock; its phase drives the gate; nothing ticks after an outcome) |
| game-state-stage-flow.md | TR-state-007 (Rule 15): set state, stop clock, cancel input, emit; the rest of the tick skipped | Decision 3 (gate reads the phase); Decision 4 (`halted()` before steps 2 to 6) |
| game-state-stage-flow.md | TR-state-012 (Rule 4): one `to_ticks`; integer countdowns | Decision 6 |
| game-state-stage-flow.md | TR-state-014: Lost delay, Won beat, arming on the frame clock | Decision 8 (HudLogic `advance(ms)` in step 1, running while gated) |
| combat-damage.md | TR-combat-009 (Rule 11): Flow, advance, `tick_status`, towers by slot, hero then burst, reap; leaks before fire | Decision 4 |
| combat-damage.md | TR-combat-014: determinism per architecture; baselines per architecture | Decision 9; V4, V5 |
| enemy-wave.md | TR-enemy-002 (Formulas, Rule 8): fixed `dt`; `to_ticks` halves away from zero; absolute schedule | Decision 6; Decision 3 (`dt` checked) |
| enemy-wave.md | TR-enemy-003 (Rule 12): advance and reap entries; roster passed to `tick_status` | Decision 4 (steps 2, 3, 6) |
| enemy-wave.md | TR-enemy-007 (Rule 6): no wave randomness; separate cosmetic RNG; retry identical | Decision 7 (`draw_count()` 0; view-owned RNG; seed reused) |
| tower-system.md | TR-tower-005 (Rules 9, 10): ascending slot; integer `cooldown_left` every tick, Intermission included | Decisions 3, 4, 6 |
| tower-system.md | TR-tower-010 (Rule 8): chip window on real time via `ChipWindow.advance(ms)` from the wrapper | Decisions 5 and 8 |
| hero-system.md | TR-hero-003 (Tick list): Hero-and-burst slot, `to_ticks`, returns when halted | Decisions 4 and 6 |
| hero-system.md | TR-hero-006 (Rule 14, Formulas): PinGeometry in float scalars, no `Vector2` methods | Decision 9 |
| hero-system.md | TR-hero-011 (Rule 16): aim state and `cooldown_digit()` through an explicit `update()` | Decision 5 (`update()` first in step 4, matching the drawn frame) |
| hero-system.md | TR-hero-013: pause stops the clock; exact resume; Build no ticks, Intermission ticks | Decision 3 |
| battle-hud.md | TR-hud-005 (Rules 10, 18): commands, real-time models, ticks, views; displayed equals paid | Decision 5 (paid equals the most recently rendered value) |
| battle-hud.md | TR-hud-007 (Rule 11): arming on `advance(ms)`, 100 ms clamp, frozen while Paused | Decision 8 |

Also answered: QQ-01, QQ-05 (float policy; `Vector2` precision stays ADR-0009 V1), QQ-08 (tick order), QQ-11 (split; device numbers via V6), the Hero GDD's HeroInput question, ADR-0003 SP11's request.

## Performance Implications
- **CPU**: A few float operations per frame for the clock; four checks per tick call. Tick cost is the systems' (V6). Worst-case frame: 3 ticks at 1.33 ms inside 4.0 ms.
- **Memory**: One `SimTime`, `SimRng` and `BattleClock` per battle; no per-tick allocation added.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

No code exists. Before acceptance: the V4 and V9 headless script (outside `src/`) and the spike items. First stories after acceptance: (1) `SimTime`, `SimRng` with the golden values as unit tests; (2) `BattleClock` with Validation 1; (3) the `Battle.tick` gate and order with recording fakes; (4) the wrapper's `_process` and `_on_phase_changed`, verified manually; (5) the determinism test once two sims exist. Prototype numbers are not carried over; every bot gate is re-baselined.

**Rollback plan**: The driver is one wrapper function and one pure class; moving to `_physics_process` changes `battle_wrapper.gd` only. Clamp, phase and stall are constants. Changing `SimRng`'s algorithm changes one file and every baseline, through a superseding ADR, as does relaxing the float policy.

## Validation Criteria

1. **Clock (headless).** At 60: `advance(1/60)` gives 1; `advance(1/30)` gives 2; `advance(0.2)` gives 3 and leaves 1.5 ticks of carry; `advance(0.6)` gives 0 and resets to half a tick; `advance(0.0)`, `(-1.0)`, `(NAN)`, `(INF)` give 0 and change nothing; 1,800 calls of `advance(1/30)` give 3,600 ticks; `drop_backlog()` then `advance(0.01)` gives 1. **Jitter:** 600 frames alternating `1/60 - 0.0001` and `1/60 + 0.0001`, minus first, give 600 one-tick frames (a clock started at 0 gives 0- and 2-tick frames).
2. **Gate (headless, recording fakes).** Build, Paused, Won, Lost, Fatal run no step, `ticks_run()` 0; Wave and Intermission run six steps in order; `halted()` latched in step N stops N+1 to 6 (Game State Acceptance 9, 13); latched after step 3, `between_ticks()` reads true after `tick()` returns; `tick(1.0 / 30.0)` at 60 Hz runs nothing and records one development error; a re-entrant `tick` records one.
3. **`to_ticks` (headless).** At 60: 0.9 s 54, 5.0 s 300, 1/60 s 1, 0 is 0; 0.125 s steps 0, 8, 15, 23; 0.1 s member 3 is 18; 0.025 s 2, -0.025 s -2. At 4: 0.125 s 1. `NAN`, `INF` give 0. A 5.0 s float countdown by repeated subtraction takes 301 ticks (regression reason).
4. **`SimRng` (headless).** V4's sequences; `draw_count()` counts; one seed, one sequence.
5. **Seed never read.** Two seeds, one script, through the Builder: identical logs and distances, `sim_rng.draw_count()` 0 (Enemy & Wave Acceptance 42).
6. **Determinism (ADR-0007 harness).** One `(fixture, stage, seed, script)` twice: identical per-tick digests (positions, HP, counters, phase, gold) and signal logs, compared against `tests/baselines/<arch>/`.
7. **HeroInput sync (headless, fake resolver).** Walk the hero beyond its 56-unit grab radius from its start, call `update()`: a press at `position()` hits the hero's disc, a press at the start misses. Calling `update()` before the ticks (the rejected order) makes the first press miss on the frame the hero is drawn at the new position.
8. **Pause.** Headless: each live phase, `pause()`, 100 tick calls, `resume()`: no countdown or position changes (Game State Acceptance 12). Manual, in `production/qa/evidence/`: focus loss mid-walk and mid-telegraph on desktop and phone; the hero continues from the same point.
9. **Displayed equals paid.** Manual, desktop and phone: tap Call as the digit changes, 20 times; gold gained equals the last rendered bonus each time (dev log records shown and paid), with SP1's late-event rate beside it.
10. **Budget.** V6 records the whole-tick p99, step timings and N; Data Flow 10 gets measured figures.

The decision is wrong if a GDD rule needs a second clock or order, bots disagree with themselves on one architecture, or paid cannot be kept equal to the rendered value.

## Related

- Depends on ADR-0001, ADR-0003; binding ADR-0005 (0.5 ms read ceiling), ADR-0009 (its V4 is V6 here). Enables ADR-0006, ADR-0007, ADR-0010, ADR-0011.
- `architecture.md`: Data Flow 1, 2, 6, 10; B0, B4, B5, B9; QQ-01, 05, 08, 11.
- GDDs: game-state-stage-flow (Rules 4, 5, 15, 17, Edge Cases), combat-damage (Rule 11), enemy-wave (Rules 6, 8, 12, Formulas), tower-system (Rules 8 to 10), hero-system (Tick list, Rules 15, 16, the HeroInput question), battle-hud (Rules 10, 11, 15, 18), input-gesture-resolver (adapter contract), data-config-pipeline (interval floor).
- Spike kit `prototypes/adr-0003-device-spike/` (SP1, SP10, SP11 reused; SP14, SP15 proposed).
- Code: `src/foundation/sim_time.gd`, `src/foundation/sim_rng.gd`, `src/root/battle_clock.gd`, `src/root/battle.gd`, `src/root/battle_wrapper.gd`.

